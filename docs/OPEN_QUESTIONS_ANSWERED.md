# Open Questions: answered

Items that are answered, approved, superseded, or notes that ask nothing. Kept for the item numbers that code,
tests and the GDD cite; the GDD is the record of each decision. Sorted out of `docs/OPEN_QUESTIONS.md` on October 14, 2026.

Item numbers are permanent: code comments, tests and the GDD cite them ("`docs/OPEN_QUESTIONS.md` item 628", "FB 73").
An item lives in exactly one of three files, under its original heading and number:

- `docs/OPEN_QUESTIONS.md`: the few questions that need the owner (work waits on them, or the placeholder gets
  costlier to change later).
- `docs/OPEN_QUESTIONS_DEFERRED.md`: still technically open, but the placeholder works and nothing waits on it
  (tuning, names, looks, feel). **The placeholder stands as built** until the owner reopens it while playtesting.
- `docs/OPEN_QUESTIONS_ANSWERED.md`: answered, approved, superseded, or notes that ask nothing.

To find a cited item, search the three files: `grep -n "^628\. " docs/OPEN_QUESTIONS*.md` (build phase 2 items have
no prefix; "GB n" and "FB n" are in their own sections). **Don't read these files whole.**

## Raised during build

### Owner's placeholder review (September 26, 2026)
The owner reviewed every placeholder below. **GB** means "From the R1 core-movement grey box", **FB** "From the full build", and **P2** "From build phase 2"; numbers are the items' own. Unless listed under changes, playtesting or later rounds, **an item is approved as is**: its placeholder now counts as decided (GDD §12), and its `DESIGN-TBD` marker can come off.

**Changes (recorded in the GDD):**
- GB 5: a blocked wall entry adds a small sideways bump to the clank (§3).
- GB 6: **no change**. What looks like a hit is a hit on every surface, so a low wall runner can hit a fence in the outer lane (§3). Buzz Overdrive's "wall runners are safe" rule stands; its hitboxes stay inside its lane.
- GB 10: ramps add a speed boost that fades like a speed pad's (§3).
- FB 6: endless mode runs until death, climbs in difficulty, cycles through the unlocked zones' scenery, and pays 20% plus a lump sum every 2 minutes survived (§6).
- FB 14: quitting from the pause menu keeps 20%, like a death (§4).
- FB 27: big attacks of different enemy types take turns (§9). The owner may revert this after playtesting, since early playtests felt not very challenging.
- FB 53: the music dips on death, and the level-complete riff plays in each zone's key (§11).
- FB 71: hosts are immune to all weapon damage (§9.7). *(Superseded October 8, 2026: weapons hit hosts, GDD §9.7; items 628–633.)*
- FB 85: no screeches in the Neon City (§9.5).
- P2 4: Buzz Overdrive also appears in the Golden Zone (§9.9; a recording error, corrected).
- P2 7: Dead Zone 2 has fewer enemies but more hosts and Bad Dream chases, darker lighting, and long silent stretches broken by sudden threats (§5).
- P2 10: the placeholder level names are approved (§5).
- FB 46: every zone with a still floor gets the dust, scraps and speed-streak motion cues.
- P2 6: the Corporate skin also shows military ships and props.
- P2 13: beyond the "each feature at least once" guarantee, a level's newest things get the most picks.
- P2 18: a narrow Gangland ceiling is a slab broken off a building.
- P2 20: the Gangland corporate logo matches the Corporate zone's brand once it exists.

**Tune after playtesting** (placeholders stay):
- movement and pacing: GB 2, GB 3, GB 11, GB 12, GB 16 (5 PC lanes for now), FB 41
- economy: FB 10, FB 11, P2 16 (needs a balancing pass over 15 levels)
- audio mix: FB 52
- enemy numbers: FB 68, FB 75, FB 80, FB 82, FB 87, FB 96–98, and the EMP radius in FB 73
- difficulty curve: P2 8

**Later design rounds:**
- cinematics: FB 3, P2 11
- audio: GB 15, FB 54
- power-ups and balance: P2 12
- mobile: FB 15
- title and brand: FB 109
- other: FB 111 (achievements)

**R6 (October 2, 2026): markers taken off the items approved as is.** The `DESIGN-TBD` markers of these items
are now plain doc comments naming the item; every other item keeps its marker (changes until their value is in place,
tune after playtesting, later design rounds, and every item from build phase 2).

| Item | What | Files |
|---|---|---|
| GB 8 | Air-slide fast fall is a kept feel addition | 1 |
| FB 5 | The Normal/Hard/Insane tiers (FB 4, the difficulty curve, keeps its marker: reopened by the playtests and G1) | 1 |
| FB 7 | First-encounter hints, togglable in Settings | 3 |
| FB 8 | Credit denominations: look, colours, sound | 3 |
| FB 9 | Credit placement (trails, risky-spot big credits) | 1 |
| FB 12 | Purchases spend bought credits first | 1 |
| FB 13 | One breakable charge per attempt | 1 |
| FB 16 | Revives: one per attempt, 2 s invulnerability | 1 |
| FB 17 | Juggernaut dash: duration/cooldown/speed, passes every hazard but falls | 3 |
| FB 18 | Grapple hook pull velocity | 1 |
| FB 20 | Ramp score multiplier (x2) | 1 |
| FB 21, FB 49 | Speed pads: green "safe boost" family, +6 m/s decaying | 11 |
| FB 23 | Magnet radius per tier | 2 |
| FB 24 | Claws extend wall runs 1.5x | 1 |
| FB 25 | Slow time: 0.5x for 3 s, 20 s cooldown | 2 |
| FB 26, FB 29 | Weapon tiers 2–3, fire rate, splash radius, swarm bonus on splash | 2 |
| FB 34 | Enemy health bars read in the red family | 1 |
| FB 36, FB 37 | Invulnerability flash and death flash look | 1 |
| FB 40 | Yellow/black hazard sign frame, every zone | 1 |
| FB 42 | Ships fly toward the player, like the trucks | 1 |
| FB 58 | HUD shows a progress bar (markers still undecided) | 2 |
| FB 60 | Level-complete stats screen | 1 |
| FB 61 | Revive offer waits for a choice, no countdown | 1 |
| FB 70 | Cyborgs/window cyborgs hold fire at a ceiling or own-wall rider | 1 |
| FB 73 | Fence generator: claws/contact don't destroy it, body solid | 1 |
| FB 76, FB 77 | Octodog diagonal aim and between-charges pass clearance | 1 |
| FB 79 | Octodog doghouse (first 3, burst at 55 m) | 2 |
| FB 83, FB 84 | Screech spines are a body collision; stops at a hole's edge | 1 |
| FB 86, FB 88 | Drone has no contact hitbox; "on screen" definition | 1 |
| FB 89, FB 90 | Drone wave pairing/gap and pad schedule | 2 |
| FB 91, FB 92, FB 93 | Hover truck lane/pacing, warnings, kill rules | 1 |
| FB 94 | Trucks per level (1 early to 3 late, always one) | 1 |
| FB 99, FB 100, FB 101, FB 103 | Bad Dream: wall slash, escape fairness, body touch, EMP dissolve | 2 |
| FB 104, FB 105 | Bad Dream survival bonus and chase pad schedule | 1 |

### From the R1 core-movement grey box (September 25, 2026)
Each item has a placeholder in code marked `DESIGN-TBD` and, where it's a number, a value in `data/tuning/movement.tres` or `data/levels/`. Answer them after playtesting the grey box.
1. **PC jump key:** the placeholder is Up arrow + Space. **Dash key:** the placeholder is Shift (the dash itself isn't built yet).
4. **Leaving a wall:** jump = wall jump (per GDD). The placeholder also treats **pressing toward the lanes** as a wall jump. The slide action does nothing on a wall. Keep these?
5. **Sign blocks wall entry:** the move is ignored and the player stays in the outer lane, with a metallic "clank" sound. Should there be more feedback (a bump animation)?
6. **Low wall run vs floor fences:** on a wall, the body sticks out sideways into the outer lane. If the player is low on the wall, they hit a fence in the outer lane. This isn't specified; it's just what the collision does. Intended?
7. **Ceiling rules:** moving past the outer ceiling lane does nothing (no ceiling → wall). The ceiling has the same lane count and gravity as the floor. Jump and slide also work on the ceiling, mirrored (jump drops you away from the hull, then gravity pulls you back). Correct?
8. **Air slide:** pressing slide in mid-air drops fast and slides on landing. It's not in the GDD and can be switched off with `air_slide_fast_fall`. Keep it?
9. ~~**Hull end landing:**~~ Answered: keep a safe landing zone (GDD §3, September 26, 2026).
10. **Ramps:** (the boost was changed by the owner's review and built by R1: see "From build phase 2" item 80.) The placeholder launches onto the wall at 4.0 m, with no speed boost (`ramp_speed_boost = 0`). The ramp sits in the outer lane and launches the player when they run over it.
13. ~~**Mobile orientation:** landscape or portrait?~~ Answered: landscape (GDD §2).
14. **Coyote time and jump buffering** (0.08 s and 0.14 s grace windows) are feel aids, not design. Tell me if you want them removed.

### From the full build (September 26, 2026)
Placeholders the build needed to be playable end to end. Each is marked `DESIGN-TBD` in code or data;
numbers live in `data/` (mostly `data/tuning/*.tres`, `data/shop/catalog.json`, `data/levels/*.tres`).

**Campaign and structure**
1. **Introduction schedule** (superseded September 26, 2026 by the owner's level-by-level schedule in GDD §5: cyborgs move to City 1, pulsing fences and window cyborgs to City 3, and the Octodog stays in Gangland 2 with drones in Gangland 3) (one new thing per level): City 1 *Rooftop Rush*: gaps, fences, walls and
   signs. City 2 *Skyway*: ceilings (anti-grav pads) and pulsing fences. City 3 *Neon Crossfire*:
   cyborgs and a rare hover truck. Gangland 1 *Scrapyard Streets*: ramps, sewer screeches, fence
   generators. Gangland 2 *Dog Run*: Octodogs and speed pads. Gangland 3 *Rotor Wash*: heli drones
   and window cyborgs. Hosts and the Bad Dream are built but no level uses them yet (GDD: "late
   levels"; quick play `--features=cyborg,host,ceilings` shows them). Which level introduces them? Level
   names and lengths (100–140 s) are placeholders too.
2. (Answered: GDD §10's roster; the slots carry each boss's name and phases since B8.) **Boss slots:** Zone 1's boss is unnamed (the Floating Head is a candidate); the Sewer Swarm sits
   in Gangland because of the sewers. Which boss goes where?
4. **Difficulty curve** (the campaign is now 15 levels, GDD §5): 0.1 → 0.9 across the planned campaign (18 levels, counting 3 per undesigned
   zone), linear, plus a per-level bias; within a level +0.25 from start to end.
5. **Difficulty tiers** (unlocked after the last campaign step): Normal / Hard / Insane with +0.15 /
   +0.3 difficulty and ×1.1 / ×1.2 run speed.
6. **Endless mode:** one 20-minute random level in the furthest zone reached, difficulty 0.2 → 1.0;
   credits pay out like a death (20%); not in the web demo.
7. **Tutorial:** first-encounter hints (a line of text just before the first gap, fence, wall, pad,
   enemy, ...), once per profile, with the player's own keys; can be turned off in Settings
   (`data/hints/hints.json`).

**Economy**
8. **Credit denominations and look:** 1 (silver chip), 5 (azure ringed chip), 25 (violet diamond), 100
   (ice-white gem), shaped differently so colour isn't needed to tell them apart, and never in a
   hazard colour (gold would read like the yellow signs). The world and the UI share the colours
   (`data/ui/ui_style.tres`).
9. **Credit placement:** trails of 1s in clear stretches, a 5 at gap edges with an arc of 1s over the
   jump, a 5 above full fences / under gapped fences, a line along each ramp's wall run ending in a 25,
   a line along each ceiling with a 25 in the far lane.
12. **Spending order:** purchases spend bought credits first, so buying credits never lowers net worth.
13. **Breakables per run:** each attempt carries one charge of each owned, switched-on breakable (armor,
    shield, grapple); spares stay in stock. Revives are used from stock on the death screen.
14. **Quitting a level** from the pause menu pays nothing.

**Rules**
16. **Revives:** at most one per attempt (item or ad); 2 s of invulnerability afterwards; a player who
    fell is pulled back up out of the gap.
17. **Juggernaut dash:** passes through every hazard except falls, including signs and enemy fire, and
    smashes enemies (not the Bad Dream). Duration 0.6 s, cooldown 8 s, +8 m/s.
18. **Grapple hook:** yanks the player up out of the gap they're falling into.
19. **Weak points** (the hover truck's) are harmless unless stomped.
20. **Ramp score multiplier:** ×2 on credits collected during that wall run.
21. **Speed pads:** green chevrons (the ramps' "safe boost" colour), +6 m/s that decays.
22. **Enemy fire** is red in every zone; the player's shots are cyan, violet and white, so they never
    read alike.
23. **Magnet:** radius 1.6 / 2.6 / 3.6 m per tier, never more than 1.25 lane widths sideways.
24. **Claws:** wall runs last 1.5× longer.
25. **Slow time:** 0.5× for 3 s (real time), 20 s cooldown.
26. **Weapon tiers 2–3:** damage 1.4 and 2.0 (tier 1 = 1, tier 4 = 3); fire intervals 0.32 / 0.3 /
    0.55 / 0.65 s; heavy-missile splash 3.5 m at half damage, ×2 against swarms.
27. **Attacks of different enemy types don't take turns.** Each type spaces its own attacks (one cyborg
  burst at a time *(Superseded October 8, 2026: up to two cyborg-type bursts may be in the air at once, GDD §9.2; items 600–603.)*, one drone barrage at a time, Octodog charges only on clear stretches), and the Bad
  Dream will wait for Octodog charges and drone barrages (GDD §9.7). Other types don't coordinate. In
  Gangland 3, attacks from two types overlap for 0.3–2.5 s of a 142 s run (measured at 3/5/6 lanes),
  mostly a drone barrage during a hover truck's rev or cannon charge. Should all major attacks take
  turns? (The director already coordinates the Bad Dream this way; other types would only need to
  opt in.)

**Power-ups** (from the power-ups work)
28. **Missiles home** on their target (turn rate 7 rad/s) and leave the launcher angled 0.35 away from the
    surface. The GDD doesn't say missiles home.
29. **Swarm bonus on splash:** the heavy missile's bonus also applies to its splash on swarm enemies.
30. **No overkill:** auto-fire skips an enemy that shots already in flight will kill and moves on to
    the next nearest.
31. ~~**Fence generators** are auto-fire targets (destroying one sets off its EMP). Should they be?~~ Answered September 26, 2026: no. Auto-fire never targets generators and missile splash never damages them (GDD §9.1). Built in task B9: generators are immune to all weapon damage; a stomp or the dash still sets one off.
32. **Shots ignore level geometry** (hulls, walls), and the weapon fires from any surface.
33. **Slow time** slows the player too; pausing suspends it (resuming continues); dying or finishing
    ends it. Audio isn't slowed.
34. **Enemy health bars** appear after the first hit: red, draining to dark red, with a white segment
    for recent damage (yellow and orange stay hazard colours). The magnet's pull glows azure.

**Player model** (from the player-model work)
35. *(Superseded September 26, 2026: redo for Razor Echo, see `docs/art/BRIEF_RAZOR_ECHO.md`.)* How each power-up looks: claws on the gloves, armor plates, a shield bubble, a shoulder weapon that
    grows by tier (tier colours are made up), a magnet coil.
36. Invulnerability: a bright tint that flickers (held steady with Reduced flashing), not a blink.
37. Death: a red flash while the suit's glow powers down (the grey box turned red). Keep?
38. The stomp pose also plays during the air-slide fast fall.
39. *(Answered September 26, 2026: the player's glow is now soft copper, GDD §11.)* The player's glow is cyan, the same as the anti-grav pads. OK, or should the player have its own
    colour?

**Neon City look** (from the City skin work)
40. **Sign language for every zone:** a yellow/black striped frame around neon content (the frame is
   the hazard; the content can be anything).
42. **Ships** fly toward the player: bow over the near end, engines at the far end where the player
   drops; the far end also carries the gap-edge orange.
43. **Fences:** glowing edge bars (top for full fences, bottom for gapped); an off fence shows no field.
44. **City neon avoids hazard colours:** no red traffic lights (red plus bloom reads as fence pink);
   decorative neon is unframed and sits above 9 m. The grey box's faint 2 m / 4 m wall-run height lines
   are kept on the facades. Keep them?

**Gangland look** (from the Gangland skin work)
45. (Superseded by the Gangland update: see "From build phase 2" item 17.) **Ceiling:** a scavenger cargo barge (patched plates, a blunt bow with a bumper beam, cargo on deck,
  the orange end band, dim engines). GDD §3 leaves other zones' ceilings open. Keep it?
46. **Motion on a still street:** drifting ash, paper scraps and speed streaks give a sense of speed
  where nothing streams by (the City has its moving road). Keep them? Should other still zones get
  them too?
47. **Holes:** a dark pit showing the road's layers, with the orange edge glow on the front and back
  edges only (as in the City). Is that enough?
48. **Side streets** are barricaded flush with the wall up to about 7–8 m, so every wall can be run.
49. **Speed pads** are green arrow strips in every zone (the City's were invisible before).
50. **Worn dashed lane lines** on the street as a speed cue.
51. **Hints** now say "ceiling" rather than "the ship's hull", since the Gangland ceiling is a barge.

**Audio** (from the audio work)
53. **Music on death and level complete:** the zone track keeps playing under the death screen; the
  `level_complete` riff is in E (fits City, clashes with Gangland). Stop, duck, or play on?

**UI** (from the UI kit work)
55. **Palette:** an azure main accent and a violet second accent; red only for warnings and "can't
    afford". Pink, orange and yellow are never UI colours (they're hazard colours).
56. **Stars** are white with an azure glow rather than gold (yellow is the sign colour). OK?
57. **Fonts and sizes:** Orbitron (titles) and Exo 2 (text, and heavy for numbers: Orbitron's slashed
    zero read like a "no" sign in a score of 0); touch devices get 76 px controls
    and 1.2× text. Worth checking on a real phone (`data/ui/ui_style.tres`).
58. **HUD progress bar:** shown, with no markers yet; what markers should stand for is open. Endless runs
    show no progress.
59. **Key rebinding:** single keys only (no Ctrl+ combinations); Esc cancels a rebind, so Esc itself
    can't be bound.
60. **Level-complete stats:** time, distance, kills, stomps, ramps, longest wall run and hits blocked.
61. **Revive offer:** waits for a choice (no countdown). Its buttons ignore input for 0.5 s so a jump
  press from the run can't spend a revive.
62. **Quitting from the pause menu** asks first, since the run's credits are lost. Keep the question?
63. **Breakable stock** shows as x/max in the shop. The level select's difficulty tier is remembered for
  the session only, not saved.
64. **Shop order:** breakable items first. Esc in the between-runs shop carries on like the main button.
65. **Keys on touch devices:** the key-binding section is hidden, so a tablet with a keyboard can't
  rebind keys.
66. **Boss and cinematic slots** show their planning notes on screen ("PLANNED"). Useful for playtests;
  remove before release.

**Cyborgs and fence generators** (from the cyborg work)
67. **Cyborg shots to kill** (GDD §8 leaves it open): 3 laser tier 1 shots early in the campaign, 5 late.
69. **Cyborg movement:** walks toward the player at 1.4 m/s for up to 8 m and drops back at 8 m/s once
  passed. The panic variant (1 in 3) notices the player at 58 m, runs at 8.5 m/s for up to 45 m, then
  cowers. The GDD doesn't say what a fleeing cyborg does when it runs out of room.
70. **Fairness rules added (not in the GDD):** no cyborg bolt arrives within 12 m before or 8 m after a
  fence or gap; only one cyborg bursts at a time; cyborgs hold fire at a player on the ceiling, and
  window cyborgs at a player on their own wall; cyborgs stand at least 10 m from gaps, fences, ramps
  and pads. *(Superseded October 8, 2026: up to two cyborg-type bursts may be in the air at once, GDD §9.2; items 600–603.)*
71. **Hosts:** never panic; the kill bonus is 1,500. It's paid, and the Bad Dream released, on any
  kill, even a stray direct weapon hit (auto-fire never aims at hosts). *(Superseded October 8, 2026: weapons hit hosts, GDD §9.7; items 628–633.)*
72. **Window cyborgs:** a 0.8 m body band centred on the 2.2 m wall-entry height, reaching 0.55 m out
  from the wall. They can't be stomped.
74. **Scores and look:** cyborg and window cyborg 200, generator 150. LED faces are amber *(changed September 26, 2026: cold white, GDD §9.2)* so they read
  apart from the player's cyan visor.

**Octodog and Sewer Screech** (from their work)
76. **Octodog aim:** it locks on the player's lane when the wind-up starts; 40% of repeat charges come
  from the lane beside the player. The first charge aims at the player from wherever the dog stands,
  so on 5–6 lanes it can cut across several lanes.
77. **Between charges** it passes in another lane and is harmless until 3 m ahead (no attack from
  behind). After its last charge it sits and is left behind; if no clear moment comes within 40 m, it
  runs off ahead.
78. **Charge planning:** charges only happen on clear stretches (no fence, pad, ceiling or other enemy),
  and a dog is left out if fewer than 2 charges fit.
79. **Doghouse:** the player's first 3 Octodogs ever hide in a doghouse in their lane and burst out at
  55 m.
81. **Octodog contact:** is running into a standing Octodog also a "grab"? It's currently an attack, so
  armor blocks it.
83. **Screech spines:** landing on or running into them is a body collision, so armor doesn't block it
  (the shield does). With claws, even touching its swipe kills it.
84. **Screech and holes:** it stops at a hole's edge rather than dashing in.
85. **City screeches** come from wall vents only (a `screech_vents` level feature, rare). A manhole cover
  lands back over its hole, so no open hole looks like a gap.

**Heli drone and hover truck** (from their work)
86. **Drone contact:** it has no body hitbox, so touching, stomping or dashing into it does nothing.
88. **"Every drone on screen"** (for the anti-grav pad) means swooped in, and between 12 m behind and
  120 m ahead of the player.
89. **Drone waves:** a level's first wave is a single drone; a second drone joins only from mid-campaign;
  waves come at least 20 s apart; a level with drones always gets at least one.
90. **Drone pads:** the first comes 10 s after a wave appears plus some slack; each pad's ceiling lasts
  3 s. After the first wave the drone's pad schedule owns every pad: pattern ceilings give way, and
  floor pieces and enemies under a pad's ceiling are removed. Pads avoid a hover truck's lane.
91. **Hover truck lane and pacing:** it holds the outer lane on its side and never changes lanes. The
  pacing cycle (ahead, lurch back, rev, lurch forward alongside the player) and its timings are
  placeholders. Blocked by a player behind it, it leaves by speeding off ahead.
92. **Hover truck warnings:** a new "rev" sound and flashing spikes warn of the forward lurch. The
  cannon fires only while the truck paces ahead, and holds fire at a player on the ceiling or riding
  the roof. Window shooters (0 early, 2 late, 1 mid-campaign) fire with the cannon.
93. **Hover truck kill rules:** the weak point is on the lower cab roof, and riders drift toward it.
  Claws and the dash defeat it on contact with its live spikes (the shared rules). Its burst through
  the wall counts as an enemy attack, so armor blocks it.
94. **Trucks per level:** 1 early to 3 late, at least one guaranteed, one at a time. Its lane is kept
  clear while it's around, and a ramp is added for the wall route onto the roof when the level has
  ramps. City 3 has no ramps, so there only the lurch route and weapons reach the roof.
95. **Scores:** drone 300, hover truck 800.

**The Cyborg's Bad Dream** (from its work)
99. **Jumping doesn't dodge it:** the claws sweep 0–1.75 m, higher than a jump, so only leaving the lit
  lanes (another lane, a wall, a pad) escapes. On a wall it slashes the wall (up to 4.8 m) and the outer
  lane: a wall jump plus a lane switch escapes.
100. **Escape rule added (not in the GDD):** it never telegraphs when no escape is open (on 3 lanes a
  middle-lane slash covers the whole floor, so a wall without a sign must be free), or at a player
  falling into a hole or dropping from a ceiling.
101. **Touching its body** hurts like the slash (armor blocks it); in practice it never comes that close.
102. **A second host killed mid-chase** pays the host bonus but releases no second Bad Dream.
103. **EMP:** dissolves it wherever it is, in 0.7 s, with no survival bonus.
104. **Survival bonus:** 1,000, paid only if the player is alive when the chase ends.
105. **Pads during a chase:** at most 10 s apart (added ones 8–10 s after the last, with 3 s ceilings);
  hosts are at least 7 s apart after a chase could end, so a level keeps 1–2 hosts. After a level's
  first drone, the drone's pad schedule places every pad, and a host whose chase it doesn't cover is
  left out. Levels without ceilings get no hosts.
106. **Blocked attacks:** an Octodog kept from charging during a chase runs off ahead; a drone keeps
  following without firing.
107. **Look:** the GDD's purple leans violet (pink means "electric fence"); the throat and claws turn
  enemy-red only while it attacks; below the neck it's translucent vapour; the three lanes it will slash
  light up red. Hint: "The Bad Dream slashes the lanes it lights red. Get out of them: another lane, a
  wall or a pad."

**Platforms and presentation**
108. **Store links** in the web demo point at the stores' front pages until the game has store pages.
110. **Leaderboards view:** scores are already submitted (per level and difficulty tier, endless per lane
  count and tier, net worth), but no screen opens the platform's leaderboard UI yet. The plan is a button on
  the title and results screens once the platform plugins are chosen (the stub has no leaderboards).

### From build phase 2 (September 26, 2026)
Questions the phase 2 build tasks raised (`docs/TASK_PLAN.md`), folded in from `docs/questions/<task-id>.md`
as each task merged. Each has a placeholder marked `DESIGN-TBD` in code or data.

**Cult symbol** (from D7, cult symbol options)
1. ~~**Which emblem and colour for the cult?** (GDD §5, "The cult")~~ **Answered: B, the Convergent Triad**
   (owner, September 26, 2026; recorded in GDD §5 and set in `data/world/cult_emblem_choice.tres`). The four
   options, drawn in code (`CultEmblem`) and compared on `tools/showcase/cult_emblem_sheet.tscn`:
   - **A, Broadcast Halo:** three broken rings around a core, echoing the Resonator's halos; glows a cool white,
     brushed platinum when unlit, a gold medallion with a red core stone in the Golden Zone.
   - **B, Convergent Triad:** three notched arrows converging on a point ("every path leads to him"); glows a
     warm white, brushed bronze when unlit.
   - **C, Aperture Mark:** seven aperture blades around a lens ring ("always watching"); glows a deep indigo,
     gunmetal when unlit.
   - **D, Signal Spire:** a slim spire with three one-sided bars, like the Resonator plus a signal-strength
     glyph; glows plum, dark metal when unlit.

   Working the chosen mark into every zone skin (hidden in logos and ads, open in the Golden Zone) follows in
   the skin tasks. Keep it off tiny sizes where its three-fold silhouette could read like the radiation trefoil.

**Campaign restructure** (from B1: six zones, 15 levels)
4. **The Buzz Overdrive's "only two zones"** (GDD §9.9). Placeholder: Corporate and the Dead Zone; not the
   Golden Zone.
7. (Decided in the owner's review and built by R5: see items 152–156.) **Dead Zone 2, "a quiet, eerie remix"** (GDD §5). Placeholder: Dead Zone 1's features, a little harder,
   nothing new. What makes it a remix in play: fewer enemies, more hosts, something else?
13. **Earlier features in later levels** (GDD §5: "anything introduced earlier keeps appearing later"). As
    levels list more features, each gets fewer pattern picks, and some enemies' rules drop what doesn't fit,
    so on the shipped seeds some levels went without one (no Octodog in Gangland 3 at 3 or 6 lanes, nor in the
    Dead Zone or Golden Zone at 5 lanes; no host in Dead Zone 2 at 5 or 6 lanes, nor in Golden 1; no vent
    screech in Corporate 1). The GDD rule is decided, so the build is adding a guarantee that every level
    places each of its features at least once (follow-up task after B1). Still open: how often each earlier
    feature should appear beyond that. (Built: every campaign level now places each of its features at least once, on
    any seed and lane count; see items 25–26.)
15. (No longer comes up: every zone has its own track since D8, item 109.) **Music for the new zones until their tracks exist.** Zones name their track after their id; until the
    music task adds them the game skips them quietly and the menu music keeps playing. Fine as a stopgap?

**Gangland update** (from D1; numbers are F6-tunable exports on `GanglandSkin`)
24. **Motion on the still street** ("From the full build" item 46): dust-coloured flecks, paper scraps and pale
    speed streaks, as before.

**Boss framework** (from B8; defaults in `scripts/campaign/boss_def.gd`)
31. **Time and score after a checkpoint:** a win after resuming counts the fight time and score from the attempt
    that reached the checkpoint plus this one's, so par times, the time bonus and the leaderboard compare whole
    fights.
39. **The first boss hint:** "A boss! Only its glowing red weak points and your weapons can hurt it." Sleep Taker,
    which weapons can't hurt, will need its own hint.
40. **Boss HUD and results** (§A.5): a bar top centre in enemy-health red with the boss's name, its phase and a marker
    at each phase's end, grey while it can't be hurt; a "Checkpoint!" hint; results with time, phase reached, weak
    points hit, kills, hits blocked, the time bonus and the par times.
41. **Boss leaderboards** (GDD §10): one board per boss and difficulty tier (`boss/<boss id>/<tier>`); none in the web
    demo.

**Marketplace skin** (from D2; numbers and colours are exports on `MarketplaceSkin`)
47. **Decorative signs:** neon, ad boards and casino bulbs never below 8 m, and the wall-run band above the shop
    windows stays calm; hazard signs are painted shop signs inside the yellow/black frame.
48. **Fence mounts:** steel poles with glowing insulator caps in stacked wooden market crates at the lane edges.
49. **Motion on the still floor** (approved for every still-floor zone in the review): dust, paper scraps and speed
    streaks, the stalls' frame poles and scalloped hems, pennants and festoon lights across the street every ~34 m,
    and cables higher still.
51. **Wall-run height marks on light walls** (FB 44): the 2 m and 4 m lines as dark, unlit paint.
55. **How dusty and worn:** sand on roofs, awnings and ledges, sun-bleached patches, grime at the foot of faces and
    under windows, weathering blotches and a light haze; one `wear` value scales it all.

**In-run pickups** (from B7; numbers in `data/tuning/pickups.tres`)
59. **Picked-up items and the stock:** a picked-up charge belongs to the fight, like a granted item: breaking it
    never costs stock, and a pickup never adds to the stock.

**Razor Echo, the player model** (from P1; brief `docs/art/BRIEF_RAZOR_ECHO.md`; frames in the P1 report)
65. **Invulnerability and death in the new look** (FB 36, 37): the invulnerability tint is pale copper-white; on death
    the red flash stays and the conduits and eye go dark.
66. **The dash in copper:** the dash's shell, speed lines and smash burst are pale copper, a little dimmer so the
    additive shell never reads as a hazard's orange.

**Dangerous floor under ceilings** (from B2; `CeilingZones`, the gauntlet patterns)
73. **Octodogs under a ceiling** may run and charge a floor runner; their charges keep off pads and landing zones, and
    they never wind up at a ceiling rider.

**The Floating Head: ship, entrance, bombing run and reveal** (from E1a; numbers in `data/bosses/city_boss_tuning.tres`;
play it with `--boss=city_boss` in debug builds)
85. **The entrance:** a 4 s intro. It starts 42 m behind the runner out of sight with a jet roar, sweeps overhead (the
    camera shakes) and eases into its station, its stern 34 m ahead and its belly 12 m up; it attacks nothing on the way.

**The Floating Head: the face-off, the towers and the pin** (from E1b; numbers in `data/bosses/city_boss_tuning.tres`;
play it with `--boss=city_boss` in debug builds; showcase scenarios `faceoff`, `fallback`, `pinned`, `mouth`)
115. **The drag:** it burns down the runner's lane from about 25 m ahead to the runner in 1.0 s and leaves a burning line
    for 0.8 s (clear of a wall runner beside it). It fires only while a lane beside the runner is free to switch into.
123. **Its face-off sounds:** the eyes' rising, throbbing whine ending in a click; the beams' zap and buzz; the jaw's
    grinding ratchet and clank; a cyborg's landing clank; the tower's crack and groan; its crash onto the ship. The
    warnings sound the same every time.
(E1b's placeholder release, the ship shaking free as the runner comes within 12 m, is replaced by E1c's stomp windows.)

**Corporate skin** (from D4; numbers and colours are exports on `CorporateSkin`, F6; play it with
`--quick --skin=corporate --nofall` or `--level=corporate/1`)
137. **Motion cues on the still floor:** per 40 m, 20 grit and drizzle flecks, 3 paper scraps and 16 speed streaks, plus
    the carriage joints passing underfoot.
139. **Generic, soulless corporate art:** glass curtain walls and fin towers 44–170 m tall; the brand's glowing sign near
    the top of 45% of towers, banners on 40%, surveillance cameras on 50%, cold light strips up 70% of corners, glass
    skybridges 24–33 m up; wordless ads (the mark, charts that only go up, a turning globe).
141. **The mix of ceilings:** a glass skyway along the street (weight 3.0), a tower bridging the street (2.5), a concrete
    viaduct with a military checkpoint (2.5), a gunship flying low (1.0); every underside a flat plated surface with lamps
    along the lane seams and the orange band at its far end.
142. **How often the cult's emblem hides here:** 35% of the ads on street screens and roof boards (a small warm-white
    badge) and 35% of banners at their foot (unlit bronze); never under 0.9 m, never on a hazard sign, always above 8 m.
143. **How often the cult's feed plays here:** 35% of the big screens (roof boards, and screens hung out over the street
    14–18 m up from 35% of flush towers).
145. **Hazards in the zone's dress:** fences strung between slim steel security pylons on round base plates or set in
    olive barrier blocks, with the shared glowing bars; hazard signs are corporate screens inside the yellow and black
    frame.

**The campaign's shape: newest things picked most, The Hush, Buzz Overdrive in the Golden Zone** (from R5; the curve in
`data/tuning/feature_recency.tres`, F6 "Feature picks (campaign)"; The Hush in `data/levels/dead_zone_2.tres`; measure with
`tools/measure/level_shape.gd`. Buzz Overdrive is now listed in Golden 1–3, as corrected.)
156. **Music in the silent stretches:** see item 112; the generator can list the stretches for the music player.

**The Floating Head: the stomp windows** (from E1c; numbers in `data/bosses/city_boss_tuning.tres`, groups Stomp windows,
Ramp window, Ceiling window; showcase `floating_head_showcase.tscn -- --scenario=faceoff --towers-after=0 --phase=0|1|2`,
or `--scenario=window|missed`)
169. (E1d brought a perfect run to about 101 s: see item 201.) **The fight's length** (GDD §10: 60–120 s): a runner who never misses takes about 134 s (a 17 s first bombing run,
    two 9 s later runs, three face-offs until a tower, three windows). To tighten it: shorter or fewer bombing runs,
    fewer attacks before a tower, or towers closer together? (Task E1d brings it inside 60–120 s as a placeholder.)

**The Resonator** (from C3; numbers in `data/enemies/resonator.tres`, F6 "Enemy: Resonator"; review with
`tools/showcase/resonator_showcase.tscn` (`--view=model|play|close`, `--skin=golden`, `--double`, `--wall`), or quick
play with `--features=resonator --skin=golden`)
185. **The warning:** *(Superseded October 8, 2026: the chime is replaced by a crackling fire breaking into a wave crash, GDD §9.10; items 609–612.)* 1.3 s. The halos spin up and swing into line facing the runner, one on each of the chime's three
    notes, ending as a red target, while the core and trims glow brighter; the wave leaves at the end and reaches the
    runner about 1.1 s later (about 2.4 s from the first note). Steady glow with Reduced flashing. Right length and look?
195. **The chime and its sounds** (GDD §9.10) *(Superseded October 8, 2026: the chime is replaced by a crackling fire breaking into a wave crash, GDD §9.10; items 609–612.)*: soft mallets on tuned metal bars with a glassy shimmer, rising G5, C6, E6
    (a bright major triad, far from the Golden music's F♯ minor), the same every time; the pulse a deep thump and a rush
    rolling in along the floor; its death the chime bending out of tune and shattering. Right notes and feel?
197. **The hint:** *(Superseded October 8, 2026: the chime is replaced by a crackling fire breaking into a wave crash, GDD §9.10; items 609–612.)* "When the Resonator's chime plays, a red wave rolls along the floor. Jump it ({jump}), or be on a wall or
    the ceiling." Right wording?

**The Marketplace citizens** (from D3; regenerate the sheets with `tools/godot.sh citizens`; review with `tools/showcase/skin_review.tscn -- --skin=marketplace`)
260. **How many windows should host a citizen** (not in the GDD at all). Placeholder:
    `MarketCitizens.CITIZEN_SHARE` = 0.16 of eligible windows, picked to keep the chunk's draw calls
    and build time inside `SkinSuite`'s existing budgets (see `tests/suites/test_marketplace_skin.gd`
    for the measured numbers with citizens on and off). The owner can judge this by playing, so it's a
    tunable, not really an open question, but the share needed real measurement to pick.

**Zone doodads: the looks** (from G6; colours in each skin's "Doodads" group, F6; review with `tools/showcase/doodad_review.tscn -- --skin=<zone>`)
279. **What the Golden Zone's statue doodad looks like** (GDD §3, owner's playtest September 30, 2026:
    "statues on plinths, never at wall-run height (the Gilded Sentinels' language)"). The large doodad
    never stands at wall-run height anyway (it's a floor piece, far below `GoldenSkin.statue_min_height`),
    so the instruction read as: don't give it the Gilded Sentinels' specific shape language either (the
    armoured guard holding a halberd, `GoldenStatue`, task C4), so a statue in a lane is never mistaken
    for the live enemy even up close. Built it as a plain, faceless, robed figure instead: tapered gold
    tiers, a rounded cowl, hands clasped, a red sash, nothing raised or held. The alternative: reuse
    `GoldenStatue`'s decorative poses (`&"guard"`, `&"vigil"`, `&"salute"`) scaled down to fit the box,
    which would read as more clearly "a statue" (the same kit as the ledges') at the cost of standing
    closer to the Sentinel's own silhouette.
    *Placeholder:* since G6b the small class, painted: `tools/asset_gen/doodad_art/golden_art.gd` (`_figure`,
    `_statue`); `test_golden_skin`'s `_doodad_statue_not_sentinel` guards against the doodad ever building from
    `GoldenStatue`.

**The economy after the playtest** (from R7; measure with `tools/measure/economy.gd`; prices in `data/shop/catalog.json`)
293. **Armor I's new price (GDD §4, §8).** 350, reachable after one clean run of City 1 (or ~5 deaths).
    **Alternative:** cheaper still (so even a first attempt's partial credits cover it), or a flat
    starting discount instead of a price cut.
    **October 3 owner update (`docs/USER_REQUESTS.md`):** City 1 is now 55 seconds and its lower
    earnings are intentional; update tests, not rewards or prices. The historical affordability
    rationale is not a promise to compensate. After additive floor gaps, the 5-lane native-seed
    70%-share wallet is 372, so Armor I still fits City 1 at 350; Laser I at 900 now first fits
    City 3 (City 2 wallet 833, City 3 wallet 1,495); the laser later rose to 1,800, so it first fits City 4. The old ~5-deaths estimate is historical.

**The Sewer Swarm, the clusters and the Rising** (from E4a; numbers in `data/bosses/gangland_boss_tuning.tres`; play `--boss=gangland_boss`, review with `tools/showcase/sewer_swarm_showcase.tscn` and the stress scene `tools/showcase/swarm_stress.tscn`)
327. **The clusters in phase 3** (GDD §10: phase 2 ends "when the rest are" destroyed, yet in phase 3 the Host
    "flings the remaining clusters at the player"). With 5 clusters (2 + 3) none remain for phase 3.
    **Placeholder (E4a's stand-in until E4b builds the Host):** phase 3 re-forms clusters. Does the Host fling
    re-formed clusters, does phase 2 end with some left, or does it fling something else?

**The Enforcer Truck** (from C6; numbers in `data/enemies/enforcer_truck.tres`, F6 "Enemy: Enforcer Truck"; play `--level=corporate/2`, review with `tools/showcase/enforcer_truck_showcase.tscn`)
351. **Riders: hosts, and shooting riders off** (GDD §9.13 "picking up cyborgs", §9.7 hosts). A host is a cyborg
    the player can leave alive, but taking one aboard raises what happens to its Bad Dream when the truck is
    destroyed; and the GDD doesn't say whether a rider can be shot off the roof (which would lower the rate of
    fire again). Placeholder: hosts never board (`EnforcerTruckTuning.picks_up_hosts = false`, `DESIGN-TBD` in
    `scripts/enemies/enforcer_truck_tuning.gd`), and riders are part of the truck, so they share its immunity
    to weapons (`scripts/enemies/enforcer_truck.gd`, `_pick_up_riders`).
    **Answered (owner, October 7, 2026):** yes. Hosts never board, and riders can't be shot off (GDD §9.13).
352. **A gap too wide to hop** (GDD §9.13 "Holes"). Placeholder: a gap longer than 0.6 of a full jump at the
    level's speed wrecks it (`max_hop_jump_fraction` in `data/enemies/enforcer_truck.tres`); it hops every
    shorter one. Every gap in its six levels is 0.35 to 0.6 of a jump (measured at 3, 5 and 6 lanes on their own
    seeds: none wider), so in the campaign only a charge or a Buzz Overdrive's cut destroys it. Should its
    levels get a few wider gaps planned as baits during its chase (and how wide), or should the threshold come
    down so some ordinary gaps count?
    **Answered (owner, October 7, 2026):** every level gets a couple of wider gaps, uncommon but jumpable, that wreck an Enforcer following into them (GDD §9.13; task G7).
353. **The teaching moment** (GDD §9.13 "Teaching", proposed: before its first appearance the player sees a charge
    flatten another enemy, an Octodog lunging through a cyborg). Not built. The Octodog's and the Buzz
    Overdrive's rules keep every other enemy off their charge's stretch and lane (`Octodog.charge_clear`, the
    cut's lane window), the dog aims at the runner's lane, and a cyborg in that lane is an obstacle the runner
    must dodge anyway; a set piece would need a cyborg standing in a lunge's line ahead of the runner, which
    those fairness rules exist to prevent. Placeholder: the level introduction's hint (`data/hints/hints.json`,
    `enforcer_truck`) explains the bait. Should there be a scripted set piece (for example in Corporate 1 or
    early in Corporate 2: a cyborg in a lane beside the runner's, flattened by a dog lunging across from
    further ahead), or is the hint enough?
    **Answered (owner, October 7, 2026):** occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge, at least once before the Enforcer's first appearance (GDD §9.13; task G7).

**Level skies** (from G8; each level's `sky` in `data/levels/*.tres`, `scripts/world/skins/level_sky.gd`)
361. **The Marketplace's "third level"** (GDD §5, "Skies show progression"). The owner asked for the sunset on the
    Marketplace's third level, but the zone has two (GDD §5's schedule). Placeholder: the sunset is on
    Marketplace 2, the zone's last level, like City 3 and Gangland 3 (`data/levels/marketplace_2.tres`, `sky`;
    `DESIGN-TBD` on `LevelConfig.sky`). Move it to Marketplace 1, or keep it on the last level?
    **Answered (owner, October 9, 2026):** keep it on Marketplace 2, the zone's last level (GDD §5).
362. **The boss after each of these levels** (GDD §10). The Floating Head, the Sewer Swarm and The House, and each
    zone's outro, keep their zone's own sky, so the dawn goes back to night for the fight (and the blood red back
    to Gangland's dust, the sunset back to the Marketplace's warm dusk). Placeholder: the zone's own sky
    (`Campaign.configure_boss` gives the arena no level sky). Should each fight keep its zone's last level's sky?
    **Answered (owner, October 8, 2026):** yes. The fight keeps the sky of the level before it
    (`Campaign.configure_boss`); the dawn moved to City 1, so the Floating Head keeps the City's night (GDD §5).
    The boss's intro in between is item 404; the zones' outros after these fights are item 405.
363. **The street's light under the new skies** (GDD §5). Only the sky and the distant haze change; the scenery's
    lighting stays the zone's: the Marketplace's low sun still gilds the upper floors of one side under the
    darker sunset sky, and the City's street stays lit as at night under the dawn. Placeholder: unchanged.
    Should the street's light follow (for example a little of The Hush's darkness on Marketplace 2)?
    **Answered (owner, October 8, 2026):** yes, as it adds little code and no performance cost: each level sky's
    `scenery_tint` (the global `scenery_tint`, one multiply per scenery pixel; GDD §5).

**The Enforcer Truck shows itself; its explosion** (from C6b; groups "Showing itself" and "Wreck" in `data/enemies/enforcer_truck.tres`, F6; review with `tools/showcase/enforcer_truck_showcase.tscn -- --scenario=show` or `--scenario=cut`)
364. **How often players will see it** (GDD §9.13 "Showing itself": "every so often"). A showing needs about 7 s
    between its arrival and its bait's turn (pulling up, about 3 s alongside, dropping back, a margin), with a lane
    beside the runner kept clear. Many campaign chases put the bait sooner or fill the lanes beside the runner
    (fences, doodads, holes), so it often can't show. In Corporate 2's own build, a runner keeping to the middle
    lane sees no showing at 3 lanes, one at 5 and none at 6. Placeholder: at most `show_count` (2) showings, one
    on arrival and one mid-chase, only where every rule holds (`data/enemies/enforcer_truck.tres`; `DESIGN-TBD` on
    `EnforcerTruckTuning.show_count`). Should the generator keep room for the arrival showing (a later bait, or a
    clear stretch beside the runner's lane after it arrives)? That would be a change to the generator and the
    level data, so it needs a core task. Or is a rare showing fine?
365. **A runner in an outer lane** (GDD §9.13: "never takes the only free lane"). A runner in an outer lane has only
    one lane beside them, so the truck never shows itself to them. Placeholder: no showing while the runner is in
    an outer lane (`EnforcerTruck.show_lane_now`). Is that right, even though it means a player who keeps to the
    wall never sees it?
367. **Other attacks during a showing** (GDD §9, big attacks take turns). A showing takes a big attack's turn. A hover
    truck and a Gilded Sentinel can't wait, so while one is in play or about to arrive the truck doesn't show
    itself. A Resonator's pulse waits for the showing to end, as it waits for a volley (up to the director's
    `turn_wait_max`, 8 s). Placeholder: `EnforcerTruckRoom.NO_SHOW_TYPES`. OK?
    **Answered (owner, October 9, 2026):** a hover truck or a Gilded Sentinel no longer stops a showing, as long as the runner keeps a free lane (GDD §9.13; task C6e). The Resonator's pulse still waits.

**Room for the Enforcer Truck to show itself in every chase** (from C6c; the showing windows in `scripts/enemies/enforcer_truck_rules.gd` (`ShowPlanner`), group "Showing itself" in `data/enemies/enforcer_truck.tres`; count showings per chase with `tools/measure/enforcer_shows.gd`)
382. **A runner by a wall** (GDD §9.13 "Showing itself": "never takes the only free lane"; follows question 365). A
    runner in an outer lane used to never see the truck. Beside them on their inner side it would take their only
    lane to dodge into, and at 5 and 6 lanes it would also hide up to 25 m of their lane from the camera (the camera
    sits inward of a runner by a wall). Placeholder: it pulls up two lanes in and leaves the lane between free; the
    "never the only free lane" rule holds both ways (the lane between stays open wherever the runner's lane is
    blocked, and the runner's lane wherever the lane between is). Its whole look stays on screen and it hides nothing
    of their lane or the lane between (`EnforcerTruckRoom.sides`, `escape_lane`, `EnforcerTruckView.check`;
    `DESIGN-TBD`). Is two lanes in right?
    **Answered (owner, October 9, 2026):** yes: two lanes in, with the lane between left free (GDD §9.13).
383. **What a showing window may take out** (the owner's request against the danger density request). Where a chase
    has no calm stretch where it can show itself to a runner in every lane, the generator takes out only what's in the
    way: plain holes and fences (never a pulsing fence or one a fence generator powers), and plain cyborgs, window
    cyborgs and Screeches (never a host, the first of a kind the level introduces, or the last of its kind or of one
    of the level's features). Every
    later pass keeps its additions off each window, but nothing keeps a spacing from one. On the six levels' own seeds
    at 3, 5 and 6 lanes the windows cost about 2% of their enemies and of their obstacles (592 to 580 enemies, 3281 to
    3226 obstacles; from +3 to -14 obstacles a level), and the danger density pass's measured increases stay in their
    bands. Placeholder: `ShowPlanner.REMOVABLE_TYPES` and the window's stretch (`enforcer_truck_rules.gd`,
    `DESIGN-TBD` on `EnforcerTruckTuning.show_window_planned`). Is that cost acceptable?
    **Answered (owner, October 9, 2026):** yes: the cost is accepted (GDD §9.13).
384. **Chases with no window** (7 of the 23 chases on the levels' own seeds). In four, a hover truck or a Gilded
    Sentinel is about for the whole chase, and the truck never shows itself while one is (question 367). The other
    three have no calm stretch at all: Corporate 2 at 5 lanes (the truck's introduction, among an Octodog's charges, a
    Tithe Collector and a Buzz Overdrive's attack), Dead Zone 1 at 3 lanes (pulsing fences, a ramp's wall run and a
    Screech at the level's start), and Dead Zone 2 at 6 lanes (rows of fences with a pad in their gap). Three more
    windows hold for most lanes but not all: a runner who takes a pad onto a ceiling, or a ramp onto a wall, in that
    lane misses that showing. Placeholder: the baits that get trucks are the ones whose chases hold the most windows,
    and a level that introduces the truck keeps its first bait's chase. Should a chase with no room for a showing get
    no truck (another bait instead), or should the hover truck and the Gilded Sentinel make room?
    **Answered (owner, October 9, 2026):** move the truck to a chase with room whenever the level has another bait (GDD §9.13; task C6d).
385. **Windows after the bait** (6 of the 16). Where the bait comes right after the truck arrives (at some lane counts
    the Golden levels' first truck arrives at the end of the run-up and their first Buzz Overdrive revs 4 s later), no
    showing fits before it, so the window comes after the first bait. A player who destroys the truck with that bait sees its wreck blow up instead, and a wider gap later in
    the chase (task G7) can wreck it first too: in the simulated runs, 18 of the 75 runner runs with a window lost the
    truck before its window. Placeholder: as described (`ShowPlanner.plan`). Is a showing after the bait worth its
    calm stretch, or should those chases arrive later?
    **Answered (owner, October 9, 2026):** yes: those trucks arrive earlier, so the showing comes before the bait (GDD §9.13; task C6d).

**The Floating Head's salvos** (from E1g; group "Salvos" and `later_run_seconds` in `data/bosses/city_boss_tuning.tres`,
F6 in the fight; the owner's request and answers, October 9, 2026, are in GDD §10; review with
`tools/showcase/floating_head_showcase.tscn -- --scenario=bombing --phase=1` or `--phase=2`, with `--lanes=3`, `5` or `6`)
396. **Which runs drop salvos** (GDD §10: "the next bombing run"). The fight has two later runs, at the start of phases 2
    and 3. Placeholder: both drop salvos (`salvo_spots` = 1, 4, 4; the first run keeps one spot at a time). Should the
    third phase's run go back to one spot at a time (1, 4, 1)?
    **Answered (owner, October 9, 2026):** the third phase's run keeps its salvos (GDD §10).
397. **How much harder on 5 or more lanes** (owner: "increase the difficulty on five or more lanes"). With one or two
    bombs a spot, a runner on a wide street can step clear of a whole salvo. Placeholder: from 5 lanes
    (`salvo_wide_lanes`) a spot takes up to three bombs side by side (`salvo_wide_bombs`), placed to leave the runner as
    few lanes as possible but never none, so after the first spot there is usually one way through
    (`salvo_wide_choices` = 1; 2 would leave a choice of two lanes). On 3 lanes a spot keeps one or two bombs, two 40%
    of the time (`salvo_pair_chance`). Is three bombs a spot right (beyond the one or two first asked for), and is one
    way through too hard?
    **Answered (owner, October 9, 2026):** three bombs a spot is right on 5 or more lanes, leaving a choice of two lanes
    (`salvo_wide_choices` = 2). On 3 lanes a spot leaves one lane, a forced path, with one or two bombs (`salvo_choices`
    = 1, `salvo_bombs` = 2; `salvo_pair_chance` is gone: every street places its spots the same way). GDD §10.
398. **How tight** (owner: "make it tighter"). Placeholder: 10 m between spots at 18 m/s instead of 12 m
    (`salvo_spacing`): about 0.56 s from one blast to the next, leaving about 0.4 s after passing a blast to switch one
    lane before the next (`salvo_max_shift`: one lane from spot to spot). Tighter still?
    **Answered (owner, October 9, 2026):** the spacing is right as it is (GDD §10).
399. **The later runs' length** (owner: a little longer, for the longer salvos). Placeholder: 6.5 s instead of 5.6 s
    (`later_run_seconds`): two salvos of four spots fit, with a little room. Right length?
    **Answered (owner, October 9, 2026):** longer, 10–12 s. Built: 10 s, which fits three salvos of four spots, stays
    shorter than the first run (11.2 s) and leaves a flawless fight's length as it was (113.9, 100.6 and 114.0 s at 3,
    5 and 6 lanes); 11 s makes it miss a tower and wait for the next (133.9 s at 3 lanes, past GDD §10's 60–120 s).

**Every chase shows its truck** (from C6d; `_choose` and `ShowPlanner` in `scripts/enemies/enforcer_truck_rules.gd`; count chases and showings with `tools/measure/enforcer_shows.gd`)
400. **Chases no bait with room is left for** (GDD §9.13 "Room to show itself"; follows questions 384 and 385). On the
    levels' own seeds, 14 of the 23 chases still have no window before their bait, and no move or earlier arrival
    gives them one. In 8 builds the level has a single usable bait: it comes too soon for any showing before it (Golden
    1 at 3 and 6 lanes, Golden 2 and 3 at 6: a Buzz Overdrive revs 4 s after the run-up; Corporate 2 at 6 lanes: an
    Octodog charging at the start keeps its truck from arriving earlier), or a hover truck or a Gilded Sentinel is
    about for its whole chase (Dead Zone 1 at 6 lanes, Golden 2 at 3, Golden 3 at 5). In the other 6 chases the level's
    other bait already has its other truck (see the next question), or neither bait has room (Dead Zone 2 at 3 lanes).
    Placeholder: the truck keeps its chase, its showing after the bait where one fits (7 chases), else none
    (`_choose` in `enforcer_truck_rules.gd`; `DESIGN-TBD` on `EnforcerTruckTuning.show_window_planned`). Dropping those
    trucks would leave 9 of the 18 builds with none (Corporate 2 at 6 lanes among them, its introduction). With 8 other
    seeds of each level (162 builds) the hover truck and the Sentinel weigh most: they keep 93 of the 128 chases with no
    window from having one (Corporate 2 brings many hover trucks). Keep those trucks as they are, or make room another
    way (the level's first Buzz Overdrive later; the hover truck and the Sentinel letting it show)?
    **Answered (owner, October 9, 2026):** make room: the hover truck and the Sentinel let it show (with a free lane kept), and where the first bait comes right after the calm start, the truck arrives a few seconds early and shows itself at the end of it (GDD §9.13; task C6e).
401. **Two trucks, one chase with room** (Corporate 2 at 5 lanes, Dead Zone 1 at 3 lanes, Dead Zone 2 at 5 and 6 lanes, on
    their own seeds). The only bait whose chase has room before it has one truck; the other truck has nowhere with room
    to go. Placeholder: both stay, so in Corporate 2 at 5 lanes the introduction (14 s in, among a Tithe Collector's
    visit and then its own Buzz Overdrive's turn too close) shows itself only at the second truck (59 s). Or should such
    a level keep only the truck that shows itself (one truck instead of two; Corporate 2's introduction at 59 s)?
    **Answered (owner, October 9, 2026):** keep both trucks (GDD §9.13).

**The zone doodads as picture cards** (from G6b; the owner's request of October 9, 2026: each doodad a simple box with a picture of the object on it, open air see-through; the pictures in `tools/asset_gen/doodad_art/<zone>_art.gd`, regenerated with `tools/godot.sh doodads`; review with `tools/showcase/doodad_review.tscn -- --skin=<zone> --lanes=5`. The owner answered every item the same day; GDD §3, Zone doodads, their look)
412. **Each zone's three looks** (GDD §3; §5, each zone's mood; the owner left them to the build's recommendation).
    Placeholder: City a vending machine or a poster pillar, a street-food stall, a little shop; Gangland oil drums, a
    burned-out van, a broken-down shack; Marketplace a potted palm or a flowering bush, the vendor's stall, a slot-machine
    bank; Corporate a steel planter, a security booth, a supply container; Dead Zone a broken column, a rubble heap, a
    burned-out bus; Golden a robed statue or a gilded urn, a wall fountain, a colonnade (small, medium, large). Some
    differ from G6's meshes (the drums, the van, the stall, the booth, the container, the column, the bus, the statue as
    the small one, the colonnade).
    **Answered (owner, October 9, 2026):** the looks are fine (GDD §3).
413. **Showing the push side** (GDD §3: a push to "the side with room, a side chosen per doodad"). The old default
    slanted a doodad's front back toward the side it pushes to; the pictures are the same from either side.
    **Answered (owner, October 9, 2026):** no hint needed (GDD §3). The grey box's default look still slants.
414. **A rubble heap lower at its edges** (GDD §3: a doodad reads as too tall to jump). Placeholder: a mound 2.5 m in its
    middle and 1.5 m at its edges (`HEAP_EDGE`, `HEAP_PEAK` in `dead_zone_art.gd`); its box is 2.6 m everywhere.
    **Answered (owner, October 9, 2026):** fine (GDD §3).
415. **The doodads' edge sheen.** Placeholder: a soft neutral sheen at grazing angles (`doodad_card.gdshader`), where
    the kit's violet default framed the dark zones' doodads in purple edges.
    **Answered (owner, October 9, 2026):** fine (GDD §3).

**The Golden Convergence: the design choices made under the owner's mandate** (from E5d's design session with the owner, October 9, 2026; every choice is marked *(proposed)* in GDD §10, The Golden Convergence; numbers in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight) and `data/bosses/golden_boss_skin.tres`; play `--level=golden/boss`, review with `tools/showcase/golden_convergence_showcase.tscn` and `golden_convergence_magnate_showcase.tscn`)
418. **The entrance:** the suit rises at the far end of the court, its cape unfurling, to the cult's
    three-note chime (the Resonator's) played huge and slow.
419. **Paces:** stage 1's phases at 1, 1.1 and 1.2; stage 2's at 1, 1.15 and 1.3 (the Sleep Taker's).
420. **The strafe's first pass covers the outer lanes**; in the 7-pass strafe the 4th and 7th passes come
    from behind.
421. **The horizontal pass's live line reaches above a jump** (a jump doesn't dodge it: the buttress or the
    dash does).
422. **Which slams land ahead, and which are buttress chances** (a fixed script): phase 1, slams 1 and 2 on
    the runner and 3 ahead, chances on 2 and 3; later phases, slams 1, 3 and 4 on the runner and 2 and 5
    ahead, chances on 3 and 4. About two seconds apart, faster with the phase's pace.
423. **The hole's footprint:** around the locked lane, moved inward at the edge; a fist locked onto another
    lane never digs through a buttress.
424. **The barrage's fire** is about 1.5 s and a metre high (a jump only delays it); the missiles hang at
    the top of their climb, then dive with a whistle while the red marks fill in.
425. **The Refill Ship's strafe holds its fire** while the cage comes up and the runner goes for it, so the
    route to the pad is always clear, then fires on once they're past the pad.
426. **The cage's sides** are fences along the pad lane's edges (a new lengthwise fence, the same pink
    crackle and rules as any fence).
427. **Stage 2's attacks:** the Pounce (bait it into a Flying Buttress to stun him; stomp a red spine port
    by jumping onto his back) and, from stage 2's second phase, the Cable Lash (low: jump; high: slide).
    A buttress comes up for every second Pounce. Do you want a third attack for stage 2's last phase?
    *Answered (the owner's playtest, October 9, 2026):* two more attacks for stage 2, the Claw Slash and the Screen Storm (GDD §10; items 491-503).
429. **Numbers:** six phases of the boss's health (a sixth each); weapons chip at most one big hit's worth
    over the whole fight; 1,000 credits and 10,000 points for the win; par times measured from a clean
    fight.

**The Golden Convergence: the golden suit, the Grand Court, the Helidrone Strafe and the Flying Buttress** (from E5d-a; built in task E5d-a (the golden suit, the Grand Court, the entrance, the Helidrone Strafe and the Flying Buttress). Every number below is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight) or `data/bosses/golden_boss_skin.tres` (`GoldenCourtSkin`) unless it says otherwise, marked `DESIGN-TBD` in code)
433. **The squadron's look** (GDD §10: "the heli drone's model, never coloured red"): the heli drone's model at
    1.45x (`drone_scale`), its red eye and band redrawn in a cold white glow and unlit gold, no amber
    (`add_model(..., hostile = false)` in `scripts/enemies/drone.gd`). Their fire and its warnings stay the
    enemy attacks' red.
434. **A jump doesn't dodge a vertical pass either.** The rake's fire reaches 3.2 m up
    (`GoldenConvergenceFire.RAKE_HEIGHT`, over a jump's reach), as the GDD proposes for the horizontal line,
    so each vertical pass makes the runner change lanes ("each vertical pass moves the player").
435. **The first pass on 6 lanes.** "The first pass covers the outer lanes (lanes 1, 3, 5 counting from 1)":
    on 3 and 5 lanes those take both outer lanes; on 6 lanes lanes 1, 3 and 5 take only the left one (lane 6
    is safe on the first pass). Built as written (`GoldenConvergenceTuning.covered_lanes`, parity 0 first).
436. **The strafe's timings** (GDD §10: "about a second ahead"; "a second or two apart"): the red lines and
    the whine come 1.15 s before the guns open up at the far end of the raked stretch (`warning_seconds`,
    never divided by the pace); a head-on pass rakes 42 m of lane toward the runner at 55 m/s, so a runner who
    stays is hit about 1.4 s after the lines show; a pass from behind about 2 s after; the next pass's warning 1.5 s after a pass's fire
    (`pass_gap`, divided by the phase's pace); out of the cape 1.6 s, back 2.2 s. The squadron waits 40 m
    ahead and 12 m up between passes and rakes from 7 m up.
437. **The horizontal pass:** the sweep crosses the track in 0.55 s; the live line burns whole 0.3 s before
    the runner reaches it and 0.45 s after they're past it; its fire reaches 3.4 m up (above a jump) and 1.6 m
    along the track; the lines for show lie 24 m apart beyond it (one per other drone), burn 0.6 s and have no
    hitbox at all (their fire is out long before the runner gets there); scorch marks fade over 9 s.
440. **The Grand Court's numbers:** the balustrade 1.1 m tall with lamp posts every 5 m; the pools 22 m below;
    a tower every 120 m along each side (alternating), 30 m out, each with a 17 m feed screen 24 m up showing
    the calm golden face and the emblem in turn (`golden_court_feed.gdshader`; stage 2's roaring Magnate is a
    darkened placeholder until E5d-d); the hall's colonnade 95 m out, columns 135 m tall, the vault's ribs
    every 160 m.
441. **The entrance's timing** (proposed in the GDD): the first phase's intro is 5.5 s: the suit rises 60 m
    over 3.2 s, the cape unfurls from 1 s over 2.6 s, the chime rings at 1.6 s (the Resonator's G5, C6 and E6,
    0.7 s apart where the Resonator's are 0.42 s, each doubled an octave and two below, with the court's
    echo: `gc_chime`; every sound effect stays under 2.5 s, so the rise's rumble tapers off under the chime); then the first
    beat 0.8 s into the pattern. A later stage 1 phase's 3 s intro: the suit reels back (0.22 rad) and
    recovers.
442. **The fight's numbers for now:** 600 health; pars 330 s (two stars) and 260 s (three) and a 400 s time
    bonus, all provisional until the whole fight is built; phase names "The Golden Suit" (1-3) and "The
    Magnate" (4-6). The boss bar shows the phase's number alone ("1/6") when the boss's long name and the
    phase's title don't both fit (`BossBar._refresh`).
    *Superseded:* the par times are now 238 s (three stars) and 308 s (two stars), from the clean whole fight after E5d-e.
443. **Until the later steps:** a beat whose attack isn't built yet is skipped (slams, barrage: E5d-b), a
    refill beat plays its strafe alone (E5d-c), and stage 2 (phases 4-6) idles the suit with no attack
    (E5d-d), so `--boss=golden_boss --phase=4` plays.
    *Obsolete:* every step is built (E5d-b, c, d and e).

**The Golden Convergence: the Fist Slam, the toppled tower and the Missile Barrage** (from E5d-b; built in task E5d-b (the Fist Slam with its Flying Buttress bait and the toppled tower's wall, and the Missile Barrage). Every number below is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, groups "Fist Slam", "The toppled tower" and "Missile Barrage", F6 in the fight) unless it says otherwise, marked `DESIGN-TBD` in code)
446. **The square footprint** (GDD §10, proposed: "around the locked lane, moved inward at the edge"): two
    lanes on 3 lanes, three on 5 and 6 (`GoldenConvergenceHole.hole_lanes`), as long along the track as it is
    wide. On 3 lanes, from the middle lane the second lane is on the slamming fist's side (they take turns);
    from an outer lane, the middle lane. Never every lane, so a lane switch always gets out from under it.
447. **The fist's timing:** out over the runner's lane in 0.7 s (over the pace), the warning (the fist rising
    from 8 m to 11 m, its shadow growing, the red square, the grind) 0.8 s before the lock, the lock 1 s before
    it lands, the drop in the last 0.4 s; slams 2 s apart (over the pace); back to rest in 0.85 s. An ahead slam
    lands as the runner is 1.1 s from its hole (`slam_ahead_seconds`), to be jumped or switched around. The
    touch lasts 0.2 s from the impact and reaches 4 m up over the hole's square (`slam_hit_seconds`,
    `slam_hit_height`: a jump doesn't clear it).
448. **The hold after a blocked hit** (GDD §10: "the floor under the runner holds for about a second ... A dash
    through the fist gets the same second"): it's given to any runner the touch doesn't kill: the armor or the
    shield blocking it, the dash, and also a runner still invulnerable from an earlier hit (and god mode).
    Only the lanes under the runner's feet hold, for `GameRules.cut_hold_seconds` (1 s). The grapple saves
    the fall into the hole, never the hit.
451. **A bait ends the sequence at once:** the other gate, if it's up, sinks back into the causeway the way it
    rose; the barrage starts warming up the same frame (no gap after a bait; the usual `beat_gap` otherwise).
453. **The barrage's warning:** the hatches open over 0.5 s, the missiles launch one after another over 0.5 s
    and climb for 1 s, arcing up out of view, then hang 0.5 s 22 m up and about 46 m ahead, out to either side
    of the suit's chest and keeping pace with the runner (`missile_apex_height`;
    `GoldenConvergenceBarrage.APEX_*`), then dive for 1 s with the whistle while the marks fill in: the fire
    lands 3 s after the hatches open, at every pace. Reaching the wall from the far side needs 1.5 s on 3
    lanes and 2 s on 6 (a 0.7 s reaction, 0.14 s a lane switch, the 0.16 s wall entry and a 0.4 s margin:
    `barrage_reaction`, `barrage_margin`). The red marks spread over the floor from the launch: 5 a lane
    (`marks_per_lane`, one missile each), 0.95 m across (`mark_radius`). Like every other attack it's keyed
    to the runner's distance at the run speed, so a dash during the warning brings the fire a little sooner.
454. **The fire's stretch:** every lane from 3 m behind where the runner is as it lands (`fire_behind`) to as
    far as they could run while it burns, a dash included, and 5 m more (`fire_ahead`): it can't be outrun.
    In an outer lane it stops short of a wall runner's body, so the wall is safe at every height. It leaves
    no scorch marks (the strafe's do); it dies down over 0.35 s after its 1.5 s.
455. **Pickups keep off** a slam's rows and the barrage's stretch (both are floor warnings, like the strafe's
    red lines).

**The Golden Convergence: The Magnate (stage 2) and the defeat** (from E5d-d; built in task E5d-d (stage 2, The Magnate, and the defeat, "the feed dies"). Every number is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`'s "The Magnate" groups, F6 in the fight) unless it says otherwise, marked `DESIGN-TBD` in code. Review it with `./play.sh --boss=golden_boss --phase=4` and the showcase (`res://tools/showcase/golden_convergence_magnate_showcase.tscn`, its header lists the scenarios))
457. **His look** (GDD §10, Look, owner approved): built as written on all fours, a hunched predator about 3.5 m
    from snout to rump and 1.95 m at the shoulder, 2.7 times the runner's drawn height (`magnate_scale` 1):
    blackish-grey skin cracked in a fine cell network, the plates between toned like burnt paper; dull gold
    splashes on his shoulders and haunches; half the calm golden mask fused to his left side (the runner's
    right as he faces them), its closed eye and dull red tear, his real right half a heavy brow, a wild pale
    eye and a roaring jaw; five red ports along his spine (the weak points' red, the only thing on him that
    glows a hazard colour); burgundy tatters from his shoulders trailing grey smoke; the six broadcast cables
    (the suit's tentacle pipes, burnt black with dull gold bands) trailing from his back to the ground behind
    him. Is this him?
464. **The phases' scripts** (`phase_beats`): phase 4 an overtake, a Pounce, a Pounce with the bait; phase 5 a
    Pounce, a low Lash, a Pounce with the bait, a high Lash; phase 6 a Pounce, a high and a low Lash, a Pounce
    with the bait, a low and a high Lash; each looped until the stomp. A clean stage 2 from the checkpoint takes
    about 76 s of fight (about 25 s a phase). The GDD asks "do you want a third attack for stage 2's last
    phase?" (question 12 above): phase 6 is the Lash's mixes at the fastest pace for now.

**The Golden Convergence: the Refill Ship and stage 1's phases** (from E5d-c; built in task E5d-c (the Refill Ship, its closed cage and the chain reaction: the only way to damage the golden suit; stage 1 played through, and the whole fight in the campaign). Every number below is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`'s "Refill Ship" groups, F6 in the fight) unless it says otherwise, marked `DESIGN-TBD` in code. Review it with `./play.sh --boss=golden_boss` (or `--level=golden/boss`) and the showcase (`res://tools/showcase/golden_convergence_showcase.tscn`: `--scenario=refill`, `cage`, `chain`, `missed`, `stage1`, `whole`; its header lists the options))
470. **Which shoulder it feeds:** the one whose pipes are whole, his right first (the runner's left), then his
    left; in phase 3, with both blown out, his right's torn stubs (`GoldenConvergenceRefill.fed_side`). The ship
    waits on that side.
476. **The chain reaction's timing** (GDD §10: the pad "hurls the whole squadron up into the Refill Ship, setting off
    a chain reaction"): from the pad, the drones crash into its racks; the missiles go up in a ripple along the
    racks from 0.3 s over 0.8 s (`ripple_at`, `ripple_seconds`), outward from where the drones hit; the ship spins
    off to the fed side from 1.4 s over 1.3 s (`spin_at`, `spin_seconds`), its belly gone, so the runner rides it
    about 1.4 s and drops back to the floor, landing about 0.6 s later; it explodes beside the causeway past the
    balustrade, and the blast races up the line into his shoulder in 0.9 s (`blast_seconds`): the hit lands 3.6 s
    after the pad. The squadron is gone with the ship (that strafe is over).
477. **The cage sinks away once its pad is ridden** (0.35 s, harmless at once), so the camera doesn't pass through
    its fences as it ducks under the belly.
478. **The hits show** (GDD §10: "the first blows out one shoulder's pipes, the second the other's, and the third
    bursts the suit open"): the first ship's blast blows out his right shoulder's pipes, the second's his left's.
    The third's ends phase 3: the transition's burst is the only blast then (the ship's adds none), so a retry
    from the checkpoint shows the same burst. A phase ended by weapons (they can end a phase:
    `weapons_can_end_phase`) shows the same damage as a ship's hit would have (`GoldenConvergence._show_damage`).
479. **The next phase's first slams are planned from the chain reaction** (E5d-b question 7, "the first slam can
    stalk"): the chain knows when its hit will land, so at the Golden Zone's 25 m/s phases 2 and 3 open with
    their first fist on time (`GoldenConvergenceSlams.plan_phase_ahead`). At quick play's 18 m/s the built track
    (about 180 m ahead) still reaches past where it would land, so it comes as soon as the track allows, about
    2.7 s late (about 4 s if planned at the phase's start), the fist stalking the runner's lane meanwhile. A
    phase ended by weapons still plans at its start, and its first fist can stalk.
480. **A missed pad** (GDD §10: "the ship finishes refilling and flies off, and the phase's loop starts again
    from the slams"): a runner 3 m (at 18 m/s) past the pad without riding it has missed it (`miss_after`); the
    ship climbs back to its station over 1.6 s, finishes refilling 1.5 s later and flies off ahead and away over
    2.2 s (`climb_seconds`, `finish_seconds`, `leave_seconds`), while the strafe fires its passes left; the
    beat is over when both are, and the loop goes on from the slams (planned while the ship flies off). The
    next ship is the same (no escalation).
481. **Par times** (E5d-a question 12): measured from the test bot's clean fight (every pad ridden by the
    generator, never hit, no armor): 198.2 s from the entrance to the defeat at the Golden Zone's 25 m/s at 3, 5
    and 6 lanes (stage 1 won at 122.0 s), and 208.7 s at quick play's 18 m/s (stage 1 at 132.4 s: at the lower
    speed the built track reaches further ahead in seconds, so the slams' holes, which must lie past it, come
    later; question 11). Set the way Hostile Takeover's are (74 s and 96 s
    over its clean 68.6 s): three stars at 214 s, two at 277 s, and the time bonus runs out at 340 s, a little
    past two stars as the provisional 400 s was past 330 s (`data/bosses/golden_boss.tres`). The fight is three
    times longer than any other boss's; are these the right margins?
482. **Its sounds** (`tools/asset_gen/sfx_bank_golden_convergence.gd`, none pitch-varied): the ship's engines
    droning in (`gc_ship`, as long as its flight in), the feed line's pneumatic shot and coupling clank
    (`gc_feed`), missiles clattering up the line (`gc_ride`, every 1.3 s while it feeds), the fence warning
    as the cage flickers in, the drones' hurl (E5d-a's), the ripple along the racks (`gc_ripple`), the ship's
    crash (`gc_crash`), the blast racing up the line (`gc_blast`), the pipes blowing out (`gc_pipes`) and, on a
    miss, the ship leaving (`gc_leave`).

**The Golden Convergence: the polish pass** (from the review of E5d-a, b and d; built in the polish pass after the fight's review. Numbers are in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight) or constants marked `DESIGN-TBD` in code, as each item says)
488. **The barrage's target marks** fill in near opaque (`fill_alpha` 0.95 in `golden_convergence_floor.gdshader`;
    0.6 read salmon or pink over the white marble), so they read red on every renderer.
490. **The Magnate's legs move now** (a fix found in this pass): his poses never reached his legs (a blend skipped
    their angles), so they stayed in his first frame's pose; his gallop, the leap's stretch, the rear, the whip and
    the slump show now. Worth a look: `res://tools/showcase/golden_convergence_magnate_showcase.tscn`,
    `--scenario=magnate`.

**The Golden Convergence: the owner's playtest of stage 2 (the Claw Slash, the Screen Storm, darker)** (from E5d-e; the owner's request and approvals of October 9, 2026 are in GDD §10, Second stage, Owner's playtest; built in task E5d-e, the owner's playtest of stage 2 (GDD §10, "Owner's playtest (October 9, 2026)": the Claw Slash, the Screen Storm, the arena darker, the new beat scripts, the stomp's chevrons). The owner approved the playtest's specifics; these are the choices made while building them. Numbers are in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight: "The Magnate: the darkness", "the Claw Slash", "the Screen Storm") unless the item says otherwise, marked `DESIGN-TBD` in code)
498. **The stomp's chevrons and the stun's lead.** Green ramp chevrons in both of his lanes over the middle of the
    take-off stretch (12% of it off each end, as the cue before the Hostile Takeover's couplings), streaming toward
    him from the stun until he's stomped or shakes free (`GoldenConvergenceTakeoffMarks`). He now crashes into the
    gate 1.75 to 1.78 s before the runner reaches his back, which leaves 1.5 s from the stun to the last take-off
    (`stun_takeoff`).
499. **Stage 2's beats come 0.6 s apart** (`stage_two_beat_gap`; stage 1's are 1.6 s), divided by the phase's pace.
    A beat is over once he's back behind the runner, so nothing of one attack is still out when the next one warns.
500. **Its sounds** (`tools/asset_gen/sfx_bank_magnate.gd`, each under 2.5 s, the two warnings never pitch-varied):
    `magnate_snarl` (the Slash's warning: a short, sharp snarl, not the Pounce's roar), `magnate_swipe` (the
    claws), `magnate_glitch` (a screen's warning: the rising glitch-whine), `magnate_smash` (a screen shattering),
    `magnate_yank` (its tentacle whipping it away) and `magnate_pain` (his cry when a screen hits him).
501. **The screens' look.** 16:9 screens 2 m wide in gilded frames, his glitching, roaring face on them (the court's
    feed shader, held still with Reduced flashing), each on a gold tentacle 46 m long up into the vault; a crash
    throws pale glass shards (and warm white sparks, none with Reduced flashing), and the dark, broken screen is
    yanked away (`GoldenConvergenceTentacles`).
502. **The hints** (`data/hints/hints.json`): `golden_boss_slash` and `golden_boss_screens` are new, and the stun's
    now says to take off from the green chevrons.
503. **The par times, from the longer clean fight.** The bot's clean fight now takes 217.6 to 220.2 s at 25 m/s and
    228.2 to 229.3 s at 18 m/s (it was 198.3 to 200.1 s and 208.9 to 209.1 s); stage 2 from the checkpoint takes
    about 96 s (it was 76 s). Three stars at 238 s, two at 308 s (Hostile Takeover's margins over a clean fight)
    and the time bonus runs out at 378 s (they were 214, 277 and 340 s; `data/bosses/golden_boss.tres`).

**The Casino skin** (from K1; the owner's reference `docs/art/reference/casino_zone.webp`; exports on `CasinoSkin`, `data/skins/casino_skin.tres` and the arena's `data/bosses/casino_boss_skin.tres`, F6; review with `./play.sh --quick --skin=casino`)
506. **Sign names (the reference's "Gasket's House of Chance", "The Brass Lotus", "Casino Entrance").** The
    game's signs and screens carry no real words (the cult's feed is wordless; every skin's lettering is rows of
    chunky glyphs), so the names can't be spelled. Placeholder: lit signs show a brand mark (a diamond, a lotus,
    a crown, a chip or a die) and rows of glyphs, and vertical blade signs run lettering down their board like
    "The Brass Lotus". Should the Casino's two named signs be drawn as real lettering once the project has a
    way to draw words on a sign (a texture of each sign)? Until then no sign says "HAZARD" or anything else.
    **Answered (owner, October 9, 2026):** real lettering, with the names "Gasket's House of Chance" and "The Brass Lotus" (GDD §5, Zone 4; task K3).
507. **Pedestrians far down the street.** The reference has a few small figures far down the street. The owner
    said no new characters, and the Marketplace's citizens only play in shop windows (they react to the runner
    and The House's crowds cheer and duck through them). Placeholder: **none**: the street is empty, as the
    Marketplace's is. Should a few of the Marketplace's citizens also stand far down the street as tiny,
    fogged silhouettes (scenery only, never in the lanes), or are the shop windows enough?
    **Answered (owner, October 9, 2026):** no pedestrians; the shop windows are enough (GDD §5, Zone 4).
509. **The glass roof (GDD §5: the vault stays high overhead as background).** Placeholder: the roof springs from
    the facades' top at 22 m and rises to about 26-29 m (higher over a wider street); it is **opaque and faked**
    (dark night-blue panes with a few stars, warmer where they catch the lamplit haze, 10% of the panes missing
    so the night sky shows through), with iron ribs every 8 m, girders across the street every 32 m or so
    carrying heavy banners, lanterns on chains and the occasional still ceiling fan. Nothing hangs below 16 m
    over the lanes (the arrival flyover's and The House's limits). The ceiling fans don't turn (a static mesh).
    Is the broken glass right for a "gaudy, warm and a little seedy" casino, or should the roof be whole?
    **Answered (owner, October 9, 2026):** the roof is whole, with no broken or missing panes (GDD §5, Zone 4; task K3).

**The Casino in the campaign** (from K2; the owner added the Casino as Zone 4 on October 8, 2026, GDD §5, §6, §10; data in `data/zones/casino.tres`, `data/levels/casino_1.tres`, `casino_2.tres`, `data/bosses/casino_boss.tres`; review with `./play.sh --level=casino/1` or `--level=casino/boss`)
516. **The Casino's level names** (GDD §5: "(name to come)"). Proposed: Casino 1 *Brass Arcade* (the covered
    street, its brass pipes), Casino 2 *House Edge* (The House follows it) (`display_name` in
    `data/levels/casino_1.tres`, `casino_2.tres`).
    **Answered (owner, October 9, 2026):** *Brass Arcade* and *House Edge* are approved (GDD §5).
519. **The difficulty curve over 17 levels: the owner's choice** (GDD §6: an automatic curve making each level
    slightly harder than the last). The curve still runs 0.1 to 0.9 and `enemy_scaling` 0 to 1, now over 17
    levels, so every level between City 1 and Golden 3 moved (the curve's step from 0.057 to 0.05 a level):
    the City, Gangland and the Marketplace got a little easier, Corporate, the Dead Zone and Golden 1 and 2 a
    little harder.
    Placeholder: this re-spaced curve. The alternative keeps the existing levels' difficulty (each level's
    `difficulty_bias` holding its old value, the Casino's two levels between Marketplace 2's 0.500 and
    Corporate 1's 0.557), which keeps their difficulty-gated patterns and spacing as they were (not their
    recency ages or completion bonuses, which follow a level's place in the campaign either way). What the
    re-spaced curve changes is listed below ("What the re-spaced curve changes"). Which does the owner want?
    **Answered (owner, October 9, 2026):** no level gets easier: every level is too easy, at least on PC. The Marketplace keeps at least its old difficulty (a little harder is welcome), and Corporate and beyond may get harder (GDD §6; task K4). Built in K4: the curve's exponent 0.79 (item 528 has the table).

    | Level | Difficulty before | after | Enemy scaling before | after |
    |---|---|---|---|---|
    | City 1 | 0.050 | 0.050 | 0.000 | 0.000 |
    | City 2 | 0.157 | 0.150 | 0.071 | 0.063 |
    | City 3 | 0.214 | 0.200 | 0.143 | 0.125 |
    | Gangland 1 | 0.271 | 0.250 | 0.214 | 0.188 |
    | Gangland 2 | 0.329 | 0.300 | 0.286 | 0.250 |
    | Gangland 3 | 0.386 | 0.350 | 0.357 | 0.313 |
    | Marketplace 1 | 0.443 | 0.400 | 0.429 | 0.375 |
    | Marketplace 2 | 0.500 | 0.450 | 0.500 | 0.438 |
    | Casino 1 | – | 0.500 | – | 0.500 |
    | Casino 2 | – | 0.550 | – | 0.563 |
    | Corporate 1 | 0.557 | 0.600 | 0.571 | 0.625 |
    | Corporate 2 | 0.614 | 0.650 | 0.643 | 0.688 |
    | Dead Zone 1 | 0.671 | 0.700 | 0.714 | 0.750 |
    | Dead Zone 2 | 0.729 | 0.750 | 0.786 | 0.813 |
    | Golden 1 | 0.786 | 0.800 | 0.857 | 0.875 |
    | Golden 2 (peak) | 0.893 | 0.900 | 0.929 | 0.938 |
    | Golden 3 | 0.850 | 0.850 | 1.000 | 1.000 |

    Boss fights keep their own difficulty; the enemies they bring take their zone's last level's scaling:
    the Floating Head 0.143 to 0.125, the Sewer Swarm 0.357 to 0.313, The House 0.500 (Marketplace 2's) to
    0.563 (Casino 2's: its Barnacle Turrets reload in 2.06 s instead of 2.10 and fire bolts at 17.1 m/s
    instead of 17.0, still 5 shots to kill), Hostile Takeover 0.643 to 0.688, the Sleep Taker 0.786 to 0.813.
521. **What the re-spaced curve changes** (for the owner's choice of curve above; measured on the 15-level
    curve before the Casino, commit 74c0b5e, and on this branch):
    - **Patterns gated by difficulty** (`min_difficulty` / `max_difficulty` in `data/patterns/*.json`; a
      level's difficulty rises 0.25 across it). In the levels that got easier they come later or never: City
      2 loses `fence_mixed`; City 3 loses `cyborg_pair`, `window_cyborg_pair` and `fence_stagger` (in its
      last 6% before); Gangland 1 never reaches the main `hover_truck` pattern (only `hover_truck_rare`),
      `gap_with_fence_lane` or `ceiling_over_gauntlet` (its last 9% before); Gangland 2 loses
      `cyborg_stagger` and `screech_manhole_row`; Gangland 3 loses `fence_pulsing_all`; Marketplace 1 loses
      `drone_pair` (its last 17% before); Marketplace 2's `hover_truck`, `generator_pulsing_all`,
      `gap_with_fence_lane` and `ceiling_over_gauntlet` start 20% in (from its start before); the other gated
      patterns of these levels start 3% to 20% of the level later, and the easy ones that stop at a difficulty
      (`fence_full_single`, `fence_pulsing_single`, `hover_truck_rare`) last longer, Marketplace 2's
      `hover_truck_rare` back for its first 20%. In the levels that got harder they come
      earlier: `drone_pair` from 20% into Corporate 1 (37% before) and from Corporate 2's start (14%);
      Corporate 1 loses `fence_full_single` and `fence_pulsing_single` (its first 17% before) and has
      `fence_pulsing_all` from its start (17% in before); Golden 2's two Gilded Sentinel patterns from 20% in
      (23%).
    - **The recency curve** (a newly introduced feature's patterns weigh more in the levels right after its
      introduction): those boosts move from Corporate and the Dead Zone to the Casino. Corporate 1: Barnacle
      Turrets age 2 to 4 (weight 1.75 to 1.0), wall fences 1 to 3 (2.5 to 1.25), fence generators 3 to 5 (1.25
      to 1.0); Corporate 2: turrets 1.25 to 1.0, wall fences 1.75 to 1.0; Dead Zone 1: wall fences 1.25 to
      1.0. Casino 1 gets wall fences 2.5, turrets 1.75 and generators 1.25; Casino 2 wall fences 1.75 and
      turrets 1.25.
    - **The economy** (`tools/measure/economy.gd --lanes=5 --seeds=0 --share=0.7`): a level's completion
      bonus is 100 + 25 × its index, so every level after the Marketplace pays 50 more, and the Casino's two
      levels add theirs: a clean 5-lane playthrough's wallet (boss payouts in) goes from 14,446 to 16,874. The
      Heavy missile comes into reach after Dead Zone 1 instead of Golden 1 (the 13th level either way, now of
      17; this bears on open question 294), and Armor IV after Casino 1 instead of Corporate 1 (the 9th).
    - **Late introductions** (`test_campaign` on the levels' own seeds: a level's first piece of a feature
      that starts partway in, more than 210 m at the reference pace after that start): 3 of 63 before, 6 now.
      - Corporate 2's Enforcer Truck at 5 lanes (the Enforcer's first level): start 176 m, first at 713 m,
        about 23 s late.
      - Marketplace 2's vent screeches at 3 and 6 lanes: start 1311 m, first at 2022 and 1960 m, about 30 s
        late (at 5 lanes, late before, on time now).
      - Corporate 1's Buzz Overdrive at 6 lanes: start 339 m, first at 783 m (585 before), and only one Buzz
        Overdrive there (three before); at 5 lanes first at 1214 m (976 before, already late then).
      - Dead Zone 1's host at 3 lanes, late before and after (start 351 m, first at about 2010 m).

      Gangland 1's wall gaps, first at about three quarters of the level on every build before and after
      (WallGapPlacement's schedule), no longer count (`SPACED_FROM_START` in `tests/suites/test_campaign.gd`).
      That's principled (they're never an introduction pick), but it landed exactly as the re-spaced curve
      broke the check's 10% budget (9 of 66 with them), and the result sits at the limit: 6 of 63, and a
      seventh fails. Are these late introductions acceptable?
    - **The levels' own builds** (same seeds, new layouts). Where a level lost something it had:
      - Golden 1 at 3 lanes has room for a doodad in one stretch only, and its share (0.8) left it out.
        Placeholder: `doodad_share` 0.8 to 1.0, every stretch with room, like Dead Zone 2's
        (`data/levels/golden_1.tres`): 1/4/3 doodads at 3/5/6 lanes (1/1/2 before).
      - The final zones' danger density at 3 lanes: `test_danger_density`'s sample (Dead Zone 1, Golden 2 and
        3, each on its own seed and two others) had 30.4% more enemies with the pass before and 29.7% after,
        under the 30% floor of "about 35%". Placeholder, the owner's to set: Golden 2's and 3's dials 0.38 to
        0.39 (`data/levels/golden_2.tres`, `golden_3.tres`), 30.1%: 246 to 320 enemies, the fewest the floor
        allows (0.38's 319 is one short). The pass runs short of fair room there, not of dial: over six other
        seeds the same levels land at 29.4% before and 29.2% after. Is about 29% enough at 3 lanes in the final
        zones, or should the pass find more room there (`data/tuning/danger_density.tres`)?
      - Wider gaps in Enforcer chases (open question 357, whose "11 of 18" is older): the first chase holds one
        in 9 of the 18 level and lane builds with trucks, before the curve moved and after, but not the same
        ones. Corporate 2 at 5 lanes lost its one (a drone's barrage, fences, cyborgs and a pad fill its chase
        now), and so did Golden 2 at 3 and 6 lanes; Dead Zone 1 at 3 and Golden 1 and 2 at 5 gained one.
        `test_wide_gaps` holds Corporate 2 to one at 3 and 6 lanes (its wreck played there), 5 lanes the one
        exemption, and wherever a first chase has none it checks for a clear stretch there for a new row. That
        check (`_chase_spot`) tries only the pass's way of adding a new row, on the finished layout, and counts
        a spot only in a run of fitting starts 2 m long (a fitting stretch of one or two starts goes unseen): it
        shows that the pass missed no clear stretch, not that the chase has no room. Should every chase be
        guaranteed one, or at least the Enforcer's first level's?
      - Gangland 1 at 3 lanes has its hover truck out at 363 m and gone long before its ramps start (40% of
        the way in, 1177 m), so it has no ramp for route (a) (`HoverTruckRules`: "not before the ramps'
        start"), only route (b), as every truck in City 3 (no ramps) has; its truck was out at 1205 m before.
        `test_hover_truck` allows that for this build only. Should a level's trucks wait for its ramps?
      - `test_danger_density`'s route case (a zone doodad right past a full row in the only lane the pass's
        rows leave open, which `DangerDensity.doodad_ok` keeps doodads off): golden/1 at 6 lanes on seed 9003
        had already stopped building that way before the Casino, and no Golden 1 build at 6 lanes on seeds
        9001-9060 does now. It's re-pinned to Dead Zone 1 at 6 lanes on seed 9007 (found by building without
        `doodad_ok`), and the test now checks that its case still shows the scenario.
522. **The Casino's music** (GDD §11: no more generated songs; the owner supplies them). Placeholder: the
    Casino's track (`casino`) plays the Marketplace's: Jackpot Plaza in its levels, the Marketplace's
    generated default in its cinematics and The House's fight, and the Marketplace's level-complete riff
    (`data/audio/music_library.tres`: `files`, `zone_tracks`, `riff_tracks`). Will the owner supply a Casino
    song, and should The House get a boss song of its own?
    **Answered (owner, October 9, 2026):** `Zone_3_2_Casino_Midnight_at_the_atrium.mp3` is the Casino's
    gameplay song and The House shares it; the generated default remains for cinematics. No separate
    boss song was requested.
524. **The House's leaderboard** is now `boss/casino_boss/<tier>` (it was `boss/marketplace_boss/<tier>`). No
    platform leaderboards are registered yet (the stub serves every build); any made from the old id must use
    the new one.

**Merging main into the Casino branch** (from K5; main's C6e showing windows, PERF2, G6b and G8 met the Casino's levels and K4's curve)
536. **What the merge moved** (notes for items 401, 528 and 530; not a question)
    - **Item 401's builds** (two trucks, room for one showing; the owner: keep both): now Corporate 2 at 6 lanes
      and Dead Zone 2 at 5 and 6 lanes. Corporate 2 at 5 lanes and Dead Zone 1 at 3 lanes have one truck that
      shows itself (item 402's case). `test_enforcer_truck`'s `BOTH_TRUCKS` lists them and checks both ways.
    - **Item 440's notes:**
      - Corporate 2's first Enforcer chase now holds a wider gap only at 3 lanes (`test_wide_gaps`'
        `CORPORATE_2_CHASE_LANES`, now 3 lanes, checked both ways). Its chase leaves room past the window at 3
        and 5 lanes: at 5 lanes that stretch has no clear spot, and at 6 lanes the window comes after the bait.
        The first chase holds one in 4 of the 18 level and lane builds with trucks.
      - Corporate 2's late Enforcer introduction at 5 lanes is at 1219 m now (641 m before the merge).
      - The final zones' obstacles at 3 lanes: 30.6% in `test_danger_density`'s sample with the wall fences' share
        at 1.9 (28.8% at 1.25); over 7 seeds 31.9% (30.2%). See above.
    - **Re-pinned scenario cases** (each still shows its scenario):
      - `test_danger_density`'s route case: Golden 2 at 3 lanes on seed 9004.
      - `test_gilded_sentinel`'s case of a window cyborg on a Sentinel's wall section, without the check: Golden 3
        at 3 lanes on 9039, the only one of 240 builds on seeds 9001–9040.
      - `test_level_cache`'s Corporate 2 attempt plays at 3 lanes. At 5 lanes the attempt's weapons shoot its
        Buzz Overdrive before its charge, so no floor cut begins. The EMP now goes off at 9 s, and an attempt is
        spoiled to 1600 m.
      - `test_level_sky`: The House follows Casino 2, which has no level sky, so the fight is under the Casino's
        own.

**The Beach: its skin** (from D10; GDD §5, Zone 6 (zone 5 when it was added, before the Casino's zone 4 joined main); the owner's reference `docs/art/reference/beach_zone.jpg`; numbers in `data/skins/beach_skin.tres`, `BeachSkin`; review with `tools/showcase/skin_review.tscn -- --skin=beach`, with `--open` for the open walls and `--sky=beach_sunset`, and `splash_review.tscn`)
538. **Its place in the campaign.** The recommendation was between Corporate and the Dead Zone (zone 5 then): it breaks up the
    two night zones that ran back to back, has 11 enemy types to remix by then, keeps the sandy zones apart, and
    keeps the Dead Zone's ruins straight into the Golden Zone's opulence and its pools away from the Golden Zone's
    canals. **Answered (owner, October 9, 2026):** between Corporate and the Dead Zone, zone 6 now that the Casino is zone 4 (GDD §5; items 569–579).
543. **No words on signs.** Placeholder: wordless silhouettes (a sun, waves, a palm, a surfboard, a flamingo, a
    cocktail glass, a tiki totem). **Answered (owner, October 9, 2026):** "keep the wordless signs as they are."
544. **Time of day.** Placeholder: a bright tropical afternoon (`night_sky.gdshader`'s uniforms: a blue zenith, white
    cumulus, a turquoise sea and a low palm island; the lit walls lifted by `bc_daylight`). **Answered (owner,
    October 9, 2026):** the first level in daylight; the last with "the sun starting to set. Not dark, but the sun's
    starting to have some purples and oranges in the sky." No existing sky fitted (the Marketplace's sunset and the
    City's dawn are night-dark overhead, with stars), so `data/skies/beach_sunset.tres` is the Beach's own, on
    Sunset Strip (item 558).
545. **The cyborgs' look** (`enemy_variant`; no new enemy assets). **Answered (owner, October 9, 2026):** "reuse one
    of the existing cyborg looks, whatever fits the theme of this zone the best." The orchestrator picked
    `&"casino"`, the Casino Mob Enforcer: a mob running the bars and lounges, and the Barnacle Turret's furry
    creature look (barnacles at the beach). The base (`&"city"`) or the ceremonial enforcer (`&"golden"`) would fit
    too, if the owner prefers.
546. **The pools' depth.** Six metres down, the water hid behind the near edge from the game camera, and every pool
    read as a black pit. **Answered (owner, October 9, 2026):** "it's pretty good as it is", the water may sit a
    little closer to the rim, and a fall makes a splash (item 559). `pool_depth` is 0.45 m (range 0.4–1.2, above the
    grapple's `pit_depth` of 0.35 m, so a grappled runner never reaches the water). A fall sinks out of sight into
    the opaque water; the chase camera stays 2.4 m above the floor even at the 4 m fall death. A shallower pool
    still (0.4 m) stays an option.
552. **The wall-run band.** Placeholder: below 7.2 m (`band_top`) the shacks' faces are flush (bamboo, mats, planks,
    rusty sheets, shut shutters, wordless posters, painted boards), and the decoration (verandas, thatch, tiki masks,
    lanterns, signs, tanks) starts at 8 m (`decor_min_height`). The reference's decoration is all at street level,
    where it would break the band's calm (GDD §3).
553. **The hazard sign and fence.** Placeholder: the usual yellow/black frame around a painted surf or bar sign, and
    the usual pink field between bamboo-wrapped steel posts in sand-filled drums: the Beach's reading of the
    cross-zone hazard language, no new shapes.
557. **The shacks at a gap's ends** are closed with a timber gable (`BeachShacks.gap_end_cap`) over the standard dark
    slab; alcoves and items that would straddle a gap's end are left out. Known limit: `feed_boards()` and
    `cult_emblems()` don't know about gaps, so they may list an item a shack dropped there (only `skin_review`'s
    close-ups read them).

**The Beach: open side walls** (from D10b; the owner, October 9, 2026: the side walls should "appear about 50% of the time that they are now ... much longer sections where there aren't sidewalls"; numbers in `data/tuning/beach_wall_gaps.tres`, F6 "Wall gaps" in a Beach level; `LevelConfig.wall_gap_tuning` and the coverage mode in `WallGapPlacement`)
565. **The Beach's features** (GDD §5). Placeholder: Corporate 2's list on both levels, a remix of everything before
    the Beach, introducing nothing; it keeps the Tithe Collector and the wall-vent screeches (no manholes in sand).
    **Answered (owner, October 9, 2026):** "Do not worry about any new enemies at this time": the Beach is GDD §5's
    one exception for now.
568. **D10b's other placeholders** (its place, difficulty, names, music, boss and cinematics, and a way to play it
    outside the campaign) are answered or replaced by the owner's decision of October 9, 2026: items 569–579.

**The Beach joins the campaign** (from D10c; the owner, October 9, 2026: "put the beach between the corporate and dead zone. Keep in mind that there will be a boss battle for the beach, but it has not yet been created. Do not worry about any new enemies at this time. Create level names that fit the theme."; GDD §5, §6 and §10; `data/campaign/campaign.tres`, `data/zones/beach.tres`, `data/levels/beach_1.tres` (Tiki Tides) and `beach_2.tres` (Sunset Strip); play `--level=beach/1`)
577. **The music.** The zone's track `beach` (`data/audio/music_library.tres`; `MusicLibrary.zone_tracks`)
    previously borrowed the Marketplace's generated loop in cinematics and Jackpot Plaza in levels.
    **Answered (owner, October 9, 2026):** `Zone_Beach_Palms_at_Terminal_Speed.mp3` is the Beach's
    gameplay song; the generated default remains for cinematics. No zone-specific completion riff was requested.
579. **The Buzz Overdrive's zones** (GDD §9.9 named the Corporate zone and the two after it). The Beach's remix has it
    too, its rev a little shorter than Corporate 2's (it follows the level's enemy scaling). **Updated:** GDD §9.9
    now names the Beach, which follows from the owner's placement and the remix.

**The Gilded Sentinels' shorter warning and lit niches** (from H1, owner, October 8, 2026, GDD §9.11; numbers in
`data/enemies/gilded_sentinel.tres`)
607. **A decorative alcove that would overlap a live niche is left out** (less than 0.3 m of wall between the
    frames); facade statues no longer straddle a chunk's end (about 6% fewer outdoor decorative statues, a build
    fix). The halberd's draw-back takes the last half of the warning (0.3 s).
    - Placeholder: `GoldenSkin.NICHE_CLEARANCE` 0.3, `GildedSentinelTuning.raise_share` 0.5 (`DESIGN-TBD`).

**The Sleep Taker's October 8 changes** (from H9, owner, October 8, 2026, GDD §10; numbers in `data/bosses/dead_zone_boss_tuning.tres`
(`SleepTakerTuning`, F6 in the fight) and `data/bosses/dead_zone_boss_wall_gaps.tres`, marked `DESIGN-TBD` in
`scripts/bosses/sleep_taker/sleep_taker_tuning.gd`)
622. **When a round can't fit.** A round takes the rows that end before the next refuge's slash or lure, never fewer
    than 2 (`hand_rows_min`); otherwise it waits and the phase's next attack may go first. A clean win sees 3–4
    rounds (about 78 s, inside the three-star par of 86 s).
623. **The fairness margins rounds are planned with:** a runner moving 0.4 s after the mists show (`route_reaction`),
    a lane switch taking the real 0.14 s × 1.5 (`route_switch_margin`), the body 0.55 m past a hand either way
    (`route_body_margin`), checked by The House's lane router.
625. **"Double the floor gaps."** Once a lap's refuges are in, the generator's additive gap pass doubles the rows of
    holes the fight has (`floor_gap_increase` 1), keeping their average width: over three laps 11 → 22 rows at 3 and
    5 lanes, 8 → 16 at 6 (lane-gaps 15 → 30, 26 → 53, 24 → 50). New rows keep 1.3 s of run from everything else
    (`floor_gap_spacing`; the arena's own 1.9 s fits only 1.6–1.8 times as many).

**Dash walls, the mechanism** (from H7a, owner, October 8, 2026, GDD §9.14; numbers in `data/tuning/dash_walls.tres`, `MovementTuning` and
`SpeedFxTuning` "Dash walls", `LevelConfig.dash_walls`)
651. **The wall's size and the wall runners' strip** (GDD §9.14: "it blocks only the floor; a player running on a side
    wall passes it"). Placeholder (`MovementTuning`, "Dash walls"): 9 m tall (a wall jump's feet reach about 5.3 m),
    2.5 m deep, its sides 1.2 m short of each side wall's face (`dash_wall_wall_room`), its hitbox 0.15 m inside its
    look at its sides and its face (`dash_wall_inset`), from 5 cm above the floor (a slide never passes under it).
    A runner in the outer lane meets it; one on the side wall clears its hitbox by about a quarter metre and passes.
    At least one side wall is kept open beside it for `wall_route_seconds` (0.6 s) before its face: no sign (one on
    each side has those of one side taken out), and no wall gap or wall fence on either.
654. **The hover truck** (GDD §9.3 with §9.14; the brief asked for the simplest fair rule). Placeholder: it gives way:
    a standing wall coming within the time it needs to drop behind the runner sends it into its lurch back, and it
    holds back, revving for no forward lurch, until the runner has broken the wall (`HoverTruck._wall_ahead`); its
    cannon holds fire near a wall. Where it can't drop back (the runner in its lane behind it, ridden, leaving ahead),
    it bursts through the wall as it burst out of the building (broken by `hover_truck`). The generator keeps walls off
    its entrance only. Why: the runner always meets the wall themselves (the truck never takes the challenge away),
    and nothing new is asked of the truck but a move it already makes.
655. **The Enforcer Truck** (GDD §9.13). Placeholder: nothing; it drives behind the runner, so it only meets a wall
    already broken, and its volleys never start with a wall in the escape (as with a doodad). *(Since the merge with
    tasks C6b–C6d, October 9, 2026: when it shows itself it pulls up beside the runner, its front ahead of them, so
    walls keep off its planned showing windows and in play it never shows itself where its view would reach a wall.)*
657. **The look** (GDD §9.14: "the same assets as the side walls, turned to face the player"; task H7b). Placeholder:
    every skin's default look is a plain three-storey facade (pilasters, floor slabs, a plinth and a cornice, dark
    windows, a few shuttered ones, cracks across the ground storey) in colours from the zone's own side walls
    (`ZoneSkin.dash_wall`, `dash_wall_colors()` per skin), lit by the zone's kit material. No cue in the dash's
    colour yet. H7b replaces it with each zone's side-wall kit.

**Dash walls, the art** (from H7b, owner, October 8, 2026, GDD §9.14; each zone's `*_dash_wall.gd` and `scripts/world/skins/dash_wall_kit.gd`)
667. **Roof plant and finials** (`DashWallKit.ROOF`, 1 m of the box's height): the building's own top is 1 m under the
    box's, and what stands on it (air handlers, urns, a mast) fills the rest, so the silhouette isn't a flat box. The
    hitbox still reaches the box's top, so a flyer's lift (`Enemy.dash_wall_lift`) clears the plant too.

**Merging main's Casino into the H series** (October 10, 2026: K1-K5, the Casino zone and K4's curve, meet the H series)
679. **What the Casino merge moved** (notes; not a question)
    - **Re-pinned scenario cases** (each still shows its scenario, checked both ways):
      - `test_danger_density`'s route case: Golden 3 at 3 lanes on seed 9019 (main's Golden 2 at 3 lanes on 9004 no
        longer builds that way with the H series), found among 396 seeded builds.
      - `test_gilded_sentinel`'s case of a window cyborg on a Sentinel's wall section without the check: Golden 3 at 3
        lanes on seed 9024 (main's 9039 no longer builds that way). Without the check, 54 of Golden 2's and the
        Palace's 720 builds on seeds 9001-9120 now show the problem (main: 1 of 240 on 9001-9040); with it, none
        of them does.
      - `test_level_cache`'s smash-and-retry attempt plays Golden 1 at 3 lanes (Dead Zone 1 has no doodad in its
        starting lane before its first wall on K4's curve).
    - **Corporate 2 at 3 lanes on seed 7101** gets its wall from the last resort (item 677), and Corporate 1's
      introduction at 5 lanes is late (item 676).

**Merging main's Beach into the H series** (October 10, 2026: D10, the Beach as zone 6, meets the H series)
682. **What the Beach merge moved** (notes; not a question): `test_enforcer_truck`'s `BOTH_TRUCKS` (item 401's case,
    two trucks with room for one showing, both kept) adds Sunset Strip at 5 lanes, with the H series; Tiki Tides at 5
    lanes stays. The Beach's doodads tag their main colours for the dash's smash (task H5), as every zone's do.

### Answered by the owner on October 14, 2026
Moved here from `docs/OPEN_QUESTIONS.md`, each with its answer; the GDD records them.

**Campaign restructure** (from B1: six zones, 15 levels)
16. **The economy over 15 levels** ("From the full build" items 10–11). Completion pays 100 + 25 per campaign
    level, so Golden 3 pays 450; prices were set for a two-zone campaign. Needs a balancing pass.
    **Answered (owner, October 14, 2026):** Yes, rebalance the shop prices (and the payouts) for the full campaign (GDD §7). Queued in `docs/USER_REQUESTS.md`.

**Cinematics** (from F1; review with `tools/showcase/cinematic_review.tscn`, or play `--level=city/intro`, `--level=city/boss_intro`; numbers in `data/cinematics/`)
238. **The arrival flyovers' story beats** (GDD §1: a light story told through the zones and 5–15 second
    cinematics; the owner describes the beats later, task F2). What should each zone's intro show, and should
    the intros share one form?
    - *Placeholder:* one arrival flyover for every zone's intro slot (`scripts/cinematics/arrival_flyover.gd`,
    `ArrivalFlyover`, marked DESIGN-TBD; numbers in `data/cinematics/arrival_flyover.tres`). 9.5 s: the camera
    opens low in the street looking up at the zone's skyline, tilts down as the runner runs in beneath it,
    glides over the street behind them, and settles into the run camera's view as they run under one of
    the zone's ceilings; the zone's music comes in; it fades to black and the level opens on the same view.
    Built in the zone's own skin, taken from the zone's data.
    **Answered (owner, October 14, 2026):** The owner will describe the zones' arrival cinematics in a later session; the shared flyover stands until then (GDD §6).

**Lag spikes** (from PERF1; numbers in `data/tuning/speed_fx.tres` and `data/tuning/performance.tres`, F6; the frame-time graph is F7 in debug builds, or `--frame-graph`)
330. **A level's start** (GDD §4, the flow into a run). A level is generated and built in the frame after
    the player picks it (0.3 to 1.8 s on the dev machine, the first level of a session the longest), and
    now also readies what it will need later instead of hitching mid-run (its enemy types' scripts and
    looks, 0.1 to 0.9 s more on the dev machine the first time in a session, and on a real renderer its
    shaders, drawn once in its first frame); a phone takes several times longer. The level select holds
    still meanwhile, then the run starts at once. Should a level open behind a short loading card (the
    zone's name on its colour, shown while it loads), or stay as it is?
    - **Placeholder:** no loading card; the screen holds still until the run starts, as before.
    **Answered (owner, October 14, 2026):** No loading card (GDD §6).

**Hostile Takeover, phase 2: The Contract** (from E5b-b; numbers in `data/bosses/corporate_boss_tuning.tres`; play `--boss=corporate_boss --phase=2`, measure with `tools/measure/hostile_takeover.gd`)
336. **Weapons ending a phase** (GDD §10, the Floating Head: "weapons chip away slowly (tuned so even the
    best weapon saves at most one stomp over the whole fight)").
    **Question:** should weapons be able to end a boss's phase (saving one stomp, as the Floating Head's
    rule says), or should only stomps end phases? And should that be decided per boss?
    **Placeholder:** `BossDef.weapons_can_end_phase`, checked in `BossEncounter.damage()`. It is on for
    every boss (the behaviour so far, The House included: a 0.34 cap over three phases of a third each). It
    is off for Hostile Takeover (`data/bosses/corporate_boss.tres`), whose weapons chip a phase only to just
    above its end. Damage carries from one phase into the next. So a runner who chipped a phase to its floor
    starts the next one a hair above that one's end. In the preview, one stomp then ends phase 3 instead of
    three; phase 3 itself (task E5b-c) can decide how its hits count.
    **Alternative:** on everywhere (weapons may save a stomp in every fight), or off everywhere.
    **Answered (owner, October 14, 2026):** Yes, weapons may end a phase, set per boss as built: on for every boss but Hostile Takeover (GDD §10, General).

**The Neon City's outro** (from F2a; the owner's beats, GDD §6 Cinematics; numbers in `data/cinematics/city_outro_tuning.tres`, code in `scripts/cinematics/city_outro.gd` and `city_outro_set.gd`; review with `tools/showcase/cinematic_review.tscn -- --slot=city/outro`)
379. **The web demo.** The demo ends after Zone 1, and the outro belongs to Zone 1, so the demo plays it (Gangland's
    landing included) before the store-link screen, a teaser for Zone 2. Wanted, or should the demo go straight to
    the store links (GDD §10's wording could be read that way)?
    **Answered (owner, October 14, 2026):** Yes, the demo plays the Zone 1 outro before the store links, as built (GDD §2).

**Gangland's boss intro** (from F2b; the owner's beat, GDD §10 Sewer Swarm "Intro cinematic"; numbers in `data/cinematics/sewer_swarm_intro.tres`, code in `scripts/cinematics/sewer_swarm_intro/`; review with `tools/showcase/cinematic_review.tscn -- --slot=gangland/boss_intro`, or play `--level=gangland/boss_intro`)
395. **Slots.** This answers part of items 11 and 200: Gangland now has a boss intro as
    well as the City. Should the other zones' bosses get one?
    **Answered (owner, October 14, 2026):** Give every boss a slot for an intro cinematic; the owner decides later whether to fill them (GDD §6). Queued in `docs/USER_REQUESTS.md`.

**The Golden Convergence: the polish pass** (from the review of E5d-a, b and d; built in the polish pass after the fight's review. Numbers are in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight) or constants marked `DESIGN-TBD` in code, as each item says)
483. **The armor pickup after a shield break** (GDD §10, Armor pickups: "triggered when the player has lost all
    their armor"). The boss framework schedules the 22 s armor pickup when the shield breaks too, while the runner
    still wears armor: `BossEncounter._on_item_used` answers both items, and the player reports the shield on every
    break but the armor only once it's gone. With one pickup a phase (`armor_pickups_per_phase`), a shield break
    uses up the phase's pickup, so an armor break later in that phase brings none. Is this more generous timing
    wanted, or should only losing the last of the armor schedule it, as the GDD reads? (Changing it changes the
    framework, so every boss with the armor rule.)
    **Answered (owner, October 14, 2026):** No. Only the armor taking a hit schedules the pickup, not a shield break (GDD §10, standard armor rule). Queued in `docs/USER_REQUESTS.md`.

**The Beach joins the campaign** (from D10c; the owner, October 9, 2026: "put the beach between the corporate and dead zone. Keep in mind that there will be a boss battle for the beach, but it has not yet been created. Do not worry about any new enemies at this time. Create level names that fit the theme."; GDD §5, §6 and §10; `data/campaign/campaign.tres`, `data/zones/beach.tres`, `data/levels/beach_1.tres` (Tiki Tides) and `beach_2.tres` (Sunset Strip); play `--level=beach/1`)
576. **The cinematics** (GDD §6). Placeholder: `beach_intro.tres` ("The Beach") plays the arrival flyover in the
    Beach's look, its card "ZONE 6 · Beach"; `beach_outro.tres` ("Last light") is a placeholder card (after the
    boss, as the sun goes down, heading for the Dead Zone); Corporate's outro card now heads for the Beach. The
    beats are still to come; the Dead Zone and the Golden Zone now show as zones 7 and 8 on their cards. The Dead
    Zone's intro (task F2c, GDD §6) opens on the runner lying in a smoking crater, put there by "a cinematic before
    this one": with the Beach in between, that is now the Beach's outro, not Corporate's.
    **Answered (owner, October 14, 2026):** The owner will add the Beach's cinematics in a later session; the placeholders stand until then (GDD §6).

**The Gilded Sentinels' shorter warning and lit niches** (from H1, owner, October 8, 2026, GDD §9.11; numbers in
`data/enemies/gilded_sentinel.tres`)
608. **GDD §9.11 no longer matches the build in one place** (predates H1): "decorative statues never stand at wall-run
    height". Since the owner's earlier request, decorative statues stand in alcoves at the bottom of the walls,
    0.1–3.5 m up, which is wall-run height; they're told from live ones by the red eyes and the warning. Should
    the GDD line change to match?
    **Answered (owner, October 14, 2026):** Yes, the GDD now matches the build (GDD §9.11).

**Merging main's Beach into the H series** (October 10, 2026: D10, the Beach as zone 6, meets the H series)
680. **No dash walls in the Beach, for now** (GDD §9.14: introduced in the Corporate zone "and in the zones after it";
    GDD §5, the Beach as zone 6 between Corporate and the Dead Zone, task D10). The Beach's levels (Tiki Tides and
    Sunset Strip) don't have the `dash_wall` feature: its side walls stand open on about half of a level (task D10b),
    where a dash wall's route ("a player running on a side wall passes it", with at least one side wall standing
    beside it) would rarely be there, and it has no wall look of its own (task H7b: each zone's building face turned
    to the player; the Beach's skin keeps the default box). Placeholder (the coordinator's call, October 10, 2026):
    none there; `test_campaign`'s `LEFT_OUT` lists the Beach for `dash_wall`, `test_beach_levels` takes Corporate 2's
    features but its dash walls, and `test_dash_walls`' skin contract keeps the Beach on the default look
    (`DEFAULT_LOOK_SKINS`). Should the Beach get dash walls, and how do they meet its open side walls (standing only
    where a side wall stands beside them, or with no wall route at all), and in what look (a beach bar's front)?
    **Answered (owner, October 14, 2026):** Keep the Beach's walls as they are: no dash walls in the Beach (GDD §9.14).

**The web demo** (from E2; export and check it with `tools/godot.sh web`, README "The web demo"; the demo is City 1–3 and the Floating Head, then the "get the full game" screen)
231. **The portals' rules on outbound links** (GDD §2: itch.io, possibly Poki or CrazyGames; "check each
    portal's rules on outbound links"). I couldn't read the rules: this build machine's network policy blocks
    itch.io, docs.crazygames.com, developers.poki.com and sdk.poki.com. For each portal the demo goes to:
    - **itch.io:** the demo's own page, where links to Steam, the App Store and Google Play are the usual
    thing. Do you want its end screen as it is (three store tiles)?
    - **Poki** and **CrazyGames:** do their rules allow links out of the game to other stores at all, only to
    some (for example the game's own Steam page), or none? Do they ask for their own SDK (their ads, their
    analytics, a "game loading/started" call) even in a game without ads? Is there a size or loading-time
    limit the demo must meet (it downloads about 14 MB compressed, see the report)?
    Placeholder: one build for every portal, with the three store tiles; the store links open through the
    platform layer (`Platform.open_store()` → `PlatformBackend.open_url()`), so a portal that forbids them
    gets a backend of its own that hides or disables the tiles, without touching the game.

    **Recommendation (October 14, 2026):** itch.io first, as built. CrazyGames later, if wanted:
    its rules allow a link to the game's own store page (Steam, Epic) on desktop at the end of a demo or in the main
    menu, as long as it isn't the main call to action; no cross-promotion otherwise. That needs a Steam-only end
    screen there. Skip Poki: it is curated, blocks requests out of the game unless they go through its SDK, and its
    traffic earns through its ads, which the demo doesn't have.
    **Answered (owner, October 14, 2026):** the recommendation, as above (GDD §2).

### The Beach's boss, designed and built (task E5e; filed on October 14, 2026)
Item 575 moved here from `docs/OPEN_QUESTIONS.md` once the fight was designed and built. After it come the owner's
answers from the fight's design session, items 749–765 (the session's items were numbered 683–700 on the task's
branch; its last, 766, waits on the owner in `docs/OPEN_QUESTIONS.md`), and the two questions task E5e's steps
raised that are answered or superseded, items 783 and 788 (from task E5e's questions file; the rest of items
767–824 are deferred, in `docs/OPEN_QUESTIONS_DEFERRED.md`). The GDD records the design (§10, Mecha Guppy and
Captain Cogs).

**The Beach joins the campaign** (from D10c; the owner, October 9, 2026: "put the beach between the corporate and dead zone. Keep in mind that there will be a boss battle for the beach, but it has not yet been created. Do not worry about any new enemies at this time. Create level names that fit the theme."; GDD §5, §6 and §10; `data/campaign/campaign.tres`, `data/zones/beach.tres`, `data/levels/beach_1.tres` (Tiki Tides) and `beach_2.tres` (Sunset Strip); play `--level=beach/1`)
575. **The boss** (GDD §10: "there will be a boss battle for the beach, but it has not yet been created"; task E5e,
    blocked on design). Placeholder: `data/bosses/beach_boss.tres`, "The Beach's boss", unbuilt: the campaign shows
    its placeholder card and passes through it to the Beach's outro and the Dead Zone, with no stars. Its fight,
    name and payout are to be designed. When it's built, `test_app_flow` and `test_screens` need another unbuilt
    stand-in for their placeholder-card checks.
    **In progress (owner, October 14, 2026):** the owner is designing the Beach's boss in another session.
    **Answered and built (owner, October 10–11, 2026; task E5e):** Mecha Guppy and Captain Cogs, a giant
    mechanical shark and a flying pirate, in a climb (GDD §10). Its design answers are items 749–765; the build's
    placeholders, its payout among them, are items 767–824. `test_app_flow` and `test_screens` now check the
    placeholder card on an unbuilt stand-in in its slot (a copy of its `BossDef` with no scene).

**The Beach's boss: the design session** (the owner with Claude, October 10, 2026; GDD §10, Mecha Guppy and Captain Cogs; task E5e)
749. **The way up: ceilings, to confirm** (GDD §10, The Beach's boss, The climb). The owner proposed two ways up:
    anti-grav pads to ceilings that drop the runner onto higher floors, or side walls standing in the lanes, climbed by
    wall hops from wall to wall. The owner's answers on October 10, 2026 (the wrong ceiling lane, ceiling riders and
    the bombs) follow the ceilings, so the GDD records them, marked *(to confirm)*. Claude's feasibility notes (task
    E5e in `docs/TASK_PLAN.md`): the ceilings reuse pads, partial ceilings and landing on raised floors; the side-wall
    climb needs the wall system rewritten (walls stand only at the track's two edges, a wall run slides down, and the
    wall hop holds a runner at about 4.5 m but never climbs). A cheap mix: a run up an edge wall, then a wall jump onto
    a higher roof, as onto the Floating Head in its phase 2. Ceilings only, or ceilings with edge-wall steps?
    **Answered (owner, October 10, 2026):** ceilings only. Nothing for walls in the lanes was built, and the owner
    doesn't want their cost in time, code complexity and maintenance (GDD §10, Mecha Guppy and Captain Cogs, The
    climb).
750. **The name** of the fight, the shark and the pirate.
    **Answered (owner, October 10, 2026):** the shark is **Mecha Guppy** and the pirate **Captain Cogs**. The fight's
    own title is item 762.
751. **Phases and length** (GDD §10: 60–120 seconds; death restarts the fight). How many phases, and what changes in
    each? Claude's suggestion, not decided: phase 1 ceilings, phase 2 edge-wall steps, phase 3 both, each phase a
    little faster, as at the other bosses.
    **Answered (owner, October 10, 2026):** three phases. Phase 1: the climb, dodging bombs, 4 hits. Phase 2: the same
    with more bombs and a climb 15–25% faster, 6 hits. Phase 3: the runner reaches the top, level with Captain Cogs,
    whose ship fires rounds dodged by switching lanes while waves crash over lanes to jump; after a minute of dodging,
    Mecha Guppy leaps over and eats the captain. Placeholder *(proposed)*: about 20% faster, by bringing the steps closer
    together (the run speed stays the zone's).
752. **The bombs' warning** (GDD §3 and CLAUDE.md: every attack has a visual and an audio warning). Reuse the Floating
    Head's (a red target circle where a bomb will land and a falling whistle), with a pirate look on the bombs? How
    many bombs at once, and how often?
    **Answered (owner, October 10, 2026):** reuse the Floating Head's warning (the red target circle and the falling
    whistle) in a pirate look.
753. **Bombs on a ceiling rider** (owner: ceiling riders aren't safe from them). How does a bomb reach a runner hanging
    under a ceiling, and where is its warning drawn (on the ceiling's underside, above the rider's head)? For example,
    the ship flies ahead below the ceiling's line and lobs them in, or the bombs burst through the ceiling.
    **Answered (owner, October 10, 2026):** for now, a ceiling rider with the ceiling between them and a bomb isn't
    hurt by it. The owner doesn't want ceilings to be too safe (item 766).
754. **The shark's bites** (GDD §10: its maw comes up through the floor and eats a huge chunk of the level). Where and
    when does it bite: ahead of the runner, behind them, under floor they've left, under the floor they're on? If a
    bite can catch the runner, it's an attack and needs its warning and a way to dodge (a rumble, churning water,
    cracks spreading). If it only eats floor the runner has left, it kills only a runner who drops back down.
    **Answered (owner, October 10, 2026):** it eats the floor the runner should have left. A runner who drops off the
    ceiling in the wrong place falls back down to where it is eating, which kills them. It is mechanical and doesn't
    glow red (its eyes are item 763).
755. **How many hits** ("many") end the fight, and does anything else hurt the shark? Weapons chip every other boss,
    and every other boss also has a big hit (a stomp on a glowing red weak point). Is it bombs only?
    **Answered (owner, October 10, 2026):** phase 1 ends after 4 bomb hits, phase 2 after 6; phase 3 after the player
    has dodged attacks for one minute. Weapons do no chip damage in this fight.
756. **The pirate bomber's fate.** Can it be hurt or beaten, or is it out of reach for the whole fight? Does it
    appear in later levels (GDD §5: "Anything introduced earlier keeps appearing later"), or only in this fight?
    **Answered (owner, October 10, 2026):** Captain Cogs is only in this fight: Mecha Guppy eats the captain at the end
    of phase 3. The player never hurts the captain.
757. **The last-ditch saves** (owner: a wall to cling to, or the grapple). The grapple today pulls a runner back up out
    of a pit to the street's level; in the climb it would have to pull them back onto the roof they fell from. A wall:
    GDD §3's entry grace says a runner already falling into a gap can't get onto a wall, but this fight lets a falling
    runner catch one. How late may they catch it, and where do walls stand in the climb? The wall hop (GDD §3) lets a
    runner stay on a wall as long as they like: do the bombs reach wall runners, so a wall isn't a place to wait out
    the fight (item 417's concern)?
    **Answered (owner, October 10, 2026):** only occasional side walls, here and there, never the climb's full length,
    as a last-ditch save that should rescue a player about 20% of the time; Mecha Guppy eats them too, like the
    floors. If that's too complex to build, the fight has no walls.
758. **Reading the lanes.** On a ceiling, the camera sits under it looking up. How does the player see which lanes
    lead to the higher roof before the ceiling ends: the roof in plain view ahead, a marking on the ceiling, or
    something else?
    **Answered (owner, October 10, 2026):** either the ceiling lanes that lead up run further than the others, or one
    or two of the roof's lanes reach further back toward the runner than the others; the two cues alternate.
759. **The arena's looks.** What forms the ceilings (the Beach's skin uses footbridges, verandas and a party barge)?
    Do the neon signs on the roofs stay out of the lanes as scenery, or stand in lanes as obstacles? Daylight or
    sunset (the fight follows Sunset Strip, whose sun is setting, and comes before the outro, "Last light")?
    **Answered (owner, October 10, 2026):** the ceilings are tiki huts; the neon signs are scenery only, with no
    effect on play; daylight. The backdrop is a waterfall in phases 1 and 2 and the Beach's normal one in phase 3.
    **Changed (owner, October 10, 2026):** (later the same day) the sky is Sunset Strip's setting sun after all, as
    the rule for the boss after a level gives (GDD §5); and the fight may run longer than the usual 60–120 seconds.
760. **3 lanes against 5–6** (lane count is a parameter). How many of a ceiling's lanes lead up on each?
    **Answered (owner, October 10, 2026):** one ceiling lane leads up on 3 lanes; on 5–6 lanes, one, two or three,
    alternating. One safe place to drop to is enough.
761. **Pickups, granted items, rewards and the defeat.** The standard armor rule (15–17 seconds)? What happens to
    the shark and the pirate when the fight is won?
    **Answered (owner, October 10, 2026):** the standard armor rule. The defeat: Mecha Guppy has eaten Captain Cogs
    and swims away.
762. **The fight's title** (GDD §10). The owner named the shark Mecha Guppy and the pirate Captain Cogs. Placeholder:
    the boss slot, its card and the boss bar read "Mecha Guppy and Captain Cogs". Should the fight have a title of its
    own?
    **Answered (owner, October 10, 2026):** yes, the title is "Mecha Guppy and Captain Cogs".
763. **Mecha Guppy's eyes** (GDD §10). First pictured as red eyes ("or whatever eyes make sense"); the owner then said
    the shark is mechanical and doesn't glow red. Placeholder: dark red lenses that don't glow. Do you want another
    colour, or lit eyes in a colour that isn't red?
    **Answered (owner, October 10, 2026):** yes, dark red lenses that don't glow.
764. **Phase 3's warnings** (GDD §10, Phase 3; every attack has a visual and an audio warning). Placeholder: Captain
    Cogs' rounds warned by red lines down the lanes they'll hit (the boss's lane warning) with a cannon's charging
    sound; a wave warned by a rising swell and a roar, jumped like the Resonator's ring (GDD §9.10). Are these right?
    **Answered (owner, October 10, 2026):** yes, as the placeholders describe.
765. **A checkpoint before phase 3?** Death restarts a boss fight (GDD §10; only the final boss has a checkpoint), and
    phase 3's minute comes last, so a death late in it replays the whole fight, about two minutes. Placeholder: no
    checkpoint, as at every other boss.
    **Answered (owner, October 10, 2026):** agreed: no checkpoint.

**E5e, Mecha Guppy and Captain Cogs: Raised by E5e-b2 (the shark, the pirate, the bombs and the hits)** (from task E5e's questions file)
783. **How the hits come** (GDD §10: only a bomb that falls through a gap, off a roof's edge or into a
  stretch the shark has eaten through, where it's clearly exposed and in the line of fire; "aim the bombs
  so a runner who dodges well lands hits steadily"). Placeholder (`MechaGuppyPattern._hit`, `hit_spot`,
  DESIGN-TBD): on every step, at the hut's deadline (when every rider is committed), Captain Cogs throws a
  bomb at the chasm in front of the higher roof, beside the lanes that lead up on the side with more
  lanes that don't (`hit_back` 6.8 m before that roof's front; `hit_seconds` 0.65 s of flight, its circle
  and whistle as every bomb's), and Mecha Guppy rises there to eat, its jaws open as the bomb comes down
  into them: a hit. So a runner who keeps climbing (who dodges well enough to survive the step) lands one
  hit a step: 4 steps end phase 1 and 6 phase 2. The clean bot's phase 1 ends at about 24-26 s and phase 2
  about 29-32 s later. Is "one hit a step" the owner's steady hits? The alternative (hits only when bombs
  aimed at the runner happen to miss past an edge) would make hits depend on luck and on dodging badly.
  **Answered (owner, October 11, 2026): bait the bombs.** Captain Cogs' bombs lock onto the runner's lane; a
  runner who dodges one at a roof's end or a pier's open side sends it past the edge into Mecha Guppy's jaws,
  a hit, the way the Floating Head's laser is baited into a tower. A player who doesn't manage it still
  progresses, more slowly: Captain Cogs sometimes misses into the chasm anyway (GDD §10). Built by E5e-b3 (see
  "Raised by E5e-b3"): the "one hit a step" above is now the fallback, after `fallback_after` steps without a hit.
788. **The bombs a step, and phase 2's "more bombs"** (GDD §10: the bombs warned like the Floating Head's;
  phase 2 the same with more bombs). Placeholders (`MechaGuppyTuning`, "Captain Cogs' bombs"):
  - The Floating Head's warning: a red circle at the floor's height from the throw, a whistle, 1.1 s from
    the throw to the landing (`lock_seconds`); its salvo rules for the spots (a lane to dodge into always
    reached in time, never off a pier's side, never under a hut, never on a pickup). The circles never show
    before the hut's deadline (so they never hint at the lanes that lead up).
  - Phase 1: a volley of two spots on the higher roof's run each step (one or two bombs a spot on 3 lanes,
    two or three on 5-6), 2.3-3.5 bombs a step.
  - Phase 2: one spot on the roof's run, a landing spot where riders come down (dodged in the air off the
    hut's end), and two bombs on the hut over a rider, which burst on its top (the owner's rule: the
    ceiling between them shields a rider), 4.3-4.5 bombs a step. The hut's bombs show no circle (nobody can
    stand there) and a rider under the hut only hears and feels them. Are harmless hut bombs part of the
    owner's "more bombs", or should phase 2 put more on the roofs instead? **Superseded by E5e-b3** (E5e-b2's
    review: the hut bombs were harmless and unseen, and phase 2 had fewer bombs to dodge than phase 1): the hut
    bombs are gone, and phase 2 has more bombs that can reach the runner (see "Raised by E5e-b3").

**F2e, the Beach's outro** (from `docs/questions/f2e.md`)
862. **Its length** (GDD §1 and §6: "5–15 second cinematics"). Built at 39.6 s, to give the owner's many beats time.
  **Answered (owner, October 15, 2026):** "I am okay with this movie being a little bit longer than the others."
  Their follow-up the same day is built too: the bartender no longer stretches his arm back to point at the menu
  behind him; he turns to it "like a human would", points, and turns back to them.


**Answered (October 16, 2026, the batch of October 15): wall-run gaps (J2) and the shark bite's water (J3)**
864. **How often.** How many a level, and how should that rise through the campaign? (GDD §5, Level schedule.)
   Placeholder: about one per 70 s of run at difficulty 0 to one per 40 s at difficulty 1 (`spacing_seconds_easy`,
   `spacing_seconds_hard`), each placed within 40 s of a seeded spot (`search_seconds`), at least 15 s between two
   (`min_spacing_seconds`), at least one in every level with the feature. Measured over the campaign's own seed and two
   more at 3, 5 and 6 lanes, a build has on average 1.9 in the Marketplace (one in Marketplace 1), 2.6 in the Casino,
   2.3 in Corporate, 2.1 on the Beach, 2.0 in the Dead Zone and 1.5 in the Golden Zone, where the levels are most
   crowded and fewer fit than the numbers ask for (3 to 4); 15 of those 117 builds had one give way to a wider gap or a
   dash wall (item 10). So the latest zone has the fewest, the opposite of "especially in later zones". Asking for more
   there doesn't help: the Golden Zone's and the Beach's builds already ask for 3 to 4 and fit fewer (the Beach's open
   walls leave few lit walls whole). Should more room be made for them there, and at what cost? Taking a big encounter
   out for every one, not only a level's only one (item 8), would take Resonators and Gilded Sentinels out of the
   Golden Zone (Golden 2 is "Sentinel Row"); letting them win over the wider gaps and the dash walls (item 10) would
   leave those levels short of their own counts (GDD §9.13, §9.14); and more of them takes more of the room the
   danger density pass fills at 3 lanes (item 12). None of that is done yet.
  **Answered (owner, October 16, 2026):** Keep the Beach's and the Golden Zone's wall-run gaps as built (the fewest of any zone, because those levels are crowded); no encounter is taken out to fit more.
865. **Where they start.** From which level? (GDD §5.)
   Placeholder: from halfway into Marketplace 1 (`data/levels/marketplace_1.tres`, `feature_starts` 0.5), and in every
   later level (the Casino, Corporate, the Beach, the Dead Zone, the Golden Zone and the Golden Palace); never in the
   City or Gangland, a boss arena or quick play. Endless mode has them from the Marketplace zone on (it plays a zone's
   last level). The first one comes where its whole clear stretch fits past the start: 5 to 26 s after it in
   Marketplace 1's own builds (`test_campaign` counts it with the wall gaps, `SPACED_FROM_START`, not among the
   introductions that land right after their start). This goes against GDD §5's "each level introduces about one new
   thing": Marketplace 1 already introduces the Barnacle Turret (from a tenth of the way in), so it now brings two new
   things. Should the wall-run gaps start in a level of their own instead, and which?
  **Answered (owner, October 16, 2026):** Fine as built: Marketplace 1 introduces a second new thing beside the Barnacle Turret. "It is fine to conflict with that. We're going to introduce more than one or two new things per level."
875. **Where the water lies.** Placeholder (`MechaGuppyBiteWater`, DESIGN-TBD): from each top bite's snap, the sea at the
   bottom of its hole, at the same surface and in the same look as the water beside the top (`MechaGuppyTop.water_y`,
   1.2 m under the deck; the backdrop's sea shader in `sea_mid_color`). It covers the whole crescent, and 6 m past each
   of its ends under the eave, and runs out through the bitten side under the water beside it, so the hole reads as
   bitten through to the sea Mecha Guppy swims in. The water is a look only: phase 3's timing, hitboxes and falls are
   unchanged. A runner who falls into the hole still falls through the water, with no splash (unlike the Beach's
   pools). Is the sea just under the deck right, or should the hole look deeper? Should a fall into it splash?
  **Answered (owner, October 16, 2026):** Closed: "the way it looked with my first playtest was fine"; the water stays as built.
876. **A gap should still read as deadly** (§3: safe things look safe). The Beach's pools are deliberately dark, so a gap
   reads as a hole; this water is the sea's bright turquoise, 1.2 m down. The bite keeps its red warning and the
   eaten edge's orange lip. Is bright water at the bottom of a deadly gap acceptable, or should it be darker?
  **Answered (owner, October 16, 2026):** Closed with 875, as built.
877. **Only the top's bites?** Placeholder: phases 1 and 2's floor bites and the climb's chasms (phase 3's last steps
   before the top included) are exactly as they were (the owner: "still works great"). They still open onto the haze,
   or onto the street's dark water low down. Should they show water too?

### Folded on October 16, 2026 (task K1, the Bad Dream slashes a ceiling rider)
  **Answered (owner, October 16, 2026):** Closed with 875, as built.

### Folded on October 16, 2026 (task K2, the Sentinels on the wall face)

885. **A high relief, flat to the wall.** ANSWERED by the owner's approval of the frames (October 16, 2026: "They look good"):
   the relief stands. Placeholder (DESIGN-TBD, now the owner's look): both kinds of statue are squashed along the wall's normal
   to 0.4 of their depth (`GildedSentinelTuning.statue_relief`, read by `GoldenSkin.decorative_statue_relief()`: the live
   one is the decorative one with its eyes lit), the live one's front 0.008 m behind the face (`statue_inset` 0.02 m times
   the relief) and a decorative one's 0.02 m (`GoldenSkin.statue_base_inset`, was 0.10 m), in niches 0.4 m deep (was
   0.78 m; the decorative alcoves went from 1.56 m to about 0.44 m) and 2.0 m wide (the live one was 1.8 m, so one less
   tell). The live statue's rest pose is now the decorative guard (the halberd's blade turned along the wall), and the
   decorative vigil and salute poses were reworked to keep their blades and hands close to the body. From 20 m on five
   lanes 89% of the live statue shows (was 44%) and 68 to 73% of a decorative one (was 3 to 16%).
