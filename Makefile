SHELL := /bin/bash

.PHONY: help submodules macos-arm64 macos-release-arm64

help:
	@echo 'make submodules  # update git submodules (Clash.Meta core sources)'
	@echo 'make macos-arm64  # build and sign an arm64-only macOS app'
	@echo 'make macos-release-arm64  # sign with SIGNING_IDENTITY'
	@echo ''
	@echo 'The Go core and Rust helper build automatically through the setup build'
	@echo 'hook during flutter build; see .agents/commands.md.'

submodules:
	git submodule update --init --recursive

macos-arm64:
	bash macos/packaging/release_arm64.sh

macos-release-arm64:
	@test -n "$(SIGNING_IDENTITY)" || (echo 'Set SIGNING_IDENTITY to a Developer ID Application certificate.' >&2; exit 2)
	bash macos/packaging/release_arm64.sh --identity "$(SIGNING_IDENTITY)"
