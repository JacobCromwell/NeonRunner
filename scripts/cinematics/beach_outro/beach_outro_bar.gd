class_name BeachOutroBar
extends Node3D
## The tiki bar of the Beach's outro (BeachOutro; the owner, October 15, 2026: "a tiki bar that is using the existing
## beach assets, though you might have to create some assets for the bar itself"; the bartender is the volleyball
## match's opponent). Visual only, moved by the cinematic's clock (update):
## - the bar is the Beach's own tiki bar kiosk (BeachDoodads' large doodad: a bamboo back wall with a shelf of
##   bottles, the counter, bamboo corner poles and a flat thatch canopy), built bigger and scaled down to the
##   characters (they are about 1.3-1.4 m tall);
## - dressed with the bar's own pieces (dressing(), one mesh in the skin's materials): the menu board on the back wall
##   (a timber-framed chalkboard of wordless rows, a cocktail glass drawn in chalk at the head of each, the Beach's
##   signs having no words, docs/OPEN_QUESTIONS_ANSWERED.md item 528), a little violet neon cocktail glass over it
##   (the Beach's decorative neon: violet, blue and warm white), two bamboo stools, two paper lanterns glowing warm
##   white under the canopy;
## - the two drinks (drink_mesh(): a tall glass of something sunset-coloured with a pineapple wedge, a straw and a
##   paper umbrella), on the counter from when the bartender sets them down (under the cut away to the palace), and
##   the shaker in his hand while he makes them;
## - the bartender (VolleyballRivalSuit on the humanoid rig): idle behind the counter; he gestures to the menu and
##   asks with open hands, nods, turns his back and shakes the drinks; back from the cut he's set them down, and ducks
##   behind the counter, hands over his head, as the bombs come.
## Its space ("bar space"): the origin on the floor at the middle of the counter's front, x across the track (+x out
## into the street), y up, z along the track (the node's -z: it sits in world axes, track z being world -z).
## DESIGN-TBD (docs/questions/f2e.md): the dressing's looks and the bartender's moves.

## The kiosk's counter as BeachDoodads builds it (unscaled metres): its top over the kiosk's floor, and its front
## (the top slab's) in from the kiosk's +x side.
const COUNTER_TOP: float = 1.25
const COUNTER_FRONT_IN: float = 0.07
## The back wall's inner face, in from the kiosk's -x side (unscaled).
const BACK_WALL_IN: float = 0.2
## The menu board: its middle along the bar, its bottom and size (bar space, metres); the neon glass over it.
const MENU_ALONG: float = 1.15
const MENU_BOTTOM: float = 1.48
const MENU_SIZE := Vector2(1.45, 0.78)
## The stools (along the bar), their seat's height and radius; the lanterns (along the bar, back from the front).
const STOOLS: Array[float] = [-1.35, 1.45]
const STOOL_HEIGHT: float = 0.6
const STOOL_RADIUS: float = 0.17
const LANTERNS: Array[float] = [-1.5, 1.5]
const LANTERN_BACK: float = 0.35
## The drinks on the counter: along it from the runner (theirs, and the screech's beside where it sits), in from its
## front edge.
const DRINK_IN: float = 0.14
## A drink's glass: its radius and height.
const GLASS_RADIUS: float = 0.04
const GLASS_HEIGHT: float = 0.15
## The shaker in his hand (its joint's space; metres) and its size.
const SHAKER_IN_HAND := Vector3(0.0, -0.1, -0.02)
const SHAKER_SIZE := Vector2(0.045, 0.17)
## Colours (sRGB): the chalkboard, chalk, the cocktail pictograms' muted paints, a drink's colours.
const BOARD := Color(0.07, 0.09, 0.08)
const CHALK := Color(0.78, 0.78, 0.74)
const GLASS := Color(0.72, 0.8, 0.82)
const DRINK := Color(0.86, 0.48, 0.26)
const DRINK_DEEP := Color(0.62, 0.22, 0.2)
const PINEAPPLE := Color(0.86, 0.74, 0.32)
const STRAW := Color(0.88, 0.88, 0.85)
const UMBRELLA := Color(0.35, 0.5, 0.82)
const STEEL := Color(0.62, 0.64, 0.68)
## How fast he turns his back and back round (seconds), how deep he ducks (metres) and how quickly.
const TURN_SECONDS: float = 0.6
const DUCK_DEPTH: float = 0.72
const DUCK_SECONDS: float = 0.35
## His shake: how fast (Hz) and how far his forearms swing (degrees).
const SHAKE_HZ: float = 4.2
const SHAKE_SWING: float = 22.0

var tuning: BeachOutroTuning
var skin: BeachSkin
## The kiosk's scale, the counter's top (bar space) and its depth from its front back to the bartender's side.
var scale_k: float = 0.7
var counter_top: float = 0.875
## The kiosk's middle (bar space) and its size (scaled).
var kiosk_center := Vector3.ZERO
var kiosk_size := Vector3.ONE
var bartender: Node3D
var rig: HumanoidRig
var drinks: Array[Node3D] = []
var shaker: MeshInstance3D
## Where the menu board's middle is (bar space): he points at it.
var menu_center := Vector3.ZERO

var _last_time: float = 0.0

static var _meshes: Dictionary = {}


## Builds it in `p_skin` (the stage's: a BeachSkin) from `p_tuning`.
func setup(p_skin: BeachSkin, p_tuning: BeachOutroTuning) -> void:
	name = "Bar"
	skin = p_skin
	tuning = p_tuning
	scale_k = tuning.kiosk_scale
	var raw: Vector3 = tuning.kiosk_size
	kiosk_size = raw * scale_k
	counter_top = COUNTER_TOP * scale_k
	kiosk_center = Vector3(-(raw.x * 0.5 - COUNTER_FRONT_IN) * scale_k, kiosk_size.y * 0.5, 0.0)
	var kiosk := Node3D.new()
	kiosk.name = "Kiosk"
	kiosk.position = local(kiosk_center)
	kiosk.scale = Vector3.ONE * scale_k
	add_child(kiosk)
	skin.doodad(kiosk, raw, &"large", -1, 7)
	var back: float = kiosk_center.x - (raw.x * 0.5 - BACK_WALL_IN) * scale_k
	menu_center = Vector3(back + 0.03, MENU_BOTTOM + MENU_SIZE.y * 0.5, MENU_ALONG)
	var dressing_mesh: MeshInstance3D = MeshBatch.add_instance(self, dressing(back), "Dressing")
	dressing_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i: int in 2:
		var d := Node3D.new()
		d.name = "Drink%d" % i
		add_child(d)
		var m: MeshInstance3D = MeshBatch.add_instance(d, drink_mesh(i), "Glass")
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.visible = false
		d.position = local(drink_spot(0.06 if i == 0 else tuning.perch_along + 0.3))
		drinks.append(d)
	_build_bartender()


## A bar-space point in the node's space (track z is world -z).
static func local(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y, -p.z)


## The bar's own pieces, one mesh in the skin's solid material: the menu board on the back wall (`back`, bar space x
## of its inner face), the neon glass over it, two stools out front and two paper lanterns under the canopy.
func dressing(back: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var c: Vector3 = local(menu_center)
	var w: float = MENU_SIZE.x
	var h: float = MENU_SIZE.y
	# The board: a timber frame round a dark chalkboard, facing +x (into the bar).
	s.box(c + Vector3(-0.015, 0.0, 0.0), Vector3(0.03, h + 0.08, w + 0.08), skin.timber_color * 0.8, 0.0,
		MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES, MeshKit.beach_timber_param(2, 1, 3))
	s.rect(c + Vector3(0.002, -h * 0.5 + 0.02, w * 0.5 - 0.02), Vector3(0, 0, -(w - 0.04)), Vector3(0, h - 0.04, 0), BOARD)
	# Four wordless rows: a cocktail glass drawn in chalk, a chalk line for its name and a short one for its price.
	var paints: PackedColorArray = skin.paint_colors
	for row: int in 4:
		var y: float = c.y + h * 0.5 - 0.13 - float(row) * 0.17
		var z0: float = c.z + w * 0.5 - 0.12
		var tint: Color = paints[(row * 2 + 1) % paints.size()].lerp(CHALK, 0.35)
		# The glass: a triangle bowl on a stem and a foot.
		s.quad(Vector3(c.x + 0.004, y + 0.05, z0 + 0.05), Vector3(c.x + 0.004, y + 0.05, z0 - 0.05),
			Vector3(c.x + 0.004, y - 0.005, z0), Vector3(c.x + 0.004, y - 0.005, z0), tint)
		s.rect(Vector3(c.x + 0.004, y - 0.05, z0 + 0.004), Vector3(0, 0, -0.008), Vector3(0, 0.046, 0), CHALK)
		s.rect(Vector3(c.x + 0.004, y - 0.055, z0 + 0.025), Vector3(0, 0, -0.05), Vector3(0, 0.008, 0), CHALK)
		# The lines.
		var name_len: float = 0.62 - 0.08 * float(row % 3)
		s.rect(Vector3(c.x + 0.004, y - 0.006, z0 - 0.1), Vector3(0, 0, -name_len), Vector3(0, 0.014, 0), CHALK)
		s.rect(Vector3(c.x + 0.004, y - 0.006, c.z - w * 0.5 + 0.28), Vector3(0, 0, -0.16), Vector3(0, 0.014, 0), CHALK)
	# The neon cocktail glass over the board (violet, decorative), on a small bamboo bracket.
	var g := Vector3(c.x + 0.05, c.y + h * 0.5 + 0.2, c.z)
	var violet: Color = skin.neon_violet
	var glow: float = skin.neon_glow * 2.0
	s.box(g + Vector3(0.0, 0.1, 0.11), Vector3(0.025, 0.025, 0.24), violet, glow)
	s.box_xform(Transform3D(Basis(Vector3.RIGHT, 0.6) * Basis.from_scale(Vector3(0.025, 0.025, 0.15)), g + Vector3(0, 0.04, 0.17)),
		violet, glow)
	s.box_xform(Transform3D(Basis(Vector3.RIGHT, -0.6) * Basis.from_scale(Vector3(0.025, 0.025, 0.15)), g + Vector3(0, 0.04, 0.05)),
		violet, glow)
	s.box(g + Vector3(0.0, -0.06, 0.11), Vector3(0.025, 0.12, 0.025), violet, glow)
	s.box(g + Vector3(0.0, -0.12, 0.11), Vector3(0.025, 0.025, 0.12), violet, glow)
	s.box(Vector3(back + 0.04, g.y, g.z + 0.11), Vector3(0.08, 0.05, 0.05), skin.post_color)
	# Two bamboo stools out in front of the counter.
	var bamboo: Color = skin.bamboo_colors[0]
	for along: float in STOOLS:
		var at := local(Vector3(0.38, 0.0, along))
		s.prism(at + Vector3(0, STOOL_HEIGHT - 0.05, 0), STOOL_RADIUS, 0.06, 8, skin.timber_color, 0.0, MeshKit.PAT_BEACH_TIMBER,
			true, MeshKit.beach_timber_param(2, 1, 9))
		for k: int in 4:
			var a: float = TAU * (float(k) + 0.5) / 4.0
			var foot := at + Vector3(cos(a), 0.0, sin(a)) * STOOL_RADIUS * 0.9
			var top := at + Vector3(cos(a), 0.0, sin(a)) * STOOL_RADIUS * 0.55 + Vector3(0, STOOL_HEIGHT - 0.05, 0)
			_pole(s, foot, top, 0.022, bamboo)
		s.prism(at + Vector3(0, 0.22, 0), STOOL_RADIUS * 0.82, 0.025, 8, bamboo)
	# Two paper lanterns hanging under the canopy's front: a muted shell round a warm-white glow.
	var canopy: float = kiosk_size.y - 0.32
	for k: int in LANTERNS.size():
		var at := local(Vector3(-LANTERN_BACK, canopy - 0.42, LANTERNS[k]))
		var shell: Color = skin.lantern_shell_colors[k % skin.lantern_shell_colors.size()]
		s.prism(at, 0.11, 0.22, 8, shell.lerp(skin.neon_white, 0.5), 0.9)
		s.prism(at + Vector3(0, 0.22, 0), 0.07, 0.03, 8, skin.timber_color * 0.6)
		s.prism(at + Vector3(0, -0.03, 0), 0.07, 0.03, 8, skin.timber_color * 0.6)
		s.box(at + Vector3(0, 0.25 + 0.1, 0), Vector3(0.008, 0.2, 0.008), skin.timber_color * 0.5)
	return batch.to_mesh()


## A bamboo pole from `a` to `b`, `r` thick.
static func _pole(s: MeshLayer, a: Vector3, b: Vector3, r: float, color: Color) -> void:
	var d: Vector3 = b - a
	var up: Vector3 = d.normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side * r, d, up.cross(side) * r)
	s.prism_xform(Transform3D(basis, a), 6, color)


## A drink (the runner's, `which` 0, or the screech's, 1): a tall glass of something sunset-coloured (deeper at the
## bottom), a wedge of pineapple on its rim, a straw and a little paper umbrella; standing on y = 0. Cached.
static func drink_mesh(which: int) -> ArrayMesh:
	var key: String = "beach_outro_drink_%d" % which
	if _meshes.has(key):
		return _meshes[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(MeshKit.solid())
	var r: float = GLASS_RADIUS
	var h: float = GLASS_HEIGHT
	s.prism(Vector3.ZERO, r * 1.1, 0.012, 8, GLASS)
	s.prism(Vector3(0, 0.012, 0), r * 0.98, h * 0.45, 8, DRINK_DEEP)
	s.prism(Vector3(0, 0.012 + h * 0.45, 0), r, h * 0.42, 8, DRINK)
	s.prism(Vector3(0, 0.012 + h * 0.87, 0), r * 1.04, h * 0.1, 8, GLASS)
	# The pineapple wedge on the rim, the straw and the umbrella.
	s.box_xform(Transform3D(Basis(Vector3.FORWARD, 0.5) * Basis.from_scale(Vector3(0.045, 0.03, 0.02)),
		Vector3(r * 0.95, h * 0.97, 0.0)), PINEAPPLE)
	s.box_xform(Transform3D(Basis(Vector3.FORWARD, -0.25) * Basis.from_scale(Vector3(0.008, h * 0.6, 0.008)),
		Vector3(-r * 0.35, h * 1.05, 0.006)), STRAW)
	var stick := Vector3(r * 0.3, h * 1.12, -r * 0.4)
	s.box_xform(Transform3D(Basis(Vector3.RIGHT, -0.35) * Basis.from_scale(Vector3(0.005, 0.1, 0.005)), stick), STRAW)
	var top: Vector3 = stick + Basis(Vector3.RIGHT, -0.35) * Vector3(0, 0.05, 0)
	var paint: Color = UMBRELLA if which == 0 else UMBRELLA.lerp(Color(0.62, 0.42, 0.85), 0.7)
	for k: int in 6:
		var a0: float = TAU * float(k) / 6.0
		var a1: float = TAU * float(k + 1) / 6.0
		var p0: Vector3 = top + Vector3(cos(a0) * 0.06, -0.022, sin(a0) * 0.06)
		var p1: Vector3 = top + Vector3(cos(a1) * 0.06, -0.022, sin(a1) * 0.06)
		s.quad(top, p1, p0, p0, paint if k % 2 == 0 else paint.lerp(Color.WHITE, 0.3))
		s.quad(top, p0, p1, p1, paint.darkened(0.3))
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[key] = mesh
	return mesh


func _build_bartender() -> void:
	bartender = Node3D.new()
	bartender.name = "Bartender"
	add_child(bartender)
	rig = HumanoidRig.new()
	rig.name = "Rig"
	bartender.add_child(rig)
	var anim := load(PlayerAvatar.ANIM_TUNING_PATH) as HumanoidAnimTuning
	rig.build(VolleyballRivalSuit.parts(), VolleyballRivalSuit.material(), anim if anim != null else HumanoidAnimTuning.new())
	rig.scale = Vector3.ONE * (tuning.bartender_height / VolleyballRivalSuit.DESIGN_HEIGHT)
	bartender.position = local(tuning.bartender_at)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(MeshKit.solid())
	s.prism(Vector3(0, -SHAKER_SIZE.y * 0.5, 0), SHAKER_SIZE.x, SHAKER_SIZE.y * 0.8, 8, STEEL)
	s.prism(Vector3(0, SHAKER_SIZE.y * 0.3, 0), SHAKER_SIZE.x * 0.8, SHAKER_SIZE.y * 0.2, 8, STEEL.darkened(0.15))
	shaker = MeshBatch.add_instance(rig.joint(&"hand_r"), batch.to_mesh(), "Shaker", SHAKER_IN_HAND)
	shaker.visible = false
	update(0.0)


## Poses the bartender and shows the drinks at time `t` (the cinematic's clock).
func update(t: float) -> void:
	var delta: float = clampf(t - _last_time, 0.0, 0.1)
	_last_time = t
	var n: BeachOutroTuning = tuning
	var served: bool = t >= n.palace_at
	for d: Node3D in drinks:
		d.visible = served
	# Facing the customers (+x), turned to the back wall while he makes the drinks; facing them again once served.
	var away: float = smoothstep(n.turn_back_at, n.turn_back_at + TURN_SECONDS, t) * (0.0 if served else 1.0)
	bartender.rotation.y = -PI * 0.5 + PI * away
	# Ducking behind the counter as the bombs come.
	var duck: float = smoothstep(n.duck_at, n.duck_at + DUCK_SECONDS, t)
	rig.animate({"speed": 0.0}, delta)
	rig.position.y = -DUCK_DEPTH * duck
	shaker.visible = t >= n.turn_back_at + TURN_SECONDS * 0.5 and not served
	var head: Node3D = rig.joint(&"head")
	if duck > 0.0:
		# Hands over his head.
		_arm(1, Vector3(150.0, 0.0, 55.0), Vector3(140.0, 0.0, 0.0), duck)
		_arm(-1, Vector3(150.0, 0.0, 55.0), Vector3(140.0, 0.0, 0.0), duck)
		head.rotation.x -= deg_to_rad(30.0) * duck
		return
	if served:
		# Leaning on the counter, hands on it, having set the drinks down.
		_arm(1, Vector3(40.0, 0.0, 12.0), Vector3(40.0, 0.0, 0.0), 1.0)
		_arm(-1, Vector3(40.0, 0.0, 12.0), Vector3(40.0, 0.0, 0.0), 1.0)
		return
	# The gesture to the menu: his head turns to it and his right arm points up at it.
	var point: float = _window(t, n.gesture_at, n.gesture_at + 0.45, n.gesture_at + n.gesture_seconds - 0.3,
		n.gesture_at + n.gesture_seconds + 0.2)
	if point > 0.0:
		GanglandOutro.aim_arm(rig, &"r", to_global(local(menu_center)), point)
		_turn_head(head, deg_to_rad(-70.0) * point, deg_to_rad(12.0) * point)
	# Asking: open hands, palms up, a tilt of his head.
	var ask: float = _window(t, n.ask_at, n.ask_at + 0.35, n.ask_at + 1.2, n.ask_at + 1.6)
	if ask > 0.0:
		_arm(1, Vector3(25.0, 0.0, 22.0), Vector3(75.0, 0.0, -20.0), ask)
		_arm(-1, Vector3(25.0, 0.0, 22.0), Vector3(75.0, 0.0, -20.0), ask)
		head.rotation.z += deg_to_rad(12.0) * ask
	# The nod: "two, coming up".
	var nod: float = (t - n.nod_at) / 0.5
	if nod > 0.0 and nod < 1.0:
		head.rotation.x -= deg_to_rad(20.0) * sin(PI * nod)
	# Shaking the drinks, his back to us: both forearms up in front of him, swinging.
	var shake: float = smoothstep(n.shake_at - 0.3, n.shake_at, t)
	if shake > 0.0:
		var swing: float = SHAKE_SWING * sin(TAU * SHAKE_HZ * (t - n.shake_at))
		_arm(1, Vector3(60.0 + swing * 0.5, 0.0, 18.0), Vector3(85.0 + swing, 0.0, 0.0), shake)
		_arm(-1, Vector3(60.0 + swing * 0.5, 0.0, 18.0), Vector3(85.0 + swing, 0.0, 0.0), shake)


## Turns his head: `yaw` radians (+ left), `pitch` (+ up).
static func _turn_head(head: Node3D, yaw: float, pitch: float) -> void:
	head.rotation.y += yaw
	head.rotation.x += pitch


## Poses one arm (`side` 1 his right, -1 his left), the upper arm and forearm in degrees (HumanoidPose's limb
## convention: +x swings the arm forward and up, +z out to the side), blended over the rig's pose by `k`.
func _arm(side: int, upper: Vector3, fore: Vector3, k: float) -> void:
	var pre: String = "_l" if side < 0 else "_r"
	_blend(rig.joint(StringName("upper_arm" + pre)), VolleyballRival._limb(side, upper), k)
	_blend(rig.joint(StringName("forearm" + pre)), VolleyballRival._limb(side, fore), k)


static func _blend(j: Node3D, euler: Vector3, k: float) -> void:
	if j == null:
		return
	j.quaternion = j.quaternion.slerp(Quaternion.from_euler(euler), clampf(k, 0.0, 1.0))


## 0 before `a`, rising to 1 by `b`, 1 until `c`, falling to 0 by `d` (smoothstep at each end).
static func _window(t: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, t) * (1.0 - smoothstep(c, d, t))


## Where a drink stands on the counter (bar space): `along` from the runner.
func drink_spot(along: float) -> Vector3:
	return Vector3(-DRINK_IN, counter_top, along)
