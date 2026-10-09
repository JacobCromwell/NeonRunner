class_name CyborgGun
extends RefCounted
## The cyborgs' arm cannon (GDD §9.2), shared by floor and window cyborgs. A burst is:
## 1. a visible charge-up (the arm cannon glows up, CyborgBody.set_charge) with the cyborg_charge
##    sound: the telegraph, which always comes first (CLAUDE.md readability rules);
## 2. 2–3 laser bolts through ProjectilePool.fire_enemy (the pool's red enemy look). The aim locks
##    when the charge-up ends: each bolt flies to where a player keeping that line would be when it
##    arrives, give or take a little (loosely aimed), so switching lanes after the charge-up dodges
##    the whole burst. The panic variant fires wildly instead: every bolt at a random spot around
##    the player;
## 3. a reload pause.
##
## Fairness (GDD §9 shared rules): a burst only starts, and a bolt only fires, if
## - none of its bolts would arrive where the shooter holds its fire (`hold`, task G7);
## - the shooter is ahead of the player and within engage_distance (never from behind or out of
##   sight), and the enemy's own may_attack() agrees (e.g. not at a player on the ceiling);
## - each bolt needs at least min_warning_time to arrive;
## - the player's path around every bolt's arrival is free of fences and gaps in all lanes, so a
##   burst is never timed onto a jump or a full-lane fence, and of zone doodads (GDD §3: a doodad's
##   side blocks a dodge and its push moves the player);
## - fewer than GameRules.max_bursts_in_air bursts of the cyborg-type guns are in the air (GDD §9.2,
##   owner, October 8, 2026: up to two at once; CyborgAirspace, shared through RunWorld metadata), and
##   no boss holds the whole airspace (the Floating Head's eye lasers);
## - the crossfire rule (DESIGN-TBD, docs/OPEN_QUESTIONS.md item 600): bursts whose bolts arrive within
##   crossfire_gap of each other always leave the runner a way out, a place one move away that none of
##   them is aimed at, and wild fire never arrives that close to another burst (_crossfire_fair). A
##   burst that would leave none waits before its charge-up, never after it; the check as its aim
##   locks is a last resort that calls it off.
## Everything runs in the physics step from the enemy's seeded random stream, so every attempt at a
## seed plays out the same way.
##
## Pace (GDD §3, owner's playtest September 30, 2026: enemies speed up to match the runner): the
## engage distance, the bolt speed and the clear path around an impact are given at
## MovementTuning.REFERENCE_SPEED and stretched by the level's pace (`pace`), so in a faster zone the
## bolts fly faster from further out and every burst keeps its seconds; the charge-up and
## min_warning_time are seconds already and never get shorter.

enum State { READY, CHARGING, FIRING, RELOADING }

const SHOT_NAME: String = "cyborg bolt"
const LOOK: StringName = &"enemy_bolt"
## Pause after a cancelled charge before trying again.
const RETRY_PAUSE: float = 0.35
## The crossfire rule as a burst would start its charge-up counts bursts arriving within crossfire_gap plus
## this long: the arrivals it predicts can be off by a few hundredths of a second by the lock (a walking
## cyborg stops to shoot, the runner moves), and a burst that clears the start by a hair mustn't be called
## off at its lock for it.
const START_MARGIN: float = 0.15

var shooter: Enemy
var world: RunWorld
var tuning: CyborgGunTuning
var rng: RandomNumberGenerator
## The shooter's model, which shows the telegraph: a CyborgBody, or another enemy's (GunModel).
var body: GunModel
## Wild fire (the panic variant): each bolt goes to a random spot around the player, up to
## wild_spread sideways.
var wild: bool = false
var wild_spread: float = 2.0
var enabled: bool = true
## The charge-up's and each bolt's sounds, and the bolts' name (a death's cause): the cyborgs' own
## unless the shooter has its own (the Barnacle Turret, GDD §9.8).
var charge_sound: StringName = &"cyborg_charge"
var shot_sound: StringName = &"cyborg_shot"
var shot_name: String = SHOT_NAME
## The shooter's own rule for the player's path around a bolt's arrival, in place of the floor's
## (path_clear): Callable(from_d: float, to_d: float) -> bool. Unset for the cyborgs; the Barnacle
## Turret, which fires only at a ceiling rider, sets one for the ceiling (GDD §9.8).
var path_rule: Callable
## The shooter's own rule for the lanes a player dodging its bolts can switch into (the crossfire rule,
## _moves): Callable(lane: int, from_d: float, to_d: float) -> bool, `from_d` to `to_d` the track
## distances from the player to past its bolts' arrival. Unset: any of the track's lanes a lane blocker
## doesn't hold (_lane_held); the Barnacle Turret's: its ceiling's lanes without a turret in them there
## (GDD §9.8).
var lane_rule: Callable
## Where bolts leave the cannon, from the enemy's origin (gameplay: the visual cannon animates, the
## shots never depend on it). Bolts start muzzle_reach further along their line.
var muzzle_offset: Vector3 = Vector3(0.0, 1.12, 0.0)
var muzzle_reach: float = 0.45
## The shooter's own speed along the track (m/s, + = forward, away from the player), for predictions.
var track_velocity: float = 0.0
## The level's pace (MovementTuning.pace; 1 at the reference speed, and in boss fights).
var pace: float = 1.0
## Returns whether the shooter may attack right now (the enemy's own rules).
var may_attack: Callable
## A stretch of the player's distances where none of its bolts may arrive (task G7: a cyborg planted in a
## charge's path holds its fire through the charge's warning and strike, ChargePathPlacement): a burst whose
## bolts would land there isn't fair (_burst_fair). Empty (Vector2(INF, -INF)) for every other shooter.
var hold := Vector2(INF, -INF)
var state: State = State.READY
## Every charge, shot and cancelled burst (for tests and debugging): {"t" (level time),
## "event": &"charge" | &"shot" | &"cancel", "player_d" and "shooter_d" (track distances); charges
## add "shots"; shots add "impact" (track distance), "arrive" (level time), "from", "velocity", "line"
## (the world x the burst was aimed along) and "wild"; cancels add "why" (_cancel), and the player's
## "lane" and "surface"}.
var events: Array[Dictionary] = []

var _timer: float = 0.0
var _shots_left: int = 0
var _burst: int = 0
var _lock := Vector2.ZERO
## The burst's place in the airspace (CyborgAirspace.claim) while it charges and fires.
var _claim: Dictionary = {}
## The burst _burst_fair last planned: when its bolts would arrive (level times, x to y), and how far
## along the track the player's path around them reaches.
var _window := Vector2.ZERO
var _reach: float = 0.0
## The physics query the crossfire rule asks with (_lane_held, _wall_open), made on first use.
var _query: PhysicsShapeQueryParameters3D


func _init(p_shooter: Enemy, p_world: RunWorld, p_tuning: CyborgGunTuning, p_rng: RandomNumberGenerator,
		p_body: GunModel) -> void:
	shooter = p_shooter
	world = p_world
	tuning = p_tuning
	rng = p_rng
	body = p_body
	if world != null and world.tuning != null:
		pace = world.tuning.pace()


## How close the player must be before a burst may start (engage_distance at the level's pace).
func engage_distance() -> float:
	return tuning.engage_distance * pace


## The bolts' speed over the ground at the level's scaling and pace.
func bolt_speed() -> float:
	return tuning.bolt_speed_at(_scaling()) * pace


## Charging or firing a burst (the enemy shows its aiming pose and face).
func is_attacking() -> bool:
	return state == State.CHARGING or state == State.FIRING


## Runs the cannon for one physics frame.
func update(delta: float) -> void:
	if not enabled or world == null or world.player == null:
		return
	var player: Player = world.player
	match state:
		State.READY:
			_timer -= delta
			if _timer <= 0.0 and _allowed() and _airspace_free() and _burst_fair(tuning.charge_time, tuning.burst_max) \
					and _crossfire_fair(false):
				_start_charge()
		State.CHARGING:
			_timer += delta
			body.set_charge(_timer / tuning.charge_time)
			_aim_body(player)
			if not _allowed():
				_cancel(&"allowed")
			elif _timer >= tuning.charge_time:
				if not _burst_fair(0.0, _burst):
					_cancel(&"path")
				elif not _crossfire_fair(true):
					_cancel(&"crossfire")
				else:
					_lock_aim(player)
					var here: Dictionary = _here()
					_airspace().aim(_claim, _lock.x, int(here["surface"]), int(here["side"]), _window.x, _window.y)
					state = State.FIRING
					_timer = 0.0
					_fire_step(delta)
		State.FIRING:
			_aim_body(player)
			_fire_step(delta)
		State.RELOADING:
			_timer -= delta
			if _timer <= 0.0:
				state = State.READY
				_timer = 0.0


## Stops everything at once (the enemy was defeated or left play): its place in the air goes (bolts
## already on their way fly on).
func stop() -> void:
	if state == State.CHARGING or state == State.FIRING:
		_release_airspace()
	_claim = {}
	state = State.READY
	enabled = false
	body.set_charge(0.0)
	body.clear_aim()


## Seconds until a bolt fired from `from` at `speed` meets a target at `target` that runs toward -z at
## `v` (the player). -1 if it never does.
static func intercept_time(from: Vector3, target: Vector3, v: float, speed: float) -> float:
	var d: Vector3 = target - from
	var a: float = v * v - speed * speed
	var b: float = -2.0 * v * d.z
	var c: float = d.length_squared()
	if absf(a) < 1e-6:
		return c / -b if b < 0.0 else -1.0
	var disc: float = b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var root: float = sqrt(disc)
	var best: float = -1.0
	for t: float in [(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)]:
		if t > 0.0 and (best < 0.0 or t < best):
			best = t
	return best


func _allowed() -> bool:
	return shooter.alive and (not may_attack.is_valid() or bool(may_attack.call()))


## The world's airspace, shared by every cyborg-type gun (and a boss's eye lasers).
func _airspace() -> CyborgAirspace:
	return CyborgAirspace.of(world)


## Whether a burst may start: fewer than GameRules.max_bursts_in_air are in the air and no boss holds
## the whole airspace.
func _airspace_free() -> bool:
	var most: int = world.rules.max_bursts_in_air if world.rules != null else CyborgAirspace.DEFAULT_MOST
	return _airspace().may_start(world.level_time(), most)


## Gives up this gun's place in the air (and no other shooter's).
func _release_airspace() -> void:
	_airspace().release(shooter, world.level_time())


## The crossfire rule (DESIGN-TBD, docs/OPEN_QUESTIONS.md item 600; GDD §9.2: up to two bursts in the air at once,
## each dodged by switching lanes, GDD §3). Bursts whose bolts arrive within crossfire_gap of each other
## must always leave the runner a way out: a place one move away that none of them is aimed at (_way_out).
## Wild fire (the panic variant's, landing anywhere around the runner) never arrives that close to another
## burst. The burst _burst_fair just planned asks twice:
## - as it would start its charge-up (`locked` false), so that one that would leave no way out waits before
##   its telegraph, never after it (task R3's rule for an attack that waits): wherever the runner may be by
##   the time its aim locks, where they are now or one move away (a wall they can step onto included), it
##   must leave them a way out. Bursts already aimed count along their lines. One still charging that
##   began more than reaction_time ago may be dodged before this one locks, so it counts as aimed where the
##   runner is now; one that began since will lock where this one does. Bursts arriving up to
##   START_MARGIN later than crossfire_gap count too, for predictions a little off by the lock;
## - as its aim locks (`locked`), the last resort: only bursts already aimed count, and one that would leave
##   the runner no way out is called off (_cancel). A runner who moves while two charge-ups that began
##   together end can still bring it about.
func _crossfire_fair(locked: bool) -> bool:
	var now: float = world.level_time()
	var others: Array[Dictionary] = _airspace().near(_claim, _window.x, _window.y,
		tuning.crossfire_gap + (0.0 if locked else START_MARGIN), locked, now)
	if others.is_empty():
		return true
	if wild:
		return false
	var here: Dictionary = _here()
	var lines: Array[Dictionary] = []
	for c: Dictionary in others:
		if bool(c["wild"]):
			return false
		if bool(c["aimed"]):
			lines.append({"x": float(c["line"]), "surface": int(c["surface"]), "side": int(c["side"])})
		elif now - float(c["t0"]) > tuning.reaction_time:
			lines.append({"x": float(here["x"]), "surface": int(here["surface"]), "side": int(here["side"])})
	if not _way_out(here, lines):
		return false
	if locked:
		return true
	for place: Dictionary in _moves(here, true):
		if not _way_out(place, lines):
			return false
	return true


## Whether a burst aimed along `line` ({"x" (world x), "surface" (Player.Surface), "side" (a wall's)}) is
## aimed at place `place` (_here): only on the same surface (bolts aimed at a wall runner pass at least
## 0.7 m wide of the middle of the lane below and a bolt hits within about 0.3 m of it; a floor runner's
## pass under a wall runner's body; a ceiling rider's far above the floor), at that wall, or within half a
## lane of a lane's middle.
static func aims_at(line: Dictionary, place: Dictionary, geo: TrackGeometry) -> bool:
	if int(line["surface"]) != int(place["surface"]):
		return false
	if int(place["surface"]) == Player.Surface.WALL:
		return int(line["side"]) == int(place["side"])
	return absf(float(line["x"]) - float(place["x"])) <= geo.lane_width * 0.5


## Whether one of `places` is aimed at by none of `lines` (aims_at): a way out.
static func way_out(places: Array[Dictionary], lines: Array[Dictionary], geo: TrackGeometry) -> bool:
	for place: Dictionary in places:
		var free: bool = true
		for line: Dictionary in lines:
			if aims_at(line, place, geo):
				free = false
				break
		if free:
			return true
	return false


## A way out of `place`: way_out over the places one move from it (a wall not counted: the rule doesn't
## judge a wall's own hazards, a sign, a wall fence or a window cyborg).
func _way_out(place: Dictionary, lines: Array[Dictionary]) -> bool:
	return way_out(_moves(place, false), lines, world.geo)


## Where the runner is now, as a place the crossfire rule reasons about: {"surface" (Player.Surface),
## "lane" (a floor or ceiling lane; for a wall, the outer lane below it), "side" (a wall's; 0 otherwise),
## "x" (the world x a burst aimed there flies along)}.
func _here() -> Dictionary:
	var player: Player = world.player
	if player.surface == Player.Surface.WALL:
		return _wall_place(player.wall_side)
	return _lane_place(player.surface, world.geo.lane_at(player.hurtbox_aabb().get_center().x))


func _lane_place(surface: int, lane: int) -> Dictionary:
	return {"surface": surface, "lane": lane, "side": 0, "x": world.geo.lane_x(lane)}


func _wall_place(side: int) -> Dictionary:
	return {"surface": Player.Surface.WALL, "lane": world.geo.lane_count - 1 if side > 0 else 0, "side": side,
		"x": side * (world.geo.wall_x() - world.tuning.hurtbox_size.y * 0.5)}


## The places one move from `place` (GDD §3): the lanes beside a floor or ceiling lane; from an outer floor
## lane, with `onto_walls`, the wall beside it where the runner could step onto it now (_wall_open); from a
## wall, the outer lane below (a wall jump). A lane the shooter's lane_rule rules out is no place to go, nor
## a floor lane a lane blocker holds from the runner to past the bolts' arrival (_lane_held).
func _moves(place: Dictionary, onto_walls: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = world.geo.lane_count
	var surface: int = place["surface"]
	var lanes: Array[int] = []
	if surface == Player.Surface.WALL:
		surface = Player.Surface.FLOOR
		lanes.append(int(place["lane"]))
	else:
		for to: int in [int(place["lane"]) - 1, int(place["lane"]) + 1]:
			if to >= 0 and to < n:
				lanes.append(to)
	var from_d: float = world.player.distance
	for to: int in lanes:
		if lane_rule.is_valid() and not bool(lane_rule.call(to, from_d, _reach)):
			continue
		if surface == Player.Surface.FLOOR and _lane_held(to, from_d - 1.0, _reach):
			continue
		out.append(_lane_place(surface, to))
	if onto_walls and int(place["surface"]) == Player.Surface.FLOOR:
		var side: int = -1 if int(place["lane"]) == 0 else (1 if int(place["lane"]) == n - 1 else 0)
		if side != 0 and _wall_open(side):
			out.append(_wall_place(side))
	return out


## True if a lane blocker (a hover truck's solid side, a boss's prop: what bumps a lane switch back,
## Player._lane_blocked) holds floor lane `lane` anywhere from track distance `from_d` to `to_d`. A zone
## doodad doesn't count: none stands in any lane near the bolts' arrival (path_clear), and the runner
## passes one before that, then switches.
func _lane_held(lane: int, from_d: float, to_d: float) -> bool:
	if not shooter.is_inside_tree():
		return false
	var q: PhysicsShapeQueryParameters3D = _box_query(TrackBuilder.LAYER_LANE_BLOCKER,
		Vector3(world.geo.lane_width * 0.5, 1.2, maxf(to_d - from_d, 0.5)))
	q.transform = Transform3D(Basis.IDENTITY,
		Vector3(world.geo.lane_x(lane), 0.6, TrackGeometry.world_z((from_d + to_d) * 0.5)))
	for hit: Dictionary in shooter.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var area := hit.get("collider") as Node
		if area != null and not area.has_meta(&"doodad"):
			return true
	return false


## Whether the runner could step onto wall `side` now (GDD §3): it stands there (no wall gap) and nothing
## blocks an entry (a sign, a wall a boss takes away: what bumps the runner back, Player._wall_blocked).
func _wall_open(side: int) -> bool:
	var player: Player = world.player
	if not player.wall_supported(side, player.distance):
		return false
	if not shooter.is_inside_tree():
		return true
	var q: PhysicsShapeQueryParameters3D = _box_query(TrackBuilder.LAYER_WALL_BLOCKER,
		Vector3(0.5, 20.0, world.tuning.hurtbox_size.z + 0.4))
	q.transform = Transform3D(Basis.IDENTITY,
		Vector3(side * (world.geo.wall_x() - 0.3), 5.0, TrackGeometry.world_z(player.distance)))
	return shooter.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## The crossfire rule's physics query, a box of `size` against `mask` (areas only), made once.
func _box_query(mask: int, size: Vector3) -> PhysicsShapeQueryParameters3D:
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		_query.shape = BoxShape3D.new()
		_query.collide_with_areas = true
		_query.collide_with_bodies = false
	_query.collision_mask = mask
	(_query.shape as BoxShape3D).size = size
	return _query


func _start_charge() -> void:
	state = State.CHARGING
	_timer = 0.0
	_burst = rng.randi_range(tuning.burst_min, maxi(tuning.burst_min, tuning.burst_max))
	_shots_left = _burst
	var now: float = world.level_time()
	_claim = _airspace().claim(shooter, now + tuning.charge_time + (_burst - 1) * tuning.shot_interval
		+ tuning.burst_gap, _window.x, _window.y, wild, now)
	var at: Vector3 = _muzzle_base()
	world.play_sfx_at(charge_sound, at)
	events.append({"t": world.level_time(), "event": &"charge", "shots": _burst,
		"player_d": world.player.distance, "shooter_d": shooter.track_distance(), "from": at})


## Calls the charge-up off (`why`: &"allowed", the shooter may no longer attack; &"path", the burst
## would no longer be fair on the track; &"crossfire", the crossfire rule's last check at the lock).
func _cancel(why: StringName) -> void:
	state = State.READY
	_timer = RETRY_PAUSE
	_release_airspace()
	_claim = {}
	body.set_charge(0.0)
	body.clear_aim()
	var player: Player = world.player
	events.append({"t": world.level_time(), "event": &"cancel", "why": why, "player_d": player.distance,
		"shooter_d": shooter.track_distance(), "lane": player.lane, "surface": player.surface})


func _fire_step(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var player: Player = world.player
	if _shots_left > 0 and _allowed() and _time_to_player(player) >= tuning.min_warning_time * 0.5:
		_fire(player)
		_shots_left -= 1
		_timer = tuning.shot_interval
		body.set_charge(float(_shots_left) / float(maxi(_burst, 1)))
	else:
		_shots_left = 0
	if _shots_left <= 0:
		state = State.RELOADING
		_timer = tuning.reload_at(_scaling())
		# The claim runs on to its end in the airspace; the next burst checks against this one there.
		_claim = {}
		body.set_charge(0.0)
		body.clear_aim()


func _lock_aim(player: Player) -> void:
	var c: Vector3 = player.hurtbox_aabb().get_center()
	_lock = Vector2(c.x + rng.randf_range(-tuning.aim_error, tuning.aim_error), c.y)


## One bolt: aimed where the player will be when it arrives (on the locked line, or wild).
func _fire(player: Player) -> void:
	var c: Vector3 = player.hurtbox_aabb().get_center()
	var target := Vector3(_lock.x, _lock.y, c.z)
	if wild:
		target.x = c.x + rng.randf_range(-wild_spread, wild_spread)
		target.y = maxf(0.25, c.y + rng.randf_range(-0.45, 0.7))
	else:
		target.x += rng.randf_range(-tuning.shot_jitter, tuning.shot_jitter)
		target.y += rng.randf_range(-tuning.shot_jitter, tuning.shot_jitter) * 0.5
	var speed: float = bolt_speed()
	var v: float = player.speed
	var base: Vector3 = _muzzle_base()
	var t: float = intercept_time(base, target, v, speed)
	if t <= 0.0:
		return
	var aim: Vector3 = target + Vector3(0.0, 0.0, -v * t)
	var from: Vector3 = base + (aim - base).normalized() * muzzle_reach
	t = intercept_time(from, target, v, speed)
	if t <= 0.0:
		return
	aim = target + Vector3(0.0, 0.0, -v * t)
	var velocity: Vector3 = (aim - from).normalized() * speed
	world.projectiles.fire_enemy(from, velocity, LOOK, shot_name, tuning.bolt_life)
	world.play_sfx_at(shot_sound, from)
	if not _claim.is_empty():
		_airspace().arrives(_claim, world.level_time() + t)
	events.append({"t": world.level_time(), "event": &"shot", "impact": player.distance + v * t,
		"arrive": world.level_time() + t, "from": from, "velocity": velocity, "line": _lock.x, "wild": wild,
		"player_d": player.distance, "shooter_d": shooter.track_distance()})


## Whether a burst of `shots` bolts, the first fired `lead` seconds from now, would be fair: the first
## bolt gives at least min_warning_time and no bolt arrives near a fence or gap. Plans the burst as it
## goes: when its bolts arrive (_window) and how far the path around them reaches (_reach).
func _burst_fair(lead: float, shots: int) -> bool:
	var player: Player = world.player
	var v: float = player.speed
	var speed: float = bolt_speed()
	var c: Vector3 = player.hurtbox_aabb().get_center()
	var now: float = world.level_time()
	_window = Vector2(INF, -INF)
	_reach = player.distance
	for k: int in maxi(shots, 1):
		var tau: float = lead + k * tuning.shot_interval
		var from: Vector3 = _muzzle_base() + Vector3(0.0, 0.0, -track_velocity * tau)
		var target: Vector3 = c + Vector3(0.0, 0.0, -v * tau)
		var t: float = intercept_time(from, target, v, speed)
		if t <= 0.0:
			return false
		if k == 0 and t < tuning.min_warning_time:
			return false
		var impact: float = player.distance + v * (tau + t)
		if impact >= hold.x and impact <= hold.y:
			return false
		if not path_clear(impact - tuning.clear_before_impact * pace, impact + tuning.clear_after_impact * pace):
			return false
		_window = Vector2(minf(_window.x, now + tau + t), maxf(_window.y, now + tau + t))
		_reach = maxf(_reach, impact + tuning.clear_after_impact * pace)
	return true


## True if the player's path between two track distances has no live fence, no gap and no zone
## doodad in any lane (and, for a player on a wall, no sign on that wall). A shooter's own path_rule
## decides instead. The doodads: DESIGN-TBD (docs/questions/g5.md 5).
func path_clear(from_d: float, to_d: float) -> bool:
	if path_rule.is_valid():
		return bool(path_rule.call(from_d, to_d))
	var layout: LevelLayout = world.layout
	if layout.doodad_between(from_d, to_d):
		return false
	for f: Dictionary in layout.fences:
		var at: float = f["at"]
		if at >= from_d and at <= to_d and not f.get("disabled", false):
			return false
	for g: Dictionary in layout.gaps:
		if g["start"] <= to_d and g["end"] >= from_d:
			return false
	var player: Player = world.player
	if player.surface == Player.Surface.WALL:
		for s: Dictionary in layout.signs:
			if int(s["side"]) == player.wall_side and s["start"] <= to_d and s["end"] >= from_d:
				return false
	return true


## Seconds a bolt fired now would need to reach the player (-1 if it can't).
func _time_to_player(player: Player) -> float:
	return intercept_time(_muzzle_base(), player.hurtbox_aabb().get_center(), player.speed, bolt_speed())


## Points the body's cannon at the player while charging, then along the locked line while firing.
func _aim_body(player: Player) -> void:
	var c: Vector3 = player.hurtbox_aabb().get_center()
	var t: float = maxf(_time_to_player(player), 0.0)
	var aim := Vector3(c.x, c.y, c.z - player.speed * t)
	if state == State.FIRING and not wild:
		aim.x = _lock.x
		aim.y = _lock.y
	body.aim_at(aim)


func _muzzle_base() -> Vector3:
	return shooter.global_position + muzzle_offset


func _scaling() -> float:
	return world.config.enemy_scaling if world.config != null else 0.0
