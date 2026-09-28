class_name ZoneSkin
extends Resource
## The visual layer for one zone (CLAUDE.md, architecture principle 2). TrackBuilder creates
## every collision shape and gameplay node, then calls these hooks to decorate each abstract
## piece. Skins add meshes (later: lights, sounds, props) and never collision or gameplay.
## Hazards must keep the same colour and shape language in every skin (pink crackle = fence).
##
## `parent`-based hooks use the chunk's space, which is world space: x = sideways,
## y = up, z = -distance. Hooks that receive a gameplay node work in that node's local space.
##
## A level's darkness (LevelConfig.darkness; GDD §5, The Hush's darker lighting) reaches every skin
## through level_environment(): only the scenery darkens. apply_darkness() dims the sky and the
## distance fog, and sets the global shader uniform `scenery_light` (project.godot), which the mesh
## kit's scenery shaders (kit_solid's lit surfaces, facade, shopfront, road, drift) and the grey
## box's scenery material multiply their lit colour by. Glowing things keep their glow (hazards,
## triggers, neon, screens), and the ambient light and the sun that light the player and the enemies
## stay as they are, so hazards and enemies read as well as anywhere. A skin with scenery of its own
## drawn another way reads `scenery_light` too, or overrides apply_darkness() (calling it first).

## The dimmest the scenery gets, at darkness 1: darker, but never pitch black (the rule GDD §10 gives
## the Sleep Taker's arena, BossEncounter.MIN_LIGHT_LEVEL).
const MIN_SCENERY_LIGHT: float = 0.3
## The global shader uniform the scenery's shaders multiply their lit colour by (1 = the zone's own
## light).
const SCENERY_LIGHT: StringName = &"scenery_light"

## The scenery light set last (set_scenery_light), for tests and tools: the global uniform itself
## can't be read back in a headless run.
static var scenery_light_now: float = 1.0

## Which zone variant enemies dress in: the cyborgs' zone look (GDD §9.2, CyborgSuit.look_for) and the
## other enemies' weathering (&"scavenger" weathered, anything else clean). Each zone's value is listed
## in docs/ARCHITECTURE.md (Zone skins). Their hazard colours and shapes stay the same everywhere.
@export var enemy_variant: StringName = &"city"


func make_environment() -> Environment:
	return Environment.new()


## The environment for a level of this zone with the level's `darkness` (LevelConfig.darkness, 0–1):
## make_environment() with apply_darkness(). The run (LevelRun) builds its environment this way.
func level_environment(darkness: float) -> Environment:
	var env: Environment = make_environment()
	apply_darkness(env, darkness)
	return env


## Dims the scenery for a level's `darkness` (0 = the zone's own light, which it sets back): the sky
## (background energy) and the distance fog by scenery_light_for(darkness) (energy_factor), and the
## skin's lit surfaces through the `scenery_light` uniform. Glows, the ambient light and the sun are
## left alone (see the header). It dims the scene by as much on the Compatibility renderer.
func apply_darkness(env: Environment, darkness: float) -> void:
	var light: float = scenery_light_for(darkness)
	env.background_energy_multiplier *= energy_factor(light)
	env.fog_light_energy *= energy_factor(light)
	set_scenery_light(light)


## How lit the scenery is at `darkness` (0–1): 1 at 0, down to MIN_SCENERY_LIGHT at 1. A factor for
## linear space.
static func scenery_light_for(darkness: float) -> float:
	return lerpf(1.0, MIN_SCENERY_LIGHT, clampf(darkness, 0.0, 1.0))


## The factor on the environment's energies for a scenery `light`: the Compatibility renderer works in
## sRGB space, so it takes the light's sRGB equivalent (as the kit shaders' light_factor() does).
static func energy_factor(light: float) -> float:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return pow(maxf(light, 0.0), 1.0 / 2.2)
	return light


## Sets the `scenery_light` shader uniform (1 = the zone's own light). The run sets it for its level
## and back to 1 when it ends.
static func set_scenery_light(light: float) -> void:
	scenery_light_now = light
	RenderingServer.global_shader_parameter_set(SCENERY_LIGHT, light)


## One lane's solid floor. center/size describe the collision box, whose top is at y = 0.
## edge_start/edge_end say whether a gap borders the segment at that end.
func floor_segment(_parent: Node3D, _center: Vector3, _size: Vector3, _lane_x: float,
		_edge_start: bool, _edge_end: bool) -> void:
	pass


## One side wall between two track distances. face_x is the wall face's signed world x.
func wall_section(_parent: Node3D, _side: int, _face_x: float, _start: float, _end: float) -> void:
	pass


## An electric fence's energy field, the size of its hitbox and centred on the hazard.
## ground_y is the floor height in hazard-local space; gapped fences are open underneath.
func fence(_hazard: Hazard, _size: Vector3, _ground_y: float, _gapped: bool) -> void:
	pass


## A sign on a wall, the size of its hitbox and centred on the hazard.
func wall_sign(_hazard: Hazard, _size: Vector3) -> void:
	pass


## A ceiling section. center/size describe the collision box; its underside is the surface.
## lane_edges_x are the world x positions of the seams between ceiling lanes.
func hull(_parent: Node3D, _center: Vector3, _size: Vector3, _lane_edges_x: Array[float]) -> void:
	pass


## An anti-grav pad, the size of its trigger volume and centred on it. The floor is at -size.y / 2.
func pad(_trigger: Area3D, _size: Vector3) -> void:
	pass


## A ramp onto the wall on `side`, the size of its trigger volume and centred on it.
func ramp(_trigger: Area3D, _size: Vector3, _side: int) -> void:
	pass


## A speed pad, the size of its trigger volume and centred on it. The floor is at -size.y / 2.
func speed_pad(_trigger: Area3D, _size: Vector3) -> void:
	pass


func finish_line(_parent: Node3D, _width: float, _distance: float) -> void:
	pass
