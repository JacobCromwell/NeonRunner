class_name EnforcerTruckModel
extends Node3D
## The Enforcer Truck's look (GDD §9.13: "a heavy armoured truck, police-style, distinct from the hover truck,
## with headlights and a red-and-blue light bar. Cyborgs it picks up ride on its roof"; proposed: its body
## follows the zone's skin like the hover truck's). Built in code from the enemies' kit like the hover truck
## and the Buzz Overdrive: a wheeled riot truck with a push bar, a sloped armoured nose, a slatted slit
## windscreen, a long armoured box behind, a light bar on the roof, hatches for its riders and a gun ring. Safe
## and solid parts are matte; only its lights glow: the white headlights, and the light bar's red and blue
## (the enemy's own colours, never the safe cyan). Its riders are crouching cyborg gunners whose screen faces
## glow the cult feed's cold white, the only glow a cyborg has besides its charge-up.
##
## Model space: it faces -z (its direction of travel, toward the runner ahead of it); the origin is on the floor
## under the middle of its front; its body runs back along +z. Its profile rises from a low nose to its roof
## well behind the front, and its riders crouch low behind the light bar, so at its close gap behind the runner
## (EnforcerTruckTuning.close_gap) nothing of it rises into the camera's line of sight to the runner's feet
## (GDD §9.13: while that close it must not hide the runner; tests/suites/test_enforcer_truck.gd checks every
## vertex). Three looks (look_of): clean police paint (navy, with a white roof and nose), weathered (soot and
## rust, for the zones whose enemies weather), and gilded (ivory and unlit gold, for the Golden Zone and the
## Marketplace's casino crowd). Draw calls: the body (one surface in vertex colours), the headlights, the two
## halves of the light bar, and two per rider shown (body, face); about 1,500 triangles with three riders.
## Built once per look and shared (static caches), so a truck spawned in play makes no mesh or material.
##
## The floor lights (floor_lights()) are the truck's own: cheap additive shapes on the floor of its lane, not
## real lights (phones and the Compatibility renderer): its headlight beams thrown forward, and the light bar's
## red and blue washes. The truck keeps them on the floor while the model hops.

## The enemies' merger of primitives, one surface per material (the hover truck's kit): the glowing parts.
const PartBatch := preload("res://scripts/enemies/mesh_batch.gd")
const HEADLIGHT := Color(0.92, 0.96, 1.0)
## The light bar's colours: the enemy fire's red, and a deep police blue kept well away from the safe cyan.
const BAR_RED := Color(1.0, 0.1, 0.07)
const BAR_BLUE := Color(0.12, 0.28, 1.0)
## The riders' screen faces: the cyborgs' cold white LED (CyborgKit).
const FACE := Color(0.82, 0.9, 1.0)
## Where a rider crouches on the roof (x, and z from the front), in boarding order: the two hatches behind the
## light bar, then the gun ring further back.
const RIDER_SLOTS: Array[Vector2] = [Vector2(-0.5, 3.55), Vector2(0.5, 3.55), Vector2(0.0, 4.9)]
## A rider's height over the roof (its screen head's top) and the gun ring's lift for the third.
const RIDER_HEIGHT: float = 0.74
const RING_LIFT: float = 0.12
## The light bar: its middle along the truck (z from the front), its height over the roof.
const BAR_Z: float = 2.72
const BAR_HEIGHT: float = 0.11
## The floor lights' reach ahead of its front (metres).
const BEAM_REACH: float = 16.0
const WASH_REACH: float = 7.5

## Meshes per look and size: {body, lamps, bar_red, bar_blue, rider_body, rider_face}.
static var _meshes: Dictionary = {}
## Materials made once: the body's matte vertex-colour material, the floor lights' (bright, dim), the light
## bar's halves (bright, dim, steady).
static var _materials: Dictionary = {}
## The floor lights' meshes: {beam, wash_red, wash_blue}.
static var _floor_meshes: Dictionary = {}
static var _prims: Dictionary = {}

var body: MeshInstance3D
var lamps: MeshInstance3D
var bar_red: MeshInstance3D
var bar_blue: MeshInstance3D
var riders: Array[Node3D] = []
## Which half of the light bar is lit (0 red, 1 blue), or -1: both, steady (Reduced flashing).
var flash_phase: int = -2


## Builds the look for a zone's enemy variant (ZoneSkin.enemy_variant) at `size` (width, roof height, length).
func build(variant: StringName, size: Vector3) -> void:
	var look: StringName = look_of(variant)
	var m: Dictionary = meshes_for(look, size)
	body = _node(self, m["body"], "Body")
	lamps = _node(self, m["lamps"], "Headlights")
	bar_red = _node(self, m["bar_red"], "BarRed")
	bar_blue = _node(self, m["bar_blue"], "BarBlue")
	for i: int in RIDER_SLOTS.size():
		var slot := Node3D.new()
		slot.name = "Rider%d" % i
		var s: Vector2 = RIDER_SLOTS[i]
		slot.position = Vector3(s.x, size.y + (RING_LIFT if i == 2 else 0.0), s.y)
		add_child(slot)
		_node(slot, m["rider_body"], "Body")
		_node(slot, m["rider_face"], "Face")
		slot.visible = false
		riders.append(slot)
	set_flash(0, false)


## Shows the first `count` riders (0 to 3).
func set_riders(count: int) -> void:
	for i: int in riders.size():
		riders[i].visible = i < count


## The light bar: the red half lit (phase 0) or the blue half (phase 1), the other dim; with `reduced`
## (Reduced flashing) both lit, steady and softer.
func set_flash(phase: int, reduced: bool) -> void:
	var p: int = -1 if reduced else phase
	if p == flash_phase:
		return
	flash_phase = p
	if p < 0:
		bar_red.material_override = bar_material(BAR_RED, &"steady")
		bar_blue.material_override = bar_material(BAR_BLUE, &"steady")
	else:
		bar_red.material_override = bar_material(BAR_RED, &"bright" if p == 0 else &"dim")
		bar_blue.material_override = bar_material(BAR_BLUE, &"bright" if p == 1 else &"dim")


## Draw calls of what it shows now (the riders shown).
func draw_call_count() -> int:
	var n: int = 0
	for mi: MeshInstance3D in _shown_meshes():
		n += mi.mesh.get_surface_count()
	return n


## Triangles of what it shows now (the riders shown).
func triangle_count() -> int:
	var n: int = 0
	for mi: MeshInstance3D in _shown_meshes():
		n += _triangles(mi.mesh)
	return n


func _shown_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in _mesh_nodes():
		if mi.get_parent() == self or (mi.get_parent() as Node3D).visible:
			out.append(mi)
	return out


## Every material the model draws with (the light bar's every state too), and the part it's on (tests: only
## the lights and the riders' faces glow).
func materials() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mi: MeshInstance3D in _mesh_nodes():
		for s: int in mi.mesh.get_surface_count():
			out.append({"part": String(mi.get_parent().name) + "/" + String(mi.name) if mi.get_parent() != self else String(mi.name),
				"material": mi.mesh.surface_get_material(s)})
	for color: Color in [BAR_RED, BAR_BLUE]:
		for state: StringName in [&"bright", &"dim", &"steady"]:
			out.append({"part": "light bar (%s)" % state, "material": bar_material(color, state)})
	return out


## Every vertex of what it shows (the body, the light bar and the riders shown), in the model's space: what
## the close-up's line-of-sight check tests.
func solid_vertices() -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi: MeshInstance3D in _shown_meshes():
		var parent: Node3D = mi.get_parent() as Node3D
		var xf: Transform3D = mi.transform if parent == self else parent.transform * mi.transform
		for s: int in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				out.append(xf * v)
	return out


func _mesh_nodes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = [body, lamps, bar_red, bar_blue]
	for slot: Node3D in riders:
		for c: Node in slot.get_children():
			if c is MeshInstance3D:
				out.append(c as MeshInstance3D)
	return out


static func _triangles(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty():
			n += (idx as PackedInt32Array).size() / 3
		else:
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _node(parent: Node3D, mesh: Mesh, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# --- Looks -------------------------------------------------------------------------------------------

## The look for a zone's enemy variant: weathered where the zone's enemies weather (the Dead Zone's burned
## look, Gangland's scavengers), gilded in the Golden Zone and the Marketplace, clean police paint anywhere
## else (the Neon City, the Corporate zone).
static func look_of(variant: StringName) -> StringName:
	match variant:
		&"burned", &"scavenger":
			return &"weathered"
		&"golden", &"casino":
			return &"gilded"
	return &"clean"


## The meshes for a look at `size`, built once: {body, lamps, bar_red, bar_blue, rider_body, rider_face}.
static func meshes_for(look: StringName, size: Vector3) -> Dictionary:
	var key: String = "%s|%s" % [look, size]
	if _meshes.has(key):
		return _meshes[key]
	var out := {
		"body": _body(look, size),
		"lamps": _lamps(size),
		"bar_red": _bar(-1.0, size),
		"bar_blue": _bar(1.0, size),
		"rider_body": _rider(look),
		"rider_face": _rider_face(),
	}
	_meshes[key] = out
	return out


## The body's colours per look: paint (the lower body), roof (the upper body, nose and roof), dark (push bar,
## underbody, slats), steel, glass, rubber, stripe (the livery band along its sides) and trim.
static func palette(look: StringName) -> Dictionary:
	match look:
		&"weathered":
			return {"paint": Color(0.17, 0.15, 0.13), "roof": Color(0.4, 0.37, 0.33), "dark": Color(0.08, 0.075, 0.07),
				"steel": Color(0.4, 0.37, 0.33), "glass": Color(0.05, 0.05, 0.05), "rubber": Color(0.06, 0.055, 0.05),
				"stripe": Color(0.38, 0.24, 0.14), "trim": Color(0.3, 0.2, 0.13)}
		&"gilded":
			return {"paint": Color(0.8, 0.76, 0.67), "roof": Color(0.9, 0.87, 0.79), "dark": Color(0.16, 0.14, 0.12),
				"steel": Color(0.58, 0.55, 0.5), "glass": Color(0.06, 0.06, 0.07), "rubber": Color(0.07, 0.065, 0.06),
				"stripe": Color(0.62, 0.48, 0.22), "trim": Color(0.62, 0.48, 0.22)}
	return {"paint": Color(0.1, 0.12, 0.18), "roof": Color(0.78, 0.8, 0.84), "dark": Color(0.08, 0.085, 0.1),
		"steel": Color(0.52, 0.54, 0.58), "glass": Color(0.04, 0.05, 0.07), "rubber": Color(0.05, 0.05, 0.055),
		"stripe": Color(0.78, 0.8, 0.84), "trim": Color(0.2, 0.21, 0.24)}


## The armoured body, in one surface (vertex colours under one matte material): a push bar, a low sloped nose
## and a slatted windscreen rising to the roof well behind the front, a long armoured box, six wheels.
static func _body(look: StringName, size: Vector3) -> ArrayMesh:
	var c: Dictionary = palette(look)
	var W: float = size.x
	var R: float = size.y
	var L: float = size.z
	var b := Batch.new()
	# Underbody and wheels (three axles), with arches over them.
	b.box(c["dark"], Vector3(0.0, 0.5, L * 0.5 + 0.1), Vector3(W - 0.3, 0.3, L - 0.6))
	for z: float in [1.0, L - 2.55, L - 1.2]:
		for sx: float in [-1.0, 1.0]:
			b.cylinder(c["rubber"], Vector3(sx * (W * 0.5 - 0.18), 0.46, z), Vector3(0.92, 0.36, 0.92), Vector3(0.0, 0.0, PI * 0.5))
			b.cylinder(c["steel"], Vector3(sx * (W * 0.5 - 0.15), 0.46, z), Vector3(0.42, 0.38, 0.42), Vector3(0.0, 0.0, PI * 0.5))
			b.box(c["dark"], Vector3(sx * (W * 0.5 - 0.02), 0.98, z), Vector3(0.1, 0.14, 1.12))
	# The armoured box behind the cab: the lower body in the paint, the upper in the roof's colour, the roof.
	var box_from: float = 1.45
	var box_len: float = L - box_from
	b.box(c["paint"], Vector3(0.0, 1.13, box_from + box_len * 0.5), Vector3(W, 0.9, box_len))
	b.box(c["roof"], Vector3(0.0, (1.58 + R) * 0.5, 2.3 + (L - 2.3) * 0.5), Vector3(W, R - 1.58, L - 2.3))
	b.box(c["dark"], Vector3(0.0, R + 0.02, 2.3 + (L - 2.3) * 0.5), Vector3(W - 0.24, 0.04, L - 2.5))
	# Its livery: a band along each side, and dark slit windows high on the box.
	for sx: float in [-1.0, 1.0]:
		b.box(c["stripe"], Vector3(sx * (W * 0.5 + 0.012), 1.34, box_from + box_len * 0.5 + 0.1), Vector3(0.025, 0.2, box_len - 0.5))
		b.box(c["trim"], Vector3(sx * (W * 0.5 + 0.012), 1.2, box_from + box_len * 0.5 + 0.1), Vector3(0.026, 0.05, box_len - 0.5))
		for k: int in 3:
			b.box(c["glass"], Vector3(sx * (W * 0.5 + 0.01), 1.98, 2.9 + k * 1.05), Vector3(0.02, 0.14, 0.62))
	# The cab: sides in the paint, side windows, and a sloped slit windscreen behind armour slats.
	for sx: float in [-1.0, 1.0]:
		b.box(c["paint"], Vector3(sx * (W * 0.5 - 0.06), 1.0, 0.95), Vector3(0.12, 0.92, 1.1))
		b.box(c["paint"], Vector3(sx * (W * 0.5 - 0.06), 1.72, 1.92), Vector3(0.11, 0.5, 0.75))
		b.box(c["glass"], Vector3(sx * (W * 0.5 - 0.005), 1.8, 1.95), Vector3(0.02, 0.36, 0.56))
	var screen_from := Vector2(1.45, 1.42)
	var screen_to := Vector2(2.32, R - 0.06)
	_slab(b, c["glass"], screen_from, screen_to, W - 0.22, 0.06)
	for k: int in 3:
		var t: float = (k + 1) / 4.0
		var at: Vector2 = screen_from.lerp(screen_to, t)
		b.box(c["dark"], Vector3(0.0, at.y + 0.03, at.x - 0.02), Vector3(W - 0.24, 0.05, 0.07))
	# The roof's front edge over the windscreen, in the roof's colour.
	b.box(c["roof"], Vector3(0.0, R - 0.06, 2.36), Vector3(W, 0.12, 0.16))
	# The nose: a low engine block under a sloped armoured hood.
	b.box(c["paint"], Vector3(0.0, 0.78, 0.92), Vector3(W - 0.12, 0.56, 1.16))
	_slab(b, c["roof"], Vector2(0.32, 1.02), Vector2(1.5, 1.42), W - 0.1, 0.08)
	b.box(c["dark"], Vector3(0.0, 0.83, 0.33), Vector3(W - 0.5, 0.34, 0.05))
	# The push bar across its front: a heavy steel ram plate and its uprights.
	b.box(c["dark"], Vector3(0.0, 0.52, 0.16), Vector3(W + 0.1, 0.42, 0.26))
	b.box(c["steel"], Vector3(0.0, 0.76, 0.06), Vector3(W + 0.1, 0.08, 0.12))
	for sx: float in [-0.62, 0.62]:
		b.box(c["dark"], Vector3(sx, 0.86, 0.12), Vector3(0.1, 0.22, 0.1))
	b.box(c["steel"], Vector3(0.0, 0.95, 0.12), Vector3(W - 0.5, 0.06, 0.08))
	# Mirrors, the light bar's housing, the riders' hatches and the gun ring, a rear door frame.
	for sx: float in [-1.0, 1.0]:
		b.box(c["dark"], Vector3(sx * (W * 0.5 + 0.12), 1.72, 1.55), Vector3(0.08, 0.26, 0.16))
	b.box(c["dark"], Vector3(0.0, R + 0.03, BAR_Z), Vector3(1.44, 0.06, 0.28))
	for i: int in RIDER_SLOTS.size():
		var s: Vector2 = RIDER_SLOTS[i]
		var lift: float = RING_LIFT if i == 2 else 0.0
		b.cylinder(c["steel"] if i == 2 else c["dark"], Vector3(s.x, R + 0.02 + lift * 0.5, s.y), Vector3(0.66, 0.04 + lift, 0.66))
	b.box(c["trim"], Vector3(0.0, 1.5, L + 0.01), Vector3(W - 0.4, 1.6, 0.03))
	if look == &"weathered":
		# Soot and rust over the paint: patches along the sides and on the nose.
		for sx: float in [-1.0, 1.0]:
			for k: int in 4:
				b.box(c["trim"] if k % 2 == 0 else c["dark"], Vector3(sx * (W * 0.5 + 0.02), 0.85 + 0.22 * (k % 3),
					2.0 + k * 1.05), Vector3(0.02, 0.34, 0.6))
		b.box(c["trim"], Vector3(0.35, 1.25, 1.0), Vector3(0.6, 0.02, 0.5), Vector3(-0.33, 0.0, 0.0))
	elif look == &"gilded":
		# Unlit gold trim along the roof's edges and the nose.
		for sx: float in [-1.0, 1.0]:
			b.box(c["trim"], Vector3(sx * (W * 0.5 + 0.01), R - 0.02, 2.3 + (L - 2.3) * 0.5), Vector3(0.03, 0.04, L - 2.3))
		b.box(c["trim"], Vector3(0.0, 0.62, 0.02), Vector3(W + 0.12, 0.04, 0.04))
	return b.commit(body_material())


## A flat slab from `from` to `to` (z, y in the model's space) across `width`: a sloped hood or windscreen.
static func _slab(b: Batch, color: Color, from: Vector2, to: Vector2, width: float, thickness: float) -> void:
	var d: Vector2 = to - from
	var mid: Vector2 = (from + to) * 0.5
	b.box(color, Vector3(0.0, mid.y, mid.x), Vector3(width, thickness, d.length()), Vector3(-atan2(d.y, d.x), 0.0, 0.0))


## The headlights: four lamps in the grille under the nose, and two driving lamps on the push bar.
static func _lamps(size: Vector3) -> ArrayMesh:
	var b := PartBatch.new()
	var m: Material = GreyboxMaterials.glow(HEADLIGHT, 3.2)
	for x: float in [-0.82, -0.52, 0.52, 0.82]:
		b.box(m, Vector3(x * size.x / 2.2, 0.83, 0.3), Vector3(0.24, 0.13, 0.05))
	for x: float in [-0.36, 0.36]:
		b.box(m, Vector3(x, 0.62, 0.0), Vector3(0.16, 0.1, 0.05))
	return b.commit()


## One half of the light bar on the roof: `side` -1 (the red, on the left) or 1 (the blue, on the right). Its
## material is set by set_flash().
static func _bar(side: float, size: Vector3) -> ArrayMesh:
	var b := PartBatch.new()
	var m: Material = GreyboxMaterials.flat(Color.WHITE)
	b.box(m, Vector3(side * 0.34, size.y + 0.06 + BAR_HEIGHT * 0.5, BAR_Z), Vector3(0.62, BAR_HEIGHT, 0.2))
	return b.commit()


## The light bar's material for `color` in a `state`: &"bright" (its turn), &"dim" (the other's), &"steady"
## (both, with Reduced flashing). Made once.
static func bar_material(color: Color, state: StringName) -> Material:
	match state:
		&"bright":
			return GreyboxMaterials.glow(color, 4.5)
		&"dim":
			return GreyboxMaterials.glow(color.darkened(0.55), 0.7)
	return GreyboxMaterials.glow(color, 2.2)


## A rider: a cyborg gunner crouching on the roof, its arm cannon forward, its screen head over its shoulders
## (no taller than RIDER_HEIGHT). Its clothes follow the zone's cyborgs (CyborgSuit's looks, simplified).
static func _rider(look: StringName) -> ArrayMesh:
	var cloth: Color = Color(0.37, 0.37, 0.27)
	var vest: Color = Color(0.21, 0.16, 0.13)
	var pants: Color = Color(0.31, 0.32, 0.25)
	var metal: Color = Color(0.37, 0.25, 0.18)
	var casing: Color = Color(0.2, 0.21, 0.22)
	match look:
		&"weathered":
			cloth = Color(0.24, 0.22, 0.2)
			vest = Color(0.14, 0.12, 0.11)
			pants = Color(0.2, 0.19, 0.17)
		&"gilded":
			cloth = Color(0.12, 0.11, 0.12)
			vest = Color(0.2, 0.18, 0.19)
			pants = Color(0.13, 0.12, 0.13)
			metal = Color(0.6, 0.48, 0.24)
			casing = Color(0.16, 0.15, 0.15)
	var dark := Color(0.08, 0.08, 0.085)
	var b := Batch.new()
	# Knees and shins folded under it, boots behind.
	for sx: float in [-1.0, 1.0]:
		b.box(pants, Vector3(sx * 0.11, 0.08, 0.02), Vector3(0.13, 0.15, 0.42))
		b.box(dark, Vector3(sx * 0.11, 0.06, 0.24), Vector3(0.14, 0.12, 0.16))
	# A torso leaning forward over its gun, a vest and a backpack.
	b.box(cloth, Vector3(0.0, 0.32, 0.03), Vector3(0.36, 0.32, 0.24), Vector3(0.35, 0.0, 0.0))
	b.box(vest, Vector3(0.0, 0.34, 0.01), Vector3(0.38, 0.2, 0.26), Vector3(0.35, 0.0, 0.0))
	b.box(dark, Vector3(0.0, 0.36, 0.2), Vector3(0.28, 0.24, 0.14), Vector3(0.35, 0.0, 0.0))
	# The arm cannon braced forward, the other arm on it.
	b.box(metal, Vector3(0.16, 0.36, -0.2), Vector3(0.11, 0.11, 0.42))
	b.box(dark, Vector3(0.16, 0.36, -0.43), Vector3(0.08, 0.08, 0.06))
	b.box(cloth, Vector3(-0.12, 0.36, -0.1), Vector3(0.09, 0.09, 0.3), Vector3(0.0, 0.5, 0.0))
	# The screen head: a beat-up box television, its screen facing forward, its tube's back behind it, a bent
	# antenna.
	b.box(casing, Vector3(0.0, 0.6, -0.08), Vector3(0.25, 0.2, 0.12))
	b.box(casing.darkened(0.25), Vector3(0.0, 0.59, 0.03), Vector3(0.17, 0.14, 0.13))
	b.box(metal, Vector3(0.06, 0.68, 0.02), Vector3(0.015, 0.1, 0.015), Vector3(0.0, 0.0, -0.5))
	b.box(dark, Vector3(0.0, 0.47, -0.01), Vector3(0.1, 0.06, 0.1))
	return b.commit(body_material())


## A rider's screen face: the cold white LED glow on the front of its head.
static func _rider_face() -> ArrayMesh:
	var b := PartBatch.new()
	b.box(GreyboxMaterials.glow(FACE, 1.6), Vector3(0.0, 0.605, -0.145), Vector3(0.19, 0.14, 0.02))
	return b.commit()


## The body's and riders' matte material: lit like GreyboxMaterials.flat, its colours the vertices'.
static func body_material() -> StandardMaterial3D:
	if not _materials.has(&"body"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.75
		_materials[&"body"] = m
	return _materials[&"body"]


# --- Floor lights ---------------------------------------------------------------------------------------

## The truck's floor lights (GDD §9.13: "its headlight beams and light bar shine forward onto the floor of its
## lane"), on the floor in front of the truck (same space as the model, at its front): "Beams", its headlights
## thrown forward up the lane, fading to nothing BEAM_REACH ahead; "WashRed" and "WashBlue", the light bar's
## two colours on the floor just ahead of it, left and right of its lane's middle. Additive, unshaded shapes
## with their colours in the vertices: cheap on every renderer. Shared meshes and materials.
static func floor_lights() -> Node3D:
	var root := Node3D.new()
	root.name = "FloorLights"
	var m: Dictionary = _floor_shapes()
	for part: String in ["Beams", "WashRed", "WashBlue"]:
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = m[part]
		mi.material_override = floor_material(&"bright")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


## The floor lights' additive material: &"bright", or &"dim" (the light bar's half not lit, and both with
## Reduced flashing).
static func floor_material(state: StringName) -> StandardMaterial3D:
	var key := StringName("floor_" + String(state))
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color.WHITE if state == &"bright" else Color(0.38, 0.38, 0.38)
		m.render_priority = 1
		_materials[key] = m
	return _materials[key]


static func _floor_shapes() -> Dictionary:
	if not _floor_meshes.is_empty():
		return _floor_meshes
	var beams := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx: float in [-1.0, 1.0]:
		# Each headlight's beam: from just ahead of its front, widening and fading up the lane, soft at its edges.
		_strip(st, func(t: float) -> Vector4:
			var half: float = lerpf(0.32, 0.85, t)
			var x: float = sx * lerpf(0.58, 0.5, t)
			return Vector4(x - half, x + half, -0.25 - t * BEAM_REACH, 0.3 * pow(1.0 - t, 1.4) * smoothstep(0.0, 0.06, t)),
			HEADLIGHT, 10)
	st.commit(beams)
	_floor_meshes["Beams"] = beams
	for part: String in ["WashRed", "WashBlue"]:
		var side: float = -1.0 if part == "WashRed" else 1.0
		var color: Color = BAR_RED if part == "WashRed" else BAR_BLUE.lightened(0.15)
		var wash := ArrayMesh.new()
		var ws := SurfaceTool.new()
		ws.begin(Mesh.PRIMITIVE_TRIANGLES)
		# The light bar's glow: brightest a few metres ahead of its front, fading back under it and forward.
		_strip(ws, func(t: float) -> Vector4:
			var half: float = 0.72 * sin(PI * clampf(t * 0.9 + 0.08, 0.0, 1.0)) + 0.12
			var x: float = side * 0.6
			return Vector4(x - half, x + half, 1.2 - t * (1.2 + WASH_REACH), 0.42 * sin(PI * t)),
			color, 8)
		ws.commit(wash)
		_floor_meshes[part] = wash
	return _floor_meshes


## A strip on the floor (y 0) from `shape`(0) to `shape`(1): shape(t) gives (x_left, x_right, z, alpha) for t
## from 0 to 1, in `segments` steps; its colour fades with alpha along it, and across it to nothing at its edges
## (two quads across: edge, middle, edge).
static func _strip(st: SurfaceTool, shape: Callable, color: Color, segments: int) -> void:
	st.set_normal(Vector3.UP)
	for i: int in segments:
		var a: Vector4 = shape.call(float(i) / segments)
		var b: Vector4 = shape.call(float(i + 1) / segments)
		var am: float = (a.x + a.y) * 0.5
		var bm: float = (b.x + b.y) * 0.5
		var clear := Color(color, 0.0)
		for half: Array in [[a.x, am, b.x, bm, true], [am, a.y, bm, b.y, false]]:
			# Each half: from its outer edge (clear) to the middle (lit), or the middle to the other edge.
			var outer_first: bool = half[4]
			var ca0: Color = clear if outer_first else Color(color, a.w)
			var ca1: Color = Color(color, a.w) if outer_first else clear
			var cb0: Color = clear if outer_first else Color(color, b.w)
			var cb1: Color = Color(color, b.w) if outer_first else clear
			for v: Array in [[half[0], a.z, ca0], [half[2], b.z, cb0], [half[3], b.z, cb1],
					[half[0], a.z, ca0], [half[3], b.z, cb1], [half[1], a.z, ca1]]:
				st.set_color(v[2])
				st.add_vertex(Vector3(float(v[0]), 0.0, float(v[1])))


# --- Merging -------------------------------------------------------------------------------------------

## A unit primitive (1 x 1 x 1): a box, a cylinder along y.
static func _prim(kind: StringName) -> Mesh:
	if not _prims.has(kind):
		if kind == &"box":
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE
			_prims[kind] = bm
		else:
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 10
			c.rings = 1
			_prims[kind] = c
	return _prims[kind]


## Merges primitives into one surface, each part in its own colour (vertex colours under one material): one
## draw call for a whole body, as the Buzz Overdrive's hull.
class Batch:
	var _st := SurfaceTool.new()

	func _init() -> void:
		_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func box(color: Color, center: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
		_add(color, EnforcerTruckModel._prim(&"box"), Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), center))

	## A cylinder along y, `size` = (diameter x, height, diameter z).
	func cylinder(color: Color, center: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
		_add(color, EnforcerTruckModel._prim(&"cylinder"), Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), center))

	func commit(material: Material) -> ArrayMesh:
		var mesh: ArrayMesh = _st.commit()
		mesh.surface_set_material(0, material)
		return mesh

	func _add(color: Color, mesh: Mesh, xform: Transform3D) -> void:
		var arrays: Array = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normal_basis: Basis = xform.basis.inverse().transposed()
		_st.set_color(color)
		for i: int in idx:
			_st.set_normal((normal_basis * normals[i]).normalized())
			_st.add_vertex(xform * verts[i])
