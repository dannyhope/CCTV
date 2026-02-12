APP_NAME = CCTV
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
BUNDLE_ID = co.uk.dannyhope.cctv

SHELL = /bin/bash

.PHONY: build bundle codesign run clean

build:
	swift build -c release

bundle: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp SupportFiles/Info.plist "$(APP_BUNDLE)/Contents/"

codesign: bundle
	codesign --force --sign - "$(APP_BUNDLE)"

run: codesign
	open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
