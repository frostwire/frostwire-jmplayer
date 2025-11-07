.PHONY: help build build-windows build-macos build-linux build-openssl-windows build-openssl-native clean-build clean check-env install-deps show-config

# Color codes for help output
BLUE := \033[36m
RESET := \033[0m

# Detect OS
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    DETECTED_OS = Linux
    DETECTED_ARCH = $(shell uname -m)
endif
ifeq ($(UNAME_S),Darwin)
    DETECTED_OS = macOS
    DETECTED_ARCH = $(shell uname -m)
endif

# Normalize architecture names
ifeq ($(DETECTED_ARCH),aarch64)
    DETECTED_ARCH = arm64
endif
ifeq ($(DETECTED_ARCH),x86_64)
    DETECTED_ARCH = x86_64
endif

default: help

# ============================================================================
# HELP
# ============================================================================

help tasks:  ## Display this help message
	@echo "$(BLUE)FrostWire FWPlayer Build System$(RESET)"
	@echo ""
	@echo "$(BLUE)Detected Environment:$(RESET) $(DETECTED_OS) ($(DETECTED_ARCH))"
	@echo ""
	@echo "$(BLUE)Available Commands:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  $(BLUE)%-25s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)Quick Start:$(RESET)"
	@echo "  make build              # Build for current platform"
	@echo "  make build-openssl-native # Build OpenSSL for current platform"
	@echo "  make clean              # Clean all build artifacts"
	@echo ""

# ============================================================================
# CONFIGURATION & CHECKS
# ============================================================================

check-env:  ## Check if OPENSSL_ROOT is set
	@if [ -z "$(OPENSSL_ROOT)" ]; then \
		echo "$(BLUE)Error:$(RESET) OPENSSL_ROOT not set"; \
		echo "Please set: export OPENSSL_ROOT=\$${HOME}/src/openssl"; \
		exit 1; \
	else \
		echo "$(BLUE)✓$(RESET) OPENSSL_ROOT=$(OPENSSL_ROOT)"; \
	fi

show-config:  ## Show build configuration
	@echo "$(BLUE)Build Configuration:$(RESET)"
	@echo "  Operating System:  $(DETECTED_OS)"
	@echo "  Architecture:       $(DETECTED_ARCH)"
	@echo "  OPENSSL_ROOT:       $(OPENSSL_ROOT)"
	@echo "  MPlayer Status:     $(if $(shell [ -d mplayer-trunk ] && echo yes),$(BLUE)✓$(RESET) Present,$(BLUE)✗$(RESET) Not cloned)"
	@echo "  FFmpeg Status:      $(if $(shell [ -d mplayer-trunk/ffmpeg ] && echo yes),$(BLUE)✓$(RESET) Present,$(BLUE)✗$(RESET) Not cloned)"

# ============================================================================
# OPENSSL BUILDS
# ============================================================================

build-openssl-native:  ## Build OpenSSL for current platform (native)
	@echo "$(BLUE)Building OpenSSL for $(DETECTED_OS) ($(DETECTED_ARCH))...$(RESET)"
	@./build-openssl.sh

build-openssl-windows:  ## Build OpenSSL for Windows x86_64 (from Linux only)
ifeq ($(DETECTED_OS),Linux)
	@echo "$(BLUE)Building OpenSSL for Windows x86_64...$(RESET)"
	@BUILD_FOR_WINDOWS=1 ./build-openssl.sh
else
	@echo "$(BLUE)Error:$(RESET) Windows cross-compilation only supported from Linux"
	@exit 1
endif

# ============================================================================
# PLAYER BUILDS
# ============================================================================

build: check-env  ## Build fwplayer for current platform (native)
ifeq ($(DETECTED_OS),Linux)
	@echo "$(BLUE)Building fwplayer_linux.$(DETECTED_ARCH)...$(RESET)"
	@./build_linux.sh
else ifeq ($(DETECTED_OS),macOS)
	@echo "$(BLUE)Building fwplayer_osx.$(DETECTED_ARCH)...$(RESET)"
	@./build_macos.sh
else
	@echo "$(BLUE)Error:$(RESET) Unsupported platform: $(DETECTED_OS)"
	@exit 1
endif

build-windows: check-env  ## Build fwplayer.exe for Windows (cross-compile from Linux only)
ifeq ($(DETECTED_OS),Linux)
	@echo "$(BLUE)Building fwplayer.exe for Windows x86_64...$(RESET)"
	@./build_windows.sh
else
	@echo "$(BLUE)Error:$(RESET) Windows builds only supported from Linux"
	@exit 1
endif

build-macos: check-env  ## Build fwplayer_osx for macOS (x86_64 or arm64)
ifeq ($(DETECTED_OS),macOS)
	@echo "$(BLUE)Building fwplayer_osx.$(DETECTED_ARCH)...$(RESET)"
	@./build_macos.sh
else
	@echo "$(BLUE)Error:$(RESET) macOS builds only supported on macOS"
	@exit 1
endif

build-linux: check-env  ## Build fwplayer_linux for Linux (x86_64 or arm64)
ifeq ($(DETECTED_OS),Linux)
	@echo "$(BLUE)Building fwplayer_linux.$(DETECTED_ARCH)...$(RESET)"
	@./build_linux.sh
else
	@echo "$(BLUE)Error:$(RESET) Linux builds only supported on Linux"
	@exit 1
endif

# ============================================================================
# SETUP & INITIALIZATION
# ============================================================================

install-deps:  ## Install system dependencies for building
ifeq ($(DETECTED_OS),Linux)
	@echo "$(BLUE)Installing Linux build dependencies...$(RESET)"
	@if [ -f ./prepare-ubuntu-environment.sh ]; then ./prepare-ubuntu-environment.sh; fi
else ifeq ($(DETECTED_OS),macOS)
	@echo "$(BLUE)Installing macOS build dependencies...$(RESET)"
	@if [ -f ./prepare-macos-environment.sh ]; then ./prepare-macos-environment.sh; fi
else
	@echo "$(BLUE)Error:$(RESET) Unsupported platform: $(DETECTED_OS)"
	@exit 1
endif

setup: install-deps build-openssl-native  ## Complete setup: install dependencies and build OpenSSL
	@echo "$(BLUE)✓$(RESET) Setup complete! Run 'make build' to build the player"

# ============================================================================
# CLEANING
# ============================================================================

clean-build:  ## Clean MPlayer and FFmpeg build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(RESET)"
	@bash -c 'source build-functions.sh && clean_build_artifacts'
	@echo "$(BLUE)✓$(RESET) Build artifacts cleaned"

clean: clean-build  ## Clean all build artifacts (alias for clean-build)
	@echo "$(BLUE)✓$(RESET) Clean complete"

# ============================================================================
# INFORMATION & TROUBLESHOOTING
# ============================================================================

info:  ## Show build information and status
	@echo "$(BLUE)FrostWire JMPlayer Build Information$(RESET)"
	@echo ""
	@make show-config
	@echo ""
	@echo "$(BLUE)Quick Commands:$(RESET)"
	@echo "  Setup:   make setup              # First time setup"
	@echo "  Build:   make build              # Build for current platform"
	@echo "  Clean:   make clean              # Clean build artifacts"
	@echo ""

version:  ## Show script versions
	@echo "$(BLUE)Component Versions:$(RESET)"
	@if [ -f build-openssl.sh ]; then grep "OPENSSL_VERSION" build-openssl.sh | head -1; fi
	@echo "  MPlayer: SVN trunk"
	@echo "  FFmpeg:  Git latest"
