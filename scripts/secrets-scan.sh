#!/usr/bin/env bash
# secrets-scan.sh — fail CI if real secrets leaked into the repo.
#
# Flags:
#   JWT_SECRET=<non-empty real value>            (empty placeholders in *.env.example are OK)
#   BEGIN ... PRIVATE KEY                        (any .pem-like block outside docs of the scanner itself)
#   password_hash with a value outside SQL DDL   (migrations DDL `password_hash TEXT NOT NULL` is ALLOWED)
#   apns/push keys with values                    (empty placeholders in *.env.example are OK)
#
# Allowlist:
#   * any *.env.example file (root .env.example + Backend/.env.example hold EMPTY/dummy placeholders only)
#   * Backend/migrations/*.sql for the password_hash DDL pattern
#
# Also verifies Backend/.env.example exists and holds dummy-only values.
set -euo pipefail

FAIL=0

echo "==> secrets-guard: scanning tracked files"
RAW_MATCHES="$(grep -rEn --exclude-dir=node_modules --exclude-dir=.git \
  --exclude-dir=dist --exclude-dir=DerivedData --exclude-dir=build \
  --exclude='*.env.example' --exclude='secrets-scan.sh' \
  -e "JWT_SECRET\s*=\s*\"\S+\"" \
  -e "JWT_SECRET\s*=\s*'\S+'" \
  -e 'JWT_SECRET\s*=\s*[^[:space:]"'\'']' \
  -e "JWT_REFRESH_SECRET\s*=\s*\"\S+\"" \
  -e "JWT_REFRESH_SECRET\s*=\s*'\S+'" \
  -e 'JWT_REFRESH_SECRET\s*=\s*[^[:space:]"'\'']' \
  -e 'BEGIN [A-Z ]*PRIVATE KEY' \
  -e 'apns[_-]?key[^[:space:]]*\s*[:=]\s*\S+' \
  . 2>/dev/null || true)"
# Drop documentation placeholders: <value>/<non-empty>/template markers are prose, not leaks.
MATCHES="$(echo "$RAW_MATCHES" | grep -vEi '<(value|non-empty|placeholder|your-|secret-here)[^>]*>|changeme|dummy|dev-only|example\.com|YOUR_' || true)"
# password_hash: violation ONLY when a hash VALUE is assigned (bcrypt $2x$... or quoted
# value). Bare identifiers, SQL DDL (`password_hash TEXT NOT NULL`), and docs prose
# are not leaks. Migrations DDL stays explicitly allowed.
PW_MATCHES="$(grep -rEn --exclude-dir=node_modules --exclude-dir=.git \
  --exclude-dir=dist --exclude-dir=DerivedData --exclude-dir=build \
  --exclude='*.env.example' --exclude='secrets-scan.sh' \
  -e "password_hash['\"]?[[:space:]]*[:=][[:space:]]*['\"]?\$2[aby]?\$" \
  -e "password_hash['\"]?[[:space:]]*[:=][[:space:]]*['\"][^'\"]{8,}" \
  . 2>/dev/null | grep -v 'Backend/migrations/' || true)"

if [[ -n "$MATCHES" ]]; then
  echo "ERROR: possible secret found in repo:"
  echo "$MATCHES"
  FAIL=1
fi
if [[ -n "$PW_MATCHES" ]]; then
  echo "ERROR: password_hash reference outside migrations DDL:"
  echo "$PW_MATCHES"
  FAIL=1
fi

echo "==> checking Backend/.env.example holds dummy-only values"
if [[ ! -f Backend/.env.example ]]; then
  echo "ERROR: Backend/.env.example missing"
  FAIL=1
else
  # Dummy markers allowed anywhere in the value: empty, dev-only-*, dummy, change*,
  # example, test, localhost, ./storage, com.lumeo.*, pure numbers (ports).
  SUSPECT=""
  while IFS='=' read -r KEY VAL || [ -n "$KEY" ]; do
    case "$KEY" in ''|\#*) continue ;; esac
    [ -z "${VAL:-}" ] && continue
    case "$VAL" in
      *dev-only*|*dummy*|*change*|*example*|*test*|*localhost*|dev-*|./storage*|com.lumeo*|[0-9]*) ;;
      *) SUSPECT="${SUSPECT}${KEY}=${VAL}
" ;;
    esac
  done < Backend/.env.example
  if [[ -n "$SUSPECT" ]]; then
    echo "WARNING: Backend/.env.example has non-dummy values (review):"
    echo "$SUSPECT"
    # Warning only — root .env.example stays the CI gate for empties.
  else
    echo "OK: Backend/.env.example is dummy-only"
  fi
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "FAIL: secrets-guard found violations" >&2
  exit 1
fi
echo "OK: no hardcoded secrets detected."
