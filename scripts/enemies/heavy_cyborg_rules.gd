extends RefCounted
## Generator rules for the Heavy Cyborg (GDD §9.16), run for levels with the `heavy_cyborg` feature (the Ice Lab's
## Relay Station, from its introduction, and Specimen Vault; the Golden Zone's three levels). It stands on the floor
## ahead like a cyborg (proposed), and every Heavy Cyborg stands where its stream gets to fire (fits).
## - Its own encounters: its pattern (data/patterns/heavy_cyborg.json, PATTERN_ID: picked from the feature's start as
##   often as a single cyborg's, the campaign's recency curve and the level's feature_weights on top) places a plain
##   cyborg alone, its stream's zone the pattern's own empty floor before it. Every rule plans around it as around any
##   plain cyborg (the cyborg rules keep it from every obstacle; the dash walls, wall-run gaps and an Enforcer Truck's
##   showing let it stand as near as a cyborg, and a rule that makes room may take it out): this pattern's picks move
##   the level's other picks, as any pattern's do, but where a Heavy Cyborg will stand the rules plan as for a cyborg.
## - Last of the rules (apply, RUN_AFTER), each such cyborg still standing becomes a Heavy Cyborg where one fits, and
##   stays a plain cyborg where none does; then a share of the level's other plain cyborgs from the feature's start on
##   become Heavy Cyborgs where one fits (the top-up): each with the chance `share` times the campaign's recency factor
##   for the feature (LevelConfig.recency_factor: most in the level that introduces it, fewer as it gets older), the
##   first that fits always where the pattern's left none. The passes after the rules (the danger density pass, the
##   wider gaps, the fill pass, the zone doodads, the dash walls past their introduction) keep off a Heavy Cyborg's
##   keep-out and floor as off any enemy that isn't a cyborg, its stream's zone among them. (A level without cyborgs of
##   its own, quick play's `--features=heavy_cyborg`, drops the pattern's cyborgs that don't become Heavy Cyborgs.)
## - After the zone doodads (after_doodads), once everything that stands on the floor is placed (nothing after them
##   adds a gap, a fence or a doodad in its levels; the gap density pass runs in City 1 only): every Heavy Cyborg that
##   no longer fits is given back as a plain cyborg (_give_back); where none is left, the first of the level's own
##   plain cyborgs that fits becomes one (_last_resort, saving a build). A build with none at all is built again with
##   picks of its pattern forced elsewhere (LevelConfig.guarantee_features), as for any feature.
## A Heavy Cyborg fits where (fits):
## - it stands on the floor where a plain cyborg stood (not a host, no rule's mark in its params: a cyborg planted in
##   a charge's path, a Buzz Overdrive's company, one planted under a falling gantryway are their rules' own; the last
##   resort takes none the danger density pass added, its own small threats of the types its tuning lists);
## - it keeps the cyborgs' margin from every obstacle (CyborgRules: their rules and its walk keep it), the zone
##   doodads' included;
## - its stream's zone (stream_zone: keep_clear_seconds of run before it) holds nothing its stream is held for, in any
##   lane (CyborgGun.floor_clear, what the gun's path_clear asks around every round's arrival: a gap or a live fence, a
##   doodad, a falling gantryway's or a teleporter's calm stretch, a dash wall), so it gets to fire as the runner closes
##   in;
## - what it reaches (its stream's zone, its keep-out and the floor it uses) meets no dash wall's footprint, no wider
##   gap's zone, no wall-run gap's clear stretch and no calm stretch a rule keeps in every lane
##   (LevelGenerator.rules_doodad_keep_outs with `calm`: an Enforcer Truck's showing window): those let a cyborg stand
##   nearer than any other enemy, its obstacle margin away (DashWallRules.enemy_spans, WideGapPlacement.keeps_of,
##   WallRunGapPlacement.floor_keeps, the Enforcer Truck's ROOM_TYPES), and their re-checks hold a Heavy Cyborg to the
##   rest's rule;
## - at least spacing_seconds of run from every other Heavy Cyborg;
## - never the level's last plain cyborg (the `cyborg` feature keeps appearing: LevelGenerator.feature_positions), nor,
##   in the last resort, the last of the level's own floor cyborgs before the danger density pass's first (the pass,
##   which comes after the rules, adds its own only past the level's first).
## A Heavy Cyborg keeps a cyborg's keep-out (keep_out: from two seconds of run before it, its stream's zone, to its
## margin after it) and its tuning's floor reach. It is never a panic variant nor a host.
## DESIGN-TBD (docs/questions/s1.md): its pattern's weight, the top-up's share, the spacing and the stream's zone.

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const TYPE: String = "heavy_cyborg"
const CYBORG: String = "cyborg"
const TUNING_PATH: String = "res://data/enemies/heavy_cyborg.tres"
## Its pattern's id (data/patterns/heavy_cyborg.json).
const PATTERN_ID: String = "heavy_cyborg"
## Its rules run last of the rules (whichever of these the level has), so every rule plans around the plain cyborg
## where a Heavy Cyborg will stand.
const RUN_AFTER: Array[String] = ["cyborg", "window_cyborg", "host", "hover_truck", "octodog", "drone", "generator",
	"barnacle_turret", "buzz_overdrive", "wall_run_gaps", "dash_wall", "enforcer_truck", "gantryway", "octodog_jar",
	"teleporter", "gilded_sentinel", "resonator", "treasure_stash", "fenced_ceiling", "floor_cutter", "centipede",
	"debris_maze"]
## The params a plain cyborg's entry may carry (its rules' panic roll); any other is a rule's mark.
const PLAIN_PARAMS: PackedStringArray = ["panic", "host"]


## Last of the rules: the cyborg of each of its pattern's picks still standing becomes a Heavy Cyborg where one fits,
## spaced from the one before (never the level's last plain cyborg); one that doesn't stays the plain cyborg it is.
## Then the top-up (see the header), from its own random stream.
static func apply(gen: LevelGenerator) -> void:
	var t: HeavyCyborgTuning = tuning_of()
	var spans: Array[Vector2] = CyborgRules.obstacle_spans(gen.layout, gen.tuning, gen.zones)
	var taken: Array[Vector2] = taken_spans(gen)
	var spacing: float = t.spacing_seconds * gen.speed
	# The level's last plain cyborg stays one where the level has cyborgs of its own (they keep appearing).
	var own: bool = gen.config.has_feature(CYBORG)
	var left: int = 0 if own else 1 << 30
	for e: Dictionary in gen.layout.enemies:
		left += 1 if own and is_plain_cyborg(e) else 0
	var placed: Array[float] = []
	var stray: Array[Dictionary] = []
	for e: Dictionary in pattern_cyborgs(gen):
		var at: float = float(e["at"])
		if left > 1 and _spaced(placed, at, spacing) and fits(gen, e, t, spans, taken):
			_take(e, placed)
			left -= 1
		else:
			stray.append(e)
	# A level without cyborgs of its own (quick play's `--features=heavy_cyborg`) keeps none of the pattern's that didn't
	# become Heavy Cyborgs: no cyborg rule has planned around them.
	if not own and not stray.is_empty():
		var kept: Array[Dictionary] = []
		for e: Dictionary in gen.layout.enemies:
			if not _holds(stray, e):
				kept.append(e)
		gen.layout.enemies = kept
	# The top-up: a share of the level's other plain cyborgs, the first that fits always where the pattern's left none.
	var from: float = gen.feature_start(TYPE)
	var chance: float = clampf(t.share * gen.config.recency_factor([TYPE]), 0.0, 1.0)
	var rng: RandomNumberGenerator = gen.rng_for(TYPE)
	var plain: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		if is_plain_cyborg(e) and float(e["at"]) >= from - 0.001:
			plain.append(e)
	plain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	for e: Dictionary in plain:
		var at: float = float(e["at"])
		if left <= 1 or not _spaced(placed, at, spacing) or not fits(gen, e, t, spans, taken):
			continue
		# One draw for every cyborg that may become one, the first's too: the same stream whatever the share.
		var roll: float = rng.randf()
		if not placed.is_empty() and roll >= chance:
			continue
		_take(e, placed)
		left -= 1


## The plain cyborgs its pattern's picks placed that still stand (LevelGenerator.picks: the one inside each pick's
## stretch), in order.
static func pattern_cyborgs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in gen.picks:
		if String(p.get("id", "")) != PATTERN_ID:
			continue
		var from: float = float(p["at"])
		var to: float = from + float(p.get("used", 0.0))
		for e: Dictionary in gen.layout.enemies:
			var at: float = float(e["at"])
			if at >= from and at <= to and is_plain_cyborg(e):
				out.append(e)
				break
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## After the zone doodads: every Heavy Cyborg that no longer fits (or stands nearer the one before than the spacing) is
## given back as a plain cyborg; where none is left, the last resort (see the header).
static func after_doodads(gen: LevelGenerator) -> void:
	if not gen.config.has_feature(TYPE):
		return
	var lay: LevelLayout = gen.layout
	var t: HeavyCyborgTuning = tuning_of()
	var spacing: float = t.spacing_seconds * gen.speed
	var taken: Array[Vector2] = taken_spans(gen)
	var spans: Array[Vector2] = CyborgRules.obstacle_spans(lay, gen.tuning, gen.zones)
	var placed: Array[float] = []
	var heavies: Array[Dictionary] = []
	for e: Dictionary in lay.enemies:
		if String(e.get("type", "")) == TYPE:
			heavies.append(e)
	heavies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	for e: Dictionary in heavies:
		var at: float = float(e["at"])
		if _spaced(placed, at, spacing) and fits(gen, e, t, spans, taken):
			placed.append(at)
		else:
			_give_back(e)
	if placed.is_empty():
		_last_resort(gen, t, spans, taken)


## Where none is left after the zone doodads: the first of the level's own plain cyborgs from the feature's start on
## that fits becomes one (never the last plain cyborg, nor the last own floor cyborg before the danger density pass's
## first, nor one the pass added), which saves a build of the guarantee.
static func _last_resort(gen: LevelGenerator, t: HeavyCyborgTuning, spans: Array[Vector2],
		taken: Array[Vector2]) -> void:
	var from: float = gen.feature_start(TYPE)
	# The danger density pass's own cyborgs are none of these: it adds them only past the level's first.
	var added: Array = gen.danger_density_result.get("added_enemies", [])
	var added_first: float = INF
	for e: Variant in added:
		if String((e as Dictionary).get("type", "")) == CYBORG:
			added_first = minf(added_first, float((e as Dictionary)["at"]))
	var own: Array[Dictionary] = []
	var before_added: int = 0
	var left: int = 0
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) != CYBORG or _holds(added, e):
			continue
		own.append(e)
		before_added += 1 if float(e["at"]) < added_first and _counts_first(e) else 0
		left += 1 if is_plain_cyborg(e) else 0
	own.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	for e: Dictionary in own:
		var at: float = float(e["at"])
		var first_kept: bool = at < added_first and _counts_first(e) and before_added <= 1
		if at >= from - 0.001 and is_plain_cyborg(e) and left > 1 and not first_kept and fits(gen, e, t, spans, taken):
			var placed: Array[float] = []
			_take(e, placed)
			return


## True if `at` is at least `spacing` from every one of `placed`.
static func _spaced(placed: Array[float], at: float, spacing: float) -> bool:
	for p: float in placed:
		if absf(at - p) < spacing:
			return false
	return true


## Cyborg entry `e` becomes a Heavy Cyborg, in its place (none of a cyborg's params: no panic variant); `placed` notes
## where.
static func _take(e: Dictionary, placed: Array[float]) -> void:
	e["type"] = TYPE
	e["params"] = {}
	placed.append(float(e["at"]))


## Heavy Cyborg entry `e` goes back to the level as the plain cyborg it was (no panic variant).
static func _give_back(e: Dictionary) -> void:
	e["type"] = CYBORG
	e["params"] = {"panic": false}


## True if cyborg entry `e` counts as the level's first of its kind for the danger density pass (DangerDensity: a floor
## cyborg that isn't a host).
static func _counts_first(e: Dictionary) -> bool:
	return int(e.get("side", 0)) == 0 and not bool((e.get("params", {}) as Dictionary).get("host", false))


## True if `list` holds `item` itself (not an equal copy).
static func _holds(list: Array, item: Dictionary) -> bool:
	for x: Variant in list:
		if is_same(x, item):
			return true
	return false


## True if enemy entry `e` is a plain cyborg (see the header): one a Heavy Cyborg may take the place of.
static func is_plain_cyborg(e: Dictionary) -> bool:
	if String(e.get("type", "")) != CYBORG or int(e.get("side", 0)) != 0:
		return false
	var params: Dictionary = e.get("params", {})
	if bool(params.get("host", false)):
		return false
	for key: Variant in params:
		if not PLAIN_PARAMS.has(String(key)):
			return false
	return true


## True if a Heavy Cyborg fits where cyborg entry `e` stands (see the header): `spans` are the level's obstacles
## (CyborgRules.obstacle_spans) and `taken` the stretches its reach keeps off (taken_spans).
static func fits(gen: LevelGenerator, e: Dictionary, t: HeavyCyborgTuning, spans: Array[Vector2],
		taken: Array[Vector2]) -> bool:
	var at: float = float(e["at"])
	if CyborgRules.near_any(spans, at, CyborgRules.obstacle_margin_at(t, gen.pace)):
		return false
	if not zone_clear(gen.layout, stream_zone(gen, at, t)):
		return false
	var reach: Vector2 = reach_of(gen, e, t)
	for s: Vector2 in taken:
		if s.x <= reach.y and s.y >= reach.x:
			return false
	return true


## True if a stream's zone (`zone`, track distances) holds nothing its stream is held for, in any lane
## (CyborgGun.floor_clear: what the gun's path_clear asks around each round's arrival).
static func zone_clear(layout: LevelLayout, zone: Vector2) -> bool:
	return CyborgGun.floor_clear(layout, zone.x, zone.y)


## What a Heavy Cyborg standing where entry `e` does reaches along the track (metres): its stream's zone, its keep-out
## and the floor it uses (its tuning's floor reach, as LevelGenerator.enemy_floor_span measures it).
static func reach_of(gen: LevelGenerator, e: Dictionary, t: HeavyCyborgTuning = null) -> Vector2:
	if t == null:
		t = tuning_of()
	var at: float = float(e["at"])
	var zone: Vector2 = stream_zone(gen, at, t)
	var keep: Vector2 = keep_out(gen, e)
	return Vector2(minf(minf(zone.x, keep.x), at - t.floor_reach_before * gen.pace),
		maxf(keep.y, at + t.floor_reach_after * gen.pace))


## The stretches a Heavy Cyborg's reach keeps off, any lane (see the header): every dash wall's footprint
## (DashWallRules.footprint), wider gap's zone (WideGapPlacement.keep_outs) and wall-run gap's clear stretch with its
## margin (WallRunGapPlacement.keep_out), and every calm stretch a rule keeps in every lane.
static func taken_spans(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for w: Dictionary in gen.layout.dash_walls:
		out.append(LevelGenerator.DashWallRules.footprint(gen, w))
	out.append_array(WideGapPlacement.keep_outs(gen))
	for w: Dictionary in gen.layout.wall_run_gaps:
		out.append(WallRunGapPlacement.keep_out(w))
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if bool(k.get("calm", false)) and not k.has("lane"):
			out.append(Vector2(float(k["from"]), float(k["to"])))
	return out


## The stretch of track (metres) a Heavy Cyborg standing at `at` needs clear for its stream: keep_clear_seconds of
## run at the level's speed before it, to where it stands.
static func stream_zone(gen: LevelGenerator, at: float, t: HeavyCyborgTuning = null) -> Vector2:
	if t == null:
		t = tuning_of()
	return Vector2(at - t.keep_clear_seconds * gen.speed, at)


## What the passes keep off around Heavy Cyborg entry `e` (LevelGenerator.enemy_keep_out: the danger density pass, the
## wider gaps, the fill pass, the zone doodads, the dash walls...): a cyborg's (CyborgRules.keep_out: from two seconds
## of run before it, its stream's zone, to its margin after it).
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	return CyborgRules.keep_out(gen, e)


## Its tuning (data/enemies/heavy_cyborg.tres), or the class's defaults.
static func tuning_of() -> HeavyCyborgTuning:
	var t := load(TUNING_PATH) as HeavyCyborgTuning if ResourceLoader.exists(TUNING_PATH) else null
	return t if t != null else HeavyCyborgTuning.new()
