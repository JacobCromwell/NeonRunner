extends TestSuite
## The Hunter's gantryway bait (task S2; GDD §9.17) in whole chases at the leads Specimen Vault gives it (task S2's
## review), on real physics at the Ice Lab's speed, every take watched each frame (test_hunter's rules):
## - the leads: every Hunter of Specimen Vault's builds at 3, 5 and 6 lanes, the campaign's seed and four more, from its
##   arrival to its bait's pillar (re-read from the builds on every run, so they follow the rules). Each one is played on a
##   plain track with its walkway's lane, its push both ways round, and the runner starting in every lane, its flurries on.
##   The runner (BaitRunner below, the review's probe): steps one lane away from the Hunter a reaction into each warning;
##   heads for the walkway's lane once the pillar is in sight (5 s of run), a lane at a time, never during a flurry; dashes
##   the pillar; steps out away from the Hunter a reaction after it breaks. The walkway lands on the Hunter in at least
##   RATE of the takes at each lane count (every take, measured), and the runner lives through every one;
## - the step-out window: a runner who steps out from under the falling walkway any time after the pillar breaks and
##   lives has the walkway land on the Hunter (it follows them into the walkway's lane at once, walkway_switch_seconds),
##   at 3, 5 and 6 lanes, both ways round; the window's end (the first step-out the walkway catches) is printed.

const HunterRules := preload("res://scripts/enemies/hunter_rules.gd")
const GantrywayRules := preload("res://scripts/enemies/gantryway_rules.gd")
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const LANE_COUNTS: Array[int] = [3, 5, 6]
## Seeds beyond the campaign's own whose builds give more leads (the review's: 9001-9004).
const MORE_SEEDS: Array[int] = [9001, 9002, 9003, 9004]
## Where the plain tracks' Hunter arrives (metres): past the level's calm start.
const ARRIVE: float = 70.0
## The reaction the suites give a runner to see something and start to act.
const REACTION: float = 0.35
## The runner heads for the walkway's lane once its pillar is this many seconds of run ahead (in sight).
const SIGHT_SECONDS: float = 5.0
## And moves a lane at most this often on the way.
const MOVE_EVERY: float = 0.3
## The share of the takes at each lane count in which the walkway must land on the Hunter.
const RATE: float = 0.95
## Step-outs after the break for the window (seconds).
const STEP_OUTS: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 1.0]

var sim: RunSim
var t: HunterTuning
var mt: MovementTuning
var pt: PowerupTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = HunterRules.tuning()
	pt = load("res://data/tuning/powerups.tres") as PowerupTuning
	await _test_real_leads()
	await _test_step_out_window()


# --- Helpers -------------------------------------------------------------------------------------

## Every bait of Specimen Vault's Hunters at `lanes` lanes over the campaign's seed and MORE_SEEDS: [{seed, at (its
## arrival), lead (seconds of run to its pillar), lane, side (the push), hunter_seed}], and the level's run speed.
func _leads(lanes: int) -> Dictionary:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var out: Array = []
	var speed: float = 0.0
	var seeds: Array[int] = [-1]
	seeds.append_array(MORE_SEEDS)
	for s: int in seeds:
		var config: LevelConfig = campaign.configure(campaign.step("ice_lab/3"), lanes)
		if s >= 0:
			config.level_seed = s
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		speed = gen.speed
		for h: Dictionary in HunterRules.hunters_in(layout):
			for b: Dictionary in (h["params"] as Dictionary).get("baits", []):
				out.append({"seed": config.level_seed, "at": float(h["at"]), "lead": (float(b["at"]) - float(h["at"])) / gen.speed,
					"lane": int(b["lane"]), "side": int(b["side"]), "hunter_seed": int(h.get("seed", 7))})
	return {"baits": out, "speed": speed}


## A plain track `lanes` wide with a Hunter arriving at ARRIVE whose bait is a falling gantryway over `lane` pushing on
## `side`, its pillar `lead` seconds of run on.
func _bait_layout(lanes: int, lane: int, side: int, lead: float, hunter_seed: int = 7) -> LevelLayout:
	var pillar: float = ARRIVE + lead * mt.run_speed
	var layout := RunSim.layout(lanes, pillar + 300.0)
	layout.enemies.append({"type": "hunter", "at": ARRIVE, "lane": 0, "side": 0, "seed": hunter_seed,
		"params": {"baits": [{"at": pillar, "lane": lane, "side": side, "id": 0}]}})
	_gantryway(layout, lane, pillar, side)
	return layout


## A falling gantryway as its rules hang one (test_hunter's): over `lane`, its pillar's front at `pillar`, pushing on
## `side`, nothing planted under it.
func _gantryway(layout: LevelLayout, lane: int, pillar: float, side: int) -> Dictionary:
	var config := LevelConfig.new()
	config.lane_count = layout.lane_count
	var gen: LevelGenerator = LevelGenerator.for_layout(config, mt, layout)
	var gt: GantrywayTuning = GantrywayTuning.load_default()
	var walkway: float = GantrywayRules.walkway_length(gen, gt)
	var calm: float = GantrywayRules.calm_length(gen, gt)
	var start: float = pillar - GantrywayRules.NEAR_OVERHANG
	var g := {"id": layout.gantryways.size(), "lane": lane, "start": start, "end": start + walkway, "pillar": pillar,
		"side": side, "calm": [pillar, pillar + calm], "seed": 7, "intro": false, "both": false}
	layout.gantryways.append(g)
	var box: Vector3 = mt.doodad_size(Gantryway.PILLAR_SIZE)
	layout.doodads.append({"lane": lane, "start": pillar, "end": pillar + box.z, "size": Gantryway.PILLAR_SIZE, "side": side,
		"seed": 7, LevelLayout.GANTRY_PILLAR: int(g["id"])})
	return g


## A world on `layout` at the level's speed, the runner in `lane`, unprotected.
func _world(layout: LevelLayout, lane: int) -> RunWorld:
	var w: RunWorld = sim.build_world(layout, Loadout.new(), mt, LevelConfig.new())
	w.player.setup(w.tuning, w.geo, lane)
	w.player.armor_state.carried = false
	w.player.armor_state.hits = 0
	return w


func _hunter(w: RunWorld) -> Hunter:
	for e: Variant in w.director.active:
		if is_instance_valid(e) and e is Hunter:
			return e as Hunter
	return null


## Holds the Hunter's flurries off in `w` (its first never comes).
func _no_flurries(w: RunWorld) -> void:
	w.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e is Hunter:
			var h := e as Hunter
			h.tuning = h.tuning.duplicate() as HunterTuning
			h.tuning.first_slash_seconds = 999.0)


## Steps `w` up to `seconds` of physics, the runner running, `bot` called before each step, until `done` holds or the
## runner dies; every frame watched (test_hunter's rules: its body never meets the runner's, it never sinks, its cuts only
## in the lane it warned of a whole warning after). Returns {alive, cause, faults, history}.
func _run(w: RunWorld, seconds: float, bot: Callable, done: Callable) -> Dictionary:
	var p: Player = w.player
	if not p.running:
		await tree.physics_frame
		p.running = true
	var out := {"alive": true, "cause": "", "faults": PackedStringArray(), "history": []}
	var on_died := func(cause: String) -> void: out["cause"] = cause
	p.died.connect(on_died)
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if bot.is_valid():
			bot.call(w)
		await tree.physics_frame
		var h: Hunter = _hunter(w)
		if h != null:
			out["history"] = h.history
			_watch(w, h, out["faults"])
		if done.is_valid() and done.call(w):
			break
		if not p.alive:
			break
	p.died.disconnect(on_died)
	out["alive"] = p.alive
	return out


func _watch(w: RunWorld, h: Hunter, faults: PackedStringArray) -> void:
	if not h.visible or not h.alive or faults.size() >= 10:
		return
	var p: Player = w.player
	var at: String = "at %.1f m" % p.distance
	if p.surface == Player.Surface.FLOOR and p.alive:
		var dx: float = absf(h.global_position.x - p.position.x)
		var reach_x: float = (w.geo.lane_width * 0.9 + w.tuning.hurtbox_size.x) * 0.5 - 0.05
		var reach_z: float = (t.blocker_length + w.tuning.hurtbox_size.z) * 0.5
		if dx < reach_x and absf(h.gap) < reach_z:
			faults.append("its body met the runner's %s" % at)
	if h.global_position.y < -0.001:
		faults.append("it sank %s" % at)
	if h.is_cutting():
		if absf(h.slash_hitbox().global_position.x - w.geo.lane_x(h.slash_lane)) > 0.01:
			faults.append("its cuts left the lane it warned of %s" % at)
		var warned: float = -INF
		for e: Array in h.history:
			if String(e[0]) == "warn":
				warned = float(e[2])
		if w.level_time() - warned < t.warning_seconds - 0.02:
			faults.append("it cut %.2f s after its warning %s" % [w.level_time() - warned, at])


## The bait runner (the review's probe; see the suite's doc), its state in `state` (pillar, lane: the walkway's).
func _bait_runner(state: Dictionary) -> Callable:
	var dashing: float = mt.run_speed + pt.dash_speed_bonus
	return func(w: RunWorld) -> void:
		var p: Player = w.player
		var h: Hunter = _hunter(w)
		if h == null or not h.alive:
			return
		var pillar: float = float(state["pillar"])
		var lane: int = int(state["lane"])
		var away: StringName = &"move_left" if h.side > 0 else &"move_right"
		state["flurries"] = h.flurries
		# A reaction into each warning: one lane away from it.
		if h.slash == Hunter.Slash.WARNING and int(state["dodged"]) != h.flurries and float(h.get(&"_slash_t")) >= REACTION:
			state["dodged"] = h.flurries
			RunSim.act(p, away)
			return
		if float(state["broke"]) >= 0.0:
			# A reaction after the pillar breaks: out from under the walkway, away from it.
			if not bool(state["out"]) and w.level_time() - float(state["broke"]) >= REACTION:
				state["out"] = true
				RunSim.act(p, away)
			return
		var in_sight: bool = p.distance >= pillar - SIGHT_SECONDS * mt.run_speed and p.distance < pillar
		if in_sight and h.slash == Hunter.Slash.IDLE and p.lane != lane and w.level_time() >= float(state["next_move"]):
			state["next_move"] = w.level_time() + MOVE_EVERY
			RunSim.act(p, &"move_right" if p.lane < lane else &"move_left")
		if not bool(state["dashed"]) and p.lane == lane and p.distance >= pillar - 0.5 * pt.dash_duration * dashing:
			state["dashed"] = true
			RunSim.act(p, &"dash")


## One take: the bait at `lead` over `lane` pushing on `side` at `lanes` lanes, the runner starting in `start` (the bait
## runner, flurries on). Returns _run's result plus {crushed, flurries, dashed}.
func _bait_take(lanes: int, lane: int, side: int, lead: float, start: int, hunter_seed: int) -> Dictionary:
	var layout: LevelLayout = _bait_layout(lanes, lane, side, lead, hunter_seed)
	var pillar: float = float(layout.gantryways[0]["pillar"])
	var w: RunWorld = _world(layout, start)
	var crushed: Array = []
	w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		if e is Hunter:
			crushed.append(cause))
	var state: Dictionary = {"pillar": pillar, "lane": lane, "dodged": 0, "dashed": false, "out": false, "broke": -1.0,
		"flurries": 0, "next_move": 0.0}
	w.track.gantryway_fell.connect(func(_g: Gantryway) -> void: state["broke"] = w.level_time())
	var r: Dictionary = await _run(w, (pillar + 80.0) / mt.run_speed, _bait_runner(state), func(ww: RunWorld) -> bool:
		return not crushed.is_empty() and ww.player.distance > pillar + 40.0)
	r["crushed"] = crushed == [Gantryway.CRUSH_CAUSE]
	r["flurries"] = int(state["flurries"])
	r["dashed"] = bool(state["dashed"])
	await sim.free_world(w)
	return r


# --- The real leads ------------------------------------------------------------------------------

func _test_real_leads() -> void:
	var lines: PackedStringArray = []
	for lanes: int in LANE_COUNTS:
		var found: Dictionary = _leads(lanes)
		var baits: Array = found["baits"]
		mt = tuning.duplicate() as MovementTuning
		mt.run_speed = float(found["speed"])
		var takes: int = 0
		var crushed: int = 0
		var flurries: int = 0
		var misses: PackedStringArray = []
		var deaths: PackedStringArray = []
		var faults: PackedStringArray = []
		var leads: PackedStringArray = []
		for b: Dictionary in baits:
			var lane: int = int(b["lane"])
			leads.append("%.1f s (seed %d, lane %d, push %+d)" % [float(b["lead"]), int(b["seed"]), lane, int(b["side"])])
			for side: int in [-1, 1]:
				if lane - side < 0 or lane - side >= lanes or lane + side < 0 or lane + side >= lanes:
					continue
				for start: int in lanes:
					var r: Dictionary = await _bait_take(lanes, lane, side, float(b["lead"]), start, int(b["hunter_seed"]))
					var tag: String = "lead %.1f s, walkway lane %d pushing %+d, start lane %d" % [float(b["lead"]), lane, side, start]
					takes += 1
					crushed += 1 if bool(r["crushed"]) else 0
					flurries += int(r["flurries"])
					if not bool(r["crushed"]) and misses.size() < 12:
						var names: Array = (r["history"] as Array).map(func(e: Array) -> String: return "%s@%.0f" % [e[0], e[1]])
						misses.append("%s: %s, %d flurries, %s" % [tag, "dashed" if bool(r["dashed"]) else "never dashed", int(r["flurries"]), names])
					if not bool(r["alive"]) and deaths.size() < 12:
						deaths.append("%s: %s" % [tag, r["cause"]])
					for f: String in r["faults"]:
						if faults.size() < 12:
							faults.append("%s: %s" % [tag, f])
		var rate: float = float(crushed) / maxf(takes, 1)
		lines.append("%d lanes: %d of %d takes (%.0f%%), %d flurries dodged on the way; leads %s" % [lanes, crushed, takes,
			rate * 100.0, flurries, ", ".join(leads)])
		check(takes >= 6 and rate >= RATE,
			"at Specimen Vault's leads (%d lanes) the walkway lands on the Hunter in %d of %d takes (%.0f%%; every start lane, both ways round, its flurries on and dodged) %s"
			% [lanes, crushed, takes, rate * 100.0, misses])
		check(deaths.is_empty(), "the bait runner lives through every take, every flurry dodged (%d lanes) %s" % [lanes, deaths])
		check(faults.is_empty(), "its rules held in every take (%d lanes) %s" % [lanes, faults])
		check(flurries > 0, "its flurries came on the way to the baits (%d, %d lanes)" % [flurries, lanes])
	print("  the bait at Specimen Vault's leads:\n    " + "\n    ".join(lines))


# --- The step-out window ------------------------------------------------------------------------

## A runner in the walkway's lane, the Hunter beside them away from the push (its flurries off), dashes the pillar and
## steps out to the push side `delay` seconds after it breaks. Returns {alive, cause, crushed}.
func _step_out_take(lanes: int, lane: int, side: int, delay: float) -> Dictionary:
	var layout: LevelLayout = _bait_layout(lanes, lane, side, 9.0)
	var pillar: float = float(layout.gantryways[0]["pillar"])
	var w: RunWorld = _world(layout, lane)
	_no_flurries(w)
	var crushed: Array = []
	w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		if e is Hunter:
			crushed.append(cause))
	var times: Array = [-1.0, -1.0]
	w.track.gantryway_fell.connect(func(_g: Gantryway) -> void: times[0] = w.level_time())
	w.track.gantryway_landed.connect(func(_g: Gantryway) -> void: times[1] = w.level_time())
	var dashing: float = mt.run_speed + pt.dash_speed_bonus
	var acted: Array = [false, false]
	var bot := func(ww: RunWorld) -> void:
		if not acted[0] and ww.player.distance >= pillar - 0.5 * pt.dash_duration * dashing:
			acted[0] = true
			RunSim.act(ww.player, &"dash")
		if not acted[1] and times[0] >= 0.0 and ww.level_time() - float(times[0]) >= delay - 0.001:
			acted[1] = true
			RunSim.act(ww.player, &"move_left" if side < 0 else &"move_right")
	var r: Dictionary = await _run(w, (pillar + 60.0) / mt.run_speed, bot, func(ww: RunWorld) -> bool:
		return float(times[1]) >= 0.0 and ww.level_time() - float(times[1]) > 0.3)
	r["crushed"] = crushed == [Gantryway.CRUSH_CAUSE]
	r["broke"] = float(times[0]) >= 0.0
	await sim.free_world(w)
	return r


func _test_step_out_window() -> void:
	mt = tuning.duplicate() as MovementTuning
	mt.run_speed = 24.8
	var lines: PackedStringArray = []
	for lanes: int in LANE_COUNTS:
		var lane: int = lanes / 2
		for side: int in [-1, 1]:
			var tag: String = "(%d lanes, the walkway over lane %d pushing %s)" % [lanes, lane, "left" if side < 0 else "right"]
			var lived: Array[float] = []
			var missed: Array[float] = []
			var first_caught: float = INF
			var broke: bool = true
			for delay: float in STEP_OUTS:
				var r: Dictionary = await _step_out_take(lanes, lane, side, delay)
				broke = broke and bool(r["broke"])
				if bool(r["alive"]):
					lived.append(delay)
					if not bool(r["crushed"]):
						missed.append(delay)
				else:
					first_caught = minf(first_caught, delay)
			check(broke and missed.is_empty() and lived.has(0.8),
				"every step-out after the break that the runner lives through (%s s) has the walkway land on the Hunter (missed at %s) %s"
				% [lived, missed, tag])
			lines.append("%d lanes pushing %+d: the Hunter crushed for every step-out %.2f-%.2f s after the break; the walkway catches the runner from %s s"
				% [lanes, side, lived.min() if not lived.is_empty() else -1.0, lived.max() if not lived.is_empty() else -1.0,
				"%.2f" % first_caught if first_caught < INF else "never"])
	print("  the step-out window:\n    " + "\n    ".join(lines))
