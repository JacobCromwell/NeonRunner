class_name CasinoIntroLotus
extends Node3D
## The Brass Lotus, the casino the Casino intro's runner pulls up to (CasinoIntro; the owner's reference image of its front,
## October 18, 2026, docs/art/reference/casino_brass_lotus.webp): built in an opening of the street's left wall
## (CineStageDef.wall_gaps) so its front stands back from the street behind a grand staircase. Visual only: no hitboxes.
## - The pavement in front, the staircase (its steps, a burgundy carpet up the middle held by brass rods, stepped cheek
##   walls with brass balusters and handrails, a lamp post on a plinth at each corner) and the terrace at its top (a
##   balustrade along its edge either side of the steps), on a podium of dark stone banded in brass.
## - The front: dark riveted iron (the Casino's PAT_CASINO_IRON) banded in brass, tall arched windows lit warm; tall fluted
##   brass columns either side of the doors; the doors (CasinoGoldenDoor, the boss intro's golden leaves) standing open
##   on a vestibule lit warm; the marquee over them, its underside and edges studded with warm bulbs; the name board on it
##   (THE BRASS LOTUS, CasinoLettering's board, as the street's named casinos carry it); over that an art-deco crest of
##   stepped violet neon round a gold lotus; a blade sign (the name stacked down it) standing out at the far end; a
##   cornice, and a soffit over the opening at the eaves, where the street's glass vault springs.
## - The opening's ends: its side walls back to the front, and a brass-banded pier on each cut end of the street's wall
##   over the orange marks a level's wall gap carries (they tell a runner in play the wall stops; here it's a building).
## - Its lights for the people on the rig (warm: the doors, the marquee, the lamps).
## Colour rule (GDD §5): the reference's pink neon is drawn in the Casino's violet, and nothing else glows but warm white
## (bulbs, lamps, windows, the lettering) and the gold of the lotus; brass and gold are lit metal; the carpet is cloth.
## Its space: x along the street's x from the left wall's line (back into the building is -x), y up from the street,
## and z along the street from the middle of the front, so a track-space offset (x, y, z) is the local (x, y, -z): see L().
## DESIGN-TBD (docs/questions/f2j.md): its front's design beyond the reference, the staircase and the terrace.

const IRON := CasinoHall.IRON
const IRON_DARK := CasinoHall.IRON_DARK
const BRASS := CasinoHall.BRASS
const BRASS_DARK := CasinoHall.BRASS_DARK
const GOLD := CasinoHall.GOLD
const LAMP := CasinoHall.LAMP
const VIOLET := CasinoHall.SCREEN_VIOLET
const STONE := Color(0.16, 0.14, 0.135)
const STONE_LIGHT := Color(0.24, 0.21, 0.19)
const CARPET := Color(0.33, 0.05, 0.09)
const CARPET_EDGE := Color(0.5, 0.36, 0.17)
const PLUM := CasinoHall.WALL
const POT := Color(0.24, 0.17, 0.13)
const LEAF := Color(0.14, 0.24, 0.13)
const LEAF_DARK := Color(0.1, 0.18, 0.1)
## The carpet runner's width up the steps and its brass edging.
const CARPET_WIDTH: float = 3.2
## The cheek walls either side of the steps: their width and how far they stand over each step.
const CHEEK_WIDTH: float = 0.6
const CHEEK_OVER: float = 0.5
## A balustrade's height over what it stands on, its balusters' spacing, its rail's size.
const RAIL_HEIGHT: float = 0.8
const BALUSTER_STEP: float = 0.42
## The columns either side of the doors: their radius, how far they stand out of the front and how high they go.
const COLUMN_RADIUS: float = 0.42
const COLUMN_OUT: float = 0.75
const COLUMN_HEIGHT: float = 10.6
## The front's iron's thickness; the cut wall's piers (out into the street, back along the wall, high).
const FRONT_THICK: float = 0.6
const PIER := Vector3(0.32, 1.25, 8.2)
## How far the pier reaches along the street's wall past the opening's end.
const PIER_PAST: float = 0.65
## The lamp posts' height and their globes' size.
const LAMP_POST: float = 3.2
const GLOBE: float = 0.34
## How much the bulbs, the lamps, the windows, the neon and the lotus glow (COLOR.a).
const BULB_GLOW: float = 1.3
const WINDOW_GLOW: float = 0.45
const NEON_GLOW: float = 0.95
const LOTUS_GLOW: float = 0.7
## The hall's light at the back of the vestibule: warm, dim enough that the people walking into it stay readable.
const HALL_GLOW: float = 0.3
## The kerb along the street's edge across the opening (over the lip a level's wall gap marks there): out into the
## street, back from the wall's line, high.
const KERB := Vector3(0.42, 0.12, 0.07)

var n: CasinoIntroTuning
var skin: ZoneSkin
var door: CasinoGoldenDoor
var front: MeshInstance3D
## Where things are, in its own measures (x back from the wall's line is negative): the foot of the steps, their top,
## the front's face, the terrace's height.
var foot_x: float = 0.0
var top_x: float = 0.0
var face_x: float = 0.0
var rise: float = 0.0


## A track-space offset from the middle of its front on the wall's line (x, y, z) in its own space.
static func L(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y, -p.z)


func setup(p_skin: ZoneSkin, p_numbers: CasinoIntroTuning) -> void:
	name = "BrassLotus"
	skin = p_skin
	n = p_numbers
	rise = n.stairs_rise
	foot_x = -n.forecourt
	top_x = foot_x - n.stairs_depth
	face_x = top_x - n.terrace_depth
	CasinoLettering.warm()
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material())
	var g: MeshLayer = batch.layer(glow_material())
	_ground(s)
	_staircase(s, g)
	_terrace(s)
	_front(s, g)
	_marquee(s, g)
	_crest(s, g)
	_blade(s)
	_ends(s)
	front = batch.commit(self, "Front")
	if front != null:
		front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	door = CasinoGoldenDoor.new()
	add_child(door)
	door.setup(solid_material(), n.door_width, n.door_height)
	# Its -z (into the passage) into the building, its leaves across the opening.
	door.position = L(Vector3(face_x - FRONT_THICK * 0.5, rise, 0.0))
	door.rotation.y = PI * 0.5
	set_doors(1.0)
	_lights()


## The kit's solid material in the Casino's look (its patterns: iron, brass), else the kit's own.
func solid_material() -> ShaderMaterial:
	if skin != null and skin.has_method(&"solid_material"):
		return skin.call(&"solid_material") as ShaderMaterial
	return MeshKit.solid({"sheen_color": Color(0.5, 0.34, 0.2), "sheen_strength": 0.2})


func glow_material() -> ShaderMaterial:
	if skin != null and skin.has_method(&"glow_material"):
		return skin.call(&"glow_material") as ShaderMaterial
	return MeshKit.glow()


## The doors: 0 shut, 1 wide open (into the vestibule).
func set_doors(open: float) -> void:
	if door == null:
		return
	for i: int in door.leaves.size():
		var side: float = -1.0 if i == 0 else 1.0
		door.leaves[i].rotation.y = -side * CasinoGoldenDoor.OPEN_ANGLE * clampf(open, 0.0, 1.0)


# --- Places the cinematic uses (offsets from the front's middle on the wall's line, track space) ---------------------

## On the street at the foot of the steps, `out` metres toward the street, `along` from their middle.
func foot_point(out: float, along: float) -> Vector3:
	return Vector3(foot_x + out, 0.0, along)


## On the terrace, `back` metres back from the top step's edge, `along` from the middle.
func terrace_point(back: float, along: float) -> Vector3:
	return Vector3(top_x - back, rise, along)


## The middle of the doorway on the terrace, in the front's face.
func door_point() -> Vector3:
	return Vector3(face_x, rise, 0.0)


## The steps' surface under `x` (0 below the foot, rise at the top and over the terrace).
func step_height(x: float) -> float:
	if x >= foot_x:
		return 0.0
	if x <= top_x:
		return rise
	var tread: float = n.stairs_depth / float(n.step_count)
	return float(mini(floori((foot_x - x) / tread) + 1, n.step_count)) * rise / float(n.step_count)


## Draw calls its meshes add now (each visible mesh's surfaces): tests.
func draw_calls() -> int:
	var calls: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			calls += m.mesh.get_surface_count()
	return calls


# --- The pavement, the staircase and the terrace ------------------------------------------------------------------

## The pavement from the street's edge to the steps and the podium, flagstones of dark stone with brass between; two
## planters of dark greenery either side of the steps, and a lamp post on a plinth at each corner of the steps.
func _ground(s: MeshLayer) -> void:
	var half: float = n.frontage * 0.5
	# Over the wall gap's lip at the street's edge, back to the podium's foot.
	s.box(L(Vector3((0.3 + top_x) * 0.5, -0.04, 0.0)), Vector3(0.3 - top_x, 0.1, n.frontage), STONE, 0.0, MeshKit.PAT_PLAIN)
	var z: float = -half + 1.5
	while z < half - 0.5:
		s.box(L(Vector3((0.3 + top_x) * 0.5, 0.012, z)), Vector3(0.3 - top_x, 0.01, 0.05), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.FACE_PY, 0.4)
		z += 1.5
	s.box(L(Vector3((KERB.x - KERB.y) * 0.5, KERB.z * 0.5, 0.0)), Vector3(KERB.x + KERB.y, KERB.z, n.frontage), STONE_LIGHT, 0.0,
		MeshKit.PAT_PLAIN)
	s.box(L(Vector3(KERB.x, KERB.z * 0.5, 0.0)), Vector3(0.04, KERB.z + 0.01, n.frontage), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
		MeshKit.ALL_FACES, 0.5)
	var wing: float = n.stairs_width * 0.5 + CHEEK_WIDTH
	for side: float in [-1.0, 1.0]:
		# Planters along the podium's foot beside the steps.
		var pz: float = side * (wing + (half - wing) * 0.5)
		var px: float = top_x + 0.55
		s.box(L(Vector3(px, 0.3, pz)), Vector3(0.8, 0.6, (half - wing) - 1.6), POT, 0.0, MeshKit.PAT_PLAIN)
		s.box(L(Vector3(px, 0.62, pz)), Vector3(0.9, 0.06, (half - wing) - 1.5), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.6)
		var count: int = 7
		for i: int in count:
			var u: float = (float(i) + 0.5) / float(count) - 0.5
			var bz: float = pz + u * ((half - wing) - 2.0)
			var h: float = 0.5 + 0.25 * MeshKit.hash01(i, int(side), 71)
			var xf := Transform3D(Basis(Vector3.UP, 0.7 * float(i)) * Basis.from_scale(Vector3(0.5, h, 0.5)), L(Vector3(px, 0.62 + h * 0.5, bz)))
			s.box_xform(xf, LEAF if i % 2 == 0 else LEAF_DARK, 0.0, MeshKit.PAT_PLAIN)
		# A lamp post at the foot of the steps, on the cheek wall's end.
		_lamp_post(s, Vector3(foot_x - 0.05, CHEEK_OVER + rise / float(n.step_count), side * (n.stairs_width * 0.5 + CHEEK_WIDTH * 0.5)))


## The steps up to the terrace, the carpet up their middle and the cheek walls either side.
func _staircase(s: MeshLayer, g: MeshLayer) -> void:
	var tread: float = n.stairs_depth / float(n.step_count)
	var step_h: float = rise / float(n.step_count)
	var w: float = n.stairs_width
	for i: int in n.step_count:
		var front_x: float = foot_x - float(i) * tread
		var top: float = float(i + 1) * step_h
		# Each step a block from its nose back to the top, its face and tread showing.
		s.box(L(Vector3((front_x + top_x) * 0.5, top * 0.5, 0.0)), Vector3(front_x - top_x, top, w),
			STONE_LIGHT if i % 2 == 0 else STONE, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PX | MeshKit.FACE_PY)
		# The nose, a brass edge.
		s.box(L(Vector3(front_x - 0.02, top - 0.012, 0.0)), Vector3(0.05, 0.026, w), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES, 0.5)
		# The carpet over the tread and down the riser, its edges trimmed in gold, held by a brass rod at the riser's foot.
		s.box(L(Vector3(front_x - tread * 0.5, top + 0.006, 0.0)), Vector3(tread, 0.012, CARPET_WIDTH), CARPET, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PY | MeshKit.FACE_PX)
		s.box(L(Vector3(front_x + 0.006, top - step_h * 0.5, 0.0)), Vector3(0.012, step_h, CARPET_WIDTH), CARPET, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PX)
		for side: float in [-1.0, 1.0]:
			s.box(L(Vector3(front_x - tread * 0.5, top + 0.008, side * (CARPET_WIDTH * 0.5 - 0.06))), Vector3(tread, 0.014, 0.1),
				CARPET_EDGE, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
		s.box(L(Vector3(front_x - tread + 0.03, top + 0.02, 0.0)), Vector3(0.03, 0.03, CARPET_WIDTH + 0.16), BRASS, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.9)
		# The cheek walls, stepped with the stairs.
		for side: float in [-1.0, 1.0]:
			var cz: float = side * (w * 0.5 + CHEEK_WIDTH * 0.5)
			s.box(L(Vector3(front_x - tread * 0.5, (top + CHEEK_OVER) * 0.5, cz)), Vector3(tread + 0.002, top + CHEEK_OVER, CHEEK_WIDTH),
				STONE, 0.0, MeshKit.PAT_PLAIN)
			s.box(L(Vector3(front_x - tread * 0.5, top + CHEEK_OVER + 0.03, cz)), Vector3(tread + 0.002, 0.06, CHEEK_WIDTH + 0.06),
				BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.4)
	# Balusters on the cheek walls and a brass handrail along the slope.
	for side: float in [-1.0, 1.0]:
		var cz: float = side * (w * 0.5 + CHEEK_WIDTH * 0.5)
		var x: float = foot_x - BALUSTER_STEP * 0.5
		while x > top_x:
			var base: float = step_height(x) + CHEEK_OVER + 0.06
			s.prism(L(Vector3(x, base, cz)), 0.045, RAIL_HEIGHT - 0.06, 6, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.6)
			x -= BALUSTER_STEP
		var a := Vector3(foot_x, CHEEK_OVER + step_h + RAIL_HEIGHT, cz)
		var b := Vector3(top_x, rise + CHEEK_OVER + RAIL_HEIGHT, cz)
		_beam(s, L(a), L(b), 0.09, BRASS, 0.9)
		# A lamp post at the top corner.
		_lamp_post(s, Vector3(top_x + 0.3, rise + CHEEK_OVER, cz))
	# The glow of the four lamps (soft halos).
	for side: float in [-1.0, 1.0]:
		var cz: float = side * (w * 0.5 + CHEEK_WIDTH * 0.5)
		for p: Vector3 in [Vector3(foot_x - 0.05, CHEEK_OVER + step_h + LAMP_POST + GLOBE * 0.5, cz),
				Vector3(top_x + 0.3, rise + CHEEK_OVER + LAMP_POST + GLOBE * 0.5, cz)]:
			g.rect(L(p + Vector3(0.0, -0.9, -0.9)), Vector3(0.0, 0.0, -1.8), Vector3(0.0, 1.8, 0.0), LAMP, 0.35, MeshKit.SHAPE_RADIAL)


## A lamp post standing on `at`: a brass base and fluted post, a crossbar, and a warm globe lantern on top.
func _lamp_post(s: MeshLayer, at: Vector3) -> void:
	s.prism(L(at), 0.17, 0.3, 8, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.5)
	s.prism(L(at + Vector3(0.0, 0.3, 0.0)), 0.06, LAMP_POST - 0.3, 8, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.8)
	s.prism(L(at + Vector3(0.0, LAMP_POST - 0.1, 0.0)), 0.12, 0.1, 8, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.6)
	s.prism(L(at + Vector3(0.0, LAMP_POST, 0.0)), GLOBE * 0.5, GLOBE, 10, LAMP, BULB_GLOW)
	s.prism(L(at + Vector3(0.0, LAMP_POST + GLOBE, 0.0)), 0.1, 0.08, 8, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.6)


## A square beam `thick` across from `a` to `b` (local space), lit brass.
static func _beam(s: MeshLayer, a: Vector3, b: Vector3, thick: float, color: Color, polish: float) -> void:
	var along: Vector3 = b - a
	var side: Vector3 = along.cross(Vector3.UP).normalized() * thick
	var up: Vector3 = side.cross(along).normalized() * thick
	s.box_xform(Transform3D(Basis(along, up, side), (a + b) * 0.5), color, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, polish)


## The terrace at the top of the steps: the podium under it (dark stone, a brass band at the top), its floor and a
## balustrade along its edge either side of the steps.
func _terrace(s: MeshLayer) -> void:
	var half: float = n.frontage * 0.5
	var depth: float = top_x - face_x
	s.box(L(Vector3((top_x + face_x) * 0.5, rise * 0.5, 0.0)), Vector3(depth, rise, n.frontage), STONE, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PX | MeshKit.FACE_PY)
	# Its floor: dark flagstones with brass between, a band of it along the edge.
	var z: float = -half
	while z < half:
		s.box(L(Vector3((top_x + face_x) * 0.5, rise + 0.006, z)), Vector3(depth, 0.01, 0.05), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.FACE_PY, 0.4)
		z += 1.2
	s.box(L(Vector3(top_x - 0.15, rise + 0.006, 0.0)), Vector3(0.3, 0.012, n.frontage), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
		MeshKit.FACE_PY, 0.5)
	# The carpet carries on to the doors.
	s.box(L(Vector3((top_x + face_x) * 0.5, rise + 0.008, 0.0)), Vector3(depth, 0.014, CARPET_WIDTH), CARPET, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PY)
	# The podium's face either side of the steps: a brass band under its edge and a plinth at its foot.
	var wing: float = n.stairs_width * 0.5 + CHEEK_WIDTH
	for side: float in [-1.0, 1.0]:
		var mid: float = side * (wing + half) * 0.5
		var span: float = half - wing
		s.box(L(Vector3(top_x + 0.02, rise - 0.12, mid)), Vector3(0.06, 0.12, span), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.7)
		s.box(L(Vector3(top_x + 0.04, 0.15, mid)), Vector3(0.1, 0.3, span), STONE_LIGHT, 0.0, MeshKit.PAT_PLAIN)
		# The balustrade along the edge.
		var bz: float = side * wing
		while absf(bz) < half - 0.1:
			s.prism(L(Vector3(top_x - 0.2, rise, bz + side * 0.2)), 0.045, RAIL_HEIGHT, 6, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.6)
			bz += side * BALUSTER_STEP
		s.box(L(Vector3(top_x - 0.2, rise + RAIL_HEIGHT, mid)), Vector3(0.12, 0.08, span), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES, 0.9)


# --- The front ---------------------------------------------------------------------------------------------------

## The casino's face from the terrace up to the eaves: dark iron banded in brass round the doorway, rows of tall arched
## windows lit warm, the columns, the vestibule behind the doors, a cornice; the soffit over the opening.
func _front(s: MeshLayer, g: MeshLayer) -> void:
	var half: float = n.frontage * 0.5
	var x: float = face_x - FRONT_THICK * 0.5
	var top: float = n.height
	var dw: float = n.door_width
	var dh: float = n.door_height
	# The wall round the doorway: either side of it, and over it.
	for side: float in [-1.0, 1.0]:
		var z0: float = side * dw * 0.5
		var z1: float = side * half
		s.box(L(Vector3(x, (rise + top) * 0.5, (z0 + z1) * 0.5)), Vector3(FRONT_THICK, top - rise, absf(z1 - z0)), IRON, 0.0,
			MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES, 0.0)
	s.box(L(Vector3(x, (rise + dh + top) * 0.5, 0.0)), Vector3(FRONT_THICK, top - rise - dh, dw), IRON, 0.0, MeshKit.PAT_CASINO_IRON,
		MeshKit.ALL_FACES, 0.0)
	# The doorway's surround: brass jambs and a stepped brass lintel, a fan of gold over it.
	for side: float in [-1.0, 1.0]:
		s.box(L(Vector3(face_x + 0.06, rise + dh * 0.5, side * (dw * 0.5 + 0.14))), Vector3(0.14, dh, 0.28), BRASS, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.8)
	for i: int in 3:
		var w: float = dw + 0.56 + 0.3 * float(i)
		s.box(L(Vector3(face_x + 0.06 + 0.04 * float(i), rise + dh + 0.1 + 0.16 * float(i), 0.0)), Vector3(0.14, 0.16, w), BRASS if i % 2 == 0 else BRASS_DARK,
			0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.7)
	# The vestibule behind the doors: plum walls, the carpet, and the hall's warm light at its back.
	var v0: float = face_x - FRONT_THICK
	var v1: float = v0 - n.vestibule
	for side: float in [-1.0, 1.0]:
		s.box(L(Vector3((v0 + v1) * 0.5, rise + dh * 0.5, side * (dw * 0.5 + 0.1))), Vector3(v0 - v1, dh, 0.2), PLUM, 0.0, MeshKit.PAT_PLAIN)
	s.box(L(Vector3((v0 + v1) * 0.5, rise + dh + 0.1, 0.0)), Vector3(v0 - v1, 0.2, dw + 0.4), IRON_DARK, 0.0, MeshKit.PAT_PLAIN)
	s.box(L(Vector3((v0 + v1) * 0.5, rise + 0.006, 0.0)), Vector3(v0 - v1, 0.012, dw), CARPET, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
	s.box(L(Vector3(v1 - 0.05, rise + dh * 0.5, 0.0)), Vector3(0.1, dh, dw + 0.4), LAMP.darkened(0.2), HALL_GLOW)
	# Brass bands across the front every few metres, and the cornice at the top.
	var band: float = rise + dh + 0.9
	while band < top - 1.0:
		s.box(L(Vector3(face_x + 0.04, band, 0.0)), Vector3(0.1, 0.2, n.frontage), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
		band += 4.2
	s.box(L(Vector3(face_x + 0.3, top - 0.45, 0.0)), Vector3(0.7, 0.5, n.frontage), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
	s.box(L(Vector3(face_x + 0.45, top - 0.1, 0.0)), Vector3(1.0, 0.2, n.frontage), IRON_DARK, 0.0, MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES, 2.0)
	# Rows of tall arched windows either side of the crest, lit warm behind iron mullions.
	var room: float = n.marquee_width * 0.5 + 1.6
	for side: float in [-1.0, 1.0]:
		var wz: float = room + 1.4
		while wz < half - 1.0:
			var wy: float = rise + 1.4
			while wy + 3.0 < top - 1.2:
				_window(s, Vector3(face_x, wy, side * wz), 1.3, 2.6)
				wy += 4.2
			wz += 2.4
	# The columns either side of the marquee: a base, a fluted brass shaft, a capital, an urn on top.
	for side: float in [-1.0, 1.0]:
		var c := Vector3(face_x + COLUMN_OUT, rise, side * (n.marquee_width * 0.5 + 0.75))
		s.prism(L(c), COLUMN_RADIUS * 1.35, 0.5, 8, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.5)
		s.prism(L(c + Vector3(0.0, 0.5, 0.0)), COLUMN_RADIUS, COLUMN_HEIGHT - 1.3, 16, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.85)
		for ring: float in [1.6, COLUMN_HEIGHT * 0.5]:
			s.prism(L(c + Vector3(0.0, ring, 0.0)), COLUMN_RADIUS * 1.08, 0.14, 16, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.6)
		s.prism(L(c + Vector3(0.0, COLUMN_HEIGHT - 0.8, 0.0)), COLUMN_RADIUS * 1.25, 0.3, 12, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.6)
		s.prism(L(c + Vector3(0.0, COLUMN_HEIGHT - 0.5, 0.0)), COLUMN_RADIUS * 1.5, 0.3, 8, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.8)
		s.prism(L(c + Vector3(0.0, COLUMN_HEIGHT - 0.2, 0.0)), COLUMN_RADIUS * 0.7, 0.7, 10, GOLD, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.9)
		# Its foot tied back into the front by an iron plate.
		s.box(L(Vector3(face_x + COLUMN_OUT * 0.5, rise + COLUMN_HEIGHT * 0.5, c.z)), Vector3(COLUMN_OUT, COLUMN_HEIGHT - 1.0, 0.3), IRON_DARK, 0.0,
			MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES, 0.0)
	# The soffit over the whole opening at the eaves, iron with brass ribs.
	s.box(L(Vector3(face_x * 0.5, top + 0.15, 0.0)), Vector3(-face_x + 0.4, 0.3, n.frontage + 0.4), IRON_DARK, 0.0, MeshKit.PAT_CASINO_IRON,
		MeshKit.FACE_NY | MeshKit.FACE_PX, 1.0)
	var rib: float = -half + 2.0
	while rib < half:
		s.box(L(Vector3(face_x * 0.5, top - 0.15, rib)), Vector3(-face_x, 0.3, 0.2), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY, 0.3)
		rib += 3.0


## A tall window on the front at `at` (its sill's middle): a brass frame, warm light behind iron mullions, an arched head.
func _window(s: MeshLayer, at: Vector3, w: float, h: float) -> void:
	s.box(L(at + Vector3(0.03, h * 0.5, 0.0)), Vector3(0.06, h + 0.2, w + 0.2), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.FACE_PX, 0.5)
	s.box(L(at + Vector3(0.07, h * 0.5 - 0.15, 0.0)), Vector3(0.02, h - 0.3, w), LAMP.darkened(0.15), WINDOW_GLOW)
	# The arched head: three steps narrowing.
	for i: int in 3:
		var k: float = float(i + 1) / 4.0
		s.box(L(at + Vector3(0.07, h - 0.3 + 0.1 * float(i) + 0.05, 0.0)), Vector3(0.022, 0.1, w * cos(k * 1.2)), LAMP.darkened(0.15), WINDOW_GLOW)
	s.box(L(at + Vector3(0.09, h * 0.5, 0.0)), Vector3(0.03, h, 0.05), IRON_DARK, 0.0, MeshKit.PAT_PLAIN)
	for y: float in [h * 0.35, h * 0.68]:
		s.box(L(at + Vector3(0.09, y, 0.0)), Vector3(0.03, 0.05, w), IRON_DARK, 0.0, MeshKit.PAT_PLAIN)
	s.box(L(at + Vector3(0.12, -0.06, 0.0)), Vector3(0.18, 0.1, w + 0.3), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.6)


## The marquee over the doors: a deep box standing out over the terrace, edged in brass, its face and underside studded
## with warm bulbs, the name board on it.
func _marquee(s: MeshLayer, g: MeshLayer) -> void:
	var y0: float = rise + n.marquee_y
	var thick: float = 1.0
	var x0: float = face_x
	var x1: float = face_x + n.marquee_reach
	var w: float = n.marquee_width
	s.box(L(Vector3((x0 + x1) * 0.5, y0 + thick * 0.5, 0.0)), Vector3(x1 - x0, thick, w), IRON_DARK, 0.0, MeshKit.PAT_CASINO_IRON,
		MeshKit.ALL_FACES, 0.0)
	for y: float in [y0 + 0.05, y0 + thick - 0.05]:
		s.box(L(Vector3(x1 + 0.02, y, 0.0)), Vector3(0.08, 0.1, w + 0.08), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.8)
	# Bulbs: two rows along its face, and a grid on its underside.
	var bz: float = -w * 0.5 + 0.2
	while bz < w * 0.5 - 0.1:
		for y: float in [y0 + 0.25, y0 + thick - 0.25]:
			s.box(L(Vector3(x1 + 0.05, y, bz)), Vector3(0.08, 0.08, 0.08), LAMP, BULB_GLOW)
		var ux: float = x0 + 0.35
		while ux < x1 - 0.1:
			s.box(L(Vector3(ux, y0 - 0.03, bz)), Vector3(0.07, 0.06, 0.07), LAMP, BULB_GLOW)
			ux += 0.45
		bz += 0.4
	# Violet tube along the face between the bulb rows.
	s.box(L(Vector3(x1 + 0.04, y0 + thick * 0.5, 0.0)), Vector3(0.04, 0.05, w - 0.6), VIOLET, NEON_GLOW)
	g.rect(L(Vector3(x1 + 0.2, y0 - 0.5, w * 0.5)), Vector3(0.0, 0.0, -w), Vector3(0.0, thick + 1.0, 0.0), LAMP, 0.22, MeshKit.SHAPE_FLAT)
	# The pool of the bulbs' light on the terrace under it.
	g.rect(L(Vector3((x0 + x1) * 0.5 + 1.2, rise + 0.03, w * 0.5)), Vector3(0.0, 0.0, -w), Vector3(-n.marquee_reach - 2.4, 0.0, 0.0), LAMP, 0.18,
		MeshKit.SHAPE_RADIAL)
	# The name board standing on it: a dark panel with a violet tube and the name in warm white (CasinoLettering).
	var bh: float = 2.0
	var bw: float = w - 1.6
	var bx: float = x1 - 0.35
	var by: float = y0 + thick + bh * 0.5 + 0.1
	s.box(L(Vector3(bx - 0.1, by, 0.0)), Vector3(0.2, bh + 0.24, bw + 0.24), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.8)
	s.rect(L(Vector3(bx + 0.02, by - bh * 0.5, bw * 0.5)), Vector3(0.0, 0.0, -bw), Vector3(0.0, bh, 0.0), VIOLET, 0.6, MeshKit.PAT_CASINO_SIGN,
		Vector2.ZERO, Vector2(bw, bh), 37.0 + 100.0 * roundf(bh * 10.0) + CasinoLettering.NAMED_PANEL)
	var layout: int = CasinoLettering.Layout.LOTUS_BOARD
	var sc: float = CasinoLettering.fit(layout, Vector2(bw - 1.0, bh - 0.5))
	if sc > 0.0:
		var letters: MeshLayer = CasinoLettering.layer(layout, _lettering_color(), _lettering_glow())
		# The letters on the board, facing the street (+x), reading toward -z (the viewer's right).
		s.append(letters, Transform3D(Basis(Vector3(0, 0, -1) * sc, Vector3(0, sc, 0), Vector3(1, 0, 0) * sc), L(Vector3(bx + 0.05, by, 0.0))))
	# The board's glow on the haze.
	g.rect(L(Vector3(bx + 0.3, by - bh, bw * 0.5 + 0.5)), Vector3(0.0, 0.0, -bw - 1.0), Vector3(0.0, bh * 2.0, 0.0), VIOLET, 0.12, MeshKit.SHAPE_FLAT)


## The art-deco crest over the marquee: stepped violet neon bars rising to the middle round a gold lotus, on a dark
## panel framed in brass.
func _crest(s: MeshLayer, g: MeshLayer) -> void:
	var y0: float = rise + n.marquee_y + 1.0 + 2.5
	var x: float = face_x + 0.12
	var bars: int = 9
	var spacing: float = 0.62
	var tallest: float = 6.8
	s.box(L(Vector3(face_x + 0.06, y0 + tallest * 0.5 + 0.2, 0.0)), Vector3(0.12, tallest + 0.9, spacing * float(bars) + 0.7), IRON_DARK, 0.0,
		MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES, 0.0)
	for i: int in bars:
		var u: float = float(i) - float(bars - 1) * 0.5
		var h: float = tallest * (1.0 - 0.13 * absf(u))
		var z: float = u * spacing
		s.box(L(Vector3(x + 0.04, y0 + h * 0.5, z)), Vector3(0.08, h, 0.3), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
		s.box(L(Vector3(x + 0.1, y0 + h * 0.5, z)), Vector3(0.05, h - 0.3, 0.07), VIOLET, NEON_GLOW)
		# Its rounded head.
		s.box(L(Vector3(x + 0.1, y0 + h - 0.08, z)), Vector3(0.05, 0.07, 0.2), VIOLET, NEON_GLOW)
	g.rect(L(Vector3(x + 0.35, y0 - 0.6, spacing * float(bars) * 0.5 + 0.8)), Vector3(0.0, 0.0, -spacing * float(bars) - 1.6),
		Vector3(0.0, tallest + 1.2, 0.0), VIOLET, 0.16, MeshKit.SHAPE_RADIAL)
	# The lotus: a fan of petals in gold, lit, at the foot of the bars.
	var c := Vector3(x + 0.18, y0 + 0.2, 0.0)
	var petals: int = 7
	for i: int in petals:
		var a: float = lerpf(-1.15, 1.15, float(i) / float(petals - 1))
		var len: float = 1.25 * (1.0 - 0.18 * absf(a))
		var dir := Vector3(0.0, cos(a), sin(a))
		var xf := Transform3D(Basis(Vector3.RIGHT, -a) * Basis.from_scale(Vector3(0.05, len, 0.26)), L(c + dir * len * 0.5))
		s.box_xform(xf, GOLD, LOTUS_GLOW)
	s.box(L(c + Vector3(0.02, -0.06, 0.0)), Vector3(0.06, 0.18, 1.6), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.8)


## The blade sign at the far end of the front, standing out toward the street: a dark board edged in brass with the
## name stacked down it in warm white, both faces, a violet tube round it.
func _blade(s: MeshLayer) -> void:
	var layout: int = CasinoLettering.Layout.LOTUS_BLADE
	var size: Vector2 = CasinoLettering.layout_size(layout)
	if size.y <= 0.0:
		return
	var y0: float = rise + 5.6
	var room: float = n.height - 2.2 - y0
	var sc: float = minf(0.62, room / size.y)
	var box: Vector2 = size * sc
	var board := Vector2(box.x + 0.5, box.y + 0.6)
	var z: float = n.frontage * 0.5 - 1.6
	var x: float = face_x + 0.2 + board.x * 0.5
	var y: float = y0 + board.y * 0.5
	s.box(L(Vector3(x, y, z)), Vector3(board.x, board.y, 0.22), IRON_DARK, 0.0, MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES, 0.0)
	s.box(L(Vector3(x, y, z)), Vector3(board.x + 0.12, board.y + 0.12, 0.16), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.8)
	var letters: MeshLayer = CasinoLettering.layer(layout, _lettering_color(), _lettering_glow())
	for face: float in [-1.0, 1.0]:
		# Facing back down the street (-z, toward the arriving car) and up it; reading left to right either way.
		var nrm := Vector3(0, 0, -face)
		var right := Vector3(face, 0, 0)
		s.append(letters, Transform3D(Basis(L(right) * sc, Vector3(0, sc, 0), L(nrm) * sc), L(Vector3(x, y, z + face * -0.13))))
		for e: float in [-1.0, 1.0]:
			s.box(L(Vector3(x + e * (board.x * 0.5 - 0.1), y, z - face * 0.12)), Vector3(0.05, board.y - 0.2, 0.02), VIOLET, NEON_GLOW)


## The opening's ends: its side walls from the street's wall back to the front, and a pier over each cut end of the
## street's wall.
func _ends(s: MeshLayer) -> void:
	var half: float = n.frontage * 0.5
	for side: float in [-1.0, 1.0]:
		var z: float = side * (half + 0.3)
		s.box(L(Vector3(face_x * 0.5, n.height * 0.5, z)), Vector3(-face_x, n.height, 0.6), IRON, 0.0, MeshKit.PAT_CASINO_IRON,
			MeshKit.ALL_FACES, 0.0)
		for y: float in [rise, rise + n.door_height + 0.9, rise + n.door_height + 5.1, n.height - 0.45]:
			s.box(L(Vector3(face_x * 0.5, y, z - side * 0.32)), Vector3(-face_x, 0.2, 0.06), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
				MeshKit.ALL_FACES, 0.5)
		# The pier over the cut wall's end: out a little into the street, back along the wall over its marks (on the
		# wall's face, ZoneSkin.WALL_GAP_EDGE_WIDTH along it from the end, and up the end's corner).
		var pz: float = side * (half + PIER_PAST - PIER.y * 0.5)
		s.box(L(Vector3(PIER.x * 0.5 - 0.6, PIER.z * 0.5, pz)), Vector3(PIER.x + 1.2, PIER.z, PIER.y), IRON, 0.0, MeshKit.PAT_CASINO_IRON,
			MeshKit.ALL_FACES, 0.0)
		for y: float in [0.3, 2.6, 5.0, PIER.z - 0.2]:
			s.box(L(Vector3(PIER.x * 0.5 - 0.6, y, pz)), Vector3(PIER.x + 1.3, 0.22, PIER.y + 0.1), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS,
				MeshKit.ALL_FACES, 0.7)


func _lettering_color() -> Color:
	var c: Variant = skin.get(&"lettering_color") if skin != null else null
	return c as Color if c is Color else Color(0.98, 0.91, 0.74)


func _lettering_glow() -> float:
	var v: Variant = skin.get(&"lettering_glow") if skin != null else null
	return float(v) if v != null else 0.3


## Warm lights for the people on the rig (the front's own surfaces carry the kit's fake light): the doorway, the marquee
## and the lamps at the top of the steps.
func _lights() -> void:
	var lamps: Array[Vector4] = [Vector4(face_x + 1.2, rise + 2.6, 0.0, 6.5),
		Vector4(face_x + n.marquee_reach * 0.5, rise + n.marquee_y - 0.6, 0.0, 7.0),
		Vector4(top_x + 0.3, rise + 3.0, -(n.stairs_width * 0.5 + CHEEK_WIDTH * 0.5), 5.0),
		Vector4(top_x + 0.3, rise + 3.0, n.stairs_width * 0.5 + CHEEK_WIDTH * 0.5, 5.0),
		Vector4(foot_x + 0.6, 2.6, 0.0, 6.0)]
	for i: int in lamps.size():
		var p: Vector4 = lamps[i]
		var omni := OmniLight3D.new()
		omni.name = "Lamp%d" % i
		omni.light_color = LAMP
		omni.light_energy = 1.2
		omni.omni_range = p.w
		omni.omni_attenuation = 0.9
		omni.shadow_enabled = false
		add_child(omni)
		omni.position = L(Vector3(p.x, p.y, p.z))
