# C6e (making room where there is none): open questions

- **How early in the calm start** (GDD §9.13 "Making room where there is none": "late enough that the player is
  under way (a minimum in data)"). Placeholder: `EnforcerTruckTuning.calm_start_min_seconds` 0.5 s into the run
  (`data/enemies/enforcer_truck.tres`, `DESIGN-TBD`). The truck arrives there at its follow gap, right behind the
  runner, and pulls alongside as it arrives: from its usual arrival gap (45 m) it couldn't come alongside before the
  bait (Golden 1's first Buzz Overdrive revs 4 s after the 60 m run-up). Is 0.5 s right, and is arriving close in
  fine?
- **"Nothing taken out" in the calm start.** A showing there runs on past the run-up (2.4 s at the Golden Zone's
  speed) into the level's first patterns. Placeholder: it takes nothing out anywhere, as the task asked
  (`calm_start_takes_out` off, `DESIGN-TBD`), so it fits only where those patterns leave a lane: on the own seeds
  Golden 1 at 3 lanes gets it, Golden 1 and 2 at 6 lanes and Golden 3 at 5 don't. Switched on, it may take out plain
  holes, fences and cyborgs past the run-up as any other window may, and those three get a showing before their bait
  (taking out 2, 8 and 2 pieces of their first patterns). Switch it on?
- **A Buzz Overdrive's claim during a showing, beyond the calm start.** Placeholder: anywhere in a level (not only
  the calm start), a window may overlap the claim on its turn a Buzz Overdrive makes before its rev, the tank staying
  where it is, the showing out of view `show_margin_seconds` before the rev (`ShowPlanner` CLAIM mode). It only
  comes where no window fits before the bait otherwise. An Octodog's turn is unchanged. Keep it level-wide?
- **The hover truck's cannon and forward lurch wait.** Placeholder: only its entrance (banging and bursting out)
  can't wait for a turn; its cannon shots and forward lurch take turns and wait for a showing, as other big attacks
  do. Should they count as attacks that can't wait too (the showing fitting between them instead)?
- **A runner lane no showing can reach.** Placeholder: a window may leave out one runner lane no showing could reach
  (beside a hover truck at 3 lanes, or with only a floor cut's lane beside it); a runner keeping to that lane doesn't
  see that showing. Two such lanes leave the window out. Is one lane without the showing acceptable?
