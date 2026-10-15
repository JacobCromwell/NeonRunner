# Architecture: Tests: the runner, the layout cache, timing, general suites

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Tests

`tools/godot.sh test` runs every `tests/suites/test_*.gd` (a `TestSuite`); `--suite=<name>` runs
one; `--jobs=N` (T-SPEED) splits them across N Godot processes instead, balanced by each suite's
last measured time (`tests/.suite_times.json`, refreshed by every run and git-ignored), each with its
own `user://` folder so their saves never collide; use it on a machine with CPUs to spare, since the
default (one process) is unchanged. `LayoutCache` (`tests/helpers/layout_cache.gd`, T-SPEED) shares
one real build of a level across every suite in a run: `LevelGenerator.generate()` is a pure function
of (config, tuning, patterns), so the many suites that independently build the same level -- often a
campaign step's own default build (3/5/6 lanes, its own seed), which several suites generate just to
run their own checks on it -- ask the cache instead of the generator. `generate()` always hands back a
fresh `LevelLayout.copy()`, and `generator()` a `LevelGenerator.for_layout` stand-in with the real
build's `attempts`/`warnings`/`picks`/`fills` restored, for a caller that reads those or calls one of
the generator's pure, read-only queries (`feature_start`, `quiet_at`, `difficulty_at`,
`placeable_features`, ...) -- never a method that places something, or `pick_weights` (it needs
generation-only state, such as `_due`/`_intro_burst`, the stand-in never had set up); its own doc
comment lists exactly which. A suite's own "does regenerating give the same layout" check keeps its
second, independent build real and uncached, so the cache can never make such a check trivially pass;
`test_layout_cache.gd` checks the cache itself (identity with a fresh build, sharing across separately
`duplicate()`d configs with the same content, never conflating a real difference, independent copies,
the `generator()` stand-in's queries), and `--no-layout-cache` (read by `tests/run_tests.gd`) turns it
off for a suite that must prove its checks still pass without it. `RunSim` (`tests/helpers/run_sim.gd`) runs a Player over a hand-built layout (`run()`), or a
full RunWorld (`build_world()` + `step_world()`); with `trace` on it records the player after every
physics frame (position, height, speed, surface, lane, lean). `SkinSuite` (`tests/helpers/skin_suite.gd`) holds
the checks every zone skin must pass, and helpers to inspect what a skin builds over a whole level
(`visit_level()`, `rects_of()`, `under_hazard()`). Its chunk build-time budgets (`whole_level()`,
`BUILD_BUDGET_MEAN_MS`/`BUILD_BUDGET_MAX_MS`) time the dressed build over `build_all()`'s
`timing_passes` (`BUILD_TIMING_PASSES`, 3) fresh builds and keep, per build step, the fastest seen:
OS preemption on a loaded machine only ever adds wall-clock time to one pass, never removes it, so
the minimum stays a faithful reading of the skin's real cost even when a single pass gets paused
mid-build. That alone doesn't help when *every* pass is slow -- several agents' test runs and
renders sharing the CPUs at once (T-BUDGET2) -- so each timed pass also drives a reference
`TrackBuilder`, in `GreyboxSkin` over a plain `REFERENCE_LANES`-lane layout as long as the one under
test, one chunk-step at a time right alongside the skin's own (same process, same moment, the whole
build through, not a snapshot at its edges). `load_factor()` reads that reference's own inflation
over its quiet-machine baseline (`REFERENCE_IDLE_MS`) and scales the budget by it, each direction
with its own safety margin and cap on how far a single pathological moment may widen it
(`MEAN_SAFETY_MARGIN`/`MEAN_FACTOR_CAP` for the mean budget, `MAX_SAFETY_MARGIN`/`MAX_FACTOR_CAP`,
wider, for the max budget, which a single loaded chunk can spike well past the mean's own inflation);
at load factor 1.0 (an unloaded machine) neither margin nor cap changes anything, so a real
regression still fails exactly as before. `test_skin_budget` (with the test-only `SlowTestSkin`,
`tests/helpers/slow_test_skin.gd`, which busy-waits a few real milliseconds per lane, a cost that
grows with load more slowly than a real skin's own) checks that check still fails a skin that really
is expensive, at whatever load this run measures, including the heaviest load the mean cap still lets
through. `LayoutChecks` (`tests/helpers/layout_checks.gd`) holds the
fairness checks for generated layouts (the generator suite runs them over many seeds, the campaign
suite over every campaign level at 3, 5 and 6 lanes, the enemy suites over their own levels), among
them `check_ceilings` (GDD §3: pads that can be stepped on and under their ceiling, safe landing zones
over each ceiling's lanes, a one-lane ceiling short, and a floor route under every ceiling without its
pad, found by `FloorRoute`, `tests/helpers/floor_route.gd`, which keeps out of a zone doodad's lane where
it stands) and `check_doodads` (G5: every doodad in an inner lane, one at a time, with nothing else in
any lane from its push to the spacing after it and off every lane-bound attack), and finds a
feature's pieces in a layout with the generator's own `LevelGenerator.feature_positions()`; a task
that adds a new kind of piece extends it (and `FloorRoute`'s cells, if the piece is on the floor), or
gives its rules script `positions()`. The generator suite also checks the recency curve's pick weights
exactly (`pick_weights()`: each kind's share, the caps) and levels paced in bursts; the campaign suite
checks each kind's share at spots all through every campaign level, The Hush and the darker lighting
on every skin. `test_enemy_director` checks the turn-taking between big attacks
with scripted test enemies (`tests/helpers/turn_dummy.gd`: the queue's order, a place kept through a gap
in the asks and through the turn, give-ups and the grace), a real Octodog that another type's repeated
attacks used to keep from its turn, and simulated runs of campaign levels,
watched by `tools/measure/attack_watch.gd` (see Review tools). `test_cyborg_airspace` checks the cyborgs'
airspace (H4): its claims (the limit, a release ending only its own claim, shooters that left play, a
boss's whole claim), two cyborgs firing together while a third waits (at once if one is killed
mid-charge), the limit at 1, the crossfire rule on 3 and 5 lanes with a runner dodging the bolts it sees
(a later second burst waiting before its charge-up on 3 lanes, firing at once on 5), a hover truck
alongside holding its lane, a wall runner (a burst at them waiting while another comes down the lane
below; two guns at the same wall runner both firing), a panic cyborg's wild fire kept apart, the places
one move away (walls, lane blockers but not doodads, a ceiling rider's lanes), two turrets on one ceiling
firing together, and the same scenario playing out the same way twice;
`test_cyborg` and `test_barnacle_turret` check at most `max_bursts_in_air` bursts in the air over
generated levels. `DummyBoss` (`tests/helpers/dummy_boss.gd`) is a boss
for framework tests, with `make_def()` for a BossDef from a list of phases; `test_bosses` runs fights
in bare worlds and, with the test boss in the City's slot, through the App (at the City's speed there,
in quick play at the base speed; and an arena planned at 25 m/s keeps its laps' seconds). `test_pickups` checks
pickup placement against the rules as it writes them itself, over hand-built cases and generated
tracks at 3, 5 and 6 lanes, and the armor rule end to end on the test boss. `test_boss_armor_rule` (I9)
checks the armor rule on every built boss that uses it (the campaign's slots and the test boss, so a boss
built later joins) at 3, 5 and 6 lanes, in a fight begun with the free armor and two shields: shield breaks
(the armor on, then down) schedule and offer no armor pickup, a hit the armor survives schedules the
phase's one within the boss's delay, and its last hit brings no second. `test_armor` covers the
free armor and its upgrade (G3): the state's rules, its wait at any frame rate and not while paused,
each tier's numbers alternating as GDD §8 says, a run's block, revive and pickups, the HUD, the shop
line and texts, the save migration, and every kind of run through the App (the web demo's too).
`test_last_hit_warning` covers the "one hit from death" cue (I6; GDD §4): the tuning's ranges and F6 sliders; the
siren's file (two flat tones alternating once per pulse, its length, no loop, mixed under the quietest attack
warning as heard); the cue stepped by hand on a bare world (the free armor breaking, a shield still held, an
upgraded armor's surviving hits, the armor's return, a pickup, death and a revive, a start with no armor, a run that
is over, a mini-game level, and the siren played once and cut off when the cue ends first); the pulses' count,
rhythm and the steady edge after them; Reduced flashing (no pulsing); the HUD running it by itself and a pause
holding it; and through the App a level, a retry, a death, both boss fights and their end, and the volleyball match.
`test_theft` covers the robbed hit (B6; GDD §9.12): a thief's touch resolving to `ROBBED` over every
combination of protections (never hurt, nothing used up; caught by the dash, a stomp, the claws), every
other hazard resolving exactly as before (a copy of the rules before B6, over every hazard kind, enemy
part and flag), the player's theft window, the books (25% of what the run holds, rounded down, held;
a second thief; the payout with the jackpot; credits held off the track and the best score), the pay
(a death after a theft, completion, a boss fight), stars equal to a clean run's, the results' "Stolen",
the HUD (the count down in the loss colour, its fade, the pop-ups, never the death message), the coin
streams, the sounds, Reduced flashing, and the stand-in on real physics at 3, 5 and 6 lanes (robbing a
runner who keeps to its lane once, missing one who moves aside, caught by a stomp, the dash, the claws
and a weapon, the same every attempt) and quick play's `--thief`.
