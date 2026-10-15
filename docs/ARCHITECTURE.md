# Architecture (index)

How the game is put together, for anyone (human or agent) adding to it. The rules behind it are in
`CLAUDE.md`; the design is in `docs/GDD_CHECKPOINT.md`.

**How to use these notes.** The notes are split into the parts listed below, in `docs/architecture/`. Don't read
them all: find your topic in the table (or `grep -rn "<word>" docs/architecture/`), then read only that part, or
only the paragraph you need. A reference elsewhere such as "`docs/ARCHITECTURE.md`, Zone skins" or "…, Pace" names
a topic in this table.

## The big picture

```
scenes/main.tscn (scripts/app/main.gd)
  World (Node3D)        runs, bosses and cinematics live here
  Screens (CanvasLayer) the current full screen (title, level select, shop, results, ...)
  Overlays (CanvasLayer) pause menu, revive offer, settings from pause

Autoloads: TouchInput (swipes/taps → input actions), Platform (ads, purchases, leaderboards,
store links, cloud save), Music (music playback), App (state and flow)
```

`App` (`scripts/app/app.gd`) holds the data and moves the player between screens and runs:
title → level select → campaign step (cinematic / level / boss) → results → shop → next step.
After a death: revive offer (item, or rewarded ad on mobile) → run summary → shop → retry (GDD §4).
Screens only call `App` methods; they never change state themselves.

## Parts and topics

| Part | What it covers | Topics |
|---|---|---|
| [`run.md`](architecture/run.md) (42 KB) | A run: the run, speed effects, smooth frames, the hover truck's cost, retries | A run; Speed effects and spectacle; Smooth frames; Measuring; The hover truck's cost on a phone; Retries reuse the built level |
| [`data-and-damage.md`](architecture/data-and-damage.md) (28 KB) | Data and the damage/interaction rules | Data; Damage and interactions: one place |
| [`enemies.md`](architecture/enemies.md) (26 KB) | Enemies: the files of a type, the director, airspace, pace, floor use, dash walls | Enemies; Big attacks take turns through the director; The cyborgs' airspace; Pace; Floor use; Dash walls |
| [`enemies-later-zones.md`](architecture/enemies-later-zones.md) (35 KB) | Enemies: Barnacle Turret, Buzz Overdrive, Gilded Sentinels, Enforcer Truck | A ceiling enemy: the Barnacle Turret; A floor cutter: the Buzz Overdrive; A wall enemy in a niche: the Gilded Sentinels; Behind the runner: the Enforcer Truck |
| [`generator.md`](architecture/generator.md) (47 KB) | The generator: density, placement, picks, pace, fill pass | The generator; Progressive danger density; Ramps; Ceilings over a dangerous floor; Narrow ceilings; Barnacle Turrets; Gilded Sentinels; Enforcer Trucks; Showing windows; Making room; Late starts; Feature weights; A level's newest things get the most picks; Quiet stretches and bursts; Every feature appears; Pace; Busier levels: the fill pass |
| [`generator-track-features.md`](architecture/generator-track-features.md) (62 KB) | The generator: gaps, doodads, floor cuts, wall fences, wall gaps, wider gaps, dash walls, ceiling scenarios | City 1's additive floor gaps; Zone doodads; A runner who dashes through a doodad; Floor cuts; Floor cuts on the track; Wall fences; Wall fences on the track; Side wall gaps; A level's own wall gaps, and the Beach's open walls; Wider gaps; Cyborgs in charge paths; Dash walls; Dash walls on the track; Ceiling scenarios; Ceiling scenarios on the track |
| [`powerups-pickups.md`](architecture/powerups-pickups.md) (4 KB) | Power-ups and pickups | Power-ups; Pickups |
| [`skins.md`](architecture/skins.md) (48 KB) | Zone skins: the shared parts (doodads, dash walls, floor cuts, fences, ceilings, lighting, skies) | Zone skins; Zone doodads' looks; Dash walls' looks; Floor cuts' looks; Wall fences' looks; Ceiling fences' and return pads' looks; Ceilings from their lanes; Nothing below the underside past a far end; The climbing view; A level's darker lighting; A level's own sky; Colours in a skin's own uniforms; Pattern ids; Gangland's ceilings |
| [`skins-marketplace-corporate-deadzone-casino.md`](architecture/skins-marketplace-corporate-deadzone-casino.md) (23 KB) | Zone skins: the Marketplace, Corporate, the Dead Zone, the Casino | The Marketplace; The Corporate zone; The Dead Zone; The Casino |
| [`skins-golden-beach-cult.md`](architecture/skins-golden-beach-cult.md) (30 KB) | Zone skins: the Golden Zone, the Golden Palace, the Beach, the cult emblem and feed, reduced flashing | The Golden Zone; The Golden Palace; The Beach; The cult emblem; The cult's feed; Reduced flashing |
| [`characters-ui-audio.md`](architecture/characters-ui-audio.md) (11 KB) | Characters, UI and audio | Characters, UI and audio |
| [`campaign.md`](architecture/campaign.md) (11 KB) | Campaign, bosses and cinematics: the schedule and slots | Campaign, bosses and cinematics; The schedule; The Hush; The Beach |
| [`bosses.md`](architecture/bosses.md) (21 KB) | Bosses: the framework, building a boss, how the designed bosses fit | Bosses; To build a boss; How the designed bosses fit |
| [`boss-floating-head.md`](architecture/boss-floating-head.md) (13 KB) | Boss: The Floating Head | The Floating Head |
| [`boss-sleep-taker.md`](architecture/boss-sleep-taker.md) (13 KB) | Boss: The Sleep Taker | The Sleep Taker |
| [`boss-the-house.md`](architecture/boss-the-house.md) (14 KB) | Boss: The House | The House |
| [`boss-hostile-takeover.md`](architecture/boss-hostile-takeover.md) (22 KB) | Boss: Hostile Takeover | Hostile Takeover |
| [`boss-sewer-swarm.md`](architecture/boss-sewer-swarm.md) (16 KB) | Boss: The Sewer Swarm | The Sewer Swarm |
| [`boss-golden-convergence.md`](architecture/boss-golden-convergence.md) (40 KB) | Boss: The Golden Convergence (and stage 2, The Magnate) | The Golden Convergence; Stage 2, The Magnate, and the defeat |
| [`boss-mecha-guppy.md`](architecture/boss-mecha-guppy.md) (63 KB) | Boss: Mecha Guppy and Captain Cogs (the climb, the floor bite, the bombs and the bait, phase 3 and the defeat; its files, bot, sounds, hints and suites) | Mecha Guppy and Captain Cogs |
| [`cinematics.md`](architecture/cinematics.md) (28 KB) | Cinematics | Cinematics; The flow; Track space; The stage picks up the slot's look from the zone's data; Cameras; Actors; Reduced flashing and comfort; Writing a cinematic; The arrival flyover; The City outro; Gangland's boss intro; Gangland's outro; The Dead Zone's intro |
| [`mini-games.md`](architecture/mini-games.md) (7 KB) | Mini-games (the volleyball match) | Mini-games; The volleyball match |
| [`economy-platforms.md`](architecture/economy-platforms.md) (9 KB) | Economy and saving; platforms and build flavors; the web demo | Economy and saving; Approved early-economy revision; Platforms and build flavors; The web demo |
| [`tests.md`](architecture/tests.md) (8 KB) | Tests: the runner, the layout cache, timing, general suites | Tests |
| [`tests-bosses.md`](architecture/tests-bosses.md) (28 KB) | Tests: the boss suites | test_floating_head; test_floating_head_faceoff; test_golden_convergence; test_golden_convergence_bait; test_golden_convergence_barrage; test_golden_convergence_magnate; test_golden_convergence_magnate_fight; test_golden_convergence_whole; test_sewer_swarm; test_sewer_swarm_fight; test_sewer_swarm_host; test_sewer_swarm_surrounded; test_sewer_swarm_walls; test_the_house_fight |
| [`tests-features.md`](architecture/tests-features.md) (47 KB) | Tests: enemy, generator and level suites | test_beach_levels; test_buzz_overdrive; test_ceiling_scenarios; test_charge_paths; test_dash_walls; test_doodads; test_enemy_director; test_enforcer_truck; test_fireballs; test_floor_cuts; test_host_releases; test_hover_truck (cost); test_level_cache; test_pace; test_perf; test_phone_screens; test_resonator; test_volleyball; test_wall_fences; test_wall_gaps; test_web_demo; test_wide_gaps; test_zone_shaders |
| [`review-tools.md`](architecture/review-tools.md) (18 KB) | Review tools: smoke runs, showcases, measuring | Review tools |
