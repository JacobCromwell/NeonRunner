# FIX4: open questions

- **Zone doodads or City 1's extra gaps: which gives way?** (GDD §3 zone doodads; docs/USER_REQUESTS.md,
  more gaps in City 1.) The doodads were built to only add to a level (the same level without them, plus
  them), and City 1's extra-gap pass, which runs after them, was built to keep every doodad where it is.
  Where both want the same stretch, one has to move. Placeholder: the doodads stay, and the extra gaps
  keep out of their way, but a row widened with a lane left open now keeps off a doodad's own lane and
  window only, not a margin around it in every lane (`DESIGN-TBD` in `scripts/world/gap_density.gd`, the
  widening in `apply`). A row widened to full width (a jump, which lands past the row) and a new row still
  keep the margin from a doodad, so the doodads can still decide where those go: over test_city_gaps' 33
  City 1 builds (3, 5 and 6 lanes, seeds 1 to 8, every tier) the doodads change the gaps in 15 (19 before),
  almost all through a full-width jump a doodad stands too close to, among them the shipped City 1 at 6
  lanes on the 0.35 tier; the shipped default tier, at every lane count, no longer.
  The alternative: run the extra-gap pass before the doodads, so the doodads fill what it leaves and only
  ever add (City 1's doodads at 3 and 5 lanes then stand elsewhere, and test_city_gaps would no longer
  expect them unchanged).
- **A Resonator still owing its first pulse when the next one arrives** (GDD §9.10, §9 big attacks take
  turns). Placeholder: a first pulse overdue by `ResonatorTuning.turn_wait_max` (8 s of waiting, for other
  attacks or for clear floor) keeps its place in the turn queue, so the other types' next attacks wait for
  it and it pulses at the next clear floor (`DESIGN-TBD` in `scripts/enemies/resonator.gd`,
  `_first_overdue`). Before, a long Bad Dream chase over a visit's planned pulses, then a drone that
  stays, could keep it from ever pulsing until the next Resonator's arrival sent it away (Golden 2 at 6
  lanes). Not seen since in the Golden campaign layouts, but a chase a player sets off can still last
  past the next visit's arrival, and the arrival still sends the last one away (one on screen at a
  time). The alternative: the next one holds back far ahead until the last one's first pulse has begun
  (two on screen meanwhile, and its own visit may then run out of level).
