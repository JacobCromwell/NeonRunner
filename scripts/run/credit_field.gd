class_name CreditField
extends Node3D
## Every credit in the level (GDD §7). Credits keep one look in every zone (like hazards, they're
## part of the game's language): four denominations told apart by shape and colour, so they don't
## rely on colour alone. Their colours come from the UI style (data/ui/ui_style.tres, credit_colors),
## so the credits in the world and the icons in the HUD and shop always match; none of them uses a
## hazard colour (yellow signs, orange gap edges, pink fences). Each denomination is one MultiMesh (a few draw calls for the whole level)
## spinning in a shader, so idle credits cost no CPU. Collected credits are hidden, never freed.
##
## A credit is collected when the player's hitbox, grown by a pickup margin and swept over this
## frame's motion, reaches it. The magnet (GDD §8) pulls credits on the player's own surface,
## never further sideways than the adjacent lanes.

signal collected(value: int, position: Vector3)

## Pickup reach beyond the damage hitbox (generous: credits should feel easy to grab).
const PICKUP_MARGIN := Vector3(0.45, 0.35, 0.35)
## DESIGN-TBD: the credit look per denomination (shape and size here, colour in the UI style):
## a silver chip, an azure ringed chip, a violet diamond and an ice-white gem.
const LOOKS: Dictionary = {
	1: {"shape": "coin", "radius": 0.2},
	5: {"shape": "hex", "radius": 0.28},
	25: {"shape": "gem", "radius": 0.3},
	100: {"shape": "big_gem", "radius": 0.42},
}
const SPIN_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 2.2;
uniform float spin_speed = 3.0;
void vertex() {
	float a = TIME * spin_speed;
	mat3 r = mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
}
void fragment() {
	ALBEDO = color.rgb;
	EMISSION = color.rgb * energy;
	METALLIC = 0.7;
	ROUGHNESS = 0.3;
}
"""

enum State { IDLE, PULLED, GONE }

## Credits placed during the run (place()) share MultiMeshes of this many instances.
const PLACE_CHUNK: int = 32

var world: RunWorld
## Magnet pull radius in metres (0 = off). The magnet power-up sets it.
var magnet_radius: float = 0.0
var magnet_pull_speed: float = 30.0

## One per credit: {value, surface, lane, side, pos: Vector3, at, state, mm: MultiMesh, idx}.
var _entries: Array[Dictionary] = []
var _pulled: Array[Dictionary] = []
var _next: int = 0
var _multimeshes: Dictionary = {}
## Placed credits' MultiMeshes (place()): denomination → [MultiMesh], the last one filling.
var _placed: Dictionary = {}
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


func setup(p_world: RunWorld) -> void:
	world = p_world
	for child: Node in get_children():
		child.queue_free()
	_entries.clear()
	_pulled.clear()
	_multimeshes.clear()
	_placed.clear()
	_next = 0
	var by_value: Dictionary = {}
	for c: Dictionary in world.layout.credits:
		var value: int = denomination(int(c["value"]))
		var e := {"value": value, "surface": String(c["surface"]), "lane": int(c.get("lane", 0)),
			"side": int(c.get("side", 0)), "at": float(c["at"]), "state": State.IDLE,
			"pos": _world_pos(c)}
		_entries.append(e)
		if not by_value.has(value):
			by_value[value] = []
		(by_value[value] as Array).append(e)
	for value: int in by_value:
		var list: Array = by_value[value]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_for(value)
		mm.instance_count = list.size()
		for i: int in list.size():
			var e: Dictionary = list[i]
			e["mm"] = mm
			e["idx"] = i
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, e["pos"]))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = material_for(value)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		_multimeshes[value] = inst


## Credits not collected yet.
func remaining() -> int:
	var n: int = 0
	for e: Dictionary in _entries:
		if e["state"] != State.GONE:
			n += 1
	return n


## Places credits during the run (GDD §10, The House's jackpot: "a fountain of real credits to grab"):
## entries like LevelLayout.credits' ({surface, lane, side, at, value, height}), collected (and pulled
## by the magnet) like the level's own from now on. Each denomination's placed credits share MultiMeshes
## of PLACE_CHUNK instances, so a fountain costs a draw or two. Returns how many were placed.
func place(credits: Array[Dictionary]) -> int:
	for c: Dictionary in credits:
		var value: int = denomination(int(c["value"]))
		var e := {"value": value, "surface": String(c.get("surface", "floor")), "lane": int(c.get("lane", 0)),
			"side": int(c.get("side", 0)), "at": float(c["at"]), "state": State.IDLE, "pos": _world_pos(c)}
		var chunks: Array = _placed.get(value, [])
		_placed[value] = chunks
		if chunks.is_empty() or (chunks[-1] as MultiMesh).visible_instance_count >= PLACE_CHUNK:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh_for(value)
			mm.instance_count = PLACE_CHUNK
			mm.visible_instance_count = 0
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			inst.material_override = material_for(value)
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(inst)
			chunks.append(mm)
		var chunk: MultiMesh = chunks[-1]
		e["mm"] = chunk
		e["idx"] = chunk.visible_instance_count
		chunk.set_instance_transform(e["idx"], Transform3D(Basis.IDENTITY, e["pos"]))
		chunk.visible_instance_count += 1
		# The field walks its credits in track order from _next: keep that order.
		var i: int = _entries.bsearch_custom(e, func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["at"]) < float(b["at"]), false)
		_entries.insert(maxi(i, _next), e)
	return credits.size()


func _physics_process(delta: float) -> void:
	if world == null or world.player == null or not world.player.alive or not world.player.running:
		return
	var player: Player = world.player
	var motion: float = player.speed * delta
	var box: AABB = player.hurtbox_aabb()
	box = AABB(box.position - PICKUP_MARGIN, box.size + PICKUP_MARGIN * 2.0)
	box = box.merge(AABB(box.position + Vector3(0.0, 0.0, motion), box.size))
	var reach: float = maxf(magnet_radius * 2.5, 2.0)
	var d: float = player.distance

	while _next < _entries.size() and float(_entries[_next]["at"]) < d - 3.0:
		_next += 1
	var i: int = _next
	while i < _entries.size() and float(_entries[i]["at"]) <= d + reach:
		var e: Dictionary = _entries[i]
		i += 1
		if e["state"] != State.IDLE:
			continue
		if box.has_point(e["pos"]):
			_collect(e)
		elif magnet_radius > 0.0 and _in_magnet(e, player):
			e["state"] = State.PULLED
			_pulled.append(e)

	if not _pulled.is_empty():
		_update_pulled(player, box, delta)


func _in_magnet(e: Dictionary, player: Player) -> bool:
	var surface: String = player.surface_name()
	if e["surface"] != surface:
		return false
	if surface == "wall" and e["side"] != player.wall_side:
		return false
	var offset: Vector3 = (e["pos"] as Vector3) - (player.hurtbox_aabb().get_center())
	var ahead: float = -offset.z
	if ahead < -1.0 or ahead > magnet_radius * 2.5:
		return false
	# GDD §8: the pull never reaches past the lanes next to the player's.
	var lateral_cap: float = world.geo.lane_width * 1.25
	var lateral: float = absf(offset.x) if surface != "wall" else absf(offset.y)
	return lateral <= minf(magnet_radius, lateral_cap)


func _update_pulled(player: Player, box: AABB, delta: float) -> void:
	var target: Vector3 = player.hurtbox_aabb().get_center()
	for j: int in range(_pulled.size() - 1, -1, -1):
		var e: Dictionary = _pulled[j]
		if e["state"] != State.PULLED:
			_pulled.remove_at(j)
			continue
		var pos: Vector3 = e["pos"]
		var step: float = (magnet_pull_speed + player.speed) * delta
		pos = pos.move_toward(target, step)
		e["pos"] = pos
		(e["mm"] as MultiMesh).set_instance_transform(e["idx"], Transform3D(Basis.IDENTITY, pos))
		if box.has_point(pos) or pos.distance_to(target) < 0.5:
			_collect(e)
			_pulled.remove_at(j)


func _collect(e: Dictionary) -> void:
	e["state"] = State.GONE
	var pos: Vector3 = e["pos"]
	(e["mm"] as MultiMesh).set_instance_transform(e["idx"], Transform3D(Basis().scaled(Vector3.ZERO), pos))
	var value: int = e["value"]
	world.score.add_credit(value)
	world.play_sfx(StringName("credit_%d" % value))
	world.effects.burst(pos, color_of(value), 6 if value < 25 else 14, 0.25 if value < 25 else 0.5)
	collected.emit(value, pos)


func _world_pos(c: Dictionary) -> Vector3:
	var at: float = float(c["at"])
	var height: float = float(c.get("height", 0.7))
	var z: float = TrackGeometry.world_z(at)
	match String(c["surface"]):
		"ceiling":
			return Vector3(world.geo.lane_x(int(c["lane"])), world.tuning.ceiling_height - height, z)
		"wall":
			var side: int = int(c["side"])
			return Vector3(side * (world.geo.wall_x() - 0.55), height, z)
	return Vector3(world.geo.lane_x(int(c["lane"])), height, z)


## A thief's vacuum (GDD §9.12, the Tithe Collector; task C5): the floor credit in `lane`, still idle,
## closest to `at` metres along the track, within `reach` either way. Hides it (collected, never freed:
## it never reaches the player) and returns `{value, pos}`, or `{}` when there is none in reach, so a
## thief only ever takes the credits in its own path.
func take_near(lane: int, at: float, reach: float) -> Dictionary:
	var best: int = -1
	var best_d: float = reach
	for i: int in _entries.size():
		var e: Dictionary = _entries[i]
		if e["state"] != State.IDLE or e["surface"] != "floor" or int(e["lane"]) != lane:
			continue
		var d: float = absf(float(e["at"]) - at)
		if d <= best_d:
			best = i
			best_d = d
	if best < 0:
		return {}
	var e: Dictionary = _entries[best]
	var out: Dictionary = {"value": e["value"], "pos": e["pos"]}
	e["state"] = State.GONE
	(e["mm"] as MultiMesh).set_instance_transform(e["idx"], Transform3D(Basis().scaled(Vector3.ZERO), e["pos"]))
	return out


## The denomination a credit worth `value` shows as: the largest one not above it.
static func denomination(value: int) -> int:
	var best: int = 1
	for v: int in LOOKS:
		if value >= v:
			best = maxi(best, v)
	return best


## The denomination's colour, shared with the UI's credit icons.
static func color_of(value: int) -> Color:
	return UiTheme.credit_color(value)


## A denomination's spinning, glowing material (one per denomination, shared by every credit drawn in
## its look: the field's, and RunEffects' coin streams).
static func material_for(value: int) -> Material:
	if not _materials.has(value):
		var shader := Shader.new()
		shader.code = SPIN_SHADER
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"color", color_of(value))
		m.set_shader_parameter(&"energy", 2.0 if value < 25 else 3.0)
		m.set_shader_parameter(&"spin_speed", 3.0 if value < 100 else 1.8)
		_materials[value] = m
	return _materials[value]


## A denomination's mesh (LOOKS: its shape and size).
static func mesh_for(value: int) -> Mesh:
	if _meshes.has(value):
		return _meshes[value]
	var look: Dictionary = LOOKS[value]
	var r: float = look["radius"]
	var mesh: Mesh
	match String(look["shape"]):
		"coin", "hex":
			var cyl := CylinderMesh.new()
			cyl.top_radius = r
			cyl.bottom_radius = r
			cyl.height = 0.06 if look["shape"] == "coin" else 0.08
			cyl.radial_segments = 12 if look["shape"] == "coin" else 6
			cyl.rings = 1
			# Stand the disc up so its face points along the track.
			var st := SurfaceTool.new()
			st.append_from(cyl, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
			mesh = st.commit()
		_:
			mesh = _gem(r, r * (1.6 if look["shape"] == "big_gem" else 1.3))
	_meshes[value] = mesh
	return mesh


## An octahedron-style gem: `radius` wide, `height` tall.
static func _gem(radius: float, height: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.0, height * 0.5, 0.0)
	var bottom := Vector3(0.0, -height * 0.5, 0.0)
	var ring: Array[Vector3] = []
	for i: int in 6:
		var a: float = TAU * i / 6.0
		ring.append(Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	for i: int in 6:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 6]
		for tri: Array in [[top, b, a], [bottom, a, b]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for v: Vector3 in tri:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()
