class_name Enemy
extends Node3D
## Base for every enemy and destructible (e.g. fence generators). An enemy type is a script at
## res://scripts/enemies/<type>.gd extending Enemy, with optional tuning at res://data/enemies/<type>.tres
## (see EnemyDirector). The generator places it as a layout entry {type, at, lane, side, seed, params}.
##
## Enemies declare properties and never decide damage themselves (CLAUDE.md principle 8):
## - hurting the player: own Hazard hitboxes (add_hitbox) and fire Projectiles (world.projectiles);
##   DamageRules resolves every contact.
## - being hurt: take_damage() from weapons, defeat() from contacts (stomp, claws, dash) or rules
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

# --- Declared properties (read by DamageRules, the weapon system and the score) ---------------
var type_id: StringName = &"enemy"
var display_name: String = "Enemy"
var max_health: float = 1.0
var health: float = 1.0
## Score for defeating it (GDD §7: enemy kills add to the level score).
var score_value: int = 100
## Weapons can't hurt it and auto-fire never targets it (e.g. the Bad Dream).
var immune_to_weapons: bool = false
## A cyborg carrying a Bad Dream: auto-fire never targets it and missile splash never hurts it (GDD §9.7).
var is_host: bool = false
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


## Auto-fire can pick this enemy (GDD §8: the weapon fires at the nearest valid target).
func targetable() -> bool:
	return alive and not immune_to_weapons and not is_host and is_inside_tree()


func health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)


## Weapon damage. `splash` damage never hurts hosts (GDD §9.7).
func take_damage(amount: float, source: StringName, splash: bool = false) -> void:
	if not alive or immune_to_weapons or (splash and is_host):
		return
	health -= amount
	health_changed.emit(self)
	if health <= 0.0:
		defeat(source)


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
