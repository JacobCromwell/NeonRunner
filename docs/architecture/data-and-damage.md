# Architecture: Data and the damage/interaction rules

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Data (tunables live in data, CLAUDE.md principle 7)

| File | What |
|---|---|
| `data/tuning/movement.tres` (`MovementTuning`) | the base run speed (quick play, tests; `REFERENCE_SPEED` and `pace()`, see Pace), jump, walls (and the blocked entry's bump), ramps and speed pads (their boosts share one fade), ceiling, piece sizes, zone doodads' sizes and push, camera, touch |
| `data/tuning/game_rules.tres` (`GameRules`) | lanes per device, death share, invulnerability, the armor (the free armor's hits and wait, the upgrade's per tier, a pickup's extra hit), the window after a theft, stomp, whether big attacks take turns, score, economy, stars |
| `data/tuning/powerups.tres` (`PowerupTuning`) | weapon tiers, claws, dash, magnet, slow time |
| `data/tuning/pickups.tres` (`PickupTuning`) | in-run pickups: where they appear, taking them, the charge cap, the look |
| `data/tuning/feature_recency.tres` (`FeatureRecency`) | the campaign's recency curve: how a level's pick weights follow how recently the campaign introduced each feature |
| `data/tuning/wall_fences.tres` (`WallFenceTuning`) | wall fences (B5): how often, how they pulse, their introduction, and the fairness margins (their sizes are the movement tuning's) |
| `data/tuning/dash_walls.tres` (`DashWallTuning`) | dash walls (H7a): the clear stretch around one, the wall route, the spacing's margin and the dash baits, the introduction's window, clearing plain pieces (how many a level is `LevelConfig.dash_walls`; the wall's size is the movement tuning's "Dash walls", its crumble the speed effects' "Dash walls") |
| `data/tuning/wall_gaps.tres` (`WallGapTuning`) | side wall gaps (Zone 2 on): spacing (easy/hard), jitter, length, the share on both walls, and the keep-out margins, all in seconds at the level's run speed (a boss arena that opts in has its own: `LevelConfig.wall_gap_tuning`) |
| `data/tuning/beach_wall_gaps.tres` (`WallGapTuning`) | the Beach's own wall gaps (`LevelConfig.wall_gap_tuning`, task D10b): its open walls (the Open walls group: the share of each wall to open, the shortest open and standing stretches, the most open on both walls at once) and a narrower clearance around what the walls hold |
| `data/tuning/performance.tres` (`PerformanceTuning`) | smooth frames (PERF1): how long a frame may spend dressing built chunks, and `test_frame_times`' frame-time budgets |
| `data/enemies/<type>.tres` (`EnemyTuning` subclasses) | per-enemy numbers, early/late pairs for campaign scaling |
| `data/shop/catalog.json` | shop items, tiers and prices (the armor's texts take `{hits}` and `{seconds}`, filled from `GameRules` by `ShopScreen.item_text()`) |
| `data/campaign/campaign.tres` → `data/zones/*.tres` → `data/levels/*.tres` | the campaign; each zone's run speed (`ZoneDef.run_speed`, a level may set its own), each level's pacing, fill pass, zone doodads and credits |
| `data/bosses/*.tres` | bosses (`BossDef`: slot, health, phases, arena, rewards, par times, armor rule), and a boss script's own tuning (`<id>_tuning.tres`) |
| `data/cinematics/*.tres` | cinematic slots (`CinematicDef`: each slot's scene), the arrival flyover's numbers (`arrival_flyover.tres`, `ArrivalFlyoverTuning`), the City outro's (`city_outro_tuning.tres`, `CityOutroTuning`), the Gangland boss intro's (`sewer_swarm_intro.tres`, `SewerSwarmIntroTuning`), the Gangland outro's (`gangland_outro_tuning.tres`, `GanglandOutroTuning`) and the Dead Zone intro's (`dead_zone_intro_tuning.tres`, `DeadZoneIntroTuning`) |
| `data/patterns/*.json` | generator patterns (every file in the folder is loaded) |
| `data/skins/*.tres` | zone looks |
| `data/audio/*.tres` | sound and music libraries |

Any `@export_range` number or bool on a resource registered with the tuning panel shows up under F6.

## Damage and interactions: one place (CLAUDE.md principle 8)

- **Hazards declare, `DamageRules` decides.** A `Hazard` (`scripts/world/hazard.gd`) is an Area3D on
  the hazard layer with properties: `is_electrical`, `is_enemy_attack`, `is_solid`, `armor_blocks_solid`
  (a solid hit armor absorbs all the same: a dash wall's crash, below), `breakable` (what any contact breaks:
  a dash wall), `dash_passes`, `steals_share` (a thief's touch, below), `enemy` (owning enemy or null) and
  `part` (`&"body"`, `&"top"`, `&"weak_point"`, `&"attack"`).
- The player checks contacts each frame (a swept shape query) and calls `Player.receive_hit(hazard,
  stomping)`, which asks `DamageRules.resolve()` and applies the outcome: `IGNORE`,
  `BLOCKED_ARMOR`, `BLOCKED_SHIELD` (then ~1 s invulnerability), `KILL`, `DEFEAT_ENEMY` (claws or
  dash), `STOMP` (enemy defeated, player bounces), `ROBBED` (a thief's touch, below). Nothing else
  hurts the player.
- **Thefts: the robbed hit** (GDD §9.12, the Tithe Collector; task B6 built the mechanism, task C5 the
  collector). The game's first non-lethal hit:
  - *The rule.* A hazard with `steals_share` > 0 resolves to `ROBBED` instead of hurting: after the
    dash, a stomp and the claws (which catch the thief: `DEFEAT_ENEMY`, `STOMP`), before everything
    that protects from harm. It's no hit, so armor, the shield, the invulnerability window and god mode
    don't stop it and nothing is used up; only the moment after a theft does (`Defense.theft_immune`:
    `Player.theft_immune_left`, `GameRules.theft_grace`), so one touch robs once. The player emits
    `robbed(hazard)` and the `robbed` event (its sound). DESIGN-TBD (`docs/questions/b6.md` 1, 2).
  - *The books* (`ScoreKeeper`). `rob(thief, share)` takes the share of the run's credits as they stand
    (collected, less what thieves hold), rounded down, and the thief holds it (`held_by`); a second
    theft takes a share of what's left. The level score never drops (GDD §7: never spent), so a theft
    never costs a star or a leaderboard place. `hold(thief, value)` is for credits a thief takes off the
    track before the player gets them (C5's collector sucks them up): it holds them, and the stars' best
    score (`max_credit_score`) leaves them out while it does. Any defeat of a thief is a catch: the
    director's `enemy_defeated` calls `pay_out(thief, enemy.jackpot_credits)`, which pays everything it
    holds plus its jackpot straight into the run's credits for a player-attributed defeat (with the
    `jackpot` sound; what it took off the
    track and the jackpot count as collected, score and best score). A thief must be spawned through the
    director. One that leaves uncaught keeps it: `stolen_kept()`, which `RunResult` takes out of the pay
    (`credits_stolen`; completion pays what's left plus the bonus, a death or a quit 20% of what's left)
    and the results screen shows as "Stolen". Signals `stolen(amount, thief)` and
    `recovered(amount, jackpot, thief)`; stats `thefts`, `credits_stolen`, `credits_recovered`,
    `jackpots`, `stolen_kept`. DESIGN-TBD (`docs/questions/b6.md` 3, 4).
  - *The feedback.* The HUD's credits count down in the loss colour, dipped (`CreditCounter.drop_on_loss`,
    the theme's `font_loss_color`: the violet accent, no hazard colour and not the warning red), with a
    "Robbed −N" pop-up; a payout pops "Recovered +N" and "Jackpot +N". Never the centre message, where a
    death shows. `RunEffects.coin_stream` flies coins in the credit look from the runner to the thief,
    and out of a caught thief into the runner (numbers in `SpeedFxTuning`, "Thefts"); no shake, no
    hit-stop, nothing flashes, and the loss look is a single fade, softer with Reduced flashing. Sounds
    `robbed` (coins tumbling away) and `jackpot` (a slot machine's payout), in `sfx_bank_ui.gd`.
  - *A thief declares* `Hazard.steals_share` on its hitboxes and `Enemy.jackpot_credits`, from a
    `ThiefTuning` (`scripts/enemies/thief_tuning.gd`: `steals_share` 0.25, GDD §9.12; `jackpot_credits`).
    The stand-in thief (`scripts/enemies/stand_in_thief.gd`, `data/enemies/stand_in_thief.tres`; never in
    the campaign) is a plain gold block that crosses the lanes ahead of the runner, planned to be over the
    lane it aims at when the runner arrives; one hitbox, its stomp part, so from above it's a stomp and
    any other touch robs; after a theft it makes off ahead and up (`Hazard.contacted`). Quick play's
    `--thief` sends one after another (`StandInThief.start_review`, loaded by path from `LevelRun`), its
    numbers in F6, and starts the runner with a purse (`review_purse`, 400) so the first theft has
    something to take.
  - **The Tithe Collector** (GDD §9.12, task C5, from Corporate 2, skipping the Dead Zone, back in the
    Golden Zone): `scripts/enemies/tithe_collector.gd`, `tithe_collector_tuning.gd` (extends
    `ThiefTuning`), `data/enemies/tithe_collector.tres`, one pattern
    (`data/patterns/tithe_collector.json`, `"requires": ["tithe_collector"]`, placed many times across
    a level like the drone's, each its own approach); it's out of `LevelConfig.PLANNED_FEATURES`. A
    small, fast gold drone with a collection plate (plain metal, never glowing, unlike a heli drone: no
    rotors, and anti-grav pads don't affect it, since it never connects to `Player.movement_event`).
    *Approach*: like the stand-in thief (task B6), it appears `start_ahead` ahead of the player and
    closes in at `approach_speed`, slower than the runner, low to the floor the whole way in, so an
    ordinary run brings it into stomp and dash reach without a boost; a player who leaves its lane
    before it arrives is never touched. It sets `steals_share` on its one hitbox and `jackpot_credits`
    on itself from its tuning, and flees ahead and up on a theft (`Hazard.contacted` with `ROBBED`),
    exactly like the stand-in thief. *Weaving* ("the most dangerous lanes"): every `weave_interval` it
    counts gaps, fences, floor cuts and other floor enemies in each lane over `weave_lookahead` ahead of
    its own track position and eases toward the lane with the most (ties keep its current lane; with
    nothing dangerous ahead it settles over the player's own lane) — not the player's lane outright, so
    catching it means following it into the risk; it's a body to touch, not a hazard, so this can never
    make a lane unfair, it only ever changes where the 25% risk or the catch's reward sits. *The
    vacuum*: `CreditField.take_near(lane, at, reach)` is the small hook (hide an idle floor credit in
    `lane` within `reach` of `at` and return its value and position, or `{}`); every `vacuum_interval`
    the collector calls it for its own lane and position, `world.score.hold(self, value)`s what it
    gets, and flies it in with `RunEffects.coin_stream` for the visible stream GDD §9.12 asks for. *The
    approach cue*: not a hazard warning (touching it isn't an attack), but still noticeable: a smug
    chuckle plays for everyone to hear (`world.play_sfx`, like the Resonator's warning) as soon as it
    exists. It reports no big attack (`is_major_attack_active` stays false): it isn't an attack, so it
    never takes a turn. *How long it stays* (task H10, GDD §9.12, owner, October 8, 2026: "twice as
    long"): untouched it leaves by distance, so its stay is `(start_ahead + passed_behind) /
    approach_speed` seconds (`TitheCollectorTuning.stay_seconds()`): the pace stretches all three alike,
    so it is the same in seconds at every run speed. First built at 30 m and 8 m over 7 m/s, about
    5.4 s; the owner doubled it by halving `approach_speed` to 3.5 m/s (about 8.6 s ahead of the runner,
    2.3 s behind, 10.9 s in all) with `start_ahead` and `passed_behind` (now a tunable, was a const) as
    they were. Its pace along the track is the runner's less 3.5 m/s, so it covers about 2.7 times the
    track it did (and sucks up about 2.5 times the credits in a credit-dense lane); a catch's window is
    longer too (it closes more slowly). Robbed, it flees as it always did (`flee_speed`, `gone_ahead`).
    A spawn param `approach_speed` overrides the tuning's: Hostile Takeover's Board passes its
    `tithe_approach_speed` (7 m/s, the first-built stay), because a 130 m flatcar roof is too short for
    the longer one (at 3.5 m/s it would meet the runner past the roof's end, over the coupling the
    runner jumps, and be stomped mid-jump). It needs no reserved window in the generator: touching it is never a hit and it is never a
    keep-out for anything (the generator's keep-out for it ends at its `at`, before it appears).
- **A stomp on the ceiling** (C1): a hitbox that hangs from a ceiling (`Hazard.upside_down`, the
  Barnacle Turret's crown) has its top facing down, toward a rider on the ceiling, who stomps it by
  dropping back onto it after a jump (`Player._is_stomping`: on the ceiling, falling back toward it with
  the feet within `GameRules.stomp_tolerance` of the hazard's `bottom_y()`). Only such hitboxes can be
  stomped from the ceiling; on the floor nothing changed.
- Falls aren't hazards: the Player handles them (the grapple hook saves one fall).
  - **Counted from the floor fallen from** (task E5e-a, for GDD §10's climb, the Beach's boss): the pit
    (`pit_depth`: no more lane switches, jumps or wall entries; the grapple fires here) and the fall's death
    (`fall_death_depth`) are measured down from `Player.fall_base()`: the floor base a boss that raises the
    floor sets (`Player.floor_base`, 0 in every level and every other boss fight), or the floor the runner
    last stood on (`Player.floor_y`) if that's lower, so a floor base raised ahead of the climb never drops a
    runner who isn't up there yet. A fall off a roof 20 m up then ends as soon, and as far below it, as a fall
    into the street's pit (about 0.5 s), where it took about 1.2 s counted from the street.
  - **The save goes where the boss says**: the grapple's save, and a revive after a fall, pull the runner up
    with the grapple's pull from just under a floor (`Player._pull_up`): by default straight up out of the pit
    (just under `fall_base()`, as it always was), or where `Player.grapple_save` says, a Callable a boss fight
    sets to its own hook as it begins (`BossEncounter._grapple_save(player, cause)`, `cause` &"grapple" or
    &"revive"; the framework's returns `{}`, the default). It returns `{lane, height}`: the lane to pull them
    into (moved across like a lane switch) and the world height of the floor to pull them up onto (GDD §10:
    the Beach's climb pulls them up onto the higher roof, into its nearest lane that leads up). Either may be
    left out; the save never pulls them down.
  - **A fast fall lands where it crosses a floor.** A landing is found by `_support_top`'s rays, 0.6 m above
    the feet to 0.3 m below, and allowed up to `pit_depth` below the top; a fall faster than `pit_depth` a
    frame could end a frame that far below a top it passed and drop through it. Such a frame now looks from
    where the feet were as it began (`_crossed_top`) and lands on the highest top they passed. Slower falls
    never need it, so they land exactly as before. It catches the air slide's fast fall (22 m/s and more):
    on the unchanged code (437d46e), a slide pressed 1 to 40 frames into a jump dropped through the street
    at 4 of those 40 timings (3, 11, 30 and 34 frames), and at the same 4 threw a rider who had jumped off
    a ceiling off it mid-ceiling as they slid back up (an early `hull_end`). It also catches long drops
    off high ceilings, and the anti-grav pull up to a ceiling higher than `ceiling_height` (which could
    pass through it and fall back).
- **The armor** (GDD §4 and §8, owner's playtest, September 30, 2026) is a state with rules of its own,
  `DamageRules.Armor`: up with its hits left, or broken and coming back. Every run the profile starts
  (levels, boss fights, retries, quick play, endless, the web demo) carries it free (`Loadout.armor`),
  and the shop's armor is an upgrade to it (its tier, `tiers[&"armor"]`; the equip toggle switches only
  the upgrade off). RunWorld makes the run's armor (`Armor.create(rules, tier, carried)`) from
  `GameRules`' Armor group: the free armor's hits (1) and wait (30 s), and each tier's (placeholders
  2/30 s, 2/25 s, 3/25 s, 3/20 s: the tiers alternate one more hit and a shorter wait). The Player holds
  it (`armor_state`; `armor` is its hits left, and setting it, for tests and tools, puts that many hits
  up) and applies what resolve() says: a blocked hit takes one (`block()`) with the usual
  invulnerability (event `armor_hit`), the last one breaks it (`item_used(&"armor")`, `armor_break`),
  and from the Player's physics step its wait runs (`tick()`: the run's clock, so a pause or a death
  stops it, the same at any frame rate) until it's back whole (`armor_back`). A revive brings it back
  whole (`restore()`); an armor pickup (`take_pickup()`) does too, at once, and on whole armor adds a
  hit, up to `armor_pickup_extra_hits` over its count. `armor_changed` tells the HUD and the player
  model; `ScoreKeeper` counts every blocked hit. A bare `Loadout` (tests, tools) has no armor until a
  pickup gives it. DESIGN-TBD (`docs/questions/g3.md`): worn armor gets nothing back until it breaks;
  the pickup's extra hit; the revive; that the free armor can't be switched off.
- Enemy shots go through `ProjectilePool.fire_enemy()`; the pool sweeps each shot against the
  player's hitbox and calls `receive_hit`, so armor, shield, invulnerability and the dash all apply.
- **Blocked moves bump, never hurt.** A lane switch into a solid side (a lane blocker: the hover
  truck's, a boss's block) and a wall entry where the wall is blocked (a sign, or a wall a boss takes
  away; GDD §3) move the player out toward it and back (`Player._start_bump`) with the clank
  (`lane_blocked` / `wall_blocked`). The player stays in their lane and can act meanwhile; collision is
  unchanged. The wall's bump (`wall_bump_distance`, `wall_bump_time`) stops short of any hazard or wall
  blocker in its way, so a sign that reaches down to the player stops it at its face, and the model
  leans away from the wall on the way back. On a ceiling over fewer lanes (a narrow ceiling, GDD §3) a
  move toward a lane it doesn't cover is blocked the same way (`ceiling_blocked`, the same clank;
  `Player._bump_ceiling_edge`, a bump that stops short of the ceiling's edge). The player asks the
  ceilings themselves: a ray on the hull layer over the middle of each lane (`_ceiling_over`), so the
  track's ceilings and a boss's (`BossProps.ceiling`) hold the player in alike, and a pad lands the
  player in its own lane even if a switch was under way (`_hold_to_pad_lane`). A ceiling whose lanes end
  at different distances (`BossProps.ceiling_lanes`: one section per run of lanes ending together) holds
  the player within the lanes still covered where they are, and each lane drops at its own end.
- **Ceilings at any height** (task E5e-a, for GDD §10's climb). Each ceiling carries its own height: its
  collision box on the hull layer. A pad flips the player to the first ceiling over the pad's lane within
  `Player.CEILING_SEARCH` (30 m) of the feet (`_ceiling_over_pad`), and `Player.ceiling_y` holds the
  height of the ceiling they ride (or rode last), which the flip (`_flip`), the ride (`_support_top`,
  `_surface_y`), the drop at its end, the lanes on it (`_ceiling_over`), the shadow on its underside, the
  magnet's field and the climbing camera all use. With no ceiling over the pad the standard height stands in (`ceiling_height` above
  `fall_base()`): the player flips up into nothing and drops back, as ever. A ceiling within
  `HEIGHT_SNAP` (1 mm) of the standard height is taken at exactly that height, so every level's ceilings
  (all at `ceiling_height`) play exactly as before; one that moves while it's ridden (a gunship's belly
  coming down, the Floating Head's third-window ceiling lowering in) takes `ceiling_y` along while the
  player stands on it (`_follow_ceiling`), so the drop at its end comes from where it really is. At its
  end the player drops onto whatever is below on the floor layer: a raised roof (landed on at any height
  through `_support_top`, and `_crossed_top` for a long drop), the floor far below, or nothing (a fall).
  `Player.floor_y` is the floor they stand on or last stood on (the street or a raised one).
- **Wall fences are fences** (task B5; GDD §9.1: "the same rules as floor fences"). A wall fence's field is
  an electrical Hazard like a floor fence's (TrackBuilder._build_wall_fence), so DamageRules lets armor, the
  shield and the dash through and never claws, and weapons never see it (it's no enemy). It's on the
  hazard layer only, never a wall blocker: the wall is open to enter, and a live field just hurts. Its
  field reaches out from the facade over the wall runner's body (on a wall the hurtbox lies along the wall
  and reaches out by its height, Player.hurtbox_aabb) and stops short of a floor runner in the middle of
  the outer lane (WallFencePlan.reach), so a wall runner within its band is hit while it's on, a floor
  runner beside it never is, stepping onto the wall into a live one is a hit, and a blocked entry's bump
  never reaches into one (Player._bump_room). The Player needed no change.
- **Zone doodads push, never hurt** (GDD §3, owner's playtest September 30, 2026; task G5). A doodad is
  no hazard: the track builds it as a body on a layer of its own (`TrackBuilder.LAYER_DOODAD`) that is
  also a lane blocker, with a standable top on the floor layer (`_build_doodad`). On the floor, the
  player meets its front with the visual body (sliding, its slide height; from just above the feet)
  swept ahead by the moment a shove needs to clear its side (`Player._check_doodads`,
  `_push_clear_seconds`), so the body never sinks into it, and is pushed into the neighbouring lane over
  `doodad_push_time` (`_start_push`: the lane switch machinery with a sharper ease, `_push_x`), with the
  `doodad_push` event: the thud (`doodad_push.wav`), a small shake (`SpeedFxTuning.push_shake_*`) and
  the runner leaning into it. Head-on the push goes to the doodad's side (seeded by the generator, the
  same on every attempt); a front corner caught mid-switch pushes back the way the player came (never
  through the doodad); a side with no room (the track's edge, a lane blocker there) gives way to the
  other. A jump or a slide into one is pushed the same way (doodads are too tall to jump), a switch into
  its side is a blocked move (above: the clank and the bump), and a player who comes down on its top
  lands on it and runs along it. It costs nothing: DamageRules never sees it, the run's speed stays,
  and shots and weapons pass through it. Wall runners and ceiling riders never meet one (the generator
  keeps them out of the outermost lanes and from under ceilings).
- **The dash smashes a zone doodad** (GDD §3, owner, October 8, 2026; task H5): dashing into one breaks it
  apart, and the player keeps their lane with no push and no damage. The track builds every doodad as a
  `DashBreakable` (`scripts/world/dash_breakable.gd`: an Area3D carrying its layout entry, its box and the
  colours its pieces fly off in). In `Player._check_doodads`, a doodad that comes within the push's reach
  while the player is dashing is *claimed* if the dash lasts until the body gets there (`_dash_claims`: its
  front within `_dash_reach()`, the track the dash still covers, a ramp's or speed pad's boost counted as it
  fades, `MovementTuning.boost_distance`); a claimed one breaks when the body meets it, a frame before they
  touch (`_smash`: head-on, at a front corner or from the side), and a dash that ends short of one leaves it
  unclaimed, so it pushes as usual, at the push's usual moment. A claim outlives the dash by
  `SMASH_CLAIM_GRACE` (0.1 s), since the contact can come a frame or two after the dash's last one. The
  doodad pushing the player is left alone while its push carries them, so a dash started during a push
  doesn't smash that one: the push completes; once a move cuts the push short, a dash that steers back into
  it claims it and breaks it where the body meets it. A lane switch into a doodad's side while dashing isn't blocked (`_lane_blocked(target,
  dash_through)` claims it: "dashing into one"), and the body breaks it where it meets it; any other solid
  side (a hover truck's, a boss's prop) still bumps a dashing player. `DashBreakable.smash()` switches off its
  collision (its body, its lane blocker and its standable top) and hides its look, and marks its layout
  entry `smashed` (as an EMP marks a fence `disabled`), which `TrackBuilder._build_doodad` never builds:
  it stays broken for the rest of the attempt, a revive in place too, and a retry plays a fresh copy of the
  level's build in a world built anew (`LevelCache`, task PERF2: the mark was on the attempt's own copy), every
  doodad whole (a test that runs one layout twice gives each run its own copy). The player
  emits `smashed(breakable)` and the `doodad_smash` movement event (`<kind>_smash`): the crunch
  (`doodad_smash.wav`), the pieces (`RunEffects.rubble`) and a light shake (Speed effects). It costs
  nothing and scores nothing, and DamageRules never sees it. Enemies' fairness checks read the layout
  (`LevelLayout.doodad_between`), so they hold an attack by a smashed doodad's stretch as they did before it
  broke: the same on every attempt. An attempt without a dash is exactly as before. Task H7a's dash walls
  share the path: a `DashBreakable` of another `kind` (with its own `<kind>_smash` event and sound),
  `Player.smashed` and the run's effects.
- **Dash walls: dash through, or take a hit** (GDD §9.14, owner, October 8, 2026; task H7a). A building
  standing across every floor lane (the generator, the track and the look below). The track builds each as a
  `DashBreakable` of kind `dash_wall` on a layer of its own (`TrackBuilder.LAYER_DASH_WALL`: the box its look
  fills; never a lane blocker, a wall blocker or a hazard itself) with one Hazard child, its hitbox: the box
  less `MovementTuning.dash_wall_inset` at its sides and its face, from `TrackBuilder.DASH_WALL_FLOOR_LIFT`
  above the floor to its top (a slide never passes under it, and it's taller than any jump), declaring
  `is_solid`, `armor_blocks_solid` and `breakable` (the wall). It breaks as the runner reaches it, whatever
  they do (`Player._check_dash_walls`, after `_check_doodads`, before the triggers and hazards; a level without
  walls skips its query: `Player.dash_walls`, the layout's own list, which RunWorld hands it), so it never
  stands between the chase camera and them:
  - **the dash** claims it as it claims a doodad (`_dash_claims`: the dash lasts until the body gets there;
    the query reaches as far as the dash still covers) and smashes it a frame before the body would touch it
    (broken by `dash`): no hit, the lane and the speed kept;
  - **a wall runner** beside it (their hurtbox clear of the hitbox across and up: the strip of
    `dash_wall_wall_room` the building leaves by each side wall; `_in_wall_way`) passes it: it crumbles as
    their front reaches its face (broken by `pass`), costing nothing;
  - **anyone else** meets its hitbox: the crash (`_check_hazards` → `receive_hit`). DamageRules decides it as
    any hit, with one declared exception: armor that is up blocks a hazard with `armor_blocks_solid` (GDD
    §9.14: "armor or the shield absorbs it", an exception to the rule that armor never blocks solid
    collisions; nothing else declares it, so a sign or a truck's body stays a hit armor never blocks), then
    the shield, else it kills ("dash wall"); god mode and the invulnerability window ignore it, the dash
    passes it. Whatever the outcome, `receive_hit` breaks a hazard's `breakable` (broken by `crash`, or
    `dash` for a dashing body), so the runner goes on through it after an absorbed hit, with the usual
    invulnerability.
  `Player._break(b, how)` does it: `DashBreakable.smash(how)` (its entry marked `smashed` and `broken_by`, its
  box and hitbox off, its look hidden), the counts (`smashes`, `crashes`, `wall_passes`), `smashed(b)` and the
  `dash_wall_smash` event: RunEffects crumbles it (Speed effects) and the event plays the crash
  (`dash_wall_smash.wav`). It stays broken for the attempt (never built again), and a retry rebuilds it whole
  (a fresh copy of the level's build, as for a doodad).
  Scores nothing (DESIGN-TBD, `docs/OPEN_QUESTIONS.md` item 653). The layout counts a wall as a doodad in every lane
  (`LevelLayout.doodad_between`, and `dash_wall_between`), broken or not, so every enemy that holds an attack
  by a doodad holds it by a wall the same on every attempt.
