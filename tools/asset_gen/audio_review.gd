extends RefCounted
## Listening proxies for the sound and music generators (their --review option): level statistics,
## and images of the waveform, loudness over time and spectrogram, so levels, clipping, brightness
## and loop seams can be checked by eye. Buffers are mono floats at sfx_dsp.gd's RATE.

const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")
const RATE: int = DSP.RATE
const WAVE_COLOR := Color(0.4, 0.9, 1.0)


## One line of level statistics: length, peak, RMS, brightness (zero crossings) and clipping.
static func stats(b: PackedFloat32Array) -> String:
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


## Loudest 400 ms after a listening weighting, in dB: &"k" approximates ITU-R BS.1770 K-weighting
## (headphones, PC speakers: +4 dB presence shelf, rumble cut), &"phone" a small phone speaker
## (little below ~450 Hz). Compares how loud sounds seem, not just their RMS.
static func weighted_loudness_db(b: PackedFloat32Array, weighting: StringName) -> float:
	var w := b.duplicate()
	if weighting == &"phone":
		DSP.filter(w, &"highpass", 450.0, 0.7)
		DSP.filter(w, &"highpass", 450.0, 0.7)
		DSP.filter(w, &"lowpass", 12000.0, 0.7)
	else:
		DSP.filter(w, &"peaking", 4000.0, 0.4, 4.0)
		DSP.filter(w, &"highpass", 38.0, 0.5)
	return peak_loudness_db(w)


## Loudest 400 ms RMS in dB: how loud a sound is at its peak moment, for comparing short and long sounds.
static func peak_loudness_db(b: PackedFloat32Array) -> float:
	var window: int = mini(b.size(), int(0.4 * RATE))
	var sum: float = 0.0
	for i: int in window:
		sum += b[i] * b[i]
	var best: float = sum
	for i: int in range(window, b.size()):
		sum += b[i] * b[i] - b[i - window] * b[i - window]
		best = maxf(best, sum)
	return linear_to_db(sqrt(maxf(best, 1e-12) / window))


## Waveform (64 px) above a spectrogram (256 px, log frequency 40 Hz–16 kHz), `columns_per_second` wide.
static func spectrogram(b: PackedFloat32Array, columns_per_second: int = 128) -> Image:
	var hop: int = RATE / columns_per_second
	var columns: int = maxi(1, b.size() / hop)
	var img := Image.create(columns, 64 + 256, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	_draw_waveform(img, b, hop, 0)
	_draw_spectrum(img, b, hop, 64)
	return img


## The music review sheet: waveform, short-term loudness (400 ms RMS, -40 to 0 dB, guides every
## 10 dB, dim lines at every bar and bright ones at section starts), the spectrogram, and a zoom on
## the loop seam (10 ms either side, one pixel per sample, the seam marked in red).
static func music_sheet(b: PackedFloat32Array, step_samples: float, sections: Array) -> Image:
	var columns_per_second: int = 32
	var hop: int = RATE / columns_per_second
	var columns: int = maxi(1, b.size() / hop)
	var seam_half: int = RATE / 100
	var width: int = maxi(columns, seam_half * 2)
	var img := Image.create(width, 64 + 96 + 256 + 72, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	_draw_waveform(img, b, hop, 0)
	# Loudness strip.
	var top: int = 64
	for db: int in [-10, -20, -30]:
		var y: int = top + int(-db / 40.0 * 95.0)
		for x: int in columns:
			img.set_pixel(x, y, Color(0.18, 0.18, 0.18))
	var bar_samples: float = step_samples * 16.0
	var bar_count: int = roundi(b.size() / bar_samples)
	var section_bars: Array[int] = []
	for s: Array in sections:
		section_bars.append(int(s[0]))
	for bar: int in bar_count:
		var x: int = int(bar * bar_samples / hop)
		var c := Color(0.9, 0.3, 0.9) if section_bars.has(bar) else Color(0.25, 0.25, 0.35)
		for y: int in range(top, top + 96):
			img.set_pixel(clampi(x, 0, width - 1), y, c)
	var window: int = int(0.4 * RATE)
	var previous_y: int = -1
	for x: int in columns:
		var center: int = x * hop
		var sum: float = 0.0
		for k: int in range(-window / 2, window / 2, 4):
			var v: float = b[posmod(center + k, b.size())]
			sum += v * v
		var db: float = linear_to_db(maxf(sqrt(sum / (window / 4)), 1e-6))
		var y: int = top + clampi(int(-db / 40.0 * 95.0), 0, 95)
		if previous_y >= 0:
			for yy: int in range(mini(y, previous_y), maxi(y, previous_y) + 1):
				img.set_pixel(x, yy, Color(1.0, 0.85, 0.3))
		previous_y = y
	_draw_spectrum(img, b, hop, 64 + 96)
	# Seam zoom: the loop's last 10 ms, then its first 10 ms.
	var seam_top: int = 64 + 96 + 256
	for x: int in seam_half * 2:
		var v: float = b[posmod(x - seam_half, b.size())]
		var y: int = seam_top + 36 - int(clampf(v, -1.0, 1.0) * 34.0)
		img.set_pixel(x, clampi(y, seam_top, seam_top + 71), WAVE_COLOR)
	for y: int in range(seam_top, seam_top + 72):
		img.set_pixel(seam_half, y, Color(1.0, 0.2, 0.2))
	return img


## Tonal balance: the level of each octave band (63 Hz to 8 kHz) relative to the 1 kHz band, from an
## average spectrum. A balanced mix is within a few dB of flat up to 2 kHz and falls off above.
static func band_balance(b: PackedFloat32Array) -> String:
	var size: int = 4096
	var power := PackedFloat32Array()
	power.resize(size / 2)
	var frames: int = 0
	for start: int in range(0, b.size() - size, size):
		var re := PackedFloat32Array()
		var im := PackedFloat32Array()
		re.resize(size)
		im.resize(size)
		for k: int in size:
			re[k] = b[start + k] * (0.5 - 0.5 * cos(TAU * k / (size - 1)))
		_fft(re, im)
		for k: int in size / 2:
			power[k] += re[k] * re[k] + im[k] * im[k]
		frames += 1
	var bin_hz: float = float(RATE) / size
	var centers: Array[float] = [63.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0]
	var levels: Array[float] = []
	for center: float in centers:
		var sum: float = 0.0
		for k: int in range(int(center / sqrt(2.0) / bin_hz), int(center * sqrt(2.0) / bin_hz) + 1):
			sum += power[k]
		levels.append(10.0 * log(maxf(sum, 1e-20)) / log(10.0))
	var reference: float = levels[4]
	var parts: PackedStringArray = []
	for i: int in centers.size():
		var label: String = "%dk" % int(centers[i] / 1000.0) if centers[i] >= 1000.0 else "%d" % int(centers[i])
		parts.append("%s %+.0f" % [label, levels[i] - reference])
	return "bands (dB vs 1k): " + "  ".join(parts)


## How big the jump across the loop seam is, next to the signal's own sample-to-sample jumps:
## [seam step, 99th percentile step]. A click would show as a seam step far above the percentile.
static func seam_step(b: PackedFloat32Array) -> Array[float]:
	var steps: Array[float] = []
	for i: int in range(1, b.size(), 7):
		steps.append(absf(b[i] - b[i - 1]))
	steps.sort()
	return [absf(b[0] - b[b.size() - 1]), steps[int(steps.size() * 0.99)]]


static func _draw_waveform(img: Image, b: PackedFloat32Array, hop: int, top: int) -> void:
	for c: int in mini(img.get_width(), b.size() / hop):
		var lo: float = 0.0
		var hi: float = 0.0
		for k: int in hop:
			var x: float = b[mini(c * hop + k, b.size() - 1)]
			lo = minf(lo, x)
			hi = maxf(hi, x)
		for y: int in range(int(32 - hi * 31), int(32 - lo * 31) + 1):
			img.set_pixel(c, top + clampi(y, 0, 63), WAVE_COLOR)


static func _draw_spectrum(img: Image, b: PackedFloat32Array, hop: int, top: int) -> void:
	var size: int = 1024
	var rows: int = 256
	var bin_hz: float = float(RATE) / size
	for c: int in mini(img.get_width(), maxi(1, b.size() / hop)):
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
			img.set_pixel(c, top + rows - 1 - row, _heat(level))


static func _heat(v: float) -> Color:
	if v < 0.33:
		return Color(0.0, 0.0, v * 1.5)
	if v < 0.66:
		return Color((v - 0.33) * 3.0, 0.0, 0.5)
	return Color(1.0, (v - 0.66) * 3.0, 0.5 - (v - 0.66) * 1.5)


## In-place radix-2 FFT.
static func _fft(re: PackedFloat32Array, im: PackedFloat32Array) -> void:
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
