# Next Steps, Risk Tests & Provisional Build Plan

## 1. Immediate next steps

1. **Save these four files** in a new project folder:
   ```
   neon-runner/
     CLAUDE.md
     docs/GDD_CHECKPOINT.md
     docs/OPEN_QUESTIONS.md
     docs/NEXT_STEPS.md
   ```
2. **Continue the design sessions in claude.ai**, in this order: Zones → Bosses → Player character → Remaining power-up numbers → Screens → Audio → Mobile specifics → Build planning and budget. Start each new session by attaching `GDD_CHECKPOINT.md` and `OPEN_QUESTIONS.md`, so nothing depends on the memory of an old chat.
3. **Optional but recommended: start a grey-box prototype now**, in parallel with the remaining design work. The core movement (lanes, walls, ceiling, jump, slide, gaps, collisions) is fully specified. Finding out early whether it *feels* good is the most valuable test in the whole project, and changes are cheapest now. It uses plain boxes and colored materials, with no art.

## 2. Software to install (Windows)

| Tool | Why | When |
|---|---|---|
| Git | Version control, needed by Claude Code | Now |
| Claude Code | The builder | Now |
| Godot 4 (latest stable, standard build, not .NET) | Engine; a single program with no installer | Now |
| Godot export templates | Needed to export builds | First export |
| Android build tools (Android Studio or command-line SDK plus a JDK) | Android builds | During the risk tests below |
| An Android phone (mid-range, ideally) | Real performance testing | During the risk tests below |
| Cloud Mac build service account | iOS builds | Near release |
| Apple Developer / Google Play / Steamworks accounts | Store publishing | Before release candidates |

No Blender or other 3D software is required.

## 3. Phase 0: Risk tests (do these before building the full game)

Each test is small, answers one risky question, and is thrown away or folded in afterward.

| # | Test | Question it answers | Why early |
|---|---|---|---|
| R1 | **Core movement grey-box** | Do lanes, walls, ceiling, jump, and slide feel good on PC and touch? | Everything else depends on it |
| R2 | **Web export plus Compatibility renderer glow** | Does the neon glow/bloom look acceptable in a browser build? | The art style depends on it |
| R3 | **Mobile ads and purchases plugins** | Do the community Godot plugins for ads and purchases work on Android (then iOS via cloud build)? | Biggest technical risk for mobile revenue |
| R4 | **Swarm rendering on a phone** | Can MultiMesh clusters of hundreds of creatures hold frame rate on a mid-range phone? | Swarm boss feasibility |
| R5 | **Code-generated model pipeline** | Can code-generated `.glb` models reach the quality bar? Produce a truck, fence, and drone as samples. | Validates the whole art approach |
| R6 | **Humanoid animation** | Rigged cyborg with run, shoot, and death animations: code-generated vs a free animation library | Weakest part of the art approach |

## 4. Provisional milestone plan

1. **M0:** Risk tests R1–R6
2. **M1:** Core runner — movement, generator v1, collisions, damage system, credits, one grey-box zone
3. **M2:** Zone 1 vertical slice — final art for Zone 1, electric fence, cyborg, first boss, shop, level-complete screen, HUD, audio
4. **M3:** Web demo release candidate (Zone 1 plus boss, store-link end screen). Public on itch.io, useful for early feedback and marketing.
5. **M4:** Remaining enemies and power-ups
6. **M5:** Zones 2–6+ with their bosses
7. **M6:** Endless mode, difficulty tiers, stars, leaderboards, net worth leaderboard
8. **M7:** Platform integration — Steam, ads/purchases, store builds, cloud saves
9. **M8:** Balancing, polish, performance, accessibility, store pages, launch

## 5. Provisional orchestration plan (to finalize after the budget question)

**Build phase 2 (from September 26, 2026) runs from `docs/TASK_PLAN.md`,** which assigns a model and effort level to every task.


Claude Code lets each sub-agent use a different model (`opus`, `sonnet`, `haiku`, or `inherit` from the main session). The principle is to **spend on judgment and pay less for routine work.**

| Role | Model tier | Typical tasks |
|---|---|---|
| **Orchestrator** (main session) | Strongest (Opus-class) | Breaks milestones into tasks, reviews results, guards the design document, decides when to escalate to you |
| **Architect** | Strongest | Core systems: damage/interaction system, generator, platform services layer, save system |
| **Complex gameplay engineer** | Strongest | Bosses, hover truck, Cyborg's Bad Dream, swarm rendering; anything with tricky timing or AI behavior |
| **Gameplay engineer** | Mid (Sonnet-class) | Standard enemies, power-ups, shop, screens, HUD, menus, settings |
| **Asset generator** | Mid | Code-generated models and materials for each zone skin, following the art rules |
| **Tester / reviewer** | Mid | Runs builds headless, writes tests, checks tasks against the design document |
| **Routine helper** | Cheapest (Haiku-class) | File searches, data-file entry (prices, tuning tables), docs updates, renaming, simple refactors |

### Keeping you from being interrupted constantly
- Pre-approve routine permissions in Claude Code's settings (editing project files, running Godot headless, running tests, git commits on feature branches) so sub-agents don't ask minute by minute.
- Keep approval-required actions few: installing new software, adding paid services or plugins, changing the design document, anything touching store accounts, and deleting work.
- Agents follow `CLAUDE.md`: unclear design becomes a `DESIGN-TBD` placeholder plus a question in `OPEN_QUESTIONS.md`, instead of stopping to ask. You answer questions in batches at milestone reviews.

### Cost notes
- Verify current Claude Code pricing and plan limits in the official docs before starting: https://docs.claude.com/en/docs/claude-code/overview
- The biggest cost savers:
  - Tunable numbers kept in data files (cheap models can edit them)
  - Small, well-specified tasks (fewer retries)
  - Not re-reading the whole project each task (agents rely on `CLAUDE.md` and the design document)
