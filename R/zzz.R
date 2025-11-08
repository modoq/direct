# Package initialization and MCP tool registration
# This file is automatically sourced when the package is loaded

.onAttach <- function(libname, pkgname) {
  packageStartupMessage("✅ direct loaded - The Director is ready! 🎬")
  packageStartupMessage("📁 Workspace: ", getwd())
  packageStartupMessage("")
  packageStartupMessage("💡 Quick start:")
  packageStartupMessage("   - init_project()      : Initialize current project")
  packageStartupMessage("   - show_claude_config(): Get Claude Desktop config")
  packageStartupMessage("   - check_setup()       : Verify installation")
}

# Export MCP tools for mcptools package
.onLoad <- function(libname, pkgname) {
  
  # Check if mcptools is available
  if (!requireNamespace("mcptools", quietly = TRUE)) {
    return(invisible(NULL))
  }
  
  # Check if ellmer is available
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    return(invisible(NULL))
  }
  
  # Register MCP tools if both packages are available
  tryCatch({
    # Create MCP tool definitions using ellmer::tool()
    tools_list <- list(
      ellmer::tool(
        run_r_code,
        name = "run_r_code",
        description = "Executes R code. BLOCKS dangerous operations (system, file.remove, etc.)",
        arguments = list(
          code = ellmer::type_string("The R code to execute"),
          echo = ellmer::type_boolean("Echo in Console (default: TRUE)")
        )
      ),
      
      ellmer::tool(
        safe_write_file,
        name = "safe_write_file",
        description = "Writes files ONLY in current R working directory. Paths outside workspace are blocked.",
        arguments = list(
          filename = ellmer::type_string("Filename (relative to workspace)"),
          content = ellmer::type_string("File content as string")
        )
      ),
      
      ellmer::tool(
        write_r_script,
        name = "write_r_script",
        description = "Writes files in workspace with intelligent extension detection. Automatically appends .R only for R scripts. Supports: .Rmd, .qmd, .Rnw, .csv, .json, .md, .yaml, etc. without modification.",
        arguments = list(
          filename = ellmer::type_string("Filename with extension (e.g. 'report.Rmd' or 'script.R')"),
          code = ellmer::type_string("File content")
        )
      ),
      
      ellmer::tool(
        update_plot_colors,
        name = "update_plot_colors",
        description = "Updates plot colors safely",
        arguments = list(
          plot_variable = ellmer::type_string("Name of plot variable"),
          color_type = ellmer::type_string("'gradient' or 'manual'"),
          color_low = ellmer::type_string("Low color"),
          color_high = ellmer::type_string("High color")
        )
      ),
      
      ellmer::tool(
        view_dataframe,
        name = "view_dataframe",
        description = "Opens dataframe in RStudio Viewer (read-only)",
        arguments = list(
          data_name = ellmer::type_string("Name of dataframe")
        )
      ),
      
      ellmer::tool(
        workspace_info,
        name = "workspace_info",
        description = "Shows workspace information (safe, read-only)",
        arguments = list()
      )
    )
    
    # Store tools in package namespace for access by mcptools
    assign("mcp_tools", tools_list, envir = parent.env(environment()))
    
  }, error = function(e) {
    # Silently fail if tool registration fails
    # Tools will still be available as regular functions
  })
  
  invisible(NULL)
}
