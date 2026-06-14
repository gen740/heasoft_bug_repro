#!/bin/bash
# Helper script to build and run the HEASoft bug reproduction container.
#
# Two image variants can be built from the same Dockerfile:
#   * buggy   (default)         - unpatched source, reproduces the bug
#   * patched (APPLY_PATCH=1)   - patches/ applied, the bug is fixed
#
# Prerequisites:
#   Start dockerd in a separate terminal first:
#     nix shell nixpkgs#docker -c sudo dockerd \
#       --data-root /tmp/docker-data \
#       --exec-root /tmp/docker-exec \
#       --pidfile /tmp/docker.pid \
#       --host unix:///tmp/docker.sock
#
# Then run this script:
#   nix shell nixpkgs#docker -c bash build_and_run.sh run
#   nix shell nixpkgs#docker -c bash build_and_run.sh run-patched

set -e

DOCKER="docker -H unix:///tmp/docker.sock"
# Lifting the core file size hard limit lets `ulimit -c unlimited` succeed
# inside the container so core dumps can be captured.
RUN_OPTS="--ulimit core=-1"

IMAGE="heasoft-debug:6.36"
IMAGE_PATCHED="heasoft-debug:6.36-patched"
CONTAINER="heasoft-bug"
CONTAINER_PATCHED="heasoft-fixed"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
    $DOCKER rm -f "${1}" 2>/dev/null || true
}

build_image() {
    # $1 = image tag, $2 = APPLY_PATCH value
    echo "=== Building ${1} (APPLY_PATCH=${2}; first build takes a very long time) ==="
    $DOCKER build --build-arg "APPLY_PATCH=${2}" -t "${1}" "${SCRIPT_DIR}"
}

run_image() {
    # $1 = image tag, $2 = container name, $3 = APPLY_PATCH value
    # Always (re)build first; Docker layer caching makes this a no-op when nothing changed.
    build_image "${1}" "${3}"
    cleanup "${2}"
    echo "=== Reproducing XSPEC bug (generate spectra + GDB backtrace) using ${1} ==="
    $DOCKER run --rm $RUN_OPTS --name "${2}" "${1}"
}

case "${1:-}" in
  build)          build_image "${IMAGE}" 0 ;;
  build-patched)  build_image "${IMAGE_PATCHED}" 1 ;;
  run)            run_image "${IMAGE}" "${CONTAINER}" 0 ;;
  run-patched)    run_image "${IMAGE_PATCHED}" "${CONTAINER_PATCHED}" 1 ;;
  *)
    echo "Usage: nix shell nixpkgs#docker -c bash $0 <command>"
    echo ""
    echo "  build          - build the buggy (unpatched) image"
    echo "  build-patched  - build the patched (fixed) image (patches/ applied)"
    echo "  run            - build then reproduce the bug (emit GDB backtrace)"
    echo "  run-patched    - build then run the same scenario against the patched build"
    exit 1
    ;;
esac
