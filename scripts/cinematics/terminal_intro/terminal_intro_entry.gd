class_name TerminalIntroEntry
extends Node3D
## The way in, seen from inside (TerminalIntro; the owner's beat: the runner squeezes in through the hole and jumps down to the
## ground, and we see the first level's layout ahead): a section of the station's outer wall standing at the left platform's back,
## in the Terminal's look (old tile under black ashlar, the skin's own pattern), with the doorway the runner came through: the back
## of the rubble heap that blocks it (TerminalIntroHeap, here a short steep slope down to the platform) up to a ragged crack under
## the lintel, through which the dusk's cold grey light comes in as a beam across the platform: cold against the work lamps'
## amber. Same frame as the station's front (x along the wall, y up, z out of the wall into the hall), so the heap and the lintel
## are built the same way. Built on the Terminal stage (a second CineStage after the cut), hidden with it. Visual only.
## DESIGN-TBD (docs/questions/f2k.md): the wall's design, the cold light.

const THICK: float = 1.2
const HALF_WIDTH: float = 9.0
const WALL_TOP: float = 11.5
const STONE_DARK := Color(0.09, 0.085, 0.08)
const COLD := Color(0.62, 0.72, 0.9)

var n: TerminalIntroTuning
var skin: ZoneSkin
var heap: TerminalIntroHeap
var wall_x: float = 0.0
var along: float = 0.0
## The crest of the heap (y) and the landing's x out of the wall.
var crest: float = 0.0


## A point of this frame in track space.
func track(p: Vector3) -> Vector3:
	return Vector3(wall_x + p.z, p.y, along + p.x)


func setup(p_skin: ZoneSkin, p_numbers: TerminalIntroTuning, stage: CineStage, p_wall_x: float, p_along: float) -> void:
	name = "Entry"
	skin = p_skin
	n = p_numbers
	wall_x = p_wall_x
	along = p_along
	position = stage.point(Vector3(wall_x, 0.0, along))
	rotation_degrees = Vector3(0.0, 90.0, 0.0)
	heap = TerminalIntroHeap.new(n.heap_height, n.inside_slope, n.heap_foot_width * 0.8, n.door_width)
	crest = n.heap_height
	var solid: ShaderMaterial = skin.call(&"solid_material") as ShaderMaterial if skin.has_method(&"solid_material") else MeshKit.solid()
	var glow: ShaderMaterial = skin.call(&"glow_material") as ShaderMaterial if skin.has_method(&"glow_material") else MeshKit.glow()
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid)
	_wall(s)
	heap.build(s)
	heap.build_chunks(s)
	_crack(s)
	var body: MeshInstance3D = batch.commit(self, "Wall")
	if body != null:
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam(glow)


func _slab(s: MeshLayer, x0: float, x1: float, y0: float, y1: float, color: Color, out: float = 0.0, back: float = -THICK,
		pattern: int = MeshKit.PAT_TERMINAL_WALL, param: float = 0.0) -> void:
	s.box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (out + back) * 0.5), Vector3(x1 - x0, y1 - y0, out - back), color, 0.0, pattern,
		MeshKit.ALL_FACES, param)


func _wall(s: MeshLayer) -> void:
	var dw: float = n.door_width * 0.5
	var stone: Color = skin.get(&"stone_color") if skin.get(&"stone_color") is Color else Color(0.2, 0.185, 0.175)
	_slab(s, -HALF_WIDTH, -dw, 0.0, WALL_TOP, stone)
	_slab(s, dw, HALF_WIDTH, 0.0, WALL_TOP, stone)
	_slab(s, -dw, dw, n.door_height, WALL_TOP, stone)
	# The jambs and the doorway's inside, dark.
	_slab(s, -dw - 0.4, -dw, 0.0, n.door_height + 0.4, STONE_DARK, 0.4, -THICK)
	_slab(s, dw, dw + 0.4, 0.0, n.door_height + 0.4, STONE_DARK, 0.4, -THICK)
	# Piers at the wall's ends (steel, the zone's).
	var steel: Color = skin.get(&"steel_color") if skin.get(&"steel_color") is Color else Color(0.14, 0.23, 0.2)
	for side: float in [-1.0, 1.0]:
		_slab(s, side * HALF_WIDTH - 0.45, side * HALF_WIDTH + 0.45, 0.0, WALL_TOP, steel, 0.5, -THICK, MeshKit.PAT_TERMINAL_STEEL)


## The lintel's broken underside (stone teeth into the crack) and the light beyond the crack: a pale card across the whole
## doorway above the heap, the dusk outside.
func _crack(s: MeshLayer) -> void:
	var dw: float = n.door_width * 0.5
	var tooth: float = -dw
	var ti: int = 3
	while tooth < dw - 0.1:
		var tw: float = 0.5 + 0.9 * MeshKit.hash01(ti, 7, 71)
		var td: float = 0.12 + 0.4 * MeshKit.hash01(ti, 8, 72)
		s.quad(Vector3(tooth, n.door_height, 0.25), Vector3(tooth + tw * 0.5, n.door_height - td, 0.25), Vector3(minf(tooth + tw, dw), n.door_height, 0.25),
			Vector3(minf(tooth + tw, dw), n.door_height, 0.25), STONE_DARK, 0.0, MeshKit.PAT_DZ_CONCRETE)
		tooth += tw
		ti += 1
	# The dusk outside, through the crack: a pale card behind the doorway (emissive, a cold grey, under the bloom threshold).
	s.rect(Vector3(-dw, 0.0, -THICK + 0.05), Vector3(dw * 2.0, 0.0, 0.0), Vector3(0.0, n.door_height, 0.0), COLD * 0.9, 0.14, MeshKit.PAT_PLAIN)


## The cold light coming in through the crack: a beam down and out over the platform and the track.
func _beam(glow: ShaderMaterial) -> void:
	var batch := MeshBatch.new()
	var g: MeshLayer = batch.layer(TerminalIntroStation.own(glow))
	var dw: float = n.door_width * 0.5
	var y: float = n.door_height - 0.4
	for k: int in 3:
		var fan: float = float(k - 1) * 1.4
		g.rect(Vector3(-dw + 0.5 + fan * 0.3, y, 0.0), Vector3(dw * 2.0 - 1.0, 0.0, 0.0), Vector3(fan * 1.6, -y + 0.1, 9.0 + float(k)), COLD, 0.16, MeshKit.SHAPE_BEAM, Vector2.ZERO, Vector2.ONE, -3.5)
	g.rect(Vector3(-dw - 1.0, n.door_height - 2.0, 0.3), Vector3(dw * 2.0 + 2.0, 0.0, 0.0), Vector3(0.0, 3.4, 0.0), COLD, 0.22, MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE, -3.5)
	var m: MeshInstance3D = batch.commit(self, "Beam")
	if m != null:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func draw_calls() -> int:
	var calls: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			calls += m.mesh.get_surface_count()
	return calls
