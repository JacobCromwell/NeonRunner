class_name SewerSwarmIntro
extends CinematicSequencer
## The Gangland boss intro, before the Sewer Swarm (the owner's story beat, October 9, 2026; GDD §10). At street
## level, the runner runs down the middle of the street between manholes on either side. Two seconds in, a
## screech leaps out of one at them and they jump over it; a second later three more, two on one side and one on
## the other: they slide under the one leaping over and weave round the other two; a second later five on the
## left and six on the right, and they run on past them. Then more and more pour out of the manholes, and more
## drop from the sky out of sight, landing and running beside the runner, as the camera swings round in front
## of them: behind them a wall of screeches rises and runs them down, curling over like a breaking wave. As it
## closes in, one cut to the mass: a dark hollow in its middle, and in the dark the glint of the Host. Then black,
## and the fight (whose Rising carries on from here: manholes shaking all along both sides, screeches pouring out).
##
## The camera stays at ground level throughout, so we're in the runner's shoes (owner). On the toolkit: the runner,
## the camera and the events are the timeline's (_make_timeline); the screeches, their manholes and the swarm are
## this cinematic's own props (SwarmIntroScreeches, SwarmIntroSwarm), built on the stage, so they hide with it,
## from the sewer screech's and the Sewer Swarm's own meshes and shaders, and moved by the cinematic's clock
## (_on_advance), so a test or a tool stepping it sees the same. Visual only: no hitboxes. The stage is a plain
## stretch of the fight's arena look (CineStage.skin_for) in as many lanes as the fight, and the runner runs at
## the fight's speed. Its numbers are data: `numbers`, by default data/cinematics/sewer_swarm_intro.tres
## (SewerSwarmIntroTuning). DESIGN-TBD (docs/questions/f2b.md): what the owner's beats leave open.

const NUMBERS_PATH: String = "res://data/cinematics/sewer_swarm_intro.tres"
## The runner's path has a key this often through a jump or a weave (and every half second otherwise).
const RUNNER_KEY_STEP: float = 0.04

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: SewerSwarmIntroTuning

## The numbers playing (numbers, or NUMBERS_PATH's), and the runner's speed (m/s).
var n: SewerSwarmIntroTuning
var speed: float = 18.0
## Fewer creatures (DeviceProfile.is_low_end(), read as it starts; tools and tests may set it before).
var low_end: bool = false
var screeches: SwarmIntroScreeches
var swarm: SwarmIntroSwarm


func _numbers() -> SewerSwarmIntroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as SewerSwarmIntroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	speed = run_speed()
	var d := CineStageDef.new()
	d.length = n.stage_length
	return d


## The runner's speed: the fight's arena's own (BossDef.arena), else the zone's (ZoneDef.run_speed), else the
## base run speed, as Campaign.run_speed_for gives the fight.
func run_speed() -> float:
	if zone != null and zone.boss != null and zone.boss.arena != null and zone.boss.arena.run_speed > 0.0:
		return zone.boss.arena.run_speed
	if zone != null and zone.run_speed > 0.0:
		return zone.run_speed
	return tuning.run_speed


func _make_timeline() -> CineTimeline:
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	_add_runner(t)
	_add_camera(t)
	_add_events(t)
	# The props, now the stage is built (_on_advance moves them from the first frame on).
	low_end = low_end or DeviceProfile.is_low_end()
	var props := Node3D.new()
	props.name = "SwarmIntro"
	stage.add_child(props)
	screeches = SwarmIntroScreeches.new()
	props.add_child(screeches)
	screeches.setup(self)
	swarm = SwarmIntroSwarm.new()
	props.add_child(swarm)
	swarm.setup(self)
	return t


## The props keep time with the clock (stepped by a test or a tool, they show the same).
func _on_advance(_delta: float) -> void:
	if screeches == null:
		return
	screeches.update(time)
	swarm.update(time)


## The street must stay built under the swarm behind the runner (a stretch of it out of the run camera's sight).
func _stage_near(near: float) -> float:
	return minf(near, runner_z(time) - n.gap_start - n.mass_length - 5.0)


# --- The runner -------------------------------------------------------------------------------------

## Where the runner is along the track at `t`.
func runner_z(t: float) -> float:
	return n.runner_start + speed * t


## Sideways: the weave round the second beat's two (0 to `weave_side` and back, starting and ending at rest).
func runner_x(t: float) -> float:
	var w: Vector2 = weave_window()
	if t <= w.x or t >= w.y:
		return 0.0
	return n.weave_side * 0.5 * (1.0 - cos(TAU * (t - w.x) / (w.y - w.x)))


## Up: the jump over the first screech.
func runner_y(t: float) -> float:
	var j: Vector2 = jump_window()
	if t <= j.x or t >= j.y:
		return 0.0
	var u: float = (t - j.x) / (j.y - j.x)
	return 4.0 * n.jump_height * u * (1.0 - u)


func runner_at(t: float) -> Vector3:
	return Vector3(runner_x(t), runner_y(t), runner_z(t))


func sliding(t: float) -> bool:
	var s: Vector2 = slide_window()
	return t >= s.x and t < s.y


func jump_window() -> Vector2:
	return Vector2(n.jump_at - n.jump_seconds * 0.5, n.jump_at + n.jump_seconds * 0.5)


func slide_window() -> Vector2:
	return Vector2(n.slide_at - n.slide_seconds * 0.5, n.slide_at + n.slide_seconds * 0.5)


func weave_window() -> Vector2:
	return Vector2(n.weave_at - n.weave_seconds * 0.5, n.weave_at + n.weave_seconds * 0.5)


## The runner's keys: every half second along the street, close together through the jump and the weave
## (straight moves between them), and the slide's start and end.
func _add_runner(t: CineTimeline) -> void:
	var times: Array[float] = []
	var at: float = 0.0
	while at < n.duration:
		times.append(at)
		at += 0.5
	times.append(n.duration)
	for w: Vector2 in [jump_window(), weave_window()]:
		at = w.x
		while at < w.y:
			times.append(at)
			at += RUNNER_KEY_STEP
		times.append(w.y)
	var s: Vector2 = slide_window()
	times.append(s.x)
	times.append(s.y)
	times.sort()
	var runner: CineActor = t.actor(&"runner")
	var last: float = -1.0
	var was_sliding: bool = false
	for time_at: float in times:
		if time_at - last < 0.005 or time_at > n.duration:
			continue
		var slide: bool = sliding(time_at)
		var pose: StringName = &""
		if last < 0.0 or slide != was_sliding:
			pose = &"slide" if slide else &"run"
		last = time_at
		was_sliding = slide
		runner.at(time_at, runner_at(time_at), pose)


# --- The swarm --------------------------------------------------------------------------------------

## How far behind the runner the wall's foot is at `t` (metres): closing in from `gap_start` as it rises to
## `gap_cut` at the cut, then by `close_after_cut` m/s.
func wall_gap(t: float) -> float:
	if t >= n.cut_at:
		return n.gap_cut - n.close_after_cut * (t - n.cut_at)
	var u: float = clampf((t - n.wall_from) / maxf(n.cut_at - n.wall_from, 0.01), 0.0, 1.0)
	return lerpf(n.gap_start, n.gap_cut, lerpf(u, u * u, n.gap_ease))


## How far the wall has risen (0 before `wall_from`, 1 once risen).
func wall_rise(t: float) -> float:
	return smoothstep(0.0, 1.0, clampf((t - n.wall_from) / maxf(n.rise_seconds, 0.01), 0.0, 1.0))


## Where the wall's foot is along the track (-INF before it rises): screeches behind it are lost in it.
func wall_foot_z(t: float) -> float:
	if t < n.wall_from:
		return -INF
	return runner_z(t) - wall_gap(t)


## The middle of the street (track x: the runner's lane is a lane off it on an even count).
func street_middle() -> float:
	return (stage.wall_x(-1) + stage.wall_x(1)) * 0.5


## Draw calls its props add now (each visible mesh's surfaces, and each MultiMesh's): tests.
func props_draw_calls() -> int:
	var count: int = 0
	if stage == null or stage.get_node_or_null(^"SwarmIntro") == null:
		return 0
	for node: Node in stage.get_node(^"SwarmIntro").find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		count += mesh.get_surface_count() if mesh != null else 0
	return count


## The middle of the hollow in the mass (track space), which the cut looks into.
func maw_point(t: float) -> Vector3:
	return Vector3(0.0, n.maw_height, wall_foot_z(t) + n.maw_forward)


# --- The camera -------------------------------------------------------------------------------------

## The camera at `at`: [position, what it looks at (track space), field of view]. It rides with the runner's
## line (not their jumps or weaves), low behind them, then swings round their right side to low in front of
## them looking back, then after the cut looks into the hollow from between them and the wall.
func camera_at(at: float) -> Array:
	var r := Vector3(0.0, 0.0, runner_z(at))
	if at >= n.cut_at:
		var c: float = clampf((at - n.cut_at) / maxf(n.duration - n.cut_at, 0.01), 0.0, 1.0)
		return [r + n.cut_camera.lerp(n.cut_camera_end, c), maw_point(at), n.cut_fov]
	if at <= n.swing_from:
		return [r + n.behind, r + n.behind_look, n.behind_fov]
	if at >= n.swing_to:
		var f: float = clampf((at - n.swing_to) / maxf(n.cut_at - n.swing_to, 0.01), 0.0, 1.0)
		return [r + n.front.lerp(n.front_end, f), r + n.front_look.lerp(n.front_look_end, f), n.front_fov]
	# The swing: round the runner's right side (+x), low, looking at them halfway round.
	var s: float = smoothstep(n.swing_from, n.swing_to, at)
	var a0: float = atan2(n.behind.x, n.behind.z)
	var a1: float = atan2(n.front.x, n.front.z)
	var radius: float = lerpf(Vector2(n.behind.x, n.behind.z).length(), Vector2(n.front.x, n.front.z).length(), s)
	var a: float = lerpf(a0, a1, s)
	var side: float = minf(radius, minf(n.swing_side, stage.wall_x(1) - n.swing_wall))
	var pos: Vector3 = r + Vector3(side * sin(a), lerpf(n.behind.y, n.front.y, s), radius * cos(a))
	var middle: Vector3 = r + Vector3(0.0, 1.0, 0.0)
	var target: Vector3 = (r + n.behind_look).lerp(middle, smoothstep(0.0, 1.0, s * 2.0)) if s < 0.5 \
		else middle.lerp(r + n.front_look, smoothstep(0.0, 1.0, s * 2.0 - 1.0))
	return [pos, target, lerpf(n.behind_fov, n.front_fov, s)]


## A key every `camera_key_step` (smooth through them), and the cut.
func _add_camera(t: CineTimeline) -> void:
	var step: float = n.camera_key_step
	var times: Array[float] = []
	var at: float = 0.0
	while at < n.cut_at - step * 0.5:
		times.append(at)
		at += step
	# The last moment before the cut (the key before a cut holds until it).
	times.append(n.cut_at - 0.004)
	var cut_index: int = times.size()
	at = n.cut_at
	while at < n.duration - step * 0.5:
		times.append(at)
		at += step
	times.append(n.duration)
	for i: int in times.size():
		var c: Array = camera_at(times[i])
		var key: CineCameraKey = t.shot(times[i], c[0], c[1], CinePath.Move.SMOOTH, c[2])
		if i == cut_index:
			key.move = CinePath.Move.CUT


# --- Sounds and effects -----------------------------------------------------------------------------

func _add_events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, n.music_fade)
	# Each beat: its manholes' rattle (the warning), then the burst.
	for burst: float in [n.first_burst, n.second_burst, n.third_burst]:
		t.sound(burst - n.shake_seconds, &"screech_shake")
		t.sound(burst, &"screech_burst")
	var j: Vector2 = jump_window()
	t.sound(j.x, &"jump")
	t.sound(j.y, &"land")
	t.sound(slide_window().x, &"slide")
	t.sound(n.weave_at - 0.25, &"screech_swipe")
	# The pour: manholes shaking and bursting all around, a swelling chitter, the wall rising and closing in.
	t.sound(n.pour_from - 0.35, &"swarm_rise")
	t.sound(n.pour_from + 0.8, &"swarm_chitter")
	t.sound(n.wall_from + 0.2, &"swarm_wave")
	t.sound(n.cut_at - 1.3, &"swarm_surge")
	t.effect(n.cut_at - 1.4, CineEvent.SHAKE, 1.4, n.approach_shake)
	# The cut, and the glint in the dark (its look: SwarmIntroSwarm.glint_at).
	t.cue(n.cut_at, &"cut")
	t.sound(n.cut_at, &"swarm_chitter")
	t.effect(n.cut_at, CineEvent.SHAKE, n.duration - n.cut_at, n.cut_shake)
	t.cue(n.cut_at + n.glint_after, &"glint")
	t.effect(n.duration - n.fade_out, CineEvent.FADE_OUT, n.fade_out)
