#!/usr/bin/env bash
# Quick trigger: ./release.sh 0.2.1 [branch]
VERSION="${1:-0.2.1}"
BRANCH="${2:-main}"
gh workflow run release.yml --repo construct-space/releases -f version="$VERSION" -f branch="$BRANCH"
echo "Triggered v${VERSION} from ${BRANCH}"
echo "Watch: https://github.com/construct-space/releases/actions"
