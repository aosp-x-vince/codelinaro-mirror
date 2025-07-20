#!/bin/bash

# Config
MANIFEST_FILE="codelinaro.xml"
GITHUB_ORG="aosp-x-vince"
REMOTE_BASE="https://git.codelinaro.org/clo/la"

mkdir -p repos && cd repos

# Authenticate if needed
gh auth status || gh auth login

# Parse and loop through each project
xmlstarlet sel -t -m '//project' \
    -v '@name' -o '|' \
    -v '@path' -o '|' \
    -v '@revision' -n \
    "../$MANIFEST_FILE" | while IFS="|" read -r NAME PATH REVISION; do

  [[ -z "$NAME" ]] && continue

  LOCAL_PATH="${PATH:-$NAME}"
  BRANCH="${REVISION:-master}"
  DEST_REPO="$GITHUB_ORG/${LOCAL_PATH}"
  DEST_URL="https://github.com/$DEST_REPO.git"

  echo "📦 [$NAME] Cloning branch $BRANCH"
  git clone --branch "$BRANCH" --single-branch "$REMOTE_BASE/$NAME.git" "$LOCAL_PATH" || continue

  echo "🚀 Creating repo on GitHub: $DEST_REPO"
  gh repo view "$DEST_REPO" > /dev/null 2>&1 || gh repo create "$DEST_REPO" --public --confirm

  echo "🔄 Pushing branch $BRANCH to GitHub"
  cd "$LOCAL_PATH"
  git remote set-url origin "$DEST_URL"
  git push origin "$BRANCH"
  cd ..
done

echo "✅ Done pushing selected branches to $GITHUB_ORG"
