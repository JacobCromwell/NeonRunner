extends TestSuite
## Wall-hop credits (task N1; GDD §7, "Wall-hop credits", owner, October 9, 2026: "some long walls carry high-value
## credits further along than one wall run reaches, so only a player inventive enough to wall hop collects them";
## WallHopPlacement, WallHopPath):
## - their numbers: the high-value credits hang above the highest a fresh wall run reaches a pickup without a hop (a
##   step onto the wall from the floor, or straight back onto it as a wall run drops its runner), and a hop's fresh
##   wall run passes them; the line's shape at every zone's speed puts them past one wall run's reach (and a clawed
##   one's), within a few hops;
## - placement: none in the City (its levels ask for none) and none in a level that asks for none, which is built as
##   before but for the line (the same layout without it); from Gangland 1 on every campaign level asks for one, and
##   at 3, 5 and 6 lanes, on each level's own build, every line keeps its rules (LayoutChecks.check_wall_hops), at most
##   one a level, and most builds have one ("about once a level"; the Beach's open walls leave none long enough,
##   printed); the same seed builds the same lines; every build's three-star line is reached without the high-value
##   credits (out of the stars' best score);
## - on real physics (excerpts of the campaign's first and last line at 5 lanes, the slowest and the fastest zone): the
##   reference hopper (WallHopPath: on at the entry, a hop each time its run comes down to the tuning's hop_height)
##   collects every credit of the line, alive, its fresh runs peaking where WallHopPath says; one who keeps another
##   rhythm (hops at 0.6 or 1.0 m) and hops once more as the high-value credits come near (0.15 or 0.35 s before them)
##   collects them all; one wall run from the entry collects the lead-in but none of the high-value credits, with claws
##   too; a runner who steps straight back onto the wall each time a run drops them, or who steps onto it from the floor
##   further along, passes under them, with Magnet I too (the magnet leaves them alone: CreditField._in_magnet). A jump
##   onto the wall from the floor at the right spot starts a run high enough to reach them (item
##   1020); nothing here rides that.

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const LANE_COUNTS: Array[int] = [3, 5, 6]
## The zones whose levels ask for no wall-hop credits (GDD §7, proposed: "from Gangland on"), and the Terminal, whose
## walls can't be run on (task O1; GDD §5, Zone 8).
const WITHOUT: Array[StringName] = [&"city", &"terminal"]
## The zone whose open walls (task D10b: half of each wall's length) leave no stretch long enough for a line.
const OPEN_WALLS: StringName = &"beach"
## An excerpt's line steps onto the wall this far along its fresh track.
const ENTRY_AT: float = 60.0
## At least this share of the campaign's builds outside the Beach get a line (GDD §7: "about once a level").
const MIN_SHARE: float = 0.7

var campaign: Campaign
var t: WallHopTuning
var sim: RunSim
## The campaign builds with a line at 5 lanes, in campaign order: [{id, config, layout, line}] (_test_campaign).
var found: Array[Dictionary] = []


func run() -> void:
	campaign = load(CAMPAIGN_PATH) as Campaign
	t = WallHopPlacement.tuning()
	sim = RunSim.new(tree, tuning)
	_test_numbers()
	_test_campaign()
	_test_without()
	await _test_rides()


# --- Numbers ----------------------------------------------------------------------------------------

func _test_numbers() -> void:
	check(t.resource_path == WallHopTuning.PATH, "the wall-hop numbers load from %s" % WallHopTuning.PATH)
	var height: float = WallHopPlacement.gem_height(tuning, t)
	var reach: float = WallHopPath.pickup_reach(tuning)
	var floor_top: float = minf(tuning.wall_entry_height, tuning.wall_max_height)
	var drop_top: float = tuning.wall_entry_height + tuning.wall_air_entry_factor * tuning.wall_exit_height
	check(height - reach > floor_top and height - reach > drop_top and height - reach > WallHopPath.fresh_top(tuning),
		"the high-value credits (%.2f m) are out of reach of a fresh wall run from the floor (%.2f m) or straight back on as one drops its runner (%.2f m), a pickup reaching %.2f m"
		% [height, floor_top, drop_top, reach])
	check(height < tuning.wall_max_height, "and below the top of the wall")
	for zone: ZoneDef in campaign.zones:
		if WITHOUT.has(zone.id):
			continue
		var mt: MovementTuning = tuning.duplicate() as MovementTuning
		mt.run_speed = zone.run_speed
		var shape: Dictionary = WallHopPlacement.shape_for(mt, zone.run_speed, t)
		check(not shape.is_empty(), "a line has a shape at %s's speed" % zone.id)
		if shape.is_empty():
			continue
		var path: WallHopPath = shape["path"]
		var gems: Array = shape["gems"]
		var claws: float = path.distance_at(path.run_end(0, WallHopPlacement.claws_multiplier()))
		check(gems.size() == t.gems and float(gems[0]["at"]) > path.distance_at(path.run_end(0)) + t.reach_margin_seconds * zone.run_speed - 0.01,
			"%s: its %d high-value credits lie past one wall run's reach (%.1f m: from %.1f m)"
			% [zone.id, t.gems, path.distance_at(path.run_end(0)), float(gems[0]["at"])])
		check(int(shape["run"]) >= 1 and int(shape["run"]) <= LayoutChecks.MAX_HOPS,
			"%s: within a few hops (%d)" % [zone.id, int(shape["run"])])
		# A single run with claws slides on further (GDD §8), but never above a fresh run's height: under them.
		for g: Dictionary in gems:
			var clawed: float = _single_run_height(mt, float(g["t"]), WallHopPlacement.claws_multiplier())
			check(clawed < height - reach, "%s: a single run with claws passes %.2f m under a high-value credit (%.2f m high, %.1f m along; it reaches %.1f m)"
				% [zone.id, height - clawed, height, float(g["at"]), claws])
		print("  %s at %.1f m/s: one wall run reaches %.1f m, with claws %.1f m; %d high-value credits at %.2f m high from %.1f m, after %d hops; the stretch %.0f m"
			% [zone.id, zone.run_speed, path.distance_at(path.run_end(0)), claws, gems.size(), height, float(gems[0]["at"]),
			int(shape["run"]), float(shape["to"]) - float(shape["from"])])


## The height of a single wall run from the floor (no hop) t seconds after its entry, its slide `multiplier` times as
## long (Player._update_wall); 0 once it has ended.
func _single_run_height(mt: MovementTuning, tt: float, multiplier: float) -> float:
	if tt < mt.wall_entry_time:
		return mt.wall_entry_height * (1.0 - pow(1.0 - tt / mt.wall_entry_time, 2.0))
	var s: float = (tt - mt.wall_entry_time) / (mt.wall_slide_time * multiplier)
	if s >= 1.0:
		return 0.0
	return mt.wall_exit_height + (mt.wall_entry_height - mt.wall_exit_height) * (1.0 - pow(s, mt.wall_descent_exponent))


# --- Placement --------------------------------------------------------------------------------------

func _test_campaign() -> void:
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var builds: int = 0
	var with_line: int = 0
	var open_walls: Array[String] = []
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame():
			continue
		if WITHOUT.has(s.zone.id):
			check(s.level.wall_hop_lines == 0, "%s asks for no wall-hop credits (GDD §7: from Gangland on)" % s.id)
		else:
			check(s.level.wall_hop_lines == 1, "%s asks for a line of wall-hop credits (GDD §7: about once a level)" % s.id)
		for lanes: int in LANE_COUNTS:
			var config: LevelConfig = campaign.configure(s, lanes)
			var tag: String = "%s lanes=%d" % [s.id, lanes]
			# T-SPEED: the level's own default build (LayoutCache), shared with test_campaign and others.
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var layout: LevelLayout = gen.layout
			LayoutChecks.check_wall_hops(self, layout, config, tag)
			if WITHOUT.has(s.zone.id):
				check(layout.wall_hops.is_empty(), "no wall-hop line " + tag)
				continue
			check(layout.wall_hops.size() <= 1, "at most one line a level %s" % tag)
			if s.zone.id == OPEN_WALLS:
				open_walls.append("%s %d" % [tag, layout.wall_hops.size()])
			else:
				builds += 1
				with_line += 0 if layout.wall_hops.is_empty() else 1
			if layout.wall_hops.is_empty():
				continue
			# The stars (GameRules.stars_for, a share of the stars' best score): the other credits alone clear three.
			var gems: int = 0
			for c: Dictionary in layout.credits:
				gems += int(c["value"]) if c.has(WallHopPlacement.GEM) else 0
			check(gems == t.gems * t.gem_value and layout.star_credit_value() + gems <= layout.total_credit_value(),
				"the stars' best score (%d) leaves the high-value credits out (%d) %s" % [layout.star_credit_value(), gems, tag])
			check(rules.stars_for(true, layout.star_credit_value(), layout.star_credit_value()) == 3,
				"every credit but the high-value ones clears the three-star line %s" % tag)
			if lanes == 5:
				found.append({"id": s.id, "config": config, "layout": layout, "line": layout.wall_hops[0]})
	check(builds > 0 and float(with_line) >= MIN_SHARE * builds,
		"most builds from Gangland on have a line: %d of %d outside the Beach (at least %.0f%%)" % [with_line, builds, MIN_SHARE * 100.0])
	print("  wall-hop lines: %d of %d builds outside the Beach at 3, 5 and 6 lanes; the Beach's open walls: %s"
		% [with_line, builds, ", ".join(open_walls)])
	# The same seed builds the same lines (an uncached rebuild against the shared build).
	for id: String in ["gangland/1", "golden/3"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		var patterns: Array = LevelGenerator.load_for(config)
		var cached: LevelLayout = LayoutCache.generate(config, tuning, patterns)
		var fresh: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
		check(JSON.stringify(cached.to_dict()) == JSON.stringify(fresh.to_dict()) and not fresh.wall_hops.is_empty(),
			"the same seed builds the same level, its wall-hop line too, %s" % id)


## A level that asks for no line is built as before: the same layout as with one, but for the line (its record and its
## credits), whose placement draws from a stream of its own and only adds credits.
func _test_without() -> void:
	for id: String in ["gangland/2", "corporate/1"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		var patterns: Array = LevelGenerator.load_for(config)
		var with: LevelLayout = LayoutCache.generate(config, tuning, patterns)
		var none_config: LevelConfig = config.duplicate() as LevelConfig
		none_config.wall_hop_lines = 0
		var none: LevelLayout = LevelGenerator.new().generate(none_config, tuning, patterns)
		var stripped: LevelLayout = with.copy()
		stripped.wall_hops.clear()
		var kept: Array[Dictionary] = []
		for c: Dictionary in stripped.credits:
			if not c.has(WallHopPlacement.GEM) and not c.has(WallHopPlacement.LEAD):
				kept.append(c)
		stripped.credits = kept
		check(none.wall_hops.is_empty() and not none.to_dict().has("wall_hops") and not with.wall_hops.is_empty(),
			"%s: a line with the count at 1, none at 0" % id)
		# The credit pass sorts its credits by distance, and two at one distance may come in either order.
		var a: Dictionary = stripped.to_dict()
		var b: Dictionary = none.to_dict()
		var credits_a: Array = a["credits"].map(func(c: Dictionary) -> String: return JSON.stringify(c))
		var credits_b: Array = b["credits"].map(func(c: Dictionary) -> String: return JSON.stringify(c))
		credits_a.sort()
		credits_b.sort()
		a.erase("credits")
		b.erase("credits")
		check(JSON.stringify(a) == JSON.stringify(b) and credits_a == credits_b,
			"%s: the level built without its line is the same but for it (%d credits, %d)" % [id, credits_a.size(), credits_b.size()])


# --- Real physics -----------------------------------------------------------------------------------

func _test_rides() -> void:
	check(found.size() >= 2, "lines to ride at 5 lanes (%d)" % found.size())
	if found.is_empty():
		return
	await _ride(found[0])
	if found.size() > 1:
		await _ride(found[-1])


## An excerpt of `pick`'s line on a fresh straight track: its credits, its entry ENTRY_AT metres along. {layout, line}.
static func _excerpt(pick: Dictionary) -> Dictionary:
	var source: LevelLayout = pick["layout"]
	var w: Dictionary = pick["line"]
	var shift: float = ENTRY_AT - float(w["entry"])
	var line: Dictionary = w.duplicate(true)
	for key: String in ["entry", "start", "end", "gems_from", "gems_to"]:
		line[key] = float(w[key]) + shift
	var out := RunSim.layout(source.lane_count, float(line["end"]) + 120.0)
	out.wall_hops.append(line)
	for c: Dictionary in source.credits:
		if (c.has(WallHopPlacement.GEM) or c.has(WallHopPlacement.LEAD)) and int(c["side"]) == int(w["side"]) \
				and float(c["at"]) >= float(w["start"]) and float(c["at"]) <= float(w["end"]):
			var k: Dictionary = c.duplicate(true)
			k["at"] = float(c["at"]) + shift
			out.credits.append(k)
	return {"layout": out, "line": line}


## Rides `pick`'s line (see the header).
func _ride(pick: Dictionary) -> void:
	var config: LevelConfig = pick["config"]
	var mt: MovementTuning = config.movement_for(tuning)
	var v: float = mt.run_speed
	var ex: Dictionary = _excerpt(pick)
	var layout: LevelLayout = ex["layout"]
	var line: Dictionary = ex["line"]
	var side: int = int(line["side"])
	var outer: int = layout.outer_lane(side)
	var entry: float = float(line["entry"])
	var tag: String = "(%s lanes=5, the %s wall's line at %.0f m)" % [pick["id"], "left" if side < 0 else "right", float(pick["line"]["entry"])]
	var lead: int = 0
	var gems: int = 0
	var value: int = 0
	for c: Dictionary in layout.credits:
		lead += 1 if c.has(WallHopPlacement.LEAD) else 0
		gems += 1 if c.has(WallHopPlacement.GEM) else 0
		value += int(c["value"])
	var seconds: float = (float(line["end"]) + 30.0) / v
	var path := WallHopPath.of(entry, mt, v, t.hop_height)
	# The reference hopper collects every credit of the line, its fresh runs peaking where WallHopPath says.
	var r: Dictionary = await _drive(layout, mt, outer, seconds, _hopper(side, entry, t.hop_height, float(line["gems_to"]) + 1.0))
	check(bool(r["alive"]) and int(r["pickups"]) == lead + gems and int(r["credits"]) == value,
		"the reference hopper collects every credit of the line (%d of %d, %d of %d credits) %s"
		% [r["pickups"], lead + gems, r["credits"], value, tag])
	var peaks: Array[float] = _peaks(r["trace"])
	var want: Array[float] = []
	for run: Dictionary in path.runs:
		if float(run["start"]) <= path.time_at(float(line["gems_to"])):
			want.append(float(run["peak"]))
	var close: bool = peaks.size() >= want.size()
	for i: int in mini(peaks.size(), want.size()):
		close = close and absf(peaks[i] - want[i]) <= 0.1
	check(close, "its fresh wall runs peak where WallHopPath says (%s, the path %s) %s" % [peaks, want, tag])
	# Another rhythm, as a player finding the move might keep: hops low on the wall, whose fresh runs peak elsewhere
	# (printed), and the same with a hop as the high-value credits come near, up to them: all of them.
	var others: PackedStringArray = []
	for hop_at: float in [0.6, 1.0]:
		var o: Dictionary = await _drive(layout, mt, outer, seconds, _hopper(side, entry, hop_at, float(line["gems_to"]) + 1.0))
		others.append("hopping at %.1f m alone %d of %d" % [hop_at, o["gems"], gems])
		for lead_s: float in [0.15, 0.35]:
			var n: Dictionary = await _drive(layout, mt, outer, seconds, _hopper(side, entry, hop_at, float(line["gems_to"]) + 1.0,
				float(line["gems_from"]) - lead_s * v))
			check(bool(n["alive"]) and int(n["gems"]) == gems,
				"a runner who stays on with hops at %.1f m and hops %.2f s before the high-value credits collects them all (%d of %d) %s"
				% [hop_at, lead_s, n["gems"], gems, tag])
	print("  %s: the reference hopper takes all %d high-value credits; %s" % [tag, gems, ", ".join(others)])
	# One wall run from the entry: the lead-in, none of the high-value credits; with claws too.
	for claws: bool in [false, true]:
		var loadout := Loadout.new()
		if claws:
			loadout.tiers[&"claws"] = 1
		var once: Dictionary = await _drive(layout, mt, outer, seconds, _wall_runner(side, entry, false), loadout)
		check(bool(once["alive"]) and int(once["pickups"]) == lead and int(once["credits"]) == lead * t.lead_value,
			"one wall run from the entry%s collects the lead-in (%d of %d) but none of the high-value credits (%d credits) %s"
			% [" with claws" if claws else "", once["pickups"], lead, once["credits"], tag])
	# Straight back onto the wall each time a run drops them (from the floor, or still in the air from its end): under them.
	var again: Dictionary = await _drive(layout, mt, outer, seconds, _wall_runner(side, entry, true))
	check(int(again["gems"]) == 0, "a runner who steps straight back onto the wall each time a run drops them takes none of the high-value credits (%d) %s"
		% [again["gems"], tag])
	# A step onto the wall from the floor further along, at any point up to the high-value credits: under them.
	var gems_from: float = float(line["gems_from"])
	var d: float = path.distance_at(path.run_end(0))
	var late: int = 0
	while d < gems_from:
		var late_r: Dictionary = await _drive(layout, mt, outer, seconds, _late_entry(side, d))
		late += int(late_r["gems"])
		d += 4.0
	check(late == 0, "a runner who steps onto the wall from the floor past one wall run's reach takes none of them (%d) %s" % [late, tag])
	# The same with Magnet I, every 2 m up to just past them: the magnet leaves them alone (task N1's review: it pulled all
	# three from a step on 2-19 m before them in Gangland 1).
	var magnet := Loadout.new()
	magnet.tiers[&"magnet"] = 1
	var pulled: int = 0
	var radius: float = 0.0
	var md: float = path.distance_at(path.run_end(0))
	while md <= gems_from + 2.0:
		var mr: Dictionary = await _drive(layout, mt, outer, seconds, _late_entry(side, md), magnet)
		pulled += int(mr["gems"])
		radius = maxf(radius, float(mr["magnet"]))
		md += 2.0
	check(radius > 0.0 and pulled == 0,
		"with Magnet I (%.1f m), a runner who steps onto the wall from the floor past one wall run's reach, never hopping, takes none of them (%d) %s"
		% [radius, pulled, tag])


## Runs a full world over a copy of `layout` from `start_lane` for up to `seconds`, calling `each.call(player)` before
## every physics frame. {trace (d, h, surface), alive, pickups, credits, gems (the high-value credits collected),
## magnet (the pull radius the loadout gave)}.
func _drive(layout: LevelLayout, mt: MovementTuning, start_lane: int, seconds: float, each: Callable,
		loadout: Loadout = null) -> Dictionary:
	var world: RunWorld = sim.build_world(layout.copy(), loadout, mt)
	world.player.setup(mt, world.geo, start_lane)
	var out := {"trace": [], "gems": 0}
	world.credits.collected.connect(func(value: int, _pos: Vector3) -> void:
		if value == t.gem_value:
			out["gems"] = int(out["gems"]) + 1)
	var player: Player = world.player
	await tree.physics_frame
	player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		each.call(player)
		await tree.physics_frame
		(out["trace"] as Array).append({"d": player.distance, "h": player.h, "surface": player.surface_name()})
		if not player.alive:
			break
	out["alive"] = player.alive
	out["pickups"] = world.score.credit_pickups
	out["credits"] = world.score.credits
	out["magnet"] = world.credits.magnet_radius
	await sim.free_world(world)
	return out


## The highest the runner was on each stay on a wall in `trace`, in order.
static func _peaks(trace: Array) -> Array[float]:
	var out: Array[float] = []
	var on: bool = false
	for x: Dictionary in trace:
		if String(x["surface"]) == "wall":
			if not on:
				out.append(float(x["h"]))
				on = true
			else:
				out[-1] = maxf(out[-1], float(x["h"]))
		else:
			on = false
	return out


## A driver for the reference hopper (WallHopPath): onto wall `side` from the outer lane at `entry`, then, each time its
## wall run (past its entry) has come down to `hop_at`, a hop: jump, and back toward the wall HOP_FRAMES frames later;
## no more hops past `until`. With `extra` (a track distance), one more hop as it gets there, wherever its run is.
func _hopper(side: int, entry: float, hop_at: float, until: float, extra: float = INF) -> Callable:
	var state := {"wall": 0, "wait": 0, "on": false, "extra": extra}
	var toward: StringName = &"move_left" if side < 0 else &"move_right"
	var settle: int = ceili(tuning.wall_entry_time * Engine.physics_ticks_per_second)
	return func(p: Player) -> void:
		state["wall"] = int(state["wall"]) + 1 if p.surface == Player.Surface.WALL else 0
		if int(state["wait"]) > 0:
			state["wait"] = int(state["wait"]) - 1
			if int(state["wait"]) == 0:
				p.press(toward)
			return
		if not bool(state["on"]) and p.distance >= entry and p.surface == Player.Surface.FLOOR:
			state["on"] = true
			p.press(toward)
			return
		var now: bool = p.distance >= float(state["extra"])
		if p.surface == Player.Surface.WALL and int(state["wall"]) > settle and (p.h <= hop_at or now) and p.distance < until:
			if now:
				state["extra"] = INF
			p.press(&"jump")
			state["wait"] = WallHopPath.HOP_FRAMES


## A driver for a wall runner who never hops: onto wall `side` from the outer lane at `entry`; with `again`, back toward
## the wall every frame it's off it after that (straight back on as a run drops them, still in the air, or from the
## floor).
func _wall_runner(side: int, entry: float, again: bool) -> Callable:
	var state := {"on": false}
	var toward: StringName = &"move_left" if side < 0 else &"move_right"
	return func(p: Player) -> void:
		if p.surface == Player.Surface.WALL:
			return
		if not bool(state["on"]) and p.distance >= entry:
			state["on"] = true
			p.press(toward)
		elif again and bool(state["on"]):
			p.press(toward)


## A driver for a runner who stays on the floor in the outer lane and steps onto wall `side` at track distance `at`,
## never hopping.
func _late_entry(side: int, at: float) -> Callable:
	var state := {"on": false}
	var toward: StringName = &"move_left" if side < 0 else &"move_right"
	return func(p: Player) -> void:
		if not bool(state["on"]) and p.distance >= at and p.surface == Player.Surface.FLOOR:
			state["on"] = true
			p.press(toward)
