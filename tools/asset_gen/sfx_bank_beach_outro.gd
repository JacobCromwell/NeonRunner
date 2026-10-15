extends "res://tools/asset_gen/sfx_bank.gd"
## The Beach outro's own sounds (BeachOutro), in the same crunchy 16-bit style as the rest (neither is a warning; like
## every sound effect, each is under 2.5 s). The rest of its sounds are the game's: the defeat's guppy_leap and
## guppy_swim, the screech's chirp, the cult's chime (gc_chime) and the refill ship's engines (gc_ship), the bombs'
## whistle and blast, the pool's splash.
##   bar_shaker  the bartender shaking the drinks: ice rattling in a steel shaker, back and forth in quick strokes,
##               the steel ringing a little
##   bar_glass   the two drinks set down on the counter: two glass clinks on wood, the ice settling


func sounds() -> Dictionary:
	return {
		"bar_shaker": _shaker,
		"bar_glass": _glass,
	}


## Ice in a steel shaker: each stroke a burst of hard little ticks (bandpassed noise grains, the ice) over a short
## swish, two strokes a beat, with a faint steel ring under them.
func _shaker() -> PackedFloat32Array:
	var rng := _rng(2201)
	var d: float = 1.6
	var b := DSP.buffer(d)
	var stroke: float = 0.13
	var at: float = 0.02
	var k: int = 0
	while at < d - 0.12:
		var swish := DSP.noise(0.09, rng)
		DSP.filter(swish, &"bandpass", 2600.0 if k % 2 == 0 else 3300.0, 1.2)
		DSP.envelope(swish, 0.01, 0.03)
		DSP.mix(b, swish, at, 0.35)
		for g: int in 7:
			var tick := DSP.noise(0.006, rng)
			DSP.filter(tick, &"bandpass", rng.randf_range(3500.0, 6500.0), 2.0)
			DSP.envelope(tick, 0.0005, 0.002)
			DSP.mix(b, tick, at + 0.04 + rng.randf_range(0.0, 0.05), rng.randf_range(0.5, 0.9))
		var ring := DSP.metal_hit(0.08, 1850.0 + 90.0 * float(k % 3), 0.02, rng)
		DSP.filter(ring, &"highpass", 900.0)
		DSP.mix(b, ring, at + 0.05, 0.12)
		at += stroke
		k += 1
	DSP.shape(b, 0.02, 0.15)
	DSP.filter(b, &"highpass", 700.0)
	DSP.crush(b, 11, 22000.0)
	return b


## Two glass clinks on wood (a bright FM ping over a soft knock), a little apart, and the ice settling after.
func _glass() -> PackedFloat32Array:
	var rng := _rng(2202)
	var d: float = 0.9
	var b := DSP.buffer(d)
	for k: int in 2:
		var knock := DSP.kick(0.06, 420.0, 260.0, rng)
		DSP.filter(knock, &"lowpass", 1600.0)
		DSP.mix(b, knock, 0.02 + k * 0.21, 0.35)
		var ping := _fm_note(0.4, 2900.0 + 380.0 * k, 2.7, 1.8, 0.4, 0.09)
		DSP.mix(b, ping, 0.02 + k * 0.21, 0.32)
	for g: int in 10:
		var tick := DSP.noise(0.005, rng)
		DSP.filter(tick, &"bandpass", rng.randf_range(3000.0, 6000.0), 2.0)
		DSP.envelope(tick, 0.0005, 0.002)
		DSP.mix(b, tick, rng.randf_range(0.28, 0.6), rng.randf_range(0.15, 0.35))
	DSP.filter(b, &"highpass", 250.0)
	DSP.crush(b, 11, 24000.0)
	return b
