APP_NAME    = WhisperDictation
BUILD_DIR   = .build/release
BUNDLE      = $(APP_NAME).app

.PHONY: build bundle install run clean

# Compile the Swift package in release mode
build:
	swift build -c release

# Build and package into a macOS .app bundle
bundle: build
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	@cp Resources/Info.plist $(BUNDLE)/Contents/
	@codesign --force --sign - $(BUNDLE)
	@echo "Built $(BUNDLE)"

# Install the .app bundle to /Applications
install: bundle
	@cp -r $(BUNDLE) /Applications/
	@echo "Installed to /Applications/$(BUNDLE)"

# Build and launch the app
run: bundle
	@open $(BUNDLE)

# Remove build artifacts
clean:
	swift package clean
	rm -rf $(BUNDLE)
