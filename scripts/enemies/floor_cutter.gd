extends Enemy
## The floor cutter: a plain grey-box stand-in that runs a floor cut (task B4) so it can be reviewed
## before task C2's Buzz Overdrive (GDD §9.9) exists. Debug-only quick play (`--features=floor_cutter`);
## never in the campaign. It's the visible cause of its planned cut (LevelLayout.cuts; its entry stands
## at the cut's end, in its lane, floor_cutter_rules.gd), keyed to the player's distance like the cut
## (FloorCutPlan), so it does the same on every attempt and at every frame rate:
## - it waits at the cut's end, in view, until the player reaches the cut's warning point;
## - the warning (a placeholder, DESIGN-TBD: C2 brings the Buzz Overdrive's own): a red line down the
##   lane it's about to cut, pulsing (steady with Reduced flashing), and a rev (the hover truck's), while
##   its blade spins up;
## - it charges back along its lane toward and past the player at its cut's speed, its blade cutting the
##   floor behind it (FloorCut.advance_to: the floor ahead of it stays whole, behind it is a gap), sparks
##   flying (none with Reduced flashing);
## - past its cut's start it's off the screen behind the player, and gone.
## Its blade hurts on contact (an enemy attack: the armor and the shield block it, and then the floor
## under the player holds for GameRules.cut_hold_seconds, FloorCut.hold_under); its hitbox is narrow and
## centred on its lane, so it never reaches a wall runner or anyone in another lane. Weapons and the dash
## kill it, and the cut stops where it dies (FloorCut.stop); the claws don't, and it can't be stomped.
## Numbers: FloorCutterTuning (data/enemies/floor_cutter.tres), every one a placeholder for review.

enum State { WAIT, WARN, CHARGE, GONE }

const Rules = preload("res://scripts/enemies/floor_cutter_rules.gd")
const BODY_COLOR := Color(0.36, 0.37, 0.4)
const TRIM_COLOR := Color(0.26, 0.27, 0.3)
const BLADE_COLOR := Color(0.2, 0.21, 0.23)
## The red of every floor warning (BossProps.WARNING_COLOR), and the blade's edge.
const WARNING_COLOR := Color(1.0, 0.12, 0.08)
const SPARK_COLOR := Color(1.0, 0.6, 0.2)
## The warning line's width, as a share of the lane.
const LINE_WIDTH: float = 0.34
## The blade's spin while it charges (radians a second); it spins up to this over the warning.
const SPIN: float = 32.0

var tuning: FloorCutterTuning
var state: State = State.WAIT
var lane: int = 0
## The layout's cut it runs (LevelLayout.cuts), and the track's once its chunk is built.
var cut: Dictionary = {}
var floor_cut: FloorCut
## Where its blade cuts the floor (track distance): the cut's front while it charges.
var front: float = 0.0

var _run_speed: float = 18.0
var _blade: Node3D
var _line: MeshInstance3D
var _hitbox: Hazard
var _line_t: float = 0.0
var _spin_t: float = 0.0
var _spark_left: float = 0.0


func _build() -> void:
	tuning = tuning_res as FloorCutterTuning
	if tuning == null:
		tuning = FloorCutterTuning.new()
	display_name = "floor cutter"
	claw_immune = true
	stompable = false
	dash_kills = true
	lane = clampi(int(spawn.get("lane", 0)), 0, world.geo.lane_count - 1)
	cut = Rules.cut_of(world.layout, spawn)
	_run_speed = world.tuning.run_speed
	front = float(cut.get("end", spawn.get("at", 0.0)))
	position = world.lane_point(lane, front)
	_build_visuals()
	var r: float = tuning.blade_radius
	_hitbox = add_hitbox(&"body", tuning.hitbox_size, Vector3(0.0, tuning.hitbox_size.y * 0.5, 0.0), true)
	_hitbox.hazard_name = "floor cutter"
	_hitbox.contacted.connect(_on_contacted)
	if cut.is_empty():
		state = State.GONE
	# The blade is hidden in its body's front until it's in view.
	_blade.position = Vector3(0.0, r - 0.15, 0.0)


func _tick(delta: float) -> void:
	if cut.is_empty():
		return
	if floor_cut == null:
		floor_cut = world.track.floor_cut(lane, float(cut["end"]))
	var p: float = world.player_distance()
	match state:
		State.WAIT:
			if p >= FloorCutPlan.warn_at(cut):
				_warn()
		State.WARN:
			_spin_t = minf(_spin_t + delta, tuning.warn_seconds)
			_blade.rotation.x += SPIN * (_spin_t / maxf(tuning.warn_seconds, 0.1)) * delta
			if p >= FloorCutPlan.charge_at(cut):
				state = State.CHARGE
	if state == State.CHARGE:
		front = FloorCutPlan.front_at(cut, p, _run_speed)
		position = world.lane_point(lane, front)
		if floor_cut != null:
			floor_cut.advance_to(front)
		_blade.rotation.x += SPIN * delta
		_sparks(delta)
		if front <= float(cut["start"]) + 0.001:
			_gone()
	_update_line(delta)


## Its big attack (GDD §9: big attacks take turns) is on from its warning until it's gone. The generator
## planned nothing else to go on meanwhile; this keeps an enemy that might from starting one.
func is_major_attack_active() -> bool:
	return alive and (state == State.WARN or state == State.CHARGE)


## Gone once its cut has ended (it's off the screen behind the player), or if it never had one.
func should_retire() -> bool:
	return state == State.GONE


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 1.2, -1.0)


func hit_radius() -> float:
	return 1.0


func _on_defeated(cause: StringName) -> void:
	# GDD §9.9: "killing it mid-charge stops the cut where it dies" (and before it, saves the floor).
	if floor_cut != null:
		floor_cut.stop()
	elif not cut.is_empty():
		# Its cut's chunk isn't built yet: it never begins.
		front = float(cut["end"])
	_line.visible = false
	super._on_defeated(cause)


func _warn() -> void:
	state = State.WARN
	_line.visible = true
	_line_t = 0.0
	world.play_sfx_at(&"truck_rev", global_position)


func _gone() -> void:
	state = State.GONE
	_line.visible = false
	visible = false


## After the shield or the armor blocks its blade, the floor under the player holds for a moment
## (GDD §9.9: "just enough to switch lanes").
func _on_contacted(outcome: int) -> void:
	if outcome != DamageRules.Outcome.BLOCKED_ARMOR and outcome != DamageRules.Outcome.BLOCKED_SHIELD:
		return
	if floor_cut != null and world.player != null:
		floor_cut.hold_under(world.player, world.rules.cut_hold_seconds if world.rules != null else 1.0)


## The red line down the lane it's about to cut: from the cut's start to where it has got to.
func _update_line(delta: float) -> void:
	if not _line.visible:
		return
	_line_t += delta
	var from: float = float(cut["start"])
	var to: float = front
	if to - from < 0.05:
		_line.visible = false
		return
	var grow: float = 0.85 + 0.25 * clampf(_line_t / 0.8, 0.0, 1.0)
	var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.12 * sin(_line_t * 24.0)
	_line.global_transform = Transform3D(Basis.from_scale(Vector3(world.geo.lane_width * LINE_WIDTH * grow * beat, 0.04, to - from)),
		Vector3(world.geo.lane_x(lane), 0.03, TrackGeometry.world_z((from + to) * 0.5)))


## Sparks where the blade bites into the floor (none with Reduced flashing).
func _sparks(delta: float) -> void:
	if Settings.flashing_reduced:
		return
	_spark_left -= delta
	if _spark_left > 0.0:
		return
	_spark_left = tuning.spark_every
	world.effects.burst(global_position + Vector3(0.0, 0.15, -0.3), SPARK_COLOR, 5, 0.25)


func _build_visuals() -> void:
	var body: Vector3 = tuning.body_size
	var r: float = tuning.blade_radius
	var body_mat: Material = GreyboxMaterials.flat(BODY_COLOR)
	# The body waits behind its blade (further along the track), its nose over the blade's hub.
	GreyboxMaterials.add_box(self, Vector3(0.0, body.y * 0.5, -body.z * 0.5 - r * 0.4), body, body_mat)
	GreyboxMaterials.add_box(self, Vector3(0.0, body.y + 0.15, -body.z * 0.6 - r * 0.4), Vector3(body.x * 0.8, 0.3, body.z * 0.5),
		GreyboxMaterials.flat(TRIM_COLOR))
	_blade = Node3D.new()
	_blade.name = "Blade"
	add_child(_blade)
	# A vertical disc along the lane (its axis across it), the hazard red only on its cutting edge.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.12
	cyl.radial_segments = 24
	cyl.rings = 1
	disc.mesh = cyl
	disc.rotation.z = PI * 0.5
	disc.material_override = GreyboxMaterials.flat(BLADE_COLOR)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(disc)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = r - 0.08
	ring.outer_radius = r + 0.02
	ring.rings = 32
	ring.ring_segments = 4
	rim.mesh = ring
	rim.rotation.z = PI * 0.5
	rim.material_override = GreyboxMaterials.glow(WARNING_COLOR, 1.6)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(rim)
	_line = MeshInstance3D.new()
	_line.name = "WarningLine"
	_line.mesh = GreyboxMaterials.unit_box()
	_line.material_override = GreyboxMaterials.glow(WARNING_COLOR, 2.6, 0.75)
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.top_level = true
	_line.visible = false
	add_child(_line)
