extends TestSuite
## Falling gantryways (task Q3; GDD §5, Zone 9, the owner, October 21, 2026: "an upper walkway over one lane only, looking
## like a ceiling section ... Pillars stand in the floor lanes holding them up. Dashing through a pillar knocks down its
## long section of gantryway. It takes about a second to fall. When it lands, it destroys any enemy in its path. A runner
## under it when it lands is hit; armor and the shield block it, as they block any hit").
## - The layout: a level without gantryways is the same data as before (no "gantryways" key); copy() and append_pieces()
##   carry them, each still naming its own pillar; a gantryway's calm stretch counts as a doodad in its lane for the
##   enemies' and the generator's checks (LevelLayout.doodad_between), and in any lane with -1.
## - The generator (gantryway_rules.gd) over the Ice Lab's levels at 3, 5 and 6 lanes: Frost Foundry introduces them right
##   after their start (within intro_window_seconds), the introduction keeping both lanes beside it clear and a cyborg
##   planted under it; every planted cyborg plain, standing, holding its fire through the calm stretch, under its walkway
##   where it lands; a level without the feature, or with a count of 0, hangs none. (Every build's fairness, the count
##   and the same level twice: test_ice_lab_levels, through LayoutChecks.check_gantryways; quick play's level over seeds
##   and difficulties: test_generator.)
## - The track: a Gantryway over each entry, its walkway hanging at the ceilings' height over its lane, no collision but a
##   hitbox that is off; its pillar a DashBreakable of kind gantry_pillar with a small doodad's body (the doodad and lane
##   blocker layers, its entry as its "doodad"), its look rising to the walkway's underside.
## - The damage rules: the falling walkway is solid, the armor and then the shield absorb it, the dash passes through it,
##   god mode and the invulnerability window ignore it, and a hit of it pays for the whole of it.
## - On real physics at 3, 5 and 6 lanes, in every inner lane, both ways: run into without the dash, the pillar pushes the
##   runner aside and the walkway stays up; dashed through, it falls, and a runner who steps into either lane beside it
##   lives while it lands on the cyborg under it (a kill the score counts); a runner who stays under it is hit (the run
##   ends, "falling gantryway"; a jump or a slide too), the armor or the shield absorbs that and the run goes on, god mode
##   shrugs it off; once down, the runner runs over it unharmed.
## - The warning (CLAUDE.md: seen and heard before it can hurt): the creak as the pillar goes, the shadow on its lane
##   darkening and the lane's red line from then until it lands, its hitbox off for hold_seconds and live only while it
##   drops and as it lands, the crash as it lands; the line pulses, steady with Reduced flashing; the crush: every enemy in
##   its path (a heli drone low over the lane too), none beside it, above it or past its ends.
## - Every skin dresses its walkway, its pillar and its wreck inside their boxes (railings and icicles aside), lit and never
##   glowing, in materials that dissolve near the camera, and names their pieces' colours; the warm-up draws them, with
##   nothing physical in it; every number reaches the F6 panel.

const GantrywayRules := preload("res://scripts/enemies/gantryway_rules.gd")
const DUMMY_SCRIPT: String = "res://tests/helpers/dummy_enemy.gd"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const LANE_COUNTS: Array[int] = [3, 5, 6]
## The pillar's front on the hand-built tracks (metres): past the run's start, where the runner is at full speed.
const PILLAR: float = 90.0
## Seconds of run every physics take is given (to well past the landing).
const RUN_SECONDS: float = 7.5

var gt: GantrywayTuning


func run() -> void:
	gt = GantrywayTuning.load_default()
	_test_layout()
	_test_generator()
	await _test_track()
	_test_damage_rules()
	await _test_physics()
	await _test_warning()
	await _test_crush()
	_test_skins()
	_test_tuning()


# --- The layout ---------------------------------------------------------------------------------

func _test_layout() -> void:
	var bare := LevelLayout.new()
	check(not bare.to_dict().has("gantryways"), "a level without gantryways has no \"gantryways\" key")
	var lay: LevelLayout = _layout(5, 1, -1, true)
	check(lay.to_dict().has("gantryways"), "a level with them lists them")
	var copy: LevelLayout = lay.copy()
	copy.gantryways[0]["fallen"] = true
	check(not lay.gantryways[0].has("fallen") and copy.gantryways.size() == 1 and not copy.pillar_of(copy.gantryways[0]).is_empty(),
		"copy() carries them, its own copy (an attempt's marks stay its own)")
	var more: LevelLayout = _layout(5, 3, 1, false)
	for g: Dictionary in more.gantryways:
		g["start"] = float(g["start"]) + 500.0
		g["end"] = float(g["end"]) + 500.0
	var joined: LevelLayout = lay.copy()
	joined.append_pieces(more)
	check(joined.gantryways.size() == 2 and int(joined.gantryways[1]["id"]) == 1 and not joined.pillar_of(joined.gantryways[1]).is_empty()
		and int(joined.pillar_of(joined.gantryways[1])["lane"]) == 3 and int(joined.pillar_of(joined.gantryways[0])["lane"]) == 1,
		"append_pieces() renumbers the appended ones, each still naming its own pillar")
	var g: Dictionary = lay.gantryways[0]
	var calm: Array = g["calm"]
	var mid: float = (float(calm[0]) + float(calm[1])) * 0.5
	check(lay.doodad_between(mid, mid + 1.0, 1) and lay.doodad_between(mid, mid + 1.0) and not lay.doodad_between(mid, mid + 1.0, 3),
		"its calm stretch counts as a doodad in its lane, and in any lane with -1, never in another lane")
	check(not lay.doodad_between(float(calm[1]) + 1.0, float(calm[1]) + 5.0, 1), "past its calm stretch its lane is free again")
	check(LevelLayout.is_gantry_pillar(lay.pillar_of(g)) and lay.gantryway_by_id(0) == g, "its pillar is marked with its id")


# --- The generator ------------------------------------------------------------------------------

func _test_generator() -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var planted: int = 0
	var hung: int = 0
	for n: int in [1, 2, 3]:
		var step: CampaignStep = campaign.step("ice_lab/%d" % n)
		for lanes: int in LANE_COUNTS:
			var config: LevelConfig = campaign.configure(step, lanes)
			var tag: String = "%s lanes=%d" % [step.id, lanes]
			var patterns: Array = LevelGenerator.load_for(config)
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
			var layout: LevelLayout = gen.layout
			check(layout.gantryways.size() == config.gantryways, "%d of %d gantryways %s" % [layout.gantryways.size(),
				config.gantryways, tag])
			check(GantrywayRules.positions(layout) == LevelGenerator.feature_positions(layout, GantrywayRules.FEATURE),
				"the every-feature check finds them at their pillars " + tag)
			for g: Dictionary in layout.gantryways:
				hung += 1
				var c: Dictionary = GantrywayRules.planted_under(layout, g)
				if c.is_empty():
					continue
				planted += 1
				var params: Dictionary = c["params"]
				check(String(c["type"]) == "cyborg" and int(c["lane"]) == int(g["lane"]) and bool(params["stand"])
					and not bool(params["host"]) and not bool(params["panic"]) and params["hold_fire"] is Vector2,
					"the cyborg under the gantryway at %.0f m is a plain one standing in its lane, holding its fire %s" % [
						float(g["pillar"]), tag])
				var reach: Vector2 = GantrywayRules.plant_range(gen, float(g["pillar"]), float(g["end"]))
				check(float(c["at"]) >= reach.x - 0.01 and float(c["at"]) <= reach.y + 0.01,
					"... where the walkway lands on it before a runner who stays could reach it %s" % tag)
				var hold: Vector2 = params["hold_fire"]
				check(hold.x <= float(g["pillar"]) - gt.hold_before_seconds * gen.speed + 0.01 and hold.y >= float((g["calm"] as Array)[1]) - 0.01,
					"... from before the runner reaches the pillar until its calm stretch is over %s" % tag)
				check(not LevelGenerator.feature_positions(layout, "cyborg").has(float(c["at"])),
					"... and it isn't one of the level's own cyborg encounters %s" % tag)
			if n == 1:
				var first: Dictionary = layout.gantryways[0] if not layout.gantryways.is_empty() else {}
				var start: float = gen.feature_start(GantrywayRules.FEATURE)
				check(not first.is_empty() and bool(first.get("intro", false)) and bool(first.get("both", false))
					and float(first["pillar"]) >= start - 0.01 and float(first["pillar"]) <= start + gt.intro_window_seconds * gen.speed + 0.01
					and not GantrywayRules.planted_under(layout, first).is_empty(),
					"Frost Foundry introduces them within %.1f s of their start (%.0f m), both lanes beside it clear and a cyborg under it (%s) %s"
					% [gt.intro_window_seconds, start, first, tag])
				for g: Dictionary in layout.gantryways:
					check(g == first or float(g["pillar"]) > float(first["pillar"]), "nothing of it before its introduction " + tag)
	check(planted * 10 >= hung * 9, "a cyborg stands under (nearly) every gantryway (%d of %d)" % [planted, hung])
	print("  gantryways in the Ice Lab's own builds: %d, %d with a cyborg under them" % [hung, planted])
	# A level without the feature, or with a count of 0, hangs none.
	var step_2: CampaignStep = campaign.step("ice_lab/2")
	for c: int in 2:
		var config: LevelConfig = campaign.configure(step_2, 5)
		if c == 0:
			var features := PackedStringArray(config.features)
			features.remove_at(features.find(GantrywayRules.FEATURE))
			config.features = features
		else:
			config.gantryways = 0
			config.guarantee_features = false
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		var pillars: int = 0
		for d: Dictionary in layout.doodads:
			pillars += 1 if LevelLayout.is_gantry_pillar(d) else 0
		check(layout.gantryways.is_empty() and pillars == 0 and not layout.to_dict().has("gantryways"),
			"%s hangs none" % ["a level without the feature", "a count of 0"][c])


# --- The track ----------------------------------------------------------------------------------

func _test_track() -> void:
	var sim := RunSim.new(tree, tuning)
	for lanes: int in LANE_COUNTS:
		var lane: int = lanes / 2
		var layout: LevelLayout = _layout(lanes, lane, 1, true)
		var world: RunWorld = sim.build_world(layout)
		world.track.update(PILLAR, 0.0)
		var g: Dictionary = layout.gantryways[0]
		var node: Gantryway = world.track.gantryway_for(g)
		var tag: String = "(lanes=%d)" % lanes
		check(node != null and world.track.gantryway_nodes().size() == 1, "the track builds its gantryway " + tag)
		if node == null:
			await sim.free_world(world)
			continue
		var t: MovementTuning = world.tuning
		check(is_equal_approx(node.hang_y, t.ceiling_height) and node.state == Gantryway.State.STANDING
			and absf(node.look_node().global_position.y - (t.ceiling_height + node.size.y * 0.5)) < 0.01
			and absf(node.look_node().global_position.x - world.geo.lane_x(lane)) < 0.01,
			"its walkway hangs at the ceilings' height over its lane " + tag)
		check(node.size.x < world.geo.lane_width and absf(node.size.z - (float(g["end"]) - float(g["start"]))) < 0.01,
			"its walkway is narrower than its lane and as long as its entry " + tag)
		check(node.hitbox.state == Hazard.State.OFF and node.hitbox.collision_layer == 0 and not node.shadow().visible
			and not node.warning_line().visible and not node.wreck_node().visible,
			"standing, its hitbox is off and no warning shows " + tag)
		var bodies: int = 0
		for o: Node in node.find_children("*", "CollisionObject3D", true, false):
			bodies += 1 if (o as CollisionObject3D).collision_layer != 0 else 0
		check(bodies == 0, "nothing of it collides while it stands (nobody walks on it) " + tag)
		var pillar: DashBreakable = node.pillar
		var box: Vector3 = t.doodad_size(Gantryway.PILLAR_SIZE)
		check(pillar != null and pillar.kind == &"gantry_pillar" and is_same(pillar.entry, layout.pillar_of(g))
			and pillar.collision_layer == TrackBuilder.LAYER_DOODAD | TrackBuilder.LAYER_LANE_BLOCKER
			and pillar.has_meta(&"doodad") and pillar.size.is_equal_approx(Vector3(box.x, box.y, box.z)),
			"its pillar is a DashBreakable with a small doodad's body, pushing like one " + tag)
		if pillar != null:
			var top: float = -INF
			for m: Node in pillar.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				if mi.mesh != null and mi.visible and not mi.is_in_group(&"debug_hitbox"):
					top = maxf(top, (mi.global_transform * mi.get_aabb()).end.y)
			check(absf(top - t.ceiling_height) < 0.05, "its pillar's look rises to the walkway's underside (%.2f m) %s" % [top, tag])
		await sim.free_world(world)


# --- The damage rules ---------------------------------------------------------------------------

func _test_damage_rules() -> void:
	var g := Gantryway.new()
	g.setup({"id": 0, "lane": 1, "start": 10.0, "end": 60.0, "pillar": 10.3, "side": 1, "seed": 0}, gt,
		TrackGeometry.new(3, tuning), tuning)
	var h: Hazard = g.hitbox
	h.set_enabled(true)
	var d := DamageRules.Defense.new()
	check(h.is_solid and DamageRules.resolve(h, d) == DamageRules.Outcome.KILL, "the falling walkway is solid: unprotected, it kills")
	d.armor = true
	check(DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_ARMOR, "the armor absorbs it (GDD §5: \"armor ... block[s] it\")")
	d.armor = false
	d.shield = true
	check(DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_SHIELD, "the shield absorbs it")
	check(DamageRules.lets_through(h, DamageRules.Outcome.BLOCKED_SHIELD) and DamageRules.lets_through(h, DamageRules.Outcome.BLOCKED_ARMOR),
		"a hit of it pays for the whole of it")
	d.shield = false
	d.dashing = true
	check(DamageRules.resolve(h, d) == DamageRules.Outcome.IGNORE, "the dash passes through it, as through every hazard")
	d.dashing = false
	d.god_mode = true
	check(DamageRules.resolve(h, d) == DamageRules.Outcome.IGNORE, "god mode ignores it")
	d.god_mode = false
	d.invulnerable = true
	check(DamageRules.resolve(h, d) == DamageRules.Outcome.IGNORE, "the invulnerability window ignores it")
	h.set_enabled(false)
	check(DamageRules.resolve(h, DamageRules.Defense.new()) == DamageRules.Outcome.IGNORE, "off, it does nothing")
	g.free()


# --- On real physics ----------------------------------------------------------------------------

func _test_physics() -> void:
	var sim := RunSim.new(tree, tuning)
	for lanes: int in LANE_COUNTS:
		for lane: int in range(1, lanes - 1):
			for side: int in [-1, 1]:
				var tag: String = "(lanes=%d lane=%d side=%d)" % [lanes, lane, side]
				# Run into without the dash: pushed aside, the walkway stays up.
				var r: Dictionary = await _take(sim, lanes, lane, side, "push")
				check(bool(r["alive"]) and int(r["lane"]) == lane + side and int(r["pushes"]) == 1 and not bool(r["fell"]),
					"without the dash the pillar pushes the runner into the lane on its side and the walkway stays up %s %s"
					% [_brief(r), tag])
				# Dashed through, stepping out to the pillar's side (or the other, for the introduction).
				for out: int in [side, -side]:
					r = await _take(sim, lanes, lane, side, "out", out)
					check(bool(r["alive"]) and bool(r["landed"]) and int(r["lane"]) == lane + out and int(r["crushed"]) == 1
						and int(r["kills"]) >= 1 and int(r["smashes"]) == 1,
						"dashed through, it falls and lands on the cyborg under it (a kill) while the runner steps out to %d %s %s"
						% [lane + out, _brief(r), tag])
		var lane_mid: int = maxi(lanes / 2, 1)
		var at: String = "(lanes=%d)" % lanes
		# Staying under it.
		var r: Dictionary = await _take(sim, lanes, lane_mid, 1, "stay")
		check(not bool(r["alive"]) and String(r["cause"]) == "falling gantryway" and float(r["hit_after"]) >= gt.hold_seconds(),
			"a runner who stays under it is hit (%.2f s after the pillar breaks, never before it drops) %s %s"
			% [float(r["hit_after"]), _brief(r), at])
		for move: StringName in [&"jump", &"slide"]:
			r = await _take(sim, lanes, lane_mid, 1, "stay", 0, move)
			check(not bool(r["alive"]) and String(r["cause"]) == "falling gantryway",
				"a %s under it doesn't save the runner %s %s" % [move, _brief(r), at])
		r = await _take(sim, lanes, lane_mid, 1, "armor")
		check(bool(r["alive"]) and bool(r["landed"]) and ((r["events"] as Array).has(&"armor_hit") or (r["events"] as Array).has(&"armor_break")),
			"the armor absorbs it, and the run goes on %s %s" % [_brief(r), at])
		r = await _take(sim, lanes, lane_mid, 1, "shield")
		check(bool(r["alive"]) and bool(r["landed"]) and (r["events"] as Array).has(&"shield_break"),
			"the shield absorbs it, and the run goes on %s %s" % [_brief(r), at])
		r = await _take(sim, lanes, lane_mid, 1, "god")
		check(bool(r["alive"]) and bool(r["landed"]), "god mode shrugs it off %s %s" % [_brief(r), at])
		# Once down, the runner runs over it.
		r = await _take(sim, lanes, lane_mid, 1, "back")
		check(bool(r["alive"]) and bool(r["landed"]) and int(r["lane"]) == lane_mid,
			"once down, the runner runs back over it unharmed %s %s" % [_brief(r), at])


## One take on real physics (see _test_physics): a 3-, 5- or 6-lane track with a gantryway over `lane` whose pillar pushes
## to `side`, a cyborg planted under it, the runner coming at the pillar in that lane. `how`: "push" (no dash), "out" (dash,
## then step to `out`), "stay" (dash and stay, no armor; `move` pressed as the walkway drops), "armor", "shield", "god"
## (dash and stay protected), "back" (dash, step out, step back in over the wreck once it has landed).
func _take(sim: RunSim, lanes: int, lane: int, side: int, how: String, out: int = 0, move: StringName = &"") -> Dictionary:
	var layout: LevelLayout = _layout(lanes, lane, side, true)
	var world: RunWorld = sim.build_world(layout)
	world.player.setup(world.tuning, world.geo, lane)
	var p: Player = world.player
	# Unprotected, but for the armor's take: carried and whole.
	p.armor_state.carried = how == "armor"
	p.armor_state.hits = p.armor_state.max_hits if how == "armor" else 0
	if how == "shield":
		p.shield = 1
	if how == "god":
		p.god_mode = true
	var out_r := {"fell": false, "landed": false, "crushed": 0, "fell_at": -1.0, "hit_after": -1.0}
	world.track.gantryway_fell.connect(func(_g: Gantryway) -> void:
		out_r["fell"] = true
		out_r["fell_at"] = p.elapsed)
	world.track.gantryway_landed.connect(func(_g: Gantryway) -> void: out_r["landed"] = true)
	world.director.enemy_defeated.connect(func(_e: Enemy, cause: StringName) -> void:
		out_r["crushed"] = int(out_r["crushed"]) + (1 if cause == Gantryway.CRUSH_CAUSE else 0))
	p.died.connect(func(_cause: String) -> void:
		if float(out_r["fell_at"]) >= 0.0:
			out_r["hit_after"] = p.elapsed - float(out_r["fell_at"]))
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var dash_at: float = PILLAR - 0.5 * pt.dash_duration * (world.tuning.run_speed + pt.dash_speed_bonus)
	var actions: Array = []
	if how != "push":
		actions.append([dash_at, &"dash"])
	var step: StringName = &"move_left" if out < 0 else &"move_right"
	if how == "out" or how == "back":
		if how == "back":
			step = &"move_left" if side < 0 else &"move_right"
		actions.append([PILLAR + 2.0, step])
	if how == "back":
		var fastest: float = GantrywayRules.fastest(LevelGenerator.for_layout(world.config, tuning, layout))
		actions.append([PILLAR + (gt.fall_seconds + 0.3) * fastest, &"move_right" if side < 0 else &"move_left"])
	if move != &"":
		# As it drops: the jump's or the slide's body under it as it comes down.
		var speed: float = world.tuning.run_speed + pt.dash_speed_bonus
		actions.append([PILLAR + (gt.hold_seconds() + gt.drop_seconds() * 0.7) * speed, move])
	var r: Dictionary = await sim.step_world(world, RUN_SECONDS, actions, [], false)
	r.merge(out_r)
	r["pushes"] = p.pushes
	r["smashes"] = p.smashes
	r["kills"] = world.score.kills
	await sim.free_world(world)
	return r


func _brief(r: Dictionary) -> String:
	return "(alive %s, cause '%s', lane %d, fell %s, landed %s, crushed %d)" % [r.get("alive"), r.get("cause", ""), int(r.get("lane", -1)),
		r.get("fell"), r.get("landed"), int(r.get("crushed", 0))]


# --- The warning --------------------------------------------------------------------------------

func _test_warning() -> void:
	var sim := RunSim.new(tree, tuning)
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var layout: LevelLayout = _layout(5, 2, -1, false)
		var world: RunWorld = sim.build_world(layout)
		world.player.setup(world.tuning, world.geo, 2)
		var p: Player = world.player
		p.god_mode = true
		var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
		var dash_at: float = PILLAR - 0.5 * pt.dash_duration * (world.tuning.run_speed + pt.dash_speed_bonus)
		var node: Gantryway = null
		var frames: Array[Dictionary] = []
		await tree.physics_frame
		p.running = true
		var dashed: bool = false
		for i: int in int(RUN_SECONDS * Engine.physics_ticks_per_second):
			if not dashed and p.distance >= dash_at:
				RunSim.act(p, &"dash")
				dashed = true
			await tree.physics_frame
			if node == null:
				node = world.track.gantryway_for(layout.gantryways[0])
			if node != null and node.state != Gantryway.State.STANDING:
				var line: Transform3D = node.warning_line().transform
				frames.append({"t": node.t, "state": node.state, "hit": node.hitbox.state, "layer": node.hitbox.collision_layer,
					"shadow": node.shadow().visible, "dark": node.shadow_darkness(), "line": node.warning_line().visible,
					"width": line.basis.get_scale().x, "under": node.underside_y, "bottom": node.hitbox.bottom_y(),
					"sounds": node.sounds_played.duplicate()})
		var tag: String = "(Reduced flashing %s)" % ("on" if reduced else "off")
		check(not frames.is_empty() and (frames[0]["sounds"] as Array).has(Gantryway.CREAK_SOUND),
			"the creak plays as the pillar goes " + tag)
		var first_live: float = INF
		var lowest_hold: float = INF
		var falling_shown: bool = true
		var darker: bool = true
		var last_dark: float = -1.0
		var widths: Array[float] = []
		for f: Dictionary in frames:
			if int(f["state"]) == Gantryway.State.SHUDDERING or int(f["state"]) == Gantryway.State.DROPPING:
				falling_shown = falling_shown and bool(f["shadow"]) and bool(f["line"])
				darker = darker and float(f["dark"]) >= last_dark - 0.0001
				last_dark = float(f["dark"])
				widths.append(float(f["width"]))
			if int(f["hit"]) == Hazard.State.ON and int(f["layer"]) != 0:
				first_live = minf(first_live, float(f["t"]))
			if int(f["state"]) == Gantryway.State.SHUDDERING:
				lowest_hold = minf(lowest_hold, float(f["under"]))
		check(falling_shown and darker and last_dark > 0.0, "from the pillar breaking until it lands its shadow darkens on its lane and the lane shows red " + tag)
		check(first_live >= gt.hold_seconds() - 0.001, "its hitbox is off while it shudders (live from %.2f s, the hold %.2f s) %s"
			% [first_live, gt.hold_seconds(), tag])
		check(lowest_hold >= world.tuning.ceiling_height - gt.sag - gt.shudder_amplitude - 0.01,
			"it hangs where it was while it shudders, only lurched down by its sag " + tag)
		# The earliest a standing runner's body can meet it: when its hitbox comes down to their head.
		var reach_head: float = INF
		for f: Dictionary in frames:
			if int(f["hit"]) == Hazard.State.ON and float(f["bottom"]) <= world.tuning.hurtbox_size.y:
				reach_head = minf(reach_head, float(f["t"]))
		check(reach_head >= gt.hold_seconds() + 0.3, "a runner standing under it is reached %.2f s after the pillar breaks: time to see, hear and leave %s"
			% [reach_head, tag])
		var landed: Dictionary = frames[-1] if not frames.is_empty() else {}
		check(not landed.is_empty() and int(landed["state"]) == Gantryway.State.LANDED and int(landed["layer"]) == 0
			and int(landed["hit"]) == Hazard.State.OFF and not bool(landed["shadow"]) and not bool(landed["line"])
			and (landed["sounds"] as Array).has(Gantryway.LAND_SOUND) and node.wreck_node().visible and not node.look_node().visible,
			"once down: its hitbox off, its warning gone, its crash played, its wreck shown " + tag)
		var smooth: bool = widths.size() > 2
		for i: int in range(1, widths.size()):
			smooth = smooth and widths[i] >= widths[i - 1] - 0.0001
		if reduced:
			check(smooth, "with Reduced flashing its lane's line never pulses, it only widens " + tag)
		else:
			check(not smooth and widths.size() > 2, "its lane's line pulses as BossProps' lane warnings do " + tag)
		await sim.free_world(world)
	Settings.flashing_reduced = false


# --- The crush ----------------------------------------------------------------------------------

func _test_crush() -> void:
	var sim := RunSim.new(tree, tuning)
	var layout: LevelLayout = _layout(5, 2, -1, false)
	var world: RunWorld = sim.build_world(layout)
	world.player.setup(world.tuning, world.geo, 2)
	world.player.god_mode = true
	var g: Dictionary = layout.gantryways[0]
	var at: float = float(g["start"]) + 30.0
	# Dummies: on the floor under it, a heli drone's height over its lane, in the lane beside it, high above it, past its
	# far end.
	var cases: Array = [["on the floor under it", 2, at, 0.0, true], ["low over its lane (a heli drone)", 2, at + 4.0, 3.2, true],
		["in the lane beside it", 3, at, 0.0, false], ["high above it", 2, at + 8.0, 8.0, false],
		["past its far end", 2, float(g["end"]) + 4.0, 0.0, false]]
	var dummies: Array[Enemy] = []
	for c: Array in cases:
		var e: Enemy = world.director.spawn({"type": "dummy", "script": DUMMY_SCRIPT, "lane": int(c[1]), "at": float(c[2]), "params": {}})
		e.position.y = float(c[3])
		dummies.append(e)
	var crushed: Array = []
	world.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		if cause == Gantryway.CRUSH_CAUSE:
			crushed.append(e))
	var kills_before: int = world.score.kills
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var dash_at: float = PILLAR - 0.5 * pt.dash_duration * (world.tuning.run_speed + pt.dash_speed_bonus)
	await sim.step_world(world, RUN_SECONDS, [[dash_at, &"dash"], [PILLAR + 2.0, &"move_left"]], [], false)
	for i: int in cases.size():
		var c: Array = cases[i]
		check(crushed.has(dummies[i]) == bool(c[4]), "an enemy %s is %scrushed" % [c[0], "" if c[4] else "not "])
	check(world.score.kills - kills_before >= 2, "a crush is the runner's kill, with its score (%d)" % (world.score.kills - kills_before))
	await sim.free_world(world)


# --- Skins, the warm-up and the numbers ---------------------------------------------------------

func _test_skins() -> void:
	var skins: Array[ZoneSkin] = [GreyboxSkin.new()]
	var names: Array[String] = ["grey box"]
	for file: String in DirAccess.get_files_at("res://data/skins"):
		if file.ends_with("_skin.tres"):
			var s := load("res://data/skins".path_join(file)) as ZoneSkin
			if s != null:
				skins.append(s)
				names.append(file)
	var geo := TrackGeometry.new(5, tuning)
	var box: Vector3 = tuning.doodad_size(Gantryway.PILLAR_SIZE)
	for k: int in skins.size():
		var skin: ZoneSkin = skins[k]
		var tag: String = "(%s)" % names[k]
		for look_seed: int in [0, 1, 2, 3]:
			var size := Vector3(geo.lane_width * Gantryway.WIDTH_SHARE, gt.deck_thickness, 40.0 + look_seed * 9.0)
			var walkway := Node3D.new()
			skin.gantryway(walkway, size, look_seed)
			_check_look(walkway, AABB(Vector3(-size.x * 0.5, -size.y * 0.5 - GantrywayKit.ICICLE_MAX, -size.z * 0.5),
				Vector3(size.x, size.y + GantrywayKit.ICICLE_MAX + GantrywayKit.RAIL_HEIGHT + 0.03, size.z)), skin, "its walkway " + tag)
			check(not skin.gantryway_debris_colors(walkway, look_seed).is_empty() and skin.gantryway_snow_colors().size() >= 1,
				"its walkway names the colours its pieces fly in " + tag)
			walkway.free()
			var wreck := Node3D.new()
			var wreck_size := Vector3(size.x, Gantryway.WRECK_HEIGHT, size.z)
			skin.gantryway_wreck(wreck, wreck_size, look_seed)
			_check_look(wreck, AABB(-wreck_size * 0.5, wreck_size), skin, "its wreck " + tag)
			wreck.free()
			for side: int in [-1, 1]:
				var body := Node3D.new()
				var look := Vector3(box.x, tuning.ceiling_height, box.z)
				skin.gantry_pillar(body, look, -box.y * 0.5, side, look_seed)
				_check_look(body, AABB(Vector3(-box.x * 0.5, -box.y * 0.5, -box.z * 0.5), look), skin, "its pillar " + tag)
				check(not skin.gantry_pillar_debris_colors(body, side, look_seed).is_empty(), "its pillar names its pieces' colours " + tag)
				body.free()
	# The warm-up's sample: every part, nothing physical.
	var stage := Node3D.new()
	var sample: Node3D = Gantryway.warm_look(stage, GreyboxSkin.new(), geo, tuning)
	var meshes: int = sample.find_children("*", "MeshInstance3D", true, false).size()
	check(meshes >= 5 and sample.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the warm-up draws its walkway, pillar, wreck, shadow and red line (%d meshes), with nothing that collides" % meshes)
	stage.free()


## Every mesh under `root` lies inside `bounds` (`root`'s space, a centimetre's slack), never glows (every vertex's
## COLOR.a is 0), and draws with the skin's gantryway material (it dissolves near the camera).
func _check_look(root: Node3D, bounds: AABB, skin: ZoneSkin, what: String) -> void:
	var instances: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	check(not instances.is_empty(), "%s has a look" % what)
	var slack: AABB = bounds.grow(0.01)
	for n: Node in instances:
		var mi := n as MeshInstance3D
		var aabb: AABB = mi.transform * mi.mesh.get_aabb()
		check(slack.encloses(aabb), "%s stays inside its box (%s in %s)" % [what, aabb, bounds])
		var glow: bool = false
		for s: int in mi.mesh.get_surface_count():
			var colors: PackedColorArray = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
			for c: Color in colors:
				glow = glow or c.a > 0.0001
		check(not glow, "%s never glows" % what)
		check(mi.material_override == skin.gantryway_material(), "%s draws with the gantryway material" % what)
	var mat := skin.gantryway_material() as ShaderMaterial
	check(mat != null and float(mat.get_shader_parameter(&"near_fade_begin")) < float(mat.get_shader_parameter(&"near_fade_end")),
		"%s's material dissolves near the camera" % what)


## Every number of GantrywayTuning reaches the F6 panel (an @export_range hint).
func _test_tuning() -> void:
	var ranged: bool = true
	var count: int = 0
	for p: Dictionary in gt.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (int(p["usage"]) & PROPERTY_USAGE_EDITOR):
			continue
		if int(p["type"]) == TYPE_FLOAT or int(p["type"]) == TYPE_INT:
			count += 1
			if int(p["hint"]) != PROPERTY_HINT_RANGE:
				ranged = false
				failures.append("GantrywayTuning.%s has no range hint" % p["name"])
	check(ranged and count >= 15, "every number of the gantryways' tuning has a range for the F6 panel (%d)" % count)
	check(gt.hold_seconds() < gt.fall_seconds and gt.drop_seconds() > 0.0, "it shudders, then drops, within its fall")


# --- Helpers ------------------------------------------------------------------------------------

## A hand-built track `lanes` wide with one gantryway over `lane`, its pillar's front at PILLAR pushing to `side`, as its
## rules make one (its walkway, its calm stretch), and with `cyborg` a cyborg planted under it as they plant one.
func _layout(lanes: int, lane: int, side: int, cyborg: bool) -> LevelLayout:
	var layout := RunSim.layout(lanes, 600.0)
	var config := LevelConfig.new()
	config.lane_count = lanes
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var walkway: float = GantrywayRules.walkway_length(gen, gt)
	var calm: float = GantrywayRules.calm_length(gen, gt)
	var start: float = PILLAR - GantrywayRules.NEAR_OVERHANG
	var g := {"id": 0, "lane": lane, "start": start, "end": start + walkway, "pillar": PILLAR, "side": side,
		"calm": [PILLAR, PILLAR + calm], "seed": 7, "intro": true, "both": true}
	layout.gantryways.append(g)
	var box: Vector3 = tuning.doodad_size(Gantryway.PILLAR_SIZE)
	layout.doodads.append({"lane": lane, "start": PILLAR, "end": PILLAR + box.z, "size": Gantryway.PILLAR_SIZE, "side": side,
		"seed": 7, LevelLayout.GANTRY_PILLAR: 0})
	if cyborg:
		var reach: Vector2 = GantrywayRules.plant_range(gen, PILLAR, start + walkway, gt)
		var hold := Vector2(PILLAR - gt.hold_before_seconds * gen.speed, PILLAR + calm)
		layout.enemies.append({"type": "cyborg", "at": reach.x + 1.0, "lane": lane, "side": 0, "seed": 3,
			"params": {"panic": false, "host": false, "stand": true, "hold_fire": hold, GantrywayRules.PARAM: 0}})
	return layout
