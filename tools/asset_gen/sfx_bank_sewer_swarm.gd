extends "res://tools/asset_gen/sfx_bank.gd"
## The Sewer Swarm's sounds (GDD §10), in the same crunchy 16-bit style as the rest: the sewer screech's voice
## (sfx_bank_enemies.gd: its squeal, its claws, its rattling cover) multiplied into a horde. Every attack's
## warning has a character of its own (CLAUDE.md readability rules):
##   swarm_rise     the Rising: covers rattling all along the street, then hundreds of squeals and
##                  chittering swelling up out of the sewers over a low rumble
##   swarm_chitter  a surge's warning (GDD §10: "a red lane line and a rising chitter"): a dense chitter of
##                  clicking teeth and squeaks rising in pitch and density as the cluster rears, ending
##                  in a hiss as it goes
##   swarm_surge    the surge: a skittering rush of hundreds of claws on asphalt, a whoosh and shrieks
##   swarm_shock    a cluster shocked by a live fence: the fence's crackle bursting into a loud zap, a
##                  chorus of squeals cut short, sizzling
##   swarm_fall     a cluster pouring into a hole: squeals falling away into the dark, scrabbling claws, a
##                  distant thud
##   swarm_scatter  a cluster thinned to nothing (or beaten): squeals and claws scattering away


func sounds() -> Dictionary:
	return {
		"swarm_rise": _rise,
		"swarm_chitter": _chitter,
		"swarm_surge": _surge,
		"swarm_shock": _shock,
		"swarm_fall": _fall,
		"swarm_scatter": _scatter,
	}


## One squeal: a short FM chirp gliding from `from_hz` to `to_hz`.
func _squeak(seconds: float, from_hz: float, to_hz: float) -> PackedFloat32Array:
	var b := DSP.fm(seconds, func(u: float) -> float: return DSP.sweep(from_hz, to_hz, u), 1.0,
		func(u: float) -> float: return 1.6 + 0.8 * sin(PI * u))
	DSP.envelope(b, 0.004, seconds * 0.45)
	return b


## Claws on asphalt: `count` tiny ticks over the buffer, denser where `density` (of normalized time) is high.
func _skitter(seconds: float, count: int, density: Callable, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.buffer(seconds)
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 8:
		tries += 1
		var u: float = rng.randf()
		if rng.randf() > float(density.call(u)):
			continue
		var at: int = int(u * maxi(b.size() - 64, 1))
		var level: float = rng.randf_range(0.3, 1.0)
		for j: int in mini(48, b.size() - at):
			b[at + j] += rng.randf_range(-1.0, 1.0) * level * exp(-j / 6.0)
		placed += 1
	DSP.filter(b, &"bandpass", 3600.0, 0.9)
	return b


## The Rising: covers rattling, then the horde squealing up out of the sewers over a rumble.
func _rise() -> PackedFloat32Array:
	var rng := _rng(611)
	var d: float = 2.6
	var b := DSP.buffer(d)
	var rumble := DSP.noise(d, rng)
	DSP.filter(rumble, &"lowpass", 140.0, 0.9)
	DSP.adsr(rumble, 0.8, 0.6, 0.7, 0.7)
	DSP.mix(b, rumble, 0.0, 1.8)
	# Covers rattling all along the street, thickening.
	var t: float = 0.0
	while t < 1.6:
		DSP.mix(b, DSP.metal_hit(0.07, rng.randf_range(560.0, 860.0), 0.02, rng), t, rng.randf_range(0.25, 0.6))
		t += rng.randf_range(0.02, 0.06)
	# The horde: squeals swelling in.
	for k: int in 90:
		var at: float = 0.5 + pow(rng.randf(), 0.7) * (d - 0.7)
		var hz: float = rng.randf_range(1800.0, 4200.0)
		var sq := _squeak(rng.randf_range(0.05, 0.14), hz, hz * rng.randf_range(0.8, 1.35))
		DSP.mix(b, sq, at, rng.randf_range(0.08, 0.22) * smoothstep(0.4, 1.8, at))
	var claws := _skitter(d, 700, func(u: float) -> float: return smoothstep(0.15, 0.7, u), rng)
	DSP.mix(b, claws, 0.0, 0.7)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 18000.0)
	return b


## A surge's warning: a chitter rising in pitch and density, ending in a hiss.
func _chitter() -> PackedFloat32Array:
	var rng := _rng(612)
	var d: float = 2.4
	var b := DSP.buffer(d)
	# Clicking teeth: a tick train speeding up.
	var phase: float = 0.0
	var i: int = 0
	while i < b.size():
		var u: float = float(i) / b.size()
		var rate: float = lerpf(14.0, 46.0, u * u)
		phase += rate / RATE
		if phase >= 1.0:
			phase -= 1.0
			var level: float = 0.35 + 0.65 * u
			for j: int in mini(40, b.size() - i):
				b[i + j] += rng.randf_range(-1.0, 1.0) * level * exp(-j / 7.0)
		i += 1
	DSP.filter(b, &"bandpass", 2400.0, 1.2)
	# Squeaks rising with it.
	for k: int in 70:
		var u: float = pow(rng.randf(), 0.55)
		var hz: float = lerpf(1300.0, 4600.0, u) * rng.randf_range(0.85, 1.15)
		var sq := _squeak(rng.randf_range(0.04, 0.1), hz, hz * rng.randf_range(1.0, 1.4))
		DSP.mix(b, sq, u * (d - 0.15), rng.randf_range(0.1, 0.25) * (0.3 + 0.7 * u))
	# A trembling growl under it, and the hiss as it goes.
	var growl := DSP.osc(d, func(u: float) -> float: return lerpf(90.0, 150.0, u), &"saw")
	DSP.filter(growl, &"lowpass", 600.0)
	DSP.adsr(growl, 1.2, 0.5, 0.8, 0.2)
	DSP.mix(b, growl, 0.0, 0.18)
	var hiss := DSP.noise(0.5, rng)
	DSP.filter(hiss, &"highpass", 3000.0)
	DSP.adsr(hiss, 0.3, 0.1, 0.8, 0.1)
	DSP.mix(b, hiss, d - 0.5, 0.35)
	DSP.drive(b, 1.6)
	DSP.crush(b, 9, 18000.0)
	return b


## The surge: claws rushing on asphalt, a whoosh, shrieks.
func _surge() -> PackedFloat32Array:
	var rng := _rng(613)
	var d: float = 1.3
	var b := _whoosh(d, 600.0, 4000.0, 0.9, rng)
	DSP.mix(b, _skitter(d, 900, func(u: float) -> float: return sin(PI * clampf(u * 1.2, 0.0, 1.0)), rng), 0.0, 1.0)
	for k: int in 26:
		var hz: float = rng.randf_range(2600.0, 5000.0)
		DSP.mix(b, _squeak(rng.randf_range(0.06, 0.16), hz, hz * rng.randf_range(0.7, 1.2)), rng.randf_range(0.0, d - 0.2),
			rng.randf_range(0.12, 0.3))
	DSP.drive(b, 1.7)
	DSP.crush(b, 9, 18000.0)
	return b


## Shocked on a live fence: a crackling zap, squeals cut short, sizzling.
func _shock() -> PackedFloat32Array:
	var rng := _rng(614)
	var d: float = 1.25
	var b := DSP.buffer(d)
	var zap := DSP.noise(0.35, rng)
	for i: int in zap.size():
		zap[i] *= 0.5 + 0.5 * sign(sin(TAU * 120.0 * i / RATE))
	DSP.filter(zap, &"bandpass", 1800.0, 0.8)
	DSP.envelope(zap, 0.002, 0.12)
	DSP.mix(b, zap, 0.0, 1.6)
	var buzz := DSP.osc(0.5, func(u: float) -> float: return 120.0, &"square")
	DSP.filter(buzz, &"lowpass", 2000.0)
	DSP.envelope(buzz, 0.002, 0.18)
	DSP.mix(b, buzz, 0.0, 0.4)
	DSP.mix(b, _crackle(d, 90, 0.4, 4200.0, rng), 0.0, 0.9)
	for k: int in 30:
		var hz: float = rng.randf_range(2500.0, 4800.0)
		var sq := _squeak(rng.randf_range(0.04, 0.09), hz, hz * 1.3)
		DSP.mix(b, sq, rng.randf_range(0.0, 0.18), rng.randf_range(0.15, 0.3))
	var sizzle := DSP.noise(d, rng)
	DSP.filter(sizzle, &"highpass", 5000.0)
	DSP.adsr(sizzle, 0.05, 0.3, 0.4, 0.7)
	DSP.mix(b, sizzle, 0.1, 0.25)
	DSP.drive(b, 2.0)
	DSP.crush(b, 8, 16000.0)
	return b


## Into a hole: squeals falling away, scrabbling claws, a distant thud.
func _fall() -> PackedFloat32Array:
	var rng := _rng(615)
	var d: float = 1.6
	var b := DSP.buffer(d)
	for k: int in 40:
		var at: float = rng.randf_range(0.0, 0.8)
		var hz: float = rng.randf_range(2200.0, 4200.0)
		var sq := _squeak(rng.randf_range(0.18, 0.4), hz, hz * 0.45)
		DSP.mix(b, sq, at, rng.randf_range(0.1, 0.22) * (1.0 - at * 0.6))
	DSP.mix(b, _skitter(d, 400, func(u: float) -> float: return 1.0 - u, rng), 0.0, 0.7)
	var thud := DSP.kick(0.4, 90.0, 40.0, rng)
	DSP.mix(b, thud, 1.05, 0.5)
	DSP.filter(b, &"lowpass", 9000.0)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 18000.0)
	return b


## Thinned to nothing: squeals and claws scattering away.
func _scatter() -> PackedFloat32Array:
	var rng := _rng(616)
	var d: float = 0.9
	var b := DSP.buffer(d)
	for k: int in 22:
		var hz: float = rng.randf_range(2400.0, 4600.0)
		DSP.mix(b, _squeak(rng.randf_range(0.05, 0.12), hz, hz * rng.randf_range(0.9, 1.3)), rng.randf_range(0.0, 0.5),
			rng.randf_range(0.12, 0.26))
	DSP.mix(b, _skitter(d, 300, func(u: float) -> float: return 1.0 - u * 0.8, rng), 0.0, 0.8)
	DSP.drive(b, 1.5)
	DSP.crush(b, 9, 18000.0)
	return b
