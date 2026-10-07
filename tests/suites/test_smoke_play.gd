extends TestSuite
## FIX5: `tools/godot.sh smoke --level=...` plays the level. A campaign run waits at the owner's level
## introduction until PLAY is pressed, which left the smoke run building the level and stopping there;
## tools/smoke/smoke_play.gd presses PLAY through the App and plays on. Runs the tool in fresh Godot
## processes (its own XDG_DATA_HOME on Linux, so its saves leave this run's profile alone): a level and a boss
## fight that start and move the runner; the same level with PLAY held back (--smoke-hold), which must be
## reported; and a level that does not exist, which must be reported too.

const TOOL: String = "res://tools/smoke/smoke_play.gd"
const FRAMES: int = 240


func run() -> void:
	if OS.get_name() != "Linux" or not FileAccess.file_exists("/usr/bin/env"):
		check(true, "skipped: the smoke tool's child processes need /usr/bin/env")
		return
	var played: String = _smoke(["--level=city/1", "--god", "--nofall"])
	check(played.contains("PLAY pressed"), "city/1: PLAY was pressed at the introduction:\n%s" % played)
	check(not played.contains("smoke:"), "city/1: no problem reported:\n%s" % played)
	check(_distance(played) > 5.0, "city/1: the runner ran %.1f m in %d frames:\n%s" % [_distance(played), FRAMES, played])
	var held: String = _smoke(["--level=city/1", "--god", "--nofall", "--smoke-hold"])
	check(held.contains("never left its introduction"), "PLAY held back: the run is reported stuck:\n%s" % held)
	check(_distance(held) == 0.0, "PLAY held back: the runner did not move:\n%s" % held)
	var boss: String = _smoke(["--level=city/boss", "--god", "--nofall"])
	check(boss.contains("PLAY pressed") and not boss.contains("smoke:"), "city/boss: played past its introduction:\n%s" % boss)
	check(_distance(boss) > 5.0, "city/boss: the runner ran %.1f m:\n%s" % [_distance(boss), boss])
	var missing: String = _smoke(["--level=nowhere/9"])
	check(missing.contains("started no run") or missing.contains("smoke:"), "an unknown level is reported:\n%s" % missing)


## The tool's output for `args` (game args), FRAMES frames long, with its report on.
func _smoke(args: Array[String]) -> String:
	var dir: String = OS.get_user_data_dir().path_join("smoke_child")
	DirAccess.make_dir_recursive_absolute(dir)
	var argv := PackedStringArray(["XDG_DATA_HOME=" + dir, OS.get_executable_path(), "--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--fixed-fps", "60", "-s", TOOL, "--",
		"--smoke-frames=%d" % FRAMES, "--smoke-report"])
	argv.append_array(PackedStringArray(args))
	var output: Array = []
	OS.execute("/usr/bin/env", argv, output, true)
	return "\n".join(output)


## The "furthest distance N m" of the tool's report, 0 when it has none.
func _distance(text: String) -> float:
	var at: int = text.find("furthest distance ")
	return text.substr(at + 18).to_float() if at >= 0 else 0.0
