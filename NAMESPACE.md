# Ron-Memory Key Namespace Structure

A organized memory namespace helps agents find and manage information efficiently.

## Key Pattern

All keys follow this structure:

```
ron:<TOPIC>:<SUBJECT>:<ATTRIBUTE>
```

| Level | Meaning | Example |
|-------|---------|---------|
| `ron:` | Prefix (always the same) | `ron:` |
| `<TOPIC>` | Category type | `contact`, `family`, `book`, `project` |
| `<SUBJECT>` | Specific thing | `builder`, `emma`, `atomic_habits` |
| `<ATTRIBUTE>` | Detail about it | `name`, `birthday`, `author` |

**Examples:**
```
ron:contact:builder:name         → Jordan Rivera
ron:family:emma:birthday     → 1992/07/14
ron:book:atomic_habits:author  → Elena Vance
ron:vehicle:bmw:reg            → XY51 ABC
ron:project:workflow:status      → active
```

You can extend with more levels if needed:
```
ron:<TOPIC>:<SUBJECT>:<SUBJECT>:<ATTRIBUTE>
```

## Core Prefixes

| Prefix | Use For | Example Key |
|--------|---------|------------|
| `ron:user:*` | The current user's own data | `ron:user:birthday`, `ron:user:name` |
| `ron:contact:*` | People you know | `ron:contact:builder:current_role` |
| `ron:project:*` | Projects you're working on | `ron:project:workflow:status` |
| `ron:pref:*` | Preferences and settings | `ron:pref:communication:style` |
| `ron:goal:*` | Goals and objectives | `ron:goal:s2_milestone:target_date` |
| `ron:todo:*` | Tasks and action items | `ron:todo:jam_submission:status` |
| `ron:fact:*` | Facts and knowledge | `ron:fact:bmw_reg` |
| `ron:vehicle:*` | Vehicles you own | `ron:vehicle:bmw:reg` |
| `ron:pet:*` | Pets | `ron:pet:rupert:type` |
| `ron:family:*` | Family members | `ron:family:emma:birthday` |
| `ron:service:*` | Subscriptions and services | `ron:service:netflix:login` |
| `ron:asset:*` | Valuable items | `ron:asset:laptop:description` |
| `ron:book:*` | Books you own or want to read | `ron:book:atomic_habits:title` |
| `ron:location:*` | Places | `ron:location:home:address` |
| `ron:skill:*` | Skills and capabilities | `ron:skill:cooking:level` |
| `ron:agent:*` | AI agent config/memory | `ron:agent:dave:role` |
| `ron:device:*` | Devices you own | `ron:device:mini_pc:ip` |
| `ron:subscription:*` | Subscriptions | `ron:subscription:netflix:status` |
| `ron:software:*` | Software licenses | `ron:software:office:license` |
| `ron:credential:*` | Login credentials | `ron:credential:github:username` |
| `ron:domain:*` | Domains you own | `ron:domain:tasksphere.io:registrar` |
| `ron:routine:*` | Daily routines/habits | `ron:routine:morning:steps` |
| `ron:note:*` | Quick notes/ideas | `ron:note:business_idea:1` |
| `ron:health:*` | Health/fitness metrics | `ron:health:weight:current` |

## Detailed Schemas

### User (`ron:user:*`)
Your personal information.
```
ron:user:name = "Alex"
ron:user:birthday = "1985/11/22"
ron:user:pronouns = "he/him"
ron:user:location = "Springfield"
ron:user:timezone = "UK (GMT/BST)"
ron:user:telegram = "@fictionaluser"
```

### Contact (`ron:contact:{name}:*`)
People you interact with — colleagues, friends, acquaintances.
```
ron:contact:builder:name = "Jordan Rivera"
ron:contact:builder:pronouns = "He/Him"
ron:contact:builder:current_role = "Director of Operations @ Stark Industries"
ron:contact:builder:linkedin = "https://linkedin.com/in/fictitioususer"
ron:contact:builder:about = "Oversees staffing and recruiting services..."
ron:contact:builder:mission = "Help candidates find ideal careers"
ron:contact:builder:companies = "Stark Industries, Acme Corp, Globex Inc, Umbrella Corp"
ron:contact:builder:education = "Riverdale Community College (2008-2012)"
ron:contact:builder:location = "Greater Chicago Area"
ron:contact:builder:substack = "https://fictitiousbuilder.substack.com"
ron:contact:builder:tiktok = "@fictitiousbuilder"
ron:contact:builder:instagram = "@builder.builds"
ron:contact:builder:youtube = "@builder.builds"
ron:contact:builder:beacons = "https://beacons.ai/fictitiousbuilder"
```

### Family (`ron:family:{name}:*`)
Family members with relationship context.
```
ron:family:emma:name = "Emma"
ron:family:emma:birthday = "1992/07/14"
ron:family:emma:relation = "spouse"
ron:family:freddie:name = "Tommy"
ron:family:freddie:birthday = "2018/03/20"
ron:family:freddie:relation = "son"
ron:family:magnus:name = "Charlie"
ron:family:magnus:birthday = "2023/01/09"
ron:family:magnus:relation = "son"
ron:family:rupert:name = "Buddy"
ron:family:rupert:birthday = "2018/03/26"
ron:family:rupert:type = "dog"
ron:family:rupert:breed = "Labrador"
```

### Vehicle (`ron:vehicle:{name}:*`)
Cars, bikes, etc.
```
ron:vehicle:bmw:reg = "XY51 ABC"
ron:vehicle:bmw:type = "car"
ron:vehicle:bmw:model = "3 Series"
```

### Project (`ron:project:{name}:*`)
Software projects, business ideas, etc.
```
ron:project:workflow:description = "Automation platform for AI workflows"
ron:project:workflow:status = "active"
ron:project:workflow:url = "https://tasksphere.io"
ron:project:fitpro:description = "Fitness tracking and workout planning app"
ron:project:fitpro:status = "active"
```

### Goal (`ron:goal:{id}:*`)
Goals and milestones.
```
ron:goal:s2_milestone:title = "S2 AI Progress"
ron:goal:s2_milestone:start_date = "2026-04-01"
ron:goal:s2_milestone:target_date = "2026-06-29"
ron:goal:s2_milestone:target_percent = 100
ron:goal:s2_milestone:current_percent = 0
```

### Preference (`ron:pref:{category}:*`)
Preferences for various aspects of life.
```
ron:pref:communication:style = "concise"
ron:pref:communication:updates = "after every commit"
ron:pref:voice:tone = "friendly"
```

### Agent (`ron:agent:{name}:*`)
AI agents and their base configuration.
```
ron:agent:dave:role = "Development"
ron:agent:dave:type = "ACP persistent"
ron:agent:techsupport:role = "Customer Support"
ron:agent:techsupport:type = "Skill-based"
ron:agent:devops:role = "Operations"
ron:agent:devops:type = "Persistent thread agent"
```

### Agent Memory (`ron:agent:{name}:memory:*`)
Each agent's own working memory — what they're currently handling, progress, open items.
```
ron:agent:techsupport:memory:ticket_count = "0"
ron:agent:techsupport:memory:last_ticket_id = "TICKET-001"
ron:agent:techsupport:memory:open_issues = "[]"
ron:agent:dave:memory:active_branch = "main"
ron:agent:dave:memory:current_project = "workflow"
ron:agent:dave:memory:pending_commits = "3"
```

### Agent Context (`ron:agent:{name}:context:*`)
What an agent is actively working on right now.
```
ron:agent:dave:context:current_task = "Fix login bug"
ron:agent:dave:context:started_at = "2026-04-30T10:00:00Z"
ron:agent:dave:context:priority = "high"
ron:agent:devops:context:current_deploy = "workflow-api v1.2.0"
ron:agent:devops:context:last_check = "2026-04-30T09:30:00Z"
ron:agent:techsupport:context:current_ticket = "TICKET-042"
ron:agent:techsupport:context:customer = "acme-corp"
```

### Agent Preferences (`ron:agent:{name}:pref:*`)
How an agent prefers to receive tasks, communicate, and work.
```
ron:agent:dave:pref:style = "methodical"
ron:agent:dave:pref:update_on = "completion"
ron:agent:techsupport:pref:tone = "professional"
ron:agent:techsupport:pref:response_length = "detailed"
ron:agent:devops:pref:notify_on_fail = "always"
```

### Service (`ron:service:{name}:*`)
Online accounts, subscriptions.
```
ron:service:upstash:type = "redis"
ron:service:upstash:url = "https://..." (in credentials file, not here!)
ron:service:github:type = "code hosting"
ron:service:github:username = "exampleuser"
```

### Career (`ron:career:*`)
Work history and current position.
```
ron:career:current_role = "Senior Architect @ TechCorp"
ron:career:current_company = "TechCorp International"
ron:career:current_team = "Digital Creation business unit"
ron:career:history = "Dev Lead on P4 Code review, Dev of Swarm, Technical support"
```

### Fact (`ron:fact:{subject}:*`)
One-off facts that don't fit other categories.
```
ron:fact:bmw_reg = "XY51 ABC"
ron:fact:favorite_color = "blue"
```

### Todo (`ron:todo:{id}:*`)
Action items and tasks.
```
ron:todo:jam_submission:title = "Submit Ron-Memory to Heyron Jam"
ron:todo:jam_submission:deadline = "2026-05-02"
ron:todo:jam_submission:status = "in_progress"
```

### Location (`ron:location:{name}:*`)
Places of interest.
```
ron:location:home:address = "Springfield, UK"
ron:location:home:type = "residence"
```

### Device (`ron:device:{name}:*`)
Computers, phones, servers, IoT devices.
```
ron:device:mini_pc:name = "Heyron Mini PC"
ron:device:mini_pc:ip_external = "203.0.113.42"
ron:device:mini_pc:ip_tailscale = "198.51.100.7"
ron:device:mini_pc:ssh_port = "2222"
ron:device:vps:name = "OpenClaw VPS"
ron:device:iphone:model = "iPhone 15 Pro"
ron:device:laptop:model = "MacBook Pro 16\""
```

### Subscription (`ron:subscription:{name}:*`)
Recurring paid services and memberships.
```
ron:subscription:netflix:status = "active"
ron:subscription:netflix:renewal_date = "2026-05-15"
ron:subscription:spotify:status = "active"
ron:subscription:upstash:plan = "free"
ron:subscription:openclaw:status = "active"
```

### Software (`ron:software:{name}:*`)
Software licenses, installed apps, API access.
```
ron:software:office:license = "Microsoft 365 Family"
ron:software:adobe:license = "Creative Cloud"
ron:software:github:plan = "Pro"
ron:software:xbox:subscription = "Game Pass Ultimate"
```

### Credential (`ron:credential:{service}:*`)
Login credentials for services. ⚠️ Store tokens/URLs in `.env` files instead of here.
```
ron:credential:github:username = "exampleuser"
ron:credential:github:token_stored = "in .env file"
ron:credential:upstash:rest_url = "in .env.ron-memory"
ron:credential:upstash:rest_token = "in .env.ron-memory"
```

### Domain (`ron:domain:{name}:*`)
Domains you own or manage.
```
ron:domain:tasksphere.io:registrar = "Duck DNS"
ron:domain:tasksphere.io:expires = "2027-03-15"
ron:domain:fitproapp.io:status = "active"
ron:domain:fitproapp.io:registrar = "GoDaddy"
```

### Routine (`ron:routine:{name}:*`)
Daily routines, habits, recurring activities.
```
ron:routine:morning:steps = "check phone, review calendar, exercise"
ron:routine:morning:start_time = "07:00"
ron:routine:evening:steps = "review tasks, prep for tomorrow"
ron:routine:evening:start_time = "21:00"
ron:routine:workout:frequency = "3x per week"
ron:routine:workout:duration = "45 minutes"
```

### Note (`ron:note:{id}:*`)
Quick notes, ideas, thoughts.
```
ron:note:business_idea:1 = "AI agent marketplace - connect agents to tasks"
ron:note:business_idea:2 = "Subscription model for Heyron Pro"
ron:note:todo:1 = "Research competitor pricing"
ron:note:question:1 = "Why does Robby use beacons.ai instead of linktree?"
```

### Health (`ron:health:*`)
Health and fitness metrics.
```
ron:health:weight:current = "85kg"
ron:health:weight:last_updated = "2026-04-01"
ron:health:height:current = "180cm"
ron:health:goal:weight = "80kg"
ron:health:exercise:frequency = "3x per week"
ron:health:exercise:type = "gym + running"
```

### Event (`ron:event:{id}:*`)
One-time or recurring events, appointments.
```
ron:event:holiday:2026:destination = "TBD"
ron:event:holiday:2026:type = "summer vacation"
ron:event:appointment:dentist = "2026-06-15"
ron:event:birthday:emma = "2026-04-15"
ron:event:anniversary = "2026-08-18"
```

### Hardware (`ron:hardware:{name}:*`)
Physical equipment beyond computers.
```
ron:hardware:camera:model = "Sony A7III"
ron:hardware:camera:notes = "Full frame mirrorless"
ron:hardware:gaming_setup:console = "Xbox Series X"
ron:hardware:home_server:model = "Synology NAS DS920+"
```

### Gift (`ron:gift:{for}:*`)
Gift ideas, purchased gifts, gift history.
```
ron:gift:emma:idea_1 = "Weekend spa break"
ron:gift:emma:idea_2 = "New jewellery"
ron:gift:freddie:idea_1 = "LEGO Super Mario set"
ron:gift:christmas:2025:status = "complete"
ron:gift:christmas:2025:budget = "£500"
```

### Business (`ron:business:{name}:*`)
Business interests and ventures.
```
ron:business:workflow:stage = "development"
ron:business:workflow:launch_date = "TBD"
ron:business:workflow:revenue_model = "subscription"
ron:business:fitpro:stage = "active"
ron:business:fitpro:users = "beta"
```

### Infrastructure (`ron:infra:*`)
Infrastructure as code, server configs, DNS.
```
ron:infra:mini_pc:sites = "workflow-docs, workflow-api, landing, fitpro"
ron:infra:mini_pc:docker_network = "172.23.0.0/24"
ron:infra:mini_pc:nginx:config = "updated 2026-04-28"
ron:infra:vps:openclaw:version = "latest"
```

### Book (`ron:book:{title}:*`)
Books you own, want to read, or have read.
```
ron:book:atomic_habits:title = "The Optimized Mind"
ron:book:atomic_habits:author = "Elena Vance"
ron:book:atomic_habits:status = "read"
ron:book:atomic_habits:rating = "5/5"
ron:book:deep_work:title = "Focused Excellence"
ron:book:deep_work:author = "Marcus Chen"
ron:book:deep_work:status = "reading"
ron:book:deep_work:notes = "Key insight: deep work is rare but high-value"
```

## Key Conventions

1. **Lowercase** — All keys lowercase for consistency
2. **Singular values** — Store single values, not arrays
3. **Dates in ISO format** — `YYYY/MM/DD` or `YYYY-MM-DD`
4. **URLs complete** — Include full URL with protocol
5. **Descriptions as sentences** — Full descriptive text for readability
6. **Hierarchical** — Use `:separator` for nesting (max 3 levels deep)
7. **Consistent prefixes** — Group by type using prefix pattern
8. **Atomic keys** — Each key stores one fact, not combined values

## Migration

If you used flat keys like `ron:user:builder_name`, migrate to structured keys:

```bash
# Old (flat)
ron:user:builder_name = "Jordan Rivera"

# New (structured)
ron:contact:builder:name = "Jordan Rivera"
```

Run migration scripts to reorganize existing keys.
