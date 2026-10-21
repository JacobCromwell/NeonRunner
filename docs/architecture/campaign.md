# Architecture: Campaign, bosses and cinematics: the schedule and slots

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Campaign, bosses and cinematics

`Campaign` lists `ZoneDef`s; each built zone contributes steps: optional intro cinematic, its
levels, optional boss-intro cinematic, the boss, optional outro cinematic. Step ids (`city/1`,
`city/boss`, ...) key the save file, so they never change (but for a zone's new place in the campaign, which a
save migration follows: Economy and saving, Saves from before the Casino). A cinematic slot added after a save had passed it
(Gangland's boss intro, F2b) counts as done when the step after it is (`App.step_done`), so the save keeps what it
unlocked and Continue doesn't go back over it. Difficulty comes from a campaign-wide curve
plus each level's `difficulty_bias`; `enemy_scaling` runs 0 → 1 across the campaign. A level off the curve
(`LevelConfig.off_curve`: the Beach's and the Terminal's, below) plays at its own.

The campaign (GDD §5) has nine zones, with ids other tasks rely on: `city`, `gangland`,
`marketplace`, `casino`, `corporate`, `beach`, `dead_zone`, `terminal` and `golden`, with 3, 3, 2, 2, 2, 3, 2, 2 and 3
levels in `data/levels/<zone id>_<n>.tres` (Golden 3 is the Golden Palace). Every zone has intro and outro
cinematic slots (every boss also an intro slot: built for the City's, Gangland's and the Casino's, empty and skipped
for the rest, Empty boss-intro slots below) and a boss slot from GDD §10's roster, but the
Marketplace, which leads straight into the Casino (owner, October 8, 2026): its steps run from
Marketplace 2 to its outro, and The House is the Casino's boss (`casino_boss`); the Beach's boss is Mecha Guppy and
Captain Cogs (`beach_boss`, Bosses below). The Terminal has no boss either (owner, October 20, 2026). A zone's music
track is named after its id, and every zone has one (a track the music library doesn't list is skipped
quietly and the music already playing carries on: the Terminal's until task O4 adds it). Only the City is in the web demo. The curve runs 0.1 → 0.9
over the 17 levels on it (FB 4, FB 5; the Beach's three, task D10c and its volleyball match, D10e, are off it, so the Beach moved no other
level). When the Casino's two came in, task K2 re-spaced it linearly (each
existing level's difficulty and `enemy_scaling` moved, Marketplace 2 from 0.50 to 0.45 and Corporate 1 from
0.56 to 0.60; the enemy numbers that step at a threshold of `enemy_scaling` were moved in data so every
existing level keeps its own, `docs/OPEN_QUESTIONS.md` §D, items 519-521). The owner then ruled that no
level gets easier when levels are added (GDD §6, October 9, 2026), so `difficulty_curve_exponent` bends it
(0.79, task K4, DESIGN-TBD): every level is at least as hard as on the 15-level linear curve before the
Casino (Marketplace 2 binds that up to about 0.84), the Marketplace a little harder (0.469 and 0.516, from
0.443 and 0.500), City 2 to Gangland 3 0.03-0.04 harder, Corporate 1 to Golden 2 0.02-0.10 harder, City 1
(0.05) and Golden 3 (0.85) as they were, and each level at least 0.04 harder than the last (Golden 3
aside). `enemy_scaling` stays linear (K2's thresholds stand), and `test_campaign` checks every level
against the 15-level curve (`docs/OPEN_QUESTIONS.md` §D, item 528: the table and why 0.79). Which level is the peak
(proposed: Golden 2, with Golden 3 a little below it) and the remaining level lengths (DESIGN-TBD, run
120–150 s) stay open.
Zone & Levels 1 shortens only City 1 (Rooftop Rush) from 110 to 55 seconds via
`data/levels/city_1.tres`'s `duration_seconds`; all other level durations stay unchanged.
At the City's 21 m/s this moves its finish line from 2310 to 1155 metres. The existing generator
and distance-based completion use that value without changing speed, difficulty, clear distances,
or the fractional starts of cyborgs and doodads. These are running times without speed-changing
power-ups or pauses, excluding cinematics and the completion delay. The levels then totalled 34.1 minutes;
with the Casino's 145 and 150 seconds they total 39.0, with the Beach's 145 and 150 seconds 43.9, and with its
volleyball match's 55 (a flawless match, task D10e) 44.8 (GDD §5: about 45), and with the Terminal's 140 and 145
seconds 49.6 (task O1, DESIGN-TBD, `docs/questions/o1.md`; `test_campaign` allows 47-52).

**The schedule** (GDD §5) is each level's `features` list, in the order the campaign introduces them:
a feature once introduced stays in every later level, bar the exceptions the design gives (screeches
come from manholes only in street zones and from wall vents, `screech_vents`, elsewhere, with none in
Marketplace 1; the Tithe Collector skips the Dead Zone; Zone & Levels 2 excludes Octodogs from
Golden 1–3, including the Golden Palace). Octodogs remain enabled from Gangland 2 through the
Dead Zone, the Beach's remix included. Removing only `octodog` from the three Golden resources excludes both dog patterns and
their generator rules, including the guaranteed-dog fallback; the director therefore has no dogs
to warm or spawn there. Speed pads and all other Golden features remain enabled. The Buzz Overdrive appears from Corporate 1
through the Dead Zone and the Golden Zone, the Golden Palace included (GDD §9.9, corrected), and in the Beach between
Corporate and the Dead Zone (its remix; GDD §9.9 names it, `docs/OPEN_QUESTIONS.md` item 579). The Casino
introduces nothing (GDD §5: it reuses the Marketplace's enemies, owner, October 8, 2026): its two levels
play Marketplace 2's features with no starts of their own (task K2, DESIGN-TBD until the owner says what
each adds), and `test_campaign` exempts it from "a new enemy per zone" and "something new per level", as it does the
Beach (owner, October 9, 2026: "do not worry about any new enemies at this time"; item 565). Each
level introduces its new features at starts of their own (`feature_starts`, see Late starts under The
generator; City 1's cyborgs come late in the level), and its newest features get the most picks
(the campaign's recency curve, under The generator). `test_campaign` holds the schedule table and its
exceptions, checks the features' order, and checks that every level has each of its features at 3, 5
and 6 lanes, on its own seed and over a seed sweep (Every feature appears, under The generator).
Features of enemies and mechanics still to be built (`LevelConfig.PLANNED_FEATURES`) are listed already
and do nothing until their code and patterns exist. The wall fences' `wall_fences` and
`wall_fences_partial` are built (B5; The generator, Wall fences).

**The Hush** (Dead Zone 2; GDD §5: "a quiet, eerie remix: fewer enemies but more hosts and Bad Dream
chases, darker lighting, and long silent stretches broken by sudden threats") brings nothing new; its
remix is its own data, which no other level uses: quiet stretches and bursts (`quiet_seconds` and the
rest, with its hosts as its quiet feature), hosts picked more often (`feature_weights`), and its
`darkness`, and its three extended wall runs, for which it leaves out the heli drone (the owner, October 19 and 20,
2026: The generator, Extended wall runs). A Bad Dream
chase starts only when the player kills a host (GDD §9.7), so more chases come
from more hosts, standing alone in the quiet stretches where one is easy to reach; the host rules
still fit one chase at a time. All DESIGN-TBD (`docs/questions/r5.md`). Endless mode, which copies the
furthest zone's last level, leaves the remix out (`App.start_endless`: no quiet stretches, no quiet
features or their weights, no extended wall runs and the drone back, no darkness), so endless in the Dead Zone plays
as it did before.

**The Beach** (task D10c; the owner, October 9, 2026: "put the beach between the corporate and dead zone", a boss
battle to come, "do not worry about any new enemies at this time"; GDD §5). `data/zones/beach.tres` (id `beach`, the
Beach skin, 23.8 m/s) is zone 6, between Corporate and the Dead Zone: its intro (the arrival flyover), Tiki Tides,
the volleyball match (*Net Gains*, `data/levels/beach_2.tres`, task D10e: a mini-game, Mini-games below; the owner,
October 10, 2026) and Sunset Strip (`data/levels/beach_1.tres` and `beach_3.tres`: seeds 801 and 802, 145 and 150 s,
the open walls of task D10b, `wall_gap_tuning` under The generator, Side wall gaps; Beach 1 in the zone's daylight,
Sunset Strip under `data/skies/beach_sunset.tres`), its boss slot and its outro. Sunset Strip was `beach/2` until
the match came in (its records follow it: Economy and saving, Saves from before the volleyball match). It is a remix of everything before it, Corporate 2's
features with no introductions, and the one zone that brings no new enemy (GDD §5's exception).
Its levels are **off the curve** (`LevelConfig.off_curve`), so every level and boss that was in the campaign before
plays exactly as before:
- `Campaign.configure` gives a level off the curve its own `difficulty` (plus the tier's bonus; its
  `difficulty_bias` isn't read) and `enemy_scaling`: the Beach's 0.71 and 0.72, 0.71 and 0.73, strictly between
  Corporate 2's (0.695, 0.6875) and Dead Zone 1's (0.737, 0.75) on the curve as task K4 bent it for the Casino;
- the curve spans the levels on it (`curve_level_count()`: 17 of `level_count()`'s 20, against
  `planned_level_count()`'s 20; 17 of 22 since the Terminal), and a level off it takes the place of the level on it
  before it
  (`CampaignStep.level_index`: Corporate 2's, so its completion bonus too);
- a level off the curve counts every level before it, in the order they're played, for its feature ages, and a level
  on it only the levels on it, so the Dead Zone and the Golden Zone keep their ages and recency
  (`Campaign.feature_ages`); a mini-game level (the volleyball match, off the curve with no features) counts for no
  level's ages, so Sunset Strip kept its own when the match came in before it; a boss fights at the scaling of the
  level before it (`Campaign.level_scaling`: the Beach's boss slot at Sunset Strip's).
So the other 17 levels keep their difficulty, enemy scaling, run speed, feature ages, recency and completion bonus,
and every one of their layouts in `tools/measure/level_pace.gd --dump` (at 3, 5 and 6 lanes, on its own seed and four
others) is byte-identical; `test_campaign` also builds the campaign without the Beach from the same data and compares
every level and boss with it (task D10d: with the Casino in, every non-Beach step configures exactly as on main), and the
campaign without the volleyball match (task D10e: every level and boss, Sunset Strip included, configures as before it). A save from before the Beach keeps what it had open (`App.step_done`: the Beach's outro counts
as done once the Dead Zone's intro is), and its Continue offers the Beach's intro. DESIGN-TBD
(`docs/OPEN_QUESTIONS.md` items 569–577): whether the curve is later re-spread over all its levels (19, the volleyball match aside), the Beach's numbers, its
completion bonus, Continue for old saves, its boss, cinematics and music.

**The Terminal** (task O1; the owner, October 20, 2026; GDD §5, Zone 8). `data/zones/terminal.tres` (id `terminal`,
24.6 m/s, music `terminal`, the Dead Zone's skin until task O4's) is zone 8, between the Dead Zone and the Golden
Zone: its intro (the arrival flyover), Rubble Line and Last Stop (`data/levels/terminal_1.tres` and `terminal_2.tres`:
seeds 901 and 902, 140 and 145 s) and its outro (a card), **no boss** (the Marketplace's way: no boss or boss-intro
slot). Its levels are off the curve like the Beach's, strictly between Dead Zone 2 and Golden 1 (difficulty 0.79 and
0.805, enemy scaling 0.83 and 0.85, completion bonus Dead Zone 2's; danger density dials 0.37 and 0.38, which add
nothing there yet: none of the usual enemies and no fillers), so every other level plays exactly as before.
The Terminal's rules are level data: its own pattern folder (`patterns_path` = `data/patterns/terminal/`: open track
with credits and a one-lane ceiling, none of the core patterns' holes, fences, signs or enemies), two wider gaps for
its couple of holes (`wide_gaps`), no dash walls, every ceiling one lane wide (`narrow_ceiling_share` and
`one_lane_ceiling_share` 1), its arch walls (`wall_gap_tuning` = `data/tuning/terminal_wall_gaps.tres`, Arches) and
**no wall running** (`LevelConfig.wall_running` off: The generator, Side wall gaps, Arches and boundary walls). Its
`debris_maze` (task O2: The generator, The debris maze; its own numbers per level, `debris_maze_tuning`), with doodads
that stop the runner (`doodads_stop`: Damage and interactions) and stand lower (`doodad_height` 1.7 m), and its
`centipede` (task O3: the Cybernetic Centipede, which waits in the maze: In the debris maze); the Golden Zone leaves
both out. A save from before the Terminal keeps the Golden Zone open (Economy and saving, Saves from before the
Terminal). `test_campaign` checks the Terminal's steps, numbers and content, and `test_terminal_levels` its levels at
3, 5 and 6 lanes (arches, stumps, no wall running in the run). DESIGN-TBD (`docs/questions/o1.md`): all the numbers.

**Empty boss-intro slots** (task I8; the owner, October 14, 2026, item 395: every boss gets a slot for an intro
cinematic, to fill when the owner adds the beats). The City's, Gangland's and the Casino's (The House's, task F2i,
October 17, 2026) boss intros play; Hostile Takeover's, the Beach's, the Sleep Taker's and the Golden Convergence's are `data/cinematics/<zone id>_boss_intro.tres`,
set as the zone's `boss_intro`, with no `scene` and `skip_while_empty = true` (`CinematicDef.is_skipped()`: marked and
not built). `Campaign._build_steps` builds no step for a skipped slot, so the campaign goes from the zone's last level
straight to its boss: no card, no black frame, no delay, nothing recorded, and no step id or index changes for the
steps already there (the Marketplace has no boss, so no slot). `Campaign.empty_slots()` lists the skipped slots (the
level select shows them as dim, unpressable "EMPTY SLOT" tiles in debug builds; `cinematic_review` says a slot is
empty). **Filling one is data only:** make a scene whose root extends `Cinematic` (Cinematics, "Writing a
cinematic"), set the def's `scene`, and the step `<zone id>/boss_intro` appears before the boss. A save from before
that counts it done once the boss is (`App.step_done`: a cinematic slot added after a save had passed it), so the
boss stays open and Continue goes on. The web demo (the City only) is unchanged. `skip_while_empty` works on a
zone's intro and outro too; the existing ones don't set it and keep their placeholder cards.

A `BossDef` or `CinematicDef` with an empty `scene` shows a placeholder card, which the player
continues past. A cinematic is a scene whose root extends `Cinematic` (emit `finished`, support
`skip()`), built with the cinematic toolkit (Cinematics, below): every zone's intro but the City's, Gangland's, the
Marketplace's and the Dead Zone's, and the City's boss intro, play a placeholder arrival flyover, the City's outro plays its own scene (`CityOutro`, task F2a),
Gangland's boss intro plays its own (`SewerSwarmIntro`, task F2b), the City's, Gangland's, the Marketplace's and the Dead Zone's
intros their own (`CityIntro`, F2h; `GanglandIntro`, F2g; `MarketplaceIntro`, F2f; `DeadZoneIntro`, task F2c), Gangland's and the Beach's outros theirs (`GanglandOutro`, F2d; `BeachOutro`, F2e), and the other outros are
still cards. A boss is
built on the boss framework (Bosses, below). Every zone's boss is built (its step plays the fight; the Beach's
Mecha Guppy and Captain Cogs last, task E5e-c), each slot holding the phases GDD §10 gives its boss and its
armor-rule delay. With no placeholder slot left, `test_app_flow` and `test_screens` check the boss slot's card on an
unbuilt stand-in in the Beach's slot (a copy of its `BossDef` with no scene, put back after;
`docs/OPEN_QUESTIONS.md` item 575). A fight
still being built names its scene in the slot's `preview_scene` instead of `scene`: the campaign keeps the card,
and debug builds play the fight with `--boss=<boss id>` as quick play (`BossDef.preview()`), so nothing is recorded.
