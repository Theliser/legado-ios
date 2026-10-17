.PHONY: help setup generate lint format format-check build test clean feature

help:
	@echo "Legado iOS Development Commands:"
	@echo "  make setup        - Install tools (xcodegen, swiftlint, swiftformat, xcbeautify) and configure git hooks"
	@echo "  make generate     - Regenerate Xcode project via XcodeGen"
	@echo "  make lint         - Run SwiftLint and SwiftFormat checks"
	@echo "  make format       - Format code using SwiftFormat and SwiftLint auto-fix"
	@echo "  make format-check - Check formatting and linting without modifying files"
	@echo "  make build        - Build app for iOS Simulator"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make feature name=<name> - Create a new feature branch from develop"

setup:
	@bash scripts/setup.sh

generate:
	@xcodegen generate

lint:
	@bash scripts/lint.sh

format:
	@bash scripts/format.sh

format-check:
	@bash scripts/lint.sh

build:
	@xcodebuild -project Legado.xcodeproj -scheme Legado -destination 'platform=iOS Simulator,name=iPhone 17' build | xcbeautify

test:
	@xcodebuild -project Legado.xcodeproj -scheme Legado -destination 'platform=iOS Simulator,name=iPhone 17' test | xcbeautify

clean:
	@rm -rf .build DerivedData .derivedData
	@xcodebuild -project Legado.xcodeproj -scheme Legado clean | xcbeautify

feature:
	@if [ -z "$(name)" ]; then echo "❌ Error: please specify name, e.g.: make feature name=book-source"; exit 1; fi
	@git checkout develop
	@git pull origin develop
	@git checkout -b feature/$(name)
	@echo "✨ Created and switched to feature/$(name) from develop"
