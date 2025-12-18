#!/bin/sh

# Script to update all git repositories in ~/Projects and ~/Projects/vincent directories
# For each repository found, it will:
# - Fetch from all remotes and prune deleted branches/tags
# - Run git garbage collection
# - Display current status

# Process a single directory - check if it's a git repo and update it
run_for_dir() {
  dir=$1
  [ -d "$dir" ] || return 0
  (
    cd "$dir" || exit 1
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf '\n=== %s ===\n' "$(pwd)"
      # Fetch all remotes, prune deleted branches/tags
      if ! git fetch --all --prune --tags; then
        printf '[WARN] fetch failed in %s\n' "$(pwd)" >&2
      fi
      if ! git gc; then
        printf '[WARN] git gc failed in %s\n' "$(pwd)" >&2
      fi
      git status --short --branch || printf '[WARN] status failed in %s\n' "$(pwd)" >&2
    else
      printf '[SKIP] Not a git repo: %s\n' "$(pwd)"
    fi
  )
}

# Process all subdirectories in a base directory
process_base() {
  base=$1
  [ -d "$base" ] || { printf '[WARN] Missing %s\n' "$base" >&2; return 0; }
  for dir in "$base"/*/; do
    [ -d "$dir" ] || continue
    # strip trailing slash for nicer printing
    dir=${dir%/}
    run_for_dir "$dir"
  done
}

# Run the script for both project directories
process_base "$HOME/Projects"
process_base "$HOME/Projects/vincent"
