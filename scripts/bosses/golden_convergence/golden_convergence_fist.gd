class_name GoldenConvergenceFist
extends BossPart
## The Fist Slam's touch and its marks on the floor (GDD §10: "A runner under the fist is hit ... The fist
## rises, its shadow grows on the floor, a red square marks where it will land"; task E5d-b). The fist itself
## is the suit's hand on its telescoping arm (GoldenConvergenceSuit.set_arm); GoldenConvergenceSlams drives
## both. A rig per fist (0 the suit's right, on the runner's left; 1 its left), so the two fists' slams may
## overlap, each made with the fight:
## - set_square(i, x0, x1, from, to, k): the red square where that fist will land (a glowing frame in the enemy
##   attacks' red round a faint fill) over world x [x0, x1] and track distances [from, to], deepening as its
##   warning comes on (`k`, 0-1), pulsing as BossProps' red lines do (steady with Reduced flashing);
## - set_shadow(i, x, at, size, k): the fist's shadow on the floor under it, growing and darkening as `k` comes
##   to 1 (a soft dark patch, never glowing);
## - set_touch(i, x0, x1, from, to) and touch_off(i): the touch, an enemy attack hitbox over the hole's
##   footprint from the floor to slam_hit_height (above a jump's reach; across the track the slams keep it clear
##   of a wall runner's body, GoldenConvergenceSlams.touch_x): the armor and the shield block it, the dash passes
##   through, and each contact is reported (`hit`);
## - impact(x0, x1, from, to): the floor bursting round the hole, rubble and dust.
## A part of the boss that's no target and no kill of its own.

## The touch met the runner (`outcome`: a DamageRules.Outcome other than IGNORE).
signal hit(fist: int, outcome: int)

## Rigs: one per fist.
const RIGS: int = 2
## The square's frame is this wide, its fill this see-through.
const FRAME: float = 0.16
const FILL_ALPHA: float = 0.85
## The shadow's darkest (black's alpha) on the marble, and on the Compatibility renderer, which blends in sRGB
## space: the same alpha comes out much darker there (GoldenConvergenceMagnate's shadow's, E5d polish).
const SHADOW_ALPHA: float = 0.62
const SHADOW_ALPHA_COMPAT: float = 0.36
const SHADOW_SHADER: String = "res://scripts/bosses/golden_convergence/golden_convergence_shadow.gdshader"
## The impact's rubble and dust: pale marble, never in a hazard colour.
const RUBBLE := Color(0.82, 0.79, 0.72)
const DUST := Color(0.7, 0.66, 0.6)

var tuning: GoldenConvergenceTuning
## {square: Node3D, frame: Array[MeshInstance3D], fill, shadow, shadow_mat, touch: Hazard, on, t, box: Rect2
## (x0, from, x1 - x0, to - from), k}
var rigs: Array[Dictionary] = []
## Contacts reported (tests): {fist, outcome, runner, lane, h}.
var hits: Array[Dictionary] = []

var _t: float = 0.0
## SHADOW_ALPHA, or SHADOW_ALPHA_COMPAT on the Compatibility renderer.
var _shadow_alpha: float = SHADOW_ALPHA


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as GoldenConvergenceTuning
	if tuning == null:
		tuning = GoldenConvergenceTuning.new()
	display_name = "the golden fist"
	is_obstacle = true
	immune_to_weapons = true
	_shadow_alpha = shadow_alpha_for(RenderingServer.get_current_rendering_method())
	var frame_mat: Material = GreyboxMaterials.glow(BossProps.WARNING_COLOR, 2.6, 0.8)
	var fill_mat: Material = GreyboxMaterials.glow(BossProps.WARNING_COLOR, 1.2, FILL_ALPHA)
	var shader := load(SHADOW_SHADER) as Shader
	for i: int in RIGS:
		var square := Node3D.new()
		square.name = "Square%d" % i
		square.top_level = true
		add_child(square)
		var frame: Array[MeshInstance3D] = []
		for k: int in 4:
			frame.append(_box(square, frame_mat))
		var fill: MeshInstance3D = _box(square, fill_mat)
		var shadow := MeshInstance3D.new()
		shadow.name = "Shadow%d" % i
		var quad := PlaneMesh.new()
		quad.size = Vector2.ONE
		shadow.mesh = quad
		var mat := ShaderMaterial.new()
		# Drawn over the red square's fill (both see-through), so the growing shadow reads inside the square.
		mat.render_priority = 1
		mat.shader = shader
		shadow.material_override = mat
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadow.top_level = true
		shadow.visible = false
		add_child(shadow)
		var holder := Node3D.new()
		holder.name = "Touch%d" % i
		holder.top_level = true
		add_child(holder)
		var touch: Hazard = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, holder)
		touch.hazard_name = "the golden fist"
		touch.contacted.connect(_on_contacted.bind(i))
		touch.set_enabled(false)
		rigs.append({"square": square, "frame": frame, "fill": fill, "shadow": shadow, "shadow_mat": mat,
			"touch": touch, "holder": holder, "on": false, "t": 0.0, "box": Rect2(), "k": 0.0})
		hide_square(i)
		touch_off(i)


func _box(parent: Node3D, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = GreyboxMaterials.unit_box()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


# --- The red square -----------------------------------------------------------------------------------

## The red square of fist `i` over world x [x0, x1] and track distances [from, to]; `k` (0-1): how far its
## warning has come (the frame deepens with it).
func set_square(i: int, x0: float, x1: float, from: float, to: float, k: float) -> void:
	var rig: Dictionary = rigs[i]
	if not bool(rig["on"]):
		rig["t"] = 0.0
	rig["on"] = true
	rig["box"] = Rect2(minf(x0, x1), minf(from, to), absf(x1 - x0), absf(to - from))
	rig["k"] = clampf(k, 0.0, 1.0)
	(rig["square"] as Node3D).visible = true
	_place_square(rig)


func hide_square(i: int) -> void:
	var rig: Dictionary = rigs[i]
	rig["on"] = false
	(rig["square"] as Node3D).visible = false


## True while fist `i`'s red square shows.
func square_on(i: int) -> bool:
	return bool(rigs[i]["on"])


## Where fist `i`'s red square lies: Rect2(x0, from, width, length) (world x, track distance).
func square_box(i: int) -> Rect2:
	return rigs[i]["box"]


func _place_square(rig: Dictionary) -> void:
	var box: Rect2 = rig["box"]
	var t: float = float(rig["t"])
	var k: float = float(rig["k"])
	# Deepening as it's shown; the beat stops with Reduced flashing (BossProps' red lines do the same).
	var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.2 * sin(t * 24.0)
	var w: float = FRAME * (0.8 + 0.6 * k) * beat
	var x0: float = box.position.x
	var x1: float = box.end.x
	var z0: float = TrackGeometry.world_z(box.position.y)
	var z1: float = TrackGeometry.world_z(box.end.y)
	var cx: float = (x0 + x1) * 0.5
	var cz: float = (z0 + z1) * 0.5
	var lx: float = x1 - x0
	var lz: float = absf(z1 - z0)
	var y: float = 0.035
	var frame: Array = rig["frame"]
	(frame[0] as Node3D).transform = Transform3D(Basis.from_scale(Vector3(lx, 0.04, w)), Vector3(cx, y, z0 - w * 0.5))
	(frame[1] as Node3D).transform = Transform3D(Basis.from_scale(Vector3(lx, 0.04, w)), Vector3(cx, y, z1 + w * 0.5))
	(frame[2] as Node3D).transform = Transform3D(Basis.from_scale(Vector3(w, 0.04, lz)), Vector3(x0 + w * 0.5, y, cz))
	(frame[3] as Node3D).transform = Transform3D(Basis.from_scale(Vector3(w, 0.04, lz)), Vector3(x1 - w * 0.5, y, cz))
	(rig["fill"] as Node3D).transform = Transform3D(Basis.from_scale(Vector3(lx - w * 2.0, 0.02, maxf(lz - w * 2.0, 0.05))),
		Vector3(cx, y - 0.01, cz))


# --- The shadow ---------------------------------------------------------------------------------------

## Fist `i`'s shadow on the floor under it: centred at world x `x` and track distance `at`, `size` metres
## across at its fullest, `k` (0-1) how near the fist has come (it grows and darkens).
func set_shadow(i: int, x: float, at: float, size: float, k: float) -> void:
	var rig: Dictionary = rigs[i]
	var shadow: MeshInstance3D = rig["shadow"]
	var c: float = clampf(k, 0.0, 1.0)
	var s: float = size * (0.45 + 0.55 * c)
	shadow.global_transform = Transform3D(Basis.from_scale(Vector3(s, 1.0, s)), Vector3(x, 0.05, TrackGeometry.world_z(at)))
	(rig["shadow_mat"] as ShaderMaterial).set_shader_parameter(&"darkness", _shadow_alpha * (0.25 + 0.75 * c))
	shadow.visible = true


## The shadow's darkest on rendering method `method` (RenderingServer.get_current_rendering_method()).
static func shadow_alpha_for(method: String) -> float:
	return SHADOW_ALPHA_COMPAT if method == "gl_compatibility" else SHADOW_ALPHA


func hide_shadow(i: int) -> void:
	(rigs[i]["shadow"] as Node3D).visible = false


func shadow_on(i: int) -> bool:
	return (rigs[i]["shadow"] as Node3D).visible


# --- The touch ----------------------------------------------------------------------------------------

## Fist `i`'s touch over world x [x0, x1] and track distances [from, to], from the floor up to
## slam_hit_height: live from now (touch_off ends it).
func set_touch(i: int, x0: float, x1: float, from: float, to: float) -> void:
	var rig: Dictionary = rigs[i]
	var touch: Hazard = rig["touch"]
	var size := Vector3(absf(x1 - x0), tuning.slam_hit_height, absf(to - from))
	GoldenConvergenceFire._resize(touch, size)
	touch.position = Vector3.ZERO
	(rig["holder"] as Node3D).global_position = Vector3((x0 + x1) * 0.5, size.y * 0.5, TrackGeometry.world_z((from + to) * 0.5))
	touch.set_enabled(true)


func touch_off(i: int) -> void:
	var rig: Dictionary = rigs[i]
	(rig["touch"] as Hazard).set_enabled(false)
	(rig["holder"] as Node3D).global_position = Vector3(0.0, -300.0, 0.0)


## True while fist `i`'s touch is live.
func touch_on(i: int) -> bool:
	return (rigs[i]["touch"] as Hazard).is_active()


## Fist `i`'s touch hitbox (tests, the slams' hold).
func touch_hazard(i: int) -> Hazard:
	return rigs[i]["touch"]


## Every touch hitbox (tests: none is live but at an impact).
func hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for rig: Dictionary in rigs:
		out.append(rig["touch"])
	return out


# --- The impact ----------------------------------------------------------------------------------------

## The floor bursting round the hole over world x [x0, x1] and track distances [from, to]: rubble flung up
## from its rim, a cloud of marble dust.
func impact(x0: float, x1: float, from: float, to: float) -> void:
	if world == null or world.effects == null:
		return
	var effects: RunEffects = world.effects
	var mid := Vector3((x0 + x1) * 0.5, 0.6, TrackGeometry.world_z((from + to) * 0.5))
	effects.debris(mid + Vector3(0.0, 0.4, 0.0), RUBBLE, 14, 1.4)
	for corner: Vector2 in [Vector2(x0, from), Vector2(x1, from), Vector2(x0, to), Vector2(x1, to)]:
		effects.debris(Vector3(corner.x, 0.3, TrackGeometry.world_z(corner.y)), RUBBLE, 5, 0.9)
	effects.burst(mid, DUST, 30, 1.3)


func _tick(delta: float) -> void:
	_t += delta
	for rig: Dictionary in rigs:
		if bool(rig["on"]):
			rig["t"] = float(rig["t"]) + delta
			_place_square(rig)


## Everything off: no square, no shadow, no touch.
func clear() -> void:
	for i: int in rigs.size():
		hide_square(i)
		hide_shadow(i)
		touch_off(i)


func _on_contacted(outcome: int, i: int) -> void:
	if outcome == DamageRules.Outcome.IGNORE:
		return
	var p: Player = world.player
	hits.append({"fist": i, "outcome": outcome, "runner": p.distance, "lane": p.lane, "h": p.h})
	hit.emit(i, outcome)


## Never a target.
func targetable() -> bool:
	return false


## The fight is won: nothing touches any more.
func _on_defeated(_cause: StringName) -> void:
	clear()
