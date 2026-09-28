extends Node3D
## The Golden Zone's statue kit (GoldenStatue) close up, for visual review and for task C4 (the Gilded
## Sentinels); not part of the game. Render it on both renderers, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/statues/f.png --quit-after 40 res://tools/showcase/statue_showcase.tscn -- --view=swing
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Views:
##   poses  (default) every pose in GoldenStatue.POSES side by side on its pedestal, as the skin appends
##          them (mesh()): the decorative guard, vigil and salute, then the swing's raise and strike.
##   turn   the guard from the front, its right side, the back and its left side.
##   swing  a live statue the way task C4 would build one: rig() on the sill of a niche() at wall-run
##          height in a Golden Zone facade, its eyes given a glowing red material of its own, swinging
##          from raise to strike and back (blend_poses() and apply_pose() every frame), seen from the
##          lane beside the wall.
## Options: --skin=res://path/to/skin.tres (default: the Golden Zone's skin, whose kit, materials and
## environment it uses), --nolabel hides the captions.

const SKIN_PATH: String = "res://data/skins/golden_skin.tres"
## The swing view: the wall face's distance from the lane's middle, the niche's sill height and size,
## and how long one swing (raise to strike and back) takes.
const WALL_X: float = 3.2
const SILL_Y: float = 1.2
const NICHE := Vector2(1.5, 3.6)
const SWING_PERIOD: float = 2.4

var skin: GoldenSkin
var kit: GoldenStatue
var view: String = "poses"
var labels: bool = true
var _rig: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	var skin_path: String = SKIN_PATH
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--view="):
			view = v
		elif arg.begins_with("--skin="):
			skin_path = v
		elif arg == "--nolabel":
			labels = false
	skin = load(skin_path) as GoldenSkin
	if skin == null:
		push_error("statue_showcase: %s is not a GoldenSkin" % skin_path)
		skin = GoldenSkin.new()
	kit = skin.statues()
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var camera := Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.make_current()
	match view:
		"turn":
			_turn(camera)
		"swing":
			_swing(camera)
		_:
			_poses(camera)


func _process(delta: float) -> void:
	if _rig.is_empty():
		return
	_t += delta
	var s: float = 0.5 - 0.5 * cos(_t * TAU / SWING_PERIOD)
	GoldenStatue.apply_pose(_rig, GoldenStatue.blend_poses(GoldenStatue.pose_named(&"raise"),
		GoldenStatue.pose_named(&"strike"), s))


## Every pose side by side on a marble floor, facing the camera.
func _poses(camera: Camera3D) -> void:
	var names: Array = GoldenStatue.POSES.keys()
	var spacing: float = 1.7
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	_floor(solid, Vector3(0.0, 0.0, 0.0), 12.0, 6.0)
	for i: int in names.size():
		var x: float = (float(i) - float(names.size() - 1) * 0.5) * spacing
		solid.append(kit.mesh(GoldenStatue.pose_named(names[i])), Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0)))
		var kind: String = "decorative" if GoldenStatue.DECORATIVE.has(names[i]) else "Sentinel's swing"
		_caption("%s\n(%s)" % [names[i], kind], Vector3(x, GoldenStatue.PEDESTAL_HEIGHT + GoldenStatue.STATURE + 0.45, 0.0))
	batch.commit(self)
	camera.position = Vector3(0.0, 2.1, 7.6)
	camera.look_at(Vector3(0.0, 1.6, 0.0))


## The guard turned four ways: front, its right side, back, its left side.
func _turn(camera: Camera3D) -> void:
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	_floor(solid, Vector3.ZERO, 10.0, 6.0)
	var turns: Array[float] = [0.0, -90.0, 180.0, 90.0]
	var captions: PackedStringArray = ["front", "its right side", "back", "its left side"]
	for i: int in turns.size():
		var x: float = (float(i) - 1.5) * 1.9
		solid.append(kit.mesh(GoldenStatue.pose_named(&"guard")),
			Transform3D(Basis(Vector3.UP, deg_to_rad(turns[i])), Vector3(x, 0.0, 0.0)))
		_caption(captions[i], Vector3(x, GoldenStatue.PEDESTAL_HEIGHT + GoldenStatue.STATURE + 0.35, 0.0))
	batch.commit(self)
	camera.position = Vector3(0.0, 2.0, 6.8)
	camera.look_at(Vector3(0.0, 1.6, 0.0))


## A live statue in a niche at wall-run height on a Golden Zone facade (the right wall, facing the
## street, -X), rigged and swinging, with glowing red eyes; the lane's walkway in front.
func _swing(camera: Camera3D) -> void:
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var facade: MeshLayer = batch.layer(skin.facade_material())
	_floor(solid, Vector3(WALL_X - 3.0, 0.0, -6.0), 6.0, 30.0)
	var wall: Color = skin.stone_colors[1]
	MeshKit.facade_quad(facade, 1, WALL_X, -8.0, 16.0, 0.0, skin.plinth_top, skin.plinth_top, wall, 0.0,
		GoldenFacades.STYLE_PLINTH, 7.0)
	MeshKit.facade_quad(facade, 1, WALL_X, -8.0, 16.0, skin.plinth_top, skin.band_top, skin.band_top, wall, 0.0,
		GoldenFacades.STYLE_BAND, 7.0)
	MeshKit.facade_quad(facade, 1, WALL_X, -8.0, 16.0, skin.band_top, skin.frieze_top, skin.frieze_top, wall, 0.0,
		GoldenFacades.STYLE_FRIEZE, 7.0)
	MeshKit.facade_quad(facade, 1, WALL_X, -8.0, 16.0, skin.frieze_top, 16.0, 16.0, wall, 0.3,
		GoldenFacades.STYLE_UPPER, 7.0)
	# The niche on the wall at distance 0, facing the street (niche space +Z to world -X).
	var facing := Basis(Vector3.UP, -PI * 0.5)
	solid.append(kit.niche(NICHE.x, NICHE.y), Transform3D(facing, Vector3(WALL_X, SILL_Y, 0.0)))
	batch.commit(self)
	var holder := Node3D.new()
	holder.name = "Sentinel"
	holder.transform = Transform3D(facing, Vector3(WALL_X, SILL_Y, 0.0)) * Transform3D(Basis.IDENTITY,
		Vector3(0.0, 0.0, 0.32))
	add_child(holder)
	_rig = kit.rig(holder, GoldenStatue.pose_named(&"raise"))
	var eyes := StandardMaterial3D.new()
	eyes.albedo_color = Color(1.0, 0.12, 0.08)
	eyes.emission_enabled = true
	eyes.emission = Color(1.0, 0.12, 0.08)
	eyes.emission_energy_multiplier = 4.0
	(_rig[&"eyes"] as MeshInstance3D).material_override = eyes
	_caption("a live Sentinel: rig() in niche(), eyes red (task C4)", Vector3(WALL_X - 0.6, SILL_Y + NICHE.y + 0.9, 0.0))
	camera.position = Vector3(WALL_X - 4.6, 3.0, 5.4)
	camera.look_at(Vector3(WALL_X - 0.6, SILL_Y + 1.7, 0.0))


## A marble floor (the kerbs' stone) centred on `center`, `width` across and `length` long.
func _floor(solid: MeshLayer, center: Vector3, width: float, length: float) -> void:
	solid.rect(center + Vector3(-width * 0.5, 0.0, length * 0.5), Vector3(width, 0.0, 0.0), Vector3(0.0, 0.0, -length),
		skin.kerb_color, 0.0, MeshKit.PAT_MARBLE)


func _caption(text: String, at: Vector3) -> void:
	if not labels:
		return
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.004
	label.font_size = 40
	label.outline_size = 8
	label.position = at
	add_child(label)
