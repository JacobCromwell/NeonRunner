extends "res://tools/asset_gen/sfx_bank.gd"
## The Magnate's sounds (GDD §10, the Golden Convergence's second stage and its defeat; task E5d-d), in the game's
## 16-bit style. His warnings sound the same every time (no pitch variation in data/audio/sfx_library.tres): the
## roar is a Pounce's warning, the crackle a Cable Lash's, as long as its warning (lash_warning, read from the
## fight's tuning, data/bosses/golden_boss_tuning.tres: regenerate it when that changes). Like every sound effect,
## each is under MAX_SECONDS (test_units).
##   magnate_roar       a Pounce's warning, and the transition's "screeching animal roar of rage": his voice rising
##                      into a bellow and falling away, a rattle in his throat, a screech riding on top
##   magnate_growl      a low growl from behind the runner (the chase): a rumbling rattle, an "oo" opening up
##   magnate_breath     his breathing behind the runner: a rasping breath in, a heavy one out
##   magnate_leap       his leap: claws scraping off the stone, a thump as he pushes off, a grunt, the air
##   magnate_crash      a Pounce's landing: a deep boom, the stone cracking, his claws skidding, debris
##   magnate_slam       crashing into a Flying Buttress's gate: a clang of gold, a boom, the stone giving way
##   magnate_stun       stunned in the rubble: a dazed groan sinking, the ports on his spine humming up (the weak
##                      points open)
##   magnate_stomp      a stomp on his back: a heavy thud, the ports shorting with a zap, a shriek
##   magnate_howl       hurling himself clear (after a stomp, or shaking free): a howl rising and falling, the air
##   magnate_crackle    a Cable Lash's warning (as long as lash_warning): electricity building along the cable,
##                      crackles thickening and climbing over a rising hum
##   magnate_whip       the lash: a swish across the track, the cable's crack, a zap dying away
##   magnate_tear       a cable tearing out of his back (his defeat): a rip, a spark's pop, the cable snapping free
##   magnate_screens    the screens dying (his defeat): the feed's hum falling away, a run of screens switching
##                      off in static, further and further away
##   magnate_screen     one tower's screen going dark: a burst of static, a screen's switch-off, a pop
##   magnate_burst      the suit bursting open (the transition): a blast, gold plates clanging off, a hiss
##   magnate_suit_fall  the empty suit toppling off the causeway: metal groaning, crashing through the balustrade,
##                      falling away
##   magnate_suit_down  the suit hitting the pools far below: a distant boom and a heavy splash
##   magnate_death      the third stomp: his death throes, a roar breaking up into convulsions and a choking rattle
##   magnate_collapse   collapsing on the causeway (in the silence): a heavy body falling, a last breath, the
##                      light in his cracks fizzling out
## The owner's playtest (task E5d-e):
##   magnate_snarl      a Claw Slash's warning: a sharp snarl, a hiss and a snap of his jaw (not the roar)
##   magnate_swipe      the swipe: a rush of air and three claws raking through it
##   magnate_glitch     a falling screen's warning (as long as screen_warning): a whine rising through stuttering
##                      static, louder to the end
##   magnate_smash      a screen crashing: a heavy hit, glass shattering and tinkling down, its electrics popping
##   magnate_yank       a tentacle yanking its screen back up: a metal cable whipping taut and away
##   magnate_pain       his cry of pain when a screen hits him: a yelp breaking into a choked snarl (not the roar,
##                      not the howl)

const GoldenBank = preload("res://tools/asset_gen/sfx_bank_golden_convergence.gd")
## A sound effect's longest (test_units: every sound is under 2.5 s).
const MAX_SECONDS: float = 2.45


func sounds() -> Dictionary:
	return {
		"magnate_roar": _roar,
		"magnate_growl": _growl,
		"magnate_breath": _breath,
		"magnate_leap": _leap,
		"magnate_crash": _crash,
		"magnate_slam": _slam,
		"magnate_stun": _stun,
		"magnate_stomp": _stomp,
		"magnate_howl": _howl,
		"magnate_crackle": _crackle_warning,
		"magnate_whip": _whip,
		"magnate_tear": _tear,
		"magnate_screens": _screens,
		"magnate_screen": _screen,
		"magnate_burst": _burst,
		"magnate_suit_fall": _suit_fall,
		"magnate_suit_down": _suit_down,
		"magnate_death": _death,
		"magnate_collapse": _collapse,
		"magnate_snarl": _snarl,
		"magnate_swipe": _swipe,
		"magnate_glitch": _glitch,
		"magnate_smash": _smash,
		"magnate_yank": _yank,
		"magnate_pain": _pain,
	}


# --- Building blocks ---------------------------------------------------------------------------------------

## A rattle in his throat: `b` chopped `hz_from`-`hz_to` times a second, `depth` 0-1, each pulse a little uneven.
func _fry(b: PackedFloat32Array, hz_from: float, hz_to: float, depth: float, rng: RandomNumberGenerator) -> void:
	var n: int = b.size()
	var phase: float = 0.0
	var jitter: float = 1.0
	for i: int in n:
		var before: float = phase
		phase += lerpf(hz_from, hz_to, float(i) / n) * jitter / RATE
		if floorf(phase) != floorf(before):
			jitter = rng.randf_range(0.85, 1.15)
		b[i] *= 1.0 - depth + depth * pow(absf(sin(PI * phase)), 0.6)


## His voice: _voice's saw through two formants (`pitch` Hz over normalized time, the vowel gliding from f1.x and
## f2.x to f1.y and f2.y), a rasp of breath through the upper formant, a growl an octave below, a rattle in the
## throat (_fry at `fry` Hz, from x to y), driven hard.
func _beast(seconds: float, pitch: Callable, f1: Vector2, f2: Vector2, fry: Vector2,
		rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _voice(seconds, pitch, f1, f2, 6.0, 0.4, rng)
	var rasp := DSP.noise(seconds, rng)
	DSP.filter_sweep(rasp, &"bandpass", f2.x, f2.y, 1.4)
	DSP.mix(b, rasp, 0.0, 0.35)
	var sub := DSP.osc(seconds, func(u: float) -> float: return float(pitch.call(u)) * 0.5, &"saw")
	DSP.filter(sub, &"lowpass", 420.0)
	DSP.mix(b, sub, 0.0, 0.3)
	_fry(b, fry.x, fry.y, 0.55, rng)
	DSP.drive(b, 4.0, 0.08)
	return b


## Stone breaking: a sharp crack and rubble pattering down over `seconds`, `count` bits.
func _rubble(seconds: float, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	var crack := DSP.noise(0.12, rng)
	DSP.filter(crack, &"highpass", 1300.0)
	DSP.envelope(crack, 0.0005, 0.03)
	DSP.mix(b, crack, 0.0, 1.0)
	for k: int in count:
		var at: float = 0.05 + pow(rng.randf(), 1.6) * (seconds - 0.2)
		var bit := DSP.noise(0.05, rng)
		DSP.filter(bit, &"bandpass", rng.randf_range(250.0, 1000.0), 1.0)
		DSP.envelope(bit, 0.001, 0.015)
		DSP.mix(b, bit, at, 0.6 * (1.0 - at / seconds))
	return b


## Electricity shorting: an FM buzz at `hz` snapping off over `seconds` under a burst of crackles.
func _zap(seconds: float, hz: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.fm(seconds, func(_u: float) -> float: return hz, 3.0, func(u: float) -> float: return 6.0 * exp(-u * 3.0) + 1.0)
	DSP.envelope(b, 0.002, seconds * 0.3)
	DSP.mix(b, _crackle(seconds, 30, seconds * 0.4, 3000.0, rng), 0.0, 1.2)
	return b


## A screen switching off: a whine dropping from `from_hz` to nothing, with a pop.
func _switch_off(from_hz: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.osc(0.22, func(u: float) -> float: return DSP.sweep(from_hz, 120.0, u), &"sine")
	DSP.envelope(b, 0.002, 0.08)
	DSP.mix(b, DSP.kick(0.12, 300.0, 90.0, rng), 0.0, 0.6)
	return b


## Static: crushed noise switching on and off in uneven 20-60 ms bursts, high-passed, over `seconds`.
func _static(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	DSP.filter(b, &"highpass", 1200.0)
	DSP.crush(b, 4, 6000.0)
	var n: int = b.size()
	var i: int = 0
	while i < n:
		var span: int = int(rng.randf_range(0.02, 0.06) * RATE)
		var level: float = 1.0 if rng.randf() < 0.6 else 0.15
		for j: int in mini(span, n - i):
			b[i + j] *= level
		i += span
	return b


## Fades the last `seconds` of `b` out smoothly.
func _fade_out(b: PackedFloat32Array, seconds: float) -> void:
	var n: int = b.size()
	var span: int = mini(int(seconds * RATE), n)
	for i: int in span:
		var k: float = float(i) / float(maxi(span, 1))
		b[n - 1 - i] *= k * k * (3.0 - 2.0 * k)


# --- His voice ---------------------------------------------------------------------------------------------

## A Pounce's warning and the transition's screech: his voice rising into a bellow (150 to 235 Hz) and falling
## away, an "ah" with a rattle in his throat, a screech riding on top (its pitch over three times his).
func _roar() -> PackedFloat32Array:
	var rng := _rng(1801)
	var d: float = 1.3
	var pitch := func(u: float) -> float:
		return DSP.sweep(150.0, 235.0, u / 0.3) if u < 0.3 else DSP.sweep(235.0, 140.0, (u - 0.3) / 0.7)
	var b := _beast(d, pitch, Vector2(620.0, 760.0), Vector2(1150.0, 1300.0), Vector2(32.0, 22.0), rng)
	DSP.adsr(b, 0.05, 0.25, 0.8, 0.45)
	var screech := _voice(d * 0.8, func(u: float) -> float: return float(pitch.call(u * 0.8)) * 3.2,
		Vector2(900.0, 700.0), Vector2(2600.0, 2000.0), 9.0, 0.8, rng)
	DSP.drive(screech, 5.0)
	DSP.filter(screech, &"bandpass", 2300.0, 0.7)
	DSP.adsr(screech, 0.04, 0.2, 0.7, 0.35)
	DSP.mix(b, screech, 0.02, 0.45)
	DSP.crush(b, 9, 18000.0)
	return b


## A low growl from behind the runner: a deep voice (78 to 64 Hz) rattling, its "oo" opening a little.
func _growl() -> PackedFloat32Array:
	var rng := _rng(1802)
	var d: float = 1.1
	var b := _beast(d, func(u: float) -> float: return DSP.sweep(78.0, 64.0, u), Vector2(330.0, 460.0),
		Vector2(780.0, 920.0), Vector2(24.0, 19.0), rng)
	_fry(b, 11.0, 8.0, 0.35, rng)
	DSP.adsr(b, 0.15, 0.2, 0.75, 0.35)
	DSP.filter(b, &"lowpass", 2400.0)
	DSP.crush(b, 9, 16000.0)
	return b


## His breathing: a rasping breath in (noise rising through a band-pass), a heavy one out with a low rattle.
func _breath() -> PackedFloat32Array:
	var rng := _rng(1803)
	var d: float = 0.95
	var b := DSP.buffer(d)
	var inhale := DSP.noise(0.32, rng)
	DSP.filter_sweep(inhale, &"bandpass", 700.0, 1150.0, 1.5)
	DSP.shape(inhale, 0.2, 0.08)
	DSP.mix(b, inhale, 0.0, 0.7)
	var exhale := DSP.noise(0.55, rng)
	DSP.filter_sweep(exhale, &"bandpass", 950.0, 480.0, 1.2)
	DSP.envelope(exhale, 0.03, 0.25)
	DSP.mix(b, exhale, 0.37, 1.0)
	var rattle := _voice(0.45, func(u: float) -> float: return DSP.sweep(62.0, 50.0, u), Vector2(400.0, 330.0),
		Vector2(850.0, 700.0), 4.0, 0.3, rng)
	_fry(rattle, 20.0, 14.0, 0.7, rng)
	DSP.envelope(rattle, 0.03, 0.18)
	DSP.mix(b, rattle, 0.38, 0.35)
	DSP.filter(b, &"lowpass", 2600.0)
	DSP.crush(b, 10, 16000.0)
	return b


## Hurling himself clear: a howl rising (200 to 380 Hz) and falling, its vowel opening from "oo" to "ah", with
## the scrape and the rush of air of his leap.
func _howl() -> PackedFloat32Array:
	var rng := _rng(1809)
	var d: float = 1.5
	var pitch := func(u: float) -> float:
		return DSP.sweep(200.0, 380.0, u / 0.35) if u < 0.35 else DSP.sweep(380.0, 230.0, (u - 0.35) / 0.65)
	var b := _beast(d, pitch, Vector2(380.0, 760.0), Vector2(900.0, 1300.0), Vector2(26.0, 20.0), rng)
	DSP.adsr(b, 0.08, 0.3, 0.8, 0.5)
	var scrape := DSP.noise(0.12, rng)
	DSP.filter(scrape, &"bandpass", 3000.0, 1.0)
	DSP.envelope(scrape, 0.002, 0.03)
	DSP.mix(b, scrape, 0.0, 0.6)
	DSP.mix(b, _whoosh(0.6, 400.0, 2000.0, 1.0, rng), 0.1, 0.45)
	DSP.crush(b, 9, 18000.0)
	return b


## The third stomp: his death throes (2 s): a roar sinking from 240 to 110 Hz, breaking up into convulsions (its
## level jerking every 60-140 ms, its pitch jumping, more and more), the ports on his spine sputtering, a choking
## rattle at the end; it's gone before he collapses, in the silence.
func _death() -> PackedFloat32Array:
	var rng := _rng(1818)
	var d: float = 2.1
	# The jerks: segments of 60-140 ms, each a level and a pitch of its own, the swings growing.
	var cuts: Array[float] = [0.0]
	var levels: Array[float] = [1.0]
	var bends: Array[float] = [1.0]
	while cuts[-1] < d:
		var u: float = cuts[-1] / d
		cuts.append(cuts[-1] + rng.randf_range(0.06, 0.14))
		levels.append(lerpf(1.0, rng.randf_range(0.15, 1.0), clampf(u * 1.6, 0.0, 1.0)))
		bends.append(1.0 + rng.randf_range(-0.16, 0.16) * clampf(u * 1.8, 0.0, 1.0))
	var segment := func(t: float) -> int:
		return clampi(cuts.bsearch(t, false) - 1, 0, cuts.size() - 1)
	var pitch := func(u: float) -> float:
		return DSP.sweep(240.0, 110.0, pow(u, 0.8)) * bends[int(segment.call(u * d))]
	var b := _beast(d, pitch, Vector2(760.0, 360.0), Vector2(1300.0, 800.0), Vector2(18.0, 8.0), rng)
	var n: int = b.size()
	var level: float = 1.0
	for i: int in n:
		var t: float = float(i) / RATE
		# Smoothed, so the jerks thump instead of clicking.
		level = lerpf(level, levels[int(segment.call(t))], 0.004)
		b[i] *= level
	DSP.adsr(b, 0.03, 0.4, 0.7, 0.2)
	var sputter := _crackle(d, 40, 0.8, 2800.0, rng)
	DSP.mix(b, sputter, 0.3, 0.4)
	_fade_out(b, 0.6)
	DSP.crush(b, 9, 18000.0)
	return b


# --- His body ----------------------------------------------------------------------------------------------

## His leap: claws scraping off the stone (three quick scratches), a thump as he pushes off, a grunt, the rush of
## air.
func _leap() -> PackedFloat32Array:
	var rng := _rng(1804)
	var d: float = 0.8
	var b := DSP.buffer(d)
	for k: int in 3:
		var scratch := DSP.noise(0.07, rng)
		DSP.filter(scratch, &"bandpass", 3200.0 - k * 300.0, 1.0)
		DSP.envelope(scratch, 0.002, 0.02)
		DSP.mix(b, scratch, k * 0.05, 0.7)
	DSP.mix(b, DSP.kick(0.3, 110.0, 45.0, rng), 0.02, 0.8)
	var grunt := _voice(0.25, func(u: float) -> float: return DSP.sweep(160.0, 120.0, u), Vector2(700.0, 600.0),
		Vector2(1200.0, 1100.0), 5.0, 0.2, rng)
	DSP.drive(grunt, 3.0)
	DSP.envelope(grunt, 0.01, 0.08)
	DSP.mix(b, grunt, 0.0, 0.5)
	DSP.mix(b, _whoosh(0.6, 300.0, 1600.0, 1.0, rng), 0.08, 0.7)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 18000.0)
	return b


## A Pounce's landing: a deep boom with a heavy thump over it (heard on a phone's speaker too), the stone
## cracking, his claws skidding (noise juddering), debris.
func _crash() -> PackedFloat32Array:
	var rng := _rng(1805)
	var d: float = 1.4
	var b := DSP.buffer(d)
	DSP.mix(b, _boom(d, 140.0, 36.0, 0.35, rng), 0.0, 0.6)
	var thump := DSP.noise(0.25, rng)
	DSP.filter(thump, &"bandpass", 650.0, 0.8)
	DSP.envelope(thump, 0.001, 0.06)
	DSP.mix(b, thump, 0.0, 1.4)
	DSP.mix(b, _rubble(d, 16, rng), 0.0, 1.3)
	var skid := DSP.noise(0.35, rng)
	DSP.filter(skid, &"bandpass", 1400.0, 1.2)
	var judder: float = 0.0
	for i: int in skid.size():
		judder += 35.0 / RATE
		skid[i] *= 0.5 + 0.5 * sin(TAU * judder)
	DSP.envelope(skid, 0.01, 0.15)
	DSP.mix(b, skid, 0.03, 0.9)
	DSP.mix(b, _crackle(d, 30, 0.4, 1800.0, rng), 0.0, 0.9)
	DSP.drive(b, 2.0)
	DSP.crush(b, 9, 18000.0)
	return b


## Crashing into the gate: a clang of its gold (two heavy struck plates), a boom, the stone giving way.
func _slam() -> PackedFloat32Array:
	var rng := _rng(1806)
	var d: float = 1.5
	var b := _boom(d, 150.0, 40.0, 0.3, rng)
	DSP.mix(b, DSP.metal_hit(1.2, 210.0, 0.45, rng), 0.0, 0.7)
	DSP.mix(b, DSP.metal_hit(0.9, 330.0, 0.3, rng), 0.01, 0.5)
	DSP.mix(b, _rubble(d - 0.05, 22, rng), 0.03, 1.0)
	var dust := DSP.noise(d, rng)
	DSP.filter(dust, &"lowpass", 600.0)
	DSP.envelope(dust, 0.02, 0.45, 0.1)
	DSP.mix(b, dust, 0.0, 0.5)
	DSP.drive(b, 1.8)
	DSP.crush(b, 9, 18000.0)
	return b


## Stunned in the rubble (it plays with the slam): a dazed groan sinking from 170 to 95 Hz, the ports on his spine
## humming up and pulsing (the weak points open), a rising whine with them.
func _stun() -> PackedFloat32Array:
	var rng := _rng(1807)
	var d: float = 1.7
	var b := DSP.buffer(d)
	var groan := _beast(1.3, func(u: float) -> float: return DSP.sweep(170.0, 95.0, u), Vector2(700.0, 400.0),
		Vector2(1200.0, 850.0), Vector2(18.0, 12.0), rng)
	DSP.adsr(groan, 0.08, 0.3, 0.6, 0.5)
	DSP.mix(b, groan, 0.15, 0.8)
	var hum := DSP.osc(d - 0.3, func(_u: float) -> float: return 110.0, &"square")
	DSP.filter(hum, &"lowpass", 1500.0)
	var n: int = hum.size()
	for i: int in n:
		hum[i] *= 0.6 + 0.4 * sin(TAU * 6.0 * float(i) / RATE)
	DSP.adsr(hum, 0.3, 0.2, 0.8, 0.3)
	DSP.mix(b, hum, 0.3, 0.35)
	var whine := DSP.osc(0.6, func(u: float) -> float: return DSP.sweep(300.0, 700.0, u), &"sine")
	DSP.shape(whine, 0.2, 0.15)
	DSP.mix(b, whine, 0.25, 0.2)
	DSP.crush(b, 9, 18000.0)
	return b


## A stomp on his back: a heavy thud and a crunch, the ports shorting with a zap, a shriek (520 to 300 Hz).
func _stomp() -> PackedFloat32Array:
	var rng := _rng(1808)
	var d: float = 1.1
	var b := DSP.kick(0.35, 170.0, 50.0, rng)
	b.resize(int(d * RATE))
	var crunch := DSP.noise(0.12, rng)
	DSP.filter(crunch, &"bandpass", 900.0, 0.8)
	DSP.envelope(crunch, 0.001, 0.03)
	DSP.mix(b, crunch, 0.0, 0.8)
	DSP.mix(b, _zap(0.5, 120.0, rng), 0.01, 0.5)
	var shriek := _voice(0.75, func(u: float) -> float: return DSP.sweep(520.0, 300.0, u), Vector2(900.0, 700.0),
		Vector2(2500.0, 1800.0), 9.0, 1.0, rng)
	DSP.drive(shriek, 5.0)
	DSP.adsr(shriek, 0.02, 0.2, 0.7, 0.3)
	DSP.mix(b, shriek, 0.06, 0.8)
	DSP.crush_sweep(b, 9.0, 7.0, 18000.0, 12000.0)
	return b


## Collapsing on the causeway, in the silence: a heavy body falling (a boom and a thud), a smaller one as his
## head and arms come down, a last breath out with a rattle, the light in his cracks fizzling out.
func _collapse() -> PackedFloat32Array:
	var rng := _rng(1819)
	var d: float = 1.9
	var b := DSP.buffer(d)
	DSP.mix(b, _boom(1.6, 120.0, 35.0, 0.3, rng), 0.0, 0.55)
	var fall := DSP.noise(0.3, rng)
	DSP.filter(fall, &"bandpass", 520.0, 0.7)
	DSP.envelope(fall, 0.002, 0.08)
	DSP.mix(b, fall, 0.0, 1.5)
	var second := DSP.noise(0.2, rng)
	DSP.filter(second, &"bandpass", 450.0, 0.8)
	DSP.envelope(second, 0.002, 0.05)
	DSP.mix(b, second, 0.28, 0.9)
	DSP.mix(b, _boom(0.6, 100.0, 40.0, 0.15, rng), 0.28, 0.35)
	DSP.mix(b, _rubble(1.0, 10, rng), 0.0, 0.6)
	DSP.mix(b, _crackle(1.2, 18, 0.4, 1500.0, rng), 0.0, 0.6)
	var breath := DSP.noise(1.0, rng)
	DSP.filter_sweep(breath, &"bandpass", 700.0, 350.0, 1.0)
	DSP.envelope(breath, 0.1, 0.4, 0.2)
	DSP.mix(b, breath, 0.45, 0.6)
	var rattle := _voice(0.8, func(u: float) -> float: return DSP.sweep(70.0, 50.0, u), Vector2(400.0, 300.0),
		Vector2(800.0, 650.0), 3.0, 0.3, rng)
	_fry(rattle, 14.0, 7.0, 0.8, rng)
	DSP.envelope(rattle, 0.05, 0.3, 0.2)
	DSP.mix(b, rattle, 0.5, 0.2)
	var fizzle := DSP.osc(1.2, func(u: float) -> float: return DSP.sweep(220.0, 60.0, u), &"sine")
	DSP.mix(fizzle, _crackle(1.2, 14, 0.5, 2400.0, rng), 0.0, 0.6)
	DSP.envelope(fizzle, 0.05, 0.4, 0.2)
	DSP.mix(b, fizzle, 0.6, 0.15)
	_fade_out(b, 0.3)
	DSP.crush(b, 9, 18000.0)
	return b


# --- His cables --------------------------------------------------------------------------------------------

## A Cable Lash's warning, as long as lash_warning: electricity building along the cable, crackles thickening
## toward the end and climbing in pitch (band-passed 1.2 to 4.2 kHz) over a hum rising from 70 to 260 Hz and a
## faint whine; louder to the end, the same every time.
func _crackle_warning() -> PackedFloat32Array:
	var rng := _rng(1810)
	var d: float = clampf(GoldenBank.tuning_value("lash_warning", 1.25), 0.6, MAX_SECONDS - 0.05)
	var b := DSP.buffer(d)
	var hum := DSP.osc(d, func(u: float) -> float: return DSP.sweep(70.0, 260.0, pow(u, 1.3)), &"saw")
	DSP.filter_sweep(hum, &"lowpass", 600.0, 2400.0)
	DSP.drive(hum, 2.0)
	DSP.mix(b, hum, 0.0, 0.35)
	for k: int in 90:
		var at: float = d * pow(rng.randf(), 0.55)
		var u: float = at / d
		var spark := DSP.noise(rng.randf_range(0.01, 0.03), rng)
		DSP.filter(spark, &"bandpass", lerpf(1200.0, 4200.0, u), 1.2)
		DSP.envelope(spark, 0.0005, 0.006)
		DSP.mix(b, spark, at, rng.randf_range(0.5, 1.0) * (0.4 + 0.6 * u))
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(900.0, 2400.0, u), &"sine")
	DSP.mix(b, whine, 0.0, 0.1)
	var n: int = b.size()
	for i: int in n:
		b[i] *= 0.4 + 0.6 * float(i) / n
	DSP.shape(b, 0.02, 0.02)
	DSP.crush(b, 8, 17000.0)
	return b


## The lash: a swish across the track (a band-pass sweeping down), the cable's sharp crack, a zap dying away.
func _whip() -> PackedFloat32Array:
	var rng := _rng(1811)
	var d: float = 0.9
	var b := DSP.buffer(d)
	DSP.mix(b, _whoosh(0.3, 4000.0, 700.0, 1.2, rng), 0.0, 0.9)
	var crack := DSP.noise(0.03, rng)
	DSP.filter(crack, &"highpass", 1800.0)
	DSP.envelope(crack, 0.0003, 0.006)
	DSP.mix(b, crack, 0.11, 2.0)
	var snap := DSP.osc(0.06, func(u: float) -> float: return DSP.sweep(1800.0, 600.0, u), &"sine")
	DSP.envelope(snap, 0.001, 0.02)
	DSP.mix(b, snap, 0.11, 0.3)
	DSP.mix(b, _crackle(0.6, 35, 0.25, 2600.0, rng), 0.1, 0.6)
	var buzz := DSP.osc(0.5, func(_u: float) -> float: return 120.0, &"saw")
	DSP.filter(buzz, &"lowpass", 1200.0)
	DSP.envelope(buzz, 0.005, 0.15)
	DSP.mix(b, buzz, 0.1, 0.35)
	DSP.drive(b, 1.8)
	DSP.crush(b, 8, 17000.0)
	return b


## A cable tearing out of his back: a rip (noise torn into uneven grains), a spark's pop, the cable snapping
## free.
func _tear() -> PackedFloat32Array:
	var rng := _rng(1812)
	var d: float = 0.6
	var b := DSP.buffer(d)
	var rip := DSP.noise(0.3, rng)
	DSP.filter(rip, &"bandpass", 1300.0, 0.9)
	var i: int = 0
	while i < rip.size():
		var span: int = int(rng.randf_range(0.006, 0.014) * RATE)
		var level: float = rng.randf_range(0.2, 1.0)
		for j: int in mini(span, rip.size() - i):
			rip[i + j] *= level
		i += span
	DSP.envelope(rip, 0.01, 0.12)
	DSP.mix(b, rip, 0.0, 0.9)
	var pop := DSP.noise(0.05, rng)
	DSP.filter(pop, &"highpass", 3000.0)
	DSP.envelope(pop, 0.0005, 0.01)
	DSP.mix(b, pop, 0.18, 1.0)
	DSP.mix(b, _crackle(0.35, 20, 0.12, 3200.0, rng), 0.18, 0.5)
	var snap := DSP.osc(0.12, func(u: float) -> float: return DSP.sweep(900.0, 250.0, u), &"sine")
	DSP.envelope(snap, 0.001, 0.04)
	DSP.mix(b, snap, 0.18, 0.4)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 18000.0)
	return b


# --- The screens -------------------------------------------------------------------------------------------

## The screens dying (1.5 s, gone before he collapses): the feed's hum falling away under a power cut's thump,
## six screens switching off one after another, each further away (darker, softer), static breaking up.
func _screens() -> PackedFloat32Array:
	var rng := _rng(1813)
	var d: float = 1.5
	var b := DSP.kick(0.6, 80.0, 30.0, rng)
	b.resize(int(d * RATE))
	var hum := DSP.osc(d, func(u: float) -> float: return DSP.sweep(60.0, 22.0, u), &"saw")
	DSP.mix(hum, DSP.osc(d, func(u: float) -> float: return DSP.sweep(120.0, 44.0, u), &"square"), 0.0, 0.3)
	DSP.filter(hum, &"lowpass", 500.0)
	DSP.envelope(hum, 0.005, 0.5)
	DSP.mix(b, hum, 0.0, 0.6)
	for k: int in 6:
		var off := _switch_off(3200.0, rng)
		DSP.filter(off, &"lowpass", 4000.0 - k * 500.0)
		DSP.mix(b, off, 0.05 + k * 0.18, 0.5 * (1.0 - k * 0.12))
	var fizz := _static(1.2, rng)
	DSP.envelope(fizz, 0.01, 0.4)
	DSP.mix(b, fizz, 0.02, 0.35)
	_fade_out(b, 0.3)
	DSP.crush(b, 8, 16000.0)
	return b


## One tower's screen going dark: a burst of static, its switch-off and a pop.
func _screen() -> PackedFloat32Array:
	var rng := _rng(1814)
	var d: float = 0.55
	var b := _static(0.18, rng)
	DSP.envelope(b, 0.002, 0.08)
	b.resize(int(d * RATE))
	DSP.mix(b, _switch_off(2600.0, rng), 0.08, 1.0)
	DSP.crush(b, 8, 16000.0)
	return b


# --- The suit ----------------------------------------------------------------------------------------------

## The suit bursting open: a blast, its gold plates clanging off in every direction, metal tearing, a hiss.
func _burst() -> PackedFloat32Array:
	var rng := _rng(1815)
	var d: float = 1.8
	var b := _explosion(d, 0.9, rng)
	for k: int in 7:
		var clang := DSP.metal_hit(0.6, rng.randf_range(250.0, 900.0), rng.randf_range(0.15, 0.3), rng)
		DSP.mix(b, clang, 0.02 + k * 0.09 + rng.randf_range(0.0, 0.04), 0.4)
	var hiss := DSP.noise(1.0, rng)
	DSP.filter(hiss, &"highpass", 3500.0)
	DSP.envelope(hiss, 0.005, 0.35)
	DSP.mix(b, hiss, 0.03, 0.4)
	var groan := DSP.fm(0.6, func(u: float) -> float: return DSP.sweep(90.0, 60.0, u), 1.41,
		func(_u: float) -> float: return 3.0)
	DSP.filter(groan, &"bandpass", 400.0, 0.9)
	DSP.envelope(groan, 0.01, 0.25)
	DSP.mix(b, groan, 0.05, 0.4)
	DSP.crush(b, 9, 18000.0)
	return b


## The empty suit toppling off the causeway: its metal groaning as it tips, scraping and crashing through the
## balustrade (clangs, stone breaking), then falling away (a rush of air dropping and fading).
func _suit_fall() -> PackedFloat32Array:
	var rng := _rng(1816)
	var d: float = 2.2
	var b := DSP.buffer(d)
	var groan := DSP.fm(1.6, func(u: float) -> float: return DSP.sweep(75.0, 55.0, u), 1.41,
		func(u: float) -> float: return 2.5 + 1.5 * sin(u * 9.0))
	DSP.filter(groan, &"bandpass", 300.0, 0.9)
	DSP.shape(groan, 0.3, 0.5)
	DSP.mix(b, groan, 0.0, 0.5)
	var scrape := DSP.noise(0.8, rng)
	DSP.filter_sweep(scrape, &"bandpass", 600.0, 1200.0, 1.4)
	var judder: float = 0.0
	for i: int in scrape.size():
		judder += 25.0 / RATE
		scrape[i] *= 0.55 + 0.45 * sin(TAU * judder)
	DSP.drive(scrape, 3.0)
	DSP.adsr(scrape, 0.05, 0.2, 0.7, 0.2)
	DSP.mix(b, scrape, 0.15, 0.6)
	DSP.mix(b, DSP.metal_hit(1.0, 160.0, 0.5, rng), 0.25, 0.6)
	DSP.mix(b, DSP.metal_hit(0.8, 250.0, 0.35, rng), 0.27, 0.4)
	DSP.mix(b, _rubble(1.0, 14, rng), 0.25, 0.8)
	DSP.mix(b, _whoosh(1.4, 900.0, 250.0, 0.8, rng), 0.7, 0.5)
	_fade_out(b, 0.5)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 18000.0)
	return b


## The suit hitting the pools far below: a distant boom, a heavy splash (a burst of noise closing down) and its
## spray falling back, a muffled clang of metal.
func _suit_down() -> PackedFloat32Array:
	var rng := _rng(1817)
	var d: float = 2.0
	var b := _boom(d, 90.0, 30.0, 0.6, rng)
	var splash := DSP.noise(d, rng)
	DSP.filter_sweep(splash, &"lowpass", 5000.0, 800.0, 0.7)
	DSP.envelope(splash, 0.005, 0.35)
	DSP.mix(b, splash, 0.0, 0.8)
	DSP.mix(b, _crackle(1.5, 40, 0.5, 1200.0, rng), 0.1, 0.4)
	var clang := DSP.metal_hit(1.5, 110.0, 0.6, rng)
	DSP.filter(clang, &"lowpass", 1200.0)
	DSP.mix(b, clang, 0.0, 0.5)
	DSP.filter(b, &"lowpass", 3000.0)
	_fade_out(b, 0.5)
	DSP.crush(b, 9, 16000.0)
	return b


# --- The owner's playtest (task E5d-e) ----------------------------------------------------------------------

## A Claw Slash's warning (0.55 s, the same every time): a sharp snarl (his voice jumping from 210 to 330 Hz and
## dropping, a fast rattle, an "eh" vowel), a hiss through his teeth over it, a snap of his jaw at the start. Short
## and high: never the Pounce's long roar.
func _snarl() -> PackedFloat32Array:
	var rng := _rng(1820)
	var d: float = 0.55
	var pitch := func(u: float) -> float:
		return DSP.sweep(210.0, 330.0, u / 0.25) if u < 0.25 else DSP.sweep(330.0, 190.0, (u - 0.25) / 0.75)
	var b := _beast(d, pitch, Vector2(560.0, 700.0), Vector2(1700.0, 1500.0), Vector2(48.0, 34.0), rng)
	DSP.adsr(b, 0.015, 0.12, 0.75, 0.2)
	var hiss := DSP.noise(d, rng)
	DSP.filter(hiss, &"bandpass", 4200.0, 1.1)
	DSP.adsr(hiss, 0.02, 0.15, 0.6, 0.2)
	DSP.mix(b, hiss, 0.0, 0.45)
	var snap := DSP.noise(0.04, rng)
	DSP.filter(snap, &"bandpass", 1800.0, 1.2)
	DSP.envelope(snap, 0.0005, 0.012)
	DSP.mix(b, snap, 0.0, 1.0)
	DSP.crush(b, 9, 18000.0)
	return b


## The swipe (0.5 s): a rush of air sweeping down (a band-pass falling from 3.5 to 0.6 kHz) and three claws raking
## through it, one after another, each a scrape of noise.
func _swipe() -> PackedFloat32Array:
	var rng := _rng(1821)
	var d: float = 0.5
	var b := DSP.buffer(d)
	DSP.mix(b, _whoosh(0.32, 3500.0, 600.0, 1.3, rng), 0.0, 1.0)
	for k: int in 3:
		var rake := DSP.noise(0.09, rng)
		DSP.filter_sweep(rake, &"bandpass", 3600.0 - k * 400.0, 1500.0 - k * 200.0, 1.6)
		DSP.envelope(rake, 0.002, 0.035)
		DSP.mix(b, rake, 0.06 + k * 0.035, 0.75)
	var thump := DSP.kick(0.18, 120.0, 55.0, rng)
	DSP.mix(b, thump, 0.1, 0.4)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 18000.0)
	return b


## A falling screen's warning, as long as screen_warning (read from the fight's tuning): his feed's whine rising
## from 300 Hz to 2.2 kHz under stuttering static (bursts switching on and off faster and faster), louder to the
## end, then a hard stop: the same every time.
func _glitch() -> PackedFloat32Array:
	var rng := _rng(1822)
	var d: float = clampf(GoldenBank.tuning_value("screen_warning", 0.9), 0.5, MAX_SECONDS - 0.05)
	var b := DSP.buffer(d)
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(300.0, 2200.0, pow(u, 1.4)), &"square")
	DSP.filter_sweep(whine, &"lowpass", 900.0, 5000.0)
	DSP.mix(b, whine, 0.0, 0.35)
	var buzz := DSP.osc(d, func(u: float) -> float: return DSP.sweep(60.0, 120.0, u), &"saw")
	DSP.filter(buzz, &"lowpass", 700.0)
	DSP.mix(b, buzz, 0.0, 0.25)
	var fizz := _static(d, rng)
	DSP.mix(b, fizz, 0.0, 0.4)
	# The stutter: the whole sound cut in and out, faster toward the crash.
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		phase += lerpf(9.0, 26.0, u) / RATE
		var gate: float = 1.0 if fmod(phase, 1.0) < 0.72 else 0.35
		b[i] *= gate * (0.35 + 0.65 * u)
	DSP.shape(b, 0.01, 0.02)
	DSP.crush(b, 8, 16000.0)
	return b


## A screen crashing (1.0 s): a heavy hit (a boom and a thud), its glass shattering (a burst of bright noise) and
## tinkling down (thirty small high pings), its electrics popping and dying.
func _smash() -> PackedFloat32Array:
	var rng := _rng(1823)
	var d: float = 1.0
	var b := DSP.buffer(d)
	DSP.mix(b, _boom(0.7, 150.0, 45.0, 0.2, rng), 0.0, 0.55)
	var thud := DSP.noise(0.18, rng)
	DSP.filter(thud, &"bandpass", 700.0, 0.8)
	DSP.envelope(thud, 0.001, 0.05)
	DSP.mix(b, thud, 0.0, 1.1)
	var burst := DSP.noise(0.25, rng)
	DSP.filter(burst, &"highpass", 3000.0)
	DSP.envelope(burst, 0.001, 0.06)
	DSP.mix(b, burst, 0.005, 0.9)
	for k: int in 30:
		var at: float = 0.02 + pow(rng.randf(), 1.5) * (d - 0.15)
		var hz: float = rng.randf_range(3200.0, 7000.0)
		var ping := DSP.osc(0.05, func(_u: float) -> float: return hz, &"sine")
		DSP.envelope(ping, 0.0005, 0.012)
		DSP.mix(b, ping, at, rng.randf_range(0.15, 0.4) * (1.0 - at / d))
	DSP.mix(b, _zap(0.35, 140.0, rng), 0.02, 0.35)
	_fade_out(b, 0.25)
	DSP.crush(b, 9, 18000.0)
	return b


## A tentacle yanking its screen back up (0.5 s): a metal cable whipping taut (a twang falling from 900 Hz), a rush
## of air rising away, a creak.
func _yank() -> PackedFloat32Array:
	var rng := _rng(1824)
	var d: float = 0.5
	var b := DSP.buffer(d)
	var twang := DSP.fm(0.35, func(u: float) -> float: return DSP.sweep(900.0, 420.0, u), 1.41,
		func(u: float) -> float: return 3.0 * exp(-u * 4.0) + 0.5)
	DSP.envelope(twang, 0.002, 0.1)
	DSP.mix(b, twang, 0.0, 0.5)
	DSP.mix(b, _whoosh(0.4, 500.0, 2600.0, 1.0, rng), 0.03, 0.8)
	var creak := DSP.osc(0.12, func(u: float) -> float: return DSP.sweep(180.0, 240.0, u), &"saw")
	DSP.filter(creak, &"bandpass", 900.0, 1.0)
	DSP.envelope(creak, 0.005, 0.05)
	DSP.mix(b, creak, 0.0, 0.3)
	DSP.crush(b, 9, 18000.0)
	return b


## His cry of pain when a screen hits him (0.85 s): a yelp leaping from 260 to 520 Hz and breaking off into a choked
## snarl falling to 150 Hz, rattling: higher and shorter than the roar, harsher than the howl.
func _pain() -> PackedFloat32Array:
	var rng := _rng(1825)
	var d: float = 0.85
	var pitch := func(u: float) -> float:
		return DSP.sweep(260.0, 520.0, u / 0.2) if u < 0.2 else DSP.sweep(520.0, 150.0, pow((u - 0.2) / 0.8, 0.7))
	var b := _beast(d, pitch, Vector2(800.0, 450.0), Vector2(1600.0, 900.0), Vector2(38.0, 16.0), rng)
	DSP.adsr(b, 0.01, 0.18, 0.7, 0.3)
	var crack := DSP.noise(0.05, rng)
	DSP.filter(crack, &"highpass", 2000.0)
	DSP.envelope(crack, 0.0005, 0.015)
	DSP.mix(b, crack, 0.17, 0.6)
	DSP.crush(b, 9, 18000.0)
	return b
