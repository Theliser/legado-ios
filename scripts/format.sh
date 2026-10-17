#!/bin/sh
set -e

export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

echo "==> Formatting code with SwiftFormat..."
swiftformat .

echo "==> Running SwiftLint autocorrect..."
swiftlint --fix

echo "✅ Code formatting and auto-fixes applied!"
