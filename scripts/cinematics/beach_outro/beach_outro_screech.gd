class_name BeachOutroScreech
extends CarPassenger
## The runner's screech friend in the Beach's outro (the owner, October 15, 2026: "our character's screech friend also
## hops up onto the bar"): the screech from the Gangland outro's passenger seat (CarPassenger, its sitting body and
## head: ScreechModel's own triangles, posed), still in Gangland's look, plus the screeches' running body
## (ScreechModel.mesh(), calm: its spines down) for when it trots or runs beside the runner and hops. The cinematic
## places it every step (BeachOutro._place_screech), so it is worked out from the time; this node only shows one
## body or the other and poses the sitting one. Visual only.
## Its space: the origin on the ground (or the counter) under its hips, facing -z.

## Its running body's scurry (ScreechModel: the legs' and tail's speed) when trotting and when running flat out.
const TROT_SCURRY: float = 0.35
const RUN_SCURRY: float = 1.0

var size: float = 0.55
var runner_body: MeshInstance3D
## Now: sitting (true) or on its feet, running (false).
var sitting: bool = true


func setup_friend(p_size: float, variant: StringName) -> void:
	name = "Screech"
	size = p_size
	seat = Vector3.ZERO
	sitting_meshes()
	var material: ShaderMaterial = ScreechModel.material(variant)
	screech = _part("Screech", _body_mesh, material)
	head = _part("Head", _head_mesh, material)
	runner_body = _part("Running", ScreechModel.mesh(), material)
	runner_body.scale = Vector3.ONE * size
	runner_body.visible = false
	sit(0.0, 0.0, 0.0, 0.0)


## Sitting at time `t`: its head turned `head_yaw` radians (+ left) and tipped `head_up` (+ up), nodding by `nod`
## (0-1); breathing.
func sit(t: float, head_yaw: float, head_up: float, nod: float) -> void:
	sitting = true
	screech.visible = true
	head.visible = true
	runner_body.visible = false
	var breath: float = 1.0 + BREATH * sin(TAU * BREATH_RATE * t)
	var hips := Vector3(HIPS.x, 0.0, HIPS.z)
	var body := Transform3D(Basis.IDENTITY, seat) * Transform3D(Basis.from_scale(Vector3(size, size * breath, size)),
		Vector3.ZERO) * Transform3D(Basis.IDENTITY, -hips)
	screech.transform = body
	var turn := Basis(Vector3.UP, head_yaw) * Basis(Vector3.RIGHT, head_up - deg_to_rad(NOD_DEGREES) * nod)
	head.transform = body * Transform3D(turn, _neck_sat - turn * _neck_sat)


## On its feet: trotting or running (`pace` 0 trotting, 1 flat out).
func run(pace: float) -> void:
	sitting = false
	screech.visible = false
	head.visible = false
	runner_body.visible = true
	runner_body.set_instance_shader_parameter(&"scurry", lerpf(TROT_SCURRY, RUN_SCURRY, clampf(pace, 0.0, 1.0)))
