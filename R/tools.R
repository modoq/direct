# ============================================================================
# MCP Tools for Claude Desktop + RStudio Integration
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

#' Execute R Code in RStudio Console
#' 
#' Executes R code with security checks to block dangerous operations.
#' 
#' @param code Character string containing R code to execute
#' @param echo Logical indicating whether to echo code in console (default: TRUE)
#' @return Character string with execution status
#' @export
run_r_code <- function(code, echo = TRUE) {
  if (!rstudioapi::isAvailable()) {
    return("Error: RStudio is not available.")
  }
  
  # Warn about dangerous operations
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
      warning_msg <- paste0(
        "⛔ WARNING: Potentially dangerous command detected!\n",
        "Pattern: ", pattern, "\n",
        "Code will NOT be executed.\n"
      )
      return(warning_msg)
    }
  }
  
  rstudioapi::sendToConsole(code, execute = TRUE, echo = echo)
  return("✅ Code executed")
}

#' Safe File Writing (Workspace Only)
#' 
#' Writes files only within the current R workspace. Blocks writing outside
#' workspace and prevents overwriting existing files.
#' 
#' @param filename Character string with filename (relative to workspace)
#' @param content Character string with file content
#' @return Character string with operation status
#' @export
safe_write_file <- function(filename, content) {
  # Validate path
  if (!is_safe_path(filename)) {
    return(paste0(
      "⛔ ERROR: Writing outside workspace NOT allowed!\n",
      "Workspace: ", getwd(), "\n",
      "Attempted path: ", filename, "\n",
      "❌ Only files in current workspace can be written."
    ))
  }
  
  # Check if file already exists
  if (file.exists(filename)) {
    return(paste0(
      "⚠️ WARNING: File already exists!\n",
      "File: ", filename, "\n",
      "Use a different name or delete the file first."
    ))
  }
  
  tryCatch({
    writeLines(content, filename)
    abs_path <- normalizePath(filename)
    
    if (rstudioapi::isAvailable()) {
      msg <- sprintf("cat('✅ File created: %s\\n')", basename(filename))
      rstudioapi::sendToConsole(msg, execute = TRUE, echo = FALSE)
    }
    
    return(paste0("✅ File created:\n   ", abs_path))
  }, error = function(e) {
    return(paste0("❌ Error writing file:\n   ", e$message))
  })
}

#' Write R Scripts and Reports
#' 
#' Writes R scripts, R Markdown, Quarto and other files with intelligent
#' extension detection. Only appends .R for pure R scripts.
#' 
#' @param filename Character string with filename (with extension)
#' @param code Character string with file content
#' @return Character string with operation status
#' @export
write_r_script <- function(filename, code) {
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
      return(paste0(
        "⛔ SECURITY WARNING: Dangerous code detected!\n",
        "Pattern: ", pattern, "\n",
        "Script will NOT be created."
      ))
    }
  }
  
  if (file.exists(filename)) {
    return(paste0(
      "⚠️ WARNING: File already exists!\n",
      "File: ", filename
    ))
  }
  
  tryCatch({
    writeLines(code, filename)
    abs_path <- normalizePath(filename)
    
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
    return(paste0("❌ Error:", e$message))
  })
}

#' Update Plot Colors
#' 
#' Updates ggplot2 color gradients for existing plot objects.
#' 
#' @param plot_variable Character string with name of plot variable
#' @param color_type Character string: 'gradient' or 'manual'
#' @param color_low Character string with low color (hex or name)
#' @param color_high Character string with high color (hex or name)
#' @return Character string with operation status
#' @export
update_plot_colors <- function(plot_variable, color_type, color_low, color_high) {
  if (!rstudioapi::isAvailable()) {
    return("❌ RStudio not available")
  }
  
  if (!color_type %in% c("gradient", "manual")) {
    return("❌ color_type must be 'gradient' or 'manual'")
  }
  
  code <- sprintf(
    '%s <- %s + scale_fill_gradient(low = "%s", high = "%s")',
    plot_variable, plot_variable, color_low, color_high
  )
  
  rstudioapi::sendToConsole(code, execute = TRUE, echo = TRUE)
  return(paste0("✅ Plot colors updated: ", plot_variable))
}

#' View Dataframe in RStudio Viewer
#' 
#' Opens a dataframe in the RStudio Viewer pane (read-only).
#' 
#' @param data_name Character string with name of dataframe
#' @return Character string with operation status
#' @export
view_dataframe <- function(data_name) {
  if (!rstudioapi::isAvailable()) {
    return("❌ RStudio not available")
  }
  
  code <- sprintf("View(%s)", data_name)
  rstudioapi::sendToConsole(code, execute = TRUE, echo = TRUE)
  return(paste0("✅ Dataframe opened: ", data_name))
}

#' Get Workspace Information
#' 
#' Returns information about the current R workspace (read-only).
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
