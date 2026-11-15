# Excalidraw File Format Reference

Comprehensive reference for the Excalidraw JSON schema. Consult this when you need details beyond what SKILL.md covers.

## Table of Contents

1. [Top-Level Scene Schema](#1-top-level-scene-schema)
2. [Base Element Properties](#2-base-element-properties)
3. [Element Types](#3-element-types)
4. [Text-in-Shape Binding](#4-text-in-shape-binding)
5. [Arrow Bindings](#5-arrow-bindings)
6. [Arrowhead Types](#6-arrowhead-types)
7. [Roundness Types](#7-roundness-types)
8. [Font Families](#8-font-families)
9. [Fill Styles](#9-fill-styles)
10. [Grouping](#10-grouping)
11. [Frames](#11-frames)
12. [Element Linking](#12-element-linking)
13. [Color Palette (Full)](#13-color-palette-full)
14. [Generating .excalidraw.md Format](#14-generating-excalidrawmd-format)
15. [Text Dimension Approximation](#15-text-dimension-approximation)
16. [Font Size Guidelines](#16-font-size-guidelines)

---

## 1. Top-Level Scene Schema

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [],
  "appState": {
    "gridSize": 20,
    "viewBackgroundColor": "#ffffff",
    "theme": "light"
  },
  "files": {}
}
```

The `files` object stores embedded images as base64 data URLs, keyed by fileId.

---

## 2. Base Element Properties

Every element shares these properties:

| Property | Type | Notes |
|---|---|---|
| `id` | string | 8-char alphanumeric nanoid |
| `type` | string | Element type |
| `x`, `y` | number | Position (top-left corner) |
| `width`, `height` | number | Dimensions in px |
| `angle` | number | Rotation in radians (90deg = Math.PI/2) |
| `strokeColor` | string | CSS color. Default: `"#1e1e1e"` |
| `backgroundColor` | string | Fill color. Default: `"transparent"` |
| `fillStyle` | string | `"solid"`, `"hachure"`, `"cross-hatch"`, `"zigzag"` |
| `strokeWidth` | number | 1 (thin), 2 (default), 4 (extra bold) |
| `strokeStyle` | string | `"solid"`, `"dashed"`, `"dotted"` |
| `roughness` | number | 0=Architect, 1=Artist, 2=Cartoonist |
| `opacity` | number | 0-100 |
| `roundness` | object/null | See Roundness Types section |
| `seed` | number | Random int for roughjs rendering |
| `version` | number | Incremented on each change |
| `versionNonce` | number | Random int for conflict resolution |
| `index` | string/null | Fractional index for z-ordering |
| `isDeleted` | boolean | Soft delete flag |
| `groupIds` | string[] | Group IDs, deepest first |
| `frameId` | string/null | Containing frame element ID |
| `boundElements` | array/null | Elements bound to this one |
| `updated` | number | Epoch ms timestamp |
| `link` | string/null | URL, `[[wikilink]]`, or `element://<id>` |
| `locked` | boolean | Lock state |

---

## 3. Element Types

### Generic shapes: `rectangle`, `diamond`, `ellipse`
No additional properties beyond base.

### Text element
```
fontSize: number (default 20)
fontFamily: number (see Font Families)
text: string (displayed/wrapped text)
originalText: string (original unwrapped text)
textAlign: "left" | "center" | "right"
verticalAlign: "top" | "middle" | "bottom"
containerId: string | null (parent shape ID)
autoResize: boolean (true = width fits text)
lineHeight: number (unitless, ~1.25)
```

### Linear elements: `line`, `arrow`
```
points: [number, number][] (relative to element x,y)
startBinding: FixedPointBinding | null
endBinding: FixedPointBinding | null
startArrowhead: Arrowhead | null
endArrowhead: Arrowhead | null
```

Arrow-specific: `elbowed: boolean` (right-angle routing)
Line-specific: `polygon: boolean` (closes the shape)

### FreeDraw
```
points: [number, number][]
pressures: number[]
simulatePressure: boolean
```

### Image
```
fileId: string | null (references top-level files object)
status: "pending" | "saved" | "error"
scale: [number, number] (flip with -1)
crop: { x, y, width, height, naturalWidth, naturalHeight } | null
```

### Frame
```
name: string | null (display name)
```
Frame styling is fixed: strokeColor "#bbb", strokeWidth 2, roughness 0, transparent bg.

### Embeddable / Iframe
No additional properties (embeddable). Iframe may have `customData.generationData`.

---

## 4. Text-in-Shape Binding

To place text inside a shape:
1. Shape gets `boundElements: [{ "id": "<text-id>", "type": "text" }]`
2. Text gets `containerId: "<shape-id>"`, `textAlign: "center"`, `verticalAlign: "middle"`

Text auto-centers with 5px padding. Valid containers: rectangle, diamond, ellipse, arrow.

---

## 5. Arrow Bindings

### FixedPointBinding (current format)
```json
{
  "elementId": "shape-id",
  "fixedPoint": [0.5, 0.5],
  "focus": 0,
  "gap": 8
}
```

`fixedPoint` is normalized [0-1, 0-1] on the bound element:
- `[0, 0]` = top-left
- `[0.5, 0.5]` = center
- `[1, 1]` = bottom-right
- `[1, 0.5]` = right edge center
- `[0, 0.5]` = left edge center
- `[0.5, 0]` = top center
- `[0.5, 1]` = bottom center

When a shape has bound arrows, its `boundElements` includes: `{ "id": "arrow-id", "type": "arrow" }`

---

## 6. Arrowhead Types

| Value | Description |
|---|---|
| `"arrow"` | Standard arrow tip |
| `"bar"` | Perpendicular line |
| `"circle"` | Filled circle |
| `"circle_outline"` | Hollow circle |
| `"triangle"` | Filled triangle |
| `"triangle_outline"` | Hollow triangle |
| `"diamond"` | Filled diamond |
| `"diamond_outline"` | Hollow diamond |

**ERD cardinality markers:**
`"cardinality_one"`, `"cardinality_many"`, `"cardinality_one_or_many"`,
`"cardinality_exactly_one"`, `"cardinality_zero_or_one"`, `"cardinality_zero_or_many"`

---

## 7. Roundness Types

| Type | Value | Use for |
|---|---|---|
| LEGACY | 1 | Legacy rectangles (proportional) |
| PROPORTIONAL_RADIUS | 2 | Linear elements, diamonds (25% of largest side) |
| ADAPTIVE_RADIUS | 3 | Rectangles (fixed 32px radius, like CSS border-radius) |
| Sharp corners | null | No rounding |

Rules:
- Rectangles: `{ "type": 3 }` (or `null` for sharp)
- Diamonds: `{ "type": 2 }`
- Lines/arrows: `{ "type": 2 }`
- Text: `null` always

---

## 8. Font Families

| Value | Font | Use |
|---|---|---|
| 1 | Virgil | Hand-drawn style |
| 2 | Helvetica | Clean sans-serif (professional diagrams) |
| 3 | Cascadia | Monospace (code, technical labels) |
| 5 | Excalifont | Current default hand-drawn |
| 6 | Nunito | Rounded sans-serif |
| 7 | Lilita One | Bold display |
| 8 | Comic Shanns | Comic-style monospace |

In Obsidian plugin: values 1-3 are reliably supported. Use 2 for professional, 3 for code.

---

## 9. Fill Styles

| Value | Description |
|---|---|
| `"solid"` | Solid color fill (recommended for programmatic generation) |
| `"hachure"` | Diagonal line fill (classic Excalidraw) |
| `"cross-hatch"` | Cross-hatched lines |
| `"zigzag"` | Zigzag pattern |

---

## 10. Grouping

Elements share group membership via `groupIds` arrays. Nested groups list deepest first:

```json
{"id": "a", "groupIds": ["inner-group", "outer-group"]}
{"id": "b", "groupIds": ["inner-group", "outer-group"]}
{"id": "c", "groupIds": ["outer-group"]}
```

---

## 11. Frames

Set `frameId` on child elements to contain them in a frame:

```json
{"id": "frame-1", "type": "frame", "name": "My Frame", "x": 0, "y": 0, "width": 500, "height": 400}
{"id": "box-1", "type": "rectangle", "frameId": "frame-1", "x": 20, "y": 20, "width": 100, "height": 80}
```

---

## 12. Element Linking

The `link` property accepts:
- URLs: `"https://example.com"`
- Obsidian wikilinks: `"[[Note Name]]"` or `"[[Note Name#heading]]"`
- Element links: `"element://<elementId>"`

Wikilinks create clickable Obsidian navigation and appear in graph view.

---

## 13. Color Palette (Full)

Open Color values used by Excalidraw (indices [0]=light to [4]=dark):

| Color | [0] | [1] | [2] | [3] | [4] |
|---|---|---|---|---|---|
| gray | `#f8f9fa` | `#e9ecef` | `#ced4da` | `#868e96` | `#343a40` |
| red | `#fff5f5` | `#ffc9c9` | `#ff8787` | `#fa5252` | `#e03131` |
| pink | `#fff0f6` | `#fcc2d7` | `#f783ac` | `#e64980` | `#c2255c` |
| grape | `#f8f0fc` | `#eebefa` | `#da77f2` | `#be4bdb` | `#9c36b5` |
| violet | `#f3f0ff` | `#d0bfff` | `#9775fa` | `#7950f2` | `#6741d9` |
| blue | `#e7f5ff` | `#a5d8ff` | `#4dabf7` | `#228be6` | `#1971c2` |
| cyan | `#e3fafc` | `#99e9f2` | `#3bc9db` | `#15aabf` | `#0c8599` |
| teal | `#e6fcf5` | `#96f2d7` | `#38d9a9` | `#12b886` | `#099268` |
| green | `#ebfbee` | `#b2f2bb` | `#69db7c` | `#40c057` | `#2f9e44` |
| yellow | `#fff9db` | `#ffec99` | `#ffd43b` | `#fab005` | `#f08c00` |
| orange | `#fff4e6` | `#ffd8a8` | `#ffa94d` | `#fd7e14` | `#e8590c` |
| bronze | `#f8f1ee` | `#eaddd7` | `#d2bab0` | `#a18072` | `#846358` |

Special: black `#1e1e1e`, white `#ffffff`, transparent `"transparent"`

Use [1] index for backgrounds (visible in both themes), [4] index for strokes (high contrast).

---

## 14. Generating .excalidraw.md Format

For Obsidian-native format with frontmatter and compression, use this Python approach:

```python
# Requires: pip install lzstring
from lzstring import LZString
import json

def generate_excalidraw_md(elements, app_state=None, files=None):
    scene = {
        "type": "excalidraw",
        "version": 2,
        "source": "https://github.com/zsviczian/obsidian-excalidraw-plugin",
        "elements": elements,
        "appState": {
            "gridSize": None,
            "viewBackgroundColor": "#ffffff",
            **(app_state or {})
        },
        "files": files or {}
    }

    compressed = LZString.compressToBase64(json.dumps(scene))

    text_content = "\n".join(
        e["text"] for e in elements
        if e.get("type") == "text" and not e.get("isDeleted")
    )

    return "\n".join([
        "---", "",
        "excalidraw-plugin: parsed",
        "tags: [excalidraw]", "",
        "---",
        "==⚠  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠==", "",
        "", "# Excalidraw Data", "",
        "## Text Elements",
        text_content,
        "%%",
        "## Drawing",
        "```compressed-json",
        compressed,
        "```",
        "%%"
    ])
```

Note: The `.excalidraw` (plain JSON) format is simpler and works fine with the Obsidian plugin. Use `.excalidraw.md` only when you need Obsidian frontmatter, tags, or graph-view link integration.

---

## 15. Text Dimension Approximation

Without the rendering engine, approximate text dimensions:
- **Width**: `len(text) * fontSize * 0.6` (monospace) or `* 0.5` (proportional)
- **Height**: `numberOfLines * fontSize * lineHeight`
- **lineHeight**: typically 1.25

For bound text (inside shapes), set `autoResize: True` and the plugin handles sizing.

---

## 16. Font Size Guidelines

| Use Case | Size |
|---|---|
| Main titles | 28-36 |
| Section headers | 24 |
| Box labels | 20 |
| Descriptions | 16 |
| Notes/annotations | 14 |
| Fine print | 12 |
