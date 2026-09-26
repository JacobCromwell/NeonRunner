extends Node3D
## Review scene for the player avatar (PlayerAvatar on HumanoidRig): every pose side by side, the
## equipment placeholders, and a slowly turning runner, lit like the game. The camera cycles through
## shots (front and back views of each row, then the turntable); ui_left / ui_right step through them.
##
##   Render:  SCENE=res://tools/showcase/avatar_showcase.tscn render.sh . build/avatar 30
##   Options (after --): --shot=N holds one shot, --shot-seconds=S sets the time per shot.

const LEVEL_PATH: String = "res://data/levels/prototype_level.tres"
const RUN_SPEED: float = 18.0
const SPACING: float = 1.15
const ROW_POSES: float = 0.0
const ROW_SPECIAL: float = -15.0
const ROW_EQUIPMENT: float = -30.0
const TURNTABLE := Vector3(30.0, 0.0, 0.0)

## Seconds per camera shot when cycling.
@export var shot_seconds: float = 0.4

var _entries: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _camera: Camera3D
var _time: float = 0.0
var _shot: int = 0
var _hold_shot: int = -1
var _turntable: Array[Node3D] = []


func _ready() -> void:
	_parse_args()
	_build_environment()
	_build_poses_row()
	_build_special_row()
	_build_equipment_row()
	_build_turntable()
	_build_shots()
	_camera = Camera3D.new()
	_camera.fov = 34.0
	add_child(_camera)
	_camera.make_current()
	_apply_shot(_hold_shot if _hold_shot >= 0 else 0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_hold_shot = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shot-seconds="):
			shot_seconds = float(arg.get_slice("=", 1))


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
	GreyboxMaterials.add_box(self, Vector3(12.0, -0.1, -15.0), Vector3(80.0, 0.2, 90.0),
		GreyboxMaterials.flat(Color(0.16, 0.17, 0.22)))
	for z: float in [ROW_POSES, ROW_SPECIAL, ROW_EQUIPMENT]:
		for side: float in [-1.0, 1.0]:
			GreyboxMaterials.add_box(self, Vector3(4.0, 0.005, z + side * 1.2), Vector3(24.0, 0.02, 0.06),
				GreyboxMaterials.glow(Color(0.2, 0.6, 1.0), 0.8))


func _add_avatar(parent: Node3D, at: Vector3, label: String, state: Callable, freeze: float = INF) -> PlayerAvatar:
	var avatar := PlayerAvatar.new()
	avatar.position = at
	parent.add_child(avatar)
	_entries.append({"avatar": avatar, "state": state, "freeze": freeze})
	if label != "":
		var text := Label3D.new()
		text.text = label
		text.font_size = 40
		text.pixel_size = 0.004
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text.modulate = Color(0.85, 0.9, 1.0)
		text.outline_size = 8
		text.position = Vector3(at.x, 1.6 if at.y < 0.5 else at.y + 1.5, at.z)
		add_child(text)
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


func _build_poses_row() -> void:
	var x: float = 0.0
	var z: float = ROW_POSES
	_add_avatar(self, Vector3(x, 0, z), "idle", func(_t: float) -> Dictionary: return _run_state(0.0, {"speed": 0.0}))
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "run", func(t: float) -> Dictionary: return _run_state(t * RUN_SPEED))
	for phase: float in [0.1, 0.35, 0.6, 0.85]:
		x += SPACING
		var d: float = _at_phase(phase)
		_add_avatar(self, Vector3(x, 0, z), "run %.2f" % phase, func(_t: float) -> Dictionary: return _run_state(d))
	for jump: Array in [["jump rise", 7.0], ["apex tuck", 0.0], ["fall", -7.0]]:
		x += SPACING
		var vh: float = jump[1]
		_add_avatar(self, Vector3(x, 0, z), jump[0], func(_t: float) -> Dictionary:
			return _run_state(0.0, {"grounded": false, "vh": vh}))
	x += SPACING
	# Landing: touch down on the second frame, freeze at the squash peak.
	_add_avatar(self, Vector3(x, 0, z), "landing", func(t: float) -> Dictionary:
		return _run_state(_at_phase(0.35), {"just_landed": t > 0.01 and t < 0.03}), 0.06)
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "slide", func(_t: float) -> Dictionary: return _run_state(0.0, {"sliding": true}))


func _build_special_row() -> void:
	var z: float = ROW_SPECIAL
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
		return _run_state(_at_phase(0.6), {"surface": "ceiling"}))
	_label(Vector3(2.0, 2.75, z), "ceiling run")
	var x: float = 3.4
	_add_avatar(self, Vector3(x, 0, z), "lane lean", func(_t: float) -> Dictionary:
		return _run_state(_at_phase(0.35), {"switch_dir": 1}))
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "dash", func(_t: float) -> Dictionary:
		return _run_state(_at_phase(0.35), {"dashing": true}))
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "stomp", func(_t: float) -> Dictionary:
		return _run_state(0.0, {"grounded": false, "vh": -22.0, "stomping": true}))
	x += SPACING
	_add_avatar(self, Vector3(x, 0, z), "death", func(t: float) -> Dictionary:
		return _run_state(0.0, {"alive": t < 0.05}))
	x += SPACING
	var flash := _add_avatar(self, Vector3(x, 0, z), "flash", func(_t: float) -> Dictionary:
		return _run_state(_at_phase(0.35)))
	flash.set_flash(true)


func _build_equipment_row() -> void:
	var z: float = ROW_EQUIPMENT
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
			return _run_state(_at_phase(0.35)))
		avatar.set_equipment(look[1])
		x += SPACING


func _build_turntable() -> void:
	for i: int in 2:
		var spin := Node3D.new()
		spin.position = TURNTABLE + Vector3(i * 1.6, 0.0, 0.0)
		add_child(spin)
		_turntable.append(spin)
		var avatar := _add_avatar(spin, Vector3.ZERO, "", func(t: float) -> Dictionary: return _run_state(t * 6.0, {"speed": 6.0}))
		if i == 1:
			avatar.set_equipment({"claws": true, "armor": true, "weapon_tier": 2, "magnet": true})


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
	var rows: Array = [[ROW_POSES, 10.0 * SPACING], [ROW_SPECIAL, 8.5], [ROW_EQUIPMENT, 9.0 * SPACING]]
	for row: Array in rows:
		var z: float = row[0]
		var mid: float = row[1] * 0.5
		# Front three-quarter view, then the view from behind and above (like the game camera).
		_shots.append({"from": Vector3(mid - 1.5, 1.9, z - 8.5), "at": Vector3(mid, 0.8, z)})
		_shots.append({"from": Vector3(mid, 4.0, z + 8.5), "at": Vector3(mid, 0.5, z)})
	_shots.append({"from": TURNTABLE + Vector3(0.8, 1.3, -3.6), "at": TURNTABLE + Vector3(0.8, 0.7, 0.0)})
	# The real game camera (MovementTuning defaults: 7.5 m back, 4.2 m up, 70° FOV) behind the runner.
	var runner := Vector3(SPACING, 0.0, ROW_POSES)
	_shots.append({"from": runner + Vector3(0.0, 4.2, 7.5), "at": runner + Vector3(0.0, 1.0, -14.0), "fov": 70.0})


func _apply_shot(index: int) -> void:
	_shot = index
	var shot: Dictionary = _shots[index]
	_camera.fov = shot.get("fov", 34.0)
	_camera.position = shot["from"]
	_camera.look_at(shot["at"])
