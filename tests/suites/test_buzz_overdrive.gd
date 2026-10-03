extends TestSuite
## The Buzz Overdrive (GDD §9.9; task C2), from its numbers and look to the campaign and real physics:
## - Its numbers: health 20, so 22 laser tier 1 shots (G4's two-shot rule) and 15, 10 and 7 at tiers 2-4;
##   the rev (its only scaling) a little shorter level by level from Corporate 1, health the same.
## - Its look: within an enemy's budget, only the blade's teeth and the eyes glow, in hazard colours.
## - Generation: each Buzz Overdrive has its planned cut and stands at its end; the plan's geometry; every
##   campaign level that lists it has some, the same every build; Corporate 1 introduces it soon after
##   its start; quick play with it and every built feature at 3, 5 and 6 lanes passes the fairness
##   checks (LayoutChecks.check_cuts and the rest).
## - On real physics: in the distance, then rolling ahead, its warning (the red line, only from the
##   warning point) before its charge, and only its own lane cut, exactly behind it; a player who leaves
##   at the warning is never touched, at 3, 5 and 6 lanes and at every zone's speed; wall and ceiling
##   riders beside it are safe; a block (armor or shield) holds the floor for about a second and a lane
##   switch escapes; a kill before the charge saves the floor, a kill mid-charge stops the cut there;
##   laser tier 1 never stops it in time and the missile tiers do (measured at every zone's speed); the
##   claws do nothing, the dash smashes it (and only the grapple saves the runner then), and it can't be
##   stomped; it plays the same on every attempt and at 30 and 60 Hz; its rev and charge are a big
##   attack the others wait for.
## - Its data: the hint, its sounds, Reduced flashing, out of the planned features.

const Rules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const TankScript = preload("res://scripts/enemies/buzz_overdrive.gd")
const AttackWatch = preload("res://tools/measure/attack_watch.gd")
const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"
## The zones' run speeds where it appears (data/zones: Corporate, the Dead Zone, the Golden Zone) and
## the enemy scaling of each zone's first level there.
const ZONES: Array = [["corporate", 23.4, 8.0 / 14.0], ["dead_zone", 24.2, 10.0 / 14.0], ["golden", 25.0, 12.0 / 14.0]]
## Its levels and how the campaign introduces it.
const LEVELS: Array[String] = ["corporate/1", "corporate/2", "dead_zone/1", "dead_zone/2", "golden/1", "golden/2", "golden/3"]

var sim: RunSim
var rules: GameRules
var t: BuzzOverdriveTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	rules = load("res://data/tuning/game_rules.tres") as GameRules
	t = Rules.tuning()
	_test_numbers()
	await _test_model()
	_test_plan()
	_test_campaign()
	_test_quick_play()
	await _test_warning_first()
	await _test_sparks_and_reduced_flashing()
	await _test_leave_at_warning()
	await _test_staying_is_hit()
	await _test_wall_and_ceiling()
	await _test_block()
	await _test_kills()
	await _test_weapons()
	await _test_claws_dash_stomp()
	await _test_same_every_attempt()
	await _test_big_attack()
	await _test_attack_watch()
	_test_data()


# --- Helpers -------------------------------------------------------------------------------------

## The movement tuning at run speed `speed` (the suite's own at 0).
func _mt(speed: float = 0.0) -> MovementTuning:
	if speed <= 0.0:
		return tuning
	var out: MovementTuning = tuning.duplicate() as MovementTuning
	out.run_speed = speed
	return out


## A Buzz Overdrive's cut in `lane` that sets off with the player at `anchor`, at `mt`'s speed and pace.
func _cut(lane: int, anchor: float, mt: MovementTuning = null, scaling: float = 8.0 / 14.0) -> Dictionary:
	var m: MovementTuning = mt if mt != null else tuning
	return Rules.plan_for(t, lane, anchor, m.run_speed, m.pace(), scaling)


## A plain track of `lanes` lanes holding `cut` and its Buzz Overdrive at its end.
func _layout(lanes: int, cut: Dictionary, length: float = 900.0) -> LevelLayout:
	var layout := RunSim.layout(lanes, length)
	layout.cuts.append(cut)
	layout.enemies.append({"type": "buzz_overdrive", "at": float(cut["end"]), "lane": int(cut["lane"]), "side": 0,
		"seed": 11, "params": {}})
	return layout


## A full world on `layout` with the player in `lane` at distance `from`.
func _world(layout: LevelLayout, lane: int, from: float, loadout: Loadout = null, mt: MovementTuning = null) -> RunWorld:
	var m: MovementTuning = mt if mt != null else tuning
	var world: RunWorld = sim.build_world(layout, loadout if loadout != null else Loadout.new(), m)
	world.player.setup(m, world.geo, lane)
	world.player.distance = from
	world.track.update(from, 0.0)
	return world


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


## The Buzz Overdrive in play, or null.
func _tank(w: RunWorld) -> Enemy:
	for e: Enemy in w.director.active:
		if is_instance_valid(e) and e.alive and e.type_id == &"buzz_overdrive":
			return e
	return null


func _state(e: Enemy) -> int:
	return int(e.get("state")) if e != null else -1


## Steps the world until `done` holds or `seconds` pass. True if it held.
func _run_until(w: RunWorld, seconds: float, done: Callable) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


## True if a ray down at track distance `d` over lane `lane` meets floor.
func _floor_at(node: Node3D, geo: TrackGeometry, lane: int, d: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(geo.lane_x(lane), 0.5, -d), Vector3(geo.lane_x(lane), -0.5, -d),
		TrackBuilder.LAYER_FLOOR)
	return not node.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## True if every lane but `except` has floor all along [from, to] (sampled every 2 m).
func _others_whole(w: RunWorld, except: int, from: float, to: float) -> bool:
	var ok: bool = true
	for lane: int in w.geo.lane_count:
		if lane == except:
			continue
		var d: float = from + 0.3
		while d < to - 0.3:
			ok = ok and _floor_at(w, w.geo, lane, d)
			d += 2.0
	return ok


# --- Numbers and look ----------------------------------------------------------------------------

func _test_numbers() -> void:
	check(is_equal_approx(t.health_early, 20.0) and is_equal_approx(t.health_late, 20.0),
		"its health is 20 at every point of the campaign (GDD §9.9: it stays at 22 tier 1 shots)")
	var prev: float = INF
	var shorter: bool = true
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var revs: PackedStringArray = []
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or not s.level.has_feature("buzz_overdrive"):
			continue
		var rev: float = t.rev_at(campaign.level_progress(s.level_index))
		shorter = shorter and rev < prev
		prev = rev
		revs.append("%s %.2f s" % [s.id, rev])
	check(shorter and revs.size() == LEVELS.size(), "its rev gets a little shorter level by level (%s)" % ", ".join(revs))
	check(t.rev_at(8.0 / 14.0) >= 2.5 and t.rev_at(1.0) >= 2.0 and t.rev_at(8.0 / 14.0) - t.rev_at(1.0) <= 0.8,
		"it revs for a few seconds, slightly faster by the Golden Zone, never too fast (%.2f s to %.2f s)" % [
		t.rev_at(8.0 / 14.0), t.rev_at(1.0)])
	check(t.hitbox_size.x < tuning.lane_width * 0.4 and t.body_size.x <= tuning.lane_width - 0.15,
		"its blade's hitbox is narrow and its body inside its lane (wall runners beside it are never touched)")
	# Its rev and charge keep their seconds at every zone's speed (G1: distances stretch with the pace).
	var secs: Array[float] = []
	for z: Array in ZONES:
		var m: MovementTuning = _mt(float(z[1]))
		var c: Dictionary = _cut(1, 300.0, m)
		secs.append((FloorCutPlan.charge_at(c) - FloorCutPlan.warn_at(c)) / m.run_speed)
		check(absf((FloorCutPlan.meet(c, m.run_speed) - FloorCutPlan.charge_at(c)) / m.run_speed - t.charge_seconds) < 0.001,
			"its charge reaches the player charge_seconds after it starts at %.1f m/s" % m.run_speed)
	check(absf(secs[0] - t.rev_at(8.0 / 14.0)) < 0.001, "its warning lasts its rev in seconds, whatever the speed")


func _test_model() -> void:
	for variant: StringName in [&"vr_runner", &"burned", &"golden"]:
		var m := BuzzOverdriveModel.new()
		tree.root.add_child(m)
		m.build(variant, t.body_size, t.blade_radius)
		check(m.draw_call_count() <= 8, "%s: a few draw calls (%d)" % [variant, m.draw_call_count()])
		check(m.triangle_count() <= 2400, "%s: %d triangles (within a cyborg's 2,400)" % [variant, m.triangle_count()])
		var faults: PackedStringArray = []
		var glowing: int = 0
		for entry: Dictionary in m.materials():
			var mat := entry["material"] as StandardMaterial3D
			if mat == null:
				continue
			if mat.emission_enabled:
				glowing += 1
				var c: Color = mat.emission
				# Hazard colours only: the blade's hot orange-red and the eyes' red.
				if not (c.r > 0.9 and c.g < 0.4 and c.b < 0.2):
					faults.append("%s glows %s" % [entry["part"], c])
		check(faults.is_empty() and glowing >= 2, "%s: only the blade's teeth and the eyes glow, in hazard colours %s" % [variant, faults])
		m.queue_free()
	await tree.process_frame


# --- Generation ----------------------------------------------------------------------------------

func _test_plan() -> void:
	var m: MovementTuning = _mt(24.2)
	var c: Dictionary = _cut(2, 400.0, m, 0.7)
	var ahead: float = t.charge_distance(m.run_speed, m.pace())
	check(is_equal_approx(FloorCutPlan.lead_at(c), 400.0) and is_equal_approx(float(c["lead"]), t.roll_seconds * m.run_speed),
		"it sets off where its pattern stood it and rolls roll_seconds before its warning")
	check(is_equal_approx(float(c["charge"]), ahead) and is_equal_approx(float(c["warn"]), ahead + t.rev_at(0.7) * m.run_speed),
		"its warning starts a rev before its charge, and it charges from a charge's distance ahead")
	check(FloorCutPlan.lane_window(c).x < FloorCutPlan.warned_lane(c).x and is_equal_approx(FloorCutPlan.attack_window(c, m.run_speed).x,
		FloorCutPlan.warn_at(c)), "its lane is kept from where it sets off; its attack from its warning")
	# Its position as the player runs (keyed to the player's distance).
	var layout := _layout(3, c)
	var gen := LevelGenerator.for_layout(LevelConfig.new(), m, layout)
	check(gen.cut_problem(c) == "", "on a plain track its cut fits (%s)" % gen.cut_problem(c))


func _test_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var first_shares: Array[float] = []
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var listed: bool = s.level.has_feature("buzz_overdrive")
		check(listed == LEVELS.has(String(s.id)), "%s %s the Buzz Overdrive" % [s.id, "lists" if listed else "doesn't list"])
		if not listed:
			continue
		var counts: PackedStringArray = []
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(s, lanes)
			var m: MovementTuning = config.movement_for(tuning)
			# T-SPEED: this level's own default build (LayoutCache), shared with other suites; the
			# "same level every build" check below stays a real, independent second build.
			var layout: LevelLayout = LayoutCache.generate(config, m, LevelGenerator.load_for(config))
			var again: LevelLayout = LevelGenerator.new().generate(config, m, LevelGenerator.load_for(config))
			var tag: String = "(%s, %d lanes)" % [s.id, lanes]
			check(JSON.stringify(layout.to_dict()) == JSON.stringify(again.to_dict()), "the same level every build " + tag)
			var tanks: Array[Dictionary] = Rules.tanks_in(layout)
			var with_cut: bool = true
			for e: Dictionary in tanks:
				var c: Dictionary = Rules.cut_of(layout, e)
				with_cut = with_cut and not c.is_empty() and float(c.get("lead", 0.0)) > 0.0
			check(not tanks.is_empty() and tanks.size() == layout.cuts.size() and with_cut,
				"every Buzz Overdrive stands at its own planned cut's end, and the level has some %s" % tag)
			counts.append("%d lanes: %d" % [lanes, tanks.size()])
			if String(s.id) == "corporate/1":
				var first: float = INF
				for c: Dictionary in layout.cuts:
					first = minf(first, FloorCutPlan.lead_at(c))
				first_shares.append(first / layout.length)
		print("  %s Buzz Overdrives: %s" % [s.id, ", ".join(counts)])
	# Corporate 1 introduces it at 10% of the level: on its own seed, at every lane count, it comes soon.
	var soon: int = 0
	for share: float in first_shares:
		if share < 0.25:
			soon += 1
	check(soon >= 2, "Corporate 1 introduces it soon after its start (first at %s of the level)" % [first_shares])


## Quick play with the Buzz Overdrive and every built feature, busy (the fill pass, doodads), at 3, 5
## and 6 lanes, at a zone's speed: every cut keeps GDD §9.9's limits, every rule holds.
func _test_quick_play() -> void:
	var base := load("res://data/levels/prototype_level.tres") as LevelConfig
	var every := PackedStringArray(["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "hover_truck",
		"octodog", "screech", "drone", "generator", "host", "resonator", "barnacle_turret", "buzz_overdrive"])
	var tanks: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in [1, 2, 3, 4]:
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.level_seed = level_seed
			config.difficulty = 0.6
			config.enemy_scaling = 0.7
			config.features = every
			config.fill_empty_seconds = 2.0
			config.doodad_share = 0.5
			config.run_speed = 24.2
			config.narrow_ceiling_share = 0.5
			var tag: String = "(quick play with every feature, %d lanes, seed %d)" % [lanes, level_seed]
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, config.movement_for(tuning), LevelGenerator.load_for(config))
			check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
			LayoutChecks.check_layout(self, layout, config, tag)
			LayoutChecks.check_rules(self, layout, config, tag)
			tanks += Rules.tanks_in(layout).size()
	check(tanks > 0, "Buzz Overdrives find room among every other feature (%d)" % tanks)


# --- On real physics -----------------------------------------------------------------------------

## GDD §9.9: seen in the distance, then the rev with its warning, then the charge; only its own lane is
## cut, exactly behind it, and nothing before the charge.
func _test_warning_first() -> void:
	var cut: Dictionary = _cut(2, 300.0)
	var w: RunWorld = _world(_layout(5, cut), 0, 300.0 - t.appear_distance)
	w.player.god_mode = true
	var warn_at: float = FloorCutPlan.warn_at(cut)
	var charge_at: float = FloorCutPlan.charge_at(cut)
	# [seen in the distance, line early, whole before the charge, cut behind it, ahead whole, state order ok]
	var ok: Array[bool] = [false, false, true, true, true, true]
	var states: Array[int] = []
	var spots: Array[float] = []
	await _run_until(w, 25.0, func() -> bool:
		var e: Enemy = _tank(w)
		var p: float = w.player.distance
		if e == null:
			return p > FloorCutPlan.window(cut, tuning.run_speed).y
		var s: int = _state(e)
		if states.is_empty() or states[-1] != s:
			states.append(s)
			spots.append(p)
		ok[0] = ok[0] or (e.visible and e.track_distance() - p > 100.0)
		var line := e.find_child("WarningLine", false, false) as MeshInstance3D
		if line.visible and p < warn_at - 0.01:
			ok[1] = true
		var front: float = float(e.get("front"))
		if s != TankScript.State.CHARGE and s != TankScript.State.GONE and p > float(cut["start"]):
			ok[2] = ok[2] and _floor_at(w, w.geo, 2, (float(cut["start"]) + float(cut["end"])) * 0.5)
		if s == TankScript.State.CHARGE:
			if front + 0.06 < float(cut["end"]):
				ok[3] = ok[3] and not _floor_at(w, w.geo, 2, front + 0.06)
			if front - 0.06 > float(cut["start"]):
				ok[4] = ok[4] and _floor_at(w, w.geo, 2, front - 0.06)
		return false)
	var order: Array[int] = [TankScript.State.PARKED, TankScript.State.ROLL, TankScript.State.REV, TankScript.State.CHARGE,
		TankScript.State.GONE]
	ok[5] = states == order and spots[2] >= warn_at - 0.01 and spots[2] < warn_at + 1.0 \
		and spots[3] >= charge_at - 0.01 and spots[3] < charge_at + 1.0 and _tank(w) == null
	check(ok[0], "the player sees it in the distance first")
	check(ok[5], "it parks, rolls, revs at its warning point and charges at its charge point (%s at %s)" % [states, spots])
	check(not ok[1], "its warning line never shows before the warning point")
	check(ok[2], "nothing is cut before its charge")
	check(ok[3] and ok[4], "as it charges the floor behind it is a gap and ahead of it is whole")
	check(_others_whole(w, 2, float(cut["start"]), float(cut["end"]) + 10.0), "only its own lane is cut")
	var fc: FloorCut = w.track.floor_cut(2, float(cut["end"]))
	check(fc != null and fc.done(), "its whole stretch is a gap once it's gone")
	await sim.free_world(w)


## Its sparks come from its own emitter (one per tank, never the shared bursts), only while it cuts; with
## Reduced flashing there are none, and its warning line only widens (no pulse).
func _test_sparks_and_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var cut: Dictionary = _cut(1, 200.0)
		var w: RunWorld = _world(_layout(3, cut), 0, 200.0 - 20.0)
		w.player.god_mode = true
		# [sparks only while charging, sparked at all, line never narrower than the frame before]
		var ok: Array[bool] = [true, false, true]
		var last_width: float = 0.0
		await _run_until(w, 15.0, func() -> bool:
			var e: Enemy = _tank(w)
			if e == null:
				return w.player.distance > FloorCutPlan.window(cut, tuning.run_speed).y
			var sparks := e.find_child("Sparks", false, false) as CPUParticles3D
			var charging: bool = _state(e) == TankScript.State.CHARGE
			ok[0] = ok[0] and sparks != null and (not sparks.emitting or charging)
			ok[1] = ok[1] or (sparks != null and sparks.emitting)
			var line := e.find_child("WarningLine", false, false) as MeshInstance3D
			if _state(e) == TankScript.State.REV and line.visible:
				var width: float = line.global_transform.basis.get_scale().x
				ok[2] = ok[2] and width >= last_width - 0.0001
				last_width = width
			return false)
		var mode: String = "with Reduced flashing" if reduced else "normally"
		check(ok[0], "%s: its sparks fly only while it cuts" % mode)
		check(ok[1] != reduced, "%s: %s" % [mode, "no sparks at all" if reduced else "sparks fly as it cuts"])
		if reduced:
			check(ok[2], "with Reduced flashing its warning line widens without pulsing")
		await sim.free_world(w)
	Settings.flashing_reduced = was


## GDD §9.9: "leave its lane before it arrives". At every zone's speed and 3, 5 and 6 lanes, from the
## middle and an outer lane: a player who switches out half a second into the warning is never touched.
func _test_leave_at_warning() -> void:
	for z: Array in ZONES:
		var m: MovementTuning = _mt(float(z[1]))
		for setup: Array in [[3, 1], [3, 0], [5, 2], [5, 4], [6, 0], [6, 3]]:
			var lanes: int = setup[0]
			var lane: int = setup[1]
			var cut: Dictionary = _cut(lane, 300.0, m, float(z[2]))
			var w: RunWorld = _world(_layout(lanes, cut), lane, FloorCutPlan.lead_at(cut) - 20.0, Loadout.new(), m)
			var move: StringName = &"move_right" if lane < lanes - 1 else &"move_left"
			var react: float = FloorCutPlan.warn_at(cut) + LevelConfig.new().cut_reaction_seconds * m.run_speed
			var r: Dictionary = await sim.step_world(w, (FloorCutPlan.window(cut, m.run_speed).y - w.player.distance) / m.run_speed + 1.0,
				[[react, move]])
			var tag: String = "(%s, %.1f m/s, %d lanes, lane %d)" % [z[0], m.run_speed, lanes, lane]
			check(bool(r["alive"]) and r["cause"] == "" and not r["events"].has(&"armor_hit") and not r["events"].has(&"shield_break"),
				"a player who leaves at the warning is never touched %s" % tag)
			var fc: FloorCut = w.track.floor_cut(lane, float(cut["end"]))
			check(fc != null and fc.done(), "while the cut runs beside them %s" % tag)
			await sim.free_world(w)


func _test_staying_is_hit() -> void:
	var cut: Dictionary = _cut(1, 300.0)
	var w: RunWorld = _world(_layout(3, cut), 1, FloorCutPlan.warn_at(cut) - 10.0)
	var r: Dictionary = await sim.step_world(w, 10.0)
	check(not bool(r["alive"]) and String(r["cause"]).contains("Buzz Overdrive"),
		"a player who stays in its lane is hit by the saw (%s)" % r["cause"])
	await sim.free_world(w)


## GDD §9.9: "It only threatens its own floor lane: wall runners and ceiling runners are safe, even
## beside it."
func _test_wall_and_ceiling() -> void:
	var cut: Dictionary = _cut(0, 300.0)
	var w: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.warn_at(cut) - 10.0)
	var meet: float = FloorCutPlan.meet(cut, tuning.run_speed)
	var on_wall: Array[bool] = [false]
	var passed: Array[bool] = [false]
	await _run_until(w, 10.0, func() -> bool:
		if w.player.distance >= meet - 18.0 and w.player.surface == Player.Surface.FLOOR and not on_wall[0]:
			w.player.press(&"move_left")
			on_wall[0] = true
		var e: Enemy = _tank(w)
		if e != null and e.track_distance() < w.player.distance - 3.0:
			passed[0] = passed[0] or w.player.surface == Player.Surface.WALL
		return passed[0] or not w.player.alive)
	check(passed[0] and w.player.alive, "a wall runner beside it in the outer lane is safe as it passes below")
	await sim.free_world(w)
	var cut2: Dictionary = _cut(1, 300.0)
	var layout := _layout(3, cut2)
	var pad_at: float = FloorCutPlan.warn_at(cut2) - 20.0
	layout.pads.append({"lane": 0, "at": pad_at})
	layout.hulls.append({"start": pad_at - 3.0, "end": FloorCutPlan.lane_window(cut2).y + 25.0})
	var w2: RunWorld = _world(layout, 0, pad_at - 20.0)
	var meet2: float = FloorCutPlan.meet(cut2, tuning.run_speed)
	var r: Dictionary = await sim.step_world(w2, (float(layout.hulls[0]["end"]) + 30.0 - w2.player.distance) / tuning.run_speed,
		[[pad_at + 12.0, &"move_right"]], [meet2])
	var at_meet: Dictionary = r["at"].get(meet2, {})
	check(String(at_meet.get("surface", "")) == "ceiling" and int(at_meet.get("lane", -1)) == 1,
		"a rider is on the ceiling over its lane as it charges beneath (%s)" % at_meet)
	check(bool(r["alive"]) and String(r["surface"]) == "floor", "and is safe, landing past it")
	await sim.free_world(w2)


## GDD §9.9: "The shield and armor block it. After a block, the floor under the player holds for about
## a second, just enough to switch lanes (a jump would land back in the cut lane)."
func _test_block() -> void:
	var hold: float = rules.cut_hold_seconds
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	for plan: String in ["armor", "shield", "switch"]:
		var cut: Dictionary = _cut(1, 300.0)
		var w: RunWorld = _world(_layout(3, cut), 1, FloorCutPlan.warn_at(cut) - 10.0)
		if plan == "shield":
			w.player.shield = 1
		else:
			w.player.armor = 1
		var blocked: Array[float] = [-1.0]
		var fell: Array[float] = [-1.0]
		w.player.movement_event.connect(func(kind: StringName) -> void:
			if (kind == &"armor_break" or kind == &"armor_hit" or kind == &"shield_break") and blocked[0] < 0.0:
				blocked[0] = w.player.elapsed)
		await _run_until(w, 12.0, func() -> bool:
			if blocked[0] >= 0.0 and plan == "switch" and w.player.elapsed >= blocked[0] + hold * 0.5 and w.player.lane == 1:
				w.player.press(&"move_left")
			if blocked[0] >= 0.0 and fell[0] < 0.0 and w.player.h < -0.05:
				fell[0] = w.player.elapsed
			return not w.player.alive or (blocked[0] >= 0.0 and w.player.elapsed > blocked[0] + hold + 1.5))
		var tag: String = "(%s)" % plan
		check(blocked[0] >= 0.0, "the %s blocks the saw %s" % ["shield" if plan == "shield" else "armor", tag])
		if plan == "switch":
			check(w.player.alive and w.player.lane == 0 and fell[0] < 0.0, "a lane switch within the hold escapes " + tag)
		else:
			check(fell[0] >= blocked[0] + hold - dt and fell[0] <= blocked[0] + hold + 0.2 and not w.player.alive,
				"the floor holds for %.1f s after the block, then goes (%.3f s) %s" % [hold, fell[0] - blocked[0], tag])
		await sim.free_world(w)


## GDD §9.9: "Killing it before it charges saves the floor; killing it mid-charge stops the cut where it
## dies."
func _test_kills() -> void:
	for when: int in [TankScript.State.ROLL, TankScript.State.REV]:
		var cut: Dictionary = _cut(1, 300.0)
		var w: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.lead_at(cut) - 20.0)
		w.player.god_mode = true
		await _run_until(w, 12.0, func() -> bool:
			var e: Enemy = _tank(w)
			if e != null and _state(e) == when:
				e.take_damage(1000.0, &"weapon")
				return true
			return false)
		await sim.step_world(w, (FloorCutPlan.window(cut, tuning.run_speed).y - w.player.distance) / tuning.run_speed + 0.5)
		var whole: bool = true
		var d: float = float(cut["start"]) + 0.3
		while d < float(cut["end"]) - 0.3:
			whole = whole and _floor_at(w, w.geo, 1, d)
			d += 1.5
		check(whole and _tank(w) == null, "killed %s, it saves the floor: its lane stays whole" % ["while it rolls", "during its rev"][when - 1])
		await sim.free_world(w)
	var cut2: Dictionary = _cut(1, 300.0)
	var w2: RunWorld = _world(_layout(3, cut2), 0, FloorCutPlan.warn_at(cut2) - 10.0)
	w2.player.god_mode = true
	var mid: float = (float(cut2["end"]) + FloorCutPlan.meet(cut2, tuning.run_speed)) * 0.5
	var died_at: Array[float] = [-1.0]
	await _run_until(w2, 12.0, func() -> bool:
		var e: Enemy = _tank(w2)
		if e != null and _state(e) == TankScript.State.CHARGE and float(e.get("front")) <= mid:
			died_at[0] = float(e.get("front"))
			e.take_damage(1000.0, &"weapon")
			return true
		return false)
	await sim.step_world(w2, 1.0)
	var fc: FloorCut = w2.track.floor_cut(1, float(cut2["end"]))
	check(fc != null and fc.stopped and absf(fc.front - died_at[0]) < 0.001, "killed mid-charge, the cut stops where it dies")
	check(fc != null and _floor_at(w2, w2.geo, 1, fc.front - 0.1) and not _floor_at(w2, w2.geo, 1, fc.front + 0.1),
		"the floor before it stays whole, behind it the gap stays")
	await sim.free_world(w2)


## GDD §9.9: 22 laser tier 1 shots; tuned so laser tier 1 can't stop it in time, but the missile tiers
## usually can. Measured with the real auto-fire, alone on a plain track (a runner in the next lane, so
## nothing else draws fire), at every zone's speed: tier 1 never kills it before it has passed the runner;
## tiers 3 and 4 kill it before it charges (the floor saved), and tier 2 does too.
func _test_weapons() -> void:
	var w0: RunWorld = sim.build_world(_layout(3, _cut(1, 300.0)), _loadout({"weapon": 1}))
	var tank: Enemy = w0.director.spawn({"type": "buzz_overdrive", "at": 400.0, "lane": 1, "seed": 1, "params": {}})
	var c: PowerupController = w0.powerups as PowerupController
	var shots: Array[int] = []
	for tier: int in [1, 2, 3, 4]:
		c.weapon.tier = tier
		var dmg: float = c.weapon.damage(tank)
		shots.append(ceili(tank.max_health / dmg - 0.0001))
	check(shots == [22, 15, 10, 7], "22 laser tier 1 shots, 15, 10 and 7 at tiers 2-4 (%s)" % [shots])
	await sim.free_world(w0)
	for z: Array in ZONES:
		var m: MovementTuning = _mt(float(z[1]))
		for tier: int in [1, 3, 4]:
			var cut: Dictionary = _cut(1, 300.0, m, float(z[2]))
			var w: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.lead_at(cut) - 60.0, _loadout({"weapon": tier}), m)
			w.player.god_mode = true
			var death: Array = [-1, 0.0]
			w.director.enemy_defeated.connect(func(e: Enemy, _cause: StringName) -> void:
				if e.type_id == &"buzz_overdrive":
					death[0] = _state(e)
					death[1] = w.player.distance)
			await _run_until(w, 25.0, func() -> bool:
				return int(death[0]) >= 0 or w.player.distance > FloorCutPlan.window(cut, m.run_speed).y)
			var tag: String = "(%s, %.1f m/s, tier %d)" % [z[0], m.run_speed, tier]
			if tier == 1:
				check(int(death[0]) < 0 or float(death[1]) > FloorCutPlan.meet(cut, m.run_speed),
					"laser tier 1 can't stop it in time %s" % tag)
			else:
				check(int(death[0]) == TankScript.State.ROLL or int(death[0]) == TankScript.State.REV,
					"the missiles stop it before it charges %s (died in state %d)" % [tag, int(death[0])])
			await sim.free_world(w)


## GDD §9.9: claws don't work (claw-immune); the dash smashes it, into the cut lane (only the grapple
## saves the runner); no stomp.
func _test_claws_dash_stomp() -> void:
	# Claws: the saw kills a clawed runner as it would anyone.
	var cut: Dictionary = _cut(1, 300.0)
	var w: RunWorld = _world(_layout(3, cut), 1, FloorCutPlan.warn_at(cut) - 10.0, _loadout({"claws": 1}))
	var r: Dictionary = await sim.step_world(w, 10.0)
	check(not bool(r["alive"]) and String(r["cause"]).contains("Buzz Overdrive"), "the claws don't touch it: the saw wins (%s)" % r["cause"])
	await sim.free_world(w)
	# The rules themselves: no stomp, no claws, the dash.
	var w1: RunWorld = _world(_layout(3, _cut(1, 300.0)), 0, 50.0)
	var e: Enemy = w1.director.spawn({"type": "buzz_overdrive", "at": float(_cut(1, 300.0)["end"]), "lane": 1, "seed": 1, "params": {}})
	var saw: Hazard = null
	for h: Node in e.find_children("*", "", true, false):
		if h is Hazard:
			saw = h as Hazard
	var d := DamageRules.Defense.new()
	check(saw != null and DamageRules.resolve(saw, d, true) == DamageRules.Outcome.KILL, "dropping onto it is no stomp: the blade hurts")
	d.claws = true
	check(DamageRules.resolve(saw, d, true) == DamageRules.Outcome.KILL and DamageRules.resolve(saw, d) == DamageRules.Outcome.KILL,
		"and the claws don't kill it")
	d.dashing = true
	check(DamageRules.resolve(saw, d) == DamageRules.Outcome.DEFEAT_ENEMY, "the dash smashes it")
	check(e.claw_immune and not e.stompable and e.dash_kills, "claw-immune, not stompable, the dash kills it")
	await sim.free_world(w1)
	# The dash into it on real physics: it's smashed, the cut stops, and the runner runs into the gap.
	for grapple: bool in [false, true]:
		var c2: Dictionary = _cut(1, 300.0)
		var items: Dictionary = {"dash": 1}
		if grapple:
			items["grapple"] = 1
		var w2: RunWorld = _world(_layout(3, c2), 1, FloorCutPlan.warn_at(c2) - 10.0, _loadout(items))
		var smashed: Array[String] = [""]
		w2.director.enemy_defeated.connect(func(en: Enemy, cause: StringName) -> void:
			if en.type_id == &"buzz_overdrive":
				smashed[0] = String(cause))
		var pressed: Array[bool] = [false, false]
		await _run_until(w2, 12.0, func() -> bool:
			var tank: Enemy = _tank(w2)
			if tank != null and not pressed[0] and _state(tank) == TankScript.State.CHARGE \
					and tank.track_distance() - w2.player.distance < 14.0:
				(w2.powerups as PowerupController).dash.trigger()
				pressed[0] = true
			if grapple and w2.player.grapples == 0 and not pressed[1]:
				w2.player.press(&"move_left")
				pressed[1] = true
			return not w2.player.alive or w2.player.distance > float(c2["end"]) + 20.0)
		var tag: String = "(with%s the grapple)" % ("" if grapple else "out")
		check(smashed[0] == "dash", "the dash smashes it %s (%s)" % [tag, smashed[0]])
		if grapple:
			check(w2.player.alive, "and the grapple hook saves the runner from the gap it cut " + tag)
		else:
			check(not w2.player.alive, "but the runner dashed into its lane and falls into the gap it cut " + tag)
		await sim.free_world(w2)


## It plays the same on every attempt (keyed to the player's distance) and at 30 and 60 Hz: where its
## blade is at each player distance.
func _test_same_every_attempt() -> void:
	var traces: Array = []
	var ticks: int = Engine.physics_ticks_per_second
	for hz: int in [60, 60, 30]:
		Engine.physics_ticks_per_second = hz
		var cut: Dictionary = _cut(2, 300.0)
		var w: RunWorld = _world(_layout(5, cut), 0, FloorCutPlan.lead_at(cut) - 30.0)
		w.player.god_mode = true
		var trace: Array = []
		var marks: Array[float] = []
		var d: float = FloorCutPlan.lead_at(cut)
		while d < FloorCutPlan.done_at(cut, tuning.run_speed):
			marks.append(d)
			d += 6.0
		await _run_until(w, 25.0, func() -> bool:
			var e: Enemy = _tank(w)
			while not marks.is_empty() and w.player.distance >= marks[0]:
				var p: float = w.player.distance
				marks.pop_front()
				if e != null:
					# Where it should be for exactly this player distance, against where it is.
					trace.append([snappedf(p, 0.01), _state(e), absf(float(e.get("front")) - _expected_front(cut, p)) < 0.001])
			return marks.is_empty() or not w.player.alive)
		traces.append(trace)
		await sim.free_world(w)
	Engine.physics_ticks_per_second = ticks
	var keyed: bool = true
	for trace: Array in traces:
		for row: Array in trace:
			keyed = keyed and bool(row[2])
	check(traces[0] == traces[1] and not traces[0].is_empty(), "the same on every attempt (%d samples)" % traces[0].size())
	check(keyed, "at 30 and 60 Hz alike its blade is where the plan puts it for the player's distance")


func _expected_front(cut: Dictionary, p: float) -> float:
	var ahead: float = float(cut["charge"])
	if p < FloorCutPlan.lead_at(cut):
		return FloorCutPlan.lead_at(cut) + ahead
	if p < FloorCutPlan.charge_at(cut):
		return p + ahead
	return FloorCutPlan.front_at(cut, p, tuning.run_speed)


## GDD §9: its rev and charge are a big attack: on from the warning until it's gone, never before; while
## it's on another type's big attack waits (it never waits itself: its moment was planned).
func _test_big_attack() -> void:
	var cut: Dictionary = _cut(1, 300.0)
	var w: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.lead_at(cut) - 20.0)
	w.player.god_mode = true
	# Another type's enemy far ahead, still in play all the while.
	var other: Enemy = w.director.spawn({"type": "dummy", "script": DUMMY, "at": FloorCutPlan.window(cut, tuning.run_speed).y + 120.0,
		"lane": 2, "seed": 1, "params": {}})
	var ok: Array[bool] = [true, false, true]
	await _run_until(w, 15.0, func() -> bool:
		var e: Enemy = _tank(w)
		if e == null:
			return w.player.distance > FloorCutPlan.lead_at(cut) + 5.0
		var s: int = _state(e)
		var on: bool = e.is_major_attack_active()
		ok[0] = ok[0] and on == (s == TankScript.State.REV or s == TankScript.State.CHARGE)
		if s == TankScript.State.REV and is_instance_valid(other):
			ok[1] = ok[1] or w.director.major_attack_blocked(other)
		if s == TankScript.State.ROLL and is_instance_valid(other):
			ok[2] = ok[2] and not w.director.major_attack_blocked(other)
		return s == TankScript.State.GONE)
	check(ok[0], "its big attack is on exactly while it revs and charges")
	check(ok[1] and ok[2], "another type's big attack waits for it then, not while it only rolls ahead")
	await sim.free_world(w)


## R3's turn-taking tool (tools/measure/attack_watch.gd) reads its state, never is_major_attack_active:
## AttackWatch.open_kinds reports "buzz_charge" exactly while it revs and charges, empty otherwise, and
## AttackWatch.observe() counts exactly one over the whole run.
func _test_attack_watch() -> void:
	var cut: Dictionary = _cut(1, 300.0)
	var w: RunWorld = _world(_layout(3, cut), 0, FloorCutPlan.lead_at(cut) - 20.0)
	w.player.god_mode = true
	var watch := AttackWatch.new(w)
	var open_before: bool = false
	var open_during: bool = true
	var open_after: bool = false
	await _run_until(w, 15.0, func() -> bool:
		watch.observe()
		var e: Enemy = _tank(w)
		if e == null:
			return w.player.distance > FloorCutPlan.lead_at(cut) + 5.0
		var s: int = _state(e)
		var kinds: Array[String] = AttackWatch.open_kinds(e)
		if s == TankScript.State.REV or s == TankScript.State.CHARGE:
			open_during = open_during and kinds == ["buzz_charge"]
		elif s == TankScript.State.PARKED or s == TankScript.State.ROLL:
			open_before = open_before or not kinds.is_empty()
		else:
			open_after = open_after or not kinds.is_empty()
		return false)
	check(not open_before, "AttackWatch sees nothing open before its rev")
	check(open_during, "AttackWatch sees buzz_charge open exactly while it revs and charges")
	check(not open_after, "AttackWatch sees nothing open once it's gone")
	check(int(watch.attacks.get("buzz_charge", 0)) == 1, "AttackWatch counts its one charge (%s)" % watch.attacks)
	await sim.free_world(w)


# --- Data ----------------------------------------------------------------------------------------

func _test_data() -> void:
	check(not LevelConfig.PLANNED_FEATURES.has("buzz_overdrive") and LayoutChecks.known_feature("buzz_overdrive"),
		"it's a built feature now, no longer a planned one")
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var hint: bool = false
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		hint = hint or String(h.get("trigger", "")) == "enemy:buzz_overdrive"
	check(hint, "its first encounter has a hint")
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var rev: AudioStream = library.stream(&"buzz_rev")
	check(rev != null and library.stream(&"buzz_charge") != null and library.stream(&"truck_explode") != null,
		"its warning, its charge and its explosion have sounds")
	# The spin-up stays under the library's 2.5 s (test_units) and plays stretched over the rev by pitch,
	# ending as the charge starts, from Corporate 1's long rev to the Golden Palace's short one.
	var length: float = rev.get_length() if rev != null else 0.0
	var spans: bool = length > 2.0 and length < 2.5
	var pitches: PackedStringArray = []
	for scaling: float in [8.0 / 14.0, 10.0 / 14.0, 12.0 / 14.0, 1.0]:
		var pitch: float = TankScript.rev_pitch(length, t.rev_at(scaling))
		spans = spans and absf(length / pitch - t.rev_at(scaling)) < 0.01 and pitch >= 0.8 and pitch <= 1.0
		pitches.append("%.2f" % pitch)
	check(spans, "its spin-up (%.2f s) lasts its rev at every level, played at a pitch near its own (%s)" % [length,
		", ".join(pitches)])
