---
[Submission] Ron-Memory — @Crazydc90

Repo: https://github.com/crazydc/ron-memories
License: MIT - https://github.com/crazydc/ron-memories/blob/main/LICENSE

───

Ron-Memory gives Heyron agents persistent, cross-session memory using Upstash Redis with a local file cache. When an agent saves a fact, it's stored in Redis and a local markdown file — meaning the agent can retrieve it even if Redis is briefly unavailable.

Core capabilities:

• Save and retrieve facts across sessions (e.g. "my car is a Tesla, REG XY51 ABC")
• 30 documented namespace types (user, family, contact, vehicle, project, goal, preferences)
• Auto-learning when it encounters unknown prefixes
• Trigger phrases: "remember that...", "don't forget...", "note that...", "save that..."
• R.A.G-ready structured key:value storage
• Multi-agent ready — one agent saves, any agent recalls

───

Installation (No Shell Required)

"Install the Ron Memory skill from https://github.com/crazydc/ron-memories"

Then configure: "Set my Upstash credentials: UPSTASH_REDIS_URL=https://your-db.upstash.io, UPSTASH_REDIS_TOKEN=your-token-here"

Get credentials at https://upstash.com (free Redis database).

Example:
User: I have a Tesla with registration XY51 ABC
Agent: memory-set.sh tesla_reg "XY51 ABC"

[later session]
User: What's my car registration?
Agent: memory-get.sh tesla_reg → "XY51 ABC"
───

R.A.G and Multi-Agent Sharing

Structured key:value pairs mean any agent can query "what cars does this user own?" without parsing free text. Namespace prefixing enables semantic search across categories.

memory-learn.sh --audit surfaces all namespaces in use — useful for understanding what an agent knows about a user.

For HeyRon deployments with multiple agents, Ron-Memory acts as a shared brain — one agent learns something, all agents benefit.
---