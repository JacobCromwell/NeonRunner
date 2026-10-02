class_name TheHouseWalls
extends RefCounted
## The House's wall fences (GDD §10, phase 2: "one on a wall, with wall fences in play"; GDD §9.1: full-height
## wall fences from Marketplace 2, passed by timing). In the phases TheHouseTuning.wall_fence_phases lists,
## full-height wall fences (task B5: LevelLayout.wall_fences entries, WallFencePlan) stand along both walls,
## one every wall_fence_every seconds of run on alternating walls, pulsing wall_fence_on on and
## wall_fence_off off on the level clock with the floor fence's warning before each switch on. They're
## track pieces: planned past the built track a batch at a time (BossArena.stream_from, add_pieces), each held to the level's rules on the arena's track first (BossArena.wall_fence_problem),
## built and pulsing like a level's (TrackBuilder), so DamageRules and their looks are B5's.
## The fight reads them here: the wall button's plan passes a wall fence only while it's off (passage_off),
## and the machine's strikes keep off their drop windows (in_drop_window: B5's rule that no big attack
## reaches the outer lane a wall runner drops into when one switches on). Nothing here draws.

var boss: TheHouse
var tuning: TheHouseTuning
var world: RunWorld
## Every wall fence planned this fight, in track order (WallFencePlan entries).
var entries: Array[Dictionary] = []
## Wall fences left out for a rule of the level's (wall_fence_problem), for tests.
var refused: int = 0

var _active: bool = false
var _next_at: float = -1.0
var _side: int = -1


func _init(p_boss: TheHouse) -> void:
	boss = p_boss
	tuning = boss.tuning
	world = boss.world


## Starts or stops planning them (a phase that has them begins, or one without).
func set_active(on: bool) -> void:
	_active = on
	if on and _next_at < 0.0:
		_next_at = 0.0


func active() -> bool:
	return _active


## Plans the next ones past the built track (wall_fence_ahead seconds of run past it), a batch at a time:
## once the track is built up to within a spacing of the next one to plan.
func tick() -> void:
	if not _active or boss.arena == null:
		return
	var v: float = boss.speed()
	var from: float = boss.arena.stream_from() + 1.0
	if _next_at > from + tuning.wall_fence_every * v:
		return
	var at: float = maxf(_next_at, from)
	var until: float = from + tuning.wall_fence_ahead * v
	var extra := LevelLayout.new()
	extra.lane_count = boss.lane_count()
	while at <= until:
		var entry: Dictionary = WallFencePlan.make(_side, at, "full", tuning.wall_fence_on, tuning.wall_fence_off,
			fposmod(at * 0.137, 1.0))
		_side = -_side
		var problem: String = boss.arena.wall_fence_problem(entry)
		if problem == "":
			extra.wall_fences.append(entry)
			entries.append(entry)
		else:
			refused += 1
		at += tuning.wall_fence_every * v
	_next_at = at
	if not extra.wall_fences.is_empty():
		boss.arena.add_pieces(extra)
		boss.log_event(&"wall_fences", {"count": extra.wall_fences.size(), "until": at})


## The level time when the runner reaches track distance `d` at their speed now.
func time_at(d: float) -> float:
	return world.level_time() + (d - world.player.distance) / boss.speed()


## True if every wall fence on wall `side` whose field lies between track distances `from` and `to`
## stays off (never on; its harmless warning may show) while a runner who passes `from` at level time `t0`
## at speed `v` goes by it, from `margin` seconds before to `margin` after.
func passage_off(side: int, from: float, to: float, t0: float, v: float, margin: float) -> bool:
	var half: float = world.tuning.fence_depth * 0.5 + world.tuning.hurtbox_size.z * 0.5
	for e: Dictionary in entries:
		if int(e["side"]) != side:
			continue
		var at: float = float(e["at"])
		if at + half < from or at - half > to:
			continue
		var t_pass: float = t0 + (at - from) / maxf(v, 0.1)
		var t_from: float = t_pass - half / maxf(v, 0.1) - margin
		var t_to: float = t_pass + half / maxf(v, 0.1) + margin
		if WallFencePlan.state_at(e, t_from, world.tuning.fence_pulse_warning) == Hazard.State.ON:
			return false
		if WallFencePlan.next_on(e, t_from) <= t_to:
			return false
	return true


## B5's drop window of each wall fence: where a wall runner who sees it switch on drops into the outer
## lane on its side, [at - drop_before_seconds, at + drop_after_seconds] at the run speed: {side, from, to}.
func drop_windows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wt: WallFenceTuning = _wall_tuning()
	var v: float = boss.speed()
	var d: float = world.player.distance
	for e: Dictionary in entries:
		var at: float = float(e["at"])
		var to: float = at + wt.drop_after_seconds * v
		if to < d - 5.0:
			continue
		out.append({"side": int(e["side"]), "from": at - wt.drop_before_seconds * v, "to": to})
	return out


## True if any of `obstacles` (TheHouseRoute.obstacle entries) lies in an outer lane over a wall fence's
## drop window on its side.
func in_drop_window(obstacles: Array[Dictionary]) -> bool:
	if entries.is_empty():
		return false
	var last: int = boss.lane_count() - 1
	var windows: Array[Dictionary] = drop_windows()
	for o: Dictionary in obstacles:
		var lane: int = int(o["lane"])
		if lane != 0 and lane != last:
			continue
		var side: int = -1 if lane == 0 else 1
		if last == 0:
			side = 0
		for w: Dictionary in windows:
			if (side == 0 or int(w["side"]) == side) and float(o["from"]) <= float(w["to"]) \
					and float(o["to"]) >= float(w["from"]):
				return true
	return false


## The wall fences' own numbers (the level's: B5's data/tuning/wall_fences.tres).
func _wall_tuning() -> WallFenceTuning:
	return WallFencePlacement.tuning()
