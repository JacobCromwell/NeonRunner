class_name LastHitWarningTuning
extends Resource
## Numbers for the "one hit from death" cue (GDD §4, owner, October 14, 2026: when the player has run out of
## all armor and shields, an audio and visual cue says they are a single hit away from death; the sound is a
## two-tone siren): the HUD's red screen edges (LastHitWarning) and the siren that goes with them. Edit
## data/ui/last_hit_warning.tres; every number shows in F6, "One hit from death". The siren's level is in
## data/audio/sfx_library.tres (`last_hit_siren`) with every other sound's.
##
## The siren is a recording (`tools/godot.sh sfx --only=last_hit_siren`, tools/asset_gen/sfx_bank_power.gd) made
## for `pulse_count` and `pulse_seconds`: change either, and regenerate it so the pulses and the tones stay
## together (test_last_hit_warning measures the file against them). Every number here is a first value for
## playtesting (DESIGN-TBD, docs/questions/i6.md).

const PATH: String = "res://data/ui/last_hit_warning.tres"
## Seconds of quiet after the last tone in the siren's file.
const SIREN_TAIL: float = 0.08

@export_group("When")
## DESIGN-TBD (docs/questions/i6.md 1): a level or a fight that begins with the player unprotected (a loadout
## with no armor: the game's own runs always start with the free armor) gives the cue once at the start, as if
## the protection had just run out. Off: the cue waits until the player has been protected once.
@export var warn_at_start: bool = true
## Seconds after the protection runs out before the siren and the first pulse begin, so the armor's or the
## shield's break (`armor_break`, `shield_break`) is heard on its own first. The steady edge starts at once.
@export_range(0.0, 1.0, 0.05, "suffix:s") var onset_delay: float = 0.2

@export_group("Pulses")
## How many times the screen's edges pulse with the siren, one for each high tone. The siren is made for this
## many (see the header). At most 3, so the longest siren stays under the sound library's 2.5 s.
@export_range(1, 3) var pulse_count: int = 2
## Seconds from one pulse to the next: one high tone and one low tone of the siren, slower than the other two-tone
## sounds in a fight (The House's jackpot, the searchlight's beeps). Never faster than 3 a second (the usual limit for
## anything that flashes, and Reduced flashing switches the pulses off anyway).
@export_range(0.34, 0.8, 0.01, "suffix:s") var pulse_seconds: float = 0.68
## How strong the red is at the very edge at the top of a pulse (0 clear, 1 solid).
@export_range(0.1, 1.0, 0.01) var pulse_alpha: float = 0.6

@export_group("Steady edge")
## How strong the red is at the very edge for as long as the player is unprotected, once the pulses are over.
## Dim: it is there to be seen at a glance, not to be looked at.
@export_range(0.05, 0.6, 0.01) var steady_alpha: float = 0.28
## The same with Reduced flashing on: no pulses, so the steady edge is a little stronger to make up for them.
@export_range(0.05, 0.8, 0.01) var reduced_alpha: float = 0.36
## How far in from the screen's edge the red reaches, as a share of the screen's height (its shorter side). Only the
## edges are drawn, about a third of the screen at the most, and the middle where the lanes are read is clear.
@export_range(0.04, 0.3, 0.01) var edge_width: float = 0.12
## Seconds the edge takes to come up when the protection runs out.
@export_range(0.05, 1.0, 0.05, "suffix:s") var fade_in_seconds: float = 0.2
## Seconds it takes to go when protection comes back, the player dies or the run ends.
@export_range(0.05, 1.5, 0.05, "suffix:s") var fade_out_seconds: float = 0.4


## The shared tuning (data/ui/last_hit_warning.tres), or the defaults if it's missing.
static func load_default() -> LastHitWarningTuning:
	var res: Resource = load(PATH) if ResourceLoader.exists(PATH) else null
	return res as LastHitWarningTuning if res is LastHitWarningTuning else LastHitWarningTuning.new()


## Seconds the siren plays: its pulses, and a short tail after the last tone dies away.
func siren_seconds() -> float:
	return float(pulse_count) * pulse_seconds + SIREN_TAIL

