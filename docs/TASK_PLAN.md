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
| **T1** | Opus 5.5, **max** effort (agents `architect`, `build-opus-max`, and `reviewer` for reviews) | Core files, the level generator, runtime track changes, boss fights, fairness-critical timing: anything where a subtle bug makes the game unfair |
| **T2** | **Sonnet 5.5, extra-high (`xhigh`)** effort (agents `gameplay-engineer`, `skin-artist`, `build-sonnet-xhigh`) | New enemies and features that don't change core files, zone skins and code-built art, UI features, tools that need judgment |
| **T3** | Sonnet 5.5, **high** effort (agents `tool-writer`, `build-sonnet-high`) | Well-specified, self-contained work: small tools, process docs, option sheets |
| **T4** | Haiku 5.5 (agents `helper`, `build-haiku`) | Pure data entry (numbers in `.tres`/`.json` files), renames, doc touch-ups |

- **Models updated October 7, 2026** (the owner left the choice to the orchestrator):
  - **T2 moves from Opus 5.5 at max effort to Sonnet 5.5 at extra-high effort.** Sonnet 5.5 costs half as much per token ($2 / $10 per million, against Opus 5.5's $4 / $20) and is built for everyday coding and agent work. Sonnet already did well here on T3 work (T-SPEED, FIX1, FIX3), and two Opus runs stopped on the weekly usage limit.
  - **T3 moves from Sonnet 5 to Sonnet 5.5** at the same price, and **T4 from Haiku 4.5 to Haiku 5.5** ($0.10 / $0.50 per million, a tenth of Haiku 4.5's price).
  - **T1, reviews and the orchestrator stay on Opus 5.5 at max effort.** That's where subtle fairness bugs were caught: the Buzz Overdrive's turn overlap (FIX2), and the warm-up that moved a seeded kill (PERF1).
- **Escalation:** a task that turns out to touch core files, fairness-critical timing or a boss moves up to T1. A T2 or T3 task that fails review twice is re-run one tier up.
- The orchestrator (main session) runs on Opus 5.5 at max or extra-high effort, and reviews every task before merging.
- Following the owner's rule of thumb, the plan errs toward the stronger tier: T3 and T4 are used only where the task is genuinely simple.
- **Claude Fable 5.1** is also available. It is more capable than Opus 5.5 but costs 2.5 times as much per token ($10 / $50 per million). It isn't assigned anywhere; keep it in reserve for a T1 task that Opus fails at twice.
- The agent definitions live in `.claude/agents/` (the `build-*` agents take a brief from the orchestrator; the role agents work from the task plan directly).

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
| B9 | **Weapons never set off fence generators** (GDD §9.1, decided September 26, 2026). | – | S | T3 |

**B9: weapons never set off fence generators** (added September 26, 2026, from the owner's design round).
- Auto-fire never targets a generator, and no weapon damage (direct hit or missile splash) sets one off; a stomp or the dash still does. The same rule as for hosts, so an EMP is always the player's choice.
- Sleep Taker (E5c) relies on it.

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
- From the owner's review: a narrow Gangland ceiling is a slab broken off a building.

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
| C6 | **Enforcer Truck** (GDD §9.13, owner, October 4, 2026) | the owner's enemy-versus-enemy charge mechanic (on the owner's machine, to be pushed) | L | T1 |

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
- the cult (GDD §5): its emblem hidden in logos and ads (shown openly in the Golden Zone), and **its feed playing on billboards and in shop windows** (the Cyborg Viewing Devices story, decided September 26, 2026)

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
| D9 | **The cult's feed and emblem in the City and Gangland skins** | D2 | S–M | T2 |

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
- From the owner's review: military ships and props are part of the zone's look (the military presence, and Corporate 2's heavier one), and Gangland's placeholder corporate logo changes to match this zone's brand once it exists (`kit_logo.gdshaderinc`).

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

**D9: the cult's feed and emblem in the City and Gangland skins** (added September 26, 2026, from GDD §5, "Cyborg Viewing Devices").
- The Marketplace skin (D2) builds the feed as a shared piece: the same wordless broadcast on billboards, ads and shop-window screens in every zone. Skins built after it include the feed and the emblem from the start.
- D9 adds the feed to the City and Gangland, and the hidden emblem to the City (Gangland already has it).

**D8: Music for the four new zones.** Also, from the owner's review (GDD §11): **the music dips when the player dies**, and **the level-complete riff plays in each zone's key**. Code-generated placeholder loops in the existing style, fitting each zone's mood:
- Marketplace: happy and bustling
- Corporate: oppressive
- Dead Zone: eerie and quiet
- Golden Zone: decadent

The owner reviews them.

**No more generated songs** (owner, September 28, 2026; GDD §11): D8's tracks are the last generated music. The owner will provide the songs; until then every task uses the existing tracks and creates none. Sound effects are unaffected.

### P. Player and cyborg looks

Added September 26, 2026, from the owner's design round 4 (GDD §9.2 and §11). All three change **looks only**, never gameplay or hitboxes.

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| P1 | **Razor Echo, the new player model** (GDD §11). Brief: `docs/art/BRIEF_RAZOR_ECHO.md` | – | L | T2 |
| P2 | **The ragged screen-head cyborg base** (GDD §9.2). Brief: `docs/art/BRIEF_CYBORG_GANGSTER.md` | P1 | M–L | T2 |
| P3 | **The cyborg zone variants** (GDD §9.2). Brief: the "Zone variants" section of `docs/art/BRIEF_CYBORG_GANGSTER.md` | P2 | L | T2 |

- P1 and P2 may both touch the shared humanoid rig (`scripts/characters/humanoid_*`), so they run one after the other.
- They run alongside the core lane.
- P1 and P2 are finished before the web demo release (E2).

### R. The owner's placeholder review

Added September 26, 2026. The owner reviewed every build placeholder (`docs/OPEN_QUESTIONS.md` §D, "Owner's placeholder review"): approved ones now count as decided (GDD §12), and these tasks build the changes. **Collision stays physical on every surface** (GDD §3): what looks like a hit is a hit, and the wall-runner collision doesn't change.

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| R1 | **Ramps' fading speed boost and the blocked-wall bump** (§3). **Core** (player, generator). | B2 | S–M | T2 |
| R2 | **Small rule changes:** quitting keeps 20% (§4), hosts immune to all weapon damage (§9.7), no screeches in the Neon City (§9.5) | – | S | T3 |
| R3 | **Big attacks of different enemy types take turns** (§9), behind a data switch | – | M | T1 |
| R4 | **Endless mode** (§6). **Core** (track builder, run world). **Deferred** by the owner (September 30, 2026) until the campaign is done. | B5 | M–L | T1 |
| R5 | **Dead Zone 2's remix** (§5), **the newest features get the most picks**, and **Buzz Overdrive in the Golden Zone** (§9.9). **Core** (generator, level data). | R1 | M | T1 |
| R6 | **Take the `DESIGN-TBD` markers off approved placeholders** (GDD §12) | a quiet moment | M | T3 |
| R7 | **Balancing pass** over the 15 levels and the economy | the owner's playtest | M | T2 |

**R1: ramps and the blocked wall.**
- A ramp's speed boost fades away the same way a speed pad's does; the build's placeholder had none (`ramp_speed_boost` is 0). Every generator rule that predicts a ramp's wall run (the credits along it, B5's rule about wall fences after ramps) must include the boost.
- A blocked wall entry plays the clank and a small sideways bump, so the player sees why they didn't get onto the wall.

**R2: small rule changes.**
- Quitting a level from the pause menu keeps 20% of the credits collected, like a death (the confirmation stays, with new wording).
- Hosts are immune to all weapon damage, so a stray shot never releases a Bad Dream (the same declared property as B9's generators).
- No screeches in the Neon City: remove what's left of the City's wall-vent screeches (docs, quick-play notes, the City skin's vents if it draws any).

**R3: big attacks take turns.**
- The major attacks of different enemy types never overlap: the Octodog's charges, the drone's wind-up and barrage, the hover truck's lurch and cannon, the Bad Dream's chase, and the new enemies' attacks as they arrive. `EnemyDirector.major_attack_blocked()` already does this for the Bad Dream; every type opts in.
- **One data switch turns it off** (default on): the owner may revert it after playtesting, since early playtests felt not very challenging. With it off, the game behaves as before.
- A waiting attack must never start its warning and then hold: it waits before its telegraph, and every attack keeps its visual and audio warning.

**R4: endless mode.** It runs until the player dies, with no time limit, and its difficulty keeps climbing. Its scenery cycles through the zones the player has unlocked, changing every few minutes, and each zone brings its own features and rules (no screeches in the City). It pays 20% of the credits collected, like a death, plus a lump sum every 2 minutes survived. Not in the web demo. The track streams ahead like a boss arena's laps (B8), with fair joins between stretches.

**R5: the campaign's shape.**
- Dead Zone 2 (The Hush) has fewer enemies but more hosts and Bad Dream chases, darker lighting, and long silent stretches broken by sudden threats. The darker lighting is a level setting the skin's environment follows (the Dead Zone skin, D5, uses it).
- Beyond the "every feature at least once" guarantee, a level's newest things get the most picks.
- Buzz Overdrive also appears in the Golden Zone (a correction), so its feature is listed in Golden 1–3.

**R6: approved placeholders.** Remove the `DESIGN-TBD` markers of every item approved as is. Items listed under "tune after playtesting" or "later design rounds" keep theirs. Run it when few tasks are in flight, or in batches that skip files other agents are changing.

**R7: balancing pass.** After the owner's playtest. The owner's early playtest felt **not very challenging**, so start from a harder baseline: the difficulty curve (P2 8), enemy numbers and the economy (the "tune after playtesting" list).

### G. The owner's playtest (September 30, 2026)

The owner played every zone and the Floating Head. The feedback is in GDD §3 ("Pace and busier levels"), §4 (free armor), §8 (armor as an upgrade; laser tier 1) and §10 (the Floating Head). **The campaign comes first:** endless mode (R4) waits.

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| E1e | **Floating Head fixes:** a forgiving ramp boarding, a missing route after the first stomp (the fight couldn't be won), armor pickups for a player who starts without armor | – | M | T1 |
| G1 | **Pace and busier levels:** run speed about 21 m/s in the City rising to about 25 m/s in the Golden Zone, enemies and attacks sped up to match, more gaps, obstacles and enemies. **Core** (generator, level data, tuning). | – | L | T1 |
| G2 | **Speed effects and spectacle:** the camera widening at speed, speed lines, camera shake, sparks, a brief freeze on kills, all honouring Reduced flashing | – | M | T2 (Sonnet) |
| G3 | **Free armor** in every level and boss fight, back 30 s after it breaks; the shop's armor becomes an upgrade whose tiers alternate between an extra hit and a shorter wait. **Core** (damage rules), with the shop, save and HUD. | – | M–L | T1 |
| G4 | **Laser tier 1:** a shorter range, and two more tier-1 shots for every enemy but the screech (data) | – | S | T3 |
| G5 | **Zone doodads, the mechanism:** doodads standing in lanes that push the player into a neighbouring lane; placed by the generator so a push never lands on a gap or hazard. **Core** (generator, track builder, player). | G1 | M–L | T1 |
| G6 | **Zone doodads, the art:** each zone's doodads (City: pillars, small buildings, tiny market stalls; Gangland: burned-out cars, broken-down shops; Marketplace: plants, casino machines; the others in their zone's look) | G5 | L | T2 (Sonnet) |

- **Order:** E1e, G1, G3 and G4 first (G1 and G3 are core but touch different files: G1 the generator and level data, G3 the damage rules). G2 when a slot frees. G5 after G1 (both in the generator), then G6. The core lane's B4, B5 and the rest follow G5.
- **R7** (the balancing pass) keeps the economy: after G3, since armor as an upgrade changes the shop.
- **PERF1, lag spikes** (owner, October 2, 2026: "the overall performance of the game is getting worse; lag spikes are more common"): measure each level's frame times against the build before the playtest work, fix the biggest causes without changing what the game decides, add a frame-time overlay for the owner and a frame-time regression suite. T1, ahead of the remaining content.
- **T-SPEED, a faster test suite** (October 2, 2026): the full suite reached about 29 minutes under load (67 suites, 6.1 million checks) against a 40-minute watchdog, and grows with every boss. Make it faster without removing or weakening any check: share the work suites repeat (level layouts built for the same config, seed and lanes), make the heaviest suites cheaper, and let `tools/godot.sh test` run suites in parallel processes. T3 (tests and tools only).
- **G7, wider gaps and enemies in charge paths** (owner, October 7, 2026, answering open questions 352 and 353): a couple of wider, still jumpable gaps in every level, which wreck an Enforcer Truck that follows the player in; and occasionally a cyborg in the path of an Octodog's lunge or a Buzz Overdrive's charge, at least once before the Enforcer's first appearance in Corporate 2. **Core** (the generator). T1.
- **C6b, the Enforcer Truck shows itself** (owner, October 8, 2026): every so often it speeds up into view beside the runner for a few seconds, then drops back, so its model is seen (GDD §9.13). T1 (it blocks a lane while it's there).
- **C6c, room to show itself in every chase** (follows C6b: dense levels left Corporate 2 with 0–1 showings): the generator reserves a showing window in each Enforcer chase that no later pass fills. Core (the generator). T1.
- **C6d, every chase shows its truck** (owner, October 9, 2026, open questions 384–385; follows C6c, 57 of 106 chase runs): a chase with no room for a showing gives its truck to another bait's chase with room, and a truck whose showing would come after its bait arrives earlier so it comes before. Core (the generator's placement). T1.
- **E1g, the Floating Head's salvos** (owner, October 9, 2026): after the first bombing run, the searchlight marks two to four spots at once, one or two bombs each, the nearest first and each later one further along the track, so the player sees the way through before the bombs fall (GDD §10). The owner's follow-ups the same day: harder on 5 or more lanes, spots closer together, later runs a little longer (6.5 s), far circles the same red; then a forced path on 3 lanes and a choice of two lanes from 5. T1 (a boss fight's fairness).
- **G8, level skies** (owner, October 8, 2026): a zone's last level shows its sky turning (City 3 a dawn, Gangland 3 a cloudy blood-red sky, Marketplace 2 a sunset; GDD §5, "Skies show progression"). A level's own sky over its zone's (`LevelConfig.sky`, `data/skies/`), clouds and a glow on the horizon in the sky shader. Level data and the sky shader. T2.

### E. Bosses and the web demo

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| E1 | **Floating Head** (GDD §10). XL, split into steps. | B7, B8 | XL | T1 |
| E2 | **Web demo release candidate** (GDD §2) | E1, P1, P2 | M | T2 |
| E3 | **Swarm rendering risk test (R4)** | owner's phone | M | T2 |
| E4 | **Sewer Swarm** | B7, B8 (E3 sets its crowd sizes later) | XL | T1 |
| E5a | **The House** (Marketplace boss) | B5, B7, B8, C1, D2 (D3 for the cheering citizens) | XL | T1 |
| E5b | **Hostile Takeover** (Corporate boss) | B4, B5, B7, B8, C2, C5, D4 | XL | T1 |
| E5c | **Sleep Taker** (Dead Zone boss) | B7, B8, B9, D5 | XL | T1 |
| E5d | **The final villain** | design | – | T1 |

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

**E4: Sewer Swarm.** Designed (GDD §10, September 26, 2026). The owner decided on October 2, 2026 to build it now with crowd sizes that scale and to size them down later: the phone test R4 (E3) no longer comes first, and later sets the sizes. Two steps: E4a (the clusters, the arena and phase 1), then E4b (phases 2 and 3, the Host, the defeat, the slot).

**E5: the other bosses.** The House, Hostile Takeover and Sleep Taker are designed (GDD §10, September 26, 2026); each is XL, split into steps like E1, and waits for the enemies, mechanics and skin its fight uses. The final villain (E5d) still needs its design.

### F. Cinematics

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| F1 | **Cinematic toolkit** | – | M | T2 |
| F2 | **Cinematic content** | owner's story beats | – | T2 |
| F2a | **The Neon City's outro** (the owner's beats, October 8, 2026) | F1 | M | T2 |
| F2b | **Gangland boss intro** (the owner's beat, October 9, 2026) | F1 | M | T2 |

**F1: cinematic toolkit.**
- A code-driven toolkit: camera paths, actors on the humanoid rig, timed events, skippable.
- It builds on the existing `Cinematic` base.
- Placeholder "arrival" flyovers per zone until the owner describes the story beats.

**F2: cinematic content.** Waiting on the owner's story beats, slot by slot. F2a and F2b have them so far.

**F2a: the Neon City's outro** (owner, October 8, 2026; GDD §6, Cinematics). **Done:** `CityOutro`. The
Floating Head crashes, a roadblock of the game's own enemies bars a side street, and the runner leaps off the
trucks and lands in Gangland. It adds four toolkit features any cinematic can use: wall openings on a stage,
a head turn for the runner, a per-frame hook for a script's props, and cutting to another zone's stretch.
The staging choices are in `docs/OPEN_QUESTIONS.md` §D, items 369–381.

**F2b: Gangland's boss intro** (owner, October 9, 2026; GDD §10, Sewer Swarm, "Intro cinematic"). **Done:**
`SewerSwarmIntro` (`scripts/cinematics/sewer_swarm_intro/`) in Gangland's boss-intro slot, a new slot. At ground
level, screeches burst out of the manholes after the runner (one, then three, then eleven), more and more pour out
and drop from the sky, a wall of them chases the runner down, and one cut shows the Host's glint in the dark heart
of the swarm. It adds one toolkit hook: `_stage_near()`, to keep the street built under props behind the camera.
The staging choices are in `docs/OPEN_QUESTIONS.md` §D, items 387–395.

### H. The owner's requests (October 8, 2026)

From the owner's list in `docs/USER_REQUESTS.md` (October 8, 2026), recorded in the GDD where they change design. Run by a second orchestrator session alongside the main one, so core-file tasks here wait for the main session's core task in flight (G7, the generator) and then take their turn.

| ID | Task | Needs | Size | Tier |
|---|---|---|---|---|
| H1 | **Gilded Sentinels:** warning halved (1.2 s to 0.6 s), and the live statue and its niche brought forward so they read (GDD §9.11) | – | S–M | T2 |
| H2 | **The Resonator's warning sound:** a crackling build-up of fire breaking into a crashing wave, replacing the doorbell-like chime (GDD §9.10) | – | S | T2 |
| H3 | **Buzz Overdrive cuts show the zone below the street,** like an ordinary gap (GDD §9.9) | – | M | T2 |
| H4 | **Two cyborg-type bursts in the air at once** (cyborgs, window cyborgs, Barnacle Turrets; GDD §9.2). Big attacks still take turns. | – | S–M | T1 |
| H5 | **The dash smashes doodads** (GDD §3). **Core** (player). | G7 | S–M | T1 |
| H6 | **Explosions:** one shared yellow-and-red fireball for every explosion, pooled, Compatibility-safe, softened by Reduced flashing (GDD §11) | – | M | T2 |
| H7a | **Dash walls, the mechanism:** generator placement from the Corporate zone, the wall, the crash rule (armor or shield absorbs; otherwise it kills), crumbling into rubble, sounds and a first-encounter hint (GDD §9.14). **Core** (generator, track builder, damage rules). | G7, H5 | L | T1 |
| H7b | **Dash walls, the art:** each zone's building face turned toward the player, from its side-wall kit | H7a | M | T2 |
| H8 | **Weapons hit hosts:** auto-fire targets them and a weapon kill releases the Bad Dream (GDD §9.7). Raised to T1: an earlier release moves the Bad Dream chases the generator plans around. | – | M | T1 |
| H9 | **Sleep Taker:** lights out 50% darker, hands spread along the street, wall gaps and more wall hands, twice the floor gaps (GDD §10). **Core** (small opt-in hooks in the boss framework and level config). | – | M–L | T1 |
| H10 | **The Tithe Collector stays twice as long** (GDD §9.12) | – | S | T3 |

---

## Order at a glance

**Wave 1 (start now):**
- **Core lane:** B1 → B2 → R1 → R5 → B3 → B4 → B5 → R4.
- **In parallel,** up to three at a time:
  - after B1: B8, then B7
  - D1, D2, D4, D5, D6a
  - D7, F1, A1
  - P1 → P2 → P3, one after another (alongside the core lane; P1 and P2 before E2)
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
| B9 generators and weapons | anytime |
| D9 the cult's feed in the City and Gangland | D2 |
| P2 cyborg base, then P3 variants | P1, then P2 |
| R2 small rule changes, R3 big attacks take turns | anytime |
| E5c Sleep Taker | B7, B8, B9 and D5 |

**Wave 3:**
- B6 → C5 (Tithe Collector)
- E5a The House (after B5, C1, D2), E5b Hostile Takeover (after B4, B5, C2, C5, D4)
- E2 (web demo release candidate), after E1, P1 and P2
- R4 endless mode (after B5), R6 approved placeholders (at a quiet moment), R7 balancing (after the owner's playtest)

**Blocked on design:** E5d (the final villain), F2 (cinematic content, apart from F2a's City outro and F2b's Gangland boss intro). **Blocked on the owner's phone:** E3 (E4 goes ahead first with crowd sizes that scale; owner, October 2, 2026).

**The critical path to the web demo:** B1 → B8 and B7 → E1 → E2. The demo depends on the Floating Head more than on anything else, so keep that path moving first. P1 → P2 (the new player and cyborg looks) must also be done before E2.

---

## Still to design with the owner

- **Bosses:** the final villain with its second stage (the other five are designed, GDD §10).
- **Cinematics:** story beats for each slot but the City's outro (GDD §6) and Gangland's boss intro (GDD §10, Sewer Swarm).
- **Placeholder review:** a keep-or-change pass over the numbered items in `docs/OPEN_QUESTIONS.md` §D.
- **Remaining rounds:** player and power-up numbers, screens and stars, audio, mobile and ads, title, accessibility, languages, age rating, budget and check-ins.
