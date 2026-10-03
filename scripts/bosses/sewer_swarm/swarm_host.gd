class_name SwarmHost
extends BossPart
## The Host, the Sewer Swarm's heart (GDD §10: "a poor person with electronic components fused to their
## sickly body, mostly hidden under the screeches latched onto them"; "The Host is one more entity"): the
## boss's body (its health is the fight's: BossPart, shares_health). It waits hidden through phases 1 and 2
## and comes into play in phase 3 (SwarmHostAttacks moves it, it draws itself and switches its hitboxes).
##
## Its look, all made before the fight: its bulk, host_creatures screeches latched onto it (a SwarmCrowd of
## kind HOST, one draw: knocked off a share at each hit, so more of the person shows), the person inside
## (SwarmHostPerson on the HumanoidRig, held up), and its three implants: red domes glowing through the swarm
## on its back (the weak points' language), each going dark as a hit shorts it out.
##
## Its poses (Pose): STAND (pacing the runner ahead, facing them; rearing to fling or lunge), LUNGE (charging
## down a lane at the runner: its attack hitbox live, an enemy attack armor blocks), STUNNED (shocked by a
## fence it was baited into, slumped in that lane: solid, its sides bump a lane switch back), CROUCH (in a
## ramp's lane at a host spot, long and low, its back crouch_height up: its body solid and deadly to run into,
## its sides bumping a lane switch back, its back a floor to land on, and its implants a weak point a stomp
## from above hits: a wall jump off the ramp's wall run comes down on them) and FREED (its defeat: the
## screeches scatter, the implants short out, the person slumps free). Its fling's splat is an enemy attack
## of its own (splat(): an enemy attack where the flung swarm lands).
## Numbers: SewerSwarmTuning ("The Host"). DESIGN-TBD (docs/questions/e4.md): its look and its way up.

enum Pose { HIDDEN, STAND, LUNGE, STUNNED, CROUCH, FREED }

const POSE_NAMES: PackedStringArray = ["hidden", "stand", "lunge", "stunned", "crouch", "freed"]
const IMPLANTS: int = 3
## The person's height (the rig's design height is 1.3 m).
const PERSON_HEIGHT: float = 1.75
## Shares of the swarm still latched on after each hit (the last one frees the person).
const LATCHED: PackedFloat32Array = [1.0, 0.72, 0.48, 0.0]

var tuning: SewerSwarmTuning
var pose: Pose = Pose.HIDDEN
## Its anchor's track distance (standing: its middle; lunging: its front; crouched: the crouch's middle), its
## x, and its height off the street (a leap).
var at: float = 0.0
var x: float = 0.0
var lift: float = 0.0
## Its look, eased by SwarmHostAttacks: crouched (0-1), rearing (0-1), charging (0-1), a shock's glow, and an
## attack's heat (0-1: enemy-attack red, only while it attacks: a fling's wind-up, a lunge's warning and
## charge; rearing to drop or leap is no attack).
var crouch: float = 0.0
var rear: float = 0.0
var charge: float = 0.0
var shock: float = 0.0
var heat: float = 0.0
## Hits taken (stomps on its implants and lunges into fences), and its implants still glowing.
var hits_taken: int = 0
var implants_left: int = IMPLANTS
## The crouch's length (metres along the track: crouch_length at the run's pace).
var crouch_length: float = 12.0
var crowd: SwarmCrowd
var person: HumanoidRig
var implants: Array[MeshInstance3D] = []
## Its hitboxes and surfaces (made once, switched and resized as it moves between poses).
var body: Hazard
var lunge_box: Hazard
var weak: Hazard
var splat_box: Hazard
var blocker: Area3D
var surface: StaticBody3D
## Seconds since it was freed.
var freed_seconds: float = 0.0

var _look: Node3D
var _splat_root: Node3D
var _shown: float = 1.0
var _clock: float = 0.0
static var _dome_live: ArrayMesh
static var _dome_dead: ArrayMesh


func _build() -> void:
	var p: Dictionary = spawn.get("params", {})
	tuning = p.get("tuning") as SewerSwarmTuning
	if tuning == null:
		tuning = SewerSwarmTuning.new()
	display_name = "the Host"
	is_obstacle = true
	var low_end: bool = bool(p.get("low_end", false))
	var grime: float = 1.0 if world.skin == null or world.skin.enemy_variant != &"city" else 0.0
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	crowd = SwarmCrowd.make(SwarmCrowd.Kind.HOST, tuning.host_size(low_end), hash(["host", int(p.get("seed", 0))]), grime,
		tuning.creature_scale)
	crowd.name = "HostSwarm"
	_look.add_child(crowd)
	person = HumanoidRig.new()
	person.name = "Person"
	_look.add_child(person)
	person.build(SwarmHostPerson.parts(), SwarmHostPerson.material())
	person.scale = Vector3.ONE * (PERSON_HEIGHT / 1.3)
	# Facing the runner (+z), as the swarm does.
	person.rotation = Vector3(0.0, PI, 0.0)
	for i: int in IMPLANTS:
		var dome := MeshInstance3D.new()
		dome.name = "Implant%d" % i
		dome.mesh = dome_mesh(true)
		dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_look.add_child(dome)
		implants.append(dome)
	# The shorted-out dome's mesh too, made now (its material is the live one's).
	dome_mesh(false)
	var lane_w: float = world.geo.lane_width
	body = add_hitbox(&"body", Vector3(lane_w * 0.7, 1.8, 6.0), Vector3(0.0, 0.9, 0.0))
	body.hazard_name = "the Host"
	lunge_box = add_hitbox(&"attack", Vector3(lane_w * tuning.lunge_hit_width_share, tuning.lunge_hit_height,
		tuning.lunge_hit_length), Vector3(0.0, tuning.lunge_hit_height * 0.5, -(0.3 + tuning.lunge_hit_length * 0.5)), true)
	lunge_box.hazard_name = "the Host"
	weak = add_weak_point(Vector3(lane_w * 0.8, tuning.implant_rise, 6.0), Vector3(0.0, 2.0, 0.0))
	weak.hazard_name = "the Host's implants"
	blocker = add_lane_blocker(Vector3(lane_w * 0.8, 2.0, 6.0), Vector3(0.0, 1.0, 0.0))
	surface = add_surface(Vector3(lane_w * 0.8, 0.2, 6.0), Vector3(0.0, -50.0, 0.0))
	_splat_root = Node3D.new()
	_splat_root.name = "Splat"
	_splat_root.top_level = true
	add_child(_splat_root)
	splat_box = add_hitbox(&"attack", Vector3(lane_w * 0.7, 1.0, tuning.splat_length), Vector3(0.0, 0.5, 0.0), true, _splat_root)
	splat_box.hazard_name = "the Sewer Swarm"
	for h: Hazard in [body, lunge_box, weak, splat_box]:
		h.set_enabled(false)
	_set_blocking(false)
	hide_away()


# --- Poses -----------------------------------------------------------------------------------------

## Out of play (phases 1 and 2): hidden, far under the street, nothing live.
func hide_away() -> void:
	pose = Pose.HIDDEN
	visible = false
	at = 0.0
	lift = -60.0
	for h: Hazard in [body, lunge_box, weak]:
		h.set_enabled(false)
	_set_blocking(false)
	place()


## Standing (pacing, rearing, a leap): in sight, nothing live but its look.
func stand() -> void:
	pose = Pose.STAND
	visible = true
	for h: Hazard in [body, lunge_box, weak]:
		h.set_enabled(false)
	_set_blocking(false)


## Lunging down the lane at `lane_x`: its front at `at`, its attack's hitbox live.
func lunge(lane_x: float) -> void:
	pose = Pose.LUNGE
	x = lane_x
	lift = 0.0
	body.set_enabled(false)
	weak.set_enabled(false)
	_set_blocking(false)
	lunge_box.set_enabled(true)


## Shocked by a fence and down in its lane past it (`p_at` its middle): solid, bumping lane switches back.
func stunned(lane_x: float, p_at: float) -> void:
	pose = Pose.STUNNED
	x = lane_x
	at = p_at
	lift = 0.0
	lunge_box.set_enabled(false)
	weak.set_enabled(false)
	var lane_w: float = world.geo.lane_width
	_resize(body, Vector3(lane_w * 0.7, 1.6, 4.0), Vector3(0.0, 0.8, 0.0))
	_resize(blocker, Vector3(lane_w * 0.8, 1.8, 4.6), Vector3(0.0, 0.9, 0.0))
	body.set_enabled(true)
	_set_blocking(true)


## Crouched in the lane at `lane_x` from track distance `from` to `to` (its implants not live yet: open()).
func crouch_at(lane_x: float, from: float, to: float) -> void:
	pose = Pose.CROUCH
	x = lane_x
	at = (from + to) * 0.5
	lift = 0.0
	crouch_length = to - from
	lunge_box.set_enabled(false)
	var lane_w: float = world.geo.lane_width
	var h: float = tuning.crouch_height
	var w: float = lane_w * tuning.crouch_width_share
	# Its body (smaller than its look, and well below its back), its sides, its back, and its implants' stomp
	# box over the whole back: a wall jump that comes down on it comes down on them.
	_resize(body, Vector3(w * 0.85, h - 0.3, crouch_length - 1.2), Vector3(0.0, (h - 0.3) * 0.5, 0.0))
	_resize(blocker, Vector3(w, h, crouch_length), Vector3(0.0, h * 0.5, 0.0))
	var top := surface.get_child(0) as CollisionShape3D
	(top.shape as BoxShape3D).size = Vector3(w * 0.95, 0.2, crouch_length - 0.6)
	surface.position = Vector3(0.0, h - 0.1, 0.0)
	_resize(weak, Vector3(lane_w * 0.98, tuning.implant_rise + 0.1, crouch_length - 1.0),
		Vector3(0.0, h + tuning.implant_rise * 0.5 - 0.05, 0.0))
	body.set_enabled(true)
	weak.set_enabled(false)
	_set_blocking(true)


## Its implants go live (crouched and settled).
func open() -> void:
	if pose == Pose.CROUCH and implants_left > 0:
		weak.set_enabled(true)


## Up from a crouch or a stun: its hitboxes go, its back with them (a runner still on it drops off).
func rise() -> void:
	stand()
	surface.position = Vector3(0.0, -50.0, 0.0)


## A hit (a stomp on its implants, or shocked by a fence it was baited into): a share of its screeches is
## knocked off, more of the person shows, and an implant shorts out (`stomped`: the one under the stomp).
func knock(stomped: bool) -> void:
	hits_taken += 1
	if implants_left > 0:
		implants_left -= 1
		implants[implants_left].mesh = dome_mesh(false)
	weak.set_enabled(false)
	shock = 1.0
	if not stomped:
		world.effects.burst(aim_point(), Color(1.0, 0.3, 0.7), 30, 1.1)
	world.effects.burst(aim_point() + Vector3(0.0, 0.6, 0.0), ScreechLair.MIST, 26, 1.0)


## Freed (its defeat): its hitboxes go (its back stays under a runner on it until SwarmHostAttacks takes it
## away), the screeches scatter, the implants short out, the person slumps.
func free_person() -> void:
	pose = Pose.FREED
	freed_seconds = 0.0
	for h: Hazard in [body, lunge_box, weak, splat_box]:
		h.set_enabled(false)
	_set_blocking(false)
	for i: int in implants.size():
		implants[i].mesh = dome_mesh(false)
	implants_left = 0


## The fling's splat: an enemy attack in `lane` at track distance `p_at` (its middle), on or off.
func splat(p_at: float, lane: int, on: bool) -> void:
	_splat_root.global_position = Vector3(world.geo.lane_x(lane), 0.0, TrackGeometry.world_z(p_at))
	splat_box.set_enabled(on)


## Puts it where it is now.
func place() -> void:
	position = Vector3(x, lift, TrackGeometry.world_z(at))


func _set_blocking(on: bool) -> void:
	blocker.monitorable = on
	blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER if on else 0
	if not on:
		surface.position = Vector3(0.0, -50.0, 0.0)


static func _resize(area: Area3D, size: Vector3, offset: Vector3) -> void:
	area.position = offset
	var shape := area.get_child(0) as CollisionShape3D
	(shape.shape as BoxShape3D).size = size
	var hazard := area as Hazard
	if hazard != null:
		hazard.size = size


# --- Enemy -----------------------------------------------------------------------------------------

## Weapons target it while it's in play and in front of the runner.
func targetable() -> bool:
	if not super.targetable() or pose in [Pose.HIDDEN, Pose.FREED] or world == null:
		return false
	return at > world.player.distance + 2.0


func is_major_attack_active() -> bool:
	return pose == Pose.LUNGE


func aim_point() -> Vector3:
	var h: float = lerpf(tuning.host_height * 0.55, tuning.crouch_height * 0.6, crouch)
	return Vector3(x, lift + h, TrackGeometry.world_z(at))


func hit_radius() -> float:
	return 1.6


func _tick(_delta: float) -> void:
	place()


## The fight is won (BossEncounter defeats every part): the Host is freed (SewerSwarm plays it out).
func _on_defeated(_cause: StringName) -> void:
	if pose != Pose.FREED:
		free_person()


# --- The look -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or crowd == null or not visible:
		return
	_clock += delta
	shock = move_toward(shock, 0.0, delta / 0.6)
	var latched: float = LATCHED[clampi(hits_taken, 0, LATCHED.size() - 1)]
	_shown = move_toward(_shown, latched, delta / 0.5)
	var dying: bool = pose == Pose.FREED
	if dying:
		freed_seconds += delta
	var w: float = lerpf(tuning.host_width, world.geo.lane_width * tuning.crouch_width_share, crouch)
	var h: float = lerpf(tuning.host_height, tuning.crouch_height, crouch)
	var d: float = lerpf(tuning.host_depth, crouch_length, crouch)
	crowd.set_host(Vector4(w, h, d, 0.0), crouch, rear, charge, shock, heat)
	crowd.set_life(_shown if not dying else 1.0, 1.0, 3 if dying else 0, freed_seconds, 6.0)
	crowd.show_up_to(1.0)
	_pose_person(delta, w, h, d)
	_place_implants(w, h, d)


## The person inside: held up in the bulk standing, prone along it crouched, slumped on the street freed.
func _pose_person(_delta: float, _w: float, h: float, d: float) -> void:
	var p: HumanoidPose
	if pose == Pose.FREED:
		p = SwarmHostPerson.freed()
		var k: float = clampf(freed_seconds / 0.8, 0.0, 1.0)
		person.position = Vector3(0.0, lerpf(h * 0.35, 0.0, k * k) - lift, 0.0)
	elif crouch > 0.5:
		p = SwarmHostPerson.prone()
		person.position = Vector3(0.0, h * 0.45, d * 0.18)
	else:
		p = SwarmHostPerson.held(fmod(_clock * 0.35, 1.0))
		person.position = Vector3(0.0, h * 0.42 + rear * 0.3, 0.25)
	person.apply_pose(p)


## The implants on its back: standing, on its shoulders and spine; crouched, along its spine (in a row
## from its rear to its head, the next to short out first).
func _place_implants(w: float, h: float, d: float) -> void:
	for i: int in implants.size():
		var dome: MeshInstance3D = implants[i]
		var stand_at := Vector3((float(i) - 1.0) * w * 0.28, h * (0.93 - 0.05 * absf(float(i) - 1.0)), -d * 0.22)
		var crouch_at_pos := Vector3(0.0, h + 0.02, (float(i) - 1.0) * d * 0.28)
		dome.position = stand_at.lerp(crouch_at_pos, crouch)
		dome.visible = pose != Pose.HIDDEN


## An implant's dome: a red dome glowing on a dark socket (the weak points' language), or shorted out (dark).
static func dome_mesh(live: bool) -> ArrayMesh:
	if live and _dome_live != null:
		return _dome_live
	if not live and _dome_dead != null:
		return _dome_dead
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(MeshKit.solid({"glow_scale": 4.0}))
	var dark := Color(0.12, 0.12, 0.13)
	var red: Color = BossProps.WARNING_COLOR if live else Color(0.18, 0.1, 0.09)
	var glow: float = 1.2 if live else 0.0
	m.prism(Vector3.ZERO, 0.55, 0.1, 10, dark)
	m.prism(Vector3(0.0, 0.1, 0.0), 0.4, 0.16, 10, red, glow)
	m.prism(Vector3(0.0, 0.26, 0.0), 0.26, 0.1, 10, red, glow * 1.1)
	var mesh: ArrayMesh = batch.to_mesh()
	if live:
		_dome_live = mesh
	else:
		_dome_dead = mesh
	return mesh
