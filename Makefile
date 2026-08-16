APP_NAME = CCTV
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
BUNDLE_ID = co.uk.dannyhope.cctv
INFO_PLIST = SupportFiles/Info.plist
INSTALL_APP = /Applications/$(APP_NAME).app

SHELL = /bin/bash

.PHONY: build bump-build bundle codesign run watch install clean

build:
	swift build -c release

# Increment CFBundleVersion (build number) for each rebuild. Marketing version stays put.
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
	echo "Build number → $$next"

bundle: bump-build build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp "$(INFO_PLIST)" "$(APP_BUNDLE)/Contents/"

codesign: bundle
	codesign --force --sign - "$(APP_BUNDLE)"

# Quit any running CCTV (including a stale /Applications copy), then launch this build.
run: codesign
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.25
	open "$(APP_BUNDLE)"
	@echo "Running $(APP_BUNDLE)"

# Rebuild + relaunch whenever Swift or Info.plist changes. Needs fswatch (brew install fswatch).
watch:
	@command -v fswatch >/dev/null || { echo "fswatch not found — brew install fswatch"; exit 1; }
	@echo "Watching Sources/CCTV and SupportFiles — save a file to rebuild & relaunch."
	@echo "Dev build path: $(APP_BUNDLE)  (not $(INSTALL_APP))"
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
	rm -rf "$(INSTALL_APP)"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_APP)"
	open "$(INSTALL_APP)"
	@echo "Installed and opened $(INSTALL_APP)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
