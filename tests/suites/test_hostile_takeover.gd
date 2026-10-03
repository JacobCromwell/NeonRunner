extends TestSuite
## Hostile Takeover, the Corporate zone's boss (GDD §10; tasks E5b-a and E5b-b): its slot and data, the
## train arena (its consist of carriages and flatcars; every gap between carriages jumpable from every lane
## at the Corporate zone's 23.4 m/s and quick play's 18 m/s, with the player's real jump), what counts as
## landing on a coupling (its stomp box over the gap, the bounce that carries the runner on), phase 1's plan
## (The Board) at 3, 5 and 6 lanes (the guards, the Tithe Collectors and the partial wall fences always
## leave a way through, and each coupling's lane stays reachable; the Collectors capped a phase), phase 2's
## plan (The Contract: the dropped Buzz Overdrive's cut as a level's, the runway of pads and the belly ride
## over the armored carriage, the strafes' free lanes), and its look (the colour rule, budgets, nothing
## made while running, Reduced flashing). The fight itself: test_hostile_takeover_fight.gd.

const BOSS_PATH: String = "res://data/bosses/corporate_boss.tres"
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Corporate zone's (GDD §3).
const SPEEDS: Array[float] = [18.0, 23.4]
const NEW_SOUNDS: Array[StringName] = [&"takeover_gunship", &"takeover_couplings", &"takeover_decouple",
	&"takeover_breakaway", &"takeover_whine", &"takeover_strafe", &"takeover_drop", &"takeover_bay"]
## A jump in a gap's lane takes off this far before its edge (metres at 18 m/s, at the run's pace): the
## latest a runner who reads the gap would leave it.
const HOLE_LEAD: float = 1.6
## Carriages the plan checks are planned over (a few laps' worth of the Board).
const PLANNED: int = 36
## Flatcars whose drop phase 2's plan check plans.
const DROPS: int = 3
## A saturated colour outside the decorative blue-to-violet band glows only on hazards (GDD §5).
const GLOW_SATURATION_LIMIT: float = 0.35
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")

var sim: RunSim
var slot: BossDef
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	slot = load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "Hostile Takeover's fight loads as a preview")
		return
	_test_slot()
	for speed: float in SPEEDS:
		await _test_train(speed)
	await _test_coupling_box()
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_board(lanes, speed)
	await _test_tithe_cap()
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_contract(lanes, speed)
	await _test_look()


## The fight at `lanes` and `speed` m/s (the arena config at that speed, as the campaign sets it), from
## phase `phase` (a checkpoint's resume): [world, boss].
func _fight(p_def: BossDef, lanes: int, speed: float, loadout: Loadout = null, phase: int = 0) -> Array:
	var boss := BossEncounter.create(p_def) as HostileTakeover
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": phase} if phase > 0 else {}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


## The arena alone (planned, no world): [arena, boss]; the caller frees the boss (not in the tree).
func _arena(lanes: int, speed: float) -> Array:
	var boss := BossEncounter.create(def) as HostileTakeover
	var ctx := RunContext.new()
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
	return [boss.plan_arena(ctx), boss]


# --- The slot ------------------------------------------------------------------------------------

func _test_slot() -> void:
	check(slot.display_name == "Hostile Takeover" and slot.id == &"corporate_boss", "the Corporate zone's slot is Hostile Takeover (GDD §10)")
	check(not slot.is_built() and slot.preview_scene == "res://scenes/bosses/hostile_takeover.tscn" and slot.preview() != null,
		"step 1 of 3: the campaign keeps its card; debug builds play the fight as a preview (--boss=corporate_boss)")
	var list: Array[BossPhase] = def.phase_list()
	check(list.size() == 3 and list[0].display_name == "The Board" and list[1].display_name == "The Contract"
		and list[2].display_name == "The Merger", "three phases: The Board, The Contract, The Merger (GDD §10)")
	check(list[0].hits == 1 and list[1].hits == 1 and list[2].hits == 3, "one big hit in each of the first two, the three docking clamps in the third")
	check(def.weapon_share_cap > 0.0 and def.weapon_share_cap <= 1.0 / 3.0 + 0.01,
		"weapons chip, but can save at most one stomp (%.2f of its health)" % def.weapon_share_cap)
	check(def.armor_rule and def.armor_delay_min == 15.0 and def.armor_delay_max == 17.0 and def.armor_pickups_per_phase == 1
		and def.armor_when_unprotected, "the standard armor rule, 15-17 s, a phase begun unprotected counting as a break (GDD §10)")
	check(def.music == &"corporate", "it plays the Corporate zone's own track (no new music)")
	check(def.tuning is HostileTakeoverTuning and def.tuning.resource_path == "res://data/bosses/corporate_boss_tuning.tres",
		"its numbers are a tuning of its own (F6)")
	var skin := def.arena.skin as HostileTakeoverSkin if def.arena != null else null
	check(skin != null and skin.resource_path == "res://data/bosses/corporate_boss_skin.tres" and skin is CorporateSkin,
		"its arena is the Corporate zone's look on the Chairman's train, a skin of its own")
	check(skin != null and skin.enemy_variant == &"vr_runner", "its guards wear the Corporate levels' look (the VR runner)")
	check(skin != null and skin.skybridge_share == 0.0 and skin.hover_ship_share == 0.0 and skin.street_screen_share == 0.0,
		"nothing hangs over the street, where the gunship flies")
	check(def.arena.features.is_empty(), "the arena's laps are the train alone: the phases bring the rest")
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in NEW_SOUNDS:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "its sound %s exists" % sound)
	check(sfx.stream(&"takeover_couplings").get_length() <= 1.5 and sfx.stream(&"takeover_decouple").get_length() <= 1.5,
		"the couplings' cue and the stomp are short")
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Array = []
	for h: Dictionary in (hints as Dictionary)["hints"]:
		triggers.append(h["trigger"])
	for trigger: String in ["enemy:corporate_boss", "boss:corporate_boss/couplings", "boss:corporate_boss/strafe",
			"boss:corporate_boss/ride"]:
		check(triggers.has(trigger), "a first-time hint for %s" % trigger)
	var t := def.tuning as HostileTakeoverTuning
	var flatcar: int = HostileTakeoverTrain.Kind.FLATCAR
	var corporate: int = HostileTakeoverTrain.Kind.CORPORATE
	check(t.opening_for(0) >= 1 and t.opening_for(7) == t.opening_gaps[-1], "each phase opens with dark gaps (the last entry's for later ones)")
	check(t.consist_kinds().has(flatcar) and t.consist_kinds().has(corporate), "the train's consist: corporate carriages and flatcars")
	check(t.guards_on(0, 5) == 0 and t.guards_on(t.guards_from, 3) <= 2 and t.guards_on(t.guards_from, 6) >= 1
		and t.guards_on(t.guards_from, 6, flatcar) == 0, "guards from their carriage on, at most one fewer than the lanes, none on a flatcar")
	check(t.tithe_on(t.tithe_first, flatcar) and not t.tithe_on(t.tithe_first, corporate) and not t.tithe_on(t.tithe_first - 1, flatcar)
		and t.tithe_visits_per_phase >= 1, "a Tithe Collector on each flatcar from its carriage on, %d a phase at most" % t.tithe_visits_per_phase)
	check(HostileTakeover.pattern_of(0) == HostileTakeover.Pattern.BOARD and HostileTakeover.pattern_of(1) == HostileTakeover.Pattern.CONTRACT,
		"phase 1 plays The Board, phase 2 The Contract")
	check(sfx.stream(&"takeover_whine").get_length() >= t.strafe_warning - 0.05 and sfx.stream(&"takeover_whine").get_length() <= t.strafe_warning + 0.4,
		"the strafe's rising whine lasts its warning (%.2f s)" % sfx.stream(&"takeover_whine").get_length())


# --- The train -----------------------------------------------------------------------------------

## GDD §10: "carriage roofs are the floor and the gaps between carriages are the gaps". Every lap is the
## train: a gap across every lane at the end of each carriage, a level's jump long (a share of a jump at the
## run speed, within the generator's longest), the carriages in the tuning's consist (corporate carriages
## and long flatcars, each its length in seconds), running on across the laps without a seam; nothing
## else. Every gap is jumpable from every lane with the player's real jump, at this speed.
func _test_train(speed: float) -> void:
	var tag: String = "(%.1f m/s)" % speed
	var t := def.tuning as HostileTakeoverTuning
	for lanes: int in LANES:
		var pair: Array = _arena(lanes, speed)
		var arena: BossArena = pair[0]
		var boss: HostileTakeover = pair[1]
		var train: HostileTakeoverTrain = boss.train
		var layout: LevelLayout = arena.layout
		var jump: float = arena.tuning.jump_distance(speed)
		var lane_tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
		check(is_equal_approx(train.speed, speed) and is_equal_approx(train.gap, t.gap_jump_fraction * jump),
			"a gap is a share of a jump at the run speed (%.2f m) %s" % [train.gap, lane_tag])
		check(train.gap <= arena.config.max_gap_jump_fraction * jump + 0.001,
			"and no longer than the generator's longest gap (%.2f of %.2f m) %s" % [train.gap, arena.config.max_gap_jump_fraction * jump, lane_tag])
		var starts: Dictionary = {}
		var clean: bool = true
		for g: Dictionary in layout.gaps:
			var key: String = "%.3f" % float(g["start"])
			if not starts.has(key):
				starts[key] = []
			(starts[key] as Array).append(int(g["lane"]))
			clean = clean and is_equal_approx(float(g["end"]) - float(g["start"]), train.gap)
		var across: bool = true
		for key: String in starts:
			var lanes_cut: Array = starts[key]
			lanes_cut.sort()
			across = across and lanes_cut == range(lanes)
		check(clean and across and starts.size() >= 2 * train.per_lap,
			"every gap spans every lane, the same length (%d gaps over two laps) %s" % [starts.size(), lane_tag])
		var keys: Array = starts.keys().map(func(k: String) -> float: return float(k))
		keys.sort()
		var placed: bool = true
		var kinds_ok: bool = true
		var lengths_ok: bool = true
		var kinds: PackedInt32Array = t.consist_kinds()
		var pace: float = arena.tuning.pace()
		for i: int in keys.size():
			placed = placed and absf(float(keys[i]) - train.gap_start(i)) < 0.01
			if i == 0:
				continue
			var kind: int = train.kind(i)
			kinds_ok = kinds_ok and kind == kinds[(i - 1) % kinds.size()]
			var roof: Vector2 = train.roof(i)
			var wanted: float = (t.flatcar_length if kind == HostileTakeoverTrain.Kind.FLATCAR else t.carriage_length) * pace
			lengths_ok = lengths_ok and roof.y - roof.x >= wanted * 0.85 and roof.y - roof.x <= wanted * 1.15
		check(placed and is_equal_approx(arena.lap_length, train.period * train.consists_per_lap)
			and train.per_lap == train.consists_per_lap * kinds.size(),
			"the carriages in their consist (%d a lap), the laps joining seamlessly %s" % [train.per_lap, lane_tag])
		check(kinds_ok and lengths_ok, "each carriage of its kind, keeping its length in seconds (a flatcar %.1f m) %s" % [
			train.roof(train.next_flatcar(1)).y - train.roof(train.next_flatcar(1)).x, lane_tag])
		check(float(keys[0]) >= pace * 30.0 and float(keys[0]) < train.roofs[train.roofs.size() - 1] + train.gap,
			"the rear carriage's roof before the first gap is the entrance's (%.1f m) %s" % [float(keys[0]), lane_tag])
		check(layout.fences.is_empty() and layout.signs.is_empty() and layout.hulls.is_empty() and layout.pads.is_empty()
			and layout.ramps.is_empty() and layout.speed_pads.is_empty() and layout.enemies.is_empty() and layout.credits.is_empty()
			and layout.doodads.is_empty() and layout.cuts.is_empty() and layout.wall_fences.is_empty(),
			"the laps hold the train alone %s" % lane_tag)
		var rules := load("res://data/tuning/game_rules.tres") as GameRules
		var before: float = t.stomp_before * arena.tuning.pace()
		check(train.bounce_clears(arena.tuning, rules, t.stomp_top, before),
			"a stomp from the box's near end bounces on past the gap (%.1f m for %.1f m) %s" % [
				HostileTakeoverTrain.bounce_length(arena.tuning, rules, t.stomp_top), before + train.gap, lane_tag])
		# The generator's route model through two laps, from every lane.
		var grid := FloorRoute.new(layout, arena.tuning)
		var routes_ok: bool = true
		for lane: int in lanes:
			routes_ok = routes_ok and bool(grid.find(1.0, arena.lap_length * 1.6, lane)["ok"])
		check(routes_ok, "a floor route jumps every gap from every lane %s" % lane_tag)
		boss.free()
	# The player's real jump, from every lane, over the first gaps.
	for lanes: int in LANES:
		var pair: Array = _arena(lanes, speed)
		var arena: BossArena = pair[0]
		var train: HostileTakeoverTrain = (pair[1] as HostileTakeover).train
		(pair[1] as Node).free()
		var movement: MovementTuning = arena.tuning
		var actions: Array = []
		for k: int in 6:
			actions.append([train.gap_start(k) - HOLE_LEAD * movement.pace(), &"jump"])
		var seconds: float = (train.gap_end(5) + 10.0) / speed
		for lane: int in lanes:
			var r: Dictionary = await sim.run(arena.layout, lane, seconds, actions, [], movement)
			check(r["alive"] and float(r["distance"]) > train.gap_end(5),
				"the player's real jump clears six gaps from lane %d (%d lanes) %s" % [lane, lanes, tag])


# --- What counts as landing on a coupling ---------------------------------------------------------

## GDD §10: "the player stomps it by landing on it while jumping the gap". Its stomp box spans its lane
## over the whole gap and a little past both edges, up to stomp_top over the roofs (at the run's pace), a
## weak point (a stomp from above), off until it's live; a jump from the take-off window (where its descent
## comes down over the box) lands on it, and the window is as long in seconds at every speed.
func _test_coupling_box() -> void:
	var t := def.tuning as HostileTakeoverTuning
	for speed: float in SPEEDS:
		var tag: String = "(%.1f m/s)" % speed
		var pair: Array = _fight(def, 5, speed)
		var world: RunWorld = pair[0]
		var boss: HostileTakeover = pair[1]
		var c: HostileTakeoverCouplings = boss.couplings
		var pace: float = world.tuning.pace()
		var gap: float = boss.train.gap
		check(c.immune_to_weapons and not c.targetable() and c.is_obstacle and c.shares_health,
			"the couplings: part of the boss (its stomps hurt it), no weapon's target, no kill of their own")
		check(is_equal_approx(c.box_size.x, world.geo.lane_width * t.stomp_width_share)
			and is_equal_approx(c.box_size.z, gap + (t.stomp_before + t.stomp_after) * pace)
			and is_equal_approx(c.box_offset.y + c.box_size.y * 0.5, t.stomp_top),
			"its stomp box: its lane, the gap and a little either side at the run's pace, up to %.2f m %s" % [t.stomp_top, tag])
		var span: Vector2 = c.box_span(3)
		check(is_equal_approx(span.x, boss.train.gap_start(3) - t.stomp_before * pace)
			and is_equal_approx(span.y, boss.train.gap_end(3) + t.stomp_after * pace), "over the gap it's laid on %s" % tag)
		var rules := load("res://data/tuning/game_rules.tres") as GameRules
		check(c.box_offset.y + c.box_size.y * 0.5 - rules.stomp_tolerance > 0.0,
			"a runner who drops off the roof's edge is never high enough over it to stomp it")
		var window: float = (c.takeoff.y - c.takeoff.x) / speed
		check(c.takeoff.x > 0.0 and window >= 0.4 and absf(window - (gap + (t.stomp_before + t.stomp_after) * pace) / speed) < 0.01,
			"a jump from %.1f to %.1f m before the gap lands on it: a %.2f s window %s" % [c.takeoff.x, c.takeoff.y, window, tag])
		var hazards: Array[Hazard] = []
		for rig: Dictionary in c.rigs:
			hazards.append(rig["hazard"])
		check(hazards.size() == HostileTakeoverCouplings.POOL and hazards.all(func(h: Hazard) -> bool:
			return h.part == &"weak_point" and not h.is_active()), "pooled weak points, off while nothing is live")
		await sim.free_world(world)


# --- Phase 1's plan: The Board --------------------------------------------------------------------

## GDD §10: "security cyborgs guard the roofs, a Tithe Collector skims credits, and partial wall fences
## run along the track's sound barriers. Each carriage coupling glows red and sits in one lane above the
## gap". Over PLANNED carriages at this lane count and speed: each coupling in a lane of its own (never the
## last one's, at most coupling_max_shift from it); the guards never within the cyborgs' margin of a gap
## (the level's rule), never where they could reach a coupling's run-up or its bounce's landing in its lane,
## apart from each other and fewer than the lanes, so a way through is always open and the coupling's lane
## stays reachable; on each flatcar from tithe_first on a Tithe Collector and nothing else (no guards, no wall
## fence: phase 2 drops its Buzz Overdrive there); partial wall fences only where the level's rules allow
## (LayoutChecks.check_wall_fences, independently), the low and high bands in turn.
func _test_board(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var t := def.tuning as HostileTakeoverTuning
	var pair: Array = _fight(def, lanes, speed)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var board: HostileTakeoverBoard = boss.board
	var train: HostileTakeoverTrain = boss.train
	var pace: float = world.tuning.pace()
	while board.planned < PLANNED:
		board.plan(board.planned + 1)
	var cyborg := load("res://data/enemies/cyborg.tres") as CyborgTuning
	var margin: float = CyborgRules.obstacle_margin_at(cyborg, pace)
	var lanes_ok: bool = true
	var guards_ok: bool = true
	var corridors_ok: bool = true
	var spacing_ok: bool = true
	var guard_count: int = 0
	var tithes: Array[int] = []
	var lone_tithes: bool = true
	var bands: Array[String] = []
	var why: String = ""
	for k: int in range(0, PLANNED + 1):
		var lane: int = int(board.lanes[k])
		if k > 0:
			var prev: int = int(board.lanes[k - 1])
			if lanes > 1 and (lane == prev or absi(lane - prev) > t.coupling_max_shift):
				lanes_ok = false
		var rec: Dictionary = board.carriages[k]
		var guards: Array = rec["guards"]
		if guards.size() >= lanes:
			guards_ok = false
		var roof: Vector2 = train.roof(k)
		for i: int in guards.size():
			var g: Dictionary = guards[i]
			guard_count += 1
			var at: float = float(g["at"])
			if at < roof.x + margin - 0.01 or at > roof.y - margin + 0.01:
				guards_ok = false
				why = "a guard %.1f m from a gap on carriage %d" % [minf(at - roof.x, roof.y - at), k]
			var reach: Vector2 = board.guard_reach(k, g)
			if int(g["lane"]) == lane and reach.y > roof.y - t.approach_clear * pace:
				corridors_ok = false
			if k > 0 and int(g["lane"]) == int(board.lanes[k - 1]) and reach.x < roof.x + t.landing_clear * pace:
				corridors_ok = false
			for j: int in range(i + 1, guards.size()):
				if absf(float((guards[j] as Dictionary)["at"]) - at) < t.guard_spacing * pace - 0.01:
					spacing_ok = false
		if float(rec["tithe"]) >= 0.0:
			tithes.append(k)
		if train.kind(k) == HostileTakeoverTrain.Kind.FLATCAR and (not guards.is_empty() or not (rec["wall_fence"] as Dictionary).is_empty()):
			lone_tithes = false
		if not (rec["wall_fence"] as Dictionary).is_empty():
			bands.append(String(rec["wall_fence"]["band"]))
	check(lanes_ok, "each coupling in a lane of its own, at most %d from the last %s" % [t.coupling_max_shift, tag])
	check(guards_ok, "guards fewer than the lanes on every carriage, never within the cyborgs' margin of a gap %s %s" % [tag, why])
	check(corridors_ok, "no guard can reach a coupling's run-up or its bounce's landing in its lane %s" % tag)
	check(spacing_ok, "two guards on a carriage stand apart %s" % tag)
	var listed: int = 0
	var expected: int = 0
	for k: int in range(0, PLANNED + 1):
		listed += t.guards_on(k, lanes, train.kind(k))
		if t.tithe_on(k, train.kind(k)):
			expected += 1
	check(guard_count <= listed and guard_count >= listed * 9 / 10 and guard_count >= PLANNED / 2,
		"the roofs are guarded as the tuning lists, a guard that fits nowhere left out (%d cyborgs of %d over %d carriages) %s" % [
			guard_count, listed, PLANNED, tag])
	check(tithes.size() == expected and expected >= 3, "a Tithe Collector on each flatcar from carriage %d on (%d) %s" % [
		t.tithe_first, tithes.size(), tag])
	check(lone_tithes, "no guards and no wall fence on a flatcar: its Collector keeps to the runner's lane over its trail %s" % tag)
	check(bands.size() >= PLANNED / 4 and not bands.has("full") and bands.has("low") and bands.has("high"),
		"partial wall fences along the barriers, low and high (%d, %d refused) %s" % [bands.size(), board.refused_fences, tag])
	# The guards on the track as the arena's enemies, the Collectors brought in as the runner reaches them
	# (in the runner's lane), the wall fences as track pieces.
	var cyborgs: int = 0
	var collectors: int = 0
	for e: Dictionary in boss.arena.layout.enemies:
		match String(e["type"]):
			"cyborg":
				cyborgs += 1
			"tithe_collector":
				collectors += 1
	var due: Array = board.tithes_due.map(func(d: Dictionary) -> int: return int(d["k"]))
	check(cyborgs == guard_count and collectors == 0 and due == tithes,
		"the guards come onto the track as its enemies, the Collectors wait for the runner %s" % tag)
	check(boss.arena.layout.wall_fences.size() == bands.size(), "and the wall fences as its pieces %s" % tag)
	# A level's rules for its wall fences, all but the feature's: the encounter places them itself, so its
	# arena's config lists no feature for the generator to place its own.
	var fenced: LevelConfig = boss.arena.config.duplicate() as LevelConfig
	fenced.features = PackedStringArray(["wall_fences_partial"])
	LayoutChecks.check_wall_fences(self, boss.arena.layout, fenced, tag)
	# A way through: at every point of every carriage some lane is clear of every guard's reach, and its
	# coupling's lane is clear over the coupling's run-up.
	var through: bool = true
	for k: int in range(board.carriages.keys().min(), PLANNED + 1):
		var roof: Vector2 = train.roof(k)
		var d: float = maxf(roof.x, 0.0)
		while d < roof.y:
			var blocked: int = 0
			for g: Dictionary in board.carriages[k]["guards"]:
				var reach: Vector2 = board.guard_reach(k, g)
				if d >= reach.x - 1.0 and d <= reach.y + 1.0:
					blocked += 1
			if blocked >= lanes:
				through = false
			d += 2.0
	check(through, "a way through every carriage %s" % tag)
	await sim.free_world(world)


# --- The Collectors' cap -------------------------------------------------------------------------

## OPEN_QUESTIONS item 321: a caught Tithe Collector pays its jackpot and phase 1 has no time limit, so a
## runner who lets the couplings go by could farm them. The Board brings at most tithe_visits_per_phase
## into play in a phase (DESIGN-TBD); those due beyond it never come (logged), counted phase by phase.
func _test_tithe_cap() -> void:
	var pair: Array = _fight(def, 5, 23.4)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var t: HostileTakeoverTuning = boss.tuning
	var board: HostileTakeoverBoard = boss.board
	var came: Array[int] = [0]
	world.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.type_id == &"tithe_collector":
			came[0] += 1)
	board.tithes_due.clear()
	for i: int in t.tithe_visits_per_phase + 2:
		board.tithes_due.append({"k": 100 + i * 6, "at": world.player.distance})
	board.tick()
	var skipped: int = boss.events.filter(func(e: Dictionary) -> bool: return e["event"] == &"tithe_skipped").size()
	check(came[0] == t.tithe_visits_per_phase and board.visits_skipped == 2 and skipped == 2 and board.tithes_due.is_empty()
		and int(board.visits.get(0, 0)) == t.tithe_visits_per_phase,
		"at most %d Tithe Collectors come in a phase, the rest never do (%d came, %d left out)" % [
			t.tithe_visits_per_phase, came[0], board.visits_skipped])
	await sim.free_world(world)


# --- Phase 2's plan: The Contract ------------------------------------------------------------------

## GDD §10, phase 2: "the gunship strafes the lanes ... and drops a Buzz Overdrive onto the roof ahead, which
## cuts a carriage lane. An armored carriage with no roof access blocks the way, so the player takes an
## anti-grav pad and rides the gunship's belly over it". Planned from phase 2's start (a checkpoint's) at
## this lane count and speed, over DROPS flatcars:
## - each drop's cut is a level's (FloorCutPlan with the C2 tank's own rev, charge, charge speed, run past
##   and keep, and no roll: the drop brings it into view), its lane window on its flatcar's roof, and a
##   level's rules for cuts hold for it, checked independently (LayoutChecks.check_cuts, its tank standing
##   at its end as the generator's would: no hole in its lane, the lanes beside it whole, nothing else going
##   on, a runner in its lane when it warns can leave it);
## - each ride: a runway of pads the lane's full width in every lane, longer than any leap at this speed (a
##   jump with a dash: HostileTakeoverContract.longest_leap), on the carriage before the armored one; the
##   armored carriage too tall to jump onto, and low enough that a jump from the belly never reaches it;
##   the belly over the runner from the runway's start until past the armored carriage's far gap, its drop
##   bay passing over them, and the runner back on the next carriage's roof before its gap;
## - a strafe strikes fewer lanes than there are, so a lane beside its lines is always free.
func _test_contract(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(def, lanes, speed, null, 1)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var t: HostileTakeoverTuning = boss.tuning
	var c: HostileTakeoverContract = boss.contract
	var train: HostileTakeoverTrain = boss.train
	var m: MovementTuning = world.tuning
	var pace: float = m.pace()
	var saw := BuzzRules.tuning()
	var drops: Array[Dictionary] = []
	var rides: Array[Dictionary] = []
	var k: int = train.next_flatcar(1)
	for i: int in DROPS * 3:
		if drops.size() >= DROPS:
			break
		var drop: Dictionary = c.plan_drop(k)
		if not drop.is_empty():
			drops.append(drop)
			var ride: Dictionary = c.plan_ride(k + 2)
			if not ride.is_empty():
				rides.append(ride)
		k = train.next_flatcar(k + 1)
	check(drops.size() == DROPS and rides.size() == DROPS and int(drops[0]["k"]) == train.next_flatcar(1),
		"a drop on each flatcar, the first one's planned from the phase's start, and the ride after each %s" % tag)
	# The drops: a level's cuts, the C2 tank's numbers.
	var copy: LevelLayout = boss.arena.layout.copy()
	var numbers_ok: bool = true
	var on_flatcar: bool = true
	for drop: Dictionary in drops:
		var cut: Dictionary = drop["cut"]
		var v: float = m.run_speed
		numbers_ok = numbers_ok and is_equal_approx(float(cut["charge"]), saw.charge_distance(v, pace))
		numbers_ok = numbers_ok and is_equal_approx(float(cut["warn"]), saw.charge_distance(v, pace) + saw.rev_at(boss.arena.config.enemy_scaling) * v)
		numbers_ok = numbers_ok and is_equal_approx(float(cut["speed"]), saw.charge_speed_at(pace)) and is_equal_approx(float(cut["keep"]), saw.keep())
		numbers_ok = numbers_ok and not cut.has("lead") and boss.arena.layout.cuts.has(cut)
		var roof: Vector2 = train.roof(int(drop["k"]))
		var window: Vector2 = FloorCutPlan.lane_window(cut)
		on_flatcar = on_flatcar and train.kind(int(drop["k"])) == HostileTakeoverTrain.Kind.FLATCAR and window.x >= roof.x \
			and window.y <= roof.y + 0.01
		copy.enemies.append({"type": "buzz_overdrive", "at": cut["end"], "lane": cut["lane"], "side": 0})
	check(numbers_ok, "each drop's cut is the Buzz Overdrive's own: its rev, charge, speed and keep, no roll %s" % tag)
	check(on_flatcar, "its lane window on its flatcar's roof %s" % tag)
	LayoutChecks.check_cuts(self, copy, boss.arena.config, tag)
	# The rides.
	var strip_ok: bool = true
	var cover_ok: bool = true
	var bay_ok: bool = true
	var land_ok: bool = true
	var belly: float = HostileTakeoverModel.BELLY_FRONT + HostileTakeoverModel.BELLY_STERN
	for ride: Dictionary in rides:
		var rk: int = int(ride["k"])
		var strip: Vector2 = ride["strip"]
		var before: Vector2 = train.roof(rk - 1)
		strip_ok = strip_ok and strip.x >= before.x and strip.y <= before.y - t.pad_before * pace + 0.01 \
			and train.kind(rk) == HostileTakeoverTrain.Kind.CORPORATE and float(ride["pad_at"]) == strip.x
		# Over the runner from the runway's start (its stern well behind them) until the landing point, where
		# its front reaches them by design (they drop off as it passes): sampled every metre and just short of it.
		var d: float = float(ride["pad_at"])
		while d <= float(ride["land_at"]):
			var at: float = minf(d, float(ride["land_at"]) - 0.05)
			var front: float = c.belly_front(ride, at)
			cover_ok = cover_ok and front > at and front - belly < at - 1.0
			d += 1.0
		var bay_then: float = c.belly_front(ride, float(ride["pad_at"])) - HostileTakeoverModel.BELLY_FRONT + HostileTakeoverModel.BAY_AHEAD
		var bay_last: float = c.belly_front(ride, float(ride["land_at"])) - HostileTakeoverModel.BELLY_FRONT + HostileTakeoverModel.BAY_AHEAD
		bay_ok = bay_ok and bay_then > float(ride["pad_at"]) + 2.0 and bay_last < float(ride["land_at"]) - 2.0 and c.bay_lead(ride) > 0.5
		var stretch: Vector2 = c.ride_stretch(ride)
		land_ok = land_ok and float(ride["land_at"]) > train.gap_end(rk) + 1.0 and stretch.y + 2.0 < train.gap_start(rk + 1) \
			and float(ride["descend_from"]) < float(ride["pad_at"]) and float(ride["climb_to"]) > float(ride["land_at"])
	var armored: HostileTakeoverArmored = boss.armored
	var length: float = armored.strip_length()
	var full_width: bool = armored.pads.size() == lanes
	for i: int in armored.pads.size():
		var box := (armored.pads[i].get_child(0) as CollisionShape3D).shape as BoxShape3D
		full_width = full_width and box.size.x >= world.geo.lane_width - 0.01 and is_equal_approx(armored.pads[i].position.x, world.geo.lane_x(i))
	check(full_width and strip_ok and HostileTakeoverContract.strip_clears(m, length),
		"a runway of pads in every lane, its full width, %.1f m long: no leap clears it (%.1f m at the most) %s" % [
			length, HostileTakeoverContract.longest_leap(m), tag])
	check(t.armored_height > m.jump_height + 0.2 and m.ceiling_height - m.jump_height - m.visual_size.y > t.armored_height + 0.4,
		"the armored carriage: too tall to jump onto, below a jump from the belly")
	check(cover_ok, "the belly is over the runner from the runway to past the armored carriage %s" % tag)
	check(bay_ok, "its drop bay passes over them on the way %s" % tag)
	check(land_ok, "they drop off onto the next carriage's roof, before its gap %s" % tag)
	# The strafes.
	var struck: int = t.struck_lanes(lanes)
	check(struck >= 1 and struck < lanes and (lanes <= 3 or struck <= lanes - 2),
		"a strafe strikes %d of %d lanes: one beside its lines is always free %s" % [struck, lanes, tag])
	await sim.free_world(world)


# --- The look --------------------------------------------------------------------------------------

## Budgets and the colour rule (GDD §5: only hazards glow in hazard colours; the weak points' red, the gaps'
## orange and the way-up's green chevrons are the fight's): the gunship, the locomotive and the Chairman
## glow only in cold white and the brand's blue; the train's material breaks away and comes back whole; the
## streaming city makes no nodes while the runner goes on; the live couplings' pulse is steady with Reduced
## flashing.
func _test_look() -> void:
	var pair: Array = _fight(def, 6, 23.4)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var skin := world.skin as HostileTakeoverSkin
	check(skin != null, "the fight runs in its own skin")
	var gunship: ArrayMesh = boss.gunship.model.mesh as ArrayMesh
	var loco: ArrayMesh = boss.locomotive.model.mesh as ArrayMesh
	var chairman: ArrayMesh = boss.locomotive.chairman.mesh as ArrayMesh
	var gv: int = HostileTakeoverModel.vertices(gunship)
	var lv: int = HostileTakeoverModel.vertices(loco)
	var cv: int = HostileTakeoverModel.vertices(chairman)
	print("  Hostile Takeover's models: the gunship %d vertices (%d draws), the locomotive %d (%d), the Chairman %d" % [
		gv, gunship.get_surface_count(), lv, loco.get_surface_count(), cv])
	check(gv > 300 and gv < 6000 and gunship.get_surface_count() <= 2, "the gunship is low-poly, merged (%d vertices)" % gv)
	check(lv > 200 and lv < 5000 and loco.get_surface_count() <= 2, "the locomotive is low-poly, merged (%d vertices)" % lv)
	check(cv > 50 and cv < 1500, "the Chairman is a handful of boxes (%d vertices)" % cv)
	var bad: Array[String] = []
	for mesh: ArrayMesh in [gunship, loco, chairman]:
		for i: int in mesh.get_surface_count():
			var colors: PackedColorArray = mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
			for c: Color in colors:
				if c.a > 0.0 and _hazard_hue(Color(c.r, c.g, c.b)) and bad.size() < 3:
					bad.append(str(c))
	check(bad.is_empty(), "nothing on the gunship or the locomotive glows in a hazard's colour: %s" % ", ".join(bad))
	check(HostileTakeoverModel.WEAK.h < 0.05 or HostileTakeoverModel.WEAK.h > 0.95, "the couplings glow the weak points' red")
	# Phase 2's parts: the armored carriage in the solid obstacles' yellow and black, the rakes in the
	# attacks' red, the runway one draw for every tile.
	var armored: ArrayMesh = boss.armored.model.mesh as ArrayMesh
	var yellow: bool = false
	for i: int in armored.get_surface_count():
		for col: Color in armored.surface_get_arrays(i)[Mesh.ARRAY_COLOR]:
			yellow = yellow or (col.s > 0.6 and col.h > 0.1 and col.h < 0.18 and col.v > 0.6)
	var av: int = HostileTakeoverModel.vertices(armored)
	check(yellow and av < 4000, "the armored carriage's front is framed in the solid obstacles' yellow and black (%d vertices)" % av)
	check(_hazard_hue(HostileTakeoverStrafes.RAKE_COLOR) and _hazard_hue(HostileTakeoverStrafes.TRACER_COLOR),
		"the strafes' rakes and tracers glow in the attacks' red")
	var tiles := boss.armored.runway.get_node_or_null(^"Tiles") as MultiMeshInstance3D
	check(tiles != null and tiles.multimesh.instance_count >= 6 * 3 and tiles.multimesh.instance_count % 6 == 0,
		"the runway's pads are one MultiMesh (%d tiles)" % (tiles.multimesh.instance_count if tiles != null else 0))
	# The breakaway on the train's material, and back.
	var m: ShaderMaterial = skin.train_material()
	check(float(m.get_shader_parameter(&"break_age")) < 0.0, "the train starts whole")
	var k_break: int = boss.train.next_flatcar(1) + 1
	var ends: PackedFloat32Array = boss.train.ends_behind(k_break, 8)
	skin.set_breakaway(boss.train.gap_start(k_break), 1.2, ends, boss.tuning)
	var ends_a: Vector4 = m.get_shader_parameter(&"break_ends_a")
	check(is_equal_approx(float(m.get_shader_parameter(&"break_z")), TrackGeometry.world_z(boss.train.gap_start(k_break)))
		and float(m.get_shader_parameter(&"break_age")) > 1.0 and is_equal_approx(ends_a.x, ends[0]) and is_equal_approx(ends_a.y, ends[1])
		and ends[1] - ends[0] > boss.train.roofs[0] + boss.train.gap - 0.01,
		"a breakaway sets the line behind which the carriages tumble, each about its own rear end (a flatcar's further back), and its clock")
	skin.clear_breakaway()
	check(float(m.get_shader_parameter(&"break_age")) < 0.0 and float(m.get_shader_parameter(&"break_z")) > 1.0e8, "and clears")
	# The streaming city: no nodes made while the runner goes on, beyond the chunks' own.
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	world.player.running = true
	await physics_frames(30)
	var parts_before: int = _count(boss)
	var most: int = _most_per_chunk(world.track)
	var peak: int = most
	var chunks: int = 0
	for i: int in 8:
		await physics_frames(20)
		peak = maxi(peak, _most_per_chunk(world.track))
		chunks = maxi(chunks, world.track.get_child_count())
	var window: int = ceili((TrackBuilder.BUILD_AHEAD + TrackBuilder.KEEP_BEHIND) / TrackBuilder.CHUNK_LENGTH) + 3
	check(peak <= most + 4 and chunks <= window and _count(boss) == parts_before,
		"the city streams past without new nodes: a chunk's %d → at most %d, %d chunks at most (%d), the boss's %d → %d" % [
			most, peak, chunks, window, parts_before, _count(boss)])
	# The live couplings pulse (the weak points' language), steady with Reduced flashing.
	var was: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var glows: Array[float] = []
		for i: int in 12:
			await physics_frames(3)
			glows.append(boss.couplings.live_glow())
		var spread: float = float(glows.max()) - float(glows.min())
		if reduced:
			check(is_zero_approx(spread) and is_equal_approx(glows[0], 1.0), "a live coupling glows steady with Reduced flashing")
		else:
			check(spread > 0.1, "a live coupling's glow pulses (%.2f)" % spread)
	# The open drop bay pulses (the weak points' language), the tracers and the muzzle flicker: all steady
	# with Reduced flashing.
	boss.gunship.set_bay(true)
	boss.strafes.start([0] as Array[int])
	boss.gunship.set_firing(true)
	var bay_m := boss.gunship.bay_mesh.material_override as ShaderMaterial
	var beam: MeshInstance3D = boss.strafes.rigs[0]["beam"]
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var glows: Array[float] = []
		var widths: Array[float] = []
		var flashes: Array[float] = []
		for i: int in 12:
			await physics_frames(3)
			boss.strafes.set_front(world.player.distance + 20.0, boss.gunship.gun_point())
			glows.append(float(bay_m.get_shader_parameter(&"state_glow")))
			widths.append(beam.global_transform.basis.x.length())
			flashes.append(boss.gunship.muzzle.scale.x)
		var spread: float = float(glows.max()) - float(glows.min()) + float(widths.max()) - float(widths.min()) \
			+ float(flashes.max()) - float(flashes.min())
		if reduced:
			check(is_zero_approx(spread), "the open bay, the tracers and the muzzle are steady with Reduced flashing")
		else:
			check(float(glows.max()) - float(glows.min()) > 0.1 and float(widths.max()) - float(widths.min()) > 0.01,
				"the open bay pulses and the tracers flicker")
	boss.strafes.stop()
	boss.gunship.set_firing(false)
	boss.gunship.set_bay(false)
	Settings.flashing_reduced = was
	var towers: Dictionary = skin.towers_for(1, world.geo.wall_x())
	var verts: PackedVector3Array = towers["verts"]
	var inside: bool = false
	for v: Vector3 in verts:
		inside = inside or absf(v.x) < world.geo.wall_x() + skin.near_towers_from_to.x - 0.01
	check(not inside and verts.size() > 0, "the towers stand beyond the barriers, never over the street")
	await sim.free_world(world)


func _count(node: Node) -> int:
	var n: int = 1
	for child: Node in node.get_children():
		n += _count(child)
	return n


## The most nodes any one of the track's chunks holds.
func _most_per_chunk(track: Node) -> int:
	var most: int = 0
	for chunk: Node in track.get_children():
		most = maxi(most, _count(chunk))
	return most


static func _hazard_hue(c: Color) -> bool:
	if c.s < GLOW_SATURATION_LIMIT:
		return false
	return c.h < 0.58 or c.h > 0.8
