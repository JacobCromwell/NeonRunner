class_name GoldenConvergenceRefill
extends GoldenConvergenceAttack
## The Refill Ship (GDD §10, "Damaging the suit: the Refill Ship", the owner's design; task E5d-c), beat kind
## `refill` (its argument the script of the Helidrone Strafe that comes with it): the only way to damage the golden
## suit. "After the boss has fired its Missile Barrages (one in phase 1, two in later phases), a ship comes in to
## refill his missiles. It feeds them to him along a line running to his shoulder pipes." Every point of it is keyed
## to the runner's distance at the run speed (its chain reaction to the physics clock), so a dash never desyncs it
## and every attempt plays the same:
## 1. the ship (GoldenConvergenceShip: a gilded cult cargo ship, its belly a ceiling over every lane) flies in from
##    behind and above the runner to its station beside the causeway on the fed shoulder's side (proposed: the
##    shoulder whose pipes are whole, his right first; with both blown out, his right's torn stubs) and paces them
##    there; the feed line shoots out from its boom to the shoulder's pipes, the hatch over them opens, and missiles
##    ride up the line (gc_ship, gc_feed, gc_ride);
## 2. the beat's Helidrone Strafe (GoldenConvergenceStrafe, `refill`) comes out of the cape at once and flies its
##    passes;
## 3. once it has flown cage_after of them, the cage comes up (GoldenConvergenceCage: the anti-grav pad in an inner
##    lane behind its front fence, the lengthwise sides, the generator in a lane beside it, the fences flickering in
##    with their warning, gc's fence crackle), cage_lead ahead of the runner; the squadron holds its fire
##    (strafe.hold, GDD §10's clear route: "the lanes the runner needs for the generator and the pad are never under
##    the strafe's fire ... no horizontal pass lands while the cage is coming up"), hovering in formation beside the
##    ship under its racks (hold_station); the ship comes over the causeway and down to the ceiling's height,
##    pacing the runner, its belly over every lane (and over them), settled settle_before before they reach the
##    front fence;
## 4. the ways in (the dash, the generator's pulse, armor or the shield spent on a fence) lead onto the pad: the
##    runner flips up onto the belly, and the pad hurls the squadron up into the ship (the strafe's pad rule,
##    `hurled`): the chain reaction (chain): the drones crash into its racks (the squadron explodes: that strafe is
##    over), its missiles explode in a ripple along the racks (gc_ripple), it spins off to the side, its belly gone
##    (the runner falls back to the floor unharmed, onto floor nothing of the boss's is on), and explodes beside the
##    causeway (gc_crash); the blast races up the feed line into his shoulder (gc_blast), and the hit lands:
##    damage(hit_damage(), &"refill_ship"), a third of the suit's health. Each shows: the first blows out one
##    shoulder's pipes, the second the other's (gc_pipes, GoldenConvergenceSuit.set_pipes_broken), the third bursts
##    the suit open (phase 3 ends: GoldenConvergenceTransition plays its own blast, the only one then);
## 5. a missed pad (the runner past it by miss_after without riding): the strafe fires on (its passes left, planned
##    on from the runner), the ship climbs back to its station, finishes refilling and flies off (gc_leave); the beat
##    is over when the strafe and the ship are, and the phase's loop starts again from the slams (loop_from). It
##    never gets harder (GDD §10: no escalation): the next ship is the same.
## Planning ahead (E5d-b's slams plan their holes past the built track): ends_at() says where a missed refill's
## beat will be over (the strafe's passes left and the ship's leaving), so the loop's slams after it are planned
## while it plays; a chain reaction ends the phase, so it plans the next phase's first slams itself
## (GoldenConvergenceSlams.plan_phase_ahead) from where its hit will land and the next phase's intro, and that
## phase opens with its first fist on time instead of stalking the runner while its holes are planned.
## Weapons never target the ship or the cage (proposed; docs/OPEN_QUESTIONS.md items 416–503): the ship is immune and never
## targetable, the fences are hazards, the generator is the game's (weapons never set one off). They still chip the
## suit.
## Numbers: GoldenConvergenceTuning's "Refill Ship" groups (DESIGN-TBD, docs/OPEN_QUESTIONS.md, items 469–482).

## The chain reaction began (the pad), and its hit landed; a pad missed.
signal chained(info: Dictionary)
signal hit_landed(info: Dictionary)
signal pad_missed(info: Dictionary)

enum Stage { IDLE, ON, CHAIN, DONE }
enum ShipStage { HIDDEN, ARRIVE, STATION, DESCEND, LOW, SPIN, CLIMB, FINISH, LEAVE, GONE }
enum FeedStage { NONE, REACH, ON, BURN, RETRACT }

const SHIP_SCRIPT: Script = preload("res://scripts/bosses/golden_convergence/golden_convergence_ship.gd")
## The ship flies in from this far behind the runner and this high, a little in from its station's side.
const ARRIVE_BEHIND: float = 46.0
const ARRIVE_HIGH: float = 30.0
## It flies off to this far ahead, this high, this much further out than its station.
const LEAVE_AHEAD: float = 220.0
const LEAVE_HIGH: float = 55.0
const LEAVE_OUT: float = 1.6
## Spinning off: out past the walls' line this far, down this far (a little: E5d polish, it used to sink 10 m, below
## the deck, and explode out of the cameras' sight), rolling this far over (its belly turning away), surging this
## far ahead of where it rode (into the run camera's view): it explodes beside the causeway above its level, where the
## run camera and the side see it (GoldenConvergenceShip.explode). DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 487).
const SPIN_OUT: float = 10.0
const SPIN_DOWN: float = 1.5
const SPIN_ROLL: float = 2.3
const SPIN_AHEAD: float = 30.0
## The hatch over the fed pipes swings open or shut over this long.
const HATCH_SECONDS: float = 0.5
## While it feeds, the riding missiles' clatter repeats this often.
const RIDE_SOUND_EVERY: float = 1.3
## The blast up the line drops a burst of fire this often.
const BLAST_STEP: float = 0.07
## The squadron's pad hurl's rise outside this fight's refill (GoldenConvergenceSquadron's default).
const HURL_RISE_DEFAULT: float = 6.0

var ship: GoldenConvergenceShip
var cage: GoldenConvergenceCage
var stage: Stage = Stage.IDLE
var ship_stage: ShipStage = ShipStage.HIDDEN
var feed: FeedStage = FeedStage.NONE
## Refills begun this fight; chain reactions; hits landed; pads missed.
var refills: int = 0
var chains: int = 0
var hits: int = 0
var misses: int = 0
## The refill under way: {n, start, arrive_to, side (the fed shoulder: -1 its right, 1 its left), script, cage_after,
## cage_at (where the runner was as the cage came up, -1 before), front_at, desc_from, desc_to, miss_at, missed,
## climb_to, finish_to, leave_to}.
var p: Dictionary = {}
## The chain reaction under way: {t, d (where the runner was at the pad), ripple: Array[int] (rack missiles in
## order), rippled, spun, exploded, blasted, side, line_from_rel}.
var chain: Dictionary = {}
## The runner's ride: dropped off the belly (its distance), landed back on the floor ({distance, lane}).
var dropped_at: float = -1.0
var landed: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _feed_t: float = 0.0
var _ride_sound: float = 0.0
var _hatch: float = 0.0
var _hatch_side: int = -1
## A ship move under way blends from where it was at its start: its place relative to the runner (x, y, and its
## middle this far ahead of the runner) and its turn (pitch, yaw, roll). E5d polish: two vectors, not a Dictionary
## made a frame.
var _from_at := Vector3.ZERO
var _from_turn := Vector3.ZERO
var _move_t: float = 0.0
## The ship's pose relative to the runner as last placed (the same two), and whether it has been since it came.
var _rel_at := Vector3.ZERO
var _rel_turn := Vector3.ZERO
var _placed: bool = false
var _riding: bool = false


func _init(p_boss: GoldenConvergence) -> void:
	super(p_boss, &"refill")
	ship = boss.add_part(SHIP_SCRIPT, {"tuning": boss.tuning}) as GoldenConvergenceShip
	cage = GoldenConvergenceCage.new()
	boss.add_child(cage)
	cage.setup(boss)
	boss.strafe.hurled.connect(_on_hurled)
	boss.world.player.movement_event.connect(_on_player_event)


## The ship hidden at its arrival point (its meshes and materials made with the fight, not mid-fight).
func prewarm() -> void:
	ship.set_shown(false)


func busy() -> bool:
	return stage == Stage.ON or stage == Stage.CHAIN


## The cage is up ahead of the runner (its fences a hazard to read).
func warning_on() -> bool:
	return busy() and cage.ahead()


## True while the cage is up and the runner hasn't passed its pad.
func cage_up() -> bool:
	return busy() and cage.up and not bool(p.get("missed", false)) and stage != Stage.CHAIN and cage.ahead()


## The shoulder it feeds (-1 its right, the runner's left; 1 its left): the one whose pipes are whole, his right
## first; with both blown out, his right's torn stubs. DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 470).
func fed_side() -> int:
	var suit: GoldenConvergenceSuit = boss.suit
	if suit == null or not suit.pipes_broken[0]:
		return -1
	if not suit.pipes_broken[1]:
		return 1
	return -1


## The refill begins: the ship flies in, the strafe comes out of the cape.
func start(beat: Dictionary) -> void:
	clear()
	refills += 1
	_rng.seed = hash([String(boss.def.id), "refill", refills, boss.rng.seed])
	var t: GoldenConvergenceTuning = boss.tuning
	var d: float = boss.player_distance()
	var v: float = boss.speed_planned()
	var script: String = String(beat.get("arg", ""))
	var side: int = fed_side()
	p = {"n": refills, "start": d, "arrive_to": d + v * t.ship_in_seconds, "side": side, "script": script,
		"cage_at": -1.0, "missed": false}
	stage = Stage.ON
	_t = 0.0
	_hatch_side = side
	dropped_at = -1.0
	landed = {}
	_riding = false
	ship.set_shown(true)
	ship.set_belly(false)
	_set_ship(ShipStage.ARRIVE)
	_from_at = _arrive_at()
	_from_turn = _arrive_turn()
	_place_ship(d)
	boss.squadron.hurl_rise = HURL_RISE_DEFAULT
	boss.strafe.start({"kind": &"refill", "arg": script})
	p["cage_after"] = _cage_after()
	boss.sound(&"gc_ship", boss.sound_point(ship.global_position))
	boss.hint("refill")
	boss.log_event(&"refill_start", {"n": refills, "side": side, "script": script, "runner": d, "lane": boss.player_lane()})


## The passes the strafe flies before the cage comes up: cage_after, or fewer if its script has no more than that
## (one is always left for after the pad, so the squadron is out when the runner gets there).
func _cage_after() -> int:
	var passes: int = boss.strafe.passes.size()
	return clampi(boss.tuning.cage_after, 0, maxi(passes - 1, 0))


## A phase's intro or the defeat (its tick() doesn't run): the hatch over the fed pipes swings shut, a cage
## sinking away goes on sinking.
func look_tick(delta: float) -> void:
	_tick_hatch(delta)
	cage.tick(delta)


func tick(delta: float) -> void:
	_tick_hatch(delta)
	cage.tick(delta)
	if stage == Stage.IDLE or stage == Stage.DONE:
		return
	_t += delta
	var d: float = boss.player_distance()
	if stage == Stage.CHAIN:
		_tick_chain(delta, d)
		if stage != Stage.CHAIN:
			# The hit landed: the phase ended, and everything was cleared (clear()).
			return
	else:
		_tick_refill(d)
	_tick_ship(delta, d)
	_tick_feed(delta)
	_watch_ride()


# --- The refill ----------------------------------------------------------------------------------------

func _tick_refill(d: float) -> void:
	var s: GoldenConvergenceStrafe = boss.strafe
	if float(p["cage_at"]) < 0.0:
		var between: bool = s.current < 0 and s.stage == GoldenConvergenceStrafe.Stage.PASSES
		if (between and _passes_done(s) >= int(p["cage_after"])) or (int(p["cage_after"]) == 0 and s.busy()):
			_raise_cage(d)
		return
	if not bool(p["missed"]):
		if d >= float(p["miss_at"]) and boss.world.player.surface != Player.Surface.CEILING:
			_miss(d)
		return
	# Missed: the ship climbs back to its station, finishes refilling and flies off; the beat is over once the strafe
	# and the ship are.
	if ship_stage == ShipStage.GONE and not s.busy():
		stage = Stage.DONE
		boss.log_event(&"refill_done", {"n": int(p["n"]), "hit": false, "runner": d})
	elif ship_stage == ShipStage.FINISH and d >= float(p["finish_to"]):
		_set_ship(ShipStage.LEAVE)
		feed = FeedStage.RETRACT
		_feed_t = 0.0
		boss.sound(&"gc_leave", boss.sound_point(ship.global_position))
		boss.log_event(&"refill_leaves", {"n": int(p["n"]), "runner": d})
	elif ship_stage == ShipStage.LEAVE and d >= float(p["leave_to"]):
		_set_ship(ShipStage.GONE)
		ship.set_shown(false)
	elif ship_stage == ShipStage.CLIMB and d >= float(p["climb_to"]):
		_set_ship(ShipStage.FINISH)


## Passes the strafe has finished.
static func _passes_done(s: GoldenConvergenceStrafe) -> int:
	var n: int = 0
	for pass_info: Dictionary in s.passes:
		if int(pass_info["stage"]) == GoldenConvergenceStrafe.PassStage.DONE:
			n += 1
	return n


## The cage comes up: cage_lead ahead of the runner (or more: GoldenConvergenceCage.lead_seconds), its pad in an
## inner lane (by the fight's seed), its generator in a lane beside it (by the seed); the squadron holds its fire
## beside the ship, which comes down over the causeway.
func _raise_cage(d: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var v: float = boss.speed_planned()
	var lanes: int = boss.lane_count()
	var lane: int = _rng.randi_range(1, lanes - 2) if lanes >= 3 else 0
	var gen_lane: int
	if lanes < 2:
		gen_lane = lane
	elif lanes < 3:
		gen_lane = 1 - lane
	else:
		gen_lane = lane + (-1 if _rng.randf() < 0.5 else 1)
	var front_at: float = d + v * GoldenConvergenceCage.lead_seconds(t, boss.world.tuning, lanes)
	cage.place(lane, gen_lane, front_at)
	var span: Dictionary = cage.plan
	p["cage_at"] = d
	p["front_at"] = front_at
	p["lane"] = lane
	p["gen_lane"] = gen_lane
	p["desc_to"] = maxf(front_at - v * t.settle_before, d + 1.0)
	p["desc_from"] = clampf(float(p["desc_to"]) - v * t.descend_seconds, d, float(p["desc_to"]) - 1.0)
	p["miss_at"] = float(span["pad_to"]) + t.miss_after * boss.run_pace()
	var s: GoldenConvergenceStrafe = boss.strafe
	s.hold_station = func(i: int) -> Vector3: return ship.hold_point(i, boss.squadron.size())
	s.hold(true)
	boss.squadron.hurl_rise = ship.hurl_rise()
	boss.sound(&"fence_warning", boss.sound_point(boss.world.lane_point(lane, front_at, 1.0)))
	boss.hint("cage")
	boss.log_event(&"cage_up", {"n": int(p["n"]), "lane": lane, "gen_lane": gen_lane, "front_at": front_at,
		"pad_from": span["pad_from"], "pad_to": span["pad_to"], "gen_at": span["gen_at"], "runner": d,
		"runner_lane": boss.player_lane(), "passes_done": _passes_done(s)})


## Past the pad without riding the ship: a miss. The strafe fires on, the ship climbs back to its station.
func _miss(d: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var v: float = boss.speed_planned()
	p["missed"] = true
	misses += 1
	ship.set_belly(false)
	_set_ship(ShipStage.CLIMB)
	p["climb_to"] = d + v * t.climb_seconds
	p["finish_to"] = float(p["climb_to"]) + v * t.finish_seconds
	p["leave_to"] = float(p["finish_to"]) + v * t.leave_seconds
	var s: GoldenConvergenceStrafe = boss.strafe
	s.hold(false)
	s.hold_station = Callable()
	boss.squadron.hurl_rise = HURL_RISE_DEFAULT
	var info := {"n": int(p["n"]), "runner": d, "lane": boss.player_lane(), "pad_to": cage.plan.get("pad_to", 0.0)}
	boss.log_event(&"refill_missed", info)
	pad_missed.emit(info)


# --- The planning ahead ---------------------------------------------------------------------------------

## Where the beat will be over, at the run speed: once a pad is missed, the strafe's passes left and the ship's
## leaving (the loop's slams after it plan from here); -1 before (it isn't known yet whether the pad is ridden, and a
## ride ends the phase: the chain plans the next phase's slams itself).
func ends_at() -> float:
	if stage != Stage.ON or not bool(p.get("missed", false)):
		return -1.0
	var s: GoldenConvergenceStrafe = boss.strafe
	var strafe_end: float = s.ends_at() if s.busy() else boss.player_distance()
	if s.busy() and strafe_end < 0.0:
		return -1.0
	var ship_end: float = float(p["leave_to"]) if ship_stage != ShipStage.GONE else boss.player_distance()
	return maxf(strafe_end, ship_end)


# --- The chain reaction ---------------------------------------------------------------------------------

## The pad hurled the squadron (GoldenConvergenceStrafe's pad rule): if it was the cage's pad, the chain reaction
## begins.
func _on_hurled() -> void:
	if stage != Stage.ON or float(p.get("cage_at", -1.0)) < 0.0 or bool(p.get("missed", false)):
		return
	var player: Player = boss.world.player
	var span: Dictionary = cage.plan
	if span.is_empty() or player.lane != int(p["lane"]) or player.distance < float(span["pad_from"]) - 1.5 \
			or player.distance > float(span["pad_to"]) + 1.5:
		return
	_start_chain(player.distance)


func _start_chain(d: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	stage = Stage.CHAIN
	chains += 1
	cage.padded = true
	# The cage has done its work: it sinks away (out of the camera's way as it ducks under the belly).
	cage.retract()
	# The rack missiles blow up in order of their distance from where the drones hit (the ripple spreads both ways).
	var hits_at: Array[Vector3] = []
	for i: int in boss.squadron.size():
		hits_at.append(ship.hold_point(i, boss.squadron.size()) + Vector3(0.0, ship.hurl_rise(), 0.0))
	var order: Array = []
	for i: int in ship.rack_count():
		var at: Vector3 = ship.rack_point(i)
		var near: float = INF
		for h: Vector3 in hits_at:
			near = minf(near, Vector2(at.x - h.x, at.z - h.z).length() + absf(signf(at.x) - signf(h.x)) * 50.0)
		order.append([near, i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (is_equal_approx(float(a[0]), float(b[0])) and int(a[1]) < int(b[1])))
	var ripple: Array[int] = []
	for e: Array in order:
		ripple.append(int(e[1]))
	chain = {"t": 0.0, "d": d, "ripple": ripple, "rippled": 0, "spun": false, "exploded": false, "blasted": false,
		"side": int(p["side"]), "blast_step": 0.0, "from_rel": Vector3.ZERO}
	var info := {"n": int(p["n"]), "runner": d, "lane": boss.player_lane(), "phase": boss.phase_index,
		"hit_in": t.spin_at + t.spin_seconds + t.blast_seconds}
	boss.log_event(&"refill_chain", info)
	chained.emit(info)
	_plan_next_phase(d)


## The hit ends the phase: the next phase's first slams are planned now, from where its first beat will begin
## (the hit, the next phase's intro, its first beat's delay), so their holes lie past the built track in time.
func _plan_next_phase(d: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var next: int = boss.phase_index + 1
	if boss.slams == null or next >= GoldenConvergence.STAGE_2 or next >= boss.phase_count():
		return
	var phase_def: BossPhase = boss.def.phase_list()[next]
	var to_hit: float = t.spin_at + t.spin_seconds + t.blast_seconds
	var start_d: float = d + boss.speed_planned() * (to_hit + phase_def.intro_seconds + t.first_beat_delay / maxf(phase_def.pace, 0.05))
	boss.slams.plan_phase_ahead(next, start_d)


func _tick_chain(delta: float, d: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	chain["t"] = float(chain["t"]) + delta
	var ct: float = float(chain["t"])
	# The ripple along the racks.
	var ripple: Array[int] = chain["ripple"]
	var count: int = ripple.size()
	if ct >= t.ripple_at and int(chain["rippled"]) == 0 and count > 0:
		boss.sound(&"gc_ripple", boss.sound_point(ship.global_position))
		boss.world.effects.shake(0.35, 0.5)
		boss.log_event(&"refill_ripple", {"n": int(p["n"])})
	while int(chain["rippled"]) < count and ct >= t.ripple_at + t.ripple_seconds * float(int(chain["rippled"])) / float(count):
		ship.explode_rack(ripple[int(chain["rippled"])])
		chain["rippled"] = int(chain["rippled"]) + 1
	# It spins off to the side, its belly gone: the runner drops back to the floor.
	if ct >= t.spin_at and not bool(chain["spun"]):
		chain["spun"] = true
		ship.set_belly(false)
		_set_ship(ShipStage.SPIN)
		boss.log_event(&"ship_spins", {"n": int(p["n"]), "runner": d, "riding": boss.world.player.surface == Player.Surface.CEILING})
	# It explodes beside the causeway; the blast starts up the line.
	var explode_at: float = t.spin_at + t.spin_seconds
	if ct >= explode_at and not bool(chain["exploded"]):
		chain["exploded"] = true
		var at: Vector3 = ship.blast_center()
		# The blast races up the line from where the ship goes off (its boom, rolled over, points below the deck).
		chain["from_rel"] = Vector3(at.x, at.y + 1.5, -at.z - d)
		ship.explode()
		ship.set_line(Vector3(at.x, at.y + 1.5, at.z), boss.suit.pipe_mouth(int(chain["side"])), 1.0)
		boss.sound(&"gc_crash", boss.sound_point(at))
		boss.world.effects.shake(0.6, 0.8)
		feed = FeedStage.BURN
		_feed_t = 0.0
		boss.sound(&"gc_blast", boss.sound_point(at))
		boss.log_event(&"ship_exploded", {"n": int(p["n"]), "x": at.x, "y": at.y, "runner": d})
	if bool(chain["exploded"]) and not bool(chain["blasted"]):
		var u: float = clampf((ct - explode_at) / maxf(t.blast_seconds, 0.05), 0.0, 1.0)
		chain["blast_step"] = float(chain["blast_step"]) - delta
		if float(chain["blast_step"]) <= 0.0 and u < 1.0:
			chain["blast_step"] = BLAST_STEP
			var at: Vector3 = ship.line_point(u)
			ship.fireball(at, 2.6, 0.45)
			if not Settings.flashing_reduced:
				boss.world.effects.burst(at, GoldenConvergenceShip.FIRE, 8, 0.6)
		if u >= 1.0:
			chain["blasted"] = true
			_blast_lands()


## The blast reaches his shoulder: the first two blow out a shoulder's pipes; the third bursts the suit open (phase
## 3's end: the transition plays its own blast, so this one adds none); then the hit lands, a third of the suit's
## health, and the phase ends (clear() follows at once).
func _blast_lands() -> void:
	var suit: GoldenConvergenceSuit = boss.suit
	var side: int = int(chain["side"])
	var phase: int = boss.phase_index
	ship.hide_line()
	feed = FeedStage.NONE
	var mouth: Vector3 = suit.pipe_mouth(side)
	var burst_suit: bool = phase >= GoldenConvergence.STAGE_2 - 1
	if not burst_suit:
		suit.set_pipes_broken(side, true)
		ship.fireball(mouth, 4.5, 0.9)
		ship.smoke(mouth + Vector3(0.0, 2.0, 0.0), 4.0, 2.4)
		if not Settings.flashing_reduced:
			boss.world.effects.burst(mouth, GoldenConvergenceShip.FIRE_HOT, 30, 1.8)
		boss.world.effects.shake(0.45, 0.5)
		boss.sound(&"gc_pipes", boss.sound_point(mouth))
	hits += 1
	var info := {"n": int(p["n"]), "hit": hits, "side": side, "phase": phase, "burst": burst_suit, "runner": boss.player_distance(),
		"damage": boss.hit_damage()}
	boss.log_event(&"refill_hit", info)
	hit_landed.emit(info)
	boss.damage(boss.hit_damage(), &"refill_ship")


# --- The ship's flight --------------------------------------------------------------------------------

## Where the ship is relative to the runner for its stage (_pose_now), blended from where a move began.
func _tick_ship(delta: float, d: float) -> void:
	_move_t += delta
	match ship_stage:
		ShipStage.ARRIVE:
			if d >= float(p["arrive_to"]):
				_set_ship(ShipStage.STATION)
				feed = FeedStage.REACH
				_feed_t = 0.0
				_ride_sound = RIDE_SOUND_EVERY
				boss.sound(&"gc_feed", boss.sound_point(ship.boom_point()))
				boss.log_event(&"refill_feed", {"n": int(p["n"]), "side": int(p["side"])})
		ShipStage.STATION:
			if float(p.get("cage_at", -1.0)) >= 0.0 and not bool(p["missed"]) and d >= float(p["desc_from"]):
				_set_ship(ShipStage.DESCEND)
		ShipStage.DESCEND:
			if d >= float(p["desc_to"]):
				_set_ship(ShipStage.LOW)
				ship.set_belly(true)
				boss.log_event(&"ship_low", {"n": int(p["n"]), "runner": d, "front_at": p.get("front_at", 0.0)})
	if ship_stage == ShipStage.HIDDEN or ship_stage == ShipStage.GONE:
		return
	if ship_stage == ShipStage.SPIN and bool(chain.get("exploded", false)):
		return
	_place_ship(d)


func _set_ship(next: ShipStage) -> void:
	if ship_stage != ShipStage.HIDDEN and ship_stage != ShipStage.GONE:
		_from_at = _rel_at if _placed else _station_at()
		_from_turn = _rel_turn if _placed else _station_turn()
	ship_stage = next
	_move_t = 0.0


## The ship's pose now, relative to the runner at `d`.
func _place_ship(d: float) -> void:
	_pose_now(d)
	_placed = true
	ship.set_pose(Transform3D(Basis.from_euler(_rel_turn), Vector3(_rel_at.x, _rel_at.y, TrackGeometry.world_z(d + _rel_at.z))))


## Its pose for its stage now, relative to the runner at `d`: sets _rel_at (x, y, its middle ahead of the runner)
## and _rel_turn (pitch, yaw, roll).
func _pose_now(d: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var side: float = float(p.get("side", -1))
	match ship_stage:
		ShipStage.ARRIVE:
			var k: float = _progress(d, float(p["start"]), float(p["arrive_to"]))
			var e: float = 1.0 - pow(1.0 - k, 2.2)
			_rel_at = _arrive_at().lerp(_station_at(), e)
			_rel_turn = _arrive_turn().lerp(_station_turn(), e) - Vector3(0.0, 0.0, side * 0.18 * sin(PI * k))
		ShipStage.STATION, ShipStage.FINISH:
			_blend_to(_station_at(), _station_turn(), smoothstep(0.0, 1.0, clampf(_move_t / 0.6, 0.0, 1.0)))
		ShipStage.DESCEND:
			var k: float = smoothstep(0.0, 1.0, _progress(d, float(p["desc_from"]), float(p["desc_to"])))
			_blend_to(_low_at(), Vector3.ZERO, k)
			_rel_turn.z += side * 0.22 * sin(PI * k)
		ShipStage.LOW:
			_blend_to(_low_at(), Vector3.ZERO, clampf(_move_t / 0.2, 0.0, 1.0))
		ShipStage.CLIMB:
			_blend_to(_station_at(), _station_turn(), smoothstep(0.0, 1.0, _progress(d, float(p["miss_at"]), float(p["climb_to"]))))
		ShipStage.LEAVE:
			var k: float = _progress(d, float(p["finish_to"]), float(p["leave_to"]))
			_blend_to(_leave_at(), _leave_turn(), k * k)
		ShipStage.SPIN:
			var k: float = clampf(_move_t / maxf(t.spin_seconds, 0.05), 0.0, 1.0)
			var e: float = k * k
			_rel_at = _from_at + Vector3(side * (boss.world.geo.wall_x() + SPIN_OUT) * (1.0 - (1.0 - k) * (1.0 - k)),
				-SPIN_DOWN * e, SPIN_AHEAD * k)
			_rel_turn = Vector3(_from_turn.x - 0.35 * k, -side * 0.4 * k, _from_turn.z + side * SPIN_ROLL * e)
		_:
			_rel_at = _station_at()
			_rel_turn = _station_turn()


## The pose `k` (0-1) of the way from where the move began to `at` turned `turn`.
func _blend_to(at: Vector3, turn: Vector3, k: float) -> void:
	_rel_at = _from_at.lerp(at, k)
	_rel_turn = _from_turn.lerp(turn, k)


## Its station beside the causeway on the fed shoulder's side (framing, gently bobbing): where, and its turn.
func _station_at() -> Vector3:
	var t: GoldenConvergenceTuning = boss.tuning
	var side: int = int(p.get("side", -1))
	return Vector3(side * t.ship_side, t.ship_station_height + 0.35 * sin(_t * 1.1), t.ship_station_ahead)


func _station_turn() -> Vector3:
	var side: int = int(p.get("side", -1))
	return Vector3(0.0, 0.0, side * 0.04 * sin(_t * 0.7))


## Down over the causeway at the ceiling's height, the runner RIDER behind its middle (level).
func _low_at() -> Vector3:
	return Vector3(0.0, boss.world.tuning.ceiling_height, GoldenConvergenceShipModel.RIDER)


## Where it comes in from: high, behind the runner, its nose a little down.
func _arrive_at() -> Vector3:
	var side: int = int(p.get("side", -1))
	return Vector3(side * boss.tuning.ship_side * 0.6, ARRIVE_HIGH, -ARRIVE_BEHIND)


func _arrive_turn() -> Vector3:
	return Vector3(0.12, 0.0, 0.0)


## Where it goes as it leaves: far ahead, high, out to its side, banking away.
func _leave_at() -> Vector3:
	var side: int = int(p.get("side", -1))
	return Vector3(side * boss.tuning.ship_side * LEAVE_OUT, LEAVE_HIGH, LEAVE_AHEAD)


func _leave_turn() -> Vector3:
	var side: int = int(p.get("side", -1))
	return Vector3(-0.12, 0.0, side * 0.2)


static func _progress(d: float, from: float, to: float) -> float:
	return clampf((d - from) / maxf(to - from, 0.01), 0.0, 1.0)


# --- The feed line, the hatch --------------------------------------------------------------------------

func _tick_feed(delta: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	_feed_t += delta
	var mouth: Vector3 = boss.suit.pipe_mouth(int(p.get("side", -1)))
	match feed:
		FeedStage.NONE:
			return
		FeedStage.REACH:
			var k: float = clampf(_feed_t / maxf(t.feed_reach_seconds, 0.05), 0.0, 1.0)
			ship.set_line(ship.boom_point(), mouth, k)
			if k >= 1.0:
				feed = FeedStage.ON
		FeedStage.ON:
			ship.set_line(ship.boom_point(), mouth, 1.0)
			ship.ride(delta, t.feed_speed, t.feed_every)
			_ride_sound -= delta
			if _ride_sound <= 0.0:
				_ride_sound = RIDE_SOUND_EVERY
				boss.sound(&"gc_ride", boss.sound_point(ship.line_point(0.3)))
		FeedStage.RETRACT:
			var k: float = clampf(1.0 - _feed_t / maxf(t.feed_reach_seconds, 0.05), 0.0, 1.0)
			ship.set_line(ship.boom_point(), mouth, k)
			if k <= 0.0:
				ship.hide_line()
				feed = FeedStage.NONE
		FeedStage.BURN:
			var rel: Vector3 = chain.get("from_rel", Vector3.ZERO)
			var from := Vector3(rel.x, rel.y, TrackGeometry.world_z(boss.player_distance() + rel.z))
			ship.set_line(from, mouth, 1.0)
			ship.burn_line(clampf(_feed_t / maxf(t.blast_seconds, 0.05), 0.0, 1.0))


## The hatch over the fed pipes opens while the line feeds them, and shuts after (the barrage leaves the hatches
## alone while it's idle; it opens them itself for its own salvo).
func _tick_hatch(delta: float) -> void:
	var want: float = 1.0 if feed == FeedStage.REACH or feed == FeedStage.ON else 0.0
	if want <= 0.0 and _hatch <= 0.0:
		return
	if boss.barrage != null and boss.barrage.stage != GoldenConvergenceBarrage.Stage.IDLE:
		return
	_hatch = move_toward(_hatch, want, delta / HATCH_SECONDS)
	if boss.suit != null and is_instance_valid(boss.suit):
		boss.suit.pipes_open[0 if _hatch_side < 0 else 1] = _hatch


# --- The ride, the landing -------------------------------------------------------------------------------

## Notes the runner's ride on the belly: off it (dropped) and back on the floor (landed), for the tests' clear-floor
## check.
func _watch_ride() -> void:
	var player: Player = boss.world.player
	if player.surface == Player.Surface.CEILING:
		_riding = true


func _on_player_event(movement: StringName) -> void:
	if not _riding:
		return
	var player: Player = boss.world.player
	match movement:
		&"hull_end":
			dropped_at = player.distance
			boss.log_event(&"rider_dropped", {"n": int(p.get("n", 0)), "runner": player.distance, "lane": player.lane})
		&"land":
			if dropped_at >= 0.0 and landed.is_empty():
				_riding = false
				landed = {"distance": player.distance, "lane": player.lane, "t": boss.fight_time()}
				boss.log_event(&"rider_landed", {"n": int(p.get("n", 0)), "runner": player.distance, "lane": player.lane})


# --- An EMP, clear ------------------------------------------------------------------------------------------

## An EMP reached the ship (every part hears one): the cage's fences it reaches go dark (its own generator's pulse
## switches the whole cage off).
func on_emp(center: Vector3, radius: float) -> void:
	cage.emp(center, radius)


## Everything gone at once (a phase's end, the defeat), safely: the ship and its line, the cage (a generator still
## standing ahead of the runner out of play), the squadron's hold. Fire already burning fades on its own.
func clear() -> void:
	super()
	stage = Stage.IDLE
	chain = {}
	p = {}
	ship_stage = ShipStage.HIDDEN
	feed = FeedStage.NONE
	_from_at = Vector3.ZERO
	_from_turn = Vector3.ZERO
	_placed = false
	_riding = false
	if ship != null and is_instance_valid(ship):
		ship.set_shown(false)
	if cage != null and is_instance_valid(cage):
		cage.put_away()
	var s: GoldenConvergenceStrafe = boss.strafe
	if s != null:
		s.hold_station = Callable()
	if boss.squadron != null and is_instance_valid(boss.squadron):
		boss.squadron.hurl_rise = HURL_RISE_DEFAULT
	if _hatch > 0.0 and boss.suit != null and is_instance_valid(boss.suit) and (boss.barrage == null
			or boss.barrage.stage == GoldenConvergenceBarrage.Stage.IDLE):
		boss.suit.pipes_open[0 if _hatch_side < 0 else 1] = 0.0
	_hatch = 0.0
