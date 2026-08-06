.DEFAULT_GOAL := help
PACKAGE := Packages/QuillCore
SIMULATOR := platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: help project test build lint clean verify

help: ## Show available targets
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

project: ## Regenerate Quill.xcodeproj from project.yml
	xcodegen generate

test: ## Run the package test suite (no simulator needed)
	swift test --package-path $(PACKAGE)

build: ## Build the app for the iOS Simulator
	xcodebuild build -project Quill.xcodeproj -scheme Quill -destination '$(SIMULATOR)' -quiet

lint: ## Run SwiftLint in strict mode
	swiftlint lint --strict

# Mirrors CI, so a green run here means a green run there.
verify: lint test build ## Everything CI runs

clean: ## Remove build artefacts
	rm -rf build .build $(PACKAGE)/.build
	xcodebuild clean -project Quill.xcodeproj -scheme Quill -quiet || true
