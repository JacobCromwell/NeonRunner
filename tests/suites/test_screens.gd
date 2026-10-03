extends TestSuite
## The game's screens and HUD on the real main scene. Every screen and overlay (a boss fight's results
## too) builds and frees cleanly for a fresh and a rich profile, at desktop and touch sizes; fits the
## smallest screen (1280×720 after stretching) without clipping; and gives keyboard focus that moves.
## Then each screen's own behaviour: the title menu, level select (locks, tiers, the demo's limit),
## the shop (buying, stock, equip, the way out, credit packs), settings (volumes, toggles, keys), the
## pause, death and results overlays, the slot and demo-end screens, and the HUD following a
## RunWorld's score, credits, charges and power-ups.

var main: Node
var heard: Array[StringName] = []


func run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	UiSounds.hook = func(sound: StringName) -> void: heard.append(sound)
	for touch: int in [0, 1]:
		UiTheme.touch_override = touch
		for rich: bool in [false, true]:
			App.profile = SampleProfiles.rich() if rich else SampleProfiles.fresh()
			await _test_every_screen("%s, %s profile" % ["touch" if touch == 1 else "desktop", "rich" if rich else "fresh"])
	UiTheme.touch_override = 0
	App.profile = SampleProfiles.rich()
	await _test_title()
	await _test_level_select()
	await _test_shop()
	await _test_settings()
	await _test_hint_paging()
	await _test_intro()
	await _test_pause()
	await _test_death()
	await _test_results()
	await _test_slots_and_demo_end()
	App.show_title()
	await _test_hud()

	UiTheme.touch_override = -1
	UiSounds.hook = Callable()
	LevelSelectScreen.chosen_tier = 0
	App.show_title()
	await tree.process_frame
	App.profile = saved
	InputMap.load_from_project_settings()
	Settings.apply(saved)
	main.queue_free()
	App.main = null
	await tree.process_frame


# --- Helpers ---------------------------------------------------------------------

func _frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		tree.root.push_input(event)


func _focus() -> Control:
	return tree.root.gui_get_focus_owner()


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key


func _show_result(completed: bool) -> ResultsScreen:
	var s := ResultsScreen.new()
	s.result = SampleProfiles.result(completed)
	App.show_screen(s)
	return s


func _show_boss_result(won: bool) -> ResultsScreen:
	var s := ResultsScreen.new()
	s.result = SampleProfiles.boss_result(won)
	App.show_screen(s)
	return s


func _start_level(id: String) -> void:
	App.start_level(App.campaign.step(id))
	App.begin_run()
	await physics_frames(10)


func _test_intro() -> void:
	App.profile = SampleProfiles.fresh()
	App.start_level(App.campaign.step("city/1"))
	await _frames(3)
	var intro := App.screen as LevelIntroScreen
	check(intro != null and App.run.state == LevelRun.State.READY, "campaign starts on its level introduction")
	if intro == null:
		return
	_check_fits(intro, "level intro")
	await _check_focus(intro, "level intro")
	var world: RunWorld = App.run.world
	await physics_frames(10)
	check(is_zero_approx(world.player.distance) and not world.player.running and not TouchInput.enabled,
		"the intro holds gameplay and touch input at the start")
	check(not App.profile.has_seen("hint/lanes"), "unconfirmed intro does not consume hints")
	intro.back_button.pressed.emit()
	await _frames(3)
	check(App.run == null and not App.profile.has_seen("hint/lanes"), "back discards the prepared run without losing hints")
	App.start_level(App.campaign.step("city/1"))
	intro = App.screen as LevelIntroScreen
	world = App.run.world
	var entries: Array[Dictionary] = intro.hints.duplicate(true)
	await _frames(3)
	for i: int in range(1, entries.size()):
		_tap(&"move_right")
		await _frames(2)
	intro.play_button.pressed.emit()
	await physics_frames(10)
	check(App.screen == null and App.run.world == world and world.player.running and world.player.distance > 0.0,
		"PLAY starts the same prepared world")
	check(App.profile.has_seen("hint/lanes") and App.run.hud.hint_text() == "", "intro hints are remembered without HUD popups")
	App.retry(App.run.context)
	intro = App.screen as LevelIntroScreen
	check(intro != null and intro.hints.is_empty(), "retry retains first-encounter history")
	intro.play_button.pressed.emit()
	App.run.restart()
	check(App.screen is LevelIntroScreen and App.run.state == LevelRun.State.READY,
		"campaign debug restart returns to the reusable introduction")
	Settings.set_value(App.profile, "hints", false)
	App.start_level(App.campaign.step("city/2"))
	intro = App.screen as LevelIntroScreen
	check(intro != null and intro.hints.is_empty(), "hints off keeps the intro but hides hints")
	for entry: Dictionary in entries:
		check(App.profile.has_seen("hint/" + String(entry["id"])), "intro presentation persists " + String(entry["id"]))
	Settings.set_value(App.profile, "hints", true)
	App.start_boss(App.campaign.step("city/boss"))
	intro = App.screen as LevelIntroScreen
	var boss: BossEncounter = App.run.encounter
	var held_time: float = boss.state_time
	await physics_frames(20)
	check(intro != null and is_equal_approx(boss.state_time, held_time),
		"boss introduction holds the fight clock too")
	check(intro != null and intro.hints.any(func(entry: Dictionary) -> bool: return entry["id"] == "city_boss_ceiling"),
		"boss route hints are not lost when runtime cues are suppressed")
	check(intro.hints[0]["id"] == "boss", "new boss concepts precede any unseen arena reminders")
	for id: String in ["lanes", "pickup_shield", "pickup_grapple"]:
		check(not intro.hints.any(func(entry: Dictionary) -> bool: return entry["id"] == id),
			"City boss excludes unrelated " + id)
	App.start_quick()
	check(App.screen == null and App.run.state == LevelRun.State.RUNNING and App.run.intro_hints().is_empty(),
		"debug quick play still starts immediately without hints")
	App.show_title()


func _test_hint_paging() -> void:
	App.profile = SampleProfiles.fresh()
	App.start_level(App.campaign.step("city/1"))
	await _frames(3)
	var intro := App.screen as LevelIntroScreen
	var original_focus: Control = _focus()
	check(intro.page_index == 0 and intro.previous_button.disabled and not intro.next_button.disabled,
		"intro opens on its first page with correct button boundaries")
	check(intro.hint_list.get_child_count() == 2 and intro.page_label.text == "1 / %d" % intro.hints.size(),
		"only one hint and the page counter are presented")
	_tap(&"move_left")
	await _frames(2)
	check(intro.page_index == 0 and _focus() == original_focus, "left boundary clamps without moving PLAY focus")
	tree.root.push_input(_key(KEY_RIGHT))
	await _frames(2)
	check(intro.page_index == 1 and _focus() == original_focus and App.run.state == LevelRun.State.READY,
		"right arrow pages without activating PLAY or moving focus")
	var repeat := _key(KEY_RIGHT)
	repeat.echo = true
	tree.root.push_input(repeat)
	await _frames(2)
	check(intro.page_index == 1, "held-arrow echoes do not skip hint pages")
	_tap(&"move_left")
	await _frames(2)
	check(intro.page_index == 0, "left action returns to the previous page")
	var rebound := _key(KEY_ENTER)
	Settings.bind_key(App.profile, &"move_right", rebound)
	tree.root.push_input(_key(KEY_RIGHT))
	await _frames(2)
	check(intro.page_index == 0, "old arrow binding no longer pages after rebinding")
	intro.play_button.grab_focus()
	tree.root.push_input(rebound)
	await _frames(2)
	check(intro.page_index == 1 and App.screen == intro and App.run.state == LevelRun.State.READY,
		"rebound paging takes precedence over ui_accept on focused PLAY")
	InputMap.load_from_project_settings()
	Settings.reset_bindings(App.profile)
	# Skip several pages in one frame: only the rendered destination becomes presented.
	for i: int in range(2, intro.hints.size()):
		intro.next_button.pressed.emit()
	await _frames(2)
	check(intro.page_index == intro.hints.size() - 1 and intro.next_button.disabled,
		"click/touch NEXT reaches the last page and disables its boundary")
	_tap(&"move_right")
	await _frames(2)
	check(intro.page_index == intro.hints.size() - 1, "right boundary does not wrap")
	intro.previous_button.pressed.emit()
	await _frames(2)
	check(intro.page_index == intro.hints.size() - 2, "click/touch PREVIOUS pages back")
	var expected_seen: Array[String] = []
	for i: int in [0, 1, intro.hints.size() - 2, intro.hints.size() - 1]:
		var id: String = String(intro.hints[i]["id"])
		if not expected_seen.has(id):
			expected_seen.append(id)
	var entries: Array[Dictionary] = intro.hints.duplicate(true)
	var lane: int = App.run.world.player.lane
	intro.play_button.pressed.emit()
	await physics_frames(2)
	check(App.run.world.player.lane == lane, "consumed paging input does not leak into gameplay")
	for entry: Dictionary in entries:
		var id: String = String(entry["id"])
		check(App.profile.has_seen("hint/" + id) == expected_seen.has(id),
			"history includes truly presented pages only: " + id)
	App.retry(App.run.context)
	await _frames(3)
	intro = App.screen as LevelIntroScreen
	check(intro.hints.size() == entries.size() - expected_seen.size(), "retry offers only unvisited pages")
	App.show_title()
	# Empty and single-page cases use the same screen and never navigate into a missing page.
	for count: int in [0, 1]:
		var screen := LevelIntroScreen.new()
		screen.context = RunContext.new()
		screen.context.config = LevelConfig.new()
		if count == 1:
			screen.hints = [{"id": "gap", "text": "Jump the gap."}]
		App.show_screen(screen)
		await _frames(3)
		_tap(&"move_left")
		_tap(&"move_right")
		await _frames(2)
		check(screen.page_index == 0, "%d-page intro safely consumes navigation" % count)
		if count == 1:
			check(screen.previous_button.disabled and screen.next_button.disabled,
				"single-page intro disables both paging buttons")
	App.show_title()


func _die() -> void:
	App.run.world.player.call(&"_die", "Cyborg")
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))


## The screen's layout needs no more room than the viewport has (scroll areas excepted).
func _check_fits(screen: Control, what: String) -> void:
	var viewport: Vector2 = screen.get_viewport_rect().size
	var layout := screen.get_node_or_null(^"SafeArea") as Control
	var need: Vector2 = layout.get_combined_minimum_size() if layout != null else Vector2.ZERO
	check(need.x <= viewport.x + 0.5 and need.y <= viewport.y + 0.5,
		"%s fits the screen (needs %s of %s)" % [what, need, viewport])


## The screen gave one of its controls the focus, and ui_focus_next moves it to another one.
func _check_focus(screen: Control, what: String) -> void:
	var first: Control = _focus()
	check(first != null and screen.is_ancestor_of(first), "%s gives a control the focus (%s)" % [what, first])
	if first == null:
		return
	_tap(&"ui_focus_next")
	await tree.process_frame
	var second: Control = _focus()
	check(second != null and second != first and screen.is_ancestor_of(second),
		"%s: focus moves on to another control (%s → %s)" % [what, first, second])


func _open_and_check(what: String, open: Callable, type: Script, overlay: bool = false) -> Control:
	var previous: Control = App.overlay if overlay else App.screen
	open.call()
	await _frames(3)
	var shown: Control = App.overlay if overlay else App.screen
	check(shown != null and is_instance_of(shown, type), "%s opens (%s)" % [what, shown])
	if previous != null and previous != shown:
		check(not is_instance_valid(previous), "%s: the screen before it is freed" % what)
	if shown != null and is_instance_of(shown, type):
		_check_fits(shown, what)
		await _check_focus(shown, what)
	return shown


# --- Every screen, every size ------------------------------------------------------

func _test_every_screen(tag: String) -> void:
	var screens: Array = [
		["title", func() -> void: App.show_title(), TitleScreen],
		["level select", func() -> void: App.show_level_select(), LevelSelectScreen],
		["shop", func() -> void: App.show_shop(), ShopScreen],
		["shop between levels", func() -> void: App.show_shop(App.show_title, "Next"), ShopScreen],
		["settings", func() -> void: App.show_settings(), SettingsScreen],
		["level intro", func() -> void: App.start_level(App.campaign.step("city/1")), LevelIntroScreen],
		["results", func() -> void: _show_result(true), ResultsScreen],
		["run summary", func() -> void: _show_result(false), ResultsScreen],
		["boss results", func() -> void: _show_boss_result(true), ResultsScreen],
		["boss run summary", func() -> void: _show_boss_result(false), ResultsScreen],
		# The City's boss is built (task E1d), and Gangland's (E4b); the Golden Palace's is still a placeholder card.
		["boss slot", func() -> void: App.play_step(App.campaign.step("golden/boss")), SlotScreen],
		# The zones' intros play their arrival flyovers (task F1); the outros are still placeholder cards.
		["cinematic slot", func() -> void: App.play_step(App.campaign.step("city/outro")), SlotScreen],
		["demo end", func() -> void: App.show_demo_end(), DemoEndScreen],
	]
	for entry: Array in screens:
		await _open_and_check("%s (%s)" % [entry[0], tag], entry[1], entry[2])

	# The overlays over a running level.
	await _start_level("city/1")
	await _open_and_check("pause (%s)" % tag, func() -> void: App.pause_game(), PauseScreen, true)
	var pause := App.overlay as PauseScreen
	if pause != null:
		await _open_and_check("settings over the pause (%s)" % tag, func() -> void: pause.buttons["settings"].pressed.emit(),
			SettingsScreen, true)
		await _open_and_check("back to the pause (%s)" % tag, func() -> void: (App.overlay as ScreenBase).go_back(),
			PauseScreen, true)
	App.resume_game()
	await physics_frames(2)
	var has_revive: bool = App.revive_options()["item"]
	await _die()
	if has_revive:
		var death := App.overlay as DeathScreen
		check(death != null, "the revive offer shows with a revive in stock (%s)" % tag)
		if death != null:
			_check_fits(death, "the revive offer (%s)" % tag)
			await physics_frames(int(DeathScreen.ARM_TIME * 60.0) + 6)
			await _check_focus(death, "the revive offer (%s)" % tag)
		App.decline_revive()
		await _frames(3)
	check(App.screen is ResultsScreen, "a death ends on the run summary (%s)" % tag)
	App.show_title()
	await _frames(2)


# --- Title -----------------------------------------------------------------------

func _test_title() -> void:
	App.show_title()
	await _frames(2)
	var title := App.screen as TitleScreen
	for id: String in ["continue", "levels", "endless", "shop", "settings", "quit"]:
		check(title.buttons.has(id), "the title menu has %s" % id)
	check(title.wallet.value == App.profile.credits(), "the title shows the wallet")
	check(_focus() == title.continue_button, "Continue has the first focus")
	(title.buttons["levels"] as BaseButton).pressed.emit()
	await _frames(2)
	check(App.screen is LevelSelectScreen, "Level select opens the level select")
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	App.show_title()
	await _frames(2)
	title = App.screen as TitleScreen
	check(not title.buttons.has("endless"), "the web demo has no endless mode")
	BuildFlavor.set_override(-1)
	App.profile = SampleProfiles.fresh()
	App.show_title()
	await _frames(2)
	title = App.screen as TitleScreen
	(title.continue_button as BaseButton).pressed.emit()
	await physics_frames(3)
	var first: Cinematic = App.playing_cinematic()
	check(first != null and first.step.id == "city/intro",
		"a new player's Play starts the campaign at its first step (the City's arrival flyover)")
	App.profile = SampleProfiles.rich()


# --- Level select ------------------------------------------------------------------

func _test_level_select() -> void:
	App.show_level_select()
	await _frames(2)
	var levels := App.screen as LevelSelectScreen
	var all: Array[CampaignStep] = App.campaign.steps()
	var missing: int = 0
	for s: CampaignStep in all:
		if not levels.tiles.has(s.id):
			missing += 1
	check(missing == 0, "every campaign step has a tile (%d missing)" % missing)
	check(not (levels.tiles["city/3"] as TileButton).disabled and (levels.tiles["city/boss"] as TileButton).disabled,
		"steps are open up to the next unfinished one, locked after it")
	check(_focus() == levels.tiles["city/3"], "the next step to play has the focus (%s)" % _focus())
	check(levels.tier_buttons.size() == 2, "a second difficulty tier adds the selector (%d)" % levels.tier_buttons.size())
	levels.set_tier(1)
	await _frames(2)
	check((levels.tiles["city/1"] as TileButton).disabled and not (levels.tiles["city/intro"] as TileButton).disabled,
		"the harder tier has its own progress")
	(levels.tiles["city/intro"] as TileButton).pressed.emit()
	await _frames(2)
	App.show_level_select()
	await _frames(2)
	levels = App.screen as LevelSelectScreen
	check(levels.tier == 1, "the chosen tier is kept for the session")
	levels.set_tier(0)
	(levels.tiles["city/1"] as TileButton).pressed.emit()
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "city/1" and App.run.context.difficulty_tier == 0,
		"a level tile starts that level on the chosen tier")
	App.show_title()
	await _frames(1)

	# The web demo: past its zone, tiles lead to the "full game" screen.
	var p: Profile = App.profile
	for s: CampaignStep in all:
		if s.zone == all[0].zone:
			p.record_run(s.id, 0, true, 100, 3, 10.0)
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	App.show_level_select()
	await _frames(2)
	levels = App.screen as LevelSelectScreen
	var first_out: TileButton = levels.tiles.get("gangland/intro")
	check(first_out != null and not first_out.disabled, "the step after the demo's zone is open")
	if first_out != null:
		first_out.pressed.emit()
		await _frames(2)
		check(App.screen is DemoEndScreen, "and leads to the demo's end screen")
	BuildFlavor.set_override(-1)

	# Deep into the six-zone campaign, the list opens on the next step, scrolled into view, at desktop
	# and touch sizes.
	for touch: int in [0, 1]:
		UiTheme.touch_override = touch
		App.profile = SampleProfiles.fresh()
		SampleProfiles.complete_until(App.profile, App.campaign, "golden/2")
		App.show_level_select()
		await _frames(4)
		levels = App.screen as LevelSelectScreen
		var tile: TileButton = levels.tiles.get("golden/2")
		var scroll: ScrollContainer = levels.find_children("*", "ScrollContainer", true, false)[0]
		var tag: String = "touch" if touch == 1 else "desktop"
		check(tile != null and _focus() == tile, "late in the campaign the next step has the focus (%s, %s)" % [_focus(), tag])
		check(tile != null and scroll.get_global_rect().encloses(tile.get_global_rect()),
			"and the list scrolls it into view (%s)" % tag)
		check(levels.tiles.size() == App.campaign.steps().size(), "every step of the six zones has a tile (%s)" % tag)
	UiTheme.touch_override = 0
	App.profile = SampleProfiles.rich()

	# Every shipped zone is built; a zone still to be designed would show as "coming soon".
	var shipped: Campaign = App.campaign
	var trial := Campaign.new()
	var later := ZoneDef.new()
	later.id = &"later"
	later.display_name = "Later Zone"
	later.placeholder = true
	trial.zones.assign([shipped.zones[0], later])
	App.campaign = trial
	App.show_level_select()
	await _frames(2)
	var labels: PackedStringArray = []
	for node: Node in App.screen.find_children("*", "Label", true, false):
		labels.append((node as Label).text)
	check(labels.has("Later Zone · coming soon") and labels.has("ZONE 2"), "a zone still to be designed shows as coming soon")
	App.campaign = shipped
	App.show_level_select()
	await _frames(1)


# --- Shop ------------------------------------------------------------------------

func _test_shop() -> void:
	App.show_shop()
	await _frames(2)
	var shop := App.screen as ShopScreen
	check(shop.cards.size() == App.catalog.items_for(false).size(), "a card for every item sold on PC (%d)" % shop.cards.size())
	var grapple: ItemCard = shop.cards[&"grapple"]
	var shield: ItemCard = shop.cards[&"shield"]
	check(grapple.stock == 1 and grapple.max_stock == 5 and grapple.status_label.text == "STOCK 1/5", "a breakable shows its stock (%s)" % grapple.status_label.text)
	check(shield.state == ItemCard.State.MAXED and not shield.buy_button.visible, "a full stock can't be bought")
	check(_focus() == grapple.buy_button, "the first item that can be bought has the focus (%s)" % _focus())
	var armor: ItemCard = shop.cards[&"armor"]
	check(armor.stock == -1 and armor.tier == 1 and armor.max_tier == 4 and armor.title == "Armor I" and armor.equip_switch.visible
		and armor.get_parent() == shop.cards[&"weapon"].get_parent() and armor.description.begins_with("Next: Armor II."),
		"the armor is a permanent upgrade among the permanent items (GDD §8): %s" % armor.description)
	var price: int = App.catalog.item(&"grapple").price
	var before: int = App.profile.credits()
	heard.clear()
	UiSounds._quiet_until_ms = 0
	grapple.buy_pressed.emit(&"grapple")
	await _frames(2)
	check(App.profile.stock(&"grapple") == 2 and App.profile.credits() == before - price, "buying adds one to the stock")
	check(grapple.stock == 2 and grapple.status_label.text == "STOCK 2/5", "and the card follows (%s)" % grapple.status_label.text)
	check(shop.wallet.value == before - price and shop.wallet.is_counting(), "the wallet counts down to the new balance")
	check(heard.has(&"ui_buy"), "buying plays ui_buy (%s)" % [heard])
	var weapon: ItemCard = shop.cards[&"weapon"]
	check(weapon.tier == 2 and weapon.max_tier == 4 and weapon.icon_name == &"weapon_2", "the weapon shows its tier and tier icon")
	var magnet: ItemCard = shop.cards[&"magnet"]
	check(not magnet.equipped, "an item switched off shows off")
	magnet.equip_toggled.emit(&"magnet", true)
	await _frames(1)
	check(App.profile.is_equipped(&"magnet") and magnet.equipped, "the equip switch switches it back on")
	App.profile.earned = 100
	App.profile_changed.emit()
	await _frames(1)
	check(weapon.state == ItemCard.State.CANT_AFFORD and weapon.buy_button.disabled, "a price over the wallet can't be paid")
	App.profile = SampleProfiles.rich()

	# The way out between runs.
	var left: Array[bool] = [false]
	App.show_shop(func() -> void: left[0] = true, "Retry")
	await _frames(2)
	shop = App.screen as ShopScreen
	check(shop.play_button != null and shop.play_button.text == "RETRY" and _focus() == shop.play_button,
		"between runs the main button carries on (%s)" % (shop.play_button.text if shop.play_button else "none"))
	check(not shop.back_button.visible, "and replaces the back button")
	shop.play_button.pressed.emit()
	check(left[0], "the main button runs on_close")
	shop.menu_button.pressed.emit()
	await _frames(1)
	check(App.screen is TitleScreen, "Menu goes to the title screen")

	# Mobile: no slow time, and credit packs when the platform sells them.
	App.mobile = true
	Platform.configure_for(BuildFlavor.Kind.FULL_MOBILE)
	App.show_shop()
	await _frames(2)
	shop = App.screen as ShopScreen
	check(not shop.cards.has(&"slow_time"), "mobile shops don't sell slow time")
	check(shop.pack_buttons.size() == Platform.products().size() and shop.pack_buttons.size() > 0,
		"mobile shops sell the platform's credit packs (%d)" % shop.pack_buttons.size())
	var bought: int = App.profile.purchased
	if shop.pack_buttons.has(&"credits_small"):
		(shop.pack_buttons[&"credits_small"] as BaseButton).pressed.emit()
		await _frames(3)
		check(App.profile.purchased == bought + 1000, "a credit pack adds bought credits (%d)" % App.profile.purchased)
		check(not (shop.pack_buttons[&"credits_small"] as BaseButton).disabled, "and the packs can be bought again")
	App.mobile = false
	Platform.configure_for(BuildFlavor.current())
	App.profile = SampleProfiles.rich()


# --- Settings --------------------------------------------------------------------

func _test_settings() -> void:
	App.show_settings()
	await _frames(2)
	var settings := App.screen as SettingsScreen
	check(settings.sliders.size() == 3 and settings.toggles.size() == SettingsScreen.TOGGLES.size() and settings.toggles.has("citizens"), "volumes and comfort options (the citizens too)")
	(settings.sliders["music"] as HSlider).value = 0.3
	check(is_equal_approx(float(Settings.value(App.profile, "volume_music")), 0.3), "the music slider sets the music volume")
	var shake := settings.toggles["screen_shake"] as CheckButton
	shake.button_pressed = false
	check(Settings.value(App.profile, "screen_shake") == false, "the screen shake switch turns it off")
	check(settings.key_buttons.size() == Settings.REBINDABLE.size(), "every action can be rebound on PC (%d)" % settings.key_buttons.size())
	var jump: KeyBindButton = settings.key_buttons[&"jump"]
	jump.rebind_requested.emit(&"jump", _key(KEY_J))
	check(SettingsScreen.key_codes(&"jump") == [KEY_J] and jump.text == "J", "a new key replaces the action's keys (%s)" % jump.text)
	var slide: KeyBindButton = settings.key_buttons[&"slide"]
	slide.rebind_requested.emit(&"slide", _key(KEY_J))
	check(SettingsScreen.key_codes(&"slide") == [KEY_J] and SettingsScreen.key_codes(&"jump").is_empty() and jump.text == "—",
		"a key moves from the action that had it")
	settings.call(&"_reset_keys")
	check(SettingsScreen.key_codes(&"jump").has(KEY_SPACE) and jump.text.contains("SPACE"), "Reset keys brings the defaults back")
	# The fonts' license (SIL OFL) is one button away.
	settings.licenses_button.pressed.emit()
	await _frames(1)
	var licenses: String = settings.licenses_label.text if settings.licenses_label != null else ""
	check(licenses.contains("ORBITRON") and licenses.contains("EXO 2") and licenses.count("SIL Open Font License") >= 2
		and not licenses.contains("missing"), "the About card shows both fonts' licenses")
	settings.licenses_button.pressed.emit()
	check(not settings.licenses_label.visible, "and hides them again")
	settings.go_back()
	await _frames(1)
	check(App.screen is TitleScreen, "back leaves the settings (to the title by default)")

	UiTheme.touch_override = 1
	App.show_settings()
	await _frames(2)
	check((App.screen as SettingsScreen).key_buttons.is_empty(), "touch devices have no keys section")
	UiTheme.touch_override = 0
	App.mobile = true
	App.show_settings()
	await _frames(2)
	check(not (App.screen as SettingsScreen).key_buttons.has(&"slow_time"), "no slow time key on mobile")
	App.mobile = false
	Settings.set_value(App.profile, "volume_music", 0.7)
	Settings.set_value(App.profile, "screen_shake", true)


# --- Overlays ---------------------------------------------------------------------

func _test_pause() -> void:
	await _start_level("city/1")
	App.pause_game()
	await _frames(2)
	var pause := App.overlay as PauseScreen
	check(pause != null and pause.progress != null and _focus() == pause.buttons["resume"], "the pause menu shows progress and focuses Resume")
	(pause.buttons["settings"] as BaseButton).pressed.emit()
	await _frames(2)
	var over := App.overlay as SettingsScreen
	check(over != null and over.backdrop == ScreenBase.Backdrop.DIM, "settings open over the paused run, dimming it")
	if over != null:
		(over.toggles["screen_shake"] as CheckButton).button_pressed = false
		check(App.run.world.effects.shake_scale == 0.0, "turning screen shake off applies to the paused run")
		(over.toggles["screen_shake"] as CheckButton).button_pressed = true
		over.go_back()
		await _frames(2)
	pause = App.overlay as PauseScreen
	check(pause != null and tree.paused, "back from the settings to the pause menu, still paused")
	(pause.buttons["restart"] as BaseButton).pressed.emit()
	App.begin_run()
	await physics_frames(3)
	check(App.run != null and App.run.context.attempt == 2 and not tree.paused and App.overlay == null, "Restart starts the level again")
	App.pause_game()
	await _frames(2)
	_tap(&"pause")
	await _frames(2)
	check(not tree.paused and App.overlay == null, "the pause key resumes")
	App.pause_game()
	await _frames(2)
	pause = App.overlay as PauseScreen
	(pause.buttons["quit"] as BaseButton).pressed.emit()
	await _frames(2)
	check(App.run != null and App.overlay == pause, "quitting asks first")
	_tap(&"ui_cancel")
	await _frames(2)
	check(App.run != null and tree.paused and App.overlay == pause, "cancelling the question keeps the run paused")
	(pause.buttons["quit"] as BaseButton).pressed.emit()
	await _frames(2)
	var dialog: ConfirmDialog = pause.get("_quit_dialog")
	check(dialog.message.contains("20%"), "the quit question says the credit share, not that they're all lost (%s)" % dialog.message)
	# FB 14 (decided September 26, 2026): quitting keeps the same credit share as a death.
	App.run.world.score.credits = 100
	var wallet_before: int = App.profile.credits()
	var record_before: Dictionary = App.profile.record("city/1").duplicate()
	var deaths_before: int = int(App.profile.stats.get("deaths", 0))
	dialog.confirm_button.pressed.emit()
	await _frames(2)
	check(App.run == null and App.screen is LevelSelectScreen and not tree.paused, "confirming quits to the level select")
	check(App.profile.credits() == wallet_before + floori(100 * App.rules.death_credit_keep_fraction),
		"quitting pays the wallet %d%% of the run's credits, like a death" % roundi(App.rules.death_credit_keep_fraction * 100.0))
	var record: Dictionary = App.profile.record("city/1")
	check(record.get("completed", false) == record_before.get("completed", false) \
			and record.get("best_score", 0) == record_before.get("best_score", 0) \
			and record.get("stars", 0) == record_before.get("stars", 0) \
			and record.get("best_time", 0.0) == record_before.get("best_time", 0.0),
		"quitting is never a completion and never improves the level's record (%s -> %s)" % [str(record_before), str(record)])
	check(int(record.get("attempts", 0)) == int(record_before.get("attempts", 0)) + 1,
		"quitting still counts as an attempt, like giving up after a death does")
	check(int(App.profile.stats.get("deaths", 0)) == deaths_before, "quitting doesn't count as a death")


func _test_death() -> void:
	App.profile.stocks["revive"] = 2
	await _start_level("city/1")
	await _die()
	var death := App.overlay as DeathScreen
	check(death != null and death.buttons.has("item") and death.buttons.has("give_up") and not death.buttons.has("ad"),
		"PC: the revive offer has the item and give up")
	if death == null:
		return
	check((death.buttons["item"] as BaseButton).disabled, "the buttons ignore input for a moment")
	await physics_frames(int(DeathScreen.ARM_TIME * 60.0) + 6)
	check(not (death.buttons["item"] as BaseButton).disabled and _focus() == death.buttons["item"], "then Revive takes the focus")
	(death.buttons["item"] as BaseButton).pressed.emit()
	await physics_frames(3)
	check(App.overlay == null and App.run.world.player.alive and App.profile.stock(&"revive") == 1, "Revive uses one from stock")
	App.show_title()
	await _frames(1)

	# Mobile: a rewarded ad.
	Platform.configure_for(BuildFlavor.Kind.FULL_MOBILE)
	(Platform.backend as StubBackend).fake_ad_seconds = 0.0
	App.profile.stocks["revive"] = 0
	await _start_level("city/1")
	await _die()
	death = App.overlay as DeathScreen
	check(death != null and death.buttons.has("ad") and not death.buttons.has("item"), "mobile: an ad revive without stock")
	if death != null:
		await physics_frames(int(DeathScreen.ARM_TIME * 60.0) + 6)
		(death.buttons["ad"] as BaseButton).pressed.emit()
		await physics_frames(5)
		check(App.overlay == null and App.run.world.player.alive, "watching the ad revives")
	Platform.configure_for(BuildFlavor.current())
	App.show_title()
	await _frames(1)
	App.profile = SampleProfiles.rich()


func _test_results() -> void:
	var results: ResultsScreen = _show_result(true)
	var revealed: Array[int] = []
	results.stars.star_revealed.connect(func(i: int) -> void: revealed.append(i))
	await _frames(2)
	UiSounds._quiet_until_ms = 0
	heard.clear()
	check(not results.buttons.has("retry") and _focus() == results.buttons["continue"], "a campaign clear offers Continue (focused) and Menu")
	await physics_frames(150)
	check(revealed == [0, 1] and results.stars.stars == 2, "the stars pop in one by one (%s)" % [revealed])
	check(results.score_counter.displayed_value() == 12340 and results.credits_counter.displayed_value() == 540,
		"the score and the credits earned count up (%d, %d)" % [results.score_counter.displayed_value(), results.credits_counter.displayed_value()])
	check(results.new_best.visible, "a new best says so")
	(results.buttons["continue"] as BaseButton).pressed.emit()
	await _frames(1)
	check(App.screen is ShopScreen and (App.screen as ShopScreen).play_label == "Next", "Continue goes to the shop, then the next level")

	results = _show_result(false)
	await _frames(2)
	check(results.buttons.has("retry") and results.stars == null, "a death offers a retry now and no stars")
	(results.buttons["retry"] as BaseButton).pressed.emit()
	await physics_frames(3)
	check(App.run != null and App.run.context.step.id == "city/2" and App.run.context.attempt == 2, "Retry now starts the next attempt")
	results = _show_result(false)
	await _frames(1)
	(results.buttons["menu"] as BaseButton).pressed.emit()
	await _frames(1)
	check(App.screen is LevelSelectScreen, "Menu after a campaign run goes to the level select")


func _test_slots_and_demo_end() -> void:
	App.profile = SampleProfiles.fresh()
	# The City's boss is built (task E1d), and Gangland's (E4b); the Golden Palace's is still a placeholder card.
	App.play_step(App.campaign.step("golden/boss"))
	await _frames(2)
	var slot := App.screen as SlotScreen
	check(slot != null and _focus() == slot.continue_button, "the boss slot focuses Continue")
	if slot == null:
		return
	slot.continue_button.pressed.emit()
	await _frames(2)
	check(App.profile.is_completed("golden/boss") and App.screen is SlotScreen
		and (App.screen as SlotScreen).step.id == "golden/outro", "Continue counts the boss as done and moves on")
	(App.screen as ScreenBase).go_back()
	await _frames(1)
	check(App.screen is LevelSelectScreen, "back returns to the level select")
	App.show_demo_end()
	await _frames(2)
	var end := App.screen as DemoEndScreen
	check(end.store_buttons.size() == Platform.store_names().size() and end.store_buttons.size() > 0,
		"the demo's end links every store (%d)" % end.store_buttons.size())
	end.menu_button.pressed.emit()
	await _frames(1)
	check(App.screen is TitleScreen, "and has a way back to the menu")
	App.profile = SampleProfiles.rich()


# --- HUD -------------------------------------------------------------------------

func _test_hud() -> void:
	var sim := RunSim.new(tree, tuning)
	var loadout := Loadout.new()
	loadout.armor = true
	loadout.charges = {&"shield": 1, &"grapple": 1}
	loadout.tiers = {&"claws": 1}
	var world: RunWorld = sim.build_world(RunSim.layout(5, 400.0), loadout)
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	var hud := RunHud.new()
	tree.root.add_child(hud)
	hud.bind(world, ctx)
	await _frames(2)
	for id: StringName in [&"armor", &"shield", &"grapple"]:
		check(hud.item_icons.has(id), "the HUD shows %s" % id)
	if world.powerups == null:
		check(hud.item_icons.has(&"claws"), "without a power-up controller, owned claws show")
	check((hud.item_icons[&"armor"] as CooldownIcon).count == 1, "with the charges the player carries")

	world.score.add_credit(25)
	await _frames(1)
	check(hud.credits_counter.value == 25 and hud.score_counter.value == 25, "score and credits follow the run")
	world.score.add_bonus(&"kill", 150, "Cyborg")
	await _frames(1)
	var popups: Node = hud.get_node(^"HudRoot/SafeFrame/Score").get_child(2)
	check(popups.get_child_count() == 1 and (popups.get_child(0) as Label).text.contains("Cyborg"), "a bonus pops up")
	check(hud.score_counter.value == 175, "and adds to the score (%d)" % hud.score_counter.value)
	world.player.armor = 0
	world.score.multiplier = 2.0
	world.player.distance = 200.0
	await _frames(1)
	check((hud.item_icons[&"armor"] as CooldownIcon).count == 0, "a broken item shows as spent")
	var badge := hud.get_node(^"HudRoot/SafeFrame/Score").get_child(0).get_child(0) as Control
	check(badge.visible, "the ramp multiplier shows while it's on")
	check(is_equal_approx(hud.progress.value, 0.5), "progress follows the distance (%.2f)" % hud.progress.value)
	hud.show_hint("Jump the gap!")
	hud.set_message("LEVEL COMPLETE")
	await _frames(2)
	check(hud.hint_text() == "Jump the gap!", "hints show")
	var pauses: Array[int] = [0]
	hud.pause_pressed.connect(func() -> void: pauses[0] += 1)
	hud.pause_button.pressed.emit()
	check(pauses[0] == 1, "the pause button asks to pause")

	# Nothing overlaps, and everything is on screen.
	var view := Rect2(Vector2.ZERO, hud.root.get_viewport_rect().size)
	var score_rect: Rect2 = (hud.get_node(^"HudRoot/SafeFrame/Score") as Control).get_global_rect()
	var items_rect: Rect2 = (hud.get_node(^"HudRoot/SafeFrame/Items") as Control).get_global_rect()
	var progress_rect: Rect2 = hud.progress.get_global_rect()
	var hint_rect: Rect2 = (hud.get_node(^"HudRoot/SafeFrame/Hint") as Control).get_global_rect()
	for r: Array in [["score", score_rect], ["items", items_rect], ["progress", progress_rect], ["hint", hint_rect]]:
		check(view.encloses(r[1]), "the HUD's %s is on screen (%s)" % r)
	check(not score_rect.intersects(progress_rect) and not items_rect.intersects(hint_rect) and not score_rect.intersects(items_rect)
		and not progress_rect.intersects(hint_rect) and not score_rect.intersects(hint_rect), "the HUD's parts don't overlap")
	check(absf(hint_rect.get_center().x - view.get_center().x) < 2.0, "the hint sits in the middle")

	# Power-ups report themselves.
	var fake := FakePowerups.new()
	fake.states = [
		{"id": &"dash", "icon": &"dash", "tier": 1, "ready": 0.25, "active": false, "charges": -1},
		{"id": &"slow_time", "icon": &"slow_time", "tier": 1, "ready": 1.0, "active": true, "charges": 2},
		{"id": &"weapon", "icon": &"weapon", "tier": 3, "ready": 1.0, "active": false},
	]
	world.add_child(fake)
	world.powerups = fake
	hud.bind(world, ctx)
	await _frames(2)
	var dash: CooldownIcon = hud.item_icons.get(&"dash")
	var slow: CooldownIcon = hud.item_icons.get(&"slow_time")
	var weapon: CooldownIcon = hud.item_icons.get(&"weapon")
	check(dash != null and absf(dash.charge() - 0.25) < 0.01 and dash.key_hint != "", "a recharging power-up shows its charge and key")
	check(slow != null and slow.active and slow.count == 2, "an active power-up pulses and shows its charges")
	check(weapon != null and weapon.icon_name == &"weapon_3" and weapon.count == -1, "the weapon shows its tier's icon")
	check(not hud.item_icons.has(&"claws"), "with a power-up controller, it decides what shows")
	fake.states[0]["ready"] = 1.0
	await _frames(1)
	check(dash != null and dash.is_ready(), "a power-up that recharged shows ready")

	# Rebinding (a restart) follows the new world only; quick play moves the meter aside.
	var second: RunWorld = sim.build_world(RunSim.layout(5, 400.0), loadout)
	ctx.mode = RunContext.Mode.QUICK
	hud.bind(second, ctx)
	await _frames(1)
	world.score.add_credit(5)
	await _frames(1)
	check(hud.credits_counter.value == 0, "after a rebuild the HUD follows the new world only")
	check(hud.progress.get_parent().name == "Score", "quick play puts the progress meter in the score column")
	var lifted: Rect2 = (hud.get_node(^"HudRoot/SafeFrame/Items") as Control).get_global_rect()
	check(lifted.end.y <= view.size.y - 70.0, "quick play lifts the icons above the debug help (%.0f)" % lifted.end.y)
	hud.queue_free()
	await sim.free_world(world)
	await sim.free_world(second)
