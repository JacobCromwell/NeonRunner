extends "res://tools/asset_gen/sfx_bank.gd"
## The Buzz Overdrive's sounds (GDD §9.9), in the game's 16-bit style:
##   buzz_rev     the warning: its diesel coughs and climbs while the giant blade spins up, a metallic
##                whine rising from a low hum to a scream (GDD §9.9: "a spin-up noise as its blade spins
##                up"). It lasts its rev where it first appears (Corporate 1, BuzzOverdriveTuning.rev_at
##                at that level's enemy scaling), so it ends as the charge starts there; later levels
##                rev a little faster and the charge comes in over its last moments.
##   buzz_charge  the attack: the blade at full speed tearing into the floor, a grinding shriek over the
##                engine's roar, dropping in pitch as it passes the player
## Its death is the hover truck's explosion (truck_explode): vehicles blow up alike.

const TUNING_PATH: String = "res://data/enemies/buzz_overdrive.tres"
## Corporate 1's enemy scaling (level 9 of 15): where the rev is heard first and longest.
const FIRST_SCALING: float = 8.0 / 14.0


func sounds() -> Dictionary:
	return {
		"buzz_rev": _buzz_rev,
		"buzz_charge": _buzz_charge,
	}


## The rev's length where the tank first appears (2.93 s if the tuning can't be read).
static func rev_time() -> float:
	var t: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	if t == null or t.get("rev_seconds_early") == null:
		return 2.93
	return lerpf(float(t.get("rev_seconds_early")), float(t.get("rev_seconds_late")), FIRST_SCALING)


## The warning: a diesel cough and a climbing growl under the blade's whine, which rises from a hum to
## a scream and swells, with a ringing metallic edge (inharmonic partials) as it reaches speed.
func _buzz_rev() -> PackedFloat32Array:
	var rng := _rng(1201)
	var d: float = rev_time() + 0.05
	var b := DSP.buffer(d)
	var n: int = b.size()
	# The engine: firing strokes from a lumpy idle up to a hard rev, barking through the exhaust.
	var engine := DSP.buffer(d)
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		var rpm: float = 0.1 + 0.9 * smoothstep(0.05, 0.85, u)
		phase += lerpf(26.0, 92.0, rpm) / RATE
		var p: float = fmod(phase, 1.0)
		var bark: float = exp(-p * lerpf(8.0, 3.5, rpm))
		engine[i] = ((p * 2.0 - 1.0) * 0.55 + rng.randf_range(-1.0, 1.0) * bark * 0.4) * (0.4 + 0.6 * bark) * (0.5 + 0.5 * rpm)
	DSP.drive(engine, 3.2, 0.08)
	DSP.filter(engine, &"lowpass", 1400.0)
	DSP.mix(b, engine, 0.0, 0.55)
	# The blade: a saw-tooth whine and its fifth, rising from 140 Hz to 1.7 kHz with the spin.
	var whine := DSP.osc(d, func(u: float) -> float: return DSP.sweep(140.0, 1700.0, pow(u, 0.8)), &"saw")
	var fifth := DSP.osc(d, func(u: float) -> float: return DSP.sweep(210.0, 2550.0, pow(u, 0.8)), &"square")
	DSP.mix(whine, fifth, 0.0, 0.35)
	DSP.filter(whine, &"lowpass", 5200.0)
	for i: int in n:
		var u: float = float(i) / n
		# Teeth passing: a flutter that speeds up with the blade.
		var flutter: float = 0.75 + 0.25 * sin(TAU * lerpf(6.0, 60.0, u * u) * float(i) / RATE)
		whine[i] *= (0.15 + 0.85 * u * u) * flutter
	DSP.mix(b, whine, 0.0, 0.7)
	# The ring of a big steel disc at speed: inharmonic partials swelling in over the last third.
	var ring := DSP.buffer(d)
	for k: int in 3:
		var hz: float = [2370.0, 3410.0, 4890.0][k]
		var part := DSP.osc(d, func(u: float) -> float: return hz * (0.92 + 0.08 * u), &"sine")
		DSP.mix(ring, part, 0.0, [0.5, 0.3, 0.2][k])
	for i: int in n:
		var u: float = float(i) / n
		ring[i] *= smoothstep(0.55, 1.0, u)
	DSP.mix(b, ring, 0.0, 0.22)
	# A clank as the drive engages.
	DSP.mix(b, DSP.metal_hit(0.3, 180.0, 0.1, rng), 0.02, 0.45)
	DSP.shape(b, 0.01, 0.04)
	DSP.crush(b, 9, 20000.0)
	return b


## The attack: the blade at full speed tearing into the floor (a grinding, shrieking scream with
## noise bursts), the engine roaring under it, and the whole sound dropping in pitch as it passes.
func _buzz_charge() -> PackedFloat32Array:
	var rng := _rng(1202)
	var d: float = 1.6
	var b := DSP.buffer(d)
	var n: int = b.size()
	# The pass: full pitch until it reaches the player (about 1 s), then a drop of a fifth.
	var pitch := func(u: float) -> float:
		var t: float = u * d
		return 1.0 if t < 0.95 else lerpf(1.0, 0.66, smoothstep(0.95, 1.35, t))
	var scream := DSP.osc(d, func(u: float) -> float: return 1700.0 * float(pitch.call(u)), &"saw")
	var upper := DSP.osc(d, func(u: float) -> float: return 2550.0 * float(pitch.call(u)), &"square")
	DSP.mix(scream, upper, 0.0, 0.3)
	DSP.filter(scream, &"lowpass", 6000.0)
	DSP.mix(b, scream, 0.0, 0.5)
	# Grinding: bright noise in bursts as the teeth bite.
	var grind := DSP.noise(d, rng)
	DSP.filter(grind, &"bandpass", 3200.0, 0.9)
	var gate: float = 0.0
	for i: int in n:
		if i % 220 == 0:
			gate = rng.randf_range(0.35, 1.0)
		grind[i] *= gate
	DSP.mix(b, grind, 0.0, 0.55)
	# The engine at full roar.
	var roar := DSP.noise(d, rng)
	DSP.filter(roar, &"lowpass", 420.0)
	DSP.drive(roar, 4.0)
	DSP.mix(b, roar, 0.0, 0.6)
	var hum := DSP.osc(d, func(u: float) -> float: return 70.0 * float(pitch.call(u)), &"saw")
	DSP.filter(hum, &"lowpass", 600.0)
	DSP.mix(b, hum, 0.0, 0.4)
	# Swell in, and fade away behind the player.
	for i: int in n:
		var t: float = float(i) / RATE
		b[i] *= smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(1.05, d, t) * 0.92)
	DSP.drive(b, 1.8)
	DSP.crush(b, 9, 18000.0)
	return b
