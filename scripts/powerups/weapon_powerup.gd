class_name WeaponPowerup
extends PowerupModule
## The weapon line (GDD §8). Fires automatically at the nearest valid target: the director's
## targets_ahead() never offers hosts or weapon-immune enemies, and fences aren't enemies, so
## auto-fire ignores them. Tiers (ProjectilePool looks):
##   1 laser, 2 enhanced laser (new colour, thicker, more damage), 3 missile (more damage, homes),
##   4 heavy missile (new look, large damage, splash that never hurts hosts, bonus vs swarm).
## Damage is in laser tier 1 shots (GDD §8 damage reference); fire interval, damage, shot speed,
## range, splash and homing come from PowerupTuning.
##
## Shots leave the player's right shoulder on whichever surface they're on. Auto-fire keeps track
## of its own shots in flight and doesn't waste more on an enemy they will already destroy, so a
## 15-health enemy takes exactly 15 laser shots at tier 2-4, and 17 at tier 1 (see damage(): tier 1
## alone stretches its per-shot hit, PowerupTuning.tier1_extra_shots, GDD §8's September 30, 2026
## playtest). Lasers lead moving targets; missiles home. With the weapon, enemies show health bars
## (EnemyHealthBars).

## ProjectilePool looks per tier.
const LOOKS: Array[StringName] = [&"laser", &"laser_2", &"missile", &"heavy_missile"]
## The shoulder mount in the player's body space (x right, y away from the surface, -z forward),
## as fractions of the visual body size (MovementTuning.visual_size): over the gold left arm, where
## Razor Echo's weapon sits (PlayerSuit).
const MOUNT := Vector3(-0.55, 0.8, -0.7)

var health_bars: EnemyHealthBars
var fx: WeaponFx
## The enemy the latest shot was fired at.
var last_target: Enemy
var shots_fired: int = 0
## Whether the weapon has a target in range right now.
var engaged: bool = false

var _cooldown: float = 0.0
## Own shots in flight: {shot: Projectile, target: Enemy, damage: float}.
var _in_flight: Array[Dictionary] = []
## Enemy instance id -> its aim point on the previous physics frame, and its velocity from that.
var _last_aim: Dictionary = {}
var _velocity: Dictionary = {}


func _build() -> void:
	tier = clampi(tier, 1, LOOKS.size())
	health_bars = EnemyHealthBars.new()
	health_bars.name = "HealthBars"
	add_child(health_bars)
	health_bars.setup(world)
	fx = WeaponFx.new()
	fx.name = "Fx"
	add_child(fx)
	fx.setup(world, self)
	world.projectiles.enemy_hit.connect(_on_enemy_hit)


func look() -> StringName:
	return LOOKS[tier - 1]


## This tier's per-shot damage, plain (`target == null`, e.g. for the HUD) or against a real target.
## Tier 1 alone (PowerupTuning.tier1_extra_shots, GDD §8) stretches its per-shot hit down against a
## target that takes more than one plain tier 1 shot to kill, so it takes that many more shots to
## bring down, without touching the target's health or any other tier: `target.max_health` split
## across its plain shot count (ceil(max_health / plain damage)) plus the extra. Left alone (plain
## damage) for a one-shot kill already (the sewer screech), an immune_to_weapons target (never
## offered anyway) and a boss part (GDD §10: a boss's weapon chip is its own rule,
## BossEncounter.weapon_share_cap, not this one).
func damage(target: Enemy = null) -> float:
	var plain: float = PowerupTuning.at_tier(world.powerup_tuning.weapon_damage, tier)
	var extra: int = world.powerup_tuning.tier1_extra_shots
	if tier != 1 or extra <= 0 or target == null or target.immune_to_weapons or target.is_boss \
			or target.max_health <= 0.0:
		return plain
	var plain_shots: int = ceili(target.max_health / plain - 0.0001)
	if plain_shots <= 1:
		return plain
	return target.max_health / float(plain_shots + extra)


func fire_interval() -> float:
	return maxf(PowerupTuning.at_tier(world.powerup_tuning.weapon_fire_interval, tier), 0.02)


func shot_speed() -> float:
	return maxf(PowerupTuning.at_tier(world.powerup_tuning.weapon_shot_speed, tier), 1.0)


## Missile tiers (3 and 4) home on their target.
func is_missile() -> bool:
	return tier >= 3


## The heavy missile (tier 4) splashes and gets the swarm bonus.
func is_heavy() -> bool:
	return tier >= 4


func physics_tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_resolve_shots()
	_track_motion(delta)
	var p: Player = world.player
	engaged = false
	if not p.alive or not p.running:
		return
	var target: Enemy = pick_target()
	engaged = target != null
	if target != null and _cooldown <= 0.0 and fire_at(target):
		_cooldown = fire_interval()


func visual_tick(delta: float) -> void:
	health_bars.update_bars(delta)
	fx.update(delta)


func stop() -> void:
	engaged = false


func hud_entry() -> Dictionary:
	return controller.make_hud_entry(id, tier, 1.0 - _cooldown / fire_interval(), engaged, -1)


## How far ahead this tier's shots reach (PowerupTuning.weapon_range: shorter for tier 1).
func range_m() -> float:
	return PowerupTuning.at_tier(world.powerup_tuning.weapon_range, tier)


## The nearest valid target in range that the shots already in flight won't destroy, or null.
func pick_target() -> Enemy:
	for e: Enemy in world.director.targets_ahead(muzzle_point(), range_m()):
		if incoming_damage(e) < e.health - 0.001:
			return e
	return null


## Damage this weapon's shots in flight will deal to `enemy` when they land.
func incoming_damage(enemy: Enemy) -> float:
	var total: float = 0.0
	for s: Dictionary in _in_flight:
		if s["target"] == enemy:
			total += float(s["damage"])
	return total


## Fires one shot at `target` now (auto-fire calls this; so can tests). False if the projectile
## pool is exhausted.
func fire_at(target: Enemy) -> bool:
	var t: PowerupTuning = world.powerup_tuning
	var from: Vector3 = muzzle_point()
	var speed: float = shot_speed()
	var aim: Vector3 = target.aim_point()
	var homing: bool = is_missile()
	if not homing:
		aim = _lead(target, from, aim, speed)
	var dir: Vector3 = aim - from
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var velocity: Vector3 = dir * speed
	if homing:
		# Leave the launcher angled away from the surface, then curve onto the target.
		var away: Vector3 = surface_basis(world.player) * Vector3.UP
		velocity = (dir + away * t.missile_launch_lift).normalized() * speed
	var closing: float = maxf(speed - world.player.speed, 8.0)
	var life: float = clampf(1.5 * (from.distance_to(aim) + 10.0) / closing, 1.0, 6.0)
	var heavy: bool = is_heavy()
	var swarm: float = t.swarm_bonus_multiplier if heavy else 1.0
	var dmg: float = damage(target)
	var shot: Projectile = world.projectiles.fire_player(from, velocity, dmg, look(),
		target if homing else null, t.missile_turn_rate if homing else 0.0,
		t.splash_radius if heavy else 0.0, t.splash_damage_share if heavy else 0.0, swarm, life)
	if shot == null:
		return false
	_in_flight.append({"shot": shot, "target": target, "damage": dmg * (swarm if target.is_swarm else 1.0)})
	last_target = target
	shots_fired += 1
	fx.muzzle_flash(dir)
	world.play_sfx(&"missile_fire" if homing else &"laser_fire")
	controller.fired.emit(tier)
	return true


## Where shots leave the player: the left shoulder (the gold arm's), turned with the player onto
## walls and the ceiling, lower while sliding.
func muzzle_point() -> Vector3:
	var p: Player = world.player
	if p.is_inside_tree():
		# The player model's shoulder weapon (it follows the pose and the roll onto walls/ceiling).
		return p.weapon_muzzle()
	var v: Vector3 = p.tuning.visual_size
	var local := Vector3(v.x * MOUNT.x, body_height(p) * MOUNT.y, v.z * MOUNT.z)
	return p.global_position + surface_basis(p) * local


## Drops shots that have landed or expired (the pool released them) and shots whose target is gone.
## Runs after the projectile pool in the same physics frame, so a released shot is always seen
## before the pool can hand it out again.
func _resolve_shots() -> void:
	for i: int in range(_in_flight.size() - 1, -1, -1):
		var s: Dictionary = _in_flight[i]
		var target: Variant = s["target"]
		if not (s["shot"] as Projectile).in_use or not is_instance_valid(target) or not (target as Enemy).alive:
			_in_flight.remove_at(i)


## Remembers where each enemy's aim point was, to estimate how it moves (for leading lasers).
func _track_motion(delta: float) -> void:
	var seen: Dictionary = {}
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive:
			continue
		var key: int = e.get_instance_id()
		var aim: Vector3 = e.aim_point()
		if _last_aim.has(key) and delta > 0.0:
			_velocity[key] = (aim - (_last_aim[key] as Vector3)) / delta
		_last_aim[key] = aim
		seen[key] = true
	if _last_aim.size() != seen.size():
		for key: Variant in _last_aim.keys():
			if not seen.has(key):
				_last_aim.erase(key)
				_velocity.erase(key)


## Where to aim a straight shot so it meets a moving target.
func _lead(target: Enemy, from: Vector3, aim: Vector3, speed: float) -> Vector3:
	var v: Vector3 = _velocity.get(target.get_instance_id(), Vector3.ZERO)
	if v.length_squared() < 0.0001:
		return aim
	var t: float = from.distance_to(aim) / speed
	for i: int in 2:
		t = from.distance_to(aim + v * t) / speed
	return aim + v * t


func _on_enemy_hit(enemy: Enemy, _damage: float, splash: bool) -> void:
	# Only the heavy missile splashes; show the blast once, on its direct hit.
	if is_heavy() and not splash and is_instance_valid(enemy):
		fx.blast(enemy.aim_point(), world.powerup_tuning.splash_radius)
	if is_instance_valid(enemy) and not enemy.alive:
		fx.kill_flash(enemy.aim_point())
