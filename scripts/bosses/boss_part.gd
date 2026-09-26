class_name BossPart
extends Enemy
## A piece of a boss in the run world (GDD §10): a body the player sees, dodges, shoots and stomps.
## It is an Enemy the director runs, so the shared rules apply to it as to any enemy (CLAUDE.md
## principle 8): its hitboxes go through DamageRules, its shots through the projectile pool, and
## auto-fire targets it. What makes it a boss's is declared, never special-cased:
## - is_boss and claw_immune: claws never defeat it (GDD §8: bosses ignore claw contact kills);
## - dash_kills off: the juggernaut dash passes through it safely;
## - not stompable: only its weak points take stomps (add_weak_point);
## - immune_to_weapons, is_swarm and the rest as for any enemy (Sleep Taker is immune to weapons;
##   the Sewer Swarm's clusters are a swarm, so the heavy missile's bonus applies).
##
## Two kinds of part:
## - the boss's body (shares_health, the default): its health is the fight's. Weapon hits pass to the
##   encounter (BossEncounter.damage) and nothing defeats it until the fight is won;
## - a part with health of its own (shares_health off: the Sewer Swarm's clusters): weapons hurt it
##   like any enemy, a boss script may defeat it (baited into a fence or a hole), and the encounter
##   hears of it (BossEncounter._on_part_defeated) to hurt the boss or move the fight on.
## Every part passes an EMP to the encounter (BossEncounter._on_part_emp: Sleep Taker's weakness).
##
## Boss scripts make parts with BossEncounter.add_part(): a subclass builds its look and hitboxes in
## _build() (add_hitbox for bodies and attacks, add_weak_point for the glowing red weak points,
## add_surface for a top to land on or an underside to ride) and usually leaves the moving to the
## encounter's pattern. Parts other than the boss's body should declare is_obstacle, so the win counts
## one kill.

## The fight this part belongs to (set from the spawn entry's params before _build runs).
var encounter: BossEncounter
## The fight's health (the boss's body), or health of its own (a swarm cluster).
var shares_health: bool = true
## Its weak points: hitboxes where a stomp from above hurts the boss (DamageRules: STOMP).
var weak_points: Array[Hazard] = []


func _init() -> void:
	is_boss = true
	claw_immune = true
	dash_kills = false
	stompable = false
	# The encounter scores the win (BossDef.defeat_score).
	score_value = 0


func setup(p_world: RunWorld, p_spawn: Dictionary, p_tuning: Resource) -> void:
	var params: Dictionary = p_spawn.get("params", {})
	encounter = params.get("encounter") as BossEncounter
	if encounter != null and encounter.def != null:
		display_name = encounter.def.display_name
	super.setup(p_world, p_spawn, p_tuning)
	sync_health()


## Mirrors the fight's health on the boss's body, so auto-fire and anything reading enemy health
## see the boss's.
func sync_health() -> void:
	if encounter == null or not shares_health:
		return
	max_health = encounter.max_health
	health = encounter.health


func health_ratio() -> float:
	if encounter != null and shares_health:
		return encounter.health_ratio()
	return super.health_ratio()


## Weapon damage: to the fight for the boss's body (only while the boss can be hurt), to the part
## itself otherwise.
func take_damage(amount: float, source: StringName, splash: bool = false) -> void:
	if not shares_health:
		if encounter != null and not encounter.is_vulnerable():
			return
		super.take_damage(amount, source, splash)
		return
	if not alive or immune_to_weapons or splash or encounter == null:
		return
	encounter.damage(amount, source)
	health_changed.emit(self)


## The boss's body is defeated only by the end of the fight: contacts and rules are ignored until the
## encounter is won, which then defeats its parts. A part with health of its own falls like any enemy
## and tells the encounter.
func defeat(cause: StringName) -> void:
	var fighting: bool = encounter != null and is_instance_valid(encounter) and not encounter.is_defeated()
	if shares_health and fighting:
		return
	var was_alive: bool = alive
	super.defeat(cause)
	if was_alive and fighting:
		encounter.part_defeated(self, cause)


## An EMP went off (a fence generator destroyed nearby): the encounter decides what it does.
func on_emp(center: Vector3, radius: float) -> void:
	if encounter != null and is_instance_valid(encounter):
		encounter.part_hit_by_emp(self, center, radius)


## Auto-fire targets it only while the boss can be hurt (not during its entrance or a phase change,
## nor once weapons have done all they may: BossDef.weapon_share_cap).
func targetable() -> bool:
	if not super.targetable() or encounter == null or not encounter.is_vulnerable():
		return false
	return not shares_health or encounter.weapons_can_hurt()


## A boss's part leaves play with its fight, never by falling behind (the swarm strikes from behind
## too). A boss script retires a part itself when it's done with it.
func should_retire() -> bool:
	return encounter == null or not is_instance_valid(encounter)


## A weak point: a glowing red spot (the boss script draws it, the hover truck's language) where a
## stomp from above hurts the boss by its phase's hit damage and bounces the player; touching it any
## other way is harmless, and it works while the player dashes too. Boss scripts switch weak points on
## and off with set_weak_points_enabled() (the jackpot hopper, a coupling over a gap, a docking clamp);
## the encounter switches them off while the boss can't be hurt.
func add_weak_point(box_size: Vector3, offset: Vector3, parent: Node3D = null) -> Hazard:
	var hazard: Hazard = add_hitbox(&"weak_point", box_size, offset, false, parent)
	hazard.hazard_name = "%s's weak point" % display_name
	hazard.dash_passes = false
	hazard.contacted.connect(_on_weak_point_contacted.bind(hazard))
	weak_points.append(hazard)
	return hazard


func set_weak_points_enabled(on: bool) -> void:
	for hazard: Hazard in weak_points:
		hazard.set_enabled(on)


func weak_points_enabled() -> bool:
	for hazard: Hazard in weak_points:
		if hazard.is_active():
			return true
	return false


## A solid surface the player can stand on (`ceiling` off: a pinned ship's top, the hover truck's
## roof) or ride underneath like a ceiling section (`ceiling` on: a gunship's belly, reached by an
## anti-grav pad). It moves with the part. Box in the part's local space (or `parent`'s).
func add_surface(box_size: Vector3, offset: Vector3, ceiling: bool = false, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = TrackBuilder.LAYER_HULL if ceiling else TrackBuilder.LAYER_FLOOR
	body.collision_mask = 0
	body.position = offset
	(parent if parent != null else self).add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	return body


## A stomp on the boss body's weak point is a hit on the boss. (A part with health of its own falls to
## the stomp like any enemy, which reaches the encounter as part_defeated.)
func _on_weak_point_contacted(outcome: int, hazard: Hazard) -> void:
	if outcome == DamageRules.Outcome.STOMP and encounter != null and shares_health:
		encounter.stomp_weak_point(self, hazard)
