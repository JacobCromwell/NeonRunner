class_name FloatingHeadBombing
extends Node3D
## The Floating Head's bombing run (GDD §10): "the ship flies in overhead and drops bombs toward the
## player for about 15-20 seconds. A searchlight sweeps the lanes and the bombs fall where it lingers,
## with a falling whistle, so the light is the visual warning."
## The light's spot hunts the runner on the floor ahead of them, about as far ahead as they will run
## while a bomb falls. Each round:
## 1. SWEEP_OUT: after a blast it swings away across the lanes (a seeded pick), then
## 2. SWEEP_IN: it sweeps back to the runner's lane and rests there a moment;
## 3. LOCK, the warning: it lingers on that spot of the track, turning red, with the framework's red
##    target circle (BossProps.circle_warning, so pickups keep off it), the lock sound, and a bomb
##    falling from the bay with its whistle, timed to end with the blast;
## 4. the blast: a hitbox and a fireball where the circle was, for BossProps-style blast_seconds, as the runner
##    would get there. Leaving the lane dodges it; it's too tall to jump.
## Every few locks (straddle_every) the light spreads over two lanes side by side: two bombs, and the
## free side is the way out. A player who keeps moving can always escape (the fairness rules below).
## Salvos (owner's request, October 9, 2026; task E1g; FloatingHeadTuning, group Salvos): in a phase
## whose run drops them (every run after the first), a lock marks 2-4 spots at once instead of one,
## each a block of lanes side by side. The nearest is where a single lock's would be, on the runner's
## lane; each next one lies salvo_spacing further along the track. Each spot is placed to leave the
## runner as few lanes to be in past it as it can, but never none (plan_salvo): on a narrow street
## (under salvo_wide_lanes) one or two bombs a spot and one lane left, a path the runner has to take;
## on a wide street up to three bombs and a choice of two lanes, so a runner can't step clear of the
## whole salvo (the owner's answers, the same day). Every spot's red circle shows at the lock, while
## the later spots' bombs are still in the bay: the runner sees the whole way through. The bombs leave
## the bay one spot after another, each falling for the warning's length, and blow up nearest first,
## each as the runner gets there; the light moves on to the next spot as each one blows. Fairness:
## every spot keeps a single lock's rules, and from one to the next the way through moves at most
## salvo_max_shift lanes, through lanes free of holes and fences (way_through). Every target circle
## keeps its red at any distance, out of the fog (the owner: a salvo's far spots the same colour as its
## near ones).
## Fairness: a lock happens only where the lanes it strikes are free of holes and fences around the
## blast (it lands on a roof), where a lane it doesn't strike lies at most max_escape_lanes away with
## it and every lane on the way free of holes and fences from the player to past the blast (the dodge is
## a plain lane switch), with no ceiling over it and no pickup waiting in it (the margins along the track
## at the run's pace, FloatingHead.metres: as long to run at any speed, GDD §3); the warning always lasts
## lock_seconds / pace. Otherwise the light keeps hunting. The blast's hitbox is about as big as
## its fireball and, in an outer lane, keeps clear of a wall runner beside it.
## Nothing depends on how long the fight has lasted: random picks come from the fight's seeded rng and
## time from the physics step, so every attempt plays out the same way for the same inputs.
## The run ends run_seconds after the light switches on; the last blast lands before it ends (a salvo
## that wouldn't is cut short, down to least_spots()).

enum Step { IDLE, SWEEP_OUT, SWEEP_IN, LOCK }

const BOMB_NAME: String = "Floating Head's bomb"
const LIGHT_WHITE := Color(0.85, 0.92, 1.0)
const LIGHT_RED := Color(1.0, 0.16, 0.1)
## Bombs and blasts kept ready (a whole salvo's: four spots of up to three bombs). Each blast's look is one of the
## shared fireballs (RunEffects.fireball, pooled there).
const POOL: int = 12
## How fast the spot catches up along the track after a blast, beyond the runner's own speed (at
## 18 m/s; at the run's pace, so it takes as long at any speed).
const CATCH_UP: float = 60.0
## The spot counts as on the runner's lane within this of its centre.
const ON_LANE: float = 0.2
## A blast's book is kept this long (its hitbox only blast_seconds; its fireball, RunEffects.fireball, is a quick one
## of about the same length: a look only).
const FIRE_SECONDS: float = 0.6
## The blast's look is one of the shared fireballs (GDD §11), held in so what burns is about what hurts (task H6's
## review: what looks like a hit must be a hit): as big as the blast's radius, flying out of its centre only this
## share as far as a free fireball's fire does, played this much faster than a fireball of its size would, with no
## smoke (it must not hide the lane the runner escapes into).
const FIRE_SIZE_PER_RADIUS: float = 1.0
const FIRE_SPREAD: float = 0.45
const FIRE_PACE: float = 2.0
## A straddle's second bomb leaves the bay this much later (it lands at the same time).
const SECOND_BOMB_DELAY: float = 0.07
## The falling whistle's length, if the sound library doesn't say.
const WHISTLE_SECONDS: float = 0.9
## No lock where a ceiling reaches within this far before the blast or this far after it (metres at
## 18 m/s, at the run's pace).
const CEILING_BEFORE: float = 8.0
const CEILING_AFTER: float = 4.0
## In a salvo the light moves sideways to the next spot this many times faster than it sweeps.
const SPOT_SWEEP: float = 3.0
## A runner is past a salvo's spot once its hurtbox is this far beyond the blast's far edge.
const PAST_MARGIN: float = 0.3

var head: FloatingHead
var tuning: FloatingHeadTuning
var world: RunWorld
var step: Step = Step.IDLE
var step_time: float = 0.0
## The run: whether its light is on, how long it lasts, and how long it has run.
var running: bool = false
var run_seconds: float = 0.0
var run_time: float = 0.0
## Seconds of bombing so far (bombs in the air and blasts keep to this clock).
var clock: float = 0.0
## Locks so far in this run (every straddle_every-th covers two lanes).
var locks: int = 0
## The light's spot: its world x and its track distance.
var spot_x: float = 0.0
var spot_d: float = 0.0
## The lock in progress: {lanes: Array[int], at, x, lock, impact} (clock times), or empty. A salvo's
## also holds its spots, {lanes, at, x, impact} each, the nearest first (its own lanes, at, x and
## impact are the nearest spot's).
var target: Dictionary = {}

## Bombs on their way: {lane, at, x, release, impact, whistle, released, whistled, circle, bomb, from}
## (a salvo's also spot_x, the middle of its spot).
var _drops: Array[Dictionary] = []
## Blasts burning: {hazard, x, at, start}.
var _blasts: Array[Dictionary] = []
var _out_lane: int = 0
## The spots the next salvo may have (a seeded pick each round; 0 outside salvo runs).
var _salvo: int = 0
var _settled: float = 0.0
## Seconds since the light began its sweep (it sweeps at least sweep_seconds between locks).
var _swept: float = 0.0
var _red: float = 0.0
var _light: float = 0.0
var _whistle: float = WHISTLE_SECONDS
var _beam: MeshInstance3D
var _spot: MeshInstance3D
var _beam_material: ShaderMaterial
var _spot_material: ShaderMaterial
## The target circles' look: BossProps.circle_warning's, out of the fog (made with the first circle).
var _circle_material: BaseMaterial3D
var _bombs: Array[MeshInstance3D] = []
var _hazards: Array[Hazard] = []

static var _cone: ArrayMesh
static var _quad: ArrayMesh


func setup(p_head: FloatingHead) -> void:
	head = p_head
	tuning = head.tuning
	world = head.world
	top_level = true
	transform = Transform3D.IDENTITY
	if world.sfx_library != null and world.sfx_library.stream(&"bomb_whistle") != null:
		_whistle = world.sfx_library.stream(&"bomb_whistle").get_length()
	var shader := load("res://scripts/bosses/floating_head/floating_head_light.gdshader") as Shader
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = shader
	_beam_material.set_shader_parameter(&"shape", 0)
	_spot_material = ShaderMaterial.new()
	_spot_material.shader = shader
	_spot_material.set_shader_parameter(&"shape", 1)
	_beam = _mesh_node(_cone_mesh(), _beam_material, "Beam")
	_spot = _mesh_node(_quad_mesh(), _spot_material, "Spot")
	_beam.visible = false
	_spot.visible = false
	for i: int in POOL:
		var bomb: MeshInstance3D = _mesh_node(FloatingHeadModel.bomb_mesh(), null, "Bomb")
		bomb.visible = false
		_bombs.append(bomb)
		_hazards.append(_make_hazard())


## Starts a run of `seconds`: the light switches on and starts sweeping, the bay opens.
func start(seconds: float) -> void:
	stop()
	running = true
	run_seconds = seconds
	run_time = 0.0
	locks = 0
	_light = 0.0
	spot_x = 0.0
	spot_d = world.player.distance + _lead()
	_out_lane = _pick_out_lane()
	_salvo = _pick_salvo()
	_set_step(Step.SWEEP_OUT)
	_swept = 0.0
	head.body.bay_open = true
	head.body.lamp = FloatingHeadBody.Lamp.SWEEP
	head.sound(&"searchlight_on", head.body.lamp_world())
	head.log_event(&"run_start", {"seconds": seconds})


## Ends the run now: the light goes off and bombs still in the air are gone (their circles too).
## Blasts already burning finish.
func stop() -> void:
	if running:
		head.log_event(&"run_end")
	running = false
	target = {}
	_set_step(Step.IDLE)
	for d: Dictionary in _drops:
		head.props.remove(d["circle"])
		if d["bomb"] != null:
			(d["bomb"] as Node3D).visible = false
	_drops.clear()
	if head.body != null and is_instance_valid(head.body):
		head.body.bay_open = false
		head.body.lamp = FloatingHeadBody.Lamp.OFF


## Everything off, blasts included (the fight is won).
func clear() -> void:
	stop()
	for b: Dictionary in _blasts:
		(b["hazard"] as Hazard).set_enabled(false)
	_blasts.clear()


## True once the run is over and its last bomb has landed.
func finished() -> bool:
	return not running and _drops.is_empty()


## True while a blast is burning.
func burning() -> bool:
	for b: Dictionary in _blasts:
		if (b["hazard"] as Hazard).is_active():
			return true
	return false


## The live blasts' hitboxes (tests).
func blast_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for b: Dictionary in _blasts:
		if (b["hazard"] as Hazard).is_active():
			out.append(b["hazard"])
	return out


## The spot's centre on the floor (world space).
func spot_world() -> Vector3:
	return Vector3(spot_x, 0.03, TrackGeometry.world_z(spot_d))


## One physics step of the run (FloatingHead's pattern calls it every frame of its fight).
func tick(delta: float) -> void:
	clock += delta
	_update_drops()
	_update_blasts()
	if running:
		run_time += delta
		step_time += delta
		_update_light(delta)
		if run_time >= run_seconds - 0.0001 and step != Step.LOCK:
			stop()
	_update_visuals(delta)


# --- The light ------------------------------------------------------------------------------

## The warning's length at this phase's pace.
func lock_time() -> float:
	return tuning.lock_seconds / head.pace()


## How far ahead of the runner the spot hunts: where they will be when a bomb it drops now goes off.
func _lead() -> float:
	return world.player.speed * (lock_time() + tuning.arrival_seconds)


func _update_light(delta: float) -> void:
	var geo: TrackGeometry = world.geo
	var ahead: float = world.player.distance + _lead()
	var sweep: float = tuning.sweep_speed * head.pace() * delta
	_swept += delta
	match step:
		Step.SWEEP_OUT, Step.SWEEP_IN:
			spot_d = move_toward(spot_d, ahead, (world.player.speed + head.metres(CATCH_UP)) * delta)
			var lane: int = _out_lane if step == Step.SWEEP_OUT else head.player_lane()
			spot_x = move_toward(spot_x, geo.lane_x(lane), sweep)
			if step == Step.SWEEP_OUT:
				if absf(spot_x - geo.lane_x(lane)) < 0.01:
					_set_step(Step.SWEEP_IN)
			else:
				var on_lane: bool = absf(spot_x - geo.lane_x(lane)) <= ON_LANE and absf(spot_d - ahead) < 0.5
				_settled = _settled + delta if on_lane else 0.0
				if _settled >= tuning.settle_seconds / head.pace() and _swept >= tuning.sweep_seconds / head.pace():
					_try_lock()
		Step.LOCK:
			# A salvo: the light rests on the next spot to blow, and moves on as each one does.
			var next: Dictionary = _next_spot()
			if not next.is_empty():
				spot_d = move_toward(spot_d, float(next["at"]), (world.player.speed + head.metres(CATCH_UP)) * delta)
				spot_x = move_toward(spot_x, float(next["x"]), sweep * SPOT_SWEEP)


## Locks on the runner's lane where the spot rests, if the rules allow it there now.
func _try_lock() -> void:
	if salvo_size() > 1:
		_try_salvo()
		return
	var lt: float = lock_time()
	if run_time + lt > run_seconds:
		return
	var pl: int = head.player_lane()
	var at: float = spot_d
	var lanes: Array[int] = plan(pl, at)
	if lanes.is_empty():
		return
	locks += 1
	var geo: TrackGeometry = world.geo
	var x: float = 0.0
	for l: int in lanes:
		x += geo.lane_x(l)
	x /= lanes.size()
	spot_x = x
	target = {"lanes": lanes, "at": at, "x": x, "lock": clock, "impact": clock + lt}
	for i: int in lanes.size():
		var lane: int = lanes[i]
		var impact: float = clock + lt
		_drops.append({"lane": lane, "at": at, "x": geo.lane_x(lane), "release": clock + i * SECOND_BOMB_DELAY,
			"impact": impact, "whistle": maxf(clock, impact - _whistle), "released": false, "whistled": false,
			"circle": _circle(at, lane), "bomb": null, "from": Vector3.ZERO})
	head.sound(&"searchlight_lock", spot_world())
	head.log_event(&"lock", {"lanes": lanes.duplicate(), "at": at, "player_lane": pl, "d0": world.player.distance,
		"warning": lt, "straddle": lanes.size() > 1})
	_set_step(Step.LOCK)


## The lanes a lock on `pl` at track distance `at` would strike now: two side by side on every
## straddle_every-th lock where both are fair, else the one, or none if even that isn't fair.
func plan(pl: int, at: float) -> Array[int]:
	var n: int = world.geo.lane_count
	if tuning.straddle_every > 0 and (locks + 1) % tuning.straddle_every == 0 and n >= 3:
		var sides: Array[int] = [-1, 1]
		if head.rng.randf() < 0.5:
			sides.reverse()
		for s: int in sides:
			var other: int = pl + s
			if other < 0 or other >= n:
				continue
			var pair: Array[int] = [mini(pl, other), maxi(pl, other)]
			if fair(pair, pl, at):
				return pair
	var single: Array[int] = [pl]
	if fair(single, pl, at):
		return single
	var none: Array[int] = []
	return none


## The fairness rules for bombs on `lanes` at `at` while the runner is in lane `pl` (see the header);
## their margins along the track at the run's pace (FloatingHead.metres: as long to run at any speed).
func fair(lanes: Array[int], pl: int, at: float) -> bool:
	for l: int in lanes:
		if not _clear(l, at - head.metres(tuning.clear_before_impact), at + head.metres(tuning.clear_after_impact)) \
				or _pickup_near(l, at):
			return false
	# No lock under a ceiling: the arena's, or the third stomp window's own (FloatingHead.ceiling_between).
	if head.ceiling_between(at - head.metres(CEILING_BEFORE), at + head.metres(CEILING_AFTER)):
		return false
	return escape_lane(lanes, pl, world.player.distance, at) >= 0


## The nearest lane a runner in `pl` at `d0` can switch to out of bombs on `lanes` at `at`: not struck,
## at most max_escape_lanes away, and it and every lane on the way free of holes and fences from `d0`
## to escape_clear_after past the blast (FloatingHead.escape_lane; at the run's pace). -1 if there is
## none.
func escape_lane(lanes: Array[int], pl: int, d0: float, at: float) -> int:
	return head.escape_lane(lanes, pl, d0, at + head.metres(tuning.escape_clear_after))


func _clear(lane: int, from: float, to: float) -> bool:
	return head.floor_clear_lane(lane, from, to)


func _pickup_near(lane: int, at: float) -> bool:
	return head.pickup_near(lane, at, tuning.pickup_margin)


## After a blast the light swings away across the lanes before it hunts again: a seeded pick among
## the lanes 1 to sweep_out_lanes from the runner's.
func _pick_out_lane() -> int:
	var pl: int = head.player_lane()
	var choices: Array[int] = []
	for l: int in world.geo.lane_count:
		var d: int = absi(l - pl)
		if d >= 1 and d <= tuning.sweep_out_lanes:
			choices.append(l)
	if choices.is_empty():
		return pl
	return choices[head.rng.randi() % choices.size()]


func _set_step(next: Step) -> void:
	step = next
	step_time = 0.0
	_settled = 0.0


# --- Salvos ------------------------------------------------------------------------------------

## The most spots one of this phase's salvos may have (1: one spot at a time, as in the first run).
func salvo_size() -> int:
	return tuning.salvo_spots_in(head.phase_index)


## Seconds from one spot's blast to the next one's in a salvo: salvo_spacing at the run's speed (as
## long at any speed, and the phase's pace doesn't shorten it: the runner switches lanes no faster).
func spot_gap_time() -> float:
	return head.metres(tuning.salvo_spacing) / maxf(world.player.speed, 0.1)


## The fewest spots one of this phase's salvos may have: salvo_min_spots, or salvo_size() if smaller.
func least_spots() -> int:
	return mini(tuning.salvo_min_spots, salvo_size())


## The spots the next salvo may have: a seeded pick from least_spots() to salvo_size() (0 when this
## phase's run drops no salvos, and then no pick is made).
func _pick_salvo() -> int:
	var most: int = salvo_size()
	if most <= 1:
		return 0
	var least: int = least_spots()
	return least + head.rng.randi() % (most - least + 1)


## Locks a salvo on the runner's lane where the spot rests, if the rules allow one there now: as many
## of its spots as land before the run ends, least_spots() at least.
func _try_salvo() -> void:
	var lt: float = lock_time()
	var gap: float = spot_gap_time()
	var fit: int = floori((run_seconds - run_time - lt) / gap + 0.0001) + 1
	var most: int = mini(_salvo, fit)
	if most < least_spots():
		return
	var pl: int = head.player_lane()
	var spots: Array[Dictionary] = plan_salvo(pl, spot_d, most)
	if spots.is_empty():
		return
	locks += 1
	var geo: TrackGeometry = world.geo
	var logged: Array[Dictionary] = []
	for i: int in spots.size():
		var spot: Dictionary = spots[i]
		var lanes: Array[int] = spot["lanes"]
		var at: float = spot["at"]
		var x: float = 0.0
		for l: int in lanes:
			x += geo.lane_x(l)
		x /= lanes.size()
		var impact: float = clock + lt + i * gap
		spot["x"] = x
		spot["impact"] = impact
		# Its bombs leave the bay one spot after another, each falling for the warning's length; every
		# circle shows now.
		for j: int in lanes.size():
			var lane: int = lanes[j]
			_drops.append({"lane": lane, "at": at, "x": geo.lane_x(lane), "spot_x": x,
				"release": impact - lt + j * SECOND_BOMB_DELAY, "impact": impact,
				"whistle": maxf(clock, impact - _whistle), "released": false, "whistled": false,
				"circle": _circle(at, lane), "bomb": null, "from": Vector3.ZERO})
		logged.append({"lanes": lanes.duplicate(), "at": at, "warning": impact - clock})
	var first: Dictionary = spots[0]
	spot_x = float(first["x"])
	target = {"lanes": first["lanes"], "at": first["at"], "x": first["x"], "lock": clock, "impact": first["impact"],
		"spots": spots}
	head.sound(&"searchlight_lock", spot_world())
	var first_lanes: Array[int] = first["lanes"]
	head.log_event(&"lock", {"lanes": first_lanes.duplicate(), "at": first["at"], "player_lane": pl,
		"d0": world.player.distance, "warning": lt, "straddle": first_lanes.size() > 1, "spots": logged})
	_set_step(Step.LOCK)


## True if salvos here keep a wide street's rules (salvo_wide_lanes lanes or more).
func wide_street() -> bool:
	return world.geo.lane_count >= tuning.salvo_wide_lanes


## The most bombs side by side in one spot here: salvo_wide_bombs on a wide street, else salvo_bombs.
func spot_bombs() -> int:
	return tuning.salvo_wide_bombs if wide_street() else tuning.salvo_bombs


## The fewest lanes a spot here leaves the runner to be in, where it can: salvo_wide_choices on a wide
## street (a choice of two), else salvo_choices (one: a path they have to take).
func spot_choices() -> int:
	return maxi(tuning.salvo_wide_choices if wide_street() else tuning.salvo_choices, 1)


## A salvo for a runner in lane `pl`, its nearest spot at track distance `at`: up to `most` spots,
## {lanes: Array[int], at} each, the nearest first, or none if fewer than least_spots() are fair now.
## It follows the lanes a runner keeping the rules could be in past each spot (from every lane they
## could be in at the spot before; their own lane before the first), and makes each spot the block of up
## to spot_bombs() lanes side by side, on clear roof with no pickup, that leaves them the fewest, but no
## fewer than spot_choices() where it can and never none (the owner, October 9, 2026: a path to take on
## a narrow street, a choice of two lanes on a wide one). The first spot's block holds the runner's
## lane; each later one strikes at least one lane they could be in. Ties go to striking a lane they could
## have stayed in since the first spot (so none is left that clears the whole salvo), then more of the
## lanes they could be in, then to leaving lanes that lie together, then to fewer bombs, then to a
## seeded pick. A salvo whose next spot can't be fair ends there.
func plan_salvo(pl: int, at: float, most: int) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var gap: float = head.metres(tuning.salvo_spacing)
	var n: int = world.geo.lane_count
	var choices: int = spot_choices()
	var could: Array[int] = [pl]
	# The lanes a runner could have stayed in since the first spot, never struck.
	var stay: Array[int] = []
	var from: float = world.player.distance
	for k: int in most:
		var spot_at: float = at + k * gap
		if head.ceiling_between(spot_at - head.metres(CEILING_BEFORE), spot_at + head.metres(CEILING_AFTER)):
			break
		var open: Array[bool] = _open_lanes(from, spot_at + head.metres(tuning.escape_clear_after))
		var roof: Array[bool] = []
		for l: int in n:
			roof.append(_clear(l, spot_at - head.metres(tuning.clear_before_impact),
				spot_at + head.metres(tuning.clear_after_impact)) and not _pickup_near(l, spot_at))
		var best: Array = []
		var picks: Array = []
		for width: int in range(1, spot_bombs() + 1):
			for low: int in range(0, n - width + 1):
				var block: Array[int] = []
				var on_roof: bool = true
				for l: int in range(low, low + width):
					block.append(l)
					on_roof = on_roof and roof[l]
				if not on_roof or (k == 0 and not block.has(pl)):
					continue
				var struck: int = 0
				for l: int in could:
					if block.has(l):
						struck += 1
				if struck == 0:
					continue
				var left: Array[int] = _reach(could, block, pl, open, k == 0)
				if left.is_empty():
					continue
				var stayed: int = 0
				for l: int in stay:
					if block.has(l):
						stayed += 1
				var enough: bool = left.size() >= choices
				var key: Array = [0 if enough else 1, left.size() if enough else -left.size(), -stayed, -struck,
					left[-1] - left[0], width]
				var order: int = _compare(key, best)
				if order < 0:
					best = key
					picks = [[block, left]]
				elif order == 0:
					picks.append([block, left])
		if picks.is_empty():
			break
		var pick: Array = picks[head.rng.randi() % picks.size()]
		var lanes: Array[int] = pick[0]
		spots.append({"lanes": lanes, "at": spot_at})
		could = pick[1]
		if k == 0:
			stay = could.duplicate()
		else:
			for l: int in lanes:
				stay.erase(l)
		from = spot_at
	if spots.size() < least_spots():
		spots.clear()
	return spots


## -1, 0 or 1 as `a` sorts before, with or after `b`, element by element (an empty `b` sorts last).
static func _compare(a: Array, b: Array) -> int:
	if b.is_empty():
		return -1
	for i: int in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return -1 if a[i] < b[i] else 1
	return 0


## For each lane, true if its floor is free of holes and fences between two track distances.
func _open_lanes(from: float, to: float) -> Array[bool]:
	var out: Array[bool] = []
	for l: int in world.geo.lane_count:
		out.append(_clear(l, from, to))
	return out


## The lanes a runner could be in past a spot striking `lanes`, from any of `starts`: not struck, at
## most max_escape_lanes from where they are for the `first` spot and salvo_max_shift for the rest,
## with every lane on the way `open` (the runner's own lane `pl` is theirs to run before the first).
func _reach(starts: Array[int], lanes: Array[int], pl: int, open: Array[bool], first: bool) -> Array[int]:
	var reach: int = tuning.max_escape_lanes if first else tuning.salvo_max_shift
	var n: int = world.geo.lane_count
	var out: Array[int] = []
	for r: int in starts:
		for e: int in range(maxi(r - reach, 0), mini(r + reach, n - 1) + 1):
			if not lanes.has(e) and not out.has(e) and _crossing_open(r, e, pl, open, first):
				out.append(e)
	out.sort()
	return out


## True if every lane from `r` to `e` is `open` (but the runner's own lane `pl` before the first spot).
func _crossing_open(r: int, e: int, pl: int, open: Array[bool], first: bool) -> bool:
	for l: int in range(mini(r, e), maxi(r, e) + 1):
		if (l != pl or not first) and not open[l]:
			return false
	return true


## A way through `spots` (a salvo's, {lanes, at} each, the nearest first) for a runner in `pl` at
## `d0`: the lane to be in at each spot, with as few lane switches as can be, or empty if there is none.
## It keeps the salvo's rules: from the runner to the first spot it moves at most max_escape_lanes and
## from one spot to the next at most salvo_max_shift, through lanes free of holes and fences from where
## it sets off (the runner's spot, or the spot before) to escape_clear_after past the spot (the
## runner's own lane is theirs to run, as for any lock).
func way_through(spots: Array, pl: int, d0: float) -> Array[int]:
	var way: Array[int] = []
	var n: int = world.geo.lane_count
	var cost: Dictionary = {pl: 0}
	var back: Array[Dictionary] = []
	var from: float = d0
	for k: int in spots.size():
		var lanes: Array = spots[k]["lanes"]
		var at: float = float(spots[k]["at"])
		var open: Array[bool] = _open_lanes(from, at + head.metres(tuning.escape_clear_after))
		var reach: int = tuning.max_escape_lanes if k == 0 else tuning.salvo_max_shift
		var next: Dictionary = {}
		var prev: Dictionary = {}
		var starts: Array = cost.keys()
		starts.sort()
		for r: int in starts:
			for e: int in range(maxi(r - reach, 0), mini(r + reach, n - 1) + 1):
				var c: int = int(cost[r]) + absi(e - r)
				if lanes.has(e) or (next.has(e) and int(next[e]) <= c):
					continue
				if _crossing_open(r, e, pl, open, k == 0):
					next[e] = c
					prev[e] = r
		if next.is_empty():
			return way
		cost = next
		back.append(prev)
		from = at
	# The cheapest lane at the last spot (the nearest the runner's on a tie), then back to the first.
	var best: int = -1
	for e: int in cost:
		if best < 0 or int(cost[e]) < int(cost[best]) or (int(cost[e]) == int(cost[best])
				and (absi(e - pl) < absi(best - pl) or (absi(e - pl) == absi(best - pl) and e < best))):
			best = e
	way.resize(spots.size())
	var lane: int = best
	for k: int in range(spots.size() - 1, -1, -1):
		way[k] = lane
		lane = int(back[k][lane])
	return way


## The salvo's spots a runner at track distance `d0` hasn't run past yet (the nearest first; none
## outside a salvo).
func spots_ahead(d0: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not target.has("spots"):
		return out
	var past: float = tuning.blast_depth * 0.5 + world.tuning.hurtbox_size.z * 0.5 + PAST_MARGIN
	for spot: Dictionary in target["spots"]:
		if float(spot["at"]) + past > d0:
			out.append(spot)
	return out


## Where a runner in lane `pl` at `d0` should be for the next salvo spot ahead of them, on a way
## through the rest (way_through): -1 outside a salvo, past its last spot or with no way through.
func dodge_lane(pl: int, d0: float) -> int:
	var ahead: Array[Dictionary] = spots_ahead(d0)
	if ahead.is_empty():
		return -1
	var way: Array[int] = way_through(ahead, pl, d0)
	return way[0] if not way.is_empty() else -1


## A bomb's red target circle on `lane` at `at` (BossProps.circle_warning, so pickups keep off it), the
## same red at any distance.
func _circle(at: float, lane: int) -> MeshInstance3D:
	var circle: MeshInstance3D = head.props.circle_warning(at, lane, tuning.blast_radius)
	if _circle_material == null and circle.material_override is BaseMaterial3D:
		_circle_material = circle.material_override.duplicate() as BaseMaterial3D
		_circle_material.disable_fog = true
	if _circle_material != null:
		circle.material_override = _circle_material
	return circle


## The salvo's next spot to blow (none outside a salvo, or once its last has blown).
func _next_spot() -> Dictionary:
	if not target.has("spots"):
		return {}
	for spot: Dictionary in target["spots"]:
		if float(spot["impact"]) > clock + 0.0001:
			return spot
	return {}


# --- Bombs and blasts ---------------------------------------------------------------------------

func _update_drops() -> void:
	for i: int in range(_drops.size() - 1, -1, -1):
		var d: Dictionary = _drops[i]
		if not d["released"] and clock >= float(d["release"]):
			d["released"] = true
			d["bomb"] = _free_bomb()
			var mid: float = float(d.get("spot_x", target.get("x", d["x"])))
			d["from"] = head.body.bay_world() + Vector3((float(d["x"]) - mid) * 0.4, 0.0, 0.0)
		if not d["whistled"] and clock >= float(d["whistle"]):
			d["whistled"] = true
			head.sound(&"bomb_whistle", Vector3(float(d["x"]), 1.0, TrackGeometry.world_z(float(d["at"]))))
		var bomb: MeshInstance3D = d["bomb"]
		if bomb != null:
			_place_bomb(bomb, d)
		if clock >= float(d["impact"]) - 0.0001:
			if bomb != null:
				bomb.visible = false
			head.props.remove(d["circle"])
			_drops.remove_at(i)
			_blast(int(d["lane"]), float(d["at"]))
	if step == Step.LOCK and _drops.is_empty():
		target = {}
		_out_lane = _pick_out_lane()
		_salvo = _pick_salvo()
		_set_step(Step.SWEEP_OUT)
		_swept = 0.0


## A bomb on its way down: from the bay to the target circle, falling ever faster, nose first.
func _place_bomb(bomb: MeshInstance3D, d: Dictionary) -> void:
	var t0: float = float(d["release"])
	var s: float = clampf((clock - t0) / maxf(float(d["impact"]) - t0, 0.01), 0.0, 1.0)
	var from: Vector3 = d["from"]
	var to := Vector3(float(d["x"]), 0.25, TrackGeometry.world_z(float(d["at"])))
	var pos := Vector3(lerpf(from.x, to.x, s), lerpf(from.y, to.y, s * s), lerpf(from.z, to.z, s))
	var vel := Vector3(to.x - from.x, 2.0 * s * (to.y - from.y) - 0.5, to.z - from.z)
	bomb.visible = true
	bomb.global_position = pos
	if vel.length() > 0.01:
		var up: Vector3 = Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.BACK
		bomb.look_at(pos + vel, up)


## The blast: its hitbox burns for blast_seconds; the fireball (RunEffects.fireball: a look only), the boom and a shake.
func _blast(lane: int, at: float) -> void:
	var geo: TrackGeometry = world.geo
	var half: float = geo.lane_width * tuning.blast_width_share * 0.5
	var x: float = geo.lane_x(lane)
	# A wall runner's body reaches this far in from the wall's face: the blast keeps clear of it.
	var reach: float = geo.wall_x() - world.tuning.hurtbox_size.y - 0.05
	var x0: float = maxf(x - half, -reach)
	var x1: float = minf(x + half, reach)
	var hazard: Hazard = _free_hazard()
	var size := Vector3(x1 - x0, tuning.blast_height, tuning.blast_depth)
	hazard.size = size
	((hazard.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
	hazard.global_position = Vector3((x0 + x1) * 0.5, size.y * 0.5, TrackGeometry.world_z(at))
	hazard.set_enabled(true)
	_blasts.append({"hazard": hazard, "x": x, "at": at, "start": clock})
	var center := Vector3(x, 0.8, TrackGeometry.world_z(at))
	world.effects.fireball(center + Vector3(0.0, 0.3, 0.0), tuning.blast_radius * FIRE_SIZE_PER_RADIUS, false, FIRE_PACE, FIRE_SPREAD)
	var near: float = clampf(1.0 - (at - world.player.distance) / 40.0, 0.2, 1.0)
	world.effects.shake(0.3 * near, 0.3)
	head.sound(&"bomb_blast", center)
	head.log_event(&"blast", {"lane": lane, "at": at})


func _update_blasts() -> void:
	for i: int in range(_blasts.size() - 1, -1, -1):
		var b: Dictionary = _blasts[i]
		var age: float = clock - float(b["start"])
		var hazard: Hazard = b["hazard"]
		if hazard.is_active() and age >= tuning.blast_seconds - 0.0001:
			hazard.set_enabled(false)
		if age >= FIRE_SECONDS and not hazard.is_active():
			_blasts.remove_at(i)


# --- Visuals ------------------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	var lit: bool = running or step == Step.LOCK
	_light = move_toward(_light, 1.0 if lit else 0.0, delta / 0.25)
	_red = move_toward(_red, 1.0 if step == Step.LOCK else 0.0, delta / 0.12)
	var body: FloatingHeadBody = head.body
	if body == null or not is_instance_valid(body):
		_beam.visible = false
		_spot.visible = false
		return
	body.lamp = FloatingHeadBody.Lamp.OFF if not lit else (FloatingHeadBody.Lamp.LOCK if step == Step.LOCK
		else FloatingHeadBody.Lamp.SWEEP)
	var spot: Vector3 = spot_world()
	body.lamp_target = spot
	_beam.visible = _light > 0.0
	_spot.visible = _light > 0.0
	if _light <= 0.0:
		return
	var color: Color = LIGHT_WHITE.lerp(LIGHT_RED, _red)
	# The spot: a lane wide while it sweeps, tighter once it lingers, over every lane a lock strikes;
	# the light falls through a hole in the floor instead of lighting it.
	var rx: float = tuning.spot_radius
	var rz: float = tuning.spot_radius
	if not target.is_empty():
		var lanes: Array = target["lanes"]
		var next: Dictionary = _next_spot()
		if not next.is_empty():
			lanes = next["lanes"]
		rx = tuning.blast_radius * 1.2 + world.geo.lane_width * 0.5 * (lanes.size() - 1)
		rz = tuning.blast_radius * 1.3
	var over_hole: bool = target.is_empty() and head.arena != null \
		and head.arena.hole_between(spot_d - 0.4, spot_d + 0.4, _nearest_lane(spot_x))
	_spot.global_transform = Transform3D(Basis.from_scale(Vector3(rx, 1.0, rz)), spot)
	_spot_material.set_shader_parameter(&"light_color", color)
	_spot_material.set_shader_parameter(&"strength", (0.0 if over_hole else 1.6) * _light)
	var from: Vector3 = body.lamp_world()
	var dir: Vector3 = spot - from
	var length: float = dir.length()
	if length > 0.5:
		var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.BACK
		var r: float = maxf(rx, rz) * 0.85
		_beam.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(r, r, length)), from)
	_beam_material.set_shader_parameter(&"light_color", color)
	_beam_material.set_shader_parameter(&"strength", (1.0 + 0.4 * _red) * _light)


func _nearest_lane(x: float) -> int:
	var geo: TrackGeometry = world.geo
	return clampi(roundi(x / geo.lane_width + (geo.lane_count - 1) * 0.5), 0, geo.lane_count - 1)


# --- Pools and meshes ---------------------------------------------------------------------------

func _free_bomb() -> MeshInstance3D:
	for b: MeshInstance3D in _bombs:
		if not b.visible:
			return b
	var extra: MeshInstance3D = _mesh_node(FloatingHeadModel.bomb_mesh(), null, "Bomb")
	_bombs.append(extra)
	return extra


func _free_hazard() -> Hazard:
	for h: Hazard in _hazards:
		if not h.is_active() and not _burning(h):
			return h
	var extra: Hazard = _make_hazard()
	_hazards.append(extra)
	return extra


func _burning(h: Hazard) -> bool:
	for b: Dictionary in _blasts:
		if b["hazard"] == h:
			return true
	return false


func _make_hazard() -> Hazard:
	var hazard := Hazard.new()
	hazard.name = "Blast"
	hazard.hazard_name = BOMB_NAME
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
	return hazard


func _mesh_node(mesh: Mesh, material: Material, node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## The beam: an open cone along -z from radius 0.3 at the lamp (z = 0) to 1 at the floor (z = -1),
## with normals for its soft edges and UV.y running along it.
static func _cone_mesh() -> ArrayMesh:
	if _cone != null:
		return _cone
	var sides: int = 16
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in sides:
		var a0: float = TAU * i / sides
		var a1: float = TAU * (i + 1) / sides
		var n0 := Vector3(cos(a0), sin(a0), 0.0)
		var n1 := Vector3(cos(a1), sin(a1), 0.0)
		var p00: Vector3 = n0 * 0.3
		var p01: Vector3 = n1 * 0.3
		var p10: Vector3 = n0 + Vector3(0, 0, -1)
		var p11: Vector3 = n1 + Vector3(0, 0, -1)
		verts.append_array(PackedVector3Array([p00, p10, p11, p00, p11, p01]))
		normals.append_array(PackedVector3Array([n0, n0, n1, n0, n1, n1]))
		uvs.append_array(PackedVector2Array([Vector2(float(i) / sides, 0), Vector2(float(i) / sides, 1),
			Vector2(float(i + 1) / sides, 1), Vector2(float(i) / sides, 0), Vector2(float(i + 1) / sides, 1),
			Vector2(float(i + 1) / sides, 0)]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_cone = ArrayMesh.new()
	_cone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _cone


## The spot: a flat square from -1 to 1 on the floor, facing up, UV 0-1 over it.
static func _quad_mesh() -> ArrayMesh:
	if _quad != null:
		return _quad
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, 0, 1), Vector3(-1, 0, -1), Vector3(1, 0, -1),
		Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(1, 0, 1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 0),
		Vector2(1, 1), Vector2(1, 0)])
	_quad = ArrayMesh.new()
	_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _quad
