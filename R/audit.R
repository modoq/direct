# ============================================================================
# Audit Logging System with PII Redaction
# ============================================================================

#' Get or create audit log directory
#' 
#' @param project_dir Project directory (default: current working directory)
#' @return Path to .direct directory
#' @keywords internal
get_audit_dir <- function(project_dir = getwd()) {
  audit_dir <- file.path(project_dir, ".direct")
  if (!dir.exists(audit_dir)) {
    dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
  }
  return(audit_dir)
}

#' Sanitize text for PII (Personally Identifiable Information)
#' 
#' Removes common PII patterns from text for safe logging and sharing.
#' 
#' @param text Character string to sanitize
#' @return Sanitized text with PII replaced by placeholders
#' @keywords internal
#' @export
sanitize_pii <- function(text) {
  if (is.null(text) || length(text) == 0 || !is.character(text)) {
    return(text)
  }
  
  # Email addresses
  text <- gsub(
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
    "[EMAIL]",
    text,
    perl = TRUE
  )
  
  # Names in quotes (heuristic: "Firstname Lastname" or 'Firstname Lastname')
  # Matches: Capital letter, lowercase letters, space, Capital letter, lowercase letters
  text <- gsub(
    "(['\"])([A-ZÄÖÜ][a-zäöüß]+ [A-ZÄÖÜ][a-zäöüß]+)\\1",
    "\\1[NAME]\\1",
    text,
    perl = TRUE
  )
  
  # Phone numbers (various formats)
  # Matches: +49 123 456789, 0123-456789, (123) 456-7890, etc.
  text <- gsub(
    "\\+?[0-9]{1,4}[\\s.-]?\\(?[0-9]{1,4}\\)?[\\s.-]?[0-9]{1,4}[\\s.-]?[0-9]{1,9}",
    "[PHONE]",
    text,
    perl = TRUE
  )
  
  # IBANs (International Bank Account Numbers)
  text <- gsub(
    "\\b[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}\\b",
    "[IBAN]",
    text,
    perl = TRUE
  )
  
  # Credit card numbers (simple pattern: 4 groups of 4 digits)
  text <- gsub(
    "\\b[0-9]{4}[\\s-]?[0-9]{4}[\\s-]?[0-9]{4}[\\s-]?[0-9]{4}\\b",
    "[CC_NUMBER]",
    text,
    perl = TRUE
  )
  
  # IP addresses (optional, depending on use case)
  text <- gsub(
    "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",
    "[IP_ADDR]",
    text,
    perl = TRUE
  )
  
  # UUIDs (if considered PII)
  text <- gsub(
    "\\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\b",
    "[UUID]",
    text,
    perl = TRUE,
    ignore.case = TRUE
  )
  
  # Load custom patterns from config if exists
  config_path <- file.path(get_audit_dir(), "config.yml")
  if (file.exists(config_path)) {
    tryCatch({
      if (requireNamespace("yaml", quietly = TRUE)) {
        config <- yaml::read_yaml(config_path)
        if (!is.null(config$audit$pii_patterns)) {
          for (pattern_config in config$audit$pii_patterns) {
            text <- gsub(
              pattern_config$pattern,
              pattern_config$replacement,
              text,
              perl = TRUE
            )
          }
        }
      }
    }, error = function(e) {
      # Silently fail if yaml not available or config invalid
    })
  }
  
  return(text)
}

#' Sanitize secrets from output
#' 
#' Removes common secret patterns (API keys, tokens, passwords) from text
#' before sending to AI.
#' 
#' @param text Character string to sanitize
#' @return Sanitized text with secrets replaced by [REDACTED]
#' @keywords internal
#' @export
sanitize_secrets <- function(text) {
  if (is.null(text) || length(text) == 0 || !is.character(text)) {
    return(text)
  }
  
  # API Keys (various patterns)
  text <- gsub(
    "(?i)(api[_-]?key|apikey)\\s*[:=]\\s*['\"]?([a-zA-Z0-9_\\-]{20,})['\"]?",
    "\\1: [REDACTED]",
    text,
    perl = TRUE
  )
  
  # Passwords
  text <- gsub(
    "(?i)(password|passwd|pwd)\\s*[:=]\\s*['\"]?([^'\"\\s]{6,})['\"]?",
    "\\1: [REDACTED]",
    text,
    perl = TRUE
  )
  
  # Tokens
  text <- gsub(
    "(?i)(token|bearer)\\s*[:=]\\s*['\"]?([a-zA-Z0-9_\\-\\.]{20,})['\"]?",
    "\\1: [REDACTED]",
    text,
    perl = TRUE
  )
  
  # OpenAI/Anthropic API Keys
  text <- gsub(
    "sk-[a-zA-Z0-9]{32,}",
    "sk-[REDACTED]",
    text,
    perl = TRUE
  )
  
  # AWS Access Keys
  text <- gsub(
    "AKIA[0-9A-Z]{16}",
    "AKIA[REDACTED]",
    text,
    perl = TRUE
  )
  
  # Private Keys
  text <- gsub(
    "-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?-----END [A-Z ]*PRIVATE KEY-----",
    "-----BEGIN PRIVATE KEY----- [REDACTED] -----END PRIVATE KEY-----",
    text,
    perl = TRUE
  )
  
  # Database Connection Strings
  text <- gsub(
    "(?i)(mongodb|postgres|mysql|mariadb)://[^:]+:([^@]+)@",
    "\\1://user:[REDACTED]@",
    text,
    perl = TRUE
  )
  
  # Check for Sys.getenv() output
  if (grepl("Sys\\.getenv", text, fixed = TRUE)) {
    warning(
      "[SECURITY WARNING] Sys.getenv() output detected and redacted.\n",
      "Use direct::allow_env_var('VAR_NAME') to whitelist specific variables.",
      call. = FALSE
    )
    text <- paste0(
      "[SECURITY WARNING: Sys.getenv() output redacted]\n",
      "Use direct::allow_env_var('VAR_NAME') to whitelist specific variables."
    )
  }
  
  return(text)
}

#' Log audit entry
#' 
#' Records tool execution in audit log with full command and sanitized version.
#' 
#' @param session_id R session ID
#' @param tool Tool name that was called
#' @param command Full command/code that was executed
#' @param status Execution status ("success", "error", "blocked")
#' @param ... Additional fields to log (e.g., duration_ms, error message)
#' @keywords internal
#' @export
log_audit <- function(session_id, tool, command, status, ...) {
  tryCatch({
    audit_dir <- get_audit_dir()
    log_file <- file.path(audit_dir, "audit.log")
    
    # Build entry
    entry <- list(
      ts = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      sid = session_id,
      tool = tool,
      cmd = command,                        # Full command for forensics
      cmd_sanitized = sanitize_pii(command), # PII-redacted for export
      status = status
    )
    
    # Add additional fields
    extra <- list(...)
    if (length(extra) > 0) {
      entry <- c(entry, extra)
    }
    
    # Convert to JSON and append
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      json_line <- jsonlite::toJSON(entry, auto_unbox = TRUE)
      cat(json_line, "\n", file = log_file, append = TRUE)
    } else {
      warning("jsonlite package not available, audit logging disabled", call. = FALSE)
    }
    
  }, error = function(e) {
    # Don't fail tool execution if logging fails
    warning("Failed to write audit log: ", e$message, call. = FALSE)
  })
}

#' Read audit log entries
#' 
#' @param sanitize Logical, if TRUE shows sanitized commands (default: TRUE)
#' @param last_n Number of recent entries to show (default: all)
#' @param tool Filter by tool name (optional)
#' @param status Filter by status (optional)
#' @param since Filter by timestamp (ISO format, optional)
#' @return Data frame with audit entries
#' @export
show_audit <- function(sanitize = TRUE, last_n = NULL, tool = NULL, 
                       status = NULL, since = NULL) {
  audit_dir <- get_audit_dir()
  log_file <- file.path(audit_dir, "audit.log")
  
  if (!file.exists(log_file)) {
    message("No audit log found at: ", log_file)
    return(invisible(NULL))
  }
  
  # Read JSONL file
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite package required for reading audit log", call. = FALSE)
  }
  
  lines <- readLines(log_file, warn = FALSE)
  if (length(lines) == 0) {
    message("Audit log is empty")
    return(invisible(NULL))
  }
  
  # Parse each line
  entries <- lapply(lines, function(line) {
    tryCatch(
      jsonlite::fromJSON(line),
      error = function(e) NULL
    )
  })
  entries <- Filter(Negate(is.null), entries)
  
  if (length(entries) == 0) {
    message("No valid entries in audit log")
    return(invisible(NULL))
  }
  
  # Convert to data frame
  df <- do.call(rbind, lapply(entries, function(e) {
    as.data.frame(e, stringsAsFactors = FALSE)
  }))
  
  # Filter
  if (!is.null(tool)) {
    df <- df[df$tool == tool, ]
  }
  if (!is.null(status)) {
    df <- df[df$status == status, ]
  }
  if (!is.null(since)) {
    df <- df[df$ts >= since, ]
  }
  
  # Select last_n
  if (!is.null(last_n) && nrow(df) > last_n) {
    df <- tail(df, last_n)
  }
  
  # Choose cmd column
  if (sanitize) {
    if ("cmd_sanitized" %in% names(df)) {
      df$cmd_display <- df$cmd_sanitized
    } else {
      df$cmd_display <- df$cmd
    }
  } else {
    message("⚠️  Showing FULL commands (may contain PII/secrets)")
    df$cmd_display <- df$cmd
  }
  
  # Display columns
  display_cols <- c("ts", "sid", "tool", "cmd_display", "status")
  display_cols <- intersect(display_cols, names(df))
  
  print(df[, display_cols])
  invisible(df)
}

#' Export audit log to CSV
#' 
#' Always exports sanitized version for safe sharing.
#' 
#' @param output_file Path to output CSV file
#' @param tool Filter by tool name (optional)
#' @param status Filter by status (optional)
#' @param since Filter by timestamp (ISO format, optional)
#' @export
export_audit <- function(output_file, tool = NULL, status = NULL, since = NULL) {
  df <- show_audit(sanitize = TRUE, tool = tool, status = status, since = since)
  
  if (is.null(df) || nrow(df) == 0) {
    message("No entries to export")
    return(invisible(NULL))
  }
  
  # Select export columns (always sanitized)
  export_cols <- c("ts", "sid", "tool", "cmd_sanitized", "status")
  export_cols <- intersect(export_cols, names(df))
  
  write.csv(df[, export_cols], output_file, row.names = FALSE)
  message("✓ Exported ", nrow(df), " entries to: ", output_file)
  invisible(output_file)
}

#' Get audit statistics
#' 
#' @return List with audit statistics
#' @export
audit_stats <- function() {
  df <- show_audit(sanitize = TRUE)
  
  if (is.null(df) || nrow(df) == 0) {
    message("No audit entries found")
    return(invisible(NULL))
  }
  
  stats <- list(
    total_entries = nrow(df),
    date_range = c(
      first = min(df$ts),
      last = max(df$ts)
    ),
    by_tool = table(df$tool),
    by_status = table(df$status),
    by_session = table(df$sid)
  )
  
  # Print nicely
  cat("=== Audit Statistics ===\n\n")
  cat("Total entries:", stats$total_entries, "\n")
  cat("Date range:", stats$date_range["first"], "to", stats$date_range["last"], "\n\n")
  
  cat("By Tool:\n")
  print(stats$by_tool)
  cat("\n")
  
  cat("By Status:\n")
  print(stats$by_status)
  cat("\n")
  
  cat("By Session:\n")
  print(stats$by_session)
  
  invisible(stats)
}

#' Initialize audit configuration
#' 
#' Creates .direct/config.yml with default settings
#' 
#' @param project_dir Project directory (default: current working directory)
#' @export
init_audit_config <- function(project_dir = getwd()) {
  audit_dir <- get_audit_dir(project_dir)
  config_file <- file.path(audit_dir, "config.yml")
  
  if (file.exists(config_file)) {
    message("Config already exists at: ", config_file)
    return(invisible(config_file))
  }
  
  default_config <- '# direct Package Configuration

audit:
  log_full_commands: true       # Store both cmd and cmd_sanitized
  default_view: "sanitized"     # What show_audit() displays by default
  
  # Custom PII patterns (in addition to built-in patterns)
  pii_patterns:
    # Example: Custom customer ID format
    # - pattern: "CUST[0-9]{6}"
    #   replacement: "[CUSTOMER_ID]"

# Allowed environment variables (whitelist)
# Only these can be read via Sys.getenv() without warning
allowed_env_vars:
  - R_HOME
  - PATH
  - LANG
  - TZ

# Blocked paths (in addition to default blocks like ~/.ssh)
blocked_paths:
  # - "/custom/sensitive/dir"
'
  
  writeLines(default_config, config_file)
  message("✓ Created audit config at: ", config_file)
  message("  Edit this file to customize PII patterns and security settings")
  invisible(config_file)
}
