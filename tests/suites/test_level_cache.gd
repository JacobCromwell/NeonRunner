extends TestSuite
## Task PERF2 (the owner's approval, October 9, 2026): a retry of the same level plays a copy of the layout
## the last run built (LevelCache), exactly as a fresh build would play.
## - The key (LevelCache.key_for) stays the same for the same level configured again (with another look too)
##   and changes with its seed, lane count, difficulty, features, feature starts, pacing or run speed, the
##   campaign's recency curve, the movement tuning, a placement tuning or an enemy type's tuning (the live
##   tuning panel edits them in place), the patterns and the build flavor.
## - LevelLayout.copy() copies every list and field a layout has (a run plays a copy: a list it left out would
##   be missing from every run), each into a list of its own; a generated layout holds plain data only (no
##   Object, and no list or dictionary in two places, which a copy would split in two).
## - The generator's warnings come with a reused level, and a run's changes to its copy never reach the kept
##   build or the next copy.
## - Retries reuse the build both ways (LevelRun.restart, and the results screen's retry through the App), and a
##   seeded scripted attempt (lane switches, jumps, slides and dashes, and an EMP over the fences ahead) plays
##   exactly as with the cache off (every run building its level, as before): the same layout, the runner's
##   trace and events, kills and credits, the enemies' event log, the floor cuts begun, the score and the fences
##   switched off, at Gangland 3 (5 lanes) and Corporate 2 (3 lanes: a floor cut, a thief, an Enforcer Truck).
## - Nothing leaks into the next attempt: after an attempt that changed its world and layout every way play can
##   (and more), each retry starts from the build's layout, with every enemy still to come, every credit,
##   every fence on, no floor cut begun, the build's length and no score; the kept build is untouched.
## - Builds again where a build can differ: a new seed, lane count or difficulty (quick play's debug keys), an
##   edit in the live tuning panel (F6) to the movement tuning or an enemy type's tuning (a restart after it
##   reuses the new build), another level; endless mode builds on every run, a new level each time, and keeps
##   nothing.

const AttackWatch = preload("res://tools/measure/attack_watch.gd")
## The scripted attempts' review aids (App._apply_review_args), but for their lane count (_review_args): no deaths
## and no falls, so the runner meets everything in the time.
const REVIEW_ARGS: PackedStringArray = ["--god", "--nofall"]
## When a scripted attempt sets off its EMP (_play), over the fences 10-170 m ahead: Gangland 3's first ones at 5
## lanes (from 338 m with the Casino's levels and K4's curve, task K5) are in its reach then, and Corporate 2's.
const EMP_SECONDS: float = 9.0
## Corporate 2's scripted attempt plays at 3 lanes, where its floor cut begins 32 s in and its Enforcer Truck is
## wrecked in a wider gap before: at 5 lanes (with the Casino's levels and K4's curve, task K5) the attempt's weapons
## shoot its one Buzz Overdrive down before its charge, so no cut would begin.
const CORPORATE_2_LANES: int = 3
## How far an attempt is spoiled (_spoil) and its retry's track looked at (_test_nothing_leaks, Corporate 2 at 5
## lanes): past its floor cut (1301-1460 m with the Casino's levels and K4's curve), so it's among what the attempt
## ran and the retry builds.
const SPOIL_TO: float = 1600.0

var main: Node


func run() -> void:
	var was_on: bool = LevelCache.enabled
	LevelCache.enabled = true
	LevelCache.forget()
	_test_key()
	_test_copy_covers_every_field()
	_test_plain_data()
	_test_reuse_and_warnings()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved_profile: Profile = App.profile
	var saved_args: PackedStringArray = App._review_args
	App.profile = _full_profile()
	await _test_retries_play_the_same("gangland/3", 5, 24.0, ["credits", "fences_off"])
	await _test_retries_play_the_same("corporate/2", CORPORATE_2_LANES, 44.0, ["credits", "kills", "cuts"])
	App._review_args = _review_args(5)
	await _test_nothing_leaks("corporate/2")
	await _test_builds_again()
	await _test_endless()
	App._review_args = saved_args
	App.show_title()
	await tree.process_frame
	App.profile = saved_profile
	main.queue_free()
	App.main = null
	await tree.process_frame
	LevelCache.enabled = was_on
	LevelCache.forget()


# --- The key --------------------------------------------------------------------------------------

## The same level configured again has the same key; anything the build reads, changed, gives another.
func _test_key() -> void:
	var step: CampaignStep = App.campaign.step("corporate/1")
	var config: LevelConfig = App.campaign.configure(step, 5)
	var patterns: Array = LevelGenerator.load_for(config)
	var key: String = LevelCache.key_for(config, tuning, patterns)
	var again: LevelConfig = App.campaign.configure(step, 5)
	check(LevelCache.key_for(again, tuning, LevelGenerator.load_for(again)) == key,
		"the same level configured again has the same key")
	again.skin = load("res://data/skins/golden_skin.tres") as ZoneSkin
	check(LevelCache.key_for(again, tuning, patterns) == key, "with another look too (the generator never reads it)")
	var starts: Dictionary[String, float] = config.feature_starts.duplicate()
	starts["octodog"] = 0.9
	var changes: Array[Array] = [
		["seed", "level_seed", config.level_seed + 1],
		["lane count", "lane_count", 6],
		["difficulty", "difficulty", config.difficulty + 0.05],
		["set of features (--features)", "features", config.features + PackedStringArray(["screech"])],
		["feature start", "feature_starts", starts],
		["pacing (F6, Level pacing)", "fill_empty_seconds", config.fill_empty_seconds + 0.5],
		["run speed (--speed, a difficulty tier)", "run_speed", config.run_speed + 1.0],
	]
	for change: Array in changes:
		var changed: LevelConfig = App.campaign.configure(step, 5)
		changed.set(String(change[1]), change[2])
		check(LevelCache.key_for(changed, tuning, patterns) != key, "another %s gives another key" % change[0])
	# Resources the build reads, edited in place as the live tuning panel (F6) does, then put back.
	var edits: Array[Array] = [
		["the campaign's recency curve (F6: Feature picks)", config.feature_recency],
		["the movement tuning (F6: Movement)", tuning],
		["a placement tuning (F6: Wall fences)", WallFencePlacement.tuning()],
		["an enemy type's tuning (F6: Enemy: Octodog)", EnemyDirector.tuning_for("octodog")],
		["the danger density tuning", load("res://data/tuning/danger_density.tres")],
	]
	for edit: Array in edits:
		var res: Resource = edit[1]
		var prop: String = _tunable(res)
		var was: Variant = res.get(prop)
		res.set(prop, was + 1)
		check(prop != "" and LevelCache.key_for(config, tuning, patterns) != key, "an edit to %s (%s) gives another key" % [
			edit[0], prop])
		res.set(prop, was)
	var other_patterns: Array = patterns.duplicate(true)
	(other_patterns[0] as Dictionary)["id"] = "edited"
	check(LevelCache.key_for(config, tuning, other_patterns) != key, "so do edited patterns")
	var flavor: int = BuildFlavor._override
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO if BuildFlavor.current() != BuildFlavor.Kind.WEB_DEMO
		else BuildFlavor.Kind.FULL_PC)
	check(LevelCache.key_for(config, tuning, patterns) != key, "and another build flavor")
	BuildFlavor.set_override(flavor)
	check(LevelCache.key_for(config, tuning, patterns) == key, "with everything put back, the key is the first one again")


## The first number `res` shows in the live tuning panel (a ranged int or float, TuningPanel._editable_props),
## but the run speed (a campaign level runs at its own: LevelConfig.movement_for).
static func _tunable(res: Resource) -> String:
	for prop: Dictionary in res.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR and prop["name"] != "run_speed" \
				and prop["type"] in [TYPE_FLOAT, TYPE_INT] and prop["hint"] == PROPERTY_HINT_RANGE:
			return prop["name"]
	return ""


# --- Copies ---------------------------------------------------------------------------------------

## LevelLayout.copy() copies every field a layout has, lists added later included (every run plays a copy), each
## list into one of its own.
func _test_copy_covers_every_field() -> void:
	var source := LevelLayout.new()
	var fields: PackedStringArray = []
	for prop: Dictionary in source.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var field: String = prop["name"]
		fields.append(field)
		var value: Variant = source.get(field)
		if value is Array:
			var list: Array = value
			var typed: int = list.get_typed_builtin()
			list.append({"probe": field} if not list.is_typed() or typed == TYPE_DICTIONARY else type_convert(7, typed))
		elif value is Dictionary:
			(value as Dictionary)["probe"] = field
		elif value is int:
			source.set(field, 7)
		elif value is float:
			source.set(field, 123.25)
	var copy: LevelLayout = source.copy()
	var missing: PackedStringArray = []
	var shared: PackedStringArray = []
	for field: String in fields:
		var a: Variant = source.get(field)
		var b: Variant = copy.get(field)
		if _exact(a) != _exact(b):
			missing.append(field)
		elif (a is Array or a is Dictionary) and is_same(a, b):
			shared.append(field)
	check(fields.size() >= 15 and missing.is_empty(), "LevelLayout.copy() copies every field of a layout (%d; missing: %s)" % [
		fields.size(), ", ".join(missing)])
	check(shared.is_empty(), "each list into a list of its own (shared: %s)" % ", ".join(shared))


## A generated layout holds plain data only, so a copy of it plays exactly as it: no Object, and no list or
## dictionary in two places (a copy would make two of it, and a change to one would no longer show in the other).
func _test_plain_data() -> void:
	for spec: Array in [["gangland/3", 5], ["golden/1", 3]]:
		var config: LevelConfig = App.campaign.configure(App.campaign.step(spec[0]), spec[1])
		var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
		var found: Dictionary = {"dicts": 0, "objects": PackedStringArray(), "twice": PackedStringArray(), "lists": []}
		for prop: Dictionary in layout.get_property_list():
			if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_walk(layout.get(prop["name"]), prop["name"], found)
		var lists: Array = found["lists"]
		for i: int in lists.size():
			for j: int in range(i + 1, lists.size()):
				if is_same(lists[i][0], lists[j][0]):
					(found["twice"] as PackedStringArray).append("%s and %s" % [lists[i][1], lists[j][1]])
		check(int(found["dicts"]) > 200 and (found["objects"] as PackedStringArray).is_empty(),
			"%s at %d lanes holds no Object (%d entries; %s)" % [spec[0], spec[1], found["dicts"], found["objects"]])
		check((found["twice"] as PackedStringArray).is_empty(), "and no list or dictionary in two places (%s)" % found["twice"])


## Walks `value` (a throwaway layout's: it marks each dictionary it meets), noting Objects, dictionaries met
## twice, and every list for the pairwise check.
func _walk(value: Variant, path: String, found: Dictionary) -> void:
	if value is Dictionary:
		var dict: Dictionary = value
		if dict.has("__walked"):
			(found["twice"] as PackedStringArray).append("%s and %s" % [dict["__walked"], path])
			return
		found["dicts"] = int(found["dicts"]) + 1
		var keys: Array = dict.keys()
		dict["__walked"] = path
		for k: Variant in keys:
			_walk(dict[k], "%s.%s" % [path, k], found)
	elif value is Array:
		(found["lists"] as Array).append([value, path])
		var list: Array = value
		for i: int in list.size():
			_walk(list[i], "%s[%d]" % [path, i], found)
	elif value is Object:
		(found["objects"] as PackedStringArray).append("%s: %s" % [path, value])


## A level with drones but no ceilings warns that its drones get no pad schedule: its retry, a copy of the
## build, warns the same (LevelRun prints the warnings on every run). Each run gets a copy of its own: one run's
## changes to it reach neither the kept build nor the next run's copy.
func _test_reuse_and_warnings() -> void:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.config = (load(LEVEL_PATH) as LevelConfig).duplicate() as LevelConfig
	ctx.config.features = PackedStringArray(["drone", "pulsing"])
	ctx.tuning = tuning
	LevelCache.forget()
	var first: LevelLayout = LevelCache.layout_for(ctx)
	var warned: PackedStringArray = LevelCache.warnings.duplicate()
	var built: String = _layout_dump(first)
	check(not LevelCache.last_reused and not warned.is_empty() and warned[0].begins_with("drone:"),
		"a level with drones but no ceilings builds, and warns (%s)" % ", ".join(warned))
	check(not is_same(first, LevelCache._layout) and _layout_dump(LevelCache._layout) == built,
		"the run gets a copy of the build, the same layout")
	first.enemies.clear()
	first.length += 100.0
	if not first.fences.is_empty():
		first.fences[0]["disabled"] = true
	var again: LevelLayout = LevelCache.layout_for(ctx.retry())
	check(LevelCache.last_reused and LevelCache.warnings == warned, "its retry reuses the build, with the same warnings")
	check(not is_same(again, first) and _layout_dump(again) == built and _layout_dump(LevelCache._layout) == built,
		"and gets a copy of its own: the first run's changes to its copy reach neither the build nor this one")
	LevelCache.enabled = false
	LevelCache.layout_for(ctx.retry())
	check(not LevelCache.last_reused and LevelCache.warnings == warned, "with the cache off, every run builds (the same warnings)")
	LevelCache.enabled = true
	LevelCache.forget()


# --- Retries play the same ------------------------------------------------------------------------

## A seeded scripted attempt at campaign level `id` (`lanes` lanes, god mode, no falls, every item), played as the App
## plays it: with the cache off (every run builds its level, as before), then the first run with it (a copy of
## its build), its restart in place (LevelRun.restart) and the results screen's retry (App.retry). The three
## play exactly as the first, and both retries reuse the build. `needs`: what the attempt must have had for the
## comparison to mean something (_play's counts: credits, kills, cuts, fences_off).
func _test_retries_play_the_same(id: String, lanes: int, seconds: float, needs: PackedStringArray) -> void:
	App._review_args = _review_args(lanes)
	var step: CampaignStep = App.campaign.step(id)
	var runs: Array[Dictionary] = []
	var ways: PackedStringArray = ["a fresh build (the cache off)", "the first run with the cache (a copy of its build)",
		"its restart (LevelRun.restart)", "the results screen's retry (App.retry)"]
	LevelCache.enabled = false
	_restock()
	App.start_level(step)
	runs.append(await _play(seconds))
	LevelCache.enabled = true
	LevelCache.forget()
	_restock()
	App.start_level(step)
	var first_built: bool = not LevelCache.last_reused
	runs.append(await _play(seconds))
	App.run.restart()
	var restart_reused: bool = LevelCache.last_reused
	runs.append(await _play(seconds))
	_restock()
	App.retry(App.run.context)
	var retry_reused: bool = LevelCache.last_reused
	runs.append(await _play(seconds))
	check(first_built and restart_reused and retry_reused, "%s: the first run builds, and both retries reuse its build" % id)
	var base: Dictionary = runs[0]
	var lacking: PackedStringArray = []
	for need: String in needs:
		if int(base[need]) <= 0:
			lacking.append(need)
	check(lacking.is_empty(), "%s: the attempt has something to compare (%s, %d fences switched off, %d events; lacking: %s)" % [
		id, base["score"], base["fences_off"], (base["events"] as PackedStringArray).size(), ", ".join(lacking)])
	for i: int in range(1, runs.size()):
		var r: Dictionary = runs[i]
		var tag: String = "%s, %s" % [id, ways[i]]
		check(r["layout"] == base["layout"], "%s: the same layout as %s" % [tag, ways[0]])
		check(r["trace"] == base["trace"], "%s: the same runner's trace (%s)" % [tag, _first_diff(r["trace"], base["trace"])])
		check(r["events"] == base["events"], "%s: the same events, kills and credits (%s)" % [tag,
			_first_diff(r["events"], base["events"])])
		check(r["log"] == base["log"], "%s: the same enemies' event log" % tag)
		check(r["score"] == base["score"] and r["fences_off"] == base["fences_off"], "%s: the same score and EMPs (%s, %d off; %s, %d off)" % [
			tag, r["score"], r["fences_off"], base["score"], base["fences_off"]])


## Plays the App's run (built, its introduction up) from PLAY for `seconds` with a seeded script of moves (dashes
## too) and, at EMP_SECONDS, an EMP over the fences ahead (RunWorld.emp, as a destroyed fence generator sets
## off: it switches them off in the run's layout), and reports what happened: the layout it was built with
## (exactly), the runner's trace and events, kills and credits, the enemies' event log (AttackWatch), the floor
## cuts begun, the score and the fences switched off.
func _play(seconds: float) -> Dictionary:
	await tree.process_frame
	App.begin_run()
	var world: RunWorld = App.run.world
	var out: Dictionary = {"layout": _layout_dump(world.layout)}
	var watch := AttackWatch.new(world)
	var trace := PackedStringArray()
	var events := PackedStringArray()
	var cuts: Dictionary = {}
	world.player.movement_event.connect(func(kind: StringName) -> void:
		events.append("%.3f %s" % [world.level_time(), kind]))
	world.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		events.append("%.3f kill %s %s" % [world.level_time(), e.type_id, cause]))
	world.credits.collected.connect(func(value: int, _at: Vector3) -> void:
		events.append("%.3f credit %d" % [world.level_time(), value]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i: int in int(seconds * 60.0):
		if i % 40 == 0:
			world.player.press([&"move_left", &"move_right", &"jump", &"slide", &"dash"][rng.randi_range(0, 4)])
		if i == int(EMP_SECONDS * 60.0):
			var off_now: int = world.emp(world.lane_point(0, world.player.distance + 90.0, 1.0), 80.0)
			events.append("%.3f emp %d" % [world.level_time(), off_now])
		await tree.physics_frame
		watch.observe()
		if i % 30 == 0:
			trace.append("%.3f %.4f %d %d %.4f" % [world.level_time(), world.player.distance, world.player.lane,
				world.player.surface, world.player.h])
			for cut: FloorCut in world.track.floor_cuts():
				if cut.began():
					cuts[FloorCut.key_for(cut.lane, cut.end)] = true
	var s: ScoreKeeper = world.score
	var off: int = 0
	for f: Dictionary in world.layout.fences + world.layout.wall_fences:
		if f.get("disabled", false):
			off += 1
	out["trace"] = trace
	out["events"] = events
	out["log"] = watch.log_hash()
	out["score"] = "score %d, credits %d (%d picked up), kills %d, %d stolen, %d floor cuts begun" % [s.score, s.credits,
		s.credit_pickups, s.kills, s.credits_stolen, cuts.size()]
	out["kills"] = s.kills
	out["credits"] = s.credit_pickups
	out["cuts"] = cuts.size()
	out["fences_off"] = off
	return out


# --- Nothing leaks --------------------------------------------------------------------------------

## An attempt whose world and layout are changed every way play can (and some it can't: _spoil), then a retry
## each way: it starts from the build's layout with every enemy still to come and none in play, every credit,
## the build's length and no score, and as its track is built ahead, every fence on and no floor cut begun; the
## kept build is untouched.
func _test_nothing_leaks(id: String) -> void:
	_restock()
	App.start_level(App.campaign.step(id))
	var built: String = _layout_dump(App.run.world.layout)
	var length: float = App.run.world.layout.length
	var kept: String = _layout_dump(LevelCache._layout)
	await tree.process_frame
	App.begin_run()
	await physics_frames(5)
	for way: String in ["LevelRun.restart", "App.retry"]:
		var spoiled: Dictionary = _spoil(App.run.world)
		_restock()
		if way == "App.retry":
			App.retry(App.run.context)
		else:
			App.run.restart()
		check(LevelCache.last_reused, "%s after a spoiled attempt reuses the build" % way)
		var world: RunWorld = App.run.world
		check(_layout_dump(world.layout) == built and world.layout.length == length,
			"%s after an attempt that %s starts from the build's layout" % [way, spoiled["what"]])
		check(world.director.active.is_empty() and world.director._pending.size() == world.layout.enemies.size()
			and world.director._next == 0, "with every enemy still to come (%d) and none in play" % world.layout.enemies.size())
		check(world.credits.remaining() == world.layout.credits.size() and world.score.score == 0
			and world.score.credits == 0 and world.score.kills == 0, "every credit there (%d) and no score" % world.credits.remaining())
		var disabled: int = 0
		for f: Dictionary in world.layout.fences + world.layout.wall_fences:
			if f.get("disabled", false):
				disabled += 1
		# The track built ahead a chunk at a time (this attempt is thrown away after): every fence and floor cut of
		# the stretch the last attempt spoiled, as it's built.
		var seen: Dictionary = {"fences": 0, "off": 0, "cuts": 0, "begun": 0}
		var d: float = 0.0
		while d <= SPOIL_TO + 200.0:
			world.track.update(d, 0.0)
			for h: Hazard in world.track.fence_hazards() + world.track.wall_fence_hazards():
				seen["fences"] = int(seen["fences"]) + 1
				# Off for good (an EMP: Hazard.set_enabled), not a pulsing fence in its off time.
				if h.state == Hazard.State.OFF and h._pulse_on <= 0.0:
					seen["off"] = int(seen["off"]) + 1
			for cut: FloorCut in world.track.floor_cuts():
				seen["cuts"] = int(seen["cuts"]) + 1
				if cut.began() or cut.stopped:
					seen["begun"] = int(seen["begun"]) + 1
			d += TrackBuilder.CHUNK_LENGTH
		check(disabled == 0, "with no fence of its layout switched off")
		check(int(seen["off"]) == 0 and int(seen["fences"]) > 0, "and every fence on as the track is built (%d of %d looks off)" % [
			seen["off"], seen["fences"]])
		check(int(seen["begun"]) == 0 and int(seen["cuts"]) > 0, "and no floor cut begun (%d looks at its cuts)" % seen["cuts"])
	check(_layout_dump(LevelCache._layout) == kept, "the kept build is untouched by the attempts")


## Changes `world`'s run every way play can, and more: brings a stretch into play and kills every enemy in it,
## switches every fence off with one EMP, runs every floor cut built, collects credits, lengthens the track, and
## edits the layout's entries in place. Returns what it did ({what}).
func _spoil(world: RunWorld) -> Dictionary:
	world.track.update(SPOIL_TO, 30.0)
	world.director.update(SPOIL_TO)
	var kills: int = 0
	for e: Enemy in world.director.active.duplicate():
		if is_instance_valid(e) and e.alive:
			e.defeat(&"test")
			kills += 1
	var off: int = world.emp(Vector3(0.0, 1.0, TrackGeometry.world_z(350.0)), 100000.0)
	var cuts: int = 0
	for cut: FloorCut in world.track.floor_cuts():
		cut.advance_to(cut.start)
		cuts += 1
	var taken: int = 0
	for c: Dictionary in world.layout.credits:
		if String(c["surface"]) == "floor" and not world.credits.take_near(int(c["lane"]), float(c["at"]), 0.5).is_empty():
			taken += 1
	world.score.add_credit(25)
	var extra := LevelLayout.new()
	extra.lane_count = world.layout.lane_count
	extra.length = world.layout.length + 200.0
	extra.fences.append({"lane": 0, "at": world.layout.length + 100.0, "variant": "full", "pulsing": false})
	world.track.extend_layout(extra)
	for e: Dictionary in world.layout.enemies:
		if e.get("params") is Dictionary:
			(e["params"] as Dictionary)["spoiled"] = true
	if not world.layout.credits.is_empty():
		world.layout.credits[0]["value"] = 999
	return {"what": "killed %d enemies, switched %d fences off, ran %d floor cuts, took %d credits and lengthened its track" % [
		kills, off, cuts, taken]}


# --- Building again -------------------------------------------------------------------------------

## Where a build can differ, the run builds again: quick play's restarts reuse its build until a debug key gives
## it another seed, lane count or difficulty; an edit in the live tuning panel (F6) to the movement tuning or to
## an enemy type's tuning builds again, and the restart after reuses that build; another level builds again.
func _test_builds_again() -> void:
	LevelCache.forget()
	App.start_quick(PackedStringArray(["--seed=7", "--lanes=3", "--features=cyborg"]))
	await tree.process_frame
	var run: LevelRun = App.run
	check(not LevelCache.last_reused, "quick play builds its level")
	run.restart()
	check(LevelCache.last_reused, "a restart (quick play's after a death, the debug key) reuses it")
	for key: Array in [[&"debug_new_seed", "a new seed"], [&"debug_cycle_lanes", "another lane count"],
			[&"debug_cycle_difficulty", "another difficulty"]]:
		var event := InputEventAction.new()
		event.action = key[0]
		event.pressed = true
		run._unhandled_input(event)
		check(not LevelCache.last_reused, "%s (its debug key) builds again" % key[1])
		run.restart()
		check(LevelCache.last_reused, "and the restart after reuses that build (%s)" % key[1])
	var panel: TuningPanel = run.tuning_panel
	check(panel != null, "the live tuning panel is there (a debug build)")
	if panel == null:
		return
	panel.open()
	for res: Resource in [run.context.tuning, EnemyDirector.tuning_for("cyborg")]:
		var control: Dictionary = {}
		for c: Dictionary in panel._controls:
			if c["resource"] == res and c.has("slider"):
				control = c
				break
		check(not control.is_empty(), "F6 shows %s" % res.resource_path)
		if control.is_empty():
			continue
		var slider: HSlider = control["slider"]
		var was: Variant = res.get(control["prop"])
		# One step of the slider, as a player of the panel would.
		slider.value = slider.value + slider.step if slider.value + slider.step <= slider.max_value else slider.value - slider.step
		run.restart()
		check(not LevelCache.last_reused and res.get(control["prop"]) != was,
			"an F6 edit to %s (%s) builds again" % [res.resource_path, control["prop"]])
		run.restart()
		check(LevelCache.last_reused, "and the restart after reuses that build")
		res.set(control["prop"], was)
		run.restart()
		check(not LevelCache.last_reused, "putting it back builds again")
	panel.close()
	App.start_level(App.campaign.step("city/1"))
	check(not LevelCache.last_reused, "another level builds again")
	await tree.process_frame


## Endless mode builds on every run (each has a random seed): two runs, two levels, and its restart builds again
## too; it keeps nothing, so the kept build is still the last level's.
func _test_endless() -> void:
	App.start_level(App.campaign.step("city/1"))
	await tree.process_frame
	var kept: LevelLayout = LevelCache._layout
	var kept_key: String = LevelCache._key
	App.start_endless()
	await tree.process_frame
	check(not LevelCache.last_reused and App.run.context.mode == RunContext.Mode.ENDLESS, "endless mode builds its level")
	var first: String = _layout_dump(App.run.world.layout)
	var first_seed: int = App.run.context.config.level_seed
	App.start_endless()
	await tree.process_frame
	check(not LevelCache.last_reused and App.run.context.config.level_seed != first_seed
		and _layout_dump(App.run.world.layout) != first, "and a new level on its next run")
	App.run.restart()
	check(not LevelCache.last_reused, "a restart of the same seed builds again: endless mode never reuses")
	check(LevelCache._layout == kept and LevelCache._key == kept_key, "and it keeps nothing: the kept build is the last level's")
	App.show_title()
	await tree.process_frame


# --- Helpers --------------------------------------------------------------------------------------

## The review aids for a scripted attempt at `lanes` lanes (REVIEW_ARGS).
static func _review_args(lanes: int) -> PackedStringArray:
	var out := PackedStringArray(["--lanes=%d" % lanes])
	out.append_array(REVIEW_ARGS)
	return out


## A profile that owns every item at its top tier, one of each breakable in stock: every start, and the results
## screen's retry (which takes its loadout from the profile), brings everything.
func _full_profile() -> Profile:
	var p := Profile.new()
	for item: ShopItem in App.catalog.items:
		if item.kind == ShopItem.Kind.PERMANENT:
			p.set_tier(item.id, item.tier_count())
	_restock(p)
	return p


## One of each breakable item in stock again (a run that breaks one uses it up), for the next start's loadout.
func _restock(p: Profile = App.profile) -> void:
	for item: ShopItem in App.catalog.items:
		if item.kind == ShopItem.Kind.BREAKABLE:
			p.stocks[String(item.id)] = 1


## Every field of `layout` written out exactly (_exact), lists added after this test included.
static func _layout_dump(layout: LevelLayout) -> String:
	var parts: PackedStringArray = []
	for prop: Dictionary in layout.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			parts.append("%s=%s" % [prop["name"], _exact(layout.get(prop["name"]))])
	return "\n".join(parts)


## `value` written out exactly: every dictionary's keys in their order, every list's type and every value's
## (var_to_str tells 1 from 1.0 and &"a" from "a", but sorts a dictionary's keys).
static func _exact(value: Variant) -> String:
	if value is Dictionary:
		var parts: PackedStringArray = []
		for k: Variant in value:
			parts.append("%s: %s" % [var_to_str(k), _exact((value as Dictionary)[k])])
		return "{%s}" % ", ".join(parts)
	if value is Array:
		var list: Array = value
		var parts: PackedStringArray = []
		for item: Variant in list:
			parts.append(_exact(item))
		var kind: String = "Array[%d %s]" % [list.get_typed_builtin(), list.get_typed_class_name()] if list.is_typed() else "Array"
		return "%s(%s)" % [kind, ", ".join(parts)]
	return var_to_str(value)


## Where two lists of lines first differ ("same" if they don't).
static func _first_diff(a: PackedStringArray, b: PackedStringArray) -> String:
	for i: int in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return "line %d: %s, not %s" % [i, a[i], b[i]]
	if a.size() != b.size():
		return "%d lines, not %d" % [a.size(), b.size()]
	return "same"
