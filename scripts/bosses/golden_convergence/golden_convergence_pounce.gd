class_name GoldenConvergencePounce
extends GoldenConvergenceAttack
## The Magnate's Pounce and its bait (GDD §10, proposed; task E5d-d): the beat kind `pounce`, `pounce:bait` with
## a Flying Buttress (GoldenConvergenceTuning.phase_beats).
## - The warning: "with a roar, his marker turns red" (magnate_roar from where he is behind the runner; the
##   chase's marker red) pounce_windup (over the phase's pace) before "he leaps from behind over the runner".
## - The leap (pounce_flight): high over the runner (pounce_apex), his landing lane following theirs until
##   lock_seconds before he lands ("about a second": never divided by the pace), when it locks onto the lane the
##   runner is in and "a red square marks where he'll land, ahead in that lane" (a floor warning: pickups keep
##   off it). He lands land_lead before the runner would get there: where they'd be.
## - The crash: an enemy attack over the square (crash_width_share of the lane, up to crash_height, above a
##   jump's reach: GoldenConvergenceMagnate.set_crash), live from his landing until the runner is past the square
##   (he crouches there: at least crash_min, at most crash_max); armor and the shield block it, the dash passes.
##   "Dodge: leave the lane." Then "he bounds off onto a balustrade" (the side away from the runner) and the
##   chase drops him back behind them.
## - The bait (`pounce:bait`): "a Flying Buttress comes up ahead for every second Pounce" (an inner lane, by the
##   fight's seed) bait_sight before the runner reaches it, and his landing is timed so that, "locked onto the
##   buttress's lane", he aims for the gate instead and "crashes into the gate, too big to fit through"
##   (GoldenConvergenceButtress.smash) stun_lead before the runner reaches him; before the lock his leap heads
##   for the gate while the runner is in its lane. Locked onto another lane, it's a Pounce like any other.
## - The stun: "he slumps in its rubble across two lanes, his back to the runner, the red ports on his spine
##   glowing": the buttress's lane and its neighbour toward the middle (stun_lanes); a weak point over his back in
##   each (set_weak_box: generous, reaching stun_reach toward the runner at the run's pace, stun_stomp_top over his
##   back, a jump's height, never out of its reach: stomp_top), stomped by "jumping onto his back (from either
##   lane)" (BossEncounter's stomp: the phase ends, GoldenConvergence._on_weak_point_hit); "while stunned he's solid
##   but safe: switching into him bumps the runner" (set_blocker over his lanes from a lane switch's run before his
##   back; his body has no hitbox).
## - E5d-e, the owner's playtest (proposed: "the stomp easier to read: while he's stunned, green chevrons on the floor
##   show where to take off, and the stun leaves time to line up the jump (at least about 1.5 s from the stun to the
##   last takeoff)"): he crashes into the gate stun_lead_seconds() before the runner reaches his back (stun_lead, or
##   longer so that stun_takeoff is left from the stun to the last takeoff, last_takeoff_gap(), at any speed), and
##   while he lies stunned the green chevrons (GoldenConvergenceTakeoffMarks) mark where to take off in each of his
##   two lanes: the middle of takeoff_gaps(), the stretch a jump can come down on his back from.
## - The release: "if they haven't by the time they're nearly on him, he shakes free and leaps away (a miss)":
##   a runner on the floor within stun_release of his back (at the run speed; never while a jump from there could
##   still come down on his back: release_gap), or one past him, and he leaps up and away onto the balustrade at
##   once (before the runner can reach him), dropping back behind; the bait comes around again with the beat
##   script's loop (no escalation).
## Every timing is planned from the runner's distance when the beat starts, at the run speed: the same on every
## attempt. Its sounds go through GoldenConvergence.sound() (logged).

enum Stage { IDLE, GATE, ROAR, FLIGHT, CRASH, BOUND, STUN, SHAKE, RETURN }

## His slumped body's depth along the track (his back to the gate's rubble), how high his back is, and the gap
## to the gate's front.
const STUN_DEPTH: float = 2.0
const STUN_BACK_TOP: float = 1.2
const STUN_GATE_GAP: float = 0.25
## His slump: turned this far (radians) from facing down the track toward his second lane.
const STUN_YAW: float = 1.3
## How fast his leap's landing lane follows the runner's before the lock (m/s sideways), and its length (m/s).
const AIM_SIDE_SPEED: float = 9.0
const AIM_ALONG_SPEED: float = 45.0
## The shake free: how long, how high, how far ahead.
const SHAKE_SECONDS: float = 0.55
const SHAKE_HEIGHT: float = 3.6
const SHAKE_AHEAD: float = 4.0
## The bound off the square onto a balustrade: how high.
const BOUND_HEIGHT: float = 2.4
## The square's frame: its rim's width (metres).
const SQUARE_RIM: float = 0.16
## E5d polish (F6's stun_stomp_top could lift his weak points out of a jump's reach): their top stays at least this
## far under the highest a jump can stomp from (the jump's top plus the stomp tolerance), a moment of the jump's fall
## (stomp_top). DESIGN-TBD (docs/questions/e5d.md, E5d polish 7).
const STOMP_WINDOW: float = 0.25

var chase: GoldenConvergenceChase
var magnate: GoldenConvergenceMagnate
var stage: Stage = Stage.IDLE
var stage_time: float = 0.0
## Pounces so far, baits so far, stuns, misses, stomps (tests).
var pounces: int = 0
var baits: int = 0
var stuns: int = 0
var misses: int = 0
var stomps: int = 0
## The pounce under way: {bait, d0, v, t (seconds since its start), t_roar, t_leap, t_lock, t_land, from (his
## pose at the leap), lane (locked, -1 before), at (the square's middle), gate_lane, gate_at, stun_mid, stun_back,
## stun_lanes, taken, roared_at, locked_at, landed_at}.
var p: Dictionary = {}
var buttress: GoldenConvergenceButtress = null
## Its placement number when this Pounce raised it (GoldenConvergenceButtress.is_placement).
var buttress_places: int = -1

var _rng := RandomNumberGenerator.new()
var _square: MeshInstance3D = null
var _square_base: Transform3D
var _square_t: float = 0.0
var _aim_x: float = 0.0
var _aim_rel: float = 0.0
## The crash: when it started, the side he bounds to, his bound's start.
var _bound: Dictionary = {}
var _shake: Dictionary = {}
var _square_material: StandardMaterial3D
## E5d-e: the green chevrons where to take off for the stomp.
var takeoff_marks: GoldenConvergenceTakeoffMarks


func _init(p_boss: GoldenConvergence) -> void:
	super(p_boss, &"pounce")
	chase = boss.chase
	magnate = boss.magnate


func prewarm() -> void:
	_square_material = GreyboxMaterials.glow(BossProps.WARNING_COLOR, 2.6, 0.85)
	if takeoff_marks == null and boss.world != null:
		takeoff_marks = GoldenConvergenceTakeoffMarks.new()
		boss.add_child(takeoff_marks)
		takeoff_marks.setup(boss, takeoff_gaps())


func busy() -> bool:
	if stage == Stage.RETURN and chase.home():
		_set_stage(Stage.IDLE)
	return stage != Stage.IDLE


## A warning shows or the crash is live (pickups and the bot read it).
func warning_on() -> bool:
	return stage == Stage.ROAR or stage == Stage.FLIGHT or stage == Stage.CRASH


## True while he lies stunned (his weak points live).
func stunned() -> bool:
	return stage == Stage.STUN


## Starts a Pounce (`beat`'s argument "bait": with a Flying Buttress for the bait).
func start(beat: Dictionary) -> void:
	clear()
	pounces += 1
	var bait: bool = String(beat.get("arg", "")) == "bait"
	_rng.seed = hash([String(boss.def.id), "pounce", pounces, boss.rng.seed])
	var t: GoldenConvergenceTuning = boss.tuning
	var pace: float = boss.pace()
	var v: float = boss.speed_planned()
	var d0: float = boss.player_distance()
	var windup: float = t.pounce_windup / pace
	var flight: float = maxf(t.pounce_flight - t.lock_seconds, 0.1) / pace + t.lock_seconds
	p = {"bait": bait, "d0": d0, "v": v, "t": 0.0, "lane": -1, "taken": false, "flight": flight, "n": pounces}
	if bait:
		baits += 1
		var lanes: int = boss.lane_count()
		var gate_lane: int = _rng.randi_range(1, lanes - 2) if lanes > 2 else 0
		var gate_at: float = d0 + v * maxf(t.bait_sight, t.buttress_sight)
		buttress = boss.place_buttress(gate_lane, gate_at)
		buttress_places = buttress.places
		var stun_back: float = gate_at - t.pier_depth * 0.5 - STUN_GATE_GAP - STUN_DEPTH
		var second: int = clampi(gate_lane - buttress.lean, 0, lanes - 1)
		if second == gate_lane:
			second = gate_lane + 1 if gate_lane + 1 < lanes else gate_lane - 1
		p["gate_lane"] = gate_lane
		p["gate_at"] = gate_at
		p["stun_back"] = stun_back
		p["stun_mid"] = stun_back + STUN_DEPTH * 0.5
		p["stun_lanes"] = [mini(gate_lane, second), maxi(gate_lane, second)]
		p["t_land"] = (stun_back - d0) / v - stun_lead_seconds()
		p["t_leap"] = float(p["t_land"]) - flight
		p["t_roar"] = maxf(float(p["t_leap"]) - windup, 0.0)
		_set_stage(Stage.GATE)
		boss.log_event(&"bait_placed", {"n": pounces, "lane": gate_lane, "at": gate_at, "stun_lanes": p["stun_lanes"],
			"runner": d0, "stun_lead": stun_lead_seconds()})
	else:
		p["t_roar"] = 0.0
		p["t_leap"] = windup
		p["t_land"] = windup + flight
		_roar()
	p["t_lock"] = float(p["t_land"]) - t.lock_seconds
	boss.log_event(&"pounce_start", {"n": pounces, "bait": bait, "t_roar": p["t_roar"], "t_lock": p["t_lock"],
		"t_land": p["t_land"]})


## Where the runner will be `t` seconds into the pounce (planned at the run speed).
func planned(t: float) -> float:
	return float(p["d0"]) + float(p["v"]) * t


func tick(delta: float) -> void:
	if stage == Stage.IDLE or p.is_empty():
		return
	stage_time += delta
	p["t"] = float(p["t"]) + delta
	var t: float = float(p["t"])
	_pulse_square(delta)
	match stage:
		Stage.GATE:
			if t >= float(p["t_roar"]):
				_roar()
		Stage.ROAR:
			# Roaring behind the runner, keeping his place there until he leaps.
			magnate.play(&"roar")
			chase.place(Vector3(magnate.global_position.x, 0.0,
				TrackGeometry.world_z(boss.player_distance() - boss.tuning.chase_gap)), 0.0, delta)
			if t >= float(p["t_leap"]):
				_leap()
		Stage.FLIGHT:
			_tick_flight(delta, t)
		Stage.CRASH:
			_tick_crash(delta)
		Stage.BOUND:
			_tick_bound(delta)
		Stage.STUN:
			_tick_stun()
		Stage.SHAKE:
			_tick_shake(delta)


# --- The warning, the leap -------------------------------------------------------------------------------

func _roar() -> void:
	_set_stage(Stage.ROAR)
	p["roared_at"] = boss.fight_time()
	chase.drive(self)
	chase.alarm = 1.0
	magnate.play(&"roar")
	boss.sound(&"magnate_roar", boss.sound_point(magnate.head_point()))
	boss.hint("pounce")
	boss.log_event(&"pounce_roar", {"n": pounces, "runner": boss.player_distance(), "lane": boss.player_lane()})


func _leap() -> void:
	_set_stage(Stage.FLIGHT)
	var from: Vector3 = magnate.global_position
	p["from"] = from
	p["rel0"] = -from.z - planned(float(p["t"]))
	_aim_x = from.x
	_aim_rel = _end_rel(boss.player_lane())
	magnate.play(&"leap")
	boss.sound(&"magnate_leap", boss.sound_point(magnate.global_position))
	boss.log_event(&"pounce_leap", {"n": pounces, "runner": boss.player_distance()})


## Where (relative to the runner's planned place as he lands) he'd come down locked onto `lane`: the square's
## middle, or for the bait's lane his slumped body's middle before the gate.
func _end_rel(lane: int) -> float:
	var land: float = planned(float(p["t_land"]))
	if bool(p["bait"]) and lane == int(p["gate_lane"]):
		return float(p["stun_mid"]) - land
	return float(p["v"]) * boss.tuning.land_lead + boss.tuning.crash_depth * 0.5


func _tick_flight(delta: float, t: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	if int(p["lane"]) < 0 and t >= float(p["t_lock"]):
		_lock()
	var lane: int = int(p["lane"]) if int(p["lane"]) >= 0 else boss.player_lane()
	# Before the lock his aim follows the runner's lane (and the gate's spot while they're in its lane).
	var target_x: float = boss.world.geo.lane_x(lane)
	if bool(p.get("taken", false)):
		target_x = _stun_x()
	_aim_x = move_toward(_aim_x, target_x, AIM_SIDE_SPEED * delta * (3.0 if int(p["lane"]) >= 0 else 1.0))
	_aim_rel = move_toward(_aim_rel, _end_rel(lane), AIM_ALONG_SPEED * delta)
	var t0: float = float(p["t_leap"])
	var u: float = clampf((t - t0) / maxf(float(p["flight"]), 0.05), 0.0, 1.0)
	var from: Vector3 = p["from"]
	var ez: float = 1.0 - (1.0 - u) * (1.0 - u)
	var ex: float = u * u * (3.0 - 2.0 * u)
	var rel: float = lerpf(float(p["rel0"]), _aim_rel, ez)
	var y: float = lerpf(from.y, 0.0, u) + tu.pounce_apex * 4.0 * u * (1.0 - u)
	var x: float = lerpf(from.x, _aim_x, ex)
	var yaw: float = 0.0
	if bool(p.get("taken", false)):
		yaw = _stun_yaw() * clampf((u - 0.7) / 0.3, 0.0, 1.0)
	chase.place(Vector3(x, y, TrackGeometry.world_z(planned(t) + rel)), yaw, delta)
	magnate.play(&"leap")
	if u >= 1.0:
		if bool(p.get("taken", false)):
			_stun()
		else:
			_land()


## The lock: the lane the runner is in now; the red square where he'll land in it (the gate's spot, in the
## buttress's lane, for the bait).
func _lock() -> void:
	var lane: int = boss.player_lane()
	p["lane"] = lane
	p["locked_at"] = boss.fight_time()
	var taken: bool = bool(p["bait"]) and lane == int(p["gate_lane"])
	p["taken"] = taken
	var from: float
	var to: float
	if taken:
		from = float(p["stun_back"])
		to = float(p["stun_back"]) + STUN_DEPTH
	else:
		var at: float = planned(float(p["t_land"])) + float(p["v"]) * boss.tuning.land_lead + boss.tuning.crash_depth * 0.5
		p["at"] = at
		from = at - boss.tuning.crash_depth * 0.5
		to = at + boss.tuning.crash_depth * 0.5
	p["square"] = Vector2(from, to)
	_show_square(lane, from, to)
	boss.log_event(&"pounce_lock", {"n": pounces, "lane": lane, "from": from, "to": to, "taken": taken,
		"runner": boss.player_distance()})


# --- The crash, the bound ---------------------------------------------------------------------------------

func _land() -> void:
	_set_stage(Stage.CRASH)
	p["landed_at"] = boss.fight_time()
	chase.alarm = 0.0
	var lane: int = int(p["lane"])
	var sq: Vector2 = p["square"]
	var geo: TrackGeometry = boss.world.geo
	var tu: GoldenConvergenceTuning = boss.tuning
	var mid: float = (sq.x + sq.y) * 0.5
	magnate.play(&"crouch")
	chase.place(Vector3(geo.lane_x(lane), 0.0, TrackGeometry.world_z(mid)), 0.0, 0.0)
	magnate.set_crash(true, Vector3(geo.lane_x(lane), tu.crash_height * 0.5, TrackGeometry.world_z(mid)),
		Vector3(geo.lane_width * tu.crash_width_share, tu.crash_height, sq.y - sq.x))
	boss.world.effects.burst(Vector3(geo.lane_x(lane), 0.3, TrackGeometry.world_z(mid)), Color(0.78, 0.74, 0.66), 34, 1.4)
	boss.world.effects.shake(0.3, 0.35)
	boss.sound(&"magnate_crash", boss.sound_point(magnate.global_position))
	boss.log_event(&"pounce_crash", {"n": pounces, "lane": lane, "runner": boss.player_distance(),
		"runner_lane": boss.player_lane()})


func _tick_crash(delta: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	var sq: Vector2 = p["square"]
	var past: bool = boss.player_distance() > sq.y + 0.6
	chase.place(magnate.global_position, 0.0, delta)
	if (stage_time >= tu.crash_min and past) or stage_time >= tu.crash_max:
		magnate.set_crash(false)
		_remove_square()
		# Off onto the balustrade away from the runner.
		var lane: int = int(p["lane"])
		var side: int = 1 if boss.player_lane() < lane else (-1 if boss.player_lane() > lane else chase.nearer_side(magnate.global_position.x))
		_bound = {"from": magnate.global_position, "side": side, "seconds": tu.bound_seconds / boss.pace()}
		_set_stage(Stage.BOUND)
		magnate.play(&"leap")
		boss.log_event(&"pounce_bound", {"n": pounces, "side": side})


func _tick_bound(delta: float) -> void:
	var from: Vector3 = _bound["from"]
	var u: float = clampf(stage_time / maxf(float(_bound["seconds"]), 0.05), 0.0, 1.0)
	var side: int = int(_bound["side"])
	var top: float = chase.balustrade_y()
	var x: float = lerpf(from.x, chase.balustrade_x(side), u * u * (3.0 - 2.0 * u))
	var y: float = lerpf(from.y, top, u) + BOUND_HEIGHT * 4.0 * u * (1.0 - u)
	chase.place(Vector3(x, y, from.z - 2.0 * u), 0.0, delta)
	if u >= 1.0:
		_set_stage(Stage.RETURN)
		chase.drop_back(self, side)


# --- The bait: the stun, the release ----------------------------------------------------------------------

func _stun_x() -> float:
	var lanes: Array = p["stun_lanes"]
	return (boss.world.geo.lane_x(int(lanes[0])) + boss.world.geo.lane_x(int(lanes[1]))) * 0.5


## His slump's turn: head toward his second lane, back to the runner.
func _stun_yaw() -> float:
	var lanes: Array = p["stun_lanes"]
	var gate: int = int(p["gate_lane"])
	var toward: int = 1 if int(lanes[1]) != gate else -1
	return -toward * STUN_YAW


## Locked onto the buttress's lane, he crashes into the gate and slumps in its rubble across his two lanes.
func _stun() -> void:
	_set_stage(Stage.STUN)
	stuns += 1
	p["landed_at"] = boss.fight_time()
	chase.alarm = 0.0
	_remove_square()
	if gate() != null:
		buttress.smash()
	var geo: TrackGeometry = boss.world.geo
	var tu: GoldenConvergenceTuning = boss.tuning
	var mid: float = float(p["stun_mid"])
	magnate.play(&"slump")
	magnate.speed = 0.0
	magnate.ports_glow = 1.0
	chase.place(Vector3(_stun_x(), 0.0, TrackGeometry.world_z(mid)), _stun_yaw(), 0.0)
	var back: float = float(p["stun_back"])
	var reach: float = tu.stun_reach * boss.run_pace()
	var top: float = _stomp_top()
	var lanes: Array = p["stun_lanes"]
	for i: int in 2:
		var lane: int = int(lanes[i])
		var from: float = back - reach
		var to: float = back + STUN_DEPTH
		magnate.set_weak_box(i, true, Vector3(geo.lane_x(lane), (top + 0.2) * 0.5, TrackGeometry.world_z((from + to) * 0.5)),
			Vector3(geo.lane_width * 0.9, top - 0.2, to - from))
	# Solid but safe: a switch into either lane beside him bumps, from a lane switch's run before his back.
	var lead: float = boss.world.tuning.run_speed * boss.world.tuning.lane_switch_time * tu.blocker_lead
	var x0: float = geo.lane_x(int(lanes[0])) - geo.lane_width * 0.25
	var x1: float = geo.lane_x(int(lanes[1])) + geo.lane_width * 0.25
	var z0: float = back - lead
	var z1: float = back + STUN_DEPTH
	magnate.set_blocker(true, Vector3((x0 + x1) * 0.5, GoldenConvergenceMagnate.BLOCKER_HEIGHT * 0.5,
		TrackGeometry.world_z((z0 + z1) * 0.5)), Vector3(x1 - x0, GoldenConvergenceMagnate.BLOCKER_HEIGHT, z1 - z0))
	# E5d-e: the green chevrons where to take off, in both his lanes.
	if takeoff_marks != null:
		takeoff_marks.show_marks(lanes, back, takeoff_gaps())
	boss.world.effects.burst(Vector3(_stun_x(), 1.2, TrackGeometry.world_z(mid + 1.0)), Color(0.86, 0.84, 0.78), 46, 1.8)
	boss.world.effects.shake(0.5, 0.5)
	boss.sound(&"magnate_slam", boss.sound_point(magnate.global_position))
	boss.sound(&"magnate_stun", boss.sound_point(magnate.global_position))
	boss.hint("stun")
	boss.log_event(&"stun", {"n": pounces, "lanes": lanes, "back": back, "runner": boss.player_distance(),
		"runner_lane": boss.player_lane(), "last_takeoff": back - last_takeoff_gap()})


## His weak points' top over the causeway: his back plus stun_stomp_top, kept STOMP_WINDOW under the highest a jump
## can stomp from (MovementTuning.jump_height plus GameRules.stomp_tolerance), whatever either tuning says.
static func stomp_top(t: GoldenConvergenceTuning, movement: MovementTuning, rules: GameRules) -> float:
	var tolerance: float = rules.stomp_tolerance if rules != null else GameRules.new().stomp_tolerance
	return minf(STUN_BACK_TOP + t.stun_stomp_top, movement.jump_height + tolerance - STOMP_WINDOW)


func _stomp_top() -> float:
	return stomp_top(boss.tuning, boss.world.tuning, boss.world.rules)


## How far before his back a runner still on the floor makes him shake free: stun_release at the run speed, but
## never while a jump from where they are could still come down on his back (last_takeoff_gap; E5d polish: with
## F6's stun_release high and stun_reach short he'd shake free before any jump could reach him).
func release_gap() -> float:
	return minf(boss.tuning.stun_release * boss.speed_planned(), last_takeoff_gap())


## The closest to his back (track distance before it) a runner on the floor can still jump from and come down on his
## weak points, at the run speed: the jump's feet first come under their top over their far end.
func last_takeoff_gap() -> float:
	var mt: MovementTuning = boss.world.tuning
	var fall: float = mt.gravity() * mt.fall_gravity_multiplier
	var under_top: float = mt.jump_time_to_apex + sqrt(2.0 * maxf(mt.jump_height - _stomp_top(), 0.0) / fall)
	return maxf(boss.speed_planned() * under_top - STUN_DEPTH, 0.0)


## E5d-e: how long before the runner reaches his back he crashes into the gate (never over the pace): stun_lead, or
## longer so that stun_takeoff is left from the stun to the runner's last takeoff for a stomp (last_takeoff_gap() at
## the run speed).
func stun_lead_seconds() -> float:
	var t: GoldenConvergenceTuning = boss.tuning
	return maxf(t.stun_lead, t.stun_takeoff + last_takeoff_gap() / maxf(boss.speed_planned(), 1.0))


## E5d-e: the stretch a jump can be taken from and still come down on his weak points (track distance before his
## back: x the nearest, last_takeoff_gap(); y the furthest, where the jump's feet are last in their stomp height,
## GameRules.stomp_tolerance under their top, as it reaches their near end), at the run speed. The green chevrons
## mark its middle.
func takeoff_gaps() -> Vector2:
	var mt: MovementTuning = boss.world.tuning
	var tol: float = boss.world.rules.stomp_tolerance if boss.world.rules != null else GameRules.new().stomp_tolerance
	var fall: float = mt.gravity() * mt.fall_gravity_multiplier
	var t_low: float = mt.jump_time_to_apex + sqrt(2.0 * maxf(mt.jump_height - (_stomp_top() - tol), 0.0) / fall)
	var far: float = boss.speed_planned() * t_low + boss.tuning.stun_reach * boss.run_pace()
	return Vector2(last_takeoff_gap(), maxf(far, last_takeoff_gap() + 0.5))


## Where his back's near edge is (track distance), while stunned.
func stun_back() -> float:
	return float(p.get("stun_back", INF))


## The release's watch: a runner within release_gap of his back who can't come down on it any more (on the
## floor, or falling with their feet already under his weak points' stomp height), or one past him.
func _tick_stun() -> void:
	var pl: Player = boss.world.player
	var back: float = float(p["stun_back"])
	var gap: float = back - pl.distance
	var lowest_stomp: float = _stomp_top() - boss.world.rules.stomp_tolerance
	var down: bool = pl.surface == Player.Surface.FLOOR and (pl.grounded or (pl.vh <= 0.0 and pl.h < lowest_stomp))
	if down and gap < release_gap():
		_release(&"floor", gap)
	elif pl.distance > back + STUN_DEPTH + 1.0:
		_release(&"passed", gap)


## The miss: he shakes free and leaps away, up and onto the balustrade on his head's side, before the runner
## reaches him; then he drops back behind them.
func _release(why: StringName, gap: float) -> void:
	misses += 1
	_off_stun()
	# Toward his second lane's side (his head's).
	var lanes: Array = p["stun_lanes"]
	var side: int = 1 if int(lanes[1]) != int(p["gate_lane"]) else -1
	_shake = {"from": magnate.global_position, "side": side}
	_set_stage(Stage.SHAKE)
	magnate.play(&"hurl")
	boss.world.effects.shake(0.3, 0.4)
	boss.sound(&"magnate_howl", boss.sound_point(magnate.global_position))
	boss.log_event(&"stun_released", {"n": pounces, "why": why, "gap": gap, "runner": boss.player_distance()})


func _tick_shake(delta: float) -> void:
	var from: Vector3 = _shake["from"]
	var side: int = int(_shake["side"])
	var u: float = clampf(stage_time / SHAKE_SECONDS, 0.0, 1.0)
	var e: float = 1.0 - (1.0 - u) * (1.0 - u)
	var x: float = lerpf(from.x, chase.balustrade_x(side), e)
	var y: float = lerpf(from.y, chase.balustrade_y(), u) + SHAKE_HEIGHT * minf(u * 2.2, 1.0) * (1.0 - u * u)
	var z: float = from.z - (SHAKE_AHEAD + boss.speed_planned() * SHAKE_SECONDS * 0.5) * e
	chase.place(Vector3(x, y, z), _stun_yaw() * (1.0 - e), delta)
	if u >= 1.0:
		_set_stage(Stage.RETURN)
		chase.drop_back(self, side)


## A stomp landed on his back (GoldenConvergence._on_weak_point_hit; the phase ends right after).
func on_stomp() -> void:
	stomps += 1
	magnate.ports_glow = 0.0
	boss.log_event(&"magnate_stomp", {"n": pounces, "lane": boss.player_lane(), "runner": boss.player_distance()})


func _off_stun() -> void:
	for i: int in 2:
		magnate.set_weak_box(i, false)
	magnate.set_weak_points_enabled(false)
	magnate.set_blocker(false)
	magnate.ports_glow = 0.0
	if takeoff_marks != null:
		takeoff_marks.hide_marks()


# --- The square ---------------------------------------------------------------------------------------

## The red square where he'll land: a frame over `lane` from track distance `from` to `to`, and a faint fill; a
## floor warning (BossProps.floor_warning), pulsing a little (steady with Reduced flashing).
func _show_square(lane: int, from: float, to: float) -> void:
	_remove_square()
	var geo: TrackGeometry = boss.world.geo
	var w: float = geo.lane_width * 0.92
	var depth: float = absf(to - from)
	if _square_material == null:
		prewarm()
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(_square_material)
	var r: float = SQUARE_RIM
	s.box(Vector3(0.0, 0.0, depth * 0.5 - r * 0.5), Vector3(w, 0.04, r), Color.WHITE)
	s.box(Vector3(0.0, 0.0, -depth * 0.5 + r * 0.5), Vector3(w, 0.04, r), Color.WHITE)
	s.box(Vector3(w * 0.5 - r * 0.5, 0.0, 0.0), Vector3(r, 0.04, depth - 2.0 * r), Color.WHITE)
	s.box(Vector3(-w * 0.5 + r * 0.5, 0.0, 0.0), Vector3(r, 0.04, depth - 2.0 * r), Color.WHITE)
	# The diagonals: an X across it, where he'll come down.
	for k: int in 2:
		var dir: float = 1.0 if k == 0 else -1.0
		var length: float = sqrt(w * w + depth * depth) - 2.0 * r
		var ang: float = atan2(w, depth) * dir
		s.box_xform(Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(r * 0.7, 0.03, length)), Vector3.ZERO),
			Color.WHITE)
	var mesh: MeshInstance3D = batch.commit(boss.props, "PounceSquare")
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_square_base = Transform3D(Basis.IDENTITY, Vector3(geo.lane_x(lane), 0.035, TrackGeometry.world_z((from + to) * 0.5)))
	mesh.transform = _square_base
	boss.props.floor_warning(mesh, lane, minf(from, to), maxf(from, to))
	_square = mesh
	_square_t = 0.0


func _pulse_square(delta: float) -> void:
	if _square == null or not is_instance_valid(_square):
		return
	_square_t += delta
	var grow: float = 0.9 + 0.1 * clampf(_square_t / 0.6, 0.0, 1.0)
	var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.06 * sin(_square_t * 22.0)
	_square.transform = Transform3D(Basis.from_scale(Vector3(grow * beat, 1.0, grow * beat)), _square_base.origin)


func _remove_square() -> void:
	if _square != null and is_instance_valid(_square):
		boss.props.remove(_square)
	_square = null


## The square on the floor now (tests, the bot): {lane, from, to} or {}.
func square() -> Dictionary:
	if _square == null or not is_instance_valid(_square) or not p.has("square"):
		return {}
	var sq: Vector2 = p["square"]
	return {"lane": int(p["lane"]), "from": sq.x, "to": sq.y}


# --- Clear ------------------------------------------------------------------------------------------

func _set_stage(next: Stage) -> void:
	stage = next
	stage_time = 0.0


## The bait's buttress while it's still the one this Pounce raised (never a gate gone back to the pool and risen
## for another attack since), or null.
func gate() -> GoldenConvergenceButtress:
	if buttress != null and is_instance_valid(buttress) and buttress.is_placement(buttress_places):
		return buttress
	return null


## Everything at once (a phase's end, the defeat): the square, the crash, the weak points and his sides gone,
## a buttress still standing ahead of the runner sinking back into the causeway (one crumbling crumbles on, and
## goes back to the pool once passed: nothing pops in front of the runner); whoever comes next moves him (the
## next phase's intro, the defeat).
func clear() -> void:
	super()
	_remove_square()
	if magnate != null:
		magnate.set_crash(false)
		_off_stun()
	if chase != null:
		chase.alarm = 0.0
	var b: GoldenConvergenceButtress = gate()
	if b != null and b.standing() and b.at > boss.player_distance():
		b.sink()
	buttress = null
	buttress_places = -1
	_set_stage(Stage.IDLE)
	p = {}
	_bound = {}
	_shake = {}
