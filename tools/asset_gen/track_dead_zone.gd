extends RefCounted
## "Dead Zone", Zone 6 (a blackened, bombed-out husk of the city: rubble, embers, smoke and silence).
## Eerie doom at 84 BPM in C# minor: quiet but never empty. A heartbeat and a ticking sixteenth
## pulse keep the runner moving under a drone, a smoky pad and a lonely tremolo guitar, then a slow,
## crushing doom riff. The quiet half sits about 5 dB under the heavy one. 16 bars = 45.7 s:
##   A  bars 1–8    ash: the C#–G# drone, the pad (C#m A F#m D G#: the Neapolitan D and the dominant
##                  G# with its B#), a heartbeat on 1 and 3, the tick, a clean guitar lament with
##                  tremolo and a long echo, distant girders creaking, wind, embers
##   B  bars 9–16   doom: the riff on the tritone (C# … E G F#), then A, a chromatic creep F#–G–G#, the
##                  Neapolitan D and G#; half-time drums with a cavernous snare, a wailing lead; the
##                  last chord rings out into the quiet

const Song = preload("res://tools/asset_gen/music_song.gd")
const Inst = preload("res://tools/asset_gen/music_instruments.gd")
const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")

const LAMENT: Array = [
	"C#5 - - - - - - - G#4 - - - - - - -",
	"E4 - - - - - - - F#4 - - - G#4 - - -",
	"A4 - - - - - - - - - - - C#5 - - -",
	"B4 - - - - - - - - - - - . . . .",
	"A4 - - - - - - - F#4 - - - - - - -",
	"C#5 - - - - - - - B4 - - - A4 - - -",
	"F#4 - - - - - - - A4 - - - D5 - - -",
	"D#5 - - - - - - - B#4 - - - - - - -",
]
const DOOM: Array = [
	"C#2 - - - - - - - E2 - - - G2 - F#2 -",
	"F#2 - - - - - - - E2 - - - D#2 - - -",
	"C#2 - - - - - - - E2 - - - G2 - F#2 -",
	"F#2 - - - - - - - E2 - - - D#2 - - -",
	"A1 - - - - - - - - - - - G#1 - A1 -",
	"F#1 - - - - - - - - - - - G1 - G#1 -",
	"D2 - - - - - - - - - - - C#2 - D2 -",
	"G#1 - - - - - - - - - - - - - - -",
]
const WAIL: Array = [
	". . . . . . . . . . . . . . . .",
	". . . . . . . . . . . . . . . .",
	"G#3 - - - - - - - - - - - B3 - C#4 -",
	"E4 - - - - - - - D#4 - - - - - - -",
	"C#4 - - - - - - - - - - - E4 - - -",
	"F#4 - - - - - - - - - - - . . . .",
	"A4 - - - - - - - F#4 - - - D4 - - -",
	"B#3 - - - - - - - - - - - - - - -",
]
const PROGRESSION: Array = ["C#m", "C#m", "A", "A", "F#m", "F#m", "D", "G#",
	"C#m", "C#m", "C#m", "C#m", "A", "F#m", "D", "G#"]
const PAD_CHORDS: Dictionary = {
	"C#m": [56, 61, 64], "A": [57, 61, 64], "F#m": [57, 61, 66], "D": [57, 62, 66], "G#": [56, 60, 63],
}
## The guitar's tremolo, in time: sixteenths at 84 BPM.
const TREMOLO_HZ: float = 5.6


static func compose() -> Song:
	var song := Song.new(84.0, 16, 841)
	song.sections = [[0, "A ash"], [8, "B doom"]]
	_heart_and_tick(song)
	_drums(song)
	_drone_and_pad(song)
	_clean(song)
	_doom(song)
	_lead(song)
	_ruins(song)
	song.echo("clean", 3.0, 0.45, 2200.0, 0.4)
	song.echo("snare", 6.0, 0.35, 1500.0, 0.35)
	song.echo("lead", 3.0, 0.35, 1800.0, 0.3)
	song.echo("fx", 4.0, 0.4, 1200.0, 0.35)
	song.mixdown({"heart": -17.0, "tick": -27.0, "drone": -19.0, "pad": -19.5, "clean": -13.5,
		"gtr": -11.0, "bass": -13.0, "drums": -12.5, "snare": -15.0, "lead": -14.0, "fx": -22.0}, -16.0)
	return song


## The heartbeat (A: lub-dub on 1 and 3) and the tick of sixteenths that runs through the whole loop,
## with embers crackling here and there.
static func _heart_and_tick(song: Song) -> void:
	var rng := song.rng
	var beat: Array = []
	for v: int in 2:
		var k := DSP.kick(0.35, 85.0, 38.0, rng)
		DSP.filter(k, &"lowpass", 180.0, 0.7)
		beat.append(k)
	song.drum("heart", 0, "x.o.....x.o.....".repeat(8), beat, 1.0)
	var tick: Array = []
	for v: int in 3:
		var t := DSP.noise(0.006, rng)
		DSP.filter(t, &"bandpass", 4500.0, 1.5)
		DSP.envelope(t, 0.0003, 0.0015, 0.001)
		tick.append(t)
	song.drum("tick", 0, "xooo".repeat(4 * 8), tick, 1.0)
	song.drum("tick", 8, "xooo".repeat(4 * 8), tick, 0.7)
	for c: int in int(song.seconds() * 2.5):
		var pop := DSP.noise(rng.randf_range(0.001, 0.003), rng)
		DSP.filter(pop, &"highpass", 1800.0)
		song.add("tick", pop, rng.randi_range(0, song.length - 1), rng.randf_range(0.2, 0.7))


## B: slow doom drums: the kick on 1 and 3's lead-in, a cavernous snare on 3, crashes, a tom fill.
static func _drums(song: Song) -> void:
	var rng := song.rng
	var kick: Array = [DSP.kick(0.5, 120.0, 40.0, rng), DSP.kick(0.5, 120.0, 40.0, rng)]
	var snare: Array = []
	for v: int in 2:
		var s := DSP.snare(0.6, 160.0, 0.5, rng)
		var room := DSP.noise(0.4, rng)
		DSP.filter(room, &"bandpass", 1400.0, 0.5)
		DSP.envelope(room, 0.005, 0.12, 0.05)
		DSP.mix(s, room, 0.0, 0.5)
		snare.append(s)
	var crash: Array = [DSP.crash(2.8, rng), DSP.crash(2.8, rng)]
	var ride: Array = [DSP.hat(0.7, 0.3, rng)]
	var toms: Array = [[DSP.tom(0.6, 140.0, rng)], [DSP.tom(0.6, 105.0, rng)], [DSP.tom(0.7, 80.0, rng)]]
	song.drum("drums", 8, "x.......x.x.....".repeat(7) + "X...............", kick, 1.0)
	song.drum("snare", 8, "........x.......".repeat(7), snare, 1.0)
	song.drum("drums", 8, "x...x...x...x...".repeat(7), ride, 0.25)
	for bar: int in [8, 10, 12, 14, 15]:
		song.drum("drums", bar, "X", crash, 0.5)
	song.drum("drums", 11, "............xx..", toms[0], 0.8)
	song.drum("drums", 11, "..............xx", toms[2], 0.85)
	song.drum("drums", 14, "............x.x.", toms[1], 0.8)
	song.drum("drums", 14, ".............x.x", toms[2], 0.85)


static func _drone_and_pad(song: Song) -> void:
	var rng := song.rng
	var bar_seconds: float = song.steps_to_seconds(16.0)
	for bar: int in 16:
		var drone := Inst.pad([37, 44], bar_seconds, 320.0, rng)
		song.add("drone", drone, song.at(bar), 1.0 if bar < 8 else 0.6)
		var chord: String = PROGRESSION[bar]
		var pad := Inst.pad(PAD_CHORDS[chord], bar_seconds, 1100.0, rng)
		song.add("pad", pad, song.at(bar), 1.0)


static func _clean(song: Song) -> void:
	var rng := song.rng
	var note := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		return Inst.clean_guitar(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), TREMOLO_HZ, rng)
	song.play("clean", Song.parse(0, LAMENT), note)


static func _doom(song: Song) -> void:
	var rng := song.rng
	var chord := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		return song.cached("gtr:%d:%d" % [n.midi, n.steps], func() -> PackedFloat32Array:
			return Inst.chord(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), false, rng))
	song.play("gtr", Song.parse(8, DOOM), chord)
	var bass := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		return Inst.fm_bass(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps - 0.2), 1.2)
	song.play("bass", Song.parse(8, DOOM), bass)


static func _lead(song: Song) -> void:
	var rng := song.rng
	var wail := func(n: Song.Note, _previous: Song.Note) -> PackedFloat32Array:
		var long_note: bool = n.steps >= 4
		return Inst.guitar_note(DSP.midi_hz(n.midi), song.steps_to_seconds(n.steps), false,
			1.0 if long_note else 0.0, 0.5 if long_note else 0.0, rng)
	song.play("lead", Song.parse(8, WAIL), wail)


## The ruins: girders creaking in the distance, wind through empty windows, and the boom that lets
## the doom in.
static func _ruins(song: Song) -> void:
	var rng := song.rng
	for spot: Array in [[2, 6.0, 175.0], [5, 11.0, 150.0], [13, 4.0, 190.0]]:
		song.add("fx", _creak(float(spot[2]), rng), song.at(spot[0], spot[1]), 0.8)
	var gust_seconds: float = song.steps_to_seconds(64.0)
	for bar: int in [0, 4]:
		song.add("fx", _wind(gust_seconds, rng), song.at(bar), 0.7)
	var bar_seconds: float = song.steps_to_seconds(16.0)
	var suck := Inst.reverse_crash(bar_seconds, rng)
	song.add("fx", suck, song.at(8) - suck.size(), 0.6)
	song.add("fx", Inst.boom(2.0, rng), song.at(8), 1.0)


## A steel girder groaning far away: a slow, sagging metallic tone.
static func _creak(hz: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.fm(1.4, func(u: float) -> float: return DSP.sweep(hz, hz * 0.8, u), 1.414,
		func(u: float) -> float: return 3.5 - 2.5 * u)
	DSP.envelope(b, 0.12, 0.45, 0.2)
	var grit := DSP.noise(1.4, rng)
	DSP.filter(grit, &"bandpass", hz * 3.0, 2.0)
	DSP.envelope(grit, 0.1, 0.3, 0.2)
	DSP.mix(b, grit, 0.0, 0.3)
	DSP.filter(b, &"bandpass", 700.0, 0.6)
	return b


## Wind through the ruins: noise whose band rises and falls over the gust.
static func _wind(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := DSP.noise(seconds, rng)
	var f := DSP.Biquad.new()
	var n: int = b.size()
	for i: int in n:
		var u: float = float(i) / n
		if i % 32 == 0:
			f.set_filter(&"bandpass", 260.0 + 420.0 * sin(PI * u), 1.8)
		b[i] = f.process(b[i]) * pow(sin(PI * u), 2.0)
	return b
