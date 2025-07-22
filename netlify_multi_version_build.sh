#!/usr/bin/env bash
set -eo pipefail  # Exit on error or pipe failure (debug: allow unset variables)

#!/usr/bin/env bash
set -eo pipefail  # Exit on error or pipe failure (debug: allow unset variables)

# Cleanup all existing git worktrees at script start
echo "🧹 Cleaning up all existing git worktrees at script start..."
existing_worktrees=$(git worktree list --porcelain | awk '/^worktree /{print $2}')
for wt in $existing_worktrees; do
  if [ "$wt" != "." ]; then
    echo "  Removing worktree: $wt"
    git worktree remove --force "$wt" || echo "  WARN: Could not remove $wt"
  fi
done
echo "Initial worktree cleanup done."

# Create the main public directory
mkdir -p public

# Fetch all branches and tags (full history for worktree support)
git fetch --all --tags

# Read all versions from versions.json
versions_json_file="data/versions.json"
site_versions=($(jq -r '.versions[]' "$versions_json_file"))

# Read defaultVersion and docsVersion from params.toml
# docsVersion determines which worktree to replace with the PR branch
# defaultVersion determines which version is built to the root public/
docsVersion=$(grep -E '^\s*docsVersion\s*=' config/_default/params.toml | head -n1 | cut -d'=' -f2 | tr -d ' "')
defaultVersion=$(grep -E '^\s*defaultVersion\s*=' config/_default/params.toml | head -n1 | cut -d'=' -f2 | tr -d ' "')

# Detect PR preview context
IS_PR_PREVIEW=false
if [ -n "$GITHUB_HEAD_REF" ] || { [ "$CONTEXT" = "deploy-preview" ] && [ -n "$HEAD" ]; }; then
  IS_PR_PREVIEW=true
fi
PR_BRANCH=""
if [ -n "$GITHUB_HEAD_REF" ]; then
  PR_BRANCH="$GITHUB_HEAD_REF"
elif [ "$CONTEXT" = "deploy-preview" ] && [ -n "$HEAD" ]; then
  PR_BRANCH="$HEAD"
else
  PR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
fi

echo "\n📦 Starting multi-version build for: ${site_versions[*]}"
echo "  defaultVersion: $defaultVersion (will be built to root public/)"
echo "  docsVersion: $docsVersion (PR preview: $IS_PR_PREVIEW, PR branch: $PR_BRANCH)\n"

# Worktree and build logic with PR-branch mapping
declare -a worktree_dirs

# Main, minimal build loop
declare -a build_summaries
for site_version in "${site_versions[@]}"; do
  if [ -z "$site_version" ]; then
    echo "WARN: Empty site_version, skipping."
    continue
  fi
  # Mapping: site version "dev" → branch "main", all others identical
  if [ "$site_version" = "dev" ]; then
    ref="main"
  else
    ref="$site_version"
  fi
  worktree_dir="worktree-$site_version"

  # PR preview: docsVersion → PR_BRANCH, else origin/ref
  if [ "$site_version" = "$docsVersion" ] && [ -n "$PR_BRANCH" ] && $IS_PR_PREVIEW; then
    echo "\n🔄 Building version '$site_version': PR branch '$PR_BRANCH' replaces ref '$ref' (docsVersion, PR preview)"
    git worktree add -f "$worktree_dir" "$PR_BRANCH" || { echo "❌ Error during worktree checkout for PR branch $PR_BRANCH (site_version: $site_version)" >&2; exit 1; }
  else
    echo "\n🔄 Building version '$site_version': ref 'origin/$ref'"
    git worktree add "$worktree_dir" "origin/$ref" || { echo "❌ Error during worktree checkout for $ref (site_version: $site_version)" >&2; exit 1; }
  fi
  worktree_dirs+=("$worktree_dir")

  cd "$worktree_dir"
  echo "📦 Installing npm dependencies for $ref ..."
  npm ci --prefer-offline --no-audit


  # Output: defaultVersion → public/, else public/<site_version>
  # in case of PR preview use deploy preview URL as baseURL
  if [ "$site_version" = "$defaultVersion" ]; then
    dest_dir="../public"
    if [ -n "$DEPLOY_PRIME_URL" ]; then
      base_url="$DEPLOY_PRIME_URL/"
    else
      base_url="https://ocm.software/"
    fi
  else
    dest_dir="../public/$site_version"
    if [ -n "$DEPLOY_PRIME_URL" ]; then
      base_url="$DEPLOY_PRIME_URL/$site_version/"
    else
      base_url="https://ocm.software/$site_version/"
    fi
  fi
  mkdir -p "$dest_dir"

  if [ "$ref" != "legacy" ]; then
    echo "📥 Getting Hugo modules for $ref ..."
    npm run mod:get "github.com/morri-son/open-component-model-test@$ref"
  fi

  echo "🏗️  Building Hugo site for $ref → $dest_dir ..."
  npm run build -- --destination "$dest_dir" --baseURL "$base_url"
  echo "✅ Done: $site_version → $dest_dir"
  build_summaries+=("$site_version → $dest_dir")
  cd ..
done

# Cleanup worktrees
echo "🧹 Cleaning up worktrees..."
for worktree_dir in "${worktree_dirs[@]}"; do
  echo "  Removing $worktree_dir"
  git worktree remove "$worktree_dir" --force
done

echo "\nBuild summary:"
for summary in "${build_summaries[@]}"; do
  echo "$summary"
done
echo "\n🎉 All versions built successfully!"