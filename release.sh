#!/usr/bin/env bash
# Usage: ./release.sh [version] [branch]
# If no version given, auto-bumps patch from latest GitHub release.
# Examples:
#   ./release.sh              # auto-bump: 0.3.0 → 0.3.1
#   ./release.sh 0.4.0        # explicit version
#   ./release.sh 0.4.0 dev    # explicit version + branch
set -e

REPO="construct-space/releases"
BRANCH="${2:-main}"
CONSTRUCT_DIR="$(cd "$(dirname "$0")/../construct" && pwd)"

if [ -n "$1" ]; then
  VERSION="$1"
else
  # Fetch latest release tag and auto-bump patch
  LATEST=$(gh release view --repo "$REPO" --json tagName -q '.tagName' 2>/dev/null || echo "")
  LATEST="${LATEST#v}"  # strip leading v

  if [ -z "$LATEST" ]; then
    echo "No existing release found. Please provide a version: ./release.sh 0.1.0"
    exit 1
  fi

  # Split into major.minor.patch and bump patch
  IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST"
  PATCH=$((PATCH + 1))
  VERSION="${MAJOR}.${MINOR}.${PATCH}"

  echo "Latest release: v${LATEST}"
  echo "Bumping to:     v${VERSION}"
  echo ""
  read -p "Continue? [Y/n] " confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# Sync version to all files in the construct repo
echo "==> Syncing version to construct repo"
"$CONSTRUCT_DIR/scripts/sync-version.sh" "$VERSION"

# Commit version bump if there are changes
cd "$CONSTRUCT_DIR"
if [ -n "$(git status --porcelain .version package.json src-tauri/tauri.conf.json src-tauri/Cargo.toml)" ]; then
  git add .version package.json src-tauri/tauri.conf.json src-tauri/Cargo.toml
  git commit -m "Bump version to $VERSION"
  git push
  echo "  ✓ Version bump committed and pushed"
else
  echo "  ✓ Version already at $VERSION"
fi
cd -

# Trigger CI release
gh workflow run release.yml --repo "$REPO" -f version="$VERSION" -f branch="$BRANCH"
echo ""
echo "Triggered v${VERSION} from ${BRANCH}"
echo "Watch: https://github.com/construct-space/releases/actions"
