#!/bin/bash
set -e

export HEADAS=/opt/heasoft
. "$HEADAS/headas-init.sh"

# Use a local CALDB file tree (some tools misbehave with a remote URL)
export CALDB=/opt/heasoft/caldb
export CALDBCONFIG=/opt/heasoft/caldb/caldb.config
export CALDBALIAS=/opt/heasoft/caldb/alias_config.fits
export PFILES="/home/heasoft/pfiles;$HEADAS/syspfiles"
mkdir -p /home/heasoft/pfiles

# Enable core dumps (depends on the host's /proc/sys/kernel/core_pattern and on
# the hard limit set via `docker run --ulimit core=-1`).
# Without a raised hard limit this fails, but it is not fatal, so ignore it.
ulimit -c unlimited 2>/dev/null || echo "warning: could not raise core file size limit (continuing without core dumps)"

cd /work

# Virtual framebuffer so XSPEC/PGPLOT doesn't fail on missing display
if [ -z "${DISPLAY:-}" ]; then
    Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
    XVFB_PID=$!
    export DISPLAY=:99
    sleep 2
fi

echo "============================================================"
echo "Step 1: Creating dummy response files (RMF + ARF)"
echo "============================================================"
python3 /scripts/make_responses.py

echo ""
echo "============================================================"
echo "Step 2: Generating fake spectra with XSPEC fakeit"
echo "============================================================"
xspec < /scripts/generate_spectra.xcm

echo ""
echo "Files in /work after fakeit:"
ls -lh /work/ 2>/dev/null || true

echo ""
echo "============================================================"
echo "Step 3: Reproducing bug under GDB"
echo "  (_GLIBCXX_ASSERTIONS fires abort() -> SIGABRT on OOB access)"
echo "============================================================"

gdb -batch \
    -ex "set pagination off" \
    -ex "set print pretty on" \
    -ex "handle SIGABRT stop print nopass" \
    -ex "handle SIGSEGV stop print nopass" \
    -ex "run < /scripts/reproduce_bug.xcm" \
    -ex "thread apply all backtrace" \
    --args xspec 2>&1 | tee /work/bt_clean.txt || true

echo ""
echo "--- key frames ---"
grep -E "^(#[0-9]|Thread |.*received signal)" /work/bt_clean.txt || true

echo ""
echo "Full backtrace: /work/bt_clean.txt"

[ -n "${XVFB_PID:-}" ] && kill "${XVFB_PID}" 2>/dev/null || true
