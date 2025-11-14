#!/bin/bash
################################################################################
# Build FWPlayer Windows executable either natively or via Docker
#
# This script can:
# 1. Build and run inside Docker (recommended)
# 2. Run build_windows.sh directly on host (requires Ubuntu x86_64)
# 3. Only build Docker image for later use
#
# Usage:
#   ./docker_build_windows.sh              # Build in Docker (default, recommended)
#   ./docker_build_windows.sh --native     # Build directly on host (Ubuntu x86_64 only)
#   ./docker_build_windows.sh --image-only # Only build Docker image, don't run build
#
################################################################################

set -e

IMAGE_NAME="fwplayer-builder:windows"
DOCKERFILE="Dockerfile.windows"
BUILD_MODE="docker"  # Default: docker

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

print_info() {
    echo -e "${YELLOW}Info:${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================================================${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --native)
            BUILD_MODE="native"
            shift
            ;;
        --image-only)
            BUILD_MODE="image-only"
            shift
            ;;
        --docker)
            BUILD_MODE="docker"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (default)      Build in Docker (recommended)"
            echo "  --docker       Build in Docker"
            echo "  --native       Build directly on host (Ubuntu x86_64 only)"
            echo "  --image-only   Build Docker image without running the build"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "FrostWire FWPlayer Windows Build"

# Check prerequisites for host
check_host_prerequisites() {
    if [ "$(uname -m)" != "x86_64" ]; then
        print_error "Build requires x86_64 architecture (detected: $(uname -m))"
        exit 1
    fi
}

# Native build on Ubuntu host
build_native() {
    print_header "Building natively on Ubuntu x86_64 host"

    # Check host OS
    check_host_prerequisites

    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        print_error "Native builds require Ubuntu Linux"
        echo "Use --docker flag to build in Docker container, or:"
        echo "  ./prepare-ubuntu-environment.sh"
        exit 1
    fi

    print_status "Ubuntu x86_64 environment verified"
    echo ""

    # Run the build script
    print_status "Running build_windows.sh..."
    ./build_windows.sh
}

# Docker build
build_docker() {
    print_header "Building in Docker container"

    check_host_prerequisites

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        echo ""
        print_info "Install Docker from: https://docs.docker.com/install/"
        exit 1
    fi

    # Build Docker image
    print_status "Building Docker image: $IMAGE_NAME"
    echo ""

    if [ ! -f "$DOCKERFILE" ]; then
        print_error "Dockerfile not found: $DOCKERFILE"
        exit 1
    fi

    if [ ! -d "MPlayer-1.5" ]; then
        print_error "MPlayer-1.5 directory not found"
        exit 1
    fi

    docker build \
        -f "$DOCKERFILE" \
        -t "$IMAGE_NAME" \
        .

    print_status "Docker image built successfully"
    echo ""

    # Run build in container with volume mounts
    print_status "Running Windows build in Docker container..."
    echo ""

    docker run \
        --rm \
        -it \
        -v "$(pwd)":/workspace \
        "$IMAGE_NAME" \
        ./build_windows.sh

    print_status "Docker build completed!"
}

# Build image only
build_image_only() {
    print_header "Building Docker image only"

    check_host_prerequisites

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    print_status "Building Docker image: $IMAGE_NAME"
    echo ""

    if [ ! -f "$DOCKERFILE" ]; then
        print_error "Dockerfile not found: $DOCKERFILE"
        exit 1
    fi

    if [ ! -d "MPlayer-1.5" ]; then
        print_error "MPlayer-1.5 directory not found"
        exit 1
    fi

    docker build \
        -f "$DOCKERFILE" \
        -t "$IMAGE_NAME" \
        .

    print_status "Docker image built successfully: $IMAGE_NAME"
    echo ""
    print_info "To run the build, execute:"
    echo "  docker run --rm -it -v \$(pwd):/workspace -w /workspace $IMAGE_NAME ./build_windows.sh"
}

# Main execution
case "$BUILD_MODE" in
    native)
        build_native
        ;;
    docker)
        build_docker
        ;;
    image-only)
        build_image_only
        ;;
    *)
        print_error "Unknown build mode: $BUILD_MODE"
        exit 1
        ;;
esac

echo ""
print_status "All done!"

if [ -f "fwplayer_windows.exe" ]; then
    print_status "Build output: fwplayer_windows.exe"
    ls -lh fwplayer_windows.exe
fi
