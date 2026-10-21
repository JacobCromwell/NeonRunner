extends TestSuite
## DamageRules as a pure function: every shared interaction rule from GDD §8–9.

const O = DamageRules.Outcome

var _nodes: Array[Node] = []


func run() -> void:
	var fence: Hazard = _hazard(false, false, true)
	# A plain solid: a truck's body, a boss's block, a wall.
	var solid: Hazard = _hazard(true, false, false)
	var sign_box: Hazard = _sign()
	var shot: Hazard = _hazard(false, true, false)
	var body: Hazard = _enemy_part(&"body")
	var top: Hazard = _enemy_part(&"top")
	var contact_body: Hazard = _enemy_part(&"body", true)
	var contact_top: Hazard = _enemy_part(&"top", true)
	var weak: Hazard = _enemy_part(&"weak_point")
	var slash: Hazard = _enemy_part(&"attack", true)

	check(DamageRules.resolve(fence, _d()) == O.KILL, "an unprotected player dies on a fence")
	fence.set_enabled(false)
	check(DamageRules.resolve(fence, _d()) == O.IGNORE, "an inactive hazard does nothing")
	fence.set_enabled(true)

	# Armor: electrical hazards and enemy attacks, never solid collisions (GDD §8), except one that declares
	# armor_blocks_solid: a sign (task K3, the owner's request), as a dash wall's crash.
	check(DamageRules.resolve(fence, _d("armor")) == O.BLOCKED_ARMOR, "armor blocks an electrical fence")
	check(DamageRules.resolve(shot, _d("armor")) == O.BLOCKED_ARMOR, "armor blocks an enemy shot")
	check(DamageRules.resolve(solid, _d("armor")) == O.KILL, "armor doesn't block a plain solid collision (a truck's body, a wall)")
	check(DamageRules.resolve(sign_box, _d("armor")) == O.BLOCKED_ARMOR, "armor takes a sign's hit (it declares armor_blocks_solid)")
	check(DamageRules.resolve(sign_box, _d()) == O.KILL, "a sign still kills a runner with no armor and no shield")
	check(DamageRules.resolve(body, _d("armor")) == O.KILL, "armor doesn't block a solid enemy body")
	# Barnacle contacts opt into the existing enemy-attack rule, while retaining body/top roles.
	check(DamageRules.resolve(contact_body, _d("armor")) == O.BLOCKED_ARMOR, "armor blocks an opted-in body contact")
	check(DamageRules.resolve(contact_top, _d("armor")) == O.BLOCKED_ARMOR, "armor blocks a non-stomp opted-in crown contact")
	check(DamageRules.resolve(contact_body, _d()) == O.KILL, "an opted-in body contact still kills without protection")
	check(DamageRules.resolve(contact_top, _d()) == O.KILL, "an opted-in crown contact still kills without protection")
	check(DamageRules.resolve(contact_body, _d("armor", "shield")) == O.BLOCKED_ARMOR,
		"armor precedes the shield on opted-in body contact")
	check(DamageRules.resolve(contact_body, _d("invulnerable")) == O.IGNORE,
		"a spent armor's grace ignores body contact")
	check(DamageRules.resolve(contact_top, _d("armor", "invulnerable")) == O.IGNORE,
		"grace ignores crown contact before consuming another armor charge")
	check(DamageRules.resolve(contact_body, _d("armor", "claws")) == O.DEFEAT_ENEMY,
		"claws still defeat an opted-in body before armor is used")
	check(DamageRules.resolve(contact_top, _d("armor", "claws")) == O.DEFEAT_ENEMY,
		"claws still defeat an opted-in crown before armor is used")
	check(DamageRules.resolve(contact_body, _d("armor", "dashing")) == O.DEFEAT_ENEMY,
		"the dash still defeats an opted-in body before armor is used")
	check(DamageRules.resolve(contact_top, _d("armor"), true) == O.STOMP,
		"a stomp still defeats an opted-in crown before armor is used")
	# Shield: anything.
	check(DamageRules.resolve(sign_box, _d("shield")) == O.BLOCKED_SHIELD, "the shield blocks a sign")
	check(DamageRules.resolve(solid, _d("shield")) == O.BLOCKED_SHIELD, "the shield blocks a plain solid")
	check(DamageRules.resolve(fence, _d("shield")) == O.BLOCKED_SHIELD, "the shield blocks a fence")
	check(DamageRules.resolve(fence, _d("armor", "shield")) == O.BLOCKED_ARMOR, "armor is used before the shield when it applies")
	check(DamageRules.resolve(sign_box, _d("armor", "shield")) == O.BLOCKED_ARMOR, "armor is used before the shield on a sign too")
	check(DamageRules.resolve(solid, _d("armor", "shield")) == O.BLOCKED_SHIELD, "the shield covers what armor can't")
	# Invulnerability window and god mode.
	check(DamageRules.resolve(fence, _d("invulnerable")) == O.IGNORE, "invulnerable players ignore hazards")
	check(DamageRules.resolve(sign_box, _d("armor", "invulnerable")) == O.IGNORE,
		"the invulnerability window ignores a sign before the armor takes another hit")
	check(DamageRules.resolve(sign_box, _d("god")) == O.IGNORE, "god mode ignores hazards")

	# Who goes on through a hazard after a block (task K3): a sign whose hit armor or the shield took, nothing else.
	check(DamageRules.lets_through(sign_box, O.BLOCKED_ARMOR) and DamageRules.lets_through(sign_box, O.BLOCKED_SHIELD),
		"a sign whose hit armor or the shield took lets the runner through the rest of it")
	check(not DamageRules.lets_through(sign_box, O.KILL) and not DamageRules.lets_through(sign_box, O.IGNORE),
		"nothing lets a runner through that wasn't blocked")
	var crash: Hazard = _hazard(true, false, false)
	crash.armor_blocks_solid = true
	check(not DamageRules.lets_through(fence, O.BLOCKED_ARMOR) and not DamageRules.lets_through(shot, O.BLOCKED_ARMOR)
		and not DamageRules.lets_through(solid, O.BLOCKED_SHIELD) and not DamageRules.lets_through(crash, O.BLOCKED_ARMOR)
		and not DamageRules.lets_through(body, O.BLOCKED_SHIELD),
		"nothing else does: a fence, a shot, a plain solid, a dash wall's crash, an enemy's body")

	# Dash: passes through obstacles and enemies' attacks, defeats enemies (GDD §8, §9.1).
	check(DamageRules.resolve(fence, _d("dashing")) == O.IGNORE, "the dash passes through a fence")
	check(DamageRules.resolve(sign_box, _d("armor", "dashing")) == O.IGNORE, "the dash passes through a sign, nothing used")
	check(DamageRules.resolve(shot, _d("dashing")) == O.IGNORE, "the dash passes through enemy fire")
	check(DamageRules.resolve(body, _d("dashing")) == O.DEFEAT_ENEMY, "the dash defeats an enemy it hits")
	(body.enemy as Enemy).dash_kills = false
	check(DamageRules.resolve(body, _d("dashing")) == O.IGNORE, "the dash passes safely through a dash-proof enemy (Bad Dream)")
	(body.enemy as Enemy).dash_kills = true
	_test_dash_hits_and_harmless_parts()

	# Stomps, spines and tentacles.
	check(DamageRules.resolve(top, _d(), true) == O.STOMP, "dropping onto a stompable enemy stomps it")
	check(DamageRules.resolve(top, _d(), false) == O.KILL, "running into its top without dropping is a collision")
	(top.enemy as Enemy).stompable = false
	check(DamageRules.resolve(top, _d(), true) == O.KILL, "landing on spines/tentacles without claws hurts")
	check(DamageRules.resolve(top, _d("claws"), true) == O.DEFEAT_ENEMY, "claws beat spines and tentacles")
	(top.enemy as Enemy).stompable = true
	check(DamageRules.resolve(weak, _d(), true) == O.STOMP, "stomping a weak point defeats its enemy")
	check(DamageRules.resolve(weak, _d(), false) == O.IGNORE, "touching a weak point otherwise is harmless")

	# Claws: any enemy on contact, except claw-immune ones and pure attack areas.
	check(DamageRules.resolve(body, _d("claws")) == O.DEFEAT_ENEMY, "claws defeat an enemy on contact")
	(body.enemy as Enemy).claw_immune = true
	check(DamageRules.resolve(body, _d("claws")) == O.KILL, "claws don't work on claw-immune enemies")
	(body.enemy as Enemy).claw_immune = false
	check(DamageRules.resolve(slash, _d("claws")) == O.KILL, "claws don't cancel an attack area")
	check(DamageRules.resolve(slash, _d("armor")) == O.BLOCKED_ARMOR, "armor blocks an attack area")

	(body.enemy as Enemy).alive = false
	check(DamageRules.resolve(body, _d()) == O.IGNORE, "a defeated enemy can't hurt")
	check(DamageRules.defeat_cause(O.STOMP, _d()) == &"stomp", "stomp cause")
	check(DamageRules.defeat_cause(O.DEFEAT_ENEMY, _d("dashing")) == &"dash", "dash cause")
	check(DamageRules.defeat_cause(O.DEFEAT_ENEMY, _d("claws")) == &"claws", "claws cause")

	for n: Node in _nodes:
		n.free()


## Task O3 (GDD §9.15, the Cybernetic Centipede): an enemy that takes two dashes (Enemy.dash_hits) is wounded by the
## first (WOUND_ENEMY, the dash passing safely) and defeated by the second; its harmless parts (Hazard.harmless: the
## body and legs, only its bite hurts) do nothing to a runner whatever they carry, but a dash through them still counts;
## its bite (an attack part) is one hit that armor or the shield absorbs, that claws don't cancel and a stomp can't land.
func _test_dash_hits_and_harmless_parts() -> void:
	var shell: Hazard = _enemy_part(&"body")
	shell.harmless = true
	shell.is_solid = false
	var bite: Hazard = _enemy_part(&"attack", true)
	bite.enemy = shell.enemy
	var e: Enemy = shell.enemy
	e.dash_hits = 2
	e.claw_immune = true
	e.stompable = false
	e.immune_to_weapons = true
	for defense: Array in [[], ["armor"], ["shield"], ["claws"], ["armor", "shield"], ["god"], ["invulnerable"]]:
		var d: DamageRules.Defense = _d(defense[0] if defense.size() > 0 else "", defense[1] if defense.size() > 1 else "")
		check(DamageRules.resolve(shell, d) == O.IGNORE and DamageRules.resolve(shell, d, true) == O.IGNORE,
			"a harmless part does nothing, touched or landed on (%s)" % [defense])
	check(DamageRules.resolve(shell, _d("dashing")) == O.WOUND_ENEMY, "the first of its two dashes wounds it")
	check(DamageRules.resolve(bite, _d("dashing")) == O.WOUND_ENEMY, "through its bite too: the dash passes safely")
	e.dash_wounds = 1
	check(DamageRules.resolve(shell, _d("dashing")) == O.DEFEAT_ENEMY and DamageRules.resolve(bite, _d("dashing")) == O.DEFEAT_ENEMY,
		"its second dash defeats it")
	e.dash_wounds = 0
	check(DamageRules.resolve(bite, _d()) == O.KILL, "its bite kills a runner with no armor and no shield")
	check(DamageRules.resolve(bite, _d("armor")) == O.BLOCKED_ARMOR, "armor absorbs a bite")
	check(DamageRules.resolve(bite, _d("shield")) == O.BLOCKED_SHIELD, "the shield absorbs a bite")
	check(DamageRules.resolve(bite, _d("claws")) == O.KILL, "claws don't stop a bite: a claw runner is bitten like anyone")
	check(DamageRules.resolve(bite, _d(), true) == O.KILL, "landing on its bite is no stomp")
	check(DamageRules.resolve(bite, _d("armor", "invulnerable")) == O.IGNORE, "the invulnerability window ignores a bite")
	# Every other enemy is as before: one dash defeats it.
	var plain: Hazard = _enemy_part(&"body")
	check((plain.enemy as Enemy).dash_hits == 1 and DamageRules.resolve(plain, _d("dashing")) == O.DEFEAT_ENEMY,
		"an enemy with the default dash_hits still falls to one dash")
	check(not plain.harmless, "hazards aren't harmless by default")


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
	return d


func _hazard(solid: bool, attack: bool, electrical: bool) -> Hazard:
	var h := Hazard.new()
	h.is_solid = solid
	h.is_enemy_attack = attack
	h.is_electrical = electrical
	_nodes.append(h)
	return h


## A sign as the track builds it (TrackBuilder._build_sign; test_sign_armor checks the built one): solid, a hit
## armor absorbs all the same, which lets the runner through after a block.
func _sign() -> Hazard:
	var h: Hazard = _hazard(true, false, false)
	h.armor_blocks_solid = true
	h.passes_after_block = true
	return h


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
