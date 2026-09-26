class_name DeathScreen
extends ScreenBase
## The revive offer after a death (GDD §4: mobile: rewarded ad or revive item; PC: revive item),
## over the stopped run: what hit the player, how far they got, and the ways back in. With nothing
## to offer it goes straight on to the run summary. The buttons wake up after a moment, so keys
## still being mashed from the run can't spend a revive by accident.
## DESIGN-TBD: whether the offer times out on its own (a countdown) is open; it waits for a choice.

## How long the buttons ignore input after the offer appears (real seconds; the game is paused).
const ARM_TIME: float = 0.5

## The offer's buttons by name (item, ad, give_up), for tests.
var buttons: Dictionary = {}
var _status: Label
var _waiting_for_ad: bool = false


func _ready() -> void:
	var options: Dictionary = App.revive_options()
	if not options["item"] and not options["ad"]:
		App.decline_revive.call_deferred()
		return
	backdrop = Backdrop.DIM
	show_title_bar = false
	show_back = false
	var column: VBoxContainer = add_panel(UiTheme.DIALOG, 440.0)
	column.add_theme_constant_override(&"separation", roundi(UiTheme.px(10)))
	var down := ScreenBase.make_label("DOWN!", UiTheme.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	down.add_theme_color_override(&"font_color", UiTheme.style().danger)
	column.add_child(down)
	var run: LevelRun = App.run
	var cause: String = run.death_cause if run != null else ""
	column.add_child(ScreenBase.make_label(DeathScreen.cause_text(cause), UiTheme.HEADING, HORIZONTAL_ALIGNMENT_CENTER))
	var progress: Control = DeathScreen.progress_row(run)
	if progress != null:
		column.add_child(progress)

	var gap := Control.new()
	gap.custom_minimum_size.y = UiTheme.px(4)
	column.add_child(gap)
	if options["item"]:
		var stock: int = int(options["stock"])
		var b: NeonButton = _add_button(column, "item", "REVIVE", NeonButton.Kind.PRIMARY, &"revive", App.revive_with_item)
		b.tooltip_text = "Uses one revive from your stock"
		column.add_child(ScreenBase.make_label("%d in stock" % stock if stock != 1 else "Your last one",
			UiTheme.CAPTION, HORIZONTAL_ALIGNMENT_CENTER))
	if options["ad"]:
		var kind: NeonButton.Kind = NeonButton.Kind.NORMAL if options["item"] else NeonButton.Kind.PRIMARY
		_add_button(column, "ad", "WATCH AN AD TO REVIVE", kind, &"ad", _watch_ad)
	_add_button(column, "give_up", "GIVE UP", NeonButton.Kind.FLAT, &"close", App.decline_revive)
	_status = ScreenBase.make_label("", UiTheme.CAPTION, HORIZONTAL_ALIGNMENT_CENTER)
	_status.visible = false
	column.add_child(_status)
	initial_focus = buttons.get("item", buttons.get("ad"))
	_set_enabled(false)
	get_tree().create_timer(ARM_TIME, true, false, true).timeout.connect(_arm)


## How far the run got, for the revive offer and the pause menu: a meter with the share of the level
## run and its percentage, or in a boss fight the share of the boss's health taken, with a marker at
## each phase's end and the phase reached (GDD §10). Null for endless runs (no end to measure).
static func progress_row(run: LevelRun) -> Control:
	if run == null or run.world == null or run.world.layout == null or run.context.mode == RunContext.Mode.ENDLESS:
		return null
	var meter := ProgressMeter.new()
	var text: String
	var encounter: BossEncounter = BossEncounter.of(run.world)
	if encounter != null:
		meter.value = 1.0 - encounter.health_ratio()
		var marks := PackedFloat32Array()
		for m: float in encounter.phase_marks():
			marks.append(1.0 - m)
		meter.markers = marks
		text = "PHASE %d/%d" % [encounter.phase_index + 1, encounter.phase_count()]
	else:
		meter.value = clampf(run.world.player.distance / maxf(run.world.layout.length, 1.0), 0.0, 1.0)
		text = "%d%%" % floori(meter.value * 100.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(meter)
	row.add_child(ScreenBase.make_label(text, UiTheme.VALUE))
	return row


## "You fell", "Hit by Cyborg": the death cause as the player reads it.
static func cause_text(cause: String) -> String:
	if cause == "":
		return "Down"
	if cause == "fell":
		return "You fell"
	return "Hit by %s" % (cause.left(1).to_upper() + cause.substr(1))


func _add_button(parent: Control, id: String, label: String, kind: NeonButton.Kind, icon_name: StringName,
		action: Callable) -> NeonButton:
	var b := NeonButton.make(label, kind, icon_name)
	b.pressed.connect(action)
	parent.add_child(b)
	buttons[id] = b
	return b


func _arm() -> void:
	if not is_inside_tree() or _waiting_for_ad:
		return
	_set_enabled(true)
	focus_initial()


func _set_enabled(on: bool) -> void:
	for id: String in buttons:
		(buttons[id] as NeonButton).disabled = not on


func _watch_ad() -> void:
	_waiting_for_ad = true
	_set_enabled(false)
	_status.text = "Ad playing…"
	_status.visible = true
	DeathScreen._await_ad(weakref(self))


## Awaits the ad in a static function: on success the App closes this overlay (and frees it).
static func _await_ad(screen_ref: WeakRef) -> void:
	await App.revive_with_ad()
	var screen := screen_ref.get_ref() as DeathScreen
	if screen != null and screen.is_inside_tree() and not screen.is_queued_for_deletion():
		screen._ad_failed()


## The ad ended without a reward: the offer stays open.
func _ad_failed() -> void:
	_waiting_for_ad = false
	_status.text = "No reward: the ad didn't finish."
	_set_enabled(true)
	if buttons.has("ad"):
		(buttons["ad"] as NeonButton).grab_focus(UiTheme.is_touch())
