class_name LoadingCardScreen
extends Control
## A loading card (GDD §11, Loading cards; owner, October 11, 2026; task PERF3b): the full-screen picture the
## game shows while a level or a cinematic loads (in a browser its shaders compile meanwhile, a minute or more
## on Windows), with the level's or zone's name and a progress bar. The level's own card if it has one
## (LevelConfig.loading_card), else its zone's (ZoneDef.loading_card), else a plain card on the menu backdrop
## (card_path_for). It shows for at least PerformanceTuning.loading_card_min_seconds, so a quick load never
## flashes it, and emits `done` once the load is through (progress reaches 1) and that time has passed. The
## App puts it on its own layer above everything (LAYER), a cinematic's letterbox and skip button included.

signal done

## The canvas layer the App shows it on: above the screens, the overlays and a cinematic's overlay.
const LAYER: int = 100
## How much of the screen's height the dark shade at the bottom covers (the name and the bar sit on it; the
## cards keep their bottom fifth calm for them).
const SHADE: float = 0.38

## The picture (a loading card's path; empty: the plain card), the big name and the line under it.
var card_path: String = ""
var title: String = ""
var subtitle: String = ""
## The load's progress, 0 to 1 (LevelRun.load_progress, ShaderWarmup.progress). Unset: nothing to wait for.
var progress: Callable
var picture: TextureRect
var bar: ProgressBar
var _shown_for: float = 0.0
var _min_seconds: float = 1.0
var _done: bool = false


## The card a level or cinematic of `zone` shows: the level's own (`config`, if any), else the zone's; empty
## when neither has one that exists (a plain card).
static func card_path_for(zone: ZoneDef, config: LevelConfig) -> String:
	for path: String in [config.loading_card if config != null else "", zone.loading_card if zone != null else ""]:
		if path != "" and ResourceLoader.exists(path):
			return path
	return ""


func _ready() -> void:
	name = "LoadingCard"
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_min_seconds = PerformanceTuning.load_default().loading_card_min_seconds
	var style: UiStyle = UiTheme.style()
	var back := ColorRect.new()
	back.color = style.backdrop_bottom
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	if card_path != "":
		picture = TextureRect.new()
		picture.texture = load(card_path) as Texture2D
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(picture)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(style.backdrop_bottom, 0.0))
	gradient.set_color(1, Color(style.backdrop_bottom, 0.92))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0.5, 0.0)
	shade_texture.fill_to = Vector2(0.5, 1.0)
	var shade := TextureRect.new()
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 1.0 - SHADE
	shade.anchor_bottom = 1.0
	add_child(shade)
	var column := VBoxContainer.new()
	column.anchor_left = 0.08
	column.anchor_right = 0.92
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_bottom = -UiTheme.px(36)
	column.add_theme_constant_override(&"separation", UiTheme.px(8))
	add_child(column)
	if title != "":
		column.add_child(ScreenBase.make_label(title.to_upper(), UiTheme.TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	if subtitle != "":
		column.add_child(ScreenBase.make_label(subtitle, UiTheme.SUBHEADING, HORIZONTAL_ALIGNMENT_CENTER))
	bar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = UiTheme.px(10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar)
	_update()


func _process(delta: float) -> void:
	_shown_for += delta
	_update()


## True once it has emitted `done`.
func is_done() -> bool:
	return _done


func _update() -> void:
	var p: float = clampf(float(progress.call()), 0.0, 1.0) if progress.is_valid() else 1.0
	bar.value = p
	if not _done and p >= 1.0 and _shown_for >= _min_seconds:
		_done = true
		done.emit()
