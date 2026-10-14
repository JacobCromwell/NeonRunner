# Open Questions

Questions that need the owner's answer. Sorted on October 14, 2026, when the list had grown to 794 items: the owner
is happy with the gameplay, so everything whose placeholder works moved out.

Item numbers are permanent: code comments, tests and the GDD cite them ("`docs/OPEN_QUESTIONS.md` item 628", "FB 73").
An item lives in exactly one of three files, under its original heading and number:

- `docs/OPEN_QUESTIONS.md`: the few questions that need the owner (work waits on them, or the placeholder gets
  costlier to change later).
- `docs/OPEN_QUESTIONS_DEFERRED.md`: still technically open, but the placeholder works and nothing waits on it
  (tuning, names, looks, feel). **The placeholder stands as built** until the owner reopens it while playtesting.
- `docs/OPEN_QUESTIONS_ANSWERED.md`: answered, approved, superseded, or notes that ask nothing.

To find a cited item, search the three files: `grep -n "^628\. " docs/OPEN_QUESTIONS*.md` (build phase 2 items have
no prefix; "GB n" and "FB n" are in their own sections). **Don't read these files whole.**

**New questions** from a task go in `docs/questions/<task-id>.md` (see `CLAUDE.md`). When the task merges, the
orchestrator gives each one the next free number (**749** after the sort; raise it here when you use one) and files it
here only if work waits on it or its placeholder will be costly to change later; otherwise in
`docs/OPEN_QUESTIONS_DEFERRED.md`. When the owner answers an item, record the answer in the GDD and move the item
to `docs/OPEN_QUESTIONS_ANSWERED.md` with the answer.

## Needs the owner (summary)

| Item | Question |
|---|---|
| 16 | Should the shop prices and completion payouts be rebalanced for 15 levels, given the current 100 + 25 per level payout and two-zone prices? |
| 231 | Do Poki and CrazyGames allow store links in the demo, and is the itch.io three-tile end screen right (placeholder: one build, three store tiles)? |
| 238 | What should each zone's arrival cinematic show (placeholder: one shared 9.5 s flyover of the zone's skyline for every zone)? |
| 330 | Should a level open behind a short loading card (zone name on its colour) while it generates, given phones take several times longer than the dev machine? Placeholder: no card, screen holds still. |
| 336 | Should weapons be able to end a boss's phase (saving one stomp), everywhere or only per boss? Placeholder: allowed for every boss except Hostile Takeover, where only stomps and counted big hits end phases. |
| 379 | Should the web demo play the Zone 1 outro (landing in Gangland) before the store links, as now, or go straight to the store links? |
| 395 | Should the other zones' bosses get intro cinematics like the City and Gangland have; currently only those two do? |
| 483 | Should an armor pickup be scheduled when the shield breaks while armor remains (current placeholder, generous), or only when the last armor is lost as the GDD reads? |
| 575 | Do you want to design the Beach boss (fight, name, payout) now, given a placeholder card with no stars? |
| 576 | What should happen in the Beach's outro (and its intro), given the Dead Zone intro opens on the runner in a crater and the outro is currently a placeholder card? |
| 608 | Should GDD 9.11's line be changed to allow decorative statues in alcoves at wall-run height, as built? |
| 680 | Should the Beach zone (Tiki Tides, Sunset Strip) get dash walls, given its open side walls; currently it has none and the default box look. |

## The items in full

### From build phase 2 (September 26, 2026)

**Campaign restructure** (from B1: six zones, 15 levels)
16. **The economy over 15 levels** ("From the full build" items 10–11). Completion pays 100 + 25 per campaign
    level, so Golden 3 pays 450; prices were set for a two-zone campaign. Needs a balancing pass.

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

**Lag spikes** (from PERF1; numbers in `data/tuning/speed_fx.tres` and `data/tuning/performance.tres`, F6; the frame-time graph is F7 in debug builds, or `--frame-graph`)
330. **A level's start** (GDD §4, the flow into a run). A level is generated and built in the frame after
    the player picks it (0.3 to 1.8 s on the dev machine, the first level of a session the longest), and
    now also readies what it will need later instead of hitching mid-run (its enemy types' scripts and
    looks, 0.1 to 0.9 s more on the dev machine the first time in a session, and on a real renderer its
    shaders, drawn once in its first frame); a phone takes several times longer. The level select holds
    still meanwhile, then the run starts at once. Should a level open behind a short loading card (the
    zone's name on its colour, shown while it loads), or stay as it is?
    - **Placeholder:** no loading card; the screen holds still until the run starts, as before.

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

**The Neon City's outro** (from F2a; the owner's beats, GDD §6 Cinematics; numbers in `data/cinematics/city_outro_tuning.tres`, code in `scripts/cinematics/city_outro.gd` and `city_outro_set.gd`; review with `tools/showcase/cinematic_review.tscn -- --slot=city/outro`)
379. **The web demo.** The demo ends after Zone 1, and the outro belongs to Zone 1, so the demo plays it (Gangland's
    landing included) before the store-link screen, a teaser for Zone 2. Wanted, or should the demo go straight to
    the store links (GDD §10's wording could be read that way)?

**Gangland's boss intro** (from F2b; the owner's beat, GDD §10 Sewer Swarm "Intro cinematic"; numbers in `data/cinematics/sewer_swarm_intro.tres`, code in `scripts/cinematics/sewer_swarm_intro/`; review with `tools/showcase/cinematic_review.tscn -- --slot=gangland/boss_intro`, or play `--level=gangland/boss_intro`)
395. **Slots.** This answers part of items 11 and 200: Gangland now has a boss intro as
    well as the City. Should the other zones' bosses get one?

**The Golden Convergence: the polish pass** (from the review of E5d-a, b and d; built in the polish pass after the fight's review. Numbers are in `data/bosses/golden_boss_tuning.tres` (`GoldenConvergenceTuning`, F6 in the fight) or constants marked `DESIGN-TBD` in code, as each item says)
483. **The armor pickup after a shield break** (GDD §10, Armor pickups: "triggered when the player has lost all
    their armor"). The boss framework schedules the 22 s armor pickup when the shield breaks too, while the runner
    still wears armor: `BossEncounter._on_item_used` answers both items, and the player reports the shield on every
    break but the armor only once it's gone. With one pickup a phase (`armor_pickups_per_phase`), a shield break
    uses up the phase's pickup, so an armor break later in that phase brings none. Is this more generous timing
    wanted, or should only losing the last of the armor schedule it, as the GDD reads? (Changing it changes the
    framework, so every boss with the armor rule.)

**The Beach joins the campaign** (from D10c; the owner, October 9, 2026: "put the beach between the corporate and dead zone. Keep in mind that there will be a boss battle for the beach, but it has not yet been created. Do not worry about any new enemies at this time. Create level names that fit the theme."; GDD §5, §6 and §10; `data/campaign/campaign.tres`, `data/zones/beach.tres`, `data/levels/beach_1.tres` (Tiki Tides) and `beach_2.tres` (Sunset Strip); play `--level=beach/1`)
575. **The boss** (GDD §10: "there will be a boss battle for the beach, but it has not yet been created"; task E5e,
    blocked on design). Placeholder: `data/bosses/beach_boss.tres`, "The Beach's boss", unbuilt: the campaign shows
    its placeholder card and passes through it to the Beach's outro and the Dead Zone, with no stars. Its fight,
    name and payout are to be designed. When it's built, `test_app_flow` and `test_screens` need another unbuilt
    stand-in for their placeholder-card checks.
576. **The cinematics** (GDD §6). Placeholder: `beach_intro.tres` ("The Beach") plays the arrival flyover in the
    Beach's look, its card "ZONE 6 · Beach"; `beach_outro.tres` ("Last light") is a placeholder card (after the
    boss, as the sun goes down, heading for the Dead Zone); Corporate's outro card now heads for the Beach. The
    beats are still to come; the Dead Zone and the Golden Zone now show as zones 7 and 8 on their cards. The Dead
    Zone's intro (task F2c, GDD §6) opens on the runner lying in a smoking crater, put there by "a cinematic before
    this one": with the Beach in between, that is now the Beach's outro, not Corporate's.

**The Gilded Sentinels' shorter warning and lit niches** (from H1, owner, October 8, 2026, GDD §9.11; numbers in
`data/enemies/gilded_sentinel.tres`)
608. **GDD §9.11 no longer matches the build in one place** (predates H1): "decorative statues never stand at wall-run
    height". Since the owner's earlier request, decorative statues stand in alcoves at the bottom of the walls,
    0.1–3.5 m up, which is wall-run height; they're told from live ones by the red eyes and the warning. Should
    the GDD line change to match?

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
