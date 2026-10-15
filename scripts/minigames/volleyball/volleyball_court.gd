class_name VolleyballCourt
extends Node3D
## The volleyball court (VolleyballMatch): raked sand laid over the street across every lane, from behind the runner's
## line to behind the rival's, with its white boundary tapes (volleyball_court.gdshader), and the net across the street
## between two padded posts on the side lines. Scenery only: nothing here has collision, so it never touches gameplay
## (the runner walks up to it, stops and plays, and the net sinks into the sand before they run on, sink()). Built in
## world space (x across the street, y up, z = -distance), like the track, from the match's numbers.

const COURT_SHADER: Shader = preload("res://scripts/minigames/volleyball/volleyball_court.gdshader")
const NET_SHADER: Shader = preload("res://scripts/minigames/volleyball/volleyball_net.gdshader")
const PROP_SHADER: Shader = preload("res://scripts/minigames/volleyball/volleyball_prop.gdshader")
## How high the court's sand sits over the street's floor (no z-fighting, too thin to see as a step).
const SAND_LIFT: float = 0.012
## How far behind the runner's line the sand runs (past the chase camera, MovementTuning.camera_distance 7.5 m).
const SAND_BEHIND: float = 10.0
const POST_RADIUS: float = 0.05
const POST_COLOR := Color(0.78, 0.8, 0.82)
## The posts' padding: the Beach's ocean blue (the rival's shorts), never a hazard colour.
const PAD_COLOR := Color(0.12, 0.33, 0.6)
const PAD_HEIGHT: float = 1.0

## The net and its posts (they sink together).
var net_root: Node3D
var sand: MeshInstance3D
var net: MeshInstance3D

var _sink_from: float = 0.0
var _sink_left: float = -1.0
var _sink_seconds: float = 1.0
var _sink_depth: float = 0.0


## Builds the court: side lines at +-half_x, the runner's line at runner_z, the net at net_z, the rival's line at
## rival_z (world z; the rival's side is further along, so rival_z < net_z < runner_z), from `t`'s sizes, in the
## sand colours of `skin` if it has them (the Beach's).
func build(half_x: float, runner_z: float, net_z: float, rival_z: float, t: VolleyballTuning, skin: ZoneSkin) -> void:
	name = "Court"
	# The end lines, end_margin behind each player's line. The sand runs on past them and breaks up into the street:
	# behind the rival's, a little way; behind the runner's, past the chase camera, so its broken edge never shows.
	var near: float = runner_z + t.end_margin
	var far: float = rival_z - t.end_margin
	var sand_near: float = runner_z + maxf(t.end_margin + 1.2, SAND_BEHIND)
	var sand_far: float = far - 1.2
	var mid: float = (sand_near + sand_far) * 0.5
	var half_len: float = (sand_near - sand_far) * 0.5
	var plane := PlaneMesh.new()
	plane.size = Vector2((half_x + 0.12) * 2.0, half_len * 2.0)
	plane.subdivide_depth = 0
	plane.subdivide_width = 0
	var mat := ShaderMaterial.new()
	mat.shader = COURT_SHADER
	mat.set_shader_parameter(&"half_x", half_x)
	mat.set_shader_parameter(&"near_z", near - mid)
	mat.set_shader_parameter(&"far_z", far - mid)
	mat.set_shader_parameter(&"net_z", net_z - mid)
	mat.set_shader_parameter(&"quad_half", Vector2(plane.size.x * 0.5, half_len))
	var light: Variant = skin.get(&"sand_light_color") if skin != null else null
	var dark: Variant = skin.get(&"sand_color") if skin != null else null
	if light is Color:
		mat.set_shader_parameter(&"sand_color", light)
	if dark is Color:
		mat.set_shader_parameter(&"sand_dark_color", dark)
	sand = MeshInstance3D.new()
	sand.name = "Sand"
	sand.mesh = plane
	sand.material_override = mat
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sand.position = Vector3(0.0, SAND_LIFT, mid)
	add_child(sand)

	net_root = Node3D.new()
	net_root.name = "Net"
	add_child(net_root)
	var quad := QuadMesh.new()
	quad.size = Vector2(half_x * 2.0, t.net_band)
	var net_mat := ShaderMaterial.new()
	net_mat.shader = NET_SHADER
	net_mat.set_shader_parameter(&"size", quad.size)
	net = MeshInstance3D.new()
	net.name = "Mesh"
	net.mesh = quad
	net.material_override = net_mat
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	net.position = Vector3(0.0, t.net_height - t.net_band * 0.5, net_z)
	net_root.add_child(net)
	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = POST_RADIUS
		cyl.bottom_radius = POST_RADIUS
		cyl.height = t.net_height + 0.12
		cyl.radial_segments = 8
		cyl.rings = 1
		post.mesh = cyl
		post.material_override = _prop_material(POST_COLOR)
		post.position = Vector3(side * (half_x + POST_RADIUS), cyl.height * 0.5, net_z)
		net_root.add_child(post)
		var pad := MeshInstance3D.new()
		var pad_mesh := CylinderMesh.new()
		pad_mesh.top_radius = POST_RADIUS * 1.9
		pad_mesh.bottom_radius = POST_RADIUS * 1.9
		pad_mesh.height = PAD_HEIGHT
		pad_mesh.radial_segments = 8
		pad_mesh.rings = 1
		pad.mesh = pad_mesh
		pad.material_override = _prop_material(PAD_COLOR)
		pad.position = Vector3(side * (half_x + POST_RADIUS), PAD_HEIGHT * 0.5, net_z)
		net_root.add_child(pad)
	_sink_depth = t.net_height + 0.4


## Sinks the net and its posts into the sand over `seconds` (the match is over: the runner runs on over where it
## stood). The court's sand and lines stay.
func sink(seconds: float) -> void:
	_sink_seconds = maxf(seconds, 0.01)
	_sink_left = _sink_seconds
	_sink_from = net_root.position.y


## True once the net has sunk out of the way (or was never up).
func sunk() -> bool:
	return net_root == null or net_root.position.y <= -_sink_depth + 0.001


## Moves the sinking on (the match calls it from its physics step).
func advance(delta: float) -> void:
	if _sink_left < 0.0:
		return
	_sink_left = maxf(_sink_left - delta, 0.0)
	var k: float = 1.0 - _sink_left / _sink_seconds
	net_root.position.y = lerpf(_sink_from, -_sink_depth, k * k)
	net_root.visible = not is_zero_approx(_sink_left)
	if is_zero_approx(_sink_left):
		_sink_left = -1.0


static func _prop_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PROP_SHADER
	m.set_shader_parameter(&"color", color)
	return m
