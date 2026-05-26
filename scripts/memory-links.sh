#!/bin/bash
# memory-links.sh v1.0 — Entity relationship manager for ron-memory
# Manages typed relationships between entities (knowledge graph lite)
# Stores links in both local JSON files and Redis under links:* key pattern

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

LINKS_DIR="$RON_CACHE_DIR/links"
mkdir -p "$LINKS_DIR"

# Redis credentials
TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'

# Relationship types
VALID_RELATIONSHIPS="works_at founded lives_in loves visited owns married_to parent_of friend_of colleague_of member_of"

usage() {
    cat << EOF
Usage: memory-links.sh <command> [options]

Commands:
  add <entity1> <relationship> <entity2> [--context "tags"]
  get <entity> [--depth N]
  back <entity>
  list [--type relationship_type]
  suggest <entity> --based-on <text>

Relationships: works_at, founded, lives_in, loves, visited, owns, married_to, parent_of, friend_of, colleague_of, member_of

Examples:
  # Add a link
  memory-links.sh add sam loves reptiles --context "animals"
  memory-links.sh add acasey works_at perforce --context "career"

  # Get outgoing links from an entity
  memory-links.sh get sam
  memory-links.sh get acasey --depth 1

  # Get back-links (who links TO this entity)
  memory-links.sh back reptiles

  # List all links of a type
  memory-links.sh list --type loves

  # Suggest links based on text
  memory-links.sh suggest sam --based-on "Sam loves the Welsh Mountain Zoo"
EOF
}

# Validate relationship type
validate_relationship() {
    local rel="$1"
    for valid in $VALID_RELATIONSHIPS; do
        if [ "$rel" = "$valid" ]; then
            return 0
        fi
    done
    echo "❌ Invalid relationship: $rel"
    echo "Valid: $VALID_RELATIONSHIPS"
    return 1
}

# Normalize entity name (lowercase, replace spaces with underscores)
normalize_entity() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/ /_/g' | sed 's/[^a-z0-9_]//g'
}

# Local JSON storage path for an entity
get_entity_file() {
    local entity="$1"
    echo "$LINKS_DIR/${entity}.json"
}

# Store link in Redis
redis_set_link() {
    local from="$1"
    local rel="$2"
    local to="$3"
    local context="${4:-}"
    
    local redis_key="links:${from}:${rel}:${to}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local json_payload="{\"from\": \"$from\", \"relationship\": \"$rel\", \"to\": \"$to\", \"timestamp\": \"$timestamp\", \"context\": \"$context\", \"confidence\": \"high\", \"source\": \"manual\"}"
    
    curl -s -X POST "$URL/set/$redis_key" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "$json_payload" >/dev/null 2>&1
}

# Store back-link in Redis
redis_set_backlink() {
    local from="$1"
    local rel="$2"
    local to="$3"
    
    local redis_key="backlinks:${to}:${rel}:${from}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local json_payload="{\"from\": \"$from\", \"relationship\": \"$rel\", \"to\": \"$to\", \"timestamp\": \"$timestamp\"}"
    
    curl -s -X POST "$URL/set/$redis_key" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "$json_payload" >/dev/null 2>&1
}

# Add a link
cmd_add() {
    local entity1="$1"
    local relationship="$2"
    local entity2="$3"
    local context=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --context) context="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$entity1" ] || [ -z "$relationship" ] || [ -z "$entity2" ]; then
        echo "❌ Usage: memory-links.sh add <entity1> <relationship> <entity2> [--context 'tags']"
        return 1
    fi
    
    validate_relationship "$relationship" || return 1
    
    local from=$(normalize_entity "$entity1")
    local to=$(normalize_entity "$entity2")
    
    # Local JSON
    local file=$(get_entity_file "$from")
    
    # Create JSON structure
    local link_json="{\"relationship\": \"$relationship\", \"to\": \"$to\", \"context\": \"$context\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"confidence\": \"high\", \"source\": \"manual\"}"
    
    if [ -f "$file" ]; then
        # Add to existing array (avoid duplicates)
        local temp=$(mktemp)
        python3 -c "
import json, sys
with open('$file', 'r') as f:
    data = json.load(f)
# Check for duplicate
exists = False
for link in data.get('links', []):
    if link.get('relationship') == '$relationship' and link.get('to') == '$to':
        exists = True
        break
if not exists:
    data.setdefault('links', []).append(json.loads('$link_json'))
print(json.dumps(data, indent=2))
" > "$temp"
        mv "$temp" "$file"
    else
        echo "{\"entity\": \"$from\", \"links\": [$(echo "$link_json")]}" > "$file"
    fi
    
    # Store in Redis
    redis_set_link "$from" "$relationship" "$to" "$context"
    redis_set_backlink "$from" "$relationship" "$to"
    
    echo "✅ Added: $from --$relationship--> $to"
}

# Get outgoing links from an entity
cmd_get() {
    local entity="$1"
    local depth=1
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --depth) depth="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$entity" ]; then
        echo "❌ Usage: memory-links.sh get <entity> [--depth N]"
        return 1
    fi
    
    local norm=$(normalize_entity "$entity")
    local file=$(get_entity_file "$norm")
    
    if [ ! -f "$file" ]; then
        echo "No links found for: $entity"
        return 0
    fi
    
    echo "Links for: $entity"
    echo ""
    
    python3 -c "
import json
with open('$file', 'r') as f:
    data = json.load(f)
for link in data.get('links', []):
    rel = link.get('relationship', '')
    to = link.get('to', '')
    ctx = link.get('context', '')
    conf = link.get('confidence', '')
    print(f'  --{rel}--> {to}', end='')
    if ctx:
        print(f' (context: {ctx})', end='')
    print('')
" 2>/dev/null
}

# Get back-links (who links TO this entity)
cmd_back() {
    local entity="$1"
    
    if [ -z "$entity" ]; then
        echo "❌ Usage: memory-links.sh back <entity>"
        return 1
    fi
    
    local norm=$(normalize_entity "$entity")
    
    # Search local files for references to this entity
    echo "Back-links for: $entity"
    echo ""
    
    local found=0
    for file in "$LINKS_DIR"/*.json; do
        [ -f "$file" ] || continue
        local name=$(basename "$file" .json)
        
        # Check if this entity links to our target
        if grep -q "\"to\": \"$norm\"" "$file" 2>/dev/null; then
            python3 -c "
import json
with open('$file', 'r') as f:
    data = json.load(f)
entity = data.get('entity', '')
for link in data.get('links', []):
    if link.get('to') == '$norm':
        rel = link.get('relationship', '')
        print(f'{entity} --{rel}--> $norm')
" 2>/dev/null
            found=1
        fi
    done
    
    if [ "$found" = "0" ]; then
        echo "  No back-links found"
    fi
}

# List all links, optionally filtered by type
cmd_list() {
    local type_filter=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) type_filter="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    echo "All links"
    if [ -n "$type_filter" ]; then
        echo "Filter: $type_filter"
    fi
    echo ""
    
    local count=0
    for file in "$LINKS_DIR"/*.json; do
        [ -f "$file" ] || continue
        
        python3 -c "
import json, sys
with open('$file', 'r') as f:
    data = json.load(f)
entity = data.get('entity', '')
for link in data.get('links', []):
    rel = link.get('relationship', '')
    to = link.get('to', '')
    if '$type_filter' == '' or rel == '$type_filter':
        print(f'{entity} --{rel}--> {to}')
" 2>/dev/null
        count=1
    done
    
    if [ "$count" = "0" ]; then
        echo "No links found"
    fi
}

# Suggest links based on text content
cmd_suggest() {
    local entity=""
    local text=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --based-on) text="$2"; shift 2 ;;
            *) entity="$1"; shift ;;
        esac
    done
    
    if [ -z "$entity" ] || [ -z "$text" ]; then
        echo "❌ Usage: memory-links.sh suggest <entity> --based-on <text>"
        return 1
    fi
    
    local norm=$(normalize_entity "$entity")
    echo "Link suggestions for: $entity"
    echo "Based on: $text"
    echo ""
    
    local text_lc=$(echo "$text" | tr '[:upper:]' '[:lower:]')
    
    # Pattern-based detection using Python for better regex handling
    python3 << PYSCRIPT
import re

text = """$text"""
text_lc = text.lower()

stopwords = {'the', 'a', 'an', 'in', 'at', 'on', 'to', 'for', 'with', 'and', 'or', 'but'}
suggestions = []

# loves pattern - handles "Sam loves X and Y"
loves_match = re.search(r'loves?\s+(.+?)(?:\s+at\s|$)', text, re.IGNORECASE)
if loves_match:
    remaining = loves_match.group(1).strip()
    items = [s.strip() for s in remaining.split(' and ')]
    for item in items:
        # Filter out stopwords
        words = item.split()
        meaningful = [w for w in words if w.lower() not in stopwords and len(w) > 1]
        if meaningful:
            capitals = re.findall(r'([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*)', item)
            if capitals:
                target = capitals[-1]
            else:
                target = ' '.join(meaningful)
            norm_target = target.lower().replace(' ', '_').replace('-', '_')
            suggestions.append(("loves", norm_target))

# works_at pattern
if re.search(r'works?\s+(?:at|for)|employed\s+(?:at|by)', text_lc):
    match = re.search(r'(?:works?\s+(?:at|for)|employed\s+(?:at|by))\s+([A-Z][a-zA-Z]+)', text, re.IGNORECASE)
    if match:
        target = match.group(1).lower().replace(' ', '_').replace('-', '_')
        suggestions.append(("works_at", target))

# visited pattern - stop at time indicators
visited_match = re.search(r'(?:visited?|goes?\s+to|went\s+to)\s+(.+?)(?:\s+(?:last|this|next|yesterday|tomorrow|on\s+\d|\d)|$)', text, re.IGNORECASE)
if visited_match:
    target = visited_match.group(1).strip()
    capitals = re.findall(r'([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*)', target)
    if capitals:
        target = capitals[-1]
    norm_target = target.lower().replace(' ', '_').replace('-', '_')
    suggestions.append(("visited", norm_target))

# lives_in pattern
if re.search(r'lives?\s+(?:in|at)|resident\s+of', text_lc):
    match = re.search(r'lives?\s+(?:in|at)\s+([A-Z][a-zA-Z]+)', text, re.IGNORECASE)
    if match:
        target = match.group(1).lower().replace(' ', '_').replace('-', '_')
        suggestions.append(("lives_in", target))

# parent_of pattern
if re.search(r'parent\s+of|father\s+of|mother\s+of|has\s+a\s+(?:son|daughter|child|kid)', text_lc):
    match = re.search(r'(?:son|daughter|child|kid)\s+named\s+([A-Z][a-z]+)', text, re.IGNORECASE)
    if match:
        target = match.group(1).lower().replace(' ', '_').replace('-', '_')
        suggestions.append(("parent_of", target))

# owns pattern
if re.search(r'owns?|has\s+a\s+\w+\s+named\s+', text_lc):
    match = re.search(r'has\s+a\s+(\w+)\s+named\s+([A-Z][a-z]+)', text, re.IGNORECASE)
    if match:
        thing = match.group(1).lower()
        target = match.group(2).lower().replace(' ', '_').replace('-', '_')
        suggestions.append(("owns", target))

if suggestions:
    print("Suggested links:")
    entity_norm = "$norm"
    for rel, target in suggestions:
        print(f"  {entity_norm} --{rel}--> {target}")
    print("")
    print(f"To add: memory-links.sh add {entity_norm} <relationship> <target>")
else:
    print("  No clear relationships detected")
    print("")
    print("Tip: Try phrasing like:")
    print("  - 'X loves Y and Z'")
    print("  - 'X works at Y'")
    print("  - 'X visited Y'")
    print("  - 'X lives in Y'")
PYSCRIPT
}

# Main
COMMAND="$1"
case "$COMMAND" in
    add) shift; cmd_add "$@" ;;
    get) shift; cmd_get "$@" ;;
    back) shift; cmd_back "$@" ;;
    list) shift; cmd_list "$@" ;;
    suggest) shift; cmd_suggest "$@" ;;
    *) usage; exit 1 ;;
esac