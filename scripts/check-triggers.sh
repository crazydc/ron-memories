#!/bin/bash
# Ron Memory - Check for trigger phrases in input

# Trigger patterns
TRIGGERS=(
    "remember that"
    "don't forget"
    "important:"
    "note that"
    "i need to remember"
    "save this"
    "keep in mind"
    "remind me"
    "store this"
)

# Read input from args or stdin
if [ $# -gt 0 ]; then
    INPUT="$*"
else
    INPUT=""
    while read -r line; do
        INPUT="$INPUT $line"
    done
fi

# Convert to lowercase for matching
INPUT_LOWER=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')

for trigger in "${TRIGGERS[@]}"; do
    if echo "$INPUT_LOWER" | grep -qi "$trigger"; then
        # Extract the content after the trigger
        CONTENT=$(echo "$INPUT" | sed -i "s/.*$trigger *//i" 2>/dev/null || echo "$INPUT")
        CONTENT=$(echo "$CONTENT" | sed "s/.*$trigger *//i")
        echo "FOUND|$CONTENT"
        exit 0
    fi
done

echo "NONE"
exit 0