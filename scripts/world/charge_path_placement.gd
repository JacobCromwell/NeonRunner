class_name ChargePathPlacement
extends RefCounted
## Cyborgs in charge paths (owner, October 7, 2026, answering open question 353; GDD §9.13 "Teaching":
## "occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge, so the player
## sees a charge flatten another enemy. At least one comes before the Enforcer's first appearance in Corporate 2";
## task G7). Up to LevelConfig.charge_path_cyborgs of a level's Octodog first lunges and Buzz Overdrive charges get
## a plain floor cyborg planted in their path, which the charge flattens (the owner's mechanic,
## Enemy._hurt_charge_contacts: `take_damage` with `&"enemy_charge"`, unscored). Numbers: ChargePathTuning
## (data/tuning/charge_paths.tres).
##
## The generator runs it after the enemy rules (every Octodog's charges and every Buzz Overdrive's cut are final)
## and the danger density pass's enemies, before the fill pass (LevelGenerator._build): the fillers, the danger
## density pass's floor pieces, the wider gaps and the doodads then keep off the planted cyborg as off any enemy.
## Its entries take seeds of their own (not LevelGenerator.add_enemy's running count). With
## charge_path_cyborgs 0 (quick play, the tests) and in a boss arena it draws nothing and the level is built
## exactly as before.
##
## The planted cyborg is the one exception to the rules that keep every other enemy off a charge's stretch
## (Octodog.charge_clear, the cut's attack window), and it keeps what those rules protect:
## - It's a plain floor cyborg: never a host (a host's death releases a Bad Dream) and never a window cyborg, not
##   the panic variant, and it stands where it's placed (params `stand`), so the charge meets it where planned.
## - Its fire never lands during the charge's warning or strike: it holds fire, and no bolt of its arrives, while
##   the runner is in its `hold_fire` stretch (from hold_before_seconds before the warning to hold_after_seconds
##   after the charge has passed them; Cyborg, CyborgGun.hold).
## - It's in view when the charge hits it: the runner is still in_view_seconds or more behind it then
##   (dog_in_view, tank_in_view).
## - The runner keeps an escape: an Octodog's planted lunge is dodged by leaving its far lane or jumping it, as
##   any lunge, and its cyborg dies well before the runner reaches it; a Buzz Overdrive's cut keeps its own
##   escape (LevelGenerator.cut_escape_clear) and its cyborg stands in the cut's own lane, which the runner leaves
##   anyway. It keeps its obstacle margin (CyborgRules) and off every ceiling's safe floor (CeilingZones).
## - The charge comes as planned: the encounter claims its turn among the big attacks claim_seconds before its
##   warning (a planted Octodog from params `claim_at`; a parked Buzz Overdrive's cut carries `claim_seconds`), so
##   a drone's barrage or a hover truck's lurch or cannon shot that gets ready meanwhile waits for it, and it keeps
##   attack_margin_seconds from what can't wait or claims a turn of its own (attack_near: a Bad Dream's chase, a
##   Resonator's pulse, a Gilded Sentinel's strike, another Octodog's run or Buzz Overdrive's attack; a hover
##   truck keeping one of its lanes).
## How it makes sure the charge crosses the cyborg, at any lane count and speed:
## - Octodog: only its first lunge, which it makes from where it stands (Octodog: IDLE, then the wind-up at its
##   spot). The cyborg stands dog_cyborg_ahead (or a little more) in front of it in the lane beside, and the lunge
##   goes along a line planned through it (params `through_lane`, `through_at`), on two lanes across: it flattens
##   the cyborg about halfway, then carries on toward the far lane, which it reaches about where it would meet a
##   runner there. Its red line shows that path, so the runner dodges it as any lunge; its later charges are at the
##   runner's lane as always (so it still baits an Enforcer Truck). A dog with two lanes beside it on one side and a
##   hole-free path; one standing in the middle of 3 lanes moves to an outer lane where it may stand (_dog_lanes).
##   Never a gap bait (its first lunge is meant to fall into the hole before it).
## - Buzz Overdrive: its cut gets `park`: the tank waits at its cut's end, revs there and charges as planned
##   (a tank that rolls ahead of the runner would drive through a cyborg in its lane), and the cyborg stands
##   tank_cyborg_seconds of run (or a little less) in front of its blade, in its lane: the blade crosses it as it
##   charges.
## Never the level's introduction of the charging enemy (skip_introductions). Up to the level's count, spread
## through the level, from a stream of its own (rng_for("charge_paths")); its report says why each other
## encounter was turned down. DESIGN-TBD (docs/questions/g7.md): the planted lunge's line, the parked tank, the
## numbers.

const TUNING_PATH: String = "res://data/tuning/charge_paths.tres"
const OctodogRules = preload("res://scripts/enemies/octodog_rules.gd")
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const HostRules = preload("res://scripts/enemies/host_rules.gd")
const HoverTruckRules = preload("res://scripts/enemies/hover_truck_rules.gd")
const DOG: String = "octodog"
const TANK: String = "buzz_overdrive"
const CYBORG: String = "cyborg"
## The planted cyborg's params key: which charge it stands in the path of ("octodog" or "buzz_overdrive").
const PARAM: String = "charge_path"
## The cyborg's and the dog's contact boxes, half their depths summed (Octodog.TOP_SIZE, Cyborg.BODY_SIZE):
## how far apart their centres are along the track when the lunge first touches it.
const CONTACT_DEPTH: float = 0.62
## Metres between the samples of a planted lunge's path checked for holes.
const PATH_STEP: float = 0.25
## Metres either side of a sample a hole may not reach, and how far across from the path a lane counts.
const PATH_MARGIN: float = 0.6
const PATH_SIDE: float = 0.45
## How many spots are tried for a dog's cyborg: dog_cyborg_ahead in front of it, then DOG_SPOT_STEP metres (at the
## reference speed) further each, while it's still in view (dog_in_view).
const DOG_SPOTS: int = 3
const DOG_SPOT_STEP: float = 0.25
## How many spots are tried for a tank's cyborg: tank_cyborg_seconds of run in front of its blade, then
## TANK_SPOT_STEP seconds further each, while it's still in view (tank_in_view).
const TANK_SPOTS: int = 5
const TANK_SPOT_STEP: float = 0.1
## Metres either side of a planted cyborg that keep off the rules' calm stretches too (an Enforcer Truck's showing
## window: the room a floor enemy keeps in its lane, EnforcerTruckRoom.ENEMY_ROOM).
const CALM_ROOM: float = 3.0


static func tuning() -> ChargePathTuning:
	var res: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return res as ChargePathTuning if res is ChargePathTuning else ChargePathTuning.new()


## Plants the level's cyborgs (see the header). Returns its report (LevelGenerator.charge_path_result): {} when
## the level asks for none (or is a boss arena, or has no cyborgs); else {target, planted: [{kind, cyborg (its
## entry), charger (the dog's or tank's entry)}], options (how many encounters could take one), constraints}.
static func place(gen: LevelGenerator) -> Dictionary:
	var want: int = gen.config.charge_path_cyborgs
	if want <= 0 or WallGapPlacement.is_boss_arena(gen.config) or not gen.config.has_feature(CYBORG):
		return {}
	var t: ChargePathTuning = tuning()
	var rng: RandomNumberGenerator = gen.rng_for("charge_paths")
	var options: Array[Dictionary] = []
	var rejected: Dictionary = {}
	var dogs: Array[Dictionary] = OctodogRules.dogs_in(gen.layout)
	for i: int in dogs.size():
		var option: Dictionary = {"why": "the level's introduction"} if i == 0 and _introduces(gen, t, DOG) \
			else dog_option(gen, t, rng, dogs[i])
		_sort_option(option, options, rejected, DOG)
	var tanks: Array[Dictionary] = BuzzRules.tanks_in(gen.layout)
	for i: int in tanks.size():
		var option: Dictionary = {"why": "the level's introduction"} if i == 0 and _introduces(gen, t, TANK) \
			else tank_option(gen, t, tanks[i])
		_sort_option(option, options, rejected, TANK)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["warn"]) < float(b["warn"]))
	var chosen: Array[Dictionary] = _choose(gen, rng, options, want)
	var planted: Array[Dictionary] = []
	for option: Dictionary in chosen:
		planted.append(plant(gen, option, planted.size()))
	var constraints: PackedStringArray = []
	if planted.size() < want:
		constraints.append("%d of %d: only %d Octodog lunges or Buzz Overdrive charges here can take one fairly"
			% [planted.size(), want, options.size()])
	return {"target": want, "planted": planted, "options": options.size(), "rejected": rejected,
		"constraints": constraints}


## Plants `option`'s cyborg (dog_option, tank_option) in `gen`'s layout, the level's `index`-th: its entry (seeded
## by the level's seed and `index`), the dog's planned line through it and its claim (params `through_lane`,
## `through_at`, `claim_at`; the dog in the option's lane), or the tank's cut parked with its longer claim (`park`,
## `claim_seconds`). Returns {kind, cyborg, charger}.
static func plant(gen: LevelGenerator, option: Dictionary, index: int) -> Dictionary:
	var cyborg: Dictionary = option["cyborg"]
	cyborg["seed"] = hash([gen.config.level_seed, PARAM, index])
	gen.layout.enemies.append(cyborg)
	var charger: Dictionary = option["charger"]
	if String(option["kind"]) == DOG:
		var params: Dictionary = charger.get("params", {})
		params["through_lane"] = int(cyborg["lane"])
		params["through_at"] = float(cyborg["at"])
		params["claim_at"] = float(option["claim"])
		charger["params"] = params
		charger["lane"] = int(option["lane"])
	else:
		var cut: Dictionary = option["cut"]
		cut["park"] = true
		cut["claim_seconds"] = maxf(tuning().claim_seconds, BuzzRules.tuning().claim_seconds)
	return {"kind": option["kind"], "cyborg": cyborg, "charger": charger}


## Files `option` (dog_option, tank_option) among the `options`, or counts why it was turned down in `rejected`
## ("<kind>: <why>" -> how many).
static func _sort_option(option: Dictionary, options: Array[Dictionary], rejected: Dictionary, kind: String) -> void:
	if option.has("cyborg"):
		options.append(option)
		return
	var key: String = "%s: %s" % [kind, String(option.get("why", "?"))]
	rejected[key] = int(rejected.get(key, 0)) + 1


## Every cyborg planted in a charge's path in `layout`, along the track.
static func planted_in(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == CYBORG and (e.get("params", {}) as Dictionary).has(PARAM):
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## The dog or tank entry whose charge planted cyborg `cyborg` stands in the path of ({} if none): the Octodog
## whose `through_at` is its spot, or the Buzz Overdrive whose parked cut's lane it stands in, in front of it.
static func charger_of(layout: LevelLayout, cyborg: Dictionary) -> Dictionary:
	var at: float = float(cyborg["at"])
	var lane: int = int(cyborg.get("lane", -1))
	for e: Dictionary in layout.enemies:
		var params: Dictionary = e.get("params", {})
		match String(e.get("type", "")):
			DOG:
				if int(params.get("through_lane", -1)) == lane and absf(float(params.get("through_at", INF)) - at) < 0.01:
					return e
			TANK:
				var cut: Dictionary = BuzzRules.cut_of(layout, e)
				if not cut.is_empty() and bool(cut.get("park", false)) and int(cut["lane"]) == lane \
						and at < float(cut["end"]) and at > FloorCutPlan.charge_at(cut):
					return e
	return {}


## The planted cyborg's entry for an Octodog `dog` (its first planned lunge from its spot), with what planting it
## takes: {kind, charger, cyborg, warn (where the runner is as its wind-up starts), claim, lane (the dog's lane
## for it)}; {why} if it can't take one fairly (see the header).
static func dog_option(gen: LevelGenerator, t: ChargePathTuning, rng: RandomNumberGenerator, dog: Dictionary) -> Dictionary:
	var params: Dictionary = dog.get("params", {})
	var anchors: Array = params.get("charge_at", [])
	if anchors.is_empty() or params.has("through_lane"):
		return {"why": "no planned charges"}
	if bool(params.get("bait", false)):
		return {"why": "a gap bait"}
	var ot: OctodogTuning = OctodogRules.tuning()
	var scaling: float = gen.config.enemy_scaling
	var v: float = gen.speed
	var d: float = float(dog["at"])
	var a0: float = float(anchors[0])
	var stop: float = ot.stop_distance(v, scaling, gen.pace)
	if absf(d - stop - a0) > 0.5:
		return {"why": "its first charge isn't from its spot"}
	var n: int = gen.layout.lane_count
	var own: int = int(dog.get("lane", 0))
	var flip: bool = rng.randf() < 0.5
	var windup: float = ot.windup_time(scaling)
	var strike_end: float = a0 + (windup + ot.lunge_duration(v, scaling, gen.pace) + t.hold_after_seconds) * v
	var claim: float = a0 - t.claim_seconds * v
	var margin: float = t.attack_margin_seconds * v
	var span := Vector2(claim - margin, strike_end + margin)
	var near: String = attack_near(gen, dog, span)
	if near != "":
		return {"why": "near " + near}
	# Its own lane first, then (where its lane has no two lanes beside it on a side, or they don't fit) the
	# others it may stand in at its spot: floor under it and no hover truck keeping the lane. The cyborg where
	# the tuning puts it, or a little further on (the lunge then reaches the far lane later, never past it).
	var why: String = "no two lanes beside it"
	for lane: int in _dog_lanes(gen, dog, own):
		for k: int in 2:
			var side: int = 1 if (k == 0) == flip else -1
			var through: int = lane + side
			var far: int = lane + 2 * side
			if far < 0 or far >= n:
				continue
			var lanes: Array[int] = [lane, through, far]
			near = attack_near(gen, dog, span, lanes)
			if near != "":
				why = "near " + near
				continue
			for step: int in DOG_SPOTS:
				var c: float = d - gen.metres(t.dog_cyborg_ahead + DOG_SPOT_STEP * step)
				if not dog_in_view(gen, t, ot, d, c):
					why = "out of view"
					break
				var cyborg: Dictionary = _cyborg(c, through, DOG, Vector2(a0 - t.hold_before_seconds * v, strike_end))
				if not _cyborg_fits(gen, cyborg):
					why = "no room for the cyborg"
					continue
				if not path_clear(gen, ot, lane, through, d, c):
					why = "a hole on the lunge's path"
					continue
				return {"kind": DOG, "charger": dog, "cyborg": cyborg, "warn": a0, "claim": claim, "lane": lane}
	return {"why": why}


## True if a dog standing at `d` that lunges through a cyborg at `c` (its first, planted lunge, at the level's run
## speed) reaches it with the runner still in_view_seconds or more behind it.
static func dog_in_view(gen: LevelGenerator, t: ChargePathTuning, ot: OctodogTuning, d: float, c: float) -> bool:
	var lunge: float = ot.lunge_speed_at(gen.config.enemy_scaling, gen.pace)
	var t_touch: float = maxf(d - c - CONTACT_DEPTH, 0.0) / maxf(lunge, 0.01)
	var runner: float = d - ot.lunge_start_distance * gen.pace + gen.speed * t_touch
	return c - runner >= t.in_view_seconds * gen.speed - 0.001


## The lanes Octodog `dog` may stand in at its spot for a planted lunge: its own (`own`) first, then the others
## with floor under it there and no hover truck keeping them (HoverTruckRules.open_lanes), nearest first.
static func _dog_lanes(gen: LevelGenerator, dog: Dictionary, own: int) -> Array[int]:
	var at: float = float(dog["at"])
	var out: Array[int] = [own]
	var others: Array[int] = []
	for lane: int in HoverTruckRules.open_lanes(gen, at):
		if lane != own and not gen.layout.gapped_between(lane, at - 1.5, at + 1.5):
			others.append(lane)
	others.sort_custom(func(a: int, b: int) -> bool:
		return absi(a - own) < absi(b - own) or (absi(a - own) == absi(b - own) and a < b))
	out.append_array(others)
	return out


## The planted cyborg's entry for Buzz Overdrive `tank` (its cut parked), with {kind, charger, cyborg, cut, warn
## (where the runner is as its rev starts)}; {why} if it can't take one fairly (see the header).
static func tank_option(gen: LevelGenerator, t: ChargePathTuning, tank: Dictionary) -> Dictionary:
	var cut: Dictionary = BuzzRules.cut_of(gen.layout, tank)
	if cut.is_empty() or bool(cut.get("park", false)):
		return {"why": "no cut"}
	var v: float = gen.speed
	var warn: float = FloorCutPlan.warn_at(cut)
	var meet: float = FloorCutPlan.meet(cut, v)
	var claim: float = warn - maxf(t.claim_seconds, BuzzRules.tuning().claim_seconds) * v
	var margin: float = t.attack_margin_seconds * v
	var lanes: Array[int] = [int(cut["lane"])]
	var near: String = attack_near(gen, tank, Vector2(claim - margin, FloorCutPlan.window(cut, v).y + margin), lanes)
	if near != "":
		return {"why": "near " + near}
	# The cyborg where the tuning puts it in front of the blade, or a little nearer the runner, in view.
	var why: String = "out of view"
	for step: int in TANK_SPOTS:
		var c: float = float(cut["end"]) - (t.tank_cyborg_seconds + TANK_SPOT_STEP * step) * v
		if not tank_in_view(gen, t, cut, c):
			break
		var cyborg: Dictionary = _cyborg(c, int(cut["lane"]), TANK,
			Vector2(warn - t.hold_before_seconds * v, meet + t.hold_after_seconds * v))
		if _cyborg_fits(gen, cyborg):
			return {"kind": TANK, "charger": tank, "cyborg": cyborg, "cut": cut, "warn": warn}
		why = "no room for the cyborg"
	return {"why": why}


## True if a tank's charge back along `cut` reaches a cyborg at `c` in its lane (at the level's run speed) with the
## runner still in_view_seconds or more behind it.
static func tank_in_view(gen: LevelGenerator, t: ChargePathTuning, cut: Dictionary, c: float) -> bool:
	var runner: float = FloorCutPlan.charge_at(cut) + (float(cut["end"]) - c) / maxf(FloorCutPlan.ratio(cut, gen.speed), 0.0001)
	return c < float(cut["end"]) and c - runner >= t.in_view_seconds * gen.speed - 0.001


## A planted cyborg's layout entry (its seed comes when it's planted).
static func _cyborg(at: float, lane: int, kind: String, hold: Vector2) -> Dictionary:
	return {"type": CYBORG, "at": at, "lane": lane, "side": 0, "seed": 0,
		"params": {"panic": false, "host": false, "stand": true, "hold_fire": hold, PARAM: kind}}


## True if `level` introduces `kind` (the schedule brings it in here: its age is 0) and introductions are skipped.
static func _introduces(gen: LevelGenerator, t: ChargePathTuning, kind: String) -> bool:
	return t.skip_introductions and int(gen.config.feature_ages.get(kind, -1)) == 0


## True if a cyborg entry keeps a cyborg's obstacle margin (CyborgRules: no hole, fence, ramp, pad, speed pad or
## landing zone near, in any lane) and every ceiling's safe floor (CeilingZones.enemy_clear), and stands on floor.
static func _cyborg_fits(gen: LevelGenerator, cyborg: Dictionary) -> bool:
	var ct := EnemyDirector.tuning_for(CYBORG) as CyborgTuning
	var margin: float = CyborgRules.obstacle_margin_at(ct, gen.pace) if ct != null else gen.metres(10.0)
	var spans: Array[Vector2] = CyborgRules.obstacle_spans(gen.layout, gen.tuning, gen.zones)
	var at: float = float(cyborg["at"])
	if CyborgRules.near_any(spans, at, margin) or gen.layout.gapped_between(int(cyborg["lane"]), at - 1.0, at + 1.0):
		return false
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if bool(k.get("calm", false)) and not k.has("lane") and at + CALM_ROOM >= float(k["from"]) \
				and at - CALM_ROOM <= float(k["to"]):
			return false
	return gen.zones.enemy_clear(gen.layout, cyborg)


## True if the planted lunge's path, from the dog's spot `d` in `lane` along the line through the cyborg's spot
## `c` in `through` (and on, as far as the lunge goes at the run speed), keeps off every hole: a lunge carried
## over one falls in (Octodog: gap bait).
static func path_clear(gen: LevelGenerator, ot: OctodogTuning, lane: int, through: int, d: float, c: float) -> bool:
	var geo := TrackGeometry.new(gen.layout.lane_count, gen.tuning)
	var scaling: float = gen.config.enemy_scaling
	var travel: float = ot.lunge_speed_at(scaling, gen.pace) * ot.lunge_duration(gen.speed, scaling, gen.pace)
	var x0: float = geo.lane_x(lane)
	var slope: float = (geo.lane_x(through) - x0) / maxf(d - c, 0.01)
	var lo: float = geo.lane_x(0)
	var hi: float = geo.lane_x(gen.layout.lane_count - 1)
	var z: float = d + 1.0
	while z >= d - travel - 1.0:
		var x: float = clampf(x0 + slope * maxf(d - z, 0.0), lo, hi)
		for probe: float in [x - PATH_SIDE, x + PATH_SIDE]:
			if gen.layout.gapped_between(geo.lane_at(probe), z - PATH_MARGIN, z + PATH_MARGIN):
				return false
		z -= PATH_STEP
	return true


## What other big attack planned in the level (other than `charger`'s own) could hold its charge back in `span`
## (track distances: from before its claim to past its strike), or "" if none. A drone's barrage and a hover
## truck's lurch or cannon shot ask for their turn before their warnings, so they wait for the encounter's claim
## (ChargePathTuning.claim_seconds, longer than any of them lasts); a hover truck only counts where it keeps one
## of the encounter's `lanes` (the dog's, the cyborg's and the far one; the cut's). What can't wait or claims a
## turn of its own keeps its distance: a Bad Dream's chase (a host's), a Resonator's pulses (each from its warning
## until its wave has passed the runner, DangerDensity.resonator_pulse_windows: between them it only hovers; its
## whole visit if it has no plan), a Gilded Sentinel's strike, another Octodog's run (with what a wait for its turn
## moves it on) or Buzz Overdrive's attack, and the rules' other keep-outs (LevelGenerator.rules_doodad_keep_outs).
static func attack_near(gen: LevelGenerator, charger: Dictionary, span: Vector2, lanes: Array[int] = []) -> String:
	var hooks: Dictionary = {}
	var ot: OctodogTuning = OctodogRules.tuning()
	for e: Dictionary in gen.layout.enemies:
		if is_same(e, charger):
			continue
		var busy: Array[Vector2] = []
		match String(e.get("type", "")):
			DOG:
				var run: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
				busy.append(Vector2(run.x, run.y + ot.turn_wait_max * gen.speed))
			"resonator":
				busy = LevelGenerator.DangerDensity.resonator_pulse_windows(gen, e)
				if busy.is_empty():
					busy.append(gen.enemy_keep_out(e, hooks))
			"gilded_sentinel", TANK:
				busy.append(gen.enemy_keep_out(e, hooks))
		for b: Vector2 in busy:
			if b.x <= span.y and b.y >= span.x:
				return String(e.get("type", ""))
	for s: Vector2 in HostRules.chase_stretches(gen):
		if s.x <= span.y and s.y >= span.x:
			return "a Bad Dream's chase"
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if (k.has("lane") and not lanes.has(int(k["lane"]))) or bool(k.get("calm", false)):
			continue  # A calm stretch holds no attack: it keeps off the cyborg itself (_cyborg_fits).
		if float(k["from"]) <= span.y and float(k["to"]) >= span.x:
			return String(k.get("type", "a hover truck's lane" if k.has("lane") else "a rule's keep-out"))
	return ""


## Up to `want` of `options`, spread through the level (each slot's target a seeded spot in its share of the
## track), along the track.
static func _choose(gen: LevelGenerator, rng: RandomNumberGenerator, options: Array[Dictionary], want: int) -> Array[Dictionary]:
	var chosen: Array[Dictionary] = []
	var from: float = gen.config.start_clear_distance
	var to: float = gen.layout.length - gen.config.end_clear_distance
	for k: int in want:
		var target: float = lerpf(from, to, (float(k) + rng.randf_range(0.25, 0.75)) / float(want))
		var best: Dictionary = {}
		for option: Dictionary in options:
			if chosen.has(option) or _shares_charger(chosen, option):
				continue
			if best.is_empty() or absf(float(option["warn"]) - target) < absf(float(best["warn"]) - target):
				best = option
		if best.is_empty():
			break
		chosen.append(best)
	chosen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["warn"]) < float(b["warn"]))
	return chosen


static func _shares_charger(chosen: Array[Dictionary], option: Dictionary) -> bool:
	for c: Dictionary in chosen:
		if is_same(c["charger"], option["charger"]):
			return true
	return false
