extends Node3D
## Zone-skin review, for visual review only (not part of the game): a hand-built level with every
## kind of piece (gaps, fences, signs, pads and ceilings, a ramp, a speed pad, the finish), dressed
## in any skin, seen through the game's camera or from fixed spots. Render it on both renderers:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/review/f.png --quit-after 300 res://tools/showcase/skin_review.tscn -- --skin=marketplace
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options:
##   --skin=name     a skin in data/skins/ (name_skin.tres) or a res:// path (default: city)
##   --lanes=N       lane count (default 5)
##   --view=run      (default) a god-mode player runs the level: jumps a gap and a fence, takes a pad
##                   onto a ceiling and switches lanes up there, rides a ramp onto the right wall past
##                   its shopfronts, then takes the other ceilings. Each action and movement event is
##                   printed with its time, to find the matching frames (frame = time x fps).
##   --view=shot     still cameras, one after another every --hold frames (default 3): 0 the street,
##                   1 into a gap, 2 a ceiling's near end, 3 under a ceiling looking up, 4 the right
##                   wall close up, 5 the left wall close up, 6 the fences and signs, 7 a ceiling's far end,
##                   8 the sky, 9-12 each ceiling's near end from the floor.
##                   --shot=N shows only that one.
## The level's ceilings: for the Marketplace skin, one of each kind (building bridge, overpass,
## ship, floating ad), found by asking the skin which kind a spot gets.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LENGTH: float = 760.0
## Where the ceilings start and how long they are (moved a little to get each Marketplace kind).
const HULLS: Array[Vector2] = [Vector2(196.0, 60.0), Vector2(372.0, 44.0), Vector2(476.0, 40.0), Vector2(576.0, 48.0)]

var tuning: MovementTuning
var skin: ZoneSkin
var lanes: int = 5
var track: TrackBuilder
var player: Player
var camera: Camera3D
var layout: LevelLayout
var _pending: Array = []
var _cam_focus := Vector3.ZERO
var _cam_look_y: float = 1.0
var _shots: Array = []
var _hold: int = 3
var _frame: int = 0


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	lanes = int(_opt("lanes", "5"))
	var skin_name: String = _opt("skin", "city")
	var path: String = skin_name if skin_name.begins_with("res://") else "res://data/skins/%s_skin.tres" % skin_name
	skin = load(path) as ZoneSkin
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	layout = _layout()
	track = TrackBuilder.new()
	add_child(track)
	track.set_layout(layout, tuning, skin)
	camera = Camera3D.new()
	camera.far = 600.0
	camera.fov = tuning.camera_fov
	add_child(camera)
	camera.make_current()
	if _opt("view", "run") == "shot":
		_hold = int(_opt("hold", "3"))
		_shots = _shot_list()
		var only: String = _opt("shot", "")
		if only != "":
			_shots = [_shots[int(only)]]
		_show_shot(0)
		return
	player = Player.new()
	add_child(player)
	player.setup(tuning, TrackGeometry.new(lanes, tuning), lanes / 2)
	player.god_mode = true
	player.grapples = 1_000_000
	player.running = true
	player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [player.elapsed, player.distance, kind]))
	_pending = _script()
	track.update(0.0, 0.0)
	_cam_focus = Vector3(player.position.x, tuning.camera_height, 0.0)
	_update_camera(1.0)


static func _opt(opt_name: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % opt_name):
			return arg.get_slice("=", 1)
	return default


func _layout() -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = lanes
	out.length = LENGTH
	var mid: int = lanes / 2
	# Gaps: beside the player, in the player's lane (jumped), then across several lanes.
	out.gaps.append({"lane": maxi(mid - 1, 0), "start": 62.0, "end": 69.0})
	out.gaps.append({"lane": mid, "start": 86.0, "end": 92.0})
	out.gaps.append({"lane": mini(mid + 1, lanes - 1), "start": 104.0, "end": 111.0})
	var pulsing := _fence(mid, 130.0, "full")
	pulsing["pulsing"] = true
	pulsing["pulse_on"] = 1.2
	pulsing["pulse_off"] = 1.0
	out.fences.append(pulsing)
	out.fences.append(_fence(maxi(mid - 1, 0), 136.0, "gapped"))
	out.fences.append(_fence(mini(mid + 1, lanes - 1), 142.0, "full"))
	out.signs.append({"side": 1, "start": 150.0, "end": 160.0, "bottom": 2.8, "top": 5.5})
	out.signs.append({"side": -1, "start": 166.0, "end": 174.0, "bottom": 0.0, "top": 1.4})
	out.speed_pads.append({"lane": mini(mid + 1, lanes - 1), "at": 178.0})
	# Ceilings, each with a pad at its start in the middle lane; floor gaps under the first one.
	var starts: Array[float] = _hull_starts()
	for i: int in HULLS.size():
		var s: float = starts[i]
		out.hulls.append({"start": s, "end": s + HULLS[i].y})
		out.pads.append({"lane": mid, "at": s + 3.0})
	out.gaps.append({"lane": maxi(mid - 1, 0), "start": starts[0] + 20.0, "end": starts[0] + 26.0})
	out.gaps.append({"lane": mid, "start": starts[0] + 32.0, "end": starts[0] + 38.0})
	# A ramp onto the right wall between the first two ceilings.
	out.ramps.append({"side": 1, "at": 300.0})
	out.gaps.append({"lane": 0, "start": 690.0, "end": 697.0})
	out.gaps.append({"lane": lanes - 1, "start": 700.0, "end": 707.0})
	return out


static func _fence(lane: int, at: float, variant: String) -> Dictionary:
	return {"lane": lane, "at": at, "variant": variant, "pulsing": false, "pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0}


## Where each ceiling starts. With the Marketplace skin, nudged forward until the skin gives each
## one a different kind (bridge, overpass, ship, ad) so one run shows them all.
func _hull_starts() -> Array[float]:
	var out: Array[float] = []
	for i: int in HULLS.size():
		out.append(HULLS[i].x)
	var market := skin as MarketplaceSkin
	if market == null:
		return out
	var geo := TrackGeometry.new(lanes, tuning)
	var wall_x: float = geo.wall_x()
	var wanted: Array[int] = [MarketCeilings.Kind.BRIDGE, MarketCeilings.Kind.OVERPASS, MarketCeilings.Kind.SHIP,
		MarketCeilings.Kind.AD]
	for i: int in HULLS.size():
		for step: int in 400:
			var s: float = HULLS[i].x + step * 0.25
			var center := Vector3(0.0, tuning.ceiling_height + TrackBuilder.HULL_THICKNESS * 0.5, -(s + HULLS[i].y * 0.5))
			var size := Vector3(geo.half_width() * 2.0, TrackBuilder.HULL_THICKNESS, HULLS[i].y)
			if market.ceilings().kind_of(center, size, wall_x) == wanted[i]:
				out[i] = s
				break
	return out


## [distance, action]: fired once when the player reaches that distance.
func _script() -> Array:
	var starts: Array[float] = _hull_starts()
	var out: Array = [
		[82.0, &"jump"],
		[127.5, &"jump"],
		[starts[0] + 22.0, &"move_right"],
		[starts[0] + 40.0, &"move_left"],
		[284.0, &"move_right"],
		[288.0, &"move_right"],
		[292.0, &"move_right"],
		[340.0, &"move_left"],
		[346.0, &"move_left"],
		[352.0, &"move_left"],
	]
	for i: int in range(1, starts.size()):
		out.append([starts[i] + 14.0, &"move_left" if i % 2 == 0 else &"move_right"])
		out.append([starts[i] + 26.0, &"move_right" if i % 2 == 0 else &"move_left"])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return out


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		player.press(action)
	track.update(player.distance, player.elapsed)


func _process(delta: float) -> void:
	if player != null:
		_update_camera(delta)
		return
	_frame += 1
	if _frame % _hold == 0 and _frame / _hold < _shots.size():
		_show_shot(_frame / _hold)


## The game's follow camera (a copy of scripts/run/run_camera.gd, without shake).
func _update_camera(delta: float) -> void:
	var p: Vector3 = player.position
	var cam_y: float = tuning.camera_height + p.y * tuning.camera_follow_y
	var look_y: float = p.y * tuning.camera_follow_y + 1.0
	if player.surface == Player.Surface.CEILING:
		cam_y = tuning.camera_ceiling_height
		look_y = tuning.ceiling_height - 1.2
	var k: float = 1.0 - exp(-tuning.camera_smoothing * delta)
	_cam_focus.x = lerpf(_cam_focus.x, p.x * tuning.camera_follow_x, k)
	_cam_focus.y = lerpf(_cam_focus.y, cam_y, k)
	_cam_look_y = lerpf(_cam_look_y, look_y, k)
	camera.position = Vector3(_cam_focus.x, _cam_focus.y, p.z + tuning.camera_distance)
	camera.look_at(Vector3(_cam_focus.x, _cam_look_y, p.z - tuning.camera_look_ahead))


## Still cameras: [distance of the track to build around, camera position, look-at point].
func _shot_list() -> Array:
	var geo := TrackGeometry.new(lanes, tuning)
	var w: float = geo.wall_x()
	var s0: float = _hull_starts()[0]
	var h: float = tuning.ceiling_height
	var out: Array = [
		[40.0, Vector3(0.0, tuning.camera_height, -40.0), Vector3(0.0, 1.0, -70.0)],
		[70.0, Vector3(geo.lane_x(lanes / 2), 3.2, -78.0), Vector3(geo.lane_x(lanes / 2), -2.5, -90.0)],
		[s0 - 20.0, Vector3(0.0, tuning.camera_height, -(s0 - 16.0)), Vector3(0.0, 4.5, -(s0 + 4.0))],
		[s0, Vector3(0.0, tuning.camera_ceiling_height, -(s0 + 8.0)), Vector3(0.0, h - 1.2, -(s0 + 22.0))],
		[280.0, Vector3(w - 3.2, 2.2, -290.0), Vector3(w, 1.8, -300.0)],
		[280.0, Vector3(-w + 3.2, 2.2, -290.0), Vector3(-w, 1.8, -300.0)],
		[120.0, Vector3(0.5, 3.4, -118.0), Vector3(0.0, 1.2, -135.0)],
		[s0 + 30.0, Vector3(0.0, tuning.camera_ceiling_height, -(s0 + HULLS[0].y - 16.0)),
			Vector3(0.0, h - 0.6, -(s0 + HULLS[0].y + 6.0))],
		[40.0, Vector3(0.0, 30.0, -40.0), Vector3(0.0, 40.0, -60.0)],
	]
	# 9-12: each ceiling's near end, from the floor as the player comes up to it.
	var starts: Array[float] = _hull_starts()
	for s: float in starts:
		out.append([s - 24.0, Vector3(0.0, tuning.camera_height, -(s - 18.0)), Vector3(0.0, 5.5, -(s + 2.0))])
	return out


func _show_shot(index: int) -> void:
	var shot: Array = _shots[index]
	# The track only builds forward: start it over for every shot.
	track.set_layout(layout, tuning, skin)
	track.update(float(shot[0]), float(shot[0]) / tuning.run_speed)
	camera.position = shot[1]
	camera.look_at(shot[2])
	print("shot %d at frame %d" % [index, _frame])
