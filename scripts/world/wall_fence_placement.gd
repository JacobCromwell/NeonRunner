class_name WallFencePlacement
extends RefCounted
## Where the generator puts wall fences (task B5; GDD §9.1: "electric fences that span a side wall and
## turn off and on from time to time, to make the walls less safe"; full-height ones from Marketplace 2,
## partial ones over the low or the high part of the wall from the Corporate zone). LevelGenerator runs
## place() after the zone doodads and before the credits (_place_wall_fences), for a level with the
## `wall_fences` or `wall_fences_partial` feature, on a random stream of its own: wall fences only add
## to the walls, so everything else in a level (the patterns, the rules, the fillers, the doodads and
## the credits) comes out exactly as it does without them, and a level without the features is built
## byte for byte as before. Wall fences have no patterns.
##
## The fairness rules, each a stretch of track where a wall fence on one wall may not stand
## (keep_outs(); the times are WallFenceTuning's, seconds at the level's run speed, so they keep their
## seconds at every zone's speed, GDD §3):
## - its wall: never on the same wall section as a sign or a window cyborg (GDD §9.1; wall_clear_seconds
##   either side), nor where a wall vent's screech swipes up that wall (vent_before/after_seconds), nor
##   where a ramp launches the player along that wall (GDD §9.1: never where a ramp launches the player
##   into one while it's on), from just before the ramp to past the end of the longest wall run it can
##   launch (RampLaunch with its fading boost, R1, plus claws' longer wall runs and a speed pad's boost
##   carried onto it);
## - the floor beside it: a wall runner who sees it on, or its warning, drops off the wall with a wall
##   jump, into the outer lane on its side, so that lane holds no hole, fence, floor cut, pad, speed pad,
##   ramp or floor enemy from drop_before_seconds before it to drop_after_seconds after it (its drop
##   window), and no hover truck keeps that lane meanwhile;
## - what runs meanwhile: no floor cut's window (B4: nothing else goes on during a cut), no big attack
##   (an enemy keep-out of the drone's, the hover truck's, the Octodog's, the Resonator's or a floor
##   cut's cause) and no Bad Dream chase reaches its drop window (the wall is one of their escapes; one
##   big thing at a time);
## - the level: its drop window between the run-up and the end-clear stretch;
## - other wall fences: same_side_gap_seconds apart on one wall (a wall run meets one at a time), and
##   gap_seconds apart on either.
## Zone doodads (G5) need no rule: they stand in inner lanes only, never pushing anyone onto a wall, and
## a wall fence's field never reaches a floor runner (WallFencePlan.reach), so neither ever meets the
## other; their keep-outs stay as they were.
##
## How many, and where: from the feature's start, a spot every spacing_seconds of run or so (from easy
## to hard with the difficulty there, varied by spacing_jitter), on a random wall (the other if that one
## has no fair spot within search_seconds), each at the first fair spot from there. Past the
## `wall_fences_partial` feature's start, partial_share of them cover only the low or the high part of
## the wall, each as likely. Each pulses on the level clock (pulse times from easy to hard, a random
## phase).
## - The introduction (a level that gives a feature a start, LevelConfig.feature_starts: Marketplace 2's
##   full-height ones, Corporate 1's partial ones) comes first, within intro_seconds of the start, alone:
##   at the first fair spot where the floor beside it is clear in every lane over its drop window and no
##   enemy is about (where one comes in time; else the first fair spot), with a long off time
##   (intro_off_seconds), so the player meets it gently, right after its first-encounter hint.
## - Every feature appears (GDD §5; LevelGenerator.feature_positions): a level left without a
##   full-height one (or a partial one, with the partial feature) gets one at the first fair spot past
##   its start; a level with no fair spot at all gets a warning.
## DESIGN-TBD (docs/questions/b5.md): the numbers (WallFenceTuning), the drop window, and keeping off
## big attacks.

const FEATURE: String = "wall_fences"
const PARTIAL: String = "wall_fences_partial"
const TUNING_PATH: String = "res://data/tuning/wall_fences.tres"
## Claws lengthen wall runs (PowerupTuning.claws_wall_time_multiplier): a ramp's longest wall run.
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
## Enemy types whose attacks are big ones (their rules scripts' keep_out, LevelGenerator.enemy_keep_out):
## a wall fence's drop window keeps off them.
const BIG_ATTACKS: PackedStringArray = ["drone", "hover_truck", "octodog", "resonator", "floor_cutter"]
## Metres past the end of a stretch it may not stand in where a wall fence may stand again.
const EPSILON: float = 0.01


static func tuning() -> WallFenceTuning:
	var res: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return res as WallFenceTuning if res is WallFenceTuning else WallFenceTuning.new()


## Places the level's wall fences (see the header), into gen.layout.wall_fences, in track order.
static func place(gen: LevelGenerator) -> void:
	var t: WallFenceTuning = tuning()
	var lay: LevelLayout = gen.layout
	var full_on: bool = gen.config.has_feature(FEATURE)
	var partial_on: bool = gen.config.has_feature(PARTIAL)
	if not full_on and not partial_on:
		return
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	# What each wall keeps them off, before any wall fence: [left, right].
	var keeps: Array = [merged(keep_outs(gen, lay, -1, t)), merged(keep_outs(gen, lay, 1, t))]
	var last: float = lay.length - gen.config.end_clear_distance
	var cursor: float = maxf(gen.feature_start(FEATURE if full_on else PARTIAL), gen.config.start_clear_distance)
	# The introductions, first and gently.
	if full_on and gen.config.feature_starts.has(FEATURE):
		var intro: Dictionary = _introduce(gen, t, rng, keeps, "full", gen.feature_start(FEATURE))
		if not intro.is_empty():
			cursor = float(intro["at"])
	if partial_on and gen.config.feature_starts.has(PARTIAL):
		_introduce(gen, t, rng, keeps, _partial_band(rng), gen.feature_start(PARTIAL))
	# The rest, about a spacing apart.
	while true:
		var difficulty: float = gen.difficulty_at(clampf(cursor / lay.length, 0.0, 1.0))
		var spacing: float = WallFenceTuning.by_difficulty(t.spacing_seconds_easy, t.spacing_seconds_hard, difficulty)
		cursor += spacing * (1.0 + rng.randf_range(-t.spacing_jitter, t.spacing_jitter)) * gen.speed
		if cursor > last:
			break
		var band: String = "full"
		if partial_on and gen.feature_active(PARTIAL, cursor) and (not full_on or rng.randf() < t.partial_share):
			band = _partial_band(rng)
		elif not full_on:
			continue
		var side: int = -1 if rng.randf() < 0.5 else 1
		var entry: Dictionary = _fit(gen, t, rng, keeps, band, [side, -side], cursor,
			cursor + t.search_seconds * gen.speed, false)
		if not entry.is_empty():
			cursor = float(entry["at"])
	# Every feature appears (GDD §5).
	if full_on and _count(lay, false) == 0:
		_guarantee(gen, t, rng, keeps, "full")
	if partial_on and _count(lay, true) == 0:
		_guarantee(gen, t, rng, keeps, _partial_band(rng))
	lay.wall_fences.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))


## Why wall fence `entry` (WallFencePlan.make) can't stand where it lies in `lay` (the generator's own
## layout by default), or "" if it can: the fairness rules of the header (keep_outs), and its spacing
## from the other wall fences there. A boss arena asks it before adding one (BossArena.wall_fence_problem).
## It doesn't look at the level's features or their starts (place() keeps to those).
static func problem(gen: LevelGenerator, entry: Dictionary, lay: LevelLayout = null) -> String:
	var layout: LevelLayout = lay if lay != null else gen.layout
	var t: WallFenceTuning = tuning()
	var side: int = int(entry.get("side", 0))
	if side != -1 and side != 1:
		return "side %d is no wall" % side
	if not WallFencePlan.BANDS.has(String(entry.get("band", ""))):
		return "no band '%s'" % entry.get("band", "")
	if float(entry.get("pulse_on", 0.0)) <= 0.0 or float(entry.get("pulse_off", 0.0)) < gen.tuning.fence_pulse_warning:
		return "it must switch on and off, with its whole warning in its off time"
	var phase: float = float(entry.get("phase", -1.0))
	if phase < 0.0 or phase >= 1.0:
		return "its phase %.2f isn't within its cycle" % phase
	var at: float = float(entry["at"])
	for k: Dictionary in keep_outs(gen, layout, side, t):
		if at >= float(k["from"]) and at <= float(k["to"]):
			return String(k["why"])
	for w: Dictionary in layout.wall_fences:
		if is_same(w, entry):
			continue
		var apart: float = absf(float(w["at"]) - at)
		if apart < t.gap_seconds * gen.speed:
			return "another wall fence stands %.1f m away" % apart
		if int(w["side"]) == side and apart < t.same_side_gap_seconds * gen.speed:
			return "another wall fence stands %.1f m away on its wall" % apart
	return ""


## The stretches of track where a wall fence on wall `side` of `lay` may not stand (its `at`), at the
## generator's run speed: {from, to, why}, in no particular order. See the header for the rules.
static func keep_outs(gen: LevelGenerator, lay: LevelLayout, side: int, t: WallFenceTuning) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var v: float = gen.speed
	var tuning: MovementTuning = gen.tuning
	var half: float = tuning.fence_depth * 0.5
	var before: float = t.drop_before_seconds * v
	var after: float = t.drop_after_seconds * v
	var clear: float = t.wall_clear_seconds * v + half
	var lane: int = lay.outer_lane(side)
	# The level: its drop window between the run-up and the end-clear stretch.
	out.append({"from": -INF, "to": gen.config.start_clear_distance + before - EPSILON, "why": "in the run-up"})
	out.append({"from": lay.length - gen.config.end_clear_distance - after + EPSILON, "to": INF,
		"why": "in the end-clear stretch"})
	# Its wall: signs, window cyborgs, wall vents, ramps.
	for s: Dictionary in lay.signs:
		if int(s["side"]) == side:
			out.append({"from": float(s["start"]) - clear, "to": float(s["end"]) + clear, "why": "a sign is on its wall section"})
	var window: float = _window_cyborg_half_length()
	for e: Dictionary in lay.enemies:
		if int(e.get("side", 0)) != side:
			continue
		var at: float = float(e["at"])
		match String(e.get("type", "")):
			"window_cyborg":
				out.append({"from": at - window - clear, "to": at + window + clear,
					"why": "a window cyborg is on its wall section"})
			"screech":
				if String((e.get("params", {}) as Dictionary).get("source", "vent")) == "vent":
					out.append({"from": at - t.vent_before_seconds * v - half, "to": at + t.vent_after_seconds * v + half,
						"why": "a wall vent's screech swipes up its wall there"})
	for r: Dictionary in lay.ramps:
		if int(r["side"]) == side:
			out.append({"from": float(r["at"]) - t.ramp_before_seconds * v - half,
				"to": ramp_run_end(gen, r) + t.ramp_after_seconds * v + half, "why": "a ramp launches the player along its wall"})
	# The floor beside it: its drop window in the outer lane.
	var drop: Array[Vector2] = []
	for g: Dictionary in lay.gaps:
		if int(g["lane"]) == lane:
			drop.append(Vector2(float(g["start"]), float(g["end"])))
	var fence_half: float = tuning.fence_depth * 0.5
	for f: Dictionary in lay.fences:
		if int(f["lane"]) == lane:
			drop.append(Vector2(float(f["at"]) - fence_half, float(f["at"]) + fence_half))
	for c: Dictionary in lay.cuts:
		if int(c["lane"]) == lane:
			drop.append(FloorCutPlan.lane_window(c))
	for p: Dictionary in lay.pads:
		if int(p["lane"]) == lane:
			drop.append(Vector2(float(p["at"]), float(p["at"]) + tuning.pad_length))
	for p: Dictionary in lay.speed_pads:
		if int(p["lane"]) == lane:
			drop.append(Vector2(float(p["at"]), float(p["at"]) + tuning.speed_pad_length))
	for r: Dictionary in lay.ramps:
		if lay.outer_lane(int(r["side"])) == lane:
			drop.append(Vector2(float(r["at"]), float(r["at"]) + tuning.ramp_length))
	for e: Dictionary in lay.enemies:
		# Wall enemies (side ±1) are its wall's business, above.
		if int(e.get("side", 0)) == 0 and int(e.get("lane", -1)) == lane:
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
			if span.y >= span.x:
				drop.append(span)
	# The rules' lane-bound attacks (a hover truck's lane for its whole stay) and the ones in every lane
	# (a Bad Dream's chase).
	var attacks: Array[Dictionary] = gen.rules_doodad_keep_outs()
	for k: Dictionary in attacks:
		if k.has("lane") and int(k["lane"]) == lane:
			drop.append(Vector2(float(k["from"]), float(k["to"])))
	for s: Vector2 in drop:
		out.append({"from": s.x - after, "to": s.y + before, "why": "the outer lane beside it isn't clear to drop off into"})
	# What runs meanwhile: floor cuts, big attacks, Bad Dream chases.
	var busy: Array[Vector2] = []
	for c: Dictionary in lay.cuts:
		busy.append(FloorCutPlan.window(c, v))
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		if BIG_ATTACKS.has(String(e.get("type", ""))):
			busy.append(gen.enemy_keep_out(e, hooks))
	for k: Dictionary in attacks:
		if not k.has("lane"):
			busy.append(Vector2(float(k["from"]), float(k["to"])))
	for s: Vector2 in busy:
		if s.y >= s.x:
			out.append({"from": s.x - after, "to": s.y + before, "why": "a floor cut or a big attack runs meanwhile"})
	return out


## The end of the longest wall run ramp `r` can launch at the level's run speed: with claws' longer wall
## runs and a speed pad's boost carried onto it, on top of its own fading boost (RampLaunch).
static func ramp_run_end(gen: LevelGenerator, r: Dictionary) -> float:
	var claws: float = 1.0
	var pt := load(POWERUPS_PATH) as PowerupTuning if ResourceLoader.exists(POWERUPS_PATH) else null
	if pt != null:
		claws = maxf(pt.claws_wall_time_multiplier, 1.0)
	var longest: RampLaunch = RampLaunch.of(r, gen.tuning, gen.speed, gen.tuning.speed_pad_boost, claws)
	return maxf(longest.end(), gen.ramp_launch(r).end())


## A stretch of track [from, to] where a wall fence's drop window (from drop_before_seconds before it
## to drop_after_seconds after it) lies, around one at `at`, at the generator's run speed.
static func drop_window(gen: LevelGenerator, at: float, t: WallFenceTuning = null) -> Vector2:
	var tt: WallFenceTuning = t if t != null else tuning()
	return Vector2(at - tt.drop_before_seconds * gen.speed, at + tt.drop_after_seconds * gen.speed)


## `keeps` (keep_outs entries, or Vector2 stretches) as sorted, merged Vector2 stretches.
static func merged(keeps: Array) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for k: Variant in keeps:
		if k is Vector2:
			spans.append(k)
		else:
			spans.append(Vector2(float((k as Dictionary)["from"]), float((k as Dictionary)["to"])))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array[Vector2] = []
	for s: Vector2 in spans:
		if not out.is_empty() and s.x <= out[-1].y:
			out[-1] = Vector2(out[-1].x, maxf(out[-1].y, s.y))
		else:
			out.append(s)
	return out


## The first track distance in [lo, hi] that none of the sorted, merged stretches `blocked` covers; INF
## if there's none.
static func first_free(blocked: Array[Vector2], lo: float, hi: float) -> float:
	var at: float = lo
	for b: Vector2 in blocked:
		if b.y < at:
			continue
		if b.x > at:
			break
		at = b.y + EPSILON
	return at if at <= hi else INF


## How many wall fences `lay` has: partial ones with `partial`, else full-height ones.
static func _count(lay: LevelLayout, partial: bool) -> int:
	var n: int = 0
	for w: Dictionary in lay.wall_fences:
		if WallFencePlan.is_partial(w) == partial:
			n += 1
	return n


static func _partial_band(rng: RandomNumberGenerator) -> String:
	return "low" if rng.randf() < 0.5 else "high"


## The introduction of a wall fence of `band` (see the header): the first fair spot within intro_seconds
## of `start`, where the floor is calm in every lane if such a spot comes in time. Returns its entry,
## or {} if none fits in time (a later one then comes first).
static func _introduce(gen: LevelGenerator, t: WallFenceTuning, rng: RandomNumberGenerator, keeps: Array,
		band: String, start: float) -> Dictionary:
	var by: float = start + t.intro_seconds * gen.speed
	var side: int = -1 if rng.randf() < 0.5 else 1
	var entry: Dictionary = _fit(gen, t, rng, keeps, band, [side, -side], start, by, true, merged(_calm_keep_outs(gen, t)))
	if entry.is_empty():
		entry = _fit(gen, t, rng, keeps, band, [side, -side], start, by, true)
	return entry


## A level left without a wall fence of `band`'s kind gets one at the first fair spot past its start, or
## a warning if there's none at all.
static func _guarantee(gen: LevelGenerator, t: WallFenceTuning, rng: RandomNumberGenerator, keeps: Array,
		band: String) -> void:
	var side: int = -1 if rng.randf() < 0.5 else 1
	var entry: Dictionary = _fit(gen, t, rng, keeps, band, [side, -side], 0.0, gen.layout.length, false)
	if entry.is_empty():
		gen.warnings.append("wall fences: no fair spot anywhere for a %s one (every feature should appear, GDD §5)" % band)


## Adds a wall fence of `band` at the first fair spot in [lo, hi] (and past its feature's start) on the
## first of `sides` that has one: its pulse times from the difficulty there (the introduction's off time
## at least intro_off_seconds), a random phase. `calm` (merged stretches) keeps it off more. Returns its
## entry, or {} (adding nothing) if no spot fits.
static func _fit(gen: LevelGenerator, t: WallFenceTuning, rng: RandomNumberGenerator, keeps: Array, band: String,
		sides: Array, lo: float, hi: float, intro: bool, calm: Array[Vector2] = []) -> Dictionary:
	var lay: LevelLayout = gen.layout
	var from: float = maxf(lo, gen.feature_start(FEATURE))
	if band != "full":
		from = maxf(from, gen.feature_start(PARTIAL))
	var difficulty: float = gen.difficulty_at(clampf(from / lay.length, 0.0, 1.0))
	var on: float = WallFenceTuning.by_difficulty(t.on_seconds_easy, t.on_seconds_hard, difficulty) \
		+ rng.randf_range(-t.pulse_jitter_seconds, t.pulse_jitter_seconds)
	var off: float = WallFenceTuning.by_difficulty(t.off_seconds_easy, t.off_seconds_hard, difficulty) \
		+ rng.randf_range(-t.pulse_jitter_seconds, t.pulse_jitter_seconds)
	if intro:
		off = maxf(off, t.intro_off_seconds)
	off = maxf(off, gen.tuning.fence_pulse_warning + 0.2)
	var phase: float = rng.randf()
	for side: Variant in sides:
		var s: int = int(side)
		var blocked: Array = (keeps[0 if s < 0 else 1] as Array).duplicate()
		blocked.append_array(calm)
		for w: Dictionary in lay.wall_fences:
			var gap: float = (t.same_side_gap_seconds if int(w["side"]) == s else t.gap_seconds) * gen.speed
			blocked.append(Vector2(float(w["at"]) - gap + EPSILON, float(w["at"]) + gap - EPSILON))
		var at: float = first_free(merged(blocked), from, hi)
		if at < INF:
			var entry: Dictionary = WallFencePlan.make(s, at, band, on, off, phase)
			lay.wall_fences.append(entry)
			return entry
	return {}


## The stretches where the floor isn't calm around a wall fence (its introduction): something on the
## floor in any lane (a hole, a fence, a floor cut, a pad, a speed pad, a ramp, a zone doodad) or an
## enemy about (what the fill pass keeps for it) within its drop window. Vector2 stretches of its `at`.
static func _calm_keep_outs(gen: LevelGenerator, t: WallFenceTuning) -> Array[Vector2]:
	var lay: LevelLayout = gen.layout
	var tuning: MovementTuning = gen.tuning
	var before: float = t.drop_before_seconds * gen.speed
	var after: float = t.drop_after_seconds * gen.speed
	var busy: Array[Vector2] = []
	for g: Dictionary in lay.gaps:
		busy.append(Vector2(float(g["start"]), float(g["end"])))
	for f: Dictionary in lay.fences:
		busy.append(Vector2(float(f["at"]), float(f["at"])))
	for c: Dictionary in lay.cuts:
		busy.append(FloorCutPlan.window(c, gen.speed))
	for p: Dictionary in lay.pads:
		busy.append(Vector2(float(p["at"]), float(p["at"]) + tuning.pad_length))
	for p: Dictionary in lay.speed_pads:
		busy.append(Vector2(float(p["at"]), float(p["at"]) + tuning.speed_pad_length))
	for r: Dictionary in lay.ramps:
		busy.append(Vector2(float(r["at"]), float(r["at"]) + tuning.ramp_length))
	for d: Dictionary in lay.doodads:
		busy.append(Vector2(float(d["start"]), float(d["end"])))
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		busy.append(gen.enemy_keep_out(e, hooks))
	var out: Array[Vector2] = []
	for s: Vector2 in busy:
		if s.y >= s.x:
			out.append(Vector2(s.x - after, s.y + before))
	return out


## Half a window cyborg's window along the track (WindowCyborgTuning.window_length).
static func _window_cyborg_half_length() -> float:
	var wt := EnemyDirector.tuning_for("window_cyborg") as WindowCyborgTuning
	return (wt.window_length if wt != null else 1.5) * 0.5
