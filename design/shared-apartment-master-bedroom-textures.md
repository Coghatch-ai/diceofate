# Shared Apartment — Master Bedroom Textures (Slice 3)

**Goal** — Walking into the master bedroom, the props no longer read as flat-grey greybox: the wardrobe, nightstand and desk show pixel-art wood, the bed shows its bedding texture — so the room visibly reads as "3D pixel art" in the actual scene, not the editor viewport.

**Why this slice** — The user asked to *see* the pixel art applied in the apartment scene ("only there, as of now was only greybox. I need to see"). One prop (`BedMaster`) already proves the wiring works; this slice extends that proof to the rest of the room using the textures already on disk. It is the smallest change that turns "one textured box among four grey boxes" into "a textured room".

**Scope (in)**
- Re-wire the four remaining master-bedroom prop materials in `levels/shared_apartment.tscn` from flat `albedo_color` to `albedo_texture`, using the PNGs **already in `assets/textures/`** — no new art authored:
  - **Wardrobe** (`StandardMaterial3D_u4q88`) → `desk_wood.png` (vertical wood-plank texture; reads as a wood wardrobe).
  - **NightstandMaster** (`StandardMaterial3D_alb77`) → `desk_wood.png`.
  - **DeskMaster** (`StandardMaterial3D_6vjlv`) → `desk_wood.png`.
  - **BedMaster** — already textured (`bed_fabric.png`); leave as-is. Confirm it still renders.
- Each re-wired material: `albedo_texture = ExtResource(desk_wood.png)`, **`texture_filter = 1`** (NEAREST — the trap is `3`), per skill `godot-texture-import-pixel-art`. Keep `albedo_color` white (default) so the texture isn't tinted dark.
- Ensure `assets/textures/desk_wood.png.import` has `mipmaps/generate=false` and `compress/mode=0` (skill step 1). `assets/` is gitignored — the sidecar is regenerated, not committed.
- One shared `desk_wood` material sub-resource reused by the three wood props is fine (and cleaner) — but each prop's BoxMesh keeps its own `size`, so UVs differ per box. That's acceptable for this "see it in the scene" pass.

**Scope (out)**
- **ChairMaster** — stays flat `albedo_color` Color(0.45,0.45,0.50). No fitting texture exists on disk (it's an upholstered chair, not wood). Texturing it is blocked on art → see Later / asset-sourcing loop. Leaving one grey prop is the honest, observable boundary, not a miss.
- **Per-face / strip UV mapping** — Godot wraps one PNG across all six box faces with default UVs, so a tall wardrobe shows the wood stretched vertically and the bed's top texture also appears on its sides. Fixing texel density / per-face UVs is a *style* improvement, parked (Later). This slice is "make the textures appear", not "make every face perfect".
- **New textures** for chair, walls, floor, or twin/kitchen/bath props — not authored here; separate art-sourcing + slices.
- **Texel-density tuning** to match the world pixel grid — parked; needs the UV work above to be meaningful.

**Acceptance**
- `$GODOT --headless --path . --script tools/verify_scene.gd -- levels/shared_apartment.tscn main.tscn` prints `VERIFY: OK` (catches a dropped `albedo_texture` / bad `ExtResource`).
- Smoke run: `$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR"` finds nothing.
- In the saved `.tscn`: Wardrobe, NightstandMaster, DeskMaster materials each have `albedo_texture` referencing `desk_wood.png` and `texture_filter = 1` (not `3`); BedMaster unchanged.
- **F5**, load SharedApartment, walk to the master bedroom (right end of corridor, up through the master door): the wardrobe, nightstand and desk visibly show **wood-grain pixel-art** (not flat brown), the bed shows its bedding, texels are **crisp/blocky** at SubViewport scale (no blur, no moire — proves NEAREST + no-mipmap). The chair remains a flat grey-blue box (expected). Nothing else in the apartment changed.

**Skill notes**
- `godot-texture-import-pixel-art` — the whole slice. Step 3 (`texture_filter = 1` on each `StandardMaterial3D`, the `=3` mipmap trap), step 1 (`.import` sidecar `mipmaps/generate=false`, `compress/mode=0`), error table (blur → filter is `3`; moire → mipmaps on).
- `godot-3d-pixelation` — textures must be judged at SubViewport scale, not in the editor; verify through the running game (F5), not the viewport.
- `godot-verify` — mandatory 3-layer check; `albedo_texture` is exactly the kind of property silently dropped if the `ExtResource` is malformed.
- `godot-pixel-lighting` — unchanged; the existing sun/ambient already lights these boxes. No lighting edits this slice.

**Later**
- **Chair texture** — author/source an upholstery PNG (asset-sourcing loop: asset-advisor → Get Assets modal → wire), then texture ChairMaster.
- **Per-face / strip UVs + texel density** — stop one PNG smearing across all six faces; map wood vertically on tall props, bedding only on the bed top. The real "looks intentional, not stretched" pass. Likely its own small slice once art is settled.
- **Walls & floor textures** — currently flat zone colours; a tiled wall/floor pixel-art pass is a separate slice.
- **Other rooms' props** (twin, kitchen, bath) — texture as those prop slices land.

**Open questions** — none. (Chair-without-art is a deliberate scope cut, not a blocker: the slice is observable with four of five props textured.)
</content>
</invoke>
