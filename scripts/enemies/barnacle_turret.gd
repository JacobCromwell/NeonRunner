class_name BarnacleTurret
extends Enemy
## The Barnacle Turret (GDD §9.8), the Marketplace's ceiling hazard (first in Marketplace 1). It hangs
## from a ceiling's underside over one of the lanes the ceiling covers, pops out as the player comes
## near (barnacle_emerge; a floor runner sees it too) and stays put. It fires only at a rider on its
## own ceiling, never down at the floor, the cyborgs' way (CyborgGun: a visible charge-up at its chest
## cannon with the barnacle_charge sound, a short burst of bolts in the pool's red enemy look, a reload
## pause), slightly more accurately than a cyborg (BarnacleTurretTuning).
## - Fairness (GDD §9.8: dodgeable within the ceiling's lanes): a burst starts, and each bolt fires,
##   only while the rider stays on the ceiling through the bolt's arrival and a lane beside theirs,
##   within the ceiling, is clear of turret bodies around it (_path_fair), so the rider always has a
##   lane to dodge into and, on a two-lane ceiling where that lane is the turret's own, room to switch
##   back out before passing it. Only one fires at a time (GDD §9.8, proposed): the cyborgs' airspace
##   (CyborgGun.AIRSPACE_META) holds every burst while another is in the air. Its burst is a small
##   attack, like a cyborg's: it doesn't take turns with the big ones (EnemyDirector).
## - Body (GDD §9.8: treated like the cyborg's): a solid body against the underside and a stompable
##   top below it, its crown, the top as a rider on the ceiling sees it (Hazard.upside_down). Running
##   into it is deadly unless shielded, clawed or dashing; armor doesn't help. A rider who jumps and
##   drops back onto its crown stomps it (Player._is_stomping on the ceiling), and the body ends at the
##   stomp line, so that rider only ever touches the crown. Weapons: its health is in plain laser tier
##   1 shots, 5 where it first appears (7 at laser tier 1, whose hit PowerupTuning.tier1_extra_shots
##   stretches, GDD §8), slightly more later. Armor and the shield block its bolts (enemy attacks).
## - Nothing of it reaches below REACH_BELOW under the underside: out of reach of a jump from a hover
##   truck's roof and of the highest wall run, so it never touches anyone who isn't on its ceiling, and
##   the floor route under its ceiling is what it was without it.
## - Looks (GDD §9.8): mechanical in most zones, a furry creature in Gangland and the Marketplace
##   (BarnacleTurretModel, from the skin's enemy_variant), with the same dome, cannon and hitboxes.
## barnacle_turret_rules.gd places it on the level's ceilings with its ceiling's span and lanes in its
## params. A boss's own ceiling (BossProps.ceiling) passes them to spawn_enemy, as The House will.
##
## Spawn params: hull_start, hull_end (its ceiling's track distances), first_lane, last_lane (its
## lanes; every lane when left out), fires (bool, default true; tests), health (float; tests).

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
## The death cause its bolts report.
const SHOT_NAME: String = "barnacle bolt"
## The solid body: from the underside down to the stomp line (the crown's far side minus
## GameRules.stomp_tolerance), a little smaller than the dome; it reaches a little forward over the
## cannon's housing.
const BODY_SIZE := Vector3(0.9, 0.34, 1.0)
const BODY_Z: float = 0.05
## The stompable crown: from just past the body to REACH_BELOW under the underside, wide and forgiving.
const TOP_FROM: float = 0.37
const REACH_BELOW: float = 0.8
const TOP_SIZE := Vector3(0.9, REACH_BELOW - TOP_FROM, 0.9)
## Where its bolts leave the cannon (from the mount point on the underside), and how much further
## along their line they start: the muzzle's tip (BarnacleTurretModel.MUZZLE).
const MUZZLE_OFFSET := Vector3(0.0, BarnacleTurretModel.CANNON_Y, 0.62)
const MUZZLE_REACH: float = 0.26

var tuning: BarnacleTurretTuning
var model: BarnacleTurretModel
var gun: CyborgGun
var lane: int = 0
## Its ceiling: the track distances it spans and the lanes it covers.
var hull_start: float = 0.0
var hull_end: float = 0.0
var first_lane: int = 0
var last_lane: int = 0
## Out of its hatch (it has started to pop out): its hitboxes are on, and weapons may target it.
var out: bool = false

var _emerge_t: float = 0.0
var _body_box: Hazard
var _top_box: Hazard


func _build() -> void:
	tuning = tuning_res as BarnacleTurretTuning
	if tuning == null:
		tuning = BarnacleTurretTuning.new()
	var p: Dictionary = spawn.get("params", {})
	display_name = "Barnacle Turret"
	var scaling: float = world.config.enemy_scaling if world.config != null else 0.0
	max_health = float(p["health"]) if p.has("health") else tuning.whole_health_at(scaling)
	lane = clampi(int(spawn.get("lane", 0)), 0, world.geo.lane_count - 1)
	var at: float = float(spawn.get("at", 0.0))
	_find_ceiling(p, at)
	position = Vector3(world.geo.lane_x(lane), world.tuning.ceiling_height, TrackGeometry.world_z(at))
	_body_box = add_hitbox(&"body", BODY_SIZE, Vector3(0.0, -BODY_SIZE.y * 0.5, BODY_Z))
	_top_box = add_hitbox(&"top", TOP_SIZE, Vector3(0.0, -(TOP_FROM + TOP_SIZE.y * 0.5), 0.0))
	_top_box.upside_down = true
	for box: Hazard in [_body_box, _top_box]:
		box.set_enabled(false)
	model = BarnacleTurretModel.new()
	model.name = "Model"
	add_child(model)
	model.build(world.skin.enemy_variant, int(spawn.get("seed", 0)))
	model.set_emerged(0.0)
	gun = CyborgGun.new(self, world, tuning, rng, model)
	gun.muzzle_offset = MUZZLE_OFFSET
	gun.muzzle_reach = MUZZLE_REACH
	gun.charge_sound = &"barnacle_charge"
	gun.shot_sound = &"barnacle_shot"
	gun.shot_name = SHOT_NAME
	gun.may_attack = _may_attack
	gun.path_rule = _path_fair
	gun.enabled = bool(p.get("fires", true))
	health_changed.connect(func(_e: Enemy) -> void: model.flash())


## Its ceiling from its params, else the layout's ceiling over its spot, else (a ceiling nobody
## described) the stretch it can engage over, every lane.
func _find_ceiling(p: Dictionary, at: float) -> void:
	var n: int = world.geo.lane_count
	var h: Dictionary = {}
	if not p.has("hull_start") and world.layout != null:
		h = world.layout.hull_at(at, lane)
	if p.has("hull_start"):
		hull_start = float(p["hull_start"])
		hull_end = float(p.get("hull_end", at))
		first_lane = int(p.get("first_lane", 0))
		last_lane = int(p.get("last_lane", n - 1))
	elif not h.is_empty():
		hull_start = float(h["start"])
		hull_end = float(h["end"])
		var lanes: Vector2i = world.layout.hull_lanes(h)
		first_lane = lanes.x
		last_lane = lanes.y
	else:
		hull_start = at - tuning.engage_distance
		hull_end = at + 1.0
		first_lane = 0
		last_lane = n - 1
	first_lane = clampi(first_lane, 0, n - 1)
	last_lane = clampi(last_lane, first_lane, n - 1)


func _tick(delta: float) -> void:
	var player: Player = world.player
	if not out:
		var lead: float = tuning.emerge_seconds * maxf(player.speed, 1.0)
		if player.distance >= track_distance() - lead:
			_emerge()
		return
	if _emerge_t < tuning.emerge_time:
		_emerge_t = minf(_emerge_t + delta, tuning.emerge_time)
		model.set_emerged(_emerge_t / maxf(tuning.emerge_time, 0.001))
	gun.update(delta)
	model.watch(player.hurtbox_aabb().get_center())


## Pops out of its hatch: its hitboxes switch on (well before anyone can reach it) and weapons may
## target it from now on.
func _emerge() -> void:
	out = true
	for box: Hazard in [_body_box, _top_box]:
		box.set_enabled(true)
	world.play_sfx_at(&"barnacle_emerge", aim_point())


func targetable() -> bool:
	return out and super()


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, -0.42, 0.0)


func hit_radius() -> float:
	return 0.55


func _on_defeated(cause: StringName) -> void:
	gun.stop()
	world.play_sfx_at(&"barnacle_death", aim_point())
	var pal: Dictionary = BarnacleTurretModel.PALETTES[BarnacleTurretModel.palette_key(model.variant)]
	world.effects.burst(aim_point(), pal["tip"] if model.creature else Kit.LED_COLOR, 18, 0.6)
	model.death_finished.connect(queue_free)
	model.die(cause)


## GDD §9.8: it fires only at a rider on its own ceiling who is still ahead of it, within reach.
func _may_attack() -> bool:
	var player: Player = world.player
	if not out or not player.alive or not player.running or player.surface != Player.Surface.CEILING:
		return false
	if player.distance < hull_start - 0.5 or player.distance > hull_end + 0.5:
		return false
	var ahead: float = track_distance() - player.distance
	return ahead > 0.0 and ahead <= tuning.engage_distance


## The rider's path around a bolt's arrival (`from_d` to `to_d`, CyborgGun's clear stretch around the
## impact) is fair on the ceiling: the rider is still on it past the stretch, and a lane beside theirs
## within the ceiling has no turret body near the stretch, to dodge into (GDD §9.8).
func _path_fair(from_d: float, to_d: float) -> bool:
	if to_d > hull_end - tuning.end_margin:
		return false
	var rider_lane: int = world.player.lane
	for n: int in [rider_lane - 1, rider_lane + 1]:
		if n < first_lane or n > last_lane:
			continue
		if not body_in_lane(n, from_d - tuning.body_reach, to_d + tuning.body_reach):
			return true
	return false


## True if a living turret on this one's ceiling (this one included) has its body in `lane` anywhere
## between track distances `from_d` and `to_d`.
func body_in_lane(in_lane: int, from_d: float, to_d: float) -> bool:
	var half: float = BODY_SIZE.z * 0.5
	for e: Enemy in world.director.active:
		var t := e as BarnacleTurret
		if t == null or not is_instance_valid(t) or not t.alive or t.lane != in_lane:
			continue
		if absf(t.hull_start - hull_start) > 0.01:
			continue
		var d: float = t.track_distance()
		if d + half >= from_d and d - half <= to_d:
			return true
	return false
