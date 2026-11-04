#!/usr/bin/env bash
# Dry-run test: fake /proc/meminfo showing memory pressure and a fake "chromium" process; oom-trim must
# pick it as the priority target, and must NOT act when memory is fine. Kills only the process it started.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); trap 'kill $pid 2>/dev/null; rm -rf "$T"' EXIT
cp "$(command -v sleep)" "$T/chromium"; "$T/chromium" 300 & pid=$!
sleep 0.5
run() { OOMTRIM_MEMINFO="$T/meminfo" OOMTRIM_DRY_RUN=1 OOMTRIM_ONESHOT=1 OOMTRIM_MIN_RSS_MB=0 XDG_STATE_HOME="$T/state" "$here/bin/oom-trim"; }
fail=0
printf 'MemTotal: 16000000 kB\nMemAvailable: 500000 kB\n' > "$T/meminfo"; rm -rf "$T/state"; run
grep -q "DRY-RUN would TERM pid=$pid (priority:chromium" "$T/state/oom-trim.log" && echo "ok   - targets the priority hog under pressure" || { echo "FAIL - no target"; fail=1; }
printf 'MemTotal: 16000000 kB\nMemAvailable: 9000000 kB\n' > "$T/meminfo"; rm -rf "$T/state"; run
grep -q "would TERM" "$T/state/oom-trim.log" && { echo "FAIL - acted with plenty of memory"; fail=1; } || echo "ok   - leaves everything alone when memory is fine"
[ "$fail" = 0 ] && echo "oom-trim-test: all passed" || exit 1
