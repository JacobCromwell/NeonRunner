class_name TheHouseCeiling
extends Node3D
## The House's ceiling (GDD §10, phase 3: "one on a ceiling reached by an anti-grav pad, guarded by Barnacle
## Turrets"): for a set of 7 buttons whose special button is on a ceiling, a floating billboard over every
## lane (GDD §5: the Marketplace's ceilings include "floating advertisements"), an anti-grav pad under its
## start (BossProps.pad, the zone's pad), the 7 button on its underside (TheHouseButtons, kind "ceiling")
## and Barnacle Turrets hanging from it past the button (task C1's enemy, through
## BossEncounter.spawn_enemy, with C1's limits: at most two on a ceiling, never one lane wide, never over
## the pad's lane, at least after_pad_seconds past the pad (tight_after_pad_seconds in the only lane beside
## it) and spacing_seconds apart, before_end_seconds before its end; one fires at a time, at a rider on
## its own ceiling only).
## The plan (plan()): the pad where the runner reaches it, in a lane off the edges (so its lane always
## has a free lane beside it to dodge into: the turrets all hang in the lane on one side of the pad's, the
## other side's stays clear); the button ceiling_button_after past the pad in the pad's lane
## (ceiling_button_shift over), before the turrets' first bolts can come; the turrets; its end. Its
## route on the ceiling (route(): TheHouseRoute over the turrets' bodies, over the button) and the floor
## route to the pad are checked before a set is offered (TheHouseButtons.plan).
## The machine is taller than a ceiling (TheHouse squats it under duck_top while the billboard is over it):
## so the billboard comes down from the sky (billboard_drop_seconds) only once the machine has squatted,
## duck_seconds after the lever's pull, with its pad and turrets. The ceiling is a StaticBody on the hull
## layer (TrackBuilder.LAYER_HULL), as BossProps.ceiling's, so the player rides it like any (a ray on the
## hull layer over each lane) and drops back down where it ends; its look is the machine's own (one
## merged mesh per size, the kit's solid material; nothing glows in a hazard's colour but the orange end
## band every ceiling has). The billboard is pooled.

const TURRET_TUNING: BarnacleTurretTuning = preload("res://data/enemies/barnacle_turret.tres")
## The billboard's slab over its underside, and how high above its place it starts coming down from.
const SLAB: float = 0.9
const DROP_FROM: float = 26.0
## The orange band across its far end (every zone's ceiling end), and its lamps' spacing.
const END_BAND: float = 1.2
const LAMP_EVERY: float = 7.5
const END_ORANGE := Color(1.0, 0.25, 0.04)
## A landing after its end: the floor kept clear of the machine's strikes that long (s, at the run speed).
const LANDING_SECONDS: float = 0.8

var boss: TheHouse
var tuning: TheHouseTuning
var world: RunWorld
## The segment in play: {pad_lane, pad_at, start, end, button_lane, button_at, turret_lane, turret_ats,
## drop_at (clock), shown}, or {}.
var segment: Dictionary = {}
## Seconds of the fight's pattern (TheHouseAttacks keeps the same clock).
var clock: float = 0.0
## The turrets of the segment in play (tests).
var turrets: Array[Enemy] = []
## Segments shown this fight.
var count: int = 0

var _boards: Array[Dictionary] = []
var _board: Dictionary = {}
static var _meshes: Dictionary = {}


func setup(p_boss: TheHouse) -> void:
	boss = p_boss
	tuning = boss.tuning
	world = boss.world
	top_level = true
	transform = Transform3D.IDENTITY


## Makes its billboard before the fight (pooled), with the mesh of a ceiling at the run's speed.
func prewarm() -> void:
	if _boards.is_empty():
		_new_board()
	if boss.lane_count() >= 2 and world.tuning != null:
		var seg: Dictionary = plan(1, 0.0, 0.0, world.tuning.run_speed, 1)
		_mesh(world.geo, float(seg["end"]) - float(seg["start"]))
	# The turrets' script, numbers and look, loaded and built once now, not at the first one's spawn.
	if tuning.special_buttons.has("ceiling"):
		EnemyDirector.script_for("barnacle_turret")
		EnemyDirector.tuning_for("barnacle_turret")
		var look := BarnacleTurretModel.new()
		add_child(look)
		look.build(world.skin.enemy_variant if world.skin != null else &"", 0)
		look.queue_free()


## C1's limits and timings (data/enemies/barnacle_turret.tres).
static func turret_tuning() -> BarnacleTurretTuning:
	return TURRET_TUNING


## How many turrets guard a ceiling at this lane count (turrets_by_lanes; at most two, GDD §9.8).
func turret_count() -> int:
	return clampi(TheHouseTuning.per_lanes(tuning.turrets_by_lanes, boss.lane_count()), 0, 2)


## True if a pad may go in `lane`: never at an edge (with three lanes or more), so a lane beside it is
## always free of turrets.
func pad_lane_ok(lane: int) -> bool:
	var n: int = boss.lane_count()
	return n < 3 or (lane > 0 and lane < n - 1)


## The segment for a special button whose pad the runner reaches `reach` seconds from now at speed `v`,
## from `d0`, in `pad_lane`, the turrets on `side` of it (-1 or 1): its geometry (nothing shown yet).
func plan(pad_lane: int, d0: float, reach: float, v: float, side: int) -> Dictionary:
	var n: int = boss.lane_count()
	var bt: BarnacleTurretTuning = turret_tuning()
	var pad_at: float = d0 + v * reach
	var button_lane: int = clampi(pad_lane - side * tuning.ceiling_button_shift, 0, n - 1)
	var turret_lane: int = clampi(pad_lane + side, 0, n - 1)
	var only_lane: bool = n == 2 or pad_lane == 0 or pad_lane == n - 1
	var after: float = bt.tight_after_pad_seconds if only_lane else bt.after_pad_seconds
	var first: float = pad_at + v * maxf(after, tuning.ceiling_button_after + 0.6)
	var ats: Array[float] = []
	if turret_lane != pad_lane:
		for i: int in turret_count():
			ats.append(first + v * bt.spacing_seconds * i)
	var last: float = ats[-1] if not ats.is_empty() else pad_at + v * (tuning.ceiling_button_after + 0.6)
	var end: float = last + v * maxf(tuning.ceiling_end_after, bt.before_end_seconds)
	var lead_in: float = boss.arena.config.hull_lead_in if boss.arena != null and boss.arena.config != null else 3.0
	return {"pad_lane": pad_lane, "pad_at": pad_at, "start": pad_at - lead_in, "end": end,
		"button_lane": button_lane, "button_at": pad_at + v * tuning.ceiling_button_after,
		"turret_lane": turret_lane, "turret_ats": ats, "side": side}


## The turrets' bodies as route obstacles on the ceiling (with C1's body_reach either side).
func obstacles(seg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var half: float = BarnacleTurret.BODY_SIZE.z * 0.5 + turret_tuning().body_reach
	for at: float in seg.get("turret_ats", []):
		out.append(TheHouseRoute.obstacle(int(seg["turret_lane"]), at - half, at + half))
	return out


## A way along the ceiling for a rider who lands in the pad's lane: past the turrets' bodies and over the
## button, to the end (TheHouseRoute.find's result).
func route(seg: Dictionary) -> Dictionary:
	var r: TheHouseRoute = boss.route()
	var at: float = float(seg["pad_at"])
	return r.find(int(seg["pad_lane"]), at, at, float(seg["end"]), obstacles(seg),
		[{"lane": int(seg["button_lane"]), "at": float(seg["button_at"])}])


## Shows a planned segment: the billboard comes down duck_seconds from now (once the machine has squatted),
## with its pad and its turrets.
func start(seg: Dictionary) -> void:
	clear()
	segment = seg.duplicate()
	segment["drop_at"] = clock + tuning.duck_seconds / boss.pace()
	segment["shown"] = false
	segment["spawned"] = 0
	turrets.clear()
	count += 1
	boss.log_event(&"ceiling_planned", {"pad_lane": int(seg["pad_lane"]), "pad_at": float(seg["pad_at"]),
		"start": float(seg["start"]), "end": float(seg["end"]), "button_lane": int(seg["button_lane"]),
		"button_at": float(seg["button_at"]), "turret_lane": int(seg["turret_lane"]),
		"turret_ats": (seg["turret_ats"] as Array).duplicate()})


## True from a segment's plan until the runner is down past its end (LANDING_SECONDS on).
func active() -> bool:
	if segment.is_empty():
		return false
	return world.player.distance < landing_end() or world.player.surface == Player.Surface.CEILING


## Where the floor after it is the runner's again: its end and a landing.
func landing_end() -> float:
	if segment.is_empty():
		return -INF
	return float(segment["end"]) + LANDING_SECONDS * boss.speed()


## True if the billboard (shown or coming) spans any of track distances [from, to].
func over(from: float, to: float) -> bool:
	if segment.is_empty():
		return false
	return float(segment["start"]) <= to and float(segment["end"]) >= from


## Everything off now (a phase's end, the defeat): the billboard back in the pool. Its pad and turrets
## stay where they are (the props and the director retire them once passed).
func clear() -> void:
	if not _board.is_empty():
		_put_away(_board)
		_board = {}
	segment = {}
	turrets.clear()


func tick(delta: float) -> void:
	clock += delta
	if segment.is_empty():
		return
	# Its turrets, one a frame from the frame after the pull (each stays in its hatch until the runner is
	# near), then the billboard and its pad once the machine has squatted.
	var ats: Array = segment["turret_ats"]
	if int(segment["spawned"]) < ats.size():
		var at: float = float(ats[int(segment["spawned"])])
		segment["spawned"] = int(segment["spawned"]) + 1
		var params := {"hull_start": float(segment["start"]), "hull_end": float(segment["end"]), "first_lane": 0,
			"last_lane": boss.lane_count() - 1}
		var e: Enemy = boss.spawn_enemy("barnacle_turret", at, int(segment["turret_lane"]), 0, params)
		if e != null:
			turrets.append(e)
	elif not bool(segment["shown"]) and clock >= float(segment["drop_at"]):
		_show()
	if not _board.is_empty():
		var k: float = clampf((clock - float(segment["drop_at"])) / maxf(tuning.billboard_drop_seconds, 0.05), 0.0, 1.0)
		var look: Node3D = _board["look"]
		look.position = Vector3(0.0, DROP_FROM * pow(1.0 - k, 3.0), 0.0)
	if world.player.distance > landing_end() + 20.0 and world.player.surface != Player.Surface.CEILING:
		clear()


func _show() -> void:
	segment["shown"] = true
	var seg: Dictionary = segment
	_board = _free_board()
	var section := CeilingSection.make(world.geo, world.tuning.ceiling_height, TrackBuilder.HULL_THICKNESS,
		float(seg["start"]), float(seg["end"]), Vector2i(0, boss.lane_count() - 1))
	var body: StaticBody3D = _board["body"]
	(_board["shape"] as BoxShape3D).size = section.size
	body.position = section.center
	body.collision_layer = TrackBuilder.LAYER_HULL
	var root: Node3D = _board["root"]
	root.position = Vector3(0.0, world.tuning.ceiling_height, TrackGeometry.world_z(float(seg["start"])))
	var look: MeshInstance3D = _board["look"]
	look.mesh = _mesh(world.geo, float(seg["end"]) - float(seg["start"]))
	look.position = Vector3(0.0, DROP_FROM, 0.0)
	root.visible = true
	boss.props.pad(int(seg["pad_lane"]), float(seg["pad_at"]))
	boss.sound(&"house_billboard", world.lane_point(int(seg["pad_lane"]), float(seg["pad_at"]), 8.0))
	boss.log_event(&"ceiling_shown", {"start": float(seg["start"]), "end": float(seg["end"]),
		"turrets": turrets.size()})


# --- The billboard -------------------------------------------------------------------------------------

func _free_board() -> Dictionary:
	for b: Dictionary in _boards:
		if not b["used"]:
			b["used"] = true
			return b
	var b: Dictionary = _new_board()
	b["used"] = true
	return b


func _new_board() -> Dictionary:
	var root := Node3D.new()
	root.name = "Billboard"
	root.visible = false
	add_child(root)
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	var look := MeshInstance3D.new()
	look.name = "Look"
	look.material_override = TheHouseModel.solid_material(world.skin)
	look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(look)
	var b := {"root": root, "body": body, "shape": box, "look": look, "used": false}
	_boards.append(b)
	return b


func _put_away(b: Dictionary) -> void:
	b["used"] = false
	(b["root"] as Node3D).visible = false
	(b["body"] as StaticBody3D).collision_layer = 0


## The billboard's mesh, `length` long over the street's lanes (cached per size): local space has its
## underside at y = 0, its near end at z = 0 and its far end at z = -length.
static func _mesh(geo: TrackGeometry, length: float) -> ArrayMesh:
	var hw: float = geo.half_width() + geo.wall_margin * 0.6
	var key: String = "%.2f_%.2f_%d_%.2f" % [hw, length, geo.lane_count, geo.lane_width]
	if _meshes.has(key):
		return _meshes[key]
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(TheHouseModel.solid_material())
	var zf: float = -length
	# The underside: one plated surface across the lanes (no gaps between lanes, GDD §3), a faint seam
	# between each pair of lanes with flush warm lamps along it, and the orange end band.
	var z0: float = zf + END_BAND
	m.rect(Vector3(-hw, 0.0, z0), Vector3(hw * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -z0), Color(0.8, 0.77, 0.72), 0.0,
		MeshKit.PAT_HULL)
	for lane: int in range(1, geo.lane_count):
		var x: float = geo.lane_x(lane) - geo.lane_width * 0.5
		m.box(Vector3(x, -0.006, z0 * 0.5), Vector3(0.06, 0.012, -z0), Color(0.5, 0.47, 0.44), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		var z: float = -4.0
		while z > z0 + 2.0:
			m.box(Vector3(x, -0.02, z), Vector3(0.26, 0.04, 0.26), Color(1.0, 0.92, 0.75), 0.75, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			z -= LAMP_EVERY
	m.rect(Vector3(-hw, 0.0, zf), Vector3(hw * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, END_BAND), END_ORANGE, 0.33)
	# The slab: purple sides and top, a gold trim, white bulbs along its edges, hover pods on top.
	m.box_between(Vector3(-hw, 0.0, zf), Vector3(hw, SLAB, 0.0), TheHouseModel.PURPLE, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	m.box_between(Vector3(-hw - 0.05, SLAB - 0.12, zf - 0.05), Vector3(hw + 0.05, SLAB, 0.05), TheHouseModel.GOLD, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY & ~MeshKit.FACE_PY)
	var x_bulb: float = -hw + 0.4
	while x_bulb < hw - 0.2:
		m.box(Vector3(x_bulb, SLAB * 0.45, 0.04), Vector3(0.2, 0.2, 0.08), Color(1.0, 0.95, 0.85), 0.9)
		x_bulb += 0.8
	var z_bulb: float = -0.8
	while z_bulb > zf + 0.6:
		for sx: float in [-1.0, 1.0]:
			m.box(Vector3(sx * (hw + 0.04), SLAB * 0.45, z_bulb), Vector3(0.08, 0.2, 0.2), Color(1.0, 0.95, 0.85), 0.9)
		z_bulb -= 1.6
	# Its sign: the reels' 7 on an ivory panel over the near end, framed in gold.
	var sign_w: float = minf(hw * 1.2, 6.0)
	m.box_between(Vector3(-sign_w * 0.5 - 0.15, SLAB, -0.6), Vector3(sign_w * 0.5 + 0.15, SLAB + 2.5, -0.2),
		TheHouseModel.GOLD)
	m.box_between(Vector3(-sign_w * 0.5, SLAB + 0.15, -0.21), Vector3(sign_w * 0.5, SLAB + 2.35, -0.15),
		TheHouseModel.IVORY, 0.25)
	var seven := Color(0.1, 0.27, 1.0)
	m.box_between(Vector3(-0.6, SLAB + 1.85, -0.16), Vector3(0.6, SLAB + 2.1, -0.12), seven, 0.5)
	m.prism_xform(Transform3D(Basis(Vector3.BACK, -0.42) * Basis.from_scale(Vector3(0.24, 1.5, 0.05)),
		Vector3(0.12, SLAB + 1.15, -0.14)), 4, seven, 0.5)
	var z_pod: float = -length * 0.2
	while z_pod > zf + 2.0:
		for sx: float in [-1.0, 1.0]:
			m.prism(Vector3(sx * hw * 0.6, SLAB, z_pod), 0.7, 0.5, 8, TheHouseModel.GUNMETAL)
		z_pod -= maxf(length * 0.3, 8.0)
	var mesh: ArrayMesh = batch.to_mesh()
	if _meshes.size() > 16:
		_meshes.clear()
	_meshes[key] = mesh
	return mesh
