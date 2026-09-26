class_name NeonButton
extends Button
## The kit's button. Themed (finger-size on touch devices), with an optional vector icon by name,
## and it plays ui_move when hovered or focused and ui_select when pressed (UiSounds; silent if
## the library has no such sound).
##   var play := NeonButton.make("PLAY", NeonButton.Kind.PRIMARY, &"play")

enum Kind { NORMAL, PRIMARY, DANGER, FLAT, ICON, HUD, PRICE }

const VARIATIONS: Dictionary = {
	Kind.NORMAL: &"",
	Kind.PRIMARY: UiTheme.PRIMARY_BUTTON,
	Kind.DANGER: UiTheme.DANGER_BUTTON,
	Kind.FLAT: UiTheme.FLAT_BUTTON,
	Kind.ICON: UiTheme.ICON_BUTTON,
	Kind.HUD: UiTheme.HUD_BUTTON,
	Kind.PRICE: UiTheme.PRICE_BUTTON,
}

@export var kind: Kind = Kind.NORMAL:
	set(value):
		kind = value
		theme_type_variation = VARIATIONS[value]
## An IconFactory icon shown before the text, tinted by the theme's icon colours.
@export var icon_name: StringName = &"":
	set(value):
		icon_name = value
		_update_icon()
## Colour baked into the icon (for icons with their own colour, like credits). Transparent =
## white, tinted per state by the theme.
@export var icon_color: Color = Color(0, 0, 0, 0):
	set(value):
		icon_color = value
		_update_icon()
@export var sound_move: StringName = UiSounds.MOVE
@export var sound_select: StringName = UiSounds.SELECT


static func make(label: String, button_kind: Kind = Kind.NORMAL, icon_id: StringName = &"") -> NeonButton:
	var b := NeonButton.new()
	b.text = label
	b.kind = button_kind
	b.icon_name = icon_id
	return b


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	pressed.connect(_on_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_ensure_theme.call_deferred()
	elif what == NOTIFICATION_THEME_CHANGED:
		_update_icon()


func _ensure_theme() -> void:
	UiTheme.ensure(self)


func _update_icon() -> void:
	if icon_name == &"":
		icon = null
		return
	var tint: Color = icon_color if icon_color.a > 0.0 else Color.WHITE
	var size_px: int = get_theme_constant(&"icon_size", UiTheme.NEON)
	if size_px <= 0:
		# Not under a UiTheme theme yet; the theme change on entering one updates it.
		size_px = UiTheme.style().icon_size
	icon = IconFactory.texture(icon_name, size_px, tint)


func _on_mouse_entered() -> void:
	if not disabled:
		UiSounds.play(sound_move)


func _on_focus_entered() -> void:
	# A click also focuses the button; that press plays ui_select instead.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		UiSounds.play(sound_move)


func _on_pressed() -> void:
	UiSounds.play(sound_select)
