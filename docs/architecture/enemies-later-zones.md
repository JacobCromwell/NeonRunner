# Architecture: Enemies: Barnacle Turret, Buzz Overdrive, Gilded Sentinels, Enforcer Truck, Heavy Cyborg

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Enemies (continued)

**A ceiling enemy: the Barnacle Turret** (C1, GDD §9.8). `barnacle_turret.gd` (`BarnacleTurret`), its
tuning (`BarnacleTurretTuning`, `data/enemies/barnacle_turret.tres`), its model
(`barnacle_turret_model.gd`) and its rules (`barnacle_turret_rules.gd`, The generator):
- **Where.** Its node sits at its mount point on a ceiling's underside (`tuning.ceiling_height`, over
  its lane); it hangs toward -y and faces +z, the player. Its params carry its ceiling (`hull_start`,
  `hull_end`, `first_lane`, `last_lane`); without them it takes the layout's ceiling over its spot. It
  stays in its hatch (hitboxes off, never targeted) until the player is `emerge_seconds` away at their
  speed, then pops out (`barnacle_emerge`; a floor runner sees it too) and stays put.
- **Its gun is the cyborgs'.** `CyborgGun` takes any `GunModel` (`scripts/enemies/gun_model.gd`: the
  three calls it makes on a model, `set_charge`, `aim_at`, `clear_aim`; `CyborgBody` extends it), a
  shooter's own sounds and bolt name (`charge_sound`, `shot_sound`, `shot_name`), and a `path_rule` that
  replaces the floor's check (`path_clear`: fences and gaps) for a target that isn't on the floor. The
  turret's `may_attack`: a rider on its own ceiling (on the ceiling, within its span), ahead, within
  `engage_distance`; never the floor. Its path rule (`_path_fair`): the rider is still on the ceiling past
  each bolt's clear stretch (`end_margin`), and a lane beside the rider's, within the ceiling, has no
  turret body from where the rider is to past the stretch (`body_reach`): there's always a lane to dodge
  into, on a two-lane ceiling (where it's the turret's own) the bolts come well before it, and a second
  turret never fires while the first stands in that lane between the rider and its bolts. It shares the
  cyborgs' airspace (`CyborgAirspace`, above: up to two bursts in the air at once, GDD §9.2 and §9.8,
  owner, October 8, 2026), so both turrets on a ceiling may fire together; its `lane_rule` (`_lane_open`)
  gives the crossfire rule the lanes a rider can dodge into (its ceiling's, never one a turret stands in
  before the bolts pass). Its burst is a small attack: it doesn't take turns with the big ones. Slightly more accurate than the cyborg
  (`aim_error`, `shot_jitter`), with faster bolts (so they can meet a rider closing in at run speed well
  before the turret); the dodge window is `min_warning_time` either way.
- **Body.** A solid `body` hitbox from the underside to the stomp line and its crown below it, a `top`
  that is `upside_down` (Damage and interactions). Both declare enemy attacks, so armor absorbs one
  contact hit using the shared armor/grace rules; unprotected contact is still deadly. Shield, claws
  and dash retain their rules; claws, the dash, a stomp from the ceiling or weapons kill it. Its health is
  in plain laser tier 1 shots rounded to whole shots at the level's `enemy_scaling`
  (`whole_health_at`): 5 (7 at laser tier 1, with `PowerupTuning.tier1_extra_shots`) through the Corporate
  zone, 6 (8) in the Dead Zone and the Golden Zone. Nothing of it reaches more than `REACH_BELOW` (0.8 m)
  under the underside: above a jump from a hover truck's roof and the top of a wall run.
- **Looks.** `BarnacleTurretModel` builds both looks from the same dome, chest cannon and size: mechanical
  (armour plates, a riveted band, a dim cold-white sensor), or a furry creature (low-poly tufts, googly
  eyes, floppy ears) on `&"scavenger"` and `&"casino"` (Gangland, the Marketplace; `is_creature`), with a
  palette per zone variant. Only its muzzle ever glows a hazard colour: enemy-fire red, swelling over the
  charge-up and the burst (a steady swell, nothing strobes). A hit's flash is softer with Reduced flashing.

**A floor cutter: the Buzz Overdrive** (C2, GDD §9.9; from Corporate 1 through the Dead Zone and the
Golden Zone). `buzz_overdrive.gd`, its tuning (`BuzzOverdriveTuning`, `data/enemies/buzz_overdrive.tres`),
its model (`buzz_overdrive_model.gd`), its rules (`buzz_overdrive_rules.gd`, The generator, Floor cuts),
its pattern (`data/patterns/buzz_overdrive.json`) and its sounds (`tools/asset_gen/
sfx_bank_buzz_overdrive.gd`: `buzz_rev`, `buzz_charge`; its death is the hover truck's `truck_explode`).
It is the visible cause of a floor cut the generator planned (B4's `FloorCutPlan`, `FloorCut`), keyed to
the player's distance like the cut, so it does the same on every attempt and at every frame rate:
- **Its encounter.** Its entry stands at its cut's end, in its lane (`cut_of`). It shows parked in its lane
  `appear_distance` ahead (the director spawns it far ahead, `spawn_lead` 300 m, hidden until then; its
  hint is now presented on the level introduction). When the player is a charge's distance from it (`FloorCutPlan.lead_at`) it
  rolls ahead of them at that distance for `roll_seconds`, revs for its rev (`rev_at`: its warning, the
  level's enemy scaling from 2.93 s in Corporate 1 to 2.5 s in the Golden Palace, the only thing that
  scales; its health stays 20) while it keeps rolling, then charges back at the player (`charge_seconds`
  to meet them, at `charge_speed` stretched by the pace), cutting the floor behind it (`advance_to`), and
  runs on `run_past` metres past them, off the screen, gone (retired only then: its cut runs to its
  start). Its distances follow the pace (the charge's from `charge_distance()`), its seconds don't.
- **Its warning.** The rev: the spin-up (`buzz_rev`), its eyes flaring and a red line over the lane it's
  about to cut, from just behind the player to its blade (then, as it charges, the stretch it still has
  to cut; the Octodog's lunge-line red, widening over the rev and pulsing, only widening with Reduced
  flashing). Sparks fly from the blade as it cuts (none with Reduced flashing). Its rev and charge play
  on its own voice, which moves with it (the world's voices stay where a sound starts), at full volume
  from a charge's distance (`sound_full_volume_distance`); the 2.45 s spin-up (under the library's 2.5 s
  a sound) is stretched over the rev by pitch (`rev_pitch`), so it always ends as the charge starts.
- **Contact and kills.** Its blade is an `attack` hitbox, narrow and centred on its lane (0.7 m wide, 2.4 m
  tall: a jump doesn't clear it), so wall and ceiling riders are never touched; no other part hurts. The
  armor and the shield block it, and then `FloorCut.hold_under` holds the floor under the player for
  `GameRules.cut_hold_seconds`: its cut runs on 1.5 s ahead of where it meets the player (0.6 s at 2.5
  times the run speed), so a player who stays falls once the hold is over. Claw-immune, not stompable (no
  `top`); the dash smashes it (`dash_kills`), into the cut lane, where only the grapple hook saves the
  runner. Weapons: health 20, so 22 laser tier 1 shots (G4's rule) and 15, 10 and 7 at tiers 2-4; a kill
  before its charge saves the floor, mid-charge `stop()` ends the cut where it dies. It rolls in 50-60 m
  ahead: beyond laser tier 1's 42 m and within the other tiers' 70 m, so on a plain track tier 1 never
  stops it before it has passed the runner and tiers 2-4 kill it during its rev at the zones' speeds
  (23.4-25 m/s); at the harder tiers' 28-30 m/s tier 3 (and tier 4 at 30) stop it mid-charge
  (`test_buzz_overdrive`; DESIGN-TBD, `docs/questions/c2.md`).
- **A big attack that never waits.** Its rev and charge are one big attack (`is_major_attack_active` from
  the rev until it's gone): the generator planned its moment, so it never waits and the others wait for
  it. **It claims its turn** (task FIX2). Reporting itself only from its rev, it let another type's attack
  that asked a moment before (when only its roll was on) start and run on into its rev: over the seven
  levels that have it, at 3, 5 and 6 lanes on 13 seeds each (273 runs of `big_attacks.gd`), 73 of 380
  tanks revved into a drone's barrage, a hover truck's lurch or cannon shot or a Resonator's pulse, 87 s
  of two big attacks at once (FIX1's 0.62 s in Dead Zone 1 at 5 lanes: a truck's lurch asked for 0.85 s
  before its rev). So, like a Gilded Sentinel, a tank that rolls in (`takes_turns()`: its cut has a roll,
  `lead`, and big attacks take turns) claims its turn `claim_seconds` (2.5 s) before its rev
  (`claiming()`: it reports itself from then on, so another type's big attack that gets ready meanwhile
  waits) and asks `major_attack_blocked` as its rev would start: with one begun before its claim still on
  (or its shots on their way, or one that can't wait begun meanwhile: a Bad Dream bursting out of a host
  killed then), it gives up its turn and lets the runner pass (`PASS`, last of its states
  so the measure tools' event logs keep the others' numbers): no rev, no line, no cut (`FloorCut.stop`, its
  lane stays whole), it speeds off ahead (`_passing_front`, keyed to the runner's distance) and is out of
  view and gone `pass_seconds` (3 s) later. Over the same runs: no overlap; 378 tanks revved and 2 let the
  runner pass (both behind a Resonator's pulse), none revved into another attack; the others lost 57 of
  2,163 drone barrages, 14 of 632 cannon shots and 7 of 527 lurches (no Octodog charge, Bad Dream slash or
  Resonator pulse, and no enemy went without its attack); event logs stayed identical in 199 runs, and the
  other 74 first differ within a tank's turn (its claim until it's gone). A boss's tank (its cut planned
  without a roll: Hostile Takeover's drop, whose boss keeps its own attacks off it) and every tank with the
  switch off rev as planned, as before (DESIGN-TBD, `docs/questions/fix2.md`).
- **Looks.** `BuzzOverdriveModel`: a tracked hull with skirt armour, a sloped glacis, a low turret with a
  slanted red eye slit under a dark brow on each side, exhaust stacks, and a giant vertical saw on braced
  arms whose teeth glow hot orange-red (the deadly part); matte military gunmetal and olive, scorched and
  rusted where enemies weather (`&"burned"`, `&"scavenger"`). Four draw calls, about 1,300 triangles: the
  hull is one surface in vertex colours under one matte material (`HullBatch`), then the eyes, the blade's
  disc and its teeth; the meshes are built once per look (about 1 ms, at the first one's spawn) and shared.
- **Cheap to run.** Its sparks come from its own emitter (one `CPUParticles3D`, `sparks_per_second`, only
  while it cuts), never the shared bursts; its sounds from its own voice; it looks up its cut's track piece
  only from its rev on; everything else a frame is a few transforms.
- **The Resonator** keeps its pulses off every cut (its rules run after these: `busy_stretches` holds each
  cut's whole window, and `Resonator.pulse_clear` counts a cut's stretch as a gap).
- **Company** (task L2; The generator, Company for the Buzz Overdrive). In a campaign level, a tank with no
  Enforcer Truck near it (and not the level's introduction of it) shares its stretch with cyborgs that hold their
  fire through its attack, rows of holes or fences and wall fences, all kept out of its lane and, over its attack,
  out of the escape lane beside it (its cut's `company` key). Nothing it adds is a big attack, so its turn is as
  before (DESIGN-TBD, items 933-941 in `docs/OPEN_QUESTIONS*.md`).

**A wall enemy in a niche: the Gilded Sentinels** (C4, GDD §9.11; Golden 2 brings them in, the Golden
Palace keeps them). `gilded_sentinel.gd` (`GildedSentinel`), its tuning (`GildedSentinelTuning`,
`data/enemies/gilded_sentinel.tres`, F6 "Enemy: Gilded Sentinel"), its rules (`gilded_sentinel_rules.gd`,
The generator), its patterns (`data/patterns/gilded_sentinel.json`: one, one that swings twice, a pair
across the street), its cut's shader (`gilded_sentinel_cut.gdshader`), its sounds
(`tools/asset_gen/sfx_bank_sentinel.gd`: `gilded_sentinel_grind`, `_swing`, `_break`) and its hint
(`enemy:gilded_sentinel`). DESIGN-TBD throughout (`docs/questions/c4.md`):
- **In its niche.** A wall enemy (`side`), standing in a niche set into the wall at wall-run height: a
  2.6 m statue standing out from the wall would block a wall run at all of its heights, so the statue (the
  Golden Zone's kit, `GoldenStatue`, at `statue_scale`) stands in the recess with its front
  `statue_inset` (0.02 m; 0.008 m once the relief squashes it, task K2, below) behind the face. Nothing of it reaches over the
  wall-run path (a wall runner's body lies along the face); only its swing does. The Golden Zone's skins open the
  niche (Zone skins: the statue kit's `recess()`, `GoldenSkin.note_wall_enemies`); in any other skin (quick
  play) it stands in front of the wall in the kit's `niche()` as a review stand-in, its hitboxes the same
  (the whole statue, not a relief). At rest it holds its halberd upright at its side, the blade turned along the
  wall (the kit's decorative `guard` pose, `GoldenStatue.POSE_GUARD`: at rest it is the decorative guard with its
  eyes lit), so it fits the niche whole.
- **Seeing it** (task H1, GDD §9.11, owner, October 8, 2026: "too hard to see inside the arched recess").
  Seen from down the street the wall is almost edge-on, and whatever stands deep in an opening hides behind
  its near edge: a point `x` deep shows through it `x * distance / (the runner's distance from the wall)`
  further along it, so at 20 m with the wall 6 m away a statue 0.4 m deep is hidden behind a 1.4 m opening's
  edge and only a sliver of it shows, in a black hole. The build can't do much about the depth: **collision
  stays physical**, so nothing of the statue goes in front of the wall face (a wall runner's body lies along
  it; a statue standing out of the wall would block the wall run, a design change for the owner) and the solid
  `body` hitbox (`niche_depth - 0.1` deep behind the face) reaches as far back as the statue does (the suite
  checks both). **The statue moved only about 4 cm; most of the gain was lighting and a wider opening**: the owner
  said it was still too far back (task K2, the bullet below).
  - *Placement from the real outline.* `GildedSentinel.reach_out()` measures the statue's rest frame by its
    vertices (cached per frame and turn), not its turned bounding box, which overstated how far it reaches
    toward the street by 0.033 m: its real front was 0.063 m behind the face, not the 0.03 it was set to, and
    is now `statue_inset` (0.02 m) behind it exactly.
  - *A shallower, wider niche.* `niche_depth` 0.78 m (from 0.9: the statue is about 0.7 m deep as it stands)
    and `niche_width` 1.8 m (from 1.4), so more of the statue and of the niche's back show at a grazing angle.
    Both are tunables the skin reads (`GildedSentinel.niche_rect()`, `niche_depth()`); the hitboxes follow.
  - *On the wall face* (task K2, owner, October 2026: "still too far back in the wall recess for the player to
    see"; docs/questions/k2.md). A statue 0.44 m back with its back 0.7 m behind the face still hid behind the near
    edge of its opening: a point `d` behind the face shows through it `d * (distance along the street / the runner's
    distance from the wall)` further toward the runner, a ratio of 3.2 at 20 m on five lanes (12 m on three), so
    from there only 44% of its width showed. The statue is now a high relief: squashed along the wall's normal to
    `statue_relief` (0.4: 0.27 m deep), about the face, so its front stays `statue_inset` times the relief (0.008 m)
    behind it (the decorative statues' fronts stand `statue_base_inset`, 0.02 m, behind it), in a niche
    `niche_depth` 0.4 m deep and `niche_width` 2.0 m wide (the decorative alcoves'; 89% of the statue shows from 20 m
    on five lanes, `test_gilded_sentinel` measures it). **Nothing is in front of the face** (the suite checks every
    vertex of the live statue and the decorative ones), so the wall run, a wall runner's body (it lies along the
    face) and the runner's side clearance are as they were; the solid `body` and `top` hitboxes, still behind the
    face, are shallower with the niche (`niche_depth - 0.1`: 0.68 m to 0.30 m deep), where nothing in play reaches.
    The wider niche moves a Sentinel by up to 0.10 m in the builds where `in_chunk` keeps its niche inside a track
    chunk (`niche_width / 2 + CHUNK_MARGIN`, about 26% of random-seed Golden 2 and 3 builds). Only in the Golden Zone's skins
    (the review stand-in in other skins is the whole statue). The relief is squashed by the statue's node (`Statue`'s
    transform, `_set_relief`), so the baked frames are shared and unchanged. **The swing steps out**: as it draws its
    halberd back the statue un-squashes about the face to `statue_swing_relief` (0.7) and goes back as it recovers
    (visual only: the swing's cut, hitboxes, marks and slash are the same), so its halberd still comes out of the face
    over the wall-run path as a swing always did: about 0.71 m at most (1.22 m at the wind-up's peak and 1.01 m in the
    swing before K2; the 0.54 and 0.78 m of the raised end pose are not its fullest reach). The decorative statues
    have the same relief (`GoldenSkin.decorative_statue_basis`, from `GildedSentinel.statue_relief()`; Zone skins).
  - *Lit, not black, every niche alike.* `GoldenStatue.recess()` draws the inside of every statue niche, a live
    Sentinel's and the decorative alcoves' (outdoor facades and the Palace), in warm bronze stone
    (`LIT_BACK`, `LIT_SIDES` for the surface seen through the opening, `LIT_CEILING`): plain lit surfaces,
    never the kit's glow channel (GDD §5: gold, stone and cloth never glow, and only hazards glow in hazard
    colours; `test_golden_skin` pins it). The live niche is not the only lit one: the owner asked for the
    decorative statues to be there so a live one can surprise the player (`docs/USER_REQUESTS.md`), so it is
    told from them by its red eyes (`EYES_IDLE`, a little more than at first) and its warning. The statue's
    gold is lifted in albedo by the decorative statues' amount (`STATUE_LIFT`).
  - *The flare tints it red.* `gilded_sentinel_niche.gdshader` (blend_mix, unshaded, no textures, its colour a
    plain vec3 in linear light: the same on both renderers) lays the eyes' red over the live niche's far side
    and back as they flare, rather than adding red to it (red added to bronze goes orange, a hazard's colour
    of its own, about 13 degrees against Sentinel red's 3). `niche_tint_alpha(flare)` rises fast (full at 0.3
    of the warning, with no throb) so the blended colour is hue 0.5 to 6 degrees from then on and passes
    through the oranges only in the first 0.1 s; `test_gilded_sentinel` computes the hues.
  - *Room around it, and the chunk's end.* A decorative wall-base alcove that would overlap or touch a live
    niche (less than `GoldenSkin.NICHE_CLEARANCE`, 0.3 m, of wall between the frames) is left out, hole and
    statue (`GoldenSkin.crowds_niche()`, used by the facades and the Palace's colonnade), so a live niche is
    never overlapped by a decorative one, and not otherwise set apart. The walls are built a chunk at a time and
    each chunk knows only its own Sentinels, so a facade statue's alcove never reaches across a chunk's end
    (`GoldenFacades.chunk_straddled()` in `_place_statues`, about 6% of the statues: a chunk that skipped an
    alcove for a niche beside it would otherwise leave a see-through slot where the next chunk cut its part of
    the hole); the Palace's bays (every 8 m, centred 4 m off the chunk lines) cannot straddle one.
    `statue_spots()` lists the candidate places.
- **The attack**, once, as the runner comes: when they're `warning_seconds` (and `strike_lead_seconds`) at
  their speed from the stretch it guards, it asks the director (below), then warns: its eyes flare (their
  own material, and their red light filling the niche, what a runner sees from far down the street where
  the wall is seen edge-on), stone grinds, it draws its halberd back, and the red marks of its cut light
  up, filling toward the runner (the band on its wall, on the face; the outer lane's floor). The warning is
  0.6 s (GDD §9.11, owner, October 8, 2026: half as long as first built); the eyes flare through all of it
  and the draw-back takes its last `raise_share` (half, 0.3 s: `raise_seconds()`), so they come first, and
  the grind sound (`gilded_sentinel_grind`) is as long as the warning (regenerate it alone with
  `tools/godot.sh sfx --only=gilded_sentinel_grind` after changing either; the suite checks its length). What
  0.6 s leaves a runner: on the floor, a lane change started after the 0.35 s reaction time the boss suites
  assume is in time; a wall runner who stepped on the wall before the warning (in the band, 0 to 0.55 s
  before) saw none before the cut, and escapes with two moves (off the wall, then a lane change) started
  within 0.50 s of it; passing above or below the band by timing the wall entry has to be planned from the
  statue at rest, since the jump of the high route (`wall_entry_time` + 0.08 s + the jump's apex time, 0.6 s)
  starts as the warning does (`test_gilded_sentinel`'s reaction checks pin all of it). Then it
  swings as the runner reaches the stretch (`section_length`, around its niche; a slower runner: it holds,
  raised, up to `hold_max_seconds`; a faster one may get past, since the warning always runs its whole
  length): for `strike_seconds` its cut is live, two `attack` boxes over the stretch, the band on its wall
  (`band()`: the heights around the free wall-entry height, from the face out over a wall runner's whole
  body, `wall_reach`) and the outer lane (from `wall_reach` out to `lane_margin` short of its inner edge,
  from the floor up to the band's top, above any jump), with a red slash through both. One that swings
  twice (`params.swings` 2) cuts the stretch before its niche, then swings back across the stretch past
  it, each as the runner reaches it. So: on the wall, stepping on right before it is hit, a jump onto the
  wall (or a ramp) runs above the band and an early entry slides below it; on the floor, anywhere but the
  outer lane is safe.
- **Protection.** Its cut is an enemy attack: armor and the shield block it; the dash passes through
  unharmed and leaves it standing (`dash_kills` off, as for the Resonator's wave). Its body is a solid
  `body` box in the niche, behind the face, where nothing in play reaches.
- **Killing it.** Weapons (health 15: 17 laser tier 1 shots with G4's rule; auto-fire picks it out in its
  niche), or a kick: a wall jump made right by its head on its wall (`can_kick`: the runner's height from
  `kick_below` under its helmet's base to `kick_above` over its crest, within `kick_along` of it along the
  track) stomps its `top` through DamageRules (`Player.receive_hit(top, true)`: it's defeated, the runner
  bounces). A wall jump leaps out to the outer lane and never comes down on a statue in the wall, so the
  push-off is the stomp; it hears the wall jump as `Player.movement_event`, never by checking each frame.
  Down, its eyes go dark and it slumps in its niche until the runner is far past.
- **Big attacks.** Its attack counts as one, from its eyes' flare until its last swing's cut is over
  (`is_major_attack_active`), so the others wait for it. A statue can't wait (the runner is gone by then),
  so it claims its turn `claim_seconds` before its warning (`claiming()`: it reports itself from then on,
  and another type's attack that gets ready meanwhile waits), then asks `major_attack_blocked` as its
  warning would start: with another type's attack begun before its claim still on, it gives up its turn
  and lets the runner pass, with no warning and no swing (`history` "pass"). So its cut never overlaps
  another big attack. The generator keeps floor cuts, Octodog runs and ceilings' landings off it, and
  every big attack off a level's first, so that one always swings. In simulated runs of Golden 2 and the
  Palace (god mode, the middle lane, at 3, 5 and 6 lanes) 32 of 36 Sentinels swung with the claim (the
  rest met a long attack begun before it), 21 without; the other types' big attacks went from 148 to 135
  (the Resonator's pulses also keep off the Sentinels' turns, so a busy level may get one visit fewer).
- **Cheap.** The statue is one mesh of two surfaces (the gold on the skin's solid material, the eyes on
  each Sentinel's own), its frames baked once from the kit (`frames_for`: rest to wind-up, the swing, the
  recovery, the husk; mirrored on the left wall so it swings toward the runner on both) and shared by
  every Sentinel, so animating it is a mesh swap when the frame changes; the marks and slashes are a few
  quads on one small shader; its bursts are the shared ones. Reduced flashing: the eyes rise steadily
  (no throb) and a swing's flash is a single, softer fade.

**Behind the runner: the Enforcer Truck** (C6, GDD §9.13; from Corporate 2, then every later level with an
Octodog or a Buzz Overdrive). `enforcer_truck.gd` (`EnforcerTruck`), its tuning (`EnforcerTruckTuning`,
`data/enemies/enforcer_truck.tres`, F6 "Enemy: Enforcer Truck"), its model (`enforcer_truck_model.gd`), its
marker (`enforcer_truck_marker.gd`), its rules (`enforcer_truck_rules.gd`, The generator; it has no
patterns), where and how it shows itself (`enforcer_truck_room.gd`, `enforcer_truck_view.gd`; task C6b), its
blast (one of the shared fireballs, `RunEffects.fireball`; C6b, task H6), its sounds (`tools/asset_gen/sfx_bank_enforcer.gd`: `enforcer_siren`,
`_whine`, `_laser`, `_pickup`, `_crash` as it's hit; every wreck's blast is the hover truck's `truck_explode`)
and its hint (`enemy:enforcer_truck`). DESIGN-TBD numbers throughout (`docs/questions/c6.md`, `c6b.md`):
- **The chase.** Where its entry's `at` says (the runner's distance), its siren whoops and it drives in from
  `arrive_gap` (45 m) behind to `follow_gap` (8.5 m: behind the camera's 7.5 m), keeping its place relative
  to the runner's distance, never closer than `MIN_GAP`. It takes each of the runner's lane changes
  `lane_delay_seconds` (0.8 s, GDD §9.13) later (a log of their lane changes on the level clock), over
  `switch_seconds`, so a late dodge leaves it in the lane just left. It holds still while the runner is
  down. After `chase_seconds` (25 s) it gives up, never mid-volley or with a bait on, and drops back at
  `leave_speed` until it's out of play.
- **Seen from behind.** Behind the camera, it shows by its headlights' beams and its light bar's red and
  blue washes on the floor of its lane (`EnforcerTruckModel.floor_lights()`: three flat, unshaded,
  additive vertex-coloured strips, soft-edged; the bar's halves take turns at `flash_hz`, both lit and
  steady with Reduced flashing) and a marker at the screen's bottom edge under its lane (a CanvasLayer
  under the HUD; the lane's point unprojected with the current camera; a red and blue chevron with a pip
  for each rider, sized with `UiTheme.px`).
- **Its volleys** (GDD §9.13: lasers at the runner's lane). Each is warned by a red line on the floor of the
  runner's lane, from just behind them to `line_ahead` ahead (widening and pulsing, only widening with
  Reduced flashing), and a rising whine on its own voice stretched by pitch over `warning_seconds` (1 s).
  Then `shots_per_volley` shots `shot_gap_seconds` apart, each a column of bolts (`bolt_heights`: over a
  slide and a whole jump, so only leaving the lane dodges it) fired from its front through
  `ProjectilePool.fire_enemy` (red enemy bolts, `LASER_NAME`), reaching the runner `bolt_flight_seconds`
  later. The line stays until the last bolt has passed. A volley starts only when it chases at its follow
  gap and its interval is over (`first_volley_seconds` after it arrives, then `volley_interval(riders)`
  from the last one's end), with the runner on the floor and a lane beside clear to step into until the
  volley is over (`escape_clear`/`lane_open`: no hole, fence, floor cut, doodad, floor enemy or hover
  truck's lane, from `escape_reaction_seconds` after the warning), and never from `hold_seconds()` (2.7 s)
  before one of its baits attacks (an Octodog's wind-up, a Buzz Overdrive's rev: so a volley is over before
  it closes up, and before a tank claims its turn) until the attack is over; then it also gives up any place
  it held in the director's queue. A volley is a big attack (`is_major_attack_active`): it asks
  `major_attack_blocked` before its warning, and the others wait for it.
- **Its baits.** It declares `charge_bait` (Enemy charge contacts above) and is immune to weapons (never
  targeted, no health bar), stomps, the claws and the dash (`claw_immune`, not `stompable`, no `dash_kills`;
  it never touches the runner anyway). Its body hitbox (`hitbox_size`, a little smaller than its look) is
  what a charge must touch: an Octodog's lunge or a Buzz Overdrive's charge that crosses it destroys it, as
  the player's kill (then its blast, below). While an Octodog attacks (`close_lead_seconds` before its wind-up until it gives up)
  it closes right up to `close_gap_for(dog, pace)` (2.4 m, inside where the lunge ends,
  `lunge_overshoot` behind the runner), its model low enough to stay under the camera's line of sight to
  the runner's feet. A dodge as the lunge begins leaves it in the lunge's lane; one at the wind-up's start
  takes it out in time (`test_enforcer_truck_runs`).
- **Holes.** It hops every ordinary gap in its lane (a bounce keyed to its own distance, until its rear has
  cleared it); a gap wider than `max_hop_jump_fraction` of a jump at the level's speed, or a begun floor
  cut not solid under its front or middle (`FloorCut.solid_at`), wrecks it (`&"gap"`, `&"cut"`: the
  player's kill, `enforcer_crash`, then its blast, below). None of a level's own gaps is that wide (0.6 of a jump; the levels' are
  0.35-0.6), but each campaign level's couple of wider gaps are (0.7; task G7, Wider gaps below), one in its
  chase where one fits.
- **Riders.** Cyborgs the runner passes alive (`Cyborg.Mode.PASSED`) are recorded with their lane and spot;
  when its front reaches one in its lane it climbs aboard (a crouching gunner on its roof, `set_riders`, a
  pip on the marker, `enforcer_pickup`), up to `max_riders` (3), and a cyborg node still in play leaves
  it. Each rider makes the next volley come sooner (`rider_rate_bonus`), and destroying it pays
  `rider_bonus` for each (`&"enforcer_riders"`). Window cyborgs (another type) never board, and hosts don't
  (`picks_up_hosts`, DESIGN-TBD).
- **Looks.** `EnforcerTruckModel`: a wheeled riot truck (a push bar, a sloped armoured nose, a slatted slit
  windscreen, a long armoured box with slit windows, the light bar on the roof, its riders' hatches and a
  gun ring), its body one mesh in vertex colours under one matte material, in three looks by the zone's
  variant (`look_of`: clean police paint on `&"city"` and `&"vr_runner"`, weathered on `&"burned"` and
  `&"scavenger"`, gilded on `&"golden"` and `&"casino"`); only its headlights, its light bar (red, and a
  blue well off the safe cyan) and its riders' screen faces glow. Its riders are crouching cyborg gunners
  sharing two meshes. Four draw calls and two per rider shown, about 1,500 triangles with three riders;
  meshes and materials are built once per look and shared (`warm_up` builds them with the level), so a
  truck spawned in play makes none.
- **Showing itself** (C6b; GDD §9.13 "Showing itself", the owner, October 8, 2026). Now and then it speeds up
  beside the runner in a lane next to theirs, its front `show_ahead` (4 m) ahead of them so its body is level
  with them and the chase camera shows all of it (its riders and light bar too), stays `show_seconds` (3 s)
  and drops back: as it arrives (`show_on_arrival`, pulling up from its arrival gap) and once more mid-chase
  (`show_count` 2), `show_spacing_seconds` (6 s) apart; its first volley waits up to `show_wait_seconds` for
  the first. `show_phase` goes NONE, PULL_UP (`show_close_speed`), ALONGSIDE, DROP_BACK (`show_drop_speed`,
  `show_yield_speed` when it gives way), back to NONE and the runner's lane; `show_lane_now()` gives the lane
  it may take now or why not (`show_problem()`), and `history` notes `show`, `alongside`, `drop_back`,
  `give_way` and `shown`. Its rules:
  - **A turn.** A showing is a big attack's turn (`is_major_attack_active` from its start until it's dropped
    back `EnforcerTruckRoom.OUT_OF_VIEW` behind the runner): it asks `major_attack_blocked` before it starts,
    so it never meets a volley's, a bait's or another type's warning or attack, and it never fires while
    beside the runner. It's back behind them `show_margin_seconds` + `close_lead_seconds` before a bait's
    turn (an Octodog's planned wind-up, a Buzz Overdrive's claim on its turn, from the layout and the dogs and
    tanks in play): it shortens its stay for one (`hold_for`, never under `show_min_seconds`) or doesn't show.
    Beside a hover truck or a Gilded Sentinel (task C6e; the owner, October 9, 2026, GDD §9.13 "Making room where
    there is none": they no longer stop it, as long as the runner keeps a free lane), it fits between what of them
    can't wait for a turn, a hover truck's entrance (its banging to its emerging) and a Sentinel's turn (its claim to
    its last swing; `EnforcerTruckRoom.fixed`, `seconds_to_fixed`): never begun during one, its stay shortened to be
    back `show_margin_seconds` before the next (`hold_for`'s `to_fixed`), giving way to one that comes sooner. Their
    other attacks (the hover truck's cannon and forward lurch) take turns and wait for it, as a Resonator's pulse does.
  - **Solid, safe sides.** While beside the runner, a lane blocker along its body to `blocker_ahead` past its
    front (`TrackBuilder.add_lane_blocker`, `LAYER_LANE_BLOCKER`) bumps a lane change into it back (Player's
    `lane_blocked`, never a hit: its 2 m body hitbox in a 2.4 m lane leaves the bump clear of it). As the
    runner moves toward its lane (a lane change or a bump that way, `movement_event`), leaves the floor, or
    anything below stops holding, it gives way.
  - **Never the only free lane** (`EnforcerTruckRoom`, the layout read once by lane at load; the truck adds
    what's in play). Its stay must leave the runner a lane to dodge into for everything blocking their lane
    (`can_dodge`: holes, fences, doodads, floor enemies, a floor cut's lane window; with `DODGE_ROOM_SECONDS`
    to step around each) at 3, 5 and 6 lanes; to a runner by a wall (an outer lane) it shows itself two lanes
    in, leaving them the lane between (`sides`, `escape_lane`; task C6c, the owner's answer of October 9, 2026,
    GDD §9.13 "Room to show itself": beside them it would take their only lane to dodge into, and at 5 and 6 lanes
    it would hide up to 25 m of their lane from the camera, which sits inward of them), held to the same rule both
    ways (the lane between open where theirs is blocked, theirs open where the lane between is); never to a runner
    off the floor; and its own lane must be clear where the camera sees it there (`lane_clear`: no fence, doodad,
    floor enemy, pad, speed pad or ramp, nor a hole too wide to hop until it's rejoined the runner's lane; it hops
    the others), so it's never beside a lane the runner needs. A lane a hover truck holds (`held`, `held_lanes`: from
    where its lane is kept free before its burst to where it has left, and one in play's; task C6e) is a wall to the
    runner and never the truck's, and the truck never stands between the runner and it (it would hide it): a runner
    beside it sees the truck two lanes in on their other side, the lane between left free, and at 3 lanes a runner
    beside it has no lane for it. What blocks the runner's lane counts as far as its stay reaches (`can_dodge`'s
    `clip`: once it's back behind them every lane is theirs), a floor cut's lane from its charge on (`leave_late`: a
    runner baiting a Buzz Overdrive keeps to its lane until the cut runs back toward them).
  - **Never hides anything.** `EnforcerTruckView` (the run camera's resting view) checks at load, for its
    look and lane count (`fits_for`, with `EnforcerTruckModel.profile`), that every corner of it is on
    screen and nothing of the runner or the floor of their lane and the far side is behind it; enemies its
    body would hide from the camera keep it from showing (`shadow_clear`), so a hazard's warning stays in view.
  - **Seen and heard.** Its siren swells as it pulls alongside (`siren_swell_db` up to full); its marker fades
    while it's in view; its light bar and floor lights carry on as before.
  - **Its planned window** (task C6c; The generator, Enforcer Trucks). Where the generator planned a window in
    its chase (params `show`: `show_window()`, `show_at()`), it claims its turn among the big attacks
    `show_claim_seconds` (2 s) before the runner reaches where the showing is due, until it begins or the runner
    is `show_window_slack_seconds` past (`claiming()`, part of `is_major_attack_active`): another type's big
    attack that gets ready meanwhile waits for it, one already on ends first; and it starts no volley that would
    still be on there (`_holds_for_showing`). It still shows itself wherever play allows before; once it has,
    the window has done its work. A showing beside the runner tries a lane clear for its whole stay first, else
    one clear for its shortest. A window planned with its bait's claim during it (its `mode` "claim" or "calm",
    task C6e; `_claim_window_now`) stays alongside until it must be out of view `show_margin_seconds` before the
    Buzz Overdrive's rev (`hold_claimed`), and that claim doesn't make it give way (`_attack_on`'s `skip_claims`).
    One planned in the level's calm start ("calm", `calm_start()`) arrives inside the run-up at its follow gap,
    already chasing, shows itself as it arrives, and fires no volley before the run-up's end (`_ready_to_fire`).
- **Its blast** (C6b; the owner, October 8, 2026: a visible explosion however it's destroyed). Every wreck (an
  Octodog's lunge, a Buzz Overdrive's charge or cut, a gap too wide to hop) lurches on into the chase camera's
  view over `wreck_surge_seconds` (its front to `wreck_gap` behind the runner; in a hole, until its nose meets
  the far edge; spinning out from a charge, nose-diving on its rear into a hole so nothing of it rises into the
  camera it passes under), trailing sparks, then blows up (`_explode`): its model and riders gone in one of the
  shared yellow-and-red fireballs (`RunEffects.fireball`, GDD §11, the owner, October 8, 2026: every explosion is
  one; merged in from task H6), as big as its blast (`blast_size`: `blast_radius`, smaller in the runner's lane,
  `blast_radius_in_lane`), its fire burning `blast_seconds` (`fire_pace`), held in (`FIRE_SPREAD`, less in the
  runner's lane) and with no smoke, so everything it draws only adds light and nothing of it can hide the
  runner; the shared `RunEffects` smoke burst and debris (a chunk for each rider), a shake and `truck_explode`.
  The fireball is carried along with the wreck (its `carrier`: the pool moves it with the truck node), so it
  burns where the chase camera sees it, falling back at `blast_drift`, and the truck is freed after
  `blast_seconds`; the pool then lets it go. Reduced flashing softens it as it does every fireball, and its
  materials are drawn with the level's effects (`ShaderWarmup`).
- **Cheap.** A few transforms a frame, its hole checks walking each lane's gaps with a cursor; its bolts
  are the projectile pool's. A showing's checks read the stretches `EnforcerTruckRoom` indexed at load.

**A heavier cyborg with a gatling: the Heavy Cyborg** (S1, GDD §9.16; owner, October 23, 2026: one of the Ice Lab's
two new enemies, from Relay Station, then Specimen Vault and all three of the Golden Zone's levels). It is a cyborg
with a drone's barrage in place of the arm cannon's bursts, so it is built on the cyborg's files rather than beside
them: `heavy_cyborg.gd` (`HeavyCyborg extends Cyborg`), its gun (`heavy_cyborg_gun.gd`, `HeavyCyborgGun extends
CyborgGun`), its body (`heavy_cyborg_body.gd`, `HeavyCyborgBody extends CyborgBody`) and armour
(`cyborg_looks/heavy.gd`), its tuning (`HeavyCyborgTuning extends CyborgTuning`, `data/enemies/heavy_cyborg.tres`) and
its rules (`heavy_cyborg_rules.gd`) and pattern (`data/patterns/heavy_cyborg.json`). The shared cyborg files carry only
hooks: `CyborgGun`'s `shot_interval()`, `roll_shots()`, `most_shots()`, `charge_sound_point()`, `min_flight_time()` and
`look`, and its static `floor_clear()` (what `path_clear` asks of the floor, which the rules ask too; a cyborg's
behaviour unchanged), and `CyborgSuit.heavy_set()` (every look gets an armour set, worn only by a Heavy Cyborg).
- **The stream.** A wind-up (`charge_time`, 1 s: the barrels spin up and turn red-hot, a red ring grows at the muzzle,
  a red aim line runs from the muzzle to the runner and flickers faster as it ends, the `heavy_cyborg_windup` sound,
  played on the way to the runner, no further than `windup_heard_within`, so it's heard as far off as the stream
  starts), then the aim locks and a stream of rounds flies down that line (the drone gatling's red `enemy_bullet`
  look). Its rounds reach a runner who keeps to the line `bullet_gap` apart (0.18 to 0.16 s, the gap a zigzag goes
  through; the drone's are 0.18 to 0.15 s), so the gatling fires them further apart, by the rounds' speed over the
  closing speed at the level's run speed (`shot_interval`); and only as many (`barrage_count`, 6) as all arrive within
  `invulnerability_share` of the hit invulnerability window, so armor or a shield protects through all of it
  (`most_shots`). Its first round flies `min_warning_time` at least and every later one `later_round_warning_share` of
  it (`min_flight_time`, a `CyborgGun` hook whose cyborg default asks nothing of later bolts), measured from the barrels'
  tips (`HeavyCyborg.MUZZLE_REACH` along the line: the hook adds the time a round takes to get there). A stream that no
  longer fits whole (it starts late: its place in the air came free, or the path cleared, as the runner closed in)
  fires as many of its rounds as still do, `min_stream_rounds` (4) at the least, its last ones left out
  (`HeavyCyborgGun._burst_fair`, planned before the wind-up and again as the aim locks; `roll_shots` fires that many);
  with fewer it waits. Dodged by switching lanes once it locks; a runner who moves during the wind-up is followed; the
  line's flicker thickens steadily instead with Reduced flashing, and the muzzle's flash is left out. The barrels'
  red-hot material is built once and swapped only when the heat crosses `HOT_FROM`.
- **A cyborg's small attack** (owner: it fires when the other small enemies fire and doesn't wait its turn). It is a
  `CyborgGun`, so its stream takes one of the cyborgs' places in the air from its wind-up until `burst_gap` after its
  last round (The cyborgs' airspace, `docs/architecture/enemies.md`), keeps the crossfire rule (a cyborg's burst that
  would leave no way out waits for it, and it for them), holds its fire at a ceiling rider and by anything
  `path_clear` counts, and a teleport calls a stream under way off. It takes no part in `EnemyDirector`'s turns
  (`is_major_attack_active` stays false): the big attacks don't wait for it, nor it for them.
- **Kill and contact.** Declared on `Enemy`: `claw_immune` (the claws don't kill it; a claw runner who touches it is
  hit like anyone), stompable and dash-killed as a cyborg. Health 11.1 in laser tier 1 shots: 14 shots with
  `PowerupTuning.tier1_extra_shots`, twice a cyborg's in every level it appears in, and twice at every other weapon
  tier (`test_heavy_cyborg` checks it against the cyborg's tuning at each level's enemy scaling); twice a cyborg's
  score. Its body hurts on contact as a cyborg's does; another enemy's charge and a falling gantryway destroy it; it
  never boards an Enforcer Truck (only a passed `cyborg` does). Not a host, no panic variant, no window version.
- **Hitboxes.** A solid body (0.7 × 1.12 × 0.45 m) that ends below the stomp line, and a stompable top (0.9 wide, from
  1.18 to 1.6 m: above a standing runner's hurtbox, its top at a jump's highest feet), both inside a body drawn bigger
  than a cyborg's (the model only is scaled; the hitboxes and the gun's muzzle point never change).
- **Look.** Its zone's cyborg (the same rig and poses, CRT head, clothes and colours) bulked out (`BULK`: each segment
  wider and deeper, never longer; shoulders and hips set wider), under the look's armour set (merged into the same
  segment meshes) and drawn `model_scale` (1.15) bigger than the zone's cyborgs. The gatling (receiver, six barrels,
  drum, carry handle; built once and shared) hangs from the chest; the chest turns toward the aim and the arms reach
  its grips (two-bone, `_reach`). Only the face and the gatling's red glow. Its `warm_up` look shows everything at once
  (`show_everything`); the aim line is placed in the world only while it is top-level, so the warm-up stage keeps it
  in its tiny space. `tools/showcase/enemy_showcase.gd` has heavy views (`--camera`).
- **In the levels.** Every Heavy Cyborg stands where its stream gets to fire (`HeavyCyborgRules.fits`): its stream's
  zone (`keep_clear_seconds`, 2 s, of run before it) holds nothing its gun's `path_clear` holds a stream for, in any
  lane (`CyborgGun.floor_clear`: a gap, a live fence, a doodad, a falling gantryway's or a teleporter's calm stretch, a
  dash wall); the cyborgs' margin from every obstacle; what it reaches (that zone, its keep-out, its floor) off every
  dash wall's footprint, wider gap's zone, wall-run gap's clear stretch and calm stretch a rule keeps in every lane
  (those let a cyborg stand its margin away, any other enemy only its keep-out away: a Heavy Cyborg gives way to the
  wider gaps and dash walls, which keep a cyborg's margin from it, and the wall-run gaps' and an Enforcer Truck's
  showing's re-checks hold it to the rest's rule); `spacing_seconds` from every other one; never the level's last plain
  cyborg.
  - Its own encounters: `data/patterns/heavy_cyborg.json` (weight 1.6, as a single cyborg's; each level's
    `feature_weights` and the recency curve on top) places a plain cyborg alone at 36 m of 40, the pattern's own empty
    floor its stream's zone. Every rule plans around it as a cyborg (allowances, make-room and all). Last of the rules
    (`apply`, `RUN_AFTER` every rule its levels have), each one still standing (`pattern_cyborgs`, found through
    `LevelGenerator.picks`) becomes a Heavy Cyborg where it fits and stays a cyborg where it doesn't; then a share of
    the level's other plain cyborgs past the feature's start do too where they fit (the top-up: `share` times the
    campaign's recency factor, from its own random stream, the first always where the pattern's left none).
  - The passes after the rules keep off a Heavy Cyborg's keep-out and floor as off any enemy that isn't a cyborg (the
    fill pass, the zone doodads, the danger density pass's rows), so its zone stays clear, but for the counted
    features, which keep a cyborg's margin from it as from the cyborg it stands in for (the wider gaps,
    `WideGapPlacement.keeps_of`; the dash walls past their introduction, `DashWallRules.enemy_spans`), and the danger
    density pass may add enemies near it as near a cyborg (its tuning's `twin_tolerated_types`: a small threat).
    After the zone doodads (`after_doodads`) one that no longer fits (a wider gap or a dash wall in its zone) is given
    back as a plain cyborg, and where none is left the first own plain cyborg that fits becomes one (`_last_resort`;
    never the last own floor cyborg before the danger density pass's first). A build with none is built again with
    its pattern's picks forced (`guarantee_features`). It keeps a cyborg's keep-out (`keep_out`).
  - The pattern moves the levels' other picks, as any new pattern does. Each level's weight for it (`feature_weights`
    in its data) is one whose own-seed builds at 3, 5 and 6 lanes keep every counted feature their builds had before
    it (teleporters, blinking ones, dash walls, wider gaps, gantryways, Enforcer Trucks, Octodog jars and decoys,
    treasure stashes and fenced ceilings) and have two Heavy Cyborgs at least at 5 lanes and one at 3 and 6: Relay
    Station 2.9 (2, 3 and 3 Heavy Cyborgs at 3, 5 and 6 lanes), Specimen Vault 2.5 (6, 3, 2), Golden 1 2.3 (5, 4, 2),
    Golden 2 3 (3, 3, 3), Golden 3 1.8 (2, 2, 2); only Golden 1's and Golden 3's wall-run gaps at 3 lanes, which come
    by frequency, are fewer. The generator takes about as long as before. Any change that moves the levels' picks (a
    new pattern, the Hunter's) calls for the weights to be checked again. The Golden Zone dates it from the Ice Lab (a
    level old in Golden 1), as the teleporters. The danger density pass, which twins no Heavy Cyborg, adds a little
    less in the Golden Zone at 3 lanes (`test_danger_density`'s HEAVY_CYBORG_ROOM).
- **Sounds.** `tools/asset_gen/sfx_bank_heavy_cyborg.gd`: `heavy_cyborg_windup` (the warning: a motor grinding up
  under a ratchet speeding into a rattle and the red charge's hum, lasting the wind-up and 30 ms into the first round;
  lower and heavier than the drone's) and `heavy_cyborg_shot` (a low double crack, 0.2 s).
- **Tests.** `test_heavy_cyborg` and `test_heavy_cyborg_play` (the campaign's own builds played through, every Heavy
  Cyborg firing; Tests, features), `test_ice_lab_levels` (Relay Station brings it in after its teleporters, none in
  Frost Foundry, none before its start), `test_campaign` (its place in the schedule, the Ice Lab's first new enemy, the
  Golden Zone's ages), `test_hints`, `test_perf` (its warm-up look) and `test_audio`.
