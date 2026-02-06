# Speakable - macOS TTS App
# Run `just` or `just --list` to see all available commands
# Auto-derived from project.yml

app_version := `grep 'MARKETING_VERSION:' project.yml | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/"`
app_build := `grep 'CURRENT_PROJECT_VERSION:' project.yml | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/"`
sparkle_version := "2.8.1"

default:
    @just --list

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────

# Generate Xcode project from project.yml
generate:
    xcodegen generate

# Build Debug configuration
build: generate
    xcodebuild -scheme Speakable -configuration Debug -derivedDataPath build/derived build | xcbeautify

# Build Release configuration
build-release: generate
    xcodebuild -scheme Speakable -configuration Release -derivedDataPath build/derived build | xcbeautify

# Kill running Debug app (if any)
kill-debug:
    @-pkill -x "Speakable Debug" 2>/dev/null || true

# Run already-built Debug app (requires prior `just build`)
run-built:
    open "build/derived/Build/Products/Debug/Speakable Debug.app"

# Build and run Debug
run: kill-debug build run-built

# Run tests without rebuilding (requires prior `just test-build`)
test-run:
    xcodebuild -scheme Speakable -configuration Debug -derivedDataPath build/derived test-without-building | xcbeautify

# Build for testing only
test-build: generate
    xcodebuild -scheme Speakable -configuration Debug -derivedDataPath build/derived build-for-testing | xcbeautify

# Build and run unit tests
test: test-build test-run

# ─────────────────────────────────────────────────────────────────────────────
# Code Quality
# ─────────────────────────────────────────────────────────────────────────────

# Run SwiftLint (fails on warnings)
lint:
    swiftlint --strict

# Check formatting without changes
format-check:
    swiftformat --lint .

# Apply SwiftFormat
format:
    swiftformat .

# Run all checks (lint + format)
check: lint format-check

# Auto-fix all fixable issues
fix:
    swiftlint --fix
    swiftformat .

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────────────────────

# Clean build artifacts
clean:
    rm -rf build/
    @echo "Cleaned build artifacts"

# Remove generated Xcode project (run `just generate` to recreate)
clean-project:
    rm -rf Speakable.xcodeproj
    @echo "Cleaned Xcode project"

# Clean everything (build + project + packages)
clean-all: clean clean-project
    rm -rf SourcePackages/
    @echo "Cleaned everything"

# ─────────────────────────────────────────────────────────────────────────────
# Release
# Requires: Developer ID certificate + `just setup-notarization` (one-time)
# ─────────────────────────────────────────────────────────────────────────────

# Create Release archive → build/Speakable.xcarchive
archive: generate
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Archiving Release build..."
    xcodebuild -scheme Speakable \
        -configuration Release \
        -archivePath build/Speakable.xcarchive \
        archive | xcbeautify
    echo "Archive created at build/Speakable.xcarchive"

# Export signed .app from archive → build/export/Speakable.app
export-app:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -d "build/Speakable.xcarchive" ]]; then
        echo "Error: Archive not found. Run 'just archive' first."
        exit 1
    fi
    echo "Exporting signed app..."
    xcodebuild -exportArchive \
        -archivePath build/Speakable.xcarchive \
        -exportPath build/export \
        -exportOptionsPlist ExportOptions.plist | xcbeautify
    echo "Exported to build/export/"

# Fix Sparkle framework in xcarchive: remove non-standard root symlinks that
# cause "unsealed contents" code signing errors.
# Must run BEFORE export-app so Xcode cloud signing re-signs correctly.
# Ref: https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears
fix-sparkle-framework:
    #!/usr/bin/env bash
    set -euo pipefail
    FRAMEWORK="build/Speakable.xcarchive/Products/Applications/Speakable.app/Contents/Frameworks/Sparkle.framework"
    if [[ ! -d "$FRAMEWORK" ]]; then
        echo "Error: Archive not found. Run 'just archive' first."
        exit 1
    fi
    echo "Removing non-standard root symlinks from Sparkle.framework in archive..."
    for link in Autoupdate Updater.app XPCServices; do
        if [[ -L "$FRAMEWORK/$link" ]]; then
            rm "$FRAMEWORK/$link"
            echo "  Removed: $link"
        fi
    done
    echo "Done. Export will re-sign via Xcode cloud signing."

# Create zip from exported app → build/Speakable-<version>.zip
create-zip:
    #!/usr/bin/env bash
    set -euo pipefail
    APP_PATH="build/export/Speakable.app"
    ZIP_PATH="build/Speakable-{{ app_version }}.zip"
    if [[ ! -d "$APP_PATH" ]]; then
        echo "Error: App not found. Run 'just export-app' first."
        exit 1
    fi
    echo "Creating zip..."
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
    echo "Created $ZIP_PATH"

# Submit zip to Apple for notarization and staple ticket
notarize:
    #!/usr/bin/env bash
    set -euo pipefail
    ZIP_PATH="build/Speakable-{{ app_version }}.zip"
    if [[ ! -f "$ZIP_PATH" ]]; then
        echo "Error: zip not found. Run 'just create-zip' first."
        exit 1
    fi
    echo "Submitting for notarization..."
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "AC_PASSWORD" \
        --wait
    echo "Stapling notarization ticket..."
    xcrun stapler staple "build/export/Speakable.app"
    echo "Recreating zip with stapled ticket..."
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "build/export/Speakable.app" "$ZIP_PATH"
    echo "Notarization complete!"

# Full release: archive → fix sparkle → export → zip → notarize
release: archive fix-sparkle-framework export-app create-zip notarize
    @echo ""
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    @echo "Release {{ app_version }} (build {{ app_build }}) complete!"
    @echo "Zip: build/Speakable-{{ app_version }}.zip"
    @echo ""
    @echo "Next step — create GitHub Release (appcast auto-deploys via CI):"
    @echo "  gh release create v{{ app_version }} build/Speakable-{{ app_version }}.zip --title 'v{{ app_version }}'"
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─────────────────────────────────────────────────────────────────────────────
# Sparkle Tools
# ─────────────────────────────────────────────────────────────────────────────

# Download Sparkle CLI tools (one-time)
sparkle-download-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    TOOLS_DIR="build/sparkle-tools"
    if [[ -d "$TOOLS_DIR/bin" ]]; then
        echo "Sparkle tools already present at $TOOLS_DIR"
        exit 0
    fi
    echo "Downloading Sparkle {{ sparkle_version }} tools..."
    mkdir -p "$TOOLS_DIR"
    curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/{{ sparkle_version }}/Sparkle-{{ sparkle_version }}.tar.xz" \
        | tar -xJ -C "$TOOLS_DIR" --include='./bin/*'
    echo "Sparkle tools installed to $TOOLS_DIR/bin/"
    ls "$TOOLS_DIR/bin/"

# Generate Sparkle EdDSA signing keys (one-time)
sparkle-generate-keys: sparkle-download-tools
    build/sparkle-tools/bin/generate_keys --account speakable-ed25519

# Show Sparkle EdDSA public key
sparkle-show-public-key: sparkle-download-tools
    build/sparkle-tools/bin/generate_keys -p --account speakable-ed25519

# ─────────────────────────────────────────────────────────────────────────────
# Version Management
# ─────────────────────────────────────────────────────────────────────────────

# Show current version and build number
version:
    @echo "{{ app_version }} (build {{ app_build }})"

# Bump version: just bump-version major | minor | patch | 1.2.3
bump-version part:
    #!/usr/bin/env bash
    set -euo pipefail
    current="{{ app_version }}"
    IFS='.' read -r major minor patch <<< "$current"
    case "{{ part }}" in
        major) new="$((major + 1)).0.0" ;;
        minor) new="${major}.$((minor + 1)).0" ;;
        patch) new="${major}.${minor}.$((patch + 1))" ;;
        *)     new="{{ part }}" ;;
    esac
    sed -i '' "s/MARKETING_VERSION: '.*'/MARKETING_VERSION: '$new'/" project.yml
    echo "Version: $current → $new (build {{ app_build }})"
    echo "Run 'just generate' to apply."

# Increment build number
bump-build:
    #!/usr/bin/env bash
    set -euo pipefail
    next=$(({{ app_build }} + 1))
    sed -i '' "s/CURRENT_PROJECT_VERSION: '.*'/CURRENT_PROJECT_VERSION: '$next'/" project.yml
    echo "Version: {{ app_version }} (build {{ app_build }} → $next)"
    echo "Run 'just generate' to apply."

# ─────────────────────────────────────────────────────────────────────────────
# Beta Testing
# ─────────────────────────────────────────────────────────────────────────────

# Build for beta testing (no notarization)
beta: generate
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building for beta testing..."
    xcodebuild -scheme Speakable \
        -configuration Release \
        -derivedDataPath build/beta-derived \
        build | xcbeautify
    rm -rf build/beta
    mkdir -p build/beta
    cp -R build/beta-derived/Build/Products/Release/Speakable.app build/beta/
    echo ""
    echo "Beta build ready: build/beta/Speakable.app"
    echo "Testers: right-click → Open to bypass Gatekeeper."

# Package beta build as zip
beta-zip: beta
    #!/usr/bin/env bash
    set -euo pipefail
    cd build/beta
    zip -r ../Speakable-beta.zip Speakable.app
    echo "Created build/Speakable-beta.zip"

# ─────────────────────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────────────────────

# List code signing certificates
show-certs:
    @security find-identity -v -p codesigning

# Open project in Xcode
xcode: generate
    open Speakable.xcodeproj

# Show build settings (signing, bundle ID)
show-settings:
    xcodebuild -scheme Speakable -configuration Debug -showBuildSettings | grep -E "DEVELOPMENT_TEAM|CODE_SIGN|PRODUCT_BUNDLE"

# Store notarization credentials in Keychain (one-time)
setup-notarization apple_id:
    @echo "You'll need an App-Specific Password from https://account.apple.com"
    xcrun notarytool store-credentials AC_PASSWORD --apple-id "{{ apple_id }}" --team-id NAP6NNQHV6
