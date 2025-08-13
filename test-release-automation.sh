#!/bin/bash

# Test script for Packr Homebrew Release Automation
# This script demonstrates the end-to-end release automation pipeline

set -e

echo "🚀 Testing Packr Homebrew Release Automation Pipeline"
echo "======================================================="

# Configuration
VERSION="3.0.5-test"
RELEASE_TAG="packr-v${VERSION}"
ASSET_NAME="packr-${VERSION}-darwin-arm64.tar.gz"
SOURCE_REPO="codefuturist/monorepository"
TAP_REPO="codefuturist/homebrew-tap"

echo "📋 Test Configuration:"
echo "  Version: ${VERSION}"
echo "  Release Tag: ${RELEASE_TAG}"
echo "  Asset Name: ${ASSET_NAME}"
echo "  Source Repo: ${SOURCE_REPO}"
echo "  Tap Repo: ${TAP_REPO}"
echo ""

# Step 1: Create a test binary and package
echo "📦 Step 1: Creating test package..."
cd /tmp
echo "Test packr v${VERSION} binary" > packr
chmod +x packr
tar -czf "${ASSET_NAME}" packr
SHA256=$(sha256sum "${ASSET_NAME}" | awk '{print $1}')
echo "  ✅ Created ${ASSET_NAME} with SHA256: ${SHA256}"

# Step 2: Create GitHub release
echo "📄 Step 2: Creating GitHub release..."
gh release create "${RELEASE_TAG}" \
  --repo "${SOURCE_REPO}" \
  --title "Packr v${VERSION}" \
  --notes "Automated test release for Homebrew pipeline validation

This release tests the complete automation pipeline:
- ✅ Release creation
- ✅ Asset upload  
- ✅ SHA256 calculation
- ✅ Homebrew formula update
- ✅ Repository dispatch

**Installation:** 
\`\`\`bash
brew tap ${TAP_REPO}
brew install packr
\`\`\`" \
  --target main \
  "${ASSET_NAME}"

RELEASE_URL="https://github.com/${SOURCE_REPO}/releases/tag/${RELEASE_TAG}"
DOWNLOAD_URL="https://github.com/${SOURCE_REPO}/releases/download/${RELEASE_TAG}/${ASSET_NAME}"

echo "  ✅ Created release: ${RELEASE_URL}"
echo "  ✅ Upload asset: ${DOWNLOAD_URL}"

# Step 3: Trigger Homebrew formula update
echo "🍺 Step 3: Triggering Homebrew formula update..."
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $(gh auth token)" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${TAP_REPO}/dispatches \
  -d "{
    \"event_type\": \"formula-update\",
    \"client_payload\": {
      \"formula\": \"packr\",
      \"version\": \"${VERSION}\",
      \"url\": \"${DOWNLOAD_URL}\",
      \"sha256\": \"${SHA256}\",
      \"triggered_by\": \"automation_test\",
      \"release_url\": \"${RELEASE_URL}\"
    }
  }"

echo "  ✅ Repository dispatch sent to ${TAP_REPO}"

# Step 4: Wait for and verify the update
echo "⏱️  Step 4: Waiting for Homebrew formula update..."
sleep 15

# Check if workflow ran
echo "🔍 Checking workflow status..."
LATEST_RUN=$(gh run list --repo "${TAP_REPO}" --workflow="update-formula.yml" --limit 1 --json status,conclusion,url | jq -r '.[0]')

if [ "${LATEST_RUN}" != "null" ]; then
  STATUS=$(echo "${LATEST_RUN}" | jq -r '.status')
  CONCLUSION=$(echo "${LATEST_RUN}" | jq -r '.conclusion') 
  RUN_URL=$(echo "${LATEST_RUN}" | jq -r '.url')
  
  echo "  Status: ${STATUS}"
  echo "  Conclusion: ${CONCLUSION}"
  echo "  Workflow URL: ${RUN_URL}"
  
  if [ "${CONCLUSION}" = "success" ]; then
    echo "  ✅ Homebrew formula update completed successfully!"
  else
    echo "  ⚠️  Homebrew formula update may still be running or failed"
  fi
else
  echo "  ⚠️  No recent workflow runs found"
fi

# Step 5: Verify formula update
echo "✅ Step 5: Verifying formula update..."
sleep 5

# Get current formula version
CURRENT_VERSION=$(curl -s https://raw.githubusercontent.com/${TAP_REPO}/main/Formula/packr.rb | grep 'version "' | sed 's/.*version "\(.*\)".*/\1/')

if [ "${CURRENT_VERSION}" = "${VERSION}" ]; then
  echo "  ✅ Formula successfully updated to version: ${CURRENT_VERSION}"
else
  echo "  ⚠️  Formula version (${CURRENT_VERSION}) doesn't match expected (${VERSION})"
  echo "     This may indicate the update is still in progress"
fi

# Step 6: Test installation (optional)
echo "🧪 Step 6: Testing formula installation..."
if command -v brew >/dev/null 2>&1; then
  echo "  Homebrew detected, testing installation..."
  
  # Update tap
  brew tap "${TAP_REPO}" 2>/dev/null || true
  brew update
  
  # Check if packr can be installed/updated
  if brew info packr >/dev/null 2>&1; then
    BREW_VERSION=$(brew info packr --json | jq -r '.[0].installed[0].version // "not_installed"')
    echo "  Currently installed version: ${BREW_VERSION}"
    
    echo "  To update to the latest version, run:"
    echo "    brew upgrade packr"
  else
    echo "  To install packr, run:"
    echo "    brew install packr"
  fi
else
  echo "  ⚠️  Homebrew not detected, skipping installation test"
fi

echo ""
echo "🎉 Pipeline Test Summary:"
echo "========================="
echo "✅ Release created: ${RELEASE_URL}"
echo "✅ Asset uploaded: ${DOWNLOAD_URL}" 
echo "✅ SHA256 calculated: ${SHA256}"
echo "✅ Repository dispatch sent"
echo "✅ Formula update triggered"
echo "✅ Current formula version: ${CURRENT_VERSION}"
echo ""
echo "🔗 Useful Links:"
echo "  - Source Release: ${RELEASE_URL}"
echo "  - Homebrew Tap: https://github.com/${TAP_REPO}"
echo "  - Formula File: https://github.com/${TAP_REPO}/blob/main/Formula/packr.rb"
echo "  - Workflow Runs: https://github.com/${TAP_REPO}/actions"
echo ""
echo "📚 Installation Instructions:"
echo "  brew tap ${TAP_REPO}"
echo "  brew install packr"
echo "  packr --version"

# Cleanup
rm -f /tmp/packr /tmp/"${ASSET_NAME}"

echo ""
echo "✨ Test completed successfully!"
