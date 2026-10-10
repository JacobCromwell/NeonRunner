class_name ProjectilePool
extends Node3D
## Pools every shot in a run (CLAUDE.md: pool frequently spawned objects). Enemies fire with
## fire_enemy(); the player's weapon with fire_player(). Each physics frame the pool moves every
## live shot and sweeps it: enemy shots against the player's hitbox (resolved by DamageRules via
## Player.receive_hit), player shots against enemies (Enemy.take_damage, with splash).
##
## Enemy fire keeps one colour and shape language in every zone (CLAUDE.md readability rules):
## hot red bolts. Player fire is cool (cyan/white), so the two never read alike.

const POOL_SIZE: int = 96
const MAX_RANGE: float = 160.0

## Visual styles: mesh size, colour and glow per look.
const LOOKS: Dictionary = {
	&"enemy_bolt": {"size": Vector3(0.18, 0.18, 0.9), "color": Color(1.0, 0.15, 0.1), "energy": 4.0},
	&"enemy_shell": {"size": Vector3(0.45, 0.45, 0.8), "color": Color(1.0, 0.25, 0.05), "energy": 4.0},
	&"enemy_bullet": {"size": Vector3(0.12, 0.12, 0.5), "color": Color(1.0, 0.3, 0.2), "energy": 3.5},
	&"laser": {"size": Vector3(0.08, 0.08, 1.4), "color": Color(0.3, 0.9, 1.0), "energy": 4.0},
	&"laser_2": {"size": Vector3(0.13, 0.13, 1.6), "color": Color(0.75, 0.55, 1.0), "energy": 4.5},
	&"missile": {"size": Vector3(0.16, 0.16, 0.6), "color": Color(0.9, 0.95, 1.0), "energy": 3.0},
	&"heavy_missile": {"size": Vector3(0.24, 0.24, 0.8), "color": Color(0.8, 1.0, 1.0), "energy": 4.0},
}

signal enemy_hit(enemy: Enemy, damage: float, splash: bool)

var world: RunWorld
var _free: Array[Projectile] = []
var _live: Array[Projectile] = []
var _materials: Dictionary = {}
var _mesh: BoxMesh


func setup(p_world: RunWorld) -> void:
	world = p_world
	for p: Projectile in _live:
		_release(p)
	if _free.is_empty() and _live.is_empty():
		_mesh = BoxMesh.new()
		_mesh.size = Vector3.ONE
		for i: int in POOL_SIZE:
			var p := Projectile.new()
			p.mesh_instance = MeshInstance3D.new()
			p.mesh_instance.mesh = _mesh
			p.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(p.mesh_instance)
			p.visible = false
			add_child(p)
			_free.append(p)


## An enemy shot from `from` with world velocity `velocity` (the track is static in world space;
## remember the player runs toward -z). Returns the shot, or null if the pool is exhausted.
func fire_enemy(from: Vector3, velocity: Vector3, look: StringName = &"enemy_bolt",
		shot_name: String = "enemy fire", life: float = 4.0) -> Projectile:
	var p: Projectile = _take()
	if p == null:
		return null
	p.friendly = false
	p.hazard_name = shot_name
	p.is_enemy_attack = true
	p.is_solid = false
	p.enemy = null
	_launch(p, from, velocity, look, life)
	return p


## A player shot. `target` makes it home (missiles).
func fire_player(from: Vector3, velocity: Vector3, damage: float, look: StringName = &"laser",
		target: Enemy = null, turn_rate: float = 0.0, splash_radius: float = 0.0,
		splash_share: float = 0.0, swarm_multiplier: float = 1.0, life: float = 2.0) -> Projectile:
	var p: Projectile = _take()
	if p == null:
		return null
	p.friendly = true
	p.damage = damage
	p.target = target
	p.turn_rate = turn_rate
	p.splash_radius = splash_radius
	p.splash_share = splash_share
	p.swarm_multiplier = swarm_multiplier
	_launch(p, from, velocity, look, life)
	return p


func live_count() -> int:
	return _live.size()


func live_shots() -> Array[Projectile]:
	return _live.duplicate()


func _take() -> Projectile:
	if _free.is_empty():
		return null
	var p: Projectile = _free.pop_back()
	_live.append(p)
	return p


func _launch(p: Projectile, from: Vector3, velocity: Vector3, look: StringName, life: float) -> void:
	p.in_use = true
	p.velocity = velocity
	p.life = life
	p.look = look
	p.state = Hazard.State.ON
	p.position = from
	var style: Dictionary = LOOKS.get(look, LOOKS[&"enemy_bolt"])
	p.radius = maxf(style["size"].x, style["size"].y) * 0.5
	p.mesh_instance.scale = style["size"]
	p.mesh_instance.material_override = _material(look, style)
	_orient(p)
	p.visible = true
	if not p.contacted.is_connected(_on_contacted.bind(p)):
		p.contacted.connect(_on_contacted.bind(p))


func _release(p: Projectile) -> void:
	p.in_use = false
	p.visible = false
	p.target = null
	p.state = Hazard.State.OFF
	_live.erase(p)
	if not _free.has(p):
		_free.append(p)


func _physics_process(delta: float) -> void:
	if world == null or _live.is_empty():
		return
	var player: Player = world.player
	var player_box := AABB()
	var check_player: bool = player != null and player.alive
	if check_player:
		player_box = player.hurtbox_aabb()
		# Sweep the player's own motion this frame too: stretch the box back along +z.
		var motion: float = player.speed * delta
		player_box = player_box.merge(AABB(player_box.position + Vector3(0.0, 0.0, motion), player_box.size))
	for i: int in range(_live.size() - 1, -1, -1):
		var p: Projectile = _live[i]
		p.life -= delta
		if p.life <= 0.0 or not p.in_use:
			_release(p)
			continue
		if p.friendly and p.target != null and p.turn_rate > 0.0:
			_steer(p, delta)
		var from: Vector3 = p.position
		var to: Vector3 = from + p.velocity * delta
		p.position = to
		if player != null and absf(to.z - player.position.z) > MAX_RANGE:
			_release(p)
			continue
		if p.friendly:
			_hit_enemies(p, from, to)
		elif check_player and _segment_hits_box(from, to, player_box.grow(p.radius)):
			# An ignored hit (invulnerable, dashing) lets the shot fly on through.
			player.receive_hit(p)
			check_player = player.alive


func _on_contacted(_outcome: int, p: Projectile) -> void:
	if p.in_use:
		world.effects.burst(p.position, (LOOKS.get(p.look, LOOKS[&"enemy_bolt"]) as Dictionary)["color"], 10, 0.4)
		_release(p)


func _hit_enemies(p: Projectile, from: Vector3, to: Vector3) -> void:
	for e: Enemy in world.director.active:
		# A weapon-immune enemy (a fence generator, GDD §9.1; the Bad Dream) lets a shot pass through.
		# A host doesn't: weapons hit hosts (GDD §9.7, owner, October 8, 2026).
		if not is_instance_valid(e) or not e.alive or e.immune_to_weapons:
			continue
		var r: float = e.hit_radius() + p.radius
		if _segment_point_distance(from, to, e.aim_point()) > r:
			continue
		var dmg: float = p.damage * (p.swarm_multiplier if e.is_swarm else 1.0)
		e.take_damage(dmg, &"weapon")
		enemy_hit.emit(e, dmg, false)
		if p.splash_radius > 0.0:
			_splash(p, e)
		world.effects.burst(p.position, (LOOKS.get(p.look, LOOKS[&"laser"]) as Dictionary)["color"],
			18 if p.splash_radius > 0.0 else 8, 0.8 if p.splash_radius > 0.0 else 0.35)
		world.play_sfx_at(&"missile_explode" if p.splash_radius > 0.0 else &"enemy_hit", p.position)
		_release(p)
		return


func _splash(p: Projectile, direct: Enemy) -> void:
	for e: Enemy in world.director.active:
		# Splash never hurts a weapon-immune enemy either (a fence generator, GDD §9.1), and it doesn't
		# report the hit; it hurts a host like any other enemy (GDD §9.7).
		if e == direct or not is_instance_valid(e) or not e.alive or e.immune_to_weapons:
			continue
		if e.aim_point().distance_to(p.position) <= p.splash_radius:
			# The heavy missile's swarm bonus (GDD §8) also applies to its splash (FB 29).
			var dmg: float = p.damage * p.splash_share * (p.swarm_multiplier if e.is_swarm else 1.0)
			e.take_damage(dmg, &"weapon", true)
			enemy_hit.emit(e, dmg, true)


func _steer(p: Projectile, delta: float) -> void:
	if not is_instance_valid(p.target) or not p.target.alive:
		p.target = null
		return
	var want: Vector3 = (p.target.aim_point() - p.position).normalized() * p.velocity.length()
	var angle: float = p.velocity.angle_to(want)
	if angle > 0.0001:
		p.velocity = p.velocity.slerp(want, minf(1.0, p.turn_rate * delta / angle))
	_orient(p)


func _orient(p: Projectile) -> void:
	if p.velocity.length_squared() > 0.0001:
		var dir: Vector3 = p.velocity.normalized()
		var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		p.basis = Basis.looking_at(dir, up)


func _material(look: StringName, style: Dictionary) -> Material:
	if not _materials.has(look):
		_materials[look] = GreyboxMaterials.glow(style["color"], style["energy"])
	return _materials[look]


static func _segment_hits_box(a: Vector3, b: Vector3, box: AABB) -> bool:
	if box.has_point(a) or box.has_point(b):
		return true
	return box.intersects_segment(a, b) != null


static func _segment_point_distance(a: Vector3, b: Vector3, point: Vector3) -> float:
	var ab: Vector3 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.000001:
		return a.distance_to(point)
	var t: float = clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * t).distance_to(point)
