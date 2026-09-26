class_name BossPart
extends Enemy
## A boss's body in the run world (GDD §10): what the player sees, dodges, shoots and stomps. It is an
## Enemy the director runs, so the shared rules apply to it as to any enemy (CLAUDE.md principle 8):
## its hitboxes go through DamageRules, its shots through the projectile pool, and auto-fire targets
## it. What makes it a boss's is declared, never special-cased:
## - is_boss and claw_immune: claws never defeat it (GDD §8: bosses ignore claw contact kills);
## - dash_kills off: the juggernaut dash passes through it safely;
## - not stompable: only its weak points take stomps.
## Its health is the fight's (BossEncounter): weapon hits and weak-point stomps pass to the encounter,
## and nothing else defeats it. Splash damage doesn't count (a missile's direct hit already does).
##
## A boss script makes its parts with BossEncounter.add_part(): a subclass builds its look and hitboxes
## in _build() (add_hitbox for bodies and attacks, add_weak_point for the glowing red weak points, the
## hover truck's language) and usually leaves the moving to the encounter's pattern. The first part is
## the boss's body; others (claws, turrets) should declare is_obstacle, so the defeat counts one kill.

## The fight this part belongs to (set from the spawn entry's params before _build runs).
var encounter: BossEncounter
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


## Mirrors the fight's health, so auto-fire and anything reading enemy health see the boss's.
func sync_health() -> void:
	if encounter == null:
		return
	max_health = encounter.max_health
	health = encounter.health


func health_ratio() -> float:
	return encounter.health_ratio() if encounter != null else super.health_ratio()


## Weapon damage goes to the fight; it counts only while the boss can be hurt.
func take_damage(amount: float, source: StringName, splash: bool = false) -> void:
	if not alive or immune_to_weapons or splash or encounter == null:
		return
	encounter.damage(amount, source)
	health_changed.emit(self)


## Nothing defeats a boss's part but the end of the fight: contacts and rules are ignored until the
## encounter is beaten, which then defeats its parts.
func defeat(cause: StringName) -> void:
	if encounter != null and is_instance_valid(encounter) and not encounter.is_defeated():
		return
	super.defeat(cause)


## Auto-fire targets it only while the boss can be hurt (not during its entrance or a phase change).
func targetable() -> bool:
	return super.targetable() and encounter != null and encounter.is_vulnerable()


## A boss's part leaves play with its fight, never by falling behind.
func should_retire() -> bool:
	return encounter == null or not is_instance_valid(encounter)


## A weak point: a glowing red spot (a boss script draws it) where a stomp from above hurts the boss by
## its phase's stomp damage and bounces the player; touching it any other way is harmless. It works
## while the player dashes too. Boss scripts switch weak points on and off with
## set_weak_points_enabled(); the encounter switches them off while the boss can't be hurt.
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


func _on_weak_point_contacted(outcome: int, hazard: Hazard) -> void:
	if outcome == DamageRules.Outcome.STOMP and encounter != null:
		encounter.stomp_weak_point(self, hazard)
