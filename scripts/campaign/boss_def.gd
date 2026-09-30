class_name BossDef
extends Resource
## A zone's boss (GDD §10): its slot in the campaign and the numbers of its fight. A boss plays inside
## the normal run world, as close to the runner as possible (see BossEncounter): its scene's root
## extends BossEncounter and runs the boss's own pattern; this resource holds what the framework
## needs around it: health and phases, the arena's track, the items it grants, and the rewards.
## Until a boss has a scene, the game shows a placeholder card in its place and lets the player
## continue.

@export var id: StringName = &""
@export var display_name: String = "Boss"
## The fight: a scene whose root extends BossEncounter (scripts/bosses/boss_encounter.gd).
## Empty = not built yet (placeholder card).
@export_file("*.tscn") var scene: String = ""
## A fight still being built: while `scene` is empty, debug builds play this one with
## `--boss=<id>` (as quick play, so nothing is recorded), and the campaign keeps its placeholder card.
@export_file("*.tscn") var preview_scene: String = ""
## Power-ups the fight grants before it starts (GDD §8: every boss must be beatable with only what
## the game grants): a permanent item at tier 1 or better ("weapon", or "weapon:2" for a tier; "armor"
## is the armor upgrade's tier over the free armor), one charge of a breakable one ("shield"), which
## never costs the player's own stock (Loadout.grant).
@export var granted_items: PackedStringArray = PackedStringArray()
## Design notes shown on the placeholder card.
@export_multiline var notes: String = ""

@export_group("Fight")
## DESIGN-TBD: the boss's health, in laser tier 1 shots (the GDD §8 damage reference). Weapons chip
## it; a big hit (a weak-point stomp, an EMP, ...) takes its part of the phase's share (BossPhase.hits).
@export_range(1.0, 5000.0, 1.0) var health: float = 300.0
## The most of the boss's health weapons can take over the whole fight, as a share (1 = no limit).
## GDD §10: the Floating Head's weapons chip slowly, so even the best weapon saves at most one of its
## three stomps (a third). DESIGN-TBD for the other bosses.
@export_range(0.0, 1.0, 0.01) var weapon_share_cap: float = 1.0
## The phases, in order (GDD §10). Empty = one phase.
@export var phases: Array[BossPhase] = []
## One lap of the fight's track, which the level generator plans like a level (seed, features,
## difficulty, pacing; its duration_seconds is the lap's length) and the fight runs through for as long
## as it lasts (BossArena). None = a plain track: floor and walls only.
@export var arena: LevelConfig
## Laps the arena cycles through, each generated from its own seed.
@export_range(1, 8) var arena_laps: int = 3
## The boss script's own numbers (timings, distances, counts): a resource of its own class, kept in
## its own file (data/bosses/<id>_tuning.tres) so the F6 tuning panel can show and save it.
@export var tuning: Resource
## Music track; empty = the zone's.
@export var music: StringName = &""

@export_group("Rewards")
## DESIGN-TBD: credits paid for a win (GDD §10: beating a boss earns credits and score), on top of any
## collected in the fight.
@export_range(0, 10000, 10) var payout_credits: int = 500
## DESIGN-TBD: score for beating the boss, and for each weak-point stomp.
@export_range(0, 100000, 100) var defeat_score: int = 5000
@export_range(0, 10000, 50) var weak_point_score: int = 500
## DESIGN-TBD (GDD §10, proposed: one star for winning, two and three for beating par times set per
## boss in data): the par times, in seconds of fight.
@export_range(10.0, 900.0, 1.0, "suffix:s") var two_star_seconds: float = 150.0
@export_range(10.0, 900.0, 1.0, "suffix:s") var three_star_seconds: float = 100.0
## DESIGN-TBD (GDD §10, proposed: the boss score includes a time bonus): points for every second the
## fight takes less than time_bonus_seconds.
@export_range(0, 1000, 5) var time_bonus_per_second: int = 50
@export_range(10.0, 900.0, 1.0, "suffix:s") var time_bonus_seconds: float = 200.0

@export_group("Armor pickups")
## GDD §10's standard armor rule: an armor pickup at the start of the final phase, and another some
## seconds after the player's armor or shield breaks, at most once per phase (proposed cap). The fight
## schedules them (BossEncounter.armor_pickup_due); the pickups themselves are task B7's.
@export var armor_rule: bool = true
## Seconds from a break to its pickup, somewhere in [min, max] (seeded): 15–17 by the standard rule,
## 10–15 for the Floating Head, the gentler first boss.
@export_range(0.0, 60.0, 0.5, "suffix:s") var armor_delay_min: float = 15.0
@export_range(0.0, 60.0, 0.5, "suffix:s") var armor_delay_max: float = 17.0
## Pickups after breaks per phase (GDD §10, proposed: at most one).
@export_range(0, 5) var armor_pickups_per_phase: int = 1


func is_built() -> bool:
	return scene != "" and ResourceLoader.exists(scene)


## A copy of this boss that plays its preview scene (a fight still being built), or null if it has
## none or is built already. The copy shares everything else (phases, arena, tuning).
func preview() -> BossDef:
	if is_built() or preview_scene == "" or not ResourceLoader.exists(preview_scene):
		return null
	var out: BossDef = duplicate() as BossDef
	out.scene = preview_scene
	return out


## The phases in order: the listed ones, or a single default phase.
func phase_list() -> Array[BossPhase]:
	if not phases.is_empty():
		return phases
	var only: Array[BossPhase] = [BossPhase.new()]
	return only


func phase_count() -> int:
	return maxi(phases.size(), 1)


## The share of the boss's health (0–1) left when each phase ends, in phase order; the last is 0.
## Three equal phases give [0.667, 0.333, 0].
func phase_ends() -> PackedFloat32Array:
	var list: Array[BossPhase] = phase_list()
	var total: float = 0.0
	for p: BossPhase in list:
		total += maxf(p.health_share, 0.0)
	var out := PackedFloat32Array()
	var left: float = 1.0
	for i: int in list.size():
		left -= maxf(list[i].health_share, 0.0) / maxf(total, 0.0001)
		out.append(0.0 if i == list.size() - 1 else maxf(left, 0.0))
	return out


## The index of the first phase marked as a checkpoint, or -1.
func checkpoint_phase() -> int:
	var list: Array[BossPhase] = phase_list()
	for i: int in list.size():
		if list[i].checkpoint:
			return i
	return -1


## Stars for a fight (GDD §10, proposed): none without a win; one for winning, two and three for
## beating the par times.
func stars_for(won: bool, seconds: float) -> int:
	if not won:
		return 0
	if seconds <= three_star_seconds:
		return 3
	if seconds <= two_star_seconds:
		return 2
	return 1


## The time bonus in the boss score for a win after `seconds` of fight.
func time_bonus(seconds: float) -> int:
	return maxi(roundi(time_bonus_per_second * (time_bonus_seconds - seconds)), 0)
