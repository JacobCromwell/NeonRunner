class_name BossBar
extends VBoxContainer
## The boss's health on the HUD (GDD §10): its name and phase above a wide bar in the enemy-health red,
## with a marker where each phase ends (a marker dims once its phase is over), and a white segment
## that drains after each hit, like the enemy health bars. While the boss can't be hurt (its entrance
## or a phase change) the fill turns grey. Nothing in it blinks (Reduced flashing).
## DESIGN-TBD (OPEN_QUESTIONS §5, docs/questions/b8.md): the boss HUD's look and place.
##   bar.bind(encounter)        # follows the fight from then on
##   bar.set_state(0.6, [0.667, 0.333], true, "PHASE 2/3")   # or drive it by hand (tests, showcases)

## Seconds the recent-damage segment waits before draining, and its drain speed (share per second).
const DRAIN_DELAY: float = 0.3
const DRAIN_SPEED: float = 0.8

var name_label: Label
var phase_label: Label
## Health share shown (0–1), the phase ends, and whether the boss can be hurt now.
var value: float = 1.0
var marks: PackedFloat32Array = PackedFloat32Array()
var vulnerable: bool = true
var encounter: BossEncounter

var _bar: BarView
var _drain: float = 1.0
var _hold: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 2)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	name_label = _label(UiTheme.HUD_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	phase_label = _label(UiTheme.HUD_CAPTION, HORIZONTAL_ALIGNMENT_RIGHT)
	phase_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(phase_label)
	_bar = BarView.new()
	_bar.owner_bar = self
	add_child(_bar)


## Follows `p_encounter` (its boss's name, health, phases and state) from now on.
func bind(p_encounter: BossEncounter) -> void:
	encounter = p_encounter
	name_label.text = encounter.def.display_name.to_upper()
	value = encounter.health_ratio()
	_drain = value
	_hold = 0.0
	_refresh()


## Sets what the bar shows without an encounter.
func set_state(p_value: float, p_marks: PackedFloat32Array, p_vulnerable: bool, phase_text: String) -> void:
	_show_value(p_value)
	marks = p_marks
	vulnerable = p_vulnerable
	phase_label.text = phase_text
	_bar.queue_redraw()


## The share the white recent-damage segment reaches (it drains down to `value`).
func drain_value() -> float:
	return _drain


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if encounter != null and is_instance_valid(encounter):
		_refresh()
	if _drain > value:
		if _hold > 0.0:
			_hold -= delta
		else:
			_drain = move_toward(_drain, value, DRAIN_SPEED * delta)
	else:
		_drain = value
	_bar.queue_redraw()


## A new health share: after a hit, the white segment holds a moment before it drains.
func _show_value(v: float) -> void:
	var next: float = clampf(v, 0.0, 1.0)
	if next < value - 0.0001:
		_hold = DRAIN_DELAY
	value = next


func _refresh() -> void:
	_show_value(encounter.health_ratio())
	marks = encounter.phase_marks()
	vulnerable = encounter.is_vulnerable() or encounter.is_defeated()
	var text: String = ""
	if encounter.is_defeated():
		text = "DEFEATED"
	elif encounter.phase_count() > 1:
		var count: String = "%d/%d" % [encounter.phase_index + 1, encounter.phase_count()]
		text = "%s · %s" % [encounter.phase().title(encounter.phase_index).to_upper(), count]
		# A long name (the final villain's) keeps its room: the phase shows its number alone (DESIGN-TBD,
		# docs/OPEN_QUESTIONS.md, item 442).
		if not _fits(text):
			text = count
	phase_label.text = text


## True if the boss's name and `phase_text` both fit the bar's row (or it isn't laid out yet).
func _fits(phase_text: String) -> bool:
	var row: float = size.x
	if row <= 0.0:
		return true
	return _text_width(name_label, name_label.text) + _text_width(phase_label, phase_text) + UiTheme.px(8) <= row


static func _text_width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font(&"font")
	if font == null:
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x


func _label(variation: StringName, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The bar itself, drawn in code.
class BarView:
	extends Control

	var owner_bar: BossBar

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		return Vector2(UiTheme.px(240), UiTheme.px(16))

	func _draw() -> void:
		var s: UiStyle = UiTheme.style()
		var r := Rect2(Vector2.ZERO, size)
		var inner: Rect2 = r.grow(-2.0)
		draw_rect(r, Color(s.panel, 0.92))
		var fill: Color = s.danger if owner_bar.vulnerable else s.text_disabled
		var drain_w: float = inner.size.x * owner_bar.drain_value()
		var fill_w: float = inner.size.x * owner_bar.value
		if drain_w > fill_w:
			draw_rect(Rect2(inner.position, Vector2(drain_w, inner.size.y)), Color(1.0, 1.0, 1.0, 0.9))
		if fill_w > 0.0:
			draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), fill)
			# A lighter top edge so the fill reads as lit.
			draw_rect(Rect2(inner.position, Vector2(fill_w, maxf(inner.size.y * 0.25, 1.0))), fill.lerp(Color.WHITE, 0.35))
		for m: float in owner_bar.marks:
			var x: float = inner.position.x + inner.size.x * m
			var passed: bool = owner_bar.value <= m + 0.0001
			var c: Color = Color(s.text_dim, 0.6) if passed else s.text
			draw_rect(Rect2(x - 1.5, r.position.y - 3.0, 3.0, r.size.y + 6.0), c)
			var d: float = UiTheme.px(5)
			var top := Vector2(x, r.position.y - 3.0)
			draw_colored_polygon(PackedVector2Array([top + Vector2(0, -d), top + Vector2(d, 0), top + Vector2(0, d),
				top + Vector2(-d, 0)]), c)
		draw_rect(r, Color(s.text, 0.55), false, 1.5)
