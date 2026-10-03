class_name SwarmPipe
extends Node3D
## The big sewer pipe the Host bursts out of (GDD §10, phase 3: "the Host bursts out of a big sewer pipe
## ahead"): a huge pale steel pipe ringed with rust, slung across the street overhead from wall to wall on
## brackets (pale against the brick, so it's seen from far off), high above anything the runner does
## (SewerSwarmTuning.pipe_height), its rusted middle bulging and dripping sludge, small warm work lamps on
## its brackets. When the Host bursts out (burst()) its middle section tears open: the torn ring shows,
## debris and screeches spill. Scenery: no collision, no hazard colours. Made with the fight (hidden), placed
## ahead as phase 3 begins.
## World space (top_level): place() puts it across the street at a track distance.

const STEEL := Color(0.52, 0.53, 0.5)
const RUST := Color(0.38, 0.24, 0.15)
const RUST_DARK := Color(0.22, 0.15, 0.1)
const METAL := Color(0.3, 0.29, 0.27)
const SLUDGE := Color(0.32, 0.27, 0.12)
const INSIDE := Color(0.04, 0.035, 0.03)
## The brackets' work lamps: small and warm white (never a hazard colour).
const LAMP := Color(1.0, 0.86, 0.66)

var world: RunWorld
## Its track distance, and whether it has burst.
var at: float = 0.0
var burst_open: bool = false

var _whole: MeshInstance3D
var _torn: MeshInstance3D


## Builds it across `p_world`'s street at `height` (its axis) with `radius`; hidden until placed.
func setup(p_world: RunWorld, height: float, radius: float) -> void:
	world = p_world
	name = "SewerPipe"
	top_level = true
	var half: float = world.geo.wall_x() + 1.5
	var solid: ShaderMaterial = MeshKit.solid({"glow_scale": 4.0})
	_whole = MeshBatch.add_instance(self, _mesh(solid, half, height, radius, false), "Pipe")
	_torn = MeshBatch.add_instance(self, _mesh(solid, half, height, radius, true), "PipeTorn")
	# Drawn from the fight's start, too small to see, so their looks are ready (no hitch when it shows).
	visible = true
	scale = Vector3.ONE * 0.0001
	position = Vector3(0.0, -40.0, 0.0)
	_torn.visible = true


## Puts it across the street at track distance `p_at`, whole.
func place(p_at: float) -> void:
	at = p_at
	burst_open = false
	scale = Vector3.ONE
	position = Vector3(0.0, 0.0, TrackGeometry.world_z(at))
	visible = true
	_whole.visible = true
	_torn.visible = false


## Its middle tears open (the Host bursting out).
func burst() -> void:
	burst_open = true
	_whole.visible = false
	_torn.visible = true


## Out of sight again.
func stow() -> void:
	visible = false


## Where the Host drops out of it (world space).
func mouth() -> Vector3:
	return Vector3(0.0, position.y, position.z)


## The pipe across the street (x from -half to half) at `height`, `radius` round: rusted, ringed with flanges,
## on brackets at the walls, a bulging middle dripping sludge; `torn`: its middle torn open, a dark hole with
## jagged lips.
static func _mesh(material: Material, half: float, height: float, radius: float, torn: bool) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(material)
	var sides: int = 12
	var gap: float = radius * 1.4
	# The pipe along x: two runs from the walls to the middle (or one through it), as prisms on their side.
	var runs: Array = [[-half, -gap], [gap, half]] if torn else [[-half, half]]
	for run: Array in runs:
		var x0: float = float(run[0])
		var x1: float = float(run[1])
		var length: float = x1 - x0
		var xform := Transform3D(Basis(Vector3(0.0, radius, 0.0), Vector3(length, 0.0, 0.0), Vector3(0.0, 0.0, radius)),
			Vector3(x0, height, 0.0))
		m.prism_xform(xform, sides, STEEL)
	if torn:
		# The torn lips: jagged plates curling out round the hole, its dark inside.
		for side: float in [-1.0, 1.0]:
			for i: int in 8:
				var a: float = TAU * (float(i) + 0.5) / 8.0
				var lip := Vector3(side * (gap + 0.25), height + sin(a) * radius * 1.08, cos(a) * radius * 1.08)
				m.box(lip, Vector3(0.5, 0.45 + 0.3 * float(i % 2), 0.45 + 0.2 * float(i % 3)), RUST_DARK)
			m.prism_xform(Transform3D(Basis(Vector3(0.0, radius * 0.92, 0.0), Vector3(side * 0.15, 0.0, 0.0),
				Vector3(0.0, 0.0, radius * 0.92)), Vector3(side * gap, height, 0.0)), sides, INSIDE)
	else:
		# The bulging middle, sludge dripping from its seams.
		m.prism_xform(Transform3D(Basis(Vector3(0.0, radius * 1.18, 0.0), Vector3(gap * 2.0, 0.0, 0.0),
			Vector3(0.0, 0.0, radius * 1.18)), Vector3(-gap, height, 0.0)), sides, RUST)
		for i: int in 5:
			var dx: float = (float(i) - 2.0) * gap * 0.4
			m.box(Vector3(dx, height - radius * 1.25 - 0.4 - 0.15 * (i % 2), 0.1 * (i % 3)), Vector3(0.12, 0.8 + 0.3 * (i % 2), 0.12),
				SLUDGE)
	# Flanges along it, and the brackets at the walls.
	var flanges: int = int(half * 2.0 / 3.0)
	for i: int in flanges + 1:
		var fx: float = -half + float(i) * (half * 2.0 / maxf(flanges, 1))
		if torn and absf(fx) < gap + 0.3:
			continue
		m.prism_xform(Transform3D(Basis(Vector3(0.0, radius * 1.1, 0.0), Vector3(0.22, 0.0, 0.0),
			Vector3(0.0, 0.0, radius * 1.1)), Vector3(fx - 0.11, height, 0.0)), sides, RUST_DARK)
	# Brackets bolted into the walls either side (nothing reaches down into the street).
	for side: float in [-1.0, 1.0]:
		var bx: float = side * (half - 1.2)
		m.box(Vector3(bx, height - radius - 0.2, 0.0), Vector3(0.6, 0.35, radius * 2.4), METAL)
		m.box(Vector3(bx, height + radius + 0.2, 0.0), Vector3(0.6, 0.35, radius * 2.4), METAL)
		m.box(Vector3(bx - side * 0.5, height - radius - 0.5, radius * 0.9), Vector3(0.34, 0.16, 0.34), LAMP, 2.2)
	return batch.to_mesh()
