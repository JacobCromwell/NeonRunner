class_name CasinoHolo
extends Node3D
## The casino hall's holographic games (CasinoHall; the owner: "a few holographic games that do not yet exist in the
## real world"), each over a brass-and-iron pedestal the hall builds, in additive light (casino_holo.gdshader: bright
## edges, faint faces, soft scanlines; never flickering):
## - the dice tower: three great dice tumbling up and down inside a column of violet light ringed with bands;
## - the orbit wheel: a ring of eight glowing cards wheeling round over the table, a diamond sigil turning in its hub;
## - the star sphere: a slowly turning lattice globe, tokens orbiting it on tilted paths.
## Violet, blue and cold white only (the Casino's sign colours; GDD §5: never a hazard's hue). Moved from the
## cinematic's clock (update()), so stepping shows the same.
## Its space: the hall's (CasinoHall: track space with z flipped); `setup` takes each pedestal's foot there.
## DESIGN-TBD (docs/questions/casino_boss_intro.md): what the games are and how they look.

const VIOLET := Color(0.66, 0.45, 1.0)
const BLUE := Color(0.42, 0.6, 1.0)
const COLD := Color(0.85, 0.9, 1.0)
## The pedestals' top, where the light starts.
const BASE_Y: float = 0.7

var material: ShaderMaterial
var dice: Array[Node3D] = []
var wheel: Node3D
var sigil: Node3D
var globe: Node3D
var tokens: Array[Node3D] = []
var _feet: Array[Vector3] = []


func setup(_solid: Material, feet: Array[Vector3]) -> void:
	name = "Holograms"
	_feet = feet
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/cinematics/casino_boss_intro/casino_holo.gdshader")
	_dice_tower(feet[0])
	_orbit_wheel(feet[1])
	_star_sphere(feet[2])
	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _instance(parent: Node3D, layer_fill: Callable, node_name: String, at: Vector3) -> MeshInstance3D:
	var batch := MeshBatch.new()
	layer_fill.call(batch.layer(material))
	return MeshBatch.add_instance(parent, batch.to_mesh(), node_name, at)


func _dice_tower(foot: Vector3) -> void:
	var root := Node3D.new()
	root.name = "DiceTower"
	add_child(root)
	root.position = foot
	_instance(root, func(l: MeshLayer) -> void:
		l.prism(Vector3(0.0, BASE_Y, 0.0), 0.68, 2.5, 12, VIOLET, 0.32, MeshKit.PAT_PLAIN, false)
		for i: int in 5:
			l.prism(Vector3(0.0, BASE_Y + 0.15 + 0.55 * float(i), 0.0), 0.72, 0.03, 24, VIOLET, 0.9, MeshKit.PAT_PLAIN, false)
		l.prism(Vector3(0.0, BASE_Y + 2.5, 0.0), 0.5, 0.02, 24, COLD, 0.8, MeshKit.PAT_PLAIN, true)
	, "Column", Vector3.ZERO)
	for i: int in 3:
		var holder := Node3D.new()
		holder.name = "Die%d" % i
		root.add_child(holder)
		_instance(holder, func(l: MeshLayer) -> void:
			l.box(Vector3.ZERO, Vector3.ONE * 0.36, COLD if i == 1 else VIOLET, 0.85)
			# Pips: small bright squares on three faces.
			for f: Vector3 in [Vector3(0.0, 0.0, 0.181), Vector3(0.181, 0.0, 0.0), Vector3(0.0, 0.181, 0.0)]:
				l.box(f, Vector3(0.07, 0.07, 0.07) * (Vector3.ONE - f.abs() / 0.181 * 0.9), COLD, 1.0)
		, "Die", Vector3.ZERO)
		dice.append(holder)


func _orbit_wheel(foot: Vector3) -> void:
	var root := Node3D.new()
	root.name = "OrbitWheel"
	add_child(root)
	root.position = foot
	wheel = Node3D.new()
	wheel.name = "Wheel"
	root.add_child(wheel)
	wheel.position = Vector3(0.0, BASE_Y + 1.35, 0.0)
	_instance(wheel, func(l: MeshLayer) -> void:
		# The hoop: a ring of thin bars in the wheel's plane (x, y), and its eight cards round it.
		var segs: int = 28
		for i: int in segs:
			var a0: float = TAU * float(i) / float(segs)
			var a1: float = TAU * float(i + 1) / float(segs)
			var p0 := Vector3(cos(a0), sin(a0), 0.0) * 1.15
			var p1 := Vector3(cos(a1), sin(a1), 0.0) * 1.15
			var mid: Vector3 = (p0 + p1) * 0.5
			var xf := Transform3D(Basis(Vector3.BACK, (a0 + a1) * 0.5) * Basis.from_scale(Vector3(0.03, p0.distance_to(p1), 0.03)), mid)
			l.box_xform(xf, BLUE, 0.9)
		for i: int in 8:
			var a: float = TAU * float(i) / 8.0
			var c := Vector3(cos(a), sin(a), 0.0) * 1.15
			l.box_xform(Transform3D(Basis.from_scale(Vector3(0.34, 0.48, 0.02)), c), COLD if i % 2 == 0 else BLUE, 0.7)
			l.box_xform(Transform3D(Basis(Vector3.BACK, PI * 0.25) * Basis.from_scale(Vector3(0.12, 0.12, 0.03)), c), VIOLET, 1.0)
			# The spoke to the hub.
			l.box_xform(Transform3D(Basis(Vector3.BACK, a - PI * 0.5) * Basis.from_scale(Vector3(0.015, 0.9, 0.015)), c * 0.55), BLUE, 0.6)
	, "Cards", Vector3.ZERO)
	sigil = Node3D.new()
	sigil.name = "Sigil"
	root.add_child(sigil)
	sigil.position = Vector3(0.0, BASE_Y + 1.35, 0.0)
	_instance(sigil, func(l: MeshLayer) -> void:
		l.box_xform(Transform3D(Basis(Vector3(1.0, 0.0, 1.0).normalized(), 0.955) * Basis.from_scale(Vector3.ONE * 0.32), Vector3.ZERO), VIOLET, 0.9)
	, "Diamond", Vector3.ZERO)
	# A beam of light from the pedestal up to the wheel.
	_instance(root, func(l: MeshLayer) -> void:
		l.prism(Vector3(0.0, BASE_Y, 0.0), 0.12, 0.9, 8, BLUE, 0.35, MeshKit.PAT_PLAIN, false)
	, "Beam", Vector3.ZERO)


func _star_sphere(foot: Vector3) -> void:
	var root := Node3D.new()
	root.name = "StarSphere"
	add_child(root)
	root.position = foot
	globe = Node3D.new()
	globe.name = "Globe"
	root.add_child(globe)
	globe.position = Vector3(0.0, BASE_Y + 1.2, 0.0)
	var radius: float = 0.85
	_instance(globe, func(l: MeshLayer) -> void:
		# Lines of latitude and longitude, each a ring of thin bars.
		for lat: int in 5:
			var phi: float = lerpf(-1.1, 1.1, float(lat) / 4.0)
			var rr: float = cos(phi) * radius
			var y: float = sin(phi) * radius
			_ring_bars(l, Vector3(0.0, y, 0.0), rr, Basis.IDENTITY, 24, COLD if lat == 2 else VIOLET, 0.8)
		for lon: int in 6:
			var b := Basis(Vector3.UP, PI * float(lon) / 6.0) * Basis(Vector3.RIGHT, PI * 0.5)
			_ring_bars(l, Vector3.ZERO, radius, b, 28, VIOLET, 0.6)
		# A bright core.
		l.box_xform(Transform3D(Basis(Vector3(1.0, 1.0, 0.0).normalized(), 0.6) * Basis.from_scale(Vector3.ONE * 0.18), Vector3.ZERO), COLD, 1.0)
	, "Lattice", Vector3.ZERO)
	for i: int in 4:
		var orbit := Node3D.new()
		orbit.name = "Orbit%d" % i
		root.add_child(orbit)
		orbit.position = Vector3(0.0, BASE_Y + 1.2, 0.0)
		orbit.rotation = Vector3(0.5 + 0.35 * float(i), 1.3 * float(i), 0.0)
		_instance(orbit, func(l: MeshLayer) -> void:
			l.box(Vector3(radius + 0.32 + 0.06 * float(i), 0.0, 0.0), Vector3(0.12, 0.12, 0.03), BLUE if i % 2 == 0 else COLD, 1.0)
		, "Token", Vector3.ZERO)
		tokens.append(orbit)
	_instance(root, func(l: MeshLayer) -> void:
		l.prism(Vector3(0.0, BASE_Y, 0.0), 0.5, 0.05, 20, VIOLET, 0.8, MeshKit.PAT_PLAIN, false)
	, "Halo", Vector3.ZERO)


## A ring of `segs` thin bars of radius `r` round `center` in the plane `b` turns (x, z) into.
static func _ring_bars(l: MeshLayer, center: Vector3, r: float, b: Basis, segs: int, color: Color, strength: float) -> void:
	for i: int in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0: Vector3 = b * Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var p1: Vector3 = b * Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		var along: Vector3 = p1 - p0
		if along.length() < 0.0001:
			continue
		var up: Vector3 = Vector3.UP if absf(along.normalized().y) < 0.95 else Vector3.RIGHT
		var xf := Transform3D(Basis.looking_at(along.normalized(), up) * Basis.from_scale(Vector3(0.022, 0.022, along.length())),
			center + (p0 + p1) * 0.5)
		l.box_xform(xf, color, strength)


## Moves the games to time `t` (the cinematic's clock).
func update(t: float) -> void:
	material.set_shader_parameter(&"clock", t)
	for i: int in dice.size():
		var d: Node3D = dice[i]
		var ph: float = t * (0.7 + 0.13 * float(i)) + float(i) * 2.1
		d.position = Vector3(sin(ph * 1.3) * 0.22, BASE_Y + 1.25 + sin(ph) * 0.8, cos(ph * 1.1) * 0.22)
		d.rotation = Vector3(t * (1.1 + 0.3 * float(i)), t * (0.8 - 0.2 * float(i)), t * 0.5 * float(i))
	if wheel != null:
		wheel.rotation = Vector3(0.0, sin(t * 0.25) * 0.4, -t * 0.6)
	if sigil != null:
		sigil.rotation = Vector3(0.0, t * 1.4, 0.0)
	if globe != null:
		globe.rotation = Vector3(0.25, t * 0.35, 0.0)
	for i: int in tokens.size():
		var o: Node3D = tokens[i]
		o.rotation = Vector3(0.5 + 0.35 * float(i), 1.3 * float(i) + t * (0.9 + 0.25 * float(i)), 0.0)
