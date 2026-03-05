#!/usr/bin/env bash
set -euo pipefail

# release-local.sh — Build a signed release locally (for testing updater)
#
# Usage:
#   ./release-local.sh 0.2.1
#
# Prerequisites:
#   - ~/.tauri/construct.key (signing private key)
#   - construct-brain built for current arch
#
# What it does:
#   1. Sets version in tauri.conf.json + Cargo.toml
#   2. Builds brain sidecar
#   3. Builds signed Tauri app
#   4. Generates latest.json for the updater

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONSTRUCT_DIR="$(cd "$SCRIPT_DIR/../construct" && pwd)"
BRAIN_DIR="$(cd "$SCRIPT_DIR/../construct-brain" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ $# -lt 1 ]; then
  echo "Usage: $0 <version>"
  echo "  e.g. $0 0.2.1"
  exit 1
fi

VERSION="$1"

# Check signing key
KEY_PATH="$HOME/.tauri/construct.key"
if [ ! -f "$KEY_PATH" ]; then
  echo -e "${RED}Missing signing key at $KEY_PATH${NC}"
  echo "Generate one with: cargo tauri signer generate -w ~/.tauri/construct.key"
  exit 1
fi

export TAURI_SIGNING_PRIVATE_KEY="$(cat "$KEY_PATH")"
export TAURI_SIGNING_PRIVATE_KEY_PASSWORD="${TAURI_SIGNING_PRIVATE_KEY_PASSWORD:-}"

echo -e "${CYAN}Building Construct Personal v${VERSION}${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  TARGET="aarch64-apple-darwin"
  BRAIN_GOARCH="arm64"
elif [ "$ARCH" = "x86_64" ]; then
  TARGET="x86_64-apple-darwin"
  BRAIN_GOARCH="amd64"
else
  echo -e "${RED}Unsupported architecture: $ARCH${NC}"
  exit 1
fi

# Update version
echo -e "${CYAN}Setting version to ${VERSION}...${NC}"
cd "$CONSTRUCT_DIR"
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"${VERSION}\"/" src-tauri/tauri.conf.json
sed -i '' "s/^version = \"[^\"]*\"/version = \"${VERSION}\"/" src-tauri/Cargo.toml

# Build brain
echo -e "${CYAN}Building brain service...${NC}"
cd "$BRAIN_DIR"
GOOS=darwin GOARCH=$BRAIN_GOARCH go build -o "$CONSTRUCT_DIR/src-tauri/bin/construct-brain-${TARGET}" .

# Build Tauri
echo -e "${CYAN}Building Tauri app (target: $TARGET)...${NC}"
cd "$CONSTRUCT_DIR"
bun run tauri build -- --target "$TARGET"

# Find built artifacts
BUNDLE_DIR="$CONSTRUCT_DIR/src-tauri/target/${TARGET}/release/bundle"
echo ""
echo -e "${GREEN}Build complete!${NC}"
echo "Artifacts:"
find "$BUNDLE_DIR" -type f \( -name "*.dmg" -o -name "*.app.tar.gz" -o -name "*.sig" \) | while read f; do
  echo "  $(basename "$f")"
done

# Generate latest.json
SIG_FILE=$(find "$BUNDLE_DIR" -name "*.app.tar.gz.sig" | head -1)
TAR_FILE=$(find "$BUNDLE_DIR" -name "*.app.tar.gz" | head -1)

if [ -n "$SIG_FILE" ] && [ -n "$TAR_FILE" ]; then
  SIG=$(cat "$SIG_FILE")
  TAR_NAME=$(basename "$TAR_FILE")
  DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  PLATFORM_KEY="darwin-aarch64"
  if [ "$ARCH" = "x86_64" ]; then
    PLATFORM_KEY="darwin-x86_64"
  fi

  cat > "$SCRIPT_DIR/latest.json" << EOF
{
  "version": "${VERSION}",
  "notes": "Construct Personal v${VERSION}",
  "pub_date": "${DATE}",
  "platforms": {
    "${PLATFORM_KEY}": {
      "signature": "${SIG}",
      "url": "https://github.com/construct-space/releases/releases/download/v${VERSION}/${TAR_NAME}"
    }
  }
}
EOF

  echo ""
  echo -e "${GREEN}Generated latest.json${NC}"
  echo "  Upload $TAR_NAME and latest.json to the release"
fi
