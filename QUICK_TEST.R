# ============================================================================
# DIRECT PACKAGE - QUICK TEST
# ============================================================================
# Run this in RStudio to test the audit system
# ============================================================================

cat("\n╔══════════════════════════════════════╗\n")
cat("║  DIRECT AUDIT SYSTEM - QUICK TEST   ║\n")
cat("╚══════════════════════════════════════╝\n\n")

# Setup
test_dir <- "~/Desktop/direct-test"
dir.create(test_dir, showWarnings = FALSE, recursive = TRUE)
setwd(test_dir)

cat("📁 Test directory:", getwd(), "\n\n")

# Load package
cat("Loading package...\n")
devtools::load_all("~/Desktop/direct")
cat("✅ Loaded\n\n")

# Initialize
cat("Initializing project...\n")
init_project(force = TRUE)
cat("\n")

# Test 1: Successful execution
cat("━━━ Test 1: Successful code execution ━━━\n")
result <- run_r_code("test_var <- 1:10; mean(test_var)")
cat("Result:", result, "\n\n")

# Test 2: Blocked command
cat("━━━ Test 2: Blocked command ━━━\n")
result <- run_r_code("system('echo hello')")
cat("Result:", result, "\n\n")

# Test 3: Code with PII
cat("━━━ Test 3: Code with PII ━━━\n")
result <- run_r_code("email <- 'max.mustermann@example.com'")
cat("Result:", result, "\n\n")

# Test 4: Write script with PII
cat("━━━ Test 4: Write script with PII ━━━\n")
result <- write_r_script("analysis.R", 
  "# Analysis for max.mustermann@example.com\n# Phone: +49-123-456789\nprint('test')")
cat("Result:", result, "\n\n")

# Test 5: Check audit log exists
cat("━━━ Test 5: Check audit log ━━━\n")
if (file.exists(".direct/audit.log")) {
  cat("✅ Audit log exists\n")
  cat("   Size:", file.size(".direct/audit.log"), "bytes\n")
  cat("   Lines:", length(readLines(".direct/audit.log", warn = FALSE)), "\n\n")
} else {
  cat("❌ Audit log NOT found!\n\n")
}

# Test 6: Show audit (sanitized)
cat("━━━ Test 6: Show audit (sanitized) ━━━\n")
df <- show_audit()
cat("\n")

# Test 7: Show audit (full)
cat("━━━ Test 7: Show audit (full - with PII) ━━━\n")
df_full <- show_audit(sanitize = FALSE)
cat("\n")

# Test 8: Compare cmd vs cmd_sanitized
cat("━━━ Test 8: Verify PII redaction ━━━\n")
if (requireNamespace("jsonlite", quietly = TRUE)) {
  lines <- readLines(".direct/audit.log", warn = FALSE)
  if (length(lines) > 0) {
    # Find entry with PII
    for (line in lines) {
      entry <- jsonlite::fromJSON(line)
      if (entry$cmd != entry$cmd_sanitized) {
        cat("Found PII redaction:\n")
        cat("  Original:", substr(entry$cmd, 1, 60), "\n")
        cat("  Sanitized:", substr(entry$cmd_sanitized, 1, 60), "\n")
        cat("✅ PII redaction works!\n\n")
        break
      }
    }
  }
}

# Test 9: Export
cat("━━━ Test 9: Export audit ━━━\n")
export_audit("test_export.csv")
cat("\n")

# Test 10: Statistics
cat("━━━ Test 10: Audit statistics ━━━\n")
audit_stats()
cat("\n")

# Summary
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("SUMMARY\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

cat("Files created:\n")
list.files(all.files = TRUE, recursive = TRUE)

cat("\n\n╔══════════════════════════════════════╗\n")
cat("║  ✅ TESTS COMPLETED                  ║\n")
cat("╚══════════════════════════════════════╝\n\n")

cat("Check these files manually:\n")
cat("  1. .direct/audit.log (JSONL format)\n")
cat("  2. test_export.csv (sanitized CSV)\n")
cat("  3. analysis.R (created file)\n\n")

cat("Try these commands:\n")
cat("  • show_audit() - View sanitized\n")
cat("  • show_audit(sanitize = FALSE) - View full\n")
cat("  • show_audit(tool = 'run_r_code') - Filter by tool\n")
cat("  • show_audit(status = 'blocked') - Show blocked\n\n")
