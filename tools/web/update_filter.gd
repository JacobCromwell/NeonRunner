extends SceneTree
## Sets the "Web (demo)" preset's exclude filter in export_presets.cfg from the data
## (tools/web/demo_filter.gd: the tracks and riffs the demo never plays, and the test boss):
##   godot --headless -s res://tools/web/update_filter.gd [-- --check]
## `tools/godot.sh web` runs it before every export. With --check it only says whether the preset
## matches the data, with exit code 1 when it doesn't.


func _initialize() -> void:
	var filter_script := load("res://tools/web/demo_filter.gd") as GDScript
	var want: String = filter_script.call(&"expected")
	var have: String = filter_script.call(&"preset_filter")
	var want_set: PackedStringArray = filter_script.call(&"patterns_of", want)
	var have_set: PackedStringArray = filter_script.call(&"patterns_of", have)
	var added := PackedStringArray()
	var dropped := PackedStringArray()
	for p: String in want_set:
		if not have_set.has(p):
			added.append(p)
	for p: String in have_set:
		if not want_set.has(p):
			dropped.append(p)
	if added.is_empty() and dropped.is_empty():
		print("The web demo's export filter matches the data (%d patterns)." % want_set.size())
		quit(0)
		return
	if not added.is_empty():
		print("Leave out: " + ", ".join(added))
	if not dropped.is_empty():
		print("Keep again: " + ", ".join(dropped))
	if OS.get_cmdline_user_args().has("--check"):
		print("The web demo's export filter doesn't match the data: run tools/godot.sh web")
		quit(1)
		return
	var err: Error = filter_script.call(&"write_preset", want)
	if err != OK:
		printerr("Could not update %s: %s" % [filter_script.get_script_constant_map()["PRESETS_PATH"], error_string(err)])
		quit(1)
		return
	print("Updated the web demo's export filter in export_presets.cfg.")
	quit(0)
