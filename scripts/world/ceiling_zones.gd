class_name CeilingZones
extends RefCounted
## The floor a ceiling keeps safe (GDD §3, changed September 26, 2026). The floor beneath a ceiling
## may be dangerous: it may hold gaps, hazards and enemies, and the ceiling is the way to escape
## them. Two stretches of floor around every ceiling section stay safe all the same:
## - Its landing zone. Wherever the player drops back to the floor, the floor is safe to land on:
##   from the section's end, for LevelConfig.hull_landing_seconds at run speed, no lane the section
##   covers holds a gap or a fence (every lane, for a ceiling over every lane; a narrow ceiling's
##   rider can only drop from its own lanes, GDD §3), and no floor enemy uses the floor there, in any
##   lane (LevelGenerator.enemy_floor_span).
## - Each anti-grav pad's spot, so the player can actually step on the pad. The pad's lane holds no
##   gap, fence or ramp, and no floor enemy standing in it uses the floor, from a full jump's length
##   before the pad (a player who cleared the lane's last obstacle lands before it) until its lift
##   has carried the player up to the hull (nothing in that lane catches them on the way up); and no
##   floor enemy in any other lane uses the floor where the pad lies.
## The ceiling itself is never required: the floor under it holds what the generator's patterns put
## there, with their usual fairness, and a floor runner can always pass the pad by (switch away from
## it or jump it). The generator keeps both stretches for every ceiling: a pattern's own
## (LevelGenerator) and those rules add (LevelGenerator.add_hull_with_pad, PadPlacement); rules that
## add floor enemies keep off them too (CyborgRules.obstacle_spans, Octodog.pad_or_landing_between).
## A narrow ceiling (B3) covers a range of lanes (LevelLayout.hull_lanes): its pads lie in that range
## and its landing zone covers those lanes; the rules that keep off landing zones in every lane (the
## cyborgs', the Octodog's) still do, which is safe for any range. Floor cuts planned in advance (B4)
## ask their questions here as well.

## Every lane, for the `lanes` of landing_clear() and clear_landing().
const ALL_LANES := Vector2i(0, 1 << 30)

## Metres of floor kept safe to land on after a ceiling section's end. DESIGN-TBD
## (docs/questions/b2.md): LevelConfig.hull_landing_seconds at run speed, clear of holes, fences
## and floor enemies' reach.
var landing: float = 0.0
## Metres of a pad's lane kept clear before the pad: a full jump at run speed. DESIGN-TBD
## (docs/questions/b2.md): what makes a pad one the player can step on.
var run_up: float = 0.0
## Metres of a pad's lane kept clear after the pad: how far the player runs while its lift carries
## them up to the hull. DESIGN-TBD, like run_up.
var rise: float = 0.0
## A pad's length along its lane.
var pad_length: float = 2.0
## A ramp's length along its lane (ramps sit in the outer lanes).
var ramp_length: float = 4.0
## The level's pace (MovementTuning.pace): floor enemies' reach (LevelGenerator.enemy_floor_span) is
## stretched by it.
var pace: float = 1.0
## Half a fence's depth along the track: a fence is in a stretch if any of it is.
var fence_half_depth: float = 0.15


## The zones for a level built from `config` (the landing's length; LevelConfig's defaults without
## one) at `speed` (`tuning`'s run speed when 0).
static func make(config: LevelConfig, tuning: MovementTuning, speed: float = 0.0) -> CeilingZones:
	var c: LevelConfig = config if config != null else LevelConfig.new()
	var v: float = speed if speed > 0.0 else c.movement_for(tuning).run_speed
	var z := CeilingZones.new()
	z.landing = c.hull_landing_seconds * v
	z.run_up = tuning.jump_distance(v)
	z.rise = lift_seconds(tuning) * v
	z.pad_length = tuning.pad_length
	z.ramp_length = tuning.ramp_length
	z.fence_half_depth = tuning.fence_depth * 0.5
	z.pace = v / MovementTuning.REFERENCE_SPEED
	return z


## Seconds an anti-grav pad's lift takes to carry the player from the floor up to the hull: they
## leave at antigrav_launch_velocity and fall toward the hull at the descending gravity (Player).
static func lift_seconds(tuning: MovementTuning) -> float:
	var v0: float = tuning.antigrav_launch_velocity
	var a: float = maxf(tuning.gravity() * tuning.fall_gravity_multiplier, 0.01)
	return (-v0 + sqrt(v0 * v0 + 2.0 * a * tuning.ceiling_height)) / a


## Where the player lands after ceiling section `hull`: [end, end + landing], in every lane it covers
## (LevelLayout.hull_lanes).
func landing_zone(hull: Dictionary) -> Vector2:
	var end: float = float(hull["end"])
	return Vector2(end, end + landing)


## The stretch of its lane a pad at `at` keeps clear: [at - run_up, at + pad_length + rise].
func pad_zone(at: float) -> Vector2:
	return Vector2(at - run_up, at + pad_length + rise)


## Where a pad at `at` lies, [at, at + pad_length]: no floor enemy uses the floor there.
func pad_spot(at: float) -> Vector2:
	return Vector2(at, at + pad_length)


## Every ceiling section's landing zone in `layout`, in the order of its hulls.
func landing_zones(layout: LevelLayout) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for h: Dictionary in layout.hulls:
		out.append(landing_zone(h))
	return out


## True if the floor in `zone` is safe to land on: no gap or fence in `lanes` (Vector2i(first, last);
## every lane by default, as under a ceiling over every lane), and no floor enemy's stretch, in any
## lane, reaches into it.
func landing_clear(layout: LevelLayout, zone: Vector2, lanes: Vector2i = ALL_LANES) -> bool:
	for g: Dictionary in layout.gaps:
		if gap_in(g, zone) and in_lanes(int(g["lane"]), lanes):
			return false
	for f: Dictionary in layout.fences:
		if fence_in(f, zone) and in_lanes(int(f["lane"]), lanes):
			return false
	for e: Dictionary in layout.enemies:
		if enemy_in(e, zone):
			return false
	return true


## True if a pad at `at` in `lane` can be stepped on: its lane is clear (pad_lane_clear) and no
## floor enemy is in the way (pad_enemies_clear).
func pad_clear(layout: LevelLayout, lane: int, at: float) -> bool:
	return pad_lane_clear(layout, lane, at) and pad_enemies_clear(layout, lane, at)


## True if `lane` holds no gap or fence in the pad's zone (pad_zone), and no ramp from the zone's
## start to the pad's end (a ramp would throw the player onto the wall before they reach the pad).
func pad_lane_clear(layout: LevelLayout, lane: int, at: float) -> bool:
	var zone: Vector2 = pad_zone(at)
	for g: Dictionary in layout.gaps:
		if gap_in(g, zone, lane):
			return false
	for f: Dictionary in layout.fences:
		if fence_in(f, zone, lane):
			return false
	for r: Dictionary in layout.ramps:
		if ramp_in(layout, r, Vector2(zone.x, at + pad_length), lane):
			return false
	return true


## True if no floor enemy is in the way of a pad at `at` in `lane` (pad_enemy_in).
func pad_enemies_clear(layout: LevelLayout, lane: int, at: float) -> bool:
	for e: Dictionary in layout.enemies:
		if pad_enemy_in(e, lane, at):
			return false
	return true


## True if enemy entry `e` (placed or about to be) keeps off every ceiling's safe floor in `layout`:
## no landing zone and no pad it would be in the way of (pad_enemy_in). Rules that add a floor enemy
## after the ceilings are in place (the host and Octodog guarantees) keep to this.
func enemy_clear(layout: LevelLayout, e: Dictionary) -> bool:
	for zone: Vector2 in landing_zones(layout):
		if enemy_in(e, zone):
			return false
	for p: Dictionary in layout.pads:
		if pad_enemy_in(e, int(p["lane"]), float(p["at"])):
			return false
	return true


## True if enemy entry `e` is in the way of a pad at `at` in `lane`: its floor stretch
## (LevelGenerator.enemy_floor_span) reaches the pad's zone (pad_zone) while it stands in that lane,
## or the spot where the pad lies (pad_spot) from any lane.
func pad_enemy_in(e: Dictionary, lane: int, at: float) -> bool:
	var zone: Vector2 = pad_zone(at) if int(e.get("lane", -1)) == lane else pad_spot(at)
	return enemy_in(e, zone)


## Takes out whatever keeps `zone` from being safe to land on in `lanes` (see landing_clear). Returns
## how many pieces and enemies went.
func clear_landing(layout: LevelLayout, zone: Vector2, lanes: Vector2i = ALL_LANES) -> int:
	var before: int = layout.gaps.size() + layout.fences.size() + layout.enemies.size()
	_keep(layout.gaps, func(g: Dictionary) -> bool: return not (gap_in(g, zone) and in_lanes(int(g["lane"]), lanes)))
	_keep(layout.fences, func(f: Dictionary) -> bool: return not (fence_in(f, zone) and in_lanes(int(f["lane"]), lanes)))
	_keep(layout.enemies, func(e: Dictionary) -> bool: return not enemy_in(e, zone))
	return before - (layout.gaps.size() + layout.fences.size() + layout.enemies.size())


## True if `lane` is within `lanes` (Vector2i(first, last)).
static func in_lanes(lane: int, lanes: Vector2i) -> bool:
	return lane >= lanes.x and lane <= lanes.y


## Takes out whatever keeps a pad at `at` in `lane` from being stepped on (see pad_clear): the gaps,
## fences and ramps in its lane's zone, and the floor enemies in its way (pad_enemy_in). Returns how
## many pieces and enemies went.
func clear_pad(layout: LevelLayout, lane: int, at: float) -> int:
	var zone: Vector2 = pad_zone(at)
	var ramp_zone := Vector2(zone.x, at + pad_length)
	var before: int = layout.gaps.size() + layout.fences.size() + layout.ramps.size() + layout.enemies.size()
	_keep(layout.gaps, func(g: Dictionary) -> bool: return not gap_in(g, zone, lane))
	_keep(layout.fences, func(f: Dictionary) -> bool: return not fence_in(f, zone, lane))
	_keep(layout.ramps, func(r: Dictionary) -> bool: return not ramp_in(layout, r, ramp_zone, lane))
	_keep(layout.enemies, func(e: Dictionary) -> bool: return not pad_enemy_in(e, lane, at))
	return before - (layout.gaps.size() + layout.fences.size() + layout.ramps.size() + layout.enemies.size())


## True if gap `g` reaches into `zone`, in `lane` (any lane with -1).
func gap_in(g: Dictionary, zone: Vector2, lane: int = -1) -> bool:
	return (lane < 0 or int(g["lane"]) == lane) and float(g["start"]) <= zone.y and float(g["end"]) >= zone.x


## True if any of fence `f` stands in `zone`, in `lane` (any lane with -1).
func fence_in(f: Dictionary, zone: Vector2, lane: int = -1) -> bool:
	return (lane < 0 or int(f["lane"]) == lane) and float(f["at"]) + fence_half_depth >= zone.x \
		and float(f["at"]) - fence_half_depth <= zone.y


## True if ramp `r` (in the outer lane on its side) reaches into `zone`, in `lane` (any with -1).
func ramp_in(layout: LevelLayout, r: Dictionary, zone: Vector2, lane: int = -1) -> bool:
	return (lane < 0 or layout.outer_lane(int(r["side"])) == lane) and float(r["at"]) <= zone.y \
		and float(r["at"]) + ramp_length >= zone.x


## True if enemy entry `e` uses the floor (LevelGenerator.enemy_floor_span, at the level's pace)
## anywhere in `zone`.
func enemy_in(e: Dictionary, zone: Vector2) -> bool:
	var span: Vector2 = LevelGenerator.enemy_floor_span(e, pace)
	return span.x <= zone.y and span.y >= zone.x


## Keeps the items of `list` for which `keep` returns true (in place, so typed arrays stay typed).
static func _keep(list: Array[Dictionary], keep: Callable) -> void:
	var out: Array[Dictionary] = []
	for item: Dictionary in list:
		if keep.call(item):
			out.append(item)
	list.assign(out)
