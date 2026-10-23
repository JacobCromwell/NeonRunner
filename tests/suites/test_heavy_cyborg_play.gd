extends TestSuite
## The Heavy Cyborg in the campaign's own builds, played through (GDD §9.16; task S1, the review's play check): Relay
## Station, Specimen Vault and the Golden Zone's three levels at 3, 5 and 6 lanes on their own seeds, as the campaign
## configures them, at each level's own pace, with everything else the level holds in play (its heli drones, window
## cyborgs and cyborgs sharing the airspace). A runner in god mode who stays on the floor (steering round the anti-grav
## pads, which would lift them onto a ceiling, where a Heavy Cyborg holds its fire as a cyborg does, and the
## teleporters, which would carry them past it; grapples pull them out of gaps) passes every Heavy Cyborg, and every one
## winds up (its warning first) and fires a stream of min_stream_rounds rounds at the least, Relay Station's first, its
## introduction, among them; every round comes from ahead after a whole wind-up, flies its warning from the barrels'
## tips and arrives where the path around it is clear of fences and gaps. test_heavy_cyborg has the rest.

const LEVELS: Array[String] = ["ice_lab/2", "ice_lab/3", "golden/1", "golden/2", "golden/3"]
const LANES: Array[int] = [3, 5, 6]
## Metres past the last Heavy Cyborg the run goes on (its last rounds land behind the runner's spot by then).
const PAST: float = 30.0
## Metres ahead in their lane the runner looks for an anti-grav pad or a teleporter to steer round (_steer), and seconds
## between two lane switches.
const LOOK_AHEAD: float = 30.0
const STEER_EVERY: float = 0.3

var sim: RunSim
var ht: HeavyCyborgTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	ht = load("res://data/enemies/heavy_cyborg.tres") as HeavyCyborgTuning
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	check(ht != null and campaign != null, "its tuning and the campaign load")
	if ht == null or campaign == null:
		return
	var others: Dictionary = {}
	var lines: PackedStringArray = []
	for id: String in LEVELS:
		for lanes: int in LANES:
			lines.append(await _play(campaign, id, lanes, others))
	print("  Heavy Cyborgs played: %s" % "; ".join(lines))
	check(int(others.get("drone", 0)) > 0 and int(others.get("window_cyborg", 0)) > 0 and int(others.get("cyborg", 0)) > 0,
		"with heli drones, window cyborgs and cyborgs in play beside them (%s)" % [others])


## Plays `id` at `lanes` lanes to past its last Heavy Cyborg and checks every one fired (see the header). Counts the other
## shooters met in `others`; returns a line for the log.
func _play(campaign: Campaign, id: String, lanes: int, others: Dictionary) -> String:
	var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
	var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
	var layout: LevelLayout = gen.layout
	var tag: String = "%s lanes=%d" % [id, lanes]
	var homes: Array[float] = LevelGenerator.feature_positions(layout, "heavy_cyborg")
	check(not homes.is_empty(), "%s has Heavy Cyborgs" % tag)
	if homes.is_empty():
		return "%s: none" % tag
	var movement: MovementTuning = config.movement_for(tuning)
	var loadout := Loadout.new()
	loadout.charges[&"grapple"] = 999
	var w: RunWorld = sim.build_world(layout, loadout, movement, config)
	w.player.god_mode = true
	var guns: Dictionary = {}
	w.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e is HeavyCyborg:
			guns[(e as HeavyCyborg).home] = (e as HeavyCyborg).gun
		elif e.type_id in [&"drone", &"window_cyborg", &"cyborg"]:
			others[String(e.type_id)] = int(others.get(String(e.type_id), 0)) + 1)
	await tree.physics_frame
	w.player.running = true
	var end: float = homes[-1] + PAST
	var frames: int = int((end + 60.0) / movement.run_speed * 1.3 * Engine.physics_ticks_per_second)
	var steered: Array[float] = [-INF]
	for i: int in frames:
		_steer(w, layout, steered)
		await tree.physics_frame
		if w.player.distance > end:
			break
	check(w.player.distance > end, "%s: the runner gets past the last Heavy Cyborg (%.0f m of %.0f)" % [tag,
		w.player.distance, end])
	var fired: int = 0
	var rounds: int = 0
	for home: float in homes:
		var gun: CyborgGun = guns.get(home, null)
		check(gun != null, "%s: the Heavy Cyborg at %.0f m comes into play" % [tag, home])
		if gun == null:
			continue
		var shots: int = _check_rounds(gun, layout, movement.pace(), "%s at %.0f m" % [tag, home])
		rounds += shots
		fired += 1 if shots >= ht.min_stream_rounds else 0
		check(shots >= ht.min_stream_rounds, "%s: the Heavy Cyborg at %.0f m winds up and fires a stream (%d rounds%s)"
			% [tag, home, shots, ", Relay Station's introduction" if id == "ice_lab/2" and home == homes[0] else ""])
	await sim.free_world(w)
	return "%s: %d of %d fired, %d rounds" % [tag, fired, homes.size(), rounds]


## Keeps the runner on the floor (see the header): where an anti-grav pad or a teleporter lies within LOOK_AHEAD in their
## lane, a switch to the nearest lane free of both there, at most every STEER_EVERY seconds (`steered`: the last one's
## level time).
static func _steer(w: RunWorld, layout: LevelLayout, steered: Array[float]) -> void:
	var p: Player = w.player
	if p.surface != Player.Surface.FLOOR or w.level_time() - steered[0] < STEER_EVERY \
			or not _lift_ahead(layout, p.lane, p.distance):
		return
	for s: int in [1, -1, 2, -2]:
		var to: int = p.lane + s
		if to < 0 or to >= layout.lane_count or _lift_ahead(layout, to, p.distance):
			continue
		for k: int in absi(s):
			p.press(&"move_right" if s > 0 else &"move_left")
		steered[0] = w.level_time()
		return


## True if an anti-grav pad or a teleporter's pad lies in `lane` within LOOK_AHEAD past track distance `d`.
static func _lift_ahead(layout: LevelLayout, lane: int, d: float) -> bool:
	for pad: Dictionary in layout.pads:
		if int(pad["lane"]) == lane and float(pad["at"]) >= d - 2.0 and float(pad["at"]) <= d + LOOK_AHEAD:
			return true
	for t: Dictionary in layout.teleporters:
		if int(t["lane"]) == lane and float(t["end"]) >= d - 2.0 and float(t["at"]) <= d + LOOK_AHEAD:
			return true
	return false


## Checks every round `gun` fired (see the header): after a whole wind-up, from ahead, its warning from the barrels'
## tips (the first min_warning_time, the rest later_round_warning_share of it), the path around its arrival clear of
## fences and gaps (its tuning's clear stretch at the level's `pace`, a little inside it). Returns how many it fired.
func _check_rounds(gun: CyborgGun, layout: LevelLayout, pace: float, tag: String) -> int:
	var shots: int = 0
	var charge_t: float = -1.0
	var first: bool = false
	for ev: Dictionary in gun.events:
		match ev["event"]:
			&"charge":
				charge_t = float(ev["t"])
				first = true
			&"cancel":
				charge_t = -1.0
			&"shot":
				shots += 1
				var t: float = float(ev["t"])
				check(charge_t >= 0.0 and t - charge_t >= ht.charge_time - 0.02, "every round follows a wind-up " + tag)
				check(float(ev["shooter_d"]) > float(ev["player_d"]), "every round comes from ahead " + tag)
				var flight: float = float(ev["arrive"]) - t
				var least: float = ht.min_warning_time * (1.0 if first else ht.later_round_warning_share)
				check(flight >= least - 0.005, "every round flies its warning (%.3f s, %.3f at the least) %s" % [flight, least,
					tag])
				first = false
				var impact: float = float(ev["impact"])
				check(CyborgGun.floor_clear(layout, impact - ht.clear_before_impact * pace + 1.5,
					impact + ht.clear_after_impact * pace - 1.5), "no round arrives near a fence, a gap or a doodad (%.1f m) %s"
					% [impact, tag])
	return shots
