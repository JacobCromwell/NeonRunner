class_name GoldenConvergenceAttack
extends RefCounted
## One of the Golden Convergence's attacks (GDD §10: the Helidrone Strafe, task E5d-a; the Fist Slam and the
## Missile Barrage, E5d-b; the Refill Ship, E5d-c; stage 2's Pounce and Cable Lash, E5d-d), each its own class
## with this small interface, so the encounter (GoldenConvergence) runs a phase's beat script
## (GoldenConvergenceTuning.phase_beats) without knowing what each beat does:
## - prewarm(): makes everything it shows now (pooled), not mid-fight;
## - start(beat): the beat begins ({kind, arg}: arg is the beat script's argument, a strafe's passes);
## - tick(delta): every physics frame of the pattern while the runner is up;
## - look_tick(delta): every physics frame its tick() doesn't run (a phase's intro, the defeat): what it shows
##   keeps easing to rest (an arm stretched to the track, a hatch left open, a tower falling), never frozen;
## - busy(): true until the beat is over (the next beat waits for it);
## - hold(on): stops it hurting while on (GDD §10, the Refill Ship's cage: "the squadron holds its fire
##   while the cage comes up"), then lets it go on;
## - clear(): everything gone at once (a phase's end, the defeat), safely;
## - warning_on(): one of its warnings shows or its fire is live (pickups and the bot read it);
## - ends_at(), gap_after() (E5d-b): where its beat will be over, and the wait after it.
## The encounter registers each attack under its beat kind (GoldenConvergence.register_attack). Every warning
## it shows is a floor warning of the encounter's BossProps (red, steady with Reduced flashing) or counted as
## one (BossProps.floor_warning), and every sound goes through GoldenConvergence.sound(), which logs it.

var boss: GoldenConvergence
## The beat kind it plays (GoldenConvergenceTuning.phase_beats).
var kind: StringName = &""
var held: bool = false


func _init(p_boss: GoldenConvergence, p_kind: StringName) -> void:
	boss = p_boss
	kind = p_kind


func prewarm() -> void:
	pass


func start(_beat: Dictionary) -> void:
	pass


func tick(_delta: float) -> void:
	pass


func look_tick(_delta: float) -> void:
	pass


func busy() -> bool:
	return false


func hold(on: bool) -> void:
	held = on


func clear() -> void:
	held = false


func warning_on() -> bool:
	return false


# --- E5d-b: planning ahead --------------------------------------------------------------------------

## Where the beat it plays now will be over: the runner's track distance at the run speed once everything
## it does is done, or -1 if it can't say. The Fist Slam plans its holes before its beat begins (floor cuts
## go past the built track, BossArena.stream_from) from the beat before it's (GoldenConvergenceSlams).
func ends_at() -> float:
	return -1.0


## The wait before the next beat once this one is over (divided by the phase's pace): the tuning's
## beat_gap, unless the attack says otherwise (a Fist Slam sequence ended by a buttress hit: the Missile
## Barrage warms up at once, as the tower falls).
func gap_after() -> float:
	return boss.tuning.beat_gap
