extends "res://tools/asset_gen/sfx_bank.gd"
## The mini-games' own sounds (the Beach's volleyball match, VolleyballMatch), where the game's don't fit (GDD §11: new
## sound effects are fine where the existing ones don't cover a moment; only new music is off). In the game's crunchy
## 16-bit style. None of them is a hazard's warning, and no warning is reused, so the warnings keep their meaning:
##   volley_hit      a hand slapping a volleyball: a hollow, rubbery thump with a slap on top (each hit, the
##                   rival's and the runner's; the rival's tells the runner a ball is on its way)
##   volley_bounce   the ball thudding into soft sand: a dull low thump and a puff of grains (a miss, a winner)
##   volley_whistle  a referee's whistle: a short trilled pea whistle (each point's end)


func sounds() -> Dictionary:
	return {
		"volley_hit": _hit,
		"volley_bounce": _bounce,
		"volley_whistle": _whistle,
	}


## A hand on the ball (0.35 s): a hollow thump that drops in pitch (the ball's air), a sharp slap of skin on
## leather on top, crushed a little.
func _hit() -> PackedFloat32Array:
	var rng := _rng(3101)
	var d: float = 0.35
	var b := DSP.buffer(d)
	var thump := DSP.osc(d, func(u: float) -> float: return 240.0 + 280.0 * exp(-u * d / 0.025))
	DSP.envelope(thump, 0.001, 0.055)
	DSP.mix(b, thump, 0.0, 0.8)
	# The ball's ring, an octave and a bit up: what a phone speaker plays of it.
	var body := DSP.osc(d, func(u: float) -> float: return 760.0 + 180.0 * exp(-u * d / 0.02), &"triangle")
	DSP.envelope(body, 0.001, 0.04)
	DSP.mix(b, body, 0.0, 0.55)
	var slap := DSP.noise(0.06, rng)
	DSP.filter(slap, &"bandpass", 2600.0, 0.9)
	DSP.envelope(slap, 0.0005, 0.014)
	DSP.mix(b, slap, 0.0, 1.6)
	DSP.drive(b, 1.6)
	DSP.crush(b, 11, 22000.0)
	return b


## The ball into sand (0.45 s): a dull low thump, soft at the front (sand gives), and a short puff of grains.
func _bounce() -> PackedFloat32Array:
	var rng := _rng(3102)
	var d: float = 0.45
	var b := DSP.buffer(d)
	var thud := DSP.osc(d, func(u: float) -> float: return 130.0 + 110.0 * exp(-u * d / 0.03))
	DSP.envelope(thud, 0.004, 0.07)
	DSP.mix(b, thud, 0.0, 1.0)
	var puff := DSP.noise(0.3, rng)
	DSP.filter_sweep(puff, &"bandpass", 3200.0, 1400.0, 0.6)
	DSP.envelope(puff, 0.003, 0.07)
	DSP.mix(b, puff, 0.005, 0.8)
	DSP.mix(b, _crackle(0.3, 14, 0.08, 4200.0, rng), 0.01, 0.25)
	DSP.drive(b, 1.4)
	DSP.crush(b, 11, 20000.0)
	return b


## A referee's pea whistle (0.6 s): a bright tone near 3 kHz trilled by the pea (a fast warble in pitch and level),
## with breath noise, a quick attack and release.
func _whistle() -> PackedFloat32Array:
	var rng := _rng(3103)
	var d: float = 0.6
	var b := DSP.osc(d, func(u: float) -> float:
		var t: float = u * d
		return 2950.0 + 140.0 * sin(TAU * 32.0 * t) + 60.0 * sin(TAU * 7.0 * t))
	var n: int = b.size()
	for i: int in n:
		var t: float = float(i) / RATE
		b[i] *= 0.75 + 0.25 * sin(TAU * 32.0 * t)
	var breath := DSP.noise(d, rng)
	DSP.filter(breath, &"bandpass", 3000.0, 1.2)
	DSP.mix(b, breath, 0.0, 0.25)
	DSP.shape(b, 0.015, 0.06)
	DSP.crush(b, 12, 24000.0)
	return b
