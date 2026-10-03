# Side wall gaps: open questions

- **Feedback when a wall entry is refused in a gap** (GDD §3 wall running). Placeholder: the player stays
  in the outer lane with no bump or clank, and `Player` emits `wall_missing` (`DESIGN-TBD` in
  `scripts/player/player.gd`, `_try_enter_wall`). No sound is mapped. Should it have a sound or a small
  sideways lean?
- **Sound for the automatic drop** (`wall_gap_drop`). Placeholder: silent, like `wall_exit`. ScoreKeeper
  ends the wall run.
- **Frequency and length** (owner: "LOW"; both walls "rarely"). Placeholder values are in
  `data/tuning/wall_gaps.tres`: about one gap every 24–32 s (±35%), each 0.6–1.1 s long, and 12% of
  placements on both walls. Measured over Zone 2+ levels at 3/5/6 lanes: 0.4–2.4 gaps a minute (median
  1.7; the low end is gangland/1, which introduces gaps halfway in), and about 10% of them on both
  walls (43 of 453). Should these be confirmed in playtest?
- **Overhead dressing over a gap** (skybridges, strings of lights). Placeholder: zone skins leave
  overhead pieces out across a gap, so some may end at the gap's edge.
