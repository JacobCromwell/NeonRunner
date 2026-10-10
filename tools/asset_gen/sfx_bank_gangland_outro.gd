extends "res://tools/asset_gen/sfx_bank.gd"
## The Gangland outro's own sounds (GanglandOutro), in the same crunchy 16-bit style as the rest (none of them is a
## warning; like every sound effect, each is under 2.5 s):
##   screech_sniff  the screeches sniffing at the freed Host: wet snuffles in twos and threes, small chitters and
##                  claws ticking on the asphalt
##   key_glint      the golden key glinting in the Host's hand: a bright bell arpeggio rising into a shimmer
##   car_unlock     the sports car unlocking: two quick chirps and the locks clunking open
##   car_door       its scissor door swinging up (or down): a hydraulic hiss and servo whine, a soft latch
##   car_start      its engine starting: the starter, the catch, a blip of the throttle, idling
##   car_drive      it launches: the tyres biting, the engine roaring up through two gears as it drives away down
##                  the street, fading into the distance

## How long the drive-off lasts, the roar fading to nothing (every sound stays under 2.5 s).
const DRIVE_SECONDS: float = 2.45


func sounds() -> Dictionary:
	return {
		"screech_sniff": _sniff,
		"key_glint": _glint,
		"car_unlock": _unlock,
		"car_door": _door,
		"car_start": _start,
		"car_drive": _drive,
	}


## Snuffling: short, wet in-breaths of noise through a high band, in twos and threes, a few squeaks and claws.
func _sniff() -> PackedFloat32Array:
	var rng := _rng(1701)
	var d: float = 1.8
	var b := DSP.buffer(d)
	var at: float = 0.02
	while at < d - 0.2:
		var count: int = rng.randi_range(2, 3)
		for k: int in count:
			var len: float = rng.randf_range(0.05, 0.09)
			var sniff := DSP.noise(len, rng)
			DSP.filter_sweep(sniff, &"bandpass", rng.randf_range(1800.0, 2600.0), rng.randf_range(3200.0, 4200.0), 2.5)
			DSP.envelope(sniff, len * 0.4, len * 0.3)
			DSP.mix(b, sniff, at + k * rng.randf_range(0.09, 0.12), rng.randf_range(0.5, 0.8))
		at += count * 0.11 + rng.randf_range(0.12, 0.25)
	for k: int in 4:
		var squeak := DSP.fm(0.07, func(u: float) -> float: return DSP.sweep(2600.0, 3400.0, u), 1.0,
			func(u: float) -> float: return 1.4 + 0.6 * sin(PI * u))
		DSP.envelope(squeak, 0.004, 0.03)
		DSP.mix(b, squeak, rng.randf_range(0.1, d - 0.15), 0.2)
	var claws := DSP.buffer(d)
	for k: int in 26:
		var tick := DSP.noise(0.008, rng)
		DSP.envelope(tick, 0.0005, 0.002)
		DSP.mix(claws, tick, rng.randf_range(0.0, d - 0.01), rng.randf_range(0.15, 0.35))
	DSP.filter(claws, &"highpass", 3000.0)
	DSP.mix(b, claws)
	DSP.crush(b, 10, 20000.0)
	return b


## A bright bell arpeggio (FM bells: E6, B6, E7) rising into a soft shimmer of high partials.
func _glint() -> PackedFloat32Array:
	var d: float = 1.4
	var b := DSP.buffer(d)
	var notes: Array[float] = [88.0, 95.0, 100.0]
	for k: int in notes.size():
		var bell := _fm_note(d - k * 0.07, DSP.midi_hz(notes[k]), 3.5, 2.5, 0.6, 0.45)
		DSP.mix(b, bell, k * 0.07, 0.5 - 0.08 * k)
	var shimmer := DSP.buffer(d)
	for k: int in 6:
		var hz: float = DSP.midi_hz(100.0 + k * 2.0)
		var tone := DSP.osc(d - 0.15, func(_u: float) -> float: return hz, &"sine", float(k) * 0.7)
		var n: int = tone.size()
		for i: int in n:
			var u: float = float(i) / n
			tone[i] *= sin(PI * u) * (0.5 + 0.5 * sin(TAU * (6.0 + k) * u * (d - 0.15)))
		DSP.mix(shimmer, tone, 0.15, 0.06)
	DSP.mix(b, shimmer)
	# Bells only: nothing low (the FM's sidebands fold a little energy down there).
	DSP.filter(b, &"highpass", 400.0)
	DSP.crush(b, 11, 24000.0)
	return b


## Two quick chirps (a square tone, the second higher) and the locks clunking open.
func _unlock() -> PackedFloat32Array:
	var rng := _rng(1702)
	var d: float = 0.65
	var b := DSP.buffer(d)
	for k: int in 2:
		var lift: float = 300.0 * k
		var chirp := DSP.osc(0.075, func(u: float) -> float: return DSP.sweep(1900.0 + lift, 2300.0 + lift, u), &"square")
		DSP.filter(chirp, &"bandpass", 2200.0, 0.8)
		DSP.adsr(chirp, 0.004, 0.02, 0.7, 0.02)
		DSP.mix(b, chirp, k * 0.17, 0.45)
	for k: int in 2:
		var clunk := DSP.metal_hit(0.12, 260.0 + 60.0 * k, 0.025, rng)
		DSP.filter(clunk, &"lowpass", 1800.0)
		DSP.mix(b, clunk, 0.38 + k * 0.05, 0.6)
	DSP.crush(b, 10, 20000.0)
	return b


## A hydraulic hiss and a servo whining up, ending on a soft latch.
func _door() -> PackedFloat32Array:
	var rng := _rng(1703)
	var d: float = 1.05
	var b := _whoosh(0.9, 900.0, 3200.0, 1.2, rng)
	for i: int in b.size():
		b[i] *= 0.6
	var servo := DSP.osc(0.85, func(u: float) -> float: return DSP.sweep(320.0, 520.0, u), &"saw")
	DSP.filter(servo, &"lowpass", 1400.0)
	DSP.adsr(servo, 0.08, 0.2, 0.8, 0.15)
	DSP.mix(b, servo, 0.0, 0.18)
	var out := DSP.buffer(d)
	DSP.mix(out, b)
	var latch := DSP.metal_hit(0.15, 420.0, 0.03, rng)
	DSP.filter(latch, &"lowpass", 2400.0)
	DSP.mix(out, latch, 0.86, 0.55)
	DSP.crush(out, 10, 20000.0)
	return out


## The engine starting: the starter cranking, the catch, a blip of the throttle, then idling (its idle fading at
## the end, under car_drive if the car launches first).
func _start() -> PackedFloat32Array:
	var rng := _rng(1704)
	var b := _engine(1.5, _start_rpm, func(_t: float) -> float: return 0.0, rng)
	# The starter: a whining motor pulsing as it turns the engine over.
	var starter := DSP.osc(0.4, func(_u: float) -> float: return 190.0, &"saw")
	for i: int in starter.size():
		var t: float = float(i) / RATE
		starter[i] *= 0.5 + 0.5 * sin(TAU * 11.0 * t)
	DSP.filter(starter, &"bandpass", 700.0, 0.9)
	DSP.adsr(starter, 0.01, 0.1, 0.8, 0.05)
	DSP.mix(b, starter, 0.0, 0.35)
	DSP.shape(b, 0.005, 0.35)
	DSP.crush(b, 10, 22000.0)
	return b


## The launch: the tyres biting, the engine roaring up through first gear, a shift, second, a shift, third, and
## away down the street, duller and quieter as it goes.
func _drive() -> PackedFloat32Array:
	var rng := _rng(1705)
	var b := _engine(DRIVE_SECONDS, _drive_rpm, _drive_away, rng)
	var squeal := DSP.osc(0.5, func(u: float) -> float: return DSP.sweep(1400.0, 1100.0, u), &"saw")
	DSP.filter(squeal, &"bandpass", 1300.0, 3.0)
	DSP.adsr(squeal, 0.02, 0.15, 0.5, 0.2)
	DSP.mix(b, squeal, 0.0, 0.15)
	DSP.shape(b, 0.005, 0.25)
	DSP.crush(b, 10, 22000.0)
	return b


## An engine `seconds` long, its speed (0-1) and how far away it has gone (0-1) over time given by `rpm` and
## `away` (seconds in): ten cylinders' worth of barks with a buzzy saw over them, and the exhaust's roar growing
## with the revs (its band is what phone speakers carry), duller and quieter as it goes.
func _engine(seconds: float, rpm: Callable, away: Callable, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	var n: int = b.size()
	var phase: float = 0.0
	var lp := DSP.Biquad.new()
	var roar := DSP.noise(seconds, rng)
	DSP.filter(roar, &"bandpass", 1000.0, 0.7)
	for i: int in n:
		var t: float = float(i) / RATE
		var r: float = float(rpm.call(t))
		var far: float = float(away.call(t))
		roar[i] *= r * r * (1.0 - 0.95 * far)
		if r <= 0.0:
			continue
		phase += lerpf(34.0, 210.0, r) / RATE
		var p: float = fmod(phase, 1.0)
		var bark: float = exp(-p * lerpf(6.0, 2.5, r))
		var tone: float = (p * 2.0 - 1.0) * 0.55 + sin(TAU * phase * 2.0) * 0.25 + sin(TAU * phase * 5.0) * 0.12 * r
		var s: float = (tone * (0.4 + 0.6 * bark) + rng.randf_range(-1.0, 1.0) * bark * 0.25) * (0.4 + 0.6 * r)
		if i % 64 == 0:
			lp.set_filter(&"lowpass", lerpf(3200.0, 700.0, far), 0.7)
		b[i] = lp.process(s) * (1.0 - 0.9 * far)
	DSP.filter(b, &"highpass", 70.0)
	DSP.drive(b, 2.6, 0.08)
	DSP.mix(b, roar, 0.0, 1.0)
	return b


## The engine's speed (0-1) starting, `t` seconds in: catching at 0.33 s, settling to idle, a blip, idling.
static func _start_rpm(t: float) -> float:
	if t < 0.33:
		return 0.0
	var idle: float = 0.18 + 0.3 * exp(-(t - 0.33) / 0.12)
	return idle + 0.5 * sin(PI * clampf((t - 0.62) / 0.3, 0.0, 1.0))


## The engine's speed (0-1) driving off, `t` seconds after the launch: up through first gear, a shift, second, a
## shift, third.
static func _drive_rpm(t: float) -> float:
	var shifts: Array[float] = [0.0, 0.75, 1.65]
	var g: int = 0
	for k: int in shifts.size():
		if t >= shifts[k]:
			g = k
	var e: float = t - shifts[g]
	var from: float = 0.35 if g == 0 else 0.62
	return lerpf(from, 1.0, 1.0 - exp(-e / (0.35 + 0.25 * g)))


## How far away it has gone (0 here, 1 far down the street), `t` seconds after the launch.
static func _drive_away(t: float) -> float:
	return smoothstep(0.3, DRIVE_SECONDS - 0.1, t)
