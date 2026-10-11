class_name MechaGuppyBombs
extends Node3D
## Captain Cogs' bombs (GDD §10: "The bombs are warned like the Floating Head's (a red target circle where each will
## land, and a falling whistle), in a pirate look"; "a runner on a ceiling with the ceiling between them and a bomb
## isn't hurt by it"; "Hurting Mecha Guppy: dodging the bombs. Not every miss hurts it: only a bomb that falls through a
## gap, off a roof's edge, or into a stretch it has eaten through, where it is clearly exposed and in the line of fire";
## task E5e-b2). The captain throws them from his ship (CaptainCogsShip) on a lob to where they land; each bomb's red
## target circle shows from the throw (BossProps.circle_warning at the height it lands at, the same red at any
## distance, out of the fog: the Floating Head's), the throw is heard (cogs_throw) and the bomb whistles as it falls
## (bomb_whistle, timed to end as it lands), lock_seconds from the throw to the landing. Where a bomb comes down:
## - on a roof: it bursts there, a blast too tall to jump for blast_seconds (an enemy attack's hitbox a little smaller
##   than its fireball, on that roof's top: real contact only; armor, the shield and the dash as for any boss bomb). A
##   miss that doesn't hurt the shark;
## - on a hut: it bursts on the hut's top; the rider hanging under it is never touched (the blast is all above the hut);
## - where there's no floor (past a roof's edge, through a gap beside a pier, into the chasm the shark has eaten): it
##   falls on, and if Mecha Guppy's open jaws are there (MechaGuppyShark.mouth_contains), into them: a hit
##   (MechaGuppy.register_hit; the clang, a fireball, sparks and smoke). Otherwise it falls away into the haze.
## What it throws, and when, is MechaGuppyPattern's. The spots a runner must dodge (a volley: throw_spots) are planned
## here by the Floating Head's salvo rules on the climb's roofs (plan_spots): every spot leaves the runner a lane to be
## in, reached from where they first can switch (on the floor over every lane crossed, never off a pier's side into the
## chasm, never on a hut) with dodge_reaction and every switch plus dodge_margin to spare; a spot is never under or near
## a hut (the hut would take the bomb) nor on a pickup. way_through and dodge_lane give a way through a volley (the
## tests' runner, MechaGuppyBot, and the showcase use them).
## Nothing depends on how long the fight has lasted: picks come from seeds of the fight and the step, time from the
## physics step (tick: the boss's pattern drives it), so every attempt plays out the same way for the same inputs.
## DESIGN-TBD (docs/questions/e5e.md): the bombs' look (a round black iron bomb with a brass cog band and a lit fuse),
## the volleys and what counts as a hit (MechaGuppyTuning, "Captain Cogs' bombs").

enum Kind { SPOT, HUT, HIT, TEST }
enum Lands { ROOF, HUT, CHASM }

const BOMB_NAME: String = "Captain Cogs' bomb"
## Bombs kept ready (a volley's: two spots of up to three bombs, plus a hut's and a hit's). Each blast's look is one of
## the shared fireballs (RunEffects.fireball, pooled there).
const POOL: int = 10
## A blast's book is kept this long (its hitbox only blast_seconds).
const FIRE_SECONDS: float = 0.6
## The blast's look (the Floating Head's): a fireball as big as its radius, held in, quick, no smoke (it must not hide
## the lane the runner escapes into).
const FIRE_SIZE_PER_RADIUS: float = 1.0
const FIRE_SPREAD: float = 0.45
const FIRE_PACE: float = 2.0
## The falling whistle's length, if the sound library doesn't say.
const WHISTLE_SECONDS: float = 0.9
## The lob's height over the straight line from the captain's hand to where it lands (metres, at its middle).
const LOB: float = 3.5
## A bomb that finds no floor falls on this long, ever faster, before it's gone (seconds), at this pull.
const FALL_ON: float = 1.4
const FALL_PULL: float = 30.0
## A spot's blast lands on floor this far beyond its depth either way, and no hut reaches within HUT_CLEAR of it
## (metres).
const FLOOR_CLEAR: float = 0.5
const HUT_CLEAR: float = 2.0
## A spot's escape lanes stay open this far past it (metres at 18 m/s, at the run's pace).
const ESCAPE_AFTER: float = 3.0
## A runner is past a spot once its hurtbox is this far beyond the blast's far edge.
const PAST_MARGIN: float = 0.3
## The fuse's spark: its colour (warm, never a hazard colour), its flicker (steady with Reduced flashing).
const FUSE_COLOR := Color(1.0, 0.86, 0.5)
const FUSE_HZ: float = 13.0

var boss: MechaGuppy
var tuning: MechaGuppyTuning
var world: RunWorld
## Seconds of bombing so far (bombs in the air and blasts keep to this clock).
var clock: float = 0.0
## Volleys thrown whose spots may still lie ahead: {kind, step, spots: [{lanes, at, y, impact}], s_open, lock}.
var volleys: Array[Dictionary] = []
## What happened to the bombs (tests): thrown, roof (burst on a roof), hut (on a hut's top), chasm (fell away), hit
## (into the shark), and the volleys' spots.
var stats: Dictionary = {"thrown": 0, "roof": 0, "hut": 0, "chasm": 0, "hit": 0, "spots": 0, "volleys": 0}

## Bombs on their way: {kind, lane, x, at, y, release, impact, whistle, released, whistled, landed, circle, bomb,
## from, to, fall (seconds falling on past the floor's level)}.
var _drops: Array[Dictionary] = []
## Blasts burning: {hazard, start}.
var _blasts: Array[Dictionary] = []
var _whistle: float = WHISTLE_SECONDS
var _circle_material: BaseMaterial3D
var _bombs: Array[Node3D] = []
var _hazards: Array[Hazard] = []
var _rng := RandomNumberGenerator.new()

## The bomb's body per material (bomb_mesh).
static var _bomb_meshes: Dictionary = {}


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	tuning = boss.tuning
	world = boss.world
	top_level = true
	transform = Transform3D.IDENTITY
	if world.sfx_library != null and world.sfx_library.stream(&"bomb_whistle") != null:
		_whistle = world.sfx_library.stream(&"bomb_whistle").get_length()
	for i: int in POOL:
		_bombs.append(_new_bomb())
		_hazards.append(_make_hazard())


## Everything off: bombs in the air and their circles gone, blasts out (the fight is won).
func clear() -> void:
	for d: Dictionary in _drops:
		boss.props.remove(d.get("circle"))
		if d["bomb"] != null:
			(d["bomb"] as Node3D).visible = false
	_drops.clear()
	for b: Dictionary in _blasts:
		(b["hazard"] as Hazard).set_enabled(false)
	_blasts.clear()
	volleys.clear()


## Bombs still on their way down.
func in_air() -> int:
	return _drops.size()


## The live blasts' hitboxes (tests).
func blast_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for b: Dictionary in _blasts:
		if (b["hazard"] as Hazard).is_active():
			out.append(b["hazard"])
	return out


## The bombs on their way down (tests: {kind, lane, x, at, y, impact, circle, ...}).
func drops() -> Array[Dictionary]:
	return _drops


## One physics step (MechaGuppy's pattern drives it, so it waits while the runner is down).
func tick(delta: float) -> void:
	clock += delta
	_update_drops(delta)
	_update_blasts()
	_prune_volleys()


# --- Throwing -------------------------------------------------------------------------------------

## The warning's length.
func lock_time() -> float:
	return tuning.lock_seconds


## Throws a volley at the runner's path (MechaGuppyPattern): `spots` [{lanes: Array[int], at, y}], nearest first, each
## landing as a runner at the run's speed gets there (arrival_seconds before they reach its middle); `s_open`, where the
## runner can first switch lanes to dodge it (way_through). Every circle shows now, the throw is heard; each spot's
## bombs leave the captain's hand lock_seconds before they land.
func throw_spots(kind: int, step: int, spots: Array[Dictionary], s_open: float) -> void:
	if spots.is_empty():
		return
	var p: Player = world.player
	var speed: float = maxf(p.speed, 1.0)
	var logged: Array[Dictionary] = []
	for spot: Dictionary in spots:
		var at: float = float(spot["at"])
		var impact: float = clock + maxf((at - p.distance) / speed - tuning.arrival_seconds, lock_time())
		spot["impact"] = impact
		for lane: int in spot["lanes"]:
			_add(kind, lane, at, float(spot["y"]), impact)
		logged.append({"lanes": (spot["lanes"] as Array).duplicate(), "at": at, "y": float(spot["y"]), "warning": impact - clock})
	volleys.append({"kind": kind, "step": step, "spots": spots, "s_open": s_open, "lock": clock})
	stats["volleys"] = int(stats["volleys"]) + 1
	stats["spots"] = int(stats["spots"]) + spots.size()
	boss.sound(&"cogs_throw", _hand())
	boss.log_event(&"volley", {"kind": kind, "step": step, "spots": logged, "lane": p.lane, "d0": p.distance,
		"s_open": s_open})


## Throws one bomb to land at track distance `at` over `lane` (x offset `x` from its middle), coming down to world
## height `y`, `flight` seconds from now (lock_seconds by default; a hit's, which threatens nobody, hit_seconds) (a hut's,
## a hit's, a review's or a test's: `kind`). It shows its circle there (none for a bomb on a hut's top: nobody can stand
## there, and a rider under it can't see it). Returns its record.
func throw_at(kind: int, lane: int, at: float, y: float, x: float = 0.0, flight: float = -1.0) -> Dictionary:
	var seconds: float = flight if flight > 0.0 else lock_time()
	var d: Dictionary = _add(kind, lane, at, y, clock + seconds, x, seconds)
	boss.sound(&"cogs_throw", _hand())
	boss.log_event(&"throw", {"kind": kind, "lane": lane, "at": at, "y": y, "x": x})
	return d


func _add(kind: int, lane: int, at: float, y: float, impact: float, x: float = 0.0, flight: float = -1.0) -> Dictionary:
	var circle: MeshInstance3D = null
	if kind != Kind.HUT:
		circle = _circle(at, lane, x, y)
	var seconds: float = flight if flight > 0.0 else lock_time()
	var d := {"kind": kind, "lane": lane, "x": world.geo.lane_x(lane) + x, "at": at, "y": y,
		"release": impact - seconds, "impact": impact, "whistle": maxf(clock, impact - _whistle), "released": false,
		"whistled": false, "landed": false, "circle": circle, "bomb": null, "from": Vector3.ZERO, "fall": 0.0,
		"lands": -1}
	_drops.append(d)
	stats["thrown"] = int(stats["thrown"]) + 1
	return d


## Where the captain's hand is (the throw's start), or a point high ahead of the runner without the ship.
func _hand() -> Vector3:
	if boss.ship != null and is_instance_valid(boss.ship):
		return boss.ship.hand_world()
	var p: Player = world.player
	return Vector3(0.0, p.floor_base + tuning.ship_height, TrackGeometry.world_z(p.distance + tuning.ship_ahead))


## A bomb's red target circle over `lane` at `at` (x offset `x`), at world height `y` (BossProps.circle_warning: pickups
## keep off it), the same red at any distance (a fog-free copy of its material, the Floating Head's).
func _circle(at: float, lane: int, x: float, y: float) -> MeshInstance3D:
	var circle: MeshInstance3D = boss.props.circle_warning(at, lane, tuning.blast_radius, x, y)
	if _circle_material == null and circle.material_override is BaseMaterial3D:
		_circle_material = circle.material_override.duplicate() as BaseMaterial3D
		_circle_material.disable_fog = true
	if _circle_material != null:
		circle.material_override = _circle_material
	return circle


# --- The spots' rules -------------------------------------------------------------------------------

## The most bombs side by side in a spot of phase `phase` here, and the fewest lanes it leaves where it can.
func spot_bombs(phase: int) -> int:
	var wide: bool = world.geo.lane_count >= tuning.wide_lanes
	return maxi(MechaGuppyTuning.per_phase(tuning.spot_bombs_wide if wide else tuning.spot_bombs, phase), 1)


func spot_choices() -> int:
	return maxi(tuning.spot_choices_wide if world.geo.lane_count >= tuning.wide_lanes else tuning.spot_choices, 1)


## True if a spot's bomb may land over `lane` at `at` on the roof whose top is `y`: the roof is under the whole blast
## (FLOOR_CLEAR beyond its depth either way), no hut reaches within HUT_CLEAR of it (the hut would take the bomb), and
## no pickup waits there (pickup_margin).
func spot_floor(lane: int, at: float, y: float) -> bool:
	var half: float = tuning.blast_depth * 0.5
	if not _covered(lane, at - half - FLOOR_CLEAR, at + half + FLOOR_CLEAR, y):
		return false
	if _hut_near(lane, at - half - HUT_CLEAR, at + half + HUT_CLEAR, y):
		return false
	return not _pickup_near(lane, at)


## True if the roof whose top is `y` covers `lane` everywhere from `from` to `to`.
func _covered(lane: int, from: float, to: float, y: float) -> bool:
	var climb: MechaGuppyClimb = boss.climb
	for i: int in range(maxi(climb.roof_index_at(from) - 1, 0), mini(climb.roof_index_at(to) + 2, climb.roofs.size())):
		var r: MechaGuppyClimb.Roof = climb.roofs[i]
		if absf(r.top - y) < 0.05 and r.covers(lane, from) and r.covers(lane, to - 0.001):
			return true
	return false


## True if a hut above height `y` covers `lane` anywhere between `from` and `to`.
func _hut_near(lane: int, from: float, to: float, y: float) -> bool:
	var climb: MechaGuppyClimb = boss.climb
	for k: int in range(maxi(climb.step_index_at(from) - 1, 0), mini(climb.step_index_at(to) + 2, climb.steps.size())):
		var s: MechaGuppyClimb.Step = climb.steps[k]
		if s.top or s.hut_y <= y + 0.5 or lane < 0 or lane >= s.ends.size():
			continue
		if s.hut_start < to and s.ends[lane] > from:
			return true
	return false


func _pickup_near(lane: int, at: float) -> bool:
	if world.pickups == null:
		return false
	for p: Pickup in world.pickups.active:
		if is_instance_valid(p) and p.lane == lane and absf(p.at - at) < tuning.pickup_margin:
			return true
	return false


## For each lane, true if the roof whose top is `y` covers it from `from` to `to` (the runner can be there, and
## switch through it).
func open_lanes(from: float, to: float, y: float) -> Array[bool]:
	var out: Array[bool] = []
	for l: int in world.geo.lane_count:
		out.append(_covered(l, from, to, y))
	return out


## A volley for a runner in lane `pl` at track distance `d0` who can first switch at `s_open`: spots at the track
## distances `ats` (nearest first) on the roof whose top is `y`, in phase `phase`; up to as many as are fair:
## [{lanes, at, y}], or none. The Floating Head's salvo rules (FloatingHeadBombing.plan_salvo): it follows every lane
## the runner could be in past each spot, and makes each spot the block of up to spot_bombs() lanes side by side, all
## on floor with no hut near and no pickup (spot_floor), that leaves them the fewest lanes, but no fewer than
## spot_choices() where it can and never none: the first spot's block holds the runner's lane and leaves a lane at most
## max_escape_lanes away (fewer if time is short: dodge_reaction, then each switch at the lane-switch time plus
## dodge_margin from where they can first switch), each later one strikes a lane they could be in and leaves one at
## most max_shift from it, through lanes open from where they set off to ESCAPE_AFTER past the spot. Ties: a lane they
## could have stayed in since the first spot, then more of their lanes, then lanes left together, then fewer bombs,
## then a seeded pick (`seed`). A volley whose next spot can't be fair ends there.
func plan_spots(pl: int, d0: float, s_open: float, ats: Array[float], y: float, phase: int, seed: int) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	if ats.is_empty():
		return spots
	_rng.seed = seed
	var n: int = world.geo.lane_count
	var speed: float = maxf(world.player.speed, 1.0)
	var t: MovementTuning = world.tuning
	var choices: int = spot_choices()
	var after: float = ESCAPE_AFTER * t.pace()
	var could: Array[int] = [pl]
	var stay: Array[int] = []
	var from: float = maxf(d0, s_open)
	for k: int in ats.size():
		var at: float = ats[k]
		var reach: int = tuning.max_shift
		if k == 0:
			# The time from when they can first act (seen it and can switch) to reaching the spot.
			var see: float = tuning.dodge_reaction
			var can: float = maxf(see, (s_open - d0) / speed)
			var have: float = (at - d0) / speed - can - tuning.dodge_margin
			reach = mini(tuning.max_escape_lanes, floori(have / maxf(t.lane_switch_time, 0.01) + 0.0001))
			if reach < 1:
				break
		var open: Array[bool] = open_lanes(from, at + after, y)
		var floor_ok: Array[bool] = []
		for l: int in n:
			floor_ok.append(spot_floor(l, at, y))
		var best: Array = []
		var picks: Array = []
		for width: int in range(1, spot_bombs(phase) + 1):
			for low: int in range(0, n - width + 1):
				var block: Array[int] = []
				var on_floor: bool = true
				for l: int in range(low, low + width):
					block.append(l)
					on_floor = on_floor and floor_ok[l]
				if not on_floor or (k == 0 and not block.has(pl)):
					continue
				var struck: int = 0
				for l: int in could:
					if block.has(l):
						struck += 1
				if struck == 0:
					continue
				var left: Array[int] = _reach(could, block, open, reach)
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
		var pick: Array = picks[_rng.randi() % picks.size()]
		var lanes: Array[int] = pick[0]
		spots.append({"lanes": lanes, "at": at, "y": y})
		could = pick[1]
		if k == 0:
			stay = could.duplicate()
		else:
			for l: int in lanes:
				stay.erase(l)
		from = at
	return spots


## -1, 0 or 1 as `a` sorts before, with or after `b`, element by element (an empty `b` sorts last).
static func _compare(a: Array, b: Array) -> int:
	if b.is_empty():
		return -1
	for i: int in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return -1 if a[i] < b[i] else 1
	return 0


## The lanes a runner could be in past a spot striking `lanes`, from any of `starts`: not struck, at most `reach` from
## where they are, with every lane on the way `open`.
func _reach(starts: Array[int], lanes: Array[int], open: Array[bool], reach: int) -> Array[int]:
	var n: int = world.geo.lane_count
	var out: Array[int] = []
	for r: int in starts:
		for e: int in range(maxi(r - reach, 0), mini(r + reach, n - 1) + 1):
			if not lanes.has(e) and not out.has(e) and _crossing_open(r, e, open):
				out.append(e)
	out.sort()
	return out


static func _crossing_open(r: int, e: int, open: Array[bool]) -> bool:
	for l: int in range(mini(r, e), maxi(r, e) + 1):
		if not open[l]:
			return false
	return true


## A way through `spots` ({lanes, at, y} each, nearest first) for a runner in `pl` at `d0` who can first switch at
## `s_open`: the lane to be in at each spot, with as few switches as can be, or empty if there is none. It keeps the
## volley's rules: to the first spot at most max_escape_lanes, from one to the next at most max_shift, through lanes open
## from where it sets off to ESCAPE_AFTER past the spot.
func way_through(spots: Array, pl: int, d0: float, s_open: float) -> Array[int]:
	var way: Array[int] = []
	var n: int = world.geo.lane_count
	var after: float = ESCAPE_AFTER * world.tuning.pace()
	var cost: Dictionary = {pl: 0}
	var back: Array[Dictionary] = []
	var from: float = maxf(d0, s_open)
	for k: int in spots.size():
		var lanes: Array = spots[k]["lanes"]
		var at: float = float(spots[k]["at"])
		var open: Array[bool] = open_lanes(minf(from, at), at + after, float(spots[k]["y"]))
		var reach: int = tuning.max_escape_lanes if k == 0 else tuning.max_shift
		var next: Dictionary = {}
		var prev: Dictionary = {}
		var starts: Array = cost.keys()
		starts.sort()
		for r: int in starts:
			for e: int in range(maxi(r - reach, 0), mini(r + reach, n - 1) + 1):
				var c: int = int(cost[r]) + absi(e - r)
				if lanes.has(e) or (next.has(e) and int(next[e]) <= c):
					continue
				if _crossing_open(r, e, open):
					next[e] = c
					prev[e] = r
		if next.is_empty():
			return way
		cost = next
		back.append(prev)
		from = at
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


## The volleys' spots a runner at `d0` hasn't run past yet, nearest first, each with its volley's s_open.
func spots_ahead(d0: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var past: float = tuning.blast_depth * 0.5 + world.tuning.hurtbox_size.z * 0.5 + PAST_MARGIN
	for v: Dictionary in volleys:
		for spot: Dictionary in v["spots"]:
			if float(spot["at"]) + past > d0:
				var s: Dictionary = spot.duplicate()
				s["s_open"] = float(v["s_open"])
				out.append(s)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## Where a runner in lane `pl` at `d0` should be for the next spot ahead of them, on a way through the rest
## (way_through): -1 with no spot ahead or no way through.
func dodge_lane(pl: int, d0: float) -> int:
	var ahead: Array[Dictionary] = spots_ahead(d0)
	if ahead.is_empty():
		return -1
	var way: Array[int] = way_through(ahead, pl, d0, float(ahead[0]["s_open"]))
	return way[0] if not way.is_empty() else -1


func _prune_volleys() -> void:
	var d: float = world.player.distance
	var past: float = tuning.blast_depth * 0.5 + world.tuning.hurtbox_size.z * 0.5 + PAST_MARGIN + 2.0
	for i: int in range(volleys.size() - 1, -1, -1):
		var spots: Array = volleys[i]["spots"]
		if spots.is_empty() or float(spots[-1]["at"]) + past < d:
			volleys.remove_at(i)


# --- Bombs and what they land on --------------------------------------------------------------------

func _update_drops(delta: float) -> void:
	for i: int in range(_drops.size() - 1, -1, -1):
		var d: Dictionary = _drops[i]
		if not bool(d["released"]) and clock >= float(d["release"]) - 0.0001:
			d["released"] = true
			d["bomb"] = _free_bomb()
			d["from"] = _hand()
			if boss.ship != null and is_instance_valid(boss.ship):
				boss.ship.throw()
		if not bool(d["whistled"]) and clock >= float(d["whistle"]):
			d["whistled"] = true
			boss.sound(&"bomb_whistle", Vector3(float(d["x"]), float(d["y"]) + 1.0, TrackGeometry.world_z(float(d["at"]))))
		var bomb: Node3D = d["bomb"]
		if not bool(d["landed"]):
			if bomb != null:
				_place_bomb(bomb, d)
			if clock >= float(d["impact"]) - 0.0001:
				d["landed"] = true
				boss.props.remove(d.get("circle"))
				d["circle"] = null
				if _land(d):
					if bomb != null:
						bomb.visible = false
					_drops.remove_at(i)
		else:
			# Fell past the floor's level with nothing there: on down into the chasm, ever faster, then gone.
			d["fall"] = float(d["fall"]) + delta
			var f: float = float(d["fall"])
			if bomb != null:
				bomb.global_position = Vector3(float(d["x"]), float(d["y"]) - 8.0 * f - 0.5 * FALL_PULL * f * f,
					TrackGeometry.world_z(float(d["at"])))
				bomb.rotate_x(delta * 6.0)
			if f >= FALL_ON:
				if bomb != null:
					bomb.visible = false
				_drops.remove_at(i)


## The bomb lands (see the header). True once it's done (it burst, or went into the shark); false if it falls on.
func _land(d: Dictionary) -> bool:
	var lane: int = int(d["lane"])
	var at: float = float(d["at"])
	var y: float = float(d["y"])
	var x: float = float(d["x"])
	var p := Vector3(x, y, TrackGeometry.world_z(at))
	var lands: int = surface_at(lane, at, y)
	d["lands"] = lands
	match lands:
		Lands.ROOF:
			stats["roof"] = int(stats["roof"]) + 1
			_blast(x, at, y, false)
			return true
		Lands.HUT:
			stats["hut"] = int(stats["hut"]) + 1
			_blast(x, at, y, true)
			return true
	if boss.shark != null and boss.shark.mouth_contains(p):
		stats["hit"] = int(stats["hit"]) + 1
		boss.shark.hit(p)
		var counted: bool = boss.register_hit(&"bomb")
		boss.log_event(&"shark_hit", {"lane": lane, "at": at, "kind": int(d["kind"]), "counted": counted})
		return true
	stats["chasm"] = int(stats["chasm"]) + 1
	boss.log_event(&"chasm", {"lane": lane, "at": at, "y": y, "kind": int(d["kind"])})
	return false


## What a bomb coming down over `lane` at `at` to height `y` meets there: a roof's top (ROOF), a hut's top (HUT), or
## nothing (CHASM: past an edge, through a gap, into the eaten chasm).
func surface_at(lane: int, at: float, y: float) -> int:
	var climb: MechaGuppyClimb = boss.climb
	var top: float = climb.floor_at(lane, at, y + 0.3)
	if not is_nan(top) and absf(top - y) < 0.3:
		return Lands.ROOF
	var hut: float = climb.hut_at(lane, at)
	if not is_nan(hut) and absf(hut + TrackBuilder.HULL_THICKNESS - y) < 0.4:
		return Lands.HUT
	return Lands.CHASM


## A bomb on its way: from the captain's hand to where it lands, on a lob, nose first, its fuse sparking (steady with
## Reduced flashing).
func _place_bomb(bomb: Node3D, d: Dictionary) -> void:
	var t0: float = float(d["release"])
	var s: float = clampf((clock - t0) / maxf(float(d["impact"]) - t0, 0.01), 0.0, 1.0)
	var from: Vector3 = d["from"]
	var to := Vector3(float(d["x"]), float(d["y"]) + 0.35, TrackGeometry.world_z(float(d["at"])))
	var line: Vector3 = from.lerp(to, s)
	bomb.visible = true
	bomb.global_position = line + Vector3(0.0, LOB * 4.0 * s * (1.0 - s), 0.0)
	bomb.rotation = Vector3(s * 7.0, s * 3.0, 0.0)
	var spark: Node3D = bomb.get_child(0) as Node3D
	if spark != null:
		spark.visible = Settings.flashing_reduced or int(clock * FUSE_HZ * 2.0) % 2 == 0


## A burst: on a roof's top a blast that burns blast_seconds (an enemy attack: real contact only), on a hut's top the
## same above the hut (a rider under it is never touched); a fireball, the boom and a shake.
func _blast(x: float, at: float, y: float, on_hut: bool) -> void:
	var geo: TrackGeometry = world.geo
	var half: float = geo.lane_width * tuning.blast_width_share * 0.5
	var reach: float = geo.wall_x() - 0.05
	var x0: float = maxf(x - half, -reach)
	var x1: float = minf(x + half, reach)
	var hazard: Hazard = _free_hazard()
	var size := Vector3(x1 - x0, tuning.blast_height, tuning.blast_depth)
	hazard.size = size
	((hazard.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
	hazard.global_position = Vector3((x0 + x1) * 0.5, y + size.y * 0.5, TrackGeometry.world_z(at))
	hazard.set_enabled(true)
	_blasts.append({"hazard": hazard, "start": clock})
	var centre := Vector3(x, y + 0.8, TrackGeometry.world_z(at))
	if on_hut:
		# Kept up on the hut's top (its fire never shows under the hut a rider hangs from), smoking.
		world.effects.fireball(centre + Vector3(0.0, tuning.blast_radius * 0.6, 0.0), tuning.blast_radius, true, FIRE_PACE, FIRE_SPREAD)
		world.effects.debris(centre + Vector3(0.0, 0.8, 0.0), (world.skin as BeachSkin).thatch_color if world.skin is BeachSkin
			else Color(0.6, 0.5, 0.3), 6, 0.7)
	else:
		world.effects.fireball(centre + Vector3(0.0, 0.3, 0.0), tuning.blast_radius * FIRE_SIZE_PER_RADIUS, false, FIRE_PACE,
			FIRE_SPREAD)
	var near: float = clampf(1.0 - absf(at - world.player.distance) / 40.0, 0.2, 1.0)
	world.effects.shake((0.18 if on_hut else 0.3) * near, 0.3)
	boss.sound(&"bomb_blast", centre)
	boss.log_event(&"blast", {"x": x, "at": at, "y": y, "hut": on_hut})


func _update_blasts() -> void:
	for i: int in range(_blasts.size() - 1, -1, -1):
		var b: Dictionary = _blasts[i]
		var age: float = clock - float(b["start"])
		var hazard: Hazard = b["hazard"]
		if hazard.is_active() and age >= tuning.blast_seconds - 0.0001:
			hazard.set_enabled(false)
		if age >= FIRE_SECONDS and not hazard.is_active():
			_blasts.remove_at(i)


# --- Pools and the bomb's look --------------------------------------------------------------------

func _free_bomb() -> Node3D:
	for b: Node3D in _bombs:
		if not b.visible and not _flying(b):
			return b
	var extra: Node3D = _new_bomb()
	_bombs.append(extra)
	return extra


func _flying(b: Node3D) -> bool:
	for d: Dictionary in _drops:
		if d["bomb"] == b:
			return true
	return false


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


## A bomb: its body (bomb_mesh) and its fuse's spark (its first child), hidden until thrown.
func _new_bomb() -> Node3D:
	var bomb := Node3D.new()
	bomb.name = "Bomb"
	var spark := MeshInstance3D.new()
	spark.name = "Spark"
	spark.mesh = GreyboxMaterials.unit_box()
	spark.material_override = GreyboxMaterials.glow(FUSE_COLOR, 3.0)
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark.position = Vector3(0.0, 0.62, 0.0)
	spark.scale = Vector3(0.14, 0.14, 0.14)
	bomb.add_child(spark)
	var beach := world.skin as BeachSkin
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = bomb_mesh(beach.solid_material() if beach != null else null)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if beach == null:
		body.material_override = GreyboxMaterials.scenery(Color(0.1, 0.1, 0.11))
	bomb.add_child(body)
	bomb.visible = false
	add_child(bomb)
	return bomb


## The bomb's body (GDD §10: "in a pirate look"): a round black iron bomb, about 0.9 m across, a brass cog band round
## its middle with teeth, a brass cap and a short fuse on top (its spark is the bomb's own node). In `material` (the
## skin's solid one), shared.
static func bomb_mesh(material: Material) -> ArrayMesh:
	var key: int = material.get_instance_id() if material != null else 0
	if _bomb_meshes.has(key):
		return _bomb_meshes[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var iron := Color(0.075, 0.075, 0.085)
	var brass := Color(0.78, 0.6, 0.3)
	var rings: int = 6
	var sides: int = 10
	var r: float = 0.45
	for i: int in rings:
		var a0: float = PI * float(i) / float(rings) - PI * 0.5
		var a1: float = PI * float(i + 1) / float(rings) - PI * 0.5
		for j: int in sides:
			var b0: float = TAU * float(j) / float(sides)
			var b1: float = TAU * float(j + 1) / float(sides)
			var p00 := Vector3(cos(a0) * cos(b0), sin(a0), cos(a0) * sin(b0)) * r
			var p01 := Vector3(cos(a0) * cos(b1), sin(a0), cos(a0) * sin(b1)) * r
			var p10 := Vector3(cos(a1) * cos(b0), sin(a1), cos(a1) * sin(b0)) * r
			var p11 := Vector3(cos(a1) * cos(b1), sin(a1), cos(a1) * sin(b1)) * r
			var out: Vector3 = (p00 + p11) * 0.5
			if (p01 - p00).cross(p11 - p00).dot(out) > 0.0:
				s.quad(p00, p10, p11, p01, iron)
			else:
				s.quad(p00, p01, p11, p10, iron)
	# The brass cog band round its middle, with teeth.
	s.prism(Vector3(0.0, -0.07, 0.0), r * 1.03, 0.14, sides, brass)
	for j: int in sides:
		var b: float = TAU * (float(j) + 0.5) / float(sides)
		s.box(Vector3(cos(b), 0.0, sin(b)) * r * 1.08, Vector3(0.1, 0.12, 0.1), brass)
	# The cap and the fuse.
	s.prism(Vector3(0.0, r * 0.88, 0.0), 0.13, 0.12, 8, brass)
	s.box(Vector3(0.0, r + 0.12, 0.0), Vector3(0.04, 0.16, 0.04), Color(0.3, 0.24, 0.16))
	var mesh: ArrayMesh = batch.to_mesh()
	_bomb_meshes[key] = mesh
	return mesh
