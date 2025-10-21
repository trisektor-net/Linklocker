#!/usr/bin/env bash
set -euo pipefail

echo "🔎 Supabase schema verification (optional)"

# Requires a Postgres connection string in DATABASE_URL (GitHub Secret)
# Example: postgres://USER:PASSWORD@HOST:PORT/DATABASE
if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ℹ️  DATABASE_URL not set; skipping remote schema verification."
  exit 0
fi

# Ensure psql exists; install if needed (runner is Ubuntu)
if ! command -v psql >/dev/null 2>&1; then
  echo "Installing psql client..."
  sudo apt-get update -y
  sudo apt-get install -y postgresql-client
fi

echo "Checking required tables exist in remote DB..."

REQUIRED_TABLES=("profiles" "links" "clicks" "leads")
MISSING=()

for t in "${REQUIRED_TABLES[@]}"; do
  EXISTS=$(psql "$DATABASE_URL" -tAc "SELECT to_regclass('public.$t') IS NOT NULL;")
  if [[ "$EXISTS" != "t" ]]; then
    MISSING+=("$t")
  fi
done

if (( ${#MISSING[@]} > 0 )); then
  echo "❌ Missing tables in remote DB: ${MISSING[*]}"
  echo "Hint: push your schema/migrations or seed using Supabase."
  exit 1
fi

echo "✅ Remote DB has all required tables."
