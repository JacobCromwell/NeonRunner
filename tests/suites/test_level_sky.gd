extends TestSuite
## A level's own sky over its zone's (LevelConfig.sky, LevelSky; owner, October 8, 2026): City 1 shows the
## sun about to rise (pinks and purples on the undersides of clouds), Gangland 3 a cloudy blood-red sky,
## the Marketplace's last level (Marketplace 2: the zone has two) a darkening sunset (deep blues, pink
## low down), and the Beach's last level (Sunset Strip; owner, October 9, 2026) the sun starting to set,
## not dark, with purples and oranges; every other level keeps its zone's sky, and the boss fight after a
## level keeps that level's sky (Campaign.configure_boss). Its uniforms are the sky shader's own, the run's
## environment takes them and its fog colour (ZoneSkin.level_environment) and nothing else (the light on the
## runner and the enemies, every glow, the fog's reach), a level's darkness still dims it, it never touches the zone's
## own environment, and its brightest stays under the glow threshold, so only hazards glow. The street's
## light follows it (the global `scenery_tint`, which every scenery shader that follows a level's darkness
## multiplies its lit colour by, and no glow does), never brighter than the zone's own, and back to white
## for a level without one. The sky shader's new looks (clouds, a glow on the horizon) are off by default,
## so no other zone's sky changes. A run taking the level's sky and tint, and endless mode leaving them
## out, are checked in test_app_flow.

## The levels with a sky of their own (campaign step id: the sky in data/skies/).
const LEVEL_SKIES: Dictionary[String, String] = {
	"city/1": "city_dawn",
	"gangland/3": "gangland_blood_red",
	"marketplace/2": "marketplace_sunset",
	"beach/2": "beach_sunset",
}
const SKY_SHADER: String = "night_sky.gdshader"
## Every scenery shader that follows a level's darkness (they declare `scenery_light`) is found under these.
const SHADER_DIRS: Array[String] = ["res://scripts"]
## Shaders that never take the street's light: hazards, triggers, glows, the feed, the enemies, the runner,
## the pickups and the sky.
const KEEPS: Array[String] = ["res://scripts/world/meshes/shaders/energy_field.gdshader",
	"res://scripts/world/meshes/shaders/kit_glow.gdshader", "res://scripts/world/meshes/shaders/cult_feed.gdshader",
	"res://scripts/world/meshes/shaders/night_sky.gdshader", "res://scripts/enemies/cyborg_body.gdshader",
	"res://scripts/characters/humanoid_body.gdshader", "res://scripts/run/pickup.gdshader"]
## Where the sky's brightest shows, just above the far skyline's lowest tops (night_sky.gdshader's
## skyline(): 0.02 in sin(elevation)).
const HORIZON_ELEVATION: float = 0.02


func run() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	check(campaign != null, "the campaign loads")
	if campaign == null:
		return
	_which_levels(campaign)
	_shader_defaults()
	for id: String in LEVEL_SKIES:
		var s: CampaignStep = campaign.step(id)
		if s == null or s.level.sky == null:
			continue
		var skin: ZoneSkin = s.level.skin if s.level.skin != null else s.zone.skin
		_applies(id, s.level.sky, skin)
		_never_glows(id, s.level.sky, skin)
		_street_light(id, s.level.sky, skin)
	_bosses(campaign)
	_tint_shaders()
	_moods(campaign)


## Only the levels the owner named have their own sky, the sky in data/skies/ named for each; every other
## campaign level keeps its zone's.
func _which_levels(campaign: Campaign) -> void:
	var own: int = 0
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		if LEVEL_SKIES.has(s.id):
			own += 1
			var path: String = "res://data/skies/%s.tres" % LEVEL_SKIES[s.id]
			check(s.level.sky != null and s.level.sky.resource_path == path,
				"%s has its own sky, %s" % [s.id, path.get_file()])
		else:
			check(s.level.sky == null, "%s keeps its zone's sky" % s.id)
	check(own == LEVEL_SKIES.size(), "every level with its own sky is in the campaign (%d)" % own)


## The boss fight after each zone's last level keeps that level's sky (none: the zone's own), its fog and
## its street light (owner, October 8, 2026).
func _bosses(campaign: Campaign) -> void:
	var with_sky: int = 0
	for s: CampaignStep in campaign.steps():
		if s.kind != CampaignStep.Kind.BOSS:
			continue
		var before: CampaignStep = _last_level(campaign, s.zone)
		var config: LevelConfig = campaign.configure_boss(s, 5)
		check(before != null and config.sky == before.level.sky,
			"%s has %s's sky (%s)" % [s.id, before.id if before != null else "?",
				config.sky.resource_path.get_file() if config.sky != null else "the zone's own"])
		if config.sky != null:
			with_sky += 1
	# GDD §5: the Sewer Swarm under Gangland 3's blood-red sky; The House, which follows Casino 2 since the Casino
	# was added (task K2), under the Casino's own sky (Casino 2 keeps its zone's).
	check(campaign.configure_boss(campaign.step("gangland/boss"), 5).sky == campaign.step("gangland/3").level.sky
		and campaign.step("gangland/3").level.sky != null and campaign.step("casino/2").level.sky == null
		and campaign.configure_boss(campaign.step("casino/boss"), 5).sky == null,
		"the Sewer Swarm fights under Gangland 3's sky and The House under the Casino's own (%d fights under a level's sky)"
		% with_sky)
	check(campaign.configure_boss(campaign.step("city/boss"), 5).sky == null,
		"the Floating Head under the City's own night sky (City 3 has it)")
	# A boss's intro is under the fight's sky, between the level and the fight; a zone's own intro and
	# outro keep the zone's.
	for s: CampaignStep in campaign.steps():
		if s.kind != CampaignStep.Kind.BOSS:
			continue
		var fight: LevelSky = campaign.configure_boss(s, 5).sky
		check(CineStage.sky_for(null, s.zone, &"boss_intro") == fight
			and CineStage.sky_for(null, s.zone, &"intro") == null and CineStage.sky_for(null, s.zone, &"outro") == null,
			"%s's intro is under the fight's sky; the zone's intro and outro under its own" % s.id)
	var gangland: ZoneDef = campaign.step("gangland/boss").zone
	check(gangland.boss_intro != null and CineStage.sky_for(null, gangland, &"boss_intro") == campaign.step("gangland/3").level.sky,
		"the Sewer Swarm's intro keeps Gangland 3's blood-red sky")


func _last_level(campaign: Campaign, zone: ZoneDef) -> CampaignStep:
	var last: CampaignStep = null
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s.zone == zone:
			last = s
	return last


## The looks a level's sky adds are off by default: no clouds, no glow on the horizon, and the horizon's
## gradient as it was, so every zone's own sky looks as before.
func _shader_defaults() -> void:
	var defaults: Dictionary = {"cloud_amount": 0.0, "sun_glow_strength": 0.0, "horizon_falloff": 0.55}
	for uniform: String in defaults:
		var value: Variant = _default(uniform)
		check(value != null and is_equal_approx(float(value), float(defaults[uniform])),
			"the sky shader's %s defaults to %s (%s)" % [uniform, defaults[uniform], value])


## A sky shader uniform's default, read from its code (a headless run's renderer keeps none): a float, or a
## vec3 as a Vector3. Null if it has none.
func _default(uniform: String) -> Variant:
	var re := RegEx.create_from_string("uniform (float|vec3) %s\\b[^=;]*= *([^;]+);" % uniform)
	var m: RegExMatch = re.search(MeshKit.shader(SKY_SHADER).code)
	if m == null:
		return null
	if m.get_string(1) == "float":
		return float(m.get_string(2))
	var parts: PackedStringArray = m.get_string(2).trim_prefix("vec3(").trim_suffix(")").split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


## The run's environment (ZoneSkin.level_environment) takes the sky's uniforms, as sRGB Vector3s for its
## colours, and its fog colour, and nothing else; darkness still dims it; and the zone's own environment
## is never touched.
func _applies(id: String, sky: LevelSky, skin: ZoneSkin) -> void:
	var names: Array[String] = []
	for u: Dictionary in MeshKit.shader(SKY_SHADER).get_shader_uniform_list():
		names.append(String(u["name"]))
	for uniform: String in sky.sky:
		check(names.has(uniform), "%s: %s is a sky shader uniform" % [id, uniform])
	var plain: Environment = skin.make_environment()
	var env: Environment = skin.level_environment(0.0, sky)
	var material := env.sky.sky_material as ShaderMaterial
	var plain_material := plain.sky.sky_material as ShaderMaterial
	check(material != null and material != plain_material, "%s: its sky is a material of its own" % id)
	if material == null:
		return
	var applied: bool = true
	for uniform: String in sky.sky:
		var want: Variant = sky.sky[uniform]
		var got: Variant = material.get_shader_parameter(uniform)
		if want is Color:
			applied = applied and got is Vector3 and (got as Vector3).is_equal_approx(LevelSky.srgb(want))
		else:
			applied = applied and got == want
	check(applied, "%s: the run's sky takes its uniforms (colours as sRGB)" % id)
	check(env.fog_light_color == sky.fog_color and sky.use_fog_color, "%s: and its fog colour" % id)
	check(env.ambient_light_color == plain.ambient_light_color and env.ambient_light_energy == plain.ambient_light_energy
		and env.glow_enabled == plain.glow_enabled and env.glow_intensity == plain.glow_intensity
		and env.glow_hdr_threshold == plain.glow_hdr_threshold and env.tonemap_mode == plain.tonemap_mode
		and env.fog_depth_begin == plain.fog_depth_begin and env.fog_depth_end == plain.fog_depth_end
		and env.fog_light_energy == plain.fog_light_energy and env.background_energy_multiplier == plain.background_energy_multiplier,
		"%s: the light on the runner and the enemies, every glow and the fog's reach stay the zone's" % id)
	var again: Environment = skin.make_environment()
	var untouched: bool = again.fog_light_color == plain.fog_light_color
	for uniform: String in sky.sky:
		untouched = untouched and (again.sky.sky_material as ShaderMaterial).get_shader_parameter(uniform) \
			== plain_material.get_shader_parameter(uniform)
	check(untouched, "%s: the zone's own sky is left as it was" % id)
	var dark: Environment = skin.level_environment(0.7, sky)
	check(is_equal_approx(dark.background_energy_multiplier,
		plain.background_energy_multiplier * ZoneSkin.energy_factor(ZoneSkin.scenery_light_for(0.7))),
		"%s: a level's darkness still dims it" % id)
	ZoneSkin.set_scenery_light(1.0)


## The street's light follows the sky: level_environment() sets the sky's tint (the zone's own light,
## white, without one), which only ever dims or tints the scenery, never brightens it, so the glows stay
## the brightest things on screen.
func _street_light(id: String, sky: LevelSky, skin: ZoneSkin) -> void:
	skin.level_environment(0.0, sky)
	check(ZoneSkin.scenery_tint_now == sky.scenery_tint and sky.scenery_tint != Color.WHITE,
		"%s: the street's light follows its sky (%s)" % [id, sky.scenery_tint])
	check(sky.scenery_tint.r <= 1.0 and sky.scenery_tint.g <= 1.0 and sky.scenery_tint.b <= 1.0
		and sky.scenery_tint.get_luminance() >= ZoneSkin.MIN_SCENERY_LIGHT,
		"%s: and never brightens the street, nor darkens it past a level's darkest" % id)
	skin.level_environment(0.0)
	check(ZoneSkin.scenery_tint_now == Color.WHITE, "%s: a level without its own sky has the zone's own light" % id)


## Every scenery shader that follows a level's darkness follows the street's light too, multiplying it in
## with the darkness; the hazards', glows', enemies' and the runner's never read it; the uniform is a
## project global.
func _tint_shaders() -> void:
	var found: Array[String] = []
	for dir: String in SHADER_DIRS:
		_shaders_in(dir, found)
	var scenery: int = 0
	for path: String in found:
		var code: String = FileAccess.get_file_as_string(path)
		if code.contains("global uniform float scenery_light;"):
			scenery += 1
			check(code.contains("global uniform vec3 scenery_tint;")
				and code.count("* scenery_tint") == code.count("light_factor(scenery_light)") + (1 if code.contains("float light = scenery_light;") else 0),
				"%s takes the street's light wherever it takes the darkness" % path.get_file())
	check(scenery >= 9, "every scenery shader is checked (%d)" % scenery)
	for path: String in KEEPS:
		check(not FileAccess.get_file_as_string(path).contains("scenery_tint"), "%s never takes it" % path.get_file())
	check(ProjectSettings.has_setting("shader_globals/scenery_tint"), "the street's light is a global shader uniform (project.godot)")


func _shaders_in(dir: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gdshader"):
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		_shaders_in(dir.path_join(sub), out)


## Its brightest (the horizon's colour with the haze and the glow on it just above the far skyline's
## lowest tops, as the sky shader adds them, and the clouds' lit undersides) stays under the
## environment's glow threshold, so the sky never blooms: only hazards glow in hazard colours (GDD §5),
## and a sunset's pink never reads as a fence's. Colours as linear, converted once (a bound: Forward+
## draws the zone's own colours darker still).
func _never_glows(id: String, sky: LevelSky, skin: ZoneSkin) -> void:
	var env: Environment = skin.level_environment(0.0, sky)
	var m := env.sky.sky_material as ShaderMaterial
	var el: float = HORIZON_ELEVATION
	var horizon: Color = _linear(m, "horizon_color") \
		+ _linear(m, "haze_color") * (_float(m, "haze_strength") * exp(-el / _float(m, "haze_height"))) \
		+ _linear(m, "sun_glow_color") * (_float(m, "sun_glow_strength") * exp(-el / _float(m, "sun_glow_height")))
	var brightest: float = maxf(maxf(horizon.r, horizon.g), horizon.b)
	var cloud: Color = _linear(m, "cloud_lit_color")
	check(brightest < env.glow_hdr_threshold and maxf(maxf(cloud.r, cloud.g), cloud.b) < env.glow_hdr_threshold,
		"%s: its sky never glows (brightest %.2f, under %.2f)" % [id, brightest, env.glow_hdr_threshold])


func _linear(m: ShaderMaterial, uniform: String) -> Color:
	var v: Variant = m.get_shader_parameter(uniform)
	if v == null:
		v = _default(uniform)
	var c: Color = Color(v.x, v.y, v.z) if v is Vector3 else v as Color
	return c.srgb_to_linear()


func _float(m: ShaderMaterial, uniform: String) -> float:
	var v: Variant = m.get_shader_parameter(uniform)
	return float(v if v != null else _default(uniform))


## The owner's three moods, broadly: City 1's dawn has clouds whose undersides catch pink, and a glow
## where the sun is about to rise; Gangland's is a cloudy, blood-red sky; the Marketplace's sunset is
## deep blue overhead with pink at the bottom of the sky.
func _moods(campaign: Campaign) -> void:
	var dawn: Dictionary = campaign.step("city/1").level.sky.sky
	var lit: Color = dawn.get("cloud_lit_color", Color.BLACK)
	check(float(dawn.get("cloud_amount", 0.0)) > 0.0 and lit.r > lit.g and lit.b > lit.g and lit.r > lit.b,
		"City 1's dawn: clouds, their undersides pink")
	check(float(dawn.get("sun_glow_strength", 0.0)) > 0.0, "and a glow where the sun is about to rise")
	var red: Dictionary = campaign.step("gangland/3").level.sky.sky
	var reds: bool = float(red.get("cloud_amount", 0.0)) >= 0.5
	for uniform: String in ["zenith_color", "horizon_color", "cloud_color", "cloud_lit_color"]:
		var c: Color = red.get(uniform, Color.WHITE)
		reds = reds and c.r > c.g * 2.0 and c.r > c.b * 2.0
	check(reds, "Gangland 3: a cloudy, blood-red sky")
	var sunset: Dictionary = campaign.step("marketplace/2").level.sky.sky
	var top: Color = sunset.get("zenith_color", Color.WHITE)
	var bottom: Color = sunset.get("haze_color", Color.BLACK)
	check(top.b > top.r and top.b > top.g and bottom.r > bottom.g and bottom.b > bottom.g * 0.9
		and float(sunset.get("haze_height", 1.0)) < 0.1,
		"Marketplace 2's sunset: deep blue overhead, pink at the very bottom")
