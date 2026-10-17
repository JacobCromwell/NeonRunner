class_name CasinoGoldenDoor
extends Node3D
## The golden door in the casino hall's back wall (CasinoHall; the owner: "the chairman goes through a door and it
## closes behind him. It should be an elegant golden door"): two tall leaves of polished gold, each with raised panels
## framed in brass, a sunburst boss and a long brass handle, hinged at the opening's sides. They swing open into the
## passage behind as the Chairman comes up to it and swing shut behind him, the last stretch quick and heavy with a
## little rebound. Gold is lit metal, never glowing (GDD §5). Moved from the cinematic's clock (update()).
## Its space: the middle of the opening on the floor, in the wall's middle; -z (the hall's +z) into the passage.

const GOLD := Color(0.83, 0.64, 0.3)
const GOLD_DARK := Color(0.55, 0.4, 0.16)
const BRASS := Color(0.64, 0.49, 0.25)
## How far the leaves swing open (radians).
const OPEN_ANGLE: float = 1.45

var leaves: Array[Node3D] = []
var width: float = 2.4
var height: float = 3.8


func setup(solid: Material, p_width: float, p_height: float) -> void:
	name = "GoldenDoor"
	width = p_width
	height = p_height
	var half: float = width * 0.5
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "Leaf%s" % ("L" if side < 0.0 else "R")
		add_child(hinge)
		hinge.position = Vector3(side * half, 0.0, 0.0)
		var batch := MeshBatch.new()
		var s: MeshLayer = batch.layer(solid)
		# The leaf runs from its hinge toward the opening's middle (-side along x).
		var cx: float = -side * half * 0.5
		s.box(Vector3(cx, height * 0.5, 0.0), Vector3(half - 0.02, height, 0.1), GOLD, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 1.0)
		for face: float in [-1.0, 1.0]:
			var fz: float = face * 0.06
			# Two raised panels, framed in darker gold, and a sunburst boss between them.
			for py: float in [height * 0.28, height * 0.7]:
				var ph: float = height * (0.34 if py < height * 0.5 else 0.38)
				s.box(Vector3(cx, py, fz), Vector3(half - 0.32, ph, 0.03), GOLD_DARK, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.7)
				s.box(Vector3(cx, py, fz + face * 0.015), Vector3(half - 0.44, ph - 0.12, 0.03), GOLD, 0.0, MeshKit.PAT_CASINO_BRASS,
					MeshKit.ALL_FACES, 1.0)
			var boss := Vector3(cx, height * 0.49, fz + face * 0.02)
			for i: int in 8:
				var a: float = TAU * float(i) / 8.0
				var xf := Transform3D(Basis(Vector3.BACK, a) * Basis.from_scale(Vector3(0.035, 0.22, 0.02)),
					boss + Vector3(cos(a + PI * 0.5), sin(a + PI * 0.5), 0.0) * 0.11)
				s.box_xform(xf, GOLD, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 1.0)
			s.box(boss, Vector3(0.12, 0.12, 0.03), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 1.0)
			# The handle, a long brass bar near the leaves' meeting edge.
			var hx: float = -side * (half - 0.16)
			s.box(Vector3(hx, height * 0.46, fz + face * 0.05), Vector3(0.04, 0.7, 0.04), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS,
				MeshKit.ALL_FACES, 1.0)
			for hy: float in [height * 0.46 - 0.3, height * 0.46 + 0.3]:
				s.box(Vector3(hx, hy, fz + face * 0.025), Vector3(0.04, 0.04, 0.05), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 1.0)
		MeshBatch.add_instance(hinge, batch.to_mesh(), "Gold").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leaves.append(hinge)


## How far open the door is at time `t` (0 shut, 1 wide open).
static func openness(t: float, n: CasinoBossIntroTuning) -> float:
	if t < n.door_open_at:
		return 0.0
	var opening: float = smoothstep(n.door_open_at, n.door_open_at + n.door_open_seconds, t)
	if t < n.door_close_at:
		return opening
	var k: float = clampf((t - n.door_close_at) / maxf(n.door_close_seconds, 0.05), 0.0, 1.0)
	# Shutting: slow to start, then heavy and quick (an ease-in), a small rebound as it bangs home.
	var shut: float = k * k * k
	var after: float = t - (n.door_close_at + n.door_close_seconds)
	var rebound: float = 0.0
	if after > 0.0:
		rebound = 0.05 * sin(after * 22.0) * exp(-after * 9.0)
		return clampf(rebound, 0.0, 1.0)
	return opening * (1.0 - shut)


## Whether the door has banged shut by time `t`.
static func is_shut(t: float, n: CasinoBossIntroTuning) -> bool:
	return t >= n.door_close_at + n.door_close_seconds


func update(t: float, n: CasinoBossIntroTuning) -> void:
	var o: float = openness(t, n)
	for i: int in leaves.size():
		var side: float = -1.0 if i == 0 else 1.0
		# Into the passage (-z here): the left leaf turns about its hinge one way, the right the other.
		leaves[i].rotation.y = -side * OPEN_ANGLE * o
