# List of Tasks

The owner's requests. Add new ones at the end as `- [ ]` items, under a dated heading. When an orchestrator
finishes one, it ticks it (`- [x]`), adds a short DONE note, and moves it to `docs/USER_REQUESTS_DONE.md` (same
heading), so this file holds only what is still to do. Code comments citing "`docs/USER_REQUESTS.md`" may mean a
request that is now in the done file.

## October 20, 2026

- [ ] **Add the Terminal, zone 8: an abandoned subway with a debris maze** (the owner, October 20, 2026; GDD §5, Zone 8;
  reference `docs/art/reference/terminal_zone.jpg`). Slot it between the Dead Zone and the Golden Zone (now zone 9), two
  levels, no boss. Build: the zone and its skin (subway tunnel, track bed, rusted trains, debris, cables, steam, orange
  work lamps; scavengers as scenery); **narrow arch side walls** (one space wide, about six lengths apart, mostly
  in pairs, a missing one shown as a stump broken off about halfway up) with **no wall running**; **lower debris doodads
  that stop the runner** instead of pushing; **the debris maze** pattern (level 1 a maze that needs the dash to finish,
  level 2 a normal run with stretches of maze); **few, single-lane ceilings** as shortcuts. **A couple of holes**, **no dash
  walls**, time-based stars. **Enemies: only the Cybernetic Centipede** (GDD §9.15, reference
  `docs/art/reference/centipede.jpg`): waits in open maze sections, wakes and chases along open paths when the runner
  comes near, can't pass debris (a dash can release a trapped one), slightly slower than the runner, can't follow onto
  a ceiling; a bite on contact is one hit; two dashes kill it, a dash passes through it safely; immune to weapons,
  claws and stomps. The maze generator must place centipedes so every layout stays escapable. Core work (generator, player, campaign data): split into tasks by the orchestrator.
