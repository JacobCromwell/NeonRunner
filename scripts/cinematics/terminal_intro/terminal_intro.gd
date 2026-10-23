class_name TerminalIntro
extends CinematicSequencer
## The Terminal's intro, before Terminal 1 (the owner's beats, October 21, 2026; GDD §6 Cinematics, "Terminal intro"; the Terminal's
## look from the owner's reference image, docs/art/reference/terminal_zone.jpg):
## 1. The runner's face as they survey the land around them, their head turning; the camera sweeps round them and pans over
##    the scene in front of them: the Dead Zone's wasteland (its rubble ground, broken columns, rubble heaps, burned-out bus,
##    smoke, sky and greys) with the outside of the large Grand Terminal Station in it (TerminalIntroStation), abandoned and
##    decayed: "GRAND" has fallen off its front, the letters of "TERMINAL" droop and are sparsely lit, a few sparking and
##    flashing a little (TerminalIntroLetters); light comes out of the station throughout, so we see why it caught their eye.
## 2. The runner walks quickly up to the route board by the entrance and wipes it with their hand (CinePoses' `wipe`,
##    TerminalIntroSign); cut to a close-up of the board: a list of stops, one in gold, THE PALACE.
## 3. They make up their mind (a nod, a turn to the entrance). The entrance is blocked by rubble with a crack of light at the
##    top (TerminalIntroHeap); they climb the rubble on hands and knees (`crawl`) and squeeze in through the gap (`squeeze`).
## 4. Inside (the Terminal's own look, a cut to another stage under black: switch_stage): they come out over the rubble and
##    jump down to the ground, and the first level's layout is ahead: the tracks running off into the distance, platforms,
##    arches, lamps (TerminalIntroEntry); the zone's title card, and black.
## A script on the toolkit, its numbers data (`numbers`, by default data/cinematics/terminal_intro_tuning.tres,
## TerminalIntroTuning). Outside it plays on one stretch of the Dead Zone's street (the stage def's skin) in the level's
## lanes, the station in an opening of the left wall; everything is worked out from the time (_on_advance), so stepping or
## skipping shows the same. DESIGN-TBD (docs/OPEN_QUESTIONS_DEFERRED.md items 1102-1115): the staging the beats leave open.

const NUMBERS_PATH: String = "res://data/cinematics/terminal_intro_tuning.tres"
## Outside is the Dead Zone's look (the zone's own skin is the Terminal's, for inside).
const OUTSIDE_SKIN_PATH: String = "res://data/skins/dead_zone_skin.tres"
## The runner's turn rate (as the other intros', unhurried).
const TURN_RATE: float = 3.0
## The wipe's hand path is measured at this many steps of its progress; the runner's keys come this often through it.
const WIPE_SAMPLES: int = 48
const KEY_STEP: float = 0.05
## The runner's cut to where they have got to on the walk is this long before the cut to the shot that follows them (s).
const CUT_LEAD: float = 0.1
## How far the hand's palm is held off the board's grime (metres), so it never goes into it.
const HAND_OFF: float = 0.03
## How many points the way up the heap is measured at (for the crawl's even pace and the slope under it).
const CRAWL_PATH_POINTS: int = 120
## The runner's own height when it lies on the heap's crest, over the surface (metres): its body is prone there.
const CREST_LIFT: float = 0.04
## The runner's eye line (metres): the face shot looks at it.
const EYE_HEIGHT: float = 1.13
## The shortest time between two sign zaps (seconds): most of a zap (1.0 s) is heard before the next one restarts it.
# DESIGN-TBD (docs/OPEN_QUESTIONS_DEFERRED.md item 1212): the zap's length and spacing.
const ZAP_GAP: float = 0.7

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: TerminalIntroTuning

var n: TerminalIntroTuning
var station: TerminalIntroStation
var letters: TerminalIntroLetters
var waste: TerminalIntroWaste
var board: TerminalIntroSign
var entry: TerminalIntroEntry
## True once it has cut inside (the Terminal's own stage).
var inside: bool = false
## The wall inside (track x of its face) and when the runner lands there.
var inside_wall_x: float = 0.0
var t_land: float = 0.0
## The wipe pose's hand offsets from the runner (right, up, forward; metres), at each of WIPE_SAMPLES + 1 steps of its
## progress, measured from the real rig (_measure_wipe).
var wipe_hand: Array[Vector3] = []
## When the wipe starts and ends, the walk to it starts, and the runner's place at its start (station frame).
var t_walk: float = 0.0
var t_wipe_end: float = 0.0
var t_corner: float = 0.0
var stand: Vector3 = Vector3.ZERO
## The street's right wall's x in the station's frame: the camera keeps inside it.
var street_edge: float = 0.0


func _numbers() -> TerminalIntroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as TerminalIntroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	var d := CineStageDef.new()
	d.skin = load(OUTSIDE_SKIN_PATH) as ZoneSkin
	d.length = n.stage_length
	d.wall_gaps = PackedVector3Array([Vector3(-1.0, n.station_at - n.frontage * 0.5, n.station_at + n.frontage * 0.5)])
	return d


func _make_timeline() -> CineTimeline:
	n = _numbers()
	_measure_wipe()
	var wipe_mid: float = _wipe_height()
	station = TerminalIntroStation.new()
	stage.add_child(station)
	# The runner's route on foot (the street's side of the heap to the board and back) stays clear of the heap's slabs and chunks.
	station.clear_paths = [PackedVector2Array([n.start_at, n.walk_corner, Vector2(n.board_x, 0.9)])]
	station.setup(stage.skin, n, stage.wall_x(-1) - n.forecourt, n.station_at, stage)
	street_edge = stage.wall_x(1) - station.front_x - 0.9
	inside_wall_x = stage.wall_x(-1) - n.inside_wall_back
	letters = TerminalIntroLetters.new()
	station.add_child(letters)
	letters.setup(station, n)
	waste = TerminalIntroWaste.new()
	station.add_child(waste)
	waste.setup(station, n, tuning)
	board = TerminalIntroSign.new()
	station.add_child(board)
	board.setup(station, n, n.board_x, wipe_mid)
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	_runner(t)
	_wipe_trail()
	_camera(t)
	_events(t)
	_on_advance(0.0)
	return t


# --- Frames ------------------------------------------------------------------------------------------------------

## A point of the station's frame (x along its front, y up, z out) in track space.
func st(x: float, y: float, z: float) -> Vector3:
	return station.track(Vector3(x, y, z))


## A runner's yaw (degrees, 0 along the front to the viewer's right, + turning left toward the front) for the direction
## (dx along the front, dz out from it).
static func yaw_to(dx: float, dz: float) -> float:
	return rad_to_deg(TerminalIntroStation.heading(dx, dz))


# --- The wipe's hand ---------------------------------------------------------------------------------------------

## Poses a scratch runner in the wipe at each step of its progress and records where its right hand is (right, up, forward
## of the runner), so the runner can be placed to put the hand on the board (the arm's pose is a table, not an IK).
func _measure_wipe() -> void:
	var avatar := PlayerAvatar.new()
	avatar.fit_to(tuning.visual_size)
	add_child(avatar)
	var rig: HumanoidRig = avatar.rig
	var pose := HumanoidPose.new()
	wipe_hand.clear()
	for i: int in WIPE_SAMPLES + 1:
		CinePoses.runner(pose, &"wipe", float(i) / float(WIPE_SAMPLES), 0.0, rig.parts.pelvis_height())
		rig.apply_pose(pose)
		var palm: Vector3 = avatar.to_local(rig.joint(&"hand_r").global_transform * Vector3(0.0, -CineActorNode.GRIP_REACH, 0.0))
		wipe_hand.append(Vector3(palm.x, palm.y, -palm.z))
	remove_child(avatar)
	avatar.free()


## The hand's height over the strokes' middle (the board's middle goes there).
func _wipe_height() -> float:
	var lo: float = INF
	var hi: float = -INF
	for i: int in WIPE_SAMPLES + 1:
		var s: float = float(i) / float(WIPE_SAMPLES)
		if s >= CinePoses.WIPE_RAISE.x and s <= CinePoses.WIPE_RAISE.y:
			lo = minf(lo, wipe_hand[i].y)
			hi = maxf(hi, wipe_hand[i].y)
	return (lo + hi) * 0.5


## The wipe at progress `s` (0-1): how raised the arm is (0 down, 1 on the board) and how far through the strokes.
static func _raise(s: float) -> float:
	return smoothstep(0.0, CinePoses.WIPE_RAISE.x, s) * (1.0 - smoothstep(CinePoses.WIPE_RAISE.y, 1.0, s))


static func _through(s: float) -> float:
	return clampf((s - CinePoses.WIPE_RAISE.x) / (CinePoses.WIPE_RAISE.y - CinePoses.WIPE_RAISE.x), 0.0, 1.0)


func _hand_at(i: int) -> Vector3:
	return wipe_hand[clampi(i, 0, WIPE_SAMPLES)]


## Where the runner stands at progress `s` of the wipe (the station's frame, y 0), facing the board (yaw 90): the hand on the
## board's face, sweeping `wipe_reach` either side of its middle.
func wipe_position(s: float) -> Vector3:
	var i: float = s * float(WIPE_SAMPLES)
	var a: Vector3 = _hand_at(floori(i))
	var b: Vector3 = _hand_at(ceili(i))
	var h: Vector3 = a.lerp(b, i - floorf(i))
	var raise: float = _raise(s)
	var forward: float = lerpf(_hand_at(WIPE_SAMPLES / 2).z, h.z, raise)
	var x: float = n.board_x + n.wipe_reach * CinePoses.wipe_stroke(_through(s)) * raise - h.x * raise
	return Vector3(x, 0.0, TerminalIntroSign.FACE_OUT + HAND_OFF + forward)


## The hand's place on the board at progress `s` (metres from its middle: along, up).
func wipe_hand_on_board(s: float) -> Vector2:
	var i: float = s * float(WIPE_SAMPLES)
	var h: Vector3 = _hand_at(floori(i)).lerp(_hand_at(ceili(i)), i - floorf(i))
	var p: Vector3 = wipe_position(s)
	return Vector2(p.x + h.x - n.board_x, h.y - board.middle.y)


## The board's wiped trail: the hand's place on it (metres from its middle) at TRAIL_POINTS moments through the strokes, and when.
func _wipe_trail() -> void:
	var points := PackedVector2Array()
	var times := PackedFloat32Array()
	var seconds: float = n.sign_at - n.wipe_at
	for i: int in TerminalIntroSign.TRAIL_POINTS:
		var s: float = lerpf(CinePoses.WIPE_RAISE.x + 0.02, CinePoses.WIPE_RAISE.y, float(i) / float(TerminalIntroSign.TRAIL_POINTS - 1))
		points.append(wipe_hand_on_board(s))
		times.append(n.wipe_at + s * seconds)
	board.path = points
	board.path_times = times


# --- The runner ---------------------------------------------------------------------------------------------------

## A key of the runner's at `at` seconds, at `p` (the station's frame), facing `yaw` degrees (NAN: the way it moves).
func _key(r: CineActor, at: float, p: Vector3, pose: StringName, yaw: float, look: float = 0.0, look_up: float = 0.0,
		progress: float = -1.0) -> CineActorKey:
	var k: CineActorKey = r.at(at, st(p.x, p.y, p.z), pose)
	if is_nan(yaw):
		k.face_path = true
	else:
		k.face_path = false
		k.yaw = yaw
	k.look = look
	k.look_up = look_up
	k.progress = progress
	return k


func _runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	r.turn_rate = TURN_RATE
	var start := Vector3(n.start_at.x, 0.0, n.start_at.y)
	# Surveying: standing at ease, their head turning (the looks keys), the body facing along the street.
	for k: Vector3 in n.looks:
		_key(r, k.x, start, &"walk", n.start_yaw, k.y, k.z)
	# The walk to the board: round the heap's foot to its right (the corner), then to where the wipe begins, at `walk_speed` (a
	# natural pace for a runner this size), arriving as the wipe starts. The shot that follows them (`walk_at`) is the last stretch
	# of it: they are cut to where they have got to by the time they arrive (a CUT key a moment before the cut to that shot, so the
	# camera riding with them never reads their path across it) while the cameras are on the station and they are out of frame.
	stand = wipe_position(0.0)
	var corner := Vector3(n.walk_corner.x, 0.0, n.walk_corner.y)
	var first: float = Vector2(corner.x - start.x, corner.z - start.z).length()
	var second: float = Vector2(stand.x - corner.x, stand.z - corner.z).length()
	var t_arrive: float = n.wipe_at - 0.25
	var last_look: float = n.looks[n.looks.size() - 1].x if not n.looks.is_empty() else 0.0
	t_walk = maxf(n.walk_at, last_look)
	var seen: float = minf(n.walk_speed * (t_arrive - t_walk), first + second)
	var d_cut: float = first + second - seen
	var cut_at: float = t_walk - CUT_LEAD
	t_corner = t_walk + (first - d_cut) / n.walk_speed if d_cut < first else -1.0
	_key(r, cut_at - 0.004, start, &"walk", yaw_to(corner.x - start.x, corner.z - start.z), 0.0, 0.0)
	_key(r, cut_at, _along(start, corner, stand, d_cut), &"walk", NAN).move = CinePath.Move.CUT
	# SMOOTH keys: a rounded corner (if it is still ahead), and a slowing as they arrive.
	if t_corner > 0.0:
		_key(r, t_corner, corner, &"walk", NAN).move = CinePath.Move.SMOOTH
	_key(r, t_arrive, stand, &"walk", NAN).move = CinePath.Move.SMOOTH
	# Slowing as they arrive, then turning to face the board (they come at it square, so it is a few degrees).
	var eased: CineActorKey = _key(r, n.wipe_at, stand, &"walk", 90.0, 0.0, 6.0)
	eased.trans = Tween.TRANS_QUAD
	eased.easing = Tween.EASE_OUT
	# The wipe: keys through its progress, the hand on the board.
	var wipe_seconds: float = n.sign_at - n.wipe_at
	t_wipe_end = n.sign_at
	var steps: int = int(ceil(wipe_seconds / KEY_STEP))
	for i: int in range(1, steps + 1):
		var s: float = minf(float(i) / float(steps), 1.0)
		var at: float = n.wipe_at + s * wipe_seconds
		var k: CineActorKey = _key(r, at, wipe_position(s), &"wipe" if i == 1 else &"", 90.0, 0.0, 6.0, s)
		if i == 1:
			k.progress = s
	# Cut to the close-up of the board: they have stepped back from it into the street's side (a cut key, the arm coming down as
	# they go), look at it, nod, and turn to the entrance.
	var back := Vector3(n.board_x, 0.0, n.step_back)
	var jump: CineActorKey = _key(r, n.sign_at, back, &"wipe", 90.0, 0.0, 4.0, 1.0)
	jump.move = CinePath.Move.CUT
	_key(r, n.nod_at - 0.1, back, &"walk", 90.0, 0.0, 6.0)
	_key(r, n.nod_at + 0.25, back, &"walk", 90.0, 0.0, -14.0)
	_key(r, n.nod_at + 0.55, back, &"walk", 90.0, 0.0, 2.0)
	_key(r, n.turn_at, back, &"walk", 90.0, 18.0, 2.0)
	var foot := Vector3(n.heap_foot.x, station.heap.height(n.heap_foot.x, n.heap_foot.y), n.heap_foot.y)
	var to_corner: float = yaw_to(corner.x - back.x, corner.z - back.z)
	_key(r, n.turn_at + 0.45, back, &"walk", to_corner, 0.0, 2.0)
	# They turn and set off the way they came (round the heap's foot, never over its flank) and are at the heap's foot by the cut to the
	# entrance (a cut key, on the heap's own surface).
	var foot_yaw: float = yaw_to(-n.heap_foot.x + 0.35, -(n.heap_foot.y - 0.45))
	_key(r, n.turn_at + 1.1, back.lerp(corner, 0.16), &"walk", NAN)
	var arrive: CineActorKey = _key(r, n.door_at, foot, &"walk", foot_yaw, 0.0, 0.0)
	arrive.move = CinePath.Move.CUT
	# Looking up at the entrance, the crack of light, then the climb.
	_key(r, n.door_at + 0.5, foot, &"walk", foot_yaw, 0.0, 26.0)
	_key(r, n.climb_from - 0.2, foot, &"walk", foot_yaw, 0.0, 24.0)
	_climb(r)
	_inside_runner(t)


## The point `d` metres along the walk start, corner, stand (station frame).
static func _along(from: Vector3, corner: Vector3, to: Vector3, d: float) -> Vector3:
	var first: float = Vector2(corner.x - from.x, corner.z - from.z).length()
	if d <= first:
		return from.lerp(corner, d / maxf(first, 0.001))
	var second: float = Vector2(to.x - corner.x, to.z - corner.z).length()
	return corner.lerp(to, clampf((d - first) / maxf(second, 0.001), 0.0, 1.0))


## Up the heap on the way TerminalIntroHeap keeps smooth (`way_x`) on hands and knees (`crawl`: the body pitched along the slope, the
## pose's progress the slope under them), at an even pace over the surface, then the squeeze in through the crack at its crest.
func _climb(r: CineActor) -> void:
	var heap: TerminalIntroHeap = station.heap
	var z0: float = n.heap_foot.y
	var z1: float = 0.45
	var up_seconds: float = n.crest_at - n.climb_from
	# The way as points on the surface and how far along it each is, so the keys can be spaced by distance covered.
	var points := PackedVector3Array()
	var lengths := PackedFloat32Array()
	for i: int in range(0, CRAWL_PATH_POINTS + 1):
		var u: float = float(i) / float(CRAWL_PATH_POINTS)
		var z: float = lerpf(z0, z1, u)
		var x: float = lerpf(n.heap_foot.x, heap.way_x(z1), u)
		points.append(Vector3(x, heap.height(x, z), z))
		lengths.append(0.0 if i == 0 else lengths[i - 1] + points[i].distance_to(points[i - 1]))
	var steps: int = int(ceil(up_seconds / KEY_STEP))
	var k: int = 0
	for i: int in range(0, steps + 1):
		var u: float = float(i) / float(steps)
		var d: float = u * lengths[lengths.size() - 1]
		while k < points.size() - 2 and lengths[k + 1] < d:
			k += 1
		var f: float = clampf((d - lengths[k]) / maxf(lengths[k + 1] - lengths[k], 0.0001), 0.0, 1.0)
		var p: Vector3 = points[k].lerp(points[k + 1], f)
		var run: float = Vector2(points[k + 1].x - points[k].x, points[k + 1].z - points[k].z).length()
		var slope: float = rad_to_deg(atan2(points[k + 1].y - points[k].y, maxf(run, 0.0001)))
		_key(r, n.climb_from + u * up_seconds, p, &"crawl" if i == 0 else &"", _climb_yaw(u), 0.0, 0.0, CinePoses.crawl_progress(slope))
	# At the crest they turn square to the gap and squeeze through it, head first, lying down as they go (progress 0 to 1).
	var crest := Vector3(heap.way_x(z1), heap.height(heap.way_x(z1), z1), z1)
	var squeeze_seconds: float = n.through_at - n.crest_at
	_key(r, n.crest_at, crest, &"squeeze", 90.0, 0.0, 20.0, 0.0)
	var in_steps: int = int(ceil(squeeze_seconds / KEY_STEP))
	for i: int in range(1, in_steps + 1):
		var u: float = float(i) / float(in_steps)
		var z: float = lerpf(z1, -2.0, u)
		var x: float = lerpf(crest.x, 0.1, u)
		_key(r, n.crest_at + u * squeeze_seconds, Vector3(x, heap.height(x, z) + CREST_LIFT, z), &"", 90.0, 0.0, 22.0, u)
	r.leave = n.through_at + 0.3


## The runner's heading up the heap: from the foot toward the crest, turning square to the gap as they reach it.
func _climb_yaw(u: float) -> float:
	var from: float = yaw_to(station.heap.way_x(0.45) - n.heap_foot.x, 0.45 - n.heap_foot.y)
	return lerpf(from, 90.0, smoothstep(0.7, 1.0, u))


# --- The camera ---------------------------------------------------------------------------------------------------

func _camera(t: CineTimeline) -> void:
	var start := Vector3(n.start_at.x, 0.0, n.start_at.y)
	var f := Vector2(cos(deg_to_rad(n.start_yaw)), -sin(deg_to_rad(n.start_yaw)))
	# Their right (the street's side): the runner faces +x along the front, the front on their left.
	var right := Vector2(-f.y, f.x)
	var eye := Vector3(start.x, EYE_HEIGHT, start.z)
	# The face: in front of them and a little to their left (the gold eyepiece's side), close, easing in.
	var from: Vector3 = eye + Vector3(f.x * n.face_from.x + right.x * n.face_from.y, 0.0, f.y * n.face_from.x + right.y * n.face_from.y)
	var to: Vector3 = eye + Vector3(f.x * n.face_to.x + right.x * n.face_to.y, 0.0, f.y * n.face_to.x + right.y * n.face_to.y)
	_shot(t, 0.0, from, eye, n.face_from.z)
	_shot(t, n.survey_at - 0.3, to, eye, n.face_to.z)
	# Sweeping round them, by their right, to behind them, rising and the lens widening, the look going from their face to what they
	# are looking at (the station) by way of the wasteland: the scene is revealed behind their head as the camera comes round.
	var steps: int = 9
	var t0: float = n.survey_at - 0.3
	var t1: float = n.facade_at - 0.02
	for i: int in range(1, steps + 1):
		var u: float = float(i) / float(steps)
		var e: float = smoothstep(0.0, 1.0, u)
		var phi: float = deg_to_rad(lerpf(n.sweep_angle.x, n.sweep_angle.y, e))
		var radius: float = lerpf(n.sweep_radius.x, n.sweep_radius.y, e)
		var dir := Vector2(f.x * cos(phi) + right.x * sin(phi), f.y * cos(phi) + right.y * sin(phi))
		var pos := Vector3(eye.x + dir.x * radius, lerpf(EYE_HEIGHT, n.sweep_end.x, e), eye.z + dir.y * radius)
		var look: Vector3 = eye.lerp(n.sweep_over.lerp(n.sweep_scene, smoothstep(0.55, 1.0, u)), smoothstep(0.25, 0.6, u))
		_shot(t, lerpf(t0, t1, u), pos, look, lerpf(n.face_to.z, n.sweep_end.y, e))
	# The station's front, from across the street: wide, then craning up and pushing in on the sign.
	var wide := Vector3(n.wide_from.x, n.wide_from.y, minf(n.wide_from.z, street_edge))
	var crane := Vector3(n.crane_from.x, n.crane_from.y, minf(n.crane_from.z, street_edge - 1.0))
	# It opens low on the letters of GRAND where they fell, holds, then pulls back and tilts up the front to the sign.
	_shot(t, n.facade_at, n.fallen_from, n.fallen_look, n.fallen_fov, CinePath.Move.CUT)
	_shot(t, n.facade_at + n.fallen_hold, n.fallen_from + Vector3(0.0, 0.0, 0.3), n.fallen_look_to, n.fallen_fov)
	_shot(t, n.facade_at + n.fallen_hold + n.fallen_move, wide, n.wide_look, n.wide_fov)
	_shot(t, n.walk_at - 0.004, crane, n.crane_look, n.crane_fov)
	# The walk: following them across the forecourt, low, the front beside them.
	var follow: CineCameraKey = t.shot(n.walk_at, st(0.0, 0.0, 0.0), st(0.0, 0.0, 0.0), CinePath.Move.CUT, n.follow_fov.x)
	follow.follow = &"runner"
	follow.watch = &"runner"
	follow.position = n.follow_from
	follow.target = n.follow_look
	var follow2: CineCameraKey = t.shot(n.arrive_at - 0.004, st(0.0, 0.0, 0.0), st(0.0, 0.0, 0.0), CinePath.Move.SMOOTH, n.follow_fov.y)
	follow2.follow = &"runner"
	follow2.watch = &"runner"
	follow2.position = n.follow_to
	follow2.target = n.follow_look_to
	# At the board as they wipe it: from their right front.
	var bx: float = n.board_x
	var mid: Vector3 = board.middle
	_shot(t, n.arrive_at, Vector3(bx + n.wipe_cam.x, n.wipe_cam.y, n.wipe_cam.z), Vector3(bx + n.wipe_look.x, n.wipe_look.y, n.wipe_look.z), n.wipe_fov.x, CinePath.Move.CUT)
	_shot(t, n.sign_at - 0.004, Vector3(bx + n.wipe_cam_to.x, n.wipe_cam_to.y, n.wipe_cam_to.z), Vector3(bx + n.wipe_look.x, n.wipe_look.y, n.wipe_look.z), n.wipe_fov.y)
	# The close-up of the board, from in front: the whole of it, pushing in toward the Palace at the bottom.
	_shot(t, n.sign_at, Vector3(bx, mid.y + 0.02, n.board_out), Vector3(bx, mid.y, 0.1), n.board_fov, CinePath.Move.CUT)
	_shot(t, n.mind_at - 0.004, Vector3(bx + n.board_push.x, mid.y + n.board_push.y, n.board_push.z),
		Vector3(bx + n.board_push_look.x, mid.y + n.board_push_look.y, n.board_push_look.z), n.board_push_fov)
	# They make up their mind: close on them from by the board, the street behind them.
	_shot(t, n.mind_at, Vector3(bx + n.mind_cam.x, n.mind_cam.y, n.mind_cam.z), Vector3(bx + n.mind_look.x, n.mind_look.y, n.step_back + n.mind_look.z), n.mind_fov.x, CinePath.Move.CUT)
	_shot(t, n.door_at - 0.004, Vector3(bx + n.mind_cam_to.x, n.mind_cam_to.y, n.mind_cam_to.z),
		Vector3(bx + n.mind_look_to.x, n.mind_look_to.y, n.step_back + n.mind_look_to.z), n.mind_fov.y)
	# The entrance: low behind them at the foot of the heap, looking up the heap at the crack of light.
	var foot := Vector3(n.heap_foot.x, 0.0, n.heap_foot.y)
	_shot(t, n.door_at, foot + n.door_cam, n.door_look, n.door_fov.x, CinePath.Move.CUT)
	_shot(t, n.climb_from - 0.004, foot + n.door_cam_to, n.door_look_to, n.door_fov.y)
	# The climb: riding with them from beside the heap (the crawl up it close enough to read), then close on the crack as they squeeze in.
	# Each change of the runner's pose (the walk to the crawl, the crawl to the squeeze) is on a cut, at the same moment: poses do not blend.
	var c: PackedVector3Array = n.climb_cam
	_follow_shot(t, n.climb_from, c[0], c[1], c[2].x, CinePath.Move.CUT)
	_follow_shot(t, n.crest_at - 0.004, c[3], c[4], c[5].x)
	_shot(t, n.crest_at, c[6], c[7], c[8].x, CinePath.Move.CUT)
	_shot(t, n.inside_at - 0.5, c[9], c[10], c[11].x)
	# Inside.
	_inside_camera(t)


func _shot(t: CineTimeline, at: float, pos: Vector3, look: Vector3, fov: float, move: CinePath.Move = CinePath.Move.SMOOTH) -> CineCameraKey:
	return t.shot(at, st(pos.x, pos.y, pos.z), st(look.x, look.y, look.z), move, fov)


## A shot riding with the runner: `offset` the camera's place from them and `look` what it looks at, in track axes (x toward the street, y
## up, z along it; CineCameraKey.follow).
func _follow_shot(t: CineTimeline, at: float, offset: Vector3, look: Vector3, fov: float, move: CinePath.Move = CinePath.Move.SMOOTH) -> CineCameraKey:
	var k: CineCameraKey = t.shot(at, Vector3.ZERO, Vector3.ZERO, move, fov)
	k.follow = &"runner"
	k.watch = &"runner"
	k.position = offset
	k.target = look
	return k


## A point of the way in (the entry's frame: x along the wall, y up, z out of it into the hall) in track space.
func ent(x: float, y: float, z: float) -> Vector3:
	return Vector3(inside_wall_x + z, y, n.inside_at_z + x)


## The runner coming out of the crack inside, jumping down and landing on the track, then facing down the line.
func _inside_runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner_in")
	r.turn_rate = TURN_RATE
	r.enter = n.inside_at - 0.05
	var top: float = n.heap_height + CREST_LIFT
	var out_yaw: float = yaw_to(0.0, 1.0)
	var k0: CineActorKey = r.at(n.inside_at - 0.05, ent(0.2, top, -1.5), &"squeeze")
	_pose_key(k0, out_yaw, 18.0, 1.0)
	var k1: CineActorKey = r.at(n.jump_at - 0.3, ent(0.2, top, 0.0))
	_pose_key(k1, out_yaw, 18.0, 1.0)
	var heap := TerminalIntroHeap.new(n.heap_height, n.inside_slope, n.heap_foot_width * 0.8, n.door_width)
	var lip: float = 0.45
	var y0: float = heap.height(0.2, lip) + 0.08
	var k2: CineActorKey = r.at(n.jump_at, ent(0.2, y0, lip), &"run")
	_pose_key(k2, out_yaw, 0.0, -1.0)
	# The jump: off the lip and down, a free fall (9.8 m/s²), landing on the track out from the wall.
	var fall: float = sqrt(2.0 * y0 / 9.8)
	t_land = n.jump_at + fall
	var steps: int = int(ceil(fall / 0.04))
	for i: int in range(1, steps + 1):
		var u: float = minf(float(i) / float(steps), 1.0)
		var tau: float = u * fall
		var p := Vector3(0.2, maxf(y0 - 0.5 * 9.8 * tau * tau, 0.0), lerpf(lip, n.landing_out, u))
		_pose_key(r.at(n.jump_at + tau, ent(p.x, p.y, p.z)), out_yaw, 0.0, -1.0)
	# They land, straighten up and turn to face down the line (+x along the wall: the way the level runs), look along it, and set off.
	var land := Vector3(0.2, 0.0, n.landing_out)
	_pose_key(r.at(t_land + 0.15, ent(land.x, 0.0, land.z), &"walk"), out_yaw, 0.0, -1.0)
	_pose_key(r.at(t_land + 0.3, ent(land.x, 0.0, land.z)), 0.0, 0.0, -1.0)
	var look: CineActorKey = _pose_key(r.at(t_land + 1.2, ent(land.x, 0.0, land.z)), 0.0, 0.0, -1.0)
	look.look_up = 8.0
	var walk: CineActorKey = r.at(n.duration, ent(land.x + 2.6, 0.0, land.z))
	_pose_key(walk, 0.0, 0.0, -1.0)
	walk.face_path = true
	walk.trans = Tween.TRANS_QUAD
	walk.easing = Tween.EASE_IN


func _pose_key(k: CineActorKey, yaw: float, look_up: float, progress: float) -> CineActorKey:
	k.face_path = false
	k.yaw = yaw
	k.look_up = look_up
	k.progress = progress
	return k


func _inside_camera(t: CineTimeline) -> void:
	# From the hall, across the track, at the crack of light in the wall and the runner coming out of it; then round to behind them
	# as they land, looking down the line: the tracks running off, the platform, the arches, the lamps. The cut to the jump is
	# at the moment they rise from the crawl and leave the lip (the runner's pose changes there: poses do not blend).
	var c: PackedVector3Array = n.inside_cam
	var at: Array[float] = [n.inside_at, n.jump_at - 0.004, n.jump_at, t_land, t_land + 1.3, n.duration]
	var cams: Array[int] = [0, 0, 1, 2, 3, 4]
	for i: int in at.size():
		var k: int = cams[i]
		# The first shot pushes in a little as they come out.
		var push := Vector3(0.3, 0.05, -0.4) if i == 1 else Vector3.ZERO
		t.shot(at[i], ent(c[k * 3].x + push.x, c[k * 3].y + push.y, c[k * 3].z + push.z),
			ent(c[k * 3 + 1].x, c[k * 3 + 1].y, c[k * 3 + 1].z),
			CinePath.Move.CUT if i == 0 or i == 2 else CinePath.Move.SMOOTH, c[k * 3 + 2].x)


# --- Sounds, effects and cues ---------------------------------------------------------------------------------------

func _events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, n.music_fade)
	# The wasteland's wind; the station's sign buzzing, from the first view of it; its sparks (each burst's zap); the hand on the
	# board; the rubble under them on the way up and through; the hum of the station as they look at the entrance.
	var at: float = 0.2
	while at < n.arrive_at:
		t.sound(at, &"waste_wind", -6.0)
		at += 2.2
	at = n.facade_at - 0.3
	while at < n.sign_at:
		t.sound(at, &"sign_buzz", -8.0)
		at += 2.3
	var soft: bool = Settings.flashing_reduced
	var last_zap: float = -INF
	for b: int in letters.bursts.size():
		var burst: Vector2 = letters.bursts[b]
		# Only the bursts that show sparks have their zap (with Reduced flashing that is one in three), and not one hard on the
		# last: the sequencer has one player per sound, so a zap restarted inside ZAP_GAP would cut off its buzz's tail.
		if burst.x > 2.4 and burst.x < n.sign_at - 0.4 and TerminalIntroLetters.burst_shows(b, soft) \
				and burst.x - last_zap >= ZAP_GAP:
			t.sound(burst.x, &"sign_zap", -4.0)
			last_zap = burst.x
	for k: int in 3:
		t.sound(n.wipe_at + 0.25 + float(k) * 0.62, &"grime_wipe", -4.0)
	at = n.door_at
	while at < n.inside_at - 0.5:
		t.sound(at, &"station_hum", -8.0)
		at += 2.3
	# The crawl's knocks and slips of stone, a scramble's length (1.8 s) at a time, from the first handhold to the crest.
	at = n.climb_from + 0.1
	var first_knock: bool = true
	while at < n.crest_at - 0.8:
		t.sound(at, &"rubble_scramble", 0.0 if first_knock else -3.0)
		first_knock = false
		at += 1.7
	t.sound(n.crest_at + 0.1, &"rubble_shift", -2.0)
	t.effect(n.inside_at - 0.45, CineEvent.FADE_OUT, 0.35)
	t.cue(n.inside_at - 0.08, &"enter")
	t.effect(n.inside_at, CineEvent.FADE_IN, 0.6)
	t.sound(n.inside_at, &"station_hum", -6.0)
	t.sound(n.inside_at + 0.3, &"rubble_shift", -3.0)
	t.sound(t_land, &"landing_thud")
	t.card(n.card_at, "{zone}", "ZONE {zone_number}", n.card_seconds)
	t.effect(n.fade_at, CineEvent.FADE_OUT, n.fade_out)


## The cut inside: under the black, the Terminal's own stage (the zone's skin, from its data) and the way in on it.
func _on_cue(cue_name: StringName) -> void:
	if cue_name != &"enter" or inside:
		return
	var d := CineStageDef.new()
	d.length = n.stage_length
	switch_stage(d)
	inside = true
	entry = TerminalIntroEntry.new()
	stage.add_child(entry)
	entry.setup(stage.skin, n, stage, inside_wall_x, n.inside_at_z)


## The street stays built back down it behind the cameras outside (the wasteland's haze). Inside, the stretch where the runner lands stays
## built whatever the camera is doing: the cut inside (the cue `enter`, under black) is a moment before the camera's own cut there, and a
## frame in between would take `near` from the camera still out at the station, 60 m up the street, and the Terminal stage would free its
## first chunks, the floor under the landing, as built (a stage's chunks are only ever freed, not built again behind).
func _stage_near(near: float) -> float:
	if inside:
		return minf(near, n.inside_at_z)
	return minf(near, n.station_at - 70.0)


# --- On the clock ------------------------------------------------------------------------------------------------

func _on_advance(_delta: float) -> void:
	if station == null or board == null or inside:
		return
	letters.update(time)
	board.update_wipe(time)
	station.set_light(_light_level(time))


## The station's light at `t`: breathing slowly around 1 (steady with Reduced flashing).
func _light_level(t: float) -> float:
	if Settings.flashing_reduced:
		return 1.0
	return 1.0 + 0.06 * sin(t * 1.7) + 0.04 * sin(t * 4.3 + 1.0)


## Draw calls its props add now (the station and what stands on it, the sparks and the dust, the way in inside, the runner's rig):
## tests.
func props_draw_calls() -> int:
	var calls: int = 0
	if station != null and station.is_visible_in_tree():
		calls += station.draw_calls() + 2
	if entry != null and entry.is_visible_in_tree():
		calls += entry.draw_calls()
	for node: CineActorNode in actors.values():
		if node.visible and node.avatar != null:
			calls += node.avatar.rig.draw_call_count()
	return calls
