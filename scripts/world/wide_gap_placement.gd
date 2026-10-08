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
## so everything before it is built as it was. The fill pass and the danger density pass's floor pieces then keep
## their spacing from the wider rows as from any piece (the danger density pass counts them as fixed,
## DangerDensity._fixed_stretches), and the doodads, wall fences, wall gaps (wall_keep_outs), City 1's extra gaps
## (GapDensity, keep_outs) and the credits after it keep off them too. With wide_gaps 0 (quick play, the tests)
## and in a boss arena it draws nothing and the level is built exactly as before.
##
## A wider gap goes only where it's fair (fits):
## - a normal jump clears it: its length is a share of a jump at the level's run speed, so it keeps its
##   take-off window in seconds at every zone's speed;
## - never stacked with other demands at take-off or landing: from clear_before_seconds before the take-off to
##   clear_after_seconds after the landing (never less than the level's spacing between two patterns there, its
##   difficulty's: the wider gap is a pattern on its own), no other hole, fence, ramp (or where its wall run
##   drops the runner back), anti-grav pad's zone, speed pad, ceiling's landing zone, floor cut's window,
##   enemy's attack (what the fill pass keeps for it, LevelGenerator.enemy_keep_out, with its floor; for a floor
##   cyborg its obstacle margin, CyborgRules: its bolts never land near a hole anyway, CyborgGun) or attack the
##   rules keep doodads off (a hover truck's stay, a Gilded Sentinel's strike; not a host's possible Bad Dream
##   chase, which the danger density pass exempts too) reaches, in any lane: the runner sees it early, lines up
##   alone and lands on clear floor. No ceiling over the jump itself, and no ramp's wall run over it (keeps_of:
##   `row_only`). Wall and ceiling enemies whose shots keep off holes by their own rules, harmless thieves and
##   the Enforcer Truck (NO_KEEP_TYPES) don't count;
## - between the run-up and the end-clear stretch, and spacing_seconds from another wider gap.
## Where they come from, in this order until the level has its count:
## 1. The level's own rows (the patterns'), made longer: at the far edge (the take-off stays where the pattern
##    put it), else the near edge, else both, whichever fits first (_widened).
## 2. With add_rows, new rows of the wider length in every lane but one (the open lane seeded), where the
##    track is clear around them by the same margins (_add_rows).
## 3. The level's rows that only other holes and plain fences keep from fitting, with those taken out
##    (_clearing: never a pulsing fence or one a fence generator powers; the generator's way to make room for a
##    guarantee, as PadPlacement's: taking content out never makes a level unfair).
## Which ones: with prefer_enforcer_chases, first one in each Enforcer Truck's chase, once the truck has settled
## behind the runner (EnforcerTruckTuning.bait_after_seconds), so the runner can lead it in; then the rest spread
## through the level, rows across most of the lanes (a jump) before single holes. DESIGN-TBD
## (docs/questions/g7.md): the width, the margins, the count and which rows.

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
	var t: WideGapTuning = tuning()
	var lay: LevelLayout = gen.layout
	var length: float = length_for(gen, t)
	var rng: RandomNumberGenerator = gen.rng_for("wide_gaps")
	var keeps: Array[Dictionary] = keeps_of(gen)
	var candidates: Array[Dictionary] = []
	var blocked: Dictionary = {}
	for row: Dictionary in GapDensity.rows(lay):
		var span: Vector2 = _widened(gen, t, row, length, keeps)
		if span.y > span.x:
			candidates.append({"row": row, "span": span, "lanes": (row["lanes"] as Array).size()})
		else:
			var what: String = blocker(gen, t, Vector2(float(row["start"]), float(row["start"]) + length), row, keeps)
			blocked[what] = int(blocked.get(what, 0)) + 1
	var rows: Array[Vector2] = []
	for c: Dictionary in _choose(gen, t, rng, candidates, want, rows):
		_widen(lay, c["row"], c["span"])
		rows.append(c["span"])
	var widened: int = rows.size()
	var added: int = 0
	if rows.size() < want and t.add_rows:
		added = _add_rows(gen, t, rng, length, keeps, rows, want - rows.size())
	# Still too few: rows only other holes and plain fences keep from widening get them taken out.
	var cleared: int = 0
	var taken_out: int = 0
	if rows.size() < want:
		var clearable: Array[Dictionary] = []
		for row: Dictionary in GapDensity.rows(lay):
			if rows.has(Vector2(float(row["start"]), float(row["end"]))):
				continue
			var plan: Dictionary = _clearing(gen, t, row, length, keeps)
			if not plan.is_empty():
				clearable.append({"row": row, "span": plan["span"], "lanes": (row["lanes"] as Array).size(), "plan": plan})
		for c: Dictionary in _choose(gen, t, rng, clearable, want - rows.size(), rows):
			taken_out += _clear(gen, c["plan"])
			_widen(lay, c["row"], c["span"])
			rows.append(c["span"])
			cleared += 1
		if taken_out > 0:
			GeneratorRules.keep_powered(gen)
	rows.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var constraints: PackedStringArray = []
	if rows.size() < want:
		constraints.append("only %d of %d wider gaps fit: nowhere else has its margins clear (or the spacing)" % [rows.size(), want])
	return {"target": want, "rows": rows, "widened": widened, "added": added, "cleared": cleared,
		"taken_out": taken_out, "blocked": blocked, "constraints": constraints}


## The wider rows `gen`'s last build placed (wide_gap_result), each Vector2(start, end).
static func rows_of(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for v: Variant in gen.wide_gap_result.get("rows", []):
		out.append(v as Vector2)
	return out


## The rows of `layout` (GapDensity.rows) longer than `fraction` of a jump of `jump` metres: a level's wider
## gaps (its other rows are 0.55 of a jump at most), for the tests and the review tools.
static func wide_rows(layout: LevelLayout, jump: float, fraction: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in GapDensity.rows(layout):
		if float(row["end"]) - float(row["start"]) > fraction * jump + EPSILON:
			out.append(row)
	return out


## What the passes after this one keep off around each wider gap, as Vector2(from, to): its take-off and
## landing margins (fits): City 1's extra gaps (GapDensity) keep their own spacing from these too.
static func keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var t: WideGapTuning = tuning()
	for span: Vector2 in rows_of(gen):
		out.append(zone_of(gen, t, span))
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
## (clear_before_seconds and clear_after_seconds, never less than the level's spacing between two patterns at
## its difficulty there).
static func zone_of(gen: LevelGenerator, t: WideGapTuning, span: Vector2) -> Vector2:
	return Vector2(span.x - maxf(t.clear_before_seconds, _spacing(gen, span.x)) * gen.speed,
		span.y + maxf(t.clear_after_seconds, _spacing(gen, span.y)) * gen.speed)


## True if a wider gap over `span` (Vector2(start, end)) fits in `gen`'s layout (see the header): its zone
## (zone_of) between the run-up and the end-clear stretch, nothing of `keeps` (keeps_of) in its zone (or, for a
## keep that's `row_only`, over its span) and no hole but those of `row` (the row being widened; {} for none) in
## its zone.
static func fits(gen: LevelGenerator, t: WideGapTuning, span: Vector2, row: Dictionary, keeps: Array[Dictionary]) -> bool:
	return blocker(gen, t, span, row, keeps) == ""


## What keeps a wider gap over `span` from fitting (fits): the level's ends, the first of `keeps` in its way, or
## another hole; "" if it fits.
static func blocker(gen: LevelGenerator, t: WideGapTuning, span: Vector2, row: Dictionary, keeps: Array[Dictionary]) -> String:
	var zone: Vector2 = zone_of(gen, t, span)
	if zone.x < gen.config.start_clear_distance or zone.y > gen.layout.length - gen.config.end_clear_distance:
		return "the run-up or the end-clear stretch"
	for k: Dictionary in keeps:
		var v: Vector2 = k["span"]
		var against: Vector2 = span if bool(k["row_only"]) else zone
		if v.x <= against.y and v.y >= against.x:
			return String(k["what"])
	for g: Dictionary in gen.layout.gaps:
		if not row.is_empty() and float(g["start"]) == float(row["start"]) and float(g["end"]) == float(row["end"]):
			continue
		if float(g["start"]) <= zone.y and float(g["end"]) >= zone.x:
			return "another hole"
	return ""


## Everything but holes a wider gap keeps off, in any lane (see the header): {span (Vector2(from, to)), what (for
## the report), row_only (true: it keeps off the wider gap itself only, not its margins: a ceiling over it, a
## ramp's wall run over it)}.
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
		var k: Vector2 = gen.enemy_keep_out(e, hooks)
		if k.y >= k.x:
			out.append(_keep(k, type))
		var floor_span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
		if floor_span.y >= floor_span.x:
			out.append(_keep(floor_span, type))
	for c: Dictionary in lay.cuts:
		out.append(_keep(FloorCutPlan.window(c, gen.speed), "a floor cut"))
	# What the rules keep doodads off (a hover truck's stay in its lane, a Gilded Sentinel's strike), but for the
	# features the danger density pass exempts too (its tuning's keep_out_exempt_features: a host's chase, which
	# only comes if the player kills the host).
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
			out.append(_keep(Vector2(float(k["from"]), float(k["to"])), String(k.get("type", feature))))
	for d: Dictionary in lay.doodads:
		out.append(_keep(Vector2(float(d["start"]), float(d["end"])), "a doodad"))
	return out


static func _keep(span: Vector2, what: String, row_only: bool = false) -> Dictionary:
	return {"span": span, "what": what, "row_only": row_only}


## The level's spacing between two patterns at its difficulty at track distance `at` (seconds): its ordinary
## pacing, not a level paced in bursts' quiet spacing (The Hush), which is pacing, not reaction time.
static func _spacing(gen: LevelGenerator, at: float) -> float:
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
	var lay: LevelLayout = gen.layout
	if float(row["end"]) - float(row["start"]) >= length - EPSILON:
		return {}
	var others: Array[Dictionary] = []
	for k: Dictionary in keeps:
		if String(k["what"]) != "a fence":
			others.append(k)
	var half: float = gen.tuning.fence_depth * 0.5
	for span: Vector2 in _spans(row, length):
		var zone: Vector2 = zone_of(gen, t, span)
		var what: String = blocker(gen, t, span, row, others)
		if what != "" and what != "another hole":
			continue
		var fences: Array[Dictionary] = []
		var ok: bool = true
		for f: Dictionary in lay.fences:
			if float(f["at"]) + half < zone.x or float(f["at"]) - half > zone.y:
				continue
			if bool(f.get("pulsing", false)) or _powered(gen, f):
				ok = false
				break
			fences.append(f)
		if not ok:
			continue
		var gaps: Array[Dictionary] = []
		for g: Dictionary in lay.gaps:
			if float(g["start"]) == float(row["start"]) and float(g["end"]) == float(row["end"]):
				continue
			if float(g["start"]) <= zone.y and float(g["end"]) >= zone.x:
				gaps.append(g)
		return {"span": span, "gaps": gaps, "fences": fences}
	return {}


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


## The rows to widen, up to `want` (see the header), along the track, spaced from those already placed (`taken`).
static func _choose(gen: LevelGenerator, t: WideGapTuning, rng: RandomNumberGenerator, candidates: Array[Dictionary],
		want: int, taken: Array[Vector2]) -> Array[Dictionary]:
	var chosen: Array[Dictionary] = []
	var across: int = maxi(1, gen.layout.lane_count - 1)
	if t.prefer_enforcer_chases:
		for chase: Vector2 in _chases(gen):
			if chosen.size() >= want:
				break
			var pool: Array[Dictionary] = []
			for c: Dictionary in candidates:
				var span: Vector2 = c["span"]
				if span.x >= chase.x and span.y <= chase.y and _spaced(gen, t, span, chosen, taken):
					pool.append(c)
			if pool.is_empty():
				continue
			# A jump across most lanes first (the truck follows the runner into one), the earliest of those.
			var best: Dictionary = pool[0]
			for c: Dictionary in pool:
				if int(c["lanes"]) >= across and int(best["lanes"]) < across:
					best = c
			chosen.append(best)
	var from: float = gen.config.start_clear_distance
	var to: float = gen.layout.length - gen.config.end_clear_distance
	var left: int = want - chosen.size()
	for k: int in left:
		var target: float = lerpf(from, to, (float(k) + rng.randf_range(0.25, 0.75)) / float(left))
		var best: Dictionary = {}
		var best_cost: float = INF
		for c: Dictionary in candidates:
			var span: Vector2 = c["span"]
			if chosen.has(c) or not _spaced(gen, t, span, chosen, taken):
				continue
			var cost: float = absf(span.x - target) / (SPREAD_SECONDS * gen.speed) - _across_bonus(int(c["lanes"]), across)
			if cost < best_cost:
				best_cost = cost
				best = c
		if best.is_empty():
			break
		chosen.append(best)
	chosen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["span"] as Vector2).x < (b["span"] as Vector2).x)
	return chosen


## How much a row of `lanes` holes is preferred, in SPREAD_SECONDS of distance from its spread target: a jump
## across most lanes (`across` or more) most, two lanes or more somewhat, a single hole (which a runner usually
## steps around) least.
static func _across_bonus(lanes: int, across: int) -> float:
	if lanes >= across:
		return 2.0
	return 1.0 if lanes >= 2 else 0.0


## True if `span` keeps spacing_seconds from every chosen wider gap's and every one already placed (`taken`).
static func _spaced(gen: LevelGenerator, t: WideGapTuning, span: Vector2, chosen: Array[Dictionary],
		taken: Array[Vector2]) -> bool:
	var room: float = t.spacing_seconds * gen.speed
	var others: Array[Vector2] = taken.duplicate()
	for c: Dictionary in chosen:
		others.append(c["span"])
	for other: Vector2 in others:
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


## Adds up to `count` new rows of the wider length (every lane but one, the open lane seeded) where they fit
## (fits), spread like the widened ones and spacing_seconds from every wider gap (`rows`, which grows). Returns
## how many it added.
static func _add_rows(gen: LevelGenerator, t: WideGapTuning, rng: RandomNumberGenerator, length: float,
		keeps: Array[Dictionary], rows: Array[Vector2], count: int) -> int:
	var lay: LevelLayout = gen.layout
	var n: int = lay.lane_count
	var from: float = gen.config.start_clear_distance
	var to: float = lay.length - gen.config.end_clear_distance
	# A conservative first sift (the widest margin anywhere), then fits() decides.
	var widest: float = maxf(maxf(t.clear_before_seconds, t.clear_after_seconds),
		maxf(gen.config.spacing_seconds_easy, gen.config.spacing_seconds_hard)) * gen.speed
	var added: int = 0
	for k: int in count:
		var busy: Array[Vector2] = []
		for keep: Dictionary in keeps:
			var v: Vector2 = keep["span"]
			busy.append(v if bool(keep["row_only"]) else Vector2(v.x - widest, v.y + widest))
		for g: Dictionary in lay.gaps:
			busy.append(Vector2(float(g["start"]) - widest, float(g["end"]) + widest))
		var room: float = t.spacing_seconds * gen.speed
		for r: Vector2 in rows:
			busy.append(Vector2(r.x - room - length, r.y + room))
		var target: float = lerpf(from, to, (float(k) + rng.randf_range(0.25, 0.75)) / float(count))
		var best := EMPTY
		for free: Vector2 in LevelGenerator.free_stretches(busy, from, to):
			if free.y - free.x < length:
				continue
			var start: float = clampf(target, free.x, free.y - length)
			var span := Vector2(start, start + length)
			if not fits(gen, t, span, {}, keeps):
				continue
			if best.y < best.x or absf(span.x - target) < absf(best.x - target):
				best = span
		if best.y < best.x:
			break
		var open: int = rng.randi_range(0, n - 1)
		for lane: int in n:
			if lane != open or n == 1:
				lay.gaps.append({"lane": lane, "start": best.x, "end": best.y})
		rows.append(best)
		added += 1
	return added
