class_name DamageRules
extends RefCounted
## The single place that decides what touching a hazard does (CLAUDE.md, architecture principle 8).
## Hazards and enemies only declare properties (Hazard: is_electrical, is_enemy_attack, is_solid,
## part; Enemy: stompable, claw_immune, dash_kills, ...). The player's protection arrives as a
## Defense snapshot. Falls aren't hazards: the Player handles them (grapple hook, GDD §8).
##
## Order (GDD §8–9 shared rules):
## 1. Inactive hazards and already-defeated enemies do nothing.
## 2. The juggernaut dash passes through hazards and defeats enemies it hits (unless the enemy
##    declares dash_kills = false, like the Bad Dream, which it passes through safely).
## 3. Dropping onto an enemy's top stomps it if it's stompable; claws beat spines and tentacles.
##    A weak point stomped from above defeats its enemy and is harmless otherwise.
## 4. Claws defeat any enemy on body contact, except claw-immune ones (bosses, the Bad Dream).
## 5. Invulnerability (after a block or revive) and god mode ignore everything harmful.
## 6. Armor that is up blocks an electrical hazard or an enemy attack, never a solid collision.
## 7. The shield blocks one hit of anything.
## 8. Otherwise the player dies (one hit ends the run, GDD §4).
##
## The armor itself (GDD §4, §8) is a state with rules of its own, below (Armor): up with its hits left,
## or broken and coming back. The Player holds one and applies what resolve() says to it.

enum Outcome {
	IGNORE,          ## No effect: inactive, invulnerable, passed through, or a harmless part.
	BLOCKED_ARMOR,   ## Armor broke instead of the player; the invulnerability window follows.
	BLOCKED_SHIELD,  ## The shield broke instead of the player; the invulnerability window follows.
	KILL,            ## The player dies.
	DEFEAT_ENEMY,    ## The contact defeats the enemy (claws or dash); the player is unharmed.
	STOMP,           ## The player stomped the enemy: it's defeated and the player bounces.
}


## What protects the player at the moment of contact.
class Defense:
	## The armor is up (Armor.is_up()).
	var armor: bool = false
	var shield: bool = false
	var invulnerable: bool = false
	var claws: bool = false
	var dashing: bool = false
	var god_mode: bool = false


## `stomping`: the player is dropping onto the hazard from above (the Player decides that from
## its motion and the hazard's top).
static func resolve(hazard: Hazard, defense: Defense, stomping: bool = false) -> Outcome:
	if not hazard.is_active():
		return Outcome.IGNORE
	var enemy: Enemy = hazard.enemy
	if enemy != null and not enemy.alive:
		return Outcome.IGNORE

	if defense.dashing and hazard.dash_passes:
		if enemy != null and enemy.dash_kills:
			return Outcome.DEFEAT_ENEMY
		return Outcome.IGNORE

	if enemy != null:
		if hazard.part == &"weak_point":
			return Outcome.STOMP if stomping else Outcome.IGNORE
		if stomping and hazard.part == &"top":
			if enemy.stompable:
				return Outcome.STOMP
			if defense.claws and not enemy.claw_immune:
				return Outcome.DEFEAT_ENEMY
		if defense.claws and not enemy.claw_immune and hazard.part != &"attack":
			return Outcome.DEFEAT_ENEMY

	if defense.invulnerable or defense.god_mode:
		return Outcome.IGNORE
	if defense.armor and (hazard.is_electrical or hazard.is_enemy_attack):
		return Outcome.BLOCKED_ARMOR
	if defense.shield:
		return Outcome.BLOCKED_SHIELD
	return Outcome.KILL


## The cause name reported when a contact defeats an enemy.
static func defeat_cause(outcome: Outcome, defense: Defense) -> StringName:
	if outcome == Outcome.STOMP:
		return &"stomp"
	return &"dash" if defense.dashing else &"claws"


## The runner's armor (GDD §4 and §8, owner's playtest, September 30, 2026). Every level and boss fight
## starts with it, free; the shop's armor is an upgrade to it (GameRules: hits and wait per tier).
## - Up, with `hits` left: each contact resolve() answers BLOCKED_ARMOR (an enemy attack or an
##   electrical hazard) takes one hit (block()), and the Player gives the usual invulnerability.
## - When its last hit goes, it breaks, and it comes back whole `recharge_time` later, on the run's
##   clock: tick() advances the wait from the Player's physics step, so a pause (or a death) stops it,
##   and it's the same at any frame rate.
## - A pickup (GDD §10) brings it back whole at once, and a revive does too (restore()).
## A run whose loadout has no armor (a bare Loadout: tests and tools) starts without it (`carried`
## false); a pickup gives it.
## DESIGN-TBD (docs/questions/g3.md): armor worn by some hits gets nothing back until it breaks; a
## pickup taken while it's whole adds a hit, up to `pickup_extra_hits` over its count; a revive brings
## it back whole.
class Armor:
	## A wait this close to its end counts as over (float steps never land on exactly 0).
	const EPSILON: float = 0.0001

	## Hits it blocks before it breaks.
	var max_hits: int = 1
	## Seconds from breaking to coming back whole.
	var recharge_time: float = 30.0
	## Hits a pickup may add over max_hits while the armor is whole.
	var pickup_extra_hits: int = 1
	## The run has armor: its loadout's, or a pickup's.
	var carried: bool = false
	## Hits left now: 0 while it's broken (or not carried).
	var hits: int = 0
	## Seconds until it's back whole: above 0 only while it's broken and coming back.
	var recharge_left: float = 0.0

	func _init(p_max_hits: int = 1, p_recharge_time: float = 30.0, p_pickup_extra_hits: int = 1,
			p_carried: bool = false) -> void:
		max_hits = maxi(p_max_hits, 1)
		recharge_time = maxf(p_recharge_time, EPSILON)
		pickup_extra_hits = maxi(p_pickup_extra_hits, 0)
		carried = p_carried
		hits = max_hits if carried else 0

	## The armor for a run, from the rules' numbers for upgrade tier `tier` (0: the free armor), up
	## and whole if the run carries it.
	static func create(rules: GameRules, tier: int, p_carried: bool) -> Armor:
		var r: GameRules = rules if rules != null else GameRules.new()
		return Armor.new(r.armor_hits_at(tier), r.armor_recharge_at(tier), r.armor_pickup_extra_hits, p_carried)

	func is_up() -> bool:
		return hits > 0

	func is_recharging() -> bool:
		return hits <= 0 and recharge_left > 0.0

	## How far broken armor has come back, 0 as it breaks to 1 as it's back; 1 while nothing is coming
	## back (it's up, or there is none).
	func progress() -> float:
		if not is_recharging():
			return 1.0
		return clampf(1.0 - recharge_left / recharge_time, 0.0, 1.0)

	## One contact it blocked (resolve() answered BLOCKED_ARMOR). True if that was its last hit: it
	## broke, and its wait starts.
	func block() -> bool:
		if not is_up():
			return false
		hits -= 1
		if hits > 0:
			return false
		recharge_left = recharge_time
		return true

	## `delta` seconds of the run pass (the Player's physics step). True when it came back whole now.
	func tick(delta: float) -> bool:
		if not is_recharging():
			return false
		recharge_left -= delta
		if recharge_left > EPSILON:
			return false
		recharge_left = 0.0
		hits = max_hits
		return true

	## Back whole at once (a revive). True if anything changed. Armor the run doesn't carry stays away.
	func restore() -> bool:
		if not carried or hits >= max_hits:
			return false
		hits = max_hits
		recharge_left = 0.0
		return true

	## An armor pickup was taken: the armor is back whole at once (and carried from now on); taken
	## while it's whole, it adds a hit, up to pickup_extra_hits over its count. True if anything changed.
	func take_pickup() -> bool:
		carried = true
		if hits < max_hits:
			hits = max_hits
			recharge_left = 0.0
			return true
		if hits < max_hits + pickup_extra_hits:
			hits += 1
			return true
		return false

	## Tests and review tools: `count` hits up now, with no wait running (0: none, and nothing coming
	## back). Carried from then on if `count` is above 0.
	func set_hits(count: int) -> void:
		hits = maxi(count, 0)
		recharge_left = 0.0
		carried = carried or hits > 0
