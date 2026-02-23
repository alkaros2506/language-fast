APP_NAME    = WhisperDictation
BUILD_DIR   = .build/release
BUNDLE      = $(APP_NAME).app
BUNDLE_ID   = com.local.WhisperDictation
CODESIGN_IDENTITY ?= 521B074D079694A2FDAA84E71B488A85247B0E2E
CODESIGN_CERT_CN  ?= WhisperDictation Dev

.PHONY: build bundle install run clean permissions

# Compile the Swift package in release mode
build:
	swift build -c release

# Build and package into a macOS .app bundle
# Uses a stable designated requirement so TCC permissions survive rebuilds.
bundle: build
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	@cp Resources/Info.plist $(BUNDLE)/Contents/
	@codesign --force --sign "$(CODESIGN_IDENTITY)" \
		-r='designated => identifier "$(BUNDLE_ID)" and certificate leaf[subject.CN] = "$(CODESIGN_CERT_CN)"' \
		$(BUNDLE)
	@echo "Built $(BUNDLE)"

# Install the .app bundle to /Applications (update in place)
install: bundle
	@mkdir -p /Applications/$(BUNDLE)/Contents/MacOS
	@mkdir -p /Applications/$(BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) /Applications/$(BUNDLE)/Contents/MacOS/
	@cp Resources/Info.plist /Applications/$(BUNDLE)/Contents/
	@codesign --force --sign "$(CODESIGN_IDENTITY)" \
		-r='designated => identifier "$(BUNDLE_ID)" and certificate leaf[subject.CN] = "$(CODESIGN_CERT_CN)"' \
		/Applications/$(BUNDLE)
	@echo "Installed to /Applications/$(BUNDLE)"

# Build and launch the app
run: bundle
	@open $(BUNDLE)

# Reset TCC permissions (run once after first install, then grant in System Settings)
permissions:
	tccutil reset Accessibility $(BUNDLE_ID)
	tccutil reset ListenEvent $(BUNDLE_ID)
	@echo "TCC reset. Restart the app and grant Accessibility + Input Monitoring."

# Remove build artifacts
clean:
	swift package clean
	rm -rf $(BUNDLE)
