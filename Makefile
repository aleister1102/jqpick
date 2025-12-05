.PHONY: build test install install-local uninstall clean demo help release release-all

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
INSTALL_PATH?=/usr/local/bin
LOCAL_INSTALL_PATH=$(HOME)/.local/bin

# GitHub settings
GITHUB_OWNER=$(shell git remote get-url origin 2>/dev/null | sed -n 's/.*github.com[:/]\([^/]*\).*/\1/p')
GITHUB_REPO=$(shell basename -s .git $$(git remote get-url origin 2>/dev/null) 2>/dev/null || echo "jqpick")

# Detect OS and architecture
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Linux)
	OS := linux
endif
ifeq ($(UNAME_S),Darwin)
	OS := darwin
endif
ifeq ($(UNAME_M),x86_64)
	ARCH := amd64
endif
ifeq ($(UNAME_M),arm64)
	ARCH := arm64
endif
ifeq ($(UNAME_M),aarch64)
	ARCH := arm64
endif

help: ## Show this help message
	@echo "JQPick - Interactive JSON Explorer"
	@echo "===================================="
	@echo "Version: $(VERSION)"
	@echo "Commit: $(COMMIT)"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

version: ## Show current version
	@echo "Version: $(VERSION)"
	@echo "Commit: $(COMMIT)"
	@echo "Date: $(DATE)"
	@echo "OS: $(OS)"
	@echo "Arch: $(ARCH)"

build: ## Build the binary for current platform
	@echo "Building $(BINARY_NAME) $(VERSION)..."
	@go build $(LDFLAGS) -o $(BINARY_NAME) .
	@echo "Build complete: ./$(BINARY_NAME)"
	@echo "Binary size: $$(du -h $(BINARY_NAME) | cut -f1)"

test: ## Run tests
	@echo "Running tests..."
	@go test -v -race -cover ./...
	@echo "Tests passed"

install: build ## Install binary to system (requires sudo)
	@echo "Installing $(BINARY_NAME) to $(INSTALL_PATH)..."
	@sudo install -d $(INSTALL_PATH)
	@sudo install -m 755 $(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "Installation complete"
	@echo "You can now use: cat file.json | $(BINARY_NAME)"

install-local: build ## Install binary to user local bin (no sudo required)
	@echo "Installing $(BINARY_NAME) to $(LOCAL_INSTALL_PATH)..."
	@mkdir -p $(LOCAL_INSTALL_PATH)
	@install -m 755 $(BINARY_NAME) $(LOCAL_INSTALL_PATH)/$(BINARY_NAME)
	@echo "Installation complete"
	@if echo "$$PATH" | grep -q "$(LOCAL_INSTALL_PATH)"; then \
		echo "You can now use: cat file.json | $(BINARY_NAME)"; \
	else \
		echo "Add $(LOCAL_INSTALL_PATH) to your PATH:"; \
		echo "  export PATH=\"$(LOCAL_INSTALL_PATH):\$$PATH\""; \
	fi

uninstall: ## Uninstall binary from system
	@echo "Removing $(BINARY_NAME)..."
	@sudo rm -f $(INSTALL_PATH)/$(BINARY_NAME) 2>/dev/null || true
	@rm -f $(LOCAL_INSTALL_PATH)/$(BINARY_NAME) 2>/dev/null || true
	@echo "Uninstall complete"

clean: ## Clean build artifacts
	@echo "Cleaning up..."
	@rm -f $(BINARY_NAME)
	@rm -f sample_data.json
	@rm -rf $(BUILD_DIR)
	@echo "Clean complete"

demo: build ## Run interactive demo
	@echo "Starting JQPick demo..."
	@./demo.sh

deps: ## Download dependencies
	@echo "Downloading dependencies..."
	@go mod download
	@go mod tidy
	@echo "Dependencies updated"

lint: ## Run linter
	@echo "Running linter..."
	@golangci-lint run || echo "Install golangci-lint for linting"

fmt: ## Format code
	@echo "Formatting code..."
	@go fmt ./...
	@echo "Code formatted"

# Development targets
run: build ## Build and run with test data
	@echo "Running with test data..."
	@cat test.json | ./$(BINARY_NAME)

dev: ## Run development version with sample data
	@echo "Development mode..."
	@go run . < test.json

# Release targets
release-prepare: clean ## Prepare release directory
	@mkdir -p $(BUILD_DIR)

release-linux: release-prepare ## Build for Linux
	@echo "Building for Linux amd64..."
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 .
	@echo "Building for Linux arm64..."
	@GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64 .
	@echo "Linux builds complete"

release-mac: release-prepare ## Build for macOS
	@echo "Building for macOS amd64..."
	@GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 .
	@echo "Building for macOS arm64..."
	@GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 .
	@echo "macOS builds complete"

release-windows: release-prepare ## Build for Windows
	@echo "Building for Windows amd64..."
	@GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe .
	@echo "Building for Windows arm64..."
	@GOOS=windows GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-arm64.exe .
	@echo "Windows builds complete"

release-all: release-linux release-mac release-windows ## Build for all platforms
	@echo "All platform builds complete"
	@ls -la $(BUILD_DIR)/

# Checksums
checksums: ## Generate checksums for release binaries
	@echo "Generating checksums..."
	@cd $(BUILD_DIR) && sha256sum * > checksums.txt 2>/dev/null || shasum -a 256 * > checksums.txt
	@echo "Checksums generated: $(BUILD_DIR)/checksums.txt"

# Archive release binaries
archive: release-all checksums ## Create compressed archives for release
	@echo "Creating archives..."
	@cd $(BUILD_DIR) && for f in $(BINARY_NAME)-*; do \
		if [ -f "$$f" ] && [ "$$f" != "checksums.txt" ]; then \
			case "$$f" in \
				*.exe) zip "$${f%.exe}.zip" "$$f" ;; \
				*) tar -czvf "$$f.tar.gz" "$$f" ;; \
			esac; \
		fi; \
	done
	@echo "Archives created"

# GitHub Release targets
git-tag: ## Create and push a git tag (usage: make git-tag TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "Please provide TAG=value"; exit 1; fi
	@echo "Creating tag $(TAG)..."
	@git tag -a $(TAG) -m "Release $(TAG)"
	@git push origin $(TAG)
	@echo "Tag $(TAG) created and pushed"

git-delete-tag: ## Delete a git tag (usage: make git-delete-tag TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "Please provide TAG=value"; exit 1; fi
	@echo "Deleting tag $(TAG)..."
	@git tag -d $(TAG)
	@git push origin :refs/tags/$(TAG)
	@echo "Tag $(TAG) deleted"

# Quick release workflow
release: ## Full release workflow (usage: make release TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "Please provide TAG=value (e.g., TAG=v1.0.0)"; exit 1; fi
	@./scripts/release.sh $(TAG)

# CI/CD targets (used by GitHub Actions)
ci-build: ## Build for CI (sets version from environment)
	@echo "CI build - Version: $(VERSION)"
	@go build $(LDFLAGS) -o $(BINARY_NAME) .

ci-test: ## Run tests for CI
	@echo "CI tests..."
	@go test -v -race -cover -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated"

ci-release: release-all checksums ## Build all platforms for CI release
	@echo "CI release build complete"

# Development helpers
watch: ## Watch for changes and rebuild (requires entr)
	@echo "Watching for changes..."
	@find . -name '*.go' | entr -r make build

benchmark: ## Run benchmarks
	@echo "Running benchmarks..."
	@go test -bench=. -benchmem ./...

# Check and validation
check: fmt test lint ## Run all checks (format, test, lint)
	@echo "All checks passed"

# Show current git status
git-status: ## Show git status and recent commits
	@echo "Git Status:"
	@git status --short
	@echo ""
	@echo "Recent commits:"
	@git log --oneline -5

# Docker targets
docker-build: ## Build Docker image
	@echo "Building Docker image..."
	@docker build -t $(BINARY_NAME):$(VERSION) -t $(BINARY_NAME):latest .
	@echo "Docker image built: $(BINARY_NAME):$(VERSION)"

docker-run: docker-build ## Run in Docker container
	@echo "Running $(BINARY_NAME) in Docker..."
	@cat test.json | docker run -i $(BINARY_NAME):latest
