extends TestSuite
## DamageRules as a pure function: every shared interaction rule from GDD §8–9.

const O = DamageRules.Outcome

var _nodes: Array[Node] = []


func run() -> void:
	var fence: Hazard = _hazard(false, false, true)
	var sign_box: Hazard = _hazard(true, false, false)
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

	# Armor: electrical hazards and enemy attacks, never solid collisions (GDD §8).
	check(DamageRules.resolve(fence, _d("armor")) == O.BLOCKED_ARMOR, "armor blocks an electrical fence")
	check(DamageRules.resolve(shot, _d("armor")) == O.BLOCKED_ARMOR, "armor blocks an enemy shot")
	check(DamageRules.resolve(sign_box, _d("armor")) == O.KILL, "armor doesn't block a solid sign")
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
	check(DamageRules.resolve(fence, _d("shield")) == O.BLOCKED_SHIELD, "the shield blocks a fence")
	check(DamageRules.resolve(fence, _d("armor", "shield")) == O.BLOCKED_ARMOR, "armor is used before the shield when it applies")
	check(DamageRules.resolve(sign_box, _d("armor", "shield")) == O.BLOCKED_SHIELD, "the shield covers what armor can't")
	# Invulnerability window and god mode.
	check(DamageRules.resolve(fence, _d("invulnerable")) == O.IGNORE, "invulnerable players ignore hazards")
	check(DamageRules.resolve(sign_box, _d("god")) == O.IGNORE, "god mode ignores hazards")

	# Dash: passes through obstacles and enemies' attacks, defeats enemies (GDD §8, §9.1).
	check(DamageRules.resolve(fence, _d("dashing")) == O.IGNORE, "the dash passes through a fence")
	check(DamageRules.resolve(shot, _d("dashing")) == O.IGNORE, "the dash passes through enemy fire")
	check(DamageRules.resolve(body, _d("dashing")) == O.DEFEAT_ENEMY, "the dash defeats an enemy it hits")
	(body.enemy as Enemy).dash_kills = false
	check(DamageRules.resolve(body, _d("dashing")) == O.IGNORE, "the dash passes safely through a dash-proof enemy (Bad Dream)")
	(body.enemy as Enemy).dash_kills = true

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
