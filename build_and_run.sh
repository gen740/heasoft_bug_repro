#!/bin/bash
# Helper script to build and run the HEASoft bug reproduction container.
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
#   nix shell nixpkgs#docker -c bash build_and_run.sh build
#   nix shell nixpkgs#docker -c bash build_and_run.sh run

set -e

DOCKER="docker -H unix:///tmp/docker.sock"
# Lifting the core file size hard limit lets `ulimit -c unlimited` succeed
# inside the container so core dumps can be captured.
RUN_OPTS="--ulimit core=-1"
IMAGE="heasoft-debug:6.36"
CONTAINER="heasoft-bug"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
    $DOCKER rm -f "${CONTAINER}" 2>/dev/null || true
}

case "${1:-}" in
  build)
    echo "=== Building ${IMAGE} (this will take a very long time) ==="
    $DOCKER build -t "${IMAGE}" "${SCRIPT_DIR}"
    ;;
  run)
    cleanup
    echo "=== Reproducing XSPEC bug (generate spectra + GDB backtrace) ==="
    $DOCKER run --rm $RUN_OPTS --name "${CONTAINER}" "${IMAGE}"
    ;;
  shell)
    cleanup
    echo "=== Interactive bash shell inside ${IMAGE} ==="
    $DOCKER run --rm -it $RUN_OPTS --name "${CONTAINER}" "${IMAGE}" /bin/bash
    ;;
  build-run)
    $DOCKER build -t "${IMAGE}" "${SCRIPT_DIR}"
    cleanup
    $DOCKER run --rm $RUN_OPTS --name "${CONTAINER}" "${IMAGE}"
    ;;
  *)
    echo "Usage: nix shell nixpkgs#docker -c bash $0 {build|run|shell|build-run}"
    echo ""
    echo "  build      — build the Docker image"
    echo "  run        — run bug reproduction (generate spectra then GDB backtrace)"
    echo "  shell      — interactive bash shell inside the image"
    echo "  build-run  — build then immediately run"
    exit 1
    ;;
esac
