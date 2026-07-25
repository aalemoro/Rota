APP_NAME    = Rota
WIDGET_NAME = RotaWidgetExtension
VERSION     = 2.2.0
BUILD_DIR   = .build/release
APP_DIR     = build/$(APP_NAME).app
APPEX_DIR   = $(APP_DIR)/Contents/PlugIns/$(WIDGET_NAME).appex

.PHONY: all build icon app install run zip clean

all: app

## Compile both the app and the widget extension (release).
build:
	swift build -c release

## Build the .icns from the iconset (uses macOS's iconutil).
icon: build/AppIcon.icns

build/AppIcon.icns: design/AppIcon.iconset
	@mkdir -p build
	iconutil -c icns design/AppIcon.iconset -o build/AppIcon.icns

## Assemble a signed (ad-hoc) .app bundle with the widget extension inside.
app: build icon
	@rm -rf "$(APP_DIR)"
	@mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	@mkdir -p "$(APPEX_DIR)/Contents/MacOS" "$(APPEX_DIR)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	@cp "$(BUILD_DIR)/$(WIDGET_NAME)" "$(APPEX_DIR)/Contents/MacOS/$(WIDGET_NAME)"
	@cp build/AppIcon.icns "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	@cp build/AppIcon.icns "$(APPEX_DIR)/Contents/Resources/AppIcon.icns"
	@sed -e "s/@VERSION@/$(VERSION)/g" scripts/Info.plist > "$(APP_DIR)/Contents/Info.plist"
	@sed -e "s/@VERSION@/$(VERSION)/g" scripts/WidgetInfo.plist > "$(APPEX_DIR)/Contents/Info.plist"
	@printf 'APPL????' > "$(APP_DIR)/Contents/PkgInfo"
	@printf 'XPC!????' > "$(APPEX_DIR)/Contents/PkgInfo"
	@codesign --force --sign - --entitlements scripts/widget.entitlements "$(APPEX_DIR)"
	@codesign --force --sign - "$(APP_DIR)"
	@echo "✅  Built $(APP_DIR) (widget extension included)"

## Copy the app into /Applications (falls back to ~/Applications).
install: app
	@if rm -rf "/Applications/$(APP_NAME).app" 2>/dev/null && cp -R "$(APP_DIR)" /Applications/ 2>/dev/null; then \
		echo "✅  Installed to /Applications/$(APP_NAME).app"; \
	else \
		mkdir -p ~/Applications && rm -rf ~/Applications/"$(APP_NAME).app" && cp -R "$(APP_DIR)" ~/Applications/; \
		echo "✅  Installed to ~/Applications/$(APP_NAME).app"; \
	fi

## Build and launch straight from ./build.
run: app
	open "$(APP_DIR)"

## Zip the app for a GitHub release.
zip: app
	cd build && ditto -c -k --keepParent "$(APP_NAME).app" "$(APP_NAME)-$(VERSION)-macOS.zip"
	@echo "✅  build/$(APP_NAME)-$(VERSION)-macOS.zip"

clean:
	rm -rf .build build
