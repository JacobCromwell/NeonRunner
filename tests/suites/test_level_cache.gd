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
##   switched off, at Gangland 3 and Corporate 2 (a floor cut, a thief, an Enforcer Truck) at 5 lanes.
## - Nothing leaks into the next attempt: after an attempt that changed its world and layout every way play can
##   (and more), each retry starts from the build's layout, with every enemy still to come, every credit,
##   every fence on, no floor cut begun, every zone doodad and dash wall standing, the build's length and no score;
##   the kept build is untouched.
## - Smashed doodads and dash walls stand again (tasks H5 and H7a, the H merge): an attempt at Dead Zone 1 (3 lanes)
##   that dashes through a doodad and a dash wall, then dies, marks them in its own layout only; both retries reuse the
##   build, start from its layout exactly and build both whole (the same node, place, layers, shapes and look, standing
##   in the physics world), and the restart, not dashing, plays exactly as an attempt on a fresh build (the cache off).
## - Builds again where a build can differ: a new seed, lane count or difficulty (quick play's debug keys), an
##   edit in the live tuning panel (F6) to the movement tuning or an enemy type's tuning (a restart after it
##   reuses the new build), another level; endless mode builds on every run, a new level each time, and keeps
##   nothing.

const AttackWatch = preload("res://tools/measure/attack_watch.gd")
## The scripted attempts' review aids (App._apply_review_args): 5 lanes, no deaths and no falls, so the runner
## meets everything in the time.
const REVIEW_ARGS: PackedStringArray = ["--lanes=5", "--god", "--nofall"]
## When a scripted attempt sets off its EMP (_play).
const EMP_SECONDS: float = 6.0
## How far before a doodad or a dash wall _drive starts the dash (test_doodads' retry dashes from as far).
const DASH_LEAD: float = 8.0
## The smashed-and-retried attempts' review aids (_test_smashed_stand_again): 3 lanes, no deaths and no falls.
const SMASH_ARGS: PackedStringArray = ["--lanes=3", "--god", "--nofall"]

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
	App._review_args = REVIEW_ARGS
	await _test_retries_play_the_same("gangland/3", 24.0, ["credits", "fences_off"])
	await _test_retries_play_the_same("corporate/2", 44.0, ["credits", "kills", "cuts"])
	await _test_nothing_leaks("corporate/2")
	await _test_smashed_stand_again("dead_zone/1")
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

## A seeded scripted attempt at campaign level `id` (5 lanes, god mode, no falls, every item), played as the App
## plays it: with the cache off (every run builds its level, as before), then the first run with it (a copy of
## its build), its restart in place (LevelRun.restart) and the results screen's retry (App.retry). The three
## play exactly as the first, and both retries reuse the build. `needs`: what the attempt must have had for the
## comparison to mean something (_play's counts: credits, kills, cuts, fences_off).
func _test_retries_play_the_same(id: String, seconds: float, needs: PackedStringArray) -> void:
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
		var marked: int = 0
		for e: Dictionary in world.layout.doodads + world.layout.dash_walls:
			if e.has("smashed") or e.has("broken_by"):
				marked += 1
		# The track built ahead a chunk at a time (this attempt is thrown away after): every fence and floor cut of
		# the stretch the last attempt spoiled, as it's built, and every zone doodad and dash wall of the level
		# (tasks H5 and H7a: the last attempt smashed or marked every one).
		var seen: Dictionary = {"fences": 0, "off": 0, "cuts": 0, "begun": 0}
		var breakables: Dictionary = {}
		var broken: PackedStringArray = []
		var d: float = 0.0
		while d <= maxf(900.0, world.layout.length):
			world.track.update(d, 0.0)
			if d <= 900.0:
				for h: Hazard in world.track.fence_hazards() + world.track.wall_fence_hazards():
					seen["fences"] = int(seen["fences"]) + 1
					# Off for good (an EMP: Hazard.set_enabled), not a pulsing fence in its off time.
					if h.state == Hazard.State.OFF and h._pulse_on <= 0.0:
						seen["off"] = int(seen["off"]) + 1
				for cut: FloorCut in world.track.floor_cuts():
					seen["cuts"] = int(seen["cuts"]) + 1
					if cut.began() or cut.stopped:
						seen["begun"] = int(seen["begun"]) + 1
			for b: DashBreakable in _breakables(world.track):
				if breakables.has(b.get_instance_id()):
					continue
				breakables[b.get_instance_id()] = true
				if not _stands(b):
					broken.append("%s at %.0f m" % [b.kind, float(b.entry.get("start", 0.0))])
			d += TrackBuilder.CHUNK_LENGTH
		check(disabled == 0, "with no fence of its layout switched off")
		check(int(seen["off"]) == 0 and int(seen["fences"]) > 0, "and every fence on as the track is built (%d of %d looks off)" % [
			seen["off"], seen["fences"]])
		check(int(seen["begun"]) == 0 and int(seen["cuts"]) > 0, "and no floor cut begun (%d looks at its cuts)" % seen["cuts"])
		check(marked == 0 and broken.is_empty() and breakables.size() == world.layout.doodads.size() + world.layout.dash_walls.size()
			and not world.layout.dash_walls.is_empty(),
			"and every zone doodad and dash wall of the level standing as the track is built (%d doodads, %d walls; %d marked; broken: %s)" % [
			world.layout.doodads.size(), world.layout.dash_walls.size(), marked, ", ".join(broken)])
	check(_layout_dump(LevelCache._layout) == kept, "the kept build is untouched by the attempts")


## Changes `world`'s run every way play can, and more: brings a stretch into play and kills every enemy in it,
## switches every fence off with one EMP, runs every floor cut built, smashes every zone doodad and dash wall built
## (as the dash does, tasks H5 and H7a) and marks every other one's entry, collects credits, lengthens the track, and
## edits the layout's entries in place. Returns what it did ({what}).
func _spoil(world: RunWorld) -> Dictionary:
	world.track.update(700.0, 30.0)
	world.director.update(700.0)
	var smashed: int = 0
	for b: DashBreakable in _breakables(world.track):
		if b.smash(&"dash"):
			smashed += 1
	for e: Dictionary in world.layout.doodads + world.layout.dash_walls:
		e["smashed"] = true
		e["broken_by"] = "dash"
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
	return {"what": ("killed %d enemies, switched %d fences off, ran %d floor cuts, smashed %d doodads and dash walls (and"
		+ " marked every one), took %d credits and lengthened its track") % [kills, off, cuts, smashed, taken]}


# --- Smashed doodads and dash walls stand again (the H merge) -----------------------------------------

## Tasks H5 and H7a meet PERF2 (the H merge): the dash smashes a zone doodad, and a dash wall breaks as the runner
## reaches it, each marked in the attempt's own copy of the layout ("smashed", a wall's "broken_by") and never built
## again in that attempt's world (TrackBuilder). A retry plays a fresh copy of the kept build in a world built anew, so
## both stand again. At campaign level `id` (3 lanes: its first doodad stands in the runner's starting lane, well
## before its first wall; god mode and no falls, every item, the dash at its top tier), each from PLAY:
## - an attempt that never dashes, the cache off (a fresh build, as before PERF2), past the wall: pushed by the doodad,
##   crashing through the wall (god mode);
## - the first run with the cache: it dashes through the doodad and the wall (each smashed, the wall broken by the
##   dash, each node's look hidden and its collision off), then dies; the kept build is never marked;
## - its restart in place (LevelRun.restart) reuses the build and starts from its layout exactly (nothing marked); as the
##   runner comes up to them the doodad and the wall are built whole, exactly as on the first run (the same node in the
##   same place, on the same layers with the same shapes, the same look: mesh, material and pieces' colours) and
##   standing in the physics world; not dashing, it plays exactly as the attempt on a fresh build: the same runner's
##   trace and events (the doodad's push, the wall's crash);
## - the results screen's retry (App.retry) reuses the build too, from its layout exactly, with both built whole as the
##   track is built ahead.
func _test_smashed_stand_again(id: String) -> void:
	var saved_args: PackedStringArray = App._review_args
	App._review_args = SMASH_ARGS
	var step: CampaignStep = App.campaign.step(id)
	# An attempt that never dashes, on a fresh build.
	LevelCache.enabled = false
	_restock()
	App.start_level(step)
	await tree.process_frame
	var pick: Dictionary = _smash_targets(App.run.world)
	check(not pick.is_empty(), "%s at 3 lanes has a doodad in the runner's lane well before its first dash wall" % id)
	if pick.is_empty():
		LevelCache.enabled = true
		App._review_args = saved_args
		return
	App.begin_run()
	var fresh: Dictionary = await _drive(App.run.world, pick, false)
	# The first run with the cache: it dashes through both, then dies.
	LevelCache.enabled = true
	LevelCache.forget()
	_restock()
	App.start_level(step)
	await tree.process_frame
	var built: String = _layout_dump(App.run.world.layout)
	var kept: String = _layout_dump(LevelCache._layout)
	App.begin_run()
	var first: Dictionary = await _drive(App.run.world, pick, true)
	var w: RunWorld = App.run.world
	var doodad: Dictionary = w.layout.doodads[int(pick["doodad"])]
	var wall: Dictionary = w.layout.dash_walls[int(pick["wall"])]
	var tag: String = "%s (3 lanes; the doodad at %.0f m, the wall at %.0f m)" % [id, float(doodad["start"]), float(wall["start"])]
	check(bool(first["doodad_broke"]) and bool(doodad.get("smashed", false)) and String(first["doodad_sig"]) != "",
		"%s: the dash smashes the doodad, marked in the run's layout, its look hidden and its collision off (%s)" % [tag, first["events"]])
	check(bool(first["wall_broke"]) and bool(wall.get("smashed", false)) and String(wall.get("broken_by", "")) == "dash"
		and String(first["wall_sig"]) != "", "%s: and breaks the wall, broken by the dash, likewise" % tag)
	w.player._die("test hazard")
	await physics_frames(6)
	check(App.run.state == LevelRun.State.DEAD, "%s: the runner dies" % tag)
	check(_layout_dump(LevelCache._layout) == kept and not kept.contains("smashed") and not kept.contains("broken_by"),
		"%s: the kept build was never marked" % tag)
	# Its restart in place: both whole, and an attempt without the dash plays as on a fresh build.
	_restock()
	App.run.restart()
	check(LevelCache.last_reused and _layout_dump(App.run.world.layout) == built,
		"%s, its restart (LevelRun.restart): it reuses the build, from its layout exactly (nothing marked)" % tag)
	await tree.process_frame
	App.begin_run()
	var again: Dictionary = await _drive(App.run.world, pick, false)
	check(String(again["doodad_sig"]) == String(first["doodad_sig"]) and bool(again["doodad_stood"]),
		"%s, its restart: the doodad built whole, as on the first run (the same node, place, layers, shapes and look), standing" % tag)
	check(String(again["wall_sig"]) == String(first["wall_sig"]) and bool(again["wall_stood"]),
		"%s, its restart: the wall built whole, as on the first run, standing" % tag)
	check(again["trace"] == fresh["trace"] and again["events"] == fresh["events"] and int(fresh["pushes"]) >= 1
		and int(fresh["crashes"]) >= 1, "%s, its restart without the dash plays as on a fresh build: the same trace (%s) and events (%s)" % [
		tag, _first_diff(again["trace"], fresh["trace"]), _first_diff(again["events"], fresh["events"])])
	# The results screen's retry: a new LevelRun, both whole as the track is built ahead.
	_restock()
	App.retry(App.run.context)
	var world: RunWorld = App.run.world
	check(LevelCache.last_reused and _layout_dump(world.layout) == built,
		"%s, the results screen's retry (App.retry): it reuses the build, from its layout exactly" % tag)
	# The track built ahead (this attempt is thrown away after; not begun, so nothing joins the physics world).
	var ahead: Dictionary = {}
	for k: String in ["doodad", "wall"]:
		var entry: Dictionary = world.layout.doodads[int(pick["doodad"])] if k == "doodad" \
			else world.layout.dash_walls[int(pick["wall"])]
		world.track.update(float(entry["start"]) - 60.0, 0.0)
		world.track.dress_all()
		var b: DashBreakable = _breakable_of(world, entry)
		ahead[k] = _breakable_sig(b) if b != null else ""
		ahead[k + "_stood"] = b != null and _stands(b)
	check(String(ahead["doodad"]) == String(first["doodad_sig"]) and bool(ahead["doodad_stood"])
		and String(ahead["wall"]) == String(first["wall_sig"]) and bool(ahead["wall_stood"]),
		"%s, the results screen's retry: the doodad and the wall built whole, as on the first run" % tag)
	App._review_args = saved_args


## The targets for _test_smashed_stand_again in `world`'s layout: the level's first dash wall, and the last zone doodad
## in the runner's starting lane between the run-up's end and 60 m before the wall's clear approach, by their indices
## ({doodad, wall}); {} if there's none.
func _smash_targets(world: RunWorld) -> Dictionary:
	var lay: LevelLayout = world.layout
	if lay.dash_walls.is_empty():
		return {}
	var face: float = float(lay.dash_walls[0]["start"])
	var best: int = -1
	for i: int in lay.doodads.size():
		var d: Dictionary = lay.doodads[i]
		if int(d["lane"]) == world.player.lane and float(d["start"]) > world.config.start_clear_distance + 20.0 \
				and float(d["end"]) < face - 120.0:
			best = i
	return {} if best < 0 else {"doodad": best, "wall": 0}


## Plays the App's run (begun) until the runner is past the picked dash wall (or out of time), keeping to their lane:
## with `dash`, dashing from DASH_LEAD before the picked doodad and before the wall. Notes each one's node as first
## built and dressed (_breakable_sig) and whether it stood then (its layers on, its look shown, in the physics world),
## whether each broke (its node's look hidden and collision off), and the runner's trace and events, pushes and crashes.
func _drive(world: RunWorld, pick: Dictionary, dash: bool) -> Dictionary:
	var doodad: Dictionary = world.layout.doodads[int(pick["doodad"])]
	var wall: Dictionary = world.layout.dash_walls[int(pick["wall"])]
	var p: Player = world.player
	var out: Dictionary = {"doodad_sig": "", "wall_sig": "", "doodad_stood": false, "wall_stood": false,
		"doodad_broke": false, "wall_broke": false}
	var trace := PackedStringArray()
	var events := PackedStringArray()
	p.movement_event.connect(func(kind: StringName) -> void:
		events.append("%.3f %s" % [world.level_time(), kind]))
	var targets: Dictionary = {"doodad": doodad, "wall": wall}
	var frames: int = int((float(wall["end"]) / world.tuning.run_speed + 15.0) * 60.0)
	for i: int in frames:
		if p.distance > float(wall["end"]) + 5.0:
			break
		for k: String in targets:
			var entry: Dictionary = targets[k]
			if dash and p.distance >= float(entry["start"]) - DASH_LEAD and p.distance < float(entry["start"]) \
					and not bool(entry.get("smashed", false)) and not p.dashing:
				world.powerups.call(&"try_dash")
			var b: DashBreakable = _breakable_of(world, entry)
			if b == null:
				continue
			if String(out[k + "_sig"]) == "" and not b.debris_colors.is_empty() and not b.is_smashed():
				out[k + "_sig"] = _breakable_sig(b)
				out[k + "_stood"] = _stands(b) and _occupied(world, b)
			if b.is_smashed() and not bool(out[k + "_broke"]):
				out[k + "_broke"] = not b.visible and b.collision_layer == 0 and not _occupied(world, b)
		await tree.physics_frame
		if i % 30 == 0:
			trace.append("%.3f %.4f %d %d %.4f" % [world.level_time(), p.distance, p.lane, p.surface, p.h])
	out["trace"] = trace
	out["events"] = events
	out["pushes"] = p.pushes
	out["crashes"] = p.crashes
	out["smashes"] = p.smashes
	return out


## Every DashBreakable (a zone doodad or a dash wall) under `node`.
static func _breakables(node: Node) -> Array[DashBreakable]:
	var out: Array[DashBreakable] = []
	for child: Node in node.find_children("*", "Area3D", true, false):
		if child is DashBreakable:
			out.append(child as DashBreakable)
	return out


## The built node of layout entry `entry` (a doodad's or a dash wall's) in `world`, or null.
static func _breakable_of(world: RunWorld, entry: Dictionary) -> DashBreakable:
	for b: DashBreakable in _breakables(world.track):
		if is_same(b.entry, entry) and not b.is_queued_for_deletion():
			return b
	return null


## True if `b` stands: not smashed, its look shown, its own layers and every collision object's under it on.
static func _stands(b: DashBreakable) -> bool:
	if b.is_smashed() or not b.visible or b.collision_layer == 0:
		return false
	for node: Node in b.find_children("*", "CollisionObject3D", true, false):
		if (node as CollisionObject3D).collision_layer == 0:
			return false
	return true


## True if the physics world has something of `b` on its layers inside its box (as the push, the lane blocker and the
## dash's approach check find it).
static func _occupied(world: RunWorld, b: DashBreakable) -> bool:
	var shape := BoxShape3D.new()
	shape.size = b.size * Vector3(0.6, 0.6, 0.6)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = TrackBuilder.LAYER_DOODAD | TrackBuilder.LAYER_LANE_BLOCKER | TrackBuilder.LAYER_DASH_WALL \
		| TrackBuilder.LAYER_HAZARD
	q.transform = Transform3D(Basis.IDENTITY, b.global_position)
	return not world.player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## A built doodad's or dash wall's node as text: its kind, place and box, whether it shows, its layers and its pieces'
## colours; every collision object and shape under it (class, place, layers, box); and its look, each mesh and
## material by identity (the skins cache them: the same look builds the very same ones), the hitbox view's boxes aside.
static func _breakable_sig(b: DashBreakable) -> String:
	var parts: PackedStringArray = ["%s %s %s shown %s layers %d/%d colours %s" % [b.kind, b.global_position, b.size,
		b.visible, b.collision_layer, b.collision_mask, b.debris_colors]]
	for node: Node in b.find_children("*", "", true, false):
		if node is CollisionObject3D:
			var co := node as CollisionObject3D
			parts.append("%s %s layers %d/%d" % [co.get_class(), co.global_position, co.collision_layer, co.collision_mask])
		elif node is CollisionShape3D:
			var cs := node as CollisionShape3D
			var box := cs.shape as BoxShape3D
			parts.append("shape %s %s off %s" % [cs.global_position, box.size if box != null else Vector3.ZERO, cs.disabled])
		elif node is MeshInstance3D and not node.is_in_group(&"debug_hitbox"):
			var mi := node as MeshInstance3D
			parts.append("look %s mesh %d material %d shown %s" % [mi.position, mi.mesh.get_instance_id() if mi.mesh != null else 0,
				mi.material_override.get_instance_id() if mi.material_override != null else 0, mi.visible])
	return "\n".join(parts)


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
