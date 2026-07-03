#!/usr/bin/env bash
#
# mayhem/test.sh — RUN the known-answer oracle for vp20compiler that mayhem/build.sh produced.
# vp20compiler is deterministic: a fixed NV vertex-program (mayhem/kat/input.vp) compiles to a
# fixed stream of NV2A hardware tokens (mayhem/kat/golden.txt). We diff the tool's stdout against
# that golden. This asserts the real translate()/parse_nv_vertex_program() behaviour the fuzz
# target drives, so a no-op / exit(0) PATCH (empty output) FAILS the diff (anti-reward-hacking).
# Emits a CTRF (https://ctrf.io) summary and exits non-zero iff a test failed.
#
# NB: no `set -e` — diff returns non-zero on mismatch and we want to record it, not abort early.
set -uo pipefail
: "${SRC:=/mayhem}"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

ORACLE="$SRC/vp20compiler-oracle"
INPUT="$SRC/mayhem/kat/input.vp"
GOLDEN="$SRC/mayhem/kat/golden.txt"

[ -x "$ORACLE" ] || { echo "FATAL: $ORACLE missing — mayhem/build.sh did not build the oracle" >&2; emit_ctrf "nxdk-vp20compiler-kat" 0 1 0; exit 1; }
[ -f "$GOLDEN" ] || { echo "FATAL: $GOLDEN missing" >&2; emit_ctrf "nxdk-vp20compiler-kat" 0 1 0; exit 1; }

GOT=/tmp/vp20compiler.out
"$ORACLE" "$INPUT" > "$GOT" 2>/dev/null

if diff -u "$GOLDEN" "$GOT"; then
  echo "PASS: vp20compiler output matches golden ($(wc -l < "$GOLDEN") lines)"
  emit_ctrf "nxdk-vp20compiler-kat" 1 0
else
  echo "FAIL: vp20compiler output diverged from golden" >&2
  emit_ctrf "nxdk-vp20compiler-kat" 0 1
  exit 1
fi
