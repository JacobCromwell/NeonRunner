extends "res://tools/asset_gen/sfx_bank.gd"
## The Hunter's sounds (task S2; GDD §9.17: a lab creation on a hover disc with red scimitars on its arms; every attack
## warns with a sound as well as a look, CLAUDE.md), in the game's 16-bit style:
##   hunter_whine    its arrival (and its coming up again after making room or a teleport): its hover disc's turbine
##                   spinning up from behind, a whine rising over a pulsing thrum and a jet's hiss. Not positional: it
##                   comes from behind the camera, so everyone hears it
##   hunter_scrape   a flurry's warning (Hunter._warn, positional, beside the runner): both blades raised and drawn
##                   across each other, a steel-on-steel scrape rising in pitch with a ringing shing at each end, as long
##                   as the warning (HunterTuning.warning_seconds, read from its data)
##   hunter_slash    the flurry itself: quick swishes of the blades through the lane, one a cut (HunterTuning.cuts over
##                   flurry_seconds), each with a bright metal tick
##   hunter_give_up  giving up (GDD §9.17: it follows about as long as the Enforcer Truck): its turbine winding down, the
##                   whine falling away behind
##   hunter_death    destroyed (a walkway landing on it, weapons): a crunch of its disc, its turbine failing in sputters
##                   and a small blast
## DESIGN-TBD (docs/questions/s2.md): the sounds.

const TUNING_PATH: String = "res://data/enemies/hunter.tres"


func sounds() -> Dictionary:
	return {
		"hunter_whine": _whine,
		"hunter_scrape": _scrape,
		"hunter_slash": _slash,
		"hunter_give_up": _give_up,
		"hunter_death": _death,
	}


## A number of its tuning (`fallback` if the data can't be read).
static func tuned(field: String, fallback: float) -> float:
	var t: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	if t == null or t.get(field) == null:
		return fallback
	return float(t.get(field))


## Its hover turbine at a pitch running from `from_hz` to `to_hz` (a buzzy saw through a resonant band, a sine an octave
## up), pulsing at `thrum_hz` (the disc's fans beating).
func _turbine(seconds: float, from_hz: float, to_hz: float, thrum_hz: float) -> PackedFloat32Array:
	var b := DSP.osc(seconds, func(u: float) -> float: return DSP.sweep(from_hz, to_hz, u), &"saw")
	DSP.filter(b, &"bandpass", (from_hz + to_hz) * 0.9, 1.2)
	var high := DSP.osc(seconds, func(u: float) -> float: return DSP.sweep(from_hz, to_hz, u) * 2.01)
	DSP.mix(b, high, 0.0, 0.35)
	var n: int = b.size()
	for i: int in n:
		var t: float = float(i) / RATE
		b[i] *= 0.75 + 0.25 * sin(TAU * thrum_hz * t)
	return b


## Its arrival: the turbine spinning up from behind, a jet's hiss rising with it.
func _whine() -> PackedFloat32Array:
	var rng := _rng(1901)
	var d: float = 1.3
	var b := DSP.buffer(d)
	var turbine := _turbine(d, 260.0, 1250.0, 16.0)
	DSP.adsr(turbine, 0.45, 0.2, 0.85, 0.35)
	DSP.mix(b, turbine, 0.0, 0.8)
	var hiss := DSP.noise(d, rng)
	DSP.filter_sweep(hiss, &"bandpass", 700.0, 4200.0, 1.6)
	DSP.adsr(hiss, 0.5, 0.2, 0.7, 0.3)
	DSP.mix(b, hiss, 0.0, 0.35)
	var thrum := DSP.osc(d, func(u: float) -> float: return DSP.sweep(55.0, 90.0, u), &"square")
	DSP.filter(thrum, &"lowpass", 260.0)
	DSP.adsr(thrum, 0.3, 0.2, 0.7, 0.3)
	DSP.mix(b, thrum, 0.0, 0.3)
	DSP.drive(b, 1.5)
	DSP.crush(b, 10, 22000.0)
	return b


## A flurry's warning: the blades drawn across each other, a grainy steel scrape climbing through a narrow band, a ring
## swelling under it, a shing as they part at the start and a sharper one as they come up to cut.
func _scrape() -> PackedFloat32Array:
	var rng := _rng(1902)
	var d: float = clampf(tuned("warning_seconds", 0.85), 0.4, 2.0)
	var b := DSP.buffer(d)
	var scrape := DSP.noise(d, rng)
	DSP.filter_sweep(scrape, &"bandpass", 1700.0, 4300.0, 7.0)
	var n: int = scrape.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		# The steel catching and slipping: grains coming faster as the scrape speeds up.
		phase = fmod(phase + DSP.sweep(22.0, 60.0, u) / RATE, 1.0)
		scrape[i] *= 0.45 + 0.55 * smoothstep(0.0, 0.3, phase) * (1.0 - smoothstep(0.6, 1.0, phase))
	DSP.adsr(scrape, 0.05, 0.1, 0.9, 0.04)
	DSP.mix(b, scrape, 0.0, 2.6)
	var ring := DSP.osc(d, func(u: float) -> float: return DSP.sweep(2300.0, 3150.0, u))
	DSP.mix(ring, DSP.osc(d, func(u: float) -> float: return DSP.sweep(3170.0, 4400.0, u)), 0.0, 0.5)
	DSP.adsr(ring, 0.3, 0.1, 0.9, 0.03)
	DSP.mix(b, ring, 0.0, 0.22)
	DSP.mix(b, DSP.metal_hit(0.3, 1900.0, 0.08, rng), 0.0, 0.7)
	DSP.mix(b, DSP.metal_hit(0.2, 2600.0, 0.05, rng), maxf(d - 0.14, 0.0), 0.8)
	DSP.drive(b, 1.4)
	DSP.crush(b, 10, 22000.0)
	return b


## The flurry: one swish of a blade for each cut, alternating high and low, each with a bright tick of steel.
func _slash() -> PackedFloat32Array:
	var rng := _rng(1903)
	var cuts: int = clampi(int(tuned("cuts", 4.0)), 1, 8)
	var span: float = clampf(tuned("flurry_seconds", 0.5), 0.15, 0.9)
	var each: float = span / cuts
	var d: float = span + 0.2
	var b := DSP.buffer(d)
	for k: int in cuts:
		var swish := _whoosh(maxf(each * 1.3, 0.08), 4200.0 if k % 2 == 0 else 3400.0, 650.0, 1.5, rng)
		DSP.mix(b, swish, k * each, 1.4)
		DSP.mix(b, DSP.metal_hit(0.12, 2900.0 - 300.0 * (k % 2), 0.03, rng), k * each + each * 0.45, 0.45)
	DSP.drive(b, 1.5)
	DSP.crush(b, 10, 22000.0)
	return b


## Giving up: the turbine winding down and the whine falling away, its thrum slowing.
func _give_up() -> PackedFloat32Array:
	var rng := _rng(1904)
	var d: float = 1.2
	var b := DSP.buffer(d)
	var turbine := _turbine(d, 1200.0, 210.0, 11.0)
	DSP.adsr(turbine, 0.02, 0.3, 0.7, 0.6)
	DSP.mix(b, turbine, 0.0, 0.8)
	var hiss := DSP.noise(d, rng)
	DSP.filter_sweep(hiss, &"bandpass", 3600.0, 600.0, 1.6)
	DSP.envelope(hiss, 0.02, 0.4, 0.2)
	DSP.mix(b, hiss, 0.0, 0.3)
	DSP.drive(b, 1.4)
	DSP.crush(b, 10, 22000.0)
	return b


## Destroyed: its disc crunching, its turbine failing in sputters, a small blast.
func _death() -> PackedFloat32Array:
	var rng := _rng(1905)
	var d: float = 1.3
	var b := _explosion(d, 0.6, rng)
	DSP.mix(b, DSP.metal_hit(0.5, 130.0, 0.2, rng), 0.0, 0.8)
	DSP.mix(b, DSP.metal_hit(0.4, 340.0, 0.12, rng), 0.03, 0.5)
	var fail := _turbine(0.9, 1100.0, 90.0, 9.0)
	var n: int = fail.size()
	for i: int in n:
		var t: float = float(i) / RATE
		# Sputtering: the turbine cutting out more and more.
		fail[i] *= 1.0 if fmod(t * DSP.sweep(18.0, 7.0, float(i) / n), 1.0) < lerpf(0.9, 0.35, float(i) / n) else 0.1
	DSP.envelope(fail, 0.01, 0.5, 0.1)
	DSP.mix(b, fail, 0.05, 0.5)
	DSP.crush(b, 9, 20000.0)
	return b
