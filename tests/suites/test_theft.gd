extends TestSuite
## The robbed hit and credit theft (GDD §9.12; task B6), the mechanism the Tithe Collector (task C5)
## builds on:
## - DamageRules: a thief's touch resolves to ROBBED, never a death or a block, whatever protects the
##   player; the moment after a theft ignores it; the dash, a stomp and the claws catch the thief; and
##   every other outcome is exactly what it was (a copy of the rules before B6, over every kind of hazard
##   and enemy part and every combination of protections);
## - the player: robbed, alive, its protection untouched, the theft window; one touch robs once;
## - the books: 25% of the run's credits as they stand, rounded down, held by the thief; a second thief
##   takes a share of what's left; the score never drops; a catch pays back what it held plus the
##   jackpot; one that gets away keeps it; credits taken off the track and the stars' best score;
## - the pay: a death after a theft pays 20% of what's left, completion what's left plus the bonus, a boss
##   fight alike; stars are a clean run's; the results screen shows what was stolen;
## - the feedback: the HUD's credits counting down in the loss colour, the pop-ups, never the death
##   message; the coin streams; the robbed and jackpot sounds; Reduced flashing;
## - the stand-in thief on real physics at 3, 5 and 6 lanes: a gold block that never glows, crossing
##   every lane, robbing a runner who keeps to its lane (once), missed by one who moves aside, caught by a
##   stomp, the dash, the claws and a weapon; the same every attempt; and quick play's --thief.

const O = DamageRules.Outcome
const THIEF: String = "stand_in_thief"

var sim: RunSim
var rules: GameRules
var _nodes: Array[Node] = []


func run() -> void:
	sim = RunSim.new(tree, tuning)
	rules = load("res://data/tuning/game_rules.tres") as GameRules
	_test_rules()
	_test_unchanged()
	await _test_player()
	await _test_books()
	await _test_pay_and_stars()
	await _test_hud_and_sound()
	await _test_stand_in()
	for lanes: int in [3, 5, 6]:
		await _test_robbed_on_physics(lanes)
	await _test_catches_on_physics()
	await _test_determinism()
	await _test_quick_play()
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


# --- DamageRules -----------------------------------------------------------------------------------

func _test_rules() -> void:
	var body: Hazard = _enemy_part(&"body")
	var top: Hazard = _enemy_part(&"top")
	for h: Hazard in [body, top]:
		h.steals_share = 0.25
	check(DamageRules.resolve(body, _d()) == O.ROBBED, "touching a thief robs: no death (GDD §9.12)")
	check(DamageRules.resolve(body, _d("armor")) == O.ROBBED and DamageRules.resolve(body, _d("shield")) == O.ROBBED
		and DamageRules.resolve(body, _d("armor", "shield")) == O.ROBBED,
		"armor and the shield don't stop it, and aren't used up: it's no hit (DESIGN-TBD)")
	check(DamageRules.resolve(body, _d("invulnerable")) == O.ROBBED and DamageRules.resolve(body, _d("god")) == O.ROBBED,
		"nor the invulnerability window or god mode (a review aid)")
	check(DamageRules.resolve(body, _d("theft_immune")) == O.IGNORE, "in the moment after a theft, a touch does nothing")
	check(DamageRules.resolve(body, _d("dashing")) == O.DEFEAT_ENEMY, "the dash catches it (GDD §9.12)")
	check(DamageRules.resolve(top, _d(), true) == O.STOMP, "a stomp catches it")
	check(DamageRules.resolve(top, _d(), false) == O.ROBBED, "running into its top is a touch")
	check(DamageRules.resolve(body, _d("claws")) == O.DEFEAT_ENEMY, "the claws catch it like any enemy (GDD §8; DESIGN-TBD)")
	(body.enemy as Enemy).claw_immune = true
	check(DamageRules.resolve(body, _d("claws")) == O.ROBBED, "a claw-immune thief robs a runner with claws")
	(body.enemy as Enemy).claw_immune = false
	body.set_enabled(false)
	check(DamageRules.resolve(body, _d()) == O.IGNORE, "an inactive thief does nothing")
	body.set_enabled(true)
	var loose := Hazard.new()
	_nodes.append(loose)
	loose.steals_share = 0.25
	check(DamageRules.resolve(loose, _d("shield")) == O.ROBBED, "a thief hitbox without an enemy robs too")
	(top.enemy as Enemy).alive = false
	check(DamageRules.resolve(top, _d()) == O.IGNORE, "a caught thief robs no more")
	(top.enemy as Enemy).alive = true

	# Every combination of protections, stomping or not: never a death, a block or a used-up item.
	var cases: int = 0
	var wrong: Array = []
	for h: Hazard in [body, top]:
		for mask: int in 128:
			for stomping: bool in [false, true]:
				var d: DamageRules.Defense = _mask(mask)
				var got: O = DamageRules.resolve(h, d, stomping)
				cases += 1
				if got != _thief_expected(h, d, stomping) and wrong.size() < 3:
					wrong.append([h.part, mask, stomping, O.keys()[got]])
	check(wrong.is_empty(), "a thief's touch over every protection (%d cases): robbed, caught or nothing, never hurt %s" % [cases, wrong])


## What a thief's touch should resolve to (GDD §9.12 and the shared rules).
func _thief_expected(h: Hazard, d: DamageRules.Defense, stomping: bool) -> O:
	var e: Enemy = h.enemy
	if d.dashing and h.dash_passes:
		return O.DEFEAT_ENEMY if e.dash_kills else O.IGNORE
	if stomping and h.part == &"top":
		if e.stompable:
			return O.STOMP
		if d.claws and not e.claw_immune:
			return O.DEFEAT_ENEMY
	if d.claws and not e.claw_immune:
		return O.DEFEAT_ENEMY
	return O.IGNORE if d.theft_immune else O.ROBBED


## Every hazard that isn't a thief resolves exactly as before B6: a copy of the rules as they were,
## over every kind of hazard and enemy part, every enemy flag and every combination of protections.
func _test_unchanged() -> void:
	var hazards: Array[Hazard] = []
	for flags: Array in [[true, false, false], [false, true, false], [false, false, true], [false, false, false]]:
		var h := Hazard.new()
		h.is_solid = flags[0]
		h.is_enemy_attack = flags[1]
		h.is_electrical = flags[2]
		_nodes.append(h)
		hazards.append(h)
	var off := Hazard.new()
	off.is_electrical = true
	off.set_enabled(false)
	_nodes.append(off)
	hazards.append(off)
	var no_dash := Hazard.new()
	no_dash.is_solid = true
	no_dash.dash_passes = false
	_nodes.append(no_dash)
	hazards.append(no_dash)
	for part: StringName in [&"body", &"top", &"weak_point", &"attack"]:
		for bits: int in 16:
			var h: Hazard = _enemy_part(part, part == &"attack")
			var e: Enemy = h.enemy
			e.stompable = bits & 1 != 0
			e.claw_immune = bits & 2 != 0
			e.dash_kills = bits & 4 != 0
			e.alive = bits & 8 != 0
			hazards.append(h)
	var cases: int = 0
	var wrong: Array = []
	for h: Hazard in hazards:
		for mask: int in 128:
			for stomping: bool in [false, true]:
				var d: DamageRules.Defense = _mask(mask)
				var got: O = DamageRules.resolve(h, d, stomping)
				cases += 1
				if got != _resolve_before_b6(h, d, stomping) and wrong.size() < 3:
					wrong.append([h.part, mask, stomping, O.keys()[got]])
				if got == O.ROBBED and wrong.size() < 3:
					wrong.append(["robbed", h.part, mask])
	check(wrong.is_empty() and cases == hazards.size() * 256,
		"every other hazard resolves exactly as before (%d cases over %d hazards) %s" % [cases, hazards.size(), wrong])


## DamageRules.resolve() as it was before task B6 (the reference for _test_unchanged).
static func _resolve_before_b6(hazard: Hazard, defense: DamageRules.Defense, stomping: bool) -> O:
	if not hazard.is_active():
		return O.IGNORE
	var enemy: Enemy = hazard.enemy
	if enemy != null and not enemy.alive:
		return O.IGNORE
	if defense.dashing and hazard.dash_passes:
		if enemy != null and enemy.dash_kills:
			return O.DEFEAT_ENEMY
		return O.IGNORE
	if enemy != null:
		if hazard.part == &"weak_point":
			return O.STOMP if stomping else O.IGNORE
		if stomping and hazard.part == &"top":
			if enemy.stompable:
				return O.STOMP
			if defense.claws and not enemy.claw_immune:
				return O.DEFEAT_ENEMY
		if defense.claws and not enemy.claw_immune and hazard.part != &"attack":
			return O.DEFEAT_ENEMY
	if defense.invulnerable or defense.god_mode:
		return O.IGNORE
	if defense.armor and (hazard.is_electrical or hazard.is_enemy_attack):
		return O.BLOCKED_ARMOR
	if defense.shield:
		return O.BLOCKED_SHIELD
	return O.KILL


# --- The player --------------------------------------------------------------------------------------

func _test_player() -> void:
	var loadout := Loadout.new()
	loadout.armor = true
	loadout.charges = {&"shield": 1}
	var world: RunWorld = sim.build_world(RunSim.layout(5, 600.0), loadout)
	var p: Player = world.player
	await _until(world, func() -> bool: return p.elapsed > 0.1, 1.0)
	world.score.add_credit(400)
	var thief: StandInThief = _spawn(world, 0)
	var events: Array[StringName] = []
	p.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	var robbed: Array[Hazard] = []
	p.robbed.connect(func(h: Hazard) -> void: robbed.append(h))
	var used: Array[StringName] = []
	p.item_used.connect(func(item: StringName) -> void: used.append(item))
	var armor_before: int = p.armor
	check(p.receive_hit(thief.box) == O.ROBBED and p.alive, "the player is robbed and lives")
	check(p.armor == armor_before and p.shield == 1 and used.is_empty() and is_zero_approx(p.invulnerable_left),
		"armor and shield untouched, nothing used up, no invulnerability given (%d armor, %d shield)" % [p.armor, p.shield])
	check(is_equal_approx(p.theft_immune_left, rules.theft_grace) and p.defense().theft_immune,
		"for %.1f s no theft can happen again" % rules.theft_grace)
	check(robbed == [thief.box] and events.count(&"robbed") == 1 and not events.has(&"died"), "robbed, told once (%s)" % [events])
	check(p.receive_hit(thief.box) == O.IGNORE and events.count(&"robbed") == 1 and world.score.thefts == 1,
		"the same touch a frame later robs nothing more")
	var shot := Hazard.new()
	shot.hazard_name = "test shot"
	shot.is_enemy_attack = true
	_nodes.append(shot)
	check(p.receive_hit(shot) == O.BLOCKED_ARMOR, "the theft window doesn't protect from a real hit")
	await _until(world, func() -> bool: return p.theft_immune_left <= 0.0, rules.theft_grace + 0.5)
	check(not p.defense().theft_immune and p.alive, "the window ends on the run's clock")
	await sim.free_world(world)


# --- The books -----------------------------------------------------------------------------------------

func _test_books() -> void:
	var world: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	var s: ScoreKeeper = world.score
	var a: StandInThief = _spawn(world, 1)
	var b: StandInThief = _spawn(world, 2)
	var seen: Array = []
	s.stolen.connect(func(amount: int, thief: Node3D) -> void: seen.append([amount, thief]))
	for v: int in [100, 100, 100, 100]:
		s.add_credit(v)
	var score_before: int = s.score
	check(s.rob(a, 0.25) == 100 and s.credits == 300 and s.held_by(a) == 100 and seen == [[100, a]],
		"a theft takes 25% of the credits collected this run (100 of 400), and the thief holds it")
	check(s.score == score_before, "the level score never drops (GDD §7: it's never spent)")
	check(s.rob(b, 0.25) == 75 and s.credits == 225 and s.held_by(b) == 75 and s.stolen_kept() == 175,
		"a second thief takes 25% of what the run holds now (75 of 300)")
	check(s.thefts == 2 and s.credits_stolen == 175, "both thefts are counted")
	var paid: Array = []
	s.recovered.connect(func(amount: int, jackpot: int, thief: Node3D) -> void: paid.append([amount, jackpot, thief]))
	check(s.pay_out(a, 100) == 200 and s.credits == 425 and s.held_by(a) == 0 and paid == [[100, 100, a]],
		"caught, a thief pays back what it held plus its jackpot, straight into the run's credits")
	check(s.score == score_before + 100 and s.stolen_kept() == 75 and s.credits_recovered == 100 and s.jackpots == 100,
		"the jackpot counts as collected; what came back was scored already")
	check(s.rob(a, 0.25) == 106, "the next theft takes 25% of the new total (106 of 425, rounded down)")
	check(s.pay_out(b, 0) == 75 and s.pay_out(b, 0) == 0, "a thief pays out once")

	# Rounding and edges.
	var w2: RunWorld = sim.build_world(RunSim.layout(3, 300.0))
	var t: StandInThief = _spawn(w2, 1)
	check(w2.score.rob(t, 0.25) == 0 and w2.score.thefts == 1 and w2.score.credits == 0, "with no credits a theft takes nothing")
	w2.score.add_credit(7)
	check(w2.score.rob(t, 0.25) == 1 and w2.score.credits == 6, "25% of 7 is 1: rounded down, in the player's favour")
	w2.score.credits = 1000
	check(w2.score.rob(t, 0.3) == 300 and w2.score.rob(t, 2.0) == 700 and w2.score.credits == 0,
		"a share is never rounded under (30% of 1000), and never takes more than the run holds")

	# Credits a thief takes off the track (task C5's collector): out of the stars' best score while held.
	var w3: RunWorld = sim.build_world(RunSim.layout(3, 300.0))
	var c: StandInThief = _spawn(w3, 1)
	w3.score.max_credit_score = 1000
	w3.score.hold(c, 80)
	check(w3.score.max_credit_score == 920 and w3.score.held_by(c) == 80 and w3.score.stolen_kept() == 0 and w3.score.credits == 0,
		"credits taken off the track: held, and out of the best possible score while held")
	var score3: int = w3.score.score
	w3.score.pay_out(c, 50)
	check(w3.score.max_credit_score == 1000 and w3.score.credits == 130 and w3.score.score == score3 + 130,
		"caught, they come back as collected (score and best score), with the jackpot")
	await sim.free_world(world)
	await sim.free_world(w2)
	await sim.free_world(w3)


# --- The pay and the stars --------------------------------------------------------------------------

func _test_pay_and_stars() -> void:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	ctx.level_index = 0
	var clean: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	var robbed: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	for w: RunWorld in [clean, robbed]:
		w.score.max_credit_score = 1000
		w.score.add_credit(750)
	var thief: StandInThief = _spawn(robbed, 1)
	robbed.score.rob(thief, 0.25)
	thief.retire()
	await tree.process_frame
	var bonus: int = rules.completion_bonus(0)
	var c_win := RunResult.from_world(clean, ctx, true, "", rules)
	var r_win := RunResult.from_world(robbed, ctx, true, "", rules)
	check(c_win.stars == 3 and r_win.stars == c_win.stars and r_win.score == c_win.score,
		"a theft never costs a star: the robbed run keeps the clean run's 3 stars (score %d / 1000)" % r_win.score)
	check(r_win.credits_collected == 750 and r_win.credits_stolen == 187 and r_win.credits_kept() == 563
		and r_win.credits_earned == 563 + bonus,
		"a thief that got away keeps what it took: completion pays what's left plus the bonus (%d)" % r_win.credits_earned)
	check(c_win.credits_stolen == 0 and c_win.credits_earned == 750 + bonus, "a clean run's pay is as before")
	var r_die := RunResult.from_world(robbed, ctx, false, "test hazard", rules)
	check(r_die.credits_earned == floori(563 * rules.death_credit_keep_fraction) and r_die.credits_earned == 112,
		"a death after a theft pays 20%% of what's left (%d of 563)" % r_die.credits_earned)
	var boss_ctx := RunContext.new()
	boss_ctx.mode = RunContext.Mode.CAMPAIGN
	boss_ctx.boss = DummyBoss.make_def([[1.0, 1, false, 0.0]])
	boss_ctx.boss.payout_credits = 300
	var b_win := RunResult.from_boss(robbed, null, boss_ctx, true, "", rules)
	var b_die := RunResult.from_boss(robbed, null, boss_ctx, false, "test hazard", rules)
	check(b_win.credits_earned == 563 + 300 and b_die.credits_earned == 112 and b_win.credits_stolen == 187,
		"a boss fight pays the same way (%d, %d)" % [b_win.credits_earned, b_die.credits_earned])
	check(int(r_win.stats.get("thefts", 0)) == 1 and int(r_win.stats.get("stolen_kept", 0)) == 187, "the stats count the theft")

	# The results screen: what was stolen sits under what was collected, so the pay adds up.
	r_die.context = ctx
	var screen := ResultsScreen.new()
	screen.result = r_die
	tree.root.add_child(screen)
	await tree.process_frame
	await tree.process_frame
	var texts: PackedStringArray = _label_texts(screen)
	check(texts.has("Stolen") and texts.has("−187") and texts.has("750"), "the results show the credits stolen (%s)" % ", ".join(texts))
	screen.queue_free()
	var clean_screen := ResultsScreen.new()
	clean_screen.result = RunResult.from_world(clean, ctx, false, "test hazard", rules)
	tree.root.add_child(clean_screen)
	await tree.process_frame
	check(not _label_texts(clean_screen).has("Stolen"), "and nothing about thefts after a run without one")
	clean_screen.queue_free()
	await tree.process_frame
	await sim.free_world(clean)
	await sim.free_world(robbed)


# --- Feedback ----------------------------------------------------------------------------------------

func _test_hud_and_sound() -> void:
	var world: RunWorld = sim.build_world(RunSim.layout(5, 1200.0))
	var p: Player = world.player
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	var hud := RunHud.new()
	tree.root.add_child(hud)
	hud.bind(world, ctx)
	var sounds: Array[StringName] = []
	world.sounds.requested.connect(func(sound: StringName) -> void: sounds.append(sound))
	await _until(world, func() -> bool: return p.elapsed > 0.1, 1.0)
	world.score.add_credit(400)
	await tree.process_frame
	hud.credits_counter.finish()
	var thief: StandInThief = _spawn(world, p.lane)
	var was_flashing: bool = Settings.flashing_reduced
	Settings.flashing_reduced = false
	p.receive_hit(thief.box)
	await tree.process_frame
	var counter: CreditCounter = hud.credits_counter
	check(counter.value == 300 and counter.displayed_value() > 300 and counter.is_counting(),
		"the HUD's credits count down to what's left (%d → %d)" % [counter.displayed_value(), counter.value])
	check(counter.loss_look() > 0.9, "in the loss colour, dipped (%.2f)" % counter.loss_look())
	var loss: Color = counter.get_theme_color(&"font_loss_color", &"CreditCounter")
	var skin := GreyboxSkin.new()
	var far: bool = true
	for c: Color in [skin.fence_color, skin.gap_edge_color, skin.sign_color, UiTheme.style().danger]:
		far = far and _hue_distance(loss, c) >= 0.08
	check(far, "the loss colour is no hazard colour and not the warning red (%s)" % loss)
	check(_popup_texts(hud).has("Robbed  −100"), "a pop-up says what went (%s)" % [_popup_texts(hud)])
	check((hud.get_node(^"HudRoot/SafeFrame/Message") as Label).text == "", "never the death message")
	check(sounds.has(&"robbed") and not sounds.has(&"died"), "the robbed sound plays, not the death's (%s)" % [sounds])
	check(world.effects.coins_in_flight() == 10, "10 coins stream from the runner to the thief (%d)" % world.effects.coins_in_flight())
	# The loss look only ever fades (no blink), and is gone with the stream.
	var prev: float = counter.loss_look()
	var rises: int = 0
	for i: int in 70:
		await tree.process_frame
		if counter.loss_look() > prev + 0.0001:
			rises += 1
		prev = counter.loss_look()
	check(rises == 0 and is_zero_approx(counter.loss_look()) and counter.displayed_value() == 300,
		"the loss look fades once and never blinks; the counter settles at 300")
	check(world.effects.coins_in_flight() == 0, "the coins have landed in the thief")

	# The catch: what it held and the jackpot come back.
	sounds.clear()
	thief.take_damage(1000.0, &"laser")
	await tree.process_frame
	var texts: PackedStringArray = _popup_texts(hud)
	check(counter.value == 500 and texts.has("Recovered  +100") and texts.has("Jackpot  +100"),
		"caught: the credits count back up with Recovered and Jackpot pop-ups (%s)" % [texts])
	check(sounds.has(&"jackpot"), "with the jackpot's sound (%s)" % [sounds])
	check(world.effects.coins_in_flight() == 16, "and a burst of coins flies into the runner (%d)" % world.effects.coins_in_flight())

	# Reduced flashing: softer.
	Settings.flashing_reduced = true
	p.theft_immune_left = 0.0
	var second: StandInThief = _spawn(world, p.lane)
	p.receive_hit(second.box)
	await tree.process_frame
	check(counter.loss_look() > 0.0 and counter.loss_look() <= CreditCounter.LOSS_REDUCED + 0.0001,
		"with Reduced flashing the loss look is softer (%.2f)" % counter.loss_look())
	Settings.flashing_reduced = was_flashing
	var library: SfxLibrary = load("res://data/audio/sfx_library.tres") as SfxLibrary
	check(library.has_file(&"robbed") and library.has_file(&"jackpot") and library.names().has("robbed")
		and library.names().has("jackpot"), "both sounds are in the library, with their files")
	hud.queue_free()
	await sim.free_world(world)


# --- The stand-in --------------------------------------------------------------------------------------

func _test_stand_in() -> void:
	var world: RunWorld = sim.build_world(RunSim.layout(6, 1500.0))
	var p: Player = world.player
	var thief: StandInThief = _spawn(world, 0)
	check(thief != null and thief.jackpot_credits == thief.tune.jackpot_credits and is_equal_approx(thief.box.steals_share, 0.25),
		"the stand-in declares the theft (25%) and its jackpot from its data")
	var model: MeshInstance3D = null
	for child: Node in thief.get_children():
		if child is MeshInstance3D:
			model = child
	var mat := model.material_override as StandardMaterial3D if model != null else null
	check(mat != null and not mat.emission_enabled and mat.albedo_color.r > mat.albedo_color.b + 0.4,
		"a plain gold block that never glows")
	var visual := AABB(Vector3(-0.5, 0.0, -0.5) * thief.tune.block_size, thief.tune.block_size)
	var hit := AABB(thief.box.position - thief.box.size * 0.5, thief.box.size)
	check(visual.encloses(hit), "its hitbox sits inside the block (forgiving)")
	# It crosses the lanes on its way in (aimed at the outer lane, all six of them), and is over the lane
	# it aims at when the runner gets there.
	var nearest: Array[float] = []
	for l: int in 6:
		nearest.append(INF)
	var at_meeting: Array[float] = [INF]
	await _until(world, func() -> bool:
		for l: int in 6:
			nearest[l] = minf(nearest[l], absf(thief.position.x - world.geo.lane_x(l)))
		if absf(thief.rel_ahead) < 0.15:
			at_meeting[0] = minf(at_meeting[0], absf(thief.position.x - world.geo.lane_x(0)))
		return thief.rel_ahead < -0.5, 8.0)
	var worst: float = 0.0
	for d: float in nearest:
		worst = maxf(worst, d)
	check(worst < 0.3, "it crosses all six lanes on its way in (furthest miss %.2f m)" % worst)
	check(at_meeting[0] < 0.3, "and is over the lane it aims at as the runner reaches it (%.2f m off)" % at_meeting[0])
	check(world.score.thefts == 0 and p.alive, "a runner in another lane is never touched")
	await sim.free_world(world)


## A runner who keeps to the stand-in's lane is robbed once; one who moves aside isn't. In the middle lane
## and an outer one.
func _test_robbed_on_physics(lanes: int) -> void:
	for lane: int in [lanes / 2, 0]:
		var r: Dictionary = await _rob_run(lanes, lane, 7, false)
		check(r["thefts"] == 1 and r["taken"] == 100 and r["alive"] and r["fled"],
			"%d lanes, lane %d: a runner who keeps to its lane is robbed once, of 25%% (%s)" % [lanes, lane, r])
		check(r["kept"] == 100 and r["credits"] == 300 and r["gone"], "it gets away with it (kept %d)" % r["kept"])
	var dodge: Dictionary = await _rob_run(lanes, lanes / 2, 7, true)
	check(dodge["thefts"] == 0 and dodge["credits"] == 400 and dodge["gone"],
		"%d lanes: a runner who moves aside isn't robbed (%s)" % [lanes, dodge])


## Plays a stand-in aimed at `lane` against a runner in it with 400 credits, who moves aside 1 s before
## it arrives if `dodge`. {thefts, taken, alive, fled, kept, credits, gone, at, trace}.
func _rob_run(lanes: int, lane: int, seed: int, dodge: bool) -> Dictionary:
	var world: RunWorld = sim.build_world(RunSim.layout(lanes, 2500.0))
	var p: Player = world.player
	await _until(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	await _to_lane(world, lane)
	world.score.add_credit(400)
	var thief: StandInThief = _spawn(world, lane, seed)
	var out := {"thefts": 0, "taken": 0, "alive": true, "fled": false, "kept": 0, "credits": 0, "gone": false,
		"at": -1.0, "trace": []}
	world.score.stolen.connect(func(amount: int, _t: Node3D) -> void:
		out["taken"] = amount
		out["at"] = p.elapsed)
	var moved: Array[bool] = [false]
	var ref: WeakRef = weakref(thief)
	await _until(world, func() -> bool:
		var t := ref.get_ref() as StandInThief
		if t != null:
			(out["trace"] as Array).append(snappedf(t.position.x, 0.001))
			if t.state == StandInThief.State.FLEE:
				out["fled"] = true
			if dodge and not moved[0] and t.rel_ahead < t.tune.approach_speed:
				p.press(&"move_right" if lane < lanes - 1 else &"move_left")
				moved[0] = true
		return t == null, 16.0)
	out["thefts"] = world.score.thefts
	out["alive"] = p.alive
	out["kept"] = world.score.stolen_kept()
	out["credits"] = world.score.credits
	out["gone"] = ref.get_ref() == null and world.score.jackpots == 0
	await sim.free_world(world)
	return out


## Each way of catching it, on real physics: a stomp, the dash, the claws, a weapon, and a shot at one
## making off with what it took.
func _test_catches_on_physics() -> void:
	# A stomp: jump so the runner comes down on it.
	var world: RunWorld = sim.build_world(RunSim.layout(5, 2000.0))
	var p: Player = world.player
	await _until(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	world.score.add_credit(400)
	var thief: StandInThief = _spawn(world, p.lane)
	var ref: WeakRef = weakref(thief)
	var causes: Array[StringName] = []
	world.director.enemy_defeated.connect(func(_e: Enemy, cause: StringName) -> void: causes.append(cause))
	var jumped: Array[bool] = [false]
	await _until(world, func() -> bool:
		var t := ref.get_ref() as StandInThief
		if not jumped[0] and t != null and t.rel_ahead <= 3.3:
			p.press(&"jump")
			jumped[0] = true
		return t == null, 12.0)
	check(causes == [&"stomp"] and world.score.thefts == 0 and world.score.credits == 500 and world.score.jackpots == 100,
		"dropping onto it catches it: its jackpot, no theft (%s, %d credits)" % [causes, world.score.credits])
	await sim.free_world(world)

	# The dash and the claws: through it.
	for way: String in ["dash", "claws"]:
		world = sim.build_world(RunSim.layout(5, 2000.0))
		p = world.player
		await _until(world, func() -> bool: return p.elapsed > 0.05, 1.0)
		world.score.add_credit(400)
		ref = weakref(_spawn(world, p.lane))
		causes.clear()
		world.director.enemy_defeated.connect(func(_e: Enemy, cause: StringName) -> void: causes.append(cause))
		if way == "claws":
			p.claws = true
		var dashed: Array[bool] = [false]
		await _until(world, func() -> bool:
			var t := ref.get_ref() as StandInThief
			if way == "dash" and not dashed[0] and t != null and t.rel_ahead <= 2.0:
				p.start_dash(1.0, 0.0)
				dashed[0] = true
			return t == null, 12.0)
		check(causes == [StringName(way)] and world.score.thefts == 0 and world.score.credits == 500,
			"the %s catches it: its jackpot, no theft (%s)" % [way, causes])
		await sim.free_world(world)

	# A weapon shoots it on its way in.
	var armed := Loadout.new()
	armed.tiers = {&"weapon": 1}
	world = sim.build_world(RunSim.layout(5, 2000.0), armed)
	p = world.player
	await _until(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	ref = weakref(_spawn(world, p.lane))
	await _until(world, func() -> bool: return ref.get_ref() == null, 12.0)
	check(world.score.thefts == 0 and world.score.jackpots == 100 and world.score.credits == 100,
		"shot on its way in: caught, its jackpot (%d credits)" % world.score.credits)
	await sim.free_world(world)

	# Robbed, then shot as it makes off: everything it took comes back, plus the jackpot.
	world = sim.build_world(RunSim.layout(5, 2000.0))
	p = world.player
	await _until(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	world.score.add_credit(400)
	thief = _spawn(world, p.lane)
	await _until(world, func() -> bool: return world.score.thefts > 0, 10.0)
	await physics_frames(20)
	check(is_instance_valid(thief) and thief.state == StandInThief.State.FLEE and thief.position.y > thief.tune.hover + 0.5,
		"after its theft it makes off ahead and up")
	var held: int = world.score.held_by(thief)
	thief.take_damage(1000.0, &"laser")
	check(held == 100 and world.score.credits == 500 and world.score.stolen_kept() == 0 and world.score.credits_recovered == 100,
		"shot as it makes off: the 100 it took and the 100 jackpot come back (%d credits)" % world.score.credits)
	await sim.free_world(world)


## The same seed plays out the same way: the theft's moment, its amount and the stand-in's crossing.
func _test_determinism() -> void:
	var a: Dictionary = await _rob_run(5, 1, 11, false)
	var b: Dictionary = await _rob_run(5, 1, 11, false)
	check(a["thefts"] == 1 and a["at"] == b["at"] and a["taken"] == b["taken"] and a["trace"] == b["trace"],
		"the same every attempt (robbed at %.3f s both times, %d frames of its crossing alike)" % [a["at"], (a["trace"] as Array).size()])


## Quick play's --thief (debug builds): stand-ins come one after another, robbing even in god mode, with
## their numbers in F6.
func _test_quick_play() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = Profile.new()
	App.start_quick(PackedStringArray(["--thief", "--lanes=6", "--god", "--nofall"]))
	await physics_frames(5)
	var run: LevelRun = App.run
	check(run != null and run.context.review_thief and run.context.config.lane_count == 6, "--thief starts quick play with stand-ins")
	var world: RunWorld = run.world if run != null else null
	var spawned: Array[int] = [0]
	if world != null:
		world.director.enemy_spawned.connect(func(e: Enemy) -> void:
			if e.type_id == &"stand_in_thief":
				spawned[0] += 1)
		# The prototype level's pads and ramps may carry the runner off the floor as one arrives; the next
		# one tries again.
		await _until(world, func() -> bool: return world.score.thefts >= 1, 45.0)
		check(spawned[0] >= 1 and world.score.thefts >= 1 and world.player.alive,
			"a stand-in comes and robs the god-mode runner (%d sent, %d thefts by %.1f s)" % [spawned[0],
				world.score.thefts, world.player.elapsed])
		await _until(world, func() -> bool: return spawned[0] >= 2, 15.0)
		check(spawned[0] >= 2, "and another follows once it's gone")
		check(run.tuning_panel == null or (run.tuning_panel.find_slider("approach_speed") != null
			and run.tuning_panel.find_slider("theft_grace") != null), "its numbers and the theft window are in F6")
	App.profile = saved
	App.show_title()
	await tree.process_frame
	main.queue_free()
	App.main = null
	await tree.process_frame


# --- Helpers -------------------------------------------------------------------------------------------

## A stand-in thief aimed at `lane`, spawned through the director (as every thief must be).
func _spawn(world: RunWorld, lane: int, seed: int = 1) -> StandInThief:
	return world.director.spawn({"type": THIEF, "at": world.player.distance, "lane": lane, "seed": seed}) as StandInThief


## Steps the world until `condition` holds or `seconds` pass (starting the run if it hasn't started).
func _until(world: RunWorld, condition: Callable, seconds: float) -> bool:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func _to_lane(world: RunWorld, lane: int) -> void:
	var p: Player = world.player
	for i: int in 12:
		if p.lane == lane:
			break
		p.press(&"move_left" if lane < p.lane else &"move_right")
		await physics_frames(12)
	await physics_frames(6)


func _d(a: String = "", b: String = "") -> DamageRules.Defense:
	var d := DamageRules.Defense.new()
	for f: String in [a, b]:
		match f:
			"armor":
				d.armor = true
			"shield":
				d.shield = true
			"invulnerable":
				d.invulnerable = true
			"claws":
				d.claws = true
			"dashing":
				d.dashing = true
			"god":
				d.god_mode = true
			"theft_immune":
				d.theft_immune = true
	return d


## The protections in the bits of `mask`: armor, shield, invulnerable, claws, dashing, god mode, theft.
func _mask(mask: int) -> DamageRules.Defense:
	var d := DamageRules.Defense.new()
	d.armor = mask & 1 != 0
	d.shield = mask & 2 != 0
	d.invulnerable = mask & 4 != 0
	d.claws = mask & 8 != 0
	d.dashing = mask & 16 != 0
	d.god_mode = mask & 32 != 0
	d.theft_immune = mask & 64 != 0
	return d


func _enemy_part(part: StringName, attack: bool = false) -> Hazard:
	var e := Enemy.new()
	_nodes.append(e)
	var h := Hazard.new()
	h.enemy = e
	h.part = part
	h.is_enemy_attack = attack
	h.is_solid = not attack
	_nodes.append(h)
	return h


func _popup_texts(hud: RunHud) -> PackedStringArray:
	return _label_texts(hud.get_node(^"HudRoot/SafeFrame/Score").get_child(2))


func _label_texts(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for n: Node in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func _hue_distance(a: Color, b: Color) -> float:
	var d: float = absf(a.h - b.h)
	return minf(d, 1.0 - d)
