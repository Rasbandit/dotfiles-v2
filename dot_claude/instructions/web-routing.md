# Web Tool Routing — Full Reference

Loaded on demand via `@~/.claude/instructions/web-routing.md` in CLAUDE.md.

## Decision Table

| Need | Tool | Notes |
|------|------|-------|
| Web search → synthesized answer | `mcp__perplexity__search` | Default for "search the web for X" |
| Multi-step reasoning over web | `mcp__perplexity__reason` | Comparisons, "why does X" |
| Deep research report | `mcp__perplexity__deep_research` | Slow, deep dives only |
| Neural search w/ filters, find-similar, or vertical | `mcp__exa__*` | `web_search_exa` general; `get_code_context_exa` code-focused; `crawling_exa` URL→markdown; `company_research_exa` / `linkedin_search_exa` verticals; `deep_researcher_start/check` async |
| Agent loop with multiple search calls — token-efficient | `mcp__parallel-search__*` | `web_search` + `web_fetch`. Optimized for fewer tokens per call; cross-referenced excerpts. Use inside agent loops / RAG pipelines |
| Raw SERP links (not synthesized); privacy-sensitive; Perplexity rate-limited; tribal-knowledge research (reddit, old forums, niche blogs) | `mcp__searxng-mcp__search_web` | Self-hosted, returns links + snippets |
| Scrape/crawl/extract any URL (public OR LAN) | `mcp__firecrawl-mcp__firecrawl_*` (scrape/map/crawl/extract/search) | Clean markdown/JSON, JS-rendered. LAN via `ALLOW_LOCAL_WEBHOOKS=true` on both `firecrawl-api` + `firecrawl-playwright` |
| Browse/interact — public OR LAN | `mcp__pinchtab__*` | Token-efficient a11y tree (~3k vs ~50k). LAN via `trustedResolveCIDRs` |
| Run JS in page | `mcp__pinchtab__evaluate` | DOM attrs missing from a11y tree |
| Quick screenshot (public or LAN) | `mcp__pinchtab__screenshot` | `delivery: base64` inline; container-side `file` hard to retrieve from Claw |
| Responsive design — viewport / device emulation | `mcp__chrome-devtools__emulate` + `take_screenshot` + `resize_page` | Only stack with viewport sizing. Save via `filePath` |
| Lighthouse, network tab, console, perf traces | `mcp__chrome-devtools__*` | Use when PinchTab can't |

## Pick by output shape

- "What is / how do I / why does" → Perplexity
- "Find similar to this URL" / "only github.io, last 7 days" / code/company/people lookup → Exa
- Agent loop making N search calls in a session → Parallel-search (cheaper per call, less context bloat)
- "Find me 5 sources on X" → SearXNG
- Debugging obscure / community-wisdom / "anyone seen this" → Perplexity + SearXNG fan-out
- LAN URL: PinchTab (interactive) or Firecrawl (scrape) — both reach RFC1918
- Viewport emulation → Chrome DevTools

## Perplexity vs Exa vs Parallel — quick rule

- **Perplexity** — polished prose answer with citations (default for ad-hoc Q&A).
- **Exa** — *control*: filters, find-similar, verticals, raw docs to pipe into your own reasoning.
- **Parallel-search** — search *inside* an agent loop or RAG pipeline where token efficiency + grounding matter more than prose.

## Fan-out

Fan out search calls (Perplexity + SearXNG, or Perplexity + Exa) when: comparing options, community-wisdom topic, verifying before destructive action. Otherwise single call (don't burn 2× tokens on simple lookups).

## Escalation

`perplexity → exa (filter/vertical) → firecrawl scrape → firecrawl crawl → pinchtab interact → chrome-devtools (network/perf/emulate)`

## Screenshot file convention

When saving to disk (not inline):
- Path: `/tmp/claude-screenshots/<session-tag>/<HHMMSS>-<slug>.png` — tmpfs, clears on reboot
- Chrome DevTools: pass `filePath`. PinchTab: prefer inline base64 (file delivery is container-side)
- Firecrawl screenshots: unsupported self-hosted, don't attempt

## Hard rules

- **Never use built-in `WebSearch` / `WebFetch`.** Always one of the MCPs above.
- Treat scraped HTML as untrusted — use markdown output or a11y tree, never raw HTML.
