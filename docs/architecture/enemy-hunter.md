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
  bait (`bait_points`) is a gantryway whose Hunter lane (the lane beside its walkway away from its pillar's push, where
  the Hunter rides as the runner, in the walkway's lane, dashes the pillar and steps out to the push side) is clear of
  what the Hunter would have to go round (doodads, live fences, teleporter pads, ramps, floor enemies by their bodies'
  spans: `body_span`) from the pillar's lead (`hunter_lane_window`) to `bait_lane_after_seconds` past its front at the
  fastest a runner comes through; plain fences there are taken out (`after_fill` too, against the fill pass). For each
  bait in turn it tries arrivals from `bait_after_seconds` to `chase_seconds - bait_before_seconds` before the pillar (a
  seeded spot in the preferred 8 to 14 s first; the level's first one as early as it can after the feature's start: the
  introduction, whose bait, `intro_bait`, the first a Hunter arriving from that start can take, gets its Hunter before
  the rest, calm where it can, else in a second try clear of every attack all the same; task S2c), keeping a calm
  arrival (`arrival_calm_seconds` of run from it free of every busy stretch: floor cuts, wall-run gaps, dash walls, the debris maze, picks, Octodog charges, every other rule's every-lane calm keeps:
  `busy_stretches`), never two at once (`chase_span` and `spacing_seconds`), at most `per_level_max`. A level where no
  arrival is calm takes one where only the calm is missing (a second pass; `problems` flags a level mixing the two, but
  for an introduction that is not calm only where its bait had no calm arrival). Its
  entry: {type, at (the runner's distance as it arrives), lane, side 0, seed, params {baits: [{at (the pillar's front),
  lane (the walkway's), side (the push), id}], calm: [from, to] when calm}}. It keeps others' doodads out of its calm
  arrival (`doodad_keep_outs`, calm only, no lane keeps: the gantryways', teleporters' and jars' own re-checks count
  every rule's keep-outs against their windows) and the fill pass out of it (`fill_keep_outs`).
  `LayoutChecks.check_hunters` runs `problems` on every built level that lists it (and checks it has its gantryways and
  starts after its feature's start).
- **The introduction's bait** (`gantryway_wanted`, read by `GantrywayRules.wanted`: a feature's rules may ask the
  gantryways' rules for a gantryway in a stretch). Where the level gives the feature a start, the gantryways' rules hang
  one `intro_bait_min_seconds` to `intro_bait_max_seconds` (12 to 18 s) of run past it, both lanes beside it clear where
  they can (else anywhere 6 to 21 s past it), before spreading the rest. Among those spots they take first one every
  wanting feature can take (`GantrywayRules.wanted_taker`, which asks each feature's rules for a `gantryway_taker`; the
  Hunter's, `HunterRules.gantryway_taker`, takes a spot whose Hunter lane is clear over its window, from each lane's shut
  stretches gathered once: `_lane_shut_spans`; task S2c: with S1's Heavy Cyborg in Specimen Vault, an Octodog run shut
  the 6-lane build's introduction bait and it came 0.65 of the way in), else any; so the first Hunter arrives about as the
  feature starts, with time for a flurry before its bait where the runner's lane allows one (none that would carry them
  two lanes past its walkway's lane: The flurry, below). A level whose features want none builds as before.
  `tools/measure/hunters.gd` prints every build's Hunters and baits (`--levels --lanes --seeds --weekly --why
  --gantryways --start`): over Specimen Vault's own builds at 3, 5 and 6 lanes and 8 other seeds each, and the weekly
  challenge's Ice Lab weeks (task S2c, with S1's Heavy Cyborg), 47 Hunters in 31 builds, every own build's calm but the
  6-lane build's introduction (no arrival for its bait is calm; one more in the sweep, 6 lanes, seed 9007), one build
  without one (3 lanes, seed 9008: its gantryways all hang before the feature's start), 3 introductions past
  test_campaign's reach (none on the levels' own seeds).
  The calm arrival is 1.5 s of run: it keeps every lane clear, and at 3 s it took one of Specimen Vault's decoy jars'
  room at five lanes (task Q5's count of 3 stands).
- **Behaviour** (`Hunter`, states WAITING, APPROACH, ALONGSIDE, YIELD, SWITCH, LEAVING, DEAD; its slash IDLE, WARNING,
  FLURRY, RECOVER). Unseen, harmless and not solid until the runner reaches its `at`; then its whine (`hunter_whine`)
  and it comes up from `arrive_gap` behind (out of view it changes lanes at once; it comes into view only into a lane
  clear ahead) into a lane beside the runner's, its middle `alongside_ahead` ahead of theirs; a runner who steps into
  its lane (or the one it's changing to) in front of it keeps it `cross_gap` behind them until its lane change has taken
  it out of their way (`_crossing_runner`). Anywhere in the runner's way behind them (their lane, or crossing it) it
  keeps `cross_gap` (5 m) back, moving straight through the nearer stretch at `drop_speed` rather than easing
  (`_move_gap`, `_drop_to`; task S2's review): nearer, it stands between them and the chase camera, hiding them or their
  lane ahead; from there back, level, it hides nothing (test_hunter's view, its disc rolled into a lane change too). It
  faces ahead, turning toward the lane it cuts only as it warns and cuts (turned toward the runner all along, its blades
  swung across the lane ahead of a runner by the edge, whose camera sits over the lane beside them, as it turned).
  Beside them it rides the lane next to theirs on its side `follow_delay_seconds` after they change lanes (a log of
  their lanes on the level clock: `_follow_lane`), so a runner who steps away leaves it in the lane they left; it never
  takes their lane. A runner who steps out from under a falling walkway (fallen, not landed: `_walkway_falling_on`) has
  it follow into that lane at once, in `walkway_switch_seconds` (0.12 s): any step out the runner lives through leaves
  it under the walkway as it lands (measured: every step out 0.00 to 0.90 s after the pillar breaks; the walkway catches
  the runner from 0.95 s). Its side (`_pick_side`, `_bait_side`): the runner's far side from the next bait's walkway
  lane where they could then step out of it away from it onto open floor (the push side, or the other where `_out_open`
  finds it open), else away from the push; with no bait ahead, toward the nearer edge. Where it would ride between the
  runner and the next bait's walkway lane two or more lanes off on its side (a runner by the edge on the wrong side), it
  rides there beside them, its flurries never carrying them further from that lane once the pillar is within
  `bait_cross_seconds` and a flurry's length of run (task S2c; before that it slashes as ever), until the pillar is
  `bait_cross_seconds` (5 s) of run ahead (task S2's review: before, it dropped out of view for that whole stretch);
  from then until its run-up (`_blocks_bait`: the pillar within `bait_cross_seconds` and further than
  `bait_hold_seconds`, the runner then able to step out of the walkway's lane on that side) it lets them past: it
  crosses behind them to their other side (SWITCH `bait`), or, with no lane there, drops back (YIELD `bait`; coming up,
  it holds back unseen just behind the camera), leaving them a window to cross, and comes up on their other side once
  they're past, or beside them again for the run-up. Over a bait's run-up it keeps out of the walkway's lane
  (`_run_up_bait`). It steers (`_lane_clear_ahead`, `lane_blocker`, `blocker_in`): what stands in its lane
  `steer_ahead_seconds` ahead (a doodad, a pillar or a jar, a gapped fence, a teleporter's pad, a ramp, a standing dash
  wall, a floor enemy; through a warning and its cuts only as far as they last and `ATTACK_STEER_MARGIN`, 0.3 s, more:
  what lies past them it steers round once they're over rather than calling them off, task S2c) it goes round in the
  lane the runner just left, or the lane further out; else it crosses behind
  them to their other side where that lane is clear and they don't need it (`_may_cross`, SWITCH `blocked`: it drops
  straight to `cross_gap` behind them, changes lanes there and comes up again with its whine); else it drops out of view
  (YIELD `blocked`: to `yield_gap`, behind the camera, and comes up again after `regain_seconds`). A full fence (one the
  runner jumps), live or not, it rises over (`_update_lift`, `lift`; task S2's review: as a flyer over a dash wall): its
  disc's underside `fence_clearance` over the fence's top as its body reaches it, climbing and settling at `lift_speed`,
  over the fences in every lane its disc spans. A gapped fence (the runner slides under it) it goes round: risen about 2
  m its body would hide the floor ahead of a runner beside it from the camera; beside a runner in an edge lane it goes
  round every fence for the same reason (`_goes_round`, `_runner_in_edge_lane`; test_hunter's view). It makes room where
  the runner's lane holds what they must leave, another enemy's small attack too (its body never takes a dodge away:
  `_small_attack_on`, any `CyborgGun` charging or firing, the floor and window cyborgs', the barnacle turret's, the
  Heavy Cyborg's gatling, or an enemy shot reaching their lane within `make_room_seconds`), and their other lane isn't
  open (`_must_make_room`, `_needs_leaving`, `lane_open`), and before a wall-run gap: it drops straight back only
  `cross_gap`, still on screen, clear of the lane beside them so they can step into it in front of it, and comes up
  again as soon as they no longer need it (`room_seconds` at the soonest; task S2's review: it used to drop out of view
  for `regain_seconds`). It hovers over holes, gaps and floor cuts (its place is set from the runner's distance and its
  gap; nothing makes it fall). Below a runner on a ceiling or a wall it waits beside their lane. A teleport
  (`runner_teleported`; `follows_runner` keeps it in play) leaves it behind to catch up from where it was left
  (`catch_up_gap_max`); one still waiting whose spot the jump skipped retires. After `chase_seconds` from its arrival,
  whatever it's doing, it gives up (`hunter_give_up`), drops back at `leave_speed` and retires at `gone_gap`.
- **The flurry** (`_update_slash`, `may_slash`). Settled beside a runner on the floor in the middle of their lane, with
  their other lane open to step into from `escape_reaction_seconds` after the warning to the last cut (`lane_open`,
  strict: no hole, floor cut, doodad, live fence, floor enemy, solid side or trap pad, `_trap_pad_in`: one marked
  "unsafe", or any pad under a ceiling with a fence in its lane ahead of it), outside the level's calm start, a
  gantryway's run-up and calm stretch (`_bait_near`), a teleporter's calm stretch in their lane, a wall-run gap and a
  fenced ceiling's pick (`LevelLayout.fenced_pick_between`, as the heli drone's barrages), never while another enemy's
  small attack is on at them (`_small_attack_on`, their lane or the one they'd step into), never one whose dodge would
  carry them two lanes or more past the next bait's walkway lane as its pillar nears (within `bait_cross_seconds` and a
  flurry's length of run; task S2c), never one it would be risen over a fence through while
  its sweep shows and its cuts are live (`_lifted_between`: the sweep is drawn from its hover), and finishing before it
  gives up (`slash_problem` names the first rule that holds one back, "" when it may: `may_slash`). The first comes
  `first_slash_seconds` after it settles beside them, the next a seeded `slash_interval_min` to `slash_interval_max`
  from the last one's warning (0.4 s; 1.8 to 2.0 s: task S2c, the owner's "it should attack 2 times more often", with a
  quicker approach, follow and return, `approach_speed` 16 m/s, `follow_delay_seconds` 0.15 s, `switch_seconds` 0.2 s,
  `regain_seconds` 0.5 s, `yield_gap` 8 m, and `bait_hold_seconds` 2 s; 1.0 s and 1.8 to 2.3 s from task S2's review,
  1.4 s and 2.4 to 3.2 s before). Its warning (both blades raised,
  eyes and blades brighter, `hunter_scrape` on its own voice, carried with it, and the red mark on the locked lane:
  `_update_mark`, widening and pulsing, only widening with Reduced flashing), then `flurry_seconds` of cuts
  (`hunter_slash`; its attack hitbox over the locked lane, `slash_height` high and `slash_depth` long, placed each tick
  where the runner is along the track: `_place_slash_box`), then `recover_seconds`. What the cuts reach is drawn
  (CLAUDE.md principle 4; task S2's review): over the warning's last `TRAIL_IN` (0.12 s) a see-through red fan of its
  blades (`_build_trail`, `HunterModel.slash_mesh` and `slash_material`, unlit, both faces) sweeps out across the locked
  lane from a pivot in front of its chest and stays whole through the cuts, and its rig lunges `HunterModel.LUNGE` (0.5
  m) that way (`model.reach`, easing back as it recovers); the fan is built round the hitbox, every corner of it inside
  with `SLASH_MARGIN` (0.1 m) and `SLASH_ANGLE_PAD` to spare, and clipped where it would reach more than `SLASH_MARGIN`
  past the cut lane's far edge (`x_max`); its mesh is shared by every Hunter with the same numbers
  (`HunterModel.shared_slash_mesh`), and `slash_fan` reports it to the tests. It's steady (one sweep a flurry, no
  pulse), so Reduced flashing leaves it as it is. It holds its lane through a warning, its cuts and its recovery: its
  blades come down and its lunge eases back before it follows (task S2's review: following with them still up, beside a
  runner its dodge took to the edge, they hid that runner's lane ahead from the camera). What shuts that lane ahead
  meanwhile calls a warning or the cuts off as it steers, crosses or drops back. A runner who takes a pad, steps onto a
  wall or teleports calls them off (`_on_player_event` runs before the hazard check in the same step; the mark and the
  sweep go at once). A warning called off stops its scrape (`_stop_scrape`). One flurry is one hit: the damage rules'
  armor and shield take the first contact and the invulnerability window the rest. A runner at an edge with it inward
  has no lane away from it, so it never slashes them there (an edge refuge, a question for the owner:
  `docs/questions/s2.md`).
- **Its cost** (task S2's review: its per-frame checks had doubled). Its checks run every tick; what they read more than
  once a frame is kept: whether a runner can step out of a bait's walkway lane to a side (`_out_open`, per bait and side,
  looked at again every `OUT_OPEN_REFRESH`, 0.25 s), the small attacks at the runner (`_small_attacks`, once a physics
  frame), whether an enemy type uses the floor (`_type_uses_floor`, once a type), its baits (read from its entry once),
  the layout's doodads and fences by lane, sorted (`_index_layout`, looked up by bisection). Over Specimen Vault's chases
  on a cloud container: about 80 µs a tick on average at 5 lanes (65 at 3, 78 at 6; 65, 57 and 77 before the review's
  changes).
- **What it hides from the chase camera** (task S2's review; the reviewer's view probe: Specimen Vault's builds at 3, 5
  and 6 lanes, a god-mode runner dodging each flurry, the camera's resting view each frame, each of its parts as a box):
  over the 12 chases it hides the runner 0.23 s and their lane ahead 0.16 s in all (3.37 s and 3.74 s before this
  round's view work, 1.98 s and 1.10 s at the first review's build). What's left: risen over a full fence while making
  room beside a runner by the edge at 6 lanes (camera over its lane), and a warning's first turn toward the lane it cuts
  (that lane's floor 10 m ahead, 0.03 s).
- **Its chases, measured** (`tools/measure/hunter_chases.gd`, `--seeds=N --runner=dodge|bait --start --levels`): plays
  Specimen Vault's builds at 3, 5 and 6 lanes (its own seed and 9001 on) with the Hunter's chases on a god-mode runner
  who grapples, jumps holes and dodges every flurry (or also heads for the bait and dashes it), and prints each chase:
  how long, beside them, unseen, the runner in an edge lane, flurries warned off the edges, cuts, yields and what shut
  its lane (`lane_blocker`), what called its warnings off, the due flurries held back and why (`slash_problem`). With
  the review's changes (2 seeds): 1.3 warned flurries a chase for the dodger, 2.7 for every 25 s off the edges (2.4, 1.9
  and 5.2 at 3, 5 and 6 lanes), beside them 53% of the time and unseen 20% (before: 0.6, 1.1, 38%, 39%); the bait
  runner 0.6 a chase, 1.4 for every 25 s off the edges, beside 57%, every bait landed. Task S2c (the owner: twice as
  often; 6 seeds, 31 chases, with S1's Heavy Cyborg in the level): the bait runner 0.81 warned a chase (0.30 before),
  0.65 cut (0.20), 2.3 for every 25 s off the edges (0.8), 29 of 31 baits landed; the dodger 0.94 a chase (0.67), 0.77
  cut (0.43), 2.7 off the edges (1.7): its dodges take it to the edge, where it spends 65% of its chases
  (`docs/questions/s2.md` items 20 and 21). What holds the rest back is the level and the fairness rules: the edge
  refuge, a gantryway's run-up and calm stretch, the bait's keep-out, no way out, the runner off the floor.
- **Declared properties** (CLAUDE.md principle 8). `claw_immune`, not `stompable`, `dash_kills` false, `follows_runner`;
  its body hitbox `harmless` (`DamageRules`: the dash, claws and stomps do nothing, and it hurts no one), its lane
  blocker (`blocker_height`, over a whole jump) solid; `is_major_attack_active` false (it neither waits for the
  director's turns nor holds anyone else's: the owner's "it does not wait for other big enemies"); `charge_can_hurt`
  false (other enemies' charges pass it by). Weapons hurt it (`health` 23, so 25 laser tier 1 shots,
  `PowerupTuning.tier1_extra_shots`, and 17, 12 and 8 at tiers 2 to 4), but auto-fire, the laser and the missiles alike,
  never picks it beside the runner (`targetable`: only while it's seen and its middle `target_ahead` or more ahead of
  theirs; the owner: its staying at the runner's side makes it "difficult for the player to damage it with dashes or
  with laser attacks"). It never rides that far ahead, so shots reach it only on their way to something else: over a
  whole chase beside a runner auto-firing laser tier 1, none did (test_hunter). So its 25 laser hits come only from
  stray shots in play: an open question for the owner (`docs/questions/s2.md`, item 1: a lower priority beside the
  runner, or a smaller `target_ahead`). `aim_point` (its chest) and `hit_radius` are what shots and a falling walkway's
  crush (`Gantryway.crushes`, RunWorld: `defeat(&"gantryway")`, the runner's kill) see. Its death (`_on_defeated`): its
  blades and solid side off at once, sparks, steel debris and a small shared fireball (GDD §11), `hunter_death`.
- **Its look** (`HunterModel`). Built in code from boxes, cylinders, domes and spikes, each moving part one mesh in
  vertex colours (disc, jets, torso, eyes, two arms, two blades: 8 draw calls), standard materials only (the
  Compatibility renderer). Only the eyes (orange-red), the blades (the hazard red, lit, a red glow brighter while alert:
  a change of state, never a flicker) and the jets (a pale blue-white well off the safe cyan) glow. Its pose (`hover`,
  `face_yaw`, `lean`, `raise`, `cut`, `roll`, `alert`, `reach`, `reach_dir`) is set by `Hunter._place` and applied by
  `animate()`: the torso facing ahead, turned toward the lane it cuts and both blades raised over its head through a
  warning, the arms chopping
  in turn through the cuts as the rig lunges toward the lane it cuts, the disc rolling into a lane change. Meshes and
  materials are built once (static caches); `Hunter.warm_up` draws the model, its alert materials, the mark and the
  sweep with the level (no physics object). The look as a whole, the lunge and the sweep are DESIGN-TBD
  (`docs/questions/s2.md`).
- **Sounds** (`tools/asset_gen/sfx_bank_hunter.gd`, `tools/godot.sh sfx --only=hunter_whine,...`): `hunter_whine`
  (everyone hears it: it comes from behind), `hunter_scrape` (as long as `warning_seconds`, read from its data; no pitch
  variation; on its own voice, carried with it, so a warning called off cuts it short), `hunter_slash` (one swish a cut), `hunter_give_up`, `hunter_death`.
- **Review** (`tools/showcase/hunter_showcase.tscn`): `--scenario=model` (three of it: calm, warning, cutting),
  `--scenario=fences` (task S2's review: it rises over two full fences in its lane, crosses behind the runner round a
  crate, rises over a full fence on their other side and goes round a gapped one) or the default chase on Specimen
  Vault's look (it arrives, a flurry dodged into the walkway's lane, then the bait), with `--camera=game|side|behind`,
  `--stay`, `--mortal`, `--lanes`, `--skin`, `--reduced-flashing`.
- **Tests.** `test_hunter` (medium) and `test_hunter_baits` (slow: the bait at every lead Specimen Vault's builds give
  it, every start lane, both ways round, its flurries on, 200 of 200 takes; and the step-out window, 0.00 to 0.90 s)
  (`docs/architecture/tests-features.md`), `LayoutChecks.check_hunters` through every suite that checks Specimen Vault's
  builds (test_ice_lab_levels, test_campaign, test_weekly_challenge), `test_campaign`'s feature lists (Specimen Vault
  introduces it), `test_hints`, `test_audio`.
