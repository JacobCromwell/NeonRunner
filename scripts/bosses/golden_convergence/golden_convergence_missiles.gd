class_name GoldenConvergenceMissiles
extends BossPart
## The Missile Barrage's missiles, marks and fire (GDD §10: "missiles climb high with a launch roar, and red
## target marks spread across the floor ... The missiles cover the whole floor, every lane, and leave a fiery
## trail"; task E5d-b). GoldenConvergenceBarrage plans and times it; this part shows it and carries the fire,
## everything pooled and made with the fight:
## - the missiles (set_missile, hide_missiles): up to MAX of them, one MultiMesh of small bronze missiles and
##   one of the fiery trails behind them (additive, the hazards' red-orange);
## - the red target marks (set_mark, hide_marks): a red ring per mark that spreads in, its inside filling in as
##   the missiles dive (`fill`, 0-1), pulsing as BossProps' red lines do (steady with Reduced flashing): one
##   MultiMesh of rings, one of fills, in the red lines' see-through glowing red (golden_convergence_floor
##   .gdshader: blended, not added, so they read red on the white marble);
## - the fire (set_fire, fire_off): an enemy attack hitbox over each lane's stretch (fire_height high: a jump
##   only delays it), the outer lanes' kept clear of a wall runner's body lying across the wall's foot, so the
##   wall is safe at every height; flames over every lane (golden_convergence_barrage.gdshader: additive, their
##   flicker steady with Reduced flashing, lifted on the Compatibility renderer) on a burning floor laid red-hot
##   over each lane (golden_convergence_floor.gdshader, blended like the marks);
##   `hit` reports each touch;
## - burst(at): a missile's blast where it lands: one of the game's shared yellow-and-red fireballs (RunEffects.fireball;
##   GDD §11, the owner, October 8, 2026: every explosion is one; the H merge), quick, smokeless and held in, softened
##   by Reduced flashing as every one is, and a red-orange spark burst (none with Reduced flashing).
## A part of the boss that's no target and no kill of its own.

## The fire touched the runner (`outcome`: a DamageRules.Outcome other than IGNORE).
signal hit(lane: int, outcome: int)

## Missiles (and marks) at most: 6 lanes × 10 marks.
const MAX: int = 60
## Lanes the fire covers at most.
const LANES_MAX: int = 6
## The fire in an outer lane stops this far short of a wall runner's body (Player: a wall runner lies across the
## wall's foot, out from its face by the hurtbox's height).
const WALL_CLEAR: float = 0.06
## Flames: one about every FLAME_STEP metres of each lane's stretch.
const FLAME_STEP: float = 1.3
const FLAMES_MAX: int = 320
const SHADER: String = "res://scripts/bosses/golden_convergence/golden_convergence_barrage.gdshader"
const FLOOR_SHADER: String = "res://scripts/bosses/golden_convergence/golden_convergence_floor.gdshader"
## The missiles' body (bronze, never glowing) and size.
const BODY := Color(0.42, 0.3, 0.18)
const NOSE := Color(0.72, 0.56, 0.32)
const MISSILE_LENGTH: float = 3.4
const MISSILE_RADIUS: float = 0.42
## A trail's length behind its missile.
const TRAIL: float = 9.0
## A landing missile's blast (burst): a shared fireball this big (metres in radius), this many times as quick as a free
## one and held in to this share of its spread, as the Floating Head's and The House's bombs are, gone soon after the
## fire floor lights. DESIGN-TBD (the H merge; docs/OPEN_QUESTIONS.md item 674).
const BLAST_FIRE_SIZE: float = 2.0
const BLAST_FIRE_PACE: float = 1.6
const BLAST_FIRE_SPREAD: float = 0.6

var tuning: GoldenConvergenceTuning
## The fire per lane: {hazard, floor: MeshInstance3D, on, lane, from, to}.
var lanes: Array[Dictionary] = []
## Touches reported (tests): {lane, outcome, runner, h, surface, t}.
var hits: Array[Dictionary] = []
## The fire burning (its hitboxes live) and how it shows (0 out, 1 full: the flames die down after it).
var burning: bool = false
var flame_level: float = 0.0

var _missiles: MultiMeshInstance3D
var _trails: MultiMeshInstance3D
var _rings: MultiMeshInstance3D
var _fills: MultiMeshInstance3D
var _flames: MultiMeshInstance3D
var _flame_base: Array[Transform3D] = []
var _floor_mat: ShaderMaterial
var _flame_mat: ShaderMaterial
## Marks: {pos: Vector3, radius, shown (0-1), fill, t}.
var _marks: Array[Dictionary] = []
var _t: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as GoldenConvergenceTuning
	if tuning == null:
		tuning = GoldenConvergenceTuning.new()
	display_name = "the missiles' fire"
	is_obstacle = true
	immune_to_weapons = true
	var shader := load(SHADER) as Shader
	_missiles = _multimesh("Missiles", _missile_mesh(), null, MAX)
	_trails = _multimesh("Trails", _cross_quad(), _shader_mat(shader, 2), MAX)
	var floor_shader := load(FLOOR_SHADER) as Shader
	_rings = _multimesh("Rings", _flat_quad(), _shader_mat(floor_shader, 3), MAX)
	_fills = _multimesh("Fills", _flat_quad(), _shader_mat(floor_shader, 4), MAX)
	_flame_mat = _shader_mat(shader, 0)
	_flames = _multimesh("Flames", _cross_quad(), _flame_mat, FLAMES_MAX)
	_floor_mat = _shader_mat(floor_shader, 1)
	for i: int in MAX:
		_marks.append({"pos": Vector3.ZERO, "radius": 1.0, "shown": 0.0, "fill": 0.0, "t": 0.0, "on": false})
	for k: int in LANES_MAX:
		var holder := Node3D.new()
		holder.name = "Fire%d" % k
		holder.top_level = true
		add_child(holder)
		var hazard: Hazard = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, holder)
		hazard.hazard_name = "the missiles' fire"
		hazard.contacted.connect(_on_contacted.bind(k))
		var glow := MeshInstance3D.new()
		glow.name = "Burning"
		glow.mesh = _flat_quad()
		glow.material_override = _floor_mat
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.top_level = true
		add_child(glow)
		lanes.append({"hazard": hazard, "holder": holder, "floor": glow, "on": false, "lane": k, "from": 0.0, "to": 0.0,
			"x0": 0.0, "x1": 0.0})
	clear()


func _multimesh(node_name: String, mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if material != null:
		inst.material_override = material
	inst.top_level = true
	# Its instances spread over a long stretch of track: never culled while any of it is in view.
	inst.extra_cull_margin = 200.0
	add_child(inst)
	inst.global_transform = Transform3D.IDENTITY
	return inst


func _shader_mat(shader: Shader, shape: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"shape", shape)
	return m


## A small missile along -z (its nose forward), bronze with a gold nose and fins (the suit's metal, never
## glowing), in the court's solid material.
func _missile_mesh() -> Mesh:
	var skin := world.skin as GoldenSkin if world != null else null
	var material: Material = skin.solid_material() if skin != null else GoldenSkin.new().solid_material()
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var r: float = MISSILE_RADIUS
	var l: float = MISSILE_LENGTH
	s.prism_xform(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(r, l * 0.75, r)),
		Vector3(0.0, 0.0, l * 0.5)), 6, BODY, 0.0, MeshKit.PAT_GOLD, true, 0.5)
	s.prism_xform(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(r * 0.9, l * 0.25, r * 0.9)),
		Vector3(0.0, 0.0, -l * 0.25)), 6, NOSE, 0.0, MeshKit.PAT_GOLD, true, 0.85)
	for k: int in 4:
		var a: float = TAU * float(k) / 4.0 + PI * 0.25
		s.box_xform(Transform3D(Basis(Vector3.BACK, a) * Basis.from_scale(Vector3(r * 2.6, 0.06, 0.7)),
			Vector3(0.0, 0.0, l * 0.42)), NOSE, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.85)
	return batch.to_mesh()


## A unit quad lying flat (x and z from -0.5 to 0.5, facing up), UV over it.
func _flat_quad() -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	return plane


## Two unit quads crossed along y (one facing z, one facing x), from y = 0 to 1, UV.y up: flames and trails
## seen from any side.
func _cross_quad() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: int in 2:
		var u: Vector3 = Vector3.RIGHT if axis == 0 else Vector3.BACK
		var corners: Array[Vector3] = [-u * 0.5, u * 0.5, u * 0.5 + Vector3.UP, -u * 0.5 + Vector3.UP]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])
	return st.commit()


# --- Missiles ----------------------------------------------------------------------------------------------

## How many missiles show (the first `count` of the pool).
func show_missiles(count: int) -> void:
	_missiles.multimesh.visible_instance_count = clampi(count, 0, MAX)
	_trails.multimesh.visible_instance_count = clampi(count, 0, MAX)


func hide_missiles() -> void:
	show_missiles(0)


## Missile `i` at `pos` (world space) flying along `dir`, its trail behind it (`trail` 0-1 of its length).
func set_missile(i: int, pos: Vector3, dir: Vector3, trail: float = 1.0) -> void:
	if i < 0 or i >= MAX:
		return
	var forward: Vector3 = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var up: Vector3 = Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var basis := Basis.looking_at(forward, up)
	_missiles.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	# The trail: a crossed quad from the missile's tail back along where it came from.
	var length: float = TRAIL * clampf(trail, 0.0, 1.0)
	var tail: Vector3 = pos - forward * (MISSILE_LENGTH * 0.5)
	var along := Basis(basis.x, -forward, basis.y)
	if length < 0.05:
		_trails.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -300.0, 0.0)))
	else:
		_trails.multimesh.set_instance_transform(i, Transform3D(along * Basis.from_scale(Vector3(1.1, length, 1.1)), tail))


## A missile's blast where it lands: a shared fireball (quick, smokeless, held in) and a red-orange spark burst (none
## with Reduced flashing, which softens the fireball).
func burst(at: Vector3) -> void:
	if world == null or world.effects == null:
		return
	world.effects.fireball(at + Vector3(0.0, 0.5, 0.0), BLAST_FIRE_SIZE, false, BLAST_FIRE_PACE, BLAST_FIRE_SPREAD)
	if not Settings.flashing_reduced:
		world.effects.burst(at + Vector3(0.0, 0.5, 0.0), Color(1.0, 0.42, 0.12), 14, 0.9)


# --- Marks ---------------------------------------------------------------------------------------------------

## Mark `i` at world point `pos` on the floor, `radius` metres, `shown` (0-1: spreading in) and `fill` (0-1).
func set_mark(i: int, pos: Vector3, radius: float, shown: float, fill: float) -> void:
	if i < 0 or i >= MAX:
		return
	var m: Dictionary = _marks[i]
	if not bool(m["on"]):
		m["t"] = 0.0
	m["on"] = true
	m["pos"] = pos
	m["radius"] = radius
	m["shown"] = clampf(shown, 0.0, 1.0)
	m["fill"] = clampf(fill, 0.0, 1.0)


## How many marks show (the first `count`).
func show_marks(count: int) -> void:
	_rings.multimesh.visible_instance_count = clampi(count, 0, MAX)
	_fills.multimesh.visible_instance_count = clampi(count, 0, MAX)
	for i: int in range(count, MAX):
		_marks[i]["on"] = false


func hide_marks() -> void:
	show_marks(0)


func marks_shown() -> int:
	return _rings.multimesh.visible_instance_count


## Mark `i`'s ring as drawn now: its radius (spreading in, pulsing) and its fill (tests).
func mark_ring(i: int) -> Vector2:
	var m: Dictionary = _marks[i]
	return Vector2(float(m.get("r", 0.0)), float(m["fill"]))


func _place_marks(delta: float) -> void:
	var count: int = _rings.multimesh.visible_instance_count
	for i: int in count:
		var m: Dictionary = _marks[i]
		m["t"] = float(m["t"]) + delta
		var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.08 * sin(float(m["t"]) * 24.0)
		var r: float = float(m["radius"]) * float(m["shown"]) * beat
		m["r"] = r
		var pos: Vector3 = m["pos"]
		_rings.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r * 2.0, 1.0, r * 2.0)), pos + Vector3(0.0, 0.04, 0.0)))
		var f: float = float(m["radius"]) * 0.82 * float(m["fill"]) * float(m["shown"])
		_fills.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(f * 2.0, 1.0, f * 2.0)), pos + Vector3(0.0, 0.035, 0.0)))


# --- The fire ------------------------------------------------------------------------------------------------

## The fire over every lane from track distance `from` to `to`: its hitboxes live from now (fire_off ends them),
## its flames up. Returns the lanes' boxes as {lane, x0, x1} (world x).
func set_fire(from: float, to: float) -> Array[Dictionary]:
	var geo: TrackGeometry = world.geo
	var n: int = mini(geo.lane_count, LANES_MAX)
	var out: Array[Dictionary] = []
	var reach: float = world.tuning.hurtbox_size.y + WALL_CLEAR
	var height: float = tuning.fire_height
	for k: int in lanes.size():
		var rig: Dictionary = lanes[k]
		var hazard: Hazard = rig["hazard"]
		if k >= n:
			hazard.set_enabled(false)
			(rig["floor"] as Node3D).visible = false
			continue
		var x0: float = geo.lane_x(k) - geo.lane_width * 0.5
		var x1: float = geo.lane_x(k) + geo.lane_width * 0.5
		# The outer lanes' fire stops short of a wall runner's body (the wall is safe at every height).
		if k == 0:
			x0 = -geo.wall_x() + reach
		if k == n - 1:
			x1 = geo.wall_x() - reach
		var size := Vector3(x1 - x0, height, to - from)
		GoldenConvergenceFire._resize(hazard, size)
		hazard.position = Vector3.ZERO
		(rig["holder"] as Node3D).global_position = Vector3((x0 + x1) * 0.5, height * 0.5, TrackGeometry.world_z((from + to) * 0.5))
		hazard.set_enabled(true)
		# The burning floor over just what burns: the lanes' floor edge to edge (no unburnt strip between two
		# lanes), the outer lanes' out to their fire's edge short of the wall.
		var glow: MeshInstance3D = rig["floor"]
		glow.global_transform = Transform3D(Basis.from_scale(Vector3(x1 - x0, 1.0, to - from)),
			Vector3((x0 + x1) * 0.5, 0.045, TrackGeometry.world_z((from + to) * 0.5)))
		glow.visible = true
		rig["on"] = true
		rig["from"] = from
		rig["to"] = to
		rig["x0"] = x0
		rig["x1"] = x1
		out.append({"lane": k, "x0": x0, "x1": x1})
	_lay_flames(from, to, n)
	burning = true
	flame_level = 1.0
	_set_level(1.0)
	return out


## The fire's hitboxes off (it has burnt its time); its flames die down on their own.
func fire_off() -> void:
	burning = false
	for rig: Dictionary in lanes:
		(rig["hazard"] as Hazard).set_enabled(false)
		(rig["holder"] as Node3D).global_position = Vector3(0.0, -300.0, 0.0)
		rig["on"] = false


## True while any of the fire's hitboxes is live.
func live() -> bool:
	for rig: Dictionary in lanes:
		if (rig["hazard"] as Hazard).is_active():
			return true
	return false


## Every hitbox of the fire (tests).
func hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for rig: Dictionary in lanes:
		out.append(rig["hazard"])
	return out


## Flames over the stretch in every lane: each its own height, width and sway, seeded by where it stands (the
## same every attempt).
func _lay_flames(from: float, to: float, n: int) -> void:
	var geo: TrackGeometry = world.geo
	var mm: MultiMesh = _flames.multimesh
	_flame_base.clear()
	var count: int = 0
	for k: int in n:
		var d: float = from + FLAME_STEP * 0.5 * (1.0 + float(k % 2) * 0.5)
		while d < to - 0.2 and count < FLAMES_MAX:
			var h01: float = MeshKit.hash01(k, roundi(d * 10.0), 911)
			var x: float = geo.lane_x(k) + (MeshKit.hash01(k, roundi(d * 10.0), 913) - 0.5) * geo.lane_width * 0.6
			var height: float = tuning.fire_height * lerpf(0.85, 1.25, h01)
			var width: float = lerpf(0.9, 1.4, MeshKit.hash01(k, roundi(d * 10.0), 917))
			var base := Transform3D(Basis(Vector3.UP, h01 * PI) * Basis.from_scale(Vector3(width, height, width)),
				Vector3(x, 0.02, TrackGeometry.world_z(d)))
			_flame_base.append(base)
			mm.set_instance_transform(count, base)
			count += 1
			d += FLAME_STEP
	mm.visible_instance_count = count


## How high the flames stand (0 out, 1 full).
func _set_level(level: float) -> void:
	flame_level = clampf(level, 0.0, 1.0)
	_flame_mat.set_shader_parameter(&"level", flame_level)
	_floor_mat.set_shader_parameter(&"level", flame_level)
	var mm: MultiMesh = _flames.multimesh
	if flame_level <= 0.0:
		mm.visible_instance_count = 0
		for rig: Dictionary in lanes:
			(rig["floor"] as Node3D).visible = false
		return
	for i: int in mini(_flame_base.size(), mm.visible_instance_count):
		var base: Transform3D = _flame_base[i]
		mm.set_instance_transform(i, Transform3D(base.basis * Basis.from_scale(Vector3(1.0, flame_level, 1.0)), base.origin))


func _tick(delta: float) -> void:
	_t += delta
	_place_marks(delta)
	if not burning and flame_level > 0.0:
		# The flames die down once the fire has burnt its time (visual only).
		_set_level(flame_level - delta / 0.35)


## Everything off: no missile, no mark, no fire.
func clear() -> void:
	hide_missiles()
	hide_marks()
	fire_off()
	_set_level(0.0)


func _on_contacted(outcome: int, lane: int) -> void:
	if outcome == DamageRules.Outcome.IGNORE:
		return
	var p: Player = world.player
	var entry := {"lane": lane, "outcome": outcome, "runner": p.distance, "h": p.h, "surface": p.surface,
		"t": encounter.fight_time() if encounter != null else 0.0}
	hits.append(entry)
	hit.emit(lane, outcome)


## Never a target.
func targetable() -> bool:
	return false


## The fight is won: the fire goes out.
func _on_defeated(_cause: StringName) -> void:
	clear()
