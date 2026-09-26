extends TestSuite
## The Cyborg's Bad Dream (GDD §9.7) in full RunWorlds on real physics: it bursts out of a killed host
## (stomp, claws or dash) and only then; its immunities and the counters (weapons, stomping, claws,
## the dash, armor, the shield, a generator's EMP); the three-lane slash at 3, 5 and 6 lanes (exactly
## those lanes, edges clamped), its warning and its dodge; waiting below a ceiling, following onto a
## wall slowly, and the wall slash; the chase's end and survival bonus; one at a time; never with an
## Octodog charge sequence or a drone barrage; and its generator rules (host_rules.gd) over lane
## counts, seeds and difficulties, alone and together with drones and Octodogs.

const DroneScript := preload("res://scripts/enemies/drone.gd")
const HostRules := preload("res://scripts/enemies/host_rules.gd")
const CYBORG_TUNING_PATH: String = "res://data/enemies/cyborg.tres"
## Jump this far (track distance) before a walking cyborg to land on its head (as in test_cyborg).
const STOMP_LEAD: float = 9.5
const SLASH_NAME: String = "Bad Dream slash"

var sim: RunSim
var t: BadDreamTuning
var ct: CyborgTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = EnemyDirector.tuning_for("bad_dream") as BadDreamTuning
	ct = load(CYBORG_TUNING_PATH) as CyborgTuning
	check(t != null, "data/enemies/bad_dream.tres is a BadDreamTuning")
	check(ct != null, "the cyborg tuning loads")
	if t == null or ct == null:
		return
	await _test_declared()
	await _test_emerges_from_hosts()
	await _test_not_otherwise()
	await _test_immunities()
	await _test_protection()
	await _test_slash_lanes()
	await _test_dodge()
	await _test_warning()
	await _test_waits_below_ceiling()
	await _test_follows_onto_wall()
	await _test_wall_slash()
	await _test_chase_end()
	await _test_emp()
	await _test_one_at_a_time()
	await _test_major_attacks()
	_test_generator()


# --- Helpers ------------------------------------------------------------------------------------

func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k in ["armor", "shield", "grapple", "revive"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


## A world with the player in `player_lane` and a Bad Dream already floating in front of them (no
## emergence), over `dream_lane` (default: the player's). Returns [world, dream].
func _world(lanes: int, player_lane: int, params: Dictionary = {}, loadout: Loadout = null,
		layout: LevelLayout = null, dream_lane: int = -1, config: LevelConfig = null) -> Array:
	var l: LevelLayout = layout if layout != null else RunSim.layout(lanes, 1500.0)
	var w: RunWorld = sim.build_world(l, loadout, null, config)
	w.player.setup(tuning, w.geo, player_lane)
	var p: Dictionary = {"emerge": false}
	p.merge(params, true)
	var dream := w.director.spawn({"type": "bad_dream", "at": 0.0, "side": 0, "seed": 5, "params": p,
		"lane": dream_lane if dream_lane >= 0 else player_lane}) as BadDream
	await tree.physics_frame
	w.player.running = true
	return [w, dream]


## Steps physics frames until `cond` is true (true) or `seconds` pass (false).
func _until(cond: Callable, seconds: float) -> bool:
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


func _wait(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)


## The Bad Dream with this instance id, or null once it's freed.
func _dream(id: int) -> BadDream:
	var o: Object = instance_from_id(id)
	return o as BadDream if is_instance_valid(o) else null


## How many times `event` is in the dream's history (0 once it's gone).
func _count(id: int, event: String) -> int:
	var d: BadDream = _dream(id)
	if d == null:
		return 0
	var n: int = 0
	for h: Array in d.history:
		if h[0] == event:
			n += 1
	return n


## The level time of the `nth` (0-based) `event` in the dream's history, or -1.
func _time_of(d: BadDream, event: String, nth: int = 0) -> float:
	var n: int = 0
	for h: Array in d.history:
		if h[0] == event:
			if n == nth:
				return float(h[1])
			n += 1
	return -1.0


func _gone(id: int) -> bool:
	var d: BadDream = _dream(id)
	return d == null or d.is_queued_for_deletion() or not d.alive


## The lanes GDD §9.7 says a slash at `lane` covers: it and the lanes on either side, clamped.
static func _expected_band(lanes: int, lane: int) -> Vector2i:
	return Vector2i(maxi(lane - 1, 0), mini(lane + 1, lanes - 1))


# --- Declared properties ------------------------------------------------------------------------

func _test_declared() -> void:
	check(is_equal_approx(t.chase_min_seconds, 20.0) and is_equal_approx(t.chase_max_seconds, 30.0),
		"GDD §9.7: a 20–30 s chase")
	check(is_equal_approx(t.slash_interval_min, 3.0) and is_equal_approx(t.slash_interval_max, 4.0),
		"GDD §9.7: a slash every ~3–4 s")
	for s: float in [0.0, 0.5, 1.0]:
		check(t.warning_time(s) >= 0.9, "scaling %.1f: the slash is telegraphed %.2f s ahead (at least 0.9 s)"
			% [s, t.warning_time(s)])
	check(t.slash_height > tuning.jump_height + 0.05, "the claws sweep higher than a jump's feet reach: only leaving the lanes dodges")
	var made: Array = await _world(5, 2)
	var w: RunWorld = made[0]
	var dream: BadDream = made[1]
	check(dream.immune_to_weapons and dream.claw_immune and not dream.stompable and not dream.dash_kills,
		"declared: immune to weapons, claws and stomping; the dash doesn't kill it")
	check(dream.exclusive_major_attack and dream.is_major_attack_active(), "its chase is an exclusive major attack")
	check(dream.slash_hitbox().is_enemy_attack and not dream.slash_hitbox().is_solid and dream.slash_hitbox().dash_passes
		and dream.slash_hitbox().part == &"attack", "the slash is an enemy attack the dash passes through")
	check(dream.body_hitbox().is_enemy_attack and dream.body_hitbox().dash_passes, "so is its body")
	# The rolled chase length stays in 20–30 s.
	var lo: float = INF
	var hi: float = -INF
	for s: int in 40:
		var d := w.director.spawn({"type": "bad_dream", "at": 0.0, "lane": 1, "side": 0, "seed": 100 + s,
			"params": {"emerge": false}}) as BadDream
		lo = minf(lo, d.chase_seconds)
		hi = maxf(hi, d.chase_seconds)
		d.retire()
	check(lo >= t.chase_min_seconds and hi <= t.chase_max_seconds and hi - lo > 5.0,
		"each rolls its chase in 20–30 s (%.1f–%.1f)" % [lo, hi])
	await sim.free_world(w)


# --- Origin -------------------------------------------------------------------------------------

## GDD §9.7: it bursts out of a host killed by a stomp, claws or the dash; the host bonus is paid.
func _test_emerges_from_hosts() -> void:
	for cause: String in ["stomp", "claws", "dash"]:
		var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0), _loadout({"claws": 1} if cause == "claws" else {}))
		w.player.setup(tuning, w.geo, 1)
		var host := w.director.spawn({"type": "cyborg", "at": 45.0, "lane": 1, "side": 0, "seed": 3,
			"params": {"host": true, "panic": false, "fires": false}}) as Cyborg
		await tree.physics_frame
		w.player.running = true
		match cause:
			"stomp":
				await _until(func() -> bool: return host.track_distance() - w.player.distance <= STOMP_LEAD, 4.0)
				w.player.press(&"jump")
			"dash":
				await _until(func() -> bool: return host.track_distance() - w.player.distance <= 6.0, 4.0)
				w.player.start_dash(0.8, 0.0)
		await _until(func() -> bool: return w.director.count_alive(&"bad_dream") > 0 or not w.player.alive, 4.0)
		check(w.player.alive and not host.alive, "a host killed by %s (%s)" % [cause, w.player.last_event])
		check(int(w.score.bonuses.get(&"host", 0)) == ct.host_bonus, "pays the host bonus (%s)" % cause)
		var dream: BadDream = null
		for e: Enemy in w.director.active:
			if e is BadDream:
				dream = e
		check(dream != null and dream.alive, "the Bad Dream bursts out of a host killed by %s" % cause)
		if dream != null:
			check(bool(dream.spawn["params"].get("from_host", false)) and dream.state == BadDream.State.EMERGE,
				"it emerges from the host (%s)" % cause)
			check(absf(dream.rel_ahead - (host.track_distance() - w.player.distance)) < 3.0,
				"where the host stood (%.1f m ahead)" % dream.rel_ahead)
			check(not dream.body_hitbox().is_active() and not dream.slash_hitbox().is_active(),
				"harmless while it emerges")
			var id: int = dream.get_instance_id()
			await _until(func() -> bool: return _dream(id) != null and _dream(id).state == BadDream.State.DRIFT, 3.0)
			check(dream.state == BadDream.State.DRIFT and dream.rel_ahead > t.lunge_ahead,
				"then floats in front of the player (%.1f m ahead)" % dream.rel_ahead)
			check(w.player.alive, "and emerging never hurt the player (%s)" % w.player.last_event)
		await sim.free_world(w)


## Nothing else releases one: a host left alone, a host that leaves play, a normal cyborg killed.
func _test_not_otherwise() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 0)
	w.director.spawn({"type": "cyborg", "at": 40.0, "lane": 2, "side": 0, "seed": 3,
		"params": {"host": true, "panic": false, "fires": false}})
	var retired := w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 2, "side": 0, "seed": 4,
		"params": {"host": true, "panic": false, "fires": false}}) as Cyborg
	var normal := w.director.spawn({"type": "cyborg", "at": 90.0, "lane": 0, "side": 0, "seed": 5,
		"params": {"panic": false, "fires": false}}) as Cyborg
	await tree.physics_frame
	w.player.running = true
	retired.retire()
	await _until(func() -> bool: return normal.track_distance() - w.player.distance <= STOMP_LEAD, 6.0)
	w.player.press(&"jump")
	await _until(func() -> bool: return w.player.distance > 130.0, 4.0)
	check(w.player.alive and w.score.stomps == 1, "a normal cyborg was stomped (%s)" % w.player.last_event)
	check(w.director.count_alive(&"bad_dream") == 0 and int(w.score.bonuses.get(&"host", 0)) == 0,
		"no Bad Dream from a host passed by or leaving play, nor from a normal cyborg")
	await sim.free_world(w)


# --- Immunities and counters ----------------------------------------------------------------------

func _defense(items: Array) -> DamageRules.Defense:
	var d := DamageRules.Defense.new()
	d.armor = items.has("armor")
	d.shield = items.has("shield")
	d.claws = items.has("claws")
	d.dashing = items.has("dash")
	return d


## GDD §9.7: immune to weapons (never targeted), stomping and claws; the dash passes through it.
func _test_immunities() -> void:
	const O = DamageRules.Outcome
	var made: Array = await _world(5, 2)
	var w: RunWorld = made[0]
	var dream: BadDream = made[1]
	check(not dream.targetable() and not w.director.targets_ahead(Vector3(0.0, 1.0, w.player.position.z), 80.0).has(dream),
		"auto-fire never targets it")
	var hits: Array = []
	w.projectiles.enemy_hit.connect(func(e: Enemy, _dmg: float, _splash: bool) -> void: hits.append(e))
	for look: StringName in [&"laser", &"heavy_missile"]:
		w.projectiles.fire_player(dream.aim_point() + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -90.0), 3.0, look,
			null, 0.0, 5.0 if look == &"heavy_missile" else 0.0, 0.5)
	await physics_frames(12)
	check(hits.is_empty() and dream.alive and is_equal_approx(dream.health, dream.max_health),
		"shots and missile splash pass through it harmlessly")
	var body: Hazard = dream.body_hitbox()
	check(DamageRules.resolve(body, _defense([]), true) == O.KILL, "landing on it doesn't stomp it: it hurts")
	check(DamageRules.resolve(body, _defense(["claws"]), true) == O.KILL
		and DamageRules.resolve(body, _defense(["claws"]), false) == O.KILL, "claws don't beat it")
	check(DamageRules.resolve(body, _defense(["dash"]), false) == O.IGNORE, "the dash passes through it safely")
	check(DamageRules.resolve(body, _defense(["armor"]), false) == O.BLOCKED_ARMOR, "armor blocks its touch")
	# Real contact through the player (as its contact check would): the dream is never defeated.
	w.player.claws = true
	var outcome: int = w.player.receive_hit(body, true)
	check(outcome == O.KILL and dream.alive, "a clawed stomp on it kills the player, not the dream")
	w.player.revive()
	w.player.claws = false
	w.player.invulnerable_left = 0.0
	w.player.start_dash(0.6, 0.0)
	check(w.player.receive_hit(body, false) == O.IGNORE and dream.alive and w.player.alive, "dashing into it: safe, and it lives")
	await sim.free_world(w)

	# The dash carries the player through a live slash, and the dream is still there afterwards.
	made = await _world(3, 1)
	w = made[0]
	dream = made[1]
	var id: int = dream.get_instance_id()
	await _until(func() -> bool: return _count(id, "lunge") >= 1, 4.0)
	w.player.start_dash(0.6, 8.0)
	await _until(func() -> bool: return _count(id, "recover") >= 1 or not w.player.alive, 2.0)
	check(w.player.alive and dream.slashes >= 1 and dream.alive and not dream.is_queued_for_deletion(),
		"the juggernaut dash passes through a slash safely and doesn't kill it (%s)" % w.player.last_event)
	await sim.free_world(w)


## GDD §9.7: armor and the shield each block one slash (then the next one lands).
func _test_protection() -> void:
	for items: Array in [["armor"], ["shield"], ["armor", "shield"]]:
		var charges: Dictionary = {}
		for item: String in items:
			charges[item] = 1
		var made: Array = await _world(3, 1, {"chase": 30.0}, _loadout(charges))
		var w: RunWorld = made[0]
		var dream: BadDream = made[1]
		var id: int = dream.get_instance_id()
		var events: Array = []
		w.player.movement_event.connect(func(k: StringName) -> void: events.append(k))
		var tag: String = "+".join(items)
		for i: int in items.size():
			await _until(func() -> bool: return _count(id, "recover") >= i + 1 or not w.player.alive, 7.0)
			check(w.player.alive and dream.slashes == i + 1, "%s: slash %d is blocked (%s)" % [tag, i + 1, w.player.last_event])
		check(events.count(&"armor_break") == (1 if items.has("armor") else 0)
			and events.count(&"shield_break") == (1 if items.has("shield") else 0),
			"%s: each item blocks exactly one slash (%s)" % [tag, events])
		await _until(func() -> bool: return not w.player.alive, 7.0)
		check(not w.player.alive and w.player.last_event.contains(SLASH_NAME) and dream.slashes == items.size() + 1,
			"%s: the next slash lands (%s, %d slashes)" % [tag, w.player.last_event, dream.slashes])
		await sim.free_world(w)


# --- The slash ------------------------------------------------------------------------------------

## GDD §9.7: the slash covers the player's lane and the lanes on either side, clamped at the edges,
## at every lane count: the damage box holds a runner (standing or at a jump's top) in exactly those
## lanes, never a wall runner beside them, and a player who stays is hit.
func _test_slash_lanes() -> void:
	var half := Vector3(tuning.hurtbox_size.x * 0.5, 0.0, tuning.hurtbox_size.z * 0.5)
	for lanes: int in [3, 5, 6]:
		var player_lanes: Array[int] = [0, 1, lanes / 2, lanes - 1]
		if lanes == 3:
			player_lanes = [0, 1, 2]
		for player_lane: int in player_lanes:
			var tag: String = "lanes=%d player=%d" % [lanes, player_lane]
			var made: Array = await _world(lanes, player_lane)
			var w: RunWorld = made[0]
			var dream: BadDream = made[1]
			var id: int = dream.get_instance_id()
			var told: bool = await _until(func() -> bool: return _count(id, "telegraph") >= 1, 3.0)
			var expected: Vector2i = _expected_band(lanes, player_lane)
			check(told and dream.band == expected, "the slash covers lanes %s %s (%s)" % [expected, tag, dream.band])
			var box: AABB = dream.slash_box_for(dream.band)
			for lane: int in lanes:
				var covered: bool = lane >= expected.x and lane <= expected.y
				for h: float in [0.0, tuning.jump_height]:
					var body := AABB(Vector3(w.geo.lane_x(lane), h, 0.0) - half, tuning.hurtbox_size)
					check(box.intersects(body) == covered, "lane %d at %.1f m %s by the claws %s" % [lane, h,
						"is reached" if covered else "is out of reach", tag])
			for side: int in [-1, 1]:
				var x0: float = side * w.geo.wall_x() - (tuning.hurtbox_size.y if side > 0 else 0.0)
				for h: float in [tuning.wall_exit_height, 1.0, tuning.wall_entry_height, tuning.wall_max_height]:
					var runner := AABB(Vector3(x0, h - half.x, -half.z), Vector3(tuning.hurtbox_size.y, half.x * 2.0, half.z * 2.0))
					check(not box.intersects(runner), "a wall runner beside the lanes is safe (side %d, %.1f m) %s" % [side, h, tag])
			await _until(func() -> bool: return not w.player.alive or _count(id, "recover") >= 1, 3.0)
			check(not w.player.alive and w.player.last_event.contains(SLASH_NAME),
				"staying in a covered lane is hit %s (%s)" % [tag, w.player.last_event])
			await sim.free_world(w)


## GDD §9.7: leaving the covered lanes after the telegraph starts (soon, or at the last moment)
## dodges the slash: to a free lane, or onto a wall (on three lanes the middle lane's slash covers
## the whole floor).
func _test_dodge() -> void:
	var late: float = t.warning_time(0.0) - 0.36
	for lanes: int in [3, 5, 6]:
		for player_lane: int in [0, lanes / 2, lanes - 1]:
			var band: Vector2i = _expected_band(lanes, player_lane)
			for dir: int in [-1, 1]:
				# Moves to the first free lane that way, or onto the wall.
				var out: int = band.x - 1 if dir < 0 else band.y + 1
				var moves: int = absi(out - player_lane)
				var onto_wall: bool = out < 0 or out >= lanes
				if onto_wall:
					moves = (player_lane + 1) if dir < 0 else (lanes - player_lane)
				for delay: float in [0.15, late]:
					var tag: String = "lanes=%d player=%d %s%s x%d after %.2f s" % [lanes, player_lane,
						"left" if dir < 0 else "right", " onto the wall" if onto_wall else "", moves, delay]
					var made: Array = await _world(lanes, player_lane)
					var w: RunWorld = made[0]
					var dream: BadDream = made[1]
					var id: int = dream.get_instance_id()
					await _until(func() -> bool: return _count(id, "telegraph") >= 1, 3.0)
					await _wait(delay)
					for m: int in moves:
						w.player.press(&"move_left" if dir < 0 else &"move_right")
					await _until(func() -> bool: return not w.player.alive or _count(id, "recover") >= 1, 3.0)
					check(w.player.alive and dream.slashes == 1, "leaving the lanes dodges the slash: %s (%s)" % [tag,
						w.player.last_event])
					if onto_wall:
						check(w.player.surface == Player.Surface.WALL, "and the player is on the wall " + tag)
					await sim.free_world(w)


## Every attack has a visual and an audio warning (CLAUDE.md): the shriek and the lit lanes come at
## least the warning time before the claws are live, at every campaign scaling.
func _test_warning() -> void:
	for scaling: float in [0.0, 1.0]:
		var config := LevelConfig.new()
		config.enemy_scaling = scaling
		var made: Array = await _world(5, 2, {}, null, null, -1, config)
		var w: RunWorld = made[0]
		var dream: BadDream = made[1]
		var id: int = dream.get_instance_id()
		var marks := dream.get_node(^"LaneMarks") as MeshInstance3D
		check(not marks.visible, "no lane marks before a telegraph")
		await _until(func() -> bool: return _count(id, "telegraph") >= 1, 3.0)
		await physics_frames(3)
		check(marks.visible and marks.mesh != null, "the telegraph lights the covered lanes")
		if marks.mesh != null:
			var aabb: AABB = marks.mesh.get_aabb()
			var lo: float = w.geo.lane_x(dream.band.x) - w.geo.lane_width * 0.5
			var hi: float = w.geo.lane_x(dream.band.y) + w.geo.lane_width * 0.5
			check(aabb.position.x >= lo - 0.01 and aabb.end.x <= hi + 0.01 and aabb.size.x > (hi - lo) * 0.85,
				"exactly across the covered lanes (%.1f..%.1f of %.1f..%.1f)" % [aabb.position.x, aabb.end.x, lo, hi])
		await _until(func() -> bool: return not w.player.alive or _count(id, "slash") >= 1, 3.0)
		var t0: float = _time_of(dream, "telegraph")
		var t1: float = _time_of(dream, "slash")
		check(t1 - t0 >= t.warning_time(scaling) - 0.02 and t1 - t0 >= 0.9,
			"scaling %.0f: the claws are live %.2f s after the telegraph starts" % [scaling, t1 - t0])
		var shriek: bool = false
		var whoosh: bool = false
		for s: Array in dream.sounds:
			shriek = shriek or (s[0] == &"bad_dream_shriek" and absf(float(s[1]) - t0) < 0.001)
			whoosh = whoosh or (s[0] == &"bad_dream_slash" and float(s[1]) >= t0 + t.telegraph_time(scaling) - 0.02
				and float(s[1]) <= t1)
		check(shriek and whoosh, "it shrieks as the telegraph starts and whooshes as it lunges (%s)" % [dream.sounds])
		await sim.free_world(w)


# --- Where it goes -------------------------------------------------------------------------------

## GDD §9.7: it can't reach a ship's hull: while the player rides a ceiling it waits below (no
## telegraph, never near the hull, still in front of them) and attacks again once they're down.
func _test_waits_below_ceiling() -> void:
	var l := RunSim.layout(5, 1500.0)
	l.hulls.append({"start": 57.0, "end": 60.0 + 5.0 * tuning.run_speed})
	l.pads.append({"lane": 2, "at": 60.0})
	var made: Array = await _world(5, 2, {"chase": 30.0}, null, l)
	var w: RunWorld = made[0]
	var dream: BadDream = made[1]
	var id: int = dream.get_instance_id()
	w.player.god_mode = true
	await _until(func() -> bool: return w.player.surface == Player.Surface.CEILING, 6.0)
	check(w.player.surface == Player.Surface.CEILING, "the player took the pad")
	await _until(func() -> bool: return not dream.is_attacking(), 2.0)
	var told: int = _count(id, "telegraph")
	var highest: float = -INF
	var nearest: float = INF
	var waited: bool = false
	while w.player.surface == Player.Surface.CEILING:
		await tree.physics_frame
		highest = maxf(highest, dream.top_height())
		nearest = minf(nearest, dream.rel_ahead)
		waited = waited or dream.is_waiting()
	check(waited and _count(id, "wait") >= 1, "it waits below while the player is on the ceiling")
	check(_count(id, "telegraph") == told, "and never telegraphs up there")
	check(highest <= tuning.ceiling_height - t.hull_clearance + 0.01,
		"its head stays below the hull (top %.2f m, hull at %.1f m)" % [highest, tuning.ceiling_height])
	check(nearest > t.lunge_ahead, "and in front of the player (%.1f m ahead at the nearest)" % nearest)
	var landed: Array = [false]
	w.player.movement_event.connect(func(k: StringName) -> void: landed[0] = landed[0] or k == &"land")
	await _until(func() -> bool: return landed[0], 3.0)
	var down_at: float = w.level_time()
	await _until(func() -> bool: return _count(id, "telegraph") > told, 6.0)
	check(_count(id, "telegraph") > told and _time_of(dream, "telegraph", told) >= down_at - 0.001,
		"once the player is back down, it attacks again")
	await sim.free_world(w)


## GDD §9.7: it drifts toward the player's lane at a limited sideways speed, and follows onto a wall
## slowly (no faster than wall_follow_speed, and no wall slash before it has got there).
func _test_follows_onto_wall() -> void:
	# On the floor: it follows lane switches, never faster than drift_speed.
	var made: Array = await _world(6, 0, {"chase": 30.0}, _loadout({"claws": 1}))
	var w: RunWorld = made[0]
	var dream: BadDream = made[1]
	w.player.god_mode = true
	await physics_frames(2)
	for i: int in 5:
		w.player.press(&"move_right")
	var fastest: float = 0.0
	var prev: float = dream.rel_x
	for i: int in 90:
		await tree.physics_frame
		fastest = maxf(fastest, absf(dream.rel_x - prev) * Engine.physics_ticks_per_second)
		prev = dream.rel_x
	check(fastest <= t.drift_speed + 0.05 and fastest > t.drift_speed * 0.8,
		"it drifts toward the player's lane at a limited sideways speed (%.2f m/s)" % fastest)
	await sim.free_world(w)

	# Onto a wall: slowly, and it doesn't slash a wall runner before it's there.
	made = await _world(3, 0, {"chase": 30.0}, _loadout({"claws": 1}), null, 2)
	w = made[0]
	dream = made[1]
	var id: int = dream.get_instance_id()
	w.player.god_mode = true
	w.player.press(&"move_left")
	await _until(func() -> bool: return w.player.surface == Player.Surface.WALL, 1.0)
	check(w.player.surface == Player.Surface.WALL, "the player is on the wall")
	fastest = 0.0
	prev = dream.rel_x
	var start: float = prev
	var told: int = _count(id, "telegraph")
	# Frames that start and end with the player on the wall.
	while true:
		await tree.physics_frame
		if w.player.surface != Player.Surface.WALL:
			break
		fastest = maxf(fastest, absf(dream.rel_x - prev) * Engine.physics_ticks_per_second)
		prev = dream.rel_x
	var off_wall: float = w.level_time()
	check(fastest <= t.wall_follow_speed + 0.05 and prev < start - 1.0,
		"it follows onto the wall slowly (%.2f m/s, %.1f m)" % [fastest, start - prev])
	check(_count(id, "telegraph") == told or _time_of(dream, "telegraph", told) >= off_wall - 0.001,
		"and doesn't slash a wall it hasn't reached")
	await sim.free_world(w)


## DESIGN-TBD: once it has followed a player onto a wall, its slash covers the wall and the outer
## lane: staying on the wall is hit; wall-jumping and moving in a lane dodges it.
func _test_wall_slash() -> void:
	for escape: bool in [false, true]:
		for side: int in [-1, 1]:
			var made: Array = await _world(3, 0 if side < 0 else 2, {"chase": 30.0}, _loadout({"claws": 1}))
			var w: RunWorld = made[0]
			var dream: BadDream = made[1]
			var id: int = dream.get_instance_id()
			dream.rel_x = side * (w.geo.wall_x() - t.wall_inset)
			w.player.press(&"move_left" if side < 0 else &"move_right")
			await _until(func() -> bool: return _count(id, "telegraph") >= 1 or not w.player.alive, 3.0)
			var tag: String = "side %d" % side
			check(w.player.surface == Player.Surface.WALL and dream.band == (Vector2i(-1, 0) if side < 0 else Vector2i(2, 3)),
				"at a wall runner it covers the wall and the outer lane %s (%s)" % [tag, dream.band])
			if escape:
				await _wait(0.2)
				w.player.press(&"jump")
				await physics_frames(2)
				w.player.press(&"move_right" if side < 0 else &"move_left")
			await _until(func() -> bool: return not w.player.alive or _count(id, "recover") >= 1, 3.0)
			if escape:
				check(w.player.alive, "a wall jump and a lane switch dodge it %s (%s)" % [tag, w.player.last_event])
			else:
				check(not w.player.alive and w.player.last_event.contains(SLASH_NAME),
					"staying on the wall is hit %s (%s)" % [tag, w.player.last_event])
			await sim.free_world(w)


# --- The chase's end ------------------------------------------------------------------------------

## GDD §9.7: it slashes every ~3–4 s, stays in view, and dissolves when the chase is over; a player
## who survived it earns the bonus. One who died doesn't.
func _test_chase_end() -> void:
	var made: Array = await _world(5, 2, {"chase": 12.0})
	var w: RunWorld = made[0]
	var dream: BadDream = made[1]
	var id: int = dream.get_instance_id()
	w.player.god_mode = true
	var cam := RunCamera.new()
	w.add_child(cam)
	cam.make_current()
	cam.follow(w)
	var out_of_view: int = 0
	var frames: int = 0
	while not _gone(id) and dream.state != BadDream.State.DISSOLVE and frames < 16 * 60:
		await tree.physics_frame
		frames += 1
		if not cam.is_position_in_frustum(dream.head_point()) or cam.is_position_behind(dream.head_point()):
			out_of_view += 1
	check(out_of_view == 0, "it stays in the camera's view (%d frames out of view)" % out_of_view)
	check(dream.state == BadDream.State.DISSOLVE and absf(dream.chase_time - 12.0) < 0.05,
		"it dissolves when its chase is over (%.2f s)" % dream.chase_time)
	var starts: Array[float] = []
	for h: Array in dream.history:
		if h[0] == "telegraph":
			starts.append(float(h[1]))
	var spaced: bool = starts.size() >= 3
	for i: int in range(1, starts.size()):
		var gap: float = starts[i] - starts[i - 1]
		spaced = spaced and gap >= t.slash_interval_min - 0.02 and gap <= t.slash_interval_max + 0.05
	check(spaced, "a slash every 3–4 s (%s)" % [starts])
	check(int(w.score.bonuses.get(&"chase", 0)) == t.survival_bonus, "surviving the chase earns the bonus (%s)" % [w.score.bonuses])
	var dissolve_sound: bool = false
	for s: Array in dream.sounds:
		dissolve_sound = dissolve_sound or s[0] == &"bad_dream_dissolve"
	check(dissolve_sound and not dream.is_major_attack_active(), "it dissolves with its sound, and its chase is over")
	await _until(func() -> bool: return _gone(id), t.dissolve_time + 0.5)
	check(_gone(id) and w.director.count_alive(&"bad_dream") == 0, "then leaves play")
	await sim.free_world(w)

	# A player who didn't survive earns nothing.
	made = await _world(3, 1, {"chase": 5.0})
	w = made[0]
	dream = made[1]
	id = dream.get_instance_id()
	await _until(func() -> bool: return _gone(id) or dream.state == BadDream.State.DISSOLVE, 7.0)
	check(not w.player.alive and not w.score.bonuses.has(&"chase"), "no bonus for a player the chase killed")
	await sim.free_world(w)


## GDD §9.1/§9.7: a fence generator's EMP dissolves it early (DESIGN-TBD: without the bonus), even
## mid-telegraph: the slash never comes.
func _test_emp() -> void:
	var made: Array = await _world(3, 1, {"chase": 30.0})
	var w: RunWorld = made[0]
	var dream: BadDream = made[1]
	var id: int = dream.get_instance_id()
	await _until(func() -> bool: return _count(id, "telegraph") >= 1, 3.0)
	await _wait(0.3)
	w.emp(Vector3(0.0, 0.5, w.player.position.z - 40.0), 16.0)
	check(_count(id, "emp") == 1 and dream.state == BadDream.State.DISSOLVE and not dream.is_major_attack_active(),
		"an EMP dissolves it")
	await _until(func() -> bool: return _gone(id), t.emp_dissolve_time + 0.5)
	check(_gone(id), "early, in %.1f s" % t.emp_dissolve_time)
	check(w.player.alive and _count(id, "slash") == 0, "and the slash it was winding up never comes")
	check(not w.score.bonuses.has(&"chase"), "no survival bonus for an EMP'd chase")
	await sim.free_world(w)

	# Through a real fence generator, destroyed by the dash (GDD §9.1: weapons never set one off,
	# so a shot at it, unlike here before, would no longer do anything).
	var l := RunSim.layout(3, 800.0)
	l.fences.append(RunSim.fence(1, 70.0, "full"))
	made = await _world(3, 1, {"chase": 30.0}, null, l)
	w = made[0]
	dream = made[1]
	id = dream.get_instance_id()
	w.player.god_mode = true
	var gen := w.director.spawn({"type": "generator", "at": 61.0, "lane": 1, "side": 0, "seed": 1, "params": {}}) as Enemy
	check(not w.director.targets_ahead(gen.aim_point(), 200.0).has(gen), "auto-fire can't target it")
	await _until(func() -> bool: return 61.0 - w.player.distance <= 5.0, 6.0)
	w.player.start_dash(0.6, 0.0)
	await _until(func() -> bool: return gen == null or not gen.alive, 2.0)
	check(gen != null and not gen.alive, "the dash destroyed it")
	await physics_frames(2)
	check(_count(id, "emp") == 1 and (_gone(id) or dream.state == BadDream.State.DISSOLVE),
		"its EMP dissolves the Bad Dream")
	await sim.free_world(w)


# --- Rules ---------------------------------------------------------------------------------------

## GDD §9.7: only one on screen at a time. DESIGN-TBD: one released while another is around never
## appears, whether spawned or burst out of a second host.
func _test_one_at_a_time() -> void:
	var made: Array = await _world(5, 2, {"chase": 30.0})
	var w: RunWorld = made[0]
	var first: BadDream = made[1]
	var second := w.director.spawn({"type": "bad_dream", "at": 20.0, "lane": 1, "side": 0, "seed": 9,
		"params": {"from_host": true}}) as BadDream
	check(second != null and second.history.size() >= 2 and second.history[-1][0] == "fizzle",
		"a second one never appears")
	w.player.god_mode = true
	var host := w.director.spawn({"type": "cyborg", "at": 40.0, "lane": 2, "side": 0, "seed": 3,
		"params": {"host": true, "panic": false, "fires": false}}) as Cyborg
	await _until(func() -> bool: return host.track_distance() - w.player.distance <= 6.0, 4.0)
	w.player.start_dash(0.8, 0.0)
	await _until(func() -> bool: return not host.alive, 2.0)
	await physics_frames(3)
	check(not host.alive and w.director.count_alive(&"bad_dream") == 1 and first.alive,
		"killing another host mid-chase adds none (%d)" % w.director.count_alive(&"bad_dream"))
	await sim.free_world(w)


## GDD §9.7: never at the same time as an Octodog charge sequence or a drone barrage. While it
## chases, neither starts one; while one is on, it holds its slash.
func _test_major_attacks() -> void:
	# It chases first: an Octodog doesn't start its charges, a drone doesn't start a barrage.
	var made: Array = await _world(5, 2, {"chase": 7.0})
	var w: RunWorld = made[0]
	var dream: BadDream = made[1]
	w.player.god_mode = true
	var dog := w.director.spawn({"type": "octodog", "at": 60.0, "lane": 2, "side": 0, "seed": 4,
		"params": {"doghouse": false, "charges": 2}}) as Octodog
	var drone := w.director.spawn({"type": "drone", "at": 0.0, "lane": 2, "side": 0, "seed": 6,
		"params": {"slot": 0}}) as Enemy
	var violations: PackedStringArray = await _watch(w, [dream, dog, drone], 7.5)
	check(violations.is_empty(), "no major attack starts during its chase, nor overlaps its slash (%s)" % [violations])
	check(dream.slashes >= 1, "it slashed meanwhile (%d)" % dream.slashes)
	var dog_wound: bool = false
	for h: Array in dog.history:
		dog_wound = dog_wound or h[0] == "windup"
	check(not dog_wound and int(drone.get(&"barrages")) == 0, "the Octodog never charged and the drone never fired")
	await _until(func() -> bool: return int(drone.get(&"barrages")) >= 1, 6.0)
	check(int(drone.get(&"barrages")) >= 1, "once the chase is over, the drone fires again")
	await sim.free_world(w)

	# An Octodog's charge sequence is on first: the Bad Dream holds its slash until it's over.
	w = sim.build_world(RunSim.layout(5, 1500.0))
	w.player.setup(tuning, w.geo, 2)
	w.player.god_mode = true
	dog = w.director.spawn({"type": "octodog", "at": 60.0, "lane": 2, "side": 0, "seed": 4,
		"params": {"doghouse": false, "charges": 2}}) as Octodog
	await tree.physics_frame
	w.player.running = true
	await _until(func() -> bool: return dog.phase == Octodog.Phase.WINDUP, 5.0)
	check(dog.is_major_attack_active(), "an Octodog's wind-up starts its charge sequence")
	var dog_history: Array = dog.history  # still readable once the dog has left play
	dream = w.director.spawn({"type": "bad_dream", "at": 0.0, "lane": 2, "side": 0, "seed": 5,
		"params": {"emerge": false, "chase": 30.0}}) as BadDream
	violations = await _watch(w, [dream, dog], 9.0)
	check(violations.is_empty(), "it never slashes during the Octodog's charges (%s)" % [violations])
	var lunges: int = 0
	for h: Array in dog_history:
		if h[0] == "lunge":
			lunges += 1
	check(lunges == 2 and dream.slashes >= 1, "both still attack in turn (%d charges, %d slashes)" % [lunges, dream.slashes])
	await sim.free_world(w)

	# A drone's barrage is on first: the Bad Dream holds its slash until it's over.
	w = sim.build_world(RunSim.layout(5, 1500.0))
	w.player.setup(tuning, w.geo, 2)
	w.player.god_mode = true
	drone = w.director.spawn({"type": "drone", "at": 0.0, "lane": 2, "side": 0, "seed": 6,
		"params": {"slot": 0}}) as Enemy
	await tree.physics_frame
	w.player.running = true
	await _until(func() -> bool: return int(drone.get(&"state")) == DroneScript.State.WINDUP, 5.0)
	dream = w.director.spawn({"type": "bad_dream", "at": 0.0, "lane": 2, "side": 0, "seed": 5,
		"params": {"emerge": false, "chase": 30.0}}) as BadDream
	violations = await _watch(w, [dream, drone], 8.0)
	check(violations.is_empty(), "it never slashes during a drone barrage (%s)" % [violations])
	check(int(drone.get(&"barrages")) == 1 and dream.slashes >= 1,
		"the barrage finished, then only the Bad Dream attacked (%d barrages, %d slashes)" % [int(drone.get(&"barrages")), dream.slashes])
	await sim.free_world(w)


## Runs the world for `seconds`, checking every frame that the Bad Dream (the first enemy) never
## telegraphs or slashes while another's major attack is on, and that no other enemy starts one while
## the Bad Dream chases. Returns the violations.
func _watch(w: RunWorld, enemies: Array, seconds: float) -> PackedStringArray:
	var dream: BadDream = enemies[0]
	var out := PackedStringArray()
	var was_on: Array[bool] = []
	for e: Variant in enemies:
		was_on.append(is_instance_valid(e) and (e as Enemy).is_major_attack_active())
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		await tree.physics_frame
		var chasing: bool = is_instance_valid(dream) and dream.is_major_attack_active()
		for k: int in range(1, enemies.size()):
			var e: Variant = enemies[k]
			var on: bool = is_instance_valid(e) and (e as Enemy).alive and (e as Enemy).is_major_attack_active()
			if on and chasing and is_instance_valid(dream) and dream.is_attacking():
				out.append("%s attacks with the slash at %.2f s" % [(e as Enemy).display_name, w.level_time()])
			if on and not was_on[k] and chasing:
				out.append("%s started during the chase at %.2f s" % [(e as Enemy).display_name, w.level_time()])
			was_on[k] = on
		if out.size() > 5:
			break
	return out


# --- Generator ------------------------------------------------------------------------------------

## host_rules.gd over lane counts, seeds and difficulties: every chase fits before the end, chases
## never overlap, anti-grav pads come at most pad_gap_seconds apart through every chase, and the
## ceilings keep GDD §3; deterministic and without warnings. With drones (in either order of
## features) their pad schedule stays intact and covers the chases after the first drone; with
## Octodogs their planned charges stay off every ceiling. Without ceilings, hosts are dropped.
func _test_generator() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var dt: DroneTuning = EnemyDirector.tuning_for("drone") as DroneTuning
	var ot: OctodogTuning = EnemyDirector.tuning_for("octodog") as OctodogTuning
	var hosts: int = 0
	var with_drones: int = 0
	var with_dogs: int = 0
	var feature_sets: Array = [
		["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "host"],
		["ramps", "ceilings", "pulsing", "cyborg", "host", "drone"],
		["drone", "ceilings", "pulsing", "host", "cyborg"],
		["ramps", "ceilings", "pulsing", "octodog", "cyborg", "host"],
		["ceilings", "host", "octodog", "drone", "window_cyborg", "generator"],
	]
	for set_index: int in feature_sets.size():
		for lanes: int in [3, 5, 6]:
			for difficulty: float in [0.3, 0.6, 0.9]:
				for level_seed: int in range(1, 9):
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.lane_count = lanes
					config.difficulty = difficulty
					config.enemy_scaling = difficulty
					config.level_seed = level_seed
					config.features = PackedStringArray(feature_sets[set_index])
					var tag: String = "set=%d lanes=%d diff=%.1f seed=%d" % [set_index, lanes, difficulty, level_seed]
					var patterns: Array = LevelGenerator.load_for(config)
					var gen := LevelGenerator.new()
					var a: LevelLayout = gen.generate(config, tuning, patterns)
					check(gen.warnings.is_empty(), "host levels generate without warnings %s %s" % [tag, gen.warnings])
					var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "same seed, same hosts and pads " + tag)
					var n: int = _check_hosts(a, config, tag)
					hosts += n
					_check_ceilings(a, config, tag)
					if config.has_feature("drone"):
						_check_drone_pads(a, config, dt, tag)
						if n > 0 and HostRules.first_drone_at(a) < INF:
							with_drones += 1
					if config.has_feature("octodog"):
						with_dogs += _check_dogs(a, config, ot, tag)
	check(hosts > 100, "levels with the host feature keep hosts (%d)" % hosts)
	check(with_drones > 10, "hosts and drones share levels (%d levels)" % with_drones)
	check(with_dogs > 10, "hosts and Octodogs share levels (%d dogs)" % with_dogs)

	# Without ceilings no pad can come: the hosts are dropped, with a warning.
	var warned: bool = false
	for level_seed: int in range(1, 20):
		var config: LevelConfig = base.duplicate() as LevelConfig
		config.level_seed = level_seed
		config.features = PackedStringArray(["cyborg", "host"])
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		check(HostRules.hosts_in(layout).is_empty(), "no host without the ceilings feature")
		warned = warned or (gen.warnings.size() == 1 and gen.warnings[0].contains("ceilings"))
	check(warned, "and the rules say why")

	# Without the feature, no hosts (GDD §6); quick play (--features=cyborg,host,ceilings) reaches them.
	var plain: LevelConfig = base.duplicate() as LevelConfig
	plain.features = PackedStringArray(["ramps", "ceilings", "pulsing", "cyborg"])
	var none: LevelLayout = LevelGenerator.new().generate(plain, tuning, LevelGenerator.load_for(plain))
	check(HostRules.hosts_in(none).is_empty(), "no hosts without the host feature")
	for lanes: int in [3, 5, 6]:
		var quick: int = 0
		for level_seed: int in range(1, 5):
			var config: LevelConfig = (load("res://data/levels/prototype_level.tres") as LevelConfig).duplicate() as LevelConfig
			config.lane_count = lanes
			config.level_seed = level_seed
			for f: String in ["cyborg", "host", "ceilings"]:
				if not config.features.has(f):
					config.features.append(f)
			quick += HostRules.hosts_in(LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))).size()
		check(quick > 0, "quick play with --features=cyborg,host,ceilings meets hosts at %d lanes (%d in seeds 1–4)" % [lanes, quick])


## Checks every host's chase in one layout. Returns the number of hosts.
func _check_hosts(layout: LevelLayout, config: LevelConfig, tag: String) -> int:
	var speed: float = tuning.run_speed
	var last_ok: float = layout.length - config.end_clear_distance \
		- (t.pad_ceiling_seconds + config.hull_landing_seconds) * speed
	var pads: Array[float] = []
	for p: Dictionary in layout.pads:
		pads.append(float(p["at"]))
	pads.sort()
	var hosts: Array[Dictionary] = HostRules.hosts_in(layout)
	var prev_end: float = -INF
	for e: Dictionary in hosts:
		var s: Vector2 = t.chase_stretch(float(e["at"]), speed)
		check(s.y <= last_ok + 0.01, "a host's chase fits before the level's end (%.0f of %.0f m) %s" % [s.y, layout.length, tag])
		check(s.x >= prev_end + t.host_gap_seconds * speed - 0.01, "chases never overlap %s" % tag)
		prev_end = s.y
		var cursor: float = s.x
		var worst: float = 0.0
		for p: float in pads:
			if p > s.x and p <= s.y:
				worst = maxf(worst, p - cursor)
				cursor = p
		worst = maxf(worst, s.y - cursor)
		check(worst <= t.pad_gap_seconds * speed + 0.01,
			"anti-grav pads through the whole chase: at most %.1f s apart (%.1f s) %s" % [t.pad_gap_seconds, worst / speed, tag])
		check(not bool(e["params"].get("panic", true)), "hosts don't panic " + tag)
	return hosts.size()


## GDD §3 for every ceiling: a pad under a hull, on solid floor; nothing on the floor beneath it; a
## clear landing; all before the finish.
func _check_ceilings(layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var landing: float = config.hull_landing_seconds * tuning.run_speed
	var finish: float = layout.length - config.end_clear_distance + 0.001
	for p: Dictionary in layout.pads:
		var covered: bool = false
		for h: Dictionary in layout.hulls:
			covered = covered or (float(h["start"]) <= float(p["at"]) - 1.0 and float(h["end"]) >= float(p["at"]) + 10.0)
		check(covered, "pad at %.0f has a ceiling above %s" % [p["at"], tag])
		check(not layout.gapped_between(int(p["lane"]), float(p["at"]) - 6.0, float(p["at"]) + tuning.pad_length),
			"pad at %.0f is on solid floor %s" % [p["at"], tag])
	for h: Dictionary in layout.hulls:
		check(float(h["end"]) + landing <= finish, "ceiling and landing before the finish " + tag)
		for g: Dictionary in layout.gaps:
			check(float(g["start"]) > float(h["end"]) + landing * 0.8 or float(g["end"]) < float(h["start"]),
				"no gap under a ceiling or on its landing " + tag)
		for f: Dictionary in layout.fences:
			check(float(f["at"]) < float(h["start"]) or float(f["at"]) > float(h["end"]), "no fence under a ceiling " + tag)
		for e: Dictionary in layout.enemies:
			if int(e.get("side", 0)) == 0 and LevelGenerator.enemy_uses_floor(e):
				check(float(e["at"]) < float(h["start"]) or float(e["at"]) > float(h["end"]),
					"no floor enemy under a ceiling (%s) %s" % [e["type"], tag])


## The drone rules (GDD §9.6) still hold with hosts about: at least 10 s of dodging before the first
## pad after each drone, then pads 8–10 s apart (the host rules add none after the first drone).
func _check_drone_pads(layout: LevelLayout, config: LevelConfig, dt: DroneTuning, tag: String) -> void:
	var speed: float = tuning.run_speed
	var drones: Array[float] = []
	for e: Dictionary in layout.enemies:
		if String(e["type"]) == "drone":
			drones.append(float(e["at"]))
	drones.sort()
	var pads: Array[float] = []
	for p: Dictionary in layout.pads:
		if not pads.has(float(p["at"])):
			pads.append(float(p["at"]))
	pads.sort()
	for d: float in drones:
		var first: float = INF
		for p: float in pads:
			if p > d + 0.01:
				first = p
				break
		check(first < INF and (first - d) / speed >= dt.first_pad_seconds - 0.001,
			"at least %d s of dodging before a drone's first pad (%.2f s) %s" % [dt.first_pad_seconds, (first - d) / speed, tag])
	if drones.is_empty():
		return
	var schedule_start: float = INF
	for p: float in pads:
		if p > drones[0] + 0.01:
			schedule_start = p
			break
	for i: int in pads.size() - 1:
		if pads[i] < schedule_start - 0.01:
			continue
		var gap: float = (pads[i + 1] - pads[i]) / speed
		check(gap >= dt.pad_repeat_min_seconds - 0.001 and gap <= dt.pad_repeat_max_seconds + 0.001,
			"the drone's pads stay 8–10 s apart (%.2f s at %.0f m) %s" % [gap, pads[i], tag])


## Planned Octodog charges stay clear of every ceiling, hosts' pads included. Returns the dog count.
func _check_dogs(layout: LevelLayout, config: LevelConfig, ot: OctodogTuning, tag: String) -> int:
	var speed: float = tuning.run_speed
	var window: float = ot.window_length(speed, config.enemy_scaling)
	var stop: float = ot.stop_distance(speed, config.enemy_scaling)
	var n: int = 0
	for e: Dictionary in layout.enemies:
		if String(e["type"]) != "octodog":
			continue
		n += 1
		var at: Array = e["params"].get("charge_at", [])
		for a: Variant in at:
			check(Octodog.window_clear(layout, float(a), float(a) + window), "an Octodog charge stays clear of ceilings " + tag)
		if not at.is_empty():
			check(not Octodog.ceiling_between(layout, float(at[0]) - 6.0, float(at[-1]) + stop + 2.0),
				"its whole run stays off ceiling sections " + tag)
	return n
