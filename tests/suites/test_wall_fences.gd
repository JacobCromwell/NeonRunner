extends TestSuite
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
	check(is_zero_approx(low.x) and low.y < high.x and is_equal_approx(high.y, full.y), "the low band is the bottom of the wall, the high band its top")
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
	for lanes: int in [3, 5]:
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
		check(not r["alive"] and String(r["cause"]).begins_with("wall fence"), "stepping onto the wall into a live one is a hit (%s) %s" % [r["cause"], tag])
		# A wall runner who jumps off before it passes it on the floor.
		r = await sim.run(_layout(lanes, [_live(1, 70.0)]), right, 5.0, _onto_wall(40.0) + [[60.0, &"jump"]], [75.0])
		check(r["alive"] and r["at"][75.0]["surface"] == "floor", "a wall runner who jumps off the wall before it passes it (%s) %s" % [r["cause"], tag])


## GDD §9.1: partial ones are passed by entering the wall high or low. The low band: a runner who jumps
## onto the wall passes above it; one who steps on and has come down by then is hit. The high band: a
## runner who steps on passes below it; one who jumps on is hit.
func _test_partial_bands() -> void:
	for lanes: int in [3, 6]:
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
	check(dropped_hit == 0, "a wall runner who jumps off %.2f s after the warning starts is never hit (%d of %d were)" % [REACTION, dropped_hit, cases])
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
