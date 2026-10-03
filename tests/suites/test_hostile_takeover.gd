extends TestSuite
## Hostile Takeover, the Corporate zone's boss (GDD §10; task E5b): its slot in the campaign and its data
## (par times, sounds, hints), the train arena (its consist of carriages and flatcars; every gap between
## carriages jumpable from every lane at the Corporate zone's 23.4 m/s and quick play's 18 m/s, with the
## player's real jump), what counts as landing on a coupling (its stomp box over the gap, the bounce that
## carries the runner on), phase 1's plan (The Board) at 3, 5 and 6 lanes (the guards, the Tithe Collectors
## and the partial wall fences always leave a way through, and each coupling's lane stays reachable; the
## Collectors capped a phase), phase 2's plan (The Contract: the dropped Buzz Overdrive's cut as a level's,
## the runway of pads and the belly ride over the armored carriage, the strafes' free lanes), phase 3's plan
## (The Merger: the drops after the docking, the passes under the war engine's belly and its three docking
## clamps within reach, the Board back on its carriages), and its look (the colour rule, budgets, nothing
## made while running, phase 3's parts built with the fight, Reduced flashing). The fight itself:
## test_hostile_takeover_fight.gd.

const BOSS_PATH: String = "res://data/bosses/corporate_boss.tres"
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Corporate zone's (GDD §3).
const SPEEDS: Array[float] = [18.0, 23.4]
const NEW_SOUNDS: Array[StringName] = [&"takeover_gunship", &"takeover_couplings", &"takeover_decouple",
	&"takeover_breakaway", &"takeover_whine", &"takeover_strafe", &"takeover_drop", &"takeover_bay", &"takeover_clamps",
	&"takeover_merger", &"takeover_clamp", &"takeover_explode", &"takeover_derail"]
## A jump in a gap's lane takes off this far before its edge (metres at 18 m/s, at the run's pace): the
## latest a runner who reads the gap would leave it.
const HOLE_LEAD: float = 1.6
## Carriages the plan checks are planned over (a few laps' worth of the Board).
const PLANNED: int = 36
## Flatcars whose drop phase 2's plan check plans.
const DROPS: int = 3
## Phase 3's passes its plan check plans.
const PASSES: int = 3
## A runner back on the roof after a pass has at least this long before the next gap (seconds).
const LANDING_SECONDS: float = 0.5
## A clamp's take-off window and its landing keep this far inside the clamp's ends (metres along the belly).
const CLAMP_MARGIN: float = 0.2
## A runner's reaction time (the bot's), and how long the runway's pad takes to flip them up onto the belly.
const REACTION: float = 0.35
const BOARD_SECONDS: float = 0.3
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
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "Hostile Takeover's fight loads")
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
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_merger_plan(lanes, speed)
	await _test_look()
	await _test_merger_look()


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
	check(slot.is_built() and slot.scene == "res://scenes/bosses/hostile_takeover.tscn" and slot.preview_scene == ""
		and slot.preview() == null, "the campaign plays the fight in the Corporate zone's boss slot (task E5b-c)")
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var step: CampaignStep = campaign.step("corporate/boss") if campaign != null else null
	var ids: Array[String] = []
	if campaign != null:
		for s: CampaignStep in campaign.steps():
			ids.append(s.id)
	check(step != null and step.boss == slot and is_equal_approx(step.zone.run_speed, 23.4)
		and ids.find("corporate/boss") == ids.find("corporate/2") + 1 and ids.find("corporate/outro") == ids.find("corporate/boss") + 1,
		"after Corporate 2 and before its outro, at the zone's 23.4 m/s")
	check(slot.three_star_seconds < slot.two_star_seconds and slot.three_star_seconds >= 60.0 and slot.two_star_seconds <= 120.0,
		"par times: %.0f s for three stars, %.0f s for two (GDD §10: 60-120 s)" % [slot.three_star_seconds, slot.two_star_seconds])
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
			"boss:corporate_boss/ride", "boss:corporate_boss/merger", "boss:corporate_boss/clamps"]:
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
	check(HostileTakeover.pattern_of(0) == HostileTakeover.Pattern.BOARD and HostileTakeover.pattern_of(1) == HostileTakeover.Pattern.CONTRACT
		and HostileTakeover.pattern_of(2) == HostileTakeover.Pattern.MERGER, "phase 1 plays The Board, phase 2 The Contract, phase 3 The Merger")
	check(sfx.stream(&"takeover_whine").get_length() >= t.strafe_warning - 0.05 and sfx.stream(&"takeover_whine").get_length() <= t.strafe_warning + 0.4,
		"the strafe's rising whine lasts its warning (%.2f s)" % sfx.stream(&"takeover_whine").get_length())
	check(sfx.stream(&"takeover_clamps").get_length() <= t.dock_seconds and sfx.stream(&"takeover_merger").get_length() <= t.merger_flash_seconds,
		"the docking's clamps lock and MERGER COMPLETE's sting within the docking and the flashing")
	check(t.explode_at + sfx.stream(&"takeover_explode").get_length() <= t.defeat_seconds + 0.05
		and t.crash_at + sfx.stream(&"takeover_derail").get_length() <= t.defeat_seconds + 0.05 and t.explode_at < t.crash_at,
		"the defeat's explosion, then the crash, both heard out before the results (%.1f s)" % t.defeat_seconds)
	check(t.clamp_at.size() == 3 and t.clamp_side.size() == 3 and t.merger_text != "", "three docking clamps; the screens' words")


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


# --- Phase 3's plan: The Merger --------------------------------------------------------------------

## GDD §10, phase 3: "the locomotive comes back and the gunship docks onto it ... its attacks combine both
## phases' ... the player stomps the three glowing docking clamps to tear the gunship loose". Planned from
## phase 3's start (a checkpoint's) at this lane count and speed:
## - the drops as phase 2's (a level's cuts, checked independently), none moving out before the docking is
##   over, over PASSES flatcars;
## - after each, a pass: a runway of pads in every lane on the corporate carriage after the flatcar, longer
##   than any leap, its far end pad_before short of the carriage's gap; the war engine's belly over the
##   runner from the runway's start until its stern passes over them (they ride along it at pass_speed, so
##   the ride takes the same seconds at every speed), and their drop back onto a roof at least
##   LANDING_SECONDS short of the next gap;
## - the three docking clamps along the belly, one under each third of it with a lane under it; for each, a
##   jump from anywhere on its take-off cue comes back up onto it (clamp_lead, CLAMP_MARGIN inside its ends),
##   the cue just short of it, before the war engine pulls away; the first one's cue ends long enough after
##   the runner boards for a reaction and two lane moves, and each next one's after the last one's stomp
##   has bounced them back onto the belly;
## - The Board back: guards and wall fences only on merger_board_slots' carriages (none on a pass's runway or
##   landing carriage or on a flatcar, no Tithe Collector), fewer guards than lanes, the wall fences a level's
##   (LayoutChecks.check_wall_fences, independently);
## - a strafe strikes fewer lanes than there are.
func _test_merger_plan(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(def, lanes, speed, null, 2)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var t: HostileTakeoverTuning = boss.tuning
	var c: HostileTakeoverContract = boss.contract
	var train: HostileTakeoverTrain = boss.train
	var board: HostileTakeoverBoard = boss.board
	var m: MovementTuning = world.tuning
	var pace: float = m.pace()
	var v: float = m.run_speed
	check(c.active and c.merger and board.merger and c.not_before >= world.player.distance + t.dock_seconds * v,
		"phase 3: the war engine's drops and passes, none before its docking is over, the Board back %s" % tag)
	# The drops and the passes.
	var drops: Array[Dictionary] = []
	var passes: Array[Dictionary] = []
	var k: int = train.next_flatcar(1)
	for i: int in PASSES * 4:
		if drops.size() >= PASSES:
			break
		var drop: Dictionary = c.plan_drop(k)
		if not drop.is_empty():
			drops.append(drop)
			var ride: Dictionary = c.plan_pass(k + 1)
			if not ride.is_empty():
				passes.append(ride)
		k = train.next_flatcar(k + 1)
	check(drops.size() == PASSES and passes.size() == PASSES, "a drop on each flatcar after the docking and a pass after each %s" % tag)
	var early: bool = false
	var copy: LevelLayout = boss.arena.layout.copy()
	for drop: Dictionary in drops:
		early = early or float(drop["release_p"]) - float(drop["move"]) < c.not_before
		var cut: Dictionary = drop["cut"]
		copy.enemies.append({"type": "buzz_overdrive", "at": cut["end"], "lane": cut["lane"], "side": 0})
	check(not early, "no drop moves out before the docking is over %s" % tag)
	LayoutChecks.check_cuts(self, copy, boss.arena.config, tag)
	var length: float = boss.armored.strip_length()
	var belly: float = HostileTakeoverModel.BELLY_FRONT + HostileTakeoverModel.BELLY_STERN
	var strip_ok: bool = true
	var cover_ok: bool = true
	var seconds_ok: bool = true
	var land_ok: bool = true
	var least: float = INF
	var pass_carriages: Array[int] = []
	for ride: Dictionary in passes:
		var rk: int = int(ride["k"])
		var strip: Vector2 = ride["strip"]
		var roof: Vector2 = train.roof(rk)
		strip_ok = strip_ok and ride["pass"] and train.kind(rk) == HostileTakeoverTrain.Kind.CORPORATE \
			and train.kind(rk - 1) == HostileTakeoverTrain.Kind.FLATCAR and strip.x >= roof.x and strip.y <= roof.y - t.pad_before * pace + 0.01 \
			and is_equal_approx(strip.y - strip.x, length) and is_equal_approx(float(ride["pad_at"]), strip.x) \
			and float(ride["descend_from"]) < strip.x
		var d: float = float(ride["pad_at"])
		while d < float(ride["land_at"]):
			var u: float = c.pass_u(ride, d)
			cover_ok = cover_ok and u > 0.0 and u < belly
			d += 0.5
		cover_ok = cover_ok and absf(c.pass_u(ride, float(ride["land_at"]))) < 0.01
		seconds_ok = seconds_ok and absf((float(ride["pull_at"]) - float(ride["pad_at"])) / v
			- (t.pass_release - t.pass_rear_margin) / t.pass_speed) < 0.01
		var landing: float = c.ride_stretch(ride).y
		var g: int = train.next_gap(landing)
		var margin: float = minf(train.gap_start(g) - landing, landing - train.gap_end(g - 1))
		least = minf(least, margin / v)
		land_ok = land_ok and margin >= LANDING_SECONDS * v
		pass_carriages.append(rk)
		pass_carriages.append(train.carriage_at(landing))
	check(strip_ok and HostileTakeoverContract.strip_clears(m, length),
		"each pass's runway of pads on the carriage after the flatcar, %.1f m long: no leap clears it %s" % [length, tag])
	check(cover_ok, "the war engine's belly over the runner from the runway until its stern passes them %s" % tag)
	check(seconds_ok, "they ride its belly %.1f s, at every speed %s" % [(t.pass_release - t.pass_rear_margin) / t.pass_speed, tag])
	check(land_ok, "and drop back onto a roof, %.2f s at the least before the next gap %s" % [least, tag])
	# The clamps: one under each third of the belly, a lane under each, each within reach on the ride.
	var g_ship: HostileTakeoverGunship = boss.gunship
	var sides: Array[int] = []
	var under_ok: bool = g_ship.clamps.size() == 3
	for cl: Dictionary in g_ship.clamps:
		sides.append(int(cl["side"]))
		var width: float = (cl["point"] as Hazard).size.x
		var mid_x: float = float(cl["side"]) * g_ship.belly_width / 3.0
		var under: int = 0
		for lane: int in lanes:
			if absf(world.geo.lane_x(lane) - mid_x) <= width * 0.5:
				under += 1
		under_ok = under_ok and under >= 1
	sides.sort()
	check(under_ok and sides == [-1, 0, 1], "three docking clamps, one under each third of the belly, a lane under each %s" % tag)
	var lead: float = g_ship.clamp_lead()
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var g_up: float = m.gravity()
	var bounce_h: float = rules.stomp_bounce_velocity * rules.stomp_bounce_velocity / (2.0 * g_up)
	var bounce: float = rules.stomp_bounce_velocity / g_up + sqrt(2.0 * bounce_h / (g_up * m.fall_gravity_multiplier))
	var ready: float = REACTION + 2.0 * m.lane_switch_time
	var reach_ok: bool = true
	var soonest: float = INF
	var back_at: float = t.pass_rear_margin + BOARD_SECONDS * t.pass_speed
	var order: Array[int] = [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool: return float(g_ship.clamps[a]["at"]) < float(g_ship.clamps[b]["at"]))
	for i: int in order:
		var at: float = float(g_ship.clamps[i]["at"])
		var span := Vector2(at - t.clamp_length * 0.5, at + t.clamp_length * 0.5)
		var cue: Vector2 = g_ship.clamp_cue(i)
		reach_ok = reach_ok and cue.x + lead >= span.x + CLAMP_MARGIN and cue.y + lead <= span.y - CLAMP_MARGIN \
			and cue.y < span.x and cue.y + lead <= t.pass_release
		soonest = minf(soonest, (cue.y - back_at) / t.pass_speed)
		# Stomped on its middle, the bounce brings them back onto the belly this far on.
		back_at = at + bounce * t.pass_speed
	check(reach_ok and lead > 0.5, "a jump from anywhere on a clamp's cue comes back up onto it (%.2f m on), before the war engine pulls away %s" % [
		lead, tag])
	check(soonest >= ready, "from boarding, and from each stomp's bounce, %.2f s at the least to the next clamp's cue's end (a reaction and two lane moves: %.2f s) %s" % [
		soonest, ready, tag])
	# The Board, back on its slots' carriages.
	var from: int = maxi(board.planned + 1, 0)
	while board.planned < from + 18:
		board.plan(board.planned + 1)
	var board_ok: bool = true
	var fences: int = 0
	var guards: int = 0
	for j: int in range(from, board.planned + 1):
		var rec: Dictionary = board.carriages[j]
		var slot_j: int = train.slot(j)
		var n: int = (rec["guards"] as Array).size()
		guards += n
		var on_slot: bool = t.merger_board_slots.has(slot_j) and train.kind(j) != HostileTakeoverTrain.Kind.FLATCAR
		board_ok = board_ok and float(rec["tithe"]) < 0.0 and n <= t.merger_guards_on(lanes, train.kind(j), slot_j) and n < lanes
		board_ok = board_ok and (on_slot or (n == 0 and (rec["wall_fence"] as Dictionary).is_empty()))
		if not (rec["wall_fence"] as Dictionary).is_empty():
			fences += 1
	var clear_ok: bool = true
	for j: int in pass_carriages:
		if board.carriages.has(j):
			clear_ok = clear_ok and (board.carriages[j]["guards"] as Array).is_empty()
		clear_ok = clear_ok and not t.merger_board_slots.has(train.slot(j))
	check(board_ok and guards >= 1 and fences >= 1,
		"the Board's guards (%d) and wall fences (%d) only on its slots' carriages, no Tithe Collector %s" % [guards, fences, tag])
	check(clear_ok, "never on a pass's runway or landing carriage %s" % tag)
	var fenced: LevelConfig = boss.arena.config.duplicate() as LevelConfig
	fenced.features = PackedStringArray(["wall_fences_partial"])
	LayoutChecks.check_wall_fences(self, boss.arena.layout, fenced, tag)
	var struck: int = t.struck_lanes(lanes)
	check(struck >= 1 and struck < lanes, "a strafe strikes %d of %d lanes %s" % [struck, lanes, tag])
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


## Phase 3's look (GDD §5's colour rule; Reduced flashing; task PERF1): its parts are built with the fight
## and hidden (the clamps folded, the screens dark, the lobby away); the clamps' locks glow the weak points'
## red with the green chevrons of the ways up behind them, while the rest of the clamps, the arms, the
## screens' words, the lobby tower and its sculpture glow in no hazard colour, all of it low-poly; MERGER
## COMPLETE flashes and the clamps pulse, both steady with Reduced flashing; and from the docking through
## a pass to the defeat, the boss's parts make no node.
func _test_merger_look() -> void:
	var pair: Array = _fight(def, 5, 23.4, null, 2)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var g: HostileTakeoverGunship = boss.gunship
	var t: HostileTakeoverTuning = boss.tuning
	var first: Dictionary = g.clamps[0]
	check(not g.docked and (first["folded"] as Node3D).visible and not (first["body"] as Node3D).visible
		and not (first["cue"] as Node3D).visible and not boss.screens.on and not boss.lobby.visible and boss.screens.screens.size() == 3,
		"phase 3's parts are built with the fight and hidden: the clamps folded, three screens dark, the lobby away")
	var parts_before: int = _parts(boss)
	# Colours.
	var bad: Array[String] = []
	var meshes: Array[Mesh] = [(first["body"] as MeshInstance3D).mesh, (first["folded"] as MeshInstance3D).mesh,
		(boss.lobby.tower as MeshInstance3D).mesh]
	for node: Node in boss.lobby.sculpture.get_children():
		if node is MeshInstance3D:
			meshes.append((node as MeshInstance3D).mesh)
	for arm: Node3D in g.arms:
		for node: Node in arm.get_children():
			if node is MeshInstance3D:
				meshes.append((node as MeshInstance3D).mesh)
	var verts: int = 0
	for mesh: Mesh in meshes:
		var array_mesh := mesh as ArrayMesh
		if array_mesh == null:
			continue
		verts = maxi(verts, HostileTakeoverModel.vertices(array_mesh))
		for i: int in array_mesh.get_surface_count():
			for col: Color in array_mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]:
				if col.a > 0.0 and _hazard_hue(Color(col.r, col.g, col.b)) and bad.size() < 3:
					bad.append(str(col))
	check(bad.is_empty() and not _hazard_hue(HostileTakeoverScreens.TEXT_COLOR),
		"nothing on the clamps' bodies, the arms, the screens' words, the tower or its sculpture glows in a hazard's colour: %s" % ", ".join(bad))
	print("  Hostile Takeover's phase 3 models: the largest %d vertices (the lobby tower %d, its sculpture %d)" % [verts,
		HostileTakeoverModel.vertices((boss.lobby.tower as MeshInstance3D).mesh as ArrayMesh),
		HostileTakeoverModel.vertices(((boss.lobby.sculpture.get_child(0) as MeshInstance3D).mesh) as ArrayMesh)])
	check(verts < 6000, "low-poly (%d vertices at the most)" % verts)
	var core := (first["core"] as MeshInstance3D).mesh as ArrayMesh
	var red: bool = true
	for i: int in core.get_surface_count():
		for col: Color in core.surface_get_arrays(i)[Mesh.ARRAY_COLOR]:
			red = red and (col.h < 0.05 or col.h > 0.95) and col.s > 0.5
	var cue := (first["cue"] as MeshInstance3D).mesh as ArrayMesh
	var green: bool = cue != null
	for i: int in (cue.get_surface_count() if cue != null else 0):
		for col: Color in cue.surface_get_arrays(i)[Mesh.ARRAY_COLOR]:
			green = green and col.h > 0.2 and col.h < 0.45
	check(red and green, "the clamps' locks glow the weak points' red, the chevrons behind them the ways up's green")
	# Through the docking (god mode: the runner just runs on).
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	var bot := HostileTakeoverBot.new(boss)
	bot.reaction = 0.35
	await tree.physics_frame
	world.player.running = true
	for i: int in 12 * 60:
		bot.step()
		if boss.docked:
			break
		await tree.physics_frame
	check(boss.docked and g.docked and boss.screens.on and boss.step == HostileTakeover.Step.MERGED and (first["body"] as Node3D).visible
		and (first["cue"] as Node3D).visible and not boss.locomotive.chairman.visible,
		"docked: the clamps unfolded with their cues, the screens on, the Chairman gone from his window")
	# MERGER COMPLETE flashes and the clamps pulse; both steady with Reduced flashing.
	var was: bool = Settings.flashing_reduced
	var lock := (first["core"] as MeshInstance3D).material_override as ShaderMaterial
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		boss.screens.set_on(true)
		var words: Array[float] = []
		var glows: Array[float] = []
		for i: int in 16:
			await physics_frames(3)
			bot.step()
			words.append(boss.screens.text_material.emission_energy_multiplier)
			glows.append(float(lock.get_shader_parameter(&"state_glow")))
		var flash: float = float(words.max()) - float(words.min())
		var pulse: float = float(glows.max()) - float(glows.min())
		if reduced:
			check(is_zero_approx(flash) and float(words.min()) > 0.5 and is_zero_approx(pulse),
				"MERGER COMPLETE glows steady, and the clamps too, with Reduced flashing")
		else:
			check(flash > 0.5 and pulse > 0.1, "MERGER COMPLETE flashes and the clamps pulse (%.2f, %.2f)" % [flash, pulse])
	Settings.flashing_reduced = was
	# On through a pass to the defeat: the boss's parts make no node.
	for i: int in 60 * 60:
		bot.step()
		if boss.victory_over():
			break
		await tree.physics_frame
	check(boss.is_defeated() and boss.victory_over() and _parts(boss) == parts_before,
		"from the docking through its passes to the defeat, its parts make no node (%d → %d)" % [parts_before, _parts(boss)])
	await sim.free_world(world)


## The nodes the boss's parts hold.
func _parts(boss: BossEncounter) -> int:
	var n: int = 0
	for part: BossPart in boss.parts:
		if is_instance_valid(part):
			n += _count(part)
	return n


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
