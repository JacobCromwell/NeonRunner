extends TestSuite
## The Golden Convergence, the Golden Zone's boss and the final villain (GDD §10; task E5d-a: the golden
## suit, the Grand Court, the entrance, the Helidrone Strafe and the Flying Buttress), its parts one at a
## time:
## - its slot (data/bosses/golden_boss.tres): six phases (stage 1's paces 1, 1.1 and 1.2, stage 2's 1, 1.15
##   and 1.3), the checkpoint at stage 2's first, equal shares, weapons chipping at most one ship's worth,
##   the 22 s armor rule, its payout, score, pars, music, tuning and arena skin; built (E5d-c: the campaign's
##   Golden Zone plays it after Golden 3); its sounds (the warnings never pitch-varied, the whine as long as the
##   warning) and its hints;
## - its tuning's beat scripts, the squadron's size and the lanes each vertical pass covers;
## - the Grand Court at 3, 5 and 6 lanes: plain laps (no holes, fences, pads, doodads, enemies or credits);
##   both walls taken away ahead of the runner (a move past an outer lane bumps them back), a wall opened on
##   request (the runner can run it, is dropped off at its end) and closed again;
## - the golden suit: out of reach (no hitbox, nothing to touch), weapons chip it at its chest within the
##   best weapons' reach, never during its entrance; its look (the calm face with its dull red tear, never
##   glowing; nothing on it glows or passes the hazards' saturation; the cape's shader never glows), its
##   handles (the arms telescoping, the hatches opening, the pipes blown out, the plates bursting) and its
##   draw budget;
## - the entrance: it rises at the far end, the cape unfurls, the chime rings, nothing attacks, then the
##   strafe begins;
## - the squadron: half the lanes rounded up, the heli drone's model never red, never a target;
## - the Flying Buttress: it rises in its lane with its sound, leans toward the nearer edge, its sides bump a
##   lane switch into its lane while a runner in its lane runs through the arch unharmed, and once smashed it
##   crumbles and blocks nothing;
## - Reduced flashing: the squadron's muzzle flashes and tracers steady;
## - stage 2's start: from the checkpoint (phase 4) the transition plays, nothing attacking, and the chase
##   begins (stage 2 itself: test_golden_convergence_magnate.gd);
## - the court's feed screens and their handles.
## The strafes played through (fairness at every lane count and speed, the bot, the wall rule, the pad, the
## hold, determinism): test_golden_convergence_fight.gd.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const NEW_SOUNDS: Array[StringName] = [&"gc_rise", &"gc_chime", &"gc_emerge", &"gc_whine", &"gc_rake", &"gc_sweep",
	&"gc_spark", &"gc_buttress", &"gc_crumble", &"gc_hurl", &"gc_return"]
## Its warnings and cues, each the same every time (no pitch variation).
const WARNINGS: Array[StringName] = [&"gc_whine", &"gc_chime", &"gc_buttress", &"gc_rise", &"gc_emerge"]
## Lit (non-glowing) surfaces stay below this chroma (brightest minus darkest channel; GDD §5, as
## test_golden_skin checks the zone's own colours).
const MAX_SURFACE_CHROMA: float = 0.45
## The suit's draw budget (one giant on screen; measured 17 instances and about 64,000 vertices).
const SUIT_MAX_INSTANCES: int = 30
const SUIT_MAX_VERTICES: int = 90000

var sim: RunSim
var slot: BossDef
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	slot = load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Golden Convergence's fight is built")
		return
	_test_slot()
	_test_tuning()
	for lanes: int in LANES:
		await _test_arena(lanes)
	await _test_court_walls()
	await _test_suit()
	await _test_entrance()
	await _test_squadron()
	await _test_buttress()
	await _test_reduced_flashing()
	await _test_reel()
	await _test_stage_two_start()
	await _test_feed()
	await _test_hud()


## The fight at `lanes` and `speed` m/s: from phase `phase` (a checkpoint's resume), or with `phase` -1 past
## the entrance (phase 1's pattern after its intro); every phase's beat script `beats` if given: [world, boss].
func _fight(lanes: int, speed: float = 18.0, loadout: Loadout = null, phase: int = 0, beats: String = "") -> Array:
	var d: BossDef = def
	if beats != "":
		d = def.duplicate() as BossDef
		var t := (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
		var list := PackedStringArray()
		for i: int in t.phase_beats.size():
			list.append(beats)
		t.phase_beats = list
		d.tuning = t
	var boss := BossEncounter.create(d) as GoldenConvergence
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = d
	ctx.config = BossArena.base_config(d)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	elif phase < 0:
		ctx.boss_resume = {"phase": 0, "time": 0.0}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(boss: BossEncounter, sound_name: StringName) -> int:
	return boss.events.filter(func(e: Dictionary) -> bool: return e["event"] == &"sound" and e["name"] == sound_name).size()


## Steps the fight until `done` holds, the runner dies or `seconds` pass; `each` every frame.
func _run(world: RunWorld, seconds: float, done: Callable = Callable(), each: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if each.is_valid():
			each.call()
		if (done.is_valid() and done.call()) or not world.player.alive:
			return
		await tree.physics_frame


## A colour uniform of `m`: its value on the material, or the default in the shader's code (headless runs
## compile no shaders).
static func _param(m: ShaderMaterial, param: StringName) -> Color:
	if m == null or m.shader == null:
		return Color.RED
	var v: Variant = m.get_shader_parameter(param)
	if v is Color:
		return v
	if v is Vector3:
		return Color((v as Vector3).x, (v as Vector3).y, (v as Vector3).z)
	var re := RegEx.new()
	re.compile("uniform\\s+vec3\\s+%s[^=;]*=\\s*vec3\\(([^)]*)\\)" % param)
	var found: RegExMatch = re.search(m.shader.code)
	if found == null:
		return Color.RED
	var parts: PackedStringArray = found.get_string(1).split(",")
	return Color(float(parts[0]), float(parts[1]), float(parts[2])) if parts.size() == 3 else Color.RED


## Waits until the nodes have drawn a frame (their _process: the suit applies its handles there).
func _drawn() -> void:
	await tree.process_frame
	await tree.process_frame


## Brightest minus darkest channel.
static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


## A saturated red (the hazards' and the enemies' hue).
static func _reddish(c: Color) -> bool:
	return (c.h < 0.06 or c.h > 0.94) and c.s > 0.45 and c.v > 0.3


# --- The slot ------------------------------------------------------------------------------------

func _test_slot() -> void:
	check(slot.id == &"golden_boss" and slot.display_name == "The Golden Convergence",
		"the Golden Zone's slot is The Golden Convergence (GDD §10)")
	check(slot.is_built() and slot.scene == "res://scenes/bosses/golden_convergence.tscn" and slot.preview_scene == ""
		and slot.preview() == null, "the campaign plays the fight in the Golden Zone's boss slot (task E5d-c)")
	check(slot.notes.contains("checkpoint halfway"), "its notes keep the halfway checkpoint")
	var list: Array[BossPhase] = slot.phase_list()
	var paces: Array[float] = []
	var names: Array[String] = []
	var shares_equal: bool = true
	for p: BossPhase in list:
		paces.append(p.pace)
		names.append(p.display_name)
		shares_equal = shares_equal and is_equal_approx(p.health_share, list[0].health_share)
	check(list.size() == 6, "six phases: three of the golden suit, three of The Magnate (%d)" % list.size())
	if list.size() == 6:
		check(is_equal_approx(paces[0], 1.0) and is_equal_approx(paces[1], 1.1) and is_equal_approx(paces[2], 1.2)
			and is_equal_approx(paces[3], 1.0) and is_equal_approx(paces[4], 1.15) and is_equal_approx(paces[5], 1.3),
			"paces 1, 1.1, 1.2 in stage 1 and 1, 1.15, 1.3 in stage 2 (GDD §10, proposed): %s" % [paces])
		check(names[0] == "The Golden Suit" and names[2] == "The Golden Suit" and names[3] == "The Magnate"
			and names[5] == "The Magnate", "stage 1 is the golden suit, stage 2 The Magnate: %s" % [names])
		check(list[3].checkpoint and slot.checkpoint_phase() == 3 and not list[0].checkpoint and not list[4].checkpoint,
			"the fight's checkpoint is halfway, at stage 2's first phase (GDD §10)")
		check(list[0].intro_seconds >= 5.0 and list[1].intro_seconds > 0.0,
			"the first phase's intro has room for the entrance (%.1f s), the later ones for the reel" % list[0].intro_seconds)
	check(shares_equal, "each phase is the same share of its health (a ship a third of the suit's)")
	check(slot.weapon_share_cap > 0.0 and slot.weapon_share_cap <= 1.0 / 6.0 + 0.01 and slot.weapons_can_end_phase,
		"weapons chip it, at most one ship's worth over the fight (%.2f: GDD §10, the Floating Head's rule)" % slot.weapon_share_cap)
	check(slot.armor_rule and is_equal_approx(slot.armor_delay_min, 22.0) and is_equal_approx(slot.armor_delay_max, 22.0)
		and slot.armor_when_unprotected, "the armor rule with the longest delay of any fight, 22 s, once the armor's all gone (GDD §10)")
	check(slot.payout_credits == 1000 and slot.defeat_score == 10000, "1,000 credits and 10,000 points for the win")
	check(slot.three_star_seconds > 0.0 and slot.three_star_seconds < slot.two_star_seconds and slot.two_star_seconds < slot.time_bonus_seconds,
		"pars: %.0f s for three stars, %.0f s for two, a time bonus to %.0f s (from a clean fight: test_golden_convergence_whole)" % [
			slot.three_star_seconds, slot.two_star_seconds, slot.time_bonus_seconds])
	check(slot.music == &"golden", "it plays the Golden Zone's track")
	check(slot.tuning is GoldenConvergenceTuning and slot.tuning.resource_path == "res://data/bosses/golden_boss_tuning.tres",
		"its numbers are a tuning of its own (F6)")
	var skin := slot.arena.skin as GoldenCourtSkin if slot.arena != null else null
	check(skin != null and skin is GoldenPalaceSkin and skin.resource_path == "res://data/bosses/golden_boss_skin.tres",
		"its arena is the Grand Court, the Golden Palace's look (GoldenCourtSkin)")
	check(slot.arena != null and slot.arena.features.is_empty(), "the court's laps bring nothing of their own")
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var missing: PackedStringArray = []
	for sound: StringName in NEW_SOUNDS:
		if not sfx.volume_db.has(String(sound)) or sfx.stream(sound) == null:
			missing.append(String(sound))
	check(missing.is_empty(), "its sounds are in the library (missing: %s)" % ", ".join(missing))
	var varied: PackedStringArray = []
	for sound: StringName in WARNINGS:
		if float(sfx.pitch_variation.get(String(sound), 0.0)) != 0.0:
			varied.append(String(sound))
	check(varied.is_empty(), "its warnings and cues sound the same every time (no pitch variation: %s)" % ", ".join(varied))
	var whine: AudioStream = sfx.stream(&"gc_whine")
	var t: GoldenConvergenceTuning = slot.tuning as GoldenConvergenceTuning
	check(whine != null and absf(whine.get_length() - t.warning_seconds) < 0.05,
		"the gatlings' whine lasts the pass's warning (%.2f s)" % (whine.get_length() if whine != null else 0.0))
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Array[String] = []
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		triggers.append(String(h.get("trigger", "")))
	check(triggers.has("enemy:golden_boss") and triggers.has("boss:golden_boss/strafe") and triggers.has("boss:golden_boss/buttress"),
		"its first fight, the strafe and the buttress have hints")


# --- The tuning ----------------------------------------------------------------------------------

func _test_tuning() -> void:
	var t: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	var kinds: Array[String] = []
	for beat: Dictionary in t.beats_for(0):
		kinds.append("%s:%s" % [beat["kind"], beat["arg"]])
	check(kinds == ["strafe:VVH", "slams:", "barrage:", "refill:VVH"],
		"phase 1: a strafe on its own (V-V-H), slams, a barrage, the Refill Ship with a strafe (GDD §10): %s" % [kinds])
	kinds.clear()
	for beat: Dictionary in t.beats_for(1):
		kinds.append("%s:%s" % [beat["kind"], beat["arg"]])
	check(kinds == ["slams:", "barrage:", "slams:", "barrage:", "refill:VVHvVHv"],
		"phases 2 and 3: slams, a barrage, slams, a barrage, the Refill Ship with a 7-pass strafe: %s" % [kinds])
	check(t.loop_start(0) == 1 and t.loop_start(1) == 0, "phase 1 loops from its slams (its opening strafe plays once)")
	check(GoldenConvergenceTuning.squadron_size(3) == 2 and GoldenConvergenceTuning.squadron_size(5) == 3
		and GoldenConvergenceTuning.squadron_size(6) == 3, "a drone for every other lane: 2 on 3 lanes, 3 on 5 or 6 (GDD §10)")
	check(GoldenConvergenceTuning.covered_lanes(3, 0) == [0, 2] and GoldenConvergenceTuning.covered_lanes(3, 1) == [1]
		and GoldenConvergenceTuning.covered_lanes(5, 0) == [0, 2, 4] and GoldenConvergenceTuning.covered_lanes(5, 1) == [1, 3]
		and GoldenConvergenceTuning.covered_lanes(6, 0) == [0, 2, 4] and GoldenConvergenceTuning.covered_lanes(6, 1) == [1, 3, 5],
		"a vertical pass rakes every other lane, lanes 1, 3, 5 counting from 1 first")
	check(t.warning_seconds >= 1.0, "a pass warns at least a second ahead (%.2f s)" % t.warning_seconds)
	check(t.line_height > tuning.jump_height + 1.0, "the live line's fire reaches above a jump (%.1f m)" % t.line_height)
	check(t.wall_line_height >= tuning.wall_max_height + 1.0, "and up a wall at every height a wall run reaches")


# --- The Grand Court -----------------------------------------------------------------------------

func _test_arena(lanes: int) -> void:
	var tag: String = "(%d lanes)" % lanes
	var pair: Array = _fight(lanes)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var plain: bool = true
	for lap: LevelLayout in boss.arena.laps:
		plain = plain and lap.gaps.is_empty() and lap.fences.is_empty() and lap.pads.is_empty() and lap.doodads.is_empty() \
			and lap.enemies.is_empty() and lap.credits.is_empty() and lap.ramps.is_empty() and lap.hulls.is_empty() \
			and lap.wall_fences.is_empty() and lap.cuts.is_empty()
	check(plain, "the court's laps are plain: every danger is the boss's %s" % tag)
	check(world.skin is GoldenCourtSkin, "the run wears the Grand Court %s" % tag)
	await _run(world, 0.2)
	var d: float = world.player.distance
	var t: GoldenConvergenceTuning = boss.tuning
	var walls_ok: bool = true
	var x: float = d - 5.0
	while x < d + t.wall_block_ahead - t.wall_block_stretch:
		walls_ok = walls_ok and boss.court.blocked(-1, x) and boss.court.blocked(1, x)
		x += 4.0
	check(walls_ok and boss.court.laid_until(-1) >= d + t.wall_block_ahead, "both walls are taken away ahead of the runner %s" % tag)
	await sim.free_world(world)


## The walls: a move past an outer lane bumps the runner back (no new way to die); a wall opened on request
## can be run, its end drops the runner off; closed again, it bumps.
func _test_court_walls() -> void:
	var pair: Array = _fight(5)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	var moves: Array[StringName] = []
	world.player.movement_event.connect(func(kind: StringName) -> void: moves.append(kind))
	await _run(world, 0.3)
	for i: int in 3:
		world.player.press(&"move_left")
		await _run(world, 0.25)
	check(world.player.lane == 0 and world.player.surface == Player.Surface.FLOOR, "the runner reaches the left lane")
	moves.clear()
	world.player.press(&"move_left")
	await _run(world, 0.4)
	check(moves.has(&"wall_blocked") and world.player.surface == Player.Surface.FLOOR and world.player.alive,
		"a move past the outer lane bumps them back off the balustrade (%s)" % [moves])
	# Further on, the walls are still taken away ahead.
	await _run(world, 8.0)
	var d: float = world.player.distance
	check(boss.court.blocked(-1, d + 100.0) and boss.court.blocked(1, d + 100.0), "the walls stay away as the runner goes on")
	# A wall opened from just ahead: the runner can run it, and drops off at its end.
	var id: int = boss.court.open_wall(-1, d + 6.0, d + 40.0)
	check(boss.court.is_open(-1, d + 20.0) and not boss.court.blocked(-1, d + 20.0) and boss.court.blocked(-1, d + 60.0)
		and not boss.court.is_open(1, d + 20.0), "open_wall takes the blockers up over its stretch, on its side only")
	await _run(world, 0.6)
	moves.clear()
	world.player.press(&"move_left")
	await _run(world, 0.4)
	check(world.player.surface == Player.Surface.WALL and moves.has(&"wall_enter"), "the runner can run the opened wall (%s)" % [moves])
	var repels: int = boss.court.repels
	for k: int in 12:
		await _run(world, 0.2)
		if world.player.surface == Player.Surface.WALL and world.player.h > 1.2:
			world.player.press(&"jump")
	check(_events(boss, &"wall_open").size() == 1, "the opening is logged")
	await _run(world, 2.0, func() -> bool: return world.player.distance > d + 44.0)
	check(world.player.surface != Player.Surface.WALL and world.player.alive, "past its end the runner is back off the wall")
	check(boss.court.repels >= repels, "a runner still on it at its end is dropped off (%d)" % boss.court.repels)
	boss.court.close_wall(id)
	check(not boss.court.is_open(-1, d + 20.0) and _events(boss, &"wall_close").size() == 1, "close_wall gives the stretch back")
	var d2: float = world.player.distance
	var id2: int = boss.court.open_wall(-1, d2 + 4.0, d2 + 200.0)
	await _run(world, 0.4)
	world.player.press(&"move_left")
	await _run(world, 0.3)
	var on_wall: bool = world.player.surface == Player.Surface.WALL
	repels = boss.court.repels
	boss.court.close_wall(id2)
	await _run(world, 0.2)
	check(on_wall and world.player.surface != Player.Surface.WALL and boss.court.repels == repels + 1
		and _events(boss, &"wall_repel").size() >= 1, "a wall closing under a runner drops them off with the clank")
	check(boss.court.blocked(-1, world.player.distance + 30.0), "and is blocked again")
	await sim.free_world(world)


# --- The golden suit -----------------------------------------------------------------------------

func _test_suit() -> void:
	var pair: Array = _fight(5, 18.0, null, -1)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var suit: GoldenConvergenceSuit = boss.suit
	world.player.god_mode = true
	check(suit.find_children("*", "Hazard", true, false).is_empty() and suit.weak_points.is_empty() and suit.shares_health,
		"the suit is the fight's body, out of reach: no hitbox, no weak point, nothing to touch")
	check(not suit.targetable(), "no target during the phase's intro")
	await _run(world, 8.0, func() -> bool: return boss.is_vulnerable())
	await _run(world, 0.5)
	check(boss.is_vulnerable() and suit.targetable(), "weapons may chip it once the pattern begins")
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var muzzle: Vector3 = world.player.global_position + Vector3(0.0, 1.2, 0.0)
	var ahead: float = muzzle.z - suit.aim_point().z
	var best: float = PowerupTuning.at_tier(pt.weapon_range, 2)
	var first: float = PowerupTuning.at_tier(pt.weapon_range, 1)
	check(ahead <= best - 1.0 and world.director.targets_ahead(muzzle, best).has(suit),
		"its chest is %.0f m ahead: the upgraded weapons (%.0f m) reach it" % [ahead, best])
	check(ahead > first and not world.director.targets_ahead(muzzle, first).has(suit),
		"the tier-1 weapon (%.0f m) doesn't (DESIGN-TBD, docs/OPEN_QUESTIONS.md items 416–503)" % first)
	var hp: float = boss.health
	suit.take_damage(10.0, &"weapon")
	check(boss.health < hp, "a weapon hit chips the fight's health")
	# Its look: nothing glows, nothing passes the hazards' saturation, the tear a dull red.
	var glowing: int = 0
	var loud: Array[String] = []
	var tear: int = 0
	var tear_ok: bool = true
	for mi: MeshInstance3D in suit.meshes():
		if mi.mesh == null or mi.material_override != null and mi.material_override == suit.cape_material():
			continue
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
			for i: int in colors.size():
				var c: Color = colors[i]
				if c.a > 0.001:
					glowing += 1
				if _chroma(c) > MAX_SURFACE_CHROMA and loud.size() < 4:
					loud.append(str(c))
				if c.r > c.g * 2.5 and c.r > c.b * 2.5:
					tear += 1
					tear_ok = tear_ok and c.v < 0.45 and _chroma(c) <= MAX_SURFACE_CHROMA \
						and (uv2s.is_empty() or (int(round(uv2s[i].x)) == MeshKit.PAT_GOLD and uv2s[i].y <= 0.1))
	check(glowing == 0, "nothing on the suit glows: polished metal lit by the court (%d glowing vertices)" % glowing)
	check(loud.is_empty(), "its gold, bronze and red stay well below the hazards' saturation: %s" % ", ".join(loud))
	check(tear > 0 and tear_ok, "its face has the dull red tear: darker than the gold, unpolished, never glowing (%d vertices)" % tear)
	var cape: ShaderMaterial = suit.cape_material()
	var code: String = cape.shader.code if cape != null and cape.shader != null else ""
	var cloth: Color = _param(cape, &"cloth_color")
	check(code.contains("unshaded") and not code.contains("EMISSION") and cloth.v < 0.6 and _chroma(cloth) <= MAX_SURFACE_CHROMA,
		"the cape never glows: burgundy velvet under the bloom, no emission (%s)" % cloth)
	var stats: Dictionary = suit.draw_stats()
	print("  the golden suit draws %d instances, %d surfaces, %d vertices" % [stats["instances"], stats["surfaces"], stats["vertices"]])
	check(int(stats["instances"]) <= SUIT_MAX_INSTANCES and int(stats["vertices"]) <= SUIT_MAX_VERTICES,
		"its draw budget: %d instances, %d vertices" % [stats["instances"], stats["vertices"]])
	# Its handles.
	var rest_hand: Vector3 = suit.hand_point(1)
	var target: Vector3 = world.player.global_position + Vector3(3.0, 0.0, -15.0)
	suit.set_arm(1, target, 1.0, 1.0, true)
	await _drawn()
	var reach: Vector3 = suit.hand_point(1)
	check(reach.distance_to(target) < rest_hand.distance_to(target) - 15.0,
		"an arm swings out and telescopes toward its target (%.0f m from it, from %.0f)" % [reach.distance_to(target), rest_hand.distance_to(target)])
	suit.set_arm(1, target, 0.0, 0.0, false)
	await _drawn()
	check(suit.hand_point(1).distance_to(rest_hand) < 2.0, "and comes back to hang at its side")
	var mouth: Vector3 = suit.pipe_mouth(-1)
	check(mouth.y > suit.head_point().y - 6.0 and mouth.z < world.player.global_position.z,
		"its shoulder pipes' mouths stand up on its pauldrons")
	var hatch: Node3D = suit.find_child("Hatch", true, false) as Node3D
	var shut: Transform3D = hatch.transform if hatch != null else Transform3D.IDENTITY
	suit.pipes_open[0] = 1.0
	suit.pipes_open[1] = 1.0
	await _drawn()
	check(hatch != null and not hatch.transform.is_equal_approx(shut), "the pipes' hatches swing open")
	suit.set_pipes_broken(-1)
	await _drawn()
	var torn: Node3D = suit.find_child("PipesR", true, false).get_node(^"Torn") as Node3D
	var cluster: Node3D = suit.find_child("PipesR", true, false).get_node(^"Cluster") as Node3D
	check(torn.visible and not cluster.visible, "a shoulder's pipes blown out show torn stubs")
	suit.burst = 1.0
	await _drawn()
	var plates: Array = suit.find_children("Plate?", "Node3D", true, false)
	var opened: bool = not plates.is_empty()
	for p: Node in plates:
		opened = opened and absf((p as Node3D).rotation.y) > 1.0
	check(opened, "the chest's plates burst open (%d)" % plates.size())
	for i: int in 3:
		var c: Vector3 = boss.cape_point(i)
		check(c.z < suit.global_position.z and c.y > 8.0, "drone %d comes out of the cape, behind and above the suit" % i)
	await sim.free_world(world)


# --- The entrance ----------------------------------------------------------------------------------

func _test_entrance() -> void:
	var pair: Array = _fight(5)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var t: GoldenConvergenceTuning = boss.tuning
	world.player.god_mode = true
	check(boss.step == GoldenConvergence.Step.ENTER and boss.suit.unfurl < 0.01 and _events(boss, &"entrance").size() == 1
		and _sounds(boss, &"gc_rise") == 1, "the fight opens on the entrance: the suit rising with its sound, the cape furled")
	var low: float = boss.suit.global_position.y
	check(low < t.suit_height - t.rise_depth * 0.5, "it starts far below its place (%.0f m)" % low)
	var seen := {"attack": false, "targetable": false, "chime_t": -1.0, "risen_t": -1.0, "unfurled_t": -1.0}
	await _run(world, 12.0, func() -> bool: return boss.is_vulnerable(), func() -> void:
		if boss.is_vulnerable():
			return
		if boss.strafe.busy() or boss.warning_active() or boss.fire.live():
			seen["attack"] = true
		if boss.suit.targetable():
			seen["targetable"] = true
		if float(seen["risen_t"]) < 0.0 and boss.suit.global_position.y >= t.suit_height - t.bob - 0.05:
			seen["risen_t"] = boss.fight_time()
		if float(seen["unfurled_t"]) < 0.0 and boss.suit.unfurl >= 0.999:
			seen["unfurled_t"] = boss.fight_time())
	var chimes: Array[Dictionary] = _events(boss, &"chime")
	check(chimes.size() == 1 and absf(float(chimes[0]["t"]) - t.chime_at) < 0.05 and _sounds(boss, &"gc_chime") == 1,
		"the cult's chime rings out once, %.1f s in (GDD §10, proposed)" % t.chime_at)
	check(float(seen["risen_t"]) > 0.0 and float(seen["risen_t"]) <= t.rise_seconds + 0.05,
		"it has risen into its place by %.1f s (%.2f s)" % [t.rise_seconds, seen["risen_t"]])
	check(float(seen["unfurled_t"]) >= t.unfurl_at and float(seen["unfurled_t"]) <= t.unfurl_at + t.unfurl_seconds + 0.05,
		"its cape unfurls into its cloud from %.1f s over %.1f s (%.2f s)" % [t.unfurl_at, t.unfurl_seconds, seen["unfurled_t"]])
	check(not seen["attack"] and not seen["targetable"], "nothing attacks and nothing can be hit during the entrance")
	check(boss.is_vulnerable() and absf(boss.fight_time() - boss.phase().intro_seconds) < 0.1,
		"phase 1 begins after its intro (%.1f s)" % boss.fight_time())
	await _run(world, 3.0, func() -> bool: return boss.strafe.busy())
	var beats: Array[Dictionary] = _events(boss, &"beat")
	check(not beats.is_empty() and beats[0]["kind"] == &"strafe" and String(beats[0]["arg"]) == "VVH"
		and _sounds(boss, &"gc_emerge") == 1, "then the squadron comes out of the cape for phase 1's first strafe, V-V-H")
	await sim.free_world(world)


# --- The squadron ----------------------------------------------------------------------------------

func _test_squadron() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(lanes, 18.0, null, -1)
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var tag: String = "(%d lanes)" % lanes
		check(boss.squadron.size() == GoldenConvergenceTuning.squadron_size(lanes), "%d drones fly %s" % [boss.squadron.size(), tag])
		if lanes == 5:
			var red: Array[String] = []
			for rig: Dictionary in boss.squadron.rigs:
				for node: Node in (rig["node"] as Node).find_children("*", "MeshInstance3D", true, false):
					var mi := node as MeshInstance3D
					var mats: Array[Material] = [mi.material_override]
					if mi.mesh != null:
						for s: int in mi.mesh.get_surface_count():
							mats.append(mi.mesh.surface_get_material(s))
							mats.append(mi.get_surface_override_material(s))
					for m: Material in mats:
						var sm := m as StandardMaterial3D
						if sm == null:
							continue
						if _reddish(sm.albedo_color) or (sm.emission_enabled and _reddish(sm.emission)):
							red.append(str(sm.albedo_color))
			check(red.is_empty(), "the squadron is the heli drone's model never coloured red (GDD §10): %s" % ", ".join(red))
			check(boss.squadron.immune_to_weapons and not boss.squadron.targetable() and not boss.fire.targetable()
				and boss.squadron.find_children("*", "Hazard", true, false).is_empty(),
				"weapons never target the squadron, and it has no touch of its own (only its fire hurts)")
			var harmless: bool = boss.fire.lines.size() == GoldenConvergenceFire.LINES
			for l: int in range(1, boss.fire.lines.size()):
				for cell: Dictionary in boss.fire.lines[l]["lanes"]:
					harmless = harmless and cell["hazard"] == null
				for wall: Dictionary in boss.fire.lines[l]["walls"]:
					harmless = harmless and wall["hazard"] == null
			check(harmless, "the lines for show have no hitbox at all (GDD §10: only the line at the buttress is live)")
		await sim.free_world(world)


# --- The Flying Buttress ---------------------------------------------------------------------------

func _test_buttress() -> void:
	# No attacks (a beat script of a kind that isn't built: the pattern idles).
	var pair: Array = _fight(5, 18.0, null, -1, "none")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var t: GoldenConvergenceTuning = boss.tuning
	await _run(world, 0.2)
	var d: float = world.player.distance
	var left: GoldenConvergenceButtress = boss.place_buttress(1, d + 300.0)
	var right: GoldenConvergenceButtress = boss.place_buttress(3, d + 330.0)
	var mid: GoldenConvergenceButtress = boss.place_buttress(2, d + 360.0)
	check(left.lean == -1 and right.lean == 1 and absi(mid.lean) == 1, "its arch leans toward the nearer edge (the middle lane's by seed)")
	check(_sounds(boss, &"gc_buttress") == 3 and left.standing() and left.rise < 0.1, "it rises with a deep rumble")
	await _run(world, t.buttress_rise_seconds + 0.1)
	check(left.state == GoldenConvergenceButtress.State.STANDING and is_equal_approx(left.rise, 1.0), "risen in %.1f s" % t.buttress_rise_seconds)
	var marble: bool = true
	var arrays: Array = left._pier.mesh.surface_get_arrays(0)
	for c: Color in (arrays[Mesh.ARRAY_COLOR] as PackedColorArray):
		marble = marble and c.a < 0.001 and _chroma(c) <= MAX_SURFACE_CHROMA
	check(marble, "its marble and gold never glow (safe things look safe)")
	left.release()
	right.release()
	mid.release()
	# A lane switch into its lane beside the pier bumps the runner; a runner in its lane runs through the arch.
	for i: int in 2:
		world.player.press(&"move_left")
		await _run(world, 0.3)
	check(world.player.lane == 0, "the runner is in the left lane")
	d = world.player.distance
	var b: GoldenConvergenceButtress = boss.place_buttress(1, d + 30.0)
	var span: Vector2 = b.blocked_span()
	var moves: Array[StringName] = []
	world.player.movement_event.connect(func(kind: StringName) -> void: moves.append(kind))
	await _run(world, 3.0, func() -> bool: return world.player.distance >= span.x + 0.5)
	world.player.press(&"move_right")
	await _run(world, 0.3)
	check(moves.has(&"lane_blocked") and world.player.lane == 0 and world.player.alive,
		"a lane switch into its lane beside the pier bumps the runner back, unharmed (%s)" % [moves])
	await _run(world, 2.0, func() -> bool: return world.player.distance > span.y + 1.0)
	world.player.press(&"move_right")
	await _run(world, 0.3)
	check(world.player.lane == 1, "past it, the lane is free again")
	d = world.player.distance
	var gate: GoldenConvergenceButtress = boss.place_buttress(1, d + 40.0)
	moves.clear()
	await _run(world, 4.0, func() -> bool: return world.player.distance > gate.at + 5.0)
	check(world.player.alive and world.player.lane == 1 and not moves.has(&"lane_blocked") and not moves.has(&"doodad_push"),
		"a runner in its lane runs through the arch untouched")
	# Smashed: it crumbles, and blocks nothing.
	d = world.player.distance
	var target: GoldenConvergenceButtress = boss.place_buttress(2, d + 40.0)
	var smashed: Array = []
	target.smashed.connect(func(which: GoldenConvergenceButtress) -> void: smashed.append(which))
	await _run(world, 0.5)
	target.smash()
	check(smashed.size() == 1 and target.state == GoldenConvergenceButtress.State.CRUMBLING and not target.standing()
		and target.in_use() and _sounds(boss, &"gc_crumble") == 1, "smashed, it crumbles with its sound and says so")
	moves.clear()
	await _run(world, 2.0, func() -> bool: return world.player.distance >= target.blocked_span().x + 0.5)
	world.player.press(&"move_right")
	await _run(world, 0.3)
	check(world.player.lane == 2 and not moves.has(&"lane_blocked"), "its sides block nothing once smashed")
	await _run(world, t.crumble_seconds + 0.2)
	check(not target.visible, "it's gone once it has crumbled")
	await _run(world, 4.0, func() -> bool: return not target.in_use())
	check(not target.in_use() and gate.lane == -1, "and back in the pool once the runner is past")
	await sim.free_world(world)


# --- Reduced flashing --------------------------------------------------------------------------------

func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var pair: Array = _fight(5, 18.0, null, -1, "strafe:V")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		world.player.god_mode = true
		var seen := {"frames": 0, "flash_on": 0, "widths": {}}
		await _run(world, 16.0, func() -> bool: return int(seen["frames"]) >= 20, func() -> void:
			var s: GoldenConvergenceStrafe = boss.strafe
			if s.current < 0 or int(s.passes[s.current]["stage"]) != GoldenConvergenceStrafe.PassStage.FIRE:
				return
			for i: int in boss.squadron.size():
				var rig: Dictionary = boss.squadron.rigs[i]
				if not bool(rig["firing"]):
					continue
				seen["frames"] = int(seen["frames"]) + 1
				if (rig["flash"] as Node3D).visible:
					seen["flash_on"] = int(seen["flash_on"]) + 1
				var beam: Node3D = boss.fire.tracers[i]["beam"]
				seen["widths"][snappedf(beam.scale.x, 0.001)] = true)
		var frames: int = int(seen["frames"])
		var tag: String = "with Reduced flashing" if reduced else "normally"
		if reduced:
			check(frames > 0 and int(seen["flash_on"]) == frames and (seen["widths"] as Dictionary).size() == 1,
				"%s the muzzle flashes and the tracers stay steady (%d/%d, %d widths)" % [tag, seen["flash_on"], frames, (seen["widths"] as Dictionary).size()])
		else:
			check(frames > 0 and int(seen["flash_on"]) < frames and (seen["widths"] as Dictionary).size() > 1,
				"%s they flicker (%d/%d)" % [tag, seen["flash_on"], frames])
		await sim.free_world(world)
	Settings.flashing_reduced = was


# --- A later phase -----------------------------------------------------------------------------------

## A stage 1 phase after the first opens on the suit reeling back from the blast (GDD §10, proposed), then
## floating on (here weapons end phase 1: BossDef.weapons_can_end_phase, a ship saved), its right shoulder's pipes
## blown out (the first ship's damage, whatever ended the phase).
func _test_reel() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "none")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	await _run(world, 8.0, func() -> bool: return boss.is_vulnerable())
	boss.suit.take_damage(boss.max_health * boss.def.weapon_share_cap, &"weapon")
	check(boss.phase_index == 1 and not boss.is_vulnerable(), "weapons can end phase 1 (a ship's worth: the most they may)")
	check(boss.suit.pipes_broken[0] and not boss.suit.pipes_broken[1], "phase 2 shows the first ship's damage: its right shoulder's pipes")
	var most := {"reel": 0.0}
	await _run(world, 6.0, func() -> bool: return boss.is_vulnerable(), func() -> void:
		most["reel"] = maxf(float(most["reel"]), boss.suit.reel))
	check(_events(boss, &"reel").size() == 1 and float(most["reel"]) > 0.5,
		"phase 2 opens on the suit reeling back from the blast (%.2f)" % float(most["reel"]))
	await _run(world, 0.2)
	check(boss.is_vulnerable() and is_zero_approx(boss.suit.reel) and boss.step == GoldenConvergence.Step.FLOAT,
		"then it floats on")
	await sim.free_world(world)


# --- Stage 2 (E5d-d) ---------------------------------------------------------------------------------

## From the checkpoint (phase 4), stage 2 begins with the transition (E5d-d): the suit bursts, The Magnate comes
## out, the suit is gone and the chase begins; nothing attacks during it (test_golden_convergence_magnate.gd
## tests stage 2 itself).
func _test_stage_two_start() -> void:
	var pair: Array = _fight(5, 18.0, null, 3)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	await _run(world, 4.0)
	check(boss.phase_index == 3 and _events(boss, &"stage_2").size() == 1 and _events(boss, &"transition").size() == 1,
		"from the checkpoint, stage 2 begins with the transition")
	check(_events(boss, &"beat").is_empty() and not boss.strafe.busy() and not boss.fire.live()
		and _events(boss, &"pounce_roar").is_empty(), "and nothing attacks during it")
	await _run(world, 3.0)
	check(not boss.suit.visible and boss.transition.suit_down and boss.magnate.shown()
		and boss.chase.mode != GoldenConvergenceChase.Mode.OFF, "then the suit is gone and The Magnate hunts the runner")
	await sim.free_world(world)


# --- The feed ---------------------------------------------------------------------------------------

func _test_feed() -> void:
	var pair: Array = _fight(5)
	var world: RunWorld = pair[0]
	var skin := world.skin as GoldenCourtSkin
	var state: Dictionary = skin.feed_state()
	check(int(state["mode"]) == 0 and is_equal_approx(float(state["power"]), 1.0) and float(state["blackout_radius"]) < 0.0,
		"the fight starts on stage 1's feed, every screen on")
	skin.set_feed(1, 0.5, 0.3)
	skin.set_feed_blackout(Vector3(0.0, 0.0, -100.0), 40.0)
	state = skin.feed_state()
	check(int(state["mode"]) == 1 and is_equal_approx(float(state["power"]), 0.5) and is_equal_approx(float(state["glitch"]), 0.3)
		and is_equal_approx(float(state["blackout_radius"]), 40.0), "the later steps can switch the feed and black the screens out")
	skin.reset_feed()
	var towers: Array[Dictionary] = skin.towers(-1, -world.geo.wall_x(), 0.0, 600.0)
	towers.append_array(skin.towers(1, world.geo.wall_x(), 0.0, 600.0))
	check(towers.size() >= 8, "the palace's towers stand along both sides, each with its screen (%d in 600 m)" % towers.size())
	var m: ShaderMaterial = skin.court_feed_material()
	var loud: Array[String] = []
	for param: StringName in [&"feed_color", &"face_color", &"emblem_color"]:
		var c: Color = _param(m, param)
		if c.s > 0.35:
			loud.append("%s %s" % [param, c])
	var tear: Color = _param(m, &"tear_color")
	check(loud.is_empty() and tear.v < 0.45, "the feed glows only in its whites and pale gold, its tear dark: %s" % ", ".join(loud))
	await sim.free_world(world)


# --- The HUD -----------------------------------------------------------------------------------------

## The boss bar names the fight; with the final villain's long name the phase keeps to its number when
## its title doesn't fit beside it (BossBar), never overlapping.
func _test_hud() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "none")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	var hud := RunHud.new()
	tree.root.add_child(hud)
	hud.bind(world, ctx)
	await _run(world, 8.0, func() -> bool: return boss.is_vulnerable())
	await tree.process_frame
	await tree.process_frame
	var bar: BossBar = hud.boss_bar
	var phase_text: String = bar.phase_label.text
	check(bar.visible and bar.name_label.text == "THE GOLDEN CONVERGENCE", "the boss bar names the fight (%s)" % bar.name_label.text)
	check(phase_text == "THE GOLDEN SUIT · 1/6" or phase_text == "1/6", "and its phase, 1 of 6 (%s)" % phase_text)
	var fits: bool = BossBar._text_width(bar.name_label, bar.name_label.text) + BossBar._text_width(bar.phase_label, phase_text) \
		<= bar.size.x + 0.5
	check(fits, "the name and the phase fit side by side (%s, %.0f px)" % [phase_text, bar.size.x])
	hud.queue_free()
	await sim.free_world(world)
