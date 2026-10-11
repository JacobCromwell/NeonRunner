class_name MechaGuppyWaves
extends Node3D
## The waves of phase 3 (GDD §10: "there will be some waves that crash over the lanes that the player has to jump over";
## the warning, the owner's (October 10, 2026): "a rising swell and a roar", jumped "like the Resonator's ring", §9.10;
## task E5e-c). MechaGuppyTop starts each wave on its beat:
## - start(): the warning. A swell rises out of the sea beside the top on the side away from Captain Cogs' ship (WAVE_SIDE),
##   ahead of the runner where it will crash: a curling wall of water whose crest comes up past the deck's edge over
##   wave_warning, with its roar (wave_swell, as long as wave_warning, swelling to the crash);
## - wave_warning later it crashes over every lane wave_ahead ahead of the runner (wave_crash: its lip falls across the
##   deck in a burst of foam), and its surge rushes along the deck at them, closing in at wave_close: a low band across
##   every lane, wave_height tall and wave_depth deep (the Resonator's: a normal jump clears it), its hitbox an enemy
##   attack (real contact only; armor and the shield block it, the dash passes through it). Its look is a little bigger
##   than its hitbox (GDD §3): water foaming over, with the red line of the hazard low on its face (the Resonator's red
##   ring, the cross-zone sign of a low band to jump; the water itself never glows), a wash of water behind it;
## - past the runner it rushes on behind them and is gone.
## A wave's time from its warning to the runner never changes with the run's speed (wave_close, wave_ahead: it keeps pace
## with them, as the Resonator's waves close in at the same speed at any pace). Its own clock runs on the boss's ticks
## (time from the physics step; it waits while the runner is down). Nothing flickers: the water's streaks run, and stand
## still with Reduced flashing. DESIGN-TBD (docs/questions/e5e.md): the waves' look and numbers.

const SHADER_PATH: String = "res://scripts/bosses/mecha_guppy/mecha_guppy_wave.gdshader"
const WAVE_NAME: String = "wave"
## The side of the top the swells rise on (+1 the right: Captain Cogs' ship comes level on the left).
const WAVE_SIDE: int = 1
## The swell: its length along the track, how deep below the deck it starts rising from, and its crash: how long it takes
## to come down across the deck's edge (its lip falling over the outer lane as it collapses into the sea), how far it
## moves in and drops, and how flat it gets.
const SWELL_LENGTH: float = 24.0
const SWELL_RISE: float = 30.0
const CRASH_SECONDS: float = 0.4
const CRASH_IN: float = 2.0
const CRASH_DROP: float = 14.0
const CRASH_FLAT: float = 0.45
## The swell's profile up its face, across from the deck's edge (+x out to sea) and up from the deck: its foot far below,
## its crest well above the deck, its lip curling over the outer lane.
const PROFILE: Array[Vector2] = [Vector2(16.0, -38.0), Vector2(10.0, -21.0), Vector2(5.0, -8.0), Vector2(2.6, 0.0),
	Vector2(1.8, 3.8), Vector2(0.7, 7.0), Vector2(-1.2, 7.6), Vector2(-2.7, 6.0)]
## The surge's look over its hitbox (the Resonator's scales: GDD §3, hitboxes smaller than visuals), and its wash behind.
const CREST_HEIGHT_SCALE: float = 1.35
const CREST_DEPTH_SCALE: float = 1.4
const WASH_LENGTH: float = 3.5
## A wave is past the runner once its back is this far behind their hurtbox (metres); it's gone this long after (seconds).
const PAST_MARGIN: float = 0.3
const GONE_AFTER: float = 0.6
## The streaks' speed (cycles a second).
const FLOW_SPEED: float = 0.6
## The crash's foam.
const FOAM_COLOR := Color(0.93, 0.95, 0.93)

enum State { SWELL, ROLL, DONE }

var boss: MechaGuppy
var world: RunWorld
var tuning: MechaGuppyTuning
## Seconds of waves so far (its waves keep to this clock).
var clock: float = 0.0
## Waves started over the fight (tests).
var started: int = 0
## The waves under way: {k (its beat), start, crash, pass (clock: when its surge reaches the runner), d0, d_crash, d_pass,
## y (the deck), speed (the surge's along the track toward the runner), swell (MeshInstance3D), band (MeshInstance3D),
## hazard (Hazard), state}.
var waves: Array[Dictionary] = []

var _material: ShaderMaterial
var _swell_mesh: ArrayMesh
var _band_mesh: ArrayMesh
var _band_key: Vector2 = Vector2.ZERO
var _flow: float = 0.0


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	tuning = boss.tuning
	top_level = true
	transform = Transform3D.IDENTITY
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH) as Shader
	var beach := world.skin as BeachSkin
	if beach != null:
		_material.set_shader_parameter(&"deep_color", beach.sea_deep_color)
		_material.set_shader_parameter(&"water_color", beach.sea_mid_color)
		_material.set_shader_parameter(&"shallow_color", beach.sea_shallow_color)
		_material.set_shader_parameter(&"foam_color", beach.foam_color)
	_material.set_shader_parameter(&"hazard_color", BossProps.WARNING_COLOR)
	_swell_mesh = swell_mesh()


## Everything gone: the swells, the surges and their hitboxes (the fight is won).
func clear() -> void:
	for w: Dictionary in waves:
		_end(w)
	waves.clear()


## One physics step (MechaGuppy's ticks drive it).
func tick(delta: float) -> void:
	clock += delta
	if not Settings.flashing_reduced:
		_flow += delta * FLOW_SPEED
		_material.set_shader_parameter(&"flow", _flow)
	for i: int in range(waves.size() - 1, -1, -1):
		var w: Dictionary = waves[i]
		_advance(w)
		if int(w["state"]) == State.DONE:
			waves.remove_at(i)


## A wave's times for a runner at `speed` (m/s), from its warning: {crash, pass} (seconds after the warning starts) and
## how far ahead of the runner (at the warning) it crashes and reaches them (metres along the track).
func timing(speed: float) -> Dictionary:
	var v: float = maxf(speed, 1.0)
	var crash: float = tuning.wave_warning
	var pass_t: float = crash + tuning.wave_ahead / maxf(tuning.wave_close, 1.0)
	return {"crash": crash, "pass": pass_t, "crash_ahead": v * crash + tuning.wave_ahead, "pass_ahead": v * pass_t}


## Starts wave `k`: its warning begins now (see the header). Returns its record.
func start(k: int) -> Dictionary:
	var p: Player = world.player
	var v: float = maxf(p.speed, 1.0)
	var t: Dictionary = timing(v)
	var d0: float = p.distance
	var w: Dictionary = {"k": k, "start": clock, "crash": clock + float(t["crash"]), "pass": clock + float(t["pass"]),
		"d0": d0, "d_crash": d0 + float(t["crash_ahead"]), "d_pass": d0 + float(t["pass_ahead"]), "y": p.floor_base,
		"speed": maxf(tuning.wave_close - v, 0.5), "state": State.SWELL}
	var swell := MeshInstance3D.new()
	swell.name = "Swell"
	swell.mesh = _swell_mesh
	swell.material_override = _material
	swell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(swell)
	w["swell"] = swell
	_place_swell(w)
	waves.append(w)
	started += 1
	boss.sound(&"wave_swell", _swell_point(w))
	boss.log_event(&"wave", {"k": k, "d0": d0, "warning": float(t["pass"]), "d_crash": float(w["d_crash"]),
		"d_pass": float(w["d_pass"])})
	return w


## The live surges' hitboxes (tests).
func band_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for w: Dictionary in waves:
		var h: Hazard = w.get("hazard")
		if h != null and h.is_active():
			out.append(h)
	return out


## The surges rushing at the runner (the bot): [{d (where the surge's front is now), speed (along the track toward the
## runner), y}], nearest first.
func surges() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in waves:
		if int(w["state"]) == State.ROLL and not w.has("passed"):
			out.append({"d": surge_d(w, clock) - tuning.wave_depth * 0.5, "speed": float(w["speed"]), "y": float(w["y"])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	return out


## True while a swell is rising (a wave's warning is on: the bot, tests).
func swelling() -> bool:
	for w: Dictionary in waves:
		if int(w["state"]) == State.SWELL:
			return true
	return false


## Where wave `w`'s surge (its middle) is along the track at clock `at` once it has crashed.
static func surge_d(w: Dictionary, at: float) -> float:
	return float(w["d_crash"]) - float(w["speed"]) * maxf(at - float(w["crash"]), 0.0)


func _advance(w: Dictionary) -> void:
	match int(w["state"]):
		State.SWELL:
			_place_swell(w)
			if clock >= float(w["crash"]) - 0.0001:
				_crash(w)
		State.ROLL:
			var swell: MeshInstance3D = w["swell"]
			if swell != null and is_instance_valid(swell):
				var k: float = (clock - float(w["crash"])) / CRASH_SECONDS
				if k >= 1.0:
					swell.queue_free()
					w["swell"] = null
				else:
					_place_swell(w, k)
			var d: float = surge_d(w, clock)
			var band: MeshInstance3D = w["band"]
			band.global_position = Vector3(0.0, float(w["y"]), TrackGeometry.world_z(d))
			var hazard: Hazard = w["hazard"]
			hazard.global_position = Vector3(0.0, float(w["y"]) + tuning.wave_height * 0.5, TrackGeometry.world_z(d))
			var p: Player = world.player
			var past: float = p.distance - world.tuning.hurtbox_size.z * 0.5 - tuning.wave_depth * 0.5 - PAST_MARGIN
			if d < past:
				hazard.set_enabled(false)
				if not w.has("passed"):
					w["passed"] = clock
					boss.log_event(&"wave_passed", {"k": int(w["k"])})
				if clock - float(w["passed"]) >= GONE_AFTER:
					_end(w)


## The crash: the swell's lip falls across the deck in a burst of foam, and the surge forms there across every lane.
func _crash(w: Dictionary) -> void:
	w["state"] = State.ROLL
	var d: float = float(w["d_crash"])
	var y: float = float(w["y"])
	var half: float = world.geo.wall_x()
	var band := MeshInstance3D.new()
	band.name = "Surge"
	band.mesh = _band(half)
	band.material_override = _material
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)
	band.global_position = Vector3(0.0, y, TrackGeometry.world_z(d))
	w["band"] = band
	var hazard := Hazard.new()
	hazard.name = "SurgeHit"
	hazard.hazard_name = WAVE_NAME
	hazard.is_enemy_attack = true
	hazard.part = &"attack"
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.collision_mask = 0
	hazard.monitoring = false
	var size := Vector3(world.geo.half_width() * 2.0 - 0.1, tuning.wave_height, tuning.wave_depth)
	hazard.size = size
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	hazard.add_child(shape)
	add_child(hazard)
	hazard.global_position = Vector3(0.0, y + size.y * 0.5, TrackGeometry.world_z(d))
	hazard.set_enabled(true)
	w["hazard"] = hazard
	for i: int in 6:
		var x: float = lerpf(-half, half, float(i) / 5.0)
		world.effects.burst(Vector3(x, y + 1.2, TrackGeometry.world_z(d)), FOAM_COLOR, 18, 1.4)
	world.effects.burst(Vector3(float(WAVE_SIDE) * (half + 2.0), y + 3.0, TrackGeometry.world_z(d)), FOAM_COLOR, 28, 2.2)
	var near: float = clampf(1.0 - absf(d - world.player.distance) / 40.0, 0.2, 1.0)
	world.effects.shake(0.18 * near, 0.3)
	boss.sound(&"wave_crash", Vector3(0.0, y + 1.0, TrackGeometry.world_z(d)))
	boss.log_event(&"wave_crash", {"k": int(w["k"]), "d": d})


## Wave `w`'s look and hitbox gone.
func _end(w: Dictionary) -> void:
	w["state"] = State.DONE
	for key: String in ["swell", "band", "hazard"]:
		var node: Node = w.get(key)
		if node != null and is_instance_valid(node):
			if node is Hazard:
				(node as Hazard).set_enabled(false)
			node.queue_free()
		w[key] = null


## The swell beside the top at wave `w`'s crash line: rising up out of the sea over its warning (eased), then, `crash`
## (0 to 1) of the way through its crash, its lip tipping over across the deck as it falls.
func _place_swell(w: Dictionary, crash: float = -1.0) -> void:
	var swell: MeshInstance3D = w["swell"]
	if swell == null or not is_instance_valid(swell):
		return
	var side: float = float(WAVE_SIDE)
	var edge: float = side * world.geo.wall_x()
	var y: float = float(w["y"])
	var z: float = TrackGeometry.world_z(float(w["d_crash"]))
	var basis := Basis.from_scale(Vector3(side, 1.0, 1.0))
	if crash < 0.0:
		var k: float = clampf((clock - float(w["start"])) / maxf(float(w["crash"]) - float(w["start"]), 0.01), 0.0, 1.0)
		var e: float = 1.0 - (1.0 - k) * (1.0 - k)
		swell.global_transform = Transform3D(basis, Vector3(edge, y - SWELL_RISE * (1.0 - e), z))
		return
	# Coming down: in over the deck's edge, its lip falling across the outer lane, collapsing and dropping back into the sea
	# (the deck hides what passes under it).
	var c: float = clampf(crash, 0.0, 1.0)
	var squash := Basis.from_scale(Vector3(1.0, lerpf(1.0, CRASH_FLAT, c), 1.0))
	swell.global_transform = Transform3D(basis * squash, Vector3(edge - side * CRASH_IN * c, y - CRASH_DROP * c * c, z))


## Where the swell's roar is heard: its crest.
func _swell_point(w: Dictionary) -> Vector3:
	return Vector3(float(WAVE_SIDE) * (world.geo.wall_x() + 2.0), float(w["y"]) + 2.0,
		TrackGeometry.world_z(float(w["d_crash"])))


# --- The meshes ---------------------------------------------------------------------------------

## The swell (UV2.x 0: mecha_guppy_wave.gdshader): a curling wall of water SWELL_LENGTH long along the track, its profile
## (PROFILE) highest in its middle and lower toward its ends, which bend out to sea. Local space: x out to sea from the
## deck's edge, y up from the deck, z along the track (its middle at 0).
static func swell_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: int = 12
	var rows: int = PROFILE.size()
	var grid: Array[PackedVector3Array] = []
	var uvs: Array[PackedVector2Array] = []
	for i: int in cols + 1:
		var u: float = float(i) / float(cols)
		var bulge: float = sin(u * PI)
		var height: float = lerpf(0.55, 1.0, bulge)
		var out: float = (1.0 - bulge) * 3.0
		var col := PackedVector3Array()
		var col_uv := PackedVector2Array()
		for j: int in rows:
			var p: Vector2 = PROFILE[j]
			var y: float = p.y * height if p.y > 0.0 else p.y
			col.append(Vector3(p.x + out, y, (u - 0.5) * SWELL_LENGTH))
			col_uv.append(Vector2(u, float(j) / float(rows - 1)))
		grid.append(col)
		uvs.append(col_uv)
	for i: int in cols:
		for j: int in rows - 1:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i][j + 1]
			var ua: Vector2 = uvs[i][j]
			var ub: Vector2 = uvs[i + 1][j]
			var uc: Vector2 = uvs[i + 1][j + 1]
			var ud: Vector2 = uvs[i][j + 1]
			for tri: Array in [[a, ua, b, ub, c, uc], [a, ua, c, uc, d, ud]]:
				for n: int in 3:
					st.set_uv(tri[n * 2 + 1])
					st.set_uv2(Vector2(0.0, 0.0))
					st.add_vertex(tri[n * 2])
	return st.commit()


## The surge across the deck (2 × `half` wide): the crest (UV2.x 1), a low arch CREST_HEIGHT_SCALE × wave_height high and
## CREST_DEPTH_SCALE × wave_depth deep over its hitbox, its front facing the runner (+z), and its wash behind it (UV2.x
## 2), a sheet on the deck WASH_LENGTH long. Local space: x across, y up from the deck, z along the track (+z toward the
## runner; its middle at 0). Cached for the current half width and tuning.
func _band(half: float) -> ArrayMesh:
	var key := Vector2(half, tuning.wave_height * 100.0 + tuning.wave_depth)
	if _band_mesh != null and _band_key == key:
		return _band_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = tuning.wave_height * CREST_HEIGHT_SCALE
	var d: float = tuning.wave_depth * CREST_DEPTH_SCALE
	var steps: int = 8
	var arch := PackedVector3Array()
	for j: int in steps + 1:
		var v: float = float(j) / float(steps)
		var a: float = v * PI
		# Front foot (+z) to back foot (-z), a little steeper in front (the face the runner sees).
		arch.append(Vector3(0.0, sin(a) * h * (1.0 + 0.15 * sin(a * 2.0)), cos(a) * d * 0.5))
	var xs: int = 8
	for i: int in xs:
		var x0: float = lerpf(-half, half, float(i) / float(xs))
		var x1: float = lerpf(-half, half, float(i + 1) / float(xs))
		var u0: float = float(i) / float(xs)
		var u1: float = float(i + 1) / float(xs)
		for j: int in steps:
			var v0: float = float(j) / float(steps)
			var v1: float = float(j + 1) / float(steps)
			var p0: Vector3 = arch[j]
			var p1: Vector3 = arch[j + 1]
			_quad(st, Vector3(x0, p0.y, p0.z), Vector3(x1, p0.y, p0.z), Vector3(x1, p1.y, p1.z), Vector3(x0, p1.y, p1.z),
				Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1), 1.0)
		# The wash behind it, just over the deck.
		var z0: float = -d * 0.5
		var z1: float = z0 - WASH_LENGTH
		_quad(st, Vector3(x0, 0.03, z0), Vector3(x1, 0.03, z0), Vector3(x1, 0.03, z1), Vector3(x0, 0.03, z1),
			Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0), 2.0)
	_band_mesh = st.commit()
	_band_key = key
	return _band_mesh


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2,
		ud: Vector2, kind: float) -> void:
	for pair: Array in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
		st.set_uv(pair[1])
		st.set_uv2(Vector2(kind, 0.0))
		st.add_vertex(pair[0])
