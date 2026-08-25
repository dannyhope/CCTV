APP_NAME = CCTV
BUILD_DIR = .build/release
# Bundle path is CCTV-<build>.app — set after bump-build via Info.plist.
INFO_PLIST = SupportFiles/Info.plist
BUNDLE_ID_BASE = co.uk.dannyhope.cctv

SHELL = /bin/bash

.PHONY: build bump-build bundle codesign run watch install clean

# Read the current build number from Info.plist (after bump-build).
build_number = $$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$(INFO_PLIST)")
app_bundle = $(BUILD_DIR)/$(APP_NAME)-$(build_number).app
install_app = /Applications/$(APP_NAME)-$(build_number).app

build:
	swift build -c release

# Increment CFBundleVersion and stamp the build number into the display name,
# bundle name, and identifier so System Settings / Finder never mix this
# binary up with an older CCTV.
bump-build:
	@current=$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$(INFO_PLIST)"); \
	if [[ "$$current" =~ ^[0-9]+$$ ]]; then \
		next=$$((current + 1)); \
	elif [[ "$$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$$ ]]; then \
		next=1; \
	else \
		next=1; \
	fi; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$next" "$(INFO_PLIST)"; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName CCTV $$next" "$(INFO_PLIST)"; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleName CCTV $$next" "$(INFO_PLIST)"; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(BUNDLE_ID_BASE).$$next" "$(INFO_PLIST)"; \
	echo "Build number → $$next (CCTV $$next / $(BUNDLE_ID_BASE).$$next)"

bundle: bump-build build
	@bn=$(build_number); \
	bundle="$(BUILD_DIR)/$(APP_NAME)-$$bn.app"; \
	rm -rf "$(BUILD_DIR)/$(APP_NAME).app" "$(BUILD_DIR)/$(APP_NAME)-"*.app; \
	mkdir -p "$$bundle/Contents/MacOS"; \
	mkdir -p "$$bundle/Contents/Resources"; \
	cp "$(BUILD_DIR)/$(APP_NAME)" "$$bundle/Contents/MacOS/$(APP_NAME)"; \
	cp "$(INFO_PLIST)" "$$bundle/Contents/"; \
	echo "Bundled $$bundle"

codesign: bundle
	@bn=$(build_number); \
	bundle="$(BUILD_DIR)/$(APP_NAME)-$$bn.app"; \
	codesign --force --sign - "$$bundle"; \
	echo "Signed $$bundle"

# Quit any running CCTV (including a stale /Applications copy), then launch this build.
run: codesign
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.25
	@bn=$(build_number); \
	bundle="$(BUILD_DIR)/$(APP_NAME)-$$bn.app"; \
	open "$$bundle"; \
	echo "Running $$bundle"

# Rebuild + relaunch whenever Swift or Info.plist changes. Needs fswatch (brew install fswatch).
watch:
	@command -v fswatch >/dev/null || { echo "fswatch not found — brew install fswatch"; exit 1; }
	@echo "Watching Sources/CCTV and SupportFiles — save a file to rebuild & relaunch."
	@echo "Dev builds land at $(BUILD_DIR)/$(APP_NAME)-<n>.app"
	@echo "Ctrl+C to stop."
	@fswatch -o -l 0.4 Sources/CCTV SupportFiles | while read -r _; do \
		echo ""; \
		echo "⟶ change detected — rebuilding…"; \
		$(MAKE) run && echo "✓ relaunched" || echo "✗ build failed — still watching"; \
	done

# Optional: copy the current build into /Applications for daily use / Login Items.
install: codesign
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.25
	@bn=$(build_number); \
	bundle="$(BUILD_DIR)/$(APP_NAME)-$$bn.app"; \
	dest="/Applications/$(APP_NAME)-$$bn.app"; \
	rm -rf /Applications/$(APP_NAME).app /Applications/$(APP_NAME)-*.app; \
	cp -R "$$bundle" "$$dest"; \
	open "$$dest"; \
	echo "Installed and opened $$dest"

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)/$(APP_NAME).app" "$(BUILD_DIR)/$(APP_NAME)-"*.app
