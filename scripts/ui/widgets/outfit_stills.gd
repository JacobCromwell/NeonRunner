class_name OutfitStills
extends RefCounted
## The pictures of the outfits the shop's previews show at rest (OutfitPreview; GDD §8, "Cosmetics"): each outfit drawn
## once on an OutfitStage, read back as a texture and kept for the rest of the session, so the shop opens with no
## runner built and no viewport drawn: the second visit (the shop is shown after every death) costs nothing, and
## the first one builds one outfit at a time, a few frames apart, instead of six at once on the frame the shop opens.
##
## `request(id, pixels, preview)` hands the preview its picture (`preview.still_ready(key, texture)`) as soon as it is
## there, at once if it was drawn before; asks for the same picture twice draw it once, and a picture no preview
## still `wants(key)` by its turn isn't drawn at all. One stage serves the whole
## queue and goes when the queue is empty. A picture is keyed by outfit and pixel size, so a window of another size
## draws its own. Where nothing draws (the headless tests), the jobs still run and finish with no texture.

## How many pictures are kept; past it the oldest go (a few window sizes of six outfits).
const MAX_STILLS: int = 36
## Frames the shop gets between one picture and the next (each takes a few dozen milliseconds on a desktop: the outfit's
## meshes, the avatar, the draw and the read-back), so the menu answers input while the pictures come in.
const FRAMES_BETWEEN: int = 3

## Keys of the pictures drawn this session, in order (the tests read it).
static var drawn: Array[String] = []

static var _textures: Dictionary = {}
static var _waiting: Dictionary = {}
static var _jobs: Dictionary = {}
static var _queue: Array[String] = []
static var _running: bool = false


static func key_for(id: StringName, pixels: Vector2i) -> String:
	return "%s@%dx%d" % [id, pixels.x, pixels.y]


## The kept picture of `id` at `pixels`, or null.
static func cached(id: StringName, pixels: Vector2i) -> Texture2D:
	return _textures.get(key_for(id, pixels))


## True while pictures are waiting to be drawn or being drawn.
static func is_busy() -> bool:
	return _running or not _queue.is_empty()


## Asks for the picture of `id` at `pixels`: `preview.still_ready(key, texture)` is called with it (texture null where
## nothing could be drawn). A picture already kept is handed over at once.
static func request(id: StringName, pixels: Vector2i, preview: Object) -> void:
	var key: String = key_for(id, pixels)
	var kept: Texture2D = _textures.get(key)
	if kept != null:
		preview.call(&"still_ready", key, kept)
		return
	if not _waiting.has(key):
		_waiting[key] = []
		_jobs[key] = {"id": id, "pixels": pixels}
		_queue.append(key)
	(_waiting[key] as Array).append(weakref(preview))
	if not _running:
		_run()


## Forgets every picture (a tool that changes an outfit's pieces at runtime; the tests).
static func clear() -> void:
	_textures.clear()
	drawn.clear()


static func _run() -> void:
	_running = true
	var tree := Engine.get_main_loop() as SceneTree
	var stage: OutfitStage = null
	var can_draw: bool = DisplayServer.get_name() != "headless"
	while not _queue.is_empty():
		var key: String = _queue.pop_front()
		# A picture nobody wants (a size the window has left, a shop closed) costs no wait and no draw, so a burst of stale
		# requests never holds up the ones that count.
		if not _wanted(key):
			_forget(key)
			continue
		for i: int in FRAMES_BETWEEN:
			await tree.process_frame
		if not _wanted(key):
			_forget(key)
			continue
		var job: Dictionary = _jobs[key]
		_jobs.erase(key)
		var texture: Texture2D = null
		if can_draw:
			if stage == null:
				stage = OutfitStage.new()
				tree.root.add_child(stage)
			stage.size = job["pixels"]
			stage.dress(job["id"])
			stage.draw_once()
			# The stage draws at the end of this frame, and the picture is there once it has.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image: Image = stage.get_texture().get_image()
			if image != null and not image.is_empty():
				texture = ImageTexture.create_from_image(image)
		if texture != null:
			_keep(key, texture)
		drawn.append(key)
		for ref: Variant in _waiting[key]:
			var preview: Object = (ref as WeakRef).get_ref()
			if preview != null:
				preview.call(&"still_ready", key, texture)
		_waiting.erase(key)
	if stage != null:
		stage.queue_free()
	_running = false


static func _forget(key: String) -> void:
	_jobs.erase(key)
	_waiting.erase(key)


## True if some preview waiting for the picture still wants it.
static func _wanted(key: String) -> bool:
	for ref: Variant in _waiting[key]:
		var preview: Object = (ref as WeakRef).get_ref()
		if preview != null and preview.call(&"wants", key):
			return true
	return false


static func _keep(key: String, texture: Texture2D) -> void:
	if _textures.size() >= MAX_STILLS:
		_textures.erase(_textures.keys()[0])
	_textures[key] = texture
