class_name BossArena
extends RefCounted
## A boss fight's track (GDD §10: a fight has no time limit; GDD §6: handmade arenas are allowed
## within the generator system). The level generator plans a few laps from the boss's arena config
## (BossDef.arena: one lap's seed, features, difficulty and pacing; its duration_seconds sets the lap's
## length), each lap from its own seed. The fight runs through them in turn, over and over: the next
## lap joins the track (TrackBuilder.extend_layout) a whole lap before the player gets there, so the
## track keeps going for as long as the fight lasts and is the same on every attempt. A boss without an
## arena config fights on a plain track (floor and walls).
##
## Nothing in a lap ramps up (GDD §10: no escalation), and laps carry no credits (DESIGN-TBD: in a
## fight with no time limit, credits along the track would pay players for stalling; beating the boss
## pays instead). Enemies a lap lists come into play like a level's: the director spawns those of the
## laps planned before the world was built, the arena those of the laps it joins later, each at its
## type's spawn lead.
##
## Boss scripts ask the arena about the track: floor_clear(), pieces_between(), lap_at().

## Laps kept on the track beyond the one the player is in.
const LAPS_AHEAD: int = 1

## One lap's generator settings, ready to generate (base_config, then lane count and difficulty).
var config: LevelConfig
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

## Enemies of the laps joined while the world runs, in order, with the distance where each spawns.
var _enemies: Array[Dictionary] = []
var _next_enemy: int = 0


## The arena's generator settings for `def`: a copy of its arena config (a plain one without), with
## nothing ramping within the fight and every feature there from the start.
static func base_config(def: BossDef) -> LevelConfig:
	var config: LevelConfig = def.arena.duplicate() as LevelConfig if def.arena != null else LevelConfig.new()
	if def.arena == null:
		config.features = PackedStringArray()
	config.id = StringName("%s_arena" % def.id)
	config.display_name = def.display_name
	config.difficulty_ramp = 0.0
	# A new dictionary: a copy shares the original's.
	config.feature_starts = {}
	return config


## Plans the arena for a fight against `def`: the distinct laps, from `p_config` (base_config with
## the lane count and difficulty set) at `p_tuning`'s run speed, and the first laps of the track.
static func plan(def: BossDef, p_config: LevelConfig, p_tuning: MovementTuning) -> BossArena:
	var arena := BossArena.new()
	arena.config = p_config
	arena.tuning = p_tuning
	arena.lap_length = maxf(p_tuning.run_speed * p_config.duration_seconds, TrackBuilder.BUILD_AHEAD * 2.0)
	var generated: bool = def.arena != null
	var patterns: Array = LevelGenerator.load_for(p_config) if generated else []
	for i: int in (maxi(def.arena_laps, 1) if generated else 1):
		arena.laps.append(arena._generate(i, patterns) if generated else arena._plain())
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


## The world this arena's track runs in (LevelRun builds it from `layout`, then calls this).
func attach(p_world: RunWorld) -> void:
	world = p_world


## Lap `index` of the fight: one of the distinct laps, starting at index × lap_length.
func lap(index: int) -> LevelLayout:
	return BossArena.shifted(laps[index % laps.size()], index * lap_length)


## The lap the track distance `d` falls in.
func lap_at(d: float) -> int:
	return maxi(floori(d / lap_length), 0)


## Keeps LAPS_AHEAD laps on the track beyond the player's, and brings the enemies of laps joined
## during the fight into play as the player comes within their spawn lead. The encounter calls this
## every physics frame.
func update(player_distance: float) -> void:
	while laps_joined <= lap_at(player_distance) + LAPS_AHEAD:
		_join(lap(laps_joined))
	if world == null:
		return
	while _next_enemy < _enemies.size() and player_distance >= float(_enemies[_next_enemy]["spawn_at"]):
		world.director.spawn(_enemies[_next_enemy])
		_next_enemy += 1


## True if the floor between two track distances has no hole and no working fence, in `lane` or, with
## -1, in every lane: for fair attacks (a dodge never has to happen during a jump or into a lane the
## player can't use) and for spots the player must run up to.
func floor_clear(from: float, to: float, lane: int = -1) -> bool:
	for g: Dictionary in layout.gaps:
		if (lane < 0 or int(g["lane"]) == lane) and float(g["start"]) <= to and float(g["end"]) >= from:
			return false
	for f: Dictionary in layout.fences:
		if (lane < 0 or int(f["lane"]) == lane) and not f.get("disabled", false) \
				and float(f["at"]) >= from and float(f["at"]) <= to:
			return false
	return true


## The pieces of one kind of the layout's lists ("pads", "hulls", "ramps", ...) that reach into
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
	if world == null:
		# Before the world is built: straight into the layout it's built from.
		var to: Dictionary = layout.to_dict()
		var from: Dictionary = next.to_dict()
		for key: String in from:
			if from[key] is Array and to.get(key) is Array:
				(to[key] as Array).append_array(from[key])
		layout.length = next.length
		return
	world.track.extend_layout(next)
	for e: Dictionary in next.enemies:
		var entry: Dictionary = e.duplicate()
		entry["spawn_at"] = float(e["at"]) - EnemyDirector.lead_for(String(e["type"]))
		_enemies.append(entry)
	_enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["spawn_at"] < b["spawn_at"])


func _generate(index: int, patterns: Array) -> LevelLayout:
	var lap_config: LevelConfig = config.duplicate() as LevelConfig
	lap_config.level_seed = hash([config.level_seed, index])
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
