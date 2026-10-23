extends "res://tools/asset_gen/sfx_bank.gd"
## The falling gantryways' sounds (task Q3; GDD §5, Zone 9, proposed: "before it drops, it warns as every attack must: a
## groan and a creak of steel"), in the game's 16-bit style:
##   gantry_creak  its warning as its pillar goes (Gantryway.fall, at the pillar): a deep groan of steel bending (a low
##                 buzzing tone sagging in pitch through a resonant band), a high creak over it (stick-slip friction,
##                 a squeal stuttering faster), a couple of rivets popping and a hiss of snow sliding off. CREAK_LENGTH
##                 long: about the fall (GantrywayTuning.fall_seconds, 1 s), its groan sinking as the walkway drops
##   gantry_land   its landing (Gantryway, where it lands nearest the camera): a heavy steel crash on the floor, a deep
##                 boom with a clang of girders, plates rattling flat and a whump of snow
## Its pillar's break is the dash's doodad crunch (RunWorld.EVENT_SOUNDS: gantry_pillar_smash plays doodad_smash).
## DESIGN-TBD (docs/questions/q3.md): the sounds.

## The warning's length (seconds): the fall's, so the groan carries until the walkway is down.
const CREAK_LENGTH: float = 1.0


func sounds() -> Dictionary:
	return {
		"gantry_creak": _creak,
		"gantry_land": _land,
	}


## Steel groaning as it bends: a buzzy tone that sags from `from_hz` to `to_hz` with a slow wobble, through a resonant
## band around `body_hz` (a girder's ring).
func _groan(seconds: float, from_hz: float, to_hz: float, body_hz: float) -> PackedFloat32Array:
	var b := DSP.osc(seconds, func(u: float) -> float:
		return DSP.sweep(from_hz, to_hz, u) * (1.0 + 0.03 * sin(TAU * 5.5 * u * seconds)), &"saw")
	var ring := b.duplicate()
	DSP.filter(ring, &"bandpass", body_hz, 3.0)
	DSP.filter(b, &"lowpass", 700.0)
	DSP.mix(b, ring, 0.0, 1.6)
	return b


## A creak: friction's stick-slip, a narrow squeal around `hz` chopped into grains that come faster (from `from_rate`
## to `to_rate` a second) as it gives.
func _squeal(seconds: float, hz: float, from_rate: float, to_rate: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	DSP.filter(b, &"bandpass", hz, 9.0)
	DSP.filter(b, &"bandpass", hz, 6.0)
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		phase = fmod(phase + DSP.sweep(from_rate, to_rate, u) / RATE, 1.0)
		# Each grain sticks (silent), then slips (a short burst).
		b[i] *= smoothstep(0.55, 0.62, phase) * (1.0 - smoothstep(0.85, 1.0, phase))
	return b


func _creak() -> PackedFloat32Array:
	var rng := _rng(1601)
	var d: float = CREAK_LENGTH
	var b := DSP.buffer(d)
	# The groan: the girders bending, sinking as the walkway goes.
	var groan := _groan(d, 95.0, 58.0, 420.0)
	DSP.envelope(groan, 0.04, 2.0, 0.12)
	DSP.mix(b, groan, 0.0, 0.85)
	# The creak over it, the friction coming faster as it gives.
	var squeal := _squeal(d * 0.8, 1450.0, 7.0, 19.0, rng)
	DSP.envelope(squeal, 0.02, 1.5, 0.1)
	DSP.mix(b, squeal, 0.04, 4.5)
	# Rivets popping.
	DSP.mix(b, DSP.metal_hit(0.25, 620.0, 0.05, rng), 0.0, 0.9)
	DSP.mix(b, DSP.metal_hit(0.25, 880.0, 0.04, rng), 0.31, 0.5)
	DSP.mix(b, DSP.metal_hit(0.25, 540.0, 0.05, rng), 0.58, 0.45)
	# Snow sliding off it.
	var snow := DSP.noise(d, rng)
	DSP.filter(snow, &"bandpass", 3200.0, 0.8)
	DSP.envelope(snow, 0.15, 0.5, 0.1)
	DSP.mix(b, snow, 0.0, 0.25)
	DSP.drive(b, 1.6)
	DSP.crush(b, 10, 22000.0)
	return b


func _land() -> PackedFloat32Array:
	var rng := _rng(1602)
	var d: float = 1.3
	var b := DSP.buffer(d)
	# The impact: a deep boom and the crash.
	DSP.mix(b, _boom(d, 90.0, 34.0, 0.3, rng), 0.0, 1.0)
	var crash := DSP.noise(d, rng)
	DSP.filter_sweep(crash, &"lowpass", 5200.0, 300.0, 0.8)
	DSP.envelope(crash, 0.002, 0.16, 0.05)
	DSP.mix(b, crash, 0.0, 1.1)
	# The girders clanging on the floor, low and heavy.
	DSP.mix(b, DSP.metal_hit(0.9, 150.0, 0.32, rng), 0.0, 0.8)
	DSP.mix(b, DSP.metal_hit(0.7, 233.0, 0.22, rng), 0.03, 0.55)
	# Plates and rails rattling flat after it.
	for k: int in 6:
		var at: float = 0.08 + 0.07 * k + rng.randf_range(0.0, 0.03)
		DSP.mix(b, DSP.metal_hit(0.3, rng.randf_range(380.0, 900.0), 0.06, rng), at, 0.4 * exp(-float(k) * 0.3))
	# A whump of snow thrown up.
	var snow := DSP.noise(0.6, rng)
	DSP.filter(snow, &"bandpass", 900.0, 0.7)
	DSP.envelope(snow, 0.01, 0.15, 0.05)
	DSP.mix(b, snow, 0.0, 0.6)
	DSP.mix(b, _crackle(d, 28, 0.35, 2600.0, rng), 0.02, 0.45)
	DSP.drive(b, 1.9)
	DSP.crush(b, 9, 20000.0)
	return b
