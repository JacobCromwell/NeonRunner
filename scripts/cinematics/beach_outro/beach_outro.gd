class_name BeachOutro
extends CinematicSequencer
## The Beach's outro, after Mecha Guppy and Captain Cogs (the owner's beats, October 15, 2026):
## 1. Mecha Guppy swims away: out at sea it bursts out of the water in one long leap heading away, dives back in, and
##    swims off, its back and dorsal fin cutting the water until it sinks out of sight.
## 2. The camera pans over to the runner, watching it from the promenade, their screech friend sitting at their feet.
##    They turn and walk over to a tiki bar (BeachOutroBar: the Beach's own tiki bar kiosk, dressed).
## 3. Cut to them walking up to the bar.
## 4. From the barkeeper's view: the screech hops up onto the bar.
## 5. The bartender (the volleyball match's opponent) gestures to the menu on the wall: what'll it be?
## 6. The runner and the screech look at him, and the runner holds up two fingers: two drinks.
## 7. He turns his back to make them.
## 8. Cut to the Golden Palace (BeachOutroPalace): in a dark room walled with screens, the Golden Convergence's face;
##    it raises its hand and points a finger forward.
## 9. Its refill ships (the final fight's, BeachOutroRaid) flying forward.
## 10. Back at the beach, the two drinks on the bar: the ships fly over, dropping bombs; big explosions. The runner
##     and the screech look up, see the bombs, leave their drinks and run; explosions to the left, then the right.
## 11. The runner sees a pool and jumps in just as an explosion goes off, the fire filling the picture; then black,
##     and the Dead Zone's intro (which opens on them lying in a smoking crater).
## A script on the toolkit, its numbers data (`numbers`, by default data/cinematics/beach_outro_tuning.tres,
## BeachOutroTuning). One stage throughout, picking up where the fight ended (CineStageDef.after_fight: the arena's
## open shore and the sunset the fight was under), on the level's lanes, with the pool a gap in the start lane (the
## Beach's gaps are pools of water). The Golden Palace is a set of its own, closed, high over the stage: for its shot
## the street hides, its fog goes off and the scenery's light goes down (restored after, and when it ends). Everything
## is worked out from the time (_on_advance), so stepping or skipping shows the same.
## DESIGN-TBD (docs/questions/f2e.md): the staging the beats leave open.

const NUMBERS_PATH: String = "res://data/cinematics/beach_outro_tuning.tres"
## The runner slows to a stop at the counter over this long (an eased stop), and squares up to it this long after.
const ARRIVE_SETTLE: float = 0.5
const SQUARE_UP: float = 0.3
## The runner's two fingers: how long the hand takes to come up (and go down), and its fingers (the hand joint's
## space, metres): their root, length, thickness and spread (degrees each way).
const HAND_BLEND: float = 0.35
const FINGER_ROOT := Vector3(0.0, -0.092, -0.012)
const FINGER_LENGTH: float = 0.075
const FINGER_THICK: float = 0.017
const FINGER_SPREAD: float = 11.0
## The runner turns and starts running over this long, then runs flat out.
const RUN_START: float = 0.35
## The screech: how far from the runner it keeps (to their right as they walk or run, metres), and back behind them;
## its seat on the ground by the counter, out from the runner's place.
const SCREECH_SIDE: float = 0.55
const SCREECH_BACK: float = 0.25
const SCREECH_GROUND := Vector3(0.42, 0.0, -0.55)
## Its hop down from the counter as they run (seconds).
const HOP_DOWN: float = 0.4
## Where it sits on the counter's top, in from its front (metres).
const PERCH_IN: float = 0.17
## The shots that look back up the street (the first, out to sea; the ships') see this far: the street stays built
## from LOOK_BACK + 30 m behind the bar (TrackBuilder.KEEP_BEHIND).
const LOOK_BACK: float = 170.0
const SEA_BACK: float = 90.0
## The Golden Palace hangs this high over the street (well over anything built there), over the bar.
const PALACE_HEIGHT: float = 300.0
## The bombs' shake: metres per metre of fireball radius, and how long.
const BLAST_SHAKE: float = 0.025
const BLAST_SHAKE_SECONDS: float = 0.5
## With Reduced flashing the fire comes up this much more slowly and this much darker.
const SOFT_FIRE_SLOW: float = 2.5
const SOFT_FIRE_DARK: float = 0.35

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: BeachOutroTuning

var n: BeachOutroTuning
var bar: BeachOutroBar
var screech: BeachOutroScreech
var palace: BeachOutroPalace
var raid: BeachOutroRaid
## Mecha Guppy: its head (the jaws' hinge) and its plumes.
var shark: Node3D
var plumes: Array[MechaGuppySplash] = []
## The runner's two raised fingers (on their right hand, shown while they hold them up).
var fingers: Node3D
## True while the Golden Palace's room is showing.
var in_palace: bool = false
## Where things are (track space): the counter's front middle (the bar's origin), where the runner watches from,
## stands at the counter, comes into the start lane, takes off for the pool; the sea's level; where Mecha Guppy
## bursts out.
var counter := Vector3.ZERO
var watch_point := Vector3.ZERO
var stand_point := Vector3.ZERO
var lane_point := Vector3.ZERO
var takeoff := Vector3.ZERO
var sea_y: float = -1.4
var burst_point := Vector3.ZERO
var palace_origin := Vector3.ZERO
## When things happen (seconds): the runner reaches the counter, and the pace they run at.
var t_arrive: float = 0.0
var run_pace: float = 7.0
## The water in the pool (its level), and splashes made so far (the runner's and the screech's).
var water_y: float = -0.45
var splashed: Dictionary = {}

var _fog_was: bool = true
var _light_before: float = 1.0
var _fire_color := Color.BLACK


func _numbers() -> BeachOutroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as BeachOutroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	var d := CineStageDef.new()
	d.length = n.stage_length
	d.after_fight = true
	d.gaps = PackedVector3Array([Vector3(0.0, n.bar_at + n.pool_from, n.bar_at + n.pool_from + n.pool_length)])
	return d


## Where and when things happen, from the numbers and the stage's street.
func _plan() -> void:
	var raw: Vector3 = n.kiosk_size
	var front: float = stage.wall_x(-1) + n.kiosk_inset + (raw.x - BeachOutroBar.COUNTER_FRONT_IN) * n.kiosk_scale
	counter = Vector3(front, 0.0, n.bar_at)
	watch_point = at_bar(n.watch_from)
	stand_point = at_bar(Vector3(n.counter_gap, 0.0, 0.0))
	var beach := stage.skin as BeachSkin
	if beach != null:
		sea_y = -beach.beach_drop
		water_y = -beach.pool_depth
	var walk: float = watch_point.distance_to(stand_point)
	t_arrive = n.walk_at + (walk - ARRIVE_SETTLE * n.walk_speed * 0.5) / maxf(n.walk_speed, 0.1) + ARRIVE_SETTLE
	if t_arrive > n.bartender_view_at:
		push_warning("BeachOutro: the runner reaches the counter at %.2f s, after the cut to the bartender's view" % t_arrive)
	lane_point = Vector3(0.0, 0.0, n.bar_at + 8.0)
	takeoff = Vector3(0.0, 0.0, n.bar_at + n.pool_from - 1.1)
	var run: float = stand_point.distance_to(lane_point) + lane_point.distance_to(takeoff)
	run_pace = run / maxf(n.jump_at - n.run_at - RUN_START * 0.5, 0.5)
	burst_point = Vector3(stage.wall_x(-1) - n.breach_out, sea_y, n.bar_at + n.breach_along)
	palace_origin = Vector3(0.0, PALACE_HEIGHT, n.bar_at)


## A point given from the counter's front middle (x out into the street, y up, z along the track): track space.
func at_bar(p: Vector3) -> Vector3:
	return counter + p


func _make_timeline() -> CineTimeline:
	_plan()
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	bar = BeachOutroBar.new()
	stage.add_child(bar)
	bar.setup(stage.skin as BeachSkin if stage.skin is BeachSkin else BeachSkin.new(), n)
	bar.global_position = stage.point(counter)
	screech = BeachOutroScreech.new()
	add_child(screech)
	screech.setup_friend(n.screech_size, n.screech_look)
	_build_shark()
	palace = BeachOutroPalace.new()
	add_child(palace)
	palace.setup(n)
	palace.global_position = stage.point(palace_origin)
	palace.point_target = Vector3(0.0, palace.face_point().y, 14.0)
	raid = BeachOutroRaid.new()
	add_child(raid)
	raid.setup(stage, n)
	_runner(t)
	_camera(t)
	_events(t)
	return t


# --- Mecha Guppy --------------------------------------------------------------------------------------

func _build_shark() -> void:
	shark = Node3D.new()
	shark.name = "MechaGuppy"
	add_child(shark)
	var beach := stage.skin as BeachSkin
	var m: Dictionary = MechaGuppySharkModel.meshes(beach if beach != null else BeachSkin.new())
	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3.ONE * n.shark_scale
	shark.add_child(body)
	for part: String in ["upper_jaw", "lower_jaw", "body"]:
		var mi: MeshInstance3D = MeshBatch.add_instance(body, m[part], part.capitalize().replace(" ", ""))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 20.0
	for i: int in 2:
		var plume := MechaGuppySplash.new()
		plume.name = "Plume%d" % i
		add_child(plume)
		plumes.append(plume)


## Mecha Guppy at `t` (track space for its head, the jaws' hinge, and the way its snout points): from under the sea up
## through its leap's arc out to sea, head first back in, then on under the surface, its back and fin showing, sinking
## away. Returns [head, direction]; its body trails straight behind the head.
func shark_pose(t: float) -> Array:
	var v := Vector3(n.swim_velocity.x, 0.0, n.swim_velocity.y)
	var span: float = n.breach_seconds
	var u: float = (t - n.breach_at) / span
	var flat: Vector3 = v * span
	var height: float = n.breach_height
	if u <= 1.0:
		# The arc: up out of the sea, over, and back in (the head's path), the snout along it.
		var uu: float = maxf(u, -0.6)
		var head: Vector3 = burst_point + flat * uu + Vector3(0.0, 4.0 * height * uu * (1.0 - uu), 0.0)
		var tangent: Vector3 = flat + Vector3(0.0, 4.0 * height * (1.0 - 2.0 * uu), 0.0)
		return [head, tangent.normalized()]
	# Under the sea: on along its heading, levelling out at fin_depth, its back breaking the surface, then sinking.
	var e: float = (t - n.breach_at - span) / maxf(n.fin_seconds, 0.1)
	var entry: Vector3 = burst_point + flat
	var dive: Vector3 = (flat + Vector3(0.0, -4.0 * height, 0.0)).normalized()
	var level: float = smoothstep(0.0, 0.5, e)
	var dir: Vector3 = dive.lerp(v.normalized(), level).normalized()
	var depth: float = lerpf(0.0, n.fin_depth, smoothstep(0.0, 0.4, e)) + 14.0 * smoothstep(0.6, 1.0, e)
	var head: Vector3 = entry + v * (t - n.breach_at - span) + Vector3(0.0, -depth, 0.0)
	return [head, dir]


func _place_shark() -> void:
	var span: float = n.breach_seconds + n.fin_seconds
	var shown: bool = time >= n.breach_at - 0.2 and time <= n.breach_at + span and not in_palace
	shark.visible = shown
	if shown:
		var pose: Array = shark_pose(time)
		var dir: Vector3 = pose[1]
		# Its local +y along the snout; +z (its belly) as near straight down as the snout allows. Track z runs against
		# world z.
		var y := Vector3(dir.x, dir.y, -dir.z).normalized()
		var down: Vector3 = Vector3.DOWN - y * Vector3.DOWN.dot(y)
		var z: Vector3 = down.normalized() if down.length() > 0.01 else Vector3.FORWARD
		shark.global_transform = Transform3D(Basis(y.cross(z), y, z), stage.point(pose[0]))
	var bursts: Array[float] = [n.breach_at, n.breach_at + n.breach_seconds]
	for i: int in plumes.size():
		var plume: MechaGuppySplash = plumes[i]
		if time >= bursts[i] and plume.age < 0.0 and not splashed.has("plume%d" % i):
			splashed["plume%d" % i] = true
			var size: Vector2 = n.burst_plume if i == 0 else n.dive_plume
			var at: Vector3 = burst_point + Vector3(n.swim_velocity.x, 0.0, n.swim_velocity.y) * n.breach_seconds * float(i)
			plume.play(stage.point(at), size.x, size.y)


# --- The runner ------------------------------------------------------------------------------------

func _runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	r.turn_rate = n.turn_rate
	# Watching Mecha Guppy go from the promenade (facing out to sea, back toward where it leapt), following it with
	# their head; then turning to the bar.
	var sea_yaw: float = _yaw_to(watch_point, burst_point)
	_turned(r.at(0.0, watch_point, &"walk"), sea_yaw, 0.0)
	_turned(r.at(n.breach_at + 1.2, watch_point), sea_yaw, -12.0)
	_turned(r.at(n.breach_at + n.breach_seconds + 0.6, watch_point), sea_yaw, -30.0)
	var to_bar: float = _yaw_to(watch_point, stand_point)
	_turned(r.at(n.walk_at - 0.6, watch_point), sea_yaw, -30.0)
	_turned(r.at(n.walk_at, watch_point), to_bar, 0.0)
	# The walk over to the bar: steady, then an eased stop at the counter.
	var slow: float = t_arrive - ARRIVE_SETTLE
	var settle: Vector3 = stand_point + (watch_point - stand_point).normalized() * (ARRIVE_SETTLE * n.walk_speed * 0.5)
	r.at(slow, settle)
	_eased(r.at(t_arrive, stand_point), Tween.TRANS_QUAD, Tween.EASE_OUT)
	# Facing the bar (+90: -x); looking at the bartender, at the menu as he points to it, back at him, up at the ships.
	var face: float = 90.0
	var looks: Array = [[t_arrive + SQUARE_UP, -12.0, 0.0], [n.gesture_at + 0.3, -12.0, 0.0], [n.gesture_at + 0.8, -38.0, 14.0],
		[n.ask_at + 0.2, -38.0, 14.0], [n.ask_at + 0.6, -14.0, 2.0], [n.raid_at, -14.0, 2.0], [n.look_up_at, -14.0, 2.0],
		[n.look_up_at + 0.5, 20.0, 55.0], [n.run_at, 20.0, 55.0]]
	var last: float = t_arrive
	for look: Array in looks:
		last = maxf(float(look[0]), last + 0.05)
		var k: CineActorKey = _turned(r.at(last, stand_point), face, float(look[1]))
		k.look_up = float(look[2])
	# They run for it: a turn and a step, then flat out down the street to the pool.
	_turned(r.at(maxf(n.run_at + 0.02, last + 0.05), stand_point, &"run"), face, 20.0).look_up = 30.0
	var start: Vector3 = stand_point + (lane_point - stand_point).normalized() * (run_pace * RUN_START * 0.5)
	var go: CineActorKey = r.at(n.run_at + RUN_START, start, &"run")
	go.face_path = true
	var lane_at: float = n.run_at + RUN_START + start.distance_to(lane_point) / run_pace
	r.at(lane_at, lane_point)
	r.at(n.jump_at, takeoff)
	# The jump into the pool: up, over its edge, down into the water and under.
	var reach: float = run_pace * 0.3
	r.at(n.jump_at + 0.3, takeoff + Vector3(0.0, n.jump_height, reach), &"", CinePath.Move.SMOOTH)
	r.at(n.jump_at + 0.62, takeoff + Vector3(0.0, water_y, reach * 1.9), &"", CinePath.Move.SMOOTH)
	r.at(n.jump_at + 1.2, takeoff + Vector3(0.0, -2.6, reach * 2.4), &"", CinePath.Move.SMOOTH)


## The heading (CineActorKey.yaw, degrees: 0 down the track, + left) from `a` to `b`.
static func _yaw_to(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = b - a
	return rad_to_deg(atan2(-d.x, d.z))


static func _eased(k: CineActorKey, trans: Tween.TransitionType = Tween.TRANS_SINE,
		easing: Tween.EaseType = Tween.EASE_IN_OUT) -> CineActorKey:
	k.trans = trans
	k.easing = easing
	return k


static func _turned(k: CineActorKey, body: float, head: float) -> CineActorKey:
	k.face_path = false
	k.yaw = body
	k.look = head
	return k


# --- The camera ------------------------------------------------------------------------------------

func _camera(t: CineTimeline) -> void:
	var c: Vector3 = counter
	var w: Vector3 = watch_point
	# Out to sea from the promenade as Mecha Guppy leaps away and swims off.
	var sea_cam: Vector3 = w + Vector3(1.9, 1.35, -7.0)
	var swim: Vector3 = Vector3(n.swim_velocity.x, 0.0, n.swim_velocity.y)
	var leap_top: Vector3 = burst_point + swim * n.breach_seconds * 0.5 + Vector3(0.0, n.breach_height * 0.55, 0.0)
	t.shot(0.0, sea_cam, burst_point + swim * n.breach_seconds * 0.3 + Vector3(0.0, n.breach_height * 0.45, 0.0),
		CinePath.Move.SMOOTH, 48.0)
	t.shot(n.breach_at + n.breach_seconds * 0.5, sea_cam + Vector3(0.0, 0.03, 0.15), leap_top, CinePath.Move.SMOOTH, 50.0)
	var swim_on: Vector3 = burst_point + swim * (n.breach_seconds + n.fin_seconds * 0.6) + Vector3(0.0, 1.0, 0.0)
	var pan_from: float = n.breach_at + n.breach_seconds + n.fin_seconds * 0.6
	t.shot(pan_from, sea_cam + Vector3(0.0, 0.05, 0.3), swim_on, CinePath.Move.LINEAR, 44.0)
	# The pan: the camera turns from the sea to the runner watching it (both looks kept a few metres off, so it turns
	# evenly rather than swinging through the far point).
	var cam_pan: Vector3 = sea_cam + Vector3(0.0, 0.05, 0.3)
	var near_sea: Vector3 = cam_pan + (swim_on - cam_pan).normalized() * 6.0
	t.shot(pan_from + 0.05, cam_pan, near_sea, CinePath.Move.LINEAR, 44.0)
	var pan: CineCameraKey = t.shot(n.walk_at - 0.2, cam_pan + Vector3(0.0, 0.0, 0.2), Vector3(0.0, 1.0, 0.0),
		CinePath.Move.LINEAR, 46.0)
	pan.watch = &"runner"
	# They walk over to the bar: the camera keeps them in view, edging after them.
	var after: CineCameraKey = t.shot(n.up_close_at - 0.004, cam_pan + Vector3(-0.2, 0.05, 2.4), Vector3(0.0, 0.95, 0.0),
		CinePath.Move.LINEAR, 44.0)
	after.watch = &"runner"
	after.trans = Tween.TRANS_LINEAR
	# Cut: from the bar's far end, low along the counter's front, as they walk up to it.
	t.shot(n.up_close_at, c + Vector3(1.05, 0.95, 3.0), c + Vector3(0.4, 0.85, -2.0), CinePath.Move.CUT, 46.0)
	t.shot(n.bartender_view_at - 0.004, c + Vector3(1.15, 1.0, 2.7), c + Vector3(0.35, 0.85, -0.6), CinePath.Move.SMOOTH, 46.0)
	# Cut: the bartender's view, across the counter at the runner, and the screech hopping up beside them.
	var eyes: Vector3 = c + n.bartender_at + Vector3(-0.15, n.bartender_height * 0.93, -0.1)
	var both: Vector3 = c + Vector3(n.counter_gap * 0.3, 0.98, n.perch_along * 0.55)
	t.shot(n.bartender_view_at, eyes, both, CinePath.Move.CUT, 56.0)
	t.shot(n.bartender_shot_at - 0.004, eyes + Vector3(0.1, -0.02, 0.0), both + Vector3(0.0, -0.02, 0.0),
		CinePath.Move.SMOOTH, 54.0)
	# Cut: the bartender, from the street beyond the runner's other side: him, the menu on the wall he points to.
	var him: Vector3 = c + n.bartender_at + Vector3(0.0, n.bartender_height * 0.75, 0.0)
	t.shot(n.bartender_shot_at, c + Vector3(1.55, 1.2, 1.75), him + Vector3(0.0, 0.2, 0.35), CinePath.Move.CUT, 42.0)
	t.shot(n.order_shot_at - 0.004, c + Vector3(1.45, 1.18, 1.6), him + Vector3(0.0, 0.2, 0.3), CinePath.Move.SMOOTH, 42.0)
	# Cut: his view again, closer: the runner and the screech look at him, and the runner holds up two fingers.
	var pair: Vector3 = c + Vector3(n.counter_gap * 0.4, 1.02, n.perch_along * 0.5)
	var close: Vector3 = c + n.bartender_at + Vector3(0.12, n.bartender_height * 0.9, -0.05)
	t.shot(n.order_shot_at, close, pair, CinePath.Move.CUT, 50.0)
	t.shot(n.back_shot_at - 0.004, close + Vector3(0.08, -0.02, 0.0), pair + Vector3(0.0, 0.02, 0.0), CinePath.Move.SMOOTH, 48.0)
	# Cut: wider, from the street: he nods, turns his back and shakes their drinks.
	t.shot(n.back_shot_at, c + Vector3(2.7, 1.3, 1.9), c + Vector3(-0.6, 1.0, 0.0), CinePath.Move.CUT, 46.0)
	t.shot(n.palace_at - 0.004, c + Vector3(2.55, 1.28, 1.6), c + Vector3(-0.65, 1.0, 0.05), CinePath.Move.SMOOTH, 46.0)
	# Cut: the Golden Palace. Close on the face, pushing in; then round to the side as its arm comes up and points
	# ahead, past us.
	var face: Vector3 = palace.face_point()
	t.shot(n.palace_at, _palace(face + Vector3(0.0, 0.1, 4.4)), _palace(face), CinePath.Move.CUT, 40.0)
	t.shot(n.point_at, _palace(face + Vector3(0.0, 0.05, 3.7)), _palace(face), CinePath.Move.SMOOTH, 40.0)
	t.shot(n.point_at + n.point_seconds, _palace(face + Vector3(3.4, -0.5, 6.4)), _palace(face + Vector3(-1.6, -0.6, 1.8)),
		CinePath.Move.SMOOTH, 54.0)
	t.shot(n.ships_at - 0.004, _palace(face + Vector3(3.5, -0.52, 6.6)), _palace(face + Vector3(-1.6, -0.6, 1.8)),
		CinePath.Move.SMOOTH, 54.0)
	# Cut: the ships, flying forward, at the camera and over it, against the sunset.
	var lead_then: Vector3 = raid.ship_point(0, n.ships_at)
	var sky_cam: Vector3 = raid.ship_point(0, n.raid_at) + Vector3(-12.0, -20.0, 6.0)
	t.shot(n.ships_at, sky_cam, lead_then + Vector3(0.0, 2.0, 0.0), CinePath.Move.CUT, 44.0)
	t.shot(n.raid_at - 0.004, sky_cam + Vector3(0.0, -0.5, 2.0), raid.ship_point(0, n.raid_at - 0.3) + Vector3(0.0, 2.0, 0.0),
		CinePath.Move.SMOOTH, 54.0)
	# Cut: back at the bar, the drinks served; the first bombs land out on the beach beyond it.
	t.shot(n.raid_at, c + Vector3(3.6, 1.45, -3.2), c + Vector3(-0.6, 1.25, 0.6), CinePath.Move.CUT, 54.0)
	t.shot(n.sky_shot_at - 0.004, c + Vector3(3.4, 1.42, -2.9), c + Vector3(-0.6, 1.3, 0.6), CinePath.Move.SMOOTH, 54.0)
	# Cut: low behind them, looking up past them at the ships and the bombs coming down.
	t.shot(n.sky_shot_at, c + Vector3(0.9, 0.45, -1.9), c + Vector3(1.6, 7.0, 4.0), CinePath.Move.CUT, 68.0)
	t.shot(n.run_shot_at - 0.004, c + Vector3(0.95, 0.43, -2.0), c + Vector3(1.8, 7.6, 4.6), CinePath.Move.SMOOTH, 68.0)
	# Cut: ahead of them as they run, low, the explosions going off to one side, then the other.
	var lead: CineCameraKey = t.shot(n.run_shot_at, Vector3(0.6, 1.1, 5.5), Vector3(0.0, 0.85, 0.0), CinePath.Move.CUT, 58.0)
	lead.follow = &"runner"
	lead.watch = &"runner"
	var lead_end: CineCameraKey = t.shot(n.pool_shot_at - 0.004, Vector3(-0.2, 1.2, 4.6), Vector3(0.0, 0.9, 0.0),
		CinePath.Move.LINEAR, 58.0)
	lead_end.follow = &"runner"
	lead_end.watch = &"runner"
	# Cut: behind them, the pool ahead; they jump in, and the fire comes.
	var chase: CineCameraKey = t.shot(n.pool_shot_at, Vector3(0.6, 1.5, -4.2), Vector3(0.0, 0.5, 6.0), CinePath.Move.CUT, 60.0)
	chase.follow = &"runner"
	chase.watch = &"runner"
	var chase_end: CineCameraKey = t.shot(n.jump_at, Vector3(0.6, 1.5, -4.2), Vector3(0.0, 0.5, 6.0), CinePath.Move.LINEAR, 60.0)
	chase_end.follow = &"runner"
	chase_end.watch = &"runner"
	chase_end.trans = Tween.TRANS_LINEAR
	var hold: Vector3 = takeoff + Vector3(0.6, 1.5, -4.2)
	t.shot(n.jump_at + 0.004, hold, takeoff + Vector3(0.0, 0.5, 6.0), CinePath.Move.CUT, 60.0)
	t.shot(n.duration, hold + Vector3(0.0, 0.05, 0.6), takeoff + Vector3(0.0, 0.0, 4.5), CinePath.Move.LINEAR, 60.0)


## True during the shots from the bartender's own eyes.
func pov_shot(at: float) -> bool:
	return (at >= n.bartender_view_at and at < n.bartender_shot_at) or (at >= n.order_shot_at and at < n.back_shot_at)


## A point in the palace room's space (the suit's: +z its front) in track space (track z runs against world z).
func _palace(p: Vector3) -> Vector3:
	return palace_origin + Vector3(p.x, p.y, -p.z)


## The street stays built far enough back for the shots that look back along it: out to sea at the start, and the
## ships coming (the track builder keeps only 30 m behind the nearest point and builds 180 m ahead of it).
func _stage_near(near: float) -> float:
	if time < n.up_close_at:
		return minf(near, n.bar_at - SEA_BACK)
	if time >= n.ships_at and time < n.raid_at:
		return minf(near, n.bar_at - LOOK_BACK)
	if in_palace:
		return minf(near, n.bar_at)
	return near


# --- Sounds, effects and cues -------------------------------------------------------------------------

func _events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	# The fight's music fades out: the fight is over. DESIGN-TBD (docs/questions/f2e.md): no music of its own.
	t.music(0.0, &"", n.music_fade)
	t.sound(n.breach_at, &"guppy_leap", -4.0)
	t.sound(n.breach_at + n.breach_seconds, &"guppy_swim", -3.0)
	t.sound(n.hop_at + n.hop_seconds, &"screech_chirp")
	t.sound(n.shake_at, &"bar_shaker")
	t.cue(n.palace_at, &"palace")
	t.sound(n.palace_at + 0.2, &"gc_chime", -3.0)
	t.cue(n.ships_at, &"ships")
	t.sound(n.ships_at, &"gc_ship")
	t.sound(n.raid_at + 0.05, &"bar_glass")
	for k: int in n.bombs.size():
		var b: Vector4 = n.bombs[k]
		if k % 2 == 0:
			t.sound(b.x - n.bomb_fall, &"bomb_whistle", -4.0)
		t.sound(b.x, &"bomb_blast", 0.0 if k == n.bombs.size() - 1 else -2.0)
		t.effect(b.x, CineEvent.SHAKE, BLAST_SHAKE_SECONDS, BLAST_SHAKE * b.w)
	t.sound(n.run_at + 0.2, &"screech_chirp", -2.0)
	t.sound(n.jump_at + 0.6, &"splash")
	t.cue(n.fire_at, &"fire")


func _on_cue(cue_name: StringName) -> void:
	match cue_name:
		&"palace":
			_enter_palace()
		&"ships":
			_leave_palace()


## The Golden Palace: the street hides (the room is closed, high over it), the fog goes off (it would wash the dark
## room in the sunset's haze) and the scenery's light goes down to the room's.
func _enter_palace() -> void:
	if in_palace:
		return
	in_palace = true
	stage.visible = false
	palace.visible = true
	if stage.environment != null:
		_fog_was = stage.environment.fog_enabled
		stage.environment.fog_enabled = false
	_light_before = ZoneSkin.scenery_light_now
	ZoneSkin.set_scenery_light(n.palace_light)
	log_lines.append("palace in")


func _leave_palace() -> void:
	if not in_palace:
		return
	in_palace = false
	stage.visible = true
	palace.visible = false
	if stage.environment != null:
		stage.environment.fog_enabled = _fog_was
	ZoneSkin.set_scenery_light(_light_before)
	log_lines.append("palace out")


## Over (played out or skipped): the scenery's light and the fog go back as they were, and its props hide.
func _finish() -> void:
	if not done:
		_leave_palace()
		for node: Node3D in [screech, shark, palace, raid, fingers]:
			if node != null:
				node.visible = false
		for plume: MechaGuppySplash in plumes:
			plume.visible = false
	super()


# --- On the clock ------------------------------------------------------------------------------------

func _on_advance(_delta: float) -> void:
	if n == null:
		return
	bar.update(time)
	# The bartender's own views (across the counter at the runner): his body would be in the way.
	bar.bartender.visible = not (pov_shot(time) or in_palace)
	palace.update(time)
	raid.update(time)
	raid.visible = not in_palace
	_place_shark()
	for plume: MechaGuppySplash in plumes:
		plume.advance(_delta)
		plume.visible = not in_palace
	var runner := actors.get(&"runner") as CineActorNode
	if runner != null and runner.avatar != null:
		_pose_runner(runner)
		_place_screech(runner)
		_splashes(runner)
	_fill_fire()


## The runner's right hand up, two fingers raised (for two drinks), eased up and down.
func _pose_runner(runner: CineActorNode) -> void:
	var rig: HumanoidRig = runner.avatar.rig
	if fingers == null:
		_build_fingers(rig)
	var up: float = smoothstep(n.fingers_at, n.fingers_at + HAND_BLEND, time) \
		* (1.0 - smoothstep(n.fingers_at + n.fingers_seconds - HAND_BLEND, n.fingers_at + n.fingers_seconds, time))
	fingers.visible = up > 0.6 and runner.visible
	if up <= 0.0:
		return
	_blend(rig.joint(&"upper_arm_r"), VolleyballRival._limb(1, Vector3(70.0, 0.0, 18.0)), up)
	_blend(rig.joint(&"forearm_r"), VolleyballRival._limb(1, Vector3(95.0, 0.0, 0.0)), up)
	_blend(rig.joint(&"hand_r"), VolleyballRival._limb(1, Vector3(0.0, 90.0, 0.0)), up)


static func _blend(j: Node3D, euler: Vector3, k: float) -> void:
	if j == null:
		return
	j.quaternion = j.quaternion.slerp(Quaternion.from_euler(euler), clampf(k, 0.0, 1.0))


## Two fingers out of the runner's right hand (its fingerless glove's bare fingers, PlayerSuit.SKIN), spread in a V.
func _build_fingers(rig: HumanoidRig) -> void:
	fingers = Node3D.new()
	fingers.name = "Fingers"
	var hand: Node3D = rig.joint(&"hand_r")
	(hand if hand != null else rig).add_child(fingers)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(MeshKit.solid())
	for side: float in [-1.0, 1.0]:
		var tip := Basis(Vector3.BACK, deg_to_rad(FINGER_SPREAD) * side)
		var root: Vector3 = FINGER_ROOT + Vector3(side * 0.011, 0.0, 0.0)
		s.box_xform(Transform3D(tip * Basis.from_scale(Vector3(FINGER_THICK, FINGER_LENGTH, FINGER_THICK)),
			root + tip * Vector3(0.0, -FINGER_LENGTH * 0.5, 0.0)), PlayerSuit.SKIN)
	var mi: MeshInstance3D = MeshBatch.add_instance(fingers, batch.to_mesh(), "Two")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fingers.visible = false


## The screech at `time`: sitting at the runner's feet as they watch the sea; trotting beside them to the bar; sitting
## by the counter; hopping up onto it and sitting there, looking at the bartender, at the runner, up at the ships; then
## down and running beside the runner, and into the pool with them.
func _place_screech(runner: CineActorNode) -> void:
	screech.visible = runner.visible or time < n.run_at
	var r: Vector3 = runner.track_position
	var yaw: float = runner.yaw
	var ground: Vector3 = stand_point + SCREECH_GROUND
	var perch: Vector3 = at_bar(Vector3(-PERCH_IN, bar.counter_top, n.perch_along))
	var hop_end: float = n.hop_at + n.hop_seconds
	var pos: Vector3
	var heading: float
	if time < n.walk_at:
		heading = deg_to_rad(_yaw_to(watch_point, burst_point))
		pos = watch_point + _right(heading) * SCREECH_SIDE + _forward(heading) * 0.15
		_sit_looking(_shark_look(pos, heading), 0.15, 0.0)
	elif time < t_arrive:
		heading = yaw
		pos = r + _right(yaw) * SCREECH_SIDE - _forward(yaw) * SCREECH_BACK
		screech.run(0.0)
	elif time < n.hop_at:
		# Sat down by the counter, facing it; looking up at the bar top.
		var settle: float = smoothstep(t_arrive, t_arrive + 0.5, time)
		var from: Vector3 = stand_point + _right(deg_to_rad(_yaw_to(watch_point, stand_point))) * SCREECH_SIDE
		pos = from.lerp(ground, settle)
		heading = deg_to_rad(90.0)
		_sit_looking(0.0, 0.5, 0.0)
		if settle < 1.0:
			screech.run(0.0)
	elif time < hop_end:
		var u: float = (time - n.hop_at) / maxf(n.hop_seconds, 0.05)
		pos = ground.lerp(perch, u) + Vector3(0.0, 4.0 * n.hop_height * u * (1.0 - u), 0.0)
		heading = deg_to_rad(_yaw_to(ground, perch))
		screech.run(0.6)
	elif time < n.run_at:
		pos = perch
		heading = deg_to_rad(90.0)
		_sit_looking(_perch_look(), _perch_tip(), _perch_nod())
	elif time < n.run_at + HOP_DOWN:
		var u2: float = (time - n.run_at) / HOP_DOWN
		var land: Vector3 = r + _right(yaw) * SCREECH_SIDE
		pos = perch.lerp(Vector3(land.x, 0.0, land.z), u2) + Vector3(0.0, 0.5 * u2 * (1.0 - u2) * 4.0 * 0.4, 0.0)
		heading = yaw
		screech.run(1.0)
	else:
		heading = yaw
		pos = r + _right(yaw) * SCREECH_SIDE + _forward(yaw) * 0.2
		screech.run(1.0)
		if r.y < water_y - 0.4:
			screech.visible = false
	if in_palace:
		screech.visible = false
	screech.global_transform = Transform3D(Basis(Vector3.UP, heading), stage.point(pos))


## Its head turned `yaw` (+ left) and tipped up `tip` (radians), nodding by `nod`.
func _sit_looking(yaw: float, tip: float, nod: float) -> void:
	screech.sit(time, yaw, tip, nod)


## On the counter, facing the bartender: it looks at him, round at the runner as they hold up two fingers, back, then
## up at the ships.
func _perch_look() -> float:
	var at_runner: float = smoothstep(n.fingers_at - 0.2, n.fingers_at + 0.2, time) \
		* (1.0 - smoothstep(n.fingers_at + n.fingers_seconds, n.fingers_at + n.fingers_seconds + 0.4, time))
	var up: float = smoothstep(n.look_up_at - 0.1, n.look_up_at + 0.3, time)
	return lerpf(deg_to_rad(-12.0), deg_to_rad(-70.0), at_runner) * (1.0 - up) + deg_to_rad(25.0) * up


func _perch_tip() -> float:
	return lerpf(0.12, 0.9, smoothstep(n.look_up_at - 0.1, n.look_up_at + 0.3, time))


## A nod as the drinks are ordered (it's in on it).
func _perch_nod() -> float:
	var u: float = (time - (n.fingers_at + 0.5)) / 0.6
	return sin(PI * u) if u > 0.0 and u < 1.0 else 0.0


## Its head following Mecha Guppy out to sea, from where it sits at `pos` facing `heading`.
func _shark_look(pos: Vector3, heading: float) -> float:
	var pose: Array = shark_pose(clampf(time, n.breach_at, n.breach_at + n.breach_seconds + n.fin_seconds))
	var to: Vector3 = (pose[0] as Vector3) - pos
	var want: float = atan2(-to.x, to.z)
	return clampf(angle_difference(heading, want), -1.2, 1.2)


## The way a heading (radians: 0 down the track, + left) faces, and its right, in track space.
static func _forward(heading: float) -> Vector3:
	return Vector3(-sin(heading), 0.0, cos(heading))


static func _right(heading: float) -> Vector3:
	return Vector3(cos(heading), 0.0, sin(heading))


## A splash where the runner, and the screech, go into the pool's water (the Beach's own, BeachSplash).
func _splashes(runner: CineActorNode) -> void:
	var r: Vector3 = runner.track_position
	if time < n.jump_at or splashed.has("runner"):
		return
	if r.y <= water_y:
		splashed["runner"] = true
		for p: Vector3 in [r, r + _right(runner.yaw) * SCREECH_SIDE]:
			var splash := BeachSplash.new()
			stage.add_child(splash)
			splash.global_position = stage.point(Vector3(p.x, water_y, p.z))


## The fire filling the picture as the runner goes in (a fade to its colour; slower and darker with Reduced
## flashing), then black. Worked out from the time.
func _fill_fire() -> void:
	if overlay == null or time < n.fire_at:
		return
	var soft: bool = Settings.flashing_reduced
	var rise: float = n.fire_seconds * (SOFT_FIRE_SLOW if soft else 1.0)
	var fire: Color = n.fire_color.darkened(SOFT_FIRE_DARK) if soft else n.fire_color
	var a: float = smoothstep(n.fire_at, n.fire_at + rise, time)
	var out: float = smoothstep(n.fire_at + rise + 0.1, n.fire_at + rise + 0.1 + n.black_seconds, time)
	_fire_color = Color(fire.lerp(Color.BLACK, out), a)
	overlay.fade_rect.color = _fire_color


## Draw calls its props add now (each visible mesh's surfaces): tests.
func props_draw_calls() -> int:
	var count: int = 0
	for root: Node in [bar, screech, shark, palace, raid, fingers]:
		if root == null:
			continue
		for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
			var g := node as GeometryInstance3D
			if g == null or not g.is_visible_in_tree():
				continue
			if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
				count += (g as MeshInstance3D).mesh.get_surface_count()
			elif g is MultiMeshInstance3D:
				count += 1
	return count
