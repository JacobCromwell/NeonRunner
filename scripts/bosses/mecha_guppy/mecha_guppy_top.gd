class_name MechaGuppyTop
extends Node3D
## Phase 3 of Mecha Guppy and Captain Cogs, "Level with Captain Cogs" (GDD §10; reworked by the owner, October 15, 2026,
## task E5e-g: "we will be adding the Mecha Guppy to the third phase of the boss fight. The Mecha Guppy will be on the
## right side of the screen, while Captain Cogs is on the left side of the screen still ... his attacks should come at the
## player horizontally ... they need to be jumpable and dodgeable ... As the player dodges these attacks, the Mecha Guppy
## is in turn hit with the attacks. So the timed aspect of phase three is to be replaced instead with a health bar, and
## the health bar corresponds to the Mecha Guppy's health ... the Mecha Guppy can take some damage from the bombs sent from
## Captain Cogs, and it will go underneath the water. And then when it reappears, it causes a splash, which causes the wave
## attack. Then, after the wave attack, the Mecha Guppy will do its signature chomp bite attack"). MechaGuppy begins it the
## moment the runner stands on the top (top_reached): the climb's last roof, a long tiki bar roof deck running on flat, with
## no more pads, huts or bites of the climb's. From then on:
## - Captain Cogs' ship comes level, alongside the top on the left (CaptainCogsShip.come_level), and Mecha Guppy rises
##   into its watch beside the top on the right (MechaGuppyShark.top_watch), keeping pace with the runner;
## - the barrages (MechaGuppyBarrage): from top_first on, word after word of MechaGuppyTuning.barrage_script (looped; a
##   fixed, learnable script, GDD §10: no escalation), one bomb a letter, low (L: jump it) or high (H: slide under it),
##   fired across every lane at the runner, each warned bomb_warning ahead; the next bomb's warning bomb_gap after the
##   last's at the soonest and never before the last has passed the runner by beat_spare (one dodge at a time), and
##   barrage_rest between two barrages. Every bomb that gets past the runner flies on into Mecha Guppy's head: a hit
##   (bomb_landed: BossPhase.hits of them empty its bar, the boss bar being its health), and the last hit wins the fight;
## - after every dive_every hits (a barrage stops there, and waits for its bombs in flight), the interlude: Mecha Guppy
##   dives (MechaGuppyShark.top_dive); surface_after later it bursts up out of the sea ahead on the right with a splash
##   (MechaGuppyShark.top_splash, a plume, guppy_leap) and falls back in as the wave's swell rises right there
##   (MechaGuppyWaves: jump the surge); once the surge has passed the runner by bite_after, its floor bite on the top, from
##   the right (MechaGuppyClimb.plan_top_bite: the climb's warning and promises; one leaving a lane, then one across every
##   lane to jump, alternating); once that has sunk away and the runner is past its gap, it rises back into its watch and
##   the next barrage begins barrage_rest after.
## Everything is timed by the fight's clock and the runner's own moments (a bomb passing them, a wave passing them): a
## retry plays the same. Nothing comes while the boss isn't vulnerable (an intro) or its attacks are off (tests).

enum Act { NONE, RISE, BARRAGE, DIVE, SPLASH, WAVE, BITE, RETURN }

## The splash's plume (MechaGuppySplash: height, width; metres), at the deck's height where Mecha Guppy breaks out.
const PLUME := Vector2(12.0, 10.0)
## It dives this long after the hit that brings its dive (seconds: its shudder shows first).
const DIVE_AFTER: float = 0.5

var boss: MechaGuppy
var world: RunWorld
var tuning: MechaGuppyTuning
var barrage: MechaGuppyBarrage
var waves: MechaGuppyWaves
var plume: MechaGuppySplash
## The fight time the runner reached the top, or -1 before.
var began_at: float = -1.0
## What phase 3 is doing (Act), and since when (seconds of phase 3: elapsed()).
var act: Act = Act.NONE
var act_at: float = 0.0
## The barrage under way: its word (letters left to fire come from bomb_n on), its index among the barrages (-1 before the
## first), and when its next bomb's warning may come (seconds of phase 3).
var word: String = ""
var barrage_n: int = -1
var bomb_n: int = 0
var next_bomb_at: float = INF
## Hits landed in phase 3, and since the last dive; when the last landed (seconds of phase 3).
var hits: int = 0
var hits_since_dive: int = 0
var last_hit_at: float = -INF
## Interludes begun (dives), the wave and the floor bite of the one under way.
var interludes: int = 0
var wave: Dictionary = {}
var bite: MechaGuppyCrescent
## True once the fight is won (phase 3 over).
var finished: bool = false
## Beats begun (barrages' bombs and waves: tests), in order: {k, kind (&"bomb", &"wave"), high, at (seconds of phase 3)}.
var beats: Array[Dictionary] = []

var _beat_k: int = 0
var _plume_played: int = 0


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	tuning = boss.tuning
	top_level = true
	transform = Transform3D.IDENTITY
	barrage = MechaGuppyBarrage.new()
	barrage.name = "Barrage"
	add_child(barrage)
	barrage.setup(boss)
	barrage.on_landed = bomb_landed
	waves = MechaGuppyWaves.new()
	waves.name = "Waves"
	add_child(waves)
	waves.setup(boss)
	plume = MechaGuppySplash.new()
	plume.name = "SplashPlume"
	add_child(plume)


## True once phase 3 has begun (the runner reached the top).
func started() -> bool:
	return began_at >= 0.0


## The runner reached the top at fight time `at`: the ship comes level, Mecha Guppy rises into its watch, the first barrage
## waits for top_first.
func begin(at: float) -> void:
	if started():
		return
	began_at = at
	if boss.ship != null:
		boss.ship.come_level()
	_set_act(Act.RISE)
	if boss.shark != null:
		boss.shark.top_watch(world.player.floor_base)
	_next_barrage(tuning.top_first)
	boss.log_event(&"top_begin", {"words": words(tuning).size()})


## Seconds of phase 3 so far (0 before it begins).
func elapsed() -> float:
	return maxf(boss.fight_time() - began_at, 0.0) if started() else 0.0


## One physics step of phase 3 (MechaGuppy's ticks drive it): the bombs, the waves and the plume move, and the next thing
## comes when it's due (while the boss is vulnerable and its attacks are on).
func tick(delta: float) -> void:
	barrage.tick(delta)
	waves.tick(delta)
	plume.advance(delta)
	if not started() or finished or not boss.is_vulnerable() or not boss.attacks_enabled:
		return
	var t: float = elapsed()
	match act:
		Act.RISE, Act.RETURN:
			if boss.shark == null or boss.shark.watching():
				_set_act(Act.BARRAGE)
		Act.BARRAGE:
			_barrage_tick(t)
		Act.DIVE:
			if t - act_at >= tuning.bite_sink + tuning.surface_after - 0.0001 and boss.shark != null and boss.shark.idle():
				_splash()
		Act.SPLASH:
			var shark: MechaGuppyShark = boss.shark
			# Its plume as it breaks out (a third of its rise) and as it falls back in.
			if _plume_played == 0 and t - act_at >= MechaGuppyShark.SPLASH_RISE * 0.35:
				_play_plume()
			if t - act_at >= MechaGuppyShark.SPLASH_RISE + MechaGuppyShark.SPLASH_HOLD - 0.0001:
				_play_plume()
				wave = waves.start(_next_k())
				beats.append({"k": int(wave["k"]), "kind": &"wave", "high": false, "at": t})
				_set_act(Act.WAVE)
			elif shark == null:
				_set_act(Act.WAVE)
		Act.WAVE:
			if wave.is_empty() or (wave.has("passed") and waves.clock - float(wave["passed"]) >= tuning.bite_after - 0.0001) \
					or int(wave.get("state", MechaGuppyWaves.State.DONE)) == MechaGuppyWaves.State.DONE:
				if boss.shark == null or boss.shark.can_breach(world.player.floor_base):
					_floor_bite()
		Act.BITE:
			var fb: MechaGuppyFloorBite = boss.floor_bite
			var p: Player = world.player
			var past: bool = bite == null or p.distance > bite.to + world.tuning.hurtbox_size.z * 0.5
			var done: bool = fb == null or fb.bite != bite or fb.snapped_at >= 0.0 or bite == null
			if past and done and (boss.shark == null or boss.shark.idle()):
				_set_act(Act.RETURN)
				if boss.shark != null:
					boss.shark.top_watch(p.floor_base)
				_next_barrage(t + tuning.barrage_rest)


## A bomb reached Mecha Guppy (MechaGuppyBarrage): its clang, fireball and shudder, and the hit (the boss bar drops; the
## last one wins the fight).
func bomb_landed(_b: Dictionary, point: Vector3) -> void:
	if finished:
		return
	if boss.shark != null:
		boss.shark.hit(point)
	hits += 1
	hits_since_dive += 1
	last_hit_at = elapsed()
	boss.register_hit(&"bomb")


## Everything of phase 3's attacks off (the fight is won): the bombs and the waves gone, nothing more to come.
func clear() -> void:
	finished = true
	barrage.clear()
	waves.clear()


## The barrages' words (MechaGuppyTuning.barrage_script: each a run of L and H; anything else left out), for `t`.
static func words(t: MechaGuppyTuning) -> Array[String]:
	var out: Array[String] = []
	for w: String in t.barrage_script.to_upper().split(" ", false):
		var clean: String = ""
		for c: String in w:
			if c == "L" or c == "H":
				clean += c
		if not clean.is_empty():
			out.append(clean)
	return out


func _barrage_tick(t: float) -> void:
	# A bomb in flight that has passed the runner lets the next one come (beat_spare after), bomb_gap after the last's
	# warning at the soonest.
	var last: Dictionary = barrage.bombs[-1] if not barrage.bombs.is_empty() else {}
	if not last.is_empty():
		if float(last["passed"]) < 0.0 and int(last["state"]) != MechaGuppyBarrage.State.DONE:
			return
		if float(last["passed"]) >= 0.0:
			var passed_t: float = t - (barrage.clock - float(last["passed"]))
			next_bomb_at = maxf(next_bomb_at, passed_t + tuning.beat_spare)
	if hits_since_dive >= tuning.dive_every:
		# Enough hits for a dive: no more bombs; once those in flight are done (and its shudder from the last hit shows), it
		# goes under.
		if not barrage.busy() and t >= last_hit_at + DIVE_AFTER - 0.0001:
			_dive()
		return
	if bomb_n >= word.length():
		if not barrage.busy():
			_next_barrage(t + tuning.barrage_rest)
		return
	if t < next_bomb_at - 0.0001 or (boss.shark != null and not boss.shark.watching()):
		return
	var high: bool = word[bomb_n] == "H"
	var k: int = _next_k()
	barrage.fire(k, bomb_n, high)
	beats.append({"k": k, "kind": &"bomb", "high": high, "at": t, "barrage": barrage_n, "n": bomb_n})
	bomb_n += 1
	next_bomb_at = t + tuning.bomb_gap


## The next barrage, its first bomb's warning at `at` (seconds of phase 3) at the soonest.
func _next_barrage(at: float) -> void:
	var all: Array[String] = words(tuning)
	barrage_n += 1
	word = all[barrage_n % all.size()] if not all.is_empty() else ""
	bomb_n = 0
	next_bomb_at = at
	boss.log_event(&"barrage", {"n": barrage_n, "word": word, "at": at})


func _dive() -> void:
	interludes += 1
	hits_since_dive = 0
	_set_act(Act.DIVE)
	if boss.shark != null:
		boss.shark.top_dive()


## Mecha Guppy bursts up out of the sea ahead on the right, where the wave's swell will rise as it falls back in.
func _splash() -> void:
	var p: Player = world.player
	var v: float = maxf(p.speed, 1.0)
	var at: float = p.distance + v * (MechaGuppyShark.SPLASH_RISE + MechaGuppyShark.SPLASH_HOLD + tuning.wave_warning) \
		+ tuning.wave_ahead
	_plume_played = 0
	_set_act(Act.SPLASH)
	if boss.shark != null and boss.shark.top_splash(at, p.floor_base):
		boss.sound(&"guppy_leap", Vector3(boss.shark.hinge.x, p.floor_base, TrackGeometry.world_z(at)))


func _play_plume() -> void:
	if _plume_played >= 2 or boss.shark == null:
		_plume_played += 1
		return
	var at: Vector3 = Vector3(boss.shark.hinge.x, world.player.floor_base, boss.shark.hinge.z)
	plume.play(at, PLUME.x * (1.0 if _plume_played == 0 else 0.8), PLUME.y)
	_plume_played += 1


## Its floor bite on the top, from the right: the climb's warning and snap (MechaGuppyFloorBite, MechaGuppyShark.floor_bite).
func _floor_bite() -> void:
	var p: Player = world.player
	_set_act(Act.BITE)
	bite = boss.climb.plan_top_bite(p.distance, interludes % 2 == 0, 1) if boss.climb != null else null
	if bite == null or boss.shark == null or boss.floor_bite == null:
		return
	var speed: float = maxf(p.speed, 1.0)
	var lunge: float = (tuning.bite_dive + tuning.bite_rise + tuning.bite_hold + tuning.bite_snap) * speed
	var spot: Dictionary = {"side": bite.side, "top": boss.climb.roofs[bite.roof].top, "roof": bite.roof,
		"at": (bite.from + bite.to) * 0.5, "bite": bite, "snap_at": bite.snap_at, "lunge_at": bite.snap_at - lunge}
	if boss.shark.floor_bite(spot):
		boss.floor_bite.start(bite)
	else:
		bite.skipped = true
		boss.log_event(&"floor_bite_skipped", {"roof": bite.roof, "top": true})


func _set_act(next: Act) -> void:
	act = next
	act_at = elapsed()
	boss.log_event(&"top_act", {"act": Act.keys()[next], "at": act_at})


func _next_k() -> int:
	_beat_k += 1
	return _beat_k - 1
