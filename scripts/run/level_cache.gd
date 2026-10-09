class_name LevelCache
extends RefCounted
## The last level a run built, kept so that a retry starts at once (task PERF2, the owner's approval of
## October 9, 2026). Generating its level is the slow part of starting a run: a late campaign level takes
## seconds on a desktop and several times that on a phone (the generator builds it again for each feature
## its guarantee finds missing), and a campaign level comes out the same on every attempt (GDD §6: a fixed
## seed; RunContext.retry). So LevelRun takes a level's layout from here (layout_for): the generator's
## build the first time, then a copy of that build for every run of the same level, as long as everything
## the build reads is the same (key_for):
## - the level config: every value it stores (seed, lane count, difficulty, features and their starts,
##   pacing, the campaign's recency curve and ages, ...), its look (`skin`) aside, which the generator never
##   reads (zones are skins, CLAUDE.md principle 2);
## - the movement tuning the level is built at (LevelConfig.movement_for);
## - the patterns, as read from their files now (LevelGenerator.load_for);
## - every tuning resource in TUNING_DIRS (the placement tunings and the enemy types' tunings the generator
##   and its rules read), by value: a change in the live tuning panel (F6) builds the level again;
## - the build flavor.
## A different seed, lane count, level or setting builds again, and only the last level is kept. Endless
## mode always builds (each of its runs has a random seed) and keeps nothing; a boss fight's arena plans its
## own laps (BossEncounter.plan_arena, 6 to 25 ms here) and never comes here.
##
## The kept build is never handed out: every run plays its own LevelLayout.copy(), the first run too,
## since a run changes its layout as it goes (an EMP switches fences off in it, the track numbers its fences,
## a boss arena's next lap or endless mode's next stretch joins it, and an enemy's entry is the enemy's own
## one level deep only). A layout holds plain data (no Object, and no list or dictionary in two places), so a
## copy plays exactly as the build would. The build's generator warnings come with every copy, for LevelRun
## to print as it always has.
##
## A tunable the generator reads from anywhere but the config, the movement tuning, the patterns and
## TUNING_DIRS must join the key here, or a run after a change to it could play the level built before.
## (tests/helpers/layout_cache.gd is the tests' own cache of generated layouts, unrelated to this one.)

## The folders of the tuning resources the generator and its rules read: data/tuning (the placement passes',
## the power-ups') and data/enemies (every enemy type's, EnemyDirector.tuning_for). Small resources only.
const TUNING_DIRS: PackedStringArray = ["res://data/tuning", "res://data/enemies"]
## Stored properties that name a resource rather than hold its data.
const RESOURCE_SKIP: PackedStringArray = ["resource_path", "resource_name", "resource_local_to_scene", "script"]
## The level config's: RESOURCE_SKIP and its look, which the generator never reads (and which would take a
## whole zone skin's tree of meshes and materials to sign).
const CONFIG_SKIP: PackedStringArray = ["resource_path", "resource_name", "resource_local_to_scene", "script",
	"skin"]
## Sub-resources nested deeper than this are named by their path alone (no tuning nests so deep: a guard).
const MAX_DEPTH: int = 6

## Off: every run builds its level, as before this cache (tests and tools compare the two).
static var enabled: bool = true
## True if the last layout_for() handed out a copy of the kept build, false if it built the level.
static var last_reused: bool = false
## The generator's warnings for the layout the last layout_for() handed out (its build's).
static var warnings: PackedStringArray = []

static var _key: String = ""
static var _layout: LevelLayout = null
static var _warnings: PackedStringArray = []


## The layout for `context`'s level (not a boss fight's), its build's warnings in `warnings`: a copy of the
## kept build if key_for() matches it, else a new build, kept for the next run (in endless mode, or with the
## cache off, the new build itself, kept for none).
static func layout_for(context: RunContext) -> LevelLayout:
	var patterns: Array = LevelGenerator.load_for(context.config)
	var keep: bool = enabled and context.mode != RunContext.Mode.ENDLESS
	var key: String = key_for(context.config, context.tuning, patterns) if keep else ""
	last_reused = keep and _layout != null and key == _key
	if not last_reused:
		var gen := LevelGenerator.new()
		var built: LevelLayout = gen.generate(context.config, context.tuning, patterns)
		if not keep:
			warnings = gen.warnings.duplicate()
			return built
		_key = key
		_layout = built
		_warnings = gen.warnings.duplicate()
	warnings = _warnings.duplicate()
	return _layout.copy()


## Drops the kept build: the next run builds its level.
static func forget() -> void:
	_key = ""
	_layout = null
	_warnings = PackedStringArray()


## Everything a build of `config` at `tuning` from `patterns` reads, as one string (see the header): two
## builds with the same key make the same layout.
static func key_for(config: LevelConfig, tuning: MovementTuning, patterns: Array) -> String:
	var parts: Array = [BuildFlavor.current(), _sign(config, CONFIG_SKIP), _sign(config.movement_for(tuning)),
		_sign(patterns)]
	for dir: String in TUNING_DIRS:
		var files: PackedStringArray = ResourceLoader.list_directory(dir)
		files.sort()
		for file: String in files:
			if file.ends_with(".tres") or file.ends_with(".res"):
				parts.append([file, _sign(load(dir.path_join(file)))])
	return var_to_str(parts)


## `value` as plain data for the key: a resource as its class and stored properties (`skip` aside), its
## sub-resources likewise; a dictionary as its [key, value] pairs in their order (var_to_str would sort them);
## lists item by item.
static func _sign(value: Variant, skip: PackedStringArray = RESOURCE_SKIP, depth: int = 0) -> Variant:
	if value is Resource:
		var res: Resource = value
		var script: Script = res.get_script() as Script
		var out: Array = [res.get_class(), script.resource_path if script != null else ""]
		if depth >= MAX_DEPTH:
			out.append(res.resource_path)
			return out
		for prop: Dictionary in res.get_property_list():
			var prop_name: String = prop["name"]
			if int(prop["usage"]) & PROPERTY_USAGE_STORAGE and not skip.has(prop_name):
				out.append([prop_name, _sign(res.get(prop_name), RESOURCE_SKIP, depth + 1)])
		return out
	if value is Object:
		return str(value)
	if value is Dictionary:
		var pairs: Array = ["{}"]
		for k: Variant in value:
			pairs.append([_sign(k, RESOURCE_SKIP, depth), _sign((value as Dictionary)[k], RESOURCE_SKIP, depth)])
		return pairs
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_sign(item, RESOURCE_SKIP, depth))
		return items
	return value
