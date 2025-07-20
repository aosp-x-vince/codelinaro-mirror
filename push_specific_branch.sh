#!/bin/bash

# Disable colorized output from commands to prevent visual glitches
export NO_COLOR=1

# --- Configuration ---
MANIFEST_FILE="codelinaro.xml"
SOURCE_REMOTE_BASE="https://git.codelinaro.org/clo/la"
DEST_GH_ORG="aosp-x-vince"
# --- End of Configuration ---

set -e # Exit immediately if a command fails

echo "### Starting specific branch push process ###"
echo "### This script will push ONLY the specific commit from the manifest to a new branch. ###"
echo "-------------------------------------------------"

# 1. Prerequisites Check
if ! command -v gh &> /dev/null; then
    echo "ERROR: GitHub CLI 'gh' not found. Please install it."
    exit 1
fi
if ! gh auth status &> /dev/null; then
    echo "ERROR: Not logged into GitHub. Please run 'gh auth login'."
    exit 1
fi
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "ERROR: Manifest file '$MANIFEST_FILE' not found."
    exit 1
fi

# 2. Parse the default revision from the manifest's <default> tag
default_revision=$(grep '<default ' "$MANIFEST_FILE" | sed -n 's/.*revision="\([^"]*\)".*/\1/p')
if [ -z "$default_revision" ]; then
    echo "ERROR: Could not find a <default ... revision=\"...\"> tag in the manifest."
    exit 1
fi
echo "Default revision from manifest is: ${default_revision}"

# 3. Create a temporary directory for cloning
TEMP_DIR="repo_push_temp"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"
echo "Created temporary directory: $(pwd)"

# 4. Parse the manifest and process each project
grep '<project ' "../$MANIFEST_FILE" | while read -r line; do
    # Extract the required attributes from the project line
    source_repo_name=$(echo "$line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')
    commit_ref=$(echo "$line" | sed -n 's/.*revision="\([^"]*\)".*/\1/p')
    upstream_branch_ref=$(echo "$line" | sed -n 's/.*upstream="\([^"]*\)".*/\1/p')

    # Use the default revision if a project-specific one isn't found
    if [ -z "$commit_ref" ]; then
        commit_ref=$default_revision
    fi
    
    # Determine the name for our new branch in the destination repo.
    if [ -n "$upstream_branch_ref" ]; then
        target_branch_name=$(basename "$upstream_branch_ref")
    else
        target_branch_name=$default_revision
    fi

    # Sanitize the repo name for GitHub (e.g., 'platform/vendor/qcom' -> 'platform_vendor_qcom')
    dest_repo_name=$(echo "$source_repo_name" | tr '/' '_')
    
    echo ""
    echo "--- Processing: ${source_repo_name} ---"
    echo "  - Source Commit/Ref: ${commit_ref}"
    echo "  - Destination Repo: ${DEST_GH_ORG}/${dest_repo_name}"
    echo "  - Destination Branch: ${target_branch_name}"

    # 5. Create the repository on GitHub if it doesn't exist
    if gh repo view "${DEST_GH_ORG}/${dest_repo_name}" &> /dev/null; then
        echo "Repository ${dest_repo_name} already exists. Skipping creation."
    else
        echo "Creating repository ${dest_repo_name} on GitHub..."
        gh repo create "${DEST_GH_ORG}/${dest_repo_name}" --public --description "Fork of ${SOURCE_REMOTE_BASE}/${source_repo_name} for branch ${target_branch_name}"
    fi

    # 6. Clone the source repository as a bare repo (very efficient)
    source_repo_url="${SOURCE_REMOTE_BASE}/${source_repo_name}.git"
    clone_dir="${dest_repo_name}.git"
    
    echo "Cloning (bare) from ${source_repo_url}..."
    git clone --bare "$source_repo_url" "$clone_dir"

    # 7. Push ONLY the specific commit to the new branch in your GitHub repo
    echo "Pushing '${commit_ref}' to new branch '${target_branch_name}'..."
    (
        cd "$clone_dir"
        git push "https://github.com/${DEST_GH_ORG}/${dest_repo_name}.git" "${commit_ref}:refs/heads/${target_branch_name}" --force
    )

    # 8. Clean up the local bare clone to save space
    echo "Cleaning up local clone..."
    rm -rf "$clone_dir"

    echo "--- Successfully processed ${source_repo_name} ---"
done

# 9. Final cleanup
cd ..
rm -rf "$TEMP_DIR"
echo ""
echo "-------------------------------------------------"
echo "### All projects have been processed successfully! ###"