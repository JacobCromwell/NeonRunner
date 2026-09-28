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
10. **Ramps:** (the boost was changed by the owner's review and built by R1: see "From build phase 2" item 80.) The placeholder launches onto the wall at 4.0 m, with no speed boost (`ramp_speed_boost = 0`). The ramp sits in the outer lane and launches the player when they run over it.
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
7. (Decided in the owner's review and built by R5: see items 152–156.) **Dead Zone 2, "a quiet, eerie remix"** (GDD §5). Placeholder: Dead Zone 1's features, a little harder,
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
15. (No longer comes up: every zone has its own track since D8, item 109.) **Music for the new zones until their tracks exist.** Zones name their track after their id; until the
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

**The cult's feed and emblem in the City and Gangland** (from D9; what the feed shows is item 52)
76. **Where the feed plays in the Neon City** (GDD §5): the City has no shop windows at the play field, so 35% of the low
    buildings' roof billboards show it, and 40% of the towers flush with the street hang a big screen (4.8 m wide, its
    bottom 12–16 m up) out over the street facing the traffic: about one hung screen every 170 m and one feed billboard
    every 210 m. The right places and amounts?
77. **Where the emblem hides in the City:** a 1.4 m sponsor's badge in the corner of 40% of the roof billboard ads and a
    brand mark at the foot of 40% of the towers' neon banners, in its warm-white neon, never on hazard signs, never below
    0.9 m: about one every 50 m, usually too small or edge-on to notice from the lanes. Right amount? Should it also
    brand the hover trucks' containers or the ships (they are play surfaces)?
78. **Where the feed plays in Gangland:** 35% of the overpasses' gantry billboards are salvaged screens playing it, and
    30% of the tall ruins have a TV glowing with it in one upper window (9.9 m up or higher). The paper corporate ads in
    the wall-run band stay paper. Should the bombed-out buildings bridging the street show a TV too?
79. **A TV in a window next to window cyborgs** (GDD §9.2 readability): the feed's loop shows a screen-head face, so a TV
    could look a little like a window cyborg's face. The TVs stay well above the band window cyborgs use, small, dim, in
    a dark room, and the face shows 7 s of the 18 s loop. Distinct enough, or should Gangland's TVs leave the face out?

**Ramps' speed boost and the blocked-wall bump** (from R1; numbers in `data/tuning/movement.tres`)
80. **A ramp's speed boost** (GDD §3): a speed pad's, 6 m/s (`ramp_speed_boost`), fading at their shared 4 m/s every
    second (`boost_decay_per_second`), so it's gone after 1.5 s. A ramp's wall run now covers about 43 m instead of 39 m.
    Bigger, smaller, or a speed pad's? (To tune after playtesting.)
81. **The blocked-entry bump** (GDD §3: "a small sideways bump"): out toward the wall and back over 0.16 s
    (`wall_bump_time`), at most 0.35 m (`wall_bump_distance`); a sign that reaches down to the runner stops it at its
    face. The runner stays upright going out and leans away from the wall coming back, as if pushed off it. Right size,
    speed and look?
82. **Wall-run credits with claws** (GDD §7, §8; unchanged by R1): the credits follow the path of a runner without
    claws. Claws make wall runs 1.5 times longer, so a runner with claws slides down more slowly and passes the last
    three credits (35 of the 42) too high to take them. Keep it (claws trade those credits for a longer run), or place
    the line so both paths reach it (for example fewer credits, all in the high first half)?

**The Floating Head: ship, entrance, bombing run and reveal** (from E1a; numbers in `data/bosses/city_boss_tuning.tres`;
play it with `--boss=city_boss` in debug builds)
83. **The ship and its face** (GDD §10): a hull shaped like a huge head seen from behind, dark gunmetal with cold white and
    blue lights; its stern is a visor screen with a face in cold-white LED dots (eyes that follow the runner, heavy brows,
    static, a rolling bar), a hinged jaw below (the mouth for the cyborg drop), loudspeaker "ears", a searchlight and bomb
    bay underneath, three red weak points on the crown under covers. Does the look fit? Should the face keep the cult's
    cold-white screen language or have a colour of its own (never a hazard colour)?
84. **Its size:** it fills the street less 0.6 m a side (6.6 m wide at 3 lanes, 11.4 m at 5, 13.8 m at 6), 24 m long,
    10.5–12 m tall, so the arena's walls carry no signs. A bigger ship would fly above the buildings, where its face and
    weak points are hard to read on a phone. Right scale?
85. **The entrance:** a 4 s intro. It starts 42 m behind the runner out of sight with a jet roar, sweeps overhead (the
    camera shakes) and eases into its station, its stern 34 m ahead and its belly 12 m up; it attacks nothing on the way.
86. **The searchlight** (GDD §10, proposed): the light hunts the runner, its spot where the runner will be when a bomb
    lands (about 22 m ahead); after each blast it swings away 1–2 lanes and back. The lock is the warning: the light turns
    from white to red, a red target circle marks the spot, a clack-and-alarm plays, and the bomb falls with its whistle;
    the blast comes 1.1 s after the lock. Every third lock covers two lanes. That makes 9 locks and 12 bombs in the 17 s
    first run. Hunt the player like this, or sweep a fixed pattern? Is 1.1 s right? Is a white sweeping light (red only
    when locked) right?
87. **The blast:** a fireball whose hitbox burns 0.35 s, 0.7 of a lane wide and 2.4 m tall, too tall to jump, so
    switching lanes is the dodge; armor and the shield block it, the dash passes through, and a wall runner beside it is
    safe. Should a jump, a slide or a wall run ever be a planned way to dodge a bomb?
88. **Where bombs may fall** (fairness): only on clear roof (no holes or fences from 8 m before to 5 m after), with a free
    lane at most 2 lanes away and a clear way to it, never under a ceiling, never within 3 m of a pickup. Otherwise the
    light keeps hunting, so a runner hemmed in by fences may see no bombs for a moment. Right rules?
89. **The later, shorter runs** (GDD §10: once or twice it rises for another, shorter run): 2 runs of 9 s, at the start of
    phases 2 and 3, at the phase's pace, so the warning shrinks to 0.96 s and then 0.85 s. When should they come, how
    long, and should "the next phase is faster" also shorten the warnings?
90. **The reveal:** after the first run it drops in front of the runner over 3 s, to 26 m ahead with its belly 3 m up
    (above the fences, so the track stays in view); over the last 1.6 s its screen powers on (a bright line, static, then
    the face) with a picture tube's thunk, static and a loudspeaker blare. Is the height right?
91. **The arena:** the City's truck roofs with gaps, fences and pulsing fences at difficulty 0.3, 3 laps of 60 s, opening
    with 80 m of clear roof; no signs, no ceilings yet (phase 3 will need one), no enemies of its own (the cyborgs come
    from its mouth). Its City look hangs none of the towers' big feed screens over the street, since the ship flies there
    (the roof billboards still play the feed). Right mix, and how hard should the arena be under the bombs?
92. **Its sounds** (GDD §11): a flyover roar with a Doppler drop and a power chord, the searchlight's clunk and arc hum, a
    lock's clack and two-tone alarm, a falling whistle, a blast, and the reveal's tube thunk, static and blare. Do they
    fit?

**Big attacks take turns** (from R3; the switch is `big_attacks_take_turns` in `data/tuning/game_rules.tres`, on, F6 "Game
rules"; switched off, the game plays exactly as before; measure with `tools/measure/big_attacks.gd`)
93. **Which attacks count as big** (GDD §9): the Octodog's whole charge sequence (so nothing else attacks between its
    charges), the drone's wind-up and barrage, the hover truck's rev and lurch and its cannon's charge and volley, and the
    Bad Dream's whole chase. Small (not taking turns): a cyborg's burst, a window cyborg's shots, a screech's swipe. Not
    counted: the hover truck's entrance, whose moment the generator plans, so it can't wait (a big attack was open during
    about 13 s of truck entrances over the measured runs). Right list? Should the entrance count (the others would then
    be held off a few seconds before each one)?
94. **When a big attack is over:** when nothing of it can still reach the player: the lunge has passed, the lurch has
    ended, and the last bullet, shell or bolt is 0.5 m behind the player or gone. A warning never waits once it has
    started. OK?
95. **The Bad Dream's chase holds every other type's big attack for its 20–30 s** (§9.7 already held Octodog charges and
    drone barrages; now a hover truck's lurch and cannon wait too). In Golden 3 at 5 lanes a truck arriving mid-chase
    gets one lurch and no cannon shot (3 shots and a lurch without the rule). The other way: count only its slashes, so
    others attack between them. Which?
96. **Who goes first, and how long an Octodog waits:** of the enemies waiting, the one that has waited longest goes next,
    so none waits for ever. While waiting they carry on (a drone follows, a truck holds back or paces; a cannon shot that
    doesn't get its turn before the truck's pacing ends is skipped). An Octodog paces in front of the player and its
    planned charges move on with it for up to 4 s (`turn_wait_max`), keeping the planner's margins; then it runs off as
    before. OK?
97. **Keep the rule after playtesting?** Measured over every campaign level at 3, 5 and 6 lanes (45 simulated runs,
    6,298 s): **without it**, big attacks of different types overlap for 60.5 s in all (61 times in 25 runs; 1.3 s a run
    on average, 7.3 s at worst in Dead Zone 2 at 3 lanes), mostly a drone barrage with a truck's lurch or cannon (40 s);
    **with it**, never. The cost: 12% of the trucks' cannon shots, 6% of their lurches and 4% of drone barrages; no
    Octodog charge or Bad Dream slash lost. One attack in eleven waits: a barrage 1.6 s on average (up to 5 s), a lurch
    3.1 s (up to 9 s, in a chase), a cannon shot 1.6 s, an Octodog 2 s.
98. **The enemies still to come** (proposals for their tasks): Buzz Overdrive's rev and charge are big, but the generator
    plans its cut, so like the truck's entrance it can't wait (the others would be held off before its rev); the
    Resonator's pulse is big; the Gilded Sentinel's halberd swing (its wall section and the outer lane): big or small?;
    the Barnacle Turret's burst is small (its "one fires at a time" stays its own rule); the Tithe Collector isn't an
    attack.

**The ragged screen-head cyborg** (from P2; brief `docs/art/BRIEF_CYBORG_GANGSTER.md`, Variant 1; review with
`tools/showcase/enemy_showcase.tscn`, views `poses`, `faces`, `turn`, `window`, `far`, `charge`)
99. **ERR before the screen goes dark** (brief: proposed): a defeated cyborg's screen shows "ERR" in cold white for 0.2 s,
    then collapses to a bright line and goes dark over 0.14 s like an old CRT (with Reduced flashing it only fades). Its
    death sparks are cold white now (they were orange, close to the player's copper). Keep the ERR; long enough?
100. **The faces' pixel art** (13 × 9 LEDs): calm (square eyes, flat mouth), aiming (brows running into narrowed eyes, a
    long hard mouth), the panic variant's shocked "O", ERR, and the hosts' two corrupted faces (a wide grin; broken eyes
    over a zigzag mouth). Drawn bold so each keeps its shape at about 7 × 5 pixels, as it is 14 m ahead at 720p. Right
    expressions?
101. **Static on the screen:** a faint cold-white static (about 8% brightness) under scanlines, on dark glass darkening to
    rounded corners; the concept sheet's screen is mostly static, but here it stays faint so the face reads. More?
102. **How a host looks** (GDD §9.7): the white face tinged purple over a dim purple wash, blocks of purple static and rows
    jumping sideways; thin purple veins up the neck, down the sleeve onto the hand and along the cyber arm and cannon,
    pulsing slowly (steady with Reduced flashing). They stay a true purple, since brighter drifts toward the fences' pink.
    Right amount, right places?
103. **How strung out it moves:** hunched 11° with the screen raised to look ahead; now and then the head jerks up to
    8–13° in 0.05 s and settles; a fine tremor in the free hand; a shamble dragging the left leg, with the heavy cannon
    arm swinging less. Timings and reach unchanged. Too much, too little?
104. **The window cyborg's window light** is now a dim, cold screen light (the feed on a TV in the room), below the glow
    threshold; it was a warm orange that read like the player's copper and the gap edges. Right?
105. **Details read off the concept sheet:** a grimy grey TV casing with a dented bezel, vents, two knobs and rust; a dark
    leather vest open over an olive-khaki hoodie with a frayed hem and hanging drawstrings; olive cargo pants with
    patches and a thigh strap; scuffed brown laced boots; an olive-grey metal backpack with two black cables into the TV
    and a brown rubber hose (the sheet's is copper) into a rusted-steel cyber arm whose forearm is the cannon; a bare,
    bony left hand. Anything to change?
106. **The cult feed's face now matches the cyborgs' calm face** (GDD §5, "Cyborg Viewing Devices"; item 52): the same
    proportions, smooth instead of LED dots, in the same cold white, so billboards and screen heads show one face. Keep
    them the same?
107. **How much the body stands out on a dark track** (GDD §9.2; deadly parts look deadly): the grimy clothes are much
    darker than the old pale armour on the City's dark roofs, and the olive blends into Gangland's brown street; the read
    at gameplay distance comes from the lit face, the light TV casing and the red emitter ring. A faint rim light would
    lift the silhouette but is a glow on clothing, which the colour rules rule out. Strong enough, or lighter clothes, or
    allow the rim light?

**Quitting keeps 20%** (from R2; the rule is decided, GDD §4; these are how it shows)
108. **What the player sees after quitting:** the pause menu's confirmation now says 20% of the run's credits are kept,
    like a death; after quitting, the game goes straight back to level select (or the title) as before, with a short
    "+N credits kept" note, rather than through the results screen a death shows. A quit also counts as an attempt on
    that level (its tile then reads "not cleared" instead of "new"), though it never improves its best score, stars,
    time or leaderboard place, and it isn't counted as a death in the stats. Right, or should a quit show the results
    screen, or not count as an attempt?

**Music for the four new zones, the death dip and the level-complete riffs** (from D8; levels and tempos in
`data/audio/music_library.tres`, F6 "Music"; `tools/godot.sh music --review` renders review images)
109. **Music style per zone** (FB 54 stays open for a later design round). All placeholders in the crunchy 16-bit /
    heavy-metal style, one seamless loop each, levelled to the same loudness; the menus (100 BPM synthwave), the City
    (160 BPM galloping synth-metal, E minor) and Gangland (120 BPM drop-D industrial, D phrygian) are unchanged. New:
    - **Marketplace:** 144 BPM, B♭ major, 40 s. Bouncy ska-metal: a Mega Drive horn section in thirds over off-beat
      guitar chops, an organ, a walking slap bass; a punk-polka chorus under a soaring horn hook.
    - **Corporate:** 112 BPM, B minor (drop-B), 43 s. Cold cyber-metal: a machine riff of palm-muted sixteenths locked
      to the kick; a half-time march with timpani and a Vangelis-style synth-brass theme; a military snare cadence.
    - **Dead Zone:** 84 BPM, C♯ minor, 46 s. Quiet but never empty: a heartbeat, a ticking pulse, a drone and a lonely
      tremolo guitar with echo, creaking girders and wind; then a slow doom riff that rings out into the quiet again.
    - **Golden Zone** (also the Golden Palace): 132 BPM, F♯ harmonic minor, 44 s. Neoclassical metal: harpsichord,
      strings and timpani under a regal theme, guitar sweeps; no bells or chimes, so it never sounds like the
      Resonator's chime.
    Is each one's direction right for its zone?
110. **The death dip** (GDD §11): as the player dies the track sinks 10 dB over 0.5 s while a low-pass closes to 800 Hz,
    so it sounds far away rather than stopping; it holds under the revive offer and comes back over 1 s on a revive or
    a retry; leaving to the summary crossfades to the menu music as before. With the pause menu's duck, the deeper of
    the two applies. Right depth and muffling? Start at the death (as built) or only when the revive offer appears?
111. **The level-complete riff in each zone's key** (GDD §11): the same shape everywhere (two chugs on the root, one on
    the third, the fourth rings out), on each track's beat and with a touch of its sound: City E E G A (also the
    fallback), Gangland D D F G with an anvil, Marketplace B♭ B♭ D E♭ with a horn stab, Corporate B B D E with a
    brass swell, Dead Zone C♯ C♯ E F♯ dying away with no crash, Golden F♯ F♯ A B with a harpsichord flourish. A boss's
    defeat plays the riff of the music playing. Recognisably the same riff? The Marketplace's uses the major third to
    stay in B♭ major (every other one the minor third): keep it?
112. **The Hush's silent stretches and the music** (GDD §5; task R5): both Dead Zone levels play the same track, whose
    quiet half sits about 4 dB under the other tracks and its doom half about 1 dB over. For The Hush, should its
    level play only the quiet half, a quieter mix, or the music dipped during its silent stretches (the music player
    could dip on the level's signal the way it dips on a death)?

**The Floating Head: the face-off, the towers and the pin** (from E1b; numbers in `data/bosses/city_boss_tuning.tres`;
play it with `--boss=city_boss` in debug builds; showcase scenarios `faceoff`, `fallback`, `pinned`, `mouth`)
113. **The eye lasers' warning** (GDD §10, proposed): for 1.0 s the eyes glow red (red only in the eyes) and whine, while
    thin aiming beams show where it will fire: red aim lines across the street at the beams' heights for a sweep, a red
    spot following the runner's lane for a drag (then the red lane warning as it fires). Does it read? Is 1.0 s right?
114. **High and low sweeps:** a low sweep's two beams cross at 0.35 m (jump them; a slide doesn't pass). A high sweep's
    cross at 0.85 m and 1.9 m, the shape of a gapped fence, so only a slide passes (with one beam at 0.85 m a well-timed
    jump would clear it too). Sweeps cross the street at 13 m/s. Is the gapped-fence shape right for "high", or should a
    jump also get past it?
115. **The drag:** it burns down the runner's lane from about 25 m ahead to the runner in 1.0 s and leaves a burning line
    for 0.8 s (clear of a wall runner beside it). It fires only while a lane beside the runner is free to switch into.
116. **The face-off's rhythm** (with the owner's "not very challenging" in mind): one attack list per phase taken in
    order (for example low, drag, high, drop, drag), the next fair one going first when one can't start; 0.8 s between
    attacks and 0.9 s to move, divided by the phase's pace (1, 1.15, 1.3): about one attack every 3 s, plus a tower
    about every 20 s once baited. These are the numbers to tighten. Should later phases also shorten the warning itself?
117. **The cyborg drop:** it pulls back to 50 m ahead, opens its jaw with a grinding sound for 0.8 s while red target
    circles mark the landing spots, then drops 1 cyborg (phase 1) or 2 (later), each in its own lane with a lane left
    free; they fight like normal cyborgs, so 1 in 3 is the panic variant. Its lasers wait while one is still ahead (up
    to 4 s). Is a red circle right for a landing spot? Should a dropped cyborg never be the panic variant?
118. **A dropped cyborg's burst during an eye laser:** never (one big attack at a time, as in R3's rule). Should they ever
    overlap, say in the last phase, for more challenge?
119. **The marked towers:** a 40 m pale concrete tower whose head juts 2.8 m out over the street (so it shows from far
    along it), with white painted bands, big white target marks (a ring and a cross), dark cracks at the base and cold
    white lights; no hitbox until it falls. One every 300 m on alternating sides, the first 240 m into each lap, with
    the track clear of holes and fences around it. What should the mark look like (never a hazard colour)? How often?
120. **Baiting a tower:** for each tower it pulls back beside it and times a drag so its warning ends as the tower passes
    its face; if the runner is in the outer lane on the tower's side then, the drag clips the tower: a bait, worth 500
    points ("Tower!"), and the runner dodges the drag as usual. 3 attacks come before any tower attempt. Is "be in the
    outer lane on the tower's side when the eyes finish charging" the right rule? Should a tower attempt look different
    from a normal drag?
121. **The fallback:** once 2 towers in a phase go by unbaited, the next tower's drag strikes the tower first, then swings
    into the runner's lane, with no bonus: about 60–70 s into a face-off where the runner never baits. Sooner?
122. **The pinned pose** (E1c needs three ways onto its head: up the fallen tower like a ramp, a wall jump, a drop from a
    ceiling): the tower topples onto the crown behind the weak points; the ship sinks between the trucks until its
    weak points' tops are 2.5 m up (a wall jump peaks about 2.9 m, a truck roof is 2.2 m), rolled 5° toward the tower,
    its face mostly hidden below the roofs; the tower lies diagonally from its stump across the crown. (The other
    options were tilting it nose-down with its face showing, or shrinking it.) Does sinking read? Is a hidden face all
    right while pinned? Should the tower fall so it makes a straight ramp?
123. **Its face-off sounds:** the eyes' rising, throbbing whine ending in a click; the beams' zap and buzz; the jaw's
    grinding ratchet and clank; a cyborg's landing clank; the tower's crack and groan; its crash onto the ship. The
    warnings sound the same every time.
(E1b's placeholder release, the ship shaking free as the runner comes within 12 m, is replaced by E1c's stomp windows.)

**The cyborg zone variants** (from P3; brief `docs/art/BRIEF_CYBORG_GANGSTER.md`, "Zone variants"; review with
`tools/showcase/enemy_showcase.tscn --view=lineup` (`--back`, `--host`, `--face=aiming`), `--view=lineup_far`, and
`--variant=brute|casino|vr_runner|burned|golden`; each skin picks its look with `enemy_variant`)
124. **The Broadcast Brute** (Gangland): the base's TV in a dark steel casing inside a cage of dull brass bars, two small
    side monitors showing a dim cold-white X, a short antenna raked back; a brown work jumpsuit under scuffed brass
    armour; heavy steel arms; a crude pipe gun in the right fist (valve, gas canister, tape). Should the side monitors be
    dim screens like this or unlit dark glass? Brass armour (the brief allows it), or rusted steel to keep brass further
    from Razor Echo's gold arm?
125. **The Casino Mob Enforcer** (Marketplace): a gilded TV engraved with card suits; a black suit with gold pinstripes, a
    gold breastplate, a bandolier, gold pauldrons and knee plates; gunmetal forearms with gold rings; a compact drum-fed
    gun held one-handed along the right forearm (the cyborgs aim with the weapon arm alone; the sheet holds a rifle in
    both hands); no "SPADE" arm cannon. Its screen's LEDs are small diamonds instead of dots. Is the one-handed gun right?
    Are diamond LEDs enough of a casino touch, or should the screen also show dice or card glyphs?
126. **The Golden Zone's ceremonial enforcer:** built from the Casino Mob Enforcer in cream with pale gold pinstripes, a
    red shirt and lapels, a red sash with the Convergent Triad on a medallion (unlit polished gold meeting at a small red
    stone, fading out below about 24 pixels like the skins' marks), gold epaulettes, ivory gauntlets, gold filigree on
    the TV, a gold gun with a red drum; the reds are deep and unlit, well clear of the charge-up's red. Right palette? A
    cream cyborg may blend into the Golden Zone's cream walkways (D6a): would a red tunic be better? Should the Triad be
    worn larger (on the back or the TV's top) so it shows from further away?
127. **The Wide-Aspect VR Runner** (Corporate): a wide headset whose visor is the screen (19 × 7 LEDs, flat and evenly
    lit), with the same expressions redrawn for the wide shape (about 8 × 3 pixels 14 m ahead; the three faces still
    differ there); a high collar over the lower face; a charcoal bomber jacket, olive-grey trousers, chrome hands, a sleek
    chrome arm cannon, an unlit tablet in the left hand. Are the visor's faces right, and do they read at their size?
128. **Posture:** every look moves like the base (hunched, twitchy, limping), since they're one unit; the sheets' Brute,
    enforcer and runner stand upright. Should they stand straighter (same timings and reach), or is the shared
    strung-out posture right?
129. **How burned the Dead Zone's cyborg is:** the base under soot, pale ash on its top surfaces (which keeps its outline on
    dark ground), scorch marks, a shredded hem and ripped sleeve; the screen cracked and flickering at three quarters of
    P2's strength so the face never quite goes out (steady with Reduced flashing); no embers (they would glow a hazard
    orange). More or less burned? Keep the crack?
130. **The other enemies' weathering in the later zones:** drones, hover trucks, Octodogs and screeches weather only under
    Gangland's `scavenger`, so the Marketplace, Corporate, Dead Zone and Golden Zone show their clean versions. Should any
    of those zones (the Dead Zone?) have the weathered versions?
131. **A host's veins on each look:** on the surfaces the player sees (the Brute's chest, neck and both steel arms; the
    enforcers' neck, sleeves and gauntlets; the VR Runner's collar, sleeves, chrome hand and cannon). Right places?
    (Item 102, on the amount of purple, applies to every look.)

**Corporate skin** (from D4; numbers and colours are exports on `CorporateSkin`, F6; play it with
`--quick --skin=corporate --nofall` or `--level=corporate/1`)
132. **Time of day and weather:** a heavy overcast night, a low smog deck lit cold grey from below by the city, no moon or
    stars, fog from 18 m to 190 m. Right for "a more oppressive Blade Runner"?
133. **The brand's colour and mark** (GDD §5: one harsh brand colour, away from the hazard colours): an electric
    ultramarine (about 231°), between the UI's azure (209°) and violet (252°), fully saturated where they are soft; blue
    is the dimmest hue, so it never outshines a hazard. The mark is a rounded square with its upper-right quarter split
    off, generic and soulless on purpose. Approve the colour and the mark? Should the corporation have a name or wordmark?
134. **Gangland's corporate hints** now carry the same mark (containers, crates, ads) but stay off-white and grey. Should
    they take the brand's blue, as lit paint only?
135. **Maglev or plaza, per level** (GDD §5): the zone runs on maglev train roofs; a plaza variant (an elevated deck of
    polished slabs, with a heavier military presence) is built for Corporate 2, Checkpoint Plaza, and used there.
    Right split?
136. **The trains and what a gap shows:** express carriages 22 m long on a per-lane grid, a dark slit between parallel
    trains, olive military freight cars (15%), and the brand's mark painted on 30% of corporate roofs in a flat dark
    blue. A gap is the space between two carriages: the orange edge, then only deep shade below. **Orchestrator's note:**
    the roof marks sit in the running lanes, where cyan anti-grav pads also appear; they're dim and flat where the pads
    glow, but check on a phone that a blue mark never reads as a pad (or keep them off the lanes' centres).
137. **Motion cues on the still floor:** per 40 m, 20 grit and drizzle flecks, 3 paper scraps and 16 speed streaks, plus
    the carriage joints passing underfoot.
138. **The calm band** (GDD §9.1: partial wall fences from this zone): below 7.2 m every wall is flush sterile cladding
    where nothing glows or sticks out, so a pink wall fence never competes; decoration starts at 8 m; the 2 m and 4 m
    wall-run height marks are pale unlit lines. Right heights?
139. **Generic, soulless corporate art:** glass curtain walls and fin towers 44–170 m tall; the brand's glowing sign near
    the top of 45% of towers, banners on 40%, surveillance cameras on 50%, cold light strips up 70% of corners, glass
    skybridges 24–33 m up; wordless ads (the mark, charts that only go up, a turning globe).
140. **The military presence** (heavier in Corporate 2): compounds for 18% of buildings (blast walls with wire, a
    watchtower whose searchlight points at the sky, never the lanes, since a light on the lanes is the Floating Head's
    warning), gunships hovering 40–52 m up, gunships flying low as ceilings, olive freight cars; the plaza raises
    compounds to 30% and hovering gunships to 80%. Right forms and amounts?
141. **The mix of ceilings:** a glass skyway along the street (weight 3.0), a tower bridging the street (2.5), a concrete
    viaduct with a military checkpoint (2.5), a gunship flying low (1.0); every underside a flat plated surface with lamps
    along the lane seams and the orange band at its far end.
142. **How often the cult's emblem hides here:** 35% of the ads on street screens and roof boards (a small warm-white
    badge) and 35% of banners at their foot (unlit bronze); never under 0.9 m, never on a hazard sign, always above 8 m.
143. **How often the cult's feed plays here:** 35% of the big screens (roof boards, and screens hung out over the street
    14–18 m up from 35% of flush towers).
144. **A boss arena over the street** (Hostile Takeover's gunship): setting four shares to 0 clears everything above the
    lanes (street screens, banners, skybridges, hovering ships). The right things to clear?
145. **Hazards in the zone's dress:** fences strung between slim steel security pylons on round base plates or set in
    olive barrier blocks, with the shared glowing bars; hazard signs are corporate screens inside the yellow and black
    frame.

**The campaign's shape: newest things picked most, The Hush, Buzz Overdrive in the Golden Zone** (from R5; the curve in
`data/tuning/feature_recency.tres`, F6 "Feature picks (campaign)"; The Hush in `data/levels/dead_zone_2.tres`; measure with
`tools/measure/level_shape.gd`. Buzz Overdrive is now listed in Golden 1–3, as corrected.)
146. **The recency curve** (P2 13): a pattern's pick weight is multiplied by 4 in the level that introduces its newest
    feature, 2.5 a level later, 1.75 two later, 1.25 three later, 1 from four on. Right shape? Should the oldest features
    drop below 1?
147. **No level gets easier: picks move within a kind.** The curve only moves picks between patterns of the same kind
    (enemy patterns keep the number of enemies they place; obstacle-only and safe patterns keep their shares), so a new
    enemy takes picks from older enemies and a new mechanic from older mechanics. Over 453 layouts a level, no level lost
    more than 0.08 enemies or 0.04 obstacle rows (within noise), and several gained (Gangland 1–3 up to +0.7 enemies and
    +1.7 rows; Marketplace 1–2 about +1.8 rows). The cost: City 2's new ceilings, its only safe feature, gain nothing.
    Is "within a kind" right?
148. **Features the curve leaves alone:** the host, hover truck, drone and Octodog (whose own rules dropped most extra
    picks and left empty stretches: Golden 1 lost 1.4 enemies and 3 rows that way) and the vent screech (rare, §9.5) are
    never boosted. So the curve changes nothing in Dead Zone 1, The Hush, Corporate 2 or the Golden Zone until their own
    new enemies are built, and Gangland 2's new Octodog keeps its old share (fifth). Should any get a boost after all,
    or the Octodog only where it's introduced?
149. **The newest things' shares now:** most picked in City 2 (ceilings 50%), City 3 (pulsing fences 30%) and Gangland 1
    (screeches 33%); second or third in Gangland 3 and Marketplace 1 (generators 14%, from 8%). A feature with many
    patterns can still out-pick a new one with one light pattern. Should the curve set each feature's share directly?
150. **Older features lean on the guarantee a little more:** without the every-feature guarantee, Gangland 2 would lack a
    ceiling or a cyborg in 5 of 27 layouts (1 before); the guarantee still places every feature. Acceptable?
151. **Level weights on top of the curve:** Marketplace 2's vent screeches (2.5×) and Corporate 2's military (1.5×
    drones, hover trucks and Buzz Overdrives) still apply and are now all that favours them. Keep both?
152. **The Hush's quiet stretches and bursts** (GDD §5): 14 s quiet stretches with no enemies but hosts, alternating
    with 7 s bursts of threats only, patterns 0.9 s apart (the spacing other levels reach only at full difficulty).
    Per level: 10.9 enemies besides hosts (21.2 before) and 34 obstacle rows (41); many of its features now come only
    from the guarantee (no Octodog without it in 24 of 27 layouts). Right lengths and densities? Tighter bursts (not
    playtested)?
153. **Threats that outlast a burst:** a hover truck, a drone or a Bad Dream chase starting in a burst carries on into
    the next quiet stretch; an Octodog, needing a clear floor, lands in a quiet stretch about half the time. Acceptable,
    or should a quiet stretch wait until they're gone?
154. **More Bad Dream chases** (a chase only starts when the player kills a host on purpose, §9.7): The Hush has 1.45 hosts
    a level (Dead Zone 1: 1.09), two or three in 42% of layouts, all in quiet stretches where stomping, clawing or dashing
    into them is easy (hosts picked 12.5× as often). The host rules allow one chase at a time and none across the first
    drone wave, so three is the most in practice. More chases would need shorter chases, fewer or later drones in The
    Hush, or more reason to kill a host (a bigger bonus). Which, if any?
155. **Darker lighting:** The Hush's `darkness` 0.7: the scenery gets 51% of its light (floor about 23% darker on screen,
    sky about a third), never below 30%; glows, the runner and the enemies keep theirs. Right amount? The Dead Zone skin
    (D5) sets the zone's own palette and the darkness applies on top.
156. **Music in the silent stretches:** see item 112; the generator can list the stretches for the music player.
157. **The Octodog's wait for its turn** (R3's rule): a dog held for another type's turn keeps asking until its turn
    comes, and if the wait made it miss its clear stretch, its charges move on until the stretch ahead is clear, within
    the same 4 s; then its usual 40 m of slack runs. So a dog may pace ahead for up to about 6 s before its first charge.
    Fine, or should it re-plan further ahead? (A rarer case remains: on 3 of 277 dogs over extra seeds, none on the
    campaign's own, a drone's repeated barrages keep a dog from its turn; a follow-up gives a waiting enemy its place.)

**The Floating Head: the stomp windows** (from E1c; numbers in `data/bosses/city_boss_tuning.tres`, groups Stomp windows,
Ramp window, Ceiling window; showcase `floating_head_showcase.tscn -- --scenario=faceoff --towers-after=0 --phase=0|1|2`,
or `--scenario=window|missed`)
158. **The fallen tower as a ramp** (GDD §10): as the tower crashes onto the ship, a broken slab of it (pale concrete, a
    row of its windows, a torn top end) slams into the weak point's lane nearest the tower's wall, 14 m long, its top
    resting just past the ship's face 0.8 m above the crown, with the City's green ramp chevrons up its middle; it gives
    no boost. The runner runs off its end onto the weak point (a jump at the top overshoots). Does green read right on a
    tower that isn't a ramp pad, or should it be white paint? Is "run off the end" the skill?
159. **The tower breaks as it lands:** lying from its stump across every lane it would block every route and cover a
    weak point, so it breaks 2.5 m behind the weak points: the part behind stays on the ship's back, the part in front
    drops away in dust (its slab makes phase 1's ramp). Does it still read as the same tower?
160. **The weak points:** one over each lane near the ship's centre line (3 at 3 and 5 lanes, 4 at 6), red domes that
    rise as armoured covers swing back, pulsing slowly (steady with Reduced flashing), with a hiss and a rising
    four-note "target" arpeggio; a stomp counts over a generous box (2.0 m wide, 3.0 m along, up to 0.55 m above the
    socket). Right number and size?
161. **Pinned, the ship is the way up's floor** (collision stays physical): its crown is a floor exactly where it's drawn
    and its hull stops being deadly (the window closes before a runner on the trucks can reach its face); it rolls 5°
    toward the tower, so the tower-side weak point sits lower and that side is easier. All right?
162. **When a window closes** (no timer, no escalation): once the runner is still on the trucks within 8 m of its face
    (no jump from there reaches a weak point) or 1 m past the weak points, it shakes free (lurching 8 m further ahead
    and up, so a runner on its crown drops off behind), rises back in front and the face-off goes on, with the same
    window next time. The wall route means committing before the 8 m line. Right lines, and is it clear enough that the
    chance is gone?
163. **After a stomp:** a distorted, glitching mechanical scream through its loudspeakers, red sparks and its face
    glitching, the same lurch free, then the rise to the next phase. The right sound, or should it carry the propaganda
    voice (E1d)?
164. **The wall jump** (phase 2): a wall jump off a fresh wall entry peaks about 2.9 m, reaching the weak points from
    either wall at every lane count (at 5 and 6 lanes with a second move inward in the air); the wall away from the
    tower is harder. Right difficulty? The wall jump also works in phases 1 and 3: should the walls be taken away there
    so each phase's own way is the only one?
165. **The ceiling** (phase 3): as the tower falls, pads light up in every lane 26 m before the ship's face (about 1.6 s
    to see them, with a sound), and a City ship underside lowers in from 9 m above once the ship's face is past its end,
    ending 5.5 m before the face; the drop off its end lands on the weak points at every lane count. Pads in every lane
    (a runner can't miss them unless they jump)? Should the ceiling arrive another way (a ship flying in overhead)?
166. **The order of the ways up** is data (ramp, wall, ceiling, as the GDD lists them); a missed window always comes back
    the same way, never harder and never easier. Should a struggling player ever be offered an easier way?
167. **Pickups and the pin:** an armor pickup falling due while a tower is lined up or the ship is pinned waits until
    it's back in the air (up to about 8 s), a marked tower whose pin would land on a pickup or a dropped cyborg goes by as
    scenery, and a cyborg still under the ship as it crashes down is crushed. All right?
168. **Weapons:** with 300 health and the framework's 34% cap, weapons alone can end one phase and no more. With the
    owner's "not very challenging" in mind, should they be slower still?
169. (E1d brought a perfect run to about 101 s: see item 201.) **The fight's length** (GDD §10: 60–120 s): a runner who never misses takes about 134 s (a 17 s first bombing run,
    two 9 s later runs, three face-offs until a tower, three windows). To tighten it: shorter or fewer bombing runs,
    fewer attacks before a tower, or towers closer together? (Task E1d brings it inside 60–120 s as a placeholder.)
170. **Edge cases after a lost window:** at 3 lanes a runner sliding down a wall beside the pinned ship lands inside its
    hull for a moment before it shakes free; at 6 lanes a drop off the ceiling into the outer lane on the tower's side
    lands where the rolled hull dips under the roofs. Both only after the chance is gone, and nothing hurts. Acceptable?

**Golden Zone skin** (from D6a; numbers and colours are exports on `GoldenSkin`, F6; play it with
`--quick --skin=golden --nofall` or `--level=golden/1`; the statue kit in `tools/showcase/statue_showcase.tscn`)
171. **Time of day:** the blue hour: a deep blue sky over the warm afterglow of the set sun, a pale moon, the white
    palaces floodlit from their entablatures, warm lamplight on the calm band. (In full daylight the hazards' glow washed
    out against the white; at night the white turned grey.) Right hour?
172. **The walkways over water:** each lane its own walkway of deep, satin-burnished gold plates between polished gold
    rails, over a dark canal 5.5 m below flowing toward the player; a gap is a missing stretch with the usual orange lip
    on the collision edge, glowing as brightly as the Marketplace's (a lit gold floor swallows a dimmer edge), a soft
    halo on the far edge, and deep shade below. The gold is kept well below the cream cyborgs in value and saturation so
    they stand out (a more polished deck paled right where they stand). Right look?
173. **Motion cues over water:** per 40 m, 55 motes of mist, 10 flakes of gold leaf and 12 speed streaks drifting toward
    the player, with the plate seams streaming past and the canal flowing in the gaps. The right equivalent?
174. **The facades and the calm band:** every face flush up past the wall-run band (polished granite, then calm stone to
    7 m where nothing opens, lights up, sticks out or looks like a vent or a niche, since vents and niches mean screeches
    and Sentinels here), gold inlay lines at the 2 m and 4 m wall-run heights, a gold frieze to 8.6 m; above it white
    palaces with gold-framed windows and balconies, galleries of gilded frames, and champagne-glass towers on gold fins.
    Right?
175. **The statues** (GDD §9.11): a 2.6 m gilded guardian in faceted ceremonial armour with a crested helmet and a 2.95 m
    halberd, future rather than historical; three decorative poses and two swing poses for C4's live Sentinel. Decorative
    ones stand on the palaces' ledge with their feet 8.8 m up (a wall run reaches about 5.8 m), every 5.2 m, 90% filled.
    Right look, height and density?
176. **The cult's emblem, shown openly** (GDD §5): in polished gold meeting at a red stone, on red banners on 60% of
    towers, in relief on 70% of the towers rising over the building before them, on a crest on every golden bridge and
    the archways' keystones, on the sky bridges, in the galleries' frames, and inlaid as medallions in the walkways; drawn
    large because marks fade out below about 24 pixels. How openly, where, and how often?
177. **The retuned gold** (`CultEmblem`): the old placeholder gold read as sign yellow once lit, so it's now a paler,
    half-saturated gold meeting at a deep ruby stone, the same gold the whole zone uses. Approve?
178. **The cult's feed here:** in 30% of the galleries' gilded frames and on big screens hung over the street from 35% of
    towers (a boss arena can turn those off). Right places and amounts?
179. **The ceilings:** golden bridges with coffered undersides and a crest (over fewer lanes, a suspended gallery on gold
    beams; weight 4.0), a gallery of parabolic golden arches (full width only; 3.0), a hover-yacht of the elite (2.0);
    flatter and shorter over narrow streets so nothing cuts through the walls' statues and frames. Right mix and forms?
180. **Waterfalls off the ceilings** (GDD §5: scenery only, sparse): on half the bridges, water pours off the bridge's face
    into gilded troughs beside the crest, always above the underside, never over the floor or the wall-run band; 3-lane
    streets have no room for them. What the owner means, and sparse enough?
181. **Over the street:** sky bridges slung between towers 24–30 m up in 70% of stretches where towers stand on both
    sides; hover-yachts as ceilings. Enough future?
182. **Red accents:** besides the banners, frames and the yachts' stripe, half the lit windows show red velvet drapes.
    Enough red?
183. **Hazards in the zone's dress:** fences between marble-and-gold stanchions with pink emitters; signs are boutique
    boards (cream, midnight blue, black lacquer, ivory with gold lettering) in the yellow/black frame (a crimson board was
    dropped, since a glowing red reads as a hazard). OK?

**The Resonator** (from C3; numbers in `data/enemies/resonator.tres`, F6 "Enemy: Resonator"; review with
`tools/showcase/resonator_showcase.tscn` (`--view=model|play|close`, `--skin=golden`, `--double`, `--wall`), or quick
play with `--features=resonator --skin=golden`)
184. **The look** (GDD §9.10): a faceted, double-ended golden mast with ivory collars and three small vanes at each end
    (the emblem's three-fold symmetry), opening in the middle into a cage of gold ribs around a red crystal core (the only
    part that always glows); three halos of gold arcs tumble slowly at rest. No bell, chain, cross, candle or steeple
    shape. 5.2 m tall. Right look?
185. **The warning:** 1.3 s. The halos spin up and swing into line facing the runner, one on each of the chime's three
    notes, ending as a red target, while the core and trims glow brighter; the wave leaves at the end and reaches the
    runner about 1.1 s later (about 2.4 s from the first note). Steady glow with Reduced flashing. Right length and look?
186. **Distance and size (please look at this one):** it hovers 34 m ahead, its core 3.1 m up (too high to stomp). On the
    Golden skin's bright facades the red target is small at that distance (about 40 pixels across at 960×540), so the
    chime and the visible approaching wave carry most of the warning (frames: C3's `build/sheets/resonator_golden.png`).
    Closer, or larger? (`hover_ahead`, `model_scale`, F6.)
187. **The wave:** a straight, low red crest across every lane (a ring 34 m out crosses the track almost straight), rolling
    at 11 m/s early to 14 m/s late. Its hitbox is 0.45 m high: a jump started 0.1–0.6 s before it arrives clears it; a
    slide doesn't; wall and ceiling riders are safe. Right shape, speed and height?
188. **Pulses and scaling** (later in the zone it pulses faster or sends double waves): both. 3 pulses early to 4 late, a
    rest of 2.2 s to 1.2 s between pulses, and up to half the pulses doubled late (the second wave 0.9 s behind, inside the
    hit invulnerability, so armor that blocks the first covers the second); a level's first pulse is always single.
    Right counts and ramp?
189. **Toughness:** 15 health (15 laser tier 1 shots, like the Gilded Sentinels), score 400; no contact hitbox (like the
    drone); shot down, a wave still rolling fizzles out. Right?
190. **Protection:** armor and the shield block a wave (GDD §9.10), and the dash passes through it like any enemy attack.
    Right for the dash?
191. **A big attack** (item 98): from its warning until its last wave has passed, a pulse is a big attack; it waits for
    other types' turns (moving its visit on) and after 8 s of waiting drops its remaining pulses, never its first. Over
    Golden 1–3: no overlap with turns on; 10 of 44 pulses waited, 0.8 s on average. Right?
192. **Never a wave on a gap or a fence:** from 0.6 s before its wave meets the runner until 0.6 s after, no gap, live
    fence, floor enemy, pad, ceiling landing or speed pad in any lane, so a jump always has solid floor to leave from and
    land on; re-checked before each warning. The right stretch? Should a speed pad count?
193. **Where visits go:** one Resonator at a time, at least 6 s apart; no pulse planned during an Octodog's run; drones,
    hover trucks and chases take turns with it at run time. About 2.6 visits of 3 pulses in Golden 1, 1.8 of nearly 4 in
    Golden 2 and 3. Measured over 21 seeds at 3, 5 and 6 lanes, a visit's clear floor trades obstacle rows for waves:
    Golden 1 has 38.7 obstacle rows a level (45.4 before the Resonator) and 17.3 enemies with the Resonators (16.8),
    Golden 2 42.1 (48.0) and 17.2 (17.5), Golden 3 42.4 (48.0) and 17.6 (17.7), for about 8 waves to jump a level.
    Right amount, with the balancing pass (R7) in mind?
194. **The recency curve leaves it alone** (like item 148): boosted, its one-at-a-time rule dropped a third of its picks and
    left empty stretches (Golden 1 lost 1.9 enemies and 3.4 rows), so it's capped. Should the Golden Zone's newest enemy
    get a boost after all (fewer, longer visits, or visits placed by its rules)?
195. **The chime and its sounds** (GDD §9.10): soft mallets on tuned metal bars with a glassy shimmer, rising G5, C6, E6
    (a bright major triad, far from the Golden music's F♯ minor), the same every time; the pulse a deep thump and a rush
    rolling in along the floor; its death the chime bending out of tune and shattering. Right notes and feel?
196. **One on screen at a time:** a Resonator arriving sends the last one away after its current pulse. Right?
197. **The hint:** "When the Resonator's chime plays, a red wave rolls along the floor. Jump it ({jump}), or be on a wall or
    the ceiling." Right wording?

**The Floating Head: propaganda, defeat, and the finished fight** (from E1d; the fight now plays in the City's boss
slot; numbers in `data/bosses/city_boss_tuning.tres` and `data/bosses/city_boss.tres`; showcase scenarios `slogans`,
`defeat`, `wreck`)
198. **The slogans** (GDD §10: a few short slogans on its face screen, so only they need translating; the owner writes
    them). Placeholders after GDD §5's "every path leads to him": "EVERY PATH / LEADS TO HIM", "STAY / ALIGNED",
    "DON'T RUN. / CONVERGE.", "HE SEES / YOU", "RETURN TO / THE FEED": two lines of at most 12 characters in the UI's
    display font on a dark band across the face, under the eyes (the lasers' warning) and above the mouth (the drop's
    warning); ready for translation once the game has it. Their words, how many, and where on the face?
199. **The propaganda voice** (GDD §10: heavily distorted, not meant to be understood): four phrases of made-up
    syllables with an announcer's rise and fall, a deep voice through a blown loudhailer, starting at the reveal, 1.5–3.5 s
    apart, under its warnings in level. It never masks a warning: while an attack warns or strikes, a cue sounds, a
    dropped cyborg is about or a pulsing fence is near, it ducks 18 dB at once and the slogan fades; so it's heard mostly
    between attacks (about 12 phrases in a 100 s fight). The right character and amount? Pause rather than duck?
200. **The defeat** (GDD §10): the last stomp's cry is the propaganda cutting out mid-shout (it stutters, dives like a
    stopping tape and dies in static). It shakes free, lurches ahead with its face tearing into static (steady with
    Reduced flashing), loses power (the face collapses to a line and goes dark) and crashes into the street at the first
    clear stretch ahead: a dust cloud and a heavy shake, no flash. Its cracked, dead face falls flat before the wreck, and
    its stern half lies across the street like a tunnel the runner runs through (dark metal, cold white sparks, grey
    smoke, nothing in a hazard colour, nothing that hurts); its bow vanishes in the dust. Does the tunnel read as "runs
    through the wreck"? Should the bow stay, and should the fallen face show something (a last slogan, a frozen frame)?
201. **The fight's length** (60–120 s): a 16 s first bombing run, two 8 s later runs, marked towers every 240 m, two
    attacks before it aims at a tower, and the laser clipping every other tower on its own for a runner who doesn't bait
    them. A perfect run takes about 101 s at 3, 5 and 6 lanes; a struggling one (never baiting, missing each phase's
    first window) about 234–254 s (no time limit, no escalation). Right, or should a struggling run be shorter?
202. **Par times** (GDD §10, proposed): three stars under 110 s, two under 150 s, so a perfect run gets three and a run
    that misses a window or two gets two.
203. **After the win:** the results come 2 s after the runner reaches the fallen face; meanwhile the runner is safe (the
    framework's rule), so fences in the way are harmless, but a hole still ends the run early (the win counts). Should the
    street to the wreck be clear, or its fences go dark as it crashes?

**Dead Zone skin** (from D5; numbers and colours are exports on `DeadZoneSkin`, F6; play it with
`--quick --skin=dead_zone --nofall` or `--level=dead_zone/1` (`dead_zone/2` is The Hush); the Bad Dream's chase
through it in `tools/showcase/bad_dream_showcase.tscn -- --skin=dead_zone`)
204. **Time of day:** a smoke-choked night: a low pall of smoke, an ash-grey haze on the horizon with the ruins in dark
    silhouette against it, smoke columns faintly lit from below by distant fires, a veiled moon. Distance fades into the
    haze (lighter than the ruins), so the black Bad Dream and the burned cyborgs read as dark silhouettes against it.
    (The Sleep Taker's defeat brings "the first grey dawn light", GDD §10.) Right hour and mood?
205. **The rubble street and its holes:** broken road plates under pale ash, worn lane lines mostly buried, rubble drawn
    flat (nothing on the running surface stands up like an obstacle), no round shapes (a manhole means a screech). A gap
    is a collapsed hole with the usual orange edge and a soft halo on its far edge, deep shade and a dark void below; the
    ash-grey street is the zone's lightest surface, so a hole reads at a glance. Right look?
206. **Motion cues:** per 40 m, 70 ash flakes drifting and falling, 7 faint smoke puffs drifting low and rising, 12 speed
    streaks, with the plate seams and rubble streaming past. Right equivalent?
207. **The ruins and the calm band:** the Neon City's own towers, gutted (burnt-out window grids, dead neon banners and
    roof boards, broken skybridges, tops sheared off, 40% burnt down to their steel frames); every face flush and closed
    up to 7.2 m (nothing that opens, lights up, sticks out, or looks like a window cyborg's window, a vent or a manhole),
    with faint lines at the wall-run heights. Right look? More destruction (whole blocks gone, open sky) would need open
    lots, which no zone's walls have yet.
208. **Embers** (fires kept minimal): in 35% of towers, a few rooms smoulder 16 m up or higher, a dull orange kept below
    the bloom threshold and under a third of a gap edge's brightness, breathing slowly (still with Reduced flashing); none
    near the play field. Too many, too few, or none?
209. **Smoke columns** billow slowly up from the broken tops of 22% of the ruins 20 m tall or more. Right amount?
210. **The ceilings:** across every lane a crumbling charred bridge (a wreck and a toppled lamp post on its deck) or a
    dead tower's burnt-out upper storeys; over fewer lanes a floor slab broken off the tower it reaches, or a collapsed
    span hanging from a steel gantry. Every underside is flat charred concrete with the orange band at its far end.
    Right mix and forms?
211. **The cult's emblem here:** in its unlit bronze, scorched and half-gone (a ragged burn front across it), on 40% of the
    dead roof billboards and at the foot of the dead neon banners. Is a burnt remnant of the cult right here, and how
    much?
212. **The cult's feed on surviving screens** (proposal): it still plays in the dead city on a few surviving screens, dim
    and high up (20% of the roof boards, big screens hung from 12% of the towers, 15 m up or more; about 16 over 3 km).
    The burned cyborgs' flickering screens suggest the broadcast still reaches them. Should it play here at all, and
    this sparsely?
213. **Broken skybridges:** a stub from each wall 18 m up or more, broken off short of the middle, in half the stretches
    where towers stand tall on both sides. Enough future in the ruins?
214. **Hazards in the zone's dress:** the same pink fence between charred steel posts in rubble or wreckage; signs are dead
    billboards (a cracked dark screen or a burnt poster, unlit) in the yellow/black frame. OK?
215. **The other enemies' look here** (only the cyborgs have a Dead Zone variant, GDD §9.2): drones, hover trucks,
    Octodogs and screeches keep their clean look. Burnt or weathered here too? (Item 130 asks the same across zones.)
216. **The Hush's darkness** on this skin: every piece dims with it; on screen the street goes from about 80 to 56 in grey
    value and the walls from 40 to 20, while hazards, triggers and enemies stay as bright. Dark enough? (Item 155.)

**Narrow ceilings** (from B3; numbers are exports on `LevelConfig`, group "Narrow ceilings", F6, values in
`data/levels/*.tres`; review with `tools/showcase/skin_review.tscn -- --narrow` (any skin, `--lanes=3`,
`--view=shot`, `--reduced-flashing`) or play `--level=city/3`, `--level=gangland/1`,
`--quick --features=ceilings,cyborg --lanes=6`; measured over every campaign level on 9 seeds at 3, 5 and 6 lanes)
217. **How often, and where they first appear.** Placeholder: `narrow_ceiling_share` 0.5 in every
    campaign level from City 2 on (half of a level's ceilings are narrow; City 1 has no ceilings) and in
    quick play's level (`prototype_level.tres`); 0, the default, wherever a level file doesn't set it (a
    boss arena's laps, for one). City 2, which introduces ceilings, keeps its first
    half full width (`narrow_ceiling_start` 0.5), so ceilings come first and narrow ones later in the
    level. Measured: City 2 has 0.6 to 1.0 narrow ceilings a level (13–25% of its ceilings, the first at
    61–78% of the level, in about half its builds), City 3 1.4 to 1.6 (about 45%), Gangland 1 and 2 1.0
    to 2.0 (37–60%), and from Gangland 3 on, where ceilings are common, 3 to 6.6 a level (38–52%). A
    level generates exactly as before with a share of 0. Is City 2's second half the right place to
    introduce them (GDD §5: each level introduces about one new thing, and City 2's is ceilings and
    pads), or should they wait for City 3 or Gangland? And is half of a level's ceilings the right
    amount?
218. **Widths.** Placeholder: 35% of narrow ceilings cover one lane (`one_lane_ceiling_share`); the others
    cover from two lanes to all but one (`narrow_ceiling_max_lanes` 0; a number caps it), each width as
    likely, placed anywhere that holds their pads. At 3 lanes that means one or two lanes; at 5 and 6 lanes
    every width comes up. Right mix? Should wide streets lean toward some widths (for example no five-lane
    ceiling on six lanes, which reads almost like a full one: `narrow_ceiling_max_lanes` 4)?
219. **One-lane ceilings: very short and relatively safe.** Placeholder: 1.6 s from the pad to the end
    (`one_lane_ceiling_seconds`; a plain pattern's ceiling lasts 4 s). A pattern's ceiling can be one lane
    only if the pattern puts nothing else on the track (just the ceiling and credits), so a gauntlet's
    ceiling, which is an escape from what's under it, always keeps a second lane; the rules' ceilings
    (a drone's pads, a Bad Dream chase's) can be one lane too, over whatever the floor held there (b2's
    placeholder). No hazards ride on them (GDD §9.8: never a Barnacle Turret on a one-lane ceiling), and
    the drop lands on safe floor (item 221). Right length? Should a rule's ceiling always keep two
    lanes as well?
220. **A move toward a lane the ceiling doesn't cover.** Placeholder (`Player._bump_ceiling_edge`,
    DESIGN-TBD): blocked, with the same feedback as a lane switch into a solid side: the runner bumps out
    toward that side and back (stopping short of the ceiling's edge, so it never looks like stepping off)
    and the blocked wall entry's clank plays (`ceiling_blocked` event, `wall_blocked` sound). A lane
    switch still under way from the floor when a pad lifts the runner ends in the pad's lane the same
    way. Right look and sound? Should the edge of a narrow ceiling show something more, such as a lit
    rim along its sides (today its sides show only the skin's own edge: a hull's side, a slab's broken
    edge)?
221. **Landing and the floor around a narrow ceiling.** Placeholder (`CeilingZones`): the safe landing
    zone (1.2 s after the end, B2's placeholder) keeps holes and fences out of the lanes the ceiling
    covers, since its rider can only drop from those; the other lanes keep what their patterns put
    there. Floor enemies still keep off the landing zone in every lane. The floor route under every
    ceiling stays survivable without the pad (checked on every campaign level). Right?
222. **The rules' ceilings are narrow too.** Placeholder: a drone wave's pads and a Bad Dream chase's pads
    get narrow ceilings at the level's share, over the pad's lane. A chase's one-lane ceiling lasts 1.6 s
    instead of 3 s; its pads still come as often, so the Bad Dream's refuge is there as before. Right?
223. **Credits on a narrow ceiling.** Placeholder: the usual line along the pad's lane and the rich credit
    in the ceiling's far lane (the lane of the ceiling furthest from the pad's); a one-lane ceiling has
    only the line. Credit trails on the floor skip only the lanes a ceiling covers. Right?
224. **Drones hurled into a narrow ceiling** (GDD §9.6: stepping on a pad hurls every drone on screen up
    into the ship's hull). Placeholder (`Drone.hurl_x`): a drone not under the ceiling veers into its lanes
    as it rises and crashes 0.8 m inside its edge. Right, or should a drone that isn't under the ceiling
    just crash upward into nothing?
225. **The City's narrow ceilings: a smaller craft** (`CityShip`, `small`). Placeholder: built from its lanes
    like any ship, with a lower hull (sides rising 30% of its width, 1.3–2.0 m, against a full ship's
    2.6 m), a deck on top, a shorter, sharper bow with a dark glass canopy over it and a light strip along
    its rim, smaller headlights, and one engine per lane (two at most). Right look?
226. **Gangland's narrow ceilings: a slab broken off a building** (the owner's review, P2 18;
    `GanglandCeiling`, `Kind.SLAB`). Placeholder: a 0.6 m thick floor slab with broken edges, rebar sticking
    0.5 m out of them, rubble, broken column stubs and a piece of wall still standing on it. A side that
    reaches the street's edge stays lodged in the building face there; a slab that reaches neither side
    hangs from torn, bent steel beams of its building's frame, running up to the building faces on both
    sides 2.4 m above its top. Right look?
227. **The other zones' narrow ceilings.** Placeholder: each builds its kinds from the ceiling's lanes. In
    the Marketplace a building bridging the street needs both walls, so over fewer lanes it becomes an
    overpass; its merchant ships and floating ads just build narrower. In the Corporate zone (and its
    plaza) a tower across the street becomes a viaduct over fewer lanes; skyways and gunships build
    narrower. In the Dead Zone (D5, which built its own) a narrow ceiling is a slab broken off the tower on
    the side it reaches, or a fallen span hanging from its gantry in mid-street. In the Golden Zone (D6a) a
    bridge over fewer lanes is a gallery hung on gold beams, and the arches stay full width only. The grey
    box shows a plain slab. The orange end band spans the ceiling's lanes in every zone. Right?
228. **The camera at a ceiling's end.** Dropping off any ceiling's far end used to flash an orange wash
    and a glare (about a quarter of a second in a 30 fps capture): the chase camera rose after the
    falling runner and passed through the ceiling's end, and the end band's glow card reached 1.5 m past
    the end below the underside. Now the
    camera stays at least 1 m under any ceiling over it, just beside it, 2.5 m ahead or until 3 m past
    its end (`MovementTuning.camera_ceiling_clearance`, F6), and every zone keeps what glows past a far
    end above the underside, fading as the camera comes within 4 m (the band's glow) or 8 m (engine
    glows). The band itself is unchanged. For a moment after a drop the view sits a little lower than
    before. OK?
229. **No hint, no recency boost.** Placeholder: narrow ceilings aren't a feature of their own (they
    aren't in a level's `features`), so they get no first-encounter hint (`data/hints/hints.json`) and
    the campaign's recency curve (R5) doesn't boost them after they first appear. Narrowing a ceiling
    takes nothing from the level: ceilings over two lanes or more leave the patterns as they were (the
    same ones in the same spots, and a narrow ceiling's landing zone clears only its own lanes), and a
    one-lane ceiling is shorter, so what follows it comes a little earlier.
    Should they get a hint (for example "Some ceilings cover only a few lanes: you can only move within
    them.") or be introduced like a feature?

### Answered (recorded in GDD_CHECKPOINT.md)
- Wall entry follows the jump grace rule (§3, September 25, 2026).
- ~~Ceilings never carry obstacles underneath (§3, September 25, 2026).~~ **Reversed September 26, 2026:** the floor under a ceiling may be dangerous; only the landing zone must be safe (§3). The generator's "floor under a ceiling is clear" rule and test need changing, as does the drone-pad rule that removes floor pieces and enemies under a pad's ceiling (item 75).
- Mobile orientation is landscape (§2, September 26, 2026).
- Zone 1 is the Neon City, Zone 2 is Gangland (§5, September 26, 2026).
- Bosses are standalone mini-games; short cinematics sit between levels and zones. Both are designed later, and the build leaves slots (§6, §10, September 26, 2026).
- The player is a human runner in a cyber suit, about 75% of the grey-box size (§11, September 26, 2026).
- Music: code-generated placeholders for now (§11, September 26, 2026).
- The cult's symbol and colour: the Convergent Triad, option B of the D7 sheet (§5, September 26, 2026).
