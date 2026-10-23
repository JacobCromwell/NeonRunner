class_name HeavyCyborg
extends Cyborg
## The Heavy Cyborg (GDD §9.16; owner, October 23, 2026; one of the Ice Lab's two new enemies, also in the Golden
## Zone): a bigger, bulkier, beefier cyborg carrying a big gatling (HeavyCyborgBody). It is a cyborg (Cyborg): it
## stands in a lane on the floor ahead, steps slowly toward the runner (heavier: HeavyCyborgTuning's walk) and drops
## behind once passed; it keeps the cyborgs' margins from every obstacle (CyborgRules), holds its fire at a runner
## riding a ceiling, and a teleport calls its stream under way off. No panic variant, never a host, no window
## version, and it never boards an Enforcer Truck (only a passed `cyborg` does).
## - Attack (HeavyCyborgGun): its gatling's stream, an attack like the heli drone's (GDD §9.6): an audible wind-up
##   (the barrels spin up and glow red, a red aim line on the runner), then it locks the runner's place and fires a
##   stream down that line, spaced so the runner can zigzag through and over within the hit invulnerability window,
##   dodged by switching lanes. It counts as a cyborg's small attack (owner): its stream takes one of the cyborgs'
##   places in the air (CyborgAirspace) and keeps their crossfire rule, so it fires when the other small enemies
##   fire, never waits for the big attacks' turns, and the big attacks never wait for it (is_major_attack_active
##   stays false: it takes no part in EnemyDirector's turns).
## - Kill (DamageRules reads the declared properties): a stomp on its head or the dash (owner); weapons take twice a
##   cyborg's laser hits (owner; and twice its missile hits, proposed: HeavyCyborgTuning); the claws don't kill it
##   (owner: claw_immune), so a claw runner who touches it is hit like anyone (proposed). Touching its body hurts as
##   touching a cyborg's does (solid: armor doesn't stop it), and a falling gantryway, an Octodog's lunge and a Buzz
##   Overdrive's charge destroy it as they destroy a cyborg (proposed). It pays twice a cyborg's score (proposed).
## Hitboxes, slightly smaller than its bigger body (the model is drawn bigger, never its hitboxes): a solid body
## (BODY_BOX) that ends below the stomp line, and a stompable top (TOP_BOX) at the height of its chest and shoulders,
## within a jump's reach (MovementTuning.jump_height: a jump's feet reach 1.6 m), wider than the cyborg's for a
## forgiving stomp; it starts above a standing runner's hurtbox, so only a jump touches it.
## Spawn params: fires (bool, default true; tests), health (float), stand (bool), hold_fire (Vector2), as a cyborg's.

## DESIGN-TBD (docs/questions/s1.md): the solid body (0 to 1.12 m), wider and deeper than a cyborg's, below the stomp
## line (the top's top less GameRules.stomp_tolerance).
const BODY_BOX := Vector3(0.7, 1.12, 0.45)
## DESIGN-TBD (docs/questions/s1.md): the stompable top, 1.18 to 1.6 m: its top at a jump's highest feet.
const TOP_BOX := Vector3(0.9, 0.42, 0.75)
const TOP_Y: float = 1.39
## Where its rounds leave the gatling, from its origin (gameplay: the drawn gatling turns and walks with the body;
## the rounds never depend on it): at the waist, a little to its right (world -x: it faces +z), and MUZZLE_REACH
## further along their line, at the drawn barrels' tips.
const MUZZLE_OFFSET := Vector3(-0.1, 0.95, 0.0)
const MUZZLE_REACH: float = 1.3

var heavy: HeavyCyborgTuning

## The gun's events (CyborgGun.events) looked at so far, for the muzzle's flash.
var _events_seen: int = 0


## A Heavy Cyborg's look as `entry`'s would be, for EnemyDirector.warm_up (which frees it): everything it shows later
## at once (the gatling's heat and ring, a muzzle flash, the aim line), so their materials are built with the level.
static func warm_up(world: RunWorld, entry: Dictionary) -> Node:
	var body := HeavyCyborgBody.new()
	body.build(world.skin.enemy_variant, false, false, int(entry.get("seed", 0)))
	body.show_everything()
	return body


## A Heavy Cyborg brings nothing else into play (never a host).
static func brings(_entry: Dictionary) -> Array[Dictionary]:
	return []


func _build() -> void:
	heavy = tuning_res as HeavyCyborgTuning
	if heavy == null:
		heavy = HeavyCyborgTuning.new()
	tuning = heavy
	var p: Dictionary = spawn.get("params", {})
	display_name = "heavy cyborg"
	# GDD §9.16: the claws don't kill it; a stomp on its head or the dash does (Enemy's defaults).
	claw_immune = true
	is_host = false
	is_panic = false
	if p.has("health"):
		max_health = float(p["health"])
	lane = clampi(int(spawn.get("lane", 0)), 0, world.geo.lane_count - 1)
	home = float(spawn.get("at", 0.0))
	position = world.lane_point(lane, home)
	stand = bool(p.get("stand", false))
	if p.get("hold_fire") is Vector2:
		hold_fire = p["hold_fire"]
	add_hitbox(&"body", BODY_BOX, Vector3(0.0, BODY_BOX.y * 0.5, 0.0))
	add_hitbox(&"top", TOP_BOX, Vector3(0.0, TOP_Y, 0.0))
	var heavy_body := HeavyCyborgBody.new()
	heavy_body.name = "Body"
	add_child(heavy_body)
	heavy_body.build(world.skin.enemy_variant, false, false, int(spawn.get("seed", 0)))
	# Drawn bigger than its zone's cyborgs, from its feet; the hitboxes and the muzzle point stay as they are.
	heavy_body.scale = Vector3.ONE * CyborgSuit.draw_scale(world.skin) * heavy.model_scale
	body = heavy_body
	gun = HeavyCyborgGun.new(self, world, heavy, rng, heavy_body)
	gun.muzzle_offset = MUZZLE_OFFSET
	gun.muzzle_reach = MUZZLE_REACH
	gun.enabled = bool(p.get("fires", true))
	gun.may_attack = _may_attack
	gun.hold = hold_fire
	_compute_limits()
	health_changed.connect(func(_e: Enemy) -> void: body.flash())


func _tick(delta: float) -> void:
	super(delta)
	if not alive:
		return
	var hb := body as HeavyCyborgBody
	var hg := gun as HeavyCyborgGun
	hb.firing = gun.state == CyborgGun.State.FIRING
	if gun.is_attacking():
		hb.show_aim_line(hg.aim_line_target(), hg.windup_progress())
	else:
		hb.hide_aim_line()
	# A round left the muzzle since the last tick (the gun logs each one): its flash.
	for i: int in range(_events_seen, gun.events.size()):
		if gun.events[i]["event"] == &"shot":
			hb.flash_muzzle()
	_events_seen = gun.events.size()


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 1.0, 0.0)


func hit_radius() -> float:
	return 0.75
