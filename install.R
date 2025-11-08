#!/usr/bin/env Rscript
# Installation script for direct package

cat("\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("🎬 DIRECT PACKAGE INSTALLATION\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("\n")

# Check for required packages
cat("📦 Checking dependencies...\n")

packages_needed <- c("remotes", "roxygen2", "devtools", "ellmer", "rstudioapi", "mcptools")
packages_missing <- packages_needed[!sapply(packages_needed, requireNamespace, quietly = TRUE)]

if (length(packages_missing) > 0) {
  cat("⚠️  Missing packages:", paste(packages_missing, collapse = ", "), "\n")
  cat("📥 Installing missing packages...\n\n")
  
  install.packages(packages_missing)
  
  cat("\n✅ Dependencies installed\n\n")
} else {
  cat("✅ All dependencies present\n\n")
}

# Generate documentation
cat("📝 Generating documentation...\n")
roxygen2::roxygenise()
cat("✅ Documentation generated\n\n")

# Install package
cat("🔧 Installing direct package...\n")
devtools::install()
cat("✅ Package installed\n\n")

# Test installation
cat("🧪 Testing installation...\n")
library(direct)
cat("✅ Package loaded successfully\n\n")

cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("✨ INSTALLATION COMPLETE!\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("\n")
cat("Next steps:\n")
cat("  1. Navigate to your RStudio project\n")
cat("  2. Run: library(direct)\n")
cat("  3. Run: init_project()\n")
cat("  4. Run: show_claude_config()\n")
cat("  5. Add config to Claude Desktop\n")
cat("  6. Restart RStudio + Claude Desktop\n")
cat("\n")
cat("📚 Documentation: ?direct\n")
cat("🐛 Issues: https://github.com/modoq/direct/issues\n")
cat("\n")
