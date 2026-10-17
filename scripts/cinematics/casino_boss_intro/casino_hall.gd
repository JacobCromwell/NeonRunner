class_name CasinoHall
extends Node3D
## The casino hall of the Casino boss intro (CasinoBossIntro; the owner's beats, October 17, 2026: "a camera angle that
## is inside of the bustling casino ... lots of different casino tables with cards and roulette and a few holographic
## games that do not yet exist in the real world"). A closed set of its own, built once: the cinematic hides the
## street's track and plays wholly in here. In the Casino's look (GDD §5 Zone 4, docs/art/reference/casino_zone.webp):
## dark riveted iron and aged brass, warm lamplight, plum walls over a dark wood wainscot, a burgundy carpet woven
## with gold (casino_carpet.gdshader), a coffered iron ceiling, brass chandeliers.
## What's in it (track space, see below):
## - the roulette table (CasinoRoulette: its wheel spins and its ball drops, the establishing shot's close-up);
## - two blackjack tables, a poker table and a dice table, their cards and chip stacks;
## - three holographic games (CasinoHolo): a dice tower, an orbit wheel of glowing cards and a star sphere;
## - banks of slot machines along the left wall and an island of them near the back;
## - the bar along the right wall, its counter, its stools and its lit shelves of bottles;
## - the back wall: the golden door (CasinoGoldenDoor) the Chairman leaves by, and to its left the stretch of wall
##   that trembles and bursts (CasinoWallBreak), with The House standing behind it (a TheHouseModel, the fight's own
##   machine, sized to the fight's street), its lights dark until the wall falls.
## Everything still is merged into a few meshes (one draw per material); what moves is worked out from the cinematic's
## clock (update()), so stepping or skipping shows the same. Visual only.
## Its space: track space (x right, y up, z along the hall from the near wall at z = 0 to the back wall at z = DEPTH)
## mapped to this node by z -> -z (the node sits at the stage's origin, so a point here is stage.point() of its track
## point). Colour rule (GDD §5): only the lamps, the slot machines' screens and the holograms glow, in warm and cold
## white, violet and blue; red cloth, green felt and gold stay unlit.
## DESIGN-TBD (docs/questions/f2i.md): the hall's look, its size and what stands where.

## The hall: half its width, its depth (the back wall's z), its height.
const HALF_WIDTH: float = 17.0
const DEPTH: float = 40.0
const HEIGHT: float = 16.0
## The back wall's thickness, the wainscot's height and the picture rail's.
const WALL_THICK: float = 0.6
const WAINSCOT: float = 1.5
const RAIL: float = 4.2

## The roulette table: its middle, its size (along x, across z), the felt's height; its wheel sits in the table's
## right end (CasinoRoulette).
const ROULETTE := Vector3(-6.0, 0.0, 9.0)
const ROULETTE_SIZE := Vector2(3.4, 1.6)
const TABLE_HEIGHT: float = 0.62
## The wheel's bowl stands this far up out of the felt.
const WHEEL_RAISE: float = 0.04
## The bar: the counter's front (x), its ends along z, its height and depth; the back bar's shelves against the wall.
const BAR_FRONT: float = 12.6
const BAR_Z := Vector2(6.5, 21.5)
const BAR_HEIGHT: float = 0.8
const BAR_DEPTH: float = 0.7
## The golden door: the middle of its opening along the back wall (x), its width and height.
const DOOR_X: float = 7.5
const DOOR_WIDTH: float = 2.4
const DOOR_HEIGHT: float = 3.8
## The tables: [kind, middle (x, z), turn (degrees)].
const BLACKJACK_A := Vector3(-12.0, 0.0, 15.5)
const BLACKJACK_B := Vector3(-1.2, 0.0, 17.0)
const POKER := Vector3(-12.2, 0.0, 29.5)
const DICE_TABLE := Vector3(11.0, 0.0, 30.5)
## The holograms' middles.
const HOLO_DICE := Vector3(2.0, 0.0, 9.8)
const HOLO_WHEEL := Vector3(6.5, 0.0, 12.0)
const HOLO_SPHERE := Vector3(-5.5, 0.0, 21.5)
## The chandeliers: their middles (the bottom of their bulbs' ring is this high).
const CHANDELIERS: Array[Vector3] = [Vector3(-6.0, 9.0, 11.0), Vector3(5.5, 9.0, 15.0), Vector3(-3.0, 10.0, 25.0)]

## Paint, wood, iron and brass (sRGB; none of them glows).
const WALL := Color(0.2, 0.1, 0.19)
const WALL_DARK := Color(0.13, 0.065, 0.12)
const WOOD := Color(0.17, 0.09, 0.055)
const WOOD_LIGHT := Color(0.3, 0.16, 0.08)
const IRON := Color(0.11, 0.11, 0.12)
const IRON_DARK := Color(0.06, 0.06, 0.065)
const BRASS := Color(0.62, 0.47, 0.24)
const BRASS_DARK := Color(0.4, 0.29, 0.14)
const GOLD := Color(0.8, 0.62, 0.28)
const FELT := Color(0.05, 0.24, 0.14)
const FELT_BLUE := Color(0.06, 0.13, 0.27)
const VELVET := Color(0.36, 0.05, 0.08)
const CARD := Color(0.93, 0.92, 0.88)
const CARD_BACK := Color(0.34, 0.07, 0.1)
## The chips' colours: none glows, and the red is a dull, dark one.
const CHIPS: Array[Color] = [Color(0.85, 0.83, 0.78), Color(0.45, 0.08, 0.1), Color(0.12, 0.2, 0.45), Color(0.08, 0.08, 0.09),
	Color(0.48, 0.3, 0.55)]
## The lamps' light: warm white (sconces, chandeliers, the bar's shelves) and a cold white.
const LAMP := Color(1.0, 0.84, 0.6)
const LAMP_COLD := Color(0.82, 0.88, 1.0)
const SCREEN_VIOLET := Color(0.62, 0.45, 1.0)
const SCREEN_BLUE := Color(0.4, 0.58, 1.0)

## The House's reels as it powers on: how long the first spins, how much later each next one stops, how many symbols
## each turns through, and where each stops (TheHouseReels' strip: 0 a seven, 1 a cherry, 2 BAR, 3 lightning).
const REEL_SPIN: float = 1.0
const REEL_STAGGER: float = 0.45
const REEL_TURNS: float = 14.0
const REEL_STOPS := Vector3(1.0, 2.0, 3.0)

var skin: ZoneSkin
var roulette: CasinoRoulette
var holo: CasinoHolo
var door: CasinoGoldenDoor
var wall_break: CasinoWallBreak
var house: TheHouseModel
var house_holder: Node3D
var house_shape: TheHouseModel.Shape
## The hole the House bursts through: its middle along the back wall (x), its width and height.
var hole_x: float = -4.5
var hole_width: float = 14.0
var hole_height: float = 12.5
var carpet: MeshInstance3D
var shell: MeshInstance3D
var _tables: MeshInstance3D


## Builds the hall in `p_skin`'s materials (the Casino's), The House sized as `p_house_shape` (the fight's machine),
## the hole a margin round it, centred at `p_hole_x`.
func setup(p_skin: ZoneSkin, p_house_shape: TheHouseModel.Shape, p_hole_x: float, hole_margin: Vector2) -> void:
	name = "CasinoHall"
	skin = p_skin
	house_shape = p_house_shape
	hole_x = p_hole_x
	hole_width = house_shape.width + hole_margin.x * 2.0
	hole_height = minf(house_shape.height + hole_margin.y, HEIGHT - 1.5)
	_build_carpet()
	_build_shell()
	_build_lights()
	_build_furniture()
	roulette = CasinoRoulette.new()
	add_child(roulette)
	roulette.setup(solid_material())
	roulette.position = L(wheel_center())
	holo = CasinoHolo.new()
	add_child(holo)
	holo.setup(solid_material(), [L(HOLO_DICE), L(HOLO_WHEEL), L(HOLO_SPHERE)])
	door = CasinoGoldenDoor.new()
	add_child(door)
	door.setup(solid_material(), DOOR_WIDTH, DOOR_HEIGHT)
	door.position = L(Vector3(DOOR_X, 0.0, DEPTH - WALL_THICK * 0.5))
	wall_break = CasinoWallBreak.new()
	add_child(wall_break)
	wall_break.setup(solid_material(), self)
	# The machine places itself in its holder (TheHouseModel.animate sets its own position: its shake).
	house_holder = Node3D.new()
	house_holder.name = "House"
	add_child(house_holder)
	# Its face just behind the wall, looking into the hall (its own +z is the hall's -z, this node's +z).
	house_holder.position = L(Vector3(hole_x, 0.0, DEPTH + 0.25))
	house = TheHouseModel.new()
	house.name = "Machine"
	house_holder.add_child(house)
	house.build(house_shape, skin)
	house.lights = 0.0
	house.power = 0.0
	house.animate()


## A track-space point in this node's space.
static func L(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y, -p.z)


## The kit's solid material in the Casino's look (its patterns: iron, brass), else the kit's own.
func solid_material() -> ShaderMaterial:
	if skin != null and skin.has_method(&"solid_material"):
		return skin.call(&"solid_material") as ShaderMaterial
	return MeshKit.solid({"sheen_color": Color(0.5, 0.34, 0.2), "sheen_strength": 0.2})


func glow_material() -> ShaderMaterial:
	if skin != null and skin.has_method(&"glow_material"):
		return skin.call(&"glow_material") as ShaderMaterial
	return MeshKit.glow()


# --- Places the cinematic uses (track space) -----------------------------------------------------------

## The roulette wheel's middle, on the felt.
static func wheel_center() -> Vector3:
	return Vector3(ROULETTE.x + ROULETTE_SIZE.x * 0.5 - 0.72, TABLE_HEIGHT + WHEEL_RAISE, ROULETTE.z)


## Where someone leaning back against the bar's counter stands (their heels), at `z` along it.
static func bar_lean(z: float) -> Vector3:
	return Vector3(BAR_FRONT - 0.24, 0.0, z)


## The counter's top at `z` along it, `inset` in from its front.
static func bar_top(z: float, inset: float) -> Vector3:
	return Vector3(BAR_FRONT + inset, BAR_HEIGHT, z)


## The middle of the golden door's opening, on the floor, in the wall's plane (its hall side).
static func door_point() -> Vector3:
	return Vector3(DOOR_X, 0.0, DEPTH - WALL_THICK)


## The middle of the hole's face, on the floor.
func hole_point() -> Vector3:
	return Vector3(hole_x, 0.0, DEPTH - WALL_THICK)


# --- On the clock --------------------------------------------------------------------------------------

## Moves what moves to time `t`: the wheel and the ball, the holograms, the door, the wall and its dust.
func update(t: float, n: CasinoBossIntroTuning) -> void:
	roulette.update(t, n)
	holo.update(t)
	door.update(t, n)
	wall_break.update(t, n)
	# The House: dark behind the wall, its lights blazing on as the wall comes down.
	var on: float = smoothstep(n.house_lights_at, n.house_lights_at + n.house_lights_seconds, t)
	house.power = on
	house.lights = on
	house.jackpot = 0.35 * on
	# Its reels spin up as it powers on and stop one after another on a cherry, a BAR and a lightning bolt: its
	# three attacks (GDD §10), never the jackpot's sevens.
	for i: int in 3:
		var stop: float = n.house_lights_at + REEL_SPIN + REEL_STAGGER * float(i)
		var u: float = clampf((t - n.house_lights_at) / maxf(stop - n.house_lights_at, 0.01), 0.0, 1.0)
		var left: float = 1.0 - u
		house.reel_angles[i] = REEL_STOPS[i] - REEL_TURNS * left * left
		house.reel_blur[i] = clampf(2.0 * REEL_TURNS * left / maxf(stop - n.house_lights_at, 0.01) / 12.0, 0.0, 1.0)
	house_holder.visible = t >= n.tremble_at - 1.0
	house.animate()


## Draw calls its meshes add now (each visible mesh's surfaces): tests.
func draw_calls() -> int:
	var calls: int = 0
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			calls += (g as MeshInstance3D).mesh.get_surface_count()
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
			if mm.mesh != null and mm.visible_instance_count != 0:
				calls += mm.mesh.get_surface_count()
	return calls


# --- The carpet and the shell ------------------------------------------------------------------------

func _build_carpet() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_WIDTH * 2.0, DEPTH)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/cinematics/casino_boss_intro/casino_carpet.gdshader")
	carpet = MeshInstance3D.new()
	carpet.name = "Carpet"
	carpet.mesh = plane
	carpet.material_override = mat
	carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(carpet)
	carpet.position = L(Vector3(0.0, 0.0, DEPTH * 0.5))
	# The world bounds and the chandeliers' pools, once the node is placed (set again by the cinematic).
	_carpet_bounds.call_deferred()


func _carpet_bounds() -> void:
	if not is_inside_tree():
		return
	var mat := carpet.material_override as ShaderMaterial
	var o: Vector3 = global_position
	mat.set_shader_parameter(&"bounds", Vector4(o.x - HALF_WIDTH, o.x + HALF_WIDTH, o.z - DEPTH, o.z))
	var pools: Array[StringName] = [&"pool_a", &"pool_b", &"pool_c"]
	for i: int in mini(CHANDELIERS.size(), pools.size()):
		var c: Vector3 = CHANDELIERS[i]
		mat.set_shader_parameter(pools[i], Vector4(o.x + c.x, o.z - c.z, 0.0, 6.5))


## Places the carpet's pattern for where the hall now stands (world space).
func place() -> void:
	_carpet_bounds()


func _build_shell() -> void:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material())
	var g: MeshLayer = batch.layer(glow_material())
	var hw: float = HALF_WIDTH
	# The side walls and the near wall: wainscot, the plum wall over it, a brass rail between, iron pilasters.
	for side: float in [-1.0, 1.0]:
		var x: float = side * (hw + 0.3)
		_wall_run(s, Vector3(x, 0.0, DEPTH * 0.5), Vector3(0.6, 0.0, DEPTH), true)
		# Engaged iron pillars with brass bands, every 8 m.
		var z: float = 4.0
		while z < DEPTH - 1.0:
			var px: float = side * (hw - 0.25)
			s.box(L(Vector3(px, HEIGHT * 0.5, z)), Vector3(0.7, HEIGHT, 0.9), IRON, 0.0, MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES, 2.0)
			for y: float in [0.25, WAINSCOT, RAIL, HEIGHT - 1.2]:
				s.box(L(Vector3(px, y, z)), Vector3(0.82, 0.18, 1.02), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
			# A sconce on each pillar's face, warm.
			var fx: float = side * (hw - 0.62)
			s.box(L(Vector3(fx, 3.0, z)), Vector3(0.12, 0.5, 0.26), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.6)
			s.box(L(Vector3(fx - side * 0.06, 3.35, z)), Vector3(0.16, 0.22, 0.16), LAMP, 1.0)
			g.rect(L(Vector3(fx - side * 0.1, 2.55, z - 0.7)), Vector3(0.0, 0.0, -1.4), Vector3(0.0, 1.6, 0.0), LAMP, 0.45, MeshKit.SHAPE_RADIAL)
			z += 8.0
	_wall_run(s, Vector3(0.0, 0.0, -0.3), Vector3(hw * 2.0, 0.0, 0.6), false)
	# The back wall, but for the stretch that bursts (CasinoWallBreak) and the door's opening.
	_back_wall(s, g)
	# The ceiling: coffered iron, brass ribs.
	s.box(L(Vector3(0.0, HEIGHT + 0.2, DEPTH * 0.5)), Vector3(hw * 2.0 + 1.2, 0.4, DEPTH + 1.2), IRON_DARK, 0.0,
		MeshKit.PAT_CASINO_IRON, MeshKit.FACE_NY, 1.0)
	var rib_z: float = 4.0
	while rib_z < DEPTH:
		s.box(L(Vector3(0.0, HEIGHT - 0.3, rib_z)), Vector3(hw * 2.0, 0.6, 0.35), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY, 0.3)
		rib_z += 4.0
	for rib_x: float in [-11.0, -5.5, 0.0, 5.5, 11.0]:
		s.box(L(Vector3(rib_x, HEIGHT - 0.25, DEPTH * 0.5)), Vector3(0.3, 0.5, DEPTH), IRON, 0.0, MeshKit.PAT_CASINO_IRON,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY, 2.0)
	# A cornice round the top of the walls.
	for side: float in [-1.0, 1.0]:
		s.box(L(Vector3(side * (hw - 0.1), HEIGHT - 0.9, DEPTH * 0.5)), Vector3(0.5, 0.5, DEPTH), BRASS_DARK, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.3)
	_chandeliers(s, g)
	shell = batch.commit(self, "Shell")
	if shell != null:
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A run of wall `size` long (x or z) at `center` (on the floor): the wainscot, its brass rail, the plum wall up to the
## ceiling, the picture rail. `along_z` for the side walls.
func _wall_run(s: MeshLayer, center: Vector3, size: Vector3, along_z: bool) -> void:
	var w: Vector3 = size
	s.box(L(center + Vector3(0.0, WAINSCOT * 0.5, 0.0)), Vector3(w.x, WAINSCOT, w.z), WOOD, 0.0, MeshKit.PAT_PLAIN)
	s.box(L(center + Vector3(0.0, (HEIGHT + WAINSCOT) * 0.5, 0.0)), Vector3(w.x, HEIGHT - WAINSCOT, w.z), WALL, 0.0, MeshKit.PAT_PLAIN)
	var grow := Vector3(0.12, 0.0, 0.0) if along_z else Vector3(0.0, 0.0, 0.12)
	s.box(L(center + Vector3(0.0, WAINSCOT, 0.0)), Vector3(w.x, 0.12, w.z) + grow, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS,
		MeshKit.ALL_FACES, 0.6)
	s.box(L(center + Vector3(0.0, RAIL, 0.0)), Vector3(w.x, 0.08, w.z) + grow, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
		MeshKit.ALL_FACES, 0.4)
	s.box(L(center + Vector3(0.0, 0.06, 0.0)), Vector3(w.x, 0.12, w.z) + grow * 0.5, IRON_DARK, 0.0, MeshKit.PAT_PLAIN)


## The back wall at z = DEPTH: the stretches either side of the hole and of the door, the lintel over the hole (all
## built like any wall run), the door's surround, and behind the hole the dark the House stands in.
func _back_wall(s: MeshLayer, g: MeshLayer) -> void:
	var z: float = DEPTH + WALL_THICK * 0.5
	var hole_l: float = hole_x - hole_width * 0.5
	var hole_r: float = hole_x + hole_width * 0.5
	var door_l: float = DOOR_X - DOOR_WIDTH * 0.5
	var door_r: float = DOOR_X + DOOR_WIDTH * 0.5
	var spans: Array[Vector2] = [Vector2(-HALF_WIDTH, hole_l), Vector2(hole_r, door_l), Vector2(door_r, HALF_WIDTH)]
	for span: Vector2 in spans:
		if span.y - span.x > 0.01:
			_wall_run(s, Vector3((span.x + span.y) * 0.5, 0.0, z), Vector3(span.y - span.x, 0.0, WALL_THICK), false)
	# Over the hole: the lintel (the plum wall), down to the hole's top.
	var lintel: float = HEIGHT - hole_height
	s.box(L(Vector3(hole_x, hole_height + lintel * 0.5, z)), Vector3(hole_width, lintel, WALL_THICK), WALL, 0.0, MeshKit.PAT_PLAIN)
	# Over the door: the wall from the door's top up.
	s.box(L(Vector3(DOOR_X, (HEIGHT + DOOR_HEIGHT) * 0.5, z)), Vector3(DOOR_WIDTH, HEIGHT - DOOR_HEIGHT, WALL_THICK), WALL, 0.0,
		MeshKit.PAT_PLAIN)
	# The door's surround: gilded columns, an arched pediment, a brass lamp either side, the passage behind it dark.
	var front: float = DEPTH - 0.05
	for side: float in [-1.0, 1.0]:
		var cx: float = DOOR_X + side * (DOOR_WIDTH * 0.5 + 0.22)
		s.box(L(Vector3(cx, DOOR_HEIGHT * 0.5 + 0.2, front - 0.1)), Vector3(0.36, DOOR_HEIGHT + 0.4, 0.3), GOLD, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.9)
		s.box(L(Vector3(cx, 0.15, front - 0.12)), Vector3(0.5, 0.3, 0.4), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
		var lx: float = DOOR_X + side * (DOOR_WIDTH * 0.5 + 0.9)
		s.box(L(Vector3(lx, 2.6, front - 0.1)), Vector3(0.14, 0.6, 0.2), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.7)
		s.box(L(Vector3(lx, 3.0, front - 0.2)), Vector3(0.22, 0.26, 0.22), LAMP, 1.0)
		g.rect(L(Vector3(lx - 0.9, 2.1, front - 0.35)), Vector3(1.8, 0.0, 0.0), Vector3(0.0, 1.8, 0.0), LAMP, 0.5, MeshKit.SHAPE_RADIAL)
	# The pediment: a gilded lintel, a stepped crown and a sunburst of gilded rays over it.
	s.box(L(Vector3(DOOR_X, DOOR_HEIGHT + 0.5, front - 0.12)), Vector3(DOOR_WIDTH + 1.0, 0.45, 0.34), GOLD, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.9)
	s.box(L(Vector3(DOOR_X, DOOR_HEIGHT + 0.85, front - 0.1)), Vector3(DOOR_WIDTH + 0.4, 0.25, 0.28), GOLD, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.9)
	for i: int in 9:
		var a: float = lerpf(-1.25, 1.25, float(i) / 8.0)
		var ray_len: float = 0.9 if i % 2 == 0 else 0.6
		var base := Vector3(DOOR_X, DOOR_HEIGHT + 1.0, front - 0.08)
		var dir := Vector3(sin(a), cos(a), 0.0)
		var xf := Transform3D(Basis(Vector3.BACK, -a) * Basis.from_scale(Vector3(0.09, ray_len, 0.06)), L(base + dir * ray_len * 0.5))
		s.box_xform(xf, GOLD, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 1.0)
	# The passage behind the door: dark, a faint warm light at its far end.
	var deep: float = DEPTH + WALL_THICK + 2.5
	s.box(L(Vector3(DOOR_X, DOOR_HEIGHT * 0.5, deep)), Vector3(DOOR_WIDTH + 0.4, DOOR_HEIGHT + 0.2, 5.0), IRON_DARK * 0.6, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ & ~MeshKit.FACE_PZ)
	s.box(L(Vector3(DOOR_X, DOOR_HEIGHT * 0.5, deep + 2.5)), Vector3(DOOR_WIDTH + 0.4, DOOR_HEIGHT + 0.2, 0.1), WALL_DARK, 0.0,
		MeshKit.PAT_PLAIN)
	g.rect(L(Vector3(DOOR_X - 1.0, 0.6, deep + 2.3)), Vector3(2.0, 0.0, 0.0), Vector3(0.0, 2.6, 0.0), LAMP, 0.35, MeshKit.SHAPE_RADIAL)
	# Behind the hole: the dark the House stands in (the street beyond, unlit), so the hole never shows the sky.
	var back_z: float = DEPTH + house_shape.depth + 3.0
	s.box(L(Vector3(hole_x, HEIGHT * 0.5, back_z)), Vector3(hole_width + 12.0, HEIGHT + 4.0, 0.4), IRON_DARK * 0.4, 0.0, MeshKit.PAT_PLAIN)
	for side: float in [-1.0, 1.0]:
		s.box(L(Vector3(hole_x + side * (hole_width * 0.5 + 6.0), HEIGHT * 0.5, (DEPTH + back_z) * 0.5)),
			Vector3(0.4, HEIGHT + 4.0, back_z - DEPTH), IRON_DARK * 0.4, 0.0, MeshKit.PAT_PLAIN)
	s.box(L(Vector3(hole_x, HEIGHT + 1.0, (DEPTH + back_z) * 0.5)), Vector3(hole_width + 12.0, 0.4, back_z - DEPTH), IRON_DARK * 0.4,
		0.0, MeshKit.PAT_PLAIN)
	s.box(L(Vector3(hole_x, -0.05, (DEPTH + back_z) * 0.5)), Vector3(hole_width + 12.0, 0.1, back_z - DEPTH), Color(0.08, 0.07, 0.07),
		0.0, MeshKit.PAT_PLAIN)


func _chandeliers(s: MeshLayer, g: MeshLayer) -> void:
	for c: Vector3 in CHANDELIERS:
		# The chain up to the ceiling, a crown, two rings of arms with warm bulbs, a drop under it.
		s.box(L(Vector3(c.x, (c.y + 1.6 + HEIGHT) * 0.5, c.z)), Vector3(0.08, HEIGHT - c.y - 1.6, 0.08), BRASS_DARK, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.3)
		s.prism(L(Vector3(c.x, c.y + 1.2, c.z)), 0.5, 0.4, 10, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.8)
		s.prism(L(Vector3(c.x, c.y - 0.5, c.z)), 0.22, 0.6, 8, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.8)
		for ring: int in 2:
			var r: float = 1.6 if ring == 0 else 1.0
			var y: float = c.y + (0.0 if ring == 0 else 0.7)
			var count: int = 12 if ring == 0 else 8
			s.prism(L(Vector3(c.x, y - 0.06, c.z)), r, 0.12, 16, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.8)
			for i: int in count:
				var a: float = TAU * (float(i) + 0.5 * float(ring)) / float(count)
				var b: Vector3 = Vector3(c.x + cos(a) * r, y + 0.16, c.z + sin(a) * r)
				s.box(L(b), Vector3(0.14, 0.24, 0.14), LAMP, 1.2)
			g.rect(L(Vector3(c.x - r * 1.9, y - r * 1.2, c.z)), Vector3(r * 3.8, 0.0, 0.0), Vector3(0.0, r * 2.6, 0.0), LAMP, 0.32,
				MeshKit.SHAPE_RADIAL)


## The hall's light on the people (the rig's material is lit; the hall's own surfaces carry the kit's fake light): a warm
## light from high over the floor, and the chandeliers', the bar's and the door's lamps as warm pools.
func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.name = "HallLight"
	key.light_color = Color(1.0, 0.86, 0.7)
	key.light_energy = 0.75
	key.rotation_degrees = Vector3(-58.0, 200.0, 0.0)
	key.shadow_enabled = false
	key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(key)
	var pools: Array[Vector4] = []
	for c: Vector3 in CHANDELIERS:
		pools.append(Vector4(c.x, c.y - 1.0, c.z, 15.0))
	pools.append(Vector4(BAR_FRONT + 0.4, 2.4, (BAR_Z.x + BAR_Z.y) * 0.5, 9.0))
	pools.append(Vector4(DOOR_X, 3.4, DEPTH - 2.5, 8.0))
	for i: int in pools.size():
		var p: Vector4 = pools[i]
		var omni := OmniLight3D.new()
		omni.name = "Lamp%d" % i
		omni.light_color = LAMP
		omni.light_energy = 1.3
		omni.omni_range = p.w
		omni.omni_attenuation = 0.8
		omni.shadow_enabled = false
		add_child(omni)
		omni.position = L(Vector3(p.x, p.y, p.z))


# --- The furniture -----------------------------------------------------------------------------------

func _build_furniture() -> void:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material())
	var g: MeshLayer = batch.layer(glow_material())
	_roulette_table(s)
	_blackjack(s, BLACKJACK_A, 25.0, 11)
	_blackjack(s, BLACKJACK_B, -15.0, 23)
	_poker(s, POKER, 31)
	_dice_table(s, DICE_TABLE, 47)
	_slot_banks(s, g)
	_bar(s, g)
	_ropes(s)
	for p: Vector3 in [HOLO_DICE, HOLO_WHEEL, HOLO_SPHERE]:
		_holo_base(s, p)
	_tables = batch.commit(self, "Furniture")
	if _tables != null:
		_tables.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A table's wooden body: a rounded slab of felt on a wood apron with a padded rail and a brass edge, on a plinth.
func _table_body(s: MeshLayer, center: Vector3, size: Vector2, felt: Color, turn: float) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(turn))
	var at: Callable = func(local: Vector3) -> Vector3: return L(center + basis * local)
	var b: Basis = Basis(Vector3.UP, deg_to_rad(-turn))
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(size.x * 0.7, TABLE_HEIGHT - 0.18, size.y * 0.55)),
		at.call(Vector3(0.0, (TABLE_HEIGHT - 0.18) * 0.5, 0.0))), WOOD, 0.0, MeshKit.PAT_PLAIN)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(size.x, 0.16, size.y)), at.call(Vector3(0.0, TABLE_HEIGHT - 0.1, 0.0))),
		WOOD_LIGHT, 0.0, MeshKit.PAT_PLAIN)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(size.x - 0.26, 0.02, size.y - 0.26)), at.call(Vector3(0.0, TABLE_HEIGHT, 0.0))),
		felt, 0.0, MeshKit.PAT_PLAIN)
	# The padded rail round it (dark leather), its brass edge.
	for side: float in [-1.0, 1.0]:
		s.box_xform(Transform3D(b * Basis.from_scale(Vector3(size.x, 0.08, 0.13)), at.call(Vector3(0.0, TABLE_HEIGHT + 0.02,
			side * (size.y * 0.5 - 0.065)))), Color(0.1, 0.05, 0.04), 0.0, MeshKit.PAT_PLAIN)
		s.box_xform(Transform3D(b * Basis.from_scale(Vector3(0.13, 0.08, size.y)), at.call(Vector3(side * (size.x * 0.5 - 0.065),
			TABLE_HEIGHT + 0.02, 0.0))), Color(0.1, 0.05, 0.04), 0.0, MeshKit.PAT_PLAIN)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(size.x + 0.04, 0.03, size.y + 0.04)), at.call(Vector3(0.0, TABLE_HEIGHT - 0.19, 0.0))),
		BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.7)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(size.x * 0.75, 0.08, size.y * 0.6)), at.call(Vector3(0.0, 0.04, 0.0))),
		BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.4)


## A stack of `count` chips at `p` (track space, on a table's felt).
func _chips(s: MeshLayer, p: Vector3, count: int, color: Color) -> void:
	s.prism(L(p), 0.035, 0.009 * float(count), 8, color, 0.0, MeshKit.PAT_PLAIN)
	s.prism(L(p + Vector3(0.0, 0.009 * float(count), 0.0)), 0.03, 0.002, 8, color.lightened(0.3), 0.0, MeshKit.PAT_PLAIN)


## A playing card lying on the felt at `p`, turned `turn` degrees, face up or not.
func _card(s: MeshLayer, p: Vector3, turn: float, face_up: bool) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(turn)) * Basis.from_scale(Vector3(0.06, 0.004, 0.085)), L(p + Vector3(0.0, 0.004, 0.0)))
	s.box_xform(xf, CARD if face_up else CARD_BACK, 0.0, MeshKit.PAT_PLAIN)
	if face_up:
		var pip := Transform3D(Basis(Vector3.UP, deg_to_rad(turn)) * Basis.from_scale(Vector3(0.02, 0.002, 0.026)), L(p + Vector3(0.0, 0.007, 0.0)))
		s.box_xform(pip, Color(0.45, 0.08, 0.1) if int(absf(turn)) % 2 == 0 else Color(0.08, 0.08, 0.09), 0.0, MeshKit.PAT_PLAIN)


func _roulette_table(s: MeshLayer) -> void:
	_table_body(s, ROULETTE, ROULETTE_SIZE, FELT, 0.0)
	# The betting layout: a grid of numbers in alternating dull red and black cells with white lines (unlit), the zero
	# cell nearest the wheel, the outside bets along the near edge.
	var x0: float = ROULETTE.x - ROULETTE_SIZE.x * 0.5 + 0.25
	var x1: float = wheel_center().x - 0.66
	var cols: int = 12
	var cw: float = (x1 - x0) / float(cols)
	for c: int in cols:
		for r: int in 3:
			var cx: float = x0 + (float(c) + 0.5) * cw
			var cz: float = ROULETTE.z + 0.05 + (float(r) - 1.0) * 0.2
			var red: bool = (c + r) % 2 == 0
			s.box(L(Vector3(cx, TABLE_HEIGHT + 0.012, cz)), Vector3(cw - 0.016, 0.004, 0.184),
				Color(0.42, 0.07, 0.08) if red else Color(0.06, 0.06, 0.07), 0.0, MeshKit.PAT_PLAIN)
	s.box(L(Vector3(x1 + 0.08, TABLE_HEIGHT + 0.012, ROULETTE.z + 0.05)), Vector3(0.14, 0.004, 0.58), Color(0.08, 0.3, 0.16), 0.0,
		MeshKit.PAT_PLAIN)
	for i: int in 3:
		var cx: float = x0 + (float(i) + 0.5) * (x1 - x0) / 3.0
		s.box(L(Vector3(cx, TABLE_HEIGHT + 0.012, ROULETTE.z - 0.42)), Vector3((x1 - x0) / 3.0 - 0.02, 0.004, 0.16), FELT.lightened(0.15),
			0.0, MeshKit.PAT_PLAIN)
	# Bets on the layout: chip stacks scattered over it, the dolly by the winning number.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	for i: int in 16:
		var p := Vector3(rng.randf_range(x0, x1), TABLE_HEIGHT + 0.014, ROULETTE.z + rng.randf_range(-0.5, 0.3))
		_chips(s, p, rng.randi_range(1, 6), CHIPS[rng.randi() % CHIPS.size()])
	# The croupier's chip float at the wheel's end, and the players' stacks along the far rail.
	for i: int in 6:
		_chips(s, Vector3(wheel_center().x - 0.75 + 0.08 * float(i % 3), TABLE_HEIGHT + 0.014, ROULETTE.z - 0.62 + 0.09 * float(i / 3)),
			12, CHIPS[i % CHIPS.size()])
	for i: int in 8:
		_chips(s, Vector3(x0 + 0.3 + 0.36 * float(i), TABLE_HEIGHT + 0.014, ROULETTE.z + 0.62), rng.randi_range(4, 12),
			CHIPS[rng.randi() % CHIPS.size()])


func _blackjack(s: MeshLayer, center: Vector3, turn: float, seed_value: int) -> void:
	_table_body(s, center, Vector2(2.2, 1.2), FELT_BLUE, turn)
	var basis := Basis(Vector3.UP, deg_to_rad(turn))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Five places along its curved side, each with a hand of two cards and a bet; the dealer's hand and shoe.
	for i: int in 5:
		var a: float = lerpf(-0.9, 0.9, float(i) / 4.0)
		var local := Vector3(sin(a) * 0.75, TABLE_HEIGHT + 0.012, 0.32 - cos(a) * 0.2 + 0.1)
		var p: Vector3 = center + basis * local
		_card(s, p, turn + rad_to_deg(a) + 8.0, true)
		_card(s, p + basis * Vector3(0.04, 0.003, 0.02), turn + rad_to_deg(a) - 6.0, true)
		_chips(s, center + basis * Vector3(sin(a) * 0.6, TABLE_HEIGHT + 0.014, 0.12), rng.randi_range(2, 8), CHIPS[rng.randi() % CHIPS.size()])
	_card(s, center + basis * Vector3(-0.05, TABLE_HEIGHT + 0.012, -0.3), turn, true)
	_card(s, center + basis * Vector3(0.05, TABLE_HEIGHT + 0.015, -0.3), turn + 5.0, false)
	s.box(L(center + basis * Vector3(0.6, TABLE_HEIGHT + 0.06, -0.32)), Vector3(0.14, 0.12, 0.22), Color(0.12, 0.12, 0.13), 0.0,
		MeshKit.PAT_PLAIN)
	for i: int in 4:
		_chips(s, center + basis * Vector3(-0.3 + 0.1 * float(i), TABLE_HEIGHT + 0.014, -0.42), 14, CHIPS[i])


func _poker(s: MeshLayer, center: Vector3, seed_value: int) -> void:
	# An oval table: a long slab with rounded ends (prisms), the dealer's button and the pot in the middle.
	var size := Vector2(2.8, 1.4)
	_table_body(s, center, Vector2(size.x - size.y * 0.5, size.y), FELT, 0.0)
	for side: float in [-1.0, 1.0]:
		var end: Vector3 = center + Vector3(side * (size.x * 0.5 - size.y * 0.5), 0.0, 0.0)
		s.prism(L(end + Vector3(0.0, TABLE_HEIGHT - 0.18, 0.0)), size.y * 0.5, 0.16, 16, WOOD_LIGHT, 0.0, MeshKit.PAT_PLAIN)
		s.prism(L(end + Vector3(0.0, TABLE_HEIGHT - 0.02, 0.0)), size.y * 0.5 - 0.13, 0.03, 16, FELT, 0.0, MeshKit.PAT_PLAIN)
		s.prism(L(end), size.y * 0.3, TABLE_HEIGHT - 0.18, 10, WOOD, 0.0, MeshKit.PAT_PLAIN)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in 5:
		_card(s, center + Vector3(-0.3 + 0.15 * float(i), TABLE_HEIGHT + 0.012, 0.0), 0.0, true)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		var p: Vector3 = center + Vector3(cos(a) * 1.05, TABLE_HEIGHT + 0.012, sin(a) * 0.45)
		_card(s, p, rad_to_deg(a), false)
		_card(s, p + Vector3(0.03, 0.003, 0.0), rad_to_deg(a) + 10.0, false)
		_chips(s, p + Vector3(-cos(a) * 0.2, 0.002, -sin(a) * 0.12), rng.randi_range(4, 14), CHIPS[rng.randi() % CHIPS.size()])
	for i: int in 5:
		_chips(s, center + Vector3(rng.randf_range(-0.2, 0.2), TABLE_HEIGHT + 0.014, rng.randf_range(0.18, 0.3)), rng.randi_range(3, 9),
			CHIPS[rng.randi() % CHIPS.size()])


func _dice_table(s: MeshLayer, center: Vector3, seed_value: int) -> void:
	# A dice table: a long sunken tub, its walls padded, a pair of dice and the chips on the rails.
	var size := Vector2(3.0, 1.5)
	_table_body(s, center, size, FELT, 90.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in 2:
		s.box(L(center + Vector3(rng.randf_range(-0.3, 0.3), TABLE_HEIGHT + 0.03, rng.randf_range(-0.6, 0.6))), Vector3(0.06, 0.06, 0.06),
			CARD, 0.0, MeshKit.PAT_PLAIN)
	for i: int in 12:
		_chips(s, center + Vector3(rng.randf_range(-0.55, 0.55), TABLE_HEIGHT + 0.014, rng.randf_range(-1.2, 1.2)), rng.randi_range(2, 9),
			CHIPS[rng.randi() % CHIPS.size()])


## A hologram's pedestal: a round brass-and-iron plinth with a ring of cold lights round its top.
func _holo_base(s: MeshLayer, p: Vector3) -> void:
	s.prism(L(p), 1.05, 0.22, 16, IRON, 0.0, MeshKit.PAT_CASINO_IRON, true, 2.0)
	s.prism(L(p + Vector3(0.0, 0.22, 0.0)), 0.95, 0.12, 16, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.7)
	s.prism(L(p + Vector3(0.0, 0.34, 0.0)), 0.7, 0.32, 16, IRON_DARK, 0.0, MeshKit.PAT_PLAIN)
	s.prism(L(p + Vector3(0.0, 0.66, 0.0)), 0.74, 0.05, 16, SCREEN_BLUE, 1.0, MeshKit.PAT_PLAIN)
	# A rail round it where the players lean, chips on it.
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		s.box(L(p + Vector3(cos(a) * 1.0, 0.5, sin(a) * 1.0)), Vector3(0.1, 0.06, 0.1), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES, 0.4)


## Banks of slot machines: along the left wall (facing into the hall) and an island of them near the back right.
func _slot_banks(s: MeshLayer, g: MeshLayer) -> void:
	var z: float = 6.0
	var i: int = 0
	while z < 37.0:
		if absf(z - 20.0) > 1.0 and absf(fmod(z, 8.0) - 4.0) > 0.7:
			_slot(s, g, Vector3(-HALF_WIDTH + 0.65, 0.0, z), 90.0, i)
		z += 1.0
		i += 1
	for k: int in 6:
		_slot(s, g, Vector3(11.0 + 0.95 * float(k % 3) - 0.95, 0.0, 35.4 + (0.0 if k < 3 else 1.2)), 180.0 if k < 3 else 0.0, k + 40)


## One slot machine at `p` facing `turn` degrees (0: +z, toward the back wall; 90: +x): an iron and brass cabinet,
## its reels' window lit warm, a violet or blue screen over it, its lever, a lamp on top.
func _slot(s: MeshLayer, g: MeshLayer, p: Vector3, turn: float, seed_value: int) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(turn))
	var b: Basis = Basis(Vector3.UP, deg_to_rad(-turn))
	var at: Callable = func(local: Vector3) -> Vector3: return L(p + basis * local)
	var screen: Color = SCREEN_VIOLET if seed_value % 3 != 1 else SCREEN_BLUE
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(0.78, 1.45, 0.62)), at.call(Vector3(0.0, 0.725, 0.0))), IRON, 0.0,
		MeshKit.PAT_PLAIN)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(0.84, 0.1, 0.68)), at.call(Vector3(0.0, 0.05, 0.0))), BRASS_DARK, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(0.82, 0.06, 0.66)), at.call(Vector3(0.0, 1.47, 0.0))), BRASS, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.7)
	# The reels' window (warm) and the screen over it, on the cabinet's front (its local +z, toward the hall).
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(0.56, 0.3, 0.02)), at.call(Vector3(0.0, 0.92, 0.32))), LAMP, 0.55,
		MeshKit.PAT_PLAIN)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(0.6, 0.3, 0.02)), at.call(Vector3(0.0, 1.27, 0.32))), screen, 0.7,
		MeshKit.PAT_PLAIN)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(0.64, 0.12, 0.2)), at.call(Vector3(0.0, 0.66, 0.36))), BRASS_DARK, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(0.05, 0.4, 0.05)), at.call(Vector3(0.44, 1.05, 0.0))), BRASS, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.8)
	s.box_xform(Transform3D(b * Basis.from_scale(Vector3(0.1, 0.1, 0.1)), at.call(Vector3(0.44, 1.28, 0.0))), Color(0.12, 0.12, 0.14),
		0.0, MeshKit.PAT_PLAIN)
	s.prism(at.call(Vector3(0.0, 1.5, 0.0)), 0.09, 0.14, 8, LAMP_COLD if seed_value % 2 == 0 else LAMP, 0.8, MeshKit.PAT_PLAIN)
	# A stool in front of it.
	var stool: Vector3 = p + basis * Vector3(0.0, 0.0, 0.75)
	s.prism(L(stool), 0.05, 0.52, 6, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.4)
	s.prism(L(stool + Vector3(0.0, 0.52, 0.0)), 0.19, 0.07, 10, VELVET, 0.0, MeshKit.PAT_PLAIN)


## The bar along the right wall: a dark wood counter with a brass foot rail and a polished top, its stools, the back
## bar's mirrored shelves of bottles lit warm from beneath each shelf.
func _bar(s: MeshLayer, g: MeshLayer) -> void:
	var len: float = BAR_Z.y - BAR_Z.x
	var mid: float = (BAR_Z.x + BAR_Z.y) * 0.5
	var cx: float = BAR_FRONT + BAR_DEPTH * 0.5
	s.box(L(Vector3(cx, (BAR_HEIGHT - 0.06) * 0.5, mid)), Vector3(BAR_DEPTH, BAR_HEIGHT - 0.06, len), WOOD, 0.0, MeshKit.PAT_PLAIN)
	s.box(L(Vector3(cx - 0.05, BAR_HEIGHT - 0.03, mid)), Vector3(BAR_DEPTH + 0.16, 0.06, len + 0.16), WOOD_LIGHT, 0.0, MeshKit.PAT_PLAIN)
	s.box(L(Vector3(BAR_FRONT - 0.13, BAR_HEIGHT - 0.035, mid)), Vector3(0.06, 0.07, len + 0.16), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS,
		MeshKit.ALL_FACES, 0.8)
	s.box(L(Vector3(BAR_FRONT - 0.12, 0.16, mid)), Vector3(0.05, 0.05, len), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.8)
	# Panels down its front, brass-edged.
	var z: float = BAR_Z.x + 0.75
	while z < BAR_Z.y - 0.5:
		s.box(L(Vector3(BAR_FRONT - 0.005, BAR_HEIGHT * 0.5, z)), Vector3(0.02, BAR_HEIGHT * 0.62, 1.1), WOOD_LIGHT, 0.0, MeshKit.PAT_PLAIN)
		z += 1.5
	# Stools along it (but where the runner leans, and the screech sits).
	z = BAR_Z.x + 0.8
	while z < BAR_Z.y - 0.4:
		if absf(z - 15.0) > 1.4:
			s.prism(L(Vector3(BAR_FRONT - 0.55, 0.0, z)), 0.05, 0.6, 6, BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.4)
			s.prism(L(Vector3(BAR_FRONT - 0.55, 0.6, z)), 0.2, 0.08, 10, VELVET, 0.0, MeshKit.PAT_PLAIN)
		z += 1.3
	# The back bar: a dark wood case against the wall, mirrored shelves, bottles, warm light under each shelf.
	var bx: float = HALF_WIDTH - 0.45
	s.box(L(Vector3(bx, 0.5, mid)), Vector3(0.6, 1.0, len), WOOD, 0.0, MeshKit.PAT_PLAIN)
	s.box(L(Vector3(HALF_WIDTH - 0.08, 2.0, mid)), Vector3(0.05, 2.4, len - 0.4), Color(0.12, 0.13, 0.16), 0.0, MeshKit.PAT_GLASS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var bottles: Array[Color] = [Color(0.45, 0.28, 0.1), Color(0.12, 0.25, 0.14), Color(0.7, 0.72, 0.74), Color(0.3, 0.12, 0.16),
		Color(0.5, 0.42, 0.18), Color(0.2, 0.22, 0.35)]
	for shelf: int in 3:
		var y: float = 1.1 + 0.62 * float(shelf)
		s.box(L(Vector3(bx + 0.05, y, mid)), Vector3(0.42, 0.04, len - 0.4), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
		s.box(L(Vector3(bx - 0.14, y - 0.035, mid)), Vector3(0.03, 0.025, len - 0.5), LAMP, 0.9)
		var bz: float = BAR_Z.x + 0.4
		while bz < BAR_Z.y - 0.4:
			var h: float = rng.randf_range(0.2, 0.34)
			s.prism(L(Vector3(bx + rng.randf_range(-0.05, 0.12), y + 0.02, bz)), 0.04, h, 6, bottles[rng.randi() % bottles.size()], 0.0,
				MeshKit.PAT_PLAIN)
			s.prism(L(Vector3(bx, y + 0.02 + h, bz)), 0.015, 0.08, 6, Color(0.15, 0.12, 0.1), 0.0, MeshKit.PAT_PLAIN)
			bz += rng.randf_range(0.14, 0.26)
	# The bar's own lamps hanging over the counter.
	z = BAR_Z.x + 1.5
	while z < BAR_Z.y:
		s.box(L(Vector3(cx, 3.2, z)), Vector3(0.03, 2.4, 0.03), BRASS_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.3)
		s.prism(L(Vector3(cx, 1.85, z)), 0.2, 0.18, 8, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.8)
		s.box(L(Vector3(cx, 1.82, z)), Vector3(0.14, 0.06, 0.14), LAMP, 1.2)
		g.rect(L(Vector3(cx, 0.9, z - 0.8)), Vector3(0.0, 0.0, -1.6), Vector3(0.0, 1.6, 0.0), LAMP, 0.3, MeshKit.SHAPE_RADIAL)
		z += 3.0


## Brass posts and a velvet rope either side of the way to the golden door.
func _ropes(s: MeshLayer) -> void:
	for side: float in [-1.0, 1.0]:
		var posts: Array[Vector3] = []
		for k: int in 3:
			posts.append(Vector3(DOOR_X + side * 1.5, 0.0, DEPTH - 1.0 - 1.5 * float(k)))
		for p: Vector3 in posts:
			s.prism(L(p), 0.12, 0.05, 8, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.8)
			s.prism(L(p), 0.035, 0.8, 6, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.8)
			s.prism(L(p + Vector3(0.0, 0.8, 0.0)), 0.06, 0.08, 8, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.9)
		for k: int in posts.size() - 1:
			var a: Vector3 = posts[k] + Vector3(0.0, 0.74, 0.0)
			var b: Vector3 = posts[k + 1] + Vector3(0.0, 0.74, 0.0)
			var mid: Vector3 = (a + b) * 0.5 + Vector3(0.0, -0.18, 0.0)
			for half: Array in [[a, mid], [mid, b]]:
				var p0: Vector3 = half[0]
				var p1: Vector3 = half[1]
				var along: Vector3 = L(p1) - L(p0)
				var xf := Transform3D(Basis.looking_at(along.normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.05, 0.05, along.length())),
					(L(p0) + L(p1)) * 0.5)
				s.box_xform(xf, VELVET, 0.0, MeshKit.PAT_PLAIN)
