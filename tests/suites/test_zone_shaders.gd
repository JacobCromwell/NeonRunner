extends TestSuite
## Task I1 (the owner's "shader cleanup in every zone", October 14, 2026): one program per look, in each zone's
## first level, the Golden Palace and every built boss's arena.
##
## The renderer compiles a program for each Shader and for each set of a standard material's features, five or six
## of them (four the engine's own), and on the web every one is a wait at the level's load
## (tools/web/shader_programs.js, tools/measure/zone_shaders.gd). So in each of these, with the track's first stretch
## dressed, the boss in place and the shader warm-up's stage built: one look is one shader. No shader code is in two
## Shaders, and no two standard materials differ only in what the renderer ignores (the emission of an unshaded one:
## a look that is the glow's but for a missing emission, like the player's shadow or the Floating Head's tower cut,
## drew with a shader of its own). The pieces that once made their own (the shadow, a lair's dark recess, the speed
## lines) are checked in test_perf.

## Each zone's first level and the Golden Palace.
const ZONE_LEVELS: Array[String] = ["city/1", "gangland/1", "marketplace/1", "casino/1", "corporate/1", "beach/1",
	"dead_zone/1", "golden/1", "golden/3"]

var sim: RunSim
var campaign: Campaign
var _twice: PackedStringArray = []
var _twins: PackedStringArray = []
var _shaders_seen: int = 0
var _looks_seen: int = 0
var _bosses: PackedStringArray = []


func run() -> void:
	sim = RunSim.new(tree, tuning)
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	for id: String in ZONE_LEVELS:
		await _level(id)
	for step: CampaignStep in campaign.steps():
		if step.kind == CampaignStep.Kind.BOSS and step.boss != null and step.boss.is_built():
			await _boss(step)
	check(_shaders_seen > 100 and _looks_seen > 50, "the zones' levels and bosses were looked at (%d shaders, %d standard looks in all)" % [
		_shaders_seen, _looks_seen])
	check(_bosses.size() >= 6 and "city/boss" in _bosses, "every built boss's arena was built (%s)" % ", ".join(_bosses))
	check(_twice.is_empty(), "no level or boss arena draws one shader code from two Shaders: %s" % ", ".join(_twice.slice(0, 4)))
	check(_twins.is_empty(), "nor two standard materials that differ only in an unshaded one's emission: %s" % ", ".join(_twins.slice(0, 4)))


## A campaign level, as the App builds it (5 lanes), the layout from the shared cache.
func _level(id: String) -> void:
	var config: LevelConfig = campaign.configure(campaign.step(id), 5)
	var t: MovementTuning = config.movement_for(tuning)
	var layout: LevelLayout = LayoutCache.generate(config, t, LevelGenerator.load_for(config))
	var world := sim.build_world(layout, Loadout.full(App.catalog), t, config)
	await _look_at(id, world, t)


## A boss's fight in a bare world (the framework's tests' set-up: its arena planned and built, the boss set up in it).
func _boss(step: CampaignStep) -> void:
	var def: BossDef = step.boss
	var enc := BossEncounter.create(def)
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = 5
	ctx.tuning = ctx.config.movement_for(tuning)
	var arena: BossArena = enc.plan_arena(ctx)
	var world := sim.build_world(arena.layout, Loadout.full(App.catalog), ctx.tuning, ctx.config)
	enc.setup(world, ctx, arena)
	# A second of the fight: props a boss builds as the runner nears them (the Floating Head's towers, 340 m ahead)
	# are built by then.
	world.player.god_mode = true
	await sim.step_world(world, 1.0, [], [], false)
	_bosses.append(step.id)
	await _look_at(step.id, world, ctx.tuning)


## Notes the twins among the materials of `world` and its warm-up stage, then frees the world.
func _look_at(id: String, world: RunWorld, t: MovementTuning) -> void:
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	var stage := ShaderWarmup.new()
	stage.setup(world, camera)
	world.track.update(300.0, 300.0 / t.run_speed)
	world.track.dress_all()
	var drawn: Array[Material] = ShaderWarmup.materials_of(world)
	drawn.append_array(ShaderWarmup.materials_of(stage))
	var shaders_of_code: Dictionary = {}
	var keys_of_look: Dictionary = {}
	for m: Material in drawn:
		var sm := m as ShaderMaterial
		if sm != null and sm.shader != null:
			if not shaders_of_code.has(sm.shader.code):
				shaders_of_code[sm.shader.code] = {}
			shaders_of_code[sm.shader.code][sm.shader] = true
		var b := m as BaseMaterial3D
		if b != null:
			var look: String = look_key(b)
			if not keys_of_look.has(look):
				keys_of_look[look] = {}
			keys_of_look[look][ShaderWarmup.shader_key(b)] = true
	_shaders_seen += shaders_of_code.size()
	_looks_seen += keys_of_look.size()
	for code: String in shaders_of_code:
		if shaders_of_code[code].size() > 1:
			_twice.append("%s: %d Shaders of code %s" % [id, shaders_of_code[code].size(), code.md5_text().left(8)])
	for look: String in keys_of_look:
		if keys_of_look[look].size() > 1:
			_twins.append("%s: %d shaders for the look %s" % [id, keys_of_look[look].size(), look.md5_text().left(8)])
	stage.queue_free()
	camera.queue_free()
	await sim.free_world(world)


## What a standard material draws as, apart from what the renderer ignores: ShaderWarmup.shader_key's settings, but
## an unshaded material's emission isn't one (it draws its albedo alone).
static func look_key(b: BaseMaterial3D) -> String:
	var parts: PackedStringArray = []
	for setting: int in [b.transparency, b.shading_mode, b.blend_mode, b.cull_mode, b.depth_draw_mode, b.diffuse_mode,
			b.specular_mode, b.billboard_mode]:
		parts.append(str(setting))
	for f: int in BaseMaterial3D.FLAG_MAX:
		parts.append("1" if b.get_flag(f) else "0")
	for f: int in BaseMaterial3D.FEATURE_MAX:
		var on: bool = b.get_feature(f)
		if f == BaseMaterial3D.FEATURE_EMISSION and b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			on = false
		parts.append("1" if on else "0")
	for p: int in BaseMaterial3D.TEXTURE_MAX:
		parts.append("1" if b.get_texture(p) != null else "0")
	return ",".join(parts)
