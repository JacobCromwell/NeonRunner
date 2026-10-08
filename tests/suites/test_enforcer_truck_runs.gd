extends TestSuite
## The Enforcer Truck on real physics (GDD §9.13; task C6), at 3, 5 and 6 lanes and at quick play's 18 m/s
## and Corporate 2's 23.4 m/s (with its enemy scaling). Its numbers, look, core hooks and placement are
## test_enforcer_truck.gd's.
## - It follows: it copies each of the runner's lane changes lane_delay_seconds later, and is never closer
##   behind them than its MIN_GAP.
## - Its volleys: a runner who stays in the lane is hit by its laser, and not before the warning (the red
##   line and the whine) and a bolt's flight; over a whole chase, a scripted runner (no armor) who steps
##   aside a reaction after each warning is never hit, the line shows exactly while a volley is on, with no
##   riders it fires every volley_interval_seconds from the last volley's end, and it gives up after
##   chase_seconds (never mid-volley), fires no more, drops back with its marker fading and leaves play.
## - Turns (GDD §9): a volley due while another type's big attack is on waits for it, and another type's
##   attack that gets ready during a volley waits for the volley's end (tests/helpers/turn_dummy.gd).
## - Its baits: an Octodog's lunge dodged as it begins and a Buzz Overdrive's charge left half a second
##   before it meets the runner each destroy it, the player's kill with rider_bonus for each rider aboard;
##   dodged early, it survives. It closes right up for the Octodog's attack, and no volley is on during an
##   Octodog's wind-up or lunge or a Buzz Overdrive's rev or charge, big attacks taking turns or not.
##   AttackWatch follows its volleys and what destroyed it, and finds no overlap.
## - Holes: led late around a Buzz Overdrive's cut (the tank shot down mid-charge) or a gap too wide to hop,
##   it's wrecked, the player's kill; it hops an ordinary gap the runner jumps.
## - Riders: cyborgs the runner passes alive in its lane board it, at most 3 (never one in another lane,
##   one killed, a window cyborg or a host), shown on its roof and its marker, and its next volley comes
##   volley_interval(3) after the last.
## - It plays the same on every attempt.
## - Its blast (the owner, October 8, 2026: every way it's destroyed ends in a visible explosion): destroyed by an
##   Octodog's lunge, a Buzz Overdrive's charge, a gap too wide to hop or a Buzz Overdrive's cut, it blows up a
##   lurch later (wreck_surge_seconds at most) with its sound, the run camera sees its fireball, and no puff of it
##   ever stands between that camera and the runner (EnforcerTruckView).
## - Showing itself (GDD §9.13, the owner, October 8, 2026), with the runs above playing without it: as it arrives
##   and once more mid-chase, show_seconds alongside in a lane beside the runner's, its whole look on screen hiding
##   nothing of the runner, then back to its follow gap and the runner's lane, never firing meanwhile, its marker
##   faded and its siren swelling, its volleys still coming; its sides bump a lane change back without hurting
##   and it gives way; it never takes the only free lane (zone doodads at 3, 5 and 6 lanes) nor shows itself to a
##   runner in an outer lane; another type's big attack on keeps it back and one that gets ready waits for its
##   showing; a bait close behind its arrival keeps it back, a later one shortens its stay; its baits still destroy
##   it after it has shown itself; and it plays the same on every attempt.
## - Corporate 2's own build at 3, 5 and 6 lanes, played to its end by a scripted runner (god mode,
##   grapples; it keeps to the middle lane like AttackWatch's) that baits each charge while a truck chases:
##   every truck that comes is destroyed by a charge the runner dodged, no other type's big attack is open
##   during a volley, and it never fires while it shows itself nor comes closer than MIN_GAP in the runner's lane
##   (the showings it makes there are printed).

const Rules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const BuzzScript = preload("res://scripts/enemies/buzz_overdrive.gd")
const AttackWatch = preload("res://tools/measure/attack_watch.gd")
const TURN_DUMMY: String = "res://tests/helpers/turn_dummy.gd"
const LANES: Array[int] = [3, 5, 6]

var sim: RunSim
var t: EnforcerTruckTuning
## [run speed, enemy scaling]: quick play's (the base tuning, no scaling) and Corporate 2's.
var paces: Array = []
## One physics frame (seconds).
var frame: float = 1.0 / 60.0


## The scripted runner of these runs: it holds the lane `home` (one step at a time, a step at most every
## STEP_SECONDS), and steps out of each volley's lane a reaction after its warning
## (EnforcerTruckTuning.escape_reaction_seconds) into a lane beside that's open (EnforcerTruck.lane_open,
## as the truck's escape check), toward `home` where it can. It never steps into a lane a volley sweeps.
class Runner:
	const STEP_SECONDS: float = 0.3
	var w: RunWorld
	var home: int = 0
	var _next: float = -INF

	func _init(p_world: RunWorld) -> void:
		w = p_world
		home = w.player.lane

	## Called once a frame, before the physics step.
	func step(truck: EnforcerTruck) -> void:
		var p: Player = w.player
		if not p.alive or not p.running or p.surface != Player.Surface.FLOOR:
			return
		var want: int = home
		if truck != null and is_instance_valid(truck) and truck.alive and truck.volley != EnforcerTruck.Volley.IDLE:
			var swept: int = truck.volley_lane
			if p.lane == swept:
				if truck.volley == EnforcerTruck.Volley.WARNING \
						and float(truck.get(&"_volley_t")) < truck.tuning.escape_reaction_seconds - 0.0001:
					return
				want = _escape(truck, swept)
			elif want == swept or (want - p.lane) * (swept - p.lane) > 0:
				want = p.lane
		if want == p.lane or w.level_time() < _next:
			return
		_next = w.level_time() + STEP_SECONDS
		p.press(&"move_right" if want > p.lane else &"move_left")

	## The lane beside `swept` to escape into: open until the volley is over, toward `home` first.
	func _escape(truck: EnforcerTruck, swept: int) -> int:
		var v: float = maxf(w.player.speed, 1.0)
		var from: float = w.player.distance
		var to: float = from + truck.tuning.volley_seconds() * v + 2.0
		var toward: int = 1 if home > swept else -1
		for l: int in [swept + toward, swept - toward]:
			if l >= 0 and l < w.geo.lane_count and truck.lane_open(l, from, to):
				return l
		return swept


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = Rules.tuning()
	frame = 1.0 / float(Engine.physics_ticks_per_second)
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var c2: LevelConfig = campaign.configure(campaign.step("corporate/2"), 3)
	paces = [[tuning.run_speed, 0.0], [c2.movement_for(tuning).run_speed, c2.enemy_scaling]]
	await _test_follows()
	await _test_volley_hits_who_stays()
	await _test_whole_chase()
	await _test_turns()
	await _test_octodog_bait()
	await _test_buzz_bait()
	await _test_holes()
	await _test_riders()
	await _test_same_every_attempt()
	await _test_shows()
	await _test_show_bump()
	await _test_show_fairness()
	await _test_show_turns()
	await _test_show_baits()
	await _test_show_same_every_attempt()
	await _test_corporate_2()


# --- Helpers -------------------------------------------------------------------------------------

func _mt(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var out: MovementTuning = tuning.duplicate() as MovementTuning
	out.run_speed = speed
	return out


func _tag(lanes: int, pace: Array) -> String:
	return "(%d lanes, %.1f m/s)" % [lanes, float(pace[0])]


## A plain track of `lanes` lanes whose truck arrives as the run starts.
func _layout(lanes: int, length: float = 1400.0) -> LevelLayout:
	var layout := RunSim.layout(lanes, length)
	layout.enemies.append({"type": "enforcer_truck", "at": 1.0, "lane": lanes / 2, "side": 0, "seed": 7, "params": {}})
	return layout


## A world on `layout` at `pace` ([run speed, enemy scaling]), the runner in the middle lane without armor,
## big attacks taking turns or not. `edit` changes each truck's own copy of its tuning as it comes into play.
func _world(layout: LevelLayout, pace: Array, edit: Callable = Callable(), turns: bool = true) -> RunWorld:
	var config := LevelConfig.new()
	config.enemy_scaling = float(pace[1])
	var w: RunWorld = sim.build_world(layout, Loadout.new(), _mt(float(pace[0])), config)
	w.player.armor = 0
	if not turns:
		w.rules = w.rules.duplicate() as GameRules
		w.rules.big_attacks_take_turns = false
	if edit.is_valid():
		var apply := func(e: Enemy) -> void:
			if e is EnforcerTruck:
				var truck := e as EnforcerTruck
				truck.tuning = truck.tuning.duplicate() as EnforcerTruckTuning
				edit.call(truck.tuning)
		for e: Variant in w.director.active:
			if is_instance_valid(e):
				apply.call(e)
		w.director.enemy_spawned.connect(apply)
	return w


func _no_volleys(tt: EnforcerTruckTuning) -> void:
	tt.first_volley_seconds = 999.0


## No showings (GDD §9.13 "Showing itself"): the runs that check its chase, volleys, baits, holes and riders as
## they were (its showings have runs of their own, and Corporate 2's run plays them with the rest).
func _no_shows(tt: EnforcerTruckTuning) -> void:
	tt.show_count = 0


func _plain(tt: EnforcerTruckTuning) -> void:
	_no_volleys(tt)
	_no_shows(tt)


func _start(w: RunWorld) -> void:
	await tree.physics_frame
	w.player.running = true


## The first enemy of `type` in play (alive or not, until it's freed), or null.
func _first(w: RunWorld, type: StringName) -> Enemy:
	for e: Variant in w.director.active:
		if is_instance_valid(e) and (e as Enemy).type_id == type:
			return e as Enemy
	return null


func _truck(w: RunWorld) -> EnforcerTruck:
	return _first(w, &"enforcer_truck") as EnforcerTruck


## True if `e` holds an object not freed yet (a freed one may compare equal to null).
static func _valid(e: Variant) -> bool:
	return is_instance_valid(e)


## How many of `truck`'s history events are `event`.
static func _count(truck: EnforcerTruck, event: String) -> int:
	var n: int = 0
	for h: Array in truck.history:
		if String(h[0]) == event:
			n += 1
	return n


## The riders shown on its roof.
static func _shown_riders(truck: EnforcerTruck) -> int:
	var n: int = 0
	for r: Node3D in truck.model.riders:
		if r.visible:
			n += 1
	return n


## The lane beside `lane` to step into, toward the middle where there is one.
static func _beside(lane: int, lanes: int) -> int:
	return lane - 1 if lane > 0 and (lane >= lanes / 2 or lane == lanes - 1) else lane + 1


## Watches `truck`'s wreck from the frame it's destroyed until it's gone (the owner, October 8, 2026: every way
## it's destroyed ends in a visible explosion): {blast (it blew up), explode (the blast's sound), lurch (seconds
## from its wreck to its blast), puffs (frames its fireball showed), seen (frames a puff's upper half was on
## screen in the run camera's resting view of the runner, EnforcerTruckView), covers (a puff ever stood between
## that camera and the runner), at (where it went off)}.
func _watch_blast(w: RunWorld, truck: EnforcerTruck) -> Dictionary:
	var out := {"blast": false, "explode": false, "lurch": -1.0, "seen": 0, "covers": false, "puffs": 0}
	var wrecked: float = w.level_time()
	for i: int in int(3.0 / frame):
		if not _valid(truck):
			break
		var blast: EnforcerTruckBlast = truck.get(&"_blast") as EnforcerTruckBlast
		if not bool(out["blast"]) and _count(truck, "blast") > 0:
			out["blast"] = true
			out["lurch"] = w.level_time() - wrecked
			out["at"] = "went off %.2f m behind the runner, %.2f m up, %.2f m across" % [w.player.distance
				+ blast.global_position.z, blast.global_position.y, blast.global_position.x - w.player.position.x]
		if bool(out["blast"]) and blast.visible:
			var spheres: Array[Vector4] = blast.spheres()
			if not spheres.is_empty():
				out["puffs"] = int(out["puffs"]) + 1
			var view := EnforcerTruckView.of_runner(w.tuning, w.geo, w.player.lane, w.player.distance)
			var on: bool = false
			for sphere: Vector4 in spheres:
				var c: Vector3 = truck.global_transform * Vector3(sphere.x, sphere.y, sphere.z)
				on = on or view.on_screen(c + Vector3(0.0, sphere.w * 0.5, 0.0), 0.0)
				for p: Vector3 in EnforcerTruckView.runner_points(w.tuning, w.player.position.x, w.player.distance):
					if _segment_hits_sphere(view.origin, p, c, sphere.w):
						if not bool(out["covers"]):
							out["covered"] = "puff (%.2f, %.2f, %.2f behind) r %.2f, runner point (%.2f, %.2f), t %.2f" % [
								c.x - w.player.position.x, c.y, w.player.distance + c.z, sphere.w, p.x - w.player.position.x, p.y,
								blast.t]
						out["covers"] = true
			if on:
				out["seen"] = int(out["seen"]) + 1
		out["explode"] = truck.sounds_played.has(&"truck_explode")
		await tree.physics_frame
	return out


## True if the segment from `a` to `b` passes within `radius` of `c`.
static func _segment_hits_sphere(a: Vector3, b: Vector3, c: Vector3, radius: float) -> bool:
	var ab: Vector3 = b - a
	var k: float = clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * k).distance_to(c) < radius


## The blast's own checks for a run's result (_watch_blast).
func _check_blast(tag: String, kind: String, r: Dictionary) -> void:
	check(bool(r.get("blast", false)) and bool(r.get("explode", false)) and float(r.get("lurch", -1.0)) <= t.wreck_surge_seconds + 0.05,
		"%s %s: it blows up %.2f s after it's hit, with its sound" % [tag, kind, float(r.get("lurch", -1.0))])
	check(int(r.get("puffs", 0)) > 0 and int(r.get("seen", 0)) >= int(r.get("puffs", 0)) * 3 / 4 and not bool(r.get("covers", true)),
		"%s %s: the camera sees its fireball (%d of %d frames), never in front of the runner (%s) %s" % [tag, kind,
		int(r.get("seen", 0)), int(r.get("puffs", 0)), r.get("at", ""), r.get("covered", "")])


# --- Following ------------------------------------------------------------------------------------

## It copies each of the runner's lane changes lane_delay_seconds later (to a frame), quick ones included,
## ends up in their lane, and never comes closer than MIN_GAP.
func _test_follows() -> void:
	for lanes: int in LANES:
		for pace: Array in paces:
			var tag: String = _tag(lanes, pace)
			var w: RunWorld = _world(_layout(lanes), pace, _plain)
			await _start(w)
			var steps: Array = [[1.0, &"move_left"], [3.0, &"move_right"], [3.25, &"move_right"], [5.5, &"move_left"]]
			var truck: EnforcerTruck = null
			var moves: Array[float] = []
			var follows: Array[float] = []
			var runner_lane: int = w.player.lane
			var target: int = -1
			var since: float = -1.0
			var min_gap: float = INF
			for i: int in int(14.0 / frame):
				await tree.physics_frame
				if truck == null:
					truck = _truck(w)
				if truck == null or truck.state != EnforcerTruck.State.CHASING:
					continue
				if since < 0.0:
					since = w.level_time()
					target = truck.target_lane
				var now: float = w.level_time() - since
				while not steps.is_empty() and now >= float(steps[0][0]):
					w.player.press(steps.pop_front()[1])
				if w.player.lane != runner_lane:
					runner_lane = w.player.lane
					moves.append(w.level_time())
				if truck.target_lane != target:
					target = truck.target_lane
					follows.append(w.level_time())
				min_gap = minf(min_gap, truck.gap)
				if steps.is_empty() and now > 8.0:
					break
			var delays: PackedStringArray = []
			var on_time: bool = moves.size() == 4 and follows.size() == 4
			for k: int in mini(moves.size(), follows.size()):
				var d: float = follows[k] - moves[k]
				delays.append("%.3f" % d)
				on_time = on_time and absf(d - t.lane_delay_seconds) <= 1.5 * frame
			check(since > 0.0 and on_time, "%s it takes each of the runner's 4 lane changes %.1f s later (%s)" % [tag,
				t.lane_delay_seconds, ", ".join(delays)])
			var settled: bool = truck != null and truck.lane == w.player.lane \
				and absf(truck.global_position.x - w.geo.lane_x(w.player.lane)) < 0.01
			check(settled, "%s and ends up in their lane" % tag)
			check(min_gap >= EnforcerTruck.MIN_GAP - 0.001 and min_gap >= t.follow_gap - 0.5,
				"%s it keeps its gap behind them (closest %.2f m)" % [tag, min_gap])
			await sim.free_world(w)


# --- Volleys --------------------------------------------------------------------------------------

## A runner who stays in its lane is hit by its laser: its first volley, warned by its line and its whine
## (in that lane) warning_seconds before its first shot, whose bolts reach the runner a flight later.
func _test_volley_hits_who_stays() -> void:
	for lanes: int in LANES:
		for pace: Array in paces:
			var tag: String = _tag(lanes, pace)
			var w: RunWorld = _world(_layout(lanes), pace, _no_shows)
			var cause: Array[String] = [""]
			w.player.died.connect(func(c: String) -> void: cause[0] = c)
			await _start(w)
			var truck: EnforcerTruck = null
			var warned: float = -1.0
			var line_then: bool = false
			var whine_then: bool = false
			var lane_then: int = -1
			var hit: float = -1.0
			for i: int in int(12.0 / frame):
				await tree.physics_frame
				if truck == null:
					truck = _truck(w)
				if truck != null and warned < 0.0 and truck.volley == EnforcerTruck.Volley.WARNING:
					warned = w.level_time()
					line_then = (truck.get_node(^"WarningLine") as Node3D).visible
					whine_then = truck.sounds_played.has(&"enforcer_whine")
					lane_then = truck.volley_lane
				if not w.player.alive:
					hit = w.level_time()
					break
			check(warned > 0.0 and line_then and whine_then and lane_then == w.player.lane,
				"%s its volley is warned by the red line and the whine, in the runner's lane" % tag)
			var after: float = hit - warned
			check(hit > 0.0 and cause[0] == EnforcerTruck.LASER_NAME, "%s a runner who stays is hit by its laser (%s)" % [tag, cause[0]])
			check(after >= t.warning_seconds + 0.8 * t.bolt_flight_seconds and after <= t.volley_seconds(),
				"%s not before the warning and a bolt's flight: %.2f s after the warning (%.2f s + %.2f s)" % [tag, after,
				t.warning_seconds, t.bolt_flight_seconds])
			await sim.free_world(w)


## A whole chase, the scripted runner (no armor) stepping aside a reaction after each warning: it's never
## hit; the line shows exactly while a volley is on and each volley's whine plays; with no riders each
## volley comes volley_interval(0) after the last one's end; it gives up after chase_seconds (never with a
## volley on), fires no more, drops back with its marker fading, and leaves play.
func _test_whole_chase() -> void:
	for lanes: int in LANES:
		for pace: Array in paces:
			var tag: String = _tag(lanes, pace)
			var w: RunWorld = _world(_layout(lanes), pace, _no_shows)
			await _start(w)
			var bot := Runner.new(w)
			var truck: EnforcerTruck = null
			var found: bool = false
			var warns: Array[float] = []
			var ends: Array[float] = []
			var was: int = EnforcerTruck.Volley.IDLE
			var line_right: bool = true
			var left: float = -1.0
			var left_clock: float = -1.0
			var volleys_then: int = -1
			var volleys: int = 0
			var whines: int = 0
			var shown: float = 1.0
			var fades: bool = true
			var gone: float = -1.0
			for i: int in int(40.0 / frame):
				bot.step(truck if found and is_instance_valid(truck) else null)
				await tree.physics_frame
				if not found:
					truck = _truck(w)
					found = truck != null
					continue
				if not is_instance_valid(truck) or not w.director.active.has(truck):
					gone = w.level_time()
					break
				volleys = truck.volleys
				whines = truck.sounds_played.count(&"enforcer_whine")
				var now: float = w.level_time()
				if truck.volley != was:
					if was == EnforcerTruck.Volley.IDLE:
						warns.append(now)
					elif truck.volley == EnforcerTruck.Volley.IDLE:
						ends.append(now)
					was = truck.volley
				line_right = line_right and (truck.get_node(^"WarningLine") as Node3D).visible == (truck.volley != EnforcerTruck.Volley.IDLE)
				if truck.state == EnforcerTruck.State.LEAVING:
					if left < 0.0:
						left = now
						left_clock = float(truck.get(&"_clock"))
						volleys_then = truck.volleys
					fades = fades and truck.marker.shown <= shown + 0.0001
					shown = truck.marker.shown
				if not w.player.alive:
					break
			check(w.player.alive and warns.size() >= 4 and ends.size() == warns.size(),
				"%s a runner stepping aside at each warning is never hit (%d volleys over the chase; %s)" % [tag, warns.size(),
				w.player.last_event])
			check(line_right, "%s its line shows exactly while a volley is on" % tag)
			check(whines == warns.size() and volleys == warns.size(), "%s each volley's whine plays (%d)" % [tag, whines])
			var gaps: PackedStringArray = []
			var regular: bool = true
			for k: int in range(1, warns.size()):
				var d: float = warns[k] - ends[k - 1]
				gaps.append("%.2f" % d)
				regular = regular and absf(d - t.volley_interval(0)) <= 2.0 * frame
			check(regular, "%s with no riders a volley comes %.1f s after the last one's end (%s)" % [tag,
				t.volley_interval(0), ", ".join(gaps)])
			check(left > 0.0 and left_clock >= t.chase_seconds - 0.001 and left_clock <= t.chase_seconds + t.volley_seconds() + 2.0 * frame,
				"%s it gives up after its chase, never mid-volley (at %.2f s)" % [tag, left_clock])
			check(volleys_then == volleys and fades and shown < 0.05,
				"%s then it fires no more and drops back, its marker fading (%.2f)" % [tag, shown])
			var drop: float = (t.gone_gap - t.follow_gap) / t.leave_speed
			check(gone > 0.0 and gone - left <= drop + 0.5, "%s and leaves play (%.1f s after giving up)" % [tag, gone - left])
			await sim.free_world(w)


# --- Turns ----------------------------------------------------------------------------------------

## GDD §9: its volleys take turns with the other types' big attacks (tests/helpers/turn_dummy.gd): one due
## while another type's attack is on waits for it (held for its turn), and another type's attack that gets
## ready during a volley waits for the volley's end. Never both at once.
func _test_turns() -> void:
	for case: Array in [[3, paces[0]], [6, paces[1]]]:
		var tag: String = _tag(case[0], case[1])
		# Another type's attack is on as its first volley comes due.
		var w: RunWorld = _world(_layout(case[0]), case[1], _no_shows)
		w.player.god_mode = true
		await _start(w)
		var truck: EnforcerTruck = null
		var other: Enemy = null
		var held: bool = false
		var both: bool = false
		var warned: float = -1.0
		var warn_clock: float = -1.0
		for i: int in int(14.0 / frame):
			await tree.physics_frame
			if truck == null:
				truck = _truck(w)
			if truck == null or truck.state == EnforcerTruck.State.WAITING or truck.state == EnforcerTruck.State.ARRIVING:
				continue
			if other == null:
				other = w.director.spawn({"type": "blocker", "script": TURN_DUMMY, "at": 0.0, "lane": 0, "side": 0, "seed": 1,
					"params": {"first": 0.3, "warning": 1.5, "attack": 2.5, "interval": 99.0}})
			held = held or w.director.held_for_turn(truck)
			both = both or (truck.is_major_attack_active() and other.is_major_attack_active())
			if warned < 0.0 and truck.volley != EnforcerTruck.Volley.IDLE:
				warned = w.level_time()
				warn_clock = float(truck.get(&"_clock"))
			if warned > 0.0 and truck.volley == EnforcerTruck.Volley.IDLE:
				break
		var spans: Array = other.call(&"spans") if other != null else []
		var other_end: float = float(spans[0][1]) if not spans.is_empty() else INF
		check(held and warned >= other_end - frame and warn_clock > t.first_volley_seconds + 1.0,
			"%s a volley due while another type's big attack is on waits for its end (held, warned %.2f s, %.2f s into its chase; the other's end %.2f s)"
			% [tag, warned, warn_clock, other_end])
		check(not both, "%s never both at once" % tag)
		await sim.free_world(w)
		# Another type's attack gets ready during a volley.
		w = _world(_layout(case[0]), case[1], _no_shows)
		w.player.god_mode = true
		await _start(w)
		truck = null
		other = null
		both = false
		var ended: float = -1.0
		for i: int in int(14.0 / frame):
			await tree.physics_frame
			if truck == null:
				truck = _truck(w)
			if truck == null:
				continue
			if other == null and truck.volley == EnforcerTruck.Volley.WARNING:
				other = w.director.spawn({"type": "blocker", "script": TURN_DUMMY, "at": 0.0, "lane": 0, "side": 0, "seed": 1,
					"params": {"first": 0.1, "warning": 0.5, "attack": 0.5, "interval": 99.0}})
			if other == null:
				continue
			both = both or (truck.is_major_attack_active() and other.is_major_attack_active())
			if ended < 0.0 and truck.volley == EnforcerTruck.Volley.IDLE:
				ended = w.level_time()
			if int(other.call(&"count", "end")) > 0:
				break
		var other_spans: Array = other.call(&"spans") if other != null else []
		var started: float = float(other_spans[0][0]) if not other_spans.is_empty() else -1.0
		check(other != null and int(other.call(&"count", "held")) > 0 and started >= ended - frame and ended > 0.0,
			"%s another type's big attack that gets ready during a volley waits for its end (it started %.2f s, the volley ended %.2f s)"
			% [tag, started, ended])
		check(not both, "%s never both at once, the other way round" % tag)
		await sim.free_world(w)


# --- Baits ----------------------------------------------------------------------------------------

## One run of an Octodog's charge with the truck chasing (2 riders aboard), the scripted runner in the
## middle lane dodging the volleys, then the charge: late (as the lunge begins) or early (as the wind-up
## begins). What happened: {down (what destroyed it; "" if it lives), by (the dog lunged then), kill
## (points for it), riders (the riders' bonus), alive (the runner), during (a volley on during the
## dog's wind-up or lunge), due (a volley was due meanwhile: it held its fire), closest (its gap while the
## dog attacked), min_gap, volleys, watch_volleys, watch_down, overlap, history, sounds, score, distance,
## lane}.
func _dog_run(lanes: int, pace: Array, late: bool, turns: bool, shows: bool = false) -> Dictionary:
	var v: float = float(pace[0])
	var dog_t := EnemyDirector.tuning_for("octodog") as OctodogTuning
	var stop: float = dog_t.stop_distance(v, float(pace[1]), v / MovementTuning.REFERENCE_SPEED)
	var layout := _layout(lanes)
	var lane: int = lanes / 2
	layout.enemies.append({"type": "octodog", "at": (16.0 if shows else 9.0) * v + stop, "lane": lane, "side": 0, "seed": 3,
		"params": {"doghouse": false}})
	var w: RunWorld = _world(layout, pace, Callable() if shows else _no_shows, turns)
	var watch := AttackWatch.new(w)
	watch.keep_lane = -1
	await _start(w)
	var bot := Runner.new(w)
	var truck: EnforcerTruck = null
	var found: bool = false
	var dog: Octodog = null
	var out := {"down": "", "by": false, "kill": 0, "riders": 0, "alive": true, "during": false, "due": false,
		"closest": INF, "min_gap": INF, "volleys": 0, "watch_volleys": 0, "watch_down": "", "overlap": 0.0}
	var windup: float = -1.0
	var dodged: bool = false
	var boarded: bool = false
	var kills_before: int = 0
	var lunged: float = -1.0
	for i: int in int(18.0 / frame):
		if not found:
			truck = _truck(w)
			found = truck != null
		if dog == null:
			dog = _first(w, &"octodog") as Octodog
		bot.step(truck if found and is_instance_valid(truck) else null)
		kills_before = int(w.score.bonuses.get(&"kill", 0))
		await tree.physics_frame
		watch.observe()
		var now: float = w.level_time()
		if not found:
			continue
		if not is_instance_valid(truck):
			break
		if not boarded and truck.state == EnforcerTruck.State.CHASING:
			boarded = true
			truck.riders = 2
			truck.model.set_riders(2)
			truck.marker.riders = 2
		out["volleys"] = truck.volleys
		out["history"] = truck.history.duplicate(true)
		out["sounds"] = truck.sounds_played.duplicate()
		if truck.alive:
			out["min_gap"] = minf(float(out["min_gap"]), truck.gap)
		elif String(out["down"]) == "":
			out["down"] = String(truck.history.back()[0]).trim_prefix("wreck:")
			out["by"] = _valid(dog) and dog.phase == Octodog.Phase.LUNGE
			out["kill"] = int(w.score.bonuses.get(&"kill", 0)) - kills_before
			out["riders"] = int(w.score.bonuses.get(&"enforcer_riders", 0))
			out["history"] = truck.history.duplicate(true)
			out.merge(await _watch_blast(w, truck), true)
			continue
		if _valid(dog):
			var attacking: bool = dog.phase == Octodog.Phase.WINDUP or dog.phase == Octodog.Phase.LUNGE
			if attacking and truck.alive:
				out["closest"] = minf(float(out["closest"]), truck.gap)
				out["during"] = bool(out["during"]) or truck.volley != EnforcerTruck.Volley.IDLE
				out["due"] = bool(out["due"]) or truck.next_volley_in() <= 0.0
			if windup < 0.0 and dog.phase == Octodog.Phase.WINDUP:
				windup = now
			if lunged < 0.0 and dog.phase == Octodog.Phase.LUNGE:
				lunged = now
			if not dodged and windup >= 0.0 and ((late and dog.phase == Octodog.Phase.LUNGE) or (not late and now - windup >= 0.2)):
				dodged = true
				bot.home = _beside(lane, lanes)
			if lunged >= 0.0 and not attacking and now - lunged > 1.0:
				break
		if not w.player.alive:
			break
	out["alive"] = w.player.alive
	out["watch_volleys"] = int(watch.attacks.get("enforcer_volley", 0))
	for key: int in watch.enforcers:
		out["watch_down"] = String((watch.enforcers[key] as Dictionary)["down"])
	out["overlap"] = watch.overlap
	out["score"] = w.score.stats()
	out["distance"] = snappedf(w.player.distance, 0.0001)
	out["lane"] = w.player.lane
	await sim.free_world(w)
	return out


## GDD §9.13: an Octodog's lunge dodged late destroys the truck (closed right up behind the runner, still in
## its lane): the player's kill, with rider_bonus for each rider aboard; dodged early, the truck follows the
## runner out in time and lives. No volley is on during the dog's wind-up or lunge (big attacks taking turns
## at 3 and 6 lanes, not at 5), it never comes closer than MIN_GAP, and AttackWatch follows it.
func _test_octodog_bait() -> void:
	var dog_t := EnemyDirector.tuning_for("octodog") as OctodogTuning
	for lanes: int in LANES:
		for pace: Array in paces:
			var turns: bool = lanes != 5
			var tag: String = "%s%s" % [_tag(lanes, pace), "" if turns else " (no turns)"]
			var r: Dictionary = await _dog_run(lanes, pace, true, turns)
			check(String(r["down"]) == String(Enemy.CHARGE_DAMAGE_CAUSE) and bool(r["by"]) and bool(r["alive"]),
				"%s an Octodog's lunge dodged as it begins destroys it, the runner unhurt (%s)" % [tag, r["down"]])
			_check_blast(tag, "an Octodog's lunge", r)
			check(int(r["kill"]) == t.score_value and int(r["riders"]) == 2 * t.rider_bonus,
				"%s the player's kill (%d) with the bonus for its 2 riders (%d)" % [tag, int(r["kill"]), int(r["riders"])])
			var close: float = t.close_gap_for(dog_t, float(pace[0]) / MovementTuning.REFERENCE_SPEED)
			check(float(r["closest"]) <= close + 0.3 and float(r["min_gap"]) >= EnforcerTruck.MIN_GAP - 0.001,
				"%s it closes right up for the dog's attack (%.2f m; its close gap %.2f m), never closer than %.1f m" % [tag,
				float(r["closest"]), close, EnforcerTruck.MIN_GAP])
			check(not bool(r["during"]) and bool(r["due"]) and int(r["volleys"]) >= 1,
				"%s no volley during the wind-up or the lunge, though one was due (%d volleys before)" % [tag, int(r["volleys"])])
			check(int(r["watch_volleys"]) == int(r["volleys"]) and String(r["watch_down"]) == String(Enemy.CHARGE_DAMAGE_CAUSE)
				and is_zero_approx(float(r["overlap"])), "%s AttackWatch sees its %d volleys and its end, and no overlap (%.2f s)" % [tag,
				int(r["watch_volleys"]), float(r["overlap"])])
			r = await _dog_run(lanes, pace, false, turns)
			check(String(r["down"]) == "" and bool(r["alive"]), "%s dodged early, the lunge misses it too (%s)" % [tag, r["down"]])
			check(not bool(r["during"]), "%s and no volley is on meanwhile" % tag)


## One run of a Buzz Overdrive's charge in the middle lane with the truck chasing (1 rider aboard): the
## scripted runner dodges the volleys and leaves the tank's lane `lead` seconds before it meets them. What
## happened: {down, by (the tank was charging then), kill, riders, alive, during (a volley on during its
## rev or charge), due (a volley was due meanwhile: it held its fire), volleys, revved}.
func _buzz_run(lanes: int, pace: Array, lead: float, turns: bool, shows: bool = false) -> Dictionary:
	var v: float = float(pace[0])
	var lane: int = lanes / 2
	var cut: Dictionary = BuzzRules.plan_for(BuzzRules.tuning(), lane, (15.0 if shows else 8.0) * v, v,
		v / MovementTuning.REFERENCE_SPEED, float(pace[1]))
	var layout := _layout(lanes, maxf(1400.0, float(cut["end"]) + 400.0))
	layout.cuts.append(cut)
	layout.enemies.append({"type": "buzz_overdrive", "at": float(cut["end"]), "lane": lane, "side": 0, "seed": 11, "params": {}})
	var w: RunWorld = _world(layout, pace, Callable() if shows else _no_shows, turns)
	await _start(w)
	var bot := Runner.new(w)
	var meet: float = FloorCutPlan.meet(cut, v)
	var truck: EnforcerTruck = null
	var found: bool = false
	var tank: Enemy = null
	var out := {"down": "", "by": false, "kill": 0, "riders": 0, "alive": true, "during": false, "due": false, "volleys": 0,
		"revved": false}
	var boarded: bool = false
	var kills_before: int = 0
	for i: int in int(30.0 / frame):
		if not found:
			truck = _truck(w)
			found = truck != null
		if tank == null:
			tank = _first(w, &"buzz_overdrive")
		if w.player.distance >= meet - lead * v:
			bot.home = _beside(lane, lanes)
		bot.step(truck if found and is_instance_valid(truck) else null)
		kills_before = int(w.score.bonuses.get(&"kill", 0))
		await tree.physics_frame
		if not found:
			continue
		if not is_instance_valid(truck):
			break
		if not boarded and truck.state == EnforcerTruck.State.CHASING:
			boarded = true
			truck.riders = 1
			truck.model.set_riders(1)
		var s: int = int(tank.get(&"state")) if _valid(tank) else -1
		out["revved"] = bool(out["revved"]) or s == BuzzScript.State.REV
		out["volleys"] = truck.volleys
		if truck.alive and (s == BuzzScript.State.REV or s == BuzzScript.State.CHARGE):
			out["during"] = bool(out["during"]) or truck.volley != EnforcerTruck.Volley.IDLE
			out["due"] = bool(out["due"]) or truck.next_volley_in() <= 0.0
		if not truck.alive and String(out["down"]) == "":
			out["down"] = String(truck.history.back()[0]).trim_prefix("wreck:")
			out["by"] = s == BuzzScript.State.CHARGE
			out["kill"] = int(w.score.bonuses.get(&"kill", 0)) - kills_before
			out["riders"] = int(w.score.bonuses.get(&"enforcer_riders", 0))
			out["shown"] = truck.shows
			out.merge(await _watch_blast(w, truck), true)
			break
		if not w.player.alive or w.player.distance > meet + 2.0 * v:
			break
	out["alive"] = w.player.alive
	await sim.free_world(w)
	return out


## GDD §9.13: a Buzz Overdrive's charge left half a second before it meets the runner destroys the truck
## (still in its lane), the player's kill with the riders' bonus; left a second and a half before, the
## truck follows the runner out in time and lives. No volley is on during the tank's rev or charge,
## big attacks taking turns or not.
func _test_buzz_bait() -> void:
	for lanes: int in LANES:
		for pace: Array in paces:
			var turns: bool = lanes != 5
			var tag: String = "%s%s" % [_tag(lanes, pace), "" if turns else " (no turns)"]
			var r: Dictionary = await _buzz_run(lanes, pace, 0.5, turns)
			check(String(r["down"]) == String(Enemy.CHARGE_DAMAGE_CAUSE) and bool(r["by"]) and bool(r["alive"]) and bool(r["revved"]),
				"%s a Buzz Overdrive's charge left half a second before it meets the runner destroys it (%s)" % [tag, r["down"]])
			_check_blast(tag, "a Buzz Overdrive's charge", r)
			check(int(r["kill"]) == t.score_value and int(r["riders"]) == t.rider_bonus,
				"%s the player's kill (%d) with its rider's bonus (%d)" % [tag, int(r["kill"]), int(r["riders"])])
			check(not bool(r["during"]) and bool(r["due"]) and int(r["volleys"]) >= 1,
				"%s no volley during the tank's rev or charge, though one was due (%d volleys before)" % [tag, int(r["volleys"])])
			r = await _buzz_run(lanes, pace, 1.5, turns)
			check(String(r["down"]) == "" and bool(r["alive"]), "%s left early, the charge misses it too (%s)" % [tag, r["down"]])
			check(not bool(r["during"]), "%s and no volley is on meanwhile" % tag)


# --- Holes ----------------------------------------------------------------------------------------

## GDD §9.13: led late around a gap too wide to hop (the runner steps aside a quarter of a second before
## it), it's wrecked, the player's kill; it hops an ordinary gap the runner jumps; led late around a Buzz
## Overdrive's cut (the tank shot down mid-charge, its cut stopping there), it's wrecked too.
func _test_holes() -> void:
	for lanes: int in LANES:
		for pace: Array in paces:
			var tag: String = _tag(lanes, pace)
			var v: float = float(pace[0])
			var jump: float = _mt(v).jump_distance(v)
			var lane: int = lanes / 2
			# A gap too wide to hop.
			var wide := Vector2(6.0 * v, 6.0 * v + 0.75 * jump)
			var layout := _layout(lanes)
			layout.gaps.append({"lane": lane, "start": wide.x, "end": wide.y})
			var r: Dictionary = await _hole_run(layout, pace, wide.x - 0.25 * v, wide.y + 2.0 * v)
			check(String(r["down"]) == "gap" and bool(r["alive"]) and int(r["kill"]) == t.score_value,
				"%s led late around a gap too wide to hop (%.1f m), it's wrecked, the player's kill (%s, %d)" % [tag,
				wide.y - wide.x, r["down"], int(r["kill"])])
			_check_blast(tag, "a gap too wide to hop", r)
			# An ordinary gap the runner jumps.
			var narrow := Vector2(6.0 * v, 6.0 * v + 0.5 * jump)
			layout = _layout(lanes)
			layout.gaps.append({"lane": lane, "start": narrow.x, "end": narrow.y})
			r = await _hole_run(layout, pace, -1.0, narrow.y + 2.0 * v, narrow.x - 0.25 * jump)
			check(String(r["down"]) == "" and bool(r["alive"]) and int(r["hops"]) == 1 and float(r["lift"]) >= 0.5 * t.hop_height,
				"%s it hops an ordinary gap (%.1f m) the runner jumps (%d hops, %.2f m up)" % [tag, narrow.y - narrow.x,
				int(r["hops"]), float(r["lift"])])
			# A Buzz Overdrive's cut, the tank shot down mid-charge.
			r = await _cut_run(lanes, pace)
			check(String(r["down"]) == "cut" and bool(r["alive"]) and int(r["kill"]) == t.score_value and bool(r["shot"]),
				"%s led late around a Buzz Overdrive's cut (the tank shot down mid-charge), it's wrecked, the player's kill (%s)"
				% [tag, r["down"]])
			_check_blast(tag, "a Buzz Overdrive's cut", r)


## The truck (no volleys) chasing the runner over `layout`: the runner steps aside at `leave_at` (if not
## negative) or jumps at `jump_at` (if not negative), until it's at `until`. {down, kill, alive, hops, lift}.
func _hole_run(layout: LevelLayout, pace: Array, leave_at: float, until: float, jump_at: float = -1.0) -> Dictionary:
	var w: RunWorld = _world(layout, pace, _plain)
	await _start(w)
	var bot := Runner.new(w)
	var truck: EnforcerTruck = null
	var found: bool = false
	var out := {"down": "", "kill": 0, "alive": true, "hops": 0, "lift": 0.0}
	var jumped: bool = false
	var kills_before: int = 0
	for i: int in int(20.0 / frame):
		if not found:
			truck = _truck(w)
			found = truck != null
		if leave_at >= 0.0 and w.player.distance >= leave_at:
			bot.home = _beside(layout.lane_count / 2, layout.lane_count)
		if jump_at >= 0.0 and not jumped and w.player.distance >= jump_at:
			jumped = true
			w.player.press(&"jump")
		bot.step(truck if found and is_instance_valid(truck) else null)
		kills_before = int(w.score.bonuses.get(&"kill", 0))
		await tree.physics_frame
		if not found:
			continue
		if not is_instance_valid(truck):
			break
		if truck.alive:
			out["lift"] = maxf(float(out["lift"]), truck.model.position.y)
		elif String(out["down"]) == "":
			out["down"] = String(truck.history.back()[0]).trim_prefix("wreck:")
			out["kill"] = int(w.score.bonuses.get(&"kill", 0)) - kills_before
			out["hops"] = _count(truck, "hop")
			out.merge(await _watch_blast(w, truck), true)
			break
		if not w.player.alive or w.player.distance > until:
			break
	out["alive"] = w.player.alive
	if _valid(truck) and String(out["down"]) == "":
		out["hops"] = _count(truck, "hop")
	await sim.free_world(w)
	return out


## A Buzz Overdrive charging down the runner's lane is shot down (weapons) when it's 0.9 s of running ahead
## of them, its cut stopping there; the runner steps aside a quarter of a second before the cut, the truck
## (no volleys) still in the lane. {down, kill (points for the truck), alive, shot}.
func _cut_run(lanes: int, pace: Array) -> Dictionary:
	var v: float = float(pace[0])
	var lane: int = lanes / 2
	var cut: Dictionary = BuzzRules.plan_for(BuzzRules.tuning(), lane, 6.0 * v, v, v / MovementTuning.REFERENCE_SPEED,
		float(pace[1]))
	var layout := _layout(lanes, maxf(1400.0, float(cut["end"]) + 400.0))
	layout.cuts.append(cut)
	layout.enemies.append({"type": "buzz_overdrive", "at": float(cut["end"]), "lane": lane, "side": 0, "seed": 11, "params": {}})
	var w: RunWorld = _world(layout, pace, _plain)
	await _start(w)
	var bot := Runner.new(w)
	var truck: EnforcerTruck = null
	var found: bool = false
	var tank: Enemy = null
	var out := {"down": "", "kill": 0, "alive": true, "shot": false}
	var stopped_at: float = INF
	var kills_before: int = 0
	for i: int in int(30.0 / frame):
		if not found:
			truck = _truck(w)
			found = truck != null
		if tank == null:
			tank = _first(w, &"buzz_overdrive")
		if w.player.distance >= stopped_at - 0.25 * v:
			bot.home = _beside(lane, lanes)
		bot.step(truck if found and is_instance_valid(truck) else null)
		kills_before = int(w.score.bonuses.get(&"kill", 0))
		await tree.physics_frame
		if not found:
			continue
		if not is_instance_valid(truck):
			break
		if _valid(tank) and tank.alive and int(tank.get(&"state")) == BuzzScript.State.CHARGE \
				and float(tank.get(&"front")) - w.player.distance <= 0.9 * v:
			tank.take_damage(9999.0, &"weapon")
			out["shot"] = not tank.alive
			var fc: FloorCut = w.track.floor_cut(lane, float(cut["end"]))
			stopped_at = fc.front if fc != null else float(tank.get(&"front"))
			# Points from here on are the truck's alone.
			kills_before = int(w.score.bonuses.get(&"kill", 0))
		if not truck.alive:
			out["down"] = String(truck.history.back()[0]).trim_prefix("wreck:")
			out["kill"] = int(w.score.bonuses.get(&"kill", 0)) - kills_before
			out.merge(await _watch_blast(w, truck), true)
			break
		if not w.player.alive or w.player.distance > float(cut["end"]) + 2.0 * v:
			break
	out["alive"] = w.player.alive
	await sim.free_world(w)
	return out


# --- Riders ---------------------------------------------------------------------------------------

## GDD §9.13: cyborgs the runner (god mode, running through them) passes alive in the truck's lane board
## it, at most max_riders: never one in another lane, one the runner killed, a window cyborg or a host. Each
## shows on its roof and its marker, and with 3 aboard its next volley comes volley_interval(3) after the
## last one's end.
func _test_riders() -> void:
	for lanes: int in LANES:
		for pace: Array in paces:
			var tag: String = _tag(lanes, pace)
			var k: float = float(pace[0]) / MovementTuning.REFERENCE_SPEED
			var lane: int = lanes / 2
			var other: int = _beside(lane, lanes)
			var layout := _layout(lanes)
			var still := {"fires": false, "panic": false}
			layout.enemies.append({"type": "cyborg", "at": 18.0 * k, "lane": lane, "side": 0, "seed": 20,
				"params": {"fires": false, "host": true}})
			for d: float in [24.0, 30.0, 36.0, 42.0]:
				layout.enemies.append({"type": "cyborg", "at": d * k, "lane": lane, "side": 0, "seed": int(d),
					"params": still.duplicate()})
			layout.enemies.append({"type": "cyborg", "at": 33.0 * k, "lane": other, "side": 0, "seed": 33,
				"params": still.duplicate()})
			layout.enemies.append({"type": "window_cyborg", "at": 27.0 * k, "lane": 0, "side": 1, "seed": 27,
				"params": {"fires": false}})
			layout.enemies.append({"type": "cyborg", "at": 48.0 * k, "lane": lane, "side": 0, "seed": 48,
				"params": still.duplicate()})
			var w: RunWorld = _world(layout, pace, _no_shows)
			w.player.god_mode = true
			await _start(w)
			var truck: EnforcerTruck = null
			var killed: bool = false
			var warns: Array[float] = []
			var ends: Array[float] = []
			var was: int = EnforcerTruck.Volley.IDLE
			for i: int in int(12.0 / frame):
				await tree.physics_frame
				if truck == null:
					truck = _truck(w)
				if not killed:
					for e: Variant in w.director.active:
						if is_instance_valid(e) and (e as Enemy).alive and (e as Enemy).type_id == &"cyborg" \
								and is_equal_approx(float((e as Enemy).spawn.get("at", 0.0)), 48.0 * k) \
								and (e as Enemy).track_distance() - w.player.distance < 10.0:
							(e as Enemy).defeat(&"weapon")
							killed = true
				if truck == null:
					continue
				if truck.volley != was:
					if was == EnforcerTruck.Volley.IDLE:
						warns.append(w.level_time())
					elif truck.volley == EnforcerTruck.Volley.IDLE:
						ends.append(w.level_time())
					was = truck.volley
				if warns.size() >= 2:
					break
			check(killed and truck != null and truck.riders == t.max_riders and _count(truck, "rider") == t.max_riders,
				"%s 3 of the 4 cyborgs passed alive in its lane board it; none in another lane, killed, in a window or a host (%d)"
				% [tag, truck.riders if truck != null else -1])
			check(truck != null and _shown_riders(truck) == truck.riders and truck.marker.riders == truck.riders
				and truck.sounds_played.count(&"enforcer_pickup") == truck.riders,
				"%s each rider shows on its roof and its marker, with its sound" % tag)
			var interval: float = warns[1] - ends[0] if warns.size() >= 2 and ends.size() >= 1 else -1.0
			check(absf(interval - t.volley_interval(t.max_riders)) <= 2.0 * frame,
				"%s with 3 riders its next volley comes %.2f s after the last (%.2f s; %.2f s with none)" % [tag,
				t.volley_interval(t.max_riders), interval, t.volley_interval(0)])
			await sim.free_world(w)


# --- Showing itself ---------------------------------------------------------------------------------

## The new history events of `truck` since `seen` (an index), as [event, level time] pairs appended to `into`;
## returns the new index.
func _take_events(w: RunWorld, truck: EnforcerTruck, seen: int, into: Array) -> int:
	for i: int in range(seen, truck.history.size()):
		into.append([String(truck.history[i][0]), w.level_time()])
	return truck.history.size()


## The level times of `events` (_take_events) named `event`.
static func _times(events: Array, event: String) -> Array[float]:
	var out: Array[float] = []
	for e: Array in events:
		if String(e[0]) == event:
			out.append(float(e[1]))
	return out


## GDD §9.13 "Showing itself" (the owner, October 8, 2026), on a plain track at 3, 5 and 6 lanes and both paces,
## the scripted runner dodging its volleys: it shows itself as it arrives, its siren swelling, in a lane beside the
## runner's with its front show_ahead ahead of them, its whole look on screen in the run camera's resting view and
## hiding nothing of the runner (EnforcerTruckView), its sides solid and its showing taking a turn; it stays
## alongside show_seconds, drops back to its follow gap and takes up the runner's lane again; its marker fades while
## it's on screen and it never fires meanwhile. It shows itself once more mid-chase, show_spacing_seconds or more
## after, show_count times in all, and its volleys still come.
func _test_shows() -> void:
	for lanes: int in LANES:
		for pace: Array in paces:
			var tag: String = _tag(lanes, pace)
			var w: RunWorld = _world(_layout(lanes), pace)
			await _start(w)
			var bot := Runner.new(w)
			var truck: EnforcerTruck = null
			var events: Array = []
			var seen: int = 0
			var settled: int = 0
			var faults: Dictionary = {}
			var marker_max: float = 0.0
			var rejoined: Array[float] = []
			var look: StringName = EnforcerTruckModel.look_of(w.skin.enemy_variant if w.skin != null else &"city")
			for i: int in int(30.0 / frame):
				bot.step(truck if truck != null and is_instance_valid(truck) else null)
				await tree.physics_frame
				if truck == null:
					truck = _truck(w)
					continue
				if not is_instance_valid(truck) or truck.state == EnforcerTruck.State.LEAVING:
					break
				seen = _take_events(w, truck, seen, events)
				var p: Player = w.player
				if truck.show_phase != EnforcerTruck.Show.NONE and truck.volley != EnforcerTruck.Volley.IDLE:
					faults["fired while showing itself"] = true
				if truck.show_phase == EnforcerTruck.Show.ALONGSIDE:
					settled += 1
					if not truck.blocking() or not truck.is_major_attack_active():
						faults["sides not solid or no turn taken"] = true
					if absi(truck.lane - p.lane) != 1:
						faults["not in a lane beside the runner's"] = true
					if settled > int(0.4 / frame):
						if absf(truck.gap + t.show_ahead) > 0.35:
							faults["front not show_ahead ahead (%.2f)" % -truck.gap] = true
						var view := EnforcerTruckView.of_runner(w.tuning, w.geo, p.lane, p.distance)
						var boxes: Array[AABB] = EnforcerTruckView.truck_boxes(
							EnforcerTruckModel.profile(look, t.body_size, truck.riders), truck.global_position.x, p.distance - truck.gap)
						for c: Vector3 in EnforcerTruckView.corners(boxes):
							if not view.on_screen(c, 0.0):
								faults["off screen"] = true
						for q: Vector3 in EnforcerTruckView.runner_points(w.tuning, p.position.x, p.distance):
							if view.hidden(boxes, q):
								faults["hides the runner"] = true
						marker_max = maxf(marker_max, truck.marker.shown) if settled > int(0.8 / frame) else marker_max
				else:
					settled = 0
				if truck.show_phase == EnforcerTruck.Show.NONE and not _times(events, "shown").is_empty() \
						and rejoined.size() < _times(events, "shown").size() and truck.lane == p.lane:
					rejoined.append(w.level_time() - _times(events, "shown")[rejoined.size()])
			var shows: Array[float] = _times(events, "show")
			var alongside: Array[float] = _times(events, "alongside")
			var drops: Array[float] = _times(events, "drop_back")
			var shown: Array[float] = _times(events, "shown")
			var arrive: Array[float] = _times(events, "arrive")
			check(not arrive.is_empty() and not shows.is_empty() and absf(shows[0] - arrive[0]) < 0.001,
				"%s it shows itself as it arrives (%s)" % [tag, events.slice(0, 3)])
			var held: bool = alongside.size() >= 2 and drops.size() >= 2
			for k: int in mini(alongside.size(), drops.size()):
				held = held and absf(drops[k] - alongside[k] - t.show_seconds) <= 2.5 * frame
			check(held, "%s it stays alongside %.1f s, then drops back (%s)" % [tag, t.show_seconds, _pairs(alongside, drops)])
			check(shows.size() == t.show_count and shown.size() == t.show_count and shows[1] - shown[0] >= t.show_spacing_seconds - frame,
				"%s once more mid-chase, %.1f s or more after the first: %d showings in all (%s)" % [tag, t.show_spacing_seconds,
				shows.size(), shows])
			var back: bool = rejoined.size() == shown.size()
			for r: float in rejoined:
				back = back and r <= t.lane_delay_seconds + t.switch_seconds + 0.1
			check(back, "%s back at its follow gap, it takes up the runner's lane again (%s s)" % [tag, rejoined])
			check(faults.is_empty(), "%s alongside: in a lane beside theirs, its whole look on screen, hiding nothing of the runner, its sides solid, its turn taken, never firing (%s)"
				% [tag, faults.keys()])
			var sirens: int = truck.sounds_played.count(&"enforcer_siren") if truck != null and is_instance_valid(truck) else -1
			check(marker_max < 0.05 and sirens == shows.size(), "%s its marker fades while it's on screen (%.2f), its siren as each begins (%d)"
				% [tag, marker_max, sirens])
			check(truck != null and is_instance_valid(truck) and truck.volleys >= 2, "%s and its volleys still come (%d)" % [tag,
				truck.volleys if truck != null and is_instance_valid(truck) else -1])
			await sim.free_world(w)


static func _pairs(a: Array[float], b: Array[float]) -> String:
	var out: PackedStringArray = []
	for k: int in mini(a.size(), b.size()):
		out.append("%.2f s" % (b[k] - a[k]))
	return ", ".join(out)


## GDD §9.3 (the hover truck's solid sides, the Enforcer's while it shows itself; §9.13): a lane change into its
## side is bumped back (the runner stays in their lane, lane_blocked), never hurts a runner without armor, and it
## gives way: it drops back at once, and once its side has passed them the runner changes into that lane, the truck
## then MIN_GAP or more behind them there. At 3, 5 and 6 lanes.
func _test_show_bump() -> void:
	for lanes: int in LANES:
		var tag: String = _tag(lanes, paces[1])
		var w: RunWorld = _world(_layout(lanes), paces[1], _no_volleys)
		var blocked: Array[int] = [0]
		w.player.movement_event.connect(func(kind: StringName) -> void:
			if kind == &"lane_blocked":
				blocked[0] += 1)
		await _start(w)
		var truck: EnforcerTruck = null
		var settled: int = 0
		var home: int = w.player.lane
		var side: int = 0
		var gave_way: bool = false
		var stayed: bool = true
		var moved: bool = false
		var min_gap: float = INF
		var pressed_again: bool = false
		for i: int in int(12.0 / frame):
			await tree.physics_frame
			if truck == null:
				truck = _truck(w)
				continue
			if not is_instance_valid(truck):
				break
			if side == 0:
				settled = settled + 1 if truck.show_phase == EnforcerTruck.Show.ALONGSIDE else 0
				if settled == int(0.5 / frame):
					side = signi(truck.show_lane - w.player.lane)
					w.player.press(&"move_right" if side > 0 else &"move_left")
				continue
			gave_way = gave_way or _count(truck, "give_way") > 0
			if not pressed_again:
				stayed = stayed and w.player.lane == home
				if truck.gap > t.blocker_ahead + 1.2 and gave_way:
					pressed_again = true
					w.player.press(&"move_right" if side > 0 else &"move_left")
				continue
			moved = moved or w.player.lane == home + side
			if absf(truck.global_position.x - w.player.position.x) < (t.body_size.x + tuning.visual_size.x) * 0.5:
				min_gap = minf(min_gap, truck.gap)
			if moved and truck.show_phase == EnforcerTruck.Show.NONE and truck.lane == w.player.lane:
				break
		check(side != 0 and blocked[0] >= 1 and stayed, "%s a lane change into its side is bumped back (%d bumps)" % [tag, blocked[0]])
		check(w.player.alive, "%s and never hurts (no armor, no god mode)" % tag)
		check(gave_way and moved, "%s it gives way, and the runner then changes into that lane" % tag)
		check(min_gap >= EnforcerTruck.MIN_GAP - 0.001, "%s behind them there, never closer than %.1f m (%.2f m)" % [tag,
			EnforcerTruck.MIN_GAP, min_gap])
		await sim.free_world(w)


## GDD §9.13: it never takes the only free lane, at 3, 5 and 6 lanes. The runner in the middle lane, its two
## neighbours `left` and `right`: zone doodads (the runner must leave a lane for one) stand 3.5 s ahead in the
## runner's lane and in `left`, so `right` would be the only free lane there; it never shows itself in `right`
## while that spot lies ahead (nor in `left`, not clear). With the runner's lane free there instead, it shows
## itself in `right` as it arrives (the runner keeps their own lane). A runner in an outer lane never sees it
## alongside.
func _test_show_fairness() -> void:
	for lanes: int in LANES:
		var tag: String = _tag(lanes, paces[1])
		var mid: int = lanes / 2
		var spot: float = 3.5 * float(paces[1][0])
		for runner_free: bool in [false, true]:
			var layout := _layout(lanes)
			var mine: Array[int] = [mid - 1]
			if not runner_free:
				mine.append(mid)
			for l: int in mine:
				layout.doodads.append({"lane": l, "start": spot, "end": spot + 3.0, "size": "medium", "side": -1 if l > 0 else 1,
					"seed": l})
			var w: RunWorld = _world(layout, paces[1], _no_volleys)
			w.player.god_mode = true
			await _start(w)
			var bot := Runner.new(w)
			var truck: EnforcerTruck = null
			var first_show: float = -1.0
			var show_lane: int = -1
			var why: String = ""
			for i: int in int(10.0 / frame):
				bot.step(null)
				await tree.physics_frame
				if truck == null:
					truck = _truck(w)
					continue
				if why == "" and truck.state != EnforcerTruck.State.WAITING:
					why = truck.show_problem() if truck.show_phase == EnforcerTruck.Show.NONE else "(showing)"
				if first_show < 0.0 and truck.show_phase != EnforcerTruck.Show.NONE:
					first_show = w.player.distance
					show_lane = truck.show_lane
				if w.player.distance > spot + 40.0:
					break
			if runner_free:
				check(first_show >= 0.0 and first_show < 5.0 and show_lane == mid + 1,
					"%s its lane free, the runner keeps a lane: it shows itself as it arrives in lane %d (lane %d, at %.0f m)" % [tag,
					mid + 1, show_lane, first_show])
			else:
				check(first_show < 0.0 or first_show > spot + 3.0, "%s doodads in the runner's lane and lane %d at %.0f m: it never takes lane %d, the only free one there (%s; first showing at %.0f m)"
					% [tag, mid - 1, spot, mid + 1, why, first_show])
			await sim.free_world(w)
	# A runner in an outer lane.
	var w: RunWorld = _world(_layout(3), paces[1], _no_volleys)
	await _start(w)
	w.player.press(&"move_left")
	var truck: EnforcerTruck = null
	var ever: bool = false
	for i: int in int(8.0 / frame):
		await tree.physics_frame
		if truck == null:
			truck = _truck(w)
		ever = ever or (truck != null and truck.show_phase != EnforcerTruck.Show.NONE)
	check(not ever and truck != null and truck.show_problem() == "runner in an outer lane",
		"(3 lanes) a runner in an outer lane (no lane on each side) never has it alongside (%s)" % (truck.show_problem() if truck != null else ""))
	await sim.free_world(w)


## GDD §9.13: it never shows itself during an attack's warning. Another type's big attack on as it arrives
## (tests/helpers/turn_dummy.gd): it shows itself only once that's over. One that gets ready while it shows
## itself waits for its turn until it has dropped back out of view (its showing takes a turn like a big attack).
## Both at 5 lanes.
func _test_show_turns() -> void:
	var pace: Array = paces[1]
	var w: RunWorld = _world(_layout(5), pace, _no_volleys)
	w.player.god_mode = true
	await _start(w)
	var other: Enemy = w.director.spawn({"type": "blocker", "script": TURN_DUMMY, "at": 0.0, "lane": 0, "side": 0, "seed": 1,
		"params": {"first": 0.0, "warning": 1.5, "attack": 2.0, "interval": 99.0}})
	var truck: EnforcerTruck = null
	var shown_at: float = -1.0
	var both: bool = false
	for i: int in int(10.0 / frame):
		await tree.physics_frame
		if truck == null:
			truck = _truck(w)
			continue
		both = both or (truck.show_phase != EnforcerTruck.Show.NONE and other.is_major_attack_active())
		if shown_at < 0.0 and truck.show_phase != EnforcerTruck.Show.NONE:
			shown_at = w.level_time()
			break
	var spans: Array = other.call(&"spans")
	var other_end: float = float(spans[0][1]) if not spans.is_empty() else INF
	check(shown_at > 0.0 and shown_at >= other_end - frame and not both,
		"(5 lanes) another type's attack on as it arrives: it shows itself once that's over (at %.2f s; the other's end %.2f s)"
		% [shown_at, other_end])
	await sim.free_world(w)
	# One that gets ready during a showing.
	w = _world(_layout(5), pace, _no_volleys)
	w.player.god_mode = true
	await _start(w)
	truck = null
	other = null
	both = false
	var out_of_view: float = -1.0
	for i: int in int(14.0 / frame):
		await tree.physics_frame
		if truck == null:
			truck = _truck(w)
			continue
		if other == null and truck.show_phase == EnforcerTruck.Show.ALONGSIDE:
			other = w.director.spawn({"type": "blocker", "script": TURN_DUMMY, "at": 0.0, "lane": 0, "side": 0, "seed": 1,
				"params": {"first": 0.0, "warning": 0.5, "attack": 0.5, "interval": 99.0}})
		if other == null:
			continue
		both = both or (truck.is_major_attack_active() and other.is_major_attack_active())
		if out_of_view < 0.0 and truck.show_phase != EnforcerTruck.Show.ALONGSIDE and not truck.is_major_attack_active():
			out_of_view = w.level_time()
		if int(other.call(&"count", "end")) > 0:
			break
	var other_spans: Array = other.call(&"spans") if other != null else []
	var started: float = float(other_spans[0][0]) if not other_spans.is_empty() else -1.0
	check(other != null and int(other.call(&"count", "held")) > 0 and started >= out_of_view - frame and out_of_view > 0.0 and not both,
		"(5 lanes) another type's attack that gets ready while it shows itself waits until it's out of view (it started %.2f s, out of view %.2f s)"
		% [started, out_of_view])
	await sim.free_world(w)


## GDD §9.13: it never shows itself during a bait's warning or charge, or as it closes up for an Octodog's lunge:
## an Octodog planned to wind up soon after it arrives keeps it from showing itself as it arrives (a bait coming);
## planned a little later, it shows itself with a shorter stay, back behind the runner in time. And its baits still
## work with its showings: an Octodog's lunge and a Buzz Overdrive's charge, dodged late, still destroy it after it
## has shown itself. At 3, 5 and 6 lanes, Corporate 2's pace.
func _test_show_baits() -> void:
	var pace: Array = paces[1]
	var v: float = float(pace[0])
	var dog_t := EnemyDirector.tuning_for("octodog") as OctodogTuning
	var stop: float = dog_t.stop_distance(v, float(pace[1]), v / MovementTuning.REFERENCE_SPEED)
	for lanes: int in LANES:
		var tag: String = _tag(lanes, pace)
		for case: Array in [[5.0, "a bait coming"], [8.5, ""]]:
			var layout := _layout(lanes)
			layout.enemies.append({"type": "octodog", "at": float(case[0]) * v + stop, "lane": lanes / 2, "side": 0, "seed": 3,
				"params": {"doghouse": false, "charge_at": [float(case[0]) * v]}})
			var w: RunWorld = _world(layout, pace, _no_volleys)
			w.player.god_mode = true
			await _start(w)
			var truck: EnforcerTruck = null
			var why: String = ""
			var hold: float = -1.0
			var back: float = INF
			for i: int in int(10.0 / frame):
				await tree.physics_frame
				if truck == null:
					truck = _truck(w)
					continue
				if why == "" and truck.state != EnforcerTruck.State.WAITING:
					why = truck.show_problem() if truck.show_phase == EnforcerTruck.Show.NONE else "(showing)"
					hold = float(truck.get(&"_show_hold"))
				if truck.show_phase == EnforcerTruck.Show.NONE and _count(truck, "shown") > 0 and back == INF:
					back = w.player.distance
				if w.player.distance > float(case[0]) * v:
					break
			if String(case[1]) != "":
				check(why == String(case[1]) and _count(truck, "show") == 0,
					"%s an Octodog winding up %.1f s after it arrives: no showing (%s)" % [tag, float(case[0]), why])
			else:
				var lead: float = (float(case[0]) * v - back) / v
				check(why == "(showing)" and hold >= t.show_min_seconds and hold < t.show_seconds and lead >= t.close_lead_seconds,
					"%s an Octodog winding up %.1f s after it arrives: it shows itself %.2f s, back behind the runner %.2f s before the wind-up"
					% [tag, float(case[0]), hold, lead])
			await sim.free_world(w)
		var r: Dictionary = await _dog_run(lanes, pace, true, true, true)
		check(String(r["down"]) == String(Enemy.CHARGE_DAMAGE_CAUSE) and bool(r["by"]) and bool(r["alive"])
			and _count_in(r.get("history", []), "alongside") >= 1,
			"%s with its showings, an Octodog's lunge dodged late still destroys it, after it showed itself (%s)" % [tag, r["down"]])
		r = await _buzz_run(lanes, pace, 0.5, true, true)
		check(String(r["down"]) == String(Enemy.CHARGE_DAMAGE_CAUSE) and bool(r["by"]) and bool(r["alive"]) and int(r.get("shown", 0)) >= 1,
			"%s and so does a Buzz Overdrive's charge (%s, %d showings first)" % [tag, r["down"], int(r.get("shown", 0))])


## How many of `history`'s events (EnforcerTruck.history) are `event`.
static func _count_in(history: Array, event: String) -> int:
	var n: int = 0
	for h: Variant in history:
		if String((h as Array)[0]) == event:
			n += 1
	return n


## The same showing run twice (an Octodog bait after its showing at 5 lanes and Corporate 2's pace): the same
## events at the same distances, the same sounds, score and runner.
func _test_show_same_every_attempt() -> void:
	var a: Dictionary = await _dog_run(5, paces[1], true, true, true)
	var b: Dictionary = await _dog_run(5, paces[1], true, true, true)
	check(a.has("history") and _count_in(a["history"], "alongside") >= 1 and JSON.stringify(a) == JSON.stringify(b),
		"its showings play the same on every attempt (%d events)" % (a.get("history", []) as Array).size())


# --- Determinism ------------------------------------------------------------------------------------

## The same run twice (an Octodog bait at 5 lanes and Corporate 2's pace): the same events at the same
## distances, the same sounds, score and runner.
func _test_same_every_attempt() -> void:
	var a: Dictionary = await _dog_run(5, paces[1], true, true)
	var b: Dictionary = await _dog_run(5, paces[1], true, true)
	check(a.has("history") and JSON.stringify(a) == JSON.stringify(b),
		"it plays the same on every attempt (%d events)" % (a.get("history", []) as Array).size())


# --- Corporate 2 ------------------------------------------------------------------------------------

## Corporate 2's own build (LayoutCache) at 3, 5 and 6 lanes, played to its end by a scripted runner: god
## mode and grapples, keeping to the middle lane like AttackWatch's runner, and baiting each charge while a
## truck chases (it steps out of an Octodog's lunge aimed at it as the lunge begins; it steps into a Buzz
## Overdrive's lane as it rolls in, and out half a second before it meets the runner). Every truck that
## comes is destroyed by a charge the runner was out of the way of, the player's kill; no other type's big
## attack is open during its volleys; the runner reaches the end.
func _test_corporate_2() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for lanes: int in LANES:
		var config: LevelConfig = campaign.configure(campaign.step("corporate/2"), lanes)
		config.skin = null  # the grey box: skins never change gameplay
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		var planned: int = Rules.trucks_in(layout).size()
		var w: RunWorld = sim.build_world(layout, null, null, config)
		w.player.god_mode = true
		w.player.grapples = 1_000_000
		var watch := AttackWatch.new(w)
		var middle: int = watch.keep_lane
		var v: float = w.tuning.run_speed
		var trucks: Dictionary = {}
		var bait: Dictionary = {}
		await _start(w)
		var frames_left: int = int(config.duration_seconds * 2.0 / frame)
		while w.player.distance < layout.length - 2.0 and frames_left > 0:
			frames_left -= 1
			_bait_step(w, watch, bait, middle, v)
			await tree.physics_frame
			watch.observe()
			for e: Variant in w.director.active:
				if not is_instance_valid(e) or not (e is EnforcerTruck):
					continue
				var truck := e as EnforcerTruck
				var id: int = truck.get_instance_id()
				if truck.state == EnforcerTruck.State.WAITING:
					continue
				var rec: Dictionary = trucks.get_or_add(id, {"down": "", "dodged": false, "riders": 0, "volleys": 0, "shows": 0,
					"fired": false, "closest": INF})
				rec["riders"] = truck.riders
				rec["volleys"] = truck.volleys
				rec["shows"] = maxi(int(rec["shows"]), truck.shows)
				if truck.alive:
					rec["fired"] = bool(rec["fired"]) or (truck.show_phase != EnforcerTruck.Show.NONE and truck.volley != EnforcerTruck.Volley.IDLE)
					if absf(truck.global_position.x - w.player.position.x) < (t.body_size.x + tuning.visual_size.x) * 0.5:
						rec["closest"] = minf(float(rec["closest"]), truck.gap)
				if not truck.alive and String(rec["down"]) == "":
					rec["down"] = String(truck.history.back()[0]).trim_prefix("wreck:")
					rec["dodged"] = _out_of_the_way(w, truck)
		var tag: String = "Corporate 2 at %d lanes" % lanes
		var downs: PackedStringArray = []
		var all_baited: bool = not trucks.is_empty()
		var fair: bool = true
		for id: int in trucks:
			var rec: Dictionary = trucks[id]
			downs.append("%s%s (%d riders, %d volleys, %d showings)" % [rec["down"], "" if bool(rec["dodged"]) else " NOT DODGED",
				int(rec["riders"]), int(rec["volleys"]), int(rec["shows"])])
			fair = fair and not bool(rec["fired"]) and float(rec["closest"]) >= EnforcerTruck.MIN_GAP - 0.001
			all_baited = all_baited and String(rec["down"]) in [String(Enemy.CHARGE_DAMAGE_CAUSE), "cut", "gap"] and bool(rec["dodged"])
		check(planned >= 1 and trucks.size() == planned, "%s: its %d planned trucks come (%d)" % [tag, planned, trucks.size()])
		check(all_baited, "%s: each is destroyed by a charge the runner was out of the way of (%s)" % [tag, ", ".join(downs)])
		check(fair, "%s: it never fires while it shows itself, and in the runner's lane never comes closer than %.1f m" % [tag,
			EnforcerTruck.MIN_GAP])
		var pairs: PackedStringArray = []
		for pair: String in watch.overlap_pairs:
			if pair.contains("enforcer_truck"):
				pairs.append("%s %.2f s" % [pair, float(watch.overlap_pairs[pair])])
		check(pairs.is_empty() and int(watch.attacks.get("enforcer_volley", 0)) >= 1,
			"%s: no other type's big attack is open during its %d volleys (%s)" % [tag, int(watch.attacks.get("enforcer_volley", 0)),
			", ".join(pairs)])
		check(w.player.alive and w.player.distance >= layout.length - 2.0, "%s: the runner reaches the end" % tag)
		print("  %s: %d trucks: %s" % [tag, trucks.size(), "; ".join(downs)])
		await sim.free_world(w)


## The scripted runner's baits in a campaign level, steering AttackWatch's runner (keep_lane) while a truck
## chases: an Octodog's lunge at the runner's lane is dodged as it begins; a Buzz Overdrive rolling in is
## met in its lane and left half a second before it meets the runner. Otherwise it keeps to `middle`.
## `bait` holds the bait under way: {kind, enemy, lane, leave (where to leave a tank's lane)}.
func _bait_step(w: RunWorld, watch: AttackWatch, bait: Dictionary, middle: int, v: float) -> void:
	var p: Player = w.player
	if not bait.is_empty():
		var e: Enemy = bait["enemy"] as Enemy if is_instance_valid(bait["enemy"]) else null
		if String(bait["kind"]) == "dog":
			if e == null or not e.alive or ((e as Octodog).phase != Octodog.Phase.LUNGE and (e as Octodog).phase != Octodog.Phase.WINDUP):
				bait.clear()
		else:
			var s: int = int(e.get(&"state")) if e != null and e.alive else BuzzScript.State.GONE
			if s == BuzzScript.State.GONE or s == BuzzScript.State.PASS:
				bait.clear()
			elif p.distance >= float(bait["leave"]) and watch.keep_lane == int(bait["lane"]):
				watch.keep_lane = _beside(int(bait["lane"]), w.geo.lane_count)
		if bait.is_empty():
			watch.keep_lane = middle
		return
	var chasing: bool = false
	for e: Variant in w.director.active:
		if is_instance_valid(e) and e is EnforcerTruck and (e as EnforcerTruck).alive \
				and (e as EnforcerTruck).state == EnforcerTruck.State.CHASING:
			chasing = true
	if not chasing:
		return
	for e: Variant in w.director.active:
		if not is_instance_valid(e) or not (e as Enemy).alive:
			continue
		if e is Octodog and (e as Octodog).phase == Octodog.Phase.LUNGE and (e as Octodog).target_lane == p.lane:
			var to: int = _beside(p.lane, w.geo.lane_count)
			bait.merge({"kind": "dog", "enemy": e, "lane": p.lane, "leave": 0.0})
			watch.keep_lane = to
			p.press(&"move_right" if to > p.lane else &"move_left")
			return
		if (e as Enemy).type_id == &"buzz_overdrive" and int((e as Enemy).get(&"state")) == BuzzScript.State.ROLL:
			var cut: Dictionary = (e as Enemy).get(&"cut")
			bait.merge({"kind": "buzz", "enemy": e, "lane": int(cut["lane"]), "leave": FloorCutPlan.meet(cut, v) - 0.5 * v})
			watch.keep_lane = int(cut["lane"])
			return


## True if the runner was out of the way of the charge that destroyed `truck` (an Octodog lunging at
## another lane, a Buzz Overdrive charging down another), or `truck` fell in a hole.
func _out_of_the_way(w: RunWorld, truck: EnforcerTruck) -> bool:
	var cause: String = String(truck.history.back()[0]).trim_prefix("wreck:")
	if cause != String(Enemy.CHARGE_DAMAGE_CAUSE):
		return true
	for e: Variant in w.director.active:
		if not is_instance_valid(e):
			continue
		if e is Octodog and (e as Octodog).phase == Octodog.Phase.LUNGE:
			return (e as Octodog).target_lane != w.player.lane
		if (e as Enemy).type_id == &"buzz_overdrive" and int((e as Enemy).get(&"state")) == BuzzScript.State.CHARGE:
			return int((e as Enemy).get(&"lane")) != w.player.lane
	return false
