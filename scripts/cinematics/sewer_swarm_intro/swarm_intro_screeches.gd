class_name SwarmIntroScreeches
extends Node3D
## The screeches of the Gangland boss intro (SewerSwarmIntro) and their manholes. Visual only, moved by the
## cinematic's clock (update): everything is worked out from the time, so stepping or skipping it shows the same.
## - The manholes: rows along both sides of the runner, one lane over (and the beats' own), all in one MultiMesh
##   drawn and animated like the Sewer Swarm's (SwarmLairs.mesh, swarm_lair.gdshader): a lid rattles, its slots
##   glowing, for `shake_seconds` (the screech's warning, GDD §9.5; steady, never blinking), then bursts open and
##   clangs back down askew.
## - The beats' screeches (`leapers`): the sewer screech's own body (ScreechModel, as in play), one each. The
##   first pounces into the runner's lane as they jump over it; of the next three, one leaps over the runner's
##   lane as they slide under it and two land in it ahead and swipe as the runner weaves round them; the eleven
##   after land either side of the runner's lane and rear up as the runner runs past. Each then gives chase and
##   falls behind.
## - The pour and the rain (`crowd`): one MultiMesh of the screech's crowd body (ScreechModel.crowd_mesh, its
##   look from multimesh_material), placed here: screeches hopping out of the manholes as they burst, more and
##   more, and dropping from above the camera's view, then running beside the runner (never in their lane) and
##   dropping back into the wall chasing them. A screech behind the wall's foot is lost in it (hidden).

enum After { CHASE, HOLD }
enum Kind { POUR, RAIN }

## A screech comes out of its manhole from this far down, and hops out of it in this long, this high.
const LAIR_DEPTH: float = -0.25
const HOP_SECONDS: float = 0.35
const HOP_HEIGHT: float = 0.55
## Seconds a lid takes to fly (as the swarm's lairs).
const OPEN_SECONDS: float = 0.6
## A screech giving chase reaches its speed in this long; one pouring out reaches the runner's pace in this long.
const CHASE_RAMP: float = 0.4
const POUR_RAMP: float = 0.7
## A swipe (ScreechModel's swipe input running 0-1) takes this long.
const SWIPE_SECONDS: float = 0.5
## Nothing is drawn nearer the camera than this (a screech running past the lens).
const CAMERA_CLEARANCE: float = 0.9
## A crowd screech's size (the Sewer Swarm's creatures, SewerSwarmTuning.creature_scale, when there's no boss).
const CROWD_SCALE: float = 0.7
## A pouncer that landed in the runner's lane skids on this far the way it leapt before giving chase.
const SKID: float = 1.1
## How far the crowd's spines are raised and glowing (ScreechModel's bristle).
const CROWD_BRISTLE: float = 0.6

## One of the beats' screeches.
class Leaper:
	var side: int = 0
	var beat: int = 0
	var lair: int = -1
	var burst: float = 0.0
	## Its leap: from (in the hole) to where it lands, between start and end, `arc` over the straight line.
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var start: float = 0.0
	var end: float = 0.0
	var arc: float = 0.0
	var after: After = After.CHASE
	## HOLD: it stands where it landed facing the runner until then, swiping from `swipe_at`.
	var hold_until: float = -1.0
	var swipe_at: float = -1.0
	## The x it gives chase along: out of the runner's lane (it skids on the way it leapt, or steps aside).
	var chase_x: float = 0.0
	var node: MeshInstance3D
	## Where it is now (track space) and whether it's in view (tests).
	var position := Vector3.ZERO
	var shown: bool = false

var intro: SewerSwarmIntro
var n: SewerSwarmIntroTuning
## The manholes: where (track space x, z), their side, and when each rattles and bursts (INF: never).
var lair_points := PackedVector2Array()
var lair_sides := PackedInt32Array()
var lair_shake := PackedFloat32Array()
var lair_burst := PackedFloat32Array()
var manholes: MultiMeshInstance3D
var leapers: Array[Leaper] = []
var crowd: MultiMeshInstance3D
## The crowd's screeches: kind, when each comes out (out of its manhole, or starts falling), where from (its
## manhole, or where it starts falling), the x it runs along at, its share of the run speed and its own seed.
var crowd_kind := PackedByteArray()
var crowd_start := PackedFloat32Array()
var crowd_from := PackedVector3Array()
var crowd_slot := PackedFloat32Array()
var crowd_share := PackedFloat32Array()
var crowd_seed := PackedFloat32Array()
## Where each is now (track space) and whether it's in view (tests and review tools).
var crowd_position := PackedVector3Array()
var crowd_shown := PackedByteArray()

var _lane_width: float = 2.4
var _scale: float = CROWD_SCALE
var _lair_sent := PackedColorArray()
var _buffer := PackedFloat32Array()


func setup(p_intro: SewerSwarmIntro) -> void:
	intro = p_intro
	n = intro.n
	name = "Screeches"
	_lane_width = intro.stage.geo.lane_width
	var boss_tuning := intro.zone.boss.tuning as SewerSwarmTuning if intro.zone != null and intro.zone.boss != null else null
	_scale = boss_tuning.creature_scale if boss_tuning != null else CROWD_SCALE
	var variant: StringName = intro.stage.skin.enemy_variant
	_plan_beats()
	_plan_lairs()
	_plan_crowd()
	_build_manholes()
	for l: Leaper in leapers:
		l.node = MeshInstance3D.new()
		l.node.name = "Screech%d" % leapers.find(l)
		l.node.mesh = ScreechModel.mesh()
		l.node.material_override = ScreechModel.material(variant)
		l.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.node.visible = false
		add_child(l.node)
		l.node.set_instance_shader_parameter(&"seed", _hash(l.lair, 9) * 10.0)
		l.node.set_instance_shader_parameter(&"bristle", 1.0)
	crowd = MultiMeshInstance3D.new()
	crowd.name = "Crowd"
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crowd.material_override = ScreechModel.multimesh_material(variant)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# White instance colours (SwarmCrowd.make: the Compatibility renderer would zero the vertex colours).
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = ScreechModel.crowd_mesh()
	mm.instance_count = crowd_kind.size()
	crowd.multimesh = mm
	# Placed here, anywhere along the street: bounds that always hold them.
	crowd.custom_aabb = AABB(Vector3(-20.0, -2.0, -2000.0), Vector3(40.0, 40.0, 4000.0))
	add_child(crowd)
	_buffer.resize(crowd_kind.size() * 20)
	crowd_position.resize(crowd_kind.size())
	crowd_shown.resize(crowd_kind.size())


# --- The plan ------------------------------------------------------------------------------------------

## The owner's three beats: one at the first, three at the second, eleven at the third.
func _plan_beats() -> void:
	var lw: float = _lane_width
	# One from the right pounces into the runner's lane, landing right under them at the top of their jump.
	var j: float = n.jump_at
	var land := Vector3(0.0, 0.0, intro.runner_z(j) + 0.15)
	var first: Leaper = _leaper(1, 1, n.first_burst, Vector3(lw, LAIR_DEPTH, land.z + 1.2), land, j + 0.02, n.leap_height)
	first.chase_x = land.x - SKID
	# One from the right leaps over the runner's lane, right to left, as they slide under it.
	var s: float = n.slide_at
	var zs: float = intro.runner_z(s)
	var from := Vector3(lw, LAIR_DEPTH, zs + 0.6)
	var to := Vector3(-lw * 0.75, 0.0, zs - 0.6)
	var start: float = n.second_burst + n.emerge_seconds
	var cross: float = from.x / (from.x - to.x)
	var over: Leaper = _leaper(1, 2, n.second_burst, from, to, start + (s - start) / cross, 0.0)
	over.arc = (n.over_height - lerpf(from.y, to.y, cross)) / sin(PI * cross)
	over.chase_x = maxf(to.x - SKID, intro.stage.wall_x(-1) + 0.6)
	# Two from the left land in the runner's lane ahead, facing them, and swipe as they weave past.
	for k: int in 2:
		var pass_at: float = n.weave_at + (float(k) * 2.0 - 1.0) * n.weave_seconds * 0.16
		var z: float = intro.runner_z(pass_at)
		var l: Leaper = _leaper(-1, 2, n.second_burst + 0.06 * k, Vector3(-lw, LAIR_DEPTH, z + 1.0),
			Vector3(-0.1 + 0.2 * k, 0.0, z), n.second_burst + 0.5 + 0.08 * k, n.leap_height)
		_hold(l, pass_at)
		l.chase_x = -n.third_land
	# Five on the left and six on the right land either side of the runner's lane and rear up as they pass.
	var base: float = intro.runner_z(n.third_burst) + n.third_from
	for side: int in [-1, 1]:
		var count: int = n.third_left if side < 0 else n.third_right
		for i: int in count:
			var z: float = base + (float(i) + (0.25 if side < 0 else 0.75)) * n.third_span / maxf(count, 1) \
				+ (_hash(i, 20 + side) - 0.5) * 1.2
			var burst: float = n.third_burst + _hash(i, 30 + side) * 0.12
			var l: Leaper = _leaper(side, 3, burst, Vector3(side * lw, LAIR_DEPTH, z), Vector3(side * n.third_land,
				0.0, z - 0.6), burst + n.emerge_seconds + 0.45, n.leap_height + 0.1)
			_hold(l, (z - 0.6 - n.runner_start) / intro.speed)


## A beat's screech out of a manhole at `from` (track space) on `side`, bursting at `burst`, landing at `to` at
## `land_at`.
func _leaper(side: int, beat: int, burst: float, from: Vector3, to: Vector3, land_at: float, arc: float) -> Leaper:
	var l := Leaper.new()
	l.side = side
	l.beat = beat
	l.burst = burst
	l.from = from
	l.to = to
	l.start = burst + n.emerge_seconds
	l.end = maxf(land_at, l.start + 0.1)
	l.arc = arc
	l.chase_x = to.x
	l.lair = _add_lair(Vector2(from.x, from.z), side, burst - n.shake_seconds, burst)
	leapers.append(l)
	return l


## It stands facing the runner until they've passed it (at `pass_at`), swiping as they do, then gives chase.
func _hold(l: Leaper, pass_at: float) -> void:
	l.after = After.HOLD
	l.swipe_at = pass_at - SWIPE_SECONDS * 0.4
	l.hold_until = maxf(pass_at + 0.25, l.end)


func _add_lair(at: Vector2, side: int, shake: float, burst: float) -> int:
	lair_points.append(at)
	lair_sides.append(side)
	lair_shake.append(shake)
	lair_burst.append(burst)
	return lair_points.size() - 1


## The rows of manholes along both sides; those the runner nears in the pour burst one after another.
func _plan_lairs() -> void:
	var beats: int = lair_points.size()
	var z_end: float = intro.runner_z(n.cut_at) + n.lairs_past
	var pour_start_z: float = intro.runner_z(n.pour_from)
	for side: int in [-1, 1]:
		var z: float = n.runner_start - 12.0 + (0.0 if side < 0 else n.lair_spacing * 0.5)
		var i: int = 0
		while z < z_end:
			var at: float = z + (_hash(i, 40 + side) - 0.5) * n.lair_jitter
			z += n.lair_spacing
			i += 1
			var clear: bool = true
			for b: int in beats:
				if lair_sides[b] == side and absf(lair_points[b].y - at) < n.lair_clear:
					clear = false
			if not clear:
				continue
			# It bursts `lead` seconds before the runner reaches it (after, below 0), within the pour; those the
			# runner passed shortly before it began burst as it does; the rest stay shut.
			var reach: float = (at - n.runner_start) / intro.speed
			var burst: float = reach - lerpf(n.pour_lead_min, n.pour_lead_max, _hash(i, 50 + side))
			if burst < n.pour_from:
				burst = n.pour_from + _hash(i, 60 + side) * 0.8 if at >= pour_start_z - n.pour_behind else INF
			if burst > n.pour_to:
				burst = INF
			_add_lair(Vector2(side * _lane_width, at), side, burst - n.shake_seconds * 0.6, burst)


## The pour (screeches out of each manhole that bursts in it, more and more of them) and the rain.
func _plan_crowd() -> void:
	var share: float = n.pour_low_end_share if intro.low_end else 1.0
	for i: int in lair_points.size():
		var burst: float = lair_burst[i]
		if burst == INF or burst < n.pour_from:
			continue
		var k: float = clampf((burst - n.pour_from) / maxf(n.pour_to - n.pour_from, 0.01), 0.0, 1.0)
		var count: int = roundi(lerpf(n.pour_first, n.pour_last, k) * share)
		for c: int in count:
			var seed: float = _hash(i * 31 + c, 70)
			_add_creature(Kind.POUR, burst + 0.08 + 0.13 * c + seed * 0.05,
				Vector3(lair_points[i].x, LAIR_DEPTH, lair_points[i].y), lair_sides[i], seed)
	var rain: int = n.rain_count_low_end if intro.low_end else n.rain_count
	var fall: float = sqrt(2.0 * n.rain_height / maxf(n.rain_gravity, 0.1))
	for r: int in rain:
		var seed: float = _hash(r, 80)
		# More and more of them: dropping ever closer together.
		var drop: float = lerpf(n.rain_from, n.rain_to, sqrt((float(r) + 0.5) / float(rain)))
		var side: int = -1 if _hash(r, 81) < 0.5 else 1
		var land_rel: float = lerpf(-n.rain_behind, n.rain_ahead, _hash(r, 82))
		var i: int = _add_creature(Kind.RAIN, drop, Vector3.ZERO, side, seed)
		var v: float = intro.speed * crowd_share[i]
		crowd_from[i] = Vector3(crowd_slot[i], n.rain_height, intro.runner_z(drop + fall) + land_rel - v * fall)


func _add_creature(kind: Kind, start: float, from: Vector3, side: int, seed: float) -> int:
	crowd_kind.append(kind)
	crowd_start.append(start)
	crowd_from.append(from)
	# Its lane beside the runner: on its side, between the runner's lane and the wall.
	var inner: float = n.beside_inner
	var outer: float = maxf(absf(intro.stage.wall_x(side)) - n.beside_wall, inner + 0.2)
	crowd_slot.append(side * lerpf(inner, outer, _hash(crowd_kind.size(), 90 + side)))
	crowd_share.append(lerpf(n.speed_share_min, n.speed_share_max, _hash(crowd_kind.size(), 91)))
	crowd_seed.append(seed)
	return crowd_kind.size() - 1


func _build_manholes() -> void:
	manholes = MultiMeshInstance3D.new()
	manholes.name = "Manholes"
	manholes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SwarmLairs.SHADER
	mat.set_shader_parameter(&"kind", int(SwarmLairs.Kind.MANHOLE))
	manholes.material_override = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = SwarmLairs.mesh(SwarmLairs.Kind.MANHOLE)
	mm.instance_count = lair_points.size()
	for i: int in lair_points.size():
		var at: Vector2 = lair_points[i]
		var basis := Basis(Vector3.UP, (_hash(i, 2) - 0.5) * 1.2)
		mm.set_instance_transform(i, Transform3D(basis, intro.stage.point(Vector3(at.x, 0.0, at.y))))
		mm.set_instance_color(i, Color.WHITE)
		var custom := Color(0.0, 0.0, 0.0, _hash(i, 3) * 7.0)
		mm.set_instance_custom_data(i, custom)
		_lair_sent.append(custom)
	manholes.multimesh = mm
	manholes.custom_aabb = AABB(Vector3(-20.0, -2.0, -2000.0), Vector3(40.0, 6.0, 4000.0))
	add_child(manholes)


# --- Every frame -----------------------------------------------------------------------------------

func update(t: float) -> void:
	var foot: float = intro.wall_foot_z(t)
	var cam: Vector3 = intro.camera_at(t)[0]
	_update_lairs(t)
	for l: Leaper in leapers:
		_update_leaper(l, t, foot, cam)
	_update_crowd(t, foot, cam)


func _update_lairs(t: float) -> void:
	var mm: MultiMesh = manholes.multimesh
	for i: int in lair_points.size():
		var rattle: float = 1.0 if t >= lair_shake[i] and t < lair_burst[i] else 0.0
		var open: float = clampf((t - lair_burst[i]) / OPEN_SECONDS, 0.0, 1.0) if lair_burst[i] != INF else 0.0
		var custom := Color(rattle, snappedf(open, 0.01), 0.0, _lair_sent[i].a)
		if custom != _lair_sent[i]:
			_lair_sent[i] = custom
			mm.set_instance_custom_data(i, custom)


## Whether manhole `i` has burst open by `t` (tests).
func lair_open(i: int, t: float) -> bool:
	return lair_burst[i] != INF and t >= lair_burst[i]


func _update_leaper(l: Leaper, t: float, foot: float, cam: Vector3) -> void:
	var p := Vector3.ZERO
	var yaw: float = 0.0
	var swipe: float = 0.0
	var scurry: float = 1.0
	var leap_yaw: float = atan2(-(l.to.x - l.from.x), l.to.z - l.from.z)
	if t < l.start:
		l.shown = false
		l.node.visible = false
		return
	if t < l.end:
		var u: float = (t - l.start) / (l.end - l.start)
		p = l.from.lerp(l.to, u)
		p.y = lerpf(l.from.y, l.to.y, u) + l.arc * sin(PI * u)
		yaw = leap_yaw
		# Claws up as it pounces.
		swipe = 0.3 * sin(PI * u)
	elif l.after == After.HOLD and t < l.hold_until:
		p = l.to
		# Turned to face the runner coming at it (it landed facing across), rearing and swiping as they pass.
		yaw = lerp_angle(leap_yaw, PI, clampf((t - l.end) / 0.2, 0.0, 1.0))
		scurry = 0.3
		if l.swipe_at >= 0.0 and t >= l.swipe_at:
			swipe = clampf((t - l.swipe_at) / SWIPE_SECONDS, 0.0, 1.0)
	else:
		# Giving chase: up to its speed, down the street after the runner, falling behind.
		var from_t: float = maxf(l.end, l.hold_until)
		var tc: float = t - from_t
		var v: float = intro.speed * n.chase_share
		p = l.to + Vector3(0.0, 0.0, v * _ramped(tc, CHASE_RAMP))
		p.x = lerpf(l.to.x, l.chase_x, smoothstep(0.0, 0.4, tc))
		yaw = lerp_angle(PI if l.after == After.HOLD else leap_yaw, 0.0, clampf(tc / 0.25, 0.0, 1.0))
	l.position = p
	l.shown = p.z > foot - 0.3 and p.distance_to(cam) > CAMERA_CLEARANCE
	l.node.visible = l.shown
	if not l.shown:
		return
	l.node.global_transform = Transform3D(Basis(Vector3.UP, yaw), intro.stage.point(p))
	l.node.set_instance_shader_parameter(&"swipe", swipe)
	l.node.set_instance_shader_parameter(&"scurry", scurry)


## Metres covered `tc` seconds after setting off at 1 m/s, reaching it in `ramp` seconds (speeding up steadily).
static func _ramped(tc: float, ramp: float) -> float:
	if tc <= 0.0:
		return 0.0
	if tc < ramp:
		return tc * tc / (2.0 * ramp)
	return tc - ramp * 0.5


func _update_crowd(t: float, foot: float, cam: Vector3) -> void:
	var fall: float = sqrt(2.0 * n.rain_height / maxf(n.rain_gravity, 0.1))
	for i: int in crowd_kind.size():
		var tau: float = t - crowd_start[i]
		var shown: bool = tau >= 0.0
		var p := Vector3.ZERO
		var fwd := Vector3(0.0, 0.0, 1.0)
		var up := Vector3.UP
		var squash: float = 1.0
		var v: float = intro.speed * crowd_share[i]
		var slot: float = crowd_slot[i]
		var seed: float = crowd_seed[i]
		if shown and crowd_kind[i] == Kind.POUR:
			var from: Vector3 = crowd_from[i]
			if tau < HOP_SECONDS:
				# Out of the manhole, up and over toward its lane.
				var u: float = tau / HOP_SECONDS
				p = Vector3(lerpf(from.x, lerpf(from.x, slot, 0.3), u), lerpf(from.y, 0.0, u) + HOP_HEIGHT * sin(PI * u),
					from.z + 0.4 * u)
				fwd = Vector3(slot - from.x, 0.6 * cos(PI * u), 1.0)
			else:
				var tr: float = tau - HOP_SECONDS
				var side_k: float = smoothstep(0.0, 0.7, tr)
				p = Vector3(lerpf(lerpf(from.x, slot, 0.3), slot, side_k), 0.0, from.z + 0.4 + v * _ramped(tr, POUR_RAMP)
					- _fallen_back(tr - n.fall_back_after))
				fwd = Vector3((slot - from.x) * 0.7 * (1.0 - side_k), 0.0, 1.0)
		elif shown:
			var from: Vector3 = crowd_from[i]
			if tau < fall:
				# Dropping from above the camera's view, legs splayed, nose dipping.
				p = Vector3(slot, n.rain_height - 0.5 * n.rain_gravity * tau * tau, from.z + v * tau)
				fwd = Vector3(0.0, -0.35, 1.0)
			else:
				var tl: float = tau - fall
				p = Vector3(slot + sin(tl * 3.0 + seed * 9.0) * 0.12, 0.0, from.z + v * tau - _fallen_back(tl - n.fall_back_after))
				# Landing: squashed flat, springing back.
				squash = lerpf(0.55, 1.0, smoothstep(0.0, 0.18, tl))
		if shown:
			p.y += absf(sin(t * 14.0 + seed * 40.0)) * 0.05 * float(p.y <= 0.05)
			shown = p.z > foot - 0.3 and p.distance_to(cam) > CAMERA_CLEARANCE
		crowd_position[i] = p
		crowd_shown[i] = 1 if shown else 0
		_write(i, p, fwd, up, squash if shown else 0.0, seed)
	crowd.multimesh.buffer = _buffer


## Metres a screech has dropped back `tf` seconds after it started to (none before).
func _fallen_back(tf: float) -> float:
	return 0.5 * n.fall_back * tf * tf if tf > 0.0 else 0.0


## Instance `i`'s transform (facing `fwd`, its back toward `up`, squashed to `squash` of its height: 0 hidden),
## white colour and custom data (swipe, bristle, scurry, seed), into the buffer (MultiMesh's layout: the basis by
## rows and the origin, then the colour, then the custom data).
func _write(i: int, p: Vector3, fwd: Vector3, up: Vector3, squash: float, seed: float) -> void:
	var o: int = i * 20
	var hidden: bool = squash <= 0.0
	var world: Vector3 = Vector3(0.0, -100.0, 0.0) if hidden else intro.stage.point(p)
	# Track z is world -z: the body (which faces -Z) faces down `fwd` in world space.
	var f := Vector3(fwd.x, fwd.y, -fwd.z).normalized()
	var z_axis: Vector3 = -f
	var x_axis: Vector3 = up.cross(z_axis)
	x_axis = x_axis.normalized() if x_axis.length_squared() > 0.0001 else Vector3.RIGHT
	var y_axis: Vector3 = z_axis.cross(x_axis)
	var s: float = 0.0 if hidden else _scale * (0.85 + 0.3 * seed)
	x_axis *= s
	y_axis *= s * squash
	z_axis *= s
	_buffer[o] = x_axis.x
	_buffer[o + 1] = y_axis.x
	_buffer[o + 2] = z_axis.x
	_buffer[o + 3] = world.x
	_buffer[o + 4] = x_axis.y
	_buffer[o + 5] = y_axis.y
	_buffer[o + 6] = z_axis.y
	_buffer[o + 7] = world.y
	_buffer[o + 8] = x_axis.z
	_buffer[o + 9] = y_axis.z
	_buffer[o + 10] = z_axis.z
	_buffer[o + 11] = world.z
	_buffer[o + 12] = 1.0
	_buffer[o + 13] = 1.0
	_buffer[o + 14] = 1.0
	_buffer[o + 15] = 1.0
	_buffer[o + 16] = 0.0
	_buffer[o + 17] = CROWD_BRISTLE
	_buffer[o + 18] = 1.0
	_buffer[o + 19] = seed * 10.0


## Screeches of the crowd in view now (tests).
func crowd_shown_count() -> int:
	var c: int = 0
	for s: int in crowd_shown:
		c += s
	return c


func _hash(i: int, k: int) -> float:
	return float(posmod(hash([i, k, "swarm_intro"]), 10007)) / 10007.0
