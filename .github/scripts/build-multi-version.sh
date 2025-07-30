done
declare -A BUILT_VERSIONS
done
done

#!/usr/bin/env bash
set -euox pipefail

# Multi-Version Build Script for OCM Website
# Usage: ./github/scripts/build-multi-version.sh
# Requirements: git, hugo, npm, jq, cmp
#
# This script builds all website versions in parallel using git worktrees.
# For performance, it reuses the central node_modules folder via symlink if the package-lock.json is identical.
# If dependencies differ, node_modules is installed separately in the worktree.

# Helper for error output
err() { echo "[ERROR] $*" >&2; }
# Helper for info output
info() { echo "[INFO] $*"; }

# Check required commands
for cmd in git hugo npm jq cmp; do
  if ! command -v "$cmd" &>/dev/null; then
    err "$cmd is required but not installed."
    exit 1
  fi
done

# Read all versions from data/versions.json
VERSIONS=$(jq -r '.versions[]' data/versions.json)
if [ -z "$VERSIONS" ]; then
  err "No versions found in data/versions.json."
  exit 1
fi

# Read default version from config/_default/params.toml
DEFAULT_VERSION=$(grep -E '^[[:space:]]*defaultVersion' config/_default/params.toml | cut -d'=' -f2 | tr -d ' "')
if [ -z "$DEFAULT_VERSION" ]; then
  err "defaultVersion not found in config/_default/params.toml."
  exit 1
fi

# Prepare output and worktree directories
PUBLIC_DIR="public"
rm -rf "$PUBLIC_DIR"
mkdir -p "$PUBLIC_DIR"

WORKTREE_BASE=".worktrees"
rm -rf "$WORKTREE_BASE"
mkdir -p "$WORKTREE_BASE"

# Build each version
# BUILT_VERSIONS will hold the mapping: version -> output directory
declare -A BUILT_VERSIONS
for VERSION in $VERSIONS; do
  # Determine branch and output directory for each version
  if [ "$VERSION" = "dev" ]; then
    BRANCH="main"
    OUTDIR="$PUBLIC_DIR/dev"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    # If main is already checked out, build directly in main working directory
    if [ "$CURRENT_BRANCH" = "main" ]; then
      info "Building dev version directly from main working directory"
      hugo mod get -u || { err "hugo mod get -u failed for main"; exit 1; }
      hugo mod tidy || { err "hugo mod tidy failed for main"; exit 1; }
      npm ci || { err "npm ci failed for main"; exit 1; }
      npm run build -- --destination "$OUTDIR" --baseURL "https://ocm.software/dev" || { err "npm run build failed for main"; exit 1; }
      BUILT_VERSIONS["$VERSION"]="$OUTDIR"
      continue
    fi
  elif [ "$VERSION" = "$DEFAULT_VERSION" ]; then
    BRANCH="website/$VERSION"
    OUTDIR="$PUBLIC_DIR"
  else
    BRANCH="website/$VERSION"
    OUTDIR="$PUBLIC_DIR/$VERSION"
  fi

  info "Building version $VERSION from branch $BRANCH into $OUTDIR"

  # Create a git worktree for the branch
  git worktree add "$WORKTREE_BASE/$VERSION" "$BRANCH" || { err "Failed to add worktree for $BRANCH"; exit 1; }
  pushd "$WORKTREE_BASE/$VERSION" >/dev/null

  # Update Hugo modules for the branch
  hugo mod get -u || { err "hugo mod get -u failed for $BRANCH"; popd >/dev/null; exit 1; }
  hugo mod tidy || { err "hugo mod tidy failed for $BRANCH"; popd >/dev/null; exit 1; }

  # Optimization: reuse central node_modules if package-lock.json is identical
  # This saves time and disk space for identical dependencies across versions
  if cmp -s package-lock.json ../../package-lock.json; then
    info "package-lock.json is identical, creating symlink to central node_modules."
    ln -s ../../node_modules ./node_modules
  else
    info "package-lock.json differs, running npm ci in worktree."
    npm ci || { err "npm ci failed for $BRANCH"; popd >/dev/null; exit 1; }
  fi

  # Build the site for this version
  npm run build -- --destination "../../$OUTDIR" --baseURL "https://ocm.software/$VERSION" || { err "npm run build failed for $BRANCH"; popd >/dev/null; exit 1; }
  BUILT_VERSIONS["$VERSION"]="$OUTDIR"

  popd >/dev/null
  git worktree remove "$WORKTREE_BASE/$VERSION" --force
done

# Summary: print all built versions and their output directories
info "Multi-version build completed. Output in $PUBLIC_DIR."
echo "--- Build Summary ---"
for VERSION in "${!BUILT_VERSIONS[@]}"; do
  printf "Version: %-10s → %s\n" "$VERSION" "${BUILT_VERSIONS[$VERSION]}"
done
