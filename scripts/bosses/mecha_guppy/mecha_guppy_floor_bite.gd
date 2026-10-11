class_name MechaGuppyFloorBite
extends Node3D
## Mecha Guppy's floor bite in the fight (GDD §10, the owner, October 11, 2026: "The floor bite"; task E5e-f): its warning,
## its snap and what a runner caught in it meets. The plan (MechaGuppyClimb, MechaGuppyCrescent) says where and when;
## MechaGuppyPattern starts it as the runner reaches the bite's warn_at, and Mecha Guppy's snap (MechaGuppyShark.on_snap,
## MechaGuppyPattern.on_snap) bites the chunk out:
## - start(bite): the warning (every attack has a visual and an audio warning): the crescent in the enemy attacks' red on
##   the roof's floor, the Golden Convergence's Fist Slam's look (a solid red fill, FILL_ALPHA, inside a brighter frame
##   that deepens as the snap comes, its beat steady with Reduced flashing; the frame's mesh built once and its width set
##   by a uniform, mecha_guppy_floor_warning.gdshader), counted as a floor warning on every lane it takes
##   (BossProps.floor_warning: pickups keep off it). Its sound (guppy_floor_warn, nothing else's) and the snout rising
##   beside the roof's side are the shark's (MechaGuppyShark.floor_bite). The jaws' hitboxes are placed now, off.
## - snap(): the chunk is gone (MechaGuppyStairs.eat_crescent: the collision and the look together), rubble flies, a
##   shake; the jaws' hitboxes are live for SNAP_SECONDS. Real contact only: an enemy attack over the crescent a little
##   smaller than it (SNAP_INSET), from under the floor to over a jump's reach, so a runner caught in it (in the bite's
##   area as it snaps, on the floor or in the air) meets the damage rules: armor and the shield block it, the dash passes
##   through it. A runner who lives through it (blocked, dashing, safe for a moment after a hit) has the floor under them
##   held for GameRules.cut_hold_seconds (FloorCut.hold_under's rule, the Fist Slam's too: the block means something); one
##   who doesn't block it dies of the bite. DESIGN-TBD (docs/questions/e5e.md).
## - call_off(): a bite whose warning showed but which hasn't snapped when the attacks stop (an intro, the win): its warning
##   goes, nothing is bitten, and it counts as skipped.
## One bite at a time; its clock is the boss's (tick: the pattern's frames, waiting while the runner is down).

## The jaws' hitboxes: this many along the bite, each SNAP_INSET in from the crescent's outline, from SNAP_UNDER under the
## floor to SNAP_HEIGHT over it (over a jump's reach with the runner's body: MovementTuning.jump_height and hurtbox_size.y),
## live this long (seconds).
const SNAP_BOXES: int = 10
const SNAP_INSET: float = 0.15
const SNAP_UNDER: float = 0.6
const SNAP_HEIGHT: float = 3.0
const SNAP_SECONDS: float = 0.15
## The jaws' hitboxes' name (a death by them is "Mecha Guppy's bite").
const BITE_NAME: String = "Mecha Guppy's bite"
## The outline: its frame this wide (deepening to 1.4 times as the snap comes), beating this much (none with Reduced
## flashing), its fill this opaque (a solid red: it reads); both just over the deck.
const FRAME: float = 0.18
const BEAT: float = 0.2
const FILL_ALPHA: float = 0.85
const FRAME_Y: float = 0.035
const FILL_Y: float = 0.025
## The rubble's colours come from the Beach's skin, flung up this hard.
const RUBBLE_UP := Vector3(0.0, -2.0, 0.0)
## A snapped bite is done once the runner is this far past its end (metres).
const PASSED: float = 2.0

var boss: MechaGuppy
var world: RunWorld
## The bite under way (its warning showing, then its hole, until the runner is past it), or null.
var bite: MechaGuppyCrescent
## Seconds of the fight's attacks so far (tick), the clock its warning showed at and its snap came at (-1 before).
var clock: float = 0.0
var warned_at: float = -1.0
var snapped_at: float = -1.0
## Where the runner was as its warning showed (track distance).
var warned_from: float = 0.0
## Bites warned, snapped, called off, runners caught (tests).
var warnings: int = 0
var snaps: int = 0
var called_off: int = 0
var caught: int = 0
## The outline's frame's width now (metres; tests: steady with Reduced flashing, only deepening).
var frame_width: float = 0.0

const FRAME_SHADER: Shader = preload("res://scripts/bosses/mecha_guppy/mecha_guppy_floor_warning.gdshader")

var _frame: MeshInstance3D
var _fill: MeshInstance3D
var _tokens: Array[Node3D] = []
var _hazards: Array[Hazard] = []
## The floor held under a runner who lived through a snap: {body, look, until (clock)}, or empty.
var _hold: Dictionary = {}
var _frame_material: ShaderMaterial
var _fill_material: BaseMaterial3D


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	top_level = true
	transform = Transform3D.IDENTITY
	_frame_material = ShaderMaterial.new()
	_frame_material.shader = FRAME_SHADER
	_frame_material.set_shader_parameter(&"color", Color(BossProps.WARNING_COLOR, 0.8))
	_frame_material.set_shader_parameter(&"width", FRAME)
	_fill_material = (GreyboxMaterials.glow(BossProps.WARNING_COLOR, 1.2, FILL_ALPHA).duplicate() as BaseMaterial3D)
	_fill_material.disable_fog = true
	_frame = MeshInstance3D.new()
	_frame.name = "Outline"
	_frame.material_override = _frame_material
	_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_frame.visible = false
	add_child(_frame)
	_fill = MeshInstance3D.new()
	_fill.name = "Fill"
	_fill.material_override = _fill_material
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.visible = false
	add_child(_fill)


## True while a bite's warning shows (started, not yet snapped).
func warning() -> bool:
	return bite != null and snapped_at < 0.0


## The jaws' hitboxes (tests).
func hazards() -> Array[Hazard]:
	return _hazards


## True while the floor is held under a runner who lived through a snap.
func holding() -> bool:
	return not _hold.is_empty()


## The floor held under a runner (tests): {from, to, x0, x1, until} (track distances, world x, the clock), or empty.
func held() -> Dictionary:
	if _hold.is_empty():
		return {}
	return {"from": _hold["from"], "to": _hold["to"], "x0": _hold["x0"], "x1": _hold["x1"], "until": _hold["until"]}


## The bite's warning shows (see the header): its outline on the roof's floor, a floor warning on each lane it takes, its
## hitboxes placed (off).
func start(p_bite: MechaGuppyCrescent) -> void:
	clear()
	bite = p_bite
	bite.warned = true
	warned_at = clock
	snapped_at = -1.0
	warned_from = world.player.distance
	warnings += 1
	var top: float = _top()
	_fill.mesh = _fill_mesh(top + FILL_Y)
	_fill.visible = true
	_frame.mesh = _frame_mesh(top + FRAME_Y)
	_frame.visible = true
	_update_frame()
	for lane: int in world.geo.lane_count:
		var s: Vector2 = bite.lane_stretch(lane)
		if s.x > s.y:
			continue
		var token := Node3D.new()
		token.name = "FloorBiteWarning"
		add_child(token)
		_tokens.append(token)
		boss.props.floor_warning(token, lane, s.x, s.y, top)
	_place_hazards(top)
	boss.log_event(&"floor_bite_warning", {"roof": bite.roof, "side": bite.side, "full": bite.full, "keep": bite.keep,
		"from": bite.from, "to": bite.to, "d0": world.player.distance, "lane": world.player.lane, "snap_at": bite.snap_at})


## The jaws snap (MechaGuppyPattern.on_snap; see the header): a runner caught in the bite meets its hitboxes, and one who
## lives through it has the floor held under them; the chunk goes, rubble flies.
func snap() -> void:
	if bite == null or snapped_at >= 0.0:
		return
	snapped_at = clock
	snaps += 1
	var p: Player = world.player
	var top: float = _top()
	for h: Hazard in _hazards:
		h.set_enabled(true)
	# A runner in the bite's area as it snaps (its hitboxes' boxes against their hurtbox): the damage rules say what
	# comes of it (the hitboxes do it, on contact: Player._check_hazards); one who lives through it keeps the floor under
	# them a moment.
	var in_area: Hazard = _touching(p)
	var outcome: int = -1
	if in_area != null and p.alive:
		caught += 1
		outcome = DamageRules.resolve(in_area, p.defense())
		if outcome != DamageRules.Outcome.KILL:
			_hold_under(p, top)
	var box: AABB = boss.stairs.eat_crescent(bite.roof)
	_clear_warning()
	var colors := PackedColorArray()
	var beach := world.skin as BeachSkin
	if beach != null:
		colors = PackedColorArray([beach.boardwalk_color, beach.bamboo_colors[0], beach.kerb_color, beach.timber_color])
	if box.size.z > 0.01:
		world.effects.rubble(box, colors, RUBBLE_UP, bite.roof + 1000)
		var near: float = clampf(1.0 - absf(-box.get_center().z - p.distance) / 50.0, 0.25, 1.0)
		world.effects.shake(0.35 * near, 0.35)
	boss.log_event(&"floor_bite_snap", {"roof": bite.roof, "d0": p.distance, "lane": p.lane, "caught": in_area != null,
		"outcome": outcome, "full": bite.full})


## A bite warned but not yet snapped is called off (the attacks stopped: an intro, the win): its warning goes, nothing is
## bitten. A snapped one just finishes (its hitboxes off).
func call_off() -> void:
	if bite != null and snapped_at < 0.0:
		bite.skipped = true
		called_off += 1
		boss.log_event(&"floor_bite_called_off", {"roof": bite.roof})
	clear()


## Everything off: no warning, no hitboxes, no bite under way (a held floor stays its moment).
func clear() -> void:
	_clear_warning()
	for h: Hazard in _hazards:
		if is_instance_valid(h):
			h.queue_free()
	_hazards.clear()
	bite = null


## One frame of the fight's attacks (MechaGuppy._advance).
func tick(delta: float) -> void:
	clock += delta
	if warning():
		_update_frame()
	if snapped_at >= 0.0 and clock - snapped_at >= SNAP_SECONDS - 0.0001 and not _hazards.is_empty():
		for h: Hazard in _hazards:
			if is_instance_valid(h):
				h.queue_free()
		_hazards.clear()
	# The bite stays under way (its hole what it shows) until the runner is past it.
	if bite != null and snapped_at >= 0.0 and _hazards.is_empty() and world.player.distance > bite.to + PASSED:
		bite = null
	if not _hold.is_empty() and clock >= float(_hold["until"]) - 0.0001:
		_end_hold()


# --- Internals ------------------------------------------------------------------------------------

## The bite's roof's top.
func _top() -> float:
	return boss.climb.roofs[bite.roof].top


func _clear_warning() -> void:
	_frame.visible = false
	_fill.visible = false
	for t: Node3D in _tokens:
		if is_instance_valid(t):
			boss.props.remove(t)
	_tokens.clear()


## The crescent's outline, front to back along its edge, then back along the bitten side's wall (Vector2(x, d)).
func _outline() -> PackedVector2Array:
	var out: PackedVector2Array = bite.edge()
	out.append(Vector2(bite.x_of(0.0), bite.from))
	return out


## The fill: the crescent between the bitten side's wall and its edge, stretch by stretch, at height `y`.
func _fill_mesh(y: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var pts: PackedVector2Array = bite.edge()
	var wall: float = bite.x_of(0.0)
	for i: int in pts.size() - 1:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[i + 1]
		if q.y - p.y < 0.0005:
			continue
		_tri_up(verts, Vector3(wall, y, -p.y), Vector3(p.x, y, -p.y), Vector3(q.x, y, -q.y))
		_tri_up(verts, Vector3(wall, y, -p.y), Vector3(q.x, y, -q.y), Vector3(wall, y, -q.y))
	return _mesh(verts)


## The frame's width as far as the warning has come (and its beat): the shader's uniform; its mesh stays as built.
func _update_frame() -> void:
	var p: Player = world.player
	var k: float = clampf((p.distance - warned_from) / maxf(bite.snap_at - warned_from, 0.5), 0.0, 1.0)
	var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + BEAT * sin((clock - warned_at) * 24.0)
	frame_width = FRAME * (0.8 + 0.6 * k) * beat
	_frame_material.set_shader_parameter(&"width", frame_width)


## The frame's mesh at height `y`, built once a bite: a band round the outline, each quad's outer vertices on it and its
## inner ones there too with their inward direction (into the crescent) in UV, so the shader moves them in by its width.
func _frame_mesh(y: float) -> ArrayMesh:
	var pts: PackedVector2Array = _outline()
	var n: int = pts.size()
	# Each point's normal into the crescent (the outline runs round it clockwise or not: the side decides).
	var inward := PackedVector2Array()
	inward.resize(n)
	for i: int in n:
		var acc := Vector2.ZERO
		for j: int in [i - 1, i]:
			var a: Vector2 = pts[(j + n) % n]
			var b: Vector2 = pts[(j + 1) % n]
			var t: Vector2 = b - a
			if t.length() > 0.0001:
				acc += Vector2(float(bite.side) * t.y, -float(bite.side) * t.x).normalized()
		inward[i] = acc.normalized() if acc.length() > 0.0001 else Vector2.ZERO
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		if a.distance_to(b) < 0.0005:
			continue
		var va := Vector3(a.x, y, -a.y)
		var vb := Vector3(b.x, y, -b.y)
		# Track distance d runs along -z: an inward step (x, d) moves a vertex by (x, -d) in x and z.
		var ia := Vector2(inward[i].x, -inward[i].y)
		var ib := Vector2(inward[(i + 1) % n].x, -inward[(i + 1) % n].y)
		verts.append_array(PackedVector3Array([va, vb, vb, va, vb, va]))
		uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, ib, Vector2.ZERO, ib, ia]))
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Its bounds reach in by the widest frame (the shader moves the inner vertices after culling decides).
	mesh.custom_aabb = mesh.get_aabb().grow(FRAME * 2.0)
	return mesh


## Appends triangle (a, b, c) wound to face up.
static func _tri_up(verts: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).y > 0.0:
		verts.append_array(PackedVector3Array([a, c, b]))
	else:
		verts.append_array(PackedVector3Array([a, b, c]))


static func _mesh(verts: PackedVector3Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The jaws' hitboxes over the bite (see the header), placed now and off until the snap.
func _place_hazards(top: float) -> void:
	var span: float = (bite.to - bite.from) / float(SNAP_BOXES)
	for i: int in SNAP_BOXES:
		var a: float = bite.from + span * float(i)
		var b: float = a + span
		# The shallowest the gap is over this stretch (at its edge's points there), so the box stays inside it.
		var w: float = minf(bite.min_depth(a + SNAP_INSET, b - SNAP_INSET), bite.width()) - SNAP_INSET
		var lo: float = SNAP_INSET
		if w - lo < 0.3 or b - a < SNAP_INSET * 2.0 + 0.1:
			continue
		var x0: float = minf(bite.x_of(lo), bite.x_of(w))
		var size := Vector3(w - lo, SNAP_UNDER + SNAP_HEIGHT, b - a - SNAP_INSET * 2.0)
		var hazard := Hazard.new()
		hazard.name = "FloorBite"
		hazard.hazard_name = BITE_NAME
		hazard.is_enemy_attack = true
		hazard.part = &"attack"
		hazard.size = size
		hazard.collision_layer = TrackBuilder.LAYER_HAZARD
		hazard.collision_mask = 0
		hazard.monitoring = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		hazard.add_child(shape)
		add_child(hazard)
		hazard.global_position = Vector3(x0 + size.x * 0.5, top - SNAP_UNDER + size.y * 0.5, TrackGeometry.world_z((a + b) * 0.5))
		hazard.set_enabled(false)
		_hazards.append(hazard)


## The hitbox a runner's hurtbox meets as the bite snaps (their box against its boxes), or null.
func _touching(p: Player) -> Hazard:
	var hurt: AABB = p.hurtbox_aabb()
	for h: Hazard in _hazards:
		var box := AABB(h.global_position - h.size * 0.5, h.size)
		if box.intersects(hurt):
			return h
	return null


## The floor under runner `p` holds for GameRules.cut_hold_seconds (FloorCut.hold_under's rule): over the lanes their feet
## are in, from just behind them to as far as they run meanwhile, the roof's deck shown there, then gone all at once (a
## runner still on it falls).
func _hold_under(p: Player, top: float) -> void:
	_end_hold()
	var seconds: float = world.rules.cut_hold_seconds if world.rules != null else 1.0
	var x: float = p.position.x
	var feet: float = world.tuning.foot_half_width
	var x0: float = INF
	var x1: float = -INF
	for lane: int in world.geo.lane_count:
		var span: Vector2 = world.geo.lane_floor_span(lane)
		if x + feet >= span.x and x - feet <= span.y:
			x0 = minf(x0, span.x)
			x1 = maxf(x1, span.y)
	if x0 >= x1:
		return
	var from: float = p.distance - 1.0
	var to: float = p.distance + maxf(p.speed, 0.0) * seconds + 2.0
	var body := StaticBody3D.new()
	body.name = "FloorBiteHeld"
	body.collision_layer = TrackBuilder.LAYER_FLOOR
	body.collision_mask = 0
	add_child(body)
	var size := Vector3(x1 - x0, 0.5, to - from)
	body.global_position = Vector3((x0 + x1) * 0.5, top - size.y * 0.5, TrackGeometry.world_z((from + to) * 0.5))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var look: Node3D = null
	if boss.stairs.looks != null:
		look = boss.stairs.looks.held_floor(x0, x1, from, to, top)
		add_child(look)
	_hold = {"body": body, "look": look, "until": clock + seconds, "from": from, "to": to, "x0": x0, "x1": x1}
	boss.log_event(&"floor_bite_hold", {"roof": bite.roof, "from": from, "to": to, "seconds": seconds, "lane": p.lane,
		"dashing": p.dashing})


func _end_hold() -> void:
	if _hold.is_empty():
		return
	for key: String in ["body", "look"]:
		var node: Node = _hold[key]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_hold = {}
