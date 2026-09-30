extends TestSuite
## Free armor that comes back (GDD §4 and §8, owner's playtest, September 30, 2026; task G3): the
## armor's state and rules (DamageRules.Armor: its hits, a blocked hit, the break, the wait on the run's
## clock at any frame rate, a revive, a pickup, a run without armor); the free armor's and each upgrade
## tier's hits and waits from the data, alternating as GDD §8 says; in a run: a blocked hit with its
## invulnerability, back after exactly the wait and not while paused, a revive, armor pickups; the
## HUD's hits, ring and flash; the shop's upgrade line and prices from the data, and its texts; the
## save migration; and through the App on the real main scene, every level, retry, revive, boss fight,
## quick play and endless run starting with it, the upgrade and its equip toggle, and the web demo.

const TEST_BOSS_PATH: String = "res://data/bosses/test_boss.tres"

var sim: RunSim
var rules: GameRules


func run() -> void:
	sim = RunSim.new(tree, tuning)
	rules = load("res://data/tuning/game_rules.tres") as GameRules
	_test_state()
	_test_frame_rates()
	await _test_tiers()
	await _test_in_a_run()
	await _test_revive_and_pickups()
	await _test_hud()
	_test_shop_data()
	_test_migration()
	await _test_app()


func _shot() -> Hazard:
	var shot := Hazard.new()
	shot.hazard_name = "test shot"
	shot.is_enemy_attack = true
	return shot


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


# --- The armor's state ---------------------------------------------------------------------------

func _test_state() -> void:
	var a := DamageRules.Armor.create(rules, 0, true)
	check(a.carried and a.is_up() and a.hits == 1 and a.max_hits == 1 and is_equal_approx(a.recharge_time, 30.0),
		"the free armor: up, 1 hit, back 30 s after it breaks (GDD §4): %d hit, %.1f s" % [a.hits, a.recharge_time])
	check(a.hits == rules.armor_hits and is_equal_approx(a.recharge_time, rules.armor_recharge), "its numbers are the data's")
	check(is_equal_approx(a.progress(), 1.0) and not a.is_recharging(), "whole armor has nothing to wait for")
	check(a.block() and not a.is_up() and a.is_recharging() and is_equal_approx(a.recharge_left, 30.0),
		"its one hit breaks it, and its wait starts")
	check(is_zero_approx(a.progress()), "a broken armor's return starts at 0")
	check(not a.block() and a.hits == 0, "broken armor blocks nothing")
	check(not a.tick(15.0) and is_equal_approx(a.progress(), 0.5), "halfway back after half the wait")
	check(a.tick(15.0) and a.is_up() and a.hits == 1 and is_zero_approx(a.recharge_left),
		"back whole when the wait is over")
	check(not a.tick(100.0) and a.hits == 1, "whole armor stays as it is")
	a.block()
	check(a.restore() and a.is_up() and not a.is_recharging(), "a revive brings broken armor back whole at once (DESIGN-TBD)")
	check(not a.restore(), "and changes nothing on whole armor")

	# An upgraded armor with hits to spare (tier 3 of the data).
	var m := DamageRules.Armor.create(rules, 3, true)
	var hits: int = rules.armor_hits_at(3)
	check(hits >= 2 and m.hits == hits, "an upgraded armor starts with its tier's hits (%d)" % m.hits)
	check(not m.block() and m.hits == hits - 1 and m.is_up(), "it survives a hit, one hit down")
	check(not m.tick(1000.0) and m.hits == hits - 1, "worn armor gets nothing back until it breaks (DESIGN-TBD)")
	check(m.take_pickup() and m.hits == hits and not m.is_recharging(), "a pickup brings worn armor back whole")
	check(m.take_pickup() and m.hits == hits + 1, "on whole armor, a pickup adds a hit over its count (DESIGN-TBD)")
	check(not m.take_pickup() and m.hits == hits + rules.armor_pickup_extra_hits,
		"up to %d over, then nothing" % rules.armor_pickup_extra_hits)
	for i: int in hits:
		m.block()
	check(m.hits == 1 and m.block() and m.is_recharging(), "its last hit breaks it")
	check(m.tick(m.recharge_time) and m.hits == hits, "and it comes back to its own count, not the extra hit")
	m.block()
	for i: int in hits - 1:
		m.block()
	check(m.is_recharging() and m.take_pickup() and m.hits == hits and is_zero_approx(m.recharge_left),
		"a pickup on broken armor brings it back whole and ends the wait")

	# A run without armor (a bare loadout: tests and tools).
	var none := DamageRules.Armor.create(rules, 0, false)
	check(not none.carried and not none.is_up() and not none.is_recharging() and is_equal_approx(none.progress(), 1.0),
		"a run without armor has none, and nothing coming")
	check(not none.restore() and not none.tick(100.0) and not none.is_up(), "a revive or time gives it none")
	check(none.take_pickup() and none.carried and none.hits == none.max_hits, "a pickup gives it, whole")
	none.set_hits(0)
	check(not none.is_up() and not none.is_recharging(), "set_hits(0) (tests and tools): no hits, nothing coming back")
	none.set_hits(2)
	check(none.hits == 2 and none.is_up(), "set_hits(n): n hits up at once")


## On the run's clock, the same at any frame rate: the step that ends the wait brings it back.
func _test_frame_rates() -> void:
	for hz: int in [30, 60, 144, 240]:
		var a := DamageRules.Armor.create(rules, 0, true)
		a.block()
		var step: float = 1.0 / hz
		var ticks: int = 1
		while not a.tick(step) and ticks < 100000:
			ticks += 1
		check(ticks == roundi(a.recharge_time * hz), "at %d Hz it's back on step %d (%.4f s)" % [hz, ticks, ticks * step])
	var b := DamageRules.Armor.create(rules, 0, true)
	b.block()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t: float = 0.0
	var last: float = 0.0
	while true:
		last = rng.randf_range(0.004, 0.05)
		t += last
		if b.tick(last) or t > 100.0:
			break
	check(t >= b.recharge_time - DamageRules.Armor.EPSILON and t - last < b.recharge_time,
		"with uneven steps too: back on the step that reaches the wait (%.4f s)" % t)


## GDD §8: the shop's tiers alternate between one more hit and a shorter wait; the numbers are data.
func _test_tiers() -> void:
	var item: ShopItem = App.catalog.item(&"armor")
	check(item != null and item.kind == ShopItem.Kind.PERMANENT, "the shop's armor is a permanent upgrade (GDD §8)")
	if item == null:
		return
	check(item.tier_count() >= 1 and item.tier_count() == rules.armor_tier_hits.size()
		and item.tier_count() == rules.armor_tier_recharge.size(),
		"the data has hits and a wait for each of the shop's %d tiers" % item.tier_count())
	var previous := DamageRules.Armor.create(rules, 0, true)
	for t: int in range(1, item.tier_count() + 1):
		var a := DamageRules.Armor.create(rules, t, true)
		check(a.max_hits == rules.armor_tier_hits[t - 1] and is_equal_approx(a.recharge_time, rules.armor_tier_recharge[t - 1]),
			"tier %d: its hits and wait from the data (%d hits, %.1f s)" % [t, a.max_hits, a.recharge_time])
		var more_hits: bool = a.max_hits > previous.max_hits
		var shorter: bool = a.recharge_time < previous.recharge_time
		check(more_hits != shorter and more_hits == (t % 2 == 1) and a.max_hits >= previous.max_hits
			and a.recharge_time <= previous.recharge_time,
			"tier %d brings one more hit or a shorter wait, alternating (GDD §8)" % t)
		previous = a
	check(rules.armor_hits_at(99) == rules.armor_hits_at(item.tier_count()), "a tier past the data's last uses the last")
	# A run takes its tier's numbers (RunWorld builds the armor from the loadout).
	for t: int in [0, 2, item.tier_count()]:
		var loadout := Loadout.new()
		loadout.armor = true
		if t > 0:
			loadout.tiers[&"armor"] = t
		var world: RunWorld = sim.build_world(RunSim.layout(3, 400.0), loadout)
		var armor: DamageRules.Armor = world.player.armor_state
		check(armor.carried and armor.hits == rules.armor_hits_at(t) and is_equal_approx(armor.recharge_time, rules.armor_recharge_at(t)),
			"a run with the armor at tier %d starts with %d hits, back %.1f s after it breaks" % [t, armor.hits, armor.recharge_time])
		await sim.free_world(world)


# --- In a run ------------------------------------------------------------------------------------

func _test_in_a_run() -> void:
	var loadout: Loadout = Loadout.from_profile(Profile.new(), App.catalog, false)
	var world: RunWorld = sim.build_world(RunSim.layout(5, 2500.0), loadout)
	var p: Player = world.player
	check(p.armor == rules.armor_hits and p.armor_state.carried and is_equal_approx(p.armor_state.recharge_time, rules.armor_recharge),
		"a run from a fresh profile starts with the free armor (%d hit)" % p.armor)
	var events: Array[StringName] = []
	p.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	var used: Array[StringName] = []
	p.item_used.connect(func(item: StringName) -> void: used.append(item))
	var changes: Array[int] = [0]
	p.armor_changed.connect(func() -> void: changes[0] += 1)
	var back_at: Array[float] = [-1.0]
	p.movement_event.connect(func(kind: StringName) -> void:
		if kind == &"armor_back":
			back_at[0] = p.elapsed)
	await _until(world, func() -> bool: return p.elapsed > 0.5, 2.0)

	var wall := Hazard.new()
	wall.hazard_name = "test wall"
	wall.is_solid = true
	check(DamageRules.resolve(wall, p.defense()) == DamageRules.Outcome.KILL, "it doesn't stop a solid collision (GDD §8)")
	var shot := _shot()
	check(p.receive_hit(shot) == DamageRules.Outcome.BLOCKED_ARMOR and p.alive and p.armor == 0 and p.armor_state.is_recharging(),
		"an enemy attack breaks it, and the player lives")
	var t0: float = p.elapsed
	check(is_equal_approx(p.invulnerable_left, rules.hit_invulnerability), "with the usual invulnerability (GDD §4)")
	check(used == [&"armor"] and events.has(&"armor_break") and changes[0] == 1 and world.score.blocked == 1,
		"the break is told (item_used, armor_break, armor_changed) and counted as a blocked hit")
	check(not p.defense().armor, "broken armor covers nothing while it comes back")

	# A pause stops the wait.
	var left: float = p.armor_state.recharge_left
	tree.paused = true
	await physics_frames(30)
	check(p.armor_state.recharge_left == left and p.elapsed == t0, "a pause stops the wait (%.3f s left)" % p.armor_state.recharge_left)
	tree.paused = false
	await _until(world, func() -> bool: return back_at[0] >= 0.0, rules.armor_recharge + 2.0)
	check(back_at[0] >= 0.0 and absf(back_at[0] - t0 - rules.armor_recharge) < 0.001,
		"it comes back exactly %.0f s of the run after it broke (%.4f s)" % [rules.armor_recharge, back_at[0] - t0])
	check(p.alive and p.armor == rules.armor_hits and events.has(&"armor_back") and changes[0] == 2,
		"whole again, with its sound (armor_back) and armor_changed")
	check(p.receive_hit(wall) == DamageRules.Outcome.KILL and not p.alive, "and it still never stops a crash")
	shot.free()
	wall.free()
	await sim.free_world(world)


func _test_revive_and_pickups() -> void:
	var loadout: Loadout = Loadout.from_profile(Profile.new(), App.catalog, false)
	var world: RunWorld = sim.build_world(RunSim.layout(5, 3000.0), loadout)
	var p: Player = world.player
	var shot := _shot()
	await _until(world, func() -> bool: return p.elapsed > 0.2, 1.0)
	p.receive_hit(shot)
	p.call(&"_die", "test hazard")
	check(not p.alive and p.armor_state.is_recharging(), "the player dies with the armor broken")
	var left: float = p.armor_state.recharge_left
	await physics_frames(10)
	check(p.armor_state.recharge_left == left, "the wait doesn't run while the player is down")
	var changes: Array[int] = [0]
	p.armor_changed.connect(func() -> void: changes[0] += 1)
	p.revive()
	check(p.alive and p.armor == rules.armor_hits and not p.armor_state.is_recharging() and changes[0] == 1,
		"a revive brings the armor back whole (DESIGN-TBD)")

	# Armor pickups (GDD §10): placed as before; now they bring the armor back whole at once.
	p.invulnerable_left = 0.0
	p.receive_hit(shot)
	var taken: Array = []
	world.pickups.collected.connect(func(pickup: Pickup, gained: bool) -> void: taken.append([pickup.item, gained]))
	var gained: Array[StringName] = []
	p.item_gained.connect(func(item: StringName) -> void: gained.append(item))
	world.pickups.offer(&"armor")
	await _until(world, func() -> bool: return taken.size() >= 1, 6.0)
	check(taken == [[&"armor", true]] and p.armor == rules.armor_hits and not p.armor_state.is_recharging(),
		"an armor pickup brings broken armor back whole at once (%s)" % [taken])
	check(gained == [&"armor"] and world.loadout.picked_up.is_empty(), "the player gains it, and it's no stock charge")
	world.pickups.offer(&"armor")
	await _until(world, func() -> bool: return taken.size() >= 2, 6.0)
	check(taken.size() == 2 and taken[1] == [&"armor", true] and p.armor == rules.armor_hits + 1,
		"on whole armor a pickup adds a hit (DESIGN-TBD): %d" % p.armor)
	if rules.armor_pickup_extra_hits == 1:
		world.pickups.offer(&"armor")
		await _until(world, func() -> bool: return taken.size() >= 3, 6.0)
		check(taken.size() == 3 and taken[2] == [&"armor", false] and p.armor == rules.armor_hits + 1,
			"past the cap it's taken for nothing (%s)" % [taken])
	shot.free()
	await sim.free_world(world)


# --- HUD -----------------------------------------------------------------------------------------

func _test_hud() -> void:
	var loadout := Loadout.new()
	loadout.armor = true
	loadout.tiers[&"armor"] = 3
	var hits: int = rules.armor_hits_at(3)
	var world: RunWorld = sim.build_world(RunSim.layout(5, 1500.0), loadout)
	var p: Player = world.player
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	var hud := RunHud.new()
	tree.root.add_child(hud)
	hud.bind(world, ctx)
	await tree.process_frame
	await tree.process_frame
	var icon: CooldownIcon = hud.item_icons.get(&"armor")
	check(icon != null, "the HUD shows the armor")
	if icon == null:
		hud.queue_free()
		await sim.free_world(world)
		return
	check(icon.count == hits and icon.is_ready(), "with its hits (%d) and no ring" % icon.count)
	var flashes: Array[int] = [0]
	icon.became_ready.connect(func() -> void: flashes[0] += 1)
	var shot := _shot()
	p.receive_hit(shot)
	await tree.process_frame
	check(icon.count == hits - 1 and icon.is_ready(), "a hit it survives takes one off (%d)" % icon.count)
	for i: int in hits - 1:
		p.invulnerable_left = 0.0
		p.receive_hit(shot)
	await tree.process_frame
	check(icon.count == 0 and not icon.is_ready() and icon.charge() < 0.05, "broken: the ring starts to fill (%.2f)" % icon.charge())
	p.armor_state.recharge_left = p.armor_state.recharge_time * 0.5
	await tree.process_frame
	check(absf(icon.charge() - 0.5) < 0.02, "and fills as it comes back (%.2f at half the wait)" % icon.charge())
	var ring: Color = icon.get_theme_color(&"progress", &"CooldownIcon")
	var danger: Color = UiTheme.style().danger
	var hue_gap: float = absf(ring.h - danger.h)
	check(ring.is_equal_approx(UiTheme.style().accent) and minf(hue_gap, 1.0 - hue_gap) > 0.2,
		"in the kit's calm accent, far from its warning red")
	p.armor_state.recharge_left = 0.05
	await _until(world, func() -> bool: return p.armor_state.is_up(), 1.0)
	await tree.process_frame
	check(icon.count == hits and icon.is_ready() and flashes[0] == 1, "back whole: the ring is gone and the icon flashes once")
	# The power-up controller reports the same (hud_state).
	if world.powerups != null:
		var entry: Dictionary = {}
		for e: Dictionary in world.powerups.call(&"hud_state"):
			if e["id"] == &"armor":
				entry = e
		check(entry.get("charges", -1) == hits and entry.get("active", false) and is_equal_approx(float(entry.get("ready", 0.0)), 1.0)
			and entry.get("tier", 0) == 3, "hud_state: its hits, up, ready, its tier (%s)" % [entry])
		check(bool(world.powerups.call(&"equipment")["armor"]), "and the player model wears it again")
	shot.free()
	hud.queue_free()
	await sim.free_world(world)


# --- Shop and save -------------------------------------------------------------------------------

func _test_shop_data() -> void:
	var item: ShopItem = App.catalog.item(&"armor")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ShopCatalog.PATH))
	var json_tiers: Array = []
	for d: Variant in (raw as Dictionary)["items"]:
		if String((d as Dictionary).get("id", "")) == "armor":
			json_tiers = (d as Dictionary).get("tiers", [])
	check(json_tiers.size() == item.tier_count() and item.tier_count() == 4, "four upgrade tiers in the catalog (%d)" % item.tier_count())
	var last: int = 0
	for t: int in range(1, item.tier_count() + 1):
		var price: int = item.price_of(t, false)
		check(price == int((json_tiers[t - 1] as Dictionary)["price"]) and price > last,
			"tier %d costs the catalog's %d, more than the tier before" % [t, price])
		last = price
	check(not App.catalog.item(&"shield").kind == ShopItem.Kind.PERMANENT, "the shield stays a breakable (GDD §8)")
	# The texts carry the data's numbers.
	var base: String = ShopScreen.item_text(item, item.description, 0)
	check(base.contains("%d hit" % rules.armor_hits) and base.contains("%d s" % roundi(rules.armor_recharge)) and not base.contains("{"),
		"the shop says what the free armor does, with the data's numbers (%s)" % base)
	for t: int in range(1, item.tier_count() + 1):
		var text: String = ShopScreen.item_text(item, item.tier_description(t), t)
		check(text.begins_with("%d hits" % rules.armor_hits_at(t)) and text.contains("%d s" % roundi(rules.armor_recharge_at(t)))
			and not text.contains("{"), "tier %d's text: %s" % [t, text])
	check(ShopScreen.item_text(App.catalog.item(&"shield"), "Blocks {hits}", 0) == "Blocks {hits}", "other items' texts are left as they are")

	# Buying it tier by tier.
	var saved: Profile = App.profile
	App.profile = Profile.new()
	App.profile.add_earned(100000)
	var spent: int = 0
	for t: int in item.tier_count():
		var price: int = App.next_price(item)
		check(price == item.price_of(t + 1, App.mobile) and App.buy(&"armor") and App.profile.tier(&"armor") == t + 1,
			"buys armor tier %d for %d" % [t + 1, price])
		spent += price
	check(App.next_price(item) == -1 and not App.buy(&"armor") and App.profile.credits() == 100000 - spent,
		"the upgrade maxes out, and the prices were the catalog's")
	check(App.profile.stock(&"armor") == 0, "no armor stock is bought any more")
	var l: Loadout = App.make_loadout()
	check(l.has_armor() and l.armor and l.tier(&"armor") == item.tier_count(), "the next run carries the upgrade")
	App.profile.set_equipped(&"armor", false)
	l = App.make_loadout()
	check(l.has_armor() and l.armor and l.tier(&"armor") == 0,
		"switched off, the upgrade stays home and the free armor still comes (DESIGN-TBD)")
	App.profile = saved


func _test_migration() -> void:
	var v1: Dictionary = {"version": 1, "earned": 200, "purchased": 0, "lifetime_earned": 1000, "lifetime_spent": 800,
		"tiers": {"weapon": 1.0}, "stocks": {"armor": 3.0, "shield": 2.0}, "equip_off": {"armor": true, "magnet": true}}
	var p: Profile = Profile.from_dict(v1)
	check(p.stock(&"armor") == 0 and not p.stocks.has("armor"), "a version 1 save's armor stock is gone")
	check(Profile.V1_ARMOR_PRICE == 150 and p.earned == 200 + 3 * 150 and p.net_worth() == 650,
		"paid back in earned credits at the 150 each it cost (%d)" % p.earned)
	check(p.lifetime_spent == 800 - 450 and p.lifetime_earned == 1000, "the refund undoes the purchases in the totals")
	check(p.stock(&"shield") == 2 and p.tier(&"weapon") == 1 and not p.is_equipped(&"magnet"), "everything else is kept")
	check(p.is_equipped(&"armor"), "the old armor toggle goes, so an upgrade bought later starts switched on")
	var d: Dictionary = p.to_dict()
	check(int(d["version"]) == Profile.VERSION and Profile.VERSION == 2, "it saves as version 2")
	var again: Profile = Profile.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(again.earned == p.earned and again.lifetime_spent == p.lifetime_spent, "a version 2 save isn't paid back twice")
	var oldest: Profile = Profile.from_dict({"earned": 10, "stocks": {"armor": 1}})
	check(oldest.earned == 160 and oldest.stock(&"armor") == 0, "a save without a version counts as version 1")
	# Through the file on disk.
	var path: String = "user://test_g3_migration.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1))
	file.close()
	var loaded: Profile = SaveService.load_profile(path)
	check(loaded.earned == 650 and loaded.stock(&"armor") == 0, "SaveService loads a version 1 file migrated")
	check(SaveService.save_profile(loaded, path), "and saves it back")
	var reread: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(typeof(reread) == TYPE_DICTIONARY and int((reread as Dictionary)["version"]) == 2
		and SaveService.load_profile(path).earned == 650, "as version 2, paid once")
	SaveService.delete_save(path)


# --- Every run, through the App ------------------------------------------------------------------

func _test_app() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = Profile.new()

	App.start_level(App.campaign.step("city/1"))
	await physics_frames(5)
	_check_armor("a campaign level", 0)
	App.retry(App.run.context)
	await physics_frames(5)
	_check_armor("its retry", 0)
	# A revive (the item) brings broken armor back whole.
	App.profile.add_stock(&"revive", 1)
	var shot := _shot()
	App.run.world.player.receive_hit(shot)
	App.run.world.player.call(&"_die", "test hazard")
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame
	check(App.overlay is DeathScreen and App.run.world.player.armor_state.is_recharging(), "a death with the armor broken")
	App.revive_with_item()
	await physics_frames(3)
	_check_armor("a revive", 0)
	# The upgrade, and the equip toggle down to the free armor.
	App.profile.set_tier(&"armor", 2)
	App.start_level(App.campaign.step("city/2"))
	await physics_frames(5)
	_check_armor("a level with the armor upgrade at tier 2", 2)
	App.profile.set_equipped(&"armor", false)
	App.retry(App.run.context)
	await physics_frames(5)
	_check_armor("a retry with the upgrade switched off", 0)
	App.profile = Profile.new()

	# Boss fights: the zone's boss in the campaign, and quick play's.
	var boss_step: CampaignStep = App.campaign.step("city/boss")
	if boss_step != null and boss_step.boss != null and boss_step.boss.is_built():
		App.start_boss(boss_step)
		await physics_frames(5)
		check(App.run != null and App.run.context.is_boss(), "the City's boss fight starts")
		_check_armor("the City's boss fight", 0)
		App.retry(App.run.context)
		await physics_frames(5)
		_check_armor("its retry", 0)
	var test_def: BossDef = load(TEST_BOSS_PATH) as BossDef
	App.start_boss_quick(test_def)
	await physics_frames(5)
	_check_armor("a quick-play boss fight (the test boss grants armor: its upgrade's tier 1)", 1)
	App.start_quick()
	await physics_frames(5)
	_check_armor("quick play", 0)
	App.start_endless()
	await physics_frames(5)
	_check_armor("an endless run", 0)

	# The web demo (GDD §2): the same free armor, and the same upgrade in its shop.
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	App.start_level(App.campaign.step("city/1"))
	await physics_frames(5)
	_check_armor("the web demo's first level", 0)
	App.show_shop()
	await tree.process_frame
	await tree.process_frame
	var shop := App.screen as ShopScreen
	var card: ItemCard = shop.cards.get(&"armor") if shop != null else null
	check(card != null and card.max_tier == 4 and card.tier == 0 and card.price == App.catalog.item(&"armor").price_of(1, false)
		and card.stock == -1 and card.description.contains("30 s"),
		"the demo's shop sells the upgrade as a permanent line (%s)" % (card.description if card != null else "no card"))
	if card != null:
		App.profile.add_earned(5000)
		card.buy_pressed.emit(&"armor")
		await tree.process_frame
		await tree.process_frame
		check(App.profile.tier(&"armor") == 1 and card.tier == 1 and card.title == "Armor I" and card.equip_switch.visible
			and card.description.begins_with("Next: Armor II. %d hits" % rules.armor_hits_at(2)),
			"buying tier 1 shows it owned, with an equip switch and the next tier (%s)" % card.description)
	BuildFlavor.set_override(-1)

	shot.free()
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


## The App's current run started with its armor up and whole, with the numbers of upgrade tier `tier`.
func _check_armor(what: String, tier: int) -> void:
	var p: Player = App.run.world.player if App.run != null and App.run.world != null else null
	if p == null:
		check(false, "%s: no run" % what)
		return
	var a: DamageRules.Armor = p.armor_state
	check(p.alive and a.carried and a.is_up() and a.hits == rules.armor_hits_at(tier) and a.max_hits == rules.armor_hits_at(tier)
		and is_equal_approx(a.recharge_time, rules.armor_recharge_at(tier)) and App.run.context.loadout.has_armor(),
		"%s starts with the armor up (%d hits, back %.1f s after it breaks)" % [what, a.hits, a.recharge_time])
