extends RefCounted
## Generator rules for the Octodog jars that break open (task Q5; GDD §5, Zone 9, the owner, October 21, 2026: "some jars
## hold a curled-up Octodog instead of a brain. Sometimes smashing an Octodog jar doodad releases its Octodog into the
## world, and the runner has to fight it"; its proposals: a jar is smashed the way every doodad is, by the dash, and one
## that will release its Octodog looks the same as one that won't; the freed Octodog tumbles out, runs ahead to its usual
## distance and starts its usual attack (§9.4) from the first wind-up, with its cue, never a lunge without warning; it is
## fought and killed like any Octodog). No patterns: like the falling gantryways and the teleporters, a set piece its
## rules stand where it's fair. Each is two entries:
## - a zone doodad (LevelLayout.doodads) of the small class (JAR_SIZE) in lane L, its front at J, pushing into the lane on
##   its `side` like any doodad, marked LevelLayout.HOLDS "octodog": the skin dresses it as the zone's jar with an
##   Octodog curled up in it (ZoneSkin.held_doodad_look; the Ice Lab's IceLabDoodads.OCTODOG_JAR), the look the zone's
##   other Octodog jars, which hold nothing, have too;
## - the Octodog it holds: an ordinary `octodog` entry of LevelLayout.enemies at J in L, its params marked
##   LevelLayout.HELD, with no doghouse, and its charges planned from the release (`charges`, `charge_at`, `floor_span`)
##   as octodog_rules.gd plans a standing dog's. It stays in its jar (Octodog: hidden, harmless, untouchable) until the
##   jar breaks; a runner who passes the jar (pushed aside, as by any doodad) never meets it.
##
## Where (at the level's run speed; every margin in metres written for MovementTuning.REFERENCE_SPEED and stretched by the
## level's pace, LevelGenerator.metres):
## - The jar keeps every rule a zone doodad keeps (LevelGenerator.doodad_fits: its own lane and the lanes beside it clear
##   around it, what every lane keeps never reaching it, no other doodad too near), in an inner lane or, where the level
##   stands doodads by a side wall, in an outermost one by an open stretch of that wall, pushing inward (task L3: a wall
##   runner low on that wall breaks it as they reach it, and it lets its dog out then too). DESIGN-TBD
##   (docs/questions/q5.md 2 and 3).
## - Its dog's first wind-up is planned release_distance past the jar's front (OctodogTuning: the tumble, the sprint to its
##   usual distance ahead and jar_settle_seconds, and how far the dash that smashed the jar can carry the runner on
##   meanwhile), each later one as a standing dog's (a cycle on, or up to charge_slack later where its stretch is clear),
##   MIN_CHARGES at least (GDD §9.4: "2–3 charges early, up to 4 at the maximum"; octodog_rules.gd's least) and up to
##   the count it rolls (charges_range at the level's enemy scaling); one only where no spot in the level has room for
##   more even with room made (below), so the level still has its jar. DESIGN-TBD (docs/questions/q5.md 6). Each
##   charge's stretch is clear as a standing dog's must be (Octodog.charge_clear: no fence, doodad, anti-grav pad,
##   ceiling landing or other enemy near, holes in one lane at most), with no pad or ceiling landing near its first
##   wind-up or between two of them (Octodog.pad_or_landing_between). Another enemy at work while it gets out and into
##   position is kept apart from its charges as from a standing dog's (charge_clear's margins, and the director's turns
##   at its first wind-up, GDD §9). DESIGN-TBD (docs/questions/q5.md 13).
## - From the jar's push lead to past its last charge (its run: the dog is loose from the jar on), no anti-grav pad's
##   zone or ceiling landing zone (CeilingZones), no Bad Dream's chase or kept extended wall run, nothing the rules keep
##   (in every lane or in a lane, all counted in every lane, as the dog crosses lanes: a falling gantryway from its
##   pillar's lead to past its walkway and calm stretch, a teleporter's way around, pad stretch and landings, a wall-run
##   gap's clear stretch, a treasure stash's floor), so no freed dog attacks in a gantryway's step out or a teleporter's
##   approach or landing; and every other Octodog's run kept apart from it (one at a time, as octodog_rules.gd keeps
##   them: a stop distance and DOG_GAP between them).
## - Between the run-up (and the feature's start) and the end-clear stretch.
## Every pass after the rules keeps off the dog's run as off any enemy's (its entry's keep-out reaches back past the jar:
## the fill pass, the danger density pass, the wider gaps, the cyborgs planted in charge paths, the zone doodads), so the
## jar stays as fair as it was placed; problems() re-checks a finished layout (LayoutChecks.check_octodog_jars), and the
## jar's push is checked as any doodad's (LayoutChecks.check_doodads, which leaves its own dog out of it).
##
## Making room: a heli drone's pad schedule (a ceiling every 8 to 10 s from its first pad to the level's end, whose pads
## and landings no dog's run may meet) leaves no stretch long enough for two charges once it has started, so a level
## with drones has room for a freed dog's usual attack before the drone's first pad only, where its own content stands.
## Like a gantryway's introduction (gantryway_rules.gd, _make_room), a jar takes plain content out of its way where
## nothing fits without that (taking content out never makes a level unfair): enemies of MAKE_ROOM_TYPES with no rule's
## mark in their params (a pattern's cyborg, window cyborg or fence generator; never a host, a gantryway's or a charge
## path's cyborg, an Octodog or a drone) standing near one of its charges or where the jar keeps clear, ceilings the
## patterns put there (with their pads and the credits on them; never a drone's, a ceiling scenario's or one a Barnacle
## Turret hangs from), and plain holes and fences (never a wall-run gap's hole, a pulsing fence or one a fence generator
## powers). Never the last of a feature, nor the first of one the level gives a start: every feature and introduction
## stays. The spot that takes the fewest out is taken, then the one nearest a seeded aim. DESIGN-TBD
## (docs/questions/q5.md 7).
##
## How many: up to LevelConfig.octodog_jars, a part of the level each, the best spot there (above), then the best of the
## rest. Its own random stream (LevelGenerator.rng_for), after every other feature's rules (RUN_AFTER: the gantryways and
## the teleporters keep exactly the spots they had), so a level without the feature draws nothing and is built byte for
## byte as before. Which of a zone's Octodog jars release: only these. Its others are its skin's look (IceLabDoodads'
## variety, commoner toward the laboratory) and hold nothing, so "sometimes" is these among them. DESIGN-TBD
## (docs/questions/q5.md 1).

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
const GantrywayRules = preload("res://scripts/enemies/gantryway_rules.gd")
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
## The jar's size class (LevelLayout.DOODAD_SIZES): the small one, whose looks the Ice Lab's Octodog jar is among.
const JAR_SIZE: StringName = &"small"
## A freed dog makes at least this many charges where any spot in the level has room for them (GDD §9.4: "2–3 charges
## early"; octodog_rules.gd's MIN_CHARGES), else one (_apply).
const MIN_CHARGES: int = 2
## Metres between the jar fronts tried (at the reference speed).
const SEARCH_STEP: float = 2.0
## Metres between two Octodogs' runs beyond the stop distance (at the reference speed).
const DOG_GAP: float = 10.0
## Metres kept clear of a pad's spot before its first wind-up and past where its run ends, as octodog_rules.gd's
## _first_charge_fits and LayoutChecks.check_rules keep them (at the reference speed).
const PAD_BEFORE: float = 6.0
const PAD_AFTER: float = 2.0
## The enemy types a jar may take out of its way to make room (see the header), when their params carry no key but
## PLAIN_PARAMS (a pattern's own).
const MAKE_ROOM_TYPES: PackedStringArray = ["cyborg", "window_cyborg", "generator", "screech"]
const PLAIN_PARAMS: PackedStringArray = ["panic"]
## Spots tried for real, the fewest taken out first, for one jar (_best): what's taken out for each is put back if it
## doesn't fit after all.
const ROOM_TRIES: int = 12

## Review aid (tools/measure/octodog_jars.gd): microseconds apply() has taken, and the pieces and enemies it has taken out
## to make room, summed over every call since they were zeroed.
static var spent_usec: int = 0
static var taken_out: int = 0
## Review aid (tools/measure/octodog_jars.gd --why): with `debug` on, how many jar fronts tried each reason turned down.
static var debug: bool = false
static var why: Dictionary = {}
# TEMPORARY (task Q5 investigation): remove before the task's last commit.
static var tmp_dump: bool = false


# TEMPORARY (task Q5 investigation): remove before the task's last commit.
static func _tmp_dump(plan: Plan) -> void:
	var gen: LevelGenerator = plan.gen
	var lay: LevelLayout = gen.layout
	var items: Array = []
	for h: Dictionary in lay.hulls:
		items.append([float(h["start"]), "HULL %.0f-%.0f landing to %.0f" % [float(h["start"]), float(h["end"]),
			gen.zones.landing_zone(h).y]])
	for p: Dictionary in lay.pads:
		var z: Vector2 = gen.zones.pad_zone(float(p["at"]))
		items.append([float(p["at"]), "PAD %.0f zone %.0f-%.0f" % [float(p["at"]), z.x, z.y]])
	for e: Dictionary in lay.enemies:
		var k: Vector2 = gen.enemy_keep_out(e, {})
		var f: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
		items.append([float(e["at"]), "ENEMY %s %.0f L%d keep %.0f-%.0f floor %.0f-%.0f %s" % [e["type"], float(e["at"]),
			int(e.get("lane", -1)), k.x, k.y, f.x, f.y, str(e.get("params", {})).left(160)]])
	for k: Dictionary in gen.rules_doodad_keep_outs():
		items.append([float(k["from"]), "KEEP %.0f-%.0f %s" % [float(k["from"]), float(k["to"]), k]])
	for c: Vector2 in plan.chases:
		items.append([c.x, "CHASE %.0f-%.0f" % [c.x, c.y]])
	for d: Dictionary in lay.doodads:
		items.append([float(d["start"]), "DOODAD %.0f L%d %s" % [float(d["start"]), int(d["lane"]),
			"HOLDS" if LevelLayout.holds_enemy(d) else ""]])
	items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	print("TIMELINE lo=%.0f hi=%.0f fences=%d gaps=%d" % [plan.lo, plan.hi, lay.fences.size(), lay.gaps.size()])
	for it: Array in items:
		print("  %7.0f  %s" % [float(it[0]), it[1]])


## Counts reason `what` in `why` (with `debug` on) and returns {} (a spot turned down).
static func _no(what: String) -> Dictionary:
	if debug:
		why[what] = int(why.get(what, 0)) + 1
	return {}


## One level's numbers for its jars, at its run speed (metres), and what the layout holds that they keep off (plan_for,
## refreshed whenever the layout changes by refresh()).
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
	## What the layout holds now (refresh()): what the rules keep (every lane and lane by lane, all counted in every lane),
	## every Octodog's run as far as it keeps a new one off (busy_of), every pad's zone and ceiling landing zone
	## (CeilingZones), and the zone doodads' room.
	var keeps: Array[Vector2] = []
	var dogs: Array[Vector2] = []
	var zones: Array[Vector2] = []
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


## What `plan`'s layout holds now (Plan; after a jar and its dog joined it, or content went to make room).
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
	plan.zones = _ceiling_zones(gen)


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


## Every anti-grav pad's zone and ceiling landing zone in `gen`'s layout (CeilingZones), in any lane.
static func _ceiling_zones(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Dictionary in gen.layout.pads:
		out.append(gen.zones.pad_zone(float(p["at"])))
	out.append_array(gen.zones.landing_zones(gen.layout))
	return out


## The plan of the dog a jar with its front at `j` holds, trying for `wanted` charges and making `least` at the fewest,
## in `plan`'s level: {anchors, span}, or {} where no fair one fits (see the header). Its later charges are the first that
## fit one after the other; it keeps as many of them as its run takes off everything it keeps clear.
static func dog_at(plan: Plan, j: float, wanted: int, least: int = MIN_CHARGES) -> Dictionary:
	var gen: LevelGenerator = plan.gen
	var lay: LevelLayout = gen.layout
	var a0: float = j + plan.release
	var from: float = j - plan.before
	# The shortest run it can make (`least` charges a cycle apart) must fit before anything else is looked at.
	var shortest: float = a0 + (least - 1) * plan.cycle + plan.window
	if shortest > plan.last_ok:
		return _no("its dog's charges reach the end")
	if _hits(plan.zones, from, shortest) or _hits(plan.chases, from, shortest + plan.stop) or _hits(plan.keeps, from, shortest):
		return _no("a pad, a landing, a chase or what a rule keeps in its shortest run")
	if _hits(plan.dogs, from - plan.gap, shortest + plan.stop + plan.gap):
		return _no("another Octodog's run")
	# Its first wind-up as a standing dog's (octodog_rules.gd, _first_charge_fits): no pad or ceiling landing from a little
	# before it to where the dog stands then, and a clear stretch.
	if Octodog.pad_or_landing_between(lay, a0 - gen.metres(PAD_BEFORE), a0 + plan.stop + gen.metres(PAD_AFTER), gen.pace):
		return _no("a pad or a ceiling landing at its first wind-up")
	if not Octodog.charge_clear(lay, a0, plan.window, gen.pace):
		return _no("its dog's first charge not clear")
	var anchors: Array[float] = [a0]
	var prev: float = a0
	var slack: float = gen.metres(plan.t.charge_slack)
	while anchors.size() < maxi(wanted, least):
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
	if anchors.size() < least:
		return _no("too few charges fit")
	var why_not: String = ""
	while anchors.size() >= least:
		# The floor its charges use, as a standing dog's (octodog_rules.gd, run_start: from before its first wind-up to
		# past its last); from the jar on, the dog is loose: its whole run off every pad's zone and ceiling landing, every
		# chase and what every rule keeps, and one dog at a time (its run and its stop distance after it apart from every
		# other's).
		var span := Vector2(OctodogRules.run_start(gen, a0), anchors[-1] + plan.window - 0.001)
		if _hits(plan.zones, from, span.y):
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


## For a jar with its front at `j` whose dog makes `least` charges at the fewest: `j` if the shortest run its dog can make
## (dog_at) meets no pad's zone, ceiling landing, chase, what a rule keeps or other Octodog's run, else the first front past
## all it meets there (every front before that meets one of them too: _best skips them).
static func _past_blocks(plan: Plan, j: float, least: int) -> float:
	var a0: float = j + plan.release
	var from: float = j - plan.before
	var shortest: float = a0 + (least - 1) * plan.cycle + plan.window
	var past: float = j
	for s: Vector2 in plan.zones:
		if s.x <= shortest and s.y >= from:
			past = maxf(past, s.y + plan.before + 0.001)
	for s: Vector2 in plan.keeps:
		if s.x <= shortest and s.y >= from:
			past = maxf(past, s.y + plan.before + 0.001)
	for s: Vector2 in plan.chases:
		if s.x <= shortest + plan.stop and s.y >= from:
			past = maxf(past, s.y + plan.before + 0.001)
	for s: Vector2 in plan.dogs:
		if s.x <= shortest + plan.stop + plan.gap and s.y >= from - plan.gap:
			past = maxf(past, s.y + plan.gap + plan.before + 0.001)
	return past


## A jar with its front at `j` and its dog's plan (dog_at: `least` charges at the fewest), if both fit as `plan`'s layout
## stands: {front, anchors, span, fits}, `fits` the lanes the jar fits in, each [lane, its sides that fit], or {}.
static func _fits_at(plan: Plan, j: float, wanted: int, least: int) -> Dictionary:
	var dog: Dictionary = dog_at(plan, j, wanted, least)
	if dog.is_empty():
		return {}
	var fits: Array[Array] = []
	for lane: int in plan.gen.layout.lane_count:
		var sides: Array[int] = []
		for side: int in [-1, 1]:
			if plan.gen.doodad_fits(plan.room, JAR_SIZE, lane, side, j):
				sides.append(side)
		if not sides.is_empty():
			fits.append([lane, sides])
	if fits.is_empty():
		return _no("no lane for the jar")
	dog["front"] = j
	dog["fits"] = fits
	return dog


static func tuning() -> OctodogTuning:
	return OctodogRules.tuning()


static func powerups() -> PowerupTuning:
	var res: Resource = load(POWERUPS_PATH) if ResourceLoader.exists(POWERUPS_PATH) else null
	return res as PowerupTuning if res is PowerupTuning else PowerupTuning.new()


## The level's jars (see the header).
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
	if tmp_dump:
		_tmp_dump(plan)
	var placed: int = 0
	if plan.hi >= plan.lo:
		# A part of the level each, aiming for a seeded spot in it; then, where a part had no room, the rest of the level.
		var part: float = (plan.hi - plan.lo) / float(count)
		var aims: Array[float] = []
		for k: int in count:
			aims.append(plan.lo + (k + rng.randf_range(0.25, 0.75)) * part)
		for k: int in count:
			var a: float = plan.lo + k * part
			var spot: Dictionary = _best(plan, rng, a, a + part, aims[k], _roll_charges(gen, t, rng), MIN_CHARGES)
			if not spot.is_empty():
				_place(plan, spot, placed)
				placed += 1
		while count > 1 and placed < count:
			var spot: Dictionary = _best(plan, rng, plan.lo, plan.hi, plan.lo, _roll_charges(gen, t, rng), MIN_CHARGES)
			if spot.is_empty():
				break
			_place(plan, spot, placed)
			placed += 1
		# A level with no room anywhere for a dog's usual attack, even with room made, still has its jar: its dog makes
		# the charges that fit, one at the fewest.
		if placed == 0:
			var spot: Dictionary = _best(plan, rng, plan.lo, plan.hi, aims[0], _roll_charges(gen, t, rng), 1)
			if not spot.is_empty():
				_place(plan, spot, placed)
				placed += 1
	if placed == 0:
		gen.warnings.append("octodog jars: no fair spot for one in the level (GDD §5: a feature a level has appears in it)")
	gen.layout.doodads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))


## How many charges a freed dog tries for (charges_range at the level's enemy scaling).
static func _roll_charges(gen: LevelGenerator, t: OctodogTuning, rng: RandomNumberGenerator) -> int:
	var r: Vector2i = t.charges_range(gen.config.enemy_scaling)
	return rng.randi_range(r.x, r.y)


## The best spot for a jar with its front in [a, b] (see the header: the fewest pieces and enemies taken out of its way,
## then the nearest `aim`, then the earliest; its lane the one that takes the fewest out, then the nearest the middle),
## its dog trying for `wanted` charges and making `least` at the fewest: {front, lane, side, anchors, span}, with what it
## needed taken out already gone from the layout, or {} (the layout as it was). The spots are those that fit with
## everything that may go out of the way (_removable); each of the best ROOM_TRIES is then tried for real with what's in
## its way taken out (_in_way, _strip), and put back if it doesn't fit after all.
static func _best(plan: Plan, rng: RandomNumberGenerator, a: float, b: float, aim: float, wanted: int,
		least: int) -> Dictionary:
	var gen: LevelGenerator = plan.gen
	var lay: LevelLayout = gen.layout
	var going: Going = _removable(gen)
	var saved: Dictionary = _save(lay)
	_strip(gen, _all_of(going))
	refresh(plan)
	var options: Array[Dictionary] = []
	var j: float = maxf(a, plan.lo)
	while j <= minf(b, plan.hi):
		# Past whatever its shortest run meets, on the fronts' grid.
		var past: float = _past_blocks(plan, j, least)
		if past > j:
			j = plan.lo + ceilf((past - plan.lo) / plan.step - 0.0001) * plan.step
			continue
		var o: Dictionary = _fits_at(plan, j, wanted, least)
		if not o.is_empty():
			options.append(o)
		j += plan.step
	_restore(lay, saved)
	refresh(plan)
	if options.is_empty():
		return {}
	# [taken out, off the aim, front, option, lane, what's in its way]
	var ranked: Array[Array] = []
	for o: Dictionary in options:
		var pick: Array = _in_way(plan, o, going)
		ranked.append([int(pick[0]), absf(float(o["front"]) - aim), float(o["front"]), o, int(pick[1]), pick[2]])
	ranked.sort_custom(func(x: Array, y: Array) -> bool:
		if int(x[0]) != int(y[0]):
			return int(x[0]) < int(y[0])
		if not is_equal_approx(float(x[1]), float(y[1])):
			return float(x[1]) < float(y[1])
		return float(x[2]) < float(y[2]))
	var features: Dictionary = _feature_counts(gen)
	for k: int in mini(ranked.size(), ROOM_TRIES):
		var r: Array = ranked[k]
		var items: Dictionary = r[5]
		var before_take: Dictionary = _save(lay)
		var n: int = int(r[0])
		if n > 0:
			_strip(gen, items)
			if not _features_kept(gen, features):
				_restore(lay, before_take)
				continue
			refresh(plan)
		var o: Dictionary = _fits_at(plan, float(r[2]), wanted, least)
		var lane: int = int(r[4])
		for f: Array in o.get("fits", []):
			if int(f[0]) == lane:
				var sides: Array = f[1]
				taken_out += n
				return {"front": float(r[2]), "lane": lane, "side": int(sides[rng.randi_range(0, sides.size() - 1)]),
					"anchors": o["anchors"], "span": o["span"]}
		if n > 0:
			_restore(lay, before_take)
			refresh(plan)
	return {}


## What may go from a layout to make room for a jar (_removable), with where each reaches along the track (metres),
## worked out once for every spot _in_way looks at: parallel lists, one entry each.
class Going:
	extends RefCounted
	## The plain enemies: each one's spot, what doodads keep off around it (LevelGenerator.doodad_enemy_keep_out; x > y
	## for nothing), its floor lane and the floor it uses (-1 and nothing for one off the floor).
	var enemies: Array[Dictionary] = []
	var enemy_at := PackedFloat64Array()
	var enemy_keep := PackedVector2Array()
	var enemy_lane := PackedInt32Array()
	var enemy_floor := PackedVector2Array()
	## The pattern ceilings: each one's reach, from its start (its pads' zones and Octodog.CEILING_LEAD before them, if
	## earlier) to its landing zone's end or Octodog.CEILING_LANDING past its end, whichever is later.
	var hulls: Array[Dictionary] = []
	var hull_reach := PackedVector2Array()
	## The plain fences (their spots) and holes (their stretches), with their lanes.
	var fences: Array[Dictionary] = []
	var fence_at := PackedFloat64Array()
	var fence_lane := PackedInt32Array()
	var gaps: Array[Dictionary] = []
	var gap_span := PackedVector2Array()
	var gap_lane := PackedInt32Array()
	## Every hole of the layout, in its order (LevelLayout.gaps): its index among `gaps`, or -1 for one that can't go.
	var gap_index := PackedInt32Array()


## What may go from `gen`'s layout to make room for a jar (see the header).
static func _removable(gen: LevelGenerator) -> Going:
	var lay: LevelLayout = gen.layout
	var out := Going.new()
	var first_drone: float = INF
	var hung: Array[float] = []
	for e: Dictionary in lay.enemies:
		match String(e.get("type", "")):
			"drone":
				first_drone = minf(first_drone, float(e["at"]))
			"barnacle_turret":
				hung.append(float((e.get("params", {}) as Dictionary).get("hull_start", -INF)))
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		if not MAKE_ROOM_TYPES.has(String(e.get("type", ""))):
			continue
		var plain: bool = true
		for key: Variant in (e.get("params", {}) as Dictionary).keys():
			plain = plain and PLAIN_PARAMS.has(String(key))
		if not plain:
			continue
		var lane: int = -1
		var span := Vector2(INF, -INF)
		if LevelGenerator.enemy_uses_floor(e):
			lane = int(e.get("lane", -1))
			if (lane < 0 or lane >= lay.lane_count) and int(e.get("side", 0)) != 0:
				lane = lay.outer_lane(int(e["side"]))
			span = LevelGenerator.enemy_floor_span(e, gen.pace)
		out.enemies.append(e)
		out.enemy_at.append(float(e["at"]))
		out.enemy_keep.append(gen.doodad_enemy_keep_out(e, hooks))
		out.enemy_lane.append(lane)
		out.enemy_floor.append(span)
	var lead: float = Octodog.CEILING_LEAD * gen.pace
	for h: Dictionary in lay.hulls:
		if h.has(CeilingScenarios.KEY):
			continue
		var keep: bool = false
		for at: float in hung:
			keep = keep or absf(at - float(h["start"])) < 0.01
		var reach := Vector2(float(h["start"]), maxf(gen.zones.landing_zone(h).y,
			float(h["end"]) + Octodog.CEILING_LANDING * gen.pace))
		for p: Dictionary in _pads_of(lay, h):
			var at: float = float(p["at"])
			keep = keep or at >= first_drone
			var zone: Vector2 = gen.zones.pad_zone(at)
			reach = Vector2(minf(reach.x, minf(zone.x, at - lead)), maxf(reach.y, maxf(zone.y, at + lead)))
		if not keep:
			out.hulls.append(h)
			out.hull_reach.append(reach)
	var powered: Array[Dictionary] = GantrywayRules.powered_fences(gen)
	for f: Dictionary in lay.fences:
		var lit: bool = false
		for p: Dictionary in powered:
			lit = lit or is_same(p, f)
		if not bool(f.get("pulsing", false)) and not lit:
			out.fences.append(f)
			out.fence_at.append(float(f["at"]))
			out.fence_lane.append(int(f["lane"]))
	for g: Dictionary in lay.gaps:
		if LevelLayout.is_wall_run_hole(g):
			out.gap_index.append(-1)
			continue
		out.gap_index.append(out.gaps.size())
		out.gaps.append(g)
		out.gap_span.append(Vector2(float(g["start"]), float(g["end"])))
		out.gap_lane.append(int(g["lane"]))
	return out


## Everything `going` holds, as _strip takes it: {enemies, hulls, fences, gaps}.
static func _all_of(going: Going) -> Dictionary:
	return {"enemies": going.enemies, "hulls": going.hulls, "fences": going.fences, "gaps": going.gaps}


## The pads of ceiling `h` in `lay` (under it, in its lanes).
static func _pads_of(lay: LevelLayout, h: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lanes: Vector2i = lay.hull_lanes(h)
	for p: Dictionary in lay.pads:
		var at: float = float(p["at"])
		if at >= float(h["start"]) - 0.01 and at <= float(h["end"]) + 0.01 and int(p["lane"]) >= lanes.x \
				and int(p["lane"]) <= lanes.y:
			out.append(p)
	return out


## Of `going` (_removable), what stands in the way of option `o` (_fits_at, found with all of it gone), as `gen`'s layout
## stands (the one `going` was worked out on), in the lane of the jar it fits in that takes the fewest out (the nearest
## the middle of those): [how many, lane, {enemies, hulls, fences, gaps}]. Whatever the lane: the enemies standing near
## one of its charges (Octodog.charge_clear's margins) or at work where the jar keeps every lane clear
## (LevelGenerator.doodad_enemy_keep_out, doodad_fits); the ceilings whose reach (Going) meets the jar's lead or its dog's
## run with its margins; the fences in a charge's stretch, and the holes there in every lane but one (the one with a hole
## that can't go, else the one with the most there). In the jar's lane and the lanes beside it: the floor enemies, holes
## and fences around it (LevelGenerator._doodad_lane_fits' and _doodad_push_fits' stretches).
static func _in_way(plan: Plan, o: Dictionary, going: Going) -> Array:
	var gen: LevelGenerator = plan.gen
	var lay: LevelLayout = gen.layout
	var j: float = float(o["front"])
	var anchors: Array[float] = o["anchors"]
	var from: float = j - plan.before
	var to: float = anchors[-1] + plan.window
	# Around the jar: what every lane keeps clear (its push's lead to a lane switch's room past its end), its own lane to
	# the level's spacing past it, and the lanes beside it (the one it pushes into among them) until its push's landing
	# and reaction, or a lane switch's room past its end if later.
	var end: float = j + plan.length
	var region := Vector2(j - LevelGenerator.doodad_lead_for(gen.tuning) - 0.02, j + gen.doodad_reach(plan.length) + 0.02)
	var own := Vector2(from - 0.01, end + gen.doodad_after(end))
	var beside := Vector2(from - 0.01, maxf(end + gen.doodad_lane_room(), gen.doodad_landing(j)))
	var before_charge: float = Octodog.OTHER_ENEMY_BEFORE * gen.pace
	var after_charge: float = plan.window + Octodog.OTHER_ENEMY_MARGIN * gen.pace
	var half: float = gen.tuning.fence_depth * 0.5
	# Whatever the lane: 1 for what goes, 2 for what's on the floor around the jar's stretch (in the way in its lane or a
	# lane beside it), 0 for the rest.
	var enemy_mark := PackedByteArray()
	enemy_mark.resize(going.enemies.size())
	for i: int in going.enemies.size():
		var at: float = going.enemy_at[i]
		var k: Vector2 = going.enemy_keep[i]
		var hit: bool = k.y >= k.x and k.x <= region.y and k.y >= region.x
		for a: float in anchors:
			hit = hit or (at >= a - before_charge and at <= a + after_charge)
		var s: Vector2 = going.enemy_floor[i]
		enemy_mark[i] = 1 if hit else (2 if going.enemy_lane[i] >= 0 and s.x <= beside.y and s.y >= own.x else 0)
	var reach := Vector2(from, to + plan.stop + gen.metres(PAD_AFTER))
	var hulls: Array[Dictionary] = []
	for i: int in going.hulls.size():
		var r: Vector2 = going.hull_reach[i]
		if r.x <= reach.y and r.y >= reach.x:
			hulls.append(going.hulls[i])
	var fence_mark := PackedByteArray()
	fence_mark.resize(going.fences.size())
	for i: int in going.fences.size():
		var at: float = going.fence_at[i]
		var hit: bool = false
		for a: float in anchors:
			hit = hit or (at >= a - 1.0 and at <= a + plan.window)
		fence_mark[i] = 1 if hit else (2 if at + half >= own.x and at - half <= maxf(own.y, beside.y) else 0)
	var gap_mark := PackedByteArray()
	gap_mark.resize(going.gaps.size())
	for i: int in going.gaps.size():
		var s: Vector2 = going.gap_span[i]
		gap_mark[i] = 2 if s.x <= maxf(own.y, beside.y) and s.y >= own.x else 0
	# In each charge's stretch, the holes of every lane but one.
	for a: float in anchors:
		var by_lane: Dictionary = {}
		var fixed: int = -1
		for g: int in lay.gaps.size():
			var hole: Dictionary = lay.gaps[g]
			if float(hole["start"]) <= a + plan.window and float(hole["end"]) >= a:
				var l: int = int(hole["lane"])
				if not by_lane.has(l):
					by_lane[l] = PackedInt32Array()
				var in_lane: PackedInt32Array = by_lane[l]
				in_lane.append(going.gap_index[g])
				by_lane[l] = in_lane
				if going.gap_index[g] < 0:
					fixed = l
		if by_lane.size() <= 1:
			continue
		var kept: int = fixed
		if kept < 0:
			for l: int in by_lane:
				if kept < 0 or (by_lane[l] as PackedInt32Array).size() > (by_lane[kept] as PackedInt32Array).size():
					kept = l
		for l: int in by_lane:
			if l == kept:
				continue
			for i: int in (by_lane[l] as PackedInt32Array):
				if i >= 0:
					gap_mark[i] = 1
	# The lane that takes the fewest out.
	var best: Array = []
	var middle: float = (lay.lane_count - 1) * 0.5
	for f: Array in o["fits"]:
		var lane: int = int(f[0])
		var n: int = hulls.size()
		for i: int in going.enemies.size():
			n += 1 if enemy_mark[i] == 1 or (enemy_mark[i] == 2 and _near_jar(going.enemy_lane[i], going.enemy_floor[i], lane,
				own, beside)) else 0
		for i: int in going.fences.size():
			var at: float = going.fence_at[i]
			n += 1 if fence_mark[i] == 1 or (fence_mark[i] == 2 and _near_jar(going.fence_lane[i], Vector2(at - half, at + half),
				lane, own, beside)) else 0
		for i: int in going.gaps.size():
			n += 1 if gap_mark[i] == 1 or (gap_mark[i] == 2 and _near_jar(going.gap_lane[i], going.gap_span[i], lane, own,
				beside)) else 0
		if best.is_empty() or n < int(best[0]) or (n == int(best[0]) and absf(lane - middle) < absf(int(best[1]) - middle)):
			best = [n, lane]
	var lane: int = int(best[1])
	var enemies: Array[Dictionary] = []
	for i: int in going.enemies.size():
		if enemy_mark[i] == 1 or (enemy_mark[i] == 2 and _near_jar(going.enemy_lane[i], going.enemy_floor[i], lane, own,
				beside)):
			enemies.append(going.enemies[i])
	var fences: Array[Dictionary] = []
	for i: int in going.fences.size():
		var at: float = going.fence_at[i]
		if fence_mark[i] == 1 or (fence_mark[i] == 2 and _near_jar(going.fence_lane[i], Vector2(at - half, at + half), lane,
				own, beside)):
			fences.append(going.fences[i])
	var gaps: Array[Dictionary] = []
	for i: int in going.gaps.size():
		if gap_mark[i] == 1 or (gap_mark[i] == 2 and _near_jar(going.gap_lane[i], going.gap_span[i], lane, own, beside)):
			gaps.append(going.gaps[i])
	return [int(best[0]), lane, {"enemies": enemies, "hulls": hulls, "fences": fences, "gaps": gaps}]


## True if what stands in lane `l` over `span` is in the way of a jar in `lane` (_in_way): in its lane within `own`, or in
## a lane beside it within `beside`.
static func _near_jar(l: int, span: Vector2, lane: int, own: Vector2, beside: Vector2) -> bool:
	return (l == lane and span.x <= own.y and span.y >= own.x) \
		or (absi(l - lane) == 1 and span.x <= beside.y and span.y >= beside.x)


## The layout's lists that making room changes, as they are (shallow copies: the entries stay the same dictionaries).
static func _save(lay: LevelLayout) -> Dictionary:
	return {"enemies": lay.enemies.duplicate(), "hulls": lay.hulls.duplicate(), "pads": lay.pads.duplicate(),
		"credits": lay.credits.duplicate(), "fences": lay.fences.duplicate(), "gaps": lay.gaps.duplicate()}


## Puts back the lists `saved` (_save) holds.
static func _restore(lay: LevelLayout, saved: Dictionary) -> void:
	lay.enemies.assign(saved["enemies"])
	lay.hulls.assign(saved["hulls"])
	lay.pads.assign(saved["pads"])
	lay.credits.assign(saved["credits"])
	lay.fences.assign(saved["fences"])
	lay.gaps.assign(saved["gaps"])


## Takes `items` ({enemies, hulls, fences, gaps}) out of `gen`'s layout: each ceiling with its pads and the credits on it.
static func _strip(gen: LevelGenerator, items: Dictionary) -> void:
	var lay: LevelLayout = gen.layout
	var hulls: Array[Dictionary] = []
	hulls.assign(items["hulls"])
	var pads: Array[Dictionary] = []
	for h: Dictionary in hulls:
		pads.append_array(_pads_of(lay, h))
	if not hulls.is_empty():
		_keep(lay.credits, func(c: Dictionary) -> bool:
			if String(c.get("surface", "")) != "ceiling":
				return true
			for h: Dictionary in hulls:
				var lanes: Vector2i = lay.hull_lanes(h)
				if float(c["at"]) >= float(h["start"]) and float(c["at"]) <= float(h["end"]) \
						and int(c.get("lane", -1)) >= lanes.x and int(c.get("lane", -1)) <= lanes.y:
					return false
			return true)
	_drop(lay.hulls, hulls)
	_drop(lay.pads, pads)
	_drop(lay.enemies, items["enemies"])
	_drop(lay.fences, items["fences"])
	_drop(lay.gaps, items["gaps"])


## Takes every entry of `going` (the very dictionaries) out of `list`, in place, so typed arrays stay typed.
static func _drop(list: Array[Dictionary], going: Array) -> void:
	if going.is_empty():
		return
	_keep(list, func(x: Dictionary) -> bool:
		for g: Variant in going:
			if is_same(g, x):
				return false
		return true)


## Keeps the items of `list` for which `keep` returns true (in place, so typed arrays stay typed).
static func _keep(list: Array[Dictionary], keep: Callable) -> void:
	var kept: Array[Dictionary] = []
	for item: Dictionary in list:
		if keep.call(item):
			kept.append(item)
	list.assign(kept)


## Each of the level's features (but this one) with its count of positions (LevelGenerator.feature_positions), and the
## first position of each the level gives a start (INF where it has none): making room keeps both (_features_kept).
static func _feature_counts(gen: LevelGenerator) -> Dictionary:
	var counts: Dictionary = {}
	var firsts: Dictionary = {}
	for f: String in gen.config.features:
		if f == FEATURE:
			continue
		var at: Array[float] = LevelGenerator.feature_positions(gen.layout, f)
		counts[f] = at.size()
		if gen.config.feature_starts.has(f):
			firsts[f] = at[0] if not at.is_empty() else INF
	return {"counts": counts, "firsts": firsts}


## True if every feature that had something in the layout (`before`: _feature_counts) still has, and the first of each
## the level introduces is where it was.
static func _features_kept(gen: LevelGenerator, before: Dictionary) -> bool:
	var now: Dictionary = _feature_counts(gen)
	for f: String in (before["counts"] as Dictionary):
		if int(before["counts"][f]) > 0 and int((now["counts"] as Dictionary).get(f, 0)) == 0:
			return false
	for f: String in (before["firsts"] as Dictionary):
		var was: float = float(before["firsts"][f])
		var is_now: float = float((now["firsts"] as Dictionary).get(f, INF))
		if not (is_inf(was) and is_inf(is_now)) and not is_equal_approx(was, is_now):
			return false
	return true


## Stands jar `spot` (_best) in the layout, the `index`th of the level's jars, with the dog it holds at its front, its
## plan in its params.
static func _place(plan: Plan, spot: Dictionary, index: int) -> void:
	var gen: LevelGenerator = plan.gen
	var j: float = float(spot["front"])
	var lane: int = int(spot["lane"])
	var jar := {"lane": lane, "start": j, "end": j + plan.length, "size": JAR_SIZE, "side": int(spot["side"]),
		"seed": hash([gen.config.level_seed, FEATURE, index]), LevelLayout.HOLDS: TYPE}
	gen.layout.doodads.append(jar)
	var anchors: Array[float] = spot["anchors"]
	gen.add_enemy(TYPE, j, lane, 0, {LevelLayout.HELD: true, "doghouse": false, "charges": anchors.size(),
		"charge_at": anchors, "floor_span": spot["span"]})
	refresh(plan)


## Every jar holding an Octodog in `layout`: its front (LevelGenerator.feature_positions: the every-feature check).
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
	var gap: float = gen.metres(DOG_GAP)
	var most: int = maxi(t.charges_range(scaling).y, MIN_CHARGES)
	var keeps: Array[Vector2] = []
	for k: Dictionary in gen.rules_doodad_keep_outs():
		keeps.append(Vector2(float(k["from"]), float(k["to"])))
	var chases: Array[Vector2] = HostRules.chase_stretches(gen)
	chases.append_array(gen.extended_wall_run_reserve)
	var zones: Array[Vector2] = _ceiling_zones(gen)
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
		# An inner lane pushing to a side, or an outermost one (by an open side wall, LayoutChecks.check_doodads) pushing
		# inward.
		var side: int = int(d["side"])
		var inward: int = 1 if lane == 0 else (-1 if lane == lay.lane_count - 1 else 0)
		if lane < 0 or lane >= lay.lane_count or absi(side) != 1 or (inward != 0 and side != inward) \
				or StringName(d["size"]) != JAR_SIZE or absf(float(d["end"]) - j - gen.tuning.doodad_size(JAR_SIZE).z) > 0.01 \
				or d.has("row"):
			out.append("%s: not one small doodad in a lane, pushing to a side (inward by a wall)" % tag)
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
		if anchors.size() > most:
			out.append("%s: its dog makes %d charges (%d at most)" % [tag, anchors.size(), most])
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
				or _hits(zones, loose, run.y):
			out.append("%s: its dog's run meets an anti-grav pad or a ceiling's landing" % tag)
		for s: Vector2 in chases:
			if s.x <= last + window + stop and s.y >= loose:
				out.append("%s: its dog's run meets a Bad Dream's chase or a kept wall run (%.1f-%.1f m)" % [tag, s.x, s.y])
		# Its run never in what a rule keeps, in any lane (a falling gantryway's calm stretch and lane, a teleporter's way
		# around, pad stretch and landings, a wall-run gap's clear stretch, a treasure stash's floor).
		for k: Vector2 in keeps:
			if k.x <= run.y and k.y >= loose:
				out.append("%s: what a rule keeps (%.1f-%.1f m) reaches its dog's run (%.1f-%.1f m)" % [tag, k.x, k.y, loose,
					run.y])
		var mine: Vector2 = busy_of(gen, dog, before, stop)
		for e: Dictionary in lay.enemies:
			if is_same(e, dog) or String(e.get("type", "")) != TYPE:
				continue
			var o: Vector2 = busy_of(gen, e, before, stop)
			if o.y >= o.x and o.x <= mine.y + gap and o.y + gap >= mine.x:
				out.append("%s: its dog's run (%.1f-%.1f m) too near another Octodog's (%.1f-%.1f m)" % [tag, mine.x, mine.y,
					o.x, o.y])
	return out
