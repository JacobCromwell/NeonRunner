class_name OutfitPreview
extends Control
## The runner wearing an outfit (GDD §8, "Cosmetics": the shop shows a preview of each outfit, owner, October 18,
## 2026): a PlayerAvatar built for `outfit_id`, with no power-ups on, on a small lit stage (OutfitStage), shown as a
## picture. Echo's own look is `PlayerOutfits.ECHO`.
##
## At rest it is a still of the runner in a run pose turned three-quarters to the camera: a texture OutfitStills
## draws once per outfit and size for the whole session, so a preview costs no viewport and no avatar while it
## stands still. `set_live(true)` makes it run in place and turn slowly: it builds its own stage the first time (one
## avatar, one viewport drawn every frame, the one cost beyond the stills; the shop does it for the one card the pointer
## or the focus is on) and `set_live(false)` goes back to the still (the stage stays, not drawn, for the next time).
##
## Usage: `var p := OutfitPreview.new(); p.outfit_id = &"rex"; p.custom_minimum_size = Vector2(116, 150)`, then
## `p.set_live(true)` while it should move. `stage` is the live stage (null until the first `set_live(true)`).

## The render's size in pixels is the control's size times the screen's scale, no more than this: a phone's dense screen
## doesn't make the render dearer than a desktop's.
const MAX_PIXEL_SCALE: float = 2.0
const MIN_PIXELS: int = 16
## A picture that arrives after the card is on show fades in over this long (seconds).
const FADE_IN: float = 0.15

## The outfit shown: an id from data/shop/catalog.json, or PlayerOutfits.ECHO (any other id is Echo's own look).
var outfit_id: StringName = PlayerOutfits.ECHO:
	set = set_outfit_id

## The live stage, built on the first `set_live(true)`.
var stage: OutfitStage

var _image: TextureRect
var _live: bool = false
var _fit_queued: bool = false
var _pixels: Vector2i = Vector2i.ZERO
## The picture at rest (null until OutfitStills has it; where nothing draws, always null).
var _still: Texture2D
var _fade: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_image = TextureRect.new()
	_image.name = "Picture"
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_image)
	resized.connect(_fit)


func _enter_tree() -> void:
	# The render follows the window's scale too (a dense screen, a magnified phone menu).
	if not get_tree().root.size_changed.is_connected(_fit):
		get_tree().root.size_changed.connect(_fit)


func _ready() -> void:
	_fit()


func _exit_tree() -> void:
	if get_tree().root.size_changed.is_connected(_fit):
		get_tree().root.size_changed.disconnect(_fit)


func set_outfit_id(id: StringName) -> void:
	id = PlayerOutfits.resolve(id)
	if id == outfit_id:
		return
	outfit_id = id
	_still = null
	_image.texture = null
	if stage != null:
		stage.dress(id)
		stage.draw_once()
	_request_still()


func is_live() -> bool:
	return _live


## Runs in place and turns, drawn every frame (on); or the still again (off).
func set_live(on: bool) -> void:
	if on == _live:
		return
	_live = on
	if on:
		if stage == null:
			stage = OutfitStage.new()
			stage.size = _pixels if _pixels != Vector2i.ZERO else Vector2i(MIN_PIXELS, MIN_PIXELS)
			add_child(stage)
			stage.dress(outfit_id)
		stage.set_live(true)
		_show_stage_when_drawn()
	else:
		if stage != null:
			stage.set_live(false)
		if _still != null:
			_image.texture = _still


## True while the stage is drawn every frame (live): the one cost beyond the stills.
func is_rendering() -> bool:
	return stage != null and stage.is_drawing()


## OutfitStills asks whether this preview still wants the picture `key` (OutfitStills.key_for): a preview that changed
## its outfit or its size since it asked doesn't.
func wants(key: String) -> bool:
	return is_inside_tree() and key == OutfitStills.key_for(outfit_id, _pixels)


## OutfitStills hands over the picture `key` of the outfit at rest (null where nothing could be drawn).
func still_ready(key: String, texture: Texture2D) -> void:
	if key != OutfitStills.key_for(outfit_id, _pixels):
		return
	_still = texture
	if texture == null or _live:
		return
	var late: bool = _image.texture == null and is_visible_in_tree()
	_image.texture = texture
	if late:
		_fade_in()


## The render's size in pixels for a control of `logical` size on a screen scaled by `scale`.
static func pixel_size_for(logical: Vector2, scale: float) -> Vector2i:
	var s: float = clampf(scale, 0.5, MAX_PIXEL_SCALE)
	return Vector2i(maxi(roundi(logical.x * s), MIN_PIXELS), maxi(roundi(logical.y * s), MIN_PIXELS))


## The render follows the control's size (and the window's scale, so it stays sharp on a dense screen): once, after the
## frame's layout has settled.
func _fit() -> void:
	if not _fit_queued and is_inside_tree():
		_fit_queued = true
		_apply_fit.call_deferred()


func _apply_fit() -> void:
	_fit_queued = false
	if not is_inside_tree() or size.x < 1.0 or size.y < 1.0:
		return
	var scale: float = get_viewport().get_final_transform().get_scale().x
	var pixels: Vector2i = OutfitPreview.pixel_size_for(size, scale)
	if pixels == _pixels:
		return
	_pixels = pixels
	if stage != null:
		stage.size = pixels
		stage.draw_once()
	_still = null
	_request_still()


func _request_still() -> void:
	if _pixels == Vector2i.ZERO or not is_inside_tree():
		return
	OutfitStills.request(outfit_id, _pixels, self)


## The live stage hasn't drawn its first frame when it is built (or turned on again): the still stays until it has,
## a couple of frames on.
func _show_stage_when_drawn() -> void:
	if _image.texture == null or _image.texture == stage.get_texture():
		_image.texture = stage.get_texture()
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if _live and stage != null and is_inside_tree():
		_image.texture = stage.get_texture()


func _fade_in() -> void:
	if _fade != null:
		_fade.kill()
	_image.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_image, "modulate:a", 1.0, FADE_IN)
