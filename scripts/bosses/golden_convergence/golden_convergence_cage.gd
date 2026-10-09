class_name GoldenConvergenceCage
extends Node3D
## The Refill Ship's closed cage (GDD §10: "The way up: an anti-grav pad under the ship, caged by electric fences
## (§9.1). A runner who touches a fence is hit unless they dash through or first knock out the cage's generator (a
## stomp or the dash), whose pulse switches the fences off. Armor and the shield get through a fence at the cost of
## a hit, as usual"; "A closed cage: fences in the lanes beside the pad as well, and the front fence placed so a
## jump over it lands past the pad. The only ways in are the dash, the generator, or spending armor or the
## shield"; proposed: "The cage's sides are fences running along the pad lane's edges, from the front fence to past
## the pad, so a lane switch into the cage touches one"; "The generator stands in a lane next to the cage, just
## before it, with room after its pulse to switch into the pad's lane"; task E5d-c). Made once with the fight and
## reused (GoldenConvergenceRefill places it); in track coordinates:
## - the pad: an anti-grav pad (the trigger every pad is, the zone's pad look) cage_pad_length deep, just behind the
##   front fence, in an inner lane;
## - the front fence: a full-height fence across the pad's lane (jump it or not: GoldenConvergenceTuning.
##   cage_pad_length keeps the pad inside even the earliest jump over it, so a jump lands past the pad);
## - the sides: lengthwise fences along the pad lane's two edges from the front fence to cage_side_past past the
##   pad, cage_side_height tall (above a jump: a switch into the cage, in the air too, touches one), each the
##   fence's look turned along the track (its field and its gold stanchions at its ends);
## - the generator (B9's FenceGenerator, through BossEncounter.spawn_enemy: a stomp or the dash destroys it, weapons
##   never set it off) in a lane beside the pad's, generator_before before the front fence, a pink conduit along
##   the lane seam to the cage (it powers it); its pulse switches the whole cage off (emp(): its own generator's
##   EMP; any other EMP switches off what it reaches, by the fence rule's distance);
## - every fence follows every fence rule (Hazard.is_electrical, no enemy: armor and the shield get through at the
##   cost of a hit, the dash passes, claws don't, weapons never target or destroy it, an EMP switches it off) and
##   flickers in harmlessly with the fence warning (its look's WARNING state, steady with Reduced flashing, and the
##   crackle) for cage_flicker before it switches on: the cage always comes up in sight;
## - pickups keep off its stretch in the pad's and the generator's lanes (BossProps.floor_warning).
## Every contact with one of its fences is noted (`touches`, `touched`).

## A fence of the cage touched the runner (`outcome`: DamageRules.Outcome other than IGNORE).
signal touched(kind: StringName, outcome: int)

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
## The pad starts this far behind the front fence's back face (its look's plate meets the fence).
const PAD_GAP: float = 0.12
## The sides' thickness across the lane's edge (their hitbox: the drawn field is a little thicker).
const SIDE_THICK: float = 0.24
## The conduit from the generator to the cage: its casing's and its core's widths, its height over the floor.
const CONDUIT_CASE: float = 0.12
const CONDUIT_CORE: float = 0.04
const CONDUIT_Y: float = 0.02
## The cage is put away once the runner is this far past it; once its pad is ridden, it sinks away over this long.
const KEEP_BEHIND: float = 30.0
const RETRACT_SECONDS: float = 0.35
## E5d polish (F6's short cage_lead or a generator far out could leave it out of reach): from the cage's coming up
## to the generator, a runner always has this long to read it, a lane switch for every lane but one, a jump's rise
## onto the generator, and this long to spare (lead_seconds). DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 489).
const READ_SECONDS: float = 0.7
const SPARE_SECONDS: float = 0.3

var boss: GoldenConvergence
var pad: Area3D
var front: Hazard
## The left side (index 0, toward lane 0) and the right.
var sides: Array[Hazard] = []
var generator: FenceGenerator
## The cage now: {n, lane, gen_lane, front_at, pad_from, pad_to, side_from, side_to, gen_at} (track distances);
## empty while it's put away.
var plan: Dictionary = {}
## Up (placed and not yet put away); its fences dark (switched off by an EMP); its pad stepped on.
var up: bool = false
var dark: bool = false
var padded: bool = false
## Cages placed this fight; fence contacts: {n, kind, side, outcome, runner, lane, h, surface, t}.
var cages: int = 0
var touches: Array[Dictionary] = []

var _flicker_left: float = 0.0
## Seconds into sinking away (retract), -1 when it isn't; where each piece stood.
var _retract: float = -1.0
var _base: Dictionary = {}
var _side_length: float = 0.0
var _conduit_case: MeshInstance3D
var _conduit_core: MeshInstance3D
var _core_material: ShaderMaterial
var _markers: Array[Node3D] = []


func setup(p_boss: GoldenConvergence) -> void:
	boss = p_boss
	name = "Cage"
	top_level = true
	var world: RunWorld = boss.world
	var t: MovementTuning = world.tuning
	var gt: GoldenConvergenceTuning = boss.tuning
	# The pad.
	var pad_size := Vector3(world.geo.lane_width * 0.7, 0.5, gt.cage_pad_length)
	pad = Area3D.new()
	pad.name = "Pad"
	pad.collision_mask = 0
	pad.monitoring = false
	pad.set_meta(&"kind", &"pad")
	add_child(pad)
	_shape(pad, pad_size)
	world.skin.pad(pad, pad_size)
	# The front fence (full height), across the pad's lane.
	var front_size := Vector3(world.geo.lane_width - 0.2, t.fence_full_top, t.fence_depth)
	front = _fence("cage fence", front_size, -t.fence_full_top * 0.5)
	# The sides, along the pad lane's edges: the fence turned along the track (its local x along -z).
	_side_length = side_length()
	var side_size := Vector3(_side_length, gt.cage_side_height, SIDE_THICK)
	for i: int in 2:
		var side: Hazard = _fence("cage side fence", side_size, -gt.cage_side_height * 0.5)
		sides.append(side)
	# The conduit from the generator to the cage: a dark casing, a pink core pulsing toward the cage.
	_conduit_case = _box("ConduitCase", GreyboxMaterials.flat(Color(0.16, 0.13, 0.1)))
	_core_material = ShaderMaterial.new()
	_core_material.shader = Kit.shader("cable")
	_core_material.set_shader_parameter(&"color", _fence_color())
	_conduit_core = _box("ConduitCore", _core_material)
	world.player.movement_event.connect(_on_player_event)
	put_away()


## The cage's lead at `lanes` lanes (seconds of running from its coming up to its front fence): cage_lead, or
## longer where the generator (generator_before, at 18 m/s, ahead of the fence) would leave less than
## READ_SECONDS, the lane switches from the farthest lane, a jump's rise and SPARE_SECONDS to get onto it.
static func lead_seconds(t: GoldenConvergenceTuning, movement: MovementTuning, lanes: int) -> float:
	var reach: float = READ_SECONDS + float(maxi(lanes - 1, 0)) * movement.lane_switch_time + movement.jump_time_to_apex \
		+ SPARE_SECONDS
	return maxf(t.cage_lead, t.generator_before / MovementTuning.REFERENCE_SPEED + reach)


## How long the sides are: from the front fence's front face to cage_side_past (at 18 m/s, at the run's pace)
## past the pad.
func side_length() -> float:
	var t: MovementTuning = boss.world.tuning
	var gt: GoldenConvergenceTuning = boss.tuning
	return t.fence_depth + PAD_GAP + gt.cage_pad_length + gt.cage_side_past * boss.run_pace()


## Where a cage with its front fence's middle at `front_at` lies (track distances): {front_at, pad_from, pad_to,
## side_from, side_to, gen_at}.
func span_for(front_at: float) -> Dictionary:
	var t: MovementTuning = boss.world.tuning
	var gt: GoldenConvergenceTuning = boss.tuning
	var half: float = t.fence_depth * 0.5
	var pad_from: float = front_at + half + PAD_GAP
	var pad_to: float = pad_from + gt.cage_pad_length
	var side_from: float = front_at - half
	return {"front_at": front_at, "pad_from": pad_from, "pad_to": pad_to, "side_from": side_from,
		"side_to": side_from + side_length(), "gen_at": front_at - gt.generator_before * boss.run_pace()}


## Puts the cage up: its pad in `lane`, the generator in `gen_lane` beside it, the front fence's middle at
## `front_at`; its fences flickering in (the fence warning, harmless) for cage_flicker, then on.
func place(lane: int, gen_lane: int, front_at: float) -> void:
	put_away()
	var world: RunWorld = boss.world
	var geo: TrackGeometry = world.geo
	var t: MovementTuning = world.tuning
	cages += 1
	plan = span_for(front_at)
	plan["n"] = cages
	plan["lane"] = lane
	plan["gen_lane"] = gen_lane
	up = true
	dark = false
	padded = false
	var x: float = geo.lane_x(lane)
	pad.position = Vector3(x, 0.25, TrackGeometry.world_z((float(plan["pad_from"]) + float(plan["pad_to"])) * 0.5))
	pad.collision_layer = TrackBuilder.LAYER_TRIGGER
	pad.visible = true
	front.position = Vector3(x, t.fence_full_top * 0.5, TrackGeometry.world_z(front_at))
	var mid: float = (float(plan["side_from"]) + float(plan["side_to"])) * 0.5
	for i: int in 2:
		var edge: float = x + (-1.0 if i == 0 else 1.0) * geo.lane_width * 0.5
		sides[i].position = Vector3(edge, boss.tuning.cage_side_height * 0.5, TrackGeometry.world_z(mid))
	for fence: Hazard in fences():
		fence.visible = true
		fence.state = Hazard.State.WARNING
		fence.state_changed.emit(Hazard.State.WARNING)
	_flicker_left = boss.tuning.cage_flicker
	# The generator beside it, and the conduit along the seam between its lane and the cage's.
	generator = boss.spawn_enemy("generator", float(plan["gen_at"]), gen_lane) as FenceGenerator
	if generator != null:
		generator.defeated.connect(_on_generator_defeated)
	var seam: float = (geo.lane_x(lane) + geo.lane_x(gen_lane)) * 0.5
	var from: float = float(plan["gen_at"]) + 0.5
	var to: float = float(plan["side_from"])
	_strip(_conduit_case, seam, from, to, CONDUIT_CASE, 0.035)
	_strip(_conduit_core, seam, from, to, CONDUIT_CORE, 0.05)
	_core_material.set_shader_parameter(&"origin", world.lane_point(gen_lane, float(plan["gen_at"])))
	_conduit_case.visible = true
	_conduit_core.visible = true
	# Pickups keep off its stretch (the pad's lane and the generator's).
	for l: int in [lane, gen_lane]:
		var marker := Node3D.new()
		marker.name = "CageStretch"
		boss.props.floor_warning(marker, l, float(plan["gen_at"]) - 3.0, float(plan["side_to"]) + 1.0)
		_markers.append(marker)
	boss.log_event(&"cage", {"n": cages, "lane": lane, "gen_lane": gen_lane, "front_at": front_at,
		"pad_from": plan["pad_from"], "pad_to": plan["pad_to"], "side_to": plan["side_to"], "gen_at": plan["gen_at"],
		"runner": boss.player_distance(), "runner_lane": boss.player_lane()})


## Every physics frame of the fight: the flicker in, then the fences on (unless an EMP switched them off); put
## away once the runner is well past it, or once it has sunk away.
func tick(delta: float) -> void:
	if not up:
		return
	if _retract >= 0.0:
		_retract += delta
		var k: float = clampf(_retract / RETRACT_SECONDS, 0.0, 1.0)
		for node: Node3D in _base:
			node.position = (_base[node] as Vector3) - Vector3(0.0, (boss.tuning.cage_side_height + 0.6) * k * k, 0.0)
		if k >= 1.0:
			put_away()
		return
	if _flicker_left > 0.0:
		_flicker_left -= delta
		if _flicker_left <= 0.0 and not dark:
			for fence: Hazard in fences():
				fence.set_enabled(true)
			boss.log_event(&"cage_on", {"n": cages})
	if boss.player_distance() > float(plan["side_to"]) + KEEP_BEHIND:
		put_away()


## Its pad ridden (the Refill Ship's chain reaction begins): it has done its work, and sinks into the causeway
## over RETRACT_SECONDS, harmless at once (out of the way of the run camera ducking under the ship's belly).
func retract() -> void:
	if not up or _retract >= 0.0:
		return
	_retract = 0.0
	_flicker_left = 0.0
	pad.collision_layer = 0
	_base.clear()
	for node: Node3D in [pad, front, sides[0], sides[1]]:
		_base[node] = node.position
	for fence: Hazard in fences():
		fence.set_enabled(false)
	_conduit_case.visible = false
	_conduit_core.visible = false
	boss.log_event(&"cage_retract", {"n": cages, "runner": boss.player_distance()})


## The cage's three fences: the front, the left side, the right side.
func fences() -> Array[Hazard]:
	return [front, sides[0], sides[1]]


## True if the cage is up and the runner hasn't passed its pad yet.
func ahead() -> bool:
	return up and boss.player_distance() <= float(plan["pad_to"])


## An EMP at `center` (world space) reaching `radius`: its own generator's pulse switches the whole cage off
## (GDD §10: "whose pulse switches the fences off"; DESIGN-TBD, docs/OPEN_QUESTIONS.md, item 474: whatever its
## radius); any other switches off the fences it reaches (GDD §9.1's rule, by their nearest point). True if any
## went dark.
func emp(center: Vector3, radius: float) -> bool:
	if not up:
		return false
	var own: bool = generator != null and is_instance_valid(generator) \
		and Vector2(center.x, center.z).distance_to(Vector2(generator.global_position.x, generator.global_position.z)) < 1.0
	var any: bool = false
	for fence: Hazard in fences():
		if not own and _distance_to(fence, center) > radius:
			continue
		if fence.state != Hazard.State.OFF:
			fence.set_enabled(false)
			any = true
	if own or (any and not front.is_active() and not sides[0].is_active() and not sides[1].is_active()):
		dark = true
	if any:
		boss.log_event(&"cage_dark", {"n": cages, "own": own, "runner": boss.player_distance()})
	return any


## A fence's nearest point to `center` (its box), how far.
static func _distance_to(fence: Hazard, center: Vector3) -> float:
	var local: Vector3 = fence.global_transform.affine_inverse() * center
	var half: Vector3 = fence.size * 0.5
	var nearest := Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z))
	return (local - nearest).length()


## Takes it away: pad, fences and conduit gone, a generator still standing out of play (it powers nothing now).
func put_away() -> void:
	up = false
	_flicker_left = 0.0
	_retract = -1.0
	for node: Node3D in _base:
		if is_instance_valid(node):
			node.position = _base[node]
	_base.clear()
	if pad != null:
		pad.collision_layer = 0
		pad.visible = false
	for fence: Hazard in fences():
		if fence == null:
			continue
		fence.set_enabled(false)
		fence.visible = false
	if _conduit_case != null:
		_conduit_case.visible = false
		_conduit_core.visible = false
	for marker: Node3D in _markers:
		boss.props.remove(marker)
	_markers.clear()
	if generator != null and is_instance_valid(generator):
		if generator.defeated.is_connected(_on_generator_defeated):
			generator.defeated.disconnect(_on_generator_defeated)
		if generator.alive and generator.track_distance() > boss.player_distance() - 1.0:
			generator.retire()
	generator = null


## The runner's pad fired: if it's this cage's (its lane, its stretch), the cage has done its work and sinks away at
## once (the Refill Ship's chain reaction asks the same), so a runner flipping up off the pad never meets a side
## fence (the flip swings the body out sideways: GoldenConvergenceRefill's ways in are all covered).
func _on_player_event(kind: StringName) -> void:
	if kind != &"pad" or not up or _retract >= 0.0 or plan.is_empty():
		return
	var p: Player = boss.world.player
	if p.lane != int(plan["lane"]) or p.distance < float(plan["pad_from"]) - 1.5 or p.distance > float(plan["pad_to"]) + 1.5:
		return
	padded = true
	retract()


func _on_generator_defeated(_enemy: Enemy, cause: StringName) -> void:
	_conduit_core.visible = false
	boss.log_event(&"cage_generator", {"n": cages, "cause": cause, "runner": boss.player_distance(),
		"lane": boss.player_lane()})


func _on_contacted(outcome: int, fence: Hazard) -> void:
	if outcome == DamageRules.Outcome.IGNORE or not up:
		return
	var p: Player = boss.world.player
	var kind: StringName = &"front" if fence == front else &"side"
	var entry := {"n": cages, "kind": kind, "side": sides.find(fence), "outcome": outcome, "runner": p.distance, "lane": p.lane,
		"h": p.h, "surface": p.surface, "dashing": p.dashing, "t": boss.fight_time()}
	touches.append(entry)
	boss.log_event(&"cage_touch", entry)
	touched.emit(kind, outcome)


# --- Building ----------------------------------------------------------------------------------------

## A fence of `size` (its local x across its field, y up, z its depth), its middle `ground_y` above the floor's,
## in the zone's fence look with the fence's warning crackle.
func _fence(fence_name: String, size: Vector3, ground_y: float) -> Hazard:
	var hazard := Hazard.new()
	hazard.name = fence_name.capitalize().replace(" ", "")
	hazard.hazard_name = fence_name
	hazard.is_electrical = true
	hazard.size = size
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.collision_mask = 0
	hazard.monitoring = false
	add_child(hazard)
	_shape(hazard, size)
	boss.world.skin.fence(hazard, size, ground_y, false)
	var sfx: SfxLibrary = boss.world.sfx_library
	if sfx != null and sfx.stream(&"fence_warning") != null:
		var telegraph := HazardTelegraph.new()
		hazard.add_child(telegraph)
		telegraph.bind(hazard, sfx.stream(&"fence_warning"), sfx.volume(&"fence_warning"),
			sfx.warning_full_volume_distance, sfx.warning_max_distance)
	hazard.contacted.connect(_on_contacted.bind(hazard))
	if fence_name.contains("side"):
		# Turned along the track: its field runs from the front fence to past the pad.
		hazard.basis = Basis(Vector3.UP, PI * 0.5)
	return hazard


func _box(node_name: String, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = GreyboxMaterials.unit_box()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


## Lays a flat strip `width` wide and `height` tall along the track at world x `x` from `from` to `to`.
static func _strip(mesh: MeshInstance3D, x: float, from: float, to: float, width: float, height: float) -> void:
	var length: float = maxf(to - from, 0.1)
	mesh.transform = Transform3D(Basis.from_scale(Vector3(width, height, length)),
		Vector3(x, CONDUIT_Y + height * 0.5, TrackGeometry.world_z((from + to) * 0.5)))


static func _shape(owner_node: CollisionObject3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	owner_node.add_child(shape)


func _fence_color() -> Color:
	var c: Variant = boss.world.skin.get(&"fence_color") if boss.world.skin != null else null
	return c if c is Color else Kit.FENCE_PINK
