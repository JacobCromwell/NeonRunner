extends "res://tools/asset_gen/sfx_bank.gd"
## Boss sounds, in the same crunchy 16-bit / heavy-metal style as the rest. Every attack has an audio
## warning with a character of its own (CLAUDE.md readability rules):
##   head_flyover      the Floating Head roaring in overhead from behind (its arrival: a huge engine
##                     drone and turbine whine that swell, pass with a Doppler drop and a power chord)
##   searchlight_on    its searchlight powering up: a relay's heavy clunk, then an arc lamp's rising hum
##   searchlight_lock  the light lingering on a spot (a bomb's warning): the gimbal clacks and a two-tone
##                     alarm blares, high then low
##   bomb_whistle      the bomb falling (the same warning, heard): a classic falling whistle from high to
##                     low, swelling as it comes down, ending as it lands
##   bomb_blast        the bomb going off: a crack, a deep boom and debris
##   head_reveal       its face screen powering on (GDD §10's reveal): a picture tube's thunk and whine,
##                     a burst of static, then a distorted loudspeaker blare
## Later steps of the fight (task E1) add the eye lasers, the cyborg drop, the shriek, the propaganda
## voice and the crash.

## A1 and E2 (Hz): the fight's key, under the City's music.
const A1: float = 55.0
const E2: float = 82.41


func sounds() -> Dictionary:
	return {
		"head_flyover": _head_flyover,
		"searchlight_on": _searchlight_on,
		"searchlight_lock": _searchlight_lock,
		"bomb_whistle": _bomb_whistle,
		"bomb_blast": _bomb_blast,
		"head_reveal": _head_reveal,
	}


## The Floating Head flying in overhead from behind (the entrance, FloatingHead): a deep, detuned
## engine drone and a turbine whine that swell as it comes, peak as it passes over (with a power chord
## and a Doppler drop) and roll away ahead, still loud.
func _head_flyover() -> PackedFloat32Array:
	var rng := _rng(401)
	var d: float = 2.4
	var n: int = int(d * RATE)
	var pass_at: float = 0.38
	var doppler := func(u: float) -> float: return lerpf(1.1, 0.86, smoothstep(pass_at - 0.08, pass_at + 0.1, u))
	var near := func(u: float) -> float:
		return lerpf(0.25, 1.0, smoothstep(0.0, pass_at, u)) * lerpf(1.0, 0.5, smoothstep(pass_at, 1.0, u))
	var drone := DSP.buffer(d)
	for hz: float in [A1, A1 * 1.012, A1 * 1.5, A1 * 2.0]:
		DSP.mix(drone, DSP.osc(d, func(u: float) -> float: return hz * float(doppler.call(u)), &"saw"), 0.0, 0.3)
	DSP.filter(drone, &"lowpass", 520.0)
	DSP.drive(drone, 2.5)
	var whine := DSP.osc(d, func(u: float) -> float: return 540.0 * float(doppler.call(u)), &"triangle")
	DSP.mix(whine, DSP.osc(d, func(u: float) -> float: return 810.0 * float(doppler.call(u)), &"triangle"), 0.0, 0.5)
	DSP.filter(whine, &"bandpass", 700.0, 0.9)
	var roar := DSP.noise(d, rng)
	var f := DSP.Biquad.new()
	for i: int in n:
		var u: float = float(i) / n
		if i % 16 == 0:
			f.set_filter(&"bandpass", 350.0 + 1100.0 * exp(-pow((u - pass_at) / 0.12, 2.0)), 0.9)
		roar[i] = f.process(roar[i])
	var b := DSP.buffer(d)
	DSP.mix(b, drone, 0.0, 1.0)
	DSP.mix(b, whine, 0.0, 0.35)
	DSP.mix(b, roar, 0.0, 1.4)
	for i: int in n:
		b[i] *= float(near.call(float(i) / n))
	var chord := DSP.power_chord(1.4, E2, false, rng)
	DSP.envelope(chord, 0.004, 0.5, 0.2)
	DSP.mix(b, chord, pass_at * d - 0.05, 0.55)
	DSP.mix(b, DSP.kick(0.4, 90.0, 38.0, rng), pass_at * d - 0.05, 0.8)
	DSP.shape(b, 0.25, 0.3)
	DSP.crush(b, 9, 20000.0)
	return b


## The searchlight switching on (a run begins): a heavy relay clunk, then an arc lamp's hum rising
## and settling, with a crackle as it strikes.
func _searchlight_on() -> PackedFloat32Array:
	var rng := _rng(402)
	var d: float = 0.95
	var b := DSP.buffer(d)
	DSP.mix(b, DSP.metal_hit(0.35, 170.0, 0.08, rng), 0.0, 1.0)
	DSP.mix(b, DSP.metal_hit(0.25, 610.0, 0.05, rng), 0.0, 0.6)
	DSP.mix(b, DSP.kick(0.2, 120.0, 55.0, rng), 0.0, 0.7)
	var hum := DSP.osc(d - 0.1, func(u: float) -> float: return DSP.sweep(70.0, 120.0, minf(u * 2.0, 1.0)), &"saw")
	DSP.mix(hum, DSP.osc(d - 0.1, func(u: float) -> float: return DSP.sweep(140.0, 240.0, minf(u * 2.0, 1.0)), &"saw"),
		0.0, 0.6)
	DSP.filter(hum, &"bandpass", 900.0, 0.8)
	DSP.drive(hum, 3.0)
	DSP.adsr(hum, 0.15, 0.2, 0.7, 0.15)
	DSP.mix(b, hum, 0.1, 0.8)
	DSP.mix(b, _crackle(0.5, 20, 0.2, 3500.0, rng), 0.08, 0.5)
	DSP.crush(b, 9, 18000.0)
	return b


## The searchlight lingering on a spot, the bomb's warning: the gimbal clacks into place and a
## two-tone alarm blares, high then low. Bright and square: nothing else in the game sounds like it.
func _searchlight_lock() -> PackedFloat32Array:
	var rng := _rng(403)
	var b := DSP.buffer(0.5)
	DSP.mix(b, DSP.metal_hit(0.12, 950.0, 0.03, rng), 0.0, 0.8)
	var servo := DSP.osc(0.08, func(u: float) -> float: return DSP.sweep(500.0, 1400.0, u), &"saw")
	DSP.filter(servo, &"bandpass", 1500.0, 1.2)
	DSP.shape(servo, 0.005, 0.02)
	DSP.mix(b, servo, 0.0, 0.5)
	for k: int in 2:
		var hz: float = 1320.0 if k == 0 else 990.0
		var beep := Inst.pulse(0.14, hz, 0.35)
		DSP.mix(beep, Inst.pulse(0.14, hz * 1.5, 0.5), 0.0, 0.3)
		DSP.shape(beep, 0.004, 0.02)
		DSP.mix(b, beep, 0.08 + k * 0.17, 0.75)
	DSP.drive(b, 1.8)
	DSP.crush(b, 8, 16000.0)
	return b


## A bomb falling (heard with the light's warning): the classic falling whistle, from 2.6 kHz down to
## 650 Hz with a little flutter and breath, swelling as it comes down. It lasts the fall (0.9 s at the
## first phase's pace; FloatingHeadBombing starts it so it ends as the bomb lands).
func _bomb_whistle() -> PackedFloat32Array:
	var rng := _rng(404)
	var d: float = 0.9
	var pitch := func(u: float) -> float: return DSP.sweep(2600.0, 650.0, pow(u, 0.85)) * (1.0 + 0.015 * sin(TAU * 6.0 * u * d))
	var b := DSP.osc(d, pitch)
	DSP.mix(b, DSP.osc(d, func(u: float) -> float: return float(pitch.call(u)) * 2.0, &"triangle"), 0.0, 0.15)
	var breath := DSP.noise(d, rng)
	var f := DSP.Biquad.new()
	var n: int = b.size()
	for i: int in n:
		if i % 16 == 0:
			f.set_filter(&"bandpass", float(pitch.call(float(i) / n)), 6.0)
		breath[i] = f.process(breath[i])
	DSP.mix(b, breath, 0.0, 0.5)
	for i: int in n:
		var u: float = float(i) / n
		b[i] *= 0.3 + 0.7 * u * u
	DSP.shape(b, 0.03, 0.012)
	DSP.crush(b, 10, 22000.0)
	return b


## A bomb going off on the truck roofs: a crack, a deep boom, debris clattering down.
func _bomb_blast() -> PackedFloat32Array:
	var rng := _rng(405)
	var b := _explosion(1.3, 1.0, rng)
	DSP.mix(b, DSP.kick(0.35, 140.0, 42.0, rng), 0.0, 0.8)
	for k: int in 6:
		var at: float = rng.randf_range(0.15, 0.9)
		DSP.mix(b, DSP.metal_hit(0.2, rng.randf_range(900.0, 2600.0), 0.04, rng), at, 0.35 * (1.0 - at))
	DSP.crush(b, 9, 18000.0)
	return b


## The face screen powering on (GDD §10's reveal): a picture tube's thunk and rising whine, a burst of
## static, then a distorted loudspeaker blare, the propaganda about to start.
func _head_reveal() -> PackedFloat32Array:
	var rng := _rng(406)
	var d: float = 2.2
	var b := DSP.buffer(d)
	var thunk := _boom(0.6, 130.0, 45.0, 0.15, rng)
	DSP.mix(b, thunk, 0.0, 0.8)
	var buzz := DSP.osc(0.5, func(_u: float) -> float: return 60.0, &"saw")
	DSP.filter(buzz, &"bandpass", 480.0, 1.0)
	DSP.envelope(buzz, 0.005, 0.18)
	DSP.mix(b, buzz, 0.0, 0.5)
	var whine := DSP.osc(0.9, func(u: float) -> float: return DSP.sweep(1800.0, 6500.0, u))
	DSP.shape(whine, 0.2, 0.2)
	DSP.mix(b, whine, 0.05, 0.08)
	var hiss := DSP.noise(0.8, rng)
	DSP.filter(hiss, &"bandpass", 3200.0, 0.8)
	DSP.shape(hiss, 0.05, 0.3)
	DSP.mix(b, hiss, 0.25, 0.45)
	DSP.mix(b, _crackle(0.8, 30, 0.4, 2800.0, rng), 0.25, 0.5)
	# The blare: a brassy minor chord (A, C, E flat: unresolved) through a megaphone's narrow horn.
	var blare := DSP.buffer(1.05)
	for hz: float in [220.0, 261.6, 311.1]:
		DSP.mix(blare, DSP.osc(1.05, func(u: float) -> float: return hz * (1.0 + 0.004 * sin(TAU * 5.0 * u)), &"saw"), 0.0, 0.3)
	DSP.filter(blare, &"bandpass", 1100.0, 1.4)
	DSP.drive(blare, 6.0)
	DSP.filter(blare, &"lowpass", 3500.0)
	DSP.adsr(blare, 0.03, 0.2, 0.75, 0.2)
	DSP.mix(b, blare, 1.05, 1.0)
	DSP.crush(b, 9, 18000.0)
	return b
