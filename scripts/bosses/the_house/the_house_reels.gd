class_name TheHouseReels
extends RefCounted
## The House's three reels (GDD §10: "three huge reels on its chest spin and stop one at a time, each with
## a ding"): what each shows and how its drum turns (TheHouseModel draws them, the_house_reels.gdshader).
## Each reel's strip carries the symbols 7, cherry, BAR and lightning in that order, over and over; a
## reel's angle is where its window's middle is on the strip, in symbols. spin() sets a reel turning; stop()
## brings it to rest on a symbol at once (the fight's logic knows it from then on) while its drum eases
## onto it with a small bounce. A reel locked on 7 (a button run over, GDD §10) glows.

enum Symbol { SEVEN, CHERRY, BAR, LIGHTNING }
enum State { IDLE, SPINNING, STOPPING }

const NAMES: PackedStringArray = ["seven", "cherry", "bar", "lightning"]
## Symbols a second at full spin, and how long a spin takes to wind up and a stop to settle.
const SPIN_SPEED: float = 13.0
const WIND_UP: float = 0.25
const SETTLE: float = 0.34
## A stop always turns the drum at least this far, so the reel visibly lands.
const STOP_MIN: float = 1.5

## Per reel: its angle, speed, state, the symbol it shows (or will, once stopping), locked on 7, and its
## stop's ease {from, to, t}.
var angle := PackedFloat32Array([0.0, 2.0, 1.0])
var speed := PackedFloat32Array([0.0, 0.0, 0.0])
var state: Array[int] = [State.IDLE, State.IDLE, State.IDLE]
var shown: Array[int] = [Symbol.SEVEN, Symbol.BAR, Symbol.CHERRY]
var locked := PackedByteArray([0, 0, 0])
var _from := PackedFloat32Array([0.0, 0.0, 0.0])
var _to := PackedFloat32Array([0.0, 0.0, 0.0])
var _t := PackedFloat32Array([0.0, 0.0, 0.0])


static func symbol_name(s: int) -> String:
	return NAMES[clampi(s, 0, NAMES.size() - 1)]


## The symbol called `name` ("cherry", "bar", "lightning", "seven"); a cherry for anything else.
static func symbol_of(p_name: String) -> int:
	var i: int = NAMES.find(p_name)
	return Symbol.CHERRY if i < 0 else i


## Sets reel `i` spinning (unless it's locked on 7).
func spin(i: int) -> void:
	if locked[i] != 0:
		return
	state[i] = State.SPINNING


## Stops reel `i` on `symbol` now: the fight reads it from here on; the drum eases onto it. `lock`: a
## button locked it on 7 (it glows until unlock()).
func stop(i: int, symbol: int, lock: bool = false) -> void:
	shown[i] = symbol
	if lock:
		locked[i] = 1
	var a: float = angle[i]
	var k: float = ceilf(a + STOP_MIN)
	while posmod(int(k), 4) != int(symbol):
		k += 1.0
	_from[i] = a
	_to[i] = k
	_t[i] = 0.0
	state[i] = State.STOPPING


## Every reel's lock off (a new rigging after the jackpot).
func unlock() -> void:
	locked = PackedByteArray([0, 0, 0])


func spinning(i: int) -> bool:
	return state[i] == State.SPINNING


func any_spinning() -> bool:
	return spinning(0) or spinning(1) or spinning(2)


## The three symbols shown, in reel order.
func symbols() -> Array[int]:
	return [shown[0], shown[1], shown[2]]


func tick(delta: float) -> void:
	for i: int in 3:
		match state[i]:
			State.SPINNING:
				speed[i] = move_toward(speed[i], SPIN_SPEED, SPIN_SPEED / WIND_UP * delta)
				angle[i] += speed[i] * delta
			State.STOPPING:
				_t[i] = minf(_t[i] + delta / SETTLE, 1.0)
				angle[i] = lerpf(_from[i], _to[i], _back_out(_t[i]))
				speed[i] = (1.0 - _t[i]) * SPIN_SPEED
				if _t[i] >= 1.0:
					angle[i] = _to[i]
					speed[i] = 0.0
					state[i] = State.IDLE
			_:
				speed[i] = 0.0
		# Keep the angle small (the strip repeats every 4 symbols).
		if angle[i] > 4000.0 and state[i] == State.IDLE:
			angle[i] = fposmod(angle[i], 4.0)


## What the model draws: the angles, each reel's smear (0-1) and its lock glow.
func angles() -> Vector3:
	return Vector3(angle[0], angle[1], angle[2])


func blur() -> Vector3:
	return Vector3(speed[0], speed[1], speed[2]) / SPIN_SPEED


func lock_glow() -> Vector3:
	return Vector3(locked[0], locked[1], locked[2])


## An ease that overshoots a little and settles back (a reel landing).
static func _back_out(x: float) -> float:
	var c1: float = 1.2
	var c3: float = c1 + 1.0
	var u: float = x - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u
