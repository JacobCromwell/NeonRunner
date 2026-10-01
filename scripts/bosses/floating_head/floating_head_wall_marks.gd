class_name FloatingHeadWallMarks
extends Node3D
## The second stomp window's cue (GDD §10: "(2) wall-jump onto it"; task E1e, from the owner's playtest:
## after the first stomp nothing showed a way onto its head). As the tower falls onto the ship, both
## walls light up where a wall run leads onto its head: a strip of the City's green ramp chevrons along
## each wall at running height, pointing ahead, from where to get onto the wall
## (FloatingHeadTuning.wall_entry_before its pinned face) to a tall bright mark where to jump off it
## (wall_jump_before), its chevrons pointing up. They light with a sound (FloatingHead: wall_marks_light)
## and go when the window closes.
## Scenery: no collision, nothing in a hazard colour, and it never flickers (the chevrons only scroll,
## like the ramps'), so Reduced flashing leaves it as it is.
## DESIGN-TBD (docs/questions/e1e.md): the look. World space (the node sits at the origin, top_level).

## The strip's height on the wall (a wall runner's body passes it), and the jump mark's.
const STRIP_LOW: float = 1.0
const STRIP_HIGH: float = 2.5
const MARK_LOW: float = 0.3
const MARK_HIGH: float = 3.6
## The jump mark's length along the track, and each chevron panel's along the strip.
const MARK_LENGTH: float = 1.4
const PANEL_LENGTH: float = 2.4
## How far the marks stand proud of the wall line (clear of the facades' faces).
const PROUD: float = 0.06
## The glow of the strip, its edge lines and the jump mark (the ramps' chevrons glow 0.8).
const STRIP_GLOW: float = 0.8
const EDGE_GLOW: float = 1.0
const MARK_GLOW: float = 1.3

var world: RunWorld
## Where the strip starts and where the jump mark is (track distances).
var start: float = 0.0
var jump_at: float = 0.0


func setup(p_world: RunWorld, p_start: float, p_jump_at: float, color: Color) -> void:
	world = p_world
	start = p_start
	jump_at = p_jump_at
	name = "WallMarks"
	top_level = true
	transform = Transform3D.IDENTITY
	MeshBatch.add_instance(self, marks_mesh(world.geo.wall_x() - PROUD, start, jump_at, color), "Marks")
	for side: float in [-1.0, 1.0]:
		world.effects.burst(jump_mark_world(int(side)), color, 18, 0.7)


## The jump mark's middle on the wall on `side` (-1 left, +1 right), world space.
func jump_mark_world(side: int) -> Vector3:
	return Vector3(side * (world.geo.wall_x() - PROUD), (MARK_LOW + MARK_HIGH) * 0.5, TrackGeometry.world_z(jump_at))


## Both walls' marks (world space), `x` the walls' faces either side of the middle: the chevron strip
## from `from` to `to` in panels with lines along its edges, and the jump mark at `to`.
static func marks_mesh(x: float, from: float, to: float, color: Color) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(FloatingHeadModel.solid_material())
	var panels: int = maxi(int((to - from) / PANEL_LENGTH), 1)
	for side: float in [-1.0, 1.0]:
		var sx: float = side * x
		# Seen from the street, far is to the right on the left wall and to the left on the right wall;
		# quads wind clockwise as seen, and the chevrons (along UV.x) point ahead.
		for i: int in panels:
			var z0: float = TrackGeometry.world_z(lerpf(from, to, float(i) / panels))
			var z1: float = TrackGeometry.world_z(lerpf(from, to, float(i + 1) / panels))
			var near_lo := Vector3(sx, STRIP_LOW, z0)
			var near_hi := Vector3(sx, STRIP_HIGH, z0)
			var far_lo := Vector3(sx, STRIP_LOW, z1)
			var far_hi := Vector3(sx, STRIP_HIGH, z1)
			if side < 0.0:
				m.quad(near_lo, near_hi, far_hi, far_lo, color, STRIP_GLOW, MeshKit.PAT_CHEVRON, 1.0)
			else:
				m.quad(far_lo, far_hi, near_hi, near_lo, color, STRIP_GLOW, MeshKit.PAT_CHEVRON, -1.0)
		var z_from: float = TrackGeometry.world_z(from)
		var z_to: float = TrackGeometry.world_z(to)
		for y: float in [STRIP_LOW, STRIP_HIGH]:
			m.box(Vector3(sx, y, (z_from + z_to) * 0.5), Vector3(0.05, 0.07, absf(z_to - z_from)), color, EDGE_GLOW)
		# The jump mark: a tall panel of chevrons pointing up, framed.
		var zm0: float = TrackGeometry.world_z(to - MARK_LENGTH * 0.5)
		var zm1: float = TrackGeometry.world_z(to + MARK_LENGTH * 0.5)
		var near_low := Vector3(sx, MARK_LOW, zm0)
		var near_high := Vector3(sx, MARK_HIGH, zm0)
		var far_low := Vector3(sx, MARK_LOW, zm1)
		var far_high := Vector3(sx, MARK_HIGH, zm1)
		if side < 0.0:
			m.quad(far_low, near_low, near_high, far_high, color.lerp(Color.WHITE, 0.25), MARK_GLOW, MeshKit.PAT_CHEVRON, 1.0)
		else:
			m.quad(near_low, far_low, far_high, near_high, color.lerp(Color.WHITE, 0.25), MARK_GLOW, MeshKit.PAT_CHEVRON, 1.0)
		for z: float in [zm0, zm1]:
			m.box(Vector3(sx, (MARK_LOW + MARK_HIGH) * 0.5, z), Vector3(0.06, MARK_HIGH - MARK_LOW, 0.09), color, EDGE_GLOW)
		for y: float in [MARK_LOW, MARK_HIGH]:
			m.box(Vector3(sx, y, (zm0 + zm1) * 0.5), Vector3(0.06, 0.09, MARK_LENGTH), color, EDGE_GLOW)
	return batch.to_mesh()
