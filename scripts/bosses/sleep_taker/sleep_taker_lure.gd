class_name SleepTakerLure
extends Node3D
## The way to hurt the Sleep Taker (GDD §10: "glowing fence generators stand along the route. The player
## lures it close (it lunges toward them), then destroys the generator with a stomp or the dash; the EMP
## rips a chunk of the nightmare away"; "a missed generator is followed by another"):
## - a generator (FenceGenerator: the Dead Zone's last working machines; a stomp or the dash destroys it,
##   weapons never set it off, GDD §9.1) comes into sight far ahead (place(): generator_sight ahead, in a
##   lane whose floor is clear around it, away from the refuges' slashes and from ceilings), glowing: a
##   tall beacon of its pink light rising from it and a halo on the street around it, drawn without the
##   scene's light, so it reads from afar and in the dark of lights out;
## - the lure: lure_seconds before the runner reaches it, the nightmare lunges toward them (its hungry
##   roar, sleep_taker_lure), arms reaching and maws gaping, and holds close in front of them (its claws
##   lure_gap away) until they're past the generator. It doesn't attack while lured;
## - close enough: while the generator is within emp_reach of the nightmare (in_reach()), pink arcs
##   crackle from its coils into the nightmare (sleep_taker_crackle): smash it now, and its EMP tears a
##   chunk away (SleepTaker._on_part_emp). With Reduced flashing the arcs hold still;
## - missed (the runner passes it), it pulls back to hover, and the encounter brings another
##   generator_again later. Nothing changes with the misses (GDD §10: no escalation).
## Numbers: SleepTakerTuning ("Generators and the lure"), all DESIGN-TBD (docs/questions/e5c.md).

enum Stage { IDLE, WAITING, LUNGE, HOLD, RELEASE }

## The beacon's height and width, and the halo's size on the street (metres).
const BEACON_HEIGHT: float = 42.0
const BEACON_WIDTH: float = 1.8
const HALO_SIZE: float = 5.0
## Where the arcs leave the generator (its coils' top) and how many there are.
const ARC_FROM := Vector3(0.0, 1.0, 0.0)
const ARC_COUNT: int = 3
const ARC_SEGMENTS: int = 12
## The arcs' jags change this often (none with Reduced flashing: they hold their shape).
const ARC_FLICKER: float = 0.07
## Where the arcs reach into the nightmare (model space: its belly and waist, below its great maw).
const ARC_TARGETS: Array[Vector3] = [Vector3(-1.6, 4.4, 1.8), Vector3(0.0, 3.4, 2.0), Vector3(1.6, 4.4, 1.8)]
const PINK := Color(1.0, 0.3, 0.75)
const ARC_CORE := Color(1.0, 0.85, 0.97)
const SCRIPT_PATH: String = "res://scripts/bosses/sleep_taker/sleep_taker_lure.gd"
const BEACON_SHADER: String = "res://scripts/bosses/sleep_taker/sleep_taker_beacon.gdshader"

var boss: SleepTaker
var stage: Stage = Stage.IDLE
var stage_time: float = 0.0
## The generator in play now (null when none): its spot {at (track distance), lane}.
var generator: FenceGenerator
var site: Dictionary = {}
## Generators placed, lures started, arcs shown, and what became of each: for tests and tuning.
var count: int = 0
var lures: int = 0
var smashed: int = 0
var missed: int = 0
## True while the arcs show (the generator is in reach of the nightmare).
var arcs_on: bool = false

var _pull: float = 0.0
var _pull_from: float = 0.0
var _beacon: MeshInstance3D
var _halo: MeshInstance3D
var _arcs: MeshInstance3D
var _arc_mesh: ImmediateMesh
var _arc_rng := RandomNumberGenerator.new()
var _arc_jags: Array[PackedVector3Array] = []
var _arc_clock: float = 0.0


func setup(p_boss: SleepTaker) -> void:
	boss = p_boss
	name = "Lure"
	top_level = true
	_arc_rng.seed = hash(["sleep_taker_arcs", boss.rng.seed])
	_beacon = MeshInstance3D.new()
	_beacon.name = "Beacon"
	var quad := QuadMesh.new()
	quad.size = Vector2(BEACON_WIDTH, BEACON_HEIGHT)
	quad.center_offset = Vector3(0.0, BEACON_HEIGHT * 0.5, 0.0)
	_beacon.mesh = quad
	_beacon.material_override = beacon_material()
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.extra_cull_margin = BEACON_HEIGHT
	_beacon.visible = false
	add_child(_beacon)
	_halo = MeshInstance3D.new()
	_halo.name = "Halo"
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALO_SIZE, HALO_SIZE)
	_halo.mesh = plane
	_halo.material_override = halo_material()
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.visible = false
	add_child(_halo)
	_arc_mesh = ImmediateMesh.new()
	_arcs = MeshInstance3D.new()
	_arcs.name = "Arcs"
	_arcs.mesh = _arc_mesh
	_arcs.material_override = arc_material()
	_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arcs.extra_cull_margin = 30.0
	_arcs.visible = false
	add_child(_arcs)


# --- State ------------------------------------------------------------------------------------------

## True while a generator is in play (placed, luring, or the nightmare still pulling back).
func busy() -> bool:
	return stage != Stage.IDLE


## True while the nightmare is lured in (lunging in or held close): it doesn't attack meanwhile.
func luring() -> bool:
	return stage == Stage.LUNGE or stage == Stage.HOLD


## How far it's drawn in toward the runner now (0 = hovering, 1 = held close), eased.
func pull() -> float:
	return _pull


## Where it holds while lured: its claws lure_gap in front of the runner (metres ahead of them).
func lure_ahead() -> float:
	return boss.tuning.lure_gap + boss.body.claw_reach()


## The track distance where the lure starts for the generator at `at`: lure_seconds before the runner
## reaches it, at `v` m/s.
func lure_at(at: float, v: float) -> float:
	return at - v * boss.tuning.lure_seconds


## True if the generator in play is alive and within emp_reach of the nightmare (along the street):
## its EMP would tear a chunk away now.
func in_reach() -> bool:
	if generator == null or not is_instance_valid(generator) or not generator.alive:
		return false
	return reaches(generator.global_position)


## True if an EMP at `center` reaches the nightmare (within emp_reach of its middle, along the street).
func reaches(center: Vector3) -> bool:
	var body: SleepTakerBody = boss.body
	if body == null or not is_instance_valid(body):
		return false
	return absf(body.global_position.z - center.z) <= boss.tuning.emp_reach


# --- Placing a generator ------------------------------------------------------------------------

## Puts a generator in sight ahead where it fits fairly (see find_spot()); false if there's no spot now.
func place() -> bool:
	if busy():
		return false
	var spot: Dictionary = find_spot()
	if spot.is_empty():
		return false
	var enemy: Enemy = boss.spawn_enemy("generator", float(spot["at"]), int(spot["lane"]))
	generator = enemy as FenceGenerator
	if generator == null:
		if enemy != null:
			enemy.retire()
		return false
	site = spot
	count += 1
	generator.defeated.connect(_on_generator_defeated)
	var pos: Vector3 = boss.world.lane_point(int(spot["lane"]), float(spot["at"]))
	_beacon.global_position = pos
	_halo.global_position = pos + Vector3(0.0, 0.03, 0.0)
	_beacon.visible = true
	_halo.visible = true
	_set_stage(Stage.WAITING)
	boss.log_event(&"generator", {"n": count, "lane": spot["lane"], "at": spot["at"], "d": boss.player_distance()})
	return true


## The first fair spot for a generator from generator_sight ahead: {at, lane}, or {} for none within a
## stretch past it. Its lane (the runner's, else the nearest) has its floor clear of holes and fences
## generator_clear_before it to generator_clear_after past it, no pad or ramp there and no pickup on
## it; the lure's stretch is clear of ceilings (the runner on the street the whole way) and of every
## refuge's slash, with an attack gap's room on either side.
func find_spot() -> Dictionary:
	var t: SleepTakerTuning = boss.tuning
	var k: float = boss.run_pace()
	var v: float = boss.speed()
	var d: float = boss.player_distance()
	var n: int = boss.lane_count()
	var lanes: Array[int] = []
	var home: int = boss.player_lane()
	for dist: int in n:
		for s: int in ([0] if dist == 0 else [-1, 1]):
			var l: int = home + s * dist
			if l >= 0 and l < n:
				lanes.append(l)
	var from: float = d + t.generator_sight * k
	var step: float = 3.0 * k
	var at: float = from
	while at <= from + 160.0 * k:
		if _stretch_fair(at, v, k):
			for lane: int in lanes:
				if _lane_fair(lane, at, k):
					return {"at": at, "lane": lane}
		at += step
	return {}


## The lure's stretch around a generator at `at`: no ceiling, and no refuge's slash (from an attack gap
## before its warning to an attack gap after its claws pull back).
func _stretch_fair(at: float, v: float, k: float) -> bool:
	var t: SleepTakerTuning = boss.tuning
	var from: float = lure_at(at, v) - v * t.attack_gap
	var to: float = at + t.lure_release * k + v * (t.lure_back_seconds + t.attack_gap)
	if boss.ceiling_between(from, to):
		return false
	for r: Dictionary in boss.refuges_between(from - 200.0 * k, to + 200.0 * k):
		var warn: float = boss.refuge_warn_at(float(r["pad"]))
		var r_from: float = warn - v * t.attack_gap
		var r_to: float = float(r["pad"]) + v * (t.strike_after_pad + t.slash_active + t.slash_recover + t.attack_gap)
		if r_from <= to and r_to >= from:
			return false
	return true


func _lane_fair(lane: int, at: float, k: float) -> bool:
	var t: SleepTakerTuning = boss.tuning
	var from: float = at - t.generator_clear_before * k
	var to: float = at + t.generator_clear_after * k
	if not boss.floor_clear_lane(lane, from, to) or boss.pickup_near(lane, at, 4.0):
		return false
	var layout: LevelLayout = boss.arena.layout if boss.arena != null else null
	if layout == null:
		return true
	for list: Array in [layout.pads, layout.ramps]:
		for p: Dictionary in list:
			var p_at: float = float(p.get("at", p.get("start", 0.0)))
			if int(p.get("lane", -1)) == lane and p_at >= from and p_at <= to:
				return false
	return true


# --- Each frame ---------------------------------------------------------------------------------

func tick(delta: float) -> void:
	_arc_clock += delta
	if stage == Stage.IDLE:
		_update_arcs(false)
		return
	var t: SleepTakerTuning = boss.tuning
	stage_time += delta
	var d: float = boss.player_distance()
	var v: float = boss.speed()
	var at: float = float(site.get("at", d))
	match stage:
		Stage.WAITING:
			if generator == null or not is_instance_valid(generator):
				_end()
			elif not generator.alive:
				_release(&"smashed_early")
			elif d >= lure_at(at, v) and boss.state == BossEncounter.State.FIGHT:
				_set_stage(Stage.LUNGE)
				_pull_from = _pull
				lures += 1
				boss.sound(&"sleep_taker_lure", boss.body.mouth_world())
				boss.log_event(&"lure", {"n": count, "at": at, "lane": site["lane"], "d": d})
		Stage.LUNGE:
			var k: float = clampf(stage_time / maxf(t.lure_lunge_seconds, 0.01), 0.0, 1.0)
			_pull = lerpf(_pull_from, 1.0, 1.0 - pow(1.0 - k, 2.0))
			if k >= 1.0:
				_set_stage(Stage.HOLD)
			_check_passed(d, at)
		Stage.HOLD:
			_pull = 1.0
			_check_passed(d, at)
		Stage.RELEASE:
			var k: float = clampf(stage_time / maxf(t.lure_back_seconds, 0.01), 0.0, 1.0)
			_pull = _pull_from * (1.0 - smoothstep(0.0, 1.0, k))
			if k >= 1.0:
				_end()
	_set_body()
	_update_arcs(luring() and in_reach())


## Past the generator by lure_release without smashing it: a miss; it pulls back.
func _check_passed(d: float, at: float) -> void:
	if generator == null or not is_instance_valid(generator):
		_release(&"gone")
	elif d >= at + boss.tuning.lure_release * boss.run_pace():
		_release(&"missed")


func _release(why: StringName) -> void:
	if why == &"missed" or why == &"smashed_early" or why == &"gone":
		missed += 1
		boss.log_event(&"lure_missed", {"n": count, "why": why})
	_pull_from = _pull
	_set_stage(Stage.RELEASE)


## Stops it at once (a phase change, the defeat): the nightmare is let go, the beacon and the arcs go
## out. A generator still standing stays, dark (a missed one), and is no longer the lure's.
func clear() -> void:
	_pull = 0.0
	_pull_from = 0.0
	_end()
	_set_body()


## Lets go of the generator: no beacon, no halo, no arcs.
func _end() -> void:
	if generator != null and is_instance_valid(generator) and generator.defeated.is_connected(_on_generator_defeated):
		generator.defeated.disconnect(_on_generator_defeated)
	generator = null
	site = {}
	_beacon.visible = false
	_halo.visible = false
	_update_arcs(false)
	_set_stage(Stage.IDLE)


## The generator was destroyed (a stomp or the dash): its EMP follows at once (SleepTaker._on_part_emp
## decides whether it reached the nightmare); the beacon goes out with it.
func _on_generator_defeated(_enemy: Enemy, cause: StringName) -> void:
	smashed += 1
	_beacon.visible = false
	_halo.visible = false
	boss.log_event(&"generator_smashed", {"n": count, "cause": cause, "in_reach": in_reach_of(generator),
		"d": boss.player_distance()})


## True if the nightmare is within reach of `enemy`'s spot (in_reach() for a generator just destroyed).
func in_reach_of(enemy: Enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and reaches(enemy.global_position)


## Lured, it reaches for the runner: arms up and out, every maw gaping hungrily (never the attack's red).
func _set_body() -> void:
	var body: SleepTakerBody = boss.body
	if body == null or not is_instance_valid(body) or boss.slash.busy():
		return
	body.raise = 0.55 * _pull
	body.reach = 1.0 + 0.3 * _pull
	if not boss.dark.warning_on():
		body.inhale = 0.4 * _pull


func _set_stage(next: Stage) -> void:
	stage = next
	stage_time = 0.0


# --- The arcs -------------------------------------------------------------------------------------

## Draws the arcs from the generator's coils into the nightmare while `on` (re-rolling their jags every
## ARC_FLICKER, or never with Reduced flashing), and plays the crackle as they appear.
func _update_arcs(on: bool) -> void:
	if on and not arcs_on:
		boss.sound(&"sleep_taker_crackle", generator.global_position + ARC_FROM)
		boss.log_event(&"in_reach", {"n": count, "d": boss.player_distance()})
		_roll_jags()
	arcs_on = on
	_arcs.visible = on
	if not on:
		return
	if not Settings.flashing_reduced and _arc_clock >= ARC_FLICKER:
		_arc_clock = 0.0
		_roll_jags()
	_draw_arcs()


func _roll_jags() -> void:
	_arc_jags.clear()
	for i: int in ARC_COUNT:
		var jags := PackedVector3Array()
		for s: int in ARC_SEGMENTS + 1:
			var edge: float = 0.0 if s == 0 or s == ARC_SEGMENTS else 1.0
			jags.append(Vector3(_arc_rng.randf_range(-1.0, 1.0), _arc_rng.randf_range(-1.0, 1.0),
				_arc_rng.randf_range(-1.0, 1.0)) * edge)
		_arc_jags.append(jags)


func _draw_arcs() -> void:
	_arc_mesh.clear_surfaces()
	if generator == null or not is_instance_valid(generator) or _arc_jags.size() < ARC_COUNT:
		return
	var from: Vector3 = generator.global_position + ARC_FROM
	var model: Node3D = boss.body.model
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in ARC_COUNT:
		var to: Vector3 = model.global_transform * ARC_TARGETS[i]
		var span: float = from.distance_to(to)
		var points := PackedVector3Array()
		for s: int in ARC_SEGMENTS + 1:
			var f: float = float(s) / ARC_SEGMENTS
			var sag: float = sin(f * PI) * span * 0.08
			points.append(from.lerp(to, f) + Vector3(0.0, sag, 0.0) + _arc_jags[i][s] * span * 0.035)
		for s: int in ARC_SEGMENTS:
			_ribbon(points[s], points[s + 1], 0.09 if i == 1 else 0.065)
	_arc_mesh.surface_end()


## One segment of an arc: two crossed strips (so it shows from any side), each a hot core line down
## its middle fading out to pink at its edges.
func _ribbon(a: Vector3, b: Vector3, half: float) -> void:
	var dir: Vector3 = (b - a).normalized()
	var side: Vector3 = dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up: Vector3 = side.cross(dir).normalized()
	var edge := Color(PINK, 0.0)
	for across: Vector3 in [side, up]:
		for sgn: float in [-1.0, 1.0]:
			var o: Vector3 = across * half * sgn
			for pair: Array in [[a, ARC_CORE], [a + o, edge], [b + o, edge], [a, ARC_CORE], [b + o, edge], [b, ARC_CORE]]:
				_arc_mesh.surface_set_color(pair[1])
				_arc_mesh.surface_add_vertex(pair[0])


# --- Materials ------------------------------------------------------------------------------------

## The beacon: a soft column of the generator's pink rising from it, facing the camera about its upright
## axis, drawn without the scene's light or its fog so it reads from afar and in the dark.
static func beacon_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(BEACON_SHADER) as Shader
	m.set_shader_parameter(&"color", PINK)
	return m


## The halo on the street around a generator: a soft pink glow, unshaded.
static func halo_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	m.albedo_color = Color(PINK, 0.55)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	m.albedo_texture = texture
	return m


## The arcs: additive, unshaded, coloured per vertex (white-hot core, pink edges).
static func arc_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	return m
