class_name LevelSelectScreen
extends ScreenBase
## The campaign map (GDD §6): every zone in order. A built zone shows its steps as tiles: cinematic
## slots, levels (stars and best score for the chosen difficulty tier) and the boss slot. Steps not
## reached yet are locked; in the web demo, steps past its zone lead to the "full game" screen.
## Zones not designed yet show as "coming soon". Once a harder tier is unlocked, a selector picks
## the tier the tiles show and play.

## The tier last chosen, kept for the session.
static var chosen_tier: int = 0

var tier: int = 0
## Step id -> its tile, for tests and focus.
var tiles: Dictionary = {}
var tier_buttons: Array[NeonButton] = []
var _zones: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	title = "CAMPAIGN"
	back_requested.connect(App.show_title)
	tier = clampi(chosen_tier, 0, App.profile.unlocked_tier)
	if App.profile.unlocked_tier > 0:
		_build_tier_selector()
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	content.add_child(_scroll)
	_zones = VBoxContainer.new()
	_zones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zones.add_theme_constant_override(&"separation", roundi(UiTheme.px(14)))
	_scroll.add_child(_zones)
	_build_zones()


## Shows another difficulty tier's records and locks, and plays it.
func set_tier(t: int) -> void:
	tier = clampi(t, 0, App.profile.unlocked_tier)
	chosen_tier = tier
	for i: int in tier_buttons.size():
		tier_buttons[i].set_pressed_no_signal(i == tier)
	_build_zones()


func _build_tier_selector() -> void:
	header_right.add_child(ScreenBase.make_label("DIFFICULTY", UiTheme.CAPTION))
	var group := ButtonGroup.new()
	for t: int in App.profile.unlocked_tier + 1:
		var tier_name: String = App.campaign.tier_names[t] if t < App.campaign.tier_names.size() else "Tier %d" % (t + 1)
		var b := NeonButton.make(tier_name.to_upper())
		b.toggle_mode = true
		b.button_group = group
		b.set_pressed_no_signal(t == tier)
		b.pressed.connect(set_tier.bind(t))
		header_right.add_child(b)
		tier_buttons.append(b)


func _build_zones() -> void:
	for child: Node in _zones.get_children():
		_zones.remove_child(child)
		child.queue_free()
	tiles.clear()
	var steps: Array[CampaignStep] = App.campaign.steps()
	# Zones still to be designed share one row of "coming soon" cards after the built ones (made only
	# when there is one: a node never added to the tree would leak).
	var coming: HFlowContainer = null
	for zi: int in App.campaign.zones.size():
		var zone: ZoneDef = App.campaign.zones[zi]
		if zone.placeholder or zone.levels.is_empty():
			if coming == null:
				coming = HFlowContainer.new()
			coming.add_child(_coming_soon_card(zone, zi))
		else:
			_zones.add_child(_zone_section(zone, zi, steps))
	if coming != null:
		_zones.add_child(coming)
	# Focus the next step to play (or the first open one).
	var next: CampaignStep = App.next_unfinished_step(tier)
	var target: TileButton = tiles.get(next.id) if next != null else null
	if target == null or target.disabled:
		for s: CampaignStep in steps:
			var t: TileButton = tiles.get(s.id)
			if t != null and not t.disabled:
				target = t
				break
	initial_focus = target
	if is_node_ready():
		focus_initial.call_deferred()
	_scroll_into_view(target)


## Scrolls the list to `target` once the tiles have their layout, `frames` frames from now:
## follow_focus can't scroll to controls laid out in the same frame, and six zones make a list
## several screens long, so a player deep in the campaign would otherwise open it at the top with the
## focused step out of sight. (A one-shot connection rather than an await: it simply drops if the
## screen is freed first.)
func _scroll_into_view(target: Control, frames: int = 2) -> void:
	if target == null or not is_inside_tree():
		return
	if frames > 0:
		get_tree().process_frame.connect(_scroll_into_view.bind(target, frames - 1), CONNECT_ONE_SHOT)
	elif is_instance_valid(target) and target.is_inside_tree():
		_scroll.ensure_control_visible(target)


func _zone_section(zone: ZoneDef, zi: int, steps: Array[CampaignStep]) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.CARD
	var column := VBoxContainer.new()
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var names := VBoxContainer.new()
	names.add_theme_constant_override(&"separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(names)
	names.add_child(ScreenBase.make_label("ZONE %d" % (zi + 1), UiTheme.SUBHEADING))
	var name_row := HBoxContainer.new()
	names.add_child(name_row)
	name_row.add_child(ScreenBase.make_label(zone.display_name, UiTheme.HEADING))
	if zone.tagline != "":
		var tagline := ScreenBase.make_label(zone.tagline, UiTheme.CAPTION)
		tagline.size_flags_vertical = Control.SIZE_SHRINK_END
		name_row.add_child(tagline)
	header.add_child(_zone_stars(zone, steps))
	var row := HFlowContainer.new()
	column.add_child(row)
	for s: CampaignStep in steps:
		if s.zone == zone:
			var tile: TileButton = _step_tile(s)
			row.add_child(tile)
			tiles[s.id] = tile
	return panel


## Stars earned in the zone out of the most possible, on the chosen tier.
func _zone_stars(zone: ZoneDef, steps: Array[CampaignStep]) -> Control:
	var earned: int = 0
	var most: int = 0
	for s: CampaignStep in steps:
		if s.zone == zone and s.is_level():
			earned += App.profile.stars(s.id, tier)
			most += 3
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var star := NeonIcon.make(&"star", UiTheme.px(22), UiTheme.style().star)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(star)
	row.add_child(ScreenBase.make_label("%d / %d" % [earned, most], UiTheme.VALUE))
	return row


func _step_tile(s: CampaignStep) -> TileButton:
	var tile := TileButton.new()
	tile.tooltip_text = s.title()
	var locked: bool = not App.step_unlocked(s, tier)
	var full_game: bool = not App.in_demo_scope(s)
	var done: bool = App.profile.is_completed(s.id, tier)
	match s.kind:
		CampaignStep.Kind.LEVEL:
			_fill_level(tile, s, done, locked)
		CampaignStep.Kind.BOSS:
			tile.custom_minimum_size.x = UiTheme.px(156)
			tile.content.add_child(_centered_icon(&"boss", 36, UiTheme.style().danger if not locked else UiTheme.style().text_disabled))
			tile.add_label("BOSS", UiTheme.SUBHEADING)
			tile.add_label(s.title(), UiTheme.CAPTION)
		CampaignStep.Kind.CINEMATIC:
			tile.custom_minimum_size.x = UiTheme.px(112)
			tile.content.add_child(_centered_icon(&"film", 28, UiTheme.style().text_dim))
			tile.add_label(LevelSelectScreen.slot_name(s), UiTheme.CAPTION)
	if full_game and not locked:
		# The demo stops here: the tile leads to the "get the full game" screen.
		tile.content.add_child(_badge(&"store", "FULL GAME", UiTheme.style().accent_2))
	elif locked:
		tile.content.add_child(_badge(&"lock", "LOCKED", UiTheme.style().text_dim))
	elif done and not s.is_level():
		tile.content.add_child(_badge(&"check", "DONE", UiTheme.style().accent))
	tile.disabled = locked
	if locked:
		tile.content.modulate = Color(1, 1, 1, 0.55)
	tile.pressed.connect(func() -> void: App.play_step(s, tier))
	return tile


func _fill_level(tile: TileButton, s: CampaignStep, done: bool, locked: bool) -> void:
	tile.custom_minimum_size.x = UiTheme.px(200)
	var record: Dictionary = App.profile.record(s.id, tier)
	var top := HBoxContainer.new()
	tile.content.add_child(top)
	var number := ScreenBase.make_label("%02d" % s.number_in_zone, UiTheme.VALUE)
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(number)
	var stars := StarRow.new()
	stars.star_size = UiTheme.px(20)
	stars.stars = int(record.get("stars", 0))
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.add_theme_constant_override(&"separation", roundi(UiTheme.px(4)))
	top.add_child(stars)
	var level_name := ScreenBase.make_label(s.title(), &"", HORIZONTAL_ALIGNMENT_LEFT)
	level_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# A long name shrinks a little to fit its tile.
	level_name.resized.connect(func() -> void:
		UiTheme.fit_font(level_name, get_theme_font(&"font", &"Label"), get_theme_font_size(&"font_size", &"Label"), 0.8))
	tile.content.add_child(level_name)
	if locked:
		return
	var best: int = int(record.get("best_score", 0))
	if done:
		tile.add_label("BEST %s" % UiTheme.format_int(best), UiTheme.CAPTION, HORIZONTAL_ALIGNMENT_LEFT)
	elif int(record.get("attempts", 0)) > 0:
		tile.add_label("NOT CLEARED", UiTheme.CAPTION, HORIZONTAL_ALIGNMENT_LEFT)
	else:
		tile.add_label("NEW", UiTheme.ACCENT_CAPTION, HORIZONTAL_ALIGNMENT_LEFT)


func _coming_soon_card(zone: ZoneDef, zi: int) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = UiTheme.CARD
	card.custom_minimum_size.x = UiTheme.px(280)
	card.modulate = Color(1, 1, 1, 0.6)
	var row := HBoxContainer.new()
	card.add_child(row)
	var icon := NeonIcon.make(&"lock", UiTheme.px(26), UiTheme.style().text_dim)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", 0)
	row.add_child(words)
	words.add_child(ScreenBase.make_label("ZONE %d" % (zi + 1), UiTheme.SUBHEADING))
	words.add_child(ScreenBase.make_label("Coming soon" if zone.display_name == "" or zone.display_name.begins_with("Zone") \
		else "%s · coming soon" % zone.display_name, UiTheme.CAPTION))
	return card


## "INTRO", "BOSS INTRO", "OUTRO" from the step id's slot.
static func slot_name(s: CampaignStep) -> String:
	return s.id.get_slice("/", 1).replace("_", " ").to_upper()


func _centered_icon(icon_name: StringName, size_px: float, color: Color) -> NeonIcon:
	var icon := NeonIcon.make(icon_name, UiTheme.px(size_px), color)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return icon


func _badge(icon_name: StringName, text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 4)
	var icon := NeonIcon.make(icon_name, UiTheme.px(14), color)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label := ScreenBase.make_label(text, UiTheme.CAPTION)
	label.add_theme_color_override(&"font_color", color)
	row.add_child(label)
	return row
