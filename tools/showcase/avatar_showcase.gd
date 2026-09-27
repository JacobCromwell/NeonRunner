extends Node3D
## Review scene for the player avatar (Razor Echo: PlayerAvatar on HumanoidRig), lit like the game:
## every pose side by side, the power-up looks, sheets like the owner's concept sheet (side, front and
## back of one runner), a slowly turning runner, and the view from the game camera. Each row is built
## twice, once facing the camera and once turned to show its left side (the gold arm). The camera
## cycles through the shots; ui_left / ui_right step through them.
##
##   Render:  godot --path . --write-movie build/avatar/f.png --fixed-fps 10 --quit-after 12
##            res://tools/showcase/avatar_showcase.tscn -- --shot=sheet
##   Options (after --):
##     --shot=N|name   hold one shot: poses, poses-back, poses-side, special, special-back,
##                     special-side, equipment, equipment-back, equipment-side, sheet, sheet-run,
##                     sheet-close, turntable, game
##     --look=a,b      power-up looks on the sheets and the turntable: claws, armor, shield, magnet,
##                     weapon1..weapon4, or all
##     --shot-seconds=S   time per shot while cycling

const LEVEL_PATH: String = "res://data/levels/prototype_level.tres"
const RUN_SPEED: float = 18.0
const SPACING: float = 1.15
const ROW_POSES: float = 0.0
const ROW_SPECIAL: float = -15.0
const ROW_EQUIPMENT: float = -30.0
## The same rows turned to show their left side sit this far behind the facing ones.
const SIDE_ROW: float = -60.0
const ROW_SHEET: float = -120.0
const ROW_SHEET_RUN: float = -130.0
const TURNTABLE := Vector3(30.0, 0.0, 0.0)
## Turned to show the left side (the gold arm) to a camera in front, facing the viewer's left, like
## the concept sheet's side view.
const TURN_SIDE: float = -PI * 0.5

## Seconds per camera shot when cycling.
@export var shot_seconds: float = 0.4

var _entries: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _camera: Camera3D
var _time: float = 0.0
var _shot: int = 0
var _hold_shot: int = -1
var _hold_name: String = ""
var _turntable: Array[Node3D] = []
var _look: Dictionary = {}


func _ready() -> void:
	_parse_args()
	_build_environment()
	for turn: float in [0.0, TURN_SIDE]:
		var shift: float = 0.0 if turn == 0.0 else SIDE_ROW
		_build_poses_row(ROW_POSES + shift, turn)
		_build_special_row(ROW_SPECIAL + shift, turn)
		_build_equipment_row(ROW_EQUIPMENT + shift, turn)
	_build_sheet(ROW_SHEET, "idle", func(_t: float) -> Dictionary: return _run_state(0.0, {"speed": 0.0}))
	_build_sheet(ROW_SHEET_RUN, "run", func(_t: float) -> Dictionary: return _run_state(_at_phase(0.35)))
	_build_turntable()
	_build_shots()
	_camera = Camera3D.new()
	_camera.fov = 34.0
	add_child(_camera)
	_camera.make_current()
	if _hold_name != "":
		for i: int in _shots.size():
			if _shots[i]["name"] == _hold_name:
				_hold_shot = i
	_apply_shot(_hold_shot if _hold_shot >= 0 else 0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--shot="):
			if v.is_valid_int():
				_hold_shot = int(v)
			else:
				_hold_name = v
		elif arg.begins_with("--shot-seconds="):
			shot_seconds = float(v)
		elif arg.begins_with("--look="):
			_look = _parse_look(v)


## "claws,armor,weapon3" or "all" → the avatar's equipment dictionary.
static func _parse_look(list: String) -> Dictionary:
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_left"):
		var step: int = 1 if event.is_action_pressed(&"ui_right") else -1
		_hold_shot = posmod((_hold_shot if _hold_shot >= 0 else _shot) + step, _shots.size())
		_apply_shot(_hold_shot)


func _physics_process(delta: float) -> void:
	_time += delta
	for e: Dictionary in _entries:
		var avatar: PlayerAvatar = e["avatar"]
		var state: Dictionary = (e["state"] as Callable).call(_time)
		var freeze: float = e.get("freeze", INF)
		avatar.animate(state, 0.0 if _time > freeze else delta)
	for node: Node3D in _turntable:
		node.rotation.y += delta * 0.9
	if _hold_shot < 0:
		var shot: int = int(_time / shot_seconds) % _shots.size()
		if shot != _shot:
			_apply_shot(shot)


# --- Scene -------------------------------------------------------------------

func _build_environment() -> void:
	var skin: ZoneSkin = null
	var config := load(LEVEL_PATH) as LevelConfig
	if config != null:
		skin = config.skin
	if skin == null:
		skin = GreyboxSkin.new()
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	GreyboxMaterials.add_box(self, Vector3(12.0, -0.1, -70.0), Vector3(90.0, 0.2, 200.0),
		GreyboxMaterials.flat(Color(0.16, 0.17, 0.22)))
	for z: float in [ROW_POSES, ROW_SPECIAL, ROW_EQUIPMENT]:
		for shift: float in [0.0, SIDE_ROW]:
			for side: float in [-1.0, 1.0]:
				GreyboxMaterials.add_box(self, Vector3(4.0, 0.005, z + shift + side * 1.2), Vector3(24.0, 0.02, 0.06),
					GreyboxMaterials.glow(Color(0.2, 0.6, 1.0), 0.8))


func _add_avatar(parent: Node3D, at: Vector3, label: String, state: Callable, freeze: float = INF,
		turn: float = 0.0) -> PlayerAvatar:
	var avatar := PlayerAvatar.new()
	avatar.position = at
	avatar.rotation.y = turn
	parent.add_child(avatar)
	_entries.append({"avatar": avatar, "state": state, "freeze": freeze})
	if label != "":
		_label(Vector3(at.x, 1.6 if at.y < 0.5 else at.y + 1.5, at.z), label)
	return avatar


static func _run_state(distance: float, extra: Dictionary = {}) -> Dictionary:
	var s := {"surface": "floor", "grounded": true, "vh": 0.0, "sliding": false, "distance": distance,
		"speed": RUN_SPEED, "wall_side": 1, "switch_dir": 0, "alive": true, "dashing": false, "just_landed": false}
	s.merge(extra, true)
	return s


## Distance that puts the run cycle at `phase` (the rig starts at phase 0).
static func _at_phase(phase: float) -> float:
	var t := load(PlayerAvatar.ANIM_TUNING_PATH) as HumanoidAnimTuning
	return phase * maxf(t.stride_length, RUN_SPEED / t.max_cadence)


func _build_poses_row(z: float, turn: float) -> void:
	var x: float = 0.0
	_add_avatar(self, Vector3(x, 0, z), "idle", func(_t: float) -> Dictionary: return _run_state(0.0, {"speed": 0.0}),
		INF, turn)
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "run", func(t: float) -> Dictionary: return _run_state(t * RUN_SPEED), INF, turn)
	for phase: float in [0.1, 0.35, 0.6, 0.85]:
		x += SPACING
		var d: float = _at_phase(phase)
		_add_avatar(self, Vector3(x, 0, z), "run %.2f" % phase, func(_t: float) -> Dictionary: return _run_state(d),
			INF, turn)
	for jump: Array in [["jump rise", 7.0], ["apex tuck", 0.0], ["fall", -7.0]]:
		x += SPACING
		var vh: float = jump[1]
		_add_avatar(self, Vector3(x, 0, z), jump[0], func(_t: float) -> Dictionary:
			return _run_state(0.0, {"grounded": false, "vh": vh}), INF, turn)
	x += SPACING
	# Landing: touch down on the second frame, freeze at the squash peak.
	_add_avatar(self, Vector3(x, 0, z), "landing", func(t: float) -> Dictionary:
		return _run_state(_at_phase(0.35), {"just_landed": t > 0.01 and t < 0.03}), 0.06, turn)
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "slide", func(_t: float) -> Dictionary: return _run_state(0.0, {"sliding": true}),
		INF, turn)


func _build_special_row(z: float, turn: float) -> void:
	# Wall run: rolled onto a wall like the Player's pivot (right wall: feet on the wall at +x).
	var wall_pivot := Node3D.new()
	wall_pivot.position = Vector3(0.6, 0.9, z)
	wall_pivot.rotation.z = PI * 0.5
	add_child(wall_pivot)
	GreyboxMaterials.add_box(self, Vector3(0.75, 1.2, z), Vector3(0.3, 2.4, 1.6), GreyboxMaterials.flat(Color(0.1, 0.11, 0.16)))
	_add_avatar(wall_pivot, Vector3.ZERO, "", func(_t: float) -> Dictionary:
		return _run_state(_at_phase(0.35), {"surface": "wall", "grounded": false, "wall_side": 1}))
	_label(Vector3(0.0, 2.0, z), "wall run")
	# Ceiling run: rolled 180° under a hull slab.
	var ceil_pivot := Node3D.new()
	ceil_pivot.position = Vector3(2.0, 2.3, z)
	ceil_pivot.rotation.z = PI
	add_child(ceil_pivot)
	GreyboxMaterials.add_box(self, Vector3(2.0, 2.4, z), Vector3(1.4, 0.2, 1.6), GreyboxMaterials.flat(Color(0.22, 0.16, 0.3)))
	_add_avatar(ceil_pivot, Vector3.ZERO, "", func(_t: float) -> Dictionary:
		return _run_state(_at_phase(0.6), {"surface": "ceiling"}), INF, -turn)
	_label(Vector3(2.0, 2.75, z), "ceiling run")
	var x: float = 3.4
	_add_avatar(self, Vector3(x, 0, z), "lane lean", func(_t: float) -> Dictionary:
		return _run_state(_at_phase(0.35), {"switch_dir": 1}), INF, turn)
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "dash", func(_t: float) -> Dictionary:
		return _run_state(_at_phase(0.35), {"dashing": true}), INF, turn)
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "stomp", func(_t: float) -> Dictionary:
		return _run_state(0.0, {"grounded": false, "vh": -22.0, "stomping": true}), INF, turn)
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "death", func(t: float) -> Dictionary:
		return _run_state(0.0, {"alive": t < 0.05}), INF, turn)
	x += SPACING
	var flash := _add_avatar(self, Vector3(x, 0, z), "flash", func(_t: float) -> Dictionary:
		return _run_state(_at_phase(0.35)), INF, turn)
	flash.set_flash(true)


func _build_equipment_row(z: float, turn: float) -> void:
	var looks: Array = [
		["plain", {}],
		["claws", {"claws": true}],
		["armor", {"armor": true}],
		["shield", {"shield": true}],
		["weapon 1", {"weapon_tier": 1}],
		["weapon 2", {"weapon_tier": 2}],
		["weapon 3", {"weapon_tier": 3}],
		["weapon 4", {"weapon_tier": 4}],
		["magnet", {"magnet": true}],
		["all", {"claws": true, "armor": true, "shield": true, "weapon_tier": 4, "magnet": true}],
	]
	var x: float = 0.0
	for look: Array in looks:
		var avatar := _add_avatar(self, Vector3(x, 0, z), look[0], func(_t: float) -> Dictionary:
			return _run_state(_at_phase(0.35)), INF, turn)
		avatar.set_equipment(look[1])
		x += SPACING


## Three runners like the owner's concept sheet, left to right as the camera sees them: the left
## side (the gold arm), the front, the back. (The camera looks along +z, so its left is +x.)
func _build_sheet(z: float, title: String, state: Callable) -> void:
	var x: float = 0.0
	for view: Array in [["back", PI], ["front", 0.0], ["side", TURN_SIDE]]:
		var avatar := _add_avatar(self, Vector3(x, 0, z), "", state, INF, view[1])
		avatar.set_equipment(_look)
		_label(Vector3(x, 1.55, z), "%s  %s" % [title, view[0]])
		x += 0.95


func _build_turntable() -> void:
	for i: int in 2:
		var spin := Node3D.new()
		spin.position = TURNTABLE + Vector3(i * 1.6, 0.0, 0.0)
		add_child(spin)
		_turntable.append(spin)
		var avatar := _add_avatar(spin, Vector3.ZERO, "", func(t: float) -> Dictionary: return _run_state(t * 6.0, {"speed": 6.0}))
		if i == 1:
			avatar.set_equipment(_look if not _look.is_empty()
				else {"claws": true, "armor": true, "weapon_tier": 2, "magnet": true})


func _label(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.85, 0.9, 1.0)
	label.outline_size = 8
	label.position = at
	add_child(label)


# --- Camera shots ------------------------------------------------------------

func _build_shots() -> void:
	var rows: Array = [["poses", ROW_POSES, 10.0 * SPACING], ["special", ROW_SPECIAL, 8.5],
		["equipment", ROW_EQUIPMENT, 9.0 * SPACING]]
	for row: Array in rows:
		var z: float = row[1]
		var mid: float = row[2] * 0.5
		# Front three-quarter view, the view from behind and above (like the game camera), and the
		# row turned sideways seen from the front.
		_shots.append({"name": row[0], "from": Vector3(mid - 1.5, 1.9, z - 8.5), "at": Vector3(mid, 0.8, z)})
		_shots.append({"name": row[0] + "-back", "from": Vector3(mid, 4.0, z + 8.5), "at": Vector3(mid, 0.5, z)})
		_shots.append({"name": row[0] + "-side", "from": Vector3(mid, 1.3, z + SIDE_ROW - 8.5),
			"at": Vector3(mid, 0.7, z + SIDE_ROW)})
	for sheet: Array in [["sheet", ROW_SHEET], ["sheet-run", ROW_SHEET_RUN]]:
		_shots.append({"name": sheet[0], "from": Vector3(0.95, 0.8, sheet[1] - 3.3), "at": Vector3(0.95, 0.72, sheet[1])})
	# Close on the sheet's heads and shoulders (the face, the implant, the hair, the back pattern).
	_shots.append({"name": "sheet-close", "from": Vector3(0.95, 1.05, ROW_SHEET - 1.7),
		"at": Vector3(0.95, 1.0, ROW_SHEET), "fov": 40.0})
	_shots.append({"name": "turntable", "from": TURNTABLE + Vector3(0.8, 1.3, -3.6), "at": TURNTABLE + Vector3(0.8, 0.7, 0.0)})
	# The real game camera (MovementTuning defaults: 7.5 m back, 4.2 m up, 70° FOV) behind the runner.
	var runner := Vector3(SPACING, 0.0, ROW_POSES)
	_shots.append({"name": "game", "from": runner + Vector3(0.0, 4.2, 7.5), "at": runner + Vector3(0.0, 1.0, -14.0),
		"fov": 70.0})


func _apply_shot(index: int) -> void:
	_shot = index
	var shot: Dictionary = _shots[index]
	_camera.fov = shot.get("fov", 34.0)
	_camera.position = shot["from"]
	_camera.look_at(shot["at"])
