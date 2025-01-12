# Makefile for building Dart project and VSCode plugin

# Variables
DART_PROJECT_DIR := .
VS_CODE_PLUGIN_DIR := ./easy-localization-lsp-vscode
BUILD_DIR := ./build

# Targets
.PHONY: all clean build_dart build_vscode

all: clean build_dart build_vscode

clean:
	@echo "Cleaning build directory..."
	@rm -rf $(BUILD_DIR)

build_dart:
	@echo "Building Dart project..."
	@dart compile kernel $(DART_PROJECT_DIR)/bin/easy_localization_lsp.dart -o $(VS_CODE_PLUGIN_DIR)/easy_localization_lsp.dill

build_vscode:
	@echo "Building VSCode plugin..."
	@cd $(VS_CODE_PLUGIN_DIR) && vsce package -o $(BUILD_DIR)/vscode_plugin.vsix
