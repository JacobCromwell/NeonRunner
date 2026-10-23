class_name LevelLayout
extends RefCounted
## Pure-data description of one generated level, built from abstract gameplay pieces only.
## Positions along the track are distances in metres from the start (forward is positive).
## Lanes are indices 0..lane_count-1, left to right. Wall sides are -1 (left) and +1 (right).

## A doodad's size classes, smallest first (LevelLayout.doodads `size`; MovementTuning.doodad_size).
const DOODAD_SIZES: Array[StringName] = [&"small", &"medium", &"large"]
## The key that marks a gantryway's pillar among the doodads (task Q3: its gantryway's `id`; is_gantry_pillar).
const GANTRY_PILLAR: String = "gantryway"
## The key that marks a hole of a wall-run gap (gaps; wall_run_gaps): it isn't one to jump, so the checks on
## jumpable holes and rows of holes leave it out (is_wall_run_hole).
const WALL_RUN_HOLE: String = "wall_run"
## The key that marks a side wall gap (wall_gaps) that sets a wall runner down where they're meant to come off the
## wall: an extended wall run's notch at its platform's near end (WallRunGapPlacement.openings_of). Task S3: the
## Player keeps a move away from that wall the dismount it was until their wall run would have ended (wall_gap_at).
const SETS_DOWN: String = "sets_down"
## The key of a zone doodad that holds an enemy until it's smashed (task Q5; GDD §5, Zone 9, the owner, October 21,
## 2026: "some jars hold a curled-up Octodog", and "sometimes smashing an Octodog jar doodad releases its Octodog into
## the world"): the enemy's type. Its entry in `enemies` stands at the doodad's front in its lane, its params marked
## HELD (held_by, holder_of). Abstract, as every piece here: the skin dresses such a doodad as the zone's container
## with that enemy inside (ZoneSkin.held_doodad_look: the Ice Lab's Octodog jar), and smashing it (DashBreakable.smash,
## its entry marked "smashed") lets the enemy out (it watches its doodad: Octodog). Placed by its feature's rules
## (scripts/enemies/octodog_jar_rules.gd), never by the zone doodads' pass; one marked DECOY too holds an enemy that never
## comes out (one of the pass's own doodads, or one its rules stand where a zone doodad may). A doodad of the zone's that
## only looks like such a container (the skin's own variety) holds nothing.
const HOLDS: String = "holds"
## The params key of an enemy entry held in a doodad (HOLDS) until that doodad is smashed: true.
const HELD: String = "held"
## The key of a doodad marked HOLDS whose enemy never comes out (task Q5: a decoy, true): no entry of `enemies` stands in
## it (held_by is {}), but the skin dresses it and the dash breaks it exactly as one that releases its enemy, so the two
## can't be told apart (GDD §5, proposed: "a jar that will release its Octodog looks the same as one that won't").
## Marked by its feature's rules after the zone doodads' pass (octodog_jar_rules.gd, after_doodads), on doodads of the
## zone's own, or on new ones where a zone doodad may stand where the level has too few.
const DECOY: String = "decoy"

var lane_count: int = 3
var length: float = 0.0
## {lane, start, end}: a hole in the floor segment of one lane. A wall-run gap's holes (wall_run_gaps) also carry
## WALL_RUN_HOLE: true.
var gaps: Array[Dictionary] = []
## {lane, at, variant ("full" | "gapped"), pulsing, pulse_on, pulse_off, phase}
var fences: Array[Dictionary] = []
## {side, start, end, bottom, top}: blocks wall entry along its length and hurts on contact.
var signs: Array[Dictionary] = []
## {start, end}: a ceiling section over every lane, or {start, end, first_lane, last_lane} over a
## contiguous range of lanes only (a narrow ceiling, GDD §3: "ceilings don't have to cover every
## lane"). Read the range with hull_lanes(); a range over every lane is stored without the keys, so
## full-width ceilings stay exactly as they were. A ceiling scenario (task I4) marks its ceiling with
## "scenario" (CeilingScenarios.KEY), and a fenced ceiling records its pick as "pick": [from, to], from
## its first pad's run-up to its last safe pad (fenced_pick_between).
var hulls: Array[Dictionary] = []
## {lane, at}: anti-grav pad in a floor lane.
var pads: Array[Dictionary] = []
## {side, at}: ramp in the outermost lane on that side, launching onto the wall.
var ramps: Array[Dictionary] = []
## {lane, at}: speed pad in a floor lane (GDD §6 only names them; FB 21).
var speed_pads: Array[Dictionary] = []
## {at, surface ("floor" | "wall" | "ceiling"), lane (floor/ceiling), side (wall), height, value}.
## `height` is the distance from the surface (floor/ceiling) or the height on the wall.
var credits: Array[Dictionary] = []
## {type, at, lane, side, seed, params}: an enemy (or destructible) for EnemyDirector.
var enemies: Array[Dictionary] = []
## {lane, start, end, size, side, seed}: a zone doodad (GDD §3, owner's playtest September 30, 2026):
## a scenery piece standing in `lane` from `start` to `end` that never hurts. Running into its front
## pushes the player into the neighbouring lane on `side` (-1 left, +1 right); its sides block a lane
## switch like a solid side. `size` is its size class (DOODAD_SIZES: the skin picks the look, the
## movement tuning its width and height), `seed` varies the look. The generator plans them
## (LevelGenerator: doodads), the track builder builds them (TrackBuilder, ZoneSkin.doodad).
## A doodad in a row (task L3, the owner, October 17, 2026: rows of similar doodads) also holds `row`:
## [start, end], the whole row's stretch, from its first one's front to its last one's end, and `look`, the
## seed its look is picked by (its first one's `seed`): the row's doodads share its lane, size class, side and
## look, each its own entry with a seed of its own (doodad_extent).
## A doodad that holds an enemy until it's smashed (task Q5: an Octodog's jar) also holds HOLDS, the enemy's type
## (holds_enemy, held_by), and DECOY where that enemy never comes out (is_decoy).
var doodads: Array[Dictionary] = []
## {lane, start, end, warn, charge, keep, speed}: a floor cut planned in advance (task B4; GDD §9.9,
## the Buzz Overdrive's): the floor of `lane` from `start` to `end` turns into a gap during play, run
## from `end` back toward and past the player by its cause, keyed to the player's distance. Its fields
## and geometry: FloorCutPlan. The generator plans them (LevelGenerator.add_cut, only where GDD
## §9.9's limits allow), the track builder builds them as pieces of their own (FloorCut), and a cause
## runs each (FloorCut.advance_to).
var cuts: Array[Dictionary] = []
## {side, at, band ("full" | "low" | "high"), pulse_on, pulse_off, phase}: a wall fence (task B5; GDD
## §9.1): an electric fence across the wall-run path on wall `side` at track distance `at`, between
## emitters on the facade, that switches off and on on the level clock (pulse_on seconds on, pulse_off
## off, the floor fences' flicker and crackle before it switches on; `phase` 0–1 offsets it within its
## cycle). `band` is how much of the wall it covers: all of it ("full", passed by timing), or only the
## low or the high part (passed by entering the wall high or low). Its field reaches out from the
## facade over the wall runner's path only, never as far as a floor runner in the outer lane. Its
## fields and geometry: WallFencePlan. The generator places them (WallFencePlacement, only where
## they're fair), the track builder builds them as hazards (TrackBuilder), and the skin draws them
## (ZoneSkin.wall_fence).
var wall_fences: Array[Dictionary] = []
## {side, start, end}: a side wall gap (the `wall_gaps` feature, Zone 2 on; WallGapPlacement): wall
## `side` (-1 left, 1 right) has no wall-running surface from track distance `start` to `end`. The
## track builder leaves the wall out there and marks its edges (ZoneSkin.wall_gap), a runner can't
## get onto the wall there, and one on it drops off at the gap (Player.wall_supported). Sorted by
## start; both walls may have one over the same stretch; an extended wall run's notch carries SETS_DOWN: true. In a
## level whose walls are a row of narrow arches (task O1, the Terminal: WallGapTuning's Arches group) they are the open
## space between the arches, from before the track's first chunk to past its run-out, so the arches are exactly the
## walls' solid pieces (wall_solid_pieces).
var wall_gaps: Array[Dictionary] = []
## Whether a runner can step onto the side walls (LevelConfig.wall_running, which the generator copies here): false in a
## level whose walls are a boundary everywhere (task O1; GDD §5, Zone 8: the Terminal has no wall running). The player
## bumps off them there (Player.wall_running, which RunWorld sets from this), and the track builder draws each solid
## piece of wall whole and the open space between them without a wall gap's marks (ZoneSkin.wall_opening). Left out of
## to_dict() while true, so every other level's dictionary is the same as before.
var wall_running: bool = true
## {side, start, end}: a broken stump of a side wall's section (task O1; GDD §5, Zone 8: where one side's arch is
## missing, that side shows a section "cut off about halfway up", a crumbled ruin): wall `side` has a stump from track
## distance `start` to `end`, inside one of its wall gaps, opposite the other wall's arch. Scenery only: nobody runs on
## those walls. The generator places them with the arches (WallGapPlacement, the tuning's Arches group), the track
## builder has the skin draw each whole (ZoneSkin.wall_stump), after the opening it stands in. Sorted by start.
var wall_stumps: Array[Dictionary] = []
## {start, end, seed}: a dash wall (task H7a; GDD §9.14, owner, October 8, 2026): a building standing
## across every floor lane from track distance `start` (its face, toward the runner) to `end`, leaving the
## side walls open. The runner dashes through it, crashes through it without the dash (one hit: the armor
## or the shield takes it, else it kills) or passes it on a side wall; it crumbles whichever they do and
## stays broken for the rest of the attempt (its entry marked "smashed", with "broken_by"). `seed` varies
## its look. The generator places them (scripts/enemies/dash_wall_rules.gd, only where they're fair), the
## track builder builds each as a DashBreakable (TrackBuilder) and the skin dresses it (ZoneSkin.dash_wall).
var dash_walls: Array[Dictionary] = []
## {lane, at}: an electric fence hanging from a ceiling across `lane` at track distance `at` (task I4; GDD §3,
## "Ceiling scenarios": pick the right pad), always on. A fenced ceiling (fenced_ceiling_rules.gd) hangs rows of
## them across every lane it covers after its unsafe pads' arrival. The track builder builds each as an
## electrical hazard below the ceiling's underside (TrackBuilder, MovementTuning.ceiling_fence_depth), the skin
## draws it (ZoneSkin.ceiling_fence).
var ceiling_fences: Array[Dictionary] = []
## {lane, at}: a return pad on a ceiling's underside in `lane`, from track distance `at` to a pad's length on
## (task I4; GDD §3, "Ceiling scenarios": the treasure stash). A rider who steps on it drops back to the floor
## the way a ceiling's end drops them (Player). The generator places one over each treasure stash
## (treasure_stash_rules.gd); the track builder builds it as a trigger, the skin dresses it (ZoneSkin.return_pad).
var return_pads: Array[Dictionary] = []
## {lane, start, front, end, walls_from, pad, hull_start, keep_from, keep_to}: a treasure stash (task I4; GDD §3,
## "Ceiling scenarios"): a stretch of floor in `lane`, walled off by zone doodads, that only a ceiling's return pad
## (at `pad`, over the ceiling starting at `hull_start`) drops a player into. A doodad stands in its lane from
## `start`, and after a space a second one from `front` (the owner, October 18, 2026: "a doodad, a space, then a
## second doodad, and then the treasure"); doodads stand in both neighbouring lanes from `walls_from` to `end`, where
## it opens onto the track; inside lie its credits. Its floor, kept clear in every lane, runs from `keep_from` to
## `keep_to`.
## The pieces are ordinary entries of `doodads` (marked "stash"), `return_pads` and `credits` (marked "stash");
## this is the record that ties them together (treasure_stash_rules.gd, the checks and the credit pass).
var stashes: Array[Dictionary] = []
## {side, start, end, entry, approach, landing, wall_to}: a wall-run gap (task J2; the owner, October 15, 2026: "a gap
## over the ENTIRE floor (every lane), and the only way to cross is a wall run"): every floor lane is a hole from
## `start` to `end` (entries of `gaps` marked WALL_RUN_HOLE), and wall `side` (-1 left, 1 right) is the way across: lit
## from `entry` (the earliest a step onto it carries a standard wall run past `end`) to `end`, whole and clear of
## signs, wall enemies, wall fences and wall gaps until `wall_to`. Nothing stands in any lane from `approach` (where
## the clear run-in starts) to `landing` (where the safe landing floor ends). The generator places them
## (WallRunGapPlacement), the track builder builds the holes like any and the skin lights the wall
## (ZoneSkin.wall_run_guide). Sorted by start.
var wall_run_gaps: Array[Dictionary] = []
## Whether this level's zone doodads stop the runner instead of pushing (LevelConfig.doodads_stop, which the generator
## copies here; task O2, GDD §5 Zone 8: the Terminal's debris): the Player stops at one's front (Player.doodads_stop,
## which RunWorld sets from this). Left out of to_dict() while false, so every other level's dictionary is as before.
var doodads_stop: bool = false
## The debris maze's blocks (task O2; GDD §5, Zone 8: "doodads stand so thickly that the empty space between them forms
## a maze"; DebrisMaze, which places them and answers questions about them: its cells, which connect without a dash),
## in order, each {entry, start, end, exit, walls, rooms, breaks}: open floor in every lane from `entry` (its run-in) to
## its first wall's front at `start`, its walls and rooms to its last wall's back at `end`, and open floor again to
## `exit` (its breather). `walls`: {start, end, size, open} each, a wall of debris across every lane but its `open`
## lanes (its openings), `size` the size class of its pieces; `rooms`: {start, end, dividers} each, between one wall's
## back and the next one's front, every lane but its `dividers` (debris along it the room's whole length) open, so
## the open lanes between dividers are its cells. `breaks`: the least dashes its way through takes (DebrisMaze
## .min_breaks). Its debris are ordinary `doodads` entries marked "maze" (the block's index), "part" ("wall" or
## "divider") and "index" (the wall's or the room's). An escape block (task O5, DebrisMaze.is_escape) also has
## `escape` {lane, at} (its anti-grav pad), its last room open in every lane, and its last wall a barrier of `pieces`
## pieces in every lane. Left out of to_dict() while empty.
var maze: Array[Dictionary] = []
## {side, entry, start, end, gems_from, gems_to}: a line of wall-hop credits (task N1; GDD §7, "Wall-hop credits",
## owner, October 9, 2026: "some long walls carry high-value credits further along than one wall run reaches, so only
## a player inventive enough to wall hop collects them"): on wall `side` (-1 left, 1 right), laid out for a runner who
## steps onto it at `entry` and wall hops (WallHopPath); its high-value credits lie from `gems_from` to `gems_to`, and
## the wall and the outer lane beside it are clear from `start` to `end`. Its credits are ordinary `credits` entries
## marked WallHopPlacement.LEAD (along the first wall run) and WallHopPlacement.GEM (the high-value ones, left out of
## the stars' best score: star_credit_value). The generator places them (WallHopPlacement, in its credit pass).
var wall_hops: Array[Dictionary] = []
## {id, lane, start, end, pillar, side, calm, seed}, with `intro` on a level's first where it gives the feature a start,
## and `both` where both lanes beside it are kept clear for the whole calm stretch (an introduction's: room to step out
## either way, task Q3's proposal, DESIGN-TBD; GantrywayTuning.intro_both_sides), else only the lane on its `side`: a
## falling gantryway (task Q3; GDD §5, Zone 9, the owner, October 21, 2026: "an upper walkway over one lane only, looking
## like a ceiling section"; "pillars stand in the floor lanes holding them up"; "dashing through a pillar knocks down its
## long section of gantryway"): a walkway hanging at a ceiling's height over `lane` from track distance `start` to `end`,
## never walked on, held by a pillar standing in that lane under its near end (both GDD §5's proposals), its front at
## `pillar`. The pillar is an ordinary entry of `doodads` marked GANTRY_PILLAR (its `id`): a runner who meets it without
## the dash is pushed into the lane on its `side` like by any doodad; the dash smashes it, and the walkway falls on its
## lane over about a second, crushing every enemy under it and hitting a runner still under it as it lands (Gantryway).
## `calm` [from, to] is its calm stretch, from the pillar's front to the end of the step out of the lane, which nothing is
## timed onto (doodad_between counts it in its lane). `seed` varies its look. Marked "fallen" once it fell on an attempt
## and "landed" once it lay flat (the attempt's own copy, as a smashed doodad is marked). The generator places them
## (scripts/enemies/gantryway_rules.gd, only where they're fair), the track builder builds each (TrackBuilder, Gantryway)
## and the skin dresses its walkway and its pillar (ZoneSkin.gantryway, ZoneSkin.gantry_pillar). Sorted by start.
var gantryways: Array[Dictionary] = []
## {id, lane, at, end, side, outputs, light, blink, phase, calm, span, seed}, with `intro` on a level's first where it
## gives the feature a start: a teleporter (task Q4; GDD §5, Zone 9, the owner, October 21, 2026: "a square pad with a
## look all its own, with a green, slightly space-age antenna on it. Touching it teleports the runner to an output pad
## further down the track"): its square pad fills `lane` from track distance `at` (its front) to `end`; a runner on the
## floor whose feet touch it is put on one of its `outputs` ({lane, at, end}: a square pad in the teleporter's look
## without the antenna, further down the track; one, or a left and a right, the left first: GDD §5, "some teleporters
## have a left and a right output pad"), the same way past its front as they were past the input's, keeping their speed
## (Player). Which one: its antenna's light (Teleporter.lit_side): with one output pad, that one (`light` 0); with two,
## the side lit when the runner touches the pad (-1 left, 1 right): `light` stays on one side where `blink` is 0 (GDD §5:
## "always left or always right"), and where `blink` is above 0 changes side every `blink` seconds of the level clock,
## from `light` at `phase` (0–1 of a whole cycle) at the run's start, so every attempt at a seed blinks the same.
## `side` is the lane beside it kept clear as the way around it (it's never required). `calm` [[lane, from, to], ...] are
## the stretches no attack is timed onto (teleporter_between, which doodad_between counts): its approach in its lane,
## each output pad's landing in that pad's lane (lane -1: every lane, an introduction's landing); `span` [from, to] the
## whole of what it keeps, from its approach to its last landing's end. `seed` varies its look. The generator places
## them (scripts/enemies/teleporter_rules.gd, only where they're fair), the track builder builds each (TrackBuilder,
## Teleporter) and the skin dresses its pads and its antenna (ZoneSkin.teleporter_pad, ZoneSkin.teleporter_antenna,
## ZoneSkin.teleporter_output). Sorted by `at`.
var teleporters: Array[Dictionary] = []


## Every list of pieces, by name. A level without doodads has no "doodads" key, one without floor
## cuts no "cuts" key, one without wall fences no "wall_fences" key, one without wall gaps no
## "wall_gaps" key, one without dash walls no "dash_walls" key, one without ceiling scenarios (task I4)
## no "ceiling_fences", "return_pads" or "stashes" key, one without wall-run gaps (task J2) no "wall_run_gaps" key,
## one without wall-hop credits (task N1) no "wall_hops" key, one without wall stumps (task O1) no "wall_stumps" key,
## one whose walls can be run on (every level but the Terminal's) no "wall_running" key, one whose doodads push and
## that has no debris maze (task O2) no "doodads_stop" or "maze" key, one without falling gantryways (task Q3) no
## "gantryways" key, and one without teleporters (task Q4) no "teleporters" key, so its dictionary (and every hash or dump
## of it) is the same as before those existed.
func to_dict() -> Dictionary:
	var out := {
		"lane_count": lane_count,
		"length": length,
		"gaps": gaps,
		"fences": fences,
		"signs": signs,
		"hulls": hulls,
		"pads": pads,
		"ramps": ramps,
		"speed_pads": speed_pads,
		"credits": credits,
		"enemies": enemies,
	}
	if not doodads.is_empty():
		out["doodads"] = doodads
	if not cuts.is_empty():
		out["cuts"] = cuts
	if not wall_fences.is_empty():
		out["wall_fences"] = wall_fences
	if not wall_gaps.is_empty():
		out["wall_gaps"] = wall_gaps
	if not dash_walls.is_empty():
		out["dash_walls"] = dash_walls
	if not ceiling_fences.is_empty():
		out["ceiling_fences"] = ceiling_fences
	if not return_pads.is_empty():
		out["return_pads"] = return_pads
	if not stashes.is_empty():
		out["stashes"] = stashes
	if not wall_run_gaps.is_empty():
		out["wall_run_gaps"] = wall_run_gaps
	if not wall_hops.is_empty():
		out["wall_hops"] = wall_hops
	if not wall_running:
		out["wall_running"] = false
	if not wall_stumps.is_empty():
		out["wall_stumps"] = wall_stumps
	if doodads_stop:
		out["doodads_stop"] = true
	if not maze.is_empty():
		out["maze"] = maze
	if not gantryways.is_empty():
		out["gantryways"] = gantryways
	if not teleporters.is_empty():
		out["teleporters"] = teleporters
	return out


## Appends every list of `other`'s pieces to this layout's (doodads, floor cuts, wall fences, wall gaps,
## dash walls, the ceiling scenarios' pieces, wall-run gaps, wall-hop lines, wall stumps, the debris maze's blocks, the
## falling gantryways and the teleporters included, whether or not this layout has any yet), and moves its end to other's
## if that's further. Whether its walls can be run on and whether its doodads stop the runner stay this layout's own. A
## gantryway's `id` (and its pillar's mark, GANTRY_PILLAR) is renumbered past this layout's own, so each still names its
## own pillar, and a teleporter's `id` likewise.
func append_pieces(other: LevelLayout) -> void:
	var first_gantryway: int = 0
	for g: Dictionary in gantryways:
		first_gantryway = maxi(first_gantryway, int(g.get("id", -1)) + 1)
	if first_gantryway > 0:
		for g: Dictionary in other.gantryways:
			g["id"] = int(g.get("id", 0)) + first_gantryway
		for d: Dictionary in other.doodads:
			if d.has(GANTRY_PILLAR):
				d[GANTRY_PILLAR] = int(d[GANTRY_PILLAR]) + first_gantryway
	var first_teleporter: int = 0
	for tp: Dictionary in teleporters:
		first_teleporter = maxi(first_teleporter, int(tp.get("id", -1)) + 1)
	if first_teleporter > 0:
		for tp: Dictionary in other.teleporters:
			tp["id"] = int(tp.get("id", 0)) + first_teleporter
	var lists: Dictionary = to_dict()
	var more: Dictionary = other.to_dict()
	for key: String in more:
		if more[key] is Array and lists.get(key) is Array:
			(lists[key] as Array).append_array(more[key])
	# Lists to_dict() leaves out while they're empty join here.
	if not lists.has("doodads"):
		doodads.append_array(other.doodads)
	if not lists.has("cuts"):
		cuts.append_array(other.cuts)
	if not lists.has("wall_fences"):
		wall_fences.append_array(other.wall_fences)
	if not lists.has("wall_gaps"):
		wall_gaps.append_array(other.wall_gaps)
	if not lists.has("dash_walls"):
		dash_walls.append_array(other.dash_walls)
	if not lists.has("ceiling_fences"):
		ceiling_fences.append_array(other.ceiling_fences)
	if not lists.has("return_pads"):
		return_pads.append_array(other.return_pads)
	if not lists.has("stashes"):
		stashes.append_array(other.stashes)
	if not lists.has("wall_run_gaps"):
		wall_run_gaps.append_array(other.wall_run_gaps)
	if not lists.has("wall_hops"):
		wall_hops.append_array(other.wall_hops)
	if not lists.has("wall_stumps"):
		wall_stumps.append_array(other.wall_stumps)
	if not lists.has("maze"):
		maze.append_array(other.maze)
	if not lists.has("gantryways"):
		gantryways.append_array(other.gantryways)
	if not lists.has("teleporters"):
		teleporters.append_array(other.teleporters)
	length = maxf(length, other.length)


func copy() -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = lane_count
	out.length = length
	out.gaps = gaps.duplicate(true)
	out.fences = fences.duplicate(true)
	out.signs = signs.duplicate(true)
	out.hulls = hulls.duplicate(true)
	out.pads = pads.duplicate(true)
	out.ramps = ramps.duplicate(true)
	out.speed_pads = speed_pads.duplicate(true)
	out.credits = credits.duplicate(true)
	out.enemies = enemies.duplicate(true)
	out.doodads = doodads.duplicate(true)
	out.cuts = cuts.duplicate(true)
	out.wall_fences = wall_fences.duplicate(true)
	out.wall_gaps = wall_gaps.duplicate(true)
	out.dash_walls = dash_walls.duplicate(true)
	out.ceiling_fences = ceiling_fences.duplicate(true)
	out.return_pads = return_pads.duplicate(true)
	out.stashes = stashes.duplicate(true)
	out.wall_run_gaps = wall_run_gaps.duplicate(true)
	out.wall_hops = wall_hops.duplicate(true)
	out.wall_running = wall_running
	out.wall_stumps = wall_stumps.duplicate(true)
	out.doodads_stop = doodads_stop
	out.maze = maze.duplicate(true)
	out.gantryways = gantryways.duplicate(true)
	out.teleporters = teleporters.duplicate(true)
	return out


func outer_lane(side: int) -> int:
	return 0 if side < 0 else lane_count - 1


## True if hole `g` (an entry of `gaps`) is a wall-run gap's (WALL_RUN_HOLE; wall_run_gaps): a stretch the runner
## crosses on a wall, never a jump.
static func is_wall_run_hole(g: Dictionary) -> bool:
	return bool(g.get(WALL_RUN_HOLE, false))


## The wall-run gap (wall_run_gaps) whose holes reach track distance `d` within `margin` metres either side of its
## [start, end], or {} if none does.
func wall_run_gap_at(d: float, margin: float = 0.0) -> Dictionary:
	for w: Dictionary in wall_run_gaps:
		if d >= float(w["start"]) - margin and d <= float(w["end"]) + margin:
			return w
	return {}


## True if a wall-run gap's clear stretch (wall_run_gaps: from its `approach` to its `landing`, in every lane)
## reaches anywhere into [from, to].
func wall_run_zone_between(from: float, to: float) -> bool:
	for w: Dictionary in wall_run_gaps:
		if float(w["approach"]) <= to and float(w["landing"]) >= from:
			return true
	return false


## True if a wall-run gap's crossing (wall_run_gaps: from its clear run-in's start, where the runner heads for its lit
## wall, to its gap's far end, `approach` to `end`) reaches anywhere into [from, to]: no move but the wall run there.
## An attack that could only be dodged another way holds off while one lies in its reach (a heli drone's barrage, a Bad
## Dream's slash).
func wall_run_between(from: float, to: float) -> bool:
	for w: Dictionary in wall_run_gaps:
		if float(w["approach"]) <= to and float(w["end"]) >= from:
			return true
	return false


## The lit walls (ZoneSkin.wall_run_guide) on wall `side` of the wall-run gaps whose lit wall reaches into [from, to):
## each Vector3(entry, start, end), the stretch to step on and the gap (wall_run_gaps); one for each wall run of an
## extended wall run, on each of its lit walls (WallRunGapPlacement.crossings_of: from its lit stretch, then from each
## platform's last stretch, over the hole after it).
func wall_run_guides(side: int, from: float, to: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for w: Dictionary in wall_run_gaps:
		if float(w["entry"]) >= to or float(w["end"]) <= from:
			continue
		if not w.has("runs"):
			if int(w["side"]) == side:
				out.append(Vector3(float(w["entry"]), float(w["start"]), float(w["end"])))
			continue
		if not WallRunGapPlacement.sides_of(w).has(side):
			continue
		for c: Vector3 in WallRunGapPlacement.crossings_of(w):
			if c.x < to and c.z > from:
				out.append(c)
	return out


## Total value of every credit, a treasure stash's and the wall-hop credits' too: what a run can collect (the
## economy's tools and tests). The stars count star_credit_value().
func total_credit_value() -> int:
	var total: int = 0
	for c: Dictionary in credits:
		total += int(c["value"])
	return total


## The best credit score the stars count (ScoreKeeper.max_credit_score, GameRules.stars_for): every credit but a
## treasure stash's (task I4) and the high-value ones of a line of wall-hop credits (task N1, WallHopPlacement.GEM).
## A stash is an optional reward a floor runner can't reach (and there's none on 3 or 4 lanes), and the wall-hop
## credits are for a move the game never asks for (GDD §3, the wall hop), so the three-star line never asks for
## either; collected, their credits still count in the run's credits (the wallet) and its level score. DESIGN-TBD
## (item 844; items 1017-1024).
func star_credit_value() -> int:
	var total: int = 0
	for c: Dictionary in credits:
		if not c.has("stash") and not c.has(WallHopPlacement.GEM):
			total += int(c["value"])
	return total


## True if `lane` has a hole anywhere in [from, to].
func gapped_between(lane: int, from: float, to: float) -> bool:
	for g: Dictionary in gaps:
		if g["lane"] == lane and g["start"] <= to and g["end"] >= from:
			return true
	return false


## True if a doodad stands anywhere in [from, to]: in `lane`, or in any lane with -1. A dash wall (task
## H7a) counts in every lane, since it stands across all of them (dash_wall_between). The enemies'
## fairness checks ask it (an attack is never timed onto a doodad or a dash wall, which narrow the
## player's moves: CyborgGun.path_clear, Octodog.window_clear, Resonator.pulse_clear, the drone's barrage,
## the hover truck's cannon and the Enforcer Truck's escape), and so do the generator's (a floor cut's
## lane, a floor credit, a Gilded Sentinel's stretch, a cyborg planted in a charge's path). A smashed one
## still counts, so an attack waits by it the same on every attempt. A row of doodads (task L3) counts
## from its first one's front to its last one's end, the space between them too (doodad_extent): no
## runner goes into its lane there, between a side that blocks the switch and a front that pushes.
## A falling gantryway (task Q3) counts its pillar (a doodad) and, in its lane, its whole calm stretch
## (gantryway_between): a runner who dashed its pillar must leave the lane before the walkway lands, so no attack
## is timed onto that either, fallen or not. A teleporter (task Q4) counts its calm stretches (teleporter_between): its
## approach in its lane and each output pad's landing in that pad's lane, so no attack is timed onto a runner lining up
## its pad or just arrived, and no credit lies on its pad or right where a runner lands.
func doodad_between(from: float, to: float, lane: int = -1) -> bool:
	for d: Dictionary in doodads:
		var span: Vector2 = doodad_extent(d)
		if span.x <= to and span.y >= from and (lane < 0 or int(d["lane"]) == lane):
			return true
	if not gantryways.is_empty() and gantryway_between(from, to, lane):
		return true
	if not teleporters.is_empty() and teleporter_between(from, to, lane):
		return true
	return dash_wall_between(from, to)


## True if a teleporter's calm stretch (teleporters `calm`: [lane, from, to] each, its approach in its lane and each
## output pad's landing in that pad's lane; task Q4) reaches anywhere into [from, to]: in `lane`, or in any lane with -1.
## A calm stretch of lane -1 (an introduction's landing) counts in every lane.
func teleporter_between(from: float, to: float, lane: int = -1) -> bool:
	for tp: Dictionary in teleporters:
		var span: Array = tp.get("span", [])
		if span.size() == 2 and (float(span[0]) > to or float(span[1]) < from):
			continue
		for c: Variant in tp.get("calm", []):
			var calm: Array = c
			var l: int = int(calm[0])
			if float(calm[1]) <= to and float(calm[2]) >= from and (lane < 0 or l < 0 or l == lane):
				return true
	return false


## The teleporter (teleporters) whose `id` is `id`, or {} if there's none.
func teleporter_by_id(id: int) -> Dictionary:
	for tp: Dictionary in teleporters:
		if int(tp.get("id", -1)) == id:
			return tp
	return {}


## True if a falling gantryway's calm stretch (gantryways `calm`: from its pillar's front to where a runner who dashed
## the pillar has stepped out of its lane and seen what comes next; task Q3) reaches anywhere into [from, to]: in
## `lane`, the gantryway's own, or in any lane with -1.
func gantryway_between(from: float, to: float, lane: int = -1) -> bool:
	for g: Dictionary in gantryways:
		var calm: Array = g["calm"]
		if float(calm[0]) <= to and float(calm[1]) >= from and (lane < 0 or int(g["lane"]) == lane):
			return true
	return false


## True if doodad entry `d` (one of `doodads`) is a falling gantryway's pillar (task Q3: marked GANTRY_PILLAR): placed
## by its rules with the gantryway (gantryway_rules.gd), not the zone doodads' pass, and built with it.
static func is_gantry_pillar(d: Dictionary) -> bool:
	return d.has(GANTRY_PILLAR)


## True if doodad entry `d` (one of `doodads`) holds an enemy until it's smashed (task Q5: marked HOLDS, an Octodog's
## jar): placed by its feature's rules (octodog_jar_rules.gd), not the zone doodads' pass.
static func holds_enemy(d: Dictionary) -> bool:
	return String(d.get(HOLDS, "")) != ""


## The type of the enemy doodad entry `d` holds (HOLDS), or "" if it holds none.
static func held_type(d: Dictionary) -> String:
	return String(d.get(HOLDS, ""))


## True if doodad entry `d` holds an enemy that never comes out (HOLDS and DECOY: a decoy, task Q5).
static func is_decoy(d: Dictionary) -> bool:
	return holds_enemy(d) and bool(d.get(DECOY, false))


## True if enemy entry `e` (one of `enemies`) is held in a doodad until that doodad is smashed (task Q5: its params
## marked HELD).
static func is_held(e: Dictionary) -> bool:
	return bool((e.get("params", {}) as Dictionary).get(HELD, false))


## The doodad (its entry of `doodads`) that holds enemy entry `e` (is_held): in its lane, holding its type, its front at
## the enemy's `at`; {} if there's none.
func holder_of(e: Dictionary) -> Dictionary:
	if not is_held(e):
		return {}
	var lane: int = int(e.get("lane", -1))
	var at: float = float(e.get("at", 0.0))
	var type: String = String(e.get("type", ""))
	for d: Dictionary in doodads:
		if int(d["lane"]) == lane and held_type(d) == type and absf(float(d["start"]) - at) < 0.01:
			return d
	return {}


## The enemy entry (one of `enemies`) doodad entry `d` holds (holds_enemy): of its type, held, in its lane, standing at
## its front; {} if there's none.
func held_by(d: Dictionary) -> Dictionary:
	if not holds_enemy(d):
		return {}
	var lane: int = int(d["lane"])
	var start: float = float(d["start"])
	var type: String = held_type(d)
	for e: Dictionary in enemies:
		if is_held(e) and String(e.get("type", "")) == type and int(e.get("lane", -1)) == lane \
				and absf(float(e.get("at", 0.0)) - start) < 0.01:
			return e
	return {}


## The falling gantryway (gantryways) whose `id` is `id`, or {} if there's none.
func gantryway_by_id(id: int) -> Dictionary:
	for g: Dictionary in gantryways:
		if int(g.get("id", -1)) == id:
			return g
	return {}


## The pillar (its entry of `doodads`) of falling gantryway `g` (gantryways), or {} if it has none.
func pillar_of(g: Dictionary) -> Dictionary:
	var id: int = int(g.get("id", -1))
	for d: Dictionary in doodads:
		if d.has(GANTRY_PILLAR) and int(d[GANTRY_PILLAR]) == id:
			return d
	return {}


## The stretch doodad entry `d` (one of `doodads`) keeps its lane for: its row's (`row`: from the row's first
## front to its last end, task L3), or its own from start to end.
static func doodad_extent(d: Dictionary) -> Vector2:
	if d.has("row"):
		var row: Array = d["row"]
		return Vector2(float(row[0]), float(row[1]))
	return Vector2(float(d["start"]), float(d["end"]))


## True if doodad entry `d` (one of `doodads`) is a piece of the debris maze (task O2: marked "maze", its block's
## index): placed by DebrisMaze to its own rules, not the zone doodads' (LevelGenerator._place_doodads).
static func is_maze_debris(d: Dictionary) -> bool:
	return d.has("maze")


## The debris maze's block (maze) whose stretch, from its run-in's start to its breather's end ([entry, exit]), reaches
## [from, to]; {} if none does.
func maze_block_between(from: float, to: float) -> Dictionary:
	for b: Dictionary in maze:
		if float(b["entry"]) <= to and float(b["exit"]) >= from:
			return b
	return {}


## True if a fenced ceiling's pick (task I4: its hull's "pick", from its first pad's run-up to its last safe pad,
## where the player reads which pad is the trap) overlaps [from, to]. A heli drone never starts a barrage that would
## play out there (Drone._pick_in_reach).
func fenced_pick_between(from: float, to: float) -> bool:
	for h: Dictionary in hulls:
		var pick: Variant = h.get("pick")
		if pick is Array and (pick as Array).size() == 2 and float(pick[0]) <= to and float(pick[1]) >= from:
			return true
	return false


## True if a dash wall (dash_walls, from its face to its back) stands anywhere in [from, to], broken or not.
func dash_wall_between(from: float, to: float) -> bool:
	for w: Dictionary in dash_walls:
		if float(w["start"]) <= to and float(w["end"]) >= from:
			return true
	return false


## True if a floor cut keeps its lane clear anywhere in [from, to] (FloorCutPlan.lane_window: from
## where its warning starts to past its cause's spot): in `lane`, or in any lane with -1.
func cut_between(from: float, to: float, lane: int = -1) -> bool:
	for c: Dictionary in cuts:
		if FloorCutPlan.lane_window_in(c, from, to, lane):
			return true
	return false


## True if a wall fence stands within [from, to] (its `at`): on wall `side` (-1 left, 1 right), or on
## either wall with 0. A wall enemy's rules (task C4's Gilded Sentinels) and a boss's wall pieces ask it.
func wall_fence_between(from: float, to: float, side: int = 0) -> bool:
	for w: Dictionary in wall_fences:
		if float(w["at"]) >= from and float(w["at"]) <= to and (side == 0 or int(w["side"]) == side):
			return true
	return false


## True if wall `side` (-1 left, 1 right; 0 either) has a gap anywhere in [from, to] (wall_gaps).
func wall_gap_between(from: float, to: float, side: int = 0) -> bool:
	for g: Dictionary in wall_gaps:
		if float(g["start"]) <= to and float(g["end"]) >= from and (side == 0 or int(g["side"]) == side):
			return true
	return false


## True if wall `side` has its wall-running surface at track distance `d`: no wall gap holds it
## (a gap's [start, end)).
func wall_supported(side: int, d: float) -> bool:
	return wall_supported_in(wall_gaps, side, d)


## wall_supported() over a list of wall gap entries (the player keeps the layout's list).
static func wall_supported_in(gaps: Array[Dictionary], side: int, d: float) -> bool:
	for g: Dictionary in gaps:
		if int(g["side"]) == side and d >= float(g["start"]) and d < float(g["end"]):
			return false
	return true


## The entry of `gaps` (wall gap entries) that holds wall `side` at track distance `d`, or {} where the wall stands.
static func wall_gap_at(gaps: Array[Dictionary], side: int, d: float) -> Dictionary:
	for g: Dictionary in gaps:
		if int(g["side"]) == side and d >= float(g["start"]) and d < float(g["end"]):
			return g
	return {}


## The solid stretches of wall `side` within [from, to): that range with its wall gaps taken out, in
## order (Vector2(start, end)). The track builder draws the wall over exactly these.
func wall_solid_pieces(side: int, from: float, to: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cursor: float = from
	for g: Vector2 in wall_gap_pieces(side, from, to):
		if g.x > cursor:
			out.append(Vector2(cursor, g.x))
		cursor = maxf(cursor, g.y)
	if cursor < to:
		out.append(Vector2(cursor, to))
	return out


## The parts of wall `side`'s gaps within [from, to), in order: Vector2(start, end) clipped to the
## range (the full gap's ends in wall_gap_spans).
func wall_gap_pieces(side: int, from: float, to: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g: Vector2 in wall_gap_spans(side, from, to):
		out.append(Vector2(maxf(g.x, from), minf(g.y, to)))
	return out


## The whole wall gaps on wall `side` that overlap [from, to), in order, as Vector2(start, end).
func wall_gap_spans(side: int, from: float, to: float) -> Array[Vector2]:
	return _spans_of(wall_gaps, side, from, to)


## The whole wall stumps (wall_stumps; task O1) on wall `side` that overlap [from, to), in order, as Vector2(start, end).
func wall_stump_spans(side: int, from: float, to: float) -> Array[Vector2]:
	return _spans_of(wall_stumps, side, from, to)


## The entries of `entries` ({side, start, end}) on wall `side` that overlap [from, to), in order, as
## Vector2(start, end).
static func _spans_of(entries: Array[Dictionary], side: int, from: float, to: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g: Dictionary in entries:
		var s: float = float(g["start"])
		var e: float = float(g["end"])
		if int(g["side"]) == side and s < to and e > from:
			out.append(Vector2(s, e))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


## True if a ceiling section covers the track distance `d`: in `lane`, or in any lane with -1.
func under_hull(d: float, lane: int = -1) -> bool:
	for h: Dictionary in hulls:
		if d >= h["start"] and d <= h["end"] and (lane < 0 or hull_covers(h, lane)):
			return true
	return false


## The lanes ceiling section `h` covers: Vector2i(first, last), a contiguous range (every lane for a
## full-width ceiling).
func hull_lanes(h: Dictionary) -> Vector2i:
	return hull_lanes_of(h, lane_count)


## hull_lanes() for a layout of `lanes` lanes.
static func hull_lanes_of(h: Dictionary, lanes: int) -> Vector2i:
	if not h.has("first_lane"):
		return Vector2i(0, lanes - 1)
	return Vector2i(clampi(int(h["first_lane"]), 0, lanes - 1), clampi(int(h["last_lane"]), 0, lanes - 1))


## How many lanes ceiling section `h` covers.
func hull_width(h: Dictionary) -> int:
	var lanes: Vector2i = hull_lanes(h)
	return lanes.y - lanes.x + 1


## True if ceiling section `h` covers `lane`.
func hull_covers(h: Dictionary, lane: int) -> bool:
	var lanes: Vector2i = hull_lanes(h)
	return lane >= lanes.x and lane <= lanes.y


## A ceiling section from `start` to `end` over lanes `lanes` (Vector2i(first, last)) of a layout of
## `lane_count` lanes: without a range when it covers every lane (see hulls).
static func make_hull(start: float, end: float, lanes: Vector2i, lane_count: int) -> Dictionary:
	if lanes.x <= 0 and lanes.y >= lane_count - 1:
		return {"start": start, "end": end}
	return {"start": start, "end": end, "first_lane": lanes.x, "last_lane": lanes.y}


## The ceiling section over track distance `d` (in `lane`, or any lane with -1); {} if there's none.
func hull_at(d: float, lane: int = -1) -> Dictionary:
	for h: Dictionary in hulls:
		if d >= h["start"] and d <= h["end"] and (lane < 0 or hull_covers(h, lane)):
			return h
	return {}
