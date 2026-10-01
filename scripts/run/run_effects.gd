class_name RunEffects
extends Node3D
## Shared, pooled visual effects for a run: particle bursts (hits, explosions, pickups), chunky
## debris, short glowing lines (grapple rope, beams), camera-shake requests and hit-stop. CPU
## particles only, so it works on the Compatibility renderer. Effects never affect gameplay. Screen
## shake respects the player's accessibility setting through `shake_scale` (0 = off), which also
## scales hit-stop.
##
## `setup()` (called once by RunWorld.build) also plays the shared "impact" spectacle the owner's
## playtest asked for (GDD §3, September 30, 2026): a spark burst and a small shake on a landing
## from a real drop, a stomp (plus a brief hit-stop), every enemy kill however it dies (a smaller,
## consistent shake and hit-stop, so a bigger cause-specific shake an enemy or a power-up plays of
## its own is never drowned out: shake() and freeze() both keep the stronger of two overlapping
## requests), and a spark burst in the item's own colour when the armor or the shield blocks a hit.
## All the numbers are SpeedFxTuning's (data/tuning/speed_fx.tres, F6 "Speed effects").

signal shake_requested(strength: float, duration: float)

const BURST_POOL: int = 12
const DEBRIS_POOL: int = 8
const LINE_POOL: int = 4
## Fallback if RunWorld.build is given no SpeedFxTuning (tests that build a bare RunEffects).
const DEFAULT_TUNING_PATH: String = "res://data/tuning/speed_fx.tres"

## Multiplies every shake and hit-stop request (Settings sets it; 0 turns Screen shake off).
var shake_scale: float = 1.0
## Hit-stop: RunCamera holds its view while this counts down (real seconds, decremented in
## `_process`). Never touches Engine.time_scale (SlowTimePowerup owns that for its own, very
## different, deliberate slow-down), so physics, timers and the generator tick on underneath and a
## seeded run plays out identically whichever way this fires (tested: test_speed_fx).
var freeze_left: float = 0.0

var world: RunWorld
var tuning: SpeedFxTuning

var _bursts: Array[CPUParticles3D] = []
var _next_burst: int = 0
var _debris: Array[CPUParticles3D] = []
var _next_debris: int = 0
var _debris_mesh: BoxMesh
var _lines: Array[MeshInstance3D] = []
var _line_life: Array[float] = []
var _mesh: SphereMesh
## The highest the player has been above the floor since the last landing (Landings, land_shake).
var _air_peak_h: float = 0.0


func _ready() -> void:
	_mesh = SphereMesh.new()
	_mesh.radius = 0.06
	_mesh.height = 0.12
	_mesh.radial_segments = 6
	_mesh.rings = 3
	for i: int in BURST_POOL:
		_bursts.append(_make_particles(_mesh, 0.45))
	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3.ONE * 0.1
	for i: int in DEBRIS_POOL:
		var p: CPUParticles3D = _make_particles(_debris_mesh, 0.7)
		p.spread = 60.0
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		_debris.append(p)
	for i: int in LINE_POOL:
		var line := MeshInstance3D.new()
		line.mesh = GreyboxMaterials.unit_box()
		line.visible = false
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		_lines.append(line)
		_line_life.append(0.0)


func _make_particles(mesh: Mesh, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = lifetime
	p.mesh = mesh
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.local_coords = false
	add_child(p)
	return p


## Wires the shared impact spectacle to the run's own events (RunWorld.build). `p_tuning` defaults
## to data/tuning/speed_fx.tres when null (RunWorld always passes its own; tests may skip this).
func setup(p_world: RunWorld, p_tuning: SpeedFxTuning = null) -> void:
	world = p_world
	tuning = p_tuning
	if tuning == null:
		tuning = load(DEFAULT_TUNING_PATH) as SpeedFxTuning if ResourceLoader.exists(DEFAULT_TUNING_PATH) else SpeedFxTuning.new()
	world.player.movement_event.connect(_on_player_event)
	world.director.enemy_defeated.connect(_on_enemy_defeated)


## A burst of glowing particles at `pos`. `size` scales the spread and speed (1 = explosion).
func burst(pos: Vector3, color: Color, amount: int = 16, size: float = 0.5) -> void:
	if _bursts.is_empty():
		return
	var p: CPUParticles3D = _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % _bursts.size()
	p.global_position = pos
	p.amount = clampi(amount, 2, 64)
	p.initial_velocity_min = 2.0 * size + 1.0
	p.initial_velocity_max = 7.0 * size + 2.0
	p.material_override = GreyboxMaterials.glow(color, 3.0)
	p.restart()
	p.emitting = true


## A burst of tumbling glowing chunks at `pos` (alongside `burst`'s sparks, on kills and blocked
## hits): fewer, slower and heavier than sparks, so it reads as debris rather than more sparks.
func debris(pos: Vector3, color: Color, amount: int = 6, size: float = 0.6) -> void:
	if _debris.is_empty():
		return
	var p: CPUParticles3D = _debris[_next_debris]
	_next_debris = (_next_debris + 1) % _debris.size()
	p.global_position = pos
	p.amount = clampi(amount, 2, 32)
	p.initial_velocity_min = 1.2 * size + 0.5
	p.initial_velocity_max = 3.5 * size + 1.0
	p.material_override = GreyboxMaterials.glow(color, 1.8)
	p.restart()
	p.emitting = true


## A glowing straight line from `a` to `b` that fades after `duration` (the grapple rope).
func line(a: Vector3, b: Vector3, color: Color, duration: float = 0.3, thickness: float = 0.05) -> void:
	for i: int in _lines.size():
		if _line_life[i] > 0.0:
			continue
		var l: MeshInstance3D = _lines[i]
		var mid: Vector3 = (a + b) * 0.5
		var length: float = a.distance_to(b)
		l.global_position = mid
		if length > 0.001:
			var dir: Vector3 = (b - a) / length
			var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			l.basis = Basis.looking_at(dir, up).scaled(Vector3(thickness, thickness, length))
		l.material_override = GreyboxMaterials.glow(color, 3.0)
		l.visible = true
		_line_life[i] = duration
		return


## Asks the camera to shake (hits, explosions, trucks bursting through walls).
func shake(strength: float, duration: float = 0.25) -> void:
	if shake_scale > 0.0:
		shake_requested.emit(strength * shake_scale, duration)


## A brief hit-stop (RunCamera holds its view; see the class doc for why physics and timers never
## feel it). `duration` is real seconds; overlapping requests keep the longer one, not their sum, so
## a burst of kills at once (a splash hit, a dash through a cluster) never stacks into a long stall.
func freeze(duration: float) -> void:
	if shake_scale > 0.0:
		freeze_left = maxf(freeze_left, duration)


func _process(delta: float) -> void:
	if freeze_left > 0.0:
		freeze_left = maxf(freeze_left - delta, 0.0)
	if world != null and world.player != null:
		var h: float = world.player.h
		if h > _air_peak_h:
			_air_peak_h = h
	for i: int in _lines.size():
		if _line_life[i] > 0.0:
			_line_life[i] -= delta
			if _line_life[i] <= 0.0:
				_lines[i].visible = false


func _on_player_event(kind: StringName) -> void:
	match kind:
		&"stomp":
			shake(tuning.stomp_shake_strength, tuning.stomp_shake_time)
			freeze(tuning.stomp_freeze_time)
		&"land":
			if _air_peak_h >= tuning.land_shake_fall_height:
				shake(tuning.land_shake_strength, tuning.land_shake_time)
			_air_peak_h = 0.0
		&"armor_hit":
			_block_fx(PlayerSuit.GLOW, tuning.block_shake_strength)
		&"armor_break":
			_block_fx(PlayerSuit.GLOW, tuning.block_break_shake_strength)
		&"shield_break":
			_block_fx(PlayerSuit.SHIELD, tuning.block_break_shake_strength)


func _block_fx(color: Color, shake_strength: float) -> void:
	var at: Vector3 = world.player.global_position + Vector3(0.0, 1.0, 0.0)
	burst(at, color, tuning.block_spark_amount, 0.45)
	shake(shake_strength, tuning.block_shake_time)


## Every enemy kill, whatever the cause (EnemyDirector.enemy_defeated): called while `enemy` is
## still valid (Enemy.defeat emits before it frees), so its own point still reads correctly.
func _on_enemy_defeated(enemy: Enemy, _cause: StringName) -> void:
	if not is_instance_valid(enemy):
		return
	var at: Vector3 = enemy.aim_point()
	burst(at, Color(1.0, 0.96, 0.88), tuning.kill_spark_amount, 0.4)
	debris(enemy.global_position + Vector3(0.0, 0.3, 0.0), Color(0.55, 0.52, 0.5), tuning.kill_debris_amount, 0.5)
	shake(tuning.kill_shake_strength, tuning.kill_shake_time)
	freeze(tuning.kill_freeze_time)
