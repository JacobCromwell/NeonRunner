class_name GoldenConvergenceTakeoffMarks
extends Node3D
## Where to take off for the stomp while The Magnate lies stunned (GDD §10, the owner's playtest, proposed: "while
## he's stunned, green chevrons on the floor (the game's "jump here" marks, as before the Hostile Takeover's
## couplings) show where to take off"; task E5d-e): a strip of the zone's green ramp chevrons on the floor of each of
## his two lanes, over the middle of the stretch a jump can be taken from and still come down on his back
## (GoldenConvergencePounce.takeoff_gaps, CUE_TRIM off each end), its arrows streaming toward him. Scenery: no
## collision, never a hazard colour, steady (the chevrons only scroll, as on every ramp; Reduced flashing or not).
## Its mesh is made with the fight (the stretch's length is the run speed's) and shown, two instances, by the
## Pounce's stun (show / hide).

## The cue keeps this share of the take-off stretch off each of its ends (it marks the middle of it, the Hostile
## Takeover couplings' cue's way).
const CUE_TRIM: float = 0.12
## Its strip's share of a lane's width, its edge lines' width, its glow (the ramps' chevrons glow 0.8).
const WIDTH_SHARE: float = 0.46
const EDGE: float = 0.06
const GLOW: float = 0.8
## The green when the skin doesn't say (every zone's ramp_color).
const GREEN := Color(0.3, 1.0, 0.35)

var boss: GoldenConvergence
## The marks' strips (one per lane he lies across), and the stretch they mark now: {lanes, from, to} (track
## distances, the near end first) or {}.
var strips: Array[MeshInstance3D] = []
var marked: Dictionary = {}

var _length: float = 0.0


## Makes the strips for the fight: `gaps` the take-off stretch (track distance before his back: x nearest, y
## furthest) at its run speed.
func setup(p_boss: GoldenConvergence, gaps: Vector2) -> void:
	boss = p_boss
	name = "TakeoffMarks"
	top_level = true
	var trim: float = (gaps.y - gaps.x) * CUE_TRIM
	_length = maxf(gaps.y - gaps.x - trim * 2.0, 0.5)
	var mesh: ArrayMesh = strip_mesh(boss.world.geo.lane_width * WIDTH_SHARE, _length, color(boss.world.skin),
		boss.solid_material())
	for i: int in 2:
		var strip: MeshInstance3D = MeshBatch.add_instance(self, mesh, "Chevrons%d" % i)
		strip.top_level = true
		strip.visible = false
		strips.append(strip)


## The skin's green ramp colour (or every zone's).
static func color(skin: ZoneSkin) -> Color:
	var c: Variant = skin.get("ramp_color") if skin != null else null
	return c if c is Color else GREEN


## A strip `width` wide and `length` long (its near end at the origin, running ahead along -z): the kit's chevrons
## (MeshKit.PAT_CHEVRON) streaming ahead in `green`, framed by thin edge lines, in `solid` (the court's kit material).
static func strip_mesh(width: float, length: float, green: Color, solid: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid)
	var hw: float = width * 0.5
	var y: float = 0.012
	# UV.x runs along the track ahead, toward his back, so the chevrons point and stream at him.
	s.rect(Vector3(hw, y, 0.0), Vector3(0.0, 0.0, -length), Vector3(-width, 0.0, 0.0), green, GLOW, MeshKit.PAT_CHEVRON,
		Vector2.ZERO, Vector2.ONE, 1.0)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (hw + EDGE * 0.7), y, -length * 0.5), Vector3(EDGE, 0.02, length), green, 1.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PY)
	return batch.to_mesh()


## Shows the chevrons in `lanes` (his two) before his back at track distance `back`, over the take-off stretch
## `gaps` (as setup's), trimmed to its middle.
func show_marks(lanes: Array, back: float, gaps: Vector2) -> void:
	var trim: float = (gaps.y - gaps.x) * CUE_TRIM
	var from: float = back - gaps.y + trim
	var to: float = from + _length
	for i: int in strips.size():
		var strip: MeshInstance3D = strips[i]
		if i >= lanes.size():
			strip.visible = false
			continue
		strip.global_transform = Transform3D(Basis.IDENTITY, Vector3(boss.world.geo.lane_x(int(lanes[i])), 0.02,
			TrackGeometry.world_z(from)))
		strip.visible = true
	marked = {"lanes": lanes.duplicate(), "from": from, "to": to}


func hide_marks() -> void:
	for strip: MeshInstance3D in strips:
		strip.visible = false
	marked = {}


func shown() -> bool:
	return not marked.is_empty()
