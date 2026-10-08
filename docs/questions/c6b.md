# C6b, the Enforcer Truck shows itself: open questions

- **How often players will see it** (GDD §9.13 "Showing itself": "every so often"). A showing needs about 7 s
  between its arrival and its bait's turn (pulling up, about 3 s alongside, dropping back, a margin), with a lane
  beside the runner kept clear. Many campaign chases put the bait sooner or fill the lanes beside the runner
  (fences, doodads, holes), so it often can't show. In Corporate 2's own build, a runner keeping to the middle
  lane sees no showing at 3 lanes, one at 5 and none at 6. Placeholder: at most `show_count` (2) showings, one
  on arrival and one mid-chase, only where every rule holds (`data/enemies/enforcer_truck.tres`; `DESIGN-TBD` on
  `EnforcerTruckTuning.show_count`). Should the generator keep room for the arrival showing (a later bait, or a
  clear stretch beside the runner's lane after it arrives)? That would be a change to the generator and the
  level data, so it needs a core task. Or is a rare showing fine?
- **A runner in an outer lane** (GDD §9.13: "never takes the only free lane"). A runner in an outer lane has only
  one lane beside them, so the truck never shows itself to them. Placeholder: no showing while the runner is in
  an outer lane (`EnforcerTruck.show_lane_now`). Is that right, even though it means a player who keeps to the
  wall never sees it?
- **Its first volley waits for its first showing.** So the runner sees what's chasing them before it fires,
  the first volley waits up to `show_wait_seconds` (4 s) past its time, as long as a showing can still come
  before the bait. Placeholder: as described (`DESIGN-TBD` on `show_wait_seconds`). Keep this, or fire on time?
- **Other attacks during a showing** (GDD §9, big attacks take turns). A showing takes a big attack's turn. A hover
  truck and a Gilded Sentinel can't wait, so while one is in play or about to arrive the truck doesn't show
  itself. A Resonator's pulse waits for the showing to end, as it waits for a volley (up to the director's
  `turn_wait_max`, 8 s). Placeholder: `EnforcerTruckRoom.NO_SHOW_TYPES`. OK?
- **Where the blast happens** (owner, October 8, 2026: a visible explosion). Behind the camera a blast would be
  unseen. So a wrecked truck first lurches forward into view over `wreck_surge_seconds` (0.3 s), until its front
  is `wreck_gap` (2.8 m) behind the runner, or reaches the far edge of the hole it fell in. Then it blows up and
  falls back slowly (`blast_drift`). This bends the physics a little so the blast is readable. It's smaller and
  lower in the runner's lane (`blast_radius_in_lane` 0.85 m, against `blast_radius` 1.3 m beside them) so it
  never hides them. Placeholder: those values (`DESIGN-TBD` on the "Wreck" group). OK, or should a wreck behind
  the camera show differently (only fire and debris rising into view)?
