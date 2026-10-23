extends SceneTree
## Plays the Hunter's chases (task S2; GDD §9.17, scripts/enemies/hunter.gd) on the campaign's levels that have it
## (Specimen Vault) at 3, 5 and 6 lanes, on each level's own seed and others: how much of each chase it spends beside the
## runner, out of view, and with the runner in an edge lane (where it never slashes them: docs/questions/s2.md item 20);
## the flurries it warns of and cuts; why it made room (its yields) and, for a lane shut ahead, what stood there
## (Hunter.lane_blocker); and whether its bait landed on it. From the project folder (XDG_DATA_HOME set as for the
## tests):
##   godot --headless --fixed-fps 60 -s res://tools/measure/hunter_chases.gd -- [--lanes=3,5,6] [--seeds=N]
##       [--runner=bait|dodge] [--start=middle|N] [--levels=ice_lab/3]
## --seeds=N runs each level on its own seed and N others (9001, 9002, ...; default 2). The runner (the task's review's
## probe): god mode and endless grapples (quick play's --god --nofall), starting in the middle lane (--start), jumping
## the holes in its lane; it steps one lane away from the Hunter a reaction (0.35 s) into each warning; with
## --runner=bait (the default) it also plays each bait as test_hunter_baits' runner does (the walkway's lane once the
## pillar is 5 s of run ahead, a lane at a time, never during a flurry; the dash; out from under the walkway away from
## the Hunter a reaction after the pillar breaks). Each run ends once the level's last Hunter has left play.
## Per chase: its arrival, its length (to its giving up or its end), the shares of it beside the runner (ALONGSIDE),
## out of view and with the runner in an edge lane, the flurries warned and cut (and how many of the warnings came with
## the runner off the edge lanes), its yields by reason and what shut its lane, how long a flurry was due but held back
## and why (Hunter.slash_problem), its whines, and CRUSHED where its bait landed on it. The totals: flurries warned a
## chase, a 25 s of chase with the runner off the edge lanes, the shares, the baits landed and the held time by reason.

const HunterRules = preload("res://scripts/enemies/hunter_rules.gd")
const REACTION: float = 0.35
const SIGHT_SECONDS: float = 5.0
const MOVE_EVERY: float = 0.3

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: Array[int] = [-1, 9001, 9002]
var _bait: bool = true
## -1: the middle lane.
var _start: int = -1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	if _levels.is_empty():
		for s: CampaignStep in campaign.steps():
			if s.is_level() and s.level.has_feature(HunterRules.TYPE):
				_levels.append(s.id)
	var app: Node = root.get_node_or_null(^"App")
	if app != null:
		app.set(&"autosave", false)
		app.set(&"save_path", "user://measure_profile.json")
	var chases: Array[Dictionary] = []
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		for lanes: int in _lanes:
			for level_seed: int in _seeds:
				var config: LevelConfig = campaign.configure(step, lanes)
				if level_seed >= 0:
					config.level_seed = level_seed
				config.skin = null
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
				if HunterRules.hunters_in(layout).is_empty():
					print("%s lanes=%d seed=%d: no Hunter" % [id, lanes, config.level_seed])
					continue
				if app != null:
					app.set(&"profile", Profile.new())
				var got: Array[Dictionary] = await _play(config, layout, tuning)
				for c: Dictionary in got:
					c["level"] = id
					c["lanes"] = lanes
					c["seed"] = config.level_seed
					print(_line(c))
				chases.append_array(got)
	_print_totals(chases)
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
			_seeds = [-1]
			for k: int in range(1, maxi(int(value), 0) + 1):
				_seeds.append(9000 + k)
		elif arg.begins_with("--runner="):
			_bait = value != "dodge"
		elif arg.begins_with("--start="):
			_start = -1 if value == "middle" else int(value)


## One run of `layout`: every Hunter's chase, in the order they arrive.
func _play(config: LevelConfig, layout: LevelLayout, tuning: MovementTuning) -> Array[Dictionary]:
	var world := RunWorld.new()
	root.add_child(world)
	world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning)
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var lanes: int = layout.lane_count
	world.player.setup(world.tuning, world.geo, lanes / 2 if _start < 0 else clampi(_start, 0, lanes - 1))
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	var speed: float = world.tuning.run_speed
	var jump: float = tuning.jump_distance(speed)
	var dashing: float = speed + pt.dash_speed_bonus
	var stats: Dictionary = {}
	var order: Array[int] = []
	var bot: Dictionary = {"dodged": {}, "broke": -1.0, "out": true, "dashed": {}, "next_move": 0.0}
	world.track.gantryway_fell.connect(func(_g: Gantryway) -> void:
		bot["broke"] = world.level_time()
		bot["out"] = false)
	var planned: Array[Dictionary] = HunterRules.hunters_in(layout)
	var last: float = float(planned.back()["at"]) + (HunterRules.tuning().chase_seconds + 6.0) * speed
	await physics_frame
	world.start()
	while world.player.distance < minf(layout.length - 5.0, last):
		var p: Player = world.player
		var h: Hunter = null
		for e: Variant in world.director.active:
			if is_instance_valid(e) and e is Hunter and (e as Hunter).alive and (e as Hunter).state != Hunter.State.WAITING:
				h = e as Hunter
		if h != null:
			_act(world, h, bot, pt, dashing)
			_observe(world, h, stats, order)
		_jump_holes(world, jump)
		await physics_frame
	var out: Array[Dictionary] = []
	for id: int in order:
		out.append(_chase(stats[id]))
	world.queue_free()
	await physics_frame
	return out


## The runner's moves (see the doc): a dodge a reaction into each warning; with the bait, the walkway's lane, the dash
## and the step out.
func _act(world: RunWorld, h: Hunter, bot: Dictionary, pt: PowerupTuning, dashing: float) -> void:
	var p: Player = world.player
	var away: StringName = &"move_left" if h.side > 0 else &"move_right"
	var id: int = h.get_instance_id()
	var dodged: Dictionary = bot["dodged"]
	if h.slash == Hunter.Slash.WARNING and int(dodged.get(id, 0)) != h.flurries and float(h.get(&"_slash_t")) >= REACTION:
		dodged[id] = h.flurries
		p.press(away)
		return
	if not _bait:
		return
	if not bool(bot["out"]):
		if world.level_time() - float(bot["broke"]) >= REACTION:
			bot["out"] = true
			p.press(away)
		return
	var b: Dictionary = h.call(&"_next_bait")
	if b.is_empty():
		return
	var pillar: float = float(b["at"])
	var lane: int = int(b["lane"])
	var in_sight: bool = p.distance >= pillar - SIGHT_SECONDS * world.tuning.run_speed and p.distance < pillar
	if in_sight and h.slash == Hunter.Slash.IDLE and p.lane != lane and world.level_time() >= float(bot["next_move"]):
		bot["next_move"] = world.level_time() + MOVE_EVERY
		p.press(&"move_right" if p.lane < lane else &"move_left")
	var dashed: Dictionary = bot["dashed"]
	if not dashed.has(pillar) and p.lane == lane and p.distance >= pillar - 0.5 * pt.dash_duration * dashing:
		dashed[pillar] = true
		# The dash power-up as the tests fire it (RunSim.act): the runner's dash, whatever its charge.
		p.start_dash(pt.dash_duration, pt.dash_speed_bonus)


## Counts a frame of Hunter `h`'s chase.
func _observe(world: RunWorld, h: Hunter, stats: Dictionary, order: Array[int]) -> void:
	var id: int = h.get_instance_id()
	if not stats.has(id):
		order.append(id)
		stats[id] = {"at": float(h.spawn.get("at", 0.0)), "frames": 0, "alongside": 0, "unseen": 0, "edge": 0,
			"warns_off_edge": 0, "history": h.history, "sounds": h.sounds_played, "seen": 0, "blockers": {},
			"last_flurries": 0, "held": {}}
	var s: Dictionary = stats[id]
	var p: Player = world.player
	var n: int = world.geo.lane_count
	var at_edge: bool = p.surface == Player.Surface.FLOOR and (p.lane == 0 or p.lane == n - 1)
	if h.flurries != int(s["last_flurries"]):
		s["last_flurries"] = h.flurries
		s["warns_off_edge"] = int(s["warns_off_edge"]) + (0 if at_edge else 1)
	# What shut its lane, for each new yield of "blocked" or steer round.
	var hist: Array = h.history
	for i: int in range(int(s["seen"]), hist.size()):
		var ev: String = String(hist[i][0])
		if ev == "yield:blocked" or ev == "steer":
			var what: String = h.lane_blocker(h.runner_lane() + h.side, false)
			var key: String = ev.trim_prefix("yield:") + ":" + (what if what != "" else "?")
			var blockers: Dictionary = s["blockers"]
			blockers[key] = int(blockers.get(key, 0)) + 1
	s["seen"] = hist.size()
	if h.state == Hunter.State.LEAVING:
		return
	# A flurry due but held back: why (Hunter.slash_problem).
	if h.state == Hunter.State.ALONGSIDE and h.slash == Hunter.Slash.IDLE and h.chase_time >= float(h.get(&"_next_slash")):
		var why: String = h.slash_problem()
		if why != "":
			var held: Dictionary = s["held"]
			held[why] = int(held.get(why, 0)) + 1
	s["frames"] = int(s["frames"]) + 1
	s["alongside"] = int(s["alongside"]) + (1 if h.state == Hunter.State.ALONGSIDE else 0)
	s["unseen"] = int(s["unseen"]) + (1 if h.gap > Hunter.VIEW_GAP else 0)
	s["edge"] = int(s["edge"]) + (1 if at_edge else 0)


## One chase's numbers from its counts.
func _chase(s: Dictionary) -> Dictionary:
	var names: Array = (s["history"] as Array).map(func(e: Array) -> String: return String(e[0]))
	var yields: Dictionary = {}
	for n: String in names:
		if n.begins_with("yield:"):
			var why: String = n.trim_prefix("yield:")
			yields[why] = int(yields.get(why, 0)) + 1
	var fps: float = float(Engine.physics_ticks_per_second)
	var frames: float = maxf(float(s["frames"]), 1.0)
	return {"at": s["at"], "seconds": frames / fps, "alongside": float(s["alongside"]) / frames,
		"unseen": float(s["unseen"]) / frames, "edge": float(s["edge"]) / frames,
		"off_edge_seconds": (frames - float(s["edge"])) / fps, "warned": names.count("warn"), "cut": names.count("cut"),
		"warned_off_edge": int(s["warns_off_edge"]), "yields": yields, "blockers": s["blockers"], "held": _seconds(s["held"]),
		"whines": (s["sounds"] as Array).filter(func(x: Array) -> bool: return x[0] == &"hunter_whine").size(),
		"crushed": names.has("defeat:gantryway")}


## Frame counts by key as seconds (one decimal), the largest first.
func _seconds(counts: Dictionary) -> Dictionary:
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(counts[a]) > int(counts[b]))
	var out: Dictionary = {}
	for k: Variant in keys:
		out[k] = snappedf(float(counts[k]) / float(Engine.physics_ticks_per_second), 0.1)
	return out


func _line(c: Dictionary) -> String:
	return ("%s %d lanes seed %d, Hunter at %.0f m: %.1f s, beside %.0f%%, unseen %.0f%%, runner at an edge %.0f%%; %d warned"
		+ " (%d off the edges) %d cut; yields %s; shut by %s; held (s) %s; whines %d%s") % [c["level"], c["lanes"], c["seed"],
		c["at"], c["seconds"], 100.0 * float(c["alongside"]), 100.0 * float(c["unseen"]), 100.0 * float(c["edge"]),
		c["warned"], c["warned_off_edge"], c["cut"], c["yields"], c["blockers"], c["held"], c["whines"],
		", CRUSHED" if bool(c["crushed"]) else ""]


func _print_totals(chases: Array[Dictionary]) -> void:
	if chases.is_empty():
		print("no chases")
		return
	var warned: float = 0.0
	var warned_off: float = 0.0
	var off_seconds: float = 0.0
	var seconds: float = 0.0
	var beside: float = 0.0
	var unseen: float = 0.0
	var crushed: int = 0
	var by_lanes: Dictionary = {}
	var held: Dictionary = {}
	for c: Dictionary in chases:
		for why: Variant in (c["held"] as Dictionary).keys():
			held[why] = snappedf(float(held.get(why, 0.0)) + float(c["held"][why]), 0.1)
		var s: float = float(c["seconds"])
		warned += float(c["warned"])
		warned_off += float(c["warned_off_edge"])
		off_seconds += float(c["off_edge_seconds"])
		seconds += s
		beside += float(c["alongside"]) * s
		unseen += float(c["unseen"]) * s
		crushed += 1 if bool(c["crushed"]) else 0
		var l: Array = by_lanes.get_or_add(int(c["lanes"]), [0, 0.0, 0.0, 0.0])
		l[0] += 1
		l[1] += float(c["warned"])
		l[2] += float(c["warned_off_edge"])
		l[3] += float(c["off_edge_seconds"])
	print("\n%d chases (%s runner): %.1f flurries warned a chase, %.1f a 25 s of chase off the edge lanes; beside the runner %.0f%%, out of view %.0f%% of the time; %d baits landed"
		% [chases.size(), "bait" if _bait else "dodging", warned / chases.size(), 25.0 * warned_off / maxf(off_seconds, 0.01),
		100.0 * beside / maxf(seconds, 0.01), 100.0 * unseen / maxf(seconds, 0.01), crushed])
	for lanes: int in by_lanes.keys():
		var l: Array = by_lanes[lanes]
		print("  %d lanes: %d chases, %.1f warned a chase, %.1f a 25 s off the edge lanes" % [lanes, l[0],
			float(l[1]) / float(l[0]), 25.0 * float(l[2]) / maxf(float(l[3]), 0.01)])
	print("  a flurry due but held (seconds, all chases): %s" % [held])


func _jump_holes(world: RunWorld, jump: float) -> void:
	var p: Player = world.player
	if not p.alive or not p.running or p.surface != Player.Surface.FLOOR or not p.grounded or p.in_pit:
		return
	var d: float = p.distance
	for g: Dictionary in world.layout.gaps:
		if int(g["lane"]) == p.lane and float(g["start"]) > d and float(g["start"]) - d <= jump * 0.14:
			p.press(&"jump")
			return
