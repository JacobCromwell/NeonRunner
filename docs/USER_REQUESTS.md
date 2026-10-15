# List of Tasks

The owner's requests. Add new ones at the end as `- [ ]` items, under a dated heading. When an orchestrator
finishes one, it ticks it (`- [x]`), adds a short DONE note, and moves it to `docs/USER_REQUESTS_DONE.md` (same
heading), so this file holds only what is still to do. Code comments citing "`docs/USER_REQUESTS.md`" may mean a
request that is now in the done file.

## Doodad pictures (October 9, 2026)

- [ ] Doodads prefer the lane next to the side wall when it's open, without costing gameplay: not where the generator already has something on that part of the wall or needs it open. Held, by the owner's choice ("art first, placement later"), until the dash-smash branch (`claude/nifty-brahmagupta-i5ov2i`, H5) is resolved, since it changes the same generator, track and player code. H5 has merged; the October 14 batch left it for the next batch, behind I4 (the generator).

## Wall hop nudge (October 9, 2026)

- [ ] Gently teach the wall hop (jumping off a side wall and straight back on, for an unlimited wall run; GDD §3). Some long walls carry high-value credits further along than one wall run reaches, so a player has to get inventive to collect them (GDD §7, Wall-hop credits). Proposed: from Gangland on, about once a level, on a stretch of wall with no wall gap. Don't patch the wall hop itself; the owner relies on it in every playtest. The October 14 batch left it for the next batch, behind I4 (the generator).

## Owner's answers to the open questions (October 14, 2026)

- [ ] (I7) **Rebalance the economy for the full campaign** (GDD §7; `docs/OPEN_QUESTIONS_ANSWERED.md` item 16). The shop prices and the completion payouts (100 + 25 per campaign level) were set for a two-zone campaign. Rebalance them for all eight zones with `tools/measure/economy.gd`, so each upgrade first fits about where the campaign needs it. Prices and payouts live in data (`data/shop/catalog.json` and the tuning files). Keep the approved early-economy revision (October 3, 2026) and the laser I price (1,800 credits, first affordable at City 4) unless the curve can't hold them, and report the before and after.
- [ ] (I8) **An intro cinematic slot for every boss** (GDD §6; item 395). The City and Gangland have boss intros. Give the other bosses (The House, Hostile Takeover, the Beach's boss, the Sleep Taker, the Golden Convergence) an empty intro slot that the campaign skips until it's filled, so the owner can add their beats later without a structural change.

## The owner's batch requests (October 14, 2026)

- [ ] **Shader cleanup in every zone** (I1). An earlier session found unused or duplicated shaders in Zone 1 (`fca7f77`, City 1's load compiles 17 fewer shader programs) and removing them helped performance without changing the look. Check every other zone for the same gains and make them.
- [ ] **Ceiling scenarios** (I4; GDD §3, Ceiling scenarios). Not in zones 1–2; sprinkled into later zones. (a) Pick the right pad: electric fences on a ceiling hit a player who takes the first anti-grav pad; a second pad further along avoids them. First one safe and one unsafe pad; later several pads, some safe and some not. (b) The treasure stash: a separate return pad partway along a ceiling drops the player into a stretch of floor walled off by doodads (for a stash in lane 3: a doodad at its start, and doodads in the two adjacent lanes), holding two or three of the highest-denomination credits.
- [ ] **The Hover Truck lags on mobile** (I5; GDD §9.3). The truck that smashes in through the side wall and fires its cannon causes a big performance drop on a playtester's phone. Find and make performance improvements.
- [ ] **One hit from death** (I6; GDD §4). An audio and visual cue when the player has run out of all armor and shields; the sound is a two-tone siren.
