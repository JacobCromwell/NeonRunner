extends "res://tools/asset_gen/sfx_bank.gd"
## The Terminal outro's own sounds (TerminalOutro): the runner at the abandoned metro train's front door, the screech
## that opens it, and the train leaving. In the same crunchy 16-bit style as the rest; none is a warning; like every
## sound effect, each is under 2.5 s.
##   door_rattle       the first, firm shake of the locked door: the latch catching, then the frame ticking (0.7 s)
##   door_rattle_hard  the violent shaking: the loose door clattering in its frame, heave after heave, with a rattle of
##                     sheet metal between them and a last slam (1.8 s)
##   door_bang         a fist on a heavy metal door: a dull boom, a short ring and a slap of knuckles (0.55 s)
##   train_door_open   the door opening: a pneumatic hiss, the solenoid clunking, the leaf sliding on its track and
##                     thudding against its stop, a last breath of air (1.6 s)
##   train_door_close  it closing again: the slide, a solid thud and the seal hissing tight (1.3 s)
##   train_start       the train waking: relays clunking as its lights come on (a failing strip's stutter), the
##                     transformer's hum rising, the brakes releasing in a hiss and the motors spinning up (2.4 s)
##   train_depart      pulling away: wheels clacking over the rail joints faster and faster under a rising motor whine
##                     and a growing roar (2.45 s; its ends fade, so it runs on into train_rush)
##   train_rush        the last of it, tearing off into the distance: the rattle at speed and the roar sinking and
##                     fading away to nothing (2.45 s)
##   screech_squeak    the screech's friendly squeak in the window: two quick rising squeaks, "eep-eep!" (0.55 s)

const RUSH_FADE: float = 0.15


func sounds() -> Dictionary:
	return {
		"door_rattle": _rattle,
		"door_rattle_hard": _rattle_hard,
		"door_bang": _bang,
		"train_door_open": _door_open,
		"train_door_close": _door_close,
		"train_start": _start,
		"train_depart": _depart,
		"train_rush": _rush,
		"screech_squeak": _squeak,
	}


## A short tick of loose metal: a high, dry strike that rings for `ring` seconds.
func _tick(hz: float, ring: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.metal_hit(ring * 6.0, hz, ring, rng)
	DSP.filter(b, &"highpass", 300.0)
	return b


## One heave of the door against its frame: a low thump, a ringing clang and a burst of rattling.
func _clang(hz: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var d: float = 0.28
	var b := DSP.metal_hit(d, hz, 0.07, rng)
	DSP.mix(b, DSP.metal_hit(d, hz * 2.9, 0.035, rng), 0.0, 0.35)
	var rattle := DSP.noise(0.2, rng)
	DSP.filter(rattle, &"bandpass", rng.randf_range(1800.0, 3200.0), 2.0)
	var n: int = rattle.size()
	for i: int in n:
		rattle[i] *= (0.5 + 0.5 * sin(TAU * 62.0 * float(i) / RATE)) * exp(-float(i) / RATE / 0.07)
	DSP.mix(b, rattle, 0.0, 0.5)
	return b


## The first shake: the latch catches with a clunk, the frame ticks as the door settles back.
func _rattle() -> PackedFloat32Array:
	var rng := _rng(2101)
	var d: float = 0.7
	var b := DSP.buffer(d)
	var clunk := DSP.metal_hit(0.3, 190.0, 0.06, rng)
	DSP.filter(clunk, &"lowpass", 3200.0)
	DSP.mix(b, clunk, 0.0, 0.9)
	var at: float = 0.07
	var gain: float = 0.5
	for k: int in 5:
		DSP.mix(b, _tick(rng.randf_range(900.0, 1600.0), 0.03, rng), at, gain)
		at += rng.randf_range(0.05, 0.1)
		gain *= 0.7
	DSP.crush(b, 10, 22000.0)
	return b


## The violent shaking: eight heaves at about 5 Hz (a little ragged), each a clang with a rattle, sheet metal buzzing
## between them, the last one a slam, the sound swelling in and tailing off.
func _rattle_hard() -> PackedFloat32Array:
	var rng := _rng(2102)
	var d: float = 1.8
	var b := DSP.buffer(d)
	var at: float = 0.0
	for k: int in 8:
		var hz: float = rng.randf_range(150.0, 280.0)
		var swell: float = 0.55 + 0.45 * sin(PI * clampf(at / 1.5, 0.0, 1.0))
		DSP.mix(b, _clang(hz, rng), at, swell)
		at += rng.randf_range(0.16, 0.22)
	# The sheet metal buzzing in its frame between the heaves.
	var buzz := DSP.noise(d, rng)
	DSP.filter(buzz, &"bandpass", 2400.0, 1.6)
	var n: int = buzz.size()
	for i: int in n:
		var t: float = float(i) / RATE
		var env: float = sin(PI * clampf(t / 1.6, 0.0, 1.0))
		buzz[i] *= env * (0.4 + 0.6 * absf(sin(TAU * 5.2 * t))) * (0.6 + 0.4 * sin(TAU * 37.0 * t))
	DSP.mix(b, buzz, 0.0, 0.3)
	# The last, heaviest slam.
	var slam := DSP.metal_hit(0.4, 120.0, 0.12, rng)
	DSP.mix(b, slam, 1.38, 0.9)
	DSP.drive(b, 1.6)
	DSP.crush(b, 10, 22000.0)
	return b


## A fist on the door: a dull boom that drops away, a short ring of the metal and the slap of knuckles.
func _bang() -> PackedFloat32Array:
	var rng := _rng(2103)
	var d: float = 0.55
	var b := _boom(d, 130.0, 62.0, 0.09, rng)
	DSP.filter(b, &"lowpass", 900.0)
	var ring := DSP.metal_hit(0.4, 330.0, 0.1, rng)
	DSP.filter(ring, &"bandpass", 700.0, 0.9)
	DSP.mix(b, ring, 0.0, 0.5)
	var slap := DSP.noise(0.03, rng)
	DSP.filter(slap, &"bandpass", 1800.0, 1.0)
	DSP.envelope(slap, 0.0005, 0.006)
	DSP.mix(b, slap, 0.0, 0.7)
	DSP.shape(b, 0.001, 0.12)
	DSP.crush(b, 10, 22000.0)
	return b


## A burst of escaping air: noise through a high band, quick attack, fading.
func _hiss(seconds: float, from_hz: float, to_hz: float, tau: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	DSP.filter_sweep(b, &"highpass", from_hz, to_hz, 0.9)
	DSP.envelope(b, 0.008, tau, 0.05)
	return b


## The door opening: a hiss, the solenoid clunking, the leaf sliding on its track, the thud at its stop, a last breath.
func _door_open() -> PackedFloat32Array:
	var rng := _rng(2104)
	var d: float = 1.6
	var b := DSP.buffer(d)
	DSP.mix(b, _hiss(0.45, 2500.0, 4200.0, 0.14, rng), 0.0, 0.55)
	var clunk := DSP.metal_hit(0.2, 230.0, 0.04, rng)
	DSP.filter(clunk, &"lowpass", 2600.0)
	DSP.mix(b, clunk, 0.24, 0.7)
	# The slide: a rolling rumble and the track's whine, swelling and easing off.
	var slide := DSP.noise(0.85, rng)
	DSP.filter_sweep(slide, &"bandpass", 500.0, 1400.0, 0.8)
	var n: int = slide.size()
	for i: int in n:
		var t: float = float(i) / RATE
		slide[i] *= pow(sin(PI * float(i) / n), 1.3) * (0.7 + 0.3 * sin(TAU * 38.0 * t))
	DSP.mix(b, slide, 0.32, 0.5)
	var servo := DSP.osc(0.8, func(u: float) -> float: return DSP.sweep(240.0, 380.0, u) * (1.0 - 0.15 * u), &"saw")
	DSP.filter(servo, &"lowpass", 1200.0)
	DSP.adsr(servo, 0.06, 0.2, 0.8, 0.2)
	DSP.mix(b, servo, 0.34, 0.14)
	# It meets its stop: a soft, heavy thud, and the air let out.
	var thud := _boom(0.3, 150.0, 70.0, 0.07, rng)
	DSP.filter(thud, &"lowpass", 800.0)
	DSP.mix(b, thud, 1.12, 0.7)
	DSP.mix(b, _hiss(0.35, 2200.0, 3000.0, 0.1, rng), 1.18, 0.3)
	DSP.crush(b, 10, 22000.0)
	return b


## The door closing: the slide, a solid thud and the seal hissing tight.
func _door_close() -> PackedFloat32Array:
	var rng := _rng(2105)
	var d: float = 1.3
	var b := DSP.buffer(d)
	var slide := DSP.noise(0.7, rng)
	DSP.filter_sweep(slide, &"bandpass", 1300.0, 500.0, 0.8)
	var n: int = slide.size()
	for i: int in n:
		var t: float = float(i) / RATE
		slide[i] *= pow(sin(PI * float(i) / n), 1.1) * (0.7 + 0.3 * sin(TAU * 38.0 * t))
	DSP.mix(b, slide, 0.0, 0.5)
	var thud := _boom(0.35, 170.0, 65.0, 0.08, rng)
	DSP.filter(thud, &"lowpass", 900.0)
	DSP.mix(b, thud, 0.66, 0.85)
	var latch := DSP.metal_hit(0.15, 420.0, 0.025, rng)
	DSP.filter(latch, &"lowpass", 3000.0)
	DSP.mix(b, latch, 0.74, 0.5)
	DSP.mix(b, _hiss(0.5, 2800.0, 2000.0, 0.17, rng), 0.78, 0.35)
	DSP.crush(b, 10, 22000.0)
	return b


## The train waking: three relays clunking (the lights' stutter), the transformer's hum rising, the brakes letting go
## in a hiss, the traction motors spinning up through the end.
func _start() -> PackedFloat32Array:
	var rng := _rng(2106)
	var d: float = 2.4
	var b := DSP.buffer(d)
	for k: int in 3:
		var at: float = [0.0, 0.2, 0.42][k]
		var relay := DSP.metal_hit(0.18, 150.0 + 30.0 * k, 0.03, rng)
		DSP.filter(relay, &"lowpass", 2800.0)
		DSP.mix(b, relay, at, [0.9, 0.55, 0.7][k])
		DSP.mix(b, _tick(2400.0, 0.012, rng), at + 0.01, 0.4)
	# The transformer's hum, a mains buzz with its harmonics, rising.
	var hum := DSP.osc(d, func(u: float) -> float: return DSP.sweep(90.0, 130.0, u), &"saw")
	DSP.filter(hum, &"lowpass", 900.0)
	var n: int = hum.size()
	for i: int in n:
		var u: float = float(i) / n
		hum[i] *= smoothstep(0.0, 0.25, u) * (0.6 + 0.4 * u)
	DSP.mix(b, hum, 0.0, 0.2)
	# The brakes let go: air out, a long breath.
	DSP.mix(b, _hiss(1.0, 1800.0, 3600.0, 0.35, rng), 0.7, 0.45)
	# The motors spinning up: a whine climbing, wavering.
	var whine := DSP.osc(1.5, func(u: float) -> float: return DSP.sweep(160.0, 760.0, u * u) * (1.0 + 0.012 * sin(TAU * 9.0 * u)), &"saw")
	DSP.filter(whine, &"lowpass", 2400.0)
	DSP.adsr(whine, 0.5, 0.3, 0.9, 0.15)
	DSP.mix(b, whine, 0.9, 0.2)
	DSP.shape(b, 0.003, 0.2)
	DSP.crush(b, 10, 22000.0)
	return b


## One wheelset over a rail joint: a dull clack with a quick ring.
func _clack(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.metal_hit(0.06, rng.randf_range(210.0, 300.0), 0.012, rng)
	DSP.filter(b, &"bandpass", 900.0, 0.7)
	return b


## Pulling away: clacks (two wheelsets a beat apart) faster and faster as it picks up speed, a rumble of the roar growing
## under them and the motors' whine rising past them; the ends fade so it runs on into train_rush.
func _depart() -> PackedFloat32Array:
	var rng := _rng(2107)
	var d: float = 2.45
	var b := DSP.buffer(d)
	# The joints go by faster as it speeds up: about 3 per second at first, 15 at the end.
	var t: float = 0.05
	while t < d - 0.1:
		var u: float = t / d
		var rate: float = lerpf(3.0, 15.0, u * u)
		var strength: float = 0.9 - 0.45 * u
		DSP.mix(b, _clack(rng), t, strength)
		DSP.mix(b, _clack(rng), t + 0.5 / rate * 0.35, strength * 0.7)
		t += 1.0 / rate
	var roar := DSP.noise(d, rng)
	DSP.filter_sweep(roar, &"lowpass", 260.0, 1300.0, 0.7)
	var n: int = roar.size()
	for i: int in n:
		var u: float = float(i) / n
		roar[i] *= (0.15 + 0.85 * u) * (1.0 - 0.5 * smoothstep(0.75, 1.0, u))
	DSP.mix(b, roar, 0.0, 0.5)
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(300.0, 950.0, u), &"saw")
	DSP.filter(whine, &"lowpass", 2200.0)
	for i: int in whine.size():
		var u: float = float(i) / whine.size()
		whine[i] *= smoothstep(0.0, 0.3, u) * (1.0 - 0.6 * smoothstep(0.7, 1.0, u))
	DSP.mix(b, whine, 0.0, 0.14)
	DSP.shape(b, RUSH_FADE, RUSH_FADE)
	DSP.crush(b, 10, 22000.0)
	return b


## The last of it: the rattle at speed (about 17 joints a second) and a roar, both sinking and fading away.
func _rush() -> PackedFloat32Array:
	var rng := _rng(2108)
	var d: float = 2.45
	var b := DSP.buffer(d)
	var t: float = 0.0
	while t < d - 0.2:
		var u: float = t / d
		DSP.mix(b, _clack(rng), t, 0.6 * pow(1.0 - u, 1.6))
		DSP.mix(b, _clack(rng), t + 0.018, 0.4 * pow(1.0 - u, 1.6))
		t += 1.0 / lerpf(17.0, 15.0, u)
	var roar := DSP.noise(d, rng)
	DSP.filter_sweep(roar, &"lowpass", 1400.0, 240.0, 0.7)
	var n: int = roar.size()
	for i: int in n:
		var u: float = float(i) / n
		roar[i] *= pow(1.0 - u, 1.8)
	DSP.mix(b, roar, 0.0, 0.6)
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(950.0, 520.0, u), &"saw")
	DSP.filter(whine, &"lowpass", 1800.0)
	for i: int in whine.size():
		var u: float = float(i) / whine.size()
		whine[i] *= pow(1.0 - u, 2.2)
	DSP.mix(b, whine, 0.0, 0.1)
	DSP.shape(b, RUSH_FADE, 0.4)
	DSP.crush(b, 10, 22000.0)
	return b


## The screech's squeak: two quick rising squeaks, bright and friendly.
func _squeak() -> PackedFloat32Array:
	var rng := _rng(2109)
	var d: float = 0.55
	var b := DSP.buffer(d)
	var one := DSP.fm(0.16, func(u: float) -> float: return DSP.sweep(1750.0, 2700.0, u) * (1.0 + 0.05 * sin(TAU * 9.0 * u)), 2.0,
		func(u: float) -> float: return 0.5 + 0.5 * sin(PI * u))
	DSP.adsr(one, 0.01, 0.06, 0.75, 0.06)
	DSP.mix(b, one, 0.0, 0.55)
	var two := DSP.fm(0.22, func(u: float) -> float: return DSP.sweep(2100.0, 3300.0, u) * (1.0 + 0.04 * sin(TAU * 8.0 * u)), 2.0,
		func(u: float) -> float: return 0.5 + 0.5 * sin(PI * u))
	DSP.adsr(two, 0.01, 0.08, 0.75, 0.09)
	DSP.mix(b, two, 0.2, 0.5)
	var breath := DSP.noise(0.1, rng)
	DSP.filter(breath, &"bandpass", 4200.0, 1.2)
	DSP.envelope(breath, 0.01, 0.03)
	DSP.mix(b, breath, 0.18, 0.1)
	DSP.crush(b, 11, 22000.0)
	return b
