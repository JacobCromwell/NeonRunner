class_name PerformanceTuning
extends Resource
## Numbers for keeping a run's frames smooth (task PERF1, the owner's "lag spikes are more common",
## October 2, 2026): how a run spreads its track chunks' building over frames, and the frame-time
## budgets test_frame_times holds the game to. Edit data/tuning/performance.tres; the run's numbers
## show in F6, "Performance" (the test budgets don't: they're for the tests, not for play).

const PATH: String = "res://data/tuning/performance.tres"

@export_group("Chunk building")
## How long a frame may spend dressing built track chunks (TrackBuilder.dress_budget_usec). A chunk's
## gameplay nodes (collision, hazards, triggers) are all built in the frame it's built; its look (the
## zone skin's walls, floor and hazard looks) follows over the next few frames, at least one skin call a
## frame whatever the budget, and all of it well before the player is near. 0 dresses each chunk in the
## frame it's built, as before.
@export_range(0.0, 8.0, 0.1, "suffix:ms") var chunk_dress_budget_ms: float = 1.0

@export_group("Test budgets")
## test_frame_times' budgets for one frame's CPU time (FrameMonitor: a headless run, so no GPU), on a
## quiet dev machine; a busy one scales them up by its load factor the way the skin suites' chunk
## budgets are (SkinSuite.load_factor, T-BUDGET2). The 99th percentile of a level's frames: one frame
## in a hundred may take longer. Set after PERF1's fixes, with room for the machine's own spread.
@export var test_p99_ms: float = 6.0
## The worst frame of a level once it runs (its load excluded): a first spawn, a chunk, a hit-stop's
## frame. A 60 fps frame is 16.7 ms on the target phone, which is several times slower than the dev
## machine.
@export var test_worst_ms: float = 16.0

static var _default: PerformanceTuning


## data/tuning/performance.tres (loaded once), or the defaults without it.
static func load_default() -> PerformanceTuning:
	if _default == null:
		_default = load(PATH) as PerformanceTuning if ResourceLoader.exists(PATH) else PerformanceTuning.new()
	return _default
