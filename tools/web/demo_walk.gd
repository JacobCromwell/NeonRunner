extends RefCounted
## Walks the web demo (GDD §2) through the App the way a player goes, pressing each screen's own
## buttons: the title's Play, the City's intro slot, its three levels (each run to its finish line),
## the boss intro's slot, the Floating Head (each phase ended by a big hit once it has fought a while,
## then its defeat played out on the track), the outro's slot, and the "get the full game" screen, with
## the results and the shop between steps. Runs are in god mode with falls off (the App's review aids,
## --god --nofall): this walks the flow and what it loads; test_floating_head_defeat.gd plays the fight
## itself.
##   const DemoWalk = preload("res://tools/web/demo_walk.gd")
##   var walk := DemoWalk.new(tree)
##   walk.watch = paths                  # optional: resource paths to look for in ResourceLoader's cache
##   var reached: bool = await walk.walk()
##   walk.steps, walk.screens, walk.offers, walk.problems, walk.loaded
## Along the way it notes every step and screen, anything on a screen that offers ads, purchases or
## leaderboards (GDD §2: the demo has none), and which `watch` resources were loaded, sampled every few
## frames. Used by tests/suites/test_web_demo.gd, and by tools/web/check_pack.gd against the exported
## pack, where any resource the export left out would fail to load.

## Words and icons that offer ads, purchases or leaderboards, on a label, a button or a tooltip.
const OFFER_WORDS: String = "(?i)\\b(ads?|adverts?|advertisements?|leaderboards?|purchases?|in-app|credit packs?)\\b"
const OFFER_ICONS: Array[StringName] = [&"ad", &"leaderboard"]
## At most this many screens and runs between the title and the end screen.
const MAX_STEPS: int = 64
## A level that hasn't finished after this many physics frames is stuck.
const MAX_LEVEL_FRAMES: int = 60 * 60 * 5
## The boss fight's limit, its defeat included (physics frames).
const MAX_BOSS_FRAMES: int = 60 * 60 * 5
## The watched resources are sampled every this many physics frames.
const PROBE_EVERY: int = 10

var tree: SceneTree
## How far a level's runner is carried forward each physics frame, in metres (0: at the real pace).
## Every chunk is still built and every enemy spawns, since the track builds all the way to the runner.
var fast_step: float = 25.0
## Seconds the boss fights in each phase before the walk lands the phase's big hit.
var boss_hold: float = 12.0
## Resource paths to look for in ResourceLoader's cache; `loaded` gets those seen loaded.
var watch: PackedStringArray = []
var loaded: Dictionary = {}
## Campaign step ids played or passed, in order.
var steps: PackedStringArray = []
## The screens seen, by class name, in order.
var screens: PackedStringArray = []
## Offers of ads, purchases or leaderboards found on a screen: "ScreenClass: what".
var offers: PackedStringArray = []
## Whatever went wrong; empty when the walk reached the end screen cleanly.
var problems: PackedStringArray = []
## Each run as it went: "city/1: 5 lanes, 2210 m, 3 stars".
var runs: PackedStringArray = []

var _frame: int = 0
var _offer_re: RegEx


func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	_offer_re = RegEx.create_from_string(OFFER_WORDS)


## Walks from the title screen to the demo's end screen. True if it got there without a problem.
## Needs the main scene in the tree (App.main) and a profile with the campaign not started.
func walk() -> bool:
	var saved_args: PackedStringArray = App._review_args
	App._review_args = PackedStringArray(["--god", "--nofall"])
	App.show_title()
	await _frames(2)
	var title := App.screen as TitleScreen
	var reached: bool = false
	if title == null:
		problems.append("the game doesn't open on the title screen (%s)" % _name(App.screen))
	else:
		see(title)
		title.continue_button.pressed.emit()
		reached = await _follow()
	App._review_args = saved_args
	return reached and problems.is_empty()


## Notes a screen and anything on it that offers ads, purchases or leaderboards.
func see(s: Control) -> void:
	var screen_name: String = _name(s)
	screens.append(screen_name)
	probe()
	for found: String in find_offers(s):
		offers.append("%s: %s" % [screen_name, found])


## What on a screen (or any control) offers ads, purchases or leaderboards: its texts, tooltips and
## icons, and the screens' own ad and credit-pack buttons.
func find_offers(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if root is DeathScreen and (root as DeathScreen).buttons.has("ad"):
		out.append("a rewarded-ad button")
	if root is ShopScreen and not (root as ShopScreen).pack_buttons.is_empty():
		out.append("credit packs for sale")
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var n: Node = nodes.pop_back()
		nodes.append_array(n.get_children())
		var texts := PackedStringArray()
		if n is Label:
			texts.append((n as Label).text)
		elif n is RichTextLabel:
			texts.append((n as RichTextLabel).get_parsed_text())
		elif n is Button:
			texts.append((n as Button).text)
		if n is Control:
			texts.append((n as Control).tooltip_text)
		for text: String in texts:
			if text != "" and _offer_re.search(text) != null:
				out.append("\"%s\"" % text)
		var icon: StringName = &""
		if n is NeonButton:
			icon = (n as NeonButton).icon_name
		elif n is NeonIcon:
			icon = (n as NeonIcon).icon_name
		if OFFER_ICONS.has(icon):
			out.append("the %s icon" % icon)
	return out


## Notes which watched resources are in ResourceLoader's cache now.
func probe() -> void:
	for path: String in watch:
		if not loaded.has(path) and ResourceLoader.has_cached(path):
			loaded[path] = true


## The music tracks the web demo can play: the menus', each demo zone's and its boss's, and the City's
## (quick play's, in debug builds). Music only starts through App._play_music.
static func demo_tracks(campaign: Campaign) -> PackedStringArray:
	var out := PackedStringArray(["menu", "city"])
	for zone: ZoneDef in campaign.zones:
		if not zone.in_demo:
			continue
		for track: StringName in [zone.music, zone.boss.music if zone.boss != null else &""]:
			if track != &"" and not out.has(String(track)):
				out.append(String(track))
	return out


## The sounds the web demo keeps: every sound in the library but the level-complete riffs of tracks it
## never plays (a level ends on the riff in the key of the music playing,
## MusicDirector.level_complete_sound).
static func demo_sounds(sfx: SfxLibrary, tracks: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var prefix: String = String(MusicDirector.LEVEL_COMPLETE) + "_"
	for sound: String in sfx.names():
		if sound.begins_with(prefix) and not tracks.has(sound.trim_prefix(prefix)):
			continue
		out.append(sound)
	return out


# --- The walk ---------------------------------------------------------------------------------

## From the first step to the end screen: plays each run, and on each screen presses the way on.
func _follow() -> bool:
	for i: int in MAX_STEPS:
		await _frames(2)
		if App.screen is DemoEndScreen:
			see(App.screen)
			return true
		if App.run != null:
			if not await _play(App.run):
				return false
			continue
		var s: Control = App.screen
		if s is SlotScreen:
			see(s)
			steps.append((s as SlotScreen).step.id)
			(s as SlotScreen).continue_button.pressed.emit()
		elif s is ResultsScreen:
			see(s)
			var result: RunResult = (s as ResultsScreen).result
			if not result.completed:
				problems.append("%s wasn't completed (%s)" % [result.context.step.id, result.cause])
				return false
			runs[-1] += ", %d stars" % result.stars
			((s as ResultsScreen).buttons["continue"] as BaseButton).pressed.emit()
		elif s is ShopScreen:
			see(s)
			var shop := s as ShopScreen
			if shop.play_button == null:
				problems.append("the shop between steps has no way on")
				return false
			shop.play_button.pressed.emit()
		else:
			problems.append("the flow stopped on %s" % _name(s))
			return false
	problems.append("no end screen after %d steps" % MAX_STEPS)
	return false


## Plays the run until it ends: a level runs to its finish line, a boss fight until the boss is beaten
## and its defeat has played out. True once the run has ended with its results.
func _play(run: LevelRun) -> bool:
	var ctx: RunContext = run.context
	var id: String = ctx.step.id if ctx.step != null else "quick play"
	steps.append(id)
	runs.append("%s: %d lanes, %s" % [id, run.world.geo.lane_count,
		"the %s" % ctx.boss.display_name if ctx.is_boss() else "%d m" % roundi(run.world.layout.length)])
	var limit: int = MAX_BOSS_FRAMES if ctx.is_boss() else MAX_LEVEL_FRAMES
	for i: int in limit:
		# (A freed run compares equal to null, so check it's still there first.)
		if not is_instance_valid(run) or App.run != run:
			return true
		if App.overlay is DeathScreen:
			problems.append("%s: the runner died (%s)" % [id, run.death_cause])
			return false
		if ctx.is_boss():
			var boss: BossEncounter = run.encounter
			if is_instance_valid(boss) and boss.state == BossEncounter.State.FIGHT and boss.state_time >= boss_hold:
				boss.damage(boss.hit_damage(), &"stomp")
		elif fast_step > 0.0 and run.state == LevelRun.State.RUNNING:
			var player: Player = run.world.player
			player.distance = minf(player.distance + fast_step, run.world.layout.length + 1.0)
		await tree.physics_frame
		_frame += 1
		if _frame % PROBE_EVERY == 0:
			probe()
	problems.append("%s didn't end within %d s" % [id, limit / 60])
	return false


func _frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame
	probe()


static func _name(s: Object) -> String:
	if s == null:
		return "nothing"
	var script: Script = s.get_script() as Script
	var global: StringName = script.get_global_name() if script != null else &""
	return String(global) if global != &"" else s.get_class()
