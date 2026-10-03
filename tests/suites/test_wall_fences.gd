extends SkinSuite
## Wall fences (task B5; GDD §9.1: "electric fences that span a side wall and turn off and on from time
## to time, to make the walls less safe"; full-height ones from Marketplace 2, passed by timing; partial
## ones over the low or the high part of the wall from the Corporate zone, passed by entering the wall
## high or low; the same rules as floor fences; never where a ramp launches the player into one while
## it's on, never on a wall section with a sign or a window cyborg). Checked here:
## - the data (LevelLayout.wall_fences: left out of a level without them) and WallFencePlan's geometry
##   and timing (bands, reach, the state on the level clock);
## - the track: a hazard on the wall-run path, electrical, never a wall blocker, pulsing on the level
##   clock with the floor fence's warning (the crackle too), as WallFencePlan says;
## - real physics: a wall runner is hit while it's on and safe while it's off, a floor runner in the
##   outer lane never touches it, partial ones are passed high or low (and hit the other way), the
##   warning comes first and a wall runner who jumps off when it starts is never hit, armor, the shield
##   and the dash get through and claws don't, weapons never target it, and a generator's EMP switches
##   it off;
## - the generator: every campaign level with the features places them fairly at 3, 5 and 6 lanes
##   (LayoutChecks.check_wall_fences: ramps, signs, window cyborgs, vents, the outer lane, cuts and big
##   attacks, timing, spacing), Marketplace 2 and Corporate 1 introduce them gently, every level keeps
##   them, the same on every attempt, at every zone's speed (pace), and a level is exactly the same
##   without them but for its wall fences; problem() names each rule; quick play with the features too;
## - the first-encounter hints, every zone skin's look, and a boss arena carrying them.

const LEVELS: Array = ["marketplace/2", "corporate/1", "corporate/2", "dead_zone/1", "dead_zone/2", "golden/1",
	"golden/2", "golden/3"]
const WITHOUT: Array = ["city/1", "city/2", "city/3", "gangland/1", "gangland/2", "gangland/3", "marketplace/1"]

var sim: RunSim
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	_test_data()
	_test_plan()
	await _test_track()
	await _test_wall_runner()
	await _test_partial_bands()
	await _test_warning_first()
	await _test_protection()
	await _test_emp()
	_test_campaign_levels()
	_test_introductions()
	_test_pace()
	_test_same_without()
	_test_quick_play()
	_test_problem()
	await _test_hints()
	await _test_skins()
	_test_arena()


## A layout of `lanes` lanes with `fences` (WallFencePlan.make entries).
static func _layout(lanes: int, fences: Array, length: float = 400.0) -> LevelLayout:
	var l := RunSim.layout(lanes, length)
	for w: Dictionary in fences:
		l.wall_fences.append(w)
	return l


## A wall fence that stays on for the whole test (on for a long time from the start).
static func _live(side: int, at: float, band: String = "full") -> Dictionary:
	return WallFencePlan.make(side, at, band, 600.0, 1.0, 0.0)


## A wall fence that stays off for the whole test (just past its on time, a long off time ahead).
static func _dark(side: int, at: float, band: String = "full") -> Dictionary:
	return WallFencePlan.make(side, at, band, 1.0, 600.0, 2.0 / 601.0)


func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k == "armor":
			l.armor = true
		elif k in ["shield", "grapple", "revive"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


# --- Data and geometry --------------------------------------------------------------------------

func _test_data() -> void:
	var l := RunSim.layout(3)
	check(not l.to_dict().has("wall_fences"), "a layout without wall fences has no wall_fences list in its data: the same data as before")
	l.wall_fences.append(WallFencePlan.make(1, 50.0, "full", 1.0, 1.2, 0.3))
	check((l.to_dict().get("wall_fences", []) as Array).size() == 1, "a layout's wall fences are in its data")
	var c: LevelLayout = l.copy()
	check(c.wall_fences.size() == 1 and not is_same(c.wall_fences[0], l.wall_fences[0]), "a copy carries its own wall fences")
	var into := RunSim.layout(3)
	into.append_pieces(l)
	check(into.wall_fences.size() == 1, "appending pieces brings the wall fences along, into a layout without any")
	check(l.wall_fence_between(45.0, 55.0, 1) and l.wall_fence_between(45.0, 55.0) and not l.wall_fence_between(45.0, 55.0, -1)
		and not l.wall_fence_between(51.0, 60.0), "wall_fence_between finds one by its wall and spot")
	check(not WallFencePlan.is_partial(l.wall_fences[0]) and WallFencePlan.is_partial(WallFencePlan.make(1, 0.0, "low", 1.0, 1.0, 0.0)),
		"low and high wall fences are the partial ones")
	check(LevelGenerator.feature_positions(l, "wall_fences") == [50.0] and LevelGenerator.feature_positions(l, "wall_fences_partial").is_empty(),
		"the guarantee finds full-height wall fences under wall_fences, partial ones under wall_fences_partial")
	check(not LevelConfig.PLANNED_FEATURES.has("wall_fences") and not LevelConfig.PLANNED_FEATURES.has("wall_fences_partial")
		and LayoutChecks.can_locate("wall_fences") and LayoutChecks.can_locate("wall_fences_partial"),
		"wall fences are built features now, no longer planned ones")


func _test_plan() -> void:
	var t: MovementTuning = tuning
	var full: Vector2 = WallFencePlan.band_heights("full", t)
	var low: Vector2 = WallFencePlan.band_heights("low", t)
	var high: Vector2 = WallFencePlan.band_heights("high", t)
	var body: float = t.hurtbox_size.x * 0.5
	check(is_zero_approx(full.x) and full.y >= t.wall_max_height + body and full.y >= t.ramp_entry_height + body,
		"a full-height wall fence covers the whole wall-run path, from the floor to above the highest wall run (%.2f m)" % full.y)
	check(is_zero_approx(low.x) and low.y < high.x and is_equal_approx(high.y, full.y),
		"the low band is the bottom of the wall, the high band its top")
	var entry := Vector2(t.wall_entry_height - body, t.wall_entry_height + body)
	check(entry.x > low.y and entry.y < high.x,
		"a free wall entry's body (%.2f-%.2f m) runs between the two bands (low up to %.2f, high from %.2f)" % [entry.x, entry.y, low.y, high.x])
	var jump_in: float = minf(t.wall_entry_height + t.jump_height * t.wall_air_entry_factor, t.wall_max_height)
	check(jump_in - body > low.y and jump_in + body > high.x,
		"jumping onto the wall carries the body above the low band, and into the high one (%.2f m)" % jump_in)
	var reach: float = WallFencePlan.reach(t)
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, t)
		for side: int in [-1, 1]:
			var w: Dictionary = WallFencePlan.make(side, 100.0, "full", 1.0, 1.0, 0.0)
			var box: AABB = WallFencePlan.hitbox(w, t, geo)
			var outer: float = geo.lane_x(0 if side < 0 else lanes - 1)
			var floor_body := AABB(Vector3(outer - body, 0.0, -100.5), Vector3(body * 2.0, t.hurtbox_size.y, 1.0))
			check(not box.intersects(floor_body),
				"a floor runner in the middle of the outer lane never touches it (%d lanes, side %d)" % [lanes, side])
			var wall_x: float = side * geo.wall_x()
			var wall_body := AABB(Vector3(wall_x - t.hurtbox_size.y if side > 0 else wall_x, 1.5 - body, -100.5),
				Vector3(t.hurtbox_size.y, body * 2.0, 1.0))
			check(box.intersects(wall_body), "a wall runner within its band touches it (%d lanes, side %d)" % [lanes, side])
			check(is_equal_approx(box.size.x, reach) and (box.position.x >= wall_x - reach - 0.001 and box.end.x <= wall_x + reach + 0.001),
				"its field reaches out from the facade by its reach (%d lanes, side %d)" % [lanes, side])
	# The state on the level clock: on, then off, the last of it a warning, again.
	var p: Dictionary = WallFencePlan.make(1, 0.0, "full", 1.0, 1.5, 0.2)
	var warn: float = t.fence_pulse_warning
	var seen: Array[int] = []
	var prev: int = -1
	var bad: int = 0
	for i: int in 600:
		var s: int = WallFencePlan.state_at(p, i / 60.0, warn)
		if s != prev:
			seen.append(s)
			if s == Hazard.State.ON and prev == Hazard.State.OFF:
				bad += 1
			prev = s
	check(bad == 0 and seen.has(Hazard.State.WARNING), "it never switches from off to on without its warning first (%s)" % [seen])
	var on_at: float = WallFencePlan.next_on(p, 0.0)
	check(WallFencePlan.state_at(p, on_at + 0.01, warn) == Hazard.State.ON and WallFencePlan.state_at(p, on_at - 0.01, warn) == Hazard.State.WARNING
		and WallFencePlan.state_at(p, on_at - warn - 0.02, warn) == Hazard.State.OFF, "next_on is where its warning ends and it switches on")
	check(WallFencePlan.blocks(WallFencePlan.make(1, 0.0, "low", 1.0, 1.0, 0.0), Vector2(1.6, 2.0), t)
		and not WallFencePlan.blocks(WallFencePlan.make(1, 0.0, "low", 1.0, 1.0, 0.0), Vector2(1.9, 2.3), t)
		and not WallFencePlan.blocks(WallFencePlan.make(1, 0.0, "high", 1.0, 1.0, 0.0), Vector2(2.0, 2.4), t),
		"blocks() says whether a wall runner's body reaches into a band")


# --- On the track -----------------------------------------------------------------------------

func _test_track() -> void:
	var layout := _layout(5, [WallFencePlan.make(1, 30.0, "full", 1.0, 1.3, 0.25), WallFencePlan.make(-1, 50.0, "low", 1.1, 1.2, 0.6),
		WallFencePlan.make(1, 70.0, "high", 0.9, 1.4, 0.0)])
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.sfx = load("res://data/audio/sfx_library.tres") as SfxLibrary
	track.set_layout(layout, tuning)
	track.update(0.0, 0.0)
	var built: Array[Hazard] = track.wall_fence_hazards()
	check(built.size() == 3, "each wall fence is built as a hazard (%d)" % built.size())
	var geo := TrackGeometry.new(5, tuning)
	for i: int in built.size():
		var h: Hazard = built[i]
		var w: Dictionary = layout.wall_fences[i]
		var box: AABB = WallFencePlan.hitbox(w, tuning, geo)
		check(h.global_position.is_equal_approx(box.get_center()) and h.size.is_equal_approx(box.size),
			"%s: its hitbox is WallFencePlan's (%s, %s)" % [h.hazard_name, h.global_position, h.size])
		check(h.is_electrical and not h.is_solid and not h.is_enemy_attack and h.enemy == null and h.dash_passes,
			"%s: electrical, like a floor fence (DamageRules: armor, the shield and the dash get through)" % h.hazard_name)
		check(h.collision_layer == TrackBuilder.LAYER_HAZARD, "%s: on the hazard layer only, never a wall blocker" % h.hazard_name)
		var telegraph: bool = false
		for child: Node in h.get_children():
			telegraph = telegraph or child is HazardTelegraph
		check(telegraph, "%s: the floor fence's crackle plays before it switches on" % h.hazard_name)
		check(h.hazard_name == "wall fence (%s)" % w["band"], "its name says its band (%s)" % h.hazard_name)
	# Pulsing on the level clock, as WallFencePlan says, through several cycles.
	var warn: float = tuning.fence_pulse_warning
	var wrong: int = 0
	var frames: int = 0
	var t0: float = 0.0
	for k: int in 360:
		await tree.physics_frame
		t0 += 1.0 / 60.0
		frames += 1
		for i: int in built.size():
			var expect: int = WallFencePlan.state_at(layout.wall_fences[i], t0, warn)
			var before: int = WallFencePlan.state_at(layout.wall_fences[i], t0 - 1.0 / 60.0, warn)
			var after: int = WallFencePlan.state_at(layout.wall_fences[i], t0 + 1.0 / 60.0, warn)
			if built[i].state != expect and built[i].state != before and built[i].state != after:
				wrong += 1
	check(wrong == 0, "every wall fence follows WallFencePlan.state_at on the level clock (%d frames off in %d)" % [wrong, frames])
	# Built later in the level, it picks up the level clock where it is.
	var late := _layout(3, [WallFencePlan.make(1, 20.0, "full", 1.0, 1.4, 0.4)])
	var late_track := TrackBuilder.new()
	world.add_child(late_track)
	late_track.set_layout(late, tuning)
	for at_time: float in [0.3, 1.25, 2.2, 3.05]:
		late_track.set_layout(late, tuning)
		late_track.update(0.0, at_time)
		var h: Hazard = late_track.wall_fence_hazards()[0]
		check(h.state == WallFencePlan.state_at(late.wall_fences[0], at_time, warn),
			"a wall fence built %.2f s into the level shows the state the level clock says" % at_time)
	world.queue_free()
	await tree.process_frame


# --- Real physics -------------------------------------------------------------------------------

## A runner who steps onto the right wall at `entry` m (in the right outer lane from the start) and
## stays there: [distance, action] pairs for RunSim, with a jump first (`high`) to enter the wall high.
static func _onto_wall(entry: float, high: bool = false) -> Array:
	if high:
		return [[entry, &"jump"], [entry + 6.5, &"move_right"]]
	return [[entry, &"move_right"]]


func _test_wall_runner() -> void:
	for lanes: int in [3, 5, 6]:
		var tag: String = "(%d lanes)" % lanes
		var right: int = lanes - 1
		# On: a wall runner meets it and is hit.
		var r: Dictionary = await sim.run(_layout(lanes, [_live(1, 60.0)]), right, 4.0, _onto_wall(40.0), [55.0])
		check(r["at"][55.0]["surface"] == "wall", "the runner is on the wall as they reach it " + tag)
		check(not r["alive"] and r["cause"] == "wall fence (full)", "a wall runner who meets it while it's on is hit (%s) %s" % [r["cause"], tag])
		# Off: they pass.
		r = await sim.run(_layout(lanes, [_dark(1, 60.0)]), right, 4.0, _onto_wall(40.0), [55.0, 70.0])
		check(r["alive"] and r["at"][70.0]["alive"] and r["at"][55.0]["surface"] == "wall",
			"a wall runner who meets it while it's off passes (%s) %s" % [r["cause"], tag])
		# A floor runner in the outer lane beside a live one never touches it, on either side.
		r = await sim.run(_layout(lanes, [_live(1, 40.0), _live(-1, 70.0)]), right, 3.0, [[50.0, &"move_left"]] if lanes == 3 else [])
		check(r["alive"], "a floor runner in the outer lane runs past a live wall fence (%s) %s" % [r["cause"], tag])
		r = await sim.run(_layout(lanes, [_live(-1, 40.0)]), 0, 3.0, [])
		check(r["alive"], "on the left wall too (%s) %s" % [r["cause"], tag])
		# Stepping onto the wall into a live one hits.
		r = await sim.run(_layout(lanes, [_live(1, 40.0)]), right, 3.0, [[39.0, &"move_right"]])
		check(not r["alive"] and String(r["cause"]).begins_with("wall fence"),
			"stepping onto the wall into a live one is a hit (%s) %s" % [r["cause"], tag])
		# A wall runner who jumps off before it passes it on the floor.
		r = await sim.run(_layout(lanes, [_live(1, 70.0)]), right, 5.0, _onto_wall(40.0) + [[60.0, &"jump"]], [75.0])
		check(r["alive"] and r["at"][75.0]["surface"] == "floor",
			"a wall runner who jumps off the wall before it passes it (%s) %s" % [r["cause"], tag])


## GDD §9.1: partial ones are passed by entering the wall high or low. The low band: a runner who jumps
## onto the wall passes above it; one who steps on and has come down by then is hit. The high band: a
## runner who steps on passes below it; one who jumps on is hit.
func _test_partial_bands() -> void:
	for lanes: int in [3, 5, 6]:
		var tag: String = "(%d lanes)" % lanes
		var right: int = lanes - 1
		var low: LevelLayout = _layout(lanes, [_live(1, 62.0, "low")])
		var r: Dictionary = await sim.run(low, right, 4.0, _onto_wall(40.0, true), [60.0, 75.0])
		check(r["alive"] and r["at"][60.0]["surface"] == "wall" and r["at"][75.0]["alive"],
			"entering the wall high passes above a low wall fence (h %.2f m at it; %s) %s" % [r["at"][60.0]["h"], r["cause"], tag])
		r = await sim.run(low, right, 4.0, _onto_wall(46.5), [60.0])
		check(not r["alive"] and r["cause"] == "wall fence (low)",
			"a runner who stepped on and has come down meets a low one (h %.2f m at it; %s) %s" % [r["at"][60.0]["h"], r["cause"], tag])
		var high: LevelLayout = _layout(lanes, [_live(1, 62.0, "high")])
		r = await sim.run(high, right, 4.0, _onto_wall(46.5), [60.0, 75.0])
		check(r["alive"] and r["at"][60.0]["surface"] == "wall" and r["at"][75.0]["alive"],
			"entering the wall low passes below a high wall fence (h %.2f m at it; %s) %s" % [r["at"][60.0]["h"], r["cause"], tag])
		r = await sim.run(high, right, 4.0, _onto_wall(40.0, true), [60.0])
		check(not r["alive"] and r["cause"] == "wall fence (high)",
			"a runner who jumped onto the wall meets a high one (h %.2f m at it; %s) %s" % [r["at"][60.0]["h"], r["cause"], tag])


## The warning comes first (GDD §9.1: the same flicker and crackle before switching on), and a player
## already on the wall sees it in time to drop off: wherever they are when the warning starts, a wall
## runner who jumps off REACTION seconds later is never hit (the warning is a floor fence's, whose
## dodges are as quick), while staying on runs into it at some phases.
const REACTION: float = 0.2


func _test_warning_first() -> void:
	var warn: float = tuning.fence_pulse_warning
	var speed: float = tuning.run_speed
	var at: float = 80.0
	var entry: float = 45.0
	var hits_staying: int = 0
	var dropped_hit: int = 0
	var cases: int = 0
	for k: int in 16:
		var w: Dictionary = WallFencePlan.make(1, at, "full", 1.2, 1.2, k / 16.0)
		# Where the runner is when its warning starts, once they're on the wall and before they pass it.
		var warn_start: float = WallFencePlan.next_on(w, entry / speed + 0.3) - warn
		var d: float = warn_start * speed
		if d < entry + 4.0 or d > at - 1.0:
			continue
		cases += 1
		var stay: Dictionary = await sim.run(_layout(3, [w]), 2, 6.0, _onto_wall(entry), [at + 5.0])
		hits_staying += 0 if stay["alive"] else 1
		var drop: Dictionary = await sim.run(_layout(3, [w]), 2, 6.0, _onto_wall(entry) + [[d + REACTION * speed, &"jump"]], [at + 5.0])
		if not drop["alive"]:
			dropped_hit += 1
			print("    dropped off %.2f s after the warning started %.1f m before it, and was hit (%s)" % [REACTION, at - d, drop["cause"]])
	check(cases >= 4, "the warning starts while the runner is on the wall in several cases (%d)" % cases)
	check(dropped_hit == 0, "a wall runner who jumps off %.2f s after the warning starts is never hit (%d of %d were)" % [
		REACTION, dropped_hit, cases])
	check(hits_staying > 0, "while one who stays on the wall runs into it at some phases (%d of %d)" % [hits_staying, cases])


func _test_protection() -> void:
	var layout := _layout(3, [_live(1, 60.0), _live(1, 200.0)])
	# From the middle lane, where a world's runner starts, onto the right wall.
	var on_wall: Array = [[36.0, &"move_right"], [40.0, &"move_right"]]
	var w: RunWorld = sim.build_world(layout, _loadout({"armor": 1}))
	var r: Dictionary = await sim.step_world(w, 1.0 + 60.0 / tuning.run_speed, on_wall)
	check(r["alive"] and r["events"].has(&"armor_break"), "armor gets a wall runner through a live wall fence (%s)" % r["cause"])
	await sim.free_world(w)
	w = sim.build_world(layout, _loadout({"shield": 1}))
	r = await sim.step_world(w, 1.0 + 60.0 / tuning.run_speed, on_wall)
	check(r["alive"] and r["events"].has(&"shield_break"), "the shield gets them through (%s)" % r["cause"])
	await sim.free_world(w)
	w = sim.build_world(layout)
	r = await sim.step_world(w, 52.0 / tuning.run_speed, on_wall)
	check(w.player.surface == Player.Surface.WALL and w.player.distance < 58.0, "on the wall before it (%.1f m)" % w.player.distance)
	w.player.start_dash(1.0, 5.0)
	r = await sim.step_world(w, 1.2)
	check(r["alive"] and w.player.distance > 61.0, "the juggernaut dash gets them through (%s)" % r["cause"])
	await sim.free_world(w)
	w = sim.build_world(layout, _loadout({"claws": 1}))
	r = await sim.step_world(w, 1.0 + 60.0 / tuning.run_speed, on_wall)
	check(not r["alive"] and String(r["cause"]).begins_with("wall fence"), "claws don't (%s)" % r["cause"])
	await sim.free_world(w)
	# Weapons can't destroy one: it's no enemy, so auto-fire never targets it, and it stays live.
	w = sim.build_world(layout, _loadout({"weapon": 1}))
	var controller := w.powerups as PowerupController
	check(controller != null and controller.weapon != null, "the weapon is armed")
	r = await sim.step_world(w, 1.0 + 60.0 / tuning.run_speed, on_wall)
	check(controller == null or controller.weapon.pick_target() == null, "auto-fire finds nothing to shoot at in a wall fence")
	check(not r["alive"] and String(r["cause"]).begins_with("wall fence"), "and the wall fence stays live (%s)" % r["cause"])
	await sim.free_world(w)


## GDD §9.1: a generator's EMP switches wall fences off for the rest of the level, built or not yet built;
## ones out of its reach stay live.
func _test_emp() -> void:
	var layout := _layout(3, [_live(1, 60.0), _live(-1, 64.0), _live(1, 300.0), _live(1, 120.0)])
	var w: RunWorld = sim.build_world(layout)
	await tree.physics_frame
	var count: int = w.emp(w.lane_point(1, 55.0, 0.55), 16.0)
	check(count == 2, "an EMP reaches the wall fences near it, on both walls (%d)" % count)
	var hazards: Array[Hazard] = w.track.wall_fence_hazards()
	check(hazards.size() >= 2 and not hazards[0].is_active() and not hazards[1].is_active(), "and switches them off")
	check(not layout.wall_fences[3].get("disabled", false), "one out of its reach stays on")
	check(w.track.disable_fences_near(w.lane_point(1, 300.0, 0.55), 16.0) == 1 and layout.wall_fences[2].get("disabled", false),
		"one not built yet is switched off too")
	var r: Dictionary = await sim.step_world(w, 1.0 + 70.0 / tuning.run_speed, _onto_wall(40.0), [80.0])
	check(r["at"][80.0]["alive"], "a wall runner runs through a switched-off wall fence (%s)" % r["cause"])
	await sim.free_world(w)


# --- The generator ------------------------------------------------------------------------------

## Every campaign level with the features places them fairly at 3, 5 and 6 lanes, on its own seed and
## others (LayoutChecks.check_wall_fences), keeps both kinds where it has both features, and builds
## the same wall fences on every attempt.
func _test_campaign_levels() -> void:
	var bands := {"full": 0, "low": 0, "high": 0}
	var per_minute: Array[float] = []
	for id: String in LEVELS:
		for lanes: int in [3, 5, 6]:
			for k: int in 3:
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				if k > 0:
					config.level_seed = 9100 + k
				var tag: String = "%s lanes=%d seed=%d" % [id, lanes, config.level_seed]
				var patterns: Array = LevelGenerator.load_for(config)
				# T-SPEED: shared across the run (LayoutCache); at k==0 this is a campaign level's own
				# default build, the same one test_campaign.gd's own checks already made.
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
				var layout: LevelLayout = gen.layout
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				LayoutChecks.check_wall_fences(self, layout, config, tag)
				for w: Dictionary in layout.wall_fences:
					bands[String(w["band"])] = int(bands[String(w["band"])]) + 1
				per_minute.append(layout.wall_fences.size() / (layout.length / gen.speed) * 60.0)
				check(not LevelGenerator.feature_positions(layout, "wall_fences").is_empty(),
					"%s keeps its full-height wall fences (GDD §5) %s" % [id, tag])
				check(LevelGenerator.feature_positions(layout, "wall_fences_partial").is_empty() != config.has_feature("wall_fences_partial"),
					"partial ones exactly where the level has them %s" % tag)
				if k == 0:
					var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(again.wall_fences) == JSON.stringify(layout.wall_fences), "the same wall fences on every attempt " + tag)
	per_minute.sort()
	check(per_minute[0] >= 1.0, "every level meets a few (the fewest %.1f a minute)" % per_minute[0])
	check(int(bands["low"]) > 0 and int(bands["high"]) > 0 and int(bands["full"]) > int(bands["low"]),
		"both partial bands come, full-height ones still the most (%s)" % [bands])
	print("  wall fences per minute: %.1f to %.1f (median %.1f); bands %s" % [per_minute[0], per_minute[-1],
		per_minute[per_minute.size() / 2], bands])


## GDD §6 and the schedule (GDD §5): Marketplace 2 brings in full-height wall fences and Corporate 1
## partial ones, each gently: nothing of the kind before its start; its first one is the introduction,
## with a long off time and no other wall fence near it on either wall; it comes within intro_seconds
## of the start on the level's own seed and on most others (a big attack can hold it back), mostly where
## no enemy is about.
func _test_introductions() -> void:
	var t: WallFenceTuning = WallFencePlacement.tuning()
	var on_time: int = 0
	var calm: int = 0
	var total: int = 0
	for intro: Array in [["marketplace/2", "wall_fences"], ["corporate/1", "wall_fences_partial"]]:
		var id: String = intro[0]
		var feature: String = intro[1]
		for lanes: int in [3, 5, 6]:
			for k: int in 6:
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				if k > 0:
					config.level_seed = 9200 + k
				var tag: String = "%s lanes=%d seed=%d" % [id, lanes, config.level_seed]
				# T-SPEED: shared across the run (LayoutCache); at k==0 this is the same default build
				# as _test_campaign_levels' (both marketplace/2 and corporate/1 are in LEVELS) and the
				# campaign's own.
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
				var layout: LevelLayout = gen.layout
				var start: float = gen.feature_start(feature)
				check(config.feature_starts.has(feature), "%s gives `%s` a start" % [id, feature])
				var first: Dictionary = {}
				for w: Dictionary in layout.wall_fences:
					if WallFencePlan.is_partial(w) != (feature == "wall_fences_partial"):
						continue
					check(float(w["at"]) >= start - 0.01, "nothing of `%s` before its start (%.0f m) %s" % [feature, start, tag])
					if first.is_empty() or float(w["at"]) < float(first["at"]):
						first = w
				check(not first.is_empty(), "%s has `%s` %s" % [id, feature, tag])
				if first.is_empty():
					continue
				total += 1
				check(float(first["pulse_off"]) >= t.intro_off_seconds - 0.001,
					"the introduction stays off long (%.2f s) %s" % [first["pulse_off"], tag])
				for w: Dictionary in layout.wall_fences:
					if not is_same(w, first):
						check(absf(float(w["at"]) - float(first["at"])) >= t.same_side_gap_seconds * gen.speed - 0.02,
							"no other wall fence near the introduction, on either wall %s" % tag)
				var within: bool = float(first["at"]) <= start + t.intro_seconds * gen.speed + 0.01
				on_time += 1 if within else 0
				if k == 0:
					check(within, "%s meets its first `%s` within %.0f s of the start (%.1f s) %s" % [id, feature, t.intro_seconds,
						(float(first["at"]) - start) / gen.speed, tag])
				if within:
					calm += 1 if _calm(gen, layout, first, t) else 0
	check(on_time * 4 >= total * 3, "most introductions come within %.0f s of the start (%d of %d)" % [t.intro_seconds, on_time, total])
	check(calm * 2 >= on_time, "most of those where no enemy is about (%d of %d)" % [calm, on_time])
	print("  wall fence introductions: %d of %d within %.0f s of the start, %d of those where no enemy is about" % [on_time,
		total, t.intro_seconds, calm])


## True if no enemy is about (what the fill pass keeps for it) within wall fence `w`'s drop window.
func _calm(gen: LevelGenerator, layout: LevelLayout, w: Dictionary, t: WallFenceTuning) -> bool:
	var drop: Vector2 = WallFencePlacement.drop_window(gen, float(w["at"]), t)
	for e: Dictionary in layout.enemies:
		var k: Vector2 = gen.enemy_keep_out(e)
		if k.y >= k.x and k.x <= drop.y and k.y >= drop.x:
			return false
	return true


## GDD §3 (Pace): every rule keeps its seconds at every zone's speed. Marketplace 2 at the base speed and
## at the Golden Zone's places its wall fences fairly at its own speed (the checks measure in seconds
## at it), and its wall fences stand further apart in metres at the faster speed.
func _test_pace() -> void:
	var t: WallFenceTuning = WallFencePlacement.tuning()
	for lanes: int in [3, 5, 6]:
		var closest: Array[float] = []
		for speed: float in [MovementTuning.REFERENCE_SPEED, 25.0]:
			var config: LevelConfig = campaign.configure(campaign.step("marketplace/2"), lanes)
			config.run_speed = speed
			var tag: String = "marketplace/2 at %.0f m/s, %d lanes" % [speed, lanes]
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			check(is_equal_approx(gen.speed, speed), "it's built at %.0f m/s" % speed)
			LayoutChecks.check_wall_fences(self, layout, config, tag)
			var nearest: float = INF
			for a: Dictionary in layout.wall_fences:
				for b: Dictionary in layout.wall_fences:
					if not is_same(a, b) and int(a["side"]) == int(b["side"]):
						nearest = minf(nearest, absf(float(a["at"]) - float(b["at"])))
			closest.append(nearest)
			check(nearest >= t.same_side_gap_seconds * speed - 0.02, "two on one wall stand %.1f s apart at least, at %.0f m/s (%.1f m)" % [
				t.same_side_gap_seconds, speed, nearest])
		check(closest[1] >= t.same_side_gap_seconds * 25.0 - 0.02 and closest[1] > t.same_side_gap_seconds * MovementTuning.REFERENCE_SPEED,
			"at the faster speed they keep their seconds, further apart in metres (%.1f m against %.1f m) (%d lanes)" % [
				closest[1], closest[0], lanes])


## The brief: nothing changes for levels without the feature. A level without wall fences has none and
## no wall_fences list in its data; a level with them is exactly the same without them but for its wall
## fences (they come after the doodads, from a stream of their own, and the credits never look at them):
## the same pattern picks, fillers, guarantee builds, pieces, enemies and credits.
func _test_same_without() -> void:
	for id: String in WITHOUT:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
			check(not config.has_feature("wall_fences") and layout.wall_fences.is_empty() and not layout.to_dict().has("wall_fences"),
				"%s (%d lanes) has no wall fences and no wall_fences list" % [id, lanes])
	for id: String in LEVELS:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var tag: String = "%s lanes=%d" % [id, lanes]
			# Wall gaps keep off wall fences (WallGapPlacement), so they move with them: compared without
			# them on both sides (test_wall_gaps compares a level with and without its wall gaps).
			var gapless := PackedStringArray(config.features)
			gapless.remove_at(gapless.find(WallGapPlacement.FEATURE))
			config.features = gapless
			var bare: LevelConfig = config.duplicate() as LevelConfig
			var features := PackedStringArray()
			for f: String in config.features:
				if f != "wall_fences" and f != "wall_fences_partial":
					features.append(f)
			bare.features = features
			var starts: Dictionary[String, float] = config.feature_starts.duplicate()
			starts.erase("wall_fences")
			starts.erase("wall_fences_partial")
			bare.feature_starts = starts
			var patterns: Array = LevelGenerator.load_for(config)
			var gen := LevelGenerator.new()
			var with: LevelLayout = gen.generate(config, tuning, patterns)
			var plain_gen := LevelGenerator.new()
			var plain: LevelLayout = plain_gen.generate(bare, tuning, patterns)
			var a: Dictionary = with.to_dict()
			a.erase("wall_fences")
			check(not with.wall_fences.is_empty() and plain.wall_fences.is_empty(), "with the features it has them, without none " + tag)
			check(JSON.stringify(a) == JSON.stringify(plain.to_dict()), "the rest of the level is exactly what it is without them " + tag)
			check(JSON.stringify(gen.picks) == JSON.stringify(plain_gen.picks) and JSON.stringify(gen.fills) == JSON.stringify(plain_gen.fills)
				and gen.attempts == plain_gen.attempts, "the same pattern picks, fillers and guarantee builds " + tag)


## Quick play with the features (--features=wall_fences,wall_fences_partial) at any difficulty and lane
## count, among ramps, signs, window cyborgs, wall vents, drones, hover trucks, Octodogs, generators and
## the floor cutter's cuts: every layout passes every layout check, wall fences included.
func _test_quick_play() -> void:
	var base := load(LEVEL_PATH) as LevelConfig
	var placed: int = 0
	var layouts: int = 0
	for lanes: int in [3, 5, 6]:
		for difficulty: float in [0.2, 0.6, 1.0]:
			for level_seed: int in [1, 2, 3]:
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = difficulty
				config.enemy_scaling = difficulty
				config.level_seed = level_seed
				var features: PackedStringArray = base.features.duplicate()
				features.append_array(["window_cyborg", "screech", "drone", "hover_truck", "octodog", "generator", "floor_cutter",
					"wall_fences", "wall_fences_partial"])
				config.features = features
				var tag: String = "quick lanes=%d diff=%.1f seed=%d" % [lanes, difficulty, level_seed]
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
				layouts += 1
				placed += layout.wall_fences.size()
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				check(not LevelGenerator.feature_positions(layout, "wall_fences").is_empty()
					and not LevelGenerator.feature_positions(layout, "wall_fences_partial").is_empty(), "both kinds come " + tag)
				LayoutChecks.check_layout(self, layout, config, tag)
	print("  quick play: %d wall fences in %d layouts" % [placed, layouts])


## WallFencePlacement.problem (LevelGenerator.wall_fence_problem; BossArena.wall_fence_problem) names
## each rule, on a hand-built 3-lane track at the base speed.
func _test_problem() -> void:
	var t: WallFenceTuning = WallFencePlacement.tuning()
	var v: float = tuning.run_speed
	var config := LevelConfig.new()
	config.lane_count = 3
	config.features = PackedStringArray(["wall_fences", "drone"])
	var at: float = 300.0
	var w: Dictionary = WallFencePlan.make(1, at, "full", 1.0, 1.3, 0.5)
	var cases: Array = [
		["a clear stretch", func(_l: LevelLayout) -> void: pass, ""],
		["a sign on its wall section", func(l: LevelLayout) -> void:
			l.signs.append({"side": 1, "start": at + 4.0, "end": at + 12.0, "bottom": 2.8, "top": 5.5}), "sign"],
		["a sign on the other wall", func(l: LevelLayout) -> void:
			l.signs.append({"side": -1, "start": at + 4.0, "end": at + 12.0, "bottom": 2.8, "top": 5.5}), ""],
		["a window cyborg on its wall section", func(l: LevelLayout) -> void:
			l.enemies.append({"type": "window_cyborg", "at": at - 10.0, "lane": 2, "side": 1, "seed": 1, "params": {}}), "window cyborg"],
		["a wall vent's screech on its wall", func(l: LevelLayout) -> void:
			l.enemies.append({"type": "screech", "at": at + 20.0, "lane": 2, "side": 1, "seed": 1, "params": {"source": "vent"}}), "vent"],
		["a ramp launching along its wall", func(l: LevelLayout) -> void:
			l.ramps.append({"side": 1, "at": at - 30.0}), "ramp"],
		["a ramp onto the other wall", func(l: LevelLayout) -> void:
			l.ramps.append({"side": -1, "at": at - 30.0}), ""],
		["a hole in the outer lane beside it", func(l: LevelLayout) -> void:
			l.gaps.append({"lane": 2, "start": at - 10.0, "end": at - 6.0}), "outer lane"],
		["a hole in another lane", func(l: LevelLayout) -> void:
			l.gaps.append({"lane": 0, "start": at - 10.0, "end": at - 6.0}), ""],
		["a fence in the outer lane beside it", func(l: LevelLayout) -> void:
			l.fences.append(RunSim.fence(2, at + 8.0, "full")), "outer lane"],
		["a floor enemy in the outer lane beside it", func(l: LevelLayout) -> void:
			l.enemies.append({"type": "cyborg", "at": at + 6.0, "lane": 2, "side": 0, "seed": 1, "params": {}}), "outer lane"],
		["a drone wave meanwhile", func(l: LevelLayout) -> void:
			l.enemies.append({"type": "drone", "at": at - 60.0, "lane": 1, "side": 0, "seed": 1, "params": {}}), "big attack"],
		["a floor cut meanwhile", func(l: LevelLayout) -> void:
			l.cuts.append(FloorCutPlan.make(0, at + 40.0, 50.0, 25.0, 9.0, v, 20.0, 3.0)), "cut"],
		["another wall fence on its wall", func(l: LevelLayout) -> void:
			l.wall_fences.append(WallFencePlan.make(1, at + (t.same_side_gap_seconds - 0.3) * v, "full", 1.0, 1.0, 0.0)), "another"],
		["another on the other wall, a wall run away", func(l: LevelLayout) -> void:
			l.wall_fences.append(WallFencePlan.make(-1, at + (t.gap_seconds + 0.2) * v, "full", 1.0, 1.0, 0.0)), ""],
		["another on the other wall, too close", func(l: LevelLayout) -> void:
			l.wall_fences.append(WallFencePlan.make(-1, at + (t.gap_seconds - 0.3) * v, "full", 1.0, 1.0, 0.0)), "another"],
	]
	for c: Array in cases:
		var layout := RunSim.layout(3, 700.0)
		(c[1] as Callable).call(layout)
		var gen := LevelGenerator.for_layout(config, tuning, layout)
		var why: String = gen.wall_fence_problem(w)
		var expect: String = c[2]
		if expect == "":
			check(why == "", "%s: fair (%s)" % [c[0], why])
		else:
			check(why.contains(expect), "%s: refused, naming it (%s)" % [c[0], why])
	var gen0 := LevelGenerator.for_layout(config, tuning, RunSim.layout(3, 700.0))
	check(gen0.wall_fence_problem(WallFencePlan.make(0, at, "full", 1.0, 1.3, 0.5)) != ""
		and gen0.wall_fence_problem(WallFencePlan.make(1, at, "middle", 1.0, 1.3, 0.5)) != ""
		and gen0.wall_fence_problem(WallFencePlan.make(1, at, "full", 1.0, tuning.fence_pulse_warning - 0.1, 0.5)) != ""
		and gen0.wall_fence_problem(WallFencePlan.make(1, 30.0, "full", 1.0, 1.3, 0.5)) != "",
		"and refuses one on no wall, over no band, without room for its warning, or in the run-up")
	# A floor cut never runs by a wall fence either (a boss arena's, LevelGenerator.cut_problem).
	var with_fence := RunSim.layout(3, 700.0)
	with_fence.wall_fences.append(w)
	var cut: Dictionary = FloorCutPlan.make(0, at + 40.0, 50.0, 25.0, 9.0, v, 20.0, 3.0)
	with_fence.enemies.append({"type": "floor_cutter", "at": at + 40.0, "lane": 0, "side": 0, "seed": 1, "params": {}})
	check(LevelGenerator.for_layout(config, tuning, with_fence).cut_problem(cut).contains("wall fence"),
		"and a floor cut never runs while a wall fence stands by")


# --- Hints, looks, bosses -----------------------------------------------------------------------

## The intro explains each wall fence band in the layout, naming the player's keys.
func _test_hints() -> void:
	var layout := _layout(3, [WallFencePlan.make(1, 60.0, "full", 1.0, 1.2, 0.0), WallFencePlan.make(-1, 110.0, "low", 1.0, 1.2, 0.0),
		WallFencePlan.make(1, 160.0, "high", 1.0, 1.2, 0.0), WallFencePlan.make(-1, 200.0, "full", 1.0, 1.2, 0.0)])
	var world: RunWorld = sim.build_world(layout)
	var hints := HintDirector.new()
	world.add_child(hints)
	hints.setup(world, Profile.new(), false)
	var shown: Dictionary = {}
	hints.hint_shown.connect(func(id: String, text: String) -> void: shown[id] = [text, world.player.distance])
	hints.acknowledge(hints.intro_hints)
	await sim.step_world(world, 12.0)
	for hint: Array in [["wall_fence", 60.0], ["wall_fence_low", 110.0], ["wall_fence_high", 160.0]]:
		var id: String = hint[0]
		check(shown.has(id), "the %s hint shows (%s)" % [id, shown.keys()])
		if shown.has(id):
			var d: float = float(shown[id][1])
			check(is_zero_approx(d), "the band is explained before play (%.1f m)" % d)
			check(not String(shown[id][0]).contains("{"), "its text has the player's keys in (%s)" % shown[id][0])
	await sim.free_world(world)


## Every zone's look (ZoneSkin.wall_fence: the default, or a zone's own), at 3 and 5 lanes, on both walls
## and in every band: built without errors; its field and emitters cover the hitbox, and stay within the
## field's reach of the facade (never out over the outer lane's runner); the field and the glowing
## emitters follow the hazard's state (ON, WARNING and OFF look different, and OFF shows no field).
func _test_skins() -> void:
	var skins: Array[ZoneSkin] = [GreyboxSkin.new()]
	var names: Array[String] = ["grey box"]
	for file: String in DirAccess.get_files_at("res://data/skins"):
		if file.ends_with(".tres"):
			skins.append(load("res://data/skins".path_join(file)) as ZoneSkin)
			names.append(file.get_basename())
	var reach: float = WallFencePlan.reach(tuning)
	for i: int in skins.size():
		for lanes: int in [3, 5]:
			var tag: String = "(%s, %d lanes)" % [names[i], lanes]
			var layout := _layout(lanes, [WallFencePlan.make(1, 20.0, "full", 1.0, 1.2, 0.0), WallFencePlan.make(-1, 30.0, "low", 1.0, 1.2, 0.3),
				WallFencePlan.make(1, 40.0, "high", 1.0, 1.2, 0.6), WallFencePlan.make(-1, 50.0, "full", 1.0, 1.2, 0.0)], 200.0)
			start_error_count()
			var world := Node3D.new()
			tree.root.add_child(world)
			var track := TrackBuilder.new()
			world.add_child(track)
			track.set_layout(layout, tuning, skins[i])
			track.update(0.0, 0.0)
			stop_error_count("building wall fences " + tag)
			var built: Array[Hazard] = track.wall_fence_hazards()
			check(built.size() == 4, "every wall fence is built %s" % tag)
			for h: Hazard in built:
				var side: int = 1 if h.position.x > 0.0 else -1
				var hitbox: AABB = _hitbox(h)
				var visual: AABB = _visual_bounds(h)
				check(visual.grow(0.001).encloses(hitbox), "%s at %.0f m: the look (%s) covers the hitbox (%s) %s" % [
					h.hazard_name, -h.position.z, visual, hitbox, tag])
				var out_to: float = -visual.position.x if side > 0 else visual.end.x
				check(out_to <= reach * 0.5 + 0.25, "%s: the look stays within the field's reach of the facade (%.2f m out) %s" % [
					h.hazard_name, out_to + reach * 0.5, tag])
				var state_visual: HazardStateVisual = null
				for child: Node in h.get_children():
					if child is HazardStateVisual:
						state_visual = child
				check(state_visual != null, "%s has a state visual %s" % [h.hazard_name, tag])
				if state_visual == null:
					continue
				var shown: Array[Material] = []
				for state: Hazard.State in [Hazard.State.ON, Hazard.State.WARNING, Hazard.State.OFF]:
					state_visual.show_state(state)
					shown.append(state_visual.material_of(0))
					check(state_visual.material_of(1) != null, "its glowing emitters follow state %d %s" % [state, tag])
				check(shown[0] != shown[1] and shown[1] != shown[2] and shown[0] != shown[2],
					"the field looks different on, warning and off %s" % tag)
				check(shown[2] is ShaderMaterial and float((shown[2] as ShaderMaterial).get_shader_parameter("intensity")) == 0.0,
					"an off wall fence shows no field %s" % tag)
				var on := shown[0] as ShaderMaterial
				var pink: Variant = on.get_shader_parameter("color") if on != null else null
				check(pink is Color and (pink as Color).r > 0.8 and (pink as Color).b > 0.4 and (pink as Color).g < 0.4,
					"its field is the fence pink (%s) %s" % [pink, tag])
			world.queue_free()
			await tree.process_frame


## A boss fight (BossArena, E5a's The House, E5b's Hostile Takeover) carries wall fences: a lap moved
## along the track keeps them, add_pieces() adds them, and wall_fence_problem() holds them to the rules.
func _test_arena() -> void:
	var src := _layout(3, [WallFencePlan.make(1, 50.0, "high", 1.0, 1.2, 0.3)])
	var moved: LevelLayout = BossArena.shifted(src, 100.0)
	check(moved.wall_fences.size() == 1 and is_equal_approx(float(moved.wall_fences[0]["at"]), 150.0)
		and not is_same(moved.wall_fences[0], src.wall_fences[0]), "a lap moved along carries its wall fences")
	var arena := BossArena.new()
	arena.config = LevelConfig.new()
	arena.config.lane_count = 3
	arena.tuning = tuning
	arena.layout = RunSim.layout(3, 600.0)
	var extra := _layout(3, [WallFencePlan.make(-1, 200.0, "full", 1.0, 1.2, 0.0)], 600.0)
	check(arena.add_pieces(extra) == 1 and arena.layout.wall_fences.size() == 1, "a boss adds wall fences with add_pieces()")
	check(arena.wall_fence_problem(WallFencePlan.make(-1, 210.0, "full", 1.0, 1.2, 0.0)).contains("another"),
		"wall_fence_problem() refuses one too close to another")
	check(arena.wall_fence_problem(WallFencePlan.make(1, 320.0, "low", 1.0, 1.2, 0.0)) == "", "and lets a fair one through")
