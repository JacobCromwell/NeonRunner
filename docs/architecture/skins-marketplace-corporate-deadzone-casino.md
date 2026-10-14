# Architecture: Zone skins: the Marketplace, Corporate, the Dead Zone, the Casino

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Zone skins (continued)

**The Marketplace** (`scripts/world/skins/marketplace/`): `MarketStalls` (the floor), `MarketFacades`
(the walls, and the pennants and festoon lights across the street), `MarketCeilings` and `MarketProps`
(fences and signs); its building faces use their own shader, `shopfront.gdshader`.
- *The stall floor is laid out on the GPU.* A lane piece's roofs are one quad with `PAT_STALLS`: the
  shader finds each point's stall from its track position (slots along the lane, runs of 1-3 slots)
  and draws its roof, hem and frame pole. `kit_hash_u()` in the include is `MeshKit.hash_i` bit for
  bit, so `MarketStalls.stall_at()` and `roof_of()` reproduce the shader's choices. Anything that
  must match the shader's layout goes through those two.
- *Gaps read as holes.* Everything under the roofs (stall faces, building faces, the market floor)
  is drawn with `PAT_UNDER` in the skin's `gap_inside_color`, a deep shade that only darkens with
  depth, and nothing under the roofs is lit or glows but the orange edge strip. The suite pins it
  (far darker than any roof, no roof in the edge colour).
- *Shop windows for the citizens (task D3).* Every shopfront has a row of real window openings with
  lit displays at the low part of the wall (0.85-2.8 m above the floor, above the wall vents' zone).
  `MarketplaceSkin.shop_windows(side, face_x, start, end)` lists the windows whose centres lie
  between two track distances (position on the glass, width, bottom, top, depth into the building,
  kind), computed from track positions alone, so it can be asked before or after a chunk exists.
  Citizens stand inside, between the glass plane and `face_x + side * depth`.
- *The Marketplace citizens (task D3, GDD §5 "Citizens"; scenery only, never real 3D characters).*
  `tools/asset_gen/citizen_sheet_gen.gd` bakes a few archetypes (`CitizenRig`, on the same shared
  `HumanoidRig` the player and cyborgs use, GDD §9.2) into flipbook sprite sheets
  (`CitizenSheet`: a fixed grid, one row per clip: idle, startled, cheer) at
  `assets/sprites/citizens/*.png` (`tools/godot.sh citizens` regenerates them). `MarketCitizens`
  (`scripts/world/skins/marketplace/`), called from `wall_section()`, seeds which eligible
  `shop_windows()` get one (never a feed window, `screen`) from the window's own track position, so
  a chunk builds the same citizens every time. `MarketCitizen` plays the baked sheet back as one
  cheap unlit, double-sided quad (a `StandardMaterial3D.duplicate()` per card, its `uv1_offset` the
  only thing that changes, driven in GDScript, not a shader) and reacts (startled or cheering) once
  the player's own track distance comes within range of its window, easing back to idle on its own;
  every live one joins the `"market_citizens"` group with a public `react(kind)`, the hook for The
  House (E5a, GDD §10: "the citizens in the shop windows cheer and duck throughout") to use later.
  Kept apart from window cyborgs (GDD §9.2; `docs/questions/d3.md`): citizens never glow and their
  windows stay lit, and `ZoneSkin.note_wall_enemies(side, start, end, enemies)` (a small, generic
  hook `TrackBuilder` calls just before `wall_section()`, a no-op for every other skin) tells
  `MarketplaceSkin` which window cyborgs the chunk is about to place, so `MarketCitizens` keeps
  `CYBORG_MARGIN` clear of each one's track position (`MarketplaceSkin.reserved_near()`). Switched
  off by `Settings.citizens_enabled` (`DeviceProfile.is_low_end()`, DESIGN-TBD: nothing decides
  "low-end" project-wide yet) and `Settings.DEFAULTS["citizens"]`, kept current by `apply_visuals()`
  like `flashing_reduced`, so the skin never needs a `Profile`. `test_marketplace_citizens` and
  `test_marketplace_skin`'s existing budgets (`SkinSuite`) cover it; with `CITIZEN_SHARE` at 0.16 it
  adds about 2 surfaces and under 10 vertices per 5-lane chunk on top of the Marketplace's own ~21.
- *Ceilings from their lanes (task B3).* `MarketCeilings` builds every kind (a building bridging the
  street, an overpass, a merchant ship, a floating ad) from the ceiling's collision box and lane
  seams, so a ceiling over fewer lanes just builds narrower; only a full-width ceiling becomes a
  building bridging the street. `mesh_for(kind, ...)` builds a given kind directly. A ship's engine halos
  stop at the underside (`MeshKit.stern_halo`).
- *Decorative signs* (neon, painted blade signs, ad boards, casino bulbs) never sit below
  `decor_min_height` (8 m) and never wear the striped frame, which is reserved for hazard signs.
- *Futuristic and worn* (GDD §5): `shopfront.gdshader` draws cladding, rounded smart-glass windows,
  roller shutters and grime; `MarketFacades` adds air-conditioning units, drone racks, cable trays,
  glass balconies, rooftop dishes and masts, and cables across the street (the machinery's faces
  use `PAT_TECH`), all above the wall-run band, which the suite checks stays flush. Dust on roofs,
  awnings and ledges comes from `kit_market.gdshaderinc` (`market_dust`, scaled by the skin's
  `wear`).

**The Corporate zone** (`scripts/world/skins/corporate/`): `CorporateTrains` (the floor: the roofs of
maglev trains, and the guideway trench below), `CorporatePlaza` (the paved deck of the plaza variant,
`floor_style` PLAZA, `data/skins/corporate_plaza_skin.tres`), `CorporateTowers` (the walls, and the
skybridges and hovering gunships over the street), `CorporateCeilings`, `CorporateShips` (the gunship
template) and `CorporateProps` (fences and signs); its building faces use their own shader,
`corp_facade.gdshader`.
- *The brand.* One harsh colour, `brand_color` (an electric ultramarine between the UI's azure and
  violet, clear of every hazard hue), and one mark, `corp_logo()` in `kit_logo.gdshaderinc`, which
  Gangland's corporate crates, containers and ads share. Glowing decoration keeps to cold white and the
  brand's blue; the military olive is always lit, never glowing.
- *Carriages on a grid.* Each lane's carriages sit on a grid (`carriage_length`, offset per lane:
  `carriage_unit()`, `carriage_offset()`), so they line up across chunk cuts, and a carriage's kind
  (runs of express or olive freight cars) comes from hashing its grid cell (`carriage()`).
  `carriage_plan()` lays out a floor piece's roofs and joints: no joint within `GAP_MARGIN` of a gap's
  edge, and a thin seam instead of a gangway where one would cross a chunk cut.
- *Gaps read as holes.* Everything below the running surface (the carriages' sides and ends, the
  guideways, the trench, the plaza deck's edges) is drawn with `PAT_CORP_UNDER` in `gap_inside_color`, a
  deep shade that only darkens with depth, with the guideways and the trench floor deeper than a fall
  that ends the run; nothing below is lit or glows but the orange strip. The suite pins it over a whole
  level, for the trains and the plaza.
- *The calm band.* Every wall is flush through `band_top` (7.2 m): nothing glows, lights up or sticks
  out there (partial wall fences, B5, sit in it); decorative signs and screens start at
  `decor_min_height` (8 m). What hangs out over the street (banners, big screens, skybridges) stays
  above `CorporateTowers.OVER_STREET_MIN`, and nothing of a ceiling rises more than
  `CorporateCeilings.TOP_LIMIT` above its underside, so the two never meet.
- *Ceilings from their lanes (task B3).* `CorporateCeilings` builds every kind (a glass skyway, a tower
  bridging the street, a viaduct with a military checkpoint, a gunship flying low) from the ceiling's
  collision box and lane seams; only a full-width ceiling becomes a tower bridging the street.
  `mesh_for(kind, ...)` builds a given kind directly.
- *A boss over the street.* Hostile Takeover's gunship paces the train overhead (GDD §10): an arena skin
  with `street_screen_share`, `banner_share`, `skybridge_share` and `hover_ship_share` at 0 builds
  nothing over the lanes above the ceilings (the suite checks it). Searchlights never point at the
  lanes (a light locking onto them is the Floating Head's warning).
- *The military presence* is data: `compound_share`, `hover_ship_share`, `ship_weight` and
  `military_car_share`; the plaza variant raises them for Corporate 2's heavier presence.

**The Dead Zone** (`scripts/world/skins/dead_zone/`): `DeadStreet` (the floor: a rubble street, and the
void below it), `DeadTowers` (the walls: the Neon City's towers burnt out, and the broken skybridges and
smoke over the street), `DeadCeilings` and `DeadProps` (fences and signs). Everything is drawn with the
kit's solid shader (`kit_dead_zone.gdshaderinc`), the drift shader and one shader of its own,
`dead_smoke.gdshader` (columns of smoke: one billboarded column per six vertices, lit by
`scenery_light`). Dark black, dark grey and ash grey at night (GDD §5); the ash-grey street is its
lightest surface.
- *Gaps read as holes.* The street (`PAT_DZ_STREET`, laid out from world position) is broken plates under
  pale ash with rubble drawn flat, never built, so nothing on the running surface stands up like an
  obstacle, and nothing round lies on it (a manhole is a screech's lair). Everything below it (the cut,
  the sides along lane edges, the void floor `void_depth` down) is `PAT_DZ_UNDER` in `gap_inside_color`,
  which only darkens with depth; a gap's edge is the lip, strip and far halo of every zone. The suite
  pins it over whole levels at 3 and 5 lanes (the hole far darker than the street's darkest shade).
- *The calm band.* `PAT_DZ_TOWER` draws the City's four window styles gutted (burnt rooms, shards,
  torn holes, soot) above `band_top` (7.2 m) and, below it, flush ash-dusted cladding with soot tongues
  climbing from the street: nothing opens, glows, sticks out or looks like a window (a window cyborg's)
  or a vent there; the 2 m and 4 m wall-run marks are unlit paint. Decoration (dead neon banners, dead
  roof boards, screens) starts at `decor_min_height` (8 m); what hangs over the street (screens, broken
  skybridges) stays above `DeadTowers.OVER_STREET_MIN` (14 m), and nothing of a ceiling rises more than
  `DeadCeilings.TOP_LIMIT` above its underside.
- *Fires kept minimal* (GDD §5). The only glows besides hazards, triggers, ceiling ends and the feed are
  embers: a few windows of some towers, `ember_min_height` (16 m) up or more, a dull orange below the
  bloom threshold and under a third of a gap edge's glow (the faces' vertex alpha, breathing slowly,
  steady with Reduced flashing); smoke columns rise only from ruins 20 m tall or more
  (`DeadTowers.PLUME_MIN_TOP`). The suite checks both over whole levels.
- *Motion on a still street.* Ash flakes, faint puffs of smoke and speed streaks drift toward the runner
  (`MeshKit.drift_particles(..., smoke)`: the drift shader's fourth kind, `DRIFT_SMOKE`, a big soft puff
  that fades three times as far from the camera as the others; a skin passing no smoke count is
  unchanged).
- *Ceilings from their lanes (task B3).* `DeadCeilings` builds a charred bridge or a dead building
  across every lane (weights `bridge_weight`, `building_weight`), and over fewer lanes a slab broken off
  the tower it reaches (one wall) or a collapsed span hanging from its gantry (neither wall), from the
  collision box and lane seams; `reaches_wall()` decides which sides run into a building face, from the
  section's wall distance (`DeadZoneSkin.ceiling_section`; `hull()` alone uses the wall face the skin saw
  last, as `wall_section` runs before a chunk's ceilings). Every underside is flat
  charred concrete with a steel strip and a pale line on each lane seam, and the orange far-end band.
  `mesh_for(kind, ...)` builds a given kind directly.

**The Casino** (`scripts/world/skins/casino/`; task K1, GDD §5 Zone 4, the owner's reference image
`docs/art/reference/casino_zone.webp`): `CasinoStreet` (the floor), `CasinoFacades` (the walls),
`CasinoVault` (the glass roof and what hangs from it), `CasinoCeilings` and `CasinoProps` (fences and signs);
its building faces use their own shader, `casino_facade.gdshader`, and it adds the patterns above. A long
covered casino street at night under a vault of glass and iron: dark riveted iron and aged brass, a wet
paved street, warm lamplight and haze.
- *Scenery only, on the Marketplace's skin.* The owner asked for new walls, floor, ceilings and background
  and no new characters, so `CasinoSkin` extends `MarketplaceSkin` and keeps its `enemy_variant = &"casino"`
  (the Casino Mob Enforcer and the Marketplace's other enemies, as they are), its citizens (`MarketCitizens`,
  the same class, in the same `market_citizens` group The House's crowds cheer and duck through), its plant
  and casino-machine doodads (`MarketDoodads`, in the Casino's palette), the cult's feed and emblem, and its
  `shop_windows()`, `reserved_near()` and `note_wall_enemies()` contract. `CasinoFacades` extends
  `MarketFacades` and `CasinoProps` extends `MarketProps`: the same lots and windows and the same fence and
  sign hooks, only their looks differ; `CasinoSkin.facades()` returns the Casino's. The Marketplace's own
  export groups for what it draws itself (stalls, stucco, ships) stay unused here, and `_casino_palette()`
  gives the ones the shared pieces read (neon, lamps, signs, doodads) the Casino's colours. Chunk meshes use
  the same materials as ever: the one solid and one glow material of the batch, the facade shader's own, the
  feed's, and the drift material, so the roof adds no surface of its own.
- *The street is a floor and gaps are open service trenches* (DESIGN-TBD, docs/OPEN_QUESTIONS.md §D, item 504): dark
  flagstones in running bond with brass inlaid along both edges of every lane and across it every 6 m (the
  still floor's own motion cue), pools of lamplight and a wet sheen (all in the shader, from world position,
  so chunk cuts are seamless), and the dust, scraps and speed streaks of the other skins. Under a gap
  everything is `PAT_CASINO_UNDER` in `gap_inside_color`, a deep shade that only darkens with depth and is
  far darker than any paving, with the orange lip and strip on the collision edge (`CasinoStreet`, built
  as `MarketStalls` is). The suite pins it over whole levels at 3, 5 and 6 lanes.
- *The calm band.* Every wall is flush from the street up past `band_top` (7 m): the facade shader paints
  a brass stripe there along the top of a storey, flat (no shading, so it can't read as standing out), its
  risers and round shaded pipes start above the band (`painted_pipe()`), the casino fronts' glass and bulbs
  start at `decor_min_height` (the grid begins there, a whole storey at a time), and nothing opens, glows or
  sticks out (no vent-like shape: the screeches' lairs). Balconies, brass pipes and risers, air-conditioning units and
  blade signs start at `overhang_min_height` (10 m: nothing hangs over the lanes below it but ceilings, the
  arrival flyover's rule) and stand out of the face by under a metre (the flyover's camera keeps a metre
  inside the walls); flat decoration (decorative signs, banners, wall lamps, marquee bulbs) never sits lower
  than `decor_min_height` (8 m) and is never framed in a hazard's stripes.
- *The glass vault is background* (never a ceiling the player can use). `CasinoVault` springs it from the
  facades' top (`eave_height`, 22 m) and arches it over the street (higher over a wider one: `arch_of()`),
  in bays (`bay_length`) built from one cached template per street width: iron ribs and purlins, and the
  panes (`PAT_CASINO_VAULT`: dark night-blue glass in iron frames, warmer low on the arch, a few faint
  painted stars), **opaque and faked** (no transparency, the phone rule). **The roof is whole** (owner,
  October 9, 2026: no broken or missing panes; the suite counts every pane of every bay, the arena's too), so
  the night reads only as the glass's tint. It is built with the left wall (`wall_section` and `wall_gap`, so a wall gap's
  parts keep their roof): a bay belongs to the call whose range holds its start. Hung from it, by hash:
  girders across the street carrying banners of heavy cloth, lanterns on chains (an emissive box and a
  soft halo: no real light) and still ceiling fans. **Nothing hangs below `bunting_height` over the lanes**
  (16 m; the arrival flyover's camera flies under 9.5 m and The House is 13.5 m tall:
  `TheHouseTuning.height`, `scripts/bosses/the_house/the_house_tuning.gd`). A girder under the eave runs wall
  to wall (`girder_of()`; only one hung in the roof itself ends where the glass does) and a fan's blades stay
  inside the glass (`fan_of()`: it moves to the middle of a narrow street, or is dropped).
- *Real lettering on the two named casinos* (task K3; owner, October 9, 2026: "Gasket's House of Chance"
  and "The Brass Lotus", the names in the reference). `CasinoLettering` turns the project's own Exo 2 (OFL,
  `assets/fonts/exo2`) into flat clockwise triangles once per process through `TextMesh` (curve step 6, weight
  800, about 9 ms; built when `CasinoSkin.facades()` is first made, so while a level loads, never in a chunk
  built during a run) and keeps them as plain vertex arrays in five layouts (Gasket's two lines on its board,
  its one line on a strip, GASKET'S stacked down a blade; the Brass Lotus's board and its stacked blade). A
  sign is one `MeshLayer.append` of a cached, coloured layout into the chunk's solid layer (about 15 us): no
  `Label3D`, no `SubViewport`, no node, no surface or draw call of its own. **Only a few casinos are named**
  (two famous ones, not a chain; DESIGN-TBD, `docs/OPEN_QUESTIONS.md` §D, item 525): `CasinoFacades._name_of()` cuts the
  street into periods of `name_spacing` metres (100, both walls together), picks at most one casino with a big
  sign in each by hash (from the period's middle half if it has one) and alternates the names from period to
  period, a pure function of the street's layout so every chunk agrees; a `name_spacing` of 0 names every
  casino with a big sign by hash instead. The other casinos keep the mark and glyph rows. A named casino
  carries its name on its board (the sign's shader panel is dark with a tube of light and no glyph rows:
  `NAMED_PANEL`, set only when the letters exist; a casino whose big sign plays the cult's feed gets Gasket's
  name as a strip over the screen, and the Brass Lotus's only on its blade), keeps the cult's emblem in the
  board's lower corner (the letters take the rest: `_emblem_room()`) and has **no brass pipe or riser** (a pipe
  in front of its letters crosses them from afar) and, on the street, a blade sign at the building's far end
  (the runner comes from the near end, so it never hides the board), 0.8 m out of the wall, above
  `overhang_min_height` and under the entablature, where a runner sees its face-on column of letters from afar
  (a board is seen along its face). `CasinoFacades.named_signs()` lists the pieces for reviews and tests; the
  suite checks that nothing else on the facade reaches the volume in front of any letter, which way each board
  and blade faces, the dark panel's flag, the emblem's corner and that without the font the signs keep their
  glyph rows. The letters are the warm white `lettering_color`, glowing just over the bloom threshold
  (`lettering_glow`), never a hazard hue, never below `decor_min_height`, static (nothing to flash). They add
  under 1k vertices to a chunk of about 10-11k and nothing to its surfaces or its build time.
- *Ceilings from their lanes* (task B3). `CasinoCeilings` builds a footbridge between the balconies (only
  across every lane, as the Marketplace's bridging building), a gantry carrying a bundle of brass pipes and a
  sign gantry (a big lit sign or the cult's feed on an iron frame), from the collision box and lane
  seams: a flat iron underside over exactly its lanes (beams every 3 m stream past a rider), flush lamps,
  the orange far-end band, and nothing rising more than `TOP_LIMIT` (6.2 m) above the underside.
  `mesh_for(kind, ...)` builds a given kind directly.
- *The House's arena* (`data/bosses/casino_boss_skin.tres`): the machine is 13.5 m tall
  (`TheHouseTuning.height`) and fills the street to 35 cm off the walls, so the arena skin raises
  `overhang_min_height` to 14.5 m: the facades are flush below it (the casino signs' halos lie flat on the
  wall, and the suite checks every vertex, glow and feed included, within 30 cm of the face). Phase 3's
  billboard drops from 26 m above the 6 m ceiling (`TheHouseCeiling.DROP_FROM`, slab 0.9 m, its sign 2.5 m
  more) in 0.7 s, its slab 12 cm from each wall, so the arena also raises the roof (`eave_height` 34 m,
  whatever the street's width: the suite checks the roof's underside clears the billboard's top across the
  whole street at 3, 5 and 6 lanes), hangs nothing from it (`hangings` off; `bunting_height` stays at 28 m)
  and **keeps every face flush at every height** (`flush_faces`: no balcony, pipe, unit or blade sign, flat
  lamps and entablature, the names on flat boards only; the suite holds every vertex between the ceiling and
  the slab's start to the slab's gap from the walls at 3, 5 and 6 lanes).
- *The colour rule* (GDD §5): the reference glows pink, cyan, green and orange; here those never glow near
  the track. Lit signs, marquees and lamps are warm white, violet or blue; brass is lit metal (nothing of
  brass or iron carries glow); the reference's coloured boards are dim painted signs in muted rose, teal,
  moss and ochre. The marquee bulbs and the signs' breathing honour Reduced flashing (the `reduced_flashing`
  uniform; the suite reads both shaders for it).
- *Build cost* (task K5; the budget is `SkinSuite.BUILD_BUDGET_MEAN_MS`, 4 ms a chunk at 6 lanes). A chunk's
  build time follows its vertices and its calls, and the Casino is the Marketplace's walls plus a roof and
  dressing, so it was the first skin over the line. What it costs now (6 lanes, one 40 m chunk, ms): the walls
  2.2 (windows and piers 0.4, lounge balconies, units and blade signs 0.3, wall lamps 0.2, the casino signs
  and names 0.2, pipes 0.1), the roof 0.35, citizens 0.3, the commit 0.25, on top of the floors, fences and
  the track's own 1.5; vertices about 10.5k a chunk (the Marketplace's 9.8k). Kept down by: cached templates
  for everything that repeats (a wall lamp, a lantern per chain length, a fan per quarter turn in six
  turns, a blade sign's frame per tenth of a metre of height, balconies, units: each a bulk append of one
  or two layers), no faces nobody can see (`CasinoFacades.SEEN_FACES`: a piece standing out of a wall keeps
  neither the face toward the wall nor the one facing away down the street, because the camera only looks
  ahead; `test_casino_skin` pins it), `CasinoCitizens` (the Marketplace's citizens picked from the windows'
  positions without listing every window, the same citizens: the suite compares the two builders), and the
  dressing's densities, which are exports (`balcony_share`, `pipe_share`, `unit_share`, `lantern_share`,
  `fan_share`, `banner_share`, `crossbeam_spacing`, and `bay_scale`: the shop windows' bays 1.5 times the
  Marketplace's, the same piers, a third fewer windows). Measure with `tools/godot.sh test --suite=casino_skin
  --jobs=1` on a quiet machine, next to `--suite=marketplace_skin`: the Casino should read about what the
  Marketplace does. The suite's load factor comes from a greybox build that mostly measures node creation, so
  it does not notice a machine that runs GDScript slowly, which is when this skin reads closest to its budget.
- *The street's light follows the level's sky* like every scenery shader: `casino_facade.gdshader` takes
  `scenery_tint` where it takes `scenery_light` (its glowing parts stay untinted, as in every zone), and the
  solid kit shader already did (`test_level_sky`).
- *Tested*: `test_casino_skin` (the Marketplace's checks adapted, plus the vault, the arena, the lettering, the
  citizens and the wall pieces' faces). Review it with `skin_review --skin=casino` (it asks the Casino for its
  ceiling kinds before the Marketplace, which it builds on) and a boss quick play with the arena skin on both
  renderers.
