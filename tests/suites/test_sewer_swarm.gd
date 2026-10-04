extends TestSuite
## The Sewer Swarm, Gangland's boss (GDD §10; task E4): its slot and data, its crowds (MultiMesh plus a
## shader: hundreds of creatures, a few simulated clusters and the Host; crowd sizes in data, smaller on a
## low-end device; nothing per creature on the CPU; no mesh or material made mid-fight, over the whole fight),
## its sounds and hints, its arena (the bait spots: a live fence or a hole in one lane, the street around it
## clear; the host spots: a ramp in an outer lane, the street around it clear) and the fairness of every surge
## on it at 3, 5 and 6 lanes and both speeds (GDD §3: Gangland's 21.8 m/s, quick play's 18): every surge's
## warning is long enough, its bait is in reach from any lane before the lock, and every lane has a way out;
## and the stress scene for the phone test. The fight itself: test_sewer_swarm_fight.gd (phase 1),
## test_sewer_swarm_surrounded.gd (phase 2), test_sewer_swarm_host.gd (phase 3) and test_sewer_swarm_whole.gd.

const BOSS_PATH: String = "res://data/bosses/gangland_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 21.8]
const NEW_SOUNDS: Array[StringName] = [&"swarm_rise", &"swarm_chitter", &"swarm_surge", &"swarm_shock", &"swarm_fall",
	&"swarm_scatter", &"swarm_wave", &"swarm_climb", &"host_burst", &"host_roar", &"host_fling", &"host_crouch",
	&"host_short"]
## A player's reaction to a warning, and the margins a lane switch keeps.
const REACTION: float = 0.35

var sim: RunSim
var slot: BossDef
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	slot = load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Sewer Swarm's fight is built")
		return
	_test_slot()
	_test_tuning()
	_test_crowd_mesh()
	await _test_crowds()
	await _test_arena()
	await _test_stress_scene()


## The fight at `lanes` and `speed` m/s: [world, boss].
func _fight(p_def: BossDef, lanes: int, speed: float = 0.0) -> Array:
	var boss := BossEncounter.create(p_def) as SewerSwarm
	var t: MovementTuning = tuning
	if speed > 0.0 and not is_equal_approx(speed, tuning.run_speed):
		t = tuning.duplicate() as MovementTuning
		t.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


# --- The slot ------------------------------------------------------------------------------------

func _test_slot() -> void:
	check(slot.display_name == "Sewer Swarm" and slot.id == &"gangland_boss", "Gangland's slot is the Sewer Swarm (GDD §10)")
	check(slot.is_built() and slot.scene == "res://scenes/bosses/sewer_swarm.tscn" and slot.preview() == null,
		"its fight is built: the campaign plays it after Gangland 3 (task E4b)")
	var step: CampaignStep = (load("res://data/campaign/campaign.tres") as Campaign).step("gangland/boss")
	check(step != null and step.boss == slot and step.boss.is_built(), "the campaign's Gangland boss step plays it")
	check(slot.two_star_seconds > slot.three_star_seconds and slot.three_star_seconds >= 60.0 and slot.two_star_seconds <= 200.0,
		"its par times: three stars under %.0f s, two under %.0f s" % [slot.three_star_seconds, slot.two_star_seconds])
	check(slot.weapon_share_cap <= 1.0 / 3.0 + 0.01, "weapons can save at most one phase's worth of hits (the framework's cap)")
	var list: Array[BossPhase] = def.phase_list()
	var t := def.tuning as SewerSwarmTuning
	check(list.size() == 3 and list[0].display_name == "Rising" and list[1].display_name == "Surrounded"
		and list[2].display_name == "The Host", "three phases: Rising, Surrounded, The Host (GDD §10)")
	check(t != null and list[0].hits == 2 and list[0].hits + list[1].hits == t.cluster_count,
		"phase 1 ends when two clusters are destroyed, phase 2 when the rest are (%d clusters)" % (t.cluster_count if t else 0))
	check(list[2].hits == 3, "the Host takes three hits (GDD §10: three stomps)")
	check(t.cluster_count >= 4 and t.cluster_count <= 5, "GDD §10: 4-5 clusters (%d)" % t.cluster_count)
	check(def.armor_rule and def.armor_delay_min == 15.0 and def.armor_delay_max == 17.0 and def.armor_pickups_per_phase == 1,
		"the standard armor rule, 15-17 s (GDD §10)")
	check(def.music == &"gangland", "it plays Gangland's own track (no new music)")
	check(def.arena != null and def.arena.skin is GanglandSkin and def.arena.skin.resource_path == "res://data/bosses/gangland_boss_skin.tres"
		and (def.arena.skin as GanglandSkin).enemy_variant == &"scavenger", "its arena is in Gangland's look, a skin of its own")
	check(def.arena.features.is_empty() and def.arena.difficulty_ramp == 0.0, "its arena: the generator's holes and fences, nothing ramping")
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in NEW_SOUNDS:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "its sound %s exists" % sound)
	check(sfx.stream(&"swarm_chitter").get_length() >= t.warning_seconds - 0.05,
		"the rising chitter lasts the whole warning (%.2f s)" % sfx.stream(&"swarm_chitter").get_length())
	check(sfx.stream(&"swarm_wave").get_length() >= t.behind_warning_seconds - 0.2,
		"the wave's chitter lasts its warning (%.2f s)" % sfx.stream(&"swarm_wave").get_length())
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Array = []
	for h: Dictionary in (hints as Dictionary)["hints"]:
		triggers.append(h["trigger"])
	for trigger: String in ["enemy:gangland_boss", "boss:gangland_boss/bait", "boss:gangland_boss/behind",
			"boss:gangland_boss/host"]:
		check(triggers.has(trigger), "a first-time hint for %s" % trigger)


func _test_tuning() -> void:
	var t := def.tuning as SewerSwarmTuning
	check(t.resource_path == "res://data/bosses/gangland_boss_tuning.tres", "its numbers are a tuning of its own (F6)")
	check(t.cluster_health >= 48.0, "clusters take at least a third more weapon damage than the former 36-health tuning")
	check(t.bait_spacing <= 185.0 and t.bait_spacing > 0.0,
		"bait, surge and Host opportunities recur at least 8% more often than the former 200 m spacing")
	check(t.warning_seconds - t.lock_seconds >= 1.3 - 0.001 and t.lock_seconds <= 0.9 + 0.001
		and t.behind_warning_seconds - t.behind_lock_seconds >= 1.4 - 0.001 and t.behind_lock_seconds <= 1.0,
		"less time to dodge a locked attack, without reducing the time to reach its bait")
	check(REACTION + tuning.lane_switch_time + 0.1 <= minf(t.lock_seconds, t.behind_lock_seconds),
		"both shortened locks still allow a reaction, a lane switch and a safety margin")
	check(t.fling_windup + t.fling_flight <= 1.5 + 0.001
		and t.fling_windup + t.fling_flight >= REACTION + tuning.lane_switch_time + 0.1 and t.splat_seconds >= 1.0,
		"the Host's flings arrive sooner and stay dangerous longer, but retain a readable dodge window")
	check(t.climb_seconds / (t.climb_seconds + t.climb_gap_seconds) >= 0.69 and t.climb_gap_seconds >= 1.5,
		"Surrounded takes one wall away more often, still leaving a gap with both free")
	check(t.cluster_size(true) < t.cluster_size(false) and t.horde_size(true) < t.horde_size(false)
		and t.climb_size(true) < t.climb_size(false) and t.spill_size(true) < t.spill_size(false)
		and t.host_size(true) < t.host_size(false),
		"every crowd size is data, and a low-end device draws smaller crowds (clusters %d/%d, horde %d/%d, climb %d/%d, host %d/%d)" % [
		t.cluster_size(false), t.cluster_size(true), t.horde_size(false), t.horde_size(true), t.climb_size(false), t.climb_size(true),
		t.host_size(false), t.host_size(true)])
	check(t.cluster_size(false) >= 100 and t.horde_size(false) >= 200, "it looks like hundreds (GDD §10)")
	check(t.warning_seconds > t.lock_seconds and t.lock_seconds > t.pour_seconds, "the warning, then the pour, then the lock")
	check(t.bait_kind(0) == "fence" and t.bait_kind(1) == "hole", "bait spots take turns: a live fence, then a hole")
	check(t.surge_side(0) == "behind" and t.surge_side(1) == "ahead", "phase 2's surges take turns: from behind, then ahead")
	check(t.behind_warning_seconds > t.behind_lock_seconds and t.behind_charge_speed > MovementTuning.REFERENCE_SPEED * 1.2,
		"a strike from behind warns, locks, then surges on faster than the runner")
	check(t.climb_gap_seconds > 0.0 and t.climb_height > tuning.ramp_entry_height,
		"the climbs leave both walls free between them, and cover a wall above a ramp's wall run")
	# The cluster lands past its bait: a baited one always meets it before the runner does.
	var past: float = t.charge_speed * t.lock_seconds - t.strike_before
	check(past > t.hole_length + 2.0, "a cluster lands %.1f m past its bait spot (beyond a %.1f m hole)" % [past, t.hole_length])
	check(t.hit_width_share < t.mass_width_share and t.hit_height < t.mass_height and t.hit_length_share < 1.0,
		"its hitbox is smaller than its mass (GDD §3: forgiving hitboxes)")


# --- The crowds ----------------------------------------------------------------------------------

func _test_crowd_mesh() -> void:
	var full: ArrayMesh = ScreechModel.mesh()
	var crowd: ArrayMesh = ScreechModel.crowd_mesh()
	check(crowd != null and crowd == ScreechModel.crowd_mesh() and crowd.get_surface_count() == 1,
		"a crowd's screech is one shared mesh, built once")
	var tris_full: int = full.get_faces().size() / 3
	var tris_crowd: int = crowd.get_faces().size() / 3
	check(tris_crowd < tris_full / 2 and tris_crowd <= 130, "a lower-detail screech for crowds (%d triangles, the full one %d)" % [
		tris_crowd, tris_full])
	# The same parts and colours, so the same animation and look apply.
	var parts_full: Dictionary = {}
	var parts_crowd: Dictionary = {}
	for uv: Vector2 in full.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
		parts_full[roundi(uv.x)] = true
	for uv: Vector2 in crowd.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
		parts_crowd[roundi(uv.x)] = true
	check(parts_crowd.keys().size() == parts_full.keys().size(), "with every part of the screech's body (%d)" % parts_crowd.size())
	var glow_tips: int = 0
	for c: Color in crowd.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		if c.a > 0.5:
			glow_tips += 1
	check(glow_tips > 0, "its spine tips and eyes still glow (the deadly parts look deadly)")
	var code: String = SwarmCrowd.SHADER.code
	check(code.contains("kit_flash.gdshaderinc") and code.contains("warning_flicker"),
		"a shock's crackle honours Reduced flashing (warning_flicker: steady with it on)")
	check(code.contains("RENDERER_COMPATIBILITY"), "and its glow keeps its hue on the Compatibility renderer")


func _test_crowds() -> void:
	var made_before: int = SwarmCrowd.made
	var pair: Array = _fight(def, 5)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var t: SewerSwarmTuning = boss.tuning
	var made_at_start: int = SwarmCrowd.made - made_before
	check(boss.clusters.size() == t.cluster_count, "the swarm's %d clusters are in play" % t.cluster_count)
	var simulated: int = 0
	for e: Enemy in world.director.active:
		if e is SwarmCluster or e is SwarmHost:
			simulated += 1
	check(simulated == t.cluster_count + 1, "only the clusters and the Host are simulated: %d entities for hundreds of creatures" % simulated)
	var host: SwarmHost = boss.host
	check(host != null and boss.parts[0] == host and host.shares_health and not host.visible and host.pose == SwarmHost.Pose.HIDDEN,
		"the Host is the boss's body, made with the fight, hidden until phase 3")
	check(host.crowd != null and host.crowd.multimesh.instance_count == t.host_size(false) and host.implants.size() == 3
		and host.person != null and host.person.parts == SwarmHostPerson.parts(),
		"its look: %d screeches latched onto it, the person inside, three implants" % t.host_size(false))
	for c: SwarmCluster in boss.clusters:
		check(c.is_swarm and not c.shares_health and c.is_boss and c.claw_immune and not c.dash_kills and c.is_obstacle,
			"cluster %d: a swarm, health of its own, the boss's (claws never beat it, the dash passes)" % c.index)
		check(c.crowd != null and c.crowd.multimesh.instance_count == t.cluster_size(false) and c.crowd.multimesh.use_custom_data,
			"cluster %d is drawn as one MultiMesh of %d screeches" % [c.index, t.cluster_size(false)])
		var bodies: int = 0
		for node: Node in c.find_children("*", "CollisionObject3D", true, false):
			bodies += 1
		check(bodies == 1 and c.crowd.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"it hurts only through its one hitbox: its creatures have no collision")
		check(c.crowd.get_child_count() == 0, "and no node per creature")
	var horde: int = 0
	for b: SwarmCrowd in boss.horde.bands:
		horde += b.multimesh.instance_count
	check(horde == (t.horde_size(false) / 2) * 2, "the roadside horde: %d screeches in two bands" % horde)
	await _steps(world, 1.0)
	check(boss.horde.lairs.shown_count() > 6 and boss.horde.lairs.manholes.multimesh.instance_count > 0,
		"manholes and vents line both sides (%d in sight), drawn as two MultiMeshes" % boss.horde.lairs.shown_count())
	# The Compatibility renderer multiplies vertex colours (the screech's colours and glow) by the instance
	# colour, zero in a MultiMesh without colours: every MultiMesh of the swarm carries white ones (set where
	# they're made: a headless run's rendering server keeps no instance data to read back).
	var coloured: bool = true
	var meshes: Array[MultiMesh] = [boss.horde.spill.multimesh, boss.horde.lairs.manholes.multimesh,
		boss.horde.lairs.vents.multimesh]
	for b: SwarmCrowd in boss.horde.bands:
		meshes.append(b.multimesh)
	for c: SwarmCluster in boss.clusters:
		meshes.append(c.crowd.multimesh)
	for mm: MultiMesh in meshes:
		coloured = coloured and mm.use_colors
	for path: String in ["res://scripts/bosses/sewer_swarm/swarm_crowd.gd", "res://scripts/bosses/sewer_swarm/swarm_lairs.gd"]:
		coloured = coloured and FileAccess.get_file_as_string(path).contains("set_instance_color(i, Color.WHITE)")
	check(coloured, "its MultiMeshes carry white instance colours (its colours and glow on the Compatibility renderer)")
	# Draws: one a crowd, whatever its size.
	var draws: int = boss.clusters.size() + boss.horde.draw_calls()
	check(draws <= 12, "the swarm draws in %d calls (%d clusters, two bands, the spill, two kinds of lair)" % [draws, boss.clusters.size()])
	# Nothing made once the fight has begun: the whole fight (its surges, climbs and the Host) makes no crowd,
	# mesh or material.
	var made_mid: int = SwarmCrowd.made
	var nodes_mid: int = _meshes_under(boss)
	var bot := SewerSwarmBot.new(boss)
	world.player.god_mode = true
	await _steps(world, 160.0, func() -> void: bot.step(), func() -> bool: return boss.is_defeated())
	check(boss.is_defeated() and boss.destroyed >= t.cluster_count and boss.climb.count >= 2 and boss.host_attacks.stomps >= 1,
		"(the whole fight played: %d clusters destroyed, %d climbs, %d stomps)" % [boss.destroyed, boss.climb.count,
		boss.host_attacks.stomps])
	check(SwarmCrowd.made == made_mid and _meshes_under(boss) == nodes_mid,
		"its crowds and looks are all made before the fight: %d crowds at setup (the clusters' pool, the climb, the Host, the horde), none after" % made_at_start)
	check(made_at_start == boss.crowd_pool_size() + 5, "the pool covers every cluster and flung ball the fight can have (%d)" % boss.crowd_pool_size())
	await sim.free_world(world)
	# A low-end device draws fewer.
	var forced := BossEncounter.create(def) as SewerSwarm
	forced.low_end = true
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = 3
	ctx.tuning = tuning
	var arena: BossArena = forced.plan_arena(ctx)
	var w2: RunWorld = sim.build_world(arena.layout, null, tuning, ctx.config)
	forced.setup(w2, ctx, arena)
	check(forced.clusters[0].crowd.multimesh.instance_count == t.cluster_size(true)
		and forced.horde.bands[0].multimesh.instance_count == t.horde_size(true) / 2,
		"a low-end device's crowds: %d a cluster, %d in the horde" % [t.cluster_size(true), t.horde_size(true)])
	await sim.free_world(w2)


func _steps(world: RunWorld, seconds: float, each: Callable = Callable(), done: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if each.is_valid():
			each.call()
		if done.is_valid() and done.call():
			return
		await tree.physics_frame


## The mesh and MultiMesh nodes under a node (a look made mid-fight would add some).
static func _meshes_under(node: Node) -> int:
	return node.find_children("*", "MeshInstance3D", true, false).size() + node.find_children("*", "MultiMeshInstance3D", true, false).size()


# --- The arena and fairness ------------------------------------------------------------------------

## Every lap's bait spots, at every lane count and both speeds: a live full fence or a hole in one lane, the
## street around it clear in every lane but that one; each surge's warning long enough, its bait in reach
## before the lock from any lane, and a way out of it from every lane.
func _test_arena() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			_arena_at(lanes, speed)


func _arena_at(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var boss := BossEncounter.create(def) as SewerSwarm
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	var arena: BossArena = boss.plan_arena(ctx)
	var st: SewerSwarmTuning = def.tuning as SewerSwarmTuning
	var k: float = t.pace()
	var v: float = t.run_speed
	var span: Vector2 = SewerSwarm.bait_clear_span(st, t)
	var spots: int = 0
	var all_ok: bool = true
	var clear_ok: bool = true
	var reach_ok: bool = true
	var escape_ok: bool = true
	var kinds: Dictionary = {}
	var nothing_else: bool = true
	for li: int in arena.laps.size():
		var lap: LevelLayout = arena.laps[li]
		nothing_else = nothing_else and lap.signs.is_empty() and lap.hulls.is_empty() and lap.pads.is_empty() \
			and lap.ramps.size() == (boss._host_plan.get(li, []) as Array).size() and lap.doodads.is_empty() \
			and lap.enemies.is_empty() and lap.credits.is_empty()
		var plan: Array = boss._spot_plan.get(li, [])
		for s: Dictionary in plan:
			spots += 1
			var at: float = float(s["at"])
			var lane: int = int(s["lane"])
			kinds[s["kind"]] = true
			# The bait itself.
			var found: bool = false
			if s["kind"] == "fence":
				for f: Dictionary in lap.fences:
					found = found or (int(f["lane"]) == lane and is_equal_approx(float(f["at"]), at) and f["variant"] == "full"
						and not bool(f["pulsing"]))
			else:
				for g: Dictionary in lap.gaps:
					found = found or (int(g["lane"]) == lane and is_equal_approx(float(g["start"]), at))
			all_ok = all_ok and found
			# Nothing else in the window, in any lane.
			for g: Dictionary in lap.gaps:
				var mine: bool = s["kind"] == "hole" and int(g["lane"]) == lane and is_equal_approx(float(g["start"]), at)
				if not mine and float(g["start"]) <= at + span.y and float(g["end"]) >= at + span.x:
					clear_ok = false
			for f: Dictionary in lap.fences:
				var mine: bool = s["kind"] == "fence" and int(f["lane"]) == lane and is_equal_approx(float(f["at"]), at)
				if not mine and float(f["at"]) >= at + span.x - 0.5 and float(f["at"]) <= at + span.y + 0.5:
					clear_ok = false
			# Where the runner is when its warning starts, when it locks, and where it would be met.
			var strike: float = at - st.strike_before * k
			var warn: float = strike - v * st.warning_seconds
			var entry: float = strike + st.charge_speed * k * st.lock_seconds
			var lock_d: float = strike - v * st.lock_seconds
			# Reachable: from the furthest lane, a reaction then one switch after another before the lock.
			var farthest: int = maxi(lane, lanes - 1 - lane)
			var need: float = REACTION + farthest * t.lane_switch_time + 0.15
			reach_ok = reach_ok and need <= st.warning_seconds - st.lock_seconds
			# The window holds the whole warning, from a jump before it, and the charge to past its landing.
			clear_ok = clear_ok and at + span.x <= warn - t.jump_distance(v) + 0.01 and at + span.y >= entry + st.mass_length
			# A way out from every lane at the lock: a neighbouring floor lane clear from the lock to past where
			# the cluster lands (not the bait's: it holds the bait), or the wall beside an outer lane (free in phase
			# 1: the arena has no signs). The bait's own lane: a clear neighbour, or jumping its fence or hole.
			for l: int in lanes:
				var ways: int = 0
				for n: int in [l - 1, l + 1]:
					if n >= 0 and n < lanes and _floor_clear(lap, n, lock_d, entry + st.mass_length):
						ways += 1
				if l == 0 or l == lanes - 1:
					ways += 1
				escape_ok = escape_ok and ways >= 1
			# A runner who reacts to the lock clears the lane long before the strike.
			escape_ok = escape_ok and REACTION + t.lane_switch_time + 0.1 <= st.lock_seconds
			# A baited cluster meets its bait before the runner gets there.
			var meet_t: float = (entry - float(s["far"])) / (st.charge_speed * k)
			var runner_at: float = strike - v * (st.lock_seconds - meet_t)
			all_ok = all_ok and runner_at < at - 3.0
	check(spots >= arena.laps.size() * 3, "each lap carries bait spots (%d over %d laps) %s" % [spots, arena.laps.size(), tag])
	check(all_ok and kinds.has("fence") and kinds.has("hole"),
		"each spot is a live full-height fence or a hole in one lane, met by a baited cluster before the runner %s" % tag)
	check(clear_ok, "the street around each spot is clear of every other hole and fence, in every lane, over its whole surge %s" % tag)
	check(reach_ok, "its bait is in reach from any lane before the lock (%.2f s to cross the street) %s" % [
		st.warning_seconds - st.lock_seconds, tag])
	check(escape_ok, "and every lane has a way out of its surge %s" % tag)
	check(nothing_else, "the arena has no signs, ceilings, pads, doodads, enemies or credits, and only its host spots' ramps %s" % tag)
	_host_spots_at(boss, arena, t, tag)
	check(st.warning_seconds >= 2.0 and (st.warning_seconds - st.lock_seconds) >= 1.0,
		"its warning (%.1f s) is as long in seconds at every speed %s" % [st.warning_seconds, tag])
	boss.free()


## Every lap's host spots: a ramp in the outer lane on its side (sides in turn), the street clear in every lane
## around it, the ramp's lane on to where its wall run drops back, and the crouch past the ramp within it.
func _host_spots_at(boss: SewerSwarm, arena: BossArena, t: MovementTuning, tag: String) -> void:
	var st: SewerSwarmTuning = def.tuning as SewerSwarmTuning
	var k: float = t.pace()
	var count: int = 0
	var ok: bool = true
	var interior_ramps: bool = true
	var sides: Dictionary = {}
	var outer: bool = true
	for li: int in arena.laps.size():
		var lap: LevelLayout = arena.laps[li]
		var hosts: Array = boss._host_plan.get(li, [])
		var baits: Array = boss._spot_plan.get(li, [])
		for i: int in maxi(baits.size() - 1, 0):
			var expected: float = float(baits[i]["at"]) + st.host_after * k
			var found_host: bool = false
			for h: Dictionary in hosts:
				found_host = found_host or is_equal_approx(float(h["at"]), expected)
			interior_ramps = interior_ramps and found_host
		count += hosts.size()
		for i: int in hosts.size():
			var h: Dictionary = hosts[i]
			var ramp_at: float = float(h["at"])
			var side: int = int(h["side"])
			sides[side] = true
			outer = outer and int(h["lane"]) == lap.outer_lane(side)
			var found: bool = false
			for r: Dictionary in lap.ramps:
				found = found or (int(r["side"]) == side and is_equal_approx(float(r["at"]), ramp_at))
			ok = ok and found
			var reach: Vector2 = SewerSwarm.host_clear_span(st, t, ramp_at)
			for l: int in lap.lane_count:
				ok = ok and _floor_clear(lap, l, reach.x, minf(reach.y, lap.length))
			ok = ok and _floor_clear(lap, int(h["lane"]), ramp_at, minf(float(h["drop"]), lap.length))
			ok = ok and float(h["from"]) > ramp_at + 6.0 * k and float(h["to"]) < reach.y
			if i > 0:
				ok = ok and int(hosts[i - 1]["side"]) != side
	check(count >= arena.laps.size() * 3 and ok and outer and sides.size() == 2,
		"each lap carries host spots (%d): a ramp in an outer lane, sides in turn, the street clear around it %s" % [count, tag])
	check(interior_ramps, "closer bait spacing never removes an interior Host ramp or its stomp opportunity %s" % tag)


## True if `lane` of a lap has no hole and no fence between two track distances.
static func _floor_clear(lap: LevelLayout, lane: int, from: float, to: float) -> bool:
	for g: Dictionary in lap.gaps:
		if int(g["lane"]) == lane and float(g["start"]) <= to and float(g["end"]) >= from:
			return false
	for f: Dictionary in lap.fences:
		if int(f["lane"]) == lane and float(f["at"]) >= from - 0.5 and float(f["at"]) <= to + 0.5:
			return false
	return true


# --- The stress scene ----------------------------------------------------------------------------

## The phone test's scene (task E3) loads, draws the crowds asked for on the command line's defaults, and
## sizes them by data.
func _test_stress_scene() -> void:
	var scene := load("res://tools/showcase/swarm_stress.tscn") as PackedScene
	check(scene != null, "the stress scene exists (tools/showcase/swarm_stress.tscn)")
	if scene == null:
		return
	var node: Node = scene.instantiate()
	tree.root.add_child(node)
	await tree.process_frame
	await tree.process_frame
	var t := load("res://data/bosses/gangland_boss_tuning.tres") as SewerSwarmTuning
	var crowds: Array = node.get(&"crowds")
	check(crowds.size() == t.cluster_count and (crowds[0] as SwarmCrowd).count == t.cluster_size(false),
		"it draws the tuning's clusters by default (%d of %d)" % [crowds.size(), t.cluster_size(false)])
	node.call(&"_on_slider", "crowd", 300.0)
	crowds = node.get(&"crowds")
	check((crowds[0] as SwarmCrowd).count == 300, "and resizes them live (the slider)")
	node.queue_free()
	await tree.process_frame
