#!/usr/bin/env bash

set -euo pipefail

ORG="Islandora"
WORKDIR=$(pwd | xargs dirname)
REPOS=$(gh repo list "$ORG" --limit 1000 --json name -q '.[].name')

for REPO in $REPOS; do
  if [ "$REPO" = ".github" ]; then
    echo "skipping .github repo"
    continue
  fi

  if [ ! -d "$WORKDIR/$REPO" ]; then
    gh repo clone "$ORG/$REPO" "$WORKDIR/$REPO"
  fi

  pushd "$WORKDIR/$REPO"

  DEFAULT_BRANCH=$(gh repo view "$ORG/$REPO" --json defaultBranchRef -q '.defaultBranchRef.name')
  git checkout "$DEFAULT_BRANCH"
  git pull origin "$DEFAULT_BRANCH"


  if ! ls ./*.info > /dev/null 2>&1; then
    echo "No .info files found in $REPO, skipping"
    popd > /dev/null
    continue
  fi
  
  echo "Found .info file(s) in $REPO, archiving repository..."
  
  # Check if repo is already archived
  IS_ARCHIVED=$(gh repo view "$ORG/$REPO" --json isArchived -q '.isArchived')
  
  if [ "$IS_ARCHIVED" != "true" ]; then
    gh api \
      --method PATCH \
      -H "Accept: application/vnd.github+json" \
      "repos/$ORG/$REPO" \
      -f archived=true
    echo "Successfully archived $REPO"
  fi

  popd > /dev/null

  sleep 5
done

