# FIX2: the Buzz Overdrive's turn among the big attacks

1. **What does a Buzz Overdrive do when it can't get its turn?** (GDD §9: "big attacks take turns"; §9.9:
   its cut is planned in advance.) It never asked for a turn and counted as attacking only from its rev, so
   another type's attack that started a moment before (when only its roll was on) ran on into its rev: over
   the seven levels that have it, at 3, 5 and 6 lanes on 13 seeds each, 73 of 380 tanks revved into a drone's
   barrage, a hover truck's lurch or cannon shot, or a Resonator's pulse (87 s of two big attacks at once).
   It can't wait (a later cut would run over floor the generator never checked).
   **Placeholder:** like a Gilded Sentinel (C4), it claims its turn `claim_seconds` = 2.5 s before its rev,
   while it rolls ahead (other types' big attacks that get ready meanwhile wait for it), and if one begun
   before its claim is still on as its rev would start, it lets the runner pass: no rev, no red line, no
   cut (its lane stays whole); it speeds off ahead and is out of view `pass_seconds` = 3 s later (far ahead,
   in the fog, it may cross a hole or fence in its lane). Measured over the same runs with the claim: no
   overlap; 378 tanks revved and 2 let the runner pass (both behind a Resonator's pulse); the others lost
   57 of 2,163 drone barrages, 14 of 632 cannon shots and 7 of 527 lurches, and drones waited 2.05 s on
   average instead of 1.71 s (`data/enemies/buzz_overdrive.tres`, F6 "Enemy: buzz_overdrive", Turns; `DESIGN-TBD` in
   `scripts/enemies/buzz_overdrive_tuning.gd`). This also narrows item 307's placeholder: other enemies may
   still act while it rolls ahead, but not in its last 2.5 s before its rev. A boss's tank (Hostile
   Takeover's drop, no roll) neither claims nor passes, as before: the boss keeps its own attacks off it.
   **Alternatives:** a longer claim (up to its whole 4 s roll: fewer passes, the others held longer), the
   generator keeping every other enemy off its roll too (fewer places fit a tank, and attacks timed at run
   time would still need the claim), or revving anyway (two big attacks at once, as before).
