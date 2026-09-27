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
##                   8 the sky, 9-12 each ceiling's near end from the floor, 13-16 a gap coming up from
##                   150, 100, 60 and 30 m away, from the game camera (a gap first shows about 180 m
##                   ahead, when its chunk is built). Skins that list their cult feed screens
##                   (feed_boards(), shop_windows() with "screen") add 17 the first billboard playing
##                   the feed and 18 the first shop window with a TV playing it, close up, and 19 that
##                   window from the lanes. After those come, where the skin lists them, the first
##                   feed screen of each other kind (feed_boards()), the first window with a TV
##                   playing the feed high on a wall (feed_windows()) and the first cult emblem of
##                   each kind (cult_emblems()), close up. Each shot's number, frame and subject are
##                   printed.
##                   --shot=N shows only that one.
## The level's ceilings: for the Marketplace skin, one of each kind (building bridge, overpass,
## ship, floating ad), and for the Corporate skin one of each of its kinds (glass skyway, tower
## bridging the street, viaduct, gunship), found by asking the skin which kind a spot gets.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LENGTH: float = 900.0
## A gap in the middle lane seen from afar (shots 13-16), and how far ahead of the camera it is.
const FAR_GAP: float = 830.0
const FAR_GAP_AHEAD: Array[float] = [150.0, 100.0, 60.0, 30.0]
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
	# Gaps coming up in open street, for the distance shots.
	out.gaps.append({"lane": mid, "start": FAR_GAP, "end": FAR_GAP + 7.0})
	out.gaps.append({"lane": maxi(mid - 1, 0), "start": FAR_GAP + 20.0, "end": FAR_GAP + 27.0})
	out.gaps.append({"lane": mini(mid + 1, lanes - 1), "start": FAR_GAP + 38.0, "end": FAR_GAP + 45.0})
	return out


static func _fence(lane: int, at: float, variant: String) -> Dictionary:
	return {"lane": lane, "at": at, "variant": variant, "pulsing": false, "pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0}


## Where each ceiling starts. With the Marketplace and Corporate skins, nudged forward until the skin
## gives each one a different kind (the Marketplace's bridge, overpass, ship and ad; the Corporate
## skyway, gate, viaduct and gunship) so one run shows them all.
func _hull_starts() -> Array[float]:
	var out: Array[float] = []
	for i: int in HULLS.size():
		out.append(HULLS[i].x)
	var wanted: Array[int] = []
	var kind_of := Callable()
	var market := skin as MarketplaceSkin
	var corporate := skin as CorporateSkin
	if market != null:
		wanted = [MarketCeilings.Kind.BRIDGE, MarketCeilings.Kind.OVERPASS, MarketCeilings.Kind.SHIP, MarketCeilings.Kind.AD]
		kind_of = market.ceilings().kind_of
	elif corporate != null:
		wanted = [CorporateCeilings.Kind.SKYWAY, CorporateCeilings.Kind.GATE, CorporateCeilings.Kind.VIADUCT,
			CorporateCeilings.Kind.SHIP]
		kind_of = corporate.ceilings().kind_of
	else:
		return out
	var geo := TrackGeometry.new(lanes, tuning)
	var wall_x: float = geo.wall_x()
	for i: int in HULLS.size():
		for step: int in 400:
			var s: float = HULLS[i].x + step * 0.25
			var center := Vector3(0.0, tuning.ceiling_height + TrackBuilder.HULL_THICKNESS * 0.5, -(s + HULLS[i].y * 0.5))
			var size := Vector3(geo.half_width() * 2.0, TrackBuilder.HULL_THICKNESS, HULLS[i].y)
			if int(kind_of.call(center, size, wall_x)) == wanted[i]:
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
	]
	# Over to the outer right lane and on up the right wall (past its shop windows), then back to the
	# middle lane once the wall run ends.
	var to_outer: int = lanes - 1 - lanes / 2
	for i: int in to_outer + 1:
		out.append([284.0 + 4.0 * i, &"move_right"])
	for i: int in to_outer:
		out.append([340.0 + 6.0 * i, &"move_left"])
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
	# 13-16: a gap coming up, from where the game camera would be with the player in the middle lane.
	for ahead: float in FAR_GAP_AHEAD:
		var p: float = FAR_GAP - ahead
		out.append([p, Vector3(0.0, tuning.camera_height, -(p - tuning.camera_distance)),
			Vector3(0.0, 1.0, -(p + tuning.camera_look_ahead))])
	# 17-19: the cult's feed on a billboard and on a shop-window TV.
	var board: Dictionary = {}
	if skin.has_method(&"feed_boards"):
		for side: int in [1, -1]:
			for found: Dictionary in skin.call(&"feed_boards", side, side * w, 20.0, LENGTH - 60.0):
				if board.is_empty() or float(found["at"]) < float(board["at"]):
					board = found
		if not board.is_empty():
			var c: Vector3 = board["center"]
			var side: float = signf(c.x)
			# From the far side of the street (inside the street however narrow), a little ahead.
			var across: float = minf(13.0, absf(c.x) + w - 0.8)
			out.append([float(board["at"]) - 30.0, Vector3(c.x - side * across, c.y - 3.0, c.z + 11.0), c,
				"the first billboard playing the feed (%s)" % board.get("kind", "")])
	if skin.has_method(&"shop_windows"):
		var tv: Dictionary = {}
		for side: int in [1, -1]:
			for found: Dictionary in skin.call(&"shop_windows", side, side * w, 20.0, LENGTH - 60.0):
				if found.get("screen", false) and (tv.is_empty() or float(found["at"]) < float(tv["at"])):
					tv = found
		if not tv.is_empty():
			var c: Vector3 = tv["center"]
			var side: float = float(tv["side"])
			var inside := Vector3(c.x + side * 0.45, 1.55, c.z)
			out.append([float(tv["at"]) - 20.0, Vector3(c.x - side * 2.6, 1.9, c.z + 2.2), inside,
				"the first shop window with a TV playing the feed"])
			out.append([float(tv["at"]) - 30.0, Vector3(0.0, tuning.camera_height, c.z + 12.0), inside,
				"that window from the lanes"])
	# Then the first feed screen of each other kind, the first TV window high on a wall, and the first
	# cult emblem of each kind, close up from the far side of the street.
	if skin.has_method(&"feed_boards"):
		# Shot 17 shows the first of all, which is the first of its kind.
		for found: Dictionary in _first_of_each_kind(&"feed_boards", w):
			if found.get("kind", &"") != board.get("kind", &""):
				out.append(_close_up(found, w, 11.0, 3.0, 13.0, "the first %s playing the feed" % found["kind"]))
	if skin.has_method(&"feed_windows"):
		var firsts: Array[Dictionary] = _first_of_each_kind(&"feed_windows", w)
		if not firsts.is_empty():
			var tv: Dictionary = firsts[0]
			var shot: Array = _close_up(tv, w, 5.0, 1.5, 9.0, "the first window with a TV playing the feed")
			shot[2] = tv["screen_center"]
			out.append(shot)
	if skin.has_method(&"cult_emblems"):
		for found: Dictionary in _first_of_each_kind(&"cult_emblems", w):
			out.append(_close_up(found, w, 4.0, 1.0, 10.0, "the first cult emblem on a %s" % found["kind"]))
	return out


## The first entry of each kind (or the first of all, if they have no kind) that the skin's
## `method` lists along the review track on either wall.
func _first_of_each_kind(method: StringName, wall_x: float) -> Array[Dictionary]:
	var firsts: Dictionary = {}
	for side: int in [1, -1]:
		for found: Dictionary in skin.call(method, side, side * wall_x, 20.0, LENGTH - 60.0):
			var kind: Variant = found.get("kind", &"")
			if not firsts.has(kind) or float(found["at"]) < float(firsts[kind]["at"]):
				firsts[kind] = found
	var out: Array[Dictionary] = []
	for kind: Variant in firsts:
		out.append(firsts[kind])
	return out


## A still camera on something on a wall (`found` from a skin's listing: its "at" and "center"): from
## the far side of the street (at most `reach` across), `ahead` metres before it and `below` under it.
func _close_up(found: Dictionary, wall_x: float, ahead: float, below: float, reach: float, label: String) -> Array:
	var c: Vector3 = found["center"]
	var side: float = signf(c.x)
	var across: float = minf(reach, absf(c.x) + wall_x - 0.8)
	return [float(found["at"]) - 30.0, Vector3(c.x - side * across, c.y - below, c.z + ahead), c, label]


func _show_shot(index: int) -> void:
	var shot: Array = _shots[index]
	# The track only builds forward: start it over for every shot.
	track.set_layout(layout, tuning, skin)
	track.update(float(shot[0]), float(shot[0]) / tuning.run_speed)
	camera.position = shot[1]
	camera.look_at(shot[2])
	print("shot %d at frame %d%s" % [index, _frame, (": " + String(shot[3])) if shot.size() > 3 else ""])
