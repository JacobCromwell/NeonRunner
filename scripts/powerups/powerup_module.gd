class_name PowerupModule
extends Node3D
## Base for one permanent power-up that the PowerupController runs (GDD §8). The controller creates
## a module only for an item that is owned and switched on (it's in the run's Loadout), so a module
## never has to check whether it should exist. Modules add their own visual nodes as children.
##
## The controller drives every module: physics_tick() after the rest of the world each physics
## frame (never while the game is paused), visual_tick() each rendered frame, and stop() when the
## player dies, the run ends or the controller goes away. Numbers are read from
## world.powerup_tuning every time, so live tuning (F6) applies at once.

## Shader code -> Shader, so every material using the same code shares one compiled shader.
static var _shaders: Dictionary = {}

var controller: PowerupController
var world: RunWorld
## Shop item id (&"weapon", &"dash", ...), which is also its icon name in the catalog.
var id: StringName = &""
## Owned tier (1-based).
var tier: int = 1


func setup(p_controller: PowerupController, p_id: StringName, p_tier: int) -> void:
	controller = p_controller
	world = p_controller.world
	id = p_id
	tier = p_tier
	name = String(p_id).to_pascal_case()
	_build()


func _build() -> void:
	pass


## Gameplay, once per physics frame after the player, enemies, projectiles and credits.
func physics_tick(_delta: float) -> void:
	pass


## Visuals, once per rendered frame (after the camera has moved).
func visual_tick(_delta: float) -> void:
	pass


## The player died or the run is over: end anything in progress and undo global changes.
func stop() -> void:
	pass


## This module's entry for PowerupController.hud_state().
func hud_entry() -> Dictionary:
	return controller.make_hud_entry(id, tier, 1.0, true, 0)


## Rotation from the player's floor-standing pose to how they stand on their current surface
## (GDD §3: floor, side walls, ceiling), matching the player's body roll. Local +y points away from
## the surface, +x to the player's right, -z forward.
static func surface_basis(player: Player) -> Basis:
	match player.surface:
		Player.Surface.CEILING:
			return Basis(Vector3.BACK, PI)
		Player.Surface.WALL:
			return Basis(Vector3.BACK, player.wall_side * PI * 0.5)
	return Basis.IDENTITY


## A new material for a power-up visual's shader code (the shader itself is shared).
static func shader_material(code: String) -> ShaderMaterial:
	if not _shaders.has(code):
		var shader := Shader.new()
		shader.code = code
		_shaders[code] = shader
	var mat := ShaderMaterial.new()
	mat.shader = _shaders[code]
	return mat


## The player's visible body height right now (lower while sliding).
static func body_height(player: Player) -> float:
	var t: MovementTuning = player.tuning
	var h: float = t.visual_size.y
	if player.is_sliding():
		h *= t.hurtbox_slide_height / maxf(t.hurtbox_size.y, 0.01)
	return h
