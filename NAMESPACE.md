# Ron-Memory Key Namespace Structure

A organized memory namespace helps agents find and manage information efficiently.

## Core Prefixes

| Prefix | Use For | Example Key |
|--------|---------|------------|
| `ron:user:*` | The current user's own data | `ron:user:birthday`, `ron:user:name` |
| `ron:contact:*` | People you know | `ron:contact:robby:current_role` |
| `ron:project:*` | Projects you're working on | `ron:project:heyron:status` |
| `ron:pref:*` | Preferences and settings | `ron:pref:communication:style` |
| `ron:goal:*` | Goals and objectives | `ron:goal:s2_milestone:target_date` |
| `ron:todo:*` | Tasks and action items | `ron:todo:jam_submission:status` |
| `ron:fact:*` | Facts and knowledge | `ron:fact:bmw_reg` |
| `ron:vehicle:*` | Vehicles you own | `ron:vehicle:bmw:reg` |
| `ron:pet:*` | Pets | `ron:pet:rupert:type` |
| `ron:family:*` | Family members | `ron:family:louise:birthday` |
| `ron:service:*` | Subscriptions and services | `ron:service:netflix:login` |
| `ron:asset:*` | Valuable items | `ron:asset:laptop:description` |
| `ron:location:*` | Places | `ron:location:home:address` |
| `ron:skill:*` | Skills and capabilities | `ron:skill:cooking:level` |

## Detailed Schemas

### User (`ron:user:*`)
Your personal information.
```
ron:user:name = "Dale"
ron:user:birthday = "1990/06/04"
ron:user:pronouns = "he/him"
ron:user:location = "Basingstoke"
ron:user:timezone = "UK (GMT/BST)"
ron:user:telegram = "@Crazydc90"
```

### Contact (`ron:contact:{name}:*`)
People you interact with — colleagues, friends, acquaintances.
```
ron:contact:robby:name = "Rob Houston"
ron:contact:robby:pronouns = "He/Him"
ron:contact:robby:current_role = "Director of Operations @ Mackin Talent"
ron:contact:robby:linkedin = "https://linkedin.com/in/robmhouston"
ron:contact:robby:about = "Oversees staffing and recruiting services..."
ron:contact:robby:mission = "Help candidates find ideal careers"
ron:contact:robby:companies = "Mackin Talent, Logic Staffing, Parker Staffing, Convergys"
ron:contact:robby:education = "Georgia Northwestern Technical College (2008-2012)"
ron:contact:robby:location = "Greater Seattle Area"
ron:contact:robby:substack = "https://robhouston.substack.com"
ron:contact:robby:tiktok = "@robbyhouston"
ron:contact:robby:instagram = "@robby.builds"
ron:contact:robby:youtube = "@robby.builds"
ron:contact:robby:beacons = "https://beacons.ai/robbyhouston"
```

### Family (`ron:family:{name}:*`)
Family members with relationship context.
```
ron:family:louise:name = "Louise"
ron:family:louise:birthday = "1989/03/07"
ron:family:louise:relation = "wife"
ron:family:freddie:name = "Freddie"
ron:family:freddie:birthday = "2019/11/08"
ron:family:freddie:relation = "son"
ron:family:magnus:name = "Magnus"
ron:family:magnus:birthday = "2024/08/25"
ron:family:magnus:relation = "son"
ron:family:rupert:name = "Rupert"
ron:family:rupert:birthday = "2018/03/26"
ron:family:rupert:type = "dog"
ron:family:rupert:breed = "Labrador"
```

### Vehicle (`ron:vehicle:{name}:*`)
Cars, bikes, etc.
```
ron:vehicle:bmw:reg = "KT17 KWU"
ron:vehicle:bmw:type = "car"
ron:vehicle:bmw:model = "3 Series"
```

### Project (`ron:project:{name}:*`)
Software projects, business ideas, etc.
```
ron:project:heyron:description = "AI agent platform"
ron:project:heyron:status = "active"
ron:project:heyron:url = "https://heyron.ai"
ron:project:louisegym:description = "Workout app for wife Louise"
ron:project:louisegym:status = "active"
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

### Service (`ron:service:{name}:*`)
Online accounts, subscriptions.
```
ron:service:upstash:type = "redis"
ron:service:upstash:url = "https://..." (in credentials file, not here!)
ron:service:github:type = "code hosting"
ron:service:github:username = "crazydc"
```

### Career (`ron:career:*`)
Work history and current position.
```
ron:career:current_role = "Triage Manager @ Perforce Software"
ron:career:current_company = "Perforce Software"
ron:career:current_team = "Digital Creation business unit"
ron:career:history = "Dev Lead on P4 Code review, Dev of Swarm, Technical support"
```

### Fact (`ron:fact:{subject}:*`)
One-off facts that don't fit other categories.
```
ron:fact:bmw_reg = "KT17 KWU"
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
ron:location:home:address = "Basingstoke, UK"
ron:location:home:type = "residence"
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

If you used flat keys like `ron:user:robby_name`, migrate to structured keys:

```bash
# Old (flat)
ron:user:robby_name = "Rob Houston"

# New (structured)
ron:contact:robby:name = "Rob Houston"
```

Run migration scripts to reorganize existing keys.
