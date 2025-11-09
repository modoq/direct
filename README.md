# direct 🎬

> MCP Tools for Claude Desktop + RStudio Integration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**direct** provides Model Context Protocol (MCP) tools that enable Claude Desktop to interact directly with your RStudio projects. Built on top of [`btw`](https://github.com/posit-dev/btw) (passive observation), **direct** adds active execution capabilities with built-in security features.

## 🎭 Concept

- **btw watches** 👁️ - Passive observation of workspace
- **direct directs** 🎬 - Active execution and file operations

## ✨ Features

- ✅ **Safe Code Execution** - Run R code with security checks
- ✅ **Workspace-Only File Operations** - Write files only in project directory
- ✅ **Path Traversal Protection** - Blocks `../` attacks
- ✅ **Dangerous Command Detection** - Prevents system calls, file deletion, etc.
- ✅ **Intelligent File Type Handling** - Auto-detects `.Rmd`, `.qmd`, `.R` and more
- ✅ **RStudio Integration** - View dataframes, update plots, manage workspace

## 📦 Installation

```r
# Install from GitHub
remotes::install_github("modoq/direct")

# Install dependencies (if not already installed)
install.packages(c("btw", "mcptools", "ellmer", "rstudioapi"))
```

## 🚀 Quick Start

### 1. Install and Initialize

**IMPORTANT:** After installation, you must initialize direct in each project where you want to use it.

```r
# Load the package
library(direct)

# Create a new project directory (or navigate to existing one)
dir.create("~/my-analysis-project")
setwd("~/my-analysis-project")

# Initialize direct in this project
init_project()
```

This creates:
- `.Rprofile` - Auto-loads direct when project opens
- `<project-name>.Rproj` - RStudio project file (if none exists)
- `.direct/config.yml` - Audit configuration

**Important:** Close and reopen the project in RStudio for `.Rprofile` to take effect:
- File → Recent Projects → Select your project

### 2. Configure Claude Desktop

```r
# Display the configuration you need
show_claude_config()
```

Copy the displayed JSON configuration and add it to your Claude Desktop config file:

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\\Claude\\claude_desktop_config.json`  
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

The configuration will look like this:

```json
{
  "mcpServers": {
    "r-direct": {
      "command": "Rscript",
      "args": [
        "-e",
        "direct::start_mcp_server()"
      ]
    }
  }
}
```

### 3. Restart Everything

1. **Close and reopen your project** - File → Recent Projects → Select your project
2. **Restart Claude Desktop** - Completely quit and restart so it loads the MCP server

You should see a welcome message in RStudio Console:
```
✅ Direct + btw session registered
📁 Workspace: /path/to/your/project
🎬 Direct tools: Active execution with security
📊 btw tools: Passive observation and documentation
```

### 4. Verify Setup

```r
# Check that everything is configured correctly
check_setup()
```

Expected output when ready:
```
✅ direct package installed
✅ mcptools package installed
✅ ellmer package installed
✅ .Rprofile exists in project
✅ RStudio available
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Setup complete and ready to use!
```

## 🛠️ Available Tools

### Code Execution

```r
# Execute R code (with security checks)
run_r_code("x <- 1:10; summary(x)")
```

**Blocked operations**: `system()`, `shell()`, `file.remove()`, `unlink()`, `Sys.setenv()`, `setwd()`, `source()`

### File Operations

```r
# Write a simple file
safe_write_file("data.csv", "x,y\n1,2\n3,4")

# Write R scripts, R Markdown, Quarto, etc.
write_r_script("analysis.R", "library(tidyverse)\n\ndata <- read_csv('data.csv')")
write_r_script("report.Rmd", "---\ntitle: My Report\n---\n\n# Analysis")
write_r_script("dashboard.qmd", "---\ntitle: Dashboard\nformat: html\n---")
```

**Security features**:
- ✅ Files only written to current workspace
- ✅ Path traversal blocked (`../` not allowed)
- ✅ Existing files protected (no overwriting)
- ✅ Intelligent extension handling (`.Rmd`, `.qmd`, `.R`, etc.)

### Workspace Management

```r
# View dataframe in RStudio Viewer
view_dataframe("mtcars")

# Get workspace information
workspace_info()

# Update ggplot2 colors
update_plot_colors("my_plot", "gradient", "#FF0000", "#0000FF")
```

## 🔒 Security Features

**direct** implements multiple layers of security:

### Path Validation
- All file paths validated against workspace directory
- Path traversal patterns (`../`, `/..`) blocked immediately
- Absolute paths outside workspace rejected

### Command Filtering
- Dangerous R functions blocked: `system()`, `shell()`, `file.remove()`, `unlink()`
- Environment manipulation blocked: `Sys.setenv()`, `setwd()`
- Code injection vectors: `source()` blocked

### File Protection
- Existing files cannot be overwritten
- Files created only in workspace directory
- Read-only operations for viewing data

### Output Sanitization
- Secrets automatically redacted before sending to AI (API keys, passwords, tokens)
- Environment variable outputs filtered
- Private key patterns removed

### Audit Logging
All tool executions are logged to `.direct/audit.log` with:
- ✅ Full command (for forensic analysis)
- ✅ PII-sanitized version (for safe sharing)
- ✅ Timestamp, session ID, status
- ✅ No automatic deletion (user control)

```r
# View recent audit entries (sanitized by default)
show_audit()

# View full commands (may contain PII)
show_audit(sanitize = FALSE)

# Export audit log (always sanitized)
export_audit("audit_2025-11.csv")

# Get audit statistics
audit_stats()

# Initialize/customize audit config
init_audit_config()
```

The audit log is stored in `.direct/audit.log` (automatically added to `.gitignore`) and uses JSONL format for easy parsing.

**PII Redaction**: The audit system automatically detects and redacts:
- Email addresses
- Names in quotes
- Phone numbers
- IBANs and credit card numbers
- IP addresses and UUIDs

Custom patterns can be added in `.direct/config.yml`.

## 📚 Usage with Claude Desktop

Once configured, Claude can interact with your RStudio project:

**Example prompts**:

> "Create an R Markdown report that analyzes the mtcars dataset"

> "Write a script that loads tidyverse and creates a scatter plot"

> "Show me the first 10 rows of my dataframe `df`"

> "Execute this code: `summary(lm(mpg ~ wt, data = mtcars))`"

Claude will use the **direct** tools automatically to:
- Write R scripts, R Markdown, and Quarto files
- Execute code in your RStudio console
- View and analyze data
- Create visualizations

## 🔧 Advanced Configuration

### Custom Project Paths

```r
# Show config for a specific project
show_claude_config("/path/to/my/other/project")
```

### Multiple Projects

Create separate MCP server entries in Claude Desktop config for different projects:

```json
{
  "mcpServers": {
    "project-analysis": {
      "command": "/Library/Frameworks/R.framework/Versions/Current/Resources/bin/R",
      "args": ["--slave", "--no-restore", "--no-save", "-e",
               "setwd('/Users/me/projects/analysis'); mcptools::mcp_session()"]
    },
    "project-dashboard": {
      "command": "/Library/Frameworks/R.framework/Versions/Current/Resources/bin/R",
      "args": ["--slave", "--no-restore", "--no-save", "-e",
               "setwd('/Users/me/projects/dashboard'); mcptools::mcp_session()"]
    }
  }
}
```

### Force Reinitialize

```r
# Overwrite existing .Rprofile
init_project(force = TRUE)
```

## 🤝 Related Projects

- [`btw`](https://github.com/posit-dev/btw) - Passive workspace observation (by Posit)
- [`mcptools`](https://github.com/cpsievert/mcptools) - MCP server for R
- [`ellmer`](https://github.com/hadley/ellmer) - LLM tool framework

## 📖 Documentation

```r
# View function documentation
?init_project
?run_r_code
?write_r_script
?safe_write_file
```

## 🐛 Troubleshooting

### "RStudio is not available"
Some features require RStudio. Make sure you're running R from RStudio, not terminal R.

### "Path outside workspace blocked"
**direct** restricts file operations to your project directory for security. Use relative paths or ensure files are in your workspace.

### MCP Server Not Connecting
1. Check `.Rprofile` exists in project: `file.exists(".Rprofile")`
2. Verify Claude Desktop config file path is correct
3. Ensure you restarted both RStudio and Claude Desktop
4. Run `check_setup()` to diagnose issues

### Tools Not Appearing in Claude
1. Restart Claude Desktop completely
2. Check Claude Desktop logs for MCP connection errors
3. Verify R path in config matches your system: `file.path(R.home("bin"), "R")`

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details

## 🙏 Acknowledgments

- Built on [`ellmer`](https://github.com/hadley/ellmer) for tool framework
- Inspired by [`btw`](https://github.com/posit-dev/btw) for passive observation
- Uses [`mcptools`](https://github.com/cpsievert/mcptools) for MCP server

## 📧 Contact

Questions or issues? [Open an issue](https://github.com/modoq/direct/issues)

---

**Remember**: btw watches 👁️, direct directs 🎬
