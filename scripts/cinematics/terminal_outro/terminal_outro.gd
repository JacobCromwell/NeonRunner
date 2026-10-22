class_name TerminalOutro
extends CinematicSequencer
## The Terminal's outro, after Terminal 2 (the owner's beats, October 21, 2026; GDD §6 Cinematics, "Terminal outro"; the
## Terminal has no boss), leading into the Golden Zone:
## 1. The runner jogs down the tunnel and eases to a stop: ahead in the haze stands an abandoned metro train, dark
##    (TerminalTrainModel: modern, dirty and run down, not a steam train). They look up at it.
## 2. The camera pans along the whole length of the train, car after car: grimy, but intact, its doors shut, its
##    windows whole, its pantographs folded: it looks still in working order.
## 3. At its front door: they walk up and grip the handle, shake the door once (it stays firm), pause, shake it violently
##    (the door rattling and clattering loudly, the body heaving; it still won't open), bang on it with a fist, and throw
##    their hands up in frustration (CinePoses.hands_up).
## 4. On the other side of the door's window the runner's friendly screech companion (BeachOutroScreech, the screech
##    of the Gangland and Beach outros) pops up, squeaks, and the door slides open with a hiss; the runner steps up and
##    in, the screech trotting ahead of them; the door closes behind them.
## 5. Behind the train's tail the camera pulls back as its lights come on (headlights, tail lights, the saloon's windows
##    glowing) and it pulls away, accelerating down the tracks and out of sight into the haze.
## A script on the toolkit, its numbers data (`numbers`, by default data/cinematics/terminal_outro_tuning.tres,
## TerminalOutroTuning). It plays on one stretch of the Terminal's own street (the zone's skin, from its data) in the level's
## lanes, the train standing in the lane beside the start lane (the start lane on a street of fewer than four lanes); everything
## is worked out from the time (_on_advance), so stepping or skipping shows the same.
## DESIGN-TBD (docs/questions/f2l.md): the staging the beats leave open, the train's look, the sounds.

const NUMBERS_PATH: String = "res://data/cinematics/terminal_outro_tuning.tres"
## The runner's turn rate (as GanglandOutro's, unhurried).
const TURN_RATE: float = 3.0
## They ease from a jog to a stop over this long (s).
const DECEL_SECONDS: float = 1.4
## The door's closing (s).
const CLOSE_SECONDS: float = 0.9
## A hand's fist is this far beyond the wrist (m): the arm's reach ends there. The hands hold the bar this far apart (m).
const HAND_GRIP: float = 0.05
const HAND_GAP: float = 0.2
## The screech's places (model space, +z into the train): how far in it sits in the vestibule, how far inside the door's
## glass it pops up (m: its head fills the window), and its trot into the saloon (m/s).
const SCREECH_DEPTH: float = 0.55
const POP_DEPTH: float = 0.3
const SCREECH_TROT: float = 1.7
## How far in past the door's sill the runner steps, and how far into the vestibule they walk (metres).
const INSIDE: float = 0.38
## The camera stays this far inside the street's wall line: the Terminal's steel piers stand on and beyond it (a pier
## reaches `pier_depth` out from the wall line, its angle irons 4.5 cm in).
const CAMERA_CLEAR: float = 0.3
const VESTIBULE_STOP: float = 1.4

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: TerminalOutroTuning

var n: TerminalOutroTuning
var train: TerminalTrainModel
var screech: BeachOutroScreech
## Where things are (track space): the train's middle line and where its tail and nose stand, where the runner runs and
## where they stand at the door, and the camera's lane for the pan.
var train_x: float = 0.0
var train_length: float = 0.0
var tail_z: float = 0.0
var nose_z: float = 0.0
var run_x: float = 0.0
var stop_z: float = 0.0
var stand := Vector3.ZERO
var cam_x: float = 0.0
## When the runner is inside and out of sight (the cut to the train leaving).
var t_gone: float = 0.0
## How far the train has moved from where it stood (metres).
var moved: float = 0.0


func _numbers() -> TerminalOutroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as TerminalOutroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	var d := CineStageDef.new()
	d.length = n.stage_length
	return d


func _make_timeline() -> CineTimeline:
	n = _numbers()
	_plan()
	train = TerminalTrainModel.new()
	train.name = "Train"
	stage.add_child(train)
	train.build(n.cars, n.paint, n.stripe, n.grime, n.rust, n.vines, stage.skin)
	train.set_emergency(1.0)
	screech = BeachOutroScreech.new()
	stage.add_child(screech)
	screech.setup_friend(n.screech_size, n.screech_look)
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	_runner(t)
	_camera(t)
	_events(t)
	_on_advance(0.0)
	return t


## Where things are, from the numbers and the street.
func _plan() -> void:
	train_length = TerminalTrainModel.length_of(n.cars)
	var lane: int = stage.start_lane + n.lane_offset
	if stage.geo.lane_count < 4 or lane < 0:
		lane = stage.start_lane
	train_x = stage.lane_x(lane)
	tail_z = n.tail_at
	nose_z = tail_z + train_length
	run_x = minf(train_x + n.run_side, stage.wall_x(1) - 0.8)
	stop_z = tail_z - n.stop_short
	# At the door, on its step plate, the handle (on the left stile) straight in front of them, between their shoulders.
	stand = Vector3(train_x + TerminalTrainModel.handle_point().x, TerminalTrainModel.STEP_TOP, nose_z + n.stand_off)
	cam_x = minf(train_x + TerminalTrainModel.WALL + n.pan_distance, stage.wall_x(1) - CAMERA_CLEAR)
	var walk: float = n.walk_in_speed
	t_gone = n.leave_shot_at
	var in_by: float = n.walk_in_at + (n.stand_off + INSIDE + VESTIBULE_STOP + 0.2) / walk
	if in_by > n.leave_shot_at:
		push_warning("TerminalOutro: the runner is not in the train (%.2f s) by the cut to its leaving (%.2f s)" % [in_by, n.leave_shot_at])


# --- The train ----------------------------------------------------------------------------------------------

## How far the train has moved by `t` (metres): standing until it starts, then accelerating, the acceleration easing in
## over `ramp` (constant jerk), then steady.
func train_distance(t: float) -> float:
	var u: float = t - n.start_at
	if u <= 0.0:
		return 0.0
	var a: float = n.acceleration
	var r: float = maxf(n.ramp, 0.01)
	if u <= r:
		return a * u * u * u / (6.0 * r)
	var s_r: float = a * r * r / 6.0
	var v_r: float = a * r * 0.5
	var e: float = u - r
	return s_r + v_r * e + 0.5 * a * e * e


## Its lights at `t` (0-1): off until `lights_at`, then a failing strip's stutter (a slow glow with Reduced flashing).
func lights_level(t: float, delay: float = 0.0) -> float:
	var u: float = t - n.lights_at - delay
	if u <= 0.0:
		return 0.0
	if Settings.flashing_reduced:
		return smoothstep(0.0, 1.0, u)
	if u < 0.1:
		return 1.0
	if u < 0.2:
		return 0.0
	if u < 0.28:
		return 1.0
	if u < 0.4:
		return 0.12
	return 1.0


## The door's opening at `t` (0 shut, 1 open): open from `open_at`, shut again from `close_at`.
func door_open_at(t: float) -> float:
	var up: float = smoothstep(n.open_at, n.open_at + n.open_seconds, t)
	var down: float = smoothstep(n.close_at, n.close_at + CLOSE_SECONDS, t)
	return up * (1.0 - down)


## The heave on the door at `t`: -1 to 1, + pulling back, away from the door. The first shake is one small tug; the second
## a violent, ragged shaking.
func heave_at(t: float) -> float:
	var h: float = 0.0
	var ua: float = (t - n.shake_a_at) / n.shake_a_seconds
	if ua > 0.0 and ua < 1.0:
		h += 0.55 * sin(PI * ua) - 0.12 * sin(TAU * ua)
	var ub: float = t - n.shake_b_at
	if ub > 0.0 and ub < n.shake_b_seconds:
		var env: float = _window(t, n.shake_b_at, n.shake_b_at + 0.2, n.shake_b_at + n.shake_b_seconds - 0.3,
			n.shake_b_at + n.shake_b_seconds)
		h += env * (sin(TAU * n.shake_b_rate * ub) + 0.4 * sin(TAU * n.shake_b_rate * 1.7 * ub + 1.3))
	return clampf(h, -1.4, 1.4)


## How hard the door is shaken, 0-1 (what makes the leaf rattle): the heave's size.
func door_rattle_at(t: float) -> Vector3:
	var h: float = heave_at(t)
	var amp: float = 0.0
	var ua: float = (t - n.shake_a_at) / n.shake_a_seconds
	if ua > 0.0 and ua < 1.0:
		amp = n.rattle_small * sin(PI * ua)
	var ub: float = t - n.shake_b_at
	if ub > 0.0 and ub < n.shake_b_seconds:
		amp = maxf(amp, n.rattle_big * _window(t, n.shake_b_at, n.shake_b_at + 0.15, n.shake_b_at + n.shake_b_seconds - 0.25,
			n.shake_b_at + n.shake_b_seconds))
	var v := Vector3(sin(TAU * 29.0 * t) * 0.5, sin(TAU * 37.0 * t + 1.0) * 0.25, sin(TAU * 23.0 * t + 0.4)) * amp
	# A bang jolts it.
	for k: int in n.bangs:
		var e: float = t - bang_time(k)
		if e > 0.0 and e < 0.5:
			v += Vector3(0.0, 0.0, 0.016 * exp(-e * 14.0) * sin(TAU * 27.0 * e))
	return v + Vector3(0.0, 0.0, 0.004 * h)


## When the fist lands for bang `k` (s).
func bang_time(k: int) -> float:
	return n.bang_at + n.bang_gap * (float(k) + 0.72)


## When the last bang is over (s).
func bangs_end() -> float:
	return n.bang_at + n.bang_gap * float(n.bangs) + 0.2


func _drive_train() -> void:
	moved = train_distance(time)
	train.global_transform = Transform3D(Basis.IDENTITY, stage.point(Vector3(train_x, 0.0, nose_z + moved)))
	train.set_door(door_open_at(time))
	train.set_rattle(door_rattle_at(time))
	train.set_lights(lights_level(time))
	var saloon: float = lights_level(time, 0.3)
	train.set_interior(saloon)
	train.set_emergency(1.0 - saloon)
	# Out of sight, it's not drawn (the street ends past anything the camera sees).
	train.visible = moved < n.stage_length * 0.9


# --- The screech --------------------------------------------------------------------------------------------

## Where the camera sits for the close shot of the window (track space): on the runner's left (the +x side, as they face the
## door; the handle they hold is on their right, so the line from here to the window, which is on their left, passes clear of
## their head), looking across at it. The door shots before it are from their right (the -x side).
func window_camera() -> Vector3:
	return _in_street(Vector3(train_x + 2.1, 1.5, nose_z + 2.1))


## A camera position kept inside the street (CAMERA_CLEAR in from its wall lines, clear of the Terminal's piers beyond them).
func _in_street(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, stage.wall_x(-1) + CAMERA_CLEAR, stage.wall_x(1) - CAMERA_CLEAR), p.y, p.z)


## A camera key at a track-space position kept inside the street.
func _shot(t: CineTimeline, at: float, position: Vector3, target: Vector3, move: CinePath.Move = CinePath.Move.SMOOTH,
		fov: float = 70.0) -> CineCameraKey:
	return t.shot(at, _in_street(position), target, move, fov)


## The screech's hop up at the window: 0 hidden (below the door's lower panel), 1 in the window; it springs up, hovers a
## little, bobbing, and drops out of sight.
func pop_at(t: float) -> float:
	var u: float = t - n.pop_at
	if u < 0.0 or u > n.pop_seconds:
		return 0.0
	var up: float = 1.0 - pow(1.0 - clampf(u / 0.28, 0.0, 1.0), 2.0)
	var down: float = smoothstep(n.pop_seconds - 0.38, n.pop_seconds, u)
	var bob: float = 0.05 * sin(TAU * 2.4 * u) * smoothstep(0.28, 0.5, u)
	return clampf(up * (1.0 - down) + bob * (1.0 - down), 0.0, 1.1)


func _place_screech() -> void:
	if screech == null:
		return
	var model_to_world: Transform3D = train.global_transform
	var popping: bool = time >= n.pop_at and time < n.pop_at + n.pop_seconds
	var trot_at: float = n.walk_in_at - 0.25
	var trotting: bool = time >= trot_at
	var floor_point: Vector3 = TerminalTrainModel.vestibule_point(SCREECH_DEPTH)
	if time < n.pop_at:
		screech.visible = false
		return
	if popping:
		# Hopping up in the window: its head in it, facing the camera, tilting curiously, nodding as it squeaks.
		var u: float = time - n.pop_at
		var hop: float = pop_at(time)
		screech.visible = true
		var yaw: float = 0.35 * sin(TAU * 0.9 * u) * smoothstep(0.2, 0.5, u)
		var nod: float = sin(PI * clampf((time - n.squeak_at) / 0.45, 0.0, 1.0))
		screech.sit(time, yaw, 0.12, nod)
		var cam: Vector3 = model_to_world.affine_inverse() * stage.point(window_camera())
		var window: Vector3 = TerminalTrainModel.window_point()
		# Where the camera's line through the window's middle passes at its depth: that's where it shows in the window.
		var depth: float = TerminalTrainModel.vestibule_point(POP_DEPTH).z
		var s: float = (depth - window.z) / (window.z - cam.z)
		var x: float = window.x + (window.x - cam.x) * s
		var at := Vector3(x, floor_point.y + n.pop_height * hop - (1.0 - hop) * 0.3, depth)
		var face: float = atan2(-(cam.x - at.x), -(cam.z - at.z))
		screech.global_transform = Transform3D(Basis(Vector3.UP, face), model_to_world * at)
		return
	if not trotting:
		# Sitting inside by the door as it slides open, looking round at the runner.
		screech.visible = time < n.leave_shot_at
		var look: float = smoothstep(n.open_at, n.open_at + 0.6, time)
		screech.sit(time, 0.5 * look, 0.05, 0.0)
		screech.global_transform = Transform3D(Basis.IDENTITY, model_to_world * floor_point)
		return
	# Trotting in ahead of the runner, into the dark saloon.
	var along: float = (time - trot_at) * SCREECH_TROT
	var z: float = floor_point.z + along
	var doorway_z: float = TerminalTrainModel.VESTIBULE_DEPTH
	screech.visible = z < doorway_z + 1.4 and time < n.leave_shot_at
	screech.run(0.25)
	# It turns round to face in over the first stride.
	var turn: float = smoothstep(0.0, 0.35, time - trot_at)
	var basis := Basis(Vector3.UP, PI * turn)
	screech.global_transform = Transform3D(basis, model_to_world * Vector3(floor_point.x, floor_point.y, z))


# --- The runner ---------------------------------------------------------------------------------------------

func _runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	r.turn_rate = TURN_RATE
	# Jogging in down the street beside the train, easing to a stop short of its tail.
	var v: float = n.run_speed
	var t_a: float = n.stop_at - DECEL_SECONDS
	var z_a: float = stop_z - 0.5 * v * DECEL_SECONDS
	var z0: float = z_a - v * t_a
	var jog := Vector3(run_x, 0.0, z0)
	r.at(0.0, jog, &"run")
	r.at(t_a, Vector3(run_x, 0.0, z_a))
	var stopped := Vector3(run_x, 0.0, stop_z)
	GanglandOutro._eased(r.at(n.stop_at, stopped), Tween.TRANS_QUAD, Tween.EASE_OUT)
	# They look up at it, along it: their head turning toward it (it is on their left) and tipping up.
	var k: CineActorKey = r.at(n.stop_at + 0.5, stopped)
	k.look = 10.0
	k.look_up = 8.0
	k = r.at(n.look_shot_at + 0.4, stopped)
	k.look = 24.0
	k.look_up = 15.0
	k = r.at(n.pan_shot_at - 0.3, stopped)
	k.look = 34.0
	k.look_up = 12.0
	# Cut: walking up to the front door and onto its step plate.
	var dir := Vector3(-0.38, 0.0, 0.93)
	var ground := Vector3(stand.x, 0.0, stand.z)
	var walk_from: Vector3 = ground + dir * (n.walk_speed * (n.arrive_at - n.door_shot_at))
	r.at(n.door_shot_at, walk_from, &"walk", CinePath.Move.CUT)
	var near: Vector3 = ground + dir * 0.55
	GanglandOutro._turned(r.at(n.arrive_at - 0.5, near), 180.0, 0.0)
	# The step up onto the plate's front edge (their feet clear it as it comes under them).
	var onto := Vector3(ground.x + dir.x * 0.27, TerminalTrainModel.STEP_TOP, ground.z + dir.z * 0.27)
	GanglandOutro._turned(r.at(n.arrive_at - 0.245, onto), 180.0, 0.0)
	GanglandOutro._turned(GanglandOutro._eased(r.at(n.arrive_at, stand, &"walk"), Tween.TRANS_QUAD, Tween.EASE_OUT), 180.0, 0.0).look_up = 6.0
	# Bracing against the door: gripping the handle, the small shake, the pause, the violent one, the bangs.
	var brace: Array = [
		[n.shake_a_at - 0.45, 0.0], [n.shake_a_at - 0.05, 0.7], [n.shake_b_at - 0.3, 0.6], [n.shake_b_at, 0.9],
		[n.shake_b_at + n.shake_b_seconds, 0.9], [n.bang_at - 0.15, 0.55], [bangs_end(), 0.55],
		[n.hands_up_at - 0.3, 0.0]]
	for i: int in brace.size():
		var key: CineActorKey = GanglandOutro._turned(r.at(float(brace[i][0]), stand, &"brace" if i == 0 else &""), 180.0, 0.0)
		key.progress = float(brace[i][1])
		key.look_up = 10.0
	# Hands up in frustration, held, slumping; staring at the window as the screech pops up in it.
	var up: Array = [[0.0, 0.0], [0.5, 0.35], [1.4, 0.6], [1.75, 0.85], [2.15, 1.0]]
	var pace: float = n.hands_up_seconds / 2.15
	for i: int in up.size():
		var at: float = n.hands_up_at + float(up[i][0]) * pace
		var key: CineActorKey = GanglandOutro._turned(r.at(at, stand, &"hands_up" if i == 0 else &""), 180.0, 0.0)
		key.progress = float(up[i][1])
		var raise: float = smoothstep(n.pop_at - 0.2, n.pop_at + 0.3, at)
		key.look_up = lerpf(4.0, 22.0, raise)
	# The door opens: they step up from the plate onto the riser and over the sill into the cab (each step up a key: the
	# feet clear the riser and the sill), and walk toward the doorway behind the screech.
	var s: float = n.walk_in_speed
	var riser_p := Vector3(train_x - 0.1, TerminalTrainModel.RISER_TOP, nose_z + 0.24)
	var sill_p := Vector3(train_x - 0.03, TerminalTrainModel.FLOOR, nose_z + 0.04)
	var in_p := Vector3(train_x, TerminalTrainModel.FLOOR, nose_z - INSIDE)
	var vest_p := Vector3(train_x, TerminalTrainModel.FLOOR, nose_z - INSIDE - VESTIBULE_STOP)
	var t0: float = n.walk_in_at
	var wait: CineActorKey = GanglandOutro._turned(r.at(t0, stand, &"walk"), 180.0, 0.0)
	wait.look_up = 8.0
	var t1: float = t0 + stand.distance_to(riser_p) / s
	r.at(t1, riser_p)
	var t2: float = t1 + riser_p.distance_to(sill_p) / s
	r.at(t2, sill_p)
	var t3: float = t2 + sill_p.distance_to(in_p) / s
	r.at(t3, in_p)
	var t4: float = t3 + Vector2(vest_p.x - in_p.x, vest_p.z - in_p.z).length() / s
	r.at(t4, vest_p)
	r.at(t_gone, vest_p)
	r.leave = t_gone


# --- The camera ---------------------------------------------------------------------------------------------

func _camera(t: CineTimeline) -> void:
	# Behind the runner as they jog in, low, the train looming ahead of them in the haze, closing in as they slow.
	var toward := Vector3(train_x - run_x + 0.4, 1.7, 14.0)
	# (The camera rides to the runner's side by 1.5 m, less on a street too narrow to leave it that.)
	var off: float = minf(1.5, stage.wall_x(1) - CAMERA_CLEAR - run_x)
	var c0: CineCameraKey = t.shot(0.0, Vector3(off, 1.35, -5.4), toward, CinePath.Move.SMOOTH, 66.0)
	c0.follow = &"runner"
	c0.watch = &"runner"
	var c1: CineCameraKey = t.shot(n.look_shot_at - 0.004, Vector3(minf(off, 1.1), 1.25, -4.0), toward + Vector3(0.0, 0.2, 0.0),
		CinePath.Move.SMOOTH, 62.0)
	c1.follow = &"runner"
	c1.watch = &"runner"
	# Cut: from the runner's right, low and back, the runner on the left of the picture looking up at the train's tail
	# on its right.
	var side_x: float = minf(run_x + 4.4, stage.wall_x(1) - CAMERA_CLEAR)
	_shot(t, n.look_shot_at, Vector3(side_x, 1.3, stop_z - 6.4), Vector3(run_x - 2.0, 1.8, stop_z + 5.0), CinePath.Move.CUT, 56.0)
	_shot(t, n.pan_shot_at - 0.004, Vector3(side_x - 0.3, 1.35, stop_z - 5.6), Vector3(run_x - 2.2, 1.9, stop_z + 5.6),
		CinePath.Move.SMOOTH, 52.0)
	# Cut: the pan, in a long move along the train's side from its tail to its nose, its target leading the camera.
	var gap: float = cam_x - (train_x + TerminalTrainModel.WALL)
	var fov: float = clampf(rad_to_deg(2.0 * atan(2.4 / maxf(gap, 0.5))), 44.0, 74.0)
	var y: float = n.pan_height
	var span: float = nose_z - tail_z
	var pan_t: float = n.door_shot_at - n.pan_shot_at
	var keys: Array = [[0.0, tail_z - 5.5, 0.0, 1.0], [0.28, tail_z + span * 0.2, 6.0, 1.15], [0.62, tail_z + span * 0.55, 9.0, 1.25],
		[1.0, nose_z - 6.5, 7.0, 1.4]]
	for i: int in keys.size():
		var at: float = n.pan_shot_at + pan_t * float(keys[i][0]) - (0.004 if i == keys.size() - 1 else 0.0)
		var z: float = float(keys[i][1])
		var lead: float = float(keys[i][2])
		var rise: float = float(keys[i][3])
		_shot(t, at, Vector3(cam_x, y * rise, z), Vector3(train_x + 0.2, 1.7 + 0.3 * rise, z + lead),
			CinePath.Move.CUT if i == 0 else CinePath.Move.SMOOTH, fov + 4.0 * (1.0 - float(i) / float(keys.size())))
	# Cut: the front door, from behind and to the right of the runner as they walk up and grip it; closer for the violent
	# shaking; a close three-quarter view from their right as they bang on it (the fist, the door's face) and throw up their
	# hands.
	var door_c := Vector3(train_x - 0.1, 1.3, nose_z)
	_shot(t, n.door_shot_at, Vector3(train_x - 2.8, 1.15, nose_z + 3.7), door_c, CinePath.Move.CUT, 50.0)
	_shot(t, n.shake_b_at - 0.4, Vector3(train_x - 2.4, 1.2, nose_z + 2.6), door_c, CinePath.Move.SMOOTH, 46.0)
	var medium := Vector3(train_x - 0.35, 1.3, nose_z + 0.2)
	_shot(t, n.shake_b_at - 0.396, Vector3(train_x - 2.4, 1.4, nose_z + 1.3), medium, CinePath.Move.CUT, 46.0)
	_shot(t, n.bang_at - 0.5, Vector3(train_x - 2.25, 1.35, nose_z + 1.1), medium, CinePath.Move.SMOOTH, 44.0)
	var fist := Vector3(train_x - 0.45, 1.2, nose_z + 0.15)
	_shot(t, n.bang_at - 0.496, Vector3(train_x - 2.1, 1.3, nose_z + 0.9), fist, CinePath.Move.CUT, 42.0)
	_shot(t, n.window_shot_at - 0.004, Vector3(train_x - 2.0, 1.3, nose_z + 0.8), fist + Vector3(0.0, 0.1, 0.0), CinePath.Move.SMOOTH, 42.0)
	# Cut: close on the window as the screech pops up in it, over the runner's raised hands; then wider as the door slides
	# open and the runner, following the screech, goes in.
	var window := Vector3(train_x + 0.02, 1.45, nose_z)
	_shot(t, n.window_shot_at, window_camera(), window, CinePath.Move.CUT, 33.0)
	_shot(t, n.open_at - 0.2, window_camera() + Vector3(0.1, -0.05, 0.1), window, CinePath.Move.SMOOTH, 35.0)
	_shot(t, n.walk_in_at + 0.4, Vector3(train_x + 1.9, 1.35, nose_z + 3.0), Vector3(train_x - 0.1, 1.15, nose_z - 0.3),
		CinePath.Move.SMOOTH, 48.0)
	_shot(t, n.leave_shot_at - 0.004, Vector3(train_x + 2.4, 1.5, nose_z + 3.4), Vector3(train_x - 0.1, 1.1, nose_z - 0.6),
		CinePath.Move.SMOOTH, 52.0)
	# Cut: behind the train's tail, low; it pulls back and rises as the train pulls away down the street and out of sight.
	var tx: float = train_x + 0.9
	var look_far := Vector3(train_x, 1.9, tail_z + 30.0)
	_shot(t, n.leave_shot_at, Vector3(tx, 1.15, tail_z - 5.5), look_far, CinePath.Move.CUT, 60.0)
	var mid: float = (n.leave_shot_at + n.duration) * 0.5
	_shot(t, mid, Vector3(tx + 0.6, 1.4 + n.pull_up * 0.35, tail_z - 5.5 - n.pull_back * 0.45), Vector3(train_x, 2.1, tail_z + 60.0),
		CinePath.Move.SMOOTH, 56.0)
	_shot(t, n.duration, Vector3(tx + 1.2, 1.4 + n.pull_up, tail_z - 5.5 - n.pull_back), Vector3(train_x, 2.4, tail_z + 150.0),
		CinePath.Move.SMOOTH, 52.0)


## The street stays built back far enough for the shots looking down it from behind the train's tail and for the pan.
func _stage_near(near: float) -> float:
	return minf(near, tail_z - 12.0 - n.pull_back)


# --- Sounds, effects and cues ----------------------------------------------------------------------------------

func _events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, n.music_fade)
	# The first shake: one firm rattle. The second: a loud clattering of the loose door in its frame. The bangs.
	t.sound(n.shake_a_at + 0.08, &"door_rattle")
	t.sound(n.shake_b_at, &"door_rattle_hard")
	t.effect(n.shake_b_at, CineEvent.SHAKE, n.shake_b_seconds, n.camera_shake)
	for k: int in n.bangs:
		t.sound(bang_time(k), &"door_bang", -1.0 * float(k))
	t.sound(n.squeak_at, &"screech_squeak")
	t.sound(n.open_at, &"train_door_open")
	t.sound(n.close_at, &"train_door_close")
	# Its lights come on and it starts: the relays, the motors spinning up, then the roar of it pulling away.
	t.sound(n.lights_at, &"train_start")
	t.sound(n.start_at + 0.5, &"train_depart")
	t.sound(n.start_at + 2.7, &"train_rush", -2.0)
	t.effect(n.fade_at, CineEvent.FADE_OUT, n.fade_out)


# --- On the clock ------------------------------------------------------------------------------------------------

func _on_advance(_delta: float) -> void:
	if n == null or train == null:
		return
	_drive_train()
	_place_screech()
	var runner := actors.get(&"runner") as CineActorNode
	if runner != null and runner.avatar != null and runner.visible:
		_pose_runner(runner)


## Over (played out or skipped): its props hidden.
func _finish() -> void:
	if not done:
		for node: Node3D in [train, screech]:
			if node != null:
				node.visible = false
	super()


## How much the runner grips the door's handle at `t` (0-1): reaching for it just before the first shake, holding through
## the shaking, letting go for the bangs.
func grip_at(t: float) -> float:
	return _window(t, n.shake_a_at - 0.4, n.shake_a_at - 0.05, n.shake_b_at + n.shake_b_seconds, n.shake_b_at + n.shake_b_seconds + 0.3)


## How much the runner bangs on the door at `t` (0-1).
func bang_at(t: float) -> float:
	return _window(t, n.bang_at - 0.3, n.bang_at, bangs_end() - 0.05, bangs_end() + 0.25)


## The runner's arms and body on top of their pose: both hands on the handle through the shaking, the body heaving; a fist
## bangs, the other hand flat on the door.
func _pose_runner(runner: CineActorNode) -> void:
	var rig: HumanoidRig = runner.avatar.rig
	var door: Transform3D = train.global_transform * Transform3D(Basis.IDENTITY, train.door_node.position)
	var grip: float = grip_at(time)
	var bang: float = bang_at(time)
	var h: float = heave_at(time)
	# The body heaves back and forth along the door's axis (back is +z along the track = -z world).
	var back: float = 0.07 * h * grip
	runner.avatar.position = Vector3(0.0, 0.0, -back)
	var chest: Node3D = rig.joint(&"chest")
	if chest != null and grip > 0.0:
		chest.rotate_object_local(Vector3.RIGHT, 0.26 * h * grip)
		chest.rotate_object_local(Vector3.UP, 0.1 * sin(TAU * 3.1 * time) * absf(h) * grip)
	# The runner faces the train: their right hand is on the train's left (-x), their elbows down, out and back.
	var left_pole := Vector3(0.5, -1.0, -0.3)
	var right_pole := Vector3(-0.5, -1.0, -0.3)
	if grip > 0.0:
		# Both hands on the bar, one above the other.
		var handle: Vector3 = TerminalTrainModel.handle_point()
		reach_arm(rig, &"r", door * (handle + Vector3(0.0, HAND_GAP * 0.5, 0.0)), grip, right_pole)
		reach_arm(rig, &"l", door * (handle - Vector3(0.0, HAND_GAP * 0.5, 0.0)), grip, left_pole)
	if bang > 0.0:
		# The left hand flat on the door, the right fist drawn back and thrown at it, again and again.
		var handle_x: float = TerminalTrainModel.handle_point().x
		var panel: Vector3 = TerminalTrainModel.panel_point(0.95, handle_x + 0.38)
		reach_arm(rig, &"l", door * (panel + Vector3(0.0, 0.1, -0.025)), bang, left_pole)
		var u: float = fposmod((time - n.bang_at) / n.bang_gap, 1.0)
		var cock: float = smoothstep(0.0, 0.62, u) * (1.0 - smoothstep(0.62, 0.72, u))
		var fist: Vector3 = TerminalTrainModel.panel_point(0.9 + 0.18 * cock, handle_x + 0.08) + Vector3(0.0, 0.0, -0.03 - 0.26 * cock)
		reach_arm(rig, &"r", door * fist, bang, right_pole)
		runner.avatar.position += Vector3(0.0, 0.0, 0.02 * cock * bang)
		if chest != null:
			chest.rotate_object_local(Vector3.RIGHT, 0.1 * (cock - 0.5) * bang)


## Reaches an arm (`side` &"l" or &"r") so its hand is at `target` (world space), by `k` (0-1): two-bone, the upper arm
## and forearm lengths the rig's own, the elbow bending toward `pole` (a direction in world space). Out of reach it
## straightens toward the target. The arm hangs along -y at rest (the forearm bends about its x, + forward).
static func reach_arm(rig: HumanoidRig, side: StringName, target: Vector3, k: float, pole: Vector3) -> void:
	var upper: Node3D = rig.joint(StringName("upper_arm_%s" % side))
	var fore: Node3D = rig.joint(StringName("forearm_%s" % side))
	var hand: Node3D = rig.joint(StringName("hand_%s" % side))
	if upper == null or fore == null or hand == null or k <= 0.0:
		return
	var parent := upper.get_parent() as Node3D
	var shoulder: Vector3 = upper.global_position
	var a: float = shoulder.distance_to(fore.global_position)
	var b: float = fore.global_position.distance_to(hand.global_position) + HAND_GRIP
	var to: Vector3 = target - shoulder
	if to.length_squared() < 0.0001:
		return
	var d: float = clampf(to.length(), absf(a - b) + 0.01, a + b - 0.004)
	var dir: Vector3 = to.normalized()
	var alpha: float = acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var bend: float = PI - acos(clampf((a * a + b * b - d * d) / (2.0 * a * b), -1.0, 1.0))
	var side_pole: Vector3 = pole - dir * pole.dot(dir)
	side_pole = side_pole.normalized() if side_pole.length() > 0.001 else Vector3.DOWN
	var u: Vector3 = dir * cos(alpha) + side_pole * sin(alpha)
	var elbow: Vector3 = shoulder + u * a
	var f: Vector3 = (shoulder + dir * d - elbow).normalized()
	var to_local: Basis = parent.global_basis.inverse()
	var u_local: Vector3 = (to_local * u).normalized()
	var f_local: Vector3 = (to_local * f).normalized()
	var q := Quaternion(Vector3.DOWN, u_local)
	# Twisted about the upper arm so that the forearm, bent `bend` about its own x, points along f.
	var flexed: Vector3 = q * (Quaternion(Vector3.RIGHT, bend) * Vector3.DOWN)
	var from_p: Vector3 = flexed - u_local * flexed.dot(u_local)
	var to_p: Vector3 = f_local - u_local * f_local.dot(u_local)
	if from_p.length() > 0.0001 and to_p.length() > 0.0001:
		q = Quaternion(u_local, from_p.normalized().signed_angle_to(to_p.normalized(), u_local)) * q
	upper.quaternion = upper.quaternion.slerp(q, clampf(k, 0.0, 1.0))
	fore.quaternion = fore.quaternion.slerp(Quaternion(Vector3.RIGHT, bend), clampf(k, 0.0, 1.0))


## 0 before `a`, rising to 1 by `b`, 1 until `c`, falling to 0 by `d` (eased in and out).
static func _window(t: float, a: float, b: float, c: float, d: float) -> float:
	return GanglandOutro._window(t, a, b, c, d)


## Draw calls its props add now (the train and the screech on its meshes).
func props_draw_calls() -> int:
	var calls: int = 0
	if train != null and train.is_visible_in_tree():
		calls += train.draw_call_count()
	if screech != null and screech.is_visible_in_tree():
		for mi: Node in screech.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.is_visible_in_tree() and m.mesh != null:
				calls += m.mesh.get_surface_count()
	return calls
