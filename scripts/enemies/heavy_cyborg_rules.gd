extends RefCounted
## Generator rules for the Heavy Cyborg (GDD §9.16), run for levels with the `heavy_cyborg` feature (the Ice Lab's
## Relay Station, from its introduction, and Specimen Vault; the Golden Zone's three levels). It stands on the floor
## ahead like a cyborg (proposed), so Heavy Cyborgs take the places of some of the level's cyborgs: no pattern of its
## own, as the ceiling scenarios take some of the level's ceilings. After the zone doodads (after_doodads), when every
## rule and pass but the wall fences, the side wall gaps, the gap density pass and the credits has built the level
## around its cyborgs, a share of the plain cyborgs from the feature's start on become Heavy Cyborgs, each where one
## fits (fits):
## - a plain cyborg: on the floor, not a host, no rule's mark in its params (a cyborg planted in a charge's path, a
##   Buzz Overdrive's company, one planted under a falling gantryway are their rules' own), and none the danger density
##   pass added (its own small threats, of the types its tuning lists: DangerDensity's `added_enemies`);
## - it keeps the cyborgs' margin from every obstacle (CyborgRules: their rules and its walk keep it), the zone
##   doodads' included;
## - its stream's zone (stream_zone: keep_clear_seconds of run before it) holds nothing that holds a stream
##   (CyborgGun.path_clear, LevelLayout.doodad_between: a doodad, a falling gantryway's or a teleporter's calm stretch,
##   a dash wall), so it gets to fire as the runner closes in (the zone doodads already keep a cyborg's keep-out, the
##   same two seconds, clear: LevelGenerator.doodad_enemy_keep_out);
## - what it reaches (its stream's zone, its keep-out and the floor it uses) meets no dash wall's footprint, no wider
##   gap's zone, no wall-run gap's clear stretch and no calm stretch a rule keeps in every lane
##   (LevelGenerator.rules_doodad_keep_outs with `calm`: an Enforcer Truck's showing window): those let a cyborg stand
##   nearer than any other enemy, its obstacle margin away (DashWallRules.enemy_spans, WideGapPlacement.keeps_of,
##   WallRunGapPlacement.floor_keeps, the Enforcer Truck's ROOM_TYPES), and their re-checks hold a Heavy Cyborg to the
##   rest's rule;
## - at least spacing_seconds of run from the Heavy Cyborg before it;
## - never the level's last cyborg (the `cyborg` feature keeps appearing: LevelGenerator.feature_positions).
## The first that fits from the start always becomes one (the introduction: the first cyborg that fits past the start).
## Where none fits, the first plain cyborg past the start that fits but for its stream's zone becomes the level's one
## (CyborgGun.path_clear holds its stream while the runner is where it can't fairly be shot, so it may not get to fire);
## a build with no plain cyborg past the start that fits so has none (OCCASIONAL). Each later one does with the chance
## `share` times the campaign's recency factor for the feature (LevelConfig.recency_factor: most in the level that
## introduces it, fewer as it gets older), drawn from its own random stream. Everything else is built exactly as without
## the feature: the rules and passes before planned around a cyborg, and a Heavy Cyborg keeps a cyborg's keep-out and
## floor (keep_out; its tuning's floor reach), so the passes after it build the same too, and every other rule's
## re-check finds it where it found the cyborg. It is never a panic variant nor a host.
## DESIGN-TBD (docs/questions/s1.md): taking the cyborgs' places, the share, the spacing and the stream's zone.

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const TYPE: String = "heavy_cyborg"
const CYBORG: String = "cyborg"
const TUNING_PATH: String = "res://data/enemies/heavy_cyborg.tres"
## Never forced (as the ceiling scenarios and the Octodog jars): a build of a level that lists the feature whose cyborgs
## leave a Heavy Cyborg no place has none, the generator never builds it again for one (each build again would move
## everything else: the rest of the level is built exactly as without the feature), and the campaign's checks don't ask
## every build for one (LayoutChecks.occasional). test_heavy_cyborg checks that every build of the campaign's levels on
## their own seeds at the campaign's lane count has some (and counts them at 3 and 6 lanes), and that most builds of the
## prototype level over seeds, lane counts and difficulties do. DESIGN-TBD (docs/questions/s1.md).
const OCCASIONAL: bool = true
## The params a plain cyborg's entry may carry (its pattern's and its rules' panic roll); any other is a rule's mark.
const PLAIN_PARAMS: PackedStringArray = ["panic", "host"]


## Turns a share of the level's plain cyborgs into Heavy Cyborgs (see the header).
static func after_doodads(gen: LevelGenerator) -> void:
	if not gen.config.has_feature(TYPE):
		return
	var t: HeavyCyborgTuning = tuning_of()
	var lay: LevelLayout = gen.layout
	var from: float = gen.feature_start(TYPE)
	var chance: float = clampf(t.share * gen.config.recency_factor([TYPE]), 0.0, 1.0)
	var spacing: float = t.spacing_seconds * gen.speed
	var rng: RandomNumberGenerator = gen.rng_for(TYPE)
	var taken: Array[Vector2] = taken_spans(gen)
	var spans: Array[Vector2] = CyborgRules.obstacle_spans(lay, gen.tuning, gen.zones)
	var left: int = LevelGenerator.feature_positions(lay, CYBORG).size()
	var added: Array = gen.danger_density_result.get("added_enemies", [])
	var candidates: Array[Dictionary] = []
	for e: Dictionary in lay.enemies:
		if is_plain_cyborg(e) and float(e["at"]) >= from - 0.001 and not _holds(added, e):
			candidates.append(e)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	var last: float = -INF
	for e: Dictionary in candidates:
		var at: float = float(e["at"])
		if left <= 1:
			break
		if at - last < spacing or not fits(gen, e, t, spans, taken):
			continue
		# One draw for every cyborg that fits, the first's too: the same stream whatever the share.
		var roll: float = rng.randf()
		if last > -INF and roll >= chance:
			continue
		_take_place(e)
		left -= 1
		last = at
	if last > -INF or left <= 1:
		return
	for e: Dictionary in candidates:
		if fits(gen, e, t, spans, taken, false):
			_take_place(e)
			return


## True if `list` holds `item` itself (not an equal copy).
static func _holds(list: Array, item: Dictionary) -> bool:
	for x: Variant in list:
		if is_same(x, item):
			return true
	return false


## Cyborg entry `e` becomes a Heavy Cyborg, in its place (none of a cyborg's params: no panic variant).
static func _take_place(e: Dictionary) -> void:
	e["type"] = TYPE
	e["params"] = {}


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
## (CyborgRules.obstacle_spans) and `taken` the stretches its reach keeps off (taken_spans). With `zone_clear` off, its
## stream's zone may hold what holds a stream (the guarantee's last resort).
static func fits(gen: LevelGenerator, e: Dictionary, t: HeavyCyborgTuning, spans: Array[Vector2],
		taken: Array[Vector2], zone_clear: bool = true) -> bool:
	var at: float = float(e["at"])
	if CyborgRules.near_any(spans, at, CyborgRules.obstacle_margin_at(t, gen.pace)):
		return false
	var zone: Vector2 = stream_zone(gen, at, t)
	if zone_clear and gen.layout.doodad_between(zone.x, zone.y):
		return false
	var reach: Vector2 = reach_of(gen, e, t)
	for s: Vector2 in taken:
		if s.x <= reach.y and s.y >= reach.x:
			return false
	return true


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


## What the passes keep off around Heavy Cyborg entry `e` (LevelGenerator.enemy_keep_out: the fill pass, the zone
## doodads, the danger density pass, the wall fences, the gap density pass...): a cyborg's (CyborgRules.keep_out), so
## everything after it is built as around the cyborg whose place it took.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	return CyborgRules.keep_out(gen, e)


## Its tuning (data/enemies/heavy_cyborg.tres), or the class's defaults.
static func tuning_of() -> HeavyCyborgTuning:
	var t := load(TUNING_PATH) as HeavyCyborgTuning if ResourceLoader.exists(TUNING_PATH) else null
	return t if t != null else HeavyCyborgTuning.new()
