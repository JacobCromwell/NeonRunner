# Merging main into the H series (October 9, 2026): open questions

- **The Enforcer Truck's blast is now the shared fireball** (GDD §9.13 "Its end is a visible explosion", §11
  "Explosions"). Task C6b gave the truck an explosion of its own (swelling puffs, a white-hot core, dark smoke and an
  orange glow on the floor), and task H6 made every explosion in the game the one shared yellow-and-red fireball
  (the owner, October 8, 2026). The merge keeps C6b's wreck exactly (it lurches into view, blows up 2.8 m behind
  the runner, falls back at 0.5 m/s, gone after 0.9 s) and draws its blast through the shared fireball.
  Placeholder (`EnforcerTruck._explode`, `FIRE_SPREAD`, `FIRE_SPREAD_IN_LANE`; sizes and times in
  `data/enemies/enforcer_truck.tres`, group "Wreck"): C6b's sizes (`blast_radius` 1.3 m, `blast_radius_in_lane`
  0.85 m), its fire burning `blast_seconds`, held in (0.7 of a free fireball's spread, 0.5 in the runner's lane),
  **no smoke** (everything it draws only adds light, so it can't hide the runner, as C6b required), carried along
  with the wreck. C6b's floor glow and smoke are gone. Should it keep smoke beside the runner, or be as big as the
  other trucks' explosions (3.6 to 3.8 m)?
- **The City outro's explosions** (GDD §6 Cinematics, §11). Placeholder: the roadblock's blast is now the shared
  fireball (2.0 m, its fire about 1.3 s, with smoke; softened by Reduced flashing), from a one-slot pool of the
  outro's own (`CityOutroSet.build_blast`, `start_blast`). The Floating Head's crash in the outro keeps task F2a's
  dust and smoke with no flash, while the same crash in the fight plays three fireballs (task H6,
  `FloatingHead._crash`). Should the outro's crash play the fight's fireballs too?
- **Dash walls and the Enforcer Truck's showings** (GDD §9.13 "Showing itself", §9.14). When it shows itself the
  truck pulls up beside the runner with its front ahead of them, before the runner has broken a wall there.
  Placeholder: the walls keep off its planned showing windows (with the rules' keep-outs, in every lane, the window
  and 1 m either side: `DashWallRules._counts`), and in play it never begins a showing whose view would reach a
  standing wall, nor stays alongside up to one (`EnforcerTruckRoom`: a wall is solid in every lane). A showing
  window so wins over a wall's spot. Right priority?
- **Fewer walls in Golden 1 and Golden 2** (GDD §9.14; follows docs/OPEN_QUESTIONS.md item 644, how many a level).
  Kept off the showing windows, Golden 1 on 5 lanes has room for one wall on its own seed (the only other fair
  spot, 576 to 627 m, lies in its truck's window, 393 to 625 m) and Golden 2 on 6 lanes for three (its fourth
  spot, 536 to 539 m, in the window from 518 to 719 m). Following the H7a rule that a level asks for no more than
  its track holds on its most crowded lane count, placeholder: `dash_walls` 1 in `data/levels/golden_1.tres`
  (was 2) and 3 in `golden_2.tres` (was 4), so the other lane counts lose one too. Or should a level's count
  apply per lane count, or a window give way to a wall (a truck with no showing in that chase)?
