# Open Questions & Remaining Design Topics

Companion to `GDD_CHECKPOINT.md`. The design phase is complete when this list is empty or every item is explicitly deferred.

## A. Next design rounds (in recommended order)

### 1. Zones (highest cost driver: do next)
- ~~Full list of 6+ zones: name, visual theme, and mood.~~ Answered: six zones: City, Gangland, Marketplace, Corporate, Dead Zone, Golden Zone, in that order, with moods and palettes (GDD §5).
- ~~Which zone is first (the demo zone)?~~ Answered: Neon City is Zone 1, Gangland is Zone 2 (GDD §5).
- ~~The **floor skin** for each zone~~ Answered (GDD §5).
- ~~**Levels per zone**~~ Answered: 3 / 3 / 2 / 2 / 2 / 3, 15 in all (GDD §5).
- ~~**What forms the ceiling in zones without spaceships?**~~ Answered: every zone has ceilings, made of different things per zone, and they may be narrower than the full floor (GDD §3, §5).
- ~~**Narrow ceilings**~~ Answered: lane switching within the ceiling's width; a one-lane ceiling is short and relatively safe; the floor under any ceiling may be dangerous, with a safe landing zone (GDD §3).
- **Wall skin** for each zone, and what "signs" look like there.
- ~~The **enemy introduction schedule**~~ Answered level by level (GDD §5). Still open: which zone introduces the owner's planned **ceiling turret**.
- ~~Whether each zone introduces a new mechanic or object~~ Answered: at least one new enemy per zone, preferred over new mechanics (GDD §5).
- **Three new enemies** (Marketplace, Corporate, Golden Zone), plus the ceiling turret: the owner is describing them next.
- ~~**Golden Palace**~~ Answered: inside the city-sized palace; plays like any other level (GDD §5).

### 2. Bosses
For each boss: arena, phases, attacks, weak points, what power-ups are granted before the fight, how it scales on 3 vs 5–6 lanes, and its length.
- Floating Head: full breakdown.
- Sewer Swarm: full breakdown.
- Remaining 4+ bosses: concepts needed.
- Do bosses have their own leaderboards or star criteria?

### 3. Player character
- ~~Who or what is the player?~~ Answered: a human runner in a cyber suit (GDD §11). Still open: name, customization.
- Cosmetic skins as a mobile purchase item?
- How it looks when using each power-up (claws, dash, shield, armor).

### 4. Remaining power-up details
- **Claws:** how much extra wall time? Upgrade tiers?
- **Juggernaut dash:** duration, cooldown, upgrade tiers, PC key.
- **Slow time:** strength, duration, cooldown, upgrade tiers.
- **Magnet:** number of tiers and radius at each (cap: own lane plus adjacent lanes).
- **Weapons:** fire rate per tier; damage for tiers 2–3; exact splash radius.
- **Prices** for everything, and whether prices differ between PC and mobile.
- **Ramps and speed pads:** exact speed and multiplier values; does speed reset after a boost?
- Confirm *(proposed)*: immunity comes from items only, not from ramps.

### 5. Screens & UX
- **Shop layout** (including the equip toggle).
- **Level-complete stats screen:** which stats? (time, credits, kills, ramps used, deepest wall run, damage blocked, etc.)
- **Star criteria** per level.
- Main menu, zone/level select, settings, pause, death/revive flow screens.
- **In-level display (HUD):** score, credits, power-up cooldowns, level progress bar?
- First-time tutorial approach.

### 6. Audio
- Music style per zone (synthwave, industrial, etc.).
- Sound-effect priorities (every telegraph needs a distinct sound).
- Source for music: for now, code-generated placeholders in the sound-effect style (GDD §11). Final source (commissioned, licensed, or keep generated) is still open.

### 7. Mobile specifics
- The "dynamic adjustments based on parameters" you mentioned early on: what parameters? Device performance (quality settings), player skill (dynamic difficulty), or both?
- Ad rules: rewarded ads only (recommended), or also between-level ads? Frequency caps?
- In-app purchase catalog: credit packs, a "remove ads" purchase, cosmetics, starter bundle?
- Revive limits per level (e.g. max 1 ad revive per attempt)?

### 8. Remaining mechanics details
- **Exact PC lane count:** 5 or 6?
- **PC keys** for jump, dash, and anything else.
- **Cyborg toughness:** laser tier 1 shots to kill.
- **Hover truck cannon:** projectile type, telegraph.
- **Run speed:** base speed, and does it increase within a level?
- **Difficulty tiers:** what changes in the harder tiers (speed, enemy density, lanes, no revives)?
- **Endless mode rules:** which zones' skins, how difficulty ramps, and whether credits are earned there.
- **Web demo:** portal-specific end screens if portals restrict store links.

### 9. Narrative
- ~~Is there a story?~~ Answered: a light story with little or no words, a silent protagonist, a final villain backed by a cult (GDD §1). Still open: the individual story beats and cinematics (the owner will describe them), and the cult's name and visual identity.

### 10. Other
- Working title.
- Save system: local only, or cloud save (Steam Cloud / platform saves)?
- Accessibility: colorblind-safe hazard colors (don't rely on pink vs purple alone), reduced flashing, screen shake toggle.
- Languages to support at launch.
- Age rating targets (affects violence and gore level).

## B. Build-planning questions (final round)
- **Total budget** for the Claude Code build, and whether you're on a subscription plan or API billing.
- How often do you want check-ins: after each milestone, daily, or only when blocked?
- Tolerance for autonomous decisions: which kinds of choices may agents make alone, and which must come back to you?
- Do you want playable builds at each milestone (web build link, Android test build)?

## C. Assumptions made that you can still overturn
- The EMP disables fences for the rest of the level (not timed).
- Hitboxes are slightly smaller than visuals.
- Forced ads between levels avoided in favor of rewarded ads.
- The first Octodog appearances get a doghouse hint; later ones don't.
- Screech clusters are the visual building block for the swarm boss.

## D. Raised during build

### From the R1 core-movement grey box (September 25, 2026)
Each item has a placeholder in code marked `DESIGN-TBD` and, where it's a number, a value in `data/tuning/movement.tres` or `data/levels/`. Answer them after playtesting the grey box.

1. **PC jump key:** the placeholder is Up arrow + Space. **Dash key:** the placeholder is Shift (the dash itself isn't built yet).
2. **Run speed:** the placeholder is 18 m/s, constant within a level (`speed_gain_per_minute = 0`).
3. **Wall-run entry height:** 2.2 m from a free entry. Jumping into a wall adds 60% of the jump height. The descent eases (lingers high, then drops). Are these right?
4. **Leaving a wall:** jump = wall jump (per GDD). The placeholder also treats **pressing toward the lanes** as a wall jump. The slide action does nothing on a wall. Keep these?
5. **Sign blocks wall entry:** the move is ignored and the player stays in the outer lane, with a metallic "clank" sound. Should there be more feedback (a bump animation)?
6. **Low wall run vs floor fences:** on a wall, the body sticks out sideways into the outer lane. If the player is low on the wall, they hit a fence in the outer lane. This isn't specified; it's just what the collision does. Intended?
7. **Ceiling rules:** moving past the outer ceiling lane does nothing (no ceiling → wall). The ceiling has the same lane count and gravity as the floor. Jump and slide also work on the ceiling, mirrored (jump drops you away from the hull, then gravity pulls you back). Correct?
8. **Air slide:** pressing slide in mid-air drops fast and slides on landing. It's not in the GDD and can be switched off with `air_slide_fast_fall`. Keep it?
9. ~~**Hull end landing:**~~ Answered: keep a safe landing zone (GDD §3, September 26, 2026).
10. **Ramps:** the placeholder launches onto the wall at 4.0 m, with no speed boost (`ramp_speed_boost = 0`). The ramp sits in the outer lane and launches the player when they run over it.
11. **Pulsing fences:** on/off timings are placeholders (about 1.0–1.2 s each, with 0.35 s of flicker and an electric crackle before switching on).
12. **Difficulty within a level:** the placeholder adds +0.25 difficulty linearly from start to end.
13. ~~**Mobile orientation:** landscape or portrait?~~ Answered: landscape (GDD §2).
14. **Coyote time and jump buffering** (0.08 s and 0.14 s grace windows) are feel aids, not design. Tell me if you want them removed.
15. **Sound effects:** these are generated by `tools/asset_gen/sfx_gen.gd` in a crunchy 16-bit / heavy-metal style (distorted power chords, pick scrapes, a motorbike rev, FM blips). Keep the direction, and which effects need a different character? Real recorded samples can replace any file in `assets/sfx/` under the same name.
16. **PC lane count** (see §8): the grey box now defaults to 5 lanes on PC and 3 on mobile. F1 switches to 6 for comparison.

### From the full build (September 26, 2026)
Placeholders the build needed to be playable end to end. Each is marked `DESIGN-TBD` in code or data;
numbers live in `data/` (mostly `data/tuning/*.tres`, `data/shop/catalog.json`, `data/levels/*.tres`).

**Campaign and structure**
1. **Introduction schedule** (superseded September 26, 2026 by the owner's level-by-level schedule in GDD §5: cyborgs move to City 1, pulsing fences and window cyborgs to City 3, and the Octodog stays in Gangland 2 with drones in Gangland 3) (one new thing per level): City 1 *Rooftop Rush*: gaps, fences, walls and
   signs. City 2 *Skyway*: ceilings (anti-grav pads) and pulsing fences. City 3 *Neon Crossfire*:
   cyborgs and a rare hover truck. Gangland 1 *Scrapyard Streets*: ramps, sewer screeches, fence
   generators. Gangland 2 *Dog Run*: Octodogs and speed pads. Gangland 3 *Rotor Wash*: heli drones
   and window cyborgs. Hosts and the Bad Dream aren't placed yet ("late levels"). Level names and
   lengths (100–140 s) are placeholders too.
2. **Boss slots:** Zone 1's boss is unnamed (the Floating Head is a candidate); the Sewer Swarm sits
   in Gangland because of the sewers. Which boss goes where?
3. **Cinematic slots:** City has intro, pre-boss and outro slots; Gangland has intro and outro. Where
   do you want cinematics, and what should each show?
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
10. **Payouts:** completion pays everything collected plus 100 + 25 per campaign level; stars at 45%
    and 75% of the best possible credit score (one star for finishing).
11. **Prices:** placeholders in `data/shop/catalog.json` (e.g. laser 900, heavy missile 9,500, armor
    150, shield 400, grapple 250, revive 600). A perfect run of both zones pays about 5,500 credits;
    all permanent upgrades cost about 29,700. Mobile-specific prices are supported but not set.
12. **Spending order:** purchases spend bought credits first, so buying credits never lowers net worth.
13. **Breakables per run:** each attempt carries one charge of each owned, switched-on breakable (armor,
    shield, grapple); spares stay in stock. Revives are used from stock on the death screen.
14. **Quitting a level** from the pause menu pays nothing.
15. **In-app purchases** (stub only): two placeholder credit packs.

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

**Power-ups** (from the power-ups work)
27. **Missiles home** on their target (turn rate 7 rad/s) and leave the launcher angled 0.35 away from the
    surface. The GDD doesn't say missiles home.
28. **Swarm bonus on splash:** the heavy missile's bonus also applies to its splash on swarm enemies.
29. **No overkill:** auto-fire skips an enemy that shots already in flight will kill and moves on to
    the next nearest.
30. **Fence generators** are auto-fire targets (destroying one sets off its EMP). Should they be?
31. **Shots ignore level geometry** (hulls, walls), and the weapon fires from any surface.
32. **Slow time** slows the player too; pausing suspends it (resuming continues); dying or finishing
    ends it. Audio isn't slowed.
33. **Enemy health bars** appear after the first hit: red, draining to dark red, with a white segment
    for recent damage (yellow and orange stay hazard colours). The magnet's pull glows azure.

**Player model** (from the player-model work)
34. How each power-up looks: claws on the gloves, armor plates, a shield bubble, a shoulder weapon that
    grows by tier (tier colours are made up), a magnet coil.
35. Invulnerability: a bright tint that flickers (held steady with Reduced flashing), not a blink.
36. Death: a red flash while the suit's glow powers down (the grey box turned red). Keep?
37. The stomp pose also plays during the air-slide fast fall.
38. The player's glow is cyan, the same as the anti-grav pads. OK, or should the player have its own
    colour?

**Neon City look** (from the City skin work)
39. **Sign language for every zone:** a yellow/black striped frame around neon content (the frame is
   the hazard; the content can be anything).
40. **Truck speed:** the road below streams toward the player at a placeholder 14 m/s.
41. **Ships** fly toward the player: bow over the near end, engines at the far end where the player
   drops; the far end also carries the gap-edge orange.
42. **Fences:** glowing edge bars (top for full fences, bottom for gapped); an off fence shows no field.
43. **City neon avoids hazard colours:** no red traffic lights (red plus bloom reads as fence pink);
   decorative neon is unframed and sits above 9 m. The grey box's faint 2 m / 4 m wall-run height lines
   are kept on the facades. Keep them?

**Audio** (from the audio work)
44. **Mix balance:** music sits about 10 dB under the attack warnings; the pause menu ducks music by
  8 dB. Needs a listen on real speakers and phones.
45. **Music on death and level complete:** the zone track keeps playing under the death screen; the
  `level_complete` riff is in E (fits City, clashes with Gangland). Stop, duck, or play on?
46. **Music style per zone** (OPEN_QUESTIONS §6): City is 160 BPM galloping synth-metal in E minor,
  Gangland 120 BPM drop-D industrial groove, menus 100 BPM synthwave.

**UI** (from the UI kit work)
47. **Palette:** an azure main accent and a violet second accent; red only for warnings and "can't
    afford". Pink, orange and yellow are never UI colours (they're hazard colours).
48. **Stars** are white with an azure glow rather than gold (yellow is the sign colour). OK?
49. **Fonts and sizes:** Orbitron (titles) and Exo 2 (text, and heavy for numbers: Orbitron's slashed
    zero read like a "no" sign in a score of 0); touch devices get 76 px controls
    and 1.2× text. Worth checking on a real phone (`data/ui/ui_style.tres`).
50. **HUD progress bar:** shown; what its markers should stand for is open.
51. **Key rebinding:** single keys only (no Ctrl+ combinations); Esc cancels a rebind, so Esc itself
    can't be bound.

**Cyborgs and fence generators** (from the cyborg work)
52. **Cyborg shots to kill** (GDD §8 leaves it open): 3 laser tier 1 shots early in the campaign, 5 late.
53. **Cyborg attack:** engages from 72 m; 0.75 s charge-up; bursts of 2–3 bolts 0.18 s apart; reload
  2.2 s early to 1.3 s late; bolts 10 to 15 m/s. The aim locks when the charge-up ends, so switching
  lanes after it dodges the whole burst. At these numbers a normal cyborg usually fires once before
  the player reaches it.
54. **Cyborg movement:** walks toward the player at 1.4 m/s for up to 8 m and drops back at 8 m/s once
  passed. The panic variant (1 in 3) notices the player at 58 m, runs at 8.5 m/s for up to 45 m, then
  cowers. The GDD doesn't say what a fleeing cyborg does when it runs out of room.
55. **Fairness rules added (not in the GDD):** no cyborg bolt arrives within 12 m before or 8 m after a
  fence or gap; only one cyborg bursts at a time; cyborgs hold fire at a player on the ceiling, and
  window cyborgs at a player on their own wall; cyborgs stand at least 10 m from gaps, fences, ramps
  and pads.
56. **Hosts:** never panic; the kill bonus is 1,500. It's paid, and the Bad Dream released, on any
  kill, even a stray direct weapon hit (auto-fire never aims at hosts).
57. **Window cyborgs:** a 0.8 m body band centred on the 2.2 m wall-entry height, reaching 0.55 m out
  from the wall. They can't be stomped.
58. **Fence generators:** claws and running into one don't destroy it, and its body is solid (running
  into it kills; armor doesn't help). EMP radius 16 m; 3 shots to destroy; placed 9 m before its fence
  row.
59. **Scores and look:** cyborg and window cyborg 200, generator 150. LED faces are amber so they read
  apart from the player's cyan visor.

**Octodog and Sewer Screech** (from their work)
60. **Octodog timing:** wind-up 0.95 s early to 0.8 s late; lunges from 15 m at 9 to 11 m/s with a 3 m
  overshoot. A red floor line shows the lunge path, added to the GDD's "visual cue".
61. **Octodog aim:** it locks on the player's lane when the wind-up starts; 40% of repeat charges come
  from the lane beside the player. The first charge aims at the player from wherever the dog stands,
  so on 5–6 lanes it can cut across several lanes.
62. **Between charges** it passes in another lane and is harmless until 3 m ahead (no attack from
  behind). After its last charge it sits and is left behind; if no clear moment comes within 40 m, it
  runs off ahead.
63. **Charge planning:** charges only happen on clear stretches (no fence, pad, ceiling or other enemy),
  and a dog is left out if fewer than 2 charges fit.
64. **Doghouse:** the player's first 3 Octodogs ever hide in a doghouse in their lane and burst out at
  55 m.
65. **Octodog numbers:** score 250; gap-bait bonus 300; 5 shots to kill early and late (late scaling is
  open).
66. **Octodog contact:** is running into a standing Octodog also a "grab"? It's currently an attack, so
  armor blocks it.
67. **Screech timing:** it decides 1.6 s out (at least 1.15 s of warning); shakes 0.6 s early to 0.5 s
  late; emerges in 0.22 s; dashes at 6 to 8 m/s for up to 4 m; the swipe winds up for 0.14 s and is
  live for 0.16 s, reaching 1.3 m at 1.0 m high (1.6 m from a vent). Score 100.
68. **Screech spines:** landing on or running into them is a body collision, so armor doesn't block it
  (the shield does). With claws, even touching its swipe kills it.
69. **Screech and holes:** it stops at a hole's edge rather than dashing in.
70. **City screeches** come from wall vents only (a `screech_vents` level feature, rare). A manhole cover
  lands back over its hole, so no open hole looks like a gap.

**Heli drone and hover truck** (from their work)
71. **Drone contact:** it has no body hitbox, so touching, stomping or dashing into it does nothing.
72. **Drone attack:** it swoops in, hovers 11 m ahead and 3.2 m up, winds up for 1.15 s early to 0.95 s
  late (glowing eye and an aim line), then fires 6 to 7 bullets 0.18 to 0.15 s apart. The aim locks
  when firing starts. A barrage fits inside the invulnerability window, so armor or a shield protects
  through all of it. It leads a wall runner's slide down the wall. Only one barrage at a time.
73. **"Every drone on screen"** (for the anti-grav pad) means swooped in, and between 12 m behind and
  120 m ahead of the player.
74. **Drone waves:** a level's first wave is a single drone; a second drone joins only from mid-campaign;
  waves come at least 20 s apart; a level with drones always gets at least one.
75. **Drone pads:** the first comes 10 s after a wave appears plus some slack; each pad's ceiling lasts
  3 s. After the first wave the drone's pad schedule owns every pad: pattern ceilings give way, and
  floor pieces and enemies under a pad's ceiling are removed. Pads avoid a hover truck's lane.
76. **Hover truck lane and pacing:** it holds the outer lane on its side and never changes lanes. The
  pacing cycle (ahead, lurch back, rev, lurch forward alongside the player) and its timings are
  placeholders. Blocked by a player behind it, it leaves by speeding off ahead.
77. **Hover truck warnings:** a new "rev" sound and flashing spikes warn of the forward lurch. The
  cannon fires only while the truck paces ahead, and holds fire at a player on the ceiling or riding
  the roof. Window shooters (0 early, 2 late, 1 mid-campaign) fire with the cannon.
78. **Hover truck kill rules:** the weak point is on the lower cab roof, and riders drift toward it.
  Claws and the dash defeat it on contact with its live spikes (the shared rules). Its burst through
  the wall counts as an enemy attack, so armor blocks it.
79. **Trucks per level:** 1 early to 3 late, at least one guaranteed, one at a time. Its lane is kept
  clear while it's around, and a ramp is added for the wall route onto the roof when the level has
  ramps. City 3 has no ramps, so there only the lurch route and weapons reach the roof.
80. **Scores:** drone 300, hover truck 800.

**Platforms and presentation**
81. **Store links** in the web demo point at the stores' front pages until the game has store pages.
82. **App icon:** a placeholder neon "N" (`tools/asset_gen/icon_gen.gd`) until there's a title and brand.

### Answered (recorded in GDD_CHECKPOINT.md)
- Wall entry follows the jump grace rule (§3, September 25, 2026).
- ~~Ceilings never carry obstacles underneath (§3, September 25, 2026).~~ **Reversed September 26, 2026:** the floor under a ceiling may be dangerous; only the landing zone must be safe (§3). The generator's "floor under a ceiling is clear" rule and test need changing, as does the drone-pad rule that removes floor pieces and enemies under a pad's ceiling (item 75).
- Mobile orientation is landscape (§2, September 26, 2026).
- Zone 1 is the Neon City, Zone 2 is Gangland (§5, September 26, 2026).
- Bosses are standalone mini-games; short cinematics sit between levels and zones. Both are designed later, and the build leaves slots (§6, §10, September 26, 2026).
- The player is a human runner in a cyber suit, about 75% of the grey-box size (§11, September 26, 2026).
- Music: code-generated placeholders for now (§11, September 26, 2026).
