class_name DeadZoneIntro
extends CinematicSequencer
## The Dead Zone's intro, before Dead Zone 1 (the owner's story beats, October 9, 2026). A smoking crater in the
## rubble street, looking like a gap; down in it the runner lies on their back. After a moment they shake
## themselves and start to pull themselves out: they sit up, get to their feet and reach up for the edge. A cut
## to ground level: at first only their hands, grabbing the edge, then they pull themselves up and over and get
## to their feet. Throughout, cyborgs down the street in the distance: two lying still, a third crouched over
## them, doing who knows what to them. As the runner gets up it looks over: a host (GDD §9.7), its screen
## glitching purple. A cut to a medium shot of it as it turns to stare into the camera, then to an extreme
## close-up of its glitching face filling the picture; as that starts to fade to black, the zone's title card,
## held on the black; then the level.
##
## On the toolkit: the runner and the three cyborgs are the timeline's actors, in poses the toolkit plays out over
## time (CinePoses: the runner lying, getting up and climbing out, its hands holding the edge; CyborgBody: lying
## still, crouched over something, turning its head); the crater is a gap in the stage's street (so it looks like
## one), and what is down in it, its floor, rubble, smoke and a faint light, is this cinematic's own prop
## (DeadZoneCrater), built on the stage so it hides with it. The street is the zone's own look and lanes. Its
## numbers are data: `numbers`, by default data/cinematics/dead_zone_intro_tuning.tres (DeadZoneIntroTuning).
## DESIGN-TBD (docs/questions/f2c.md): what the owner's beats leave open.

const NUMBERS_PATH: String = "res://data/cinematics/dead_zone_intro_tuning.tres"
## The runner's keys come this often through a pose that plays out over time (straight moves between them).
const RUNNER_KEY_STEP: float = 0.05
## The head shake's keys: this many to a turn.
const SHAKE_KEYS_PER_TURN: int = 2

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: DeadZoneIntroTuning

## The numbers playing (numbers, or NUMBERS_PATH's).
var n: DeadZoneIntroTuning
var crater: DeadZoneCrater
## The close-up's two camera keys (frame_face points them at the host's screen at the cut).
var _close_from: CineCameraKey
var _close_to: CineCameraKey
var _framed: bool = false


func _numbers() -> DeadZoneIntroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as DeadZoneIntroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	var d := CineStageDef.new()
	d.length = n.stage_length
	d.gaps = PackedVector3Array([Vector3(0.0, crater_start(), n.crater_end)])
	return d


func _make_timeline() -> CineTimeline:
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	_add_runner(t)
	_add_cyborgs(t)
	_add_camera(t)
	_add_events(t)
	crater = DeadZoneCrater.new()
	stage.add_child(crater)
	crater.setup(self)
	return t


## The close-up: the host's head holds still and its screen glitches harder (its shader's glitch; every host's
## is 1).
func _on_cue(cue_name: StringName) -> void:
	if cue_name != &"close_up":
		return
	var host := actors.get(&"host") as CineActorNode
	if host == null or host.body == null:
		return
	host.body.twitches = false
	if host.body.material != null:
		host.body.material.set_shader_parameter(&"glitch", n.close_glitch)


## On the close-up's first step, once the host is posed for it (head still) and before the camera moves, the
## close-up's keys are pointed at its face (frame_face).
func _on_advance(_delta: float) -> void:
	if _framed or time < n.close_up_at:
		return
	_framed = true
	var host := actors.get(&"host") as CineActorNode
	if host != null and host.body != null:
		frame_face(host)


## Points the close-up's keys (riding with the host) at its screen as it is now: the camera straight in front of
## it, close_below under its middle, far enough off that the whole screen, its face, fills close_fill_from of the
## picture inside the letterbox (its height, or its width on a screen narrower than the face), pushing in until it
## fills close_fill_to by the time it's black.
func frame_face(host: CineActorNode) -> void:
	var head: Node3D = host.body.rig.joint(&"head")
	var rect: Vector4 = CyborgSuit.screen_rect(host.body.look)
	var z: float = CyborgSuit.SCREEN_CENTER.z
	var xf: Transform3D = head.global_transform
	var middle: Vector3 = xf * Vector3((rect.x + rect.z) * 0.5, (rect.y + rect.w) * 0.5, z)
	var height: float = (xf * Vector3(0.0, rect.w, z) - xf * Vector3(0.0, rect.y, z)).length()
	var width: float = (xf * Vector3(rect.z, 0.0, z) - xf * Vector3(rect.x, 0.0, z)).length()
	var facing: Vector3 = (xf.basis * Vector3.FORWARD).normalized()
	# Offsets from the host in track axes (x right, y up, z ahead: world z turned round).
	var rel: Vector3 = middle - host.global_position
	var face := Vector3(rel.x, rel.y, -rel.z)
	var ahead := Vector3(facing.x, facing.y, -facing.z)
	var below := Vector3(0.0, -n.close_below, 0.0)
	# The picture's size a metre off (the camera's field of view is its height's; the letterbox takes off the bars).
	var view: Vector2 = camera.get_viewport().get_visible_rect().size if camera != null else Vector2(16.0, 9.0)
	var tall: float = 2.0 * tan(deg_to_rad(n.close_fov) * 0.5)
	var per_metre := Vector2(tall * view.x / maxf(view.y, 1.0), tall * (1.0 - 2.0 * CineOverlay.BAR_SHARE))
	var fit: float = maxf(height / per_metre.y, width / per_metre.x)
	_close_from.position = face + ahead * fit / n.close_fill_from + below
	_close_to.position = face + ahead * fit / n.close_fill_to + below
	_close_from.target = face
	_close_to.target = face


## The camera looks back down the street past the cyborgs into the haze: the street stays built that far back.
func _stage_near(near: float) -> float:
	return minf(near, n.crater_end - n.host_back - street_behind())


## How much street the camera sees behind the cyborgs before the haze closes in (metres): the zone's fog's.
func street_behind() -> float:
	var fog_end: Variant = stage.skin.get(&"fog_end") if stage != null else null
	return clampf(float(fog_end) if fog_end != null else 150.0, 60.0, 200.0)


## Where the crater starts along the track (its far edge is n.crater_end).
func crater_start() -> float:
	return n.crater_end - n.crater_length


## A point in track space from one given from the crater's far edge.
func from_edge(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y, n.crater_end + p.z)


## The host's place in track space (crouched, down the street behind the crater).
func host_point() -> Vector3:
	var lane: int = stage.lane_from_start(n.host_lane)
	var x: float = stage.lane_x(lane) if lane >= 0 else 0.0
	return Vector3(x, 0.0, n.crater_end - n.host_back)


## A point given from the host, in track space.
func from_host(p: Vector3) -> Vector3:
	return host_point() + p


# --- The runner -------------------------------------------------------------------------------------

## The runner's keys: lying still, then getting up (shaking their head as they sit up), staggering to the far wall
## and reaching up; after the cut their hands come up over the edge and grab it, then they climb out over it.
func _add_runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	var floor_y: float = -n.crater_depth
	var hips := Vector3(0.0, floor_y, n.crater_end - n.lie_back)
	var risen: Vector3 = hips + Vector3(0.0, 0.0, n.rise_ahead)
	var reached := Vector3(0.0, floor_y, n.crater_end - n.reach_back)
	_runner_key(r, 0.0, hips, &"lie", 0.0)
	_runner_key(r, n.stir_at, hips, &"get_up", 0.0)
	# Getting up: its key poses at their times (CinePoses.GET_UP_KEYS), coming forward a little as they rise.
	var stages: Array = [[n.stir_at + 0.4, 0.2], [n.sit_at, 0.55], [n.kneel_at, 0.75], [n.stand_at, 0.9]]
	var last_t: float = n.stir_at
	var last_p: float = 0.0
	for s: Array in stages:
		var at: float = last_t + RUNNER_KEY_STEP
		while at < float(s[0]) - 0.001:
			var p: float = lerpf(last_p, float(s[1]), (at - last_t) / (float(s[0]) - last_t))
			_runner_key(r, at, hips.lerp(risen, smoothstep(0.55, 0.9, p)), &"", p)
			at += RUNNER_KEY_STEP
		_runner_key(r, float(s[0]), hips.lerp(risen, smoothstep(0.55, 0.9, float(s[1]))), &"", float(s[1]))
		last_t = float(s[0])
		last_p = float(s[1])
	# The stagger to the far wall, swaying, easing off as they get there, then the reach up for the edge.
	var walk_at: float = n.stand_at + RUNNER_KEY_STEP
	while walk_at < n.walk_to - 0.001:
		var u: float = (walk_at - n.stand_at) / (n.walk_to - n.stand_at)
		var sway := Vector3(n.walk_sway * sin(u * TAU * 1.5), 0.0, 0.0)
		var walk: CineActorKey = _runner_key(r, walk_at, risen.lerp(reached, u * u * (3.0 - 2.0 * u)) + sway, &"", 0.9)
		walk.look_up = 18.0 * smoothstep(0.3, 1.0, u)
		walk_at += RUNNER_KEY_STEP
	(_runner_key(r, n.walk_to, reached, &"", 0.9) as CineActorKey).look_up = 18.0
	(_runner_key(r, n.reach_at, reached, &"", 1.0) as CineActorKey).look_up = 18.0
	# The climb (after the cut): the hands come up over the edge and grab it; the runner hangs there a moment, then
	# pulls themselves up and over, and gets up on the street (CinePoses.CLIMB_KEYS' key poses at these times).
	var grip := Vector3(0.0, 0.03, n.crater_end + n.grip_over)
	var below := Vector3(0.0, -0.16, n.crater_end - 0.04)
	var up := Vector3(0.0, 0.0, n.crater_end + n.up_ahead)
	# The cut: the reach holds until it, and the climb starts from it (a CUT key: no move between the shots).
	var hang: CineActorKey = _runner_key(r, n.cut_at, below, &"climb", 0.0)
	hang.look_up = 10.0
	hang.move = CinePath.Move.CUT
	var grab: CineActorKey = _runner_key(r, n.grab_at, grip, &"", 0.0)
	grab.look_up = 10.0
	(_runner_key(r, n.climb_from, grip, &"", 0.0) as CineActorKey).look_up = 6.0
	var span: float = n.knee_at - n.climb_from
	var climb: Array = [[n.climb_from + span * 0.36, 0.35], [n.climb_from + span * 0.62, 0.52],
		[n.climb_from + span * 0.82, 0.66], [n.knee_at, 0.8], [lerpf(n.knee_at, n.up_at, 0.45), 0.9], [n.up_at, 1.0]]
	last_t = n.climb_from
	last_p = 0.0
	for s: Array in climb:
		var at: float = last_t + RUNNER_KEY_STEP
		while at < float(s[0]) - 0.001:
			var u: float = (at - last_t) / (float(s[0]) - last_t)
			var p: float = lerpf(last_p, float(s[1]), u)
			_runner_key(r, at, grip.lerp(up, smoothstep(0.8, 1.0, p)), &"", p)
			at += RUNNER_KEY_STEP
		_runner_key(r, float(s[0]), grip.lerp(up, smoothstep(0.8, 1.0, float(s[1]))), &"", float(s[1]))
		last_t = float(s[0])
		last_p = float(s[1])
	_runner_key(r, n.duration, up, &"", 1.0)
	_add_shake(r)


## A key of the runner's: facing down the track (turned by lie_yaw while it lies, stirs and sits up), at `progress`.
func _runner_key(r: CineActor, at: float, p: Vector3, pose: StringName, progress: float) -> CineActorKey:
	var k: CineActorKey = r.at(at, p, pose)
	k.face_path = false
	k.yaw = n.lie_yaw * (1.0 - smoothstep(n.sit_at, n.stand_at, at))
	k.progress = progress
	return k


## The head shake as they sit up: their look swinging from side to side, dying away, on the keys already there
## between shake_from and shake_to (and on keys of its own), and their look up at the edge as they stand.
func _add_shake(r: CineActor) -> void:
	var span: float = maxf(n.shake_to - n.shake_from, 0.01)
	var step: float = 1.0 / (n.shake_rate * SHAKE_KEYS_PER_TURN)
	var times: Array[float] = []
	var at: float = n.shake_from
	while at <= n.shake_to + 0.001:
		times.append(at)
		at += step
	for time_at: float in times:
		if _key_at(r, time_at) == null:
			var k := CineActorKey.new()
			k.time = time_at
			k.position = Vector3.INF
			r.keys.append(k)
	r.keys.sort_custom(func(a: CineActorKey, b: CineActorKey) -> bool: return a.time < b.time)
	# Keys added only for the shake take the path's place and pose there.
	for i: int in r.keys.size():
		var k: CineActorKey = r.keys[i]
		if k.position == Vector3.INF:
			var before: CineActorKey = r.keys[i - 1]
			var after: CineActorKey = r.keys[i + 1] if i + 1 < r.keys.size() else before
			var u: float = clampf((k.time - before.time) / maxf(after.time - before.time, 0.001), 0.0, 1.0)
			k.position = before.position.lerp(after.position, u)
			k.face_path = false
			k.yaw = lerpf(before.yaw, after.yaw, u)
			k.progress = lerpf(before.progress, after.progress, u)
	for k: CineActorKey in r.keys:
		if k.time >= n.shake_from - 0.001 and k.time <= n.shake_to + 0.001:
			var turn: float = (k.time - n.shake_from) * n.shake_rate * 2.0
			var fade: float = 1.0 - (k.time - n.shake_from) / span
			k.look = n.shake_turn * fade * (1.0 if int(roundf(turn)) % 2 == 0 else -1.0) if k.time > n.shake_from + 0.001 else 0.0


func _key_at(a: CineActor, at: float) -> CineActorKey:
	for k: CineActorKey in a.keys:
		if absf(k.time - at) < 0.02:
			return k
	return null


# --- The cyborgs ------------------------------------------------------------------------------------

## The host crouched over the two lying still, working at them; as the runner gets up it looks over (its head
## turning and coming up), and close up its screen shows its corrupted grin.
func _add_cyborgs(t: CineTimeline) -> void:
	var at: Vector3 = host_point()
	var host: CineActor = t.actor(&"host", CineActor.Kind.CYBORG)
	host.host = true
	var k: CineActorKey = host.at(0.0, at, &"crouch")
	k.face_path = false
	k.yaw = n.host_yaw
	k.expression = &"neutral"
	k = host.at(n.look_at, at)
	k.face_path = false
	k.yaw = n.host_yaw
	k = host.at(n.look_at + n.look_seconds, at)
	k.face_path = false
	k.yaw = n.host_yaw
	k.look = n.look_turn
	k.look_up = n.look_up
	k.trans = Tween.TRANS_CUBIC
	k.easing = Tween.EASE_OUT
	k = host.at(n.close_up_at, at)
	k.face_path = false
	k.yaw = n.host_yaw
	k.look = n.look_turn
	k.look_up = n.look_up
	k.expression = &"corrupt_grin"
	k = host.at(n.duration, at)
	k.face_path = false
	k.yaw = n.host_yaw
	k.look = n.look_turn
	k.look_up = n.look_up
	for b: Array in [[&"body_a", n.body_a, n.body_a_yaw], [&"body_b", n.body_b, n.body_b_yaw]]:
		var body: CineActor = t.actor(b[0], CineActor.Kind.CYBORG)
		var bk: CineActorKey = body.at(0.0, at + (b[1] as Vector3), &"lie")
		bk.face_path = false
		bk.yaw = b[2]


# --- The cameras ------------------------------------------------------------------------------------

## High over the crater easing in; the cut to ground level beyond its far edge, rising a little as the runner gets
## up; the cut to a medium shot of the host as it looks over, easing in; the cut to its face, pushing in (the
## close-up's keys ride with the host, pointed at its screen at the cut: frame_face).
func _add_camera(t: CineTimeline) -> void:
	var k: CineCameraKey = t.shot(0.0, from_edge(n.high_from), from_edge(n.high_look_from), CinePath.Move.LINEAR, n.high_fov)
	k = t.shot(n.cut_at - 0.004, from_edge(n.high_to), from_edge(n.high_look_to), CinePath.Move.LINEAR, n.high_fov)
	k.trans = Tween.TRANS_SINE
	k.easing = Tween.EASE_OUT
	t.shot(n.cut_at, from_edge(n.ground_at), from_edge(n.ground_look), CinePath.Move.CUT, n.ground_fov)
	t.shot(n.rise_from, from_edge(n.ground_at), from_edge(n.ground_look), CinePath.Move.LINEAR, n.ground_fov)
	t.shot(n.medium_at - 0.004, from_edge(n.risen_at), from_edge(n.risen_look), CinePath.Move.LINEAR, n.ground_fov)
	t.shot(n.medium_at, from_host(n.medium_from), from_host(n.medium_look), CinePath.Move.CUT, n.medium_fov)
	k = t.shot(n.close_up_at - 0.004, from_host(n.medium_to), from_host(n.medium_look), CinePath.Move.LINEAR, n.medium_fov)
	k.trans = Tween.TRANS_SINE
	k.easing = Tween.EASE_OUT
	# Until the cut points them at its screen (frame_face), they look at about where its face will be.
	var face := Vector3(n.medium_look.x, n.medium_look.y + 0.3, n.medium_look.z)
	_close_from = t.shot(n.close_up_at, face + Vector3(0.0, 0.0, 0.6), face, CinePath.Move.CUT, n.close_fov)
	_close_from.follow = &"host"
	_close_from.watch = &"host"
	_close_to = t.shot(n.fade_at + n.fade_out, face + Vector3(0.0, 0.0, 0.5), face, CinePath.Move.LINEAR, n.close_fov)
	_close_to.follow = &"host"
	_close_to.watch = &"host"
	_close_to.trans = Tween.TRANS_SINE
	_close_to.easing = Tween.EASE_OUT


# --- Sounds and effects -----------------------------------------------------------------------------

func _add_events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, n.music_fade)
	# The crater smouldering; rubble shifting as the runner sits up; the hands slapping onto the edge; a knee onto it.
	t.sound(0.2, &"crater_smoulder")
	t.sound(n.sit_at - 0.2, &"rubble_shift")
	t.sound(n.grab_at, &"edge_grab")
	t.sound(n.knee_at - 0.1, &"rubble_shift", -4.0)
	# The host's neck grinding and its screen crackling as it turns to look; close up, its corrupted screen.
	t.sound(n.look_at, &"host_turn")
	t.cue(n.close_up_at, &"close_up")
	t.sound(n.close_up_at, &"host_glitch")
	# As the close-up starts to fade to black, the zone's title card, held on the black.
	t.effect(n.fade_at, CineEvent.FADE_OUT, n.fade_out)
	t.card(n.fade_at, "{zone}", "ZONE {zone_number}", n.card_seconds)
