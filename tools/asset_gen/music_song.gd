extends RefCounted
## One music loop being built by tools/asset_gen/music_gen.gd. It holds named stems that wrap around
## the loop: a note still ringing at the end carries on at the start, exactly as it does when the loop
## repeats. Patterns sit on a 16th-note grid. Every effect with memory (filters, echo, pumping) also
## runs around the loop, so the finished file loops with no seam.

const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")
const RATE: int = DSP.RATE
const STEPS_PER_BAR: int = 16
const NOTE_NAMES: Dictionary = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


## A note from a pattern: its start (bar and 16th step), MIDI pitch, length in steps, and flags.
class Note:
	extends RefCounted
	var bar: int = 0
	var step: int = 0
	var midi: int = 0
	var steps: int = 1
	## "m" after the note name: palm-muted (guitars) or clipped short (synths).
	var muted: bool = false
	## "!" after the note name: played harder.
	var accent: bool = false


var bpm: float
var bars: int
## Samples per 16th note.
var step: float
## Samples in the whole loop.
var length: int
var stems: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Section starts, for the review image: [[bar, "name"], ...].
var sections: Array = []
## Rendered notes by key, so repeated riffs cost nothing.
var cache: Dictionary = {}
## The finished loop, set by mixdown().
var master := PackedFloat32Array()


func _init(p_bpm: float, p_bars: int, seed_value: int) -> void:
	bpm = p_bpm
	bars = p_bars
	step = 60.0 / bpm / 4.0 * RATE
	length = roundi(step * STEPS_PER_BAR * bars)
	rng.seed = seed_value


func seconds() -> float:
	return float(length) / RATE


## Seconds in `steps` 16th notes.
func steps_to_seconds(steps: float) -> float:
	return steps * step / RATE


## The sample where a 16th step of a bar starts. Steps past 15 run into the following bars.
func at(bar: int, s: float = 0.0) -> int:
	return roundi((bar * STEPS_PER_BAR + s) * step)


func stem(stem_name: String) -> PackedFloat32Array:
	if not stems.has(stem_name):
		var b := PackedFloat32Array()
		b.resize(length)
		stems[stem_name] = b
	return stems[stem_name]


## Mixes `sound` into a stem from sample `start`, wrapping past the loop end to the start.
func add(stem_name: String, sound: PackedFloat32Array, start: int, gain: float = 1.0) -> void:
	var dst: PackedFloat32Array = stem(stem_name)
	var j: int = posmod(start, length)
	for i: int in sound.size():
		dst[j] += sound[i] * gain
		j += 1
		if j == length:
			j = 0


## Drum hits from a pattern: one character per 16th step, bars back to back (spaces are ignored).
## "X" accent, "x" hit, "o" soft hit, anything else rests. Each hit picks one of `variants`.
func drum(stem_name: String, first_bar: int, pattern: String, variants: Array, gain: float = 1.0) -> void:
	var p: String = pattern.replace(" ", "")
	for i: int in p.length():
		var velocity: float = 0.0
		match p[i]:
			"X":
				velocity = 1.25
			"x":
				velocity = 1.0
			"o":
				velocity = 0.55
			_:
				continue
		var sound: PackedFloat32Array = variants[rng.randi() % variants.size()]
		add(stem_name, sound, at(first_bar, i), gain * velocity * rng.randf_range(0.92, 1.0))


## Plays notes into a stem. `render` is called as render(note, previous_note_or_null) and returns
## the note's audio, which starts on the note's step.
func play(stem_name: String, notes: Array[Note], render: Callable, gain: float = 1.0) -> void:
	var previous: Note = null
	for n: Note in notes:
		var sound: PackedFloat32Array = render.call(n, previous)
		add(stem_name, sound, at(n.bar, n.step), gain * (1.2 if n.accent else 1.0))
		previous = n


## `render` result for a key, rendered once. Variants of the same key give riffs some life.
func cached(key: String, render: Callable) -> PackedFloat32Array:
	if not cache.has(key):
		cache[key] = render.call()
	return cache[key]


## Parses bars of notes on the 16th grid. Each string is one bar of 16 space-separated tokens: a note
## name (E2, F#3, Bb4) starts a note, "-" holds the note before it (across bar lines too), "." rests.
## A note name may end in "m" (muted/short) and "!" (accent).
static func parse(first_bar: int, bar_texts: Array) -> Array[Note]:
	var out: Array[Note] = []
	var last: Note = null
	for b: int in bar_texts.size():
		var tokens: PackedStringArray = String(bar_texts[b]).split(" ", false)
		if tokens.size() != STEPS_PER_BAR:
			push_error("Bar %d needs %d steps, has %d: %s" % [first_bar + b, STEPS_PER_BAR, tokens.size(), bar_texts[b]])
		for s: int in tokens.size():
			var token: String = tokens[s]
			if token == "-":
				if last != null:
					last.steps += 1
				continue
			last = null
			if token == ".":
				continue
			var n := Note.new()
			n.bar = first_bar + b
			n.step = s
			n.muted = token.contains("m")
			n.accent = token.contains("!")
			n.midi = note_number(token.replace("m", "").replace("!", ""))
			out.append(n)
			last = n
	return out


## "E2" → 40, "F#3" → 54, "Bb1" → 34.
static func note_number(note_name: String) -> int:
	var semitone: int = NOTE_NAMES.get(note_name.left(1), -100)
	var rest: String = note_name.substr(1)
	if rest.begins_with("#"):
		semitone += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		semitone -= 1
		rest = rest.substr(1)
	if semitone < -50 or not rest.is_valid_int():
		push_error("Not a note name: '%s'" % note_name)
		return 60
	return 12 * (int(rest) + 1) + semitone


# --- Loop-safe effects -------------------------------------------------------------

## A filter on a stem. It first runs over the loop's last two seconds, so the state it starts the
## loop with is the state the loop's end leaves it in.
func filter(stem_name: String, kind: StringName, hz: float, q: float = 0.707, gain_db: float = 0.0) -> void:
	loop_filter(stem(stem_name), kind, hz, q, gain_db)


static func loop_filter(b: PackedFloat32Array, kind: StringName, hz: float, q: float = 0.707, gain_db: float = 0.0) -> void:
	var f := DSP.Biquad.new()
	f.set_filter(kind, hz, q, gain_db)
	var n: int = b.size()
	for i: int in range(maxi(0, n - 2 * RATE), n):
		f.process(b[i])
	for i: int in n:
		b[i] = f.process(b[i])


## An echo like the SNES's: repeats every `delay_steps` 16th notes, each one darker (a low-pass in
## the feedback path) and `feedback` times as loud. Repeats run on around the loop.
func echo(stem_name: String, delay_steps: float, feedback: float, damp_hz: float, wet: float) -> void:
	var b: PackedFloat32Array = stem(stem_name)
	var n: int = b.size()
	var d: int = roundi(delay_steps * step)
	var e := PackedFloat32Array()
	e.resize(n)
	var k: float = 1.0 - exp(-TAU * damp_hz / RATE)
	var lp: float = 0.0
	# The second pass reads the first pass's tail through the wrap, so the echo is circular.
	for pass_index: int in 2:
		for i: int in n:
			var j: int = i - d
			if j < 0:
				j += n
			lp += k * (b[j] + feedback * e[j] - lp)
			e[i] = lp
	for i: int in n:
		b[i] += wet * e[i]


## Sidechain pumping: the stem dips by `depth` (0–1) at every trigger sample and recovers with time
## constant `release` seconds. Triggers are usually the kick drum's hits.
func pump(stem_name: String, triggers: Array[int], depth: float, release: float) -> void:
	if triggers.is_empty():
		return
	var b: PackedFloat32Array = stem(stem_name)
	var sorted: Array[int] = []
	for t: int in triggers:
		sorted.append(posmod(t, length))
	sorted.sort()
	var next: int = 0
	var last: int = sorted[sorted.size() - 1] - length
	var tau: float = release * RATE
	for i: int in length:
		while next < sorted.size() and sorted[next] <= i:
			last = sorted[next]
			next += 1
		b[i] *= 1.0 - depth * exp(-float(i - last) / tau)


## The sample positions of every hit in a drum pattern (for pump()).
func hit_positions(first_bar: int, pattern: String) -> Array[int]:
	var out: Array[int] = []
	var p: String = pattern.replace(" ", "")
	for i: int in p.length():
		if p[i] in ["X", "x", "o"]:
			out.append(at(first_bar, i))
	return out


# --- Mixdown -------------------------------------------------------------------------

## Sums the stems, each brought to `levels[name]` dB RMS measured while it plays (so a part that only
## plays in one section is not turned up), then masters the loop: rumble filter, a small dip where
## the sound effects' cues live, and the loudness target with soft peak limiting (no fades).
func mixdown(levels: Dictionary, target_rms_db: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	for stem_name: String in levels:
		if not stems.has(stem_name):
			push_error("No stem '%s' to mix" % stem_name)
			continue
		var b: PackedFloat32Array = stems[stem_name]
		var level: float = active_rms(b)
		if level <= 0.0:
			continue
		var gain: float = db_to_linear(float(levels[stem_name])) / level
		for i: int in length:
			out[i] += b[i] * gain
	for stem_name: String in stems:
		if not levels.has(stem_name):
			push_error("Stem '%s' has no mix level" % stem_name)
	loop_filter(out, &"highpass", 30.0)
	loop_filter(out, &"peaking", 2800.0, 0.9, -2.0)
	DSP.normalize(out, target_rms_db, 0.6, 0.85)
	master = out
	return out


## RMS over the 50 ms windows where the buffer is playing (within 40 dB of its loudest window).
static func active_rms(b: PackedFloat32Array) -> float:
	var window: int = RATE / 20
	var powers: Array[float] = []
	var top: float = 0.0
	for start: int in range(0, b.size() - window + 1, window):
		var sum: float = 0.0
		for i: int in range(start, start + window):
			sum += b[i] * b[i]
		powers.append(sum / window)
		top = maxf(top, sum / window)
	var total: float = 0.0
	var count: int = 0
	for p: float in powers:
		if p > top * 1e-4:
			total += p
			count += 1
	return sqrt(total / count) if count > 0 else 0.0
