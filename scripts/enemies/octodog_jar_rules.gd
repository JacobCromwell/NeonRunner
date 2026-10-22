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
## pieces, the falling gantryways' and the teleporters' included: the jars are planned on the level's final rules track.
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
	## What a wait for its turn can move a dog's run on (turn_wait_max at run speed), and the room between two runs
	## beyond the stop distance (DOG_GAP).
	var wait_room: float = 0.0
	var gap: float = 0.0
	## Where a jar's front may stand: [lo, hi], tried `step` apart.
	var lo: float = 0.0
	var hi: float = -1.0
	var step: float = 2.0
	## Every Bad Dream's chase and kept extended wall run.
	var chases: Array[Vector2] = []
	## What the rules keep (every lane and lane by lane, all counted in every lane), every Octodog's run as far as it
	## keeps a new one off (to its stop distance and a wait's room past its end), every other enemy's stretch, and the
	## zone doodads' room (refresh()).
	var keeps: Array[Vector2] = []
	var dogs: Array[Vector2] = []
	var others: Array[Vector2] = []
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
	p.wait_room = t.turn_wait_max * gen.speed
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


## What `plan`'s layout holds now (after a jar and its dog joined it): the zone doodads' room, what the rules keep, every
## Octodog's run as far as it keeps a new one off, every other enemy's stretch.
static func refresh(plan: Plan) -> void:
	var gen: LevelGenerator = plan.gen
	plan.room = gen.doodad_room()
	plan.keeps.clear()
	for k: Dictionary in gen.rules_doodad_keep_outs():
		plan.keeps.append(Vector2(float(k["from"]), float(k["to"])))
	plan.dogs.clear()
	plan.others.clear()
	var hooks: Dictionary = {}
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == TYPE:
			var run: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
			if run.y >= run.x:
				plan.dogs.append(Vector2(run.x, run.y + plan.stop + plan.wait_room))
			continue
		var k: Vector2 = stretch_of(gen, e, hooks)
		if k.y >= k.x:
			plan.others.append(k)


## Enemy entry `e`'s stretch as a jar keeps its release off it (an Octodog's aside): what the fill pass keeps around it
## (LevelGenerator.enemy_keep_out) and the floor it uses; nothing (x > y) for one that only drives behind the runner
## (EnemyTuning.behind_runner: the Enforcer Truck), which stands nowhere ahead of them.
static func stretch_of(gen: LevelGenerator, e: Dictionary, hooks: Dictionary = {}) -> Vector2:
	var t := EnemyDirector.tuning_for(String(e.get("type", ""))) as EnemyTuning
	if t != null and t.behind_runner:
		return Vector2(INF, -INF)
	var k: Vector2 = gen.enemy_keep_out(e, hooks)
	var span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
	if span.y >= span.x:
		k = Vector2(minf(k.x, span.x), maxf(k.y, span.y))
	return k


## The plan of the dog a jar with its front at `j` holds, trying for `wanted` charges, in `plan`'s level:
## {anchors, span}, or {} where no fair one fits (see the header).
static func dog_at(plan: Plan, j: float, wanted: int) -> Dictionary:
	var gen: LevelGenerator = plan.gen
	var lay: LevelLayout = gen.layout
	var a0: float = j + plan.release
	var from: float = j - plan.before
	if a0 + plan.window > plan.last_ok:
		return {}
	# The release and the sprint ahead: nothing else's stretch, no pad or ceiling landing.
	if _hits(plan.others, from, a0) or Octodog.pad_or_landing_between(lay, from - gen.metres(PAD_BEFORE),
			a0 + plan.stop + gen.metres(PAD_AFTER), gen.pace):
		return {}
	if not Octodog.charge_clear(lay, a0, plan.window, gen.pace):
		return {}
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
	if anchors.size() < mini(MIN_CHARGES, wanted):
		return {}
	var span := Vector2(from, anchors[-1] + plan.window - 0.001)
	if not _off_ceiling_zones(gen, span) or _hits(plan.chases, span.x, anchors[-1] + plan.window + plan.stop) \
			or _hits(plan.keeps, span.x, span.y):
		return {}
	# One dog at a time: its run (and what a wait can move it on) apart from every other's.
	if _hits(plan.dogs, span.x - plan.gap, span.y + plan.stop + plan.wait_room + plan.gap):
		return {}
	return {"anchors": anchors, "span": span}


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
	var count: int = gen.config.octodog_jars
	if count <= 0 or not gen.config.has_feature(FEATURE) or gen.layout.lane_count < 3:
		return
	var t0: int = Time.get_ticks_usec()
	_apply(gen, count)
	spent_usec += Time.get_ticks_usec() - t0


static func _apply(gen: LevelGenerator, count: int) -> void:
	var t: OctodogTuning = tuning()
	var plan: Plan = plan_for(gen, t, powerups())
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var placed: int = 0
	var from: float = plan.lo
	if gen.config.feature_starts.has(FEATURE):
		var wanted: int = _roll_charges(gen, t, rng)
		var window: float = minf(plan.lo + t.jar_intro_window_seconds * gen.speed, plan.hi)
		var spot: Dictionary = _earliest(plan, rng, plan.lo, window, wanted, true)
		if spot.is_empty():
			spot = _earliest(plan, rng, plan.lo, plan.hi, wanted, true)
		if not spot.is_empty():
			spot["intro"] = true
			_place(plan, spot, placed)
			placed += 1
			from = float(spot["front"]) + plan.step
	var left: int = count - placed
	if left > 0 and from <= plan.hi:
		var part: float = (plan.hi - from) / float(left)
		var wanted_at: Array[float] = []
		for k: int in left:
			wanted_at.append(from + (k + rng.randf_range(0.25, 0.75)) * part)
		for k: int in left:
			var a: float = from + k * part
			var spot: Dictionary = _nearest(plan, rng, a, a + part, wanted_at[k], _roll_charges(gen, t, rng))
			if not spot.is_empty():
				_place(plan, spot, placed)
				placed += 1
	# Where a part had no room: the earliest of what's left, along the level past the introduction.
	while placed < count:
		var spot: Dictionary = _earliest(plan, rng, from, plan.hi, _roll_charges(gen, t, rng), false)
		if spot.is_empty():
			break
		_place(plan, spot, placed)
		placed += 1
	if placed == 0:
		gen.warnings.append("octodog jars: no fair spot for one in the level (GDD §5: a feature a level has appears in it)")
	gen.layout.doodads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))


## How many charges a freed dog tries for (charges_range at the level's enemy scaling).
static func _roll_charges(gen: LevelGenerator, t: OctodogTuning, rng: RandomNumberGenerator) -> int:
	var r: Vector2i = t.charges_range(gen.config.enemy_scaling)
	return rng.randi_range(r.x, r.y)


## The earliest fair spot with its front in [a, b] (see the header), as {front, lane, side, anchors, span}, or {}; with
## `middle`, in the inner lane nearest the middle that fits, else in a seeded one.
static func _earliest(plan: Plan, rng: RandomNumberGenerator, a: float, b: float, wanted: int, middle: bool) -> Dictionary:
	var j: float = maxf(a, plan.lo)
	while j <= minf(b, plan.hi):
		var spot: Dictionary = _spot_at(plan, rng, j, wanted, middle)
		if not spot.is_empty():
			return spot
		j += plan.step
	return {}


## The fair spot with its front in [a, b] nearest `want` (searched outward from it, the earlier side first on a tie), or
## {}.
static func _nearest(plan: Plan, rng: RandomNumberGenerator, a: float, b: float, want: float, wanted: int) -> Dictionary:
	var lo: float = maxf(a, plan.lo)
	var hi: float = minf(b, plan.hi)
	if hi < lo:
		return {}
	var center: float = clampf(want, lo, hi)
	var reach: int = ceili(maxf(center - lo, hi - center) / plan.step)
	for k: int in reach + 1:
		var tries: Array[float] = [center] if k == 0 else [center - k * plan.step, center + k * plan.step]
		for j: float in tries:
			if j < lo or j > hi:
				continue
			var spot: Dictionary = _spot_at(plan, rng, j, wanted, false)
			if not spot.is_empty():
				return spot
	return {}


## A jar with its front at `j` and its dog's plan, if both fit: {front, lane, side, anchors, span}, or {}. The lane: with
## `middle` the inner one nearest the middle that fits, else a seeded one among those that do; its push's side a seeded
## one where both fit.
static func _spot_at(plan: Plan, rng: RandomNumberGenerator, j: float, wanted: int, middle: bool) -> Dictionary:
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
		return {}
	var dog: Dictionary = dog_at(plan, j, wanted)
	if dog.is_empty():
		return {}
	var pick: Array = fits[rng.randi_range(0, fits.size() - 1)]
	if middle:
		var mid: float = (lanes - 1) * 0.5
		fits.sort_custom(func(x: Array, y: Array) -> bool: return absf(float(x[0]) - mid) < absf(float(y[0]) - mid))
		pick = fits[0]
	var sides: Array = pick[1]
	return {"front": j, "lane": int(pick[0]), "side": int(sides[rng.randi_range(0, sides.size() - 1)]),
		"anchors": dog["anchors"], "span": dog["span"]}


## Stands jar `spot` (_spot_at) and the dog it holds in the layout, the `index`th of the level's jars.
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
	var room_after: float = t.turn_wait_max * gen.speed + gen.metres(DOG_GAP)
	var r: Vector2i = t.charges_range(scaling)
	var keeps: Array[Vector2] = []
	for k: Dictionary in gen.rules_doodad_keep_outs():
		keeps.append(Vector2(float(k["from"]), float(k["to"])))
	var chases: Array[Vector2] = HostRules.chase_stretches(gen)
	chases.append_array(gen.extended_wall_run_reserve)
	for e: Dictionary in lay.enemies:
		if LevelLayout.is_held(e) and lay.holder_of(e).is_empty():
			out.append("a held %s at %.1f m has no doodad holding it" % [e.get("type", "?"), float(e["at"])])
	var hooks: Dictionary = {}
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
		if absf(a0 - (j + release)) > 0.01:
			out.append("%s: its dog's first wind-up isn't planned where it's in position (%.1f m, not %.1f m)" % [tag, a0,
				j + release])
		if anchors.size() < mini(MIN_CHARGES, r.x) or anchors.size() > r.y:
			out.append("%s: its dog makes %d charges (%d-%d)" % [tag, anchors.size(), r.x, r.y])
		if absf(run.x - (j - before)) > 0.01 or absf(run.y - (last + window - 0.001)) > 0.01:
			out.append("%s: its dog's run isn't from the jar's push to past its last charge" % tag)
		if last + window > last_ok + 0.01:
			out.append("%s: its dog's last charge reaches the end-clear stretch" % tag)
		for i: int in anchors.size():
			var a: float = float(anchors[i])
			if not Octodog.charge_clear(lay, a, window, gen.pace):
				out.append("%s: its dog's charge %d (at %.1f m) has no clear stretch" % [tag, i + 1, a])
			if i > 0 and a < float(anchors[i - 1]) + cycle - 0.01:
				out.append("%s: its dog's charge %d comes sooner than a cycle after the one before" % [tag, i + 1])
		if Octodog.pad_or_landing_between(lay, run.x - gen.metres(PAD_BEFORE), last + stop + gen.metres(PAD_AFTER), gen.pace) \
				or not _off_ceiling_zones(gen, run):
			out.append("%s: its dog's run meets an anti-grav pad or a ceiling's landing" % tag)
		for s: Vector2 in chases:
			if s.x <= last + window + stop and s.y >= run.x:
				out.append("%s: its dog's run meets a Bad Dream's chase or a kept wall run (%.1f-%.1f m)" % [tag, s.x, s.y])
		for k: Vector2 in keeps:
			if k.x <= run.y and k.y >= run.x:
				out.append("%s: what a rule keeps (%.1f-%.1f m) reaches its dog's run" % [tag, k.x, k.y])
		for e: Dictionary in lay.enemies:
			if is_same(e, dog):
				continue
			var type: String = String(e.get("type", ""))
			if type == TYPE:
				var o: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
				if o.y >= o.x and o.x <= run.y + stop + room_after and o.y + stop + room_after >= run.x:
					out.append("%s: its dog's run (%.1f-%.1f m) too near another Octodog's (%.1f-%.1f m)" % [tag, run.x, run.y,
						o.x, o.y])
				continue
			var k2: Vector2 = stretch_of(gen, e, hooks)
			if k2.x <= a0 and k2.y >= run.x:
				out.append("%s: a %s's stretch (%.1f-%.1f m) reaches its release or its dog's run ahead" % [tag, type, k2.x, k2.y])
	return out
