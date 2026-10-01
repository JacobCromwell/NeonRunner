class_name TitheCollector
extends Enemy
## The Tithe Collector (GDD §9.12), Corporate 2's new enemy: a small, fast gold drone with a
## collection plate, smug and gaudy. It builds on the robbed hit's shared mechanism (task B6's
## stand-in thief, scripts/enemies/stand_in_thief.gd carries the whole theft contract; docs/
## ARCHITECTURE.md, Thefts).
##
## - **Not a heli drone** (GDD §9.12, proposed): no rotors, gold stays plain metal and never glows
##   in a hazard colour (its eye glows a cool tech-blue instead — never pink, yellow, orange, red,
##   green or cyan), and anti-grav pads don't affect it (it never listens for Player.movement_event's
##   &"pad", unlike the drone).
## - **Approach:** like the stand-in thief, it appears `start_ahead` ahead of the player and closes
##   in at `approach_speed`, slower than the runner (so an ordinary run brings it into stomp and dash
##   reach: no boost needed), low enough to the floor to stomp the whole way in. A player who leaves
##   its lane before it arrives is never touched (the same clean dodge the stand-in thief allows).
## - **Weaving:** every `weave_interval` it looks `weave_lookahead` metres ahead of its own position
##   for the lane with the most hazards (gaps, fences, floor cuts, other floor enemies) and eases
##   toward it at `cross_speed` (_lane_danger, _reweave) — not the player's lane, unless nothing ahead
##   is more dangerous: the player who wants to catch it has to follow it into the risk (GDD §9.12:
##   "chasing it is the risk"). It's a body to touch, not a hazard (CLAUDE.md principle 4: lanes are
##   movement targets, never collision logic) — touching it never kills, so this weave can never make
##   a lane unfair; it only ever risks the 25% theft or rewards the chase with a catch.
## - **The vacuum:** every vacuum_interval it takes the floor credit nearest its own position, in its
##   own lane, within vacuum_reach (CreditField.take_near): off the track, ScoreKeeper.hold()'d so
##   stars stay fair (GDD §7), with RunEffects.coin_stream flying it into the collector for the
##   visible stream GDD §9.12 asks for.
## - **The approach cue:** a smug laugh plays once it exists (not a warning — touching it isn't an
##   attack — but CLAUDE.md still asks that the player notice it).
## - **Theft and the catch:** its hitbox declares the theft (Hazard.steals_share, from its
##   TitheCollectorTuning); any defeat (a stomp, a shot, the dash, the claws) is a catch, and
##   ScoreKeeper.pay_out (wired generically to every thief, task B6) bursts out everything it holds
##   plus its jackpot. Robbed, it flees ahead and up with what it took, exactly like the stand-in
##   thief, until it's gone for good (should_retire) or caught on its way out.
## Spawn params: none (every lane crossing is decided live, from the layout around it). Numbers:
## data/enemies/tithe_collector.tres (TitheCollectorTuning).

const MeshBatch = preload("res://scripts/enemies/mesh_batch.gd")
const O = DamageRules.Outcome
## Once the runner is this far past it, never touched, it's gone (metres at REFERENCE_SPEED,
## stretched by the pace): a clean dodge, like the stand-in thief's.
const PASSED_BEHIND: float = 8.0
## Gold, plain metal (GDD §9.12): never glows, so it never reads as a hazard.
const GOLD := Color(1.0, 0.76, 0.3)
const GOLD_TRIM := Color(1.0, 0.9, 0.62)
const DARK := Color(0.12, 0.1, 0.06)
## Its eye: a cool, pale tech-blue glow against its warm gold body — never a hazard colour (pink,
## yellow, orange, red, green or cyan), so it reads as smug and gaudy rather than dangerous.
const EYE_COLOR := Color(0.72, 0.8, 1.0)

enum State { APPROACH, FLEE }

var state: State = State.APPROACH
var tune: TitheCollectorTuning
## Its one hitbox (the theft, and the stomp from above).
var box: Hazard

## Track distance (metres along the track, like Enemy.track_distance), world x and height.
var track_d: float = 0.0
var lane_x_now: float = 0.0
var height_now: float = 0.0
## Ahead of the player right now (APPROACH: shrinking from tune.start_ahead_at(pace); FLEE: growing).
var rel_ahead: float = 0.0
var target_lane: int = 0
var _weave_t: float = 0.0
var _vacuum_t: float = 0.0
var _lat_v: float = 0.0
var _bob_t: float = 0.0
var _pivot: Node3D
static var _mesh: ArrayMesh
static var _gold_mat: StandardMaterial3D


func _build() -> void:
	tune = tuning_res as TitheCollectorTuning if tuning_res is TitheCollectorTuning else TitheCollectorTuning.new()
	display_name = "Tithe Collector"
	stompable = true
	dash_kills = true
	# GDD §8: the claws catch it like any other enemy (the stand-in thief's default, B6; DESIGN-TBD
	# docs/questions/b6.md 2).
	claw_immune = false
	jackpot_credits = tune.jackpot_credits
	if not (tuning_res is EnemyTuning):
		max_health = tune.health_early
		score_value = tune.score_value
	var lanes: int = world.geo.lane_count
	target_lane = clampi(int(spawn.get("lane", world.player.lane)), 0, lanes - 1)
	var pace: float = world.tuning.pace()
	rel_ahead = tune.start_ahead_at(pace)
	height_now = tune.hover_height
	lane_x_now = world.geo.lane_x(target_lane)
	track_d = world.player.distance + rel_ahead
	_bob_t = rng.randf() * TAU
	_build_model()
	var size: Vector3 = tune.body_size
	box = add_hitbox(&"top", size * 0.9, Vector3(0.0, size.y * 0.5, 0.0))
	box.steals_share = tune.steals_share
	box.contacted.connect(_on_contacted)
	_place()
	# An approach cue (GDD §9.12), not a hazard warning: it isn't an attack, but it must be
	# noticeable, so it plays for everyone to hear, like the Resonator's chime. Anti-grav pads
	# don't affect it (GDD §9.12, proposed): it never connects to world.player.movement_event,
	# unlike the heli drone.
	world.play_sfx(&"tithe_collector_cue")


func _tick(delta: float) -> void:
	var p: Player = world.player
	var pace: float = world.tuning.pace()
	match state:
		State.APPROACH:
			rel_ahead -= tune.approach_speed_at(pace) * delta
			track_d = p.distance + rel_ahead
			_reweave(pace, delta)
			var target_x: float = world.geo.lane_x(target_lane)
			var step: float = tune.cross_speed_at(pace) * delta
			_lat_v = clampf(target_x - lane_x_now, -step, step) / maxf(delta, 0.0001)
			lane_x_now = move_toward(lane_x_now, target_x, step)
			_vacuum(pace, delta)
		State.FLEE:
			rel_ahead += tune.flee_speed_at(pace) * delta
			track_d = p.distance + rel_ahead
			height_now = minf(height_now + tune.flee_rise_at(pace) * delta, tune.flee_height)
			_lat_v = 0.0
	_bob_t += delta
	_place()


## Gone once it fled with what it took (far ahead for good), or, never touched, has run well behind
## the player (the stand-in thief's PASSED_BEHIND: a clean dodge).
func should_retire() -> bool:
	var pace: float = world.tuning.pace() if world != null else 1.0
	if state == State.FLEE:
		return rel_ahead > tune.gone_ahead_at(pace)
	return rel_ahead < -PASSED_BEHIND * pace


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, tune.body_size.y * 0.5, 0.0)


func hit_radius() -> float:
	return maxf(tune.body_size.x, tune.body_size.z) * 0.6


## Caught: it bursts (the payout's coins and sound are ScoreKeeper's and RunEffects', shared by
## every thief, task B6).
func _on_defeated(_cause: StringName) -> void:
	world.effects.debris(aim_point(), GOLD, 10, 0.6)
	queue_free()


## Its touch robbed the runner: it makes off with what it took, exactly like the stand-in thief.
func _on_contacted(outcome: int) -> void:
	if outcome == O.ROBBED and state == State.APPROACH:
		state = State.FLEE


# --- Weaving (GDD §9.12: "weaves through the most dangerous lanes") ----------------------------

## Reconsiders its target lane every weave_interval: the lane with the most hazards from its own
## position to weave_lookahead ahead of it, among the lanes the generator placed anything in; with
## nothing dangerous ahead it settles over the player's own lane. Ties keep the lane it's already
## heading for (no flicker), else its seeded rng breaks them, so a seed always weaves the same way
## (determinism, like every enemy's rng).
func _reweave(pace: float, delta: float) -> void:
	_weave_t -= delta
	if _weave_t > 0.0:
		return
	_weave_t = tune.weave_interval
	var lanes: int = world.geo.lane_count
	var from: float = track_d
	var to: float = track_d + tune.weave_lookahead_at(pace)
	var best_score: int = -1
	var best: Array[int] = []
	for l: int in lanes:
		var s: int = _lane_danger(l, from, to)
		if s > best_score:
			best_score = s
			best = [l]
		elif s == best_score:
			best.append(l)
	if best_score <= 0:
		target_lane = clampi(world.player.lane, 0, lanes - 1)
	elif not best.has(target_lane):
		target_lane = best[rng.randi() % best.size()]


## How many hazards (gaps, fences, floor cuts, other floor enemies) lie in `lane` between `from` and
## `to` metres along the track: a simple count, cheap and good enough for the owner's "keep it simple
## and cheap" priority (GDD §9.12: the first idea to drop if the budget tightens).
func _lane_danger(lane: int, from: float, to: float) -> int:
	var n: int = 0
	for g: Dictionary in world.layout.gaps:
		if int(g["lane"]) == lane and float(g["start"]) <= to and float(g["end"]) >= from:
			n += 1
	for f: Dictionary in world.layout.fences:
		if int(f["lane"]) == lane and float(f["at"]) >= from and float(f["at"]) <= to:
			n += 1
	for c: Dictionary in world.layout.cuts:
		if int(c["lane"]) == lane and float(c["start"]) <= to and float(c["end"]) >= from:
			n += 1
	for e: Dictionary in world.layout.enemies:
		if String(e.get("type", "")) == String(type_id):
			continue
		if int(e.get("lane", -1)) == lane and float(e["at"]) >= from and float(e["at"]) <= to:
			n += 1
	return n


# --- The vacuum (GDD §9.12: "sucks up the credits in its path") --------------------------------

func _vacuum(pace: float, delta: float) -> void:
	_vacuum_t -= delta
	if _vacuum_t > 0.0:
		return
	_vacuum_t = tune.vacuum_interval
	var lane: int = world.geo.lane_at(lane_x_now)
	var got: Dictionary = world.credits.take_near(lane, track_d, tune.vacuum_reach_at(pace))
	if got.is_empty():
		return
	var value: int = int(got["value"])
	world.score.hold(self, value)
	var fx: SpeedFxTuning = world.effects.tuning
	world.effects.coin_stream(null, got["pos"], self, aim_point() - global_position, 1, value,
		fx.coin_stream_flight, fx.coin_stream_spread, fx.coin_stream_arc)


# --- Presentation --------------------------------------------------------------------------------

func _place() -> void:
	var bob: float = sin(_bob_t * 2.6) * 0.05
	global_position = Vector3(lane_x_now, height_now + bob, TrackGeometry.world_z(track_d))
	if _pivot != null:
		_pivot.rotation.z = clampf(-_lat_v * 0.035, -0.4, 0.4)
		_pivot.rotation.x = clampf(_lat_v * 0.01, -0.12, 0.12)


func _build_model() -> void:
	_pivot = Node3D.new()
	_pivot.scale = Vector3.ONE * tune.model_scale
	add_child(_pivot)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _model_mesh()
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(mesh_inst)


## Low-poly model in local space, facing +z (toward the player it hovers ahead of, like the drone's):
## a squat gold body, a wide shallow collection plate underneath (tilted a little forward, as if
## scooping), and a smug, slanted glowing eye band. One look everywhere (GDD §9.12: gold is plain
## metal in every zone, unlike the drone's zone variants).
static func _model_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var gold: Material = _gold_material()
	var trim: Material = GreyboxMaterials.flat(GOLD_TRIM)
	var dark: Material = GreyboxMaterials.flat(DARK)
	var eye: Material = GreyboxMaterials.glow(EYE_COLOR, 2.2)
	var b := MeshBatch.new()
	b.box(gold, Vector3(0.0, 0.08, -0.05), Vector3(0.56, 0.3, 0.52))
	b.wedge(gold, Vector3(0.0, 0.08, -0.33), Vector3(0.5, 0.28, 0.22), Vector3(-PI * 0.5, 0.0, 0.0))
	b.box(dark, Vector3(0.0, 0.18, 0.08), Vector3(0.3, 0.1, 0.2))
	# The smug, slanted eye band (a visor tipped up at the outer corner).
	b.box(eye, Vector3(0.0, 0.2, 0.22), Vector3(0.38, 0.05, 0.02), Vector3(0.0, 0.0, 0.1))
	# The collection plate: a wide shallow dish underneath, tilted forward to scoop.
	b.cylinder(gold, Vector3(0.0, -0.2, 0.08), Vector3(0.92, 0.05, 0.92), Vector3(0.14, 0.0, 0.0))
	b.cylinder(trim, Vector3(0.0, -0.17, 0.08), Vector3(0.96, 0.015, 0.96), Vector3(0.14, 0.0, 0.0))
	b.box(dark, Vector3(0.0, -0.01, 0.0), Vector3(0.18, 0.2, 0.18))
	_mesh = b.commit()
	return _mesh


## Lit by the scene, not shining by itself: mostly diffuse, so dark zones don't turn it brown (GDD
## §9.12: "Gold here is metal; it never glows in a hazard colour").
static func _gold_material() -> StandardMaterial3D:
	if _gold_mat == null:
		_gold_mat = StandardMaterial3D.new()
		_gold_mat.albedo_color = GOLD
		_gold_mat.metallic = 0.5
		_gold_mat.metallic_specular = 0.85
		_gold_mat.roughness = 0.3
	return _gold_mat
