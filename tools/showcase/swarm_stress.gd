extends Node3D
## The Sewer Swarm's rendering stress scene (task E4a, for the phone test, task E3: GDD §10, "performance on
## phones: build it now with crowd sizes that scale ... the phone test (risk test R4, task E3) comes later
## and sets the sizes"). Not part of the game. It draws N clusters of C screeches each, exactly as the fight
## draws them (SwarmCrowd: one MultiMesh and swarm_crowd.gdshader each), cycling through what a cluster does
## (heaped at the roadside rearing, pouring into a lane, charging down it toward the camera, shocked,
## falling, scattering), plus the roadside horde's two bands and the lairs' spill, on a plain street in
## Gangland's light seen from the run camera's place, with a readout: frames per second, frame time (the
## mean and the worst over the last second), the crowds' own CPU time a frame (setting their uniforms: no
## creature is touched on the CPU), draw calls, primitives and objects drawn.
##   ./play.sh res://tools/showcase/swarm_stress.tscn -- --clusters=5 --crowd=140 --horde=260
##   godot4 --path . res://tools/showcase/swarm_stress.tscn -- --low-end        (the tuning's low-end sizes)
##   add --rendering-method gl_compatibility before the scene for the web / low-end renderer
## Options: --clusters=N (0-12), --crowd=C (creatures per cluster), --horde=H (both gutters together),
## --spill=S (creatures out of each of 16 lairs), --low-end (the tuning's low-end crowd sizes), --lanes=N (the
## street's width: 3, 5 or 6), --seconds=S (quit after S seconds, printing a summary line: for scripted
## measurements), --still (no cycling: every cluster charging). Defaults: the tuning's crowd sizes
## (data/bosses/gangland_boss_tuning.tres). Sliders change the clusters, the crowd and the horde live.

const TUNING_PATH: String = "res://data/bosses/gangland_boss_tuning.tres"
const SKIN_PATH: String = "res://data/bosses/gangland_boss_skin.tres"
## One cluster's cycle (seconds): rearing at the roadside, pouring, charging, a death.
const CYCLE: float = 6.0

var clusters: int = 5
var crowd_size: int = 140
var horde_size: int = 260
var spill_each: int = 10
var lanes: int = 5
var seconds: float = 0.0
var still: bool = false

var tuning: SewerSwarmTuning
var crowds: Array[SwarmCrowd] = []
var bands: Array[SwarmCrowd] = []
var spill: SwarmCrowd
var _geo: TrackGeometry
var _label: Label
var _t: float = 0.0
var _frames: Array[float] = []
var _cpu: Array[float] = []
var _last_usec: int = 0
var _sum: Dictionary = {"frames": 0, "frame_ms": 0.0, "worst_ms": 0.0, "cpu_us": 0.0, "draws": 0, "prims": 0, "objects": 0}
var _sliders: Dictionary = {}


func _ready() -> void:
	tuning = load(TUNING_PATH) as SewerSwarmTuning
	var low_end: bool = DeviceProfile.is_low_end()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--low-end":
			low_end = true
	clusters = tuning.cluster_count
	crowd_size = tuning.cluster_size(low_end)
	horde_size = tuning.horde_size(low_end)
	spill_each = tuning.spill_size(low_end)
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--clusters="):
			clusters = clampi(int(v), 0, 12)
		elif arg.begins_with("--crowd="):
			crowd_size = maxi(int(v), 0)
		elif arg.begins_with("--horde="):
			horde_size = maxi(int(v), 0)
		elif arg.begins_with("--spill="):
			spill_each = maxi(int(v), 0)
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--seconds="):
			seconds = float(v)
		elif arg == "--still":
			still = true
	var movement := load("res://data/tuning/movement.tres") as MovementTuning
	_geo = TrackGeometry.new(lanes, movement)
	_build_scene(movement)
	_build_crowds()
	_build_ui()
	_last_usec = Time.get_ticks_usec()


func _build_scene(movement: MovementTuning) -> void:
	var skin := load(SKIN_PATH) as ZoneSkin
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	# A plain street and two walls (the crowds' cost, not the zone's scenery).
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_geo.wall_x() * 2.0, 260.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = GreyboxMaterials.flat(Color(0.21, 0.19, 0.165))
	floor_mesh.position = Vector3(0.0, 0.0, -110.0)
	add_child(floor_mesh)
	for side: int in [-1, 1]:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 14.0, 260.0)
		wall.mesh = box
		wall.material_override = GreyboxMaterials.flat(Color(0.33, 0.27, 0.21))
		wall.position = Vector3(side * (_geo.wall_x() + 0.25), 7.0, -110.0)
		add_child(wall)
	var cam := Camera3D.new()
	cam.fov = movement.camera_fov
	cam.far = 400.0
	add_child(cam)
	cam.position = Vector3(0.0, movement.camera_height, movement.camera_distance)
	cam.look_at(Vector3(0.0, 0.0, -movement.camera_look_ahead), Vector3.UP)
	cam.make_current()


func _build_crowds() -> void:
	for c: SwarmCrowd in crowds:
		c.queue_free()
	for b: SwarmCrowd in bands:
		b.queue_free()
	if spill != null:
		spill.queue_free()
	crowds.clear()
	bands.clear()
	var lane_w: float = _geo.lane_width
	for i: int in clusters:
		var c := SwarmCrowd.make(SwarmCrowd.Kind.CLUSTER, crowd_size, hash(["stress", i]), 1.0, tuning.creature_scale)
		c.set_shapes(tuning.mound_length, tuning.mound_depth, tuning.mound_climb, tuning.mass_length,
			lane_w * tuning.mass_width_share, tuning.mass_height)
		add_child(c)
		crowds.append(c)
	for side: int in [-1, 1]:
		var band := SwarmCrowd.make(SwarmCrowd.Kind.BAND, horde_size / 2, hash(["stress band", side]), 1.0,
			tuning.creature_scale)
		band.set_band(side * _geo.wall_x(), side, tuning.horde_ahead, tuning.horde_behind, tuning.horde_depth,
			tuning.horde_climb, tuning.horde_drift, tuning.horde_heap_spacing)
		add_child(band)
		bands.append(band)
	spill = SwarmCrowd.make(SwarmCrowd.Kind.SPILL, spill_each * 16, hash(["stress spill"]), 1.0, tuning.creature_scale)
	add_child(spill)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(12.0, 10.0)
	layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0))
	_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0))
	_label.add_theme_constant_override(&"outline_size", 4)
	panel.add_child(_label)
	for spec: Array in [["clusters", 0, 12, clusters], ["crowd", 0, 600, crowd_size], ["horde", 0, 1200, horde_size]]:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(spec[0])
		name_label.custom_minimum_size = Vector2(70.0, 0.0)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = float(spec[1])
		slider.max_value = float(spec[2])
		slider.step = 1.0 if spec[0] == "clusters" else 10.0
		slider.value = float(spec[3])
		slider.custom_minimum_size = Vector2(220.0, 0.0)
		slider.drag_ended.connect(func(_changed: bool) -> void: _on_slider(String(spec[0]), slider.value))
		row.add_child(slider)
		panel.add_child(row)
		_sliders[spec[0]] = slider


func _on_slider(which: String, value: float) -> void:
	match which:
		"clusters":
			clusters = int(value)
		"crowd":
			crowd_size = int(value)
		"horde":
			horde_size = int(value)
	_build_crowds()


func _process(delta: float) -> void:
	_t += delta
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - _last_usec) / 1000.0
	_last_usec = now
	var t0: int = Time.get_ticks_usec()
	_animate()
	var cpu_us: float = float(Time.get_ticks_usec() - t0)
	_frames.append(frame_ms)
	_cpu.append(cpu_us)
	while _frames.size() > 60:
		_frames.pop_front()
		_cpu.pop_front()
	var draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var objects: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	if _t > 1.0:
		_sum["frames"] = int(_sum["frames"]) + 1
		_sum["frame_ms"] = float(_sum["frame_ms"]) + frame_ms
		_sum["worst_ms"] = maxf(float(_sum["worst_ms"]), frame_ms)
		_sum["cpu_us"] = float(_sum["cpu_us"]) + cpu_us
		_sum["draws"] = maxi(int(_sum["draws"]), draws)
		_sum["prims"] = maxi(int(_sum["prims"]), prims)
		_sum["objects"] = maxi(int(_sum["objects"]), objects)
	var mean: float = 0.0
	var worst: float = 0.0
	for f: float in _frames:
		mean += f
		worst = maxf(worst, f)
	mean /= maxf(_frames.size(), 1)
	var cpu_mean: float = 0.0
	for c: float in _cpu:
		cpu_mean += c
	cpu_mean /= maxf(_cpu.size(), 1)
	_label.text = "Sewer Swarm stress (%s)\n%d clusters x %d screeches, horde %d, spill %d: %d creatures\n%.0f fps   frame %.1f ms (worst %.1f)   crowd CPU %.0f us\ndraw calls %d   primitives %d   objects %d" % [
		RenderingServer.get_current_rendering_method(), clusters, crowd_size, horde_size, spill_each * 16,
		clusters * crowd_size + horde_size + spill_each * 16, 1000.0 / maxf(mean, 0.001), mean, worst, cpu_mean, draws, prims, objects]
	if seconds > 0.0 and _t >= seconds:
		var n: int = maxi(int(_sum["frames"]), 1)
		print("swarm_stress %s: clusters=%d crowd=%d horde=%d spill=%d creatures=%d frames=%d frame_ms=%.2f worst_ms=%.2f crowd_cpu_us=%.1f draws=%d primitives=%d objects=%d" % [
			RenderingServer.get_current_rendering_method(), clusters, crowd_size, horde_size, spill_each * 16,
			clusters * crowd_size + horde_size + spill_each * 16, n, float(_sum["frame_ms"]) / n, float(_sum["worst_ms"]),
			float(_sum["cpu_us"]) / n, int(_sum["draws"]), int(_sum["prims"]), int(_sum["objects"])])
		get_tree().quit()


## What the fight does to its crowds each frame: a few uniforms a crowd.
func _animate() -> void:
	var wall: float = _geo.wall_x()
	for i: int in crowds.size():
		var c: SwarmCrowd = crowds[i]
		var side: int = -1 if i % 2 == 0 else 1
		var lane: int = (i * 2 + 1) % lanes
		var k: float = CYCLE * 0.65 if still else fmod(_t + i * 1.13, CYCLE)
		var base: float = 22.0 + float(i) * 13.0
		var front: float = base
		var pour: float = 0.0
		var rear: float = clampf(k / 1.6, 0.0, 1.0)
		var charge: float = 0.0
		var death: int = 0
		var death_t: float = 0.0
		if k >= 2.0:
			pour = clampf((k - 2.0) / 0.55, 0.0, 1.0)
		if k >= 2.55:
			charge = 1.0
			front = base - minf(k - 2.55, 2.2) * 14.0
		if k >= 4.75:
			death = 1 + (i % 3)
			death_t = k - 4.75
		c.global_position = Vector3(0.0, 0.0, -front)
		c.set_formation(side * wall, side, 0.0, _geo.lane_x(lane), 0.0)
		c.set_motion(pour, rear, 0.3 + 0.7 * rear, charge)
		c.set_life(1.0, 1.0, death, death_t, 14.0)
	for band: SwarmCrowd in bands:
		band.global_position = Vector3.ZERO
		band.set_life(1.0, 1.0, 0, 0.0)
	# The spill: a lair bursting every half second along both sides.
	spill.set_param(&"clock", _t)
	var slot: int = int(_t / 0.5)
	if slot != int((_t - get_process_delta_time()) / 0.5) and spill_each > 0:
		var j: int = posmod(slot, 16)
		var side: int = -1 if slot % 2 == 0 else 1
		var at := Vector3(side * (wall - 0.5), 0.0, -(15.0 + float(posmod(slot * 7, 60))))
		for n: int in spill_each:
			spill.set_spill(j * spill_each + n, at, side, _t)
