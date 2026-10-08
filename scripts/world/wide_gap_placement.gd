class_name WideGapPlacement
extends RefCounted
## Wider gaps (owner, October 7, 2026, answering open question 352; GDD §9.13 "Holes": "every level has a
## couple of wider gaps. They're uncommon, still jumpable by the player, and wide enough that an Enforcer
## following the player into one is wrecked"; task G7). LevelConfig.wide_gaps rows of holes (the holes sharing a
## start and an end, GapDensity.rows) in a level are longer along the run than the rest: WideGapTuning
## .jump_fraction of a full jump at the level's speed (length_for), more than an Enforcer Truck hops
## (EnforcerTruckTuning.max_hop_jump_fraction) and no more than a level may ask a runner to jump
## (LevelConfig.max_gap_jump_fraction).
##
## The generator runs it after the enemy rules, the danger density pass's enemies and the cyborgs planted in
## charge paths, before the fill pass (LevelGenerator._build), from a stream of its own (rng_for("wide_gaps")),
## so everything before it is built as it was. The level's own rows it makes longer it makes longer only after the
## fill pass (widen_deferred), so the fill pass is built as it would be without them: a filler keeps the level's
## spacing and FILL_TAIL_SECONDS more from every piece, more than a row's landing margin once it's longer (it
## grows by 0.2 s of run at most); the new rows and the rows it clears room for come before it. The fill pass keeps its spacing from the wider rows as from any
## piece (more than their margins), the danger density pass's floor pieces and City 1's extra gaps keep off each
## one's zone (keep_outs: DangerDensity._index_obstacles, GapDensity._protected), a zone doodad that would reach
## it is left out (doodad_keep_outs, with the doodads' own spacing before a piece), and the side wall gaps keep off
## each one on both walls (wall_keep_outs). With wide_gaps 0 (quick play, the tests)
## and in a boss arena it draws nothing and the level is built exactly as before.
##
## A wider gap goes only where it's fair (fits):
## - a normal jump clears it: its length is a share of a jump at the level's run speed, so it keeps its
##   take-off window in seconds at every zone's speed;
## - never stacked with other demands at take-off or landing: from clear_before_seconds before the take-off to
##   clear_after_seconds after the landing (never less than the level's spacing between two patterns there, its
##   difficulty's, or its burst spacing in a level paced in bursts: the wider gap is a pattern on its own; zone_of),
##   no other hole, fence, ramp (or where its wall run
##   drops the runner back), anti-grav pad's zone, speed pad, ceiling's landing zone, floor cut's window,
##   enemy's attack (what the fill pass keeps for it, LevelGenerator.enemy_keep_out, with its floor; for a floor
##   cyborg its obstacle margin, CyborgRules: its bolts never land near a hole anyway, CyborgGun; for a planned
##   Resonator each pulse from its warning until its wave has passed, DangerDensity.resonator_pulse_windows:
##   between them it only hovers, and every pulse waits for clear floor) or attack the rules keep doodads off (a
##   Gilded Sentinel's strike; not a host's possible Bad Dream chase, which the danger density pass exempts too)
##   reaches, in any lane: the runner sees it early, lines up alone and lands on clear floor. No ceiling over the
##   jump itself, and no ramp's wall run over it (keeps_of: `row_only`). What the rules keep in one lane only (a
##   hover truck's lane for its whole stay, past the stretch it's surely there and firing, which every lane
##   keeps) keeps that lane only: the wider row leaves it open (keeps_of: `lane`), as every row there does. Wall
##   and ceiling enemies whose shots keep off holes by their own rules, harmless thieves and the Enforcer Truck
##   (NO_KEEP_TYPES) don't count;
## - between the run-up and the end-clear stretch, and spacing_seconds from another wider gap.
## Where they come from, in this order until the level has its count:
## 1. The level's own rows (the patterns'), made longer: at the far edge (the take-off stays where the pattern
##    put it), else the near edge, else both, whichever fits first (_widened).
## 2. With add_rows, new rows of the wider length in every lane but one (the open lane seeded, or the lane a
##    hover truck keeps there), where the track is clear around them by the same margins (_add_one).
## 3. The level's rows that only other holes and plain fences keep from fitting, with those taken out
##    (_clearing: never a pulsing fence or one a fence generator powers; the generator's way to make room for a
##    guarantee, as PadPlacement's: taking content out never makes a level unfair).
## Which ones: with prefer_enforcer_chases, first one in each Enforcer Truck's chase, once the truck has settled
## behind the runner (EnforcerTruckTuning.bait_after_seconds) and before it may drop back (CHASE_END_SECONDS
## before it gives up), so the runner can lead it in: from the first of the three sources above with one there,
## the earliest; then the rest spread through the level, each source used up before the next. Rows across most of
## the lanes (a jump) come before single holes. DESIGN-TBD (docs/questions/g7.md): the width, the margins, the
## count and which rows.

const TUNING_PATH: String = "res://data/tuning/wide_gaps.tres"
const EnforcerRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const GeneratorRules = preload("res://scripts/enemies/generator_rules.gd")
## The danger density pass's tuning (DangerDensity.TUNING_PATH): its keep_out_exempt_features.
const DANGER_DENSITY_TUNING: String = "res://data/tuning/danger_density.tres"
## Enemy types a wider gap needn't keep off (keeps_of): window cyborgs and Barnacle Turrets (wall and ceiling
## shooters whose bolts never land near a hole, CyborgGun), thieves (touching one never hurts) and the Enforcer
## Truck (it drives behind the runner: wider gaps are there to wreck it).
const NO_KEEP_TYPES: PackedStringArray = ["window_cyborg", "barnacle_turret", "tithe_collector", "stand_in_thief",
	"enforcer_truck"]
## Two track distances closer than this are the same spot.
const EPSILON: float = 0.001
## The seconds of run from its spread target that weigh as much as one step of a row's preference for crossing
## more lanes (_across_bonus).
const SPREAD_SECONDS: float = 10.0
## Seconds of run before an Enforcer Truck would give up, kept free of its preferred wider gap (it may be
## dropping back by then).
const CHASE_END_SECONDS: float = 3.0
## Metres between the spots a new row is tried at along a free stretch (_add_one).
const ADD_STEP: float = 1.0
const EMPTY := Vector2(INF, -INF)


static func tuning() -> WideGapTuning:
	var res: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return res as WideGapTuning if res is WideGapTuning else WideGapTuning.new()


## A wider gap's length along the run at `gen`'s run speed: jump_fraction of a full jump there, never more
## than the level's max_gap_jump_fraction.
static func length_for(gen: LevelGenerator, t: WideGapTuning = null) -> float:
	var tun: WideGapTuning = t if t != null else tuning()
	return minf(tun.jump_fraction, gen.config.max_gap_jump_fraction) * gen.jump_distance


## Places the level's wider gaps (see the header). Returns its report (LevelGenerator.wide_gap_result): {}
## when the level asks for none (or is a boss arena); else {target, rows (each wider row's
## Vector2(start, end), along the track), widened (rows of the level's own made longer as they stood), added
## (new rows), cleared (rows made longer once other pieces went) and taken_out (how many pieces went), blocked
## (what kept each of the level's own rows from widening at its far edge: "<what>" -> how many rows),
## constraints (why fewer than the target, if so)}.
static func place(gen: LevelGenerator) -> Dictionary:
	var want: int = gen.config.wide_gaps
	if want <= 0 or WallGapPlacement.is_boss_arena(gen.config):
		return {}
	var p := _Pass.new()
	p.gen = gen
	p.t = tuning()
	p.rng = gen.rng_for("wide_gaps")
	p.length = length_for(gen, p.t)
	p.keeps = keeps_of(gen)
	p.across = maxi(1, gen.layout.lane_count - 1)
	var blocked: Dictionary = {}
	for row: Dictionary in GapDensity.rows(gen.layout):
		var span: Vector2 = _widened(gen, p.t, row, p.length, p.keeps)
		if span.y > span.x:
			p.candidates.append({"row": row, "span": span, "lanes": (row["lanes"] as Array).size()})
		else:
			var what: String = blocker(gen, p.t, Vector2(float(row["start"]), float(row["start"]) + p.length), row, p.keeps)
			blocked[what] = int(blocked.get(what, 0)) + 1
	if p.t.prefer_enforcer_chases:
		for chase: Vector2 in _chases(gen):
			if p.rows.size() >= want:
				break
			if not _widen_one(p, chase, chase.x):
				if not (p.t.add_rows and _add_one(p, chase, chase.x)):
					_clear_one(p, chase, chase.x)
	var whole := Vector2(gen.config.start_clear_distance, gen.layout.length - gen.config.end_clear_distance)
	for source: int in 3:
		if source == 1 and not p.t.add_rows:
			continue
		var left: int = want - p.rows.size()
		for k: int in left:
			var target: float = lerpf(whole.x, whole.y, (float(k) + p.rng.randf_range(0.25, 0.75)) / float(left))
			match source:
				0:
					_widen_one(p, whole, target)
				1:
					_add_one(p, whole, target)
				2:
					_clear_one(p, whole, target)
	if p.taken_out > 0:
		GeneratorRules.keep_powered(gen)
	p.rows.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var constraints: PackedStringArray = []
	if p.rows.size() < want:
		constraints.append("only %d of %d wider gaps fit: nowhere else has its margins clear (or the spacing)" % [
			p.rows.size(), want])
	return {"target": want, "rows": p.rows, "widened": p.widened, "added": p.added, "cleared": p.cleared,
		"taken_out": p.taken_out, "blocked": blocked, "constraints": constraints, "deferred": p.deferred}


## Makes longer the level's own rows place() chose (its report's `deferred`), once the fill pass has run (see the
## header). A filler that still reaches one's zone (only with a jump_fraction or margins far from the data's) goes,
## as a plain piece in the way does (_clearing); anything else keeps that row as it was, with the report's
## constraints saying so.
static func widen_deferred(gen: LevelGenerator) -> void:
	var deferred: Array = gen.wide_gap_result.get("deferred", [])
	if deferred.is_empty():
		return
	var t: WideGapTuning = tuning()
	var keeps: Array[Dictionary] = keeps_of(gen)
	var others: Array[Dictionary] = []
	for k: Dictionary in keeps:
		if String(k["what"]) != "a fence":
			others.append(k)
	var taken_out: int = 0
	for d: Dictionary in deferred:
		var span: Vector2 = d["span"]
		var row: Dictionary = {}
		for r: Dictionary in GapDensity.rows(gen.layout):
			if absf(float(r["start"]) - float(d["start"])) < EPSILON and absf(float(r["end"]) - float(d["end"])) < EPSILON:
				row = r
		if row.is_empty():
			continue
		if not fits(gen, t, span, row, keeps):
			var plan: Dictionary = _clearing_at(gen, t, row, span, others)
			if plan.is_empty():
				var rows: Array = gen.wide_gap_result.get("rows", [])
				rows.erase(span)
				(gen.wide_gap_result["constraints"] as PackedStringArray).append(
					"the row at %.0f m stayed as it was: the fill pass put something it can't take out in its way" % span.x)
				continue
			taken_out += _clear(gen, plan)
		_widen(gen.layout, row, span)
	if taken_out > 0:
		gen.wide_gap_result["taken_out"] = int(gen.wide_gap_result.get("taken_out", 0)) + taken_out
		GeneratorRules.keep_powered(gen)


## One pass's state (place).
class _Pass:
	extends RefCounted
	var gen: LevelGenerator
	var t: WideGapTuning
	var rng: RandomNumberGenerator
	## A wider gap's length (length_for).
	var length: float
	var keeps: Array[Dictionary]
	## Rows of `across` lanes or more are a jump (_across_bonus).
	var across: int
	## The level's own rows that fit made longer: {row, span, lanes}.
	var candidates: Array[Dictionary] = []
	## The wider gaps placed so far, Vector2(start, end).
	var rows: Array[Vector2] = []
	var widened: int = 0
	var added: int = 0
	var cleared: int = 0
	var taken_out: int = 0
	## The level's own rows to make longer after the fill pass: {start, end (the row's), span (its wider one)}.
	var deferred: Array[Dictionary] = []


## The wider rows `gen`'s last build placed (wide_gap_result), each Vector2(start, end).
static func rows_of(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for v: Variant in gen.wide_gap_result.get("rows", []):
		out.append(v as Vector2)
	return out


## The rows of `layout` (GapDensity.rows) longer than `fraction` of a jump of `jump` metres, along the track: a
## level's wider gaps (its other rows are 0.55 of a jump at most), for the tests and the review tools.
static func wide_rows(layout: LevelLayout, jump: float, fraction: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in GapDensity.rows(layout):
		if float(row["end"]) - float(row["start"]) > fraction * jump + EPSILON:
			out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	return out


## What the passes after this one keep off around each wider gap, as Vector2(from, to): its zone (zone_of: its
## take-off and landing margins). For a pass that keeps `within` metres of its own from what it keeps off
## (GapDensity's margin), each zone comes `within` narrower at both ends, never narrower than the row itself, so
## the two together keep the zone.
static func keep_outs(gen: LevelGenerator, within: float = 0.0) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var t: WideGapTuning = tuning()
	for span: Vector2 in rows_of(gen):
		var zone: Vector2 = zone_of(gen, t, span)
		out.append(Vector2(minf(zone.x + within, span.x), maxf(zone.y - within, span.y)))
	return out


## What a zone doodad's window keeps off around each wider gap (LevelGenerator._add_doodad), as Vector2(from,
## to): from its take-off to the end of its landing margin. Before a piece a doodad keeps the level's spacing
## already (LevelGenerator._place_doodads: the take-off margin, zone_of), after one only its push's lead.
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var t: WideGapTuning = tuning()
	for span: Vector2 in rows_of(gen):
		out.append(Vector2(span.x, zone_of(gen, t, span).y))
	return out


## The stretches side wall gaps keep off (WallGapPlacement.keep_outs, both walls): each wider gap with
## wall_gap_clear_seconds either side, so a runner on a wall over one is never dropped into it.
static func wall_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var t: WideGapTuning = tuning()
	var clear: float = t.wall_gap_clear_seconds * gen.speed
	for span: Vector2 in rows_of(gen):
		out.append(Vector2(span.x - clear, span.y + clear))
	return out


## The stretch a wider gap over `span` keeps clear in every lane: from its take-off margin to its landing margin
## (clear_before_seconds and clear_after_seconds, never less than the level's spacing between two patterns there,
## _spacing).
static func zone_of(gen: LevelGenerator, t: WideGapTuning, span: Vector2) -> Vector2:
	return Vector2(span.x - maxf(t.clear_before_seconds, _spacing(gen, span.x)) * gen.speed,
		span.y + maxf(t.clear_after_seconds, _spacing(gen, span.y)) * gen.speed)


## True if a wider gap over `span` (Vector2(start, end)) fits in `gen`'s layout (see the header): its zone
## (zone_of) between the run-up and the end-clear stretch, nothing of `keeps` (keeps_of) in its zone (or, for a
## keep that's `row_only`, over its span; for one that keeps a `lane`, only if the row has a hole in that lane)
## and no hole but those of `row` (the row being widened, {start, end, lanes}; {} for none) in its zone.
static func fits(gen: LevelGenerator, t: WideGapTuning, span: Vector2, row: Dictionary, keeps: Array[Dictionary]) -> bool:
	return blocker(gen, t, span, row, keeps) == ""


## What keeps a wider gap over `span` from fitting (fits): the level's ends, the first of `keeps` in its way, or
## another hole; "" if it fits. Something that only touches the zone's end (a pass that kept exactly its margin)
## isn't in its way.
static func blocker(gen: LevelGenerator, t: WideGapTuning, span: Vector2, row: Dictionary, keeps: Array[Dictionary]) -> String:
	var zone: Vector2 = zone_of(gen, t, span)
	if zone.x < gen.config.start_clear_distance or zone.y > gen.layout.length - gen.config.end_clear_distance:
		return "the run-up or the end-clear stretch"
	var lanes: Array = row.get("lanes", [])
	for k: Dictionary in keeps:
		var v: Vector2 = k["span"]
		var against: Vector2 = span if bool(k["row_only"]) else zone
		if v.x >= against.y - EPSILON or v.y <= against.x + EPSILON:
			continue
		var lane: int = int(k["lane"])
		if lane >= 0 and not lanes.is_empty() and not lanes.has(lane):
			continue
		return String(k["what"])
	for g: Dictionary in gen.layout.gaps:
		if not row.is_empty() and float(g["start"]) == float(row["start"]) and float(g["end"]) == float(row["end"]):
			continue
		if float(g["start"]) < zone.y - EPSILON and float(g["end"]) > zone.x + EPSILON:
			return "another hole"
	return ""


## Everything but holes a wider gap keeps off (see the header): {span (Vector2(from, to)), what (for the report),
## row_only (true: it keeps off the wider gap itself only, not its margins: a ceiling over it, a ramp's wall run
## over it), lane (-1: every lane; else the one lane it keeps, which the wider row leaves open: a hover truck's
## for its whole stay)}.
static func keeps_of(gen: LevelGenerator) -> Array[Dictionary]:
	var lay: LevelLayout = gen.layout
	var out: Array[Dictionary] = []
	var half: float = gen.tuning.fence_depth * 0.5
	for f: Dictionary in lay.fences:
		out.append(_keep(Vector2(float(f["at"]) - half, float(f["at"]) + half), "a fence"))
	for r: Dictionary in lay.ramps:
		var at: float = float(r["at"])
		var run_end: float = maxf(gen.ramp_launch(r).end(), at + gen.tuning.ramp_length)
		out.append(_keep(Vector2(at, at + gen.tuning.ramp_length), "a ramp"))
		out.append(_keep(Vector2(run_end, run_end), "where a ramp's wall run drops the runner back"))
		out.append(_keep(Vector2(at, run_end), "a ramp's wall run", true))
	for p: Dictionary in lay.speed_pads:
		out.append(_keep(Vector2(float(p["at"]), float(p["at"]) + gen.tuning.speed_pad_length), "a speed pad"))
	for p: Dictionary in lay.pads:
		out.append(_keep(gen.zones.pad_zone(float(p["at"])), "a pad"))
	for h: Dictionary in lay.hulls:
		out.append(_keep(Vector2(float(h["start"]), float(h["end"])), "a ceiling", true))
		out.append(_keep(gen.zones.landing_zone(h), "a ceiling's landing zone"))
	var hooks: Dictionary = {}
	var ct := EnemyDirector.tuning_for("cyborg") as CyborgTuning
	var cyborg_margin: float = CyborgRules.obstacle_margin_at(ct, gen.pace) if ct != null else gen.metres(10.0)
	for e: Dictionary in lay.enemies:
		var type: String = String(e.get("type", ""))
		if NO_KEEP_TYPES.has(type):
			continue
		if type == "cyborg":
			# Its obstacle margin (its walk and panic run keep it too); a host's chase is exempt (below).
			var at: float = float(e["at"])
			out.append(_keep(Vector2(at - cyborg_margin, at + cyborg_margin), "a cyborg"))
			continue
		# A planned Resonator attacks only in its pulses (as the wall fences keep off it): between them it hovers,
		# and every pulse waits for clear floor at run time (Resonator.pulse_clear).
		var pulses: Array[Vector2] = LevelGenerator.DangerDensity.resonator_pulse_windows(gen, e)
		if not pulses.is_empty():
			for w: Vector2 in pulses:
				out.append(_keep(w, "a Resonator's pulse"))
			continue
		var k: Vector2 = gen.enemy_keep_out(e, hooks)
		if k.y >= k.x:
			out.append(_keep(k, type))
		var floor_span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
		if floor_span.y >= floor_span.x:
			out.append(_keep(floor_span, type))
	for c: Dictionary in lay.cuts:
		out.append(_keep(FloorCutPlan.window(c, gen.speed), "a floor cut"))
	# What the rules keep doodads off (a Gilded Sentinel's strike in every lane, a hover truck's lane for its whole
	# stay), but for the features the danger density pass exempts too (its tuning's keep_out_exempt_features: a
	# host's chase, which only comes if the player kills the host).
	var dd: Resource = load(DANGER_DENSITY_TUNING) if ResourceLoader.exists(DANGER_DENSITY_TUNING) else null
	var exempt: PackedStringArray = dd.get("keep_out_exempt_features") if dd != null else PackedStringArray(["host"])
	for feature: String in gen.config.features:
		if exempt.has(feature):
			continue
		var path: String = LevelGenerator.RULES_DIR.path_join("%s_rules.gd" % feature)
		var script: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else null
		if script == null or not script.has_method("doodad_keep_outs"):
			continue
		for k: Dictionary in script.call("doodad_keep_outs", gen):
			out.append(_keep(Vector2(float(k["from"]), float(k["to"])), String(k.get("type", feature)), false,
				int(k.get("lane", -1))))
	for d: Dictionary in lay.doodads:
		out.append(_keep(Vector2(float(d["start"]), float(d["end"])), "a doodad"))
	return out


static func _keep(span: Vector2, what: String, row_only: bool = false, lane: int = -1) -> Dictionary:
	return {"span": span, "what": what, "row_only": row_only, "lane": lane}


## The level's spacing between two patterns at track distance `at` (seconds), as the pattern pass and the fill
## pass keep it there: at its difficulty there, or in a level paced in bursts (The Hush) its burst spacing, as
## between the patterns of a burst (its quiet spacing is pacing, not reaction time).
static func _spacing(gen: LevelGenerator, at: float) -> float:
	if gen.config.paced_in_bursts():
		return gen.config.burst_spacing_seconds
	var difficulty: float = gen.difficulty_at(clampf(at / maxf(gen.layout.length, 1.0), 0.0, 1.0))
	return lerpf(gen.config.spacing_seconds_easy, gen.config.spacing_seconds_hard, difficulty)


## Makes `row`'s holes run over `span` (its wider length).
static func _widen(lay: LevelLayout, row: Dictionary, span: Vector2) -> void:
	for g: Dictionary in lay.gaps:
		if float(g["start"]) == float(row["start"]) and float(g["end"]) == float(row["end"]):
			g["start"] = span.x
			g["end"] = span.y


## The spans `row` made `length` long may take: at its far edge, its near edge, both.
static func _spans(row: Dictionary, length: float) -> Array[Vector2]:
	var s: float = float(row["start"])
	var e: float = float(row["end"])
	var extra: float = length - (e - s)
	return [Vector2(s, s + length), Vector2(e - length, e), Vector2(s - extra * 0.5, e + extra * 0.5)]


## Where `row` widened to `length` fits (fits): at its far edge, else its near edge, else both; or EMPTY if none
## does or it's already that wide.
static func _widened(gen: LevelGenerator, t: WideGapTuning, row: Dictionary, length: float, keeps: Array[Dictionary]) -> Vector2:
	if float(row["end"]) - float(row["start"]) >= length - EPSILON:
		return EMPTY
	for span: Vector2 in _spans(row, length):
		if fits(gen, t, span, row, keeps):
			return span
	return EMPTY


## How `row` could widen to `length` by taking out what's in its zone, if only other holes and plain fences are
## (never a pulsing fence, which the `pulsing` feature counts, nor one a fence generator powers): {span, gaps,
## fences} (what goes), at its far edge, else its near edge, else both; {} if none of those works.
static func _clearing(gen: LevelGenerator, t: WideGapTuning, row: Dictionary, length: float, keeps: Array[Dictionary]) -> Dictionary:
	if float(row["end"]) - float(row["start"]) >= length - EPSILON:
		return {}
	var others: Array[Dictionary] = []
	for k: Dictionary in keeps:
		if String(k["what"]) != "a fence":
			others.append(k)
	for span: Vector2 in _spans(row, length):
		var plan: Dictionary = _clearing_at(gen, t, row, span, others)
		if not plan.is_empty():
			return plan
	return {}


## _clearing for `row` widened over `span`: {span, gaps, fences} (what goes), or {} if something else than other
## holes and plain fences is in its way (`others`: the keeps but fences).
static func _clearing_at(gen: LevelGenerator, t: WideGapTuning, row: Dictionary, span: Vector2,
		others: Array[Dictionary]) -> Dictionary:
	var lay: LevelLayout = gen.layout
	var half: float = gen.tuning.fence_depth * 0.5
	var zone: Vector2 = zone_of(gen, t, span)
	var what: String = blocker(gen, t, span, row, others)
	if what != "" and what != "another hole":
		return {}
	var fences: Array[Dictionary] = []
	for f: Dictionary in lay.fences:
		if float(f["at"]) + half <= zone.x + EPSILON or float(f["at"]) - half >= zone.y - EPSILON:
			continue
		if bool(f.get("pulsing", false)) or _powered(gen, f):
			return {}
		fences.append(f)
	var gaps: Array[Dictionary] = []
	for g: Dictionary in lay.gaps:
		if float(g["start"]) == float(row["start"]) and float(g["end"]) == float(row["end"]):
			continue
		if float(g["start"]) < zone.y - EPSILON and float(g["end"]) > zone.x + EPSILON:
			gaps.append(g)
	return {"span": span, "gaps": gaps, "fences": fences}


## True if a fence generator in `gen`'s layout powers fence `f` (its EMP takes it down).
static func _powered(gen: LevelGenerator, f: Dictionary) -> bool:
	var gt := EnemyDirector.tuning_for("generator") as FenceGeneratorTuning
	if gt == null:
		return false
	var geo := TrackGeometry.new(gen.layout.lane_count, gen.tuning)
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == "generator" \
				and FenceGenerator.fences_in_reach(gen.layout, geo, float(e["at"]), int(e["lane"]), gt.emp_radius).has(f):
			return true
	return false


## Takes out what `plan` (_clearing) lists. Returns how many pieces went.
static func _clear(gen: LevelGenerator, plan: Dictionary) -> int:
	var lay: LevelLayout = gen.layout
	var out: int = 0
	for g: Dictionary in plan["gaps"]:
		var i: int = lay.gaps.find(g)
		if i >= 0:
			lay.gaps.remove_at(i)
			out += 1
	for f: Dictionary in plan["fences"]:
		var i: int = lay.fences.find(f)
		if i >= 0:
			lay.fences.remove_at(i)
			out += 1
	return out


## Makes the best of the level's own rows that fit (p.candidates) inside `window` (Vector2(from, to)) longer: the
## nearest `target`, rows across more lanes first (_across_bonus), spacing_seconds from every wider gap. False if
## none is there.
static func _widen_one(p: _Pass, window: Vector2, target: float) -> bool:
	var best: Dictionary = _best(p, p.candidates, window, target)
	if best.is_empty():
		return false
	p.candidates.erase(best)
	var row: Dictionary = best["row"]
	p.deferred.append({"start": float(row["start"]), "end": float(row["end"]), "span": best["span"]})
	p.rows.append(best["span"])
	p.widened += 1
	return true


## Like _widen_one, for the level's own rows that only other holes and plain fences keep from fitting
## (_clearing): those go first.
static func _clear_one(p: _Pass, window: Vector2, target: float) -> bool:
	var clearable: Array[Dictionary] = []
	for row: Dictionary in GapDensity.rows(p.gen.layout):
		if p.rows.has(Vector2(float(row["start"]), float(row["end"]))):
			continue
		var plan: Dictionary = _clearing(p.gen, p.t, row, p.length, p.keeps)
		if not plan.is_empty():
			clearable.append({"row": row, "span": plan["span"], "lanes": (row["lanes"] as Array).size(), "plan": plan})
	var best: Dictionary = _best(p, clearable, window, target)
	if best.is_empty():
		return false
	p.taken_out += _clear(p.gen, best["plan"])
	_widen(p.gen.layout, best["row"], best["span"])
	p.rows.append(best["span"])
	p.cleared += 1
	return true


## The one of `candidates` ({span, lanes}) inside `window` and spaced from every wider gap (_spaced) that's
## nearest `target`, in SPREAD_SECONDS, less its _across_bonus; {} if none is.
static func _best(p: _Pass, candidates: Array[Dictionary], window: Vector2, target: float) -> Dictionary:
	var best: Dictionary = {}
	var best_cost: float = INF
	for c: Dictionary in candidates:
		var span: Vector2 = c["span"]
		if span.x < window.x - EPSILON or span.y > window.y + EPSILON or not _spaced(p, span):
			continue
		var cost: float = absf(span.x - target) / (SPREAD_SECONDS * p.gen.speed) - _across_bonus(int(c["lanes"]), p.across)
		if cost < best_cost:
			best_cost = cost
			best = c
	return best


## How much a row of `lanes` holes is preferred, in SPREAD_SECONDS of distance from its target: a jump across most
## lanes (`across` or more) most, two lanes or more somewhat, a single hole (which a runner usually steps around)
## least.
static func _across_bonus(lanes: int, across: int) -> float:
	if lanes >= across:
		return 2.0
	return 1.0 if lanes >= 2 else 0.0


## True if `span` keeps spacing_seconds from every wider gap placed so far.
static func _spaced(p: _Pass, span: Vector2) -> bool:
	var room: float = p.t.spacing_seconds * p.gen.speed
	for other: Vector2 in p.rows:
		if span.x < other.y + room and span.y + room > other.x:
			return false
	return true


## Where each Enforcer Truck chases the runner settled behind them: from bait_after_seconds after it arrives
## until CHASE_END_SECONDS before it gives up.
static func _chases(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var et: EnforcerTruckTuning = EnforcerRules.tuning()
	for e: Dictionary in EnforcerRules.trucks_in(gen.layout):
		var at: float = float(e["at"])
		out.append(Vector2(at + et.bait_after_seconds * gen.speed, at + (et.chase_seconds - CHASE_END_SECONDS) * gen.speed))
	return out


## Adds a new row of the wider length inside `window` (Vector2(from, to)), nearest `target`, where it fits (fits)
## and keeps spacing_seconds from every wider gap: in every lane but one, the lane a one-lane keep holds there
## (keeps_of: a hover truck's), else the open lane seeded. False if none fits there.
static func _add_one(p: _Pass, window: Vector2, target: float) -> bool:
	var gen: LevelGenerator = p.gen
	var lay: LevelLayout = gen.layout
	var n: int = lay.lane_count
	var from: float = maxf(window.x, gen.config.start_clear_distance)
	var to: float = minf(window.y, lay.length - gen.config.end_clear_distance)
	# A first sift with the narrowest margin anywhere (fits() then decides, spot by spot).
	var narrowest: float = maxf(minf(p.t.clear_before_seconds, p.t.clear_after_seconds),
		minf(gen.config.spacing_seconds_easy, gen.config.spacing_seconds_hard)) * gen.speed
	var busy: Array[Vector2] = []
	for keep: Dictionary in p.keeps:
		if int(keep["lane"]) >= 0:
			continue  # One lane only: the new row leaves it open (below).
		var v: Vector2 = keep["span"]
		busy.append(v if bool(keep["row_only"]) else Vector2(v.x - narrowest, v.y + narrowest))
	for g: Dictionary in lay.gaps:
		busy.append(Vector2(float(g["start"]) - narrowest, float(g["end"]) + narrowest))
	var room: float = p.t.spacing_seconds * gen.speed
	for r: Vector2 in p.rows:
		busy.append(Vector2(r.x - room - p.length, r.y + room))
	var best := EMPTY
	var best_kept: int = -1
	for free: Vector2 in LevelGenerator.free_stretches(busy, from, to):
		if free.y - free.x < p.length:
			continue
		# The spots along the stretch, nearest `target` first: the first that fits.
		var spots: Array[float] = []
		var spot: float = free.x
		while spot <= free.y - p.length + EPSILON:
			spots.append(spot)
			spot += ADD_STEP
		spots.append(clampf(target, free.x, free.y - p.length))
		spots.sort_custom(func(a: float, b: float) -> bool: return absf(a - target) < absf(b - target))
		for start: float in spots:
			if best.y >= best.x and absf(start - target) >= absf(best.x - target):
				break
			var span := Vector2(start, start + p.length)
			var kept: Array[int] = _kept_lanes(gen, p.t, span, p.keeps)
			if kept.size() > 1:
				continue
			var lanes: Array[int] = []
			for lane: int in n:
				if kept.is_empty() or lane != kept[0]:
					lanes.append(lane)
			if fits(gen, p.t, span, {"start": span.x, "end": span.y, "lanes": lanes}, p.keeps):
				best = span
				best_kept = -1 if kept.is_empty() else kept[0]
				break
	if best.y < best.x:
		return false
	var open: int = p.rng.randi_range(0, n - 1)
	if best_kept >= 0:
		open = best_kept
	for lane: int in n:
		if lane != open or n == 1:
			lay.gaps.append({"lane": lane, "start": best.x, "end": best.y})
	p.rows.append(best)
	p.added += 1
	return true


## The lanes `keeps`' one-lane keeps (keeps_of: `lane`) hold anywhere in the zone of a wider gap over `span`.
static func _kept_lanes(gen: LevelGenerator, t: WideGapTuning, span: Vector2, keeps: Array[Dictionary]) -> Array[int]:
	var zone: Vector2 = zone_of(gen, t, span)
	var out: Array[int] = []
	for k: Dictionary in keeps:
		var lane: int = int(k["lane"])
		var v: Vector2 = k["span"]
		if lane >= 0 and v.x <= zone.y and v.y >= zone.x and not out.has(lane):
			out.append(lane)
	return out
