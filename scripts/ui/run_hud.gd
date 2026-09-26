class_name RunHud
extends CanvasLayer
## The in-game display (OPEN_QUESTIONS §5 leaves its contents open; placeholder): score, credits,
## a level progress bar, the protection the player carries, bonus pop-ups, a centre message, and a
## pause button for touch screens. The themed HUD (scripts/ui/widgets) replaces this look.

signal pause_pressed

var world: RunWorld
var context: RunContext

var _score: Label
var _credits: Label
var _items: Label
var _message: Label
var _progress: ProgressBar
var _popups: VBoxContainer
var _pause: Button


func _ready() -> void:
	layer = 5
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_progress.custom_minimum_size = Vector2(420.0, 10.0)
	_progress.position = Vector2(-210.0, 14.0)
	add_child(_progress)

	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -300.0
	right.offset_right = -84.0
	right.offset_top = 10.0
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(right)
	_score = _label(right, 30, HORIZONTAL_ALIGNMENT_RIGHT)
	_credits = _label(right, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_popups = VBoxContainer.new()
	right.add_child(_popups)

	_items = _label(self, 18, HORIZONTAL_ALIGNMENT_LEFT)
	_items.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_items.offset_left = 16.0
	_items.offset_top = -40.0

	_message = _label(self, 40, HORIZONTAL_ALIGNMENT_CENTER)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.grow_vertical = Control.GROW_DIRECTION_BOTH

	_pause = Button.new()
	_pause.text = "II"
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.custom_minimum_size = Vector2(56.0, 56.0)
	_pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause.offset_left = -70.0
	_pause.offset_top = 10.0
	_pause.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(_pause)


func bind(p_world: RunWorld, p_context: RunContext) -> void:
	world = p_world
	context = p_context
	world.score.bonus_awarded.connect(_on_bonus)
	set_message("")


func set_message(text: String) -> void:
	_message.text = text


func _process(_delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.player == null:
		return
	_score.text = "%d" % world.score.score
	_credits.text = "%d credits" % world.score.credits
	_progress.value = clampf(world.player.distance / maxf(world.layout.length, 1.0), 0.0, 1.0) * 100.0
	var p: Player = world.player
	var parts: PackedStringArray = []
	if p.armor > 0:
		parts.append("ARMOR")
	if p.shield > 0:
		parts.append("SHIELD")
	if p.grapples > 0:
		parts.append("GRAPPLE")
	if p.claws:
		parts.append("CLAWS")
	if world.score.multiplier > 1.0:
		parts.append("x%.1f" % world.score.multiplier)
	_items.text = "   ".join(parts)


func _on_bonus(label: String, points: int) -> void:
	var l := _label(_popups, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	l.text = "%s +%d" % [label, points]
	var tween := l.create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(l, "modulate:a", 0.0, 0.4)
	tween.tween_callback(l.queue_free)


func _label(parent: Node, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 5)
	l.horizontal_alignment = align
	parent.add_child(l)
	return l
