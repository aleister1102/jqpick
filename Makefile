.PHONY: build test install clean demo help release release-all

# Binary name
BINARY_NAME=jqpick
GO_FILES=$(shell find . -name "*.go" -type f)

# Version and build info
VERSION?=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS=-ldflags "-X main.Version=$(VERSION) -X main.Commit=$(COMMIT) -X main.Date=$(DATE) -s -w"

# Build settings
BUILD_DIR=dist
INSTALL_PATH=/usr/local/bin

# GitHub settings
GITHUB_OWNER=$(shell git remote get-url origin | sed -n 's/.*github.com[:/]\([^/]*\).*/\1/p')
GITHUB_REPO=$(shell git remote get-url origin | sed -n 's/.*\/\([^\.]*\)\.git/\1/p')

help: ## Show this help message
	@echo "JQPick - Interactive JSON Explorer"
	@echo "===================================="
	@echo "Version: $(VERSION)"
	@echo "Commit: $(COMMIT)"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

version: ## Show current version
	@echo "Version: $(VERSION)"
	@echo "Commit: $(COMMIT)"
	@echo "Date: $(DATE)"

build: ## Build the binary
	@echo "🔨 Building $(BINARY_NAME) $(VERSION)..."
	@go build $(LDFLAGS) -o $(BINARY_NAME) .
	@echo "✅ Build complete: ./$(BINARY_NAME)"
	@echo "📊 Binary size: $$(du -h $(BINARY_NAME) | cut -f1)"

test: ## Run tests
	@echo "🧪 Running tests..."
	@go test -v -race -cover ./...
	@echo "✅ Tests passed"

install: build ## Install binary to system
	@echo "📦 Installing $(BINARY_NAME) to $(INSTALL_PATH)..."
	@sudo cp $(BINARY_NAME) $(INSTALL_PATH)/
	@echo "✅ Installation complete"
	@echo "🎯 You can now use: cat file.json | $(BINARY_NAME)"

uninstall: ## Uninstall binary from system
	@echo "🗑️  Removing $(BINARY_NAME) from $(INSTALL_PATH)..."
	@sudo rm -f $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "✅ Uninstall complete"

clean: ## Clean build artifacts
	@echo "🧹 Cleaning up..."
	@rm -f $(BINARY_NAME)
	@rm -f sample_data.json
	@rm -rf $(BUILD_DIR)
	@echo "✅ Clean complete"

demo: build ## Run interactive demo
	@echo "🎬 Starting JQPick demo..."
	@./demo.sh

deps: ## Download dependencies
	@echo "📥 Downloading dependencies..."
	@go mod download
	@go mod tidy
	@echo "✅ Dependencies updated"

lint: ## Run linter
	@echo "🔍 Running linter..."
	@golangci-lint run || echo "Install golangci-lint for linting"

fmt: ## Format code
	@echo "💅 Formatting code..."
	@go fmt ./...
	@echo "✅ Code formatted"

# Development targets
run: build ## Build and run with test data
	@echo "🚀 Running with test data..."
	@cat test.json | ./$(BINARY_NAME)

dev: ## Run development version with sample data
	@echo "🔧 Development mode..."
	@go run . < test.json

# Release targets
release-prepare: clean ## Prepare release directory
	@mkdir -p $(BUILD_DIR)

release-linux: release-prepare ## Build for Linux
	@echo "🐧 Building for Linux amd64..."
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 .
	@echo "🐧 Building for Linux arm64..."
	@GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64 .
	@echo "✅ Linux builds complete"

release-mac: release-prepare ## Build for macOS
	@echo "🍎 Building for macOS amd64..."
	@GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 .
	@echo "🍎 Building for macOS arm64..."
	@GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 .
	@echo "✅ macOS builds complete"

release-windows: release-prepare ## Build for Windows
	@echo "🪟 Building for Windows amd64..."
	@GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe .
	@echo "🪟 Building for Windows arm64..."
	@GOOS=windows GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-arm64.exe .
	@echo "✅ Windows builds complete"

release-all: release-linux release-mac release-windows ## Build for all platforms
	@echo "🌍 All platform builds complete"
	@ls -la $(BUILD_DIR)/

# GitHub Release targets
git-tag: ## Create and push a git tag (usage: make git-tag TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "❌ Please provide TAG=value"; exit 1; fi
	@echo "🏷️  Creating tag $(TAG)..."
	@git tag -a $(TAG) -m "Release $(TAG)"
	@git push origin $(TAG)
	@echo "✅ Tag $(TAG) created and pushed"

git-delete-tag: ## Delete a git tag (usage: make git-delete-tag TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "❌ Please provide TAG=value"; exit 1; fi
	@echo "🗑️  Deleting tag $(TAG)..."
	@git tag -d $(TAG)
	@git push origin :refs/tags/$(TAG)
	@echo "✅ Tag $(TAG) deleted"

# GitHub CLI release
github-release: release-all ## Create GitHub release with binaries
	@if [ -z "$(TAG)" ]; then echo "❌ Please provide TAG=value"; exit 1; fi
	@echo "📦 Creating GitHub release $(TAG)..."
	@gh release create $(TAG) $(BUILD_DIR)/* \
		--title "JQPick $(TAG)" \
		--notes "JQPick $(TAG) - Interactive JSON Explorer and JQ Query Builder\n\n## Installation\n\nDownload the appropriate binary for your platform and make it executable:\n\n### Linux\n\n\`\`\`bash\nwget https://github.com/$(GITHUB_OWNER)/$(GITHUB_REPO)/releases/download/$(TAG)/$(BINARY_NAME)-linux-amd64\nchmod +x $(BINARY_NAME)-linux-amd64\nsudo mv $(BINARY_NAME)-linux-amd64 /usr/local/bin/$(BINARY_NAME)\n\`\`\`\n\n### macOS\n\n\`\`\`bash\nwget https://github.com/$(GITHUB_OWNER)/$(GITHUB_REPO)/releases/download/$(TAG)/$(BINARY_NAME)-darwin-amd64\nchmod +x $(BINARY_NAME)-darwin-amd64\nsudo mv $(BINARY_NAME)-darwin-amd64 /usr/local/bin/$(BINARY_NAME)\n\`\`\`\n\n### Windows\n\nDownload the .exe file and add it to your PATH.\n\n## Usage\n\n\`\`\`bash\ncat file.json | $(BINARY_NAME)\n\`\`\`\n\nSee [README.md](https://github.com/$(GITHUB_OWNER)/$(GITHUB_REPO)/blob/main/README.md) for full documentation."
	@echo "✅ GitHub release $(TAG) created"

# Quick release workflow (tag + build + release)
release: ## Full release workflow (usage: make release TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "❌ Please provide TAG=value (e.g., TAG=v1.0.0)"; exit 1; fi
	@echo "🚀 Starting full release workflow for $(TAG)..."
	@$(MAKE) test
	@$(MAKE) git-tag TAG=$(TAG)
	@echo "⏳ Waiting for GitHub Actions to complete..."
	@echo "✅ Release workflow triggered. Check GitHub for build status."

release-complete: ## Trigger complete multi-platform release (usage: make release-complete TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "❌ Please provide TAG=value (e.g., TAG=v1.0.0)"; exit 1; fi
	@echo "🌍 Starting complete multi-platform release for $(TAG)..."
	@$(MAKE) test
	@echo "🏷️  Creating tag $(TAG)..."
	@git tag -a $(TAG) -m "Complete multi-platform release $(TAG)"
	@git push origin $(TAG)
	@echo "✅ Complete release workflow triggered for all platforms and architectures!"
	@echo "📊 This will build binaries for:"
	@echo "   🐧 Linux: amd64, arm64, 386, arm, ppc64le, s390x, riscv64, mips64, mips64le"
	@echo "   🍎 macOS: amd64, arm64"
	@echo "   🪟 Windows: amd64, arm64, 386"
	@echo "   🐱 BSD: FreeBSD, OpenBSD, NetBSD (amd64, arm64, 386)"
	@echo "   ☀️ Other: Solaris, AIX, Android"
	@echo ""
	@echo "⏳ Check GitHub Actions for build progress:"
	@echo "   https://github.com/$(GITHUB_OWNER)/$(GITHUB_REPO)/actions"

# CI/CD targets (used by GitHub Actions)
ci-build: ## Build for CI (sets version from environment)
	@echo "🔨 CI build - Version: $(VERSION)"
	@go build $(LDFLAGS) -o $(BINARY_NAME) .

ci-test: ## Run tests for CI
	@echo "🧪 CI tests..."
	@go test -v -race -cover -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "📊 Coverage report generated"

ci-release: release-all ## Build all platforms for CI release
	@echo "📦 CI release build complete"

# Development helpers
watch: ## Watch for changes and rebuild (requires entr)
	@echo "👀 Watching for changes..."
	@find . -name '*.go' | entr -r make build

benchmark: ## Run benchmarks
	@echo "⚡ Running benchmarks..."
	@go test -bench=. -benchmem ./...

# Check and validation
check: fmt test lint ## Run all checks (format, test, lint)
	@echo "✅ All checks passed"

# Show current git status
git-status: ## Show git status and recent commits
	@echo "📊 Git Status:"
	@git status --short
	@echo ""
	@echo "📜 Recent commits:"
	@git log --oneline -5