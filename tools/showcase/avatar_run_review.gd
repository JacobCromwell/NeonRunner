extends Node3D
## Gameplay review for the player avatar: a real Player on a hand-built level, driven with press()
## like the tests' RunSim, seen through the game's camera. It jumps a gap, slides under a fence,
## hops a fence, runs the right wall, rides a pad onto the ceiling and switches lanes up there, drops
## back down, air-slides (the stomp pose), dashes, wall-runs the left wall and wall-jumps off.
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 10 --quit-after 190
##            res://tools/showcase/avatar_run_review.tscn -- [options]
##   Options (after --):
##     --skin=<zone id>   the zone's look (data/skins/<id>_skin.tres; default greybox): checks that the
##                        runner reads on every zone's track
##     --equip=a,b        power-up looks: claws, armor, shield, magnet, weapon1..weapon4, or all (armor
##                        breaks at 95 m, to show the shards)
## Each scripted action and movement event is printed with its time, to find the matching frames
## (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LANES: int = 3

## [distance, action]: each fired once when the player reaches that distance. Actions other than
## the Player's own (dash, armor_break) are the review's.
const SCRIPT_ACTIONS: Array = [
	[36.0, &"jump"],
	[73.0, &"slide"],
	[95.0, &"armor_break"],
	[103.0, &"jump"],
	[125.0, &"move_right"],
	[132.0, &"move_right"],
	[183.0, &"move_left"],
	[228.0, &"move_left"],
	[284.0, &"jump"],
	[291.0, &"slide"],
	[297.0, &"dash"],
	[318.0, &"move_left"],
	[331.0, &"jump"],
]
## The dash (seconds, extra m/s), as a placeholder dash power-up would start it.
const DASH := Vector2(0.6, 8.0)

var tuning: MovementTuning
var track: TrackBuilder
var player: Player
var camera: Camera3D
var _pending: Array = []
var _cam_focus := Vector3.ZERO
var _cam_look_y: float = 1.0
var _equipment: Dictionary = {}


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin: ZoneSkin = GreyboxSkin.new()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--skin="):
			var path: String = "res://data/skins/%s_skin.tres" % arg.get_slice("=", 1)
			if ResourceLoader.exists(path):
				skin = load(path) as ZoneSkin
			else:
				push_warning("avatar_run_review: no skin at %s; using the grey box" % path)
		elif arg.begins_with("--equip="):
			_equipment = _parse_equipment(arg.get_slice("=", 1))
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)

	var layout := _layout()
	track = TrackBuilder.new()
	add_child(track)
	track.set_layout(layout, tuning, skin)
	track.update(0.0, 0.0)
	player = Player.new()
	add_child(player)
	player.setup(tuning, TrackGeometry.new(LANES, tuning), 1)
	player.god_mode = true
	player.running = true
	if not _equipment.is_empty():
		player.set_equipment_look(_equipment)
	player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [player.elapsed, player.distance, kind]))
	_pending = SCRIPT_ACTIONS.duplicate()
	camera = Camera3D.new()
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	_cam_focus = Vector3(player.position.x, tuning.camera_height, 0.0)
	_update_camera(1.0)


## "claws,armor,weapon3" or "all" → the avatar's equipment dictionary.
static func _parse_equipment(list: String) -> Dictionary:
	var eq: Dictionary = {}
	for item: String in list.split(",", false):
		item = item.strip_edges()
		if item == "all":
			eq = {"claws": true, "armor": true, "shield": true, "magnet": true, "weapon_tier": 4}
		elif item.begins_with("weapon"):
			eq["weapon_tier"] = clampi(int(item.trim_prefix("weapon").trim_prefix("=")), 1, 4)
		elif item in ["claws", "armor", "shield", "magnet"]:
			eq[item] = true
	return eq


func _layout() -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = LANES
	out.length = 420.0
	out.gaps.append({"lane": 1, "start": 40.0, "end": 46.0})
	out.fences.append(_fence(1, 80.0, "gapped"))
	out.fences.append(_fence(1, 110.0, "full"))
	out.pads.append({"lane": 1, "at": 200.0})
	out.hulls.append({"start": 196.0, "end": 262.0})
	return out


static func _fence(lane: int, at: float, variant: String) -> Dictionary:
	return {"lane": lane, "at": at, "variant": variant, "pulsing": false, "pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0}


func _physics_process(_delta: float) -> void:
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		match action:
			&"dash":
				player.start_dash(DASH.x, DASH.y)
			&"armor_break":
				if _equipment.get("armor", false):
					player.set_equipment_look({"armor": false})
			_:
				player.press(action)
	track.update(player.distance, player.elapsed)


func _process(delta: float) -> void:
	_update_camera(delta)


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
	camera.fov = tuning.camera_fov
	camera.position = Vector3(_cam_focus.x, _cam_focus.y, p.z + tuning.camera_distance)
	camera.look_at(Vector3(_cam_focus.x, _cam_look_y, p.z - tuning.camera_look_ahead))
