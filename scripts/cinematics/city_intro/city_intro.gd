class_name CityIntro
extends CinematicSequencer
## The Neon City's intro (task F2f; the owner's story beats, GDD §6 Cinematics, "Zone 1 intro", October 16, 2026): the
## game's first cinematic, in the City's intro slot in place of the placeholder arrival flyover. About 20 seconds.
## 1. A flyby over the busy city at night: people, cars, buses and trucks on the street below, the Floating Head's
##    searchlight sweeping it, the camera following the light down into the street in one continuous move.
## 2. At street level, human height: cyborgs trudging down the street toward us, the Head looming overhead, its face
##    showing, its cold-white light sweeping over them (it watches, never attacks: red is the bombs').
## 3. The light sweeps past a window; the glass bursts just behind it; the runner leaps out, lands on one cyborg's head
##    (the stomp) and hops over the others, and runs down the street; the light whips back to catch them.
## 4. The Head: startled, then angry, then it yells. The yell goes through the feed: every cyborg's screen face flickers
##    at once and turns angry, and they turn and give chase.
## 5. Zone 1's title card over the chase, and a fade to black; play begins.
##
## On the toolkit: the stage is the City's own stretch of towers with no floor (every lane a gap), lifted so the road
## far below is y = 0, and what a street has is this cinematic's own props (CityIntroStreet, CityIntroTraffic,
## CityIntroCrowd, CityIntroWindow, and the Head: CityIntroHead), built on the stage so they hide with it and moved by
## the clock (`_on_advance`), so stepping or skipping shows the same. The runner and the cyborgs are the timeline's actors.
## The numbers are data: `numbers`, by default data/cinematics/city_intro_tuning.tres (CityIntroTuning).
## DESIGN-TBD (docs/questions/f2f.md): what the owner's beats leave open.

const NUMBERS_PATH: String = "res://data/cinematics/city_intro_tuning.tres"
const BOSS_TUNING_PATH: String = "res://data/bosses/city_boss_tuning.tres"
## The runner's and a hopping runner's keys come this often (s): straight moves between them.
const KEY_STEP: float = 0.05
## A cyborg's screen height (the rig's design height; the City draws them 1.2 times that), to land on its head.
const CYBORG_HEIGHT: float = 1.54
## The dull faces a feed surge flickers through (CyborgKit.Face names): static between the calm face and the angry one.
const FLICKER_FACES: Array[StringName] = [&"corrupt_broken", &"neutral", &"corrupt_broken"]

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: CityIntroTuning
## Fewer vehicles and people (DeviceProfile.is_low_end(), read as it starts; tools and tests may set it before).
var low_end: bool = false

var n: CityIntroTuning
## The props.
var set_root: Node3D
var street: CityIntroStreet
var traffic: CityIntroTraffic
var crowd: CityIntroCrowd
var window: CityIntroWindow
var head: CityIntroHead
## How far the stage is lifted so the road far below the City's trucks is y = 0.
var lift: float = 0.0
## The searchlight's path (street frame): its keys' times and places (see `_plan_light`).
var light_keys: Array[CineKey] = []
var light_points: Array = []
## When the Head notices the runner and the light whips round to them (it has them by `catch_at`).
var notice_at: float = 0.0
var catch_at: float = 0.0
## What the runner's keys planned: when they leave the window, land on the first cyborg, hop over the second and the
## fourth, and where they are when they start running (street frame).
var leap_at: float = 0.0
var hop_times: Array[float] = []
var run_from := Vector3.ZERO
var run_from_at: float = 0.0

var _scaled: bool = false


func _numbers() -> CityIntroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as CityIntroTuning
	return numbers


## The City's stretch of towers with no floor: every lane a gap, so only the road far below shows.
func _stage_def() -> CineStageDef:
	n = _numbers()
	low_end = low_end or DeviceProfile.is_low_end()
	var d := CineStageDef.new()
	d.lanes = n.street_lanes
	d.length = n.stage_length
	var gaps := PackedVector3Array()
	var first: int = -(n.street_lanes / 2)
	for lane: int in range(first, first + n.street_lanes):
		gaps.append(Vector3(lane, -80.0, n.stage_length + 60.0))
	d.gaps = gaps
	return d


## A point in the street's own frame (x across from its middle, y up from the road, z the track distance) as track space.
func tp(x: float, y: float, z: float) -> Vector3:
	return Vector3(x - stage.origin_x, y, z)


func tpv(p: Vector3) -> Vector3:
	return tp(p.x, p.y, p.z)


## A point of the street's frame in world space.
func world_of(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y, -p.z)


func _make_timeline() -> CineTimeline:
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	_lift_stage()
	_build_props()
	_plan()
	_runner(t)
	_cyborgs(t)
	_camera(t)
	_events(t)
	return t


## Lifts the stage so the road far below the trucks is the ground (y = 0), with no height fog (the City's is for the
## far-below street seen from above); the props live in a node that undoes the lift, so they are built in plain world space.
func _lift_stage() -> void:
	lift = stage.skin.get(&"road_depth")
	stage.position.y = lift
	stage.environment.fog_height_density = 0.0
	set_root = Node3D.new()
	set_root.name = "Set"
	stage.add_child(set_root)
	set_root.position.y = -lift


func _build_props() -> void:
	var skin := stage.skin as CitySkin
	var geo: TrackGeometry = stage.geo
	street = CityIntroStreet.new()
	street.name = "StreetDressing"
	set_root.add_child(street)
	street.build(skin, geo, n.dress_from, n.dress_to)
	traffic = CityIntroTraffic.new()
	traffic.name = "Traffic"
	set_root.add_child(traffic)
	traffic.build(skin, street.road_half, n.loop_from, n.loop_to, vehicle_count(), n.vehicle_speeds, n.traffic_clear)
	crowd = CityIntroCrowd.new()
	crowd.name = "Crowd"
	set_root.add_child(crowd)
	crowd.build(street.road_half, street.wall_half, n.loop_from, n.loop_to, people_count(), n.people_speeds)
	window = CityIntroWindow.new()
	window.name = "Window"
	set_root.add_child(window)
	window.build(skin, street.wall_half, n.window_side, n.window_z, n.window_sill, n.window_width, n.window_height,
		n.shard_count, n.burst_at)
	head = CityIntroHead.new()
	head.name = "Head"
	set_root.add_child(head)
	head.build(geo, load(BOSS_TUNING_PATH) as FloatingHeadTuning)
	head.place(n.face_at, n.belly)


## How many vehicles to a lane and people to a sidewalk this device gets.
func vehicle_count() -> int:
	return maxi(roundi(n.vehicles_per_lane * (n.low_end_share if low_end else 1.0)), 4)


func people_count() -> int:
	return roundi(n.people_per_side * (n.low_end_share if low_end else 1.0))


# --- The plan -----------------------------------------------------------------------------------------------

## When things happen that others wait for.
func _plan() -> void:
	leap_at = n.burst_at + 0.05
	notice_at = n.burst_at + 1.8
	catch_at = notice_at + 0.5
	_plan_light()


## The searchlight's path: it sweeps over the street ahead as the camera follows it down, then over the cyborgs as they
## trudge, then along the wall past the window (the glass bursts just behind it), on a little further, searching; then, as the
## Head notices the runner, it whips back to catch them (`light_at`). Times and places in the street frame.
func _plan_light() -> void:
	var wall: float = float(n.window_side) * street.wall_half
	var mid: float = n.lead_z + n.march_places[n.march_places.size() - 1].y * 0.5
	var pts: Array = [
		[0.0, Vector3(0.0, 0.0, 10.0)],
		[2.0, Vector3(-0.5, 0.0, 15.0)],
		[3.6, Vector3(0.3, 0.0, 21.0)],
		[n.street_at, Vector3(-1.5, 0.0, _march_z(mid, n.street_at) - 1.0)],
		[n.street_at + 1.1, Vector3(2.2, 0.0, _march_z(mid, n.street_at + 1.1) + 2.5)],
		[n.street_at + 2.2, Vector3(-2.2, 0.0, _march_z(mid, n.street_at + 2.2) - 3.0)],
		[n.street_at + 3.1, Vector3(1.8, 0.0, _march_z(mid, n.street_at + 3.1))],
		[n.escape_at - 0.2, Vector3(-3.2, 0.0, n.window_z + 2.5)],
		[n.burst_at - 0.65, Vector3(wall * 0.86, 0.7, n.window_z - 1.2)],
		[n.burst_at - 0.35, Vector3(wall, n.window_sill + n.window_height * 0.5, n.window_z - 0.6)],
		[n.burst_at - 0.05, Vector3(wall, n.window_sill + n.window_height * 0.5, n.window_z + 3.2)],
		[n.burst_at + 1.0, Vector3(wall, n.window_sill + 0.3, n.window_z + 9.0)],
		[notice_at, Vector3(wall * 0.6, 0.2, n.window_z + 12.0)],
	]
	for p: Array in pts:
		var k := CineKey.new()
		k.time = p[0]
		k.move = CinePath.Move.SMOOTH
		light_keys.append(k)
		light_points.append(p[1])


## The z of a point of the march that was at `z_at_stomp` (its z when the first cyborg is stomped) at time `at`.
func _march_z(z_at_stomp: float, at: float) -> float:
	return z_at_stomp + n.march_speed * (n.stomp_at - at)


## Where the light's spot is at `t` (street frame), where its surface faces, and how wide it is.
func light_at(t: float) -> Dictionary:
	var spot: Vector3 = CinePath.sample(light_keys, light_points, t)
	var radius: float = n.spot_radius
	var wall_k: float = smoothstep(0.0, 2.5, spot.y)
	radius = lerpf(radius, n.wall_spot_radius, wall_k)
	var runner := actors.get(&"runner") as CineActorNode
	if runner != null and t >= notice_at:
		# The whip: from where it was searching to the runner, quick, then on them wherever they run.
		var on: Vector3 = _street_of(runner.point_at(t))
		var k: float = smoothstep(notice_at, catch_at, t)
		spot = spot.lerp(on, k)
		wall_k *= 1.0 - k
		radius = lerpf(radius, n.runner_spot_radius, k)
	var wall_normal := Vector3(-float(n.window_side), 0.0, 0.0)
	var normal: Vector3 = Vector3.UP.lerp(wall_normal, wall_k).normalized()
	return {"point": spot, "normal": normal, "radius": radius}


## A world point as the street's frame.
func _street_of(world: Vector3) -> Vector3:
	return Vector3(world.x, world.y, -world.z)


# --- The actors -------------------------------------------------------------------------------------------

## Where cyborg `i` is at time `t` (street frame) while it trudges toward the camera: the first at lead_z when it is
## stomped.
func cyborg_at(i: int, at: float) -> Vector3:
	var place: Vector2 = n.march_places[i]
	return Vector3(place.x, 0.0, n.lead_z + place.y + n.march_speed * (n.stomp_at - at))


## How high a cyborg's head is (the City draws them bigger than their rig).
func head_top() -> float:
	return CYBORG_HEIGHT * maxf(stage.skin.cyborg_draw_scale, 0.1)


func _runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	r.enter = n.burst_at - 0.2
	var side: float = float(n.window_side)
	var wall: float = side * street.wall_half
	var top: float = head_top()
	var stomp: float = n.stomp_at
	# Behind the wall, then through the window as it bursts: running, off the sill.
	var inside: Vector3 = Vector3(wall + side * 1.4, n.window_sill, n.window_z)
	var sill: Vector3 = Vector3(wall - side * 0.1, n.window_sill, n.window_z)
	r.at(n.burst_at - 0.2, tpv(inside), &"run")
	r.at(leap_at, tpv(sill), &"run")
	# The leap: out across the street onto the first cyborg's head, the stomp pose for the last of it.
	var landing: Vector3 = cyborg_at(0, stomp) + Vector3(0.0, top, 0.0)
	_arc(r, leap_at, sill, stomp, landing, 0.9, stomp - 0.3)
	# The stomp, and the bounce on over the second cyborg, which comes toward them: the hop is mirrored about it, so its
	# top is over the cyborg.
	var hop: float = n.hop_seconds
	var go: float = stomp + n.stomp_hold
	r.at(go, tpv(landing))
	var mid1: float = go + hop * 0.5
	var over1: Vector3 = cyborg_at(1, mid1)
	var land1 := Vector3(over1.x + 0.3, 0.0, 2.0 * over1.z - landing.z)
	_arc(r, go, landing, go + hop, land1, top + n.hop_clearance - (landing.y + land1.y) * 0.5, -1.0, &"run")
	# A stride or two, and the next hop, over the fifth.
	var take2: float = go + hop + n.stride_seconds
	var from2 := Vector3(land1.x + 0.3, 0.0, land1.z + n.run_speed * n.stride_seconds)
	r.at(take2, tpv(from2))
	var mid2: float = take2 + hop * 0.5
	var over2: Vector3 = cyborg_at(4, mid2)
	var land2 := Vector3(0.65, 0.0, 2.0 * over2.z - from2.z)
	_arc(r, take2, from2, take2 + hop, land2, top + n.hop_clearance - (from2.y + land2.y) * 0.5, -1.0)
	hop_times = [stomp, take2]
	run_from = land2
	run_from_at = take2 + hop
	# Then down the street at a run, under the Head and away.
	var end: Vector3 = land2 + Vector3(0.0, 0.0, n.run_speed * (n.duration - run_from_at))
	r.at(n.duration, tpv(end), &"run")


## Adds keys along a parabola from `a` at `t0` to `b` at `t1`, rising `lift_by` metres above their line at the middle, with
## the runner in `pose` from its first key (empty: keep) and in the stomp pose from `stomp_from` on (none if negative).
func _arc(r: CineActor, t0: float, a: Vector3, t1: float, b: Vector3, lift_by: float, stomp_from: float,
		pose: StringName = &"") -> void:
	var steps: int = maxi(ceili((t1 - t0) / KEY_STEP), 2)
	var stomped: bool = false
	for k: int in range(1, steps + 1):
		var u: float = float(k) / float(steps)
		var p: Vector3 = a.lerp(b, u)
		p.y += 4.0 * lift_by * u * (1.0 - u)
		var at: float = lerpf(t0, t1, u)
		var key: CineActorKey = r.at(at, tpv(p), pose if k == 1 else &"")
		if stomp_from >= 0.0 and not stomped and at >= stomp_from - 0.001:
			key.pose = &"stomp"
			stomped = true


func _cyborgs(t: CineTimeline) -> void:
	var count: int = n.march_places.size()
	for i: int in count:
		var c: CineActor = t.actor(StringName("cyborg_%d" % i), CineActor.Kind.CYBORG)
		var start: Vector3 = cyborg_at(i, 0.0)
		var k: CineActorKey = c.at(0.0, tpv(start), &"walk")
		k.expression = &"neutral"
		if i == 0:
			# The one that is stomped: it trudges on until the runner lands on its head, then goes the way a stomp kills.
			c.at(n.stomp_at, tpv(cyborg_at(0, n.stomp_at)), &"walk")
			var down: CineActorKey = c.at(n.stomp_at + 0.02, tpv(cyborg_at(0, n.stomp_at)), &"stomped")
			down.face_path = false
			down.yaw = 180.0
			c.at(n.duration, tpv(cyborg_at(0, n.stomp_at)))
			continue
		_trudge_then_chase(c, i)


## Trudges toward the camera, stops when the Head yells, its screen face flickers at once with the feed's surge and turns
## angry, then it turns round (each a moment apart) and gives chase down the street.
func _trudge_then_chase(c: CineActor, i: int) -> void:
	var yell: float = n.yell_at
	var stop_at: float = yell + 0.3
	var halt: Vector3 = cyborg_at(i, stop_at)
	c.at(yell, tpv(cyborg_at(i, yell)), &"walk")
	c.at(stop_at, tpv(halt), &"idle")
	# The surge: every screen at once (a few hundredths apart), then the angry face; with Reduced flashing, one change.
	var flicker: float = n.flicker_at + 0.04 * MeshKit.hash01(i, 5, 231)
	var angry_by: float = n.flicker_at + n.flicker_seconds
	if Settings.flashing_reduced:
		_face(c, flicker + 0.1, &"aiming")
	else:
		var step_t: float = (angry_by - flicker) / float(FLICKER_FACES.size() + 1)
		for f: int in FLICKER_FACES.size():
			_face(c, flicker + step_t * f, FLICKER_FACES[f])
		_face(c, angry_by, &"aiming")
	# Turning round, a moment apart, and away.
	var turn0: float = angry_by + 0.15 + 0.35 * MeshKit.hash01(i, 6, 232)
	var turn1: float = turn0 + n.turn_seconds
	var half: CineActorKey = c.at(turn0, tpv(halt), &"idle")
	half.face_path = false
	half.yaw = 180.0
	var mid: CineActorKey = c.at((turn0 + turn1) * 0.5, tpv(halt))
	mid.face_path = false
	mid.yaw = 90.0
	var done: CineActorKey = c.at(turn1, tpv(halt))
	done.face_path = false
	done.yaw = 0.0
	var chase: CineActorKey = c.at(turn1 + 0.05, tpv(halt), &"walk")
	chase.face_path = true
	c.at(n.duration, tpv(halt + Vector3(0.0, 0.0, n.chase_speed * (n.duration - turn1 - 0.05))))


## A key that only changes a cyborg's screen face (it stays where it is: the path's own keys carry it).
func _face(c: CineActor, at: float, face: StringName) -> void:
	var before: CineActorKey = null
	for k: CineActorKey in c.keys:
		if k.time <= at:
			before = k
	var key: CineActorKey = c.at(at, before.position if before != null else Vector3.ZERO)
	key.expression = face
	key.face_path = before.face_path if before != null else true
	key.yaw = before.yaw if before != null else 0.0


# --- The camera ---------------------------------------------------------------------------------------------

func _camera(t: CineTimeline) -> void:
	for i: int in n.move_times.size():
		var p: Vector3 = n.move_positions[i]
		var look: Vector3 = n.move_targets[i]
		t.shot(n.move_times[i], tpv(p), tpv(look), CinePath.Move.SMOOTH, n.move_fovs[i])
	# The Head's face, from the street: tight on it startled, in as it turns angry, back and down for the jaw's drop.
	var face := Vector3(0.0, 0.0, n.face_at)
	for i: int in n.head_times.size():
		var key: CineCameraKey = t.shot(n.head_times[i], tpv(face + n.head_positions[i]), tpv(face + n.head_looks[i]),
			CinePath.Move.CUT if i == 0 else CinePath.Move.LINEAR, n.head_fovs[i])
		key.trans = Tween.TRANS_SINE
		key.easing = Tween.EASE_IN_OUT
	# The street again: the cyborgs' surge and turn, the camera drifting forward; at the title card it eases on behind the chase.
	t.shot(n.reverse_at, tpv(n.street_from), tpv(n.street_look_from), CinePath.Move.CUT, n.street_fov)
	var drift: CineCameraKey = t.shot(n.card_at, tpv(n.street_to), tpv(n.street_look_to), CinePath.Move.LINEAR, n.street_fov)
	drift.trans = Tween.TRANS_LINEAR
	var fly: CineCameraKey = t.shot(n.duration, tpv(n.chase_to), tpv(n.chase_look_to), CinePath.Move.LINEAR, n.chase_fov)
	fly.trans = Tween.TRANS_SINE
	fly.easing = Tween.EASE_IN


# --- Sounds and effects -------------------------------------------------------------------------------------

func _events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, n.music_fade)
	# The glass bursts; the runner leaps; the stomp (and the cyborg's end); the two hops.
	t.sound(n.burst_at, &"window_smash")
	t.effect(n.burst_at, CineEvent.SHAKE, 0.3, 0.1)
	t.sound(leap_at + 0.03, &"jump", -3.0)
	t.sound(n.stomp_at, &"stomp")
	t.effect(n.stomp_at, CineEvent.SHAKE, 0.25, 0.08)
	t.sound(n.stomp_at + 0.04, &"enemy_death", -2.0)
	t.sound(n.stomp_at + n.stomp_hold, &"jump", -4.0)
	t.sound(n.stomp_at + n.stomp_hold + n.hop_seconds, &"land", -4.0)
	t.sound(hop_times[1] + 0.02, &"jump", -4.0)
	t.sound(hop_times[1] + n.hop_seconds, &"land", -4.0)
	# The Head: startled, then angry, then it yells; the yell goes through the feed.
	t.sound(n.startle_at - 0.04, &"head_startle")
	t.effect(n.startle_at, CineEvent.SHAKE, 0.25, 0.1)
	t.sound(n.yell_at, &"head_yell")
	t.effect(n.yell_at, CineEvent.SHAKE, 1.5, 0.05)
	t.sound(n.flicker_at, &"feed_surge")
	t.card(n.card_at, "{zone}", "ZONE {zone_number}", n.card_seconds)
	t.effect(n.duration - n.fade_out, CineEvent.FADE_OUT, n.fade_out)


# --- The clock ----------------------------------------------------------------------------------------------

func _on_advance(_delta: float) -> void:
	if not _scaled:
		_scaled = true
		var draw_scale: float = maxf(stage.skin.cyborg_draw_scale, 0.1)
		for node: CineActorNode in actors.values():
			if node.body != null:
				node.scale = Vector3.ONE * draw_scale
	traffic.update(time)
	crowd.update(time)
	window.update(time)
	var spot: Dictionary = light_at(time)
	var p: Vector3 = spot["point"]
	head.light(world_of(p), spot["normal"], spot["radius"], 1.0)
	head.express(time, world_of(p), face_anger(time), face_surprise(time), face_jaw(time), face_glitch(time))


## The Head's face at `t`: stern while it watches, startled (`startle_at`: the eyes wide, an "O" for a mouth), angry
## (`angry_at`), yelling (`yell_at`: the jaw wide open, the picture breaking up a little).
func face_surprise(t: float) -> float:
	return smoothstep(n.startle_at, n.startle_at + 0.15, t) * (1.0 - smoothstep(n.angry_at, n.angry_at + n.expression_seconds, t))


func face_anger(t: float) -> float:
	var stern: float = 0.35 * (1.0 - smoothstep(n.startle_at, n.startle_at + 0.15, t))
	return maxf(stern, smoothstep(n.angry_at, n.angry_at + n.expression_seconds, t))


func face_jaw(t: float) -> float:
	var jaw: float = n.startle_jaw * smoothstep(n.startle_at, n.startle_at + n.expression_seconds, t)
	jaw *= 1.0 - smoothstep(n.angry_at, n.angry_at + n.expression_seconds, t)
	return maxf(jaw, smoothstep(n.yell_at, n.yell_at + n.expression_seconds, t) * (1.0 - 0.8 * smoothstep(n.yell_at + 2.0, n.yell_at + 2.5, t)))


func face_glitch(t: float) -> float:
	return n.yell_glitch * smoothstep(n.yell_at, n.yell_at + 0.3, t) * (1.0 - smoothstep(n.yell_at + 2.0, n.yell_at + 2.6, t))
