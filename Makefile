SHELL := /bin/bash

PLATFORM ?= macos
BUILDKIT := plugins/setup/buildkit/run_build_tool.sh
ARCH_ARG := $(if $(ARCH),--arch $(ARCH),)
TARGET_PLATFORM_ARG := $(if $(TARGET_PLATFORM),--target-platform $(TARGET_PLATFORM),)

.PHONY: help submodules core core-macos core-linux core-windows core-android macos-arm64 macos-release-arm64

help:
	@echo 'make core                         # build macOS core by default'
	@echo 'make core PLATFORM=linux ARCH=amd64'
	@echo 'make core-macos ARCH=arm64'
	@echo 'make core-android ARCH=arm64'
	@echo 'make core-android TARGET_PLATFORM=android-arm64'
	@echo 'make macos-arm64                 # build and ad-hoc sign an arm64-only macOS app'
	@echo 'make macos-release-arm64         # same as macos-arm64; use SIGNING_IDENTITY for Developer ID'

submodules:
	git submodule update --init --recursive

core:
	bash $(BUILDKIT) $(PLATFORM) $(ARCH_ARG) $(TARGET_PLATFORM_ARG)

core-macos:
	$(MAKE) core PLATFORM=macos

core-linux:
	$(MAKE) core PLATFORM=linux

core-windows:
	$(MAKE) core PLATFORM=windows

core-android:
	$(MAKE) core PLATFORM=android

macos-arm64:
	bash macos/packaging/release_arm64.sh

macos-release-arm64:
	@test -n "$(SIGNING_IDENTITY)" || (echo 'Set SIGNING_IDENTITY to a Developer ID Application certificate.' >&2; exit 2)
	bash macos/packaging/release_arm64.sh --identity "$(SIGNING_IDENTITY)"
