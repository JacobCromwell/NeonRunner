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
- ~~The **enemy introduction schedule**~~ Answered level by level (GDD §5). The Barnacle Turret is the Marketplace's new enemy (GDD §9.8).
- ~~Whether each zone introduces a new mechanic or object~~ Answered: at least one new enemy per zone, preferred over new mechanics (GDD §5).
- **New enemies:** the Marketplace's is the Barnacle Turret (GDD §9.8). The Corporate zone's is Buzz Overdrive (GDD §9.9). The Golden Zone's is the Resonator (GDD §9.10, working name). Also added: wall fences (§9.1), Gilded Sentinels (§9.11) and the Tithe Collector (§9.12).
- ~~**Names**~~ Answered: Resonator; Tithe Collector (GDD §9.10, §9.12).
- **Numbers still open:** the Resonator's shots to kill (Sentinels: 15; Tithe Collector: takes 25%).
- ~~**Golden Palace**~~ Answered: inside the city-sized palace; plays like any other level (GDD §5).

### 2. Bosses
For each boss: arena, phases, attacks, weak points, what power-ups are granted before the fight, how it scales on 3 vs 5–6 lanes, and its length.
- ~~Roster, gameplay style, length, death, items, rewards~~ Answered (GDD §10, September 26, 2026).
- ~~Floating Head: full breakdown.~~ Answered (GDD §10, September 26, 2026).
- ~~Sewer Swarm: full breakdown.~~ Answered (GDD §10, September 26, 2026).
- ~~Marketplace boss~~ Answered: The House (GDD §10); revisit after playtesting.
- ~~Dead Zone boss~~ Answered: Sleep Taker (GDD §10).
- ~~**Generators and auto-fire everywhere?**~~ Answered: yes. Weapons never set off a generator, in any level (GDD §9.1).
- ~~Corporate boss~~ Answered: Hostile Takeover (GDD §10).
- The final villain's fight: full breakdown.
- ~~Do bosses have their own leaderboards or star criteria?~~ Answered: yes (GDD §10).
- ~~Does the longer final fight still restart from the beginning on death?~~ Answered: a checkpoint halfway, at a possible second stage (GDD §10).

### 3. Player character
- ~~Who or what is the player?~~ Answered: redesigned September 26, 2026 after the owner's "Echo" concept sheet (GDD §11). Still open: customization.
- Cosmetic skins as a mobile purchase item?
- How it looks when using each power-up (claws, dash, shield, armor), redone for the new design.
- ~~**Player redesign**~~ Answered: Razor Echo, soft copper glow, no pistol (GDD §11; brief `docs/art/BRIEF_RAZOR_ECHO.md`).
- ~~**Cyborg redesign**~~ Answered: one blended body, a screen head, non-hazard colours, the base for every zone variant (GDD §9.2; brief `docs/art/BRIEF_CYBORG_GANGSTER.md`).
- ~~**Cyborg zone variants**~~ Answered: Brute in Gangland, Casino Mob Enforcer in the Marketplace, VR Runner in Corporate, the base burned out in the Dead Zone, a Golden Zone version derived from the Casino Mob Enforcer; all the same unit, none bigger than the base (GDD §9.2).
- ~~**Story idea: Cyborg Viewing Devices**~~ Answered: yes (GDD §5, "The cult").

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
- ~~Is there a story?~~ Answered: a light story with little or no words, a silent protagonist, a final villain backed by a cult (GDD §1). Still open: the individual story beats and cinematics (the owner will describe them), and the cult's name. The cult's symbol and colour are answered (GDD §5, September 26, 2026).

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
- FB 71: hosts are immune to all weapon damage (§9.7).
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
   and window cyborgs. Hosts and the Bad Dream are built but no level uses them yet (GDD: "late
   levels"; quick play `--features=cyborg,host,ceilings` shows them). Which level introduces them? Level
   names and lengths (100–140 s) are placeholders too.
2. (Answered: GDD §10's roster; the slots carry each boss's name and phases since B8.) **Boss slots:** Zone 1's boss is unnamed (the Floating Head is a candidate); the Sewer Swarm sits
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
27. **Attacks of different enemy types don't take turns.** Each type spaces its own attacks (one cyborg
  burst at a time, one drone barrage at a time, Octodog charges only on clear stretches), and the Bad
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
41. **Truck speed:** the road below streams toward the player at a placeholder 14 m/s.
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
52. **Mix balance:** music sits about 10 dB under the attack warnings; the pause menu ducks music by
  8 dB. Needs a listen on real speakers and phones.
53. **Music on death and level complete:** the zone track keeps playing under the death screen; the
  `level_complete` riff is in E (fits City, clashes with Gangland). Stop, duck, or play on?
54. **Music style per zone** (OPEN_QUESTIONS §6): City is 160 BPM galloping synth-metal in E minor,
  Gangland 120 BPM drop-D industrial groove, menus 100 BPM synthwave.

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
68. **Cyborg attack:** engages from 72 m; 0.75 s charge-up; bursts of 2–3 bolts 0.18 s apart; reload
  2.2 s early to 1.3 s late; bolts 10 to 15 m/s. The aim locks when the charge-up ends, so switching
  lanes after it dodges the whole burst. At these numbers a normal cyborg usually fires once before
  the player reaches it.
69. **Cyborg movement:** walks toward the player at 1.4 m/s for up to 8 m and drops back at 8 m/s once
  passed. The panic variant (1 in 3) notices the player at 58 m, runs at 8.5 m/s for up to 45 m, then
  cowers. The GDD doesn't say what a fleeing cyborg does when it runs out of room.
70. **Fairness rules added (not in the GDD):** no cyborg bolt arrives within 12 m before or 8 m after a
  fence or gap; only one cyborg bursts at a time; cyborgs hold fire at a player on the ceiling, and
  window cyborgs at a player on their own wall; cyborgs stand at least 10 m from gaps, fences, ramps
  and pads.
71. **Hosts:** never panic; the kill bonus is 1,500. It's paid, and the Bad Dream released, on any
  kill, even a stray direct weapon hit (auto-fire never aims at hosts).
72. **Window cyborgs:** a 0.8 m body band centred on the 2.2 m wall-entry height, reaching 0.55 m out
  from the wall. They can't be stomped.
73. **Fence generators:** claws and running into one don't destroy it, and its body is solid (running
  into it kills; armor doesn't help). EMP radius 16 m; placed 9 m before its fence row. (Weapons no longer
  destroy one: item 31.)
74. **Scores and look:** cyborg and window cyborg 200, generator 150. LED faces are amber *(changed September 26, 2026: cold white, GDD §9.2)* so they read
  apart from the player's cyan visor.

**Octodog and Sewer Screech** (from their work)
75. **Octodog timing:** wind-up 0.95 s early to 0.8 s late; lunges from 15 m at 9 to 11 m/s with a 3 m
  overshoot. A red floor line shows the lunge path, added to the GDD's "visual cue".
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
80. **Octodog numbers:** score 250; gap-bait bonus 300; 5 shots to kill early and late (late scaling is
  open).
81. **Octodog contact:** is running into a standing Octodog also a "grab"? It's currently an attack, so
  armor blocks it.
82. **Screech timing:** it decides 1.6 s out (at least 1.15 s of warning); shakes 0.6 s early to 0.5 s
  late; emerges in 0.22 s; dashes at 6 to 8 m/s for up to 4 m; the swipe winds up for 0.14 s and is
  live for 0.16 s, reaching 1.3 m at 1.0 m high (1.6 m from a vent). Score 100.
83. **Screech spines:** landing on or running into them is a body collision, so armor doesn't block it
  (the shield does). With claws, even touching its swipe kills it.
84. **Screech and holes:** it stops at a hole's edge rather than dashing in.
85. **City screeches** come from wall vents only (a `screech_vents` level feature, rare). A manhole cover
  lands back over its hole, so no open hole looks like a gap.

**Heli drone and hover truck** (from their work)
86. **Drone contact:** it has no body hitbox, so touching, stomping or dashing into it does nothing.
87. **Drone attack:** it swoops in, hovers 11 m ahead and 3.2 m up, winds up for 1.15 s early to 0.95 s
  late (glowing eye and an aim line), then fires 6 to 7 bullets 0.18 to 0.15 s apart. The aim locks
  when firing starts. A barrage fits inside the invulnerability window, so armor or a shield protects
  through all of it. It leads a wall runner's slide down the wall. Only one barrage at a time.
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
96. **Where it floats:** 7.5 m ahead of the player, facing them, 1.3× scale (about 4.7 m tall); 7 m ahead
  while it waits under a ceiling.
97. **Chase timing:** 20–30 s from the burst (the clock runs while it holds a slash for another enemy's
  attack); slashes 3–4 s apart; it emerges over 1.0 s and first telegraphs 0.8 s later.
98. **Telegraph:** 1.2 s early in the campaign to 1.0 s late, then a 0.22 s lunge; the claws are live for
  0.12 s and it recovers for 0.7 s. It lines up within 0.5 m of the player's lane first, waiting at most
  1.2 s for a player who keeps moving.
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
109. **App icon:** a placeholder neon "N" (`tools/asset_gen/icon_gen.gd`) until there's a title and brand.
110. **Leaderboards view:** scores are already submitted (per level and difficulty tier, endless per lane
  count and tier, net worth), but no screen opens the platform's leaderboard UI yet. The plan is a button on
  the title and results screens once the platform plugins are chosen (the stub has no leaderboards).
111. **Achievements:** the platform layer can unlock them, but none are designed. Which ones, if any?

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
2. **Where each new thing appears within its level** (GDD §5, §6; the schedule only says City 1's cyborgs come
   "late in the level"). Placeholder (`feature_starts` in `data/levels/*.tres`): City 1's cyborgs at 60% of the
   level; every other introduction at 10%, and a level bringing two or three things staggers them: City 3
   pulsing fences 10%, window cyborgs 35%, hover truck 60%; Gangland 1 screeches 10%, ramps 40%; Gangland 2
   Octodogs 10%, speed pads 45%; Gangland 3 generators 10%, drones 40%; Marketplace 2 wall fences 10%, vent
   screeches 40%; Corporate 1 Buzz Overdrive 10%, partial wall fences 50%. The first pattern after a start
   uses the feature, so it appears right after its hint. Is staggering right, and are these the places?
3. **Sewer screeches outside street zones** (GDD §5, §9.5; manholes need a street). Placeholder: the
   Marketplace, Corporate and Golden zones get wall-vent screeches only, from Marketplace 2's shopfront vents
   on; the Dead Zone's rubble street gets manholes and vents. So Marketplace 1 has no screeches (the one level
   where an earlier enemy doesn't appear). Marketplace 2 picks vent screeches 2.5× as often as the City's rare
   rate; Corporate and Golden keep the rare rate. Is that the intent?
4. **The Buzz Overdrive's "only two zones"** (GDD §9.9). Placeholder: Corporate and the Dead Zone; not the
   Golden Zone.
5. **Partial wall fences "from the Corporate zone"** (GDD §9.1). Placeholder: from Corporate 1, at 50% of the
   level, after the Buzz Overdrive's introduction. Feature names: `wall_fences`, `wall_fences_partial`.
6. **Corporate 2's heavier military presence** (GDD §5, proposed). Placeholder: drones, hover trucks and Buzz
   Overdrives are picked 1.5× as often (`feature_weights` in `data/levels/corporate_2.tres`); their rules
   still cap how many fit. Should it also (or instead) be the Corporate skin's military ships and props?
7. **Dead Zone 2, "a quiet, eerie remix"** (GDD §5). Placeholder: Dead Zone 1's features, a little harder,
   nothing new. What makes it a remix in play: fewer enemies, more hosts, something else?
8. **The difficulty curve over 15 levels** (GDD §6; supersedes "From the full build" item 4). Placeholder
   (`data/campaign/campaign.tres`): 0.1 → 0.9, linear, plus each level's bias: City 1 −0.05, Golden 2 +0.05
   (the peak, GDD §5 proposed), Golden 3 −0.05 (below the peak, above Golden 1). Within a level difficulty
   still rises by 0.25, so Golden levels reach 1.0 partway through.
9. **Level lengths** (GDD §4, §5's "about 35 minutes" flawless). Placeholder: City 110/120/130 s, Gangland
   135/140/145, Marketplace 140/145, Corporate 145/150, Dead Zone 145/150, Golden 145/150/150: 2,100 s, 35
   minutes. The first six levels got 10–15 s longer, since a 140 s average needs it under the 150 s cap.
10. **Level names** (GDD §5 names only the Golden Palace). Placeholders: Awning Alley, Shopfront Sparks, Maglev
    Line, Checkpoint Plaza, Ashfall, The Hush, Gilded Canals, Sentinel Row; the City and Gangland keep theirs.
11. **Slots for the new zones** (GDD §6, §10). Every new zone has intro and outro cinematic slots; only the City
    has a boss intro. Should the final villain get one? The Golden Zone's outro is the ending. Open boss slots
    are named "Marketplace boss", "Corporate boss", "Dead Zone boss" and "The final villain" (with the halfway
    checkpoint and second stage in its notes).
12. **Expected loadout per zone** (GDD §8). Still empty in every zone, and nothing reads it yet.
13. **Earlier features in later levels** (GDD §5: "anything introduced earlier keeps appearing later"). As
    levels list more features, each gets fewer pattern picks, and some enemies' rules drop what doesn't fit,
    so on the shipped seeds some levels went without one (no Octodog in Gangland 3 at 3 or 6 lanes, nor in the
    Dead Zone or Golden Zone at 5 lanes; no host in Dead Zone 2 at 5 or 6 lanes, nor in Golden 1; no vent
    screech in Corporate 1). The GDD rule is decided, so the build is adding a guarantee that every level
    places each of its features at least once (follow-up task after B1). Still open: how often each earlier
    feature should appear beyond that. (Built: every campaign level now places each of its features at least once, on
    any seed and lane count; see items 25–26.)
14. **Two new placeholder patterns** (`data/patterns/prototype_patterns.json`): a pulsing fence in one lane
    (difficulty 0–0.6), since the other pulsing patterns start at 0.4, which City 3 barely reaches; and a speed
    pad in one lane with four credits after it (no pattern placed speed pads before, so Gangland 2's never
    appeared).
15. **Music for the new zones until their tracks exist.** Zones name their track after their id; until the
    music task adds them the game skips them quietly and the menu music keeps playing. Fine as a stopgap?
16. **The economy over 15 levels** ("From the full build" items 10–11). Completion pays 100 + 25 per campaign
    level, so Golden 3 pays 450; prices were set for a two-zone campaign. Needs a balancing pass.

**Gangland update** (from D1; numbers are F6-tunable exports on `GanglandSkin`)
17. **Gangland's ceilings** (GDD §3, §5; replaces "From the full build" item 45, the scavenger barge). Placeholder:
    two structures, picked per ceiling (45% buildings): an overpass (tagged concrete fascia, crash barrier and
    railing, a sign gantry with billboards and corporate ads, a dead lamp post, a gang lookout of sandbags and
    military crates) and the upper storeys of a bombed-out building bridging the street (lit and curtained
    windows, laundry, a broken roof). Both run on one flat concrete slab, a beam per lane, with dark joints, small
    warm-white work lamps on every lane seam and the orange end band. Right structures, and is the lamp-lit seam
    a good lane read?
18. **Narrow ceilings in Gangland** (GDD §3, task B3): a side in mid-street ends in a plain edge face. What should
    a narrow ceiling be here: a slab broken off a building, a pedestrian bridge, something else?
19. **Time of day** (GDD §5, §11 give the palette, not the hour). Placeholder: a dusty dusk (brown sky, tan dust on
    the horizon, a veiled pale sun, smoke columns, brown dust fog), dark enough for hazards to pop. Keep it, or a
    harsher daylight?
20. **Hints of corporate and military funding** (GDD §5). Placeholder: side streets barricaded with stencilled
    olive military crates (30%) or corporate containers with a logo (30%); olive military notice boards above the
    wall-run band; corporate ads among the posters (30%); sandbags as a fence mount. The corporate logo and colour
    are a generic grey mark (`kit_logo.gdshaderinc`): should they match the Corporate zone's brand (task D4)?
21. **The cult emblem, hidden in plain sight** (GDD §5, proposed): unlit bronze, small, beside the logo on some
    container doors, as the sponsor's mark in the corner of some ads, and on some crates and notice boards (35%
    of each); it fades out below about 24 px on screen. The right amount of "hidden"?
22. **Signs of life** (GDD §5): graffiti pieces and tags over the lower storeys (dusty blue, steel grey, violet
    grey, cream; no hazard hues), 12–32% of upper windows lit, laundry, rooftop clutter, bulbs over side streets,
    washing lines across the street at 15.4 m and up. Too busy, or not enough?
23. **Holes as craters** ("From the full build" item 47): the asphalt is scorched toward each hole and sand
    drifts along the street; holes stay one lane wide and square-cut, with the orange edge on the collision edge.
    Enough of a crater read?
24. **Motion on the still street** ("From the full build" item 46): dust-coloured flecks, paper scraps and pale
    speed streaks, as before.

**Every feature appears** (from the B1 follow-up; see item 13, now built)
25. **Where a guaranteed enemy goes** (GDD §5). When a level's rules drop every host or every Octodog, those
    rules add one where it fits every rule; otherwise the generator rebuilds the level with a pick of the
    missing feature forced at a new spot. Placeholder: a random spot among those that fit (`host_rules.gd`,
    `octodog_rules.gd`); forced picks go to fixed shares of the level (`GUARANTEE_SHARES`). Should a
    guaranteed one go somewhere in particular (early, late, spread out)?
26. **Introductions that come late** (GDD §5, §6; item 2). An older feature's rules can clear away a level's
    new feature, which then first appears later. On the shipped seeds none do; over 100 random seeds 6% came
    more than 210 m late, almost all Dead Zone 1's first host (the first drone wave arrives during its chase,
    and the drones own every pad from then on, GDD §9.6) and Marketplace 2's first vent screech. Should the
    older feature make way for the new one (e.g. no drone wave during an introduced host's chase), or is "a
    little later" fine? Placeholder: the older feature's rules win.

**Boss framework** (from B8; defaults in `scripts/campaign/boss_def.gd`)
27. **Boss numbers** (GDD §10): health, payout, defeat score, score per weak point and the time bonus. Placeholder
    (every boss slot for now): 300 laser tier 1 shots, 500 credits, 5,000 points for the win and 500 per weak
    point, and 50 points for every second under 200 s.
28. **Par times** (GDD §10, proposed): placeholder 150 s for two stars and 100 s for three, the same on every lane
    count. Should they differ between 3 and 5–6 lanes?
29. **No credits on a boss's track:** a fight has no time limit, so credits along it would pay for stalling. The
    arena's laps carry none; the boss's payout replaces them. (The House's jackpot fountain will need credits
    placed during a fight, which the credit field can't do yet.)
30. **How long the final fight's checkpoint lasts** (GDD §10): placeholder: for every retry of that run (death →
    summary → shop → retry, and Restart fight in the pause menu); starting the fight again from the map or
    quitting starts it from the beginning. Never saved.
31. **Time and score after a checkpoint:** a win after resuming counts the fight time and score from the attempt
    that reached the checkpoint plus this one's, so par times, the time bonus and the leaderboard compare whole
    fights.
32. **Granted items** (GDD §8): a granted breakable is one charge whether or not the player owns it, and using it
    never costs stock; a granted permanent item is at least tier 1 (`"weapon:2"` for a tier); granted items ignore
    the equip toggle; the revive can't be granted. The intended generosity?
33. **The standard armor rule's timing** (GDD §10): the delay after a break is drawn from the boss's range (15–17 s;
    the Floating Head 10–15 s) by a seeded stream; a break counts against the cap of the phase it happened in even
    if its pickup comes in the next; the final-phase pickup also comes when a retry resumes in the final phase.
34. **Weapons against bosses** (GDD §10: even the best weapon saves at most one stomp): with no time limit only a cap
    can promise that. Placeholder: `BossDef.weapon_share_cap`, the most of a boss's health weapons can take over
    the whole fight (the Floating Head 0.34); auto-fire stops aiming at the boss once it's reached; splash never
    hurts a boss's body.
35. **Damage carried between phases:** a hit bigger than what's left of a phase carries into the next (so chip
    damage can save a stomp), but never past the end of the next phase: every phase gets played.
36. **Harder difficulty tiers and bosses** (GDD §6): placeholder: a tier's run speed and difficulty bonus apply to
    the boss's arena; the boss's own pattern doesn't change. What should a harder tier do to a boss fight?
37. **Phase data for the designed bosses** (GDD §10): the slots carry the phases the design gives. Placeholders: the
    Sewer Swarm's second phase as three clusters (five in all), one big hit in each of Hostile Takeover's first two
    phases, and every phase's pace and intro length.
38. **After the win:** the runner keeps running for two seconds while the boss's defeat plays out, safe from
    anything still in the air; then the results, the shop and the next step (the outro; in the web demo the outro,
    then the store-link screen). Is a shop wanted between a boss and its zone's outro? Placeholder: yes.
39. **The first boss hint:** "A boss! Only its glowing red weak points and your weapons can hurt it." Sleep Taker,
    which weapons can't hurt, will need its own hint.
40. **Boss HUD and results** (§A.5): a bar top centre in enemy-health red with the boss's name, its phase and a marker
    at each phase's end, grey while it can't be hurt; a "Checkpoint!" hint; results with time, phase reached, weak
    points hit, kills, hits blocked, the time bonus and the par times.
41. **Boss leaderboards** (GDD §10): one board per boss and difficulty tier (`boss/<boss id>/<tier>`); none in the web
    demo.

**Marketplace skin** (from D2; numbers and colours are exports on `MarketplaceSkin`)
42. **Enemy look in the Marketplace:** GDD §9.2 now gives its cyborgs the Casino Mob Enforcer (task P3). Placeholder:
    the city look until P3 sets the skin's `enemy_variant`; hover trucks, drones and screeches keep the city look.
43. **Time of day and light** (GDD §5 gives palette and mood): placeholder a warm, dusty dusk: a periwinkle-to-rose
    sky with an early moon, a low sun gilding the upper floors, the street in evening shade, a light dust haze, and
    warm-lit shop displays. Right for a "bustling, happy market"?
44. **Under the stall roofs:** placeholder the market floor 6.5 m below, everything under the roofs in deep shade, so
    a gap shows only dark faces dropping away and the orange edge (the first pass's lit counters made a gap look like
    a roof). How deep, and what should it show?
45. **The mix of ceilings:** placeholder weights 3.5 building bridging the street, 2.5 overpass, 1.5 merchant ship,
    2.5 floating ad; a narrow ceiling (task B3) becomes an overpass.
46. **Shop windows at wall-run height and the citizens in them** (GDD §5, §9.2): every shopfront has windows from
    0.85 m to 2.8 m with a lit display the player runs across on a wall run (`shop_windows()` lists them for task
    D3). A window cyborg draws its own dark window over the shopfront. Right height, and how should D3's citizens
    read apart from window cyborgs?
47. **Decorative signs:** neon, ad boards and casino bulbs never below 8 m, and the wall-run band above the shop
    windows stays calm; hazard signs are painted shop signs inside the yellow/black frame.
48. **Fence mounts:** steel poles with glowing insulator caps in stacked wooden market crates at the lane edges.
49. **Motion on the still floor** (approved for every still-floor zone in the review): dust, paper scraps and speed
    streaks, the stalls' frame poles and scalloped hems, pennants and festoon lights across the street every ~34 m,
    and cables higher still.
50. **How often the emblem hides in the market:** 40% of floating ads, rooftop boards and casino signs carry it as a
    small warm-white badge, and 40% of painted blade signs in unlit bronze; never smaller than 0.9 m, never an ad's
    main mark, never on hazard signs.
51. **Wall-run height marks on light walls** (FB 44): the 2 m and 4 m lines as dark, unlit paint.
52. **What the cult's feed shows** (GDD §5, Cyborg Viewing Devices: the design doesn't say). Placeholder, shared by
    every skin (`CultFeed`): a wordless cold-white CRT picture (scanlines, soft static, a slow rolling bar) looping
    over 18 s through a screen-head face, the emblem in warm white, and rings converging on a point, one at a time
    (the emblem and the rings together read as a radiation trefoil), in sync on every screen.
53. **How often the feed plays in the market:** 35% of billboards, casino signs and floating ads, and an old TV in
    22% of shop windows (dimmer, so the wall-run band stays calm).
54. **How the market's future looks** (GDD §5: never historical): composite cladding with slab-edge bands, rounded
    windows in thin aluminium frames with smart glass or roller shutters, metal-clad piers, air-conditioning units,
    delivery-drone racks, glass balconies, cable trays and cables across the street, dishes and masts on the roofs,
    all above the wall-run band. The right kind of future?
55. **How dusty and worn:** sand on roofs, awnings and ledges, sun-bleached patches, grime at the foot of faces and
    under windows, weathering blotches and a light haze; one `wear` value scales it all.

**In-run pickups** (from B7; numbers in `data/tuning/pickups.tres`)
56. **A pickup of an item the player already holds** (GDD §8, §10): does it add a second charge, pay something, or
    do nothing? It matters most for the final phase's armor pickup, which comes whether or not the player still has
    armor. Placeholder: taken without adding a charge (at most one of each item, like the loadout); if the cap is
    raised, picked-up charges break before the player's own.
57. **Where a pickup appears** (GDD §10 says when, not where): 42 m ahead (about 2.3 s), in the player's lane or the
    nearest fair lane at most 2 lanes away, with 12 m of floor before it and 6 m after free of gaps, fences, pads,
    ramps, ceilings, enemies and a boss's floor warnings. When nothing in reach is fair it waits, so a due armor
    pickup can come a little later than the 10–15 or 15–17 s. Right distances, and is waiting the right answer?
58. **A missed pickup** is gone, and the armor rule's once-per-phase cap still counts it, so a player who misses the
    pickup after a break gets none until the next phase. Intended, or should it come back once?
59. **Picked-up items and the stock:** a picked-up charge belongs to the fight, like a granted item: breaking it
    never costs stock, and a pickup never adds to the stock.
60. **The pickups' look and sound:** the HUD's round badge for the item standing upright at chest height (1.3 m):
    its white icon on a dark disc in a white ring, a soft halo and floor glow; it bobs and sways, never spins, and
    looks the same in every zone (white is also the 100-credit gem's colour; size, shape and icon tell them apart).
    A soft chime when one appears, a latch and chime when taken, and a first-encounter hint per item.

**Razor Echo, the player model** (from P1; brief `docs/art/BRIEF_RAZOR_ECHO.md`; frames in the P1 report)
61. **How each power-up looks on Razor Echo** (brief "Power-up looks", proposed; supersedes FB 35): each in steel, white
    or its own colour, never copper. Weapon: a gunmetal emitter on a folding mount over the gold arm's shoulder,
    growing by tier (cyan, violet and white lights, the shots' colours; shots now leave the left shoulder). Claws:
    three steel blades from each hand's knuckles. Armor: steel plates on the shoulders, chest and upper back, which
    burst into tumbling shards when it breaks. Magnet: a coil with azure windings on the back of the belt. Shield: the
    existing pale-cyan bubble. Should the shield follow the copper?
62. **The pattern across the back** (GDD §11): the sheet's pipes simplified for about 30 pixels on screen: a hook and a
    cross on a rusted plate, a forked Y to the belt, two long framing conduits, and a loop down each back panel of the
    skirt. The right shapes?
63. **How bright and deep the copper is** ("soft copper"): it renders pale (about RGB 250, 195, 140) on both renderers,
    well apart from the gap edges; a deeper copper moves toward gap-edge orange and enemy fire. Keep it, or deeper?
64. **The rim light for dark tracks:** a faint pale steel-blue glow on faces seen edge-on, below the bloom threshold.
    Right colour and strength?
65. **Invulnerability and death in the new look** (FB 36, 37): the invulnerability tint is pale copper-white; on death
    the red flash stays and the conduits and eye go dark.
66. **The dash in copper:** the dash's shell, speed lines and smash burst are pale copper, a little dimmer so the
    additive shell never reads as a hazard's orange.
67. **How the coat moves:** four stiff panels from the waist (two behind, split by a vent; two at the front edges)
    follow the thighs through a spring with a little lag and overshoot, trail in the wind, flare when falling, trail
    behind a slide, hang toward the feet on the ceiling, and fold along the legs in a death. On a wall they also sag
    12° toward real gravity (the brief doesn't say). Right amount of motion; keep the wall sag?
68. **Details read off the sheet:** the scar across the right cheek, a dark leather fingerless glove on the right hand,
    two small copper lights on the vest (the sheet's were cyan and orange), a dusty hem, and a high collar open at the
    front with a copper conduit round its back. Anything to change?

**Dangerous floor under ceilings** (from B2; `CeilingZones`, the gauntlet patterns)
69. **Gauntlets under ceilings** (GDD §3, §6): six new patterns put a gauntlet under a 4–4.5 s ceiling (fence rows, hole
    rows or a mix with one lane free, cyborgs, manholes, a generator with its fences), from difficulty 0.3–0.5, picked
    with weights 0.15–0.35 against the plain ceiling's 1.2, so most ceilings stay plain. City 2 introduces ceilings
    with a plain one and may show a gauntlet in its second half. The right mix, and should City 2 show one or only City 3?
70. **What "safe to land on" covers** (GDD §3): 21.6 m after a ceiling's end with no hole or fence in any lane and no
    floor enemy's reach. A cyborg further ahead may still fire at a player dropping off a ceiling. Should enemies also
    hold fire while the player drops and lands?
71. **A pad the player can step on:** the pad's lane is free of holes, fences and ramps from a full jump before it
    until the lift reaches the hull, and no floor enemy reaches the pad. A hazard row may still force the player out of
    the pad's lane just before it. Enough, or should the approach be clear in every lane?
72. **Rule ceilings now lie over the floor** (replaces FB 90's clearing): the drone's pad schedule and a Bad Dream
    chase's pads clear only the landing zone and the pad's spot, so drone and host levels keep much more floor
    content (they used to empty about half of every drone stretch). Intended density, or lighter patterns there?
73. **Octodogs under a ceiling** may run and charge a floor runner; their charges keep off pads and landing zones, and
    they never wind up at a ceiling rider.
74. **Credits under a ceiling:** unchanged: trails skip the floor under a ceiling (the ceiling's line and its 25 reward
    taking the pad); rich credits at hole edges and fences appear there as anywhere. Should the harder floor route
    under a gauntlet pay more?
75. **The ceiling camera and hazards below** (GDD §3, §11): riding a ceiling, the camera sits at 2.4 m, so a gapped
    fence below (its field reaches 2.1 m) fills the bottom of the screen with pink for about 0.25 s. Harmless, but it
    could read as a hit. Raise the ceiling camera (say to 3 m)?

### Answered (recorded in GDD_CHECKPOINT.md)
- Wall entry follows the jump grace rule (§3, September 25, 2026).
- ~~Ceilings never carry obstacles underneath (§3, September 25, 2026).~~ **Reversed September 26, 2026:** the floor under a ceiling may be dangerous; only the landing zone must be safe (§3). The generator's "floor under a ceiling is clear" rule and test need changing, as does the drone-pad rule that removes floor pieces and enemies under a pad's ceiling (item 75).
- Mobile orientation is landscape (§2, September 26, 2026).
- Zone 1 is the Neon City, Zone 2 is Gangland (§5, September 26, 2026).
- Bosses are standalone mini-games; short cinematics sit between levels and zones. Both are designed later, and the build leaves slots (§6, §10, September 26, 2026).
- The player is a human runner in a cyber suit, about 75% of the grey-box size (§11, September 26, 2026).
- Music: code-generated placeholders for now (§11, September 26, 2026).
- The cult's symbol and colour: the Convergent Triad, option B of the D7 sheet (§5, September 26, 2026).
