extends Node3D
## The Terminal's skin, for visual review only (task O4; not part of the game): a hand-built stretch of track dressed in
## the Terminal's skin (or any skin, --skin=), seen from fixed spots, one after another. It stands in for what task O1's
## track builder gives the skin: wall sections one space long (arches) with about six lengths of open space between them
## (the rest of the wall left out as wall gaps), mostly in left/right pairs, and a stump (`wall_stump`) where a side's
## section is missing; plus holes, single-lane ceilings of each kind, doodads, fences and signs. Render it on both renderers:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/terminal/f.png --quit-after 60 res://tools/showcase/terminal_review.tscn -- --skin=terminal
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options:
##   --skin=name     a skin in data/skins/ (name_skin.tres) or a res:// path (default: terminal)
##   --lanes=N       lane count (default 5)
##   --hold=N        frames each shot is held (default 3)
##   --shot=N        only that shot (the list is printed as it plays)
##   --cam=px,py,pz,tx,ty,tz[,d]   one more shot, held: the camera at p looking at t, the track built to distance d
##                   (default: the camera's)
##   --darkness=X    a level's darker lighting, 0-1 (LevelConfig.darkness)
##   --reduced-flashing  Settings > Reduced flashing on (the failing lamps hold still)
##   --speed=X       seconds of the lamps' time that pass between frames' worth of holds (default 0.1: real time at 10 fps)

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LENGTH: float = 900.0
## The arches: one every ARCH_PITCH metres from ARCH_FIRST, ARCH_LENGTH long (a space), left and right; every
## fourth pair has a missing section on one side (a stump).
const ARCH_FIRST: float = 40.0
const ARCH_PITCH: float = 26.0
const ARCH_LENGTH: float = 3.6

var tuning: MovementTuning
var skin: ZoneSkin
var lanes: int = 5
var track: TrackBuilder
var camera: Camera3D
var layout: LevelLayout
var geo: TrackGeometry
var _shots: Array = []
var _hold: int = 3
var _frame: int = 0
var _stumps: Array[Dictionary] = []
var _hulls: Array[Vector2] = []


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	lanes = int(_opt("lanes", "5"))
	geo = TrackGeometry.new(lanes, tuning)
	if _flag("reduced-flashing"):
		Settings.flashing_reduced = true
		RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var skin_name: String = _opt("skin", "terminal")
	var path: String = skin_name if skin_name.begins_with("res://") else "res://data/skins/%s_skin.tres" % skin_name
	skin = load(path) as ZoneSkin
	var env := WorldEnvironment.new()
	env.environment = skin.level_environment(float(_opt("darkness", "0")), null)
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
	_hold = int(_opt("hold", "3"))
	_shots = _shot_list()
	var only: String = _opt("shot", "")
	if only != "":
		_shots = [_shots[int(only)]]
	_show_shot(0)


func _process(_delta: float) -> void:
	_frame += 1
	var index: int = _frame / _hold
	if index >= _shots.size():
		get_tree().quit()
		return
	if _frame % _hold == 0:
		_show_shot(index)


func _opt(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.get_slice("=", 1)
	return fallback


func _flag(name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + name)


## The stretch: holes in the track bed, then arches and stumps, the ceilings, doodads, fences and signs.
func _layout() -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = lanes
	out.length = LENGTH
	var mid: int = lanes / 2
	out.gaps.append({"lane": maxi(mid - 1, 0), "start": 62.0, "end": 69.0})
	out.gaps.append({"lane": mid, "start": 86.0, "end": 92.0})
	out.gaps.append({"lane": 0, "start": 104.0, "end": 111.0})
	# The arches, as O1 will give them: a wall section a space long, the open space a wall gap, mostly in pairs.
	var k: int = 0
	var at: float = ARCH_FIRST
	while at < LENGTH - 30.0:
		if k % 4 == 2:
			_stumps.append({"side": -1 if (k / 4) % 2 == 0 else 1, "start": at, "end": at + ARCH_LENGTH})
		k += 1
		at += ARCH_PITCH
	for side: int in [-1, 1]:
		var cursor: float = 0.0
		var a: float = ARCH_FIRST
		while a < LENGTH - 30.0:
			var is_stump: bool = false
			for st: Dictionary in _stumps:
				if int(st["side"]) == side and is_equal_approx(float(st["start"]), a):
					is_stump = true
			if not is_stump:
				if a > cursor:
					out.wall_gaps.append({"side": side, "start": cursor, "end": a})
				cursor = a + ARCH_LENGTH
			a += ARCH_PITCH
		if cursor < LENGTH + 80.0:
			out.wall_gaps.append({"side": side, "start": cursor, "end": LENGTH + 80.0})
	# Fences and signs.
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
	# Single-lane ceilings of each kind in the middle lane, each with a pad at its start.
	var starts: Array[float] = _hull_starts()
	for i: int in starts.size():
		var s: float = starts[i]
		out.hulls.append(LevelLayout.make_hull(s, s + 32.0, Vector2i(mid, mid), lanes))
		out.pads.append({"lane": mid, "at": s + 3.0})
		_hulls.append(Vector2(s, s + 32.0))
	# Doodads: a row of small ones, a medium and a large.
	for i: int in 3:
		out.doodads.append({"lane": mid, "start": 420.0 + 4.0 * i, "end": 420.0 + 4.0 * i + tuning.doodad_size(&"small").z,
			"size": &"small", "side": 1, "seed": 3, "look": 3})
	out.doodads.append({"lane": maxi(mid - 1, 0), "start": 440.0, "end": 440.0 + tuning.doodad_size(&"medium").z, "size": &"medium",
		"side": 1, "seed": 5})
	out.doodads.append({"lane": mini(mid + 1, lanes - 1), "start": 440.0, "end": 440.0 + tuning.doodad_size(&"large").z, "size": &"large",
		"side": -1, "seed": 7})
	out.doodads.append({"lane": mid, "start": 462.0, "end": 462.0 + tuning.doodad_size(&"medium").z, "size": &"medium",
		"side": 1, "seed": 9})
	out.doodads.append({"lane": mid, "start": 476.0, "end": 476.0 + tuning.doodad_size(&"large").z, "size": &"large",
		"side": 1, "seed": 11})
	# Holes coming up in open track, for the distance shots.
	out.gaps.append({"lane": mid, "start": 830.0, "end": 837.0})
	out.gaps.append({"lane": maxi(mid - 1, 0), "start": 850.0, "end": 857.0})
	return out


static func _fence(lane: int, at: float, variant: String) -> Dictionary:
	return {"lane": lane, "at": at, "variant": variant, "pulsing": false, "pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0}


## Where the single-lane ceilings start: moved on until the skin gives each of its kinds (the Terminal's three), else fixed.
func _hull_starts() -> Array[float]:
	var out: Array[float] = []
	var terminal := skin as TerminalSkin
	var wanted: Array[int] = [TerminalCeilings.Kind.GIRDER, TerminalCeilings.Kind.WALKWAY, TerminalCeilings.Kind.CAR]
	var base: Array[float] = [196.0, 280.0, 340.0]
	for i: int in 3:
		var s: float = base[i]
		if terminal != null:
			var thickness: float = TrackBuilder.HULL_THICKNESS
			for step: int in 60:
				var center := Vector3(0.0, tuning.ceiling_height + thickness * 0.5, -(s + 16.0))
				var size := Vector3(tuning.lane_width, thickness, 32.0)
				if terminal.ceilings().kind_of(center, size) == wanted[i]:
					break
				s += 1.0
		out.append(s)
	return out


func _shot_list() -> Array:
	var w: float = geo.wall_x()
	var cam_h: float = tuning.camera_height
	var back: float = tuning.camera_distance
	var ahead: float = tuning.camera_look_ahead
	var a1: float = ARCH_FIRST + ARCH_PITCH * 4.0
	var stump: Dictionary = _stumps[0]
	var st: float = float(stump["start"])
	var sd: float = float(stump["side"])
	var out: Array = []
	# 0: the street from the start, through the game camera, with holes ahead.
	out.append([40.0, Vector3(0.0, cam_h, -(40.0 - back)), Vector3(0.0, 1.0, -(40.0 + ahead)), "the game camera at the start"])
	# 1: the first arches, coming up.
	out.append([a1 - 40.0, Vector3(0.0, cam_h, -(a1 - 18.0 - back)), Vector3(0.0, 1.0, -(a1 - 18.0 + ahead)), "arches coming up"])
	# 2: a stump with its partner arch, from the game camera.
	out.append([st - 40.0, Vector3(0.0, cam_h, -(st - 14.0 - back)), Vector3(0.0, 1.0, -(st - 14.0 + ahead)), "a stump and its partner arch"])
	# 3-4: close up from the street: an arch, the stump.
	out.append([a1 - 20.0, Vector3(-w * 0.4, 2.4, -(a1 - 5.5)), Vector3(w, 4.0, -(a1 + 1.0)), "an arch close up, from the street"])
	out.append([st - 20.0, Vector3(-sd * w * 0.3, 2.2, -(st - 6.0)), Vector3(sd * (w + 1.0), 1.6, -(st + 1.0)), "a stump close up"])
	# 5: across the street, a train on the second track.
	out.append([120.0, Vector3(-w + 1.0, 3.0, -118.0), Vector3(w + 6.0, 1.4, -128.0), "across the street, to the second track"])
	# 6: high in the hall, looking down the street.
	out.append([60.0, Vector3(0.0, 9.0, -52.0), Vector3(0.0, 4.0, -90.0), "high in the hall"])
	# 7: the holes from the game camera.
	out.append([40.0, Vector3(0.0, cam_h, -(60.0 - back - 16.0)), Vector3(0.0, 0.0, -(60.0 + ahead)), "holes in the track bed"])
	# 8-10: each ceiling coming up, from the floor.
	for h: Vector2 in _hulls:
		out.append([h.x - 24.0, Vector3(0.0, cam_h, -(h.x - 18.0)), Vector3(0.0, 5.0, -(h.x + 2.0)), "a ceiling's near end (%.0f m)" % h.x])
	# 11-13: riding each, the chase camera under it.
	for h: Vector2 in _hulls:
		out.append([h.x, Vector3(0.0, tuning.camera_ceiling_height, -(h.x + 4.0)), Vector3(0.0, tuning.ceiling_height - 1.2, -(h.x + 18.0)),
			"riding the ceiling at %.0f m" % h.x])
	# 14: the first ceiling from beside it.
	out.append([_hulls[0].x - 30.0, Vector3(w * 0.7, tuning.camera_height, -(_hulls[0].x - 10.0)), Vector3(0.0, 5.5, -(_hulls[0].x + 14.0)),
		"a ceiling from the platform beside it"])
	# 15: fences and signs.
	out.append([120.0, Vector3(0.5, 3.4, -118.0), Vector3(0.0, 1.2, -135.0), "fences and signs"])
	# 16: the debris.
	out.append([400.0, Vector3(0.0, cam_h, -(420.0 - back)), Vector3(0.0, 1.0, -(420.0 + ahead)), "the debris"])
	out.append([430.0, Vector3(0.5, 2.6, -432.0), Vector3(0.0, 1.0, -446.0), "the debris close up"])
	# 18: a hole coming up from afar, the game camera.
	out.append([780.0, Vector3(0.0, cam_h, -(780.0 - back)), Vector3(0.0, 1.0, -(780.0 + ahead)), "a hole from far off"])
	# --cam: one more.
	var cam: String = _opt("cam", "")
	if cam != "":
		var v: PackedStringArray = cam.split(",")
		var p := Vector3(float(v[0]), float(v[1]), float(v[2]))
		var t := Vector3(float(v[3]), float(v[4]), float(v[5]))
		var d: float = float(v[6]) if v.size() > 6 else -p.z - 40.0
		out = [[d, p, t, "--cam"]]
	return out


func _show_shot(index: int) -> void:
	var shot: Array = _shots[index]
	# The track only builds forward: start it over for every shot.
	track.set_layout(layout, tuning, skin)
	track.update(float(shot[0]), float(shot[0]) / tuning.run_speed)
	_draw_stumps()
	camera.position = shot[1]
	camera.look_at(shot[2])
	print("shot %d at frame %d: %s" % [index, _frame, String(shot[3])])


## The stumps (O1's track builder will call wall_stump itself): on the chunk each lies in, if it is built.
func _draw_stumps() -> void:
	if not skin.has_method(&"wall_stump"):
		return
	for st: Dictionary in _stumps:
		var index: int = maxi(0, int(floor(float(st["start"]) / TrackBuilder.CHUNK_LENGTH)))
		var root: Node = track.get_node_or_null("Chunk%d" % index)
		if root != null:
			skin.call(&"wall_stump", root, int(st["side"]), int(st["side"]) * geo.wall_x(), float(st["start"]), float(st["end"]))
