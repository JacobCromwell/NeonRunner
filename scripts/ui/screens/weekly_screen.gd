class_name WeeklyScreen
extends ScreenBase
## The weekly challenge (GDD §6, Replay features; the owner, October 18, 2026; task N5): this week's level, the same
## for every player, and what it holds for them. The zone it plays in and when the week ends; the kit everyone runs it
## with (Armor IV and Juggernaut dash IV, nothing else); what its first clear pays (once a week) or that it was paid;
## the board it counts for (PC's or mobile's) with the player's best on it; and the Leader of the Pack the top places
## earn, with the weeks it was earned. Locked until the Neon City's boss is beaten, and closed (PLAY off, the reason
## given) before the schedule's first week opens and while the device's clock is behind a week already played
## (App.weekly_state). Unlimited attempts: PLAY is always there when it is open, never behind an ad or a purchase.

## How often the countdown is read (seconds).
const REFRESH: float = 1.0

## The screen's buttons by name (play, board), for tests.
var buttons: Dictionary = {}
var play_button: NeonButton
## The labels the screen keeps current, for tests.
var countdown_label: Label
var best_label: Label
var _week: WeeklyWeek
var _since_refresh: float = 0.0


func _ready() -> void:
	title = "WEEKLY CHALLENGE"
	back_requested.connect(App.show_title)
	set_hints([[&"ui_accept", "SELECT"], [&"ui_cancel", "BACK"]])
	var wallet := CreditCounter.new()
	wallet.set_value(App.profile.credits(), false)
	header_right.add_child(wallet)
	App.profile_changed.connect(_rebuild)
	_rebuild()


func _exit_tree() -> void:
	if App.profile_changed.is_connected(_rebuild):
		App.profile_changed.disconnect(_rebuild)


func _process(delta: float) -> void:
	_since_refresh += delta
	if _since_refresh < REFRESH or _week == null:
		return
	_since_refresh = 0.0
	var now: int = App.now_unix()
	if _week.is_over(now):
		_rebuild()
	elif countdown_label != null:
		countdown_label.text = _countdown_text(now)


# --- Building ---------------------------------------------------------------------------------

func _rebuild() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	buttons.clear()
	play_button = null
	countdown_label = null
	best_label = null
	_week = App.current_week()
	var short: bool = is_short()
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", roundi(UiTheme.px(8 if short else 14)))
	column.custom_minimum_size.x = UiTheme.px(700 if short else 760)
	center.add_child(column)
	match App.weekly_state():
		&"open":
			_build_open(column, short)
		&"locked":
			var step: CampaignStep = App.campaign.step(App.weekly.unlock_step)
			var boss_name: String = step.title().trim_prefix("The ") if step != null and step.kind == CampaignStep.Kind.BOSS else "boss"
			var zone_name: String = step.zone.display_name if step != null and step.zone != null else "Neon City"
			_build_closed(column, short, "LOCKED", &"lock",
				"Beat the %s, the %s's boss, to take part. A new level every week, the same for every player, with a board of its own." \
				% [boss_name, zone_name])
		&"not_yet":
			_build_closed(column, short, "OPENS SOON", &"info",
				"The first weekly challenge opens on %s. A new level every week, the same for every player, with a board of its own." \
				% WeeklyChallenge.format_date(App.weekly.epoch_unix))
		&"behind":
			var high: int = App.profile.weekly_high_water()
			_build_closed(column, short, "CLOCK BEHIND", &"warning",
				"This device's clock is behind a week you have already played (week %d). The weekly challenge goes on when it reaches week %d, %s." \
				% [high + 1, high + 1, WeeklyChallenge.format_date(App.weekly.week_start(high))])
		_:
			column.add_child(_note("The weekly challenge is part of the full game."))
	var way: Control = play_button if play_button != null else first_focusable(content)
	if way != null:
		initial_focus = way
		if is_node_ready():
			focus_initial.call_deferred()


## A week the player can't play: its heading and icon, and why. PLAY is there, off.
func _build_closed(column: VBoxContainer, short: bool, heading: String, icon_name: StringName, why: String) -> void:
	var card := _card()
	column.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", roundi(UiTheme.px(6 if short else 10)))
	card.add_child(box)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override(&"separation", roundi(UiTheme.px(10)))
	var icon := NeonIcon.make(icon_name, UiTheme.px(30 if short else 40), UiTheme.style().accent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	head.add_child(make_label(heading, UiTheme.TITLE))
	box.add_child(head)
	box.add_child(_note(why))
	play_button = NeonButton.make("PLAY", NeonButton.Kind.PRIMARY, &"play")
	play_button.disabled = true
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.custom_minimum_size.x = UiTheme.px(210)
	column.add_child(play_button)
	buttons["play"] = play_button


func _build_open(column: VBoxContainer, short: bool) -> void:
	var zone: ZoneDef = WeeklyChallenge.zone_of(App.campaign, _week.zone_id)
	var zone_name: String = zone.display_name if zone != null else String(_week.zone_id).capitalize()
	var cleared: bool = App.profile.weekly_cleared(_week.index)
	var gap: int = roundi(UiTheme.px(6 if short else 10))

	# This week: its number, when it ends, the zone it plays in.
	var week_card := _card()
	column.add_child(week_card)
	var week_box := VBoxContainer.new()
	week_box.add_theme_constant_override(&"separation", 0)
	week_card.add_child(week_box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", roundi(UiTheme.px(12)))
	week_box.add_child(top)
	var kicker := make_label("WEEK %d" % _week.number(), UiTheme.SUBHEADING)
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(kicker)
	countdown_label = make_label(_countdown_text(App.now_unix()), UiTheme.CAPTION, HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(countdown_label)
	var name_label := make_label(zone_name.to_upper(), UiTheme.TITLE)
	if short:
		name_label.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(34)))
	week_box.add_child(name_label)
	var about := make_label("The same level for every player: this zone's own enemies and look, at Golden Zone difficulty, on %d lanes." \
		% App.weekly.lanes, UiTheme.CAPTION)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	week_box.add_child(about)

	# The kit and the prize, side by side.
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", gap)
	row.add_theme_constant_override(&"v_separation", gap)
	column.add_child(row)
	row.add_child(_kit_card(short))
	row.add_child(_prize_card(cleared, short))

	# The board and the player's place on it.
	column.add_child(_board_row(cleared, short))
	var earned: Control = _rewards_row()
	if earned != null:
		column.add_child(earned)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override(&"separation", roundi(UiTheme.px(14)))
	column.add_child(actions)
	play_button = NeonButton.make("PLAY" if not cleared else "PLAY AGAIN", NeonButton.Kind.PRIMARY, &"play")
	play_button.custom_minimum_size.x = UiTheme.px(210)
	play_button.pressed.connect(App.start_weekly)
	actions.add_child(play_button)
	buttons["play"] = play_button
	if Platform.leaderboards_available():
		var board := NeonButton.make("VIEW BOARD", NeonButton.Kind.NORMAL, &"leaderboard")
		board.pressed.connect(func() -> void: Platform.show_leaderboard(App.weekly_board_id(_week)))
		actions.add_child(board)
		buttons["board"] = board


func _countdown_text(now: int) -> String:
	return "ENDS IN %s" % WeeklyChallenge.format_left(_week.seconds_left(now)).to_upper()


## The uniform kit: the items every player runs the week with, by the catalog's own names.
func _kit_card(short: bool) -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	card.add_child(box)
	box.add_child(make_label("EVERYONE'S KIT", UiTheme.SUBHEADING))
	for id: Variant in App.weekly.kit:
		var item: ShopItem = App.catalog.item(StringName(String(id)))
		if item == null:
			continue
		var tier: int = clampi(App.weekly.kit_tier(item.id), 1, maxi(item.tier_count(), 1))
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", roundi(UiTheme.px(8)))
		var icon := NeonIcon.make(item.icon, UiTheme.px(22 if short else 26), UiTheme.style().accent)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(icon)
		var tier_name: String = String(item.tiers[tier - 1].get("name", item.display_name)) if item.tier_count() > 0 \
			else item.display_name
		line.add_child(make_label(tier_name, UiTheme.CARD_TITLE))
		box.add_child(line)
	var rest := make_label("Nothing else from the shop, whatever you own.", UiTheme.CAPTION)
	rest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rest)
	return card


## What the week's first clear pays, or that it has.
func _prize_card(cleared: bool, short: bool) -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	card.add_child(box)
	box.add_child(make_label("FIRST CLEAR PAID" if cleared else "FIRST CLEAR PAYS", UiTheme.SUBHEADING))
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", roundi(UiTheme.px(8)))
	var credits: int = int(App.profile.weekly_record(_week.index).get("paid", 0)) if cleared else App.weekly.first_clear_credits
	var icon := NeonIcon.make(IconFactory.credit_icon(100), UiTheme.px(22 if short else 26))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	line.add_child(make_label("%s credits" % UiTheme.format_int(credits), UiTheme.CARD_TITLE))
	box.add_child(line)
	var rest := make_label("Once a week. Every other run pays nothing." if not cleared else "Paid this week. Later runs still count for the board.",
		UiTheme.CAPTION)
	rest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rest)
	return card


## The board this device's runs go to and the player's best on it this week.
func _board_row(cleared: bool, short: bool) -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = UiTheme.HUD_PANEL
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", roundi(UiTheme.px(10)))
	chip.add_child(row)
	var icon := NeonIcon.make(&"leaderboard", UiTheme.px(22 if short else 26), UiTheme.style().accent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var board_name: String = "MOBILE BOARD" if App.mobile else "PC BOARD"
	var names := VBoxContainer.new()
	names.add_theme_constant_override(&"separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	names.add_child(make_label(board_name, UiTheme.SUBHEADING))
	var note := make_label("Top %d earn Leader of the Pack." % App.weekly.top_places, UiTheme.CAPTION)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(note)
	best_label = make_label(("BEST  %s" % UiTheme.format_int(App.profile.weekly_best(_week.index))) if cleared else "NOT CLEARED YET",
		UiTheme.CARD_TITLE, HORIZONTAL_ALIGNMENT_RIGHT)
	best_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(best_label)
	return chip


## The weeks the Leader of the Pack was earned in, if any (DESIGN-TBD, item 977 in docs/OPEN_QUESTIONS.md: the
## cosmetic itself isn't designed, so the screen only names the weeks), else null.
func _rewards_row() -> Control:
	var weeks: PackedStringArray = []
	for r: Dictionary in App.profile.weekly_rewards:
		if String(r.get("state", "")) == "earned":
			weeks.append("week %d (place %d)" % [int(r.get("week", 0)) + 1, int(r.get("rank", 0))])
	if weeks.is_empty():
		return null
	var label := make_label("LEADER OF THE PACK: %s" % ", ".join(weeks), UiTheme.ACCENT_CAPTION, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = UiTheme.CARD
	return card


func _note(text: String) -> Label:
	var label := make_label(text, &"", HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
