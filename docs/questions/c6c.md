# C6c: room for the Enforcer Truck to show itself in every chase

- **A runner by a wall** (GDD §9.13 "Showing itself": "never takes the only free lane"; follows question 365). A
  runner in an outer lane used to never see the truck. Beside them on their inner side it would take their only
  lane to dodge into, and at 5 and 6 lanes it would also hide up to 25 m of their lane from the camera (the camera
  sits inward of a runner by a wall). Placeholder: it pulls up two lanes in and leaves the lane between free; the
  "never the only free lane" rule holds both ways (the lane between stays open wherever the runner's lane is
  blocked, and the runner's lane wherever the lane between is). Its whole look stays on screen and it hides nothing
  of their lane or the lane between (`EnforcerTruckRoom.sides`, `escape_lane`, `EnforcerTruckView.check`;
  `DESIGN-TBD`). Is two lanes in right?
- **What a showing window may take out** (the owner's request against the danger density request). Where a chase
  has no calm stretch where it can show itself to a runner in every lane, the generator takes out only what's in the
  way: plain holes and fences (never a pulsing fence or one a fence generator powers), and plain cyborgs, window
  cyborgs and Screeches (never a host, the first of a kind the level introduces, or the last of its kind or of one
  of the level's features). Every
  later pass keeps its additions off each window, but nothing keeps a spacing from one. On the six levels' own seeds
  at 3, 5 and 6 lanes the windows cost about 2% of their enemies and of their obstacles (592 to 580 enemies, 3281 to
  3226 obstacles; from +3 to -14 obstacles a level), and the danger density pass's measured increases stay in their
  bands. Placeholder: `ShowPlanner.REMOVABLE_TYPES` and the window's stretch (`enforcer_truck_rules.gd`,
  `DESIGN-TBD` on `EnforcerTruckTuning.show_window_planned`). Is that cost acceptable?
- **Chases with no window** (7 of the 23 chases on the levels' own seeds). In four, a hover truck or a Gilded
  Sentinel is about for the whole chase, and the truck never shows itself while one is (question 367). The other
  three have no calm stretch at all: Corporate 2 at 5 lanes (the truck's introduction, among an Octodog's charges, a
  Tithe Collector and a Buzz Overdrive's attack), Dead Zone 1 at 3 lanes (pulsing fences, a ramp's wall run and a
  Screech at the level's start), and Dead Zone 2 at 6 lanes (rows of fences with a pad in their gap). Three more
  windows hold for most lanes but not all: a runner who takes a pad onto a ceiling, or a ramp onto a wall, in that
  lane misses that showing. Placeholder: the baits that get trucks are the ones whose chases hold the most windows,
  and a level that introduces the truck keeps its first bait's chase. Should a chase with no room for a showing get
  no truck (another bait instead), or should the hover truck and the Gilded Sentinel make room?
- **Windows after the bait** (6 of the 16). Where the bait comes right after the truck arrives (at some lane counts
  the Golden levels' first truck arrives at the end of the run-up and their first Buzz Overdrive revs 4 s later), no
  showing fits before it, so the window comes after the first bait. A player who destroys the truck with that bait sees its wreck blow up instead, and a wider gap later in
  the chase (task G7) can wreck it first too: in the simulated runs, 18 of the 75 runner runs with a window lost the
  truck before its window. Placeholder: as described (`ShowPlanner.plan`). Is a showing after the bait worth its
  calm stretch, or should those chases arrive later?
- **Making the window's showing happen** (GDD §9, big attacks take turns). The truck claims its turn among the big
  attacks `show_claim_seconds` (2 s) before its window is due, so a drone's barrage or a Resonator's pulse that gets
  ready meanwhile waits for the showing (up to the director's `turn_wait_max`), and its own volleys hold so none is
  on as the window comes. The window also holds if the showing begins up to `show_window_slack_seconds` (1 s) late.
  A host's Bad Dream chase doesn't keep a window off: it only comes if the player kills the host, and the showing
  then waits for it. Placeholder: those two values (`DESIGN-TBD` in `data/enemies/enforcer_truck.tres`). OK?
