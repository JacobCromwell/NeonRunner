extends RefCounted
## Generator rules for the Octodog jars that break open (task Q5; GDD §5, Zone 9, the owner, October 21, 2026: "some jars
## hold a curled-up Octodog instead of a brain. Sometimes smashing an Octodog jar doodad releases its Octodog into the
## world, and the runner has to fight it"; proposed: a jar is smashed the way every doodad is, by the dash, and one that
## will release its Octodog looks the same as one that won't; the freed Octodog tumbles out, runs ahead to its usual
## distance and starts its usual attack (§9.4) from the first wind-up, with its cue, never a lunge without warning; it is
## fought and killed like any Octodog). No patterns: like the falling gantryways and the teleporters, a set piece its
## rules stand where it's fair. Each is two entries:
## - a zone doodad (LevelLayout.doodads) of the small class (JAR_SIZE) in an inner lane L, its front at J, pushing into
##   the lane on its `side` like any doodad, marked LevelLayout.HOLDS "octodog": the skin dresses it as the zone's jar
##   with an Octodog curled up in it (ZoneSkin.held_doodad_look; the Ice Lab's IceLabDoodads.OCTODOG_JAR), the look the
##   zone's other Octodog jars have;
## - the Octodog it holds: an ordinary `octodog` entry of LevelLayout.enemies at J in L, its params marked
##   LevelLayout.HELD, with no doghouse, and its charges planned from the release (`charges`, `charge_at`, `floor_span`)
##   as octodog_rules.gd plans a standing dog's. It stays in its jar (Octodog: hidden, harmless, untouchable) until the
##   jar is smashed; a runner who passes the jar (pushed aside, as by any doodad) never meets it.
##
## Where (at the level's run speed; every margin in metres written for MovementTuning.REFERENCE_SPEED and stretched by the
## level's pace, LevelGenerator.metres):
## - The jar keeps every rule a zone doodad keeps (LevelGenerator.doodad_fits: its own lane and the lanes beside it clear
##   around it, what every lane keeps never reaching it, no other doodad too near), in an inner lane: never by a side wall,
##   so only the dash breaks it (a wall runner low on a wall breaks a doodad by it, task L3) and a dog that comes out has
##   a lane on either side. DESIGN-TBD (docs/questions/q5.md 2).
## - Its dog's first wind-up is planned release_distance past the jar's front (OctodogTuning: the tumble, the sprint to its
##   usual distance ahead and jar_settle_seconds, and how far the dash that smashed the jar can carry the runner on
##   meanwhile), each later one as a standing dog's (a cycle on, or up to charge_slack later where its stretch is clear),
##   at least MIN_CHARGES (GDD §9.4: 2-3 early, up to 4) and up to the count it rolls (charges_range at the level's enemy
##   scaling: 3 to 4 in the Ice Lab). Each charge's stretch is clear as a standing dog's must be (Octodog.charge_clear: no
##   fence, doodad, anti-grav pad, ceiling landing or other enemy, holes in one lane at most).
## - Its whole run, from the jar's push lead to past its last charge (its floor_span), keeps off every anti-grav pad's zone
##   and ceiling landing zone (the dog never winds up at a runner taking a pad or dropping off a ceiling), every Bad
##   Dream's chase and kept extended wall run, everything the rules keep in every lane or in a lane (all counted in every
##   lane: the dog crosses lanes): a falling gantryway from its pillar's lead to past its walkway and calm stretch, a
##   teleporter's way around, pad stretch and landings, a wall-run gap's clear stretch, so no freed dog attacks in a
##   gantryway's step out or a teleporter's approach or landing; and every other Octodog's run (one at a time, as
##   octodog_rules.gd keeps them: a stop distance and DOG_GAP between them, and what a wait for its turn, turn_wait_max,
##   can move a run on).
## - No other enemy's stretch (what the fill pass keeps around it, LevelGenerator.enemy_keep_out, and the floor it uses)
##   reaches the jar's push lead or its dog's run up to its first charge: the release, the tumble and the sprint ahead play
##   out with nothing else attacking (DESIGN-TBD, docs/questions/q5.md 7); its charges then keep off the other enemies as
##   any dog's do (charge_clear).
## - Between the run-up (and the feature's start) and the end-clear stretch.
## Every pass after the rules keeps off the dog's run as off any enemy's (its entry's keep-out reaches back past the jar:
## the fill pass, the danger density pass, the wider gaps, the cyborgs planted in charge paths, the zone doodads), so the
## jar stays as fair as it was placed; problems() re-checks a finished layout (LayoutChecks.check_octodog_jars), and the
## jar's push is checked as any doodad's (LayoutChecks.check_doodads, which leaves its own dog's run out of it).
##
## How many and where: up to LevelConfig.octodog_jars. A level that gives the feature a start (Frost Foundry) has its
## first at the earliest fair spot from there (within jar_intro_window_seconds where one fits there: the gentle, clearly
## visible first one, in the inner lane nearest the middle), the rest spread through the level past it (a part each, the
## fair spot nearest a seeded one in the part), then the earliest fair spot of what's left. Its own random stream
## (LevelGenerator.rng_for), after every other feature's rules (RUN_AFTER: the gantryways and the teleporters keep exactly
## the spots they had), so a level without the feature draws nothing and is built byte for byte as before.
## Which of a zone's Octodog jars release: only these. Its others are its skin's look (IceLabDoodads' variety, commoner
## toward the laboratory) and hold nothing, so "sometimes" is these among them. DESIGN-TBD (docs/questions/q5.md 1).

const FEATURE: String = "octodog_jar"
const TYPE: String = "octodog"
## Every feature whose rules place, move or drop enemies, plan charges or cuts, or add ceilings, pads, ramps or set
## pieces, the falling gantryways and the teleporters included: the jars are planned on the level's final rules track, so
## every rule before them places exactly what it did without them.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel", "enforcer_truck",
	"floor_cutter", "treasure_stash", "fenced_ceiling", "dash_wall", "wall_run_gaps", "debris_maze", "centipede",
	"gantryway", "teleporter", "teleporter_blinking"]
const OctodogRules = preload("res://scripts/enemies/octodog_rules.gd")
const HostRules = preload("res://scripts/enemies/host_rules.gd")
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
## The jar's size class (LevelLayout.DOODAD_SIZES): the small one, whose looks the Ice Lab's Octodog jar is among.
const JAR_SIZE: StringName = &"small"
## A freed dog makes at least this many charges, or its jar holds none there (GDD §9.4: 2-3 early, up to 4).
const MIN_CHARGES: int = 2
## Metres between the jar fronts tried (at the reference speed).
const SEARCH_STEP: float = 2.0
## Metres between two Octodogs' runs beyond the stop distance (at the reference speed), as octodog_rules.gd keeps them.
const DOG_GAP: float = 10.0
## Metres kept clear of a pad's spot before its first wind-up and past where its run ends, as octodog_rules.gd's
## _first_charge_fits and LayoutChecks.check_rules keep them (at the reference speed).
const PAD_BEFORE: float = 6.0
const PAD_AFTER: float = 2.0

## Review aid (tools/measure/octodog_jars.gd): microseconds apply() has taken, summed over every call since it was zeroed.
static var spent_usec: int = 0
## Review aid (tools/measure/octodog_jars.gd --why): with `debug` on, how many jar fronts tried each reason turned down.
static var debug: bool = false
static var why: Dictionary = {}


## Counts reason `what` in `why` (with `debug` on) and returns {} (a spot turned down).
static func _no(what: String) -> Dictionary:
	if debug:
		why[what] = int(why.get(what, 0)) + 1
	return {}


## One level's numbers for its jars, at its run speed (metres), and what the layout holds that they keep off (plan_for,
## refreshed after each jar by refresh()).
class Plan:
	extends RefCounted
	var gen: LevelGenerator
	var t: OctodogTuning
	var scaling: float = 0.0
	## A charge's stretch (OctodogTuning.window_length), the dog's distance ahead at its wind-up (stop_distance), and a
	## cycle from one wind-up to the next (cycle_distance).
	var window: float = 0.0
	var stop: float = 0.0
	var cycle: float = 0.0
	## From the jar's front to its dog's first wind-up (release_distance).
	var release: float = 0.0
	## The jar's push lead and a lane switch's room before its front (LevelGenerator.doodad_lead_for, doodad_lane_room).
	var before: float = 0.0
	var length: float = 1.4
	## A charge's stretch ends before this (the end-clear stretch).
	var last_ok: float = 0.0
	## The room between two dogs' runs beyond the stop distance (DOG_GAP).
	var gap: float = 0.0
	## Where a jar's front may stand: [lo, hi], tried `step` apart.
	var lo: float = 0.0
	var hi: float = -1.0
	var step: float = 2.0
	## Every Bad Dream's chase and kept extended wall run.
	var chases: Array[Vector2] = []
	## What the rules keep (every lane and lane by lane, all counted in every lane), every Octodog's run as far as it
	## keeps a new one off (busy_of: to its stop distance and a wait's room past its end), and the zone doodads' room
	## (refresh()).
	var keeps: Array[Vector2] = []
	var dogs: Array[Vector2] = []
	var room: LevelGenerator.DoodadRoom


## The level's Plan: its numbers at its run speed, and what its layout holds now (refresh()).
static func plan_for(gen: LevelGenerator, t: OctodogTuning, pt: PowerupTuning) -> Plan:
	var p := Plan.new()
	p.gen = gen
	p.t = t
	p.scaling = gen.config.enemy_scaling
	p.window = t.window_length(gen.speed, p.scaling, gen.pace)
	p.stop = t.stop_distance(gen.speed, p.scaling, gen.pace)
	p.cycle = t.cycle_distance(gen.speed, p.scaling, gen.pace)
	p.release = release_distance(gen, t, pt)
	p.before = LevelGenerator.doodad_lead_for(gen.tuning) + gen.doodad_lane_room()
	p.length = gen.tuning.doodad_size(JAR_SIZE).z
	p.last_ok = gen.layout.length - gen.config.end_clear_distance
	p.gap = gen.metres(DOG_GAP)
	p.step = gen.metres(SEARCH_STEP)
	p.lo = maxf(maxf(gen.config.start_clear_distance, gen.config.doodad_start * gen.layout.length),
		gen.feature_start(FEATURE) + p.before) + 0.01
	p.hi = p.last_ok - p.window - p.release
	p.chases = HostRules.chase_stretches(gen)
	p.chases.append_array(gen.extended_wall_run_reserve)
	refresh(p)
	return p


## Metres from a jar's front to its dog's planned first wind-up at `gen`'s level (OctodogTuning.release_distance, with
## how much further the dash that smashed the jar can carry the runner on: PowerupTuning's bonus over the whole dash).
static func release_distance(gen: LevelGenerator, t: OctodogTuning = null, pt: PowerupTuning = null) -> float:
	var tt: OctodogTuning = t if t != null else tuning()
	var p: PowerupTuning = pt if pt != null else powerups()
	return tt.release_distance(gen.speed, gen.config.enemy_scaling, gen.pace, p.dash_speed_bonus * p.dash_duration)


## What `plan`'s layout holds now (after a jar and its dog joined it): the zone doodads' room, what the rules keep, and
## every Octodog's run as far as it keeps a new one off (busy_of).
static func refresh(plan: Plan) -> void:
	var gen: LevelGenerator = plan.gen
	plan.room = gen.doodad_room()
	plan.keeps.clear()
	for k: Dictionary in gen.rules_doodad_keep_outs():
		plan.keeps.append(Vector2(float(k["from"]), float(k["to"])))
	plan.dogs.clear()
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == TYPE:
			var busy: Vector2 = busy_of(gen, e, plan.before, plan.stop)
			if busy.y >= busy.x:
				plan.dogs.append(busy)


## Where Octodog entry `e` is busy, as another dog keeps its own run off it: the floor its charges use
## (LevelGenerator.enemy_floor_span), from its jar's push lead (`before` before its spot) for one held in a jar, which is
## loose from there, to `after` past its end (its stop distance and what a wait for its turn can move it on).
static func busy_of(gen: LevelGenerator, e: Dictionary, before: float, after: float) -> Vector2:
	var run: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
	if run.y < run.x:
		return run
	if LevelLayout.is_held(e):
		run.x = minf(run.x, float(e["at"]) - before)
	return Vector2(run.x, run.y + after)


## The plan of the dog a jar with its front at `j` holds, trying for `wanted` charges and taking no fewer than `least`, in
## `plan`'s level: {anchors, span}, or {} where no fair one fits (see the header). Its later charges are the first that
## fit one after the other; it keeps as many of them as its run takes off everything it keeps clear.
static func dog_at(plan: Plan, j: float, wanted: int, least: int = MIN_CHARGES) -> Dictionary:
	var gen: LevelGenerator = plan.gen
	var lay: LevelLayout = gen.layout
	var a0: float = j + plan.release
	var from: float = j - plan.before
	if a0 + plan.window > plan.last_ok:
		return _no("its dog's first charge reaches the end")
	# Its first wind-up as a standing dog's (octodog_rules.gd, _first_charge_fits): no pad or ceiling landing from a little
	# before it to where the dog stands then, and a clear stretch.
	if Octodog.pad_or_landing_between(lay, a0 - gen.metres(PAD_BEFORE), a0 + plan.stop + gen.metres(PAD_AFTER), gen.pace):
		return _no("a pad or a ceiling landing at its first wind-up")
	if not Octodog.charge_clear(lay, a0, plan.window, gen.pace):
		return _no("its dog's first charge not clear")
	var anchors: Array[float] = [a0]
	var prev: float = a0
	var slack: float = gen.metres(plan.t.charge_slack)
	while anchors.size() < wanted:
		var found: float = -1.0
		var a: float = prev + plan.cycle
		while a <= prev + plan.cycle + slack:
			if a + plan.window > plan.last_ok or Octodog.pad_or_landing_between(lay, prev, a + plan.stop + gen.metres(PAD_AFTER),
					gen.pace):
				break
			if Octodog.charge_clear(lay, a, plan.window, gen.pace):
				found = a
				break
			a += 2.0
		if found < 0.0:
			break
		anchors.append(found)
		prev = found
	var fewest: int = mini(least, wanted)
	if anchors.size() < fewest:
		return _no("too few charges fit")
	var why_not: String = ""
	while anchors.size() >= fewest:
		# The floor its charges use, as a standing dog's (octodog_rules.gd, run_start: from before its first wind-up to
		# past its last), off every pad's zone and ceiling landing.
		var span := Vector2(OctodogRules.run_start(gen, a0), anchors[-1] + plan.window - 0.001)
		# From the jar on, the dog is loose: off every chase and what every rule keeps, and one dog at a time (its run
		# and its stop distance after it apart from every other's).
		if not _off_ceiling_zones(gen, span):
			why_not = "a pad's zone or a ceiling landing in its run"
		elif _hits(plan.chases, from, anchors[-1] + plan.window + plan.stop):
			why_not = "a chase in its run"
		elif _hits(plan.keeps, from, span.y):
			why_not = "what a rule keeps in its run"
		elif _hits(plan.dogs, from - plan.gap, span.y + plan.stop + plan.gap):
			why_not = "another Octodog's run"
		else:
			return {"anchors": anchors, "span": span}
		anchors.pop_back()
	return _no(why_not)


## True if no anti-grav pad's zone or ceiling landing zone (CeilingZones) reaches into `span`, in any lane.
static func _off_ceiling_zones(gen: LevelGenerator, span: Vector2) -> bool:
	for p: Dictionary in gen.layout.pads:
		var zone: Vector2 = gen.zones.pad_zone(float(p["at"]))
		if zone.x <= span.y and zone.y >= span.x:
			return false
	for landing: Vector2 in gen.zones.landing_zones(gen.layout):
		if landing.x <= span.y and landing.y >= span.x:
			return false
	return true


static func tuning() -> OctodogTuning:
	return OctodogRules.tuning()


static func powerups() -> PowerupTuning:
	var res: Resource = load(POWERUPS_PATH) if ResourceLoader.exists(POWERUPS_PATH) else null
	return res as PowerupTuning if res is PowerupTuning else PowerupTuning.new()


## The level's jars (see the header): the introduction first where the level gives the feature a start, then the rest
## spread through the level.
static func apply(gen: LevelGenerator) -> void:
	if not gen.config.has_feature(FEATURE):
		return
	var t0: int = Time.get_ticks_usec()
	_apply(gen, gen.config.octodog_jars if gen.layout.lane_count >= 3 else 0)
	spent_usec += Time.get_ticks_usec() - t0


static func _apply(gen: LevelGenerator, count: int) -> void:
	if count <= 0:
		return
	var t: OctodogTuning = tuning()
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var plan: Plan = plan_for(gen, t, powerups())
	var placed: int = 0
	var from: float = plan.lo
	if gen.config.feature_starts.has(FEATURE):
		# The introduction: the earliest fair spot from the feature's start (within jar_intro_window_seconds where one fits
		# there, the gentle first one), in the inner lane nearest the middle.
		var spot: Dictionary = _search(plan, rng, plan.lo, plan.hi, plan.lo, _roll_charges(gen, t, rng), true)
		if not spot.is_empty():
			spot["intro"] = true
			_place(plan, spot, placed)
			placed += 1
			from = float(spot["front"]) + plan.step
	var left: int = count - placed
	if left > 0 and from <= plan.hi:
		var part: float = (plan.hi - from) / float(left)
		var aims: Array[float] = []
		for k: int in left:
			aims.append(from + (k + rng.randf_range(0.25, 0.75)) * part)
		for k: int in left:
			var a: float = from + k * part
			var spot: Dictionary = _search(plan, rng, a, a + part, aims[k], _roll_charges(gen, t, rng), false)
			if not spot.is_empty():
				_place(plan, spot, placed)
				placed += 1
	# Where a part had no room: the earliest of what's left past the introduction.
	while placed < count:
		var spot: Dictionary = _search(plan, rng, from, plan.hi, from, _roll_charges(gen, t, rng), false)
		if spot.is_empty():
			break
		_place(plan, spot, placed)
		placed += 1
	if placed == 0:
		gen.warnings.append("octodog jars: no fair spot for one in the level (GDD §5: a feature a level has appears in it)")
	gen.layout.doodads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	if debug:
		_profile(plan, _roll_charges(gen, t, rng))


## The fair spot nearest `aim` with its front in [a, b] (its dog making its usual `wanted` charges where they fit, GDD
## §9.4: 2 at the fewest; else as many as fit there, one at least), or {}. With `intro`, the earliest from `a`, within
## jar_intro_window_seconds of it where one fits there, in the inner lane nearest the middle.
static func _search(plan: Plan, rng: RandomNumberGenerator, a: float, b: float, aim: float, wanted: int,
		intro: bool) -> Dictionary:
	var spans: Array[Vector2] = [Vector2(a, b)]
	if intro:
		var window: float = minf(a + plan.t.jar_intro_window_seconds * plan.gen.speed, b)
		spans = [Vector2(a, window), Vector2(a, b)]
	for span: Vector2 in spans:
		for least: int in [MIN_CHARGES, 1]:
			var spot: Dictionary = _earliest(plan, rng, span.x, span.y, wanted, least, -1, true) if intro \
				else _nearest(plan, rng, span.x, span.y, aim, wanted, least, -1, false)
			if not spot.is_empty():
				return spot
	return {}


## Review aid (debug): over every jar front of the level, how many each part of the rules lets through, in `why`.
static func _profile(plan: Plan, wanted: int) -> void:
	var gen: LevelGenerator = plan.gen
	var j: float = plan.lo
	var counts: Dictionary = {"fronts": 0, "jar fits": 0, "first wind-up off pads": 0, "first charge clear": 0,
		"both": 0, "dog fits (2 charges)": 0, "dog fits (1)": 0, "jar and dog (2)": 0, "jar and dog (1)": 0}
	debug = false
	while j <= plan.hi:
		counts["fronts"] += 1
		var jar_ok: bool = false
		for lane: int in range(1, gen.layout.lane_count - 1):
			for side: int in [-1, 1]:
				jar_ok = jar_ok or gen.doodad_fits(plan.room, JAR_SIZE, lane, side, j)
		var a0: float = j + plan.release
		var pads_ok: bool = not Octodog.pad_or_landing_between(gen.layout, a0 - gen.metres(PAD_BEFORE),
			a0 + plan.stop + gen.metres(PAD_AFTER), gen.pace)
		var clear: bool = Octodog.charge_clear(gen.layout, a0, plan.window, gen.pace)
		var two: bool = not dog_at(plan, j, wanted, MIN_CHARGES).is_empty()
		var one: bool = not dog_at(plan, j, wanted, 1).is_empty()
		counts["jar fits"] += 1 if jar_ok else 0
		counts["first wind-up off pads"] += 1 if pads_ok else 0
		counts["first charge clear"] += 1 if clear else 0
		counts["both"] += 1 if pads_ok and clear else 0
		counts["dog fits (2 charges)"] += 1 if two else 0
		counts["dog fits (1)"] += 1 if one else 0
		counts["jar and dog (2)"] += 1 if two and jar_ok else 0
		counts["jar and dog (1)"] += 1 if one and jar_ok else 0
		j += plan.step
	debug = true
	why["profile"] = counts


## The earliest fair spot with its front in [a, b], or {} (_spot_at: no fewer than `least` charges, in the lane nearest
## `prefer`, the middle with `middle`).
static func _earliest(plan: Plan, rng: RandomNumberGenerator, a: float, b: float, wanted: int, least: int, prefer: int,
		middle: bool) -> Dictionary:
	var j: float = maxf(a, plan.lo)
	while j <= minf(b, plan.hi):
		var spot: Dictionary = _spot_at(plan, rng, j, wanted, least, prefer, middle)
		if not spot.is_empty():
			return spot
		j += plan.step
	return {}


## How many charges a freed dog tries for (charges_range at the level's enemy scaling).
static func _roll_charges(gen: LevelGenerator, t: OctodogTuning, rng: RandomNumberGenerator) -> int:
	var r: Vector2i = t.charges_range(gen.config.enemy_scaling)
	return rng.randi_range(r.x, r.y)


## The fair spot with its front in [a, b] nearest `want` (searched outward from it, the earlier side first on a tie), or
## {} (_spot_at: no fewer than `least` charges, in lane `prefer` where the jar fits there, else the inner lane nearest it
## that does; with `middle`, nearest the middle).
static func _nearest(plan: Plan, rng: RandomNumberGenerator, a: float, b: float, want: float, wanted: int, least: int,
		prefer: int, middle: bool) -> Dictionary:
	var lo: float = maxf(a, plan.lo)
	var hi: float = minf(b, plan.hi)
	if hi < lo:
		return {}
	var center: float = clampf(want, lo, hi)
	var reach: int = ceili(maxf(center - lo, hi - center) / plan.step)
	for k: int in reach + 1:
		var tries: Array[float] = [center]
		if k > 0:
			tries = [center - k * plan.step, center + k * plan.step]
		for j: float in tries:
			if j < lo or j > hi:
				continue
			var spot: Dictionary = _spot_at(plan, rng, j, wanted, least, prefer, middle)
			if not spot.is_empty():
				return spot
	return {}


## A jar with its front at `j` and its dog's plan (dog_at: no fewer than `least` charges), if both fit: {front, lane,
## side, anchors, span}, or {}. The lane: the inner one that fits nearest `prefer` (the middle with `middle`; the earlier
## of two as near); its push's side a seeded one where both fit.
static func _spot_at(plan: Plan, rng: RandomNumberGenerator, j: float, wanted: int, least: int, prefer: int,
		middle: bool) -> Dictionary:
	var lanes: int = plan.gen.layout.lane_count
	var fits: Array[Array] = []
	for lane: int in range(1, lanes - 1):
		var sides: Array[int] = []
		for side: int in [-1, 1]:
			if plan.gen.doodad_fits(plan.room, JAR_SIZE, lane, side, j):
				sides.append(side)
		if not sides.is_empty():
			fits.append([lane, sides])
	if fits.is_empty():
		return _no("no lane for the jar")
	var dog: Dictionary = dog_at(plan, j, wanted, least)
	if dog.is_empty():
		return {}
	var aim: float = (lanes - 1) * 0.5 if middle or prefer < 0 else float(prefer)
	var pick: Array = fits[0]
	for f: Array in fits:
		if absf(float(f[0]) - aim) < absf(float(pick[0]) - aim):
			pick = f
	var sides: Array = pick[1]
	return {"front": j, "lane": int(pick[0]), "side": int(sides[rng.randi_range(0, sides.size() - 1)]),
		"anchors": dog["anchors"], "span": dog["span"]}


## Stands jar `spot` (_spot_at) in the layout, the `index`th of the level's jars, with the dog it holds at its front, its
## plan in its params.
static func _place(plan: Plan, spot: Dictionary, index: int) -> void:
	var gen: LevelGenerator = plan.gen
	var j: float = float(spot["front"])
	var lane: int = int(spot["lane"])
	var jar := {"lane": lane, "start": j, "end": j + plan.length, "size": JAR_SIZE, "side": int(spot["side"]),
		"seed": hash([gen.config.level_seed, FEATURE, index]), LevelLayout.HOLDS: TYPE}
	if bool(spot.get("intro", false)):
		jar["intro"] = true
	gen.layout.doodads.append(jar)
	var anchors: Array[float] = spot["anchors"]
	gen.add_enemy(TYPE, j, lane, 0, {LevelLayout.HELD: true, "doghouse": false, "charges": anchors.size(),
		"charge_at": anchors, "floor_span": spot["span"]})
	refresh(plan)


## Every jar holding an Octodog in `layout`: its front (LevelGenerator.feature_positions: the every-feature check and the
## introduction's).
static func positions(layout: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for d: Dictionary in layout.doodads:
		if LevelLayout.held_type(d) == TYPE:
			out.append(float(d["start"]))
	return out


## True if a stretch of `spans` reaches into [from, to].
static func _hits(spans: Array[Vector2], from: float, to: float) -> bool:
	for s: Vector2 in spans:
		if s.x <= to and s.y >= from:
			return true
	return false


## Every placement rule a finished level's jars break (see the header), for the tests: [] if none. Run on the finished
## layout, so it also catches a pass after the rules that put something where a jar or its dog keeps. The jar's own push
## is LayoutChecks.check_doodads'.
static func problems(gen: LevelGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	var lay: LevelLayout = gen.layout
	var t: OctodogTuning = tuning()
	var scaling: float = gen.config.enemy_scaling
	var window: float = t.window_length(gen.speed, scaling, gen.pace)
	var stop: float = t.stop_distance(gen.speed, scaling, gen.pace)
	var cycle: float = t.cycle_distance(gen.speed, scaling, gen.pace)
	var release: float = release_distance(gen, t)
	var before: float = LevelGenerator.doodad_lead_for(gen.tuning) + gen.doodad_lane_room()
	var last_ok: float = lay.length - gen.config.end_clear_distance
	var after: float = stop
	var gap: float = gen.metres(DOG_GAP)
	var r: Vector2i = t.charges_range(scaling)
	var keeps: Array[Vector2] = []
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if not k.has("lane"):
			keeps.append(Vector2(float(k["from"]), float(k["to"])))
	var chases: Array[Vector2] = HostRules.chase_stretches(gen)
	chases.append_array(gen.extended_wall_run_reserve)
	for e: Dictionary in lay.enemies:
		if LevelLayout.is_held(e) and lay.holder_of(e).is_empty():
			out.append("a held %s at %.1f m has no doodad holding it" % [e.get("type", "?"), float(e["at"])])
	for d: Dictionary in lay.doodads:
		if not LevelLayout.holds_enemy(d):
			continue
		var j: float = float(d["start"])
		var lane: int = int(d["lane"])
		var tag: String = "the jar at %.1f m (lane %d)" % [j, lane]
		if LevelLayout.held_type(d) != TYPE:
			out.append("%s: holds a %s, not an Octodog" % [tag, LevelLayout.held_type(d)])
			continue
		if lane < 1 or lane > lay.lane_count - 2 or absi(int(d["side"])) != 1 or StringName(d["size"]) != JAR_SIZE \
				or absf(float(d["end"]) - j - gen.tuning.doodad_size(JAR_SIZE).z) > 0.01 or d.has("row"):
			out.append("%s: not one small doodad in an inner lane pushing to a side" % tag)
		if j < gen.config.start_clear_distance - 0.01 or j - before < gen.feature_start(FEATURE) - 0.01:
			out.append("%s: before the run-up or the feature's start" % tag)
		var held: Array[Dictionary] = []
		for e: Dictionary in lay.enemies:
			if LevelLayout.is_held(e) and is_same(lay.holder_of(e), d):
				held.append(e)
		if held.size() != 1:
			out.append("%s: holds %d Octodogs, not one" % [tag, held.size()])
			continue
		var dog: Dictionary = held[0]
		var p: Dictionary = dog.get("params", {})
		var anchors: Array = p.get("charge_at", [])
		var span: Variant = p.get("floor_span")
		if bool(p.get("doghouse", true)) or anchors.is_empty() or int(p.get("charges", 0)) != anchors.size() \
				or not span is Vector2:
			out.append("%s: its dog has no plan of its own (no doghouse, its charges, its run)" % tag)
			continue
		var run: Vector2 = span
		var a0: float = float(anchors[0])
		var last: float = float(anchors[-1])
		var loose: float = j - before
		if absf(a0 - (j + release)) > 0.01:
			out.append("%s: its dog's first wind-up isn't planned where it's in position (%.1f m, not %.1f m)" % [tag, a0,
				j + release])
		if anchors.size() < 1 or anchors.size() > r.y:
			out.append("%s: its dog makes %d charges (1-%d)" % [tag, anchors.size(), r.y])
		if absf(run.x - OctodogRules.run_start(gen, a0)) > 0.01 or absf(run.y - (last + window - 0.001)) > 0.01:
			out.append("%s: its dog's run isn't from before its first wind-up to past its last charge" % tag)
		if last + window > last_ok + 0.01:
			out.append("%s: its dog's last charge reaches the end-clear stretch" % tag)
		for i: int in anchors.size():
			var a: float = float(anchors[i])
			if not Octodog.charge_clear(lay, a, window, gen.pace):
				out.append("%s: its dog's charge %d (at %.1f m) has no clear stretch" % [tag, i + 1, a])
			if i > 0 and a < float(anchors[i - 1]) + cycle - 0.01:
				out.append("%s: its dog's charge %d comes sooner than a cycle after the one before" % [tag, i + 1])
		if Octodog.pad_or_landing_between(lay, a0 - gen.metres(PAD_BEFORE), last + stop + gen.metres(PAD_AFTER), gen.pace) \
				or not _off_ceiling_zones(gen, run):
			out.append("%s: its dog's run meets an anti-grav pad or a ceiling's landing" % tag)
		for s: Vector2 in chases:
			if s.x <= last + window + stop and s.y >= loose:
				out.append("%s: its dog's run meets a Bad Dream's chase or a kept wall run (%.1f-%.1f m)" % [tag, s.x, s.y])
		# Its charges never in what a rule keeps in every lane (a falling gantryway's calm stretch, a teleporter's pad
		# stretch and landings, a wall-run gap's clear stretch: the rules placed after the jars keep off every dog's
		# charges, as the jars kept their dogs' runs off what was there before).
		for a: Variant in anchors:
			for k: Vector2 in keeps:
				if k.x <= float(a) + window and k.y >= float(a) - 1.0:
					out.append("%s: what a rule keeps in every lane (%.1f-%.1f m) reaches its dog's charge at %.1f m" % [tag,
						k.x, k.y, float(a)])
		var mine: Vector2 = busy_of(gen, dog, before, after)
		for e: Dictionary in lay.enemies:
			if is_same(e, dog) or String(e.get("type", "")) != TYPE:
				continue
			var o: Vector2 = busy_of(gen, e, before, after)
			if o.y >= o.x and o.x <= mine.y + gap and o.y + gap >= mine.x:
				out.append("%s: its dog's run (%.1f-%.1f m) too near another Octodog's (%.1f-%.1f m)" % [tag, mine.x, mine.y,
					o.x, o.y])
	return out
