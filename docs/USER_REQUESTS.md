# List of Tasks

The owner's requests. Add new ones at the end as `- [ ]` items, under a dated heading. When an orchestrator
finishes one, it ticks it (`- [x]`), adds a short DONE note, and moves it to `docs/USER_REQUESTS_DONE.md` (same
heading), so this file holds only what is still to do. Code comments citing "`docs/USER_REQUESTS.md`" may mean a
request that is now in the done file.

## Doodad pictures (October 9, 2026)

- [ ] Doodads prefer the lane next to the side wall when it's open, without costing gameplay: not where the generator already has something on that part of the wall or needs it open. Held, by the owner's choice ("art first, placement later"), until the dash-smash branch (`claude/nifty-brahmagupta-i5ov2i`, H5) is resolved, since it changes the same generator, track and player code.

## Wall hop nudge (October 9, 2026)

- [ ] Gently teach the wall hop (jumping off a side wall and straight back on, for an unlimited wall run; GDD §3). Some long walls carry high-value credits further along than one wall run reaches, so a player has to get inventive to collect them (GDD §7, Wall-hop credits). Proposed: from Gangland on, about once a level, on a stretch of wall with no wall gap. Don't patch the wall hop itself; the owner relies on it in every playtest.

## Owner's answers to the open questions (October 14, 2026)

- [ ] **Rebalance the economy for the full campaign** (GDD §7; `docs/OPEN_QUESTIONS_ANSWERED.md` item 16). The shop prices and the completion payouts (100 + 25 per campaign level) were set for a two-zone campaign. Rebalance them for all eight zones with `tools/measure/economy.gd`, so each upgrade first fits about where the campaign needs it. Prices and payouts live in data (`data/shop/catalog.json` and the tuning files). Keep the approved early-economy revision (October 3, 2026) and the laser I price (1,800 credits, first affordable at City 4) unless the curve can't hold them, and report the before and after.
- [ ] **An intro cinematic slot for every boss** (GDD §6; item 395). The City and Gangland have boss intros. Give the other bosses (The House, Hostile Takeover, the Beach's boss, the Sleep Taker, the Golden Convergence) an empty intro slot that the campaign skips until it's filled, so the owner can add their beats later without a structural change.
- [ ] **The boss armor pickup comes only after the armor takes a hit** (GDD §10, standard armor rule; item 483). A shield break no longer schedules it. This is a boss framework change (`BossEncounter._on_item_used`), so it's a T1 task: check every boss that uses the armor rule, at 3, 5 and 6 lanes.

