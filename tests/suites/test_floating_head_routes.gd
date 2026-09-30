extends TestSuite
## The Floating Head's ways onto its head after the owner's playtest (September 30, 2026; task E1e):
## - the fallen tower's ramp boards from its side: a lane switch into its lane anywhere along its lead-in
##   steps up its bevelled side onto it, never into it, and beside the slab above that a switch bumps;
##   in the fight a runner who boards it late, at 3, 5 and 6 lanes and from either side, still stomps;
## - the wall route shows its way: marks on both walls from where to get on to where to jump, with their
##   sound, gone when the window closes, nothing in a hazard colour, and none on the other routes; a
##   runner who follows them stomps with one wall jump, from either wall, getting on anywhere along the
##   marks before the release line and jumping within a metre of the jump mark (at 5 and 6 lanes the
##   outer lanes, where a wall jump lands, are covered by the outermost weak points' stomp boxes, which a
##   jump from the trucks still can't reach);
## - the ceiling route stomps from a pad in any lane, riding straight ahead;
## - the first time each way up comes, a hint says how to take it (once per profile);
## - a runner with no armor and no shield gets an armor pickup early in each phase (the standard rule's
##   final-phase one, and after a break, as before);
## - end to end through the campaign's flow at 3, 5 and 6 lanes, with no armor or shield: a runner who
##   takes each route the forgiving way (boarding the ramp late from its side, one wall jump at the
##   mark, a pad and no move on the ceiling) stomps in every phase; a death restarts the fight (it has
##   no checkpoint, GDD §10) and the retry plays all three routes again, to the win.

const BOSS_PATH: String = "res://data/bosses/city_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const ROUTES: Array[StringName] = [&"ramp", &"wall", &"ceiling"]

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	def = load(BOSS_PATH) as BossDef
	check(def != null and def.is_built(), "the Floating Head's fight exists")
	if def == null:
		return
	_test_data()
	await _test_side_boarding()
	await _test_late_boarding()
	await _test_wall_marks()
	await _test_wall_forgiveness()
	await _test_ceiling_any_lane()
	await _test_route_hints()
	await _test_unprotected_armor()
	await _test_end_to_end()


# --- Helpers -------------------------------------------------------------------------------

## The fight for a test: straight into the face-off (no bombing runs unless `runs`), a tower lined up at
## once (towers_after 0), marked towers every 200 m from 160 m, on a plain street.
func _def(runs: bool = false) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t := (def.tuning as FloatingHeadTuning).duplicate() as FloatingHeadTuning
	if not runs:
		t.first_run_seconds = 0.0
		t.later_runs = 0
	t.tower_first = 160.0
	t.tower_spacing = 200.0
	t.towers_after = 0
	out.tuning = t
	out.arena = null
	return out


## A fight against `p_def` in a bare world at `lanes`, from phase `phase`, with `loadout`: [world, head].
func _fight(p_def: BossDef, lanes: int, phase: int = 0, loadout: Loadout = null) -> Array:
	var head := BossEncounter.create(p_def) as FloatingHead
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": phase} if phase > 0 else {}
	var arena: BossArena = head.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	head.setup(world, ctx, arena)
	return [world, head]


## Steps the world until `condition` holds or `seconds` pass. True if it held.
func _until(world: RunWorld, condition: Callable, seconds: float) -> bool:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func _events(head: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in head.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(head: BossEncounter, sound: StringName) -> int:
	var n: int = 0
	for e: Dictionary in _events(head, &"sound"):
		if e["name"] == sound:
			n += 1
	return n


## Puts the runner on the trucks in `lane` at track distance `d`, standing still in its lane.
func _place(player: Player, lane: int, d: float) -> void:
	player.distance = d
	player.lane = lane
	player.set(&"_x", player.geo.lane_x(lane))
	player.set(&"_switch_t", 1.0)
	player.set(&"_bumping", false)
	player.surface = Player.Surface.FLOOR
	player.h = 0.0
	player.vh = 0.0
	player.grounded = true
	player.in_pit = false


## Plays phase `phase` at `lanes` (the bot takes the face-off) until the pin begins, then hands over to
## `drive` (called every frame with the head; it steers the runner) until a stomp, a missed window or
## `seconds`: {world, head, stomped, missed, moves}.
func _play_pin(phase: int, lanes: int, drive: Callable, seconds: float = 60.0, p_def: BossDef = null) -> Dictionary:
	var pair: Array = _fight(p_def if p_def != null else _def(), lanes, phase)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	world.player.god_mode = true
	var bot := FloatingHeadBot.new(head, true)
	bot.routes = false
	var out := {"world": world, "head": head, "moves": {}}
	world.player.movement_event.connect(func(kind: StringName) -> void:
		out["moves"][kind] = int(out["moves"].get(kind, 0)) + 1)
	var s := {"pinned": false}
	await _until(world, func() -> bool:
		if head.step == FloatingHead.Step.PIN_FALL or head.step == FloatingHead.Step.PINNED:
			s["pinned"] = true
		if s["pinned"]:
			drive.call(head)
		else:
			bot.step()
		return not _events(head, &"weak_point").is_empty() or not _events(head, &"window_missed").is_empty(), seconds)
	out["stomped"] = not _events(head, &"weak_point").is_empty()
	out["missed"] = not _events(head, &"window_missed").is_empty()
	return out


## One lane a frame toward `lane`.
func _steer(player: Player, lane: int) -> void:
	if player.lane != lane and player.surface == Player.Surface.FLOOR:
		player.press(&"move_right" if lane > player.lane else &"move_left")


# --- Data ----------------------------------------------------------------------------------

func _test_data() -> void:
	var t := def.tuning as FloatingHeadTuning
	var half: float = (tuning.lane_width - 0.2) * 0.5
	var limit: float = FloatingHeadRamp.side_step_limit(tuning, tuning.lane_width, half,
		tuning.lane_width - tuning.foot_half_width - half - FloatingHeadRamp.BEVEL_CLEAR)
	check(t.ramp_board_share >= 0.6 and t.ramp_board_share <= 0.85 and t.ramp_board_height > 0.5,
		"most of the ramp is a lead-in a lane switch boards (%.0f%%, %.2f m high at its end)" % [t.ramp_board_share * 100.0,
		t.ramp_board_height])
	check(limit > 0.9 and t.ramp_board_height <= limit,
		"its lead-in is no higher than a lane switch steps up its bevelled sides (%.2f m of %.2f m)" % [t.ramp_board_height, limit])
	check(t.wall_entry_before > t.window_release_gap + 1.0 and t.wall_jump_before < t.window_release_gap,
		"the wall marks start before the window's release line (%.0f m: get onto the wall there) and the jump mark is after it" % t.window_release_gap)
	check(t.stomp_covers_outer_lanes, "the outermost stomp boxes cover the outer lanes where a wall jump lands")
	check(def.armor_when_unprotected, "a runner who brings no armor or shield gets armor pickups early (the city boss)")
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	check(sfx.names().has("wall_marks_light") and sfx.stream(&"wall_marks_light") != null
		and float(sfx.pitch_variation.get("wall_marks_light", 0.0)) == 0.0,
		"the wall marks' sound exists and sounds the same every time")


# --- The ramp ---------------------------------------------------------------------------------

## Every lane switch alongside the ramp either boards it or bumps off its side, never into it: from the
## lane on either side, started anywhere from before its foot to its end, on a low and a high ramp.
## Boarding reaches to within about a metre of its knee.
func _test_side_boarding() -> void:
	var t := def.tuning as FloatingHeadTuning
	for top: float in [1.9, 2.8]:
		var world: RunWorld = sim.build_world(RunSim.layout(3, 400.0))
		world.player.god_mode = true
		var ramp := FloatingHeadRamp.new()
		world.add_child(ramp)
		ramp.setup(world, 1, 100.0, 100.0 + t.ramp_length, top, t.ramp_overhang, 0.05, Color(0.3, 1.0, 0.35),
			t.ramp_board_share, t.ramp_board_height)
		await physics_frames(6)
		var tag: String = "(a ramp %.1f m up at the face)" % top
		check(ramp.landed, "the ramp is down %s" % tag)
		var s := {"inside": 0, "odd": [], "latest": -INF}
		for side: int in [-1, 1]:
			var from: int = 1 + side
			var d: float = ramp.foot - 1.0
			while d <= ramp.end:
				_place(world.player, from, d - 1.5)
				world.player.running = true
				var events: Array[StringName] = []
				var watch := func(kind: StringName) -> void: events.append(kind)
				world.player.movement_event.connect(watch)
				# Up to the switch, then 0.2 s (the switch takes lane_switch_time): where did it end up?
				var p: Player = world.player
				var after: int = -1
				for i: int in 90:
					if after < 0 and p.distance >= d:
						p.press(&"move_right" if side < 0 else &"move_left")
						after = 0
					await tree.physics_frame
					# Inside it: in its lane, over it, well under its top.
					if absf(p.position.x - world.geo.lane_x(1)) < 0.6 and p.distance > ramp.foot + 0.5 and p.distance < ramp.end \
							and p.h < ramp.top_at(p.distance) - 0.2:
						s["inside"] += 1
					if after >= 0:
						after += 1
						if after >= 12:
							break
				world.player.movement_event.disconnect(watch)
				if p.distance < ramp.end - 0.5:
					# On a slope the runner stands on its highest foot corner.
					var reach: float = tuning.foot_half_depth + 0.05
					var boarded: bool = p.lane == 1 and p.h > ramp.top_at(p.distance - reach) - 0.05 \
						and p.h < ramp.top_at(p.distance + reach) + 0.05
					# (A bump just short of the knee may lift a foot onto the bevel for a moment.)
					var bumped: bool = p.lane == from and events.has(&"lane_blocked")
					if boarded and d >= ramp.foot:
						s["latest"] = maxf(float(s["latest"]), d)
					if not boarded and not bumped:
						(s["odd"] as Array).append("%.1f" % (d - ramp.foot))
				d += 0.5
		check(int(s["inside"]) == 0, "a lane switch never takes the runner into it %s" % tag)
		check((s["odd"] as Array).is_empty(), "every switch alongside it boards it or bumps (odd at %s m past its foot) %s" % [
			", ".join(s["odd"]), tag])
		check(float(s["latest"]) >= ramp.knee - 1.5,
			"a switch boards it up to %.1f m before its knee (%.1f m past its foot of %.1f) %s" % [ramp.knee - float(s["latest"]),
			float(s["latest"]) - ramp.foot, ramp.face - ramp.foot, tag])
		await sim.free_world(world)


## In the fight: a runner beside the ramp switches onto it late, halfway along its lead-in and 1.5 m
## before its knee, and stomps, at every lane count and from either side. (Past the knee the window
## closes for a runner still on the trucks: test_floating_head_stomps.gd's missed windows.)
func _test_late_boarding() -> void:
	for lanes: int in LANES:
		for side: int in [1, -1]:
			for at: StringName in [&"half", &"late"]:
				var s := {"from": -1, "switched": false}
				var drive := func(head: FloatingHead) -> void:
					var p: Player = head.world.player
					var lane: int = head.ramp_lane_for(head.pin_side)
					var to_middle: int = -1 if lane * 2 > lanes - 1 else 1
					var from: int = lane + side * to_middle
					if from < 0 or from >= lanes:
						return
					s["from"] = from
					if s["switched"]:
						return
					var ramp: FloatingHeadRamp = head.ramp
					var go: float = INF
					if ramp != null and is_instance_valid(ramp):
						go = lerpf(ramp.foot, ramp.knee, 0.5) if at == &"half" else ramp.knee - 1.5
					if p.distance >= go and p.lane == from:
						_steer(p, lane)
						s["switched"] = true
					else:
						_steer(p, from)
				var r: Dictionary = await _play_pin(0, lanes, drive)
				var head: FloatingHead = r["head"]
				var tag: String = "(%s, from the %s side, %d lanes)" % [at, "inner" if side > 0 else "outer", lanes]
				if int(s["from"]) < 0:
					await sim.free_world(r["world"])
					continue
				check(s["switched"] and r["stomped"] and int((r["moves"] as Dictionary).get(&"lane_blocked", 0)) == 0,
					"a runner who switches onto it %s steps up its side and stomps %s" % [
					"halfway along its lead-in" if at == &"half" else "1.5 m before its knee", tag])
				await sim.free_world(r["world"])


# --- The wall ---------------------------------------------------------------------------------

## The second window's marks: lit on both walls as the tower falls, with their sound, where the tuning
## says; nothing in a hazard colour; gone once the window closes; and only on the wall route.
func _test_wall_marks() -> void:
	var t := def.tuning as FloatingHeadTuning
	for lanes: int in LANES:
		var s := {"marks": null, "seen": false}
		var drive := func(head: FloatingHead) -> void:
			if head.wall_marks != null and is_instance_valid(head.wall_marks) and not s["seen"]:
				s["seen"] = true
				s["marks"] = head.wall_marks
				s["start"] = head.pin_stern - head.wall_marks.start
				s["jump"] = head.pin_stern - head.wall_marks.jump_at
				s["step"] = head.step
		# Stays on the trucks: a missed window.
		var r: Dictionary = await _play_pin(1, lanes, drive)
		var head: FloatingHead = r["head"]
		var tag: String = "(%d lanes)" % lanes
		check(s["seen"] and s["step"] == FloatingHead.Step.PIN_FALL, "the wall marks light up as the tower falls %s" % tag)
		if s["seen"]:
			check(absf(float(s["start"]) - t.wall_entry_before) < 0.01 and absf(float(s["jump"]) - t.wall_jump_before) < 0.01,
				"from %.0f m before its face to the jump mark %.0f m before it %s" % [float(s["start"]), float(s["jump"]), tag])
		check(_sounds(head, &"wall_marks_light") == 1 and not _events(head, &"wall_marks").is_empty(), "with their sound %s" % tag)
		check(r["missed"] and (head.wall_marks == null or not is_instance_valid(head.wall_marks)),
			"and they go once the window closes %s" % tag)
		await sim.free_world(r["world"])
	# Their look: the zone's ramp colour, on both walls.
	var mesh: ArrayMesh = FloatingHeadWallMarks.marks_mesh(4.0, 10.0, 20.0, Color(0.3, 1.0, 0.35))
	var hazard: PackedStringArray = []
	var xs := {"left": false, "right": false}
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			xs["left" if v.x < 0.0 else "right"] = true
		for c: Color in colors:
			if c.a > 0.0 and (c.r > c.g + 0.2 or (c.r > 0.6 and c.b > 0.5 and c.g < 0.4)):
				hazard.append("%s" % c)
	check(hazard.is_empty() and xs["left"] and xs["right"], "the marks glow in the ramp colour on both walls, never a hazard colour (%s)" % [
		", ".join(hazard.slice(0, 3))])
	# The other ways up show none.
	for phase: int in [0, 2]:
		var seen := {"marks": false}
		var r2: Dictionary = await _play_pin(phase, 5, func(head: FloatingHead) -> void:
			if head.wall_marks != null:
				seen["marks"] = true)
		check(not seen["marks"] and _sounds(r2["head"], &"wall_marks_light") == 0, "no wall marks on the %s route" % ROUTES[phase])
		await sim.free_world(r2["world"])


## A runner who follows the marks: to the outer lane, onto the wall anywhere along the marks before the
## release line, and one wall jump inward within a metre either side of the jump mark (no second move):
## a stomp, at every lane count and from either wall.
func _test_wall_forgiveness() -> void:
	var t := def.tuning as FloatingHeadTuning
	for lanes: int in LANES:
		for wall: int in [-1, 1]:
			for entry: float in [t.wall_entry_before - 0.5, t.window_release_gap + 0.8]:
				for jump: float in [t.wall_jump_before + 1.0, t.wall_jump_before - 1.0]:
					var s := {"stage": &"lane"}
					var drive := func(head: FloatingHead) -> void:
						var p: Player = head.world.player
						var outer: int = 0 if wall < 0 else lanes - 1
						var gap: float = head.pin_stern - p.distance
						match s["stage"]:
							&"lane":
								_steer(p, outer)
								if p.lane == outer and p.grounded and gap <= entry:
									p.press(&"move_left" if wall < 0 else &"move_right")
									s["stage"] = &"wall"
							&"wall":
								if p.surface == Player.Surface.WALL and gap <= jump:
									p.press(&"move_right" if wall < 0 else &"move_left")
									s["stage"] = &"jumped"
					var r: Dictionary = await _play_pin(1, lanes, drive)
					var head: FloatingHead = r["head"]
					var stomps: Array[Dictionary] = _events(head, &"stomp")
					var landed: String = "lane %d" % int(stomps[0]["from_lane"]) if not stomps.is_empty() else "no stomp"
					check(r["stomped"] and s["stage"] == &"jumped",
						"a wall jump off the %s wall, on at %.1f m and off at %.1f m before its face, stomps (%s) (%d lanes)" % [
						"left" if wall < 0 else "right", entry, jump, landed, lanes])
					await sim.free_world(r["world"])
	# The outer lanes' stomp boxes stay out of reach of a jump from the trucks.
	for lanes: int in [5, 6]:
		var r: Dictionary = await _play_pin(1, lanes, func(_h: FloatingHead) -> void: pass)
		var head: FloatingHead = r["head"]
		await _until(r["world"], func() -> bool: return head.window_open or head.step == FloatingHead.Step.PINNED, 5.0)
		var lowest: float = INF
		for i: int in head.body.weak_points.size():
			var reach: Vector2 = head.body.stomp_outer_reach(i)
			if reach == Vector2.ZERO:
				continue
			var box: Hazard = head.body.weak_points[i]
			lowest = minf(lowest, box.top_y() - (load("res://data/tuning/game_rules.tres") as GameRules).stomp_tolerance)
		check(lowest < INF and lowest > tuning.jump_height + 0.05,
			"a jump from the trucks (%.2f m) can't stomp the boxes over the outer lanes (they count from %.2f m) (%d lanes)" % [
			tuning.jump_height, lowest, lanes])
		await sim.free_world(r["world"])


# --- The ceiling -------------------------------------------------------------------------------

## The third window from a pad in any lane, riding straight ahead and dropping off the end: a stomp
## (at 5 and 6 lanes the outer lanes have no weak point of their own).
func _test_ceiling_any_lane() -> void:
	for lanes: int in [5, 6]:
		for lane: int in [0, lanes / 2, lanes - 1]:
			var drive := func(head: FloatingHead) -> void:
				var p: Player = head.world.player
				if p.surface == Player.Surface.FLOOR and p.distance < head.pad_at:
					_steer(p, lane)
			var r: Dictionary = await _play_pin(2, lanes, drive, 60.0)
			var head: FloatingHead = r["head"]
			var moves: Dictionary = r["moves"]
			check(r["stomped"] and int(moves.get(&"pad", 0)) >= 1 and int(moves.get(&"hull_end", 0)) >= 1,
				"a runner who takes the pad in lane %d and rides straight ahead drops onto a weak point (%d lanes)" % [lane, lanes])
			await sim.free_world(r["world"])


# --- Hints -------------------------------------------------------------------------------------

## The first time each way up comes, a hint says how to take it, and only that once (a runner who
## misses the window sees the next pin without it).
func _test_route_hints() -> void:
	var profile := Profile.new()
	for phase: int in 3:
		var pair: Array = _fight(_def(), 5, phase)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		world.player.god_mode = true
		var hints := HintDirector.new()
		world.add_child(hints)
		hints.setup(world, profile, false)
		var shown: Array[String] = []
		hints.hint_shown.connect(func(id: String, _text: String) -> void: shown.append(id))
		var bot := FloatingHeadBot.new(head, true)
		bot.wrong_route = true
		await _until(world, func() -> bool:
			bot.step()
			return _events(head, &"pin_start").size() >= 2, 120.0)
		var id: String = "city_boss_%s" % ROUTES[phase]
		check(_events(head, &"pin_start").size() >= 2 and shown.count(id) == 1,
			"the first %s window shows its hint, and the next doesn't (%s)" % [ROUTES[phase], shown])
		await sim.free_world(world)


# --- Armor -------------------------------------------------------------------------------------

## GDD §10's standard armor rule gave a runner who brings no armor and no shield nothing before the final
## phase (nothing could break). Now each phase that begins with them unprotected counts as a break: an
## armor pickup 10-15 s in, which appears. With armor or a shield it's the rule as before.
func _test_unprotected_armor() -> void:
	var shielded := Loadout.new()
	shielded.charges = {&"shield": 1}
	var armored := Loadout.new()
	armored.charges = {&"armor": 1}
	for case: int in 3:
		var loadout: Loadout = [null, armored, shielded][case]
		var pair: Array = _fight(_def(true), 5, 0, loadout)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		world.player.god_mode = true
		var bot := FloatingHeadBot.new(head, true)
		await _until(world, func() -> bool:
			bot.step()
			return head.fight_time() > head.def.armor_delay_max + 2.0, 40.0)
		var dues: Array[Dictionary] = _events(head, &"armor_pickup")
		var tag: String = ["with no armor or shield", "with armor", "with a shield"][case]
		if case == 0:
			var t0: float = float(dues[0]["t"]) if not dues.is_empty() else -1.0
			check(dues.size() == 1 and dues[0]["reason"] == &"unprotected" and int(dues[0]["phase"]) == 0
				and t0 >= head.def.armor_delay_min - 0.02 and t0 <= head.def.armor_delay_max + 0.02,
				"%s, an armor pickup is due %.1f s into the first phase" % [tag, t0])
			check(not _events(head, &"pickup_offered").is_empty() and world.pickups.made >= 1,
				"and appears on the track (%d)" % world.pickups.made)
		else:
			check(dues.is_empty(), "%s, none is due at the start (the rule as before: %d)" % [tag, dues.size()])
		await sim.free_world(world)


# --- End to end ---------------------------------------------------------------------------------

## Through the campaign's flow at 3, 5 and 6 lanes with a fresh profile (no armor or shield): a runner
## who takes each way up the forgiving way stomps in the first two phases, dies in the third, retries
## (the fight starts over: it has no checkpoint) and stomps in all three phases to the win.
func _test_end_to_end() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		App.profile = SampleProfiles.fresh()
		App.rules.lanes_pc = lanes
		App.play_step(App.campaign.step("city/boss"))
		await physics_frames(3)
		var tag: String = "(%d lanes)" % lanes
		var first: Dictionary = await _campaign_attempt(lanes, true)
		var two: Array[StringName] = [&"ramp", &"wall"]
		check(first["stomps"] == two and first["died"],
			"the first attempt: up the ramp boarded late, one wall jump at the mark, then a death in the last phase (%s) %s" % [
			first["stomps"], tag])
		check(int(first["armor"]) >= 2, "with no armor or shield, armor pickups came in the first phases (%d) %s" % [
			int(first["armor"]), tag])
		var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
		check(result != null and not result.completed, "the death ends the attempt %s" % tag)
		if result == null:
			continue
		App.continue_after_result(result)
		var shop := App.screen as ShopScreen
		check(shop != null and shop.play_label == "Retry", "with a retry %s" % tag)
		if shop == null:
			continue
		shop.on_close.call()
		await physics_frames(3)
		var again: LevelRun = App.run
		var head := again.encounter as FloatingHead if again != null else null
		check(head != null and again.context.attempt == 2 and head.phase_index == 0 and head.step == FloatingHead.Step.ENTER,
			"the retry starts the fight over, from its entrance %s" % tag)
		if head == null:
			continue
		var second: Dictionary = await _campaign_attempt(lanes, false)
		check(second["stomps"] == ROUTES and second["won"] and not second["died"],
			"the retry: all three ways up again, to the win (%s, %s) %s" % [second["stomps"], second["cause"], tag])
		App.show_title()
		await tree.process_frame
	App.rules.lanes_pc = lanes_pc
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


## One attempt of the running campaign fight with a runner who takes each way up the forgiving way
## (FloatingHeadBot: boards the ramp late from its side, the wall marks with one wall jump, the pad and
## no move on the ceiling) and reads the arena; with `die`, it dies once the last phase begins.
## {stomps (routes), died, won, cause, armor (pickups offered)}.
func _campaign_attempt(lanes: int, die: bool) -> Dictionary:
	var run: LevelRun = App.run
	var head := run.encounter as FloatingHead
	var world: RunWorld = run.world
	var bot := FloatingHeadBot.new(head, true)
	bot.ramp_board_at = 0.5
	bot.ceiling_moves = false
	var events: Array[Dictionary] = head.events
	var stomps: Array[StringName] = []
	var out := {"stomps": stomps, "died": false, "won": false, "cause": "", "armor": 0}
	world.player.died.connect(func(c: String) -> void: out["cause"] = c)
	for i: int in 300 * 60:
		if App.run != run or not is_instance_valid(head) or App.screen is ResultsScreen:
			break
		if head.is_defeated():
			out["won"] = true
		if not world.player.alive:
			break
		if die and head.phase_index == 2 and head.state == BossEncounter.State.FIGHT:
			world.player._die("test: the last phase")
			break
		bot.step()
		await tree.physics_frame
	for e: Dictionary in events:
		if e["event"] == &"stomp":
			stomps.append(e["route"])
		elif e["event"] == &"pickup_offered":
			out["armor"] += 1
	out["died"] = is_instance_valid(world) and not world.player.alive
	if out["died"]:
		# Down: the revive offer passes, then the results.
		await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
		await tree.process_frame
	else:
		# The win's results follow the run through the wreck.
		for i: int in int((LevelRun.BOSS_VICTORY_MAX + LevelRun.COMPLETE_PAUSE + 1.0) * 60.0):
			if App.screen is ResultsScreen:
				break
			await tree.physics_frame
	return out
