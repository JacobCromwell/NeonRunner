class_name RunHud
extends CanvasLayer
## The in-game display on the kit's HUD theme (OPEN_QUESTIONS §5 leaves its contents open): the
## score and the run's credits top right, with bonus pop-ups and the ramp multiplier beside them;
## level progress top centre, or in a boss fight the boss's health bar with its phase markers
## (BossBar, GDD §10); the protection the player carries and the power-ups bottom left; a centre
## message; first-encounter hints under the progress meter; and a pause button on touch screens.
## Everything stays inside the screen's safe area. In quick play, where the debug HUD fills the
## top left, the progress meter moves into the right column and the icons sit above the debug help.
## Power-ups report themselves: if world.powerups has hud_state(), each entry
## {id, icon, tier, ready 0–1, active, charges} gets an icon; otherwise the HUD shows the player's
## own charges (and claws, which have no cooldown). A pickup taken during the run (GDD §10) flashes
## its item's icon, which joins the protections in its place if the run didn't bring that item.

signal pause_pressed

## Seconds a bonus pop-up stays before it fades.
const POPUP_TIME: float = 1.1
## Pop-ups shown at once; the oldest goes first.
const MAX_POPUPS: int = 4
## Protections, in HUD order: [loadout id, icon, Player field].
const PROTECTIONS: Array = [[&"armor", &"armor", &"armor"], [&"shield", &"shield", &"shield"],
	[&"grapple", &"grapple", &"grapples"]]
## Power-ups the player triggers with a key: the key shows on the icon (keyboard devices).
const POWERUP_ACTIONS: Dictionary = {&"dash": &"dash", &"slow_time": &"slow_time"}
## Shown when a boss fight reaches its checkpoint (GDD §10).
const CHECKPOINT_TEXT: String = "Checkpoint! A retry starts here."

var world: RunWorld
var context: RunContext

var root: Control
var score_counter: CreditCounter
var credits_counter: CreditCounter
var progress: ProgressMeter
## The boss's health in a boss fight (in the progress meter's place).
var boss_bar: BossBar
var pause_button: NeonButton
## Id (armor, shield, grapple, or a power-up's id) -> its CooldownIcon.
var item_icons: Dictionary = {}

var _frame: Control
var _right: VBoxContainer
var _top_center: VBoxContainer
var _items: HBoxContainer
var _popups: VBoxContainer
var _multiplier: PanelContainer
var _multiplier_label: Label
var _message: Label
var _hint: PanelContainer
var _hint_label: Label
var _hint_tween: Tween
var _score_source: ScoreKeeper
var _pickup_source: PickupField
var _quick: bool = false


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.name = "HudRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(root, true)
	add_child(root)
	_frame = Control.new()
	_frame.name = "SafeFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_frame)
	root.resized.connect(_fit_frame)

	# Top right: score, credits, pop-ups (and the pause button at the corner).
	_right = VBoxContainer.new()
	_right.name = "Score"
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right.add_theme_constant_override(&"separation", 4)
	_frame.add_child(_right)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_END
	top.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_theme_constant_override(&"separation", roundi(UiTheme.px(12)))
	_right.add_child(top)
	_multiplier = PanelContainer.new()
	_multiplier.theme_type_variation = UiTheme.HUD_PANEL
	_multiplier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_multiplier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_multiplier.visible = false
	top.add_child(_multiplier)
	_multiplier_label = _label(UiTheme.HUD_VALUE, HORIZONTAL_ALIGNMENT_CENTER)
	_multiplier_label.add_theme_color_override(&"font_color", UiTheme.style().accent_2.lerp(Color.WHITE, 0.25))
	_multiplier_label.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(22)))
	_multiplier.add_child(_multiplier_label)
	score_counter = CreditCounter.new()
	score_counter.show_icon = false
	score_counter.show_chip = false
	score_counter.pop_on_gain = false
	score_counter.count_time = 0.35
	score_counter.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(34)))
	score_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(score_counter)
	pause_button = NeonButton.make("", NeonButton.Kind.HUD, &"pause")
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.tooltip_text = "Pause"
	pause_button.custom_minimum_size = Vector2.ONE * UiTheme.px(56)
	pause_button.visible = DisplayServer.is_touchscreen_available() or UiTheme.is_touch() or OS.has_feature("web")
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	top.add_child(pause_button)
	credits_counter = CreditCounter.new()
	credits_counter.size_flags_horizontal = Control.SIZE_SHRINK_END
	_right.add_child(credits_counter)
	_popups = VBoxContainer.new()
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popups.size_flags_horizontal = Control.SIZE_SHRINK_END
	_popups.add_theme_constant_override(&"separation", 0)
	_right.add_child(_popups)

	# Top centre: how far through the level.
	_top_center = VBoxContainer.new()
	_top_center.name = "Progress"
	_top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_top_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.add_child(_top_center)
	progress = ProgressMeter.new()
	# DESIGN-TBD: what progress markers stand for (OPEN_QUESTIONS §5); none are shown yet.
	progress.custom_minimum_size.x = UiTheme.px(420)
	_top_center.add_child(progress)
	boss_bar = BossBar.new()
	boss_bar.name = "BossBar"
	boss_bar.custom_minimum_size.x = UiTheme.px(460)
	boss_bar.visible = false
	_top_center.add_child(boss_bar)

	# Bottom left: protection and power-ups.
	_items = HBoxContainer.new()
	_items.name = "Items"
	_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_items.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_items.add_theme_constant_override(&"separation", roundi(UiTheme.px(10)))
	_frame.add_child(_items)

	_message = _label(UiTheme.HUD_VALUE, HORIZONTAL_ALIGNMENT_CENTER)
	_message.name = "Message"
	_message.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(46)))
	_message.add_theme_constant_override(&"outline_size", roundi(UiTheme.px(8)))
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(_message)

	_hint = PanelContainer.new()
	_hint.name = "Hint"
	_hint.theme_type_variation = UiTheme.HUD_PANEL
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_END
	_hint.modulate.a = 0.0
	_frame.add_child(_hint)
	var hint_row := HBoxContainer.new()
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_theme_constant_override(&"separation", 10)
	_hint.add_child(hint_row)
	var hint_icon := NeonIcon.make(&"info", UiTheme.px(22), UiTheme.style().accent)
	hint_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_row.add_child(hint_icon)
	_hint_label = _label(UiTheme.HUD_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_row.add_child(_hint_label)
	_fit_frame()


func bind(p_world: RunWorld, p_context: RunContext) -> void:
	if _score_source != null and is_instance_valid(_score_source):
		if _score_source.changed.is_connected(_on_score_changed):
			_score_source.changed.disconnect(_on_score_changed)
		if _score_source.bonus_awarded.is_connected(_on_bonus):
			_score_source.bonus_awarded.disconnect(_on_bonus)
	if _pickup_source != null and is_instance_valid(_pickup_source) and _pickup_source.collected.is_connected(_on_pickup_collected):
		_pickup_source.collected.disconnect(_on_pickup_collected)
	world = p_world
	context = p_context
	_quick = context != null and context.mode == RunContext.Mode.QUICK and OS.is_debug_build()
	_score_source = world.score
	world.score.changed.connect(_on_score_changed)
	world.score.bonus_awarded.connect(_on_bonus)
	_pickup_source = world.pickups
	if _pickup_source != null:
		_pickup_source.collected.connect(_on_pickup_collected)
	score_counter.set_value(world.score.score, false)
	credits_counter.set_value(world.score.credits, false)
	for child: Node in _popups.get_children():
		child.queue_free()
	_place_progress()
	_bind_boss(BossEncounter.of(world))
	_build_items()
	set_message("")
	_fit_frame()


func set_message(text: String) -> void:
	_message.text = text
	if text != "":
		_message.pivot_offset = _message.size * 0.5
		_message.scale = Vector2(0.85, 0.85)
		_message.create_tween().tween_property(_message, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A first-encounter hint under the progress meter for a few seconds (HintDirector).
func show_hint(text: String, seconds: float = 3.5) -> void:
	_hint_label.text = text
	# One line when it fits, wrapped at a readable width when it doesn't.
	var font: Font = _hint_label.get_theme_font(&"font")
	var font_size: int = _hint_label.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else 400.0
	# Centred, so it keeps as far from the middle as the score column does from the edge.
	var room: float = _frame.size.x - 2.0 * (_right.size.x + UiTheme.px(16)) - UiTheme.px(60)
	_hint_label.custom_minimum_size.x = minf(ceilf(width) + 2.0, clampf(room, UiTheme.px(260), UiTheme.px(560)))
	_place_hint()
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = _hint.create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.15)
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.5)


func hint_text() -> String:
	return _hint_label.text if _hint.modulate.a > 0.0 else ""


func _process(_delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.player == null:
		return
	var p: Player = world.player
	if not boss_bar.visible:
		progress.value = clampf(p.distance / maxf(world.layout.length, 1.0), 0.0, 1.0)
	var mult: float = world.score.multiplier
	_multiplier.visible = mult > 1.0
	if _multiplier.visible:
		_multiplier_label.text = "×%s" % (str(roundi(mult)) if is_equal_approx(mult, roundf(mult)) else "%.1f" % mult)
	for entry: Array in PROTECTIONS:
		var icon: CooldownIcon = item_icons.get(entry[0])
		if icon != null:
			icon.count = int(p.get(entry[2]))
	if world.powerups != null and world.powerups.has_method(&"hud_state"):
		_update_powerups(world.powerups.call(&"hud_state"))


## Protection first (what the loadout brought), then the power-ups.
func _build_items() -> void:
	for child: Node in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	item_icons.clear()
	var p: Player = world.player
	for entry: Array in PROTECTIONS:
		if world.loadout.charge(entry[0]) > 0 or int(p.get(entry[2])) > 0:
			var icon: CooldownIcon = _protection_icon(entry[0])
			icon.count = int(p.get(entry[2]))
	if world.powerups != null and world.powerups.has_method(&"hud_state"):
		_update_powerups(world.powerups.call(&"hud_state"))
	elif p.claws:
		# No power-up controller yet: claws are passive, so they show without a cooldown.
		_add_icon(&"claws", &"claws")


func _update_powerups(states: Array) -> void:
	for state: Variant in states:
		var d: Dictionary = state
		var id := StringName(String(d.get("id", "")))
		if id == &"":
			continue
		var icon: CooldownIcon = item_icons.get(id)
		if icon == null and _protection_order(id) >= 0:
			icon = _protection_icon(id)
		if icon == null:
			icon = _add_icon(id, ShopScreen.icon_for(StringName(String(d.get("icon", id))), int(d.get("tier", 1))))
			if POWERUP_ACTIONS.has(id):
				icon.key_hint = UiTheme.action_text(POWERUP_ACTIONS[id]).to_upper()
		var ready: float = clampf(float(d.get("ready", 1.0)), 0.0, 1.0)
		icon.set_cooldown(1.0 - ready, 1.0)
		icon.active = bool(d.get("active", false))
		icon.count = int(d.get("charges", -1))


func _add_icon(id: StringName, icon_name: StringName) -> CooldownIcon:
	var icon := CooldownIcon.new()
	icon.name = String(id)
	icon.icon_name = icon_name
	_items.add_child(icon)
	item_icons[id] = icon
	return icon


## The icon of a protection (armor, shield or grapple), made if it isn't shown yet: the protections
## come first, in PROTECTIONS order, then the power-ups. Null for anything else.
func _protection_icon(id: StringName) -> CooldownIcon:
	var icon: CooldownIcon = item_icons.get(id)
	var order: int = _protection_order(id)
	if icon != null or order < 0:
		return icon
	icon = _add_icon(id, PROTECTIONS[order][1])
	var before: int = 0
	for other: Array in PROTECTIONS:
		if _protection_order(other[0]) < order and item_icons.has(other[0]):
			before += 1
	_items.move_child(icon, before)
	return icon


## The place of `id` in PROTECTIONS, or -1 if it isn't a protection.
func _protection_order(id: StringName) -> int:
	for i: int in PROTECTIONS.size():
		if PROTECTIONS[i][0] == id:
			return i
	return -1


## A pickup was taken (GDD §10): its item's icon shows, with the charges the player holds now, and
## flashes (also when the player already held all they can).
func _on_pickup_collected(pickup: Pickup, _gained: bool) -> void:
	var icon: CooldownIcon = _protection_icon(pickup.item)
	if icon == null:
		return
	icon.count = world.player.charges_of(pickup.item)
	icon.flash_ready()


func _place_progress() -> void:
	var in_column: bool = progress.get_parent() == _right
	# Endless runs have no end to measure against.
	var show: bool = context == null or context.mode != RunContext.Mode.ENDLESS
	progress.visible = show
	if _quick and not in_column:
		_top_center.remove_child(progress)
		_right.add_child(progress)
		_right.move_child(progress, 2)
		progress.custom_minimum_size.x = UiTheme.px(240)
		progress.size_flags_horizontal = Control.SIZE_SHRINK_END
	elif not _quick and in_column:
		_right.remove_child(progress)
		_top_center.add_child(progress)
		progress.custom_minimum_size.x = UiTheme.px(420)


## A boss fight shows the boss's bar in the progress meter's place (a fight has no distance to
## measure; in quick play it joins the score column, clear of the debug HUD), and says when a
## checkpoint is reached.
func _bind_boss(encounter: BossEncounter) -> void:
	boss_bar.visible = encounter != null
	var in_column: bool = boss_bar.get_parent() == _right
	if _quick and not in_column:
		_top_center.remove_child(boss_bar)
		_right.add_child(boss_bar)
		_right.move_child(boss_bar, 2)
		boss_bar.custom_minimum_size.x = UiTheme.px(300)
		boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	elif not _quick and in_column:
		_right.remove_child(boss_bar)
		_top_center.add_child(boss_bar)
		boss_bar.custom_minimum_size.x = UiTheme.px(460)
		boss_bar.size_flags_horizontal = Control.SIZE_FILL
	if encounter == null:
		boss_bar.encounter = null
		return
	progress.visible = false
	boss_bar.bind(encounter)
	if not _quick:
		encounter.checkpoint_reached.connect(func(_index: int) -> void: show_hint(CHECKPOINT_TEXT))


## Keeps everything inside the safe area plus a margin; in quick play it clears the debug HUD.
func _fit_frame() -> void:
	if _frame == null or not root.is_inside_tree():
		return
	var margin: float = UiTheme.px(16)
	var safe: Vector4 = UiTheme.safe_area_margins(root)
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.offset_left = safe.x + margin
	# Quick play: below the debug HUD's progress bar along the top edge.
	_frame.offset_top = safe.y + margin * 0.75 + (UiTheme.px(14) if _quick else 0.0)
	_frame.offset_right = -(safe.z + margin)
	_frame.offset_bottom = -(safe.w + margin)
	_items.offset_bottom = -UiTheme.px(84) if _quick else 0.0
	_items.offset_top = _items.offset_bottom
	_place_hint()


## Top centre, under the progress meter, clear of the runner and of thumbs on a phone. Zero-size
## offsets, so the chip grows evenly from its anchor.
func _place_hint() -> void:
	_hint.offset_left = 0.0
	_hint.offset_right = 0.0
	# Under the boss bar, which is taller than the progress meter.
	_hint.offset_top = UiTheme.px(66 if boss_bar != null and boss_bar.visible and not _quick else 44)
	_hint.offset_bottom = _hint.offset_top


func _on_score_changed() -> void:
	score_counter.set_value(world.score.score)
	credits_counter.set_value(world.score.credits)


func _on_bonus(label: String, points: int) -> void:
	while _popups.get_child_count() >= MAX_POPUPS:
		var oldest: Node = _popups.get_child(0)
		_popups.remove_child(oldest)
		oldest.queue_free()
	var l: Label = _label(UiTheme.HUD_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	l.text = "%s  +%s" % [label, UiTheme.format_int(points)]
	l.add_theme_color_override(&"font_color", UiTheme.style().accent.lerp(Color.WHITE, 0.45))
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	l.modulate.a = 0.0
	_popups.add_child(l)
	var tween := l.create_tween()
	tween.tween_property(l, "modulate:a", 1.0, 0.12)
	tween.tween_interval(POPUP_TIME)
	tween.tween_property(l, "modulate:a", 0.0, 0.35)
	tween.tween_callback(l.queue_free)


func _label(variation: StringName, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
