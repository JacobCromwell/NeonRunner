class_name BeachOutroRaid
extends Node3D
## The Golden Convergence's ships over the beach in the Beach's outro (the owner, October 15, 2026: "Cut to another
## image of the spaceships that load the missiles in the final boss fight flying forward. Then cut back to the beach.
## The ships are flying above, dropping bombs, causing big explosions"): the final fight's refill ships
## (GoldenConvergenceShipModel: the gilded cargo hull, its racks of missiles along its flanks, its engines glowing pale
## blue) flying in a V along the track, high over the beach; the bombs are their racks' missiles (the model's
## rack_missile), each falling from under the ships, nose first, onto its spot; each lands in one of the game's shared
## yellow-and-red fireballs (FireballPool, GDD §11: every explosion is one; one slot a bomb, built with the props, so
## nothing is built mid-scene). Everything is worked out from the time (update), so stepping or skipping shows the
## same; the fireballs burn on real frames once set off, as everywhere. Visual only: no hitbox, no damage.
## DESIGN-TBD (docs/questions/f2e.md): the ships' formation and height, the bombs' number, places and size.

const BOSS_SKIN_PATH: String = "res://data/bosses/golden_boss_skin.tres"
const SPEED_FX_PATH: String = "res://data/tuning/speed_fx.tres"
## The ships' belly is this wide each way (metres: a street's width, as the fight builds them).
const HALF_WIDTH: float = 7.5
## A bomb's size against a rack missile's (they're the racks' own, a little bigger so they read from the street).
const BOMB_SCALE: float = 1.4
## A bomb falls from this far under the ships' bellies.
const DROP_UNDER: float = 1.5

var tuning: BeachOutroTuning
var stage: CineStage
var ships: Array[Node3D] = []
var bombs: Array[MeshInstance3D] = []
var fireballs: FireballPool
## Which bombs have landed (their fireball set off).
var landed: Array[bool] = []
## The beach's level beside the street (the open beach's sand and the sea's surface, under the promenade).
var beach_y: float = -1.4


func setup(p_stage: CineStage, p_tuning: BeachOutroTuning) -> void:
	name = "Raid"
	stage = p_stage
	tuning = p_tuning
	var beach := stage.skin as BeachSkin
	if beach != null:
		beach_y = -beach.beach_drop
	var skin := load(BOSS_SKIN_PATH) as GoldenSkin
	if skin == null:
		skin = GoldenSkin.new()
	var edges: Array[float] = []
	for k: int in 4:
		edges.append(-HALF_WIDTH + HALF_WIDTH * 2.0 * float(k + 1) / 5.0)
	var m: Dictionary = GoldenConvergenceShipModel.meshes(HALF_WIDTH, edges, skin)
	var slots: Array[Vector3] = GoldenConvergenceShipModel.rack_slots(HALF_WIDTH)
	for i: int in tuning.ships:
		var ship := Node3D.new()
		ship.name = "Ship%d" % i
		add_child(ship)
		MeshBatch.add_instance(ship, m["hull"], "Hull")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m["rack_missile"]
		mm.instance_count = slots.size()
		for k: int in slots.size():
			mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, slots[k]))
		var racks := MultiMeshInstance3D.new()
		racks.name = "Racks"
		racks.multimesh = mm
		racks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ship.add_child(racks)
		ships.append(ship)
	for k: int in tuning.bombs.size():
		var b: MeshInstance3D = MeshBatch.add_instance(self, m["rack_missile"], "Bomb%d" % k)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.visible = false
		bombs.append(b)
		landed.append(false)
	var fx: SpeedFxTuning = load(SPEED_FX_PATH) as SpeedFxTuning if ResourceLoader.exists(SPEED_FX_PATH) else null
	var own: SpeedFxTuning = fx.duplicate() as SpeedFxTuning if fx != null else SpeedFxTuning.new()
	own.fireball_pool = maxi(tuning.bombs.size(), 1)
	fireballs = FireballPool.new()
	fireballs.name = "Fireballs"
	add_child(fireballs)
	fireballs.setup(own)
	update(0.0)


## Where ship `i` of the V is at `t` (track space: its belly's middle): the lead in the middle, the others back and
## out to either side in turn; all flying along the track, over the bar at over_bar_at.
func ship_point(i: int, t: float) -> Vector3:
	var n: BeachOutroTuning = tuning
	var rank: int = (i + 1) / 2
	var side: float = 0.0 if i == 0 else (-1.0 if i % 2 == 1 else 1.0)
	var along: float = n.bar_at + n.ship_speed * (t - n.over_bar_at) - float(rank) * n.ship_spacing.y
	return Vector3(side * float(rank) * n.ship_spacing.x, n.ship_height, along)


## Where bomb `k` lands (track space): on the street, or down on the beach past the walls' line.
func impact(k: int) -> Vector3:
	var b: Vector4 = tuning.bombs[k]
	var x: float = b.y
	var y: float = 0.0
	if x < stage.wall_x(-1) or x > stage.wall_x(1):
		y = beach_y
	return Vector3(x, y, tuning.bar_at + b.z)


## When bomb `k` lands (seconds).
func land_time(k: int) -> float:
	return tuning.bombs[k].x


## Where bomb `k` is at `t` while it falls (track space): dropped from under the ships with their speed along the
## track, falling under gravity onto its spot, nose first.
func bomb_point(k: int, t: float) -> Vector3:
	var n: BeachOutroTuning = tuning
	var u: float = clampf(1.0 - (land_time(k) - t) / maxf(n.bomb_fall, 0.05), 0.0, 1.0)
	var end: Vector3 = impact(k)
	var height: float = n.ship_height - DROP_UNDER - end.y
	return Vector3(end.x, end.y + height * (1.0 - u * u), end.z - n.ship_speed * n.bomb_fall * (1.0 - u))


## The ships and the bombs at `t`: each bomb shows while it falls; as it lands its fireball goes off (once).
func update(t: float) -> void:
	for i: int in ships.size():
		ships[i].global_transform = Transform3D(Basis.IDENTITY, stage.point(ship_point(i, t)))
	var n: BeachOutroTuning = tuning
	for k: int in bombs.size():
		var land: float = land_time(k)
		var falling: bool = t >= land - n.bomb_fall and t < land
		bombs[k].visible = falling
		if falling:
			var at: Vector3 = stage.point(bomb_point(k, t))
			var ahead: Vector3 = stage.point(bomb_point(k, t + 0.02)) - at
			var basis := Basis.looking_at(ahead.normalized(), Vector3.RIGHT) if ahead.length() > 0.0001 else Basis.IDENTITY
			bombs[k].global_transform = Transform3D(basis.scaled_local(Vector3.ONE * BOMB_SCALE), at)
		if t >= land and not landed[k]:
			landed[k] = true
			fireballs.play(stage.point(impact(k)), n.bombs[k].w, true)


## Bombs landed by `t` (tests).
func landed_by(t: float) -> int:
	var count: int = 0
	for k: int in tuning.bombs.size():
		if land_time(k) <= t:
			count += 1
	return count
