extends "res://tools/asset_gen/sfx_bank.gd"
## Enemy sounds. The player dies in one hit, so every attack has an audio warning (CLAUDE.md), and
## each warning has its own character so it is recognised instantly, even with the music on:
##   cyborg_charge        a bright, smooth FM whine climbing and pulsing faster (high, tonal)
##   truck_bang           three muffled, booming knocks through a wall (low, slow, rhythmic)
##   truck_cannon_charge  a shell clunks in, then a deep hum throbs faster and rises (low, throbbing)
##   truck_rev            an engine blips once, then revs up hard to its redline (low-mid, growling)
##   octodog_windup       a wet, rough animal growl over a servo (low-mid, organic)
##   screech_shake        an iron cover rattling in a fast, irregular clatter (metallic, jittery)
##   drone_swoop          helicopter-rotor chop approaching with a Doppler dip (chopped noise)
##   drone_windup         a buzzing motor climbing over clicks that speed up into a rattle (mechanical)
##   bad_dream_shriek     a wavering ghost scream, two voices a tritone apart (vocal, piercing)
## (The fence's crackle, fence_warning, is in sfx_bank_player.gd.) The attacks, hits and deaths follow.

const E2: float = 82.41


func sounds() -> Dictionary:
	return {
		"enemy_death": _enemy_death,
		"cyborg_charge": _cyborg_charge,
		"cyborg_shot": _cyborg_shot,
		"truck_bang": _truck_bang,
		"truck_burst": _truck_burst,
		"truck_cannon_charge": _truck_cannon_charge,
		"truck_cannon": _truck_cannon,
		"truck_rev": _truck_rev,
		"truck_explode": _truck_explode,
		"octodog_windup": _octodog_windup,
		"octodog_lunge": _octodog_lunge,
		"screech_shake": _screech_shake,
		"screech_burst": _screech_burst,
		"screech_swipe": _screech_swipe,
		"drone_swoop": _drone_swoop,
		"drone_windup": _drone_windup,
		"drone_fire": _drone_fire,
		"drone_crash": _drone_crash,
		"emp": _emp,
		"bad_dream_emerge": _bad_dream_emerge,
		"bad_dream_shriek": _bad_dream_shriek,
		"bad_dream_slash": _bad_dream_slash,
		"bad_dream_dissolve": _bad_dream_dissolve,
	}


## Generic robot death: a glitchy falling blip that pops and fizzles out.
## G2 (September 30, 2026): punchier than the first pass, for the owner's "flashier, more
## action-packed" playtest note - a heavier kick up front and a touch more drive, the fall and
## crackle kept as they were so a kill still reads as this same sound, just with more weight behind it.
func _enemy_death() -> PackedFloat32Array:
	var rng := _rng(301)
	var b := DSP.buffer(0.5)
	var fall := DSP.fm(0.35, func(u: float) -> float: return DSP.sweep(1400.0, 90.0, u), 1.5,
		func(_u: float) -> float: return 2.5)
	DSP.envelope(fall, 0.001, 0.15)
	DSP.crush_sweep(fall, 10.0, 4.0, 32000.0, 3000.0)
	DSP.mix(b, fall, 0.0, 0.9)
	var pop := DSP.noise(0.06, rng)
	DSP.filter(pop, &"lowpass", 2500.0)
	DSP.envelope(pop, 0.0005, 0.02)
	DSP.mix(b, pop, 0.0, 1.0)
	DSP.mix(b, _crackle(0.4, 25, 0.15, 4000.0, rng), 0.08, 0.5)
	DSP.mix(b, DSP.kick(0.18, 170.0, 60.0, rng), 0.0, 0.75)
	DSP.drive(b, 1.4)
	return b


## Cyborg arm cannon charging (warning): a bright FM whine that climbs from 320 Hz to 2.2 kHz with a
## fifth above it, pulsing faster and faster (10 → 42 Hz) as it swells, like a charge shot. It lasts
## the whole charge-up (charge_time in data/enemies/cyborg.tres and window_cyborg.tres: 0.75 s) and
## runs 30 ms into the first bolt's sound, so the warning never goes quiet before the shot.
func _cyborg_charge() -> PackedFloat32Array:
	var d: float = 0.75 + 0.03
	var b := DSP.fm(d, func(u: float) -> float: return DSP.sweep(320.0, 2200.0, u), 2.0,
		func(u: float) -> float: return 0.8 + 1.4 * u)
	var fifth := DSP.fm(d, func(u: float) -> float: return DSP.sweep(480.0, 3300.0, u), 2.0,
		func(u: float) -> float: return 0.5 + u)
	DSP.mix(b, fifth, 0.0, 0.35)
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		phase += lerpf(10.0, 42.0, u) / RATE
		b[i] *= (0.55 + 0.45 * sin(TAU * phase)) * (0.35 + 0.65 * u)
	DSP.shape(b, 0.01, 0.02)
	DSP.crush(b, 9, 24000.0)
	return b


## Cyborg laser bolt: harsher and lower than the player's laser, a buzzy saw zap with crackle.
func _cyborg_shot() -> PackedFloat32Array:
	var rng := _rng(303)
	var d: float = 0.28
	var zap := func(u: float) -> float: return DSP.sweep(1500.0, 280.0, pow(u, 0.5))
	var b := DSP.osc(d, zap, &"saw")
	DSP.mix(b, DSP.fm(d, zap, 1.5, func(_u: float) -> float: return 3.0), 0.0, 0.5)
	var crackle := DSP.noise(d, rng)
	DSP.filter(crackle, &"bandpass", 2000.0, 1.0)
	DSP.envelope(crackle, 0.001, 0.06)
	DSP.mix(b, crackle, 0.0, 0.4)
	DSP.envelope(b, 0.001, 0.09)
	DSP.drive(b, 3.0)
	DSP.crush(b, 7, 14000.0)
	return b


## Hover truck banging on a building wall from inside (warning before it bursts through): three heavy,
## booming knocks, each harder, muffled by the wall, with rubble rattling after them.
func _truck_bang() -> PackedFloat32Array:
	var rng := _rng(304)
	var b := DSP.buffer(1.35)
	var times: Array[float] = [0.0, 0.36, 0.66]
	var gains: Array[float] = [0.6, 0.8, 1.0]
	for k: int in times.size():
		var knock := _boom(0.6, 95.0, 38.0, 0.18, rng)
		for i: int in knock.size():
			knock[i] *= 0.6
		var thud := DSP.noise(0.3, rng)
		DSP.filter(thud, &"lowpass", 350.0)
		DSP.envelope(thud, 0.002, 0.08)
		DSP.mix(knock, thud, 0.0, 1.0)
		# The wall's body and the truck's panels: mid-range, so a phone speaker still carries the knock.
		var slam := DSP.noise(0.3, rng)
		DSP.filter(slam, &"bandpass", 750.0, 1.0)
		DSP.envelope(slam, 0.002, 0.07)
		DSP.mix(knock, slam, 0.0, 2.2)
		DSP.mix(knock, DSP.metal_hit(0.4, 150.0 + 20.0 * k, 0.12, rng), 0.0, 0.4)
		DSP.mix(knock, DSP.metal_hit(0.3, 520.0 + 40.0 * k, 0.1, rng), 0.0, 0.8)
		DSP.mix(knock, _crackle(0.4, 8, 0.2, 2500.0, rng), 0.05, 0.4)
		DSP.drive(knock, 2.5)
		DSP.mix(b, knock, times[k], gains[k])
	DSP.filter(b, &"lowpass", 3000.0)
	DSP.crush(b, 9, 16000.0)
	return b


## The hover truck bursts through the wall: a blast, concrete crumbling, twisting metal and a
## power-chord hit.
func _truck_burst() -> PackedFloat32Array:
	var rng := _rng(305)
	var b := _explosion(1.5, 1.0, rng)
	var crumble := _crackle(1.4, 70, 0.5, 900.0, rng)
	DSP.mix(b, crumble, 0.05, 0.9)
	var screech := DSP.fm(0.8, func(u: float) -> float: return DSP.sweep(700.0, 400.0, u), 1.41,
		func(_u: float) -> float: return 6.0)
	DSP.envelope(screech, 0.01, 0.3)
	DSP.mix(b, screech, 0.05, 0.3)
	var chord := DSP.power_chord(1.0, E2, false, rng)
	DSP.envelope(chord, 0.002, 0.5, 0.2)
	DSP.mix(b, chord, 0.0, 0.5)
	DSP.crush(b, 9, 18000.0)
	return b


## Hover truck cannon charging (warning before it fires): a heavy shell clunks in, then a deep hum
## throbs faster and faster (3.5 → 16 Hz) as its pitch rises (55 → 140 Hz), with hydraulic hiss.
## Low and throbbing, unlike the cyborg's bright whine.
func _truck_cannon_charge() -> PackedFloat32Array:
	var rng := _rng(306)
	var d: float = 1.0
	var b := DSP.buffer(d)
	DSP.mix(b, DSP.metal_hit(0.3, 190.0, 0.06, rng), 0.0, 0.9)
	DSP.mix(b, DSP.metal_hit(0.3, 640.0, 0.05, rng), 0.0, 0.6)
	DSP.mix(b, DSP.kick(0.2, 110.0, 60.0, rng), 0.0, 0.7)
	var hum := DSP.fm(d - 0.1, func(u: float) -> float: return DSP.sweep(55.0, 140.0, u), 1.0,
		func(u: float) -> float: return 2.0 + u)
	for i: int in hum.size():
		hum[i] *= 0.6
	# The same throb an octave up as a saw, band-passed into the mids so phone speakers carry it.
	var body := DSP.osc(d - 0.1, func(u: float) -> float: return DSP.sweep(110.0, 280.0, u), &"saw")
	DSP.filter(body, &"bandpass", 700.0, 0.7)
	DSP.mix(hum, body, 0.0, 1.6)
	var n: int = hum.size()
	var phase: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		phase += lerpf(3.5, 16.0, u * u) / RATE
		hum[i] *= pow(0.5 + 0.5 * cos(TAU * phase), 2.0) * (0.4 + 0.6 * u)
	DSP.drive(hum, 4.0)
	DSP.filter(hum, &"lowpass", 2400.0)
	DSP.mix(b, hum, 0.1, 1.0)
	var hiss := DSP.noise(d - 0.1, rng)
	DSP.filter(hiss, &"highpass", 3000.0)
	for i: int in hiss.size():
		var u: float = float(i) / hiss.size()
		hiss[i] *= u * u
	DSP.mix(b, hiss, 0.1, 0.15)
	DSP.shape(b, 0.001, 0.03)
	DSP.crush(b, 9, 16000.0)
	return b


## The truck's cannon fires: a huge low boom with a metallic ring.
func _truck_cannon() -> PackedFloat32Array:
	var rng := _rng(307)
	var b := _boom(0.9, 120.0, 36.0, 0.25, rng)
	var blast := DSP.noise(0.9, rng)
	DSP.filter_sweep(blast, &"lowpass", 4000.0, 200.0, 0.8)
	DSP.envelope(blast, 0.001, 0.12)
	DSP.mix(b, blast, 0.0, 1.2)
	var crack := DSP.noise(0.2, rng)
	DSP.filter(crack, &"bandpass", 1200.0, 0.8)
	DSP.envelope(crack, 0.001, 0.05)
	DSP.mix(b, crack, 0.0, 2.5)
	DSP.mix(b, DSP.metal_hit(0.8, 240.0, 0.3, rng), 0.0, 0.3)
	DSP.mix(b, DSP.metal_hit(0.6, 610.0, 0.15, rng), 0.0, 0.3)
	DSP.drive(b, 3.5)
	DSP.crush(b, 9, 16000.0)
	return b


## The hover truck revs before it lurches forward: a quick blip, then a hard climb to the redline,
## each firing stroke barking through an exhaust roar. It lasts the rev (HoverTruckTuning.rev_seconds,
## 1 s), so it ends as the lurch starts.
func _truck_rev() -> PackedFloat32Array:
	var rng := _rng(309)
	var d: float = 1.0
	var b := DSP.buffer(d)
	var n: int = b.size()
	var phase: float = 0.0
	for i: int in n:
		var rpm: float = _rev_rpm(float(i) / n)
		phase += lerpf(34.0, 125.0, rpm) / RATE
		var p: float = fmod(phase, 1.0)
		# One bark per firing stroke, dying away within the cycle (longer as the engine speeds up).
		var bark: float = exp(-p * lerpf(7.0, 3.0, rpm))
		var tone: float = (p * 2.0 - 1.0) * 0.6 + (0.25 if fmod(phase * 0.5, 1.0) < 0.5 else -0.25) \
			+ sin(TAU * phase * 6.0) * 0.15 * rpm
		b[i] = (tone * (0.45 + 0.55 * bark) + rng.randf_range(-1.0, 1.0) * bark * 0.35) * (0.45 + 0.55 * rpm)
	DSP.drive(b, 3.0, 0.1)
	DSP.filter(b, &"lowpass", 2600.0)
	# The exhaust roar grows with the revs; its band is what phone speakers carry.
	var roar := DSP.noise(d, rng)
	DSP.filter(roar, &"bandpass", 900.0, 0.8)
	for i: int in n:
		var r: float = _rev_rpm(float(i) / n)
		roar[i] *= r * r
	DSP.mix(b, roar, 0.0, 0.5)
	DSP.shape(b, 0.01, 0.03)
	DSP.crush(b, 9, 16000.0)
	return b


## Engine speed (0–1) through the rev: a blip up and back, then a long climb held at the redline.
static func _rev_rpm(u: float) -> float:
	if u < 0.3:
		return 0.15 + 0.45 * sin(PI * u / 0.3)
	return lerpf(0.15, 1.0, smoothstep(0.34, 0.95, u))


## The hover truck explodes: two big blasts, burning debris and metal raining down, while everything
## powers down.
func _truck_explode() -> PackedFloat32Array:
	var rng := _rng(308)
	var b := _explosion(2.0, 1.3, rng)
	DSP.mix(b, _explosion(1.6, 1.0, rng), 0.12, 0.8)
	for k: int in 10:
		var at: float = rng.randf_range(0.3, 1.6)
		DSP.mix(b, DSP.metal_hit(0.3, rng.randf_range(600.0, 2500.0), 0.06, rng), at, 0.4 * (1.0 - at / 2.0))
	DSP.crush_sweep(b, 11.0, 6.0, 32000.0, 8000.0)
	return b


## Octodog wind-up (warning before it lunges): a wet, rough, growling snarl over a whirring servo, an
## animal sound from a machine. Low and organic, unlike every other warning.
func _octodog_windup() -> PackedFloat32Array:
	var rng := _rng(309)
	var d: float = 0.75
	var b := DSP.fm(d, func(u: float) -> float: return 85.0 + 30.0 * u, 1.5, func(u: float) -> float: return 3.0 + 2.0 * u)
	var rough := DSP.noise(d, rng)
	DSP.filter(rough, &"lowpass", 40.0, 0.7)
	var n: int = b.size()
	for i: int in n:
		b[i] *= clampf(0.6 + 14.0 * rough[i], 0.1, 1.2)
	# Wet tentacles: noise through a band-pass that wobbles between 600 and 1400 Hz.
	var squelch := DSP.noise(d, rng)
	var f := DSP.Biquad.new()
	for i: int in n:
		if i % 16 == 0:
			f.set_filter(&"bandpass", 1000.0 + 400.0 * sin(TAU * 7.0 * i / RATE), 3.0)
		squelch[i] = f.process(squelch[i])
	DSP.mix(b, squelch, 0.0, 0.5)
	var servo := DSP.osc(d, func(u: float) -> float: return DSP.sweep(600.0, 900.0, u), &"saw")
	DSP.mix(b, servo, 0.0, 0.12)
	for i: int in n:
		b[i] *= 0.4 + 0.6 * float(i) / n
	DSP.shape(b, 0.06, 0.08)
	DSP.drive(b, 4.0)
	DSP.filter(b, &"lowpass", 3500.0)
	DSP.crush(b, 8, 16000.0)
	return b


## Octodog lunges: a fast whoosh with a snarl and skittering metal claws.
func _octodog_lunge() -> PackedFloat32Array:
	var rng := _rng(310)
	var b := _whoosh(0.5, 400.0, 3000.0, 1.2, rng)
	var snarl := DSP.fm(0.3, func(u: float) -> float: return DSP.sweep(140.0, 90.0, u), 1.5,
		func(_u: float) -> float: return 4.0)
	DSP.envelope(snarl, 0.005, 0.15)
	DSP.mix(b, snarl, 0.0, 0.7)
	for k: int in 8:
		DSP.mix(b, DSP.metal_hit(0.03, rng.randf_range(3000.0, 4000.0), 0.008, rng), 0.05 + k * 0.04, 0.4)
	DSP.drive(b, 2.5)
	DSP.crush(b, 8, 16000.0)
	return b


## Sewer Screech about to burst out (warning): its manhole cover or wall vent rattling, a fast,
## irregular clatter of heavy iron that gets more violent.
func _screech_shake() -> PackedFloat32Array:
	var rng := _rng(311)
	var d: float = 0.75
	var b := DSP.buffer(d)
	var t: float = 0.0
	while t < d - 0.08:
		var u: float = t / d
		DSP.mix(b, DSP.metal_hit(0.08, rng.randf_range(620.0, 820.0), 0.02, rng), t, (0.35 + 0.65 * u) * rng.randf_range(0.6, 1.0))
		t += rng.randf_range(0.035, 0.07) * (1.0 - 0.4 * u)
	var scrape := DSP.noise(d, rng)
	DSP.filter(scrape, &"bandpass", 1200.0, 2.0)
	DSP.shape(scrape, 0.1, 0.1)
	DSP.mix(b, scrape, 0.0, 0.15)
	DSP.crush(b, 8, 16000.0)
	return b


## The Screech bursts out: the cover clangs open, a squealing shriek, a wet splash.
func _screech_burst() -> PackedFloat32Array:
	var rng := _rng(312)
	var b := DSP.buffer(0.65)
	DSP.mix(b, DSP.metal_hit(0.6, 540.0, 0.18, rng), 0.0, 1.0)
	var squeal := DSP.fm(0.5, func(u: float) -> float: return DSP.sweep(2200.0, 3000.0, u) * (1.0 + 0.04 * sin(TAU * 14.0 * u * 0.5)),
		1.0, func(_u: float) -> float: return 2.0)
	DSP.envelope(squeal, 0.01, 0.15)
	DSP.mix(b, squeal, 0.03, 0.5)
	var splash := DSP.noise(0.3, rng)
	DSP.filter(splash, &"bandpass", 1500.0, 0.7)
	DSP.envelope(splash, 0.002, 0.08)
	DSP.mix(b, splash, 0.0, 0.5)
	DSP.crush(b, 8, 16000.0)
	return b


## The Screech swipes: a fast swish with a claw scrape and a squeak.
func _screech_swipe() -> PackedFloat32Array:
	var rng := _rng(313)
	var b := _whoosh(0.3, 5000.0, 900.0, 1.4, rng)
	var scrape := DSP.noise(0.12, rng)
	DSP.filter(scrape, &"bandpass", 3500.0, 3.0)
	for i: int in scrape.size():
		scrape[i] *= 0.5 + 0.5 * sin(TAU * 90.0 * i / RATE)
	DSP.envelope(scrape, 0.002, 0.05)
	DSP.mix(b, scrape, 0.08, 0.5)
	var squeak := DSP.fm(0.08, func(u: float) -> float: return DSP.sweep(2600.0, 3400.0, u), 1.0,
		func(_u: float) -> float: return 1.5)
	DSP.envelope(squeak, 0.005, 0.03)
	DSP.mix(b, squeak, 0.12, 0.25)
	DSP.crush(b, 8, 16000.0)
	return b


## Heli drone swooping in (warning of its arrival): helicopter-rotor chop that approaches, passes
## overhead with a Doppler dip in pitch, and settles into a hover.
func _drone_swoop() -> PackedFloat32Array:
	var rng := _rng(314)
	var b := DSP.noise(1.2, rng)
	var n: int = b.size()
	var f := DSP.Biquad.new()
	var chop: float = 0.0
	var motor: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		var doppler: float = lerpf(1.12, 0.88, smoothstep(0.5, 0.7, u))
		var near: float = smoothstep(0.0, 0.6, u) * (1.0 - 0.25 * smoothstep(0.6, 1.0, u))
		if i % 16 == 0:
			f.set_filter(&"bandpass", 700.0 + 900.0 * near, 1.2)
		var x: float = f.process(b[i])
		chop += 24.0 * doppler / RATE
		motor = fmod(motor + 310.0 * doppler / RATE, 1.0)
		var blades: float = pow(0.5 + 0.5 * cos(TAU * chop), 3.0)
		b[i] = (x * (0.3 + 0.7 * blades) * 2.5 + (motor * 2.0 - 1.0) * 0.12) * (0.15 + 0.85 * near)
	DSP.shape(b, 0.05, 0.15)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 20000.0)
	return b


## Heli drone gatling spinning up (warning before its barrage): a buzzing motor climbing from 90 to
## 520 Hz over barrel clicks that speed up from 7 to 55 a second into a rattle.
func _drone_windup() -> PackedFloat32Array:
	var rng := _rng(315)
	var d: float = 0.8
	var b := DSP.buffer(d)
	var motor := DSP.osc(d, func(u: float) -> float: return DSP.sweep(90.0, 520.0, u), &"saw")
	DSP.filter(motor, &"lowpass", 2500.0)
	DSP.drive(motor, 2.0)
	DSP.mix(b, motor, 0.0, 0.5)
	var click := DSP.metal_hit(0.02, 2800.0, 0.004, rng)
	var t: float = 0.0
	while t < d - 0.02:
		DSP.mix(b, click, t, 0.6)
		t += 1.0 / lerpf(7.0, 55.0, pow(t / d, 1.5))
	var n: int = b.size()
	for i: int in n:
		b[i] *= 0.45 + 0.55 * float(i) / n
	DSP.shape(b, 0.02, 0.03)
	DSP.crush(b, 8, 16000.0)
	return b


## One burst of the drone's gatling barrage: four rapid cracks.
func _drone_fire() -> PackedFloat32Array:
	var rng := _rng(316)
	var b := DSP.buffer(0.3)
	for k: int in 4:
		var shot := DSP.noise(0.06, rng)
		DSP.filter(shot, &"bandpass", 2500.0, 0.9)
		DSP.envelope(shot, 0.0005, 0.014)
		DSP.mix(shot, DSP.kick(0.05, 600.0, 250.0, rng), 0.0, 0.3)
		DSP.mix(b, shot, k * 0.045, 1.0 - 0.1 * k)
	DSP.drive(b, 3.0)
	DSP.crush(b, 7, 14000.0)
	return b


## A drone hurled into a ship's hull: a big metal clang and crunch, a small blast, and its rotors
## chopping slower as they die.
func _drone_crash() -> PackedFloat32Array:
	var rng := _rng(317)
	var b := DSP.buffer(1.3)
	DSP.mix(b, DSP.metal_hit(1.2, 210.0, 0.35, rng), 0.0, 1.0)
	DSP.mix(b, DSP.metal_hit(0.5, 690.0, 0.1, rng), 0.0, 0.6)
	var crunch := DSP.noise(0.3, rng)
	DSP.filter(crunch, &"bandpass", 1500.0, 0.8)
	DSP.envelope(crunch, 0.001, 0.05)
	DSP.mix(b, crunch, 0.0, 0.9)
	DSP.mix(b, DSP.kick(0.3, 120.0, 50.0, rng), 0.0, 0.7)
	DSP.mix(b, _explosion(0.6, 0.5, rng), 0.05, 0.5)
	var rotor := DSP.noise(1.0, rng)
	var n: int = rotor.size()
	var f := DSP.Biquad.new()
	var chop: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		if i % 16 == 0:
			f.set_filter(&"bandpass", lerpf(900.0, 400.0, u), 1.2)
		chop += lerpf(24.0, 6.0, u) / RATE
		rotor[i] = f.process(rotor[i]) * pow(0.5 + 0.5 * cos(TAU * chop), 3.0) * (1.0 - u) * 2.5
	DSP.mix(b, rotor, 0.08, 0.4)
	DSP.crush(b, 9, 18000.0)
	return b


## A fence generator destroyed, the EMP blast: a deep electric whomp, a falling zap, a burst of the
## fence's crackle, and everything electrical powering down.
func _emp() -> PackedFloat32Array:
	var rng := _rng(318)
	var d: float = 1.6
	var b := _boom(d, 90.0, 32.0, 0.4, rng)
	var zap := DSP.fm(0.9, func(u: float) -> float: return DSP.sweep(3200.0, 70.0, u), 2.0,
		func(u: float) -> float: return 5.0 - 4.0 * u)
	DSP.envelope(zap, 0.002, 0.35)
	DSP.mix(b, zap, 0.0, 0.8)
	var crackle := DSP.buffer(1.2)
	var phase: float = 0.0
	var level: float = 1.0
	for i: int in crackle.size():
		phase += 120.0 / RATE
		if i % 96 == 0:
			level = rng.randf_range(0.15, 1.0) if rng.randf() < 0.6 else 1.0
		var spark: float = rng.randf_range(-1.0, 1.0) * 2.0 if rng.randf() < 0.004 else 0.0
		crackle[i] = ((fmod(phase, 1.0) * 2.0 - 1.0) * level + spark) * exp(-float(i) / RATE / 0.35)
	DSP.filter(crackle, &"bandpass", 1800.0, 0.6)
	DSP.drive(crackle, 4.0)
	DSP.mix(b, crackle, 0.0, 0.5)
	DSP.crush_sweep(b, 12.0, 4.0, 32000.0, 2500.0)
	return b


## A Cyborg's Bad Dream bursting out of its host: dark vapor swelling under a rising, dissonant drone,
## a reversed shriek sucking in, then a ghostly moan.
func _bad_dream_emerge() -> PackedFloat32Array:
	var rng := _rng(319)
	var d: float = 1.5
	var b := DSP.buffer(d)
	var vapor := DSP.noise(d, rng)
	DSP.filter_sweep(vapor, &"bandpass", 200.0, 3000.0, 1.0)
	var n: int = vapor.size()
	for i: int in n:
		vapor[i] *= pow(sin(PI * float(i) / n), 0.7)
	DSP.mix(b, vapor, 0.0, 0.5)
	var drone := DSP.buffer(d)
	for base: float in [110.0, 116.54, 155.56]:
		DSP.mix(drone, DSP.osc(d, func(u: float) -> float: return base * pow(2.0, 5.0 * u / 12.0), &"saw"), 0.0, 0.25)
	DSP.filter(drone, &"lowpass", 900.0)
	DSP.shape(drone, 0.3, 0.3)
	DSP.mix(b, drone, 0.0, 0.7)
	var suck := _voice(0.4, func(_u: float) -> float: return 700.0, Vector2(400.0, 900.0), Vector2(2600.0, 1600.0), 8.0, 0.8, rng)
	DSP.shape(suck, 0.01, 0.3)
	suck.reverse()
	DSP.mix(b, suck, 0.1, 0.3)
	var moan := _voice(1.0, func(u: float) -> float: return DSP.sweep(220.0, 330.0, u), Vector2(300.0, 750.0),
		Vector2(800.0, 1200.0), 5.0, 0.4, rng)
	DSP.adsr(moan, 0.2, 0.5, 0.7, 0.3)
	DSP.mix(b, moan, 0.45, 0.8)
	DSP.crush(b, 10, 20000.0)
	return b


## The Bad Dream's shriek (warning before its slash): its maw opens with a piercing, wavering ghost
## scream, two voices a tritone apart, swelling in from nothing.
func _bad_dream_shriek() -> PackedFloat32Array:
	var rng := _rng(320)
	var d: float = 0.8
	var b := _voice(d, func(u: float) -> float: return 740.0 * (1.0 + 0.06 * u), Vector2(400.0, 900.0),
		Vector2(2600.0, 1600.0), 8.0, 0.8, rng)
	var high := _voice(d, func(u: float) -> float: return 1047.0 * (1.0 + 0.06 * u), Vector2(500.0, 1000.0),
		Vector2(3000.0, 2000.0), 9.5, 0.9, rng)
	DSP.mix(b, high, 0.0, 0.5)
	DSP.adsr(b, 0.15, 0.4, 0.8, 0.12)
	DSP.drive(b, 2.5)
	DSP.filter(b, &"highpass", 300.0)
	DSP.crush(b, 9, 20000.0)
	return b


## The Bad Dream slashes: a vapor swish across the lanes with three claws ringing like blades.
func _bad_dream_slash() -> PackedFloat32Array:
	var rng := _rng(321)
	var b := _whoosh(0.5, 5000.0, 700.0, 1.3, rng)
	for k: int in 3:
		DSP.mix(b, _fm_note(0.25, 3100.0 + 350.0 * k, 1.41, 3.0, 0.5, 0.08), 0.05 + 0.03 * k, 0.35)
	DSP.mix(b, DSP.kick(0.2, 90.0, 50.0, rng), 0.0, 0.4)
	DSP.crush(b, 9, 20000.0)
	return b


## The Bad Dream dissolves (chase over, or an EMP): its moan sinks and breaks up into hiss.
func _bad_dream_dissolve() -> PackedFloat32Array:
	var rng := _rng(322)
	var d: float = 1.4
	var b := _voice(d, func(u: float) -> float: return DSP.sweep(330.0, 110.0, u), Vector2(750.0, 300.0),
		Vector2(1200.0, 800.0), 6.0, 0.6, rng)
	DSP.envelope(b, 0.01, 0.5, 0.1)
	var hiss := DSP.noise(d, rng)
	var n: int = hiss.size()
	var f := DSP.Biquad.new()
	for i: int in n:
		var u: float = float(i) / n
		if i % 16 == 0:
			f.set_filter(&"bandpass", lerpf(2000.0, 5000.0, u), lerpf(6.0, 0.5, u))
		hiss[i] = f.process(hiss[i]) * sin(PI * u)
	DSP.mix(b, hiss, 0.0, 0.5)
	DSP.crush_sweep(b, 12.0, 3.0, 32000.0, 3000.0)
	DSP.shape(b, 0.01, 0.2)
	return b
