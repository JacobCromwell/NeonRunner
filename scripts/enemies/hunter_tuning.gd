class_name HunterTuning
extends EnemyTuning
## The Hunter's numbers (GDD §9.17, owner, October 23, 2026; data/enemies/hunter.tres; F6 "Enemy: hunter"). The owner
## decided: a fast lab creation on a hover disc that comes up alongside the runner and slashes rapidly at them, staying at
## their side; it doesn't wait for the other big enemies; 25 laser hits (`health_*`, below); a falling gantryway the
## runner drops on it is the way to beat it; it follows about as long as the Enforcer Truck (25 s), and it hovers, so it
## never falls into a gap. Every other number is task S2's placeholder (DESIGN-TBD, docs/questions/s2.md). Seconds stay the
## same at every zone's speed (it moves in the runner's frame, as the Enforcer Truck does: docs/ARCHITECTURE.md, Pace);
## its gaps beside and behind the runner are plain metres (the camera's view doesn't change with the speed).
## Its health is in laser tier 1 shots (GDD §8): 23, which laser tier 1 stretches by PowerupTuning.tier1_extra_shots to the
## owner's 25 hits; the higher tiers and the missiles take 23 / their damage (17, 12 and 8 shots), the proportion every
## other enemy keeps.

@export_group("Chase")
## GDD §9.17: it follows the runner about as long as the Enforcer Truck does (§9.13: about 25 s), counted from its arrival,
## whatever happens meanwhile (a teleport, a ceiling, a wait behind the runner), then gives up.
@export_range(5.0, 60.0, 0.5, "suffix:s") var chase_seconds: float = 25.0
## DESIGN-TBD: where it comes in from behind as it arrives (its middle's gap behind the runner, plain metres), and how fast
## it closes in (metres a second faster than the runner, at most; it eases in over the last few metres, gap_rate).
@export_range(10.0, 80.0, 1.0, "suffix:m") var arrive_gap: float = 30.0
@export_range(2.0, 30.0, 0.5, "suffix:m/s") var approach_speed: float = 14.0
## How fast its gap eases toward the one it wants (per second).
@export_range(1.0, 20.0, 0.5) var gap_rate: float = 6.0
## DESIGN-TBD: alongside, its middle this far ahead of the runner's (metres): its front a little ahead of them, so the chase
## camera shows all of it, its torso turned back toward them.
@export_range(-1.0, 2.0, 0.05, "suffix:m") var alongside_ahead: float = 0.6
## DESIGN-TBD: a teleport leaves it behind (GDD §9.17, proposed): it catches up from where the jump left it, but from no
## further back than this (metres behind the runner's landing).
@export_range(20.0, 150.0, 1.0, "suffix:m") var catch_up_gap_max: float = 70.0
## DESIGN-TBD: as it gives up it drops back this fast (metres a second slower than the runner), its whine falling, and is
## gone this far behind.
@export_range(1.0, 30.0, 0.5, "suffix:m/s") var leave_speed: float = 9.0
@export_range(15.0, 120.0, 1.0, "suffix:m") var gone_gap: float = 40.0

@export_group("Lanes")
## DESIGN-TBD (GDD §9.17, proposed: "when the runner steps away it follows into the lane they left, a moment later"): it
## takes the lane beside the runner on its side this long after they change lanes (a log on the level clock, as the
## Enforcer Truck's 0.8 s), so a runner who steps away from it under a falling gantryway leaves it in the walkway's lane.
@export_range(0.05, 1.0, 0.01, "suffix:s") var follow_delay_seconds: float = 0.25
## DESIGN-TBD: how long its own lane change takes (the runner's takes 0.14 s).
@export_range(0.1, 1.0, 0.01, "suffix:s") var switch_seconds: float = 0.25
## DESIGN-TBD (task S2's review: whenever the runner steps out from under a falling walkway and lives, it's under the
## walkway as it lands): a runner who steps out of a lane a falling walkway is coming down on, it follows into that lane at
## once (no follow_delay_seconds), its lane change this quick.
@export_range(0.05, 0.5, 0.01, "suffix:s") var walkway_switch_seconds: float = 0.12
## DESIGN-TBD: how far ahead it looks in its lane for what it must go round (a doodad, a gantryway's pillar, a gapped
## fence, a teleporter's pad and antenna, a ramp, a standing dash wall, another enemy on the floor): seconds of run past
## its front.
@export_range(0.2, 2.0, 0.05, "suffix:s") var steer_ahead_seconds: float = 0.6
## DESIGN-TBD (task S2's review: more of its chase beside the runner): a hover disc, it rises over a full fence in its lane
## (one the runner jumps) rather than going round it, its disc's underside this far over the fence's top, climbing and
## settling back at lift_speed (metres a second). It goes round a gapped fence (the runner slides under it), and every
## fence beside a runner in an edge lane: risen there it would hide their lane ahead from the camera.
@export_range(0.05, 1.0, 0.05, "suffix:m") var fence_clearance: float = 0.25
@export_range(2.0, 15.0, 0.5, "suffix:m/s") var lift_speed: float = 8.0
## DESIGN-TBD (task S2's review): its lane shut ahead by something it can't rise over, with no lane further out, it crosses
## to the runner's other side rather than making room: it drops back behind them, crosses their lane at least this far
## behind them (its middle's gap, metres), and comes up beside them there.
@export_range(2.6, 6.0, 0.1, "suffix:m") var cross_gap: float = 3.2
## DESIGN-TBD: it never takes the runner's only way out (CLAUDE.md: the player dies in one hit): it makes room (drops back
## behind them) when their lane holds what they must leave it for within this many seconds of run (a doodad, a floor enemy,
## a walkway falling over it, another enemy's lane attack, a wall-run gap) and the lane on their other side isn't open.
@export_range(0.3, 3.0, 0.05, "suffix:s") var make_room_seconds: float = 1.2
## DESIGN-TBD: once it has made room (dropped back), it comes up beside the runner again no sooner than this.
@export_range(0.0, 6.0, 0.1, "suffix:s") var regain_seconds: float = 1.2
## DESIGN-TBD: where it waits while it makes room (its middle's gap behind the runner: behind the chase camera), and how
## fast it drops back there (metres a second slower than the runner, at most).
@export_range(4.0, 30.0, 0.5, "suffix:m") var yield_gap: float = 9.0
@export_range(2.0, 40.0, 0.5, "suffix:m/s") var drop_speed: float = 16.0

@export_group("Slashes")
## GDD §9.17 (proposed): each flurry is warned (both blades raised, a steel scrape, a red mark on the runner's lane), then
## its blades cut into the runner's lane flurry_seconds, `cuts` quick cuts; one flurry is one hit (armor or the shield
## takes the first contact and the invulnerability window, GameRules.hit_invulnerability, 1 s, covers the rest).
@export_range(0.4, 2.0, 0.05, "suffix:s") var warning_seconds: float = 0.85
@export_range(0.15, 0.9, 0.05, "suffix:s") var flurry_seconds: float = 0.5
@export_range(1, 8) var cuts: int = 4
## Seconds its blades take to come back down after a flurry.
@export_range(0.1, 1.5, 0.05, "suffix:s") var recover_seconds: float = 0.4
## DESIGN-TBD (GDD §9.17, the owner: "slashing rapidly"): its first flurry's warning starts this long after it has come up
## beside the runner, and each later one a seeded interval from the last one's warning.
@export_range(0.3, 6.0, 0.1, "suffix:s") var first_slash_seconds: float = 1.0
@export_range(1.0, 8.0, 0.1, "suffix:s") var slash_interval_min: float = 1.8
@export_range(1.0, 8.0, 0.1, "suffix:s") var slash_interval_max: float = 2.3
## A flurry starts only when the lane on the runner's other side is open to step into (no hole, fence, doodad, floor cut,
## floor enemy or solid side) from this many seconds of run after its warning starts until its last cut.
@export_range(0.0, 1.0, 0.05, "suffix:s") var escape_reaction_seconds: float = 0.3
## The cuts' reach in the runner's lane: from the floor to this high (over a whole jump, under any ceiling rider), and this
## long along the track around the runner, side_margin in from each edge of the lane (a runner one lane away is clear).
@export_range(2.0, 3.2, 0.05, "suffix:m") var slash_height: float = 3.0
@export_range(0.8, 4.0, 0.1, "suffix:m") var slash_depth: float = 2.2
@export_range(0.05, 0.6, 0.01, "suffix:m") var side_margin: float = 0.25
## DESIGN-TBD: no flurry from this many seconds of run before a standing gantryway's pillar (in any lane) until its calm
## stretch is over: the runner lines up the bait and steps out under no cuts.
@export_range(0.0, 6.0, 0.1, "suffix:s") var bait_hold_seconds: float = 2.5
## DESIGN-TBD (task S2's review, its default): riding between the runner and its bait's walkway lane two lanes or more off
## (a runner by the edge on the wrong side), it stays beside them, never slashing them further from that lane, until the
## pillar is this many seconds of run ahead; then it crosses to their other side or drops back, so they can cross to it.
@export_range(2.5, 12.0, 0.5, "suffix:s") var bait_cross_seconds: float = 5.0
## The red mark on the runner's lane during a warning: from this far behind them to this far ahead.
@export_range(0.0, 6.0, 0.1, "suffix:m") var mark_behind: float = 2.0
@export_range(2.0, 20.0, 0.5, "suffix:m") var mark_ahead: float = 6.0

@export_group("Body")
## Its body, metres: the solid side's height (a lane change into it is bumped back, as the hover truck's sides; over a
## whole jump, under any ceiling rider, whose body comes down to about 3.1 m mid-jump) and length along the track.
@export_range(2.0, 3.0, 0.05, "suffix:m") var blocker_height: float = 2.95
@export_range(1.0, 3.0, 0.05, "suffix:m") var blocker_length: float = 2.0
## Its body's harmless box over its disc (a dash passes through it, claws and stomps do nothing), a little smaller than its
## look. A falling gantryway's crush and the weapons see its chest and reach instead (Hunter.aim_point, hit_radius).
@export var hitbox_size: Vector3 = Vector3(1.2, 1.4, 1.3)
## How high its disc's underside hovers over the floor (it hovers over gaps and holes alike).
@export_range(0.2, 1.0, 0.01, "suffix:m") var hover_height: float = 0.38

@export_group("Weapons")
## GDD §9.17 (the owner): staying at the runner's side makes it "difficult for the player to damage it with dashes or with
## laser attacks". Auto-fire (the laser and the missiles alike: WeaponPowerup.pick_target) picks it only while its middle is
## at least this far ahead of the runner's (Hunter.targetable): never while it rides alongside (alongside_ahead), comes up
## from behind or drops back. A shot meant for something else still hits it on the way. Its health stays 25 laser tier 1
## shots (health_*).
@export_range(1.0, 20.0, 0.5, "suffix:m") var target_ahead: float = 3.0

@export_group("Placement")
## DESIGN-TBD: at most this many a level, never two at once (GDD §9.17, proposed), each chase's end (and its drop back)
## spacing_seconds from the next one's arrival.
@export_range(0, 4) var per_level_max: int = 2
@export_range(0.0, 30.0, 0.5, "suffix:s") var spacing_seconds: float = 6.0
## GDD §9.17 (proposed): it comes in only where at least one falling gantryway comes during its chase. The gantryway's
## pillar comes at least bait_after_seconds after it arrives (it has come up beside the runner and shown its flurry) and at
## least bait_before_seconds before it would give up; where it can, at a seeded bait_prefer_min/max_seconds after.
@export_range(2.0, 20.0, 0.5, "suffix:s") var bait_after_seconds: float = 6.0
@export_range(1.0, 20.0, 0.5, "suffix:s") var bait_before_seconds: float = 4.0
@export_range(2.0, 20.0, 0.5, "suffix:s") var bait_prefer_min_seconds: float = 8.0
@export_range(2.0, 20.0, 0.5, "suffix:s") var bait_prefer_max_seconds: float = 14.0
## DESIGN-TBD: the lane it keeps beside the bait's walkway lane (its Hunter lane, hunter_rules.gd), clear of what it would
## have to go round: from the pillar's lead (where the gantryway keeps the lanes beside it from: it's beside the runner as
## they reach the pillar) and this many seconds of run more, to this many past the pillar's front at the fastest a runner
## comes through one (a step out from under the walkway and its look ahead, steer_ahead_seconds: from there, its lane shut
## ahead, it takes the lane the runner left at once; within the gantryway's calm stretch).
@export_range(0.0, 3.0, 0.1, "suffix:s") var bait_lane_before_seconds: float = 0.0
@export_range(0.3, 1.5, 0.05, "suffix:s") var bait_lane_after_seconds: float = 0.9
## DESIGN-TBD (the orchestrator's brief: "a calm arrival"): the stretch of run from its arrival that no other attack is
## planned on and later passes leave calm (seconds at the run speed; in every lane, so the zone doodads keep off it too:
## 1.5 s leaves Specimen Vault room for all of its decoy jars, task Q5's count, where 3 s took one at five lanes).
@export_range(0.0, 8.0, 0.5, "suffix:s") var arrival_calm_seconds: float = 1.5
## DESIGN-TBD: where a level introduces it (gives the feature a start), the falling gantryway its first chase takes as its
## bait is hung this many seconds of run past the feature's start (GantrywayRules.wanted, hunter_rules.gd
## gantryway_wanted), so the first Hunter arrives about as the feature starts, with time to show a flurry before the bait
## where the runner's lane allows one (it never slashes them two lanes past the bait's walkway lane, Hunter.may_slash).
@export_range(6.0, 21.0, 0.5, "suffix:s") var intro_bait_min_seconds: float = 12.0
@export_range(6.0, 21.0, 0.5, "suffix:s") var intro_bait_max_seconds: float = 18.0


## Seconds of a flurry from its warning's start to its last cut.
func attack_seconds() -> float:
	return warning_seconds + flurry_seconds


## A seeded interval from one flurry's warning to the next (between slash_interval_min and slash_interval_max).
func slash_interval(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(minf(slash_interval_min, slash_interval_max), maxf(slash_interval_min, slash_interval_max))
