class_name SleepTakerBody
extends BossPart
## The Sleep Taker's body (GDD §10), the fight's one part: the colossal nightmare (SleepTakerModel),
## scaled to the street. The encounter (SleepTaker) moves it and sets what it's doing (its great maw
## opening, its arms raised and slashing, the lunge, the inhale, the light it has swallowed); this
## draws it, easing each toward its target.
## Declared, never special-cased (CLAUDE.md principle 8), so the shared rules apply as to any enemy:
## - immune_to_weapons (GDD §10: like every Bad Dream, weapons have no effect at all): auto-fire never
##   targets it, and no shot or splash hurts it (a fence generator's rule); its BossDef's weapon cap is 0
##   besides. Only a generator's EMP hurts it (SleepTaker._on_part_emp), each tearing a chunk away
##   (tear(): SleepTakerModel.CHUNK_HEADS);
## - a boss's body (BossPart): claws never defeat it, the dash passes through it, it takes no stomps
##   (it has no weak points);
## - its touch is an enemy attack (like the Bad Dream's), a damage box inside its heads and torso,
##   smaller than the look and far out of the runner's reach: it hovers SleepTakerTuning.hover_ahead
##   ahead and its lunge stops with its claws in front of the runner.
## Its attacks' hitboxes are its own too (enemy attacks, through add_hitbox), made by the encounter's
## attacks: the giant slash's box (SleepTakerSlash) and each grasping hand's (SleepTakerHands).

## Its touch: the core of its heads and torso, in the model's space (scaled with it).
const CORE_SIZE := Vector3(7.0, 12.0, 3.6)
const CORE_CENTER := Vector3(0.0, 12.0, 0.2)
## How fast its animation eases toward what the encounter asks (per second, exponential).
const EASE: float = 10.0
## How long a chunk takes to rip away and dissolve once an EMP tears it (GDD §10: "the EMP rips a chunk
## of the nightmare away").
const TEAR_SECONDS: float = 1.4

var tuning: SleepTakerTuning
## Its uniform scale (the model's size over the street: SleepTakerModel.REF_WIDTH wide at 1).
var size: float = 1.0
var model: SleepTakerModel

## What the encounter asks for (0-1 each; see SleepTakerModel): the model eases toward these.
var shriek: float = 0.0
var raise: float = 0.0
var slash: float = 0.0
var attack: float = 0.0
var lunge: float = 0.0
var inhale: float = 0.0
var swallowed: float = 0.0
var reach: float = 1.0
## Materializing (1 = not there yet) and dissolving: set directly, not eased.
var fade: float = 0.0
## Seconds since each chunk (SleepTakerModel.CHUNK_HEADS) was torn away; -1 while it's still there.
var tear_time := PackedFloat32Array([-1.0, -1.0, -1.0, -1.0])

var _core: Hazard


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as SleepTakerTuning
	if tuning == null:
		tuning = SleepTakerTuning.new()
	# GDD §10: immune to weapons, like every Bad Dream (auto-fire never targets it, no shot hurts it).
	immune_to_weapons = true
	# GDD §9: big attacks take turns (EnemyDirector.major_attack_blocked): other enemies hold theirs
	# while one of its attacks warns or strikes.
	exclusive_major_attack = true
	size = scale_for(world.geo.wall_x() * 2.0, tuning)
	model = SleepTakerModel.new()
	model.name = "Model"
	model.scale = Vector3.ONE * size
	add_child(model)
	model.build(rng.randf() * 10.0)
	_core = add_hitbox(&"body", CORE_SIZE * size, CORE_CENTER * size, true)
	_core.hazard_name = display_name


## Its uniform scale on a street `street_width` wide (wall to wall): the model fills it less the margins,
## within the tuning's limits.
static func scale_for(street_width: float, t: SleepTakerTuning) -> float:
	var inner: float = street_width - 2.0 * t.street_margin
	return clampf(inner / SleepTakerModel.REF_WIDTH, t.min_scale, t.max_scale)


## Puts it at `pos` (the street under its middle, world space), turned `lean` radians toward the runner.
func set_pose(pos: Vector3, lean: float = 0.0) -> void:
	position = pos
	model.rotation.y = lean


## The great maw's centre in world space (its shriek comes from there).
func mouth_world() -> Vector3:
	return model.global_transform * SleepTakerModel.BIG_MAW_CENTER


## Its height in metres (the top of its heads).
func height() -> float:
	return SleepTakerModel.REF_HEIGHT * size


## How far in front of its middle its claws reach at rest, in metres.
func claw_reach() -> float:
	return SleepTakerModel.CLAW_REACH * size


func core_hitbox() -> Hazard:
	return _core


## An EMP tore chunk `chunk` away (SleepTakerModel.CHUNK_HEADS): it rips off in a burst of wisps and
## dissolves over TEAR_SECONDS (`instant`: already gone, for a fight resumed at a later phase).
func tear(chunk: int, instant: bool = false) -> void:
	if chunk < 0 or chunk >= tear_time.size() or tear_time[chunk] >= 0.0:
		return
	# (Already gone: well past its tear, clear of float32 rounding.)
	tear_time[chunk] = TEAR_SECONDS + 1.0 if instant else 0.0
	if not instant and model != null:
		model.burst_chunk(chunk)


## How far chunk `chunk` has been torn away (0 = still there, 1 = gone).
func torn(chunk: int) -> float:
	if chunk < 0 or chunk >= tear_time.size() or tear_time[chunk] < 0.0:
		return 0.0
	return clampf(tear_time[chunk] / TEAR_SECONDS, 0.0, 1.0)


func aim_point() -> Vector3:
	return global_position + CORE_CENTER * size


func hit_radius() -> float:
	return 3.0 * size


## Its attacks are on while the encounter says one warns or strikes.
func is_major_attack_active() -> bool:
	var boss := encounter as SleepTaker
	return alive and boss != null and boss.attack_on()


## Mesh instances, surfaces and vertices drawn now (the draw budget; its particles are one draw each and
## counted as instances).
func draw_stats() -> Dictionary:
	var out := {"instances": 0, "surfaces": 0, "vertices": 0}
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		out["instances"] += 1
		var mesh: Mesh = (g as MeshInstance3D).mesh if g is MeshInstance3D else null
		if mesh == null:
			continue
		out["surfaces"] += mesh.get_surface_count()
		for s: int in mesh.get_surface_count():
			out["vertices"] += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return out


## Beaten, it keeps drawing itself while the encounter plays its defeat (Enemy stops ticking a defeated
## enemy).
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not alive and world != null:
		_animate(delta)


func _tick(delta: float) -> void:
	_animate(delta)


## The fight is won: the encounter plays the defeat, so the body stays (its hitboxes are already off).
func _on_defeated(_cause: StringName) -> void:
	pass


func _animate(delta: float) -> void:
	if model == null:
		return
	var k: float = 1.0 - exp(-EASE * delta)
	model.shriek = lerpf(model.shriek, shriek, k)
	model.raise = lerpf(model.raise, raise, k)
	model.slash = lerpf(model.slash, slash, 1.0 - exp(-30.0 * delta))
	model.attack = lerpf(model.attack, attack, k)
	model.lunge = lerpf(model.lunge, lunge, 1.0 - exp(-18.0 * delta))
	model.inhale = lerpf(model.inhale, inhale, 1.0 - exp(-4.0 * delta))
	model.swallowed = lerpf(model.swallowed, swallowed, 1.0 - exp(-3.0 * delta))
	model.reach = lerpf(model.reach, reach, k)
	model.fade = fade
	for i: int in tear_time.size():
		if tear_time[i] >= 0.0:
			tear_time[i] += delta
	model.torn = Vector4(torn(0), torn(1), torn(2), torn(3))
	model.animate()
