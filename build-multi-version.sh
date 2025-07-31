#!/usr/bin/env bash
set -euox pipefail

# -----------------------------------------------------------------------------
# Multi-Version Build Script for OCM Website
# -----------------------------------------------------------------------------
# Builds all website versions in parallel using git worktrees.
# For performance, it reuses the central node_modules folder via symlink if the
# package-lock.json is identical. If dependencies differ, node_modules is installed
# separately in the worktree.
#
# USAGE:
#   bash .github/scripts/build-multi-version.sh [baseURL]
#
#   baseURL: Optional. The base URL for the built site versions. Default is
#            "https://ocm.software". For local testing, you can use e.g.
#            "http://localhost:1313".
#
# EXAMPLES:
#   bash .github/scripts/build-multi-version.sh
#   bash .github/scripts/build-multi-version.sh http://localhost:1313
# -----------------------------------------------------------------------------

# Read baseURL from first argument, default to https://ocm.software
BASE_URL="${1:-https://ocm.software}"

# Helper for error output
err() { echo "[ERROR] $*" >&2; }
# Helper for info output
info() { echo "[INFO] $*"; }

# Check required commands
for cmd in git npm jq cmp; do
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

git worktree prune  # Clean up any stale worktrees

# Build each version
# BUILT_VERSIONS will hold the mapping: version -> output directory
declare -A BUILT_VERSIONS
for VERSION in $VERSIONS; do

  # Always set current branch for info/debug output
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

  # Determine output directory for each version
  if [ "$VERSION" = "dev" ]; then
    OUTDIR="$PUBLIC_DIR/dev"
    UPSTREAM_BRANCH="main"
  elif [ "$VERSION" = "$DEFAULT_VERSION" ]; then
    OUTDIR="$PUBLIC_DIR"
    UPSTREAM_BRANCH="website/$VERSION"
  else
    OUTDIR="$PUBLIC_DIR/$VERSION"
    UPSTREAM_BRANCH="website/$VERSION"
  fi

  # Read docsVersion from current branch (only exact key)
  CURRENT_DOCSVERSION=$(grep -E '^[[:space:]]*docsVersion[[:space:]]*=' config/_default/params.toml | cut -d'=' -f2 | tr -d ' "')

  if [ "$VERSION" = "$CURRENT_DOCSVERSION" ]; then
    # Build this version from current branch (no worktree)
    info "Building $VERSION version directly from current branch ($CURRENT_BRANCH) into $OUTDIR"
    hugo mod get -u || { err "hugo mod get -u failed for $CURRENT_BRANCH"; exit 1; }
    hugo mod tidy || { err "hugo mod tidy failed for $CURRENT_BRANCH"; exit 1; }
    npm ci || { err "npm ci failed for $CURRENT_BRANCH"; exit 1; }
    npm run build -- --destination "$OUTDIR" --baseURL "$BASE_URL/$VERSION" || { err "npm run build failed for $CURRENT_BRANCH"; exit 1; }
    BUILT_VERSIONS["$VERSION"]="$OUTDIR"
    continue
  else
    BRANCH="$UPSTREAM_BRANCH"
  fi

  info "Building version $VERSION from branch $BRANCH into $OUTDIR"

  # Create a git worktree for the branch
  git worktree add "$WORKTREE_BASE/$VERSION" "$BRANCH" || { err "Failed to add worktree for $BRANCH"; exit 1; }
  pushd "$WORKTREE_BASE/$VERSION" >/dev/null

  # Copy the latest data/versions.json from main into the worktree (for version switcher)
  if [ "$VERSION" != "dev" ]; then
    cp ../../data/versions.json data/versions.json
    info "Copied latest data/versions.json into worktree for $VERSION."
  fi

  # Optimization: reuse central node_modules if package-lock.json is identical
  # This saves time and disk space for identical dependencies across versions
  if cmp -s package-lock.json ../../package-lock.json; then
    info "package-lock.json is identical, creating symlink to central node_modules."
    ln -s ../../node_modules ./node_modules
  else
    info "package-lock.json differs from central version. Installing separate dependencies for this version."
    npm ci || { err "npm ci failed for $BRANCH"; popd >/dev/null; exit 1; }
  fi

  # Update Hugo modules for the branch
  npm run hugo --  mod get -u || { err "hugo mod get -u failed for $BRANCH"; popd >/dev/null; exit 1; }
  npm run hugo --  mod tidy || { err "hugo mod tidy failed for $BRANCH"; popd >/dev/null; exit 1; }

  # Build the site for this version
  if [ "$VERSION" = "$DEFAULT_VERSION" ]; then
    npm run build -- --destination "../../$OUTDIR" --baseURL "$BASE_URL" || { err "npm run build failed for $BRANCH"; popd >/dev/null; exit 1; }
  else
    npm run build -- --destination "../../$OUTDIR" --baseURL "$BASE_URL/$VERSION" || { err "npm run build failed for $BRANCH"; popd >/dev/null; exit 1; }
  fi
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
