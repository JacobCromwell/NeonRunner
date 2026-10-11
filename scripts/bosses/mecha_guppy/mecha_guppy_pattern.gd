class_name MechaGuppyPattern
extends RefCounted
## Mecha Guppy and Captain Cogs' pattern through phases 1 and 2 (GDD §10; task E5e-b2): what the shark and the pirate
## do on each step of the climb (MechaGuppyClimb.Step k: roof k, its pads and hut, the higher roof k + 1), timed by
## where the runner is, the same on every step alike (nothing changes with time but the phase: GDD §10, no escalation).
## DESIGN-TBD (docs/questions/e5e.md): the whole pattern. Each step:
## - Mecha Guppy's bite (MechaGuppyShark.bite): as the runner nears roof k's pads, the rumble and the shark rising
##   beside the roof's end (its warning, seen ahead); once the runner is up on the hut it bites the roof's end off
##   below and behind them (bite_length, never past the hut's start: the floor they should have left), the collision
##   and the look together (MechaGuppyStairs.eat_roof), with rubble flying. It never eats the floor the runner is on
##   (it waits for them to be on the hut) nor the higher roof (the safe drop). Still busy with the step before's hit
##   (phase 2's closer steps), it bites once free, while there's time before this step's hit.
## - The volley on roof k + 1's run (roof_spots: two spots in phase 1, one in phase 2): spots from where the runner
##   lands (or where the roof is full width beside a pier) to short of the next hut, nearest first, planned as the
##   runner nears them by the Floating Head's salvo rules (MechaGuppyBombs.plan_spots); their circles never show before
##   the hut's deadline (so they never tell a rider which lanes lead up: only the owner's two cues do).
## - The landing spot (phase 2: landing_spots): where a rider comes down onto roof k + 1, dodged by a switch in the
##   air as they drop (on a pier, only where it has another lane to switch to).
## - The hut's bombs (phase 2: hut_bombs): on the hut over a rider, bursting on its top (the owner: the ceiling between
##   them blocks it).
## - The hit: at the hut's deadline (every rider is committed), Captain Cogs throws at the chasm in front of roof k + 1
##   beside the lanes that lead up, on the side with more lanes that don't (hit_back before the roof's front there),
##   and Mecha Guppy rises there to eat (MechaGuppyShark.breach; until then it lurks deep, giving nothing away), its
##   jaws open as the bomb comes down: the bomb falls into the stretch it has eaten through, where it's exposed and in
##   the line of fire (GDD §10): a hit (MechaGuppy.register_hit). A runner who keeps climbing lands one a step: 4 end
##   phase 1, 6 phase 2.
## Attacks only while the pattern runs (MechaGuppy.attacks_live: not in an intro, not in phase 3's stub, not once won);
## the shark's bite of the floor left behind is the level being eaten, not an attack, so it goes on in an intro too.

## Hut bombs come this far apart once a rider has settled on the hut (seconds).
const HUT_GAP: float = 0.6
## An event whose moment the runner is already this far past (metres: a review moving them on) is skipped.
const STALE: float = 30.0
## A bite put off while the shark was busy must still have this long to spare before the step's hit (seconds).
const BITE_SPARE: float = 0.3

var boss: MechaGuppy
var tuning: MechaGuppyTuning
var world: RunWorld
var climb: MechaGuppyClimb
## Tests: false throws no hit bombs and keeps the shark down (a fight in which no hit ever lands, to show nothing
## escalates).
var hits_enabled: bool = true
## What's been done (each once a step): "bite:k", "roof:k", "land:k", "hut:k:i", "lurk:k", "hit:k".
var _done: Dictionary = {}
## When the rider settled on each step's hut (fight time).
var _settled: Dictionary = {}


func _init(p_boss: MechaGuppy) -> void:
	boss = p_boss
	tuning = boss.tuning
	world = boss.world
	climb = boss.climb


## Every physics frame the fight runs (MechaGuppy's ticks).
func tick() -> void:
	var p: Player = world.player
	if p == null or not p.alive or climb.steps.is_empty():
		return
	var d: float = p.distance
	var k0: int = maxi(climb.step_index_at(d) - 1, 0)
	for k: int in range(k0, mini(k0 + 3, climb.steps.size())):
		var step: MechaGuppyClimb.Step = climb.steps[k]
		if step.top:
			break
		if boss.bites_live():
			_bite(step, p)
		if boss.attacks_live():
			_roof_volley(step, p)
			_landing_spot(step, p)
			_hut_bombs(step, p)
			_lurk(step, p)
			_hit(step, p)


# --- Mecha Guppy's bite ---------------------------------------------------------------------------

func _bite(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "bite:%d" % step.index
	if _done.has(key):
		return
	var speed: float = maxf(p.speed, 1.0)
	if p.distance < step.pad - tuning.bite_warning * speed:
		return
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index]
	if p.distance > roof.end + STALE or roof.end >= MechaGuppyClimb.FAR * 0.5:
		_done[key] = true
		return
	# Still busy with the step before's hit (phase 2's closer steps): it bites as soon as it's free, while the bite can
	# still be over before this step's hit (MechaGuppyShark.bite logs one it's too late for as skipped).
	var bite_seconds: float = tuning.bite_warning + tuning.bite_dive + tuning.bite_rise + tuning.bite_hold + tuning.bite_snap \
		+ tuning.bite_sink + BITE_SPARE
	if boss.shark.busy() and p.distance < step.deadline - bite_seconds * speed:
		return
	_done[key] = true
	var cut: float = maxf(roof.end - tuning.bite_length, step.hut_start)
	var side: int = -1 if hash([boss.def.rng_key(), "bite", step.index]) % 2 == 0 else 1
	var index: int = step.index
	var pad: float = step.pad
	boss.shark.bite({"side": side, "edge": roof.end, "top": roof.top, "roof": index, "cut": cut,
		"may_break": func() -> bool: return _left_roof(index, pad)})


## True once nobody can be on roof `index` any more: the runner is up on a hut (or dead) past its pads at `pad`.
func _left_roof(index: int, pad: float) -> bool:
	var p: Player = world.player
	if not p.alive:
		return true
	return p.surface == Player.Surface.CEILING and p.distance >= pad - 0.5


## The bite's snap (MechaGuppyShark.on_snap): the roof's end goes, collision and look, and its rubble flies.
func on_snap(action: Dictionary) -> void:
	var index: int = int(action.get("roof", -1))
	var box: AABB = boss.stairs.eat_roof(index, float(action.get("cut", 0.0)))
	if box.size.z <= 0.01:
		return
	var colors := PackedColorArray()
	var beach := world.skin as BeachSkin
	if beach != null:
		colors = PackedColorArray([beach.boardwalk_color, beach.bamboo_colors[0], beach.thatch_color, beach.timber_color])
	world.effects.rubble(box, colors, Vector3(0.0, -2.0, 0.0), index)
	var near: float = clampf(1.0 - absf(-box.get_center().z - world.player.distance) / 50.0, 0.2, 1.0)
	world.effects.shake(0.3 * near, 0.35)
	boss.log_event(&"roof_eaten", {"roof": index, "cut": float(action.get("cut", 0.0)), "end": float(action.get("edge", 0.0))})


# --- The volleys --------------------------------------------------------------------------------

## The track distances of up to `count` spots, `spacing` apart, from the first a runner who can first switch at
## `s_open` has room to dodge (every escape switch and the margin), short of `limit`.
func _spot_places(s_open: float, count: int, limit: float, speed: float) -> Array[float]:
	var out: Array[float] = []
	var t: MovementTuning = world.tuning
	var first: float = s_open + (tuning.max_escape_lanes * t.lane_switch_time + tuning.dodge_margin + 0.05) * speed \
		+ tuning.blast_depth * 0.5 + t.hurtbox_size.z * 0.5
	var spacing: float = tuning.spot_spacing * t.pace()
	for i: int in count:
		var at: float = first + spacing * float(i)
		if at > limit:
			break
		out.append(at)
	return out


## Where a spot on roof k + 1 may lie at the latest: short of the next hut, its blast and its clearance.
func _limit(step: MechaGuppyClimb.Step) -> float:
	if step.index + 1 >= climb.steps.size():
		return -MechaGuppyClimb.FAR
	var next: MechaGuppyClimb.Step = climb.steps[step.index + 1]
	if next.top:
		return climb.roofs[step.index + 1].end - 10.0
	return next.hut_start - MechaGuppyBombs.HUT_CLEAR - tuning.blast_depth * 0.5 - MechaGuppyBombs.FLOOR_CLEAR


## Phase 1's volley on roof k + 1's run (roof_spots), thrown as the runner nears its first spot, never before the
## hut's deadline.
func _roof_volley(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "roof:%d" % step.index
	if _done.has(key) or step.index + 1 >= climb.steps.size():
		return
	var count: int = MechaGuppyTuning.per_phase(tuning.roof_spots, boss.phase_index)
	if count <= 0:
		return
	var speed: float = maxf(p.speed, 1.0)
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
	var s_open: float = maxf(step.land, roof.full_from())
	var ats: Array[float] = _spot_places(s_open, count, _limit(step), speed)
	if ats.is_empty():
		_done[key] = true
		return
	var lock_at: float = maxf(ats[0] - (tuning.lock_seconds + tuning.arrival_seconds) * speed, step.deadline)
	if p.distance < lock_at:
		return
	_done[key] = true
	if p.distance > ats[0] or p.distance > lock_at + STALE:
		return
	var plan: Dictionary = roof_volley(step, p.lane, p.distance, speed)
	boss.bombs.throw_spots(MechaGuppyBombs.Kind.SPOT, step.index, plan["spots"], float(plan["s_open"]))


## Phase 1's volley on roof k + 1 as it would be thrown at a runner in `lane` at `d0` running at `speed` (the pattern
## throws it so; the tests plan it from every lane): {spots (MechaGuppyBombs.plan_spots'), s_open (where the runner can
## first switch to dodge: their landing, or where the roof is full width beside a pier)}; no spots in a phase without
## them, or with no room for one.
func roof_volley(step: MechaGuppyClimb.Step, lane: int, d0: float, speed: float) -> Dictionary:
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
	var s_open: float = maxf(step.land, roof.full_from())
	var count: int = MechaGuppyTuning.per_phase(tuning.roof_spots, boss.phase_index)
	var ats: Array[float] = _spot_places(s_open, count, _limit(step), maxf(speed, 1.0)) if count > 0 else []
	var spots: Array[Dictionary] = []
	if not ats.is_empty():
		var seed: int = hash([boss.def.rng_key(), "roof", step.index, boss.lane_count()])
		spots = boss.bombs.plan_spots(lane, d0, s_open, ats, roof.top, boss.phase_index, seed, speed)
	return {"spots": spots, "s_open": s_open}


## Phase 2's landing spot on roof k + 1 (landing_spots): where a rider comes down, dodged in the air as they drop.
func _landing_spot(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "land:%d" % step.index
	if _done.has(key) or step.index + 1 >= climb.steps.size():
		return
	if MechaGuppyTuning.per_phase(tuning.landing_spots, boss.phase_index) <= 0:
		return
	var speed: float = maxf(p.speed, 1.0)
	var ats: Array[float] = _landing_places(step, speed)
	if ats.is_empty():
		_done[key] = true
		return
	var lock_at: float = maxf(ats[0] - (tuning.lock_seconds + tuning.arrival_seconds) * speed, step.deadline)
	if p.distance < lock_at:
		return
	_done[key] = true
	if p.distance > ats[0] or p.distance > lock_at + STALE or p.surface != Player.Surface.CEILING and p.distance < _drop(step):
		return
	var plan: Dictionary = landing_volley(step, p.lane, p.distance, speed)
	boss.bombs.throw_spots(MechaGuppyBombs.Kind.SPOT, step.index, plan["spots"], float(plan["s_open"]))


## Phase 2's landing spot on roof k + 1 as it would be thrown at a rider in `lane` at `d0` running at `speed` (the
## pattern throws it so; the tests plan it from every lane): {spots, s_open (where a rider can first switch to dodge it:
## off the hut's end, in the air)}; no spots in a phase without one, or with no room for it.
func landing_volley(step: MechaGuppyClimb.Step, lane: int, d0: float, speed: float) -> Dictionary:
	var drop: float = _drop(step)
	var ats: Array[float] = _landing_places(step, maxf(speed, 1.0))
	var spots: Array[Dictionary] = []
	if not ats.is_empty():
		var seed: int = hash([boss.def.rng_key(), "land", step.index, boss.lane_count()])
		spots = boss.bombs.plan_spots(lane, d0, drop, ats, climb.roofs[step.index + 1].top, boss.phase_index, seed, speed)
	return {"spots": spots, "s_open": drop}


## Where a rider drops off step `step`'s hut: where the lanes that lead up end (RUN_ON runs them on, REACH_BACK ends
## them all), past the foot's reach.
func _drop(step: MechaGuppyClimb.Step) -> float:
	return (step.hut_end() if step.cue == MechaGuppyClimb.Cue.RUN_ON else step.deadline) + world.tuning.foot_half_depth


## Where the landing spots lie (landing_spots of them, the first no nearer than the landing): room to dodge from the
## drop, short of the next hut.
func _landing_places(step: MechaGuppyClimb.Step, speed: float) -> Array[float]:
	var count: int = MechaGuppyTuning.per_phase(tuning.landing_spots, boss.phase_index)
	if count <= 0:
		return []
	var ats: Array[float] = _spot_places(_drop(step), count, _limit(step), speed)
	if not ats.is_empty():
		ats[0] = maxf(ats[0], step.land + tuning.blast_depth * 0.5 + 0.3)
	return ats


## Phase 2's bombs on the hut a rider hangs from (hut_bombs): over their lane where they'd be, on the hut's top.
func _hut_bombs(step: MechaGuppyClimb.Step, p: Player) -> void:
	var count: int = MechaGuppyTuning.per_phase(tuning.hut_bombs, boss.phase_index)
	if count <= 0 or p.surface != Player.Surface.CEILING or not p.grounded or p.distance < step.hut_start \
			or p.distance >= step.deadline or absf(p.ceiling_y - step.hut_y) > 0.1:
		return
	if not _settled.has(step.index):
		_settled[step.index] = boss.fight_time()
	var speed: float = maxf(p.speed, 1.0)
	for i: int in count:
		var key: String = "hut:%d:%d" % [step.index, i]
		if _done.has(key) or boss.fight_time() < float(_settled[step.index]) + HUT_GAP * float(i):
			continue
		_done[key] = true
		var at: float = p.distance + (tuning.lock_seconds + tuning.arrival_seconds) * speed
		var lane: int = p.lane
		if lane < 0 or lane >= step.ends.size() or at > step.ends[lane] - 1.0:
			continue
		boss.bombs.throw_at(MechaGuppyBombs.Kind.HUT, lane, at, step.hut_y + TrackBuilder.HULL_THICKNESS)


## Once a rider is up on the hut (and the shark has bitten their roof), it swims deep under where the hit will come, out of
## sight (MechaGuppyShark.lurk), so it can surge up in time.
func _lurk(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "lurk:%d" % step.index
	if not hits_enabled or _done.has(key) or p.surface != Player.Surface.CEILING or p.distance < step.pad or p.distance >= step.deadline \
			or step.index + 1 >= climb.roofs.size() or boss.shark.busy():
		return
	_done[key] = true
	var spot: Dictionary = hit_spot(step)
	if spot.is_empty():
		return
	boss.shark.lurk({"x": world.geo.lane_x(int(spot["lane"])) + float(spot["x_off"]), "at": float(spot["at"]),
		"top": float(spot["y"]), "side": int(spot["side"]), "open_at": INF, "step": step.index})


## The hit (see the header): at the hut's deadline, the bomb thrown at the chasm in front of roof k + 1 under the lanes
## that don't lead up, and Mecha Guppy rising there with its jaws open as it lands.
func _hit(step: MechaGuppyClimb.Step, p: Player) -> void:
	var key: String = "hit:%d" % step.index
	if _done.has(key) or p.distance < step.deadline or step.index + 1 >= climb.roofs.size():
		return
	_done[key] = true
	if p.distance > step.deadline + STALE or not hits_enabled:
		return
	var spot: Dictionary = hit_spot(step)
	if spot.is_empty():
		return
	var d: Dictionary = boss.bombs.throw_at(MechaGuppyBombs.Kind.HIT, int(spot["lane"]), float(spot["at"]), float(spot["y"]),
		float(spot["x_off"]), tuning.hit_seconds)
	boss.shark.breach({"x": float(d["x"]), "at": float(spot["at"]), "top": float(spot["y"]), "side": int(spot["side"]),
		"open_at": float(d["impact"]) - MechaGuppyShark.BREACH_EARLY, "step": step.index})


## Where step `step`'s hit lands: {lane (the lane that doesn't lead up beside the nearest that does, on the side with
## more of them; a seeded side on a tie), side (-1 left of the lanes that lead up, +1 right), x_off (from that lane's
## middle out to where the bomb falls: into the jaws of Mecha Guppy's head, which keeps MechaGuppyShark.LANE_CLEAR from
## the lanes that lead up, so on a narrow street it falls past the roof's side), at (hit_back before roof k + 1's front
## in that lane: over the chasm, the shark's head short of that roof's face), y (that roof's top)}; {} if every lane
## leads up (never: one always doesn't).
func hit_spot(step: MechaGuppyClimb.Step) -> Dictionary:
	var n: int = boss.lane_count()
	var left: int = step.up.x
	var right: int = n - 1 - step.up.y
	if left <= 0 and right <= 0:
		return {}
	var side: int = -1
	if right > left:
		side = 1
	elif right == left:
		side = -1 if hash([boss.def.rng_key(), "hit", step.index]) % 2 == 0 else 1
	var lane: int = step.up.x - 1 if side < 0 else step.up.y + 1
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
	var geo: TrackGeometry = world.geo
	var edge: float = geo.lane_x(step.up.x) - geo.lane_width * 0.5 if side < 0 else geo.lane_x(step.up.y) + geo.lane_width * 0.5
	var x: float = edge + side * (MechaGuppyShark.LANE_CLEAR + MechaGuppySharkModel.HALF_DEPTH * MechaGuppyShark.SCALE
		+ MechaGuppyShark.MOUTH_OUT)
	return {"lane": lane, "side": side, "x_off": x - geo.lane_x(lane), "at": roof.start_in(lane) - tuning.hit_back,
		"y": roof.top}
