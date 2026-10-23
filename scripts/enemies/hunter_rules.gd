extends RefCounted
## Generator rules for the Hunter (task S2; GDD §9.17, the owner, October 23, 2026: "The way the player is supposed to deal
## with the Hunter is by causing one of the overhead gantry platforms to collapse and letting it fall on top of the Hunter";
## proposed: "the rules bring one in only where at least one falling gantryway comes during its chase, so it always has a
## chance to be destroyed (as the Enforcer Truck's baits); never two at once"). LevelGenerator runs apply() for levels with
## the `hunter` feature after the rules of every other feature that plans something on the track (RUN_AFTER): the falling
## gantryways, the teleporters and the Octodog jars are final by then. It has no patterns: these rules place every one.
## - Its baits: the level's falling gantryways (LevelLayout.gantryways), each a pillar in lane L whose walkway the runner
##   steps out from under to the lane on its `side` (GantrywayRules keeps that lane clear). The Hunter rides beside the
##   runner; at the bait it is in the lane on the other side, L - side (its lane, `hunter_lane`), and when the runner steps
##   out away from it, it follows into L, under the walkway. So a gantryway is a bait only where its Hunter lane holds
##   nothing the Hunter must go round (Hunter.blocked_in: a doodad, a fence, a teleporter's pad, a ramp, a floor enemy; it
##   hovers over holes) from bait_lane_before_seconds of run before its pillar to bait_lane_after_seconds past it at the
##   fastest a runner comes through a pillar (GantrywayRules.fastest): its plain fences (never a pulsing one or one a fence
##   generator powers) are taken out to make room there (the gantryways' own clear_plain_pieces), anything else rules the
##   gantryway out. The part from the pillar's lead on the gantryway's own calm stretch keeps clear of every later pass in
##   every lane (GantrywayRules.doodad_keep_outs, fill_keep_outs), the zone doodads keep the level's spacing from a pillar
##   in the lanes beside it, and after_fill takes the fill pass's fences out of the rest.
## - Where it arrives: its entry's `at`, the runner's distance as it comes in from behind (EnemyTuning.behind_runner: no
##   spot it takes up ahead). A bait is in its chase when the pillar comes bait_after_seconds or more after the arrival (it
##   has come up beside the runner and shown its flurry) and bait_before_seconds or more before it gives up
##   (chase_seconds). Where it can, at a seeded bait_prefer_min/max_seconds; the level's introduction of it (where the level
##   gives the feature a start) at the earliest the bait allows, so the first one comes soon after the start. Never before
##   the run-up or the feature's start.
## - A calm arrival (the orchestrator's brief): the stretch from its arrival to arrival_calm_seconds of run on holds no
##   attack or set piece another rule planned (a gantryway's lead and calm stretch, a teleporter's whole span, an Octodog
##   jar's room and its dog's charges, an Octodog's planned charges, a floor cut's window, a wall-run gap's stretch, a dash
##   wall, the debris maze, a fenced ceiling's pick, what the rules keep in every lane), and every later pass keeps off it
##   (doodad_keep_outs as a calm stretch, fill_keep_outs).
## - Up to per_level_max a level, never two at once: each chase (and its drop back) keeps spacing_seconds from the next one's
##   arrival. The earliest baits get them first.
## - Its params: {"baits": [{at, lane, side, id}]}: every bait in its chase (the Hunter comes up on the side away from the
##   next one's step out, Hunter._pick_side), and {"calm": [from, to]}, its calm arrival.
## Its own random stream (LevelGenerator.rng_for), after every other feature's rules: a level without the feature draws
## nothing and is built byte for byte as before; a level with it differs by its Hunters, the plain fences their lanes needed
## taken out, their calm arrivals, and what the danger density pass adds for its higher enemy count. problems() re-checks a
## finished layout (LayoutChecks.check_hunters). DESIGN-TBD (docs/questions/s2.md): every number, the Hunter lane, the calm
## arrival, the introduction at the earliest.

const TYPE: String = "hunter"
## Every feature whose rules place, move or drop enemies, plan charges or cuts, add ceilings, pads, ramps or set pieces, and
## the falling gantryways, the teleporters and the Octodog jars: the Hunters are planned on the level's final rules track.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel", "enforcer_truck",
	"floor_cutter", "treasure_stash", "fenced_ceiling", "dash_wall", "wall_run_gaps", "debris_maze", "centipede",
	"gantryway", "teleporter", "teleporter_blinking", "octodog_jar"]
const GantrywayRules = preload("res://scripts/enemies/gantryway_rules.gd")
## The params keys: its baits, and its calm arrival.
const BAITS: String = "baits"
const CALM: String = "calm"
## The arrival offsets tried round the preferred one (seconds between them).
const OFFSET_STEP: float = 0.5
## Metres round a floor enemy's body its Hunter lane keeps clear of (Hunter.ENEMY_ROOM), and the most a standing enemy steps
## toward the runner before a Hunter passes it (metres at MovementTuning.REFERENCE_SPEED, stretched by the level's pace).
const ENEMY_ROOM: float = 1.3
const WALK_ROOM: float = 4.0

## Review aid (tools/measure/hunters.gd --why): print why a bait got no Hunter.
static var debug: bool = false


static func tuning() -> HunterTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as HunterTuning if res is HunterTuning else HunterTuning.new()


## False when the data allows no Hunter (per_level_max 0).
static func places_any() -> bool:
	return tuning().per_level_max > 0


## The level's Hunters (see the header).
static func apply(gen: LevelGenerator) -> void:
	var t: HunterTuning = tuning()
	if t.per_level_max <= 0 or not gen.config.has_feature(TYPE) or gen.layout.gantryways.is_empty():
		return
	var rng: RandomNumberGenerator = gen.rng_for(TYPE)
	var baits: Array[Dictionary] = bait_points(gen, t)
	var chases: Array[Vector2] = []
	if _pass(gen, t, rng, baits, busy_stretches(gen, true), chases, true) == 0:
		# DESIGN-TBD (docs/questions/s2.md): a level with no calm arrival for any bait still gets one, arriving where only
		# other set pieces' stretches are (never during another attack), with no calm stretch of its own.
		_pass(gen, t, rng, baits, busy_stretches(gen, false), chases, false)
	if debug:
		print("hunters: %d of %d gantryways can be baits" % [baits.size(), gen.layout.gantryways.size()])


## One pass of apply(): a Hunter for each bait in turn, the earliest first, where one may arrive (arrival_problem against
## `busy`; with `calm`, its calm arrival kept), up to per_level_max with `chases` (those placed before). Returns how many
## it placed.
static func _pass(gen: LevelGenerator, t: HunterTuning, rng: RandomNumberGenerator, baits: Array[Dictionary],
		busy: Array[Vector2], chases: Array[Vector2], calm: bool) -> int:
	var start: float = earliest(gen)
	var intro: bool = gen.config.feature_starts.has(TYPE)
	var count: int = 0
	for b: Dictionary in baits:
		if chases.size() >= t.per_level_max:
			break
		var why: Dictionary = {}
		for at: float in _arrival_order(gen, t, rng, b, start, intro and chases.is_empty()):
			var problem: String = arrival_problem(gen, t, at, start, busy, chases)
			if problem != "":
				why[problem.get_slice(" (", 0)] = int(why.get(problem.get_slice(" (", 0), 0)) + 1
				continue
			_place(gen, t, at, baits, chases.size(), calm)
			chases.append(chase_span(gen, t, at))
			count += 1
			why.clear()
			break
		if debug and not why.is_empty():
			print("hunters: no %sarrival for the bait at %.0f m (%.2f): %s" % ["calm " if calm else "", float(b["at"]),
				float(b["at"]) / gen.layout.length, why])
	return count


## Where a Hunter may arrive first: past the run-up and the feature's start.
static func earliest(gen: LevelGenerator) -> float:
	return maxf(gen.config.start_clear_distance, gen.feature_start(TYPE))


## Adds a Hunter arriving at `at`, with every bait of `baits` in its chase: their Hunter lanes' plain fences go. With
## `calm`, its calm arrival is kept (params CALM).
static func _place(gen: LevelGenerator, t: HunterTuning, at: float, baits: Array[Dictionary], index: int,
		calm: bool) -> void:
	var mine: Array = []
	for b: Dictionary in baits:
		if not in_chase(gen, t, b, at):
			continue
		_clear_hunter_lane(gen, t, b)
		mine.append({"at": b["at"], "lane": b["lane"], "side": b["side"], "id": b["id"]})
	var params: Dictionary = {BAITS: mine}
	if calm:
		var span: Vector2 = calm_span(gen, t, at)
		params[CALM] = [span.x, span.y]
	gen.layout.enemies.append({"type": TYPE, "at": at, "lane": gen.layout.lane_count / 2, "side": 0,
		"seed": hash([gen.config.level_seed, TYPE, index]), "params": params})


## The level's gantryways that can be baits (see the header), along the track: {at (its pillar's front), lane, side (its
## step out's), id, hunter_lane, window (the Hunter lane's stretch), fences (the plain ones to take out)}.
static func bait_points(gen: LevelGenerator, t: HunterTuning = null) -> Array[Dictionary]:
	var tt: HunterTuning = t if t != null else tuning()
	var out: Array[Dictionary] = []
	var powered: Array[Dictionary] = GantrywayRules.powered_fences(gen)
	for g: Dictionary in gen.layout.gantryways:
		var lane: int = int(g["lane"])
		var side: int = int(g["side"])
		var hl: int = lane - side
		if hl < 0 or hl >= gen.layout.lane_count:
			continue
		var front: float = float(g["pillar"])
		var window: Vector2 = hunter_lane_window(gen, tt, front)
		var fences: Array[Dictionary] = []
		if _hunter_lane_blocked(gen, hl, window, powered, fences):
			if debug:
				print("hunters: the gantryway at %.0f m (%.2f) is no bait: its Hunter lane %d is shut at %.0f-%.0f m" % [front,
					front / gen.layout.length, hl, window.x, window.y])
			continue
		out.append({"at": front, "lane": lane, "side": side, "id": int(g.get("id", -1)), "hunter_lane": hl,
			"window": window, "fences": fences})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## The stretch of its Hunter lane a bait keeps clear (see the header): from the pillar's lead (its push's lead and a lane
## switch's room before its front at `front`, where the gantryway keeps the lanes beside it from) and
## bait_lane_before_seconds of run more, to bait_lane_after_seconds past its front at the fastest a runner comes through a
## pillar (within its calm stretch).
static func hunter_lane_window(gen: LevelGenerator, t: HunterTuning, front: float) -> Vector2:
	var lead: float = LevelGenerator.doodad_lead_for(gen.tuning) + gen.doodad_lane_room()
	return Vector2(front - lead - t.bait_lane_before_seconds * gen.speed,
		front + t.bait_lane_after_seconds * GantrywayRules.fastest(gen))


## Task S2's hook in the gantryways' rules (GantrywayRules.wanted): where the level introduces the Hunter (it gives the
## feature a start), the stretch its first chase takes its bait in: intro_bait_min_seconds to intro_bait_max_seconds of
## run past the feature's start, so the first Hunter arrives about as the feature starts (a calm arrival found before the
## bait) and shows its flurry before the bait; where no gantryway fits there, anywhere a Hunter arriving as the feature
## starts could still take one (bait_after_seconds to chase_seconds less bait_before_seconds past the start). None in a
## level without the feature, without its start, or whose data allows no Hunter.
static func gantryway_wanted(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var t: HunterTuning = tuning()
	if t.per_level_max <= 0 or not gen.config.has_feature(TYPE) or not gen.config.feature_starts.has(TYPE):
		return out
	var start: float = earliest(gen)
	out.append(Vector2(start + minf(t.intro_bait_min_seconds, t.intro_bait_max_seconds) * gen.speed,
		start + maxf(t.intro_bait_min_seconds, t.intro_bait_max_seconds) * gen.speed))
	out.append(Vector2(start + t.bait_after_seconds * gen.speed, start + (t.chase_seconds - t.bait_before_seconds) * gen.speed))
	return out


## True if lane `hl` holds what a Hunter must go round within `window` that no rule may take out: a doodad, a pulsing or
## powered fence (`powered`), a teleporter's pad, a ramp, a floor enemy's floor. Its plain fences there are added to
## `fences` (to take out).
static func _hunter_lane_blocked(gen: LevelGenerator, hl: int, window: Vector2, powered: Array[Dictionary],
		fences: Array[Dictionary]) -> bool:
	var lay: LevelLayout = gen.layout
	var half: float = gen.tuning.fence_depth * 0.5 + 0.4
	for d: Dictionary in lay.doodads:
		var s: Vector2 = LevelLayout.doodad_extent(d)
		if int(d["lane"]) == hl and s.x <= window.y and s.y >= window.x:
			return true
	for f: Dictionary in lay.fences:
		var at: float = float(f["at"])
		if int(f["lane"]) != hl or at - half > window.y or at + half < window.x:
			continue
		if bool(f.get("pulsing", false)) or powered.has(f):
			return true
		fences.append(f)
	for tp: Dictionary in lay.teleporters:
		if int(tp["lane"]) == hl and float(tp["at"]) - 0.5 <= window.y and float(tp["end"]) + 0.5 >= window.x:
			return true
	for r: Dictionary in lay.ramps:
		var at: float = float(r["at"])
		if lay.outer_lane(int(r["side"])) == hl and at <= window.y and at + gen.tuning.ramp_length >= window.x:
			return true
	for e: Dictionary in lay.enemies:
		if not LevelGenerator.enemy_uses_floor(e) or _enemy_lane(lay, e) != hl:
			continue
		var span: Vector2 = body_span(gen, e)
		if span.x <= window.y and span.y >= window.x:
			return true
	return false


## Where floor enemy entry `e` may be as a Hunter passes it, for its Hunter lane (_hunter_lane_blocked): an Octodog anywhere
## on its run (its floor span: it runs and lunges), any other its body round its spot with ENEMY_ROOM and the few metres a
## cyborg steps toward the runner (WALK_ROOM, at the level's pace).
static func body_span(gen: LevelGenerator, e: Dictionary) -> Vector2:
	if String(e.get("type", "")) == "octodog":
		var run: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
		return Vector2(run.x - ENEMY_ROOM, run.y + ENEMY_ROOM)
	var at: float = float(e["at"])
	return Vector2(at - ENEMY_ROOM - gen.metres(WALK_ROOM), at + ENEMY_ROOM)


static func _enemy_lane(lay: LevelLayout, e: Dictionary) -> int:
	var lane: int = int(e.get("lane", -1))
	if (lane < 0 or lane >= lay.lane_count) and int(e.get("side", 0)) != 0:
		lane = lay.outer_lane(int(e["side"]))
	return lane


## Takes bait `b`'s plain fences out of its Hunter lane (bait_points found them).
static func _clear_hunter_lane(gen: LevelGenerator, _t: HunterTuning, b: Dictionary) -> void:
	var going: Array = b.get("fences", [])
	if going.is_empty():
		return
	var kept: Array[Dictionary] = []
	for f: Dictionary in gen.layout.fences:
		if not going.has(f):
			kept.append(f)
	gen.layout.fences.assign(kept)


## True if bait `b` is in the chase of a Hunter arriving at `at` (see the header).
static func in_chase(gen: LevelGenerator, t: HunterTuning, b: Dictionary, at: float) -> bool:
	var front: float = float(b["at"])
	return front >= at + t.bait_after_seconds * gen.speed - 0.001 \
		and front <= at + (t.chase_seconds - t.bait_before_seconds) * gen.speed + 0.001


## The track a Hunter arriving at `at` takes up: its chase and its drop back out of play.
static func chase_span(gen: LevelGenerator, t: HunterTuning, at: float) -> Vector2:
	return Vector2(at, at + (t.chase_seconds + t.gone_gap / maxf(t.leave_speed, 0.1)) * gen.speed)


## Its calm arrival: from `at` to arrival_calm_seconds of run on.
static func calm_span(gen: LevelGenerator, t: HunterTuning, at: float) -> Vector2:
	return Vector2(at, at + t.arrival_calm_seconds * gen.speed)


## Where a Hunter whose chase takes bait `b` may arrive, best first: the preferred spot (a seeded bait_prefer_min/max_seconds
## before the pillar), then the others in OFFSET_STEP steps nearest it; with `first`, the earliest first (the level's
## introduction: as soon after the feature's start as the bait allows). Never before `start`.
static func _arrival_order(gen: LevelGenerator, t: HunterTuning, rng: RandomNumberGenerator, b: Dictionary, start: float,
		first: bool) -> Array[float]:
	var front: float = float(b["at"])
	var lo: float = t.bait_after_seconds
	var hi: float = t.chase_seconds - t.bait_before_seconds
	var out: Array[float] = []
	if hi < lo - 0.001:
		return out
	var prefer: float = clampf(rng.randf_range(minf(t.bait_prefer_min_seconds, t.bait_prefer_max_seconds),
		maxf(t.bait_prefer_min_seconds, t.bait_prefer_max_seconds)), lo, hi)
	var offsets: Array[float] = []
	var o: float = lo
	while o <= hi + 0.001:
		offsets.append(o)
		o += OFFSET_STEP
	if first:
		offsets.sort_custom(func(a: float, c: float) -> bool: return a > c)
	else:
		offsets.sort_custom(func(a: float, c: float) -> bool: return absf(a - prefer) < absf(c - prefer))
		offsets.push_front(prefer)
	for off: float in offsets:
		var at: float = front - off * gen.speed
		if at >= start - 0.001 and not out.has(at):
			out.append(at)
	return out


## Why a Hunter can't arrive at `at` ("" if it can): before `start`, its arrival (arrival_calm_seconds from `at`) meeting
## a planned attack or set piece (`busy`, busy_stretches) or running into the end-clear stretch, or another Hunter's chase
## (with spacing_seconds).
static func arrival_problem(gen: LevelGenerator, t: HunterTuning, at: float, start: float, busy: Array[Vector2],
		chases: Array[Vector2]) -> String:
	if at < start - 0.001:
		return "before the run-up or the feature's start"
	var calm: Vector2 = calm_span(gen, t, at)
	if calm.y > gen.layout.length - gen.config.end_clear_distance + 0.001:
		return "its arrival runs into the end-clear stretch"
	for k: Vector2 in busy:
		if k.x <= calm.y and k.y >= calm.x:
			return "something planned meets its arrival (%.1f-%.1f m)" % [k.x, k.y]
	var span: Vector2 = chase_span(gen, t, at)
	var room: float = t.spacing_seconds * gen.speed
	for c: Vector2 in chases:
		if span.x < c.y + room and span.y + room > c.x:
			return "another Hunter's chase is on"
	return ""


## What an arrival keeps off (see the header), along the track: every Octodog's planned charges (a jar's dog's whole run
## too: the jars' re-check keeps every rule's keep-outs off it), every floor cut's window, wall-run gap's stretch, dash
## wall, debris maze block and fenced ceiling's pick; and with `calm` (a calm arrival, kept for the passes after the
## rules) what the other rules keep in every lane (a falling gantryway's lead and calm stretch, a teleporter's pad stretch
## and landings, an Octodog jar's room, a treasure stash's floor: their re-checks find nothing of a calm arrival there).
static func busy_stretches(gen: LevelGenerator, calm: bool = true) -> Array[Vector2]:
	var lay: LevelLayout = gen.layout
	var out: Array[Vector2] = []
	for c: Dictionary in lay.cuts:
		out.append(FloorCutPlan.window(c, gen.speed))
	for w: Dictionary in lay.wall_run_gaps:
		out.append(WallRunGapPlacement.keep_out(w))
	for w: Dictionary in lay.dash_walls:
		out.append(LevelGenerator.DashWallRules.footprint(gen, w))
	for b: Dictionary in lay.maze:
		out.append(Vector2(float(b["entry"]), float(b["exit"])))
	for h: Dictionary in lay.hulls:
		var pick: Variant = h.get("pick")
		if pick is Array and (pick as Array).size() == 2:
			out.append(Vector2(float(pick[0]), float(pick[1])))
	var ot := EnemyDirector.tuning_for("octodog") as OctodogTuning
	if ot != null:
		var window: float = ot.window_length(gen.speed, gen.config.enemy_scaling, gen.pace)
		for e: Dictionary in lay.enemies:
			if String(e.get("type", "")) != "octodog":
				continue
			var anchors: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
			if not anchors.is_empty():
				out.append(Vector2(float(anchors[0]) - gen.metres(Octodog.OTHER_ENEMY_BEFORE), float(anchors[-1]) + window))
			var span: Variant = (e.get("params", {}) as Dictionary).get("floor_span")
			if span is Vector2 and LevelLayout.is_held(e):
				out.append(span)
	if calm:
		for k: Dictionary in gen.rules_doodad_keep_outs():
			if not k.has("lane") and String(k.get("type", "")) != TYPE:
				out.append(Vector2(float(k["from"]), float(k["to"])))
	return out


## The level's Hunters, along the track.
static func hunters_in(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE:
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## What the generator keeps off around a Hunter's entry as around an enemy (LevelGenerator.enemy_keep_out: the fill pass's
## margin, the wall fences' calm): nothing (an empty span). It comes from behind and rides beside the runner, never on the
## floor ahead; its calm arrival is doodad_keep_outs' and fill_keep_outs'.
static func keep_out(_gen: LevelGenerator, _e: Dictionary) -> Vector2:
	return Vector2(INF, -INF)


## Each Hunter's calm arrival (params "calm"), along the track.
static func calm_spans(layout: LevelLayout) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e: Dictionary in hunters_in(layout):
		var calm: Variant = (e.get("params", {}) as Dictionary).get(CALM)
		if calm is Array and (calm as Array).size() == 2:
			out.append(Vector2(float(calm[0]), float(calm[1])))
	return out


## What the generator's later passes keep off in every lane (LevelGenerator.rules_doodad_keep_outs): each Hunter's calm
## arrival, a calm stretch (nothing they add may stand or attack in it, but nothing keeps a spacing from it).
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Vector2 in calm_spans(gen.layout):
		out.append({"from": c.x, "to": c.y, "type": TYPE, "calm": true})
	return out


## What the fill pass keeps off in every lane (LevelGenerator.rules_fill_keep_outs): each Hunter's calm arrival.
static func fill_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	return calm_spans(gen.layout)


## After the fill pass (LevelGenerator._fill_empty_stretches): each Hunter's baits' Hunter lanes are kept free of the
## fillers' fences before the pillar's lead (past it the gantryway's calm stretch keeps the fill pass off already).
## Taking a fence out of a row never makes it unfair.
static func after_fill(gen: LevelGenerator) -> void:
	var t: HunterTuning = tuning()
	var lay: LevelLayout = gen.layout
	var half: float = gen.tuning.fence_depth * 0.5 + 0.4
	var powered: Array[Dictionary] = GantrywayRules.powered_fences(gen)
	for e: Dictionary in hunters_in(lay):
		for b: Variant in (e.get("params", {}) as Dictionary).get(BAITS, []):
			var bait: Dictionary = b
			var hl: int = int(bait["lane"]) - int(bait["side"])
			var window: Vector2 = hunter_lane_window(gen, t, float(bait["at"]))
			var kept: Array[Dictionary] = []
			for f: Dictionary in lay.fences:
				var at: float = float(f["at"])
				if int(f["lane"]) == hl and at + half >= window.x and at - half <= window.y \
						and not bool(f.get("pulsing", false)) and not powered.has(f):
					continue
				kept.append(f)
			lay.fences.assign(kept)


## Every placement rule a finished level's Hunters break (see the header), for the tests: [] if none. Run on the finished
## layout, so it also catches a later pass that put something where a Hunter keeps.
static func problems(gen: LevelGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	var t: HunterTuning = tuning()
	var lay: LevelLayout = gen.layout
	var hunters: Array[Dictionary] = hunters_in(lay)
	if hunters.is_empty():
		return out
	if not gen.config.has_feature(TYPE):
		out.append("%d Hunters in a level without the feature" % hunters.size())
	if hunters.size() > t.per_level_max:
		out.append("%d Hunters (at most %d)" % [hunters.size(), t.per_level_max])
	var start: float = earliest(gen)
	var busy_calm: Array[Vector2] = busy_stretches(gen, true)
	var busy: Array[Vector2] = busy_stretches(gen, false)
	var calm_ones: int = 0
	var chases: Array[Vector2] = []
	for e: Dictionary in hunters:
		var at: float = float(e["at"])
		var tag: String = "the Hunter arriving at %.1f m" % at
		var params: Dictionary = e.get("params", {})
		var calm: Variant = params.get(CALM)
		var want: Vector2 = calm_span(gen, t, at)
		if calm != null:
			calm_ones += 1
			if not (calm is Array) or (calm as Array).size() != 2 or absf(float(calm[0]) - want.x) > 0.01 \
					or absf(float(calm[1]) - want.y) > 0.01:
				out.append("%s: its calm arrival isn't arrival_calm_seconds from its arrival" % tag)
		var why: String = arrival_problem(gen, t, at, start, busy_calm if calm != null else busy, chases)
		if why != "":
			out.append("%s: %s" % [tag, why])
		chases.append(chase_span(gen, t, at))
		var baits: Array = params.get(BAITS, [])
		if baits.is_empty():
			out.append("%s: no falling gantryway in its chase" % tag)
		for b: Variant in baits:
			var bait: Dictionary = b
			var g: Dictionary = lay.gantryway_by_id(int(bait.get("id", -1)))
			if g.is_empty() or absf(float(g["pillar"]) - float(bait["at"])) > 0.01 or int(g["lane"]) != int(bait["lane"]) \
					or int(g["side"]) != int(bait["side"]):
				out.append("%s: its bait at %.1f m is no gantryway of the level" % [tag, float(bait["at"])])
				continue
			if not in_chase(gen, t, bait, at):
				out.append("%s: its bait at %.1f m isn't in its chase" % [tag, float(bait["at"])])
			var hl: int = int(bait["lane"]) - int(bait["side"])
			var window: Vector2 = hunter_lane_window(gen, t, float(bait["at"]))
			var fences: Array[Dictionary] = []
			if hl < 0 or hl >= lay.lane_count or _hunter_lane_blocked(gen, hl, window, [], fences) or not fences.is_empty():
				out.append("%s: its bait at %.1f m has something in its lane %d (%.1f-%.1f m)" % [tag, float(bait["at"]), hl,
					window.x, window.y])
	if calm_ones > 0 and calm_ones < hunters.size():
		out.append("%d of %d Hunters arrive calm: a level's Hunters arrive calm, or (with no calm arrival for any bait) none"
			% [calm_ones, hunters.size()])
	return out
