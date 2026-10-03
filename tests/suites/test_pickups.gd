extends TestSuite
## In-run pickups (GDD §10, task B7): the data (numbers with F6 hints, the look's sizes and colours
## without a hazard hue, the sounds and hints); where a pickup appears at 3, 5 and 6 lanes (ahead of
## the player, within reach, in plain view, never over or at the edge of a gap, in or under a fence,
## under a ceiling or on a pad or ramp, never where an attack is telegraphed or something in play is in
## the way), over hand-built cases and a sweep of generated tracks checked against the rules as this
## suite writes them; waiting for a fair spot; taking one (its charge, the stock, the HUD, the player
## model), the charge cap, a missed pickup, pooling and the first-encounter hint; the standard armor
## rule end to end on the test boss (the final phase's pickup, a break then a pickup after the boss's
## delay, at most once per phase, none after the fight), a boss's own pickups (offer_pickup, the test
## boss's shield); and, through the App, the stock and quick play's review option.

const TEST_BOSS_PATH: String = "res://data/bosses/test_boss.tres"

var sim: RunSim
var pt: PickupTuning
var test_def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	pt = load(PickupField.TUNING_PATH) as PickupTuning
	test_def = load(TEST_BOSS_PATH) as BossDef
	_test_data()
	if pt == null:
		return
	await _test_placement_cases()
	await _test_placement_sweep()
	await _test_things_in_play()
	await _test_waits_for_a_fair_spot()
	await _test_taking()
	await _test_cap()
	await _test_missed()
	await _test_pooling()
	await _test_hud()
	await _test_hints()
	await _test_boss_rule()
	await _test_boss_offers()
	await _test_after_the_fight()
	await _test_app()


# --- Helpers -------------------------------------------------------------------------------

## A bare world on `layout` with the player in `lane` at `distance` and the track built around them.
func _world(layout: LevelLayout, loadout: Loadout = null, lane: int = -1, distance: float = 0.0) -> RunWorld:
	var world: RunWorld = sim.build_world(layout, loadout)
	_place(world, lane if lane >= 0 else layout.lane_count / 2, distance)
	await tree.physics_frame
	return world


## Moves the player to `lane` at `distance` (the track follows on the next physics frame).
func _place(world: RunWorld, lane: int, distance: float) -> void:
	world.player.setup(world.tuning, world.geo, lane)
	world.player.distance = distance


## A fight in a bare RunWorld (as in test_bosses): the arena, a world on it, the encounter in it.
func _fight(enc: BossEncounter, def: BossDef, lanes: int = 5, loadout: Loadout = null, resume: Dictionary = {}) -> RunWorld:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	ctx.boss_resume = resume
	var arena: BossArena = enc.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, ctx.tuning, ctx.config)
	enc.setup(world, ctx, arena)
	return world


## Steps the world (the player running) until `condition` holds or `seconds` pass. True if it held.
func _until(world: RunWorld, condition: Callable, seconds: float) -> bool:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


## Switches the player into `lane`, one lane a frame (starting the run if it hasn't started).
func _steer(world: RunWorld, lane: int) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in 8:
		if world.player.lane == lane:
			return
		world.player.press(&"move_left" if lane < world.player.lane else &"move_right")
		await tree.physics_frame


## Records every pickup the field shows: [item, lane, at, the player's distance, fight time or -1].
func _record(world: RunWorld, enc: BossEncounter = null) -> Array:
	var out: Array = []
	world.pickups.spawned.connect(func(p: Pickup) -> void:
		out.append([p.item, p.lane, p.at, world.player.distance, enc.fight_time() if enc != null else -1.0]))
	return out


func _shot() -> Hazard:
	var shot := Hazard.new()
	shot.hazard_name = "test shot"
	shot.is_enemy_attack = true
	return shot


## Why a pickup at (`lane`, `at`) would break the placement rules on `layout` ("" if it wouldn't),
## written from the rules themselves rather than from PickupField's code: from clear_before before the
## spot to clear_after after it, its lane has floor (no gap, so it's never over one or at its edge),
## no fence of any kind (never in one or under a gapped fence's hitbox), no pad, ramp or speed pad,
## and no ceiling overhead (in plain view), all on the track.
func _unfair(layout: LevelLayout, lane: int, at: float) -> String:
	var lo: float = at - pt.clear_before
	var hi: float = at + pt.clear_after
	if lo < 0.0 or hi > layout.length:
		return "off the track"
	for g: Dictionary in layout.gaps:
		if int(g["lane"]) == lane and float(g["end"]) >= lo and float(g["start"]) <= hi:
			return "a gap at %.0f–%.0f m" % [g["start"], g["end"]]
	for f: Dictionary in layout.fences:
		if int(f["lane"]) == lane and float(f["at"]) >= lo and float(f["at"]) <= hi:
			return "a %s%s fence at %.0f m" % [f["variant"], " pulsing" if f["pulsing"] else "", f["at"]]
	for h: Dictionary in layout.hulls:
		if float(h["end"]) >= lo and float(h["start"]) <= hi:
			return "a ceiling at %.0f–%.0f m" % [h["start"], h["end"]]
	for p: Dictionary in layout.pads:
		if int(p["lane"]) == lane and float(p["at"]) <= hi and float(p["at"]) + tuning.pad_length >= lo:
			return "a pad at %.0f m" % p["at"]
	for p: Dictionary in layout.speed_pads:
		if int(p["lane"]) == lane and float(p["at"]) <= hi and float(p["at"]) + tuning.speed_pad_length >= lo:
			return "a speed pad at %.0f m" % p["at"]
	for r: Dictionary in layout.ramps:
		if layout.outer_lane(int(r["side"])) == lane and float(r["at"]) <= hi and float(r["at"]) + tuning.ramp_length >= lo:
			return "a ramp at %.0f m" % r["at"]
	return ""


## The pieces of `layout` near [from, to] (this suite's own filter, to keep the sweep quick).
func _near(layout: LevelLayout, from: float, to: float) -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = layout.lane_count
	out.length = layout.length
	var keep := func(start: float, end: float) -> bool: return start <= to + 20.0 and end >= from - 20.0
	for g: Dictionary in layout.gaps:
		if keep.call(float(g["start"]), float(g["end"])):
			out.gaps.append(g)
	for f: Dictionary in layout.fences:
		if keep.call(float(f["at"]), float(f["at"])):
			out.fences.append(f)
	for h: Dictionary in layout.hulls:
		if keep.call(float(h["start"]), float(h["end"])):
			out.hulls.append(h)
	for p: Dictionary in layout.pads:
		if keep.call(float(p["at"]), float(p["at"])):
			out.pads.append(p)
	for p: Dictionary in layout.speed_pads:
		if keep.call(float(p["at"]), float(p["at"])):
			out.speed_pads.append(p)
	for r: Dictionary in layout.ramps:
		if keep.call(float(r["at"]), float(r["at"])):
			out.ramps.append(r)
	return out


## Checks a spot against the rules for a player in `player_lane` at `from`: ahead by the lead and
## within the search window, within reach, and fair on the track (_unfair). Returns true if it holds.
func _check_spot(layout: LevelLayout, spot: Dictionary, from: float, player_lane: int, tag: String) -> bool:
	if spot.is_empty():
		check(false, "a pickup finds a spot %s" % tag)
		return false
	var lane: int = int(spot["lane"])
	var at: float = float(spot["at"])
	var why: String = _unfair(layout, lane, at)
	var ok: bool = why == "" and at >= from + pt.lead_distance - 0.001 and at <= from + pt.lead_distance + pt.search_window + 0.001 \
		and absi(lane - player_lane) <= pt.reach_lanes
	check(ok, "the pickup's spot is fair %s (lane %d at %.0f m: %s)" % [tag, lane, at, why if why != "" else "reach or lead"])
	return ok


# --- Data ----------------------------------------------------------------------------------

func _test_data() -> void:
	check(pt != null, "the pickup tuning loads (%s)" % PickupField.TUNING_PATH)
	if pt == null:
		return
	# Every number shows in the F6 tuning panel (CLAUDE.md principle 7).
	var unranged: PackedStringArray = []
	for prop: Dictionary in pt.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(prop["type"]) in [TYPE_FLOAT, TYPE_INT] \
				and int(prop["hint"]) != PROPERTY_HINT_RANGE:
			unranged.append(prop["name"])
	check(unranged.is_empty(), "every pickup number has an @export_range hint (%s)" % [unranged])
	check(pt.lead_distance + pt.search_window + pt.clear_after < TrackBuilder.BUILD_AHEAD,
		"the stretch a pickup is placed in is always on the track built ahead")
	check(pt.take_width < tuning.lane_width and pt.take_width >= tuning.hurtbox_size.x,
		"only the pickup's own lane takes it, and running through the lane does")
	check(pt.take_height > tuning.jump_height and pt.take_height > pt.float_height,
		"running, sliding or jumping through its lane takes it")
	check(pt.max_charges >= 1, "a pickup can always give a charge the player doesn't hold")
	# It looks like nothing else on the track.
	var biggest_credit: float = 0.0
	for value: int in CreditField.LOOKS:
		biggest_credit = maxf(biggest_credit, float(CreditField.LOOKS[value]["radius"]) * 2.0)
	check(pt.badge_radius * 2.0 >= biggest_credit * 1.5, "the badge is far bigger than any credit (%.2f m vs %.2f m)" % [
		pt.badge_radius * 2.0, biggest_credit])
	check(pt.float_height - pt.badge_radius > 0.2, "it floats clear of the floor (no plate on the floor like a pad)")
	for c: Array in [["ring", Pickup.RING_COLOR], ["icon", Pickup.ICON_COLOR]]:
		check((c[1] as Color).s < 0.2, "the pickup's %s is a neutral white: no hazard hue (s %.2f)" % [c[0], (c[1] as Color).s])
	check(Pickup.DISC_COLOR.v < 0.1, "the icon sits on a dark disc, like the HUD's badge")
	check(PickupField.ITEMS == [&"armor", &"shield", &"grapple"], "pickups give armor, shields and grapples (GDD §10)")
	for item: StringName in PickupField.ITEMS:
		var texture: Texture2D = Pickup.icon_texture(item)
		check(IconFactory.has_icon(item) and texture != null and texture.get_width() == int(Pickup.ICON_PIXELS),
			"a %s pickup shows the %s icon the HUD and the shop show" % [item, item])
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in [&"pickup", &"pickup_appear"]:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "the %s sound exists" % sound)
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string(HintDirector.PATH))
	var triggers: Array = []
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		triggers.append(String(h.get("trigger", "")))
	for item: StringName in PickupField.ITEMS:
		check(triggers.has("pickup:%s" % item), "a first-encounter hint for the %s pickup" % item)


# --- Placement -----------------------------------------------------------------------------

## Hand-built cases at 3, 5 and 6 lanes, one stretch of track each: a plain track, a gap under the
## spot, gaps across every lane, each kind of fence, a ceiling, pads and ramps, and a player at the
## edge of the track.
func _test_placement_cases() -> void:
	for lanes: int in [3, 5, 6]:
		var mid: int = lanes / 2
		var cases: Array[String] = ["plain", "gap", "gaps", "full", "gapped", "pulsing", "ceiling", "pad", "speed_pad", "ramp", "edge"]
		var layout := RunSim.layout(lanes, 300.0 * cases.size() + 400.0)
		var start: Dictionary = {}
		for i: int in cases.size():
			var d: float = 100.0 + 300.0 * i
			start[cases[i]] = d
			var spot: float = d + pt.lead_distance
			match cases[i]:
				"gap":
					layout.gaps.append({"lane": mid, "start": spot - 4.0, "end": spot + 4.0})
				"gaps":
					for l: int in lanes:
						layout.gaps.append({"lane": l, "start": spot - 4.0, "end": spot + 4.0})
				"full", "gapped", "pulsing":
					var f: Dictionary = RunSim.fence(mid, spot + 2.0, "gapped" if cases[i] == "gapped" else "full")
					if cases[i] == "pulsing":
						f["pulsing"] = true
					layout.fences.append(f)
				"ceiling":
					layout.hulls.append({"start": spot - 20.0, "end": spot + 10.0})
				"pad":
					layout.pads.append({"lane": mid, "at": spot})
				"speed_pad":
					layout.speed_pads.append({"lane": mid, "at": spot - 3.0})
				"ramp":
					layout.ramps.append({"side": 1, "at": spot})
				"edge":
					for l: int in range(0, mini(pt.reach_lanes + 1, lanes)):
						layout.fences.append(RunSim.fence(l, spot + 1.0, "full"))
		var world: RunWorld = sim.build_world(layout)
		for c: String in cases:
			var d: float = start[c]
			var lane: int = lanes - 1 if c == "ramp" else (0 if c == "edge" else mid)
			_place(world, lane, d)
			await tree.physics_frame
			var spot: Dictionary = world.pickups.find_spot()
			var tag: String = "(%s, %d lanes)" % [c, lanes]
			if not _check_spot(layout, spot, d, lane, tag):
				continue
			var s_lane: int = int(spot["lane"])
			var s_at: float = float(spot["at"])
			match c:
				"plain":
					check(s_lane == mid and is_equal_approx(s_at, d + pt.lead_distance),
						"on a plain track it appears in the player's lane, the lead ahead %s" % tag)
				"gap", "full", "gapped", "pulsing", "pad", "speed_pad":
					check(s_lane != mid and absi(s_lane - mid) == 1 and is_equal_approx(s_at, d + pt.lead_distance),
						"with the player's lane in the way, it takes the next lane over %s (lane %d)" % [tag, s_lane])
				"gaps":
					check(s_at > d + pt.lead_distance + 4.0 + pt.clear_before, "with every lane broken, it comes after the gaps %s" % tag)
				"ceiling":
					check(s_at > d + pt.lead_distance + 10.0 + pt.clear_before, "never under a ceiling, and a rider has landed first %s" % tag)
				"ramp":
					check(s_lane != lanes - 1, "never on a ramp %s" % tag)
				"edge":
					check(s_at > d + pt.lead_distance + 1.0 + pt.clear_before or s_lane > pt.reach_lanes,
						"a player in the outer lane gets it beyond the fences in reach %s" % tag)
					check(s_lane <= pt.reach_lanes, "and never further away than the reach %s" % tag)
		await sim.free_world(world)


## A sweep over generated tracks (the quick-play level with ramps, ceilings and pulsing fences, and the
## test boss's arena) at 3, 5 and 6 lanes: from every 40 m of the track and from the middle and both
## outer lanes, find_spot gives exactly the first fair spot by this suite's rules (the nearest one,
## then the nearest lane), and none when there's none in reach.
func _test_placement_sweep() -> void:
	var prototype := (load(TestSuite.LEVEL_PATH) as LevelConfig).duplicate() as LevelConfig
	prototype.difficulty = 0.7
	var configs: Array[LevelConfig] = [prototype, BossArena.base_config(test_def)]
	for base: LevelConfig in configs:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
			var world: RunWorld = sim.build_world(layout, null, null, config)
			var tag: String = "(%s, %d lanes)" % [base.id, lanes]
			var tried: int = 0
			var placed: int = 0
			var wrong: PackedStringArray = []
			var d: float = 20.0
			while d < layout.length - 120.0:
				for player_lane: int in [0, lanes / 2, lanes - 1]:
					_place(world, player_lane, d)
					if player_lane == 0:
						await tree.physics_frame
					var spot: Dictionary = world.pickups.find_spot()
					var expected: Dictionary = _first_fair(world, layout, d, player_lane)
					tried += 1
					if not spot.is_empty():
						placed += 1
					if spot.is_empty() != expected.is_empty() or (not spot.is_empty() and (int(spot["lane"]) != int(expected["lane"])
							or not is_equal_approx(float(spot["at"]), float(expected["at"])))):
						wrong.append("from lane %d at %.0f m: %s, expected %s" % [player_lane, d, spot, expected])
				d += 40.0
			check(wrong.is_empty(), "every pickup takes the first fair spot in reach %s (%d of %d wrong: %s)" % [
				tag, wrong.size(), tried, ", ".join(wrong.slice(0, 3))])
			check(placed >= tried * 0.6, "pickups find a spot at once most of the time %s (%d of %d)" % [tag, placed, tried])
			await sim.free_world(world)


## The first fair spot by this suite's rules for a player in `player_lane` at `from`: the nearest one
## ahead, then the lane nearest to the player's; {} if there's none in the search window.
func _first_fair(world: RunWorld, layout: LevelLayout, from: float, player_lane: int) -> Dictionary:
	var first: float = from + pt.lead_distance
	var last: float = minf(first + pt.search_window, minf(world.track.built_until(), layout.length) - pt.clear_after)
	var near: LevelLayout = _near(layout, first - pt.clear_before, last + pt.clear_after)
	var at: float = first
	while at <= last + 0.001:
		var best: int = -1
		for lane: int in layout.lane_count:
			if absi(lane - player_lane) > pt.reach_lanes or _unfair(near, lane, at) != "":
				continue
			var middle: float = (layout.lane_count - 1) * 0.5
			if best < 0 or absi(lane - player_lane) < absi(best - player_lane) \
					or (absi(lane - player_lane) == absi(best - player_lane) and absf(lane - middle) < absf(best - middle)):
				best = lane
		if best >= 0:
			return {"lane": best, "at": at}
		at += pt.search_step
	return {}


## Things in play keep pickups away: a boss's floor warnings (a lane about to be struck, a bomb's
## circle), a block slammed into a lane, a boss's fence, an enemy standing in the lane, and enemies
## planned on the track; and a boss's lane request is kept to the lanes in reach.
func _test_things_in_play() -> void:
	var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.1]])
	var enc := DummyBoss.new()
	var world: RunWorld = _fight(enc, def, 5)
	enc.pinned = true
	enc.body.position = world.lane_point(4, 400.0, 5.0)
	await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
	world.player.running = false
	_place(world, 2, 100.0)
	await tree.physics_frame
	world.player.god_mode = true
	var d: float = 100.0
	var lead: float = pt.lead_distance
	var spot: Dictionary = world.pickups.find_spot()
	check(int(spot.get("lane", -1)) == 2 and is_equal_approx(float(spot.get("at", 0.0)), d + lead),
		"in a fight on a plain track, it comes in the player's lane (%s)" % spot)
	var props: BossProps = enc.props
	# What's placed, as [lane, from, to] stretches no pickup's own stretch may reach into.
	var taken: Array = []
	var clear := func(s: Dictionary) -> bool:
		if s.is_empty():
			return false
		for t: Array in taken:
			if int(s["lane"]) == int(t[0]) and float(t[1]) <= float(s["at"]) + pt.clear_after \
					and float(t[2]) >= float(s["at"]) - pt.clear_before:
				return false
		return true
	var warning: MeshInstance3D = props.lane_warning(2, d + 5.0, d + 150.0)
	taken.append([2, d + 5.0, d + 150.0])
	spot = world.pickups.find_spot()
	check(clear.call(spot) and int(spot["lane"]) == 1, "never in a lane lit up for an attack: the next lane (%s)" % spot)
	check(props.warned(2, d + 60.0, d + 70.0) and not props.warned(1, d + 60.0, d + 70.0), "the props know where they warn")
	var circle: MeshInstance3D = props.circle_warning(d + lead, 1, 1.5)
	taken.append([1, d + lead - 1.5, d + lead + 1.5])
	check(props.warned(1, d + lead - 2.0, d + lead + 2.0) and not props.warned(0, d + lead - 2.0, d + lead + 2.0),
		"a bomb's circle warns its own lane, not the next one whose edge it grazes")
	spot = world.pickups.find_spot()
	check(clear.call(spot) and int(spot["lane"]) == 3, "nor where a bomb's circle is (%s)" % spot)
	var block: Hazard = props.block(3, d + lead - 6.0, Vector3(2.0, 1.5, 70.0))
	taken.append([3, d + lead - 6.0, d + lead + 64.0])
	await tree.physics_frame
	spot = world.pickups.find_spot()
	check(clear.call(spot), "nor behind a block slammed into the lane (%s)" % spot)
	var fences: Array[Hazard] = []
	for l: int in [0, 4]:
		fences.append(props.fence(l, d + lead + 3.0, "full", 0.6))
		taken.append([l, d + lead + 3.0, d + lead + 3.0])
	await tree.physics_frame
	spot = world.pickups.find_spot()
	check(fences[0].state == Hazard.State.WARNING and clear.call(spot),
		"nor at a boss's fence, even one still flickering in (%s)" % spot)
	for node: Node3D in [warning, circle, block]:
		props.remove(node)
	for f: Hazard in fences:
		props.remove(f)
	await tree.physics_frame
	await tree.physics_frame
	spot = world.pickups.find_spot()
	check(int(spot.get("lane", -1)) == 2 and is_equal_approx(float(spot.get("at", 0.0)), d + lead),
		"with the props gone, the player's lane again (%s)" % spot)
	# An enemy standing in the lane.
	var cyborg: Enemy = enc.spawn_enemy("cyborg", d + lead + 2.0, 2)
	await tree.physics_frame
	spot = world.pickups.find_spot()
	check(cyborg != null and not spot.is_empty() and (int(spot["lane"]) != 2 or float(spot["at"]) - pt.clear_before > d + lead + 3.0),
		"never on an enemy in play (%s)" % spot)
	if cyborg != null:
		cyborg.retire()
	# A lane asked for: kept to the lanes in reach, nearest to the one asked.
	await tree.physics_frame
	_place(world, 0, 300.0)
	await tree.physics_frame
	spot = world.pickups.find_spot(-1.0, 4)
	check(int(spot.get("lane", -1)) == pt.reach_lanes, "a lane out of reach gets the nearest lane in reach (%s)" % spot)
	spot = world.pickups.find_spot(300.0 + 60.0, 1)
	check(int(spot.get("lane", -1)) == 1 and float(spot.get("at", 0.0)) >= 360.0, "a spot asked for further on is kept (%s)" % spot)
	spot = world.pickups.find_spot(300.0 + 5.0)
	check(float(spot.get("at", 0.0)) >= 300.0 + pt.lead_distance, "one asked for too close comes at the lead instead (%s)" % spot)
	await sim.free_world(world)

	# Enemies planned on the track keep pickups out of their lane and the next ones.
	var layout := RunSim.layout(5, 400.0)
	layout.enemies.append({"type": "cyborg", "at": 150.0, "lane": 2, "side": 0, "seed": 1, "params": {}})
	layout.enemies.append({"type": "drone", "at": 250.0, "lane": 2, "side": 0, "seed": 2, "params": {}})
	var span: Vector2 = LevelGenerator.enemy_floor_span(layout.enemies[0])
	check(not PickupField.layout_fair(layout, 2, 150.0, pt, tuning) and not PickupField.layout_fair(layout, 1, span.x + 2.0, pt, tuning),
		"never where an enemy on the track will stand, nor in the lane beside it")
	check(PickupField.layout_fair(layout, 2 + pt.enemy_lane_margin + 1 if 2 + pt.enemy_lane_margin + 1 < 5 else 0, 150.0, pt, tuning),
		"further away is fine")
	check(PickupField.layout_fair(layout, 2, 250.0, pt, tuning), "a flier doesn't use the floor, so it keeps nothing away")


## With nothing fair in reach, a pickup waits and appears as soon as a spot is fair.
func _test_waits_for_a_fair_spot() -> void:
	var layout := RunSim.layout(5, 600.0)
	for i: int in 13:
		for l: int in 5:
			layout.fences.append(RunSim.fence(l, 40.0 + i * 10.0, "full"))
	var world: RunWorld = await _world(layout)
	world.player.god_mode = true
	var seen: Array = _record(world)
	check(world.pickups.offer(&"armor") and world.pickups.waiting() == 1 and seen.is_empty(),
		"with every lane fenced ahead, the pickup waits")
	await _until(world, func() -> bool: return not seen.is_empty(), 8.0)
	check(seen.size() == 1 and float(seen[0][2]) > 160.0 + pt.clear_before and world.pickups.waiting() == 0,
		"it appears as soon as a spot beyond the fences comes in reach (%s)" % [seen])
	if not seen.is_empty():
		check(float(seen[0][2]) - float(seen[0][3]) >= pt.lead_distance - 0.01, "still the lead ahead of the player")
	check(not world.pickups.offer(&"revive") and world.pickups.waiting() == 0, "there's no pickup for other items")
	await sim.free_world(world)


# --- Taking one ----------------------------------------------------------------------------

## Running through a pickup gives its item: a charge the player uses like their own, counted as the
## fight's (no stock), shown on the player model.
func _test_taking() -> void:
	for lanes: int in [3, 5, 6]:
		var layout := RunSim.layout(lanes, 900.0)
		var mid: int = lanes / 2
		layout.gaps.append({"lane": mid, "start": 300.0, "end": 305.0})
		var loadout := Loadout.new()
		var world: RunWorld = await _world(layout, loadout, mid)
		var tag: String = "(%d lanes)" % lanes
		var taken: Array = []
		world.pickups.collected.connect(func(p: Pickup, gained: bool) -> void: taken.append([p.item, gained]))
		var shot := _shot()
		var wall := Hazard.new()
		wall.hazard_name = "test wall"
		wall.is_solid = true
		var sides: Dictionary = {}
		for item: StringName in PickupField.ITEMS:
			var before: int = taken.size()
			world.pickups.offer(item)
			var p: Pickup = world.pickups.active[0] if not world.pickups.active.is_empty() else null
			check(p != null and p.item == item and p.lane == mid and p.visible, "a %s pickup appears in the player's lane %s" % [item, tag])
			await _until(world, func() -> bool: return taken.size() > before, 4.0)
			check(taken.size() == before + 1 and taken[before] == [item, true] and world.player.charges_of(item) == 1,
				"running through it gives a %s %s" % [item, tag])
			if item == &"armor":
				# The armor is no stock (GDD §8): a pickup brings it back whole (test_armor), no charge.
				check(not loadout.picked_up.has(item), "the armor isn't counted as a charge %s" % tag)
			else:
				check(int(loadout.picked_up.get(item, 0)) == 1 and not loadout.costs_stock(item) and loadout.costs_stock(item),
					"counted as the fight's: breaking it costs no stock (one) %s" % tag)
				loadout.picked_up[item] = 1
			if world.powerups != null and item != &"grapple":
				sides[item] = bool(world.powerups.call(&"equipment")[String(item)])
		check(sides.get(&"armor", false) and sides.get(&"shield", false), "the player model shows the armor and shield %s" % tag)
		check(world.player.receive_hit(shot) == DamageRules.Outcome.BLOCKED_ARMOR and world.player.armor == 0,
			"the armor blocks an enemy attack %s" % tag)
		world.player.invulnerable_left = 0.0
		check(world.player.receive_hit(wall) == DamageRules.Outcome.BLOCKED_SHIELD and world.player.shield == 0,
			"the shield blocks a solid hit %s" % tag)
		# The grapple saves the fall into the gap ahead.
		var used: Array[StringName] = []
		world.player.item_used.connect(func(item: StringName) -> void: used.append(item))
		await _until(world, func() -> bool: return world.player.distance > 320.0 or not world.player.alive, 12.0)
		check(world.player.alive and used.has(&"grapple") and world.player.grapples == 0, "the grapple saves a fall %s (%s)" % [tag, used])
		shot.free()
		wall.free()
		await sim.free_world(world)


## A pickup of a breakable item the player already holds all they can of (PickupTuning.max_charges):
## taken, nothing added (DESIGN-TBD); the cap is data. (The armor has its own rule: test_armor.)
func _test_cap() -> void:
	var loadout := Loadout.new()
	loadout.charges = {&"shield": 1}
	var world: RunWorld = await _world(RunSim.layout(5, 600.0), loadout)
	var taken: Array = []
	world.pickups.collected.connect(func(p: Pickup, gained: bool) -> void: taken.append([p.item, gained]))
	world.pickups.offer(&"shield")
	await _until(world, func() -> bool: return not taken.is_empty(), 4.0)
	check(taken == [[&"shield", false]] and world.player.shield == 1 and loadout.picked_up.is_empty() and world.pickups.active.is_empty(),
		"with a shield on already, a shield pickup is taken without adding a second (%s)" % [taken])
	check(loadout.costs_stock(&"shield"), "and the shield the player brought still costs its stock")
	await sim.free_world(world)
	var two: PickupTuning = pt.duplicate() as PickupTuning
	two.max_charges = 2
	loadout.add_picked_up(&"shield")
	world = sim.build_world(RunSim.layout(5, 600.0), loadout)
	world.pickups.tuning = two
	check(loadout.picked_up.is_empty(), "every world starts the picked-up count afresh")
	taken.clear()
	world.pickups.collected.connect(func(p: Pickup, gained: bool) -> void: taken.append([p.item, gained]))
	world.pickups.offer(&"shield")
	await _until(world, func() -> bool: return not taken.is_empty(), 4.0)
	check(taken == [[&"shield", true]] and world.player.shield == 2, "with a cap of two in the data, it adds a second")
	await sim.free_world(world)
	# The stock rules for a break.
	var l := Loadout.new()
	l.charges = {&"shield": 1}
	l.add_picked_up(&"shield")
	check(not l.costs_stock(&"shield") and l.costs_stock(&"shield"), "a picked-up charge breaks free first, then the player's own costs stock")
	l.grant(PackedStringArray(["grapple"]), App.catalog, false)
	l.add_picked_up(&"grapple")
	check(not l.costs_stock(&"grapple") and not l.costs_stock(&"grapple"), "a granted item never costs stock")


## A pickup the player runs past is gone: no charge, and it doesn't come back.
func _test_missed() -> void:
	var world: RunWorld = await _world(RunSim.layout(5, 600.0), Loadout.new(), 2)
	var seen: Array = _record(world)
	var gone: Array[Pickup] = []
	world.pickups.missed.connect(func(p: Pickup) -> void: gone.append(p))
	world.pickups.offer(&"shield")
	await _steer(world, 0)
	await _until(world, func() -> bool: return not gone.is_empty(), 4.0)
	check(gone.size() == 1 and world.pickups.active.is_empty() and world.player.shield == 0,
		"a pickup run past in another lane is missed, and gives nothing")
	check(not gone.is_empty() and world.player.distance > gone[0].at and world.player.distance - gone[0].at < pt.miss_distance + 1.0,
		"it goes as soon as the player is past it")
	await _until(world, func() -> bool: return false, 2.0)
	check(seen.size() == 1 and world.pickups.waiting() == 0 and not gone.is_empty() and not gone[0].visible
		and gone[0].state == Pickup.State.FREE, "it's gone for good (and back in the pool)")
	await sim.free_world(world)


## Pickups are pooled (CLAUDE.md: pool frequently spawned objects).
func _test_pooling() -> void:
	var world: RunWorld = await _world(RunSim.layout(5, 3000.0), Loadout.new(), 2)
	var taken: Array[int] = [0]
	world.pickups.collected.connect(func(_p: Pickup, _g: bool) -> void: taken[0] += 1)
	for i: int in 6:
		world.pickups.offer(PickupField.ITEMS[i % 3])
		await _until(world, func() -> bool: return taken[0] > i, 4.0)
		await _until(world, func() -> bool: return false, 0.4)
	var nodes: int = 0
	for child: Node in world.pickups.get_children():
		if child is Pickup:
			nodes += 1
	check(taken[0] == 6 and world.pickups.made == 6 and nodes == 1, "six pickups in turn reuse one node (%d taken, %d nodes)" % [taken[0], nodes])
	await sim.free_world(world)


## The HUD: a pickup's item joins the protections in its place and counts its charge.
func _test_hud() -> void:
	var loadout := Loadout.new()
	loadout.charges = {&"shield": 1}
	loadout.tiers = {&"dash": 1}
	var world: RunWorld = await _world(RunSim.layout(5, 600.0), loadout)
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	var hud := RunHud.new()
	tree.root.add_child(hud)
	hud.bind(world, ctx)
	await tree.process_frame
	check(hud.item_icons.has(&"shield") and not hud.item_icons.has(&"armor"), "the HUD shows what the run brought")
	world.pickups.offer(&"armor")
	await _until(world, func() -> bool: return world.player.armor > 0, 4.0)
	await tree.process_frame
	var items: Node = hud.get_node(^"HudRoot/SafeFrame/Items")
	var order: PackedStringArray = []
	for child: Node in items.get_children():
		order.append(String(child.name))
	check(hud.item_icons.has(&"armor") and (hud.item_icons[&"armor"] as CooldownIcon).count == 1,
		"a picked-up armor shows on the HUD with its charge")
	check(order.size() >= 2 and order[0] == "armor" and order[1] == "shield", "in its place among the protections (%s)" % [order])
	if world.powerups != null:
		var ids: Array = (world.powerups.call(&"hud_state") as Array).map(func(e: Dictionary) -> StringName: return e["id"])
		check(ids.has(&"armor") and ids.find(&"armor") < ids.find(&"shield"), "the power-ups list it too, in shop order (%s)" % [ids])
	world.player.armor = 0
	await tree.process_frame
	check((hud.item_icons[&"armor"] as CooldownIcon).count == 0, "and shows it spent once it breaks")
	hud.queue_free()
	await sim.free_world(world)


## Boss pickups are explained on the intro, once per profile, never on spawning.
func _test_hints() -> void:
	var profile := Profile.new()
	for pass_index: int in 2:
		var boss := BossEncounter.create(test_def) as TestBoss
		var world: RunWorld = _fight(boss, test_def, 5, null)
		var hints := HintDirector.new()
		world.add_child(hints)
		hints.setup(world, profile, false)
		var shown: Array = []
		hints.hint_shown.connect(func(id: String, text: String) -> void: shown.append([id, text]))
		hints.acknowledge(hints.intro_hints)
		var intro_count: int = shown.size()
		world.pickups.offer(&"shield")
		await _until(world, func() -> bool: return false, 0.2)
		check(shown.size() == intro_count, "a spawning pickup never interrupts play")
		if pass_index == 0:
			var ids: Array = shown.map(func(s: Array) -> String: return s[0])
			check(ids.has("pickup_shield"), "a shield pickup's first appearance brings its hint (%s)" % [ids])
			for s: Array in shown:
				if s[0] == "pickup_shield":
					check(String(s[1]).contains("shield") and String(s[1]).contains("run through"), "saying what it does and how to take it")
			check(profile.has_seen("hint/pickup_shield") and profile.has_seen("hint/pickup_armor"), "boss pickup hints are remembered from the intro")
		else:
			check(not shown.map(func(s: Array) -> String: return s[0]).has("pickup_shield"), "never twice")
		await sim.free_world(world)


# --- The boss rule, end to end ------------------------------------------------------------------

## GDD §10's standard armor rule on the test boss: an armor pickup when the final phase begins, one
## after the boss's delay when the player's armor or shield breaks, at most once per phase; every
## one at a fair spot.
func _test_boss_rule() -> void:
	for lanes: int in [3, 5, 6]:
		var enc := BossEncounter.create(test_def) as TestBoss
		var world: RunWorld = _fight(enc, test_def, lanes, null, {"phase": 2})
		var tag: String = "(%d lanes)" % lanes
		var p: Pickup = world.pickups.active[0] if world.pickups.active.size() == 1 else null
		check(enc.is_final_phase() and p != null and p.item == &"armor", "the final phase begins with an armor pickup %s" % tag)
		if p != null:
			check(_unfair(world.layout, p.lane, p.at) == "" and p.at >= world.player.distance + pt.lead_distance,
				"on the floor ahead, at a fair spot %s" % tag)
		await sim.free_world(world)

	var loadout := Loadout.new()
	loadout.armor = true
	loadout.charges = {&"shield": 1}
	var boss := BossEncounter.create(test_def) as TestBoss
	var w: RunWorld = _fight(boss, test_def, 5, loadout)
	w.player.grapples = 1_000_000
	var seen: Array = _record(w, boss)
	var unfair: PackedStringArray = []
	w.pickups.spawned.connect(func(pk: Pickup) -> void:
		var why: String = _unfair(w.layout, pk.lane, pk.at)
		if why == "" and boss.props.warned(pk.lane, pk.at - pt.clear_before, pk.at + pt.clear_after):
			why = "a warning"
		if why != "":
			unfair.append(why))
	await _until(w, func() -> bool: return boss.is_vulnerable(), 5.0)
	w.player.god_mode = true
	var shot := _shot()
	w.player.god_mode = false
	w.player.receive_hit(shot)
	w.player.god_mode = true
	var t0: float = boss.fight_time()
	check(w.player.armor == 0 and seen.is_empty(), "the armor breaks in phase 1; nothing yet")
	await _until(w, func() -> bool: return not seen.is_empty(), test_def.armor_delay_max + 3.0)
	check(seen.size() == 1 and seen[0][0] == &"armor", "an armor pickup follows the break (%s)" % [seen])
	if not seen.is_empty():
		var delay: float = float(seen[0][4]) - t0
		check(delay >= test_def.armor_delay_min - 0.05 and delay <= test_def.armor_delay_max + 1.0,
			"after the boss's delay (%.1f s; %.0f–%.0f s)" % [delay, test_def.armor_delay_min, test_def.armor_delay_max])
		# Take it.
		await _steer(w, int(seen[0][1]))
		await _until(w, func() -> bool: return w.player.armor > 0 or w.pickups.active.is_empty(), 5.0)
		check(w.player.armor == 1, "the player takes it: armor again")
	# At most once per phase: another break brings none.
	w.player.god_mode = false
	w.player.invulnerable_left = 0.0
	w.player.receive_hit(shot)
	w.player.invulnerable_left = 0.0
	w.player.receive_hit(shot)
	w.player.god_mode = true
	await _until(w, func() -> bool: return seen.size() > 1, test_def.armor_delay_max + 4.0)
	check(seen.size() == 1 and boss.phase_index == 0, "more breaks in the same phase bring no more (%s)" % [seen])
	# The next phase answers a break again (the test boss also offers its own shield there).
	boss.damage(boss.hit_damage(), &"test")
	await _until(w, func() -> bool: return boss.is_vulnerable(), 5.0)
	w.player.armor = 1
	w.player.god_mode = false
	w.player.invulnerable_left = 0.0
	w.player.receive_hit(shot)
	w.player.god_mode = true
	await _until(w, func() -> bool: return seen.filter(func(s: Array) -> bool: return s[0] == &"armor").size() > 1,
		test_def.armor_delay_max + 4.0)
	var armors: int = seen.filter(func(s: Array) -> bool: return s[0] == &"armor").size()
	check(armors == 2 and boss.phase_index == 1, "a break in the next phase brings one again (%s)" % [seen])
	check(unfair.is_empty(), "every pickup of the fight came at a fair spot (%s)" % [unfair])
	shot.free()
	await sim.free_world(w)


## A boss's own pickups (GDD §10: "a section of floor that spawns an armor, shield or grapple pickup"):
## the test boss offers a shield when its second phase's pattern begins.
func _test_boss_offers() -> void:
	var enc := BossEncounter.create(test_def) as TestBoss
	var world: RunWorld = _fight(enc, test_def, 5, null, {"phase": 1})
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	var seen: Array = _record(world, enc)
	check(seen.is_empty(), "nothing during the phase's intro")
	await _until(world, func() -> bool: return not seen.is_empty(), test_def.phase_list()[1].intro_seconds + 1.0)
	check(seen.size() == 1 and seen[0][0] == StringName(enc.tuning.bonus_pickup) and enc.is_vulnerable(),
		"the test boss offers its %s as the second phase's pattern begins (%s)" % [enc.tuning.bonus_pickup, seen])
	var offered: Array = enc.events.filter(func(e: Dictionary) -> bool: return e["event"] == &"pickup_offered")
	check(offered.size() == 1 and offered[0]["item"] == &"shield", "and logs the offer")
	await sim.free_world(world)


## No pickup after the fight: none waiting for a spot and none on the track once the boss is beaten,
## and none offered from then on.
func _test_after_the_fight() -> void:
	var enc := BossEncounter.create(test_def) as TestBoss
	var world: RunWorld = _fight(enc, test_def, 5, null, {"phase": 2})
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	var seen: Array = _record(world, enc)
	check(world.pickups.active.size() == 1, "the final phase's pickup is on the track")
	await _until(world, func() -> bool: return enc.is_vulnerable(), 5.0)
	# Every lane warned for a long stretch: an offer has to wait.
	var warnings: Array[MeshInstance3D] = []
	for l: int in 5:
		warnings.append(enc.props.lane_warning(l, world.player.distance, world.player.distance + 300.0))
	check(enc.offer_pickup(&"shield") and world.pickups.waiting() == 1, "with every lane warned, an offer waits")
	enc.damage(enc.max_health, &"test")
	check(enc.is_defeated() and world.pickups.active.is_empty() and world.pickups.waiting() == 0,
		"beating the boss takes the pickups off the track and drops the waiting one")
	check(not enc.offer_pickup(&"armor"), "and nothing is offered after the fight")
	for m: MeshInstance3D in warnings:
		enc.props.remove(m)
	var before: int = seen.size()
	await _until(world, func() -> bool: return seen.size() > before, 3.0)
	check(seen.size() == before, "no pickup appears after the fight")
	await sim.free_world(world)


# --- Through the App ---------------------------------------------------------------------------

## On the real main scene: quick play's review option shows pickups; the player's own shield costs its
## stock when it breaks, a picked-up one doesn't.
func _test_app() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = Profile.new()
	App.profile.add_stock(&"shield", 2)
	App.start_quick(PackedStringArray(["--god", "--nofall", "--pickups=shield"]))
	await physics_frames(3)
	var run: LevelRun = App.run
	check(run != null and run.context.review_pickups == PackedStringArray(["shield"]), "--pickups asks quick play for review pickups")
	if run == null:
		App.profile = saved
		main.queue_free()
		App.main = null
		await tree.process_frame
		return
	var player: Player = run.world.player
	var wall := Hazard.new()
	wall.hazard_name = "test wall"
	wall.is_solid = true
	check(player.shield == 1, "the run brings one shield from the stock")
	player.god_mode = false
	player.receive_hit(wall)
	player.god_mode = true
	check(App.profile.stock(&"shield") == 1, "the player's own shield costs its stock when it breaks")
	var field: PickupField = run.world.pickups
	var up: bool = false
	for i: int in 60 * 5:
		if not field.active.is_empty():
			up = true
			break
		await tree.physics_frame
	check(up and field.active[0].item == &"shield", "quick play shows a shield pickup for review")
	if up:
		var lane: int = field.active[0].lane
		for i: int in 8:
			if player.lane == lane:
				break
			player.press(&"move_left" if lane < player.lane else &"move_right")
			await tree.physics_frame
		for i: int in 60 * 5:
			if player.shield > 0:
				break
			await tree.physics_frame
		check(player.shield == 1 and int(run.context.loadout.picked_up.get(&"shield", 0)) == 1, "the player takes it")
		player.god_mode = false
		player.invulnerable_left = 0.0
		player.receive_hit(wall)
		player.god_mode = true
		check(player.shield == 0 and App.profile.stock(&"shield") == 1, "breaking a picked-up shield costs no stock")
	wall.free()
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
