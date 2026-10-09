class_name GanglandOutroTuning
extends Resource
## The Gangland outro's numbers (GanglandOutro; the owner's beats, October 9, 2026, GDD §6 Cinematics):
## data/cinematics/gangland_outro_tuning.tres. Times are seconds from its start; places are in track space
## (CineStage: x metres right of the start lane's centre, y up, z along the track), most of them from the Host
## (the first scene) or the car (the second). DESIGN-TBD (docs/questions/f2c.md): the staging these fill in.

@export_group("Length")
@export_range(8.0, 40.0, 0.1, "suffix:s") var duration: float = 21.2
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_in: float = 0.8
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_out: float = 0.8
## The fight's music fades out over this long as it opens: a quiet aftermath.
@export_range(0.0, 6.0, 0.1, "suffix:s") var music_fade: float = 2.5
## The screeches' sniffing is heard from here, and a last spark from the Host's dead implants.
@export_range(0.0, 5.0, 0.05, "suffix:s") var sniff_sound_at: float = 0.35
@export_range(0.0, 5.0, 0.05, "suffix:s") var spark_at: float = 1.1

@export_group("The rubble")
## How far along the stretch the Host lies (well along it: the first shot looks back up the street, which must be
## built 170 m back).
@export_range(170.0, 300.0, 1.0, "suffix:m") var host_at: float = 190.0
@export_range(0.0, 3.0, 0.05, "suffix:m") var host_x: float = 0.0
@export_range(150.0, 1000.0, 10.0, "suffix:m") var stage_length: float = 400.0
## The person's height (the fight holds them up at 1.75 m in the swarm's bulk; the runner is about 1.3 m).
@export_range(1.0, 2.2, 0.05, "suffix:m") var host_height: float = 1.45
## Their implants' glow, shorted out (the fight's are 2.2).
@export_range(0.0, 2.2, 0.05) var host_glow: float = 0.3
## The rubble round them: pieces, how far it spreads, and how high the heap they lie back against is.
@export_range(4, 60) var rubble_pieces: int = 30
@export_range(1.0, 6.0, 0.1, "suffix:m") var rubble_spread: float = 3.4
@export_range(0.2, 2.0, 0.05, "suffix:m") var heap_height: float = 0.75

@export_group("The screeches")
## How many sniff at the Host, and their size (the fight's creatures are 0.7).
@export_range(1, 8) var sniffers: int = 4
@export_range(0.3, 1.2, 0.01) var sniffer_scale: float = 0.72
## They sniff until they look up, startled by the runner; then they scuttle away, this fast, this far.
@export_range(0.5, 10.0, 0.05, "suffix:s") var look_up_at: float = 2.9
@export_range(0.5, 10.0, 0.05, "suffix:s") var scuttle_at: float = 3.25
@export_range(1.0, 20.0, 0.5, "suffix:m/s") var scuttle_speed: float = 8.0
@export_range(4.0, 40.0, 0.5, "suffix:m") var scuttle_distance: float = 16.0

@export_group("The runner walks over")
## They walk down the street from the start, at an even pace: at walk_from they're walk_back metres short of where
## they stop, beside the Host (so they arrive at walk_from + walk_back / walk_speed).
@export_range(0.0, 10.0, 0.05, "suffix:s") var walk_from: float = 1.6
@export_range(4.0, 30.0, 0.5, "suffix:m") var walk_back: float = 11.0
@export_range(0.5, 4.0, 0.05, "suffix:m/s") var walk_speed: float = 1.8
## Where they stop, from the Host's middle: beside them, on the Host's right.
@export var stop_offset: Vector3 = Vector3(-0.78, 0.0, -0.15)

@export_group("The key")
## The Host looks up at the runner, trembles harder and holds the key up to them; it glints; the runner reaches
## and takes it; the Host's hand sinks back; the runner looks at the key.
@export_range(0.0, 20.0, 0.05, "suffix:s") var host_looks_at: float = 7.3
@export_range(0.0, 20.0, 0.05, "suffix:s") var offer_at: float = 7.9
@export_range(0.2, 3.0, 0.05, "suffix:s") var offer_seconds: float = 1.2
@export_range(0.0, 20.0, 0.05, "suffix:s") var glint_at: float = 9.0
@export_range(0.0, 20.0, 0.05, "suffix:s") var reach_at: float = 9.2
@export_range(0.1, 2.0, 0.05, "suffix:s") var reach_seconds: float = 0.55
@export_range(0.2, 3.0, 0.05, "suffix:s") var sink_seconds: float = 1.3
@export_range(0.0, 20.0, 0.05, "suffix:s") var admire_at: float = 10.3
## How hard the Host trembles (degrees): always a little, harder as they hold the key up.
@export_range(0.0, 6.0, 0.1, "suffix:°") var tremble: float = 1.2
@export_range(0.0, 12.0, 0.1, "suffix:°") var tremble_offering: float = 4.5
## Where the key changes hands (from the Host's middle): both reach for it.
@export var handoff_point: Vector3 = Vector3(-0.45, 0.66, 0.05)
## The key's length.
@export_range(0.05, 0.4, 0.01, "suffix:m") var key_length: float = 0.21

@export_group("The cut")
## It fades to black from black_at, and cuts to the car's street under black.
@export_range(0.0, 30.0, 0.05, "suffix:s") var black_at: float = 11.2
@export_range(0.1, 2.0, 0.05, "suffix:s") var black_seconds: float = 0.6
@export_range(0.0, 1.0, 0.05, "suffix:s") var black_hold: float = 0.2

@export_group("The car")
## Where it's parked (x, z on the second stretch: well along it, as the reveal looks back up the street), its size
## (width, height, length), paint and accent.
@export_range(170.0, 300.0, 1.0, "suffix:m") var car_at: float = 220.0
@export_range(-3.0, 3.0, 0.05, "suffix:m") var car_x: float = 0.0
@export var car_size: Vector3 = Vector3(1.95, 1.0, 4.3)
@export var car_paint: Color = Color(0.3, 0.12, 0.9)
@export var car_accent: Color = Color(0.35, 0.85, 1.0)
## The runner walks up to its door from here (from the car's middle), this fast, arriving at the door's side.
@export var approach_from: Vector3 = Vector3(-2.4, 0.0, -5.5)
@export_range(0.5, 4.0, 0.05, "suffix:m/s") var car_walk_speed: float = 2.1
@export_range(0.0, 2.0, 0.05, "suffix:m") var door_gap: float = 0.5
## They raise the key and the car unlocks (its lights blink twice); the door swings up; they get in; the door
## comes down; its lights come on. They get in no sooner than DOOR_TURN after reaching the door
## (GanglandOutro.t_get_in).
@export_range(0.0, 30.0, 0.05, "suffix:s") var unlock_at: float = 13.9
@export_range(0.0, 30.0, 0.05, "suffix:s") var door_up_at: float = 14.3
@export_range(0.2, 3.0, 0.05, "suffix:s") var door_seconds: float = 0.9
@export_range(0.0, 30.0, 0.05, "suffix:s") var get_in_at: float = 15.3
@export_range(0.2, 3.0, 0.05, "suffix:s") var get_in_seconds: float = 0.85
@export_range(0.0, 30.0, 0.05, "suffix:s") var door_down_at: float = 15.9
@export_range(0.0, 30.0, 0.05, "suffix:s") var lights_at: float = 17.0

@export_group("It drives off")
## The cut to the road, the revving and the launch, then its acceleration and top speed.
@export_range(0.0, 30.0, 0.05, "suffix:s") var road_at: float = 17.5
@export_range(0.0, 30.0, 0.05, "suffix:s") var launch_at: float = 18.1
@export_range(2.0, 30.0, 0.5, "suffix:m/s²") var acceleration: float = 13.0
@export_range(10.0, 90.0, 1.0, "suffix:m/s") var top_speed: float = 46.0

@export_group("Cameras")
## The first shot: low beside the Host, looking back up the street as the runner comes; it pushes in slowly.
@export var rubble_cam: Vector3 = Vector3(3.3, 0.55, 0.6)
@export var rubble_cam_end: Vector3 = Vector3(2.9, 0.5, 0.3)
@export var rubble_look: Vector3 = Vector3(-0.7, 0.35, -1.8)
@export_range(20.0, 100.0, 1.0, "suffix:°") var rubble_fov: float = 55.0
## Over the runner's shoulder as they walk up (riding with them), looking at the Host.
@export_range(0.0, 20.0, 0.05, "suffix:s") var follow_at: float = 4.7
@export var follow_cam: Vector3 = Vector3(0.55, 1.05, -2.4)
@export_range(20.0, 100.0, 1.0, "suffix:°") var follow_fov: float = 52.0
## The hand-off, close and low in front of the Host (their face to the camera, the runner side on), looking at
## where the key changes hands, pushing in.
@export_range(0.0, 20.0, 0.05, "suffix:s") var handoff_at: float = 7.6
@export var handoff_cam: Vector3 = Vector3(1.15, 0.5, -2.45)
@export var handoff_cam_end: Vector3 = Vector3(0.85, 0.55, -1.95)
@export var handoff_look: Vector3 = Vector3(-0.4, 0.55, -0.05)
@export_range(20.0, 100.0, 1.0, "suffix:°") var handoff_fov: float = 46.0
## The car's reveal: low off its front corner, gliding round to its side as the runner comes to it (from the
## car's middle).
@export var reveal_cam: Vector3 = Vector3(-2.3, 0.32, 4.4)
@export var reveal_cam_end: Vector3 = Vector3(-3.3, 0.7, 2.6)
@export var reveal_look: Vector3 = Vector3(0.0, 0.42, 0.6)
@export var reveal_look_end: Vector3 = Vector3(-0.8, 0.6, -0.3)
@export_range(20.0, 100.0, 1.0, "suffix:°") var reveal_fov: float = 50.0
## On the road behind it, at road level, as it drives off down the street.
@export var road_cam: Vector3 = Vector3(0.35, 0.16, -6.0)
@export var road_look: Vector3 = Vector3(0.0, 0.5, 20.0)
@export_range(20.0, 100.0, 1.0, "suffix:°") var road_fov: float = 58.0
