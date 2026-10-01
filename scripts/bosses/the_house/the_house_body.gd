class_name TheHouseBody
extends BossPart
## The House's body (GDD §10), the fight's one part: the machine (TheHouseModel), built to the street's
## width. The encounter (TheHouse) moves it (pose(): how far ahead its face is and how low it sags) and
## sets what it's doing (its reels, its lever, its lights, its hopper); this draws it, easing each toward
## its target.
## Declared, never special-cased (CLAUDE.md principle 8), so the shared rules apply as to any enemy:
## - a boss's body (BossPart): weapon hits go to the fight (up to its BossDef.weapon_share_cap: GDD §10,
##   "weapons chip away at it"), claws never defeat it, the dash passes through it;
## - its weak point is the coin hopper on its top (add_weak_point): a box over the whole hopper, across
##   the street from wall to wall, stomp_depth long at the run's pace (TheHouseTuning), from a little under
##   its top deck to stomp_top above it: a runner coming down onto it stomps it ("stomps do the real
##   damage"). The encounter switches it on only while the hopper is burst open at the jackpot;
## - its cabinet is solid (a body hitbox the size of the machine: running into it is deadly) while it
##   stands; at the jackpot, sunk into the street, its top deck is a floor the runner can run onto
##   (add_surface) and the cabinet's hitbox is off (set_sunk), like the pinned Floating Head's hull.
## Its attacks' hitboxes are the encounter's own (TheHouseAttacks: enemy attacks and solid blocks).

## How fast its look eases toward what the encounter asks (per second, exponential).
const EASE: float = 9.0

var tuning: TheHouseTuning
var model: TheHouseModel
var reels := TheHouseReels.new()
## How far ahead of the runner its face is drawn (metres along the track) is the encounter's: it sets
## position directly (set_pose). How low it sags (0 standing, 1 sunk so its top is deck_height up).
var sag: float = 0.0
## What the encounter asks: the lever (0 up, 1 pulled), the lights (0-1), the jackpot's celebration (0-1),
## the hopper (0 shut, 1 burst open) and the power (0 at its defeat).
var lever: float = 0.0
var lights: float = 1.0
var jackpot: float = 0.0
var hopper: float = 0.0
var power: float = 1.0
## Its speed along the track (m/s), for the treads.
var track_speed: float = 0.0

var _core: Hazard
var _hopper: Hazard
var _deck: StaticBody3D
var _shape: TheHouseModel.Shape
var _sunk: bool = false
var _scroll: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as TheHouseTuning
	if tuning == null:
		tuning = TheHouseTuning.new()
	# GDD §9: big attacks take turns (EnemyDirector.major_attack_blocked): other enemies hold theirs while
	# one of its attacks warns or strikes.
	exclusive_major_attack = true
	_shape = TheHouseModel.shape_for(world.geo.wall_x() * 2.0, tuning, hopper_length(world.tuning, tuning))
	model = TheHouseModel.new()
	model.name = "Model"
	add_child(model)
	model.build(_shape)
	var s: TheHouseModel.Shape = _shape
	_core = add_hitbox(&"body", Vector3(s.width - 0.2, s.height, s.depth),
		Vector3(0.0, s.height * 0.5, -s.depth * 0.5), false)
	_core.hazard_name = display_name
	# The hopper: across the street (a wall jump onto it counts too), the hopper's length, from a little under
	# the deck to stomp_top over it.
	var under: float = 0.25
	_hopper = add_weak_point(Vector3(world.geo.wall_x() * 2.0, under + tuning.stomp_top, s.hopper_front - s.hopper_back),
		Vector3(0.0, s.height + (tuning.stomp_top - under) * 0.5, (s.hopper_front + s.hopper_back) * 0.5))
	_hopper.hazard_name = "%s's hopper" % display_name
	_deck = add_surface(Vector3(s.width, 0.3, s.depth + TheHouseModel.FACE_Z),
		Vector3(0.0, s.height - 0.15, (TheHouseModel.FACE_Z - s.depth) * 0.5))
	set_weak_points_enabled(false)
	set_sunk(false)


## The stomp box's length along the track: stomp_depth at 18 m/s, at the run's pace (a jump covers more
## track at speed, so the box keeps its window in seconds).
static func hopper_length(movement: MovementTuning, t: TheHouseTuning) -> float:
	return t.stomp_depth * (movement.pace() if movement != null else 1.0)


func shape() -> TheHouseModel.Shape:
	return _shape


## Puts it on the street with its front at track distance `front_at`, sunk by its sag.
func set_pose(front_at: float) -> void:
	position = Vector3(0.0, -sag * (_shape.height - tuning.deck_height), TrackGeometry.world_z(front_at))


## Sunk at the jackpot: its cabinet's hitbox off and its top deck a floor (on: the runner may run onto
## it); standing: the cabinet solid again and the deck out of the way.
func set_sunk(on: bool) -> void:
	_sunk = on
	_core.set_enabled(not on)
	_deck.collision_layer = TrackBuilder.LAYER_FLOOR if on else 0


func is_sunk() -> bool:
	return _sunk


## The hopper's stomp box (its weak point).
func hopper_hitbox() -> Hazard:
	return _hopper


func core_hitbox() -> Hazard:
	return _core


## The track distances the hopper's stomp box covers when its face is at `front_at`.
func hopper_span(front_at: float) -> Vector2:
	return Vector2(front_at - _shape.hopper_front, front_at - _shape.hopper_back)


## The track distance of its back end when its face is at `front_at`.
func back_at(front_at: float) -> float:
	return front_at + _shape.depth


## Its top's height above the street now.
func top_height() -> float:
	return position.y + _shape.height


## The middle of its reels in world space (its spin's sounds come from there).
func reels_world() -> Vector3:
	return global_transform * _shape.reels_middle()


## Its coin chute (the cherry bombs and the gold blocks are flung from there).
func chute_world() -> Vector3:
	return global_transform * Vector3(0.0, TheHouseModel.TRAY_Y.y + 0.4, TheHouseModel.FACE_Z + 0.6)


## The hopper's middle on its top (the fountain bursts from there).
func hopper_world() -> Vector3:
	return global_transform * Vector3(0.0, _shape.height + 0.2, (_shape.hopper_front + _shape.hopper_back) * 0.5)


## Weapons aim at its reels while it stands, at its hopper once it's sunk.
func aim_point() -> Vector3:
	if _sunk or sag > 0.5:
		return global_transform * Vector3(0.0, _shape.height + 0.6, _shape.hopper_front - 1.0)
	return reels_world() + Vector3(0.0, 0.0, 0.4)


func hit_radius() -> float:
	return clampf(_shape.reel_height * 0.7, 1.5, 3.0)


## Its attacks are on while the encounter says one warns or strikes.
func is_major_attack_active() -> bool:
	var boss := encounter as TheHouse
	return alive and boss != null and boss.attack_on()


## Mesh instances, surfaces and vertices drawn now (the draw budget).
func draw_stats() -> Dictionary:
	return model.draw_stats() if model != null else {}


## Beaten, it keeps drawing itself while the encounter plays its defeat (Enemy stops ticking a defeated
## enemy).
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not alive and world != null:
		_animate(delta)


func _tick(delta: float) -> void:
	_animate(delta)


## The fight is won: the encounter plays the defeat, so the body stays (its hitboxes are already off).
func _on_defeated(_cause: StringName) -> void:
	pass


func _animate(delta: float) -> void:
	if model == null:
		return
	reels.tick(delta)
	var k: float = 1.0 - exp(-EASE * delta)
	model.reel_angles = reels.angles()
	model.reel_blur = reels.blur()
	model.reel_locked = reels.lock_glow()
	model.lever = lerpf(model.lever, lever, 1.0 - exp(-18.0 * delta))
	model.lights = lerpf(model.lights, lights, k)
	model.jackpot = lerpf(model.jackpot, jackpot, k)
	model.hopper_open = lerpf(model.hopper_open, hopper, 1.0 - exp(-14.0 * delta))
	model.power = lerpf(model.power, power, 1.0 - exp(-3.0 * delta))
	_scroll += track_speed * delta
	model.tread_scroll = _scroll
	model.animate()
