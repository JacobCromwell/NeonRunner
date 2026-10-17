class_name MarketPeople
extends RefCounted
## What every Marketplace citizen shares (GDD §5, "Citizens"; task L7): the one baked person (assets/models/market_person.res),
## the one material every crowd draws it with (market_person.gdshader), the palettes it is dressed from, and the crowd's clock.
## MarketCrowd (one per wall section, a MultiMesh of the people standing in its windows) calls tick() each frame; the first
## to do so in a frame advances the clock and sets the material's one uniform, so the CPU's whole cost of every citizen on
## screen is that: no per-person posing. A cheer is one more uniform, set when it begins.
##
## What cheers them (the numbers are MarketPeopleTuning's): a credit pickup worth `cheer_credit_min_value` or more (the run's
## CreditField.collected) and the defeat of a big enemy (EnemyDirector.enemy_defeated, the types in `cheer_enemy_types`,
## the player's own kills only), both heard from the skin's side: the first crowd to tick in a run finds its RunWorld and
## connects once. The House's own calls (react(&"cheer") and react(&"startled") on the "market_citizens" group, every crowd
## being in it) come through MarketCrowd.react(). No sound: the people only move.
## Only people within `cheer_ahead` of the runner and `cheer_behind` behind them take part (those in view), the cheer
## rippling out from the runner.

const MESH_PATH: String = "res://assets/models/market_person.res"
const SHADER_PATH: String = "res://scripts/world/skins/marketplace/market_person.gdshader"
## The group every crowd joins (The House calls react() on it: D3's hook, kept).
const GROUP: StringName = &"market_citizens"
const CHEER: StringName = &"cheer"
const STARTLED: StringName = &"startled"

## The palettes (sRGB, as the shader takes them; sizes pinned by the shader's arrays and test_marketplace_citizens): plain
## people in plain clothes. Clothes are muted, never a hazard's hue and never bright (test: saturation and value held), skin
## and hair are natural tones; nothing glows. A person's skin, hair, shirt, trousers and shoes are picked from them by hash.
const SKINS: PackedColorArray = [
	Color(0.80, 0.62, 0.50), Color(0.70, 0.52, 0.40), Color(0.58, 0.41, 0.31), Color(0.46, 0.32, 0.24),
	Color(0.86, 0.70, 0.58), Color(0.36, 0.25, 0.19)]
const HAIRS: PackedColorArray = [
	Color(0.10, 0.08, 0.07), Color(0.24, 0.17, 0.12), Color(0.40, 0.29, 0.19), Color(0.56, 0.55, 0.57),
	Color(0.16, 0.14, 0.15)]
const SHIRTS: PackedColorArray = [
	Color(0.30, 0.38, 0.52), Color(0.30, 0.46, 0.47), Color(0.52, 0.40, 0.50), Color(0.62, 0.70, 0.76),
	Color(0.46, 0.52, 0.42), Color(0.64, 0.64, 0.58), Color(0.30, 0.31, 0.36), Color(0.82, 0.82, 0.80)]
const PANTS: PackedColorArray = [
	Color(0.28, 0.32, 0.42), Color(0.46, 0.42, 0.36), Color(0.22, 0.22, 0.26), Color(0.34, 0.40, 0.50),
	Color(0.54, 0.50, 0.42), Color(0.36, 0.31, 0.29)]
const SHOES: PackedColorArray = [Color(0.12, 0.11, 0.11), Color(0.28, 0.20, 0.15), Color(0.34, 0.34, 0.36)]

const NO_EVENT := Vector4(-1000.0, 0.0, 0.0, 0.0)
## What the shader does to a person (market_person.gdshader's constants; posed() and reaction() mirror its vertex function):
## the arms' swing in a cheer and in a flinch (radians), the crouch (the share of their height lost), the head's tip.
const ARMS_CHEER: float = 2.65
const ARMS_FLINCH: float = 2.35
const CROUCH: float = 0.26
const TIP: float = 0.25

static var _mesh: ArrayMesh
static var _material: ShaderMaterial
static var _tuning: MarketPeopleTuning

# The clock and what the crowd has been told.
static var _clock: float = 0.0
static var _tick_frame: int = -1
static var _runner := Vector3.ZERO
static var _runner_override: Variant = null
static var _world: WeakRef
static var _event_start: float = -1000.0
static var _event_kind: StringName = &""
static var _event_frame: int = -1
## The shader's two event slots (u_event and the one before it, u_event_prev): (clock at the start, the runner's world z, kind).
static var _event := NO_EVENT
static var _event_prev := NO_EVENT


## The baked person (null until `tools/godot.sh citizens` has baked it: the skin then builds no citizens, rather than crash).
static func mesh() -> ArrayMesh:
	if _mesh == null and ResourceLoader.exists(MESH_PATH):
		_mesh = load(MESH_PATH) as ArrayMesh
	return _mesh


## The baked person's own height (metres, the mesh's meta), what a person's scale is taken from.
static func stature() -> float:
	var person: ArrayMesh = mesh()
	if person == null:
		return 1.25
	return float((person.get_meta(&"pivots", {}) as Dictionary).get(&"height", 1.25))


static func tuning() -> MarketPeopleTuning:
	if _tuning == null:
		_tuning = MarketPeopleTuning.load_default()
	return _tuning


## The one material every crowd draws with, made on first use (null with no mesh).
static func material() -> ShaderMaterial:
	if _material != null:
		return _material
	var person: ArrayMesh = mesh()
	if person == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH) as Shader
	var pivots: Dictionary = person.get_meta(&"pivots", {})
	m.set_shader_parameter(&"u_neck", pivots.get(&"neck", Vector3(0.0, 1.11, 0.0)))
	m.set_shader_parameter(&"u_shoulder_l", pivots.get(&"shoulder_l", Vector3(-0.165, 1.015, 0.0)))
	m.set_shader_parameter(&"u_shoulder_r", pivots.get(&"shoulder_r", Vector3(0.165, 1.015, 0.0)))
	m.set_shader_parameter(&"skins", SKINS)
	m.set_shader_parameter(&"hairs", HAIRS)
	m.set_shader_parameter(&"shirts", SHIRTS)
	m.set_shader_parameter(&"pants", PANTS)
	m.set_shader_parameter(&"shoes", SHOES)
	var t: MarketPeopleTuning = tuning()
	m.set_shader_parameter(&"u_cheer", Vector4(t.cheer_seconds, t.cheer_hop, t.cheer_ahead, t.cheer_behind))
	m.set_shader_parameter(&"u_motion", Vector4(t.ripple, t.jitter, t.look_near, t.look_far))
	m.set_shader_parameter(&"u_limits", Vector4(deg_to_rad(t.look_limit), deg_to_rad(t.sway), t.startle_seconds, 0.0))
	_material = m
	return m


# --- The clock --------------------------------------------------------------------------------------------------------

## Called by a crowd as it enters the tree (MarketCrowd._ready): finds its run, if it is in one, so that a crowd outside any
## run (the warm-up's sample) never drives a frame before the run's own crowds have ticked.
static func attach(crowd: Node) -> void:
	_find_world(crowd)


## Called by every crowd each frame (MarketCrowd._process): the first one of a frame advances the clock by `delta` and sets
## the material's uniform to the clock and the runner's place; the others do nothing. A crowd outside every run lets one of
## the run's own drive while a run is on; with no run at all (the Marketplace intro's street) it drives, and the heads face forward.
static func tick(from: Node, delta: float) -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _tick_frame:
		return
	var world: RunWorld = _find_world(from)
	if world == null and _world != null and _world.get_ref() != null:
		return  # A run is on and this crowd is not in it (the warm-up's sample): a crowd of the run drives the frame.
	_tick_frame = frame
	_clock += delta
	var watching: bool = false
	if world != null and world.player != null:
		_runner = world.player.global_position
		watching = true
	elif _runner_override != null:
		_runner = _runner_override
		watching = true
	var m: ShaderMaterial = material()
	if m != null:
		# With no runner to watch (a crowd outside any run: the Marketplace intro's street) the heads face forward.
		m.set_shader_parameter(&"u_state", Vector4(_clock, _runner.x, _runner.z, 1.0 if watching else 0.0))


## Where the people look, with no run to ask (reviews and tests): the runner's world position. A run's player always wins.
static func set_runner(world_position: Vector3) -> void:
	_runner_override = world_position
	_runner = world_position


static func clock() -> float:
	return _clock


## Forgets the run it was listening to and any cheer under way (a new run, and tests).
static func reset() -> void:
	_world = null
	_event_start = -1000.0
	_event_kind = &""
	_event_frame = -1
	_runner_override = null
	_set_events(NO_EVENT, NO_EVENT)


# --- What cheers them -------------------------------------------------------------------------------------------------

## Starts a cheer (&"cheer": one hop, both arms up) or a flinch (&"startled": a crouch, arms up and out) now, for the people
## near the runner. A cheer within `cheer_cooldown` of the last is let go by; any repeat in the same frame (every crowd of
## the group is asked at once) is one.
static func react(kind: StringName) -> void:
	var m: ShaderMaterial = material()
	if m == null:
		return
	var frame: int = Engine.get_process_frames()
	if frame == _event_frame and kind == _event_kind:
		return
	if kind == CHEER and _event_kind == CHEER and _clock - _event_start < tuning().cheer_cooldown:
		return
	_event_frame = frame
	_event_kind = kind
	_event_start = _clock
	# The reaction under way stays in the second slot while this one eases in, so the two blend.
	_set_events(Vector4(_clock, _runner.z, 1.0 if kind == STARTLED else 0.0, 0.0), _event)


static func _set_events(current: Vector4, previous: Vector4) -> void:
	_event = current
	_event_prev = previous
	if _material != null:
		_material.set_shader_parameter(&"u_event", current)
		_material.set_shader_parameter(&"u_event_prev", previous)


## The two event slots as the shader has them, newest first: for tests.
static func events() -> Array[Vector4]:
	return [_event, _event_prev] as Array[Vector4]


## Seconds since the last cheer or flinch began (a long time if none has): for tests.
static func since_event() -> float:
	return _clock - _event_start


## The run's world, found from a crowd in it, with its signals heard once.
static func _find_world(from: Node) -> RunWorld:
	if _world != null:
		var known: Object = _world.get_ref()
		if known != null and (known as Node).is_ancestor_of(from):
			return known as RunWorld
	var n: Node = from.get_parent()
	while n != null and not (n is RunWorld):
		n = n.get_parent()
	if n == null:
		return null
	var world := n as RunWorld
	_world = weakref(world)
	_event_start = -1000.0
	_event_kind = &""
	_set_events(NO_EVENT, NO_EVENT)
	if world.credits != null and not world.credits.collected.is_connected(_on_credit):
		world.credits.collected.connect(_on_credit)
	if world.director != null and not world.director.enemy_defeated.is_connected(_on_enemy_defeated):
		world.director.enemy_defeated.connect(_on_enemy_defeated)
	return world


static func _on_credit(value: int, _position: Vector3) -> void:
	if value >= tuning().cheer_credit_min_value:
		react(CHEER)


## The player's own defeat of a big enemy (the score's rule: another enemy's charge flattening it earns nothing, but the
## Enforcer Truck, which only baiting a charge destroys, is the player's).
static func _on_enemy_defeated(enemy: Enemy, cause: StringName) -> void:
	if cause == Enemy.CHARGE_DAMAGE_CAUSE and not enemy.charge_bait:
		return
	if tuning().cheer_enemy_types.has(String(enemy.type_id)):
		react(CHEER)


# --- The shader's pose, mirrored ---------------------------------------------------------------------------------------

## How far through the reaction `ev` (an event slot) the person standing at world z `z` is, with their own lateness `late`
## (0-1), at clock `t`, as (arms thrown up 0-1 in a cheer, hop 0-1, flinch 0-1): a GDScript mirror of market_person.gdshader's
## reaction(), change both together. Every amount is 0 where the reaction begins and ends.
static func reaction(ev: Vector4, z: float, late: float, t: float) -> Vector3:
	var tune: MarketPeopleTuning = tuning()
	var dz: float = z - ev.y
	if dz < -tune.cheer_ahead or dz > tune.cheer_behind:
		return Vector3.ZERO
	var is_flinch: bool = ev.z > 0.5
	var k: float = (t - ev.x - absf(dz) * tune.ripple - late * tune.jitter) / (tune.startle_seconds if is_flinch else tune.cheer_seconds)
	if k < 0.0 or k > 1.0:
		return Vector3.ZERO
	var arms_up: float = smoothstep(0.0, 0.22, k) * (1.0 - smoothstep(0.72, 1.0, k))
	var hk: float = clampf((k - 0.08) / 0.72, 0.0, 1.0)
	var bump: float = sin(PI * k)
	if is_flinch:
		return Vector3(0.0, 0.0, bump)
	return Vector3(arms_up, 4.0 * hk * (1.0 - hk), 0.0)


## A vertex `p` of the baked person as the shader poses it, a GDScript mirror of market_person.gdshader's vertex() in the
## person's own space, change both together: `moves` its part (0 body, 1 head, 2 left arm, 3 right arm), `r` the reactions'
## amounts (reaction(), the two slots added and held to 1), `turn` the head's turn about the neck (radians), `breath` and
## `sway` the ease's, `hop` the hop's height in the mesh's own metres, `pivots` the mesh's meta. The head and the arms turn
## about their pivots first, the crouch and the sway scale and lean the whole body after, so an arm's root goes down and
## sways with the shoulder it hangs from.
static func posed(p: Vector3, moves: int, r: Vector3, turn: float, breath: float, sway: float, hop: float,
		pivots: Dictionary) -> Vector3:
	var flinch: float = minf(r.z, 1.0)
	var arms: float = minf(minf(r.x, 1.0) * ARMS_CHEER + flinch * ARMS_FLINCH, ARMS_CHEER)
	if moves == 1:
		var neck: Vector3 = pivots[&"neck"]
		var d: Vector3 = p - neck
		var xz: Vector2 = Vector2(d.x, d.z).rotated(-turn)
		var yz: Vector2 = Vector2(d.y, xz.y).rotated(flinch * TIP)
		p = neck + Vector3(xz.x, yz.x, yz.y)
	elif moves >= 2:
		var right: bool = moves == 3
		var sh: Vector3 = pivots[&"shoulder_r"] if right else pivots[&"shoulder_l"]
		var d: Vector3 = p - sh
		var xy: Vector2 = Vector2(d.x, d.y).rotated(arms * (1.0 if right else -1.0))
		p = sh + Vector3(xy.x, xy.y, d.z)
	p.y *= (1.0 + breath) * (1.0 - CROUCH * flinch)
	p.x += p.y * sway
	p.y += minf(r.y, 1.0) * hop
	return p
