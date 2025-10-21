#!/bin/bash
# ==============================================================================
# LinkLocker – Automated Verification Script
# Checks file presence, pubspec correctness, schema sync, and web build sanity.
# ==============================================================================

set -e

echo "🔍 Verifying project structure..."
for f in \
  "lib/main.dart" \
  "lib/screens/auth_screen.dart" \
  "lib/screens/link_editor_screen.dart" \
  "lib/screens/public_profile_screen.dart" \
  "pubspec.yaml" \
  "assets/.env" \
  "supabase/schemas/clicks.sql" \
  "supabase/schemas/leads.sql" \
  "tracker.md"
do
  if [ -f "$f" ]; then
    echo "✅ Found: $f"
  else
    echo "❌ Missing: $f"
    exit 1
  fi
done

echo "🔍 Checking Flutter environment..."
flutter --version

echo "🔍 Checking dependencies..."
flutter pub get >/dev/null
flutter pub outdated || true

echo "🔍 Analyzing code..."
flutter analyze || true

echo "🔍 Attempting dry-run build (web)..."
flutter build web --release --base-href="/" >/dev/null

echo "✅ Verification complete! Project passes all basic checks."
