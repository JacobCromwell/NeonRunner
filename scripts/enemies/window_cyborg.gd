class_name WindowCyborg
extends Enemy
## A window cyborg (GDD §9.2): the upper body of a cyborg leaning out of a window in a wall. A wall
## enemy: patterns place it with `side`, not lanes. It doesn't move; it shoots at the player with
## the cyborgs' arm cannon (CyborgGun: charge-up with a sound, bursts of 2–3, reload), sharing their
## airspace (CyborgAirspace: up to two bursts in the air at once, GDD §9.2). A runner on the far wall can
## only drop off into the outer lane below, so the crossfire rule keeps another burst's bolts from
## arriving there with its own (CyborgGun._crossfire_fair).
## - Touching it hurts, and armor doesn't stop that: its body is a solid hitbox (armor still blocks
##   its shots). Claws and the dash defeat it; there is nothing to stomp up there.
## - It sits at a fixed height: its body fills a band of wall-run heights centred on the free
##   wall-entry height (MovementTuning.wall_entry_height + band_offset), so wall-entry timing decides
##   whether a wall runner passes above (a jump or ramp entry) or below (entering early enough to
##   have slid down), GDD §3.
## - Skins don't know about it, so it draws its own window frame on the facade.
## - It holds fire at a player on the ceiling or running along its own wall (there its
##   body is the hazard; FB 70); the GDD only says it shoots at the player.
## Once defeated, its body slumps over the sill and stays until the player is far past.
##
## Spawn params: fires (bool, default true; tests), health (float).

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
## The body is drawn a little larger than a floor cyborg so the torso fills the window.
const BODY_SCALE: float = 1.25
const HUSK_KEEP: float = 40.0
## The light inside the window: the cold white of a screen showing the feed, dim (below the glow
## threshold), so the only glows on a window cyborg stay its face and its cannon.
## DESIGN-TBD (docs/questions/p2.md 6): it was a warm orange.
const WINDOW_LIGHT := Color(0.6, 0.66, 0.76)

var tuning: WindowCyborgTuning
var side: int = 1
var body: CyborgBody
var gun: CyborgGun
## The band of heights its body blocks (world y).
var band_bottom: float = 0.0
var band_top: float = 0.0

var _husk: bool = false


## A window cyborg's body as `entry`'s would be, for EnemyDirector.warm_up (which frees it): its upper
## body builds what the cyborg kit shares (Cyborg.warm_up).
static func warm_up(world: RunWorld, entry: Dictionary) -> Node:
	var body := CyborgBody.new()
	body.build(world.skin.enemy_variant, false, true, int(entry.get("seed", 0)))
	return body


func _build() -> void:
	tuning = tuning_res as WindowCyborgTuning
	if tuning == null:
		tuning = WindowCyborgTuning.new()
	var p: Dictionary = spawn.get("params", {})
	display_name = "window cyborg"
	stompable = false
	if p.has("health"):
		max_health = float(p["health"])
	side = -1 if int(spawn.get("side", 1)) < 0 else 1
	position = Vector3(side * world.geo.wall_x(), 0.0, TrackGeometry.world_z(float(spawn.get("at", 0.0))))
	var center: float = world.tuning.wall_entry_height + tuning.band_offset
	band_bottom = center - tuning.band_height * 0.5
	band_top = center + tuning.band_height * 0.5
	add_hitbox(&"body", Vector3(tuning.reach, tuning.band_height, tuning.hitbox_length),
		Vector3(-side * tuning.reach * 0.5, center, 0.0))
	_build_window()
	body = CyborgBody.new()
	body.name = "Body"
	add_child(body)
	body.build(world.skin.enemy_variant, false, true, int(spawn.get("seed", 0)))
	body.scale = Vector3.ONE * BODY_SCALE
	body.lean = 0.3
	# Facing the lanes (the body's front is its local +Z), waist just below the band.
	body.rotation.y = -side * PI * 0.5
	body.position = Vector3(-side * 0.16, band_bottom - 0.05 - (CyborgBody.HIP_Y + 0.06) * BODY_SCALE, 0.0)
	gun = CyborgGun.new(self, world, tuning, rng, body)
	gun.muzzle_offset = Vector3(-side * 0.45, band_bottom + 0.45, 0.0)
	gun.muzzle_reach = 0.35
	gun.enabled = bool(p.get("fires", true))
	gun.may_attack = _may_attack
	health_changed.connect(func(_e: Enemy) -> void: body.flash())


func _tick(delta: float) -> void:
	gun.update(delta)
	var attacking: bool = gun.is_attacking()
	body.set_pose(CyborgBody.Pose.AIM if attacking else CyborgBody.Pose.IDLE)
	var face: Kit.Face = Kit.Face.AIMING if attacking else Kit.Face.NEUTRAL
	if face != body.face:
		body.set_expression(face)


func aim_point() -> Vector3:
	return global_position + Vector3(-side * 0.3, (band_bottom + band_top) * 0.5, 0.0)


func hit_radius() -> float:
	return 0.5


func _on_defeated(cause: StringName) -> void:
	gun.stop()
	_husk = true
	world.play_sfx_at(&"enemy_death", aim_point())
	world.effects.burst(aim_point(), Kit.LED_COLOR, 20, 0.7)
	body.die(cause)


func _process(_delta: float) -> void:
	if _husk and world != null and world.player != null \
			and world.player_distance() - track_distance() > HUSK_KEEP:
		queue_free()


func _may_attack() -> bool:
	var player: Player = world.player
	if not player.alive or not player.running or player.surface == Player.Surface.CEILING:
		return false
	if player.surface == Player.Surface.WALL and player.wall_side == side:
		return false
	var ahead: float = track_distance() - player.distance
	return ahead > 0.0 and ahead <= gun.engage_distance()


## The window: a dark opening lit from inside by the cold, dim light of a screen (the cult's feed,
## GDD §5; never a warm glow, which would read like the player's copper), with a frame and a sill,
## on the facade.
func _build_window() -> void:
	var key: String = "window/%d/%.2f/%.2f/%.2f/%.2f/%.2f" % [side, band_bottom, band_top,
		tuning.window_length, tuning.window_above, tuning.window_below]
	var inst := MeshInstance3D.new()
	inst.mesh = Kit.mesh(key, _window_mesh.bind(side, band_bottom - tuning.window_below,
		band_top + tuning.window_above, tuning.window_length))
	inst.material_override = Kit.part_material(&"normal")
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


static func _window_mesh(s: int, bottom: float, top: float, length: float) -> ArrayMesh:
	var b := Kit.Builder.new()
	var frame := Color(0.36, 0.38, 0.44)
	var dark := Color(0.025, 0.02, 0.03)
	var screen_light := WINDOW_LIGHT
	var h: float = top - bottom
	var mid: float = (top + bottom) * 0.5
	var inward: float = -s  # toward the lanes
	# The opening, just in front of the wall face, with dim screen light along its top edge.
	b.box(Vector3(inward * 0.012, mid, 0.0), Vector3(0.02, h, length), dark)
	b.box(Vector3(inward * 0.024, top - 0.07, 0.0), Vector3(0.01, 0.06, length - 0.1), screen_light, 0.34)
	b.box(Vector3(inward * 0.024, bottom + 0.12, 0.0), Vector3(0.01, 0.2, length - 0.1), screen_light, 0.12)
	# Frame and sill.
	var fw: float = 0.09
	b.box(Vector3(inward * 0.05, top + fw * 0.5, 0.0), Vector3(0.1, fw, length + fw * 2.0), frame)
	b.box(Vector3(inward * 0.1, bottom - fw * 0.5, 0.0), Vector3(0.2, fw, length + fw * 2.4), frame)
	for z: float in [-1.0, 1.0]:
		b.box(Vector3(inward * 0.05, mid, z * (length + fw) * 0.5), Vector3(0.1, h, fw), frame)
	return b.commit()
