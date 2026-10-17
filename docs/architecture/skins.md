# Architecture: Zone skins: the shared parts (doodads, dash walls, floor cuts, ceilings, lighting, skies)

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Zone skins

A `ZoneSkin` (`scripts/world/skins/zone_skin.gd`) decorates abstract pieces through hooks
(`floor_segment`, `floor_cut`, `wall_section`, `fence`, `wall_fence`, `wall_sign`, `ceiling_section` (by
default `hull`), `pad`, `ramp`, `speed_pad`, `doodad`, `dash_wall`, `finish_line`, `make_environment`). Skins add visuals
only, never collision or gameplay. Hazards keep one colour and shape language in every zone (pink
crackle = electric fence).
`TrackBuilder` also calls `note_wall_enemies(side, start, end, enemies)` just before `wall_section()`
for each side (a no-op default): the chunk's wall enemy layout entries (type, at, side, ...), for a
skin whose own scenery would otherwise double up with one (the Marketplace's citizens, task D3, kept
clear of window cyborgs) or make room for one (the Golden Zone's skins open a Gilded Sentinel's niche,
task C4); read-only and visual only, like every other hook.
After a side's wall sections and wall gaps it calls `wall_run_guide(parent, side, face_x, start, end, lit)` for each
wall-run gap's lit wall in the chunk (task J2; The generator, Wall-run gaps: `lit` is Vector3(where the stretch to
step on starts, the gap's start, its end), `start`/`end` the part in this chunk). The default
(`standard_wall_run_guide`, which no skin overrides yet) draws, in a skin with `show_wall_run_guide` (the default,
`true`; every zone's skin after the Marketplace's sets it `false` and draws nothing: task L5, the owner, October 17,
2026, "making the player use their brain a little bit more"; The generator, Wall-run gaps on the track), the ramps' green chevrons in the skin's `ramp_color`
(`WALL_RUN_COLOR` without one), as the Floating Head's wall marks show a wall run: a tall, bright, framed panel over the
stretch to step on and a strip at running height over the gap, `WALL_RUN_PROUD` off the wall line, its pattern running
on across chunks; never a hazard colour, never flickering. A skin may draw its own, as long as it reads as the way.
**What a side wall gap shows behind it** (task L4; the owner, October 17, 2026: "there is a hole in the wall, and
one of the buildings in the background doesn't have any other sides to it ... these holes leave an ugly unrendered
section in the background. Please add a little bit of background"). The skins draw a building as the flat face
the street sees (plus a near end above lower neighbours), so a wall left out for a gap showed the sky's skyline
below the horizon through it and, at the cut, the building's open end. `ZoneSkin.wall_gap` now builds one batch from
three calls: `wall_gap_marks` (`standard_wall_gap`: the orange lip and the stripes up the cut edges, the cross-zone
language; its old 6 m by 7 m dark slabs are gone), `wall_gap_recess(batch, side, face_x, start, end, gap)`, which
closes the opening, and `wall_gap_extras(batch, side, face_x, start, end)`, a skin's own additions (with the left wall,
the plane below the street its `below()` draws); one mesh instance. The recess: the gap's part is **an alley between the two buildings it cuts**, `RECESS_DEPTH` (16-24 m) deep behind the
wall line: both cut ends' faces (`MeshKit.end_quad`: `leading` faces on down the track, the other faces the runner
coming up, the one the camera sees), from the zone's own plane far below the street (the same one `below()` draws
across the street: the market floor, the trench, the crater floor, the void, the canal, the well, the road) to the
building's top in its colours and window grid, the face of a building across, and that
ground. It is built where a gap is and nowhere else (a few quads for a whole gap and a handful of vertices more per
chunk part), in the layers the walls draw with, so it adds no material and no shader (`test_zone_shaders`) and no
collision, and costs a gap part at most the facade and solid surfaces (one or two draw calls, shared with the extras'
solid layer); nothing in it is a glow or a hazard's colour (the buildings' own lit windows and the City road's traffic
are what they always were). A skin with a facade shader puts the faces in the facade layer in the building's own style
(`MarketFacades.recess`, `CasinoFacades` through its `_under_depth` and `_under_pattern`, `GanglandRuins.recess`,
`CorporateTowers.recess`, `DeadTowers.recess`, `GoldenFacades.recess`, `GoldenPalaceWalls.recess`,
`CityTowers.recess`); Gangland's is a collapsed stretch (its ruins' end faces and broken tops, the crater floor), the
City's an alley down to the road, and the default (`standard_wall_gap_recess`, in `gap_inside_color` lifted toward grey)
is what the grey box draws. `ZoneSkin.wall_gap_recess_on` (not exported, true) switches the recess off: a cinematic stage whose
def has wall gaps (`CineStage.build`; the City outro's and the Gangland intro's openings onto the skyline and a side
street) draws its track with a copy of the skin that has it off, which also brings the old dark slabs back, so what those
sets build in the openings is exactly what it was. `test_wall_gaps` checks it with software rays (`TriangleMesh`) from where a runner's camera is: every
ray through the opening and at least 3 degrees below the horizontal, along the track, meets a face that faces it; none
escapes to the sky's skyline. Review it with `tools/showcase/wall_gap_review.tscn -- --skin=<zone>` (Review tools).
DESIGN-TBD (items 926-928 in `docs/OPEN_QUESTIONS*.md`): that a gap shows an alley, its depth and its ground.

In a run, a chunk's hooks come over the few frames after its gameplay nodes are built, in order, each
side's `note_wall_enemies` and `wall_section` in one go (`TrackBuilder.dress_budget_usec`, task PERF1;
A run, Smooth frames): a hook never counts on the frame it's called in, and a hazard's look shows the
hazard's state when it binds (`HazardStateVisual.bind`). Tests and review tools dress each chunk at once.

**Zone doodads' looks** (task G5 built the mechanism and a plain default; task G6 gave each zone its
own, except the grey box, which keeps the plain default; since the owner's request of October 9, 2026,
"keep each doodad a simple box but draw on it a picture of the object, with the open air see-through",
every zone draws its doodads as **picture cards**. `GoldenPalaceSkin` (D6b) extends `GoldenSkin` and
doesn't override `doodad()`, so the Golden Palace inherits the Golden Zone's looks, chosen to work
indoors as well as out.) What a look gets and keeps to:
- *The hook*: `doodad(body, size, size_class, side, look_seed)`. `body` is the doodad's node, centred on
  its collision box `size` (width, height, length): the floor is at -size.y / 2 and its front, where the
  player meets it, at +size.z / 2; add meshes as its children. `size_class` is `&"small"`, `&"medium"` or
  `&"large"` (`LevelLayout.DOODAD_SIZES`), whose boxes come from `MovementTuning.doodad_size()`: by
  default 1.3 × 1.4 m, 1.9 × 3.6 m and 2.0 × 6.5 m (width × length), all 2.6 m tall (DESIGN-TBD). Map
  each class to the zone's pieces of that size. `side` is the side it pushes to (-1 left, +1 right) and
  `look_seed` a number to vary the look by, hashed (`MeshKit.hash_i`), never a random number generator,
  so a doodad looks the same wherever and whenever it is built.
- *Inside the box, filling most of it*: what looks like contact is contact (GDD §3), and it must read
  as too tall to jump (it is) and as wide as it blocks. Every look keeps its silhouette near the box's
  full height (a heap may dip at its edges, its middle stays high). Nothing outside the box (an awning, a
  branch, a sign arm): the player would pass through it. Cards lie on planes inside the box by
  construction (below), and every skin suite's `doodads_ok` checks the mesh's bounds.
- *Solid and safe* (CLAUDE.md readability rules): the zone's non-hazard colours, nothing glowing in a
  hazard colour (pink, yellow and black, red, orange, green, cyan), nothing that reads as a sign (no
  striped frames), a fence (nothing strung between posts), a barrier or an enemy (no eyes, no faces on
  screens; the cult's feed is the walls' business). Signs and screens on a doodad are matte paint.
- *Picture cards* (`DoodadCards`, `scripts/world/skins/doodad_cards.gd`): each zone's pictures are
  painted by code (`tools/asset_gen/doodad_art_gen.gd`, run with `tools/godot.sh doodads [--only=a,b]
  [--review]`) on the CPU (`DoodadPaint`: metres on a 4× supersampled canvas, polygons, gradients, soft
  weathering; `DoodadKit`: the shared motifs in the concept art's flat-paint-and-ink style: planks,
  corrugated sheet, wheels, awnings, crates, foliage, see-through window frames, stains) by one script per
  zone (`tools/asset_gen/doodad_art/<zone>_art.gd`), and packed into one atlas per zone,
  `assets/sprites/doodads/<zone>.png` (imported VRAM-compressed with mipmaps, about 2.8 MB a texture
  format: stored lossless they were a few hundred KB, but decoding one cost a 40 ms frame mid-run where
  there's no shader warm-up; `DoodadCards` keeps one zone's in memory at a time, and the web demo leaves
  out the zones it never shows), with a manifest
  `<zone>.json`: where each picture sits, the boxes they were painted for, and each size class's looks.
  A look is a list of cards (`DoodadArtSet`, `tools/asset_gen/doodad_art_set.gd`): `{plane, at, rect,
  image, flip}`, a picture on one of the box's faces (`plane` "z" across the lane, its front at `at` = 1;
  "x" along it; "y" level, the top at 1) or on a plane inside it (a palm's crossed fronds, the goods down
  a stall's middle, a fountain's water arcs, a rubble heap's inner ridges), over the share `rect` of
  that plane. Pictures are drawn as seen from outside, a side's front end on its left; a side seen from
  x- mirrors it (`flip`). Where the object is open (between a stall's counter and roof, a van's empty
  windows, a colonnade's bays) the picture is transparent and the shader drops it (alpha below one half
  is discarded: no sorting, no blending). `DoodadCards.for_zone(zone)` loads a zone once; a look is
  picked from `look_seed`; its mesh (one quad per card) is built once per look and size and shared by
  every instance, on one material per zone (`doodad_card.gdshader`: unshaded with the kit's fake city
  light, double-sided, a soft neutral sheen, `scenery_light` and `scenery_tint` like the scenery, never
  emissive), so a doodad is one draw call, the same on the Compatibility renderer. A zone without a
  manifest, or a size class without a look, falls back to the default (below). Each design keeps its
  main colours in the manifest (`colors`), and its mesh carries them as vertex colours (one a card,
  alpha 0 like the kit's lit colours: never a glow; the card shader ignores them) and as its
  `debris_colors` metadata (`DoodadCards.COLORS_META`), for anything that needs the look's colours (a
  smashed doodad's pieces). After changing `MovementTuning`'s doodad sizes, rerun `tools/godot.sh doodads`
  (`test_doodads` fails until the manifests match the boxes).
- *The default* (`default_doodad_mesh`): a low-poly block in the skin's `doodad_palette` (body, top,
  base) on the plain `MeshKit.solid()`, still used by the grey box and by any new zone before its art: a
  base plinth, an inset body and a top, its front slanting back toward its push side. The skins'
  "Doodads" export groups (other than `doodad_palette`) are unused by the cards.
- *Each zone's own look* (`scripts/world/skins/<zone>/<zone>_doodads.gd` hands the skin's doodads to its
  zone's cards; the pictures are in `tools/asset_gen/doodad_art/<zone>_art.gd`): the Neon City a street
  vending machine or a pillar plastered with posters (small, by seed), a street-food stall with stools,
  a steaming pot and a corrugated roof, open between counter and roof (medium), and a little shop with a
  roll-down shutter, a door, blinds and an unlit sign box (large). Gangland a stack of rusted oil drums
  under a tyre (small), a burned-out van, its windscreen and windows open on a charred cab (medium), and
  a broken-down corrugated shop with a half-open shutter on a dark inside (large). The Marketplace a
  potted palm or a flowering bush in a tiled planter (small), the owner's vendor's stall: a plank
  counter, corner posts, a striped little roof and its goods in the open middle (medium), and a bank of
  slot machines back to back (large). Corporate a steel planter with a clipped topiary (small), a glass
  security booth (medium) and a ribbed olive supply container with stencils (large), the brand colour
  as thin flat paint. The Dead Zone a broken column on its square foot, rebar out of its break (small), a
  heap of rubble, lower at its edges than its middle (medium), and a burned-out bus, its window frames
  open on charred seats (large). The Golden Zone a robed statue on a marble plinth or a gilded urn with
  a clipped topiary (small), a wall fountain with water arcing into a basin either side (medium), and a
  colonnade with red drapes, balustrades and a coffered roof, open between its columns (large). The
  statue is deliberately not the Gilded Sentinels' armoured guard with a halberd (`GoldenStatue`, task
  C4): a plain draped, faceless figure, hands clasped, nothing raised, its front and back on two cards so
  each end shows its own side. `test_golden_skin` guards against the doodad script ever building itself
  from `GoldenStatue`.
- *Its pieces' colours* (task H5: the dash smashes a doodad, and its pieces fly in its look's own colours,
  `RunEffects.rubble`): the hook `doodad_debris_colors(body, size_class, side, look_seed)`, asked right after
  `doodad()` dressed it (TrackBuilder keeps the answer on its `DashBreakable`). By default it reads the main lit
  colours each of the look's meshes carries as its `debris_colors` metadata (`ZoneSkin.DEBRIS_COLORS_META`, the key
  `DoodadCards.COLORS_META` names too): a card look's are its design's main colours from the manifest (`colors`,
  three a look, which its mesh also carries as vertex colours with alpha 0), and the default's are tagged as it's
  built (`ZoneSkin.tag_debris_colors`: `MeshBatch.palette()`, the batch's colours by surface area, glowing faces
  left out, at most four, worked out from the vertices still on the CPU, never read back from a built mesh, which
  would stall a frame); a look that carries none falls back to `doodad_palette`. Lit colours only: the pieces
  never glow. A skin may override the hook, say to leave out part of a look. `test_doodads`' `_test_debris_colors`
  checks every skin's: each colour one of its look's own vertex colours (none glowing), a few a mesh, the same every time.
- *Tested*: `test_doodads`' `_test_skins` builds every skin's doodads in every class (seed 7 alone) and
  checks the box, that nothing glows (the shared `MeshKit.solid()` or a zone's card material,
  `DoodadCards.is_card_material`) and that `doodad_palette` is muted; `_test_cards` loads every zone's
  manifest and checks it was painted for today's boxes, gives each class a look, and that every card
  shows a picture from its atlas on a plane inside the box, and that the card shader never emits light.
  `SkinSuite.doodads_ok(skin, name)` (`tests/helpers/skin_suite.gd`), which every zone's own suite calls,
  extends this over several seeds and both push sides: dressed, inside the box, lit scenery, never
  glowing, and the identical (cached) mesh every time the same size, side and seed are drawn again.

**Dash walls' looks** (task H7a built the hook and a default in every skin; task H7b gave each zone its own,
built from its side-wall kit; GDD §9.14: "the same assets as the side walls, but ... facing towards the player,
looking like a building in the middle of the street"). What a look gets and keeps to:
- *The hook*: `dash_wall(body, size, look_seed)`. `body` is the wall's node (a `DashBreakable`), centred on the
  box its look fills, `size` (width across the track, height, depth along it; `TrackBuilder.dash_wall_size`):
  the floor is at -size.y / 2, its face toward the oncoming runner at +size.z / 2, and its sides stop short of
  the side walls by the strip a wall runner passes it in (`MovementTuning.dash_wall_wall_room`, 1.2 m). By
  default 5.4, 10.2 and 12.6 m wide at 3, 5 and 6 lanes, 9 m tall, 2.5 m deep (DESIGN-TBD). `look_seed` varies the look
  (the same seed, the same look; `MeshKit.hash_i`, never a random number generator). Add everything as
  children of `body`, never top-level: the break hides `body` whole (`DashBreakable.smash`).
- *Inside the box, filling its face*: its hitbox is the box 0.15 m smaller at its sides and its face
  (`dash_wall_inset`, forgiving), so what looks like contact is contact, and the open strip beside each side
  wall shows that a wall runner passes it. Nothing outside the box (an awning, a sign arm, a balcony).
- *A building's face, solid and safe*: it reads as something to dash through (cracks or a breakable look are
  welcome), with nothing in a hazard colour that glows (pink, yellow and black, red, orange, green, cyan) and
  nothing that reads as a sign, a fence, a barrier's stripes or an enemy. A cue, if any, in the dash's own
  language (`PlayerSuit.GLOW_PALE`), never a hazard's; nothing that flickers (or it honours Reduced flashing).
- *Cheap*: one mesh per wall from cached templates (the kit's `MeshBatch`), drawn on the Compatibility renderer;
  ShaderWarmup draws one at the load (look seed 0, the level's size).
- *Its materials*: the surfaces of a look's mesh draw with materials the skin names in `dash_wall_materials()`
  (default `MeshKit.solid()` and `dash_wall_material()`, the zone's own `solid_material()` where it has one): a
  zone that builds its wall from its facade shader lists that too (the City, Corporate, Gangland, the Marketplace
  and the Golden Zone: `[solid_material(), facade_material()]`; the Dead Zone and the Golden Palace draw on the
  solid kit alone). Every vertex has `COLOR.a` 0: no lit window, no ember, no fire, no bulb (a facade shader's
  flicker, embers and chasing lights are all behind that share, or above the heights a wall reaches), so a wall
  never flickers and Reduced flashing changes nothing about it.
- *Its pieces' colours*: `dash_wall_debris_colors(body, look_seed)`, asked right after `dash_wall()` dressed
  it (TrackBuilder keeps the answer on the `DashBreakable`; `RunEffects.crumble` flings its pieces in them): by
  default the colours its meshes were tagged with (`tag_debris_colors`, which `DashWallKit.finish` does), else its
  walls' and trim's. Lit colours only: the pieces never glow.
- *Each zone's look* (`scripts/world/skins/<zone>/<zone>_dash_wall.gd`, a builder the skin owns like its towers and
  doodads, `mesh_for(size, look_seed)` caching one mesh per size, layout and tone): four layouts by `look_seed % 4`
  and three tones by `look_seed / 4 % 3`, each a block with depth (the facade set back from the box's face, its
  piers, cornice and canopies standing out to it, its sides in the zone's material, a little roof plant on its top
  where it is a roofed building), cracks and a chipped patch with rebar as the "this breaks" cue (the two Golden
  zones' walls have cracks only: no fallen patch in the elite's marble), in the zone's own
  facade styles and solid patterns, colours and motifs (nothing that is a sign or an enemy: no banner, screen,
  statue, billboard, laundry or bulb):
  Corporate (`CorporateDashWall`: a curtain-wall tower's foot, a lobby, a military compound's front, a podium
  building), the Dead Zone (`DeadDashWall`: a burnt tower's foot, a skeleton, a blast with its rubble, a bunker),
  the Golden Zone (`GoldenDashWall`: a rusticated palace, windows, a mirror-glass tower's foot, a gatehouse), the
  Golden Palace (`GoldenPalaceDashWall`: a pilastered marble block, galleries, arched windows, a hall block),
  the City (`CityDashWall`: its four window grids), Gangland (`GanglandDashWall`: a ruined block, a balcony block, a
  patched shop, a collapsed corner) and the Marketplace (`MarketDashWall`: two shop rows, a market hall, an arcade;
  the Casino's skin inherits it in its iron tones, its tone picks wrapped to the Casino's shorter palette: walls
  never stand in the Casino, item 678). The Beach keeps the default look (no walls there for now: item 680).
  What they share is `DashWallKit` (`scripts/world/skins/dash_wall_kit.gd`): the helpers that lay things in the box
  by height above the floor (`box`, `face`, `bay_faces` for whole windows and arches, `face_profile` and
  `broken_profile` for broken tops, `column`, `frame_rect`, `arch_head`, `finials`, `roof_plant`), `cracks` and
  `spall`, and `dress`, which puts a cached mesh on the node. The hook's default (`default_dash_wall_mesh`) now only
  serves the grey box and a skin without a look of its own (`dash_wall_colors()` is the palette it and the debris
  fall back on).
- *Review*: `tools/showcase/dash_wall_review.tscn -- --take=look|smash|crash|pass --skin=<zone> [--seed=N]`: `look`
  holds a camera still in front of the first wall (`--seed=0` to `3` shows each layout in turn), the others run the
  real world through the game's camera.
- *Tested*: `test_dash_walls`' `_test_skins` builds every skin's wall at 3 and 6 lanes over five seeds: under its
  node, inside its box and filling its face, every vertex unlit and every surface on a material the skin names,
  the same mesh for the same box and seed, a few looks, one small mesh (at most 3 surfaces and 8000 vertices), its
  pieces' colours its look's own, every zone having a look of its own, and every look built in a moment.

**Floor cuts' looks** (B4; GDD §9.9: the floor a cut takes "becomes a gap ... The cut edges glow the
usual gap-edge orange"). The track draws a cut lane's floor itself, in slices of the skin's own
`floor_segment` it hides and shortens as the cut runs (The generator, Floor cuts on the track), so the
hook `floor_cut(parent, cut)` draws only the hole, from a `FloorCutSection`
(`scripts/world/floor_cut_section.gd`: the lane, its floor's edges, the stretch, the wall faces) in four
kinds of part the cut then moves: `add_static` (the inside over the whole stretch, below the floor,
never moved), `add_span` (the orange lips along the neighbouring lanes' edges, built over the whole
stretch and scaled to what's cut), `add_front` (the lip on the whole floor's far edge, moved with the
front) and `add_far` (the far side: the lip on the floor beyond, a strip along its face, a halo). It
must read as a hole at a glance like any gap: orange edges right on the collision edge, a dark inside,
nothing else glowing, nothing flickering. `ZoneSkin.standard_floor_cut(parent, cut, solid, glow, style)`
builds all of it from a style (the edge and inside colours, the inside's darkening pattern, depth, lip
sizes and glows, a dark line beside the lips, the inside's walls and ribs); the default hook uses it
with the skin's `gap_edge_color` and `gap_inside_color`, and only the grey box and the plain `ZoneSkin`
keep it (no zone scenery below them to show: its box has a bottom of its own). Every zone draws its own
floor's cut: Corporate's maglev a carriage roof sliced open down to its frame (`CorporateTrains.cut`),
its plaza the deck split over the lower level (`CorporatePlaza.cut`), the Dead Zone's street split with
broken plates hanging into the void (`DeadStreet.cut`), the Golden Zone's walkway cut over the canal
(`GoldenWalkways.cut`), the Golden Palace's marble floor broken into the well (`GoldenPalaceFloor.cut`),
and, since task H3, the City's hover truck sliced open over the road (`CitySkin.floor_cut`), Gangland's
street split into the strata (`GanglandSkin.floor_cut`) and the Marketplace's stall roofs opened onto the
stalls' shade (`MarketplaceSkin.floor_cut`). A skin whose cuts' cause draws the hole itself
leaves the hook empty: the Grand Court's (`GoldenCourtSkin`: the Golden Convergence's Fist Slam opens a row's hole at
its impact, `GoldenConvergenceHole.open`, so a row costs little until it opens).

*What a cut shows below the street* (task H3; GDD §9.9, the owner, October 8, 2026: "bottoms of buzzsaw
cuts/gaps in the floor should show a zone specific background": "inside the cut, the player sees the zone's
own scenery below the street, the same as through an ordinary gap ... never a dark box"). A gap shows
the zone's own plane far below the street (the City's road with its traffic, Gangland's crater floor, the
market floor, the trench under the maglev with its guideway, the plaza's lower level, the Dead Zone's
void, the canal, the palace's well), drawn once per chunk with the left wall's mesh (`wall_section` and
`wall_gap`, `side < 0`, across the whole street and the whole chunk, so it lies under every lane and
every cut), between the sides the neighbouring lanes' own floors draw down to it. A cut is the same
hole, so it follows two rules: **it draws no bottom** (`bottom: false`, whatever the skin: the plane is
the bottom, `test_floor_cuts`' `_check_below` casts rays down every skin's open cut and holds each to
meet a plane deep below, never the cut's own face), and **it doesn't copy what the neighbours already
draw**: the long side walls are left to the neighbouring lanes' own sides (`walls: false`, the style the
City, Gangland and the Marketplace set; the Corporate, Dead Zone and Golden looks keep walls of their
own because they're the same shade and pattern as those sides, and Hostile Takeover's train, one wide
roof with no sides between its lanes, needs its walls). Only the two end faces, which the next piece
of floor doesn't draw, stay: in the gap's own shade and pattern, and no deeper than the floor itself
goes (`end_depth`: a hover truck is 2.6 m tall with the road 14 m below). A zone's cut must therefore
look like its gap with the orange edges added: in the City the road and its traffic between the trucks'
own ribbed sides, in Gangland the strata walls, in the Marketplace the stalls' brown shade. Compare them
with `floor_cut_review --compare` (Review tools).

*What the zones show there* (task H3's second part, the coordinator's decision: matching the gap was not enough
where the planes below were drawn almost black; the owner's "never a dark box" wants the zone's scenery
recognisable from the runner's camera, in gaps and cuts alike). The runner's camera looks along the track, so
what it sees of a hole is mostly the far end face of a gap and the first few metres of a long hole's walls,
and the bottom only from nearby or above: the scenery is on the faces first, the plane second. Each look is
one pattern in the solid kit, steady (nothing flashes: no Reduced flashing case) and all albedo (nothing
glows), `COLOR` its peak and the result capped at it (plus, for the quay and the water, exactly the sky's and
the lamps' colours), and the zone's `kit_solid` sheen is cut to a quarter below the street (`sheen_k`,
patterns 31, 41, 53, 54, 71) so it never drowns them at a hole's grazing walls. On the Compatibility renderer
alone the same patterns are lifted by `UNDER_COMPAT_GAMMA` (0.85): it shows dark values darker than Forward+
(the same colours drew as near-black), and the lift brings the holes to within a few luma points of
Forward+'s, never past it.
- *Golden Zone* (`PAT_UNDERDECK`, `PAT_CANAL`): a stone quay of round arches on piers, one a lane across an
  end face and one every two lanes along a side, the canal's light wavering on the stone and shimmering in
  the arches toward the water, and the water below, ripples sliding with the current, the dusk's sky
  laid on it more the lower the eye (a sheen and glints) and the walkways' lamps wavering on it
  (`canal_sky_color`, `canal_lamp_color`).
- *Golden Palace* (`PAT_PALACE_WELL`): a stairwell, its steps descending along a side in treads and
  risers, and far below the lower hall's marble in slabs with a soft pool of light every 22 m
  (`well_floor_color`, with the well's side walls now drawn down both sides, so a hole in an outer lane
  shows stone and not the hall's outside). DESIGN-TBD (docs/OPEN_QUESTIONS.md item 641).
- *Corporate* (`PAT_CORP_UNDER`): a carriage's side with its band of dim cold windows, the guideway beams
  on their piers with a lighter top edge (`guideway_color`) over a wet concrete trench with joints and
  puddles (`trench_color`) and the trench's retaining walls (mode 5: they, and the plaza's lower-level walls,
  were built facing away from the street and never drew; they face it now); the plaza's deck edge a slab with
  a pale fascia over a lower level of painted bays, 9 m down in the data (`trench_depth`, 18 m for the
  trains). Hostile Takeover's arena (`HostileTakeoverSkin` extends `CorporateSkin`) inherits the gap look: its
  carriage ends, its guideway colour and the cut through its train (its moving street below is its own).
- *Dead Zone* (`PAT_DZ_UNDER`): the road's broken layers and rebar, then the ruined basements, concrete
  with formwork courses, a row of dark window slots under pale lintels, a pilaster between bays, a pipe run
  and ash on the sills, a slope of rubble blocks at the foot, and far down (`void_floor_color`) a rubble
  floor with paler slabs and pale ash in its cracks: greys only (the first build's embers sat at the gap
  edge's hue and were dropped).
The hole must still read as a hole at a glance. `SkinSuite.hole_share()` (`tests/helpers/skin_suite.gd`)
holds each zone to it with the true peaks of its patterns: the brightest thing drawn below the street,
rendered (the kit lights a wall's side 0.70 and a face seen from above 0.92), over the darkest the street
is drawn, rendered, must be at most `HOLE_SHARE_MAX` (0.8); each suite prints its share (Corporate 0.70,
Golden 0.72, Dead Zone 0.75, Golden Palace 0.22). Nothing glows below but the orange edges, the cut is never
brighter than the zone's gap (`test_floor_cuts`' `_inside_limit`) nor, in these five skins, black (the
plane an open cut's ray meets is at least `BELOW_MIN_LUMINANCE`). The trade-off for the owner to confirm is
in docs/OPEN_QUESTIONS.md, item 641.

`test_floor_cuts` builds every skin in `data/skins/` (and Hostile Takeover's train, the grey box and the
plain `ZoneSkin`) at 3 and 5 lanes, in an outer and a middle lane, and checks the orange edges on the
collision edge, a dark inside, nothing else glowing, and the build cost against the same chunks without a
cut, and opens each zone's cut to cast rays down it (above); review a new look with `floor_cut_review`
(Review tools) on both renderers.

**Wall fences' looks** (B5; GDD §9.1: "the same pink crackle, strung across the wall-run path between emitters
on the facade, the way a floor fence crosses a lane"). The hook `wall_fence(hazard, size, side, band, floor_y)`
draws one in hazard-local space, centred on its hitbox `size` (x from the wall face on `side` out toward the
lanes, y up its band, z along the track), and `band` (&"full", &"low", &"high") says which part of the wall it
covers. It must read as the floor fence turned onto the wall, in every zone: the same pink field (the zone's
`fence_field_materials()`), an emitter at each end of its band on the facade whose glowing strip marks the
band's edge (the line a partial one is passed above or below), nothing else glowing, the look within the
field's reach of the facade (never out over the outer lane's runner), following the hazard's state (ON,
WARNING with the flicker, OFF with no field: `HazardStateVisual`, steady with Reduced flashing as the fence
shaders are). The default (`standard_wall_fence`) works for every zone, the grey box included:
`MeshKit.dress_wall_fence` with `wall_field_mesh` (three cards through the field's depth, UV.x up the band so the
energy field shader's arcs run from one emitter to the other, its bright edges along the facade and along the
field's outer edge) and `wall_fence_mounts` (a plate on the facade and an arm out over the field at each end of
the band, a sill at the foot of the wall for a band that starts at the floor, in `wall_fence_mount_color`, an
export on ZoneSkin, with the zone's `fence_part_materials()` for the glowing strips and caps and its
`solid_material()` for the housings; `wall_fence_look()` falls back to the kit's own materials and pink for a
skin without them). A zone may override `wall_fence()` to draw its own emitters around the same field.
`test_wall_fences` builds every skin in `data/skins/` (and the grey box) at 3 and 5 lanes on both walls in every
band; review a look with `wall_fence_review` (Review tools) on both renderers.

**Ceiling fences' and return pads' looks** (task I4; GDD §3, "Ceiling scenarios"). The hook
`ceiling_fence(hazard, size)` draws a fenced ceiling's fence in hazard-local space, centred on its hitbox `size` (x
across the lane, y down from the underside at +size.y / 2, z along the track). It must read as the floor fence's pink
crackle hung from the ceiling, in every zone, from the floor before the pad that lifts a rider into it: the zone's
fence field (`wall_fence_look()`) on `MeshKit.dress_fence`, held by an emitter along the underside
(`ceiling_fence_mounts`: a housing flush with it in `wall_fence_mount_color`, a glowing strip toward the field and a
glowing cap at each end, with the zone's fence part materials), nothing else glowing, nothing below the field (the
chase camera passes just below it) and nothing past its lane; following the hazard's state (an EMP's OFF) and steady
with Reduced flashing, as the fence shaders are. The default (`standard_ceiling_fence`) works for every zone; a zone
may override `ceiling_fence()` to draw its own emitter around the same field. `return_pad(trigger, size)` dresses a
treasure stash's return pad: the track turns the trigger upside down, so the default, the zone's own `pad()`, points
back down at the floor (GDD §3: it looks safe, with no hazard colour). `test_ceiling_scenarios` dresses both with
every skin in `data/skins/` and the grey box.

**Ceilings from their lanes** (B3). `TrackBuilder` (and `BossProps.ceiling`) describe each ceiling as a
`CeilingSection` (`scripts/world/ceiling_section.gd`): its span along the track, the lanes it covers
(`first_lane`, `last_lane`, `full()`), its collision box (`center`, `size`), the lane seams inside it
(`lane_edges_x`), the wall faces' distance (`wall_x`) and whether each side reaches the street's edge
(`reaches_wall(side)`), and hand it to `ceiling_section(parent, section)`. A skin builds the ceiling from
those, never from the track's width, so a narrow ceiling is simply a narrower one: the City's is a smaller
craft (`CityShip`, `small`), Gangland's a slab broken off a building, the Dead Zone's a slab broken off
the tower it reaches or a fallen span, and the Marketplace's, Corporate zone's and Golden Zone's kinds
build narrower (a structure that needs both walls, the Marketplace's building bridge, the Corporate
tower across the street, the Golden arches, becomes another kind over fewer lanes). The default hook
calls the older `hull(center, size, lane_edges_x)`, which the grey box still uses. Every ceiling's underside covers its footprint and stops at a free side's edge, nothing hangs
below it, and the orange end band (`MeshKit.ceiling_end`) spans its width.

**Nothing below the underside past a far end.** When the player drops off a ceiling's far end, the chase
camera follows them down and passes just below the underside there: `RunCamera.ceiling_limit` keeps it
`camera_ceiling_clearance` (1 m) under any ceiling over it, beside it (a narrow one), just ahead or just
behind (the review tools' camera copies use it too). Whatever a skin draws below the underside past the
far end fills the screen for a frame as the camera passes (task B3 found the end band's glow card doing
it in every zone: an orange wash and a glare), so past a far end glows and faces stay above the
underside: use `MeshKit.ceiling_end` for the band, `MeshKit.stern_halo` for an engine's halo (cut at the
underside), and `MeshKit.near_fade(metres)` as a glow card's `param` for any other glow the camera
passes close to (kit_glow reads a negative UV2.y as "fade out within this many metres of the camera").
`test_ceilings` builds every skin in `data/skins/` (and the City boss arena's) over full and narrow
ranges at 3, 5 and 6 lanes and checks all of this, so every zone's skin is held to it, and a new skin
(a level's own, such as the Golden Palace's) as soon as its file exists: build ceilings through
`ceiling_section` (or `hull`) from the section, keep the band and every glow past the far end above the
underside, and check the drop on both renderers (`skin_review --narrow`, Review tools).

**The climbing view** (task E5e-a, for GDD §10's climb: the camera follows the runner up). The run camera
follows only `camera_follow_y` (0.45) of the runner's height and sees a ceiling from below at a fixed
`camera_ceiling_height`, so 25-30 m up the runner would leave the top of the screen and, under a high
ceiling, the camera would sit inside the roof below it. A boss turns on `RunWorld.camera_climbs` (off in
every level and every other boss fight, where the camera is exactly as it was): the usual framing is kept
to the floor the runner is on or came from (`Player.floor_y`) instead of the street, and on a ceiling the
usual view from below is kept to that ceiling's own height (`Player.ceiling_y`; `RunCamera._climb_aim`).
It never sits inside a roof: `RunCamera.floor_limit` keeps it `camera_floor_clearance` above any floor-layer
top within `CEILING_SIDE` to either side, from `CEILING_BEHIND` behind to some way ahead, whose top is up to
`FLOOR_REACH` above it, but not one it's beneath (a raised slab it passes under: a ray up meets its
underside). The camera eases toward a height that clears a roof `camera_climb_lead` seconds of running
ahead, so it rises over the higher roof a ceiling rider will drop onto before it gets there, and is held
above any roof right at it. `ceiling_limit` holds as always and wins where both can't be kept. Every target
is eased as before, so a ride up to a ceiling and a landing on a higher roof never snap the view. The roof
check is one pass over its samples a frame with the camera's own ray queries (`floor_limits`; the static
`floor_limit` is the same for tools and tests), so it allocates no query objects. The same switch turns
on two other climb looks: the runner's blob shadow lies on the floor under them (`Player.shadow_on_floor`,
set by `camera_climbs`' setter) instead of at the street's level, where it stays in every level, under a
hover truck's roof or a boss's deck as it always was; and a landing's shake measures the fall down to the
floor landed on, not from the street (`RunEffects`). `test_climb` climbs five steps to a roof 30 m up at
3, 5 and 6 lanes and checks the runner stays on screen, the camera is never in a roof and keeps under every
ceiling, and never moves more than 0.4 m in a frame (0.30 m at most measured); without the climbing view
the runner leaves the screen up there.

Skins: `CitySkin` (Zone 1, the Neon City), `GanglandSkin` (Zone 2), `MarketplaceSkin`
(Zone 3, the Marketplace), `CasinoSkin` (Zone 4, the Casino, task K1), `CorporateSkin` (Zone 5,
Corporate), `BeachSkin` (Zone 6, the Beach; task D10, in the campaign since D10c), `DeadZoneSkin` (Zone 7, the
Dead Zone) and `GoldenSkin` (Zone 8, the Golden Zone). `GreyboxSkin` is the fallback for a zone without its own
look (every zone has one now). A
zone's skin lives at `data/skins/<zone id>_skin.tres` (`--skin=<zone id>` in quick play) and is set in its
`data/zones/<zone id>.tres`; a level's own `skin` wins over its zone's (the Golden Palace, Golden 3,
task D6b, has one: `GoldenPalaceSkin`, below). The real skins build on the mesh kit
(`scripts/world/meshes/`): `MeshKit` has shared builders for hazards, triggers and environments, and
`MeshLayer` batches a chunk's geometry.
The shaders in `scripts/world/meshes/shaders/` are procedural. `HazardStateVisual` swaps a hazard's
ON / WARNING / OFF materials. A skin's `enemy_variant` picks the enemies' look: the cyborgs' zone
variant (GDD §9.2, through `CyborgSuit.look_for()`) and the other enemies' weathering (drones, hover
trucks, Octodogs and screeches weather on `&"scavenger"` and stay clean on anything else). Each zone's
value, the one thing a new zone's skin sets for its enemies:

| Zone | `enemy_variant` | Cyborgs | Other enemies |
|---|---|---|---|
| Neon City | `&"city"` | the base (Static TV Head) | clean |
| Gangland | `&"scavenger"` | the Broadcast Brute | weathered |
| Marketplace | `&"casino"` | the Casino Mob Enforcer | clean |
| Casino (K1) | `&"casino"` | the Casino Mob Enforcer (the owner: no new character looks) | clean |
| Corporate (D4) | `&"vr_runner"` | the Wide-Aspect VR Runner | clean |
| Dead Zone (D5) | `&"burned"` | the base, burned out | clean |
| Golden Zone (D6a) | `&"golden"` | the ceremonial enforcer | clean |
| Beach (D10) | `&"casino"` | the Casino Mob Enforcer | clean |

A skin's `cyborg_draw_scale` (the class default 1.0; 1.2 in every zone skin and boss-arena skin: the Neon City in task I2,
the rest in J1; DESIGN-TBD item 829) draws that zone's cyborgs bigger without touching
a hitbox (`docs/architecture/enemies.md`, the cyborgs' look).

The Barnacle Turret wears its furry creature look on `&"scavenger"` and `&"casino"` (Gangland, the
Marketplace, the Casino and the Beach) and its mechanical look on every other value (`BarnacleTurretModel.is_creature`), with its
colours from the zone variant (`BarnacleTurretModel.PALETTES`; a new zone's variant gets the default
gunmetal until it has its own).

The City and Gangland keep their older names because they also pick the other enemies' weathering
(`CyborgSuit.VARIANT_LOOKS` maps them); every other zone sets its cyborg look's own name. A zone that
also wants the weathered enemies (the Dead Zone might) needs those enemies to treat its name like
`&"scavenger"` (a line in each one's look code). A zone on the grey box wears the base; `--variant=` in
the enemy showcase shows any look now.

**A level's darker lighting** (`LevelConfig.darkness`, 0–1; GDD §5, The Hush) reaches every skin for
free: the run takes its environment from `ZoneSkin.level_environment(darkness)`, whose
`apply_darkness()` dims only the scenery. The sky and the distance fog lose energy, and the global
shader uniform `scenery_light` (project.godot; 1 = the zone's own light, never below
`MIN_SCENERY_LIGHT`, 0.3) dims what the scenery's shaders draw: `kit_solid`'s lit surfaces (never its
glowing ones), `facade`, `shopfront`, `road`, `drift`, the Casino's `casino_facade`, the Corporate skin's
`corp_facade`, the Golden Zone's `golden_facade`, the Dead Zone's `dead_smoke`, and the grey box's floor, walls and ceilings (`GreyboxMaterials.scenery()`). Glows, the ambient light and the
sun stay, so hazards, triggers, credits, enemies and the runner (lit or glowing by their own
materials) read as well as anywhere. The
factor is given for linear space; `light_factor()` in `kit_common.gdshaderinc` (and
`ZoneSkin.energy_factor()` for the environment) converts it for the Compatibility renderer's sRGB
space, so both renderers dim alike. A new skin gets it by drawing its scenery with the kit, or by
reading `scenery_light` (through `light_factor`) in a shader of its own, or by overriding
`apply_darkness()` (calling it first). A scenery shader of its own also multiplies its lit colour by
`scenery_tint` right after (a level sky's street light; `test_level_sky` checks every shader that reads
`scenery_light` does). Only the run that set the light last resets it when it ends
(`LevelRun`). `skin_review` takes `--darkness=X` to look at it.

**A level's own sky** (`LevelConfig.sky`, a `LevelSky` in `data/skies/`; owner, October 8, 2026). Most
levels keep their zone's sky; a few show the time of day or the weather turning, for a sense of
progression: City 1 a dawn (`city_dawn`: the sun about to rise, pinks and purples on the undersides of
clouds), Gangland 3 a cloudy blood-red sky (`gangland_blood_red`), Marketplace 2, the zone's last level,
a sunset (`marketplace_sunset`: deep blue overhead, pink at the bottom of the sky). The boss fight after a
level keeps that level's sky (`Campaign.configure_boss`, unless the arena has its own), so the Sewer Swarm
fights under Gangland 3's and The House under Marketplace 2's.
`ZoneSkin.level_environment(darkness, sky)` builds the zone's environment, then `LevelSky.apply()` sets
the sky's `night_sky.gdshader` uniforms over the zone's (by name; its colours go as sRGB `Vector3`s, as the
Dead Zone's do, so both renderers draw them alike) and the distance fog's colour (so far scenery fades
into that sky), and `ZoneSkin.set_scenery_tint()` sets the street's light under it (`LevelSky.scenery_tint`,
white without a level sky); the darkness comes after, as for any level. The tint is the global shader
uniform `scenery_tint` (project.godot, a `vec3`): every scenery shader that follows a level's darkness
multiplies its lit colour by it right after `light_factor(scenery_light)` (one multiply per pixel; the
Compatibility renderer's sRGB equivalent is worked out once in `set_scenery_tint()`, not per pixel), and
no glow, hazard, enemy or runner shader reads it. A boss model built from the kit's solid shader (The
House's cabinet, the Swarm Host's body and pipe) takes it as a level's darkness reaches it; its glowing
parts don't (open question 406). A tint only dims or tints (each channel at most 1), and
the run puts it back to white when it ends (`LevelRun`). Nothing else changes: the ambient light, the sun,
every glow and the fog's reach stay the zone's, so hazards read as in the zone's other levels, and a sky
stays under the glow threshold, so it never blooms (`test_level_sky`). The zone's own environment is
never touched (each `make_environment()` builds its own sky material). The sky shader's looks for a level
sky all default to off, so no zone's own sky changes: `horizon_falloff` (0.55: how far down the zenith's
colour reaches), a glow low over the horizon at a bearing (`sun_glow_*`, where the sun is about to rise
or has just set), and a cloud layer (`cloud_*`: value-noise cloud on a plane overhead, receding to a thin
band at the horizon and stretched across the street; its undersides catch `cloud_lit_color`, the more so
toward `sun_glow_direction` by `cloud_lit_focus` (0: lit from all around, as by Gangland's fires), on the
lower clouds, on their thin edges and on each cloud's side facing the light). The clouds cost six octaves
of value noise per visible sky pixel, only where a level has them; no `TIME`, so the sky's radiance still
never updates. Endless mode, which copies its zone's last level, keeps the zone's own sky and light
(`App.start_endless`), as do a zone's intro and outro (open question 405); a boss's intro (the Sewer
Swarm's) is under the fight's sky, so the sky holds from the level through the intro to the fight (open
question 404) (`CineStage.sky_for`, the
arena's own or the zone's last level's; `CineStage.build` passes it to `level_environment(0.0, sky)`).
`skin_review` takes `--sky=name` to look at one.

The kit's solid shader (`kit_solid.gdshader`) draws surface patterns chosen per vertex (`MeshKit.PAT_*`):
panels, glass, glyphs and chevrons for the City; worn asphalt (with sand drifts and scorch around holes),
road strata, salvaged plating, posters (with corporate ads), cast concrete and stencilled crates and
container doors for Gangland; canvas, tin and whole rows of stall roofs, stall faces, tiles, shop
signs, ads, casino bulbs and stucco for the Marketplace; train roofs, the shade below them, paving,
armour plate, corporate ads, the brand's mark on panels, banners and lit glass for Corporate; the
rubble street, the shade below it, gutted towers, charred concrete, scorched steel, dead boards and the
scorched emblem for the Dead Zone; reflective gold, golden walkways, marble, the shade under the walkways, the canal, falling water, the
cult's emblem in relief, gilded coffers, red cloth and boutique boards for the Golden Zone. Features
a zone opts into are uniforms that default to off, so one zone's additions never change another's
look. Painted marks shared between shaders live in includes: `kit_marks.gdshaderinc` (graffiti pieces
and tags, stencil codes) and `kit_logo.gdshaderinc` (`corp_logo()`, the Corporate brand's mark, which
Gangland's corporate crates, containers and ads carry too). Two shader rules: take derivatives
(`fwidth`, implicit texture LODs) outside any branch that can differ between neighbouring pixels and
pass them in, and use `filtered_pulse()` only for ranges within 0–1 (`band()` for any other). Breaking
either can put a NaN in a pixel, and the glow pass blows it up into a white disc.

**Colours in a skin's own uniforms.** A `Color` set on a `vec3` shader uniform reaches the shader
already converted to linear on Forward+ and Mobile, but unconverted on the Compatibility renderer, so a
shader that converts it once more (`to_linear()`, as the kit's do for vertex colours) draws it darker and
more saturated on Forward+ than on the web. The Golden Zone passes its uniform colours as sRGB `Vector3`s
(`GoldenSkin.srgb()`), which arrive unconverted on both renderers and are converted once, like a vertex
colour; the Dead Zone does the same (`DeadZoneSkin.srgb()`, its `dz_*` uniforms and its sky). Likewise
a light factor multiplied in after `to_linear()` scales sRGB values on the
Compatibility renderer; `golden_facade.gdshader` passes every one of its light factors through
`light_factor()` (kit_common), which raises it to the 1/2.2 power there, so its walls are as bright on
both renderers. (The older skins' uniform colours, and the kit's own `shade` factor, still differ a little
between the renderers.)

**Pattern ids.** Ids up to 19 are the City's and Gangland's, in `kit_solid.gdshader` itself; ids 20-29
are the Marketplace's (all in use), in `kit_market.gdshaderinc`, and ids 30-39 the Corporate zone's
(30-37 in use), in `kit_corporate.gdshaderinc`, ids 40-49 the Dead Zone's (40-46 in use), in
`kit_dead_zone.gdshaderinc`, and ids 50-59 the Golden Zone's (all in use), in
`kit_golden.gdshaderinc` (each: one include and one dispatch line in `kit_solid`; the Golden Zone's
and the Dead Zone's includes follow `cult_mark()`, which their emblems use).
A new zone takes the next free block of ten in its own include, so zones built in parallel never
collide on an id. Ids 60-69 are the cult's, shared by every zone, in
`kit_cult.gdshaderinc` (its include follows `cult_mark()` in `kit_solid`, and its dispatch runs after
the zones' own): `PAT_CULT_MARK` (60) draws the cult's emblem from the material's `cult_emblem`
texture as a mark on a dark panel. Ids 70-79 are the Golden Palace's (task D6b, a level's own skin,
not a zone's), in `kit_golden_palace.gdshaderinc`, after `kit_golden.gdshaderinc`'s `golden_metal()`
and `golden_marble()`, which it calls directly. Ids 80-89 are the Casino's (task K1; 80-86 in use), in
`kit_casino.gdshaderinc`: the street's paving (`PAT_CASINO_STREET`), everything under it
(`PAT_CASINO_UNDER`), dark iron and aged brass (`PAT_CASINO_IRON`, `PAT_CASINO_BRASS`, lit through
`cas_metal()`, a fake reflection of the lamplit street), a pane of the glass roof (`PAT_CASINO_VAULT`), a lit
sign (`PAT_CASINO_SIGN`) and a hanging banner (`PAT_CASINO_BANNER`). Ids 90-99 are the Beach's (task D10, all in use), in
`kit_beach.gdshaderinc` (`MeshKit.PAT_BEACH_*`: sand, boardwalk, tank, water, wall, thatch, steel, painted
board, neon silhouette, timber), after `kit_marks.gdshaderinc`'s `band()` and `sd_*()`. A pattern's parameter
(`UV2.y`) is interpolated across a face, and a rasterizer's interpolation of a constant can be a few units in
the last place off (Mesa's llvmpipe and lavapipe are): a decoder that takes `floor(param / 8.0)` of an exact
multiple of 8 flips between two neighbouring values pixel by pixel (the Beach's first walls were a lattice of
dots), and a parameter above about 2^20 has units in the last place of 0.06 or more. So decode by rounding
to the nearest whole number (`floor(x + 0.5)`, or a half step added before a `floor`) and keep every
parameter under 2^20 (`MeshKit.sand_param()`, `beach_art_param()` and the others do; `test_beach_skin` pins it).

**Gangland's ceilings** (`GanglandCeiling`) take their width from the lanes they cover (the collision
box), never from the track, and draw each side as anchored (running into the building face) or free
(an edge face). A ceiling across the street is an overpass or a bombed-out building (`kind_of`, by
hashing its start); a narrow one (B3) is always a slab broken off a building (`Kind.SLAB`, the owner's
review P2 18): broken edges with rebar, rubble, column stubs and a piece of wall on it, lodged in the
building face on a side that reaches the street's edge, or hung from its building's torn steel frame
running up to both building faces when it reaches neither (`GanglandSkin.ceiling_section` passes which
sides reach a wall, and the walls' distance). Whatever the structure, the running surface is a flat
slab with lamps on every lane seam, nothing hangs below it, and its far end carries the orange band
(`MeshKit.ceiling_end`, as in every zone).
