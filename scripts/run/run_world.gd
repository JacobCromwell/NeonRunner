class_name RunWorld
extends Node3D
## One run's gameplay world: the track, the player, enemies, projectiles, credits, pickups, effects
## and the score, plus everything they share (layout, config, tuning, rules, geometry, loadout).
## LevelRun adds the camera, HUD and flow on top; tests build a bare RunWorld (RunSim).
##
## Children update in tree order each physics frame: this node (track chunks, enemy spawns), then
## the player, the enemies, the projectiles, the credits, the pickups, and the power-ups last.
## Power-ups plug in by convention: if res://scripts/powerups/powerup_controller.gd exists, it is
## created as a child and given setup(world).

const POWERUPS_SCRIPT: String = "res://scripts/powerups/powerup_controller.gd"
## Player movement events that play a differently named sound. Every blocked move (a solid side, a
## ceiling's edge) plays the blocked wall entry's clank.
const EVENT_SOUNDS: Dictionary = {&"lane_blocked": &"wall_blocked", &"ceiling_blocked": &"wall_blocked",
	&"speed_pad": &"ramp"}

var config: LevelConfig
var layout: LevelLayout
var tuning: MovementTuning
var rules: GameRules
var powerup_tuning: PowerupTuning
var geo: TrackGeometry
var skin: ZoneSkin
var loadout: Loadout
var sfx_library: SfxLibrary

var track: TrackBuilder
var player: Player
var director: EnemyDirector
var projectiles: ProjectilePool
var credits: CreditField
## Armor, shield and grapple pickups (GDD §10: offered in boss fights, BossEncounter.offer_pickup).
var pickups: PickupField
var effects: RunEffects
var score: ScoreKeeper
## The power-up controller (null until the power-ups exist).
var powerups: Node
var sounds: PlayerSfx

var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice: int = 0


## Builds the whole world for a generated layout. `p_loadout` may be null (nothing equipped).
func build(p_config: LevelConfig, p_layout: LevelLayout, p_tuning: MovementTuning, p_rules: GameRules,
		p_powerups: PowerupTuning = null, p_loadout: Loadout = null, p_sfx: SfxLibrary = null) -> void:
	config = p_config
	layout = p_layout
	# The level's own run speed, if it has one (its zone's, GDD §3), as the generator built it with.
	tuning = config.movement_for(p_tuning)
	rules = p_rules
	powerup_tuning = p_powerups if p_powerups != null else PowerupTuning.new()
	loadout = p_loadout if p_loadout != null else Loadout.new()
	sfx_library = p_sfx
	skin = config.skin if config.skin != null else GreyboxSkin.new()
	geo = TrackGeometry.new(layout.lane_count, tuning)

	track = _add(TrackBuilder.new(), "Track") as TrackBuilder
	track.sfx = p_sfx
	track.set_layout(layout, tuning, skin)
	player = _add(Player.new(), "Player") as Player
	player.rules = rules
	player.setup(tuning, geo, layout.lane_count / 2)
	# The layout's own list: wall gaps the track gains later (extend_layout) count too.
	player.wall_gaps = layout.wall_gaps
	player.apply_loadout(DamageRules.Armor.create(rules, loadout.tier(&"armor"), loadout.has_armor()),
		loadout.charge(&"shield"), loadout.charge(&"grapple"),
		loadout.tier(&"claws") > 0,
		powerup_tuning.claws_wall_time_multiplier if loadout.tier(&"claws") > 0 else 1.0)
	player.set_equipment_look({"weapon_tier": loadout.tier(&"weapon"), "magnet": loadout.tier(&"magnet") > 0})
	director = _add(EnemyDirector.new(), "Enemies") as EnemyDirector
	projectiles = _add(ProjectilePool.new(), "Projectiles") as ProjectilePool
	credits = _add(CreditField.new(), "Credits") as CreditField
	pickups = _add(PickupField.new(), "Pickups") as PickupField
	effects = _add(RunEffects.new(), "Effects") as RunEffects
	effects.setup(self)  # G2: the shared impact spectacle (RunEffects, Speed effects).
	score = _add(ScoreKeeper.new(), "Score") as ScoreKeeper
	sounds = _add(PlayerSfx.new(), "Sounds") as PlayerSfx
	if p_sfx != null:
		sounds.setup(p_sfx)
	player.movement_event.connect(_on_player_event)

	director.setup(self)
	projectiles.setup(self)
	credits.setup(self)
	pickups.setup(self)
	score.setup(self)
	if ResourceLoader.exists(POWERUPS_SCRIPT):
		powerups = (load(POWERUPS_SCRIPT) as GDScript).new() as Node
		powerups.name = "Powerups"
		add_child(powerups)
		powerups.call(&"setup", self)
		# The player model shows what the power-ups carry and drops broken armor/shields.
		player.set_equipment_look(powerups.call(&"equipment"))
		powerups.connect(&"equipment_changed", player.set_equipment_look)
	track.update(0.0, 0.0)


func start() -> void:
	player.running = true


func player_distance() -> float:
	return player.distance


## The level clock: seconds since the run started (drives pulsing hazards).
func level_time() -> float:
	return player.elapsed


## World position of a lane at a track distance, `height` above the floor.
func lane_point(lane: int, at: float, height: float = 0.0) -> Vector3:
	return Vector3(geo.lane_x(lane), height, TrackGeometry.world_z(at))


## An EMP at `center` (GDD §9.1: a destroyed fence generator): fences within `radius` go dark for the
## rest of the level, and every enemy hears it (Enemy.on_emp: the Bad Dream dissolves). Returns the
## number of fences switched off.
func emp(center: Vector3, radius: float) -> int:
	var count: int = track.disable_fences_near(center, radius)
	for e: Enemy in director.active.duplicate():
		if is_instance_valid(e) and e.alive:
			e.on_emp(center, radius)
	effects.burst(center, Color(0.55, 0.85, 1.0), 40, 1.5)
	effects.shake(0.25, 0.3)
	play_sfx_at(&"emp", center)
	return count


## A non-positional sound from the library (UI-like: pickups, the player's own actions).
func play_sfx(sound: StringName) -> void:
	if sounds != null:
		sounds.play(sound)


## A positional sound at a world point (enemy telegraphs, explosions).
func play_sfx_at(sound: StringName, pos: Vector3) -> void:
	if sfx_library == null or not SfxLibrary.audible():
		return
	var stream: AudioStream = sfx_library.stream(sound)
	if stream == null:
		return
	if _voices.is_empty():
		for i: int in 8:
			var v := AudioStreamPlayer3D.new()
			v.unit_size = sfx_library.warning_full_volume_distance
			v.max_distance = sfx_library.warning_max_distance
			if AudioServer.get_bus_index(&"SFX") >= 0:
				v.bus = &"SFX"
			add_child(v)
			_voices.append(v)
	var voice: AudioStreamPlayer3D = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = sfx_library.volume(sound)
	voice.global_position = pos
	voice.play()


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	track.update(player.distance, player.elapsed)
	director.update(player.distance)


func _on_player_event(kind: StringName) -> void:
	play_sfx(EVENT_SOUNDS.get(kind, kind))


func _add(node: Node, node_name: String) -> Node:
	node.name = node_name
	add_child(node)
	return node
