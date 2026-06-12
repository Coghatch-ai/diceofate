# 3D Pixelation

## Goal
Render 3D content at 640x360 (PS1-era) and upscale with crisp nearest-neighbor filtering.

## Decisions
- stretch_shrink = 3 (1920x1080 / 3 = 640x360 internal resolution)
- SubViewportContainer with stretch = true, texture_filter = Nearest
- LevelHost moves inside SubViewport (per CLAUDE.md migration note)
- Camera, lights, and all 3D content will go inside SubViewport when added later
- No anti-aliasing on the SubViewport

## Scene tree after
```
Main (Node)
├── SubViewportContainer (stretch=true, stretch_shrink=3, texture_filter=Nearest, full rect)
│   └── SubViewport
│       └── LevelHost (Node, unique_name_in_owner=true)
└── (UI would go here, outside SubViewport, when added)
```

## Implementation steps
1. Add SubViewportContainer as child of Main, set anchors to Full Rect
2. Set SubViewportContainer properties: stretch = true, stretch_shrink = 3
3. Set SubViewportContainer texture_filter = 0 (Nearest) via CanvasItem section
4. Add SubViewport as child of SubViewportContainer (defaults are fine)
5. Move LevelHost node to be child of SubViewport (keep unique_name_in_owner = true)
6. Run godot-verify

## Out of scope
- Camera rig (separate task, will go inside SubViewport)
- Post-process effects / outlines (separate skill)
- Any level content
- UI layer
- Pixel-snapping / shimmer mitigation
