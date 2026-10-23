# List of Tasks

The owner's requests. Add new ones at the end as `- [ ]` items, under a dated heading. When an orchestrator
finishes one, it ticks it (`- [x]`), adds a short DONE note, and moves it to `docs/USER_REQUESTS_DONE.md` (same
heading), so this file holds only what is still to do. Code comments citing "`docs/USER_REQUESTS.md`" may mean a
request that is now in the done file.

## October 23, 2026

- [ ] **Armor comes back after any hit** (task S3, a bug): the armor regenerates only once it is at 0. Its wait should
  start when a hit is taken: armor of 3 knocked to 2 starts the timer, and at its end the armor is back to 3.
- [ ] **The Hush's chasms: letting go of the wall moves two lanes** (task S3, a bug): on The Hush's long extended wall
  runs (the owner's "chasms"), pressing left or right to come off the wall threw the runner two lanes instead of one,
  maybe where the wall section ends right before a recharge platform. Coming off the wall should behave as it does
  everywhere else in the game.

