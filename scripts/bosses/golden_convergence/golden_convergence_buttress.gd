class_name GoldenConvergenceButtress
extends Node3D
## A Flying Buttress (GDD §10, the owner's new doodad for this fight): "taller than other doodads. It looks
## like it holds up buildings out of sight on either side of the track ... A gate: its pier rises from an
## inner lane, never an outer one, with a tall arched opening at its foot that the runner runs through. Its
## flying arch leaps from the top of the pier out over the wall toward the unseen building" (proposed: it
## leans toward the nearer edge of the track, either way from the middle lane by the fight's seed). "The
## sides of the gate are solid but safe, like any doodad: a lane switch into one bumps the player."
## One pooled gate (GoldenConvergence.place_buttress takes one; the pool is made with the fight):
## - place(lane, at, lean): it rises out of the causeway in `lane` (its pier's middle at track distance `at`,
##   the horizontal pass's live line) over buttress_rise_seconds with a deep rumble, its sides a lane
##   blocker (LAYER_LANE_BLOCKER, no hurt) over its lane from a lane switch's run before its front to its back:
##   a switch into its lane there bumps the runner back, as into a doodad's side; a runner already in its
##   lane runs through the arch;
## - smash() (E5d-b's Fist Slam, E5d-d's Pounce): it crumbles over crumble_seconds (the pier breaks and sinks,
##   the flying arch falls away, dust), its sides no longer block, and `smashed` tells the encounter;
## - sink() (E5d-b): it sinks back into the causeway the way it rose (a slam sequence's other gate once a
##   buttress hit has ended the sequence) and goes back to the pool;
## - span(), opening_x(), spark_point(), lean, lane, at: where it stands, for the attacks that use it.
## DESIGN-TBD (docs/questions/e5d.md, E5d-a 8): its size and how soon it rises are in the tuning; its sides
## block a switch into its lane, not one out of the arch while inside it.
## Its look: the palace's white and cream marble with gold trims (never glowing: safe things look safe), the
## cult's emblem in gold relief over the arch, a pinnacle with a gold finial on the pier, and the flying arch
## leaping up and out over the balustrade beyond the view. The legs keep inside its lane's edges, and the
## stone over the opening is far above a jump (arch_height), so what looks like contact is contact. Meshes
## are built once per lane count, lane and lean (mesh_for) and shared.

signal smashed(buttress: GoldenConvergenceButtress)

enum State { FREE, RISING, STANDING, CRUMBLING, SINKING }

## The opening's width (the runner's body is 0.6 m wide) and the legs either side fill the rest of the lane.
const OPENING: float = 1.36
## The pier widens this much each side above the opening's crown (out of every runner's reach).
const OVERHANG: float = 0.35
## The flying arch: its section, and how far out past the track's edge it's drawn, rising this high over
## the pier's top as it goes.
const ARCH_WIDTH: float = 1.5
const ARCH_DEPTH: float = 1.3
const ARCH_OUT: float = 70.0
const ARCH_RISE: float = 38.0
## The pinnacle on the pier.
const PINNACLE: float = 4.5
## Colours (sRGB): the palace's marble, a darker cream for the arch's inside, gold trims.
const MARBLE := Color(0.87, 0.85, 0.8)
const SHADE := Color(0.62, 0.58, 0.52)
const GOLD := Color(0.78, 0.66, 0.42)
## Every pier's mesh by lane count, lane and lean.
static var _meshes: Dictionary = {}

var boss: GoldenConvergence
var state: State = State.FREE
var lane: int = -1
## The pier's middle along the track (the horizontal pass's live line).
var at: float = 0.0
## The side its flying arch leans to (-1 left, 1 right).
var lean: int = 1
## How far it has risen (0-1) and crumbled (0-1).
var rise: float = 0.0
var crumble: float = 0.0
var places: int = 0

var _pier: MeshInstance3D
var _pivot: Node3D
var _blocker: Area3D
var _blocker_shape: BoxShape3D
var _time: float = 0.0


## Builds the gate's nodes (once, for the pool), under the encounter, hidden.
func setup(p_boss: GoldenConvergence) -> void:
	boss = p_boss
	name = "Buttress"
	top_level = true
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_pier = MeshInstance3D.new()
	_pier.name = "Pier"
	_pier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_pier)
	_blocker = Area3D.new()
	_blocker.name = "Sides"
	_blocker.collision_layer = 0
	_blocker.collision_mask = 0
	_blocker.monitoring = false
	add_child(_blocker)
	var shape := CollisionShape3D.new()
	_blocker_shape = BoxShape3D.new()
	shape.shape = _blocker_shape
	_blocker.add_child(shape)
	release()


## Raises it in `lane` with its pier's middle at track distance `at`, its flying arch leaning to `p_lean`.
func place(p_lane: int, p_at: float, p_lean: int) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	lane = p_lane
	at = p_at
	lean = -1 if p_lean < 0 else 1
	state = State.RISING
	rise = 0.0
	crumble = 0.0
	places += 1
	_time = 0.0
	_pier.mesh = mesh_for(geo, t, lane, lean, boss.solid_material())
	global_position = Vector3(geo.lane_x(lane), 0.0, TrackGeometry.world_z(at))
	_pivot.transform = Transform3D.IDENTITY
	visible = true
	# Its sides: over the middle of its lane (where Player._lane_blocked looks), from a lane switch's run
	# before its front (at the run speed) to its back.
	var lead: float = boss.world.tuning.run_speed * boss.world.tuning.lane_switch_time * t.blocker_lead
	var depth: float = t.pier_depth + lead
	_blocker_shape.size = Vector3(geo.lane_width * 0.4, 3.0, depth)
	_blocker.position = Vector3(0.0, 1.5, t.pier_depth * 0.5 - depth * 0.5 + lead)
	_blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER
	_apply()
	boss.sound(&"gc_buttress", boss.sound_point(global_position))
	boss.log_event(&"buttress_placed", {"lane": lane, "at": at, "lean": lean, "runner": boss.player_distance()})


## Back to the pool: hidden, out of the way, blocking nothing.
func release() -> void:
	state = State.FREE
	lane = -1
	visible = false
	if _blocker != null:
		_blocker.collision_layer = 0
	global_position = Vector3(0.0, -400.0, 0.0)


## Smashed (GDD §10, the Fist Slam: "baited into a Flying Buttress, the fist destroys it"): it crumbles and
## its sides stop blocking at once.
func smash() -> void:
	if state == State.FREE or state == State.CRUMBLING:
		return
	state = State.CRUMBLING
	crumble = 0.0
	_time = 0.0
	_blocker.collision_layer = 0
	var top: Vector3 = spark_point()
	boss.world.effects.burst(top, Color(0.86, 0.84, 0.78), 40, 1.6)
	boss.world.effects.burst(global_position + Vector3(0.0, 1.0, 0.0), Color(0.75, 0.72, 0.66), 30, 1.4)
	boss.world.effects.shake(0.35, 0.4)
	boss.sound(&"gc_crumble", boss.sound_point(global_position))
	boss.log_event(&"buttress_smashed", {"lane": lane, "at": at})
	smashed.emit(self)


## E5d-b: sinks back into the causeway the way it rose, its sides blocking nothing from the start (a Fist
## Slam sequence's other gate, once a buttress hit has ended the sequence), then goes back to the pool.
func sink() -> void:
	if not standing():
		return
	state = State.SINKING
	_time = (1.0 - rise) * boss.tuning.buttress_rise_seconds
	_blocker.collision_layer = 0
	boss.sound(&"gc_buttress", boss.sound_point(global_position))
	boss.log_event(&"buttress_sunk", {"lane": lane, "at": at})


## True while it stands whole (risen or rising): its sides block, its arch shelters.
func standing() -> bool:
	return state == State.RISING or state == State.STANDING


## True while it's in play at all (standing or crumbling).
func in_use() -> bool:
	return state != State.FREE


## True while it's still in play as placement number `placement` (its `places` when it rose): an attack holding
## it since knows it hasn't gone back to the pool and risen again for another (a stale reference never moves
## someone else's gate).
func is_placement(placement: int) -> bool:
	return state != State.FREE and places == placement


## The track span its pier covers.
func span() -> Vector2:
	var half: float = boss.tuning.pier_depth * 0.5
	return Vector2(at - half, at + half)


## The track span its sides block a lane switch into its lane over (its lane blocker).
func blocked_span() -> Vector2:
	var t: GoldenConvergenceTuning = boss.tuning
	var lead: float = boss.world.tuning.run_speed * boss.world.tuning.lane_switch_time * t.blocker_lead
	return Vector2(at - t.pier_depth * 0.5 - lead, at + t.pier_depth * 0.5)


## World x of the opening's middle (its lane's).
func opening_x() -> float:
	return boss.world.geo.lane_x(lane)


## Where bullets spark off the stone above the opening (world space).
func spark_point() -> Vector3:
	return Vector3(opening_x(), boss.tuning.arch_height + 0.6, TrackGeometry.world_z(at - boss.tuning.pier_depth * 0.5))


func tick(delta: float) -> void:
	if state == State.FREE:
		return
	_time += delta
	var t: GoldenConvergenceTuning = boss.tuning
	match state:
		State.RISING:
			rise = clampf(_time / maxf(t.buttress_rise_seconds, 0.05), 0.0, 1.0)
			if rise >= 1.0:
				state = State.STANDING
		State.CRUMBLING:
			crumble = clampf(_time / maxf(t.crumble_seconds, 0.05), 0.0, 1.0)
			if crumble >= 1.0:
				visible = false
		State.SINKING:
			rise = clampf(1.0 - _time / maxf(t.buttress_rise_seconds, 0.05), 0.0, 1.0)
			if rise <= 0.0:
				release()
				return
	_apply()


func _apply() -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var k: float = 1.0 - pow(1.0 - rise, 3.0)
	var sink: float = (t.pier_height + PINNACLE + 2.0) * (1.0 - k)
	var c: float = crumble * crumble
	sink += (t.pier_height + PINNACLE) * 0.75 * c
	_pivot.transform = Transform3D(Basis(Vector3.BACK, -lean * 0.5 * c) * Basis(Vector3.RIGHT, -0.18 * c),
		Vector3(lean * 1.5 * c, -sink, 0.0))


## The pier's mesh for `lane` at `geo`'s lane count, its arch leaning to `p_lean`, in the gate's local space
## (its lane's middle at x = 0, the floor at y = 0, its pier's middle at z = 0, the runner coming from +z).
static func mesh_for(geo: TrackGeometry, t: GoldenConvergenceTuning, p_lane: int, p_lean: int, material: Material) -> ArrayMesh:
	var key: String = "%d|%d|%d|%s|%s|%s|%s|%d" % [geo.lane_count, p_lane, p_lean, geo.lane_width, t.pier_depth,
		t.arch_height, t.pier_height, material.get_instance_id()]
	var found: ArrayMesh = _meshes.get(key)
	if found != null:
		return found
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var half_lane: float = geo.lane_width * 0.5 - 0.03
	var half_open: float = OPENING * 0.5
	var d: float = t.pier_depth * 0.5
	var spring: float = t.arch_height - half_open
	var top: float = t.pier_height
	var wide: float = half_lane + OVERHANG
	var crown: float = t.arch_height + 0.9
	# The legs, inside the lane's edges, on gold-trimmed plinths.
	for sx: float in [-1.0, 1.0]:
		var x0: float = sx * half_open
		var x1: float = sx * half_lane
		_block(s, minf(x0, x1), maxf(x0, x1), 0.0, crown, -d, d, MARBLE, 0)
		_block(s, minf(x0, x1) - 0.05, maxf(x0, x1) + 0.05, 0.0, 0.42, -d - 0.05, d + 0.05, GOLD, MeshKit.PAT_GOLD, 0.7)
	# The arch over the opening: its stone in segments around the curve, its inside a darker cream.
	var segs: int = 8
	for i: int in segs:
		var a0: float = PI * float(i) / segs
		var a1: float = PI * float(i + 1) / segs
		var p0 := Vector2(-cos(a0) * half_open, spring + sin(a0) * half_open)
		var p1 := Vector2(-cos(a1) * half_open, spring + sin(a1) * half_open)
		# The arch's inside (facing down into the opening).
		_face(s, Vector3(p0.x, p0.y, d), Vector3(p1.x, p1.y, d), Vector3(p1.x, p1.y, -d), Vector3(p0.x, p0.y, -d),
			Vector3(-(p0.x + p1.x), -((p0.y + p1.y) - 2.0 * spring), 0.0), SHADE, 0)
		# The spandrel faces front and back, from the curve up to the crown's level.
		for sz: float in [-1.0, 1.0]:
			_face(s, Vector3(p0.x, p0.y, sz * d), Vector3(p0.x, crown, sz * d), Vector3(p1.x, crown, sz * d),
				Vector3(p1.x, p1.y, sz * d), Vector3(0.0, 0.0, sz), MARBLE, MeshKit.PAT_MARBLE, 1.0)
		# A gold rim around the arch's face toward the runner.
		var r0: Vector2 = p0 + (p0 - Vector2(0.0, spring)).normalized() * 0.16
		var r1: Vector2 = p1 + (p1 - Vector2(0.0, spring)).normalized() * 0.16
		_face(s, Vector3(p0.x, p0.y, d + 0.02), Vector3(r0.x, r0.y, d + 0.02), Vector3(r1.x, r1.y, d + 0.02),
			Vector3(p1.x, p1.y, d + 0.02), Vector3.BACK, GOLD, MeshKit.PAT_GOLD, 0.8)
	# The opening's straight sides, below the arch's spring (the legs' inner faces are their blocks').
	# The pier above the crown, wider than its lane (far above every runner), with a gold cornice.
	_block(s, -wide, wide, crown, top, -d - 0.2, d + 0.2, MARBLE, MeshKit.PAT_MARBLE, 0.0)
	_block(s, -wide - 0.12, wide + 0.12, crown - 0.12, crown + 0.08, -d - 0.32, d + 0.32, GOLD, MeshKit.PAT_GOLD, 0.8)
	_block(s, -wide - 0.15, wide + 0.15, top - 0.35, top, -d - 0.35, d + 0.35, GOLD, MeshKit.PAT_GOLD, 0.8)
	# The cult's emblem in gold relief on its face, over the arch (gold alone: no red stone on the boss's
	# side of the fight, where red means a weak point).
	var size: float = minf(wide * 1.5, 2.6)
	var emblem: ArrayMesh = CultEmblem.build_mesh(GoldenSkin.cult_emblem_option(), size, GOLD, GOLD, 0.0, material)
	var em := MeshLayer.new()
	var arrays: Array = emblem.surface_get_arrays(0)
	em.verts = arrays[Mesh.ARRAY_VERTEX]
	em.colors = arrays[Mesh.ARRAY_COLOR]
	em.uvs = arrays[Mesh.ARRAY_TEX_UV]
	em.uv2s = arrays[Mesh.ARRAY_TEX_UV2]
	for i: int in em.uv2s.size():
		em.uv2s[i] = Vector2(MeshKit.PAT_GOLD, 0.85)
	s.append(em, Transform3D(Basis.IDENTITY, Vector3(0.0, crown + (top - crown) * 0.42, d + 0.23)))
	# The pinnacle with its gold finial.
	s.prism(Vector3(0.0, top, 0.0), wide * 0.75, PINNACLE * 0.45, 4, MARBLE, 0.0, MeshKit.PAT_MARBLE, true, 1.0)
	s.prism_xform(Transform3D(Basis.from_scale(Vector3(wide * 0.55, PINNACLE * 0.45, wide * 0.55)),
		Vector3(0.0, top + PINNACLE * 0.45, 0.0)), 4, MARBLE, 0.0, MeshKit.PAT_MARBLE, true, 1.0)
	s.prism(Vector3(0.0, top + PINNACLE * 0.9, 0.0), 0.32, PINNACLE * 0.25, 6, GOLD, 0.0, MeshKit.PAT_GOLD, true, 0.9)
	# The flying arch: from the pier's top out over the lanes on its side and the balustrade, rising toward
	# the unseen building beyond the view (high over the lanes: never a ceiling).
	var x_edge: float = p_lean * geo.wall_x() - geo.lane_x(p_lane)
	var x_end: float = x_edge + p_lean * ARCH_OUT
	var steps: int = 10
	var prev_top := Vector3.ZERO
	var prev_bottom := Vector3.ZERO
	for i: int in steps + 1:
		var u: float = float(i) / steps
		var x: float = lerpf(p_lean * wide * 0.6, x_end, u)
		# A quarter-ellipse leaping up and out.
		var y: float = top - 1.8 + ARCH_RISE * sin(u * PI * 0.5)
		var thick: float = lerpf(2.4, ARCH_DEPTH, u)
		var tp := Vector3(x, y + thick * 0.5, 0.0)
		var bt := Vector3(x, y - thick * 0.5, 0.0)
		if i > 0:
			var w: float = ARCH_WIDTH * 0.5
			# Top, underside, and both sides of this length of the arch.
			_face(s, prev_top + Vector3(0, 0, w), tp + Vector3(0, 0, w), tp + Vector3(0, 0, -w), prev_top + Vector3(0, 0, -w),
				Vector3(-(tp.y - prev_top.y) * p_lean, absf(tp.x - prev_top.x), 0.0), MARBLE, MeshKit.PAT_MARBLE, 1.0)
			_face(s, prev_bottom + Vector3(0, 0, w), bt + Vector3(0, 0, w), bt + Vector3(0, 0, -w), prev_bottom + Vector3(0, 0, -w),
				Vector3((bt.y - prev_bottom.y) * p_lean, -absf(bt.x - prev_bottom.x), 0.0), SHADE, 0)
			for sz: float in [-1.0, 1.0]:
				_face(s, prev_bottom + Vector3(0, 0, sz * w), prev_top + Vector3(0, 0, sz * w), tp + Vector3(0, 0, sz * w),
					bt + Vector3(0, 0, sz * w), Vector3(0, 0, sz), MARBLE, MeshKit.PAT_MARBLE, 1.0)
			# A gold band along its top edge facing the runner.
			_face(s, prev_top + Vector3(0, -0.15, w + 0.02), prev_top + Vector3(0, 0.0, w + 0.02),
				tp + Vector3(0, 0.0, w + 0.02), tp + Vector3(0, -0.15, w + 0.02), Vector3.BACK, GOLD, MeshKit.PAT_GOLD, 0.8)
		prev_top = tp
		prev_bottom = bt
	# Its far end, closed (it runs on beyond the view into the building it holds up).
	var w2: float = ARCH_WIDTH * 0.5
	_face(s, prev_bottom + Vector3(0, 0, w2), prev_top + Vector3(0, 0, w2), prev_top + Vector3(0, 0, -w2),
		prev_bottom + Vector3(0, 0, -w2), Vector3(p_lean, 0.0, 0.0), SHADE, 0)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[key] = mesh
	return mesh


## An axis-aligned block from (x0, y0, z0) to (x1, y1, z1), its bottom left open.
static func _block(s: MeshLayer, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, color: Color,
		pattern: int, param: float = 0.0) -> void:
	s.box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, y1 - y0, z1 - z0), color, 0.0,
		pattern, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, param)


## A four-cornered face toward `outward` (either winding).
static func _face(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color,
		pattern: int, param: float = 0.0) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		s.quad(a, d, c, b, color, 0.0, pattern, param)
	else:
		s.quad(a, b, c, d, color, 0.0, pattern, param)
