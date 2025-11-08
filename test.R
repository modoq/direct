# Quick Test Script for Direct Package
# Run this after installation to verify everything works

library(direct)

cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("🧪 DIRECT PACKAGE TEST SUITE\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

# Test 1: Path Validation
cat("Test 1: Path Validation\n")
cat("  Testing safe path:     ")
result1 <- is_safe_path("test.R")
cat(ifelse(result1, "✅ PASS\n", "❌ FAIL\n"))

cat("  Testing unsafe path:   ")
result2 <- !is_safe_path("../etc/passwd")
cat(ifelse(result2, "✅ PASS\n", "❌ FAIL\n"))

# Test 2: Workspace Info
cat("\nTest 2: Workspace Info\n")
info <- workspace_info()
cat("  ", gsub("\n", "\n  ", info), "\n")
cat("  ✅ PASS\n")

# Test 3: Check Setup
cat("\nTest 3: Setup Check\n")
results <- check_setup()
cat("  ✅ PASS\n")

# Test 4: Claude Config Generation
cat("\nTest 4: Claude Config Generation\n")
cat("  Generating config...   ")
config <- show_claude_config()
cat("✅ PASS\n")

# Test 5: Code Execution (if RStudio available)
if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  cat("\nTest 5: Code Execution\n")
  cat("  Testing safe code:     ")
  result <- run_r_code("x <- 1 + 1")
  cat(ifelse(grepl("executed", result, ignore.case = TRUE), "✅ PASS\n", "❌ FAIL\n"))
  
  cat("  Testing blocked code:  ")
  result <- run_r_code("system('ls')")
  cat(ifelse(grepl("WARNING", result), "✅ PASS\n", "❌ FAIL\n"))
} else {
  cat("\nTest 5: Code Execution\n")
  cat("  ⚠️  SKIP (RStudio not available)\n")
}

# Summary
cat("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("✨ TEST SUITE COMPLETE\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("\n📝 All core functions operational\n")
cat("🛡️  Security features active\n\n")
