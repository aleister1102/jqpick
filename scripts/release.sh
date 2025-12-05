#!/usr/bin/env bash
#
# Release script for jqpick
# Automates the process of creating and publishing releases to GitHub
#
# Usage:
#   ./scripts/release.sh <version>
#   ./scripts/release.sh v1.0.0
#   ./scripts/release.sh v1.0.0 --draft
#   ./scripts/release.sh v1.0.0 --prerelease
#
# Requirements:
#   - gh (GitHub CLI) installed and authenticated
#   - git configured with push access to the repository

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
BINARY_NAME="jqpick"
BUILD_DIR="dist"

# Parse arguments
VERSION="${1:-}"
DRAFT=""
PRERELEASE=""

shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --draft)
            DRAFT="--draft"
            shift
            ;;
        --prerelease)
            PRERELEASE="--prerelease"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated"
        echo "Run: gh auth login"
        exit 1
    fi
    
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed"
        exit 1
    fi
    
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        log_error "Not inside a git repository"
        exit 1
    fi
    
    log_success "All requirements met"
}

validate_version() {
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required"
        echo ""
        echo "Usage: $0 <version> [options]"
        echo ""
        echo "Examples:"
        echo "  $0 v1.0.0"
        echo "  $0 v1.0.0 --draft"
        echo "  $0 v1.0.0 --prerelease"
        exit 1
    fi
    
    # Ensure version starts with 'v'
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
        log_warn "Version prefix 'v' added: $VERSION"
    fi
    
    # Validate semver format
    if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        log_error "Invalid version format: $VERSION"
        echo "Expected format: v1.0.0 or v1.0.0-beta.1"
        exit 1
    fi
    
    # Check if tag already exists
    if git rev-parse "$VERSION" &> /dev/null; then
        log_error "Tag $VERSION already exists"
        echo "To delete the existing tag:"
        echo "  git tag -d $VERSION"
        echo "  git push origin :refs/tags/$VERSION"
        exit 1
    fi
    
    log_success "Version validated: $VERSION"
}

check_clean_tree() {
    log_info "Checking git status..."
    
    if [[ -n $(git status --porcelain) ]]; then
        log_warn "Working directory has uncommitted changes"
        git status --short
        echo ""
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "Working directory is clean"
    fi
}

run_tests() {
    log_info "Running tests..."
    if go test -v -race ./...; then
        log_success "All tests passed"
    else
        log_error "Tests failed"
        exit 1
    fi
}

build_binaries() {
    log_info "Building binaries for all platforms..."
    
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Build flags
    COMMIT=$(git rev-parse --short HEAD)
    DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    LDFLAGS="-X main.Version=$VERSION -X main.Commit=$COMMIT -X main.Date=$DATE -s -w"
    
    # Platforms to build
    PLATFORMS=(
        "linux/amd64"
        "linux/arm64"
        "darwin/amd64"
        "darwin/arm64"
        "windows/amd64"
        "windows/arm64"
    )
    
    for platform in "${PLATFORMS[@]}"; do
        OS="${platform%/*}"
        ARCH="${platform#*/}"
        OUTPUT="$BUILD_DIR/${BINARY_NAME}-${OS}-${ARCH}"
        
        if [[ "$OS" == "windows" ]]; then
            OUTPUT="${OUTPUT}.exe"
        fi
        
        log_info "Building for $OS/$ARCH..."
        GOOS="$OS" GOARCH="$ARCH" go build -ldflags "$LDFLAGS" -o "$OUTPUT" .
        
        if [[ -f "$OUTPUT" ]]; then
            log_success "Built: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
        else
            log_error "Failed to build: $OUTPUT"
            exit 1
        fi
    done
    
    log_success "All binaries built successfully"
}

create_checksums() {
    log_info "Creating checksums..."
    
    cd "$BUILD_DIR"
    
    if command -v sha256sum &> /dev/null; then
        sha256sum ${BINARY_NAME}-* > checksums.txt
    else
        shasum -a 256 ${BINARY_NAME}-* > checksums.txt
    fi
    
    cd - > /dev/null
    
    log_success "Checksums created: $BUILD_DIR/checksums.txt"
}

create_archives() {
    log_info "Creating release archives..."
    
    cd "$BUILD_DIR"
    
    for binary in ${BINARY_NAME}-*; do
        if [[ -f "$binary" ]] && [[ "$binary" != "checksums.txt" ]] && [[ ! "$binary" =~ \.(tar\.gz|zip)$ ]]; then
            if [[ "$binary" =~ \.exe$ ]]; then
                # Windows: create zip
                archive="${binary%.exe}.zip"
                zip "$archive" "$binary"
                log_success "Created: $archive"
            else
                # Unix: create tar.gz
                archive="${binary}.tar.gz"
                tar -czvf "$archive" "$binary" > /dev/null
                log_success "Created: $archive"
            fi
        fi
    done
    
    cd - > /dev/null
    
    log_success "All archives created"
}

create_git_tag() {
    log_info "Creating git tag: $VERSION"
    
    git tag -a "$VERSION" -m "Release $VERSION"
    log_success "Tag created locally"
    
    log_info "Pushing tag to origin..."
    git push origin "$VERSION"
    log_success "Tag pushed to origin"
}

generate_release_notes() {
    log_info "Generating release notes..."
    
    # Get commits since last tag
    LAST_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
    
    RELEASE_NOTES="## $BINARY_NAME $VERSION

### Installation

Download the appropriate binary for your platform from the assets below.

#### Linux
\`\`\`bash
# AMD64
curl -LO https://github.com/\$(gh repo view --json owner -q .owner.login)/\$(gh repo view --json name -q .name)/releases/download/${VERSION}/${BINARY_NAME}-linux-amd64.tar.gz
tar -xzf ${BINARY_NAME}-linux-amd64.tar.gz
sudo mv ${BINARY_NAME}-linux-amd64 /usr/local/bin/${BINARY_NAME}

# ARM64
curl -LO https://github.com/\$(gh repo view --json owner -q .owner.login)/\$(gh repo view --json name -q .name)/releases/download/${VERSION}/${BINARY_NAME}-linux-arm64.tar.gz
tar -xzf ${BINARY_NAME}-linux-arm64.tar.gz
sudo mv ${BINARY_NAME}-linux-arm64 /usr/local/bin/${BINARY_NAME}
\`\`\`

#### macOS
\`\`\`bash
# Intel Mac
curl -LO https://github.com/\$(gh repo view --json owner -q .owner.login)/\$(gh repo view --json name -q .name)/releases/download/${VERSION}/${BINARY_NAME}-darwin-amd64.tar.gz
tar -xzf ${BINARY_NAME}-darwin-amd64.tar.gz
sudo mv ${BINARY_NAME}-darwin-amd64 /usr/local/bin/${BINARY_NAME}

# Apple Silicon
curl -LO https://github.com/\$(gh repo view --json owner -q .owner.login)/\$(gh repo view --json name -q .name)/releases/download/${VERSION}/${BINARY_NAME}-darwin-arm64.tar.gz
tar -xzf ${BINARY_NAME}-darwin-arm64.tar.gz
sudo mv ${BINARY_NAME}-darwin-arm64 /usr/local/bin/${BINARY_NAME}
\`\`\`

#### Windows
Download the appropriate \`.zip\` file from assets, extract, and add to your PATH.

### Usage
\`\`\`bash
cat file.json | ${BINARY_NAME}
\`\`\`

### Verify Download
\`\`\`bash
# Download checksums
curl -LO https://github.com/\$(gh repo view --json owner -q .owner.login)/\$(gh repo view --json name -q .name)/releases/download/${VERSION}/checksums.txt

# Verify (Linux)
sha256sum -c checksums.txt --ignore-missing

# Verify (macOS)
shasum -a 256 -c checksums.txt --ignore-missing
\`\`\`
"

    if [[ -n "$LAST_TAG" ]]; then
        RELEASE_NOTES+="
### Changes since $LAST_TAG
$(git log --oneline "$LAST_TAG..HEAD" | head -20 | sed 's/^/- /')
"
    fi
    
    echo "$RELEASE_NOTES"
}

create_github_release() {
    log_info "Creating GitHub release..."
    
    NOTES=$(generate_release_notes)
    
    # Build the release command
    RELEASE_CMD="gh release create $VERSION $BUILD_DIR/*.tar.gz $BUILD_DIR/*.zip $BUILD_DIR/checksums.txt"
    RELEASE_CMD+=" --title \"$BINARY_NAME $VERSION\""
    RELEASE_CMD+=" --notes \"$NOTES\""
    
    if [[ -n "$DRAFT" ]]; then
        RELEASE_CMD+=" $DRAFT"
        log_info "Creating draft release..."
    fi
    
    if [[ -n "$PRERELEASE" ]]; then
        RELEASE_CMD+=" $PRERELEASE"
        log_info "Creating pre-release..."
    fi
    
    # Execute release
    eval "$RELEASE_CMD"
    
    log_success "GitHub release created: $VERSION"
    
    # Get release URL
    RELEASE_URL=$(gh release view "$VERSION" --json url -q .url)
    echo ""
    echo -e "${GREEN}Release published successfully!${NC}"
    echo -e "URL: ${BLUE}$RELEASE_URL${NC}"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    # Keep dist folder for reference, only remove if specified
    log_success "Cleanup complete"
}

main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $BINARY_NAME Release Script${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    check_requirements
    validate_version
    check_clean_tree
    run_tests
    build_binaries
    create_checksums
    create_archives
    create_git_tag
    create_github_release
    cleanup
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Release $VERSION Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

main

