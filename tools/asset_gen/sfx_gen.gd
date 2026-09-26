extends SceneTree
## Generates every game sound effect into assets/sfx/<name>.wav: crunchy 16-bit synth tones,
## heavy-metal guitar and drums, and a motorbike engine, all built from code so any of them can
## be regenerated and tweaked. Run: tools/godot.sh sfx
## Add --review (tools/godot.sh sfx --review) to also write build/sfx_review/<name>.png:
## waveform on top, spectrogram (0–16 kHz, time left to right) below.
## Sounds are deterministic: every random source has a fixed seed.

const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")
const OUT_DIR: String = "res://assets/sfx"
const REVIEW_DIR: String = "res://build/sfx_review"
const E2: float = 82.41
const G2: float = 98.0
const A2: float = 110.0


func _initialize() -> void:
	var review: bool = OS.get_cmdline_user_args().has("--review")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if review:
		DirAccess.make_dir_recursive_absolute(REVIEW_DIR)
		# Keep Godot from importing the review images as game assets.
		FileAccess.open("res://build/.gdignore", FileAccess.WRITE).store_string("")
	var sounds: Dictionary = {
		"jump": _jump(),
		"land": _land(),
		"slide": _slide(),
		"wall_enter": _wall_enter(),
		"wall_jump": _wall_jump(),
		"wall_blocked": _wall_blocked(),
		"ramp": _ramp(),
		"pad": _pad(),
		"hull_end": _hull_end(),
		"died": _died(),
		"fence_warning": _fence_warning(),
		"level_complete": _level_complete(),
	}
	for sound: String in sounds:
		var b: PackedFloat32Array = sounds[sound]
		DSP.finish(b)
		var err: Error = DSP.to_wav(b).save_to_wav(OUT_DIR.path_join(sound + ".wav"))
		print("%-15s %s  %s" % [sound, "ok " if err == OK else error_string(err), _stats(b)])
		if review:
			var png_err: Error = _spectrogram(b).save_png(REVIEW_DIR.path_join(sound + ".png"))
			if png_err != OK:
				push_error("Could not write the review image for %s: %s" % [sound, error_string(png_err)])
	quit()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- The sounds ------------------------------------------------------------------

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


## Level complete: a short power-chord riff. E5 chug, chug, G5, then A5 rings out with a crash.
func _level_complete() -> PackedFloat32Array:
	var rng := _rng(14)
	var eighth: float = 60.0 / 170.0 / 2.0
	var b := DSP.buffer(eighth * 3.0 + 1.3)
	var hits: Array = [[0.0, E2, true], [eighth, E2, true], [eighth * 2.0, G2, true], [eighth * 3.0, A2, false]]
	for hit: Array in hits:
		var muted: bool = hit[2]
		var chord := DSP.power_chord(eighth if muted else 1.3, hit[1], muted, rng)
		DSP.envelope(chord, 0.002, 0.07 if muted else 0.7, 0.02 if muted else 0.2)
		DSP.mix(b, chord, hit[0])
	DSP.mix(b, DSP.crash(0.9, _rng(15)), eighth * 3.0, 0.12)
	DSP.mix(b, DSP.kick(0.25, 150.0, 45.0, _rng(16)), eighth * 3.0, 0.7)
	DSP.crush(b, 11, 24000.0)
	return b


# --- Review ------------------------------------------------------------------------

func _stats(b: PackedFloat32Array) -> String:
	var sum: float = 0.0
	var top: float = 0.0
	var clipped: int = 0
	var crossings: int = 0
	for i: int in b.size():
		sum += b[i] * b[i]
		top = maxf(top, absf(b[i]))
		if absf(b[i]) > 0.99:
			clipped += 1
		if i > 0 and signf(b[i]) != signf(b[i - 1]):
			crossings += 1
	var seconds: float = DSP.seconds_of(b)
	return "%.2f s  peak %5.1f dB  rms %5.1f dB  brightness %5d Hz  clipped %.2f%%" % [
		seconds, linear_to_db(top), linear_to_db(sqrt(sum / b.size())), int(crossings / seconds / 2.0),
		100.0 * clipped / b.size()]


## Waveform (64 px) above a spectrogram (256 px, log frequency 40 Hz–16 kHz, 128 columns per second).
func _spectrogram(b: PackedFloat32Array) -> Image:
	var size: int = 1024
	var rows: int = 256
	var hop: int = DSP.RATE / 128
	var columns: int = maxi(1, b.size() / hop)
	var img := Image.create(columns, 64 + rows, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	var bin_hz: float = float(DSP.RATE) / size
	for c: int in columns:
		var lo: float = 0.0
		var hi: float = 0.0
		for k: int in hop:
			var x: float = b[mini(c * hop + k, b.size() - 1)]
			lo = minf(lo, x)
			hi = maxf(hi, x)
		for y: int in range(int(32 - hi * 31), int(32 - lo * 31) + 1):
			img.set_pixel(c, clampi(y, 0, 63), Color(0.4, 0.9, 1.0))
		var re := PackedFloat32Array()
		var im := PackedFloat32Array()
		re.resize(size)
		im.resize(size)
		for k: int in size:
			var index: int = c * hop + k - size / 2
			var window: float = 0.5 - 0.5 * cos(TAU * k / (size - 1))
			re[k] = b[index] * window if index >= 0 and index < b.size() else 0.0
		_fft(re, im)
		for row: int in rows:
			var bin: int = clampi(roundi(DSP.sweep(40.0, 16000.0, float(row) / (rows - 1)) / bin_hz), 1, size / 2 - 1)
			var mag: float = sqrt(re[bin] * re[bin] + im[bin] * im[bin]) / (size / 4.0)
			var level: float = clampf((linear_to_db(maxf(mag, 1e-9)) + 90.0) / 90.0, 0.0, 1.0)
			img.set_pixel(c, 64 + rows - 1 - row, _heat(level))
	return img


func _heat(v: float) -> Color:
	if v < 0.33:
		return Color(0.0, 0.0, v * 1.5)
	if v < 0.66:
		return Color((v - 0.33) * 3.0, 0.0, 0.5)
	return Color(1.0, (v - 0.66) * 3.0, 0.5 - (v - 0.66) * 1.5)


## In-place radix-2 FFT.
func _fft(re: PackedFloat32Array, im: PackedFloat32Array) -> void:
	var n: int = re.size()
	var j: int = 0
	for i: int in range(1, n):
		var bit: int = n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j |= bit
		if i < j:
			var tr: float = re[i]
			re[i] = re[j]
			re[j] = tr
			var ti: float = im[i]
			im[i] = im[j]
			im[j] = ti
	var length: int = 2
	while length <= n:
		var angle: float = -TAU / length
		for start: int in range(0, n, length):
			for k: int in length / 2:
				var wr: float = cos(angle * k)
				var wi: float = sin(angle * k)
				var a: int = start + k
				var c: int = a + length / 2
				var xr: float = re[c] * wr - im[c] * wi
				var xi: float = re[c] * wi + im[c] * wr
				re[c] = re[a] - xr
				im[c] = im[a] - xi
				re[a] += xr
				im[a] += xi
		length <<= 1
