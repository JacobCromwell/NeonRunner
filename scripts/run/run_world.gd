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
## ceiling's edge) plays the blocked wall entry's clank, a doodad's stop (task O2) a push's thud, and the dash
## smashing a falling gantryway's pillar (task Q3) a doodad's crunch (its walkway's creak follows: Gantryway).
const EVENT_SOUNDS: Dictionary = {&"lane_blocked": &"wall_blocked", &"ceiling_blocked": &"wall_blocked",
	&"speed_pad": &"ramp", &"doodad_stop": &"doodad_push", &"gantry_pillar_smash": &"doodad_smash"}
## The sparkle an output pad gives off as the runner arrives on it (task Q4): the teleporter's green-white.
const TELEPORT_SPARKLE := Color(0.6, 1.0, 0.65)

## The runner was teleported (task Q4; Player.teleported): from track distance `from_distance` to `to_distance`, from
## teleporter `entry`'s pad onto its output pad `output`. What lay in between is skipped already (_on_teleported); the
## camera cuts (RunCamera) and the flash shows (TeleportFlash).
signal teleported(from_distance: float, to_distance: float, entry: Dictionary, output: Dictionary)

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
## The climb is on (GDD §10, the Beach's boss, whose runner climbs ceilings and roofs 20-30 m above the
## street): the run camera climbs with the runner (RunCamera's climbing view: it frames them from the floor
## they're on or came from instead of the street, sees a ceiling from below at that ceiling's own height, and
## never sits inside a roof), the runner's blob shadow lies on the floor under them (Player.shadow_on_floor),
## and a landing's shake counts the fall down to the floor landed on (RunEffects). A boss turns it on; off
## (every level and every other boss fight), all three are as they always were.
var camera_climbs: bool = false:
	set(value):
		camera_climbs = value
		if player != null:
			player.shadow_on_floor = value

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
	player.shadow_on_floor = camera_climbs
	# The layout's own lists: wall gaps and dash walls the track gains later (extend_layout) count too.
	player.wall_gaps = layout.wall_gaps
	player.dash_walls = layout.dash_walls
	# Task O1: a level whose walls are a boundary (the Terminal's) bumps a runner off them.
	player.wall_running = layout.wall_running
	# Task O2: and one whose doodads stop the runner (the Terminal's debris) holds them at a doodad's front.
	player.doodads_stop = layout.doodads_stop
	# Task J2: the grapple's or a revive's save from a fall into a wall-run gap puts the runner on its lit wall.
	if config.has_feature(WallRunGapPlacement.FEATURE) or not layout.wall_run_gaps.is_empty():
		player.grapple_save = Callable(WallRunGapPlacement, &"grapple_save").bind(layout)
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
	# Task Q3: a falling gantryway crushes what's in its path as it comes down, and shakes the camera as it lands.
	track.gantryway_swept.connect(_on_gantryway_swept)
	track.gantryway_landed.connect(_on_gantryway_landed)
	# Task Q4: a teleporter skips the track between its pad and its output pad, and whatever it holds.
	player.teleported.connect(_on_teleported)

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


## A falling gantryway came down another tick (task Q3; Gantryway.swept): every enemy in its path is destroyed (GDD §5:
## "when it lands, it destroys any enemy in its path"; Gantryway.crushes), whatever it is but a boss's part: a kill the
## runner's score counts (Enemy.defeat with Gantryway.CRUSH_CAUSE; ScoreKeeper), as a gap an Octodog was baited into
## is. DESIGN-TBD (docs/questions/q3.md): crushing scores as any kill, with no bonus of its own.
func _on_gantryway_swept(g: Gantryway) -> void:
	for e: Enemy in director.active.duplicate():
		if is_instance_valid(e) and e.alive and not e.is_boss and g.crushes(e):
			e.defeat(Gantryway.CRUSH_CAUSE)


## A falling gantryway landed (task Q3): the camera shakes (GantrywayTuning.land_shake_strength and land_shake_seconds;
## the Screen shake setting scales it). Its crash, pieces and wreck are its own (Gantryway).
func _on_gantryway_landed(g: Gantryway) -> void:
	effects.shake(g.tuning.land_shake_strength, g.tuning.land_shake_seconds)


## The runner was teleported (task Q4; Player.teleported; GDD §5, Zone 9, proposed: the runner "skips the track in between
## and whatever it holds"), from `from` to `to` along the track, onto output pad `output` of teleporter `entry`:
## - the enemies (EnemyDirector.runner_teleported): those still to come whose spot lies behind `to` never come, those in
##   play behind it leave play, and every other one hears it (a charge-up or a wind-up under way is called off, so its next
##   attack warns from the start: Enemy.runner_teleported); a heli drone keeps its place ahead of the runner;
## - every shot in the air goes (ProjectilePool.clear_shots): none aimed at where the runner was flies on at where they are;
## - the credits between (CreditField.skip: those the magnet was pulling are collected) are passed for good, and the best
##   possible credit score leaves them out (ScoreKeeper.skip_credits), so taking a teleporter never costs a star;
## - the track is built ahead of `to` at once (TrackBuilder.update), so the view past the landing is there this frame;
## - the output pad gives off a sparkle, and `teleported` follows (RunCamera cuts, TeleportFlash shows; the sound is the
##   `teleport` event's, through PlayerSfx).
## DESIGN-TBD (docs/questions/q4.md 5 and 6): the credits skipped, and the shots in the air.
func _on_teleported(from: float, to: float, entry: Dictionary, output: Dictionary) -> void:
	director.runner_teleported(from, to)
	projectiles.clear_shots()
	score.skip_credits(credits.skip(from, to))
	track.update(to, player.elapsed)
	effects.burst(lane_point(int(output["lane"]), to + 0.5, 0.4), TELEPORT_SPARKLE, 18, 0.45)
	teleported.emit(from, to, entry, output)


func _add(node: Node, node_name: String) -> Node:
	node.name = node_name
	add_child(node)
	return node
