# E5e: Mecha Guppy and Captain Cogs, open questions

Raised by step E5e-a (the climb's core), step E5e-b1 (the climb itself), step E5e-b2 (the shark, the
pirate, the bombs and the hits) and step E5e-b3 (the hits by baiting, phase 2's bombs, the review's fixes).
The rest of the fight is built in E5e-c (phase 3, the defeat), which can answer these as it goes. Where a later
step changed an earlier placeholder, the entry says so.

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
  lead up falls into the chasm under the hut, down to the water far below (where E5e-b2's shark rises
  after the hut's deadline, and it bites the end of the roof just left), and dies unless the grapple saves
  it. Nobody lands on uneaten lower floor.

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
    (`roof_seconds`): phase 2 climbs 19-22% faster. **Changed by E5e-b3:** every roof now holds a volley and
    the bait, so the run is 3.6 s in both phases, 0.14 s (a lane switch) longer for each lane past three, and
    phase 2's roofs stand 3.6 m apart instead of 3 m (`phase2_rise`): phase 2 climbs 20% faster in metres a
    second at every lane count and speed (see "Raised by E5e-b3").
  - The reaching lanes reach 10 m under the hut's end (`reach_back`, at 18 m/s), and the running-on
    lanes run 3 m past the higher roof's front (`run_on`, at 18 m/s).
  - The street is 3.5 s long before the first pads (`start_seconds`).

  A step takes about 5.5-6 s in phase 1, which is 10 or 11 roofs (about 30-33 m up) a minute. **Since
  E5e-b3:** 7.4-8.5 s, about 21-24 m up a minute in phase 1 and 26-29 m in phase 2.
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
    where the shark rises (E5e-b2).
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
  hazier arena would bring it sooner, at the cost of the view ahead. Is that soon enough? (E5e-b3: phase 2's
  first higher step's pads come 10.3-18.2 s after the phase begins.)
- **Phase 3 and the fight's frame** (E5e-c builds phase 3). Placeholders in
  `data/bosses/beach_boss.tres`:
  - The phases are named "The Climb", "Higher" and "Level with Captain Cogs", each a third of the
    boss bar (equal health shares).
  - Phase 3 is a flat run on the last roof, with no attacks and no hits, that the fight wins 60 s
    after the runner reaches it (`top_seconds`; `MechaGuppy.top_reached`, logged and signalled for
    E5e-c).
  - Par times of 240 s and 180 s stand in until E5e-c measures the whole fight. (E5e-b3: a runner who baits
    every step clears phases 1 and 2 in 78-87 s, one who never does in 223-252 s, before phase 3's minute.)

## Raised by E5e-b2 (the shark, the pirate, the bombs and the hits)

- **How the hits come** (GDD §10: only a bomb that falls through a gap, off a roof's edge or into a
  stretch the shark has eaten through, where it's clearly exposed and in the line of fire; "aim the bombs
  so a runner who dodges well lands hits steadily"). Placeholder (`MechaGuppyPattern._hit`, `hit_spot`,
  DESIGN-TBD): on every step, at the hut's deadline (when every rider is committed), Captain Cogs throws a
  bomb at the chasm in front of the higher roof, beside the lanes that lead up on the side with more
  lanes that don't (`hit_back` 6.8 m before that roof's front; `hit_seconds` 0.65 s of flight, its circle
  and whistle as every bomb's), and Mecha Guppy rises there to eat, its jaws open as the bomb comes down
  into them: a hit. So a runner who keeps climbing (who dodges well enough to survive the step) lands one
  hit a step: 4 steps end phase 1 and 6 phase 2. The clean bot's phase 1 ends at about 24-26 s and phase 2
  about 29-32 s later. Is "one hit a step" the owner's steady hits? The alternative (hits only when bombs
  aimed at the runner happen to miss past an edge) would make hits depend on luck and on dodging badly.
  **Answered (owner, October 11, 2026): bait the bombs.** Captain Cogs' bombs lock onto the runner's lane; a
  runner who dodges one at a roof's end or a pier's open side sends it past the edge into Mecha Guppy's jaws,
  a hit, the way the Floating Head's laser is baited into a tower. A player who doesn't manage it still
  progresses, more slowly: Captain Cogs sometimes misses into the chasm anyway (GDD §10). Built by E5e-b3 (see
  "Raised by E5e-b3"): the "one hit a step" above is now the fallback, after `fallback_after` steps without a hit.
- **Where the shark is eaten "under the lanes that don't lead up"** (GDD §10: "the rest drop them back onto
  the floor they came from, where Mecha Guppy is eating"). Placeholder: the floor there is already gone
  (E5e-b1's chasm); the shark shows itself eating there by breaching in that chasm for the hit, only after
  the hut's deadline, so it never becomes a third cue to which lanes lead up (only the owner's two cues
  tell). Before the deadline it lurks deep under the middle of the chasm, facing the runner, giving nothing
  away. Should it show itself there earlier, as a help to readers? (E5e-b3: this breach is now the fallback's
  only; the lurk is out of sight altogether, since E5e-b2's review saw its snout from the hut.)
- **The bites** (GDD §10: its maw comes up through the floor and eats a huge chunk of the level; it eats
  the floors the runner should have left, never the floor they're on or the safe drop; every bite that
  could catch the runner warned). Placeholder (`MechaGuppyShark.bite`, `MechaGuppyPattern._bite`, the
  tuning's "Mecha Guppy's bites"; DESIGN-TBD):
  - Each step it bites the end of the roof the runner has just left (`bite_length` 14 m, never past the
    hut's start), only once the runner is up on that roof's hut: no bite can catch a runner.
  - Its warning all the same: the rumble (guppy_rumble) and the shark surging up beside the roof's end,
    upright, an eye just over the roof's top, 0.6 s before the runner reaches the pads (`bite_warning`),
    seen ahead.
  - The bite: it dives under the roof's top leaning in, lunges with its chin low across the roof, holds and
    snaps shut, dropping 7 m away with the roof's end (0.25 + 0.35 + 0.15 + 0.14 s); the roof's collision and
    look are cut together at the snap, rubble flying. Its jaws stay at least 2.5 m under a rider hanging
    from the hut, even mid-jump (2.8 m measured), so nothing looks like it reaches them. It comes from a
    seeded side. (E5e-b3: counting the jaws' tip caps, which E5e-b2's measure missed, the snap's closing chin
    came to 2.43 m; the snap now drops first and closes late: 3.36 m measured. On a roof with a notch the bite
    comes from the shark's catch beside the notch, on the notch's side.)
  - In phase 2's closer steps the shark can still be busy with the last step's hit when a bite is due:
    the bite waits for it, while it can still be over before the step's hit (`bite_spare`, in the tuning
    since E5e-b3; phase 2's steps are no longer closer).

  Is the end of the roof just left the right floor to eat, and is a bite under the rider (seen mostly as
  it rises ahead and lunges below) readable enough?
- **Mecha Guppy's look and size** (GDD §10: building-sized, mechanical, mostly its giant jaws and its eyes,
  dark red lenses that don't glow, nothing glowing red). Placeholder (`MechaGuppySharkModel`,
  `MechaGuppyShark.SCALE`): jaws 12 m long and 12.6 m across at the hinge, riveted grey steel plates with
  dark seams, rows of steel teeth, a dark ribbed mouth, round dark red glass lenses with a darker iris in
  steel bezels; the body below the hinge stays down in the chasm. It is always shown side-on, in profile
  (the eye toward the runner), and has no hitbox. (E5e-b3: in its catch beside a notch it leans in so its lower
  jaw lies flat under the notch's lane, the upper jaw raised beside the track, an eye toward the runner.)
- **Captain Cogs' look and the ship's station** (GDD §10: a pirate mixed with a futuristic look, in a
  floating ship flying above the track). Placeholder (`CaptainCogsSuit`, `CaptainCogsModel`,
  `CaptainCogsShip`): a burly pirate, 2.4 m tall, in a teal frock coat, a tricorn with a brass cog badge, a
  braided beard, an eyepatch, a clockwork brass arm and a monocle-eye glowing the Beach's blue (the skin's
  `neon_blue` since E5e-b3), on the
  stern castle of a flying galleon (brass bands, cannons, a patched sail with a cog-toothed skull, a neon
  violet trim, hover pods, brass cog wheels turning on its flanks). It keeps 40 m ahead of the runner
  (`ship_ahead`) and 16.5 m over the floor base (`ship_height`), stern toward them, and has no collision.
- **The bombs a step, and phase 2's "more bombs"** (GDD §10: the bombs warned like the Floating Head's;
  phase 2 the same with more bombs). Placeholders (`MechaGuppyTuning`, "Captain Cogs' bombs"):
  - The Floating Head's warning: a red circle at the floor's height from the throw, a whistle, 1.1 s from
    the throw to the landing (`lock_seconds`); its salvo rules for the spots (a lane to dodge into always
    reached in time, never off a pier's side, never under a hut, never on a pickup). The circles never show
    before the hut's deadline (so they never hint at the lanes that lead up).
  - Phase 1: a volley of two spots on the higher roof's run each step (one or two bombs a spot on 3 lanes,
    two or three on 5-6), 2.3-3.5 bombs a step.
  - Phase 2: one spot on the roof's run, a landing spot where riders come down (dodged in the air off the
    hut's end), and two bombs on the hut over a rider, which burst on its top (the owner's rule: the
    ceiling between them shields a rider), 4.3-4.5 bombs a step. The hut's bombs show no circle (nobody can
    stand there) and a rider under the hut only hears and feels them. Are harmless hut bombs part of the
    owner's "more bombs", or should phase 2 put more on the roofs instead? **Superseded by E5e-b3** (E5e-b2's
    review: the hut bombs were harmless and unseen, and phase 2 had fewer bombs to dodge than phase 1): the hut
    bombs are gone, and phase 2 has more bombs that can reach the runner (see "Raised by E5e-b3").
- **The hit's show** (GDD §10: the bomb falling, a clang, sparks or smoke). Placeholder: the bomb counts
  the moment it falls inside the open jaws (high in the mouth, where the runner sees it): a fireball,
  sparks and smoke there (RunEffects', calmed by Reduced flashing), the clang (guppy_clang), a shudder and a
  camera shake, and the shark recoils, snapping shut and sinking out of sight before the camera passes.
- **The fight's sounds** (`tools/asset_gen/sfx_bank_mecha_guppy.gd`): the captain's throw (a whoosh, a
  clockwork ratchet and a gruff "harr!"), the shark coming up (grinding machinery, a rising whine, plates
  clanking: the bites' and breaches' warning), its bite (a steel clank, hydraulics, crunching timber), a
  hit's clang (the blast, a ringing steel clang, sparks, a groan). The bombs keep the Floating Head's
  whistle and blast. (E5e-b3 adds cogs_aim, the captain taking aim while the bait's circle follows the runner,
  as long as `bait_seek`: ratchet clicks quickening over a servo whirring up, ending on a catch as the circle
  locks; the fallback's bomb is neither heard thrown nor whistles, since there is nothing to dodge.)


## Raised by E5e-b3 (the hits by baiting, phase 2's bombs)

- **The bait's shape** (GDD §10, the owner, October 11, 2026: Captain Cogs' bombs lock onto the runner's lane, and
  a runner who dodges one at a roof's end or a pier's open side sends it past the edge into Mecha Guppy's jaws).
  Placeholder (`MechaGuppyPattern._bait`, `MechaGuppyBombs.start_bait` and `lock_bait`, the tuning's "The hits";
  DESIGN-TBD):
  - From the first tower on (not the street, not the top), each roof has a **notch** near its end: Mecha Guppy has
    eaten its outer lane for the last `notch_back` (7.5 m) before the next hut starts, on a seeded side. It has the
    eaten floor's look (the orange lip, the eaten face, the chasm below), it's built with the roof, so it's in sight
    from the landing, and that lane has no pads; no pickup and no volley spot comes near it.
  - As the runner comes near, Mecha Guppy rises into its **catch** beside the notch, with its rumble: its jaws wide,
    the lower jaw flat under the notch's lane, the upper jaw raised beside the track. Captain Cogs takes aim
    (cogs_aim) and one bomb's circle, a little smaller and steady, follows the runner's lane for `bait_seek`
    (0.6 s), where the bomb will land: `catch_in` (4 m) into the notch (on the roof's top in every other lane). Then
    it **locks** onto the lane the runner is in, with the throw and the whistle, 1.1 s before it lands as they get
    there (`lock_seconds`, the Floating Head's warning).
  - Locked in the notch's lane, the runner has to switch out before the notch's edge anyway (their lane ends there,
    about a second after the lock at either speed), and the bomb goes on past the edge into the jaws as it passes
    the roof's top: **a hit**. Locked in any other lane, it's a spot of one bomb on the roof, dodged like any other.
    So the bait asks the runner to be in the notch's lane as the circle locks, then to dodge out, which is what the
    lane's end asks of them too: the dodge and the escape are the same move.
  - **Why the notch, not the hut's ends or the piers' open sides** (E5e-b2's review named those as today's places
    where a lane runs out):
    - Under a hut's ending lanes the runner hangs from the hut. A bomb there bursts on the hut's top, never touching
      them (the owner's rule), and a bomb at the roof below lands after they've dropped, so nothing there threatens
      a rider to bait. A catch beside the ending lanes before the hut's deadline would also show where the lanes
      don't lead up: a third cue, which only the owner's two cues may give; after the deadline there's no time left
      for a bait.
    - A pier's open side: on 3 lanes (and often on 5-6) a REACH_BACK pier is one lane wide, so a runner on it can't
      dodge sideways at all (task E5e-b2's review found exactly that trap). Baiting there would mean holding the
      only lane under a circle, or stepping off into the chasm. A catch beside a pier would also sit beside or
      behind the camera as the runner lands.
    - The notch is a stretch the shark "has eaten through" and where it is "clearly exposed and in the line of
      fire" (GDD §10): the runner sees it from the landing, has room to dodge on every lane count, the catch sits
      ahead beside the track in plain view, and it's the same on every roof. It is at the roof's end, as the owner
      put it, though not a pier's side.
  - **No third cue**: the notch is on the roof the runner is running on, before the next hut, and its side is seeded
    apart from the lanes that lead up next (the same sides whatever `up_counts` says: `test_mecha_guppy` checks it),
    so neither it nor the shark beside it tells anything about the next step. No new cue to which lanes lead up was
    added.
  - **The catch's reach**: no part of the jaws is ever over a lane a runner may use, nor over the notch's lane before
    the notch, at any height: the head lies out beside the track, its tip 0.4 m short of the next lane
    (`MechaGuppyShark.CATCH_CLEAR`; `test_mecha_guppy_bites` checks every frame of a fight).

  Is a notch near each roof's end the owner's "roof's end"? Is one bait a step (a hit a step for a runner who baits
  well, 4 and 6 steps for phases 1 and 2) right? Should the pier's side be a bait place too, on 5-6 lanes where a
  pier is two lanes wide?
- **The bait's circle in the notch's lane** (the circles show where a bomb lands, at that floor's height). In the
  notch's lane there is no floor: the circle hangs over the gap at the roof's top, where the bomb passes on its way
  into the jaws. Is that readable, or should a circle there look different?
- **The fallback's cadence** (GDD §10: "Captain Cogs sometimes misses into the chasm anyway"). Placeholder
  (`fallback_after` 2, DESIGN-TBD): once 2 steps in a row have gone by without a hit, at the next step's hut deadline
  (every rider committed), with the rider in a lane that leads up, Captain Cogs misses into the chasm beside the lanes
  that lead up and Mecha Guppy rises to eat it (E5e-b2's hit, unchanged; its bomb is neither heard thrown nor whistles,
  since it threatens nobody, and the shark glides deep out of sight until it surges up). A runner who never baits
  lands a hit every third step: phase 1 ends at 88.6-99.9 s and phase 2 at 222.6-251.7 s, against 32.8-36.7 s and
  77.5-87.3 s for a runner who baits every step (3, 5 and 6 lanes, 18 and 23.8 m/s). Nothing escalates. A step with
  no bait to offer (under an extreme tuning a roof may have no room for a notch) counts as one without a hit, so the
  hits never stall. Which N does the owner want? (1 would give a hit every other step; 0 a hit every step, leaving no
  reason to bait.)
- **No hit on a step the runner fell** (a rule from E5e-b3's brief): on a step where the runner fell, even if
  the grapple (or a revive) saved them, no bomb hits: a bait locked then falls past into the chasm as the shark shuts
  its jaws, and a fallback due then waits for the next step. Right?
- **A fall into the notch**: a runner who runs on past the notch's edge falls into the chasm; the grapple's save (or
  a revive) takes them back up onto the roof they fell from, into its lane beside the notch, rather than up onto the
  higher roof as other falls go (that one may still be far ahead). Falling there, a lane switch toward the roof just
  under its top bumps off its side (the roof faces' rule); deeper, as in any pit, it does nothing. Right?
- **Phase 2's "more bombs" and faster climb** (GDD §10: the same with more bombs and a climb 15-25% faster;
  *(proposed)* by bringing the steps closer together). Placeholders (`roof_spots`, `landing_spots`, `spot_bombs`,
  `spot_bombs_wide`, `roof_seconds`, `phase2_rise`; DESIGN-TBD):
  - Every roof now holds a volley and the bait, which need its run (3.6 s from the landing to the next pads, 0.14 s
    longer for each lane past three, with time between the volley and the bait for a runner to cross from the far
    side to the notch: `bait_after`). Closer steps would leave no room, so phase 2 climbs faster by **higher steps**:
    its roofs stand 3.6 m apart instead of 3 m (`phase2_rise`), the steps as long as phase 1's, and the climb rises
    20.0% faster in metres a second at 3, 5 and 6 lanes and both speeds. Every margin holds (the reading margin
    still 0.9 s); the hut keeps 4.9 m over the higher roof. Is climbing faster by higher steps acceptable instead
    of the proposed closer steps?
  - The hut bombs are gone (E5e-b2's review: harmless and unseen), and no bomb is thrown that has nothing to dodge
    but the fallback's (silent). Phase 1 throws a spot on each roof's run (one bomb on 3 lanes, two side by side
    on 5-6) and the bait; phase 2 adds, after each RUN_ON step, a spot where riders come down (dodged by a switch
    in the air as they drop off the hut's end), and its spots take a bomb more (two on 3 lanes, three on 5-6). Counting
    only the bombs that can reach the runner, the bait's included: phase 1 has 2.0-2.75 a step and 0.24-0.31 a
    second, phase 2 3.5-4.3 a step and 0.46-0.54 a second (3, 5 and 6 lanes, 18 and 23.8 m/s): 52-85% more a step
    and 65-102% more a second. Is that the owner's "more bombs", or too many? (The owner's 15-25% is read as the
    climb's figure; fewer spot bombs in phase 2 would bring it nearer that if it is meant for the bombs too.)
  - No circle ever shows in the runner's lane while every lane they could switch to has no floor (task E5e-b2's
    review: on a REACH_BACK pier the roof's first spot came down in the runner's lane as they landed). A roof's spots
    are thrown no sooner than the runner can switch lanes there (`Step.free_at`), and the suites check every frame of
    every fight.
- **The reaction the fight is planned for**: the planner gives every dodge `dodge_reaction` (0.35 s, the suites'
  usual reaction), then each lane switch the escape needs, plus `dodge_margin` (0.25 s). The suites' bot now waits
  exactly `dodge_reaction` after every circle shows and after the bait locks before it moves, and wins at every lane
  count and speed. In scratch runs a bot reacting in 0.65 s also won phases 1 and 2 at 3 and 6 lanes, missing some
  baits (so a little slower), but the plan only promises 0.35 s. Should this fight plan for a slower reaction?
