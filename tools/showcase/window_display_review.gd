extends Node3D
## The shop windows' ad screens and posters (task L10; MeshKit.PAT_WINDOW_AD, PAT_WINDOW_POSTER) up close, for visual
## review: a row of ad screens (each its own seed, so each plays its own ads and flashes the cult's emblem at its own
## moment), under a row of the four poster kinds. Render a stretch of it (frame = seconds x fps):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/l10/f.png --quit-after 300 res://tools/showcase/window_display_review.tscn -- --flash=6
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options (after the --):
##   --skin=marketplace|casino   the skin whose solid material and palettes draw them (default marketplace)
##   --reduced                   Settings > Reduced flashing on (the emblem fades slowly and stays up a while)
##   --flash=S                   every screen flashes the emblem every S seconds (default: the skin's 14 to 26 s),
##                               to find the flash in a short render
##   --seeds=N                   how many ad screens (default 6)
##   --view=wide|close|oblique|posters   the whole row (default), the first screen filling the frame, from the side as
##                               a window's is seen from the lanes, or the posters

const SIZE := Vector2(1.8, 1.0)


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var skin_name: String = "marketplace"
	var flash: float = 0.0
	var count: int = 6
	var close: bool = false
	var posters: bool = false
	var oblique: bool = false
	for a: String in args:
		if a.begins_with("--skin="):
			skin_name = a.get_slice("=", 1)
		elif a.begins_with("--flash="):
			flash = float(a.get_slice("=", 1))
		elif a.begins_with("--seeds="):
			count = int(a.get_slice("=", 1))
		elif a == "--view=close":
			close = true
		elif a == "--view=posters":
			posters = true
		elif a == "--view=oblique":
			oblique = true
	if args.has("--reduced"):
		Settings.flashing_reduced = true
		RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var skin := load("res://data/skins/%s_skin.tres" % skin_name) as MarketplaceSkin
	var solid: ShaderMaterial = skin.solid_material()
	if flash > 0.0:
		solid.set_shader_parameter(&"wd_flash_period", Vector2(flash, flash))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.17, 0.15)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	env.environment.glow_intensity = skin.glow_intensity
	env.environment.glow_hdr_threshold = skin.glow_threshold
	add_child(env)
	var batch := MeshBatch.new()
	var layer: MeshLayer = batch.layer(solid)
	var frame: Color = skin.window_frame_color
	var x: float = 0.0
	for i: int in count:
		var w: float = SIZE.x * 1.0
		var origin := Vector3(x, 1.4, 0.0)
		layer.box(origin + Vector3(w * 0.5, 0.5, -0.05), Vector3(w + 0.1, 1.1, 0.08), frame)
		layer.rect(origin, Vector3(w, 0, 0), Vector3(0, 1.0, 0), skin.window_ad_colors[0],
			skin.window_screen_glow, MeshKit.PAT_WINDOW_AD, Vector2.ZERO, Vector2(SIZE.x, 1.0), MeshKit.window_param(7 + i * 131, 0, SIZE.x))
		x += w + 0.25
	var kinds: Array = [[MeshKit.WINDOW_SIGN, Vector2(0.5, 4.2)], [MeshKit.WINDOW_SALE, Vector2(1.0, 1.0)],
		[MeshKit.WINDOW_MENU, Vector2(1.0, 0.7)], [MeshKit.WINDOW_PRODUCT, Vector2(1.0, 1.4)]]
	var px: float = 0.0
	var n: int = 0
	for round_i: int in 2:
		for k: Array in kinds:
			var h: float = float(k[1].x)
			var aspect: float = float(k[1].y)
			var w: float = h * aspect
			var base: Color = skin.window_poster_colors[(n * 5 + round_i) % skin.window_poster_colors.size()]
			var origin := Vector3(px, -0.1 - (0.0 if round_i == 0 else 1.2) - (0.0 if h > 0.6 else 0.25), 0.0)
			layer.box(origin + Vector3(w * 0.5, h * 0.5, -0.05), Vector3(w + 0.1, h + 0.1, 0.08), frame)
			layer.rect(origin, Vector3(w, 0, 0), Vector3(0, h, 0), base, 0.0, MeshKit.PAT_WINDOW_POSTER,
				Vector2.ZERO, Vector2(aspect, 1.0), MeshKit.window_param(11 + n * 37, int(k[0]), aspect))
			px += w + 0.25
			n += 1
	batch.commit(self)
	var camera := Camera3D.new()
	if close:
		camera.position = Vector3(SIZE.x * 0.5, 1.9, 3.0)
		camera.fov = 40.0
	elif oblique:
		camera.position = Vector3(SIZE.x * 0.5 + 5.0, 1.9, 5.5)
		camera.fov = 40.0
	elif posters:
		camera.position = Vector3(4.2, -0.5, 6.2)
		camera.fov = 50.0
	else:
		camera.position = Vector3(x * 0.5 - 0.1, 0.9, 11.5)
		camera.fov = 50.0
	add_child(camera)
	camera.look_at(Vector3(SIZE.x * 0.5 if oblique else camera.position.x, 1.9 if (close or oblique) else (-0.5 if posters else 0.6), 0.0))
	camera.make_current()
