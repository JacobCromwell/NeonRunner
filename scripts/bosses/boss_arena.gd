class_name BossArena
extends RefCounted
## A boss fight's track (GDD §10: a fight has no time limit; GDD §6: handmade arenas are allowed
## within the generator system). The level generator plans a few laps from the boss's arena config
## (BossDef.arena: one lap's seed, features, difficulty, pacing and skin; its duration_seconds sets the
## lap's length), each lap from its own seed, and the boss script may shape each one
## (BossEncounter._plan_lap: its own set pieces, like a train's carriage gaps). The fight runs through
## the laps in turn, over and over: the next lap joins the track (TrackBuilder.extend_layout) a whole
## lap before the player gets there, so the track keeps going for as long as the fight lasts and is the
## same on every attempt. A boss without an arena config fights on a plain track (floor and walls).
##
## During the fight a boss script adds track pieces of its own with add_pieces(): holes, fences, pads
## with ceilings, ramps, signs and enemies, planned past the built track (stream_from()), then built
## and brought into play like the rest of the arena. Things that appear within sight (a fence rolled
## across the lanes, a block slammed down, a wall taken away) are BossProps instead.
##
## Nothing in a lap ramps up (GDD §10: no escalation), and laps carry no credits (DESIGN-TBD: in a
## fight with no time limit, credits along the track would pay players for stalling; beating the boss
## pays instead). Enemies a lap lists come into play like a level's: the director spawns those of the
## laps planned before the world was built, the arena those added later, each at its type's lead.
##
## Pace (GDD §3: the run speed rises zone by zone, and a boss fight runs at its zone's speed like the
## zone's levels): the arena is planned at its config's run speed (LevelConfig.movement_for: its zone's
## in the campaign, Campaign.configure_boss; the base speed in quick play and the tests), as the
## generator builds a level, so its patterns keep their seconds; the clear stretches at a lap's start
## and end are metres at MovementTuning.REFERENCE_SPEED like the patterns, stretched by the pace too
## (the first lap's start is the boss's entrance). A boss script's own numbers in metres follow the
## same pace (tuning.pace(), the run's: world.tuning.pace() once the world is built), so its fight
## plays the same in seconds at every zone's speed.

## Laps kept on the track beyond the one the player is in.
const LAPS_AHEAD: int = 1
## Piece lists of a LevelLayout the track builder builds (the others are credits and enemies).
const TRACK_PIECES: PackedStringArray = ["gaps", "fences", "signs", "hulls", "pads", "ramps", "speed_pads"]

## One lap's generator settings, ready to generate (base_config, then lane count and difficulty).
var config: LevelConfig
## The fight's movement tuning, at the arena's run speed (config.movement_for): its pace() stretches
## the arena's and the boss's metres.
var tuning: MovementTuning
## Metres per lap: the lap's duration at run speed.
var lap_length: float = 0.0
## The distinct laps, each starting at 0. Lap k of the fight is laps[k % laps.size()], moved along.
var laps: Array[LevelLayout] = []
## The run's layout (the world's): it grows a lap at a time.
var layout: LevelLayout
## Laps on the track so far.
var laps_joined: int = 0
var world: RunWorld

## Enemies added after the world was built, in order, with the distance where each spawns.
var _enemies: Array[Dictionary] = []
var _next_enemy: int = 0


## The arena's generator settings for `def`: a copy of its arena config (a plain one without), with
## nothing ramping within the fight and every feature there from the start. Its run speed is the
## arena config's own (0, the usual: the movement tuning's base speed, as in quick play and the tests);
## the campaign gives it its zone's (Campaign.configure_boss).
static func base_config(def: BossDef) -> LevelConfig:
	var out: LevelConfig = def.arena.duplicate() as LevelConfig if def.arena != null else LevelConfig.new()
	if def.arena == null:
		out.features = PackedStringArray()
	out.id = StringName("%s_arena" % def.id)
	out.display_name = def.display_name
	out.difficulty_ramp = 0.0
	# A new dictionary: a copy shares the original's.
	out.feature_starts = {}
	return out


## Plans the arena for a fight against `def`: the distinct laps, from `p_config` (base_config with the
## lane count and difficulty set) at its run speed (p_config.movement_for(p_tuning): its own, its
## zone's in the campaign, else `p_tuning`'s), each shaped by `encounter`'s _plan_lap if given, and the
## first laps of the track.
static func plan(def: BossDef, p_config: LevelConfig, p_tuning: MovementTuning,
		encounter: BossEncounter = null) -> BossArena:
	var arena := BossArena.new()
	arena.config = p_config
	arena.tuning = p_config.movement_for(p_tuning)
	arena.lap_length = maxf(arena.tuning.run_speed * p_config.duration_seconds, TrackBuilder.BUILD_AHEAD * 2.0)
	var generated: bool = def.arena != null
	var patterns: Array = LevelGenerator.load_for(p_config) if generated else []
	for i: int in (maxi(def.arena_laps, 1) if generated else 1):
		var lap: LevelLayout = arena._generate(i, patterns) if generated else arena._plain()
		if encounter != null:
			encounter._plan_lap(lap, i, arena)
		arena.laps.append(lap)
	arena.layout = LevelLayout.new()
	arena.layout.lane_count = p_config.lane_count
	while arena.laps_joined <= LAPS_AHEAD:
		arena._join(arena.lap(arena.laps_joined))
	return arena


## A copy of `source` moved `offset` metres along the track: every piece's at, start and end, and an
## enemy's planned floor span.
static func shifted(source: LevelLayout, offset: float) -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = source.lane_count
	out.length = source.length + offset
	var from: Dictionary = source.to_dict()
	var to: Dictionary = out.to_dict()
	for key: String in from:
		if from[key] is Array and to.get(key) is Array:
			for item: Dictionary in from[key]:
				(to[key] as Array).append(_shift(item, offset))
	return out


## The world this arena's track runs in (LevelRun builds it from `layout`, then the encounter calls
## this).
func attach(p_world: RunWorld) -> void:
	world = p_world


## Lap `index` of the fight: one of the distinct laps, starting at index × lap_length.
func lap(index: int) -> LevelLayout:
	return BossArena.shifted(laps[index % laps.size()], index * lap_length)


## The lap the track distance `d` falls in.
func lap_at(d: float) -> int:
	return maxi(floori(d / lap_length), 0)


## Keeps LAPS_AHEAD laps on the track beyond the player's, and brings enemies added during the fight
## into play as the player comes within their spawn lead. The encounter calls this every physics frame.
func update(player_distance: float) -> void:
	while laps_joined <= lap_at(player_distance) + LAPS_AHEAD:
		_join(lap(laps_joined))
	if world == null:
		return
	while _next_enemy < _enemies.size() and player_distance >= float(_enemies[_next_enemy]["spawn_at"]):
		world.director.spawn(_enemies[_next_enemy])
		_next_enemy += 1


## The nearest track distance where add_pieces() may put track pieces: the end of the built track.
func stream_from() -> float:
	return world.track.built_until() if world != null else 0.0


## Adds a boss script's own pieces to the track during the fight (track distances; build them with
## the LevelLayout lists: gaps, fences, signs, hulls, pads, ramps, speed_pads, enemies). Track pieces
## must start at or past stream_from(); nearer ones are left out with a warning (use BossProps within
## sight). Enemies come into play at their type's spawn lead like the rest. Returns how many pieces
## were added.
func add_pieces(extra: LevelLayout) -> int:
	var from: float = stream_from()
	var kept := LevelLayout.new()
	kept.lane_count = layout.lane_count
	kept.length = layout.length
	var lists: Dictionary = extra.to_dict()
	var into: Dictionary = kept.to_dict()
	var count: int = 0
	for key: String in TRACK_PIECES:
		for item: Dictionary in lists[key]:
			if float(item.get("start", item.get("at", 0.0))) < from - 0.001:
				push_warning("BossArena: a %s at %.0f m is within the built track (from %.0f m); left out" % [
					key.trim_suffix("s"), float(item.get("start", item.get("at", 0.0))), from])
				continue
			(into[key] as Array).append(item)
			count += 1
	for e: Dictionary in extra.enemies:
		kept.enemies.append(e)
		count += 1
	kept.length = maxf(layout.length, extra.length)
	_join_pieces(kept)
	return count


## True if the floor between two track distances has no hole and no working fence, in `lane` or, with
## -1, in every lane: for fair attacks (a dodge never has to happen during a jump or into a lane the
## player can't use) and for spots the player must run up to.
func floor_clear(from: float, to: float, lane: int = -1) -> bool:
	return not hole_between(from, to, lane) and not live_fence_between(from, to, lane)


## True if a hole in `lane` (every lane with -1) reaches into [from, to] (a cluster baited into it).
func hole_between(from: float, to: float, lane: int = -1) -> bool:
	for g: Dictionary in layout.gaps:
		if (lane < 0 or int(g["lane"]) == lane) and float(g["start"]) <= to and float(g["end"]) >= from:
			return true
	return false


## True if a fence that's still working (not switched off by an EMP) stands in `lane` (every lane with
## -1) within [from, to]. Whether a pulsing one is on at a given moment is its hazard's state
## (world.track.fence_hazards()).
func live_fence_between(from: float, to: float, lane: int = -1) -> bool:
	for f: Dictionary in layout.fences:
		if (lane < 0 or int(f["lane"]) == lane) and not f.get("disabled", false) \
				and float(f["at"]) >= from and float(f["at"]) <= to:
			return true
	return false


## True if a ceiling section reaches into [from, to].
func ceiling_between(from: float, to: float) -> bool:
	return not pieces_between("hulls", from, to).is_empty()


## The pieces of one of the layout's lists ("pads", "hulls", "ramps", ...) that reach into
## [from, to], in track order: where the track offers a pad or a ramp to a boss's stomp window.
func pieces_between(kind: String, from: float, to: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Variant = layout.to_dict().get(kind)
	if not (list is Array):
		return out
	for item: Dictionary in list:
		var start: float = float(item.get("start", item.get("at", 0.0)))
		var end: float = float(item.get("end", start))
		if start <= to and end >= from:
			out.append(item)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("start", a.get("at", 0.0))) < float(b.get("start", b.get("at", 0.0))))
	return out


func _join(next: LevelLayout) -> void:
	laps_joined += 1
	_join_pieces(next)


func _join_pieces(next: LevelLayout) -> void:
	if world == null:
		# Before the world is built: straight into the layout it's built from.
		var to: Dictionary = layout.to_dict()
		var from: Dictionary = next.to_dict()
		for key: String in from:
			if from[key] is Array and to.get(key) is Array:
				(to[key] as Array).append_array(from[key])
		layout.length = maxf(layout.length, next.length)
		return
	var enemies: Array[Dictionary] = next.enemies.duplicate()
	world.track.extend_layout(next)
	for e: Dictionary in enemies:
		var entry: Dictionary = e.duplicate()
		entry["spawn_at"] = float(e["at"]) - EnemyDirector.lead_for(String(e["type"]))
		_enemies.append(entry)
	var pending: Array[Dictionary] = _enemies.slice(_next_enemy)
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["spawn_at"] < b["spawn_at"])
	_enemies.resize(_next_enemy)
	_enemies.append_array(pending)


func _generate(index: int, patterns: Array) -> LevelLayout:
	var lap_config: LevelConfig = config.duplicate() as LevelConfig
	lap_config.level_seed = hash([config.level_seed, index])
	# The clear stretches at its start and end keep their seconds (the header's Pace).
	lap_config.start_clear_distance = config.start_clear_distance * tuning.pace()
	lap_config.end_clear_distance = config.end_clear_distance * tuning.pace()
	var gen := LevelGenerator.new()
	var out: LevelLayout = gen.generate(lap_config, tuning, patterns)
	for line: String in gen.warnings:
		push_warning("BossArena: " + line)
	# DESIGN-TBD: no credits on a boss fight's track (see the header).
	out.credits.clear()
	out.length = lap_length
	return out


func _plain() -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = config.lane_count
	out.length = lap_length
	return out


static func _shift(item: Dictionary, offset: float) -> Dictionary:
	var out: Dictionary = item.duplicate(true)
	for key: String in ["at", "start", "end"]:
		if out.has(key):
			out[key] = float(out[key]) + offset
	var params: Variant = out.get("params")
	if params is Dictionary and (params as Dictionary).get("floor_span") is Vector2:
		params["floor_span"] = (params["floor_span"] as Vector2) + Vector2(offset, offset)
	return out
