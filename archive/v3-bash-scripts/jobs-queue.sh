#!/bin/bash
# Per-Agent Job Queue System - Ron-Memory Integration
# Each agent has its own queue. Jobs are routed based on type.
# Agents poll their own queue during heartbeats.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Upstash credentials
UPSTASH_REDIS_URL=""
UPSTASH_REDIS_TOKEN=""

for f in "$SCRIPT_DIR/../../../.env.ron-memory" \
         "$HOME/.openclaw/workspace/.env.ron-memory" \
         "/root/.openclaw/workspace/.env.ron-memory"; do
    if [ -f "$f" ]; then
        source "$f"
        break
    fi
done

if [ -z "$UPSTASH_REDIS_URL" ] || [ -z "$UPSTASH_REDIS_TOKEN" ]; then
    echo "ERROR: Upstash credentials not found"
    exit 1
fi

AGENT_ID="${1:-unknown}"
VERB="${2:-check}"

# Python helper for Upstash operations
python_redis() {
    python3 -c "
import sys, json, subprocess, os

# Load env
with open('/root/.openclaw/workspace/.env.ron-memory') as f:
    for line in f:
        if line.startswith('UPSTASH_'):
            k, v = line.strip().split('=', 1)
            os.environ[k] = v.replace('\"', '')

url = os.environ.get('UPSTASH_REDIS_URL', '')
token = os.environ.get('UPSTASH_REDIS_TOKEN', '')

$1
" 2>/dev/null
}

# Get a value from Upstash
upstash_get() {
    local key="$1"
    python3 << PYEOF
import urllib.request, json

with open('/root/.openclaw/workspace/.env.ron-memory') as f:
    for line in f:
        if line.startswith('UPSTASH_'):
            k, v = line.strip().split('=', 1)
            if k == 'UPSTASH_REDIS_URL':
                url = v.replace('"', '')
            elif k == 'UPSTASH_REDIS_TOKEN':
                token = v.replace('"', '')

req = urllib.request.Request(f'{url}/get/$key',
    headers={'Authorization': f'Bearer {token}'})
resp = json.loads(urllib.request.urlopen(req).read().decode())
r = resp.get('result', None)
if r:
    if isinstance(r, str):
        try:
            r = json.loads(r)
        except:
            pass
    if isinstance(r, dict) and 'value' in r:
        v = r['value']
        try:
            print(json.loads(v))
        except:
            print(v)
    else:
        print(r)
PYEOF
}

# Set a value in Upstash
upstash_set() {
    local key="$1"
    local value="$2"
    python3 << PYEOF
import urllib.request, json

with open('/root/.openclaw/workspace/.env.ron-memory') as f:
    for line in f:
        if line.startswith('UPSTASH_'):
            k, v = line.strip().split('=', 1)
            if k == 'UPSTASH_REDIS_URL':
                url = v.replace('"', '')
            elif k == 'UPSTASH_REDIS_TOKEN':
                token = v.replace('"', '')

data = json.dumps({'value': $value}).encode()
req = urllib.request.Request(f'{url}/set/$key',
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    data=data, method='POST')
urllib.request.urlopen(req)
print('OK')
PYEOF
}

# Delete a key
upstash_del() {
    local key="$1"
    python3 << PYEOF
import urllib.request, json

with open('/root/.openclaw/workspace/.env.ron-memory') as f:
    for line in f:
        if line.startswith('UPSTASH_'):
            k, v = line.strip().split('=', 1)
            if k == 'UPSTASH_REDIS_URL':
                url = v.replace('"', '')
            elif k == 'UPSTASH_REDIS_TOKEN':
                token = v.replace('"', '')

req = urllib.request.Request(f'{url}/del/$key',
    headers={'Authorization': f'Bearer {token}'},
    data=b'', method='POST')
urllib.request.urlopen(req)
print('OK')
PYEOF
}

# Job type -> agent routing
get_agent_for_job() {
    local job_type="$1"
    case "$job_type" in
        healthcheck|reminder|notification|data-fetch|memory-cleanup)
            echo "main"
            ;;
        code-review|deployment|bugfix|feature|testing)
            echo "dave"
            ;;
        ticket-response|customer-query|escalation)
            echo "techsupport"
            ;;
        docker|nginx|ssh|backup|infrastructure)
            echo "devops"
            ;;
        *)
            echo "main"
            ;;
    esac
}

# Get queue as JSON array
get_queue_json() {
    local agent="$1"
    local result=$(upstash_get "jobs:$agent:queue")
    if [ -z "$result" ] || [ "$result" = "None" ]; then
        echo "[]"
    else
        echo "$result"
    fi
}

# Add job to agent's queue
add_job_to_agent() {
    local agent="$1"
    local job_type="$2"
    local payload="$3"
    local priority="${4:-normal}"
    local job_id="job_$(date +%s)_$RANDOM"
    
    python3 << PYEOF
import urllib.request, json

with open('/root/.openclaw/workspace/.env.ron-memory') as f:
    for line in f:
        if line.startswith('UPSTASH_'):
            k, v = line.strip().split('=', 1)
            if k == 'UPSTASH_REDIS_URL':
                url = v.replace('"', '')
            elif k == 'UPSTASH_REDIS_TOKEN':
                token = v.replace('"', '')

agent = '$agent'
job_id = '$job_id'
job_type = '$job_type'
payload = '''$payload'''
priority = '$priority'

# Get current queue
req = urllib.request.Request(f'{url}/get/jobs:{agent}:queue',
    headers={'Authorization': f'Bearer {token}'})
resp = json.loads(urllib.request.urlopen(req).read().decode())
r = resp.get('result', None)
queue = []
if r:
    if isinstance(r, str):
        try:
            r = json.loads(r)
        except:
            pass
    if isinstance(r, dict) and 'value' in r:
        v = r['value']
        try:
            queue = json.loads(v)
        except:
            queue = [v] if v else []
    elif isinstance(r, list):
        queue = r

# Add new job
new_job = {
    'id': job_id,
    'type': job_type,
    'payload': payload,
    'priority': priority,
    'created_at': '$(date -I)',
    'status': 'pending'
}
queue.append(new_job)

# Save
data = json.dumps({'value': json.dumps(queue)}).encode()
req = urllib.request.Request(f'{url}/set/jobs:{agent}:queue',
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    data=data, method='POST')
urllib.request.urlopen(req)
print(f'Job {job_id} added to {agent} queue')
PYEOF
}

# Claim next job from queue
claim_job() {
    local agent="$1"
    
    python3 << PYEOF
import urllib.request, json

with open('/root/.openclaw/workspace/.env.ron-memory') as f:
    for line in f:
        if line.startswith('UPSTASH_'):
            k, v = line.strip().split('=', 1)
            if k == 'UPSTASH_REDIS_URL':
                url = v.replace('"', '')
            elif k == 'UPSTASH_REDIS_TOKEN':
                token = v.replace('"', '')

agent = '$agent'

# Get current queue
req = urllib.request.Request(f'{url}/get/jobs:{agent}:queue',
    headers={'Authorization': f'Bearer {token}'})
resp = json.loads(urllib.request.urlopen(req).read().decode())
r = resp.get('result', None)
queue = []
if r:
    if isinstance(r, str):
        try:
            r = json.loads(r)
        except:
            pass
    if isinstance(r, dict) and 'value' in r:
        v = r['value']
        try:
            queue = json.loads(v)
        except:
            queue = [v] if v else []
    elif isinstance(r, list):
        queue = r

# Find first pending job
claimed = None
for job in queue:
    if job.get('status') == 'pending' and not claimed:
        job['status'] = 'in_progress'
        job['claimed_at'] = '$(date -I)'
        claimed = job

# Build new queue (with claimed job updated in place)
new_queue = queue

# Save updated queue
data = json.dumps({'value': json.dumps(new_queue)}).encode()
req = urllib.request.Request(f'{url}/set/jobs:{agent}:queue',
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    data=data, method='POST')
urllib.request.urlopen(req)

if claimed:
    print(claimed['id'])
else:
    print('NO_JOBS')
PYEOF
}

# Complete a job
complete_job() {
    local agent="$1"
    local job_id="$2"
    local result="${3:-success}"
    
    python3 << PYEOF
import urllib.request, json

with open('/root/.openclaw/workspace/.env.ron-memory') as f:
    for line in f:
        for line in f:
            if line.startswith('UPSTASH_'):
                k, v = line.strip().split('=', 1)
                if k == 'UPSTASH_REDIS_URL':
                    url = v.replace('"', '')
                elif k == 'UPSTASH_REDIS_TOKEN':
                    token = v.replace('"', '')

agent = '$agent'
job_id = '$job_id'
result = '$result'

# Get current queue
req = urllib.request.Request(f'{url}/get/jobs:{agent}:queue',
    headers={'Authorization': f'Bearer {token}'})
resp = json.loads(urllib.request.urlopen(req).read().decode())
r = resp.get('result', None)
queue = []
if r:
    if isinstance(r, str):
        try:
            r = json.loads(r)
        except:
            pass
    if isinstance(r, dict) and 'value' in r:
        v = r['value']
        try:
            queue = json.loads(v)
        except:
            queue = [v] if v else []
    elif isinstance(r, list):
        queue = r

# Update job status, remove from queue
new_queue = []
for job in queue:
    if job.get('id') == job_id:
        job['status'] = 'completed'
        job['result'] = result
        job['completed_at'] = '$(date -I)'
    else:
        new_queue.append(job)

# Save
data = json.dumps({'value': json.dumps(new_queue)}).encode()
req = urllib.request.Request(f'{url}/set/jobs:{agent}:queue',
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    data=data, method='POST')
urllib.request.urlopen(req)
print(f'Completed: {job_id}')
PYEOF
}

# Check my queue
check_queue() {
    local agent="$1"
    
    python3 << PYEOF
import urllib.request, json

with open('/root/.openclaw/workspace/.env.ron-memory') as f:
    for line in f:
        if line.startswith('UPSTASH_'):
            k, v = line.strip().split('=', 1)
            if k == 'UPSTASH_REDIS_URL':
                url = v.replace('"', '')
            elif k == 'UPSTASH_REDIS_TOKEN':
                token = v.replace('"', '')

agent = '$agent'

print(f'=== Agent: {agent} ===')
print()

# Get queue
req = urllib.request.Request(f'{url}/get/jobs:{agent}:queue',
    headers={'Authorization': f'Bearer {token}'})
resp = json.loads(urllib.request.urlopen(req).read().decode())
r = resp.get('result', None)
queue = []
if r:
    if isinstance(r, str):
        try:
            r = json.loads(r)
        except:
            pass
    if isinstance(r, dict) and 'value' in r:
        v = r['value']
        try:
            queue = json.loads(v)
        except:
            queue = [v] if v else []
    elif isinstance(r, list):
        queue = r

if not queue:
    print('No jobs in queue')
else:
    pending = [j for j in queue if j.get('status') == 'pending']
    in_progress = [j for j in queue if j.get('status') == 'in_progress']
    print(f'Jobs: {len(pending)} pending, {len(in_progress)} in progress')
    
    for job in pending[:3]:
        print()
        print('Next job:')
        print(f"  ID: {job.get('id', '')}")
        print(f"  Type: {job.get('type', '')}")
        print(f"  Priority: {job.get('priority', '')}")
        print(f"  Payload: {job.get('payload', '')}")
PYEOF
}

# List all queues
list_all_queues() {
    for agent in main dave techsupport devops; do
        check_queue "$agent"
        echo ""
    done
}

# Add job (auto-routes)
add_job() {
    local job_type="$1"
    local payload="$2"
    local priority="${3:-normal}"
    local target=$(get_agent_for_job "$job_type")
    add_job_to_agent "$target" "$job_type" "$payload" "$priority"
}

# Main
case "$VERB" in
    check)
        check_queue "$AGENT_ID"
        ;;
    claim)
        claim_job "$AGENT_ID"
        ;;
    add)
        add_job "$3" "$4" "$5"
        ;;
    add-to)
        add_job_to_agent "$3" "$4" "$5" "$6"
        ;;
    complete)
        complete_job "$AGENT_ID" "$3" "$4"
        ;;
    list)
        list_all_queues
        ;;
    *)
        echo "Per-Agent Job Queue System"
        echo ""
        echo "Usage: $0 <agent_id> <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  check              - Check my queue (for heartbeat)"
        echo "  claim              - Claim next pending job"
        echo "  add <type> <msg>   - Add job (auto-routes)"
        echo "  add-to <agent> <type> <msg>  - Add to specific agent"
        echo "  complete <job_id>  - Mark job done"
        echo "  list               - List all queues"
        echo ""
        echo "Job Types -> Agent Routing:"
        echo "  main: healthcheck, reminder, notification, data-fetch, memory-cleanup"
        echo "  dave: code-review, deployment, bugfix, feature, testing"
        echo "  techsupport: ticket-response, customer-query, escalation"
        echo "  devops: docker, nginx, ssh, backup, infrastructure"
        ;;
esac