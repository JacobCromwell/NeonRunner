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
## A theft (GDD §9.12, ScoreKeeper.stolen) sends a stream of coins from the runner to the thief, and a
## caught thief's payout (ScoreKeeper.recovered) bursts out of it into the runner (coin_stream): no
## shake, no hit-stop and no flashing, so it never reads as a hit.
## Every explosion is the same pooled `fireball` (FireballPool; GDD §11, the owner, October 8, 2026): a
## big yellow-and-red ball of fire with embers and smoke, one call that every enemy, boss and weapon makes,
## softened by Reduced flashing.
## All the numbers are SpeedFxTuning's (data/tuning/speed_fx.tres, F6 "Speed effects").

signal shake_requested(strength: float, duration: float)
## An explosion was asked for (`fireball`): where, and how big (metres in radius). Tests and tools listen.
signal fireball_played(pos: Vector3, size: float)

const BURST_POOL: int = 12
const DEBRIS_POOL: int = 8
const LINE_POOL: int = 4
## Coin streams in flight at once (a theft's and a payout's may overlap), and the most coins in one.
const STREAM_POOL: int = 3
const STREAM_COINS: int = 16
## The runner's chest, where a theft's coins leave and a payout's arrive (above the feet).
const CHEST := Vector3(0.0, 0.8, 0.0)
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
var _fireballs: FireballPool
## The highest the player has been above the floor since the last landing (Landings, land_shake).
var _air_peak_h: float = 0.0
## Coin streams (coin_stream), made on first use: {inst: MultiMeshInstance3D, active, t, count, flight,
## spread, arc, from: {node, offset, last}, to: {node, offset, last}}.
var _streams: Array[Dictionary] = []
## The effects' own clock (seconds of _process), and when the last freeze began on it (freeze).
var _clock: float = 0.0
var _freeze_began: float = -INF


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
	_ensure_fireballs()
	world.player.movement_event.connect(_on_player_event)
	world.director.enemy_defeated.connect(_on_enemy_defeated)
	# The score keeper is built after the effects (RunWorld.build): its thefts are wired a moment later,
	# long before the run starts.
	_watch_score.call_deferred()


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


## An explosion at `pos`: a big yellow-and-red fireball, `size` metres in radius (a bomb 1.1, a drone's
## crash 2.4, a truck 3.8, a boss 7 to 11), with embers and, unless `smoke` is off, dark smoke after it.
## `pace` plays it faster (above 1) or slower (a bigger fireball already plays slower); `spread` (0.25 to 1)
## holds its fire and embers in nearer its centre. Pooled and bounded (FireballPool): it allocates nothing,
## and one more than the pool holds cuts the oldest short. It fades out as the camera comes near it (it
## never whites out the view), and Reduced flashing softens its rise and its strength. A look only: no sound
## (the caller's), no shake (the caller's `shake`), no collision.
func fireball(pos: Vector3, size: float = 2.0, smoke: bool = true, pace: float = 1.0, spread: float = 1.0) -> void:
	_ensure_fireballs()
	_fireballs.play(pos, size, smoke, pace, spread)
	fireball_played.emit(pos, size)


## The fireball pool (tests and the shader warm-up).
func fireballs() -> FireballPool:
	_ensure_fireballs()
	return _fireballs


## Builds the pool the first time it's needed: RunWorld.build does it in `setup`, so nothing is built
## mid-run; a bare RunEffects (a tool, a test) builds it on its first fireball.
func _ensure_fireballs() -> void:
	if _fireballs != null:
		return
	if tuning == null:
		tuning = load(DEFAULT_TUNING_PATH) as SpeedFxTuning if ResourceLoader.exists(DEFAULT_TUNING_PATH) else SpeedFxTuning.new()
	_fireballs = FireballPool.new()
	_fireballs.name = "Fireballs"
	add_child(_fireballs)
	_fireballs.setup(tuning)


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


## A stream of `count` coins (at most STREAM_COINS) flying from one end to the other, in the credit
## look of denomination `value` (CreditField's mesh and spinning material): they leave one after
## another over `spread` seconds, and each flies for `flight` seconds, arcing `arc` metres up at its
## middle and fanning out a little sideways. Each end is a node, followed while it moves (its last
## place once it's freed), plus an offset; or a fixed point: a null node, the point as the offset. A
## thief's theft and payout use it (GDD §9.12); so may a thief sucking up credits (task C5). Visual only:
## it never touches the credits themselves. Never flashes.
func coin_stream(from_node: Node3D, from_offset: Vector3, to_node: Node3D, to_offset: Vector3, count: int,
		value: int = 5, flight: float = 0.4, spread: float = 0.45, arc: float = 1.2) -> void:
	count = mini(count, STREAM_COINS)
	if count <= 0:
		return
	var s: Dictionary = _free_stream()
	var inst: MultiMeshInstance3D = s["inst"]
	var look: int = CreditField.denomination(value)
	inst.multimesh.mesh = CreditField.mesh_for(look)
	inst.material_override = CreditField.material_for(look)
	inst.multimesh.visible_instance_count = count
	s["active"] = true
	s["t"] = 0.0
	s["count"] = count
	s["flight"] = maxf(flight, 0.05)
	s["spread"] = maxf(spread, 0.0)
	s["arc"] = arc
	s["from"] = {"node": from_node, "offset": from_offset, "last": from_offset}
	s["to"] = {"node": to_node, "offset": to_offset, "last": to_offset}
	inst.visible = true
	_update_stream(s, 0.0)


## Coins of every stream still in flight (tests and tools).
func coins_in_flight() -> int:
	var n: int = 0
	for s: Dictionary in _streams:
		if s["active"]:
			n += int(s["count"])
	return n


## Asks the camera to shake (hits, explosions, trucks bursting through walls).
func shake(strength: float, duration: float = 0.25) -> void:
	if shake_scale > 0.0:
		shake_requested.emit(strength * shake_scale, duration)


## A brief hit-stop (RunCamera holds its view; see the class doc for why physics and timers never
## feel it). `duration` is real seconds. Freezes never stack or chain (task PERF1): requests in the
## frame a freeze begins keep the longer one, not their sum (a stomp and its kill), and a request less
## than SpeedFxTuning.freeze_gap after a freeze began is left out, so a run of kills (a splash hit,
## auto-fire through a cluster, a dash through a row) never holds the camera again and again.
func freeze(duration: float) -> void:
	if shake_scale <= 0.0 or duration <= 0.0:
		return
	if _clock == _freeze_began:
		freeze_left = maxf(freeze_left, duration)
	elif _clock - _freeze_began >= (tuning.freeze_gap if tuning != null else 0.0):
		_freeze_began = _clock
		freeze_left = duration


func _process(delta: float) -> void:
	_clock += delta
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
	for s: Dictionary in _streams:
		if s["active"]:
			_update_stream(s, delta)


## A stream from the pool: a free one, or the one furthest through its flight.
func _free_stream() -> Dictionary:
	if _streams.is_empty():
		for i: int in STREAM_POOL:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.instance_count = STREAM_COINS
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			inst.top_level = true
			inst.visible = false
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(inst)
			_streams.append({"inst": inst, "active": false, "t": 0.0, "count": 0})
	var best: Dictionary = _streams[0]
	for s: Dictionary in _streams:
		if not s["active"]:
			return s
		if float(s["t"]) > float(best["t"]):
			best = s
	return best


## Moves a stream's coins on by `delta` seconds; it ends once its last coin has landed.
func _update_stream(s: Dictionary, delta: float) -> void:
	s["t"] = float(s["t"]) + delta
	var t: float = s["t"]
	var count: int = s["count"]
	var flight: float = s["flight"]
	var spread: float = s["spread"]
	var inst: MultiMeshInstance3D = s["inst"]
	if t >= spread + flight:
		s["active"] = false
		inst.visible = false
		return
	var a: Vector3 = _end_point(s["from"])
	var b: Vector3 = _end_point(s["to"])
	var side: Vector3 = (b - a).cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), a)
	for i: int in count:
		var start: float = spread * float(i) / float(maxi(count - 1, 1))
		var u: float = (t - start) / flight
		if u <= 0.0 or u >= 1.0:
			inst.multimesh.set_instance_transform(i, hidden)
			continue
		var e: float = u * u * (3.0 - 2.0 * u)
		var lift: float = 4.0 * u * (1.0 - u)
		# Each coin fans out to its own side (a fixed spread per coin, so a stream looks the same every time).
		var fan: float = sin(float(i) * 2.39996) * 0.5
		var pos: Vector3 = a.lerp(b, e) + Vector3.UP * float(s["arc"]) * lift + side * fan * lift
		inst.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))


## Where a stream's end is now: its node's place plus the offset, or its last place once the node is gone.
func _end_point(end: Dictionary) -> Vector3:
	var node: Variant = end["node"]
	if node != null and is_instance_valid(node) and (node as Node3D).is_inside_tree():
		end["last"] = (node as Node3D).global_position + (end["offset"] as Vector3)
	return end["last"]


## The score keeper's thefts (GDD §9.12), once it exists (see setup).
func _watch_score() -> void:
	if world == null or not is_instance_valid(world) or world.score == null:
		return
	if not world.score.stolen.is_connected(_on_stolen):
		world.score.stolen.connect(_on_stolen)
		world.score.recovered.connect(_on_recovered)


## A theft: coins pop out of the runner and stream into the thief as it makes off.
func _on_stolen(amount: int, thief: Node3D) -> void:
	if world == null or world.player == null or not is_instance_valid(thief):
		return
	var from: Vector3 = world.player.global_position + CHEST
	burst(from, CreditField.color_of(5), tuning.theft_spark_amount, 0.3)
	var count: int = _stream_coins(amount)
	coin_stream(world.player, CHEST, thief, _aim_offset(thief), count, amount / maxi(count, 1),
		tuning.coin_stream_flight, tuning.coin_stream_spread, tuning.coin_stream_arc)


## A caught thief's payout: what it held and its jackpot burst out of it into the runner.
func _on_recovered(amount: int, jackpot: int, thief: Node3D) -> void:
	if world == null or world.player == null or not is_instance_valid(thief):
		return
	var at: Vector3 = thief.global_position + _aim_offset(thief)
	burst(at, CreditField.color_of(25), tuning.theft_spark_amount * 2, 0.6)
	var count: int = _stream_coins(amount + jackpot)
	coin_stream(null, at, world.player, CHEST, count, (amount + jackpot) / maxi(count, 1),
		tuning.coin_stream_flight, tuning.coin_stream_spread, tuning.coin_stream_arc)


## Coins in a stream for `credits` credits: one per coin_stream_credits_per_coin, at least 4.
func _stream_coins(credits: int) -> int:
	if credits <= 0:
		return 0
	return clampi(ceili(float(credits) / float(maxi(tuning.coin_stream_credits_per_coin, 1))), 4, STREAM_COINS)


## Where a thief's coins aim, from its origin: an enemy's aim point.
static func _aim_offset(thief: Node3D) -> Vector3:
	var enemy := thief as Enemy
	return enemy.aim_point() - enemy.global_position if enemy != null else Vector3.ZERO


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
		&"doodad_push":
			shake(tuning.push_shake_strength, tuning.push_shake_time)


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
