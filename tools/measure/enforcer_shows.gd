extends SceneTree
## Counts the Enforcer Truck's showings (GDD §9.13 "Showing itself", the owner, October 8, 2026; tasks C6b and
## C6c) chase by chase, over simulated runs of the campaign's levels with the truck, with a runner keeping to each
## lane in turn. From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless --fixed-fps 60 -s res://tools/measure/enforcer_shows.gd -- [options]
## Options:
##   --levels=corporate/2,golden/1   campaign steps (default: every level that lists the Enforcer Truck)
##   --lanes=3,5,6                   lane counts (default 3,5,6)
##   --runner=all|middle|N           the lanes the runner keeps to: each in turn (default), the middle one only
##                                   (AttackWatch's runner, the tests' and big_attacks.gd's), or lane N
##   --seeds=N                       each level's own seed and N others, 9001 to 9000 + N (default 0: its own)
##   --out=build/measure/x.json      also write every chase's numbers there
## The runner: god mode and endless grapples (quick play's --god --nofall), keeping to its lane (a zone doodad's
## push is undone once the doodad is behind it: AttackWatch.keep_lane) and jumping the holes in it as a player
## would (it falls into a floor cut's hole and grapples out). It baits nothing: a truck that isn't destroyed gives
## up after its chase. Each run stops once every truck the level plans has left play.
## Per chase it prints the truck's arrival, its showings (the ones that came alongside: `+` for one that began as
## it arrived), its planned showing window if it has one (EnforcerTruck.show_window, task C6c) and whether a
## showing began in it, and, for a chase without a showing, why it couldn't show itself (show_problem(), the share
## of the chase each reason held). The totals: chases, chases with a showing, with the arrival showing.

const AttackWatch = preload("res://tools/measure/attack_watch.gd")
const Rules = preload("res://scripts/enemies/enforcer_truck_rules.gd")

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
## "all", "middle" or a lane number.
var _runner: String = "all"
## The seeds to run each level on (-1: the level's own).
var _seeds: Array[int] = [-1]
var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	if _levels.is_empty():
		for s: CampaignStep in campaign.steps():
			if s.is_level() and s.level.has_feature(Rules.TYPE):
				_levels.append(s.id)
	var app: Node = root.get_node_or_null(^"App")
	if app != null:
		app.set(&"autosave", false)
		app.set(&"save_path", "user://measure_profile.json")
	var chases: Array[Dictionary] = []
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level():
			print("%s: not a campaign level" % id)
			continue
		for lanes: int in _lanes:
			for level_seed: int in _seeds:
				var config: LevelConfig = campaign.configure(step, lanes)
				if level_seed >= 0:
					config.level_seed = level_seed
				config.skin = null
				var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
				for r: int in _runner_lanes(lanes):
					if app != null:
						app.set(&"profile", Profile.new())
					var got: Array[Dictionary] = await _measure(step, config, layout, tuning, r)
					for c: Dictionary in got:
						print(_line(c))
					chases.append_array(got)
	_print_totals(chases)
	if _out != "":
		var path: String = _out if _out.begins_with("/") else ProjectSettings.globalize_path("res://" + _out)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(chases, "\t"))
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
		elif arg.begins_with("--runner="):
			_runner = value
		elif arg.begins_with("--seeds="):
			_seeds.clear()
			_seeds.append(-1)
			for k: int in range(1, maxi(int(value), 0) + 1):
				_seeds.append(9000 + k)
		elif arg.begins_with("--out="):
			_out = value


func _runner_lanes(lanes: int) -> Array[int]:
	var out: Array[int] = []
	match _runner:
		"all":
			for l: int in lanes:
				out.append(l)
		"middle":
			out.append(lanes / 2)
		_:
			out.append(clampi(int(_runner), 0, lanes - 1))
	return out


## One simulated run of `layout` (`config`'s level) with a runner keeping to lane `keep`: each truck's chase, in
## order.
func _measure(step: CampaignStep, config: LevelConfig, layout: LevelLayout, tuning: MovementTuning,
		keep: int) -> Array[Dictionary]:
	var planned: Array[Dictionary] = Rules.trucks_in(layout)
	var out: Array[Dictionary] = []
	if planned.is_empty():
		out.append({"level": String(step.id), "lanes": layout.lane_count, "seed": config.level_seed, "runner": keep,
			"truck": -1})
		return out
	var world := RunWorld.new()
	root.add_child(world)
	world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning)
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	var watch := AttackWatch.new(world)
	watch.keep_lane = keep
	var jump: float = tuning.jump_distance(world.tuning.run_speed)
	var trucks: Dictionary = {}
	var order: Array[int] = []
	var last_leave: float = float(planned.back()["at"]) + (Rules.tuning().chase_seconds + 12.0) * world.tuning.run_speed
	await physics_frame
	world.start()
	while world.player.distance < minf(layout.length, last_leave):
		_jump_holes(world, jump)
		await physics_frame
		watch.observe()
		for e: Variant in world.director.active:
			if not is_instance_valid(e) or not (e is EnforcerTruck):
				continue
			var truck := e as EnforcerTruck
			if truck.state == EnforcerTruck.State.WAITING:
				continue
			var id: int = truck.get_instance_id()
			if not trucks.has(id):
				order.append(id)
				trucks[id] = {"truck": truck, "at": float(truck.spawn.get("at", 0.0)), "reasons": {}, "frames": 0,
					"window": truck.show_window() if truck.has_method(&"show_window") else Vector2(INF, -INF),
					"due_at": truck.show_at() if truck.has_method(&"show_at") else INF,
					"slack": truck.tuning.show_window_slack_seconds * world.tuning.run_speed if truck.has_method(&"show_at") else 0.0}
			var rec: Dictionary = trucks[id]
			rec["history"] = truck.history.duplicate(true)
			if truck.alive and (truck.state == EnforcerTruck.State.CHASING or truck.state == EnforcerTruck.State.ARRIVING) \
					and truck.show_phase == EnforcerTruck.Show.NONE and truck.shows < truck.tuning.show_count:
				var why: String = truck.show_problem()
				var reasons: Dictionary = rec["reasons"]
				reasons[why] = int(reasons.get(why, 0)) + 1
				rec["frames"] = int(rec["frames"]) + 1
				# While its planned showing is due (task C6c): why not, and what attacks then.
				var due: float = truck.show_at() if truck.has_method(&"show_at") else INF
				var d: float = world.player.distance
				if truck.shows == 0 and due < INF and d >= due - 1.0 \
						and d <= due + (truck.tuning.show_window_slack_seconds + 0.25) * world.tuning.run_speed:
					var att: PackedStringArray = []
					for o: Variant in world.director.active:
						if is_instance_valid(o) and o != truck and (o as Enemy).alive and ((o as Enemy).is_major_attack_active()
								or world.director.shots_on_their_way((o as Enemy).type_id) or world.director.is_waiting(o as Enemy)):
							att.append(String((o as Enemy).type_id))
					var key: String = why + ((" (" + ",".join(att) + ")") if not att.is_empty() else "") \
						+ (" [lane %d, %s]" % [world.player.lane, Player.Surface.keys()[world.player.surface]])
					var dues: Dictionary = rec.get_or_add("due", {})
					dues[key] = int(dues.get(key, 0)) + 1
	for i: int in order.size():
		var rec: Dictionary = trucks[order[i]]
		out.append(_chase(step, config, layout, keep, i, rec))
	for i: int in range(order.size(), planned.size()):
		out.append({"level": String(step.id), "lanes": layout.lane_count, "seed": config.level_seed, "runner": keep,
			"truck": i, "at": float(planned[i]["at"]), "arrived": false, "shows": 0, "arrival_show": false,
			"in_window": false, "window": [], "reasons": {}, "frames": 0})
	world.queue_free()
	await process_frame
	return out


## Presses jump as a player would for a hole in the runner's lane coming up (its near edge within a seventh of a
## jump), on the floor.
func _jump_holes(world: RunWorld, jump: float) -> void:
	var p: Player = world.player
	if not p.alive or not p.running or p.surface != Player.Surface.FLOOR or not p.grounded or p.in_pit:
		return
	var d: float = p.distance
	for g: Dictionary in world.layout.gaps:
		if int(g["lane"]) == p.lane and float(g["start"]) > d and float(g["start"]) - d <= jump * 0.14:
			p.press(&"jump")
			return


## One truck's chase from its record: its showings ("alongside" events), whether the first began as it arrived,
## and whether one began in its planned window.
func _chase(step: CampaignStep, config: LevelConfig, layout: LevelLayout, keep: int, index: int,
		rec: Dictionary) -> Dictionary:
	var history: Array = rec.get("history", [])
	var arrive: float = NAN
	var shows: int = 0
	var starts: Array[float] = []
	var alongside_after: Array[float] = []
	var pending: float = NAN
	for h: Variant in history:
		var event: String = String((h as Array)[0])
		var d: float = float((h as Array)[1])
		match event:
			"arrive":
				arrive = d
			"show":
				pending = d
			"alongside":
				shows += 1
				starts.append(pending)
				alongside_after.append(d)
	var window: Vector2 = rec["window"]
	var due: float = float(rec.get("due_at", INF))
	var in_window: bool = false
	for s: float in starts:
		in_window = in_window or (due < INF and s >= due - 1.0 and s <= due + float(rec.get("slack", 0.0)) + 5.0)
	return {"level": String(step.id), "lanes": layout.lane_count, "seed": config.level_seed, "runner": keep,
		"truck": index, "at": rec["at"], "arrived": not is_nan(arrive), "shows": shows,
		"arrival_show": not starts.is_empty() and absf(starts[0] - arrive) < 0.5,
		"starts": starts, "in_window": in_window,
		"window": [window.x, window.y] if window.y >= window.x else [],
		"reasons": rec["reasons"], "frames": rec["frames"], "due": rec.get("due", {}), "history": history}


func _line(c: Dictionary) -> String:
	if int(c["truck"]) < 0:
		return "%-12s %d lanes seed %4d runner %d: no truck planned" % [c["level"], c["lanes"], c["seed"], c["runner"]]
	var starts: PackedStringArray = []
	for s: float in c.get("starts", []):
		starts.append("%.0f" % s)
	var w: Array = c["window"]
	var window: String = "window %.0f-%.0f%s" % [w[0], w[1], " used" if bool(c["in_window"]) else " UNUSED"] \
		if not w.is_empty() else "no window"
	var why: String = ""
	if int(c["shows"]) == 0:
		why = "  why not: " + _reasons(c)
	if not (c["window"] as Array).is_empty() and not bool(c["in_window"]) and not (c.get("due", {}) as Dictionary).is_empty():
		var due: Dictionary = c["due"]
		var keys: Array = due.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(due[a]) > int(due[b]))
		why += "  when due: " + ", ".join(keys.slice(0, 3).map(func(k: Variant) -> String: return "%s x%d" % [k, due[k]]))
	return "%-12s %d lanes seed %4d runner %d truck %d at %6.0f: %d showing%s%s [%s] %s%s" % [c["level"], c["lanes"],
		c["seed"], c["runner"], c["truck"], c["at"], c["shows"], "" if int(c["shows"]) == 1 else "s",
		" (+arrival)" if bool(c["arrival_show"]) else "", ", ".join(starts), window, why]


## The reasons it couldn't show itself, most held first, as shares of the frames it could have.
static func _reasons(c: Dictionary) -> String:
	var reasons: Dictionary = c["reasons"]
	var frames: int = maxi(int(c["frames"]), 1)
	var keys: Array = reasons.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(reasons[a]) > int(reasons[b]))
	var out: PackedStringArray = []
	for k: Variant in keys.slice(0, 4):
		out.append("%s %d%%" % [String(k), roundi(100.0 * int(reasons[k]) / frames)])
	return ", ".join(out)


func _print_totals(chases: Array[Dictionary]) -> void:
	var by: Dictionary = {}
	for c: Dictionary in chases:
		if int(c["truck"]) < 0:
			continue
		var key: String = "%d lanes" % int(c["lanes"])
		for k: String in [key, "all"]:
			var t: Dictionary = by.get_or_add(k, {"chases": 0, "shown": 0, "arrival": 0, "windows": 0, "in_window": 0,
				"showings": 0})
			t["chases"] = int(t["chases"]) + 1
			t["showings"] = int(t["showings"]) + int(c["shows"])
			if int(c["shows"]) > 0:
				t["shown"] = int(t["shown"]) + 1
			if bool(c["arrival_show"]):
				t["arrival"] = int(t["arrival"]) + 1
			if not (c["window"] as Array).is_empty():
				t["windows"] = int(t["windows"]) + 1
				if bool(c["in_window"]):
					t["in_window"] = int(t["in_window"]) + 1
	print("")
	for k: String in by:
		var t: Dictionary = by[k]
		print("%-8s %3d chases (runner-lane runs): %3d with a showing (%d%%), %3d with the arrival showing, %d showings; %d planned windows, %d used"
			% [k, t["chases"], t["shown"], roundi(100.0 * int(t["shown"]) / maxi(int(t["chases"]), 1)), t["arrival"],
			t["showings"], t["windows"], t["in_window"]])
