extends TestSuite
## The Beach's volleyball match (the owner, October 10, 2026; VolleyballMatch, a MiniGame), played through the App on
## the real main scene as the campaign's Beach 2, by VolleyballBot through the runner's own actions. Checked:
## - the data: beach/2 is the match (Net Gains, data/minigames/volleyball.tres), between Tiki Tides and Sunset Strip
##   (beach/3), off the curve; its level introduction pages the volleyball hint first;
## - the track: a clear run-in with credits, nothing on it that hurts and no gaps, the side walls open around the
##   court, the court's line, net, rival line and finish in order;
## - the owner's design, at 3, 5 and 6 lanes: the runner runs a couple of seconds, walks up and stops on the line
##   (and stands there through the match); a runner who returns every ball wins every point after
##   returns_to_win_point returns, 4-0, and is paid 400 (100 a point), three stars; one who never moves loses 0-4,
##   paid nothing, one star; one who stands under the ball without jumping takes it on the head (and loses); one who
##   wins N points is paid N × 100; every match ends at 4 points, the net sinks, and the runner crosses the finish
##   line and the level completes (the results: the match's payout as the completion bonus, its stats);
## - fairness: every ball to the runner flies at least the fairness floor for the lanes it leaves them to cross; each
##   ball in a rally comes a little quicker; every arc clears the net; the runner never dies;
## - the jump's timing: a jump within a window of at least MIN_WINDOW seconds around the ring's cue returns the serve,
##   and one far too early doesn't;
## - every attempt plays the same match against the same moves.
## The campaign's own checks of the Beach's levels (Sunset Strip's move, feature ages, saves) are test_campaign's,
## test_beach_levels' and _test_saves here.

const STEP: String = "beach/2"
const LANES: Array[int] = [3, 5, 6]
## The jump's window around the ring's cue (seconds before the ball reaches the runner's line): at least this wide.
const MIN_WINDOW: float = 0.3
## Jump leads tried for the window (seconds before the ball reaches the line).
const LEADS: Array[float] = [-0.1, 0.0, 0.1, 0.2, 0.3, 0.35, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0]

var main: Node


func run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	var lanes_pc: int = App.rules.lanes_pc
	App.profile = Profile.new()

	_test_data()
	for lanes: int in LANES:
		await _test_perfect(lanes)
	await _test_losers()
	await _test_paid_by_points()
	await _test_timing()
	await _test_same_match()
	_test_saves()

	App.rules.lanes_pc = lanes_pc
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


func _test_data() -> void:
	var campaign: Campaign = App.campaign
	var s: CampaignStep = campaign.step(STEP)
	check(s != null and s.is_level() and s.is_minigame(), "beach/2 is a level that plays a mini-game")
	if s == null:
		return
	check(s.level.resource_path == "res://data/levels/beach_2.tres" and String(s.level.id) == "beach_2"
		and s.level.display_name == "Net Gains", "its file, id and name (%s)" % s.level.display_name)
	check(s.level.minigame != null and s.level.minigame.id == &"volleyball" and s.level.minigame.is_built()
		and s.level.minigame.tuning is VolleyballTuning, "it plays the volleyball match, built, with its tuning")
	check(s.level.off_curve and s.level.features.is_empty(), "off the difficulty curve, with no features")
	check(campaign.step("beach/1").title() == "Tiki Tides" and campaign.step("beach/3").title() == "Sunset Strip"
		and campaign.next_step(campaign.step("beach/1")) == s and campaign.next_step(s).id == "beach/3",
		"between Tiki Tides and Sunset Strip, now beach/3")
	var t := s.level.minigame.tuning as VolleyballTuning
	check(t.points_to_win == 4 and t.payout_per_point == 100 and t.returns_to_win_point >= 3 and t.returns_to_win_point <= 4,
		"first to 4 points, 100 credits a point, a point for 3 or 4 returns (the owner's numbers)")
	for i: int in 4:
		check(t.flight_for(i + 1, 1, 0.14) <= t.flight_for(i, 1, 0.14), "each ball of a rally flies no slower (ball %d)" % (i + 1))
	check(t.stars_for(t.points_to_win) == 3 and t.stars_for(0) == 1, "three stars for a win, one for finishing")


## A runner who returns every ball, at `lanes` lanes: the whole level through the App (see the header).
func _test_perfect(lanes: int) -> void:
	var r: Dictionary = await _play(lanes, "perfect")
	var tag: String = "(%d lanes)" % lanes
	var game_tuning: VolleyballTuning = r["tuning"]
	check(r["completed"], "the level completes %s" % tag)
	check(r["hint_first"] == "volleyball", "its introduction pages the volleyball hint first (%s) %s" % [r["hint_first"], tag])
	_check_track(r, tag)
	check(r["won"] == 4 and r["lost"] == 0, "returning every ball wins 4-0 (%d-%d) %s" % [r["won"], r["lost"], tag])
	check(r["returns"] == 4 * game_tuning.returns_to_win_point, "every point after %d returns (%d) %s" % [
		game_tuning.returns_to_win_point, r["returns"], tag])
	check(r["payout"] == 400, "paid 400 credits (%d) %s" % [r["payout"], tag])
	var result: RunResult = r["result"]
	check(result != null and result.completed and result.completion_bonus == 400 and result.stars == 3
		and result.credits_earned == result.credits_kept() + 400,
		"the results: the match's 400 as the completion bonus, three stars %s" % tag)
	check(result != null and int(result.stats.get("points_won", -1)) == 4 and String(result.stats.get("minigame", "")) == "volleyball",
		"and its stats %s" % tag)
	check(result != null and result.credits_collected > 0, "the run-in's credits are collected (%d) %s" % [
		result.credits_collected if result != null else 0, tag])
	var duration: float = App.campaign.step(STEP).level.duration_seconds
	check(absf(r["time"] - duration) <= 5.0, "the level's duration (%.0f s) is a flawless match's length (%.1f s) %s" % [
		duration, r["time"], tag])
	print("  volleyball at %d lanes: a 4-0 match in %.1f s of level (%d balls), stops %.3f m from the line, lowest arc %.2f m over the net" % [
		lanes, r["time"], r["balls"], r["stop_error"], r["lowest_over_net"]])


func _check_track(r: Dictionary, tag: String) -> void:
	var layout: LevelLayout = r["layout"]
	var g: Dictionary = r["geometry"]
	check(layout.gaps.is_empty() and layout.fences.is_empty() and layout.signs.is_empty() and layout.enemies.is_empty()
		and layout.hulls.is_empty() and layout.cuts.is_empty() and layout.wall_fences.is_empty() and layout.doodads.is_empty(),
		"nothing on its track hurts or blocks, and it has no gaps %s" % tag)
	check(not layout.credits.is_empty() and float(layout.credits.back()["at"]) < g["run_in_end"],
		"the run-in has its credits, all before the court %s" % tag)
	var open: int = 0
	for wg: Dictionary in layout.wall_gaps:
		if float(wg["start"]) < g["stand"] - 10.0 and float(wg["end"]) > layout.length:
			open += 1
	check(open == 2, "both side walls open from before the court to past the finish %s" % tag)
	check(g["run_in_end"] > 0.0 and g["stand"] > g["run_in_end"] and g["net"] > g["stand"] and g["rival"] > g["net"]
		and layout.length > g["rival"], "the run-in, the runner's line, the net, the rival's line and the finish, in order %s" % tag)
	check(is_equal_approx(g["run_in_end"], r["run_speed"] * (r["tuning"] as VolleyballTuning).run_in_seconds),
		"a couple of seconds of normal run first (%.1f m) %s" % [g["run_in_end"], tag])
	check(r["stop_error"] < 0.05, "the runner stops on the line (%.3f m off) %s" % [r["stop_error"], tag])
	check(r["moved_in_match"] < 0.001, "and stands there through the match (%.3f m) %s" % [r["moved_in_match"], tag])
	check(r["fair"], "every ball flies at least the fairness floor for its lanes %s" % tag)
	check(r["lowest_over_net"] > 0.05, "every arc clears the net (%.2f m) %s" % [r["lowest_over_net"], tag])
	check(not r["died"], "the runner never dies %s" % tag)
	check(r["net_sunk"], "the net sinks before the runner runs on %s" % tag)


## A runner who never moves loses 0-4 (paid nothing, one star); one who stands under the ball without jumping takes
## it on the head every time.
func _test_losers() -> void:
	var idle: Dictionary = await _play(5, "idle")
	check(idle["completed"] and idle["won"] == 0 and idle["lost"] == 4, "never moving loses 0-4 (%d-%d)" % [idle["won"], idle["lost"]])
	var result: RunResult = idle["result"]
	check(result != null and result.completed and result.completion_bonus == 0 and result.stars == 1,
		"paid nothing, one star for finishing")
	var stand: Dictionary = await _play(5, "stand")
	var bonks: int = 0
	for e: String in stand["events"]:
		bonks += 1 if e == "bonk" else 0
	check(stand["completed"] and stand["lost"] == 4 and bonks == 4,
		"standing under the ball without jumping, it bounces off the runner's head every time (%d of 4)" % bonks)
	var wrong: Dictionary = await _play(5, "wrong")
	check(wrong["completed"] and wrong["lost"] == 4 and wrong["returns"] == 0, "a jump in the wrong lane never reaches it")


## Paid by the points won: one point 100, three 300.
func _test_paid_by_points() -> void:
	for n: int in [1, 3]:
		var r: Dictionary = await _play(5, "points:%d" % n)
		check(r["completed"] and r["won"] == n and r["lost"] == 4 and r["payout"] == n * 100,
			"winning %d point%s pays %d (%d-%d, paid %d)" % [n, "" if n == 1 else "s", n * 100, r["won"], r["lost"], r["payout"]])


## The jump's window: the serve is returned by a jump within at least MIN_WINDOW seconds around the ring's cue.
func _test_timing() -> void:
	var hits: Array[float] = []
	for lead: float in LEADS:
		var r: Dictionary = await _play(5, "perfect", lead, true)
		if r["first"] == "hit":
			hits.append(lead)
	var cue: float = (App.campaign.step(STEP).level.minigame.tuning as VolleyballTuning).jump_lead_seconds
	check(hits.has(cue) or hits.any(func(l: float) -> bool: return absf(l - cue) < 0.06),
		"a jump on the ring's cue returns the serve")
	var low: float = hits.min() if not hits.is_empty() else 0.0
	var high: float = hits.max() if not hits.is_empty() else 0.0
	check(high - low >= MIN_WINDOW, "the jump's window is at least %.2f s (%.2f-%.2f s before the ball)" % [MIN_WINDOW, low, high])
	check(not hits.has(LEADS[-1]), "a jump far too early (%.1f s) misses" % LEADS[-1])
	print("  volleyball serve returned by a jump %.2f-%.2f s before it reaches the runner's line" % [low, high])


## Every attempt plays the same match against the same moves.
func _test_same_match() -> void:
	var a: Dictionary = await _play(5, "points:2")
	var b: Dictionary = await _play(5, "points:2")
	check(a["events"] == b["events"] and not (a["events"] as PackedStringArray).is_empty(),
		"the same match on every attempt (%d events)" % (a["events"] as PackedStringArray).size())


## A save from before the match (version 3): Sunset Strip's records move from beach/2 to beach/3, the new beach/2 is
## open and Continue leads to it.
func _test_saves() -> void:
	var p := Profile.new()
	for s: CampaignStep in App.campaign.steps():
		p.record_run(s.id, 0, true, 5000 if s.is_level() else 0, 2 if s.is_level() else 3, 100.0)
		if s.id == "beach/2":
			break
	var d: Dictionary = p.to_dict()
	d["version"] = 3
	var old_record: Dictionary = (d["records"] as Dictionary).get("0/beach/2", {})
	var loaded: Profile = Profile.from_dict(d)
	check(not old_record.is_empty() and loaded.records.has("0/beach/3") and not loaded.records.has("0/beach/2"),
		"a version 3 save's beach/2 record (Sunset Strip) becomes beach/3's")
	var keep: Profile = App.profile
	App.profile = loaded
	check(App.step_unlocked(App.campaign.step("beach/2")) and App.next_unfinished_step() == App.campaign.step("beach/2"),
		"the new Beach 2 is open, and Continue leads to it")
	check(App.step_unlocked(App.campaign.step("beach/3")), "Sunset Strip stays open")
	App.profile = keep


## Plays the level through the App at `lanes` lanes with a bot of `skill`; `lead` overrides the bot's jump timing,
## `first_ball` stops at the first ball's outcome. What happened, in a dictionary.
func _play(lanes: int, skill: String, lead: float = -1.0, first_ball: bool = false) -> Dictionary:
	App.rules.lanes_pc = lanes
	App.start_level(App.campaign.step(STEP))
	var out: Dictionary = {"completed": false, "won": 0, "lost": 0, "returns": 0, "payout": 0, "events": PackedStringArray(),
		"result": null, "died": false, "fair": true, "stop_error": INF, "moved_in_match": 0.0, "balls": 0, "time": 0.0,
		"lowest_over_net": INF, "net_sunk": false, "first": "", "hint_first": ""}
	var hints: Array[Dictionary] = App.run.intro_hints()
	out["hint_first"] = String(hints[0]["id"]) if not hints.is_empty() else ""
	App.begin_run()
	await physics_frames(2)
	var game := App.run.minigame as VolleyballMatch
	if game == null:
		check(false, "the level runs a volleyball match")
		return out
	out["tuning"] = game.tuning
	out["layout"] = App.run.world.layout
	out["run_speed"] = game.run_speed
	out["lane_switch"] = App.run.world.tuning.lane_switch_time
	out["geometry"] = {"run_in_end": game.run_in_end, "stand": game.stand, "net": game.net_at, "rival": game.rival_at}
	var bot := VolleyballBot.new(game, skill)
	bot.jump_lead = lead
	var world: RunWorld = App.run.world
	var stand_at: float = NAN
	for i: int in 60 * 150:
		if not is_instance_valid(game) or App.run == null:
			break
		bot.step()
		await tree.physics_frame
		if not is_instance_valid(game):
			break
		var p: Player = world.player
		out["died"] = out["died"] or not p.alive
		if game.phase == VolleyballMatch.Phase.INTRO and is_nan(stand_at):
			stand_at = p.distance
			out["stop_error"] = absf(p.distance - game.stand)
		if not is_nan(stand_at) and game.phase in [VolleyballMatch.Phase.PLAY, VolleyballMatch.Phase.POINT]:
			out["moved_in_match"] = maxf(out["moved_in_match"], absf(p.distance - stand_at))
		out["won"] = game.points_won
		out["lost"] = game.points_lost
		out["returns"] = game.total_returns
		out["payout"] = game.payout()
		out["events"] = game.events.duplicate()
		out["lowest_over_net"] = game.lowest_over_net
		out["time"] = p.elapsed
		if game.phase == VolleyballMatch.Phase.DONE:
			out["net_sunk"] = game.court.sunk()
		if first_ball:
			for e: String in game.events:
				if e == "hit" or e == "drop" or e == "bonk":
					out["first"] = e
					break
			if out["first"] != "":
				break
		if App.screen is ResultsScreen:
			break
	if first_ball:
		App.quit_run()
		await tree.process_frame
		return out
	# The results follow the finish (LevelRun.COMPLETE_PAUSE).
	for i: int in 60 * 4:
		if App.screen is ResultsScreen:
			break
		await tree.physics_frame
	await tree.process_frame
	var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	out["result"] = result
	out["completed"] = result != null and result.completed
	var balls: int = 0
	for e: String in out["events"]:
		if not e.begins_with("to_runner:"):
			continue
		balls += 1
		var parts: PackedStringArray = e.split(":")
		var lanes_crossed: int = absi(int(parts[1]) - int(parts[2]))
		var t: VolleyballTuning = out["tuning"]
		if float(parts[3]) + 0.006 < t.fair_flight(lanes_crossed, float(out["lane_switch"])):
			out["fair"] = false
	out["balls"] = balls
	return out
