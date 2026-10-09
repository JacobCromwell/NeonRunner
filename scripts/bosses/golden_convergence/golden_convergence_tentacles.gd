class_name GoldenConvergenceTentacles
extends BossPart
## The Screen Storm's screens (GDD §10, the owner's playtest: "TV screens on gold tentacles come crashing down from
## the sky on either side of the runner"; proposed: "They're the feed's own screens, his glitching face on them,
## hanging from long gold broadcast tentacles out of the dark vault. Each spot is marked by a red square and the
## screen's growing shadow ... A crash hurts only in its square (and above a jump), shatters the screen, and its
## tentacle yanks it back up: nothing stays on the track"; task E5d-e). A pool of rigs made with the fight
## (GoldenConvergenceScreens drives them; nothing is built mid-fight), each:
## - a screen on its tentacle (one mesh, built once in code and shared: a 16:9 screen in a gilded frame, its dark
##   back, and the long gold tentacle curving up from its top into the vault, out of sight; the kit's solid shader
##   with the court's gold, never glowing): the picture is the feed's own (golden_court_feed.gdshader, his roaring
##   face, glitching: steady with Reduced flashing), dark once it has shattered (set_screen, shatter);
## - its red square on the floor (set_square: a frame in the enemy attacks' red round a faint fill, pulsing as
##   BossProps' red lines do, steady with Reduced flashing), sized for the fight's run speed
##   (GoldenConvergenceScreens.square_depth);
## - its shadow on the floor (set_shadow: a soft dark patch growing as the screen comes down, never glowing);
## - its touch (set_touch / touch_off: an enemy attack hitbox over the square, from the floor to screen_hit_height:
##   the armor and the shield block it, the dash passes through; each contact is reported, `hit`).
## shatter() throws its glass and (without Reduced flashing) sparks. A part of the boss that's no target and no
## kill of its own.

## The touch met the runner (`outcome`: a DamageRules.Outcome other than IGNORE).
signal hit(rig: int, outcome: int)

## Rigs made with the fight (the pool grows if a storm ever needs more at once).
const POOL: int = 8
## The screen: its picture's width (16:9), the gilded frame's rim and depth, the tentacle's length up into the vault
## and its thickness.
const SCREEN_WIDTH: float = 2.0
const SCREEN_HEIGHT: float = SCREEN_WIDTH * 9.0 / 16.0
const RIM: float = 0.11
const DEPTH: float = 0.16
const TENTACLE_LENGTH: float = 46.0
const TENTACLE_RADIUS: float = 0.12
## The square's frame width and its fill's see-through.
const FRAME: float = 0.16
const FILL_ALPHA: float = 0.16
## The glass flying off a shattered screen (pale, the feed's cold white: never a hazard colour), its sparks (the
## feed's warm white; none with Reduced flashing).
const GLASS := Color(0.78, 0.86, 0.95)
const SPARK := Color(1.0, 0.93, 0.82)
const FEED_SHADER: String = "res://scripts/bosses/golden_convergence/golden_court_feed.gdshader"
## The glitch on the falling screens' faces (held still with Reduced flashing by the feed's shader).
const GLITCH: float = 0.55

var tuning: GoldenConvergenceTuning
## The pool: {node, screen: MeshInstance3D, square: MeshInstance3D, shadow, shadow_mat, holder, touch, used,
## square_t, square_on}.
var rigs: Array[Dictionary] = []
## Contacts reported (tests): {rig, outcome, runner, lane, h}.
var hits: Array[Dictionary] = []
## The square's size (lane width share, depth along the track) the rigs were built for.
var square_size := Vector2.ONE
## Shards thrown, sparks thrown (tests: no sparks with Reduced flashing).
var shards_thrown: int = 0
var sparks_thrown: int = 0

var _screen_mesh: ArrayMesh
var _square_mesh: ArrayMesh
var _live_feed: ShaderMaterial
var _dead_feed: ShaderMaterial
var _shadow_shader: Shader
var _shadow_alpha: float = GoldenConvergenceFist.SHADOW_ALPHA


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as GoldenConvergenceTuning
	if tuning == null:
		tuning = GoldenConvergenceTuning.new()
	display_name = "a crashing screen"
	is_obstacle = true
	immune_to_weapons = true
	_shadow_alpha = GoldenConvergenceFist.shadow_alpha_for(RenderingServer.get_current_rendering_method())
	_shadow_shader = load(GoldenConvergenceFist.SHADOW_SHADER) as Shader
	_live_feed = feed_material(1.0, GLITCH)
	_dead_feed = feed_material(0.0, 0.0)
	var solid: Material = params.get("solid") as Material
	_screen_mesh = screen_mesh(solid, _live_feed)
	square_size = Vector2(world.geo.lane_width * tuning.screen_width_share,
		GoldenConvergenceScreens.square_depth(tuning, world.tuning))
	_square_mesh = square_mesh(world.geo.lane_width * 0.92, square_size.y)
	for i: int in POOL:
		_new_rig()


## A material for the falling screens' faces: the feed's own shader showing his roaring face (`power` 1 on, 0 a dead
## dark screen; `glitch` 0-1).
static func feed_material(power: float, glitch: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(FEED_SHADER) as Shader
	m.set_shader_parameter(&"feed_emblem", CultFeed.emblem_texture())
	m.set_shader_parameter(&"feed_mode", 1.0)
	m.set_shader_parameter(&"feed_power", power)
	m.set_shader_parameter(&"feed_glitch", glitch)
	return m


## The screen on its tentacle (its middle at the origin, its face toward +z, the runner coming up the track): the
## gilded frame and dark back and the gold tentacle in `solid`'s layer (the court's kit material), the picture in
## `feed`'s (surface 1, swapped per rig when it shatters).
static func screen_mesh(solid: Material, feed: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid)
	var gold := Color(0.86, 0.69, 0.36)
	var w: float = SCREEN_WIDTH
	var h: float = SCREEN_HEIGHT
	# The dark back and the gilded frame round the picture.
	s.box(Vector3(0.0, 0.0, -DEPTH * 0.15), Vector3(w + RIM, h + RIM, DEPTH * 0.7), Color(0.07, 0.06, 0.055), 0.0,
		MeshKit.PAT_PLAIN)
	for edge: Array in [[0.0, 0.5, w + RIM * 2.0, RIM], [0.0, -0.5, w + RIM * 2.0, RIM], [0.5, 0.0, RIM, h], [-0.5, 0.0, RIM, h]]:
		var c := Vector3(float(edge[0]) * (w + RIM), float(edge[1]) * (h + RIM), 0.0)
		s.box(c, Vector3(float(edge[2]), float(edge[3]), DEPTH), gold, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.85)
	# A crest over it (the towers' screens' halo, small) and the mount the tentacle grips.
	s.box(Vector3(0.0, h * 0.5 + RIM * 1.9, 0.0), Vector3(w * 0.3, RIM * 1.6, DEPTH * 0.8), gold, 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES, 0.85)
	s.prism(Vector3(0.0, h * 0.5 + RIM * 2.6, 0.0), TENTACLE_RADIUS * 1.9, 0.35, 8, gold, 0.0, MeshKit.PAT_GOLD, true, 0.8)
	# The tentacle: a gold tube curving up and back out of sight, banded every so often.
	var base := Vector3(0.0, h * 0.5 + RIM * 2.6 + 0.3, 0.0)
	var steps: int = 16
	var prev: Vector3 = base
	for k: int in steps:
		var u: float = float(k + 1) / float(steps)
		var p: Vector3 = base + Vector3(0.9 * sin(u * 2.4), TENTACLE_LENGTH * u, -3.0 * u * u)
		var r: float = TENTACLE_RADIUS * (1.0 + 0.5 * u)
		s.prism_xform(_along(prev, p, r), 6, gold.darkened(0.15), 0.0, MeshKit.PAT_GOLD, false, 0.7)
		if k % 2 == 1:
			s.prism_xform(_along(prev, prev + (p - prev).normalized() * 0.18, r * 1.35), 6, gold, 0.0, MeshKit.PAT_GOLD, true, 0.9)
		prev = p
	# The picture (its own surface: the feed's material).
	var f: MeshLayer = batch.layer(feed)
	f.rect(Vector3(-w * 0.5, -h * 0.5, DEPTH * 0.5 + 0.01), Vector3(w, 0.0, 0.0), Vector3(0.0, h, 0.0), Color.WHITE,
		0.9, 0, Vector2.ZERO, Vector2.ONE, w / h)
	return batch.to_mesh()


## The unit prism (radius 1, y from 0 to 1: MeshKit) stretched from `a` to `b`, `r` across.
static func _along(a: Vector3, b: Vector3, r: float) -> Transform3D:
	var dir: Vector3 = b - a
	var length: float = maxf(dir.length(), 0.001)
	var y: Vector3 = dir / length
	var x: Vector3 = y.cross(Vector3.BACK)
	if x.length() < 0.1:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y)
	return Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3(r, length, r)), a)


## The red square (its middle at the origin): a frame `width` wide and `depth` deep along the track in the warnings'
## red round a faint fill; two surfaces, one draw each.
static func square_mesh(width: float, depth: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var frame: MeshLayer = batch.layer(GreyboxMaterials.glow(BossProps.WARNING_COLOR, 2.6, 0.8))
	var r: float = FRAME
	frame.box(Vector3(0.0, 0.0, -depth * 0.5 + r * 0.5), Vector3(width, 0.04, r), Color.WHITE)
	frame.box(Vector3(0.0, 0.0, depth * 0.5 - r * 0.5), Vector3(width, 0.04, r), Color.WHITE)
	frame.box(Vector3(-width * 0.5 + r * 0.5, 0.0, 0.0), Vector3(r, 0.04, depth - r * 2.0), Color.WHITE)
	frame.box(Vector3(width * 0.5 - r * 0.5, 0.0, 0.0), Vector3(r, 0.04, depth - r * 2.0), Color.WHITE)
	var fill: MeshLayer = batch.layer(GreyboxMaterials.glow(BossProps.WARNING_COLOR, 1.2, FILL_ALPHA))
	fill.box(Vector3(0.0, -0.01, 0.0), Vector3(width - r * 2.0, 0.02, depth - r * 2.0), Color.WHITE)
	return batch.to_mesh()


func _new_rig() -> Dictionary:
	var i: int = rigs.size()
	var node := Node3D.new()
	node.name = "Screen%d" % i
	node.top_level = true
	add_child(node)
	var screen: MeshInstance3D = MeshBatch.add_instance(node, _screen_mesh, "TV")
	# The tentacle reaches far above what its box would say once it sways and tilts.
	screen.extra_cull_margin = 4.0
	var square: MeshInstance3D = MeshBatch.add_instance(self, _square_mesh, "Square%d" % i)
	square.top_level = true
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow%d" % i
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	shadow.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = _shadow_shader
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.top_level = true
	add_child(shadow)
	var holder := Node3D.new()
	holder.name = "Touch%d" % i
	holder.top_level = true
	add_child(holder)
	var touch: Hazard = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, holder)
	touch.hazard_name = "a crashing screen"
	touch.contacted.connect(_on_contacted.bind(i))
	var rig := {"node": node, "screen": screen, "square": square, "shadow": shadow, "shadow_mat": mat, "holder": holder,
		"touch": touch, "used": false, "square_t": 0.0, "square_on": false, "square_base": Transform3D.IDENTITY}
	rigs.append(rig)
	release(i)
	return rig


# --- The pool ---------------------------------------------------------------------------------------------

## A free rig (taken: in use until release()), the pool growing if it must.
func take() -> int:
	for i: int in rigs.size():
		if not bool(rigs[i]["used"]):
			rigs[i]["used"] = true
			return i
	_new_rig()
	rigs[-1]["used"] = true
	return rigs.size() - 1


## Rig `i` back to the pool: nothing of it shows or touches.
func release(i: int) -> void:
	var rig: Dictionary = rigs[i]
	rig["used"] = false
	hide_screen(i)
	hide_square(i)
	hide_shadow(i)
	touch_off(i)


func in_use(i: int) -> bool:
	return bool(rigs[i]["used"])


## Rigs in use now.
func used() -> int:
	var n: int = 0
	for rig: Dictionary in rigs:
		if bool(rig["used"]):
			n += 1
	return n


# --- The screen -------------------------------------------------------------------------------------------

## Rig `i`'s screen with its picture's bottom edge `bottom` metres up at world x `x` and z `z`, tilted `tilt`
## radians (a sway as it comes down, a lurch as it's yanked), its face live (on) or dark (shattered).
func set_screen(i: int, x: float, z: float, bottom: float, tilt: float = 0.0, live: bool = true) -> void:
	var rig: Dictionary = rigs[i]
	var node: Node3D = rig["node"]
	var y: float = bottom + SCREEN_HEIGHT * 0.5 + RIM
	node.global_transform = Transform3D(Basis(Vector3.BACK, tilt), Vector3(x, y, z))
	node.visible = true
	(rig["screen"] as MeshInstance3D).set_surface_override_material(1, _live_feed if live else _dead_feed)


func hide_screen(i: int) -> void:
	(rigs[i]["node"] as Node3D).visible = false


func screen_on(i: int) -> bool:
	return (rigs[i]["node"] as Node3D).visible


## Where rig `i`'s screen is (its middle, world space).
func screen_point(i: int) -> Vector3:
	return (rigs[i]["node"] as Node3D).global_position


## Its bottom edge's height now.
func screen_bottom(i: int) -> float:
	return screen_point(i).y - SCREEN_HEIGHT * 0.5 - RIM


## The screen shatters at `at` (world space): its face goes dark, its glass flies (and sparks, without Reduced
## flashing).
func shatter(i: int, at: Vector3) -> void:
	var rig: Dictionary = rigs[i]
	(rig["screen"] as MeshInstance3D).set_surface_override_material(1, _dead_feed)
	if world == null or world.effects == null:
		return
	world.effects.debris(at, GLASS, 12, 1.0)
	world.effects.burst(at, GLASS, 18, 0.7)
	shards_thrown += 1
	if not Settings.flashing_reduced:
		world.effects.burst(at + Vector3(0.0, 0.3, 0.0), SPARK, 12, 0.45)
		sparks_thrown += 1


# --- The red square and the shadow --------------------------------------------------------------------------

## Rig `i`'s red square over world x `x` (its lane's middle), its middle at track distance `at`; `k` (0-1) how far
## its warning has come (it widens a little as it's shown).
func set_square(i: int, x: float, at: float, k: float) -> void:
	var rig: Dictionary = rigs[i]
	if not bool(rig["square_on"]):
		rig["square_t"] = 0.0
	rig["square_on"] = true
	var base := Transform3D(Basis.IDENTITY, Vector3(x, 0.035, TrackGeometry.world_z(at)))
	rig["square_base"] = base
	rig["square_k"] = clampf(k, 0.0, 1.0)
	var square: MeshInstance3D = rig["square"]
	square.visible = true
	_place_square(rig)


func hide_square(i: int) -> void:
	var rig: Dictionary = rigs[i]
	rig["square_on"] = false
	(rig["square"] as Node3D).visible = false


func square_on(i: int) -> bool:
	return bool(rigs[i]["square_on"])


## The square's node (tests: its pulse).
func square_node(i: int) -> MeshInstance3D:
	return rigs[i]["square"]


func _place_square(rig: Dictionary) -> void:
	var t: float = float(rig["square_t"])
	var k: float = float(rig.get("square_k", 1.0))
	# Widening as it's shown; the beat stops with Reduced flashing (BossProps' red lines do the same).
	var grow: float = 0.9 + 0.1 * k
	var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.05 * sin(t * 22.0)
	var base: Transform3D = rig["square_base"]
	(rig["square"] as Node3D).transform = Transform3D(Basis.from_scale(Vector3(grow * beat, 1.0, grow * beat)), base.origin)


## Rig `i`'s screen's shadow on the floor under it, centred at world x `x` and z `z`, `k` (0-1) how near the screen
## has come (it grows and darkens).
func set_shadow(i: int, x: float, z: float, k: float) -> void:
	var rig: Dictionary = rigs[i]
	var shadow: MeshInstance3D = rig["shadow"]
	var c: float = clampf(k, 0.0, 1.0)
	var w: float = (SCREEN_WIDTH + RIM * 2.0) * (0.5 + 0.6 * c)
	var d: float = 0.9 + 0.9 * c
	shadow.global_transform = Transform3D(Basis.from_scale(Vector3(w, 1.0, d)), Vector3(x, 0.03, z))
	(rig["shadow_mat"] as ShaderMaterial).set_shader_parameter(&"darkness", _shadow_alpha * (0.2 + 0.8 * c))
	shadow.visible = true


func hide_shadow(i: int) -> void:
	(rigs[i]["shadow"] as Node3D).visible = false


func shadow_on(i: int) -> bool:
	return (rigs[i]["shadow"] as Node3D).visible


# --- The touch ----------------------------------------------------------------------------------------------

## Rig `i`'s touch over world x [x0, x1] and track distances [from, to], from the floor to screen_hit_height: live
## from now until touch_off.
func set_touch(i: int, x0: float, x1: float, from: float, to: float) -> void:
	var rig: Dictionary = rigs[i]
	var touch: Hazard = rig["touch"]
	var size := Vector3(absf(x1 - x0), tuning.screen_hit_height, absf(to - from))
	GoldenConvergenceFire._resize(touch, size)
	touch.position = Vector3.ZERO
	(rig["holder"] as Node3D).global_position = Vector3((x0 + x1) * 0.5, size.y * 0.5, TrackGeometry.world_z((from + to) * 0.5))
	touch.set_enabled(true)


func touch_off(i: int) -> void:
	var rig: Dictionary = rigs[i]
	(rig["touch"] as Hazard).set_enabled(false)
	(rig["holder"] as Node3D).global_position = Vector3(0.0, -300.0, 0.0)


func touch_on(i: int) -> bool:
	return (rigs[i]["touch"] as Hazard).is_active()


## Every touch hitbox (tests: none is live but at a crash).
func hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for rig: Dictionary in rigs:
		out.append(rig["touch"])
	return out


func _tick(delta: float) -> void:
	for rig: Dictionary in rigs:
		if bool(rig["square_on"]):
			rig["square_t"] = float(rig["square_t"]) + delta
			_place_square(rig)


## Everything back to the pool: nothing shows or touches.
func clear() -> void:
	for i: int in rigs.size():
		release(i)


func _on_contacted(outcome: int, i: int) -> void:
	if outcome == DamageRules.Outcome.IGNORE:
		return
	var p: Player = world.player
	hits.append({"rig": i, "outcome": outcome, "runner": p.distance, "lane": p.lane, "h": p.h})
	hit.emit(i, outcome)


## What it draws (tests: the budget): {instances, surfaces, vertices} of one rig's screen and square.
func draw_stats() -> Dictionary:
	var vertices: int = 0
	var surfaces: int = 0
	for mesh: ArrayMesh in [_screen_mesh, _square_mesh]:
		for s: int in mesh.get_surface_count():
			surfaces += 1
			vertices += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return {"rigs": rigs.size(), "surfaces": surfaces, "vertices": vertices}


## The screen's meshes (tests: the colour rule).
func screen_mesh_now() -> ArrayMesh:
	return _screen_mesh


## Never a target.
func targetable() -> bool:
	return false


## The fight is won: nothing touches any more.
func _on_defeated(_cause: StringName) -> void:
	clear()
