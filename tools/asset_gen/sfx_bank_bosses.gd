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
##   head_laser_charge the eyes glowing up before a laser (GDD §10, proposed: "the eyes glow and whine"):
##                     a rising, throbbing electric whine that throbs faster, ending on a click
##   head_laser_fire   the twin beams firing: a zap down into a harsh, sizzling buzz
##   head_mouth_open   the mouth grinding open for the cyborg drop (its warning): gears ratcheting,
##                     a pneumatic hiss and a heavy clank as the jaw locks open
##   cyborg_drop_land  a dropped cyborg landing on a truck roof: a thud and a metal clatter
##   tower_crack       the laser clipping a marked tower (its fall's warning): a sharp crack, then the
##                     long groan of concrete and steel giving way
##   tower_crash       the tower slamming onto the ship: a huge crash, crumpling metal and falling debris
##   ramp_slam         the tower's broken slab slamming down into a lane (the first stomp window's ramp):
##                     a heavy stone thud and grit
##   pads_light        anti-grav pads lighting up (the third window's way up): a rising electric hum with
##                     a shimmer, in the pads' fifths
##   ceiling_lower     a ceiling section (a ship's underside) lowering in overhead: a descending engine
##                     drone and a hydraulic thump as it settles
##   head_weak_open    its weak points' covers swinging open for a stomp window: hydraulic hiss, the
##                     covers' clank, and a bright rising "target" arpeggio
##   head_shriek       a stomp lands (GDD §10: it shrieks): a distorted, glitching mechanical scream
##   head_shake_free   it shakes free of the tower: grinding, scraping metal, a lurching thud and its
##                     engines roaring up
##   head_voice_1..4   the propaganda voice (GDD §10: "a heavily distorted announcement voice that isn't
##                     meant to be understood"): phrases of made-up syllables with an announcer's rise
##                     and fall, shouted through a blown loudhailer with a ring-modulated edge and the
##                     street's echo; no real language
##   head_voice_cut    the defeat (GDD §10: "the propaganda cuts out mid-shout"): a rising shout that
##                     breaks into a stutter, dives like a stopping tape and dies in static
##   head_power_down   it loses power: its engines spin down, sputtering, and the wind rises as it drops
##   head_crash        it crashes into the street: a huge impact, crumpling hull, its face screen
##                     shattering, debris raining down and a long rumble

## A1 and E2 (Hz): the fight's key, under the City's music.
const A1: float = 55.0
const E2: float = 82.41
## The propaganda voice's vowels: their first two formants (Hz).
const VOWELS: Dictionary = {
	&"a": Vector2(760.0, 1220.0), &"e": Vector2(500.0, 1800.0), &"i": Vector2(330.0, 2250.0),
	&"o": Vector2(520.0, 880.0), &"u": Vector2(340.0, 800.0), &"ae": Vector2(660.0, 1700.0),
}
## The propaganda phrases: syllables of [seconds, pitch from, pitch to (Hz), vowel from, vowel to,
## consonant before it (&"t", &"k", &"s", &"m" or none)]; a syllable with no vowel is a pause. A deep
## announcer's voice, shouting: each phrase climbs to its stressed syllables and falls at its end.
const PHRASES: Array = [
	[[0.14, 150.0, 162.0, &"a", &"e", &"t"], [0.2, 172.0, 186.0, &"e", &"ae", &"k"], [0.16, 164.0, 150.0, &"o", &"a", &""],
		[0.07, 0.0, 0.0, &"", &"", &""], [0.17, 152.0, 146.0, &"i", &"e", &"s"], [0.15, 146.0, 152.0, &"a", &"o", &"t"],
		[0.22, 166.0, 180.0, &"ae", &"a", &"m"], [0.14, 150.0, 140.0, &"u", &"o", &"k"], [0.36, 146.0, 116.0, &"a", &"o", &""]],
	[[0.18, 190.0, 198.0, &"o", &"a", &"k"], [0.15, 176.0, 170.0, &"e", &"i", &"t"], [0.24, 184.0, 196.0, &"a", &"ae", &"s"],
		[0.1, 0.0, 0.0, &"", &"", &""], [0.15, 160.0, 154.0, &"u", &"e", &"m"], [0.16, 158.0, 150.0, &"i", &"a", &"t"],
		[0.42, 162.0, 120.0, &"o", &"u", &"k"]],
	[[0.13, 140.0, 146.0, &"e", &"a", &"s"], [0.13, 150.0, 156.0, &"a", &"o", &"t"], [0.19, 170.0, 182.0, &"i", &"e", &"k"],
		[0.14, 160.0, 150.0, &"o", &"a", &""], [0.08, 0.0, 0.0, &"", &"", &""], [0.13, 148.0, 152.0, &"ae", &"e", &"m"],
		[0.13, 150.0, 146.0, &"u", &"o", &"t"], [0.2, 174.0, 188.0, &"a", &"ae", &"k"], [0.14, 160.0, 152.0, &"e", &"i", &"s"],
		[0.38, 150.0, 118.0, &"a", &"o", &""]],
	[[0.2, 204.0, 216.0, &"a", &"o", &"k"], [0.16, 196.0, 186.0, &"i", &"e", &"t"], [0.12, 0.0, 0.0, &"", &"", &""],
		[0.2, 210.0, 222.0, &"ae", &"a", &"s"], [0.44, 214.0, 150.0, &"o", &"u", &"m"]],
]


func sounds() -> Dictionary:
	return {
		"head_flyover": _head_flyover,
		"searchlight_on": _searchlight_on,
		"searchlight_lock": _searchlight_lock,
		"bomb_whistle": _bomb_whistle,
		"bomb_blast": _bomb_blast,
		"head_reveal": _head_reveal,
		"head_laser_charge": _head_laser_charge,
		"head_laser_fire": _head_laser_fire,
		"head_mouth_open": _head_mouth_open,
		"cyborg_drop_land": _cyborg_drop_land,
		"tower_crack": _tower_crack,
		"tower_crash": _tower_crash,
		"ramp_slam": _ramp_slam,
		"pads_light": _pads_light,
		"ceiling_lower": _ceiling_lower,
		"head_weak_open": _head_weak_open,
		"head_shriek": _head_shriek,
		"head_shake_free": _head_shake_free,
		"head_voice_1": _head_voice.bind(0),
		"head_voice_2": _head_voice.bind(1),
		"head_voice_3": _head_voice.bind(2),
		"head_voice_4": _head_voice.bind(3),
		"head_voice_cut": _head_voice_cut,
		"head_power_down": _head_power_down,
		"head_crash": _head_crash,
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


## The eyes charging a laser (its warning, laser_charge_seconds at the first phase's pace): two detuned
## saws rising from a growl to a scream, throbbing faster and faster like a capacitor filling, over a
## buzzing floor, cut off by a click as it's ready. The same every time.
func _head_laser_charge() -> PackedFloat32Array:
	var rng := _rng(407)
	var d: float = 1.0
	var n: int = int(d * RATE)
	var rise := func(u: float) -> float: return DSP.sweep(260.0, 1500.0, pow(u, 1.4))
	var b := DSP.osc(d, rise, &"saw")
	DSP.mix(b, DSP.osc(d, func(u: float) -> float: return float(rise.call(u)) * 1.007, &"saw"), 0.0, 0.8)
	DSP.mix(b, DSP.osc(d, func(u: float) -> float: return float(rise.call(u)) * 2.0, &"square"), 0.0, 0.18)
	DSP.filter(b, &"bandpass", 1400.0, 0.7)
	DSP.drive(b, 2.2)
	# The throb: a tremolo speeding up from 7 to 26 beats a second.
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		phase += TAU * lerpf(7.0, 26.0, u) / RATE
		b[i] *= (0.55 + 0.45 * sin(phase)) * (0.35 + 0.65 * u)
	var floor_buzz := DSP.osc(d, func(_u: float) -> float: return A1 * 2.0, &"saw")
	DSP.filter(floor_buzz, &"lowpass", 400.0)
	DSP.drive(floor_buzz, 3.0)
	DSP.shape(floor_buzz, 0.1, 0.05)
	DSP.mix(b, floor_buzz, 0.0, 0.35)
	DSP.mix(b, DSP.metal_hit(0.06, 2400.0, 0.02, rng), d - 0.07, 0.6)
	DSP.shape(b, 0.02, 0.01)
	DSP.crush(b, 9, 20000.0)
	return b


## The twin beams firing: a zap diving from a shriek into a harsh buzz, with a hot sizzle on top.
func _head_laser_fire() -> PackedFloat32Array:
	var rng := _rng(408)
	var d: float = 1.0
	var b := DSP.buffer(d)
	var zap := DSP.osc(0.16, func(u: float) -> float: return DSP.sweep(3200.0, 180.0, pow(u, 0.5)), &"square")
	DSP.shape(zap, 0.002, 0.03)
	DSP.mix(b, zap, 0.0, 0.7)
	var buzz := DSP.osc(d, func(u: float) -> float: return 110.0 * (1.0 + 0.02 * sin(TAU * 11.0 * u)), &"saw")
	DSP.mix(buzz, DSP.osc(d, func(_u: float) -> float: return 165.2, &"square"), 0.0, 0.5)
	DSP.filter(buzz, &"lowpass", 2200.0)
	DSP.drive(buzz, 4.0)
	DSP.adsr(buzz, 0.02, 0.2, 0.7, 0.3)
	DSP.mix(b, buzz, 0.04, 0.8)
	var sizzle := DSP.noise(d, rng)
	DSP.filter(sizzle, &"bandpass", 4200.0, 0.9)
	DSP.adsr(sizzle, 0.01, 0.3, 0.55, 0.3)
	DSP.mix(b, sizzle, 0.0, 0.5)
	DSP.mix(b, _crackle(0.8, 24, 0.5, 5200.0, rng), 0.05, 0.35)
	DSP.crush(b, 8, 18000.0)
	return b


## The mouth opening for the cyborg drop (its warning): gears ratcheting under a grinding drone, a
## pneumatic hiss, and a heavy clank as the jaw locks open.
func _head_mouth_open() -> PackedFloat32Array:
	var rng := _rng(409)
	var d: float = 0.85
	var b := DSP.buffer(d)
	var grind := DSP.noise(0.7, rng)
	DSP.filter(grind, &"lowpass", 700.0)
	DSP.drive(grind, 3.0)
	DSP.mix(grind, DSP.osc(0.7, func(u: float) -> float: return DSP.sweep(62.0, 48.0, u), &"saw"), 0.0, 0.5)
	DSP.adsr(grind, 0.04, 0.1, 0.8, 0.12)
	DSP.mix(b, grind, 0.0, 0.8)
	for k: int in 9:
		DSP.mix(b, DSP.metal_hit(0.05, 700.0 + 60.0 * (k % 3), 0.015, rng), 0.03 + k * 0.065, 0.45)
	var hiss := DSP.noise(0.45, rng)
	DSP.filter(hiss, &"highpass", 2800.0)
	DSP.shape(hiss, 0.02, 0.3)
	DSP.mix(b, hiss, 0.3, 0.4)
	DSP.mix(b, DSP.metal_hit(0.25, 180.0, 0.07, rng), 0.62, 1.0)
	DSP.mix(b, DSP.kick(0.2, 110.0, 45.0, rng), 0.62, 0.7)
	DSP.crush(b, 9, 18000.0)
	return b


## A dropped cyborg landing on a truck roof: a heavy thud under a ringing clank of its metal feet on the
## roof (loud in the middle frequencies, so a phone's speaker carries it), a puff of grit.
func _cyborg_drop_land() -> PackedFloat32Array:
	var rng := _rng(410)
	var b := DSP.buffer(0.4)
	DSP.mix(b, DSP.kick(0.3, 150.0, 50.0, rng), 0.0, 0.7)
	DSP.mix(b, DSP.metal_hit(0.22, 620.0, 0.06, rng), 0.0, 1.0)
	DSP.mix(b, DSP.metal_hit(0.16, 1300.0, 0.04, rng), 0.012, 0.7)
	DSP.mix(b, DSP.metal_hit(0.1, 2100.0, 0.03, rng), 0.03, 0.4)
	var grit := DSP.noise(0.25, rng)
	DSP.filter(grit, &"bandpass", 2500.0, 0.8)
	DSP.envelope(grit, 0.003, 0.07)
	DSP.mix(b, grit, 0.0, 0.55)
	DSP.crush(b, 9, 18000.0)
	return b


## The laser clipping a marked tower (the warning that it will fall): a sharp crack of concrete, then a
## long groan of steel and stone giving way, sagging lower, with a steel beam creaking over it (the
## crack and the creak carry on a phone's speaker).
func _tower_crack() -> PackedFloat32Array:
	var rng := _rng(411)
	var d: float = 1.3
	var b := DSP.buffer(d)
	var crack := DSP.noise(0.2, rng)
	DSP.filter(crack, &"highpass", 1200.0)
	DSP.envelope(crack, 0.001, 0.04)
	DSP.mix(b, crack, 0.0, 1.0)
	var snap := DSP.noise(0.25, rng)
	DSP.filter(snap, &"bandpass", 2000.0, 1.0)
	DSP.envelope(snap, 0.001, 0.09)
	DSP.mix(b, snap, 0.0, 0.9)
	DSP.mix(b, DSP.kick(0.3, 160.0, 60.0, rng), 0.0, 0.55)
	DSP.mix(b, _crackle(0.5, 30, 0.15, 3000.0, rng), 0.02, 0.6)
	var groan := DSP.osc(1.1, func(u: float) -> float: return DSP.sweep(95.0, 58.0, u) * (1.0 + 0.03 * sin(TAU * 4.0 * u)), &"saw")
	DSP.mix(groan, DSP.osc(1.1, func(u: float) -> float: return DSP.sweep(143.0, 84.0, u), &"saw"), 0.0, 0.6)
	DSP.filter(groan, &"lowpass", 1100.0)
	DSP.drive(groan, 3.0)
	DSP.adsr(groan, 0.15, 0.2, 0.8, 0.3)
	DSP.mix(b, groan, 0.15, 0.7)
	var creak := DSP.osc(1.0, func(u: float) -> float: return DSP.sweep(820.0, 520.0, u) * (1.0 + 0.02 * sin(TAU * 9.0 * u)), &"saw")
	DSP.filter(creak, &"bandpass", 950.0, 1.2)
	DSP.adsr(creak, 0.2, 0.2, 0.7, 0.3)
	DSP.mix(b, creak, 0.2, 0.7)
	for k: int in 4:
		DSP.mix(b, DSP.metal_hit(0.2, rng.randf_range(220.0, 520.0), 0.06, rng), rng.randf_range(0.3, 1.1), 0.3)
	DSP.crush(b, 9, 18000.0)
	return b


## The tower slamming onto the ship: a huge crash, crumpling metal and a long rattle of debris.
func _tower_crash() -> PackedFloat32Array:
	var rng := _rng(412)
	var b := _explosion(1.8, 1.4, rng)
	DSP.mix(b, DSP.kick(0.5, 110.0, 32.0, rng), 0.0, 1.0)
	DSP.mix(b, DSP.crash(1.2, rng), 0.0, 0.5)
	var crumple := DSP.noise(0.9, rng)
	DSP.filter(crumple, &"bandpass", 900.0, 0.7)
	DSP.drive(crumple, 4.0)
	DSP.envelope(crumple, 0.01, 0.3)
	DSP.mix(b, crumple, 0.05, 0.6)
	for k: int in 10:
		var at: float = rng.randf_range(0.2, 1.5)
		DSP.mix(b, DSP.metal_hit(0.2, rng.randf_range(300.0, 2200.0), 0.05, rng), at, 0.4 * (1.0 - at / 1.8))
	DSP.crush(b, 9, 18000.0)
	return b


## The tower's broken slab slamming down into a lane (the first stomp window's ramp): a heavy stone
## thud, a crunch of concrete and grit pattering down (the crunch carries on a phone's speaker).
func _ramp_slam() -> PackedFloat32Array:
	var rng := _rng(413)
	var b := DSP.buffer(0.9)
	DSP.mix(b, _boom(0.8, 95.0, 36.0, 0.18, rng), 0.0, 1.0)
	DSP.mix(b, DSP.kick(0.3, 130.0, 45.0, rng), 0.0, 0.8)
	var crunch := DSP.noise(0.35, rng)
	DSP.filter(crunch, &"bandpass", 1200.0, 0.8)
	DSP.drive(crunch, 3.0)
	DSP.envelope(crunch, 0.002, 0.09)
	DSP.mix(b, crunch, 0.0, 2.0)
	DSP.mix(b, DSP.metal_hit(0.2, 760.0, 0.05, rng), 0.0, 0.6)
	DSP.mix(b, _crackle(0.8, 30, 0.3, 2600.0, rng), 0.03, 1.1)
	DSP.crush(b, 9, 18000.0)
	return b


## Anti-grav pads lighting up in every lane (the third stomp window's way up): a rising electric hum in
## fifths, a soft zap as each catches, and a shimmer.
func _pads_light() -> PackedFloat32Array:
	var rng := _rng(414)
	var d: float = 0.9
	var b := DSP.buffer(d)
	for hz: float in [220.0, 330.0]:
		var hum := DSP.osc(d, func(u: float) -> float: return DSP.sweep(hz * 0.5, hz, minf(u * 2.5, 1.0)), &"square")
		DSP.filter(hum, &"bandpass", hz * 2.0, 0.9)
		DSP.adsr(hum, 0.1, 0.2, 0.6, 0.25)
		DSP.mix(b, hum, 0.0, 0.5)
	for k: int in 3:
		var zap := DSP.osc(0.06, func(u: float) -> float: return DSP.sweep(2400.0, 900.0, u), &"square")
		DSP.shape(zap, 0.002, 0.02)
		DSP.mix(b, zap, 0.05 + k * 0.09, 0.35)
	DSP.mix(b, _sparkle(0.6, rng), 0.25, 0.3)
	DSP.crush(b, 9, 18000.0)
	return b


## A ceiling section lowering in overhead (a ship's underside settling over the street): an engine
## drone gliding down, a whoosh, and a hydraulic thump and hiss as it locks in place.
func _ceiling_lower() -> PackedFloat32Array:
	var rng := _rng(415)
	var d: float = 1.1
	var b := DSP.buffer(d)
	var drone := DSP.osc(d, func(u: float) -> float: return DSP.sweep(140.0, 70.0, u), &"saw")
	DSP.mix(drone, DSP.osc(d, func(u: float) -> float: return DSP.sweep(141.5, 70.6, u), &"saw"), 0.0, 0.8)
	DSP.filter(drone, &"lowpass", 700.0)
	DSP.drive(drone, 2.0)
	DSP.adsr(drone, 0.1, 0.3, 0.7, 0.3)
	DSP.mix(b, drone, 0.0, 0.7)
	DSP.mix(b, _whoosh(0.7, 2200.0, 500.0, 1.2, rng), 0.0, 0.5)
	DSP.mix(b, DSP.kick(0.3, 100.0, 40.0, rng), 0.62, 0.8)
	DSP.mix(b, DSP.metal_hit(0.2, 240.0, 0.06, rng), 0.62, 0.6)
	var hiss := DSP.noise(0.35, rng)
	DSP.filter(hiss, &"highpass", 2600.0)
	DSP.shape(hiss, 0.01, 0.25)
	DSP.mix(b, hiss, 0.66, 0.35)
	DSP.crush(b, 9, 18000.0)
	return b


## Its weak points' covers swinging open (a stomp window opens): a hydraulic hiss, the covers' heavy
## clank, and a bright rising "target" arpeggio on a pulse wave (A, C, E, A: the fight's key), so the
## window is heard as well as seen.
func _head_weak_open() -> PackedFloat32Array:
	var rng := _rng(416)
	var d: float = 0.9
	var b := DSP.buffer(d)
	var hiss := DSP.noise(0.4, rng)
	DSP.filter(hiss, &"highpass", 2200.0)
	DSP.shape(hiss, 0.01, 0.25)
	DSP.mix(b, hiss, 0.0, 0.45)
	DSP.mix(b, DSP.metal_hit(0.25, 330.0, 0.07, rng), 0.12, 0.9)
	DSP.mix(b, DSP.kick(0.2, 120.0, 50.0, rng), 0.12, 0.5)
	var notes: Array[float] = [440.0, 523.3, 659.3, 880.0]
	for k: int in notes.size():
		var hz: float = notes[k]
		var beep := Inst.pulse(0.12, hz, 0.25)
		DSP.mix(beep, Inst.pulse(0.12, hz * 2.0, 0.5), 0.0, 0.25)
		DSP.shape(beep, 0.003, 0.03)
		DSP.mix(b, beep, 0.3 + k * 0.09, 0.55 + 0.1 * k)
	DSP.crush(b, 8, 16000.0)
	return b


## A stomp lands (GDD §10: it shrieks): a distorted mechanical scream through its loudspeakers, pitch
## jumping and glitching, over a crackle of static.
func _head_shriek() -> PackedFloat32Array:
	var rng := _rng(417)
	var d: float = 1.3
	var scream := _voice(d, func(u: float) -> float:
		return DSP.sweep(620.0, 260.0, pow(u, 0.7)) * (1.0 + 0.25 * float(int(u * 11.0) % 2)),
		Vector2(900.0, 620.0), Vector2(2600.0, 1700.0), 9.0, 1.2, rng)
	DSP.drive(scream, 6.0)
	DSP.filter(scream, &"bandpass", 1500.0, 0.6)
	DSP.adsr(scream, 0.02, 0.3, 0.75, 0.35)
	var b := DSP.buffer(d)
	DSP.mix(b, scream, 0.0, 1.0)
	var buzz := DSP.osc(d, func(u: float) -> float: return DSP.sweep(160.0, 70.0, u), &"saw")
	DSP.filter(buzz, &"lowpass", 900.0)
	DSP.drive(buzz, 3.0)
	DSP.adsr(buzz, 0.02, 0.3, 0.6, 0.35)
	DSP.mix(b, buzz, 0.0, 0.45)
	DSP.mix(b, _crackle(d, 40, 0.6, 3000.0, rng), 0.0, 0.5)
	DSP.crush_sweep(b, 9.0, 5.0, 18000.0, 6000.0)
	return b


## It shakes free of the tower: a long grinding scrape of metal and stone, a lurching thud, and its
## engines roaring up as it pulls away.
func _head_shake_free() -> PackedFloat32Array:
	var rng := _rng(418)
	var d: float = 1.6
	var b := DSP.buffer(d)
	var scrape := DSP.noise(0.9, rng)
	DSP.filter_sweep(scrape, &"bandpass", 500.0, 1400.0, 1.4)
	DSP.drive(scrape, 4.0)
	DSP.adsr(scrape, 0.03, 0.2, 0.7, 0.2)
	DSP.mix(b, scrape, 0.0, 0.7)
	for k: int in 5:
		DSP.mix(b, DSP.metal_hit(0.15, rng.randf_range(400.0, 1200.0), 0.04, rng), 0.05 + k * 0.14, 0.4)
	DSP.mix(b, _boom(0.7, 110.0, 40.0, 0.2, rng), 0.25, 0.9)
	var engines := DSP.buffer(1.2)
	for hz: float in [A1, A1 * 1.01, A1 * 1.5]:
		DSP.mix(engines, DSP.osc(1.2, func(u: float) -> float: return hz * lerpf(0.8, 1.25, u), &"saw"), 0.0, 0.35)
	DSP.filter(engines, &"lowpass", 600.0)
	DSP.drive(engines, 2.5)
	DSP.adsr(engines, 0.3, 0.3, 0.8, 0.3)
	DSP.mix(b, engines, 0.4, 0.9)
	DSP.crush(b, 9, 18000.0)
	return b


# --- The propaganda voice and the defeat (task E1d) --------------------------------------------

## One of the propaganda phrases (PHRASES[index]) through the loudhailer: made-up syllables, so it's
## heard as a shouted announcement and never understood.
func _head_voice(index: int) -> PackedFloat32Array:
	var rng := _rng(430 + index)
	return _loudhailer(_syllables(PHRASES[index], 0.5, rng), rng)


## The syllables of a phrase, one after another, with `tail` seconds of room after them (for echoes).
func _syllables(parts: Array, tail: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var total: float = tail
	for p: Array in parts:
		total += float(p[0])
	var b := DSP.buffer(total)
	var at: float = 0.0
	for p: Array in parts:
		var d: float = float(p[0])
		if StringName(p[3]) != &"":
			DSP.mix(b, _syllable(d, float(p[1]), float(p[2]), VOWELS[p[3]], VOWELS[p[4]], StringName(p[5]), rng), at)
		at += d
	return b


## A syllable: a consonant's burst or hiss, then the voiced vowel gliding between two vowels' formants
## as its pitch moves from `hz_from` to `hz_to`, with a square wave an octave down for a giant's chest.
func _syllable(d: float, hz_from: float, hz_to: float, vowel_from: Vector2, vowel_to: Vector2, consonant: StringName,
		rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(d)
	var onset: float = 0.0
	match consonant:
		&"t", &"k":
			var burst := DSP.noise(0.03, rng)
			DSP.filter(burst, &"bandpass", 2600.0 if consonant == &"t" else 1500.0, 1.2)
			DSP.envelope(burst, 0.001, 0.008)
			DSP.mix(b, burst, 0.0, 1.4)
			onset = 0.018
		&"s":
			var hiss := DSP.noise(0.07, rng)
			DSP.filter(hiss, &"highpass", 3600.0)
			DSP.shape(hiss, 0.01, 0.02)
			DSP.mix(b, hiss, 0.0, 0.7)
			onset = 0.05
		&"m":
			var hum := DSP.osc(0.05, func(_u: float) -> float: return hz_from)
			DSP.shape(hum, 0.005, 0.01)
			DSP.mix(b, hum, 0.0, 0.5)
			onset = 0.035
	var v: float = maxf(d - onset, 0.03)
	var pitch := func(u: float) -> float: return lerpf(hz_from, hz_to, u)
	var voiced := _voice(v, pitch, Vector2(vowel_from.x, vowel_to.x), Vector2(vowel_from.y, vowel_to.y), 5.5, 0.2, rng)
	var chest := DSP.osc(v, func(u: float) -> float: return float(pitch.call(u)) * 0.5, &"square")
	DSP.filter(chest, &"lowpass", 320.0)
	DSP.mix(voiced, chest, 0.0, 0.3)
	DSP.adsr(voiced, 0.015, 0.08, 0.8, minf(0.05, v * 0.3))
	DSP.mix(b, voiced, onset)
	return b


## The loudhailer the face shouts through: a ring-modulated cybernetic edge, a narrow, blown-out horn
## (band-limited, overdriven, bit-crushed) and the street's echoes off the buildings.
func _loudhailer(dry: PackedFloat32Array, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = dry.size()
	for i: int in n:
		dry[i] *= 0.62 + 0.38 * sin(TAU * 61.0 * float(i) / RATE)
	DSP.filter(dry, &"highpass", 300.0)
	DSP.filter(dry, &"peaking", 1400.0, 0.8, 9.0)
	DSP.drive(dry, 6.0)
	DSP.filter(dry, &"lowpass", 3600.0)
	DSP.crush(dry, 8, 11025.0)
	# A little hiss on the line.
	var line := DSP.noise(DSP.seconds_of(dry), rng)
	DSP.filter(line, &"bandpass", 2800.0, 0.7)
	DSP.mix(dry, line, 0.0, 0.025)
	var wet := dry.duplicate()
	DSP.filter(wet, &"lowpass", 2200.0)
	var out := dry.duplicate()
	DSP.mix(out, wet, 0.14, 0.42)
	DSP.mix(out, wet, 0.33, 0.22)
	return out


## GDD §10's defeat: "the propaganda cuts out mid-shout". A shout climbing to a held vowel breaks up:
## a sliver of it stutters, the rest dives in pitch like a tape stopping, a last burst of static, and
## silence (but for the street's echo).
func _head_voice_cut() -> PackedFloat32Array:
	var rng := _rng(440)
	var shout := _syllables([[0.15, 172.0, 192.0, &"a", &"e", &"t"], [0.17, 196.0, 216.0, &"e", &"a", &"k"],
		[0.55, 222.0, 238.0, &"a", &"ae", &""]], 0.0, rng)
	var cut_at: float = 0.56
	var grain_len: int = int(0.045 * RATE)
	var cut: int = int(cut_at * RATE)
	var b := DSP.buffer(1.5)
	for i: int in cut:
		b[i] = shout[i]
	# The stutter: the last 45 ms repeated, each time more broken.
	var at: int = cut
	for k: int in 5:
		var grain := shout.slice(cut - grain_len, cut)
		DSP.crush(grain, 8.0 - k, 11025.0 / (k + 1))
		DSP.shape(grain, 0.002, 0.004)
		for i: int in grain.size():
			if at + i < b.size():
				b[at + i] = grain[i] * (1.0 - 0.12 * k)
		at += grain.size()
	# The tape stop: the rest of the shout read ever slower, its pitch diving to nothing.
	var stop: int = int(0.34 * RATE)
	var pos: float = float(cut)
	for i: int in stop:
		var speed: float = pow(1.0 - float(i) / stop, 1.6)
		pos += speed
		var j: int = mini(int(pos), shout.size() - 1)
		if at + i < b.size():
			b[at + i] = shout[j] * (1.0 - 0.5 * float(i) / stop)
	at += stop
	var static_burst := DSP.noise(0.14, rng)
	DSP.filter(static_burst, &"bandpass", 3000.0, 0.8)
	DSP.crush(static_burst, 5, 6000.0)
	DSP.shape(static_burst, 0.002, 0.03)
	DSP.mix(b, static_burst, float(at) / RATE, 0.8)
	return _loudhailer(b, rng)


## It loses power (the defeat): its engines spin down, the power cutting in and out as they die, a
## falling whine, electrical sputters, and the wind rising as it drops toward the street.
func _head_power_down() -> PackedFloat32Array:
	var rng := _rng(441)
	var d: float = 1.9
	var spin := func(u: float) -> float: return lerpf(1.0, 0.22, 1.0 - pow(1.0 - u, 2.0))
	var drone := DSP.buffer(d)
	for hz: float in [A1, A1 * 1.013, A1 * 1.5, A1 * 2.0]:
		DSP.mix(drone, DSP.osc(d, func(u: float) -> float: return hz * float(spin.call(u)), &"saw"), 0.0, 0.3)
	DSP.filter_sweep(drone, &"lowpass", 1400.0, 180.0, 0.9)
	DSP.drive(drone, 3.0)
	# The power cutting in and out as it dies: short gaps in the first half, more of them as it goes.
	var n: int = drone.size()
	var i: int = 0
	var gain: float = 1.0
	while i < n:
		var u: float = float(i) / n
		var seg: int = int(rng.randf_range(0.03, 0.09) * RATE)
		var on: bool = u > 0.55 or rng.randf() > 0.25 + 0.5 * u
		for j: int in mini(seg, n - i):
			gain = move_toward(gain, 1.0 if on else 0.15, 1.0 / 200.0)
			drone[i + j] *= gain
		i += seg
	var b := DSP.buffer(d)
	DSP.mix(b, drone, 0.0, 1.0)
	var whine := DSP.osc(d, func(u: float) -> float: return 1150.0 * float(spin.call(u)), &"triangle")
	DSP.filter(whine, &"bandpass", 900.0, 0.8)
	DSP.adsr(whine, 0.01, 0.6, 0.5, 0.4)
	DSP.mix(b, whine, 0.0, 0.3)
	DSP.mix(b, _crackle(d * 0.6, 26, 0.5, 3200.0, rng), 0.0, 0.6)
	DSP.mix(b, _whoosh(1.1, 350.0, 1700.0, 0.8, rng), 0.75, 0.55)
	DSP.adsr(b, 0.01, 0.8, 0.7, 0.3)
	DSP.crush(b, 9, 18000.0)
	return b


## It crashes into the street (the defeat): a huge impact and a deep boom, the hull crumpling, its
## face screen shattering, debris raining down on the trucks, and a long rumble dying away.
func _head_crash() -> PackedFloat32Array:
	var rng := _rng(442)
	var d: float = 2.4
	var b := DSP.buffer(d)
	DSP.mix(b, _explosion(2.3, 1.8, rng), 0.0, 1.0)
	DSP.mix(b, DSP.kick(0.7, 90.0, 26.0, rng), 0.0, 1.0)
	DSP.mix(b, DSP.crash(1.6, rng), 0.02, 0.45)
	var crumple := DSP.noise(1.3, rng)
	DSP.filter_sweep(crumple, &"bandpass", 1100.0, 420.0, 0.8)
	DSP.drive(crumple, 5.0)
	DSP.adsr(crumple, 0.01, 0.4, 0.4, 0.3)
	DSP.mix(b, crumple, 0.03, 0.6)
	# The face screen shattering: bright pings and a glassy hiss.
	for k: int in 36:
		var hz: float = rng.randf_range(3200.0, 8800.0)
		var ping := DSP.osc(0.05, func(_u: float) -> float: return hz)
		DSP.envelope(ping, 0.001, 0.012)
		var at: float = 0.04 + pow(rng.randf(), 1.8) * 0.7
		DSP.mix(b, ping, at, rng.randf_range(0.2, 0.55) * (1.0 - at))
	var glass := DSP.noise(0.5, rng)
	DSP.filter(glass, &"highpass", 4200.0)
	DSP.envelope(glass, 0.002, 0.1)
	DSP.mix(b, glass, 0.03, 0.5)
	for k: int in 18:
		var at: float = rng.randf_range(0.2, 2.0)
		DSP.mix(b, DSP.metal_hit(0.22, rng.randf_range(260.0, 2000.0), 0.05, rng), at, 0.45 * (1.0 - at / d))
	var rumble := DSP.noise(d, rng)
	DSP.filter(rumble, &"lowpass", 150.0)
	DSP.drive(rumble, 2.0)
	DSP.envelope(rumble, 0.05, 0.8, 0.4)
	DSP.mix(b, rumble, 0.0, 0.9)
	DSP.crush(b, 9, 18000.0)
	return b
