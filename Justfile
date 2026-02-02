# Speakable - macOS TTS App
# Run `just` or `just --list` to see all available commands

# Default: show help
default:
    @just --list

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────

# Run this after modifying project.yml or pulling changes.
# Generate Xcode project from project.yml using XcodeGen
generate:
    xcodegen generate

# Output: ~/Library/Developer/Xcode/DerivedData/Speakable-*/Build/Products/Debug/
# Build Debug configuration
build: generate
    xcodebuild -scheme Speakable -configuration Debug build | xcbeautify

# Output: ~/Library/Developer/Xcode/DerivedData/Speakable-*/Build/Products/Release/
# Build Release configuration (optimized, no debug symbols)
build-release: generate
    xcodebuild -scheme Speakable -configuration Release build | xcbeautify

# The app will launch automatically after successful build.
# Build and run the app in Debug mode
run: build
    open ~/Library/Developer/Xcode/DerivedData/Speakable-*/Build/Products/Debug/Speakable.app

# Tests are defined in SpeakableTests/ directory.
# Run unit tests
test: generate
    xcodebuild -scheme Speakable -configuration Debug test | xcbeautify

# ─────────────────────────────────────────────────────────────────────────────
# Code Quality
# ─────────────────────────────────────────────────────────────────────────────

# Uses .swiftlint.yml for configuration. Fails on any warning (--strict).
# Run SwiftLint to check code style
lint:
    swiftlint --strict

# Uses .swiftformat for configuration. Exit code 1 if formatting needed.
# Check formatting without making changes
format-check:
    swiftformat --lint .

# Modifies files in place according to .swiftformat rules.
# Apply SwiftFormat to fix formatting
format:
    swiftformat .

# Useful for pre-commit verification.
# Run all checks (lint + format)
check: lint format-check

# Review changes with `git diff` after running.
# Auto-fix all fixable issues
fix:
    swiftlint --fix
    swiftformat .

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────────────────────

# Does not remove Xcode project or Swift packages.
# Clean build artifacts
clean:
    rm -rf build/
    rm -rf ~/Library/Developer/Xcode/DerivedData/Speakable-*
    @echo "Cleaned build artifacts"

# Run `just generate` to recreate it.
# Remove generated Xcode project
clean-project:
    rm -rf Speakable.xcodeproj
    @echo "Cleaned Xcode project"

# Full clean slate - next build will re-download all dependencies.
# Clean everything (build, project, packages)
clean-all: clean clean-project
    rm -rf SourcePackages/
    @echo "Cleaned everything"

# ─────────────────────────────────────────────────────────────────────────────
# Release
# Requires: Developer ID Application certificate
# Setup: https://developer.apple.com/account/resources/certificates
# ─────────────────────────────────────────────────────────────────────────────

# Output: build/Speakable.xcarchive
# Next step: just export-app
# Create Release archive for distribution
archive: generate
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Archiving Release build..."
    xcodebuild -scheme Speakable \
        -configuration Release \
        -archivePath build/Speakable.xcarchive \
        archive | xcbeautify
    echo "Archive created at build/Speakable.xcarchive"

# Requires: Developer ID Application certificate in Keychain.
# Uses ExportOptions.plist for signing configuration.
# Output: build/export/Speakable.app
# Next step: just create-dmg <version>
# Export signed .app from archive
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

# Usage: just create-dmg 1.0.0
# Output: build/Speakable-<version>.dmg
# Next step: just notarize <version> <apple_id> <team_id>
# Create DMG disk image from exported app
create-dmg version:
    #!/usr/bin/env bash
    set -euo pipefail
    APP_PATH="build/export/Speakable.app"
    DMG_PATH="build/Speakable-{{version}}.dmg"
    if [[ ! -d "$APP_PATH" ]]; then
        echo "Error: App not found. Run 'just export-app' first."
        exit 1
    fi
    echo "Creating DMG..."
    rm -f "$DMG_PATH"
    hdiutil create -volname "Speakable" \
        -srcfolder "$APP_PATH" \
        -ov -format UDZO \
        "$DMG_PATH"
    echo "Created $DMG_PATH"

# Usage: just notarize 1.0.0 your@email.com NAP6NNQHV6
# Requires: App-Specific Password stored in Keychain as "AC_PASSWORD".
# Setup: just setup-notarization <apple_id>
# Submit DMG to Apple for notarization
notarize version apple_id team_id:
    #!/usr/bin/env bash
    set -euo pipefail
    DMG_PATH="build/Speakable-{{version}}.dmg"
    if [[ ! -f "$DMG_PATH" ]]; then
        echo "Error: DMG not found. Run 'just create-dmg {{version}}' first."
        exit 1
    fi
    echo "Submitting for notarization..."
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "{{apple_id}}" \
        --team-id "{{team_id}}" \
        --password "@keychain:AC_PASSWORD" \
        --wait
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"
    echo "Notarization complete!"

# Usage: just release 1.0.0 your@email.com NAP6NNQHV6
# Runs: archive → export-app → create-dmg → notarize
# Output: build/Speakable-<version>.dmg (signed and notarized)
# Full release workflow
release version apple_id team_id: archive export-app (create-dmg version) (notarize version apple_id team_id)
    @echo ""
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    @echo "Release {{version}} complete!"
    @echo "DMG: build/Speakable-{{version}}.dmg"
    @echo ""
    @echo "Next steps:"
    @echo "  1. Test the DMG by mounting and running the app"
    @echo "  2. Create GitHub Release: gh release create v{{version}} build/Speakable-{{version}}.dmg"
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─────────────────────────────────────────────────────────────────────────────
# Version Management
# ─────────────────────────────────────────────────────────────────────────────

# Reads from project.yml and displays current version info.
# Show current version and build number
version:
    @grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" project.yml | sed 's/^[[:space:]]*//'

# Usage: just bump-version 0.2
# Updates MARKETING_VERSION in project.yml.
# Run `just generate` after to apply changes.
# Update version number (e.g., 0.1 → 0.2)
bump-version version:
    #!/usr/bin/env bash
    set -euo pipefail
    sed -i '' 's/MARKETING_VERSION: ".*"/MARKETING_VERSION: "{{version}}"/' project.yml
    # Reset build number to 1 for new version
    sed -i '' 's/CURRENT_PROJECT_VERSION: ".*"/CURRENT_PROJECT_VERSION: "1"/' project.yml
    echo "Version: {{version}} (build 1)"
    echo "Run 'just generate' to apply."

# Usage: just bump-build
# Increments CURRENT_PROJECT_VERSION in project.yml.
# Use when releasing a new build of the same version.
# Increment build number (e.g., 1 → 2)
bump-build:
    #!/usr/bin/env bash
    set -euo pipefail
    current=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | sed 's/.*"\([^"]*\)".*/\1/')
    next=$((current + 1))
    sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$next\"/" project.yml
    version=$(grep 'MARKETING_VERSION:' project.yml | sed 's/.*"\([^"]*\)".*/\1/')
    echo "Version: $version (build $next)"
    echo "Run 'just generate' to apply."

# ─────────────────────────────────────────────────────────────────────────────
# Beta Testing (for sharing with testers before release)
# ─────────────────────────────────────────────────────────────────────────────

# Creates unsigned .app for local/team testing.
# Testers need to right-click → Open to bypass Gatekeeper.
# Output: build/beta/Speakable.app
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
    echo "Share via AirDrop, zip, or cloud storage."
    echo "Testers: right-click → Open to bypass Gatekeeper."

# Creates a zip for easy sharing.
# Output: build/Speakable-beta.zip
# Package beta build as zip for sharing
beta-zip: beta
    #!/usr/bin/env bash
    set -euo pipefail
    cd build/beta
    zip -r ../Speakable-beta.zip Speakable.app
    echo "Created build/Speakable-beta.zip"

# ─────────────────────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────────────────────

# Look for "Developer ID Application" for distribution.
# "Apple Development" is for debug builds only.
# List code signing certificates in Keychain
show-certs:
    @echo "Code signing identities:"
    @security find-identity -v -p codesigning

# Generates project first if needed.
# Open project in Xcode
xcode: generate
    open Speakable.xcodeproj

# Useful for debugging code signing issues.
# Show build settings (signing, bundle ID)
show-settings:
    xcodebuild -scheme Speakable -configuration Debug -showBuildSettings | grep -E "DEVELOPMENT_TEAM|CODE_SIGN|PRODUCT_BUNDLE"

# Usage: just setup-notarization your@email.com
# You'll be prompted to enter your App-Specific Password.
# Get password at: https://appleid.apple.com → App-Specific Passwords
# Store notarization credentials in Keychain
setup-notarization apple_id:
    @echo "Storing notarization credentials in Keychain..."
    @echo "You'll need an App-Specific Password from https://appleid.apple.com"
    xcrun notarytool store-credentials AC_PASSWORD --apple-id "{{apple_id}}" --team-id NAP6NNQHV6
