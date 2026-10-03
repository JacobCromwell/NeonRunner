class_name HostileTakeoverContract
extends RefCounted
## Phase 2, The Contract (GDD §10: "the gunship strafes the lanes (a warning line and a rising whine) and
## drops a Buzz Overdrive onto the roof ahead, which cuts a carriage lane. An armored carriage with no roof
## access blocks the way, so the player takes an anti-grav pad and rides the gunship's belly over it (the
## gunship is the ceiling)"). While the phase's pattern runs (`active`) it plans, along the train ahead,
## one cycle after another:
## - the drop (plan_drop): on the next flatcar (HostileTakeoverTrain.Kind.FLATCAR) whose roof the built
##   track hasn't reached, a Buzz Overdrive's cut planned as a level's (FloorCutPlan at the run speed,
##   with the C2 tank's own rev, charge and run past, but no roll: the drop brings it into view), its lane
##   window on the flatcar's roof, in a seeded lane where LevelGenerator's rules for cuts allow it
##   (BossArena.cut_problem), added to the track (BossArena.add_pieces); the gunship flies out over its
##   spot, lets the tank it carries fall (drop_fall) so it lands drop_before seconds before its rev
##   starts, and the real tank comes into play there (BossEncounter.spawn_enemy: its rev and line, its
##   charge cutting the lane, the block-then-hold rule, all its own);
## - the ride (plan_ride): the second carriage past that flatcar is armored (HostileTakeoverArmored, shown
##   once it's within ARMORED_SIGHT, with its runway of pads in every lane on the carriage before it, longer
##   than any jump: strip_clears); the gunship
##   comes down over descend_seconds to the ceiling's height with its drop bay open (the weak point:
##   HostileTakeoverGunship.bay_point, live while the runner rides under it), its stern ride_rear_margin
##   behind the runner as they reach the pads, and flies on more slowly than the runner, so its nose
##   passes over them landing_after past the armored carriage's far gap, where they drop back onto the
##   roof (the floor there is whole and nothing else is going on); then it climbs back. Once a ride's
##   armored carriage is placed, the ride flies through, whatever the phase (so the carriage never stands
##   there without its ceiling); a drop or a ride not yet under way when the phase ends is dropped (its cut
##   stays on the track, never cut: no tank comes);
## - strafes, in between (_tick_strafe): when nothing else is going on (no drop or ride within
##   strafe_clear seconds, no phase-1 guard about, strafe_gap after the last one), a red line along the
##   runner's lane and the one beside it (struck_lanes) with the rising whine for strafe_warning seconds,
##   then the guns rake each line from its far end back past the runner (HostileTakeoverStrafes), always
##   leaving a free lane beside.
## Phase 3, The Merger (`merger`: GDD §10, "its attacks combine both"), plays the same drops and strafes
## from the war engine (the gunship docked onto the locomotive, HostileTakeover), and after each drop a pass
## instead of a ride (plan_pass): no armored carriage; the runway of pads on the carriage after the
## flatcar, the war engine coming back and down over the runner there, so they ride its belly forward under
## its three docking clamps (the phase's weak points, HostileTakeoverGunship.clamp_points: those not yet
## torn loose live while the runner rides), until it pulls away and they drop back onto a roof clear of the
## gaps. The Board's guards and wall fences come back in between (HostileTakeoverBoard.merger).
## It plans from the phase's start (its intro included: the first flatcar's drop, whose cut has to go
## onto the track before the built track reaches it; in phase 3 no drop moves out before `not_before`, the
## docking's end); the strafes wait for its pattern (is_vulnerable), and in phase 3 for the docking.
## Everything is keyed to the runner's distance (the gunship's pose: pose()) or to the physics clock (a
## strafe's warning and rake, a falling tank) and seeded from the fight, so every attempt plays the same.
## Numbers: HostileTakeoverTuning's Contract groups (DESIGN-TBD).

enum DropStage { PLANNED, FALLING, LANDED, DONE, CANCELLED }
enum RideStage { PLANNED, PLACED, DONE, CANCELLED }
enum StrafeStage { WARN, RAKE }

const SAW: String = "buzz_overdrive"
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
## A drop's lane window keeps this far from its flatcar's front end, and its warning this far from the
## flatcar's rear end (metres at 18 m/s).
const FLATCAR_FRONT: float = 4.0
const FLATCAR_REAR: float = 2.0
## Flatcars tried for a drop each time one is due (the nearest whose roof the built track hasn't reached).
const DROP_TRIES: int = 3
## The armored carriage stands in place once its roof's start is this far ahead of the runner (metres:
## out in the haze, HostileTakeoverSkin's fog), and is put away this far past its far end.
const ARMORED_SIGHT: float = 240.0
const RELEASE_AFTER: float = 20.0
## A strafe waits while one of phase 1's guards is alive from just behind the runner to this far past its
## line's far end (metres).
const GUARD_REACH: float = 30.0
## A strafe's runner-distance span: from its start to the runner's position this long after its warning
## (the rake has passed them by then).
const STRAFE_AFTER: float = 1.0

var boss: HostileTakeover
var tuning: HostileTakeoverTuning
var train: HostileTakeoverTrain
## The phase's pattern is running: it plans drops and rides and strafes.
var active: bool = false
## Phase 3's mode: passes under the docked war engine instead of rides (see the header).
var merger: bool = false
## No drop's move out starts before the runner is here (phase 3: the docking's end).
var not_before: float = -INF
## Planned drops and rides, in order (see plan_drop and plan_ride for their fields).
var drops: Array[Dictionary] = []
var rides: Array[Dictionary] = []
## The strafe on now ({} when none): {lanes, from, to, at (runner distance at its warning), t, stage,
## front, warnings}.
var strafe: Dictionary = {}
var strafes: int = 0
var refused_drops: int = 0

var _next_from: int = 1
var _rest: float = 0.0


func _init(p_boss: HostileTakeover) -> void:
	boss = p_boss
	tuning = boss.tuning
	train = boss.train


## The phase begins: the gunship carries a Buzz Overdrive, and the cycles start from the carriage after
## the runner's; with `p_merger`, phase 3's (passes, no drop before `p_not_before`).
func start(p_merger: bool = false, p_not_before: float = -INF) -> void:
	active = true
	merger = p_merger
	not_before = p_not_before
	_next_from = train.carriage_at(boss.player_distance()) + 1
	_rest = tuning.strafe_gap
	boss.gunship.set_saw(true)
	boss.log_event(&"contract", {"from": _next_from, "merger": merger})


## Phase 3 begins on from phase 2 (see the header): the drops phase 2 planned stay if the war engine can
## make them after its docking (no move out before `p_not_before`), each with a pass after it instead of
## its armored ride; the rest is dropped (a ride whose armored carriage stands flies on).
func merge(p_not_before: float) -> void:
	active = true
	merger = true
	not_before = p_not_before
	_rest = tuning.strafe_gap
	for ride: Dictionary in rides:
		if int(ride["stage"]) == RideStage.PLANNED:
			ride["stage"] = RideStage.CANCELLED
	for drop: Dictionary in drops:
		if int(drop["stage"]) != DropStage.PLANNED:
			continue
		if float(drop["release_p"]) - float(drop["move"]) < not_before:
			drop["stage"] = DropStage.CANCELLED
			continue
		var pass_ride: Dictionary = plan_pass(int(drop["k"]) + 1)
		if not pass_ride.is_empty():
			rides.append(pass_ride)
	_next_from = maxi(_next_from, train.carriage_at(boss.player_distance()) + 1)
	boss.gunship.set_saw(true)
	boss.log_event(&"contract", {"from": _next_from, "merger": true, "kept": drops.filter(func(x: Dictionary) -> bool:
		return int(x["stage"]) == DropStage.PLANNED).size()})


## The phase is over: what isn't under way is dropped (a ride whose armored carriage stands flies on).
func stop() -> void:
	active = false
	for drop: Dictionary in drops:
		if int(drop["stage"]) == DropStage.PLANNED:
			drop["stage"] = DropStage.CANCELLED
	for ride: Dictionary in rides:
		if int(ride["stage"]) == RideStage.PLANNED:
			ride["stage"] = RideStage.CANCELLED
	boss.gunship.set_saw(false)


## The fight is won: everything stops (the rakes, the bay); a falling tank lands.
func halt() -> void:
	stop()
	if not strafe.is_empty():
		_end_strafe()
	boss.gunship.set_weak_points_enabled(false)


func tick(delta: float) -> void:
	var d: float = boss.player_distance()
	if active:
		_plan()
	_tick_drops(delta, d)
	_tick_rides(d)
	_tick_strafe(delta, d)


# --- Planning ----------------------------------------------------------------------------------

## The next drop and its ride, once every planned drop is under way (the tank has landed).
func _plan() -> void:
	for drop: Dictionary in drops:
		if int(drop["stage"]) == DropStage.PLANNED or int(drop["stage"]) == DropStage.FALLING:
			return
	var k: int = train.next_flatcar(maxi(_next_from, train.carriage_at(boss.player_distance()) + 1))
	for i: int in DROP_TRIES:
		if k < 0:
			return
		var drop: Dictionary = plan_drop(k)
		if not drop.is_empty():
			drops.append(drop)
			var ride: Dictionary = plan_pass(k + 1) if merger else plan_ride(k + 2)
			if not ride.is_empty():
				rides.append(ride)
			_next_from = k + 1
			return
		k = train.next_flatcar(k + 1)


## A drop onto flatcar `k`: {k, lane, cut, warn_at, parked (where it lands: its blade's foot), land_p and
## release_p (where the runner is as it lands and as the gunship lets go), move (the gunship's move out
## and back, metres of the runner's), attack (FloorCutPlan.attack_window), stage, t, y0, saw}, its cut
## added to the track; or {} if no lane of its roof takes one where the built track hasn't reached.
func plan_drop(k: int) -> Dictionary:
	var arena: BossArena = boss.arena
	var v: float = arena.tuning.run_speed
	var pace: float = arena.tuning.pace()
	var t: BuzzOverdriveTuning = BuzzRules.tuning()
	var scaling: float = arena.config.enemy_scaling if arena.config != null else 0.0
	var charge: float = t.charge_distance(v, pace)
	var warn: float = charge + t.rev_at(scaling) * v
	var keep: float = t.keep()
	var roof: Vector2 = train.roof(k)
	var end: float = roof.y - FLATCAR_FRONT * pace - keep
	if end - warn < maxf(roof.x, 0.0) + FLATCAR_REAR * pace:
		boss.log_event(&"drop_refused", {"carriage": k, "why": "the flatcar is too short for its window"})
		refused_drops += 1
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(boss.def.id), "drop", k, boss.rng.seed])
	var order: Array[int] = []
	for lane: int in boss.lane_count():
		order.insert(rng.randi_range(0, order.size()), lane)
	var why: String = ""
	for lane: int in order:
		var cut: Dictionary = FloorCutPlan.make(lane, end, warn, charge, t.charge_speed_at(pace), v, t.run_past, keep)
		if float(cut["start"]) < arena.stream_from() + 0.5:
			why = "within the built track"
			break
		var problem: String = arena.cut_problem(cut)
		if problem != "":
			why = problem
			continue
		var release: float = FloorCutPlan.warn_at(cut) - (tuning.drop_before + tuning.drop_fall + tuning.drop_move) * v
		if release < not_before:
			why = "before the docking's end"
			break
		var pieces := LevelLayout.new()
		pieces.lane_count = boss.lane_count()
		pieces.cuts.append(cut)
		if arena.add_pieces(pieces) != 1:
			why = "not added"
			continue
		var warn_at: float = FloorCutPlan.warn_at(cut)
		var land_p: float = warn_at - tuning.drop_before * v
		var drop := {"k": k, "lane": lane, "cut": cut, "warn_at": warn_at, "parked": warn_at + charge, "land_p": land_p,
			"release_p": land_p - tuning.drop_fall * v, "move": tuning.drop_move * v,
			"attack": FloorCutPlan.attack_window(cut, v), "stage": DropStage.PLANNED, "t": 0.0, "y0": 0.0, "saw": null}
		boss.log_event(&"drop_planned", {"carriage": k, "lane": lane, "start": cut["start"], "end": cut["end"], "warn_at": warn_at})
		return drop
	boss.log_event(&"drop_refused", {"carriage": k, "why": why})
	refused_drops += 1
	return {}


## The ride over armored carriage `k` (the runway of pads on carriage k - 1, the landing on carriage
## k + 1): {k, roof, strip (the runway's stretch), pad_at (its near end), land_at, s (the gunship's speed
## along the track per metre of the runner's), descend_from, climb_to, stage, bay, boarded, landed,
## stomped}; or {} if those carriages aren't corporate ones.
func plan_ride(k: int) -> Dictionary:
	for i: int in [-1, 0, 1]:
		if train.kind(k + i) != HostileTakeoverTrain.Kind.CORPORATE:
			return {}
	var movement: MovementTuning = boss.arena.tuning
	var v: float = movement.run_speed
	var pace: float = movement.pace()
	var far: float = train.gap_start(k - 1) - tuning.pad_before * pace
	var strip := Vector2(maxf(far - tuning.pad_strip * pace, train.roof(k - 1).x + 1.0), far)
	var pad_at: float = strip.x
	var land_at: float = train.gap_end(k) + tuning.landing_after * pace
	var belly: float = HostileTakeoverModel.BELLY_FRONT + HostileTakeoverModel.BELLY_STERN
	var span: float = land_at - pad_at
	var s: float = clampf(1.0 - (belly - tuning.ride_rear_margin) / maxf(span, 1.0), 0.2, 0.98)
	var ride := {"k": k, "roof": train.roof(k), "strip": strip, "pad_at": pad_at, "land_at": land_at, "s": s,
		"descend_from": pad_at - tuning.descend_seconds * v, "climb_to": land_at + tuning.climb_seconds * v,
		"stage": RideStage.PLANNED, "bay": false, "boarded": false, "landed": false, "stomped": false, "pass": false}
	boss.log_event(&"ride_planned", {"carriage": k, "pad_at": pad_at, "land_at": land_at})
	return ride


## Phase 3's pass with its runway on carriage `k` (corporate, the one after a flatcar): {k, roof (the
## runway's carriage's), strip, pad_at (the runway's near end), pull_at (where the war engine pulls away),
## land_at (where its stern passes over the runner: they drop), descend_from, climb_to, stage, bay (begun),
## boarded, landed, stomps (clamps torn loose in it), pass: true}; or {} if carriage k isn't corporate.
## The runway lies on carriage k's roof, its far end at least pad_before short of its gap, where the runner
## drops back onto a roof (pass_landing) as far from any gap as it can.
func plan_pass(k: int) -> Dictionary:
	if train.kind(k) != HostileTakeoverTrain.Kind.CORPORATE:
		return {}
	var movement: MovementTuning = boss.arena.tuning
	var v: float = movement.run_speed
	var pace: float = movement.pace()
	var length: float = boss.armored.strip_length()
	var roof: Vector2 = train.roof(k)
	var first: float = maxf(roof.x, 0.0) + 1.0
	var last: float = roof.y - tuning.pad_before * pace - length
	if last < first:
		return {}
	var ride_len: float = maxf(tuning.pass_release - tuning.pass_rear_margin, 0.5) * v / maxf(tuning.pass_speed, 0.1)
	var pull_len: float = tuning.pass_release * v / maxf(tuning.pull_speed, 0.1)
	var fall: float = _fall_length()
	# The runway's start whose landing lies farthest from any gap.
	var best: float = first
	var best_margin: float = -INF
	var at: float = first
	while at <= last + 0.001:
		var margin: float = _roof_margin(at + ride_len + pull_len + fall)
		if margin > best_margin + 0.01:
			best_margin = margin
			best = at
		at += 1.0
	var pad_at: float = best
	var pull_at: float = pad_at + ride_len
	var land_at: float = pull_at + pull_len
	var ride := {"k": k, "roof": roof, "strip": Vector2(pad_at, pad_at + length), "pad_at": pad_at, "pull_at": pull_at,
		"land_at": land_at, "s": 1.0 - tuning.pass_speed / maxf(v, 0.1),
		"descend_from": pad_at - tuning.pass_descend_seconds * v, "climb_to": land_at + tuning.climb_seconds * v,
		"stage": RideStage.PLANNED, "bay": false, "boarded": false, "landed": false, "stomped": false, "pass": true,
		"stomps": []}
	boss.log_event(&"pass_planned", {"carriage": k, "pad_at": pad_at, "pull_at": pull_at, "land_at": land_at,
		"landing_margin": best_margin})
	return ride


## How far track distance `d` is from the nearest gap's edge (negative inside a gap).
func _roof_margin(d: float) -> float:
	var k: int = train.next_gap(d)
	var gap := Vector2(train.gap_start(k), train.gap_end(k))
	if d >= gap.x:
		return -minf(d - gap.x, gap.y - d)
	var before: float = d - train.gap_end(k - 1) if k > 0 else INF
	return minf(gap.x - d, before)


## How far along the track a runner travels falling from the ceiling's height to the roof.
func _fall_length() -> float:
	var m: MovementTuning = boss.world.tuning
	return sqrt(2.0 * m.ceiling_height / maxf(m.gravity() * m.fall_gravity_multiplier, 0.01)) * m.run_speed


## Where the runner at track distance `d` is along the docked war engine's belly during pass `ride`
## (metres from its stern): pass_rear_margin at the runway's start, moving forward at pass_speed until
## pass_release, then back as it pulls away (at pull_speed) until its stern passes them (0) and on.
func pass_u(ride: Dictionary, d: float) -> float:
	var v: float = maxf(boss.arena.tuning.run_speed, 0.1)
	var pull_at: float = float(ride["pull_at"])
	if d <= pull_at:
		return tuning.pass_rear_margin + (d - float(ride["pad_at"])) * tuning.pass_speed / v
	return tuning.pass_release - (d - pull_at) * tuning.pull_speed / v


# --- Drops ---------------------------------------------------------------------------------------

func _tick_drops(delta: float, d: float) -> void:
	for drop: Dictionary in drops:
		match int(drop["stage"]):
			DropStage.PLANNED:
				if not drop.has("circle") and d >= float(drop["release_p"]) - float(drop["move"]):
					# Where it will land: a red target on the roof in its lane (BossProps' circle) as the gunship
					# flies out over it.
					drop["circle"] = boss.props.circle_warning(float(drop["parked"]) + 1.5, int(drop["lane"]), 1.6)
					boss.log_event(&"drop_marked", {"lane": drop["lane"], "parked": drop["parked"]})
				if d >= float(drop["release_p"]):
					drop["stage"] = DropStage.FALLING
					drop["t"] = 0.0
					var from: Vector3 = boss.gunship.saw_world()
					drop["y0"] = maxf(from.y, 0.5)
					drop["x0"] = from.x
					boss.gunship.set_saw(false)
					boss.gunship.set_fall(Vector3(boss.world.geo.lane_x(int(drop["lane"])), float(drop["y0"]),
						TrackGeometry.world_z(float(drop["parked"]))))
					boss.log_event(&"saw_released", {"lane": drop["lane"], "parked": drop["parked"]})
			DropStage.FALLING:
				drop["t"] = float(drop["t"]) + delta
				var k: float = clampf(float(drop["t"]) / maxf(tuning.drop_fall, 0.05), 0.0, 1.0)
				var lane_x: float = boss.world.geo.lane_x(int(drop["lane"]))
				var at := Vector3(lerpf(float(drop.get("x0", lane_x)), lane_x, smoothstep(0.0, 1.0, k)),
					float(drop["y0"]) * (1.0 - k * k), TrackGeometry.world_z(float(drop["parked"])))
				boss.gunship.set_fall(at)
				if k >= 1.0:
					_land(drop, at)
			DropStage.LANDED:
				if d > float((drop["attack"] as Vector2).y) + 5.0:
					drop["stage"] = DropStage.DONE


## The tank lands: the model is put away and the C2 tank comes into play on its spot.
func _land(drop: Dictionary, at: Vector3) -> void:
	drop["stage"] = DropStage.LANDED
	boss.gunship.end_fall()
	if drop.has("circle"):
		boss.props.remove(drop["circle"] as Node)
	var cut: Dictionary = drop["cut"]
	drop["saw"] = boss.spawn_enemy(SAW, float(cut["end"]), int(cut["lane"]))
	boss.sound(&"takeover_drop", at)
	boss.world.effects.burst(at + Vector3(0.0, 0.3, 0.0), HostileTakeoverModel.GUNMETAL_LIGHT, 24, 1.1)
	boss.world.effects.shake(0.3, 0.3)
	boss.log_event(&"saw_landed", {"lane": drop["lane"], "parked": drop["parked"], "runner": boss.player_distance()})


## The drop whose tank is about now (landed, its attack not yet passed), or {}.
func saw_now() -> Dictionary:
	var d: float = boss.player_distance()
	for drop: Dictionary in drops:
		var stage: int = int(drop["stage"])
		if (stage == DropStage.FALLING or stage == DropStage.LANDED) and d <= float((drop["attack"] as Vector2).y):
			return drop
	return {}


# --- Rides ---------------------------------------------------------------------------------------

func _tick_rides(d: float) -> void:
	var armored: HostileTakeoverArmored = boss.armored
	var player: Player = boss.world.player
	var live: bool = false
	for ride: Dictionary in rides:
		if ride["pass"]:
			live = _tick_pass(ride, d) or live
			continue
		match int(ride["stage"]):
			RideStage.PLANNED:
				if d >= (ride["roof"] as Vector2).x - ARMORED_SIGHT and not armored.in_use():
					armored.place(int(ride["k"]), ride["roof"], ride["strip"])
					ride["stage"] = RideStage.PLACED
					boss.log_event(&"ride_placed", {"carriage": ride["k"], "ahead": (ride["roof"] as Vector2).x - d})
			RideStage.PLACED:
				if not ride["bay"] and d >= float(ride["descend_from"]):
					ride["bay"] = true
					boss.ride_begins(ride)
				var on_ceiling: bool = player.surface == Player.Surface.CEILING
				if on_ceiling and not ride["boarded"] and d >= float(ride["pad_at"]) - 1.0:
					ride["boarded"] = true
					boss.log_event(&"ride_boarded", {"carriage": ride["k"], "lane": player.lane})
				if ride["bay"] and not ride["stomped"] and on_ceiling and boss.gunship.bay_open and boss.is_vulnerable() \
						and d >= float(ride["pad_at"]) and d <= float(ride["land_at"]):
					live = true
				if not ride["landed"] and d > float(ride["land_at"]) and not on_ceiling:
					ride["landed"] = true
					boss.ride_ends(ride)
				if ride["landed"] and d > float(ride["climb_to"]) and d > armored.span.y + RELEASE_AFTER:
					armored.release()
					ride["stage"] = RideStage.DONE
	boss.gunship.set_weak_points_enabled(live)


## One pass's step (see plan_pass): its runway set out within sight, the war engine coming back
## (HostileTakeover.pass_begins), the runner boarding, its clamps live while they ride its belly, their
## drop back onto the roof (HostileTakeover.pass_ends) and the runway put away behind them. True if the
## clamps are live now. Once the boss is beaten, the pass only waits to put its runway away.
func _tick_pass(ride: Dictionary, d: float) -> bool:
	var armored: HostileTakeoverArmored = boss.armored
	var player: Player = boss.world.player
	var strip: Vector2 = ride["strip"]
	match int(ride["stage"]):
		RideStage.PLANNED:
			if d >= strip.x - ARMORED_SIGHT and not armored.in_use():
				armored.place(int(ride["k"]), ride["roof"], strip, false)
				ride["stage"] = RideStage.PLACED
				boss.log_event(&"pass_placed", {"carriage": ride["k"], "ahead": strip.x - d})
		RideStage.PLACED:
			if boss.is_defeated():
				if d > strip.y + RELEASE_AFTER:
					armored.release()
					ride["stage"] = RideStage.DONE
				return false
			if not ride["bay"] and d >= float(ride["descend_from"]):
				ride["bay"] = true
				boss.pass_begins(ride)
			var on_ceiling: bool = player.surface == Player.Surface.CEILING
			if on_ceiling and not ride["boarded"] and d >= float(ride["pad_at"]) - 1.0:
				ride["boarded"] = true
				boss.log_event(&"pass_boarded", {"carriage": ride["k"], "lane": player.lane})
			var live: bool = on_ceiling and boss.is_vulnerable() and d >= float(ride["pad_at"]) and d <= float(ride["land_at"])
			if not ride["landed"] and d > float(ride["land_at"]) and not on_ceiling:
				ride["landed"] = true
				boss.pass_ends(ride)
			if ride["landed"] and d > float(ride["climb_to"]) and d > strip.y + RELEASE_AFTER:
				armored.release()
				ride["stage"] = RideStage.DONE
			return live
	return false


## The ride on now (placed, the runner between where the gunship starts down and where it has climbed
## back), or {}.
func ride_now() -> Dictionary:
	var d: float = boss.player_distance()
	for ride: Dictionary in rides:
		if int(ride["stage"]) == RideStage.PLACED and d >= float(ride["descend_from"]) - 1.0 and d <= float(ride["climb_to"]):
			return ride
	return {}


## The next ride ahead (placed or planned), or {}.
func next_ride() -> Dictionary:
	var d: float = boss.player_distance()
	for ride: Dictionary in rides:
		var stage: int = int(ride["stage"])
		if (stage == RideStage.PLANNED or stage == RideStage.PLACED) and d <= float(ride["climb_to"]):
			return ride
	return {}


## The track `ride` keeps to itself: from its runway's start to where the runner, dropping off the belly
## at its landing point, is back on the roof (track distances). No pickup goes there (HostileTakeover).
func ride_stretch(ride: Dictionary) -> Vector2:
	var m: MovementTuning = boss.world.tuning
	var fall: float = sqrt(2.0 * m.ceiling_height / maxf(m.gravity() * m.fall_gravity_multiplier, 0.01)) * m.run_speed
	return Vector2(float(ride["pad_at"]), float(ride["land_at"]) + fall)


## How fast the runner moves along the gunship's belly during `ride` (m/s at the run speed).
func relative_speed(ride: Dictionary) -> float:
	return boss.arena.tuning.run_speed * (1.0 - float(ride["s"]))


## The longest a runner can be in the air over the roof at `movement`'s run speed: a full jump with a dash
## (PowerupTuning) through the whole of it. A runway of pads longer than this can't be jumped over.
static func longest_leap(movement: MovementTuning) -> float:
	var powerups := load("res://data/tuning/powerups.tres") as PowerupTuning
	var bonus: float = powerups.dash_speed_bonus if powerups != null else 0.0
	var air: float = movement.jump_distance(movement.run_speed) / maxf(movement.run_speed, 0.01)
	return movement.jump_distance(movement.run_speed) + bonus * minf(air, powerups.dash_duration if powerups != null else 0.0)


## True if a runway `length` long clears `movement`'s longest leap with `margin` to spare: no runner on
## the roof gets past it without touching a pad.
static func strip_clears(movement: MovementTuning, length: float, margin: float = 1.0) -> bool:
	return length >= longest_leap(movement) + margin


## How far short of the bay's middle (along the belly) a jump from the belly has to leave to come back
## up onto it: its time to fall back to the bay's hanging depth, at the ride's relative speed.
func bay_lead(ride: Dictionary) -> float:
	return relative_speed(ride) * up_time(tuning.bay_depth)


## How far short of a clamp's middle (along the belly, metres) a jump from it has to leave during a pass to
## come back up onto the clamp: its time to fall back to the clamp's hanging depth, at pass_speed
## (HostileTakeoverGunship.clamp_lead).
func clamp_lead() -> float:
	return boss.gunship.clamp_lead()


## How long a jump from the ceiling takes to come back up to `depth` under it.
func up_time(depth: float) -> float:
	return up_time_for(boss.world.tuning, depth)


## How long a jump from the ceiling takes to come back up to `depth` under it, with `m`'s jump.
static func up_time_for(m: MovementTuning, depth: float) -> float:
	var g_down: float = m.gravity() * m.fall_gravity_multiplier
	return m.jump_time_to_apex + sqrt(2.0 * maxf(m.jump_height - depth, 0.0) / g_down)


# --- Strafes -------------------------------------------------------------------------------------

func _tick_strafe(delta: float, d: float) -> void:
	if strafe.is_empty():
		_rest += delta
		if active and boss.is_vulnerable() and (not merger or boss.docked) and _rest >= tuning.strafe_gap and strafe_fits(d):
			_start_strafe(d)
		return
	strafe["t"] = float(strafe["t"]) + delta
	var t: float = float(strafe["t"])
	if int(strafe["stage"]) == StrafeStage.WARN:
		if t < tuning.strafe_warning:
			return
		strafe["stage"] = StrafeStage.RAKE
		var lanes: Array[int] = []
		lanes.assign(strafe["lanes"])
		boss.strafes.start(lanes)
		boss.gunship.set_firing(true)
		boss.sound(&"takeover_strafe", boss.gunship.gun_point())
		boss.log_event(&"strafe_rake", {"lanes": strafe["lanes"], "runner": d, "lane": boss.world.player.lane})
	var front: float = float(strafe["to"]) - tuning.rake_speed * boss.run_pace() * (t - tuning.strafe_warning)
	strafe["front"] = front
	boss.strafes.set_front(front, boss.gunship.gun_point())
	if front < float(strafe["from"]) - HostileTakeoverStrafes.DEPTH:
		_end_strafe()


func _end_strafe() -> void:
	boss.strafes.stop()
	boss.gunship.set_firing(false)
	for node: Variant in strafe.get("warnings", []):
		boss.props.remove(node as Node)
	boss.log_event(&"strafe_done", {"lanes": strafe.get("lanes", [])})
	strafe = {}
	_rest = 0.0


## True if a strafe may start with the runner at `d`: nothing else going on (no drop, tank or ride
## within strafe_clear seconds of its span, no phase-1 guard about, no floor cut along its line).
func strafe_fits(d: float) -> bool:
	var v: float = boss.arena.tuning.run_speed
	var pace: float = boss.run_pace()
	var clear: float = tuning.strafe_clear * v
	var span := Vector2(d - clear, d + (tuning.strafe_warning + STRAFE_AFTER) * v + clear)
	for drop: Dictionary in drops:
		var stage: int = int(drop["stage"])
		if stage == DropStage.DONE or stage == DropStage.CANCELLED:
			continue
		var busy := Vector2(float(drop["release_p"]) - float(drop["move"]), (drop["attack"] as Vector2).y)
		if busy.x <= span.y and busy.y >= span.x:
			return false
	for ride: Dictionary in rides:
		var stage: int = int(ride["stage"])
		if stage == RideStage.DONE or stage == RideStage.CANCELLED:
			continue
		if float(ride["descend_from"]) <= span.y and float(ride["climb_to"]) >= span.x:
			return false
	var to: float = d + tuning.strafe_length * pace
	for e: Enemy in boss.world.director.active:
		if not is_instance_valid(e) or not e.alive:
			continue
		if e is Cyborg or e.type_id == &"buzz_overdrive":
			var at: float = e.track_distance()
			if at >= d - 5.0 and at <= to + GUARD_REACH:
				return false
	if _cut_near(d - tuning.strafe_behind * pace, to):
		return false
	return true


func _cut_near(from: float, to: float) -> bool:
	for c: Dictionary in boss.arena.layout.cuts:
		if float(c["start"]) <= to and float(c["end"]) >= from:
			return true
	return false


## Starts a strafe with the runner at `d`: their lane and (with room) the ones beside it, seeded.
## (Phase 3: not before the war engine has docked, HostileTakeover.docked.)
func _start_strafe(d: float) -> void:
	var lanes: int = boss.lane_count()
	var n: int = tuning.struck_lanes(lanes)
	var pace: float = boss.run_pace()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(boss.def.id), "strafe", strafes, boss.rng.seed])
	var me: int = clampi(boss.world.player.lane, 0, lanes - 1)
	var struck: Array[int] = [me]
	while struck.size() < n:
		var options: Array[int] = []
		var lo: int = struck.min() - 1
		var hi: int = struck.max() + 1
		if lo >= 0:
			options.append(lo)
		if hi < lanes:
			options.append(hi)
		if options.is_empty():
			break
		struck.append(options[rng.randi() % options.size()])
	struck.sort()
	var from: float = d - tuning.strafe_behind * pace
	var to: float = d + tuning.strafe_length * pace
	var warnings: Array = []
	for lane: int in struck:
		warnings.append(boss.props.lane_warning(lane, from, to))
	strafe = {"lanes": struck, "from": from, "to": to, "at": d, "t": 0.0, "stage": StrafeStage.WARN, "front": to,
		"warnings": warnings}
	strafes += 1
	boss.sound(&"takeover_whine", boss.gunship.gun_point())
	boss.hint("strafe")
	boss.log_event(&"strafe_warned", {"lanes": struck, "from": from, "to": to, "runner": d, "lane": me})


## The lanes a strafe on now threatens until its rake has passed the runner (the bot's dodge).
func struck_now() -> Array[int]:
	var out: Array[int] = []
	if strafe.is_empty():
		return out
	if int(strafe["stage"]) == StrafeStage.RAKE and float(strafe["front"]) < boss.player_distance() - 2.0:
		return out
	out.assign(strafe["lanes"])
	return out


# --- The gunship's flight ------------------------------------------------------------------------

## The gunship's pose for the runner at `d`, from its pose at its station (`station`: {middle (track
## distance), y, x, roll, pitch}): a ride's or a pass's descent, ride and climb first, then a drop's move
## out and back, then a strafe's bank toward its lines (not docked: the war engine keeps to the line).
func pose(station: Dictionary, d: float) -> Dictionary:
	for ride: Dictionary in rides:
		if int(ride["stage"]) == RideStage.PLACED and d >= float(ride["descend_from"]) and d <= float(ride["climb_to"]):
			return _pass_pose(ride, station, d) if ride["pass"] else _ride_pose(ride, station, d)
	for drop: Dictionary in drops:
		var stage: int = int(drop["stage"])
		if stage == DropStage.DONE or stage == DropStage.CANCELLED:
			continue
		var move: float = maxf(float(drop["move"]), 0.1)
		if absf(d - float(drop["release_p"])) < move:
			return _drop_pose(drop, station, d, move)
	if not strafe.is_empty() and not boss.docked:
		var out: Dictionary = station.duplicate()
		var lanes: Array = strafe["lanes"]
		var mid: float = 0.0
		for lane: Variant in lanes:
			mid += boss.world.geo.lane_x(int(lane))
		mid /= maxf(lanes.size(), 1.0)
		var e: float = clampf(float(strafe["t"]) / 0.5, 0.0, 1.0)
		out["roll"] = float(station["roll"]) - signf(mid) * 0.14 * e
		out["x"] = lerpf(float(station["x"]), mid * 0.5, e)
		out["y"] = float(station["y"]) - 1.2 * e
		out["pitch"] = float(station["pitch"]) - 0.05 * e
		return out
	return station


## The belly's front, as the ride flies it: over the runner at the landing point, moving `s` metres for
## each of theirs.
func belly_front(ride: Dictionary, d: float) -> float:
	var land: float = float(ride["land_at"])
	return land - float(ride["s"]) * (land - d)


func _ride_pose(ride: Dictionary, station: Dictionary, d: float) -> Dictionary:
	var h: float = boss.world.tuning.ceiling_height
	var middle: float = belly_front(ride, d) - HostileTakeoverModel.BELLY_FRONT
	var pad_at: float = float(ride["pad_at"])
	var land_at: float = float(ride["land_at"])
	var e: float = 1.0
	if d < pad_at:
		e = smoothstep(0.0, 1.0, (d - float(ride["descend_from"])) / maxf(pad_at - float(ride["descend_from"]), 0.1))
	elif d > land_at:
		e = 1.0 - smoothstep(0.0, 1.0, (d - land_at) / maxf(float(ride["climb_to"]) - land_at, 0.1))
	if e >= 1.0:
		return {"middle": middle, "y": h, "x": 0.0, "roll": 0.0, "pitch": 0.0}
	return {"middle": lerpf(float(station["middle"]), middle, e), "y": lerpf(float(station["y"]), h, e),
		"x": lerpf(float(station["x"]), 0.0, e), "roll": lerpf(float(station["roll"]), 0.0, e),
		"pitch": lerpf(float(station["pitch"]), 0.0, e)}


func _drop_pose(drop: Dictionary, station: Dictionary, d: float, move: float) -> Dictionary:
	var e: float = smoothstep(0.0, 1.0, 1.0 - absf(d - float(drop["release_p"])) / move)
	var middle: float = float(drop["parked"]) - HostileTakeoverModel.BAY_AHEAD + (d - float(drop["release_p"]))
	if boss.docked:
		# The war engine moves out along the line to let it fall from its bay, at its own height.
		return {"middle": lerpf(float(station["middle"]), middle, e), "y": float(station["y"]), "x": float(station["x"]),
			"roll": float(station["roll"]), "pitch": float(station["pitch"])}
	return {"middle": lerpf(float(station["middle"]), middle, e),
		"y": lerpf(float(station["y"]), tuning.drop_height, e),
		"x": lerpf(float(station["x"]), boss.world.geo.lane_x(int(drop["lane"])), e),
		"roll": lerpf(float(station["roll"]), 0.0, e), "pitch": lerpf(float(station["pitch"]), -0.04, e)}


## The docked war engine's pose during pass `ride`: coming back and down from its station over the runway's
## run-up, its belly the ceiling over the runner (pass_u: its stern pass_u behind them) along the pass,
## then pulling away and back up to its station.
func _pass_pose(ride: Dictionary, station: Dictionary, d: float) -> Dictionary:
	var h: float = boss.world.tuning.ceiling_height
	var middle: float = d - pass_u(ride, d) + HostileTakeoverModel.BELLY_STERN
	var pad_at: float = float(ride["pad_at"])
	var land_at: float = float(ride["land_at"])
	var e: float = 1.0
	if d < pad_at:
		e = smoothstep(0.0, 1.0, (d - float(ride["descend_from"])) / maxf(pad_at - float(ride["descend_from"]), 0.1))
	elif d > land_at:
		e = 1.0 - smoothstep(0.0, 1.0, (d - land_at) / maxf(float(ride["climb_to"]) - land_at, 0.1))
	if e >= 1.0:
		return {"middle": middle, "y": h, "x": 0.0, "roll": 0.0, "pitch": 0.0}
	return {"middle": lerpf(float(station["middle"]), middle, e), "y": lerpf(float(station["y"]), h, e),
		"x": lerpf(float(station["x"]), 0.0, e), "roll": lerpf(float(station["roll"]), 0.0, e),
		"pitch": lerpf(float(station["pitch"]), 0.0, e)}


## True while a ride's gunship is low over the runner (the encounter keeps its lurch off it).
func riding(d: float) -> bool:
	var ride: Dictionary = ride_now()
	return not ride.is_empty() and d >= float(ride["descend_from"])
