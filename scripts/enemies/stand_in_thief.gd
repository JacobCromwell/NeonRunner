class_name StandInThief
extends Enemy
## A stand-in thief for tests and review (task B6; never in the campaign: no level or pattern names it):
## a plain gold block that crosses the lanes ahead of the runner while the runner closes in. It carries
## the whole theft contract that the Tithe Collector (GDD §9.12, task C5) builds its own look and
## behaviour on:
## - its hitbox declares the theft (Hazard.steals_share, from its ThiefTuning): a touch robs
##   (DamageRules.Outcome.ROBBED) instead of hurting, and it makes off ahead and up, out of reach, with
##   what it took (Hazard.contacted tells it);
## - catching it pays back everything it holds plus its jackpot (Enemy.jackpot_credits; ScoreKeeper): a
##   stomp (dropping onto it), a shot, the dash or the claws, any defeat;
## - one that gets away keeps what it took.
## One hitbox covers the block, as its stomp part (&"top"): dropped onto from above it's a stomp, any
## other touch robs. It plans its crossing so that it's over the lane it aims at (the spawn's "lane": the
## runner's lane as it appears) when the runner reaches it, so a runner who keeps to that lane is robbed
## and one who moves aside or jumps it isn't. Numbers: data/enemies/stand_in_thief.tres
## (StandInThiefTuning). Quick play's --thief (debug builds) sends one after another (start_review).

const TYPE: String = "stand_in_thief"
## Plain polished gold, unlit: it never glows, so it never takes a hazard's glowing colours.
const GOLD := Color(1.0, 0.74, 0.28)
## Once the runner is this far past it (it was dodged or jumped), it's gone (metres).
const PASSED_BEHIND: float = 8.0

enum State { APPROACH, FLEE }

var state: State = State.APPROACH
var tune: StandInThiefTuning
## Where it is, relative to the runner: metres ahead, its world x, and its underside's height.
var rel_ahead: float = 0.0
var x: float = 0.0
var y: float = 0.0
## Its one hitbox (the theft, and the stomp from above).
var box: Hazard

## The crossing: a distance along the side-to-side path between the outer lanes' middles, folded back
## and forth (_sweep_x), from the leftmost lane's middle `_x_min` over `_span` metres.
var _sweep: float = 0.0
var _x_min: float = 0.0
var _span: float = 0.0
var _model: MeshInstance3D
static var _material: StandardMaterial3D


func _build() -> void:
	tune = tuning_res as StandInThiefTuning if tuning_res is StandInThiefTuning else StandInThiefTuning.new()
	display_name = "stand-in thief"
	stompable = true
	dash_kills = true
	# DESIGN-TBD (docs/questions/b6.md 2): the claws catch it like any enemy (GDD §8).
	claw_immune = false
	jackpot_credits = tune.jackpot_credits
	if not (tuning_res is EnemyTuning):
		max_health = tune.health_early
		score_value = tune.score_value
	var lanes: int = world.geo.lane_count
	_x_min = world.geo.lane_x(0)
	_span = world.geo.lane_x(lanes - 1) - _x_min
	rel_ahead = tune.start_ahead
	y = tune.hover
	var aim: int = clampi(int(spawn.get("lane", world.player.lane)), 0, lanes - 1)
	_plan_crossing(world.geo.lane_x(aim))
	x = _sweep_x(_sweep)
	_build_model()
	var size: Vector3 = tune.block_size
	# Forgiving (CLAUDE.md principle 4): the hitbox sits a little inside the block.
	box = add_hitbox(&"top", size * 0.9, Vector3(0.0, size.y * 0.5, 0.0))
	box.steals_share = tune.steals_share
	box.contacted.connect(_on_contacted)
	_place()


func _tick(delta: float) -> void:
	match state:
		State.APPROACH:
			rel_ahead -= tune.approach_speed * delta
			_sweep += tune.cross_speed * delta
			x = _sweep_x(_sweep)
		State.FLEE:
			rel_ahead += tune.flee_speed * delta
			y = minf(y + tune.flee_rise * delta, tune.flee_height)
	_place()


## Gone once it got away with what it took (far ahead), or once the runner left it behind.
func should_retire() -> bool:
	return (state == State.FLEE and rel_ahead > tune.gone_ahead) or rel_ahead < -PASSED_BEHIND


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, tune.block_size.y * 0.5, 0.0)


func hit_radius() -> float:
	return maxf(tune.block_size.x, tune.block_size.y) * 0.6


## Caught: it bursts (the payout's coins and sound are ScoreKeeper's and RunEffects', for every thief).
func _on_defeated(_cause: StringName) -> void:
	world.effects.debris(aim_point(), GOLD, 8, 0.6)
	queue_free()


## Its touch robbed the runner: it makes off with what it took.
func _on_contacted(outcome: int) -> void:
	if outcome == DamageRules.Outcome.ROBBED and state == State.APPROACH:
		state = State.FLEE


## Sets the crossing so it's over `target_x` when the runner reaches it (rel_ahead 0): `cross_speed`
## metres along the folded path in each second of the approach, arriving from the side its seed picks.
func _plan_crossing(target_x: float) -> void:
	if _span <= 0.0:
		return
	var at: float = clampf(target_x - _x_min, 0.0, _span)
	if rng.randf() < 0.5:
		at = 2.0 * _span - at
	var meet: float = tune.start_ahead / maxf(tune.approach_speed, 0.01)
	_sweep = fposmod(at - tune.cross_speed * meet, 2.0 * _span)


## The world x of a point `s` metres along the side-to-side path (folded at the outer lanes' middles).
func _sweep_x(s: float) -> float:
	if _span <= 0.0:
		return _x_min
	var u: float = fposmod(s, 2.0 * _span)
	return _x_min + (u if u <= _span else 2.0 * _span - u)


func _place() -> void:
	position = Vector3(x, y, TrackGeometry.world_z(world.player.distance + rel_ahead))


func _build_model() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = GOLD
		_material.metallic = 0.85
		_material.roughness = 0.3
	var mesh := BoxMesh.new()
	mesh.size = tune.block_size
	_model = MeshInstance3D.new()
	_model.mesh = mesh
	_model.material_override = _material
	_model.position = Vector3(0.0, tune.block_size.y * 0.5, 0.0)
	add_child(_model)


## Quick play's review aid (--thief, debug builds; LevelRun loads this script by path): stand-ins one
## after another in `world`, each aimed at the runner's lane, a moment after the last one is gone
## (caught, or away). Returns the spawner node.
static func start_review(world: RunWorld) -> Node:
	var review := Review.new()
	review.name = "ThiefReview"
	review.world = world
	world.add_child(review)
	return review


## Sends stand-in thieves one at a time (start_review).
class Review extends Node:
	var world: RunWorld
	## Stand-ins sent so far (each one's seed).
	var sent: int = 0
	var _wait: float = 1.0
	var _current: Enemy

	func _physics_process(delta: float) -> void:
		if world == null or world.player == null or not world.player.running or not world.player.alive:
			return
		if _current != null and is_instance_valid(_current) and _current.alive:
			return
		_wait -= delta
		if _wait > 0.0:
			return
		sent += 1
		var tuning: StandInThiefTuning = EnemyDirector.tuning_for(TYPE) as StandInThiefTuning
		_wait = tuning.review_interval if tuning != null else 1.5
		_current = world.director.spawn({"type": TYPE, "at": world.player.distance, "lane": world.player.lane,
			"seed": sent})
