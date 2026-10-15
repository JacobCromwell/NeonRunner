extends SceneTree
## Measures the Sleep Taker's arena (GDD §10; task H9, owner, October 8, 2026: "twice as many floor gaps as
## first built", "the arena's side walls have many gaps"; task H11, October 10, 2026: three times that many
## floor gaps, more wall gaps): over its laps as the fight plans them
## (BossArena.plan with the boss's _plan_lap: its refuges cleared of holes, fences and wall gaps, then its
## extra floor gaps), at each lane count and speed, the floor gaps (lane-gaps: one lane's hole; rows: holes
## sharing a stretch, GapDensity.rows), the fences, the wall gaps on each wall (and a minute's worth), and
## the refuges. From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless -s res://tools/measure/sleep_taker_arena.gd -- [--lanes=3,5,6] [--speeds=18,24.2] [--first]
## `--first` measures the arena as first built (no extra floor gaps: SleepTakerTuning.floor_gap_increase 0,
## and no wall gaps), for the before/after comparison.

const BOSS_PATH: String = "res://data/bosses/dead_zone_boss.tres"

var _lanes: Array[int] = [3, 5, 6]
var _speeds: Array[float] = [18.0, 24.2]
var _first: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--lanes="):
			_lanes.clear()
			for part: String in value.split(",", false):
				_lanes.append(int(part))
		elif arg.begins_with("--speeds="):
			_speeds.clear()
			for part: String in value.split(",", false):
				_speeds.append(float(part))
		elif arg == "--first":
			_first = true
	var slot := load(BOSS_PATH) as BossDef
	var def: BossDef = slot.duplicate() as BossDef
	if _first:
		var t: SleepTakerTuning = (def.tuning as SleepTakerTuning).duplicate() as SleepTakerTuning
		t.floor_gap_increase = 0.0
		def.tuning = t
		var arena: LevelConfig = def.arena.duplicate() as LevelConfig
		var features := PackedStringArray(arena.features)
		while features.has(WallGapPlacement.FEATURE):
			features.remove_at(features.find(WallGapPlacement.FEATURE))
		arena.features = features
		arena.wall_gap_tuning = null
		def.arena = arena
	var base := load("res://data/tuning/movement.tres") as MovementTuning
	print("Sleep Taker arena%s: %d laps of %.0f s" % [" (as first built)" if _first else "", def.arena_laps,
		def.arena.duration_seconds])
	print("  %-14s %6s %10s %7s %8s %10s %9s %13s" % ["", "rows", "lane-gaps", "fences", "refuges", "wall gaps",
		"(L / R)", "a minute"])
	for speed: float in _speeds:
		for lanes: int in _lanes:
			var t: MovementTuning = base.duplicate() as MovementTuning
			t.run_speed = speed
			var config: LevelConfig = BossArena.base_config(def)
			config.lane_count = lanes
			var boss := BossEncounter.create(def) as SleepTaker
			# As plan_arena() would: the encounter shapes each lap with this def's tuning.
			boss.def = def
			var arena: BossArena = BossArena.plan(def, config, t, boss)
			var rows: int = 0
			var lane_gaps: int = 0
			var fences: int = 0
			var refuges: int = 0
			var walls := {-1: 0, 1: 0}
			for i: int in arena.laps.size():
				var lap: LevelLayout = arena.laps[i]
				rows += GapDensity.rows(lap).size()
				lane_gaps += lap.gaps.size()
				fences += lap.fences.size()
				refuges += (boss._refuge_plan.get(i, []) as Array).size()
				for g: Dictionary in lap.wall_gaps:
					walls[int(g["side"])] = int(walls[int(g["side"])]) + 1
			var minutes: float = arena.laps.size() * arena.lap_length / arena.tuning.run_speed / 60.0
			var both: int = int(walls[-1]) + int(walls[1])
			print("  %-14s %6d %10d %7d %8d %10d %9s %13s" % ["%d lanes %.1f" % [lanes, speed], rows, lane_gaps, fences,
				refuges, both, "%d / %d" % [walls[-1], walls[1]], "%.1f wall gaps" % (both / maxf(minutes, 0.001))])
			boss.free()
	quit(0)
