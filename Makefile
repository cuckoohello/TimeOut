# Makefile for TimeOut macOS Application
# Official packaging solution using standard Make targets

# Configuration
APP_NAME := TimeOut
BUNDLE_ID := me.kokonur.timeout
VERSION := 1.0
BUILD_NUMBER := 1
MIN_MACOS_VERSION := 14.0

# Directories
BUILD_CONFIG := release
BUILD_DIR := $(shell swift build -c $(BUILD_CONFIG) --show-bin-path 2>/dev/null || echo ".build/$(BUILD_CONFIG)")
APP_BUNDLE := $(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources

# Resources
ICON_SOURCE := Sources/TimeOut/Resources/AppIcon.icns

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: all build package install clean help test run

# Default target
all: package

## help: Show this help message
help:
	@echo "$(BLUE)TimeOut Makefile - Available targets:$(NC)"
	@echo ""
	@echo "  $(GREEN)make build$(NC)      - Build the release binary"
	@echo "  $(GREEN)make package$(NC)    - Create .app bundle (default)"
	@echo "  $(GREEN)make install$(NC)    - Install to /Applications"
	@echo "  $(GREEN)make run$(NC)        - Build and run the app"
	@echo "  $(GREEN)make clean$(NC)      - Remove build artifacts"
	@echo "  $(GREEN)make test$(NC)       - Run tests"
	@echo "  $(GREEN)make help$(NC)       - Show this help message"
	@echo ""

## build: Compile the Swift project in release mode
build:
	@echo "$(BLUE)🛠️  Building $(APP_NAME) in release mode...$(NC)"
	@swift build -c $(BUILD_CONFIG)
	@echo "$(GREEN)✅ Build complete!$(NC)"

## package: Create the .app bundle
package: build
	@echo "$(BLUE)📦 Creating $(APP_NAME).app bundle...$(NC)"
	@$(MAKE) -s clean-bundle
	@$(MAKE) -s create-bundle-structure
	@$(MAKE) -s copy-binary
	@$(MAKE) -s create-info-plist
	@$(MAKE) -s copy-icon
	@echo "$(GREEN)🎉 Packaging complete!$(NC)"
	@echo "$(YELLOW)📍 App bundle location: $(PWD)/$(APP_BUNDLE)$(NC)"
	@echo "$(YELLOW)💡 Run 'make install' to install to /Applications$(NC)"

## install: Install the app to /Applications
install: package
	@echo "$(BLUE)📥 Installing $(APP_NAME) to /Applications...$(NC)"
	@if [ -d "/Applications/$(APP_BUNDLE)" ]; then \
		echo "$(YELLOW)⚠️  Removing existing installation...$(NC)"; \
		rm -rf "/Applications/$(APP_BUNDLE)"; \
	fi
	@cp -R "$(APP_BUNDLE)" /Applications/
	@echo "$(GREEN)✅ Installation complete!$(NC)"
	@echo "$(YELLOW)🚀 You can now launch $(APP_NAME) from /Applications$(NC)"

## run: Build and run the application
run: build
	@echo "$(BLUE)🚀 Running $(APP_NAME)...$(NC)"
	@"$(BUILD_DIR)/$(APP_NAME)"

## test: Run Swift tests
test:
	@echo "$(BLUE)🧪 Running tests...$(NC)"
	@swift test

## clean: Remove all build artifacts and app bundle
clean:
	@echo "$(BLUE)🧹 Cleaning build artifacts...$(NC)"
	@swift package clean
	@rm -rf .build
	@$(MAKE) -s clean-bundle
	@echo "$(GREEN)✅ Clean complete!$(NC)"

## Internal targets (not shown in help)

# Remove only the app bundle
clean-bundle:
	@rm -rf "$(APP_BUNDLE)"

# Create the .app bundle directory structure
create-bundle-structure:
	@echo "  📂 Creating bundle structure..."
	@mkdir -p "$(MACOS_DIR)"
	@mkdir -p "$(RESOURCES_DIR)"

# Copy the compiled binary
copy-binary:
	@echo "  📋 Copying binary..."
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(MACOS_DIR)/$(APP_NAME)"
	@chmod +x "$(MACOS_DIR)/$(APP_NAME)"

# Create Info.plist
create-info-plist:
	@echo "  📝 Creating Info.plist..."
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > "$(CONTENTS_DIR)/Info.plist"
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '<plist version="1.0">' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '<dict>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <key>CFBundleExecutable</key>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <string>$(APP_NAME)</string>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <key>CFBundleIdentifier</key>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <string>$(BUNDLE_ID)</string>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <key>CFBundleName</key>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <string>$(APP_NAME)</string>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <key>CFBundleIconFile</key>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <string>AppIcon</string>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <key>CFBundleShortVersionString</key>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <string>$(VERSION)</string>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <key>CFBundleVersion</key>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <string>$(BUILD_NUMBER)</string>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <key>LSMinimumSystemVersion</key>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <string>$(MIN_MACOS_VERSION)</string>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <key>LSUIElement</key>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <true/>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <key>NSHighResolutionCapable</key>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '    <true/>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '</dict>' >> "$(CONTENTS_DIR)/Info.plist"
	@echo '</plist>' >> "$(CONTENTS_DIR)/Info.plist"

# Copy application icon
copy-icon:
	@if [ -f "$(ICON_SOURCE)" ]; then \
		echo "  🎨 Copying AppIcon.icns..."; \
		cp "$(ICON_SOURCE)" "$(RESOURCES_DIR)/AppIcon.icns"; \
	else \
		echo "  $(YELLOW)⚠️  No icon file found$(NC)"; \
	fi
