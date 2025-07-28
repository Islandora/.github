#!/usr/bin/env bash

set -euo pipefail

ORG="Islandora"
WORKDIR=$(pwd | xargs dirname)
NEW_FILE_NAME=".github/workflows/stale.yaml"

REPOS=$(gh repo list "$ORG" --limit 1000 --json name -q '.[].name')

for REPO in $REPOS; do
  if [ "$REPO" = ".github" ]; then
    echo "skipping .github repo"
    continue
  fi

  if [ -f "$WORKDIR/$REPO/$NEW_FILE_NAME" ]; then
    echo "$REPO/$NEW_FILE_NAME exists, skipping"
    continue
  fi

  if [ ! -d "$WORKDIR/$REPO" ]; then
    gh repo clone "$ORG/$REPO" "$WORKDIR/$REPO"
  fi

  MINUTE=$(( RANDOM % 60 ))
  HOUR=$(( RANDOM % 23 ))
  STALE_YML="name: 'Manage stale issues and PRs'
on:
  workflow_dispatch:
  schedule:
    - cron: '$MINUTE $HOUR * * *'
jobs:
  stale:
    uses: $ORG/.github/.github/workflows/stale.yaml@main
    secrets: inherit"

  pushd "$WORKDIR/$REPO"

  DEFAULT_BRANCH=$(gh repo view "$ORG/$REPO" --json defaultBranchRef -q '.defaultBranchRef.name')

  git checkout "$DEFAULT_BRANCH"
  git pull origin "$DEFAULT_BRANCH"

  mkdir -p "$(echo "$NEW_FILE_NAME" | xargs dirname)"
  echo "$STALE_YML" > "$NEW_FILE_NAME"
  git add "$NEW_FILE_NAME"
  git commit -m "Adding stale.yaml GHA"


  CURRENT_STATUS=$(gh api "repos/$ORG/$REPO/branches/$DEFAULT_BRANCH/protection" --jq '.enforce_admins.enabled' || echo "false")
  if [ "$CURRENT_STATUS" = "true" ]; then
    echo "Disabling admin bypass on $ORG/$REPO:$DEFAULT_BRANCH temporarily"
    gh api \
      --method DELETE \
      -H "Accept: application/vnd.github+json" \
      "repos/$ORG/$REPO/branches/$DEFAULT_BRANCH/protection/enforce_admins"
  fi
  git push origin "$DEFAULT_BRANCH"
  if [ "$CURRENT_STATUS" = "true" ]; then
    echo "Re-Enabling admin bypass"
    gh api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      "repos/$ORG/$REPO/branches/$DEFAULT_BRANCH/protection/enforce_admins"
  fi

  popd > /dev/null

  sleep 5
done

