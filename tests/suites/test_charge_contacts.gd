extends TestSuite
## Shared NPC charge contacts use real hitbox geometry, not lanes or weapon aim radii.

const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"

class ContactEnemy:
	extends Enemy

	var body: Hazard
	var top: Hazard
	var damage_calls: int = 0
	var sources: Array[StringName] = []
	var deaths: int = 0
	var reject_damage: bool = false

	func _build() -> void:
		max_health = 7.0
		body = add_hitbox(&"body", Vector3(0.6, 0.8, 0.6), Vector3(0.0, 0.4, 0.0))
		top = add_hitbox(&"top", Vector3(0.7, 0.2, 0.7), Vector3(0.0, 0.9, 0.0))

	func take_damage(amount: float, source: StringName, splash: bool = false) -> void:
		damage_calls += 1
		sources.append(source)
		if not reject_damage:
			super.take_damage(amount, source, splash)

	func _on_defeated(_cause: StringName) -> void:
		deaths += 1


var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	await _test_contact_and_attribution()
	await _test_non_victims()
	await _test_diagonal_sweep()
	await _test_once_per_charge()
	await _test_inactive_attacker()
	await _test_floor_cutter_victim()


func _world(layout: LevelLayout = null) -> RunWorld:
	var w: RunWorld = sim.build_world(layout if layout != null else RunSim.layout(5, 300.0), Loadout.new())
	w.set_physics_process(false)
	w.player.set_physics_process(false)
	return w


func _enemy(w: RunWorld, at: Vector3) -> ContactEnemy:
	var e := ContactEnemy.new()
	w.add_child(e)
	e.setup(w, {}, null)
	e.position = at
	e.set_physics_process(false)
	w.director.active.append(e)
	e.defeated.connect(w.director._on_defeated)
	return e


func _test_contact_and_attribution() -> void:
	var w: RunWorld = _world()
	var attacker: ContactEnemy = _enemy(w, Vector3(0.0, 0.0, -40.0))
	var victim: Enemy = w.director.spawn({"type": "dummy", "script": DUMMY, "lane": 2, "at": 40.0,
		"seed": 1, "params": {"health": 7.0}})
	victim.position = attacker.position
	victim.jackpot_credits = 60
	var victim_id: int = victim.get_instance_id()
	var lifecycle: Array[StringName] = []
	var deaths: Array[int] = [0]
	var hits: Array[int] = [0]
	var payouts: Array[int] = [0]
	w.director.enemy_defeated.connect(func(enemy: Enemy, cause: StringName) -> void:
		if enemy.get_instance_id() == victim_id:
			lifecycle.append(cause))
	victim.defeated.connect(func(_enemy: Enemy, _cause: StringName) -> void: deaths[0] += 1)
	victim.health_changed.connect(func(_enemy: Enemy) -> void: hits[0] += 1)
	w.score.recovered.connect(func(_credits: int, _jackpot: int, _thief: Node3D) -> void: payouts[0] += 1)
	w.score.credits = 40
	w.score.score = 17
	w.score.rob(victim, 0.5)
	var before: Dictionary = w.score.stats()
	await physics_frames(2)
	attacker._begin_charge_contacts()
	attacker._hurt_charge_contacts(attacker.body, attacker.body.global_transform)
	attacker._hurt_charge_contacts(attacker.top, attacker.top.global_transform)
	attacker._hurt_charge_contacts(attacker.body, attacker.body.global_transform)
	check(attacker.alive and attacker.damage_calls == 0, "a charge never hits its own parts")
	check(not victim.alive and deaths[0] == 1 and hits[0] == 1,
		"physical body/top contacts share one lethal damage call and one defeat")
	check(lifecycle == [Enemy.CHARGE_DAMAGE_CAUSE],
		"the real EnemyDirector relays exactly one NPC defeat for lifecycle listeners")
	var after: Dictionary = w.score.stats()
	for key: String in ["kills", "stomps", "score", "credits", "jackpots", "credits_recovered"]:
		check(after[key] == before[key], "NPC friendly fire grants no player " + key)
	check(after["bonuses"] == before["bonuses"], "NPC friendly fire grants no player bonus")
	check(after["stolen_kept"] == before["stolen_kept"], "NPC friendly fire doesn't cash out a thief")
	check(payouts[0] == 0, "NPC friendly fire emits no thief recovery/jackpot payout")
	await sim.free_world(w)


func _test_non_victims() -> void:
	var w: RunWorld = _world()
	var attacker: ContactEnemy = _enemy(w, Vector3(0.0, 0.0, -40.0))
	var same_lane: ContactEnemy = _enemy(w, Vector3(0.0, 0.0, -45.0))
	var beside: ContactEnemy = _enemy(w, Vector3(1.5, 0.0, -40.0))
	var overhead: ContactEnemy = _enemy(w, Vector3(0.0, 3.0, -40.0))
	var immune: ContactEnemy = _enemy(w, attacker.position)
	immune.immune_to_weapons = true
	var host: ContactEnemy = _enemy(w, attacker.position)
	host.is_host = true
	var boss: ContactEnemy = _enemy(w, attacker.position)
	boss.is_boss = true
	var electrical: ContactEnemy = _enemy(w, attacker.position)
	electrical.body.is_electrical = true
	electrical.top.is_electrical = true
	var dead: ContactEnemy = _enemy(w, attacker.position)
	dead.alive = false
	var inactive: ContactEnemy = _enemy(w, attacker.position)
	inactive.body.set_enabled(false)
	inactive.top.state = Hazard.State.WARNING
	var ranged: ContactEnemy = _enemy(w, attacker.position)
	ranged.body.part = &"attack"
	ranged.top.part = &"attack"
	var blocker: ContactEnemy = _enemy(w, Vector3(5.0, 0.0, -40.0))
	blocker.add_lane_blocker(Vector3.ONE, Vector3(-5.0, 0.5, 0.0))
	var hazard := Hazard.new()
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.position = attacker.position
	w.add_child(hazard)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	hazard.add_child(shape)
	await physics_frames(2)
	attacker._begin_charge_contacts()
	attacker._hurt_charge_contacts(attacker.body, attacker.body.global_transform)
	for victim: ContactEnemy in [same_lane, beside, overhead, immune, host, boss, electrical, dead, inactive, ranged, blocker]:
		check(victim.damage_calls == 0, "only an active, hittable, physical enemy contact receives charge damage")
	check(immune.alive and host.alive and electrical.alive and inactive.alive and ranged.alive,
		"weapon/host immunity, electricity, warnings and detached attacks survive a charge")
	await sim.free_world(w)


func _test_diagonal_sweep() -> void:
	var w: RunWorld = _world()
	var attacker: ContactEnemy = _enemy(w, Vector3(0.0, 0.0, -40.0))
	var crossed: ContactEnemy = _enemy(w, Vector3(2.0, 0.0, -42.0))
	var off_line: ContactEnemy = _enemy(w, Vector3(0.0, 0.0, -44.0))
	var above_line: ContactEnemy = _enemy(w, Vector3(2.0, 3.0, -42.0))
	await physics_frames(2)
	attacker._begin_charge_contacts()
	var from: Transform3D = attacker.body.global_transform
	attacker.position = Vector3(4.0, 0.0, -44.0)
	attacker._hurt_charge_contacts(attacker.body, from)
	check(not crossed.alive and crossed.damage_calls == 1,
		"fast diagonal motion hits a physical victim between both frame endpoints")
	check(off_line.alive and off_line.damage_calls == 0,
		"a victim inside the merged AABB but outside the actual diagonal sweep is not hit")
	check(above_line.alive and above_line.damage_calls == 0,
		"a victim above the sweep is safe even at the same track distance")
	await sim.free_world(w)


func _test_once_per_charge() -> void:
	var w: RunWorld = _world()
	var attacker: ContactEnemy = _enemy(w, Vector3(0.0, 0.0, -40.0))
	var victim: ContactEnemy = _enemy(w, attacker.position)
	victim.reject_damage = true
	await physics_frames(2)
	attacker._begin_charge_contacts()
	for i: int in 3:
		attacker._hurt_charge_contacts(attacker.body, attacker.body.global_transform)
		attacker._hurt_charge_contacts(attacker.top, attacker.top.global_transform)
	check(victim.alive and victim.damage_calls == 1,
		"persistent overlap and multiple parts don't retry a subclass-rejected hit during one charge")
	attacker._begin_charge_contacts()
	attacker._hurt_charge_contacts(attacker.body, attacker.body.global_transform)
	check(victim.damage_calls == 2, "a later charge can hit that victim once again")
	await sim.free_world(w)


func _test_inactive_attacker() -> void:
	var w: RunWorld = _world()
	var attacker: ContactEnemy = _enemy(w, Vector3(0.0, 0.0, -40.0))
	var victim: ContactEnemy = _enemy(w, attacker.position)
	await physics_frames(2)
	attacker._begin_charge_contacts()
	for state: Hazard.State in [Hazard.State.OFF, Hazard.State.WARNING]:
		attacker.body.state = state
		attacker._hurt_charge_contacts(attacker.body, attacker.body.global_transform)
	attacker.body.state = Hazard.State.ON
	(attacker.body.get_child(0) as CollisionShape3D).disabled = true
	attacker._hurt_charge_contacts(attacker.body, attacker.body.global_transform)
	(attacker.body.get_child(0) as CollisionShape3D).disabled = false
	attacker.alive = false
	attacker._hurt_charge_contacts(attacker.body, attacker.body.global_transform)
	check(victim.alive and victim.damage_calls == 0,
		"dead attackers, disabled hitboxes and warning/off hitboxes cannot inflict charge damage")
	await sim.free_world(w)


func _test_floor_cutter_victim() -> void:
	var cut: Dictionary = FloorCutPlan.make(2, 80.0, 30.0, 10.0, 30.0, tuning.run_speed, 20.0, 8.0)
	var layout: LevelLayout = RunSim.layout(5, 300.0)
	layout.cuts.append(cut)
	var w: RunWorld = _world(layout)
	w.player.distance = FloorCutPlan.charge_at(cut) + 3.0
	w.track.update(w.player.distance, 0.0)
	var cutter: Enemy = w.director.spawn({"type": "floor_cutter", "lane": 2, "at": 80.0, "seed": 1})
	cutter.set_physics_process(false)
	cutter._tick(0.0)
	cutter._tick(0.0)
	var blade := cutter.get(&"_hitbox") as Hazard
	check(blade != null and blade.part == &"body" and blade.is_enemy_attack and not blade.is_solid,
		"the floor cutter's physical blade is a body while retaining its armor-blockable attack flag")
	for protection: String in ["", "armor", "shield", "claws", "dashing", "invulnerable", "god_mode"]:
		var defense := DamageRules.Defense.new()
		if protection != "":
			defense.set(protection, true)
		for stomping: bool in [false, true]:
			var physical: DamageRules.Outcome = DamageRules.resolve(blade, defense, stomping)
			blade.part = &"attack"
			var original: DamageRules.Outcome = DamageRules.resolve(blade, defense, stomping)
			blade.part = &"body"
			check(physical == original,
				"floor cutter body classification preserves player %s/stomp=%s contact rules" % [protection, stomping])
	var attacker: ContactEnemy = _enemy(w, cutter.position)
	var causes: Array[StringName] = []
	cutter.defeated.connect(func(_enemy: Enemy, cause: StringName) -> void: causes.append(cause))
	await physics_frames(2)
	var floor_cut: FloorCut = w.track.floor_cut(2, 80.0)
	check(floor_cut != null and floor_cut.began(), "the victim cutter has an actual mid-charge floor cut")
	var front: float = floor_cut.front if floor_cut != null else 0.0
	attacker._begin_charge_contacts()
	attacker._hurt_charge_contacts(attacker.body, attacker.body.global_transform)
	check(not cutter.alive and causes == [Enemy.CHARGE_DAMAGE_CAUSE],
		"a physical charge contact defeats the floor cutter through the normal NPC damage path")
	check(floor_cut != null and floor_cut.stopped and is_equal_approx(floor_cut.front, front),
		"NPC charge defeat invokes the cutter's usual hook and stops its cut at the death front")
	check(w.score.kills == 0 and w.score.score == 0, "the cutter's NPC defeat grants no player kill reward")
	await sim.free_world(w)
