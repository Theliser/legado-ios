#!/bin/sh
set -e

export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

echo "==> Checking Swift code formatting (SwiftFormat)..."
swiftformat --lint .

echo "==> Linting Swift code (SwiftLint)..."
swiftlint lint

echo "✅ All lint checks passed!"
