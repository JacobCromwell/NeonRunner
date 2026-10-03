class_name LayoutCache
extends RefCounted
## Test-only cache of built level layouts, shared by every suite in one `tools/godot.sh test` run
## (T-SPEED). LevelGenerator.generate() is a pure function of (config, tuning, patterns) -- the same
## three inputs always build the identical layout (test_layout_cache.gd proves it against a fresh,
## uncached build) -- so the many suites that build the same level again and again (the same config
## content, seed, lane count and difficulty: often a campaign step's own default build, which several
## suites generate independently just to run their own checks on it) can share one real build instead
## of repeating it.
##
## generate() and generator() always hand the caller something it can freely mutate: a fresh
## LevelLayout.copy() (LevelLayout.copy(), scripts/world/level_layout.gd) of whatever is cached, never
## the cached instance itself, so no suite can corrupt another's cached layout by accident.
##
## `enabled` (off with run_tests.gd's --no-layout-cache) turns caching off for a whole run: every call
## then builds fresh, exactly as before this cache existed. A suite that must prove a fresh build
## matches a cached one calls clear() first for a known-empty cache and clean hit/miss counts.
##
## Caching only ever replaces ONE side of a suite's own "does regenerating give the same layout"
## check: its own explicit second, uncached `LevelGenerator.new().generate(...)` (or a second call to
## this cache after clear()) stays a real, independent build. Routing *both* sides through this cache
## with the same key would make such a check trivially pass without ever running the generator twice,
## which is not a cache win, it's a weaker check -- so suite authors never do that.

static var enabled: bool = true
static var hits: int = 0
static var misses: int = 0


class _Entry:
	var layout: LevelLayout
	## The fields a real generate() sets beyond the layout, that LevelGenerator.for_layout's cheap
	## setup does not (generator(), below).
	var warnings: PackedStringArray
	var attempts: int
	var picks: Array[Dictionary]
	var fills: Array[Dictionary]


static var _cache: Dictionary = {}  ## String signature (_key) -> _Entry


## Resets the cache and its hit/miss counters.
static func clear() -> void:
	_cache.clear()
	hits = 0
	misses = 0


## A layout for (config, tuning, patterns): a real `LevelGenerator.new().generate()` the first time
## this exact content is asked for in the run, and a `copy()` of that build every time after.
static func generate(config: LevelConfig, tuning: MovementTuning, patterns: Array) -> LevelLayout:
	return _entry(config, tuning, patterns).layout.copy()


## generate(), with a LevelGenerator standing in for the one that built it: `LevelGenerator.for_layout`
## over a copy() of the cached layout, with its attempts/warnings/picks/fills filled in from the
## cached build. A caller that reads those fields, or calls one of the generator's pure, read-only
## queries that only look at config/pace/layout.length -- feature_start, feature_share_at,
## difficulty_at, quiet_at, quiet_stretches, stretch_end, burst_index, placeable_features,
## enemy_keep_out -- sees exactly what the real build saw, without paying for a real build again.
##
## Never on the result: a method that places something (generate(), _place_*, _apply_enemy_rules,
## add_enemy, add_hull_with_pad, add_cut, ...) -- those mutate generation-only state (_rng,
## _ceiling_rng, _clear_stretches, _due, _intro_burst, ...) this stand-in never had a real build set
## up, so they would build on top of a blank slate instead of the real one, or use an unseeded random
## stream; and pick_weights (and anything that calls it, such as _check_kind_shares) -- it reads
## _intro_held/_intros_waiting, which only a real build's own _due/_intro_burst answer correctly. A
## caller that needs any of those must build for real, uncached (`LevelGenerator.new().generate(...)`).
static func generator(config: LevelConfig, tuning: MovementTuning, patterns: Array) -> LevelGenerator:
	var entry: _Entry = _entry(config, tuning, patterns)
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, entry.layout.copy())
	gen.attempts = entry.attempts
	gen.warnings = entry.warnings.duplicate()
	gen.picks = entry.picks.duplicate(true)
	gen.fills = entry.fills.duplicate(true)
	return gen


static func _entry(config: LevelConfig, tuning: MovementTuning, patterns: Array) -> _Entry:
	if not enabled:
		return _build(config, tuning, patterns)
	var key: String = _key(config, tuning, patterns)
	var cached: _Entry = _cache.get(key)
	if cached == null:
		cached = _build(config, tuning, patterns)
		_cache[key] = cached
		misses += 1
	else:
		hits += 1
	return cached


static func _build(config: LevelConfig, tuning: MovementTuning, patterns: Array) -> _Entry:
	var gen := LevelGenerator.new()
	var e := _Entry.new()
	e.layout = gen.generate(config, tuning, patterns)
	e.warnings = gen.warnings.duplicate()
	e.attempts = gen.attempts
	e.picks = gen.picks.duplicate(true)
	e.fills = gen.fills.duplicate(true)
	return e


## Resources without their own resource_path (the common case in tests: TestSuite helpers and every
## suite duplicate() a LevelConfig to set its lane count, seed and difficulty) are signed field by
## field (_sig) instead of by path, so two separately-duplicated configs with the same content still
## share one build.
const _RESOURCE_SKIP: PackedStringArray = ["resource_path", "resource_name", "resource_local_to_scene", "script"]
## `id`, `display_name` and `skin` never reach the generator (level_generator.gd never mentions any
## of the three -- CLAUDE.md's "gameplay pieces are abstract; zones are skins" -- so two configs that
## differ only there still build the same layout); leaving `skin` out of the key also dodges signing a
## whole zone skin's resource tree on every call.
const _CONFIG_SKIP: PackedStringArray = ["resource_path", "resource_name", "resource_local_to_scene", "script", "skin", "display_name", "id"]


## A string that identifies everything (config, tuning, patterns) LevelGenerator.generate()'s result
## can depend on: two calls with the same key always build the identical layout, short of a generator
## bug test_layout_cache.gd's identity check would catch.
##
## Signs `config.movement_for(tuning)` (what generate() itself resolves `tuning` to inside) rather
## than the raw `tuning` argument: some callers pre-resolve it themselves (config.movement_for(tuning)
## before calling generate()) and some pass the base tuning straight through, and both reach the
## identical effective tuning either way -- signing it, not whichever object a caller happened to
## pass, lets a suite that does one and a suite that does the other still share one build.
static func _key(config: LevelConfig, tuning: MovementTuning, patterns: Array) -> String:
	return var_to_str([_sig(config, _CONFIG_SKIP), _sig(config.movement_for(tuning), _RESOURCE_SKIP), patterns])


## `obj`'s own exported fields (every one Resource.get_property_list() marks PROPERTY_USAGE_STORAGE,
## minus `skip`), each value passed through _sig_value so a sub-resource without a path (an in-memory
## FeatureRecency a test built itself, say) is signed the same field-by-field way.
static func _sig(obj: Resource, skip: PackedStringArray) -> Dictionary:
	if obj == null:
		return {}
	var out: Dictionary = {}
	for prop: Dictionary in obj.get_property_list():
		var name: String = String(prop.get("name", ""))
		if name == "" or skip.has(name) or not (int(prop.get("usage", 0)) & PROPERTY_USAGE_STORAGE):
			continue
		out[name] = _sig_value(obj.get(name))
	return out


static func _sig_value(value: Variant) -> Variant:
	if value is Resource:
		var r: Resource = value
		if r.resource_path != "":
			return r.resource_path
		return _sig(r, _RESOURCE_SKIP)
	if value is Array:
		var out: Array = []
		for v: Variant in (value as Array):
			out.append(_sig_value(v))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for k: Variant in (value as Dictionary):
			out[_sig_value(k)] = _sig_value((value as Dictionary)[k])
		return out
	return value
