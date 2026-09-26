class_name PlaceholderSfx
extends RefCounted
## Tiny synthesized placeholder sounds, generated in code so there are no asset files to license.
## To be replaced after the audio design round (OPEN_QUESTIONS §6). Each telegraph gets its own sound.

const MIX_RATE: int = 22050

static var _cache: Dictionary = {}


static func get_stream(sound: StringName) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _make(sound)
	return _cache[sound]


## False in headless runs: the dummy audio driver never finishes a playback, so Godot would
## report every played sound as an object leaked at exit.
static func audible() -> bool:
	return DisplayServer.get_name() != "headless"


static func names() -> Array[StringName]:
	return [&"jump", &"land", &"slide", &"wall_enter", &"wall_jump", &"wall_blocked",
		&"ramp", &"pad", &"hull_end", &"died", &"fence_warning"]


static func _make(sound: StringName) -> AudioStreamWAV:
	match sound:
		&"jump":
			return _sweep(330.0, 660.0, 0.09, &"square", 0.18)
		&"land":
			return _sweep(150.0, 55.0, 0.08, &"sine", 0.5)
		&"slide":
			return _noise(0.2, 0.22)
		&"wall_enter":
			return _sweep(480.0, 820.0, 0.1, &"triangle", 0.35)
		&"wall_jump":
			return _sweep(420.0, 940.0, 0.1, &"square", 0.16)
		&"wall_blocked":
			return _sweep(190.0, 160.0, 0.12, &"square", 0.22)
		&"ramp":
			return _sweep(380.0, 1000.0, 0.22, &"saw", 0.16)
		&"pad":
			return _sweep(200.0, 1400.0, 0.35, &"sine", 0.4)
		&"hull_end":
			return _sweep(900.0, 300.0, 0.2, &"sine", 0.3)
		&"died":
			return _sweep(440.0, 60.0, 0.45, &"saw", 0.3)
		&"fence_warning":
			return _buzz(0.35)
	push_warning("PlaceholderSfx: unknown sound %s" % sound)
	return _sweep(440.0, 440.0, 0.05, &"sine", 0.1)


## A pitch sweep with a fast attack and exponential decay.
static func _sweep(from_hz: float, to_hz: float, duration: float, wave: StringName, volume: float) -> AudioStreamWAV:
	var count: int = int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / count
		phase = fmod(phase + from_hz * pow(to_hz / from_hz, t) / MIX_RATE, 1.0)
		var s: float
		match wave:
			&"square":
				s = 1.0 if phase < 0.5 else -1.0
			&"saw":
				s = phase * 2.0 - 1.0
			&"triangle":
				s = 1.0 - absf(phase * 4.0 - 2.0)
			_:
				s = sin(phase * TAU)
		samples[i] = s * volume * _envelope(t, duration)
	return _to_stream(samples)


static func _noise(duration: float, volume: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count: int = int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low: float = 0.0
	for i: int in count:
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.25)
		samples[i] = low * volume * _envelope(float(i) / count, duration)
	return _to_stream(samples)


## A crackling electric buzz that swells toward the end: "this fence is about to switch on".
static func _buzz(duration: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var count: int = int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / count
		phase = fmod(phase + 95.0 / MIX_RATE, 1.0)
		var crackle: float = 1.0 if rng.randf() < 0.3 else 0.35
		samples[i] = (phase * 2.0 - 1.0) * crackle * 0.35 * (0.3 + 0.7 * t)
	return _to_stream(samples)


static func _envelope(t: float, duration: float) -> float:
	var attack: float = minf(1.0, t * duration / 0.005)
	return attack * exp(-4.0 * t)


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
