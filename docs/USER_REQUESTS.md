# List of Tasks
NOTE: Mark tasks as done as you complete them.

## Zone & Levels Related
1. [x] First level is too long and should be about 50% of it's current runtime. DONE: City 1 is now 55 seconds instead of 110; other levels are unchanged. Lower earnings are intentional, and economy-test expectations have been updated per your answer below.
2. [x] Octodogs should not appear in the gold zone levels. DONE: Removed from all three Golden Zone levels.
3. [x] There should be more gaps in the first level. DONE: Added encounters and widened gaps, targeting 30% more encounters and 30% more missing lanes per encounter without replacing obstacles. Default-tier rows/lane-gaps: 3 lanes 11/11 -> 15/20; 5 lanes 15/24 -> 20/42; 6 lanes 13/25 -> 17/43. One harder-tier 3-lane layout reaches 25 instead of 26 lane-gaps because existing clearance constraints prevent further widening; this is explicitly reported.

## General gameplay
1. [x] The walls on the side should occassionally have gaps as well. DONE: Playable gaps start in Zone 2, automatically drop wall runners and refuse entry where the wall is missing. Zone 1 and bosses are excluded. Data-driven low frequency and rare bilateral gaps use a simple interval support check.
2. Dash should be upgradable, each upgrade should decrease the cool down.
    Though the cooldown should never be so low that the player could just spam it endlessly.

## Hints
1. [x] Hints should be shown on the screen introducing the level instead of in the middle of a level. DONE: Level introductions show hints before PLAY; mid-run tutorial popups are suppressed.
2. [x] The hints shown on the level screen should relate to the new concepts/enemies/obstables in that level and you should be able to page through the hints with the arrow keys. DONE: New concepts take priority, followed by unseen relevant hints; left/right paging also has click/touch controls.

## Graphical
1. [x] highest tier credits pickup is too hard to see. DONE: 100-credit pickups have a taller cut-gem silhouette with ice-blue facets and dark contrast; other tiers and collection behavior are unchanged.

## Verification

- Latest validation after applying your answers: all six targeted suites passed (26,992 checks), covering City 1 density, playable wall gaps, revised economy, movement, hints and the skin-budget harness. The Zone 2 headless smoke run and patch whitespace check passed.
- Additional delegated campaign/generator/pace/wall-fence checks and Zone 1/boss smoke runs passed. Separate city/corporate/dead-zone skin suites exceeded their existing build-time budgets; baseline timing comparisons also exceeded those budgets, so unrelated performance tuning was not included.
- Previous validation before your answers ran 19 affected suites: 18 passed; the economy suite failed two affordability checks (2 failures out of 1,718,940 checks). Those expectations have now been revised, and the economy suite passes.
- The integrated City 1 headless smoke run and patch whitespace check passed.
- Credit visibility was checked in rendered before/after images across nine skins using Compatibility rendering, bloom disabled and Reduced flashing enabled. Images are in `build/credits/`; no mobile/browser playtest was performed.

## Open questions for the user

Your answers below have been applied to the floor gaps, wall gaps and economy expectations. Dash upgrades remain unimplemented pending the cooldown progression question at the end of this section. Original answers and historical measurements are preserved.

### More gaps in the first level
- Should "more gaps" mean more gap encounters, more missing lanes per encounter, or both?
Answer: both
- What increase should we target: a percentage increase or a specific number of additional encounters?
Answer: percentage, 30%
- Should additional gaps replace fences/signs, or increase the overall obstacle density?
Answer: Increase density
- Current shortened City 1 (seed 101): 11 gap rows / 11 lane-gaps with 3 lanes, 15 / 24 with 5 lanes, and 13 / 25 with 6 lanes. Before shortening, there were 23 / 26 / 26 gap rows respectively.
That is fine

### Occasional gaps in side walls
- Should gaps remove the playable wall-running surface, or only create visual breaks in scenery?
Answer: remove playable surface. Do not add gaps to boss levels
- For playable gaps, should runners automatically drop, need to jump across, or bridge/re-attach?
Answer: Auto drop
- What frequency and length should gaps have, which levels should introduce them, and can both walls have gaps at the same location?
Answer: Frequency should be low, introduced in zone 2 and beyond. Yes it is possible for both walls to have gaps at the same location, but this should be rare.
- Must gaps always offer safe outer-lane landings and avoid ramps, speed pads, ceilings and attacks that require a wall escape?
Answer: No, players should see the gaps and need to plan ahead.
- Current gameplay permits wall entry/running without checking wall support, so playable gaps require coordinated gameplay and geometry changes, not just scenery changes.
Answer: It sounds like it will add a lot of complexity? If it is easy to add then add it, otherwise Continue not to check this for now

### Dash cooldown upgrades
- How many additional upgrade tiers should dash have?
Answer: 3
- What should each upgrade cost, and what should each tier's cooldown be?
Answer: Cost should be 800, 1000, 1200
- What minimum cooldown should enforce the no-endless-spam requirement?
Answer: 3 second minimum
- Current dash lasts 0.6 seconds, adds 8 m/s and has an 8-second cooldown measured from activation. It has one purchasable tier at a placeholder price of 1,800 credits. No approved upgrade curve or minimum cooldown exists.

### Economy impact of the shorter first level
- May we make a City 1-only credit adjustment to preserve early armor/laser affordability while keeping its new 55-second duration, or should the reduced early earnings be intentional?
Answer: It is intentional.
- Controlled comparison at seed 101 / 5 lanes: available City 1 credits fell from 556 to 341. The economy test's good-run wallet after City 1 fell from 489 to 339 (armor costs 350); the cumulative wallet after City 2 fell from 950 to 800 (laser costs 900).
- These two economy checks now fail because of the requested shortening. Prices, rewards and credit tuning have not been changed without approval.
Answer: Change the tests to reflect the new changes.

Implementation result: Rewards and prices are unchanged. After the approved floor-gap increase, the default 5-lane good-run wallets are 372 after City 1, 833 after City 2 and 1,495 after City 3. Armor I remains affordable after City 1; the laser affordability expectation now moves from City 2 to City 3.

### Remaining unanswered question: dash cooldown progression
- You approved three additional upgrades costing 800, 1,000 and 1,200 credits, with a minimum cooldown of 3 seconds. What should the exact cooldowns for the four total tiers be?
- Option A: 8 / 6 / 4 / 3 seconds.