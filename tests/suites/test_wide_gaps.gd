extends TestSuite
## Wider gaps (task G7; owner, October 7, 2026, answering open question 352; GDD §9.13 "Holes": "every level has
## a couple of wider gaps. They're uncommon, still jumpable by the player, and wide enough that an Enforcer
## following the player into one is wrecked"; WideGapPlacement, data/tuning/wide_gaps.tres):
## - Every campaign level at 3, 5 and 6 lanes has its LevelConfig.wide_gaps (2) wider gaps, each longer than an
##   Enforcer Truck hops and no longer than a level's longest jump, nothing else at its take-off or landing
##   (LayoutChecks.check_wide_gaps), and a floor route across it from the clear floor before it (FloorRoute: a
##   full jump with margins at both edges); its counts are printed per level.
## - Never in a boss arena, even one that asks for them; a level that asks for none (quick play, the prototype
##   level) draws nothing; a level builds the same on every attempt.
## - Jumpable on real physics with a normal jump (no dash, no pad): at quick play's 18 m/s and at every campaign
##   level's speed, at 3, 5 and 6 lanes, a runner who jumps early, midway or late in its take-off window clears
##   one; one who runs on falls in.
## - An Enforcer Truck following a runner who jumps one is wrecked in it (the player's kill), at 3, 5 and 6
##   lanes, at quick play's speed and at Corporate 2's; it hops a level's ordinary row.
## - Corporate 2 (the Enforcer's first level) at 3, 5 and 6 lanes: the first Enforcer's chase holds a wider gap
##   (prefer_enforcer_chases), and played from the level's start by a scripted runner (god mode, grapples) that
##   lines up in one of its hole lanes and jumps it, the truck following is wrecked in it.

const EnforcerRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const LANES: Array[int] = [3, 5, 6]

var sim: RunSim
var et: EnforcerTruckTuning
var wt: WideGapTuning
var frame: float = 1.0 / 60.0


func run() -> void:
	sim = RunSim.new(tree, tuning)
	et = EnforcerRules.tuning()
	wt = WideGapPlacement.tuning()
	frame = 1.0 / float(Engine.physics_ticks_per_second)
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	_test_tuning()
	_test_campaign(campaign)
	_test_off(campaign)
	await _test_jumps(campaign)
	await _test_enforcer_wrecked(campaign)
	await _test_corporate_2(campaign)


func _test_tuning() -> void:
	check(wt.jump_fraction > et.max_hop_jump_fraction and wt.jump_fraction <= 0.8,
		"a wider gap is more of a jump than an Enforcer Truck hops (%.2f > %.2f) and no more than a level's longest (0.8)"
		% [wt.jump_fraction, et.max_hop_jump_fraction])
	check(wt.spacing_seconds >= 10.0, "wider gaps are uncommon: %.0f s apart at least" % wt.spacing_seconds)


# --- Campaign --------------------------------------------------------------------------------------

func _test_campaign(campaign: Campaign) -> void:
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var line: PackedStringArray = []
		for lanes: int in LANES:
			var config: LevelConfig = campaign.configure(s, lanes)
			var tag: String = "%s at %d lanes" % [s.id, lanes]
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var layout: LevelLayout = gen.layout
			var movement: MovementTuning = config.movement_for(tuning)
			var jump: float = movement.jump_distance(movement.run_speed)
			var rows: Array[Dictionary] = WideGapPlacement.wide_rows(layout, jump, et.max_hop_jump_fraction)
			var result: Dictionary = gen.wide_gap_result
			check(config.wide_gaps == 2 and rows.size() == config.wide_gaps,
				"%s has its %d wider gaps (%d)" % [tag, config.wide_gaps, rows.size()])
			check((result.get("constraints", ["no report"]) as Array).is_empty() and (result.get("rows", []) as Array).size() == rows.size(),
				"%s: the pass placed them all, as it reports (%s)" % [tag, result.get("constraints", "no report")])
			LayoutChecks.check_wide_gaps(self, layout, config, tag)
			var grid := FloorRoute.new(layout, movement)
			var lanes_txt: PackedStringArray = []
			for row: Dictionary in rows:
				var span := Vector2(float(row["start"]), float(row["end"]))
				var zone: Vector2 = WideGapPlacement.zone_of(gen, wt, span)
				var from: float = grid.clear_start(zone.x)
				var route: Dictionary = grid.find(from, zone.y)
				check(bool(route["ok"]), "%s: a floor route crosses the wider gap at %.1f (from %.1f: %s)" % [tag, span.x, from,
					route["reason"]])
				lanes_txt.append("%.0f m %d/%d lanes" % [span.x, (row["lanes"] as Array).size(), lanes])
			line.append("%d lanes: %d rows, %d holes; wider %s (widened %d, added %d, cleared %d taking out %d)" % [lanes,
				GapDensity.rows(layout).size(), layout.gaps.size(), ", ".join(lanes_txt), int(result.get("widened", 0)),
				int(result.get("added", 0)), int(result.get("cleared", 0)), int(result.get("taken_out", 0))])
		print("  %s: %s" % [s.id, "; ".join(line)])


## A boss arena never gets them, even asked; quick play and the prototype level ask for none and draw nothing;
## a level builds the same on every attempt.
func _test_off(campaign: Campaign) -> void:
	for s: CampaignStep in campaign.steps():
		if s.boss == null or s.boss.arena == null:
			continue
		var config: LevelConfig = BossArena.base_config(s.boss)
		config.lane_count = 5
		config.wide_gaps = 2
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		var jump: float = config.movement_for(tuning).jump_distance(config.movement_for(tuning).run_speed)
		check(gen.wide_gap_result.is_empty() and WideGapPlacement.wide_rows(layout, jump, et.max_hop_jump_fraction).is_empty(),
			"%s: no wider gaps in a boss arena, even asked" % config.id)
	var quick := LevelConfig.new()
	var prototype := load("res://data/levels/prototype_level.tres") as LevelConfig
	for config: LevelConfig in [quick, prototype]:
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		var jump: float = config.movement_for(tuning).jump_distance(config.movement_for(tuning).run_speed)
		check(config.wide_gaps == 0 and gen.wide_gap_result.is_empty()
			and WideGapPlacement.wide_rows(layout, jump, et.max_hop_jump_fraction).is_empty(),
			"%s asks for none and draws nothing" % ("quick play" if config == quick else "the prototype level"))
	var c2: LevelConfig = campaign.configure(campaign.step("corporate/2"), 5)
	var a := LevelGenerator.new()
	var first: LevelLayout = a.generate(c2, tuning, LevelGenerator.load_for(c2))
	var b := LevelGenerator.new()
	var again: LevelLayout = b.generate(c2, tuning, LevelGenerator.load_for(c2))
	check(first.to_dict() == again.to_dict() and a.wide_gap_result == b.wide_gap_result,
		"Corporate 2 builds the same wider gaps on every attempt")


# --- Physics ---------------------------------------------------------------------------------------

## Quick play's speed and every campaign level's (each once), at 3, 5 and 6 lanes: a row of the wider length in
## every lane but the last, the runner in the middle lane.
func _test_jumps(campaign: Campaign) -> void:
	var speeds: Array[MovementTuning] = [tuning]
	var seen: Array[float] = [snappedf(tuning.run_speed, 0.01)]
	var configs: Array[LevelConfig] = [LevelConfig.new()]
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var config: LevelConfig = campaign.configure(s, 5)
		var movement: MovementTuning = config.movement_for(tuning)
		if seen.has(snappedf(movement.run_speed, 0.01)):
			continue
		seen.append(snappedf(movement.run_speed, 0.01))
		speeds.append(movement)
		configs.append(config)
	for i: int in speeds.size():
		var movement: MovementTuning = speeds[i]
		var v: float = movement.run_speed
		var jump: float = movement.jump_distance(v)
		var length: float = minf(wt.jump_fraction, configs[i].max_gap_jump_fraction) * jump
		for lanes: int in LANES:
			var start: float = 3.0 * v + 20.0
			var end: float = start + length
			var layout := RunSim.layout(lanes, end + 6.0 * v)
			for lane: int in lanes - 1:
				layout.gaps.append({"lane": lane, "start": start, "end": end})
			var tag: String = "(%d lanes, %.1f m/s, %.1f m: %.2f of a jump)" % [lanes, v, length, length / jump]
			var seconds: float = (end + 2.0 * v) / v
			var early: float = end - jump + FloorRoute.LANDING_MARGIN
			var late: float = start - FloorRoute.GAP_MARGIN
			for take_off: float in [early, (early + late) * 0.5, late]:
				var r: Dictionary = await sim.run(layout, lanes / 2, seconds, [[take_off, &"jump"]], [], movement)
				check(bool(r["alive"]) and float(r["distance"]) > end + v,
					"%s a jump %.2f m before its edge clears a wider gap (%s at %.1f m)" % [tag, start - take_off,
					r["cause"], float(r["distance"])])
			var on: Dictionary = await sim.run(layout, lanes / 2, seconds, [], [], movement)
			check(not bool(on["alive"]) and String(on["cause"]) == "fell", "%s running on falls in (%s)" % [tag, on["cause"]])


# --- The Enforcer Truck ------------------------------------------------------------------------------

## The truck (no volleys) chasing a runner who jumps a wider row in its lane is wrecked in it; it hops an
## ordinary row.
func _test_enforcer_wrecked(campaign: Campaign) -> void:
	var c2: LevelConfig = campaign.configure(campaign.step("corporate/2"), 5)
	var paces: Array = [[tuning, 0.0], [c2.movement_for(tuning), c2.enemy_scaling]]
	for lanes: int in LANES:
		for pace: Array in paces:
			var movement: MovementTuning = pace[0]
			var v: float = movement.run_speed
			var jump: float = movement.jump_distance(v)
			var tag: String = "(%d lanes, %.1f m/s)" % [lanes, v]
			for fraction: float in [minf(wt.jump_fraction, c2.max_gap_jump_fraction), 0.5]:
				var start: float = 6.0 * v
				var end: float = start + fraction * jump
				var layout := RunSim.layout(lanes, 1400.0)
				layout.enemies.append({"type": "enforcer_truck", "at": 1.0, "lane": lanes / 2, "side": 0, "seed": 7,
					"params": {}})
				for lane: int in lanes - 1:
					layout.gaps.append({"lane": lane, "start": start, "end": end})
				var r: Dictionary = await _truck_run(layout, pace, start - (1.0 - fraction) * 0.5 * jump, end + 2.0 * v)
				if fraction > et.max_hop_jump_fraction:
					check(String(r["down"]) == "gap" and bool(r["alive"]) and int(r["kill"]) == et.score_value,
						"%s following a runner who jumps a wider gap (%.2f of a jump), it's wrecked in it, the player's kill (%s, %d)"
						% [tag, fraction, r["down"], int(r["kill"])])
				else:
					check(String(r["down"]) == "" and bool(r["alive"]) and int(r["hops"]) == 1,
						"%s it hops an ordinary row (%.2f of a jump) the runner jumps (%s, %d hops)" % [tag, fraction, r["down"],
						int(r["hops"])])


## The truck (no volleys) chasing the runner over `layout`, who keeps to the middle lane and jumps at `jump_at`,
## until they're at `until`. {down (its wreck's cause, "" if none), kill (points for it), alive, hops}.
func _truck_run(layout: LevelLayout, pace: Array, jump_at: float, until: float) -> Dictionary:
	var config := LevelConfig.new()
	config.enemy_scaling = float(pace[1])
	var movement: MovementTuning = pace[0]
	var w: RunWorld = sim.build_world(layout, Loadout.new(), movement, config)
	w.player.armor = 0
	w.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e is EnforcerTruck:
			var truck := e as EnforcerTruck
			truck.tuning = truck.tuning.duplicate() as EnforcerTruckTuning
			truck.tuning.first_volley_seconds = 999.0)
	await tree.physics_frame
	w.player.running = true
	var out := {"down": "", "kill": 0, "alive": true, "hops": 0}
	var truck: EnforcerTruck = null
	var jumped: bool = false
	for i: int in int(30.0 / frame):
		if truck == null:
			truck = _truck(w)
		if not jumped and w.player.distance >= jump_at:
			jumped = true
			w.player.press(&"jump")
		var kills_before: int = int(w.score.bonuses.get(&"kill", 0))
		await tree.physics_frame
		if truck == null:
			continue
		if not is_instance_valid(truck):
			break
		if not truck.alive and String(out["down"]) == "":
			out["down"] = String(truck.history.back()[0]).trim_prefix("wreck:")
			out["kill"] = int(w.score.bonuses.get(&"kill", 0)) - kills_before
			break
		if not w.player.alive or w.player.distance > until:
			break
	out["alive"] = w.player.alive
	if truck != null and is_instance_valid(truck):
		for h: Array in truck.history:
			if String(h[0]) == "hop":
				out["hops"] = int(out["hops"]) + 1
	await sim.free_world(w)
	return out


func _truck(w: RunWorld) -> EnforcerTruck:
	for e: Variant in w.director.active:
		if is_instance_valid(e) and e is EnforcerTruck:
			return e as EnforcerTruck
	return null


## Corporate 2's own build, played from its start (god mode, grapples: the runner keeps to the middle lane and
## takes whatever comes) until the first Enforcer's chase reaches its wider gap: the runner lines up in a hole
## lane of it (the nearest the middle) a few seconds before and jumps it midway through its take-off window; the
## truck following is wrecked in it.
func _test_corporate_2(campaign: Campaign) -> void:
	for lanes: int in LANES:
		var config: LevelConfig = campaign.configure(campaign.step("corporate/2"), lanes)
		config.skin = null  # the grey box: skins never change gameplay
		var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
		var layout: LevelLayout = gen.layout
		var movement: MovementTuning = config.movement_for(tuning)
		var v: float = movement.run_speed
		var jump: float = movement.jump_distance(v)
		var tag: String = "Corporate 2 at %d lanes" % lanes
		var trucks: Array[Dictionary] = EnforcerRules.trucks_in(layout)
		check(not trucks.is_empty(), "%s has an Enforcer Truck" % tag)
		if trucks.is_empty():
			continue
		var at: float = float(trucks[0]["at"])
		var chase := Vector2(at + et.bait_after_seconds * v, at + (et.chase_seconds - WideGapPlacement.CHASE_END_SECONDS) * v)
		var row: Dictionary = {}
		for r: Dictionary in WideGapPlacement.wide_rows(layout, jump, et.max_hop_jump_fraction):
			if float(r["start"]) >= chase.x and float(r["end"]) <= chase.y:
				row = r
				break
		check(not row.is_empty(), "%s: its first Enforcer's chase (%.0f-%.0f m) holds a wider gap" % [tag, chase.x, chase.y])
		if row.is_empty():
			continue
		var middle: int = lanes / 2
		var hole: int = -1
		for lane: int in row["lanes"]:
			if hole < 0 or absi(lane - middle) < absi(hole - middle):
				hole = lane
		var start: float = float(row["start"])
		var end: float = float(row["end"])
		var take_off: float = start - (jump - (end - start)) * 0.5
		var w: RunWorld = sim.build_world(layout, null, null, config)
		w.player.god_mode = true
		w.player.grapples = 1_000_000
		await tree.physics_frame
		w.player.running = true
		var truck: EnforcerTruck = null
		var down: String = ""
		var jumped: bool = false
		var next_step: float = -INF
		var frames_left: int = int((end + 3.0 * v) / v * 2.0 / frame)
		while frames_left > 0 and w.player.distance < end + 3.0 * v:
			frames_left -= 1
			var p: Player = w.player
			var want: int = hole if p.distance >= start - 4.0 * v else middle
			if p.alive and p.running and p.surface == Player.Surface.FLOOR and p.grounded and p.lane != want \
					and w.level_time() >= next_step and p.distance < take_off - 0.25 * v:
				next_step = w.level_time() + 0.3
				p.press(&"move_right" if want > p.lane else &"move_left")
			if not jumped and p.distance >= take_off and p.lane == hole:
				jumped = true
				p.press(&"jump")
			await tree.physics_frame
			if truck == null:
				truck = _truck(w)
			if truck != null and is_instance_valid(truck) and not truck.alive and down == "":
				down = String(truck.history.back()[0]).trim_prefix("wreck:")
				break
		check(jumped and down == "gap",
			"%s: following the runner over the wider gap at %.0f m (lane %d, %.2f of a jump), the truck is wrecked in it (%s)"
			% [tag, start, hole, (end - start) / jump, down if down != "" else ("still chasing" if truck != null else "never came")])
		print("  %s: wider gap at %.0f m in the chase %.0f-%.0f m: the truck %s" % [tag, start, chase.x, chase.y,
			("wrecked: " + down) if down != "" else "not wrecked"])
		await sim.free_world(w)
