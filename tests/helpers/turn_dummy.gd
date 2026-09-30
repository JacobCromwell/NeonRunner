extends Enemy
## A test enemy with a scripted big attack, for the director's turn-taking
## (EnemyDirector.major_attack_blocked, GDD §9). It gets ready `first` seconds after it spawns and
## `interval` seconds after each attack, then asks for its turn every frame until it may go; its
## attack then warns for `warning` seconds and hurts for `attack` seconds (is_major_attack_active
## over both), and it can fire a shot that comes level with the player `shot` seconds later, well
## off to one side (EnemyDirector.note_attack_shot). It never hurts anyone: it only reports.
## Spawn params: {first, interval, warning, attack, shot, give_up (seconds it waits before it lets
## this attack go; 0 = never), chain (asks again while its attack is on, like the Bad Dream's next
## slash), exclusive (bool), exclusive_of (Array of type names), pauses (level-time spans [from, to]
## when it isn't ready: it neither asks nor starts, like an enemy whose stretch isn't clear for a
## moment), stalls (level-time spans when it asks but doesn't start even when it may, like an Octodog
## told it may go that is still moving its charges on to a clear stretch)}.
## Its history lists [event, level time]: ready, held, start (its warning starts), hit (its attack
## starts), end, gave_up, stalled (it may go but isn't ready), and "again" / "again_held" for chained
## asks.

enum Step { IDLE, READY, WARNING, ATTACK }

## Its shot flies this fast toward the player (relative to them), this far off to the side.
const SHOT_SPEED: float = 12.0
const SHOT_SIDE: float = 12.0

var step: Step = Step.IDLE
var history: Array = []
var first: float = 0.0
var interval: float = 1.0
var warning: float = 0.5
var attack: float = 0.5
var shot: float = 0.0
var give_up: float = 0.0
var chain: bool = false
var pauses: Array = []
var stalls: Array = []
## Seconds it waited before each of its attacks started.
var waits: Array[float] = []

var _clock: float = 0.0
var _ready_at: float = 0.0


func _build() -> void:
	var p: Dictionary = spawn.get("params", {})
	display_name = String(spawn.get("type", "dummy"))
	immune_to_weapons = true
	first = float(p.get("first", 0.0))
	interval = float(p.get("interval", 1.0))
	warning = float(p.get("warning", 0.5))
	attack = float(p.get("attack", 0.5))
	shot = float(p.get("shot", 0.0))
	give_up = float(p.get("give_up", 0.0))
	chain = bool(p.get("chain", false))
	pauses = p.get("pauses", [])
	stalls = p.get("stalls", [])
	exclusive_major_attack = bool(p.get("exclusive", false))
	for t: Variant in p.get("exclusive_of", []):
		exclusive_of.append(StringName(t))
	_clock = first
	position = world.lane_point(0, float(spawn.get("at", 0.0)), -5.0)


func _tick(delta: float) -> void:
	var now: float = world.level_time()
	match step:
		Step.IDLE:
			_clock -= delta
			if _clock <= 0.0:
				step = Step.READY
				_ready_at = now
				history.append(["ready", now])
				if not _within(pauses, now):
					_ask(now)
		Step.READY:
			if not _within(pauses, now):
				_ask(now)
		Step.WARNING:
			_clock -= delta
			if chain:
				history.append(["again_held" if world.director.major_attack_blocked(self) else "again", now])
			if _clock <= 0.0:
				step = Step.ATTACK
				_clock = attack
				history.append(["hit", now])
				if shot > 0.0:
					_fire(shot)
		Step.ATTACK:
			_clock -= delta
			if _clock <= 0.0:
				step = Step.IDLE
				_clock = interval
				history.append(["end", now])


## A shot that comes level with the player in `seconds` (in their frame), well off the track.
func _fire(seconds: float) -> void:
	var p: Player = world.player
	var from := Vector3(SHOT_SIDE, 1.0, p.position.z - SHOT_SPEED * seconds)
	var velocity := Vector3(0.0, 0.0, SHOT_SPEED - p.speed)
	world.director.note_attack_shot(self, world.projectiles.fire_enemy(from, velocity, &"enemy_bolt",
		"test shot", seconds + 2.0))


func _ask(now: float) -> void:
	if world.director.major_attack_blocked(self):
		if history.is_empty() or history[-1][0] != "held":
			history.append(["held", now])
		if give_up > 0.0 and now - _ready_at >= give_up:
			history.append(["gave_up", now])
			world.director.give_up_turn(self)
			step = Step.IDLE
			_clock = interval
		return
	if _within(stalls, now):
		if history.is_empty() or history[-1][0] != "stalled":
			history.append(["stalled", now])
		return
	waits.append(now - _ready_at)
	step = Step.WARNING
	_clock = warning
	history.append(["start", now])


func is_major_attack_active() -> bool:
	return alive and (step == Step.WARNING or step == Step.ATTACK)


func should_retire() -> bool:
	return false


## True if level time `now` falls in one of `spans` ([from, to] pairs).
static func _within(spans: Array, now: float) -> bool:
	for s: Variant in spans:
		if now >= float(s[0]) and now < float(s[1]):
			return true
	return false


## How many times `event` is in its history.
func count(event: String) -> int:
	var n: int = 0
	for h: Array in history:
		if h[0] == event:
			n += 1
	return n


## The level times of its attacks, from the start of the warning to the end: [[start, end], ...]
## (an attack still on ends at INF).
func spans() -> Array:
	var out: Array = []
	var open: float = -1.0
	for h: Array in history:
		if h[0] == "start":
			open = float(h[1])
		elif h[0] == "end" and open >= 0.0:
			out.append([open, float(h[1])])
			open = -1.0
	if open >= 0.0:
		out.append([open, INF])
	return out
