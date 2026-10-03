class_name SwarmJumpMarks
extends Node3D
## The Host's way up, shown (GDD §10: "the player reaches them by a ramp and a wall jump"; the Floating
## Head's lesson: a way up must be visible): while the Host crouches at a host spot, the ramp's wall lights a
## strip of the zone's green ramp chevrons at wall-running height, from the ramp on to where a wall jump
## still comes down on the Host's implants (SewerSwarmTuning.jump_mark_until), ending in a tall mark
## pointing up: jump before it. Scenery: no collision, never a hazard colour, never flickering (the chevrons
## only scroll, like a ramp's), so Reduced flashing leaves it as it is. Both walls' strips are made with the
## fight (hidden: show() puts one in place). World space (top_level).
## DESIGN-TBD (docs/questions/e4.md, the Host's way up): the look.

## The strip's heights on the wall (a ramp's wall run passes them), the end mark's.
const STRIP_LOW: float = 2.2
const STRIP_HIGH: float = 3.9
const MARK_LOW: float = 1.2
const MARK_HIGH: float = 4.8
const MARK_LENGTH: float = 1.2
const PANEL_LENGTH: float = 2.4
## How far it stands proud of the wall line (clear of the facades).
const PROUD: float = 0.06
const STRIP_GLOW: float = 0.8
const EDGE_GLOW: float = 1.0
const MARK_GLOW: float = 1.3

var world: RunWorld
## The side shown (-1 left, +1 right, 0 none) and where its strip starts and ends (track distances).
var side: int = 0
var from: float = 0.0
var to: float = 0.0

var _strips: Dictionary = {}
var _length: float = 10.0


## Builds both walls' strips, `length` metres long (the window at the run's pace) in `color`; hidden.
func setup(p_world: RunWorld, length: float, color: Color) -> void:
	world = p_world
	name = "JumpMarks"
	top_level = true
	_length = length
	for s: int in [-1, 1]:
		var node: MeshInstance3D = MeshBatch.add_instance(self, strip_mesh(s, world.geo.wall_x() - PROUD, length, color),
			"Strip%s" % ("Left" if s < 0 else "Right"))
		_strips[s] = node
	# Drawn tiny from the fight's start (its look ready before it's needed), then hidden by show()/hide_marks().
	position = Vector3(0.0, -40.0, 0.0)
	scale = Vector3.ONE * 0.0001
	visible = true


## Lights the strip on `p_side`'s wall from track distance `p_from` on.
func show_at(p_side: int, p_from: float) -> void:
	side = p_side
	from = p_from
	to = p_from + _length
	scale = Vector3.ONE
	position = Vector3(0.0, 0.0, TrackGeometry.world_z(from))
	visible = true
	for s: int in _strips:
		(_strips[s] as MeshInstance3D).visible = s == side


func hide_marks() -> void:
	side = 0
	visible = false


## One wall's strip (local space: from z 0 on toward -z, `length` long), on the wall face at `x`.
static func strip_mesh(p_side: int, x: float, length: float, color: Color) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(MeshKit.solid({"glow_scale": 4.0}))
	var sx: float = p_side * x
	var panels: int = maxi(int(length / PANEL_LENGTH), 1)
	for i: int in panels:
		var z0: float = -length * float(i) / panels
		var z1: float = -length * float(i + 1) / panels
		var near_lo := Vector3(sx, STRIP_LOW, z0)
		var near_hi := Vector3(sx, STRIP_HIGH, z0)
		var far_lo := Vector3(sx, STRIP_LOW, z1)
		var far_hi := Vector3(sx, STRIP_HIGH, z1)
		# Seen from the street, far is to the right on the left wall and to the left on the right wall; quads
		# wind clockwise as seen, and the chevrons (along UV.x) point ahead.
		if p_side < 0:
			m.quad(near_lo, near_hi, far_hi, far_lo, color, STRIP_GLOW, MeshKit.PAT_CHEVRON, 1.0)
		else:
			m.quad(far_lo, far_hi, near_hi, near_lo, color, STRIP_GLOW, MeshKit.PAT_CHEVRON, -1.0)
	for y: float in [STRIP_LOW, STRIP_HIGH]:
		m.box(Vector3(sx, y, -length * 0.5), Vector3(0.05, 0.07, length), color, EDGE_GLOW)
	# The end mark: a tall panel of chevrons pointing up, framed.
	var zm0: float = -length + MARK_LENGTH * 0.5
	var zm1: float = -length - MARK_LENGTH * 0.5
	var near_low := Vector3(sx, MARK_LOW, zm0)
	var near_high := Vector3(sx, MARK_HIGH, zm0)
	var far_low := Vector3(sx, MARK_LOW, zm1)
	var far_high := Vector3(sx, MARK_HIGH, zm1)
	var bright: Color = color.lerp(Color.WHITE, 0.25)
	if p_side < 0:
		m.quad(far_low, near_low, near_high, far_high, bright, MARK_GLOW, MeshKit.PAT_CHEVRON, 1.0)
	else:
		m.quad(near_low, far_low, far_high, near_high, bright, MARK_GLOW, MeshKit.PAT_CHEVRON, 1.0)
	for z: float in [zm0, zm1]:
		m.box(Vector3(sx, (MARK_LOW + MARK_HIGH) * 0.5, z), Vector3(0.06, MARK_HIGH - MARK_LOW, 0.09), color, EDGE_GLOW)
	return batch.to_mesh()
