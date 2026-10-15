# Open Questions: deferred

Questions still technically open whose placeholder works and blocks nothing. **Each placeholder stands as
built** until the owner reopens it, usually while playtesting. Sorted out of `docs/OPEN_QUESTIONS.md` on October 14, 2026.

Item numbers are permanent: code comments, tests and the GDD cite them ("`docs/OPEN_QUESTIONS.md` item 628", "FB 73").
An item lives in exactly one of three files, under its original heading and number:

- `docs/OPEN_QUESTIONS.md`: the few questions that need the owner (work waits on them, or the placeholder gets
  costlier to change later).
- `docs/OPEN_QUESTIONS_DEFERRED.md`: still technically open, but the placeholder works and nothing waits on it
  (tuning, names, looks, feel). **The placeholder stands as built** until the owner reopens it while playtesting.
- `docs/OPEN_QUESTIONS_ANSWERED.md`: answered, approved, superseded, or notes that ask nothing.

To find a cited item, search the three files: `grep -n "^628\. " docs/OPEN_QUESTIONS*.md` (build phase 2 items have
no prefix; "GB n" and "FB n" are in their own sections). **Don't read these files whole.**

## Design-phase checklists (sections A–C of the old list)

Written before the build. Much of it is built or decided since (see the GDD); what remains matters before launch
(ads, purchases, languages, age rating, the final music source), not for the next build task.

### A. Next design rounds (in recommended order)

#### 1. Zones (highest cost driver: do next)
- **Wall skin** for each zone, and what "signs" look like there.
- **New enemies:** the Marketplace's is the Barnacle Turret (GDD §9.8). The Corporate zone's is Buzz Overdrive (GDD §9.9). The Golden Zone's is the Resonator (GDD §9.10, working name). Also added: wall fences (§9.1), Gilded Sentinels (§9.11) and the Tithe Collector (§9.12).
- **Numbers still open:** the Resonator's shots to kill (Sentinels: 15; Tithe Collector: takes 25%).

#### 2. Bosses
For each boss: arena, phases, attacks, weak points, what power-ups are granted before the fight, how it scales on 3 vs 5–6 lanes, and its length.
- The House (Marketplace boss): revisit after playtesting (GDD §10).
- The Beach's boss: designed with the owner on October 10, 2026 (GDD §10, Mecha Guppy and Captain Cogs; task E5e). The owner's answers are items 749–765. Built (task E5e); the build's placeholders are items 767–824.
- The Golden Convergence (the final villain): designed with the owner and built on October 9, 2026 (GDD §10, task E5d). The owner's review of the parts Claude filled in under the owner's mandate, and the build's placeholders, are items 416–503 in §D below.

#### 3. Player character
- Player customization (GDD §11 covers the character itself).
- Cosmetic skins as a mobile purchase item?
- How it looks when using each power-up (claws, dash, shield, armor), redone for the new design.

#### 4. Remaining power-up details
- **Claws:** how much extra wall time? Upgrade tiers?
- **Juggernaut dash:** duration, cooldown, upgrade tiers, PC key.
- **Slow time:** strength, duration, cooldown, upgrade tiers.
- **Magnet:** number of tiers and radius at each (cap: own lane plus adjacent lanes).
- **Weapons:** fire rate per tier; damage for tiers 2–3; exact splash radius.
- **Prices** for everything, and whether prices differ between PC and mobile.
- **Ramps and speed pads:** exact speed and multiplier values; does speed reset after a boost?
- Confirm *(proposed)*: immunity comes from items only, not from ramps.

#### 5. Screens & UX
- **Shop layout** (including the equip toggle).
- **Level-complete stats screen:** which stats? (time, credits, kills, ramps used, deepest wall run, damage blocked, etc.)
- **Star criteria** per level.
- Main menu, zone/level select, settings, pause, death/revive flow screens.
- **In-level display (HUD):** score, credits, power-up cooldowns, level progress bar?
- First-time tutorial approach.

#### 6. Audio
- Music style per zone (synthwave, industrial, etc.).
- Sound-effect priorities (every telegraph needs a distinct sound).
- Source for music: for now, code-generated placeholders in the sound-effect style (GDD §11). Final source (commissioned, licensed, or keep generated) is still open.

#### 7. Mobile specifics
- The "dynamic adjustments based on parameters" you mentioned early on: what parameters? Device performance (quality settings), player skill (dynamic difficulty), or both?
- Ad rules: rewarded ads only (recommended), or also between-level ads? Frequency caps?
- In-app purchase catalog: credit packs, a "remove ads" purchase, cosmetics, starter bundle?
- Revive limits per level (e.g. max 1 ad revive per attempt)?

#### 8. Remaining mechanics details
- **Exact PC lane count:** 5 or 6?
- **PC keys** for jump, dash, and anything else.
- **Cyborg toughness:** laser tier 1 shots to kill.
- **Hover truck cannon:** projectile type, telegraph.
- **Run speed:** base speed, and does it increase within a level?
- **Difficulty tiers:** what changes in the harder tiers (speed, enemy density, lanes, no revives)?
- **Endless mode rules:** which zones' skins, how difficulty ramps, and whether credits are earned there.
- **Web demo:** portal-specific end screens if portals restrict store links.
- **Ceilings too safe in levels** (owner, October 10, 2026): revisit the safe landing rule (GDD §3), item 766 in `docs/OPEN_QUESTIONS.md`.

#### 9. Narrative
- The individual story beats and cinematics (the owner will describe them), and the cult's name (the story's outline is GDD §1; the cult's symbol and colour GDD §5).

#### 10. Other
- Working title.
- Save system: local only, or cloud save (Steam Cloud / platform saves)?
- Accessibility: colorblind-safe hazard colors (don't rely on pink vs purple alone), reduced flashing, screen shake toggle.
- Languages to support at launch.
- Age rating targets (affects violence and gore level).

### B. Build-planning questions (final round)
- **Total budget** for the Claude Code build, and whether you're on a subscription plan or API billing.
- How often do you want check-ins: after each milestone, daily, or only when blocked?
- Tolerance for autonomous decisions: which kinds of choices may agents make alone, and which must come back to you?
- Do you want playable builds at each milestone (web build link, Android test build)?

### C. Assumptions made that you can still overturn
- The EMP disables fences for the rest of the level (not timed).
- Hitboxes are slightly smaller than visuals.
- Forced ads between levels avoided in favor of rewarded ads.
- The first Octodog appearances get a doghouse hint; later ones don't.
- Screech clusters are the visual building block for the swarm boss.

## Raised during build

### From the R1 core-movement grey box (September 25, 2026)
Each item has a placeholder in code marked `DESIGN-TBD` and, where it's a number, a value in `data/tuning/movement.tres` or `data/levels/`. Answer them after playtesting the grey box.
2. **Run speed:** the placeholder is 18 m/s, constant within a level (`speed_gain_per_minute = 0`).
3. **Wall-run entry height:** 2.2 m from a free entry. Jumping into a wall adds 60% of the jump height. The descent eases (lingers high, then drops). Are these right?
11. **Pulsing fences:** on/off timings are placeholders (about 1.0–1.2 s each, with 0.35 s of flicker and an electric crackle before switching on).
12. **Difficulty within a level:** the placeholder adds +0.25 difficulty linearly from start to end.
15. **Sound effects:** these are generated by `tools/asset_gen/sfx_gen.gd` in a crunchy 16-bit / heavy-metal style (distorted power chords, pick scrapes, a motorbike rev, FM blips). Keep the direction, and which effects need a different character? Real recorded samples can replace any file in `assets/sfx/` under the same name.
16. **PC lane count** (see §8): the grey box now defaults to 5 lanes on PC and 3 on mobile. F1 switches to 6 for comparison.

### From the full build (September 26, 2026)
Placeholders the build needed to be playable end to end. Each is marked `DESIGN-TBD` in code or data;
numbers live in `data/` (mostly `data/tuning/*.tres`, `data/shop/catalog.json`, `data/levels/*.tres`).

**Campaign and structure**
3. **Cinematic slots:** City has intro, pre-boss and outro slots; Gangland has intro and outro. Where
   do you want cinematics, and what should each show?

**Economy**
10. **Payouts:** completion pays everything collected plus 100 + 25 per campaign level; stars at 45%
    and 75% of the best possible credit score (one star for finishing).
11. **Prices:** placeholders in `data/shop/catalog.json` (e.g. laser 900, heavy missile 9,500, armor
    150, shield 400, grapple 250, revive 600). A perfect run of both zones pays about 5,500 credits;
    all permanent upgrades cost about 29,700. Mobile-specific prices are supported but not set.
15. **In-app purchases** (stub only): two placeholder credit packs.

**Neon City look** (from the City skin work)
41. **Truck speed:** the road below streams toward the player at a placeholder 14 m/s.

**Audio** (from the audio work)
52. **Mix balance:** music sits about 10 dB under the attack warnings; the pause menu ducks music by
  8 dB. Needs a listen on real speakers and phones.
54. **Music style per zone** (OPEN_QUESTIONS §6): City is 160 BPM galloping synth-metal in E minor,
  Gangland 120 BPM drop-D industrial groove, menus 100 BPM synthwave.

**Cyborgs and fence generators** (from the cyborg work)
68. **Cyborg attack:** engages from 72 m; 0.75 s charge-up; bursts of 2–3 bolts 0.18 s apart; reload
  2.2 s early to 1.3 s late; bolts 10 to 15 m/s. The aim locks when the charge-up ends, so switching
  lanes after it dodges the whole burst. At these numbers a normal cyborg usually fires once before
  the player reaches it.
73. **Fence generators:** claws and running into one don't destroy it, and its body is solid (running
  into it kills, but armor absorbs the hit, like any other damage it works against: owner, October 10,
  2026). EMP radius 16 m; placed 9 m before its fence row. (Weapons no longer
  destroy one: item 31.)

**Octodog and Sewer Screech** (from their work)
75. **Octodog timing:** wind-up 0.95 s early to 0.8 s late; lunges from 15 m at 9 to 11 m/s with a 3 m
  overshoot. A red floor line shows the lunge path, added to the GDD's "visual cue".
80. **Octodog numbers:** score 250; gap-bait bonus 300; 5 shots to kill early and late (late scaling is
  open).
82. **Screech timing:** it decides 1.6 s out (at least 1.15 s of warning); shakes 0.6 s early to 0.5 s
  late; emerges in 0.22 s; dashes at 6 to 8 m/s for up to 4 m; the swipe winds up for 0.14 s and is
  live for 0.16 s, reaching 1.3 m at 1.0 m high (1.6 m from a vent). Score 100.

**Heli drone and hover truck** (from their work)
87. **Drone attack:** it swoops in, hovers 11 m ahead and 3.2 m up, winds up for 1.15 s early to 0.95 s
  late (glowing eye and an aim line), then fires 6 to 7 bullets 0.18 to 0.15 s apart. The aim locks
  when firing starts. A barrage fits inside the invulnerability window, so armor or a shield protects
  through all of it. It leads a wall runner's slide down the wall. Only one barrage at a time.

**The Cyborg's Bad Dream** (from its work)
96. **Where it floats:** 7.5 m ahead of the player, facing them, 1.3× scale (about 4.7 m tall); 7 m ahead
  while it waits under a ceiling.
97. **Chase timing:** 20–30 s from the burst (the clock runs while it holds a slash for another enemy's
  attack); slashes 3–4 s apart; it emerges over 1.0 s and first telegraphs 0.8 s later.
98. **Telegraph:** 1.2 s early in the campaign to 1.0 s late, then a 0.22 s lunge; the claws are live for
  0.12 s and it recovers for 0.7 s. It lines up within 0.5 m of the player's lane first, waiting at most
  1.2 s for a player who keeps moving.

**Platforms and presentation**
109. **App icon:** a placeholder neon "N" (`tools/asset_gen/icon_gen.gd`) until there's a title and brand.
111. **Achievements:** the platform layer can unlock them, but none are designed. Which ones, if any?

### From build phase 2 (September 26, 2026)
Questions the phase 2 build tasks raised (`docs/TASK_PLAN.md`), folded in from `docs/questions/<task-id>.md`
as each task merged. Each has a placeholder marked `DESIGN-TBD` in code or data.

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
5. **Partial wall fences "from the Corporate zone"** (GDD §9.1). Placeholder: from Corporate 1, at 50% of the
   level, after the Buzz Overdrive's introduction. Feature names: `wall_fences`, `wall_fences_partial`.
6. **Corporate 2's heavier military presence** (GDD §5, proposed). Placeholder: drones, hover trucks and Buzz
   Overdrives are picked 1.5× as often (`feature_weights` in `data/levels/corporate_2.tres`); their rules
   still cap how many fit. Should it also (or instead) be the Corporate skin's military ships and props?
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
14. **Two new placeholder patterns** (`data/patterns/prototype_patterns.json`): a pulsing fence in one lane
    (difficulty 0–0.6), since the other pulsing patterns start at 0.4, which City 3 barely reaches; and a speed
    pad in one lane with four credits after it (no pattern placed speed pads before, so Gangland 2's never
    appeared).

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
50. **How often the emblem hides in the market:** 40% of floating ads, rooftop boards and casino signs carry it as a
    small warm-white badge, and 40% of painted blade signs in unlit bronze; never smaller than 0.9 m, never an ad's
    main mark, never on hazard signs.
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
    the Barnacle Turret's burst is small (its "one fires at a time" stays its own rule *(Superseded October 8, 2026: up to two cyborg-type bursts may be in the air at once, GDD §9.2; items 600–603.)*); the Tithe Collector isn't an
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
      Resonator's warning (its chime until October 8, 2026).
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
138. **The calm band** (GDD §9.1: partial wall fences from this zone): below 7.2 m every wall is flush sterile cladding
    where nothing glows or sticks out, so a pink wall fence never competes; decoration starts at 8 m; the 2 m and 4 m
    wall-run height marks are pale unlit lines. Right heights?
140. **The military presence** (heavier in Corporate 2): compounds for 18% of buildings (blast walls with wire, a
    watchtower whose searchlight points at the sky, never the lanes, since a light on the lanes is the Floating Head's
    warning), gunships hovering 40–52 m up, gunships flying low as ceilings, olive freight cars; the plaza raises
    compounds to 30% and hovering gunships to 80%. Right forms and amounts?
144. **A boss arena over the street** (Hostile Takeover's gunship): setting four shares to 0 clears everything above the
    lanes (street screens, banners, skybridges, hovering ships). The right things to clear?

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
196. **One on screen at a time:** a Resonator arriving sends the last one away after its current pulse. Right?

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

**The Sewer Swarm, the clusters and the Rising** (from E4a; numbers in `data/bosses/gangland_boss_tuning.tres`; play `--boss=gangland_boss`, review with `tools/showcase/sewer_swarm_showcase.tscn` and the stress scene `tools/showcase/swarm_stress.tscn`)
324. **How a cluster is baited** (GDD §10: "the player baits the swarm into attacking, dodges in time, and the
    swarm hits a live electric fence and is shocked"; phase 1: "a cluster surges down a lane ahead of the
    player, with a red lane line and a rising chitter").
    **Placeholder:** a surge comes down the runner's lane. For 2.4 s before it would meet them
    (`warning_seconds`) its cluster rears at the roadside ahead, its chitter rises and a red line runs down
    the runner's lane to it, following them from lane to lane and ending at any fence or hole on it. 1.1 s
    before (`lock_seconds`) the cluster lands in the runner's lane and charges; the line locks there. A runner
    who held a lane with a fence or a hole on the line until then, and gets out of it after (or jumps the
    fence or the hole), has the cluster charge into it in front of them: shocked or falling, destroyed. One
    who leaves too early has the line follow them; one with no bait in their lane dodges it.
    **Alternatives:** the line locks as the warning starts (the runner must already stand in the bait's lane),
    or the cluster always goes for the bait's lane (no luring, just dodging).
325. **The arena** (GDD §10: "the street is the weapon"; the fight is "Gangland's final exam").
    **Placeholder:** Gangland's generated street (its holes and fences only: no signs, ceilings, pads or
    doodads) with a bait spot every 200 m at 18 m/s (`bait_spacing`, about 11 s at any speed): a live
    full-height fence or a hole in one lane in turn, the street around it clear, and a surge at each one. A
    runner who baits every surge ends phase 1 in about 20 s.
    **Alternatives:** surges at the generator's own fences and holes wherever they fall (more varied, less
    predictable), or a plain street with only the baits (as The House's).
326. **Weapons against the clusters** (GDD §10: "weapons thin clusters too, and the heavy missile gets bonus
    damage against them").
    **Placeholder:** a cluster is a target only while it surges (from its warning until it has passed), with
    36 laser tier 1 shots of health (`cluster_health`); its crowd thins as it's hit, and one thinned to
    nothing is destroyed and counts like a baited one (the heavy missile does it over about two of its surges,
    laser tier 1 over about seven).
    **Alternatives:** weapons only thin a cluster (it never dies to them), or a cap like the other bosses'
    `weapon_share_cap`.
328. **A horde that never hurts** (GDD §10: "it builds up on both sides of the street"; CLAUDE.md: safe things
    look safe, deadly parts look deadly).
    **Placeholder:** heaps of screeches line both gutters from the fight's start (scenery: never in the lanes,
    never hurting), and the waiting clusters are heaps at the roadside ahead; only a surging cluster heats to
    enemy-attack red and hurts. Is a harmless horde at the walls' feet the right read?
    **Alternative:** the horde stays down in the manholes and vents until it surges (an emptier street).

**Lag spikes** (from PERF1; numbers in `data/tuning/speed_fx.tres` and `data/tuning/performance.tres`, F6; the frame-time graph is F7 in debug builds, or `--frame-graph`)
329. **The hit-stop on every kill** (GDD §3, "a brief freeze on kills"; G2's `RunEffects.freeze`). It holds
    the camera still for about three frames (0.05 s) while the run goes on underneath, so the runner moves
    1.0 to 1.25 m away from the camera and the view catches up in one frame: on screen that is exactly what
    a dropped frame looks like. A stocked-up player's run has 4 to 24 of them a level, about 6 a minute
    (`tools/measure/frame_times.gd`, the whole campaign), and 23 a minute in Hostile Takeover's preview,
    where the weapon meets a guard every few seconds; the build before the playtest had none, so they
    may be most of what reads as "more lag spikes". Freezes no longer chain (below). Should every kill keep
    it, or only stomps and big kills (a host, a hover truck, a boss's part), or a shorter one (one or two
    frames), or a freeze of a different kind (the enemy and the runner's animation held for a moment, the
    camera moving on)?
    - **Placeholder:** every kill keeps it, as G2 built it. Freezes never stack or chain:
    `SpeedFxTuning.freeze_gap` (0.3 s, `data/tuning/speed_fx.tres`, F6 "Speed effects") leaves out a
    freeze asked for within 0.3 s of the last one's start. Setting `kill_freeze_time` to 0 in F6 turns
    the kills' freeze off while keeping the stomps'; Settings > Screen shake off turns every freeze off.
    The frame-time graph (F7) marks every frame a hit-stop holds the camera, so a "spike" that is one
    shows as one.

**Hostile Takeover, phase 2: The Contract** (from E5b-b; numbers in `data/bosses/corporate_boss_tuning.tres`; play `--boss=corporate_boss --phase=2`, measure with `tools/measure/hostile_takeover.gd`)
331. **The train's carriages, and the Tithe Collectors** (GDD §10: "carriage roofs are the floor and the gaps
    between carriages are the gaps"; phase 2's Buzz Overdrive "cuts a carriage lane"; OPEN_QUESTIONS items 319
    and 321).
    **Placeholder:** the train repeats corporate carriage, corporate carriage, military flatcar, then three
    corporate carriages. A corporate carriage is 50 m and a flatcar 130 m (at 18 m/s). A Buzz Overdrive needs
    about 100 m of whole roof in its lane, from its rev to its charge past the runner, which no corporate
    carriage has. In phase 1 a Tithe Collector comes on each flatcar from carriage 3, so item 319's "every
    fifth carriage" is now every flatcar, every sixth carriage. At most 2 come in a phase
    (`tithe_visits_per_phase`): without a cap, a runner who lets couplings go by could farm their 120-credit
    jackpots (item 321). Code: `HostileTakeoverTrain`, `HostileTakeoverBoard`.
    **Alternative:** longer carriages all along (a slower rhythm of gaps), or a cut that may span a gap. For
    the Collectors: one a phase, or none once the first coupling has been let go by.
332. **The strafes** (GDD §10, phase 2: "the gunship strafes the lanes (a warning line and a rising whine)").
    **Placeholder:** red lines light the runner's lane and the one beside it, from 3 m behind them to 40 m
    ahead, with a 1.2 s rising whine. At 3 lanes it strikes one lane; at 5 or 6 lanes, two; never all. Then
    the guns rake each line from its far end back past the runner at 55 m/s (at 18 m/s). A rake hits anyone
    in the lane, a jump included; leaving the lane dodges it, and the walls are safe. Strafes come about a
    second apart when nothing else is going on: never near the drop or the ride, and never while phase 1's
    guards are still about. Code: `HostileTakeoverContract`, `HostileTakeoverStrafes`.
    **Alternative:** a sweep across the lanes that a jump dodges, or a line that follows the runner from lane
    to lane.
333. **The drop** (GDD §10: the gunship "drops a Buzz Overdrive onto the roof ahead, which cuts a carriage
    lane").
    **Placeholder:** one lands on each flatcar. The gunship flies out over the spot, and a red target marks
    where it will land. The tank falls for 0.7 s and lands 0.6 s before its rev. From then on it is the C2
    tank: its rev and red line, its charge cutting the lane past the runner, and the block-then-hold rule. Its
    cut is planned like a level's (`FloorCutPlan`, `cut_problem`), in a seeded lane. Code:
    `HostileTakeoverContract.plan_drop`.
    **Alternative:** it lands further ahead and rolls in, as it does in the levels, or it drops onto a lane
    chosen from where the runner is.
334. **The armored carriage and the ride** (GDD §10: "an armored carriage with no roof access blocks the way,
    so the player takes an anti-grav pad and rides the gunship's belly over it (the gunship is the
    ceiling)").
    **Placeholder:** the second carriage after each flatcar is armored. It is 2.1 m tall: too tall to jump
    onto, and below a belly rider's jump. Its front is framed in the solid obstacles' yellow and black, and
    it is in sight 240 m ahead. Before it lies a runway of anti-grav pads in every lane, 18 m long at 18 m/s.
    That is longer than any jump, a dash in the air included, so no runner on the roof can skip it. The
    gunship comes down over the runner as they reach it and flies on slower than them, so they ride its belly
    over the armored carriage and drop off 10 m past its far gap. A runner who isn't flipped up (in practice,
    none) crashes into the armored front; the dash doesn't pass through it. Code:
    `HostileTakeoverArmored`, `HostileTakeoverContract.plan_ride`.
    **Alternative:** a single pad in each lane, as "an anti-grav pad" reads, which a jump can skip, or pads
    in some lanes only.
335. **Phase 2's weak point** (GDD §10 names none for The Contract).
    **Placeholder:** the gunship's drop bay, which the Buzz Overdrive fell from. During the ride it is open on
    the belly, glowing the weak points' red, with green chevrons before it. A jump on the belly that comes
    back up onto the bay stomps it, a stomp from the ceiling. A missed bay is harmless: the ride ends, and the
    next flatcar's drop and ride come about 23 s later. Each cycle brings another Buzz Overdrive, worth 600
    score to kill. Code: `HostileTakeoverGunship.bay_point`, `HostileTakeover._bay_stomped`.
    **Alternative:** a weak point reached another way (the tank's clamp under the belly, or a part shot
    off), or the phase's hit for just completing the ride.

**The Buzz Overdrive and turn-taking** (from FIX2; numbers in `data/enemies/buzz_overdrive.tres`, F6 "Enemy: buzz_overdrive", Turns; review with `tools/showcase/buzz_overdrive_showcase.tscn -- --pass`)
337. **What does a Buzz Overdrive do when it can't get its turn?** (GDD §9: "big attacks take turns"; §9.9:
    its cut is planned in advance.) It never asked for a turn and counted as attacking only from its rev, so
    another type's attack that started a moment before (when only its roll was on) ran on into its rev: over
    the seven levels that have it, at 3, 5 and 6 lanes on 13 seeds each, 73 of 380 tanks revved into a drone's
    barrage, a hover truck's lurch or cannon shot, or a Resonator's pulse (87 s of two big attacks at once).
    It can't wait (a later cut would run over floor the generator never checked).
    **Placeholder:** like a Gilded Sentinel (C4), it claims its turn `claim_seconds` = 2.5 s before its rev,
    while it rolls ahead (other types' big attacks that get ready meanwhile wait for it), and if one begun
    before its claim is still on as its rev would start, it lets the runner pass: no rev, no red line, no
    cut (its lane stays whole); it speeds off ahead and is out of view `pass_seconds` = 3 s later (far ahead,
    in the fog, it may cross a hole or fence in its lane). Measured over the same runs with the claim: no
    overlap; 378 tanks revved and 2 let the runner pass (both behind a Resonator's pulse); the others lost
    57 of 2,163 drone barrages, 14 of 632 cannon shots and 7 of 527 lurches, and drones waited 2.05 s on
    average instead of 1.71 s (`data/enemies/buzz_overdrive.tres`, F6 "Enemy: buzz_overdrive", Turns; `DESIGN-TBD` in
    `scripts/enemies/buzz_overdrive_tuning.gd`). This also narrows item 307's placeholder: other enemies may
    still act while it rolls ahead, but not in its last 2.5 s before its rev. A boss's tank (Hostile
    Takeover's drop, no roll) neither claims nor passes, as before: the boss keeps its own attacks off it.
    **Alternatives:** a longer claim (up to its whole 4 s roll: fewer passes, the others held longer), the
    generator keeping every other enemy off its roll too (fewer places fit a tank, and attacks timed at run
    time would still need the claim), or revving anyway (two big attacks at once, as before).

**The Sewer Swarm, phases 2 and 3** (from E4b; numbers in `data/bosses/gangland_boss_tuning.tres`; play `--level=gangland/boss`, review with `tools/showcase/sewer_swarm_showcase.tscn`)
338. **Strikes from behind** (GDD §10, phase 2: "clusters also strike from behind. The warning is a chittering
    sound plus a visible rising wave of the swarm on screen, curling like a breaking wave or a scorpion's
    stinger, about to strike its lane").
    **Placeholder** (`SwarmSurges`; `SewerSwarmTuning`, "Surrounded"): phase 2's surges alternate, from behind
    then from ahead (`surge_sides`). From behind: 2.6 s before it would catch the runner
    (`behind_warning_seconds`) a wave of the swarm rises 9 m behind them in their lane, 6.75 m high, its crest
    curling over them; its chitter rises and a red line runs down the lane ahead to the first fence or hole.
    1.2 s before (`behind_lock_seconds`) it locks on their lane; then it crashes down there and surges on ahead,
    faster than the runner, into that fence or hole (destroyed: a hit) or 30 m on and back into the gutter. A
    runner who holds the bait's lane until the lock and leaves it then baits it.
    **Alternatives:** strikes from behind are only dodged (never baited), or the wave covers every lane but one.
339. **The wall climb** (GDD §10: "the swarm also climbs the walls, taking them away as an escape route, but only
    temporarily ... one wall at a time for a few seconds, alternating sides, so one wall is always free").
    **Placeholder** (`SwarmClimb`): both walls free for 2.5 s, then the swarm covers one wall for 4 s, sides
    alternating (the first seeded). A covered wall refuses entry like a sign (the clank and the bump) and never
    hurts; the climb waits while the runner is on the wall it's due to climb.
    **Question:** should a covered wall hurt (an enemy attack) or knock a wall runner off instead?
340. **The clusters in phase 3** (follows question 327: with five clusters, none are left for phase 3).
    **Placeholder** (`SwarmHostAttacks`, flings): phase 2 ends with all five destroyed. In phase 3 the Host
    flings a ball of screeches scooped from the roadside horde at each hole spot: it rears with it (0.7 s, its
    heave heard) while a red circle marks where it will land in the runner's lane, the ball lands 1.1 s later,
    splats into a short mass for 0.8 s (an enemy attack) and scatters. A dodge, never a hit on the Host.
    **Alternatives:** phase 2 ends with one or two clusters left for the Host to fling, or a flung cluster can
    be baited into a fence or a hole too.
341. **The Host's way up** (GDD §10: its implants are reached "by a ramp and a wall jump"; "three stomps").
    **Placeholder** (`SwarmHostAttacks`, crouches; `SwarmJumpMarks`; the arena's host spots): 88 m after each
    bait spot the arena has a ramp in an outer lane (sides in turn), the street clear around it. When the
    runner is 55 m before it, the Host leaps into the ramp's lane and crouches 14.5-27 m past the ramp, long and
    low (2.1 m): solid to run into, its sides bump a lane switch back, its three implants glow red along its
    back, and green chevrons on the ramp's wall show where to jump. A ramp, a wall run and a wall jump come
    down on the implants: a stomp, one of the three hits. Missed, it rises and goes back to pacing 26 m ahead.
    The Host is a mound of screeches (3.4 m wide, 4.8 m tall) around the person, who shows more at each hit.
    **Question:** is the crouch beside a ramp the right way to reach the implants, and is this the Host's look?
342. **The lunge into a fence** (GDD §10: "its lunge can also be baited into a fence").
    **Placeholder** (`SwarmHostAttacks`, lunges): at each fence spot it lunges down the runner's lane like a
    surge (the same 2.4 s warning with its roar and the red line, locking 1.1 s before). Into the fence it's
    shocked: a hit like a stomp, down in that lane for 1.2 s; otherwise it charges past and leaps back. A
    runner who baits every lunge frees the Host with fewer stomps (a clean run: one lunge baited, two stomps).
    **Question:** should a baited lunge count as a full hit, or only weaken the Host so the stomps are still
    needed?

**Hostile Takeover, phase 3 and the defeat** (from E5b-c; numbers in `data/bosses/corporate_boss_tuning.tres`, groups "The Merger" and "The defeat"; play `--level=corporate/boss` or `--boss=corporate_boss --phase=3`)
343. **The docking and MERGER COMPLETE** (GDD §10, phase 3: "the locomotive comes back and the gunship docks
    onto it with huge clamps, forming one monstrous war engine, and 'MERGER COMPLETE' flashes on every
    screen"; the player glimpses the Chairman "as the face on the 'MERGER COMPLETE' screens"). Which screens,
    and how long does the docking take?
    **Placeholder:** once phase 2's last ride is over, a 3 s docking: the locomotive comes back from far ahead
    to 64 m ahead of the runner while the gunship settles onto its rear, three arms gripping it and its three
    clamps unfolding as they lock. Then MERGER COMPLETE flashes for 5 s (steady with Reduced flashing) on the
    locomotive's rear window, turned screen, and on two ad screens on pylons that rise beyond the sound
    barriers and pace the train ahead (the arena has nothing over the street). Each shows the Chairman's face
    as a corporate broadcast; he leaves his window. The war engine's first strafe waits 1.5 s after the words
    come up. Code: `HostileTakeover._update_merger`, `HostileTakeoverScreens`, tuning group "The Merger".
    **Alternative:** the city's own screens on the towers, a longer docking the player watches, or the
    Chairman staying at his window.
344. **How the clamps are reached** (GDD §10: "the player stomps the three glowing docking clamps (red weak
    points) to tear the gunship loose"; it doesn't say where the clamps are or how the runner gets to them).
    **Placeholder:** after each drop, a pass: a runway of anti-grav pads on the carriage after the flatcar;
    the war engine comes back down over the runner there, and they ride its belly forward at 3 m/s (at any
    run speed, 6.3 s) under its three clamps, one under each third of the belly (7, 12.75 and 18.5 m from its
    stern), each glowing red with green chevrons behind it. A jump from the belly that comes back up onto a
    clamp stomps it. Then the war engine pulls away and the runner drops back onto a roof clear of the gaps.
    All three can be torn loose in one pass (1.9 s apart: after a stomp's bounce there is time for a
    reaction and two lane moves), and clamps missed come around on the next pass, about 25 s later. Code:
    `HostileTakeoverContract.plan_pass`, `HostileTakeoverGunship.clamps`, tuning group "The Merger".
    **Alternative:** the clamps reached from the roof (a ramp onto the locomotive), one clamp a pass, or the
    clamps on the war engine's rear, stomped with a jump from the roofs.
345. **Phase 3's attacks** (GDD §10: "its attacks combine both"). Which of the earlier phases' attacks come
    back, and how dense?
    **Placeholder:** the Board's guards (one on the first carriage of each consist of six) and partial wall
    fences (on its first two carriages; no Tithe Collector), the war engine's drops (a Buzz Overdrive onto
    each flatcar, as phase 2's) and its strafes, only when nothing else is going on (one attack at a time, as
    in phase 2). In a fight without a miss, phase 3 shows the Board's pieces, a drop and the pass; strafes
    come between later cycles (after a missed pass). Code: `HostileTakeoverBoard.merger`,
    `HostileTakeoverTuning.merger_board_slots`, `merger_guards`, `merger_hold`.
    **Alternative:** a strafe guaranteed before the first pass (the phase grows by a few seconds), or a
    denser Board.
346. **How phase 3's three hits count** (follows item 336: weapons can't end Hostile Takeover's phases).
    **Placeholder:** a framework change, `BossEncounter.phase_hits`: while a boss's weapons can't end a phase,
    its big hits are counted. Each deals an equal part of what's left of the phase for each hit still to
    land, and only the phase's last one ends it, exactly at its end. So nothing weapons chipped carries into
    the next phase, and phase 3 always takes its three clamps, however far weapons chipped it (weapons still
    chip within their 0.34 cap). Code: `BossEncounter.hit_damage`, `BossEncounter.damage`.
    **Alternative:** damage carrying over (a phase chipped to its floor shortens the next one), or counting
    only the last phase's hits.
347. **The defeat** (GDD §10: "the gunship spins away and explodes; the locomotive derails and ploughs
    through the lobby of a corporate tower, bringing down a giant, soulless logo sculpture").
    **Placeholder:** the last clamp torn loose, the gunship pulls free, climbs away beside the line spinning
    and explodes 1.6 s later; the locomotive surges on, veers off the guideway to the right and ploughs into
    the sky lobby of a corporate tower standing beside the line at the train's level 2.6 s in, the brand's
    mark (a giant steel sculpture on its plaza) toppling back into the lobby; the screens glitch and go dark.
    The runner and the rest of the train run on along the guideway past the wreck, and the results come 5.5 s
    after the stomp. The lobby stands still beside the line while the city streams past (the city's towers
    keep clear of it), so the crash reads; a lobby moving with the city would rush past in a second. Code:
    `HostileTakeover._on_defeated`, `_place_defeat`, `HostileTakeoverLobby`, tuning group "The defeat".
    **Alternative:** the whole train derailing (the runner jumping clear), or a cut to a short cinematic.
348. **Par times** (GDD §10, proposed: stars for beating par times set per boss).
    **Placeholder:** 74 s for three stars and 96 s for two. A fight without a miss takes 68.6 s at 3, 5 and 6
    lanes and at 18 and 23.4 m/s; a missed pass costs about 25 s. Data: `data/bosses/corporate_boss.tres`.

**Getting main green again** (from FIX4; City 1 gaps in `data/tuning/danger_density.tres` and `scripts/world/gap_density.gd`; the Resonator in `data/enemies/resonator.tres`)
349. **Zone doodads or City 1's extra gaps: which gives way?** (GDD §3 zone doodads; docs/USER_REQUESTS.md,
    more gaps in City 1.) The doodads were built to only add to a level (the same level without them, plus
    them), and City 1's extra-gap pass, which runs after them, was built to keep every doodad where it is.
    Where both want the same stretch, one has to move. Placeholder: the doodads stay, and the extra gaps
    keep out of their way, but a row widened with a lane left open now keeps off a doodad's own lane and
    window only, not a margin around it in every lane (`DESIGN-TBD` in `scripts/world/gap_density.gd`, the
    widening in `apply`). A row widened to full width (a jump, which lands past the row) and a new row still
    keep the margin from a doodad, so the doodads can still decide where those go: over test_city_gaps' 33
    City 1 builds (3, 5 and 6 lanes, seeds 1 to 8, every tier) the doodads change the gaps in 15 (19 before),
    almost all through a full-width jump a doodad stands too close to, among them the shipped City 1 at 6
    lanes on the 0.35 tier; the shipped default tier, at every lane count, no longer.
    The alternative: run the extra-gap pass before the doodads, so the doodads fill what it leaves and only
    ever add (City 1's doodads at 3 and 5 lanes then stand elsewhere, and test_city_gaps would no longer
    expect them unchanged).
350. **A Resonator still owing its first pulse when the next one arrives** (GDD §9.10, §9 big attacks take
    turns). Placeholder: a first pulse overdue by `ResonatorTuning.turn_wait_max` (8 s of waiting, for other
    attacks or for clear floor) keeps its place in the turn queue, so the other types' next attacks wait for
    it and it pulses at the next clear floor (`DESIGN-TBD` in `scripts/enemies/resonator.gd`,
    `_first_overdue`). Before, a long Bad Dream chase over a visit's planned pulses, then a drone that
    stays, could keep it from ever pulsing until the next Resonator's arrival sent it away (Golden 2 at 6
    lanes). Not seen since in the Golden campaign layouts, but a chase a player sets off can still last
    past the next visit's arrival, and the arrival still sends the last one away (one on screen at a
    time). The alternative: the next one holds back far ahead until the last one's first pulse has begun
    (two on screen meanwhile, and its own visit may then run out of level).

**The Enforcer Truck** (from C6; numbers in `data/enemies/enforcer_truck.tres`, F6 "Enemy: Enforcer Truck"; play `--level=corporate/2`, review with `tools/showcase/enforcer_truck_showcase.tscn`)
354. **Its numbers and presentation** (GDD §9.13, proposed values and gaps), all in
    `data/enemies/enforcer_truck.tres` (F6 "Enemy: Enforcer Truck"): it drives in from 45 m behind with a siren
    and follows 8.5 m back (behind the camera, 7.5 m), closing to 2.4 m during an Octodog's attack; a volley is
    a 1.0 s warning (the line and the whine) then 3 shots of 3 stacked bolts 0.12 s apart, the first 3 s after it
    arrives, then 5 s from each volley's end, each rider 40% quicker; it holds its fire from 2.7 s before a
    bait's warning; it scores 1,000 plus 250 a rider (`DESIGN-TBD`); it arrives so its bait's warning comes 4 s
    or more after it, its hold preferably 8 to 13 s after (a volley or two first: 87 of 104 sampled trucks) and
    the charge 5 s or more before it gives up, 8 s between two trucks; Corporate 2 introduces it 5% into the
    level (`feature_starts` in `data/levels/corporate_2.tres`, before the Tithe Collector's 10%: the level's
    only baits at 3 and 6 lanes come within its first 32 s); its marker shows a pip for each rider. Confirm in
    playtest?
355. **Its volleys at a runner off the floor** (GDD §9.13 "lasers at the player's lane"). Placeholder: a volley
    starts only while the runner is on the floor, and its bolts keep to the floor lane it warned (from slide
    height to above a jump), so a runner on a wall or a ceiling is never its target
    (`EnforcerTruck._ready_to_fire`). Should it also fire at wall runners or ceiling riders?

**Wider gaps and cyborgs in charge paths** (from G7; numbers in `data/tuning/wide_gaps.tres`, `data/tuning/charge_paths.tres` and each level's `wide_gaps` / `charge_path_cyborgs`; review with `tools/showcase/wide_gap_review.tscn` and `charge_path_review.tscn`)
356. **How wide, how many, and how much room around a wider gap?** (GDD §9.13 "Holes": "a couple of wider gaps
    ... still jumpable ... wide enough that an Enforcer following the player into one is wrecked".) Is 0.7 of a
    full jump right (the levels' own gaps are 0.4 to 0.55; the truck hops up to 0.6; a normal jump clears 0.7
    from a take-off window of about 0.3 s), with nothing else in any lane from 0.9 s (or the level's spacing
    there, up to 1.1 s) before the take-off to as long after the landing, and 15 s between the two?
    - Placeholder: `data/tuning/wide_gaps.tres` (`jump_fraction` 0.7, `clear_before_seconds` and
    `clear_after_seconds` 0.9, `spacing_seconds` 15) and `wide_gaps = 2` in every campaign level
    (`data/levels/*.tres`); `DESIGN-TBD` on `LevelConfig.wide_gaps` and `WideGapPlacement`.
357. **Where do they come from, and should one always fall in an Enforcer Truck's chase?** The generator widens
    the level's own rows first, else adds new rows (every lane but one), else takes other holes and plain fences
    out of a row's way; it prefers one in each Enforcer chase, which happens in 11 of the 18 level and lane
    builds that have trucks (Corporate 2 at every lane count). Is a single-lane hole made wider acceptable as one
    of the couple (the runner usually steps around it), and should every chase be guaranteed one?
    - Placeholder: `WideGapPlacement` (`prefer_enforcer_chases`, `add_rows` in `data/tuning/wide_gaps.tres`;
    rows across more lanes preferred, single holes allowed).
358. **Is the planted Octodog lunge's line right?** (GDD §9.13 "Teaching", §9.4.) Its first lunge goes along a
    line through the cyborg in the lane beside it, two lanes across, rather than at the runner's lane (its red
    line shows it; its later charges aim at the runner as always), and a dog without two lanes beside it on a
    side moves to another lane at its spot.
    - Placeholder: `Octodog.planted()`/`_lunge_vx`, `ChargePathPlacement.dog_option`; `dog_cyborg_ahead` 2.5 m,
    `claim_seconds` 4 s in `data/tuning/charge_paths.tres`.
359. **Is a parked Buzz Overdrive right?** With a cyborg planted in its lane, the tank waits at its cut's end
    instead of rolling ahead of the runner (it would drive through the cyborg), then revs and charges as
    planned. It sits still in view longer, so a runner with missiles may shoot it before its rev.
    - Placeholder: the cut's `park` (`BuzzOverdrive.parked()`), `tank_cyborg_seconds` 0.35 s.
360. **How often should a charge flatten a cyborg?** Each level with Octodogs or Buzz Overdrives asks for one; 7,
    6 and 8 of those 11 levels get one at 3, 5 and 6 lanes (none where every encounter is the introduction,
    near a Resonator's pulse or a Gilded Sentinel, or has no room for a cyborg), and one always comes before
    Corporate 2's first Enforcer. Never the introduction of the Octodog or the Buzz Overdrive.
    - Placeholder: `charge_path_cyborgs = 1` in those levels, `skip_introductions` and `attack_margin_seconds`
    2 s in `data/tuning/charge_paths.tres`.

**The Enforcer Truck shows itself; its explosion** (from C6b; groups "Showing itself" and "Wreck" in `data/enemies/enforcer_truck.tres`, F6; review with `tools/showcase/enforcer_truck_showcase.tscn -- --scenario=show` or `--scenario=cut`)
366. **Its first volley waits for its first showing.** So the runner sees what's chasing them before it fires,
    the first volley waits up to `show_wait_seconds` (4 s) past its time, as long as a showing can still come
    before the bait. Placeholder: as described (`DESIGN-TBD` on `show_wait_seconds`). Keep this, or fire on time?
368. **Where the blast happens** (owner, October 8, 2026: a visible explosion). Behind the camera a blast would be
    unseen. So a wrecked truck first lurches forward into view over `wreck_surge_seconds` (0.3 s), until its front
    is `wreck_gap` (2.8 m) behind the runner, or reaches the far edge of the hole it fell in. Then it blows up and
    falls back slowly (`blast_drift`). This bends the physics a little so the blast is readable. It's smaller and
    lower in the runner's lane (`blast_radius_in_lane` 0.85 m, against `blast_radius` 1.3 m beside them) so it
    never hides them. Placeholder: those values (`DESIGN-TBD` on the "Wreck" group). OK, or should a wreck behind
    the camera show differently (only fire and debris rising into view)?

**The Neon City's outro** (from F2a; the owner's beats, GDD §6 Cinematics; numbers in `data/cinematics/city_outro_tuning.tres`, code in `scripts/cinematics/city_outro.gd` and `city_outro_set.gd`; review with `tools/showcase/cinematic_review.tscn -- --slot=city/outro`)
369. **Its length** (GDD §1: 5–15 s). The owner's beats are many. Placeholder: 15.0 s, the top of the range
    (`duration`): about 2 s for the crash, 3 s for the stop and the look, 3 s on the roadblock, 2 s for the escape
    and leap, and 4.4 s for the landing in Gangland. Should it run longer, or should Gangland's intro flyover (next,
    9.5 s) be shortened or dropped after it, since the outro already lands the runner in Gangland?
370. **Where the roadblock stands** ("He looks to the left, and there we see a barricade"). Placeholder: the left
    wall opens onto a side street, built from the City's own truck roofs laid across it and lined with its building
    fronts. The roadblock stands at its mouth, a few metres ahead of where the runner stops (`side_*` values). Is a
    side street what the owner pictured, or should the roadblock block the main street?
371. **The barricade's look.** Placeholder: low concrete blocks with navy and white rails, in the Enforcer Truck's
    police paint and never a hazard colour, with a cold-white floodlight at each end. The Barnacle Turrets stand in
    the gaps between the blocks like cannons (`CityOutroSet._barricade_mesh`). Should it look like Gangland's crate
    and container barricades instead?
372. **Which battle truck.** Placeholder: the Enforcer Truck (police-style, light bar, two cyborg gunners on its
    roof), because its model was already built to be shown on its own. The hover truck (Neon City 3's mini-boss) is
    the one the player has actually met by Zone 1's end. Which one?
373. **Turrets and drone.** Placeholder: 3 turrets (`turrets`) in the mechanical City look, and the heli drone over
    the truck. The player meets neither in Zone 1 (the drone arrives in Gangland 3, the turret in the Marketplace),
    so the outro previews both. Intended?
374. **"Runs in the opposite direction".** Placeholder: away from the roadblock. The runner hops back to the right,
    startled, then sprints right and slightly ahead to an opening in the right wall, and leaps out over the drop to
    the road far below. The other reading is a U-turn back the way they came. Which did the owner mean?
375. **The explosion.** Placeholder: the roadblock fires a red volley (each cyborg and turret), which blows up the
    truck roof the runner just leapt from (the Enforcer Truck's blast, bigger: `blast_*` values). The camera is out
    over the drop, so the runner flies toward it with the fireball behind them. Should it be something else, such
    as the battle truck firing or the Floating Head's wreck going up?
376. **The cut to Gangland.** Placeholder: the runner falls into the haze toward the road far below. The picture goes
    to black for about half a second, then the runner drops into a Gangland street from about 7 m, lands, glances
    left and right, and runs off. The cut happens under black because building Gangland's street takes a few frames.
    Is a cut to black acceptable, or should the camera follow the fall all the way down? A continuous fall would
    need the City's road below to become Gangland's street, a bigger job.
377. **Runner animation.** The rig has no "stop and look" or "startled" animation. Placeholders: a head turn shared by
    chest, neck and head (the toolkit's new `look` on cinematic keys), and a small hop back (`startle_hop`, 0.35 m)
    that uses the jump pose. Should it have a proper startled pose?
378. **Music.** Placeholder: the City's track plays and fades out as the runner leaps, and Gangland's comes in with
    its intro. No music was made for cinematics (GDD §11). Should the outro have its own sting?
380. **The crash plays twice** (the owner's first beat; GDD §10's defeat). The fight's defeat already plays the
    dying lurch, the plunge and the crash (`FloatingHead`). After the results and the shop, the outro opens on the
    same crash again from the run camera, as the beats ask. Placeholder: as described (`fall_start`,
    `fall_seconds`). Keep it, or open the outro on the wreck already down and smoking?
381. **The side street's marked edges.** The left opening is built as a level's wall gap, so the zone's wall-gap
    look marks it as a level marks a drop: an orange lip along the main street's edge across the side street's
    mouth (although its floor carries on), and orange edge columns framing the roadblock. That goes against "safe
    things look safe". The right opening is a real drop, so its marks are right. Placeholder: both marked
    (`CineStageDef.wall_gaps`). Give the toolkit a way to open a wall without the drop's marks, for openings
    onto floor?

**Room for the Enforcer Truck to show itself in every chase** (from C6c; the showing windows in `scripts/enemies/enforcer_truck_rules.gd` (`ShowPlanner`), group "Showing itself" in `data/enemies/enforcer_truck.tres`; count showings per chase with `tools/measure/enforcer_shows.gd`)
386. **Making the window's showing happen** (GDD §9, big attacks take turns). The truck claims its turn among the big
    attacks `show_claim_seconds` (2 s) before its window is due, so a drone's barrage or a Resonator's pulse that gets
    ready meanwhile waits for the showing (up to the director's `turn_wait_max`), and its own volleys hold so none is
    on as the window comes. The window also holds if the showing begins up to `show_window_slack_seconds` (1 s) late.
    A host's Bad Dream chase doesn't keep a window off: it only comes if the player kills the host, and the showing
    then waits for it. Placeholder: those two values (`DESIGN-TBD` in `data/enemies/enforcer_truck.tres`). OK?

**Gangland's boss intro** (from F2b; the owner's beat, GDD §10 Sewer Swarm "Intro cinematic"; numbers in `data/cinematics/sewer_swarm_intro.tres`, code in `scripts/cinematics/sewer_swarm_intro/`; review with `tools/showcase/cinematic_review.tscn -- --slot=gangland/boss_intro`, or play `--level=gangland/boss_intro`)
387. **How the runner dodges** ("easily avoids it", "dodges those", "runs past them"). Placeholder: the first
    screech pounces into the runner's lane and lands under them as they jump over it. Of the next three, the lone
    one leaps over the runner's lane as they slide under it, and the other two land in the lane ahead and swipe as
    the runner weaves round them (1.4 m to the right). The eleven land either side of the runner's lane and rear up
    and swipe as the runner runs straight between them. Each then gives chase and falls behind (`jump_at`,
    `slide_at`, `weave_at`, `third_land`, `chase_share`). In play a screech comes out only when the player is in its
    lane and dashes straight along it (GDD §9.5); here the first beats' screeches leap sideways out of the next lane
    into or across the runner's. Is that all right for a cinematic?
388. **How the wall behind the runner is shown** ("soon we see that there is a wall or wave of screeches behind the
    character"). Placeholder: the camera stays at ground level (0.47–0.75 m up). It rides low behind the runner
    until 5 s, then swings round their right side (5.0–6.4 s) to low in front of them, looking back past them at
    the wall. Should it look back over the runner's shoulder instead (the runner out of view)?
389. **Where the manholes are** ("manhole covers on either side of him"). Placeholder: rows one lane over on both
    sides of the runner, one every 6.5 m a side, the sides staggered. The runner runs in the start lane, the fight's,
    which on 6 lanes is half a lane right of the street's middle.
390. **What the wall looks like.** Placeholder: one wave across the street (6 m tall, its crest curling 8.5 m
    forward over the runner, as the fight's strike from behind does), with the rest of the swarm behind it, 26 m long. It
    rises from 6.3 s, 32 m behind the runner, and closes to 9 m by the cut. As it closes it heats toward
    enemy-attack red (0.25 to 0.5 on the fight's scale), the fight's colour for an attack. Should a cinematic use
    that warning colour at all?
391. **The cut** ("a dark area, and inside that dark area, we can just make out a glint of the host"). Placeholder:
    at 9.6 s, one cut to low between the runner and the wall, looking up into a dark hollow in the middle of the
    mass (1.9 × 2.3 m), with screeches heaped and crawling round its rim. The Host is held up inside it, its look
    darkened to a faint silhouette with a sickly edge. The implant at its temple glints red once, 0.9 s into the
    cut (with Reduced flashing, a slow, faint glow). Is the glint right, or should it be the Host's eyes, or the
    implants on its back (the fight's weak points)?
392. **How it ends.** Placeholder: 2.4 s after the cut it fades to black (12 s in all), and the fight starts on its
    own view, whose Rising carries on from here. There is no card naming the boss, since the beat has none and GDD
    §1 asks for little or no words; the City's boss intro shows one ("ZONE 1 · BOSS / FLOATING HEAD"). Should
    Gangland's show one too, over the cut or the black?
393. **How many screeches.** Placeholder: 15 in the beats; 2 to 6 out of each manhole in the pour (half as many
    on a low-end device); 110 dropping from the sky (45); 900 in the wave and 560 behind it (360 and 220); 110 heaped
    round the hollow in the cut (50). The phone test (risk test R4, task E3) should check these with the fight's.
394. **Its speed.** Placeholder: the runner runs at Gangland's run speed (21.8 m/s), the fight's, so the fight
    follows at the same pace.

**Every chase shows its truck** (from C6d; `_choose` and `ShowPlanner` in `scripts/enemies/enforcer_truck_rules.gd`; count chases and showings with `tools/measure/enforcer_shows.gd`)
402. **One truck that shows itself, or two that don't** (other seeds). Where giving a truck to a chase with room leaves
    the level's other truck no chase (they'd overlap), the level keeps the one that shows itself before its bait: 2 of
    144 builds on 8 other seeds lose a truck so (Corporate 2 at 6 lanes, Golden 1 at 5), and 1 gains one back that C6c's
    order dropped (Golden 2 at 5). Placeholder: the most windows before the bait count before the number of trucks
    (`_choose`), as C6c counted windows before trucks. Right?
403. **An introduction that moves late** (other seeds). Where Corporate 2's first bait has no room, its introduction
    moves to the first chase where it shows itself before its bait: in 3 of its 24 builds on 8 other seeds, from 8 s to
    71 s or 82 s into the level (and from 70 s to 90 s), past the reach the campaign asks of an introduction (about 19 s
    into the level: 12 s past its start). Its first-encounter hint and the charge-path cyborg before it hold (the hint
    is on the level intro, the cyborg earlier in the campaign). Placeholder: it moves (it never moves on the level's own seeds). Or keep the introduction
    early, unseen, when the room is that far?

**Level skies, the owner's follow-up** (from G8, October 8–9, 2026; `scripts/cinematics/cine_stage.gd` `sky_for`, `scripts/world/skins/level_sky.gd`, `data/skies/*.tres`)
404. **The boss's intro under the fight's sky** (GDD §5, "Skies show progression"; §10). The owner asked that the fight
    after a level whose sky turned keeps that sky; the Sewer Swarm's intro, which plays between Gangland 3 and the
    fight, landed on main just after. Placeholder: the intro plays under the fight's sky too (Gangland 3's blood
    red, `CineStage.sky_for`), so the sky holds from the level through the intro to the fight. Keep it?
405. **The cinematics around City 1's dawn and the turned-sky fights** (GDD §5). The City's intro (the arrival
    flyover, looking up at the skyline) plays right before City 1 under the zone's own night sky, so the game's
    first cinematic is at night and its first level at dawn. And the outros after the Sewer Swarm and The House
    (placeholder cards for now) will be under their zone's own sky. Placeholder: a zone's intro and outro keep the
    zone's own sky (`CineStage.sky_for` gives only a boss's intro a level sky). Should the City's intro show the
    dawn, and should an outro keep the fight's sky?
406. **Bosses under the street's light** (GDD §5). The street's light under a level sky (`scenery_tint`) reaches what
    is drawn with the street's own shaders, and two fights are built partly that way: The House's cabinet dims to
    about 70% and turns lavender under Marketplace 2's sunset, and the Swarm Host's body and pipe take Gangland 3's
    red. Their glowing parts (weak points, reels, 7 buttons, warnings) keep their light, and a level's darkness
    already reaches these bodies the same way. Placeholder: they are lit like the street. Or should a boss's body
    keep its own light (a per-material opt-out in `kit_solid`)?

**Making room where there is none** (from C6e; the window modes in `ShowPlanner`, `scripts/enemies/enforcer_truck_rules.gd`; `calm_start_min_seconds` and `calm_start_takes_out` in `data/enemies/enforcer_truck.tres`; count with `tools/measure/enforcer_shows.gd`)
407. **How early in the calm start** (GDD §9.13 "Making room where there is none": "late enough that the player is
    under way (a minimum in data)"). Placeholder: `EnforcerTruckTuning.calm_start_min_seconds` 0.5 s into the run
    (`data/enemies/enforcer_truck.tres`, `DESIGN-TBD`). The truck arrives there at its follow gap, right behind the
    runner, and pulls alongside as it arrives: from its usual arrival gap (45 m) it couldn't come alongside before the
    bait (Golden 1's first Buzz Overdrive revs 4 s after the 60 m run-up). Is 0.5 s right, and is arriving close in
    fine?
408. **"Nothing taken out" in the calm start.** A showing there runs on past the run-up (2.4 s at the Golden Zone's
    speed) into the level's first patterns. Placeholder: it takes nothing out anywhere, as the task asked
    (`calm_start_takes_out` off, `DESIGN-TBD`), so it fits only where those patterns leave a lane: on the own seeds
    Golden 1 at 3 lanes gets it, Golden 1 and 2 at 6 lanes and Golden 3 at 5 don't. Switched on, it may take out plain
    holes, fences and cyborgs past the run-up as any other window may, and those three get a showing before their bait
    (taking out 2, 8 and 2 pieces of their first patterns). Switch it on?
409. **A Buzz Overdrive's claim during a showing, beyond the calm start.** Placeholder: anywhere in a level (not only
    the calm start), a window may overlap the claim on its turn a Buzz Overdrive makes before its rev, the tank staying
    where it is, the showing out of view `show_margin_seconds` before the rev (`ShowPlanner` CLAIM mode). It only
    comes where no window fits before the bait otherwise. An Octodog's turn is unchanged. Keep it level-wide?
410. **The hover truck's cannon and forward lurch wait.** Placeholder: only its entrance (banging and bursting out)
    can't wait for a turn; its cannon shots and forward lurch take turns and wait for a showing, as other big attacks
    do. Should they count as attacks that can't wait too (the showing fitting between them instead)?
411. **A runner lane no showing can reach.** Placeholder: a window may leave out one runner lane no showing could reach
    (beside a hover truck at 3 lanes, or with only a floor cut's lane beside it); a runner keeping to that lane doesn't
    see that showing. Two such lanes leave the window out. Is one lane without the showing acceptable?

**The Golden Convergence: the design choices made under the owner's mandate** (from E5d's design session with the owner, October 9, 2026; every choice is marked *(proposed)* in GDD §10, The Golden Convergence; numbers in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight) and `data/bosses/golden_boss_skin.tres`; play `--level=golden/boss`, review with `tools/showcase/golden_convergence_showcase.tscn` and `golden_convergence_magnate_showcase.tscn`)
416. **The arena: the Grand Court** (GDD §10, The arena). A golden causeway through the palace's vast
    central hall, balustrades at the edges, reflecting pools below, towers to either side with giant feed
    screens. A plain track: no holes, fences, ceilings, doodads or enemies of its own. Is this the place
    you pictured for the fight?
417. **Stage 2 keeps the open causeway** (no side walls). The reason: with permanent walls, the wall hop
    (GDD §3) would let a runner wait out every attack on a wall. The Magnate's "walls and ceilings" are the
    balustrades, the towers' faces and the high arches, out of the runner's reach. Do you agree, or should
    stage 2 move into walled galleries (and then The Magnate needs an attack that reaches wall runners)?
428. **The defeat:** his cables tear out, the screens go dark one after another, the music cuts out with
    them, he collapses in silence, then the victory riff. Should the riff play at all, or should the
    fight end in silence like the Sleep Taker's and leave the music to the ending cinematic?
430. **Music:** the Golden Zone's track for now. Would you like a final boss theme of its own?

**The Golden Convergence: the golden suit, the Grand Court, the Helidrone Strafe and the Flying Buttress** (from E5d-a; built in task E5d-a (the golden suit, the Grand Court, the entrance, the Helidrone Strafe and the Flying Buttress). Every number below is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight) or `data/bosses/golden_boss_skin.tres` (`GoldenCourtSkin`) unless it says otherwise, marked `DESIGN-TBD` in code)
431. **How far ahead the suit floats, and which weapons reach it** (GDD §10: "it floats in the distance ahead
    of the runner"; "weapons chip at it slowly"). The suit's chest is 64 m ahead (`suit_ahead`), 12 m over the
    causeway (`suit_height`): far enough to read whole on a phone's screen, halo to hands, and inside the 70 m
    reach of weapon tiers 2-4, but **out of the tier-1 weapon's 42 m** (`PowerupTuning.weapon_range`), so the
    starting weapon never chips it. Should every tier reach it (bring it to 40 m, or give weapons a longer
    reach in this fight), or is it fine that only bought upgrades chip the suit?
432. **The suit's look** (GDD §10, Look): heavy half-closed eyes looking down the causeway and a faint smile
    (a calm face cast in gold, `GoldenConvergenceModel.face_relief`/`face_marks`); the dull red tear runs from
    under its left eye (the runner's right) down its cheek to a drop; a three-pointed diadem (the Triad's
    arrows) and two halo rings with rays turning slowly behind the head; filigree waves along the pauldrons'
    rims; four missile pipes in a row on each pauldron, angled up and back under a hinged hatch; eight
    tentacle pipes, the middle ones trailing back over the causeway, the outer ones splaying out past its
    edges and down toward the pools; the cape a cloud fanned out behind it from the shoulders, up over the
    halo and down past its sides, deep pleats with black troughs (`golden_convergence_cape.gdshader`,
    `cloth_color` 0.31/0.03/0.075 sRGB, darker burgundy with more black in its folds after the orchestrator's review, never glowing; the suit's gold a little richer than the palace's, 0.85/0.67/0.42, inside the suite's chroma limit). Is this the suit you pictured?
438. **The Flying Buttress** (GDD §10: "taller than other doodads ... it comes into view well before its line"):
    it rises out of the causeway 6 s before the runner reaches it (`buttress_sight`) over 1.4 s, with a deep
    grinding rumble; its pier 3.2 m deep and 16 m tall, its arched opening 4.4 m tall and about 1.4 m wide in
    the lane's middle; its flying arch leaps 70 m out and 38 m up toward its tower, leaning toward the
    nearer edge (by the fight's seed in the middle lane); the Triad in gold on its face. Its sides bump a
    lane switch into its lane from just before its front (`blocker_lead`). **A switch out of the arch while
    inside it isn't blocked** (the runner slips through the leg): should it be (a lane blocker on both sides
    of the pier, the runner bumped back into the arch)?
439. **The walls:** where nothing opens a wall, both walls are taken away (`BossProps.block_wall`) from just
    behind the runner to 240 m ahead (`wall_block_ahead`), so a move past an outer lane bumps them back with
    the clank, as the GDD says. An open wall (E5d-b's toppled tower) is fired on low (an outer lane's rake
    climbs it to 1.5 m, `wall_fire_height`: a wall runner above it is safe, so a wall run is safe for about
    its first second, from its 2.2 m entry, and hit low in the rest of its slide; the rake's box in the lane
    keeps clear of a wall runner's body) and at every height by the live line (7 m, `wall_line_height`).
    Is "low" about right?

**The Golden Convergence: the Fist Slam, the toppled tower and the Missile Barrage** (from E5d-b; built in task E5d-b (the Fist Slam with its Flying Buttress bait and the toppled tower's wall, and the Missile Barrage). Every number below is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, groups "Fist Slam", "The toppled tower" and "Missile Barrage", F6 in the fight) unless it says otherwise, marked `DESIGN-TBD` in code)
444. **Phase 1's third slam is both ahead and a chance.** The GDD's two proposals overlap: "in phase 1, slams 1
    and 2 come down on the runner and slam 3 ahead" and "the chances are slams that come down on the runner:
    slams 2 and 3 in phase 1". Built as both (`slam_scripts` "Ooa": a lower-case letter is a chance), so phase
    1's last chance is an ahead slam: its fist locks on the runner's lane and lands ahead, and a runner in the
    gate's lane as it locks smashes the gate. Later phases ("OAooA") have no such overlap. Should phase 1's
    third slam come down on the runner instead, or stay ahead?
445. **Where a chance's hole is dug.** "A fist locked onto another lane digs its hole beside the buttress,
    never through it": a chance's row ends 0.6 m before the gate's pier (`slam_gate_gap`), so its hole lies
    in front of the gate, never through it, whichever lanes the footprint takes. On 3 lanes the middle lane is
    the only inner lane and every two-lane footprint takes it, so the hole always opens in the gate's lane, in
    front of it (the gate still stands). Is "in front of it" what you meant by "beside it"?
449. **The arm's reach.** The suit floats 64 m ahead, so a fist over the runner's lane is 45-70 m from its
    shoulder: past a full telescope, each golden sleeve also stretches, up to 2.4 times its length
    (`GoldenConvergenceSuit.EXTEND_MAX`). Is a stretched arm fine, or should the suit lean in or come closer
    for its slams?
450. **The first slam can stalk.** A slam's hole is a floor cut, and floor cuts must lie past the track built
    ahead (about 200 m), so each sequence is planned while the beat before it plays (from where that beat
    will be over): after a strafe or a barrage, the first impact comes about 2.4 s after the beat begins. A
    phase that opens with slams (phases 2 and 3) can only plan them during its short intro, so its first fist
    comes out at once and follows the runner's lane until its warning: its first impact comes about 4.5 s
    after the beat begins at 25 m/s (7.7 s at quick play's 18 m/s). Fine, or should those phases open with a
    longer intro or another attack?
452. **The toppled tower** (GDD §10: "the building it held up, off screen, topples forward along the track"):
    it appears standing beside the causeway out of view, its foot at least 9 m behind the runner
    (`tower_behind`; farther back so its crown ends at its wall's end), and falls forward over 1.5 s
    (`tower_fall_seconds`), so the run camera sees only its last moment as it comes down beside the runner
    (with a rumble, dust and a shake; no flash). It is long enough for its wall: about 230 m at 18 m/s, 300 m
    at 25 m/s. It lies with its side flush with the wall's line, 14 m wide, its top about 9 m above the
    causeway (`tower_width`, `tower_depth`): white marble, gold bands, lit windows on its top and outer side,
    a gold crown and spire. Its side is the wall from the gate's front for 10 s of running
    (`tower_wall_seconds`); once the runner is past it, it sinks into the pools behind them over 2.5 s.
    Should more of the fall be seen (for example the tower already standing marked at the roadside ahead, as
    the Floating Head's are)?
456. **One armor hit plus the dash is a tight fit** at 1.5 s of fire (1.6 s of protection, as the GDD gives
    it): two armor hits and armor plus the shield carry the runner through on their own, but with the armor
    and the dash the dash has to start within about 0.1 s of the fire landing (so the armor's second follows
    it) or within the last 0.1 s of the armor's second. A runner who dashes at any other moment burns. Is that
    the "a bit toasty" you meant, or should the fire be a little shorter (1.3-1.4 s gives a 0.2-0.3 s window)?

**The Golden Convergence: The Magnate (stage 2) and the defeat** (from E5d-d; built in task E5d-d (stage 2, The Magnate, and the defeat, "the feed dies"). Every number is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`'s "The Magnate" groups, F6 in the fight) unless it says otherwise, marked `DESIGN-TBD` in code. Review it with `./play.sh --boss=golden_boss --phase=4` and the showcase (`res://tools/showcase/golden_convergence_magnate_showcase.tscn`, its header lists the scenarios))
458. **The warm white in his cracks** (optional in the GDD): on, at `crack_glow` 0.55, leaking only from some
    cracks in patches; it flares as he claws out of the suit and dies with him. Its colour is the feed's warm
    white (1.0/0.93/0.82), clearly whiter than the runner's copper glow (0.96/0.64/0.46). Keep it, or dark
    cracks (0)?
459. **The chase** (proposed: "his shadow and a marker at the screen's bottom edge show his lane"): he keeps
    10.5 m behind the runner (`chase_gap`, behind the camera) and takes up their lane 0.6 s after they change it
    (`chase_lane_delay`). His shadow is a soft dark blob in his lane from 2.5 m ahead of the runner to 4.5 m
    behind them (`GoldenConvergenceChase.SHADOW_*`; the run camera's view ends just behind the runner's feet, so
    the shadow has to reach past them to show). The marker is a chevron with two claw marks at the bottom edge
    under his lane, in the feed's warm white while he follows and the enemy attacks' red at a Pounce's warning.
    His breathing and growls play from where he is. Is the shadow readable without looking like a hole (the
    Grand Court has none)?
460. **The overtake** (GDD: "he overtakes along a wall or ceiling, lands ahead, then drops back"): with no walls
    or ceilings over the causeway, he runs past the runner along the nearer balustrade to 15 m ahead
    (`overtake_ahead`), leaps across the causeway 6.5 m over every lane (`overtake_height`) onto the other
    balustrade ahead, and drops back along it (4.4 s, `overtake_seconds`, divided by the pace). He lands on the
    balustrade, never on the track, so an overtake can't be mistaken for a Pounce; it growls rather than roars
    (the roar is the Pounce's warning). It opens phase 4 and each of its loops. Should he land on the track
    ahead instead (harmless)?
461. **The Pounce** (proposed): the roar and the red marker 0.75 s before he leaps (`pounce_windup`, divided by
    the pace); the leap 1.7 s (`pounce_flight`), 5.5 m over the runner (`pounce_apex`); he locks onto the
    runner's lane 1.05 s before he lands (`lock_seconds`, never divided by the pace) and the red square (with an
    X) shows there, 3.6 m deep (`crash_depth`); he lands 0.15 s (`land_lead`) before the runner would reach it.
    The crash is an enemy attack over 84% of the lane's width, up to 3.2 m (above a jump: a jump doesn't clear
    him), live until the runner is past the square (0.3-1.2 s); then he bounds off onto the balustrade away
    from the runner (no arches over the causeway to bound onto) and drops back. Armor and the shield block the
    crash; the dash passes through it.
462. **The bait** (proposed: "a Flying Buttress comes up ahead for every second Pounce"): each phase's script has
    a plain Pounce, then a Pounce with the bait (`pounce:bait`). Its buttress rises in an inner lane (by the
    fight's seed) 6.5 s before the runner reaches it (`bait_sight`). A runner in its lane as he locks on makes
    him aim at the gate: he crashes into it 1.6 s before they reach his back (`stun_lead`, never divided by the
    pace) and slumps across its lane and the next one away from its lean (toward the middle; on 3 lanes the
    gate is the middle lane and he slumps toward the side away from the lean), his back to the runner. His
    weak points are a stomp box over his back in each of his lanes, reaching 3.5 m toward the runner (at
    18 m/s, longer at the Golden Zone's pace: `stun_reach`) and 0.4 m over his back (`stun_stomp_top`); his
    sides block a switch into him (a bump, never a hit). A runner who comes down on the floor 0.25 s (at the
    run speed, `stun_release`) short of his back, or runs past him, makes him shake free and leap away before
    reaching him; the bait comes round again with the phase's loop (no escalation). Is 0.25 s fair, or should a
    miss also cost something?
463. **The Cable Lash** (proposed): he runs up along a balustrade (sides in turn) for 2.3 s (`lash_run_up`,
    divided by the pace), then rears back on it for the warning, 1.25 s (`lash_warning`, never divided by the
    pace): his cables rise crackling red, a red line lies across every lane where it will sweep, and thin red
    aim lines cross the track at its heights. The whip crosses every lane in 0.25 s and lies across them 0.3 s
    before the runner gets there. A low lash is one cable at 0.35 m (jump it); **a high lash is two cables, at
    0.85 m and 1.9 m** (slide under both), the shape of a gapped fence and of the Floating Head's twin beams, so
    that a jump can't clear it too. Should the high lash be a single cable (then a jump would clear it as well
    as a slide)?
465. **The transition** (proposed): phase 4's intro is 5 s (`data/bosses/golden_boss.tres`): the suit's chest
    bursts open over 0.5 s and its plates fly off from 0.35 s; he claws out of the man's room from 0.55 s and
    roars at 1.75 s (the screens switch to his roaring face, with a glitch); the empty suit topples off the
    causeway's side (by the fight's seed) from 2.3 s over 2.2 s and splashes into the pools far below; he leaps
    off the suit at 2.75 s, high over the runner, landing behind them 1.5 s later. It plays the same on a retry
    from the checkpoint. Phases 5 and 6's intros (2.5 s) are his hurl clear after a stomp, howling.
466. **The defeat** (proposed): he lurches 1.5 s (at the run speed) ahead of the runner into the lane furthest
    from them over 1.2 s, convulsing; his six cables tear out every 0.3 s from 0.6 s; from 0.9 s the screens
    glitch and go dark outward from him at 90 m/s (`blackout_speed`; beyond 700 m every screen in the world)
    and the music cuts out over 0.25 s; he collapses once his last cable is out, the light in his cracks dying
    over 1.4 s; once the runner is past him, the victory riff 0.35 s later. Question 13 above (the riff or
    silence) is the switch `victory_riff_on` (on).
467. **His sounds** (`tools/asset_gen/sfx_bank_magnate.gd`): his roar is both a Pounce's warning and the
    transition's screech; a howl when he hurls himself clear; a convulsive death roar; a heavy collapse in the
    silence. Is his voice the creature you pictured?
468. **Weapons in stage 2:** he can't be targeted until he's out of the suit; then weapons chip him like any
    boss part, within the fight's weapon cap (`weapon_share_cap`, one sixth over the whole fight). As in
    stage 1, `weapons_can_end_phase` is on, so a runner with enough weapon damage left could end one of his
    phases without a stomp. Should stage 2 only end on stomps?

**The Golden Convergence: the Refill Ship and stage 1's phases** (from E5d-c; built in task E5d-c (the Refill Ship, its closed cage and the chain reaction: the only way to damage the golden suit; stage 1 played through, and the whole fight in the campaign). Every number below is in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`'s "Refill Ship" groups, F6 in the fight) unless it says otherwise, marked `DESIGN-TBD` in code. Review it with `./play.sh --boss=golden_boss` (or `--level=golden/boss`) and the showcase (`res://tools/showcase/golden_convergence_showcase.tscn`: `--scenario=refill`, `cage`, `chain`, `missed`, `stage1`, `whole`; its header lists the options))
469. **The ship's look** (GDD §10, proposed: "a gilded cult cargo ship"): a 34 m gilded cargo hull over a flat
    plated belly as wide as the causeway (every lane, wall to wall), the ceilings' orange band at both ends of the
    belly; two rows of bronze missiles in open racks along each flank (never glowing: the barrage's look); a
    pointed prow, the bridge at the stern with dark windows, pale blue engines (the Golden Zone's yachts'); a gold
    feed boom amidships whose gilded hose (bronze bands) runs up across the sky to the shoulder pipes, missiles
    riding up it. Is it the ship you pictured? (`golden_convergence_ship_model.gd`.)
471. **The ship's flight** (proposed: "pacing the runner while it refills"): it flies in from 46 m behind and 30 m
    above the runner over 2.4 s (`ship_in_seconds`) to its station beside the causeway on the fed side, 22 m out
    from the middle, 36 m ahead and 11 m up (`ship_side`, `ship_station_ahead`, `ship_station_height`: framing,
    beyond the balustrade so the strafe has the track); the feed line shoots out to the shoulder 0.5 s after it
    arrives (`feed_reach_seconds`), the hatch over the pipes opens, and a missile rides up the line every 0.45 s
    at 30 m/s (`feed_every`, `feed_speed`). As the cage comes up it comes over the causeway and down to the
    ceiling's height over 2 s, settled 1 s before the runner reaches the front fence (`descend_seconds`,
    `settle_before`), the runner 4 m behind its middle.
472. **When the cage comes up, and the hold** (GDD §10: "the squadron holds its fire while the cage comes up and
    the runner goes for it"): once the beat's strafe has flown one pass (`cage_after` 1: in phase 1's V-V-H, after
    the first vertical pass; one pass is always left for after the pad), 4.5 s ahead of the runner (`cage_lead`:
    time to read it, reach the generator's lane from the farthest lane and stomp it). The squadron holds from
    then until the runner is past the pad, hovering in formation beside the ship under its racks; on a miss it
    fires its passes left, planned on from where the runner is. Is 4.5 s the right lead?
473. **The cage's numbers** (GDD §10: "the front fence placed so a jump over it lands past the pad"; proposed:
    "the cage's sides are fences running along the pad lane's edges"): the front fence is a full fence across the
    pad's lane; the pad is 1.4 m deep (`cage_pad_length`, shorter than a level's), right behind it, so even the
    latest takeoff that clears the front fence comes down past it at 18 m/s (the tests sweep every takeoff at 18
    and 25 m/s); the sides are 2.4 m tall (`cage_side_height`, above a jump: a lane switch into the cage touches
    one in the air too) and run 1.5 m (at 18 m/s) past the pad (`cage_side_past`). The pad is in an inner lane (by
    the fight's seed), so there's a lane on both sides. Its fences flicker in for 1 s with the fence warning
    (`cage_flicker`) before they switch on, so the cage always comes up in sight. Is a 1.4 m pad easy enough to
    hit on a phone?
474. **The generator** (GDD §10: "in a lane next to the cage, just before it, with room after its pulse to switch
    into the pad's lane"): the game's fence generator, in the lane beside the pad's (left or right by the seed),
    16 m (at 18 m/s) before the front fence (`generator_before`: a stomp's bounce comes down before the cage), a
    pink conduit along the lane seam to the cage. Its own pulse switches the whole cage off whatever the EMP's
    radius; any other EMP switches off only the fences it reaches (GDD §9.1's distance rule). Should its pulse
    only reach as far as any EMP (the far side fence might then stay on)?
475. **Weapons never target the ship, the generator or the fences** (proposed): the ship is immune and never a
    target; the generator is immune like every generator (weapons never set one off: GDD §9.1); the fences are
    hazards. Weapons still chip the suit. Should a weapon be able to set off the generator (a third way in)?

**The Golden Convergence: the polish pass** (from the review of E5d-a, b and d; built in the polish pass after the fight's review. Numbers are in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight) or constants marked `DESIGN-TBD` in code, as each item says)
484. **The howl after a stomp** (GDD §10, Three stomps, proposed: "After a stomp he hurls himself clear,
    roaring"). He hurls himself clear with a howl (`magnate_howl`, the same he gives when he shakes free of a
    missed bait), not his roar, so the roar stays the Pounce's warning and nothing else ("His roar is the audio
    warning"). Do you agree?
485. **Two Fist Slam rows never meet.** Consecutive rows (a chance's gate included) are always at least a lane
    switch's run plus 0.3 s apart at the run speed (`slam_row_margin`, `GoldenConvergenceSlams.row_gap`), so a
    runner landing past a hole has room to switch out of the next one's footprint. Where the script's spacing
    brings them closer (phase 3's pace at 18 m/s on 5 and 6 lanes overlapped two rows by about 0.6 m), the later
    slams come that much later. The bot's clean fight now takes 198.3 s at 3 lanes and 200.1 s at 5 and 6 lanes at
    25 m/s (it was 198.2 s), and 208.9-209.1 s at 18 m/s (208.7 s); the par times stay 214, 277 and 340 s. Is
    0.3 s the right room?
486. **The fist never reaches a wall runner** *(proposed)*. Its touch keeps clear of a wall runner's body at every
    height, as the barrage's fire does (`GoldenConvergenceSlams.touch_x`): a runner on the wall beside a slam in
    the outer lane is untouched, one on the floor in its footprint is hit. The wall is safe from the fist, as it is
    from the fire. Do you agree?
487. **The Refill Ship's end** (GDD §10: "the ship goes spinning off to the side and explodes, and the missiles it
    carries all explode"). It spins off to its side and only 1.5 m down (`GoldenConvergenceRefill.SPIN_DOWN`; it
    sank 10 m and exploded below the deck, out of sight), and its blast goes off around its middle at least 4 m
    above the causeway (`GoldenConvergenceShip.BLAST_LIFT`): a string of fireballs up to 7 m in radius along its
    length over half a second (`BLAST_RADIUS`), every rack's missiles having gone up in the same fire.
    The fire is a saturated orange with a hot yellow heart that reddens and darkens through soot, with dark smoke
    rolling up out of it and lingering (`GoldenConvergenceBlast`, `golden_convergence_blast.gdshader`: laid over
    what's behind it, where the old additive light read a washed-out peach over the court). With Reduced flashing
    its heart never flashes white-hot and no sparks fly; the shake follows the screen-shake setting. Is it the
    explosion you pictured?
489. **F6 can no longer put a move out of reach** (margins marked `DESIGN-TBD` in code; every default plays as
    before):
    - `stun_stomp_top` now ends at 0.6 m (it went to 1 m, and from 0.85 m no jump could stomp him), and his weak
    points' top always stays 0.25 m (`GoldenConvergencePounce.STOMP_WINDOW`) under what a jump can stomp, whatever
    the movement tuning;
    - he never shakes free of a stun while a jump from where the runner is could still land on his back (with
    `stun_release` at its longest and `stun_reach` at its shortest he left before any jump could reach him; at the
    defaults this moves the release 2 cm at 18 m/s);
    - a high Lash's lower cable stays 0.05 m over a sliding runner (`GoldenConvergenceLash.SLIDE_CLEAR`; at the
    lowest `lash_high` and the thickest `lash_radius` it lay on the slide);
    - the barrage's missiles hang longer where its other steps (or a longer reaction and margin) would leave less
    than the way onto the wall from the far side on 6 lanes, so its warning stays the same at every lane count;
    - the toppled tower's wall lasts through the barrage after it, its fire and 1.5 s more
    (`GoldenConvergenceTower.WALL_SPARE`);
    - the cage comes up far enough ahead to read it (0.7 s, `GoldenConvergenceCage.READ_SECONDS`), switch in from
    the farthest lane, jump onto the generator and 0.3 s to spare (`SPARE_SECONDS`): the shortest `cage_lead` with
    the farthest generator left it 0.28 s ahead of the runner.
    Are these margins right?

**The Golden Convergence: the owner's playtest of stage 2 (the Claw Slash, the Screen Storm, darker)** (from E5d-e; the owner's request and approvals of October 9, 2026 are in GDD §10, Second stage, Owner's playtest; built in task E5d-e, the owner's playtest of stage 2 (GDD §10, "Owner's playtest (October 9, 2026)": the Claw Slash, the Screen Storm, the arena darker, the new beat scripts, the stomp's chevrons). The owner approved the playtest's specifics; these are the choices made while building them. Numbers are in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight: "The Magnate: the darkness", "the Claw Slash", "the Screen Storm") unless the item says otherwise, marked `DESIGN-TBD` in code)
491. **Where he runs during a storm** (approved: "During a storm he runs close behind the runner where the camera
    shows him"). He runs up onto a balustrade (the sides in turn, the first by the fight's seed) and paces the
    runner **3 m in front of them** (`storm_ahead`), not behind. The run camera's view ends about 3.5 m behind the
    runner, so behind them he would show at most as a head at the screen's bottom edge, and the screens crashing on
    him would land out of sight. Up on the balustrade ahead the camera shows him whole at every lane count, the
    screens coming down on his back read clearly (he staggers with a cry of pain), and they never come down in a
    lane. A screen on him has no red square or shadow, since nothing there can touch the runner. The overtake beat
    (he shows himself along a wall, lands ahead and drops back) is in none of the approved scripts, so the storms
    are where he shows himself now; the beat still plays if a script names it (`overtake`). Is this where you want
    him during a storm? (`GoldenConvergenceScreens`)
492. **How many screens hit him: three a storm at every lane count** (`storm_hits`), so a storm takes a quarter of
    a phase everywhere ("each takes about a twelfth of the phase's health (a storm about a quarter)"). That is a
    third of a 10-screen storm on 3 lanes but only a fifth of a 16-screen storm on 6 lanes; a third of 16 would be
    five hits, about 40% of a phase. Keep a quarter of a phase a storm, or a third of the screens?
493. **The storm's size and pressure.** 10 screens on 3 lanes, 12 on 4, 14 on 5, 16 on 6 (`storm_screens_min`,
    `storm_screens_max`, scaled to the lane count). The screens on the track take turns: one meant for the runner
    (in their lane, once the fairness rule allows a screen there; it waits up to 0.4 s for that, then comes down
    beside them) and one beside them (two lanes off rather than one, so it doesn't block the next one meant for
    them). The model runner of the plan's test, who moves 0.35 s after each warning (The House's reaction:
    `screen_reaction`; a lane switch with a 1.5 margin, `screen_switch_margin`; 0.1 s spare round each crash,
    `screen_margin`), has to dodge 3.3 to 5.2 times a storm on average (200 storms at each of 3 to 6 lanes) and is
    never struck or sent into another warning. The storm's 5 s and its 0.9 s warnings don't speed up with the phase's
    pace (his run-up to the balustrade does). Is a storm busy enough? (`GoldenConvergenceStormPlan`)
494. **A stomp ends its phase exactly.** In stage 2 a stomp takes whatever is left of its phase, so what the screens
    (and weapons) chipped off doesn't carry over into the next phase: every phase is one stomp or four storms,
    whatever came before (`GoldenConvergence.hit_damage`). The last sliver of a phase (under a hundredth of it) goes
    with a screen's hit, so twelve twelfths always end it. A phase the screens end is followed by his hurl clear, as
    after a stomp, and in the last phase they end the fight with the same defeat as the third stomp. Should chip
    damage carry over instead, so a phase with many storms shortens the next one?
495. **The Claw Slash's timings and reach.** He closes in from behind over 0.6 s (`slash_close_seconds`, over the
    pace) to just behind the camera's view; then the warning (0.5 s, `slash_warning`, never shortened by the pace)
    while he lunges into view to 3 m behind the runner as the swipe lands (`slash_strike_behind`). The swipe covers
    84% of the lane's width (`slash_width_share`), from 1.2 m behind the runner to 0.8 m past them (`slash_behind`,
    `slash_ahead`) and 3.2 m high, live for 0.12 s; a double's second warning begins 0.12 s after the first swipe
    lands (`slash_double_gap`). The warning only begins while a lane beside the runner's is clear to switch into
    for the whole swipe (no buttress side, hole, other floor warning or live Lash cable there); otherwise he holds
    behind the camera for up to 2 s, then lets that slash go (`GoldenConvergenceSlash.WAIT_MAX`). Is the split
    second right?
496. **How the Slash's warning flashes.** His marker's red beats on and off 7 times a second (down to 30%
    opacity; `GoldenConvergenceChase.ALARM_FLASH_HZ`) and the claw marks pulse their size about 5 times a second;
    both hold steady with Reduced flashing. The marker is small, at the screen's bottom edge; is this rate fine?
497. **How dark stage 2 is.** The court's light falls to 0.4 (`stage_two_light`; the orchestrator lowered it from 0.7 after
    measuring frames, so it reads as the owner's "about 30% darker": the floor's value goes from about 208 to about 149 on
    Forward+ and from 201 to 144 on Compatibility, 29% darker on both) over 3.5 s from the transition's
    start (`dim_seconds`; on a retry from the checkpoint too) and comes back over 2 s from the defeat's start
    (`light_return_seconds`). The Magnate's body and cables dim with the court; the warm white in his cracks, his
    red ports, every hazard and warning, the runner and the pickups keep their glow. At 0.7 it read as less than 30%
    darker (the floor about 205-215 to 185-190, sRGB: the eye reads light on a curve), so it's 0.4 now.
    Darker (0.55 to 0.6)?

**The Casino skin** (from K1; the owner's reference `docs/art/reference/casino_zone.webp`; exports on `CasinoSkin`, `data/skins/casino_skin.tres` and the arena's `data/bosses/casino_boss_skin.tres`, F6; review with `./play.sh --quick --skin=casino`)
504. **Floor and gaps: to confirm with the owner (GDD §5: "Floor, gaps and ceiling pieces: chosen by the art
    agent from the reference *(to confirm)*").** The reference shows a dark, wet paved street with a few
    pedestrians far off, and no gaps. Placeholder: the floor is the street's **dark flagstones laid in running
    bond with brass inlaid along both edges of every lane**, a brass bar across the lane every 6 m (the still
    floor's own motion cue: the bars stream past underfoot, with pools of lamplight every 12 m and the wet
    sheen of the street toward the horizon), and **gaps are open service trenches under the street**, dark and
    deep (everything in them in deep shade, an iron wall dropping into the dark), edged in the orange every
    zone uses right on the collision edge. Not built, and offered if the owner would rather: a red carpet runner
    down some lanes (kept off: red is a hazard colour and the Golden Zone's walkways already read as one runner
    per lane), a gap as a broken stretch of paving with brass pipes and a dim lower level showing, and a
    different floor under each kind of building. `CasinoSkin.street_color`, `inlay_color`, `street_wet`,
    `trench_depth`; `CasinoStreet`, PAT_CASINO_STREET and PAT_CASINO_UNDER (kit_casino.gdshaderinc).
505. **The glow palette's departure from the reference's neon (GDD §5, the colour rule).** The reference glows
    pink, cyan, green and orange, which are the hazards' colours. Placeholder: lit signs, marquees and the
    lamps near the track glow **warm white, violet or blue**; brass and gold are lit metal (never neon:
    `cas_metal()` fakes a reflection of the lamplit street, nothing brass or iron carries glow); the
    reference's coloured boards appear only as **dim painted signs in muted rose, teal, moss and ochre** (lit
    like any wall, never glowing) high on the facades, never near the track's colours. The warm-white share of
    lit signs is half, so the street stays amber and gold rather than cold. Hazards stay the brightest, most
    saturated things on screen (the suite checks chroma and hue). Is that the right balance of warmth and cold?
    `CasinoSkin.neon_colors`, `dim_sign_colors`, `lamp_color`, `bulb_color`.
508. **How much each kind of piece appears (placeholder shares).** The balconies, pipes, air-conditioning units,
    planters, banners, lanterns, fans and girders across the street, and how often each ceiling kind turns up
    (footbridge 3, pipe-bundle gantry 3, sign gantry 2): all exports on `CasinoSkin` (groups "Facades", "Vault",
    "Casino ceilings"), tuned by eye against the reference; the owner may want the street busier or calmer.
510. **Doodads.** The Marketplace's potted plants, casino machines and hedge rows are reused unchanged in the
    Casino's palette (dark brass-trimmed cabinets, deep-green plants). Does the Casino want doodads of its own
    (a roulette table, a velvet-rope queue, a fruit machine)? GDD §3 only names the Marketplace's.
511. **The House's arena** (`data/bosses/casino_boss_skin.tres`): the facades are flush below 14.5 m (no balcony,
    pipe or blade sign stands out of a wall where the 13.5 m machine passes), the roof is raised to spring from
    34 m (so phase 3's billboard, which drops from about 35 m, never passes through the glass) and nothing is
    hung from it. The arena is therefore plainer than the street the player ran through to reach it; should
    the machine's arena keep the full dressing at the cost of the machine clipping through balconies, and
    should the billboard come down through a roof with a gap in it instead of under a tall one?
512. **The fences' and signs' looks** (`CasinoProps`; the same placeholder question every zone's props raise). The
    GDD fixes only the pink crackle of an electric fence and the yellow-and-black stripes of a sign. Placeholder:
    the fence's field is strung between brass stanchion posts on iron plinths (the casino's velvet-rope posts,
    the pink field in place of the rope), its edge bars and its OFF look are proposals, and a sign's striped
    frame goes round a lit casino sign's face. Is the stanchion the right post for a casino fence?
513. **Follow-up for the Marketplace (not changed here; `shopfront.gdshader` is the Marketplace's).** Its casino
    fronts (style 1) test `cy + storey > decor_top` on the cell's top, so a storey that straddles `decor_top` (6.2 to 9.4 m
    against 8 m) draws its glass and its rows of bulbs from 6.34 m, under the 8 m a decorative light may start at
    (the Casino's own shader starts the grid at `decor_top`, so it does not have this). A one-line fix there is to start
    the grid at `decor_top`, as `casino_facade.gdshader` does, or to mask the bulbs and the tinted glass below it.
    The violet tint of its glass panels under 8 m comes from the same test.

**The Casino in the campaign** (from K2; the owner added the Casino as Zone 4 on October 8, 2026, GDD §5, §6, §10; data in `data/zones/casino.tres`, `data/levels/casino_1.tres`, `casino_2.tres`, `data/bosses/casino_boss.tres`; review with `./play.sh --level=casino/1` or `--level=casino/boss`)
514. **The Casino's tagline** (GDD §5, Zone 4). Placeholder: "A covered casino street under a vaulted glass
    roof." (`data/zones/casino.tres`). The Marketplace's tagline drops its casinos: "Stall roofs, awnings and
    a bustling open-air market." (`data/zones/marketplace.tres`).
515. **The Casino's run speed** (GDD §3: about 21 m/s in the Neon City rising to about 25 in the Golden Zone).
    Placeholder: 23.0 m/s, between the Marketplace's 22.6 and Corporate's 23.4, no other zone's changed
    (`data/zones/casino.tres`, `run_speed`). The House runs at it now (GDD §3: a boss runs at its zone's
    speed), 23.0 instead of the Marketplace's 22.6.
517. **What each Casino level adds** (GDD §5: "still to design"). Placeholder: both play Marketplace 2's
    features (everything up to the wall fences and the shopfronts' vent screeches) with no introductions
    (`feature_starts` empty) and no extra pick weights (Marketplace 2's extra weight on vent screeches was for
    their introduction), so nothing new comes until Corporate 1. `test_campaign` exempts them from "each
    level brings something new" and the Casino from "every zone introduces a new enemy", keyed to the GDD's
    owner decision.
518. **The Casino levels' numbers.** Placeholders: 145 s and 150 s long (the campaign's levels now total 39.0
    minutes, GDD §5's "about 40"); seeds 701 and 702 (no existing seed renumbered); danger density 0.27 for
    both (between Marketplace 2's 0.26 and Corporate 1's 0.28; the dial never falls); doodads 0.8 like the
    Marketplace's; Marketplace 2's spacing, fill, wide gaps, charge-path cyborgs, narrow ceilings and credit
    settings; no level sky of their own (the Casino skin's sky).
520. **Enemy numbers that step at an `enemy_scaling` threshold** were moved in data so that every existing
    level keeps exactly what it had (the in-between numbers, such as reload times and bolt speeds, follow the
    re-spaced scaling). Should these steps move with the curve instead (for example the Casino, not
    Marketplace 2, as the first level with turret and drone pairs)?
    - Barnacle Turret pairs from Marketplace 2 on: `pair_min_scaling` 0.45 to 0.4; its 6 shots to kill from
      the Dead Zone on (Corporate 2 keeps 5): `health_late` 6.0 to 5.9 (`data/enemies/barnacle_turret.tres`).
    - Drone pairs from Marketplace 2 on: `pair_min_scaling` 0.5 to 0.4 (`data/enemies/drone.tres`). (A
      barrage stays at 6 bullets everywhere but the Golden Palace; its rounded bullet count only matters there.)
    - Hover trucks: two a level from Marketplace 2 on and three at the Golden Palace, one window shooter from
      Marketplace 2 and two at the Golden Palace: `max_per_level` 1.0/3.0 to 1.2/3.1, `shooters` 0.0/2.0 to
      0.2/2.1 (`data/enemies/hover_truck.tres`; both rounded down).
    - Octodog charges, 3 to 4 from Marketplace 2 on (2 to 3 before): `charges_min/max_late` 3/4 to 3.25/4.25,
      rounded (`data/enemies/octodog.tres`; the counts became decimals in `octodog_tuning.gd` so the step can
      fall between two levels).
    - Shots to kill a cyborg or window cyborg at every weapon tier, level by level: `health_late` 5.0 to 4.9
      (`data/enemies/cyborg.tres`, `window_cyborg.tres`), and a Tithe Collector: 4.5 to 4.4
      (`data/enemies/tithe_collector.tres`). The shot table at the campaign's ends (`test_powerups`) is
      unchanged.
    - The Resonator's place in the Golden Zone (`zone_t`: Golden 1 at 0.048, Golden 2 at 0.524, Golden 3 at
      1): `scaling_from` 0.85 to 0.86875 (`data/enemies/resonator.tres`).
523. **The Casino's cinematics** (GDD §6). Placeholders: its intro plays the arrival flyover over the Casino
    (title "The Casino"; its card names the zone: ZONE 4, CASINO), its outro is a placeholder card "Beyond
    the Casino: a short scene after The House, heading for the corporate district"
    (`data/cinematics/casino_intro.tres`, `casino_outro.tres`). The Marketplace's outro now reads "a short
    scene leaving the market for the casino district" (`marketplace_outro.tres`).

**The Casino's roof and named signs** (from K3; the owner's answers of October 9, 2026 to items 506, 507 and 509; exports on `CasinoSkin`, F6; lettering in `scripts/world/skins/casino/casino_lettering.gd`)
525. **Two famous casinos, or a chain?** The owner asked for the big signs to spell "Gasket's House of Chance" and
     "The Brass Lotus" and said they love the two. Two readings:
     - *Landmarks* (built): the street is cut into periods of `CasinoSkin.name_spacing` metres, 100 by default, both
       walls together. Each period has at most one named casino (a casino with a big sign, hash-picked, from the middle
       half of the period if there is one), and the names alternate from period to period, so a name is never nearer
       than 100 m to itself and at most one of each is in view at a time. That is about ten named casinos a kilometre
       out of about 27 casinos with a big sign a kilometre (30 of 81 over 3 km, 46 to 150 m apart); the others keep their mark and rows of glyphs. A runner meets
       a famous casino every 50 to 150 m and learns the two names by seeing them again and again.
     - *A chain*: every casino with a big sign is named, one of the two by hash (`name_spacing` 0). The street then
       reads as two brands with branches everywhere (a stretch of five "The Brass Lotus" in a row is possible).
     Which does the owner want? The spacing is one export on the skin; 0 gives the chain, 200 or more a rarer landmark.
526. **Casinos whose big sign plays the cult's feed (35% of them).** The feed's screen stays a screen with no words on
     it (the cult's feed is wordless). Placeholder: a Gasket's casino puts its name on a one-line strip over the screen
     in its own brass frame, and a Brass Lotus casino carries its name on its tall blade sign only. Every named casino
     also has a blade sign at the far end of its building (GASKET'S, or THE BRASS LOTUS, stacked down it): a board on
     a wall is seen along its face from the street, so only the blades can be read from a distance while running.
     Is that right, or should a feed casino go without a name, or without a blade? (The House's arena has no blades:
     its faces are kept flat because the billboard slides past them; the names are on flat boards there.)
527. **Where else the names might appear.** Only the named casinos' big signs and their blades carry words. Every other
     sign (the lounges' blade signs, the arcade halls' name boards, the sign gantries over the street, the other
     casinos' boards) keeps its rows of glyphs, as the owner asked. Should the sign gantries (a ceiling piece, seen
     face-on from far down the street) carry one of the names too?

**The curve after the Casino: no level gets easier** (from K4; the owner's answer to item 519, October 9, 2026; `difficulty_curve_exponent` 0.79 in `data/campaign/campaign.tres`, F6; GDD §6)
528. **Is this the curve the owner wants?** (GDD §6.) One exponent lifts the early and middle levels the most.
     City 2 to Gangland 3 come out 0.03 to 0.04 harder than before the Casino, more than the Marketplace's
     +0.016 and +0.026, and City 1 to City 2 is now the campaign's biggest step (+0.140; +0.107 before).
     Per-level biases could set any level by hand instead. The early curve can't get any steeper without an
     economy change: City 2's own build leaves the wallet at 898 credits against the laser's 900, and with the
     exponents from 0.70 to 0.78 City 2's layout pays enough to buy the laser after City 2, against the
     approved "laser I waits for City 3" (`test_economy`).
     - Placeholder: `difficulty_curve_exponent` 0.79 (`data/campaign/campaign.tres`).

    *Background (task K4's report):*

    The owner's answer to item 519 (October 9, 2026, GDD §6): no level gets easier when levels are
    added; the Marketplace keeps at least its old difficulty (a little harder is welcome); Corporate and the
    zones after it may get harder. Task K4 bends the 17-level curve with one number in data,
    `difficulty_curve_exponent` 0.79 in `data/campaign/campaign.tres` (it was 1, linear; `DESIGN-TBD` on
    `Campaign.difficulty_curve_exponent`, whose F6 step is now 0.01). `difficulty_start` 0.1, `difficulty_end`
    0.9 and the levels' biases (City 1 −0.05, Golden 2 +0.05, Golden 3 −0.05) are unchanged.

    `enemy_scaling` doesn't use the exponent (`Campaign.configure`: the level's place in the campaign, 0 → 1), so
    it is exactly K2's, and so are its moved thresholds (item 520), the scaling of the enemies the bosses bring
    and the recency curve's ages. `test_campaign` checks it, and checks every level against the 15-level curve.

    | Level | 15-level curve (before the Casino) | K2: 17-level linear | K4: exponent 0.79 | K4 against the 15-level curve |
    |---|---|---|---|---|
    | City 1 | 0.050 | 0.050 | 0.050 | +0.000 |
    | City 2 | 0.157 | 0.150 | 0.190 | +0.033 |
    | City 3 | 0.214 | 0.200 | 0.255 | +0.041 |
    | Gangland 1 | 0.271 | 0.250 | 0.313 | +0.042 |
    | Gangland 2 | 0.329 | 0.300 | 0.368 | +0.039 |
    | Gangland 3 | 0.386 | 0.350 | 0.419 | +0.033 |
    | Marketplace 1 | 0.443 | 0.400 | 0.469 | +0.026 |
    | Marketplace 2 | 0.500 | 0.450 | 0.516 | +0.016 |
    | Casino 1 | – | 0.500 | 0.563 | – |
    | Casino 2 | – | 0.550 | 0.608 | – |
    | Corporate 1 | 0.557 | 0.600 | 0.652 | +0.095 |
    | Corporate 2 | 0.614 | 0.650 | 0.695 | +0.081 |
    | Dead Zone 1 | 0.671 | 0.700 | 0.737 | +0.066 |
    | Dead Zone 2 | 0.729 | 0.750 | 0.779 | +0.050 |
    | Golden 1 | 0.786 | 0.800 | 0.820 | +0.034 |
    | Golden 2 (peak) | 0.893 | 0.900 | 0.910 | +0.017 |
    | Golden 3 | 0.850 | 0.850 | 0.850 | +0.000 |

    Each level is at least 0.041 harder than the one before it (Golden 1 after Dead Zone 2 is the smallest step),
    Golden 2 is the peak and Golden 3 sits between Golden 1 and Golden 2, as before.

    **Why 0.79.**

    - **Every level at least as hard as before the Casino:** Marketplace 2 binds it. Its 0.500 holds up to an
      exponent of 0.838; Corporate 1 onward were already harder on K2's linear curve.
    - **The Marketplace a little harder** (the task's example: +0.01 to +0.03 each): exponents from 0.778 to
      0.808.
    - **City 1 and Golden 3 unchanged, Golden 2 the peak, every step above 0.02:** true at any exponent in that
      range (the curve's ends don't move).
    - **The levels' own builds decided the rest.** Every layout changes with the exponent, so a scan built 0.70
      to 0.83 in steps of 0.01 against the design properties the suites check on the levels' own seeds (two wider
      gaps per build, Corporate 2's first chase holding one, Corporate 1's Buzz Overdrive in its first quarter at
      two lane counts of three, the wall fence introductions within 10 s, Marketplace 1's first turret on time,
      doodads at every lane count, the early economy, a truck in every level with the Enforcer, the Sentinels'
      rules, and at most 6 late introductions of 63). No value keeps them all:
      - 0.70 to 0.78 and 0.83: City 2's own build pays enough for the laser by City 2 (wallet 902 to 958; the
        laser costs 900, and `test_economy` keeps it for City 3). Some of them miss more: a wall fence
        introduction, Corporate 1's Buzz Overdrive, a wider gap (0.78: Casino 1 at 3 lanes), or 7 late
        introductions (0.77).
      - **0.79: one miss.** Marketplace 2 at 3 lanes meets its first full-height wall fence 15.4 s after the
        feature's start (10 s wanted). Neither wall has a fair spot in those 10 s, so the placement does what
        it must (item 529). Its layouts also cost Corporate 2's first truck its volley at 5 lanes, which the
        scan didn't count (item 530).
      - 0.80: three misses: that one (16.7 s), Gangland 3 at 5 lanes with one wider gap of two, and Corporate
        1's Buzz Overdrive.
      - 0.81 and 0.82: one miss, Corporate 1's Buzz Overdrive (in its first quarter at one lane count of three;
        the Buzz Overdrive is that level's new enemy). They also leave Marketplace 2 under +0.01.

    **What the reshape changed.**

    - **Patterns gated by difficulty** (`min_difficulty` / `max_difficulty`; a level's difficulty rises 0.25
      across it), against the 15-level curve:
      - Gained:
        - City 3 reaches `gap_with_fence_lane`, `ceiling_over_gauntlet` and the main `hover_truck` in its
          last 2% (never before), and `cyborg_pair`, `window_cyborg_pair` and `fence_stagger` from 78% in (94%).
        - Gangland 1 gets `cyborg_stagger` and `screech_manhole_row` in its last 5% (never), and the main
          `hover_truck` from 75% (92%).
        - Gangland 2 gets `fence_pulsing_all` in its last 7% (never); Gangland 3 gets `drone_pair` in its last
          8% (never).
        - Marketplace 1 gets `drone_pair` from 73% (83%). Marketplace 2 gets `drone_pair` from 54% (60%),
          `fence_pulsing_all` from 34% (40%) and `cyborg_stagger` from 14% (20%).
        - Corporate 1 has `drone_pair` and `fence_pulsing_all` from its start (37% and 17% in before), and
          Corporate 2 has `drone_pair` from its start (14%).
        - Golden 2's two Gilded Sentinel patterns start 16% in (23%).
        - Every other gated pattern from City 2 to Marketplace 2 comes 3% to 17% of the level earlier (City 2's
          `fence_mixed` from 84%, 97% before).
      - Lost: only the easy patterns that stop at a difficulty, which now end sooner.
        - `hover_truck_rare`: City 3 to 98% of the level (all of it before), Gangland 1 to 75% (91%), Gangland
          2 to 53% (69%), Gangland 3 to 32% (46%), Marketplace 1 to 13% (23%).
        - `fence_full_single` and `fence_pulsing_single`: Gangland 2 to 93% (all of it), Gangland 3 to 72%
          (86%), Marketplace 1 to 52% (63%), Marketplace 2 to 33% (40%), and Corporate 1 none (its first 17%).
      - Against K2's curve, everything K2 took from City 2 to Marketplace 2 is back, and comes earlier than on
        the 15-level curve. The Casino's harder patterns come earlier too:
        - Casino 1: `drone_pair` from 35% (60% on K2's), `fence_pulsing_all` from 15% (40%).
        - Casino 2: `drone_pair` from 17% (40%), `fence_pulsing_all` from its start (20%), and no
          `fence_full_single` or `fence_pulsing_single` (its first 20%).
      - Dead Zone 1 and 2 and Golden 1 and 3 are past every gate either way.
    - **The economy** (`tools/measure/economy.gd --lanes=5 --seeds=0 --share=0.7`, as `test_economy` reads
      it): the completion bonuses follow the level index, as on K2's curve, so only the layouts' own credits
      move.
      - A clean 5-lane playthrough's wallet with boss payouts is 16,624 (K2's 16,874; 14,446 before the
        Casino).
      - Every item comes into reach after the same level as on K2's curve but the Missile: after Marketplace 2
        instead of Marketplace 1. Gangland 3's own build carries 787 credits (1,088 on K2's), and the wallet
        after Marketplace 1 is 4,711 of the 4,800. Over each level's seed and six others, the wallet stays
        within about 2% of K2's at every level (14,065 against 14,172 after Golden 3), and every item, the
        Missile included, comes after the same level.
      - City 2's own build leaves the wallet at 898, 2 credits under the laser's 900 (`test_economy`: the
        laser waits for City 3), against 881 on K2's curve. Over seven seeds City 2 averages 919 (K2's: 910),
        so that delay holds on the levels' own seeds only, on either curve.
    - **Late introductions** (`test_campaign`, the levels' own seeds): 5 of 63 (K2's: 6; the limit is 6).
      - Marketplace 2's wall fences at 3 lanes: start 328 m, first at 675 m (item 529).
      - Corporate 1's Buzz Overdrive at 5 lanes: start 339 m, first at 1212 m (1214 on K2's curve, 976 before
        the Casino).
      - Corporate 1's Buzz Overdrive at 6 lanes: first at 970 m (783 on K2's, 585 before), two there (one on
        K2's, three before).
      - Corporate 2's Enforcer at 5 lanes: start 176 m, first at 641 m (713 on K2's).
      - Dead Zone 1's host at 3 lanes: start 351 m, first at 2004 m (about 2010 before and on K2's).

      Marketplace 2's vent screeches at 3 and 6 lanes, late on K2's curve, are on time again.
    - **The levels' own builds**:
      - Corporate 2's first Enforcer chase holds a wider gap at 3, 5 and 6 lanes again (`test_wide_gaps`'
        `CORPORATE_2_CHASE_LANES`). K2's curve left 5 lanes without one. The first chase holds one in 9 of
        the 18 level and lane builds with trucks.
      - No hover truck leaves before its level's ramps start. On K2's curve Gangland 1's did at 3 lanes
        (`test_hover_truck`'s `BEFORE_RAMPS` is now empty and checked both ways).
      - The danger density bands hold: 13-19% more enemies in the first levels, 26-28% in the middle ones,
        32-36% in the final ones, and 32.7% at 3 lanes in the final ones (item 521's 29.7% question: Golden 2's
        and 3's dials stay 0.39).
      - The cases the tests pin to a scenario on a seed were re-found where the scenario moved:
        - `test_danger_density`'s route case moves to Golden 1 at 3 lanes on seed 9005 (Dead Zone 1 at 6 lanes
          on 9007 no longer builds that way). It was found by building 189 seeded builds without
          `DangerDensity.doodad_ok`.
        - `test_wide_gaps`' filler cases are now City 3 at 3 lanes on 7040, Gangland 1 at 6 on 9101 and
          Gangland 3 at 5 on 9101.
        - `test_enemy_director`'s control case with the attack-turn switch off moves to Gangland 3 at 3 lanes
          (2.0 s of overlaps; its 6 lanes now have none).
        - `test_charge_paths`' Golden 2 plants at 3 lanes.
        - `test_enforcer_truck_runs`' `NO_VOLLEY_LANES`: Corporate 2 at 5 lanes fires no volley (item 530),
          checked both ways.
      - Marketplace 1's first turret now stands exactly at its feature's start (316.4 m). `test_barnacle_turret`
        takes the 0.01 m rounding margin the other "nothing before its start" checks take.
    - **Two generator fixes**, found while scanning (each possible on the earlier curves too). The levels' own
      builds are byte for byte the same with them and without.
      - The danger density pass could add a window cyborg on a Gilded Sentinel's wall section. Its wall
        enemies now keep off it: the pass asks the rules the generator hands it (`LevelGenerator.
        wall_section_rules`, here `GildedSentinelRules.on_wall_section`). `test_gilded_sentinel` pins Golden 2
        at 5 lanes on seed 9034, where the pass would put a window cyborg there without the check, and checks
        `on_wall_section` against `problem()` along both walls.
      - A build could end without its Enforcer Truck when its only baits' arrivals all fell during other
        attacks: about one or two seeded builds in a thousand, on every curve. The feature guarantee now covers
        it by moving the Octodog and Buzz Overdrive picks (`LevelGenerator.dependent_features`,
        `EnforcerTruckRules.GUARANTEED_BY`), one more each a build however many missed features ask, and none
        when the data allows no truck (`places_any`). None of 738 seeded builds misses one now.
529. **Marketplace 2's wall fence introduction at 3 lanes comes 15.4 s after the feature's start** (GDD §9.1;
     open question B5's 10 s). Its signs, window cyborgs and a ramp, the outer lanes' pieces, and its big
     attacks and floor cuts leave neither wall a fair spot before then. Is that acceptable, or should the
     generator hold room for introductions (a generator task)?
     - Placeholder: `LATE_INTRODUCTIONS` in `tests/suites/test_wall_fences.gd`, which checks that both walls
       are taken from the start right up to the introduction, and that the build is still late.
530. **On the Enforcer's first level, a truck can be destroyed before it ever fires** (GDD §9.13; open
     questions 357, 364, 366 and 400–403, 409).
     - Since C6e, no wider gap comes in a chase before the truck's showing window, so a wider gap no longer
       wrecks Corporate 2's first truck before it fires. Measured on the level's own seed with the Casino's
       levels and K4's curve, as `test_enforcer_truck_runs`' runner plays it (it keeps out of each bait's way,
       so the bait's charge destroys the truck):
     - At 3 lanes the truck arrives at 305 m and shows itself as it arrives (window 287–505 m). It fires one
       volley, and its bait's charge (745 m) destroys it. The chase's wider gap, at 543 m, is past the window.
     - At 5 lanes the level has one truck (item 402's case, and item 403's: see below). It arrives at 1219 m,
       about 10 s before its bait, a Buzz Overdrive charging at 1460 m, and shows itself in a window whose bait
       may claim its turn (1201–1410 m, item 409). Its first volley waits for the showing (question 366), and
       from `hold_seconds()` before the bait's rev it holds fire, so it has no time for a volley: the bait's
       charge destroys it first. The player sees it but never sees it fire.
     - At 6 lanes the first truck (296 m) has its window after its bait. It fires one volley without showing
       itself (its wait for a showing runs out), and its bait's charge destroys it. The second truck (1445 m)
       shows itself and is destroyed by its bait's charge before its first volley, as at 5 lanes.

     Should a truck that shows itself get time for a volley before its bait (a later bait, an earlier arrival,
     or a volley allowed after its showing even in the hold before the bait)? Or is a debut where it only shows
     itself acceptable?
     - Placeholder: none changes it. `test_enforcer_truck_runs` allows a build with no volley only at 5 lanes
       (`NO_VOLLEY_LANES`, checked both ways), and only when each truck there showed itself and was destroyed
       before its first volley.
531. **Are these 5 late introductions acceptable?** This is item 521's question with the list above.
     - Placeholder: none; `test_campaign`'s limit is 6 of 63.
532. **A build whose first Sentinels are a pair** (GDD §9.11 and §6: one new thing at a time; outside K4, found
     in its review). The Golden Palace at 5 lanes on seed 602 starts with a Sentinel pair. That is not a
     campaign seed: the levels' own seeds and the seed sweep's build right. `GildedSentinelRules.problems()`
     reports "the level's first Sentinel isn't alone, swinging once (its introduction)". The build is the same
     at exponent 1.0 and without K4's generator fixes, so the case is older than K4. Should the generator
     always keep a level's first Sentinel alone, or does the rule only matter in Golden 2, which introduces
     them?
     - Placeholder: none. `GildedSentinelRules.apply` leaves the build as it is.

**Merging main into the Casino branch** (from K5; main's C6e showing windows, PERF2, G6b and G8 met the Casino's levels and K4's curve)
533. **Corporate 2's introduction now moves late on its own seed** (GDD §9.13, §6; items 402, 403 and 530; the
    owner's call). Item 403's placeholder says the introduction "never moves on the level's own seeds". With the
    Casino's levels and K4's curve it does at 5 lanes.
    - The final 5-lane build is the generator's third attempt. Every campaign level guarantees each of its
      features, and the first two attempts lacked the screech vents, so each retry forced one more screech vent
      pick. Both of those had their first truck at 261 m, with a window before its bait (243–433 m, CLASSIC
      mode; the bait at 608 m), and a second truck at about 1134 m with none (a Buzz Overdrive's attack there).
    - In the third, the level's one truck arrives at 1219 m, about 52 s into the level (the reach for an
      introduction is 448 m), in a CLAIM window (1201–1410 m) before its bait at 1460 m. A second truck would
      have overlapped its chase, so item 402's rule kept only the one that shows itself. K4's curve without C6e
      had the introduction at 641 m, already late; `test_campaign` still counts 5 late introductions of 63.
    - A CLAIM window never fires before its bait: this truck and 6 lanes' second truck (1445 m) each show
      themselves and are destroyed by their bait's charge before a volley (item 530).
    - The options: item 403's alternative (keep the introduction early, and unseen); CLASSIC windows that may
      leave out one runner lane, as item 411 allows the other modes; one volley allowed between a CLAIM showing
      and its bait's hold; or the screech-vent retry (the guarantee's forced picks for the missing vents are what
      moved the truck from 261 m).
    - Placeholder: C6e's `_choose` in `enforcer_truck_rules.gd`, unchanged.
534. **The final zones at 3 lanes: about 30% more danger, not 35%** (item 521's question, "is about 29% enough at
    3 lanes in the final zones?", now for the obstacles too; the owner's request in `docs/USER_REQUESTS.md`).
    - C6e's showing windows are calm stretches that the danger density pass's rows keep off. With them,
      `test_danger_density`'s sample of the final zones (Dead Zone 1, Golden 2 and 3, each on its own seed and
      9001–9002) had 28.8% more obstacles at 3 lanes, under the band's 30% floor. Over 7 seeds (each level's own
      and 9001–9006) the same band had 30.2%: the 3-seed sample fell under its line, while over more seeds the
      levels stayed just above it. Higher dials buy almost nothing there, and more rounds (`obstacle_rounds` 3 to
      6) nothing.
    - The enemies sit at about 30% whatever the wall fences' share: 30.2% over the 7 seeds as
      `test_danger_density` counts them (the cyborgs planted in charge paths left out), 29.4% counting those too
      (the test's sample: 32.6%).
    - The placeholder raises the wall fences' share of the dial (`wall_fence_increase_scale`) from 1.25 to 1.9.
      The sample then has 30.6%, and the 7 seeds 31.9%. It adds wall fences only: 447 to 505 on the levels' own
      seeds (+13%), from Marketplace 2 on (the levels before have none). Nothing else in those layouts changes
      but the side wall gaps of two builds (Dead Zone 2 and Golden 2 at 3 lanes), which keep off the wall
      fences. It is kept because the owner finds every level too easy, not because the floor needs it.
    - The alternative: a finer grid for the pass's new rows (`row_step_seconds` 0.25 instead of 0.5, the share
      at 1.25) adds floor pieces instead: 31.9% over the 7 seeds (the floor 31.3%), 30.4% in the sample. It
      changes the build of every level the pass adds rows to, and tries twice the spots.
    - The final zones over the 7 seeds (more with the pass than without it):

      | | 3 lanes | 5 lanes | 6 lanes |
      |---|---|---|---|
      | Enemies (either share) | 30.2% | 32.4% | 30.1% |
      | Obstacles, share 1.25 | 30.2% (floor 29.5%; wall fences 216 to 293) | 36.3% | 37.7% |
      | Obstacles, share 1.9 | 31.9% (floor 29.5%; wall fences 216 to 328) | 37.3% | 38.3% |
      | Obstacles, finer grid, share 1.25 | 31.9% (floor 31.3%; wall fences 216 to 295) | 36.2% | 37.8% |
      | Obstacles, the test's sample, share 1.9 | 30.6% | 35.5% | 38.8% (its cap: 40%) |

    - Wall fences on the levels' own seeds, share 1.25 to 1.9 (the middle zones' band goes from 26–27% to
      27–28% more obstacles in the test's sample):

      | Level | 3 lanes | 5 lanes | 6 lanes | All |
      |---|---|---|---|---|
      | Marketplace 2 | 18 → 20 | 15 → 17 | 16 → 18 | 49 → 55 |
      | Casino 1 | 19 → 21 | 12 → 14 | 13 → 15 | 44 → 50 |
      | Casino 2 | 20 → 23 | 18 → 20 | 16 → 19 | 54 → 62 |
      | Corporate 1 | 12 → 13 | 14 → 16 | 20 → 23 | 46 → 52 |
      | Corporate 2 | 13 → 14 | 20 → 22 | 10 → 11 | 43 → 47 |
      | Dead Zone 1 | 17 → 20 | 17 → 20 | 13 → 15 | 47 → 55 |
      | Dead Zone 2 | 12 → 14 | 11 → 11 | 15 → 17 | 38 → 42 |
      | Golden 1 | 15 → 18 | 12 → 14 | 14 → 16 | 41 → 48 |
      | Golden 2 | 16 → 19 | 10 → 11 | 15 → 17 | 41 → 47 |
      | Golden 3 | 17 → 17 | 14 → 17 | 13 → 13 | 44 → 47 |
      | All | | | | 447 → 505 |

    Is about 30% enough at 3 lanes in the final zones? If more is wanted there, the ways are more wall fences
    (the placeholder), the finer grid, or shorter calm stretches around a showing.
    - Placeholder: `wall_fence_increase_scale = 1.9` in `data/tuning/danger_density.tres` (`DESIGN-TBD` on the
      field in `scripts/world/danger_density_tuning.gd`).
535. **A new row for a wider gap may take holes and fences out of its way** (GDD §9.13: a couple per level; item
    357). C6e keeps every wider gap off a chase before its showing window. On 306 builds of the Enforcer's levels,
    one Dead Zone 1 seed (5 lanes, 9004, in `test_campaign`'s sweep) then had no room for any: its only room was
    that chase. A Golden Palace seed (3 lanes, 9010) already had none before the merge. When the other three ways
    give a level no wider gap at all, the pass now adds a new row where only the level's own holes and plain fences
    are in the way, and takes those out. This is how it already widens a row of the level's own. Only builds
    with no wider gap change; every level's own seed builds as before. Should this last way also apply when a
    level gets one of its two, or is one fewer acceptable there, as now?
    - Placeholder: `WideGapPlacement._add_clearing`, only when the pass found none (`add_rows` must be on). Its
      report's `added_clearing` counts its row. `test_wide_gaps` pins both seeds (`LAST_RESORT_CASES`: 8 and 4
      pieces taken out) and checks it on a fenced plain stretch: plain fences make way, pulsing ones don't.
537. **How busy the Casino's street is, after the build-budget trim** (from K5, skin side; extends item 508, "How much each kind of piece appears")
    The placeholder densities in item 508 (and the roof's in item 509) were trimmed to buy back build time:

    | export                | was  | now  |
    |-----------------------|------|------|
    | `balcony_share`       | 0.55 | 0.42 |
    | `pipe_share`          | 0.55 | 0.42 |
    | `unit_share`          | 0.50 | 0.25 |
    | `lantern_share`       | 0.50 | 0.35 |
    | `fan_share`           | 0.28 | 0.20 |
    | `banner_share`        | 0.70 | 0.60 |
    | `crossbeam_spacing`   | 32 m | 40 m |
    | `bay_scale` (new)     | 1.0  | 1.5  |

    `bay_scale` widens the shop windows' bays to 1.5 times the Marketplace's (the same piers, a third fewer, broader
    windows), which also thins the citizens by a third. Measured on this machine (6 lanes, mean chunk build): the
    street was 4.4-4.5 ms, it is now 3.8-3.9 (the Marketplace 3.7-3.9). Every one of these is an export on
    `CasinoSkin`, so a busier street is a `.tres` edit away; the price is about 0.1-0.15 ms a chunk for each of the
    three biggest (balconies and units together, the roof's hangings together, the window bays).

    Question for the owner: is the thinner street fine, or should it be as busy as the reference and the build
    budget (or the machine it is measured on) be revisited instead?

    *For the record (not a design question):*
    - The skin budget's load factor (`REFERENCE_IDLE_MS` = 2.7, a 40-lane greybox build) reads 1.00 on the machines
      this was measured on, yet every skin's build there ran about 1.3 times slower than in earlier sessions
      (the Marketplace 2.4-2.8 ms then, 3.2-3.9 now; the pre-merge tree runs equally slowly today, so main did not
      cause it). A greybox build is mostly node creation, a GDScript-heavy skin build is not, so the load factor
      cannot see this. A reference that builds a skin-sized mesh in GDScript would.

**The Beach: its skin** (from D10; GDD §5, Zone 6 (zone 5 when it was added, before the Casino's zone 4 joined main); the owner's reference `docs/art/reference/beach_zone.jpg`; numbers in `data/skins/beach_skin.tres`, `BeachSkin`; review with `tools/showcase/skin_review.tscn -- --skin=beach`, with `--open` for the open walls and `--sky=beach_sunset`, and `splash_review.tscn`)
539. **The pool water doesn't glow.** The reference's pools glow turquoise, too close to the anti-grav pads' glowing
    cyan. Placeholder: deep, unlit teal (`water_color`, `PAT_BEACH_WATER`) with unlit glints, everything inside a
    pool at most 40% of the darkest floor's luminance, so a pool reads as a hole like every gap; the turquoise stays
    in the sea on the horizon. Should the water carry a faint glow after all (a violet or blue rim, say), at the cost
    of reading less like a gap?
540. **Decorative neon in violet, blue or warm white only.** The reference's neon is pink, yellow, cyan, green and
    orange, all hazard hues. Placeholder: `neon_violet`, `neon_blue` and `neon_white` (`PAT_BEACH_NEON`), the only
    decorative glows besides lamps and the cult's emblem and feed.
541. **String lights and lanterns.** The reference's string lights and lanterns glow in many colours. Placeholder:
    string lights glow warm white, blue or violet; paper lanterns are unlit shells in muted colours
    (`lantern_shell_colors`) with a warm-white glow inside; bunting and flags are unlit and muted.
542. **Pool frames are flush.** The reference's tanks stand proud of the sand; a raised rim would read as an obstacle
    that isn't there (GDD §3). Placeholder: the tank is sunk flush, with a dark steel coping beside the usual orange
    edge so it pops against the sand. Should a pool have a low frame that stands a little proud?
547. **The ceilings.** Placeholder: three kinds, by relative weight (`footbridge_weight` 3, `veranda_weight` 3,
    `barge_weight` 2): a boardwalk footbridge across every lane, a veranda deck reaching one wall, and a hovering party
    barge (any width; engines in a pale violet-blue). The reference shows only decks and verandas. OK?
548. **The doodads.** Placeholder: a surfboard rack (small), a beach cabana or a palm in a planter (medium, by
    `look_seed`) and a tiki bar kiosk (large); none has a face, so none reads as a cyborg. OK?
549. **Boardwalk against sand.** Placeholder: sand with boardwalk runs over some lanes (`boardwalk_share` 0.2, runs of
    one to three 12 m slots), flat throughout; the reference has a boardwalk deck only along the buildings. More or
    less boardwalk?
550. **The wall-run marks** (GDD §3). Placeholder: 3.6 cm lines at 2 m and 4 m in a slightly darker shade of the wall
    (`wall_mark_color`, a multiplier of about 0.7), like the Marketplace's. Readable enough in play?
551. **Colour at street level.** Placeholder: seven bamboo tones; in the wall-run band, painted doors and shutters in
    muted turquoise, coral and mustard (never a glassy blue, which reads as a window), surfboards painted flush on the
    wall, painted boards and murals; above 8 m, paper lanterns and unlit striped awnings across the verandas'
    openings. All muted (chroma at most 0.5), flush or recessed in the band; the reference's sloping awnings over
    the street are left out (nothing hangs out more than 0.25 m below 12 m). More colour, or less?
554. **The cult** (GDD §5). Placeholder: the emblem on some neon signs, roof billboards and the barge's hull (never
    under 0.9 m, never a hazard colour); the feed on TVs behind some upper-deck bars and on roof billboards, never in
    the wall-run band. Shares: `emblem_share` 0.4, `feed_tv_share` 0.35, `feed_board_share` 0.3.
555. **What is past an open wall** (the owner, October 9, 2026: "the player can see the surrounding area a little bit
    better"). Placeholder (`BeachSkin.wall_gap`, `BeachOpen`): the standard gap marks (the orange lip, the dark end
    slabs, the orange stripes), then a shore 1.4 m below the street (`beach_drop`): sand, a wet band, a foam line,
    shallows and the sea in three blues, the waterline swinging 16–64 m out, the island on the horizon. Nothing there
    is solid. The colours (`wet_sand_color`, `foam_color`, `sea_*_color`) are guesses. OK?
556. **What stands on that beach.** Placeholder: palms, beach umbrellas with loungers, surfboards stuck in the sand
    and now and then a thatched hut (`open_palm_share` 0.5, `open_umbrella_share` 0.4, `open_board_share` 0.3,
    `open_hut_share` 0.45 of 12 m cells), all dry, at least 9 m from a gap's ends and from the wall line
    (`open_margin`, `open_near`). Left out: people, boats, nets, ropes, volleyball courts, fires (anything that could
    read as a hazard or a citizen). Add any?
558. **The sunset's colours** (`data/skies/beach_sunset.tres`, on Sunset Strip). Placeholder: a periwinkle zenith, a
    peach horizon, a violet-pink haze, an orange sun glow, orange and pink clouds over lavender shadows, no stars,
    a warm fog, at least three times as bright overhead as the Marketplace's sunset and under the glow threshold;
    the street's light warmed by `scenery_tint` (1, 0.88, 0.8), G8's rule. Warmer, pinker, darker?
559. **The splash** (the owner, October 9, 2026: a fall makes a splash, "if that isn't too difficult"). Built
    (`BeachWaterWatch`, `BeachSplash`): a foam crown, 30 droplets and two spreading rings, off-white and unlit, for
    1.2 s, with a `splash` sound (`-4.5 dB`, generated). It plays out before and through the death screen's
    lead-in. Only the runner splashes. Should enemies falling into a pool (an Octodog baited into a gap, an Enforcer
    wreck) splash too? A bigger or louder splash?

**The Beach: open side walls** (from D10b; the owner, October 9, 2026: the side walls should "appear about 50% of the time that they are now ... much longer sections where there aren't sidewalls"; numbers in `data/tuning/beach_wall_gaps.tres`, F6 "Wall gaps" in a Beach level; `LevelConfig.wall_gap_tuning` and the coverage mode in `WallGapPlacement`)
560. **How much of each wall opens.** Placeholder: `coverage_target` 0.52, so each wall stands on about 48% of its
    level, against 96–100% elsewhere. A wall never opens through what it must keep (a ramp's launch and longest wall
    run, signs, wall fences, wall enemies, ceilings reaching it, wider floor gaps, the run-up and the end), so a busy
    wall stands more: measured with the campaign's settings, 107 of 108 walls stand on 40–60% (median 49%) over the
    levels' own seeds and others, and a few busy ones up to about 65%. Is about half right in play, and should a
    busy wall in the Beach carry fewer wall pieces instead?
561. **Both walls open at once** (the widest view, nothing to run along). Placeholder: `both_open_max` 0.3, at most
    30% of a level (measured 15–30%). OK?
562. **The shortest open stretch, and the shortest stretch of wall standing again.** Placeholder: 2 s each
    (`open_seconds_min`, `solid_seconds_min`; 48 m at 23.8 m/s), so the walls never flicker. Open stretches run 48 m
    to about 860 m (median about 117 m), most of the open length in stretches of 100 m and more.
563. **The longest open stretch.** Placeholder: no limit; up to about 860 m (36 s) on other seeds, and both walls open
    for the first 23 s of Tiki Tides at 5 lanes. Should a long one be broken up by a stretch of wall?
564. **A narrower clearance around what a wall holds.** Placeholder: `clear_seconds` 0.35 s (about 8 m) around signs,
    wall fences, wall enemies and ceilings, against the shared 0.5 s, so more of each wall can open; the margins
    that time a wall run (around a ramp and a wall enemy) stay the shared ones. Is 8 m of wall enough?
566. **Its mix.** Placeholder: no `feature_weights` (Corporate 2's heavier military presence stays Corporate 2's).
    Without it, one build in 54 on other seeds had no Enforcer Truck (it only comes where a bait's chase has room);
    every build on the levels' own seeds has one. OK?
567. **Lengths, density and seeds.** Placeholder, like their neighbours: 145 and 150 s, `danger_density_increase` 0.31
    and 0.33 (Corporate 2 0.29, Dead Zone 1 0.37), two wider gaps, one cyborg in a charge's path, doodads 0.7, half
    the ceilings narrow, Corporate's credit settings; seeds 801 and 802 (701 and 702 until the Casino took them).

**The Beach joins the campaign** (from D10c; the owner, October 9, 2026: "put the beach between the corporate and dead zone. Keep in mind that there will be a boss battle for the beach, but it has not yet been created. Do not worry about any new enemies at this time. Create level names that fit the theme."; GDD §5, §6 and §10; `data/campaign/campaign.tres`, `data/zones/beach.tres`, `data/levels/beach_1.tres` (Tiki Tides) and `beach_2.tres` (Sunset Strip); play `--level=beach/1`)
569. **Off the curve, or the curve re-spread over 19 levels?** (GDD §6: each level slightly harder than the last; the
    owner, October 9, 2026: no level gets easier when levels are added.) Placeholder: both Beach levels are off the
    campaign's difficulty curve (`LevelConfig.off_curve`, `Campaign.configure`): the curve (task K4's, exponent 0.79,
    re-spread when the Casino joined) runs over the other 17 levels, which keep exactly the difficulty, enemy
    scaling, run speed, feature ages and recency they have on main (every layout byte-identical at 3, 5 and 6 lanes),
    and the Beach plays at its own numbers, so no level gets easier. Should the curve be re-spread over all 19 later,
    as it was for the Casino (every level from City 2 on would move, the later ones harder)?
570. **The Beach's own difficulty and enemy scaling.** Placeholder: difficulty 0.71 and 0.72, enemy scaling 0.71 and
    0.73, strictly between Corporate 2's (0.695, 0.6875) and Dead Zone 1's (0.737, 0.75) on main's curve, rising
    (they were 0.63-0.69 against the 15-level curve before the Casino); a harder tier adds its bonus as for any
    level. The right feel for a remix between the two?
571. **Feature ages and recency** (the recency curve). Placeholder: the Beach's levels count every level before
    them, so their newest things (the Tithe Collector and the Enforcer Truck) get the most picks; the levels after
    the Beach count only the levels on the curve, so the Dead Zone's and the Golden Zone's picks are unchanged.
572. **The completion bonus.** Placeholder: the Beach's levels share Corporate 2's place on the curve
    (`CampaignStep.level_index`), so they pay Corporate 2's bonus (325), and the later zones' bonuses are unchanged.
    `level_index` is now a place on the curve, not a play order. Should the Beach pay more, as levels 13 and 14 in play order?
573. **The economy with two more levels.** A clean run now banks about 1,650 more credits before the Dead Zone, so
    the Heavy missile becomes affordable at Dead Zone 1 instead of Golden 1. Rebalance in R7?
574. **Continue for a save from before the Beach.** Placeholder (the existing rule, unchanged): a save that had
    reached the Dead Zone keeps everything it had open, and its Continue offers the Beach's intro, the first step
    it hasn't done. Should it carry on where it was instead?
578. **The zone's line and speed.** Placeholder: the tagline "Bamboo tiki bars and surf shops on a sandy lane down to
    the sea." and 23.8 m/s, between Corporate's 23.4 and the Dead Zone's 24.2.

**The Beach: from the review before merge** (task D10c's review, October 9, 2026)
580. **The hover truck's roof route on an open wall** (GDD §9.3). Its route (b) onto the roof runs along the wall, so
    it isn't there wherever that wall is open; route (a), the ramp, is kept (a ramp's wall run always stands). With
    the Beach's walls standing on about half of a level, route (b) is missing more often there. Fine, or should a
    hover truck's stretch keep its wall?
581. **Wall ends near a pool.** With the Beach's open walls, a wall run ends often: 0–4 of the 16–24 wall ends in a
    build have a pool in the outer lane within 15 m of them, so a runner dropping off there must jump at once. That
    follows the existing rule (the outer lane beside a wall gap is deliberately not kept clear: players read gaps
    coming). Keep it, or keep a landing clear after a wall end in the Beach?
582. **Turquoise doors at the pads' hue.** Some painted doors and shutters in the Beach's wall-run band are a muted
    turquoise at the anti-grav pads' hue (180°). They're unlit and far less saturated, so within the colour rule.
    Fine, or shift them toward teal-green or sea blue?
583. **The Bad Dream's escape rule ignores wall gaps** (`BadDream._escape_open`, `scripts/enemies/bad_dream.gd`). It
    has the same blind spot the hover truck's had (fixed in D10c's review): it counts the wall beside a player as a
    way out even where a side wall gap leaves no wall, and a move onto the wall there is refused. It can't happen in
    the Beach (no hosts), and on main's levels only where a rare short gap meets a Bad Dream's chase. Placeholder:
    unchanged. Fix it in a follow-up task?
584. **The Beach's cyborgs and the Casino's** (task D10d, after main's Casino zone joined). The Beach wears the Casino
    Mob Enforcer (`&"casino"`, item 545, chosen under the owner's "whatever fits the theme of this zone the best"),
    and the Casino zone (4) now wears it too, reusing the Marketplace's. So three zones show it. Keep it on the
    Beach (a mob running the bars and lounges; the Barnacle Turret's creature look), or switch the Beach to another
    existing look (the base Static TV Head, `&"city"`, say) so it stands apart?

**Two cyborg-type bursts in the air at once** (from H4, owner, October 8, 2026, GDD §9.2; numbers in `data/tuning/game_rules.tres`
(`max_bursts_in_air` 2) and in `data/enemies/cyborg.tres`, `window_cyborg.tres` and `barnacle_turret.tres`)
600. **The crossfire rule** (GDD §9.2: "Bolts are slow enough to dodge by switching lanes"; "Up to two bursts in the
    air at once"). With two bursts in the air, a runner could dodge the first into a lane the second then aims at
    while the first's bolts still come down the lane they left; from an edge lane of three, a wall run, beside a
    hover truck or on a narrow ceiling, the only way out was then the first burst's lane. What's built: bursts
    whose bolts arrive within `crossfire_gap` (0.5 s) of each other must leave the runner a place one move away
    that none of them aims at (a lane beside them, or the outer lane below a wall; a lane a hover truck or any
    lane blocker holds doesn't count). A burst that would leave none waits **before** its charge-up (task R3's
    rule), anticipating every place the runner could be by its lock, a wall they could step onto included; a
    burst still charging for more than `reaction_time` (0.25 s) counts as aimed where the runner is now.
    Measured (a dodging bot with a 0.25 s reaction): charge-ups called off at the lock went from 5 in 34 min to 0
    at 3 lanes, 1 in 34 min at 5; the share of bursts flown alongside another stayed 14% (3 lanes), 12–13%
    (5 lanes), 20–22% in dense levels. Cost: on three lanes a later second burst waits while the runner is in the
    middle lane or in an outer lane beside a usable wall. Are this rule and these numbers right? Should a wall
    count as a way out from an outer lane (it doesn't: the rule doesn't judge a wall's own hazards), or a lane
    two moves away?
    - Placeholder: `DESIGN-TBD` in `scripts/enemies/cyborg_gun.gd` (`_crossfire_fair`), `crossfire_gap` 0.5 s and
    `reaction_time` 0.25 s in the three enemy files.
601. **Wild fire next to another burst.** A panic cyborg's bolts land anywhere around the runner, so no lane is sure
    to be free of them. Placeholder: a wild burst's bolts never arrive within `crossfire_gap` of another burst's,
    either way round. Should a panic cyborg's spray be allowed to overlap an aimed burst?
602. **The last-resort call-off.** When two charge-ups begin within `reaction_time` of each other and the runner
    moves between their locks, the later one can still be called off at the end of its charge-up (glow and sound,
    no bolts); measured once in 34 min at 5 lanes, never at 3. Should it instead hold its charge until it can fire
    (a longer warning)?
603. **What "in the air" counts.** As before, a burst holds its place from the start of its charge-up until
    `burst_gap` (0.5 s) after its last bolt is fired, not until its bolts land, so a third burst's charge-up may
    start while the first two's bolts are still flying (the crossfire rule still keeps arrivals apart). Should the
    limit count bolts until they land?

**The Gilded Sentinels' shorter warning and lit niches** (from H1, owner, October 8, 2026, GDD §9.11; numbers in
`data/enemies/gilded_sentinel.tres`)
604. **The live statue moved only about 4 cm; most of the gain is lighting and a wider opening.** It can't stand out
    of the wall: a wall runner's body lies along the face and its solid body is behind it (GDD §3), so a statue
    proud of the wall would block the wall run, a design change for the owner. Its front is now 0.02 m behind the
    face (it was 0.063 m), the niche is shallower (0.78 m, from 0.9) and wider (1.8 m, from 1.4), and its inside
    is lit. On 3 lanes, where the camera is closest to the wall, the statue reads from about 10–15 m. Is that
    enough, or should the opening be wider still (decorative alcoves are 2.0 m)?
    - Placeholder: `niche_width` 1.8, `niche_depth` 0.78, `statue_inset` 0.02 (`DESIGN-TBD`).
605. **Every statue niche is lit alike; the live one is told by its eyes and its warning.** The owner's earlier
    request (decorative statues at the bottom of the walls so a live one can surprise the player) rules out a
    niche that sets the live one apart, so decorative alcoves outdoors and in the Palace get the same warm bronze
    inside (non-glowing, no hazard hues). The live statue's red eyes glow a little more at rest (1.6, from 0.9);
    at its warning the eyes flare, the niche tints dark red and stone grinds. Is a lit alcove right for all of
    them, and is the eye glow at rest enough to tell the live one at a glance, or too much?
    - Placeholder: `GoldenStatue.LIT_BACK`, `LIT_SIDES`, `LIT_CEILING`, `GildedSentinel.EYES_IDLE` (`DESIGN-TBD`).
606. **What 0.6 s does to the wall dodges.** On the floor, a lane change started after a 0.35 s reaction is still in
    time (tested at 3 and 6 lanes, 18 and 25 m/s). On the wall, passing above or below the swing by timing the
    wall entry must now be planned from the statue at rest: the jump onto the wall that runs above the band takes
    the whole 0.6 s. A runner who stepped onto the wall 0–0.55 s before the warning sees no warning before the
    cut but escapes with two moves (off the wall, then a lane change) started within 0.50 s. Is that the wall dodge
    the owner wants, or should the warning start earlier along the wall approach?

**The Resonator's new warning sound** (from H2, owner, October 8, 2026, GDD §9.10; `tools/asset_gen/sfx_bank_resonator.gd`,
`resonator_warning` at -5.0 dB in `data/audio/sfx_library.tres`)
609. **Should the Resonator's death sound lose its bell tones too?** The request named only the attack sound, so
    `resonator_death` is unchanged: it still bends the old chime's three tuned tones (G5, C6, E6, `DEATH_TONES_HZ`)
    out of tune under the glass and a small explosion. Should those tones go, leaving the glass, metal and
    explosion?
610. **A Resonator shot down in its warning cuts the warning's sound.** The warning builds to a wave crash at the
    instant the wave leaves, so a Resonator shot mid-warning (no wave) would otherwise crash after its own death
    sound, a warning for an attack that never comes. Placeholder: `Resonator._on_defeated` stops it
    (`PlayerSfx.stop()`, `DESIGN-TBD`). Right, or let the crash play out?
611. **The first-encounter hint** (`data/hints/hints.json`, `resonator`): "When the Resonator's halos line up and its
    fire roars and crashes, a red wave rolls along the floor. Jump it ({jump}), or be on a wall or the ceiling."
    Right wording?
612. **Warnings under slow time** (PC only). Slow time halves `Engine.time_scale`, but sound effects play at normal
    speed, so the warning's crash can land up to 1.3 s before the wave actually leaves. Every warning sound behaves
    this way (still heard before the attack, never after); the crash-on-release design just makes it audible.
    Should sound effects follow slow time, or is this acceptable?

**Explosions as yellow-and-red fireballs** (from H6, owner, October 8, 2026, GDD §11; `scripts/run/fireball_pool.gd`, tunables in
`SpeedFxTuning`'s "Explosions" group, F6 "Speed effects")
613. **An exception to "only hazards glow in hazard colours"?** A yellow-and-red fireball glows red and orange. The
    placeholder keeps it a look and keeps it short: no collision, no light, about a second of fire (longer for a
    boss), embers, then dark non-glowing smoke; it fades as the camera nears it, so a runner passing through one
    never loses sight of the lanes. The bombs' fireballs (Floating Head, The House) are sized to their blast and gone
    when it is. Is the fireball the one explicit exception, or should explosions of things that aren't hazards
    themselves (the player's missiles, a destroyed generator) look cooler?
614. **The player's missiles: fireballs too?** GDD §11 lists "missiles", while the weapon section keeps the player's
    fire cool (cyan, white, violet). Placeholder: the heavy missile's blast is a fireball inside the cyan splash ring
    (`WeaponFx.HEAVY_FIRE_SIZE` 2.2) and a plain missile's hit a small quick one (`MISSILE_FIRE_SIZE` 0.9); lasers
    stay cool. Both missiles, or only the heavy one?
615. **Which other events count as explosions?** Beyond the owner's list, the build also made fireballs of the hover
    truck bursting through the wall, the drone's first hit, the Floating Head's tower landing on the ship, and
    Hostile Takeover's five rolling blasts. Not changed: the Sleep Taker's wisps, the Sewer Swarm, plain deaths.
    Keep these?
616. **How big and how long?** Each explosion's size is a constant in its script (a drone's crash 2.4 m radius, a truck
    3.8, a boss 7–11); counts, lengths and brightness are in the "Explosions" group, and `fireball_scale` moves every
    size at once (`DESIGN-TBD`). With Reduced flashing they rise softly to 45% of the normal brightness. Placeholders
    until the owner has played them.

**The Sleep Taker's October 8 changes** (from H9, owner, October 8, 2026, GDD §10; numbers in `data/bosses/dead_zone_boss_tuning.tres`
(`SleepTakerTuning`, F6 in the fight) and `data/bosses/dead_zone_boss_wall_gaps.tres`, marked `DESIGN-TBD` in
`scripts/bosses/sleep_taker/sleep_taker_tuning.gd`)
617. **How dark lights out goes on the web / low-end renderer.** `dark_level` 0.225 (half the first build's 0.45)
    for ambient and sky light, fog light, the sun and the scenery's own light, above floors of its own
    (`light_floor` 0.2, `scenery_floor` 0.15; other bosses keep 0.3). Measured: the street goes from 50 to 32 (of
    255) at the darkest on both renderers; glows hold (generator 218 → 217, pad 182 → 181, mist 106 → 105). On
    Compatibility the walls go nearly black (6, was 15), though the street, bridges, wall gaps' orange edges and
    every glow stay readable. Too dark there?
618. **The slash's lane marks in lights out.** They blend over the street, so they'd dim with it (62 → 52); the
    merge made them draw stronger as the light falls (`SleepTakerSlash.MARKS_DARK_BOOST` 1.4, toward 1 as the light
    returns), so they stay as visible as before. Right?
619. **The hands' rounds.** A round has 2 rows, then one more each round up to 4 (`hand_rows_first`, `hand_rows_max`),
    kept across phases, 0.85 s of run apart (`hand_row_seconds`, divided by the phase's pace); each row leaves one
    floor lane open (`hand_row_open`), one lane over from the last, and puts a hand in every other floor lane whose
    floor is clear, so every row is a lane switch. Should wider streets leave two lanes open? Are four rows and
    these gaps right?
620. **All of a round's mists at once,** with one whisper per round and a burst sound per row as it rises. Far rows'
    mists can blend into the nightmare's purple base until the runner is closer (each row still shows at least as
    early as the first row's). Should the rows' mists appear one after another instead?
621. **Wall hands.** From the first round, one wall hand on every row, alternating walls (`wall_hands_per_row`), never
    beside a door in an outer lane, never at a wall gap, and only over an outer lane that has its own floor hand,
    so no floor runner passes under one. Right?
624. **How many wall gaps.** 1.6 to 1.3 s of run between gaps, 30% on both walls, 0.6–1.1 s long: about 15 a minute (a
    level's median is 1.7). Both walls stay whole from each refuge's slash warning to the end of its bridge (±0.5 s).
    Is that frequency right, and should the walls stay whole there?

**The Tithe Collector staying twice as long** (from H10, owner, October 8, 2026, GDD §9.12; `data/enemies/tithe_collector.tres`)
626. **Should Hostile Takeover's Tithe Collector stay twice as long too?** A level's Collector now closes in at 3.5 m/s
    instead of 7 (about 10.9 s on screen untouched, was 5.4 s, at every run speed; it sucks up about 2.4× the credits
    in a dense lane). On the boss's 130 m flatcar roof that carries it past the roof's end, over the coupling gap the
    runner jumps. Placeholder: the Board spawns its Collectors at `HostileTakeoverTuning.tithe_approach_speed` 7 m/s
    (`DESIGN-TBD`), so the fight is as before. A longer stay there needs a longer roof or a Collector that starts
    further back.
627. **May two Tithe Collectors be in the level at once?** Nothing reserves a window for one (touching it is never a
    hit). With the longer stay, two overlap when their patterns are closer than about 255 m at 23.4 m/s (Corporate 2
    at 6 lanes has gaps of 70, 98 and 160 m between its seven); they overlapped before too, less often. Placeholder:
    allowed. At most one at a time would need a reserved window of `stay_seconds()` after each one.

**Weapons hit hosts** (from H8, owner, October 8, 2026, GDD §9.7)
628. **The score for a weapon kill of a host.** GDD §9.7 says a stomp, claws or the dash still earn the big host bonus;
    it doesn't say what a weapon kill earns. Placeholder: a weapon kill (direct hit or heavy-missile splash) pays an
    ordinary cyborg kill (200) and no host bonus (`CyborgTuning.weapon_host_bonus` 0, `DESIGN-TBD`); a stomp, claws or
    the dash still pay 1,500 on top. Should a weapon kill earn a smaller host bonus, or nothing?
629. **Should an Octodog's lunge or a Buzz Overdrive's charge kill a host?** A charge is no weapon, so hosts stay out of
    a charge's reach as before (`Enemy.charge_can_hurt`, `DESIGN-TBD`). A charge killing a host would release a Bad
    Dream nobody chose to release. Wanted?
630. **Where a chase begins after a weapon kill: the lurk.** Weapons kill hosts 0.6–1.5 s of run before the runner
    reaches them (tiers 2–4; tier 1 never does). Released there, a chase began up to 37 m early: inside a wall fence's
    drop window the generator keeps off chases in 12 of 45 runs, with up to 10.17 s without a pad (the guarantee is
    10 s). Placeholder (`DESIGN-TBD` in `scripts/enemies/bad_dream.gd`): a Bad Dream bursting out further ahead than
    its hover spot (7.5 m) rises out of its host as usual, then **lurks** over that spot, harmless, maw closed and dim,
    holding no other attack back, until the runner is within 7.5 m; then its chase begins exactly as for a stomped
    host. Measured: chases begin at most 14 m before the host's spot (a stomp: up to 9 m), with the same pads as a
    stomp's, nothing kept off chases met, no fizzle or overlap. An EMP dissolves a lurking one where it hangs. Is the
    lurk right, or should the chase start at the kill?
631. **Laser tier 1 hardly ever kills a host** (7 shots, 42 m range: about 2 s before the runner arrives; in the
    measured runs it never did). The cost of carrying the weapon into host levels is real from tier 2 on (missiles
    reach 70 m). As intended, or should tier 1 reach hosts too?
632. **The first-encounter hint** (`data/hints/hints.json`, `host`). Placeholder: "Glitching cyborgs carry something
    worse, and killing one sets it loose. Your weapon fires at them too: switch it off in the shop to leave them be."
    (was "... Think before you stomp one.") Right wording?
633. **Follow-up for a later core generator task: plan the chase keep-outs from where a chase can begin.** The
    generator keeps things off each chase from its host's spot (`host_rules.gd`, `BadDreamTuning.chase_stretch`), but a
    chase can begin up to about 15.5 m earlier after a weapon release (the host's walk toward the runner plus the
    hover spot), about 9 m after a stomp. On the campaign's own seeds nothing kept off chases lies there
    (`test_host_releases`), but on another seed (Dead Zone 1, 3 lanes, seed 9001, which endless-style random seeds
    could hit) a chase began inside a wall fence's drop window; its first claws came well after, so nothing could hit
    the runner. Proposed: start the keep-outs at the host's spot less (`walk_max` + `hover_ahead`), or add seeds that
    aren't the levels' own to the layout check.

**The dash smashes doodads** (from H5, owner, October 8, 2026, GDD §3; numbers in `SpeedFxTuning`'s "Doodad smashes" group, F6 "Speed effects")
634. **What a smash looks and sounds like.** The doodad vanishes as the runner reaches it and 10–28 solid pieces (by its
    size) fly out in its look's own colours, carry on along the runner's way, tumble and shrink away within 0.9 s, with
    a light shake (0.1) and a crunch (crack, thump, crumbling, clatter; `doodad_smash`, -5 dB). No fireball, flash or
    hit-stop; the pieces never glow. More or bigger pieces, a dust cloud, a zone-specific sound?
635. **A dashing switch into a doodad's side** isn't blocked: it breaks where the body meets it, no clank or bump. Other
    solid sides (a hover truck's, a boss prop) still bump a dashing player. Or should only a head-on dash smash?
    (`Player._lane_blocked(target, dash_through)`, `DESIGN-TBD`.)
636. **A dash that ends just short of a doodad.** It smashes only if the dash lasts until the body gets there (counting a
    fading speed boost); otherwise the doodad pushes as usual, so the body never sinks into it. A reached doodad still
    breaks up to 0.1 s after the dash's last frame (`Player.SMASH_CLAIM_GRACE`, `DESIGN-TBD`). Or should any doodad touched
    within a fixed time after the dash be smashed?
637. **No score for a smash.** A doodad is scenery and the dash is the reward (`Player._smash`, `DESIGN-TBD`). A small bonus
    would make smashing something to chase. Wanted?
638. **Attacks near a smashed doodad.** Enemies that hold an attack while a doodad stands where it would land (a drone's
    barrage, a hover truck's cannon, an Octodog charge, a Resonator pulse, cyborg bolts) read the level's plan, so after
    a smash they still hold off along that stretch; every attempt plays the same, and the attack only waits a moment
    longer. Or let them attack once it's gone? (`DashBreakable`, `DESIGN-TBD`.)
639. **Telling the player.** Nothing new tells the player the dash smashes doodads (the shop's dash text already says
    "Barrel through enemies and obstacles"; no first-encounter hint). A hint the first time a runner carrying the dash
    meets a doodad, or a line in the shop?
640. **A dash started during a doodad's push** doesn't smash that doodad: the push completes and the doodad stands. If the
    player then steers back into it with the dash on, the dash takes it where the body meets it. Or should a dash during
    the push smash it at once? (`Player._check_doodads`, `DESIGN-TBD`.)
    - Measured, not a question: over every campaign level at 3, 5 and 6 lanes (270 doodads), the next thing after a
    doodad comes at least 0.72 s after its front at the dash's speed (0.68 s after its end); a reaction plus a lane switch
    takes 0.49 s, so the generator is unchanged.

**Buzz Overdrive cuts show the zone below the street** (from H3, owner, October 8, 2026, GDD §9.9; levers in each zone skin's data)
641. **How bright may the scenery below the street be?** Cuts in every zone now show what that zone's gaps show (the City's
    road and traffic, Gangland's crater strata, the Marketplace's stalls). Where the Buzz Overdrive appears, the planes
    below were drawn almost black, so they are now dimly recognisable through gaps and cuts alike, in steady albedo
    patterns (nothing glows below the street but the orange edges; no hazard hues):
    - Golden Zone: a stone quay of arches over moving canal water (ripples, a sheen of the sky, the lamps' reflections).
    - Golden Palace: a stairwell over a lower hall of marble with a soft pool of light; the well's walls drawn both sides.
    - Corporate: a carriage side with dim windows, guideway beams over a wet concrete trench; the plaza's lower level
      now 9 m down (was 18 m). Hostile Takeover's arena inherits this look.
    - Dead Zone: broken road layers, ruined basements (window slots, formwork, a pipe run), a rubble floor with ash, all greys.
    A hole stays clearly darker than the street: `SkinSuite.hole_share()` holds the brightest thing below the street, as
    rendered, to at most 0.8 of the darkest street (`HOLE_SHARE_MAX`; Corporate 0.70, Golden 0.72, Dead Zone 0.75, Palace
    0.22). The Compatibility renderer drew holes near-black, so it lifts below-street patterns there only
    (`UNDER_COMPAT_GAMMA` 0.85) to match Forward+. From the runner's camera the result is "dim but recognisable"; the Dead
    Zone gains mostly structure, not brightness. Is that the right level, or brighter (a hole risks reading as floor
    from afar) or dimmer? Levers: `gap_inside_color`, `void_floor_color`, `canal_color`, `canal_sky_color`,
    `canal_lamp_color`, `well_floor_color`, `guideway_color`, `trench_color`, `HOLE_SHARE_MAX` (`DESIGN-TBD`).
642. **A cut's far end in the City** is a plain dark face as tall as a truck (2.6 m) with the road far below; a City gap's
    far side is the next truck's cab with lights, which would glow in hazard colours meaning something else at a cut.
    Keep the plain face, or should it read as a truck's rear or front? (`CitySkin.floor_cut`, `DESIGN-TBD`.)
643. **Gangland's cut end faces** are at half the earth's brightness (`GanglandSkin.CUT_STRATA_SHADE`, `DESIGN-TBD`) so a
    cut's inside stays under the floor-cut suite's dark limit; the holes' side walls are at full brightness. Fine?

**Dash walls, the mechanism** (from H7a, owner, October 8, 2026, GDD §9.14; numbers in `data/tuning/dash_walls.tres`, `MovementTuning` and
`SpeedFxTuning` "Dash walls", `LevelConfig.dash_walls`)
644. **How many a level** (GDD §9.14 gives none; the brief: 2–4, rising). Placeholder: `LevelConfig.dash_walls`:
    Corporate 1 2, Corporate 2 1, Dead Zone 1 3, Dead Zone 2 (The Hush) 1, Golden 1 2, Golden 2 4, Golden 3 2 (0 to
    8 in the F6 "Level pacing" section). The generator places up to that many, and every campaign level gets its
    full count on its own seed at 3, 5 and 6 lanes, so each level asks for no more than its track holds on its
    most crowded lane count. Several fall short of the brief's 2 to 4:
    - Corporate 2 holds one on 5 lanes once its Tithe Collectors count as dash baits (below);
    - The Hush holds one: its walls keep out of its quiet stretches (below), and only one fits in its short bursts;
    - Golden 1 and Golden 3 hold two (the walls past an introduction take the room the other passes leave, below).
    *(Since the merge with tasks C6c–C6d, October 9, 2026: the walls keep off the Enforcer Truck's showing windows,
    which take the only room for Golden 1's second wall on 5 lanes and Golden 2's fourth on 6, so Golden 1 now asks
    for one and Golden 2 for three.)*
    Endless mode and quick play keep their base level's count, however long the level. How many should each level
    have, and should endless mode scale them with its length? Should a level that holds fewer than asked loosen a
    rule (for example let a wall stand in a quiet stretch) to reach the count?
645. **Where Corporate 1 introduces them** (GDD §9.14, proposed: "Corporate 1, after the Buzz Overdrive's
    introduction"). Placeholder: `feature_starts["dash_wall"] = 0.42` in `data/levels/corporate_1.tres` (the Buzz
    Overdrive's is 0.1, the partial wall fences' 0.5). The introduction stands at the first fair spot from its start;
    where none comes within `DashWallTuning.intro_window_seconds` (10 s) it makes room by taking out a few enemies
    that block it (a Buzz Overdrive with its cut, a fence generator, a cyborg, a window cyborg or a screech; never the
    last of a feature nor any feature's first; `dash_wall_rules.gd`, `_make_room`). Corporate 1 is crowded (every new
    enemy of the zone is in it), so its own seed only lands every lane count's introduction on time from about 0.35
    on. Is 0.42 the right moment, and is taking an enemy out for the introduction acceptable?
646. **The spacing and what counts as "needing the dash"** (GDD §9.14, proposed: "nothing else that needs the dash
    comes just before one"). Placeholder (`data/tuning/dash_walls.tres`): faces at least the dash's longest cooldown
    (8 s at tier 1) plus `cooldown_margin_seconds` (1 s) of run apart, plus the ground a dash covers; and within that
    same spacing before a face no Buzz Overdrive charge meets the runner (a panic dash smashes it), no fence
    generator stands (its hint says to dash through it) and no Tithe Collector's stay ends (its hint says to catch it
    by stomping, shooting or dashing through it; the end of its stay is the latest a dash can catch it);
    `keep_dash_baits` turns that off. A zone doodad isn't treated as one: it never needs the dash (it only pushes
    the runner aside, and no hint sends the dash at it), and keeping doodads off the whole spacing before every wall
    left Golden 2 on 5 lanes with none. Should "just before" be the whole cooldown, and are the fence generator and
    the Tithe Collector baits?
647. **Is the dash ready at a wall?** The spacing only guarantees it when the dash was last used at the previous wall.
    Faces are 9 s of run plus 4.8 m apart against an 8 s cooldown: about 1 s of slack, and every speed boost on the
    way (a speed pad, another dash) takes about 0.19 s of it. A dash spent in between on something that isn't a
    bait (a zone doodad smashed, which task H5 encourages; an enemy killed; a panic dash) can leave it recharging at
    the wall, and the runner can't plan for it: a wall is built only 180 to 220 m ahead (7.2 to 9.4 s), and the
    Dead Zone's fog ends at 150 m (about 6 s). Placeholder: accepted (GDD §9.14 allows it: on cooldown, the runner
    crashes, which the armor or the shield absorbs). Options: accept it; count more things as baits (the doodads,
    any enemy the dash kills); or show a cue when a wall is near while the dash recharges. Which?
648. **The clear stretch around a wall** (GDD §9.14 gives none; the brief: a reaction and a lane switch at dash
    speed). Placeholder: `approach_seconds` and `after_seconds` 0.6 s at the dash's speed before the face and past the
    back, in every lane: no hole, floor cut's window, fence, doodad, speed pad, pad's zone, ramp or its wall run,
    ceiling or landing zone, and no enemy's attack. Plain holes, fences and signs there are taken out to make room
    (`clear_plain_pieces`). A panic cyborg's run stops short of a wall's approach (it never runs through a standing
    wall nor cowers right behind it), and an Octodog or a Buzz Overdrive running off ahead of the runner leaves play
    at a standing wall's face rather than driving through the building.
649. **The Hush's quiet stretches** (GDD §5: "long silent stretches broken by sudden threats"). Placeholder: walls keep
    out of them, as the fill pass and the danger density pass do, unless that leaves the level with none (then one
    stands in a quiet stretch). The Hush's bursts hold one wall, so it gets one. Should a wall be allowed in a quiet
    stretch (it's a building, not an enemy), and should The Hush have more?
650. **Pressing: where the walls stand in the level's build, and the danger density request**
    (`docs/USER_REQUESTS.md`: about 35% more enemies and obstacles by the final levels, which `test_danger_density`
    holds at 30% to 40%; its final levels on 3 lanes sit at ×1.303 against the floor of 1.30, before and after the
    walls, so any later feature that takes room before the danger density pass will push them under). Placeholder:
    only the introduction stands with the enemy rules; the rest stand after the danger density pass and the zone
    doodads, in the room those passes and the fill pass left, taking out plain holes and fences in their way.
    Standing them earlier (before those passes) took the stretches the passes add enemies and rows in: the final
    levels on 3 lanes then came out about 28% denser instead of 30% (the sample was at 30.3% before the walls), and
    any wall at all, even one a level, pushed them under; and it took a crowded level's few doodad stretches (Golden 1
    lost all its doodads on 5 and 6 lanes). So the walls now cost a few plain pieces where they stand (4 to 12 a level
    for 3 or 4 walls in the suite's sample; the final levels on 3 lanes stay 30.3% and 31.2% denser) rather than the
    level losing the danger the owner asked for, and in a crowded level the
    walls get fewer fair spots (where a level ends up with none, one makes room by taking out an enemy, as the
    introduction may). Is that the right trade, or should the walls count toward the requested danger (each is a
    hit across every lane)?
652. **A wall runner passing it** (GDD §9.14). Placeholder: the wall crumbles as the wall runner's front reaches its
    face (so it never stands between the chase camera and them), with the same crumble and sound as a smash, costing
    nothing (`Player._check_dash_walls`, broken by `pass`). Should it stay standing behind a wall runner instead?
653. **No score for breaking one** (GDD §9.14 says nothing). Placeholder: a smash, a crash or a pass scores nothing and
    isn't a kill. Should a dash through one pay something?
656. **Flyers ahead of the runner** (the heli drone, the Resonator, a fleeing Tithe Collector). Placeholder: each rises
    over a standing wall in its way, 1.2 m over its top at 7 m/s, and comes back down past it (`Enemy.dash_wall_lift`);
    the drone holds its barrage while a wall is within its reach or its climb, and the Resonator's pulses wait for
    floor clear of walls. The generator keeps walls off a drone's wave no more (its barrage holds), off a floor
    cyborg's obstacle margin only and off a planned Resonator's pulses only (as the wider gaps do), and off a Tithe
    Collector's whole stay. Should they rise over it, or should the walls keep off them?
658. **The crumble and the sound** (GDD §9.14: "they will crumble and explode into rubble"). Placeholder
    (`SpeedFxTuning`, "Dash walls"): up to 64 lit pieces in the wall's colours flung out of the lanes and up, a cloud of
    see-through dust out of its lower face that fades as the camera nears it, a shake heavier than a doodad's (0.26),
    and `dash_wall_smash.wav` (a heavy crack and thump over a slab's boom, the crumble's roar closing down, masonry
    thudding down after it). Nothing flashes or glows.
659. **The first-encounter hint** (`data/hints/hints.json`, `dash_wall`): "A building blocks the street: dash through
    it ({dash})! Without the dash you crash into it: that costs your armor or your shield, and kills you if you have
    neither. A run along a side wall passes it too." Is the wording right?

**Dash walls, the art** (from H7b, owner, October 8, 2026, GDD §9.14; each zone's `*_dash_wall.gd` and `scripts/world/skins/dash_wall_kit.gd`)
660. **What kind of building, per zone** (the GDD gives none: only "the same building faces"). Placeholder: four layouts
    per zone, picked by the wall's seed, each a block of the zone's own facades. Corporate: a curtain-wall tower's foot
    on a steel canopy, a lobby with ribbon windows, a military compound's front (blast walls under an armoured block),
    a podium building. Dead Zone: a burnt tower's foot, a skeleton of steel and slabs, a blast with a heap of rubble, a
    charred bunker. Golden Zone: a rusticated palace under its frieze, a palace with a storey of gold-framed windows,
    a mirror-glass tower's foot, a gatehouse. Golden Palace: a marble block of moulded panels between gilded
    pilasters, one with galleries, one with arched windows, one with gold bands and a coffered frieze. City: a dark
    block in each of its four window grids. Gangland: a ruined block, one with a makeshift balcony, a shop patched with
    rusty sheets, a collapsed corner. Marketplace: a shop row (two window widths), a market hall under its glass vault,
    an arcade under a tin lean-to. Are these the right buildings, and should any zone's wall be a particular one of
    them (a Corporate wall that is always the military's, say)?
661. **How big it reads.** The box is the H7a placeholder (9 m tall, 2.5 m deep, 5.4, 10.2 and 12.6 m wide at 3, 5 and 6 lanes): next to the walls'
    towers (40 to 170 m) it reads as a low block, a podium or a three-storey building, never a tower, however it is
    dressed. The looks are tuned to that box (their storeys, bays and bands are laid out for 9 m; only the roof line and
    the roof plant follow `size.y`), so a different `MovementTuning.dash_wall_height` keeps the box filled but would
    want the proportions looked at again (the Golden zones' frieze and the Golden Palace's panels most). Should it be
    taller (about 12 m would stand clear of the side walls' calm band and read as a building at a distance)?
662. **No cue in the dash's colour.** The brief welcomes "a breakable or cracked hint"; I used cracks spreading from a
    few points, a chipped patch with rebar showing (not in the two Golden zones, whose stone stays clean) and, on the
    ruins, broken tops and rubble at the foot, all in the zone's own unlit colours. A glowing cue (a seam of `PlayerSuit.GLOW_PALE` along a crack, say) would be the one
    thing on the wall that glows, and the hook's contract (and its test) is that nothing does, so I left it out.
    Should the cracks glow faintly in the dash's colour, so the wall reads as "breaks to the dash" before it's close?
663. **Dark windows even in the lit zones.** Every vertex's lit-window share is 0, so a wall's windows are dark glass
    and its neon (the City's) is dead paint: in the City and Corporate it is the one dark block among lit towers, and it
    reads as solid for that. Allowed lit windows would make it match the towers more and need the hook's "never
    glowing" rule (`test_dash_walls`, `_test_skins`) loosened to "no glowing hazard colour". Wanted?
664. **Dark openings at the foot.** Corporate's lobby look has smoked glass in steel frames down to the floor under a
    canopy, and the Golden Palace's galleries and arched windows are dark (a warm umber with the far floor a shade
    lighter, never black): none is at a runner's height except the lobby's glass, which has a mullion every 3 m and a
    dark brand-paint band above it. Does a dark lobby read as passable? If so it can be cladding like the other
    podium looks.
665. **No people, signs or screens.** The Marketplace's shop windows show their displays of goods and nothing else (no
    citizens: they play behind the walls' windows), Corporate has no banner or brand sign, the Golden zones no statue
    (a statue is a Gilded Sentinel's silhouette) or tapestry (red), the Dead Zone no billboard, Gangland no laundry or
    ad, the City no neon sign or screen. Right?
666. **The look picks.** The seed's remainder by 4 picks the layout and the quotient by 4, remainder by 3, the tone (`DashWallKit.look_of`,
    `tone_of`), so a level's 2 to 4 walls, whose seeds come from the level's seed, can repeat a layout. Should the
    walls of one level be forced to differ?
668. **The ruins' broken tops** (the Dead Zone, Gangland): they stand lower in places, down to 6.3 m (Dead Zone,
    `DeadDashWall.TOP_MIN`) and 6.2 m (Gangland, `GanglandDashWall.TOP_MIN`), up to 2.8 m under the box's top, where
    the hitbox reaches higher than the look. A wall jump's feet reach about 5.3 m (`MovementTuning`), so a wall is
    never drawn lower than 5.8 m across the floor lanes (`test_dash_walls` measures every look's silhouette from its
    mesh): what looks open above it is out of reach of a jump, and only a flyer gets over. Is leaving the top 2.8 m
    of a ruin's hitbox over open air acceptable, or should a ruin's top stay nearer the box's?

**Merging main into the H series** (October 9, 2026: the Enforcer Truck's C6b–C6d and the City outro meet H6's fireball and H7a's dash walls)
669. **The Enforcer Truck's blast is now the shared fireball** (GDD §9.13 "Its end is a visible explosion", §11
    "Explosions"). Task C6b gave the truck an explosion of its own (swelling puffs, a white-hot core, dark smoke and an
    orange glow on the floor), and task H6 made every explosion in the game the one shared yellow-and-red fireball
    (the owner, October 8, 2026). The merge keeps C6b's wreck exactly (it lurches into view, blows up 2.8 m behind
    the runner, falls back at 0.5 m/s, gone after 0.9 s) and draws its blast through the shared fireball.
    Placeholder (`EnforcerTruck._explode`, `FIRE_SPREAD`, `FIRE_SPREAD_IN_LANE`; sizes and times in
    `data/enemies/enforcer_truck.tres`, group "Wreck"): C6b's sizes (`blast_radius` 1.3 m, `blast_radius_in_lane`
    0.85 m), its fire burning `blast_seconds`, held in (0.7 of a free fireball's spread, 0.5 in the runner's lane),
    **no smoke** (everything it draws only adds light, so it can't hide the runner, as C6b required), carried along
    with the wreck. C6b's floor glow and smoke are gone. Should it keep smoke beside the runner, or be as big as the
    other trucks' explosions (3.6 to 3.8 m)?
670. **The City outro's explosions** (GDD §6 Cinematics, §11). Placeholder: the roadblock's blast is now the shared
    fireball (2.0 m, its fire about 1.3 s, with smoke; softened by Reduced flashing), from a one-slot pool of the
    outro's own (`CityOutroSet.build_blast`, `start_blast`). The Floating Head's crash in the outro keeps task F2a's
    dust and smoke with no flash, while the same crash in the fight plays three fireballs (task H6,
    `FloatingHead._crash`). Should the outro's crash play the fight's fireballs too?
671. **Dash walls and the Enforcer Truck's showings** (GDD §9.13 "Showing itself", §9.14). When it shows itself the
    truck pulls up beside the runner with its front ahead of them, before the runner has broken a wall there.
    Placeholder: the walls keep off its planned showing windows (with the rules' keep-outs, in every lane, the window
    and 1 m either side: `DashWallRules._counts`), and in play it never begins a showing whose view would reach a
    standing wall, nor stays alongside up to one (`EnforcerTruckRoom`: a wall is solid in every lane). A showing
    window so wins over a wall's spot. Right priority?
672. **Fewer walls in Golden 1 and Golden 2** (GDD §9.14; follows docs/OPEN_QUESTIONS.md item 644, how many a level).
    Kept off the showing windows, Golden 1 on 5 lanes has room for one wall on its own seed (the only other fair
    spot, 576 to 627 m, lies in its truck's window, 393 to 625 m) and Golden 2 on 6 lanes for three (its fourth
    spot, 536 to 539 m, in the window from 518 to 719 m). Following the H7a rule that a level asks for no more than
    its track holds on its most crowded lane count, placeholder: `dash_walls` 1 in `data/levels/golden_1.tres`
    (was 2) and 3 in `golden_2.tres` (was 4), so the other lane counts lose one too. Or should a level's count
    apply per lane count, or a window give way to a wall (a truck with no showing in that chase)?

**Merging main into the H series again** (October 9, 2026: C6e, PERF2, G6b, the E1g follow-up and E5d meet the H series)
673. **A showing's claim keeps off a Sentinel's turn in every mode** (GDD §9.13 "Making room where there is none",
    §9.11). C6e plans a window in its new modes only where the truck's claim on its turn (`show_claim_seconds`, 2 s
    before the window) meets no attack that can't wait for a turn (a Gilded Sentinel's turn, a hover truck's
    entrance), but its first mode (C6c/C6d's) kept them off the window alone. With H1's shorter Sentinel warning
    (0.6 s) such a window can fit right behind a Sentinel's swing with its claim beginning during the next Sentinel's
    turn; the truck's claim counts as a big attack on as the Sentinel's warning would start, so that Sentinel would
    let the runner pass for good (`test_enforcer_truck`'s Sentinel case, at 3, 5 and 6 lanes). Placeholder (the
    merge, `ShowPlanner._window`): every mode keeps the claim off them. Before main's Casino it took Golden 2's
    showing at 6 lanes on its own seed; on the campaign's builds since (K4's curve) it changes no window (the
    Enforcer levels' own seeds and two others at 3, 5 and 6 lanes: 47 windows), and Golden 2's chase at 6 lanes has
    no showing with it or without it (CLASSIC's quiet keeps its window off the Sentinels). Or should a showing's
    claim take a Sentinel's turn (that Sentinel's swing lost, the truck seen)?
674. **The Golden Convergence's explosions are now the shared fireball** (GDD §11 "Explosions", §10 The Golden
    Convergence; follows item 487). Task E5d drew its chain reaction's fire itself (`GoldenConvergenceBlast`: blended,
    saturated orange balls with dark smoke, since added light read a washed-out peach over the court's marble and
    sky), and task H6 made every explosion the one shared yellow-and-red fireball (the owner, October 8, 2026). The
    merge keeps the fight's timing, hitboxes, warnings and sounds, and draws each of its explosions through the run's
    shared pool (8 fireballs at once): the squadron's crashes into the racks (2.4 m, no smoke), one quick 2.2 m
    fireball for every five rack missiles of the ripple (E5d had one a missile), the ship's five (7 m down to 3.8 m,
    with smoke), a quick 3.0 m one every 0.2 s up the feed line (E5d: 2.6 m every 0.07 s), 4.5 m with smoke at his
    shoulder, the barrage's landings (2.0 m, quick, held in, no smoke; E5d had sparks only) and the transition's burst
    of the suit (6 m with smoke; E5d had sparks and dark dust). Fire on something pacing the runner rides along with
    it (the ship, the suit), where E5d's stayed behind in the world. Its yellow heart reads lighter over the court's
    pale sky than E5d's orange did. Placeholder: as above (`RIPPLE_GROUP` and the `*_FIRE_SIZE`, `*_FIRE_PACE`
    constants in the Golden Convergence's scripts). Keep the shared look here, or give the shared fireball a darker,
    blended variant for bright backgrounds (every zone would share it)?

**Merging main's Casino into the H series** (October 10, 2026: K1-K5, the Casino zone and K4's curve, meet the H series)
675. **Fewer dash walls in Corporate 1 and Golden 2 on the Casino's curve** (GDD §9.14; follows items 644 and 672).
    With main's Casino and K4's curve ("no level gets easier") the levels are denser: on their own seeds Corporate 1
    at 3 lanes has room for one wall (its introduction) and Golden 2 at 5 lanes for two. Following item 672's rule (a
    level asks for no more than its track holds on its most crowded lane count), placeholder: `dash_walls` 1 in
    `data/levels/corporate_1.tres` (was 2) and 2 in `golden_2.tres` (was 3), so their other lane counts lose one
    too. On the levels' own seeds at 3, 5 and 6 lanes: Corporate 1 1/1/1, Corporate 2 1/1/1, Dead Zone 1 3/3/3,
    Dead Zone 2 1/1/1, Golden 1 1/1/1, Golden 2 2/2/2, Golden 3 2/2/2 (and no wall in any of the 47 showing windows
    of their own seeds and two others). Dead Zone 1 keeps its three (before the Casino the merge had it ask two, as
    its third cost the danger density pass ten pieces on 3 lanes; with K5's wall fence share the final levels keep
    32.0% more obstacles there in `test_danger_density`'s sample either way). Or should a level's count apply per
    lane count (item 672's other way)?
676. **Corporate 1's dash wall introduction comes late at 5 lanes** (GDD §9.14, §6 "one new thing at a time"; like
    item 529's wall fences). On its own seed at 5 lanes the feature guarantee rebuilds the level (task K4: a cyborg, a
    fence generator and a vent screech missing from the first build), and its forced picks, the generator at 1371 m
    (a dash bait: nothing that invites a dash comes within the dash's cooldown before a wall) and the vent screech at
    1515 m, each the only one of its feature, with ceilings and a pad, leave the introduction's window (from 1425 m,
    10 s) no fair spot and no room to make. The introduction then stands at the first spot one fits, 1897 m, 201 m
    past the partial wall fences' introduction (1696 m); moving the feature's start (0.34 to 0.46 of the level)
    doesn't help. Placeholder: as built; `test_dash_walls`' `LATE_INTRODUCTION_LANES` (5) checks it both ways (still
    late, and no wall fits from the start up to it). Should the generator hold room for an introduction against the
    guarantee's forced picks (item 529's generator task)?
677. **The zone doodads make way for a dash wall as the last resort** (GDD §5: a feature a level has appears in it;
    §9.14). On Corporate 2 at 3 lanes on seed 7101 (one of `test_dash_walls`' sweep seeds) K4's denser curve left no
    fair spot for a wall even after making room by taking out enemies, so the level had none (a warning).
    Placeholder: as a last resort `DashWallRules.after_doodads` makes room with the zone doodads in the way going too
    (scenery, never a feature: `_make_room`'s `doodads_go`); there one doodad (2928 m, lane 1) goes and the wall
    stands at 2928 m. Only a build that would otherwise have no wall changes; `test_dash_walls`' `LAST_RESORT_CASE`
    checks it both ways. Is taking out scenery for a wall acceptable, or should such a build go without one?
678. **The Casino's dash wall and floor cut looks** (GDD §9.14, §9.9; tasks H7b and H3 with K1). The Casino's skin
    inherits the Marketplace's (`CasinoSkin` extends `MarketplaceSkin`): a shopfront dash wall in the Casino's iron
    tones (the arcade look's tin lean-to takes the palette's fifth tone wrapped, `MarketDashWall._lean_to`, as the
    Casino's palette has four to the Marketplace's six: it crashed before), and the stall roofs' floor cut. Neither is
    seen in play: the Casino's levels have no dash walls or Buzz Overdrives (they come from Corporate 1), nor has its
    endless mode (Casino 2's features). Placeholder: as inherited. Should the Casino have its own (a casino front
    across the street, its flagstones cut)?

**Merging main's Beach into the H series** (October 10, 2026: D10, the Beach as zone 6, meets the H series)
681. **A floor cut in the Beach shows its pools' water** (GDD §9.9 with task H3: a cut shows what the zone's gaps
    show; task D10: the Beach's gaps are pools, their water `pool_depth` down, 0.45 m). The Beach's cut (`BeachSand.cut`)
    has no bottom and, since the merge, no side walls of its own (the neighbouring lanes' floors carry their sides in
    the tank's steel, as at any pool), so it shows the chunk's water 0.45 m down, where H3 has every other zone's cut
    show its scenery 3 m or more below. Placeholder: as its pools; `test_floor_cuts`' `SHALLOW_BELOW` takes the Beach's
    `pool_depth` as its plane below. Should a Beach cut read as a pool (as now), or open onto something deeper?

### Folded on October 14, 2026 (tasks D10e, F2c, F2d, H11, H12 and the wall gaps)
These task files were never folded into the list; their placeholders were in the owner's playtests since.

**D10e, the volleyball match** (from `docs/questions/d10e.md`)
The owner's request (October 10, 2026) is built as the Beach's new second level, **Net Gains** (`beach/2`,
`data/levels/beach_2.tres`), a mini-game (`VolleyballMatch`, `scripts/minigames/volleyball/`; its numbers in
`data/minigames/volleyball_tuning.tres`, `VolleyballTuning`, F6 in the level). Sunset Strip moved from Beach 2 to
Beach 3 (`beach/3`, `data/levels/beach_3.tres`). What the request leaves open is a placeholder, marked `DESIGN-TBD`:

683. **The level's name** (GDD §5, level names). Placeholder: *Net Gains* (a nod to the payout), proposed like the
  Beach's other two names.
684. **How many returns win a point** ("say three or four times"). Placeholder: 3 (`returns_to_win_point`). With 3, a
  flawless 4-0 match takes about 55 s of level, the level's `duration_seconds`.
685. **What else the payout replaces** (GDD §7). Placeholder: the match's payout (100 credits a point won,
  `payout_per_point`) is paid as the level's completion bonus, instead of the usual one (Corporate 2's, which the
  Beach's other levels take), and shows on the results screen as "Match payout". The run-in's credits are paid as
  usual. A player who quits between the match's end and the finish line forfeits the payout, like a completion bonus.
686. **The level's stars and score** (GDD §6, §7). Placeholder: 1 star for finishing, 2 for winning 2 points or more,
  3 for winning the match (`two_star_points`, `three_star_points`); the level score is the run-in's credits plus
  25 a return and 150 a point won (`return_score`, `point_score`), for the leaderboards.
687. **"The first couple seconds"**. Placeholder: 2.5 s of normal run at the Beach's speed (`run_in_seconds`) with two
  short trails of credits and nothing that hurts, then 1 s slowing to a walk and 1.3 s of walking (2.6 m/s) up to
  the court's line. The side walls stand during the run-in and open 45 m before the court, to the end of the level,
  so the court stands on the open beach.
688. **The court** (GDD §5, the Beach). Placeholder: raked sand across every lane with white tapes, 4.6 m from the
  runner's line to the net and 4 m from the net to the rival's line; the net's top at 1.75 m (a man's 2.43 m net
  scaled with the 1.28 m runner), between padded posts on the kerb. It has no collision: after the match the net and
  its posts sink into the sand, and the runner runs on over where it stood. Should the runner instead jump or slide
  under the net, or run around the court?
689. **How the runner plays** (GDD §3, controls). Placeholder: the runner stays on their line; the lanes are where
  the ball can come down. A ring on the sand marks the ball's lane from the moment it's hit, and a second ring
  closing on it meets it when it's time to jump (0.35 s before the ball reaches the line). The hit counts when the
  ball reaches the runner in the air, over their lane (a box 1.7 m wide, 1.4 m tall and 1.4 m deep around their head
  and hands): a jump from about 0.6 s before the ball arrives up to the moment it arrives returns it. A runner
  standing in the ball's way without jumping takes it on the head (a miss, "JUMP TO HIT IT!"). A runner jumping
  over and over is in the air most of the time and returns most balls in their lane: is that fine?
690. **How hard the rival plays** (GDD §6: one new mechanic at a time). Placeholder: the serve flies 1.8 s and comes down
  one lane from the runner; each later ball of the rally flies 0.15 s quicker (down to 1.2 s) and may come further
  away (up to two lanes for the second, any lane for the third), now and then (15%) straight down on the runner's own
  lane. Never quicker than the runner can reach and jump: 0.5 s to react, 1.6 lane switches' time per lane, 0.35 s
  for the jump (at 6 lanes, a ball five lanes away flies at least 1.97 s). Every attempt plays the same match against
  the same moves (seeded by the level). More lanes (PC) make it harder, as everywhere.
691. **The rival** (the owner: "a new person who is wearing swim trunks"). Placeholder (`VolleyballRivalSuit`): a
  tanned, bare-chested and barefoot beach player, 1.4 m tall (the runner is 1.28 m), in ocean-blue board shorts with
  white stripes, sun-bleached hair, dark sunglasses whose thin rim glows violet (the Beach's decorative neon) and a
  small earpiece (the world's viewing devices, GDD §5: he isn't one of the cyborgs), a shell necklace, a white
  wristband. He has no name ("RIVAL" on the scoreboard). He serves every point, cheers a point he wins and puts his
  hands on his head for one he loses, dives for the winning return and misses, and after the match steps aside to
  the kerb and waves the runner on.
692. **The runner's hit** (GDD §11). Placeholder: the runner's arms reach up as the ball nears an airborne runner and
  follow through after a hit, over the jump's own pose.
693. **Sounds** (GDD §11: new sound effects are fine). Placeholder: three new ones in the game's 16-bit style
  (`tools/asset_gen/sfx_bank_minigames.gd`): `volley_hit` (each hit; the rival's tells the runner a ball is coming),
  `volley_bounce` (a ball in the sand) and `volley_whistle` (each point's end); the payout plays the thief's
  `jackpot`. The music is the Beach's stand-in track.
694. **The level's sky.** Placeholder: the zone's own daylight (Tiki Tides'), with Sunset Strip's sunset still the
  zone's last level.
695. **The level introduction's hint** (`data/hints/hints.json`, `volleyball`): it explains the ring, the closing ring
  and the jump, and that every point won pays credits, without numbers (the scoreboard shows "FIRST TO 4" and a pip
  for each return the rally needs).
696. **Old saves.** A save from before the match (version 3) that had finished Sunset Strip keeps it, as `beach/3`, and
  the new Beach 2 is open and next on Continue. The Beach's boss slot (a placeholder) still follows Sunset Strip.

**F2c, the Dead Zone's intro** (from `docs/questions/f2c.md`)
The owner's story beat (October 9, 2026) is built as `DeadZoneIntro` (`scripts/cinematics/dead_zone_intro/`) in the
Dead Zone's intro slot. What the beat leaves open is a placeholder, with its numbers in
`data/cinematics/dead_zone_intro_tuning.tres` (`DeadZoneIntroTuning`, marked `DESIGN-TBD`).

This partly answers `docs/OPEN_QUESTIONS.md` items 238 (the arrival flyovers' story beats: the Dead Zone's intro has
its own now) and 239 (a title card naming the zone: this one has one, as the owner asked).

**Answered by the owner the same day** (recorded in GDD §6, Cinematics, and §11, Music):
- The zone's title card appears in the close-up as it starts to fade to black. Built: it holds on the black.
- The runner's fall into the crater will be shown in a cinematic before this one. Its beats are still to come.
- The crater has a floor, and the host's crouched work over the bodies stays as it is.
- Instead of the zoom, there is a medium shot of the host, then the extreme close-up with its whole face filling the
  screen.
- New sound effects are fine where the existing ones don't fit; only new music is off. The owner left the call to
  the build. It now has five sounds of its own (below).

**Still open:**
697. **How the runner gets out** ("shakes themselves and starts to pull themselves out"). Placeholder: they lie on their
  back, their hips 2.5 m from the crater's far wall. At 1.9 s they stir and lift their head, and from 2.35 to 3.0 s
  they shake their head (30° each way, 4.5 times a second, dying away) as they sit up. They kneel at 3.45 s and
  stand at 3.9 s, then stagger 2 m to the far wall, looking up at its edge, and reach up at 5.65 s. The cut is at
  5.75 s. They climb out toward the way the level runs, so the host is behind them.
698. **The crater's size.** Placeholder: a 5.4 m gap in the runner's lane, its floor 1.42 m down (just deep enough that
  the runner, hanging from the edge, touches it), with three thin columns of the Dead Zone's own smoke and a faint
  cold light.
699. **Where the cyborgs are.** Placeholder: 16 m down the street behind the crater, in the lane left of the runner's.
  The bodies lie face down with their screens dark. Should they show damage?
700. **The cameras.** Placeholder:
  - The first shot is high over the crater's far end (4.8 m up, easing down to 4.0 m), looking down into it and
    down the street, with the cyborgs at the top of the view.
  - The cut to ground level puts the camera 1.3 m beyond the far edge, 0.16 m up, so at first only the hands show.
  - From 6.9 s the camera rises and pulls back (to 2.7 m back and 0.42 m up) as the runner gets to their feet.
  - The host starts to look over at 8.25 s, as the runner gets to their feet. The cut to the medium shot comes
    mid-turn at 8.6 s: 2.6 m in front of where its face turns, at its height, easing in to 2.15 m.
  - The extreme close-up comes at 10 s. The camera is straight in front of the screen, a little below its middle.
    The whole face fills 80% of the picture, pushing in to 92% by the time it's black, and the host's head holds
    still for it.
701. **The host's face.** Placeholder: as it looks over, its usual face, with a host's random corrupted glitches. In the
  close-up, its corrupted grin, with its screen's glitch (row jumps and purple static) boosted from 1 to 1.8. With
  Reduced flashing it changes at the slower rate every host uses.
702. **How it ends.** Placeholder: the close-up starts to fade to black at 11.5 s, over 1.2 s, and the title card comes
  up with it and holds on the black until 14.2 s (14.3 s in all). Then Dead Zone 1 opens on its own view.
703. **Its sounds** (`tools/asset_gen/sfx_bank_cinematics.gd`). None of them is a hazard's warning.
  - `crater_smoulder` opens it: a low rumble, embers ticking, a hiss of smoke, pebbles trickling.
  - `rubble_shift` as they sit up, and quieter as a knee comes onto the edge.
  - `edge_grab` as the hands slap onto the edge, with grit trickling off it.
  - `cyborg_host_turn` as the host lifts its head: its neck servo grinding under its screen's static.
  - `cyborg_host_glitch` under the close-up: stuttering static, a sinking hum, row-jump clicks and a faint garbled voice.
  - The zone's music fades in over 5 s from the start. Should the runner have a voice (a groan, a cough)?
704. **The slot's title**, "Out of the crater" (`data/cinematics/dead_zone_intro.tres`), shows on the title screen's
  "Next:" line. Placeholder; is that the name the owner wants?
705. **The close-up's flicker.** With Reduced flashing off, the host's screen fills most of the picture and glitches as
  every host's does (its own corrupted faces, rows jumping 12 times a second, boosted for the close-up): the picture's
  brightness jumps about three times a second. With Reduced flashing on it holds steady. Should the close-up always
  use the slower glitch?
706. **Raised for a core task: a gap ending on a chunk boundary loses its orange edge.** The track builder only gives a
  hole its edge where the hole ends inside a 40 m chunk (`TrackBuilder._floor_pieces`, `CHUNK_LENGTH`). A hole that
  starts or ends exactly on a multiple of 40 m is built without that end's lip, strip and halo. Here the crater ends
  at 201 m to avoid it. None of the generator's campaign gaps hit it at 3, 5 and 6 lanes; the boss arenas' hand-placed
  gaps were not checked. `track_builder.gd` is a core file, so the fix belongs to its own task.
707. **The new poses' look.** Placeholder: the runner lying, getting up and climbing out (`CinePoses`), and a cyborg
  lying still and crouched over something (`CyborgPoses.LIE`, `CROUCH`) are hand-set key poses. They are the
  toolkit's from now on, so any cinematic can reuse them.

**F2d, Gangland's outro** (from `docs/questions/f2d.md`)
The owner's beats (October 9, 2026; GDD §6, Cinematics) are built as given, and so is their follow-up (October 10,
2026, recorded in GDD §6 too): the runner's movement more fluid and less choppy; one shot where we see the runner
getting into the car and, in the seat next to them, a screech sitting nice and cute; the car faster as it drives off.
Then, the same day: the screech looking like the other screeches, still sitting there; the two nodding at each other
as the runner comes in, and then the car taking off.
These are the choices made to fill them in. Each is a placeholder in data
(`data/cinematics/gangland_outro_tuning.tres`, `GanglandOutroTuning`) or in code marked `DESIGN-TBD`
(`scripts/cinematics/gangland_outro/`, `scripts/cinematics/cine_poses.gd`).

708. **Its length** (GDD §1 and §6: "5–15 second cinematics"). Placeholder: 22.4 s (12 s for the rubble and the key,
  10.4 s for the car), to give each beat time: the screeches' moment, the walk over, the trembling hand-off, the
  unlock, getting in beside the screech, the drive into the distance. Every time is data, so it can be tightened;
  at 15 s the hand-off and the getting in feel rushed. Is 22–23 s acceptable here?
709. **The sky and look.** Placeholder: both scenes pick up where the fight ended, in the arena's look under Gangland
  3's blood-red sky (`CineStageDef.after_fight`), where the zones' other outros keep the zone's own sky. Or should
  the outro (or only the car scene) have Gangland's own night sky?
710. **Where the car scene is** ("cut to a new scene"). Placeholder: another stretch of Gangland's street, the car
  parked in it, driving off down the street toward the Marketplace. Alternatives: a side street or garage, or the
  edge of the Marketplace.
711. **The car's look** ("sleek, flashy ... angular, almost triangular ... shiny, like a Lambo"). Placeholder
  (`SportsCarModel`; size, paint and accent in data): a faceted wedge 4.4 m long, 2.0 m wide and 1.1 m tall (a
  little big for the runner, who is about 1.3 m tall, so they fit in it, sitting, with the screech beside them;
  two raked tan seats piped in cyan), a blade of a nose, a raked windshield,
  flared fenders, a dark side intake, a rear wing, a scissor door on the driver's (left) side; ultraviolet-purple
  paint with cyan running lights, wheel hubs and glow underneath, white headlights and red taillights. Purple and
  cyan stand clear of Gangland's browns and reds; cyan is also the anti-grav pads' colour, though nothing in a
  cinematic is a hazard or a pad. Another colour (a classic yellow or orange, or gold to match the key)?
712. **Who the car belongs to, and what the key opens** (narrative, GDD §1). Placeholder: the Host's key opens the
  car; nothing says whose it was. Should anything (a card, a later beat) say?
713. **The Host** ("the swarm host cyborg"). Placeholder: the fight's person (`SwarmHostPerson`), freed, lying back
  against a heap of rubble with their implants dimmed (shorted out at the defeat), 1.45 m tall (the fight holds
  them up at 1.75 m inside the swarm's bulk). They stay in the rubble; the outro shows nothing of what becomes
  of them.
714. **The screeches.** Placeholder: four of them (`sniffers`), the sewer screech's own body, sniffing round the Host;
  they look up as the runner comes walking down the street, raise their spines (to the level a screech has in play
  when it isn't attacking, never the full blazing bristle of its attack: `GanglandOutroSet.ALARMED`), and scuttle off
  into the gutters at the walls before the runner arrives (`look_up_at`, `scuttle_at`), so the runner's coming
  scares them away. How many, and is that the reason they leave?
715. **The runner's movement** (the owner, October 10, 2026: "stiff and unrealistic ... more fluid and less
  choppy"). Placeholder: a walk of its own for cinematics (`CinePoses.walk`, in place of the run cycle at a walking
  pace, which shuffled): heel strike, the knee bending through the swing, the foot rolling off its toe, the hips and
  shoulders turning against each other, the arms swinging opposite the legs, the head steady; the planted foot
  stays put (it skated about 40% of the ground covered before), and standing, the runner breathes and shifts their
  weight. They walk at an unhurried 1.05 m/s to the Host (`walk_speed`, from 5.8 m back) and 1.1 m/s to the car
  (`car_walk_speed`), about two steps a second; they turn at `turn_rate` (3 a second: a quarter turn takes about half
  a second, stepping round), and their reach for the key, holding it up and holding it out to the car ease in and
  out. Is the pace right (slower and more solemn, or brisker)? The walk is cinematics' own: play still uses the run
  cycle, which never walks.
716. **Getting in.** Placeholder (`CinePoses.get_in`, over `get_in_seconds` 1.5 s): from standing at the door, the
  near (right) leg lifts over the sill, they duck under the door's edge, sit down onto the seat and bring the other
  leg in, then sit back low in the seat, legs out, hands in their lap, the key in their right hand.
717. **The screech on the passenger seat** (the owner: "a screech is sitting nice and cute on the seat"; then "make it
  look like the other ones pretty much, but ... still have it sit there"). Placeholder (`CarPassenger`): one of the
  screeches, their very body and look in play, calm (spines down, as in play when not attacking: their tips still
  glow), at `SIZE` 0.55 (the fight's are 0.7), sitting up on its haunches on the passenger seat like a rat: body
  tipped up 45°, head level, paws held up in front of its chest, front legs tucked, hind feet forward on the seat,
  tail curled round on the seat toward the driver (`sitting_meshes`; the pose's angles are constants there). It
  faces ahead, breathing, the tip of its tail twitching; as the runner gets in it looks round at them with a curious
  tilt of its head (`passenger_looks_at`). Is the pose right, and its size? Who is it: one of the swarm's, staying
  with the runner from now on (does it appear in later zones or cinematics)? It rides off in the car; nothing shows
  it again.
718. **The nod** (the owner: "the screech and the player character nod at each other, and then the car takes off").
  Placeholder: once the runner is sat, they look round at the screech (`GanglandOutro.LOOK_AT_PET`, 40°); it nods to
  them at `nod_at` (17.1 s: its head dips 24° over 0.7 s, with a soft chirp, `screech_chirp`) and they nod back
  0.15 s later (their head dips 26°), then look ahead again as the door comes down behind them (`door_down_at`) and
  the engine starts (`lights_at`); the cut to the road and the launch follow (`road_at`, `launch_at`), 2.2 s after
  the nod. Should the screech nod first, or the runner? Keep the chirp?
719. **The getting-in shot** (the owner: "one shot where we see our character getting in and we see in the seat next
  to them, a screech"). Placeholder: from 14.8 s to 18.9 s (`passenger_at`, `road_at`), from behind the
  dashboard, looking back at both seats and out of the open door (wide, 68°, drifting in; the car's panels are
  one-sided, so the camera sees through the back of the windscreen): the runner at the door, stepping in, ducking
  in and sitting down beside the screech, which is in view throughout; the two nod to each other, the door comes
  down behind them and the engine starts. The courtesy lights come on as the door goes up and light the cabin
  warmly from over the front of the seats (the seats' piping glows), so both read in the dark street. Then the cut
  to the road for the launch.
720. **The key and the hand-off.** Placeholder: an ornate golden key (`key_length` 0.21 m: a faceted bow round a
  jewel, a shaft, two teeth), glowing faintly so it reads as gold in the street's dim red light. The Host trembles
  (`tremble`, `tremble_offering`), sits up a little and holds it out (`offer_at`); it glints (`glint_at`: a soft
  halo and a bell chime, `key_glint`); the runner leans in and takes it (`reach_at`), then looks at it
  (`admire_at`). Is the key's look right, and should anything be said or shown (a card)?
721. **The unlock and getting in.** Placeholder: the runner points the key at the car as they walk up; it chirps and
  blinks its lights twice (`unlock_at`, `car_unlock`; one slow glow with Reduced flashing); the scissor door swings
  up (`door_up_at`, `car_door`); the runner steps in and sits (`get_in_at`); the door comes down (`door_down_at`)
  behind them, and they're out of sight from the cut to the road (`road_at`). Should the runner (and the screech) be
  seen sitting in the car as it drives off (see-through glass, a costlier material)?
722. **The drive-off** (the owner, October 10, 2026: "faster"). Placeholder: lights and engine on (`lights_at`,
  `car_start`: the starter, a blip, idling), a fine idle shudder, then it launches (`launch_at`, `car_drive`: the
  tyres spinning and biting, the engine screaming up through three quick shifts, fading fast into the distance)
  with a squat on its rear wheels and a moment of wheelspin, accelerating at 24 m/s² (`acceleration`; it was 13)
  straight down the street, seen from the road behind it, 0.16 m up (`road_cam`; the owner: "the camera should be
  at road level"). In the 3.1 s before it ends it reaches about 74 m/s and about 115 m away (its `top_speed` of
  80 m/s is a cap it doesn't reach), gone into the haze for the last moment before it fades to black. No tyre smoke
  or exhaust flames. Fast enough?
723. **The car's own glow.** Placeholder: red taillights and red halos round them, cyan running lights and glow under
  it, and the gold key's glow. GDD §5 keeps glowing hazard colours for hazards; nothing in a cinematic is one, but
  red is the enemy-attack and weak-point colour. Keep red taillights (as any car has), or another colour?
724. **Sounds.** Seven new ones (`tools/asset_gen/sfx_bank_gangland_outro.gd`): `screech_sniff`, `key_glint`,
  `car_unlock`, `car_door`, `screech_chirp` (the passenger's greeting as it nods: a little trill, a questioning chirp
  and a purr), `car_start`, `car_drive`; and from the fight, `swarm_scatter` as the screeches flee and `host_short`
  at 1.1 s (`spark_at`), a last crackle from the Host's dead implants (heard, not shown). Keep them?
725. **Music.** Placeholder: the fight's music fades out as it opens (`music_fade`; a quiet aftermath) and no music
  plays; the Marketplace's intro brings its own. No cinematic music is generated (GDD §11). Should a track play
  over the drive-off?
726. **The shots.** Placeholder (`rubble_cam`, `follow_cam`, `handoff_cam`, `reveal_cam`, `passenger_cam`, `road_cam`
  and their looks and fields of view): low beside the Host, looking back up the street at the runner coming; over the
  runner's shoulder as they walk up; low in front of the Host for the hand-off; the car's reveal low off its front
  corner, gliding round to its side; inside the car as the runner gets in beside the screech, they nod and the door
  comes down; then the road-level shot behind it. Should any beat get a different angle?

**H11, the Sleep Taker again** (from `docs/questions/h11.md`)
All the numbers below are in `data/bosses/dead_zone_boss_tuning.tres` (`SleepTakerTuning`, F6 in the
fight) or `data/bosses/dead_zone_boss_wall_gaps.tres` (`WallGapTuning`), marked DESIGN-TBD in
`scripts/bosses/sleep_taker/sleep_taker_tuning.gd`, except the runner's glow (`PlayerAvatar`).

727. **How dark lights out goes** (GDD §10, "a completely dark tunnel": "about 75 to 100% darker than it does
  currently"). Placeholder: 90% darker, the middle of the range: `dark_level` 0.0225 (from 0.225) for the
  ambient and sky light, the fog's light and the sun, and the scenery's own light (0.016 of the zone's light
  in its arena, from 0.162), with floors of its own below it (`light_floor` 0.02, `scenery_floor` 0.015;
  every other boss keeps 0.3). Measured on the Compatibility renderer
  (`tools/showcase/sleep_taker_showcase.tscn --scenario=measure`, 5 lanes): the street goes from 32 to 0 (of
  255) at the darkest, the walls from 6 to 0, the bridges' undersides from 8 to 0; the glows hold (fence
  181, generator 215, its beacon 189, pad 166, mist 95, the nightmare's maws 102, the slash's lanes bright
  red). Forward+ wasn't measured (the cloud machine has no Vulkan). Is 90% right, or should it go all the
  way to black (`dark_level` 0)?
728. **The runner's own glow** ("the player will need to have some glow on the player character"). Placeholder:
  as the light sinks, the runner's existing rim light (its pale steel blue, clear of every hazard colour)
  grows from a faint outline to the whole silhouette (`PlayerAvatar.DARK_RIM_STRENGTH` 1.1 from 0.3,
  `DARK_RIM_POWER` 1.4 from 3), still below the bloom threshold, and fades as the light comes back
  (`runner_glow` 1: its share at the darkest). The copper trim keeps its glow (brighter would bloom toward
  the gap edges' orange). It lights nothing around the runner, so the street stays dark. Is the colour
  right (copper instead?), and should it also cast a small light on the floor around the runner?
729. **Distant glows fade into black.** The fog's light goes down with the rest, so far-off hazards come out of
  black rather than out of grey haze; within the usual reaction distance they show at full strength. Keep?
730. **Holes are only their edges.** In the dark a floor gap is its two thin orange lips (and a wall gap its
  tall orange posts and floor lip); the hole itself is as black as the street. They read in the review
  frames, but should the gap edges glow brighter during lights out?
731. **"More frequent" hands** ("greater in number and more frequent"). Placeholder: rounds of 3 rows growing to
  6 (from 2 to 4), rows 0.7 s apart (from 0.85 s; divided by the phase's pace), the attacks 0.8 s apart
  (from 1.3 s), the pattern's first attack 1.0 s in (from 1.5 s), and a round of a single row where only
  that fits before the next slash or lure (`hand_rows_min` 1, from 2). A round may also start its first row
  up to 0.7 s further on where the nearest spot is a hole (`SleepTakerHands.FIRST_SHIFTS`; its mists warn
  longer). Over a whole fight (the test's runner, about 78 s): about 1.5 times the rounds (4/6/5-7 at
  3/5/6 lanes, from 3/4/4) and 1.2 to 1.6 times the hands (42/65/97-118, from 26/55/76-78). The arena's extra
  holes leave fewer spots where a fair round fits, so the hands don't grow as much as the bigger rounds
  suggest. More still? Rows 0.65 s apart were tried; the fight's test runner then fell into a hole on its
  way to a generator (its own route-finding, not the hands'), so they stay at 0.7 s for now.
732. **Wall hands on both walls.** Placeholder: every row has a hand on each wall (`wall_hands_per_row` 2, from
  1 alternating), except beside a door in an outer lane, over an outer lane without its own hand, or at a
  wall gap. Keep?
733. **"The main attack"** read as the giant slash, and "more gaps on the walls to make it harder to dodge" as
  its wall escape. Placeholder: the walls are no longer kept whole where the slash warns (the stretch before
  its bridge, about 1.1 s of run), so a wall gap can be there as it warns; they still stand under each
  refuge's bridge, where it strikes (the bridge spans wall to wall), so a runner already on a wall as the
  claws come is never dropped into them. A runner dropped off the wall by a gap in the approach still has
  at least 1.3 s to take the wall again or reach a pad. Should the walls also open under the bridges? Or
  did "the main attack" mean the hands?
734. **More wall gaps.** Placeholder: 0.6-0.5 s of run from one wall gap's end to the next (from 1.6-1.3 s),
  half of them on both walls (from 30%), 0.6-1.1 s long: about 33 a minute (from about 15). Enough?
735. **"Three times more gaps on the ground."** Read as three times the October 8 arena's. Placeholder:
  `floor_gap_increase` 5 (six times the first build's rows of holes, from 1: twice) and 0.7 s between a new
  hole and anything else (`floor_gap_spacing`, from 1.3 s), which fits about 2.7 times October 8's holes
  (82/143/138 lane-gaps at 3/5/6 lanes, from 30/53/50; `tools/measure/sleep_taker_arena.gd`). Closer
  spacing would get nearer to 3 times but crowd the hands out further. The holes are along the whole arena,
  not only where it's dark: lights out is an attack in time, and the holes are laid before the fight. Should
  the extra holes open only during lights out instead (a runtime change to the track, like Buzz Overdrive's
  cuts)?
736. **Performance.** The hands' pool grows with the rounds (a round's most and a row more, for the last row of
  the round before still sinking): 28/42/49 hands at 3/5/6 lanes, from 12/20/24. Only the risen ones draw.
  Not measured on a phone yet.

**H12, the Sleep Taker without ceilings** (from `docs/questions/h12.md`)
All the numbers below are in `data/bosses/dead_zone_boss_tuning.tres` (`SleepTakerTuning`, F6 in the
fight) or `data/bosses/dead_zone_boss.tres` (its phases and par times), marked DESIGN-TBD in
`scripts/bosses/sleep_taker/sleep_taker_tuning.gd`.

737. **One wall or both at each slash** (GDD §10, "even on the phone, there should be a sidewall that the
  player could run to"; and from earlier the same day, "more gaps on the walls to make it harder to dodge
  the main attack"). Placeholder: at each slash one side wall, picked from the lap's seed (left at some,
  right at others), stands from where the warning starts to past the strike; the other wall keeps its
  gaps, so the player reads which wall to take (wall gaps glow orange, also in the dark). The wall's
  outer lane is kept clear of holes and fences until the longest wall run against the slash is over
  (one begun as the claws strike, with the claws' longer wall runs), so a runner who comes down off it
  lands on the street. Should both walls stand instead?
738. **Where the slash comes.** Placeholder: where the bridges stood, every 240 m at 18 m/s (`refuge_first`,
  `refuge_spacing`, about every 13 s), the street clear of holes and fences around it as before. Keep the
  rhythm, or should the slash now come more freely (anywhere a wall stands)?
739. **The slash's reach toward the walls** (a fix). A wall runner's body lies across the wall, its feet on
  it, reaching 1.09 m in toward the street, but the slash's damage box stopped only 0.9 m from the wall:
  a wall runner would have been struck. No test covered it while the pads were the way out.
  Placeholder: `wall_clearance` 1.2 m; a runner in the outer lane is still well inside the box.
740. **The fourth and fifth phases** ("more hands coming out of the ground, a little bit more often, about
  10% more for the first new phase and 20% more for the second"). Placeholder: their pace (`BossPhase.pace`)
  1.45 and 1.55, from the third's 1.3 (+11.5% and +19%), with the third's attack list. Pace shortens the
  hands' rows' spacing, the gap between attacks and the hands' mist warning together. On the same track
  over 120 s (generators let go by), against the third phase: +6% and +16% hands at 3 lanes, +47% and
  +81% at 5, +13% and +30% at 6 (more rows fit before each slash and lure, a step at a time, so 5 lanes
  jumps). Paces 1.40 and 1.50 were tried: the counts then didn't rise phase by phase at every lane count.
  Keep, or should the 5-lane jump be evened out (fewer extra rows there)?
741. **The new chunks.** Placeholder: the third EMP tears away its crown and lower left front heads, the fourth
  its lower right front heads (`SleepTakerModel.CHUNK_HEADS`), after the left and right clusters; the fifth
  bursts it. Their look?
742. **Generator sites** (a fix the tripled holes needed). With three times the holes, a lane clear around a
  generator (and where a stomp's bounce comes down, now kept clear too: it landed in a hole 8.5 m past the
  generator in a test run) had become rare, and generators came up to 35 s late. Placeholder: the arena keeps
  a site between each two slashes, in the middle of the stretch where a lure fits, its lane (from the seed)
  cleared; a due generator goes to the next site past `generator_sight`, so it may show up to about 16 s
  before its lure (it was about 7 s). Fine?
743. **Length and par times.** About 139 s for a runner who never misses at 3, 5 and 6 lanes (the owner: over
  two minutes is fine); one missed generator costs about 27 s. Placeholder: three stars at 150 s (was 86),
  two at 190 s (was 110).
744. **Hint.** The refuge hint (`data/hints/hints.json`, `dead_zone_boss_refuge`) now reads "Its giant slash is
  coming: when the lanes light red, get out of them, or run up a side wall where its claws can't reach."

**Side wall gaps** (from `docs/questions/wall_gaps.md`)
745. **Feedback when a wall entry is refused in a gap** (GDD §3 wall running). Placeholder: the player stays
  in the outer lane with no bump or clank, and `Player` emits `wall_missing` (`DESIGN-TBD` in
  `scripts/player/player.gd`, `_try_enter_wall`). No sound is mapped. Should it have a sound or a small
  sideways lean?
746. **Sound for the automatic drop** (`wall_gap_drop`). Placeholder: silent, like `wall_exit`. ScoreKeeper
  ends the wall run.
747. **Frequency and length** (owner: "LOW"; both walls "rarely"). Placeholder values are in
  `data/tuning/wall_gaps.tres`: about one gap every 24–32 s (±35%), each 0.6–1.1 s long, and 12% of
  placements on both walls. Measured over Zone 2+ levels at 3/5/6 lanes: 0.4–2.4 gaps a minute (median
  1.7; the low end is gangland/1, which introduces gaps halfway in), and about 10% of them on both
  walls (43 of 453). Should these be confirmed in playtest?
748. **Overhead dressing over a gap** (skybridges, strings of lights). Placeholder: zone skins leave
  overhead pieces out across a gap, so some may end at the gap's edge.

### Folded on October 14, 2026 (task E5e, Mecha Guppy and Captain Cogs)
Task E5e built the Beach's boss (GDD §10; `scripts/bosses/mecha_guppy/`, its numbers in
`data/bosses/beach_boss_tuning.tres`, `MechaGuppyTuning`, F6 in the fight; play `--level=beach/boss`, or
`--boss=beach_boss` in debug builds), and its steps raised these: E5e-a (the climb's core), E5e-b1 (the climb
itself), E5e-b2 (the shark, the pirate, the bombs and the hits), E5e-b3 (the hits by baiting, phase 2's bombs, the
review's fixes), E5e-c (phase 3, the defeat, the campaign slot, the par times and rewards) and E5e-f (Mecha Guppy's
floor bite). Where a later step changed an earlier placeholder, the entry says so. Two of them are answered or
superseded, items 783 and 788 (`docs/OPEN_QUESTIONS_ANSWERED.md`).

**E5e, Mecha Guppy and Captain Cogs: Raised by E5e-a, with E5e-b1's placeholders** (from task E5e's questions file)
767. **How the grapple's save onto the higher roof looks** (GDD §8, §10: "it pulls the runner up onto the
  higher roof"). The save has no reel-in: the runner is lifted in one frame to just under the higher
  roof's top and moved into its lane like a lane switch (`Player._pull_up`), and the climbing camera
  eases after it. Placeholder (E5e-b1): that instant lift, plus a warm-white rope (no hazard colour)
  from the runner (followed as the save lifts them) to the roof's edge in the lane it pulls them into,
  shown for 0.35 s as it fires (`MechaGuppy._grapple_save`, `MechaGuppyRope`; DESIGN-TBD). The save
  picks a roof and lane whose path is clear (`MechaGuppyStairs.save_spot`: the lowest higher roof
  under a lane that leads up where the save brings them down, and the lift starts above every solid
  front). Should the save instead reel the runner up visibly over a fraction of a second?
768. **Where a revive after a fall puts the runner in the climb** (GDD §4: the revive item "revives on the
  spot"; §10). A revive on the spot would drop the runner straight into another fall. Placeholder
  (E5e-b1, as E5e-a proposed): a revive after a fall goes where the grapple's save goes, onto the
  higher roof in its nearest lane that leads up (`MechaGuppy._grapple_save` answers both causes;
  `test_mecha_guppy_climb` checks it). Is that right, or should a revive put them back on the roof
  they fell from?
769. **The blob shadow on a raised floor in levels too?** (GDD §3: the shadow reads height and gaps).
  Unchanged by E5e-b1: levels and the other bosses keep the street-level shadow; in the climb it lies
  on the roof under the runner (`test_mecha_guppy_climb` checks it frame by frame). Offered as a
  possible improvement: draw it on the surface under the runner everywhere.
770. **Landing back on the floor they came from** (GDD §10: "the rest drop them back onto the floor they
  came from, where Mecha Guppy is eating: falling into it is instant death"). Is landing on a part of
  the lower floor the shark hasn't eaten yet survivable, or is every drop past the higher roof a
  death? Placeholder (E5e-b1): every wrong drop is a fall. The roof a step starts from is already
  eaten from 1 m past its pad strip (`MechaGuppyTuning.edge_margin`), so a drop in a lane that doesn't
  lead up falls into the chasm under the hut, down to the water far below (where E5e-b2's shark rises
  after the hut's deadline, and it bites the end of the roof just left), and dies unless the grapple saves
  it. Nobody lands on uneaten lower floor.

**E5e, Mecha Guppy and Captain Cogs: Raised by E5e-b1 (the climb)** (from task E5e's questions file)
771. **The climb's sizes and times** (GDD §10 gives the climb's shape, not its numbers). Placeholders in
  `data/bosses/beach_boss_tuning.tres` (`MechaGuppyTuning`, all DESIGN-TBD, tunable with F6 in the
  fight):
  - Each roof stands 3 m above the last (`rise`).
  - A hut's underside is 8.5 m over the floor its step starts from (`hut_height`; a level's ceilings
    are 6 m). At 8.5 m the view from under a hut (the run camera sits 3.6 m under a ceiling) is 1.9 m
    above the next roof, so its deck shows and the lanes that reach back read as a place to land. It
    also keeps at least 3.2 m over the roof under its end (`hut_clearance`).
  - The run on a roof, from landing to the next pads, is 1.6 s in phase 1 and 0.6 s in phase 2
    (`roof_seconds`): phase 2 climbs 19-22% faster. **Changed by E5e-b3:** every roof now holds a volley and
    the bait, so the run is 3.6 s in both phases, 0.14 s (a lane switch) longer for each lane past three, and
    phase 2's roofs stand 3.6 m apart instead of 3 m (`phase2_rise`): phase 2 climbs 20% faster in metres a
    second at every lane count and speed (see "Raised by E5e-b3").
  - The reaching lanes reach 10 m under the hut's end (`reach_back`, at 18 m/s), and the running-on
    lanes run 3 m past the higher roof's front (`run_on`, at 18 m/s).
  - The street is 3.5 s long before the first pads (`start_seconds`).

  A step takes about 5.5-6 s in phase 1, which is 10 or 11 roofs (about 30-33 m up) a minute. **Since
  E5e-b3:** 7.4-8.5 s, about 21-24 m up a minute in phase 1 and 26-29 m in phase 2.
772. **The reading margin** (GDD §10: the runner must see which lanes lead up and have time to switch
  into one). Placeholder: 0.9 s beyond every lane switch the farthest lane needs (`read_seconds`; 0.6 s
  before E5e-b1's review, raised as a more humane default for the owner to tune in playtest). It counts
  from the latest a rider can settle on the hut: a jump right before the pads, with the dash, then the
  flip up. A rider who doesn't jump gets about a second more. Is 0.9 s right?
773. **Every runner flips up.** GDD §10 makes the ceiling the way up. Placeholder: each roof ends in a
  strip of pads across every lane, longer than the longest jump at the run speed (dash included) by
  2 m (`strip_margin`), so nobody can jump over it. Is an unmissable strip right?
774. **How many lanes lead up, and the cue order** (GDD §10: "one, two or three, alternating" on 5-6
  lanes; the cues alternate; "one or two of the roof's lanes reach further back").
  - On 5-6 lanes the counts cycle 1, 2, 3, 1, 3, 2 (`up_counts`).
  - The cues alternate, starting with "the hut's lanes that lead up run further" (RUN_ON) on the
    first step.
  - A "roof's lanes reach further back" step (REACH_BACK) has at most two lanes
    (`MechaGuppyClimb.REACH_BACK_MOST`), so the threes always come with RUN_ON, and the count changes
    every step.
  - Where the block of lanes sits is seeded: the same on every attempt, never the same block twice
    running, nor three times running for the same cue (3 lanes: the same lane never leads up on more
    than two REACH_BACK, or RUN_ON, steps in a row).

  Is this the owner's "alternating"?
775. **The roof faces' rules** (GDD §10 doesn't say). Placeholder (`MechaGuppyStairs`, DESIGN-TBD):
  - A roof's sides below its top are a lane blocker. A lane switch into them bumps back, as into a
    truck's side.
  - A roof's front, below the depth a runner can still step up from, is a solid hazard ("tiki bar")
    that the dash doesn't pass: running into it kills, because what looks like a hit is a hit.

  The plan keeps every front out of a living runner's path. A wrong drop is dead (or saved) before it
  reaches the front, even dashing, and a right drop lands on the top. The one way to meet a front is
  to step sideways off a reaching tongue into the gap beside it, a fall that ends in a death either
  way.
776. **The street at the start** (GDD §10: Mecha Guppy eats the level from below). Placeholder
  (`MechaGuppy._plan_lap`, `MechaGuppyStairs`): the fight starts on the street (roof 0, the climb's own
  floor), which is eaten just past the first pads like every roof. Under the climb there is no track
  floor at all: water.
777. **No side walls** (GDD §10: occasional walls as a last-ditch save, or none if too complex; E5e-d).
  Placeholder: none. A wall gap runs over the whole arena on both sides, and the open beach and sea
  lie beyond (`MechaGuppySkin`).
778. **The climb's look** (GDD §10: tiki huts as the ceilings, tiki bar roofs as the floors, a few neon
  signs; the climb must read as climbing high). Placeholder (`MechaGuppyLooks`):
  - The huts: each hut is a hovering plank platform on glowing lift pods (the Beach's engine colour,
    never a hazard colour), with a lamp-lit underside, a 4 m orange band where each lane ends, a lamp
    row along each run of lanes' shared edge (so the lanes that lead up visibly run on, lit), and a row
    of tiki huts on top. RUN_ON steps add a walkway annex over the lanes that run on.
  - The roofs: each roof is a boardwalk deck with orange lips at its edges and fronts, thatch eaves and
    lantern posts outside the lanes, on top of a tower that stands down to the water: storey after
    storey of tiki bar, each with a ledge and a row of warmly lit windows, darker the deeper.
  - The lanes that reach back (REACH_BACK) stand on a pier in front of the tower: a lantern-lit fascia,
    the orange lip at its front and along the gap beside it, and the dark framework of a pier on tall
    stilts below, so they read as a landing, not a wall. No marker beyond the owner's two cues was
    added; if playtests show riders still steering away from it, a floor marking on the pier's deck
    could be proposed then.
  - The signs: some fronts and huts carry a neon sign in the Beach's violet, blue or warm white.
  - The eaten floor: the chasm between towers, open to the water far below (the street's own water),
    where the shark rises (E5e-b2).
779. **The backdrop** (GDD §10: a waterfall in phases 1 and 2, the Beach's normal backdrop in phase 3).
  Placeholder (`MechaGuppyWaterfall`): a flat-topped massif 420 m ahead of the camera, its falls' lip
  150 m up, its rock, lip and mist at world heights, so as the runner climbs the cliffs slide down and
  the falls' foot sinks below; past the lip a plateau shows its top. Its flanks slope to the sea, so
  the horizon stays in view beside it. A sea plane fills everything below out to the far plane, and the
  sky below the horizon takes the fog's colour. Layers of low cloud at fixed heights (12 m, then every
  36 m) lie beside the climb once the runner is above them. The waterfall fades out over 2 s when the
  runner reaches phase 3's top.
780. **The arena's haze** (`data/bosses/beach_boss_skin.tres`): fog from 24 m to 200 m, fully fogged past
  it (the Beach's levels: 34-250 m, 90% at most). The long drop below the towers hazes over with depth,
  and the climb is planned no nearer than that edge of sight, so nothing ever changes where it's seen.
781. **How soon a phase change reaches the climb** (GDD §10: phase 2's climb 15-25% faster). Placeholder:
  the steps in sight when the phase changes stay as they are, and the first one past the edge of sight
  (200 m) is the new phase's. Measured right after a landing, phase 2's first closer step comes
  11.6-12.7 s after the phase begins (one or two steps), and phase 3's top 9-16 s after it begins. A
  hazier arena would bring it sooner, at the cost of the view ahead. Is that soon enough? (E5e-b3: phase 2's
  first higher step's pads come 10.3-18.2 s after the phase begins.)
782. **Phase 3 and the fight's frame** (E5e-c builds phase 3). Placeholders in
  `data/bosses/beach_boss.tres`:
  - The phases are named "The Climb", "Higher" and "Level with Captain Cogs", each a third of the
    boss bar (equal health shares).
  - Phase 3 is a flat run on the last roof, with no attacks and no hits, that the fight wins 60 s
    after the runner reaches it (`top_seconds`; `MechaGuppy.top_reached`, logged and signalled for
    E5e-c). **Changed by E5e-c:** phase 3 is built (see "Raised by E5e-c").
  - Par times of 240 s and 180 s stand in until E5e-c measures the whole fight. (E5e-b3: a runner who baits
    every step clears phases 1 and 2 in 85-96 s, one who never does in 156-176 s, before phase 3's minute.)
    **Changed by E5e-c:** 177 s and 210 s (see "Raised by E5e-c").

**E5e, Mecha Guppy and Captain Cogs: Raised by E5e-b2 (the shark, the pirate, the bombs and the hits)** (from task E5e's questions file)
784. **Where the shark is eaten "under the lanes that don't lead up"** (GDD §10: "the rest drop them back onto
  the floor they came from, where Mecha Guppy is eating"). Placeholder: the floor there is already gone
  (E5e-b1's chasm); the shark shows itself eating there by breaching in that chasm for the hit, only after
  the hut's deadline, so it never becomes a third cue to which lanes lead up (only the owner's two cues
  tell). Before the deadline it lurks deep under the middle of the chasm, facing the runner, giving nothing
  away. Should it show itself there earlier, as a help to readers? (E5e-b3: this breach is now the fallback's
  only; the lurk is out of sight altogether, since E5e-b2's review saw its snout from the hut.)
785. **The bites** (GDD §10: its maw comes up through the floor and eats a huge chunk of the level; it eats
  the floors the runner should have left, never the floor they're on or the safe drop; every bite that
  could catch the runner warned). Placeholder (`MechaGuppyShark.bite`, `MechaGuppyPattern._bite`, the
  tuning's "Mecha Guppy's bites"; DESIGN-TBD):
  - Each step it bites the end of the roof the runner has just left (`bite_length` 14 m, never past the
    hut's start), only once the runner is up on that roof's hut: no bite can catch a runner.
  - Its warning all the same: the rumble (guppy_rumble) and the shark surging up beside the roof's end,
    upright, an eye just over the roof's top, 0.6 s before the runner reaches the pads (`bite_warning`),
    seen ahead.
  - The bite: it dives under the roof's top leaning in, lunges with its chin low across the roof, holds and
    snaps shut, dropping 7 m away with the roof's end (0.25 + 0.35 + 0.15 + 0.14 s); the roof's collision and
    look are cut together at the snap, rubble flying. Its jaws stay at least 2.5 m under a rider hanging
    from the hut, even mid-jump (2.8 m measured), so nothing looks like it reaches them. It comes from a
    seeded side. (E5e-b3: counting the jaws' tip caps, which E5e-b2's measure missed, the snap's closing chin
    came to 2.43 m; the snap now drops first and closes late: 3.36 m measured. On a roof with a notch the bite
    comes from the shark's catch beside the notch, on the notch's side.)
  - In phase 2's closer steps the shark can still be busy with the last step's hit when a bite is due:
    the bite waits for it, while it can still be over before the step's hit (`bite_spare`, in the tuning
    since E5e-b3; phase 2's steps are no longer closer).

  Is the end of the roof just left the right floor to eat, and is a bite under the rider (seen mostly as
  it rises ahead and lunges below) readable enough?
786. **Mecha Guppy's look and size** (GDD §10: building-sized, mechanical, mostly its giant jaws and its eyes,
  dark red lenses that don't glow, nothing glowing red). Placeholder (`MechaGuppySharkModel`,
  `MechaGuppyShark.SCALE`): jaws 12 m long and 12.6 m across at the hinge, riveted grey steel plates with
  dark seams, rows of steel teeth, a dark ribbed mouth, round dark red glass lenses with a darker iris in
  steel bezels; the body below the hinge stays down in the chasm. It is always shown side-on, in profile
  (the eye toward the runner), and has no hitbox. (E5e-b3: in its catch beside a notch it leans in so its lower
  jaw lies flat under the notch's lane, the upper jaw raised beside the track, an eye toward the runner.)
787. **Captain Cogs' look and the ship's station** (GDD §10: a pirate mixed with a futuristic look, in a
  floating ship flying above the track). Placeholder (`CaptainCogsSuit`, `CaptainCogsModel`,
  `CaptainCogsShip`): a burly pirate, 2.4 m tall, in a teal frock coat, a tricorn with a brass cog badge, a
  braided beard, an eyepatch, a clockwork brass arm and a monocle-eye glowing the Beach's blue (the skin's
  `neon_blue` since E5e-b3), on the
  stern castle of a flying galleon (brass bands, cannons, a patched sail with a cog-toothed skull, a neon
  violet trim, hover pods, brass cog wheels turning on its flanks). It keeps 40 m ahead of the runner
  (`ship_ahead`) and 16.5 m over the floor base (`ship_height`), stern toward them, and has no collision.
789. **The hit's show** (GDD §10: the bomb falling, a clang, sparks or smoke). Placeholder: the bomb counts
  the moment it falls inside the open jaws (high in the mouth, where the runner sees it): a fireball,
  sparks and smoke there (RunEffects', calmed by Reduced flashing), the clang (guppy_clang), a shudder and a
  camera shake, and the shark recoils, snapping shut and sinking out of sight before the camera passes.
790. **The fight's sounds** (`tools/asset_gen/sfx_bank_mecha_guppy.gd`): the captain's throw (a whoosh, a
  clockwork ratchet and a gruff "harr!"), the shark coming up (grinding machinery, a rising whine, plates
  clanking: the bites' and breaches' warning), its bite (a steel clank, hydraulics, crunching timber), a
  hit's clang (the blast, a ringing steel clang, sparks, a groan). The bombs keep the Floating Head's
  whistle and blast. (E5e-b3 adds cogs_aim, the captain taking aim while the bait's circle follows the runner,
  as long as `bait_seek`: ratchet clicks quickening over a servo whirring up, ending on a catch as the circle
  locks; the fallback's bomb is neither heard thrown nor whistles, since there is nothing to dodge.)

**E5e, Mecha Guppy and Captain Cogs: Raised by E5e-b3 (the hits by baiting, phase 2's bombs)** (from task E5e's questions file)
791. **The bait's shape** (GDD §10, the owner, October 11, 2026: Captain Cogs' bombs lock onto the runner's lane, and
  a runner who dodges one at a roof's end or a pier's open side sends it past the edge into Mecha Guppy's jaws).
  Placeholder (`MechaGuppyPattern._bait`, `MechaGuppyBombs.start_bait` and `lock_bait`, the tuning's "The hits";
  DESIGN-TBD):
  - From the second tower on (roof 2: not the street, not the first tower, whose run brings the climb's first volley,
    so the bait comes once that has been learned; not the top; E5e-f's review changed this: the first tower now brings
    the first floor bite alone and the first volley comes on roof 3, after the first bait, see "Raised by E5e-f"), each
    roof has a **notch** near its end: Mecha Guppy
    has eaten its outer lane for the last `notch_back` (7.5 m) before the next hut starts, on a seeded side. It has the
    eaten floor's look (the orange lip, the eaten face, the chasm below), it's built with the roof, so it's in sight
    from the landing, and that lane has no pads; no pickup and no volley spot comes near it.
  - As the runner comes near, Mecha Guppy rises into its **catch** beside the notch, with its rumble: its jaws wide,
    the lower jaw flat under the notch's lane, the upper jaw raised beside the track. Captain Cogs takes aim
    (cogs_aim) and the bomb's **aim**, a red target, follows the runner's lane for `bait_seek` (0.6 s), where the bomb
    will land: `catch_in` (4 m) into the notch (on the roof's top in every other lane). Then it **locks** onto the lane
    the runner is in, with the throw and the whistle, 1.1 s before it lands as they get there (`lock_seconds`, the
    Floating Head's warning), and the bomb's own flat circle takes its place.
  - Locked in the notch's lane, the runner has to switch out before the notch's edge anyway (their lane ends there,
    about a second after the lock at either speed), and the bomb goes on past the edge into the jaws as it passes
    the roof's top: **a hit**. Locked in any other lane, it's a spot of one bomb on the roof, dodged like any other.
    So the bait asks the runner to be in the notch's lane as the aim locks, then to dodge out, which is what the
    lane's end asks of them too: the dodge and the escape are the same move.
  - **Why the notch, not the hut's ends or the piers' open sides** (E5e-b2's review named those as today's places
    where a lane runs out):
    - Under a hut's ending lanes the runner hangs from the hut. A bomb there bursts on the hut's top, never touching
      them (the owner's rule), and a bomb at the roof below lands after they've dropped, so nothing there threatens
      a rider to bait. A catch beside the ending lanes before the hut's deadline would also show where the lanes
      don't lead up: a third cue, which only the owner's two cues may give; after the deadline there's no time left
      for a bait.
    - A pier's open side: on 3 lanes (and often on 5-6) a REACH_BACK pier is one lane wide, so a runner on it can't
      dodge sideways at all (task E5e-b2's review found exactly that trap). Baiting there would mean holding the
      only lane under a circle, or stepping off into the chasm. A catch beside a pier would also sit beside or
      behind the camera as the runner lands.
    - The notch is a stretch the shark "has eaten through" and where it is "clearly exposed and in the line of
      fire" (GDD §10): the runner sees it from the landing, has room to dodge on every lane count, the catch sits
      ahead beside the track in plain view, and it's the same on every roof. It is at the roof's end, as the owner
      put it, though not a pier's side.
  - **No third cue**: the notch is on the roof the runner is running on, before the next hut, and its side is seeded
    apart from the lanes that lead up next (the same sides whatever `up_counts` says: `test_mecha_guppy` checks it),
    so neither it nor the shark beside it tells anything about the next step. No new cue to which lanes lead up was
    added.
  - **The catch's reach**: no part of the jaws is ever over a lane a runner may use, nor over the notch's lane before
    the notch, at any height: the head lies out beside the track, its tip 0.4 m short of the next lane
    (`MechaGuppyShark.CATCH_CLEAR`; `test_mecha_guppy_bites` checks every frame of a fight).

  Is a notch near each roof's end the owner's "roof's end"? Is one bait a step (a hit a step for a runner who baits
  well, 4 and 6 steps for phases 1 and 2) right? Should the pier's side be a bait place too, on 5-6 lanes where a
  pier is two lanes wide? Is the first bait on the second tower right (E5e-b3's review: the first step already
  brings the climb and the first volley; since E5e-f's review, the climb and the first floor bite, the first volley
  coming on roof 3)?
792. **The bait's aim** (E5e-b3's review: the following circle, a flat ring a little smaller than a bomb's circle, showed
  40 m out as a red sliver a few pixels high). Placeholder (`MechaGuppyBombs._aim_node`, `AIM_SCALE`, `AIM_LIFT`;
  DESIGN-TBD): a red target, a ring 1.25 times a bomb circle's size with four ticks across it, standing on the floor
  where the bomb will land and leaning back 45 degrees from it, its face toward the runner, so it reads from 40 m
  out; steady (no pulse, unlike the locked circle, so nothing flickers with Reduced flashing). At the lock the bomb's
  own flat, pulsing circle takes its place. In the notch's lane there is no floor: the aim, and then the circle, hang
  over the gap at the roof's top, where the bomb passes on its way into the jaws. Is a standing target the right look
  for the aim, and is the circle over the gap readable?
793. **The fallback's cadence** (GDD §10: "Captain Cogs sometimes misses into the chasm anyway"). Placeholder
  (`fallback_after` 1, DESIGN-TBD; 2 until E5e-b3's review, which found a fight with no checkpoint dragging out to
  about 5 minutes): once a step has gone by without a hit, from the next step's hut deadline (every rider committed),
  with the rider in a lane that leads up, Captain Cogs misses into the chasm beside the lanes that lead up and Mecha
  Guppy rises to eat it (E5e-b2's hit; its bomb is neither heard thrown nor whistles, since it threatens nobody, and
  the shark glides deep out of sight until it surges up). A runner who never baits lands a hit every other step:
  phase 1 ends at 66.2-74.6 s and phase 2 at 155.5-175.7 s, against 40.4-45.3 s and 85.1-95.8 s for a runner who baits
  every step (3, 5 and 6 lanes, 18 and 23.8 m/s): 1.6 and 1.8 times as long. Nothing escalates. A step with no bait to
  offer (under an extreme tuning a roof may have no room for a fair one) counts as one without a hit, so the hits never
  stall. Which N does the owner want? (2 gave a hit every third step: 223-252 s for phases 1 and 2 before the first
  notch moved to roof 2; 0 would give a hit every step, leaving no reason to bait.)
794. **At most one hit a step** (E5e-b3's review): a step its fallback already hit offers no bait (no aim follows the
  runner, no catch), so a runner never lands both on one step, and an aim that follows them is always a chance at a
  hit. Right?
795. **No hit on a step the runner fell** (a rule from E5e-b3's brief): on a step where the runner fell, even if
  the grapple (or a revive) saved them, no bomb hits: a bait locked then falls past into the chasm as the shark shuts
  its jaws, and a fallback due then waits for the next step. Right?
796. **A fall into the notch**: a runner who runs on past the notch's edge falls into the chasm; the grapple's save (or
  a revive) takes them back up onto the roof they fell from, into its lane beside the notch, rather than up onto the
  higher roof as other falls go (that one may still be far ahead). Falling there, a lane switch toward the roof just
  under its top bumps off its side (the roof faces' rule); deeper, as in any pit, it does nothing. Right?
797. **Phase 2's "more bombs" and faster climb** (GDD §10: the same with more bombs and a climb 15-25% faster;
  *(proposed)* by bringing the steps closer together). Placeholders (`roof_spots`, `landing_spots`, `spot_bombs`,
  `spot_bombs_wide`, `roof_seconds`, `phase2_rise`; DESIGN-TBD):
  - Every roof now holds a volley and the bait, which need its run (3.6 s from the landing to the next pads, 0.14 s
    longer for each lane past three, with time between the volley and the bait for a runner to cross from the far
    side to the notch: `bait_after`). Closer steps would leave no room, so phase 2 climbs faster by **higher steps**:
    its roofs stand 3.6 m apart instead of 3 m (`phase2_rise`), the steps as long as phase 1's, and the climb rises
    20.0% faster in metres a second at 3, 5 and 6 lanes and both speeds. Every margin holds (the reading margin
    still 0.9 s); the hut keeps 4.9 m over the higher roof. Is climbing faster by higher steps acceptable instead
    of the proposed closer steps?
  - The hut bombs are gone (E5e-b2's review: harmless and unseen), and no bomb is thrown that has nothing to dodge
    but the fallback's (silent). Phase 1 throws a spot on each roof's run (one bomb on 3 lanes, two side by side
    on 5-6) and the bait; phase 2 adds, after each RUN_ON step, a spot where riders come down (dodged by a switch
    in the air as they drop off the hut's end), and its spots take a bomb more (two on 3 lanes, three on 5-6). Counting
    only the bombs that can reach the runner, the bait's included, over the steps that threw any: phase 1 has
    1.8-2.6 a step and 0.22-0.30 a second, phase 2 3.5-4.3 a step and 0.46-0.54 a second (3, 5 and 6 lanes, 18 and
    23.8 m/s): 60-94% more a step and 72-111% more a second (phase 1's first step has no bait now). Is that the
    owner's "more bombs", or too many? (The owner's 15-25% is read as the climb's figure; fewer spot bombs in phase 2
    would bring it nearer that if it is meant for the bombs too.)
  - No circle ever shows in the runner's lane while every lane they could switch to has no floor (task E5e-b2's
    review: on a REACH_BACK pier the roof's first spot came down in the runner's lane as they landed). A roof's spots
    are thrown no sooner than the runner can switch lanes there (`Step.free_at`), and the suites check every frame of
    every fight.
798. **Extreme tunings** (E5e-b3's review found tunables inside their own F6 ranges breaking the bait's and the
  fallback's promises; `test_mecha_guppy_tunables` now checks every tunable at both ends of its range on physics, at
  3 lanes and 23.8 m/s and at 6 lanes and 18 m/s). Placeholders (`MechaGuppyPattern`, DESIGN-TBD):
  - A step whose bait can't be fair gets none and counts toward the fallback: the aim shows only once the runner can
    switch lanes on that roof and has had a reaction (`dodge_reaction` past `Step.free_at` and the hut's deadline),
    and a runner in the notch's lane as it locks has a reaction, a lane switch and `dodge_margin` to leave it before
    its edge. A notch starts that far past where its roof's run begins, too, or the roof has none. At the far ends
    of `bait_seek`, `lock_seconds` or `roof_seconds` this leaves no baits at all: the fallback brings every hit.
  - The fallback is thrown only once Mecha Guppy can rise for it, waiting while its bomb can still come down before
    the runner draws level with it; a bite of the roof just left that would keep the shark busy past that gives way:
    the shark sinks off and that roof's end stays uneaten that step (only under extreme bite timings). Where Mecha
    Guppy needs longer to surge up and open its jaws (`breach_rise`), the fallback's bomb flies longer than
    `hit_seconds` and can come down behind the runner.

  Are these the right ways to give at the extremes, or should those tunables' ranges be narrowed instead?
799. **The reaction the fight is planned for**: the planner gives every dodge `dodge_reaction` (0.35 s, the suites'
  usual reaction), then each lane switch the escape needs, plus `dodge_margin` (0.25 s). The suites' bot now waits
  exactly `dodge_reaction` after every circle shows and after the bait locks before it moves, and wins at every lane
  count and speed. In scratch runs a bot reacting in 0.65 s also won phases 1 and 2 at 3 and 6 lanes, missing some
  baits (so a little slower), but the plan only promises 0.35 s. Should this fight plan for a slower reaction?

**E5e, Mecha Guppy and Captain Cogs: Raised by E5e-c (phase 3, the defeat, the campaign slot, the par times and rewards)** (from task E5e's questions file)
800. **Where Captain Cogs' ship comes level** (GDD §10: "the captain's ship comes level with the player"). Placeholder
  (`CaptainCogsShip.come_level`, the tuning's "Phase 3"; DESIGN-TBD): as the runner reaches the top, the ship eases
  over `level_seconds` (3 s) from its station above the climb to one alongside the top on the left (`LEVEL_SIDE`),
  its hull `level_out` (2.5 m) outside the top's eaves, its keel `level_keel` (1 m) under the deck so its gun deck
  and the captain stand at the runner's height, `level_ahead` (30 m) ahead, keeping pace, no longer swaying; its
  three starboard cannons face the top. Alongside rather than ahead over the lanes, so the cannonballs come from
  the side and Mecha Guppy can leap up beside the top to eat it without its body ever crossing the lanes. Is
  alongside on the left right, and close enough to read as "level with" the runner?
801. **The script** (GDD §10: a fixed, learnable script, no escalation; the owner's approval of the warnings,
  item 764). Placeholder (`MechaGuppyTop.plan`, `top_script` "RRW.RWRRW.", `top_first`, `top_beat`, `top_clear`;
  DESIGN-TBD): the script loops from `top_first` (4 s after the top is reached), a beat every `top_beat` (2.4 s): R a
  round, W a wave, a dot a rest. No beat's warning starts before the last beat's attack has passed the runner
  (`beat_spare`, 0.3 s), so a jump and a switch are never asked for at once, and none whose attack would end later
  than `top_clear` (1 s) before the minute's end: 18 beats a minute, 12 rounds and 6 waves, the last over 56.3 s in.
  Everything is timed from the top by the fight's clock, so a retry plays the same and nothing escalates. A beat held
  back (the pattern not running yet, as in phase 3's intro) starts late, at most one a physics step, and every later
  beat keeps its gap after it (`MechaGuppyTop.late`; E5e-c's review: they used to start together, two rounds striking
  every lane between them). Is that mix and rhythm right, and should rests come more often?
802. **The rounds' look and rule** (GDD §10; the owner's warning: "red lines down the lanes they'll hit and a cannon's
  charging sound"). Placeholder (`MechaGuppyRounds`, `round_warning`, `round_flight`, `round_ahead`, `round_close`,
  `round_radius`; DESIGN-TBD):
  - A round strikes every other lane (`MechaGuppyTop.struck`): the lanes 0, 2, 4... or the others, alternating round
    by round, so a clear lane is always one switch away on any lane count. A struck lane with a pickup in its stretch
    is left out (`PICKUP_CLEAR`).
  - The warning: a red line down each struck lane on the top's deck (`BossProps.lane_warning`, pulsing, steady with
    Reduced flashing), over the stretch its ball will roll, with the cannons' charge (cogs_charge, as long as
    `round_warning`, 0.8 s). Then the broadside (cogs_cannon, a flash, smoke and a recoil): a cannonball from a
    starboard cannon for each struck lane, lobbed over the eaves (`round_flight`, 0.3 s) onto the far end of its line,
    `round_ahead` (24 m) ahead, then rolling down the lane at the runner, closing in at `round_close` (50 m/s): it
    reaches them 1.58 s after its warning at any run speed (the plan needs a reaction, a lane switch and
    `dodge_margin`: 0.74 s).
  - The cannonball: an iron ball `round_radius` (1.15 m) with a brass band, rolling; its hitbox 65% of its width, 85%
    of its height (1.96 m: too tall to jump, so the dodge is a switch) and 70% of its depth, an enemy attack (armor
    and the shield block it, the dash passes through it).

  Are lobbed balls rolling down the lanes the owner's "rounds"? Is every other lane, alternating, the right shape?
803. **The waves' look** (GDD §10; the owner's warning: "a rising swell and a roar", jumped like the Resonator's ring).
  Placeholder (`MechaGuppyWaves`, `mecha_guppy_wave.gdshader`, `wave_warning`, `wave_ahead`, `wave_close`,
  `wave_height`, `wave_depth`; DESIGN-TBD): a swell rises out of the sea beside the top on the right, away from the
  ship, for `wave_warning` (1.2 s) with its roar (wave_swell, as long), its crest breaking the deck's line within the
  first 0.25 s (`CREST_BY`; it rises from 11 m down, eased out hard: E5e-c's review found it hidden for half the
  warning from 30 m down) and standing 7.6 m over the deck by the crash; then it crashes over every lane `wave_ahead`
  (24 m) ahead (wave_crash, foam) and its surge rushes along the deck at the runner at `wave_close` (30 m/s), 2.0 s
  after its warning: a low band across every lane, `wave_height` (0.45 m) tall and `wave_depth` (0.5 m) deep, so a
  normal jump clears it, as the Resonator's ring's does; armor and the shield block it, the dash passes through it.
  The swell is a medium-bright turquoise wall of sea water with white foam along its crest, and the surge a paler teal
  sheet with a white foaming crest (the water never glows); the surge carries one red line low on its face, the
  Resonator's ring red, as the sign of a low band to jump (the water's colour alone would not warn). Its streaks
  stand still with Reduced flashing. Is the red line on the water right, or should the surge read by its foam alone?
804. **The minute and the boss bar** (GDD §10, proposed: the boss bar runs down over the minute). Placeholder
  (`MechaGuppyTop.run_down`, `top_seconds` 60 s): the minute counts from `top_reached` by the fight's clock; the bar
  runs from phase 3's share down toward nothing, and the fight is won as it ends (the phase's one counted hit, logged
  `top_over`), never by a hit: bombs and weapons do nothing in phase 3. The top comes 4.0-13.9 s after phase 3 begins
  (the steps already in sight first); were it reached within phase 3's intro (2.5 s), the bar would start down, and
  the beats come, once the intro ends. While it runs down, the HUD's bar follows it without the white segment's hold
  after each drop (`BossEncounter.health_runs_down`, false for every other boss; E5e-c's review found the white segment
  never draining below about 55 fps). Right?
805. **The bites stop at the top** (GDD §10). Captain Cogs' bombs (the volleys, the bait, the fallback) stop as phase 3
  begins, but Mecha Guppy's bites go on through the climb's last steps to the top (the roof just left is still
  eaten: the level being eaten isn't an attack) and stop the moment the runner stands on the top. Right?
806. **The low cloud at the top**: the waterfall's layers of low cloud fade out with it as the runner reaches the top
  (the Beach's normal backdrop in phase 3, GDD §10), so the top's sea far below shows hazy and clear. Right?
807. **The leap's staging** (GDD §10: Mecha Guppy "jumps over to the boss, Captain Cogs, and eats the boss"; "Mecha
  Guppy has eaten Captain Cogs, and it swims away"). Placeholder (`MechaGuppyLeap`, `leap_rise`, `leap_hang`,
  `leap_fall`, `breach_seconds`, `dive_after`; DESIGN-TBD): as the minute ends, Mecha Guppy bursts up out of the sea under the ship,
  upright and side-on (an eye toward the runner, its chin toward the top, as it always shows itself), its jaws opening
  wide round the ship's stern half (`leap_rise`, 1.2 s, guppy_leap); its jaws snap shut on the stern with the captain
  on it (guppy_gulp, a shudder, a shake): the captain and the stern are gone, and the bow half breaks away, tumbling
  down into the sea with the sail. It hangs a moment (`leap_hang`, 0.45 s), leaning out, and falls back out of sight
  beside the top (`leap_fall`, 0.9 s). Then it swims away where the run camera sees it (E5e-c's review: from the top
  the deck's edge hides the sea for tens of metres out and the haze the rest, so the first placeholder's fin and wake
  at the waterline were never seen, and the results waited about 6.5 s on an empty view): out at sea ahead, it bursts
  out of the water in one long leap heading away, on ahead and out to sea (the leap's roar again; a plume of spray,
  sea-blue turning to white), its whole body clear of the sea at the top of its arc (it has a tail now), and dives back
  in head first with a bigger plume (guppy_swim), over `breach_seconds` (2.8 s) from the sea back to it
  (`MechaGuppyLeap._plan_breach`, its numbers `BREACH_*`): its arc's top 10 m under the deck (at least 24 m over the
  sea), where the camera's line past the deck's edge passes 9 m under it, at least 40 m out (clear of the tower and the
  falling bow), past the shoreline wherever the camera sees the sea's surface it breaks, the top of its arc within 38°
  of the camera's forward axis, at least 55 m ahead; it pulls away at 14 m/s and out at 3 m/s; a higher leap (from a
  higher top: a runner who never baits climbs to about 73 m) takes longer so it moves the same, and from a high top it
  begins already under way, just out of the camera's sight, since nothing of its rise out of the sea far below could be
  seen. The results may follow `dive_after` (0.6 s) after its snout is back in the water (`victory_over`, 5.9-7.0 s
  after the win); it's gone once its tail is under. From the breach to the results some of the shark is in view
  90-100% of the time at 3, 5 and 6 lanes (the whole-fight suite); from a very high top on 5-6 lanes its dive's plume
  stays under the deck's edge (its body is seen diving). Nothing of its jaws or its body comes over the lanes or the top's eaves at any moment, nothing in
  it has a hitbox, and the runner is in the framework's win god mode. Is eating the stern half with the captain (the
  bow falling away) the owner's picture, or should it swallow the whole ship? Is a breach and dive the owner's "swims
  away"?
808. **The victory riff after the gulp**: LevelRun's riff at the defeat is off for this fight (`victory_riff`); the
  zone's level-complete riff plays `riff_after` (1 s) after the gulp instead (`victory_riff_on`), so the captain is
  eaten first. Right, or no riff at all?
809. **The rewards** (DESIGN-TBD): `payout_credits` 500 and `defeat_score` 5000, the same as its neighbours' (Hostile
  Takeover's and the Sleep Taker's, the framework's defaults). Should a later boss pay more?
810. **The par times** (GDD §10, proposed: one star for a win, two and three for par times). Placeholder: three stars at
  177 s, Hostile Takeover's margin (74/68.6) over the slowest whole fight played clean by a runner who baits every step
  at the campaign's speed: clean fights take 157.4-164.4 s at the Beach's 23.8 m/s and 159.2-169.7 s at 18 m/s (3, 5
  and 6 lanes), all three stars. Two stars at 210 s and the time bonus to 260 s (E5e-c's review; the owner's call):
  a runner who never baits wins in 223.1-244.3 s, so one star at every lane count and speed (230 s gave two stars on 3
  lanes and one on 5-6), and two stars need some baiting. Right?

**E5e, Mecha Guppy and Captain Cogs: Raised by E5e-f (Mecha Guppy's floor bite)** (from task E5e's questions file)
The owner's request (October 11, 2026; GDD §10, "The floor bite"): Mecha Guppy bites a shark-bite crescent out of the
floor the runner is still running on, before the pads, leaving one lane; in phase 2 the bite is sometimes so big the
runner has to jump the gap. Everything below is a placeholder (DESIGN-TBD in `MechaGuppyCrescent`, `MechaGuppyClimb`,
`MechaGuppyFloorBite`, `MechaGuppyShark.floor_bite`, `MechaGuppyStairs` (the saves and pickups near a bite),
`MechaGuppyLooks` (the hut's end band, the trench) and the tuning's "Mecha Guppy's floor bite").

811. **Which roofs carry one** (the brief: one new mechanic at a time; if a roof can't fit the bite, the volley and the bait,
  lengthen roofs modestly or alternate what each carries). Placeholder (`MechaGuppyClimb.bitten`, `FIRST_BITE`): the
  roofs alternate what they carry.
  - Roof 1, the first tower, has the bite on its own: no volley and no bait. Task E5e-f's review moved its volley off
    (one new mechanic at a time), so the climb now teaches one thing a roof: the floor bite on roof 1, the bait on roof
    2 (with a bite, already learned), the volley on roof 3. This reverses E5e-b3's order, which brought the first volley
    on roof 1 so it was learned before the bait. The alternative is `FIRST_NOTCH` = 3: the first volley on roof 2 and
    the first bait on roof 3, keeping E5e-b3's order, with the bait (and so the hits) starting a step later.
  - From roof 2 on, every other roof (the even ones, which REACH_BACK steps lead onto) has the bite and then the bait,
    with no volley: the bite takes the volley's place. The odd roofs from 3 on keep their volley and bait, so phase 2's
    landing spots, which come after RUN_ON steps, stay.
  - A bitten roof's run is as long as its bite and then its bait need (`_bite_room`), the same in both phases. Counting
    the bite's reaction from where its warning can be read and the dash's reach (task E5e-f's review, below) made these
    roofs longer: at 3 lanes 4.18 s at 18 m/s and 3.90 s at 23.8 m/s, against 3.60 s; at 5 lanes 4.74 s and 4.46 s,
    against 3.88 s; at 6 lanes 5.02 s and 4.74 s, against 4.02 s. Roof 1, with no bait to make room for, has the usual
    run.
  - The effect on the fight: a runner who baits every step finishes phase 1 at 41.0-47.2 s and phase 2 at 86.5-100.8 s
    (before the floor bite: 40.4-45.3 s and 85.1-95.8 s), and wins in 158.0-161.9 s at 23.8 m/s and 162.7-175.7 s at
    18 m/s (before: 157.4-164.4 s and 159.2-169.7 s). A runner who never baits wins in 226.1-254.3 s (before:
    223.1-244.3 s).
  - With fewer volleys there are fewer bombs to dodge. Counting only bombs that can reach the runner, over the steps
    that threw any, phase 2 has 2.50-3.17 a step and 0.317-0.366 a second, against phase 1's 1.50-2.00 and 0.142-0.180
    (before the floor bite: 3.5-4.3 and 0.46-0.54 against 1.8-2.6 and 0.22-0.30). Phase 2 still has more than phase 1.

  Should every roof have a bite instead, with longer roofs, or is alternating right? And should the first volley come
  before the first bait (`FIRST_NOTCH` = 3)?
812. **The shape** (the owner's sketch: a crescent bitten in from one side, deepest in the middle). Placeholder
  (`MechaGuppyCrescent`):
  - A half-ellipse `floor_bite_length` (12 m) long along the bitten side, its edge scalloped by 12 teeth (`TEETH`),
    each bulging back toward the floor by up to 0.3 m (`TOOTH_BULGE`). The scallops fade toward the bite's ends.
  - A bite that leaves one lane reaches, at its deepest, exactly the inner edge of the far side's outer lane: it takes
    2 of 3 lanes, 4 of 5 or 5 of 6 there (5.1 m, 9.9 m and 12.3 m deep), and fewer toward its front and back.
  - Its edge has the eaten-edge look: the orange lip and coping along the scalloped edge, the glowing strip and the
    broken face of the tower down to the water (fading into the sea haze with depth: "The trench's depth", below). The
    tower's side, eave and lanterns are gone along it.

  Collision follows the same polyline, so what looks like a hole is a hole. Is a 12 m bite the owner's size, and do
  the scallops read as teeth marks?
813. **Phase 2's full-width bites** (GDD §10: "so big that sometimes the player has to jump over the gap"). Placeholder
  (`full_every` 2, `full_jump_share` 0.7, `full_through` 0.6): every other bitten roof of phase 2 from roof 4 on
  (roofs 4, 8, 12 and so on) has a bite that crosses the whole floor over 60% of its length.
  - At the bitten side its length is 70% of a normal jump at the run's speed: 8.4 m at 18 m/s, 11.1 m at 23.8 m/s. That
    matches a level's wider gaps (0.7 of a jump); a level may ask at most 0.8.
  - Each lane's stretch is shortest on the far side: 6.3-8.4 m at 18 m/s and 8.3-11.1 m at 23.8 m/s, against jumps
    of 12.0 m and 15.9 m.
  - Its other bites leave one lane, as in phase 1.

  Is every other bite right, and is a jump of 70% the right challenge?
814. **Its warning** (every attack has a visual and an audio warning). Placeholder (`MechaGuppyFloorBite`, `floor_warning`
  1.8 s, `floor_rise` 0.5 s):
  - The visual: the crescent's outline on the floor in the enemy attacks' red, in the Golden Convergence's Fist Slam
    look: a glowing frame round a solid red fill. The frame deepens as the snap comes and beats a little, but holds
    steady with Reduced flashing. It counts as a floor warning on every lane it takes, so pickups keep off it.
  - The sound and the shark: its own warning sound (guppy_floor_warn, 1.4 s: three heavy knocks from under the deck,
    nearer each time, timbers groaning and splintering, steel teeth screeching up through the wood) as Mecha Guppy
    rises into its watch beside the roof's side on the bitten side, upright, its snout towering over the deck. Task
    E5e-f's review gave it its own sound: it used to share the rumble with the harmless bite of the roof behind and
    the fallback's breach.
  - The timing: it shows `floor_warning` before the runner reaches the bite. In practice that is 1.99 s, because it
    can't be shorter than Mecha Guppy's rise and lunge plus `floor_snap_lead` (1.54 s plus 0.45 s). It never shows
    before the deadline of the hut that led onto the roof, so it gives no cue to the lanes that lead up.
  - The margins, counted from where its warning can be read (task E5e-f's review): from a hut, and dropping off its
    end, the crescent on the roof ahead is a sliver a few pixels high, so the reaction starts where the runner can
    first switch on that roof (`Step.free_at`; never before the hut's deadline). From there the bite gives a reaction
    (0.35 s) and `WARN_SLACK` (0.15 s), every switch from the farthest lane to the one the bite leaves (0.14 s each),
    `dodge_margin` (0.25 s), half a hurtbox and the dash's reach (4.8 m: the climb's other margins hold a runner who
    dashes, and so does this one now). Its front now comes 1.24-1.73 s after the riders can first switch (it was
    0.69-0.96 s), and its end 1.62-2.24 s before the notch.
  - On real movement, in the worst case (moved into the farthest lane where the runner can first switch, reading the
    warning a reaction late from there), it has 0.40 s to spare at 3, 5 and 6 lanes and both speeds (`dodge_margin`
    and the slack): the bot's last switch is done 0.48-0.64 s before its hurtbox's front reaches the bite, or
    0.23-0.32 s before when it dashes as it starts across. Reading it as soon as it's on the roof's floor gives the
    same margins, within a frame.
  - A full-width bite warns the same way. The earliest take-off over it comes 0.64-1.11 s after a reaction counted
    from when the warning can be read, and the bot's jump clears its stretch by 0.085-0.100 s at either end.

  Is a red crescent the right warning, and are 2 s enough to read it?
815. **The snap and a runner in the bite** (the brief's placeholder; FloorCut's and the Fist Slam's rule). Placeholder
  (`floor_snap_lead` 0.45 s, `MechaGuppyFloorBite.snap`):
  - The motion: Mecha Guppy dives under the deck, bursts up through it leaning in, its lower jaw flat across the
    crescent with its teeth through the deck and its tip 0.4 m short of the lane the bite leaves (no part of its jaws
    is ever over that lane), and snaps shut (guppy_bite, the crunch), dropping 10.5 m with the chunk.
  - The timing: the chunk is gone 0.45 s before the runner reaches the bite. A full-width bite is gone at least 1 m
    before the earliest take-off that clears it.
  - Contact: a runner in the bite's area as it snaps meets the jaws' hitboxes, an enemy attack. Armor and the shield
    block it, and the dash passes through it. The floor under a runner who lives through it holds for
    `cut_hold_seconds` (1 s), drawn as the deck with the orange lips round it, and then it goes. Anyone else dies of
    "Mecha Guppy's bite".
  - Because the snap comes before the runner gets there, nobody is in its area in normal play. The contact rule only
    meets a runner put there some other way.

  Should the snap come as the runner passes instead, catching whoever is still in the bitten lanes as the Fist Slam
  does? A runner who runs into the gap falls, and the grapple or a revive saves them.
816. **Its side** (never a third cue). Placeholder (`MechaGuppyClimb._bite_side`):
  - Seeded by the roof's index, never three bites running on the same side, and with nothing to do with the lanes that
    lead up (the suite plans with other lanes leading up and finds the same bites).
  - A bitten roof's notch is on the bite's side, so the lane the bite leaves is never the notch's lane. This changes
    E5e-b3's notch side on those roofs, which was seeded by the roof alone.
  - After the bite, a baiting runner crosses from the lane it leaves to the notch's lane. The bait's aim shows only
    once the runner is past the bite, and it locks a reaction and a switch for every lane but one after that.
817. **The fallback around a bitten roof**. Placeholder (`MechaGuppyPattern.bitten_next`): a fallback due on a step that
  leads onto a bitten roof waits for the next step, because Mecha Guppy can't breach in front of that roof and also
  rise for its bite. At the default `fallback_after` (1) the fallbacks never fall on those steps, so nothing changes.
  At other values a fallback sometimes comes a step later. This changes E5e-b3's "one every fallback_after + 1
  steps". A bitten roof also keeps its notch under the extreme tuning that leaves no other roof room for one. Right?
818. **A save near a bite**. Placeholder (`MechaGuppyStairs.save_spot`, `save_crossing`):
  - A grapple save or a revive that would bring the runner down just before a bite that leaves a lane puts them in the
    lane the bite leaves when, from the lane it would bring them down in, they couldn't read the bite and cross: a
    reaction, every switch from there to the lane the bite leaves, `dodge_margin`, half a hurtbox and the dash's reach.
    (Task E5e-f's review: it used to count 1.5 times the crossing from the farthest lane, which, with the dash's reach
    counted and the bite further along, sent a save 25 m short of a bite into its lane instead of the nearest lane that
    leads up, one switch away from it.)
  - A runner who fell into an eaten bite is pulled up into the nearest lane with floor where they come down. In
    practice that is past the gap, in their own lane.
819. **Pickups near a bite** (GDD §10's standard armor rule; task E5e-f's review). Placeholder
  (`MechaGuppyStairs.pickup_spot`, `clear_of_bite`): an armor pickup on a bitten roof never lies where the bite will
  take its lane, and in a lane the bite takes it lies far enough short of the gap that a runner who grabs it (2 m
  either side of it) still has every switch to the lane the bite leaves (none over a full-width bite: its jump),
  `dodge_margin` and the dash's reach before the gap reaches that lane, so one who dashes as they grab it still clears
  the bite; otherwise it comes past the bite. Before, one could land just short of the gap with switches still needed:
  a grab and an escape that couldn't both happen. Right?
820. **The hut's end band** (E5e-b1's placeholder: the 4 m orange band where each run of lanes ends on a hut's
  underside, long and bright so it reads from the hut's start). Task E5e-f's review found it filling up to a quarter
  of the screen with bright orange as the chase camera passes just under it when the rider drops. Placeholder
  (`MechaGuppyLooks`, `END_BAND_*`): up close it is an orange lip at the very end (0.3 m, the decks' edge language)
  with a row of lamps; its 4 m length is a glow card, as bright as the old band, that fades out as the camera comes
  within 16 m. From afar it reads as before; at the drop only the lip shows (bright orange at most 3.8-5.0% of the
  screen there, against 17.4-26.5%). Dimming the band instead turned it red (the edge colour is redder than it looks
  and only reads orange when bright), a red slab overhead. Is that the right look?
821. **The trench's depth** (task E5e-f's review). Placeholder (`MechaGuppyLooks._bite_deep`): a floor bite's broken face
  fades from the tower's dark timber into the sea haze the deeper it goes (most of the way 18 m down), so a full-width
  trench seen from over it reads as a drop, not a dark slab.
822. **Its sounds**: the rise has its own warning sound, guppy_floor_warn (above; task E5e-f's review: one that means
  "this one can kill you", not the rumble of the harmless bite behind and the breach), and the snap reuses guppy_bite,
  its jaws' crunch. Is the knocking and the screech of teeth through the deck the right warning?
823. **Bites skipped**: a bite that can't be warned fairly any more is skipped, as if it had never been planned. That
  happens in an intro (the attacks off), in phase 3 (`attacks_live`) or under an extreme tuning that keeps Mecha Guppy
  too busy. A phase change calls off a bite that is already warned but hasn't started its snap: its warning goes and
  nothing is bitten. One whose jaws are already snapping shut when the phase changes completes, the chunk going as
  warned (task E5e-f's review: called off then, its jaws shut on intact floor).
824. **The par times' rule** (task E5e-f's brief): the brief describes three stars as about 1.2 times the slowest clean
  baiting fight. The suite's rule, kept here, is Hostile Takeover's margin (74/68.6, about 1.08 times) for three stars,
  with 1.2 times the room two stars must leave. The fight is a little longer (up to 4.6 s baiting at 18 m/s, up to 7.7 s
  not baiting), but the par times stay at 177 s, 210 s and the time bonus to 260 s, and they still meet the suite's
  rules: the slowest clean fight at 23.8 m/s is 161.9 s (three stars at 174.6 s by Hostile Takeover's margin, within
  3 s of 177 s), the slowest at 18 m/s 175.7 s (still three stars, by 1.3 s), and the quickest win without baiting
  226.1 s. Which rule is meant for three stars?

### Folded on October 15, 2026 (the October 14 batch, tasks I1–I9)

**I9, the boss armor pickup only after the armor takes a hit** (from `docs/questions/i9.md`)
825. **A phase that begins with the armor down but a shield held** (GDD §10, the standard armor rule; item 251,
  `BossDef.armor_when_unprotected`). A held shield counts as protection at a phase's start, so such a phase schedules
  no pickup, and since I9 its shield's break brings none either. Should a phase begun with the armor down count as
  unprotected even with a shield held? Placeholder: a held shield counts (`BossEncounter.player_protected()`, marked
  `DESIGN-TBD`, and on `BossDef.armor_when_unprotected`).
826. **A hit the upgraded armor survives** (GDD §10, "whenever the player's armor takes a hit"). Placeholder: any armor
  hit schedules the phase's pickup, not only the hit that breaks it, so with 2–3 hit armor the first survived hit
  uses the phase's one pickup. One condition in `BossEncounter._on_movement_event` if the owner meant only the break.

**I3, the menus on a phone; sound on an iPhone** (from `docs/questions/i3.md`)
827. **Should the web demo play through an iPhone's ring/silent switch?** (GDD §11; §2, the web demo.) Safari mutes all
  Web Audio (the demo's music and effects) while the switch is on; the page can ask for "playback" audio
  (`navigator.audioSession.type`, Safari 17+), which plays through the switch, as videos do, and pauses another app's
  audio when the demo's sound starts. The likeliest reason one playtester's iPhone had no music. Placeholder: it plays
  through (the "Web (demo)" preset's `html/head_include` in `export_presets.cfg`, marked `DESIGN-TBD`); removing the
  `<script>` block restores the switch.

**I2, the cyborgs drawn bigger** (from `docs/questions/i2.md`)
829. **Should the other zones draw their cyborgs bigger too?** (GDD §9.2, "Drawn 20% bigger".) Placeholder: the Neon City
  only, `ZoneSkin.cyborg_draw_scale` 1.2 in `data/skins/city_skin.tres`, 1.0 in every other skin (marked `DESIGN-TBD`);
  one number per skin. The model only: hitboxes, bolts and floor use are unchanged. A window cyborg drawn bigger
  reaches further above its window frame, so check each zone's look if it follows.
