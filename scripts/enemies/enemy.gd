class_name Enemy
extends Node3D
## Base for every enemy and destructible (e.g. fence generators). An enemy type is a script at
## res://scripts/enemies/<type>.gd extending Enemy, with optional tuning at res://data/enemies/<type>.tres
## (see EnemyDirector). The generator places it as a layout entry {type, at, lane, side, seed, params}.
##
## Enemies declare properties and never decide damage themselves (CLAUDE.md principle 8):
## - hurting the player: own Hazard hitboxes (add_hitbox) and fire Projectiles (world.projectiles);
##   DamageRules resolves every contact.
## - being hurt: take_damage() from weapons/NPC charges, defeat() from contacts (stomp, claws, dash) or rules
##   (baited into a gap, an EMP, ...).
## Every attack needs a visual and an audio warning before it can hurt (CLAUDE.md readability rules).
##
## Subclasses override _build() (visuals, hitboxes, declared properties), _tick(delta) (behaviour,
## called every physics frame while alive), and optionally _on_defeated(cause), should_retire(),
## aim_point() and hit_radius(). How far ahead it spawns comes from its EnemyTuning (spawn_lead).

signal defeated(enemy: Enemy, cause: StringName)
## Left play without being defeated (fell behind, dissolved, gave up).
signal retired(enemy: Enemy)
signal health_changed(enemy: Enemy)

## NPC friendly fire: defeat listeners must not award player kills, score or thief payouts.
const CHARGE_DAMAGE_CAUSE: StringName = &"enemy_charge"
## A flyer clears a standing dash wall's top by this much (metres), and climbs to it (and comes back down
## after) at this speed (m/s): dash_wall_lift (task H7a). DESIGN-TBD (docs/OPEN_QUESTIONS.md item 656).
const DASH_WALL_CLEARANCE: float = 1.2
const DASH_WALL_CLIMB_SPEED: float = 7.0

# --- Declared properties (read by DamageRules, the weapon system and the score) ---------------
var type_id: StringName = &"enemy"
var display_name: String = "Enemy"
var max_health: float = 1.0
var health: float = 1.0
## Score for defeating it (GDD §7: enemy kills add to the level score).
var score_value: int = 100
## Weapons can't hurt it and auto-fire never targets it (a fence generator, GDD §9.1; the Bad Dream).
var immune_to_weapons: bool = false
## A cyborg carrying a Bad Dream (GDD §9.7): killing it, by any means, releases the Bad Dream
## (Cyborg._release_bad_dream). Weapons hit hosts (owner, October 8, 2026, replacing the September 26
## rule that made hosts immune to all weapon damage): auto-fire targets a host like any other cyborg,
## shots and missile splash hurt it, and it shows a health bar, so a player who doesn't want a Bad Dream
## released switches the weapon off in the shop (the equip toggle, GDD §8). Declared for the rules that
## still tell hosts apart: only a stomp, the claws or the dash earn the host bonus (CyborgTuning), other
## enemies' charges pass a host by (charge_can_hurt), and hosts never board an Enforcer Truck.
var is_host: bool = false
## Destroyed by baiting other enemies' charges into it (GDD §9.13, the Enforcer Truck): an Octodog's lunge
## or a Buzz Overdrive's charge (_hurt_charge_contacts) defeats it although it's immune_to_weapons (weapons
## still never target or hurt it, direct or splash), and that defeat is the player's doing, a bait:
## ScoreKeeper counts it as the player's kill, with its score, unlike any other enemy a charge flattens
## (owner revision, October 3, 2026: NPC friendly fire grants nothing). Off for every other enemy: hosts and
## generators are never hurt by a charge (charge_can_hurt).
var charge_bait: bool = false
## Claw contact doesn't defeat it (bosses, the Bad Dream).
var claw_immune: bool = false
## Landing on its top defeats it. False = landing on it hurts unless the player has claws.
var stompable: bool = true
## The juggernaut dash defeats it on contact. False = the dash passes through it safely.
var dash_kills: bool = true
## Bosses ignore claw contact kills (GDD §8).
var is_boss: bool = false
## A destructible obstacle rather than a creature (fence generators): doesn't count as a kill.
var is_obstacle: bool = false
## Part of a swarm (the swarm boss's clusters): heavy missiles deal bonus damage (GDD §8).
var is_swarm: bool = false
## A thief (GDD §9.12, the Tithe Collector): credits it pays out on top of everything it holds when it's
## caught, by any defeat (a stomp, a shot, the dash, the claws). ScoreKeeper pays them; its hitboxes
## declare the theft itself (Hazard.steals_share). 0 for every other enemy.
var jackpot_credits: int = 0
## Its major attack (is_major_attack_active) never overlaps those of the types in exclusive_of,
## whether or not big attacks take turns (GameRules.big_attacks_take_turns): while it's on, they hold
## off starting theirs, and it holds its own while one of theirs is on (the Bad Dream, GDD §9.7:
## never at the same time as an Octodog charge sequence or a drone barrage). See
## EnemyDirector.major_attack_blocked().
var exclusive_major_attack: bool = false
## The types an exclusive major attack keeps apart from (empty: every type); its own type always.
var exclusive_of: Array[StringName] = []

# --- State ---------------------------------------------------------------------------------
var alive: bool = true
var world: RunWorld
## The layout entry this enemy was spawned from.
var spawn: Dictionary = {}
## This type's tuning resource (data/enemies/<type>.tres, an EnemyTuning), or null.
var tuning_res: Resource
## Seeded from the layout entry, so every attempt at a seed plays out the same way.
var rng := RandomNumberGenerator.new()

var _hitboxes: Array[Area3D] = []
var _charge_contact_hits: Dictionary = {}
var _charge_contact_query: PhysicsShapeQueryParameters3D
var _charge_contact_shape: ConvexPolygonShape3D


func setup(p_world: RunWorld, p_spawn: Dictionary, p_tuning: Resource) -> void:
	world = p_world
	spawn = p_spawn
	tuning_res = p_tuning
	rng.seed = int(p_spawn.get("seed", 0))
	_build()
	health = max_health


func _physics_process(delta: float) -> void:
	if alive and world != null:
		_tick(delta)


func _build() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


## Called once when defeated. The default plays the shared death effect and removes the enemy.
func _on_defeated(_cause: StringName) -> void:
	world.play_sfx_at(&"enemy_death", global_position)
	world.effects.burst(aim_point(), Color(1.0, 0.35, 0.2))
	queue_free()


## True when the enemy should leave play (the director retires it). Default: far behind the player.
func should_retire() -> bool:
	return world != null and world.player_distance() - track_distance() > 35.0


## Where the enemy is along the track, in metres (forward = +).
func track_distance() -> float:
	return -global_position.z


## The height a flyer must hold right now to clear the dash walls standing in its way (task H7a; GDD §9.14: a
## building across the street, MovementTuning.dash_wall_height tall), or 0 when none is: the wall's top plus
## DASH_WALL_CLEARANCE, from the moment a climb from `from_height` at DASH_WALL_CLIMB_SPEED must start for the
## flyer to be over the wall as its front reaches the face, until its body is past the wall's back. `at` is the
## flyer's track distance, `half_length` half its body's length along the track, and `closing_speed` how fast
## its body comes at the wall (the runner's speed for a flyer pacing them, more for one pulling away). A flyer
## ahead of the runner (the heli drone, the Resonator leaving, a fleeing Tithe Collector) climbs to it and back
## down past the wall, so none flies through a building. Only standing walls count: the runner breaks each one
## as they reach it, so a flyer ahead of them always meets it standing.
func dash_wall_lift(at: float, half_length: float, from_height: float, closing_speed: float) -> float:
	if world == null or world.layout == null or world.layout.dash_walls.is_empty():
		return 0.0
	var top: float = world.tuning.dash_wall_height + DASH_WALL_CLEARANCE
	var lead: float = maxf(top - from_height, 0.0) / DASH_WALL_CLIMB_SPEED * maxf(closing_speed, 1.0) + half_length
	for w: Dictionary in world.layout.dash_walls:
		if bool(w.get("smashed", false)):
			continue
		if at + lead >= float(w["start"]) and at - half_length <= float(w["end"]):
			return top
	return 0.0


## True if `front` (the front of a ground enemy ahead of the runner, moving away from them) has reached the face
## of a dash wall still standing between it and the runner (task H7a; GDD §9.14): it can't drive through a
## building, so it leaves play there (an Octodog running off ahead or pacing, a Buzz Overdrive speeding off after
## letting the runner pass). Only standing walls count, and the runner breaks each one as they reach it.
func dash_wall_reached(front: float) -> bool:
	if world == null or world.layout == null or world.layout.dash_walls.is_empty():
		return false
	var p: float = world.player_distance()
	for w: Dictionary in world.layout.dash_walls:
		if bool(w.get("smashed", false)):
			continue
		var face: float = float(w["start"])
		if face > p and front >= face:
			return true
	return false


## Where weapons aim and effects appear.
func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 0.8, 0.0)


## Radius used by weapon projectiles to decide whether they hit this enemy.
func hit_radius() -> float:
	return 0.7


## True while this enemy is in its "major attack" (a big attack, GDD §9), from the start of its
## warning until its last hazard is over: an Octodog's charge sequence, a drone's wind-up and
## barrage, a hover truck's rev and forward lurch or its cannon's charge and volley, the Bad Dream's
## chase. Shots it fires in one report themselves (EnemyDirector.note_attack_shot) and hold the
## attack's turn until they have passed the player. Big attacks take turns through the director
## (EnemyDirector.major_attack_blocked, docs/ARCHITECTURE.md, Enemies). The default: never.
func is_major_attack_active() -> bool:
	return false


## Auto-fire can pick this enemy (GDD §8: the weapon fires at the nearest valid target): anything alive
## but an immune_to_weapons enemy. A host is a target like any other cyborg (GDD §9.7, owner, October 8,
## 2026).
func targetable() -> bool:
	return alive and not immune_to_weapons and is_inside_tree()


func health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)


## True if another enemy's charge can hurt it (_hurt_charge_contacts, and take_damage with
## CHARGE_DAMAGE_CAUSE): never a host (DESIGN-TBD, docs/OPEN_QUESTIONS.md item 629: a charge is no weapon, so hosts
## kept their immunity to charges when weapons began to hit them, owner, October 8, 2026), nor an
## immune_to_weapons enemy unless it declares charge_bait (the Enforcer Truck, GDD §9.13). Bosses are left
## out by _hurt_charge_contacts itself (their parts keep their encounter's rules).
func charge_can_hurt() -> bool:
	return not is_host and (charge_bait or not immune_to_weapons)


## Weapon-compatible damage (also NPC charge contacts). A weapon (direct or splash alike) never hurts an
## immune_to_weapons enemy (a generator, GDD §9.1; the Bad Dream); a charge's contact hurts only what
## charge_can_hurt() allows (a charge_bait enemy despite its immunity, GDD §9.13; never a host).
func take_damage(amount: float, source: StringName, splash: bool = false) -> void:
	var immune: bool = (not charge_can_hurt()) if source == CHARGE_DAMAGE_CAUSE else immune_to_weapons
	if not alive or immune:
		return
	health -= amount
	health_changed.emit(self)
	# A small tolerance: weapon_damage is a PackedFloat32Array, so a shot count meant to land exactly
	# on 0 (GDD §8's shots to kill) can leave a hair of float32 rounding error above it.
	if health <= 0.001:
		defeat(source)


## Start each lunge/charge afresh. Only charge attackers allocate a swept contact query.
func _begin_charge_contacts() -> void:
	_charge_contact_hits.clear()
	if _charge_contact_query == null:
		_charge_contact_shape = ConvexPolygonShape3D.new()
		_charge_contact_shape.margin = 0.0
		_charge_contact_query = PhysicsShapeQueryParameters3D.new()
		_charge_contact_query.shape = _charge_contact_shape
		_charge_contact_query.collision_mask = TrackBuilder.LAYER_HAZARD
		_charge_contact_query.collide_with_areas = true
		_charge_contact_query.collide_with_bodies = false


## Call only for actual charging motion. The convex hull of a box's start/end corners is its exact
## translational sweep, including diagonal lunges (a merged AABB would hit things off that line).
## Victims need an active physical part: detached attacks/waves, electrical hazards and lane
## blockers aren't bodies. Damage uses the usual path, and only what charge_can_hurt() allows is a
## victim: never a host, and a weapon-immune enemy only if it declares charge_bait (the Enforcer Truck,
## GDD §9.13); any subclass damage rules apply; multiple body parts can hit a victim only once per charge.
## Boss parts keep their encounter-specific damage/progression rules, not ordinary lethal hits.
func _hurt_charge_contacts(hitbox: Hazard, previous: Transform3D) -> void:
	if not alive or _charge_contact_query == null or not hitbox.is_active():
		return
	var collision := hitbox.get_child(0) as CollisionShape3D
	if collision == null or collision.disabled or not collision.shape is BoxShape3D:
		return
	var box := collision.shape as BoxShape3D
	var current: Transform3D = collision.global_transform
	var start: Transform3D = current.affine_inverse() * previous * collision.transform
	var half: Vector3 = box.size * 0.5
	var corners := PackedVector3Array()
	for x: float in [-half.x, half.x]:
		for y: float in [-half.y, half.y]:
			for z: float in [-half.z, half.z]:
				var corner := Vector3(x, y, z)
				corners.append(corner)
				corners.append(start * corner)
	_charge_contact_shape.points = corners
	_charge_contact_query.transform = current
	for contact: Dictionary in get_world_3d().direct_space_state.intersect_shape(_charge_contact_query, 64):
		var victim_box := contact["collider"] as Hazard
		if victim_box == null or not victim_box.is_active() or victim_box.is_electrical \
				or victim_box.part not in [&"body", &"top", &"weak_point"]:
			continue
		var victim: Enemy = victim_box.enemy
		if not is_instance_valid(victim) or victim == self or not victim.alive \
				or not victim.charge_can_hurt() or victim.is_boss:
			continue
		var id: int = victim.get_instance_id()
		if _charge_contact_hits.has(id):
			continue
		_charge_contact_hits[id] = true
		victim.take_damage(victim.health, CHARGE_DAMAGE_CAUSE)


## Defeats the enemy (weapon, stomp, claws, dash, gap, emp, ...). Safe to call more than once.
func defeat(cause: StringName) -> void:
	if not alive:
		return
	alive = false
	for box: Area3D in _hitboxes:
		if box is Hazard:
			(box as Hazard).set_enabled(false)
		box.set_deferred(&"monitorable", false)
	defeated.emit(self, cause)
	_on_defeated(cause)


## An EMP went off (a fence generator was destroyed, GDD §9.1). Override to react: the Cyborg's Bad
## Dream dissolves (GDD §9.7). `center` and `radius` are in world space.
func on_emp(_center: Vector3, _radius: float) -> void:
	pass


## Removes the enemy from play without a defeat.
func retire() -> void:
	if not alive and not is_queued_for_deletion():
		queue_free()
		return
	alive = false
	retired.emit(self)
	queue_free()


## A box hitbox in this enemy's local space. `part`: &"body", &"top", &"weak_point" or &"attack".
## Body contact is solid (armor doesn't block it) unless `attack` is true.
func add_hitbox(part: StringName, box_size: Vector3, offset: Vector3, attack: bool = false,
		parent: Node3D = null) -> Hazard:
	var hazard := Hazard.new()
	hazard.hazard_name = display_name
	hazard.enemy = self
	hazard.part = part
	hazard.size = box_size
	hazard.is_enemy_attack = attack
	hazard.is_solid = not attack and part != &"weak_point"
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.collision_mask = 0
	hazard.monitoring = false
	hazard.position = offset
	(parent if parent != null else self).add_child(hazard)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	hazard.add_child(shape)
	_hitboxes.append(hazard)
	return hazard


## A solid side the player can't switch lanes into (GDD §9.3: truck sides are safe but solid).
func add_lane_blocker(box_size: Vector3, offset: Vector3, parent: Node3D = null) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER
	area.collision_mask = 0
	area.monitoring = false
	area.position = offset
	(parent if parent != null else self).add_child(area)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	area.add_child(shape)
	_hitboxes.append(area)
	return area
