extends TestSuite
## Hostile Takeover, the Corporate zone's boss (GDD §10; task E5b-a): its slot and data, the train arena
## (every gap between carriages jumpable from every lane at the Corporate zone's 23.4 m/s and quick play's
## 18 m/s, with the player's real jump), what counts as landing on a coupling (its stomp box over the gap,
## the bounce that carries the runner on), phase 1's plan (The Board) at 3, 5 and 6 lanes (the guards, the
## Tithe Collectors and the partial wall fences always leave a way through, and each coupling's lane stays
## reachable), and its look (the colour rule, budgets, nothing made while running). The fight itself:
## test_hostile_takeover_fight.gd.

const BOSS_PATH: String = "res://data/bosses/corporate_boss.tres"
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Corporate zone's (GDD §3).
const SPEEDS: Array[float] = [18.0, 23.4]
const NEW_SOUNDS: Array[StringName] = [&"takeover_gunship", &"takeover_couplings", &"takeover_decouple",
	&"takeover_breakaway"]
## A jump in a gap's lane takes off this far before its edge (metres at 18 m/s, at the run's pace): the
## latest a runner who reads the gap would leave it.
const HOLE_LEAD: float = 1.6
## Carriages the plan checks are planned over (a few laps' worth of the Board).
const PLANNED: int = 36
## A saturated colour outside the decorative blue-to-violet band glows only on hazards (GDD §5).
const GLOW_SATURATION_LIMIT: float = 0.35
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")

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
	await _test_look()


## The fight at `lanes` and `speed` m/s (the arena config at that speed, as the campaign sets it): [world, boss].
func _fight(p_def: BossDef, lanes: int, speed: float, loadout: Loadout = null) -> Array:
	var boss := BossEncounter.create(p_def) as HostileTakeover
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
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
	for trigger: String in ["enemy:corporate_boss", "boss:corporate_boss/couplings"]:
		check(triggers.has(trigger), "a first-time hint for %s" % trigger)
	var t := def.tuning as HostileTakeoverTuning
	check(t.opening_for(0) >= 1 and t.opening_for(7) == t.opening_gaps[-1], "each phase opens with dark gaps (the last entry's for later ones)")
	check(t.guards_on(0, 5) == 0 and t.guards_on(t.guards_from, 3) <= 2 and t.guards_on(t.guards_from, 6) >= 1
		and not t.tithe_on(t.guards_from), "guards from their carriage on, at most one fewer than the lanes")
	check(t.tithe_on(t.tithe_first) and t.guards_on(t.tithe_first, 6) == 0, "none on a Tithe Collector's carriage")


# --- The train -----------------------------------------------------------------------------------

## GDD §10: "carriage roofs are the floor and the gaps between carriages are the gaps". Every lap is the
## train: a gap across every lane at the end of each carriage, a level's jump long (a share of a jump at the
## run speed, within the generator's longest), at a steady pitch that runs on across the laps; nothing else.
## Every gap is jumpable from every lane with the player's real jump, at this speed.
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
		var steady: bool = true
		for i: int in range(1, keys.size()):
			steady = steady and absf(float(keys[i]) - float(keys[i - 1]) - train.pitch) < 0.01
		check(steady and is_equal_approx(arena.lap_length, train.pitch * train.per_lap),
			"carriages at a steady pitch (%.1f m), the laps joining seamlessly %s" % [train.pitch, lane_tag])
		check(train.pitch - train.gap >= t.carriage_length * arena.tuning.pace() * 0.85,
			"a carriage keeps its length in seconds (%.1f m) %s" % [train.pitch - train.gap, lane_tag])
		check(float(keys[0]) >= arena.tuning.pace() * 30.0 and float(keys[0]) < train.pitch,
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
## stays reachable; a Tithe Collector every tithe_every carriages; partial wall fences only where the level's
## rules allow (LayoutChecks.check_wall_fences, independently), the low and high bands in turn.
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
			if not guards.is_empty():
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
		listed += t.guards_on(k, lanes)
		if t.tithe_on(k):
			expected += 1
	check(guard_count <= listed and guard_count >= listed * 9 / 10 and guard_count >= PLANNED * 2 / 3,
		"the roofs are guarded as the tuning lists, a guard that fits nowhere left out (%d cyborgs of %d over %d carriages) %s" % [
			guard_count, listed, PLANNED, tag])
	check(tithes.size() == expected and expected >= 3, "a Tithe Collector every %d carriages (%d) %s" % [t.tithe_every, tithes.size(), tag])
	check(lone_tithes, "no guards on a Tithe Collector's carriage: it keeps to the runner's lane over its trail %s" % tag)
	check(bands.size() >= PLANNED / 3 and not bands.has("full") and bands.has("low") and bands.has("high"),
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
	# The breakaway on the train's material, and back.
	var m: ShaderMaterial = skin.train_material()
	check(float(m.get_shader_parameter(&"break_age")) < 0.0, "the train starts whole")
	skin.set_breakaway(500.0, 1.2, boss.train.pitch, boss.train.pitch - boss.train.gap, boss.tuning)
	check(is_equal_approx(float(m.get_shader_parameter(&"break_z")), -500.0) and float(m.get_shader_parameter(&"break_age")) > 1.0,
		"a breakaway sets the line behind which the carriages tumble, and its clock")
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
