extends "res://tools/asset_gen/sfx_bank.gd"
## The Enforcer Truck's sounds (GDD §9.13), in the game's 16-bit style. It drives behind the camera, so all of
## them play for everyone to hear (none positional), and each warns as well as the floor shows:
##   enforcer_siren   its arrival: two police whoops rising over a diesel's growl, and a short horn blast
##   enforcer_whine   a volley's warning: its laser emitters charging, a whine rising from a hum to a scream
##                    with a ticking that speeds up, as long as the warning (warning_seconds, read from its
##                    tuning; the truck stretches it by pitch to match if the tuning changes)
##   enforcer_laser   one shot of a volley: a hard electric zap snapping down the lane, with a crack
##   enforcer_pickup  a cyborg climbing aboard: a boot on steel, a hatch clanking, a radio's squelch and chirp
##   enforcer_crash   wrecked (a hole, a charge): brakes screaming, a nose-first crunch of steel, a deep boom
##                    and debris, as it's hit
## However it's destroyed, its wreck blows up in view a moment later like the other vehicles (truck_explode).

const TUNING_PATH: String = "res://data/enemies/enforcer_truck.tres"


func sounds() -> Dictionary:
	return {
		"enforcer_siren": _siren,
		"enforcer_whine": _whine,
		"enforcer_laser": _laser,
		"enforcer_pickup": _pickup,
		"enforcer_crash": _crash,
	}


## Its volley's warning in seconds (1 s if the tuning can't be read).
static func warning_time() -> float:
	var t: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	if t == null or t.get("warning_seconds") == null:
		return 1.0
	return float(t.get("warning_seconds"))


## Its arrival: two siren whoops (a square wave sweeping up through a band-pass, as a police yelp), a diesel's
## growl under them, and a blast of its horn to end.
func _siren() -> PackedFloat32Array:
	var rng := _rng(1301)
	var d: float = 1.7
	var b := DSP.buffer(d)
	for k: int in 2:
		var whoop := DSP.osc(0.55, func(u: float) -> float: return DSP.sweep(420.0, 1350.0, pow(u, 0.7)), &"square")
		DSP.filter(whoop, &"bandpass", 1100.0, 0.9)
		DSP.adsr(whoop, 0.02, 0.15, 0.8, 0.08)
		DSP.mix(b, whoop, k * 0.5, 0.55)
	var engine := DSP.osc(d, func(u: float) -> float: return 48.0 + 14.0 * u, &"saw")
	DSP.filter(engine, &"lowpass", 300.0)
	DSP.adsr(engine, 0.1, 0.2, 0.7, 0.3)
	DSP.mix(b, engine, 0.0, 0.45)
	var growl := DSP.noise(d, rng)
	DSP.filter(growl, &"bandpass", 180.0, 1.2)
	DSP.adsr(growl, 0.1, 0.3, 0.5, 0.3)
	DSP.mix(b, growl, 0.0, 0.3)
	var horn := DSP.osc(0.45, func(_u: float) -> float: return 233.0, &"saw")
	DSP.mix(horn, DSP.osc(0.45, func(_u: float) -> float: return 277.0, &"saw"), 0.0, 0.8)
	DSP.filter(horn, &"lowpass", 1800.0)
	DSP.adsr(horn, 0.01, 0.05, 0.85, 0.12)
	DSP.mix(b, horn, 1.15, 0.5)
	DSP.drive(b, 1.6)
	DSP.crush(b, 10, 22000.0)
	return b


## A volley's warning: its emitters charging, a saw whine rising from a hum to a scream, a ringing tone over
## it, and a tick speeding up to the shot.
func _whine() -> PackedFloat32Array:
	var rng := _rng(1302)
	var d: float = clampf(warning_time(), 0.5, 2.4)
	var b := DSP.buffer(d)
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(240.0, 2600.0, u * u), &"saw")
	DSP.filter(whine, &"bandpass", 1500.0, 1.0)
	DSP.adsr(whine, 0.1, 0.05, 0.95, 0.02)
	DSP.mix(b, whine, 0.0, 0.55)
	var ring := DSP.osc(d, func(u: float) -> float: return DSP.sweep(900.0, 3100.0, u), &"sine")
	DSP.adsr(ring, 0.3, 0.1, 0.8, 0.02)
	DSP.mix(b, ring, 0.0, 0.2)
	var hum := DSP.noise(d, rng)
	DSP.filter_sweep(hum, &"bandpass", 400.0, 3000.0, 2.5)
	DSP.adsr(hum, 0.05, 0.2, 0.7, 0.02)
	DSP.mix(b, hum, 0.0, 0.2)
	var t: float = 0.0
	var gap: float = 0.14
	while t < d - 0.04:
		DSP.mix(b, _blip(0.025, 3000.0, 0.25, 0.015), t, 0.28)
		t += gap
		gap = maxf(gap * 0.78, 0.04)
	DSP.crush(b, 10, 22000.0)
	return b


## One shot: an electric zap falling fast in pitch (FM, so it buzzes), a crack of noise at its front.
func _laser() -> PackedFloat32Array:
	var rng := _rng(1303)
	var d: float = 0.32
	var b := DSP.fm(d, func(u: float) -> float: return DSP.sweep(2400.0, 380.0, pow(u, 0.5)), 1.5,
		func(u: float) -> float: return 3.0 * exp(-u * 4.0))
	DSP.envelope(b, 0.001, 0.12, 0.02)
	var crack := DSP.noise(0.06, rng)
	DSP.filter(crack, &"highpass", 2500.0)
	DSP.envelope(crack, 0.001, 0.02)
	DSP.mix(b, crack, 0.0, 0.5)
	DSP.drive(b, 1.4)
	DSP.crush(b, 9, 21000.0)
	return b


## A rider climbing aboard: a boot on the steel roof, its hatch clanking shut, a radio squelch and a chirp.
func _pickup() -> PackedFloat32Array:
	var rng := _rng(1304)
	var d: float = 0.75
	var b := DSP.buffer(d)
	DSP.mix(b, DSP.metal_hit(0.3, 160.0, 0.12, rng), 0.0, 0.6)
	DSP.mix(b, DSP.metal_hit(0.35, 230.0, 0.2, rng), 0.16, 0.7)
	var squelch := DSP.noise(0.18, rng)
	DSP.filter(squelch, &"bandpass", 1800.0, 2.0)
	DSP.adsr(squelch, 0.005, 0.05, 0.6, 0.05)
	DSP.mix(b, squelch, 0.38, 0.35)
	DSP.mix(b, _blip(0.07, 1760.0, 0.5, 0.04), 0.56, 0.35)
	DSP.mix(b, _blip(0.07, 2350.0, 0.5, 0.04), 0.63, 0.35)
	DSP.crush(b, 10, 22000.0)
	return b


## Wrecked (a hole, a charge): brakes screaming, a nose-first crunch of steel, a deep boom and a clatter of debris.
func _crash() -> PackedFloat32Array:
	var rng := _rng(1305)
	var d: float = 1.5
	var b := DSP.buffer(d)
	var brakes := DSP.osc(0.4, func(u: float) -> float: return DSP.sweep(2100.0, 1500.0, u), &"square")
	DSP.filter(brakes, &"bandpass", 1800.0, 3.0)
	DSP.adsr(brakes, 0.02, 0.1, 0.7, 0.1)
	DSP.mix(b, brakes, 0.0, 0.3)
	DSP.mix(b, _boom(1.1, 110.0, 32.0, 0.35, rng), 0.3, 1.0)
	DSP.mix(b, DSP.metal_hit(0.8, 88.0, 0.35, rng), 0.3, 0.8)
	DSP.mix(b, DSP.metal_hit(0.6, 151.0, 0.25, rng), 0.34, 0.5)
	var crunch := DSP.noise(0.6, rng)
	DSP.filter(crunch, &"bandpass", 700.0, 0.6)
	DSP.adsr(crunch, 0.005, 0.15, 0.35, 0.3)
	DSP.mix(b, crunch, 0.3, 0.6)
	for i: int in 5:
		DSP.mix(b, DSP.metal_hit(0.15, rng.randf_range(400.0, 900.0), 0.05, rng), 0.75 + i * 0.12, 0.2)
	DSP.crush(b, 9, 21000.0)
	return b
