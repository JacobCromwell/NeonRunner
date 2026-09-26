class_name DummyBoss
extends BossEncounter
## A boss for framework tests (test_bosses): one body part that keeps `ahead` metres in front of the
## player in lane `lane` (a solid body box and a weak point on top, DummyBossPart), and hooks that
## write down what they hear. Parts with health of their own and EMPs hurt the boss by one big hit.
## The pattern moves the body and nothing else; tests drive the rest.

const PART_SCRIPT: String = "res://tests/helpers/dummy_boss_part.gd"

var body: BossPart
var heard: PackedStringArray = []
## Where the body keeps, relative to the player; set `pinned` to leave it where it is.
var ahead: float = 20.0
var lane: int = 0
var pinned: bool = false


## A BossDef for tests: one phase per entry of `phases`, each [health_share, hits, checkpoint,
## intro_seconds, pace].
static func make_def(phases: Array, health: float = 90.0) -> BossDef:
	var def := BossDef.new()
	def.id = &"dummy_boss"
	def.display_name = "Dummy Boss"
	def.health = health
	for p: Array in phases:
		var phase := BossPhase.new()
		phase.health_share = float(p[0])
		phase.hits = int(p[1])
		phase.checkpoint = bool(p[2])
		phase.intro_seconds = float(p[3])
		phase.pace = float(p[4]) if p.size() > 4 else 1.0
		def.phases.append(phase)
	return def


func _plan_lap(_lap: LevelLayout, index: int, _arena: BossArena) -> void:
	heard.append("plan_lap %d" % index)


func _build_boss() -> void:
	lane = lane_count() / 2
	body = add_part(load(PART_SCRIPT) as Script)
	heard.append("build")


func _on_phase_started(index: int) -> void:
	heard.append("phase_started %d" % index)


func _on_pattern_started(index: int) -> void:
	heard.append("pattern %d" % index)
	set_weak_points_enabled(true)


func _pattern_tick(_delta: float) -> void:
	if not pinned and is_instance_valid(body):
		body.position = world.lane_point(lane, player_distance() + ahead)


func _on_weak_point_hit(_part: BossPart, _hazard: Hazard) -> void:
	heard.append("weak_point")


func _on_part_defeated(_part: BossPart, cause: StringName) -> void:
	heard.append("part_defeated %s" % cause)
	damage(hit_damage(), cause)


func _on_part_emp(_part: BossPart, _center: Vector3, _radius: float) -> void:
	heard.append("emp")
	damage(hit_damage(), &"emp")


func _on_phase_ended(index: int) -> void:
	heard.append("phase_ended %d" % index)


func _on_defeated() -> void:
	heard.append("defeated")
