extends SceneTree
## Bakes the Marketplace citizens' flipbook sprite sheets (GDD §5, "Citizens"; task D3) from the
## shared HumanoidRig (CitizenRig): one PNG per archetype in assets/sprites/citizens/, a
## CitizenSheet.COLS x ROWS grid (one row per clip: idle, startled, cheer), each cell a transparent,
## unshaded render of the posed rig. MarketCitizen plays the baked sheet back as a cheap textured
## card; nothing here runs at play time, and the rig itself is never seen in the game.
##
## Regenerate: tools/godot.sh citizens (renders real 3D frames, so it needs a display: Xvfb headless,
## or a real one).

const OUT_DIR: String = "res://assets/sprites/citizens"
const ROW_CLIPS: Array[CitizenRig.Clip] = [CitizenRig.Clip.IDLE, CitizenRig.Clip.STARTLED, CitizenRig.Clip.CHEER]

var _viewport: SubViewport
var _rig: HumanoidRig


func _initialize() -> void:
	_build_scene()
	await process_frame
	await process_frame
	for i: int in CitizenRig.archetype_count():
		await _bake(i)
	print("Wrote %d citizen sheet(s) to %s" % [CitizenRig.archetype_count(), OUT_DIR])
	quit()


func _build_scene() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	_viewport = SubViewport.new()
	_viewport.size = CitizenSheet.CELL
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.54, 0.56)
	e.ambient_light_energy = 1.1
	env.environment = e
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_energy = 1.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.58
	camera.look_at_from_position(Vector3(0.0, 0.78, 1.6), Vector3(0.0, 0.78, 0.0))
	_viewport.add_child(camera)
	_rig = HumanoidRig.new()
	_rig.rotation.y = PI  # The rig faces -z; turned to face the camera, at +z.
	_viewport.add_child(_rig)


func _bake(index: int) -> void:
	var a: CitizenRig.Archetype = CitizenRig.ARCHETYPES[index]
	_rig.build(CitizenRig.parts(index), CitizenRig.material())
	var cell: Vector2i = CitizenSheet.CELL
	var atlas := Image.create(cell.x * CitizenSheet.COLS, cell.y * CitizenSheet.ROWS, false, Image.FORMAT_RGBA8)
	for row: int in ROW_CLIPS.size():
		var clip: CitizenRig.Clip = ROW_CLIPS[row]
		for col: int in CitizenSheet.COLS:
			var t: float = float(col) / float(CitizenSheet.COLS - 1)
			_rig.apply_pose(CitizenRig.pose_at(clip, t))
			await process_frame
			await process_frame
			var frame: Image = _viewport.get_texture().get_image()
			atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, cell), Vector2i(col * cell.x, row * cell.y))
	var path: String = CitizenSheet.texture_path(a.name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	atlas.save_png(path)
	print("  %s -> %s (%dx%d)" % [a.name, path, atlas.get_width(), atlas.get_height()])
