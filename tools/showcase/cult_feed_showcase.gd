extends Node3D
## The cult's feed (CultFeed) up close, for visual review: a wide billboard, a TV and a tall screen
## side by side, all playing the same broadcast in sync. Render a whole loop (about 18 s):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/feed/f.png --quit-after 190 res://tools/showcase/cult_feed_showcase.tscn
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options: --reduced (Reduced flashing on: the static and the rolling bar hold still).


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--reduced"):
		RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.06, 0.07)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.7
	env.environment.glow_hdr_threshold = 1.1
	add_child(env)
	var batch := MeshBatch.new()
	var feed: MeshLayer = batch.layer(CultFeed.material())
	var frame: MeshLayer = batch.layer(MeshKit.solid())
	# [lower-left corner, width, height]
	var screens: Array = [[Vector3(-7.4, 0.6, 0.0), 9.0, 3.0], [Vector3(2.4, 0.9, 0.0), 2.4, 1.8], [Vector3(5.6, 0.0, 0.0), 1.6, 3.2]]
	for i: int in screens.size():
		var at: Vector3 = screens[i][0]
		var w: float = screens[i][1]
		var h: float = screens[i][2]
		frame.box(at + Vector3(w * 0.5, h * 0.5, -0.12), Vector3(w + 0.3, h + 0.3, 0.2), Color(0.1, 0.1, 0.11))
		CultFeed.screen(feed, at + Vector3(0, 0, 0.001), Vector3(w, 0, 0), Vector3(0, h, 0), 1.0, i)
	batch.commit(self)
	var camera := Camera3D.new()
	camera.position = Vector3(0.2, 2.0, 11.5)
	camera.fov = 60.0
	add_child(camera)
	camera.look_at(Vector3(0.2, 1.6, 0.0))
	camera.make_current()
