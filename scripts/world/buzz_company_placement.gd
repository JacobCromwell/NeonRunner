class_name BuzzCompanyPlacement
extends RefCounted
## Company for a Buzz Overdrive (task L2; the owner, October 17, 2026, docs/USER_REQUESTS.md: "the algorithm that
## generates levels seems very hesitant to put other enemies on the screen at the same time as the Buzz Overdrive
## ... unless this is done for performance, I'd like other enemies, such as some cyborgs, maybe an Octodog, or extra
## gaps or laser fences, on the playfield at the same time as Buzz Overdrive enemies"; numbers: BuzzCompanyTuning,
## data/tuning/buzz_company.tres). Why its stretch was empty (tools/measure/buzz_company.gd): its pattern holds its
## whole encounter (data/patterns/buzz_overdrive.json: 200 m at the reference speed, about 11 s), and every pass
## after the rules keeps its cut's whole window (FloorCutPlan.window: from where it sets off to the cut's end, about
## 9 s) clear in every lane: the fill pass and the danger density pass (task B4's placeholder, "nothing else goes on
## during a cut"), the zone doodads and the wall fences (B5's, "one thing at a time"). None of it is there for
## performance. In a level that asks for it (LevelConfig.buzz_company: every campaign level with the Buzz Overdrive),
## LevelGenerator runs place() after the danger density pass's floor pieces and before the zone doodads, from a stream
## of its own: every pass before it measures and fills the level as it would without it, and the doodads, the wall
## fences, the wall gaps and the credits keep off what it adds.
##
## Which tanks (company_problem): a level's tank (not a boss's, whose cut has no lead) whose visit, from where it comes
## into view to where it's gone (visit_of), comes no nearer than truck_margin_seconds to an Enforcer Truck's chase (the
## owner: where one is likely on the map with it, sparse is fine), and not the level's introduction of it (Corporate
## 1's first, met alone after its hint; on_introduction). One parked for a cyborg in its charge's path (task G7) has
## company too, out of its lane, where the charge flattens that cyborg.
##
## Where, keyed to the runner's distance (C: its cut's lane), from where it sets off (FloorCutPlan.lead_at) to the end
## of its cut's window (stretch_of):
## - its roll, until attack_margin_seconds before its warning (attack_of): company in every lane but C, which its lane
##   window keeps clear anyway;
## - its attack, from there to the window's end: company in every lane but C and its escape lane E, a neighbour of C
##   clear of everything over the whole attack (lane_clear; recorded on the cut as CUT_KEY, -1 where neither
##   neighbour is clear, and then nothing goes in the attack), so a runner in C when the rev starts leaves into E and
##   runs on in E whatever the other lanes hold; holes only in the lanes GDD §9.9's whole lanes allow (none on 3
##   lanes; LevelConfig.cut_holes_beside lanes at 5 and 6, never C's neighbours).
## After each addition the cut must still keep what company could take from it (_cut_ok: its lane clear over its lane
## window, its whole lanes, room to leave its lane, LevelGenerator.cut_escape_clear, and E clear); nothing else
## LevelGenerator.cut_problem asks of it can change (company adds no ramp, pad, ceiling, cut or wall fence, and its
## cyborgs are the one exception to "nothing else goes on", cut_problem's own).
## What:
## - cyborg encounters (cyborgs_max, each with cyborg_chance: one of the level's plain cyborg patterns, a single or a
##   pair, picked as the pattern pass picks there), by the danger density pass's rules for an enemy it adds
##   (DangerDensity: its attack window, CyborgRules.keep_out and its floor, off the fixed stretches, pads, quiet
##   stretches and plain ceilings, enemy_fixed_stretches, and the rules' calm stretches; with the level's spacing around
##   it, at most overlap_max other attack windows, all of small enemies; its own lane and another free of pieces, kept
##   lanes and floor enemies; never before the level's introduction of cyborgs, _cyborgs_from; the cyborg rules'
##   margin from every piece and off every ceiling's safe floor): plain floor cyborgs, never a host, never the panic
##   variant (a panic run could carry one into E), holding their fire from hold_before_seconds before the warning to
##   hold_after_seconds past the window (no bolt of theirs lands meanwhile: Cyborg.hold_fire, as a cyborg in a
##   charge's path holds it). One whose floor reaches the attack stands only in a lane beside E (cyborgs_in_attack), so
##   a runner beside it can always step into E; the others before it, in any lane but C. Their params carry PARAM
##   (their tank's cut's end).
## - rows of holes or fences (rows_max: the level's one-row fillers, picked as the fill pass picks them there), as
##   wide as the filler asks but the lanes above allow, each keeping the fill pass's margin (the level's spacing and a
##   pattern's tail, times spacing_scale) from everything the fill pass keeps off (LevelGenerator.fill_keep_outs,
##   without this tank's own window) and from what the rules keep in every lane, out of what the rules keep in a lane (a
##   hover truck's), a lane left free beside it, and before the end-clear stretch. The pieces get no risky credit
##   (LevelGenerator.uncredited), as the danger density pass's don't, and carry PARAM (their tank's cut's end).
## - Wall fences: WallFencePlacement lets them run by a tank with company, keeping their drop rule (the outer lane
##   beside one clear to drop into, C's lane window too), so the walls carry their usual share there.
## No Octodog: its charges and the tank's are both big attacks that take turns (GDD §9), its charge sequence (3 or 4
## charges, 9 to 13 s at the Corporate zone's pace) is longer than the tank is in view before it claims its turn
## (about 5.5 s), and the stretch before that is the patterns'. DESIGN-TBD (items 933-941 in docs/OPEN_QUESTIONS*.md).
## Nothing it adds is a big attack, so the tank's turn is as before. With buzz_company off (quick play, the tests, boss
## arenas) or the tuning's `enabled` off, a level is built exactly as before.

const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const TruckRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const DangerDensity = preload("res://scripts/world/danger_density.gd")
const TANK: String = "buzz_overdrive"
const CYBORG: String = "cyborg"
## The cut's key that marks a tank with company: its escape lane (-1: none, and nothing in its attack).
const CUT_KEY: String = "company"
## A company cyborg's params key, and a company hole's or fence's own key: its tank's cut's end (the tank it keeps
## company).
const PARAM: String = "buzz_company"
## Seconds of run between the spots tried for a cyborg encounter, and for a row where one doesn't fit.
const SPOT_STEP_SECONDS: float = 0.25
## Metres either side of a cyborg that keep off the rules' calm stretches too (an Enforcer Truck's showing window: the
## room a floor enemy keeps in its lane, EnforcerTruckRoom.ENEMY_ROOM).
const CALM_ROOM: float = 3.0
## Metres around the escape lane's stretch it keeps clear, and around the attack an addition counts as in it (a lane
## switch's margin, as LevelGenerator.CUT_SWITCH_MARGIN).
const SWITCH_MARGIN: float = 1.0


## What the pass asks of the level again and again, asked once (task L2's review: about a tenth of a long level's
## build went on asking it per spot and lane). The rules' keep-outs (LevelGenerator.rules_doodad_keep_outs: a hover
## truck's lane, a Bad Dream's chase, a Gilded Sentinel's turn, an Enforcer Truck's showing window, a dash wall, a
## stash, a wall-run gap), which nothing the company adds changes, asked once a pass; the cyborg rules' obstacle spans
## and margin (CyborgRules), which only its rows change, asked again for each encounter (_add_encounter).
class Asked:
	extends RefCounted
	## The rules' keep-outs of one lane ({lane, from, to}).
	var lane_keeps: Array[Dictionary] = []
	## The rules' keep-outs of every lane.
	var everywhere: Array[Vector2] = []
	## Those of every lane the rules call calm (an Enforcer Truck's showing window).
	var calm: Array[Vector2] = []
	## CyborgRules.obstacle_spans of the layout as it stands, and a cyborg's obstacle margin (_add_encounter).
	var obstacles: Array[Vector2] = []
	var margin: float = 0.0

	func _init(gen: LevelGenerator) -> void:
		for k: Dictionary in gen.rules_doodad_keep_outs():
			if k.has("lane"):
				lane_keeps.append(k)
				continue
			everywhere.append(Vector2(float(k["from"]), float(k["to"])))
			if bool(k.get("calm", false)):
				calm.append(everywhere[-1])


static func tuning() -> BuzzCompanyTuning:
	return BuzzCompanyTuning.load_default()


## Gives each tank that may have it its company (see the header). Returns its report (LevelGenerator
## .buzz_company_result): {} where the level asks for none; else {tanks: [{at, lane, escape, rows, pieces, cyborgs}],
## skipped: {why: how many}, rows, pieces, cyborgs}.
static func place(gen: LevelGenerator, patterns: Array) -> Dictionary:
	if not gen.config.buzz_company or WallGapPlacement.is_boss_arena(gen.config) or not gen.config.has_feature(TANK):
		return {}
	var t: BuzzCompanyTuning = tuning()
	if not t.enabled:
		return {}
	var rng: RandomNumberGenerator = gen.rng_for(PARAM)
	var asked := Asked.new(gen)
	var made: Array[Dictionary] = []
	var skipped: Dictionary = {}
	var totals := {"rows": 0, "pieces": 0, "cyborgs": 0}
	var tanks: Array[Dictionary] = BuzzRules.tanks_in(gen.layout)
	for i: int in tanks.size():
		var cut: Dictionary = BuzzRules.cut_of(gen.layout, tanks[i])
		var why: String = company_problem(gen, t, cut, i == 0)
		if why != "":
			skipped[why] = int(skipped.get(why, 0)) + 1
			continue
		var one: Dictionary = _keep_company(gen, t, rng, patterns, tanks[i], cut, asked)
		made.append(one)
		for key: String in totals:
			totals[key] = int(totals[key]) + int(one[key])
	return {"tanks": made, "skipped": skipped, "rows": totals["rows"], "pieces": totals["pieces"],
		"cyborgs": totals["cyborgs"]}


## Why the tank whose cut is `cut` gets no company ("" if it may have it): no cut, a cut without a lead (a boss's),
## the level's introduction of it (`first`, in a level whose feature age for it is 0, unless on_introduction), or an
## Enforcer Truck's chase within truck_margin_seconds of its visit. (A tank parked for a cyborg in its charge's path,
## task G7, may: its company keeps out of its lane, where the charge flattens the cyborg.)
static func company_problem(gen: LevelGenerator, t: BuzzCompanyTuning, cut: Dictionary, first: bool) -> String:
	if cut.is_empty():
		return "no cut"
	if not cut.has("lead"):
		return "no lead (a boss's)"
	if first and not t.on_introduction and int(gen.config.feature_ages.get(TANK, -1)) == 0:
		return "the level's introduction"
	if truck_near(gen, t, cut):
		return "an Enforcer Truck about"
	return ""


## True if an Enforcer Truck's chase (EnforcerTruckRules.chase_span: from its arrival until it has dropped back) comes
## within truck_margin_seconds of the visit of the tank whose cut is `cut` (visit_of).
static func truck_near(gen: LevelGenerator, t: BuzzCompanyTuning, cut: Dictionary) -> bool:
	var visit: Vector2 = visit_of(gen, cut)
	var margin: float = t.truck_margin_seconds * gen.speed
	var tt: EnforcerTruckTuning = TruckRules.tuning()
	for truck: Dictionary in TruckRules.trucks_in(gen.layout):
		var chase: Vector2 = TruckRules.chase_span(gen, tt, float(truck["at"]))
		if chase.x - margin <= visit.y and chase.y + margin >= visit.x:
			return true
	return false


## Where the runner is while the tank whose cut is `cut` is about: from where it comes into view (parked in its lane
## appear_distance ahead: a charge's distance past where it sets off, or its cut's end for a parked one) to where its
## cut has run past them to its start and it's gone (FloorCutPlan.done_at).
static func visit_of(gen: LevelGenerator, cut: Dictionary) -> Vector2:
	var parked: float = float(cut["end"]) if bool(cut.get("park", false)) \
		else FloorCutPlan.lead_at(cut) + float(cut["charge"])
	return Vector2(parked - BuzzRules.tuning().appear_distance, FloorCutPlan.done_at(cut, gen.speed))


## The tank's attack as its company keeps it (see the header): from attack_margin_seconds before its warning to the
## end of its cut's window (FloorCutPlan.window).
static func attack_of(gen: LevelGenerator, t: BuzzCompanyTuning, cut: Dictionary) -> Vector2:
	return Vector2(FloorCutPlan.warn_at(cut) - t.attack_margin_seconds * gen.speed, FloorCutPlan.window(cut, gen.speed).y)


## The stretch a tank's company comes in: from where it sets off to the end of its attack (attack_of).
static func stretch_of(gen: LevelGenerator, t: BuzzCompanyTuning, cut: Dictionary) -> Vector2:
	return Vector2(FloorCutPlan.lead_at(cut), attack_of(gen, t, cut).y)


## The stretch company cyborgs of the tank whose cut is `cut` hold their fire over (Cyborg.hold_fire): from
## hold_before_seconds before its warning to hold_after_seconds past its cut's window.
static func hold_of(gen: LevelGenerator, t: BuzzCompanyTuning, cut: Dictionary) -> Vector2:
	return Vector2(FloorCutPlan.warn_at(cut) - t.hold_before_seconds * gen.speed,
		FloorCutPlan.window(cut, gen.speed).y + t.hold_after_seconds * gen.speed)


## True if floor lane `lane` holds nothing over `span` (SWITCH_MARGIN wider) that a runner switching into it or
## running on in it meets: no hole, fence, pad, speed pad, ramp, zone doodad or other floor cut
## (LevelGenerator._lane_busy), no floor enemy's stretch but the tank `tank`'s own, and no lane a rule keeps (a hover
## truck's). An escape lane must be (see the header). `asked`: the pass's (Asked), else the level is asked.
static func lane_clear(gen: LevelGenerator, lane: int, span: Vector2, tank: Dictionary = {},
		asked: Asked = null) -> bool:
	var a: float = span.x - SWITCH_MARGIN
	var b: float = span.y + SWITCH_MARGIN
	for s: Vector2 in gen._lane_busy(gen.layout, lane):
		if s.x <= b and s.y >= a:
			return false
	for e: Dictionary in gen.layout.enemies:
		if is_same(e, tank) or int(e.get("side", 0)) != 0 or int(e.get("lane", -1)) != lane:
			continue
		var fs: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
		if fs.y >= fs.x and fs.x <= b and fs.y >= a:
			return false
	return not _lane_kept(gen, lane, Vector2(a, b), asked)


## Every cyborg the pass gave company to the tank whose cut is `cut`, along the track.
static func cyborgs_of(layout: LevelLayout, cut: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		var params: Dictionary = e.get("params", {})
		if String(e.get("type", "")) == CYBORG and params.has(PARAM) \
				and absf(float(params[PARAM]) - float(cut["end"])) < 0.01:
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## Every hole and fence the pass gave the tank whose cut is `cut` (their own PARAM key), holes first.
static func pieces_of(layout: LevelLayout, cut: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for list: Array[Dictionary] in [layout.gaps, layout.fences]:
		for piece: Dictionary in list:
			if piece.has(PARAM) and absf(float(piece[PARAM]) - float(cut["end"])) < 0.01:
				out.append(piece)
	return out


## True if enemy entry `e` keeps a tank company (PARAM).
static func is_company(e: Dictionary) -> bool:
	return (e.get("params", {}) as Dictionary).has(PARAM)


# --- One tank's company --------------------------------------------------------------------------------------------

static func _keep_company(gen: LevelGenerator, t: BuzzCompanyTuning, rng: RandomNumberGenerator, patterns: Array,
		tank: Dictionary, cut: Dictionary, asked: Asked) -> Dictionary:
	var attack: Vector2 = attack_of(gen, t, cut)
	var escape: int = _escape_lane(gen, rng, cut, attack, tank, asked)
	cut[CUT_KEY] = escape
	var made := {"at": float(tank["at"]), "lane": int(cut["lane"]), "escape": escape, "rows": 0, "pieces": 0,
		"cyborgs": 0}
	var fixed: Array[Vector2] = DangerDensity.enemy_fixed_stretches(gen, patterns, cut)
	for k: int in t.cyborgs_max:
		if rng.randf() >= t.cyborg_chance:
			continue
		var added: int = _add_encounter(gen, t, rng, patterns, tank, cut, attack, escape, fixed, asked)
		if added == 0:
			break
		made["cyborgs"] = int(made["cyborgs"]) + added
	var blocked: Array[Vector2] = _blocked(gen, t, patterns, cut, asked)
	var rows: Vector2i = _add_rows(gen, t, rng, patterns, tank, cut, attack, escape, blocked, asked)
	made["rows"] = rows.x
	made["pieces"] = rows.y
	return made


## The tank's escape lane (see the header): one of its cut's neighbours clear over the attack (lane_clear), a seeded
## pick where both are; -1 where neither is.
static func _escape_lane(gen: LevelGenerator, rng: RandomNumberGenerator, cut: Dictionary, attack: Vector2,
		tank: Dictionary, asked: Asked) -> int:
	var lane: int = int(cut["lane"])
	var options: Array[int] = []
	for side: int in [-1, 1]:
		var l: int = lane + side
		if l >= 0 and l < gen.layout.lane_count and lane_clear(gen, l, attack, tank, asked):
			options.append(l)
	if options.is_empty():
		return -1
	return options[rng.randi_range(0, options.size() - 1)]


## True if no stretch of `spans` reaches [a, b].
static func _free(spans: Array[Vector2], a: float, b: float) -> bool:
	for s: Vector2 in spans:
		if s.x <= b and s.y >= a:
			return false
	return true


## True if a rule keeps floor lane `lane` somewhere in `span` (rules_doodad_keep_outs with a lane: a hover truck's).
static func _lane_kept(gen: LevelGenerator, lane: int, span: Vector2, asked: Asked = null) -> bool:
	for k: Dictionary in asked.lane_keeps if asked != null else gen.rules_doodad_keep_outs():
		if k.has("lane") and int(k["lane"]) == lane and float(k["from"]) <= span.y and float(k["to"]) >= span.x:
			return true
	return false


## True if floor lane `lane` holds a hole or a fence somewhere in `span`.
static func _lane_pieced(gen: LevelGenerator, lane: int, span: Vector2) -> bool:
	var half: float = gen.tuning.fence_depth * 0.5
	if gen.layout.gapped_between(lane, span.x, span.y):
		return true
	for f: Dictionary in gen.layout.fences:
		if int(f["lane"]) == lane and float(f["at"]) - half <= span.y and float(f["at"]) + half >= span.x:
			return true
	return false


## True if `span` reaches the tank's attack (`attack`, SWITCH_MARGIN wider).
static func _in_attack(attack: Vector2, span: Vector2) -> bool:
	return span.y >= attack.x - SWITCH_MARGIN and span.x <= attack.y + SWITCH_MARGIN


## Re-checks `cut` (its cause `tank`) after an addition, for what company could take from it: its lane clear over its
## lane window (no hole or fence), the lanes beside it whole enough along its stretch (GDD §9.9;
## LevelGenerator.whole_lanes_for_cut), room to leave its lane after its warning (LevelGenerator.cut_escape_clear) and
## its escape lane still clear over the attack (lane_clear).
static func _cut_ok(gen: LevelGenerator, tank: Dictionary, cut: Dictionary, attack: Vector2, escape: int,
		asked: Asked) -> bool:
	var lane: int = int(cut["lane"])
	var n: int = gen.layout.lane_count
	if _lane_pieced(gen, lane, FloorCutPlan.lane_window(cut)):
		return false
	var holed: Dictionary = {}
	for g: Dictionary in gen.layout.gaps:
		if int(g["lane"]) != lane and float(g["start"]) <= float(cut["end"]) and float(g["end"]) >= float(cut["start"]):
			holed[int(g["lane"])] = true
	if holed.size() > n - 1 - gen.whole_lanes_for_cut(n) or not gen.cut_escape_clear(cut):
		return false
	return escape < 0 or lane_clear(gen, escape, attack, tank, asked)


## Takes `item` (that very entry) out of `list`.
static func _remove(list: Array[Dictionary], item: Dictionary) -> void:
	for i: int in list.size():
		if is_same(list[i], item):
			list.remove_at(i)
			return


# --- Cyborgs ---------------------------------------------------------------------------------------------------------

## One cyborg encounter standing in the tank's stretch where one fits (see the header): a spot picked at random among
## those whose attack window (its approach may reach back before the stretch) keeps off `fixed`
## (DangerDensity.enemy_fixed_stretches, without this tank's window) with the level's spacing around it inside the
## playable track, where company cyborgs may come (_cyborgs_from), and keeps off the rules' calm stretches with where
## it stands (CALM_ROOM either side), as the danger density pass keeps an enemy it adds; the encounter one of the
## level's plain cyborg patterns there, in as many of the lanes _cyborg_lanes allows as it asks (fewer where those
## don't fit), where _encounter_fits. Returns how many cyborgs it added (0: none fits).
static func _add_encounter(gen: LevelGenerator, t: BuzzCompanyTuning, rng: RandomNumberGenerator, patterns: Array,
		tank: Dictionary, cut: Dictionary, attack: Vector2, escape: int, fixed: Array[Vector2], asked: Asked) -> int:
	var v: float = gen.speed
	var dt: Resource = DangerDensity.tuning()
	var ct := EnemyDirector.tuning_for(CYBORG) as CyborgTuning
	if ct == null:
		ct = CyborgTuning.new()
	var margin: float = CyborgRules.obstacle_margin_at(ct, gen.pace)
	asked.margin = margin
	asked.obstacles = CyborgRules.obstacle_spans(gen.layout, gen.tuning, gen.zones)
	var reach := Vector2(ct.floor_reach_before * gen.pace, ct.floor_reach_after * gen.pace)
	# Its attack window (DangerDensity.attack_window: its keep-out, CyborgRules.keep_out, and the floor it uses).
	var before: float = maxf(maxf(LevelGenerator.FILL_ENEMY_LEAD_SECONDS * v, margin), reach.x)
	var after: float = maxf(margin, reach.y)
	var stretch: Vector2 = stretch_of(gen, t, cut)
	var lo: float = gen.config.start_clear_distance
	var hi: float = gen.layout.length - gen.config.end_clear_distance
	var first: float = _cyborgs_from(gen)
	var spots: Array[float] = []
	var x: float = stretch.x
	while x <= stretch.y:
		var k := Vector2(x - before, x + after)
		if x > first + 0.01 and k.x - DangerDensity.clearance(gen, k.x, dt) >= lo \
				and k.y + DangerDensity.clearance(gen, k.y, dt) <= hi and _free(fixed, k.x, k.y) \
				and _free(asked.calm, minf(x - CALM_ROOM, k.x), maxf(x + CALM_ROOM, k.y)):
			spots.append(x)
		x += SPOT_STEP_SECONDS * v
	for i: int in range(spots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: float = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var hold: Vector2 = hold_of(gen, t, cut)
	for spot: float in spots:
		var count: int = _encounter_count(gen, rng, patterns, spot)
		if count <= 0:
			continue
		var k := Vector2(spot - before, spot + after)
		var window := Vector2(k.x - DangerDensity.clearance(gen, k.x, dt), k.y + DangerDensity.clearance(gen, k.y, dt))
		var floor_span := Vector2(spot - reach.x, spot + reach.y)
		var lanes: Array[int] = _cyborg_lanes(gen, t, cut, attack, escape, spot, floor_span, window, asked)
		_shuffle(lanes, rng)
		for size: int in range(mini(count, lanes.size()), 0, -1):
			var pick: Array[int] = lanes.slice(0, size)
			if not _encounter_fits(gen, dt, tank, cut, window, pick, asked):
				continue
			var added: Array[Dictionary] = []
			for l: int in pick:
				# DESIGN-TBD (items 933-941 in docs/OPEN_QUESTIONS*.md): never the panic variant (a panic run could carry one into E).
				var entry := {"type": CYBORG, "at": spot, "lane": l, "side": 0,
					"seed": hash([gen.config.level_seed, PARAM, _company_count(gen.layout)]),
					"params": {"panic": false, "host": false, "hold_fire": hold, PARAM: float(cut["end"])}}
				gen.layout.enemies.append(entry)
				added.append(entry)
			if _cut_ok(gen, tank, cut, attack, escape, asked):
				gen._trim_clear_stretches(k)
				return added.size()
			for entry: Dictionary in added:
				_remove(gen.layout.enemies, entry)
	return 0


## How many cyborgs the encounter at track distance `at` places: one of the level's plain cyborg patterns there (one
## enemy element of plain cyborgs in random lanes: a single, a pair), picked by its weight as the pattern pass picks
## (LevelGenerator.pick_weights); 0 where the level has none there.
static func _encounter_count(gen: LevelGenerator, rng: RandomNumberGenerator, patterns: Array, at: float) -> int:
	var difficulty: float = gen.difficulty_at(clampf(at / gen.layout.length, 0.0, 1.0))
	var pool: Dictionary = gen.pick_weights(patterns, difficulty, at, CYBORG)
	var counts: Array[int] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for i: int in (pool["patterns"] as Array).size():
		var p: Dictionary = pool["patterns"][i]
		var elements: Array = p.get("elements", [])
		if elements.size() != 1:
			continue
		var element: Dictionary = elements[0]
		var selector: Dictionary = element.get("lanes", {})
		if String(element.get("kind", "")) != "enemy" or String(element.get("type", "")) != CYBORG \
				or element.has("side") or not (element.get("params", {}) as Dictionary).is_empty() \
				or String(selector.get("mode", "random")) != "random":
			continue
		counts.append(LevelGenerator._selector_count(selector, gen.layout.lane_count, 0))
		weights.append(float(pool["weights"][i]))
		total += weights[-1]
	if counts.is_empty() or total <= 0.0:
		return 0
	var roll: float = rng.randf() * total
	for i: int in counts.size():
		roll -= weights[i]
		if roll <= 0.0:
			return counts[i]
	return counts[-1]


## The lanes a company cyborg at `at` (its floor `floor_span`, its attack window with the level's spacing around it
## `window`) may stand in: never the cut's; one whose floor reaches the attack only beside the escape lane, never in it
## (with cyborgs_in_attack and an escape lane); free of holes, fences and what a rule keeps over `window` (the danger
## density pass's own lane rule), and where _cyborg_fits.
static func _cyborg_lanes(gen: LevelGenerator, t: BuzzCompanyTuning, cut: Dictionary, attack: Vector2, escape: int,
		at: float, floor_span: Vector2, window: Vector2, asked: Asked) -> Array[int]:
	var out: Array[int] = []
	var in_attack: bool = _in_attack(attack, floor_span)
	if in_attack and (not t.cyborgs_in_attack or escape < 0):
		return out
	for l: int in gen.layout.lane_count:
		if l == int(cut["lane"]):
			continue
		if in_attack and (l == escape or absi(l - escape) != 1):
			continue
		if _lane_kept(gen, l, window, asked) or _lane_pieced(gen, l, window) or not _cyborg_fits(gen, at, l, asked):
			continue
		out.append(l)
	return out


## True if a cyborg encounter in lanes `pick` with `window` (its attack window with the level's spacing around it)
## keeps the danger density pass's rules for an enemy it adds (DangerDensity: _overlap_ok, _floor_ok): at most its
## tuning's overlap_max other attack windows reach `window`, all of its twin_tolerated_types and none a host's (the
## tank's own aside: this is its company), and min_free_lanes lanes stay free beside it of floor enemies (the tank's
## lane counts as taken), holes, fences and kept lanes.
static func _encounter_fits(gen: LevelGenerator, dt: Resource, tank: Dictionary, cut: Dictionary, window: Vector2,
		pick: Array[int], asked: Asked) -> bool:
	var tolerated: PackedStringArray = dt.get("twin_tolerated_types")
	var overlap_max: int = maxi(int(dt.get("overlap_max")), 0)
	var n: int = gen.layout.lane_count
	var min_free: int = clampi(int(dt.get("min_free_lanes")), 1, maxi(n - 1, 1))
	var taken: Dictionary = {int(cut["lane"]): true}
	for l: int in pick:
		taken[l] = true
	var overlaps: int = 0
	var hooks: Dictionary = {}
	for e: Dictionary in gen.layout.enemies:
		if is_same(e, tank):
			continue
		for w: Vector2 in DangerDensity.attack_windows(gen, e, hooks, dt):
			if w.y < w.x or w.x > window.y or w.y < window.x:
				continue
			overlaps += 1
			if not tolerated.has(String(e.get("type", ""))) or bool((e.get("params", {}) as Dictionary).get("host", false)) \
					or overlaps > overlap_max:
				return false
			if LevelGenerator.enemy_uses_floor(e):
				var lane: int = int(e.get("lane", -1))
				if lane >= 0 and lane < n:
					taken[lane] = true
				elif int(e.get("side", 0)) != 0:
					taken[gen.layout.outer_lane(int(e["side"]))] = true
	for l: int in n:
		if _lane_kept(gen, l, window, asked) or _lane_pieced(gen, l, window):
			taken[l] = true
	return n - taken.size() >= min_free


## True if a cyborg at `at` in floor lane `lane` keeps the cyborg rules' margin (CyborgRules: no hole, fence, ramp, pad,
## speed pad or landing zone near, in any lane), stands on floor and off every ceiling's safe floor (CeilingZones
## .enemy_clear), as a cyborg in a charge's path does (ChargePathPlacement).
static func _cyborg_fits(gen: LevelGenerator, at: float, lane: int, asked: Asked) -> bool:
	if CyborgRules.near_any(asked.obstacles, at, asked.margin) or gen.layout.gapped_between(lane, at - 1.0, at + 1.0):
		return false
	var probe := {"type": CYBORG, "at": at, "lane": lane, "side": 0, "params": {}}
	return gen.zones.enemy_clear(gen.layout, probe)


## Where company cyborgs may stand from in the level: past the `cyborg` feature's start, and in a level that introduces
## it (its feature age 0, or a start of its own) past its first plain cyborg (not a host, not planted in a charge's
## path, no company), so company never comes before its introduction, as the danger density pass never adds an enemy
## before the level's first of its kind. INF in a level without the feature, or one that introduces it but has none.
static func _cyborgs_from(gen: LevelGenerator) -> float:
	if not gen.config.has_feature(CYBORG):
		return INF
	var from: float = gen.feature_start(CYBORG)
	if int(gen.config.feature_ages.get(CYBORG, -1)) != 0 and not gen.config.feature_starts.has(CYBORG):
		return from
	var first: float = INF
	for e: Dictionary in gen.layout.enemies:
		var params: Dictionary = e.get("params", {})
		if String(e.get("type", "")) == CYBORG and not bool(params.get("host", false)) and not params.has(PARAM) \
				and not params.has(ChargePathPlacement.PARAM):
			first = minf(first, float(e["at"]))
	return maxf(from, first)


## How many company cyborgs `layout` holds (each one's seed is its own: not LevelGenerator.add_enemy's running count).
static func _company_count(layout: LevelLayout) -> int:
	var n: int = 0
	for e: Dictionary in layout.enemies:
		if is_company(e):
			n += 1
	return n


# --- Rows ------------------------------------------------------------------------------------------------------------

## The stretches no row may reach (margins included): what the fill pass keeps off, without `cut`'s own window and its
## cause's (LevelGenerator.fill_keep_outs: every piece, every other enemy's keep-out, the company cyborgs' too, ramps,
## pads, ceilings and their landing zones), its margins times spacing_scale, and what the rules keep in every lane (a
## Bad Dream's chase, a Gilded Sentinel's turn, an Enforcer Truck's showing window), as it stands.
static func _blocked(gen: LevelGenerator, t: BuzzCompanyTuning, patterns: Array, cut: Dictionary,
		asked: Asked) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k: Vector4 in gen.fill_keep_outs(patterns, true, cut)["keep"]:
		out.append(Vector2(k.x - k.z * t.spacing_scale, k.y + k.w * t.spacing_scale))
	out.append_array(asked.everywhere)
	return out


## The margin a row keeps at track distance `at`: the fill pass's (the level's spacing and a pattern's tail), times
## spacing_scale.
static func _margin(gen: LevelGenerator, t: BuzzCompanyTuning, at: float) -> float:
	return gen._fill_margin(at) * t.spacing_scale


## Rows of holes or fences through the tank's stretch where nothing is kept (`blocked`), the fill pass's way: at the
## start of each free stretch a filler picked there, then the next its margin past it, up to rows_max, each in the
## lanes _row_lanes allows with a lane left free beside it (a spot where none fits moves on SPOT_STEP_SECONDS).
## Returns (rows, pieces).
static func _add_rows(gen: LevelGenerator, t: BuzzCompanyTuning, rng: RandomNumberGenerator, patterns: Array,
		tank: Dictionary, cut: Dictionary, attack: Vector2, escape: int, blocked: Array[Vector2], asked: Asked) -> Vector2i:
	var stretch: Vector2 = stretch_of(gen, t, cut)
	var last: float = minf(stretch.y, gen.layout.length - gen.config.end_clear_distance)
	var rows: int = 0
	var pieces: int = 0
	var step: float = SPOT_STEP_SECONDS * gen.speed
	for region: Vector2 in LevelGenerator.free_stretches(blocked, stretch.x, last):
		var cursor: float = region.x
		while cursor < region.y and rows < t.rows_max:
			var row: Dictionary = _pick_row(gen, rng, patterns, cursor, region.y)
			if row.is_empty():
				break
			var lanes: Array[int] = _row_lanes(gen, rng, cut, attack, escape, row, asked)
			var span: Vector2 = row["span"]
			if lanes.is_empty() or not _lane_left(gen, cut, attack, span, lanes, asked) \
					or not _try_row(gen, rng, tank, cut, attack, escape, row, lanes, asked):
				cursor += step
				continue
			rows += 1
			pieces += lanes.size()
			cursor = span.y + _margin(gen, t, span.y)
	return Vector2i(rows, pieces)


## True if, beside a row taking `taken` over `span`, a lane stays free for the runner: not the cut's lane in the
## attack, none `taken`, none a rule keeps there. (The escape lane always is in the attack, the cut's lane before.)
static func _lane_left(gen: LevelGenerator, cut: Dictionary, attack: Vector2, span: Vector2, taken: Array[int],
		asked: Asked) -> bool:
	for l: int in gen.layout.lane_count:
		if taken.has(l) or (l == int(cut["lane"]) and _in_attack(attack, span)):
			continue
		if not _lane_kept(gen, l, span, asked):
			return true
	return false


## One of the level's one-row fillers (a single hole or fence element whose lanes are random, all but some, or all; no
## pulsing) picked by its weight as the fill pass picks there (LevelGenerator.pick_weights with `fill`), among those
## that fit between `at` and `room_end`: {kind, variant, mode, width, span, element}; {} where none does.
static func _pick_row(gen: LevelGenerator, rng: RandomNumberGenerator, patterns: Array, at: float,
		room_end: float) -> Dictionary:
	var difficulty: float = gen.difficulty_at(clampf(at / gen.layout.length, 0.0, 1.0))
	var pool: Dictionary = gen.pick_weights(patterns, difficulty, at, "", true)
	var rows: Array[Dictionary] = []
	var weights: Array[float] = []
	var total: float = 0.0
	var half: float = gen.tuning.fence_depth * 0.5
	for i: int in (pool["patterns"] as Array).size():
		var elements: Array = (pool["patterns"][i] as Dictionary).get("elements", [])
		if elements.size() != 1:
			continue
		var element: Dictionary = elements[0]
		var kind: String = String(element.get("kind", ""))
		var selector: Dictionary = element.get("lanes", {})
		var mode: String = String(selector.get("mode", "random"))
		if not (kind in ["gap", "fence"]) or not (mode in ["random", "all_but", "all"]) \
				or float(element.get("pulse_chance", 0.0)) > 0.0:
			continue
		var spot: float = at + gen.metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * gen.speed
		var span := Vector2(spot - half, spot + half)
		if kind == "gap":
			span = Vector2(spot, spot + minf(float(element.get("jump_frac", 0.5)), gen.config.max_gap_jump_fraction)
				* gen.jump_distance)
		if span.x < at - 0.001 or span.y > room_end:
			continue
		rows.append({"kind": kind, "variant": String(element.get("variant", "full")), "mode": mode,
			"width": LevelGenerator._selector_count(selector, gen.layout.lane_count, 0), "span": span, "element": element})
		weights.append(float(pool["weights"][i]))
		total += weights[-1]
	if rows.is_empty() or total <= 0.0:
		return {}
	var roll: float = rng.randf() * total
	for i: int in rows.size():
		roll -= weights[i]
		if roll <= 0.0:
			return rows[i]
	return rows[-1]


## The lanes `row` takes (see the header): never the cut's; in the attack never the escape lane, and holes only in the
## lanes GDD §9.9's whole lanes leave (LevelGenerator.whole_lanes_for_cut: those already holed there, then new ones
## up to the limit), never the cut's neighbours; never a lane a rule keeps there; a fence only on floor. As many as the
## filler asks (its count, all but its count, or all) of those, picked at random; [] where none.
static func _row_lanes(gen: LevelGenerator, rng: RandomNumberGenerator, cut: Dictionary, attack: Vector2, escape: int,
		row: Dictionary, asked: Asked = null) -> Array[int]:
	var n: int = gen.layout.lane_count
	var lane: int = int(cut["lane"])
	var span: Vector2 = row["span"]
	var in_attack: bool = _in_attack(attack, span)
	var out: Array[int] = []
	if in_attack and escape < 0:
		return out
	var allowed: Array[int] = []
	for l: int in n:
		if l == lane or (in_attack and l == escape) or _lane_kept(gen, l, span, asked):
			continue
		if row["kind"] == "fence" and gen.layout.gapped_between(l, span.x, span.y):
			continue
		if row["kind"] == "gap" and in_attack and absi(l - lane) == 1:
			continue
		allowed.append(l)
	_shuffle(allowed, rng)
	if row["kind"] == "gap" and in_attack:
		# GDD §9.9: the lanes beside the cut stay whole along it (on 3 lanes every one), counting those already holed.
		var holed: Dictionary = {}
		for g: Dictionary in gen.layout.gaps:
			if int(g["lane"]) != lane and float(g["start"]) <= attack.y and float(g["end"]) >= attack.x:
				holed[int(g["lane"])] = true
		var budget: int = n - 1 - gen.whole_lanes_for_cut(n) - holed.size()
		var kept: Array[int] = []
		for l: int in allowed:
			if holed.has(l):
				kept.append(l)
			elif budget > 0:
				kept.append(l)
				budget -= 1
		allowed = kept
	var width: int = allowed.size()
	if String(row["mode"]) != "all":
		width = mini(int(row["width"]), allowed.size())
	for i: int in width:
		out.append(allowed[i])
	out.sort()
	return out


## Adds `row` in `lanes` and keeps it if the cut keeps what company could take from it (_cut_ok); else takes it out
## again. True if kept.
static func _try_row(gen: LevelGenerator, rng: RandomNumberGenerator, tank: Dictionary, cut: Dictionary,
		attack: Vector2, escape: int, row: Dictionary, lanes: Array[int], asked: Asked) -> bool:
	var span: Vector2 = row["span"]
	var element: Dictionary = row["element"]
	var added: Array[Dictionary] = []
	for l: int in lanes:
		var piece: Dictionary = {}
		if row["kind"] == "gap":
			piece = {"lane": l, "start": span.x, "end": span.y, PARAM: float(cut["end"])}
			gen.layout.gaps.append(piece)
		else:
			piece = {"lane": l, "at": (span.x + span.y) * 0.5, "variant": String(row["variant"]), "pulsing": false,
				"pulse_on": float(element.get("pulse_on", 1.2)), "pulse_off": float(element.get("pulse_off", 1.0)),
				"phase": rng.randf(), PARAM: float(cut["end"])}
			gen.layout.fences.append(piece)
		added.append(piece)
	if _cut_ok(gen, tank, cut, attack, escape, asked):
		for piece: Dictionary in added:
			gen.uncredited[piece] = true
		gen._trim_clear_stretches(span)
		return true
	for piece: Dictionary in added:
		_remove(gen.layout.gaps if row["kind"] == "gap" else gen.layout.fences, piece)
	return false


static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = values[i]
		values[i] = values[j]
		values[j] = tmp
