class_name OutfitPreview
extends Control
## The runner wearing an outfit (GDD §8, "Cosmetics": the shop shows a preview of each outfit, owner, October 18,
## 2026): a PlayerAvatar built for `outfit_id`, with no power-ups on, on a small lit stage (OutfitStage), shown as a
## picture. Echo's own look is `PlayerOutfits.ECHO`.
##
## At rest it is a still of the runner in a run pose turned three-quarters to the camera: a texture OutfitStills
## draws once per outfit and size for the whole session, so a preview costs no viewport and no avatar while it
## stands still. The still is asked for only once the preview is on show or about to be (inside a ScrollContainer: within
## VIEW_MARGIN of its view), so a shop opened on its power-ups draws no picture for cards nobody has scrolled to.
## `set_live(true)` makes it run in place and turn slowly: it builds its own stage (one avatar, one viewport drawn every
## frame, the one cost beyond the stills; the shop does it for the one card the pointer or the focus is on) and
## `set_live(false)` goes back to the still. The stopped stage is kept for the next time, but only one at a time across
## previews (the most recent): another preview stopping frees the older one.
##
## Usage: `var p := OutfitPreview.new(); p.outfit_id = &"rex"; p.custom_minimum_size = Vector2(116, 150)`, then
## `p.set_live(true)` while it should move. `stage` is the live stage (null until the first `set_live(true)`).

## The render's size in pixels is the control's size times the screen's scale, no more than this: a phone's dense screen
## doesn't make the render dearer than a desktop's.
const MAX_PIXEL_SCALE: float = 2.0
const MIN_PIXELS: int = 16
## A picture that arrives after the card is on show fades in over this long (seconds).
const FADE_IN: float = 0.15
## How far past the edge of its scroll view (as a fraction of the view's height, above and below) a preview still counts as
## about to be on show: its picture is asked for a moment before the card scrolls in.
const VIEW_MARGIN: float = 0.2

## The outfit shown: an id from data/shop/catalog.json, or PlayerOutfits.ECHO (any other id is Echo's own look).
var outfit_id: StringName = PlayerOutfits.ECHO:
	set = set_outfit_id

## The live stage, built on the first `set_live(true)`.
var stage: OutfitStage

## The preview whose stopped stage is the one kept (see the header).
static var _parked: WeakRef

var _image: TextureRect
var _live: bool = false
var _fit_queued: bool = false
var _check_queued: bool = false
var _check_dirty: bool = false
var _pixels: Vector2i = Vector2i.ZERO
## The picture asked for or shown for the current outfit and size ("" before any).
var _requested_key: String = ""
## The picture at rest (null until OutfitStills has it; where nothing draws, always null).
var _still: Texture2D
var _scroll: ScrollContainer
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
	_scroll = _scroll_above()
	if _scroll != null:
		var bar: VScrollBar = _scroll.get_v_scroll_bar()
		if not bar.value_changed.is_connected(_check_view):
			bar.value_changed.connect(_check_view)
		if not bar.changed.is_connected(_check_view):
			bar.changed.connect(_check_view)


func _ready() -> void:
	_fit()


func _exit_tree() -> void:
	if get_tree().root.size_changed.is_connected(_fit):
		get_tree().root.size_changed.disconnect(_fit)
	if _scroll != null and is_instance_valid(_scroll):
		var bar: VScrollBar = _scroll.get_v_scroll_bar()
		if bar.value_changed.is_connected(_check_view):
			bar.value_changed.disconnect(_check_view)
		if bar.changed.is_connected(_check_view):
			bar.changed.disconnect(_check_view)
	_scroll = null


func set_outfit_id(id: StringName) -> void:
	id = PlayerOutfits.resolve(id)
	if id == outfit_id:
		return
	outfit_id = id
	_still = null
	_requested_key = ""
	_image.texture = null
	if stage != null:
		stage.dress(id)
		stage.draw_once()
	_check_view()


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
			_park()
		if _still != null:
			_image.texture = _still


## True while the stage is drawn every frame (live): the one cost beyond the stills.
func is_rendering() -> bool:
	return stage != null and stage.is_drawing()


## Frees the stopped stage (never a live one). If its last frame was the picture on show, the still takes its place.
func release_stage() -> void:
	if stage == null or _live:
		return
	if _image.texture == stage.get_texture():
		_image.texture = _still
	stage.queue_free()
	stage = null


## OutfitStills asks whether this preview still wants the picture `key` (OutfitStills.key_for): a preview that changed
## its outfit or its size since it asked doesn't.
func wants(key: String) -> bool:
	return is_inside_tree() and key == OutfitStills.key_for(outfit_id, _pixels)


## OutfitStills hands over the picture `key` of the outfit at rest (null where nothing could be drawn). It comes late, after
## the card was on show without it, so it fades in.
func still_ready(key: String, texture: Texture2D) -> void:
	if key != OutfitStills.key_for(outfit_id, _pixels):
		return
	_still = texture
	if texture == null or _live:
		return
	_show_still(texture, _image.texture == null and is_visible_in_tree())


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
	if pixels != _pixels:
		_pixels = pixels
		if stage != null:
			stage.size = pixels
			stage.draw_once()
		_still = null
		_requested_key = ""
	_check_view()


## Asks for the still when the preview is on show or about to be. It waits a frame first: the cards are laid out a frame after
## they are made, and where they stand now says nothing about where they will. A call that comes while one is waiting makes it
## look once more after the frame it is in, so no change (a scroll in the very frame the check ran) goes unseen.
func _check_view(_value: float = 0.0) -> void:
	_check_dirty = true
	if _check_queued or not is_inside_tree():
		return
	_check_queued = true
	while _check_dirty:
		_check_dirty = false
		await get_tree().process_frame
		if not is_inside_tree():
			break
		_ask_for_still()
	_check_queued = false


func _ask_for_still() -> void:
	if _pixels == Vector2i.ZERO:
		return
	var key: String = OutfitStills.key_for(outfit_id, _pixels)
	if key == _requested_key:
		return
	var kept: Texture2D = OutfitStills.cached(outfit_id, _pixels)
	if kept != null:
		_requested_key = key
		_still = kept
		if not _live:
			_show_still(kept, false)
	elif _near_view():
		_requested_key = key
		OutfitStills.request(outfit_id, _pixels, self)


## True if the preview is inside its scroll view, or within VIEW_MARGIN of it (always, where there is no scroll area).
func _near_view() -> bool:
	if _scroll == null:
		return true
	if not _scroll.is_visible_in_tree():
		return false
	var view: Rect2 = _scroll.get_global_rect()
	var margin: float = view.size.y * VIEW_MARGIN
	return view.grow_individual(0.0, margin, 0.0, margin).intersects(get_global_rect())


func _scroll_above() -> ScrollContainer:
	var node: Node = get_parent()
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


func _show_still(texture: Texture2D, fade: bool) -> void:
	_image.texture = texture
	if fade:
		if _fade != null:
			_fade.kill()
		_image.modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(_image, "modulate:a", 1.0, FADE_IN)
	else:
		_image.modulate.a = 1.0


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


## Only the most recent stopped stage is kept: the one that was kept before is freed.
func _park() -> void:
	if _parked != null:
		var other: OutfitPreview = _parked.get_ref() as OutfitPreview
		if other != null and other != self:
			other.release_stage()
	_parked = weakref(self)
