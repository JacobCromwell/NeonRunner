# Architecture: Enemy: the Cybernetic Centipede

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## In the debris maze: the Cybernetic Centipede

Task O3 (GDD §9.15; the owner, October 20, 2026: the Terminal's only enemy, from 35% into Rubble Line, and all through
Last Stop's maze and endless mode's copy of it). `centipede.gd`
(`Centipede`), its tuning (`CentipedeTuning`, `data/enemies/centipede.tres`: every number DESIGN-TBD,
`docs/questions/o3.md`), its model (`centipede_model.gd`), its rules (`centipede_rules.gd`), its view of a maze block
(`centipede_maze.gd`, `CentipedeMaze`) and the proof that it leaves the block escapable (`centipede_escape.gd`,
`CentipedeEscape`). No pattern: only the maze knows its cells (The generator, The debris maze).
- **Where** (`centipede_rules.gd`, `RUN_AFTER` the maze; before every later pass, which keeps off the maze's blocks
  anyway, so nothing else moves for it: `keep_out` is its block's own). Each block from the feature's start gets one
  with `block_share` at the difficulty where it stands (0.45 to 0.9), a second with `second_share` (0 to 0.35), at most
  `max_per_block`, `min_spacing` apart; the first block that takes one is its introduction (an ordinary cell first),
  and a level where no block took one gets one where any spot fits. A spot is a head in an open cell of a room (its
  body behind it in its lane, the rules' margins), in one of GDD §9.15's three places drawn by the weights: "near" (a
  cell joined to the run-in, off the block's quickest way), "way" (on that way: "in the only way through") or
  "trapped" (joined to neither the run-in nor the breather: "a dash that opens their debris can release one"). It is
  kept only if `CentipedeEscape` still finds a way out with it and the block's others, and its floor keeps off every
  pad and landing zone (`CeilingZones.enemy_clear`). Its entry: {type, at (the head), lane, side 0, params {block,
  situation, floor_span}}. How many is each level's (task O5; the owner, October 22, 2026: Rubble Line about 20 to 30%
  more, Last Stop about double): its maze tuning's `centipede_scale` (1.35, 2.3) multiplies each block's drawn count, the
  fraction drawn (`_scaled`; none at 1), and the most a block holds (`max_per_block(config)`). Second round (the owner,
  October 22, 2026: Last Stop to 12, and "not always separated from the player"): scales 1.45 and 3.25, the place
  weights 0.65, 0.3 and 0.05 (near, way, trapped), and each open cell offering `OPEN_SPOTS` spots tried `OPEN_TRIES` at a
  time; at 5 lanes over 12 seeds Rubble Line about 8.7 a level (6.75 at first), Last Stop about 11 plus its two ambushes
  (4.4 at first), walled-in ones about 60% and 70% (73% at first: most open spots fail the proof). An escape block's
  pad room (`DebrisMaze.is_escape`) takes none.
- **Ambushes** (task O5; the owner, October 22, 2026: "resting inside of one of the debris doodads, and you can barely
  see its body, and when you get close to it, the debris shatters and the centipede is released", two in Last Stop's
  last half). `DebrisMazeTuning.ambush_count` and `ambush_from`; `_place_ambushes` runs first, one a block from
  `ambush_from` of the level on (spread, the others tried in turn), each hidden in a divider (`ambush_candidates`:
  `OPEN_SPOTS` a divider, its body on the side of an open lane, `peek`), its debris (`ambush_host`: the divider's pieces
  from `AMBUSH_HOST_BEFORE` before its head to `AMBUSH_HOST_AFTER` past its tail) its "host"; the others of its block are
  placed after it, keeping it in their proof. Entry: situation "ambush", params.ambush {room, lane, peek, from, to};
  `spot_of(layout, e)` is the proof's spot for any entry. `Centipede`: `ambush`, `hidden`, `host`; hidden, it lies set to
  its side so `ambush_showing` of its body pokes out past the debris, lenses dark; it breaks out (`_breaks_out`,
  `_break_out`) once the runner is on the floor in its block within `ambush_distance_at(pace)` (8 m at the reference
  speed) or debris of it is smashed: its host's pieces are smashed (`DashBreakable.smash(&"ambush")`, the run's rubble,
  `doodad_smash`), the maze refreshes (its neighbours' sections too), and it wakes as any other. The proof
  (`CentipedeEscape`): an ambush spot wakes by distance alone (`_wake_dist`), its host is open for every centipede of
  the block from the start (`hosts`), and the sections its shattering joins are joined from the start (`_host_joins`).
  The wake check has `EPS` of tolerance at the wake distance's edge (it could count a wake a stretch late: found with
  the ambush). `CentipedeBot` opens the ambushes' hosts in its own grid, leaves a hidden one's head in debris alone, and
  skips its bound while the runner dashes (a dash passes through the bite, as the proof takes it). Tests:
  `test_centipede` (`_test_ambush`: hidden, the sliver showing, out at its distance with the crunch then the hiss,
  chasing; out at once when its debris is smashed), `test_centipede_maze` (each level's own seed holds its ambushes at 5
  and 6 lanes, one at least at 3), `LayoutChecks.check_centipedes` (in a divider of its room, from `ambush_from` on, no
  more than the count). DESIGN-TBD (`docs/questions/o5.md` 7-9).
- **The proof** (`CentipedeEscape.find`; `LayoutChecks.check_centipedes` runs it again on every built level). Escapable:
  from the block's run-in (any lane) to `leave_margin` past its last wall, a way on the Player's moves (MazeRoute's
  model: lining up while running, stops at debris, the dash from a stop when it's ready, waiting for it otherwise; the
  dash at its slowest recharge, 8 s, and just used as the runner reaches the run-in: `entry_ready`, the debris maze's
  own assumption, since a Terminal runner may well have dashed through a doodad just before the block) on which the
  runner is never within a centipede's bite, whatever it does. That rests on what the centipede keeps to (each a test):
  it doesn't move before its wake and `wake_time`; it wakes only for a runner on the floor in its block (from the run-in
  on: `_section_near` never looks outside it) and in its own section or one joined to it (with the runner's smashes)
  within `wake_distance`; it moves on open floor only (its head's footprint never touches debris, nor leaves its block),
  from a standstill, no faster than its chase speed and acceleration; its bite reaches `bite_reach`; it gives up past
  the last wall. So at time t it is nowhere further along open floor from its spot than
  `run_reach(t - wake - wake_time)`, and the runner is safe while their distance from the spot (`CentipedeMaze.field`:
  bins along the track, a lane change free, which no real way beats) is more than that and the reach (with two bins and
  0.5 m for the grid). The search goes stage by stage (run-in, each room's cells, breather) over labels {t, z, lane,
  cell, dash ready, each centipede's wake, the joins its smashes made}, dropping those another beats, and checks the
  quickest safe way again with its smashes open from the start (a hole the runner makes is open to the centipede too; a
  dash's smashes are taken as far as its whole run and `SMASH_MARGIN`, the runner carried only its run less
  `DASH_SLACK`). The way keeps off the block's anti-grav pads, as MazeRoute's do, but for an escape block's (task O5):
  there the barrier is no way through and the way out is the pad (`_escape`: lined up in its lane before it, then
  running on, checked against every awake centipede up to the barrier's front, by when the lift has the runner well
  above any bite; on the ceiling it gives up). test_centipede_maze runs each level's escape block on physics with
  `CentipedeBot` (its `ceiling`: the runner rode it). Over test_centipede_maze's sweep, two
  blocks in three get a centipede; at 5 and 6 lanes about a fifth wait near the way, a quarter in it and over half
  walled in; at 3 lanes most are walled in (there's little room to pass one in the open). It adds about 0.08 s to a
  Terminal level's generation (about 0.24 s here, from 0.16 s), and nothing measurable to endless mode's 20-minute copy
  of Last Stop (its maze's own cost).
- **Its maze** (`CentipedeMaze`, from the block's record and its debris entries, rebuilt when a dash smashes some:
  `refresh()`). One model so they never disagree: merged pieces per lane and `clear_at()` (the head's footprint, every
  piece as wide as the widest); an `open` grid (1 m bins, no debris touches) for `find_path()` (A* on Dial's buckets,
  a lane change costing its width) and `reach()`; a `free` grid (no debris covers a bin whole) for `field()` (a 0-1
  search); `block_layout()` for DebrisMaze's questions on the block alone.
- **Behaviour** (`Centipede`, states SLEEP, WAKE, CHASE, STUN, GIVE_UP; its jaws CLOSED, OPENING, STRIKE, REST). It
  waits still, head toward the runner's approach; wakes as above (its warning: `centipede_wake`, a hiss and the clatter
  of legs; it rears, lenses flaring, and keeps still for `wake_time`); chases toward the runner along its way
  (`find_path` every 0.2 s within 40 m, aiming at the farthest bin it sees clear to, straight for them within 14 m),
  stopping `STANDOFF` (1.3 m) short (from behind, its reared head still hides most of the runner while it bites:
  question 14); turns round in a lane, slowing to `turn_slow_share`; never passes debris (it slides along it). Its bite:
  when the runner will be in reach by the end of the telegraph, with no debris on the line between them, it rears and
  opens its jaws with a hiss (`centipede_bite`) for `bite_telegraph`, then strikes for `bite_window`, still reared, its
  head darting forward and back (`centipede_snap`; the bite's hitbox, `bite_width` × `bite_height`, live only then,
  reaches from its head's front to just short of its jaws' tips as drawn that frame, `CentipedeModel.jaws_reach` less
  `BITE_INSET`, at most `bite_reach`), then rests, its head sinking. It gives up (slows to a stop, legs folding, lenses
  dim) on a runner on a ceiling, `give_up_distance` behind along its way, or the runner `leave_margin` past its block's
  last wall; given up, or asleep as the runner passes, it retires `retire_behind` behind them. Not a big attack (nothing
  to take turns with).
- **Damage** (Damage and interactions: wounds and harmless parts). Its bite is an enemy attack: one hit (armor or the
  shield, then the invulnerability window; else it kills). Its head and four body boxes are `harmless`: a dash meets it
  through them (or its live bite) and wounds it (`dash_hits` 2: `WOUND_ENEMY`, one a dash), the second kills it (the
  player's kill and its score). `immune_to_weapons`, `claw_immune`, not `stompable`: auto-fire never targets it, the
  claws kill nothing, landing on it is no stomp and no bounce. A wound stuns it (`wound_stun`, at least `wake_time` if
  it was asleep: the wound wakes it), jaws shut, then it turns and chases from behind. Its hitboxes stay inside what's
  drawn (the bite under its head and within its jaws as drawn, every frame of a whole strike: test_centipede).
- **Look** (`CentipedeModel`, the owner's reference `docs/art/reference/centipede.jpg`; DESIGN-TBD). Nine riveted brass
  drums with steel bands (one multimesh), a pair of jointed steel legs each (one multimesh, stepping in a wave as it
  runs, folded while it waits), green glass canisters on every other segment (glowing, as drawn: a hazard colour) and a
  little steam; a welder-mask head 1.3 times the body's size with two big green lenses, hooked mandibles that swing
  open, and a red glow in its open jaws (the warning red); rearing lifts its head 0.8 m and its first two segments in a
  ramp, its lenses flaring (not with Reduced flashing). Wounded: a canister cracked, leaking green, sparks (none with
  Reduced flashing). Its glass, lenses and maw are all that glow; 11 draw calls and about 4,900 triangles; posed in
  world space each frame (`pose()`), built once per look (static caches), every part warmed with the level
  (`Centipede.warm_up`). Spawned `spawn_lead` (130 m) ahead and retired behind the runner, at most two a block: a few
  are alive at once.
- **Sounds** (`tools/asset_gen/sfx_bank_centipede.gd`, `tools/godot.sh sfx --only=centipede_wake,...`):
  `centipede_wake`, `centipede_bite`, `centipede_snap`, `centipede_wound`, `centipede_death`; volumes in
  `data/audio/sfx_library.tres`. It notes what it plays (`sounds_played`), and its states (`history`), bites (`bites`,
  `bite_contacts`) for tests.
- **Review.** `tools/showcase/centipede_showcase.tscn` (Review tools): its model posed (`--scenario=model --pose=walk|
  sleep|wake|bite|wounded`, `--angle`, `--near`) or a scripted encounter in a MazeKit block on the Terminal's skin
  through the game's camera (a head-on dash through it, then its bites at a closed wall, god mode).
- **Tests.** `test_centipede` (its rules and behaviour on physics at 3, 5 and 6 lanes in MazeKit blocks,
  `tests/helpers/maze_kit.gd`: hand-made maze blocks), `test_centipede_maze` (the generator over the Terminal's levels,
  the proof on hand-made blocks, its maze model against DebrisMaze's, endless mode, and `CentipedeBot`,
  `tests/helpers/centipede_bot.gd`: the proof's way out of every block with centipedes run on physics past live ones,
  the runner coming in from 25 m before the run-in with the dash just used there, checking their invariants and the
  runner's distance from each awake one with a field of its own), `test_centipede_fuzz` (slow: the bot on the levels'
  own placements at the other seeds, and on every way out that wakes them for every spot the rules may offer, alone and
  in pairs, over the same sweep), `test_damage_rules` (wounds and harmless parts). `test_doodads`'s rule for a runner
  who dashes through a doodad (time to see what it hid and move) leaves a waiting centipede out: its wake time and its
  bite's telegraph are longer than that reaction and switch (checked there).
