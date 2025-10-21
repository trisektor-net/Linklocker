#!/usr/bin/env bash
# Fast project verification for LinkLocker (Flutter + Supabase)
# - Lightweight structure checks
# - flutter pub get / analyze
# - Conditional tests (skips if none)
# - Optional WASM dry-run build for web
# Safe defaults; clear output.

set -euo pipefail

# ---- Styling ----
GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; CYAN="\033[36m"; BOLD="\033[1m"; RESET="\033[0m"
ok(){ echo -e "${GREEN}✅ $*${RESET}"; }
warn(){ echo -e "${YELLOW}⚠️  $*${RESET}"; }
info(){ echo -e "${CYAN}🔍 $*${RESET}"; }
fail(){ echo -e "${RED}❌ $*${RESET}"; }

# ---- Helpers ----
ensure_in_repo_root() {
  if [[ ! -f "pubspec.yaml" ]]; then
    fail "Run this from the project root (pubspec.yaml not found)."
    exit 1
  fi
}

has_tests() {
  shopt -s nullglob
  local files=(test/*_test.dart)
  [[ ${#files[@]} -gt 0 ]]
}

has_flutter() {
  command -v flutter >/dev/null 2>&1
}

# ---- Start ----
ensure_in_repo_root

echo -e "${BOLD}LinkLocker – Verify & Build${RESET}"
echo

# 1) Structure check (fast & minimal; warns if optional files missing)
info "Verifying project structure..."
req=( "lib/main.dart" "pubspec.yaml" )
opt=(
  "lib/screens/auth_screen.dart"
  "lib/screens/link_editor_screen.dart"
  "lib/screens/public_profile_screen.dart"
  "lib/screens/analytics_screen.dart"
  "assets/.env"
  "supabase/schemas/clicks.sql"
  "supabase/schemas/leads.sql"
  "tracker.md"
)

for f in "${req[@]}"; do
  [[ -f "$f" ]] && ok "Found: $f" || { fail "Missing required: $f"; exit 1; }
done

for f in "${opt[@]}"; do
  [[ -f "$f" ]] && ok "Found: $f" || warn "Optional missing: $f"
done
echo

# 2) Flutter env
info "Checking Flutter environment..."
if ! has_flutter; then
  fail "Flutter not found in PATH. Install or add to PATH and retry."
  exit 1
fi
flutter --version || { fail "Flutter not responding."; exit 1; }
ok "Flutter detected."
echo

# 3) Dependencies
info "Running pub get..."
flutter pub get
ok "Dependencies resolved."
echo

# 4) Static analysis
info "Running flutter analyze..."
flutter analyze
ok "Static analysis passed."
echo

# 5) Tests (only if present)
if has_tests; then
  info "Running tests..."
  # Use expanded reporter for clarity; do not fail the whole script on a single flaky test unless you want to.
  if flutter test --reporter expanded; then
    ok "Tests passed."
  else
    fail "Tests failed."
    exit 1
  fi
else
  warn "No *_test.dart files found under /test – skipping tests."
fi
echo

# 6) Web WASM dry-run build (optional; continues on error)
info "Attempting web WASM dry-run build (optional)..."
if flutter build web --wasm --release --no-tree-shake-icons --pwa-strategy=none --base-href=/ --no-source-maps; then
  ok "WASM dry-run succeeded."
else
  warn "WASM dry-run failed (non-blocking for dev)."
fi
echo

ok "Verification complete! Ready to continue development."
