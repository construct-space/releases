#!/usr/bin/env bash
# Usage: ./release.sh [version] [channel] [branch]
#
# Examples:
#   ./release.sh                    # auto-bump patch, stable, from main
#   ./release.sh 0.7.0              # explicit version, stable
#   ./release.sh 0.7.0-beta.1 beta  # beta release from beta branch
#   ./release.sh 0.7.0 stable dev   # stable from dev branch (testing)
set -e

REPO="construct-space/releases"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../construct-app" && pwd)"
CHANNEL="${2:-stable}"
BRANCH="${3:-main}"

# Auto-set branch for beta channel
if [ "$CHANNEL" = "beta" ] && [ "$BRANCH" = "main" ]; then
  BRANCH="beta"
fi

# Determine version — git tags are the source of truth
if [ -n "$1" ]; then
  VERSION="$1"
else
  LATEST=$(gh release list --repo "$REPO" --limit 1 --json tagName -q '.[0].tagName' 2>/dev/null || echo "")
  LATEST="${LATEST#v}"
  if [ -z "$LATEST" ]; then
    echo "No existing release. Usage: ./release.sh 0.1.0"
    exit 1
  fi
  IFS='.' read -r MAJOR MINOR PATCH <<< "${LATEST%%-*}"
  PATCH=$((PATCH + 1))
  VERSION="${MAJOR}.${MINOR}.${PATCH}"
  echo "Latest: v${LATEST} → Bumping to: v${VERSION}"
  read -p "Continue? [Y/n] " confirm
  [[ "$confirm" =~ ^[Nn] ]] && exit 0
fi

echo ""
echo "==> Release v${VERSION} (${CHANNEL}) from ${BRANCH}"
echo ""

# Bump version in construct-app monorepo
echo "==> Bumping construct-app to v${VERSION}"
cd "$APP_DIR"

# package.json
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"${VERSION}\"/" package.json

# tauri.conf.json
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"${VERSION}\"/" desktop/tauri.conf.json

# Cargo.toml (line 3)
sed -i '' "3s/version = \"[^\"]*\"/version = \"${VERSION}\"/" desktop/Cargo.toml

# Operator version
sed -i '' "s/const Version = \"[^\"]*\"/const Version = \"${VERSION}\"/" operator/main.go

git add package.json desktop/tauri.conf.json desktop/Cargo.toml operator/main.go
git commit -m "Release ${VERSION}" 2>/dev/null || echo "  (no changes)"
git push origin "$BRANCH"
cd - > /dev/null

# Trigger CI
echo ""
echo "==> Triggering CI release v${VERSION} (${CHANNEL}) from ${BRANCH}"
gh workflow run release.yml --repo "$REPO" \
  -f version="$VERSION" \
  -f branch="$BRANCH" \
  -f channel="$CHANNEL"

echo ""
echo "==> Release v${VERSION} triggered"
echo "  Channel: ${CHANNEL}"
echo "  Branch:  ${BRANCH}"
echo "  Watch:   https://github.com/construct-space/releases/actions"
