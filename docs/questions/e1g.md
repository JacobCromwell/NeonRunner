# E1g, the Floating Head's salvos: open questions

(The owner's request, October 9, 2026: in the next bombing run, two to four spots at once, one or two bombs each, the
nearest first. GDD §10; group "Salvos" in `data/bosses/city_boss_tuning.tres`, F6 in the fight; review with
`tools/showcase/floating_head_showcase.tscn -- --scenario=bombing --phase=1` or `--phase=2`.)

- **Which runs drop salvos** (GDD §10: "the next bombing run"). The fight has two later runs, at the start of phases 2
  and 3. Placeholder: both drop salvos (`salvo_spots` = 1, 4, 4; the first run keeps one spot at a time). Should the
  third phase's run go back to one spot at a time (1, 4, 1), or drop bigger salvos than the second?
- **Leading the way, or forcing it.** Each spot after the first hits the lane the way past the spot before leads to,
  so the salvo weaves along a path. With one or two bombs per spot, a runner on 5 or 6 lanes can often step clear of
  the whole salvo with one move (for example, spots in lanes 1, 2, 3 and 4 while the runner steps to lane 0). On 3
  lanes, the two-bomb spots force the way more often. Placeholder: as described, with a 40% chance that a spot takes
  two bombs side by side (`salvo_pair_chance`, `DESIGN-TBD`). Is that the feel you want? Or should salvos on wider
  streets block the easy way out (more two-bomb spots placed on the side away from the way, or more bombs per spot)?
- **The gap between spots.** Each spot is 12 m further than the one before at 18 m/s (`salvo_spacing`, stretched at
  the City's 21 m/s): 0.67 s from one blast to the next, the time to run past a blast and switch one lane
  (`salvo_max_shift`). The phase's pace doesn't shorten it, because the runner doesn't switch lanes faster in later
  phases. Placeholder: 12 m and one lane (`DESIGN-TBD`). Tighter or looser?
- **How many salvos fit in a run.** A later run lasts 5.6 s, so it holds one or two salvos (a 4-spot salvo takes
  about 3 s from the lock to its last blast). A salvo that wouldn't land before the run ends is cut short, down to two
  spots. Placeholder: the run lengths unchanged. Should the later runs grow to fit more salvos?
- **Seeing the far spots.** At 21 m/s a 4-spot salvo's last circle is about 62 m ahead at the lock, where the target
  circle is small on screen; it grows as the runner closes in. The light rests on the next spot to blow and moves on as
  each one blows. Placeholder: the same red circle for every spot. Should the far spots read more strongly (a bigger
  circle, or the light sweeping the whole path at the lock)?
