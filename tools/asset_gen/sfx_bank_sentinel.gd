extends "res://tools/asset_gen/sfx_bank.gd"
## The Gilded Sentinels' sounds (GDD §9.11), in the game's 16-bit style:
##   gilded_sentinel_grind  the warning (GDD §9.11: "its eyes flare and stone grinds"): a heavy stone
##                          statue coming to life, a gritty grinding over a deep rumble that swells
##                          through the warning, and the scrape of the halberd being drawn back over
##                          its last part (GildedSentinel.RAISE_SECONDS before the swing). Nothing like
##                          any other warning: no chime, crackle or whine.
##   gilded_sentinel_swing  the halberd sweeping through its cut: a heavy, fast whoosh with the blade's
##                          ring at its front and a stone thud.
##   gilded_sentinel_break  shot down or kicked: stone cracking and crumbling, gold clattering, a dull
##                          thump.

const SentinelScript = preload("res://scripts/enemies/gilded_sentinel.gd")


func sounds() -> Dictionary:
	return {
		"gilded_sentinel_grind": _grind,
		"gilded_sentinel_swing": _swing,
		"gilded_sentinel_break": _break,
	}


## Seconds the warning lasts (GildedSentinelTuning.warning_seconds): the grind fills it.
func _warning() -> float:
	var t := load("res://data/enemies/gilded_sentinel.tres") as GildedSentinelTuning
	return t.warning_seconds if t != null else 1.2


## Stone grinding on stone: noise through low resonant band-passes, chopped into grains at an uneven
## rate (the surfaces catching and slipping), over a deep wobbling rumble, swelling to the end.
func _grind() -> PackedFloat32Array:
	var rng := _rng(1101)
	var length: float = _warning() + 0.15
	var b := DSP.buffer(length)
	var grit := DSP.noise(length, rng)
	DSP.filter(grit, &"bandpass", 260.0, 2.2)
	var grit_hi := DSP.noise(length, rng)
	DSP.filter(grit_hi, &"bandpass", 900.0, 1.6)
	# Its upper grit carries the warning on a phone's speaker, which can't play the rumble.
	var grit_top := DSP.noise(length, rng)
	DSP.filter(grit_top, &"bandpass", 2300.0, 1.3)
	# The grains: an uneven chop between 18 and 34 per second.
	var phase: float = 0.0
	var rate: float = 24.0
	for i: int in b.size():
		var t: float = float(i) / RATE
		if fmod(phase + rate / RATE, 1.0) < phase:
			rate = rng.randf_range(18.0, 34.0)
		phase = fmod(phase + rate / RATE, 1.0)
		var grain: float = pow(sin(PI * phase), 3.0) * (0.55 + 0.45 * rng.randf())
		var swell: float = smoothstep(0.0, length * 0.75, t) * (1.0 - smoothstep(length - 0.12, length, t))
		b[i] = (grit[i] * 1.2 + grit_hi[i] * 1.4 + grit_top[i] * 0.7) * (0.25 + 0.75 * grain) * (0.35 + 0.65 * swell)
	var rumble := DSP.osc(length, func(u: float) -> float: return 42.0 + 8.0 * sin(TAU * 3.0 * u), &"triangle")
	for i: int in rumble.size():
		var t: float = float(i) / RATE
		rumble[i] *= smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(length - 0.15, length, t))
	DSP.mix(b, rumble, 0.0, 0.45)
	# The halberd drawn back: a rising metal scrape, ringing as it ends.
	var draw_at: float = maxf(_warning() - SentinelScript.RAISE_SECONDS, 0.0)
	var scrape := DSP.noise(SentinelScript.RAISE_SECONDS, rng)
	DSP.filter_sweep(scrape, &"bandpass", 1800.0, 5200.0, 4.0)
	DSP.shape(scrape, 0.12, 0.08)
	DSP.mix(b, scrape, draw_at, 0.55)
	DSP.mix(b, DSP.metal_hit(0.45, 1320.0, 0.18, rng), draw_at + SentinelScript.RAISE_SECONDS * 0.85, 0.25)
	DSP.drive(b, 1.6)
	DSP.crush(b, 10, 16000.0)
	return b


## The swing: the blade's ring as it starts, a fast heavy whoosh through its sweep, and a stone thud.
func _swing() -> PackedFloat32Array:
	var rng := _rng(1102)
	var length: float = 0.7
	var b := _whoosh(0.42, 260.0, 1900.0, 1.4, rng)
	var low := _whoosh(0.42, 120.0, 420.0, 1.0, rng)
	DSP.mix(b, low, 0.0, 0.9)
	var out := DSP.buffer(length)
	DSP.mix(out, b, 0.0, 1.4)
	DSP.mix(out, DSP.metal_hit(0.6, 980.0, 0.22, rng), 0.0, 0.45)
	var thud := _boom(0.4, 110.0, 50.0, 0.09, rng)
	DSP.mix(out, thud, 0.12, 0.6)
	DSP.drive(out, 1.5)
	DSP.crush(out, 10, 20000.0)
	return out


## Breaking: stone cracking and crumbling, gold pieces clattering down, a dull thump.
func _break() -> PackedFloat32Array:
	var rng := _rng(1103)
	var length: float = 1.1
	var b := _boom(length, 95.0, 40.0, 0.18, rng)
	var crumble := DSP.noise(length, rng)
	DSP.filter_sweep(crumble, &"lowpass", 3200.0, 300.0, 0.8)
	DSP.envelope(crumble, 0.004, 0.35, 0.05)
	DSP.mix(b, crumble, 0.0, 1.0)
	DSP.mix(b, _crackle(length, 70, 0.4, 2200.0, rng), 0.0, 1.0)
	for k: int in 5:
		var at: float = 0.08 + 0.13 * k + rng.randf_range(0.0, 0.05)
		DSP.mix(b, DSP.metal_hit(0.35, rng.randf_range(780.0, 1500.0), 0.12, rng), at, 0.32 * exp(-0.3 * k))
	DSP.drive(b, 1.8)
	DSP.crush(b, 9, 18000.0)
	return b
