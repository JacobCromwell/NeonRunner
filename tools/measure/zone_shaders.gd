extends SceneTree
## Counts the shaders a campaign level draws, to find the ones built twice and the ones never drawn (task I1,
## the owner's "shader cleanup in every zone", October 14, 2026). A renderer compiles a program per Shader
## resource (not per shader code) and one per standard-material look, so the count of distinct Shader objects
## and standard-material keys a level uses is the in-engine twin of `tools/web/shader_programs.js` (which
## counts the programs WebGL links in a browser). It needs no renderer, so it runs headless. From the project
## folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless -s res://tools/measure/zone_shaders.gd -- [options]
## Options:
##   --levels=city/1,gangland/1   campaign levels (default: each zone's first level and the Golden Palace)
##   --lanes=5                    the lane count (default 5)
##   --detail                     also list every shader of the level and where it is drawn
##   --out=build/measure/zone_shaders.json   write the numbers there
##
## What it does for each level: builds the world as a run does (the level's own skin, full loadout, the
## level's enemies and credits), walks the whole track with the chunks dressed (so every look the level's
## own layout dresses is built once), adds the shader warm-up's samples (ShaderWarmup, built the way LevelRun
## does, though a headless run never draws them) and prints:
## - "shader objects": distinct Shader resources on ShaderMaterials, and the distinct codes among them (more
##   objects than codes: one code built into several programs);
## - "standard looks": distinct StandardMaterial3D/ORMMaterial3D shader keys (ShaderWarmup.shader_key);
## - "warmed only": shader keys only the warm-up's samples draw (the samples cover looks a level may show
##   later: every enemy kind it brings, every piece the skin dresses), and "walked only": keys the walk of
##   the track found that the warm-up did not draw (a shader the run would first compile mid-run).

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const TUNING_PATH: String = "res://data/tuning/movement.tres"
const DEFAULT_LEVELS: Array[String] = ["city/1", "gangland/1", "marketplace/1", "casino/1", "corporate/1",
	"beach/1", "dead_zone/1", "golden/1", "golden/3"]

var _levels: Array[String] = []
var _lanes: int = 5
var _detail: bool = false
var _out: String = ""
var _results: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			for id: String in value.split(",", false):
				_levels.append(id)
		elif arg.begins_with("--lanes="):
			_lanes = int(value)
		elif arg == "--detail":
			_detail = true
		elif arg.begins_with("--out="):
			_out = value
	if _levels.is_empty():
		_levels.append_array(DEFAULT_LEVELS)
	for id: String in _levels:
		await _survey(id)
	if _out != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out).get_base_dir())
		var file := FileAccess.open(_out, FileAccess.WRITE)
		file.store_string(JSON.stringify(_results, "\t"))
		file.close()
	quit(0)


## One level: build, walk the track, add the warm-up, print.
func _survey(id: String) -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var tuning := load(TUNING_PATH) as MovementTuning
	var step: CampaignStep = campaign.step(id)
	if step == null or not step.is_level():
		print("%s: no such campaign level" % id)
		return
	var config: LevelConfig = campaign.configure(step, _lanes)
	var t: MovementTuning = config.movement_for(tuning)
	var layout: LevelLayout = LevelGenerator.new().generate(config, t, LevelGenerator.load_for(config))
	var sim := RunSim.new(self, t)
	var catalog: Object = root.get_node(^"/root/App").get(&"catalog")
	var world: RunWorld = sim.build_world(layout, Loadout.full(catalog), t, config)
	await physics_frame
	# What the level draws: the world as built, then the whole track dressed chunk by chunk.
	var walked: Dictionary = {}
	_collect(world, walked)
	var d: float = 0.0
	var frame: int = 0
	while d < layout.length + 200.0:
		d += 8.0
		world.track.update(d, d / t.run_speed)
		world.track.dress_all()
		frame += 1
		if frame % 40 == 0:
			_collect(world.track, walked)
			await process_frame
	_collect(world, walked)
	# One of each enemy type and kind the level brings, spawned as the director spawns them.
	var spawned: Dictionary = {}
	for entry: Dictionary in world.director.get(&"_pending"):
		var kind: String = "%s|%s" % [entry.get("type", ""), (entry.get("params", {}) as Dictionary).get("host", false)]
		if spawned.has(kind):
			continue
		spawned[kind] = true
		world.director.spawn(entry)
	await physics_frame
	_collect(world.director, walked)
	# What a run's stage warms: its samples (the run's hidden looks among them).
	var camera := Camera3D.new()
	root.add_child(camera)
	var stage := ShaderWarmup.new()
	stage.setup(world, camera)
	var warmed: Dictionary = {}
	_collect(stage, warmed)
	var all: Dictionary = walked.duplicate()
	all.merge(warmed)
	_report(id, config, all, walked, warmed)
	stage.free()
	camera.free()
	world.queue_free()
	await process_frame
	await process_frame


## Records the materials under `root_node` in `into` {object id: info}, with the first node that draws each
## (hidden ones too: pools wait hidden, and the warm-up's samples are hidden until its stage shows them).
func _collect(root_node: Node, into: Dictionary) -> void:
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if not node is GeometryInstance3D:
			continue
		for m: Material in ShaderWarmup.materials_of(node):
			var id: int = m.get_instance_id()
			if into.has(id):
				continue
			var info: Dictionary = {"material": m, "key": ShaderWarmup.shader_key(m), "user": _user(node)}
			var sm := m as ShaderMaterial
			if sm != null and sm.shader != null:
				info["shader"] = sm.shader
				info["code"] = sm.shader.code.md5_text().left(8)
				info["file"] = sm.shader.resource_path
			into[id] = info


## What draws a material, short: the nearest scripted ancestor (or the node's own script) and the node's name.
func _user(node: Node) -> String:
	var up: Node = node
	while up != null and up.get_script() == null:
		up = up.get_parent()
	var kind: String = (up.get_script() as Script).resource_path.get_file().get_basename() if up != null else node.get_class()
	return "%s/%s" % [kind, node.name]


func _report(id: String, config: LevelConfig, all: Dictionary, walked: Dictionary, warmed: Dictionary) -> void:
	var shaders: Dictionary = {}  # Shader object -> info of its first material
	var by_code: Dictionary = {}  # code hash -> {Shader object: true}
	var std_keys: Dictionary = {}
	var std_objects: int = 0
	var others: int = 0
	for info: Dictionary in all.values():
		if info.has("shader"):
			var shader: Shader = info["shader"]
			if not shaders.has(shader):
				shaders[shader] = info
			if not by_code.has(info["code"]):
				by_code[info["code"]] = {}
			by_code[info["code"]][shader] = true
		elif String(info["key"]).begins_with("std"):
			std_keys[info["key"]] = info
			std_objects += 1
		else:
			others += 1
	var duplicate_codes: int = 0
	var extra_objects: int = 0
	for code: String in by_code:
		if by_code[code].size() > 1:
			duplicate_codes += 1
			extra_objects += by_code[code].size() - 1
	var walked_keys: Dictionary = {}
	for info: Dictionary in walked.values():
		walked_keys[info["key"]] = info
	var warmed_keys: Dictionary = {}
	for info: Dictionary in warmed.values():
		warmed_keys[info["key"]] = info
	var only_warmed: int = 0
	var only_walked: int = 0
	for k: String in warmed_keys:
		if not walked_keys.has(k):
			only_warmed += 1
	for k: String in walked_keys:
		if not warmed_keys.has(k):
			only_walked += 1
	var skin_name: String = config.skin.get_script().resource_path.get_file() if config.skin != null else "-"
	print("== %s (%s, %s)" % [id, config.display_name, skin_name])
	print("   shader objects: %d (%d distinct codes; %d codes in several objects, %d programs built again)" % [
		shaders.size(), by_code.size(), duplicate_codes, extra_objects])
	print("   standard looks: %d (%d materials), other materials: %d" % [std_keys.size(), std_objects, others])
	print("   programs (shader objects + standard looks): %d" % (shaders.size() + std_keys.size()))
	print("   %d keys warmed, %d walked; warmed only: %d, walked only: %d" % [
		warmed_keys.size(), walked_keys.size(), only_warmed, only_walked])
	for code: String in by_code:
		if by_code[code].size() > 1:
			var names: PackedStringArray = []
			for shader: Shader in by_code[code]:
				var file: String = shader.resource_path.get_file() if shader.resource_path != "" else "(built)"
				names.append("%s [%s]" % [file, shaders[shader]["user"]])
			print("   same code %s in %d Shaders: %s" % [code, by_code[code].size(), "; ".join(names.slice(0, 6))])
	if _detail:
		var lines: PackedStringArray = []
		for shader: Shader in shaders:
			var info: Dictionary = shaders[shader]
			lines.append("   shader %s %s [%s]%s" % [info["code"], info["file"].get_file() if info["file"] != "" else "(built)",
					info["user"], _mark(info["key"], walked_keys, warmed_keys)])
		for k: String in std_keys:
			lines.append("   std %s %s [%s]%s" % [k.md5_text().left(6), _describe(std_keys[k]["material"]), std_keys[k]["user"],
					_mark(k, walked_keys, warmed_keys)])
		lines.sort()
		for line: String in lines:
			print(line)
		# Material objects per standard look (one look is one program however many materials carry it).
		var per_key: Dictionary = {}
		for info: Dictionary in all.values():
			if String(info["key"]).begins_with("std"):
				per_key[info["key"]] = int(per_key.get(info["key"], 0)) + 1
		for k: String in per_key:
			if per_key[k] > 4:
				print("   std %s: %d materials, first drawn by %s" % [k.md5_text().left(6), per_key[k], std_keys[k]["user"]])
	_results[id] = {"shader_objects": shaders.size(), "distinct_codes": by_code.size(), "standard_looks": std_keys.size(),
		"programs": shaders.size() + std_keys.size(), "built_again": extra_objects, "warmed_only": only_warmed,
		"walked_only": only_walked}


## " (warmed only)" for a key only the warm-up draws, " (walked only)" for one only the level's own nodes do.
func _mark(key: String, walked_keys: Dictionary, warmed_keys: Dictionary) -> String:
	if not walked_keys.has(key):
		return "  (warmed only)"
	if not warmed_keys.has(key):
		return "  (walked only)"
	return ""


## A standard material's look in words: the settings that make its shader (ShaderWarmup.shader_key's), as far
## as they're not the defaults.
func _describe(m: Material) -> String:
	var b := m as BaseMaterial3D
	if b == null:
		return m.get_class()
	var parts: PackedStringArray = []
	parts.append(["opaque", "alpha", "scissor", "hash", "depth-prepass"][b.transparency])
	parts.append(["unshaded", "lit", "per-vertex"][b.shading_mode])
	if b.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
		parts.append(["", "add", "sub", "mul", "premul"][b.blend_mode])
	parts.append(["cull-back", "cull-front", "two-sided"][b.cull_mode])
	if b.depth_draw_mode != BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY:
		parts.append(["", "depth-always", "depth-never"][b.depth_draw_mode])
	if b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		parts.append("billboard%d" % b.billboard_mode)
	if b.vertex_color_use_as_albedo:
		parts.append("vertex-colour")
	if b.albedo_texture != null:
		parts.append("albedo-texture")
	if b.emission_enabled:
		parts.append("emission")
	if b.no_depth_test:
		parts.append("no-depth-test")
	if b.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
		parts.append("distance-fade")
	if b.proximity_fade_enabled:
		parts.append("proximity-fade")
	if b.disable_fog:
		parts.append("no-fog")
	if b.use_point_size:
		parts.append("point-size")
	return " ".join(parts)
