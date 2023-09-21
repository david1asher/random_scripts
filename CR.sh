#!/bin/bash

# The branch you want to compare against
BRANCH_NAME="$1"

# Check if a branch name was provided
if [ -z "$BRANCH_NAME" ]; then
    echo "Usage: $0 BRANCH_NAME"
    exit 1
fi

# Create or clear the output file
OUTPUT_FILE="full_context_diff.json"
echo "[" > "$OUTPUT_FILE"

# Flag to control comma separation between entries
FIRST_ENTRY=true

# Determine the correct refspec prefix
if [[ "$BRANCH_NAME" == remotes/* ]]; then
    REFSPEC="refs/$BRANCH_NAME"
else
    REFSPEC="refs/heads/$BRANCH_NAME"
fi

# For each file that has been changed
for file in $(git diff --name-only "$BRANCH_NAME"); do
    # Capture diff of the file
    DIFF_CONTENT=$(git diff "$REFSPEC" -- "$file" | jq -Rs .)

    # Capture the "before" state of the file (if it exists in the current branch)
    if [ -f "$file" ]; then
        BEFORE_CONTENT=$(cat "$file" | jq -Rs .)
    else
        BEFORE_CONTENT="null"
    fi

    # Capture the "after" state of the file (from the branch you're comparing against)
    AFTER_CONTENT=$(git show "$REFSPEC:$file" 2>/dev/null | jq -Rs .)

    # If not the first entry, add a comma separator
    if [ "$FIRST_ENTRY" = true ]; then
        FIRST_ENTRY=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    # Create the file's JSON entry
    echo "{ \"filename\": \"$file\", \"diff\": $DIFF_CONTENT, \"before_content\": $BEFORE_CONTENT, \"after_content\": $AFTER_CONTENT }" >> "$OUTPUT_FILE"

done

echo "]" >> "$OUTPUT_FILE"
echo "Output written to $OUTPUT_FILE"
