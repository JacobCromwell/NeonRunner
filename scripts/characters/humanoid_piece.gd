class_name HumanoidPiece
extends Resource
## One low-poly mesh piece on a HumanoidRig segment, e.g. a sleeve on the upper arm or a visor on
## the head. HumanoidParts merges all pieces of a segment into one mesh (one draw call).
##
## Coordinates are the segment's joint space at design scale (metres): +y up the rest pose, -z
## forward (the way the character faces), +x the character's right. Limb pieces are authored for
## the right limb; the left limb gets a mirrored copy (see `side`).

enum Shape {
	## Box of `size`, centred on `offset`; `chamfer` cuts the vertical edges (8-sided section).
	BOX,
	## `sides`-sided prism: diameters size.x / size.z, height size.y, centred on `offset`.
	PRISM,
	## Surface of revolution: a `sides`-sided section (diameters size.x / size.z) swept through
	## `profile` rings (x = height, y = x scale, z = z scale, w = z shift). Closed at both ends.
	LATHE,
	## Like LATHE, but open (no end caps) and only the faces within `arc`: visors, collars, stripes.
	BAND,
	## Ring: diameter size.x, tube diameter size.y, `sides` segments, axis along y.
	TORUS,
	## Like BAND (the faces within `arc`, swept through `profile`), but a solid sheet `thickness`
	## thick: outside, inside, the top and bottom rims and the two cut edges are all closed, so it
	## reads from both sides (coat panels, an open collar).
	SHELL,
}

## Which rig segments get this piece. Limb segments exist twice (left and right).
enum Placement {
	## Limbs: both limbs (the left one mirrored). Centre segments: the piece plus a mirrored copy.
	MIRRORED,
	## Only the right limb, or only as authored on a centre segment.
	RIGHT,
	## Only the left limb, or only the mirrored copy on a centre segment.
	LEFT,
	## Limbs: both limbs. Centre segments: once, as authored (no mirrored copy).
	CENTER,
}

## Segment name: pelvis, chest, neck, head, upper_arm, forearm, hand, thigh, shin, foot.
@export var segment: StringName = &"chest"
@export var side: Placement = Placement.CENTER
@export var shape: Shape = Shape.BOX
@export var size: Vector3 = Vector3(0.1, 0.1, 0.1)
## BOX / PRISM: scale of the top (+y) end relative to the bottom, per x and z.
@export var top_scale: Vector2 = Vector2.ONE
## BOX / PRISM: z shift of the top end (slants the piece forward or back).
@export var top_shift: float = 0.0
## BOX: size of the corner cut as a fraction of the smaller half-size (0 = square corners).
@export_range(0.0, 0.5, 0.01) var chamfer: float = 0.0
@export_range(3, 24, 1) var sides: int = 6
## PRISM / LATHE / BAND / SHELL: turns the section's corners round its outline (degrees) without
## turning the outline itself. 0 puts a flat face at the front and back; half a side's angle puts
## a corner there instead.
@export_range(-180.0, 180.0, 0.5) var section_phase: float = 0.0
## LATHE / BAND / SHELL rings, in order: (height, x scale, z scale, z shift).
@export var profile: PackedVector4Array = PackedVector4Array()
## BAND / SHELL: keeps the faces whose direction lies between these angles (degrees; 0 = front,
## 90 = the right side, ±180 = the back).
@export var arc: Vector2 = Vector2(-180.0, 180.0)
## SHELL: the sheet's thickness (metres at design scale), measured inward from the outline.
@export_range(0.001, 0.1, 0.001) var thickness: float = 0.012
@export var offset: Vector3 = Vector3.ZERO
@export var rotation_degrees: Vector3 = Vector3.ZERO
## Albedo (sRGB). Glowing pieces use their glow colour here.
@export var color: Color = Color.WHITE
## Emission strength: 0 = matte, 1 = standard neon trim, above 1 = brighter (visors).
@export_range(0.0, 3.0, 0.05) var glow: float = 0.0
## Polish: 0 = the material's own roughness, 1 = smooth and glinting (polished metal). Written into
## the vertex colour's alpha as 1 - shine; humanoid_body.gdshader reads it, other shaders may ignore it.
@export_range(0.0, 1.0, 0.05) var shine: float = 0.0
## Optional own material (for example an animated LED screen). Pieces that share a material are
## merged into one extra surface; null uses the rig's body material (vertex colour + glow).
@export var material: Material


## True when the piece belongs on the given segment instance (`limb_side` -1 / 1 for limbs,
## 0 for centre segments), and whether that instance is the mirrored copy.
func placements(limb_side: int) -> Array[bool]:
	var out: Array[bool] = []
	if limb_side == 0:
		if side != Placement.LEFT:
			out.append(false)
		if side == Placement.MIRRORED or side == Placement.LEFT:
			out.append(true)
	elif limb_side > 0:
		if side != Placement.LEFT:
			out.append(false)
	elif side != Placement.RIGHT:
		out.append(true)
	return out
