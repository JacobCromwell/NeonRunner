class_name GoldenConvergenceOvertake
extends GoldenConvergenceAttack
## The Magnate shows himself (GDD §10: "he shows himself the way the Enforcer Truck does (§9.13): he overtakes
## along a wall or ceiling, lands ahead, then drops back"; proposed: his walls are the balustrades, out of the
## runner's reach): the beat kind `overtake` (GoldenConvergenceTuning.phase_beats). Over overtake_seconds
## (divided by the phase's pace) he leaves his place behind the runner for the nearer balustrade, gallops past the
## runner along it to overtake_ahead in front of them, leaps across the causeway high over every lane
## (overtake_height) onto the other balustrade ahead, and drops back along it behind the runner (the chase's
## drop back). It's no attack: nothing of it can touch the runner, it never enters a lane in sight, and it
## growls rather than roars (the roar is the Pounce's warning). Framing in metres relative to the runner.

## Its shares of the overtake: onto the balustrade, past the runner along it, the leap across.
const ONTO: float = 0.14
const PAST: float = 0.5
const ACROSS: float = 0.72

var chase: GoldenConvergenceChase
var magnate: GoldenConvergenceMagnate
## Overtakes so far, and the one under way: {t, seconds, side, from_x, rel0}.
var count: int = 0
var run: Dictionary = {}
## Dropping back after it (the beat lasts until he's home behind the runner).
var returning: bool = false


func _init(p_boss: GoldenConvergence) -> void:
	super(p_boss, &"overtake")
	chase = boss.chase
	magnate = boss.magnate


## Busy until he's home behind the runner again (the next beat's warning never comes while he's in view).
func busy() -> bool:
	if returning and chase.home():
		returning = false
	return not run.is_empty() or returning


func start(_beat: Dictionary) -> void:
	clear()
	count += 1
	var from: Vector3 = magnate.global_position
	run = {"t": 0.0, "seconds": boss.tuning.overtake_seconds / boss.pace(), "side": chase.nearer_side(from.x),
		"from_x": from.x, "rel0": -from.z - boss.player_distance()}
	chase.drive(self)
	magnate.breathe(&"magnate_growl")
	boss.log_event(&"overtake", {"n": count, "side": int(run["side"])})


func tick(delta: float) -> void:
	if run.is_empty():
		return
	run["t"] = float(run["t"]) + delta
	var u: float = clampf(float(run["t"]) / maxf(float(run["seconds"]), 0.05), 0.0, 1.0)
	var t: GoldenConvergenceTuning = boss.tuning
	var side: int = int(run["side"])
	var near_x: float = chase.balustrade_x(side)
	var far_x: float = chase.balustrade_x(-side)
	var top: float = chase.balustrade_y()
	var d: float = boss.player_distance()
	var rel0: float = float(run["rel0"])
	var pos: Vector3
	if u < ONTO:
		# Out of his lane onto the nearer balustrade, still behind the camera.
		var k: float = _ease(u / ONTO)
		pos = Vector3(lerpf(float(run["from_x"]), near_x, k), top * k, TrackGeometry.world_z(d + rel0))
		magnate.play(&"run")
	elif u < PAST:
		# Past the runner along it.
		var k: float = _ease((u - ONTO) / (PAST - ONTO))
		pos = Vector3(near_x, top, TrackGeometry.world_z(d + lerpf(rel0, t.overtake_ahead, k)))
		magnate.play(&"run")
	elif u < ACROSS:
		# Across the causeway, high over every lane, onto the other balustrade ahead.
		var k: float = (u - PAST) / (ACROSS - PAST)
		var y: float = top + t.overtake_height * 4.0 * k * (1.0 - k)
		pos = Vector3(lerpf(near_x, far_x, _ease(k)), y, TrackGeometry.world_z(d + t.overtake_ahead + 3.0 * k))
		magnate.play(&"leap")
	else:
		# On the other balustrade ahead: a growl, then the chase's drop back takes him behind the runner.
		pos = Vector3(far_x, top, TrackGeometry.world_z(d + t.overtake_ahead + 3.0))
		magnate.play(&"run")
		chase.place(pos, 0.0, delta)
		boss.log_event(&"overtake_done", {"n": count})
		chase.drop_back(self, -side)
		magnate.breathe(&"magnate_growl")
		run = {}
		returning = true
		return
	chase.place(pos, 0.0, delta)


static func _ease(k: float) -> float:
	var c: float = clampf(k, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## Everything at once (a phase's end): he drops back from where he is (the next phase's intro takes him).
func clear() -> void:
	super()
	returning = false
	if not run.is_empty():
		run = {}
		chase.drop_back(self, int(chase.nearer_side(magnate.global_position.x)))
