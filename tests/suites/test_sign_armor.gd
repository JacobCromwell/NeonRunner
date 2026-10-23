extends TestSuite
## A sign and the armor (task K3, the owner's request): a sign no longer kills a runner whose armor is up. The armor
## takes the hit, as it takes an enemy attack's: the break's feedback, the usual invulnerability window and the
## armor's wait; with no armor and no shield a sign kills as before, and a truck's body still kills through armor.
## - The sign as the track builds it: solid, armor_blocks_solid, passes_after_block, on the hazard and wall blocker
##   layers; nothing else the track builds (a fence, a dash wall) or an enemy's hitboxes lets a runner through after
##   a block. (DamageRules as a pure function is test_damage_rules'.)
## - On real physics at 3, 5 and 6 lanes on both walls, a wall runner running into the longest sign any pattern
##   places: with the free armor up they live, the armor breaks at the sign's face (armor_break, item_used,
##   counted as a blocked hit) with the usual invulnerability window, its wait running from the hit, and they run
##   on along the wall through the sign and out past it, its one contact the hit the armor took; with no armor and
##   no shield the same sign kills ("sign"), at its face.
## - At 3 lanes: an upgraded armor loses one hit and stays up; the shield takes it when the armor is down, and is
##   kept when the armor is up; a ramp's runner into a high sign and a wall runner coming down into a low one from
##   above; a blocked wall entry beside a sign still only bumps (nothing used); the broken armor coming back doesn't
##   stop the next sign; the dash passes a sign with nothing used, and a dash ending inside a long one leaves it to
##   the armor; one hit pays for a sign far longer than the shortest invulnerability window F6 allows (the free
##   armor, an upgrade, the shield), which without passes_after_block would kill (the check has teeth); and a
##   truck's body and an enemy's body still kill a runner whose armor is up (test_hover_truck: the hover truck's
##   spikes).

const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"
## Where the runner steps onto the wall, and where a sign's face is, in the runs below (metres).
const ENTRY: float = 10.0
const SIGN_AT: float = 25.0
## The movement events of a hit armor or the shield took.
const BLOCKS: Array[StringName] = [&"armor_hit", &"armor_break", &"shield_break"]

var sim: RunSim
var rules: GameRules


func run() -> void:
	sim = RunSim.new(tree, tuning)
	rules = load("res://data/tuning/game_rules.tres") as GameRules
	await _test_built()
	await _test_armor_takes_it()
	await _test_protections()
	await _test_heights()
	await _test_bump()
	await _test_next_sign()
	await _test_dash()
	await _test_shortest_window()
	await _test_solids_still_kill()


# --- Helpers -------------------------------------------------------------------------------------

## A sign's layout entry on wall `side`, over [start, end] and [bottom, top].
static func _sign(side: int, start: float, end: float, bottom: float, top: float) -> Dictionary:
	return {"side": side, "start": start, "end": end, "bottom": bottom, "top": top}


## Every sign the patterns place (LevelGenerator.load_for: the prototype patterns and every enemy's file), as
## {length, bottom, top} at the reference speed, with the generator's defaults for what an element leaves out.
static func _pattern_signs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Variant in LevelGenerator.load_for(LevelConfig.new()):
		for e: Variant in (p as Dictionary).get("elements", []):
			var el := e as Dictionary
			if String(el.get("kind", "")) == "sign":
				out.append({"length": float(el.get("length", 8.0)), "bottom": float(el.get("bottom", 0.0)),
					"top": float(el.get("top", 3.0))})
	return out


## The lowest value the F6 panel lets `property` of `res` take: its @export_range hint's first number (NAN if it
## has none).
static func _range_min(res: Resource, property: String) -> float:
	for p: Dictionary in res.get_property_list():
		if String(p["name"]) == property and int(p["hint"]) == PROPERTY_HINT_RANGE:
			return String(p["hint_string"]).get_slice(",", 0).to_float()
	return NAN


## A loadout: "" (nothing), "armor" (the free armor), "upgrade" (the armor's first upgrade tier), "shield" (a shield
## and no armor) or "armor+shield".
static func _loadout(kind: String) -> Loadout:
	var l := Loadout.new()
	l.armor = kind in ["armor", "upgrade", "armor+shield"]
	if kind == "upgrade":
		l.tiers[&"armor"] = 1
	if kind in ["shield", "armor+shield"]:
		l.charges[&"shield"] = 1
	return l


## One frame's run at the reference speed, and a little (metres): how far past a face a contact may come.
func _frame_slack() -> float:
	return tuning.run_speed / float(Engine.physics_ticks_per_second) + 0.05


## A run into signs: a world of `lanes` lanes carrying `loadout`, its runner put in the outer lane by wall `side`
## and stepping onto that wall at ENTRY, `signs` on the walls; `seconds` of it (until a death). `opts`: "rules" (the
## player's GameRules instead of the data's), "entry" (where to step onto the wall; below 0, never), "ramp" (a ramp
## on that wall at this distance), "actions" (more [distance, action] pairs), "setup" (a Callable given the world
## before the run), "probes" (distances to sample). Returns RunSim.step_world's result as "r", and: "hit" (at the
## first block: the runner's distance "d", "surface", "invulnerable" and the level clock "t"), "blocks" (the block
## events in order), "used" (item_used), "contacts" (each sign's contacted count, by its start in whole metres),
## "armor" (hits left), "recharging", "recharge_left", "recharge_time", "shield", "blocked" (the score's blocked
## hits), "elapsed" and "passing" (how many hazards the runner is still going through).
func _run_into(lanes: int, side: int, signs: Array[Dictionary], loadout: Loadout, seconds: float,
		opts: Dictionary = {}) -> Dictionary:
	var layout := RunSim.layout(lanes, 600.0)
	for s: Dictionary in signs:
		layout.signs.append(s)
	if opts.has("ramp"):
		layout.ramps.append({"side": side, "at": float(opts["ramp"])})
	var w: RunWorld = sim.build_world(layout, loadout)
	var p: Player = w.player
	if opts.get("rules") != null:
		p.rules = opts["rules"] as GameRules
	p.setup(w.tuning, w.geo, layout.outer_lane(side))
	var out: Dictionary = {"hit": {}, "blocks": [], "used": [], "contacts": {}}
	var contacts: Dictionary = out["contacts"]
	for n: Node in w.track.find_children("*", "Hazard", true, false):
		var hz := n as Hazard
		if hz.hazard_name != "sign":
			continue
		var start: int = roundi(-hz.global_position.z - hz.size.z * 0.5)
		contacts[start] = 0
		hz.contacted.connect(func(_outcome: int) -> void: contacts[start] = int(contacts[start]) + 1)
	if opts.has("setup"):
		(opts["setup"] as Callable).call(w)
	var hit: Dictionary = out["hit"]
	var blocks: Array = out["blocks"]
	var used: Array = out["used"]
	p.movement_event.connect(func(kind: StringName) -> void:
		if not kind in BLOCKS:
			return
		blocks.append(kind)
		if hit.is_empty():
			hit.merge({"d": p.distance, "surface": p.surface_name(), "invulnerable": p.invulnerable_left, "t": p.elapsed}))
	p.item_used.connect(func(item: StringName) -> void: used.append(item))
	var actions: Array = []
	var entry: float = float(opts.get("entry", ENTRY))
	if entry >= 0.0:
		actions.append([entry, &"move_left" if side < 0 else &"move_right"])
	actions.append_array(opts.get("actions", []))
	actions.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	out["r"] = await sim.step_world(w, seconds, actions, opts.get("probes", []))
	out["armor"] = p.armor
	out["recharging"] = p.armor_state.is_recharging()
	out["recharge_left"] = p.armor_state.recharge_left
	out["recharge_time"] = p.armor_state.recharge_time
	out["shield"] = p.shield
	out["blocked"] = w.score.blocked
	out["elapsed"] = p.elapsed
	out["passing"] = (p.get(&"_passing") as Dictionary).size()
	await sim.free_world(w)
	return out


## What a run (_run_into's result) recorded at probe distance `d`, or {} if it never got there.
static func _at(run: Dictionary, d: float) -> Dictionary:
	return ((run["r"] as Dictionary)["at"] as Dictionary).get(d, {})


## Whether the runner was alive at probe distance `d` of a run (false if they never got there).
static func _alive_at(run: Dictionary, d: float) -> bool:
	return bool(_at(run, d).get("alive", false))


## The total of a run's contacts with its signs (_run_into's "contacts").
static func _contacts(run: Dictionary) -> int:
	var total: int = 0
	var contacts: Dictionary = run["contacts"]
	for start: Variant in contacts:
		total += int(contacts[start])
	return total


## A plain solid hazard in `lane` from `at`, a lane wide and taller than a jump: a truck's body or a boss's block
## (BossProps.block's kind of hazard), which armor never stops.
static func _solid(w: RunWorld, lane: int, at: float, hazard_name: String) -> Hazard:
	var size := Vector3(w.geo.lane_width * 0.8, 3.0, 4.0)
	var hz := Hazard.new()
	hz.hazard_name = hazard_name
	hz.is_solid = true
	hz.size = size
	hz.collision_layer = TrackBuilder.LAYER_HAZARD
	hz.collision_mask = 0
	hz.monitoring = false
	hz.position = Vector3(w.geo.lane_x(lane), size.y * 0.5, TrackGeometry.world_z(at + size.z * 0.5))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	hz.add_child(shape)
	w.add_child(hz)
	return hz


# --- The sign as built ---------------------------------------------------------------------------

## The track builds a sign as a solid hazard armor absorbs and which lets the runner through after a block, on
## the hazard and wall blocker layers; nothing else it builds, nor an enemy's hitboxes, lets a runner through.
func _test_built() -> void:
	var layout := RunSim.layout(5, 400.0)
	layout.signs.append(_sign(1, 40.0, 50.0, 2.8, 5.5))
	layout.signs.append(_sign(-1, 60.0, 68.0, 0.0, 1.4))
	layout.fences.append(RunSim.fence(2, 80.0, "full"))
	layout.dash_walls.append({"start": 100.0, "end": 100.0 + tuning.dash_wall_depth, "seed": 1})
	var w: RunWorld = sim.build_world(layout)
	w.director.spawn({"type": "dummy", "script": DUMMY, "at": 120.0, "lane": 1, "seed": 1})
	var signs: int = 0
	var others: PackedStringArray = []
	for n: Node in w.find_children("*", "Hazard", true, false):
		var hz := n as Hazard
		if hz.hazard_name == "sign":
			signs += 1
			check(hz.is_solid and hz.armor_blocks_solid and hz.passes_after_block and not hz.is_electrical
				and not hz.is_enemy_attack and hz.breakable == null and hz.enemy == null and hz.dash_passes
				and hz.collision_layer == TrackBuilder.LAYER_HAZARD | TrackBuilder.LAYER_WALL_BLOCKER,
				"a sign: solid, armor absorbs it, it lets the runner through after a block, the dash passes it, on the hazard and wall blocker layers")
		else:
			others.append(hz.hazard_name)
			check(not hz.passes_after_block, "nothing else lets a runner through after a block (%s)" % hz.hazard_name)
			if hz.enemy != null and hz.part == &"body":
				check(hz.is_solid and not hz.armor_blocks_solid, "an enemy's body stays a solid hit armor never blocks")
	check(signs == 2 and others.size() >= 4, "(the layout's 2 signs, and a fence, a dash wall and an enemy's hitboxes: %s)" % others)
	await sim.free_world(w)


# --- The armor takes it --------------------------------------------------------------------------

## At 3, 5 and 6 lanes on both walls, a wall runner runs into the longest sign any pattern places (a tall one, as
## the both-walls pattern's): with the free armor up, they live; with nothing up, it kills at its face.
func _test_armor_takes_it() -> void:
	var longest: float = 0.0
	for s: Dictionary in _pattern_signs():
		longest = maxf(longest, float(s["length"]))
	check(longest >= 8.0, "(the longest sign the patterns place: %.1f m)" % longest)
	var hz: float = tuning.hurtbox_size.z * 0.5
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			var tag: String = "(%d lanes, %s wall)" % [lanes, "left" if side < 0 else "right"]
			var s := _sign(side, SIGN_AT, SIGN_AT + longest, 0.0, 5.5)
			var mid: float = SIGN_AT + longest * 0.5
			var past: float = SIGN_AT + longest + 2.0
			var run: Dictionary = await _run_into(lanes, side, [s], _loadout("armor"), 4.0, {"probes": [mid, past]})
			var r: Dictionary = run["r"]
			var hit: Dictionary = run["hit"]
			check(r["alive"] and run["blocks"] == [&"armor_break"] and run["used"] == [&"armor"],
				"with the free armor up, a wall runner who runs into the sign lives: the armor breaks instead (%s, %s) %s"
				% [r["cause"], run["blocks"], tag])
			check(String(hit.get("surface", "")) == "wall" and absf(float(hit.get("d", -100.0)) + hz - SIGN_AT) <= _frame_slack(),
				"the hit comes at the sign's face, on the wall (%s) %s" % [hit, tag])
			check(is_equal_approx(float(hit.get("invulnerable", 0.0)), rules.hit_invulnerability),
				"with the usual invulnerability window (%.2f s) %s" % [float(hit.get("invulnerable", 0.0)), tag])
			var since: float = float(run["elapsed"]) - float(hit.get("t", 0.0))
			check(int(run["armor"]) == 0 and bool(run["recharging"]) and is_equal_approx(float(run["recharge_time"]), rules.armor_recharge)
				and absf(float(run["recharge_left"]) - (rules.armor_recharge - since)) < 0.01,
				"and the armor's wait runs from the hit (%.2f s left, %.2f s on) %s" % [float(run["recharge_left"]), since, tag])
			check(int(run["blocked"]) == 1, "counted as a blocked hit (%d) %s" % [int(run["blocked"]), tag])
			check(String(_at(run, mid).get("surface", "")) == "wall" and _alive_at(run, mid),
				"they run on along the wall through the sign (%s) %s" % [_at(run, mid), tag])
			check(_alive_at(run, past), "and out past it, alive %s" % tag)
			check(_contacts(run) == 1 and int(run["passing"]) == 0,
				"its one contact is the hit the armor took, and clear of it nothing is still being passed (%d, %d) %s"
				% [_contacts(run), int(run["passing"]), tag])
			var bare: Dictionary = await _run_into(lanes, side, [s], _loadout(""), 4.0)
			var b: Dictionary = bare["r"]
			check(not b["alive"] and b["cause"] == "sign" and (bare["used"] as Array).is_empty()
				and absf(float(b["distance"]) + hz - SIGN_AT) <= _frame_slack(),
				"with no armor and no shield the sign kills, at its face (%s at %.2f m) %s" % [b["cause"], float(b["distance"]), tag])


# --- Other protection ----------------------------------------------------------------------------

## An upgraded armor loses one hit and stays up; the shield takes the hit when the armor is down, and is kept
## when the armor is up.
func _test_protections() -> void:
	var s := _sign(1, SIGN_AT, SIGN_AT + 10.0, 0.0, 5.5)
	var past: float = SIGN_AT + 12.0
	var hits: int = rules.armor_hits_at(1)
	var up: Dictionary = await _run_into(3, 1, [s], _loadout("upgrade"), 3.0, {"probes": [past]})
	check(hits >= 2 and up["r"]["alive"] and up["blocks"] == [&"armor_hit"] and int(up["armor"]) == hits - 1
		and bool(up["recharging"]) and (up["used"] as Array).is_empty() and int(up["blocked"]) == 1 and _alive_at(up, past),
		"an upgraded armor (%d hits) takes the sign's hit and stays up, one hit down (%d left, %s), its wait started (GDD §4: any hit)"
		% [hits, int(up["armor"]), up["blocks"]])
	var shield: Dictionary = await _run_into(3, 1, [s], _loadout("shield"), 3.0, {"probes": [past]})
	check(shield["r"]["alive"] and shield["blocks"] == [&"shield_break"] and int(shield["shield"]) == 0
		and shield["used"] == [&"shield"] and _alive_at(shield, past),
		"with no armor the shield takes it, and the runner goes on past the sign (%s)" % [shield["blocks"]])
	var both: Dictionary = await _run_into(3, 1, [s], _loadout("armor+shield"), 3.0)
	check(both["r"]["alive"] and both["blocks"] == [&"armor_break"] and int(both["shield"]) == 1 and int(both["armor"]) == 0,
		"with both, the armor takes it before the shield, which is kept (%s)" % [both["blocks"]])


## A ramp's runner high on the wall runs into a high sign (the sign_high pattern's heights), and a wall runner coming
## down the wall meets a low one (sign_low's heights) from above, inside it: the armor takes either, no armor dies.
func _test_heights() -> void:
	var high := _sign(1, 30.0, 40.0, 2.8, 5.5)
	var opts: Dictionary = {"entry": -1.0, "ramp": 20.0, "probes": [42.0]}
	var ramp: Dictionary = await _run_into(3, 1, [high], _loadout("armor"), 3.0, opts)
	check(ramp["r"]["alive"] and ramp["blocks"] == [&"armor_break"] and String((ramp["hit"] as Dictionary).get("surface", "")) == "wall"
		and _alive_at(ramp, 42.0),
		"a ramp's runner into a high sign: the armor takes it (%s, %s)" % [ramp["r"]["cause"], ramp["blocks"]])
	var bare: Dictionary = await _run_into(3, 1, [high], _loadout(""), 3.0, opts)
	check(not bare["r"]["alive"] and bare["r"]["cause"] == "sign", "and with no armor it kills (%s)" % bare["r"]["cause"])

	var low := _sign(1, SIGN_AT, SIGN_AT + 14.0, 0.0, 1.4)
	var down: Dictionary = await _run_into(3, 1, [low], _loadout("armor"), 3.0, {"probes": [42.0]})
	var d: float = float((down["hit"] as Dictionary).get("d", -1.0))
	check(down["r"]["alive"] and down["blocks"] == [&"armor_break"] and d > SIGN_AT + 1.0 and d < SIGN_AT + 13.0
		and _alive_at(down, 42.0) and _contacts(down) == 1,
		"a wall runner coming down into a low sign from above, inside it (at %.1f m): the armor takes it, once (%s)"
		% [d, down["blocks"]])
	bare = await _run_into(3, 1, [low], _loadout(""), 3.0)
	check(not bare["r"]["alive"] and bare["r"]["cause"] == "sign" and float(bare["r"]["distance"]) > SIGN_AT + 1.0,
		"and with no armor it kills there (%s at %.1f m)" % [bare["r"]["cause"], float(bare["r"]["distance"])])


## A wall entry beside a sign is still only blocked (GDD §3: the clank and the bump), with the armor up: the bump
## stops short of the sign, so it never touches it, and nothing is used.
func _test_bump() -> void:
	var s := _sign(1, SIGN_AT, SIGN_AT + 14.0, 0.0, 5.5)
	var run: Dictionary = await _run_into(3, 1, [s], _loadout("armor"), 2.0, {"entry": SIGN_AT + 4.0})
	var events: Array = run["r"]["events"]
	check(run["r"]["alive"] and events.has(&"wall_blocked") and (run["blocks"] as Array).is_empty() and int(run["armor"]) == 1
		and _contacts(run) == 0 and String(run["r"]["surface"]) == "floor",
		"a wall entry beside a sign clanks and bumps, and the armor is untouched (%s)" % [events])


## The broken armor, coming back, doesn't stop the next sign: the runner who lived through one sign on the armor
## dies at the next, on a second wall run.
func _test_next_sign() -> void:
	var first := _sign(1, SIGN_AT, SIGN_AT + 14.0, 0.0, 5.5)
	var second := _sign(1, 75.0, 83.0, 0.0, 5.5)
	var run: Dictionary = await _run_into(3, 1, [first, second], _loadout("armor"), 6.0, {"actions": [[60.0, &"move_right"]]})
	var r: Dictionary = run["r"]
	check(not r["alive"] and r["cause"] == "sign" and run["blocks"] == [&"armor_break"] and bool(run["recharging"])
		and absf(float(r["distance"]) + tuning.hurtbox_size.z * 0.5 - 75.0) <= _frame_slack(),
		"the armor took the first sign; broken and coming back, it doesn't stop the next (%s at %.1f m, %s)"
		% [r["cause"], float(r["distance"]), run["blocks"]])
	var contacts: Dictionary = run["contacts"]
	check(int(contacts.get(roundi(SIGN_AT), -1)) == 1 and int(contacts.get(75, -1)) == 1,
		"one contact with each sign (%s)" % [contacts])


## The dash passes a sign with nothing used (GDD §8); a dash that ends inside a long one leaves the rest of it to the
## armor, which takes one hit for it, and the runner goes on through.
func _test_dash() -> void:
	var short := _sign(1, SIGN_AT, SIGN_AT + 6.0, 0.0, 5.5)
	var opts: Dictionary = {"actions": [[SIGN_AT - 3.0, &"dash"]], "probes": [SIGN_AT + 8.0]}
	var run: Dictionary = await _run_into(3, 1, [short], _loadout("armor"), 3.0, opts)
	check(run["r"]["alive"] and (run["blocks"] as Array).is_empty() and int(run["armor"]) == 1 and _contacts(run) == 0
		and (run["r"]["events"] as Array).has(&"dash") and _alive_at(run, SIGN_AT + 8.0),
		"the dash passes through a sign: no contact, the armor untouched (%s)" % [run["blocks"]])
	var long := _sign(1, SIGN_AT, SIGN_AT + 20.0, 0.0, 5.5)
	opts = {"actions": [[SIGN_AT - 3.0, &"dash"]], "probes": [SIGN_AT + 22.0]}
	run = await _run_into(3, 1, [long], _loadout("armor"), 3.0, opts)
	var d: float = float((run["hit"] as Dictionary).get("d", -1.0))
	check(run["r"]["alive"] and run["blocks"] == [&"armor_break"] and _contacts(run) == 1 and d > SIGN_AT + 2.0
		and _alive_at(run, SIGN_AT + 22.0),
		"a dash that ends inside a long sign (at %.1f m) leaves it to the armor, which takes it once (%s)" % [d, run["blocks"]])


# --- One hit pays for the whole sign -------------------------------------------------------------

## With the shortest invulnerability window F6 allows, a wall runner runs into a sign many windows long: the free
## armor, an upgraded armor and the shield each take one hit for the whole of it, and the runner goes on through it
## and out past it. Without passes_after_block (switched off on the built sign) the free armor's runner dies
## inside it as the window runs out: the check has teeth.
func _test_shortest_window() -> void:
	var low: float = _range_min(rules, "hit_invulnerability")
	check(low > 0.0 and low < rules.hit_invulnerability, "(F6's shortest invulnerability window: %.2f s)" % low)
	if not (low > 0.0):
		return
	var short := rules.duplicate() as GameRules
	short.hit_invulnerability = low
	var length: float = 30.0
	check(length > tuning.run_speed * low * 4.0, "(the sign takes several windows to pass: %.1f m against %.1f m a window)"
		% [length, tuning.run_speed * low])
	var s := _sign(1, 15.0, 15.0 + length, 0.0, 5.5)
	var past: float = 15.0 + length + 2.0
	for kind: String in ["armor", "upgrade", "shield"]:
		var run: Dictionary = await _run_into(3, 1, [s], _loadout(kind), 4.0, {"rules": short, "probes": [past]})
		var r: Dictionary = run["r"]
		var expected: Array = [&"shield_break"] if kind == "shield" else ([&"armor_hit"] if kind == "upgrade" else [&"armor_break"])
		check(r["alive"] and run["blocks"] == expected and _contacts(run) == 1 and _alive_at(run, past)
			and int(run["blocked"]) == 1 and int(run["passing"]) == 0,
			"%s: one hit pays for a sign %.0f m long with a %.2f s window, and the runner goes on through it (%s, %s, %d contact)"
			% [kind, length, low, r["cause"], run["blocks"], _contacts(run)])
		if kind == "upgrade":
			check(int(run["armor"]) == rules.armor_hits_at(1) - 1, "the upgraded armor lost one hit only (%d left)" % int(run["armor"]))
	var no_pass := func(w: RunWorld) -> void:
		for n: Node in w.track.find_children("*", "Hazard", true, false):
			if (n as Hazard).hazard_name == "sign":
				(n as Hazard).passes_after_block = false
	var teeth: Dictionary = await _run_into(3, 1, [s], _loadout("armor"), 4.0, {"rules": short, "setup": no_pass})
	check(not teeth["r"]["alive"] and teeth["r"]["cause"] == "sign" and _contacts(teeth) == 2,
		"(without passes_after_block that runner dies inside it as the window runs out: %s, %d contacts)"
		% [teeth["r"]["cause"], _contacts(teeth)])


# --- Trucks and bodies ---------------------------------------------------------------------------

## A truck's body (a plain solid, a boss's block's kind) and an enemy's body still kill a runner whose armor is up,
## and the armor is untouched (GDD §8: armor doesn't block solid collisions; signs are the exception).
func _test_solids_still_kill() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 400.0), _loadout("armor"))
	_solid(w, 1, 30.0, "test truck")
	var r: Dictionary = await sim.step_world(w, 3.0)
	check(not r["alive"] and r["cause"] == "test truck" and w.player.armor == 1 and not (r["events"] as Array).has(&"armor_break"),
		"a truck's body still kills a runner whose armor is up, the armor untouched (%s)" % r["cause"])
	await sim.free_world(w)
	w = sim.build_world(RunSim.layout(3, 400.0), _loadout("armor"))
	w.director.spawn({"type": "dummy", "script": DUMMY, "at": 30.0, "lane": 1, "seed": 1})
	r = await sim.step_world(w, 3.0)
	check(not r["alive"] and r["cause"] == "dummy" and w.player.armor == 1, "so does an enemy's body (%s)" % r["cause"])
	await sim.free_world(w)
