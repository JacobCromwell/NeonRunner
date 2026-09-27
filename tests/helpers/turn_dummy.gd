extends Enemy
## A test enemy with a scripted big attack, for the director's turn-taking
## (EnemyDirector.major_attack_blocked, GDD §9). It gets ready `first` seconds after it spawns and
## `interval` seconds after each attack, then asks for its turn every frame until it may go; its
## attack then warns for `warning` seconds and hurts for `attack` seconds (is_major_attack_active
## over both), and it can fire a shot that reaches the player `shot` seconds later
## (EnemyDirector.note_attack_shot). It never hurts anyone: it only reports.
## Spawn params: {first, interval, warning, attack, shot, give_up (seconds it waits before it lets
## this attack go; 0 = never), chain (asks again while its attack is on, like the Bad Dream's next
## slash), exclusive (bool), exclusive_of (Array of type names)}.
## Its history lists [event, level time]: ready, held, start (its warning starts), hit (its attack
## starts), end, gave_up, and "again" / "again_held" for chained asks.

enum Step { IDLE, READY, WARNING, ATTACK }

var step: Step = Step.IDLE
var history: Array = []
var first: float = 0.0
var interval: float = 1.0
var warning: float = 0.5
var attack: float = 0.5
var shot: float = 0.0
var give_up: float = 0.0
var chain: bool = false
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
				_ask(now)
		Step.READY:
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
					world.director.note_attack_shot(self, shot)
		Step.ATTACK:
			_clock -= delta
			if _clock <= 0.0:
				step = Step.IDLE
				_clock = interval
				history.append(["end", now])


func _ask(now: float) -> void:
	if world.director.major_attack_blocked(self):
		if history.is_empty() or history[-1][0] != "held":
			history.append(["held", now])
		if give_up > 0.0 and now - _ready_at >= give_up:
			history.append(["gave_up", now])
			step = Step.IDLE
			_clock = interval
		return
	waits.append(now - _ready_at)
	step = Step.WARNING
	_clock = warning
	history.append(["start", now])


func is_major_attack_active() -> bool:
	return alive and (step == Step.WARNING or step == Step.ATTACK)


func should_retire() -> bool:
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
