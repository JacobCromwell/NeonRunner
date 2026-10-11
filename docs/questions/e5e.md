# E5e: Mecha Guppy and Captain Cogs, open questions

Raised by step E5e-a (the climb's core), step E5e-b1 (the climb itself), step E5e-b2 (the shark, the
pirate, the bombs and the hits), step E5e-b3 (the hits by baiting, phase 2's bombs, the review's fixes), step
E5e-c (phase 3, the defeat, the campaign slot, the par times and rewards) and step E5e-f (Mecha Guppy's floor bite).
Where a later step changed an earlier placeholder, the entry says so.

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
    E5e-c). **Changed by E5e-c:** phase 3 is built (see "Raised by E5e-c").
  - Par times of 240 s and 180 s stand in until E5e-c measures the whole fight. (E5e-b3: a runner who baits
    every step clears phases 1 and 2 in 85-96 s, one who never does in 156-176 s, before phase 3's minute.)
    **Changed by E5e-c:** 177 s and 210 s (see "Raised by E5e-c").

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
  - From the second tower on (roof 2: not the street, not the first tower, whose run brings the climb's first volley,
    so the bait comes once that has been learned; not the top; E5e-f's review changed this: the first tower now brings
    the first floor bite alone and the first volley comes on roof 3, after the first bait, see "Raised by E5e-f"), each
    roof has a **notch** near its end: Mecha Guppy
    has eaten its outer lane for the last `notch_back` (7.5 m) before the next hut starts, on a seeded side. It has the
    eaten floor's look (the orange lip, the eaten face, the chasm below), it's built with the roof, so it's in sight
    from the landing, and that lane has no pads; no pickup and no volley spot comes near it.
  - As the runner comes near, Mecha Guppy rises into its **catch** beside the notch, with its rumble: its jaws wide,
    the lower jaw flat under the notch's lane, the upper jaw raised beside the track. Captain Cogs takes aim
    (cogs_aim) and the bomb's **aim**, a red target, follows the runner's lane for `bait_seek` (0.6 s), where the bomb
    will land: `catch_in` (4 m) into the notch (on the roof's top in every other lane). Then it **locks** onto the lane
    the runner is in, with the throw and the whistle, 1.1 s before it lands as they get there (`lock_seconds`, the
    Floating Head's warning), and the bomb's own flat circle takes its place.
  - Locked in the notch's lane, the runner has to switch out before the notch's edge anyway (their lane ends there,
    about a second after the lock at either speed), and the bomb goes on past the edge into the jaws as it passes
    the roof's top: **a hit**. Locked in any other lane, it's a spot of one bomb on the roof, dodged like any other.
    So the bait asks the runner to be in the notch's lane as the aim locks, then to dodge out, which is what the
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
  pier is two lanes wide? Is the first bait on the second tower right (E5e-b3's review: the first step already
  brings the climb and the first volley; since E5e-f's review, the climb and the first floor bite, the first volley
  coming on roof 3)?
- **The bait's aim** (E5e-b3's review: the following circle, a flat ring a little smaller than a bomb's circle, showed
  40 m out as a red sliver a few pixels high). Placeholder (`MechaGuppyBombs._aim_node`, `AIM_SCALE`, `AIM_LIFT`;
  DESIGN-TBD): a red target, a ring 1.25 times a bomb circle's size with four ticks across it, standing on the floor
  where the bomb will land and leaning back 45 degrees from it, its face toward the runner, so it reads from 40 m
  out; steady (no pulse, unlike the locked circle, so nothing flickers with Reduced flashing). At the lock the bomb's
  own flat, pulsing circle takes its place. In the notch's lane there is no floor: the aim, and then the circle, hang
  over the gap at the roof's top, where the bomb passes on its way into the jaws. Is a standing target the right look
  for the aim, and is the circle over the gap readable?
- **The fallback's cadence** (GDD §10: "Captain Cogs sometimes misses into the chasm anyway"). Placeholder
  (`fallback_after` 1, DESIGN-TBD; 2 until E5e-b3's review, which found a fight with no checkpoint dragging out to
  about 5 minutes): once a step has gone by without a hit, from the next step's hut deadline (every rider committed),
  with the rider in a lane that leads up, Captain Cogs misses into the chasm beside the lanes that lead up and Mecha
  Guppy rises to eat it (E5e-b2's hit; its bomb is neither heard thrown nor whistles, since it threatens nobody, and
  the shark glides deep out of sight until it surges up). A runner who never baits lands a hit every other step:
  phase 1 ends at 66.2-74.6 s and phase 2 at 155.5-175.7 s, against 40.4-45.3 s and 85.1-95.8 s for a runner who baits
  every step (3, 5 and 6 lanes, 18 and 23.8 m/s): 1.6 and 1.8 times as long. Nothing escalates. A step with no bait to
  offer (under an extreme tuning a roof may have no room for a fair one) counts as one without a hit, so the hits never
  stall. Which N does the owner want? (2 gave a hit every third step: 223-252 s for phases 1 and 2 before the first
  notch moved to roof 2; 0 would give a hit every step, leaving no reason to bait.)
- **At most one hit a step** (E5e-b3's review): a step its fallback already hit offers no bait (no aim follows the
  runner, no catch), so a runner never lands both on one step, and an aim that follows them is always a chance at a
  hit. Right?
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
    only the bombs that can reach the runner, the bait's included, over the steps that threw any: phase 1 has
    1.8-2.6 a step and 0.22-0.30 a second, phase 2 3.5-4.3 a step and 0.46-0.54 a second (3, 5 and 6 lanes, 18 and
    23.8 m/s): 60-94% more a step and 72-111% more a second (phase 1's first step has no bait now). Is that the
    owner's "more bombs", or too many? (The owner's 15-25% is read as the climb's figure; fewer spot bombs in phase 2
    would bring it nearer that if it is meant for the bombs too.)
  - No circle ever shows in the runner's lane while every lane they could switch to has no floor (task E5e-b2's
    review: on a REACH_BACK pier the roof's first spot came down in the runner's lane as they landed). A roof's spots
    are thrown no sooner than the runner can switch lanes there (`Step.free_at`), and the suites check every frame of
    every fight.
- **Extreme tunings** (E5e-b3's review found tunables inside their own F6 ranges breaking the bait's and the
  fallback's promises; `test_mecha_guppy_tunables` now checks every tunable at both ends of its range on physics, at
  3 lanes and 23.8 m/s and at 6 lanes and 18 m/s). Placeholders (`MechaGuppyPattern`, DESIGN-TBD):
  - A step whose bait can't be fair gets none and counts toward the fallback: the aim shows only once the runner can
    switch lanes on that roof and has had a reaction (`dodge_reaction` past `Step.free_at` and the hut's deadline),
    and a runner in the notch's lane as it locks has a reaction, a lane switch and `dodge_margin` to leave it before
    its edge. A notch starts that far past where its roof's run begins, too, or the roof has none. At the far ends
    of `bait_seek`, `lock_seconds` or `roof_seconds` this leaves no baits at all: the fallback brings every hit.
  - The fallback is thrown only once Mecha Guppy can rise for it, waiting while its bomb can still come down before
    the runner draws level with it; a bite of the roof just left that would keep the shark busy past that gives way:
    the shark sinks off and that roof's end stays uneaten that step (only under extreme bite timings). Where Mecha
    Guppy needs longer to surge up and open its jaws (`breach_rise`), the fallback's bomb flies longer than
    `hit_seconds` and can come down behind the runner.

  Are these the right ways to give at the extremes, or should those tunables' ranges be narrowed instead?
- **The reaction the fight is planned for**: the planner gives every dodge `dodge_reaction` (0.35 s, the suites'
  usual reaction), then each lane switch the escape needs, plus `dodge_margin` (0.25 s). The suites' bot now waits
  exactly `dodge_reaction` after every circle shows and after the bait locks before it moves, and wins at every lane
  count and speed. In scratch runs a bot reacting in 0.65 s also won phases 1 and 2 at 3 and 6 lanes, missing some
  baits (so a little slower), but the plan only promises 0.35 s. Should this fight plan for a slower reaction?

## Raised by E5e-c (phase 3, the defeat, the campaign slot, the par times and rewards)

- **Where Captain Cogs' ship comes level** (GDD §10: "the captain's ship comes level with the player"). Placeholder
  (`CaptainCogsShip.come_level`, the tuning's "Phase 3"; DESIGN-TBD): as the runner reaches the top, the ship eases
  over `level_seconds` (3 s) from its station above the climb to one alongside the top on the left (`LEVEL_SIDE`),
  its hull `level_out` (2.5 m) outside the top's eaves, its keel `level_keel` (1 m) under the deck so its gun deck
  and the captain stand at the runner's height, `level_ahead` (30 m) ahead, keeping pace, no longer swaying; its
  three starboard cannons face the top. Alongside rather than ahead over the lanes, so the cannonballs come from
  the side and Mecha Guppy can leap up beside the top to eat it without its body ever crossing the lanes. Is
  alongside on the left right, and close enough to read as "level with" the runner?
- **The script** (GDD §10: a fixed, learnable script, no escalation; the owner's approval of the warnings,
  item 698). Placeholder (`MechaGuppyTop.plan`, `top_script` "RRW.RWRRW.", `top_first`, `top_beat`, `top_clear`;
  DESIGN-TBD): the script loops from `top_first` (4 s after the top is reached), a beat every `top_beat` (2.4 s): R a
  round, W a wave, a dot a rest. No beat's warning starts before the last beat's attack has passed the runner
  (`beat_spare`, 0.3 s), so a jump and a switch are never asked for at once, and none whose attack would end later
  than `top_clear` (1 s) before the minute's end: 18 beats a minute, 12 rounds and 6 waves, the last over 56.3 s in.
  Everything is timed from the top by the fight's clock, so a retry plays the same and nothing escalates. A beat held
  back (the pattern not running yet, as in phase 3's intro) starts late, at most one a physics step, and every later
  beat keeps its gap after it (`MechaGuppyTop.late`; E5e-c's review: they used to start together, two rounds striking
  every lane between them). Is that mix and rhythm right, and should rests come more often?
- **The rounds' look and rule** (GDD §10; the owner's warning: "red lines down the lanes they'll hit and a cannon's
  charging sound"). Placeholder (`MechaGuppyRounds`, `round_warning`, `round_flight`, `round_ahead`, `round_close`,
  `round_radius`; DESIGN-TBD):
  - A round strikes every other lane (`MechaGuppyTop.struck`): the lanes 0, 2, 4... or the others, alternating round
    by round, so a clear lane is always one switch away on any lane count. A struck lane with a pickup in its stretch
    is left out (`PICKUP_CLEAR`).
  - The warning: a red line down each struck lane on the top's deck (`BossProps.lane_warning`, pulsing, steady with
    Reduced flashing), over the stretch its ball will roll, with the cannons' charge (cogs_charge, as long as
    `round_warning`, 0.8 s). Then the broadside (cogs_cannon, a flash, smoke and a recoil): a cannonball from a
    starboard cannon for each struck lane, lobbed over the eaves (`round_flight`, 0.3 s) onto the far end of its line,
    `round_ahead` (24 m) ahead, then rolling down the lane at the runner, closing in at `round_close` (50 m/s): it
    reaches them 1.58 s after its warning at any run speed (the plan needs a reaction, a lane switch and
    `dodge_margin`: 0.74 s).
  - The cannonball: an iron ball `round_radius` (1.15 m) with a brass band, rolling; its hitbox 65% of its width, 85%
    of its height (1.96 m: too tall to jump, so the dodge is a switch) and 70% of its depth, an enemy attack (armor
    and the shield block it, the dash passes through it).

  Are lobbed balls rolling down the lanes the owner's "rounds"? Is every other lane, alternating, the right shape?
- **The waves' look** (GDD §10; the owner's warning: "a rising swell and a roar", jumped like the Resonator's ring).
  Placeholder (`MechaGuppyWaves`, `mecha_guppy_wave.gdshader`, `wave_warning`, `wave_ahead`, `wave_close`,
  `wave_height`, `wave_depth`; DESIGN-TBD): a swell rises out of the sea beside the top on the right, away from the
  ship, for `wave_warning` (1.2 s) with its roar (wave_swell, as long), its crest breaking the deck's line within the
  first 0.25 s (`CREST_BY`; it rises from 11 m down, eased out hard: E5e-c's review found it hidden for half the
  warning from 30 m down) and standing 7.6 m over the deck by the crash; then it crashes over every lane `wave_ahead`
  (24 m) ahead (wave_crash, foam) and its surge rushes along the deck at the runner at `wave_close` (30 m/s), 2.0 s
  after its warning: a low band across every lane, `wave_height` (0.45 m) tall and `wave_depth` (0.5 m) deep, so a
  normal jump clears it, as the Resonator's ring's does; armor and the shield block it, the dash passes through it.
  The swell is a medium-bright turquoise wall of sea water with white foam along its crest, and the surge a paler teal
  sheet with a white foaming crest (the water never glows); the surge carries one red line low on its face, the
  Resonator's ring red, as the sign of a low band to jump (the water's colour alone would not warn). Its streaks
  stand still with Reduced flashing. Is the red line on the water right, or should the surge read by its foam alone?
- **The minute and the boss bar** (GDD §10, proposed: the boss bar runs down over the minute). Placeholder
  (`MechaGuppyTop.run_down`, `top_seconds` 60 s): the minute counts from `top_reached` by the fight's clock; the bar
  runs from phase 3's share down toward nothing, and the fight is won as it ends (the phase's one counted hit, logged
  `top_over`), never by a hit: bombs and weapons do nothing in phase 3. The top comes 4.0-13.9 s after phase 3 begins
  (the steps already in sight first); were it reached within phase 3's intro (2.5 s), the bar would start down, and
  the beats come, once the intro ends. While it runs down, the HUD's bar follows it without the white segment's hold
  after each drop (`BossEncounter.health_runs_down`, false for every other boss; E5e-c's review found the white segment
  never draining below about 55 fps). Right?
- **The bites stop at the top** (GDD §10). Captain Cogs' bombs (the volleys, the bait, the fallback) stop as phase 3
  begins, but Mecha Guppy's bites go on through the climb's last steps to the top (the roof just left is still
  eaten: the level being eaten isn't an attack) and stop the moment the runner stands on the top. Right?
- **The low cloud at the top**: the waterfall's layers of low cloud fade out with it as the runner reaches the top
  (the Beach's normal backdrop in phase 3, GDD §10), so the top's sea far below shows hazy and clear. Right?
- **The leap's staging** (GDD §10: Mecha Guppy "jumps over to the boss, Captain Cogs, and eats the boss"; "Mecha
  Guppy has eaten Captain Cogs, and it swims away"). Placeholder (`MechaGuppyLeap`, `leap_rise`, `leap_hang`,
  `leap_fall`, `breach_seconds`, `dive_after`; DESIGN-TBD): as the minute ends, Mecha Guppy bursts up out of the sea under the ship,
  upright and side-on (an eye toward the runner, its chin toward the top, as it always shows itself), its jaws opening
  wide round the ship's stern half (`leap_rise`, 1.2 s, guppy_leap); its jaws snap shut on the stern with the captain
  on it (guppy_gulp, a shudder, a shake): the captain and the stern are gone, and the bow half breaks away, tumbling
  down into the sea with the sail. It hangs a moment (`leap_hang`, 0.45 s), leaning out, and falls back out of sight
  beside the top (`leap_fall`, 0.9 s). Then it swims away where the run camera sees it (E5e-c's review: from the top
  the deck's edge hides the sea for tens of metres out and the haze the rest, so the first placeholder's fin and wake
  at the waterline were never seen, and the results waited about 6.5 s on an empty view): out at sea ahead, it bursts
  out of the water in one long leap heading away, on ahead and out to sea (the leap's roar again; a plume of spray,
  sea-blue turning to white), its whole body clear of the sea at the top of its arc (it has a tail now), and dives back
  in head first with a bigger plume (guppy_swim), over `breach_seconds` (2.8 s) from the sea back to it
  (`MechaGuppyLeap._plan_breach`, its numbers `BREACH_*`): its arc's top 10 m under the deck (at least 24 m over the
  sea), where the camera's line past the deck's edge passes 9 m under it, at least 40 m out (clear of the tower and the
  falling bow), past the shoreline wherever the camera sees the sea's surface it breaks, the top of its arc within 38°
  of the camera's forward axis, at least 55 m ahead; it pulls away at 14 m/s and out at 3 m/s; a higher leap (from a
  higher top: a runner who never baits climbs to about 73 m) takes longer so it moves the same, and from a high top it
  begins already under way, just out of the camera's sight, since nothing of its rise out of the sea far below could be
  seen. The results may follow `dive_after` (0.6 s) after its snout is back in the water (`victory_over`, 5.9-7.0 s
  after the win); it's gone once its tail is under. From the breach to the results some of the shark is in view
  90-100% of the time at 3, 5 and 6 lanes (the whole-fight suite); from a very high top on 5-6 lanes its dive's plume
  stays under the deck's edge (its body is seen diving). Nothing of its jaws or its body comes over the lanes or the top's eaves at any moment, nothing in
  it has a hitbox, and the runner is in the framework's win god mode. Is eating the stern half with the captain (the
  bow falling away) the owner's picture, or should it swallow the whole ship? Is a breach and dive the owner's "swims
  away"?
- **The victory riff after the gulp**: LevelRun's riff at the defeat is off for this fight (`victory_riff`); the
  zone's level-complete riff plays `riff_after` (1 s) after the gulp instead (`victory_riff_on`), so the captain is
  eaten first. Right, or no riff at all?
- **The rewards** (DESIGN-TBD): `payout_credits` 500 and `defeat_score` 5000, the same as its neighbours' (Hostile
  Takeover's and the Sleep Taker's, the framework's defaults). Should a later boss pay more?
- **The par times** (GDD §10, proposed: one star for a win, two and three for par times). Placeholder: three stars at
  177 s, Hostile Takeover's margin (74/68.6) over the slowest whole fight played clean by a runner who baits every step
  at the campaign's speed: clean fights take 157.4-164.4 s at the Beach's 23.8 m/s and 159.2-169.7 s at 18 m/s (3, 5
  and 6 lanes), all three stars. Two stars at 210 s and the time bonus to 260 s (E5e-c's review; the owner's call):
  a runner who never baits wins in 223.1-244.3 s, so one star at every lane count and speed (230 s gave two stars on 3
  lanes and one on 5-6), and two stars need some baiting. Right?

## Raised by E5e-f (Mecha Guppy's floor bite)

The owner's request (October 11, 2026; GDD §10, "The floor bite"): Mecha Guppy bites a shark-bite crescent out of the
floor the runner is still running on, before the pads, leaving one lane; in phase 2 the bite is sometimes so big the
runner has to jump the gap. Everything below is a placeholder (DESIGN-TBD in `MechaGuppyCrescent`, `MechaGuppyClimb`,
`MechaGuppyFloorBite`, `MechaGuppyShark.floor_bite`, `MechaGuppyStairs` (the saves and pickups near a bite),
`MechaGuppyLooks` (the hut's end band, the trench) and the tuning's "Mecha Guppy's floor bite").

- **Which roofs carry one** (the brief: one new mechanic at a time; if a roof can't fit the bite, the volley and the bait,
  lengthen roofs modestly or alternate what each carries). Placeholder (`MechaGuppyClimb.bitten`, `FIRST_BITE`): the
  roofs alternate what they carry.
  - Roof 1, the first tower, has the bite on its own: no volley and no bait. Task E5e-f's review moved its volley off
    (one new mechanic at a time), so the climb now teaches one thing a roof: the floor bite on roof 1, the bait on roof
    2 (with a bite, already learned), the volley on roof 3. This reverses E5e-b3's order, which brought the first volley
    on roof 1 so it was learned before the bait. The alternative is `FIRST_NOTCH` = 3: the first volley on roof 2 and
    the first bait on roof 3, keeping E5e-b3's order, with the bait (and so the hits) starting a step later.
  - From roof 2 on, every other roof (the even ones, which REACH_BACK steps lead onto) has the bite and then the bait,
    with no volley: the bite takes the volley's place. The odd roofs from 3 on keep their volley and bait, so phase 2's
    landing spots, which come after RUN_ON steps, stay.
  - A bitten roof's run is as long as its bite and then its bait need (`_bite_room`), the same in both phases. Counting
    the bite's reaction from where its warning can be read and the dash's reach (task E5e-f's review, below) made these
    roofs longer: at 3 lanes 4.18 s at 18 m/s and 3.90 s at 23.8 m/s, against 3.60 s; at 5 lanes 4.74 s and 4.46 s,
    against 3.88 s; at 6 lanes 5.02 s and 4.74 s, against 4.02 s. Roof 1, with no bait to make room for, has the usual
    run.
  - The effect on the fight: a runner who baits every step finishes phase 1 at 41.0-47.2 s and phase 2 at 86.5-100.8 s
    (before the floor bite: 40.4-45.3 s and 85.1-95.8 s), and wins in 158.0-161.9 s at 23.8 m/s and 162.7-175.7 s at
    18 m/s (before: 157.4-164.4 s and 159.2-169.7 s). A runner who never baits wins in 226.1-254.3 s (before:
    223.1-244.3 s).
  - With fewer volleys there are fewer bombs to dodge. Counting only bombs that can reach the runner, over the steps
    that threw any, phase 2 has 2.50-3.17 a step and 0.317-0.366 a second, against phase 1's 1.50-2.00 and 0.142-0.180
    (before the floor bite: 3.5-4.3 and 0.46-0.54 against 1.8-2.6 and 0.22-0.30). Phase 2 still has more than phase 1.

  Should every roof have a bite instead, with longer roofs, or is alternating right? And should the first volley come
  before the first bait (`FIRST_NOTCH` = 3)?
- **The shape** (the owner's sketch: a crescent bitten in from one side, deepest in the middle). Placeholder
  (`MechaGuppyCrescent`):
  - A half-ellipse `floor_bite_length` (12 m) long along the bitten side, its edge scalloped by 12 teeth (`TEETH`),
    each bulging back toward the floor by up to 0.3 m (`TOOTH_BULGE`). The scallops fade toward the bite's ends.
  - A bite that leaves one lane reaches, at its deepest, exactly the inner edge of the far side's outer lane: it takes
    2 of 3 lanes, 4 of 5 or 5 of 6 there (5.1 m, 9.9 m and 12.3 m deep), and fewer toward its front and back.
  - Its edge has the eaten-edge look: the orange lip and coping along the scalloped edge, the glowing strip and the
    broken face of the tower down to the water (fading into the sea haze with depth: "The trench's depth", below). The
    tower's side, eave and lanterns are gone along it.

  Collision follows the same polyline, so what looks like a hole is a hole. Is a 12 m bite the owner's size, and do
  the scallops read as teeth marks?
- **Phase 2's full-width bites** (GDD §10: "so big that sometimes the player has to jump over the gap"). Placeholder
  (`full_every` 2, `full_jump_share` 0.7, `full_through` 0.6): every other bitten roof of phase 2 from roof 4 on
  (roofs 4, 8, 12 and so on) has a bite that crosses the whole floor over 60% of its length.
  - At the bitten side its length is 70% of a normal jump at the run's speed: 8.4 m at 18 m/s, 11.1 m at 23.8 m/s. That
    matches a level's wider gaps (0.7 of a jump); a level may ask at most 0.8.
  - Each lane's stretch is shortest on the far side: 6.3-8.4 m at 18 m/s and 8.3-11.1 m at 23.8 m/s, against jumps
    of 12.0 m and 15.9 m.
  - Its other bites leave one lane, as in phase 1.

  Is every other bite right, and is a jump of 70% the right challenge?
- **Its warning** (every attack has a visual and an audio warning). Placeholder (`MechaGuppyFloorBite`, `floor_warning`
  1.8 s, `floor_rise` 0.5 s):
  - The visual: the crescent's outline on the floor in the enemy attacks' red, in the Golden Convergence's Fist Slam
    look: a glowing frame round a solid red fill. The frame deepens as the snap comes and beats a little, but holds
    steady with Reduced flashing. It counts as a floor warning on every lane it takes, so pickups keep off it.
  - The sound and the shark: its own warning sound (guppy_floor_warn, 1.4 s: three heavy knocks from under the deck,
    nearer each time, timbers groaning and splintering, steel teeth screeching up through the wood) as Mecha Guppy
    rises into its watch beside the roof's side on the bitten side, upright, its snout towering over the deck. Task
    E5e-f's review gave it its own sound: it used to share the rumble with the harmless bite of the roof behind and
    the fallback's breach.
  - The timing: it shows `floor_warning` before the runner reaches the bite. In practice that is 1.99 s, because it
    can't be shorter than Mecha Guppy's rise and lunge plus `floor_snap_lead` (1.54 s plus 0.45 s). It never shows
    before the deadline of the hut that led onto the roof, so it gives no cue to the lanes that lead up.
  - The margins, counted from where its warning can be read (task E5e-f's review): from a hut, and dropping off its
    end, the crescent on the roof ahead is a sliver a few pixels high, so the reaction starts where the runner can
    first switch on that roof (`Step.free_at`; never before the hut's deadline). From there the bite gives a reaction
    (0.35 s) and `WARN_SLACK` (0.15 s), every switch from the farthest lane to the one the bite leaves (0.14 s each),
    `dodge_margin` (0.25 s), half a hurtbox and the dash's reach (4.8 m: the climb's other margins hold a runner who
    dashes, and so does this one now). Its front now comes 1.24-1.73 s after the riders can first switch (it was
    0.69-0.96 s), and its end 1.62-2.24 s before the notch.
  - On real movement, in the worst case (moved into the farthest lane where the runner can first switch, reading the
    warning a reaction late from there), it has 0.40 s to spare at 3, 5 and 6 lanes and both speeds (`dodge_margin`
    and the slack): the bot's last switch is done 0.48-0.64 s before its hurtbox's front reaches the bite, or
    0.23-0.32 s before when it dashes as it starts across. Reading it as soon as it's on the roof's floor gives the
    same margins, within a frame.
  - A full-width bite warns the same way. The earliest take-off over it comes 0.64-1.11 s after a reaction counted
    from when the warning can be read, and the bot's jump clears its stretch by 0.085-0.100 s at either end.

  Is a red crescent the right warning, and are 2 s enough to read it?
- **The snap and a runner in the bite** (the brief's placeholder; FloorCut's and the Fist Slam's rule). Placeholder
  (`floor_snap_lead` 0.45 s, `MechaGuppyFloorBite.snap`):
  - The motion: Mecha Guppy dives under the deck, bursts up through it leaning in, its lower jaw flat across the
    crescent with its teeth through the deck and its tip 0.4 m short of the lane the bite leaves (no part of its jaws
    is ever over that lane), and snaps shut (guppy_bite, the crunch), dropping 10.5 m with the chunk.
  - The timing: the chunk is gone 0.45 s before the runner reaches the bite. A full-width bite is gone at least 1 m
    before the earliest take-off that clears it.
  - Contact: a runner in the bite's area as it snaps meets the jaws' hitboxes, an enemy attack. Armor and the shield
    block it, and the dash passes through it. The floor under a runner who lives through it holds for
    `cut_hold_seconds` (1 s), drawn as the deck with the orange lips round it, and then it goes. Anyone else dies of
    "Mecha Guppy's bite".
  - Because the snap comes before the runner gets there, nobody is in its area in normal play. The contact rule only
    meets a runner put there some other way.

  Should the snap come as the runner passes instead, catching whoever is still in the bitten lanes as the Fist Slam
  does? A runner who runs into the gap falls, and the grapple or a revive saves them.
- **Its side** (never a third cue). Placeholder (`MechaGuppyClimb._bite_side`):
  - Seeded by the roof's index, never three bites running on the same side, and with nothing to do with the lanes that
    lead up (the suite plans with other lanes leading up and finds the same bites).
  - A bitten roof's notch is on the bite's side, so the lane the bite leaves is never the notch's lane. This changes
    E5e-b3's notch side on those roofs, which was seeded by the roof alone.
  - After the bite, a baiting runner crosses from the lane it leaves to the notch's lane. The bait's aim shows only
    once the runner is past the bite, and it locks a reaction and a switch for every lane but one after that.
- **The fallback around a bitten roof**. Placeholder (`MechaGuppyPattern.bitten_next`): a fallback due on a step that
  leads onto a bitten roof waits for the next step, because Mecha Guppy can't breach in front of that roof and also
  rise for its bite. At the default `fallback_after` (1) the fallbacks never fall on those steps, so nothing changes.
  At other values a fallback sometimes comes a step later. This changes E5e-b3's "one every fallback_after + 1
  steps". A bitten roof also keeps its notch under the extreme tuning that leaves no other roof room for one. Right?
- **A save near a bite**. Placeholder (`MechaGuppyStairs.save_spot`, `save_crossing`):
  - A grapple save or a revive that would bring the runner down just before a bite that leaves a lane puts them in the
    lane the bite leaves when, from the lane it would bring them down in, they couldn't read the bite and cross: a
    reaction, every switch from there to the lane the bite leaves, `dodge_margin`, half a hurtbox and the dash's reach.
    (Task E5e-f's review: it used to count 1.5 times the crossing from the farthest lane, which, with the dash's reach
    counted and the bite further along, sent a save 25 m short of a bite into its lane instead of the nearest lane that
    leads up, one switch away from it.)
  - A runner who fell into an eaten bite is pulled up into the nearest lane with floor where they come down. In
    practice that is past the gap, in their own lane.
- **Pickups near a bite** (GDD §10's standard armor rule; task E5e-f's review). Placeholder
  (`MechaGuppyStairs.pickup_spot`, `clear_of_bite`): an armor pickup on a bitten roof never lies where the bite will
  take its lane, and in a lane the bite takes it lies far enough short of the gap that a runner who grabs it (2 m
  either side of it) still has every switch to the lane the bite leaves (none over a full-width bite: its jump) and
  `dodge_margin` before the gap reaches that lane; otherwise it comes past the bite. Before, one could land just
  short of the gap with switches still needed: a grab and an escape that couldn't both happen. Right?
- **The hut's end band** (E5e-b1's placeholder: the 4 m orange band where each run of lanes ends on a hut's
  underside, long and bright so it reads from the hut's start). Task E5e-f's review found it filling up to a quarter
  of the screen with bright orange as the chase camera passes just under it when the rider drops. Placeholder
  (`MechaGuppyLooks`, `END_BAND_*`): up close it is an orange lip at the very end (0.3 m, the decks' edge language)
  with a row of lamps; its 4 m length is a glow card, as bright as the old band, that fades out as the camera comes
  within 16 m. From afar it reads as before; at the drop only the lip shows (bright orange at most 3.8-5.0% of the
  screen there, against 17.4-26.5%). Dimming the band instead turned it red (the edge colour is redder than it looks
  and only reads orange when bright), a red slab overhead. Is that the right look?
- **The trench's depth** (task E5e-f's review). Placeholder (`MechaGuppyLooks._bite_deep`): a floor bite's broken face
  fades from the tower's dark timber into the sea haze the deeper it goes (most of the way 18 m down), so a full-width
  trench seen from over it reads as a drop, not a dark slab.
- **Its sounds**: the rise has its own warning sound, guppy_floor_warn (above; task E5e-f's review: one that means
  "this one can kill you", not the rumble of the harmless bite behind and the breach), and the snap reuses guppy_bite,
  its jaws' crunch. Is the knocking and the screech of teeth through the deck the right warning?
- **Bites skipped**: a bite that can't be warned fairly any more is skipped, as if it had never been planned. That
  happens in an intro (the attacks off), in phase 3 (`attacks_live`) or under an extreme tuning that keeps Mecha Guppy
  too busy. A phase change calls off a bite that is already warned but hasn't started its snap: its warning goes and
  nothing is bitten. One whose jaws are already snapping shut when the phase changes completes, the chunk going as
  warned (task E5e-f's review: called off then, its jaws shut on intact floor).
- **The par times' rule** (task E5e-f's brief): the brief describes three stars as about 1.2 times the slowest clean
  baiting fight. The suite's rule, kept here, is Hostile Takeover's margin (74/68.6, about 1.08 times) for three stars,
  with 1.2 times the room two stars must leave. The fight is a little longer (up to 4.6 s baiting at 18 m/s, up to 7.7 s
  not baiting), but the par times stay at 177 s, 210 s and the time bonus to 260 s, and they still meet the suite's
  rules: the slowest clean fight at 23.8 m/s is 161.9 s (three stars at 174.6 s by Hostile Takeover's margin, within
  3 s of 177 s), the slowest at 18 m/s 175.7 s (still three stars, by 1.3 s), and the quickest win without baiting
  226.1 s. Which rule is meant for three stars?
