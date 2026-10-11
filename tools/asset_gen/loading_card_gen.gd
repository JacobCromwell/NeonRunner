extends SceneTree
## Renders the zones' loading cards (the full-screen picture shown while a level or a cinematic loads, with the
## zone's name and a progress bar over its bottom part): one 1920x1080 PNG per zone in
## assets/sprites/loading_cards/<zone>.png, plus a copy in build/loading_cards/ (git-ignored) for review.
## Nothing here runs in the game: each card is a 3D scene built from the game's own models (the runner's
## PlayerAvatar, the cyborgs' CyborgBody, the Enforcer Truck, the heli drone, the shared FireballPool fireball)
## on the zone's own skin (CineStage), staged by that zone's composition script in tools/asset_gen/loading_cards/
## (<zone>_card.gd), frozen at one moment and grabbed from a SubViewport (as citizen_sheet_gen.gd bakes its
## sheets). Add a zone by writing its composition and listing it in CARDS.
##
## A composition script (extends RefCounted) offers:
##   compose(host: Node3D, ctx: Dictionary) -> void   builds the scene under `host` (a Node3D in the SubViewport):
##                                                    its models, camera (made current) and lights. `ctx` has
##                                                    "size" (Vector2i), "preview" (bool) and "tune" (the
##                                                    --tune numbers, a Dictionary).
##   settle_frames() -> int                            frames to let the renderer run before the grab.
##   camera() -> Camera3D, subjects() -> Dictionary    what the picture is about (name -> Node3D, or [world
##                                                    centre, radius] for a fireball): the generator projects
##                                                    each through the camera and checks it lies in the safe
##                                                    zone, below.
##
## Regenerate (it renders real 3D frames, so it needs a display: Xvfb with Mesa's software GL works, on the
## Compatibility renderer, which is what the web and low-end Android run; a GPU window renders the same scene;
## `export GODOT=/path/to/the/pinned/godot` first, or put the path in the command):
##   xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-method gl_compatibility \
##     -s res://tools/asset_gen/loading_card_gen.gd -- --only=city
## It writes assets/sprites/loading_cards/city.png (and a copy in build/loading_cards/city.png), and reports where
## each subject lands against the safe zone below (exit code 1 if one is outside it). A project import
## (tools/godot.sh import) then refreshes the .png.import beside it.
## Options (after --):
##   --only=a,b   just these zones (default: every zone in CARDS)
##   --preview    half-size, quick look: writes only build/loading_cards/<zone>_preview.png, never the asset
##   --tune=k:v,k:v   overrides numbers of the composition (the card script's LOOK), for an experiment; the result
##                goes to build/loading_cards/<zone>_tuned.png only, never the asset
## Under software GL (Mesa llvmpipe) a card takes about 4 s to render, 8 s with Godot's start-up. The result is the
## same every run, bit for bit (the models are posed by explicit steps, the fireball is seeded and aged by hand,
## and the engine's clock is stopped before the first frame, so nothing depends on how long a frame took).

const SIZE := Vector2i(1920, 1080)
const OUT_DIR: String = "res://assets/sprites/loading_cards"
const REVIEW_DIR: String = "res://build/loading_cards"
const CARDS: Dictionary = {
	"city": preload("res://tools/asset_gen/loading_cards/city_card.gd"),
}
## What the screen draws over a card (it shows it "cover"-scaled: a phone crops its top and bottom, a 4:3 tablet its
## sides) leaves this much of the frame for the subjects, as shares of its width and height: the central 75% of the
## width, the central 80% of the height, and none in the bottom 22%, kept calm for the zone's name and progress bar.
const SAFE_X := Vector2(0.125, 0.875)
const SAFE_Y := Vector2(0.10, 0.78)
## The bottom of the frame is kept calm and dark for the zone's name and the progress bar (the screen builds them
## over it): a shade that starts here (share of the height from the top) and reaches SHADE_ALPHA at the foot.
const SHADE_FROM: float = 0.64
const SHADE_ALPHA: float = 0.86
## A soft vignette over the whole frame (alpha at the corners).
const VIGNETTE_ALPHA: float = 0.38

var _viewport: SubViewport
var _host: Node3D
var _tune: Dictionary = {}
var _outside: int = 0


func _initialize() -> void:
	# The clock stops before the first frame: the scene is posed by explicit steps, and the frames it takes to draw
	# (seconds each under software GL) must age nothing: not the fireball's particles, and not the shaders' TIME (the
	# cult feed's screens animate with it), which would otherwise hold whatever the first frame's length made it.
	Engine.time_scale = 0.0
	var only: PackedStringArray = []
	var preview: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",", false)
		elif arg == "--preview":
			preview = true
		elif arg.begins_with("--tune="):
			for pair: String in arg.get_slice("=", 1).split(",", false):
				_tune[pair.get_slice(":", 0)] = float(pair.get_slice(":", 1))
	# The root joins the tree on the first frame; the models read their global transforms while they are posed.
	await process_frame
	var started: int = Time.get_ticks_msec()
	var done: int = 0
	for zone: String in CARDS:
		if not only.is_empty() and not only.has(zone):
			continue
		await _render(zone, preview)
		done += 1
	if done == 0:
		push_error("loading_card_gen: no card to render (--only=%s; known: %s)" % [",".join(only), ", ".join(CARDS.keys())])
		quit(1)
		return
	print("Rendered %d loading card(s) in %.1f s" % [done, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if _outside > 0 else 0)


func _render(zone: String, preview: bool) -> void:
	var size: Vector2i = SIZE / 2 if preview else SIZE
	_build_viewport(size)
	var card: RefCounted = (CARDS[zone] as GDScript).new()
	card.compose(_host, {"size": size, "preview": preview, "tune": _tune})
	_add_shade(size)
	for i: int in int(card.call("settle_frames")):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	_check_safe_zone(card, size)
	if preview or not _tune.is_empty():
		_save(image, REVIEW_DIR, zone + ("_preview" if preview else "_tuned"))
	else:
		_save(image, OUT_DIR, zone)
		_save(image, REVIEW_DIR, zone)
	_viewport.queue_free()
	await process_frame


func _build_viewport(size: Vector2i) -> void:
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.own_world_3d = true
	get_root().add_child(_viewport)
	_host = Node3D.new()
	_host.name = "Card"
	_viewport.add_child(_host)


## Projects each subject through the card's camera and reports where it lands, as shares of the frame; a subject
## outside the safe zone is an error (the files are still written, to look at, but the run exits 1).
func _check_safe_zone(card: RefCounted, size: Vector2i) -> void:
	var camera: Camera3D = card.call("camera")
	var subjects: Dictionary = card.call("subjects")
	var frame := Vector2(size)
	print("  safe zone: x %.1f-%.1f%%, y %.1f-%.1f%% (the bottom %.0f%% is for the screen's text)" % [SAFE_X.x * 100.0,
		SAFE_X.y * 100.0, SAFE_Y.x * 100.0, SAFE_Y.y * 100.0, (1.0 - SAFE_Y.y) * 100.0])
	for subject: String in subjects:
		var rect: Rect2 = _screen_rect(camera, subjects[subject])
		if rect.size == Vector2.ZERO:
			print("    %-9s not in view" % subject)
			_outside += 1
			continue
		var x0: float = rect.position.x / frame.x
		var x1: float = rect.end.x / frame.x
		var y0: float = rect.position.y / frame.y
		var y1: float = rect.end.y / frame.y
		var inside: bool = x0 >= SAFE_X.x and x1 <= SAFE_X.y and y0 >= SAFE_Y.x and y1 <= SAFE_Y.y
		print("    %-9s x %3d-%3d%%  y %3d-%3d%%  %s" % [subject, roundi(x0 * 100.0), roundi(x1 * 100.0),
			roundi(y0 * 100.0), roundi(y1 * 100.0), "ok" if inside else "OUTSIDE"])
		if not inside:
			_outside += 1
			printerr("loading_card_gen: %s is outside the safe zone" % subject)


## The screen rectangle of what a subject draws (a Node3D's visible meshes, or a fireball's [centre, radius] as a
## square of its radius), in pixels; empty if none of it is in front of the camera.
func _screen_rect(camera: Camera3D, subject: Variant) -> Rect2:
	var points: Array[Vector3] = []
	if subject is Array:
		var center: Vector3 = subject[0]
		var radius: float = subject[1]
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				points.append(center + camera.global_transform.basis * Vector3(sx, sy, 0.0) * radius)
	else:
		for node: Node in (subject as Node3D).find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var box: AABB = mi.get_aabb()
			for i: int in 8:
				points.append(mi.global_transform * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)))
	var rect := Rect2()
	var first: bool = true
	for p: Vector3 in points:
		if camera.is_position_behind(p):
			continue
		var s: Vector2 = camera.unproject_position(p)
		rect = Rect2(s, Vector2.ZERO) if first else rect.expand(s)
		first = false
	return rect


## The calm bottom and the soft vignette: two 2D gradients over the 3D picture.
func _add_shade(size: Vector2i) -> void:
	var layer := CanvasLayer.new()
	_viewport.add_child(layer)
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, SHADE_FROM, lerpf(SHADE_FROM, 1.0, 0.5), 1.0])
	shade.colors = PackedColorArray([Color(0.02, 0.0, 0.05, 0.0), Color(0.02, 0.0, 0.05, 0.0),
		Color(0.02, 0.0, 0.05, SHADE_ALPHA * 0.55), Color(0.02, 0.0, 0.05, SHADE_ALPHA)])
	var tex := GradientTexture2D.new()
	tex.gradient = shade
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 4
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2(size)
	layer.add_child(rect)
	var vignette := Gradient.new()
	vignette.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	vignette.colors = PackedColorArray([Color(0.02, 0.0, 0.05, 0.0), Color(0.02, 0.0, 0.05, 0.0), Color(0.02, 0.0, 0.05, VIGNETTE_ALPHA)])
	var vtex := GradientTexture2D.new()
	vtex.gradient = vignette
	vtex.fill = GradientTexture2D.FILL_RADIAL
	vtex.fill_from = Vector2(0.5, 0.5)
	vtex.fill_to = Vector2(1.05, 0.95)
	vtex.width = 256
	vtex.height = 256
	var vrect := TextureRect.new()
	vrect.texture = vtex
	vrect.stretch_mode = TextureRect.STRETCH_SCALE
	vrect.size = Vector2(size)
	layer.add_child(vrect)


func _save(image: Image, dir: String, file: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path: String = "%s/%s.png" % [dir, file]
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("loading_card_gen: could not write %s (%s)" % [path, error_string(err)])
		return
	print("  %s (%dx%d)" % [path, image.get_width(), image.get_height()])
