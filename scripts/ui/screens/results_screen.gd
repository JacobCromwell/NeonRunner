class_name ResultsScreen
extends ScreenBase
## After a run: level complete (the stars pop in, the score and the credits count up: collected
## plus the completion bonus makes what's earned, then the stats and NEW BEST) or the run summary
## after a death (what hit the player, the credits kept). A boss fight (GDD §10) shows BOSS DEFEATED,
## its stars against the par times (listed under them), the boss's payout, and the fight's own stats
## (time, weak points, the phase reached, the time bonus); a mini-game level its payout and its own stats (the
## volleyball match: the points won and lost, the returns). Then on to the shop and the next step or
## a retry (GDD §4, §8), a retry now, or the menu.
## The level-complete screen's stats (FB 60): the ScoreKeeper's, and a boss fight's own
## (DESIGN-TBD, docs/questions/b8.md).

## Wait before the reveal starts, so the screen has settled.
const REVEAL_DELAY: float = 0.25

var result: RunResult

var stars: StarRow
var score_counter: CreditCounter
var credits_counter: CreditCounter
var new_best: Control
## The screen's buttons by name (continue, retry, menu), for tests.
var buttons: Dictionary = {}


func _ready() -> void:
	show_title_bar = false
	show_back = false
	set_hints([[&"ui_accept", "SELECT"]])
	var ctx: RunContext = result.context
	var column: VBoxContainer = add_panel(UiTheme.DIALOG, 820.0)
	column.add_theme_constant_override(&"separation", roundi(UiTheme.px(8)))
	var names: PackedStringArray = ResultsScreen.run_names(ctx)
	var kicker: String = names[0] if names[1] == "" else "%s · %s" % [names[0], names[1].to_upper()]
	column.add_child(ScreenBase.make_label(kicker, UiTheme.SUBHEADING, HORIZONTAL_ALIGNMENT_CENTER))
	var boss: bool = ctx.is_boss()
	var heading := ScreenBase.make_label(("BOSS DEFEATED" if boss else "LEVEL COMPLETE") if result.completed else "RUN OVER",
		UiTheme.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	if not result.completed:
		heading.add_theme_color_override(&"font_color", UiTheme.style().danger)
	column.add_child(heading)
	if not result.completed and result.cause != "":
		column.add_child(ScreenBase.make_label(DeathScreen.cause_text(result.cause), UiTheme.HEADING, HORIZONTAL_ALIGNMENT_CENTER))

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", roundi(UiTheme.px(24)))
	column.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override(&"separation", roundi(UiTheme.px(8)))
	body.add_child(left)
	if result.completed:
		stars = StarRow.new()
		stars.star_size = UiTheme.px(56)
		stars.star_revealed.connect(_on_star)
		left.add_child(stars)
		if boss:
			left.add_child(ScreenBase.make_label(ResultsScreen.par_text(ctx.boss), UiTheme.CAPTION,
				HORIZONTAL_ALIGNMENT_CENTER))
	left.add_child(_score_row())
	left.add_child(HSeparator.new())
	left.add_child(_credit_table())
	var line := VSeparator.new()
	body.add_child(line)
	body.add_child(_stats_table())

	var gap := Control.new()
	gap.custom_minimum_size.y = UiTheme.px(6)
	column.add_child(gap)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override(&"separation", roundi(UiTheme.px(14)))
	column.add_child(actions)
	var menu := NeonButton.make("MENU", NeonButton.Kind.FLAT, &"home")
	menu.pressed.connect(App.show_level_select if ctx.is_campaign() else App.show_title)
	actions.add_child(menu)
	buttons["menu"] = menu
	if not result.completed or ctx.mode != RunContext.Mode.CAMPAIGN:
		var retry := NeonButton.make("RETRY NOW", NeonButton.Kind.NORMAL, &"restart")
		retry.pressed.connect(_retry)
		actions.add_child(retry)
		buttons["retry"] = retry
	var go_on := NeonButton.make("CONTINUE", NeonButton.Kind.PRIMARY, &"chevron_right")
	go_on.tooltip_text = "To the shop, then on"
	go_on.custom_minimum_size.x = UiTheme.px(210)
	go_on.pressed.connect(_continue)
	actions.add_child(go_on)
	buttons["continue"] = go_on
	initial_focus = go_on

	var reveal := create_tween()
	reveal.tween_interval(REVEAL_DELAY)
	reveal.tween_callback(_start_reveal)


## [kicker, name] for a run: "ZONE 1 · NEON CITY" and the level's name, "ENDLESS", "QUICK PLAY".
## Harder difficulty tiers are named in the kicker.
static func run_names(ctx: RunContext) -> PackedStringArray:
	var kicker: String = "QUICK PLAY"
	var level_name: String = ""
	match ctx.mode:
		RunContext.Mode.CAMPAIGN:
			if ctx.step != null:
				kicker = "ZONE %d · %s" % [ctx.step.zone_index + 1, ctx.step.zone.display_name.to_upper()]
				level_name = ctx.step.title()
			else:
				kicker = "CAMPAIGN"
		RunContext.Mode.ENDLESS:
			kicker = "ENDLESS"
		RunContext.Mode.QUICK:
			if ctx.config != null:
				level_name = "%s · seed %d" % [ctx.config.display_name, ctx.config.level_seed]
	var tiers: PackedStringArray = App.campaign.tier_names
	if ctx.difficulty_tier > 0:
		var tier_name: String = tiers[ctx.difficulty_tier] if ctx.difficulty_tier < tiers.size() else "Tier %d" % (ctx.difficulty_tier + 1)
		kicker += " · " + tier_name.to_upper()
	return PackedStringArray([kicker, level_name])


## m:ss.s
static func format_time(seconds: float) -> String:
	var whole: int = floori(seconds)
	return "%d:%02d.%d" % [whole / 60, whole % 60, floori((seconds - whole) * 10.0)]


## A boss's par times for its stars (GDD §10, proposed): "2 stars under 1:15 · 3 stars under 0:50".
static func par_text(def: BossDef) -> String:
	return "2 stars under %s · 3 stars under %s" % [_clock(def.two_star_seconds), _clock(def.three_star_seconds)]


## m:ss
static func _clock(seconds: float) -> String:
	var whole: int = floori(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


func _score_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", roundi(UiTheme.px(14)))
	var label := ScreenBase.make_label("SCORE", UiTheme.SUBHEADING)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	score_counter = CreditCounter.new()
	score_counter.show_icon = false
	score_counter.show_chip = false
	score_counter.pop_on_gain = false
	score_counter.count_time = 1.2
	score_counter.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(44)))
	score_counter.count_finished.connect(_on_score_counted, CONNECT_ONE_SHOT)
	row.add_child(score_counter)
	new_best = _new_best_chip()
	new_best.visible = false
	row.add_child(new_best)
	return row


func _new_best_chip() -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = UiTheme.HUD_PANEL
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	chip.add_child(row)
	var icon := NeonIcon.make(&"trophy", UiTheme.px(18), UiTheme.style().accent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(ScreenBase.make_label("NEW BEST", UiTheme.ACCENT_CAPTION))
	return chip


## Collected (+ bonus) = earned on completion; collected and the share kept after a death. What thieves
## took and kept (GDD §9.12) shows under what was collected, as it leaves the pay.
func _credit_table() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", roundi(UiTheme.px(16)))
	grid.add_theme_constant_override(&"v_separation", roundi(UiTheme.px(4)))
	_table_row(grid, "Credits collected", UiTheme.format_int(result.credits_collected))
	if result.credits_stolen > 0:
		_table_row(grid, "Stolen", "−" + UiTheme.format_int(result.credits_stolen))
	if result.completed:
		if result.completion_bonus > 0:
			var bonus_label: String = "Boss payout" if result.context.is_boss() \
				else ("Match payout" if String(result.stats.get("minigame", "")) != "" else "Completion bonus")
			_table_row(grid, bonus_label, "+" + UiTheme.format_int(result.completion_bonus), UiTheme.ACCENT_TEXT)
		_table_label(grid, "Credits earned")
	else:
		var share: float = App.rules.death_credit_keep_fraction if App.rules != null else 0.0
		_table_label(grid, "Credits kept (%d%%)" % roundi(share * 100.0))
	credits_counter = CreditCounter.new()
	credits_counter.size_flags_horizontal = Control.SIZE_SHRINK_END
	credits_counter.set_value(0, false)
	grid.add_child(credits_counter)
	return grid


func _table_row(grid: GridContainer, label: String, value: String, variation: StringName = UiTheme.VALUE) -> void:
	_table_label(grid, label)
	grid.add_child(ScreenBase.make_label(value, variation, HORIZONTAL_ALIGNMENT_RIGHT))


func _table_label(grid: GridContainer, label: String) -> void:
	var l := ScreenBase.make_label(label, UiTheme.CAPTION)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	grid.add_child(l)


func _stats_table() -> Control:
	var st: Dictionary = result.stats
	var grid := GridContainer.new()
	grid.columns = 2
	grid.custom_minimum_size.x = UiTheme.px(290)
	grid.add_theme_constant_override(&"h_separation", roundi(UiTheme.px(16)))
	grid.add_theme_constant_override(&"v_separation", roundi(UiTheme.px(2)))
	var rows: Array = [
		["Time", ResultsScreen.format_time(result.time)],
		["Distance", "%s m" % UiTheme.format_int(roundi(result.distance))],
		["Kills", UiTheme.format_int(int(st.get("kills", 0)))],
		["Stomps", UiTheme.format_int(int(st.get("stomps", 0)))],
		["Ramps", UiTheme.format_int(int(st.get("ramps", 0)))],
		["Longest wall run", "%d m" % roundi(float(st.get("longest_wall_run", 0.0)))],
		["Hits blocked", UiTheme.format_int(int(st.get("blocked", 0)))],
	]
	if result.context.is_boss():
		# A fight's own numbers (GDD §10): the time counts for stars and the time bonus.
		rows = [
			["Time", ResultsScreen.format_time(result.time)],
			["Phase reached", "%d / %d" % [int(st.get("phase", 1)), int(st.get("phases", 1))]],
			["Weak points hit", UiTheme.format_int(int(st.get("weak_points", 0)))],
			["Kills", UiTheme.format_int(int(st.get("kills", 0)))],
			["Hits blocked", UiTheme.format_int(int(st.get("blocked", 0)))],
			["Time bonus", UiTheme.format_int(int(st.get("time_bonus", 0)))],
		]
	if String(st.get("minigame", "")) != "":
		# A mini-game level's own numbers (the volleyball match: the points, the returns, its payout).
		rows = [
			["Time", ResultsScreen.format_time(result.time)],
			["Points won", "%d – %d" % [int(st.get("points_won", 0)), int(st.get("points_lost", 0))]],
			["Returns", UiTheme.format_int(int(st.get("returns", 0)))],
		]
	for r: Array in rows:
		_table_label(grid, r[0])
		var v := ScreenBase.make_label(r[1], &"", HORIZONTAL_ALIGNMENT_RIGHT)
		grid.add_child(v)
	return grid


func _start_reveal() -> void:
	if stars != null:
		stars.reveal(result.stars)
		stars.reveal_finished.connect(_count_credits, CONNECT_ONE_SHOT)
		if result.stars == 0:
			_count_credits()
	else:
		_count_credits()
	score_counter.set_value(result.score)


func _count_credits() -> void:
	credits_counter.set_value(result.credits_earned)


func _on_star(_index: int) -> void:
	App.play_ui_sound(&"star")


func _on_score_counted() -> void:
	if not bool(result.record.get("new_best", false)):
		return
	new_best.visible = true
	new_best.pivot_offset = new_best.size * 0.5
	new_best.scale = Vector2(0.6, 0.6)
	var pop := create_tween()
	pop.tween_property(new_best, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _continue() -> void:
	App.continue_after_result(result)


func _retry() -> void:
	App.retry(result.context)
