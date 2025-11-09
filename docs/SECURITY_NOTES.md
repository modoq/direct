# Security & Privacy - Developer Notes

## Überblick

Dieses Dokument sammelt Sicherheits- und Privacy-relevante Design-Entscheidungen und zukünftige Verbesserungen für das `direct` Package.

---

## 1. Credential Leakage Prevention

### Status Quo (v0.1.x)

**Implementiert:**
- ✅ Output-Sanitizer für gängige Secret-Patterns (API Keys, Tokens, Passwords)
- ✅ Code-Warnung bei `Sys.getenv()` und sensiblen File-Operationen
- ✅ Path-Validation für btw-Tools (nur innerhalb Project Directory)

**Aktueller Ansatz: "Informed Trust"**
- Secrets werden aus Output gefiltert bevor sie an Claude gesendet werden
- User kann Secrets sehen, AI nicht
- Audit-Log dokumentiert alle Zugriffe

### Bekannte Limitierungen

⚠️ **AI kann Secrets theoretisch iterativ extrahieren:**

```r
# Beispiel-Angriff:
run_r_code("substr(Sys.getenv('SECRET'), 1, 5)")  # Erste 5 Zeichen
run_r_code("substr(Sys.getenv('SECRET'), 6, 10)") # Nächste 5 Zeichen
# ... und so weiter
```

**Warum nicht komplett blockiert?**
- R's Mächtigkeit macht vollständige Sandboxing unmöglich
- `eval()`, `get()`, `.Call()` umgehen String-basierte Checks
- Würde legitime Use-Cases brechen (z.B. Environment-Debugging)

### Zukünftige Verbesserungen (TODO)

#### Priorität: Hoch
- [ ] **AST-basierte Code-Analyse** vor Execution
  - Parse R-Code zu Abstract Syntax Tree
  - Erkenne `Sys.getenv()` Calls auch in verschachtelten Expressions
  - Blockiere oder warne bei sensitiven Operationen

- [ ] **Whitelisting für Environment-Variables**
  ```yaml
  # .direct/config.yml
  allowed_env_vars:
    - R_HOME
    - PATH
    - PROJECT_API_KEY  # explizit erlaubt
  ```
  Nur gewhitelistete Vars dürfen gelesen werden

- [ ] **Rate-Limiting für sensitive Operations**
  - Max N `Sys.getenv()` Calls pro Session
  - Verhindert iterative Extraktion

#### Priorität: Mittel
- [ ] **Sandbox-Modus (opt-in)**
  ```r
  direct::init_project(sandbox_mode = TRUE)
  ```
  - Setzt `HOME` auf Project-Directory
  - Leert `PATH` außer Project/bin
  - Mountet `/tmp` als tmpfs

- [ ] **Pre-Execution Review UI**
  - Bei kritischem Code: User-Bestätigung erforderlich
  - Integration mit RStudio Viewer/Dialog

#### Priorität: Niedrig
- [ ] **Machine-Learning-basierte Secret-Detection**
  - Trainiere Modell auf Secret-Patterns
  - Höhere True-Positive-Rate als Regex

---

## 2. Path Traversal & File System Access

### Status Quo

**btw-Tools (Read-Zugriff):**
- Designt für Project-Exploration
- Müssen auch außerhalb Project-Dir lesen können (Packages, Libraries)
- **Lösung:** Wrapper im MCP-Server validiert Paths vor Delegation an btw

**direct-Tools (Write-Zugriff):**
- Beschränkt auf Working Directory
- `normalizePath()` + `startsWith()` Check

### Implementierung

```r
validate_path <- function(path) {
  abs_path <- normalizePath(path, mustWork = FALSE)
  wd <- getwd()
  
  if (!startsWith(abs_path, wd)) {
    stop("SECURITY: File access outside project denied")
  }
  
  # Zusätzliche Blocks
  blocked <- c("~/.ssh", "~/.aws", "~/.config", "/etc/")
  for (pattern in blocked) {
    if (grepl(pattern, path, fixed = TRUE)) {
      stop("SECURITY: Access to sensitive directory blocked")
    }
  }
}
```

### Zukünftige Verbesserungen

- [ ] **Symlink-Attack Prevention**
  - Check ob Path durch Symlink außerhalb Project führt
  - `Sys.readlink()` rekursiv prüfen

- [ ] **Configurable Blocklist**
  ```yaml
  blocked_paths:
    - ~/.ssh
    - ~/.aws
    - /custom/sensitive/dir
  ```

- [ ] **Integration mit btw Package**
  - Feature-Request: `btw::set_path_validator()`
  - btw würde direct's Validierung nativ aufrufen

---

## 3. Audit Logging & PII

### Anforderungen

✅ **Implementiert:**
- JSONL-Format (`.direct/audit.log`)
- Vollständiger Command wird geloggt
- PII-Redaction für sanitized View
- Beide Versionen im Log: `cmd` + `cmd_sanitized`

### Log-Struktur

```json
{
  "ts": "2025-11-08T14:23:01Z",
  "sid": 1,
  "tool": "run_r_code",
  "cmd": "df %>% filter(name == 'Max Mustermann')",
  "cmd_sanitized": "df %>% filter(name == '[NAME]')",
  "status": "success",
  "duration_ms": 145
}
```

### PII-Detection Patterns

**Aktuell erkannt:**
- Email-Adressen
- Namen in Quotes (heuristisch: "Vorname Nachname")
- Telefonnummern (verschiedene Formate)
- IBANs
- Kreditkarten-Nummern
- IP-Adressen
- UUIDs

**Configurable in `.direct/config.yml`:**
```yaml
audit:
  pii_patterns:
    - pattern: "CUST[0-9]{6}"
      replacement: "[CUSTOMER_ID]"
```

### User-Interface

```r
# Standard-View (sanitized):
direct::show_audit()

# Forensik (full, mit Warnung):
direct::show_audit(sanitize = FALSE)

# Export (immer sanitized):
direct::export_audit("audit.csv")

# Stats:
direct::audit_stats()
```

### Retention Policy

- ❌ **KEINE automatische Löschung**
- User muss Log manuell löschen wenn zu groß
- Rationale: Audit-Zweck wichtiger als Disk-Space

### Zukünftige Verbesserungen

- [ ] **Log-Rotation**
  - Auto-Archive nach N MB
  - `.direct/audit.log` → `.direct/archive/audit_2025-11.log.gz`

- [ ] **Differential Privacy für Analytics**
  - `audit_stats()` könnte aggregierte Daten exportieren
  - Noise injection für Sharing

- [ ] **SIEM Integration**
  - Export zu Splunk/ELK
  - Real-time Monitoring bei kritischen Events

---

## 4. Session Isolation

### Aktueller Ansatz: Fail-First

```r
ensure_session_selected <- function() {
  sessions <- list_active_sessions()
  
  if (length(sessions) > 1 && is.null(get_selected_session())) {
    stop("MULTI_SESSION: Use list_r_sessions() + select_r_session(n)")
  }
}
```

**Verhalten:**
- Bei Multi-Session: Tool-Call scheitert mit klarer Error-Message
- Claude ruft automatisch `list_r_sessions()` auf
- User wählt Session
- Selection persistent für MCP-Server Lifetime

### Offene Fragen

- [ ] Soll Session-Wahl über Konversationen hinweg persistent sein?
- [ ] Was passiert wenn gewählte Session crashed?
- [ ] Auto-Reconnect bei Session-Loss?

---

## 5. Threat Model

### Aktuelles Ziel: "Informed Trust"

```
┌─────────────────────────────────────┐
│  User gibt explizit Erlaubnis       │
│  ↓                                   │
│  Audit-Log zeichnet alles auf       │
│  ↓                                   │
│  Output-Sanitizer filtert Patterns  │
│  ↓                                   │
│  Warnung bei gefährlichen Ops       │
└─────────────────────────────────────┘
```

**Nicht das Ziel:**
- ❌ Zero-Trust zwischen User und Claude
- ❌ Vollständige Sandboxing (technisch unmöglich in R)

**Annahmen:**
- User vertraut Claude für Code-Execution
- Anthropic loggt keine sensitiven Outputs (Privacy Policy)
- Output-Sanitizer verhindert versehentliches Secret-Leaking

### Angriffsszenarien

**Szenario 1: Versehentliches Secret-Leaking**
- User: "Zeig mir alle Environment-Variables"
- ✅ **Mitigiert:** Output wird sanitized

**Szenario 2: Böswilliger Claude (Jailbreak)**
- Claude versucht iterativ Secrets zu extrahieren
- ⚠️ **Teilweise mitigiert:** Warnung + Audit-Log
- ❌ **Nicht verhindert:** Technisch möglich

**Szenario 3: Kompromittierte Dependencies**
- Malicious R-Package in Session geladen
- ❌ **Nicht verhindert:** Außerhalb Scope von direct

---

## 6. Compliance & DSGVO

### Audit-Log Handling

**PII im Log:**
- ✅ Vollständiger Command für Forensik (`cmd`)
- ✅ Redacted Version für Export (`cmd_sanitized`)
- ✅ Default-View zeigt sanitized
- ✅ Export immer sanitized

**Rechtfertigung für vollständigen Command:**
- Log ist lokal, unter User-Kontrolle
- Audit-Zweck (Post-Mortem, Debugging) erfordert Vollständigkeit
- User kann Log löschen/redacten vor Weitergabe
- `.gitignore` enthält `.direct/`

### Datenübertragung an Anthropic

**Was wird übertragen:**
- User-Code (nach Input)
- Tool-Outputs (nach Sanitization)
- Tool-Names und Parameter

**Was wird NICHT übertragen:**
- Lokale Files (außer explizit vom User geteilt)
- Environment-Variables (nach Sanitization)
- Audit-Log

---

## 7. Best Practices für User

### Empfohlene Project-Struktur

```
my-project/
├── .Rprofile           # btw_mcp_session() call
├── .direct/
│   ├── config.yml      # direct settings
│   └── audit.log       # NICHT committen!
├── .gitignore          # enthält .direct/
├── .env                # Secrets, NICHT committen!
└── scripts/
```

### Sicherer Umgang mit Secrets

```r
# ✅ Gut: Secrets in .env
Sys.setenv(API_KEY = readLines(".env")[1])

# ❌ Schlecht: Secrets im Code
api_key <- "sk-abc123..."

# ✅ Gut: Whitelisting
direct::allow_env_var("PROJECT_API_KEY")
```

### Audit-Review

```r
# Regelmäßig Log prüfen:
direct::show_audit(last_n = 50)

# Bei verdächtigen Patterns:
direct::show_audit(tool = "run_r_code", status = "blocked")

# Vor Projekt-Sharing:
direct::export_audit("audit_sanitized.csv")
```

---

## 8. Changelog

### v0.1.0 (2025-11-08)
- ✅ Initial Security-Implementation
- ✅ Output-Sanitizer für Secrets
- ✅ Path-Validation für btw-Tools
- ✅ Audit-Logging mit PII-Redaction
- ✅ Fail-First Session-Selection

### Future Versions
- v0.2.0: AST-basierte Code-Analyse
- v0.3.0: Whitelist-basierte Env-Var-Access
- v1.0.0: Production-ready Security-Audit

---

## Kontakt

Bei Sicherheitsbedenken oder Schwachstellen:
- GitHub Issues: https://github.com/modoq/direct/issues
- Label: `security`
- Für kritische Issues: Private Security Advisory

---

**Letztes Update:** 2025-11-08  
**Autor:** Development Team  
**Status:** Living Document
