#!/usr/bin/env bash
# check-no-secrets.sh -- fail if the repo contains anything that looks personal:
# real names, usernames in paths, private hostnames, LAN/VPN addresses, MAC
# addresses, emails, tokens, keys, wallet addresses, Wi-Fi names, work references.
# Run it before every commit/push:  scripts/check-no-secrets.sh
set -uo pipefail
cd "$(dirname "$0")/.."

# Case-insensitive patterns.
# Names/hostnames you want kept out of the repo are NOT listed here (this file is public).
# Put them, one extended regex per line, in a private file and point CHECK_DENYLIST at it:
#   CHECK_DENYLIST=~/private-denylist.txt scripts/check-no-secrets.sh
CI='a^'   # matches nothing; the rules below are appended
CI+='|(^|[^a-z0-9])/(home|users)/[a-z]'
CI+='|192\.168\.|(^|[^0-9.])100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]+\.[0-9]+'
CI+='|([0-9a-f]{2}:){5}[0-9a-f]{2}'
CI+='|[a-z0-9._+-]+@[a-z0-9-]+\.(com|net|org|io|dev|me|gg|co|xyz|app|us|uk|de|ai|sh|tv|info|email|mail)([^a-z]|$)'
CI+='|(ssid|psk|passphrase)[[:space:]]*=[[:space:]]*[^[:space:]$"<]'
CI+='|BEGIN [A-Z ]*PRIVATE KEY'
CI+='|(api[_-]?key|secret|token|passw(or)?d)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9+_][A-Za-z0-9/+_-]{15,}'
if [ -n "${CHECK_DENYLIST:-}" ] && [ -f "$CHECK_DENYLIST" ]; then
  while IFS= read -r w; do [ -n "$w" ] && [ "${w#\#}" = "$w" ] && CI+="|$w"; done < "$CHECK_DENYLIST"
fi
# Case-sensitive patterns: token and wallet shapes.
CS='[0-9]{8,10}:[A-Za-z0-9_-]{30,}|sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|xox[bap]-[A-Za-z0-9-]{10,}|0x[0-9a-fA-F]{40}'

# Files/dirs never scanned: this script, git internals, and an optional allow-list.
EXCLUDES=(--exclude-dir=.git --exclude=check-no-secrets.sh --exclude=.gitignore)
[ -f scripts/check-no-secrets.allow ] && EXCLUDES+=(--exclude-from=scripts/check-no-secrets.allow)

# Optional allow-list of LINE patterns (extended regex, one per line) for vetted false positives,
# e.g. third-party copyright lines or documentation placeholders. Keep it short and specific.
filter() { if [ -f scripts/check-no-secrets.allow-lines ]; then grep -vEf scripts/check-no-secrets.allow-lines; else cat; fi; }

fail=0
if hits=$(grep -rInEi "${EXCLUDES[@]}" -e "$CI" . | filter); [ -n "$hits" ]; then
  echo "== suspicious (case-insensitive) =="; echo "$hits" | cut -c1-200; fail=1
fi
if hits=$(grep -rInE "${EXCLUDES[@]}" -e "$CS" . | filter); [ -n "$hits" ]; then
  echo "== suspicious (token/wallet shapes) =="; echo "$hits" | cut -c1-200; fail=1
fi
# Forbidden files.
bad=$(find . -path ./.git -prune -o \( -name '*.pem' -o -name '*.key' -o -name '.env' -o -name '*.env' -o -name 'id_*' -o -name '*.bak*' \) -print)
if [ -n "$bad" ]; then echo "== forbidden files =="; echo "$bad"; fail=1; fi
[ "$fail" = 0 ] && echo "check-no-secrets: clean" || { echo "check-no-secrets: FAILED"; exit 1; }
