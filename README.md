# Neon Runner (working title)

A neon 3D runner for PC (Steam), Android, iOS and a web demo. You run lanes, side walls and ceilings
through zones full of enemies, and a single hit ends the run. Built with Godot 4.7.2 and GDScript only.

**Status:** the game is built around everything designed so far:
- the whole campaign structure: six zones and 15 levels
- seven enemy types, plus fence generators
- the shop, power-ups and economy
- every screen and the HUD
- all six zone looks (the Neon City, Gangland, the Marketplace, Corporate, the Dead Zone and the Golden Zone),
  owner-supplied zone music, generated default music and sound effects
- all three build flavors

Boss fights have their framework (they play in the runner, with phases, a health bar, checkpoints,
stars and payouts); a test boss shows the framework at work. The Neon City's boss, the Floating Head,
is built and plays in the campaign after City 3 (debug builds: `--boss=city_boss`), and so is the Dead
Zone's Sleep Taker after Dead Zone 2 (`--boss=dead_zone_boss`), and the Marketplace's House after
Marketplace 2 (`--boss=marketplace_boss`), the Corporate zone's Hostile Takeover after Corporate 2
(`--boss=corporate_boss`), and Gangland's Sewer Swarm after Gangland 3 (`--boss=gangland_boss`); the
Golden Zone's final villain is still a placeholder slot. The short cinematics are built with a code-driven cinematic toolkit
(camera paths, the runner and cyborgs on the humanoid rig, timed events, skippable); until the owner
describes the story beats, each zone's intro (and the City's boss intro) plays a placeholder arrival flyover
over the zone, and the outros are placeholder cards.
Every placeholder decision is listed in `docs/OPEN_QUESTIONS.md`.

Docs: `docs/GDD_CHECKPOINT.md` (the design, the authority), `docs/OPEN_QUESTIONS.md` (open decisions and
placeholders), `docs/ARCHITECTURE.md` (how the code fits together), `docs/NEXT_STEPS.md` (risk tests and the
original build plan), `CLAUDE.md` (rules for agents).

## Play it

Engine: **Godot 4.7.2-stable** (standard build, not .NET). You don't need to import the project in Godot.

- **From a terminal (WSL, Linux or macOS):** `./play.sh`
- **From Windows:** double-click `play.cmd`, or run it from a terminal.

Either one plays whatever is in this folder right now and opens on the title screen. The first run finds Godot and
remembers where it is; after that, resources are re-imported automatically whenever a file changed. If Godot is
somewhere unusual, set the `GODOT` environment variable to its executable. Open the editor with
`tools/godot.sh edit` or `play.cmd edit`.

**Under WSL, install the native Linux Godot once:** `tools/install_godot_wsl.sh` (downloads the pinned build to
`~/.local/godot`, links `~/.local/bin/godot4`, and re-imports). `tools/godot.sh` prefers it over a Windows `.exe`,
which reads the project over `\\wsl.localhost` and takes ~66 s to start instead of ~2 s (`docs/PERFORMANCE_AUDIT.md`).
In a WSLg window, `play` and `edit` use the Compatibility renderer on the GPU (Mesa's D3D12 driver; Ubuntu has no
Vulkan driver for WSL, so Forward+ there would be software-rendered); pass `--rendering-method forward_plus` to
override. Sound in the window needs `sudo apt install libpulse0`; headless runs (tests, smoke) need neither.

Options for testing (debug builds only, the same with `play.cmd`):

| Option | What it does |
|---|---|
| `--quick` | Quick play: the prototype level, restarting on death, with the debug keys and HUD |
| `--seed=N --lanes=N --difficulty=X` | Quick play with that seed, lane count (3, 5 or 6) or difficulty (0–1) |
| `--features=cyborg,drone` | Quick play with extra level features: `ramps`, `ceilings`, `pulsing`, `speed_pads`, an enemy type (`cyborg`, `window_cyborg`, `host`, `generator`, `hover_truck`, `octodog`, `screech`, `screech_vents`, `drone`, `barnacle_turret` (with `ceilings`), `resonator`, `buzz_overdrive`, `tithe_collector`, `gilded_sentinel` (with `--skin=golden` or `golden_palace`, whose walls open its niche), `enforcer_truck` (with `octodog` or `buzz_overdrive`, its baits)), wall fences (`wall_fences`, and `wall_fences_partial` for partial ones), or `floor_cutter` (a grey-box stand-in that cuts a lane's floor into a gap during play, for review). The full list is in `LevelConfig` |
| `--god` | Hits don't kill (falls still do) |
| `--nofall` | The grapple never runs out, so falls never end the run |
| `--full-loadout` | Every power-up |
| `--skin=gangland` | Quick play in another zone's look: `city`, `gangland`, `marketplace`, `corporate`, `corporate_plaza` (Corporate's plaza floor), `dead_zone`, `golden` or `golden_palace` (Golden 3's interior) |
| `--speed=25` | Quick play at another run speed (m/s): a zone's pace, from 21 in the Neon City to 25 in the Golden Zone. The level keeps its timing in seconds (campaign levels already run at their zone's speed) |
| `--doodads=0.6` | Quick play with zone doodads (scenery in lanes that pushes you aside, never hurts; the dash smashes it, with `--full-loadout`): the chance each stretch with room for one gets one. Campaign levels have their own share |
| `--pickups` | Quick play with armor, shield and grapple pickups in turn, to review their look (`--pickups=shield,grapple` for some). In the game only boss fights have pickups |
| `--thief` | Quick play with stand-in thieves, one after another: a gold block that crosses the lanes and robs 25% of the run's credits from a runner who touches it (it doesn't kill, even without `--god`); catch it (stomp it, shoot it, dash or claw through it) for what it took plus a jackpot. The runner starts with 400 credits, so the first theft has something to take. A review aid for the Tithe Collector's mechanism; no level has one |
| `--level=city/2` | A campaign level with the full game flow (also takes `--lanes`, `--god`, `--nofall`, `--full-loadout`). Any campaign step works: `--level=gangland/intro` plays Gangland's arrival flyover, then its first level |
| `--boss=test_boss` | A boss fight by its id: the test boss (or any boss outside the campaign) as quick play, starting over after a death or a win; a zone's boss (`city_boss`: the Floating Head; `dead_zone_boss`: the Sleep Taker; `marketplace_boss`: The House; `corporate_boss`: Hostile Takeover; `gangland_boss`: the Sewer Swarm) with the full game flow once it's built, and as quick play while it's being built. Takes `--lanes`, `--god`, `--nofall`, `--full-loadout`, `--skin=<zone>` and `--phase=N` (start at phase N, as a checkpoint would) |
| `--flavor=web_demo` | Behave like another build: `full_pc`, `full_mobile` or `web_demo` |
| `--frame-graph` | Show the frame-time graph (F7, see Smooth frames) from the start of every run |

Example: `./play.sh --lanes=6 --features=octodog,ceilings --god`, or the test boss's last phase:
`./play.sh --boss=test_boss --phase=3 --god --nofall`.

## Music

Every level within a zone shares that zone's song; there are no level-specific tracks.
The owner-supplied MP3s are copied unmodified into `assets/music/`:

| Gameplay | Song |
|---|---|
| Zone 1 - Neon City | Under the Iron Sky |
| Zone 2 - Gangland | Alleyway Ambush |
| Zone 3 - Marketplace | Jackpot Plaza |
| Zone 4 - Corporate | Concrete Fever |
| Zone 5 - Dead Zone | Beneath the Cracks |
| Zone 6 - Golden Zone | View from the Zenith |
| Boss 1 - Floating Head | Apex Combat Maneuver |

Menus, cutscenes (including the Boss 1 intro), and unmatched bosses keep their generated default
music. `Horizon_Of_Glass.mp3` is intentionally unused. Gameplay replacements are selected through
`zone_tracks` and `boss_tracks` in `data/audio/music_library.tres`; the original track entries remain
available for cinematics. Songs loop in full and retain the existing pause duck, death dip and
zone completion sounds (`riff_tracks`), whose keys have not been retuned to the supplied songs.
`tools/godot.sh music` regenerates only the default WAVs, not the supplied MP3s.

## Controls

| Action | Keyboard | Touch (a mouse drag works too) |
|---|---|---|
| Change lane / enter a wall from the outer lane | Left / Right arrows | Swipe left / right |
| Jump (wall jump while on a wall) | Up arrow or Space | Swipe up |
| Slide (fast drop in the air) | Down arrow | Swipe down |
| Juggernaut dash (power-up) | Shift | Tap |
| Slow time (power-up, PC only) | E | – |
| Pause (skips a cinematic) | Esc / P | Pause button (a cinematic's Skip button) |

Every key can be rebound in Settings. PC runs use 5 lanes and mobile runs use 3 (the exact PC count is still
open: 5 or 6).

Debug keys (debug builds): **R** restart, **F1** lane count 3 → 5 → 6, **F2** next seed, **F3** difficulty,
**F4** god mode, **F5** show hitboxes, **F6** tuning panel, **F7** frame-time graph, **M** mute.

## What's in the game

- **Campaign:** 15 levels in six zones, about 35 minutes of flawless running: the Neon City (the web demo's
  zone) and Gangland with three levels each, the Marketplace, Corporate and the Dead Zone with two, and the
  Golden Zone with three.
  Each zone has a boss slot and cinematic slots; its intro plays a placeholder arrival flyover over the zone
  in its own look (skippable). Each level introduces about one new thing (GDD §5), where
  its data says (`feature_starts`):
  1. City 1 *Rooftop Rush*: gaps, fences, walls and signs, then cyborgs late in the level.
  2. City 2 *Skyway*: ceilings and anti-grav pads.
  3. City 3 *Neon Crossfire*: pulsing fences, window cyborgs and the hover truck.
  4. Gangland 1 *Scrapyard Streets*: sewer screeches and ramps.
  5. Gangland 2 *Dog Run*: Octodogs and speed pads.
  6. Gangland 3 *Rotor Wash*: fence generators and heli drones.
  7. Marketplace 1 *Awning Alley*: the Barnacle Turret.
  8. Marketplace 2 *Shopfront Sparks*: wall fences, and sewer screeches from the shopfronts' wall vents.
  9. Corporate 1 *Maglev Line*: the Buzz Overdrive, then partial wall fences.
  10. Corporate 2 *Checkpoint Plaza*: the Tithe Collector and the Enforcer Truck, and a heavier military
      presence (more drones, hover trucks and Buzz Overdrives).
  11. Dead Zone 1 *Ashfall*: hosts and the Cyborg's Bad Dream.
  12. Dead Zone 2 *The Hush*: a quiet, eerie remix with nothing new: long silent stretches broken by short
      bursts of threats, fewer enemies but more hosts (standing alone in the silence), and darker lighting.
  13. Golden 1 *Gilded Canals*: the Resonator.
  14. Golden 2 *Sentinel Row*: the Gilded Sentinels, and the hardest level.
  15. Golden 3 *The Golden Palace*, then the final boss.

  Everything introduced keeps appearing later (the Buzz Overdrive from Corporate 1 through the Golden Zone),
  and a level's newest things get the most of its picks, taken from older things of their kind (enemies from
  enemies, obstacles from obstacles), so no level gets easier; enemies whose rules keep only so many (hosts,
  hover trucks, drones, Octodogs, Resonators) and the rare vent screech aren't boosted (the campaign's recency
  curve, `data/tuning/feature_recency.tres`).
  Level names are placeholders, except the Golden Palace.
- **Movement:** floor lanes, side-wall runs and wall jumps (a sign blocking the wall bumps you back with a
  clank), anti-grav pads onto the ceiling, ramps (higher onto the wall, with a speed boost that fades like
  a speed pad's), speed pads. From the second half of City 2 on, about half the ceilings cover only some of
  the lanes (a placeholder amount): on one you switch lanes only within it (a move past its edge bumps you
  back with the clank), and a one-lane ceiling is short.
- **Obstacles:** gaps (every campaign level has a couple of wider ones: still a normal jump, but an Enforcer
  Truck following you into one is wrecked), signs, and electric fences (full-height or gapped, always-on or
  pulsing), some with a generator that switches them off. Floors that turn into gaps during play: after a warning, a lane's floor
  is cut away from ahead of you back past you, its edges glowing the gap orange (the Buzz Overdrive's cuts;
  in quick play also a grey-box stand-in, `--features=floor_cutter`). Wall fences (from Marketplace 2):
  the same pink crackle across the wall-run path between emitters on the facade, switching off and on with
  the floor fences' flicker and crackle before each switch on: time your wall run past one, or jump off the
  wall. From the Corporate zone some cover only the bottom of the wall (jump onto the wall to run above
  them) or its top (step onto the wall without a jump to run below them). Armor, the shield and the dash get
  you through, claws don't, and a generator's EMP switches them off. They're never where a ramp launches you
  along their wall, never beside a sign or a window cyborg, and the outer lane beside them is always clear
  to drop into (in quick play, `--features=wall_fences,wall_fences_partial`).
- **Enemies:**
  - cyborgs, with the panic variant and hosts; their laser firing sound is about 30% louder. Up to two
    bursts of the cyborgs, window cyborgs and Barnacle Turrets fly at once (`GameRules.max_bursts_in_air`,
    in the F6 panel), and never so that a single lane switch can't dodge them
  - window cyborgs
  - the hover truck mini-boss
  - the Octodog; its active charges can kill other vulnerable enemies on physical contact (now and then a cyborg
    stands in the path of an Octodog's lunge or a Buzz Overdrive's charge, so you see it flattened)
  - the sewer screech
  - the heli drone
  - the Cyborg's Bad Dream, released by killing a host cyborg (from Dead Zone 1; in quick play, try
    `--features=cyborg,host,ceilings`)
  - the Barnacle Turret (from Marketplace 1): a dome with a chest cannon that pops out of a ceiling's
    underside and shoots only at a rider on that ceiling, the cyborgs' way (its muzzle glows red with a
    charge-up sound, then a short burst: switch lanes). Armor or the shield absorbs a body-contact hit;
    without protection, running into it is deadly. Claws, the dash, a stomp
    (jump on the ceiling and drop back onto it) or weapons kill it. Mechanical in most zones, a furry
    creature in Gangland and the Marketplace (in quick play, `--features=ceilings,barnacle_turret`)
  - the Resonator (from Golden 1): a golden broadcast spire hovering far ahead. When its halos line up
    and a fire roars and crackles up, breaking into a crashing wave, a red wave rolls along the floor
    across every lane: jump it, or be on a wall or the ceiling. Shoot it down or wait until it leaves
    (in quick play, `--features=resonator`)
  - the Buzz Overdrive (from Corporate 1): a buzzsaw tank parked in its lane far ahead. It rolls ahead of
    you, then revs (the spin-up, its eyes flaring, a red line over its lane) and charges back down its lane,
    cutting the floor into a gap behind it: leave its lane. The armor or shield blocks it and the floor holds
    a second; the missile tiers can usually shoot it before it charges, which saves the floor; the dash
    smashes it. Big attacks take turns: if another enemy's is still going on when it would rev, it drives
    off ahead instead and its lane stays whole. Its active charge can also kill other vulnerable enemies
    it physically hits, without awarding player kill bonuses (in quick play, `--features=buzz_overdrive`)
  - the Tithe Collector (from Corporate 2, skipping the Dead Zone, back in the Golden Zone): a small gold
    drone with a collection plate, smug and gaudy (plain metal, no rotors; anti-grav pads don't affect
    it). It appears ahead of you and closes in slowly (left alone, it stays in the level about 11
    seconds), sucking up the credits in its lane along the way
    and weaving toward whichever lane has the most hazards ahead, so chasing it is the risk. Touching it
    isn't deadly: it grabs 25% of the credits you've collected and flies off. Catch it (stomp, shoot, or
    dash through it) for everything it took, plus a jackpot (in quick play, `--features=tithe_collector`,
    or review its shared mechanism with `--thief`)
  - the Gilded Sentinels (from Golden 2): golden statues with halberds in lit niches set into the walls at
    wall-run height, their eyes red. When its eyes flare and stone grinds (0.6 s of warning), a Sentinel's halberd cuts what
    lights up red: a band of its wall around the height where you step onto it, and the outer lane. Leave
    the lane, or on the wall pass above the band (jump onto the wall) or below it (onto the wall early).
    Later ones swing twice or stand in pairs across the street. The armor or shield blocks the cut;
    weapons or a wall jump off the wall right by its head kill it (in quick play,
    `--features=gilded_sentinel --skin=golden`). Decorative knights in both Golden skins stand in
    recessed mounts at the bottom of the walls, not on the high ledges; only the live enemies attack.
  - the Enforcer Truck (from Corporate 2, then every later level with Octodogs or Buzz Overdrives): an
    armoured police truck that chases you from behind the camera. Its headlights and red and blue light bar
    shine on the floor of its lane and a marker at the bottom of the screen shows the lane; it copies your
    lane changes a moment late. When your lane lights red ahead and its whine rises, change lanes before
    its lasers come up the lane. Weapons, stomps, the claws and the dash can't hurt it: bait an Octodog's
    lunge or a Buzz Overdrive's charge into it by dodging late (it closes right up behind you while an
    Octodog attacks), or lead it into a stopped cut. Cyborgs you pass alive in its lane climb onto its roof
    (up to three): each makes it fire faster, and each pays a bonus when it's destroyed. It gives up after
    about 25 s (in quick play, `--features=octodog,enforcer_truck`)
- **Bosses:** a framework for runner-style boss fights (GDD §10): the fight plays in the normal run on
  an arena track that keeps going for as long as it lasts, with the boss's health bar and phase
  markers on the HUD, weak points to stomp and weapon chip damage, a checkpoint for the final fight,
  no time limit and no escalation, stars from par times, a payout, records and a leaderboard per
  boss, and pickups: armor, shield and grapple pickups on the floor ahead, placed where they're fair
  to take, from the standard armor rule (at the start of the final phase, and a while after the
  player's armor or shield breaks) or offered by the boss itself. A campaign boss fight runs at its
  zone's speed, like the zone's levels (quick play's at the base speed). The test boss (`--boss=test_boss`),
  a hovering core that blasts the lane it lights up red and drops dazed into the player's lane to be
  stomped, shows it all (it offers a shield in its second phase). The Floating Head, the Neon City's
  boss, is built on it: a giant ship whose stern is a propaganda face, roaring in overhead, a
  bombing run where a searchlight hunts the runner and bombs fall where it lingers (a red target
  circle, an alarm and a falling whistle), the reveal of its face, and the face-off: its eyes glow and
  whine, then laser beams sweep the lanes low (jump) or high (slide) or drag down the runner's lane
  (switch lanes), its mouth drops cyborgs onto the trucks ahead, and a laser baited into a marked tower
  topples it onto the ship to pin it. Pinned, its red weak points come out on its crown: stomp one, a
  third of its health. Each phase has its own way up: run up the fallen tower's slab like a ramp (a lane
  switch steps onto its low part anywhere along it), a wall jump off lit marks on the walls, then pads and
  a ceiling to drop from; the first time each comes, a hint says how. Miss it and it shakes free and the
  face-off goes on. A phase that begins while the runner's armor is down (and no shield) brings an
  armor pickup early.
  All the while it shouts its propaganda through its loudhailers (a distorted voice never meant to be
  understood, ducking under every warning) with slogans on its face screen. Beaten, its face glitches,
  the propaganda cuts out mid-shout and it crashes into the street ahead: the runner runs over its
  fallen face and through the wreck, on to the zone's outro (in the web demo, the "get the full game"
  screen). It runs at the City's 21 m/s and plays as it did at 18 m/s in seconds: its distances follow
  the pace. About 100 s for a runner who never misses (`--boss=city_boss`, or the campaign's
  `--level=city/boss`). The Sleep Taker, the Dead Zone's boss, plays after Dead Zone 2, at the Dead
  Zone's 24.2 m/s (its distances follow the pace too): a colossal nightmare of fused Bad Dreams with
  dozens of maws, looming over the darkened street. Weapons can't touch it. As the runner reaches a
  charred bridge, its belly's great maw opens with a shriek and the three lanes it will slash light up
  red: take the bridge's pad up onto the ceiling, where it can't reach, or leave those lanes. Its hands
  come in rounds spread along the street: with a whisper, purple mist pools where each hand will burst
  up, row after row, each row leaving one lane open one lane over from the last, so the runner weaves
  through a round with a lane switch at every row. Rounds grow from two rows to four across the fight,
  and every row also reaches in from a side wall, with mist on the wall warning the spot. Its street's
  side walls break into many gaps, and it has twice the holes it first had; a round only comes where a
  way through it exists (the planner proves it with the real lane-switch time). After a deep inhale it
  swallows the light, and the street goes very dark (half as bright as it first did, never pitch
  black) while every hazard keeps glowing. Only a fence generator's EMP hurts it: a generator comes into
  sight far ahead, its pink beacon showing through the nightmare; as the runner nears it the nightmare
  lunges in after them, and
  once arcs leap from the generator into it, a stomp on the generator (or the dash) tears a chunk of
  the nightmare away. Three EMPs, three phases, each hungrier; the last bursts it into hundreds of faint
  faces and figures rising into the dark, the music falls silent and a grey dawn breaks over the Dead
  Zone. About 80 s for a runner who never misses (`--boss=dead_zone_boss`, or the campaign's
  `--level=dead_zone/boss`). The House, the Marketplace's boss, plays after Marketplace 2, at the
  Marketplace's 22.6 m/s (its distances follow the pace too): a towering slot machine on treads rolling
  down the market street ahead of the runner. It pulls its lever and spins its three reels, and each
  symbol they stop on is an attack: cherries lob cherry bombs whose landing circles light up first, a
  lightning bolt rolls a pink fence across lanes (jump or slide it like any fence), a BAR slams heavy
  gold blocks into lanes; two or three of a kind make it bigger. Big glowing 7 buttons light up along the
  street: running over one locks a reel on 7, and with all three locked it hits the JACKPOT (sirens, a
  fountain of real credits) and sags low with its coin hopper burst open on top, glowing red: stomp it.
  A missed button only means it spins again. Weapons chip it a little. Each stomp is a phase, and its
  buttons get harder to reach: in phase 2 one stands on a wall, with wall fences pulsing along both
  walls (run along the wall over it while they're off); in phase 3 a billboard comes down from the sky
  over the street with an anti-grav pad, the machine squats under it, and the button hangs under it in
  the pad's lane, Barnacle Turrets further along. Beaten, its reels spin wildly and jam, TILT flashes
  over them, and it collapses into   the street in an explosion of coins while the citizens cheer. The revised fight opens with
  three attack-only spins per phase before its buttons appear, with shorter gaps and wider cherry
  and lightning coverage. Its three-/two-star pars are 86/108 s (`--boss=marketplace_boss`, or the campaign's
  `--level=marketplace/boss`). Hostile Takeover, the Corporate zone's boss, comes after Corporate 2
  (`--boss=corporate_boss` or `--level=corporate/boss`): the runner lands on the rear roof of the Chairman's armored
  maglev train and runs forward along it, jumping the gaps between its carriages, the track's sound
  barriers on either side and the city streaming past beyond them and far below; a military gunship
  paces the train overhead, and far ahead the Chairman watches from the locomotive's window. In phase 1
  (The Board) security cyborgs guard the roofs, a Tithe Collector skims a trail of credits and partial
  wall fences pulse along the barriers; the coupling over each gap glows red in one lane: land on it
  while jumping the gap and the carriages behind break away and tumble off the track. In phase 2 (The
  Contract) the gunship strafes the lanes after a red line and a rising whine, drops a Buzz Overdrive
  onto a flatcar ahead, which cuts its lane, and an armored carriage blocks the way: a runway of anti-grav
  pads flips the runner up onto the gunship's belly, which carries them over it, and its open drop bay,
  glowing red, is stomped with a jump from the belly. In phase 3 (The Merger) the locomotive comes back
  and the gunship docks onto it with huge clamps, and MERGER COMPLETE flashes on every screen with the
  Chairman's face; the war engine's attacks combine both phases (the guards and wall fences, the strafes,
  the drops), and after each drop it comes back down over a runway of pads: ride its belly and jump to
  come back up onto its three glowing docking clamps, one under each third of it, to tear them loose
  (clamps missed come around on the next pass). Weapons chip the gunship but never end a phase, nor save
  a clamp. Beaten, the gunship spins away and explodes, and the locomotive derails and ploughs through
  the lobby of a corporate tower, bringing down its giant logo sculpture. About 69 s for a runner who
  never misses.
  The Sewer Swarm, Gangland's boss, plays after Gangland 3 at Gangland's 21.8 m/s (`--boss=gangland_boss`
  plays it at quick play's 18 m/s): a mutant horde of screeches rising from the sewers. As the fight starts, manholes and wall
  vents rattle and burst open all along both sides of the street, screeches pour out, and the horde heaps
  up in the gutters, its clusters waiting at the roadside ahead. A cluster rears up and its chitter rises,
  and a red line runs down the runner's lane to it, following them from lane to lane; then it lands in
  their lane and charges down it as a red-hot mass. Hold a lane with a live fence or a hole ahead until it
  lands, then get out of the way as it charges (or jump the fence or the hole), and it runs straight into
  it: shocked or swallowed. Two clusters destroyed end the Rising. In Surrounded the clusters also strike
  from behind at the same time as a front surge, attacking two distinct lanes and leaving the other lanes
  safe: a wave rises behind the runner with its own red warning line, then crashes down and surges on.
  Shorter warnings retain the locked-lane dodge windows and time to choose a bait reactively.
  Visible wall crowds remain naturally colored, but contact hurts and repels the runner. Wall pressure
  continues into the Host phase, clearing only the local ramp, wall-run, jump and landing route.
  The rest of the clusters destroyed, the Host bursts out of a big sewer pipe
  across the street: a person fused with machines, buried in screeches. It flings balls of the swarm (a red
  circle where each lands), lunges down the runner's lane (bait it into a fence) and crouches beside a ramp
  with its implants glowing red on its back: up the ramp, a wall run and a wall jump bring the runner down
  on them. Six hits free the Host: the screeches scatter, the implants short out and the person slumps
  free. Clusters are tougher and arrive more frequently; wall climbs and the Host's flings leave less
  downtime, while every attack still warns first. Weapons thin a surging cluster too, the heavy missile
  most of all. Its crowds are hundreds of screeches
  drawn with a MultiMesh and a shader, their sizes in data for the phone test
  (`res://tools/showcase/swarm_stress.tscn`, a stress scene with a frame-time readout). The Golden Zone's
  final villain is still to be built.
- **Protection:** every level and boss fight starts with free armor: it blocks an enemy attack or an
  electrical hazard (never a crash or a fall) and comes back 30 s after it breaks; the HUD shows its hits
  and a ring filling while it comes back. Armor pickups in boss fights bring it back at once.
- **Economy:** credits in four denominations, level score and stars, and a shop. Items are six permanent
  lines (weapon, claws, juggernaut dash, magnet, slow time, and armor upgrades: one more hit or a shorter
  wait, tier by tier) and two breakables (shield, grapple hook). Dash tiers cost 1,800 / 800 / 1,000 /
  1,200 credits and recharge in 8 / 6 / 4 / 3 seconds, respectively. After a death you're offered a revive
  (an item, or a rewarded ad on mobile). Net worth has its own leaderboard.
- **Campaign density:** more enemies and obstacles, with measured danger gains of about 17-18% in
  early levels, 26-27% in the middle zones and 32-38% in late levels across 3, 5 and 6 lanes. Additional
  rows create pressure when there is no room to fill another lane; a reachable route and attack
  warnings remain, and level durations are unchanged.
- **Modes:** the campaign, endless mode, and harder difficulty tiers after the last level.
- **Look and sound:**
  - Razor Echo, the runner: a dark-blue trench coat with soft copper conduits and a skirt that swings,
    a gold cybernetic arm and a copper ocular implant
  - the cyborgs: ragged, strung-out gangsters whose whole head is a beat-up CRT television, its screen
    their cold white LED face (calm, aiming, a shocked "O", ERR when defeated), with a backpack cabled
    into the head and a scavenged arm cannon; hosts glitch purple and wear purple veins. Each zone has
    its own version of the same unit: Gangland's caged Broadcast Brute with a pipe gun, the
    Marketplace's gilded Casino Mob Enforcer with a drum-fed gun, Corporate's Wide-Aspect VR Runner, the
    Dead Zone's burned-out TV head, and the Golden Zone's ceremonial enforcer wearing the cult's emblem
  - the City, Gangland and Marketplace zone looks, with the cult's feed on screens and its emblem hidden
    in ads in all three
  - neon UI screens and HUD
  - supplied music for all six zones and Boss 1, generated defaults for menus/cutscenes/unmatched bosses
    (music dips when the runner dies), and 76 sound
    effects, among them the level-complete riff in each zone's key
  - first-encounter hints
- **Settings:** volumes, key rebinding, screen shake, reduced flashing, hints.
- **Platforms:** export presets for Windows, Android, iOS and the web demo, which exports lean (only the
  music it plays) and is checked from the inside and in a browser (see The web demo). Ads, purchases,
  leaderboards and store links go through one platform layer, which is a stub until the real plugins are
  chosen.

## Tuning while you play (F6)

F6 pauses the game and opens a panel with sections for movement, game rules, power-ups, the runner's animation,
pickups, speed effects (the camera's field-of-view kick and lane lean, speed lines, shake, hit-stop and the
sparks and debris on kills and blocked hits, and the fireball every explosion is: counts, lengths, brightness, overall size), performance (how long a frame may spend dressing the track; see
Smooth frames), the music's pause duck and death dip, level pacing, the campaign's
recency curve for pick weights (in a campaign level), the wider gaps and the cyborgs planted in charge paths (in a
level that asks for them: **Wider gaps**, **Charge paths**) and each enemy type in the level. Changes apply immediately;
pacing, pick weights, speed, jump and size
changes also reshape the level, so press **Restart level** to rebuild it. **Save** writes the values back to
their files in `data/`; **Reload files** undoes unsaved changes. Every other number is in `data/` too: enemy
tunings in `data/enemies/`, prices in
`data/shop/catalog.json`, patterns in `data/patterns/` (format: `data/patterns/README.md`), sound volumes in
`data/audio/sfx_library.tres`, music levels and tempos in `data/audio/music_library.tres`, and UI colours and
sizes in `data/ui/ui_style.tres`.

## Smooth frames (F7)

In a debug build, **F7** shows a graph of the last five seconds of frames (`--frame-graph` shows it from the
start): each bar is one frame, as tall as its time, its lower part the game's own work and the rest the
renderer and the wait for the screen; the two lines are 60 and 30 fps. A spike (a frame well over the others)
is drawn in red and listed under the graph with how long ago it was and what happened in it (a chunk of track
built, an enemy spawned, shaders compiled, ...). The frames a kill's hit-stop holds the camera still are
marked in violet under the graph and listed too: a held camera looks like a hitch even when every frame is on
time. To report a lag spike, press F7 right after it and note (or screenshot) its line.

What to try:
- **Settings > Screen shake off** turns off every hit-stop, and the shake. To keep the shake and drop only the
  kills' freeze, set **F6 > Speed effects > Kill freeze time** to 0. If the spikes you saw go away, they were
  hit-stops (an open question for you: `docs/questions/perf1.md`). A kill's freeze no longer follows another
  within 0.3 s (**Freeze gap**, same section).
- **F6 > Performance > Chunk dress budget** (1 ms): how long a frame may spend dressing the track ahead; 0
  dresses each 40 m chunk in one frame, as before.
- A level's first frame now draws, too small to see, every look the level may need later (each enemy kind,
  the weapon's effects, every track piece), so their shaders compile there and not mid-run. The first run of
  a new build can still hitch once while the graphics driver fills its shader cache; the runs after it don't.

## Tools

```
tools/godot.sh play [options]   play (what ./play.sh runs)
tools/godot.sh edit             open the editor
tools/godot.sh test             all tests; exit code 0 = pass (--suite=name runs one; --jobs=N splits them
                                 across N Godot processes, balanced by each suite's last measured time --
                                 use it on a machine with CPUs to spare, since one process is otherwise all
                                 the suites get)
tools/godot.sh smoke [options]  40 s of the real game, headless; prints only problems. With `--level=zone/n`
                                 or `--boss=id` it presses PLAY at the level introduction (tools/smoke/smoke_play.gd)
                                 and plays on, and reports a level that never left it (`--smoke-report` adds
                                 what the run did; `--smoke-frames=N` shortens it)
tools/godot.sh sfx [--review]   regenerate the sound effects (assets/sfx/) from tools/asset_gen/
tools/godot.sh music [--review] regenerate default WAV music (leaves supplied MP3s unchanged)
tools/godot.sh citizens         regenerate the Marketplace citizens' sprite sheets (assets/sprites/citizens/)
tools/godot.sh web [--debug] [--serve]  export the web demo and check it (see The web demo)
tools/godot.sh import           force a resource import
```

`--review` also writes waveform and spectrogram images to `build/`. Every model, texture, sound and track is
generated by code (`tools/asset_gen/`, and procedural meshes and shaders under `scripts/`). The two fonts are
OFL-licensed; licenses are in `assets/LICENSES.md`.

The scenes in `tools/showcase/` show one part of the game up close for visual review (the runner in every pose
and power-up look, and a scripted run on any zone's skin; ramp launches and blocked wall entries; each enemy
family, the Barnacle Turret's looks and a ride past it, a floor cut in any zone's look, wall fences in any zone's look, the Buzz Overdrive's
model and an encounter with it, the Floating Head, the Sleep Taker (its lure and defeat, `--scenario=lure`, and its readability
in the dark, `--scenario=measure`), The House (`--scenario=spin|buttons|jackpot|wall|ceiling|defeat|fight`), Hostile Takeover (`--scenario=run|train|gunship|locomotive|coupling|contract|merger|defeat`), the Sewer Swarm (`--scenario=rising|surge|fence|hole|fight|model|behind|host|stomp|defeat|hostmodel`) and its crowds' stress test for the phone (`swarm_stress`: N clusters of C screeches with a frame-time and draw-call readout), the UI kit, every screen, a zone skin's fixed review track, the cult's feed,
the Golden Zone's statues, the Gilded Sentinels (each route past one, and its kick), the Enforcer Truck (its
chase and a volley, each bait, a too-wide gap, its model; `--scenario=chase|octodog|buzz|gap|model`), a wider gap
jumped and an Enforcer Truck wrecked in one (`wide_gap_review`, `--scenario=jump|enforcer`), zone doodads pushing the
runner and, with `--dash`, the dash smashing them (`doodad_review`), an Octodog's lunge and a
Buzz Overdrive's charge flattening a cyborg planted in its path (`charge_path_review`, `--scenario=octodog|buzz`), the
explosions (`fireball_showcase`: the shared fireball at each size and through each enemy's own death,
`--scenario=sizes|drone|truck|buzz|enforcer|generator|missile|bomb`, `--reduced` for Reduced flashing),
any campaign slot's cinematic and the cinematic toolkit's sampler); each script's header
lists its options. For example, a zone's arrival flyover rendered to frames on the web / low-end renderer:
`godot --path . --rendering-method gl_compatibility --fixed-fps 10 --write-movie build/cine/f.png --quit-after 100
res://tools/showcase/cinematic_review.tscn -- --slot=golden/intro --once`.

`tools/measure/big_attacks.gd` measures how the big attacks of different enemy types overlap over simulated runs of
the campaign, with big attacks taking turns (GDD §9, the `big_attacks_take_turns` switch in the game rules and the
F6 panel) and without, how much taking turns delays them, which enemies never got a big attack in, and how
many Buzz Overdrives revved or let the runner pass:
`godot --headless --fixed-fps 60 -s res://tools/measure/big_attacks.gd -- [--levels=gangland/3] [--lanes=3,5,6]
[--seeds=6] [--features=octodog]` (the whole campaign, both ways, takes about ten minutes on the levels' own seeds;
its header lists the options).

`tools/measure/level_pace.gd` measures each campaign level's pace and density: its run speed, events per minute
(obstacle rows, holes, enemies, big attacks, mechanics, zone doodads and the pushes a runner who ignores them
takes), its longest and mean empty stretches in seconds, and its credits; it can also build the levels with another version's data and dump every layout, to prove a change leaves
the old levels byte for byte as they were: `godot --headless -s res://tools/measure/level_pace.gd -- [--seeds=4]
[--old-data=DIR] [--dump=FILE] [--set=key:value]` (its header lists the options).

`tools/measure/stomp_routes.gd` measures how forgiving the Floating Head's ways onto its head are, at the City's
speed (21 m/s) in metres and in seconds: the latest lane switch onto the ramp that still stomps, the stretch of jump
points a single wall jump stomps from, and the ceiling from every lane (`godot --headless --fixed-fps 60 -s
res://tools/measure/stomp_routes.gd -- [--lanes=3,5,6] [--routes=ramp,wall,ceiling] [--speed=N] [--fine] [--e1c]`;
`--speed=18` measures at the reference speed, `--fine` finds the wall jump window's ends by bisection, `--e1c`
measures the numbers from before the owner's playtest fixes).

`tools/measure/level_shape.gd` measures each campaign level's shape: every feature's share of its picks, its
enemy, host and obstacle counts, what only the every-feature guarantee brings, and The Hush's quiet stretches
against its bursts, with the recency curve on and off:
`godot --headless -s res://tools/measure/level_shape.gd -- [--levels=dead_zone/2] [--curve=on,off]`.

`tools/measure/frame_times.gd` measures the game's frame times (task PERF1): it plays every campaign level and
boss fight through the game's own flow with a scripted runner (god mode, no falls, the zone's speed), each pass in
a fresh process, and prints per run the median, 95th and 99th percentile and worst frame, the frames over 8 and
16 ms, the load, the kills and hit-stops, and what the slow frames were doing; `--log` adds an event-log hash (two
builds that decide the same print the same hash; the JSON keeps the log's lines to compare), `--shaders` the
shaders first drawn after the load, and under xvfb it also counts draw calls and compiled pipelines:
`godot --headless --fixed-fps 60 -s
res://tools/measure/frame_times.gd -- [--levels=city/1] [--bosses=city_boss] [--passes=2] [--frames] [--log]`
(the whole campaign takes about fifteen minutes; its header lists the options).

`tools/measure/economy.gd` measures the campaign's economy (task R7): per level and zone, the credits
available, what a good run collects (a stand-in share, default 0.7), the payout for finishing, and what a
death or quit pays (GDD §4); then lays the shop's prices (`data/shop/catalog.json`) against the running
wallet of a player who finishes every level once, in order, with nothing bought along the way: the first
level each price is in reach of, and how many of that level's finish payouts it costs:
`godot --headless -s res://tools/measure/economy.gd -- [--share=0.7] [--mobile=true] [--packs]` (its header
lists the options; `--packs` also checks the mobile credit packs' sizes against the curve).

`tools/measure/hostile_takeover.gd` plays Hostile Takeover through quick play at every lane count and speed
the test suite only samples: a runner who plays it by what it shows dies in phase 3 once the war engine has
docked, then wins the whole fight in quick play's retry; it prints each stomp's time, the strafes, drops,
rides, passes and the clamps torn in each, the guards retired at the phase change, the Tithe Collectors and
those the cap left out, whether the defeat played out, and whether every attempt played the same:
`godot --headless --fixed-fps 60 -s res://tools/measure/hostile_takeover.gd -- [--lanes=3,5,6] [--speeds=18,23.4]
[--attempts=2] [--die-in=3] [--misses=N] [--bay-misses=N] [--pass-misses=N] [--clamps-per-pass=N]` (about a
minute for every setup).

`tools/measure/sleep_taker_arena.gd` counts the Sleep Taker's arena over its three laps as the fight plans them
(refuges and all), at every lane count and speed: its rows of holes and lane-gaps, fences, refuges and side wall
gaps (and their rate a minute); `--first` counts it as first built, before the owner's October 8, 2026 changes
(twice the floor gaps, many wall gaps): `godot --headless -s res://tools/measure/sleep_taker_arena.gd --
[--lanes=3,5,6] [--speeds=18,24.2] [--first]` (a few seconds).

## The web demo

The web demo (GDD §2) is the "Web (demo)" export preset: the Neon City's three levels and the Floating Head,
then a "get the full game" screen with links to Steam, the App Store and Google Play (placeholder links in
`data/platform/store_links.json`). It has no endless mode, ads, purchases or leaderboards, and saves in the
browser.

1. **Export templates**, once per machine: the web templates of Godot 4.7.2, from the official release
   (`Godot_v4.7.2-stable_export_templates.tpz` on https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable;
   check it against the release's `SHA512-SUMS.txt`). The demo needs only its two web templates:
   `unzip -j Godot_v4.7.2-stable_export_templates.tpz templates/web_nothreads_debug.zip templates/web_nothreads_release.zip -d ~/.local/share/godot/export_templates/4.7.2.stable/`
   (with `XDG_DATA_HOME` set, Godot looks in `$XDG_DATA_HOME/godot/export_templates/` instead; on Windows it's
   `%APPDATA%\Godot\export_templates\4.7.2.stable\`, or the editor's Editor > Manage Export Templates).
2. **Export and check:** `tools/godot.sh web` exports the demo to `exports/web/` (git-ignored), then runs the
   exported pack headless from the title to the end screen (`tools/web/check_pack.gd`) and lists the files'
   sizes. `--debug` exports a debug build to `exports/web_debug/` instead, where the command-line options work
   (below). The export leaves out the music the demo never plays, worked out from the music library, so
   replacing a track needs no change to the preset: `tools/godot.sh web` updates its filter, and the tests
   fail until it's updated (`docs/ARCHITECTURE.md`, Platforms and build flavors). The editor's Project > Export
   works too.
3. **Serve it:** `tools/godot.sh web --serve` exports, checks and serves it at http://localhost:8060 (or any
   static web server over `exports/web/`, e.g. `python3 -m http.server 8060 --directory exports/web`). It's
   built without thread support, so it needs no special headers; upload the folder's files as they are (for
   itch.io, a zip with `index.html` at its top).
4. **In a browser:** `node tools/web/browser_check.js` drives both exports in Chromium through Playwright (Node
   and Playwright with its Chromium needed): loading, the title on the Compatibility renderer, the sound after
   the first key, the canvas at other window sizes, City 1's glow, saves that survive a reload, the shop, a phone
   (taps, a swipe, held upright), and the end screen's store links. Frames and the console go to
   `build/browser/`. Software WebGL (no GPU) draws a level at a frame every few seconds, so it takes a while.

On a debug build, the options go into the page's engine settings: in `exports/web_debug/index.html`, set
`"args":["--","--level=city/outro"]` in `GODOT_CONFIG` to open on the City's outro, one step from the end screen.

## Tests

The tests run in tiers, so a task's check takes a minute and the full sweep runs where its cost is
shared (`docs/PERFORMANCE_AUDIT.md` §3.2):

| Command | What runs | Time (6 CPUs, 3 jobs) |
|---|---|---|
| `tools/godot.sh test --gate` | the smoke run, the fast suites, and the suites covering the files changed on this branch | ~1 min |
| `tools/godot.sh test --tier=merge` | all but the slow level sweeps and boss-fight simulations, plus the suites for the changed files | ~5 min |
| `tools/godot.sh test --tier=full` (or plain `test --jobs=3`) | every suite | ~13 min |

`tests/suite_map.json` lists the slow and medium suites and maps changed paths to suites
(`scripts/bosses/the_house/*` → `test_the_house*`, `data/enemies/octodog.tres` → `test_octodog`, a
zone's skin folder → its skin suite); paths it doesn't list are matched by name, and a changed
core file (generator, track builder, damage rules, run world, player, boss framework, test helpers,
level/pattern/tuning/zone data) raises the tier to full on its own. `--plan` prints the suites
without running them; `--paths=a,b` plans for those files instead of the branch's changes. Add a
rule when you add an enemy, boss, screen or skin whose folder name doesn't match its suite.

`tools/godot.sh test` runs 78 suites with about 6,400,000 checks. Many suites independently build the
same level (often a campaign step's own default build) to run their own checks on it; `LayoutCache`
(`tests/helpers/layout_cache.gd`) shares one real build of each across the whole run instead of
repeating it (`--no-layout-cache` turns that off; `tests/suites/test_layout_cache.gd` checks it never
changes a result). `--jobs=N` splits the suites across N Godot processes on a machine with CPUs to
spare (see Tools, above). Covered:
- **Generator fairness:** hundreds of levels over 3/5/6 lanes, difficulties and seeds, and every campaign level
  (each with every feature it lists, on its own seed and on others), at the base speed and at the zones' speeds
  (21 to 25 m/s, with the fill pass that makes campaign levels busier), each reaction window in seconds. Under
  every ceiling the floor may be dangerous, so each one's pads, landing zone and a floor route that never takes
  the pad are checked, and some of those routes are run on real physics; ceilings over fewer lanes too, at every
  width, with their pads under them, their landing zone over their lanes, and one-lane ceilings short. Also the
  recency curve's pick weights, and levels paced in quiet stretches and bursts (The Hush).
- **Zone doodads:** scenery standing in lanes that pushes you into the next lane and never hurts: placed only
  where every lane around it is clear (hundreds of levels at 3, 5 and 6 lanes, and every campaign level), a
  level without them built byte for byte as before, and the push on real physics (both ways, into the edge
  lanes, jumping or sliding into one, a corner caught mid-switch, a blocked side entry, landing on top, a
  ceiling rider passing over, shots passing through), with campaign doodads run into at their level's speed
  and always onto safe floor, and drones and hover trucks holding fire while one is in reach. The dash smashes
  one: head-on and from the side, with no push and no damage, the lane kept, a dash that ends short pushing as
  usual; its pieces in its look's own colours, the crunch and a light shake; it stays smashed for the attempt
  and a retry rebuilds it; campaign doodads dashed through at their level's speed, and whatever a doodad hid
  coming late enough after it, at the dash's speed, to react and move.
- **Floor cuts:** cuts planned only where they're fair (one at a time, never through a ramp, a pad or a
  ceiling's landing zone, the other lanes whole, room to leave the lane after the warning; hundreds of
  levels at 3, 5 and 6 lanes), a level without them built byte for byte as before, and on real physics:
  the floor gone exactly behind the cutter, a runner in the lane falling as into any gap, leaving in time
  from every lane, wall runners and ceiling riders untouched, the floor holding a second after a block, a
  kill stopping the cut, the same at 30 and 60 frames a second, cuts added during a boss fight, and every
  zone's look. The Buzz Overdrive's encounter the same way at every zone's speed, and the shots each weapon
  tier needs to stop it in time.
- **Wall fences:** placed only where they're fair (never where a ramp launches you along their wall, never
  beside a sign, a window cyborg or a wall vent, the outer lane beside them clear to drop into, no floor cut
  or big attack meanwhile; every campaign level that has them and quick play, at 3, 5 and 6 lanes, at every
  zone's speed), gentle introductions in Marketplace 2 and Corporate 1, a level built exactly as without them
  but for its wall fences, and on real physics: a wall runner hit while one is on and safe while it's off, a
  floor runner beside one never touched, partial ones passed high or low, the warning first and a runner who
  jumps off when it starts never hit, armor, the shield and the dash through and claws not, an EMP switching
  them off, and every zone's look.
- **Movement:** scenarios on real physics, among them a ramp's boost against a speed pad's, a ramp's wall run
  and its credits against the generator's prediction, the bump of a blocked wall entry, and moves on a
  ceiling over fewer lanes (blocked at its edges, a pad holding you to its lane, the camera kept under the
  ceiling through a drop).
- **Enemies:** each type's attacks, dodges, kills and generation rules, and big attacks of different types
  taking turns (the director, each enemy, and simulated runs of campaign levels).
- **Damage:** the shared damage rules.
- **Power-ups:** each one's behaviour.
- **Economy and saves:** the economy and save files.
- **Game flow:** the campaign (its zones, steps and level-by-level schedule, the features' ages for the
  recency curve and each kind's share of the picks through every level, The Hush and its darker lighting on
  every skin) and app flow.
- **Bosses:** the boss framework with the test boss: phases, the checkpoint, no escalation, the arena,
  the damage rules on a boss, and the flow around a fight; the Floating Head's fight so far at 3, 5 and 6
  lanes: its build and hitboxes, bombs that fall only after their warning, a runner who keeps moving
  always escaping them, the face-off's lasers (each warned, and escaped without god mode by a runner who
  reads them), its cyborg drop, a baited or fallback tower pinning it, each phase's stomp window taken
  without god mode (the ramp, a wall jump, the ceiling), missed windows repeating without escalation,
  the whole fight from its entrance to the last stomp, and every attempt playing out the same way; each
  way up taken the forgiving way (the ramp boarded from its side late, one wall jump off the wall marks
  from either wall, the ceiling ridden straight ahead from any lane) and armor for a runner who brings
  none, through the campaign's boss step with a death and a retry at 3, 5 and 6 lanes; its
  defeat (the propaganda cut, the crash, room for a runner in every lane of its wreck, Reduced
  flashing), and the whole fight through the campaign at 3, 5 and 6 lanes with no god mode, from City 3
  to the outro (and the web demo's end screen), its propaganda never masking a warning, and a death
  restarting the fight. Hostile Takeover, at 3, 5 and 6 lanes and at 18 and 23.4 m/s: every
  gap between carriages jumped from every lane with the real jump, the couplings' stomp box (a jump lands
  on it from its lane or the lane beside it, running off the edge never does), the Board's guards, Tithe
  Collectors (capped a phase) and wall fences always leaving a way through, phase 2's dropped Buzz
  Overdrive keeping a level's rules for its cut and its own rev and block-then-hold, the strafes striking
  only their warned lanes once warned, the armored carriage passed only from the runway of pads on the
  gunship's belly, phase 3's docking and MERGER COMPLETE (steady with Reduced flashing), its passes under
  the war engine's belly with each docking clamp in reach from a lane under it and time to change lanes
  between them, its defeat played out (the gunship exploding, the locomotive in the lobby), a runner who
  reads it winning the whole fight without god mode (also after missing couplings, a drop bay, a pass or a
  clamp, in quick play after a death and the retry, and through the campaign from Corporate 2 to the outro
  at every lane count), weapons within their cap, never ending a phase nor saving a clamp, the armor rule,
  the same fight on every attempt, and nothing made while the city streams past or from the docking on.
  The Sewer Swarm at 3, 5 and 6 lanes and at 18 and 21.8 m/s: every bait spot (a live fence or a hole) in
  reach before the surge locks and a way out of every lane, every surge warned by its red line and chitter
  before it can hit, a dodged surge always running into its fence or hole, a hit only through the
  cluster's hitbox, weapons thinning a surging cluster (the heavy missile's swarm bonus) and staying within
  their cap, no end and no escalation without a bait, the armor rule, the same fight at any crowd size and
  on every attempt, its crowds all made before the fight; every strike from behind warned by its wave,
  chitter and line and escapable from every lane, baited into fences and holes ahead, one wall always free
  while the swarm climbs; the Host's implants reached by a ramp and a wall jump, its lunge baited into a
  fence, its flings warned; and a runner who reads it winning each phase and the whole fight without god
  mode, also after a death and the retry, and through the campaign (Gangland 3, a death, the retry, the
  win, the stars and the outro).
- **Cinematics:** the toolkit's camera and actor paths (smooth, eased and cut moves, cameras riding with an
  actor), a timeline's checks, a cinematic played to its end with every event in order, skipping (the pause
  action and the Skip button), Reduced flashing, holding while the game is in the background, a cinematic
  described in data, every zone's arrival flyover and the City's boss intro at 3, 5 and 6 lanes (the zone's
  skin from its data, a camera that never flies into a ceiling or out of the street, ending in the run
  camera's view), and the App's flow through a built slot, the web demo's too.
- **Screens:** every screen at desktop and touch sizes.
- **The web demo:** its export preset, and a filter that leaves out only what the demo never loads, worked out
  from the data (and following a replaced track); everything the demo's scenes, scripts and data reference kept
  and loading; the demo walked from the title through the City's three levels and the Floating Head to the
  "get the full game" screen; no ads, purchases or leaderboards on any screen; the store links from data
  through the platform layer.
- **The runner:** Razor Echo's poses on every surface, the coat's panels (never through the legs or the
  ground), the budgets, the power-up looks, and its copper glow kept clear of every hazard colour.
- **The cyborgs' look:** in every zone's look, hitboxes pinned to their sizes and no look bigger than the
  base, the budgets, every weapon ending in the same red charge-up, the colour rules (only the cold white
  face, the red charge-up and a host's purple glow), faces that still differ a few pixels across (the VR
  visor's too), and ERR before a defeated cyborg's screen goes dark.
- **Zone skins:** all six skins, including a check that none adds collision, and the build budget; for
  Gangland, the Marketplace, Corporate, the Dead Zone and the Golden Zone the colour rule (only hazards glow
  in hazard colours) and ceilings a runner can read upside down, for the Marketplace, Corporate, the Dead
  Zone and the Golden Zone gaps that read as holes and a clear play space and calm walls, the Marketplace's
  shop windows, Corporate's brand colour (clear of the hazards and the UI's accents), its carriages lined up
  across chunk cuts, every kind of ceiling at one to six lanes and a boss arena's clear sky, the Dead Zone's
  near-black palette (ash-grey haze behind the Bad Dream's silhouette, embers dim and far above the play
  field, smoke only from tall ruins) and its ceilings at every width and position, the Golden Zone's gold
  (never glowing, never sign yellow or gap orange), its statues far above the wall-run band, the
  statue kit and the Gilded Sentinels' niches set into its walls, and for all six where the cult's emblem hides (or, in the Golden
  Zone, is shown openly) and where its feed plays, never in the wall-run band (the feed's shared material
  has a suite of its own). Every skin builds its ceilings from the lanes they cover, with the orange end
  band across them and nothing below the underside past the far end, where the camera passes as you drop.
- **Sounds and music:** every sound and track loads, generated defaults loop seamlessly, supplied songs
  loop in full and match all 15 levels and Boss 1, unmatched scenes retain defaults, the death dip
  combines with the pause duck, and the original zone completion riffs remain available.
- **Frame times:** City 3, Marketplace 2 and Golden 2 played as the game plays them, each pass in a fresh
  process, their 99th percentile and worst frame held to budgets in `data/tuning/performance.tres` (scaled by
  how busy the machine is, like the skins' chunk budgets); and what keeps frames smooth without changing the
  game: a chunk's look spread over frames (the same run, frame for frame), enemy types readied with the level,
  hit-stops that never chain, the shader warm-up's samples, and the frame-time graph.
- **Boot:** the real game scene.

Headless runs skip sounds, because the dummy audio driver never finishes a playback.

## Layout

```
play.sh, play.cmd       play the current version
tools/                  godot.sh (play/edit/test/smoke/sfx/music/web), asset generators, showcase scenes, measurements,
                        the web demo's export tools and browser check (web/)
scenes/main.tscn        the main scene: world, screens and overlays
scenes/bosses/          boss fight scenes (the test boss and the Floating Head so far)
scenes/cinematics/      cinematic scenes (the placeholder arrival flyover so far)
scripts/app/            App (state and flow), Profile, SaveService, Settings, BuildFlavor
scripts/run/            a run: LevelRun, RunWorld, camera, projectiles, credits, score, effects, hints
scripts/player/         the Player controller and its avatar
scripts/characters/     the procedural humanoid rig
scripts/enemies/        one script (plus tuning and generator rules) per enemy type, EnemyDirector
scripts/powerups/       the permanent power-ups
scripts/world/          level layout, generator, track builder, hazards; zone skins and the mesh kit
scripts/campaign/       campaign, zones, bosses (BossDef, BossPhase) and cinematic slots (CinematicDef, Cinematic)
scripts/cinematics/     the cinematic toolkit (CinematicSequencer, CineTimeline, CineStage, ...) and the flyover
scripts/bosses/         the boss framework (BossEncounter, BossPart, BossArena, BossProps), the test boss,
                        and one folder per boss (floating_head/, sleep_taker/, the_house/, hostile_takeover/,
                        sewer_swarm/)
scripts/economy/        the shop catalog
scripts/ui/             theme, icons, widgets, screens, HUD, debug tools
scripts/audio/          sound library, music player, hazard warning sounds
scripts/platform/       the platform services layer and its stub
scripts/core/           tunable resources and DamageRules (the single damage/interaction rule set)
scripts/input/          TouchInput (swipes/taps → named input actions)
data/                   every tunable number, level, zone, pattern, skin, catalog and library
assets/                 supplied music, generated sounds/default music, fonts, icon (licenses: assets/LICENSES.md)
tests/                  headless tests
```

Gameplay and visuals are separate: the generator and gameplay code only know abstract pieces (floor segments,
gaps, fences, walls, ceilings), and each zone's skin decorates them without touching collision.
