extends "res://tools/asset_gen/sfx_bank_bosses.gd"
## The City intro's own sounds (CityIntro; the owner's October 16, 2026 beats), in the same crunchy 16-bit style as the rest
## (none is a warning; like every sound effect, each is under 2.5 s). It builds on the bosses' bank for the Floating Head's
## propaganda voice (syllables through the loudhailer): its sounds() lists only these four. The rest of the intro's sounds are the
## game's: the runner's jump and land, the stomp and a cyborg's death.
##   window_smash   a pane of glass bursting: a hard crack and a spray of glass, a cascade of bright tinkles as the shards fly and
##                  land on the road, a few heavier pieces knocking
##   head_startle   the Floating Head startled: a sharp gasp through its loudhailer voice, a surge of power under it
##   head_yell      the Head yelling at the cyborgs: a long, hoarse, blown-out shout of its announcer's voice, climbing to a held
##                  vowel and tearing (its picture breaking up), the street's echoes
##   feed_surge     the yell going through the feed: every cyborg's screen at once surging into static, a stuttering burst
##                  of noise and a detuned hum rising, then locking onto a hard tone


func sounds() -> Dictionary:
	return {
		"window_smash": _window_smash,
		"head_startle": _head_startle,
		"head_yell": _head_yell,
		"feed_surge": _feed_surge,
	}


## A pane of glass bursting (1.5 s): the crack (a hard noise click and a high ring), then the spray: dozens of little bright pings
## at random high pitches thinning out over about a second, with a few lower knocks of bigger pieces, and a rattle of grit.
func _window_smash() -> PackedFloat32Array:
	var rng := _rng(2301)
	var d: float = 1.5
	var b := DSP.buffer(d)
	var crack := DSP.noise(0.09, rng)
	DSP.filter(crack, &"highpass", 1800.0)
	DSP.envelope(crack, 0.0005, 0.018)
	DSP.mix(b, crack, 0.0, 1.0)
	var thump := DSP.kick(0.12, 260.0, 90.0, rng)
	DSP.mix(b, thump, 0.0, 0.55)
	var ring := _fm_note(0.5, 3100.0, 2.7, 2.2, 0.4, 0.12)
	DSP.mix(b, ring, 0.0, 0.3)
	# The spray: pings, more at first.
	for k: int in 46:
		var u: float = pow(rng.randf(), 1.7)
		var at: float = 0.03 + u * 1.05
		var hz: float = rng.randf_range(2400.0, 7200.0)
		var ping := _fm_note(0.18, hz, rng.randf_range(2.1, 3.6), rng.randf_range(0.8, 1.8), 0.2, rng.randf_range(0.02, 0.06))
		DSP.mix(b, ping, at, rng.randf_range(0.1, 0.32) * (1.0 - 0.6 * u))
	# Heavier pieces knocking as they land.
	for k: int in 7:
		var at: float = 0.12 + rng.randf() * 0.9
		var knock := DSP.metal_hit(0.1, rng.randf_range(700.0, 1700.0), 0.03, rng)
		DSP.filter(knock, &"highpass", 500.0)
		DSP.mix(b, knock, at, rng.randf_range(0.15, 0.35))
	DSP.mix(b, _crackle(d, 60, 0.45, 4200.0, rng), 0.0, 0.5)
	DSP.shape(b, 0.001, 0.2)
	DSP.crush(b, 9, 22000.0)
	return b


## The Head startled (0.7 s): a sharp gasp (a vowel jumping up in pitch through the loudhailer), the power surging under it with a
## rising whine and a few sparks.
func _head_startle() -> PackedFloat32Array:
	var rng := _rng(2302)
	var gasp := _syllables([[0.3, 168.0, 330.0, &"a", &"ae", &"k"]], 0.4, rng)
	var b := DSP.buffer(0.7)
	DSP.mix(b, _loudhailer(gasp, rng), 0.0, 1.0)
	var surge := DSP.osc(0.45, func(u: float) -> float: return DSP.sweep(160.0, 900.0, pow(u, 1.4)), &"saw")
	DSP.filter(surge, &"lowpass", 2400.0)
	DSP.drive(surge, 2.5)
	DSP.envelope(surge, 0.005, 0.25)
	DSP.mix(b, surge, 0.0, 0.35)
	DSP.mix(b, _crackle(0.4, 18, 0.3, 3000.0, rng), 0.02, 0.5)
	DSP.crush(b, 9, 20000.0)
	return b


## The Head's yell (2.2 s): its announcer's voice shouting in the hoarse, blown-out loudhailer: a hard attack, a held, wide-open
## vowel climbing, then tearing down into static as the picture breaks up, with a growl under it.
func _head_yell() -> PackedFloat32Array:
	var rng := _rng(2303)
	var shout := _syllables([[0.14, 150.0, 205.0, &"a", &"o", &"k"], [0.75, 205.0, 238.0, &"o", &"a", &""],
		[0.45, 236.0, 232.0, &"a", &"ae", &""], [0.5, 228.0, 120.0, &"ae", &"u", &""]], 0.4, rng)
	var b := _loudhailer(shout, rng)
	# Overdriven harder than the propaganda: it shouts.
	DSP.drive(b, 2.6)
	DSP.filter(b, &"lowpass", 4200.0)
	var growl := DSP.osc(2.2, func(u: float) -> float: return DSP.sweep(95.0, 60.0, u), &"square")
	DSP.filter(growl, &"lowpass", 320.0)
	DSP.adsr(growl, 0.05, 0.3, 0.7, 0.5)
	DSP.mix(b, growl, 0.1, 0.22)
	# Tearing at the end: stuttering static.
	var tear := DSP.noise(0.7, rng)
	DSP.filter(tear, &"bandpass", 3000.0, 0.8)
	DSP.crush(tear, 5, 6000.0)
	var n: int = tear.size()
	for i: int in n:
		var gate: float = step_gate(float(i) / RATE, 14.0, 0.55)
		tear[i] *= gate * smoothstep(0.0, 0.35, float(i) / n) * 0.6
	DSP.mix(b, tear, 1.3, 0.7)
	DSP.shape(b, 0.003, 0.25)
	return b


## The surge through the feed (0.9 s): a burst of static gated in rapid stutters, a detuned hum rising and splitting, then
## a hard tone as the screens lock on the angry face.
func _feed_surge() -> PackedFloat32Array:
	var rng := _rng(2304)
	var d: float = 0.9
	var b := DSP.buffer(d)
	var stat := DSP.noise(0.5, rng)
	DSP.filter(stat, &"bandpass", 2600.0, 0.6)
	DSP.crush(stat, 5, 8000.0)
	var n: int = stat.size()
	for i: int in n:
		stat[i] *= step_gate(float(i) / RATE, 16.0, 0.6)
	DSP.mix(b, stat, 0.0, 0.7)
	for hz: float in [110.0, 114.0, 220.0]:
		var hum := DSP.osc(0.6, func(u: float) -> float: return hz * lerpf(1.0, 2.2, u * u), &"saw")
		DSP.filter(hum, &"lowpass", 1600.0)
		DSP.envelope(hum, 0.03, 0.4)
		DSP.mix(b, hum, 0.05, 0.25)
	var lock := DSP.osc(0.3, func(_u: float) -> float: return 1760.0, &"square")
	DSP.filter(lock, &"lowpass", 3000.0)
	DSP.envelope(lock, 0.002, 0.07)
	DSP.mix(b, lock, 0.5, 0.35)
	DSP.shape(b, 0.002, 0.15)
	DSP.crush(b, 8, 16000.0)
	return b


## A square gate: 1 in the first `duty` of each period of `hz`, 0.15 in the rest.
func step_gate(t: float, hz: float, duty: float) -> float:
	return 1.0 if fmod(t * hz, 1.0) < duty else 0.15
