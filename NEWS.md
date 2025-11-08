# direct 0.1.0

## Initial Release

### Features

* Core MCP tools for Claude Desktop integration
  - `run_r_code()`: Execute R code with security checks
  - `safe_write_file()`: Write files within workspace only
  - `write_r_script()`: Intelligent file creation for R, Rmd, qmd, etc.
  - `update_plot_colors()`: Update ggplot2 color schemes
  - `view_dataframe()`: Open dataframes in RStudio Viewer
  - `workspace_info()`: Get workspace information

### Setup Functions

* `init_project()`: Initialize direct in RStudio project
* `show_claude_config()`: Display MCP configuration for Claude Desktop
* `check_setup()`: Verify installation and configuration

### Security

* Path traversal protection (blocks `../` patterns)
* Workspace-only file operations
* Dangerous command detection and blocking
* Existing file protection (no overwriting)

### Documentation

* Comprehensive README with quick start guide
* Function documentation via roxygen2
* Development notes for contributors
* Example MCP configuration templates

---

### Breaking Changes

None (initial release)

### Bug Fixes

None (initial release)

### Deprecated

None (initial release)
