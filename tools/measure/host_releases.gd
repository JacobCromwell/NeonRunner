extends SceneTree
## Measures when the Cyborg's Bad Dreams are released in the campaign's host levels with each weapon tier (task
## H8: weapons hit hosts, owner, October 8, 2026, GDD §9.7) against where the generator planned their chases
## (host_rules.gd, from each host's spot), and holds every chase to the generator's guarantees
## (tools/measure/host_watch.gd: its pads, where it ran, what the generator kept off its stretch, one chase at a
## time) and GDD §9.7's exclusive rule (tools/measure/attack_watch.gd: no slash during an Octodog's charge or a
## drone's barrage). From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless --fixed-fps 60 -s res://tools/measure/host_releases.gd -- [options]
## Options:
##   --levels=dead_zone/1,golden/2   campaign steps (default: every level with the `host` feature)
##   --lanes=3,5,6                   lane counts (default 3,5,6)
##   --tiers=0,1,2,3,4               weapon tiers (default all; 0: no weapon, every host is stomped)
##   --seeds=N                       each level's own seed and N others, 9001 to 9000 + N (default 0)
##   --old-rule                      hosts immune to weapons again (the September 26 rule), for comparison
##   --out=build/measure/x.json      also write every run's chases there
## Every host level at 3, 5 and 6 lanes with the five loadouts (75 runs) takes about 10 minutes.
##
## The simulated runner: god mode and endless grapples, in the middle lane all the way (AttackWatch.keep_lane),
## with the weapon at the tier given (auto-fire picks its targets as in the game) and stomping every host still
## alive when it reaches it, so every host releases its Bad Dream: by the weapon when it got there first.
## Per run: the hosts the weapon killed and the rest; how far ahead of its spot each host died (`lead`, the
## runner's distance at the kill before the host's spot in the layout, in seconds at run speed); how far before
## its planned stretch each chase began (`early`); the longest run without a pad in a chase, from its start and
## from its first claws (seconds; the generator's guarantee is BadDreamTuning.pad_gap_seconds); what it met
## outside its planned stretch that the generator keeps off chases; fizzled and overlapping chases; the seconds
## a Bad Dream's slash and an Octodog's charge or a drone's barrage were open together (AttackWatch); and the
## Octodogs that never charged.

const AttackWatch = preload("res://tools/measure/attack_watch.gd")
const HostWatch = preload("res://tools/measure/host_watch.gd")
const HostRules = preload("res://scripts/enemies/host_rules.gd")

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _tiers: Array[int] = [0, 1, 2, 3, 4]
var _seeds: Array[int] = [-1]
var _out: String = ""
var _old_rule: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	if _levels.is_empty():
		for s: CampaignStep in campaign.steps():
			if s.is_level() and campaign.configure(s, 3).features.has("host"):
				_levels.append(s.id)
	var app: Node = root.get_node_or_null(^"App")
	if app != null:
		app.set(&"autosave", false)
		app.set(&"save_path", "user://measure_profile.json")
	var runs: Array[Dictionary] = []
	print("level          lanes  seed tier  hosts weapon/stomp  chases fizzled overlap  lead s (max)  early m (max)"
		+ "  pad gap s (max, from claws)  kept met  dream+dog/drone s  began during dog/drone  dogs idle")
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level():
			print("%s: not a campaign level" % id)
			continue
		for lanes: int in _lanes:
			for level_seed: int in _seeds:
				for tier: int in _tiers:
					if app != null:
						app.set(&"profile", Profile.new())
					var r: Dictionary = await _measure(campaign, step, lanes, level_seed, tier, tuning)
					runs.append(r)
					print(_line(r))
	print("")
	for tier: int in _tiers:
		_print_totals(runs, tier)
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
		elif arg.begins_with("--lanes="):
			_lanes.clear()
			for v: String in value.split(",", false):
				_lanes.append(int(v))
		elif arg.begins_with("--tiers="):
			_tiers.clear()
			for v: String in value.split(",", false):
				_tiers.append(int(v))
		elif arg.begins_with("--seeds="):
			_seeds = [-1]
			for k: int in range(1, maxi(int(value), 0) + 1):
				_seeds.append(9000 + k)
		elif arg.begins_with("--out="):
			_out = value
		elif arg == "--old-rule":
			_old_rule = true


## One simulated run of a campaign level with the weapon at `tier` (0: none). Returns its numbers.
func _measure(campaign: Campaign, step: CampaignStep, lanes: int, level_seed: int, tier: int,
		tuning: MovementTuning) -> Dictionary:
	var config: LevelConfig = campaign.configure(step, lanes)
	if level_seed >= 0:
		config.level_seed = level_seed
	config.skin = null
	var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
	var loadout := Loadout.new()
	if tier > 0:
		loadout.tiers[&"weapon"] = tier
	var world := RunWorld.new()
	root.add_child(world)
	world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, loadout)
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	if _old_rule:
		world.director.enemy_spawned.connect(func(e: Enemy) -> void:
			if e.is_host:
				e.immune_to_weapons = true)
	var attacks := AttackWatch.new(world, true)
	var hosts := HostWatch.new(world)
	await physics_frame
	world.start()
	while world.player.distance < layout.length:
		await physics_frame
		attacks.observe()
		hosts.observe()
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var r: Dictionary = hosts.check(gen)
	var a: Dictionary = attacks.summary()
	r["level"] = step.id
	r["lanes"] = lanes
	r["seed"] = config.level_seed
	r["tier"] = tier
	r["speed"] = gen.speed
	r["planned_hosts"] = HostRules.hosts_in(layout).size()
	var pairs: Dictionary = a["overlap_pairs"]
	r["dream_exclusive"] = float(pairs.get("bad_dream+octodog", 0.0)) + float(pairs.get("bad_dream+drone", 0.0)) \
		+ float(pairs.get("bad_dream+drone+octodog", 0.0))
	r["dogs"] = int(a["dogs"])
	r["dogs_no_charge"] = int(a["dogs_no_charge"])
	world.queue_free()
	await process_frame
	return r


func _line(r: Dictionary) -> String:
	var weapon: int = 0
	var lead_max: float = 0.0
	var early_max: float = 0.0
	var gap_max: float = 0.0
	var claws_gap_max: float = 0.0
	var kept: int = 0
	var during: int = 0
	for c: Dictionary in r["chases"]:
		if String(c["cause"]) == "weapon":
			weapon += 1
		lead_max = maxf(lead_max, (float(c["host_at"]) - float(c["kill_d"])) / float(r["speed"]))
		if not c.has("planned"):
			continue
		early_max = maxf(early_max, float(c["early"]))
		gap_max = maxf(gap_max, float(c["pad_gap"]))
		claws_gap_max = maxf(claws_gap_max, float(c["pad_gap_claws"]))
		kept += (c["kept"] as PackedStringArray).size()
		var others: PackedStringArray = c["others_on"]
		if others.has("octodog") or others.has("drone"):
			during += 1
	var killed: int = (r["chases"] as Array).size()
	return "%-14s %d     %5d %4d  %2d/%2d %6d/%-6d %6d %7d %7d  %12.2f  %13.1f  %16.1f, %5.1f  %8d  %17.2f  %22d  %4d/%d" % [
		r["level"], r["lanes"], r["seed"], r["tier"], killed, int(r["planned_hosts"]), weapon, killed - weapon,
		int(r["released"]), int(r["fizzled"]), int(r["overlapping"]), lead_max, early_max, gap_max, claws_gap_max,
		kept, float(r["dream_exclusive"]), during, int(r["dogs_no_charge"]), int(r["dogs"])]


func _print_totals(runs: Array[Dictionary], tier: int) -> void:
	var n: int = 0
	var hosts: int = 0
	var weapon: int = 0
	var released: int = 0
	var fizzled: int = 0
	var overlapping: int = 0
	var leads: Array[float] = []
	var early: Array[float] = []
	var gap_max: float = 0.0
	var gap_run: String = "-"
	var claws_gap_max: float = 0.0
	var exclusive: float = 0.0
	var during: int = 0
	var dogs: int = 0
	var dogs_idle: int = 0
	var kept: PackedStringArray = []
	for r: Dictionary in runs:
		if int(r["tier"]) != tier:
			continue
		n += 1
		released += int(r["released"])
		fizzled += int(r["fizzled"])
		overlapping += int(r["overlapping"])
		exclusive += float(r["dream_exclusive"])
		dogs += int(r["dogs"])
		dogs_idle += int(r["dogs_no_charge"])
		for c: Dictionary in r["chases"]:
			hosts += 1
			if String(c["cause"]) == "weapon":
				weapon += 1
				leads.append((float(c["host_at"]) - float(c["kill_d"])) / float(r["speed"]))
			if not c.has("planned"):
				continue
			early.append(float(c["early"]))
			if float(c["pad_gap"]) > gap_max:
				gap_max = float(c["pad_gap"])
				gap_run = "%s at %d lanes, host at %.0f" % [r["level"], r["lanes"], float(c["host_at"])]
			claws_gap_max = maxf(claws_gap_max, float(c["pad_gap_claws"]))
			var others: PackedStringArray = c["others_on"]
			if others.has("octodog") or others.has("drone"):
				during += 1
			for k: String in c["kept"]:
				kept.append("%s at %d lanes, host at %.0f (began at %.0f): %s" % [r["level"], r["lanes"],
					float(c["host_at"]), float(c["begin_d"]), k])
	if n == 0:
		return
	leads.sort()
	early.sort()
	print("Tier %d%s: %d runs, %d hosts killed (%d by the weapon), %d chases began, %d fizzled, %d overlapped the next"
		% [tier, " (no weapon: stomps)" if tier == 0 else "", n, hosts, weapon, released, fizzled, overlapping])
	if not leads.is_empty():
		print("  weapon kills before the host's spot: median %.2f s, max %.2f s of run" % [leads[leads.size() / 2], leads[-1]])
	if not early.is_empty():
		print("  chases begun before the planned stretch: median %.1f m, max %.1f m" % [early[early.size() / 2], early[-1]])
	print("  longest run without a pad in a chase: %.2f s (%s); from its first claws %.2f s (guarantee %.1f s)"
		% [gap_max, gap_run, claws_gap_max, HostRules.tuning().pad_gap_seconds])
	print("  a slash with an Octodog's charge or a drone's barrage open: %.2f s; chases begun during one: %d" % [exclusive, during])
	print("  Octodogs: %d, %d never charged" % [dogs, dogs_idle])
	print("  met outside the planned stretch what the generator keeps off chases: %d" % kept.size())
	for k: String in kept:
		print("    " + k)
