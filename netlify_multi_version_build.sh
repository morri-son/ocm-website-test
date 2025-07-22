#!/opt/homebrew/bin/bash
  set -eo pipefail  # Exit on error or pipe failure (debug: allow unset variables)
  echo "DEBUG: Bash version: $BASH_VERSION"
  echo "DEBUG: Script started as: $0"
  echo "DEBUG: Current user: $(whoami)"
  echo "DEBUG: Current directory: $(pwd)"

  # Cleanup all existing git worktrees at script start
  echo "🧹 Cleaning up existing git worktrees at script start..."
  existing_worktrees=$(git worktree list --porcelain | awk '/^worktree /{print $2}')
  for wt in $existing_worktrees; do
    if [ "$wt" != "." ]; then
      echo "  Removing worktree: $wt"
      git worktree remove --force "$wt" || echo "  WARN: Could not remove $wt"
    fi
  done
  echo "DEBUG: Initial worktree cleanup done."

  MAX_VERSIONS=5  # Maximum number of versions to build

  # Check for associative array support
  if ! declare -A test_assoc 2>/dev/null; then
    echo "ERROR: Bash associative arrays not supported. Use bash >= 4." >&2
    exit 1
  fi
  echo "DEBUG: Associative arrays supported."
  cd /Users/D032990/github/github.com/morri-son/ocm-website-test
  echo "DEBUG: Changed to repo dir: $(pwd)"

  # Create main public directory
  mkdir -p public
  echo "DEBUG: Created public dir."

  # Fetch all branches and tags (full history for worktree support)
  git fetch --all --tags
  echo "DEBUG: Ran git fetch."

  echo "🔍 Determining versions to build (max: $MAX_VERSIONS)..."

  # Priority branches: always include
  declare -A priority_refs
  echo "DEBUG: Declared priority_refs as associative array."
  if git show-ref --verify --quiet refs/remotes/origin/main; then
    echo "DEBUG: Found origin/main"
    priority_refs["main"]=""
  else
    echo "DEBUG: origin/main not found"
  fi
  if git show-ref --verify --quiet refs/remotes/origin/legacy; then
    echo "DEBUG: Found origin/legacy"
    priority_refs["legacy"]="legacy"
  else
    echo "DEBUG: origin/legacy not found"
  fi

  # Collect release branches: vX.Y(.Z) as a simple list
  echo "DEBUG: Collecting release branches..."
  release_branches=($(git branch -r | grep -E "origin/v[0-9]+(\.[0-9]+)+$" | sed 's|origin/||' | sort -V -r))
  echo "DEBUG: release_branches: '${release_branches[@]}'"

  # Combine final selection robustly
  declare -A selected_versions
  echo "DEBUG: Declared selected_versions as associative array."
  # Add priority branches
  echo "DEBUG: priority_refs keys: '${!priority_refs[@]}'"
  echo "DEBUG: priority_refs values: '${priority_refs[@]}'"
  for ref in "${!priority_refs[@]}"; do
    echo "DEBUG: Looping priority_refs, ref='$ref'"
    if [ -n "$ref" ]; then
      echo "DEBUG: Adding priority branch '$ref' with value '${priority_refs[$ref]}' to selected_versions"
      selected_versions["$ref"]="${priority_refs[$ref]}"
      echo "DEBUG: selected_versions['$ref']='${selected_versions[$ref]}' (after priority add)"
    else
      echo "DEBUG: Skipping empty ref in priority_refs"
    fi
  done

  priority_count=${#priority_refs[@]}
  remaining_slots=$((MAX_VERSIONS - priority_count))

  echo "✅ Priority: ${!priority_refs[@]}"
  echo "➕ Slots for release branches: $remaining_slots"

  # Add release branches if available
  echo "DEBUG: remaining_slots=$remaining_slots"
  echo "DEBUG: release_branches length=${#release_branches[@]}"
  if [ $remaining_slots -gt 0 ] && [ ${#release_branches[@]} -gt 0 ]; then
    count=0
    echo "DEBUG: Entering release_branches loop"
    for ref in "${release_branches[@]}"; do
      echo "DEBUG: Looping release branch '$ref' (count=$count)"
      if [ $count -ge $remaining_slots ]; then echo "DEBUG: count ($count) >= remaining_slots ($remaining_slots), break"; break; fi
      selected_versions["$ref"]="$ref"
      echo "DEBUG: selected_versions['$ref']='${selected_versions[$ref]}' (after release add)"
      count=$((count+1))
    done
    echo "DEBUG: Finished release_branches loop"
  else
    echo "DEBUG: Skipping release_branches loop (remaining_slots=$remaining_slots, release_branches count=${#release_branches[@]})"
  fi
  echo "MARKER: After release_branches loop"
  echo "DEBUG: selected_versions keys after filling: '${!selected_versions[@]}'"
  echo "DEBUG: selected_versions values after filling: '${selected_versions[@]}'"

  echo ""
  echo "📦 Final versions to build (${#selected_versions[@]}):"
  echo "DEBUG: selected_versions keys: '${!selected_versions[@]}'"
  for ref in "${!selected_versions[@]}"; do
    echo "DEBUG: Iterating selected_versions, current ref='$ref'"
    if [ -z "$ref" ]; then
      echo "WARN: Empty branch name in selected_versions, skipping!"
      continue
    fi
    target="${selected_versions[$ref]}"
    if [ -z "$target" ]; then target="(root)"; fi
    echo "  $ref -> public/$target"
  done
  echo ""


  # --- Neue Worktree- und Build-Logik mit PR-Branch-Mapping ---
  set -x  # Debug: Zeige alle ausgeführten Befehle
  declare -a worktree_dirs

  # Zielversion aus params.toml extrahieren (docsVersion)
  DOCS_VERSION=$(grep '^docsVersion' config/_default/params.toml | sed -E "s/.*= *\"([^"]+)\".*/\1/")
  echo "DEBUG: docsVersion from params.toml: $DOCS_VERSION"

  # PR-Branch-Name ermitteln (Netlify/GitHub-Umgebung)
  PR_BRANCH=""
  if [ -n "$GITHUB_HEAD_REF" ]; then
    PR_BRANCH="$GITHUB_HEAD_REF"
  elif [ "$CONTEXT" = "deploy-preview" ] && [ -n "$HEAD" ]; then
    PR_BRANCH="$HEAD"
  else
    # Fallback: aktueller Branch
    PR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  fi
  echo "DEBUG: PR_BRANCH: $PR_BRANCH"

  for ref in "${!selected_versions[@]}"; do
    if [ -z "$ref" ]; then
      echo "WARN: Empty branch name in selected_versions, skipping!"
      continue
    fi
    version="${selected_versions[$ref]}"
    worktree_dir="worktree-$ref"

    # Für die Zielversion (docsVersion) den PR-Branch als Worktree verwenden
    if [ "$ref" = "$DOCS_VERSION" ] && [ -n "$PR_BRANCH" ]; then
      echo "🔄 Setting up worktree for PR branch ($PR_BRANCH) as $ref -> ${version:-(root)}"
      git worktree add -f "$worktree_dir" "$PR_BRANCH" || { echo "❌ Error during worktree checkout for PR branch $PR_BRANCH" >&2; exit 1; }
    else
      echo "🔄 Setting up worktree for $ref -> ${version:-(root)}"
      git worktree add "$worktree_dir" "origin/$ref" || { echo "❌ Error during worktree checkout for $ref" >&2; exit 1; }
    fi
    worktree_dirs+=("$worktree_dir")

    cd "$worktree_dir"
    echo "DEBUG: Changed to worktree dir: $(pwd)"
    echo "📦 Installing dependencies for $ref..."
    npm ci --prefer-offline --no-audit
    echo "DEBUG: npm ci finished for $ref"
    if [ -z "$version" ]; then
      dest_dir="../public"
      base_url="https://ocm.software/"
    else
      dest_dir="../public/$version"
      base_url="https://ocm.software/$version/"
    fi
    echo "DEBUG: dest_dir='$dest_dir', base_url='$base_url'"
    mkdir -p "$dest_dir"
    echo "DEBUG: Created dest_dir $dest_dir"
    if [ "$ref" != "legacy" ]; then
      echo "📥 Getting Hugo modules for $ref..."
      npm run mod:get "github.com/morri-son/open-component-model-test@$ref"
      echo "DEBUG: npm run mod:get finished for $ref"
    fi
    echo "🏗️  Building $ref with Hugo..."
    npm run build -- --destination "$dest_dir" --baseURL "$base_url"
    echo "DEBUG: npm run build finished for $ref"
    echo "✅ Built $ref -> $dest_dir"
    cd ..
    echo "DEBUG: Returned to main workspace: $(pwd)"
    echo ""
  done
  echo "DEBUG: Finished selected_versions worktree loop"

  # Cleanup worktrees
  echo "🧹 Cleaning up worktrees..."
  for worktree_dir in "${worktree_dirs[@]}"; do
    echo "  Removing $worktree_dir"
    git worktree remove "$worktree_dir" --force
  done

  echo "🎉 All ${#selected_versions[@]} versions built successfully!"
