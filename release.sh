#!/usr/bin/env bash
# Usage: ./release.sh [version] [branch]
# If no version given, auto-bumps patch from latest GitHub release tag.
# Bumps operator + construct to the same version, commits, pushes, triggers CI.
# Examples:
#   ./release.sh              # auto-bump: 0.6.0 → 0.6.1
#   ./release.sh 0.7.0        # explicit version (minor/major)
#   ./release.sh 0.7.0 dev    # explicit version + CI branch
set -e

REPO="construct-space/releases"
BRANCH="${2:-main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATOR_DIR="$(cd "$SCRIPT_DIR/../construct-operator" && pwd)"
CONSTRUCT_DIR="$(cd "$SCRIPT_DIR/../construct" && pwd)"

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
  IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST"
  PATCH=$((PATCH + 1))
  VERSION="${MAJOR}.${MINOR}.${PATCH}"
  echo "Latest: v${LATEST} → Bumping to: v${VERSION}"
  read -p "Continue? [Y/n] " confirm
  [[ "$confirm" =~ ^[Nn] ]] && exit 0
fi

echo ""

# 1. Bump operator
echo "==> Operator v${VERSION}"
sed -i '' "s/const Version = \"[^\"]*\"/const Version = \"${VERSION}\"/" "$OPERATOR_DIR/cmd/operator/main.go"
cd "$OPERATOR_DIR"
git add cmd/operator/main.go
git commit -m "Release ${VERSION}" 2>/dev/null || echo "  (no changes)"
git push
cd - > /dev/null

# 2. Bump construct (package.json, tauri.conf.json, Cargo.toml)
echo "==> Construct v${VERSION}"
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"${VERSION}\"/" "$CONSTRUCT_DIR/package.json"
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"${VERSION}\"/" "$CONSTRUCT_DIR/src-tauri/tauri.conf.json"
sed -i '' "3s/version = \"[^\"]*\"/version = \"${VERSION}\"/" "$CONSTRUCT_DIR/src-tauri/Cargo.toml"
cd "$CONSTRUCT_DIR"
git add package.json src-tauri/tauri.conf.json src-tauri/Cargo.toml
git commit -m "Release ${VERSION}" 2>/dev/null || echo "  (no changes)"
git push
cd - > /dev/null

# 3. Trigger CI
echo ""
echo "==> Triggering release v${VERSION} from ${BRANCH}"
gh workflow run release.yml --repo "$REPO" -f version="$VERSION" -f branch="$BRANCH"
echo "Watch: https://github.com/construct-space/releases/actions"
