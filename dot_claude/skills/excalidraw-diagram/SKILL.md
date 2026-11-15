---
name: excalidraw-diagram
description: >-
  Generate Excalidraw diagrams programmatically as `.excalidraw` files in the user's Obsidian vault.
  Use this skill whenever the user asks for a visual diagram, architecture visualization, flowchart,
  system design, or any freeform layout diagram — especially when they mention "Excalidraw", want
  hand-drawn aesthetics, need precise element positioning, or when the diagram is complex enough that
  Mermaid's auto-layout would produce poor results. Also trigger when the user says "draw me",
  "sketch out", "diagram this architecture", "make a visual of", or wants boxes-and-arrows style
  diagrams with specific spatial relationships. If the user asks for a diagram and doesn't specify
  Mermaid, prefer Excalidraw for anything involving architecture, system design, or multi-layer layouts.
---

Generate Excalidraw diagrams via a Python script that outputs `.excalidraw` JSON files into the Obsidian vault.

## When to use this vs Mermaid

Choose Excalidraw when:
- The user wants precise control over element positioning or spatial layout
- The diagram has multiple layers, sections, or grouped regions
- Architecture diagrams with many interconnected components
- The user wants the hand-drawn/sketch aesthetic
- Mermaid's auto-layout would produce confusing results (crossing lines, poor grouping)
- The user explicitly asks for Excalidraw

Choose Mermaid when:
- Simple sequential flows, class diagrams, or ER diagrams
- The user explicitly asks for Mermaid
- Auto-layout is fine and positioning doesn't matter

## Workflow

### 1. Plan the layout

Before writing any code, think through:
- What are the major sections/groups? (e.g., "Clients", "Backend Services", "Data Stores")
- What color category does each section use? (see Color Palette below)
- Rough spatial arrangement — top-to-bottom flow? left-to-right? clustered regions?
- What connections exist between elements?

Sketch the layout mentally using a grid system (multiples of 50px).

### 2. Write the Python generation script

Write a Python script to `/tmp/gen_excalidraw.py` that builds the diagram elements and outputs JSON.

The script follows this structure:

```python
#!/usr/bin/env python3
"""Generate <diagram-name> Excalidraw diagram."""
import json, random, time

# --- Config ---
OUTPUT = "/home/rasbandit/Documents/Obsidian/LifeOS/Excalidraw/<Name>.excalidraw"

seed_counter = random.randint(1000, 99999)
def next_seed():
    global seed_counter
    seed_counter += 1
    return seed_counter

now = int(time.time() * 1000)
elements = []
idx_counter = [0]

def next_index():
    """Generate fractional index for z-ordering."""
    idx_counter[0] += 1
    return f"a{idx_counter[0]}"

def base_props(eid, etype, x, y, w, h, **overrides):
    """Base properties shared by all elements."""
    props = {
        "id": eid, "type": etype,
        "x": x, "y": y, "width": w, "height": h,
        "angle": 0, "strokeColor": "#1e1e1e",
        "backgroundColor": "transparent",
        "fillStyle": "solid", "strokeWidth": 2,
        "strokeStyle": "solid", "roughness": 1,
        "opacity": 100, "groupIds": [], "frameId": None,
        "roundness": {"type": 3} if etype == "rectangle" else None,
        "seed": next_seed(), "version": 2,
        "versionNonce": next_seed(), "isDeleted": False,
        "boundElements": [], "updated": now,
        "link": None, "locked": False, "index": next_index(),
    }
    props.update(overrides)
    return props

def rect(eid, x, y, w, h, bg="#e9ecef", stroke="#868e96", **kw):
    """Create a rectangle element."""
    el = base_props(eid, "rectangle", x, y, w, h,
                    backgroundColor=bg, strokeColor=stroke, **kw)
    elements.append(el)
    return el

def text(eid, x, y, content, container_id=None, font_size=20,
         font_family=2, align="center", valign="middle", **kw):
    """Create a text element, optionally bound to a container."""
    w = len(content) * font_size * 0.6
    h = font_size * 1.25
    el = base_props(eid, "text", x, y, w, h,
                    roundness=None, **kw)
    el.update({
        "text": content, "originalText": content,
        "fontSize": font_size, "fontFamily": font_family,
        "textAlign": align, "verticalAlign": valign,
        "containerId": container_id,
        "autoResize": True, "lineHeight": 1.25,
    })
    elements.append(el)
    return el

def arrow(eid, x1, y1, x2, y2, start_id=None, end_id=None,
          start_fp=None, end_fp=None, label=None, **kw):
    """Create an arrow from (x1,y1) to (x2,y2), optionally bound to shapes."""
    dx, dy = x2 - x1, y2 - y1
    el = base_props(eid, "arrow", x1, y1, abs(dx), abs(dy),
                    roundness={"type": 2}, **kw)
    el.update({
        "points": [[0, 0], [dx, dy]],
        "startBinding": {
            "elementId": start_id,
            "fixedPoint": start_fp or [0.5, 0.5],
            "focus": 0, "gap": 8
        } if start_id else None,
        "endBinding": {
            "elementId": end_id,
            "fixedPoint": end_fp or [0.5, 0.5],
            "focus": 0, "gap": 8
        } if end_id else None,
        "startArrowhead": None,
        "endArrowhead": "arrow",
    })
    elements.append(el)
    return el

def box(rect_id, text_id, x, y, w, h, label,
        bg="#a5d8ff", stroke="#1971c2", font_size=20, font_family=2,
        roughness=1, opacity=100):
    """Create a labeled rectangle (rect + bound text). Returns rect element."""
    r = rect(rect_id, x, y, w, h, bg=bg, stroke=stroke,
             roughness=roughness, opacity=opacity)
    r["boundElements"] = [{"id": text_id, "type": "text"}]
    text(text_id, x + w/2, y + h/2, label,
         container_id=rect_id, font_size=font_size,
         font_family=font_family, roughness=roughness)
    return r

def label(eid, x, y, content, font_size=24, font_family=2, **kw):
    """Create a standalone text label (not bound to a shape)."""
    return text(eid, x, y, content, font_size=font_size,
                font_family=font_family, align="left", valign="top",
                container_id=None, **kw)

def bind_arrow_to_shapes(arrow_el, start_shape=None, end_shape=None):
    """Register an arrow on the shapes it connects (call after creating the arrow)."""
    binding = {"id": arrow_el["id"], "type": "arrow"}
    if start_shape:
        start_shape["boundElements"].append(binding)
    if end_shape:
        end_shape["boundElements"].append(binding)

# --- Build the diagram ---

# (Diagram-specific element creation goes here)
# Use box() for labeled rectangles, arrow() for connections,
# label() for section headers, rect() for section backgrounds.

# --- Write output ---
scene = {
    "type": "excalidraw",
    "version": 2,
    "source": "https://excalidraw.com",
    "elements": elements,
    "appState": {"gridSize": 20, "viewBackgroundColor": "#ffffff"},
    "files": {}
}
with open(OUTPUT, "w") as f:
    json.dump(scene, f, indent=2)
print(f"Wrote {len(elements)} elements to {OUTPUT}")
```

**Adapt this template** to the specific diagram. The helper functions handle all the boilerplate — focus on the "Build the diagram" section where you place elements spatially and connect them.

### 3. Run the script

```bash
python3 /tmp/gen_excalidraw.py
```

### 4. Confirm output

Tell the user the file was created and where to find it. They can open it directly in Obsidian by navigating to the Excalidraw folder.

## Color Palette

Use these Open Color-based semantic colors. They work well in both light and dark Excalidraw themes.

| Purpose | Background | Stroke | When to use |
|---------|-----------|--------|-------------|
| Clients / Frontend | `#a5d8ff` | `#1971c2` | User-facing components, browsers, mobile apps |
| Backend / Services | `#b2f2bb` | `#2f9e44` | APIs, servers, microservices |
| Data stores | `#d0bfff` | `#9c36b5` | Databases, caches, queues, storage |
| AI / ML services | `#ffd8a8` | `#e8590c` | ML models, AI endpoints, inference |
| Process / Logic | `#ffec99` | `#f08c00` | Decision points, middleware, workflows |
| Error / Fallback | `#ffc9c9` | `#e03131` | Error paths, fallback flows |
| Section backgrounds | `#f1f3f5` | `#dee2e6` | Low-opacity (40-60) grouping rectangles |
| Neutral / Notes | `#e9ecef` | `#868e96` | Annotations, disabled states |

## Layout Guidelines

- **Grid**: Use multiples of 50px for all positioning
- **Standard box**: 200w x 80h for primary labels, 130w x 50h for small nodes
- **Spacing**: 70-100px between elements
- **Section backgrounds**: Use `opacity: 40-60` with light stroke colors, place them *before* foreground elements in the elements array so they render behind
- **Font**: `fontFamily: 3` (Cascadia/monospace) for technical labels, `fontFamily: 2` (Helvetica) for general text
- **Roughness**: `0` for clean architect look, `1` for sketchy hand-drawn feel
- **Font sizes**: 28-36 for titles, 24 for section headers, 20 for box labels, 16 for descriptions, 14 for notes

## Arrow Connection Patterns

When connecting shapes with arrows, always register the arrow on both endpoint shapes using `bind_arrow_to_shapes()`. This ensures the Excalidraw plugin correctly tracks connections.

```python
# Example: connect box_a (right edge) to box_b (left edge)
a = box("box_a", "txt_a", 100, 100, 200, 80, "Service A", bg="#b2f2bb", stroke="#2f9e44")
b = box("box_b", "txt_b", 400, 100, 200, 80, "Service B", bg="#b2f2bb", stroke="#2f9e44")
arr = arrow("arr1", 300, 140, 400, 140, start_id="box_a", end_id="box_b",
            start_fp=[1, 0.5], end_fp=[0, 0.5])
bind_arrow_to_shapes(arr, a, b)
```

**fixedPoint reference** (normalized [0-1, 0-1] on target shape):
- Right edge: `[1, 0.5]`
- Left edge: `[0, 0.5]`
- Top center: `[0.5, 0]`
- Bottom center: `[0.5, 1]`

## Output Location

All diagrams go to: `/home/rasbandit/Documents/Obsidian/LifeOS/Excalidraw/<Name>.excalidraw`

The Obsidian Excalidraw plugin (v2.20.6) reads `.excalidraw` files natively from this folder.

## Detailed Format Reference

For the full Excalidraw JSON schema, all element types, binding details, font families, fill styles, and advanced features, read: `references/format-reference.md`

Consult the reference when you need:
- Exact property types for uncommon elements (freedraw, image, frame, embeddable)
- Arrowhead variants (cardinality markers for ERDs, diamond, circle, bar, etc.)
- Roundness type rules per shape (type 3 for rectangles, type 2 for diamonds/lines)
- `.excalidraw.md` compressed format generation (for Obsidian-native format with frontmatter)
- EA scripting API details
- Grouping and frame containment
- Element linking (URLs, wikilinks, element links)
