#!/usr/bin/env bash
#
# mayhem/build.sh — build nxdk's fuzz target + the functional-test oracle, ON TOP of the org
# C/C++ base image (ghcr.io/mayhemheroes/base). The base exports the build contract:
#   CC, CXX, LIB_FUZZING_ENGINE, STANDALONE_FUZZ_MAIN, SANITIZER_FLAGS (ASan+UBSan, both halting),
#   SRC (/mayhem). We default them so the script also runs outside the image.
#
# The fuzz surface is the vp20compiler tool (tools/vp20compiler) — a standalone CLI that parses an
# NV vertex-program text file (argv[1]) and emits Xbox NV2A vertex-shader hardware tokens. It IS a
# file-input program (reads argv[1] itself), so no separate libFuzzer harness / standalone driver
# is needed — Mayhem mutates the input file directly.
#
#   /mayhem/tools/vp20compiler/vp20compiler  — the upstream CLI, instrumented (ASan+UBSan). The
#                                              fuzz target. Drives parse_nv_vertex_program() +
#                                              translate() (token packing, asserts, the line scan).
#   /mayhem/vp20compiler-oracle              — a clean (no-sanitizer, normal flags) build of the
#                                              same tool, used by test.sh for the golden KAT.
set -euo pipefail

: "${SRC:=/mayhem}"
: "${CC:=clang}"
: "${SANITIZER_FLAGS:=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -g}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
export DEBUG_FLAGS

VPDIR="$SRC/tools/vp20compiler"
SRCS=("$VPDIR/nvvertparse.c" "$VPDIR/prog_instruction.c" "$VPDIR/main.c")
CFLAGS="-std=gnu99"

echo "== [1/2] fuzz target: vp20compiler (instrumented ASan+UBSan) =="
# shellcheck disable=SC2086
"$CC" $CFLAGS $SANITIZER_FLAGS $DEBUG_FLAGS -I"$VPDIR" "${SRCS[@]}" -o "$VPDIR/vp20compiler"

echo "== [2/2] test oracle: vp20compiler-oracle (normal flags, no sanitizers) =="
# shellcheck disable=SC2086
"$CC" $CFLAGS -O2 $DEBUG_FLAGS -I"$VPDIR" "${SRCS[@]}" -o "$SRC/vp20compiler-oracle"

echo "== build.sh done =="
ls -la "$VPDIR/vp20compiler" "$SRC/vp20compiler-oracle"
