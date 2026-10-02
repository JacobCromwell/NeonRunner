class_name HostileTakeoverStrafes
extends BossPart
## The gunship's strafes (GDD §10, phase 2: "the gunship strafes the lanes (a warning line and a rising
## whine)"): what hits. HostileTakeoverContract plans each strafe and shows its warning (BossProps'
## red lane lines, the whine); then its guns rake each struck lane from the far end of its line back
## toward the runner and past them (set_front), and this part carries, per struck lane, the rake: an enemy
## attack hitbox across most of the lane, from the roof to above a jump's reach (so a jump doesn't dodge
## it: leaving the lane does; the walls are safe), the burning streak of its impacts on the roof, and the
## tracer beam from the gunship's guns down to it, in the enemy attacks' red. Nothing hits anywhere but in
## a warned lane, and only once its warning is over (the contract's timing).
## Pooled: a rig per lane it may strike, built once with the fight. A part of the boss that's no target
## and no kill of its own (is_obstacle). The armor and the shield block a rake (an enemy attack).

## Rigs: the most lanes a strafe strikes (HostileTakeoverTuning.strafe_lanes' range).
const RIGS: int = 3
## The rake's hitbox: a share of the lane's width, its height (over a jump's reach: a jump doesn't dodge
## it) and its depth along the lane (longer than it moves in a frame, so it can't step past a runner).
const WIDTH_SHARE: float = 0.7
const HEIGHT: float = 3.2
const DEPTH: float = 3.0
## Its burning streak behind the front (metres along the track), and the colours.
const STREAK: float = 7.0
const RAKE_COLOR := Color(1.0, 0.16, 0.08)
const TRACER_COLOR := Color(1.0, 0.42, 0.16)

var tuning: HostileTakeoverTuning
## {node, hazard, streak, beam, lane, on}
var rigs: Array[Dictionary] = []
var _t: float = 0.0
var _streak_mat: StandardMaterial3D
var _beam_mat: StandardMaterial3D


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as HostileTakeoverTuning
	if tuning == null:
		tuning = HostileTakeoverTuning.new()
	display_name = "the gunship's guns"
	is_obstacle = true
	immune_to_weapons = true
	_streak_mat = GreyboxMaterials.glow(RAKE_COLOR, 3.2, 0.95)
	_beam_mat = GreyboxMaterials.glow(TRACER_COLOR, 3.6, 0.8)
	var lane_w: float = world.geo.lane_width
	for i: int in RIGS:
		var node := Node3D.new()
		node.name = "Rake%d" % i
		node.top_level = true
		add_child(node)
		var hazard: Hazard = add_hitbox(&"attack", Vector3(lane_w * WIDTH_SHARE, HEIGHT, DEPTH), Vector3(0.0, HEIGHT * 0.5, 0.0),
			true, node)
		hazard.hazard_name = "the gunship's guns"
		var streak := MeshInstance3D.new()
		streak.name = "Streak"
		streak.mesh = GreyboxMaterials.unit_box()
		streak.material_override = _streak_mat
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The burning trail on the roof, from the front back along the line it has raked (ahead, -z).
		streak.transform = Transform3D(Basis.from_scale(Vector3(lane_w * 0.32, 0.06, STREAK)), Vector3(0.0, 0.04, -STREAK * 0.5))
		node.add_child(streak)
		var beam := MeshInstance3D.new()
		beam.name = "Beam"
		beam.mesh = GreyboxMaterials.unit_box()
		beam.material_override = _beam_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.top_level = true
		add_child(beam)
		rigs.append({"node": node, "hazard": hazard, "streak": streak, "beam": beam, "lane": -1, "on": false})
	stop()


## Starts raking `lanes` (each rig takes one).
func start(lanes: Array[int]) -> void:
	stop()
	for i: int in mini(lanes.size(), rigs.size()):
		var rig: Dictionary = rigs[i]
		rig["lane"] = lanes[i]
		rig["on"] = true
		(rig["node"] as Node3D).visible = true
		(rig["beam"] as Node3D).visible = true
		(rig["hazard"] as Hazard).set_enabled(true)


## Puts the rakes at track distance `front` in their lanes, the tracers from `gun` (world space).
func set_front(front: float, gun: Vector3) -> void:
	for rig: Dictionary in rigs:
		if not rig["on"]:
			continue
		var at := Vector3(world.geo.lane_x(int(rig["lane"])), 0.0, TrackGeometry.world_z(front))
		(rig["node"] as Node3D).global_position = at
		var beam: MeshInstance3D = rig["beam"]
		var to: Vector3 = at + Vector3(0.0, 0.3, 0.0)
		var along: Vector3 = to - gun
		var length: float = along.length()
		if length < 0.1:
			beam.visible = false
			continue
		# A flicker along the tracer (steady with Reduced flashing: the beam just stays on).
		var width: float = 0.16 if Settings.flashing_reduced else 0.12 + 0.06 * absf(sin(_t * 47.0 + float(rig["lane"])))
		var basis := Basis.looking_at(along / length, Vector3.UP)
		beam.global_transform = Transform3D(basis * Basis.from_scale(Vector3(width, width, length)), (gun + to) * 0.5)
		beam.visible = true


## Stops every rake (their hitboxes off, nothing shown).
func stop() -> void:
	for rig: Dictionary in rigs:
		rig["on"] = false
		rig["lane"] = -1
		(rig["node"] as Node3D).visible = false
		(rig["node"] as Node3D).global_position = Vector3(0.0, -200.0, 0.0)
		(rig["beam"] as Node3D).visible = false
		(rig["hazard"] as Hazard).set_enabled(false)


func raking() -> bool:
	for rig: Dictionary in rigs:
		if rig["on"]:
			return true
	return false


## The lanes raking now.
func lanes_on() -> Array[int]:
	var out: Array[int] = []
	for rig: Dictionary in rigs:
		if rig["on"]:
			out.append(int(rig["lane"]))
	return out


func _tick(delta: float) -> void:
	_t += delta


## Never a target.
func targetable() -> bool:
	return false


## The fight is won: the rakes stop.
func _on_defeated(_cause: StringName) -> void:
	stop()
