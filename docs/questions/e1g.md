# E1g, the Floating Head's salvos: open questions

(The owner's request, October 9, 2026: in the next bombing run, two to four spots at once, one or two bombs each, the
nearest first. The owner's answers the same day are in GDD §10: harder on 5 or more lanes, spots closer together,
later runs a little longer, far circles the same red. Numbers: group "Salvos" in `data/bosses/city_boss_tuning.tres`,
F6 in the fight; review with `tools/showcase/floating_head_showcase.tscn -- --scenario=bombing --phase=1` or
`--phase=2`, with `--lanes=3`, `5` or `6`.)

- **Which runs drop salvos** (GDD §10: "the next bombing run"). The fight has two later runs, at the start of phases 2
  and 3. Placeholder: both drop salvos (`salvo_spots` = 1, 4, 4; the first run keeps one spot at a time). Should the
  third phase's run go back to one spot at a time (1, 4, 1)?
- **How much harder on 5 or more lanes** (owner: "increase the difficulty on five or more lanes"). With one or two
  bombs a spot, a runner on a wide street can step clear of a whole salvo. Placeholder: from 5 lanes
  (`salvo_wide_lanes`) a spot takes up to three bombs side by side (`salvo_wide_bombs`, `DESIGN-TBD`), placed to leave
  the runner as few lanes as possible but never none, so after the first spot there is usually one way through
  (`salvo_wide_choices` = 1, `DESIGN-TBD`; 2 would leave a choice of two lanes). On 3 lanes a spot keeps one or two
  bombs, two 40% of the time (`salvo_pair_chance`). Is three bombs a spot right (beyond the one or two first asked
  for), and is one way through too hard?
- **How tight** (owner: "make it tighter"). Placeholder: 10 m between spots at 18 m/s instead of 12 m
  (`salvo_spacing`, `DESIGN-TBD`): about 0.56 s from one blast to the next, leaving about 0.4 s after passing a blast
  to switch one lane before the next. Tighter still?
- **The later runs' length** (owner: a little longer, for the longer salvos). Placeholder: 6.5 s instead of 5.6 s
  (`later_run_seconds`): two salvos of four spots fit, with a little room. Right length?
