# Bug Fixes - Issues from User Testing

## Issue 1: check_setup() says "Setup looks good!" when .Rprofile missing

**Problem:**
```r
check_setup()
# Shows: ⚠️  .Rprofile NOT found in project
#        Run: init_project()
# But then: ✅ Setup looks good!  ← WRONG!
```

**Root Cause:**
`check_setup()` only checked if packages were installed, not if project was initialized.

**Fix:**
```r
# Before (R/setup.R):
all_ok <- all(unlist(results[c("direct_installed", "mcptools_installed", "ellmer_installed")]))
if (all_ok) {
  message("✅ Setup looks good!")
}

# After:
packages_ok <- all(unlist(results[c("direct_installed", "mcptools_installed", "ellmer_installed")]))
project_ok <- results$rprofile_exists

if (packages_ok && project_ok) {
  message("✅ Setup complete and ready to use!")
} else if (packages_ok && !project_ok) {
  message("⚠️  Packages installed, but project not initialized")
  message("   Run: init_project()")
} else {
  message("⚠️  Some packages missing - see above for details")
}
```

**Result:**
Now correctly warns when project is not initialized.

---

## Issue 2: Project doesn't persist after RStudio restart

**Problem:**
User creates new directory, runs `init_project()`, but after RStudio restart it goes back to old project.

**Root Cause:**
`init_project()` only created `.Rprofile`, but RStudio needs a `.Rproj` file to remember a project.

**Fix:**
Updated `init_project()` to also create `.Rproj` file:

```r
# New code in init_project():
project_name <- basename(getwd())  # Or user-provided
rproj_path <- file.path(getwd(), paste0(project_name, ".Rproj"))

if (!file.exists(rproj_path)) {
  rproj_content <- c(
    "Version: 1.0",
    "",
    "RestoreWorkspace: Default",
    "SaveWorkspace: Default",
    "AlwaysSaveHistory: Default",
    "",
    "EnableCodeIndexing: Yes",
    "UseSpacesForTab: Yes",
    "NumSpacesForTab: 2",
    "Encoding: UTF-8",
    "",
    "RnwWeave: Sweave",
    "LaTeX: pdfLaTeX"
  )
  writeLines(rproj_content, rproj_path)
  message("✅ Created: ", basename(rproj_path))
}
```

**New Parameter:**
```r
init_project(project_name = "my-analysis")  # Optional: custom name
```

**Updated .gitignore:**
Changed from `*.Rproj` (ignores all) to `direct.Rproj` (only package's own).

**Updated Messages:**
```
Next steps:
  1. Close and reopen this project in RStudio
     File → Recent Projects → <project-name>.Rproj
  2. Run show_claude_config() ...
```

---

## Files Modified

1. ✅ `R/setup.R`
   - Fixed `check_setup()` logic
   - Added `.Rproj` creation to `init_project()`
   - Added `project_name` parameter
   - Updated success messages

2. ✅ `.gitignore`
   - Changed `*.Rproj` → `direct.Rproj`
   - User projects can now have `.Rproj` files

3. ✅ `README.md`
   - Added workflow for creating new project directory
   - Added `check_setup()` verification step
   - Updated "Restart Everything" instructions
   - Added expected output examples

---

## Testing the Fixes

### Test Scenario 1: New Project
```r
# Create new directory
dir.create("~/test-project")
setwd("~/test-project")

# Initialize
library(direct)
init_project()

# Expected output:
# ✅ Created: test-project.Rproj
# ✅ Project initialized successfully!
# 📁 Created: .Rprofile
# 📁 Created: .direct/config.yml

# Verify
check_setup()
# Should show: ✅ Setup complete and ready to use!

# Close RStudio, reopen via File → Recent Projects → test-project.Rproj
# Project should persist!
```

### Test Scenario 2: Incomplete Setup
```r
# In directory without .Rprofile
setwd("~/some-directory")
check_setup()

# Expected output:
# ✅ direct package installed
# ✅ mcptools package installed
# ✅ ellmer package installed
# ⚠️  .Rprofile NOT found in project
#    Run: init_project()
# ✅ RStudio available
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ⚠️  Packages installed, but project not initialized  ← CORRECT!
#    Run: init_project()
```

---

## User Workflow (Improved)

**Before:**
1. Create directory
2. `setwd()` to it
3. `init_project()`
4. Restart RStudio → ❌ Back at old project

**After:**
1. Create directory
2. `setwd()` to it
3. `init_project()` → Creates `.Rproj`
4. Close RStudio
5. File → Recent Projects → `<project>.Rproj` → ✅ Project persists!

---

## Commit Message

```
fix: check_setup() and init_project() improvements

- Fix check_setup() to distinguish between packages and project setup
  * Now warns "Packages installed, but project not initialized" correctly
  * Only shows "Setup complete" when both packages AND project ready

- Add .Rproj file creation to init_project()
  * Ensures RStudio remembers the project after restart
  * Optional project_name parameter for custom naming
  * Only creates if .Rproj doesn't exist yet

- Update .gitignore to allow user .Rproj files
  * Changed *.Rproj -> direct.Rproj
  * User projects can now have .Rproj committed if needed

- Update README with improved workflow
  * Show directory creation step
  * Add check_setup() verification
  * Clarify project reopening instructions

Fixes issues reported in user testing where:
1. check_setup() said "looks good" when .Rprofile was missing
2. Projects didn't persist after RStudio restart (missing .Rproj)
```

---

**Status:** Ready for testing ✅  
**Date:** 2025-11-08  
**Next:** User tests the fixes
