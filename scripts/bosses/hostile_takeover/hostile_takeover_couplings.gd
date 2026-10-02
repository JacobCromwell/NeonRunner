class_name HostileTakeoverCouplings
extends BossPart
## The carriage couplings (GDD §10, phase 1: "each carriage coupling glows red and sits in one lane above
## the gap between carriages. The player stomps it by landing on it while jumping the gap, and the
## carriages behind break away and tumble off the track"): one coupling over each gap of the train, in the
## lane the encounter gives it (HostileTakeoverBoard), drawn by a small pool of rigs moved from gap to gap
## as the runner goes (nothing is made during the fight: every mesh and material is built here).
## A rig: the coupling's two halves (each carriage's coupler arm and half of the knuckle in the middle of
## the gap), its dome on top (dark, or glowing the weak points' red while it's live, pulsing unless
## Reduced flashing is on), a red halo over it while it's live, the take-off cue on the roof in its lane
## while it's live (the zone's green ramp chevrons where a jump comes down on it), and its weak point.
## What counts as landing on it (GDD §10; HostileTakeoverTuning, DESIGN-TBD): a box over its lane
## (stomp_width_share of a lane's width) from stomp_before short of the gap to stomp_after past it, over
## the roofs (at the run's pace), from under the roofs' plane up to stomp_top over it: a jump that comes
## down anywhere over the gap in its lane stomps it (a stomp from above: DamageRules), and its bounce
## (GameRules.stomp_bounce_velocity) carries the runner on over the rest of the gap
## (HostileTakeoverTrain.bounce_clears). A runner who drops off the roof's edge without jumping is never
## high enough over its top (the stomp tolerance), so falling isn't a stomp; touching it any other way is
## harmless.
## A part of the boss (shares its health: a stomp is the phase's big hit through BossPart's weak points),
## immune to weapons (they chip the gunship instead), and no kill of its own (is_obstacle).

## Rigs in the pool: enough for every gap from just behind the runner to the end of the built track.
const POOL: int = 6
## The stomp box's bottom, under the roofs' plane (a runner falling in the gap past it is harmless).
const BOX_BOTTOM: float = -0.6
## A broken coupling's rear half drops away over this long, then hides.
const BREAK_SECONDS: float = 1.6
## The dome's pulse while it's live (the weak points' language), off with Reduced flashing.
const PULSE_HZ: float = 1.4
const PULSE_DEPTH: float = 0.3
## The cue keeps this share of the take-off window off each of its ends (it marks the middle of it).
const CUE_TRIM: float = 0.12

var tuning: HostileTakeoverTuning
var train: HostileTakeoverTrain
## The pool: {node, front, rear, dome, halo, cue, hazard, gap (-1: free), lane, live, broken, t}.
var rigs: Array[Dictionary] = []
## The stomp box (its size and its offset from the rig's origin) and the take-off window: how far
## before the gap's near edge a jump that comes down on the box starts (Vector2(latest, earliest)).
var box_size := Vector3.ONE
var box_offset := Vector3.ZERO
var takeoff := Vector2.ZERO

var _live_mat: ShaderMaterial
var _live_dome: ArrayMesh
var _dark_dome: ArrayMesh
var _pulse: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as HostileTakeoverTuning
	train = params.get("train") as HostileTakeoverTrain
	if tuning == null:
		tuning = HostileTakeoverTuning.new()
	if train == null:
		train = HostileTakeoverTrain.plan(world.tuning, 1000.0, tuning)
	is_obstacle = true
	immune_to_weapons = true
	var lane_w: float = world.geo.lane_width
	var pace: float = world.tuning.pace()
	var before: float = tuning.stomp_before * pace
	var after: float = tuning.stomp_after * pace
	var gap: float = train.gap
	box_size = Vector3(lane_w * tuning.stomp_width_share, tuning.stomp_top - BOX_BOTTOM, gap + before + after)
	box_offset = Vector3(0.0, (tuning.stomp_top + BOX_BOTTOM) * 0.5, (before - after) * 0.5)
	var lead: float = descent_lead(world.tuning, tuning.stomp_top)
	takeoff = Vector2(lead - gap - after, lead + before)
	_live_mat = _kit_material(1.0)
	var skin: ZoneSkin = world.skin
	var front_mesh: ArrayMesh = HostileTakeoverModel.coupling_half(gap, lane_w, false, skin)
	var rear_mesh: ArrayMesh = HostileTakeoverModel.coupling_half(gap, lane_w, true, skin)
	_live_dome = HostileTakeoverModel.coupling_dome()
	_dark_dome = HostileTakeoverModel.coupling_dome_dark(skin)
	var halo_mesh: ArrayMesh = HostileTakeoverModel.coupling_halo(skin)
	var trim: float = (takeoff.y - takeoff.x) * CUE_TRIM
	var cue_color: Color = skin.get("ramp_color") if skin != null and skin.get("ramp_color") is Color else Color(0.3, 1.0, 0.35)
	var cue_mesh: ArrayMesh = HostileTakeoverModel.coupling_cue(gap, takeoff.x + trim, takeoff.y - trim, lane_w * 0.46, cue_color, skin)
	for i: int in POOL:
		var node := Node3D.new()
		node.name = "Coupling%d" % i
		node.top_level = true
		add_child(node)
		var rear := Node3D.new()
		rear.name = "Rear"
		node.add_child(rear)
		var rig := {"node": node, "rear": rear, "gap": -1, "lane": 0, "live": false, "broken": false, "t": 0.0}
		rig["front"] = MeshBatch.add_instance(node, front_mesh, "Front")
		MeshBatch.add_instance(rear, rear_mesh, "Half")
		var dome: MeshInstance3D = MeshBatch.add_instance(node, _dark_dome, "Dome")
		rig["dome"] = dome
		var halo: MeshInstance3D = MeshBatch.add_instance(node, halo_mesh, "Halo", Vector3(0.0, 0.25, 0.7))
		halo.visible = false
		rig["halo"] = halo
		var cue: MeshInstance3D = MeshBatch.add_instance(node, cue_mesh, "Cue")
		cue.visible = false
		rig["cue"] = cue
		var hazard: Hazard = add_weak_point(box_size, box_offset, node)
		hazard.hazard_name = "the coupling"
		rig["hazard"] = hazard
		node.visible = false
		rigs.append(rig)
	set_weak_points_enabled(false)


## How far along the track a jump from the roofs carries a runner before their feet come back down to
## height `top` (the jump's rise and part of its fall, at the run speed): where to take off for a
## landing on something `top` high.
static func descent_lead(movement: MovementTuning, top: float) -> float:
	var g_down: float = movement.gravity() * movement.fall_gravity_multiplier
	var t_down: float = sqrt(2.0 * maxf(movement.jump_height - top, 0.0) / g_down)
	return movement.run_speed * (movement.jump_time_to_apex + t_down)


func _kit_material(state_glow: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MeshKit.shader("kit_solid.gdshader")
	m.set_shader_parameter(&"glow_scale", 4.0)
	m.set_shader_parameter(&"state_glow", state_glow)
	return m


## The rig over gap `k`, or {} if none is there.
func rig_for(k: int) -> Dictionary:
	for rig: Dictionary in rigs:
		if int(rig["gap"]) == k:
			return rig
	return {}


## The gap whose coupling `hazard` is (its weak point), or -1.
func gap_of(hazard: Hazard) -> int:
	for rig: Dictionary in rigs:
		if rig["hazard"] == hazard:
			return int(rig["gap"])
	return -1


## Puts a coupling over gap `k` in `lane` (taking a free rig, or the one furthest behind `behind`), unless
## one is there already. Returns its rig.
func place(k: int, lane: int, behind: float) -> Dictionary:
	var found: Dictionary = rig_for(k)
	if not found.is_empty():
		return found
	var pick: Dictionary = {}
	for rig: Dictionary in rigs:
		if int(rig["gap"]) < 0:
			pick = rig
			break
	if pick.is_empty():
		var oldest: int = 1 << 30
		for rig: Dictionary in rigs:
			if int(rig["gap"]) < oldest and train.gap_end(int(rig["gap"])) < behind:
				oldest = int(rig["gap"])
				pick = rig
	if pick.is_empty():
		return {}
	pick["gap"] = k
	pick["lane"] = lane
	pick["broken"] = false
	pick["t"] = 0.0
	var node: Node3D = pick["node"]
	var mid: float = train.gap_start(k) + train.gap * 0.5
	node.global_transform = Transform3D(Basis.IDENTITY, Vector3(world.geo.lane_x(lane), 0.0, TrackGeometry.world_z(mid)))
	(pick["rear"] as Node3D).transform = Transform3D.IDENTITY
	(pick["rear"] as Node3D).visible = true
	(pick["dome"] as MeshInstance3D).visible = true
	node.visible = true
	_set_live(pick, false)
	return pick


## Frees the rigs over gaps that ended more than `keep` metres behind `d`.
func release_before(d: float, keep: float) -> void:
	for rig: Dictionary in rigs:
		var k: int = int(rig["gap"])
		if k >= 0 and train.gap_end(k) < d - keep:
			_free(rig)


## Lights the coupling over gap `k` (live: glowing red, its cue on the roof, its weak point on while the
## boss can be hurt) or darkens it.
func set_live(k: int, live: bool) -> void:
	var rig: Dictionary = rig_for(k)
	if not rig.is_empty():
		_set_live(rig, live)


## True if the coupling over gap `k` is live (lit and not broken).
func is_live(k: int) -> bool:
	var rig: Dictionary = rig_for(k)
	return not rig.is_empty() and rig["live"] and not rig["broken"]


## Switches the live couplings' weak points on while the boss can be hurt (`on`), every other off.
func arm(on: bool) -> void:
	for rig: Dictionary in rigs:
		(rig["hazard"] as Hazard).set_enabled(on and rig["live"] and not rig["broken"] and int(rig["gap"]) >= 0)


## The coupling over gap `k` breaks (a stomp): its dome bursts, its cue and halo go out, and its rear
## half (with the carriage behind) drops away.
func break_open(k: int) -> void:
	var rig: Dictionary = rig_for(k)
	if rig.is_empty():
		return
	_set_live(rig, false)
	rig["broken"] = true
	rig["t"] = 0.0
	(rig["dome"] as MeshInstance3D).visible = false
	(rig["hazard"] as Hazard).set_enabled(false)


## Where the coupling over gap `k` is (its dome), in world space.
func dome_world(k: int) -> Vector3:
	var lane: int = int(rig_for(k).get("lane", 0))
	return Vector3(world.geo.lane_x(lane), 0.3, TrackGeometry.world_z(train.gap_start(k) + train.gap * 0.5))


## The track distances its stomp box spans over gap `k`.
func box_span(k: int) -> Vector2:
	var mid: float = train.gap_start(k) + train.gap * 0.5
	return Vector2(mid - box_offset.z - box_size.z * 0.5, mid - box_offset.z + box_size.z * 0.5)


func _tick(delta: float) -> void:
	_pulse += delta
	var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + PULSE_DEPTH * sin(_pulse * TAU * PULSE_HZ)
	_live_mat.set_shader_parameter(&"state_glow", beat)
	for rig: Dictionary in rigs:
		if not rig["broken"] or int(rig["gap"]) < 0:
			continue
		rig["t"] = float(rig["t"]) + delta
		var t: float = float(rig["t"])
		var rear: Node3D = rig["rear"]
		if t >= BREAK_SECONDS:
			rear.visible = false
			continue
		# It falls behind with the carriage it belongs to, drops and swings down.
		rear.transform = Transform3D(Basis.from_euler(Vector3(minf(t * t * 1.6, 1.2), 0.0, 0.0)),
			Vector3(0.0, -2.5 * t * t, 4.5 * t * t))


## Never a target, never retired with the fight on (a boss's part).
func targetable() -> bool:
	return false


func _set_live(rig: Dictionary, live: bool) -> void:
	rig["live"] = live and not rig["broken"]
	var on: bool = rig["live"]
	var dome: MeshInstance3D = rig["dome"]
	dome.mesh = _live_dome if on else _dark_dome
	dome.material_override = _live_mat if on else null
	(rig["halo"] as MeshInstance3D).visible = on
	(rig["cue"] as MeshInstance3D).visible = on
	if not on:
		(rig["hazard"] as Hazard).set_enabled(false)


func _free(rig: Dictionary) -> void:
	rig["gap"] = -1
	rig["live"] = false
	rig["broken"] = false
	(rig["hazard"] as Hazard).set_enabled(false)
	(rig["node"] as Node3D).visible = false
	(rig["node"] as Node3D).global_position = Vector3(0.0, -200.0, 0.0)
