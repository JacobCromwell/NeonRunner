class_name GoldenConvergenceTower
extends Node3D
## The toppled tower (GDD §10, the Fist Slam: "Baited into a Flying Buttress, the fist destroys it. The building
## it held up, off screen, topples forward along the track on the side the buttress's arch leans toward, and
## its side forms a wall the runner can wall-run on (the normal wall run, no new move). The tower is scenery and
## never lands on the track. It stays for about 8-12 seconds"; task E5d-b). One pooled tower (the slams keep a
## pool, GoldenConvergenceSlams), built once in code in the Grand Court's look (GoldenCourtSkin: white marble,
## gold bands, lit windows, a gold crown and spire) at the length the run's speed gives it:
## - topple(side, foot, length, wall_from, wall_to): it appears standing beside the causeway on `side`, its
##   foot at track distance `foot` (behind the runner, out of view: "off screen"), and topples forward along the
##   track over tower_fall_seconds (an accelerating fall, with a rumble: gc_topple), landing in a cloud of dust
##   and a shake (both honour the settings: the shake through RunEffects, no flash at all). It lies beside the
##   causeway, its side flush with the wall's face from just inside the balustrade outward; as it lands, the
##   court opens the wall on `side` over [wall_from, wall_to] (GoldenConvergenceCourt.open_wall), so the
##   runner can wall-run it (and wall hop on it), and the strafe's wall rules read it;
## - once the runner is past wall_to (the court drops a wall runner there), the wall closes and the tower sinks
##   away into the pools behind them over tower_sink_seconds, then goes back to the pool.
## It never collides: the court's wall rules are the wall (TrackBuilder's walls are the gameplay ones; the
## balustrade's blockers are taken up over the open stretch). Visual only otherwise.

enum State { FREE, FALLING, DOWN, SINKING }

## Its square section's corners are cut off this much (a palace tower, not a box).
const CHAMFER: float = 1.4
## Gold bands round it this far apart along its length, rows of lit windows between them.
const BAND_SPACING: float = 12.0
const WINDOW_SPACING: float = 4.0
## The crown at its top end: how far the gold cap and the spire reach past its shaft.
const CROWN: float = 9.0
## Its side lies this far inside the wall's line, covering the balustrade's face.
const FLUSH: float = 0.04
## The sink: how far down it goes.
const SINK_DEPTH: float = 40.0
## E5d polish: its wall outlasts the barrage that follows the bait by this long at least (wall_seconds).
const WALL_SPARE: float = 1.5
## Every tower's mesh by length and section.
static var _meshes: Dictionary = {}

var boss: GoldenConvergence
var state: State = State.FREE
## The side it lies on (-1 left, 1 right), where its foot stands, its length, and the wall it makes.
var side: int = 1
var foot: float = 0.0
var length: float = 0.0
var wall_from: float = 0.0
var wall_to: float = 0.0
## The court's opening while it's down (-1: none).
var wall_id: int = -1
## How far it has fallen (0 standing, 1 down) and sunk (0-1).
var fall: float = 0.0
var sunk: float = 0.0
var falls: int = 0

var _mesh: MeshInstance3D
var _time: float = 0.0
var _landed: bool = false


## Builds its node (once, for the pool), under the encounter, hidden.
func setup(p_boss: GoldenConvergence) -> void:
	boss = p_boss
	name = "Tower"
	top_level = true
	_mesh = MeshInstance3D.new()
	_mesh.name = "Body"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Long and thin along the track: never culled while any of it is in view.
	_mesh.extra_cull_margin = 20.0
	add_child(_mesh)
	release()


## The length a tower needs at the run's speed to lie from where it stands to past its wall's end
## (GoldenConvergenceSlams plans one for every chance: an ahead slam's gate is the farthest).
static func length_for(t: GoldenConvergenceTuning, movement: MovementTuning, run_speed: float, reach: float) -> float:
	return run_speed * wall_seconds(t, movement) + reach + t.tower_behind + CROWN


## How long its side stays a wall (seconds of running from its gate): tower_wall_seconds, or long enough for the
## barrage that follows the bait to warn, burn out and WALL_SPARE more (its fire's stretch runs a dash and
## fire_ahead past where the runner is as it goes out) with the wall still beside the runner. E5d polish: F6's
## longer barrage steps could otherwise end the wall under a wall runner while the fire still burns.
static func wall_seconds(t: GoldenConvergenceTuning, movement: MovementTuning) -> float:
	return maxf(t.tower_wall_seconds, GoldenConvergenceBarrage.warning_for(t, movement) + t.fire_seconds + WALL_SPARE)


## Builds (or finds) its meshes for `p_length` now, not mid-fight.
func prewarm(p_length: float) -> void:
	for s: int in [-1, 1]:
		_mesh.mesh = mesh_for(boss.tuning, p_length, boss.world.skin as GoldenSkin, s)


## It falls on `side` (-1 left, 1 right): standing with its foot at track distance `p_foot` beside the
## causeway, out of view, it topples forward along the track; landed, its side is the wall over
## [p_wall_from, p_wall_to]. Its length must reach from its foot past p_wall_to (length_for).
func topple(p_side: int, p_foot: float, p_length: float, p_wall_from: float, p_wall_to: float) -> void:
	side = -1 if p_side < 0 else 1
	foot = p_foot
	length = p_length
	wall_from = p_wall_from
	wall_to = p_wall_to
	state = State.FALLING
	fall = 0.0
	sunk = 0.0
	falls += 1
	_time = 0.0
	_landed = false
	_mesh.mesh = mesh_for(boss.tuning, length, boss.world.skin as GoldenSkin, side)
	visible = true
	_apply()
	boss.sound(&"gc_topple", boss.sound_point(boss.world.lane_point(0 if side < 0 else boss.lane_count() - 1,
		boss.player_distance() + 20.0, 6.0)))
	boss.log_event(&"tower_fall", {"side": side, "foot": foot, "length": length, "wall_from": wall_from,
		"wall_to": wall_to, "runner": boss.player_distance()})


## Back to the pool: hidden, its wall closed.
func release() -> void:
	if wall_id >= 0 and boss != null and boss.court != null:
		boss.court.close_wall(wall_id)
	wall_id = -1
	state = State.FREE
	visible = false
	global_position = Vector3(0.0, -500.0, 0.0)


func in_use() -> bool:
	return state != State.FREE


## True while it lies beside the causeway with its wall open.
func down() -> bool:
	return state == State.DOWN


## World x of its side facing the track (the wall's face, just inside it).
func face_x() -> float:
	return side * (boss.world.geo.wall_x() - FLUSH)


func tick(delta: float) -> void:
	if state == State.FREE:
		return
	_time += delta
	var t: GoldenConvergenceTuning = boss.tuning
	match state:
		State.FALLING:
			fall = clampf(_time / maxf(t.tower_fall_seconds, 0.05), 0.0, 1.0)
			if fall >= 1.0:
				_land()
		State.DOWN:
			if boss.player_distance() > wall_to + 2.0:
				# The runner is past its end (the court drops a wall runner there): it goes.
				if wall_id >= 0:
					boss.court.close_wall(wall_id)
					wall_id = -1
				state = State.SINKING
				_time = 0.0
				boss.log_event(&"tower_sink", {"side": side})
		State.SINKING:
			sunk = clampf(_time / maxf(t.tower_sink_seconds, 0.05), 0.0, 1.0)
			if sunk >= 1.0:
				release()
				return
	_apply()


func _land() -> void:
	state = State.DOWN
	_time = 0.0
	_landed = true
	wall_id = boss.court.open_wall(side, wall_from, wall_to)
	var effects: RunEffects = boss.world.effects
	if effects != null:
		effects.shake(0.6, 0.55)
		var d: float = boss.player_distance()
		var x: float = face_x() + side * 2.0
		for k: int in 4:
			effects.burst(Vector3(x, 0.8, TrackGeometry.world_z(d + 14.0 + float(k) * 22.0)), Color(0.78, 0.74, 0.68), 30, 1.6)
		effects.debris(Vector3(x, 1.0, TrackGeometry.world_z(d + 20.0)), Color(0.8, 0.77, 0.7), 12, 1.4)
	boss.log_event(&"tower_down", {"side": side, "wall_from": wall_from, "wall_to": wall_to, "id": wall_id,
		"runner": boss.player_distance()})


## Its pose: pivoting forward about its foot's front edge, from standing (its length up) to lying along the
## track (its length forward), an accelerating fall; sinking straight down afterwards.
func _apply() -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var half: float = t.tower_width * 0.5
	var x: float = side * (boss.world.geo.wall_x() - FLUSH + half)
	var y: float = -t.tower_depth - SINK_DEPTH * sunk * sunk
	# Up at 0, forward at 1: the angle about +x from lying.
	var k: float = fall * fall
	var angle: float = PI * 0.5 * (1.0 - k)
	global_transform = Transform3D(Basis(Vector3.RIGHT, angle), Vector3(x, y, TrackGeometry.world_z(foot)))


# --- Its look ----------------------------------------------------------------------------------------

## The tower's mesh for a tower lying on `p_side`, along -z from its foot (z = 0) over `p_length`, its
## section (tower_width square, corners cut) from y = 0 up and centred on x = 0: the palace's marble, gold
## bands round it, rows of lit windows on its top and its outer side (the side away from the track: none on
## the side the runner runs), a dark broken foot, a gold crown and spire at its top end. Built once per
## length and side and shared.
static func mesh_for(t: GoldenConvergenceTuning, p_length: float, skin: GoldenSkin, p_side: int = 1) -> ArrayMesh:
	var use: GoldenSkin = skin if skin != null else GoldenSkin.new()
	var material: Material = use.solid_material()
	var key: String = "%s|%s|%d|%d" % [snappedf(p_length, 0.1), t.tower_width, p_side, material.get_instance_id()]
	var found: ArrayMesh = _meshes.get(key)
	if found != null:
		return found
	var marble: Color = use.stone_colors[0]
	var shade: Color = use.stone_colors[2] if use.stone_colors.size() > 2 else marble.darkened(0.25)
	var gold: Color = use.gold_color
	var lit: Color = use.window_warm_color
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var h: float = t.tower_width * 0.5
	var c: float = minf(CHAMFER, h * 0.4)
	var shaft: float = p_length - CROWN
	# The section, counter-clockwise seen from its foot (+z): centred on x = 0, from y = 0 to the width.
	var cy: float = h
	var section: Array[Vector2] = [Vector2(h, cy - h + c), Vector2(h, cy + h - c), Vector2(h - c, cy + h),
		Vector2(-h + c, cy + h), Vector2(-h, cy + h - c), Vector2(-h, cy - h + c), Vector2(-h + c, cy - h),
		Vector2(h - c, cy - h)]
	var center := Vector2(0.0, cy)
	for i: int in section.size():
		var a: Vector2 = section[i]
		var b: Vector2 = section[(i + 1) % section.size()]
		var out: Vector2 = ((a + b) * 0.5 - center).normalized()
		_face(s, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), Vector3(b.x, b.y, -shaft), Vector3(a.x, a.y, -shaft),
			Vector3(out.x, out.y, 0.0), marble, MeshKit.PAT_MARBLE, 0.0)
	# Its broken foot, dark (torn from its footing), and a gold plinth band.
	_cap(s, section, 0.002, Vector3.BACK, shade.darkened(0.45), MeshKit.PAT_MARBLE, 0.0)
	_band(s, section, center, 0.0, 1.6, gold.darkened(0.2))
	# Gold bands along it.
	var z: float = BAND_SPACING
	while z < shaft - 2.0:
		_band(s, section, center, z, 0.7, gold)
		z += BAND_SPACING
	# Rows of lit windows on its top (+y) and its outer side; gold panels on the side the runner runs.
	var row: int = 0
	z = BAND_SPACING * 0.5
	while z < shaft - 3.0:
		if absf(fposmod(z, BAND_SPACING)) > 1.2 and absf(fposmod(z, BAND_SPACING) - BAND_SPACING) > 1.2:
			for col: int in 3:
				var u: float = lerpf(-h + c + 1.0, h - c - 1.0, (float(col) + 0.5) / 3.0)
				if MeshKit.hash01(row, col, 811) < 0.62:
					# Its top (lying: the face up).
					s.rect(Vector3(u - 0.5, cy + h + 0.01, -z + 0.9), Vector3(1.0, 0, 0), Vector3(0, 0, -1.8), lit, 0.6)
				if MeshKit.hash01(row, col, 823) < 0.55:
					# Its outer side (away from the track).
					var px: float = (h + 0.01) * (1.0 if p_side > 0 else -1.0)
					var y0: float = cy + u - 0.5
					if p_side > 0:
						s.rect(Vector3(px, y0, -z + 0.9), Vector3(0, 0, -1.8), Vector3(0, 1.0, 0), lit, 0.5)
					else:
						s.rect(Vector3(px, y0, -z - 0.9), Vector3(0, 0, 1.8), Vector3(0, 1.0, 0), lit, 0.5)
		z += WINDOW_SPACING
		row += 1
	# The shaft's top end, under the crown.
	_cap(s, section, -shaft, Vector3.FORWARD, marble, MeshKit.PAT_MARBLE, 0.0)
	# The crown: a gold cap over its top end and a spire reaching on along the track.
	var cap := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(h * 0.9, CROWN * 0.35, h * 0.9)),
		Vector3(0.0, cy, -shaft))
	s.prism_xform(cap, 8, gold, 0.0, MeshKit.PAT_GOLD, true, 0.85)
	var spire := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(0.7, CROWN * 0.7, 0.7)),
		Vector3(0.0, cy, -shaft - CROWN * 0.3))
	s.prism_xform(spire, 6, gold, 0.0, MeshKit.PAT_GOLD, true, 0.9)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[key] = mesh
	return mesh


## A gold band round the section at z = -at, `width` long, flush with its faces (nothing stands proud of the
## side the runner runs).
static func _band(s: MeshLayer, section: Array[Vector2], center: Vector2, at: float, width: float, color: Color) -> void:
	for i: int in section.size():
		var a: Vector2 = section[i]
		var b: Vector2 = section[(i + 1) % section.size()]
		var out: Vector2 = ((a + b) * 0.5 - center).normalized()
		var lift := Vector3(out.x, out.y, 0.0) * 0.012
		_face(s, Vector3(a.x, a.y, -at) + lift, Vector3(b.x, b.y, -at) + lift, Vector3(b.x, b.y, -at - width) + lift,
			Vector3(a.x, a.y, -at - width) + lift, Vector3(out.x, out.y, 0.0), color, MeshKit.PAT_GOLD, 0.8)


## The section's end face at z = `z`, facing `outward`.
static func _cap(s: MeshLayer, section: Array[Vector2], z: float, outward: Vector3, color: Color, pattern: int,
		param: float) -> void:
	var c := Vector3.ZERO
	for p: Vector2 in section:
		c += Vector3(p.x, p.y, z)
	c /= float(section.size())
	for i: int in section.size():
		var a: Vector2 = section[i]
		var b: Vector2 = section[(i + 1) % section.size()]
		_face(s, c, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), c, outward, color, pattern, param)


## A four-cornered face toward `outward` (either winding).
static func _face(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color,
		pattern: int, param: float = 0.0) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		s.quad(a, d, c, b, color, 0.0, pattern, param)
	else:
		s.quad(a, b, c, d, color, 0.0, pattern, param)
