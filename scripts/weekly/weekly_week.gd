class_name WeeklyWeek
extends RefCounted
## One week of the weekly challenge (GDD §6, Replay features, "Weekly challenge"; task N5): which level it plays
## and when it runs. Made by WeeklyChallenge.week(); a value, nothing in it changes.

## Weeks since the schedule's epoch (WeeklyChallenge.epoch_unix): 0 for the first, negative before it. Boards and
## the first-clear record are keyed by it, so it never changes meaning once the game ships.
var index: int = 0
## The week's place in the shipped seed list (WeeklyChallenge.entries()): the index wrapped around the list.
var entry_index: int = 0
## The zone whose skin, enemies and obstacles the week plays in.
var zone_id: StringName = &""
## The level's seed, from the shipped list.
var level_seed: int = 0
## UTC unix seconds: when the week opens, and when the next one does.
var starts_at: int = 0
var ends_at: int = 0


## The number shown to the player: "WEEK 1" is the first week of the schedule.
func number() -> int:
	return index + 1


## Whole seconds left in the week at `now` (unix seconds), never negative.
func seconds_left(now: int) -> int:
	return maxi(ends_at - now, 0)


## True once the week is over at `now`.
func is_over(now: int) -> bool:
	return now >= ends_at
