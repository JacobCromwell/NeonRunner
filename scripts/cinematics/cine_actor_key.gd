class_name CineActorKey
extends CineKey
## An actor's key (CineActor.keys): where it is at `time`, and from then on its pose, which way it faces
## and, for a cyborg, its face and aim. Positions are in track space (CineStage: x metres right of the
## start lane's centre, y metres up from the floor, z metres along the track); between keys the actor
## moves as `move` says (CinePath), and its stride keeps pace with the ground it covers.

## Where it is (track space). y off 0 is in the air (the runner jumps, or falls past the floor's edge).
@export var position: Vector3 = Vector3.ZERO
## Its pose from this key on (empty: keep the one before). The runner: `run` (it runs, walks or stands
## by how fast it moves, and is in the air above the floor), `slide`, `dash`, `stomp`, `dead`. A
## cyborg: `idle`/`walk` (by how fast it moves), `aim`, `run_away`, `cower`, `die` (falls, once).
@export var pose: StringName = &""
## True: it faces the way it moves (holding its heading while it stands). False: it turns to `yaw`.
@export var face_path: bool = true
## Its heading when not facing the way it moves, degrees: 0 faces down the track (the way the runner
## runs), 180 faces back toward an oncoming runner, + turns left.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var yaw: float = 0.0
## The runner's head turned from the way its body faces at this key, degrees (+ looks left): its chest,
## neck and head share the turn, and between keys it turns smoothly from one key's look to the next.
@export_range(-100.0, 100.0, 1.0, "suffix:°") var look: float = 0.0
## A cyborg's face from this key on (empty: keep it): neutral, aiming, shocked, dead, corrupt_grin,
## corrupt_broken (CyborgKit.Face).
@export var expression: StringName = &""
## A cyborg aims its arm cannon at this actor from this key on (&"none" stops; empty: keep).
@export var aim_at: StringName = &""
## A cyborg's cannon charge glow from this key on, 0-1 (below 0: keep). The red glow is its attack's
## warning in play, so a cinematic shows it only where an attack follows.
@export_range(-1.0, 1.0, 0.05) var charge: float = -1.0
