# Test Audit System
# Run this to test the audit logging functionality

library(direct)

# Initialize audit config if not exists
if (!file.exists(".direct/config.yml")) {
  init_audit_config()
}

cat("=== Testing Audit System ===\n\n")

# Test 1: Successful code execution
cat("Test 1: Successful code execution\n")
run_r_code("x <- 1:10; mean(x)")

# Test 2: Blocked command
cat("\nTest 2: Blocked command (system call)\n")
run_r_code("system('echo hello')")

# Test 3: Write file
cat("\nTest 3: Write file\n")
write_r_script("test_audit.R", "# Test script\nprint('Hello from test')")

# Test 4: PII in command (should be sanitized in log)
cat("\nTest 4: Command with PII\n")
run_r_code("email <- 'max.mustermann@example.com'")

# Test 5: View audit log
cat("\n=== Audit Log (last 5 entries) ===\n")
show_audit(last_n = 5)

# Test 6: Show statistics
cat("\n=== Audit Statistics ===\n")
audit_stats()

# Test 7: Export audit
cat("\n=== Exporting Audit ===\n")
export_audit("test_audit_export.csv")

cat("\n✅ All tests completed!\n")
cat("Check the following files:\n")
cat("  - .direct/audit.log (full audit log)\n")
cat("  - test_audit_export.csv (sanitized export)\n")
cat("  - test_audit.R (test script created)\n")
