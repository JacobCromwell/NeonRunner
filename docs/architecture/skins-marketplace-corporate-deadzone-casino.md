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
- *Wall gaps open onto an alley* (task L4, `MarketFacades.recess`; `docs/architecture/skins.md`, What a side wall gap
  shows behind it): the two buildings a gap cuts show their own end faces (their colour, plinth and window grid,
  `RECESS_DEPTH` 20 m back, up to their own height), a building across the alley stands 22-38 m behind the wall line,
  and the market floor runs on from the plane under the stall roofs, everything under the roofs in the same deep
  `PAT_UNDER` shade (a gap still reads as a hole). Built per gap part into the gap's batch, in the facade and solid layers the walls use (no new material or shader).
- *Shop windows for the citizens (task D3).* Every shopfront has a row of real window openings with
  lit displays at the low part of the wall (0.85-2.8 m above the floor, above the wall vents' zone).
  `MarketplaceSkin.shop_windows(side, face_x, start, end)` lists the windows whose centres lie
  between two track distances (position on the glass, width, bottom, top, depth into the building,
  kind), computed from track positions alone, so it can be asked before or after a chunk exists.
  Citizens stand inside, between the glass plane and `face_x + side * depth`. Each entry also says what the window
  holds besides: `screen` (true if an ad screen or a poster hangs in it, so no citizen stands there) and `display`
  (`&"ad"`, `&"poster"` or `&""`), both seeded from the window's own position (`MarketFacades.display_of()`).
- *Shop-window displays: ad screens and posters (task L10; GDD §5 "Cyborg Viewing Devices", the owner's October 17, 2026
  decision after playtesting: the old CRT feed TVs "don't really add much", so they are replaced entirely).*
  `MarketplaceSkin.window_display_share` (0.22, the TVs' share, and the very same windows: salt 43 of the window's
  hash) of the shop windows hold one, `window_screen_share` (0.5) of those an **ad screen** and the rest a **lit poster**
  (DESIGN-TBD, `docs/questions/l10.md`). Both are one panel in a dark frame hung in the window behind the glass
  (`MarketFacades._display()`, `_hang_panel()`; never in the template, whose mirror would flip the picture), with its
  stand, legs or lintel rod: about 60 vertices, the TV's cost. The frame, stand, legs and rod are in the solid layer the
  wall already draws; the panel's face is one rectangle in a **material of its own**, `WindowDisplay`
  (`scripts/world/meshes/window_display.gd`, `window_display.gdshader`, the pictures in `window_display.gdshaderinc`;
  `MarketplaceSkin.display_material()`, shared with the Casino's), so a chunk with displays draws one more surface, as the
  feed's TVs did. (It was first a pattern of the solid kit shader. Every zone compiles that shader, and the displays' code
  made its first compile on the Compatibility renderer about 40% slower, the City-only web demo's too: so the displays'
  code lives in a small unshaded shader of their own, and `kit_solid` knows nothing of it; `test_window_displays` pins
  that, and `kit_market_signs.gdshaderinc` holds the market's logos, shop signs and ad that both shaders draw.) The
  skin's warm-up (`warm_samples()`) draws one face while a level loads, so the material is never first compiled mid-run.
  Each panel is turned `window_screen_turn` (28 degrees) toward the runner's approach, because a flat panel is seen almost
  edge-on from the lanes, **as far as the whole of it fits the display** (`fit_turn()`: the frame's box takes
  `cos(t) * PANEL_DEPTH + sin(t) * (width + 2 * PANEL_BORDER)` of the display's 0.9 m, so a 1.6 m screen turns about 27
  degrees and the 2.1 m sign about 21; `test_window_displays` checks every vertex of every face and frame, the plinth, legs
  and rod too, between the glass and the back wall and inside the window's length and height). The ad screen is 1.4 to 1.6 m
  wide at an aspect of 1.8 on a low plinth; the posters hang from the lintel or, a menu, stand on legs: a shop's own sign
  (a strip at the top of the window), a sale, a menu board, a product. A window a window cyborg stands in gets none
  (`display_at()`: `reserved_near()` with `MarketCitizens.CYBORG_MARGIN`, the citizens' own rule, so nothing beside a
  screen-headed cyborg competes with it; `shop_windows()` lists no `display` there either) and the citizens skip every display
  window (`screen`), which leaves their share as it was.
  The pictures are wordless like every sign here: the ad screen cycles four of six scenes in a seeded order, each up
  `ad_scene_time` (5 to 7.5 s), the Marketplace's own brand card (`mk_ad()`), a bowl of noodles, a bottle, a delivery drone on its
  route, a sale starburst with a seven-segment number and a cup of tea, and the **Casino's own** (`wd_casino`, set by
  `CasinoSkin.window_display_params()`): the brand card, a slot machine of sevens, a stack of chips, a cocktail, a champagne
  bottle and a pair of dice (DESIGN-TBD, `docs/questions/l10.md`). One picture at a time: a change of ad is a **dip** through
  the screen's deep indigo and back (`ad_dip`: 5% of the ad's time each way, 12% with Reduced flashing), never two scenes
  mixed, so a pixel draws one scene and the shader's register peak stays that of one scene; a scene is drawn with the seed
  of its own number, so nothing jumps when it comes in. The screen **flashes the cult's emblem** (the material's
  `wd_emblem_tex`, the chosen option's coverage with mipmaps, `CultFeed.emblem_texture()`) onto itself every
  `emblem_flash_period` (14 to 26 s): in over `emblem_flash_times` 0.22 s, held 1.1 s, out over 0.55 s, drawn big (nine
  tenths of the screen's height) in the emblem's warm white on a deep indigo with a soft halo: never black, and it still
  reads from the game camera (the mark is thickened below about 50 pixels, so it melts into a blob, not into the dark, and
  fades only where it is a few pixels across: the solid kit's `cult_mark()` fades at about 24, which left the flash a dark
  screen from 13 m). Each screen's scene order, scene length, flash period and moment come from its seed (a hash of its
  window's position; `WindowDisplay.param()`: seed and aspect, small enough to survive the GPU's interpolation, decoded by
  rounding, as the Beach's `sand_param()`), so no two play in step and a rebuilt chunk shows the same screen at the same
  moment. **Reduced flashing** (`reduced_flashing`, kit_flash): the flash takes `emblem_flash_times_reduced` instead, in over
  0.9 s, held 2 s, out over 0.9 s, and the dip is slower, so the emblem fades up and stays a while and nothing pops;
  nothing else on the screen flashes (the scenes' motion is a slow drift, and the drone's dashes and the posters' grain are
  filtered away by distance, so nothing shimmers) and a flash is one event seconds apart, never a strobe
  (`test_window_displays` mirrors the envelope, reads the skin's numbers off the material and the shader's source). The ads'
  palette (`window_ad_colors`, the shader's `wd_palette`) is blue to violet and warm white, the decorative hues; the posters'
  paint (`window_poster_colors`) is lit, never glowing, and off every hazard hue too (blues, violets, slate, mauve and cream:
  no red, orange, yellow, green, cyan or pink, none near a hazard's colour: the owner's rule for these); neither draws a face or
  two eyes and a mouth, so nothing reads as a window cyborg's screen head. The feed stays on the billboards above the street and
  on the cyborgs' screen heads. Cost against the TVs: see `docs/architecture/run.md`, Chunk builds (a chunk with displays draws
  one more surface, the display material's, besides the feed's when a billboard plays it: `SkinSuite`'s tally went from
  19.3, 25.0 and 28.7 surfaces a chunk (3, 5 and 6 lanes) to 19.7, 25.4 and 29.1 in the Marketplace, the vertices from 8,673, 9,248 and 9,791
  to 8,656, 9,231 and 9,775, the build time unchanged).
  `tools/showcase/window_display_review.tscn` shows the screens and the four poster kinds up close (`--view=close|oblique|posters`,
  `--flash=S`, `--reduced`, `--skin=casino`), and `skin_review`'s shots 18-21 the first window with each in the street.
- *The Marketplace citizens (tasks D3 and L7, GDD §5 "Citizens"; scenery only, no collision, nothing the player touches).*
  Real low-poly people standing at ease in the shops. (D3 built them as flipbook cards; the owner never noticed them and
  asked for the newer rendered people if they cost little, so L7 measured and replaced the cards: the numbers are
  below and in `docs/architecture/run.md`, Chunk builds. The "black rectangles with crude faces" the owner saw in the
  windows were not citizens: they were the cult's feed TVs playing the calm cyborg face, which task L10 replaced with ad
  screens and posters, and the window cyborgs' screen heads.) `tools/asset_gen/citizen_person_gen.gd` (`tools/godot.sh citizens`,
  headless) poses the shared `HumanoidRig` (`CitizenRig`) standing at ease and bakes one welded, indexed mesh,
  `assets/models/market_person.res` (288 vertices, 500 triangles, 1.33 m, feet on y = 0, facing -z, two small dark eyes
  so a turning head reads; `CitizenRig`'s limb pieces hang from their joints and its head sits on the shoulders, so nothing
  floats off the figure: a test counts the front silhouette's pieces, one): UV2 tags every vertex with a colour class (trousers, shirt, skin, hair, shoes, eyes) and what
  moves it (the body, the head, the left or right arm), and the mesh's meta holds the neck and shoulder pivots.
  `MarketCitizens` (`scripts/world/skins/marketplace/`), called from `wall_section()`, seeds which eligible `shop_windows()`
  get one (never a window with an ad screen or a poster, `screen`; `CITIZEN_SHARE` 0.32) from the window's own track position (`person_for()`:
  where they stand inside, their height and build (D3's three archetypes as three silhouettes of the one mesh: the tall slim
  shopper, the short wide regular, the vendor between, 1.47 to 1.74 m, a few per cent each of their own), the way they face: the lanes, turned 20 to 50 degrees toward
  the end of the street the runner comes from, and their seeds), so a chunk builds the same citizens every time, and adds one
  `MarketCrowd` to the section: one `MultiMeshInstance3D` of the people (one draw call and three nodes however many), in the
  `"market_citizens"` group with a public `react(kind)` (D3's hook for The House, E5a: `&"cheer"` and `&"startled"`, the
  duck). `market_person.gdshader` (unshaded, the kit's fake light times `scenery_light` and `scenery_tint`, never glowing,
  never flickering, the same on the Compatibility renderer) dresses each from `MarketPeople`'s palettes (muted clothes, a
  test pins saturation, brightness and vividness; no skin-coloured shirt) by the seed in the instance's custom data and moves
  them in the vertex shader: a sway and a breath at ease, the head turning about the neck to follow the runner (from
  `look_far` 52 m, fully within 16 m, 72 degrees at the most; a crowd with no run at all, the Marketplace intro's street, faces
  forward, `u_state.w`), and a cheer or a flinch from one uniform. The head and arms turn about their pivots first and the crouch
  scales the body after, so the arms' roots go down with the shoulders (`MarketPeople.posed()` and `reaction()` mirror the shader's
  vertex function, a test keeps them and the arms on the body through a cheer, a flinch and a blend); two reactions at once add,
  the one under way kept in `u_event_prev`, so nothing snaps. One shared
  `ShaderMaterial` serves every crowd; `MarketPeople.tick()` (the first crowd of the run to process in a frame: one outside it, such as the
  warm-up's sample, leaves the frame to them) sets its one uniform
  `u_state` (the crowd's clock, which stops in a pause and slows with slow-time, and the runner's place, read from the
  `RunWorld` the crowd finds up its tree), `u_event` only when something cheers: the CPU does nothing per person.
  What cheers (`data/citizens/market_people.tres`, `MarketPeopleTuning`, all DESIGN-TBD, `docs/questions/l7.md`): a credit
  pickup worth 25 or more (`CreditField.collected`; the top two denominations, about ten a level), and the player's defeat
  of a hover truck, an Enforcer Truck, a heli drone, a Buzz Overdrive or a Resonator (`EnemyDirector.enemy_defeated`,
  `cheer_enemy_types` by `Enemy.type_id`; an enemy another's charge flattened counts only if it declares `charge_bait`, as the
  score has it). The skin side listens: the first crowd to tick in a run finds its `RunWorld` and connects both signals once
  (no core file is touched), and The House's `react()` calls arrive through the group. Citizens within 48 m ahead of the runner
  and 12 m behind hop once (0.28 m, 0.9 s, both arms thrown up), the cheer rippling out from the runner (0.012 s a metre, and
  up to 0.18 s of their own lateness), no more than one cheer per 1.6 s; a flinch crouches them with their arms up. No sound.
  Nothing flashes, so Reduced flashing has nothing to hold still. `MarketplaceSkin.warm_samples()` gives `ShaderWarmup` (the
  one hook outside the skin) a person to draw while the level loads, so the Compatibility renderer never compiles the shader
  mid-run (`frame_times --shaders`: none first drawn later). Kept apart from window cyborgs (GDD §9.2; `docs/questions/d3.md`):
  citizens never glow and their windows stay lit, and `ZoneSkin.note_wall_enemies(side, start, end, enemies)` (a small, generic
  hook `TrackBuilder` calls just before `wall_section()`, a no-op for every other skin) tells `MarketplaceSkin` which window
  cyborgs the chunk is about to place, so `MarketCitizens` keeps `CYBORG_MARGIN` clear of each one's track position
  (`MarketplaceSkin.reserved_near()`). Switched off by `Settings.citizens_enabled` (`DeviceProfile.is_low_end()`,
  DESIGN-TBD: nothing decides "low-end" project-wide yet) and `Settings.DEFAULTS["citizens"]`, kept current by
  `apply_visuals()` like `flashing_reduced`, so the skin never needs a `Profile`. Cost, against the cards (one a card at 0.16 of the windows; the people at 0.32, twice as many), measured with
  `tools/measure/market_people_cost.gd` on `marketplace_1` and `_2` at 3, 5 and 6 lanes: the citizens' own build 0.22 to
  0.31 ms a 40 m chunk (the cards' 0.35 to 0.42), 4.5 people, 1.9 draw calls and 3.8 nodes a chunk (the cards' 2.3, 2.3 and
  4.5), and about 1,300 vertices drawn a chunk (the cards' 9: a person is 288 vertices and 500 triangles); a whole chunk's
  build reads the same as with the cards (+0.3 ms of its 2 ms either way, within the run-to-run noise) and
  `test_marketplace_skin`'s budgets (4 ms mean, 32 surfaces) read as before (its tally counts `MeshInstance3D` surfaces only,
  so read the measuring tool's lines for what the people draw). Played (`tools/measure/frame_times.gd`, Marketplace 2, 40 s):
  the CPU's frame times are unchanged (median 1.0 ms, p99 3.0 ms, worst 4.6 to 5.5 ms, with the cards and with the people);
  on the Compatibility renderer (software, so counts only) the draw calls are the same (277 median, 410 to 415 most), objects the
  same, primitives 48,200 to 58,100 a frame (+10,000 triangles in view, +21%) and materials 160 to 119, no shader first
  drawn after the load. `test_marketplace_citizens` covers the person's mesh and budget, the palettes and the shader's rules, the placement, the
  switch, one crowd a section, the warm-up sample and every cheer.
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
- *Wall gaps open onto a service alley* (task L4, `CorporateTowers.recess`): the cut buildings' end faces (the
  podium's cladding, a tower's glass and service crown, a compound's blast walls, a low building's roof line) 24 m
  back, a tower across (60-130 m) and the trench floor, below the street in the trench's own `PAT_CORP_UNDER` shade
  (the trench walls at the faces still hide most of it from the street).
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
- *Wall gaps open onto where a tower was burnt away* (task L4, `DeadTowers.recess`): the two ruins' end faces
  (`PAT_DZ_TOWER`, their own style, up to their broken tops, nothing lit or smouldering), a ruin across (40-80 m,
  broken against the haze like the stumps' far rows) and the void floor, the part below the street in `PAT_DZ_UNDER`.
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
  the same people, in the same `market_citizens` group The House's crowds cheer and duck through), its plant
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
- *Wall gaps* (task L4): the Marketplace's alley (`MarketFacades.recess`, through `CasinoFacades._under_depth` and
  `_under_pattern`), in the Casino's iron, brass and arched windows down to the trench in `PAT_CASINO_UNDER`; the roof
  overhead stays (the left wall's call).
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
  and names 0.2, pipes 0.1), the roof 0.35, citizens 0.15 (task L7's people, one MultiMesh a wall section; the cards were 0.3), the commit 0.25, on top of the floors, fences and
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

**The Terminal** (`scripts/world/skins/terminal/`; task O4, GDD §5 Zone 8, the owner's reference image
`docs/art/reference/terminal_zone.jpg`): `TerminalTrack` (the floor), `TerminalHall` (everything beyond the street's
walls, and the vault), `TerminalArches` (the wall sections and stumps), `TerminalCeilings`, `TerminalProps` (fences and
signs) and `TerminalDoodads` (picture cards, `tools/asset_gen/doodad_art/terminal_art.gd`); its surfaces are the kit's
patterns 100-108 in `kit_terminal.gdshaderinc` (`MeshKit.PAT_TERMINAL_*`), drawn with the kit's one solid and one glow
material, the drift shader and the Dead Zone's smoke shader (`dead_smoke.gdshader`, for the steam), so the zone adds no shader
and `test_zone_shaders` is unchanged. An abandoned subway under
the city: wet black stone, rust and verdigris, vine green, sodium lamplight through haze, and no sky (the vault is whole).
- *The floor* (`TerminalTrack`, adapted from `DeadStreet`): every lane but the outer two is track bed
  (`PAT_TERMINAL_TRACK`: gravel, a sleeper every 0.64 m, a pair of rails 1.44 m apart in every lane, cables, puddles, a dark
  seam between lanes so the lanes read), the outer two are the platform along each wall (`PAT_TERMINAL_PLATFORM`, with a
  strip of pale studs on the edge facing the track): it needs no lane count, an outer lane being the one whose floor box
  runs on to the wall (the gutter). A gap is a hole in the track bed: the orange lip and strip right on the collision
  edge and the halo on the far side, as in every zone, and below it deep shade (`PAT_TERMINAL_UNDER`) to a service
  level; the floor cut's hole is the same with a few bent slabs hanging. Rails and cables are the only things near the
  track that are not dark: kept dull steel and black, never an orange that reads as a gap edge. **The lane's width is
  never fixed in the shader** (the skin is not given the tuning): each floor piece's pattern parameter carries the half
  width of what it is drawn on, in centimetres times 8 over the platform's flags (`TerminalTrack.half_width_param`, the
  width read off the floor box by `TerminalTrack.half_lane`, the nearer side of an outer lane's box counting; the shader's
  `tm_half_width`), and the hall's second track is drawn with the same lane width, so a level with other lane widths
  needs nothing changed.
- *The hall is drawn by the floor, not the walls* (`TerminalHall.ensure`): the arches are a few lengths wide with about six
  lengths of open space between them (O1), so nothing may depend on a wall hook running in every chunk. Each floor piece
  asks the hall to cover the 10 m cells its stretch overlaps, **once per chunk**: under the chunk's root
  (`TerminalSkin.chunk_root`: the child of the `TrackBuilder` that the piece's node is or lies under, so the slices of a
  floor cut, each under a node of its own that the cut hides or shortens as it runs, never hold the hall; Godot's names for
  the slices after the first are no mark to go by). The chunk root remembers the covered cells (`terminal_cells` meta) and
  the 40 m slices of drifting dust and steam (`terminal_slices`), so a piece cut short by a hole only adds what nothing
  has drawn, and every chunk holds its whole hall once, in one `Hall` mesh per run of uncovered cells (usually one).
  **The wall hooks draw no hall**: O1 draws each arch and stump whole, in the chunk where it starts, so an arch across a
  chunk's edge adds nothing to the next chunk's hall. The street's wall distance comes from the outer lane's own floor box
  (`TerminalTrack.build` returns it). What a cell holds, from the street out on each side: a kerb along the wall line (the
  street's boundary, since the zone has no wall running), a second track `track_drop` below with subway cars on it in trains
  (`PAT_TERMINAL_CAR`: flaking paint over rust, a band of windows every 2 m bay, a door pair every fourth, vine draped over
  the roof and hanging down; stretches picked by hash of 90 m blocks, `train_share`, `train_cars`, each car built once by the
  cell its near end is in), a few scavengers' camps (a fire barrel with dim embers and three dark hunched silhouettes,
  scenery only; `camp_share`), the far wall at `hall_extra` beyond the wall line (old white tile under black ashlar, two
  rusted pipes, a work lamp every `lamp_pitch`), plumes of steam leaking from the old pipes (`jet_share`: soft smoke, the
  kit's `dead_smoke.gdshader`, alpha-blended and unbanded, `jet_opacity`, stronger on the Compatibility renderer because it
  blends in sRGB space: `jet_opacity_compat`), and the vault: an ellipse from the far
  walls at `spring_height` up to `crown_height`, on steel ribs every `lamp_pitch` with a work lamp hung from each, dead
  departure boards hung from some (wordless, matte) and cables strung between them. Under the street, for the holes: the
  service level's floor and each side's pit wall. `wall_opening(parent, side, face_x, start, end, gap)` draws nothing (a missing
  arch is not a hazard; the hall is already there): O1's hook for the open space between arches, called once per chunk it reaches (the base's default draws a plain
  wall behind the arches, which would hide the hall). Wall gaps keep the base's look (`wall_gap_marks`, `wall_gap_recess`):
  the track builder calls `wall_gap` only in a level with wall running (this skin on another zone's level), where a gap's
  orange marks are the warning that the wall-running surface stops (`test_wall_gaps` checks every skin).
- *The arches* (`TerminalArches`): `wall_section(parent, side, face_x, start, end)` draws a riveted steel pier from the floor
  into the vault (a street face in `PAT_TERMINAL_STEEL`, angle irons and straps 4.5 cm proud, the only thing in the wall-run
  band, sometimes a rust-red enamel plate (a pale painted border and four bolts: no symbol; the first draft's ring and bar read as
  a transport operator's roundel, so it was dropped), a flared capital above 10 m, a half-rib springing from it
  along the vault to the street's middle so a pair closes an arch and a lone one is a broken arch, vines hanging from the
  capital to no lower than 7.4 m (over every ceiling), a bush of vine at its foot beyond the kerb). A section a space long
  (up to `pier_width` x 1.6) gets one pier, a longer one (the wall every other zone has) several `pier_pitch` apart, so
  the skin also works with the track builder as it is. `wall_stump(parent, side, face_x, start, end)` is the hook task O1
  adds to `ZoneSkin` (the skin defines it first, so its override takes over when the base declares it): the same pier broken
  off at about half its height in three uneven columns (0.42-0.56 of the arch's height), the paint gone from the top of each
  and the concrete core showing, rebar bristling out, rubble heaped at its foot beyond the kerb, nothing inside the wall
  line.
- *The light.* The kit has no real lights, so the zone paints its own (`tm_burn`, `tm_pool`, `tm_wall_pool`, `tm_lit`): a
  work lamp hangs from every rib (lamp k at z = -(k + 0.5) x `lamp_pitch`, `lamp_height` up, in the middle of the street) and
  one on the far wall half a pitch off; each is dead (a fifth), failing (a third: dim, with one slow smooth brownout every
  few seconds, never a strobe) or burning, by a hash of its index, decided in the shader from where the fixture stands
  (`PAT_TERMINAL_LAMP`), so a fixture and the pool of orange light under it always agree (`lamp_color`, a sodium amber,
  and the same colour tints every pool: `tm_lit`) and the skin places fixtures without hashing anything. Every lit pattern
  calls `tm_lit(albedo, light)`; the lamps' own glow is dim (`lamp_glow` 0.09, `lamp_glow_compat` 0.16 on the Compatibility
  renderer, which scales emissive colours in sRGB space and would draw the lower number far dimmer: under the bloom
  threshold and a fraction of a gap edge's, which blooms). **Reduced flashing**: `tm_burn` mixes the brownout with a
  steady dim level by the global `reduced_flashing`, so a failing lamp holds still (`test_terminal_skin` checks the shader
  source: the include never reads `TIME` itself, `tm_burn` reads `reduced_flashing`, the dip is a 0.31 Hz function of the time
  it is passed).
- *The colour rule* (GDD §5, **looser in the later zones**: the owner, October 20, 2026, "it's ok if the color palette conflicts
  a bit with the rules"; the Terminal's work lamps are orange, as the owner first asked and the reference shows): nothing
  glows but the work lamps (and the scavengers' dim embers, the same pattern), the hazards, triggers and the orange ends of
  gaps and ceilings. The lamps are orange, so they are told from a gap edge (the red-orange lip, strip and halo, unchanged)
  three ways, each a check in `test_terminal_skin`: hue (a lamp is amber, 35 degrees against the edge's 13 and short of the
  hazard signs' yellow, 46), glow (a lamp's peak is a fifth of the edge's, under the bloom threshold, which the edge is over,
  so edges bloom and lamps never do; the camps' embers dimmer still) and height (every lamp tube at least 4 m above the
  street: the crown lamps 8.4 m, the far walls' 4.4 m; nothing orange glows at floor level but hazards). Measured in
  rendered frames (the review tool's shots 1, 3 and 6, the brightest 1% of each patch; Forward+ then Compatibility): the
  gap edge's lip (255, 138, 28) and (255, 213, 22), luma 155 and 208; a lamp tube (190, 119, 9) and (191, 123, 1), luma 126
  and 129, value 0.75 against the edge's 1.0; the track bed under a lamp and the far walls lit by one saturation 0.33-0.63
  and value 0.51-0.66. The red-orange enamel plates are matte and dull, dead boards are matte glass in a worn frame, nothing
  carries words, nothing is striped but a hazard sign's frame. The steam plumes are soft alpha-blended smoke and glow not at all (the
  first draft's additive columns read as the anti-grav pads' light beams, which the pads must keep to themselves).
- *Ceilings* (`TerminalCeilings`): a GIRDER (a plate girder fallen across the street: the underside its bottom flange, a web
  with stiffeners, the near end torn open with the flange bent up), a WALKWAY (a maintenance walkway hanging from the vault
  on rods, rails along both sides, one rod given way at the near end) or a CAR (a stranded subway car's body over the
  street: its belly the underside, sides with a band of windows, a rounded roof under vine, the near end a blank cab front).
  Every one builds from the lanes it covers (the shared suites sweep every range at 3, 5 and 6 lanes), keeps nothing below
  its flat underside and the orange end band across its far end, and rises no more than `TOP_LIMIT` (1.9 m) over it (a
  walkway's rods go on up to the vault), so the lamps (8.4 m) are clear.
- *Doodads* (`TerminalDoodads`, GDD §3): picture cards (`DoodadCards.for_zone("terminal")`, atlas
  `assets/sprites/doodads/terminal.png`): small a stack of cable drums or a stack of crates under a rusted drum, medium a
  toppled ticket kiosk (its window an open frame with bars), a toppled vending machine (its empty shelves open) or a heap of
  broken concrete with rebar and a little vine, large a pile of fallen ceiling slabs (the gaps between open) or a long heap
  with a bent girder in it. They are drawn to whatever boxes `MovementTuning.doodad_size` gives them, every shape a share of
  the box's height. **Task O2 sets the zone's lower boxes**: until then the pictures are painted for the standard 2.6 m and
  a lower box squashes them; rerun `tools/godot.sh doodads --only=terminal` when O2 lands (`DoodadArtSet` reads the boxes
  from the tuning, and `test_doodads`' `_test_cards` compares each manifest with the boxes it is given).
- *No dash walls* (GDD §9.14: the Terminal's debris is enough): the skin keeps the base's default dash wall look, which no level
  of the zone asks for, and `test_dash_walls` lists `terminal_skin.tres` among the default-look skins (as the Beach's).
- *Environment*: no sky (the sky shader with stars, moon and skyline off, its horizon the fog's colour), the fog the warm
  sodium haze the street's far end fades into, the ambient a dim warm grey for the runner and enemies.
- *Music*: no song of its own (GDD §11 and the task plan: no more generated songs). `music = &"terminal"` in O1's zone
  resolves through `data/audio/music_library.tres` to the Dead Zone's, the way the Casino and the Beach reuse the
  Marketplace's generated loop: `files["terminal"]` is the Dead Zone's generated loop (cinematics, a fight with no song
  of its own), `zone_tracks["terminal"]` its supplied song (`zone_5`), `riff_tracks` keeps the level-complete riff in the
  Dead Zone's key (`level_complete_dead_zone`, for `zone_5` and for `terminal`), and `bpm` and `volume_db` are its. A song of
  its own later: add its file, level and tempo, point `zone_tracks["terminal"]` at it, and make its riff in its key.
- *Cost* (`test_terminal_skin`, 69 chunks of a level): build mean 1.9-2.9 ms a chunk at 3-6 lanes, 15-28 surfaces and 5-6.5k
  vertices a chunk (5 lanes: 21.9 against the budget of 32). Kept down by quads and a few thin boxes instead of detail (the
  detail is in the patterns, which cost nothing to build), one mesh per run of cells, trains and camps built only where
  hashed, and no faces nobody sees.
- *Tested and reviewed*: `test_terminal_skin` (the shared skin checks; the palette and colour rule; the lamps told from a gap edge by hue, glow and height, on both renderers; no sky;
  the shaders and Reduced flashing; holes read as holes, `hole_share` 0.70; the hall over a stretch with no wall at all and
  with holes in the outer lanes, and once per chunk over a floor cut and with arches crossing a chunk's edge (`_hall_once`:
  as many lamps, cars and dust as one fresh run of the hall draws, all hung from the chunk's root); the steam is smoke and
  the lane's width comes from the floor boxes; arches and stumps on both sides at 3, 5 and 6 lanes: inside the wall line, 5 cm proud at
  most, a stump about half the height with rubble; the play space; the ceilings; the doodads), and the shared suites that
  sweep every skin (`test_doodads`, `ceilings`, `floor_cuts`, `skin_budget`, `zone_shaders`). Review it with
  `tools/showcase/terminal_review.tscn` (a stretch laid out as O1's levels are, `wall_running` off: arches a space long with the
  open space between as wall gaps, which the track builder draws with `wall_opening`, stumps in `wall_stumps`, holes, one ceiling of each kind, doodads, fences, signs; 19
  shots, `--shot=N`, `--cam=px,py,pz,tx,ty,tz[,d]`, `--reduced-flashing`) and `skin_review --skin=terminal`, on both
  renderers.
