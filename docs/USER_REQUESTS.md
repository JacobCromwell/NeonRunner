# List of Tasks

The owner's requests. Add new ones at the end as `- [ ]` items, under a dated heading. When an orchestrator
finishes one, it ticks it (`- [x]`), adds a short DONE note, and moves it to `docs/USER_REQUESTS_DONE.md` (same
heading), so this file holds only what is still to do. Code comments citing "`docs/USER_REQUESTS.md`" may mean a
request that is now in the done file.

## October 24, 2026

- [ ] **Always an attacker.** Sometimes several enemies are on screen and none of them attacks the player. It may come from the safety calculation, but to a player it looks like a bug. When several enemies are on screen, at least one should be attacking or charging up its attack.
- [ ] **Teleporter camera.** The Ice zone's teleporters work well, but need a visual: when the player touches one, the camera should zoom/travel to the teleporter's output, so that although the player teleports instantly, the camera catches up and shows what happened.
- [ ] **Less red (three enemies).** (1) Gold-zone wall sentinels: when the halberd is raised there is a big red rectangle over the whole hit area; remove it (the halberd itself may be red, the attack stays the same). (2) The Ice zone's hunter: its slash has a big red rectangle besides the red blade arms; remove the rectangle. (3) The swarm host boss: the screech walls are drawn red as well as the red lane line; keep the red lane line, but give the screeches their normal colours.
