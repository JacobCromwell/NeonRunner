# E1e: the Floating Head after the owner's playtest (September 30, 2026)

Numbers in `data/bosses/city_boss_tuning.tres` (F6 in the fight) and `data/bosses/city_boss.tres`;
`tools/measure/stomp_routes.gd` measures the ways up (`--e1c`: the numbers before this task).

1. **Should every phase use a ramp?** (GDD §10: (1) the fallen tower as a ramp, (2) a wall jump,
   (3) a pad and the ceiling.) After the first stomp the owner saw no ramp and no way up. The wall route
   showed nothing, and at 5 and 6 lanes a wall jump lands in the outer lane, which has no weak point:
   only a second move inward in the air reached one (measured in the campaign's step and in quick play,
   before and after a retry: a single wall jump never stomped). Placeholder: the GDD's three ways,
   made visible and forgiving: green chevron marks light up on both walls as the tower falls, from where
   to get on (`wall_entry_before`, 13 m before its face) to a tall jump mark (`wall_jump_before`, 4 m),
   with a new sound (`wall_marks_light`); a first-time hint for each way (`data/hints/hints.json`); and
   question 3. Alternative: the tower's slab in every phase.
2. **The ramp's lead-in** (item 158): a lane switch onto the ramp bounced off its side anywhere past its
   first 2 to 2.75 m (the latest switch that still stomped: 11.3 to 12.0 m before its face). Placeholder:
   its first 75% (`ramp_board_share`) is a low lead-in rising to 1.0 m (`ramp_board_height`; a lane
   switch steps up about 1.07 m) with bevelled rubble sides; its last quarter is steeper and still
   blocks; the window stays open for a runner on the trucks until the lead-in ends (3.5 m before its
   face, not 8 m). The latest switch is now 4.5 m before its face at 3, 5 and 6 lanes. Right share,
   and does the bent slab read as the fallen tower? Alternatives: a slab two lanes wide, a longer ramp.
3. **Stomp boxes over the outer lanes** (item 160): at 5 and 6 lanes the outermost weak points' stomp
   boxes now reach over the outer lanes to the walls, at their own height (a jump from the trucks
   still can't reach them), so a wall jump or a ceiling drop there stomps the dome beside it; and every
   box is lower and deeper (0.35 m over its socket, 4 m deep; were 0.55 m and 3 m). One wall jump now
   stomps over 4.5 to 7 m of jump points around the mark. Alternative: weak points of their own over
   the outer lanes (the tower side's would sit near the roofs, in a floor jump's reach).
4. **Armor for a runner whose armor is down** (GDD §10, the standard armor rule): with no armor and no
   shield nothing could break, so no pickup came before the final phase, which the owner never
   reached (the loadout and the flow were fine). G3's free armor now covers the start of every fight.
   Placeholder on top: a phase that begins with the runner's armor down and no shield (the free armor
   still coming back) and no pickup on its way counts as a break at its start (an armor pickup 10 to
   15 s in, the phase's one; `BossDef.armor_when_unprotected`, on for the Floating Head only). Keep it,
   make it the standard rule, or drop it now that the free armor comes back by itself?
