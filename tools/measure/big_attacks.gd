extends SceneTree
## Measures how the big attacks of different enemy types overlap (GDD §9, "Big attacks take
## turns") over simulated runs of the campaign's levels, with the rule on and off
## (GameRules.big_attacks_take_turns), and how much turn-taking delays attacks. From the project
## folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless --fixed-fps 60 -s res://tools/measure/big_attacks.gd -- [options]
## Options:
##   --levels=gangland/3,dead_zone/1   campaign steps (default: every level)
##   --features=octodog                only the levels whose features include all of these
##   --lanes=3,5,6                     lane counts (default 3,5,6)
##   --seeds=N                         each level's own seed and N others, 9001 to 9000 + N
##                                     (default 0: the campaign's own seeds)
##   --seeds=A-B                       seeds A to B instead (not the level's own)
##   --turns=on,off                    the switch (default both)
##   --seconds=N                       stop each run after N s of play (default: at the finish)
##   --no-hosts                        leave hosts alone (default: the runner stomps every host it
##                                     passes, and each releases a Bad Dream chase)
##   --skins                           the zones' own skins (default: the grey box, which is faster;
##                                     skins never change gameplay)
##   --out=build/measure/x.json        also write every run's numbers and event log there
## The whole campaign at 3, 5 and 6 lanes, both ways (90 runs), takes about 10 minutes.
##
## Each run's line ends with the enemies that never made a big attack (Octodogs without a charge,
## Resonators without a pulse, drones without a barrage, hover trucks without a lurch or a cannon
## shot); a drone brought down by a pad or a truck that leaves early may have had no chance.
##
## The simulated runner: god mode and endless grapples (quick play's --god --nofall), in the middle
## lane all the way (it takes the pads in that lane), stomping every host it passes. The enemies play
## as in the game. What counts as a big attack, and as an overlap: tools/measure/attack_watch.gd.
## Each run's event log is hashed, so two builds (or the switch off and a build without the rule)
## can be compared run by run.

const AttackWatch = preload("res://tools/measure/attack_watch.gd")

var _levels: PackedStringArray = []
var _features: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
## The seeds to run each level on (-1: the level's own).
var _seeds: Array[int] = [-1]
var _turns: Array[bool] = [true, false]
var _limit: float = INF
var _stomp_hosts: bool = true
var _skins: bool = false
var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	if _levels.is_empty():
		for s: CampaignStep in campaign.steps():
			if s.is_level():
				_levels.append(s.id)
	var app: Node = root.get_node_or_null(^"App")
	if app != null:
		app.set(&"autosave", false)
		app.set(&"save_path", "user://measure_profile.json")
	var runs: Array[Dictionary] = []
	print("level          lanes  seed turns   secs  attacks: drone lurch cannon  dog dream  reso  overlap s events"
		+ "  waited s (mean/max, n)  idle dog/reso/drone/truck  log")
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level():
			print("%s: not a campaign level" % id)
			continue
		var wanted: bool = true
		for f: String in _features:
			wanted = wanted and campaign.configure(step, _lanes[0]).features.has(f)
		if not wanted:
			continue
		for lanes: int in _lanes:
			for level_seed: int in _seeds:
				for turns: bool in _turns:
					if app != null:
						# The same profile for every run (the first Octodogs of a profile hide in a doghouse).
						app.set(&"profile", Profile.new())
					var r: Dictionary = await _measure(campaign, step, lanes, level_seed, turns, tuning)
					runs.append(r)
					print(_line(r))
	print("")
	for turns: bool in _turns:
		_print_totals(runs, turns)
	if _out != "":
		var path: String = _out if _out.begins_with("/") else ProjectSettings.globalize_path("res://" + _out)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(runs, "\t"))
		f.close()
		print("\nWrote %s" % path)
	quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			_levels = value.split(",", false)
		elif arg.begins_with("--features="):
			_features = value.split(",", false)
		elif arg.begins_with("--lanes="):
			_lanes.clear()
			for v: String in value.split(",", false):
				_lanes.append(int(v))
		elif arg.begins_with("--seeds="):
			_seeds.clear()
			if value.contains("-"):
				for s: int in range(int(value.get_slice("-", 0)), int(value.get_slice("-", 1)) + 1):
					_seeds.append(s)
			else:
				_seeds.append(-1)
				for k: int in range(1, maxi(int(value), 0) + 1):
					_seeds.append(9000 + k)
		elif arg.begins_with("--turns="):
			_turns.clear()
			for v: String in value.split(",", false):
				_turns.append(v == "on")
		elif arg.begins_with("--seconds="):
			_limit = float(value)
		elif arg == "--no-hosts":
			_stomp_hosts = false
		elif arg == "--skins":
			_skins = true
		elif arg.begins_with("--out="):
			_out = value


## One simulated run of a campaign level, on its own seed (`level_seed` -1) or another. Returns its
## numbers (AttackWatch.summary() and the run's).
func _measure(campaign: Campaign, step: CampaignStep, lanes: int, level_seed: int, turns: bool,
		tuning: MovementTuning) -> Dictionary:
	var config: LevelConfig = campaign.configure(step, lanes)
	if level_seed >= 0:
		config.level_seed = level_seed
	if not _skins:
		config.skin = null
	var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
	var rules: GameRules = (load("res://data/tuning/game_rules.tres") as GameRules).duplicate() as GameRules
	rules.set(&"big_attacks_take_turns", turns)
	var world := RunWorld.new()
	root.add_child(world)
	world.build(config, layout, tuning, rules, load("res://data/tuning/powerups.tres") as PowerupTuning)
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	var watch := AttackWatch.new(world, _stomp_hosts)
	await physics_frame
	world.start()
	while world.player.distance < layout.length and world.level_time() < _limit:
		await physics_frame
		watch.observe()
	var r: Dictionary = watch.summary()
	r["level"] = step.id
	r["lanes"] = lanes
	r["seed"] = config.level_seed
	r["turns"] = turns
	r["seconds"] = world.level_time()
	if _out != "":
		r["log"] = watch.log
	world.queue_free()
	await process_frame
	return r


func _line(r: Dictionary) -> String:
	var a: Dictionary = r["attacks"]
	var waits: Array = []
	for kind: String in r["held"]:
		waits.append_array(r["held"][kind])
	var total: float = 0.0
	var most: float = 0.0
	for w: float in waits:
		total += w
		most = maxf(most, w)
	var idle: String = "%d/%d/%d/%d" % [int(r["dogs_no_charge"]), int(r["resonators_no_pulse"]),
		int(r["drones_no_barrage"]), int(r["trucks_idle"])]
	return "%-14s %d     %5d %-5s %6.1f         %5d %5d %6d %4d %5d %5d  %9.2f %6d  %5.2f/%5.2f (%2d)        %-9s  %s" % [
		r["level"], r["lanes"], r["seed"], "on" if r["turns"] else "off", r["seconds"], int(a.get("drone", 0)),
		int(a.get("truck_lurch", 0)), int(a.get("truck_cannon", 0)), int(a.get("dog_charge", 0)),
		int(a.get("dream_slash", 0)), int(a.get("resonator_pulse", 0)), r["overlap"], r["events"],
		total / maxf(waits.size(), 1), most, waits.size(), idle, String(r["log_hash"]).substr(0, 8)]


func _print_totals(runs: Array[Dictionary], turns: bool) -> void:
	var n: int = 0
	var seconds: float = 0.0
	var overlap: float = 0.0
	var events: int = 0
	var worst: float = 0.0
	var worst_run: String = "-"
	var with_overlap: int = 0
	var attacks: Dictionary = {}
	var waits: Dictionary = {}
	var turn_waits: Dictionary = {}
	var pairs: Dictionary = {}
	var entrance: float = 0.0
	var dogs: int = 0
	var dogs_idle: int = 0
	var charges: int = 0
	var slashes_runs: int = 0
	var resonators: int = 0
	var resonators_idle: int = 0
	var drones: int = 0
	var drones_idle: int = 0
	var trucks: int = 0
	var trucks_no_lurch: int = 0
	var trucks_no_cannon: int = 0
	var trucks_idle: int = 0
	var starved: PackedStringArray = []
	for r: Dictionary in runs:
		if bool(r["turns"]) != turns:
			continue
		n += 1
		seconds += float(r["seconds"])
		overlap += float(r["overlap"])
		events += int(r["events"])
		entrance += float(r["entrance_overlap"])
		dogs += int(r["dogs"])
		dogs_idle += int(r["dogs_no_charge"])
		charges += int(r["dog_charges"])
		resonators += int(r.get("resonators", 0))
		resonators_idle += int(r.get("resonators_no_pulse", 0))
		drones += int(r["drones"])
		drones_idle += int(r["drones_no_barrage"])
		trucks += int(r["trucks"])
		trucks_no_lurch += int(r["trucks_no_lurch"])
		trucks_no_cannon += int(r["trucks_no_cannon"])
		trucks_idle += int(r["trucks_idle"])
		if int(r["dogs_no_charge"]) + int(r.get("resonators_no_pulse", 0)) > 0:
			starved.append("%s at %d lanes, seed %d (%d dogs, %d Resonators)" % [r["level"], r["lanes"], r["seed"],
				int(r["dogs_no_charge"]), int(r.get("resonators_no_pulse", 0))])
		if float(r["overlap"]) > 0.0:
			with_overlap += 1
		if float(r["overlap"]) > worst:
			worst = float(r["overlap"])
			worst_run = "%s at %d lanes" % [r["level"], r["lanes"]]
		for kind: String in r["attacks"]:
			attacks[kind] = int(attacks.get(kind, 0)) + int(r["attacks"][kind])
		for kind: String in r["held"]:
			(waits.get_or_add(kind, []) as Array).append_array(r["held"][kind])
		for kind: String in r["held_turn"]:
			(turn_waits.get_or_add(kind, []) as Array).append_array(r["held_turn"][kind])
		for pair: String in r["overlap_pairs"]:
			pairs[pair] = float(pairs.get(pair, 0.0)) + float(r["overlap_pairs"][pair])
		if int((r["attacks"] as Dictionary).get("dream_slash", 0)) > 0:
			slashes_runs += 1
	if n == 0:
		return
	print("Big attacks take turns %s: %d runs, %.0f s of play" % ["ON" if turns else "OFF", n, seconds])
	print("  overlap between types: %.2f s in all (%d times, in %d runs), %.2f s per run on average, worst %.2f s (%s)"
		% [overlap, events, with_overlap, overlap / n, worst, worst_run])
	var names: Array = pairs.keys()
	names.sort()
	for pair: String in names:
		print("    %s: %.2f s" % [pair, pairs[pair]])
	print("  a hover truck's entrance while a big attack is open: %.2f s" % entrance)
	var kinds: Array = attacks.keys()
	kinds.sort()
	for kind: String in kinds:
		var list: Array = waits.get(kind, [])
		var total: float = 0.0
		var most: float = 0.0
		for w: float in list:
			total += w
			most = maxf(most, w)
		var turn_total: float = 0.0
		for w: float in turn_waits.get(kind, []):
			turn_total += w
		print("  %-12s %4d attacks; %3d waited for their turn: mean %.2f s, max %.2f s (%.1f s in all, %.1f s of it held)"
			% [kind, int(attacks[kind]), list.size(), total / maxf(list.size(), 1), most, total, turn_total])
	print("  Octodogs: %d, %d charges in all, %d never charged; Bad Dream slashes in %d runs" % [dogs, charges,
		dogs_idle, slashes_runs])
	print("  Resonators: %d came to pace the runner, %d never pulsed" % [resonators, resonators_idle])
	print("  Drones: %d swooped in, %d never fired a barrage" % [drones, drones_idle])
	print("  Hover trucks: %d burst out, %d never lurched, %d never fired the cannon, %d did neither"
		% [trucks, trucks_no_lurch, trucks_no_cannon, trucks_idle])
	for s: String in starved:
		print("    never charged or pulsed: %s" % s)
