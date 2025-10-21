# LinkLocker Patch Workflow – Android Studio + GitHub

This repository supports **patch-based updates**.  
Follow these steps whenever you receive a `.patch` file.

------------------------------------------------------------
1. Save the patch
------------------------------------------------------------
Place the `.patch` file in this folder:
tools/patches/

Example:
tools/patches/day4_update.patch

------------------------------------------------------------
2. Apply the patch
------------------------------------------------------------
Run this command inside your project root:
git apply --3way tools/patches/<file>.patch

Example:
git apply --3way tools/patches/day4_update.patch

If you see “No valid patches in input”, the file may be rich text (RTF).
Download it again as plain text.

------------------------------------------------------------
3. Verify the project
------------------------------------------------------------
Run this script to make sure everything is correct:
bash tools/verify_and_build.sh

It will check:
- Folder structure
- Flutter analyze
- Flutter test
- WASM web build

------------------------------------------------------------
4. Commit and push
------------------------------------------------------------
After verifying, finalize the patch:
git add -A
git commit -m "apply: <patch name>"
git push origin main
