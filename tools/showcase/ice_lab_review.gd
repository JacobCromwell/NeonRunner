extends Node3D
## The Ice Lab's skin, for visual review only (task Q2; not part of the game): a hand-built stretch of track dressed in the Ice Lab's skin
## in any of its three leans (--skin=ice_lab_frost, ice_lab, ice_lab_lab, or any skin), seen from fixed spots, one after another: the street, close
## ups of each wall bay (the first of each kind the skin's hash gives, searched along the wall), both kinds of ceiling coming up, ridden and
## from beside, a wall gap, the hall high up, a floor cut, fences and signs, and every doodad look of every size class in a row across the street.
## Render it on both renderers:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/ice_lab/f.png --quit-after 120 res://tools/showcase/ice_lab_review.tscn -- --skin=ice_lab_lab
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options:
##   --skin=name     a skin in data/skins/ (name_skin.tres) or a res:// path (default: ice_lab)
##   --lanes=N       lane count (default 5)
##   --hold=N        frames each shot is held (default 3)
##   --shot=N        only that shot (the list is printed as it plays)
##   --cam=px,py,pz,tx,ty,tz[,d]   one more shot, held: the camera at p looking at t, the track built to distance d (default: the camera's)
##   --reduced-flashing  Settings > Reduced flashing on (the lamps hold still)

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LENGTH: float = 900.0
## Where the wall bays are searched for (track distances), and how far a bay's close-up stands from the wall.
const SEARCH_FROM: float = 40.0
const SEARCH_TO: float = 2400.0
const BAY_NAMES: Array[String] = ["pipes", "lattice", "tank", "ice", "consoles", "racks", "tile", "door", "jars", "octodog jars"]
## Where the doodads stand: a row across the street for each size class (lane i gets look i).
const DOODAD_AT: Array[float] = [420.0, 440.0, 460.0]

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
var _hulls: Array[Vector3] = []


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	lanes = int(_opt("lanes", "5"))
	geo = TrackGeometry.new(lanes, tuning)
	if _flag("reduced-flashing"):
		Settings.flashing_reduced = true
		RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var skin_name: String = _opt("skin", "ice_lab")
	var path: String = skin_name if skin_name.begins_with("res://") else "res://data/skins/%s_skin.tres" % skin_name
	skin = load(path) as ZoneSkin
	var env := WorldEnvironment.new()
	env.environment = skin.level_environment(0.0, null)
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


static func _fence(lane: int, at: float, variant: String) -> Dictionary:
	return {"lane": lane, "at": at, "variant": variant, "pulsing": false, "pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0}


## The stretch: holes, a floor cut, wall gaps, the two kinds of ceiling, fences and signs, and the rows of doodads.
func _layout() -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = lanes
	out.length = LENGTH
	var mid: int = lanes / 2
	out.gaps.append({"lane": maxi(mid - 1, 0), "start": 62.0, "end": 69.0})
	out.gaps.append({"lane": mid, "start": 86.0, "end": 92.0})
	out.gaps.append({"lane": 0, "start": 104.0, "end": 111.0})
	out.cuts.append(FloorCutPlan.make(mid, 560.0, 60.0, 50.0, 10.0, tuning.run_speed, 5.0, 5.0))
	# Wall gaps, one a side: a stretch of wall left out.
	out.wall_gaps.append({"side": -1, "start": 190.0, "end": 215.0})
	out.wall_gaps.append({"side": 1, "start": 300.0, "end": 330.0})
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
	# Ceilings: a one-lane gantry and a one-lane walkway (found by asking the skin), then one across every lane.
	var ice := skin as IceLabSkin
	var wanted: Array[int] = [IceLabCeilings.Kind.GANTRY, IceLabCeilings.Kind.WALKWAY]
	var base: Array[float] = [250.0, 340.0]
	for i: int in 2:
		var s: float = base[i]
		if ice != null:
			for step: int in 80:
				var center := Vector3(0.0, tuning.ceiling_height + TrackBuilder.HULL_THICKNESS * 0.5, -(s + 16.0))
				var size := Vector3(tuning.lane_width, TrackBuilder.HULL_THICKNESS, 32.0)
				if ice.ceilings().kind_of(center, size) == wanted[i]:
					break
				s += 1.0
		out.hulls.append(LevelLayout.make_hull(s, s + 32.0, Vector2i(mid, mid), lanes))
		out.pads.append({"lane": mid, "at": s + 3.0})
		_hulls.append(Vector3(s, s + 32.0, wanted[i]))
	out.hulls.append(LevelLayout.make_hull(400.0, 440.0, Vector2i(0, lanes - 1), lanes))
	_hulls.append(Vector3(400.0, 440.0, -1.0))
	# Doodads: a row across the street for each size class.
	for row: int in 3:
		var size_class: StringName = LevelLayout.DOODAD_SIZES[row]
		for lane: int in lanes:
			var look_seed: int = _look_seed(size_class, lane)
			out.doodads.append({"lane": lane, "start": DOODAD_AT[row], "end": DOODAD_AT[row] + tuning.doodad_size(size_class).z,
				"size": size_class, "side": 1 if lane < mid else -1, "seed": look_seed, "look": look_seed})
	out.gaps.append({"lane": mid, "start": 830.0, "end": 837.0})
	return out


## A look seed that gives the `index`-th look of `size_class` in the skin's manifest (the Ice Lab picks looks by weights; any other skin: seed = index).
func _look_seed(size_class: StringName, index: int) -> int:
	var ice := skin as IceLabSkin
	if ice == null:
		return index
	var cards := DoodadCards.for_zone(IceLabDoodads.ZONE)
	var list: Array = cards.designs.get(String(size_class), [])
	if list.is_empty():
		return index
	return ice.doodads().look_seed_for(size_class, StringName(list[index % list.size()]["name"]))


## The first bay of each kind the skin's hash gives along a wall (side, distance) or an empty vector where none turns up.
func _find_bays() -> Dictionary:
	var out: Dictionary = {}
	var ice := skin as IceLabSkin
	if ice == null:
		return out
	for side: int in [-1, 1]:
		for k: int in range(int(SEARCH_FROM / IceLabWalls.SLOT), int(SEARCH_TO / IceLabWalls.SLOT)):
			var kind: int = ice.walls().bay_kind(side, k)
			var at: float = float(k) * IceLabWalls.SLOT
			if not out.has(kind) and not ice.reserved_near(side, at + 2.5, 6.0) and not _wall_is_cut(side, at):
				out[kind] = Vector2(side, at)
	return out


## Whether the wall of `side` is left out, or a sign hangs on it, anywhere along the bay that starts at `at`.
func _wall_is_cut(side: int, at: float) -> bool:
	for list: Array in [layout.wall_gaps, layout.signs]:
		for d: Dictionary in list:
			if int(d["side"]) == side and float(d["start"]) < at + IceLabWalls.SLOT + 6.0 and float(d["end"]) > at - 6.0:
				return true
	return false


func _shot_list() -> Array:
	var w: float = geo.wall_x()
	var cam_h: float = tuning.camera_height
	var back: float = tuning.camera_distance
	var ahead: float = tuning.camera_look_ahead
	var out: Array = []
	# The game camera at the start, and from the holes.
	out.append([40.0, Vector3(0.0, cam_h, -(40.0 - back)), Vector3(0.0, 1.0, -(40.0 + ahead)), "the game camera at the start"])
	out.append([40.0, Vector3(0.0, cam_h, -(60.0 - back - 16.0)), Vector3(0.0, 0.0, -(60.0 + ahead)), "holes in the catwalk"])
	# Each kind of wall bay close up, from the lane beside it: the camera low in the street, the wall across.
	var bays: Dictionary = _find_bays()
	for kind: int in IceLabWalls.BAY_COUNT:
		if not bays.has(kind):
			continue
		var at: Vector2 = bays[kind]
		var side: float = at.x
		var z: float = -(at.y + 2.5)
		out.append([at.y - 20.0, Vector3(-side * 0.5, 2.2, z + 5.5), Vector3(side * w, 3.0, z), "a bay of %s (%s side, at %.0f m)" % [
			BAY_NAMES[kind], "left" if side < 0.0 else "right", at.y + 2.5]])
		if kind == IceLabWalls.BAY_JARS or kind == IceLabWalls.BAY_OCTODOG:
			out.append([at.y - 20.0, Vector3(side * (w - 3.4), 1.9, z + 3.0), Vector3(side * w, 2.2, z - 0.4), "the jars of that bay, close up"])
	# Ceilings: each coming up from the floor, ridden under, and from beside.
	for h: Vector3 in _hulls:
		out.append([h.x - 24.0, Vector3(0.0, cam_h, -(h.x - 18.0)), Vector3(0.0, 5.0, -(h.x + 2.0)), "a ceiling's near end (%.0f m)" % h.x])
	for h: Vector3 in _hulls:
		out.append([h.x, Vector3(0.0, tuning.camera_ceiling_height, -(h.x + 4.0)), Vector3(0.0, tuning.ceiling_height - 1.2, -(h.x + 18.0)),
			"riding the ceiling at %.0f m" % h.x])
	out.append([_hulls[0].x - 30.0, Vector3(w * 0.7, tuning.camera_height, -(_hulls[0].x - 10.0)), Vector3(0.0, 5.5, -(_hulls[0].x + 14.0)),
		"a ceiling from the lane beside it"])
	# Wall gaps: from the game camera, and from the other side of the street.
	out.append([170.0, Vector3(0.0, cam_h, -(205.0 - back - 30.0)), Vector3(-w * 0.6, 2.0, -(205.0 + ahead)), "a gap in the left wall"])
	out.append([170.0, Vector3(w * 0.6, 3.0, -190.0), Vector3(-w - 8.0, 3.0, -203.0), "across the street, into the wall gap"])
	# The hall: high, and from the street looking up.
	out.append([60.0, Vector3(0.0, 9.0, -52.0), Vector3(0.0, 8.0, -110.0), "high in the hall"])
	out.append([60.0, Vector3(0.0, 1.8, -52.0), Vector3(0.0, 14.0, -90.0), "looking up at the cranes"])
	# Fences and signs, a floor cut, the doodads.
	out.append([120.0, Vector3(0.5, 3.4, -118.0), Vector3(0.0, 1.2, -135.0), "fences and signs"])
	out.append([560.0, Vector3(0.0, cam_h, -(560.0 - back - 6.0)), Vector3(0.0, 0.0, -(560.0 + ahead)), "a floor cut"])
	for row: int in 3:
		out.append([DOODAD_AT[row] - 20.0, Vector3(0.0, 4.2, -(DOODAD_AT[row] - 9.0)), Vector3(0.0, 1.3, -(DOODAD_AT[row] + 2.0)),
			"the %s doodads, one look a lane" % String(LevelLayout.DOODAD_SIZES[row])])
	out.append([420.0 - 20.0, Vector3(w * 0.5, 2.0, -(420.0 - 4.0)), Vector3(-1.0, 1.3, -(420.0 + 1.0)), "the small doodads close up"])
	out.append([800.0, Vector3(0.0, cam_h, -(800.0 - back)), Vector3(0.0, 1.0, -(800.0 + ahead)), "a hole from far off"])
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
	track.dress_all()
	camera.position = shot[1]
	camera.look_at(shot[2])
	print("shot %d at frame %d: %s" % [index, _frame, String(shot[3])])
