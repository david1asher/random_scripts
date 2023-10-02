#!/bin/bash

# The branch you want to compare against
BRANCH_NAME="$1"
DEFAULT_BRANCH_NAME="remotes/origin/feature/product-bundle-admin-orders"
# Check if a branch name was provided
if [ -z "$BRANCH_NAME" ]; then
    echo "Usage: $0 BRANCH_NAME"
    BRANCH_NAME=$DEFAULT_BRANCH_NAME
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



# Create or clear the code review markdown file
REVIEW_FILE="code_review.md"
echo "# Code Review Notes" > "$REVIEW_FILE"

# Iterate over each diff in the output file and generate feedback
jq -c '.[]' "$OUTPUT_FILE" | while read -r item; do
    FILENAME=$(echo "$item" | jq -r '.filename')
    DIFF_CONTENT=$(echo "$item" | jq -r '.diff')

    # Construct JSON payload using jq for the chat endpoint
    PAYLOAD=$(jq -n \
              --arg model "gpt-3.5-turbo-16k" \
              --arg message_content "Review the following code diff for $FILENAME: $DIFF_CONTENT" \
              '{ model: $model, messages: [{ role: "system", content: "You are a helpful assistant." }, { role: "user", content: $message_content }] }')

    # Call OpenAI API using the chat completions endpoint
    RESPONSE=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d "$PAYLOAD" \
      "https://api.openai.com/v1/chat/completions")

    # Check if the API call was successful
    if [ "$(echo "$RESPONSE" | jq -r '.error')" != "null" ]; then
        echo "Error calling OpenAI API for $FILENAME: $(echo "$RESPONSE" | jq -r '.error.message')"
        continue
    fi

    # Extract feedback from the response
    FEEDBACK=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

    # Check if feedback is empty or null
    if [ -z "$FEEDBACK" ] || [ "$FEEDBACK" == "null" ]; then
        echo "No feedback received for $FILENAME"
        continue
    fi

    # Write feedback to the markdown file
    echo -e "\n## $FILENAME\n\n$FEEDBACK" >> "$REVIEW_FILE"
done

echo "Code review notes written to $REVIEW_FILE"
