# Audit System - Usage Examples

## Basic Usage

### View Recent Audit Entries

```r
# Show last 20 entries (sanitized by default)
show_audit(last_n = 20)

# Show all entries
show_audit()

# Show last 50 entries with full commands (⚠️ may contain PII)
show_audit(sanitize = FALSE, last_n = 50)
```

### Filter Audit Entries

```r
# Show only run_r_code executions
show_audit(tool = "run_r_code")

# Show only blocked operations
show_audit(status = "blocked")

# Show only errors
show_audit(status = "error")

# Show entries from specific date
show_audit(since = "2025-11-08")

# Combine filters
show_audit(tool = "write_r_script", status = "success", last_n = 10)
```

### Export Audit Log

```r
# Export all entries (always sanitized for safe sharing)
export_audit("audit_full.csv")

# Export filtered entries
export_audit("blocked_commands.csv", status = "blocked")
export_audit("recent_executions.csv", since = "2025-11-01")
```

### Get Statistics

```r
# Show audit statistics
audit_stats()
```

## Understanding the Audit Log

### Log Format (JSONL)

Each line in `.direct/audit.log` is a JSON object with full and sanitized commands.

### PII Redaction

Automatically redacted patterns:
- Email addresses → `[EMAIL]`
- Names in quotes → `[NAME]`
- Phone numbers → `[PHONE]`
- IBANs → `[IBAN]`
- Credit card numbers → `[CC_NUMBER]`
- IP addresses → `[IP_ADDR]`
- UUIDs → `[UUID]`

### Custom PII Patterns

Edit `.direct/config.yml`:

```yaml
audit:
  pii_patterns:
    - pattern: "CUST[0-9]{6}"
      replacement: "[CUSTOMER_ID]"
```

## Security Notes

- **Full command** (`cmd`): For debugging/forensics only
- **Sanitized** (`cmd_sanitized`): Safe for sharing/export
- Logs never auto-delete (user control)
- `.direct/` in `.gitignore` by default

See `docs/SECURITY_NOTES.md` for detailed security architecture.
