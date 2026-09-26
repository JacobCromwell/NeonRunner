# Task Plan: Build Phase 2

**Written:** September 26, 2026, after the design rounds on zones, enemies and the first boss.
**Source of truth:** `docs/GDD_CHECKPOINT.md`. This plan only orders the work and sizes it. If the two disagree, the design document wins; raise the conflict (see "Rules for parallel work").

---

## Kickoff (for the orchestrator)

Paste this into the main build session:

> Read `CLAUDE.md`, `docs/TASK_PLAN.md`, `docs/GDD_CHECKPOINT.md` and `docs/ARCHITECTURE.md`. You are the orchestrator for build phase 2. Start the "core lane" (B1, then B2, B3, B4, B5, strictly one after another) and, alongside it, up to three tasks from "Wave 1: in parallel". Give each task to a sub-agent with the model and effort level listed here, on its own branch named after the task ID. Review each result against the design document, merge tasks into `main` one at a time, and fold each task's `docs/questions/<task-id>.md` into `docs/OPEN_QUESTIONS.md` when you merge it. Stop and ask the owner only for things marked "owner" or for design gaps you can't cover with a marked placeholder.

---

## Model tiers

| Tier | Model and effort | Use for |
|---|---|---|
| **T1** | Opus 5.5, **max** effort | Level generator fairness, runtime track changes, boss fights, anything where a subtle bug makes the game unfair |
| **T2** | Opus 5.5, **high** effort | New enemies, zone skins (art built in code needs taste), UI features, tools that need judgment |
| **T3** | Sonnet 5, **high** effort | Well-specified, self-contained work: small tools, process docs, option sheets |
| **T4** | Haiku 4.5 | Pure data entry (numbers in `.tres`/`.json` files), renames, doc touch-ups |

- The orchestrator (main session) runs on Opus 5.5 at max or extra-high effort, and reviews every task before merging.
- Following the owner's rule of thumb, the plan errs toward the stronger tier: T3 and T4 are used only where the task is genuinely simple.
- **Claude Fable 5.1** is also available. It is more capable than Opus 5.5 but costs about 2.5× as much per token. It isn't assigned anywhere; keep it in reserve for a T1 task that Opus fails at twice.

**Sizes:** **S** = a few files, one short session. **M** = one focused session. **L** = several files across systems, possibly more than one session. **XL** = split into the listed steps, each merged on its own.

---

## Rules for parallel work

These are also in `CLAUDE.md`.

1. **One task, one branch,** named after the task ID (e.g. `b2-dangerous-floor`), started from the latest `main`.
2. **Merge one at a time.** Before merging, merge the latest `main` into the task branch, then run `tools/godot.sh test` and `tools/godot.sh smoke`.
3. **The design document has one writer:** design sessions with the owner. Build agents never edit its design sections.
4. **Questions go into `docs/questions/<task-id>.md`,** not straight into `docs/OPEN_QUESTIONS.md`. The orchestrator folds them in when merging, so tasks don't collide on the shared list.
5. **Core files change one task at a time.** These files are touched by many features:
   - `scripts/world/level_generator.gd`
   - `scripts/world/track_builder.gd`
   - `scripts/core/damage_rules.gd`
   - `scripts/run/run_world.gd`
   - `scripts/player/player.gd`
   - `data/campaign/`, `data/zones/`, `data/levels/`
   
   Tasks marked **core** below touch them, and only one core task runs at a time. Other tasks may make a small, clearly separate hook change in one of them (e.g. registering a new skin), but should say so in their summary.
6. **New enemies stay in their own files** (see `docs/ARCHITECTURE.md`, Enemies): `scripts/enemies/<type>*.gd`, `data/enemies/<type>.tres`, `data/patterns/<type>.json`, `tests/suites/test_<type>.gd`. If an enemy needs a shared change, that change belongs to a core task.
7. **Every task ends** with the `CLAUDE.md` summary: what changed, what was verified and how, `DESIGN-TBD` items, risks.
8. **Parallel cap:** run at most 3–4 sub-agents at once. More than that costs more in merging and review than it saves.

---

## What already exists (don't rebuild)

- **Game flow and systems:** screens and game flow, save system, shop and economy, all permanent power-ups, UI kit and HUD, player model on the shared humanoid rig, music and sound effects.
- **Zone skins:** Neon City and Gangland.
- **All 7 original enemies:** electric fence (with generators), cyborg (window cyborgs, hosts), hover truck, Octodog, Sewer Screech, heli drone, Cyborg's Bad Dream.
- **The generator:** seeded and data-driven, for any lane count, with fairness tests.
- **Slots only:** bosses and cinematics (`BossDef`, `CinematicDef`, `BossEncounter`, `Cinematic`), and zones 3–6.

---

## Workstreams

### A. Process

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| A1 | **Sub-agent definitions:** add `.claude/agents/` files for the roles in `docs/NEXT_STEPS.md` §5 (architect, gameplay engineer, skin artist, reviewer, helper), each with the model and effort from this plan's tiers. Follow the current Claude Code docs for the file format. **Done:** `architect.md`, `gameplay-engineer.md`, `skin-artist.md`, `reviewer.md`, `helper.md`, and `tool-writer.md` (a sixth role added for T3 work, which had none) in `.claude/agents/`. | – | S | T3 |

### B. Core systems (the core lane)

**B1–B5 run strictly one after another** (they share the generator and track builder). B6–B8 touch different core files and can run beside the core lane, one at a time.

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| B1 | **Campaign restructure.** Six zones and 15 levels (3 / 3 / 2 / 2 / 2 / 3), the level-by-level schedule in GDD §5, zone definitions for Marketplace, Corporate, Dead Zone and Golden Zone (placeholder skins until theirs exist), the Golden Palace as Golden 3, six boss slots, and the difficulty curve over 15 levels. **Core.** | – | M | T2 |
| B2 | **Dangerous floor under ceilings** (GDD §3). | B1 | M–L | T1 |
| B3 | **Narrow ceilings** (GDD §3). | B2 | L | T1 |
| B4 | **Floors that turn into gaps during play** (for Buzz Overdrive, GDD §9.9). | B3 | L | T1 |
| B5 | **Wall fences** (GDD §9.1). | B4 | M | T2 |
| B6 | **Non-lethal "robbed" hit and credit theft** (for the Tithe Collector, GDD §9.12). **Core** (damage rules, score). | B1 | M | T2 |
| B7 | **In-run pickups** (GDD §10). **Core** (run world). | B1 | M | T2 |
| B8 | **Runner-style boss framework** (GDD §10). **Core** (campaign, HUD). | B1 | L | T1 |

**B1: campaign restructure.**
- Needs a way to start a feature partway into a level: cyborgs appear only late in City 1.
- The schedule moves cyborgs to City 1, pulsing fences and window cyborgs to City 3, and fence generators to Gangland 3.

**B2: dangerous floor under ceilings.**
- Remove the "floor under a ceiling is clear" rule and its tests.
- Keep the safe landing zone after every ceiling.
- Guarantee the floor route under a ceiling is always survivable without taking the pad.
- Change the drone pad rule that clears the floor under a pad's ceiling (OPEN_QUESTIONS item 75).
- Re-run the fairness sweep at 3, 5 and 6 lanes.

**B3: narrow ceilings.**
- Ceilings span a range of lanes, and the player can switch lanes only within that range.
- One-lane ceilings are short and relatively safe.
- Pads sit under the ceiling.
- Update the zone skin interface and the City, Gangland and grey-box skins.
- Skins started before B3 lands add narrow ceilings in a small follow-up.

**B4: floors that turn into gaps during play.**
- The generator plans each cut in advance (lane, start, end), so levels stay fair and identical on every attempt. Nothing else is placed in a cut stretch.
- The track builder removes that lane's floor progressively, and the player falls by ordinary physics.
- A skin hook draws the cut, with orange cut edges.
- The floor holds for about a second under a player who just blocked the saw.
- Killing the saw stops the cut where it dies.
- On 3 lanes, two lanes always stay whole.

**B5: wall fences.**
- Pulsing fences on wall sections, on the level clock, with flicker and crackle warnings.
- Full-height from Marketplace 2; partial (low band or high band) from the Corporate zone.
- The EMP switches them off.
- Fairness: never where a ramp launches the player into one while it's on, and never on a wall section with a sign or window cyborg.

**B6: non-lethal "robbed" hit.**
- A new outcome in `DamageRules`: touching the collector takes 25% of this run's credits.
- The collector holds what it took, and returns it plus a jackpot when caught.
- Star thresholds must stay fair with a collector in the level.

**B7: in-run pickups.**
- Armor, shield and grapple pickups spawned on the floor.
- The boss rule: one armor pickup at the start of the final phase, and another 10–15 s after the player's protection breaks, at most once per phase.

**B8: runner-style boss framework.**
- A `BossEncounter` that hosts the normal run world with a scripted arena, so bosses play like the runner.
- A boss health bar and phases.
- Restart on death, plus the final fight's halfway checkpoint.
- Stars from par times and a boss leaderboard entry.
- Credits and score payout.
- No time limit and no escalation while a player struggles.

### C. New enemies

Each runs in parallel with the others once its dependency has merged. Each includes its sounds (in the existing sound style), patterns, tests and a showcase view.

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| C1 | **Barnacle Turret** (GDD §9.8) | B3 | M | T2 |
| C2 | **Buzz Overdrive** (GDD §9.9) | B4 | L | T1 |
| C3 | **Resonator** (GDD §9.10) | B1 | M | T2 |
| C4 | **Gilded Sentinels** (GDD §9.11) | B5, D6a | M | T2 |
| C5 | **Tithe Collector** (GDD §9.12) | B6 | M | T2 |

**C1: Barnacle Turret.**
- Reuses the cyborg's gun (charge-up, bursts, reload), slightly more accurate.
- Pops out of the ceiling and fires only at a player on the ceiling.
- Solid body like a cyborg's; 5 shots at laser tier 1.
- Never on one-lane ceilings; at most 2 per ceiling.
- A mechanical look, plus a fuzzy, cute creature look for Gangland and the Marketplace. The creature look is low-poly tufts, not a fur shader, because of phones and the web build.

**C2: Buzz Overdrive.**
- Revs in view with a red lane warning line, then charges and cuts the floor.
- 20 shots; killing it early saves the floor.
- Claw-immune, can't be stomped, and the dash smashes it.
- Shorter rev time later in the campaign.
- Militaristic look with red angry eye slits.

**C3: Resonator.**
- A floating spire with halos and the three-note chime; red floor shockwaves across every lane.
- It must look like sci-fi broadcast technology, never like a church object.
- Generator rule: no wave arrives on a gap or fence.
- The wave effect must work on the Compatibility renderer.

**C4: Gilded Sentinels.**
- Live statues stand in wall-run-height niches with red eyes; decorative statues never stand at that height.
- A halberd swing across the wall section and the outer lane.
- 15 shots at laser tier 1.
- Uses the Golden Zone's statue kit from D6a.

**C5: Tithe Collector.**
- Darts ahead through dangerous lanes, sucking up credits.
- Catch it for everything it took plus a jackpot.
- Not a heli drone: pads don't affect it, and it has no rotors.
- Introduced in Corporate 2, skips the Dead Zone, returns in the Golden Zone.
- Build it last; it's the first to cut if the budget tightens.

### D. Zone skins and art

Each skin covers:
- floor, gaps, walls and signs, and ceilings (wide and narrow)
- sky and environment, in the palette and mood from GDD §5
- the colour rule that only hazards glow in hazard colours
- motion cues on still floors
- a Compatibility-renderer check with rendered frames
- the build budget test that the City skin has

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| D1 | **Gangland update** to the owner's direction | – | M | T2 |
| D2 | **Marketplace skin** | – | L | T2 |
| D3 | **Marketplace citizens** | D2 | M | T2 |
| D4 | **Corporate skin** | – | L | T2 |
| D5 | **Dead Zone skin** | – | L | T2 |
| D6a | **Golden Zone skin** | – | L | T2 |
| D6b | **Golden Palace interior skin** | D6a | L | T2 |
| D7 | **Cult symbol options** | – | S | T3 |
| D8 | **Music for the four new zones** | – | M | T2 |

**D1: Gangland update.** The owner's direction is browns and tans, lived in, graffiti and plenty of signs of life, with hints that corporate and military interests fund the gangs. Ceilings are the undersides of decaying or bombed-out buildings and overpasses, instead of today's scavenger barge.

**D2: Marketplace skin.**
- Floor: stall roofs and awnings, with gaps between the stalls.
- Walls: shopfronts and casinos.
- Ceilings: building and bridge undersides, a few ships, floating ads.
- Colours: tan, with whites, blue awnings and splashes of colour.
- Decorative signs stay unframed and high, so they never look like hazard signs.

**D3: Marketplace citizens.**
- A tool in `tools/asset_gen/` renders the humanoid rig into flipbook sprite sheets.
- The citizens play in the shop windows at the low part of the walls, with idle loops and reactions to the runner (startled, cheering).
- They are scenery only, switched off on low-end devices, and must pass a performance check.

**D4: Corporate skin.**
- Floor: maglev train roofs or plazas.
- Ceilings: occasional military ships.
- Colours: steel and gunmetal, military olive, sterile white light, and one harsh brand colour.
- Soulless corporate art.

**D5: Dead Zone skin.**
- Colours: black, dark grey and ash.
- Rubble street, embers, smoke and silence.
- Minimal fires, dim and in the background.
- Ceilings: charred remains of buildings and bridges.

**D6a: Golden Zone skin.**
- Colours: white and cream, with red and gold accents. Gold is reflective metal, not glowing neon.
- Floor: golden walkways over water.
- Ceilings: golden bridges and archways, with sparse waterfalls.
- The cult shown openly.
- The decorative statue kit shared with C4.

**D6b: Golden Palace interior skin.**
- A city-sized palace interior (halls, galleries, arches) for Golden 3.
- It plays like any level.

**D7: Cult symbol options.**
- Draw 3–4 cult emblem and colour options in code.
- Render a comparison sheet for the owner, who picks one.
- The chosen symbol then goes into each skin: hidden in logos and ads, and open in the Golden Zone.

**D8: Music for the four new zones.** Code-generated placeholder loops in the existing style, fitting each zone's mood:
- Marketplace: happy and bustling
- Corporate: oppressive
- Dead Zone: eerie and quiet
- Golden Zone: decadent

The owner reviews them.

### E. Bosses and the web demo

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| E1 | **Floating Head** (GDD §10). XL, split into steps. | B7, B8 | XL | T1 |
| E2 | **Web demo release candidate** (GDD §2) | E1 | M | T2 |
| E3 | **Swarm rendering risk test (R4)** | owner's phone | M | T2 |
| E4 | **Sewer Swarm** | design, E3, B8 | XL | T1 |
| E5 | **Marketplace, Corporate and Dead Zone bosses; the final villain** | design | – | T1 |

**E1: Floating Head steps.**
1. Ship and face models.
2. The bombing run, with the searchlight warning.
3. The face-off: eye-laser sweeps and the cyborg drop.
4. Tower baiting and collapse, with the fallback where the laser clips a tower on its own.
5. The pinned stomp windows: tower ramp, then wall jump, then ceiling drop.
6. Phases and damage: stomps take a third each, weapons chip.
7. The propaganda voice and slogans.
8. Defeat and handoff to the outro or demo end screen.

**E2: web demo release candidate.**
- Export the Web (demo) preset.
- Check the Compatibility renderer and the glow in a browser.
- The demo ends after the Floating Head with the store-link screen.
- Smoke-test in a browser.

**E3: swarm rendering risk test (R4).**
- MultiMesh clusters of hundreds of screeches on a mid-range Android phone.
- Needs an Android export and the owner's device.

**E4: Sewer Swarm.** Blocked: the design is still in progress (§10).

**E5: remaining bosses.** Blocked until the owner designs them.

### F. Cinematics

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| F1 | **Cinematic toolkit** | – | M | T2 |
| F2 | **Cinematic content** | owner's story beats | – | T2 |

**F1: cinematic toolkit.**
- A code-driven toolkit: camera paths, actors on the humanoid rig, timed events, skippable.
- It builds on the existing `Cinematic` base.
- Placeholder "arrival" flyovers per zone until the owner describes the story beats.

**F2: cinematic content.** Blocked until the owner describes the story beats.

---

## Order at a glance

**Wave 1 (start now):**
- **Core lane:** B1 → B2 → B3 → B4 → B5.
- **In parallel,** up to three at a time:
  - after B1: B8, then B7
  - D1, D2, D4, D5, D6a
  - D7, F1, A1
  - E3, when the owner can test on a phone

**Wave 2 (as dependencies merge):**

| Task | Starts after |
|---|---|
| C3 Resonator | B1 |
| C1 Barnacle Turret | B3 |
| C2 Buzz Overdrive | B4 |
| C4 Gilded Sentinels | B5 and D6a |
| E1 Floating Head | B7 and B8 |
| D3 Marketplace citizens | D2 |
| D6b Golden Palace | D6a |
| D8 music | anytime |

**Wave 3:**
- B6 → C5 (Tithe Collector)
- E2 (web demo release candidate)
- applying the owner's answers from the placeholder review (T4 for numbers only, T2 if code changes)

**Blocked on design:** E4 and E5 (bosses), F2 (cinematic content).

**The critical path to the web demo:** B1 → B8 and B7 → E1 → E2. The demo depends on the Floating Head more than on anything else, so keep that path moving first.

---

## Still to design with the owner

- **Bosses:** Sewer Swarm (in progress), the Marketplace, Corporate and Dead Zone bosses, and the final villain with its second stage.
- **Cinematics:** story beats for each slot.
- **Placeholder review:** a keep-or-change pass over the numbered items in `docs/OPEN_QUESTIONS.md` §D.
- **Remaining rounds:** player and power-up numbers, screens and stars, audio, mobile and ads, title, accessibility, languages, age rating, budget and check-ins.
