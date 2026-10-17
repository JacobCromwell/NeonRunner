extends SceneTree
## Measures what shares the screen with each Buzz Overdrive (task L2; the owner, October 17, 2026: "the algorithm
## that generates levels seems very hesitant to put other enemies on the screen at the same time as the Buzz
## Overdrive"; BuzzCompanyPlacement). From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless -s res://tools/measure/buzz_company.gd -- [options]
## Options:
##   --levels=corporate/1,golden/2   campaign steps (default: every level that lists the Buzz Overdrive; `all`: every
##                                   campaign level, for --dump)
##   --lanes=3,5,6                   lane counts (default 3,5,6)
##   --seeds=N                       each level's own seed and N others, 9001 to 9000 + N (default 4)
##   --company=off                   build every level with LevelConfig.buzz_company off (as before task L2)
##   --company-set=key:value;...     set BuzzCompanyTuning properties (numbers; 0 and 1 for switches) before building,
##                                   e.g. --company-set=cyborgs_max:2;rows_max:3, to try values before the data file
##   --out=build/measure/x.json      also write every tank's numbers there
##   --dump=FILE                     also write every layout (LevelLayout.to_dict) there as JSON, keyed
##                                   "<level> lanes=<n> seed=<s>" as tools/measure/level_pace.gd keys its own
##   --tanks                         also print a line for every tank
## A tank's visit is the stretch of the runner's distance from where it comes into view (parked in its lane
## appear_distance ahead) to where its cut has run past the runner and it's gone (BuzzCompanyPlacement.visit_of); its
## attack, from its rev (the warning, FloorCutPlan.warn_at) to the same end. What the runner meets meanwhile, by where
## it stands on the track (the runner passes it during the visit):
## - enemies but the tank itself and Enforcer Trucks (which drive behind the runner), each over its activity as
##   tools/measure/level_pace.gd counts it (a cyborg 2 s before its spot, an Octodog over its charges' floor, a
##   drone wave until its first pad, a hover truck for its shortest stay, a Resonator over its pulses); a cyborg
##   planted in the tank's own charge path (task G7) is counted apart ("planted");
## - floor rows (a spot holding holes or fences, a wall-run gap's holes left out) and signs; wall fences; zone
##   doodads; dash walls.
## Threats are the enemies, rows, signs and wall fences. Each tank is in one group: "truck" (an Enforcer Truck's chase
## comes within the company's truck_margin_seconds of its visit), "intro" (the level's introduction of it), "parked"
## (a cyborg planted in its charge's path), or "other" (every other: the ones BuzzCompanyPlacement gives company; with
## it on, "company" says how many of them got some). Per level (over its lane counts and seeds) it prints the tanks
## and how many are in each group, the visits' mean seconds, threats per second in all visits and in the rest of the
## level (between its run-up and its end-clear stretch, outside every visit), and for the "other" tanks: threats per
## second in their visits and in their attacks, the share of their visits with another enemy, a floor row and a wall
## fence, and the mean longest stretch of their visits with no threat at all (seconds).

const Rules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const TruckRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const TUNING_PATH: String = "res://data/tuning/movement.tres"
## Seconds before its spot an enemy counts as going on (level_pace.gd's).
const ENEMY_LEAD_SECONDS: Dictionary = {"cyborg": 2.0, "window_cyborg": 2.0, "screech": 1.6, "generator": 0.0}
## The truck margin when the company pass isn't there to say (BuzzCompanyTuning.truck_margin_seconds).
const TRUCK_MARGIN_SECONDS: float = 2.0

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 4
var _out: String = ""
var _dump: String = ""
var _print_tanks: bool = false
var _company_off: bool = false
## The company tuning --company-set changed: held so the resource cache keeps it.
var _kept_tuning: Resource = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var tuning := load(TUNING_PATH) as MovementTuning
	var all_levels: bool = _levels.size() == 1 and _levels[0] == "all"
	if _levels.is_empty() or all_levels:
		_levels.clear()
		for s: CampaignStep in campaign.steps():
			if s.is_level() and not s.is_minigame() and (all_levels or s.level.has_feature(Rules.TYPE)):
				_levels.append(s.id)
	var started: int = Time.get_ticks_msec()
	var all: Array[Dictionary] = []
	var levels_out: Dictionary = {}
	var dump: Dictionary = {}
	print("%-13s %5s %5s %5s %5s %5s %5s | %5s | thr/s: %5s %5s || other: %5s %5s %5s | share: %4s %4s %4s | empty %5s" % [
		"level", "tanks", "truck", "intro", "park", "other", "comp", "visit", "visit", "rest", "visit", "atk", "", "enem",
		"row", "wfen", "s"])
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level() or step.is_minigame():
			print("%s: not a campaign level" % id)
			continue
		var tanks: Array[Dictionary] = []
		var rest: Vector2 = Vector2.ZERO
		for lanes: int in _lanes:
			for k: int in _seeds + 1:
				var config: LevelConfig = campaign.configure(step, lanes)
				if k > 0:
					config.level_seed = 9000 + k
				if _company_off and "buzz_company" in config:
					config.set("buzz_company", false)
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
				if _dump != "":
					dump["%s lanes=%d seed=%d" % [id, lanes, config.level_seed]] = layout.to_dict()
				if not config.has_feature(Rules.TYPE):
					continue
				var found: Dictionary = measure(gen, layout, config)
				for tank: Dictionary in found["tanks"]:
					tank["level"] = id
					tank["lanes"] = lanes
					tank["seed"] = config.level_seed
					tanks.append(tank)
					if _print_tanks:
						print("  %s lanes=%d seed=%d lane %d warn %.0f visit %.0f-%.0f (%.1f s) %s%s: %s" % [id, lanes,
							config.level_seed, int(tank["lane"]), float(tank["warn"]), float(tank["visit_from"]),
							float(tank["visit_to"]), float(tank["visit_s"]), String(tank["group"]),
							" (company, escape %d)" % int(tank["escape"]) if bool(tank["company"]) else "",
							JSON.stringify(tank["visit"])])
				rest += found["rest"]
		all.append_array(tanks)
		if not tanks.is_empty():
			levels_out[id] = _print_level(id, tanks, rest)
	print("measured in %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
		var file := FileAccess.open(_out, FileAccess.WRITE)
		file.store_string(JSON.stringify({"levels": levels_out, "tanks": all}, "\t"))
		file.close()
		print("wrote %s" % _out)
	if _dump != "":
		DirAccess.make_dir_recursive_absolute(_dump.get_base_dir())
		var file := FileAccess.open(_dump, FileAccess.WRITE)
		file.store_string(JSON.stringify(dump, "", true, true))
		file.close()
		print("wrote %d layouts to %s" % [dump.size(), _dump])
	quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			_levels = value.split(",", false)
		elif arg.begins_with("--lanes="):
			_lanes.clear()
			for v: String in value.split(",", false):
				_lanes.append(int(v))
		elif arg.begins_with("--seeds="):
			_seeds = int(value)
		elif arg.begins_with("--out="):
			_out = value
		elif arg.begins_with("--dump="):
			_dump = value
		elif arg == "--company=off":
			_company_off = true
		elif arg.begins_with("--company-set=") and ResourceLoader.exists("res://data/tuning/buzz_company.tres"):
			# The live resource (cached: the pass loads the same one).
			var company: Resource = load("res://data/tuning/buzz_company.tres")
			for pair: String in arg.trim_prefix("--company-set=").split(";", false):
				var key: String = pair.get_slice(":", 0)
				var number: float = float(pair.get_slice(":", 1))
				match typeof(company.get(key)):
					TYPE_BOOL:
						company.set(key, number != 0.0)
					TYPE_INT:
						company.set(key, int(number))
					_:
						company.set(key, number)
				_kept_tuning = company
		elif arg == "--tanks":
			_print_tanks = true


## One layout's tanks: {"tanks": [{lane, warn, visit_from, visit_to, visit_s, attack_s, group, company, escape, visit,
## attack, empty_s}], "rest": Vector2(threats, seconds) outside every visit}.
static func measure(gen: LevelGenerator, layout: LevelLayout, config: LevelConfig) -> Dictionary:
	var bt: BuzzOverdriveTuning = Rules.tuning()
	var speed: float = gen.speed
	var from: float = config.start_clear_distance
	var to: float = layout.length - config.end_clear_distance
	var threats: Array[Dictionary] = threats_in(gen, layout, config)
	var out: Array[Dictionary] = []
	var visits: Array[Vector2] = []
	var tanks: Array[Dictionary] = Rules.tanks_in(layout)
	for i: int in tanks.size():
		var e: Dictionary = tanks[i]
		var cut: Dictionary = Rules.cut_of(layout, e)
		if cut.is_empty():
			continue
		var parked: bool = bool(cut.get("park", false))
		var appear: float = (float(cut["end"]) if parked else FloorCutPlan.lead_at(cut) + float(cut["charge"])) \
			- bt.appear_distance
		var visit := Vector2(maxf(appear, 0.0), FloorCutPlan.done_at(cut, speed))
		var attack := Vector2(FloorCutPlan.warn_at(cut), visit.y)
		visits.append(visit)
		var group: String = "other"
		if _truck_near(gen, layout, visit):
			group = "truck"
		elif i == 0 and int(config.feature_ages.get(Rules.TYPE, -1)) == 0:
			group = "intro"
		elif parked:
			group = "parked"
		out.append({"lane": int(e["lane"]), "warn": attack.x, "visit_from": visit.x, "visit_to": visit.y,
			"visit_s": (visit.y - visit.x) / speed, "attack_s": (attack.y - attack.x) / speed, "group": group,
			"company": cut.has("company"), "escape": int(cut.get("company", -1)),
			"visit": _count(threats, visit), "attack": _count(threats, attack),
			"empty_s": _longest_empty(threats, visit) / speed})
	# The rest of the level, outside every visit.
	var rest_threats: int = 0
	for th: Dictionary in threats:
		var span: Vector2 = th["span"]
		if span.y < from or span.x > to or not (String(th["kind"]) in ["enemy", "row", "sign", "wall_fence"]):
			continue
		var inside: bool = false
		for v: Vector2 in visits:
			inside = inside or (span.x <= v.y and span.y >= v.x)
		if not inside:
			rest_threats += 1
	var rest_m: float = to - from
	for v: Vector2 in _merged(visits):
		rest_m -= maxf(minf(v.y, to) - maxf(v.x, from), 0.0)
	return {"tanks": out, "rest": Vector2(rest_threats, maxf(rest_m, 0.0) / speed)}


## True if an Enforcer Truck's chase comes within the company's truck margin of `visit` (BuzzCompanyPlacement
## .truck_near, which says the same before the pass existed).
static func _truck_near(gen: LevelGenerator, layout: LevelLayout, visit: Vector2) -> bool:
	var margin: float = TRUCK_MARGIN_SECONDS * gen.speed
	if ResourceLoader.exists("res://data/tuning/buzz_company.tres"):
		margin = float(load("res://data/tuning/buzz_company.tres").get("truck_margin_seconds")) * gen.speed
	var tt: EnforcerTruckTuning = TruckRules.tuning()
	for truck: Dictionary in TruckRules.trucks_in(layout):
		var chase: Vector2 = TruckRules.chase_span(gen, tt, float(truck["at"]))
		if chase.x - margin <= visit.y and chase.y + margin >= visit.x:
			return true
	return false


## Every threat in `layout` and the scenery that goes with them: [{kind, type, span, lanes}]. kind: "enemy",
## "row", "sign", "wall_fence", "doodad", "dash_wall". Enemies but Buzz Overdrives and Enforcer Trucks.
static func threats_in(gen: LevelGenerator, layout: LevelLayout, config: LevelConfig) -> Array[Dictionary]:
	var speed: float = gen.speed
	var t: MovementTuning = gen.tuning
	var out: Array[Dictionary] = []
	var rows: Dictionary = {}
	for g: Dictionary in layout.gaps:
		if LevelLayout.is_wall_run_hole(g):
			continue
		var key: String = "%.1f" % float(g["start"])
		if not rows.has(key):
			rows[key] = {"kind": "row", "type": "holes", "span": Vector2(float(g["start"]), float(g["end"])), "lanes": []}
		(rows[key]["lanes"] as Array).append(int(g["lane"]))
	for f: Dictionary in layout.fences:
		var key: String = "%.1f" % float(f["at"])
		if not rows.has(key):
			rows[key] = {"kind": "row", "type": "fences", "span": Vector2(float(f["at"]) - t.fence_depth * 0.5,
				float(f["at"]) + t.fence_depth * 0.5), "lanes": []}
		(rows[key]["lanes"] as Array).append(int(f["lane"]))
	for r: Dictionary in rows.values():
		out.append(r)
	for s: Dictionary in layout.signs:
		out.append({"kind": "sign", "type": "sign", "span": Vector2(float(s["start"]), float(s["end"]))})
	for w: Dictionary in layout.wall_fences:
		out.append({"kind": "wall_fence", "type": String(w.get("band", "full")), "span": Vector2(float(w["at"]), float(w["at"]))})
	for d: Dictionary in layout.doodads:
		out.append({"kind": "doodad", "type": String(d.get("size", "")), "span": Vector2(float(d["start"]), float(d["end"]))})
	for w: Dictionary in layout.dash_walls:
		out.append({"kind": "dash_wall", "type": "dash_wall", "span": Vector2(float(w["start"]), float(w["end"]))})
	var pads: Array[float] = []
	for p: Dictionary in layout.pads:
		pads.append(float(p["at"]))
	pads.sort()
	for e: Dictionary in layout.enemies:
		var type: String = String(e.get("type", ""))
		if type == Rules.TYPE or type == TruckRules.TYPE:
			continue
		var at: float = float(e["at"])
		var params: Dictionary = e.get("params", {})
		var span := Vector2(at, at)
		match type:
			"octodog":
				var fs: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
				span = fs if fs.y >= fs.x else span
			"resonator":
				var rt := EnemyDirector.tuning_for("resonator") as ResonatorTuning
				var pulses: Array = params.get("pulse_at", [])
				if not pulses.is_empty():
					span = Vector2(float(pulses[0]), float(pulses[-1]) + rt.meet_offset(speed, config.enemy_scaling, gen.pace))
			"drone":
				var first: float = at
				for p: float in pads:
					if p > at + 0.01:
						first = p
						break
				span = Vector2(at, first)
			"hover_truck":
				var ht := EnemyDirector.tuning_for("hover_truck") as HoverTruckTuning
				span = Vector2(at, at + ht.stay_min_seconds * speed)
			_:
				span = Vector2(at - float(ENEMY_LEAD_SECONDS.get(type, 0.0)) * speed, at)
		var planted: bool = String(params.get("charge_path", "")) == Rules.TYPE
		out.append({"kind": "enemy", "type": "planted" if planted else type, "span": span})
	return out


## What of `threats` reaches into `span`: {enemies: {type: n}, enemy, planted, rows, row_pieces, signs, wall_fences,
## doodads, dash_walls, threats}. A planted cyborg is counted under "planted" (not in `enemy`).
static func _count(threats: Array[Dictionary], span: Vector2) -> Dictionary:
	var by_type: Dictionary = {}
	var c := {"enemy": 0, "planted": 0, "rows": 0, "row_pieces": 0, "signs": 0, "wall_fences": 0, "doodads": 0,
		"dash_walls": 0}
	for th: Dictionary in threats:
		var s: Vector2 = th["span"]
		if s.x > span.y or s.y < span.x:
			continue
		match String(th["kind"]):
			"enemy":
				var type: String = th["type"]
				by_type[type] = int(by_type.get(type, 0)) + 1
				if type == "planted":
					c["planted"] += 1
				else:
					c["enemy"] += 1
			"row":
				c["rows"] += 1
				c["row_pieces"] += (th["lanes"] as Array).size()
			"sign":
				c["signs"] += 1
			"wall_fence":
				c["wall_fences"] += 1
			"doodad":
				c["doodads"] += 1
			"dash_wall":
				c["dash_walls"] += 1
	c["enemies"] = by_type
	c["threats"] = int(c["enemy"]) + int(c["rows"]) + int(c["signs"]) + int(c["wall_fences"])
	return c


## The longest stretch of `span` (metres) that no threat (enemy, row, sign, wall fence) reaches.
static func _longest_empty(threats: Array[Dictionary], span: Vector2) -> float:
	var busy: Array[Vector2] = []
	for th: Dictionary in threats:
		if String(th["kind"]) in ["enemy", "row", "sign", "wall_fence"]:
			busy.append(th["span"])
	var longest: float = 0.0
	for free: Vector2 in LevelGenerator.free_stretches(busy, span.x, span.y):
		longest = maxf(longest, free.y - free.x)
	return longest


static func _merged(spans: Array[Vector2]) -> Array[Vector2]:
	var sorted: Array[Vector2] = spans.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array[Vector2] = []
	for s: Vector2 in sorted:
		if not out.is_empty() and s.x <= out[-1].y:
			out[-1].y = maxf(out[-1].y, s.y)
		else:
			out.append(s)
	return out


func _print_level(id: String, tanks: Array[Dictionary], rest: Vector2) -> Dictionary:
	var row: Dictionary = _summary(tanks)
	var groups: Dictionary = {"truck": 0, "intro": 0, "parked": 0, "other": 0}
	var other: Array[Dictionary] = []
	var company: int = 0
	for tank: Dictionary in tanks:
		groups[tank["group"]] = int(groups[tank["group"]]) + 1
		if String(tank["group"]) == "other":
			other.append(tank)
		if bool(tank["company"]):
			company += 1
	var o: Dictionary = _summary(other)
	var rest_rate: float = rest.x / maxf(rest.y, 0.001)
	print("%-13s %5d %5d %5d %5d %5d %5d | %5.1f | thr/s: %5.2f %5.2f || other: %5.2f %5.2f %5s | share: %4.0f %4.0f %4.0f | empty %5.1f" % [
		id, tanks.size(), groups["truck"], groups["intro"], groups["parked"], groups["other"], company, row["visit_s"],
		row["visit_rate"], rest_rate, o["visit_rate"], o["attack_rate"], "", o["with_enemy"], o["with_row"],
		o["with_wall_fence"], o["empty_s"]])
	row["rest_rate"] = rest_rate
	row["groups"] = groups
	row["company"] = company
	row["other"] = o
	return row


## Means over `tanks`: visit_s, visit_rate and attack_rate (threats per second), with_enemy, with_row and
## with_wall_fence (% of visits), empty_s, and the visits' enemies by type and their rows, pieces and wall fences (per
## visit).
static func _summary(tanks: Array[Dictionary]) -> Dictionary:
	var n: float = maxf(tanks.size(), 1.0)
	var visit_s: float = 0.0
	var attack_s: float = 0.0
	var visit_threats: float = 0.0
	var attack_threats: float = 0.0
	var with_enemy: float = 0.0
	var with_row: float = 0.0
	var with_wf: float = 0.0
	var empty_s: float = 0.0
	var types: Dictionary = {}
	var per: Dictionary = {"rows": 0.0, "row_pieces": 0.0, "wall_fences": 0.0, "enemy": 0.0}
	for tank: Dictionary in tanks:
		var v: Dictionary = tank["visit"]
		visit_s += float(tank["visit_s"])
		attack_s += float(tank["attack_s"])
		visit_threats += float(v["threats"])
		attack_threats += float(tank["attack"]["threats"])
		with_enemy += 1.0 if int(v["enemy"]) > 0 else 0.0
		with_row += 1.0 if int(v["rows"]) > 0 else 0.0
		with_wf += 1.0 if int(v["wall_fences"]) > 0 else 0.0
		empty_s += float(tank["empty_s"])
		for type: String in v["enemies"]:
			types[type] = float(types.get(type, 0.0)) + float(v["enemies"][type]) / n
		for key: String in per:
			per[key] = float(per[key]) + float(v[key]) / n
	return {"tanks": tanks.size(), "visit_s": visit_s / n, "visit_rate": visit_threats / maxf(visit_s, 0.001),
		"attack_rate": attack_threats / maxf(attack_s, 0.001), "with_enemy": 100.0 * with_enemy / n,
		"with_row": 100.0 * with_row / n, "with_wall_fence": 100.0 * with_wf / n, "empty_s": empty_s / n,
		"types": types, "per_visit": per}
