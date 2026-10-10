extends "res://tools/asset_gen/sfx_bank.gd"
## Player movement and level sounds: jump, land, slide, wall runs, ramps, pads, the hull, death, the
## pulsing fence's warning, a zone doodad's push and the dash smashing one, a dash wall crumbling, and a splash (a
## fall into the Beach's pool water). The level-complete riffs are in sfx_bank_riffs.gd.

const E2: float = 82.41
const A2: float = 110.0


func sounds() -> Dictionary:
	return {
		"jump": _jump,
		"land": _land,
		"slide": _slide,
		"wall_enter": _wall_enter,
		"wall_jump": _wall_jump,
		"wall_blocked": _wall_blocked,
		"ramp": _ramp,
		"pad": _pad,
		"hull_end": _hull_end,
		"died": _died,
		"fence_warning": _fence_warning,
		"doodad_push": _doodad_push,
		"doodad_smash": _doodad_smash,
		"dash_wall_smash": _dash_wall_smash,
		"splash": _splash,
	}


## Jump: a 16-bit console "boing" upward. Two-operator FM with a rising pitch, bit-crushed.
func _jump() -> PackedFloat32Array:
	var b := DSP.fm(0.17, func(u: float) -> float: return DSP.sweep(240.0, 640.0, sqrt(u)), 2.0,
		func(u: float) -> float: return 0.6 + 3.5 * exp(-u * 6.0))
	DSP.envelope(b, 0.002, 0.08)
	DSP.crush(b, 8, 16000.0)
	return b


## Land: a distorted metal kick drum.
func _land() -> PackedFloat32Array:
	var b := DSP.kick(0.22, 160.0, 46.0, _rng(2))
	DSP.drive(b, 2.0)
	DSP.crush(b, 10, 22000.0)
	return b


## Slide: metal grinding on metal, with sparks.
func _slide() -> PackedFloat32Array:
	var rng := _rng(3)
	var d: float = 0.38
	var b := DSP.noise(d, rng)
	DSP.filter_sweep(b, &"bandpass", 2800.0, 1900.0, 2.5)
	var sparks := DSP.buffer(d)
	for s: int in 45:
		var at: int = rng.randi_range(0, sparks.size() - 64)
		var level: float = rng.randf_range(0.4, 1.0)
		for k: int in 64:
			sparks[at + k] += rng.randf_range(-1.0, 1.0) * level * exp(-k / 8.0)
	DSP.filter(sparks, &"highpass", 4000.0)
	DSP.mix(b, sparks, 0.0, 1.2)
	DSP.drive(b, 4.0)
	DSP.shape(b, 0.02, 0.12)
	DSP.crush(b, 7, 14000.0)
	return b


## Wall run: a guitar pick scrape. The pick clicks across the string windings, slowing as it slides.
func _wall_enter() -> PackedFloat32Array:
	var rng := _rng(4)
	var b := DSP.noise(0.45, rng)
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		phase += DSP.sweep(95.0, 38.0, float(i) / n) / DSP.RATE
		b[i] *= 0.3 + 0.7 * pow(1.0 - fmod(phase, 1.0), 6.0)
	DSP.filter_sweep(b, &"bandpass", 4200.0, 650.0, 5.0)
	DSP.drive(b, 14.0)
	DSP.filter(b, &"lowpass", 5000.0)
	DSP.filter(b, &"highpass", 150.0)
	DSP.shape(b, 0.008, 0.1)
	DSP.crush(b, 10, 22000.0)
	return b


## Wall jump: a single distorted A5 power-chord stab.
func _wall_jump() -> PackedFloat32Array:
	var b := DSP.power_chord(0.36, A2, false, _rng(5))
	DSP.envelope(b, 0.002, 0.12)
	DSP.crush(b, 10, 24000.0)
	return b


## Wall entry blocked by a sign: a dull metallic clank. Inharmonic FM plus a thud.
func _wall_blocked() -> PackedFloat32Array:
	var d: float = 0.26
	var b := DSP.fm(d, func(_u: float) -> float: return 210.0, 1.414, func(u: float) -> float: return 7.0 * exp(-u * 9.0))
	var ring := DSP.fm(d, func(_u: float) -> float: return 587.0, 2.76, func(u: float) -> float: return 3.0 * exp(-u * 12.0))
	DSP.mix(b, ring, 0.0, 0.5)
	DSP.envelope(b, 0.001, 0.07)
	DSP.mix(b, DSP.kick(0.15, 120.0, 70.0, _rng(6)), 0.0, 0.8)
	DSP.crush(b, 7, 12000.0)
	return b


## Ramp: a V-twin motorbike rev (Motörhead). Uneven firing pairs, the throttle opening up.
func _ramp() -> PackedFloat32Array:
	var rng := _rng(7)
	var d: float = 0.85
	var b := DSP.buffer(d)
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		var throttle: float = smoothstep(0.0, 0.6, u)
		var crank: float = lerpf(26.0, 105.0, throttle) - 14.0 * smoothstep(0.78, 1.0, u)
		phase += crank / DSP.RATE
		# Two firings per two crank turns, 270° apart: the lopsided V-twin beat.
		var p: float = fmod(phase, 2.0)
		var since: float = (p if p < 0.75 else p - 0.75) / crank
		var burst: float = exp(-since / 0.007)
		var body: float = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.35
		b[i] = (burst * (0.75 + 0.25 * rng.randf_range(-1.0, 1.0)) + body) * (0.4 + 0.6 * throttle)
	DSP.filter_sweep(b, &"lowpass", 650.0, 2600.0, 1.2)
	DSP.drive(b, 6.0, 0.1)
	DSP.filter(b, &"lowpass", 3500.0)
	DSP.filter(b, &"highpass", 45.0)
	DSP.shape(b, 0.01, 0.15)
	DSP.crush(b, 10, 20000.0)
	return b


## Anti-grav pad: a futuristic rising FM sweep with a whoosh and a sub thump.
func _pad() -> PackedFloat32Array:
	var d: float = 0.5
	var b := DSP.fm(d, func(u: float) -> float: return DSP.sweep(130.0, 1500.0, u), 0.5, func(_u: float) -> float: return 2.2)
	var detuned := DSP.fm(d, func(u: float) -> float: return DSP.sweep(131.5, 1518.0, u), 0.5, func(_u: float) -> float: return 2.2)
	DSP.mix(b, detuned, 0.0, 0.8)
	var whoosh := DSP.noise(d, _rng(8))
	DSP.filter_sweep(whoosh, &"bandpass", 300.0, 5000.0, 1.2)
	DSP.mix(b, whoosh, 0.0, 0.9)
	DSP.shape(b, 0.015, 0.12)
	DSP.mix(b, DSP.kick(0.2, 90.0, 50.0, _rng(9)), 0.0, 0.9)
	DSP.crush(b, 9, 18000.0)
	return b


## Hull ends: a power-down. The pitch falls while the bit depth and sample rate collapse.
func _hull_end() -> PackedFloat32Array:
	var b := DSP.fm(0.4, func(u: float) -> float: return DSP.sweep(1100.0, 110.0, u), 2.0,
		func(u: float) -> float: return 3.0 - 2.0 * u)
	DSP.envelope(b, 0.003, 0.3)
	DSP.crush_sweep(b, 12.0, 4.0, 32000.0, 2500.0)
	return b


## Death: a guitar dive bomb. An E power chord bent down two octaves, with a kick and a crash.
func _died() -> PackedFloat32Array:
	var d: float = 1.3
	var dive := func(u: float) -> float: return 1.0 if u < 0.07 else pow(0.22, pow((u - 0.07) / 0.93, 0.8))
	var b := DSP.power_chord(d, E2, false, _rng(10), dive)
	DSP.envelope(b, 0.002, 0.9, 0.25)
	DSP.crush_sweep(b, 12.0, 6.0, 32000.0, 8000.0)
	DSP.mix(b, DSP.kick(0.3, 140.0, 45.0, _rng(11)), 0.0, 0.9)
	DSP.mix(b, DSP.crash(0.7, _rng(12)), 0.0, 0.12)
	return b


## Pulsing fence about to switch on: a crunchy electric crackle that swells.
func _fence_warning() -> PackedFloat32Array:
	var rng := _rng(13)
	var b := DSP.buffer(0.35)
	var n: int = b.size()
	var phase: float = 0.0
	var level: float = 1.0
	for i: int in n:
		var u: float = float(i) / n
		phase += 120.0 / DSP.RATE
		if i % 96 == 0:
			level = rng.randf_range(0.15, 1.0) if rng.randf() < 0.6 else 1.0
		var buzz: float = (fmod(phase, 1.0) * 2.0 - 1.0) * level + sin(TAU * phase * 0.5) * 0.4
		var spark: float = rng.randf_range(-1.0, 1.0) * 2.0 if rng.randf() < 0.004 else 0.0
		b[i] = (buzz + spark) * (0.25 + 0.75 * u)
	DSP.filter(b, &"bandpass", 1800.0, 0.6)
	DSP.drive(b, 5.0)
	DSP.crush(b, 6, 11025.0)
	return b


## A zone doodad pushes the runner into the next lane (GDD §3): a dull, heavy thud, a shoulder into
## something solid. Lower and softer than the blocked move's clank, with no metal ring: it never hurts.
## DESIGN-TBD (docs/questions/g5.md 3): the push's sound.
func _doodad_push() -> PackedFloat32Array:
	var b := DSP.tom(0.24, 150.0, _rng(30))
	DSP.mix(b, DSP.kick(0.2, 170.0, 75.0, _rng(31)), 0.0, 0.6)
	var body := DSP.noise(0.14, _rng(32))
	DSP.filter(body, &"bandpass", 650.0, 0.9)
	DSP.envelope(body, 0.001, 0.03)
	DSP.mix(b, body, 0.0, 0.9)
	DSP.drive(b, 2.2)
	DSP.filter(b, &"lowpass", 3200.0)
	DSP.envelope(b, 0.001, 0.1)
	DSP.crush(b, 10, 18000.0)
	return b


## The dash smashes a zone doodad (GDD §3, owner, October 8, 2026; task H5): a crunch, the runner
## bursting through something solid that breaks apart. A sharp crack and a short, heavy thump (the push's
## thud, harder), crumbling grit closing down, and a few small pieces clattering down after it. Heavier
## than the push, well short of an explosion's boom, and with no warning's ring: nothing hurts.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md item 634): the smash's sound.
func _doodad_smash() -> PackedFloat32Array:
	var rng := _rng(40)
	var length: float = 0.62
	var b := DSP.buffer(length)
	DSP.mix(b, DSP.kick(0.24, 210.0, 62.0, rng), 0.0, 0.9)
	DSP.mix(b, DSP.tom(0.2, 120.0, rng), 0.0, 0.5)
	# The crack carries it on a phone's speaker, which can't play the thump.
	var crack := DSP.noise(0.1, rng)
	DSP.filter(crack, &"bandpass", 1700.0, 0.8)
	DSP.envelope(crack, 0.0005, 0.022)
	DSP.mix(b, crack, 0.0, 2.0)
	var crumble := DSP.noise(length, rng)
	DSP.filter_sweep(crumble, &"lowpass", 5200.0, 450.0, 0.8)
	DSP.envelope(crumble, 0.002, 0.13, 0.04)
	DSP.mix(b, crumble, 0.0, 1.0)
	DSP.mix(b, _crackle(length, 46, 0.2, 2600.0, rng), 0.015, 1.1)
	for k: int in 4:
		var at: float = 0.11 + 0.09 * k + rng.randf_range(0.0, 0.035)
		DSP.mix(b, DSP.metal_hit(0.14, rng.randf_range(1100.0, 1900.0), 0.045, rng), at, 0.18 * exp(-0.45 * k))
	DSP.drive(b, 2.4)
	DSP.filter(b, &"lowpass", 7500.0)
	DSP.envelope(b, 0.001, 1e9, 0.08)
	DSP.crush(b, 9, 18000.0)
	return b


## A dash wall breaks (GDD §9.14, owner, October 8, 2026: "they will crumble and explode into rubble"; task
## H7a): a building front coming down as the runner bursts through it, whether the dash smashed it, they
## crashed through it or a wall runner passed it. The doodad smash's crunch, bigger and lower: a heavy crack and
## a deep thump with a slab's boom under it, then the crumble's roar closing down over a second, and chunks of
## masonry clattering and thudding down after it, the last ones sparse. Heavier than a doodad's, well short of
## an explosion (no blast, no fire's roar) and with no warning's ring: what hurts is the crash's own hit, whose
## sound is the armor's or the shield's (or the death's). DESIGN-TBD (docs/OPEN_QUESTIONS.md item 658): the sound.
func _dash_wall_smash() -> PackedFloat32Array:
	var rng := _rng(41)
	var length: float = 1.45
	var b := DSP.buffer(length)
	DSP.mix(b, DSP.kick(0.34, 150.0, 44.0, rng), 0.0, 1.0)
	DSP.mix(b, _boom(0.9, 90.0, 38.0, 0.22, rng), 0.0, 0.55)
	DSP.mix(b, DSP.tom(0.3, 95.0, rng), 0.012, 0.55)
	# The crack carries it on a phone's speaker, which can't play the thump; a second one as the face gives.
	for k: int in 2:
		var crack := DSP.noise(0.14, rng)
		DSP.filter(crack, &"bandpass", 1250.0 + 450.0 * k, 0.75)
		DSP.envelope(crack, 0.0005, 0.03)
		DSP.mix(b, crack, 0.06 * k, 2.1 - 0.8 * k)
	var crumble := DSP.noise(length, rng)
	DSP.filter_sweep(crumble, &"lowpass", 4200.0, 260.0, 0.75)
	DSP.envelope(crumble, 0.004, 0.36, 0.08)
	DSP.mix(b, crumble, 0.0, 1.25)
	DSP.mix(b, _crackle(length, 90, 0.5, 2100.0, rng), 0.02, 1.0)
	# Masonry chunks landing: low thuds with a dull knock, fewer and quieter as it settles.
	for k: int in 9:
		var at: float = 0.16 + 0.11 * k + rng.randf_range(0.0, 0.06)
		var level: float = 0.5 * exp(-0.3 * k)
		DSP.mix(b, DSP.tom(0.16, rng.randf_range(150.0, 260.0), rng), at, level)
		DSP.mix(b, DSP.metal_hit(0.1, rng.randf_range(700.0, 1200.0), 0.03, rng), at + 0.004, level * 0.35)
	DSP.drive(b, 2.2)
	DSP.filter(b, &"lowpass", 7000.0)
	DSP.envelope(b, 0.001, 1e9, 0.12)
	DSP.crush(b, 9, 18000.0)
	return b


## Splash (a fall into a Beach pool, D10): a burst of water noise whose band falls from bright to dull, a low
## "bloop" as the water closes over, and a few bubbles after. Soft-edged, no hazard-style crunch.
func _splash() -> PackedFloat32Array:
	var rng := _rng(40)
	var b := DSP.noise(0.8, rng)
	DSP.filter_sweep(b, &"bandpass", 4200.0, 600.0, 1.2)
	var n: int = b.size()
	for i: int in n:
		var u: float = float(i) / n
		b[i] *= minf(u / 0.02, 1.0) * exp(-u * 5.5)
	var bloop := DSP.osc(0.3, func(u: float) -> float: return DSP.sweep(240.0, 70.0, sqrt(u)))
	DSP.envelope(bloop, 0.004, 0.09)
	DSP.mix(b, bloop, 0.02, 0.8)
	for k: int in 5:
		var hz: float = rng.randf_range(500.0, 1200.0)
		var bubble := DSP.osc(0.07, func(u: float) -> float: return hz * (1.0 + 1.2 * u))
		DSP.envelope(bubble, 0.003, 0.02)
		DSP.mix(b, bubble, 0.12 + 0.11 * float(k) + rng.randf() * 0.05, 0.25)
	DSP.filter(b, &"highpass", 80.0)
	return b
