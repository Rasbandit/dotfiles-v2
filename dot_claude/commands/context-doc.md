---
description: Create a lean context doc so the AI can act on a domain without rediscovering every session
argument-hint: <topic or tool area, e.g. "omada network", "home assistant", "docker FastRaid">
---

The user wants to create a **context document** for a specific domain so that future sessions can act immediately without discovery.

Topic: $ARGUMENTS

---

## What a context doc IS

A lookup table for action. It gives the AI the exact IDs, names, MACs, endpoints, and tool call signatures needed to execute commands **directly** — no discovery, no exploration, no guessing.

Think: cheat sheet, not documentation. The user should be able to say "turn off the basement AP" and the AI can do it in one tool call because it has the device MAC and knows the exact tool.

## What a context doc is NOT

- Not a full reference manual (that belongs in the engram vault)
- Not a tutorial or explanation of how things work
- Not an exhaustive inventory of every capability

## Process

### 1. Discover what's available

- Identify relevant MCP tools, APIs, or CLI commands for the topic
- Test a few read-only calls to confirm connectivity and auth work
- Note any tools that error or aren't available
- **Map every connection path:** Find all auth mechanisms, API keys, tokens, config files, env vars, and credential stores involved. Trace the full chain: where creds are stored → how they get loaded → which tools/calls use them. The doc must make this explicit so no future session ever has to hunt for auth details.

### 2. Gather live state (read-only)

Pull the minimum data needed to act. Focus on:
- **Entity IDs** — the internal IDs needed to make API/tool calls (site IDs, device MACs, network IDs, profile IDs, etc.)
- **Name-to-ID mappings** — so the user can say a human name and the AI resolves it instantly
- **Current topology** — what's connected to what, which port, which VLAN, which network

Do NOT gather: historical data, logs, statistics, or anything that changes frequently.

### 3. Write the doc

Create `docs/<topic-slug>.md` in the project root. Structure:

```
## <Topic> — Quick Reference

### Connection / Auth
Every connection path spelled out. For each one:
- **Where creds live** (file path, env var name, secret store)
- **How they get loaded** (sourced by script, read by MCP server, passed as env var)
- **How to regenerate** if missing (which script to run, which UI to visit)
Example: "API keys in `scripts/secrets.conf` → loaded into `.mcp.json` by `scripts/setup-mcp.sh` → passed as env vars to the MCP server"
The AI should NEVER need to search for auth info — it's all right here.

### Entity Map
Tables mapping human names → IDs/MACs/addresses needed for tool calls.
One table per entity type (devices, networks, profiles, ports, etc.)
Keep columns minimal: Name | ID/MAC | Key detail (e.g. VLAN, IP, port number)

### Common Operations
Tool call signatures for the most common actions, using real IDs from above.
Format as: **Action description:**
```tool_call(param: "real_value")```
Group by action type (e.g. "Switch Ports", "Clients", "Networks")

### Limitations
Bullet list of what CANNOT be done through the available tools.
Only include things someone would reasonably try to ask for.
```

**Lean rules:**
- Every line must help the AI execute a command. If it doesn't, cut it.
- Prefer tables over prose. Tables are scannable; prose wastes tokens.
- Use real values from the live system, not placeholders.
- No explanations of what fields mean — the AI knows the tool schemas.
- No duplication of info already in CLAUDE.md or other @-imported docs.

### 4. Register in CLAUDE.md

Add a **single line** near the top of CLAUDE.md (after the environment section, before protocol sections). Use a plain text reference, NOT an `@` import:

```
For <topic> operations, read `docs/<topic-slug>.md`.
```

This keeps context scoped — the doc is only loaded when the task needs it.

### 5. Offer to commit

Stage the new doc and the CLAUDE.md edit. Use conventional commit format:
`docs: add <topic> context doc for direct operations`
