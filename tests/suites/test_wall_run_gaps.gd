extends SkinSuite
## Wall-run gaps (task J2; the owner, October 15, 2026, docs/USER_REQUESTS.md: "sections, especially in later zones and
## levels, where there is a gap over the ENTIRE floor (every lane), and the only way to cross is a wall run ...
## consider a wall an acceptable/safe path"; WallRunGapPlacement, wall_run_gaps_rules.gd). Checked here:
## - the numbers, at every zone's run speed: the gap is longer than any jump (a full jump with its jump grace, a speed
##   pad's or a ramp's whole boost and the dash all the way); a standard wall run (no claws, no wall hop) from the lit
##   stretch's first metre leaves the wall past the far edge, one from its last drops the runner onto the landing
##   floor; the run-in and the lit stretch give time to cross every lane of a 6-lane track; the lit wall stays clear
##   past the longest wall run (claws and the dash); claws add less to a wall run than the run-in and the lit stretch
##   last (a runner who passed a dash wall on a wall comes down before the gap, WallRunGapPlacement.past_dash_wall);
## - the generator: every campaign level with the feature (from Marketplace 1 on), at 3, 5 and 6 lanes on its own seed,
##   has at least one, every one keeping its rules (LayoutChecks.check_wall_run_gaps) with a floor route across it
##   (FloorRoute: the wall run from its lit stretch, the only move that crosses); per zone, how many a build (printed);
##   none in a level without the feature (the City, Gangland, quick play), in a boss arena, nor any hole marked as one;
##   the same seed builds the same level;
## - real physics at 3, 5 and 6 lanes, both walls: a step onto the lit wall early, midway or late on the lit stretch
##   carries the runner across onto the landing floor; with claws too; a jump, a jump with the dash, or the dash alone
##   never crosses, nor a step onto the wall well before the lit stretch; the grapple's save and a revive after a fall
##   into the gap put the runner on the lit wall, whose run carries them across (and off the wall over the landing
##   floor, even from the gap's far edge);
## - the track: only the Marketplace's skin lights the lit wall (task L5, the owner, October 17, 2026: no guide in the
##   zones after the one that introduces the mechanic; the hole itself is the cue; no gap needs a speed boost, so no
##   zone keeps it for one) and the grey box and the earlier zones' skins do (they never have one in a campaign
##   level): the ramps' green chevrons (never a hazard colour) over exactly the stretch to step on and the gap, on the
##   wall face, facing the street, seamless across chunks, nothing on the other wall; every other skin draws nothing
##   of it; both build without errors;
## - the attacks a runner can't dodge on the wall hold off while a crossing is in their reach (a heli drone's barrage, a
##   Bad Dream's slash, an Enforcer Truck's volley, an Octodog's wind-up a wait for its turn moved on: their
##   _wall_run_in_reach).

const FEATURE: String = "wall_run_gaps"
const DroneScript = preload("res://scripts/enemies/drone.gd")
## The levels that must have none (they come before the feature).
const WITHOUT: Array = ["city/1", "city/2", "city/3", "gangland/1", "gangland/2", "gangland/3"]
## Where the synthetic track's wall-run gap's clear run-in starts (metres), on a 400 m track.
const APPROACH_AT: float = 100.0
## Metres of the runner's run an Octodog's charge winding up now plays out over, for _test_holds (any window shows
## the hold; the dog's own, OctodogTuning.window_length, is a little longer).
const DOG_WINDOW: float = 20.0

var sim: RunSim
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	_test_numbers()
	_test_campaign()
	_test_without()
	_test_wide_gap_room()
	await _test_crossings()
	await _test_claws()
	await _test_saves()
	await _test_skins()
	await _test_holds()


## The campaign's levels with the feature (built steps, mini-games aside).
func _levels() -> Array[CampaignStep]:
	var out: Array[CampaignStep] = []
	for s: CampaignStep in campaign.steps():
		if s.is_level() and not s.is_minigame() and s.level.has_feature(FEATURE):
			out.append(s)
	return out


## A 400 m track of `lanes` lanes with one wall-run gap (WallRunGapPlacement.make, at the shared tuning's speed) whose
## clear run-in starts at APPROACH_AT, its lit wall on `side`: its holes in every lane, its entry.
static func _track(lanes: int, side: int, mt: MovementTuning) -> LevelLayout:
	var l := RunSim.layout(lanes, 400.0)
	var w: Dictionary = WallRunGapPlacement.make(WallRunGapPlacement.shape_for(mt, mt.run_speed), APPROACH_AT, side)
	for lane: int in lanes:
		l.gaps.append({"lane": lane, "start": float(w["start"]), "end": float(w["end"]), LevelLayout.WALL_RUN_HOLE: true})
	l.wall_run_gaps.append(w)
	return l


func _test_numbers() -> void:
	check(ResourceLoader.exists(WallRunGapTuning.PATH) and load(WallRunGapTuning.PATH) is WallRunGapTuning,
		"the shared numbers load (data/tuning/wall_run_gaps.tres)")
	var t: WallRunGapTuning = WallRunGapPlacement.tuning()
	var pt: PowerupTuning = WallRunGapPlacement.powerups()
	var speeds: Dictionary = {"the reference speed": tuning}
	for s: CampaignStep in _levels():
		speeds[String(s.zone.id)] = campaign.configure(s, 3).movement_for(tuning)
	check(speeds.size() >= 7, "every zone from the Marketplace on has them (%s)" % [speeds.keys()])
	for key: String in speeds:
		var m: MovementTuning = speeds[key]
		var v: float = m.run_speed
		var shape: WallRunGapPlacement.Shape = WallRunGapPlacement.shape_for(m, v, t, pt)
		var tag: String = "(%s, %.1f m/s: gap %.1f m)" % [key, v, shape.gap]
		var fast: float = v + maxf(m.speed_pad_boost, m.ramp_speed_boost)
		var reach: float = m.jump_distance(fast) + m.coyote_time * fast + pt.dash_duration * pt.dash_speed_bonus
		check(shape.gap > reach + 2.0, "no jump crosses it, with every boost and the dash (%.1f m) %s" % [reach, tag])
		check(shape.gap > m.jump_distance(v) * LevelConfig.new().max_gap_jump_fraction,
			"longer than any hole a level asks a runner to jump " + tag)
		var wall_run: float = (m.wall_entry_time + m.wall_slide_time) * v
		check(is_equal_approx(shape.window + shape.gap + shape.exit_margin, wall_run),
			"a standard wall run from the lit stretch's first metre leaves the wall exit_margin past the far edge " + tag)
		var latest: float = shape.window + m.coyote_time * v + wall_run + WallRunGapPlacement.drop_seconds(m) * v
		check(shape.approach + latest <= shape.approach + shape.window + shape.gap + shape.landing
			- t.landing_slack_seconds * v + 0.01,
			"one from its last metre, with the jump grace, drops the runner onto the landing floor " + tag)
		check(t.approach_seconds + t.entry_window_seconds >= 5.0 * m.lane_switch_time + 0.3,
			"the run-in and the lit stretch give time to cross 6 lanes to the wall " + tag)
		check(shape.wall_after >= shape.longest_seconds * v + pt.dash_duration * pt.dash_speed_bonus,
			"the lit wall stays clear past the longest wall run, with claws and the dash " + tag)
		check(shape.longest_seconds > shape.wall_run_seconds, "claws only lengthen the wall run " + tag)
		# A dash wall keeps a standard wall run past it off the clear stretch (WallRunGapPlacement.past_dash_wall).
		check(shape.longest_seconds - shape.wall_run_seconds < t.approach_seconds + t.entry_window_seconds,
			"claws add less to a wall run than the run-in and the lit stretch last: a clawed runner past a dash wall comes down before the gap " + tag)


func _test_campaign() -> void:
	var zones: Dictionary = {}
	var levels: Array[CampaignStep] = _levels()
	check(not levels.is_empty() and levels[0].id == "marketplace/1", "the Marketplace's first level brings them in (%s)"
		% [levels[0].id if not levels.is_empty() else "none"])
	for s: CampaignStep in levels:
		check(s.zone.id != &"city" and s.zone.id != &"gangland", "never in the first zones (%s)" % s.id)
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(s, lanes)
			var tag: String = "%s lanes=%d" % [s.id, lanes]
			# T-SPEED: the level's own default build, shared with test_campaign and the other suites (LayoutCache).
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var layout: LevelLayout = gen.layout
			check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
			check(not layout.wall_run_gaps.is_empty(), "the level has its wall-run gaps %s (%s)" % [tag,
				gen.wall_run_gap_result.get("constraints", [])])
			check(int(gen.wall_run_gap_result.get("placed", -1)) == layout.wall_run_gaps.size(),
				"the report counts them %s" % tag)
			LayoutChecks.check_wall_run_gaps(self, layout, config, tag)
			var mt: MovementTuning = config.movement_for(tuning)
			var grid := FloorRoute.new(layout, mt)
			for w: Dictionary in layout.wall_run_gaps:
				var where: String = "(%.0f m, %s wall) %s" % [float(w["start"]), "left" if int(w["side"]) < 0 else "right", tag]
				check(float(w["start"]) >= gen.feature_start(FEATURE), "nothing before the feature's start " + where)
				var from: float = grid.clear_start(float(w["entry"]))
				var route: Dictionary = grid.find(from, float(w["landing"]))
				check(bool(route["ok"]), "a way across it %s: %s" % [where, route.get("reason", "")])
				# Onto a lit wall: an extended wall run with both walls lit (task O1) may be crossed on either.
				var towards: Array[StringName] = []
				for side: int in WallRunGapPlacement.sides_of(w):
					towards.append(&"move_left" if side < 0 else &"move_right")
				var stepped: bool = false
				for a: Array in route.get("actions", []):
					if towards.has(StringName(a[1])) and float(a[0]) >= float(w["entry"]) - 0.01 and float(a[0]) <= float(w["start"]):
						stepped = true
				check(stepped, "the way across is a step onto its lit wall from the lit stretch " + where)
			var key: String = String(s.zone.id)
			zones[key] = Vector2i(zones.get(key, Vector2i.ZERO)) + Vector2i(layout.wall_run_gaps.size(), 1)
	var parts: PackedStringArray = []
	for key: String in zones:
		var n: Vector2i = zones[key]
		parts.append("%s %.2f" % [key, float(n.x) / float(n.y)])
	print("  wall-run gaps a build, by zone (own seeds, 3/5/6 lanes): %s" % ", ".join(parts))
	# The same seed builds the same level (a fresh build against another fresh one).
	var config: LevelConfig = campaign.configure(campaign.step("dead_zone/1"), 5)
	var a: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
	var b: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
	check(not a.wall_run_gaps.is_empty() and JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()),
		"the same seed builds the same wall-run gaps")


func _test_without() -> void:
	for id: String in WITHOUT:
		var s: CampaignStep = campaign.step(id)
		check(not s.level.has_feature(FEATURE), "%s doesn't list the feature" % id)
		var config: LevelConfig = campaign.configure(s, 5)
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		_check_none(layout, id)
	var quick: LevelConfig = load(LEVEL_PATH) as LevelConfig
	_check_none(LayoutCache.generate(quick, tuning, LevelGenerator.load_for(quick)), "quick play")
	# A boss arena never has one, even with the feature listed (its track is the fight's).
	var arena: LevelConfig = campaign.configure(campaign.step("golden/1"), 5)
	arena.id = &"golden_arena"
	var gen := LevelGenerator.new()
	_check_none(gen.generate(arena, tuning, LevelGenerator.load_for(arena)), "a boss arena")
	check(gen.wall_run_gap_result.is_empty(), "the pass reports nothing in a boss arena")


## A level's first wall-run gap makes room for a wider gap it crowds out (LevelGenerator._make_wide_gap_room): what a
## finished build keeps for its wider gaps in the one more build (WallRunGapPlacement.wide_gap_reserve) is its first
## wall-run gap's clear stretch where its wider gaps fall short, and nothing where they're all there, where it has no
## wall-run gap, or in the level that brings the feature in; and Golden 2 at 3 lanes on its own seed, whose one clear
## stretch both want, has every wider gap and its wall-run gap elsewhere, its own last resort having made the room.
func _test_wide_gap_room() -> void:
	var mt: MovementTuning = tuning
	var shape: WallRunGapPlacement.Shape = WallRunGapPlacement.shape_for(mt, mt.run_speed)
	var later: Dictionary = WallRunGapPlacement.make(shape, 1500.0, -1)
	var first: Dictionary = WallRunGapPlacement.make(shape, 500.0, 1)
	var short := {"rows": [Vector2(2000.0, 2012.0)]}
	var full := {"rows": [Vector2(2000.0, 2012.0), Vector2(2600.0, 2612.0)]}
	for id: String in ["golden/2", "marketplace/1"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 3)
		var lay: LevelLayout = RunSim.layout(3, 3000.0)
		lay.wall_run_gaps.assign([later, first])
		var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, lay)
		gen.wide_gap_result = short
		var reserve: Array[Vector2] = WallRunGapPlacement.wide_gap_reserve(gen)
		if id == "marketplace/1":
			check(reserve.is_empty(), "the level that brings them in keeps its first where it is introduced")
			continue
		check(config.wide_gaps == 2 and reserve.size() == 1 and reserve[0] == WallRunGapPlacement.keep_out(first),
			"a build a wider gap short keeps its first wall-run gap's clear stretch for them (%s)" % [reserve])
		gen.wide_gap_result = full
		check(WallRunGapPlacement.wide_gap_reserve(gen).is_empty(), "a build with every wider gap keeps nothing")
		gen.wide_gap_result = short
		lay.wall_run_gaps.clear()
		check(WallRunGapPlacement.wide_gap_reserve(gen).is_empty(), "a build with no wall-run gap keeps nothing")
	var golden: LevelConfig = campaign.configure(campaign.step("golden/2"), 3)
	var built: LevelGenerator = LayoutCache.generator(golden, tuning, LevelGenerator.load_for(golden))
	var made: bool = false
	for c: String in built.wall_run_gap_result.get("constraints", []):
		made = made or c.begins_with("the last resort took out")
	check(WideGapPlacement.rows_of(built).size() == golden.wide_gaps and not built.layout.wall_run_gaps.is_empty() and made
		and WallRunGapPlacement.wide_gap_reserve(built).is_empty() and built.warnings.is_empty(),
		"Golden 2 at 3 lanes has every wider gap and its wall-run gap, its last resort having made the room (%s)"
		% [built.wall_run_gap_result.get("constraints", [])])


func _check_none(layout: LevelLayout, tag: String) -> void:
	var holes: int = 0
	for g: Dictionary in layout.gaps:
		holes += 1 if LevelLayout.is_wall_run_hole(g) else 0
	check(layout.wall_run_gaps.is_empty() and holes == 0 and not layout.to_dict().has("wall_run_gaps"),
		"no wall-run gap in %s" % tag)


## A step onto the lit wall anywhere on the lit stretch crosses; nothing else does.
func _test_crossings() -> void:
	var shape: WallRunGapPlacement.Shape = WallRunGapPlacement.shape_for(tuning, tuning.run_speed)
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			var layout: LevelLayout = _track(lanes, side, tuning)
			var w: Dictionary = layout.wall_run_gaps[0]
			var entry: float = float(w["entry"])
			var start: float = float(w["start"])
			var end: float = float(w["end"])
			var landing: float = float(w["landing"])
			var outer: int = layout.outer_lane(side)
			var toward: StringName = &"move_left" if side < 0 else &"move_right"
			var tag: String = "(%d lanes, %s wall)" % [lanes, "left" if side < 0 else "right"]
			var seconds: float = (landing + 20.0) / tuning.run_speed
			for at: float in [entry + 0.3, (entry + start) * 0.5, start - 0.8]:
				var r: Dictionary = await sim.run(layout, outer, seconds, [[at, toward]], [end + 1.0, landing])
				var what: String = "a step onto the wall %.1f m into the lit stretch %s" % [at - entry, tag]
				check(bool(r["alive"]) and r["at"][end + 1.0]["alive"], "%s carries the runner across: %s" % [what, r["cause"]])
				check(r["at"][landing]["surface"] == "floor" and float(r["at"][landing]["h"]) == 0.0
					and int(r["at"][landing]["lane"]) == outer, "%s lands them on the landing floor: %s" % [what, r["at"][landing]])
				check((r["events"] as Array).has(&"wall_enter") and (r["events"] as Array).has(&"wall_exit"),
					"%s is a wall run to its end %s" % [what, r["events"]])
			var middle: int = lanes / 2
			# A jump at the edge, a jump with the dash, the dash alone: all fall in.
			for case: Array in [["a jump", [[start - 1.0, &"jump"]]],
					["a jump with the dash", [[start - 1.0, &"jump"], [start - 0.5, &"dash"]]],
					["the dash alone", [[start - 3.0, &"dash"]]]]:
				var r: Dictionary = await sim.run(layout, middle, seconds, case[1])
				check(not bool(r["alive"]) and String(r["cause"]) == "fell", "%s never crosses it %s (%s)" % [case[0], tag, r["cause"]])
			# A step onto the wall well before the lit stretch: the wall run ends over the gap.
			var early: float = entry - shape.exit_margin - 8.0
			var r: Dictionary = await sim.run(layout, outer, seconds, [[early, toward]])
			check(not bool(r["alive"]) and String(r["cause"]) == "fell",
				"a step onto the wall %.1f m before the lit stretch drops the runner into the gap %s" % [entry - early, tag])


## Claws lengthen the wall run: a runner with them crosses from the lit stretch's first metre, still on the clear wall.
func _test_claws() -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = _track(lanes, 1, tuning)
		var w: Dictionary = layout.wall_run_gaps[0]
		var loadout := Loadout.new()
		loadout.tiers[&"claws"] = 1
		var world: RunWorld = sim.build_world(layout, loadout)
		world.player.setup(tuning, world.geo, lanes - 1)
		world.player.apply_loadout(DamageRules.Armor.create(world.rules, 0, false), 0, 0, true,
			world.powerup_tuning.claws_wall_time_multiplier)
		var r: Dictionary = await sim.step_world(world, (float(w["wall_to"]) + 30.0) / tuning.run_speed,
			[[float(w["entry"]) + 0.3, &"move_right"]], [float(w["end"]) + 1.0, float(w["wall_to"]) + 25.0])
		var tag: String = "(%d lanes)" % lanes
		check(bool(r["alive"]) and r["at"][float(w["end"]) + 1.0]["surface"] == "wall",
			"with claws the runner is still on the wall past the gap %s: %s" % [tag, r["at"]])
		check(r["at"][float(w["wall_to"]) + 25.0]["surface"] == "floor" and bool(r["at"][float(w["wall_to"]) + 25.0]["alive"]),
			"and comes down on the floor past it %s" % tag)
		await sim.free_world(world)


## The grapple's save and a revive after a fall into the gap put the runner on the lit wall (WallRunGapPlacement
## .grapple_save, RunWorld sets it), whose run carries them across, and off it over the landing floor even from the
## gap's far edge.
func _test_saves() -> void:
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			var layout: LevelLayout = _track(lanes, side, tuning)
			var w: Dictionary = layout.wall_run_gaps[0]
			var tag: String = "(%d lanes, %s wall)" % [lanes, "left" if side < 0 else "right"]
			var seconds: float = (float(w["landing"]) + 30.0) / tuning.run_speed
			# The grapple: a runner in the middle lane runs into the gap.
			var world: RunWorld = sim.build_world(layout)
			check(world.player.grapple_save.is_valid(), "a level with wall-run gaps sets the save " + tag)
			world.player.grapples = 1
			var r: Dictionary = await sim.step_world(world, seconds, [], [float(w["landing"])])
			check((r["events"] as Array).has(&"grapple") and (r["events"] as Array).has(&"wall_enter"),
				"the grapple saves the runner onto the lit wall %s: %s" % [tag, r["events"]])
			check(bool(r["alive"]) and float(r["distance"]) > float(w["landing"]),
				"and its wall run carries them across %s: %s at %.0f m" % [tag, r["cause"], float(r["distance"])])
			check(world.player.grapples == 0, "the grapple is spent " + tag)
			await sim.free_world(world)
			# A revive: the runner falls in and dies, then comes back on the lit wall.
			world = sim.build_world(layout)
			r = await sim.step_world(world, seconds)
			check(not bool(r["alive"]) and String(r["cause"]) == "fell", "without the grapple the gap is a fall %s" % tag)
			var died_at: float = world.player.distance
			world.player.revive()
			check(world.player.surface == Player.Surface.WALL and world.player.wall_side == side,
				"a revive after the fall puts the runner on the lit wall %s" % tag)
			r = await sim.step_world(world, seconds)
			check(bool(r["alive"]) and float(r["distance"]) > float(w["landing"]),
				"and its wall run carries them across %s (fell at %.0f m: %s, %.0f m)" % [tag, died_at, r["cause"],
				float(r["distance"])])
			await sim.free_world(world)
			# A save at the gap's far edge: a whole wall run from there would carry the runner past the landing floor; it
			# leaves the wall in time to come down on it.
			world = sim.build_world(layout)
			r = await sim.step_world(world, seconds)
			world.player.distance = float(w["end"]) + 2.0
			world.player.revive()
			check(world.player.surface == Player.Surface.WALL, "a revive at the gap's far edge puts the runner on the lit wall " + tag)
			var down: float = float(w["landing"]) - 1.0
			r = await sim.step_world(world, seconds, [], [down])
			check(bool(r["alive"]) and float(r["distance"]) > float(w["landing"]) and r["at"].has(down)
				and r["at"][down]["surface"] == "floor",
				"and its wall run ends over the landing floor %s: %s, %s" % [tag, r["cause"], r["at"].get(down, {})])
			await sim.free_world(world)
	# Anywhere else the save is the old one: {} back, straight up.
	var plain: LevelLayout = _track(3, 1, tuning)
	var p := Player.new()
	p.distance = float(plain.wall_run_gaps[0]["landing"]) + 20.0
	check(WallRunGapPlacement.grapple_save(p, &"grapple", plain).is_empty(), "away from a wall-run gap the save is as it was")
	p.distance = float(plain.wall_run_gaps[0]["start"]) + 3.0
	check(int(WallRunGapPlacement.grapple_save(p, &"grapple", plain).get("wall", 0)) == 1, "over one it names the lit wall")
	p.free()


## A skin that lights the lit wall (ZoneSkin.show_wall_run_guide) draws the ramps' green chevrons over the stretch to
## step on and the gap, on the wall face, facing the street, their pattern running on across a chunk boundary, nothing
## on the other wall; one that doesn't draws none of it (task L5). Only the Marketplace's skin of the zones that have
## wall-run gaps shows it.
func _test_skins() -> void:
	for s: CampaignStep in _levels():
		var skin: ZoneSkin = campaign.configure(s, 3).skin
		var marketplace: bool = s.zone.id == &"marketplace"
		check(skin != null and skin.show_wall_run_guide == marketplace,
			"%s %s its wall-run gaps' lit walls (the Marketplace introduces them, no later zone shows the way)" % [
			s.zone.id, "lights" if marketplace else "leaves out"])
	var skins: Array[ZoneSkin] = [GreyboxSkin.new()]
	var names: Array[String] = ["grey box"]
	check(skins[0].show_wall_run_guide, "the grey box, quick play's and the review tools' default, lights them")
	for file: String in DirAccess.get_files_at("res://data/skins"):
		if file.ends_with(".tres"):
			skins.append(load("res://data/skins".path_join(file)) as ZoneSkin)
			names.append(file.get_basename())
	var shape: WallRunGapPlacement.Shape = WallRunGapPlacement.shape_for(tuning, tuning.run_speed)
	for i: int in skins.size():
		for lanes: int in [3, 5, 6]:
			var tag: String = "(%s, %d lanes)" % [names[i], lanes]
			var layout := RunSim.layout(lanes, 300.0)
			# The right one's lit stretch crosses the chunk boundary at 40 m; the left one comes later.
			for k: Array in [[1, 30.0 - shape.approach], [-1, 150.0]]:
				var w: Dictionary = WallRunGapPlacement.make(shape, float(k[1]), int(k[0]))
				for lane: int in lanes:
					layout.gaps.append({"lane": lane, "start": float(w["start"]), "end": float(w["end"]),
						LevelLayout.WALL_RUN_HOLE: true})
				layout.wall_run_gaps.append(w)
			var face: float = TrackGeometry.new(lanes, tuning).wall_x()
			var covered: Dictionary = {}
			var bad: Array[String] = []
			var drawn: Array[String] = []
			start_error_count()
			await visit_level(layout, skins[i], func(m: MeshInstance3D, arrays: Array, _mat: Material) -> void:
				if not String(m.name).contains("WallRunGuide"):
					return
				drawn.append(String(m.name))
				for rect: Dictionary in SkinSuite.rects_of(m, arrays):
					if int(rect["pattern"]) != MeshKit.PAT_CHEVRON:
						continue
					var o: Vector3 = rect["o"]
					var ou: Vector3 = rect["ou"]
					var side: int = 1 if o.x > 0.0 else -1
					var a: float = minf(-o.z, -ou.z)
					var b: float = maxf(-o.z, -ou.z)
					var w: Dictionary = {}
					for g: Dictionary in layout.wall_run_gaps:
						if int(g["side"]) == side and a >= float(g["entry"]) - 0.01 and b <= float(g["end"]) + 0.01:
							w = g
					var c: Color = rect["color"]
					if w.is_empty():
						bad.append("chevrons off any lit wall at %.1f-%.1f on side %d" % [a, b, side])
						continue
					if absf(absf(o.x) - face) > 0.1 or (rect["normal"] as Vector3).x * side > -0.9:
						bad.append("chevrons off the wall face or not facing the street at %.1f" % a)
					if not (c.g > c.r and c.g > c.b):
						bad.append("chevrons not green at %.1f: %s" % [a, c])
					var uv0: Vector2 = rect["uv0"]
					if absf(uv0.x - (-o.z - float(w["entry"])) / ZoneSkin.WALL_RUN_PANEL) > 0.01:
						bad.append("chevrons out of step at %.1f (uv %.3f)" % [a, uv0.x])
					covered[w] = float(covered.get(w, 0.0)) + (b - a))
			stop_error_count("building wall-run gaps' lit walls " + tag)
			if not skins[i].show_wall_run_guide:
				check(drawn.is_empty(), "a skin that leaves out the lit walls draws none of them %s (%s)" % [tag, drawn])
				continue
			check(not drawn.is_empty(), "a skin that lights the lit walls draws them %s" % tag)
			check(bad.is_empty(), "the lit walls are drawn right %s: %s" % [tag, bad.slice(0, 3)])
			for w: Dictionary in layout.wall_run_gaps:
				check(absf(float(covered.get(w, 0.0)) - (float(w["end"]) - float(w["entry"]))) < 0.05,
					"the lit wall at %.0f m covers the stretch to step on and the gap (%.2f of %.2f m) %s" % [float(w["entry"]),
					float(covered.get(w, 0.0)), float(w["end"]) - float(w["entry"]), tag])


## A heli drone's barrage, a Bad Dream's slash, an Enforcer Truck's volley and an Octodog's wind-up (one a wait for its
## turn moved on) hold off while a crossing (from the clear run-in to the gap's far edge) lies in their reach, and only
## then.
func _test_holds() -> void:
	var layout: LevelLayout = _track(5, 1, tuning)
	var w: Dictionary = layout.wall_run_gaps[0]
	var world: RunWorld = sim.build_world(layout)
	var drone: Enemy = world.director.spawn({"type": "drone", "at": 20.0, "lane": 2, "side": 0, "seed": 5,
		"params": {"slot": 0}})
	var dream: Enemy = world.director.spawn({"type": "bad_dream", "at": 0.0, "lane": 2, "side": 0, "seed": 5,
		"params": {"emerge": false}})
	var truck: Enemy = world.director.spawn({"type": "enforcer_truck", "at": 0.0, "lane": 2, "side": 0, "seed": 7,
		"params": {}})
	var dog: Enemy = world.director.spawn({"type": "octodog", "at": 300.0, "lane": 2, "side": 0, "seed": 5, "params": {}})
	await tree.physics_frame
	var p: Player = world.player
	var cases: Array = [[float(w["approach"]) - 150.0, false], [float(w["approach"]) - 2.0, true],
		[(float(w["start"]) + float(w["end"])) * 0.5, true], [float(w["end"]) + 3.0, false]]
	for c: Array in cases:
		p.distance = float(c[0])
		var where: String = "(the runner at %.0f m; the crossing %.0f-%.0f m)" % [p.distance, float(w["approach"]), float(w["end"])]
		check(bool(drone.call(&"_wall_run_in_reach", p)) == bool(c[1]),
			"a drone %s its barrage %s" % ["holds" if c[1] else "doesn't hold", where])
		check(bool(dream.call(&"_wall_run_in_reach", p)) == bool(c[1]),
			"a Bad Dream %s its slash %s" % ["holds" if c[1] else "doesn't hold", where])
		check(bool(truck.call(&"_wall_run_in_reach", p)) == bool(c[1]),
			"an Enforcer Truck %s its volley %s" % ["holds" if c[1] else "doesn't hold", where])
		# A charge winding up now plays out over the next DOG_WINDOW metres of the runner's run.
		check(bool(dog.call(&"_wall_run_in_reach", p.distance, DOG_WINDOW)) == bool(c[1]),
			"an Octodog %s its wind-up %s" % ["holds" if c[1] else "doesn't hold", where])
	check(drone.get_script() == DroneScript, "the drone is the heli drone")
	check(truck is EnforcerTruck and dog is Octodog, "the truck is the Enforcer Truck and the dog the Octodog")
	await sim.free_world(world)
