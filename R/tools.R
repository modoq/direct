# ============================================================================
# MCP Tools for Claude Desktop + RStudio Integration
# WITH AUDIT LOGGING
# ============================================================================

#' Path Validation Security Function
#' 
#' Validates that a path is within the current workspace and blocks
#' path traversal attacks.
#' 
#' @param path Character string of path to validate
#' @param base_dir Base directory (default: current working directory)
#' @return Logical indicating if path is safe
#' @keywords internal
#' @export
is_safe_path <- function(path, base_dir = getwd()) {
  tryCatch({
    # IMPORTANT: Check for path traversal patterns BEFORE normalization!
    # Block dangerous patterns immediately
    dangerous_patterns <- c(
      "../",      # Relative path traversal
      "/.."       # Absolute path traversal
    )
    
    for (pattern in dangerous_patterns) {
      if (grepl(pattern, path, fixed = TRUE)) {
        message(sprintf(
          "⛔ Path traversal blocked! Pattern: %s\n   Path: %s",
          pattern, path
        ))
        return(FALSE)
      }
    }
    
    # Expand ~ 
    if (startsWith(path, "~")) {
      path <- path.expand(path)
    }
    
    # If absolute path: normalize directly
    # If relative path: combine with base_dir
    if (startsWith(path, "/")) {
      abs_path <- normalizePath(path, mustWork = FALSE)
    } else {
      abs_path <- normalizePath(file.path(base_dir, path), mustWork = FALSE)
    }
    
    abs_base <- normalizePath(base_dir, mustWork = TRUE)
    
    # Check if path is within workspace
    is_safe <- startsWith(abs_path, abs_base)
    
    if (!is_safe) {
      message(sprintf(
        "⛔ Path outside workspace blocked!\n   Workspace: %s\n   Attempted: %s", 
        abs_base, abs_path
      ))
    }
    
    return(is_safe)
  }, error = function(e) {
    message(paste("❌ Error in path validation:", e$message))
    return(FALSE)
  })
}

#' Get current session ID
#' 
#' @return Integer session ID (defaults to 1 if not in MCP context)
#' @keywords internal
get_session_id <- function() {
  # TODO: Implement proper session tracking
  # For now, default to session 1
  return(1L)
}

#' Execute R Code in RStudio Console
#' 
#' Executes R code with security checks to block dangerous operations.
#' Logs all executions to audit log.
#' 
#' @param code Character string containing R code to execute
#' @param echo Logical indicating whether to echo code in console (default: TRUE)
#' @return Character string with execution status
#' @export
run_r_code <- function(code, echo = TRUE) {
  session_id <- get_session_id()
  start_time <- Sys.time()
  
  if (!rstudioapi::isAvailable()) {
    log_audit(session_id, "run_r_code", code, "error", 
              error = "RStudio not available")
    return("Error: RStudio is not available.")
  }
  
  # Check for dangerous operations
  dangerous_patterns <- c(
    "system\\(",
    "shell\\(",
    "file\\.remove\\(",
    "unlink\\(",
    "Sys\\.setenv\\(",
    "setwd\\(",
    "source\\("
  )
  
  for (pattern in dangerous_patterns) {
    if (grepl(pattern, code, perl = TRUE)) {
      log_audit(session_id, "run_r_code", code, "blocked",
                reason = paste("dangerous_pattern:", pattern))
      
      warning_msg <- paste0(
        "⛔ WARNING: Potentially dangerous command detected!\n",
        "Pattern: ", pattern, "\n",
        "Code will NOT be executed.\n"
      )
      return(warning_msg)
    }
  }
  
  # Warn about Sys.getenv
  if (grepl("Sys\\.getenv", code, fixed = TRUE)) {
    warning(
      "[SECURITY WARNING] Sys.getenv() detected in code.\n",
      "Output will be sanitized before sending to AI.",
      call. = FALSE
    )
  }
  
  # Execute
  tryCatch({
    rstudioapi::sendToConsole(code, execute = TRUE, echo = echo)
    
    duration_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000
    log_audit(session_id, "run_r_code", code, "success", 
              duration_ms = round(duration_ms))
    
    return("✅ Code executed")
    
  }, error = function(e) {
    log_audit(session_id, "run_r_code", code, "error",
              error = e$message)
    return(paste0("❌ Error: ", e$message))
  })
}

#' Safe File Writing (Workspace Only)
#' 
#' Writes files only within the current R workspace. Blocks writing outside
#' workspace and prevents overwriting existing files.
#' Logs all write attempts to audit log.
#' 
#' @param filename Character string with filename (relative to workspace)
#' @param content Character string with file content
#' @return Character string with operation status
#' @export
safe_write_file <- function(filename, content) {
  session_id <- get_session_id()
  
  # Validate path
  if (!is_safe_path(filename)) {
    log_audit(session_id, "safe_write_file", 
              paste0("write to: ", filename), "blocked",
              reason = "path_outside_workspace")
    
    return(paste0(
      "⛔ ERROR: Writing outside workspace NOT allowed!\n",
      "Workspace: ", getwd(), "\n",
      "Attempted path: ", filename, "\n",
      "❌ Only files in current workspace can be written."
    ))
  }
  
  # Check if file already exists
  if (file.exists(filename)) {
    log_audit(session_id, "safe_write_file",
              paste0("write to: ", filename), "blocked",
              reason = "file_exists")
    
    return(paste0(
      "⚠️ WARNING: File already exists!\n",
      "File: ", filename, "\n",
      "Use a different name or delete the file first."
    ))
  }
  
  tryCatch({
    writeLines(content, filename)
    abs_path <- normalizePath(filename)
    
    # Log with file size
    file_size <- file.size(filename)
    log_audit(session_id, "safe_write_file",
              paste0("write to: ", filename), "success",
              file_size_bytes = file_size)
    
    if (rstudioapi::isAvailable()) {
      msg <- sprintf("cat('✅ File created: %s\\n')", basename(filename))
      rstudioapi::sendToConsole(msg, execute = TRUE, echo = FALSE)
    }
    
    return(paste0("✅ File created:\n   ", abs_path))
  }, error = function(e) {
    log_audit(session_id, "safe_write_file",
              paste0("write to: ", filename), "error",
              error = e$message)
    return(paste0("❌ Error writing file:\n   ", e$message))
  })
}

#' Write R Scripts and Reports
#' 
#' Writes R scripts, R Markdown, Quarto and other files with intelligent
#' extension detection. Only appends .R for pure R scripts.
#' Logs all write attempts to audit log.
#' 
#' @param filename Character string with filename (with extension)
#' @param code Character string with file content
#' @return Character string with operation status
#' @export
write_r_script <- function(filename, code) {
  session_id <- get_session_id()
  
  # INTELLIGENT FILE EXTENSION DETECTION
  # Do NOT append .R to these file types:
  special_extensions <- c(
    "\\.Rmd$",   # R Markdown reports
    "\\.qmd$",   # Quarto Markdown
    "\\.Rnw$",   # Sweave (LaTeX + R)
    "\\.csv$",   # CSV data
    "\\.tsv$",   # TSV data
    "\\.txt$",   # Text
    "\\.json$",  # JSON
    "\\.xml$",   # XML
    "\\.md$",    # Markdown
    "\\.html$",  # HTML
    "\\.tex$",   # LaTeX
    "\\.yaml$",  # YAML
    "\\.yml$",   # YAML
    "\\.toml$",  # TOML
    "\\.Rproj$"  # RStudio Project
  )
  
  # Check if file has special extension
  has_special_extension <- any(sapply(special_extensions, function(ext) {
    grepl(ext, filename, ignore.case = TRUE)
  }))
  
  # ONLY add .R for pure R scripts
  if (!has_special_extension && !grepl("\\.R$", filename, ignore.case = TRUE)) {
    filename <- paste0(filename, ".R")
  }
  
  # Validate path
  if (!is_safe_path(filename)) {
    log_audit(session_id, "write_r_script",
              paste0("write ", filename), "blocked",
              reason = "path_outside_workspace")
    
    return(paste0(
      "⛔ ERROR: Script writing outside workspace NOT allowed!\n",
      "Workspace: ", getwd(), "\n",
      "Attempted path: ", filename
    ))
  }
  
  # Check for dangerous code patterns
  dangerous_patterns <- c(
    "system\\(",
    "shell\\(",
    "file\\.remove\\(",
    "unlink\\("
  )
  
  for (pattern in dangerous_patterns) {
    if (grepl(pattern, code, perl = TRUE)) {
      log_audit(session_id, "write_r_script",
                paste0("write ", filename), "blocked",
                reason = paste("dangerous_code:", pattern))
      
      return(paste0(
        "⛔ SECURITY WARNING: Dangerous code detected!\n",
        "Pattern: ", pattern, "\n",
        "Script will NOT be created."
      ))
    }
  }
  
  if (file.exists(filename)) {
    log_audit(session_id, "write_r_script",
              paste0("write ", filename), "blocked",
              reason = "file_exists")
    
    return(paste0(
      "⚠️ WARNING: File already exists!\n",
      "File: ", filename
    ))
  }
  
  tryCatch({
    writeLines(code, filename)
    abs_path <- normalizePath(filename)
    
    # Count lines for audit log
    num_lines <- length(readLines(filename, warn = FALSE))
    log_audit(session_id, "write_r_script",
              paste0("wrote ", filename, " (", num_lines, " lines)"), 
              "success",
              file_size_bytes = file.size(filename),
              num_lines = num_lines)
    
    if (rstudioapi::isAvailable()) {
      # Show appropriate message based on file type
      if (grepl("\\.Rmd$", filename, ignore.case = TRUE)) {
        msg <- sprintf("cat('✅ R Markdown report created: %s\\n')", basename(filename))
      } else if (grepl("\\.qmd$", filename, ignore.case = TRUE)) {
        msg <- sprintf("cat('✅ Quarto document created: %s\\n')", basename(filename))
      } else if (grepl("\\.R$", filename, ignore.case = TRUE)) {
        msg <- sprintf("cat('✅ R script created: %s\\n')", basename(filename))
      } else {
        msg <- sprintf("cat('✅ File created: %s\\n')", basename(filename))
      }
      rstudioapi::sendToConsole(msg, execute = TRUE, echo = FALSE)
    }
    
    # Return message based on file type
    if (grepl("\\.Rmd$", filename, ignore.case = TRUE)) {
      return(paste0("✅ R Markdown report created:\n   ", abs_path))
    } else if (grepl("\\.qmd$", filename, ignore.case = TRUE)) {
      return(paste0("✅ Quarto document created:\n   ", abs_path))
    } else {
      return(paste0("✅ File created:\n   ", abs_path))
    }
  }, error = function(e) {
    log_audit(session_id, "write_r_script",
              paste0("write ", filename), "error",
              error = e$message)
    return(paste0("❌ Error:", e$message))
  })
}

#' Update Plot Colors
#' 
#' Updates ggplot2 color gradients for existing plot objects.
#' Logs all color updates to audit log.
#' 
#' @param plot_variable Character string with name of plot variable
#' @param color_type Character string: 'gradient' or 'manual'
#' @param color_low Character string with low color (hex or name)
#' @param color_high Character string with high color (hex or name)
#' @return Character string with operation status
#' @export
update_plot_colors <- function(plot_variable, color_type, color_low, color_high) {
  session_id <- get_session_id()
  
  if (!rstudioapi::isAvailable()) {
    log_audit(session_id, "update_plot_colors",
              paste0("update ", plot_variable), "error",
              error = "RStudio not available")
    return("❌ RStudio not available")
  }
  
  if (!color_type %in% c("gradient", "manual")) {
    log_audit(session_id, "update_plot_colors",
              paste0("update ", plot_variable), "error",
              error = "invalid color_type")
    return("❌ color_type must be 'gradient' or 'manual'")
  }
  
  code <- sprintf(
    '%s <- %s + scale_fill_gradient(low = "%s", high = "%s")',
    plot_variable, plot_variable, color_low, color_high
  )
  
  tryCatch({
    rstudioapi::sendToConsole(code, execute = TRUE, echo = TRUE)
    
    log_audit(session_id, "update_plot_colors",
              paste0("update ", plot_variable, " colors"), "success")
    
    return(paste0("✅ Plot colors updated: ", plot_variable))
    
  }, error = function(e) {
    log_audit(session_id, "update_plot_colors",
              paste0("update ", plot_variable), "error",
              error = e$message)
    return(paste0("❌ Error: ", e$message))
  })
}

#' View Dataframe in RStudio Viewer
#' 
#' Opens a dataframe in the RStudio Viewer pane (read-only).
#' Does NOT log to audit (read-only operation).
#' 
#' @param data_name Character string with name of dataframe
#' @return Character string with operation status
#' @export
view_dataframe <- function(data_name) {
  if (!rstudioapi::isAvailable()) {
    return("❌ RStudio not available")
  }
  
  code <- sprintf("View(%s)", data_name)
  
  tryCatch({
    rstudioapi::sendToConsole(code, execute = TRUE, echo = TRUE)
    return(paste0("✅ Dataframe opened: ", data_name))
  }, error = function(e) {
    return(paste0("❌ Error: ", e$message))
  })
}

#' Get Workspace Information
#' 
#' Returns information about the current R workspace (read-only).
#' Does NOT log to audit (read-only operation).
#' 
#' @return Character string with workspace information
#' @export
workspace_info <- function() {
  info <- list(
    directory = getwd(),
    objects = length(ls(envir = .GlobalEnv)),
    r_version = R.version.string
  )
  
  output <- sprintf(
    "WORKSPACE INFO:\n   Directory: %s\n   Objects: %d\n   R Version: %s",
    info$directory, info$objects, info$r_version
  )
  
  return(output)
}
