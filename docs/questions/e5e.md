# E5e: Mecha Guppy and Captain Cogs, open questions

Raised by step E5e-a (the climb's core) and step E5e-b1 (the climb itself). The rest of the fight is
built in E5e-b2 (the shark, the pirate, the bombs) and E5e-c (phase 3, the defeat), which can answer
these as they go.

## Raised by E5e-a, with E5e-b1's placeholders

- **How the grapple's save onto the higher roof looks** (GDD §8, §10: "it pulls the runner up onto the
  higher roof"). The save has no reel-in: the runner is lifted in one frame to just under the higher
  roof's top and moved into its lane like a lane switch (`Player._pull_up`), and the climbing camera
  eases after it. Placeholder (E5e-b1): that instant lift, plus a warm-white rope (no hazard colour)
  from the runner (followed as the save lifts them) to the roof's edge in the lane it pulls them into,
  shown for 0.35 s as it fires (`MechaGuppy._grapple_save`, `MechaGuppyRope`; DESIGN-TBD). The save
  picks a roof and lane whose path is clear (`MechaGuppyStairs.save_spot`: the lowest higher roof
  under a lane that leads up where the save brings them down, and the lift starts above every solid
  front). Should the save instead reel the runner up visibly over a fraction of a second?
- **Where a revive after a fall puts the runner in the climb** (GDD §4: the revive item "revives on the
  spot"; §10). A revive on the spot would drop the runner straight into another fall. Placeholder
  (E5e-b1, as E5e-a proposed): a revive after a fall goes where the grapple's save goes, onto the
  higher roof in its nearest lane that leads up (`MechaGuppy._grapple_save` answers both causes;
  `test_mecha_guppy_climb` checks it). Is that right, or should a revive put them back on the roof
  they fell from?
- **The blob shadow on a raised floor in levels too?** (GDD §3: the shadow reads height and gaps).
  Unchanged by E5e-b1: levels and the other bosses keep the street-level shadow; in the climb it lies
  on the roof under the runner (`test_mecha_guppy_climb` checks it frame by frame). Offered as a
  possible improvement: draw it on the surface under the runner everywhere.
- **Landing back on the floor they came from** (GDD §10: "the rest drop them back onto the floor they
  came from, where Mecha Guppy is eating: falling into it is instant death"). Is landing on a part of
  the lower floor the shark hasn't eaten yet survivable, or is every drop past the higher roof a
  death? Placeholder (E5e-b1): every wrong drop is a fall. The roof a step starts from is already
  eaten from 1 m past its pad strip (`MechaGuppyTuning.edge_margin`), so a drop in a lane that doesn't
  lead up falls into the chasm under the hut, down to the water far below (a look placeholder until
  E5e-b2's shark and bites), and dies unless the grapple saves it. Nobody lands on uneaten lower floor.

## Raised by E5e-b1 (the climb)

- **The climb's sizes and times** (GDD §10 gives the climb's shape, not its numbers). Placeholders in
  `data/bosses/beach_boss_tuning.tres` (`MechaGuppyTuning`, all DESIGN-TBD, tunable with F6 in the
  fight):
  - Each roof stands 3 m above the last (`rise`).
  - A hut's underside is 8.5 m over the floor its step starts from (`hut_height`; a level's ceilings
    are 6 m). At 8.5 m the view from under a hut (the run camera sits 3.6 m under a ceiling) is 1.9 m
    above the next roof, so its deck shows and the lanes that reach back read as a place to land. It
    also keeps at least 3.2 m over the roof under its end (`hut_clearance`).
  - The run on a roof, from landing to the next pads, is 1.6 s in phase 1 and 0.6 s in phase 2
    (`roof_seconds`): phase 2 climbs 19-22% faster.
  - The reaching lanes reach 10 m under the hut's end (`reach_back`, at 18 m/s), and the running-on
    lanes run 3 m past the higher roof's front (`run_on`, at 18 m/s).
  - The street is 3.5 s long before the first pads (`start_seconds`).

  A step takes about 5.5-6 s in phase 1, which is 10 or 11 roofs (about 30-33 m up) a minute.
- **The reading margin** (GDD §10: the runner must see which lanes lead up and have time to switch
  into one). Placeholder: 0.9 s beyond every lane switch the farthest lane needs (`read_seconds`; 0.6 s
  before E5e-b1's review, raised as a more humane default for the owner to tune in playtest). It counts
  from the latest a rider can settle on the hut: a jump right before the pads, with the dash, then the
  flip up. A rider who doesn't jump gets about a second more. Is 0.9 s right?
- **Every runner flips up.** GDD §10 makes the ceiling the way up. Placeholder: each roof ends in a
  strip of pads across every lane, longer than the longest jump at the run speed (dash included) by
  2 m (`strip_margin`), so nobody can jump over it. Is an unmissable strip right?
- **How many lanes lead up, and the cue order** (GDD §10: "one, two or three, alternating" on 5-6
  lanes; the cues alternate; "one or two of the roof's lanes reach further back").
  - On 5-6 lanes the counts cycle 1, 2, 3, 1, 3, 2 (`up_counts`).
  - The cues alternate, starting with "the hut's lanes that lead up run further" (RUN_ON) on the
    first step.
  - A "roof's lanes reach further back" step (REACH_BACK) has at most two lanes
    (`MechaGuppyClimb.REACH_BACK_MOST`), so the threes always come with RUN_ON, and the count changes
    every step.
  - Where the block of lanes sits is seeded: the same on every attempt, never the same block twice
    running, nor three times running for the same cue (3 lanes: the same lane never leads up on more
    than two REACH_BACK, or RUN_ON, steps in a row).

  Is this the owner's "alternating"?
- **The roof faces' rules** (GDD §10 doesn't say). Placeholder (`MechaGuppyStairs`, DESIGN-TBD):
  - A roof's sides below its top are a lane blocker. A lane switch into them bumps back, as into a
    truck's side.
  - A roof's front, below the depth a runner can still step up from, is a solid hazard ("tiki bar")
    that the dash doesn't pass: running into it kills, because what looks like a hit is a hit.

  The plan keeps every front out of a living runner's path. A wrong drop is dead (or saved) before it
  reaches the front, even dashing, and a right drop lands on the top. The one way to meet a front is
  to step sideways off a reaching tongue into the gap beside it, a fall that ends in a death either
  way.
- **The street at the start** (GDD §10: Mecha Guppy eats the level from below). Placeholder
  (`MechaGuppy._plan_lap`, `MechaGuppyStairs`): the fight starts on the street (roof 0, the climb's own
  floor), which is eaten just past the first pads like every roof. Under the climb there is no track
  floor at all: water.
- **No side walls** (GDD §10: occasional walls as a last-ditch save, or none if too complex; E5e-d).
  Placeholder: none. A wall gap runs over the whole arena on both sides, and the open beach and sea
  lie beyond (`MechaGuppySkin`).
- **The climb's look** (GDD §10: tiki huts as the ceilings, tiki bar roofs as the floors, a few neon
  signs; the climb must read as climbing high). Placeholder (`MechaGuppyLooks`):
  - The huts: each hut is a hovering plank platform on glowing lift pods (the Beach's engine colour,
    never a hazard colour), with a lamp-lit underside, a 4 m orange band where each lane ends, a lamp
    row along each run of lanes' shared edge (so the lanes that lead up visibly run on, lit), and a row
    of tiki huts on top. RUN_ON steps add a walkway annex over the lanes that run on.
  - The roofs: each roof is a boardwalk deck with orange lips at its edges and fronts, thatch eaves and
    lantern posts outside the lanes, on top of a tower that stands down to the water: storey after
    storey of tiki bar, each with a ledge and a row of warmly lit windows, darker the deeper.
  - The lanes that reach back (REACH_BACK) stand on a pier in front of the tower: a lantern-lit fascia,
    the orange lip at its front and along the gap beside it, and the dark framework of a pier on tall
    stilts below, so they read as a landing, not a wall. No marker beyond the owner's two cues was
    added; if playtests show riders still steering away from it, a floor marking on the pier's deck
    could be proposed then.
  - The signs: some fronts and huts carry a neon sign in the Beach's violet, blue or warm white.
  - The eaten floor: the chasm between towers, open to the water far below (the street's own water),
    where E5e-b2's shark will rise.
- **The backdrop** (GDD §10: a waterfall in phases 1 and 2, the Beach's normal backdrop in phase 3).
  Placeholder (`MechaGuppyWaterfall`): a flat-topped massif 420 m ahead of the camera, its falls' lip
  150 m up, its rock, lip and mist at world heights, so as the runner climbs the cliffs slide down and
  the falls' foot sinks below; past the lip a plateau shows its top. Its flanks slope to the sea, so
  the horizon stays in view beside it. A sea plane fills everything below out to the far plane, and the
  sky below the horizon takes the fog's colour. Layers of low cloud at fixed heights (12 m, then every
  36 m) lie beside the climb once the runner is above them. The waterfall fades out over 2 s when the
  runner reaches phase 3's top.
- **The arena's haze** (`data/bosses/beach_boss_skin.tres`): fog from 24 m to 200 m, fully fogged past
  it (the Beach's levels: 34-250 m, 90% at most). The long drop below the towers hazes over with depth,
  and the climb is planned no nearer than that edge of sight, so nothing ever changes where it's seen.
- **How soon a phase change reaches the climb** (GDD §10: phase 2's climb 15-25% faster). Placeholder:
  the steps in sight when the phase changes stay as they are, and the first one past the edge of sight
  (200 m) is the new phase's. Measured right after a landing, phase 2's first closer step comes
  11.6-12.7 s after the phase begins (one or two steps), and phase 3's top 9-16 s after it begins. A
  hazier arena would bring it sooner, at the cost of the view ahead. Is that soon enough?
- **Phase 3 and the fight's frame** (E5e-c builds phase 3). Placeholders in
  `data/bosses/beach_boss.tres`:
  - The phases are named "The Climb", "Higher" and "Level with Captain Cogs", each a third of the
    boss bar (equal health shares).
  - Phase 3 is a flat run on the last roof, with no attacks and no hits, that the fight wins 60 s
    after the runner reaches it (`top_seconds`; `MechaGuppy.top_reached`, logged and signalled for
    E5e-c).
  - Par times of 240 s and 180 s stand in until E5e-c measures the whole fight.
