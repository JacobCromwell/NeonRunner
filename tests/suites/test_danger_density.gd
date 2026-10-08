extends TestSuite
## The danger density pass (scripts/world/danger_density.gd; docs/USER_REQUESTS.md: the open-lane
## allowance was too forgiving, so about 15% more enemies and obstacles in the first levels, about 35%
## by the final ones). Measured on real builds, not on the dial: each sampled campaign level at 3, 5
## and 6 lanes, on its own seed and two others, built with its dial and with the dial at 0 (exactly the
## level as it was before the pass: tools/measure/danger_density.gd checks that layout for layout
## against a dump made before the pass existed). The actual counts of enemies, and separately of
## obstacles (holes and fences lane by lane, signs, floor cuts and wall fences), summed per band of
## zones and lane count, must rise by the request's share within its tolerance. Every added enemy and
## row keeps the pass's fairness: the open lane at every moment of an added enemy's attack and at every
## row it made or widened, full rows clear of every attack, nothing added in The Hush's quiet stretches,
## nothing of a kind before the level's first, the floor route through the level, the layout and rule
## checks (Barnacle Turrets' too), the same seed the same level, a bounded build time, and no more pay:
## the pieces it adds carry no risky credit, so a level's credits stay about what they were.

const DangerDensity := preload("res://scripts/world/danger_density.gd")
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const LANES: Array[int] = [3, 5, 6]
## Each sampled level is built on its own seed and on these (tools/measure/danger_density.gd --seeds=2
## builds the same sample, so its output shows the numbers this suite checks).
const OTHER_SEEDS: Array[int] = [9001, 9002]
## The sampled levels by band: the first levels (dials 0.15 to 0.20), the middle ones (0.26 to 0.28)
## and the final ones (0.37 to 0.38). The Hush (dead_zone/2) is checked for fairness only: its quiet
## stretches stay quiet by design, so it gains less than its dial.
const BANDS: Dictionary = {
	"early": ["city/1", "city/2", "gangland/2"],
	"middle": ["marketplace/2", "corporate/1"],
	"late": ["dead_zone/1", "golden/2", "golden/3"],
}
const FAIRNESS_ONLY: Array[String] = ["dead_zone/2"]
## Builds checked for fairness only, as {id, lanes, seed}: golden/1 at 6 lanes on seed 9003 (in
## tests/suites/test_campaign.gd's seed sweep) once had a zone doodad placed, after the pass, right
## past a full row in the only lane a new row of holes left open; nothing got past it under the
## ceiling there (DangerDensity.doodad_ok keeps doodads off such lanes now).
const ROUTE_CASES: Array[Dictionary] = [{"id": "golden/1", "lanes": 6, "seed": 9003}]
## The request, as the actual increase of a band's summed counts with the dial over those without it,
## for enemies and for obstacles alike, at each lane count: about 15% in the first levels, about 35%
## in the final ones.
const TARGET_RATIO: Dictionary = {"early": 1.15, "late": 1.35}
## How far a band may land from its target: "about" 15% / 35%, as the owner's coordinator accepted it
## (10% to 20%, 30% to 40%). A band's levels differ by up to about 0.1 from each other (golden/2's
## Gilded Sentinel stretches leave the least room), so a tighter tolerance would test which levels
## and seeds were sampled rather than the pass.
const TOLERANCE: float = 0.05
## The middle zones (the user left them to judgment) land between the first levels' target and the
## final ones' and above the first band and below the last, at every lane count, for both counts.
const MIDDLE_RANGE := Vector2(1.15, 1.35)
## The pass adds danger, not pay (its tuning's credit_added_pieces off): a band's credits with the dial
## stay within these of those without (measured: x0.92 to x1.01 per band in this sample, the new rows
## taking a little room from the credit trails), so the earnings curve the shop's prices were set
## against (tests/suites/test_economy.gd) holds; the floor only catches the credits going missing.
const CREDIT_RATIO_RANGE := Vector2(0.85, 1.03)
## With the dial a level's build takes at most this many times as long as without it (measured: about
## 1.5 over this sample).
const MAX_BUILD_TIME_RATIO: float = 2.0
## Track distance between two moments checked during an added enemy's attack (metres).
const MOMENT_STEP: float = 1.0
## The highest dial a level may have (the final zones' calibration, _test_dials).
const MAX_DIAL: float = 0.40

var _dd_tuning: Resource


func run() -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	_dd_tuning = DangerDensity.tuning()
	_test_tuning()
	_test_dials(campaign)
	_test_density(campaign)
	_test_zero_dial(campaign)
	_test_deterministic(campaign)


## The pass-wide numbers keep the fairness floors: an open lane, the level's own spacing, only small
## threats added, only a host's chase exempt from the rules' keep-outs.
func _test_tuning() -> void:
	var t: Resource = _dd_tuning
	check(int(t.get("min_free_lanes")) >= 1, "at least one lane stays open around everything added")
	check(float(t.get("clearance_spacing_scale")) >= 1.0, "the clearance is never below the level's spacing")
	var allowed: PackedStringArray = ["cyborg", "screech", "window_cyborg"]
	for type: String in t.get("enemy_types"):
		check(allowed.has(type), "only small threats whose rules the pass applies are added: %s" % type)
	for type: String in t.get("twin_tolerated_types"):
		check(not type.begins_with("host") and type != "drone" and type != "resonator",
			"no big threat's attack is tolerated: %s" % type)
	check(Array(t.get("keep_out_exempt_features")) == ["host"], "only a host's chase keep-out is exempt")


## Every campaign level has a dial from 0.15 (the first) to at least 0.35 (the final), never falling
## along the campaign and never above MAX_DIAL; the prototype level and every boss arena have none.
## The final zones' dials sit a little above 0.35 so that their measured increase lands at about 35%
## (_test_density): a Gilded Sentinel's or a Resonator's stretches leave less fair room than they ask.
func _test_dials(campaign: Campaign) -> void:
	var levels: Array[CampaignStep] = []
	for s: CampaignStep in campaign.steps():
		if s.is_level():
			levels.append(s)
		elif s.boss != null:
			var arena: LevelConfig = campaign.configure_boss(s, 5)
			check(is_zero_approx(arena.danger_density_increase), "boss arena %s keeps its terrain: no dial" % s.id)
	check(levels.size() >= 2, "campaign has levels")
	var last: float = 0.0
	for s: CampaignStep in levels:
		var dial: float = s.level.danger_density_increase
		check(dial >= 0.15 - 0.001 and dial <= MAX_DIAL + 0.001, "%s dial %.2f within 0.15..%.2f" % [s.id, dial, MAX_DIAL])
		check(dial >= last - 0.001, "%s dial %.2f never below the level before (%.2f)" % [s.id, dial, last])
		last = dial
	check(is_equal_approx(levels[0].level.danger_density_increase, 0.15), "the first level asks 15% more")
	check(levels[-1].level.danger_density_increase >= 0.35 - 0.001, "the final level asks at least 35% more")
	var prototype := load(LEVEL_PATH) as LevelConfig
	check(is_zero_approx(prototype.danger_density_increase), "the prototype level has no dial")


## Each band's actual enemies and obstacles, at each lane count, against the request (TARGET_RATIO,
## TOLERANCE, MIDDLE_RANGE), with every build's fairness (_check_fair).
func _test_density(campaign: Campaign) -> void:
	var off_ms: int = 0
	var on_ms: int = 0
	var ratios: Dictionary = {}
	for band: String in BANDS:
		var enemies: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
		var floors: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
		var walls: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
		var credits: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
		for id: String in BANDS[band]:
			for li: int in LANES.size():
				for k: int in OTHER_SEEDS.size() + 1:
					var config: LevelConfig = campaign.configure(campaign.step(id), LANES[li])
					if k > 0:
						config.level_seed = OTHER_SEEDS[k - 1]
					var built: Dictionary = _build_pair(config)
					off_ms += int(built["off_ms"])
					on_ms += int(built["on_ms"])
					var off: LevelLayout = built["off"]
					var on: LevelLayout = built["on"]
					# Not the cyborgs planted in charge paths (task G7, ChargePathPlacement): the same few with and
					# without the dial, after the pass's count.
					enemies[li] += Vector2i(off.enemies.size() - ChargePathPlacement.planted_in(off).size(),
						on.enemies.size() - ChargePathPlacement.planted_in(on).size())
					floors[li] += Vector2i(DangerDensity.floor_count(off), DangerDensity.floor_count(on))
					walls[li] += Vector2i(off.wall_fences.size(), on.wall_fences.size())
					credits[li] += Vector2i(off.total_credit_value(), on.total_credit_value())
					_check_fair(config, built["gen"], off, "%s lanes=%d seed=%d" % [id, LANES[li], config.level_seed])
		var band_ratios: Array[Vector2] = []
		for li: int in LANES.size():
			var obstacles: Vector2i = floors[li] + walls[li]
			var e: float = float(enemies[li].y) / maxi(enemies[li].x, 1)
			var o: float = float(obstacles.y) / maxi(obstacles.x, 1)
			var c: float = float(credits[li].y) / maxi(credits[li].x, 1)
			band_ratios.append(Vector2(e, o))
			var tag: String = "%s lanes=%d" % [band, LANES[li]]
			print("  danger density %s: enemies %d -> %d (x%.3f), obstacles %d -> %d (x%.3f: floor pieces %d -> %d, wall fences %d -> %d), credits x%.3f" % [
				tag, enemies[li].x, enemies[li].y, e, obstacles.x, obstacles.y, o, floors[li].x, floors[li].y,
				walls[li].x, walls[li].y, c])
			check(c >= CREDIT_RATIO_RANGE.x and c <= CREDIT_RATIO_RANGE.y, "%s: credits x%.3f, within x%.2f..x%.2f" % [
				tag, c, CREDIT_RATIO_RANGE.x, CREDIT_RATIO_RANGE.y])
			var lo: float = MIDDLE_RANGE.x
			var hi: float = MIDDLE_RANGE.y
			if TARGET_RATIO.has(band):
				lo = float(TARGET_RATIO[band]) - TOLERANCE
				hi = float(TARGET_RATIO[band]) + TOLERANCE
			check(e >= lo - 0.0005 and e <= hi + 0.0005, "%s: enemies x%.3f, within x%.2f..x%.2f" % [tag, e, lo, hi])
			check(o >= lo - 0.0005 and o <= hi + 0.0005, "%s: obstacles x%.3f, within x%.2f..x%.2f" % [tag, o, lo, hi])
		ratios[band] = band_ratios
	for li: int in LANES.size():
		var early: Vector2 = ratios["early"][li]
		var middle: Vector2 = ratios["middle"][li]
		var late: Vector2 = ratios["late"][li]
		check(early.x < middle.x and middle.x < late.x, "lanes=%d: enemies rise along the campaign (x%.3f, x%.3f, x%.3f)" % [
			LANES[li], early.x, middle.x, late.x])
		check(early.y < middle.y and middle.y < late.y, "lanes=%d: obstacles rise along the campaign (x%.3f, x%.3f, x%.3f)" % [
			LANES[li], early.y, middle.y, late.y])
	for id: String in FAIRNESS_ONLY:
		for lanes: int in LANES:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var built: Dictionary = _build_pair(config)
			_check_fair(config, built["gen"], built["off"], "%s lanes=%d seed=%d" % [id, lanes, config.level_seed])
	for case: Dictionary in ROUTE_CASES:
		var config: LevelConfig = campaign.configure(campaign.step(String(case["id"])), int(case["lanes"]))
		config.level_seed = int(case["seed"])
		var built: Dictionary = _build_pair(config)
		_check_fair(config, built["gen"], built["off"], "%s lanes=%d seed=%d" % [case["id"], case["lanes"], case["seed"]])
	print("  danger density build time: %d ms without the dial, %d ms with it" % [off_ms, on_ms])
	check(on_ms <= MAX_BUILD_TIME_RATIO * off_ms + 2000, "the pass keeps builds quick: %d ms with it, %d ms without" % [on_ms, off_ms])


## `config` built with its dial and with the dial at 0: {gen, on, off, on_ms, off_ms}.
func _build_pair(config: LevelConfig) -> Dictionary:
	var patterns: Array = LevelGenerator.load_for(config)
	var zero: LevelConfig = config.duplicate() as LevelConfig
	zero.danger_density_increase = 0.0
	var t0: int = Time.get_ticks_msec()
	var off: LevelLayout = LevelGenerator.new().generate(zero, tuning, patterns)
	var t1: int = Time.get_ticks_msec()
	var gen := LevelGenerator.new()
	var on: LevelLayout = gen.generate(config, tuning, patterns)
	var t2: int = Time.get_ticks_msec()
	return {"gen": gen, "on": on, "off": off, "off_ms": t1 - t0, "on_ms": t2 - t1}


## The pass's fairness on `gen`'s build (with the dial) of `config`; `off` is the build without it.
func _check_fair(config: LevelConfig, gen: LevelGenerator, off: LevelLayout, tag: String) -> void:
	var layout: LevelLayout = gen.layout
	var result: Dictionary = gen.danger_density_result
	check(not result.is_empty(), "the pass ran " + tag)
	check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
	# A cyborg planted in a charge's path (task G7, ChargePathPlacement) comes after the pass's count, with or
	# without it.
	check(int(result.get("baseline_enemies", -1)) == off.enemies.size() - ChargePathPlacement.planted_in(off).size(),
		"the pass counts the enemies the level holds without it %s" % tag)
	var pieces: int = 0
	for key: String in ["widened", "new_row_pieces", "full_rows", "staggered_pieces", "routed", "routed_row_pieces"]:
		pieces += int(result.get(key, 0))
	check(gen.uncredited.size() == pieces, "no risky credit for any of the %d pieces the pass added (%d marked) %s" % [
		pieces, gen.uncredited.size(), tag])
	LayoutChecks.check_layout(self, layout, config, tag)
	LayoutChecks.check_rules(self, layout, config, tag)
	var movement: MovementTuning = config.movement_for(tuning)
	var route_off: bool = FloorRoute.new(off, movement).find(0.0, off.length)["ok"]
	var route_on: Dictionary = FloorRoute.new(layout, movement).find(0.0, layout.length)
	check(route_on["ok"] or not route_off, "a floor route through the level %s" % tag)
	var min_free: int = int(result.get("min_free_lanes", 1))
	var quiet: Array[Vector2] = gen.quiet_stretches()
	var types_before: Dictionary = {}
	for e: Dictionary in off.enemies:
		types_before[String(e["type"])] = true
	var types_after: Dictionary = {}
	for e: Dictionary in layout.enemies:
		types_after[String(e["type"])] = true
	check(types_after.keys().all(func(t: String) -> bool: return types_before.has(t)),
		"no enemy type the level lacks without the pass %s" % tag)
	var added: Array = result.get("added_enemies", [])
	var types: PackedStringArray = (_dd_tuning.get("enemy_types") as PackedStringArray).duplicate()
	if bool(_dd_tuning.get("ceiling_turrets")):
		types.append(DangerDensity.TURRET)
	for e: Dictionary in added:
		var type: String = String(e["type"])
		var where: String = "%s %s at %.1f lane %d side %d" % [tag, type, float(e["at"]), int(e["lane"]), int(e["side"])]
		check(layout.enemies.has(e), "added enemy is in the layout " + where)
		check(types.has(type), "only the tuning's types (and turrets where its rules hang one) are added " + where)
		var first: float = INF
		for o: Dictionary in layout.enemies:
			if String(o["type"]) == type and not added.has(o):
				first = minf(first, float(o["at"]))
		check(float(e["at"]) > first, "never before the level's first %s %s" % [type, where])
		var k: Vector2 = DangerDensity.attack_window(gen, e)
		check(quiet.all(func(q: Vector2) -> bool: return k.y <= q.x or k.x >= q.y), "nothing added in a quiet stretch " + where)
		if not LevelGenerator.enemy_uses_floor(e):
			continue
		var x: float = k.x
		while x <= k.y:
			var free: int = _free_lanes_at(gen, x, true)
			if free < min_free:
				check(false, "%d open lane(s) at %.1f during its attack (needs %d) %s" % [free, x, min_free, where])
				break
			x += MOMENT_STEP
	for row: Dictionary in result.get("rows_touched", []):
		var lanes: Array = row["lanes"]
		var a: float = float(row["start"])
		var b: float = float(row["end"])
		var where: String = "%s %s row %.1f..%.1f lanes %s" % [tag, row["kind"], a, b, lanes]
		check(quiet.all(func(q: Vector2) -> bool: return b <= q.x or a >= q.y), "no piece added in a quiet stretch " + where)
		if lanes.size() >= config.lane_count:
			var w := Vector2(a - DangerDensity.clearance(gen, a), b + DangerDensity.clearance(gen, b))
			var hit: String = ""
			for e: Dictionary in layout.enemies:
				for k: Vector2 in DangerDensity.attack_windows(gen, e):
					if k.y >= k.x and k.y > w.x and k.x < w.y:
						hit = "%s at %.1f" % [e["type"], float(e["at"])]
						break
				if not hit.is_empty():
					break
			check(hit.is_empty(), "a full row stands clear of every attack (a Resonator's as the tuning keeps it) %s %s" % [where, hit])
			if row["kind"] == "gap":
				check(b - a <= gen.jump_distance * config.max_gap_jump_fraction + 0.01, "a full row of holes is jumped " + where)
		else:
			var free: int = _free_lanes_at(gen, (a + b) * 0.5, false)
			if free == 0 and row["kind"] == "gap" and _gap_lanes(layout, a, b) >= config.lane_count:
				# GapDensity, after the pass, made the row an isolated full-width jump by its own rules
				# (tests/suites/test_city_gaps.gd): a jump clears it.
				check(b - a <= gen.jump_distance * config.max_gap_jump_fraction + 0.01, "a full row of holes is jumped " + where)
				continue
			check(free >= min_free, "%d open lane(s) at a row the pass made or widened (needs %d) %s" % [free, min_free, where])


## The lanes of `layout` with a hole over exactly `a`..`b`.
func _gap_lanes(layout: LevelLayout, a: float, b: float) -> int:
	var lanes: Dictionary = {}
	for g: Dictionary in layout.gaps:
		if is_equal_approx(float(g["start"]), a) and is_equal_approx(float(g["end"]), b):
			lanes[int(g["lane"])] = true
	return lanes.size()


## The floor lanes at track distance `x` of `gen`'s layout with no hole, floor cut or fence there and,
## if `enemies`, no floor enemy on the floor there (its floor span over `x`, in its floor lane: its
## own, or a vent Screech's outer lane).
func _free_lanes_at(gen: LevelGenerator, x: float, enemies: bool) -> int:
	var layout: LevelLayout = gen.layout
	var half: float = gen.tuning.fence_depth * 0.5
	var blocked: Dictionary = {}
	for list: Array in [layout.gaps, layout.cuts]:
		for g: Dictionary in list:
			if g.has("lane") and float(g.get("start", INF)) <= x and float(g.get("end", -INF)) >= x:
				blocked[int(g["lane"])] = true
	for f: Dictionary in layout.fences:
		if absf(float(f["at"]) - x) <= half:
			blocked[int(f["lane"])] = true
	if enemies:
		for e: Dictionary in layout.enemies:
			if not LevelGenerator.enemy_uses_floor(e):
				continue
			var span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
			if span.x > x or span.y < x:
				continue
			var lane: int = int(e.get("lane", -1))
			var side: int = int(e.get("side", 0))
			if lane >= 0 and lane < layout.lane_count:
				blocked[lane] = true
			elif side != 0:
				blocked[layout.outer_lane(side)] = true
	return layout.lane_count - blocked.size()


## At 0 the pass reports nothing and draws nothing: the build is the level as it was (layout for
## layout against a dump from before the pass: tools/measure/danger_density.gd --compare).
func _test_zero_dial(campaign: Campaign) -> void:
	for lanes: int in LANES:
		var config: LevelConfig = campaign.configure(campaign.step("golden/3"), lanes)
		config.danger_density_increase = 0.0
		var gen := LevelGenerator.new()
		gen.generate(config, tuning, LevelGenerator.load_for(config))
		check(gen.danger_density_result.is_empty(), "no pass at a dial of 0, lanes=%d" % lanes)


## The same seed builds the same level, the pass's additions too.
func _test_deterministic(campaign: Campaign) -> void:
	for id: String in ["city/2", "golden/3"]:
		for lanes: int in [3, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var patterns: Array = LevelGenerator.load_for(config)
			var a := LevelGenerator.new()
			var b := LevelGenerator.new()
			var la: LevelLayout = a.generate(config, tuning, patterns)
			var lb: LevelLayout = b.generate(config, tuning, patterns)
			var tag: String = "%s lanes=%d" % [id, lanes]
			check(JSON.stringify(la.to_dict()) == JSON.stringify(lb.to_dict()), "deterministic layout " + tag)
			check(var_to_str(a.danger_density_result) == var_to_str(b.danger_density_result), "deterministic report " + tag)
