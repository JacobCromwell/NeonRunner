class_name TestSuite
extends RefCounted
## Base for one headless test suite. tests/run_tests.gd runs every tests/suites/test_*.gd file in
## name order. Override run() (it may await frames on `tree`) and record results with check().
## A suite never quits the tree and cleans up every node it adds.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LEVEL_PATH: String = "res://data/levels/prototype_level.tres"

var tree: SceneTree
var tuning: MovementTuning
var failures: PackedStringArray = []
var checks: int = 0


func run() -> void:
	pass


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Waits `count` physics frames.
func physics_frames(count: int) -> void:
	for i: int in count:
		await tree.physics_frame
