extends TestSuite
## The House, the Marketplace's boss (GDD §10; task E5a-a): its slot and data, its arena, the machine's
## model and budget, its reels, how a spin's symbols become attacks, and the lane routes every attack and
## button is held to (TheHouseRoute). Its attacks: test_the_house_attacks.gd; its buttons, jackpot and
## fight: test_the_house_fight.gd.

const BOSS_PATH: String = "res://data/bosses/marketplace_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const NEW_SOUNDS: Array[StringName] = [&"house_roll", &"house_lever", &"house_spin", &"house_ding", &"house_lock",
	&"house_button", &"house_cherry", &"house_lightning", &"house_bar", &"house_slam", &"house_jackpot", &"house_coins",
	&"house_sag", &"house_hit"]
## The Marketplace's cables slung across the street hang no lower than this (MarketFacades.overhead:
## 15.5 m less their sag), and the machine stands under them.
const CABLES_LOWEST: float = 14.4

var sim: RunSim
var slot: BossDef
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	slot = load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "The House's fight loads as a preview")
		return
	_test_slot()
	_test_reels()
	_test_attacks_for()
	_test_route()
	await _test_arena_and_model()


## The fight at `lanes` and `speed` m/s (0: 18): [world, boss].
func _fight(p_def: BossDef, lanes: int, speed: float = 0.0) -> Array:
	var boss := BossEncounter.create(p_def) as TheHouse
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
	check(slot.display_name == "The House" and slot.id == &"marketplace_boss", "the Marketplace's slot is The House (GDD §10)")
	check(not slot.is_built() and slot.preview_scene == "res://scenes/bosses/the_house.tscn" and slot.preview() != null,
		"step 1 of 2: the campaign keeps its card; debug builds play the fight as a preview (--boss=marketplace_boss)")
	var list: Array[BossPhase] = def.phase_list()
	check(list.size() == 3 and list[0].hits == 1 and list[1].hits == 1 and list[2].hits == 1,
		"three phases, one stomp each (GDD §10)")
	check(def.weapon_share_cap > 0.0 and def.weapon_share_cap <= 1.0 / 3.0 + 0.01,
		"weapons chip at it, but can save at most one stomp (%.2f of its health)" % def.weapon_share_cap)
	check(def.armor_rule and def.armor_delay_min == 15.0 and def.armor_delay_max == 17.0 and def.armor_pickups_per_phase == 1,
		"the standard armor rule, 15-17 s (GDD §10)")
	check(def.music == &"marketplace", "it plays the Marketplace's own track (no new music)")
	check(def.tuning is TheHouseTuning, "its numbers are a tuning of its own (F6)")
	check(def.arena != null and def.arena.skin is MarketplaceSkin and def.arena.skin.resource_path == "res://data/bosses/marketplace_boss_skin.tres",
		"its arena is in the Marketplace's look, its own skin")
	var skin := def.arena.skin as MarketplaceSkin
	check(skin != null and skin.bunting_height >= 25.0, "with no pennants strung low over the street where it rolls")
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in NEW_SOUNDS:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "its sound %s exists" % sound)
	for sound: StringName in [&"house_ding", &"house_lock", &"house_button", &"house_cherry", &"house_lightning", &"house_bar"]:
		check(sfx.stream(sound).get_length() <= 1.2, "%s is short (a cue)" % sound)
	var t := def.tuning as TheHouseTuning
	check(sfx.stream(&"house_jackpot").get_length() >= t.sag_seconds, "the jackpot's sirens wail through the sag")
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Array = []
	for h: Dictionary in (hints as Dictionary)["hints"]:
		triggers.append(h["trigger"])
	for trigger: String in ["enemy:marketplace_boss", "boss:marketplace_boss/buttons", "boss:marketplace_boss/jackpot"]:
		check(triggers.has(trigger), "a first-time hint for %s" % trigger)
	# Its tuning's lists.
	for phase: int in 3:
		var spins: Array[PackedStringArray] = t.spins_for(phase)
		check(spins.size() >= 4, "phase %d has a list of spins" % (phase + 1))
		var kinds: Dictionary = {}
		var counts: Dictionary = {}
		for spin: PackedStringArray in spins:
			check(spin.size() == 3, "each spin shows three symbols")
			for s: String in spin:
				kinds[s] = true
			var most: int = 0
			for s: String in spin:
				most = maxi(most, spin.count(s))
			counts[most] = true
		check(kinds.size() == 3 and counts.has(1) and counts.has(2) and counts.has(3),
			"phase %d's spins show every symbol, and two and three of a kind" % (phase + 1))
	check(t.longest_warning() >= t.cherry_warning and TheHouseTuning.per_lanes(PackedInt32Array([2, 3, 4]), 3) == 2
		and TheHouseTuning.per_lanes(PackedInt32Array([2, 3, 4]), 5) == 3 and TheHouseTuning.per_lanes(PackedInt32Array([2, 3, 9]), 6) == 5,
		"its per-lane-count numbers always leave a lane free")


# --- Reels ---------------------------------------------------------------------------------------

func _test_reels() -> void:
	var r := TheHouseReels.new()
	for i: int in 3:
		r.spin(i)
	for k: int in 30:
		r.tick(1.0 / 60.0)
	check(r.any_spinning() and r.blur().x > 0.5, "spinning reels turn and smear")
	var targets: Array[int] = [TheHouseReels.Symbol.CHERRY, TheHouseReels.Symbol.BAR, TheHouseReels.Symbol.LIGHTNING]
	for i: int in 3:
		var before: float = r.angle[i]
		r.stop(i, targets[i])
		check(r.shown[i] == targets[i], "a stop shows its symbol at once (reel %d)" % i)
		check(r._to[i] - before >= TheHouseReels.STOP_MIN - 0.001, "and turns the drum on at least a little to land on it")
	for k: int in 60:
		r.tick(1.0 / 60.0)
	for i: int in 3:
		check(posmod(roundi(r.angle[i]), 4) == targets[i] and is_equal_approx(r.angle[i], roundf(r.angle[i])),
			"reel %d's drum comes to rest on its symbol's slot (%s)" % [i, TheHouseReels.symbol_name(targets[i])])
	check(not r.any_spinning() and r.blur() == Vector3.ZERO, "and stops smearing")
	r.stop(1, TheHouseReels.Symbol.SEVEN, true)
	r.spin(1)
	check(r.locked[1] == 1 and not r.spinning(1) and r.lock_glow().y == 1.0, "a reel locked on 7 doesn't spin again and glows")
	r.unlock()
	check(r.lock_glow() == Vector3.ZERO, "until it's unlocked")
	check(TheHouseReels.symbol_of("bar") == TheHouseReels.Symbol.BAR and TheHouseReels.symbol_of("nonsense") == TheHouseReels.Symbol.CHERRY,
		"symbols by name")


func _test_attacks_for() -> void:
	var C: int = TheHouseReels.Symbol.CHERRY
	var B: int = TheHouseReels.Symbol.BAR
	var L: int = TheHouseReels.Symbol.LIGHTNING
	var S: int = TheHouseReels.Symbol.SEVEN
	var a: Array[Dictionary] = TheHouseAttacks.attacks_for([C, B, L] as Array[int])
	check(a.size() == 3 and int(a[0]["kind"]) == TheHouseAttacks.Kind.CHERRY and int(a[1]["kind"]) == TheHouseAttacks.Kind.BAR
		and int(a[2]["kind"]) == TheHouseAttacks.Kind.LIGHTNING and int(a[0]["size"]) == 1,
		"three symbols, three attacks in reel order (GDD §10)")
	a = TheHouseAttacks.attacks_for([B, C, B] as Array[int])
	check(a.size() == 2 and int(a[0]["kind"]) == TheHouseAttacks.Kind.BAR and int(a[0]["size"]) == 2 and int(a[1]["size"]) == 1,
		"two of a kind make one bigger attack, in the order its first reel shows it")
	a = TheHouseAttacks.attacks_for([L, L, L] as Array[int])
	check(a.size() == 1 and int(a[0]["size"]) == 3, "three of a kind, the biggest")
	a = TheHouseAttacks.attacks_for([S, C, S] as Array[int])
	check(a.size() == 1 and int(a[0]["kind"]) == TheHouseAttacks.Kind.CHERRY, "a reel locked on 7 brings no attack")
	check(TheHouseAttacks.attacks_for([S, S, S] as Array[int]).is_empty(), "and three 7s bring none (the jackpot)")
	check(TheHouseAttacks.strikes_in(TheHouseAttacks.Kind.CHERRY, 3) == 3 and TheHouseAttacks.strikes_in(TheHouseAttacks.Kind.BAR, 2) == 2
		and TheHouseAttacks.strikes_in(TheHouseAttacks.Kind.LIGHTNING, 2) == 1 and TheHouseAttacks.strikes_in(TheHouseAttacks.Kind.LIGHTNING, 3) == 2,
		"the bigger versions: more volleys and rows; three lightnings, two rows")


# --- Routes --------------------------------------------------------------------------------------

func _test_route() -> void:
	var t := def.tuning as TheHouseTuning
	var r: TheHouseRoute = TheHouseRoute.for_run(3, 18.0, tuning, t)
	var O := TheHouseRoute
	# A row of solids leaving the right lane free: the way is there.
	var row: Array = [O.obstacle(0, 40.0, 42.0), O.obstacle(1, 40.0, 42.0)]
	var route: Dictionary = r.find(1, 0.0, 6.0, 60.0, row)
	check(route["ok"] and int(route["end_lane"]) == 2 and (route["moves"] as Array).size() == 1,
		"a row with a free lane: one switch into it")
	check(route["ok"] and float((route["moves"] as Array)[0]["at"]) <= 6.5, "taken as soon as the runner can move")
	check(TheHouseRoute.lane_at(route, 1, 3.0) == 1 and TheHouseRoute.lane_at(route, 1, 30.0) == 2, "the route's lane along the way")
	# Every lane solid: no way.
	var wall: Array = [O.obstacle(0, 40.0, 42.0), O.obstacle(1, 40.0, 42.0), O.obstacle(2, 40.0, 42.0)]
	check(not r.find(1, 0.0, 6.0, 60.0, wall)["ok"], "a solid wall across every lane has no way through")
	# Too late to leave the lane.
	check(not r.find(1, 0.0, 38.0, 60.0, row)["ok"], "a runner who can't move before it has no way")
	# A full fence across every lane: jumped. With a solid in its jump, that lane is blocked.
	var fences: Array = []
	for l: int in 3:
		fences.append(O.obstacle(l, 40.0, 40.3, O.Kind.FENCE))
	route = r.find(1, 0.0, 6.0, 60.0, fences)
	check(route["ok"] and (route["moves"] as Array).is_empty(), "a full fence across every lane: jump it where you are")
	var crowded: Array = fences.duplicate()
	crowded.append(O.obstacle(1, 44.0, 45.0))
	route = r.find(1, 0.0, 6.0, 60.0, crowded)
	check(route["ok"] and int(route["end_lane"]) != 1, "a solid where the jump lands makes it jump in another lane")
	# Two rows, the free lane changing: a slalom.
	var slalom: Array = [O.obstacle(0, 40.0, 42.0), O.obstacle(1, 40.0, 42.0), O.obstacle(1, 60.0, 62.0), O.obstacle(2, 60.0, 62.0)]
	route = r.find(1, 0.0, 6.0, 80.0, slalom)
	check(route["ok"] and TheHouseRoute.lane_at(route, 1, 41.0) == 2 and TheHouseRoute.lane_at(route, 1, 61.0) == 0,
		"a slalom: the free lane of each row in turn")
	check(route["ok"] and (route["moves"] as Array).size() == 3, "with no more switches than it needs")
	# Waypoints (buttons).
	route = r.find(1, 0.0, 3.0, 70.0, [], [{"lane": 0, "at": 30.0}, {"lane": 2, "at": 55.0}])
	check(route["ok"] and TheHouseRoute.lane_at(route, 1, 30.0) == 0 and TheHouseRoute.lane_at(route, 1, 55.0) == 2,
		"over each button, in order")
	check(not r.find(1, 0.0, 3.0, 70.0, [], [{"lane": 0, "at": 30.0}, {"lane": 2, "at": 33.0}])["ok"],
		"two buttons two lanes apart and too close: no way over both")
	route = r.find(1, 0.0, 3.0, 70.0, row, [{"lane": 0, "at": 56.0}])
	check(route["ok"] and TheHouseRoute.lane_at(route, 1, 41.0) == 2 and TheHouseRoute.lane_at(route, 1, 56.0) == 0,
		"around a row and on to a button behind it")
	# The margins grow with the speed (a switch takes more track).
	var fast: TheHouseRoute = TheHouseRoute.for_run(3, 22.6, tuning, t)
	check(fast.switch_m > r.switch_m and fast.jump_before > r.jump_before, "the margins follow the run speed")


# --- Arena and model -----------------------------------------------------------------------------

func _test_arena_and_model() -> void:
	var t := def.tuning as TheHouseTuning
	for lanes: int in LANES:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(def, lanes)
		var world: RunWorld = pair[0]
		var boss: TheHouse = pair[1]
		var layout: LevelLayout = boss.arena.layout
		var other: int = layout.gaps.size() + layout.fences.size() + layout.signs.size() + layout.hulls.size() + layout.pads.size() \
			+ layout.ramps.size() + layout.speed_pads.size() + layout.enemies.size() + layout.doodads.size() + layout.cuts.size() \
			+ layout.wall_fences.size() + layout.credits.size()
		check(other == 0, "its arena is a plain street: the danger is the machine's own %s" % tag)
		var s: TheHouseModel.Shape = boss.body.shape()
		check(s.width <= world.geo.wall_x() * 2.0 - 2.0 * t.street_margin + 0.01, "the machine fills the street between the walls %s" % tag)
		check(s.height + 0.6 <= CABLES_LOWEST, "and stands under the cables across the street (%.1f m) %s" % [s.height, tag])
		check(s.reel_height >= 2.4 and s.reel_width >= 1.6, "its reels are huge (%.1f x %.1f m) %s" % [s.reel_width, s.reel_height, tag])
		var stomp: float = boss.body.hopper_hitbox().size.z
		check(s.hopper_front - s.hopper_back >= stomp - 0.01 and s.depth >= -s.hopper_back + t.deck_back_margin - 0.01,
			"its hopper is as long as the stomp box, and its deck runs on past it %s" % tag)
		check(boss.body.hopper_hitbox().size.x >= world.geo.wall_x() * 2.0 - 0.01, "the hopper's box spans the street %s" % tag)
		var stats: Dictionary = boss.body.draw_stats()
		check(int(stats["instances"]) <= 12 and int(stats["surfaces"]) <= 12 and int(stats["vertices"]) <= 12000,
			"low-poly and merged: %d draws, %d vertices %s" % [stats["instances"], stats["vertices"], tag])
		# Nothing on the cabinet glows (only its bulbs, its reels' symbols and, open, its hopper do).
		var cabinet := boss.body.model.get_node("Cabinet") as MeshInstance3D
		var colors: PackedColorArray = cabinet.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var glowing: int = 0
		for c: Color in colors:
			glowing += 1 if c.a > 0.0 else 0
		check(glowing == 0, "its cabinet doesn't glow: no hazard colour lit on it %s" % tag)
		check(boss.body.model.get_node_or_null("Emblem") != null, "the cult's emblem is worked into it (GDD §10)")
		var pivot: Vector3 = s.lever_pivot
		check(absf(pivot.x) + 0.3 < world.geo.wall_x(), "its lever stands in the street, clear of the wall %s" % tag)
		check(boss.body.exclusive_major_attack and boss.body.is_boss and boss.body.claw_immune and not boss.body.dash_kills,
			"a boss's body: claws never kill it, the dash passes through it %s" % tag)
		check(boss.body.core_hitbox().is_active() and boss.body.core_hitbox().is_solid and not boss.body.weak_points_enabled(),
			"standing, it's solid and its hopper is shut %s" % tag)
		await sim.free_world(world)
