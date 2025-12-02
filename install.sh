#!/bin/bash

# JQPick Installation Script
# Downloads the appropriate binary for your platform

set -e

# Configuration
REPO="aleister1102/jqpick"
BINARY_NAME="jqpick"
VERSION="${1:-v1.3.0}"  # Use v1.3.0 by default, or allow override

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 JQPick Installer${NC}"
echo -e "${GREEN}===================${NC}"
echo

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    linux*) OS="linux" ;;
    darwin*) OS="darwin" ;;
    freebsd*) OS="freebsd" ;;
    openbsd*) OS="openbsd" ;;
    netbsd*) OS="netbsd" ;;
    *) echo -e "${RED}❌ Unsupported OS: $OS${NC}"; exit 1 ;;
esac

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    i386|i686) ARCH="386" ;;
    armv7l) ARCH="arm" ;;
    ppc64le) ARCH="ppc64le" ;;
    s390x) ARCH="s390x" ;;
    riscv64) ARCH="riscv64" ;;
    *) echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"; exit 1 ;;
esac

echo -e "${YELLOW}📋 Detected platform:${NC} $OS/$ARCH"
echo -e "${YELLOW}📦 Version:${NC} $VERSION"
echo

# Construct download URL
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY_NAME}-${OS}-${ARCH}"

# Check if Windows
if [ "$OS" = "windows" ]; then
    DOWNLOAD_URL="${DOWNLOAD_URL}.exe"
    BINARY_NAME="${BINARY_NAME}.exe"
fi

echo -e "${YELLOW}⬇️  Downloading from:${NC} $DOWNLOAD_URL"

# Download the binary
if command -v curl >/dev/null 2>&1; then
    if curl -fL -o "$BINARY_NAME.tmp" "$DOWNLOAD_URL"; then
        echo -e "${GREEN}✅ Download successful${NC}"
    else
        echo -e "${RED}❌ Download failed${NC}"
        echo -e "${YELLOW}💡 Trying alternative architectures...${NC}"
        
        # Try alternative architectures for the same OS
        case "$ARCH" in
            arm64)
                ALT_ARCH="amd64"
                echo -e "${YELLOW}🔄 Trying $OS/$ALT_ARCH instead...${NC}"
                DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY_NAME}-${OS}-${ALT_ARCH}"
                if [ "$OS" = "windows" ]; then
                    DOWNLOAD_URL="${DOWNLOAD_URL}.exe"
                fi
                if curl -fL -o "$BINARY_NAME.tmp" "$DOWNLOAD_URL"; then
                    echo -e "${GREEN}✅ Download successful (using $ALT_ARCH)${NC}"
                    ARCH="$ALT_ARCH"
                else
                    echo -e "${RED}❌ Alternative download also failed${NC}"
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}❌ No suitable alternative architecture found${NC}"
                exit 1
                ;;
        esac
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -qO "$BINARY_NAME.tmp" "$DOWNLOAD_URL"; then
        echo -e "${GREEN}✅ Download successful${NC}"
    else
        echo -e "${RED}❌ Download failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Neither curl nor wget found${NC}"
    exit 1
fi

# Make executable
chmod +x "$BINARY_NAME.tmp"

# Test the binary
echo -e "${YELLOW}🧪 Testing binary...${NC}"
if ./"$BINARY_NAME.tmp" --version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Binary test successful${NC}"
else
    echo -e "${YELLOW}⚠️  Binary test failed, but continuing...${NC}"
fi

# Move to final location
echo -e "${YELLOW}📦 Installing...${NC}"
mv "$BINARY_NAME.tmp" "$BINARY_NAME"

echo
echo -e "${GREEN}🎉 Installation complete!${NC}"
echo -e "${GREEN}Binary installed as:${NC} $BINARY_NAME"
echo
echo -e "${YELLOW}💡 Usage examples:${NC}"
echo "  ./$BINARY_NAME --version"
echo "  ./$BINARY_NAME --help"
echo "  echo '{\"test\": \"data\"}' | ./$BINARY_NAME"
echo
echo -e "${YELLOW}🚀 To install system-wide, move to /usr/local/bin:${NC}"
echo "  sudo mv $BINARY_NAME /usr/local/bin/"