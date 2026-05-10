#!/bin/bash
# Ron Memory - Auto-learn new namespaces
# Scans Redis for keys, discovers categories being used, and helps document new ones

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

NAMESPACE_FILE="$SCRIPT_DIR/../NAMESPACE.md"

usage() {
    echo "Usage: memory-learn.sh [--audit|--suggest|--update]"
    echo ""
    echo "  --audit    Scan and list all discovered category patterns"
    echo "  --suggest  Show categories not yet in NAMESPACE.md"
    echo "  --update   Add new categories to NAMESPACE.md (interactive)"
    exit 1
}

# Extract categories from key structure
# Keys look like: ron:user:category:subcategory:value
# We extract the "meaningful" category (usually after ron:user: or at ron:level1:)
extract_categories() {
    curl -s -X GET "$REDIS_URL/keys/*" -H "Authorization: $REDIS_TOKEN" | python3 -c "
import sys, json, re
from collections import defaultdict

try:
    data = json.load(sys.stdin)
    if isinstance(data, dict) and 'result' in data:
        keys = data['result']
    else:
        keys = data
    
    categories = defaultdict(set)
    
    for key in keys:
        parts = key.split(':')
        # Skip 'ron' prefix
        if len(parts) >= 3 and parts[0] == 'ron':
            # Common pattern: ron:user:category:sub:value
            # We want to find 'category' - usually index 2 if index 1 is 'user'
            if len(parts) >= 3:
                if parts[1] == 'user' and len(parts) >= 4:
                    # Extract the actual category (e.g. book, contact, family)
                    category = parts[2]
                    categories[category].add(key)
                elif parts[1] != 'user':
                    # Non-user prefix at level 1
                    category = parts[1]
                    categories[category].add(key)
    
    for cat, keys in sorted(categories.items()):
        example = list(keys)[0]
        print(f'{cat}|{example}')
        
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
}

# Get existing categories from NAMESPACE.md
# Maps common variations to their canonical form
get_existing_categories() {
    grep -E "^### [A-Z].*\(\`ron:" "$NAMESPACE_FILE" | \
        sed 's/### \([^ ]*\) .*/\1/' | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/preference/pref/;s/family/family/;s/contact/contact/' | \
        sort -u
}

# Check if category exists in NAMESPACE.md
category_exists() {
    local cat="$1"
    grep -qi "^### ${cat^} " "$NAMESPACE_FILE" 2>/dev/null
}

# Add a new category to NAMESPACE.md
add_category() {
    local cat="$1"
    local description="$2"
    local example="$3"
    
    # Add to the Core Prefixes table
    sed -i "/| \`ron:skill:\*\`/i | \`ron:${cat}:\*\` — ${description}" "$NAMESPACE_FILE"
    
    # Add section with example
    local section="\n\n### ${cat^} (\`ron:${cat}:*\`)\n${description}.\n\`\`\`\nron:${cat}:example = \"example value\"\n\`\`\`\n"
    echo -e "$section" >> "$NAMESPACE_FILE"
    
    echo "✓ Added '$cat' to NAMESPACE.md"
}

# Main
ACTION="${1:-audit}"
shift 2>/dev/null

case "$ACTION" in
    --audit)
        echo "=== Discovered Categories ==="
        while IFS='|' read -r cat example; do
            [ -z "$cat" ] && continue
            short_key=$(echo "$example" | cut -d: -f1-4)
            echo "  $cat"
            echo "    e.g. $short_key"
        done < <(extract_categories)
        ;;
        
    --suggest)
        echo "=== Categories Not in NAMESPACE.md ==="
        discovered=$(extract_categories | cut -d'|' -f1 | sort -u)
        existing=$(get_existing_categories)
        new_found=0
        
        while IFS='|' read -r cat example; do
            [ -z "$cat" ] && continue
            if ! echo "$existing" | grep -qx "$cat"; then
                echo "  ✗ NEW: $cat"
                echo "    Example: $example"
                new_found=$((new_found + 1))
            fi
        done < <(extract_categories)
        
        echo ""
        if [ $new_found -eq 0 ]; then
            echo "  All discovered categories are documented! ✓"
        else
            echo "  Run with --update to document them"
        fi
        ;;
        
    --update)
        echo "=== Learning New Categories ==="
        discovered=$(extract_categories)
        existing=$(get_existing_categories)
        new_found=0
        
        while IFS='|' read -r cat example; do
            [ -z "$cat" ] && continue
            if ! echo "$existing" | grep -qx "$cat"; then
                echo ""
                echo "New category found: $cat"
                echo "  Example key: $example"
                read -p "  Enter description (e.g. 'Books I own or want to read'): " description
                if [ -n "$description" ]; then
                    add_category "$cat" "$description" "$example"
                    new_found=$((new_found + 1))
                else
                    echo "  Skipped (no description)"
                fi
            fi
        done < <(discovered)
        
        echo ""
        if [ $new_found -eq 0 ]; then
            echo "✓ No new categories to learn"
        else
            echo "✓ Learned $new_found new categories"
            echo ""
            echo "Commit changes? (y/n)"
            read -r answer
            if [ "$answer" = "y" ]; then
                cd "$SCRIPT_DIR/.." && git add -A && git commit -m "Add auto-discovered namespaces" && git push origin master
                echo "✓ Pushed to GitHub"
            fi
        fi
        ;;
        
    *)
        usage
        ;;
esac
