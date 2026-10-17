# Architecture: Zone skins: the Golden Zone, the Golden Palace, the Beach, the cult emblem and feed, reduced flashing

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Zone skins (continued)

**The Golden Zone** (`scripts/world/skins/golden/`): `GoldenWalkways` (the floor: golden walkways over
the canal), `GoldenFacades` (the walls, and the sky bridges over the street), `GoldenCeilings`,
`GoldenProps` (fences and signs) and `GoldenStatue` (the statue kit); its building faces use their own
shader, `golden_facade.gdshader`. White and cream with red and gold accents (GDD §5), at the blue hour.
- *The gold is metal, never neon.* `golden_metal()` (kit_golden) lights gold as a fake reflection of the
  dusk: bright where it reflects the afterglow, a greyed bronze where it reflects the street (dark golds
  that keep their hue go orange in the tonemapper), champagne at its brightest. Nothing gold, red, marble,
  cloth or water ever glows; the only decorative glows are warm-white lamps and lit windows. The zone's
  gold is `CultEmblem.GOLD_COLOR`, half saturated so it never passes for sign yellow or gap-edge orange.
- *Walkways over water.* Each lane is its own walkway (`PAT_WALKWAY`, laid out from world position, so
  plates continue across chunk cuts): plates between rails, a dark joint to a neighbouring walkway, a
  marble kerb on the outer lanes. The canal (`PAT_CANAL`) is `canal_depth` below; everything under the
  decks (`PAT_UNDERDECK`, the facades' DEEP style) is deep shade in `gap_inside_color`. A gap's edge is the
  lip, dark line and strip of every zone, with a soft halo on the far edge. Medallions of the emblem are
  inlaid in some walkways, one lane square, one slot per lane per chunk, clear of gap edges
  (`GoldenWalkways.medallions()`). The suite pins that gaps read as holes at 3 and 5 lanes.
- *The calm band.* Every building face is flush from the canal to `band_top` (7 m), with gold wall-run
  height marks and recessed openings for decorative wall-base guards and live Sentinels; nothing
  projects into the wall-run path. The entablature above retains its architectural ledge.
- *Wall gaps open onto a canal-side lane* (task L4, `GoldenFacades.recess`): the cut buildings' end faces (plinth,
  calm band, frieze, then a palace's or gallery's windows or a tower's glass, setbacks and crown) 20 m back in their
  own stone, a palace across, and the canal running on from the one under the walkways (`PAT_CANAL`, the walkways'
  shade below them).
- *The statue kit* (`GoldenStatue`, for the Gilded Sentinels, task C4). Statue space: the pedestal's
  foot at the origin, facing +Z. Poses are dictionaries of joint angles (`shoulder_r/l`, `elbow_r/l`,
  `grip`, `head`, in degrees; missing keys take `REST`); `POSES` names the decorative `guard`, `vigil`,
  `salute` and the swing's `raise` and `strike`, and `blend_poses(a, b, t)` mixes two. For decoration,
  `mesh(pose)` is one cached template to append into a wall mesh (no draw call of its own). For a live
  Sentinel, `rig(parent, pose)` builds it as nodes and returns them by name (`root`, `body`, `pedestal`,
  `head`, `eyes`, `arm_r`, `arm_l`, `elbow_r`, `elbow_l`, `grip`, `halberd`): turn the pivots with
  `apply_pose(nodes, pose)` or directly, and give `eyes` (a MeshInstance3D) a glowing red material of
  its own. `niche(width, height)` is a niche proud of any wall; `recess(width, height, depth)` the one a
  statue stands in, set into the wall (a live Sentinel's, task C4, and the decorative alcoves'; since task H1 its
  inside is lit bronze rather than nearly black, for all of them): the skin learns where a live one stands
  (`note_wall_enemies`, `GildedSentinel.niche_rect`), leaves its opening out of the plinth and the calm
  band (`open_rects`: the face's pieces around it, sharing their edges exactly) and appends the recess
  there (`add_niches`: a lit bronze back and sides, a marble floor, a flush gold frame whose spandrels round it
  into an arch; a decorative alcove that would overlap it is left out, `crowds_niche()`); the Golden Palace's
  walls do the same with their panel. The skin's kit is
  `GoldenSkin.statues()` (its gold and solid material). Decorative statues in both Golden skins stand
  at `statue_base_height` (0.10 m). **They stand on the wall face as a relief** (task K2; owner: "too far back in
  their recess to see", docs/questions/k2.md): each is squashed along the wall's normal to the live Sentinel's relief
  (`GildedSentinel.statue_relief()`, 0.4; `GoldenSkin.decorative_statue_basis(facing)` turns it to face the street, a
  three-quarter view toward the approach in the Golden Zone and straight on in the Palace, `decorative_statue_turn()`),
  and mounted by its own pose's outward projection on its own wall (`decorative_statue_projection(pose, side)`, squashed
  and turned) plus `statue_base_inset` (0.02 m, from 0.10), so its front stands 0.02 m behind the face, never in front of
  it: nothing of the walls projects into the wall-run path, and the runner's side clearance is untouched. The
  recess back clears the wallward projection by 0.05 m (about 0.44 m deep, from 1.56 m; `decorative_statue_recess_depth`),
  and the decorative opening is 2.0 m wide. The decorative poses keep their halberd's blade turned along the wall and
  their hands close to the body (`GoldenStatue.POSES`; the guard is also a live Sentinel's rest), so a pose is
  not deeper than the rest. From 20 m down a five-lane street, 68 to 73% of a decorative statue's width shows through
  its alcove (3 to 16% before; `test_gilded_sentinel`). A decorative-mesh-only gold albedo lift, without emissive glow,
  keeps guards discernible from the runner camera. Pedestals and recess sills stay at or above the
  floor, and every pose stays behind the wall face. `GoldenSkin.statue_spots()` lists them. Their meshes are scenery only;
  the live Sentinel's niche is not: it is shallower (`niche_depth` 0.4 m) and wider (`niche_width` 2.0 m, from
  1.8 m), so `in_chunk` in `gilded_sentinel_rules.gd` (`niche_width / 2 + CHUNK_MARGIN`) moves a Sentinel by up to 0.10 m in
  about 26% of random-seed Golden 2 and 3 builds, and its solid `body` and `top` hitboxes went from 0.68 m to
  0.30 m deep behind the face (`niche_depth - 0.1`); its cut's hitboxes (the wall band and the lane) and marks are
  unchanged.
- *Ceilings from their lanes (task B3).* `GoldenCeilings` builds a golden bridge (a coffered underside,
  a marble face with the emblem's crest, water off some into gilded troughs), a gallery of golden arches
  (only across every lane) or a hover-yacht from the ceiling's collision box and lane seams; over fewer
  lanes a bridge becomes a suspended gallery. Water stays above the underside. `mesh_for(kind, ...)`
  builds a given kind directly. `GoldenSkin.ceiling_section` hands it the section's wall distance, and a
  yacht's engine halos stop at the underside (`MeshKit.stern_halo`), as every zone's far end must.
- *Ceilings under the walls' decorations.* The walls build without knowing where ceilings are, so
  `GoldenFacades.clearance_profile()` declares what they hold out over the street, as (reach, lowest
  height) tiers for upper architectural decorations: the ledge, gilded frames, banners, and
  `OVER_STREET` beyond. Wall-base guards are recessed rather than street overhangs.
  `GoldenCeilings.headroom()` turns it into how high a ceiling may rise at a distance from a wall:
  arches are flatter over a narrow street (`arch_rise()`), a bridge's face stays under the ledges and its
  rail stops short of the statues, and a yacht near a wall has a lower cabin and no mast. The suite
  checks both sides on streets of 3 to 6 lanes; a new wall decoration extends the profile.
- *Overhead.* Sky bridges between towers 24 m up or more, only where towers tall enough stand on both
  sides; banners hang no lower than `GoldenFacades.BANNER_BOTTOM` (11 m), clear of every ceiling.

**The Golden Palace** (Golden 3, task D6b, GDD §5 "Final level: the Golden Palace"): a level's own
skin (`data/levels/golden_3.tres`'s `skin`, over the Golden Zone's), since the player runs *inside*
the palace rather than its streets. `GoldenPalaceSkin` (`scripts/world/skins/golden_palace_skin.gd`)
extends `GoldenSkin` outright, the only skin that does: GDScript can't redeclare an exported property
in a subclass (CLAUDE.md principle 7), so `data/skins/golden_palace_skin.tres` sets fresh values for
the few exports its colonnade and ceilings reuse for a new purpose (`lot_length` as the colonnade's
bay spacing, `gallery_share`/`statue_share`/`banner_share`/`relief_share` as a bay's content,
`banner_width`/`banner_length` as a tapestry's size, `bridge_weight`/`archway_weight`/`yacht_weight`
as the ceiling pieces' weights, a chandelier taking the yacht's role), while its Gold and red,
Statues, Hazards, Pads/ramps/finish and Environment groups, its statue kit (`GoldenStatue`), its cult
emblem and feed (`CultEmblem`, `CultFeed`) and `make_environment()` (the stars turned off, the one
field it doesn't expose as an export) all carry over unchanged; `test_campaign`'s `_test_skins()`
counts a subclass of a zone's skin script as "its own variant" too, alongside Corporate 2's plaza (the
same script, different values). Only `floor_segment()`, `wall_section()` and `ceiling_section()`/
`hull()` are overridden (`scripts/world/skins/golden_palace/`):
- *The floor* (`GoldenPalaceFloor`): a palace floor's lane, flush marble (`MeshKit.PAT_PALACE_FLOOR`,
  laid out from world position) with a gold inlay runner down its centre (`runner_half_width`), no
  raised kerb or rails (solid stone, not over water, unlike `GoldenWalkways`). Gaps are breaks in the
  floor (GDD §5: "a collapsed floor, an open stairwell, a light well"): the usual orange edge, and
  below it deep shade (`MeshKit.PAT_PALACE_WELL`) darkening with depth, so a gap reads as a hole at a
  glance (pinned by `test_golden_palace_skin`, as every zone's floor is). Dust motes, floor-polish
  glints and speed streaks drift over it (the Golden Zone's `mist_count`/`leaf_count`/`streak_count`
  reused, the still floor's motion cue).
- *The walls* (`GoldenPalaceWalls`): a colonnade. A flush marble panel (`MeshKit.PAT_PALACE_PANEL`,
  with the gold wall-run height marks inlaid in it) runs from the floor to `frieze_top`, exactly as
  calm as every zone's band; gilded pilasters stand above it, every `lot_length` metres, up to
  `pilaster_height`. Between two pilasters, a bay (GDD §5) holds a gallery (a gold-framed opening
  showing the cult's feed or its emblem, `gallery_share`), an alcove (a decorative statue in the same
  niche shape of the statue kit, `GoldenStatue.niche()` (a live Gilded Sentinel's is set into the wall,
  `recess()`, task C4), `statue_share`, mounted at the wall base using the shared recessed mount),
  a tapestry (`banner_share`) or a relief (`relief_share`); otherwise
  the flush panel simply carries on. Through the existing `note_wall_gaps()` hook, low alcoves
  (their statues, recesses and frames) and pilasters are omitted when their footprints cross a physical
  wall gap, including at chunk boundaries. `statue_spots()`, `feed_boards()` and `cult_emblems()` list a
  bay's content the same way the Golden Zone's `GoldenFacades` lists its ledges, frames and banners.
- *Wall gaps open onto a side hall* (task L4, `GoldenPalaceWalls.recess`, 16 m deep, not the Golden Zone's lane):
  the cut ends' faces and the wall across in the same marble (`PAT_PALACE_PANEL`, world position, so it carries on from
  the colonnade either side) up past the pilasters, the well's floor and stone below.
- *The ceilings* (`GoldenPalaceCeilings`, task B3's narrow-ceiling rule): a bridge between galleries or
  an archway (both need every lane; over fewer lanes both fold into the narrower BALCONY) or a hanging
  chandelier (the yacht's weight, reused: it hangs over any width). Every underside reuses
  `GoldenCeilings`' recipe (a flat surface, a darker seam and flush lamps on each lane seam, the
  orange band at the far end); a chandelier's gilded rosette and ring of lamps stay flush with it too,
  so nothing of it ever hangs below the running surface, the rule every ceiling keeps. Structures keep
  `hall_clear_height` above their underside (a flat budget, not a wall-decoration profile: the
  colonnade stands well clear, to the sides, so there is nothing to duck under, unlike the Golden
  Zone's walls).
- *Shader patterns* (ids 70-79, `kit_golden_palace.gdshaderinc`, after `kit_golden.gdshaderinc`'s
  `golden_metal()`/`golden_marble()`, which it calls directly rather than inventing new ones):
  `PAT_PALACE_FLOOR` (70), `PAT_PALACE_WELL` (71) and `PAT_PALACE_PANEL` (72).

**The Beach** (task D10, the owner's request of October 9, 2026; `docs/art/reference/beach_zone.jpg`; the
campaign's zone 6 since task D10c (zone 5 until the Casino joined as zone 4), Campaign below; `data/skins/beach_skin.tres` is also shown with `--skin=beach` and
`tools/showcase/skin_review.tscn -- --skin=beach`): `BeachSkin` (`scripts/world/skins/beach_skin.gd`) is a bright
tropical afternoon on a shore: a sandy street running down to a turquoise sea and a palm island, between bamboo
shacks and tiki bars, with black rust-streaked industrial tanks behind them. No new enemy assets: its
`enemy_variant` is `&"casino"`, the Marketplace's Casino Mob Enforcer (the owner: "reuse one of the existing
cyborg looks, whatever fits the theme of this zone the best"; the pick is a placeholder,
`docs/OPEN_QUESTIONS.md` items 538–559). The gaps are pools, the owner's decision, and the walls open on the beach (the
owner's answer on side walls: "much longer sections where there aren't sidewalls"). Hooks overridden,
builders in `scripts/world/skins/beach/`:
- *The floor* (`BeachSand`): sand (`PAT_BEACH_SAND`: wind ripples, drifts, footprints, flat shells, a damp rim
  round a pool) with boardwalk runs (`PAT_BEACH_BOARDWALK`: planks across the lane, rusty steel plates
  bolted on), runs of one to three `boardwalk_slot`-metre slots hashed by lane and slot (`boardwalk_runs()`, so the runs of
  neighbouring pieces and chunks line up across cuts), a flush bamboo kerb along the building faces, and
  nothing on the running surface stands up or is round. A pool (`cut()`, the shared `standard_floor_cut()`
  with a tank pattern) is a black steel tank sunk flush: the orange lip, strip and halo sit on the
  collision edge as everywhere, beside a dark steel coping that makes them pop against the bright sand, and
  inside is darker than the darkest large floor area by a real margin (the water, with its ripples and glints, at
  most 40% of the luminance of the darkest sand, boardwalk or kerb, and under the plates' and joints';
  `test_beach_skin` computes the budget from the skin's colours: tank steel, rust, tide mark, water). Water is
  opaque, unlit deep teal (`PAT_BEACH_WATER`: long ripples, slow caustics, soft glints) filled to `pool_depth`
  0.45 m under the rim (the owner: "it's pretty good as it is", closer to the rim; deeper than the grapple's
  `pit_depth`, 0.35 m, which `test_beach_skin` pins), like the reference's near-full tanks: from the game camera
  (4.2 m up) water six metres down hides behind the near edge beyond a few metres, this shows from ten or more.
  Above it, the tank's wall
  is black rust-streaked steel (`PAT_BEACH_TANK`: panels, rivets, a flange under the rim, a tide mark and a wet
  line). The fall that ends a run (`fall_death_depth` 4 m) goes on into the water: a runner (an Octodog, a
  wreck) sinks out of sight into the opaque plane, and the chase camera (`camera_height` + `camera_follow_y` x
  the runner's height) is still 2.4 m above the floor at that depth, so it never goes under the water
  (pinned by `test_beach_skin`). Blowing sand, drifting leaves and petals and speed streaks
  (`MeshKit.drift_particles`) are the still floor's motion cue: `BeachSand.drift` gives every 40 m slice to the
  left-wall piece that holds its start, so each chunk has exactly one copy even where the wall switches
  between standing and open inside it (the shared call alone places only slices that fit whole inside a
  piece's range, which left 18-27% of the Beach's chunks without; `test_beach_skin` checks every chunk).
- *The splash* (`BeachWaterWatch`, `BeachSplash`; the owner: "a fall makes a splash"): `wall_section` and
  `wall_gap` add a `BeachWaterWatch` beside the left wall's water plane, which finds the `RunWorld` up the
  tree as `MarketCitizen` does and reads the runner's position and track distance (a read-only visual
  watcher: no collision, no gameplay state written). When the runner's height crosses the water going down
  inside its stretch of street (a floor or a cut's hole never lets that happen anywhere else), it adds a
  `BeachSplash` on the water, a one-shot that frees itself after 1.2 s (a crown of foam, droplets, two
  spreading rings; unlit off-white, no glow, no flash, so nothing for Reduced flashing to turn off; it is the
  water's foam, so it takes the street's light as the water does, `scenery_light_now` and `scenery_tint_now`
  once when it is made, `BeachSplash.in_street_light`) and plays
  the `splash` sound (`tools/asset_gen/sfx_bank_player.gd`, `RunWorld.play_sfx_at`). A grappled runner never
  splashes: the hook fires at `pit_depth`, above the water. The fall's death comes about 0.3 s after the
  splash, and the death screen's pause about a second after that, so the splash plays out under the
  overlay's lead-in. Only the runner splashes (what falls after it, such as an Octodog baited into a gap,
  doesn't). Review a real fall on both renderers with `tools/showcase/splash_review.tscn` (`--skin`,
  `--sky`, `--lanes`, `--grapple`, `--side`), a `RunWorld` with a pool in the runner's lane and no jump.
- *The walls* (`BeachShacks`): shacks one to three 12 m lots long, two to four storeys (`lot_run()`), all
  variety hashed from lot indices. Up to `band_top` (7.2 m) a face is flush and calm, drawn by
  `PAT_BEACH_WALL` from world position in bays of 3 to 4.8 m between bamboo posts, every bay a tone of its own
  (bamboo culms 0.15 m wide with nodes and bundles, palm mat, weathered planks, rusty corrugated sheets, a painted
  turquoise, coral or blue door, roller shutter or serving hatch, bamboo with wordless surf posters, painted
  boards, a mural, painted surfboards mounted flush, culms laid sideways as slats), with big sun-bleached and
  honey drifts over the bays, so a wall seen edge-on (where fine culms blur) is never one flat tone, and the
  wall-run height marks at 2 m and 4 m (a 3.6 cm line of a slightly darker shade of the wall: `wall_mark_color`
  is a multiplier near 0.7) and sand blown against the foot; nothing opens, glows or juts out more than `LIP`
  (0.25 m) there. Each building has one of seven bamboo tones (honey, sun-grey, pale straw, teak, orange-brown,
  warm tan, warm honey). Above `decor_min_height` (8 m): recessed
  verandas (bars with a counter, bottles and paper lanterns, lounges, decks; `_alcove()`, set back so nothing
  hangs over the street, with an unlit striped awning's valance across the top of a bar's or lounge's
  opening), clusters of paper lanterns hung on the faces (`lanterns` items: unlit muted shells, warm-white glow
  inside, within `LIP` of the face), thatch or tin roofs, palms, tiki masks, surfboard racks, flags, bunting
  and swags,
  black steel tanks, water towers, chimneys and dishes behind the roofline, wordless neon silhouettes and
  roof billboards. Everything over the street stays above `OVER_STREET_MIN` (12 m), clear of the
  ceilings' `TOP_LIMIT` (5.4 m over the 6 m underside), and strings of lights are cached templates hung from
  hashed spots. Wall decorations are cached `MeshLayer` templates in left-wall space with the right wall's
  mirrored copies cached once, so building a chunk is plain translations (a 5-lane chunk builds in about
  3 ms, under 25 surfaces). `note_wall_gaps()` is forwarded for the shared hooks.
- *Open stretches* (`BeachSkin.wall_gap`, `BeachOpen` in `beach_open.gd`; the owner: "much longer sections where
  there aren't sidewalls, and the player can see the surrounding area a little bit better"): where a level
  opens the side wall (`TrackBuilder` passes each chunk's slice of the gap, any length, to `wall_gap`), the
  skin draws the standard gap marks (`ZoneSkin.standard_wall_gap`: the orange lip and the orange stripes; the
  dark end slabs stay here, under the shacks' end caps) and, chunk by chunk with every position hashed from the track distance (so a stretch is
  the same however chunks cut it): the beach, from the wall line outward and 1.4 m below the street
  (`beach_drop`: sand, a wet band, a foam line, shallows, the mid sea and the deep, the shoreline swinging
  16-64 m past the wall line, 8 m quads), and on it palms, umbrellas with loungers, surfboards stuck in the sand
  and now and then a bamboo and thatch hut, kept dry, `open_margin` (9 m) from the gap's ends and `open_near`
  (9 m) from the wall line so nothing stands near the runner or the lip, with no collision. The shack at
  each end of a gap is closed with its end and a timber gable (`BeachShacks.gap_end_cap`, task L4: the end the wall
  stops with as well as the one it starts again with, so no black slab shows from the beach side), and the walls' own pieces
  carry the beach on behind them (`BeachOpen.ground`), so the view past a shack's end isn't the void. Every
  chunk stays inside the build budget (`SkinSuite`: under 32 surfaces for a five-lane chunk) with a stretch
  open on either or both sides (`test_beach_skin`, hand-built layouts through `RunSim.layout`). Review: `skin_review --skin=beach --open`
  (four shots per stretch: the game camera at the start and 50 m in, from the lane beside the opening, from
  above), and `--view=run --from=<distance>` with the same flag. `BeachOpen.shore_side` is the shore alone (the
  street's edge, the beach, the sea and its scenery, without the gap marks or the shacks' end caps), which
  `build` draws after the gap marks; the Beach's boss arena, which has no walls at all (`MechaGuppySkin`, Bosses),
  draws its sides with it.
- *The ceilings* (`BeachCeilings`; `kind_of()` by the ceiling's width and the walls it reaches, weights
  `footbridge_weight`, `veranda_weight`, `barge_weight`): a boardwalk footbridge across every lane, a veranda
  deck cantilevered from one building (narrow, reaching one wall) and a hovering party barge (any width, or
  reaching neither wall). Every underside is flat with lamps on the lane seams and the orange far-end band
  from `MeshKit.ceiling_end`; nothing hangs below it, and glows past the far end stay above it
  (`MeshKit.stern_halo` for a barge's engines).
- *Hazards and props* (`BeachProps`, the kit's shared builders): the fence is the shared pink field between
  bamboo-wrapped steel posts in sand-filled drums; the wall sign is the yellow/black hazard frame
  (`MeshKit.hazard_sign`) around a painted surf or bar sign (`PAT_BEACH_PAINT`: unlit, wordless). Pads,
  ramps, speed pads and the finish line are the kit's.
- *Doodads* (`BeachDoodads`): a surfboard rack (small), a cabana or a palm in a planter by `look_seed`
  (medium) and a tiki bar kiosk (large), cached, on `MeshKit.solid()`, no faces, muted.
- *Cult.* The emblem hides on some neon signs and roof billboards and the barge's bronze bow, never smaller
  than `emblem_min_size` and never a hazard colour; the feed plays on TVs behind some upper-deck bars and
  on roof billboards, never in the wall-run band. `feed_boards()` (kinds `deck_tv`, `roof_board`) and
  `cult_emblems()` (kinds `sign`, `billboard`) list them for `skin_review`.
- *The sky and sea*: `night_sky.gdshader` by day, through its existing uniforms (a blue zenith, white
  cumulus, a warm sun glow toward the far end; nothing blooms), and, for a level that wants the owner's
  sunset ("the sun starting to set. Not dark, but the sun's starting to have some purples and oranges in the
  sky"), `data/skies/beach_sunset.tres`, a `LevelSky` to name in `LevelConfig.sky` (a periwinkle zenith, a
  peach horizon, a violet-pink haze, an orange sun glow, orange and pink clouds over lavender shadows, no
  stars, a sea re-coloured to a deep blue; at least three times as bright overhead as the Marketplace's
  sunset and under the glow threshold; `test_beach_skin` pins it; review it with
  `skin_review --skin=beach --sky=beach_sunset`), plus three default-off uniforms: `skyline_hills`
  and `skyline_scale` turn the skyline into smooth low hills (an island, no lit windows) standing on the
  sea, and `abyss_depth` (0.3 by default) is how far below the horizon the sky becomes the abyss colour (the
  Beach: 0.05, a turquoise sea starting at the horizon).
- *Colour rule* (departures from the reference, `docs/OPEN_QUESTIONS.md` items 539–543): the water never glows
  (the reference's glowing turquoise is the pads' cyan); decorative glows are warm white, violet and blue only
  (the reference's pink, yellow, cyan, green and orange neon are hazard hues); string lights and lanterns the
  same; pool frames are flush (the reference's tanks stand proud, which would read as an obstacle); no words on
  signs. `test_beach_skin` holds the skin to it (a glowing colour is a hazard hue when its saturation is at
  least 0.35 and its hue is outside the blue-violet range; no paint is near a hazard's colour).
- *Shader patterns* (ids 80-89, `kit_beach.gdshaderinc`, with `kit_solid.gdshader` including it after
  `face_coords()` and dispatching on the id): colours arrive as sRGB `Vector3` uniforms (`BeachSkin.srgb()`)
  so both renderers agree, `bc_daylight` lifts the lit upright surfaces for the afternoon sun (the kit's
  `shade` is a night city's), and the water's drift (its ripples, caustics and glints) slows to a tenth of its speed under Reduced
  flashing (`reduced_flashing`; nothing else in the zone moves with `TIME`, which `test_beach_skin` checks). Review it
  on both renderers: `skin_review` (`--view=shot`, `--view=run`, `--narrow`), `doodad_review`,
  `floor_cut_review` and `wall_fence_review` with `--skin=beach`.

**The cult emblem** (D7, GDD §5 "The cult"): `CultEmblem` (`scripts/world/meshes/cult_emblem.gd`)
builds each option's 2D vector geometry as a flat mesh (mesh kit conventions: emissive for a neon
ad, lit for paint or the Golden Zone's gold) or a rasterised texture, at any size. The owner chose
option B, the Convergent Triad (GDD §5); the choice lives in `data/world/cult_emblem_choice.tres`
(`CultEmblemChoice`). A skin reads `choice.option` and `CultEmblem.default_scheme(option)` rather
than hardcoding an option: hidden in logos and ads in every zone, shown openly in the Golden Zone
(GDD §5, proposed). `tools/showcase/cult_emblem_sheet.tscn` is the comparison sheet. Gangland hides it
through the kit shader: the skin sets the `cult_emblem` texture (the option rasterised in its unlit
colours, `GanglandSkin.cult_emblem_texture()`), `cult_emblem_share` puts it on some corporate ads, and
`MeshKit.stencil_param(..., emblem)` on some crates, container doors and notice boards. The shader picks
its mip level itself and fades it out before it spans fewer than about 24 pixels, where the three-fold
mark could read like a radiation trefoil. The Marketplace uses geometry instead: it turns the emblem
into a mesh-kit template once (`MarketplaceSkin.cult_emblem()`), then appends it where it hides: a
small warm-white badge on some ads, an unlit bronze mark on some shop signs, never smaller than
`emblem_min_size` (0.9 m, for the same reason). The Neon City (D9) draws it with `MeshKit.PAT_CULT_MARK`:
its solid material carries the chosen emblem's coverage (`CultFeed.emblem_texture()`), and one
rectangle per mark, in UV emblem space (the mark's square spans -1 to 1, a wider range leaves a clear
margin), paints it in the vertex colour on the panel's dark background, glowing at the vertex alpha;
`cult_mark()` fades it out on screen as in Gangland, and the City keeps it at least `emblem_min_size`
across too. It sits as a sponsor's badge where a roof billboard's glyphs end and at the foot of some
towers' neon banners (the glyphs leave its square clear, so nothing overlaps); `CitySkin.cult_emblems()`
lists them. The Corporate zone (D4) draws it the same way: a warm-white badge in a lower corner of some
ads on the street screens and roof boards (never more than `CorporateTowers.SCREEN_EMBLEM_MAX` of a
screen's height), unlit bronze at the foot of some banners; `CorporateSkin.cult_emblems()` lists them.
The Dead Zone (D5) keeps it scorched and half-gone (`MeshKit.PAT_DZ_MARK`, kit_dead_zone: the chosen
emblem from the solid material's `cult_emblem` texture, in its unlit metal, with a ragged burn front
eating part of it away and soot over the rest, never glowing) in a corner of some dead roof boards and
at the foot of some dead neon banners, at least `emblem_min_size` across; `DeadZoneSkin.cult_emblems()`
lists them.
The Golden Zone (D6a) shows it openly, large, in polished gold meeting at its red stone
(`MeshKit.PAT_EMBLEM`, kit_golden: the material's `cult_emblem` texture is the choice drawn in
`CultEmblem.GOLD_COLOR` and `GOLD_ACCENT_COLOR`, `GoldenSkin.cult_emblem_texture()`, embossed and lit as
gold on red cloth or marble): on banners, reliefs on towers, gallery frames, sky bridges
(`GoldenSkin.cult_emblems()` lists them), on the bridges' crests and archways' keystones, and on the
walkways' medallions. The listed ones
are 2 m across or more (so they still read from afar before `cult_mark()` fades them), and every one
stands off its backing far enough never to flicker (`GoldenFacades.RELIEF_STANDOFF`, `EMBLEM_STANDOFF`).

**The cult's feed** (GDD §5, "Cyborg Viewing Devices"): the same wordless broadcast plays on screens
in every zone, in sync, alongside the ordinary ads. It is one shared piece, `CultFeed`
(`scripts/world/meshes/cult_feed.gd`): a glowing, shader-driven material (`cult_feed.gdshader`, the
picture in `cult_feed.gdshaderinc`) that works on the Compatibility renderer, and a helper that adds
a screen to a mesh layer:

```gdscript
var feed: MeshLayer = batch.layer(CultFeed.material())    # shared; one mesh surface per chunk
CultFeed.screen(feed, lower_left, right, up, brightness)  # a rectangle facing right × up, as seen
CultFeed.wall_screen(feed, side, x, d0, length, y0, height, brightness)  # on a wall, facing the street
```

`right` and `up` span the screen as its viewer sees it (the picture is never mirrored, so don't put a
screen in a template that gets mirrored); `brightness` (0-1) dims small or low screens. The material
draws only the picture: give each screen a bezel, frame or TV set of its own. What it shows is a
placeholder (DESIGN-TBD, `docs/questions/d2.md`): a CRT picture in cold white, like the cyborgs' screen
heads, with scanlines, soft static and a slow rolling bar, looping through the cyborgs' calm face
(`cyborg_kit.gd`'s Face.NEUTRAL drawn smooth, in the same cold white: keep the two the same face), the
chosen emblem (`CultEmblem`, faded out below about 24 pixels) and rings converging on a point, one at a
time. Rules for every skin: keep it the same broadcast (vary only how many screens
play it and where), keep other glows off it, and never tint it (only cold white and the emblem's
warm white; purple glitching belongs to hosts). It honours Reduced flashing (the static and the
rolling bar hold still). The Marketplace plays it on some billboards, casino signs and floating ads
(`feed_share`) and on old TVs in some shop windows (`feed_window_share`; `shop_windows()` marks
them with `screen`). The Neon City (D9) plays it on some low buildings' roof billboards instead of
their ad and on big screens hung out over the street from some flush towers, 12 m up or more and
facing the oncoming traffic (anything flat on the City's facades is seen almost edge-on from the game
camera); `CitySkin.feed_boards()` lists both. Gangland plays it on salvaged screens among the posters
of some overpasses' sign gantries, and on a TV glowing in an upper window of some ruins, above the
boarded-up band (`GanglandSkin.feed_windows()` lists those; `GanglandRuins.WINDOW_RECTS` mirrors the
facade shader's window rectangles so the TV's room covers a window exactly). The Corporate zone (D4)
plays it on some low buildings' roof boards and on some of the big screens flush towers hang out over
the street, 14 m up or more; `CorporateSkin.feed_boards()` lists both. The Dead Zone (D5) plays it,
sparse and dim, on the few surviving screens: some low buildings' roof boards and a big screen hung out
over the street from a few flush towers, `feed_screen_bottom` (15 m) up or more;
`DeadZoneSkin.feed_boards()` lists both. The Golden Zone (D6a) plays it in
some galleries' gilded frames and on big screens hung out over the street from some towers, sized to the
street (`feed_hung_reach`), 10 m up or more; `feed_hung_share` at 0 clears the hung ones for a boss
arena, and `GoldenSkin.feed_boards()` lists both. None of them puts a screen in
the wall-run band. `tools/showcase/cult_feed_showcase.tscn` shows a whole loop on three screens.

**Reduced flashing** (Settings): `Settings.apply_visuals()` sets the global shader uniform
`reduced_flashing` (declared in `project.godot`) and `Settings.flashing_reduced`. Hazard shaders
include `kit_flash.gdshaderinc` and use `warning_flicker()`, so a warning becomes a steady glow
instead of a strobe. Anything new that flickers or flashes must honour it too.
