# List of Tasks

The owner's requests. Add new ones at the end as `- [ ]` items, under a dated heading. When an orchestrator
finishes one, it ticks it (`- [x]`), adds a short DONE note, and moves it to `docs/USER_REQUESTS_DONE.md` (same
heading), so this file holds only what is still to do. Code comments citing "`docs/USER_REQUESTS.md`" may mean a
request that is now in the done file.

## Doodad pictures (October 9, 2026)

- [ ] Doodads prefer the lane next to the side wall when it's open, without costing gameplay: not where the generator already has something on that part of the wall or needs it open. Held, by the owner's choice ("art first, placement later"), until the dash-smash branch (`claude/nifty-brahmagupta-i5ov2i`, H5) is resolved, since it changes the same generator, track and player code. H5 has merged; the October 14 batch left it for the next batch, behind I4 (the generator).

## Wall hop nudge (October 9, 2026)

- [ ] Gently teach the wall hop (jumping off a side wall and straight back on, for an unlimited wall run; GDD §3). Some long walls carry high-value credits further along than one wall run reaches, so a player has to get inventive to collect them (GDD §7, Wall-hop credits). Proposed: from Gangland on, about once a level, on a stretch of wall with no wall gap. Don't patch the wall hop itself; the owner relies on it in every playtest. The October 14 batch left it for the next batch, behind I4 (the generator).

## October 15, 2026 batch

- [ ] **Cyborgs 20% bigger in every other zone** (J1; GDD §9.2). Draw them 20% bigger in every zone after the Neon City, as the City's were (I2): hitboxes unchanged.
- [ ] **Five lanes on mobile, if it is safe for the frame rate** (no task). Only with high confidence there is no noticeable FPS cost on phones; otherwise report and table it.
- [ ] **Wall-run-only gaps** (J2; GDD §3, §9). Some sections, especially in later zones and levels, where a gap spans the whole floor and the only way across is a wall run. A wall counts as an acceptable, safe path even if the GDD rules say otherwise.
- [ ] **Beach boss: water in the shark's third-phase bite** (J3; GDD §10, Mecha Guppy). When the shark bites the roof in phase 3 the open space should show blue water at the bottom. Phases 1 and 2 are fine as they are.
