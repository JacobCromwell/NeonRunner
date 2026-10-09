class_name GoldenConvergenceAttack
extends RefCounted
## One of the Golden Convergence's attacks (GDD §10: the Helidrone Strafe, task E5d-a; the Fist Slam and the
## Missile Barrage, E5d-b; the Refill Ship, E5d-c; stage 2's Pounce and Cable Lash, E5d-d), each its own class
## with this small interface, so the encounter (GoldenConvergence) runs a phase's beat script
## (GoldenConvergenceTuning.phase_beats) without knowing what each beat does:
## - prewarm(): makes everything it shows now (pooled), not mid-fight;
## - start(beat): the beat begins ({kind, arg}: arg is the beat script's argument, a strafe's passes);
## - tick(delta): every physics frame of the pattern while the runner is up;
## - busy(): true until the beat is over (the next beat waits for it);
## - hold(on): stops it hurting while on (GDD §10, the Refill Ship's cage: "the squadron holds its fire
##   while the cage comes up"), then lets it go on;
## - clear(): everything gone at once (a phase's end, the defeat), safely;
## - warning_on(): one of its warnings shows or its fire is live (pickups and the bot read it).
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


func busy() -> bool:
	return false


func hold(on: bool) -> void:
	held = on


func clear() -> void:
	held = false


func warning_on() -> bool:
	return false
