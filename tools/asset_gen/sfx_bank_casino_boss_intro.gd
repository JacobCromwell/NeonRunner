extends "res://tools/asset_gen/sfx_bank_marketplace_intro.gd"
## The Casino boss intro's own sounds (CasinoBossIntro): a lively steampunk casino (brass, iron, warm light), the
## roulette wheel spinning and landing to cheers, the Chairman slipping through the golden door, the wall beside it
## trembling and collapsing, and The House standing in the hole. In the same crunchy 16-bit style as the rest; none of
## them is a warning; like every sound effect, each is under 2.5 s. The guard's voice is the Marketplace cyborg's
## (the mumble technique, no real words): this bank inherits that bank's _mumble.
##   roulette_spin   the ball rolling round the wheel's track: a whirr and rattle, a click that slows, the wheel's hum (2.4 s)
##   roulette_drop   the ball dropping off the track and clattering over the pocket separators, settling (1.2 s)
##   crowd_cheer     a small crowd at the table cheering a win: "hey!"/"yeah!", a whoop, applause tailing off (2.2 s)
##   casino_bustle   the murmur of a busy floor, for repeating under the scene: chatter, chip clacks, a far slot bell,
##                   a glass clink; it fades in and out over 0.3 s (so overlapped repeats add up to a flat level) (2.4 s)
##   golden_door     a heavy ornate door swinging shut: a creak, a deep thud, the latch and a brassy ring (1.6 s)
##   wall_rumble     a deep tremor growing in the wall: low rumble, grinding stone, debris pattering, creaks (2.4 s)
##   wall_collapse   the wall bursting and collapsing: a boom, masonry crashing and tumbling, a long settling tail (2.4 s)
##   guard_halt      a cyborg guard's gruff "hey, stop!" (0.9 s)

## The bustle fades in and out over this long, so a repeat that overlaps by it keeps the level flat.
const BUSTLE_FADE: float = 0.3
const C5: float = 523.25
const E5: float = 659.26
const G5: float = 783.99


func sounds() -> Dictionary:
	return {
		"roulette_spin": _roulette_spin,
		"roulette_drop": _roulette_drop,
		"crowd_cheer": _crowd_cheer,
		"casino_bustle": _casino_bustle,
		"golden_door": _golden_door,
		"wall_rumble": _wall_rumble,
		"wall_collapse": _wall_collapse,
		"guard_halt": _guard_halt,
	}


## A small hard tick (an ivory ball on a hard edge, a chip on a chip): a burst of band-passed noise on a short ping at
## `hz`, dying with time constant `tau`.
func _tik(hz: float, tau: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var seconds: float = tau * 8.0 + 0.005
	var b := DSP.noise(seconds, rng)
	DSP.filter(b, &"bandpass", hz, 2.0)
	var ping := DSP.osc(seconds, func(_u: float) -> float: return hz * 0.92)
	DSP.mix(b, ping, 0.0, 0.5)
	DSP.envelope(b, 0.0003, tau, 0.002)
	return b


## A dull wooden knock at `hz` (a ball on the wheel's wood): a sine that sags a little, dying with time constant `tau`.
func _knock(hz: float, tau: float) -> PackedFloat32Array:
	var seconds: float = tau * 8.0 + 0.005
	var b := DSP.osc(seconds, func(u: float) -> float: return hz * (1.0 - 0.25 * u))
	DSP.envelope(b, 0.0004, tau, 0.002)
	return b


## One crowd voice shout of `seconds`: a voice at `p0` to `p1` Hz through formants gliding `f1` and `f2`.
func _shout(seconds: float, p0: float, p1: float, f1: Vector2, f2: Vector2, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var v := _voice(seconds, func(u: float) -> float: return lerpf(p0, p1, u), f1, f2, 6.0, 0.3, rng)
	DSP.envelope(v, 0.012, seconds * 0.5, 0.05)
	return v


## The ball circling the wheel: a whirr that rattles round and slows, a click each time it passes a separator that
## spaces out, and the wheel's soft woody hum under it all.
func _roulette_spin() -> PackedFloat32Array:
	var rng := _rng(5101)
	var d: float = 2.4
	var b := DSP.buffer(d)
	# The wheel: a low hum and a soft rumble of wood, sagging a little as it slows.
	var hum := DSP.osc(d, func(u: float) -> float: return 96.0 - 12.0 * u, &"triangle")
	DSP.filter(hum, &"lowpass", 420.0)
	DSP.mix(b, hum, 0.0, 0.25)
	var wood := DSP.noise(d, rng)
	DSP.filter_sweep(wood, &"bandpass", 260.0, 170.0, 1.2)
	DSP.mix(b, wood, 0.0, 1.5)
	# The ball: noise whose pitch falls, swelling once per lap, the laps slowing down.
	var whirr := DSP.noise(d, rng)
	DSP.filter_sweep(whirr, &"bandpass", 2900.0, 1500.0, 1.5)
	var phase: float = 0.0
	for i: int in whirr.size():
		var u: float = float(i) / whirr.size()
		phase = fmod(phase + lerpf(11.0, 3.2, pow(u, 1.2)) / RATE, 1.0)
		var lap: float = 0.5 + 0.5 * sin(phase * TAU)
		whirr[i] *= (0.35 + 0.65 * lap * lap) * (1.0 - 0.35 * u)
	DSP.mix(b, whirr, 0.0, 1.5)
	# Rattle: little grains of the ball skipping, fewer as it slows.
	for k: int in 90:
		var at: float = d * (1.0 - sqrt(rng.randf())) * 0.97
		var grain := DSP.noise(0.005, rng)
		DSP.filter(grain, &"bandpass", rng.randf_range(2200.0, 5200.0), 2.0)
		DSP.envelope(grain, 0.0003, 0.0015, 0.001)
		DSP.mix(b, grain, at, rng.randf_range(0.3, 0.8) * 2.2)
	# The clicks: one per separator passed, the gap growing as the ball slows.
	var t: float = 0.04
	var k: int = 0
	while t < d - 0.12:
		var u: float = t / d
		DSP.mix(b, _tik(3300.0 + 250.0 * float(k % 3), 0.0025, rng), t, rng.randf_range(0.75, 1.0) * 1.8)
		DSP.mix(b, _knock(1250.0, 0.012), t, 0.3)
		t += lerpf(0.055, 0.3, pow(u, 1.5))
		k += 1
	DSP.shape(b, 0.05, 0.14)
	return b


## The ball leaving the track: it drops and clatters over the pocket separators in quick, diminishing bounces and
## settles in a pocket with a last firm click.
func _roulette_drop() -> PackedFloat32Array:
	var rng := _rng(5102)
	var d: float = 1.2
	var b := DSP.buffer(d)
	# The wheel still turning under it.
	var wood := DSP.noise(d, rng)
	DSP.filter(wood, &"bandpass", 220.0, 1.2)
	DSP.mix(b, wood, 0.0, 2.0)
	DSP.envelope(b, 0.004, 0.55, 0.05)
	var bounces: Array = [
		[0.02, 1.0], [0.085, 0.85], [0.145, 0.95], [0.21, 0.7], [0.27, 0.78], [0.35, 0.6], [0.415, 0.5],
		[0.5, 0.52], [0.58, 0.38], [0.69, 0.4], [0.78, 0.28], [0.9, 0.22],
	]
	for bounce: Array in bounces:
		var at: float = float(bounce[0])
		var level: float = float(bounce[1])
		DSP.mix(b, _tik(rng.randf_range(2700.0, 4300.0), 0.003, rng), at, level * 1.6)
		DSP.mix(b, _knock(rng.randf_range(900.0, 1500.0), 0.014), at, level * 0.45)
	# Settling: a firmer click with a little wood behind it.
	DSP.mix(b, _tik(2300.0, 0.004, rng), 1.0, 1.5)
	DSP.mix(b, _knock(780.0, 0.03), 1.0, 0.8)
	DSP.shape(b, 0.002, 0.03)
	return b


## A small crowd cheering a win at the table: a burst of shouted "hey!"s and "yeah!"s over a swell of "aaah", a whoop
## on top, then applause thinning out.
func _crowd_cheer() -> PackedFloat32Array:
	var rng := _rng(5103)
	var d: float = 2.2
	var b := DSP.buffer(d)
	# The swell of voices: breathy noise through a vowel, loud at once, fading.
	var aah := DSP.noise(d, rng)
	DSP.filter_sweep(aah, &"bandpass", 700.0, 520.0, 2.0)
	var aah2 := DSP.noise(d, rng)
	DSP.filter_sweep(aah2, &"bandpass", 1300.0, 1000.0, 2.5)
	DSP.mix(aah, aah2, 0.0, 0.7)
	DSP.envelope(aah, 0.04, 0.45, 0.2)
	DSP.mix(b, aah, 0.0, 1.0)
	# The shouts: a dozen and a half voices, men, women, kids, in a ragged burst.
	var pitches: Array = [112.0, 130.0, 150.0, 175.0, 215.0, 250.0, 290.0, 330.0]
	for k: int in 18:
		var at: float = rng.randf_range(0.0, 0.55) + float(k) * 0.012
		var p: float = float(pitches[rng.randi_range(0, pitches.size() - 1)]) * rng.randf_range(0.96, 1.05)
		var level: float = rng.randf_range(0.55, 1.0)
		var length: float = rng.randf_range(0.2, 0.36)
		var shout: PackedFloat32Array
		if k % 2 == 0:
			# "hey": eh opening to ee.
			shout = _shout(length, p, p * 1.12, Vector2(600.0, 380.0), Vector2(1700.0, 2300.0), rng)
		else:
			# "yeah": ee into ah.
			shout = _shout(length, p * 1.05, p * 0.95, Vector2(360.0, 750.0), Vector2(2300.0, 1250.0), rng)
		DSP.mix(b, shout, at, level * 0.9)
	# The whoop: one voice swooping up and tipping over, then a smaller one.
	var whoop := _voice(0.6, func(u: float) -> float: return 330.0 * pow(2.2, sin(PI * pow(u, 0.7)) * 0.9) * (1.0 - 0.1 * u),
		Vector2(330.0, 640.0), Vector2(800.0, 1300.0), 6.5, 0.4, rng)
	DSP.envelope(whoop, 0.03, 0.4, 0.1)
	DSP.mix(b, whoop, 0.42, 0.8)
	var whoop2 := _voice(0.45, func(u: float) -> float: return 480.0 * pow(1.9, sin(PI * pow(u, 0.7)) * 0.9),
		Vector2(340.0, 600.0), Vector2(900.0, 1500.0), 6.0, 0.4, rng)
	DSP.envelope(whoop2, 0.03, 0.3, 0.1)
	DSP.mix(b, whoop2, 1.0, 0.45)
	# Applause: a patter of claps, dense at first and thinning out.
	var claps: int = 0
	while claps < 300:
		var at: float = rng.randf_range(0.5, d - 0.05)
		if rng.randf() > exp(-(at - 0.5) / 0.75):
			continue
		var clap := DSP.noise(0.014, rng)
		DSP.filter(clap, &"bandpass", rng.randf_range(1500.0, 3400.0), 0.8)
		DSP.envelope(clap, 0.0008, 0.004, 0.003)
		DSP.mix(b, clap, at, rng.randf_range(0.3, 1.0) * 2.8 * (0.5 + 0.5 * exp(-(at - 0.5) / 1.2)))
		claps += 1
	DSP.filter(b, &"highpass", 160.0)
	DSP.shape(b, 0.005, 0.3)
	return b


## The murmur of a busy casino floor, for playing in a loop: half a dozen mumbled conversations, a few chip clacks, a
## slot machine's bell arpeggio far off and a glass clink. It fades in and out over BUSTLE_FADE, so repeats that
## overlap by that much keep an even level.
func _casino_bustle() -> PackedFloat32Array:
	var rng := _rng(5104)
	var d: float = 2.4
	var b := DSP.buffer(d)
	# The room: a low bed of noise.
	var bed := DSP.noise(d, rng)
	DSP.filter(bed, &"lowpass", 900.0)
	DSP.filter(bed, &"highpass", 120.0)
	DSP.mix(b, bed, 0.0, 0.5)
	# The chatter: each talker a run of short phrases, each phrase a voice gliding between two vowels.
	var vowels: Array = [Vector2(760.0, 1220.0), Vector2(520.0, 880.0), Vector2(620.0, 1150.0), Vector2(560.0, 1750.0),
		Vector2(380.0, 2050.0)]
	for talker: int in 7:
		var pitch: float = rng.randf_range(95.0, 235.0)
		var at: float = rng.randf_range(-0.2, 0.2)
		while at < d - 0.1:
			var length: float = rng.randf_range(0.18, 0.5)
			var va: Vector2 = vowels[rng.randi_range(0, vowels.size() - 1)]
			var vb: Vector2 = vowels[rng.randi_range(0, vowels.size() - 1)]
			var p0: float = pitch * rng.randf_range(0.9, 1.15)
			var p1: float = pitch * rng.randf_range(0.8, 1.1)
			var phrase := _voice(length, func(u: float) -> float: return lerpf(p0, p1, u), Vector2(va.x, vb.x),
				Vector2(va.y, vb.y), 5.0, 0.4, rng)
			# Swelling in and out like a few syllables run together.
			for i: int in phrase.size():
				var u: float = float(i) / phrase.size()
				phrase[i] *= sin(PI * u) * (0.65 + 0.35 * sin(TAU * 2.5 * u * length / 0.2))
			if at >= 0.0:
				DSP.mix(b, phrase, at, 0.32)
			elif absf(at) < length:
				DSP.mix(b, phrase.slice(int(-at * RATE)), 0.0, 0.32)
			at += length + rng.randf_range(0.04, 0.45)
	DSP.filter(b, &"lowpass", 3200.0)
	# Chip clacks: two quick ones, then a single, and a stack set down.
	for clack: Array in [[0.62, 1.0], [0.69, 0.8], [1.48, 0.9], [1.54, 0.6], [1.58, 0.5]]:
		DSP.mix(b, _tik(rng.randf_range(2800.0, 4200.0), 0.004, rng), float(clack[0]), float(clack[1]) * 0.9)
		DSP.mix(b, _knock(rng.randf_range(1400.0, 1900.0), 0.008), float(clack[0]), float(clack[1]) * 0.2)
	# A slot machine's bell arpeggio, far away: soft FM bells through a low-pass.
	var bells := DSP.buffer(0.9)
	var notes: Array = [C5 * 2.0, E5 * 2.0, G5 * 2.0, C5 * 4.0, G5 * 2.0, C5 * 4.0]
	for k: int in notes.size():
		DSP.mix(bells, _fm_note(0.4, float(notes[k]), 3.5, 2.0, 0.4, 0.09), 0.075 * k, 1.0)
	DSP.filter(bells, &"lowpass", 2800.0)
	DSP.mix(b, bells, 0.95, 0.2)
	# A glass clink, with a small echo of it.
	var clink := DSP.metal_hit(0.4, 3050.0, 0.07, rng)
	DSP.filter(clink, &"highpass", 1500.0)
	DSP.mix(b, clink, 1.86, 0.1)
	DSP.mix(b, DSP.metal_hit(0.3, 3500.0, 0.05, rng), 1.91, 0.05)
	# Quiet and flat at both ends.
	var fade: int = int(BUSTLE_FADE * RATE)
	for i: int in mini(fade, b.size()):
		var w: float = smoothstep(0.0, 1.0, float(i) / fade)
		b[i] *= w
		b[b.size() - 1 - i] *= w
	return b


## The door swinging shut: a long low creak of stiff hinges, then the deep thud of the heavy door in its frame, the
## latch's click and a short brassy ring of the gilding.
func _golden_door() -> PackedFloat32Array:
	var rng := _rng(5105)
	var d: float = 1.6
	var b := DSP.buffer(d)
	# The creak: stick-slip, a low saw whose pitch stutters up as the hinge moves, through a sweeping resonance.
	var creak_len: float = 0.8
	var creak := DSP.osc(creak_len, func(u: float) -> float:
		return (95.0 + 110.0 * u) * (1.0 + 0.35 * sin(TAU * 17.0 * u * creak_len) * sin(TAU * 3.1 * u * creak_len)), &"saw")
	var grit := DSP.noise(creak_len, rng)
	DSP.mix(creak, grit, 0.0, 0.25)
	DSP.filter_sweep(creak, &"bandpass", 420.0, 1000.0, 3.5)
	for i: int in creak.size():
		var u: float = float(i) / creak.size()
		creak[i] *= pow(sin(PI * pow(u, 0.8)), 1.2) * (0.6 + 0.4 * sin(TAU * 5.0 * u * creak_len))
	DSP.mix(b, creak, 0.0, 3.6)
	# The thud: a deep boom with a knock of wood.
	var thud := _boom(0.9, 105.0, 38.0, 0.16, rng)
	DSP.mix(b, thud, 0.8, 1.2)
	var knock := DSP.noise(0.1, rng)
	DSP.filter(knock, &"lowpass", 900.0)
	DSP.envelope(knock, 0.001, 0.02, 0.01)
	DSP.mix(b, knock, 0.8, 0.9)
	# The latch: a bright steel click, a hair after the thud, and its tiny rattle.
	var latch := DSP.noise(0.04, rng)
	DSP.filter(latch, &"bandpass", 3600.0, 2.5)
	DSP.envelope(latch, 0.0005, 0.005, 0.004)
	DSP.mix(b, latch, 0.88, 1.8)
	DSP.mix(b, DSP.metal_hit(0.12, 1900.0, 0.03, rng), 0.88, 0.25)
	DSP.mix(b, DSP.metal_hit(0.06, 2300.0, 0.015, rng), 0.93, 0.15)
	# The brassy ring: the gilded door still humming, a brass FM note and a metal ring.
	var brass := _fm_note(0.7, 233.0, 1.0, 3.0, 1.2, 0.2)
	DSP.mix(b, brass, 0.81, 0.3)
	DSP.mix(b, DSP.metal_hit(0.7, 466.0, 0.22, rng), 0.81, 0.25)
	DSP.shape(b, 0.02, 0.2)
	return b


## The wall trembling: a deep rumble that grows, stone grinding on stone, little debris pattering down, timbers creaking.
func _wall_rumble() -> PackedFloat32Array:
	var rng := _rng(5106)
	var d: float = 2.4
	var b := DSP.buffer(d)
	var n: int = b.size()
	# The rumble: low noise and a sine shuddering at a few Hz, both growing.
	var low := DSP.noise(d, rng)
	DSP.filter_sweep(low, &"lowpass", 90.0, 200.0, 0.8)
	var shudder := DSP.osc(d, func(u: float) -> float: return 38.0 + 10.0 * u)
	for i: int in n:
		var u: float = float(i) / n
		var grow: float = 0.15 + 0.85 * pow(u, 1.4)
		var trem: float = 0.7 + 0.3 * sin(TAU * lerpf(5.0, 11.0, u) * u * d)
		b[i] = (low[i] * 5.0 + shudder[i] * 0.9) * grow * trem
	DSP.drive(b, 1.6)
	# Stone grinding: band-passed noise that catches and slips, louder as the wall moves more.
	var grind := DSP.noise(d, rng)
	DSP.filter_sweep(grind, &"bandpass", 320.0, 620.0, 1.8)
	var slip: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		slip = fmod(slip + lerpf(9.0, 19.0, u) / RATE, 1.0)
		grind[i] *= (0.3 + 0.7 * slip) * pow(u, 1.1) * 1.5
	DSP.mix(b, grind, 0.0, 1.0)
	# Debris: sparse at first, then a patter.
	for k: int in 110:
		var at: float = d * pow(rng.randf(), 0.55) * 0.97
		var bit := DSP.noise(0.012, rng)
		DSP.filter(bit, &"bandpass", rng.randf_range(1500.0, 5000.0), 1.2)
		DSP.envelope(bit, 0.0005, rng.randf_range(0.002, 0.005), 0.003)
		DSP.mix(b, bit, at, rng.randf_range(0.3, 1.0) * (0.5 + at / d) * 1.2)
	# Creaks: timber under strain, three, gliding up.
	for creak: Array in [[0.45, 0.5, 130.0, 0.5], [1.15, 0.6, 105.0, 0.7], [1.75, 0.45, 150.0, 0.9]]:
		var p0: float = float(creak[2])
		var span: float = float(creak[1])
		var c := DSP.osc(span, func(u: float) -> float: return p0 * (1.0 + 0.5 * u) * (1.0 + 0.08 * sin(TAU * 21.0 * u * span)), &"saw")
		DSP.filter_sweep(c, &"bandpass", 500.0, 900.0, 3.0)
		DSP.envelope(c, 0.05, span * 0.5, 0.1)
		DSP.mix(b, c, float(creak[0]), float(creak[3]) * 0.9)
	DSP.shape(b, 0.08, 0.12)
	return b


## The wall bursting: a crack and a huge boom, masonry crashing and tumbling in heavy thuds and clacks, the dust settling
## in a long tail of falling bits.
func _wall_collapse() -> PackedFloat32Array:
	var rng := _rng(5107)
	var d: float = 2.4
	var b := _explosion(d, 1.5, rng)
	for i: int in b.size():
		b[i] *= 0.5
	# Heavy blocks hitting: dull thuds and stone clacks scattered over the first two seconds.
	for k: int in 34:
		var at: float = 0.06 + 2.1 * pow(rng.randf(), 1.3)
		var level: float = rng.randf_range(0.4, 1.0) * exp(-at / 1.8)
		var thud := DSP.noise(0.09, rng)
		DSP.filter(thud, &"lowpass", rng.randf_range(250.0, 800.0))
		DSP.envelope(thud, 0.001, rng.randf_range(0.015, 0.04), 0.01)
		DSP.mix(b, thud, at, level * 6.0)
		var clack := DSP.noise(0.03, rng)
		DSP.filter(clack, &"bandpass", rng.randf_range(900.0, 2600.0), 1.5)
		DSP.envelope(clack, 0.0008, 0.006, 0.004)
		DSP.mix(b, clack, at, level * 2.2)
	# A rolling roar of masonry sliding down.
	var slide := DSP.noise(d, rng)
	DSP.filter_sweep(slide, &"bandpass", 700.0, 260.0, 0.8)
	DSP.envelope(slide, 0.03, 0.7, 0.2)
	DSP.mix(b, slide, 0.0, 2.2)
	# The tail: fine rubble still falling, thinning out.
	DSP.mix(b, _crackle(d, 110, 1.2, 2200.0, rng), 0.3, 2.2)
	DSP.shape(b, 0.001, 0.25)
	return b


## A cyborg guard's gruff "hey, stop!": two loud syllables, the second lower and clipped, a hiss of "s" between.
func _guard_halt() -> PackedFloat32Array:
	var rng := _rng(5108)
	var s: Array = [[0.02, 0.24, 1.05, 1.22, "e", 1.0], [0.38, 0.4, 1.18, 0.88, "o", 1.0]]
	var b := _mumble(0.9, s, 108.0, true, 5108)
	var hiss := DSP.noise(0.09, rng)
	DSP.filter(hiss, &"bandpass", 4200.0, 1.2)
	DSP.envelope(hiss, 0.01, 0.03, 0.02)
	DSP.mix(b, hiss, 0.28, 0.5)
	DSP.shape(b, 0.002, 0.04)
	return b
