extends Node3D
## The actual CreditField in a stationary RunWorld, at gameplay camera distances.
## --skin=<skin id> --baseline --reduced --shot=res://build/credits/<name>.png
## --all captures before/after in every skin to res://build/credits/ (create that directory first).
## Baseline replaces only the 100-credit mesh/material with its previous rendering.

var world: RunWorld


func _ready() -> void:
	var skin_id: String = "city"
	var baseline: bool = false
	var shot: String = ""
	var all_skins: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--skin="):
			skin_id = arg.get_slice("=", 1)
		elif arg == "--baseline":
			baseline = true
		elif arg == "--all":
			all_skins = true
		elif arg == "--reduced":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", true)
		elif arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	if all_skins:
		for skin: String in ["greybox", "city", "gangland", "marketplace", "golden",
			"golden_palace", "corporate", "corporate_plaza", "dead_zone"]:
			for before: bool in [true, false]:
				_build(skin, before)
				var error: Error = await _capture("res://build/credits/%s_%s.png" % [skin, "before" if before else "after"])
				if error != OK:
					get_tree().quit(int(error))
					return
				for child: Node in get_children():
					child.queue_free()
				await get_tree().process_frame
		get_tree().quit()
	else:
		_build(skin_id, baseline)
		if not shot.is_empty():
			var error: Error = await _capture(shot)
			get_tree().quit(int(error))


func _build(skin_id: String, baseline: bool) -> void:
	var layout := LevelLayout.new()
	layout.lane_count = 5
	layout.length = 160.0
	for at: float in [12.0, 28.0, 44.0]:
		for lane: int in 4:
			layout.credits.append({"at": at, "surface": "floor", "lane": lane, "side": 0,
				"height": 0.7, "value": [1, 5, 25, 100][lane]})
	layout.credits.append({"at": 22.0, "surface": "wall", "side": 1, "height": 3.0, "value": 100})
	layout.hulls.append({"start": 32.0, "end": 52.0})
	layout.credits.append({"at": 36.0, "surface": "ceiling", "lane": 3, "value": 100})
	var config := LevelConfig.new()
	config.lane_count = 5
	config.skin = load("res://data/skins/%s_skin.tres" % skin_id) as ZoneSkin
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, load("res://data/tuning/movement.tres") as MovementTuning,
		load("res://data/tuning/game_rules.tres") as GameRules)
	if baseline:
		var shader := Shader.new()
		shader.code = CreditField.SPIN_SHADER
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter(&"color", CreditField.color_of(100))
		material.set_shader_parameter(&"energy", 3.0)
		material.set_shader_parameter(&"spin_speed", 1.8)
		for child: Node in world.credits.get_children():
			var inst := child as MultiMeshInstance3D
			if inst != null and inst.material_override == CreditField.material_for(100):
				inst.multimesh.mesh = CreditField._gem(0.42, 0.42 * 1.6)
				inst.material_override = material
	var env := WorldEnvironment.new()
	env.environment = config.skin.make_environment()
	env.environment.glow_enabled = false
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	var camera := RunCamera.new()
	add_child(camera)
	camera.follow(world)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(16.0, 12.0)
	label.text = "%s | %s | Compatibility / no bloom\nFloor columns: 1, 5, 25, 100 | wall + ceiling: 100" % [
		skin_id, "BEFORE" if baseline else "AFTER"]
	label.add_theme_font_size_override(&"font_size", 18)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 5)
	layer.add_child(label)


func _capture(shot: String) -> Error:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(shot)
	print("credit_review: %s (%s)" % [shot, error_string(error)])
	return error
