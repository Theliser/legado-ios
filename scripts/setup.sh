#!/bin/sh
set -e

export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

echo "==> 1. Checking Homebrew..."
which brew >/dev/null 2>&1 || { echo "Homebrew is required. Install from https://brew.sh"; exit 1; }

echo "==> 2. Installing required development tools..."
for tool in xcodegen swiftlint swiftformat xcbeautify; do
    if ! which "$tool" >/dev/null 2>&1; then
        echo "Installing $tool..."
        brew install "$tool"
    else
        echo "  ✓ $tool is installed"
    fi
done

echo "==> 3. Configuring Git hooks..."
git config core.hooksPath .githooks
chmod +x .githooks/*

echo "==> 4. Generating Xcode project..."
xcodegen generate

echo "✨ Project environment setup complete!"
