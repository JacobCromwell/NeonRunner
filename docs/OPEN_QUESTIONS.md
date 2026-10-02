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

**Big attacks: a waiting enemy keeps its place** (from R3b; `turn_place_grace` in `data/tuning/game_rules.tres`, F6 "Game rules"; measured with `tools/measure/big_attacks.gd` over 741 runs)
230. **How long a waiting enemy keeps its place** (GDD §9, "Big attacks take turns"). The enemies waiting go in the
    order their waits began (R3's rule), but an enemy lost its place as soon as it was told it may go, or two frames
    after it last asked. An Octodog told it may go while the stretch its wait had moved its charges to wasn't clear
    yet paced on without charging, and once its 4 s `turn_wait_max` was used up it stopped asking: another type ready
    again (a drone's next barrage, a hover truck's cannon or lurch) went first, and the dog's slack ran out. On main
    this kept 3 dogs from ever charging before B3 (Golden 3 at 5 lanes, seed 9004; Dead Zone 1 at 5 lanes, seed 9017;
    Golden 3 at 6 lanes, seed 9019) and 4 after it (Dead Zone 1 at 3, 5 and 6 lanes, seeds 9007, 9017 and 9001;
    Golden 3 at 5 lanes, seed 9003).
    **Placeholder:** a waiting enemy keeps its place until its attack starts or it gives the attack up, as long as it
    keeps asking: through its turn too (told it may go, one that isn't quite ready and asks again still goes before
    those that waited less), and through a gap in its asks of up to `turn_place_grace` = 1 s
    (`data/tuning/game_rules.tres`, F6 "Game rules"; `DESIGN-TBD` in `scripts/core/game_rules.gd` and
    `scripts/enemies/enemy_director.gd`), while those behind it wait. After a longer gap it loses its place and the
    others go. An enemy that means to wait longer keeps asking: an Octodog that waited for its turn now asks every
    frame until it charges or its slack (40 m) runs out. An enemy that gives up says so and leaves the queue at once:
    an Octodog running off, a hover truck changing state (its pacing ended before its cannon's turn came, and the
    shot is skipped as before; or it leaves), a Resonator leaving, a dissolving Bad Dream.
    **Measured:** all those dogs charge now, after waits of 4.4 to 5.7 s. The dogs still without a charge (Gangland 3
    at 5 lanes, seed 9015; after B3 also Dead Zone 2 at 6 lanes, seed 9003) don't charge with turns off either: not a
    turn problem. Big attacks still never overlap, and no other enemy newly goes without its attack: run by run, as
    many drones (10, after B3 12, of about 810), hover trucks (about 20 of 810 never lurch, about 20 never fire) and
    Resonators (1, after B3 3, of about 350) as on main never get theirs in. 16 of the 741 runs play differently
    before B3, 17 after. The others lose a little: 7 (after B3: 4) fewer drone barrages of about 4,800, 1 (2) fewer
    cannon shots of 1,840, 2 (2) fewer lurches of 1,390; Resonators pulse 3 times more and once less before B3, 3
    times less after (of about 1,050). Waits for a turn barely change (from the first frame an enemy is held for
    another type's attack until its attack, a dog's until it charges; before B3): dogs' charges 86 → 89 waits, mean
    1.60 → 1.70 s, longest 5.60 → 5.72 s; drone barrages 853 → 865, mean 1.48 → 1.49 s, longest 7.7 → 9.5 s;
    Resonator pulses 235 → 236, mean 2.32 → 2.30 s, longest 22.6 s both; the hover trucks' and the Bad Dream's about
    as before (after B3 only the dogs' change: 88 → 92 waits, mean 1.55 → 1.65 s). A kept place cuts both ways: on
    Golden 2 at 6 lanes (seed 9014) a Resonator waiting for clear floor held the drones back for its 1 s and pulsed
    10 s sooner than on main (where two drones' barrages had kept it waiting 14.5 s), and a drone waited 9.5 s
    instead; but on Golden 1 at 6 lanes (seed 9006), and after B3 on Golden 1 at 3 lanes (seed 9015), the drone a
    Resonator held back fired that much later, over the Resonator's next clear moment, and the Resonator dropped one
    pulse of that visit (two after B3).
    Tried first: a 3 s grace, which fixed the same dogs but changed three times as many runs (12 of the first 489
    runs measured, against 4) and cost more of the others' attacks there (2 drone barrages, 2 lurches, a cannon shot
    and a Resonator pulse, against a lurch and a pulse).
    Right rule? Is 1 s the right "moment"? A longer grace makes the others wait longer for an enemy that isn't ready;
    a shorter one lets them pass it sooner. Or should an enemy in a gap keep its order without holding the others
    back (they may go while it isn't ready; when it asks again it still goes before those that began waiting after
    it)? That should spare the Resonators' pulses above (not measured), and the dogs would still charge (they keep
    asking), but a turn that comes during the gap would go to the others. And the cost of the dog's place: while it
    moves its charges on to a clear stretch, the others wait for it, up to its 4 s `turn_wait_max` plus its slack
    (about 2.2 s at run speed).

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
232. **The store links** (item 108): they still point at the stores' front pages
    (`data/platform/store_links.json`, marked DESIGN-TBD). Which pages, once they exist? And which order and
    names on the tiles (now "Steam (PC)", "App Store", "Google Play")?
233. **A phone held upright** (GDD §2: landscape on every platform; the web demo can be opened on a phone in
    either orientation, and the game is laid out for landscape only, so upright it shrinks to an unreadable
    size). Placeholder: on a touch screen held upright the page covers the game with "TURN YOUR PHONE SIDEWAYS
    TO PLAY" (a style in the preset's `html/head_include`, marked DESIGN-TBD), and a running level pauses
    (`App._on_window_resized`, DESIGN-TBD); turned back, the pause menu waits. Right, or should the game try to
    lock the orientation (browsers allow it only in full screen), or offer a full-screen button?
234. **The demo on a phone plays like the mobile game** (GDD §3, §8): a phone's browser (Android, iPhone) gets
    the mobile layout: 3 lanes, touch controls and hints, and no slow time (PC only). An iPad's browser says
    it's a Mac, so it gets the PC layout (5 lanes, keyboard hints) while touch still works. Placeholder: as
    described (`DeviceProfile.is_mobile()`, from the browser's own platform tags). Right?
235. **The loading screen** (GDD §11: the look): while the demo downloads (about 14 MB, then the engine starts),
    the page shows Godot's default splash, the Godot logo on grey, with a progress bar under it. Should it show
    the game's own title or art instead, on the game's dark violet? Placeholder: Godot's default.
236. **Sound before the first click** (GDD §11): browsers don't let a page play sound until the player clicks,
    taps or presses a key, so the title's music starts with the player's first input (Chrome notes this in its
    console). Placeholder: that. Should the demo instead open on a "click to play" card, so the music is there
    from the first screen?
237. **Where the demo's saves live** (GDD §2, §7): in the browser's own storage for the page (IndexedDB), so
    progress and credits survive a reload but stay in that browser, and a portal's page keeps its own. There is
    no way to carry them into the full game. Right?

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
239. **A title card naming the zone** (GDD §1: "little or no words"). Should an arrival cinematic name the zone
    on screen?
    - *Placeholder:* a card from about 0.9 s to 3.8 s: "ZONE 1" over "NEON CITY" (the zone's number and name,
    from the zone's data), in the menus' fonts, capitals, fading in and out
    (`ArrivalFlyover._make_timeline`, `CineOverlay.show_card`).
240. **The City's boss intro** ("Something big is coming", before the Floating Head): what should it show,
    and should it tease the boss?
    - *Placeholder:* the same arrival flyover over the fight's arena look (`city_boss_skin`, taken from the
    boss's arena data), with a card naming the boss as the level select does ("ZONE 1 · BOSS" over
    "FLOATING HEAD"), and the fight's music. No glimpse of the ship.
241. **Skipping.** GDD §1 doesn't say how cinematics are skipped. Should every cinematic be skippable at once,
    even the first time? Should a seen cinematic play again when a step is replayed from the level select?
    - *Placeholder:* always skippable at once with the pause action (Esc / P) or a Skip button (bottom right,
    dim, from 0.4 s; on touch screens it's the only way). A skipped cinematic counts as seen and done, like
    one played out. Replaying a step from the level select plays it again (nothing is skipped
    automatically; the App marks each one seen, `cinematic/<step id>`, for later use).
242. **The outros** stay placeholder cards (the task covered the intros). Should they get a placeholder
    cinematic too (a departure from the zone, say) until their beats are known? The web demo still ends on
    its end screen after the City's outro card.
    - *Placeholder:* unchanged cards (`data/cinematics/*_outro.tres` have no scene).
243. **The look of every cinematic:** letterbox bars, a fade from black at the start and to black at the end.
    - *Placeholder:* bars of 10% of the screen's height each (`CineOverlay.BAR_SHARE`); the arrival flyover
    fades in over 0.8 s and out over 0.45 s (its data).

**Free armor** (from G3; numbers in `data/tuning/game_rules.tres`, F6 "Game rules", Armor; the shop line in `data/shop/catalog.json`; review the HUD with the screens showcase `--screen=hud_armor`)
244. **Worn armor** (GDD §4, §8). An upgraded armor takes more than one hit. When it has lost some hits
    but isn't broken, does anything come back?
    **Placeholder:** nothing comes back until its last hit goes; then it breaks and comes back whole
    after its tier's wait (`DamageRules.Armor` in `scripts/core/damage_rules.gd`, `DESIGN-TBD`).
    The alternative: each lost hit comes back on its own after the wait.
245. **An armor pickup when the armor is whole** (GDD §10, the standard armor rule). A pickup brings
    broken or worn armor back whole at once. Taken while the armor is already whole, what should it do?
    **Placeholder:** it adds one hit over the armor's count, up to `armor_pickup_extra_hits` = 1
    (`data/tuning/game_rules.tres`, F6 "Game rules"; `DESIGN-TBD`). The extra hit is used first and
    doesn't come back: after a break the armor returns to its own count. The alternative: it gives
    credits.
246. **Switching the armor off** (GDD §8, Rules: the equip toggle). The shop's equip toggle switches
    the armor upgrade off, down to the free armor. Should the free armor be switchable too (a challenge
    run without it)?
    **Placeholder:** no, the free armor can't be switched off (`Loadout.from_profile` in
    `scripts/run/loadout.gd`, `DESIGN-TBD`).
247. **A revive** (GDD §4). After a revive, is the armor back whole, or as it was when the player died
    (broken and still coming back)?
    **Placeholder:** back whole (`Player.revive` in `scripts/player/player.gd`, `DESIGN-TBD`).

**The Floating Head after the playtest** (from E1e; numbers in `data/bosses/city_boss_tuning.tres`; measure the routes with `tools/measure/stomp_routes.gd`; play `--level=city/boss`)
248. (E1f: at the City's 21 m/s the wall marks sit 15.7 m and 5.2 m before the face, the same seconds as 13 m and 4 m at 18 m/s.) **Should every phase use a ramp?** (GDD §10: (1) the fallen tower as a ramp, (2) a wall jump,
    (3) a pad and the ceiling.) After the first stomp the owner saw no ramp and no way up. The wall route
    showed nothing, and at 5 and 6 lanes a wall jump lands in the outer lane, which has no weak point:
    only a second move inward in the air reached one (measured in the campaign's step and in quick play,
    before and after a retry: a single wall jump never stomped). Placeholder: the GDD's three ways,
    made visible and forgiving: green chevron marks light up on both walls as the tower falls, from where
    to get on (`wall_entry_before`, 13 m before its face) to a tall jump mark (`wall_jump_before`, 4 m),
    with a new sound (`wall_marks_light`); a first-time hint for each way (`data/hints/hints.json`); and
    question 3. Alternative: the tower's slab in every phase.
249. **The ramp's lead-in** (item 158): a lane switch onto the ramp bounced off its side anywhere past its
    first 2 to 2.75 m (the latest switch that still stomped: 11.3 to 12.0 m before its face). Placeholder:
    its first 75% (`ramp_board_share`) is a low lead-in rising to 1.0 m (`ramp_board_height`; a lane
    switch steps up about 1.07 m) with bevelled rubble sides; its last quarter is steeper and still
    blocks; the window stays open for a runner on the trucks until the lead-in ends (3.5 m before its
    face, not 8 m). The latest switch is now 4.5 m before its face at 3, 5 and 6 lanes. Right share,
    and does the bent slab read as the fallen tower? Alternatives: a slab two lanes wide, a longer ramp.
250. (E1f: the stomp boxes are now 4.6 m deep at 18 m/s, stretched by the pace in the campaign.) **Stomp boxes over the outer lanes** (item 160): at 5 and 6 lanes the outermost weak points' stomp
    boxes now reach over the outer lanes to the walls, at their own height (a jump from the trucks
    still can't reach them), so a wall jump or a ceiling drop there stomps the dome beside it; and every
    box is lower and deeper (0.35 m over its socket, 4 m deep; were 0.55 m and 3 m). One wall jump now
    stomps over 4.5 to 7 m of jump points around the mark. Alternative: weak points of their own over
    the outer lanes (the tower side's would sit near the roofs, in a floor jump's reach).
251. **Armor for a runner whose armor is down** (GDD §10, the standard armor rule): with no armor and no
    shield nothing could break, so no pickup came before the final phase, which the owner never
    reached (the loadout and the flow were fine). G3's free armor now covers the start of every fight.
    Placeholder on top: a phase that begins with the runner's armor down and no shield (the free armor
    still coming back) and no pickup on its way counts as a break at its start (an armor pickup 10 to
    15 s in, the phase's one; `BossDef.armor_when_unprotected`, on for the Floating Head only). Keep it,
    make it the standard rule, or drop it now that the free armor comes back by itself?

**Laser tier 1** (from G4; `weapon_range` and `tier1_extra_shots` in `data/tuning/powerups.tres`, F6)
252. **Laser tier 1's exact range** (GDD §8 damage reference, owner's September 30, 2026 playtest: "a
    shorter range... so enemies get close enough to be a threat before they fall"; the brief set the
    approach at about 60% of the old range). **Placeholder:** `PowerupTuning.weapon_range` tier 1 is
    42 m (was 70 m, shared with every tier), about 2.3 s of approach at the 18 m/s base run speed
    (down from about 3.9 s). Tiers 2–4 keep 70 m, since they shared the old value (GDD's rule: "higher
    tiers keep their range unless they share the value"). Is 42 m (60%) the right amount, or should it
    be shorter/longer?
    **Also applied without a question, since the owner's follow-up already resolved it:** the owner chose
    "higher tiers keep today's numbers" over raising enemy health (which had also moved tiers 2 and 3),
    so the two extra tier 1 shots are a weapon-side rule, not a health change. `PowerupTuning.tier1_extra_shots`
    (2) is one number in data; `WeaponPowerup.damage()` applies it generically, splitting a target's
    unchanged `max_health` across its plain shot count plus the extra, for any target except one already a
    one-shot kill (the sewer screech), an `immune_to_weapons` target, or a boss part (`is_boss`; a boss's
    weapon chip is its own rule, `BossEncounter.weapon_share_cap`). No enemy's `health_early`/`health_late`
    or any tier's `weapon_damage` changed.

**A faster pace and busier levels** (from G1; speeds in `data/zones/*.tres` `run_speed`, density in `data/levels/*.tres`; measure with `tools/measure/level_pace.gd`)
253. **How busy the campaign levels get** (GDD §3, busier levels: "more gaps, obstacles and enemies ...
    (to an extent)"). **Placeholder:** campaign levels space their patterns 1.1 s apart at low
    difficulty (`spacing_seconds_easy`, default 1.8 s), and a fill pass adds more of the level's plain
    hole and fence patterns wherever nothing goes on for over 2 s (`fill_empty_seconds`), all in
    `data/levels/*.tres`. Events per minute rise 23–37% in the Neon City and Gangland but only 7–16%
    from the Marketplace on: there the hard spacing (0.9 s, about the time to switch across six lanes)
    and the room kept around enemies already set the pace. The longest quiet stretch is about 4 s,
    except under the Neon City's first ceilings (about 6 s, a bare floor while ceilings are new) and
    in The Hush. **Alternatives:** a closer hard spacing (0.75 s gives the later zones about +16–22%, but
    is too short to cross six lanes), or more enemies per level.
254. **Livelier enemies: how much less idle time** (GDD §3: enemies and their attacks speed up to
    match). **Placeholder:** enemies that move in the world's frame move, lunge and fire faster from
    further out at a faster zone's speed, with every warning and dodge window in the same seconds; and
    the idle time between attacks is about 15–20% shorter in `data/enemies/*.tres`: cyborg and window
    cyborg reloads 1.8/1.1 s (were 2.2/1.3), drone follow times 1.0, 2.5/1.6 s and cooldown 0.4 s
    (were 1.2, 3.0/2.0 and 0.5), hover truck pacing 3.0/3.8 s, hold back 1.3 s, cannon interval
    3.8/2.5 s and first shot 0.5 s (were 3.5/4.5, 1.6, 4.5/3.0 and 0.6), Octodog turnaround 0.25 s
    (was 0.3), Resonator settle 0.5 s and rests 1.8/1.0 s (were 0.6 and 2.2/1.2). **Alternative:**
    shorter still, or only the faster motion.
255. **The Resonator at a faster zone's speed** (GDD §9.10 and §3). **Placeholder:** it hovers 34 m ahead
    in every zone, inside laser tier 1's 42 m reach, and the runner closes in on its waves as fast as at
    18 m/s, so each wave takes as long to arrive; at 25 m/s a wave rolls along the floor at 4–7 m/s
    instead of 11–14 (`ResonatorTuning.wave_speed_at`). **Alternatives:** hover further ahead with
    faster waves (47 m at 25 m/s, out of laser tier 1's reach), or faster waves from 34 m (0.3 s less
    to react).
256. **Harder tiers' extra speed** (GDD §6, replay: harder difficulty tiers; `Campaign.tier_speed_multiplier`,
    1.1 and 1.2). **Placeholder:** a tier's faster run stretches the patterns like a faster zone does,
    so every reaction window keeps its seconds and a harder tier is harder only through its difficulty
    bonus (`Campaign.run_speed_for`). **Alternative:** as before, a tier's extra speed tightens the
    patterns' timing.
257. **Each zone's speed** (GDD §3: about 21 m/s in the Neon City, rising zone by zone to about 25 m/s
    in the Golden Zone). **Placeholder:** a straight rise, 21.0, 21.8, 22.6, 23.4, 24.2 and 25.0 m/s
    (`run_speed` in `data/zones/*.tres`); boss fights, quick play and the tests keep the base 18 m/s.
    **Alternative:** another curve, such as a bigger step at the start of each act.
    <!-- Measurements for question 1 (tools/measure/level_pace.gd --seeds=4: each level on its own seed and
    4 others, at 3, 5 and 6 lanes). "Before" is main's data built by this branch's code (byte for byte the
    old layouts, --old-data); "after" is this branch. Events: obstacle rows, enemies, big attacks and
    mechanics. Empty: seconds with nothing going on (a ceiling ride doesn't count; The Hush is quiet by
    design, its bursts' longest empty stretch 6.0 s before and after). Credits in total: 11,571 → 11,638.
    | Level | m/s | Events/min | Longest empty, s (mean / worst) | Mean empty, s | Credits |
    |---|---|---|---|---|---|
    | city/1 | 18 → 21.0 | 28.3 → 38.8 (+37%) | 2.0 / 2.3 → 1.4 / 1.9 | 1.81 → 1.25 | 506 → 542 (+7%) |
    | city/2 | 18 → 21.0 | 26.2 → 34.1 (+30%) | 6.8 / 7.7 → 6.2 / 6.2 | 2.04 → 1.45 | 550 → 611 (+11%) |
    | city/3 | 18 → 21.0 | 27.7 → 35.5 (+28%) | 6.1 / 6.8 → 5.3 / 6.2 | 1.91 → 1.34 | 605 → 649 (+7%) |
    | gangland/1 | 18 → 21.8 | 30.8 → 38.1 (+24%) | 5.2 / 6.6 → 4.0 / 6.2 | 1.56 → 1.21 | 827 → 843 (+2%) |
    | gangland/2 | 18 → 21.8 | 30.9 → 38.4 (+24%) | 5.6 / 10.5 → 3.4 / 4.2 | 1.60 → 1.17 | 761 → 821 (+8%) |
    | gangland/3 | 18 → 21.8 | 35.3 → 43.4 (+23%) | 6.6 / 7.9 → 3.8 / 4.7 | 1.59 → 1.18 | 921 → 947 (+3%) |
    | marketplace/1 | 18 → 22.6 | 37.0 → 42.5 (+15%) | 6.4 / 9.4 → 4.2 / 5.3 | 1.54 → 1.29 | 971 → 868 (-11%) |
    | marketplace/2 | 18 → 22.6 | 36.3 → 42.1 (+16%) | 7.3 / 9.0 → 4.3 / 5.2 | 1.60 → 1.23 | 942 → 819 (-13%) |
    | corporate/1 | 18 → 23.4 | 36.8 → 42.2 (+15%) | 6.8 / 9.2 → 4.3 / 6.8 | 1.48 → 1.24 | 862 → 810 (-6%) |
    | corporate/2 | 18 → 23.4 | 36.8 → 41.9 (+14%) | 6.6 / 9.0 → 4.2 / 4.9 | 1.52 → 1.29 | 872 → 822 (-6%) |
    | dead_zone/1 | 18 → 24.2 | 35.4 → 40.2 (+14%) | 6.3 / 9.5 → 4.4 / 7.1 | 1.63 → 1.33 | 818 → 900 (+10%) |
    | dead_zone/2 (The Hush) | 18 → 24.2 | 29.2 → 28.6 (-2%) | 8.4 / 10.1 → 8.1 / 10.1 | 2.16 → 2.14 | 732 → 669 (-9%) |
    | golden/1 | 18 → 25.0 | 37.2 → 40.1 (+8%) | 6.8 / 8.8 → 4.0 / 4.8 | 1.59 → 1.32 | 701 → 738 (+5%) |
    | golden/2 | 18 → 25.0 | 36.6 → 40.9 (+12%) | 7.7 / 13.6 → 4.3 / 6.4 | 1.59 → 1.30 | 729 → 828 (+14%) |
    | golden/3 | 18 → 25.0 | 37.9 → 40.7 (+7%) | 7.3 / 8.9 → 4.1 / 5.1 | 1.63 → 1.27 | 774 → 771 (0%) |
    -->

**The Marketplace citizens** (from D3; regenerate the sheets with `tools/godot.sh citizens`; review with `tools/showcase/skin_review.tscn -- --skin=marketplace`)
258. **How a citizen's window should read apart from a window cyborg's** (GDD §5, §9.2;
    `OPEN_QUESTIONS.md` §D item 46 already raises this). The placeholder: citizens never glow and
    their windows stay as bright and lit as any other shop's (`MarketplaceSkin`'s own window look,
    unchanged); a window cyborg always darkens its own window on top, so the two never show at once.
    For *position*, `MarketplaceSkin.note_wall_enemies()` (a new, generic `ZoneSkin` hook) tells the
    skin which window cyborgs the level is about to place, and `MarketCitizens` keeps a
    `CYBORG_MARGIN` (2.2 m) clear of each one's track position on its side. 2.2 m is a guess, wider
    than a window cyborg's own drawn window (`WindowCyborgTuning.window_length`, 1.5 m by default) but
    not measured against real levels. Alternative: let window cyborgs themselves prefer the skin's
    own shop windows (closer coordination, more shared code, touches a shared enemy every zone uses).
259. **What counts as "low-end"** (task plan: "nothing decides low-end yet"). The placeholder:
    `DeviceProfile.is_low_end()` is a mobile device still rendering with the Compatibility renderer.
    `Settings.citizens_enabled` (a new setting, default on, no UI toggle built yet) is off whenever
    that's true or the player turns the setting off directly. Alternative: a frame-time budget probed
    at runtime, or a tier list by `OS.get_video_adapter_name()`.
260. **How many windows should host a citizen** (not in the GDD at all). Placeholder:
    `MarketCitizens.CITIZEN_SHARE` = 0.16 of eligible windows, picked to keep the chunk's draw calls
    and build time inside `SkinSuite`'s existing budgets (see `tests/suites/test_marketplace_skin.gd`
    for the measured numbers with citizens on and off). The owner can judge this by playing, so it's a
    tunable, not really an open question, but the share needed real measurement to pick.

**The Barnacle Turret** (from C1; numbers in `data/enemies/barnacle_turret.tres`; review with `tools/showcase/barnacle_turret_showcase.tscn` or play `--level=marketplace/1`)
261. **How does a stomp reach it?** GDD §9.8 lists "a stomp" among its kills, but it hangs from the ceiling,
    out of a floor runner's reach (it must be: the floor route under its ceiling stays as it was).
    - **Placeholder:** a rider on its ceiling jumps and drops back onto its crown, the top of the dome as
    the rider sees it (`Player._is_stomping` on the ceiling, `Hazard.upside_down`). It bounces the
    rider like any stomp. Only a turret's crown can be stomped from a ceiling.
    - **Alternative:** no stomp for the turret (claws, the dash and weapons only).
262. **When does it pop out?** GDD §9.8: it "pops out of the ceiling's underside".
    - **Placeholder:** 3.5 s before the player reaches it (`emerge_seconds`), so a floor runner sees it
    before taking the pad, and the choice to ride is an informed one. Until then it's a closed hatch
    on the underside, harmless and untargeted.
    - **Alternative:** it pops out only once the player rides its ceiling, as a surprise.
263. **May it hang over the pad's lane?** GDD §9.8: "mounted only over lanes the ceiling covers".
    - **Placeholder:** never over a pad's lane. A rider who stays in the lane they landed in never meets a
    turret's body, only its bolts, which keeps the ceiling the easier route (GDD §3), and the ceiling's
    line of credits (along that lane) never leads into one.
    - **Alternative:** any lane the ceiling covers, so a rider sometimes has to switch lanes after landing.
264. **Marketplace 1's introduction needs a ceiling.** The level's own ceilings come late (none within
    about 20 s of the turret's start at 10% on its seeds), so placed on them alone the turret would show
    up long after its hint.
    - **Placeholder:** when no ceiling it fits on lies within 8 s of the start (`intro_seconds`), the
    rules add a plain full-width ceiling for it, only where one fits without clearing anything and
    before the level's first drone; the rest of the level is unchanged.
    - **Alternative:** move Marketplace 1's start for the turret to where its first ceiling is, or let the
    introduction wait for the level's first ceiling.

**The Sleep Taker: the nightmare and its attacks** (from E5c-a; numbers in `data/bosses/dead_zone_boss_tuning.tres`; play `--boss=dead_zone_boss`, review with `tools/showcase/sleep_taker_showcase.tscn`)
265. **The refuge from the giant slash** (GDD §10: "get out of those lanes, or up onto the ceiling"; at
    3 lanes a three-lane slash covers the whole street).
    **Placeholder:** every slash comes at a refuge: every 240 m (`refuge_spacing`, about 13 s) a charred
    bridge crosses the street (the Dead Zone's ceiling look) with a pad in the middle lane (both middle
    lanes at 6), at most one lane switch away at 3 lanes and two at 5 and 6; the slash's warning
    (1.9 s) starts 1.1 s before the runner reaches the pads and it strikes 0.8 s after, while a runner who
    took a pad rides the ceiling. At 5 and 6 lanes, leaving its three lanes dodges it as well, and a wall
    is always safe from it. The street is kept clear of holes and fences from the warning to the strike.
    **Alternatives:** a pad in every lane (`refuge_pads_every_lane`: a runner can't miss one, so the
    slash never threatens anyone who doesn't jump the pad); or, at 5 and 6 lanes, more slashes between
    the bridges, dodged only by leaving the lanes.
266. **Its look and size** (GDD §10: one colossal nightmare, black with purple highlights, dozens of
    circular maws and long clawed fingers).
    **Placeholder:** a hunched mass of fused Bad Dream heads over a chest and waist, trailing vapour to
    the street, 28 maws all facing the runner, two long arms hanging wide of the middle lanes and four
    tendrils of clawed fingers; about 12 m tall over 3 lanes, 18 m over 5 and 22 m over 6, filling the
    street 26 m ahead. Its great maw (the slash's warning) gapes in its belly, about 5 m up, so it shows
    under a refuge's bridge; the bridges cut through its upper body like a ghost's. Its throat and claws
    heat to enemy-attack red as it shrieks and slashes. **Alternative:** the great maw in its head (hidden
    by the bridge during a slash, leaving the red lanes and its rising arms as the warning's look).
267. **How dark** (GDD §10: darker than normal, never pitch black; lights out darker still).
    **Placeholder:** the arena at `darkness` 0.4 (the scenery at 72% of the Dead Zone's light); lights
    out, after a 2 s inhale, brings the arena's light down to 45% for 8 s, the scenery to 32% (its floor
    is 30%), then it breathes out and the light comes back over 1.6 s. Measured on screen at 5 lanes
    (`--scenario=measure`, grey value 0-255, the arena's light → the darkest point): the street 80 → 50,
    the walls 34 → 25 on Forward+, the same on the Compatibility renderer; the slash's red lanes, the
    hand's purple mist, the pink fence and generator, the cyan pad and its maws keep their colours and
    stand out from the street as much or more (their colour distance from it: red lanes 101 → 96, fence
    148 → 224, pad 194 → 233 on Forward+; red lanes 64 → 41 on Compatibility, where their bright edges
    carry them). Dark enough, or darker (it would need a lower floor than The Hush's 30%)?
268. **The hands** (GDD §10: purple mist pools in the lane, with whispering; switch lanes).
    **Placeholder:** one hand at a time, in the runner's lane: the mist pools 1.2 s before the hand bursts
    up, 0.45 s before the runner would reach it, about one every 3 s between the refuges; the hand reaches
    above a jump, so only a lane switch (or a wall or the ceiling) dodges it, and one only comes while the
    next lane is clear. The mist is the nightmare's own purple; only the hand's claws heat red as it
    rises. **Alternative:** a red line under the mist, like the other bosses' floor warnings.
269. **Its rhythm, and lights out with the other attacks** (GDD §10: hands and slashes keep coming in the
    dark). **Placeholder:** each phase's list (`attack_patterns`; the first: hands, hands, lights out,
    hands, hands, hands), one attack at a time, 1.3 s apart (`attack_gap`), never one that would still be
    on when the next refuge's slash is due; the dark lasts while the next attacks come. Measured on its
    arena at 5 lanes (`test_sleep_taker_attacks`): 61 s of pattern bring 4 slashes, 9 hands and 2 lights
    outs (a slash about every 15 s, a hand every 7 s, lights out every 30 s); fewer hands than the list
    asks for, since a hand only comes where its lane and the next are clear of the arena's holes and
    fences. Right amount? (E5c-b makes the later phases hungrier: faster hands, more lights out.)

**Zone doodads** (from G5; the share per level in `data/levels/*.tres`, sizes in `data/tuning/movement.tres`; quick play `--doodads=X`; review with the `doodad_review` showcase)
270. **Which lanes doodads stand in** (GDD §3, Side walls and Collision rules). Doodads stand only in the
    inner lanes, never the outermost one: a wall runner's body reaches 1.28 m into the street, so a doodad
    in the outer lane would meet wall runners, and the wall-runner collision would have to change. At
    3 lanes that leaves the middle lane only (pushing left or right). The alternative: doodads in the
    outer lanes too, either narrowed to the lane's inner half (leaving a gap by the wall that looks
    passable but isn't) or blocking wall entry around them.
    *Placeholder:* `LevelGenerator._add_doodad` (inner lanes only); `LayoutChecks.check_doodads` checks it.
271. **How tall a doodad is, and its top** (GDD §3). Every doodad's collision box is 2.6 m tall
    (`MovementTuning.doodad_height`): far above a jump (the feet reach 1.6 m) and below a ceiling rider's
    head even mid-jump (about 3.1 m). Its top is solid: a player who comes down on one from above (after a
    wall jump) lands and runs along it, then drops off its end into its lane, like a hover truck's roof.
    The alternative: a top that pushes the player off sideways.
    *Placeholder:* `data/tuning/movement.tres` defaults (`doodad_height`, the size classes' lengths and
    widths); `TrackBuilder._build_doodad` (the top on the floor layer).
272. **Which way a push goes when the player catches a corner** (GDD §3: "if both sides have room, a side
    chosen per doodad"). Running into a doodad head-on pushes the player to the doodad's side, a seeded
    choice that's the same on every attempt. A player who catches its front corner while switching lanes
    into it is pushed back the way they came, never through the doodad to its far side. The push is a
    0.13 s shove (a lane switch takes 0.14 s) with a dull thud, the runner leaning into it and a small
    camera shake; it costs nothing (no damage, no speed). The alternative: always the doodad's side.
    *Placeholder:* `Player._check_doodads` (`PUSH_HEAD_ON_SHARE`), `MovementTuning.doodad_push_time`,
    `SpeedFxTuning.push_shake_*`, `assets/sfx/doodad_push.wav`.
273. **Where doodads stand, and how many** (GDD §3: busier levels, "without turning them into a slalom").
    A doodad stands only where nothing else goes on in any lane, from just before its push to the level's
    spacing after it (so the player can cross its lane again before the next obstacle, as between two
    patterns), never under a ceiling (the camera rides below a ceiling, lower than a doodad), off every
    enemy's stretch, at least 2.5 s from the next doodad. They're placed after the fill pass, into what it
    leaves, so they add to a level rather than replace obstacles: 3 to 15% more events a minute, about
    3 doodads a minute in City 1 (only the smaller ones, from a fifth of the way in), 4.5 to 5.3 in the
    City's other levels, 2.7 to 4.4 in Gangland and the Marketplace, and 2.3 to 3.2 later, where enemies
    leave less room; The Hush keeps its quiet stretches empty (as the fill pass does) and gets about 1 a
    minute (`tools/measure/level_pace.gd`). The longest empty stretches barely change: they lie under ceilings
    or around enemies. The alternative, for more of them: let them stand beside obstacle rows in lanes
    those rows leave free, and in The Hush's quiet stretches as silent wreckage.
    *Placeholder:* each level's `doodad_share` (and City 1's `doodad_start` and size weights) in
    `data/levels/*.tres`; `LevelConfig.doodad_gap_seconds`.
274. **Aimed attacks near a doodad** (GDD §9: every attack is fair; a doodad's side blocks a dodge and its
    push moves the player). The generator keeps doodads off every planned attack (an Octodog's run, a
    Resonator's visit, a drone wave until its first pad, a hover truck's stay in its lane and its first
    20 s in every lane, a Bad Dream's chase). At runtime an attack that could still come later never comes
    with a doodad in reach: a drone's barrage and the truck's cannon wait, an Octodog charge or Resonator
    pulse moved on by a wait for its turn waits, cyborg bolts never land by one, and a truck only lurches
    at a player who can leave its lane. So a drone that outlives its pads fires a little less where doodads
    stand. The alternative: keep doodads out of every drone's and hover truck's whole stay.
    *Placeholder:* `drone.gd` and `hover_truck.gd` (`_doodad_in_reach`), `Octodog.window_clear`,
    `Resonator.pulse_clear`, `CyborgGun.path_clear`.

**The Golden Palace** (from D6b; numbers and colours are exports on `GoldenPalaceSkin`, F6; play `--level=golden/3` or `--quick --skin=golden_palace`)
275. **The floor's gold inlay runner** (GDD §5: "a palace floor (marble, inlay, gold runners)"): how
    wide. **Placeholder:** `GoldenPalaceSkin.runner_half_width` (0.2 m, a roughly 0.4 m runner down
    each lane's centre), `## DESIGN-TBD` in `scripts/world/skins/golden_palace_skin.gd`.
276. **How tall the colonnade rises** above its entablature (frieze_top) before the hall reads as
    receding into haze, comfortably clear of an alcove's statue and a hung tapestry. **Placeholder:**
    `GoldenPalaceSkin.pilaster_height` (15 m), `## DESIGN-TBD` in the same file.
277. **How far a ceiling piece's structure may rise** above its underside (GDD §5: "the vast hall's
    ceiling stays far above") before the hall's haze would hide it anyway. **Placeholder:**
    `GoldenPalaceSkin.hall_clear_height` (7.5 m, close to the Corporate zone's and the Dead Zone's own
    ~7.4 m ceiling-structure budgets), `## DESIGN-TBD` in the same file.
278. **The vault above the colonnade** (GDD §5: "an enormous vaulted space, perhaps with distant halls
    and light shafts"): whether it should look like the Golden Zone's own dusk sky with the moon and
    stars turned off (what's built: `GoldenPalaceSkin.make_environment()` reuses
    `GoldenSkin.make_environment()` wholesale, its warm haze and dimmed "skyline" standing in for
    distant halls glimpsed through light shafts), or something explicitly interior instead (a painted
    or coffered ceiling glimpsed above the colonnade, a true horizon never showing).

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
    *Placeholder:* `scripts/world/skins/golden/golden_doodads.gd` (`_statue`); `test_golden_skin`'s
    `_doodad_statue_not_sentinel` guards against the doodad ever building from `GoldenStatue`.

**The Sleep Taker: hurting it, the phases and the defeat** (from E5c-b; numbers in `data/bosses/dead_zone_boss_tuning.tres`; play `--level=dead_zone/boss`, review with `tools/showcase/sleep_taker_showcase.tscn -- --scenario=lure`)
280. **The lure** (GDD §10: "the player lures it close (it lunges toward them), then destroys the generator
    with a stomp or the dash").
    **Placeholder:** going for a generator is the lure. 3 s before the runner reaches one
    (`lure_seconds`), the nightmare lunges in after them with a hungry roar and holds its claws 3.5 m in
    front of them, attacking nothing, until they're past it. While it's lured and within 24 m of the
    generator (`emp_reach`, at 18 m/s; it scales with the run speed), pink arcs crackle from the generator
    into it: smash the generator now. The arcs show 1.7-1.8 s before a stomp lands (at 18 and 24.2 m/s,
    at 3, 5 and 6 lanes). Hovering, it's never in reach. **Alternative:** lure it with its own slash (a
    generator by a refuge, smashed while it lunges in to strike).
281. **The generators** (GDD §10: they "stand along the route"; "a missed generator is followed by
    another"). **Placeholder:** one at a time, from 9 s into each phase's pattern (`generator_delay`),
    placed in sight 160 m ahead (at 18 m/s: about 9 s, at any speed) in the runner's lane, or the nearest
    lane whose floor is clear around it, never near a refuge's slash or under a ceiling; another 3 s after
    a miss. They power no fences of their own, and a pink beacon rising from each shows through the
    nightmare, which looms between the runner and it. **Alternative:** fixed spots in the arena, each
    powering a fence or two.
282. **Its phases** (GDD §10: three EMP hits, hungrier each phase: faster hands, more lights out).
    **Placeholder:** each EMP tears a chunk away (its left cluster of heads, then its right, ripping off in
    a burst of wisps), and it recoils howling and re-forms over 2.5 s. Phases 2 and 3 run at pace 1.15 and
    1.3 (shorter hand warnings and gaps) with more lights out in their lists. A phase begun with the armor
    down counts as a break (`armor_when_unprotected`, as for the Floating Head).
283. **The defeat** (GDD §10: hundreds of wisps, faint faces or figures drifting upward; "then silence, and
    the first grey dawn light").
    **Placeholder:** 260 wisps (faces with open mouths, sleeping faces, figures with raised arms) rise and
    fade over 4.5 s as it dissolves. The music fades out over 2 s, and the win plays no victory riff. Then
    the night sky turns to a grey dawn over 3.2 s (the light up to 1.25 times the zone's own), and the
    results follow. **Alternative:** keep the victory riff, as after every other win.
284. **Its length and par times** (GDD §10: 60-120 s; stars from par times).
    **Placeholder:** a runner who never misses wins in about 78 s (measured at every lane count and at
    18 and 24.2 m/s); a missed generator costs about 12 s. Three stars at 86 s or less, two at 110 s or
    less (up to two misses).

**Floors that turn into gaps** (from B4; the stand-in in `data/enemies/floor_cutter.tres`; quick play `--features=floor_cutter`; review with `tools/showcase/floor_cut_review.tscn`)
285. **How many lanes stay whole beside a cut at 5 and 6 lanes?** (GDD §9.9: "On 3 lanes, two lanes
    always stay whole.") Along a cut's stretch, at most one lane besides the cut's own may hold holes
    at 5 and 6 lanes, so 3 of 5 and 4 of 6 lanes always stay whole; the generator clears the holes
    nearest the cut first, so its neighbours stay whole. The alternative is the 3-lane rule at every
    lane count: no hole in any other lane beside a cut.
    *Placeholder:* `LevelConfig.cut_holes_beside = 1` (DESIGN-TBD; `LevelGenerator.whole_lanes_for_cut`).
286. **What does the floor that "holds for about a second" after a block look like?** (GDD §9.9: "After a
    block, the floor under the player holds for about a second, just enough to switch lanes.") The floor
    ahead of the player was already cut behind the saw when it reached them, so the held floor (from just
    behind the player to as far as they can run in that second) shows again as the lane's own floor,
    with the cut's orange edges along it, and then goes all at once. The alternative is a held stretch
    drawn as cracked, sagging plates (a look task C2 could add with the saw's own effects).
    *Placeholder:* `GameRules.cut_hold_seconds = 1.0` (the GDD's "about a second") and
    `FloorCut.hold_under` (DESIGN-TBD: the look).
287. **Does anything else go on during a cut?** The brief and GDD §9.9 keep everything else out of the
    cut's lane. I also kept every other enemy's attack, the fill pass's extra holes and fences, and zone
    doodads out of a cut's whole window (from its warning until it ends, about 5 s), so a cut is the one
    thing going on, like a big attack taking its turn. The alternative is to let the other lanes keep
    their fillers and doodads during a cut (busier, but less room to dodge sideways).
    *Placeholder:* `LevelGenerator.cut_problem`, `fill_keep_outs`, `doodad_keep_outs` (DESIGN-TBD).
288. **May a cut run through an outer lane beside a wall runner?** GDD §9.9 says wall runners are safe
    "even beside it", and they are: the cut never reaches the wall. But a wall run ends by dropping back
    into the outer lane, which is a hole there once the cut has passed, as it would be for any hole in
    the outer lane; a wall jump with a lane switch in the air reaches the next lane. I allowed outer-lane
    cuts (only never where a ramp's wall run drops the player back). The alternative is to keep cuts out
    of the outer lanes.
    *Placeholder:* `LevelGenerator.cut_problem` (DESIGN-TBD).

**The robbed hit** (from B6; `theft_grace` in `data/tuning/game_rules.tres`; quick play `--thief`)
289. **Does anything protect against a theft?** (GDD §9.12: touching the Tithe Collector isn't deadly;
    §8: armor blocks an enemy attack or electrical hazard, the shield one hit of anything.) A theft is
    no hit, so armor, the shield, the invulnerability window after a hit and god mode don't stop it, and
    nothing is used up; only a short window after a theft stops a second one, so one touch robs once.
    The alternative is that the shield (one hit of anything), or the invulnerability window, also
    blocks a theft.
    *Placeholder:* `DamageRules.resolve` (DESIGN-TBD), `GameRules.theft_grace = 1.5` s.
290. **Do the claws catch the collector?** GDD §9.12 names a stomp, a shot and the dash; GDD §8 says the
    claws kill any enemy on contact. I let the claws catch it like any enemy, so a runner with claws is
    never robbed by a touch. The alternative is a claw-immune collector (a runner with claws who touches
    it is robbed; only a stomp, a shot or the dash catch it), which task C5 would declare
    (`claw_immune`).
    *Placeholder:* the stand-in's `claw_immune = false` (DESIGN-TBD, `scripts/enemies/stand_in_thief.gd`).
291. **What does "25% of the credits collected this run" take, and does the score drop?** A theft takes
    25% of the credits the run holds at the touch (everything collected so far, less what thieves hold
    now), rounded down, so a second theft takes 25% of what's left. The level score is never lowered
    (GDD §7: it's never spent), so stars and leaderboards never feel a theft; only the pay does. The
    alternatives: 25% of everything collected this run, even what an earlier thief already took (two
    thefts take half); or a score that drops with the credits, with stars counted from a score kept
    before thefts.
    *Placeholder:* `ScoreKeeper.rob` (DESIGN-TBD).
292. **How does a caught collector "burst into everything it took plus a jackpot"?** It pays straight
    into the run's credits, shown as coins flying out of it into the runner (and pop-ups), so nothing
    lands over a gap or a hazard; the jackpot, and anything it took off the track, count as collected
    (score). The alternative is credits scattered on the track to collect, with the risk that brings.
    *Placeholder:* `ScoreKeeper.pay_out`, `ThiefTuning.jackpot_credits = 100` (DESIGN-TBD: its size).

**The economy after the playtest** (from R7; measure with `tools/measure/economy.gd`; prices in `data/shop/catalog.json`)
293. **Armor I's new price (GDD §4, §8).** 350, reachable after one clean run of City 1 (or ~5 deaths).
    **Alternative:** cheaper still (so even a first attempt's partial credits cover it), or a flat
    starting discount instead of a price cut.
294. **Weapon IV only comes into reach in the Golden Zone (level 13 of 15)** under a single clean
    playthrough. Nothing needs it (every boss is beatable with what it grants), so it reads as an
    end-game capstone purchase. **Is that the intended feel, or should Heavy missile be reachable
    earlier** (e.g. by Corporate, where Buzz Overdrive first makes a weapon's damage matter)?
295. **The armor tiers' price curve after Armor I's cut**: Armor I is now a cheap starter (350) and
    Armor II is 4.9x that (1,700), versus 2.1x before. **Leave II–IV as the existing escalating sink
    they already were, or pull them down too to keep a smoother step?**

**Wall fences** (from B5; numbers in `data/tuning/wall_fences.tres`, F6 "Wall fences"; review with `tools/showcase/wall_fence_review.tscn` or play `--level=marketplace/2`)
296. **Do partial wall fences pulse too?** (GDD §9.1: wall fences "turn off and on"; partial ones "are passed
    by entering the wall high or low".) Placeholder: every wall fence pulses on the level clock, partial ones
    included, so a partial one is passed either by timing or by entering high or low
    (`WallFencePlacement`, `scripts/world/wall_fence_placement.gd`). The alternative: partial ones always on,
    passed only by height.
297. **Is the floor fence's warning long enough on a wall?** (GDD §9.1: "the same flicker and crackle before
    switching on"; the brief: a player already on the wall always sees the warning in time to drop off.)
    Placeholder: the floor fence's own 0.35 s (`MovementTuning.fence_pulse_warning`, and its 0.35 s crackle).
    Jumping off a wall takes about 0.1 s to clear the field, so a wall runner has about 0.24 s to react, the
    same as dodging a pulsing floor fence; the tests hold a runner who jumps off 0.2 s after the warning starts
    to never being hit. The alternative: a longer warning for wall fences only (about 0.5 s, with a longer
    crackle).
298. **Where may they stand?** (GDD §9.1's fairness rules, read for the drop-off.) Placeholder: besides the GDD's
    rules (no ramp launching the player along their wall, no sign or window cyborg on their wall section),
    a wall fence keeps the outer lane beside it clear to drop into (no hole, fence, floor cut, anti-grav pad or
    floor enemy from 0.6 s before it to 0.8 s after), keeps off wall vents' screeches, and never stands during a
    big attack (a drone wave, a hover truck, an Octodog's run, a Resonator's pulse, a Bad Dream chase) or a
    floor cut, the way the fill pass keeps its extra obstacles off them (`WallFenceTuning`, "Fairness"). So
    they come where the floor beside the wall is calm, and catch players who stay on a wall from earlier; a
    long big attack can also hold Marketplace 2's or Corporate 1's introduction back past its 10 s (about one
    seed in six; never on the levels' own seeds). The alternative: let them stand during big attacks (more of
    them, and introductions always on time, but the wall is one of the escapes from the Resonator's wave and
    the Bad Dream's slash).

**The House** (from E5a-a; numbers in `data/bosses/marketplace_boss_tuning.tres`; play `--boss=marketplace_boss`, review with `tools/showcase/the_house_showcase.tscn`)
299. **The 7 buttons' look** (GDD §10: "big glowing 7 buttons appear along the route. Running over one
    locks its reel on 7"; they must read as safe to run over).
    **Placeholder:** a big round ivory button flat on the floor, ringed in white with warm bulbs chasing
    round it, the reels' own 7 in royal blue in its middle, and the same 7 floating upright above head
    height over it (it marks the button from far along the street, and shrinks away as the runner nears).
    Why: white and ivory are the pickups' "safe" neutrals; royal blue is no hazard's colour and not the
    pads' cyan; round is no pad's or ramp's shape; the 7 ties it to the reels. Each lights up 1.35 s
    before the runner reaches it, with a soft chime. **Alternative:** a gold coin-shaped button (gold reads
    as the BAR blocks' colour, so we kept it off).
300. **Do locked reels stay locked?** (GDD §10: "With all three locked: JACKPOT"; "missed buttons: it just
    spins again").
    **Placeholder:** yes, until the jackpot (`locks_persist`): a missed button only means its reel shows its
    symbol and that attack comes; the next spin offers buttons for the reels still spinning, so a runner
    rigs the machine a reel at a time (a missed jackpot clears them). **Alternative:** all three in one spin
    (`locks_persist` off), much harder once phases 2 and 3 put a button on a wall or a ceiling.
301. **How the player reaches the hopper** (GDD §10: "its coin hopper bursts open on top as a glowing red
    weak point while it sags low. The player stomps it").
    **Placeholder:** at the jackpot it rolls to a stop where the runner reaches it 2.6 s later (at any
    speed), and sinks into the street until its top is a low deck (0.35 m) the runner can run onto. The
    hopper is open in that deck across the whole street, glowing red, its stomp box 12 m long at 18 m/s
    (stretched with the speed): any jump that comes down on it stomps it, from the street or from the deck
    (the box is longer than a jump). A runner who doesn't jump runs over it unhurt; then it lurches out
    from under them, rises and spins again. The hopper opens about 1.5 s before the runner reaches it, at
    18 and 22.6 m/s. **Alternative:** it stays standing and its payout chute drops to the street as a ramp
    up to the hopper on its top.
302. **How long a phase lasts before the buttons come** (GDD §10: a fight of about 60-120 s).
    **Placeholder:** each phase opens with two spins without buttons (`opening_spins`: only attacks, about
    6 s each), then every spin offers buttons. A runner who never misses wins a phase in about 20 s (the
    whole fight about 64 s with phases 2 and 3 still played as phase 1). The spins' symbols follow a list
    per phase (`spin_patterns`, with pairs and triples) rather than chance. **Alternative:** buttons from
    the first spin, with fewer buttons per spin.
303. **The arena** (GDD §10: "unique scripted encounters"; the Marketplace's floor is stall roofs with gaps
    between the stalls).
    **Placeholder:** a plain street: the arena's laps keep no holes, fences, signs, ceilings, pads or
    doodads of their own, so every danger is the machine's (its attacks are planned around each other
    and every button and the hopper are always reachable). **Alternative:** the Marketplace's own gaps
    and fences between spins, which the machine's attacks and buttons would keep clear of.

**The Buzz Overdrive** (from C2; numbers in `data/enemies/buzz_overdrive.tres`; play `--level=corporate/1`, review with `tools/showcase/buzz_overdrive_showcase.tscn`)
304. **What does "stop it in time" mean, and may it roll ahead first?** (GDD §9.9: "tuned so laser tier 1
    can't stop it in time, but the missile tiers usually can".) I read it as killing it before it charges,
    which saves the floor. A tank parked in its lane is in missile range (70 m) for well under the 5–7 s the
    missiles need, so it rolls ahead of the runner for 4 s, about 50–60 m in front, before it revs. Measured
    on a plain track: laser tier 1 never stops it; tiers 2–4 kill it during its rev at the zones' speeds
    (23.4–25 m/s); at the harder tiers' 28–30 m/s, tier 3 (and tier 4 at 30) only stop it mid-charge. The
    alternative is that it waits parked until it charges, and no weapon tier can stop it in time.
    *Placeholder:* `BuzzOverdriveTuning.roll_seconds = 4.0` (DESIGN-TBD).
305. **How fast does it charge?** It reaches the runner 0.6 s after it starts charging, at 2.5 times the run
    speed, so its cut runs on 1.5 s ahead of where it meets them: after a block, the floor holds for 1 s and
    then the runner falls unless they switched lanes (GDD §9.9: "a jump would land back in the cut lane").
    The alternative is a slower charge, which starts further away (out of missile range at the zones'
    speeds) or leaves too little cut ahead for the hold to matter.
    *Placeholder:* `charge_seconds = 0.6`, `charge_speed = 45` (DESIGN-TBD).
306. **How many per level?** Corporate 1: 1–4 (about 2.5 on average over seeds and lane counts), Corporate 2
    about 2.6, the Dead Zone and the Golden Zone about 1 each. In Corporate 1 the recency curve picks it
    four times as often (not capped), and about a third of its picks are dropped because nothing fits around
    them (a drone's pad and ceiling come every 8–10 s, a hover truck stays 20 s or more). Its introduction
    comes within 15 s of Corporate 1's 10% start in about two thirds of the layouts, later in the rest. The
    alternative is capping its pick boost at 1 like the other big enemies (fewer wasted picks, fewer tanks).
    *Placeholder:* no cap in `data/tuning/feature_recency.tres`; `intro_seconds = 15` (DESIGN-TBD).
307. **What else may happen while it rolls in?** Only its rev and charge are kept clear of every other attack
    (B4's "nothing else goes on"); while it rolls ahead before its warning, other enemies may still act, and
    only its lane is kept clear. One Buzz Overdrive at a time counts its roll too. The alternative is to keep
    everything off its roll as well (calmer, but it fits in fewer places).
    *Placeholder:* `FloorCutPlan.attack_window` (DESIGN-TBD).
308. **Its look.** A tracked tank in military gunmetal and olive (scorched and rusted in the Dead Zone), a
    giant vertical saw whose teeth glow hot orange-red (the deadly part), and a red slit eye under a dark brow
    on each side. Its blade runs along its lane like a real saw's, so head-on (the runner's view) it shows as
    a glowing edge and its eyes only from the side; at 50 m it is small, and the red line over its lane is
    what reads. The alternatives are a blade facing the runner, a zone-tinted body (gold trim in the Golden
    Zone) or a hover tank. *Placeholder:* `BuzzOverdriveModel` (DESIGN-TBD).

**The House, phases 2 and 3** (from E5a-b; numbers in `data/bosses/marketplace_boss_tuning.tres`; play `--level=marketplace/boss` or `--boss=marketplace_boss --phase=2`, review with `tools/showcase/the_house_showcase.tscn -- --scenario=wall|ceiling|defeat`)
309. **Phase 2's wall button** (GDD §10: "(2) one on a wall, with wall fences in play").
    **Placeholder:** the last button of the set (reel 3's, `special_reel`) stands upright on a side wall's
    facade at wall-run height, the same ivory disc and blue 7 as the floor's, reached by a wall run from
    the outer lane and passed at any height. Full-height wall fences pulse along both walls all phase (one
    every 2.2 s of run on alternating walls, on 1.0 s, off 1.4 s); a set is offered only where the wall run
    passes every fence while it's off, so the player wins it by timing. The machine's new attacks wait
    while the player goes for it. **Alternative:** partial-height fences, the button reached by entering
    high or low (B5's other way).
310. **Phase 3's ceiling button and its turrets** (GDD §10: "(3) one on a ceiling reached by an anti-grav
    pad, guarded by Barnacle Turrets").
    **Placeholder:** a floating billboard (GDD §5: the Marketplace's ceilings include "floating
    advertisements") comes down from the sky over every lane with a pad under it; the button is on its
    underside 1.1 s past the pad, in the pad's lane; one turret (3 lanes) or two (5-6 lanes) hang further
    along in a lane beside the pad's (C1's limits keep them at least 2.2 s past a pad, so they come after
    the button) and fire at the rider, who dodges a lane over. **Alternative:** a longer ceiling with the
    button past the turrets.
311. **The machine is taller than a ceiling** (GDD §10 gives it a building's height; a ceiling is 6 m up).
    **Placeholder:** at the lever's pull it squats on its treads to 4.9 m and stays down until it has rolled
    past the billboard's end, then rises. **Alternative:** it drops back further while a ceiling is over
    the street (smaller on screen for that stretch).
312. **The defeat** (GDD §10: "the reels spin wildly and jam, TILT flashes, and it collapses in an explosion
    of coins while the shops erupt in cheers").
    **Placeholder:** after the last stomp it lurches out and rises as after any stomp; its reels spin
    wildly for 1.0 s and jam between symbols, TILT flashes over them for 1.4 s (steady with Reduced
    flashing), and it tips over into the street ahead over 1.8 s while 90 coins burst out (for show: the
    fight's credits are the fountains') and the citizens cheer. **Alternative:** the coins land as real
    credits to collect.
313. **Par times** (GDD §10: "two and three stars for beating par times set per boss in data").
    **Placeholder:** a clean fight takes 66-68 s at 3, 5 and 6 lanes and both speeds; three stars at 72 s
    and two at 92 s (the Sleep Taker's margins over its clean run).

**The Gilded Sentinels** (from C4; numbers in `data/enemies/gilded_sentinel.tres`, F6 "Enemy: Gilded Sentinel"; play `--level=golden/2` (3–11 Sentinels per build) or `--level=golden/3` (1–5), review with `tools/showcase/gilded_sentinel_showcase.tscn`)
314. **Its niche goes into the wall** (GDD §9.11: "stands in a niche at wall-run height"; "pass above or
    below the swing"). A 2.6 m statue standing out from the wall would block a wall run at all of its
    heights, leaving no way above or below. So the statue (at 0.85 the kit's size) stands in a recess
    with its front just behind the wall face. Nothing of it reaches over the wall-run path; only its
    swing does. The Golden skins open the niche in their walls. Since a niche seen almost edge-on
    from down the street hides what's inside, its eyes' red light fills the niche while they flare.
    *Alternative:* a smaller statue standing proud of the wall, its solid body filling the band like a
    window cyborg's. **Placeholder:** `GildedSentinelTuning` (Statue and niche), `GoldenStatue.recess()`,
    `GoldenSkin.note_wall_enemies`.
315. **What it cuts.** On its wall, a band of heights centred on the free wall-entry height (as for
    window cyborgs): stepping onto the wall right before it is hit, a jump onto the wall (or a ramp)
    passes above, an early entry slides below. On the floor, the whole outer lane up to the band's top,
    so no jump clears it. Both run over a 5 m stretch, marked in red during the warning. *Alternative:*
    a band below the entry height, so a late step onto the wall passes above and timing alone decides.
    **Placeholder:** `band_offset`, `band_height`, `section_length`, `DESIGN-TBD` in
    `gilded_sentinel_tuning.gd`.
316. **The stomp from a wall jump** (proposed). A wall jump leaps out to the outer lane and never comes
    down on a statue in the wall. So the kick is the push-off itself: a wall jump made right by its head
    (feet from just under its helmet to half a metre over its crest, within about a metre of it along
    the track) stomps it. *Alternative:* weapons only. **Placeholder:** `kick_below`, `kick_above`,
    `kick_along`; `GildedSentinel.can_kick()`.
317. **"Later ones swing twice."** It swings forward across the stretch before its niche as the runner
    reaches it, then back across the stretch past it, so it guards twice the length. A runner sliding
    down the wall must stay clear of the band for longer. Doubles and pairs (one on each wall at the
    same spot) come from difficulty 0.95: the later ones in Golden 2, and in the Palace.
    *Alternative:* two swings over the same stretch a moment apart. **Placeholder:**
    `data/patterns/gilded_sentinel.json`.
318. **A big attack that can't wait** (GDD §9, R3). Its warning and swings count as a big attack, so the
    others wait for it, and its cut never overlaps another. A statue gets one chance as the runner
    passes, so it claims its turn 2.5 s before its warning (other types' attacks that get ready from then
    on wait), and if one begun before that is still on as its warning would start, it lets the runner
    pass, without warning or swinging. The generator keeps floor cuts, Octodog runs and ceilings'
    landings off it, and every big attack off the level's first. In simulated runs of Golden 2 and the
    Palace, 32 of 36 Sentinels swung (21 without the claim), and the other types' big attacks went from
    148 to 135 (Resonators plan their pulses off the Sentinels' turns). *Alternative:* count it as a
    small attack (like a screech's swipe), which never takes turns and always swings, sometimes during
    another big attack. **Placeholder:** `claim_seconds`, `GildedSentinel._tick`,
    `gilded_sentinel_rules.gd` (`BIG_ATTACKS`, `STRICT_ATTACKS`).

**Hostile Takeover, the train and The Board** (from E5b-a; numbers in `data/bosses/corporate_boss_tuning.tres`; play `--boss=corporate_boss`, review with `tools/showcase/hostile_takeover_showcase.tscn`)
319. **The train's rhythm and The Board's density** (GDD §10, phase 1: "security cyborgs guard the roofs, a
    Tithe Collector skims credits, and partial wall fences run along the track's sound barriers. Each
    carriage coupling glows red and sits in one lane above the gap"; no numbers).
    **Placeholder:** a gap across every lane every 3.2 s (carriages 50 m at 18 m/s, gaps half a jump); the
    fight opens with its 3 s entrance and then 4 more dark gaps past the one in sight, so the first
    coupling glows over the sixth gap (a later phase keeps 1 dark), then every gap's coupling glows, in a
    lane of its own (never the last one's, at most 2 lanes from it); 1 or 2 guards a carriage from the
    third on (never more than the lanes less one, never near a coupling's run-up or landing), a partial
    wall fence on 70% of the carriages, a Tithe Collector every fifth carriage. A runner who never misses
    stomps the first coupling 18.5 s in. **Alternative:** fewer dark gaps, or a coupling lit only on some
    gaps (one at a time, as The House's buttons).
320. **What counts as landing on a coupling** (GDD §10: "the player stomps it by landing on it while jumping
    the gap").
    **Placeholder:** its stomp box covers its lane over the whole gap and 1 m (at 18 m/s) past either edge,
    up to 0.55 m above the roofs: any jump that comes down over the gap in that lane stomps it, also from the
    lane beside it with a move in mid-air. That takes an early jump, from 4 to 12 m before the gap (a 0.45 s
    window); green chevrons (the Floating Head's way-up language) mark it on the roof in the coupling's lane
    while it glows. A jump from the edge sails over it (a harmless miss), and running off the edge isn't a
    stomp: the runner falls as in any gap. **Alternative:** only the coupling's dome counts (a smaller
    target), or no chevrons (the red coupling as the only cue).
321. **Credits for the Tithe Collector in a boss fight** (GDD §10: "a Tithe Collector skims credits"; a
    boss's track carries no credits of its own).
    **Placeholder:** each Collector comes in the runner's lane on a carriage with no guards (it weaves toward
    the lanes with the most hazards, so guards would draw it off), and a trail of 6 credits worth 5 is laid
    on the roof ahead of it to skim. Catching it pays what it holds plus its 120-credit jackpot, and phase 1
    has no time limit, so a player who lets couplings go by can catch one every 16 s or so. **Alternative:**
    no trail (it only robs on a touch), one Collector a phase, or a smaller jackpot in a boss fight.
322. **The sound barriers and the sense of speed** (GDD §10: "the track's sound barriers act as walls"; "the
    sense of speed comes from the scenery streaming past").
    **Placeholder:** the barriers are the run's walls, so they stay put beside the runner as in any level
    (plain gunmetal panels with nothing to show they should be rushing past); beyond them the city's towers,
    and far below the gaps the street, stream back at the train's 45 m/s on top of the runner's pace.
    **Alternative:** the barriers' panels stream past too (a wall run along a moving wall).
323. **Where the gunship and the locomotive are, and the Chairman's glimpse** (GDD §10: "a military gunship
    paces the train overhead"; "the player gets a glimpse of him: in the locomotive's window during the
    fight").
    **Placeholder:** the gunship flies 22 m ahead of the runner and 13.5 m over the roofs, swaying 2.4 m
    over 9 s (it sweeps in from behind and above as the entrance); the locomotive leads the train 125 m
    ahead at the end of the view, and the Chairman stands at its lit rear window the whole fight, small
    but clear (2.4 m tall, the window 4.6 m wide). **Alternative:** the Chairman shows only at moments (a
    stomp, a phase change), with the locomotive nearer then.

### Answered (recorded in GDD_CHECKPOINT.md)
- Wall entry follows the jump grace rule (§3, September 25, 2026).
- ~~Ceilings never carry obstacles underneath (§3, September 25, 2026).~~ **Reversed September 26, 2026:** the floor under a ceiling may be dangerous; only the landing zone must be safe (§3). The generator's "floor under a ceiling is clear" rule and test need changing, as does the drone-pad rule that removes floor pieces and enemies under a pad's ceiling (item 75).
- Mobile orientation is landscape (§2, September 26, 2026).
- Zone 1 is the Neon City, Zone 2 is Gangland (§5, September 26, 2026).
- Bosses are standalone mini-games; short cinematics sit between levels and zones. Both are designed later, and the build leaves slots (§6, §10, September 26, 2026).
- The player is a human runner in a cyber suit, about 75% of the grey-box size (§11, September 26, 2026).
- Music: code-generated placeholders for now (§11, September 26, 2026).
- The cult's symbol and colour: the Convergent Triad, option B of the D7 sheet (§5, September 26, 2026).
