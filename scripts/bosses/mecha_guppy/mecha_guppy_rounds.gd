class_name MechaGuppyRounds
extends Node3D
## Captain Cogs' rounds in phase 3 (GDD §10: "The captain's ship comes level with the player, fires rounds of attacks at
## the player that the player must dodge by switching lanes like normal"; the warning, the owner's (October 10, 2026):
## "red lines down the lanes they'll hit and a cannon's charging sound"; task E5e-c). MechaGuppyTop fires each round on
## its beat, at the lanes it strikes:
## - fire(): the warning. A red line down each struck lane (BossProps.lane_warning on the top's deck: pulsing, steady
##   with Reduced flashing; pickups keep off it) over the stretch its cannonball will roll down, from where it lands to
##   past where it meets the runner, and the cannons' charge heard from the ship (cogs_charge, as long as round_warning);
## - round_warning later the broadside (cogs_cannon; CaptainCogsShip.fire, its flash, smoke and recoil): a cannonball
##   from one of the ship's cannons facing the top for each struck lane, lobbed over the eaves (round_flight) onto the far
##   end of its lane's line, round_ahead ahead of the runner;
## - then it rolls down its lane at them, closing in at round_close: a round iron ball with a brass band (round_radius),
##   too tall to jump, so the dodge is a switch out of its lane; its hitbox a little smaller (an enemy attack: real
##   contact only; armor and the shield block it, the dash passes through it); past the runner it rolls on behind them
##   and is gone, its line with it.
## Every round leaves the lanes it doesn't strike clear, and its time from the warning to the runner never changes with
## the run's speed (round_close, round_ahead: it keeps pace with the runner, as the Resonator's waves close in at the same
## speed at any pace). Its own clock runs on the boss's ticks (time from the physics step; it waits while the runner is
## down). DESIGN-TBD (docs/questions/e5e.md): the rounds' numbers and the cannonball's look.

const BALL_NAME: String = "Captain Cogs' cannonball"
## The hitbox against the ball (GDD §3: a little smaller than the visual): its share of the ball's width, height (from
## the deck up: too tall to jump at round_radius 1 m and more) and depth.
const HIT_WIDTH: float = 0.65
const HIT_HEIGHT: float = 0.85
const HIT_DEPTH: float = 0.7
## The red line reaches this far past where the ball meets the runner, and past where it lands (metres).
const LINE_PAST: float = 2.0
const LINE_BEYOND: float = 1.0
## The lob's height over the straight line from the cannon to where the ball lands (metres, at its middle).
const LOB: float = 2.5
## A ball is past the runner once its hitbox's back is this far behind their hurtbox (metres); it's gone this long after
## (seconds), rolling on behind them.
const PAST_MARGIN: float = 0.3
const GONE_AFTER: float = 1.2
## The landing's thud: a puff of the deck's dust.
const DUST_COLOR := Color(0.62, 0.5, 0.36)

var boss: MechaGuppy
var world: RunWorld
var tuning: MechaGuppyTuning
## Seconds of rounds so far (its rounds keep to this clock).
var clock: float = 0.0
## Rounds fired and balls launched over the fight (tests).
var fired: int = 0
var balls_shot: int = 0
## The rounds under way: {k (its beat), lanes, start, shot, land, meet (clock), d0 (the runner then), d_land, d_meet, y
## (the deck's height), speed (the ball's speed toward the runner along the track), lines ([MeshInstance3D]), balls
## ([{lane, node, hazard, from}]), state (WARN, FLY, ROLL, DONE)}.
var rounds: Array[Dictionary] = []

enum State { WARN, FLY, ROLL, DONE }

var _pool: Array[Node3D] = []
var _hazards: Array[Hazard] = []

## The ball's body per material (ball_mesh).
static var _ball_meshes: Dictionary = {}


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	tuning = boss.tuning
	top_level = true
	transform = Transform3D.IDENTITY


## Everything off: lines gone, balls hidden, hitboxes off (the fight is won).
func clear() -> void:
	for r: Dictionary in rounds:
		_end(r)
	rounds.clear()


## One physics step (MechaGuppy's ticks drive it).
func tick(delta: float) -> void:
	clock += delta
	for i: int in range(rounds.size() - 1, -1, -1):
		var r: Dictionary = rounds[i]
		_advance(r, delta)
		if int(r["state"]) == State.DONE:
			rounds.remove_at(i)


## A round's times for a runner at `speed` (m/s), from its warning: {shot, land, meet} (seconds after the warning
## starts) and how far ahead of the runner (at the warning) it lands and meets them (metres along the track).
func timing(speed: float) -> Dictionary:
	var v: float = maxf(speed, 1.0)
	var shot: float = tuning.round_warning
	var land: float = shot + tuning.round_flight
	var meet: float = land + tuning.round_ahead / maxf(tuning.round_close, 1.0)
	return {"shot": shot, "land": land, "meet": meet, "land_ahead": v * land + tuning.round_ahead, "meet_ahead": v * meet}


## Fires round `k` at `lanes` (the lanes it strikes; MechaGuppyTop leaves the others clear): its warning starts now (see
## the header). Returns its record.
func fire(k: int, lanes: Array[int]) -> Dictionary:
	var p: Player = world.player
	var v: float = maxf(p.speed, 1.0)
	var t: Dictionary = timing(v)
	var y: float = p.floor_base
	var d0: float = p.distance
	var r: Dictionary = {"k": k, "lanes": lanes.duplicate(), "start": clock, "shot": clock + float(t["shot"]),
		"land": clock + float(t["land"]), "meet": clock + float(t["meet"]), "d0": d0,
		"d_land": d0 + float(t["land_ahead"]), "d_meet": d0 + float(t["meet_ahead"]), "y": y,
		"speed": maxf(tuning.round_close - v, 0.5), "lines": [], "balls": [], "state": State.WARN}
	for lane: int in lanes:
		(r["lines"] as Array).append(boss.props.lane_warning(lane, float(r["d_meet"]) - LINE_PAST,
			float(r["d_land"]) + LINE_BEYOND, y))
	rounds.append(r)
	fired += 1
	boss.sound(&"cogs_charge", _ship_point())
	boss.log_event(&"round", {"k": k, "lanes": lanes.duplicate(), "lane": p.lane, "d0": d0, "warning": float(t["meet"]),
		"d_land": float(r["d_land"]), "d_meet": float(r["d_meet"])})
	return r


## The lanes struck by the rounds whose balls haven't passed the runner yet (the red lines showing now; tests, the bot):
## {lane: true}.
func warned_lanes() -> Dictionary:
	var out: Dictionary = {}
	for r: Dictionary in rounds:
		if int(r["state"]) == State.DONE or r.has("passed"):
			continue
		for lane: int in r["lanes"]:
			out[lane] = true
	return out


## The live balls' hitboxes (tests).
func ball_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for r: Dictionary in rounds:
		for b: Dictionary in r["balls"]:
			var h: Hazard = b["hazard"]
			if h != null and h.is_active():
				out.append(h)
	return out


## Where a ball of round `r` is along the track at clock `at` once it has landed (track distance).
static func ball_d(r: Dictionary, at: float) -> float:
	return float(r["d_land"]) - float(r["speed"]) * maxf(at - float(r["land"]), 0.0)


func _advance(r: Dictionary, delta: float) -> void:
	var p: Player = world.player
	match int(r["state"]):
		State.WARN:
			if clock >= float(r["shot"]) - 0.0001:
				_shoot(r)
		State.FLY:
			var s: float = clampf((clock - float(r["shot"])) / maxf(float(r["land"]) - float(r["shot"]), 0.01), 0.0, 1.0)
			for b: Dictionary in r["balls"]:
				var to: Vector3 = _ball_point(r, int(b["lane"]), float(r["d_land"]))
				var node: Node3D = b["node"]
				node.global_position = (b["from"] as Vector3).lerp(to, s) + Vector3(0.0, LOB * 4.0 * s * (1.0 - s), 0.0)
				node.rotate_x(delta * 5.0)
			if clock >= float(r["land"]) - 0.0001:
				_land(r)
		State.ROLL:
			var d: float = ball_d(r, clock)
			var spin: float = float(r["speed"]) / maxf(tuning.round_radius, 0.1) * delta
			for b: Dictionary in r["balls"]:
				var node: Node3D = b["node"]
				node.global_position = _ball_point(r, int(b["lane"]), d)
				node.rotate_x(spin)
				(b["hazard"] as Hazard).global_position = Vector3(world.geo.lane_x(int(b["lane"])),
					float(r["y"]) + _hit_size().y * 0.5, TrackGeometry.world_z(d))
			var past: float = p.distance - world.tuning.hurtbox_size.z * 0.5 - _hit_size().z * 0.5 - PAST_MARGIN
			if d < past:
				for b: Dictionary in r["balls"]:
					(b["hazard"] as Hazard).set_enabled(false)
				for line: Variant in r["lines"]:
					boss.props.remove(line as Node)
				(r["lines"] as Array).clear()
				if not r.has("passed"):
					r["passed"] = clock
					boss.log_event(&"round_passed", {"k": int(r["k"])})
				if clock - float(r["passed"]) >= GONE_AFTER:
					_end(r)


## The broadside: a ball from a cannon facing the top for each struck lane, the shot heard.
func _shoot(r: Dictionary) -> void:
	r["state"] = State.FLY
	var lanes: Array = r["lanes"]
	if boss.ship != null and is_instance_valid(boss.ship):
		boss.ship.fire(lanes.size())
	for i: int in lanes.size():
		var node: Node3D = _free_ball()
		node.visible = true
		var from: Vector3 = boss.ship.cannon_world(i % CaptainCogsModel.CANNONS) if boss.ship != null \
			else _ball_point(r, int(lanes[i]), float(r["d_land"])) + Vector3(0.0, 6.0, 0.0)
		node.global_position = from
		(r["balls"] as Array).append({"lane": int(lanes[i]), "node": node, "hazard": null, "from": from})
		balls_shot += 1
	boss.sound(&"cogs_cannon", _ship_point())
	boss.log_event(&"round_shot", {"k": int(r["k"]), "lanes": lanes.duplicate()})


## The balls land on the far end of their lines: their hitboxes on, a thud of dust, and they roll.
func _land(r: Dictionary) -> void:
	r["state"] = State.ROLL
	var size: Vector3 = _hit_size()
	for b: Dictionary in r["balls"]:
		var hazard: Hazard = _free_hazard()
		((hazard.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
		hazard.size = size
		hazard.global_position = Vector3(world.geo.lane_x(int(b["lane"])), float(r["y"]) + size.y * 0.5,
			TrackGeometry.world_z(float(r["d_land"])))
		hazard.set_enabled(true)
		b["hazard"] = hazard
		world.effects.debris(_ball_point(r, int(b["lane"]), float(r["d_land"])) - Vector3(0.0, tuning.round_radius * 0.8, 0.0),
			DUST_COLOR, 4, 0.6)
	var near: float = clampf(1.0 - absf(float(r["d_land"]) - world.player.distance) / 40.0, 0.2, 1.0)
	world.effects.shake(0.12 * near, 0.2)
	boss.log_event(&"round_landed", {"k": int(r["k"]), "d": float(r["d_land"])})


## A round's look and hitboxes gone.
func _end(r: Dictionary) -> void:
	r["state"] = State.DONE
	for line: Variant in r["lines"]:
		boss.props.remove(line as Node)
	(r["lines"] as Array).clear()
	for b: Dictionary in r["balls"]:
		(b["node"] as Node3D).visible = false
		if b["hazard"] != null:
			(b["hazard"] as Hazard).set_enabled(false)
	(r["balls"] as Array).clear()


## A ball's middle over `lane` at track distance `d`, resting on round `r`'s deck.
func _ball_point(r: Dictionary, lane: int, d: float) -> Vector3:
	return Vector3(world.geo.lane_x(lane), float(r["y"]) + tuning.round_radius, TrackGeometry.world_z(d))


## The ball's hitbox: smaller than the ball, standing on the deck.
func _hit_size() -> Vector3:
	var diameter: float = tuning.round_radius * 2.0
	return Vector3(diameter * HIT_WIDTH, diameter * HIT_HEIGHT, diameter * HIT_DEPTH)


## Where the charge and the shot are heard: the ship's middle (or high ahead of the runner without one).
func _ship_point() -> Vector3:
	if boss.ship != null and is_instance_valid(boss.ship):
		return boss.ship.global_position + Vector3(0.0, CaptainCogsModel.DECK, 0.0)
	var p: Player = world.player
	return Vector3(0.0, p.floor_base + 4.0, TrackGeometry.world_z(p.distance + tuning.level_ahead))


# --- Pools and the cannonball's look --------------------------------------------------------------

func _free_ball() -> Node3D:
	for b: Node3D in _pool:
		if not b.visible:
			return b
	var node := MeshInstance3D.new()
	node.name = "Cannonball"
	var beach := world.skin as BeachSkin
	node.mesh = ball_mesh(beach.solid_material() if beach != null else null)
	if beach == null:
		node.material_override = GreyboxMaterials.scenery(Color(0.1, 0.1, 0.11))
	node.scale = Vector3.ONE * tuning.round_radius
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	_pool.append(node)
	return node


func _free_hazard() -> Hazard:
	for h: Hazard in _hazards:
		if not h.is_active() and not _holding(h):
			return h
	var hazard := Hazard.new()
	hazard.name = "BallHit"
	hazard.hazard_name = BALL_NAME
	hazard.is_enemy_attack = true
	hazard.part = &"attack"
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.collision_mask = 0
	hazard.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	hazard.add_child(shape)
	add_child(hazard)
	hazard.set_enabled(false)
	_hazards.append(hazard)
	return hazard


func _holding(h: Hazard) -> bool:
	for r: Dictionary in rounds:
		for b: Dictionary in r["balls"]:
			if b["hazard"] == h:
				return true
	return false


## The cannonball (GDD §10: Captain Cogs in a pirate look, as the bombs): a round black iron ball, radius 1 (scaled to
## round_radius), with a brass band round its middle and a brass plug; in `material` (the skin's solid one), shared.
static func ball_mesh(material: Material) -> ArrayMesh:
	var key: int = material.get_instance_id() if material != null else 0
	if _ball_meshes.has(key):
		return _ball_meshes[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var iron := Color(0.085, 0.085, 0.095)
	var iron_light := Color(0.13, 0.13, 0.145)
	var brass := Color(0.78, 0.6, 0.3)
	var rings: int = 8
	var sides: int = 12
	for i: int in rings:
		var a0: float = PI * float(i) / float(rings) - PI * 0.5
		var a1: float = PI * float(i + 1) / float(rings) - PI * 0.5
		for j: int in sides:
			var b0: float = TAU * float(j) / float(sides)
			var b1: float = TAU * float(j + 1) / float(sides)
			var p00 := Vector3(cos(a0) * cos(b0), sin(a0), cos(a0) * sin(b0))
			var p01 := Vector3(cos(a0) * cos(b1), sin(a0), cos(a0) * sin(b1))
			var p10 := Vector3(cos(a1) * cos(b0), sin(a1), cos(a1) * sin(b0))
			var p11 := Vector3(cos(a1) * cos(b1), sin(a1), cos(a1) * sin(b1))
			var tone: Color = iron if (i + j) % 2 == 0 else iron_light
			var out: Vector3 = (p00 + p11) * 0.5
			if (p01 - p00).cross(p11 - p00).dot(out) > 0.0:
				s.quad(p00, p10, p11, p01, tone)
			else:
				s.quad(p00, p01, p11, p10, tone)
	# The brass band round its middle (about x, so it reads as it rolls), and the plug.
	s.prism_xform(Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled_local(Vector3(1.03, 0.16, 1.03)), Vector3(0.08, 0.0, 0.0)),
		sides, brass)
	s.box(Vector3(0.0, 0.0, 0.98), Vector3(0.28, 0.28, 0.12), brass)
	var mesh: ArrayMesh = batch.to_mesh()
	_ball_meshes[key] = mesh
	return mesh
