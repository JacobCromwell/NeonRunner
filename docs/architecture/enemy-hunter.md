# Architecture: Enemy: the Hunter

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Beside the runner: the Hunter

Task S2 (GDD §9.17; the owner, October 23, 2026: one of the Ice Lab's two new enemies, from Specimen Vault). A lab
creation riding a hover disc that comes up beside the runner, slashes into their lane and follows them about as long as
the Enforcer Truck; the way to beat it is a falling gantryway the runner drops on it. `hunter.gd` (`Hunter`), its tuning
(`HunterTuning`, `data/enemies/hunter.tres`; F6 "Enemy: hunter"), its look (`hunter_model.gd`, `HunterModel`) and its
rules (`hunter_rules.gd`), with one hook in the gantryways' rules (`GantrywayRules.wanted`). The feature is `hunter`
(Specimen Vault, `feature_starts` 0.4). Every number but the owner's (25 s, 25 laser hits) is DESIGN-TBD,
`docs/questions/s2.md`.

- **Where** (`hunter_rules.gd`, `RUN_AFTER` the gantryways, teleporters and Octodog jars, whose keep-outs it reads; no
  pattern). A Hunter comes in only where a falling gantryway can be its bait during its chase (GDD §9.17, proposed). A
  bait (`bait_points`) is a gantryway whose Hunter lane (the lane beside its walkway away from its pillar's push, where the
  Hunter rides as the runner, in the walkway's lane, dashes the pillar and steps out to the push side) is clear of what the
  Hunter would have to go round (doodads, live fences, teleporter pads, ramps, floor enemies by their bodies' spans:
  `body_span`) from the pillar's lead (`hunter_lane_window`) to `bait_lane_after_seconds` past its front at the fastest a
  runner comes through; plain fences there are taken out (`after_fill` too, against the fill pass). For each bait in turn
  it tries arrivals from `bait_after_seconds` to `chase_seconds - bait_before_seconds` before the pillar (a seeded spot in
  the preferred 8 to 14 s first; the level's first one as early as it can after the feature's start: the introduction),
  keeping a calm arrival (`arrival_calm_seconds` of run from it free of every busy stretch: floor cuts, wall-run gaps, dash
  walls, the debris maze, picks, Octodog charges, every other rule's every-lane calm keeps: `busy_stretches`), never two at
  once (`chase_span` and `spacing_seconds`), at most `per_level_max`. A level where no arrival is calm takes one where
  only the calm is missing (a second pass; `problems` flags a level mixing the two). Its entry: {type, at (the runner's
  distance as it arrives), lane, side 0, seed, params {baits: [{at (the pillar's front), lane (the walkway's), side (the
  push), id}], calm: [from, to] when calm}}. It keeps others' doodads out of its calm arrival (`doodad_keep_outs`, calm
  only, no lane keeps: the gantryways', teleporters' and jars' own re-checks count every rule's keep-outs against their
  windows) and the fill pass out of it (`fill_keep_outs`). `LayoutChecks.check_hunters` runs `problems` on every built
  level that lists it (and checks it has its gantryways and starts after its feature's start).
- **The introduction's bait** (`gantryway_wanted`, read by `GantrywayRules.wanted`: a feature's rules may ask the
  gantryways' rules for a gantryway in a stretch). Where the level gives the feature a start, the gantryways' rules hang
  one `intro_bait_min_seconds` to `intro_bait_max_seconds` (12 to 18 s) of run past it, both lanes beside it clear where
  they can (else anywhere 6 to 21 s past it), before spreading the rest; so the first Hunter arrives about as the feature
  starts and shows its flurry before its bait. A level whose features want none builds as before. `tools/measure/
  hunters.gd` prints every build's Hunters and baits (`--levels --lanes --seeds --weekly --why --gantryways --start`): over
  Specimen Vault's own builds at 3, 5 and 6 lanes and 8 other seeds each, and the weekly challenge's Ice Lab weeks, 46
  Hunters in 31 builds, every own build calm, one build without one.
- **Behaviour** (`Hunter`, states WAITING, APPROACH, ALONGSIDE, YIELD, LEAVING, DEAD; its slash IDLE, WARNING, FLURRY,
  RECOVER). Unseen, harmless and not solid until the runner reaches its `at`; then its whine (`hunter_whine`) and it comes
  up from `arrive_gap` behind (out of view it changes lanes at once; it comes into view only into a lane clear ahead) into
  a lane beside the runner's, its middle `alongside_ahead` ahead of theirs. Beside them it rides the lane next to theirs
  on its side `follow_delay_seconds` after they change lanes (a log of their lanes on the level clock: `_follow_lane`), so
  a runner who steps away leaves it in the lane they left; it never takes their lane. Its side (`_pick_side`,
  `_bait_side`): the runner's far side from the next bait's walkway lane where they could then step out of it away from it
  onto open floor (the push side, or the other where `_out_open` finds it open), else away from the push; with no bait
  ahead, toward the nearer edge. Over a bait's run-up it keeps out of the walkway's lane (`_run_up_bait`). It steers
  (`_lane_clear_ahead`, `blocked_in`): what stands in its lane `steer_ahead_seconds` ahead it goes round in the lane the
  runner just left, or the lane further out, else it makes room (YIELD: drops to `yield_gap`, behind the camera, and comes
  up again after `regain_seconds`); it makes room too where the runner's lane holds what they must leave and their other
  lane isn't open (`_must_make_room`, `_needs_leaving`, `lane_open`), and before a wall-run gap. It hovers over holes,
  gaps and floor cuts (its place is set from the runner's distance and its gap; nothing makes it fall). Below a runner on
  a ceiling or a wall it waits beside their lane. A teleport (`runner_teleported`; `follows_runner` keeps it in play)
  leaves it behind to catch up from where it was left (`catch_up_gap_max`); one still waiting whose spot the jump skipped
  retires. After `chase_seconds` from its arrival, whatever it's doing, it gives up (`hunter_give_up`), drops back at
  `leave_speed` and retires at `gone_gap`.
- **The flurry** (`_update_slash`, `may_slash`). Settled beside a runner on the floor in the middle of their lane, with
  their other lane open to step into from `escape_reaction_seconds` after the warning to the last cut (`lane_open`,
  strict), outside the level's calm start, a gantryway's run-up and calm stretch (`_bait_near`), a teleporter's calm
  stretch in their lane and a wall-run gap, and finishing before it gives up: its warning (both blades raised, eyes and
  blades brighter, `hunter_scrape` from where it is, and the red mark on the locked lane: `_update_mark`, widening and
  pulsing, only widening with Reduced flashing), then `flurry_seconds` of cuts (`hunter_slash`; its attack hitbox over the
  locked lane, `slash_height` high and `slash_depth` long, placed each tick where the runner is along the track:
  `_place_slash_box`), then `recover_seconds`. It holds its lane through a warning and its cuts. A runner who takes a pad,
  steps onto a wall or teleports calls them off (`_on_player_event` runs before the hazard check in the same step). One
  flurry is one hit: the damage rules' armor and shield take the first contact and the invulnerability window the rest.
- **Declared properties** (CLAUDE.md principle 8). `claw_immune`, not `stompable`, `dash_kills` false, `follows_runner`;
  its body hitbox `harmless` (`DamageRules`: the dash, claws and stomps do nothing, and it hurts no one), its lane blocker
  (`blocker_height`, over a whole jump) solid; `is_major_attack_active` false (it neither waits for the director's turns
  nor holds anyone else's: the owner's "it does not wait for other big enemies"); `charge_can_hurt` false (other enemies'
  charges pass it by). Weapons hurt it: `health` 23, so 25 laser tier 1 shots (`PowerupTuning.tier1_extra_shots`) and
  17, 12 and 8 at tiers 2 to 4. `aim_point` (its chest) and `hit_radius` are what shots and a falling walkway's crush
  (`Gantryway.crushes`, RunWorld: `defeat(&"gantryway")`, the runner's kill) see. Its death (`_on_defeated`): its blades
  and solid side off at once, sparks, steel debris and a small shared fireball (GDD §11), `hunter_death`.
- **Its look** (`HunterModel`). Built in code from boxes, cylinders, domes and spikes, each moving part one mesh in vertex
  colours (disc, jets, torso, eyes, two arms, two blades: 8 draw calls), standard materials only (the Compatibility
  renderer). Only the eyes (orange-red), the blades (the hazard red, lit, a red glow brighter while alert: a change of
  state, never a flicker) and the jets (a pale blue-white well off the safe cyan) glow. Its pose (`hover`, `face_yaw`,
  `lean`, `raise`, `cut`, `roll`, `alert`) is set by `Hunter._place` and applied by `animate()`: the torso turned toward
  the runner, both blades raised over its head through a warning, the arms chopping in turn through the cuts, the disc
  rolling into a lane change. Meshes and materials are built once (static caches); `Hunter.warm_up` draws the model, its
  alert materials and the mark with the level (no physics object).
- **Sounds** (`tools/asset_gen/sfx_bank_hunter.gd`, `tools/godot.sh sfx --only=hunter_whine,...`): `hunter_whine`
  (everyone hears it: it comes from behind), `hunter_scrape` (as long as `warning_seconds`, read from its data; no pitch
  variation), `hunter_slash` (one swish a cut), `hunter_give_up`, `hunter_death`.
- **Review** (`tools/showcase/hunter_showcase.tscn`): `--scenario=model` (three of it: calm, warning, cutting) or the
  default chase on Specimen Vault's look (it arrives, a flurry dodged into the walkway's lane, then the bait), with
  `--camera=game|side|behind`, `--stay`, `--mortal`, `--lanes`, `--skin`, `--reduced-flashing`.
- **Tests.** `test_hunter` (medium; `docs/architecture/tests-features.md`), `LayoutChecks.check_hunters` through every
  suite that checks Specimen Vault's builds (test_ice_lab_levels, test_campaign, test_weekly_challenge), `test_campaign`'s
  feature lists (Specimen Vault introduces it), `test_hints`, `test_audio`.
