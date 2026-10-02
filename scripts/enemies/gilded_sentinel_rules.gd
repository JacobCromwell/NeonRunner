extends RefCounted
## Generator rules for the Gilded Sentinels (GDD §9.11; GildedSentinel). Patterns place them on a wall
## (data/patterns/gilded_sentinel.json: one, one that swings twice, a pair facing each other across the
## street); LevelGenerator runs apply() after the rules of every feature that puts things on the floor or
## the walls before them (RUN_AFTER), and the Resonator's, the Barnacle Turret's and the floor cutter's
## rules run after these (theirs name this feature), so those plan around the Sentinels.
## Each Sentinel's attack, at the level's run speed (GildedSentinelTuning: seconds at that speed, so
## they hold at every zone's pace, GDD §3), is its window (attack_window: from where the runner is when
## its eyes flare to the end of the stretch its swings cut), and where it may stand (problem()):
## - the level: its window after the feature's start and the run-up, its stretch before the end-clear
##   stretch; its niche within one of the track's chunks (TrackBuilder.CHUNK_LENGTH: the Golden skins
##   open the niche in the chunk's wall, GoldenSkin.note_wall_enemies);
## - its wall: no sign, window cyborg, wall vent's screech or wall fence on its wall from approach_seconds
##   before its stretch (a runner entering the wall early to pass below needs the wall from there) to
##   wall_clear_seconds past it (GDD §9.11 with §9.1: never with a sign or a wall fence on the same wall
##   section; the wall fences, placed later, keep off it themselves, WallFencePlacement), and no other
##   Sentinel there; a ramp on its wall only where the wall run it launches (RampLaunch, also its longest
##   with claws and a speed pad's boost) passes the whole stretch above the band, or is over before it,
##   and never one in the outer lane within its stretch;
## - never when the outer lane is the only safe lane: the lane beside it (the escape) holds no hole,
##   fence, floor cut, anti-grav pad, floor enemy or hover truck's lane from escape_lead_seconds before
##   its first swing to the end of its stretch; and no hover truck holds the outer lane it cuts over its
##   window (the truck's route past it; HoverTruckRules clears that lane of floor enemies);
## - what runs meanwhile: no floor cut's window (B4: nothing else goes on during a cut) and no Octodog
##   run (its charges are planned on a clear floor, BIG_ATTACKS) reaches its window, and no ceiling's
##   landing zone either (a rider dropping into the cut); its cut keeps off every anti-grav pad's way, like
##   any floor enemy's stretch (CeilingZones.enemy_clear). Its attack is a big one that can't wait (GDD §9):
##   at run time, if another type's big attack is on as its warning would start, it lets the runner pass
##   (GildedSentinel), so drone waves and hover trucks, which stay a while and attack now and then, may be
##   about. Its introduction (the level's first) keeps off every big attack's keep-out and Bad Dream
##   chase too (strict), so the player's first meeting always comes;
## - other Sentinels: windows gap_seconds apart, unless they are a pair (the same spot on both walls,
##   swinging together: a pattern's pair).
## A Sentinel that doesn't fit where its pattern put it tries a few spots around it (MOVE_OFFSETS), one
## that swings twice then tries swinging once, and one that still doesn't fit is left out (taking things
## out never makes a level unfair). The level's first Sentinel (its introduction, GDD §6: one new thing at
## a time) swings once, alone: the partner of a first pair is left out; it looks up to INTRO_REACH further
## on for a calm spot (strict, above) before it settles for a fair one.
## Each Sentinel's params get "swings" and "floor_span" (the outer lane its cut uses, which a ceiling's
## landing zone and pads, the Resonator's waves and everything that asks the floor keep off). keep_out()
## and doodad_keep_outs() keep the fill pass, floor cuts, zone doodads and wall fences off its window.

const TYPE: String = "gilded_sentinel"
const RUN_AFTER: Array[String] = ["cyborg", "window_cyborg", "hover_truck", "octodog", "generator", "drone", "host",
	"screech", "screech_vents", "tithe_collector"]
## Enemy types whose big attacks (their keep_out, LevelGenerator.enemy_keep_out) every Sentinel's window
## keeps off: the Octodog's planned charges and a floor cut's cause. The introduction keeps off
## STRICT_ATTACKS too. (Resonators plan their pulses after the Sentinels, off their floor_span, and wait
## for them at run time.)
const BIG_ATTACKS: PackedStringArray = ["octodog", "floor_cutter", "buzz_overdrive"]
const STRICT_ATTACKS: PackedStringArray = ["drone", "hover_truck"]
## Where a Sentinel that doesn't fit at its pattern's spot tries instead, in order: metres at
## MovementTuning.REFERENCE_SPEED, stretched by the level's pace.
const MOVE_OFFSETS: Array[float] = [6.0, -6.0, 12.0, -12.0, 20.0, -20.0, 32.0, -32.0]
## The introduction, where its pattern's spot isn't calm, looks this far further on (metres at the
## reference speed, stretched by the pace, in INTRO_STEP steps) for a calm one before it settles for a
## spot where it may have to let the runner pass.
const INTRO_REACH: float = 190.0
const INTRO_STEP: float = 10.0
## Two Sentinels this close along the track on opposite walls are a pair.
const PAIR_TOLERANCE: float = 0.5
## A niche stays this far inside its chunk's ends (and its frame with it).
const CHUNK_MARGIN: float = 0.3
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"

## Why the last apply() left each group out (its first spot's problem), for measuring and tests.
static var dropped_why: PackedStringArray = []


static func apply(gen: LevelGenerator) -> void:
	var t: GildedSentinelTuning = tuning()
	var layout: LevelLayout = gen.layout
	var groups: Array[Array] = groups_in(layout)
	var placed: Array[Dictionary] = []
	var dropped: Array[Dictionary] = []
	dropped_why.clear()
	for group: Array in groups:
		var lead: Dictionary = group[0]
		var swings: int = clampi(int((lead.get("params", {}) as Dictionary).get("swings", 1)), 1, 2)
		var members: Array[Dictionary] = []
		members.assign(group)
		if placed.is_empty():
			# The introduction: one Sentinel, swinging once.
			swings = 1
			for i: int in range(1, members.size()):
				dropped.append(members[i])
			var alone: Array[Dictionary] = [members[0]]
			members = alone
		var strict: bool = placed.is_empty()
		var spot: float = _fit(gen, t, members, swings, placed, strict)
		if is_nan(spot) and swings == 2:
			swings = 1
			spot = _fit(gen, t, members, swings, placed, strict)
		if is_nan(spot) and strict:
			# No calm spot for the introduction: the first fair one, where it may let the runner pass.
			spot = _fit(gen, t, members, swings, placed, false)
		if is_nan(spot):
			dropped.append_array(members)
			dropped_why.append("%.0f: %s" % [float(lead["at"]), problem(gen, int(lead["side"]), in_chunk(t, float(lead["at"])),
				swings, layout, placed, members, strict)])
			continue
		for e: Dictionary in members:
			e["at"] = spot
			var params: Dictionary = e.get("params", {})
			params["swings"] = swings
			params["floor_span"] = t.floor_use(spot, swings, gen.speed)
			e["params"] = params
			placed.append(e)
	for e: Dictionary in dropped:
		layout.enemies.erase(e)
	_introduce(gen, t, placed)


## A level that brings the Sentinels in (LevelConfig.feature_starts: Golden 2) introduces them right
## after their first-encounter hint: when no Sentinel is left within INTRO_REACH of the feature's start
## (rules that ran before took it out: a hover truck clears its wall and lane, a drone's pads their
## stretch), one is added at the first spot from there where it fits, swinging once, calm (strict)
## where it can be, on either wall.
static func _introduce(gen: LevelGenerator, t: GildedSentinelTuning, placed: Array[Dictionary]) -> void:
	if not gen.config.feature_starts.has(TYPE):
		return
	var start: float = gen.feature_start(TYPE)
	var reach: float = start + gen.metres(INTRO_REACH)
	for e: Dictionary in placed:
		if t.warn_at(float(e["at"]), int((e["params"] as Dictionary).get("swings", 1)), gen.speed) <= reach:
			return
	var rng: RandomNumberGenerator = gen.rng_for("gilded_sentinel_intro")
	var first_side: int = -1 if rng.randf() < 0.5 else 1
	var lead: float = (t.warning_seconds + t.strike_lead_seconds) * gen.speed + t.section_length * 0.5
	for strict: bool in [true, false]:
		var at: float = maxf(start, gen.config.start_clear_distance) + lead
		while t.warn_at(at, 1, gen.speed) <= reach:
			var spot: float = in_chunk(t, at)
			for side: int in [first_side, -first_side]:
				var none: Array[Dictionary] = []
				if problem(gen, side, spot, 1, gen.layout, placed, none, strict) == "":
					var params: Dictionary = {"swings": 1, "floor_span": t.floor_use(spot, 1, gen.speed)}
					gen.add_enemy(TYPE, spot, gen.layout.outer_lane(side), side, params)
					return
			at += gen.metres(INTRO_STEP) * 0.5


static func tuning() -> GildedSentinelTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as GildedSentinelTuning if res is GildedSentinelTuning else GildedSentinelTuning.new()


## The level's Sentinels in groups along the track: a pair (two at the same spot on opposite walls, a
## pattern's pair) together, any other alone.
static func groups_in(layout: LevelLayout) -> Array[Array]:
	var all: Array[Dictionary] = sentinels_in(layout)
	var out: Array[Array] = []
	var used: Dictionary = {}
	for i: int in all.size():
		if used.has(i):
			continue
		var group: Array = [all[i]]
		for j: int in range(i + 1, all.size()):
			if not used.has(j) and group.size() < 2 and absf(float(all[j]["at"]) - float(all[i]["at"])) <= PAIR_TOLERANCE \
					and int(all[j]["side"]) == -int(all[i]["side"]):
				group.append(all[j])
				used[j] = true
		out.append(group)
	return out


## Every Sentinel in the layout, along the track.
static func sentinels_in(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE:
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## The first spot (its pattern's, then MOVE_OFFSETS around it, each moved to keep its niche in one
## chunk) where every member of a group fits with `swings`, beside the Sentinels already `placed`; NAN if
## none.
static func _fit(gen: LevelGenerator, t: GildedSentinelTuning, members: Array[Dictionary], swings: int,
		placed: Array[Dictionary], strict: bool) -> float:
	var base: float = float(members[0]["at"])
	var offsets: Array[float] = [0.0]
	offsets.append_array(MOVE_OFFSETS)
	if strict:
		var step: float = INTRO_STEP
		while step <= INTRO_REACH:
			if not offsets.has(step):
				offsets.append(step)
			step += INTRO_STEP
	for offset: float in offsets:
		var at: float = in_chunk(t, base + gen.metres(offset))
		var ok: bool = true
		for e: Dictionary in members:
			if problem(gen, int(e["side"]), at, swings, gen.layout, placed, members, strict) != "":
				ok = false
				break
		if ok:
			return at
	return NAN


## `at` moved (as little as it takes) so a niche there lies within one of the track's chunks.
static func in_chunk(t: GildedSentinelTuning, at: float) -> float:
	var half: float = t.niche_width * 0.5 + CHUNK_MARGIN
	var chunk: float = TrackBuilder.CHUNK_LENGTH
	var lo: float = floorf(at / chunk) * chunk
	if at - half < lo:
		return lo + half
	if at + half > lo + chunk:
		return lo + chunk - half
	return at


## Why a Sentinel on wall `side` at `at` swinging `swings` times can't stand there in `lay`, at the
## generator's run speed, beside the Sentinels in `others` (the group it belongs to, `group`, counts as a
## pair); "" if it can. `strict`: the level's first, which keeps off every big attack. See the header.
static func problem(gen: LevelGenerator, side: int, at: float, swings: int, lay: LevelLayout,
		others: Array[Dictionary] = [], group: Array[Dictionary] = [], strict: bool = false) -> String:
	var t: GildedSentinelTuning = tuning()
	var v: float = gen.speed
	var guard: Vector2 = t.guarded_stretch(at, swings)
	var window: Vector2 = t.attack_window(at, swings, v)
	var use: Vector2 = t.floor_use(at, swings, v)
	var tuning: MovementTuning = gen.tuning
	if side != -1 and side != 1:
		return "side %d is no wall" % side
	# The level.
	if window.x < gen.config.start_clear_distance or not gen.feature_started(TYPE, window.x):
		return "its warning would come in the run-up or before the feature's start"
	if guard.y > lay.length - gen.config.end_clear_distance:
		return "its swing would come in the end-clear stretch"
	if not is_equal_approx(in_chunk(t, at), at):
		return "its niche would cross a chunk's end"
	# Its wall.
	var wall := Vector2(guard.x - t.approach_seconds * v, guard.y + t.wall_clear_seconds * v)
	for s: Dictionary in lay.signs:
		if int(s["side"]) == side and float(s["start"]) <= wall.y and float(s["end"]) >= wall.x:
			return "a sign is on its wall section"
	var fence_half: float = tuning.fence_depth * 0.5
	for w: Dictionary in lay.wall_fences:
		if int(w["side"]) == side and float(w["at"]) + fence_half >= wall.x and float(w["at"]) - fence_half <= wall.y:
			return "a wall fence is on its wall section"
	var window_half: float = _window_cyborg_half_length()
	for e: Dictionary in lay.enemies:
		if int(e.get("side", 0)) != side:
			continue
		var e_at: float = float(e["at"])
		match String(e.get("type", "")):
			"window_cyborg":
				if e_at + window_half >= wall.x and e_at - window_half <= wall.y:
					return "a window cyborg is on its wall section"
			"screech":
				if String((e.get("params", {}) as Dictionary).get("source", "vent")) == "vent" and e_at >= wall.x and e_at <= wall.y:
					return "a wall vent's screech is on its wall section"
	for o: Dictionary in others:
		if group.has(o) or not lay.enemies.has(o):
			continue
		var o_swings: int = int((o.get("params", {}) as Dictionary).get("swings", 1))
		var o_guard: Vector2 = t.guarded_stretch(float(o["at"]), o_swings)
		if int(o["side"]) == side and o_guard.x - t.approach_seconds * v <= guard.y + t.wall_clear_seconds * v \
				and o_guard.y + t.wall_clear_seconds * v >= wall.x:
			return "another Sentinel is on its wall section"
		var o_window: Vector2 = t.attack_window(float(o["at"]), o_swings, v)
		var pair: bool = absf(float(o["at"]) - at) <= PAIR_TOLERANCE and int(o["side"]) == -side
		if not pair and o_window.x <= window.y + t.gap_seconds * v and o_window.y + t.gap_seconds * v >= window.x:
			return "another Sentinel attacks meanwhile"
	var ramp_problem: String = _ramp_problem(gen, t, side, guard, lay)
	if ramp_problem != "":
		return ramp_problem
	# The escape: the lane beside the outer one.
	var outer: int = lay.outer_lane(side)
	var escape: int = outer - side
	if escape < 0 or escape >= lay.lane_count:
		return "there is no lane beside the outer one"
	var lane_problem: String = _lane_busy(gen, lay, escape, use)
	if lane_problem != "":
		return "the lane beside the cut isn't clear: " + lane_problem
	# The outer lane it cuts: a hover truck holds it while it's about (and clears it of floor enemies,
	# HoverTruckRules: its lane is the player's route past it).
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if k.has("lane") and int(k["lane"]) == outer and float(k["from"]) <= window.y and float(k["to"]) >= window.x:
			return "a hover truck keeps the outer lane meanwhile"
	# What runs meanwhile.
	for c: Dictionary in lay.cuts:
		var cw: Vector2 = FloorCutPlan.window(c, v)
		if cw.x <= window.y and cw.y >= window.x:
			return "a floor cut runs meanwhile"
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		var type: String = String(e.get("type", ""))
		if BIG_ATTACKS.has(type) or (strict and STRICT_ATTACKS.has(type)):
			var k: Vector2 = gen.enemy_keep_out(e, hooks)
			if k.x <= window.y and k.y >= window.x:
				return "a big attack runs meanwhile (%s at %.0f)" % [type, float(e["at"])]
	if strict:
		for k: Dictionary in gen.rules_doodad_keep_outs():
			# The Sentinels' own (doodad_keep_outs) are the other Sentinels' business, above.
			if not k.has("lane") and String(k.get("type", "")) != TYPE and float(k["from"]) <= window.y \
					and float(k["to"]) >= window.x:
				return "a Bad Dream's chase (or another attack in every lane) runs meanwhile"
	for h: Dictionary in lay.hulls:
		var landing: Vector2 = gen.zones.landing_zone(h)
		if landing.x <= window.y and landing.y >= window.x:
			return "a ceiling's landing zone lies in its window"
	# Its cut keeps off every pad's way, like any floor enemy (CeilingZones.enemy_clear: a pad in its lane,
	# or the spot where one lies, from any lane).
	var candidate := {"type": TYPE, "at": at, "lane": outer, "side": side, "params": {"floor_span": use}}
	if not gen.zones.enemy_clear(lay, candidate):
		return "its cut would be in an anti-grav pad's way"
	if lay.doodad_between(window.x, window.y):
		return "a zone doodad stands in its window"
	return ""


## Why `lane` isn't clear over `span` in `lay` (a hole, a fence, a floor cut's lane window, an anti-grav
## pad, a floor enemy, a hover truck's lane or another lane-bound attack the rules keep); "" if it is.
static func _lane_busy(gen: LevelGenerator, lay: LevelLayout, lane: int, span: Vector2) -> String:
	var half: float = gen.tuning.fence_depth * 0.5
	for g: Dictionary in lay.gaps:
		if int(g["lane"]) == lane and float(g["start"]) <= span.y and float(g["end"]) >= span.x:
			return "a hole"
	for f: Dictionary in lay.fences:
		if int(f["lane"]) == lane and float(f["at"]) + half >= span.x and float(f["at"]) - half <= span.y:
			return "a fence"
	for c: Dictionary in lay.cuts:
		var lw: Vector2 = FloorCutPlan.lane_window(c)
		if int(c["lane"]) == lane and lw.x <= span.y and lw.y >= span.x:
			return "a floor cut"
	for p: Dictionary in lay.pads:
		if int(p["lane"]) == lane and float(p["at"]) + gen.tuning.pad_length >= span.x and float(p["at"]) <= span.y:
			return "an anti-grav pad"
	for e: Dictionary in lay.enemies:
		if int(e.get("side", 0)) == 0 and int(e.get("lane", -1)) == lane:
			var s: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
			if s.y >= s.x and s.x <= span.y and s.y >= span.x:
				return "a floor enemy (%s)" % e.get("type", "")
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if k.has("lane") and int(k["lane"]) == lane and float(k["from"]) <= span.y and float(k["to"]) >= span.x:
			return "a lane-bound attack (a hover truck's lane)"
	return ""


## Why a ramp on wall `side` of `lay` makes the stretch `guard` unfair (GDD §3: a ramp launches the
## runner high onto the wall; they slide down from there): one in the outer lane within the stretch (it
## would launch a runner through the cut), or one whose wall run (RampLaunch, and its longest, with claws
## and a speed pad's boost carried onto it) reaches the stretch with the runner's body not wholly above
## the band all through it. "" if none does.
static func _ramp_problem(gen: LevelGenerator, t: GildedSentinelTuning, side: int, guard: Vector2, lay: LevelLayout) -> String:
	var band: Vector2 = t.band(gen.tuning)
	var claws: float = 1.0
	var pt := load(POWERUPS_PATH) as PowerupTuning if ResourceLoader.exists(POWERUPS_PATH) else null
	if pt != null:
		claws = maxf(pt.claws_wall_time_multiplier, 1.0)
	for r: Dictionary in lay.ramps:
		if int(r["side"]) != side:
			continue
		var r_at: float = float(r["at"])
		if r_at > guard.y:
			continue
		if r_at + gen.tuning.ramp_length >= guard.x - t.strike_lead_seconds * gen.speed:
			return "a ramp stands in the outer lane by its stretch"
		for run: RampLaunch in [gen.ramp_launch(r), RampLaunch.of(r, gen.tuning, gen.speed, gen.tuning.speed_pad_boost, claws)]:
			if run.end() < guard.x:
				continue
			# The runner slides down all along: their body's lowest point over the stretch is at its end.
			var low: float = run.body_at(run.time_at(minf(guard.y, run.end()))).x
			if low <= band.y + 0.05:
				return "a ramp's wall run reaches its band (ramp at %.0f)" % r_at
	return ""


## Half a window cyborg's window along the track (WindowCyborgTuning.window_length).
static func _window_cyborg_half_length() -> float:
	var wt := EnemyDirector.tuning_for("window_cyborg") as WindowCyborgTuning
	return (wt.window_length if wt != null else 1.5) * 0.5


## What the fill pass, floor cuts and the wall fences (LevelGenerator.enemy_keep_out) keep off around
## Sentinel entry `e`: its window, from its eyes' flare to the end of its last swing's stretch.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	var swings: int = int((e.get("params", {}) as Dictionary).get("swings", 1))
	return tuning().attack_window(float(e["at"]), swings, gen.speed)


## Zone doodads keep off every Sentinel's window, in every lane (a push into or beside its cut); so do
## floor cuts and the wall fences' drop windows (LevelGenerator.rules_doodad_keep_outs: an attack in
## every lane). Each is marked with its "type".
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in sentinels_in(gen.layout):
		var k: Vector2 = keep_out(gen, e)
		out.append({"from": k.x, "to": k.y, "type": TYPE})
	return out


## Every Sentinel in `layout` that breaks a rule above, as a line of text (the tests' check), at the
## level's own run speed, with the other Sentinels as they stand; plus a planned "swings" and
## "floor_span" on each.
static func problems(layout: LevelLayout, config: LevelConfig, base: MovementTuning) -> PackedStringArray:
	var out := PackedStringArray()
	var movement: MovementTuning = config.movement_for(base)
	var gen: LevelGenerator = LevelGenerator.for_layout(config, movement, layout)
	var all: Array[Dictionary] = sentinels_in(layout)
	var t: GildedSentinelTuning = tuning()
	for e: Dictionary in all:
		var params: Dictionary = e.get("params", {})
		var tag: String = "Sentinel on side %d at %.1f" % [int(e["side"]), float(e["at"])]
		if not params.has("swings") or not (params.get("floor_span") is Vector2):
			out.append("%s has no swings or floor span planned" % tag)
			continue
		var swings: int = int(params["swings"])
		if swings < 1 or swings > 2:
			out.append("%s swings %d times" % [tag, swings])
		var group: Array[Dictionary] = [e]
		for o: Dictionary in all:
			if o != e and absf(float(o["at"]) - float(e["at"])) <= PAIR_TOLERANCE and int(o["side"]) == -int(e["side"]):
				group.append(o)
		var why: String = problem(gen, int(e["side"]), float(e["at"]), swings, layout, all, group)
		if why != "":
			out.append("%s: %s" % [tag, why])
		var span: Vector2 = params["floor_span"]
		var want: Vector2 = t.floor_use(float(e["at"]), swings, movement.run_speed)
		if not span.is_equal_approx(want):
			out.append("%s: its floor span %s isn't its cut's %s" % [tag, span, want])
	if not all.is_empty():
		var first: Dictionary = all[0]
		var firsts: int = 0
		for e: Dictionary in all:
			firsts += 1 if absf(float(e["at"]) - float(first["at"])) <= PAIR_TOLERANCE else 0
		if firsts > 1 or int((first.get("params", {}) as Dictionary).get("swings", 1)) != 1:
			out.append("the level's first Sentinel isn't alone, swinging once (its introduction)")
	return out
