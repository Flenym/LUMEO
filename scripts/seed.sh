#!/usr/bin/env bash
# seed.sh — apply SQL migrations to Postgres.
#
# Usage:
#   DATABASE_URL=postgres://user:pass@localhost:5432/lumeo ./scripts/seed.sh
#
# Applies Backend/migrations/*.sql in sorted order via psql.
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: DATABASE_URL is not set. Example:" >&2
  echo "  DATABASE_URL=postgres://user:pass@localhost:5432/lumeo ./scripts/seed.sh" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found (install PostgreSQL client)" >&2
  exit 1
fi

shopt -s nullglob
FILES=(Backend/migrations/*.sql)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "ERROR: no migration files in Backend/migrations/" >&2
  exit 1
fi

for F in "${FILES[@]}"; do
  echo "==> applying $F"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$F"
done

echo "OK: seed complete (${#FILES[@]} file(s) applied)"
