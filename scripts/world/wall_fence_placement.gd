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
##   jump, into the outer lane on its side, so that lane holds no hole, fence, floor cut, anti-grav pad
##   or floor enemy from drop_before_seconds before it to drop_after_seconds after it (its drop window:
##   where a drop-off from as late as its warning lands), and no hover truck keeps that lane meanwhile
##   (a ramp there launches along its wall, which the ramp rule keeps clear anyway);
## - what runs meanwhile: no floor cut's window (B4: nothing else goes on during a cut), no big attack
##   (an enemy keep-out of the drone's, the hover truck's, the Octodog's or a floor cut's cause; each of
##   a Resonator's pulses, from its warning until its wave has passed the player) and no Bad Dream chase
##   reaches its drop window (the wall is one of their escapes; one big thing at a time);
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
##   full-height ones, Corporate 1's partial ones) is the first of its kind, within intro_seconds of the
##   start: at the earliest fair spot on either wall where no enemy is about (calm), where one comes in
##   time, else the earliest fair one (only if none comes in time, the first fair one past it); alone,
##   with no other wall fence on either wall within same_side_gap_seconds; with a long off time
##   (intro_off_seconds). So the player meets it gently, right after its first-encounter hint.
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
## a wall fence's drop window keeps off them. (A floor cut's own window is kept too, whatever its cause:
## the floor cutter stand-in, task C2's Buzz Overdrive.)
const BIG_ATTACKS: PackedStringArray = ["drone", "hover_truck", "octodog", "resonator", "floor_cutter", "buzz_overdrive"]
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
	# Where each kind may come from (its feature's start, or its introduction), and the introductions,
	# which stand alone: nothing else on either wall within same_side_gap_seconds of one.
	var full_from: float = maxf(gen.feature_start(FEATURE), gen.config.start_clear_distance)
	var partial_from: float = maxf(gen.feature_start(PARTIAL), full_from if full_on else gen.config.start_clear_distance)
	var alone: Array[Vector2] = []
	if full_on and gen.config.feature_starts.has(FEATURE):
		var intro: Dictionary = _introduce(gen, t, rng, keeps, "full", gen.feature_start(FEATURE))
		if not intro.is_empty():
			full_from = float(intro["at"])
			alone.append(_alone(gen, t, intro))
	if partial_on and gen.config.feature_starts.has(PARTIAL):
		var intro: Dictionary = _introduce(gen, t, rng, keeps, _partial_band(rng), gen.feature_start(PARTIAL), alone)
		if not intro.is_empty():
			partial_from = float(intro["at"])
			alone.append(_alone(gen, t, intro))
	# The rest, about a spacing apart.
	var cursor: float = full_from if full_on else partial_from
	while true:
		var difficulty: float = gen.difficulty_at(clampf(cursor / lay.length, 0.0, 1.0))
		var spacing: float = WallFenceTuning.by_difficulty(t.spacing_seconds_easy, t.spacing_seconds_hard, difficulty)
		cursor += spacing * (1.0 + rng.randf_range(-t.spacing_jitter, t.spacing_jitter)) * gen.speed
		if cursor > last:
			break
		var band: String = "full"
		if partial_on and cursor > partial_from and (not full_on or rng.randf() < t.partial_share):
			band = _partial_band(rng)
		elif not full_on:
			continue
		var side: int = -1 if rng.randf() < 0.5 else 1
		var entry: Dictionary = _fit(gen, t, rng, keeps, band, [side, -side], cursor,
			cursor + t.search_seconds * gen.speed, false, alone)
		if not entry.is_empty():
			cursor = float(entry["at"])
	# Every feature appears (GDD §5).
	if full_on and _count(lay, false) == 0:
		_guarantee(gen, t, rng, keeps, "full", alone)
	if partial_on and _count(lay, true) == 0:
		_guarantee(gen, t, rng, keeps, _partial_band(rng), alone)
	lay.wall_fences.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))


## The stretch around introduction `intro` where no other wall fence stands, on either wall.
static func _alone(gen: LevelGenerator, t: WallFenceTuning, intro: Dictionary) -> Vector2:
	var gap: float = t.same_side_gap_seconds * gen.speed
	return Vector2(float(intro["at"]) - gap + EPSILON, float(intro["at"]) + gap - EPSILON)


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
	# An anti-grav pad would flip a player dropping onto it up onto a ceiling. (A ramp there launches
	# along its wall, which its own rule keeps clear; a speed pad only speeds them up.)
	for p: Dictionary in lay.pads:
		if int(p["lane"]) == lane:
			drop.append(Vector2(float(p["at"]), float(p["at"]) + tuning.pad_length))
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
		var pulses: Array[Vector2] = resonator_pulses(gen, e)
		if not pulses.is_empty():
			busy.append_array(pulses)
		elif BIG_ATTACKS.has(String(e.get("type", ""))):
			busy.append(gen.enemy_keep_out(e, hooks))
	for k: Dictionary in attacks:
		if not k.has("lane"):
			busy.append(Vector2(float(k["from"]), float(k["to"])))
	for s: Vector2 in busy:
		if s.y >= s.x:
			out.append({"from": s.x - after, "to": s.y + before, "why": "a floor cut or a big attack runs meanwhile"})
	return out


## A Resonator's planned pulses (GDD §9.10; resonator_rules.gd plans them, "pulse_at" and "double"):
## for each, the stretch from where its warning starts to where its wave has passed the player
## (ResonatorTuning.meeting_stretch), when the wall is one of the escapes from it. Between its pulses
## nothing asks for the wall. [] for any other entry, or a Resonator without a plan (its whole keep-out
## then counts, as a big attack's).
static func resonator_pulses(gen: LevelGenerator, e: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if String(e.get("type", "")) != "resonator":
		return out
	var rt := EnemyDirector.tuning_for("resonator") as ResonatorTuning
	var params: Dictionary = e.get("params", {})
	var anchors: Array = params.get("pulse_at", [])
	var doubles: Array = params.get("double", [])
	if rt == null:
		return out
	for i: int in anchors.size():
		var double: bool = i < doubles.size() and bool(doubles[i])
		var meeting: Vector2 = rt.meeting_stretch(float(anchors[i]), double, gen.speed, gen.config.enemy_scaling, gen.pace)
		out.append(Vector2(float(anchors[i]), meeting.y))
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


## The introduction of a wall fence of `band` (see the header): the earliest fair spot on either wall
## within intro_seconds of `start` where no enemy is about (calm), else the earliest fair one there, else
## (late) the first fair one past it; either way the first of its kind, with the long off time, and off
## the stretches `alone` keeps clear (another introduction's). Returns its entry, or {} if there's no fair
## spot past `start` at all.
static func _introduce(gen: LevelGenerator, t: WallFenceTuning, rng: RandomNumberGenerator, keeps: Array,
		band: String, start: float, alone: Array[Vector2] = []) -> Dictionary:
	var by: float = start + t.intro_seconds * gen.speed
	var side: int = -1 if rng.randf() < 0.5 else 1
	var calm: Array[Vector2] = _calm_keep_outs(gen, t)
	calm.append_array(alone)
	var entry: Dictionary = _fit(gen, t, rng, keeps, band, [side, -side], start, by, true, calm, true)
	if entry.is_empty():
		entry = _fit(gen, t, rng, keeps, band, [side, -side], start, by, true, alone, true)
	if entry.is_empty():
		entry = _fit(gen, t, rng, keeps, band, [side, -side], start, gen.layout.length, true, alone, true)
	return entry


## A level left without a wall fence of `band`'s kind gets one at the first fair spot past its start (off
## the stretches `alone` keeps clear), or a warning if there's none at all.
static func _guarantee(gen: LevelGenerator, t: WallFenceTuning, rng: RandomNumberGenerator, keeps: Array,
		band: String, alone: Array[Vector2]) -> void:
	var side: int = -1 if rng.randf() < 0.5 else 1
	var entry: Dictionary = _fit(gen, t, rng, keeps, band, [side, -side], 0.0, gen.layout.length, false, alone)
	if entry.is_empty():
		gen.warnings.append("wall fences: no fair spot anywhere for a %s one (every feature should appear, GDD §5)" % band)


## Adds a wall fence of `band` at the first fair spot in [lo, hi] (and past its feature's start): on the
## first of `sides` that has one there, or with `earliest` on whichever has the earliest (the first of
## `sides` on a tie). Its pulse times come from the difficulty there (an introduction's off time at least
## intro_off_seconds), its phase at random. `extra` (stretches) keeps it off more. Returns its entry, or {}
## (adding nothing) if no spot fits.
static func _fit(gen: LevelGenerator, t: WallFenceTuning, rng: RandomNumberGenerator, keeps: Array, band: String,
		sides: Array, lo: float, hi: float, intro: bool, extra: Array[Vector2] = [], earliest: bool = false) -> Dictionary:
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
	var best: float = INF
	var best_side: int = 0
	for side: Variant in sides:
		var s: int = int(side)
		var blocked: Array = (keeps[0 if s < 0 else 1] as Array).duplicate()
		blocked.append_array(extra)
		for w: Dictionary in lay.wall_fences:
			var gap: float = (t.same_side_gap_seconds if int(w["side"]) == s else t.gap_seconds) * gen.speed
			blocked.append(Vector2(float(w["at"]) - gap + EPSILON, float(w["at"]) + gap - EPSILON))
		var at: float = first_free(merged(blocked), from, hi)
		if at < best:
			best = at
			best_side = s
			if not earliest:
				break
	if best == INF:
		return {}
	var entry: Dictionary = WallFencePlan.make(best_side, best, band, on, off, phase)
	lay.wall_fences.append(entry)
	return entry


## The stretches where it isn't calm around a wall fence (its introduction): an enemy about (what the
## fill pass keeps for it, LevelGenerator.enemy_keep_out) within its drop window. Vector2 stretches of
## its `at`.
static func _calm_keep_outs(gen: LevelGenerator, t: WallFenceTuning) -> Array[Vector2]:
	var before: float = t.drop_before_seconds * gen.speed
	var after: float = t.drop_after_seconds * gen.speed
	var out: Array[Vector2] = []
	var hooks: Dictionary = {}
	for e: Dictionary in gen.layout.enemies:
		var s: Vector2 = gen.enemy_keep_out(e, hooks)
		if s.y >= s.x:
			out.append(Vector2(s.x - after, s.y + before))
	return out


## Half a window cyborg's window along the track (WindowCyborgTuning.window_length).
static func _window_cyborg_half_length() -> float:
	var wt := EnemyDirector.tuning_for("window_cyborg") as WindowCyborgTuning
	return (wt.window_length if wt != null else 1.5) * 0.5
