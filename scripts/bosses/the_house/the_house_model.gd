class_name TheHouseModel
extends Node3D
## The House's machine (GDD §10: "a slot machine the size of a building, rolling down the market street
## on treads, lights blazing and jingling. Loud, gaudy and a little ridiculous"), built once in code from
## a Shape sized to the street (TheHouseBody). Low-poly, merged into a few draws: the cabinet and its trim
## (one mesh on the kit's solid material, the cult's emblem worked into its marquee in brushed bronze, GDD
## §10: "its symbol is hidden on the machine"), its bulbs and sirens (one mesh, the_house_lights.gdshader),
## its three reels (one mesh, the_house_reels.gdshader), its treads (the_house_treads.gdshader), its lever,
## the two lids of the coin hopper on its top and the hopper's red-hot inside (the_house_hopper.gdshader).
## Its space: the face (with the reels) looks toward +z, the runner; x across the street, y up from its
## base on the street, the machine running back along -z from its front (z = 0, the treads' front ends).
## Colour rule (GDD §5, CLAUDE.md): nothing on it glows in a hazard colour but its weak point, the hopper
## (the weak points' red) once it bursts open, and the reels' symbols, each in the colour of the attack it
## announces; the cabinet is purple paint, chrome and unlit gold, its bulbs warm and cold whites.

## Paint and metal (none of them glows).
const PURPLE := Color(0.33, 0.17, 0.5)
const PURPLE_DARK := Color(0.19, 0.09, 0.3)
const NAVY := Color(0.1, 0.12, 0.3)
const CHROME := Color(0.78, 0.79, 0.84)
const GOLD := Color(0.8, 0.63, 0.3)
const IVORY := Color(0.93, 0.89, 0.8)
const GUNMETAL := Color(0.21, 0.22, 0.25)
const DARK := Color(0.07, 0.06, 0.08)
## The face's plane: the cabinet's front, behind the treads' front ends.
const FACE_Z: float = -0.6
## Base heights: the treads, the chassis, the coin tray, the reels' bottom.
const TREAD_H: float = 1.7
const CHASSIS_TOP: float = 2.4
const TRAY_Y: Vector2 = Vector2(2.65, 3.3)
const REELS_BOTTOM_SHARE: float = 0.38
## How deep the hopper's bin is below the deck.
const HOPPER_DEPTH: float = 0.3
## How many symbols a reel's window shows (the middle one whole, halves above and below).
const WINDOW_SYMBOLS: float = 1.45
## The reels' drums stand out of the face: the middle of each window this far in front of it, curving
## back toward the face at the window's top and bottom; their frame stands out further.
const REEL_Z: float = FACE_Z + 0.62
const FRAME_Z: float = FACE_Z + 0.85
const REEL_CURVE_DEGREES: float = 30.0
const BULB: float = 0.24
const TILT_SHADER: Shader = preload("res://scripts/bosses/the_house/the_house_tilt.gdshader")
## The warm fake light it's lit with when its arena's skin names none (sheen_for): the Marketplace's
## (MarketplaceSkin.sheen_color), where the fight was first built.
const DEFAULT_SHEEN := Color(0.56, 0.42, 0.34)

## The machine's size and where its parts are, in its own space (see the header).
class Shape:
	var width: float = 12.0
	var height: float = 11.5
	var depth: float = 14.0
	var tread_width: float = 1.4
	## The reels: the middle of each (x), their width and height, their gap, and the windows' bottom.
	var reel_x: PackedFloat32Array = PackedFloat32Array()
	var reel_width: float = 3.0
	var reel_height: float = 4.0
	var reel_bottom: float = 4.4
	## The hopper in the top deck: its half width and its front and back (z, both negative).
	var hopper_half_width: float = 5.0
	var hopper_front: float = -1.6
	var hopper_back: float = -13.0
	## The lever's pivot on the right side.
	var lever_pivot := Vector3.ZERO
	var lever_length: float = 3.6

	func reels_top() -> float:
		return reel_bottom + reel_height

	func reels_middle() -> Vector3:
		return Vector3(0.0, reel_bottom + reel_height * 0.5, FACE_Z)


var shape: Shape
## Each reel's place on its strip (in symbols), its smear (0-1) and whether it's locked on 7 (0-1).
var reel_angles := Vector3.ZERO
var reel_blur := Vector3.ZERO
var reel_locked := Vector3.ZERO
## The lever (0 up, 1 pulled all the way down), the lights (0 off, 1 on), the jackpot's celebration (0-1),
## the hopper's lids (0 shut, 1 burst open), how far the treads have turned (metres) and the power (0 at
## its defeat: everything dark).
var lever: float = 0.0
var lights: float = 1.0
var jackpot: float = 0.0
var hopper_open: float = 0.0
var tread_scroll: float = 0.0
var power: float = 1.0
## Its defeat: TILT shown over the reels (0-1), and how far it has collapsed (0-1: tipping forward and
## over as it sinks), with a shake (metres, side to side).
var tilt: float = 0.0
var collapse: float = 0.0
var shake: float = 0.0

var _reels_mat: ShaderMaterial
var _lights_mat: ShaderMaterial
var _hopper_mat: ShaderMaterial
var _tread_mat: ShaderMaterial
var _tilt_mat: ShaderMaterial
var _tilt: MeshInstance3D
var _lever: Node3D
var _lid_left: Node3D
var _lid_right: Node3D


## The shape for a street `street_width` wide (wall to wall) with The House's tuning, its hopper
## `hopper_length` long (its stomp box, TheHouseBody): the machine is as deep as it needs to be for it.
static func shape_for(street_width: float, t: TheHouseTuning, hopper_length: float) -> Shape:
	var s := Shape.new()
	s.width = maxf(street_width - 2.0 * t.street_margin, 4.0)
	s.height = t.height
	s.tread_width = clampf(s.width * 0.12, 0.8, 1.6)
	s.hopper_front = FACE_Z - t.stomp_front_margin
	s.hopper_back = s.hopper_front - hopper_length
	s.depth = maxf(t.depth, -s.hopper_back + t.deck_back_margin)
	s.hopper_half_width = maxf(s.width * 0.5 - 0.55, 1.0)
	var area: float = s.width * 0.8
	var gap: float = clampf(s.width * 0.025, 0.15, 0.3)
	s.reel_width = (area - 2.0 * gap) / 3.0
	s.reel_height = minf(s.reel_width * 1.45, s.height * 0.38)
	s.reel_bottom = s.height * REELS_BOTTOM_SHARE
	s.reel_x = PackedFloat32Array([-(s.reel_width + gap), 0.0, s.reel_width + gap])
	# The lever stands at the face's right edge, outside the reels' frame, its ball above the cabinet's
	# shoulder; pulled, it swings down toward the runner.
	s.lever_length = clampf(s.height * 0.36, 2.6, 5.0)
	s.lever_pivot = Vector3(s.width * 0.5 - 0.32, s.height * 0.6, FACE_Z + 0.3)
	return s


## Builds the machine to `p_shape`, lit with `p_skin`'s warm light (its arena's; solid_material).
func build(p_shape: Shape, p_skin: ZoneSkin = null) -> void:
	shape = p_shape
	for child: Node in get_children():
		child.queue_free()
	var solid: ShaderMaterial = solid_material(p_skin)
	var batch := MeshBatch.new()
	_cabinet(batch.layer(solid))
	batch.commit(self, "Cabinet")
	var emblem := MeshInstance3D.new()
	emblem.name = "Emblem"
	var choice := load("res://data/world/cult_emblem_choice.tres") as CultEmblemChoice
	var option: int = choice.option if choice != null else CultEmblem.Option.B
	var scheme: Dictionary = CultEmblem.default_scheme(option)
	var emblem_size: float = clampf(shape.width * 0.07, 0.5, 0.9)
	emblem.mesh = CultEmblem.build_mesh(option, emblem_size, scheme["metal"], scheme["metal_accent"], 0.0, solid)
	emblem.position = Vector3(0.0, _marquee_y().x + emblem_size * 0.62, FACE_Z + 0.08)
	emblem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emblem)
	_reels_mat = ShaderMaterial.new()
	_reels_mat.shader = load("res://scripts/bosses/the_house/the_house_reels.gdshader") as Shader
	_reels_mat.set_shader_parameter(&"window_symbols", WINDOW_SYMBOLS)
	_reels_mat.set_shader_parameter(&"aspect", shape.reel_width / (shape.reel_height / WINDOW_SYMBOLS))
	_add_mesh("Reels", _reels_mesh(), _reels_mat)
	_lights_mat = ShaderMaterial.new()
	_lights_mat.shader = load("res://scripts/bosses/the_house/the_house_lights.gdshader") as Shader
	_add_mesh("Lights", _lights_mesh(), _lights_mat)
	_tread_mat = ShaderMaterial.new()
	_tread_mat.shader = load("res://scripts/bosses/the_house/the_house_treads.gdshader") as Shader
	_add_mesh("Treads", _treads_mesh(), _tread_mat)
	_hopper_mat = ShaderMaterial.new()
	_hopper_mat.shader = load("res://scripts/bosses/the_house/the_house_hopper.gdshader") as Shader
	var hl: float = shape.hopper_front - shape.hopper_back
	_hopper_mat.set_shader_parameter(&"cells", Vector2(maxf(roundf(shape.hopper_half_width * 2.0 / 0.55), 4.0),
		maxf(roundf(hl / 0.55), 4.0)))
	_add_mesh("Hopper", _hopper_mesh(), _hopper_mat)
	# TILT over the reels' window (its defeat; hidden until then).
	var tilt_w: float = shape.reel_x[2] - shape.reel_x[0] + shape.reel_width
	var tilt_h: float = minf(shape.reel_height * 0.5, tilt_w / 3.2)
	var tilt_quad := QuadMesh.new()
	tilt_quad.size = Vector2(tilt_w, tilt_h)
	_tilt_mat = ShaderMaterial.new()
	_tilt_mat.shader = TILT_SHADER
	_tilt_mat.set_shader_parameter(&"aspect", tilt_w / tilt_h)
	_tilt = _add_mesh("Tilt", tilt_quad, _tilt_mat)
	_tilt.position = Vector3(0.0, shape.reel_bottom + shape.reel_height * 0.5, FRAME_Z + 0.08)
	_tilt.visible = false
	_lever = Node3D.new()
	_lever.name = "Lever"
	_lever.position = shape.lever_pivot
	add_child(_lever)
	var lever_batch := MeshBatch.new()
	_lever_arm(lever_batch.layer(solid))
	lever_batch.commit(_lever, "Arm")
	_lid_left = _lid(-1, solid)
	_lid_right = _lid(1, solid)
	animate()


## The kit's solid material for the machine and its props: lit with its arena's warm fake light
## (sheen_for: the arena skin's own sheen colour).
static func solid_material(skin: ZoneSkin = null) -> ShaderMaterial:
	return MeshKit.solid({"glow_scale": 4.0, "sheen_color": sheen_for(skin), "sheen_strength": 0.16})


## The warm fake light the machine is lit with in `skin`: the skin's `sheen_color` if it has one (the
## Marketplace's skin, the arena's look until the Casino's own is in, task K1), else DEFAULT_SHEEN.
static func sheen_for(skin: ZoneSkin) -> Color:
	var value: Variant = skin.get(&"sheen_color") if skin != null else null
	return value as Color if value is Color else DEFAULT_SHEEN


## Pushes the animated state (the fields above) to the shaders and the moving parts.
func animate() -> void:
	if _reels_mat == null:
		return
	_reels_mat.set_shader_parameter(&"angles", reel_angles)
	_reels_mat.set_shader_parameter(&"blur", reel_blur)
	_reels_mat.set_shader_parameter(&"locked", reel_locked)
	_reels_mat.set_shader_parameter(&"jackpot", jackpot)
	_reels_mat.set_shader_parameter(&"power", power)
	_lights_mat.set_shader_parameter(&"level", lights * power)
	_lights_mat.set_shader_parameter(&"jackpot", jackpot * power)
	_hopper_mat.set_shader_parameter(&"open", hopper_open * power)
	_tread_mat.set_shader_parameter(&"scroll", tread_scroll)
	_tilt.visible = tilt > 0.01
	_tilt_mat.set_shader_parameter(&"on", tilt)
	# Collapsing, it tips forward toward the street and over to one side, shaking.
	var c: float = clampf(collapse, 0.0, 1.0)
	rotation = Vector3(0.38 * c * c, 0.0, 0.16 * c)
	position = Vector3(shake, 0.0, 0.0)
	# Up and leaning back a little at rest; pulled, it swings down toward the runner.
	_lever.rotation = Vector3(lerpf(-0.12, 1.75, clampf(lever, 0.0, 1.0)), 0.0, 0.0)
	var lid: float = clampf(hopper_open, 0.0, 1.0)
	var angle: float = deg_to_rad(118.0) * (1.0 - pow(1.0 - lid, 3.0))
	_lid_left.rotation = Vector3(0.0, 0.0, angle)
	_lid_right.rotation = Vector3(0.0, 0.0, -angle)


## The marquee band over the reels (its bottom and top).
func _marquee_y() -> Vector2:
	return Vector2(shape.reels_top() + 0.45, shape.height - 0.45)


# --- The cabinet ------------------------------------------------------------------------------------

func _cabinet(m: MeshLayer) -> void:
	var s: Shape = shape
	var hw: float = s.width * 0.5
	var back: float = -s.depth
	var tw: float = s.tread_width
	# The chassis between the treads, and its bumper.
	m.box_between(Vector3(-hw + tw, 0.35, back + 0.6), Vector3(hw - tw, CHASSIS_TOP, -0.2), GUNMETAL, 0.0,
		MeshKit.PAT_HULL, MeshKit.NO_BOTTOM)
	m.box_between(Vector3(-hw + tw + 0.2, 0.5, -0.2), Vector3(hw - tw - 0.2, 1.1, 0.25), CHROME, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.NO_BOTTOM)
	# The cabinet, open on top (the deck and the hopper close it).
	m.box_between(Vector3(-hw + 0.1, CHASSIS_TOP, back + 0.3), Vector3(hw - 0.1, s.height - 0.3, FACE_Z), PURPLE, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY & ~MeshKit.FACE_PY)
	_deck(m)
	# Chrome corners down the face, gold bands round the cabinet.
	for side: int in [-1, 1]:
		var x: float = side * (hw - 0.1)
		m.box_between(Vector3(x - 0.18, CHASSIS_TOP, FACE_Z - 0.2), Vector3(x + 0.18, s.height, FACE_Z + 0.12), CHROME)
	for y: float in [CHASSIS_TOP + 0.15, s.height - 0.55]:
		m.box_between(Vector3(-hw + 0.05, y, back + 0.25), Vector3(hw - 0.05, y + 0.18, FACE_Z + 0.05), GOLD, 0.0,
			MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	# The coin tray: a chrome trough jutting out under the reels.
	var tray_hw: float = s.width * 0.3
	m.box_between(Vector3(-tray_hw, TRAY_Y.x, FACE_Z), Vector3(tray_hw, TRAY_Y.x + 0.18, FACE_Z + 0.75), CHROME)
	m.box_between(Vector3(-tray_hw, TRAY_Y.x + 0.18, FACE_Z + 0.6), Vector3(tray_hw, TRAY_Y.y, FACE_Z + 0.75), CHROME)
	m.box_between(Vector3(-tray_hw + 0.2, TRAY_Y.x + 0.25, FACE_Z + 0.01), Vector3(tray_hw - 0.2, TRAY_Y.y + 0.4, FACE_Z + 0.02),
		DARK, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	# The pay table under the reels: a navy panel with gold rules.
	var panel := Vector2(TRAY_Y.y + 0.55, s.reel_bottom - 0.45)
	if panel.y > panel.x + 0.2:
		m.box_between(Vector3(-s.width * 0.38, panel.x, FACE_Z), Vector3(s.width * 0.38, panel.y, FACE_Z + 0.06), NAVY, 0.0,
			MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | MeshKit.FACE_PY | MeshKit.FACE_NY)
		for k: int in 3:
			var y: float = lerpf(panel.x, panel.y, (float(k) + 0.5) / 3.0)
			m.box_between(Vector3(-s.width * 0.34, y - 0.03, FACE_Z + 0.06), Vector3(s.width * 0.34, y + 0.03, FACE_Z + 0.09), GOLD,
				0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	_reel_frame(m)
	_marquee(m)
	# The sirens' housings on the top's front corners.
	for side: int in [-1, 1]:
		var c := Vector3(side * (hw - 0.55), s.height, FACE_Z - 0.5)
		m.box(c + Vector3(0.0, 0.25, 0.0), Vector3(0.7, 0.5, 0.7), CHROME, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	# The lever's hub on the face's right edge.
	m.box(shape.lever_pivot + Vector3(0.0, 0.0, -0.15), Vector3(0.6, 1.0, 0.6), CHROME)


## The top deck round the hopper's opening (the hopper's own inside is drawn by its shader).
func _deck(m: MeshLayer) -> void:
	var s: Shape = shape
	var hw: float = s.width * 0.5 - 0.1
	var top: float = s.height
	var y0: float = top - 0.3
	var hh: float = s.hopper_half_width
	var back: float = -s.depth + 0.3
	m.box_between(Vector3(-hw, y0, s.hopper_front), Vector3(hw, top, FACE_Z), PURPLE_DARK, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PY | MeshKit.FACE_PZ | MeshKit.FACE_NZ)
	m.box_between(Vector3(-hw, y0, back), Vector3(hw, top, s.hopper_back), PURPLE_DARK, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PY | MeshKit.FACE_PZ | MeshKit.FACE_NZ)
	for side: int in [-1, 1]:
		var x0: float = side * hh
		var x1: float = side * hw
		m.box_between(Vector3(minf(x0, x1), y0, s.hopper_back), Vector3(maxf(x0, x1), top, s.hopper_front), PURPLE_DARK,
			0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PY | (MeshKit.FACE_NX if side > 0 else MeshKit.FACE_PX))
	# The bin's dark walls below its rim.
	var floor_y: float = top - HOPPER_DEPTH
	m.box_between(Vector3(-hh, floor_y - 0.05, s.hopper_back), Vector3(hh, floor_y, s.hopper_front), DARK, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
	# Gold edging round the opening.
	m.box_between(Vector3(-hh - 0.12, top, s.hopper_front), Vector3(hh + 0.12, top + 0.06, s.hopper_front + 0.12), GOLD)
	m.box_between(Vector3(-hh - 0.12, top, s.hopper_back - 0.12), Vector3(hh + 0.12, top + 0.06, s.hopper_back), GOLD)


## The chrome frame round the three reel windows (the reels sit just behind it).
func _reel_frame(m: MeshLayer) -> void:
	var s: Shape = shape
	var y0: float = s.reel_bottom
	var y1: float = s.reels_top()
	var x0: float = s.reel_x[0] - s.reel_width * 0.5
	var x1: float = s.reel_x[2] + s.reel_width * 0.5
	var b: float = 0.28
	var z0: float = FACE_Z
	var z1: float = FRAME_Z
	# The dark well the reels turn in.
	m.box_between(Vector3(x0 - b, y0 - b, z0), Vector3(x1 + b, y1 + b, z0 + 0.03), DARK, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PZ)
	m.box_between(Vector3(x0 - b, y1, z0), Vector3(x1 + b, y1 + b, z1), CHROME)
	m.box_between(Vector3(x0 - b, y0 - b, z0), Vector3(x1 + b, y0, z1), CHROME)
	m.box_between(Vector3(x0 - b, y0, z0), Vector3(x0, y1, z1), CHROME)
	m.box_between(Vector3(x1, y0, z0), Vector3(x1 + b, y1, z1), CHROME)
	for i: int in [0, 1]:
		var xa: float = s.reel_x[i] + s.reel_width * 0.5
		var xb: float = s.reel_x[i + 1] - s.reel_width * 0.5
		m.box_between(Vector3(xa, y0, z0), Vector3(xb, y1, z1 - 0.08), CHROME)
	# A gold outline round the frame.
	m.box_between(Vector3(x0 - b - 0.12, y1 + b, z0), Vector3(x1 + b + 0.12, y1 + b + 0.12, z1 + 0.02), GOLD)
	m.box_between(Vector3(x0 - b - 0.12, y0 - b - 0.12, z0), Vector3(x1 + b + 0.12, y0 - b, z1 + 0.02), GOLD)


## The marquee over the reels: a sunburst of ivory and purple rays round the cult's emblem (a gaudy
## casino ornament at a glance: the emblem is the sun, in brushed bronze).
func _marquee(m: MeshLayer) -> void:
	var s: Shape = shape
	var band: Vector2 = _marquee_y()
	if band.y - band.x < 0.6:
		return
	var hw: float = s.width * 0.42
	var z: float = FACE_Z + 0.03
	m.box_between(Vector3(-hw, band.x, FACE_Z), Vector3(hw, band.y, z), NAVY, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	var center := Vector3(0.0, band.x + 0.1, z + 0.01)
	var rays: int = 11
	var r: float = minf(hw * 0.95, (band.y - band.x) * 1.6)
	for i: int in rays:
		if i % 2 == 1:
			continue
		var a0: float = PI * float(i) / float(rays)
		var a1: float = PI * float(i + 1) / float(rays)
		var p0 := center + Vector3(cos(a0) * r, sin(a0) * r, 0.0)
		var p1 := center + Vector3(cos(a1) * r, sin(a1) * r, 0.0)
		p0.y = minf(p0.y, band.y - 0.05)
		p1.y = minf(p1.y, band.y - 0.05)
		p0.x = clampf(p0.x, -hw, hw)
		p1.x = clampf(p1.x, -hw, hw)
		# Clockwise seen from the front (+z): the centre, the ray's later edge, its earlier one.
		m.quad(center, p1, p0, center, IVORY)


## The lever: a chrome arm up from the pivot with a big ivory ball on top (the node turns about x).
func _lever_arm(m: MeshLayer) -> void:
	var length: float = shape.lever_length
	m.prism(Vector3(0.0, -0.1, 0.0), 0.17, length, 8, CHROME)
	var ball: float = clampf(length * 0.14, 0.32, 0.55)
	m.prism(Vector3(0.0, length - ball * 0.15, 0.0), ball * 0.7, ball * 0.25, 10, IVORY)
	m.prism(Vector3(0.0, length + ball * 0.1, 0.0), ball, ball * 0.8, 10, IVORY)
	m.prism(Vector3(0.0, length + ball * 0.9, 0.0), ball * 0.7, ball * 0.25, 10, IVORY)


## One of the hopper's two lids, hinged on the opening's long side `side` (-1 left, 1 right): shut it
## covers its half of the opening; the node turns about z to burst it open.
func _lid(side: int, solid: ShaderMaterial) -> Node3D:
	var s: Shape = shape
	var pivot := Node3D.new()
	pivot.name = "LidLeft" if side < 0 else "LidRight"
	pivot.position = Vector3(side * s.hopper_half_width, s.height, (s.hopper_front + s.hopper_back) * 0.5)
	add_child(pivot)
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(solid)
	var w: float = s.hopper_half_width
	var l: float = s.hopper_front - s.hopper_back
	m.box_between(Vector3(0.0 if side < 0 else -w, 0.0, -l * 0.5), Vector3(w if side < 0 else 0.0, 0.14, l * 0.5), GOLD)
	for k: int in 4:
		var z: float = lerpf(-l * 0.5, l * 0.5, (float(k) + 0.5) / 4.0)
		m.box_between(Vector3(0.05 if side < 0 else -w + 0.05, 0.14, z - 0.06),
			Vector3(w - 0.05 if side < 0 else -0.05, 0.2, z + 0.06), CHROME)
	batch.commit(pivot, "Lid")
	return pivot


# --- Meshes on their own shaders ------------------------------------------------------------------

func _add_mesh(node_name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return inst


## The three reels: each a strip of drum curving back at its top and bottom, UV across and down it, UV2.x
## its index.
func _reels_mesh() -> ArrayMesh:
	var s: Shape = shape
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var rows: int = 8
	var half_angle: float = deg_to_rad(REEL_CURVE_DEGREES)
	var radius: float = s.reel_height * 0.5 / sin(half_angle)
	for reel: int in 3:
		var x0: float = s.reel_x[reel] - s.reel_width * 0.5
		var x1: float = s.reel_x[reel] + s.reel_width * 0.5
		for r: int in rows:
			var v0: float = float(r) / rows
			var v1: float = float(r + 1) / rows
			var a0: float = lerpf(half_angle, -half_angle, v0)
			var a1: float = lerpf(half_angle, -half_angle, v1)
			var mid: float = s.reel_bottom + s.reel_height * 0.5
			var p0 := Vector3(0.0, mid + sin(a0) * radius, REEL_Z - (radius - cos(a0) * radius))
			var p1 := Vector3(0.0, mid + sin(a1) * radius, REEL_Z - (radius - cos(a1) * radius))
			var quad: Array[Vector3] = [Vector3(x0, p0.y, p0.z), Vector3(x1, p0.y, p0.z), Vector3(x1, p1.y, p1.z),
				Vector3(x0, p1.y, p1.z)]
			var quv: Array[Vector2] = [Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1), Vector2(0.0, v1)]
			for i: int in [0, 1, 2, 0, 2, 3]:
				verts.append(quad[i])
				uvs.append(quv[i])
				uv2s.append(Vector2(reel, 0.0))
	return _array_mesh(verts, uvs, uv2s)


## The bulbs (kind 0) round the reels' frame, along the marquee and down the face's corners, and the two
## sirens (kind 1); UV2.x each bulb's place along its row (for the chase).
func _lights_mesh() -> ArrayMesh:
	var s: Shape = shape
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var z: float = FRAME_Z + 0.04
	var x0: float = s.reel_x[0] - s.reel_width * 0.5 - 0.42
	var x1: float = s.reel_x[2] + s.reel_width * 0.5 + 0.42
	var y0: float = s.reel_bottom - 0.42
	var y1: float = s.reels_top() + 0.42
	# Round the reels' frame, clockwise from its top left.
	var ring: Array[Vector3] = [Vector3(x0, y1, z), Vector3(x1, y1, z), Vector3(x1, y0, z), Vector3(x0, y0, z), Vector3(x0, y1, z)]
	var index: float = 0.0
	for k: int in 4:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[k + 1]
		var count: int = maxi(roundi(a.distance_to(b) / 0.5), 1)
		for i: int in count:
			_bulb(verts, uvs, uv2s, a.lerp(b, float(i) / count), BULB, index, 0.0)
			index += 1.0
	# Along the marquee's top edge, and down both corners of the face.
	var band: Vector2 = _marquee_y()
	var hw: float = s.width * 0.42
	var count_top: int = maxi(roundi(hw * 2.0 / 0.5), 2)
	for i: int in count_top + 1:
		_bulb(verts, uvs, uv2s, Vector3(lerpf(-hw, hw, float(i) / count_top), band.y + 0.18, FACE_Z + 0.1), BULB, float(i), 0.0)
	for side: int in [-1, 1]:
		var x: float = side * (s.width * 0.5 - 0.1)
		var count_side: int = maxi(roundi((s.height - CHASSIS_TOP) / 0.6), 2)
		for i: int in count_side:
			_bulb(verts, uvs, uv2s, Vector3(x, s.height - 0.3 - i * 0.6, FACE_Z + 0.16), BULB, float(i), 0.0)
	# The sirens, facing the runner.
	for side: int in [-1, 1]:
		_bulb(verts, uvs, uv2s, Vector3(side * (s.width * 0.5 - 0.55), s.height + 0.3, FACE_Z - 0.14), 0.62,
			0.0 if side < 0 else 1.0, 1.0)
	return _array_mesh(verts, uvs, uv2s)


func _bulb(verts: PackedVector3Array, uvs: PackedVector2Array, uv2s: PackedVector2Array, c: Vector3, size: float,
		index: float, kind: float) -> void:
	var h: float = size * 0.5
	var quad: Array[Vector3] = [c + Vector3(-h, h, 0.0), c + Vector3(h, h, 0.0), c + Vector3(h, -h, 0.0), c + Vector3(-h, -h, 0.0)]
	var quv: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		verts.append(quad[i])
		uvs.append(quv[i])
		uv2s.append(Vector2(index, kind))


## The two treads, the length of the machine, with normals (they're lit).
func _treads_mesh() -> ArrayMesh:
	var s: Shape = shape
	var st := SurfaceTool.new()
	var box := BoxMesh.new()
	box.size = Vector3(s.tread_width, TREAD_H, s.depth + 0.4)
	for side: int in [-1, 1]:
		var xform := Transform3D(Basis.IDENTITY, Vector3(side * (s.width * 0.5 - s.tread_width * 0.5), TREAD_H * 0.5,
			-s.depth * 0.5 + 0.2))
		st.append_from(box, 0, xform)
	return st.commit()


## The hopper's red-hot inside: one quad at the bin's floor, UV 0-1 over it.
func _hopper_mesh() -> ArrayMesh:
	var s: Shape = shape
	var y: float = s.height - HOPPER_DEPTH + 0.01
	var hh: float = s.hopper_half_width
	var quad: Array[Vector3] = [Vector3(-hh, y, s.hopper_back), Vector3(hh, y, s.hopper_back), Vector3(hh, y, s.hopper_front),
		Vector3(-hh, y, s.hopper_front)]
	var quv: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for i: int in [0, 1, 2, 0, 2, 3]:
		verts.append(quad[i])
		uvs.append(quv[i])
		uv2s.append(Vector2.ZERO)
	return _array_mesh(verts, uvs, uv2s)


static func _array_mesh(verts: PackedVector3Array, uvs: PackedVector2Array, uv2s: PackedVector2Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Mesh instances, surfaces and vertices drawn now (the draw budget).
func draw_stats() -> Dictionary:
	var out := {"instances": 0, "surfaces": 0, "vertices": 0}
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var g := node as MeshInstance3D
		if not g.is_visible_in_tree() or g.mesh == null:
			continue
		out["instances"] += 1
		out["surfaces"] += g.mesh.get_surface_count()
		for i: int in g.mesh.get_surface_count():
			out["vertices"] += (g.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return out
