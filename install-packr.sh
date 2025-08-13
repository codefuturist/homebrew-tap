#!/bin/bash
# Install script for Packr from private GitHub repository
# This script uses GitHub CLI to download from private repos

set -e

VERSION="${1:-3.0.0}"
REPO="codefuturist/monorepository"
INSTALL_DIR="/opt/homebrew/bin"

echo "Installing Packr v${VERSION}..."

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is required but not installed."
    echo "Install with: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI."
    echo "Run: gh auth login"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download release
echo "Downloading from GitHub..."
gh release download "packr-v${VERSION}" \
    --repo "$REPO" \
    --pattern "packr-*.tar.gz" \
    --pattern "*.sha256" 2>/dev/null || {
    echo "Error: Failed to download release packr-v${VERSION}"
    echo "Available releases:"
    gh release list --repo "$REPO" --limit 5
    rm -rf "$TEMP_DIR"
    exit 1
}

# Verify checksum
if [ -f "packr-${VERSION}-darwin-arm64.tar.gz.sha256" ]; then
    echo "Verifying checksum..."
    shasum -a 256 -c "packr-${VERSION}-darwin-arm64.tar.gz.sha256" || {
        echo "Error: Checksum verification failed!"
        rm -rf "$TEMP_DIR"
        exit 1
    }
fi

# Extract
echo "Extracting..."
tar -xzf "packr-${VERSION}-darwin-arm64.tar.gz"

# Install
echo "Installing to ${INSTALL_DIR}..."
if [ -w "$INSTALL_DIR" ]; then
    cp packr "$INSTALL_DIR/"
else
    echo "Need sudo to install to ${INSTALL_DIR}"
    sudo cp packr "$INSTALL_DIR/"
fi

# Make executable
chmod +x "${INSTALL_DIR}/packr"

# Create config directory
CONFIG_DIR="$HOME/.config/packr"
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Creating config directory..."
    mkdir -p "$CONFIG_DIR"
fi

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ Packr v${VERSION} installed successfully!"
echo ""
echo "To get started:"
echo "  1. Create a configuration file at ~/.config/packr/packages.yaml"
echo "  2. Run: packr --help"
echo ""
echo "Version check:"
packr --version
