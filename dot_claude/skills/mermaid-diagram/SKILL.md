---
name: mermaid-diagram
description: >
  Generate Mermaid diagrams optimized for Obsidian rendering. Use this skill whenever the user asks to diagram, visualize, chart, flowchart, map out, or draw anything in an Obsidian note or markdown file. Also trigger when writing vault notes that naturally involve workflows, architectures, pipelines, relationships, decision trees, or any concept that benefits from visual structure — even if the user doesn't explicitly ask for a diagram. If you're writing a note and think "this would be clearer with a diagram," use this skill.
---

Generate Mermaid diagrams that render correctly in Obsidian and communicate structure clearly.

## Step 1: Choose the Right Diagram Type

Match the content to the best Mermaid diagram type. The goal is clarity — pick the type that most naturally represents the relationships in the data.

| Content | Diagram Type |
|---------|-------------|
| Process flow, algorithm, pipeline | `flowchart TD` |
| API/service call sequence | `sequenceDiagram` |
| OOP class relationships | `classDiagram` |
| State machine, lifecycle | `stateDiagram-v2` |
| Database schema, entity relationships | `erDiagram` |
| Project timeline, schedule | `gantt` |
| Proportions, distribution | `pie` |
| Branch strategy | `gitGraph` |
| Brainstorm, topic map | `mindmap` |
| Historical events, milestones | `timeline` |
| Priority matrix, 2x2 grid | `quadrantChart` |
| Flow volumes, resource movement | `sankey-beta` |
| Bar/line data visualization | `xychart-beta` |
| Precise block layout | `block-beta` |
| Cloud/infra topology | `architecture-beta` |
| Task board, kanban view | `kanban` |
| User experience journey | `journey` |
| Software architecture (C4 model) | `C4Context` |

When in doubt, `flowchart TD` is the safest default — it handles the widest range of concepts.

## Step 2: Layout for Obsidian's Reading Pane

Obsidian's reading pane is tall and narrow. This affects how diagrams render.

- **Default to `TD` (top-down)**. Vertical flow fits the narrow pane much better than horizontal.
- **Only use `LR`** when the diagram has 3 or fewer nodes in a chain — short horizontal flows are fine, but longer ones get squished.
- **Use subgraphs** to group related nodes. This controls width and gives visual structure. Subgraphs also let you label sections without cluttering node labels.
- **Break large diagrams apart.** If a diagram has more than ~15 nodes, split it into 2-3 focused diagrams with prose bridging them. One massive diagram is harder to read than a sequence of smaller ones.
- Use invisible links (`~~~`) when you need to nudge node positioning without adding semantic connections.

## Step 3: Write Clear Labels

Diagrams show **structure**; surrounding prose shows **detail**. Resist the urge to cram information into node labels.

- Keep labels to **1-4 words**. If you need more, the detail belongs in the text around the diagram.
- Use `<br/>` for multi-line labels when a second line genuinely helps (not markdown line breaks — Mermaid uses HTML `<br/>`).
- Use dotted arrows (`-.->`) for fallback, error, or optional paths — this creates a visual hierarchy between primary and secondary flows.
- Use the `&` operator to converge parallel flows into a single target node.

## Step 4: Apply Styling

Semantic color makes diagrams scannable. Use `classDef` to define meaningful styles.

```mermaid
classDef success fill:#22c55e,stroke:#16a34a,color:#fff
classDef danger fill:#ef4444,stroke:#dc2626,color:#fff
classDef info fill:#3b82f6,stroke:#2563eb,color:#fff
classDef warning fill:#f59e0b,stroke:#d97706,color:#fff
classDef muted fill:#6b7280,stroke:#4b5563,color:#fff
```

For dense diagrams, add a compact config block as the very first thing inside the mermaid fence:

```
---
config:
  flowchart:
    padding: 10
    nodeSpacing: 30
    rankSpacing: 30
---
```

The `base` theme with custom `themeVariables` produces clean, professional results when the default isn't sufficient.

## Step 5: Obsidian Compatibility (Critical)

Obsidian's Mermaid renderer has specific limitations. Ignoring these produces broken or invisible diagrams.

**Things that will break:**

- **Click events, tooltips, interactive links** — Obsidian renders static SVG. Any `click` callback or `href` is silently ignored.
- **ELK layout engine** (`layout: elk`) — not available in Obsidian. Stick to the default Dagre layout.
- **FontAwesome icons** (`fa:fa-database`) — only work if the user has manually loaded FA CSS, which most haven't. Avoid unless you know it's available.
- **`end` as a node name** — this is a reserved keyword in flowcharts and will break parsing. Capitalize it (`End`) or wrap in quotes (`"end"`).
- **Color names** (`red`, `blue`) in theme engine — only hex codes work (`#ff0000`, `#3b82f6`). Named colors silently fail.
- **Frontmatter position** — the `---` config block must be the very first content in the mermaid code fence. No blank lines before it.
- **Subgraph `direction`** — setting `direction LR` inside a subgraph is ignored when child nodes have links to nodes outside that subgraph.
- **Beta diagram types** (`architecture-beta`, `kanban`, `block-beta`, `packet`) — require the `obsidian-mermaid` community plugin. Mention this when using them so the user can install it if needed.

## Step 6: Wrap Up

After generating the diagram:

1. Place the mermaid block inside a fenced code block tagged with `mermaid`.
2. Add a brief sentence before or after the diagram explaining what it shows — diagrams without context are confusing when revisited later.
3. If the diagram is complex and you're unsure it will render perfectly, suggest the user preview it at [mermaid.live](https://mermaid.live) before committing.

## Reference

The user has a comprehensive Mermaid cheat sheet in their vault at:
`2. Knowledge Vault/Tools & Tech/Mermaid.js in Obsidian - Complete Cheat Sheet.md`

If you need detailed syntax for a less common diagram type (sankey, architecture-beta, xychart-beta, etc.), read that note with `mcp__engram__get_note` for the exact syntax before generating.
