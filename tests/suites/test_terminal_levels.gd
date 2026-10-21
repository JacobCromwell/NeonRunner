extends TestSuite
## The Terminal's levels (task O1; the owner, October 20, 2026, GDD §5 Zone 8: an abandoned subway under the city, the
## campaign's zone 8 between the Dead Zone and the Golden Zone, two levels and no boss; the Ice Lab came in after it,
## task Q1). How the campaign configures them off its difficulty curve and leaves every other level as it was, and saves
## from before it, are test_campaign's. Checked here:
## - the data: data/zones/terminal.tres between the Dead Zone and the Ice Lab (id terminal, "The Terminal", Rubble
##   Line and Last Stop, its music track `terminal` still to come, an intro and an outro slot, no boss slot, outside the
##   web demo); its levels: off the curve, their own seeds and patterns (data/patterns/terminal/), the arches' numbers
##   (data/tuning/terminal_wall_gaps.tres), no wall running, every ceiling one lane wide, two wider gaps, no dash walls,
##   none of the usual enemies' features, the debris maze (task O2) and the centipede (task O3) listed; its
##   doodads stop the runner and stand lower than other zones' and still too tall to jump (task O2), and each level has
##   its own maze numbers;
## - every build at 3, 5 and 6 lanes, on the levels' own seeds and OTHER_SEEDS, as the campaign configures it: no
##   warnings, the campaign's fairness checks (LayoutChecks.check_layout and check_rules: the debris maze's among them,
##   check_debris_maze and check_centipedes), the same level on a second build, and the Terminal's rules: no enemy but its
##   Cybernetic Centipedes (in its maze: test_centipede_maze), no dash walls, a couple of holes (its wider gaps, rows in
##   every lane but one) and nothing else in its floor, its debris maze, few ceilings and every one a single lane wide and
##   short, nothing on its walls (check_boundary_walls);
## - its walls: each a row of narrow arches over the whole stretch the track draws walls along, arch_length long and
##   arch_spacing (give or take its jitter) apart, mostly in pairs, a missing one a broken stump opposite the other
##   wall's arch, about arch_stump_share of the places;
## - the track (TrackBuilder, with a skin that records its calls): each arch drawn whole and once (ZoneSkin
##   .wall_section, even across a chunk's edge), each stump whole and once (wall_stump), the open space between them
##   with wall_opening and never wall_gap, tiling every wall with the arches; a level with wall running drawn as before
##   (wall_gap over its gaps, never wall_opening or wall_stump); the default stump and opening build without errors;
## - no wall running, on real physics (RunSim): a move past the outer lane, beside an arch or in the open space between
##   two, on the floor or from a jump, bumps the runner back with the blocked wall's clank (wall_blocked) and no damage:
##   they stay on the floor in the outer lane, alive; the same move in a level with wall running steps onto the wall;
## - the first-encounter hints: no wall gap hint in a Terminal level.

const ZONE_PATH: String = "res://data/zones/terminal.tres"
const ARCHES_PATH: String = "res://data/tuning/terminal_wall_gaps.tres"
const PATTERNS_PATH: String = "res://data/patterns/terminal/terminal_patterns.json"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
## The Terminal's steps, in order, after the Dead Zone's outro and before the Ice Lab's intro.
const STEPS: Array[String] = ["terminal/intro", "terminal/1", "terminal/2", "terminal/outro"]
const NAMES: Array[String] = ["Rubble Line", "Last Stop"]
## Seeds besides each level's own that every check also runs on.
const OTHER_SEEDS: Array[int] = [8901, 8902, 8903]
## "Very few" ceilings (GDD §5, Zone 8): at most this many in one level, in any build checked, the debris maze's own
## among them. DESIGN-TBD (docs/questions/o1.md, o2.md): the open stretch's pick weight against the ceiling's, and the
## maze's ceiling_share (DebrisMazeTuning), set how many.
const MOST_CEILINGS: int = 10
## Features the Terminal's levels list: its ceilings and its walls' open space, and its own two.
const FEATURES: PackedStringArray = ["ceilings", "wall_gaps", "debris_maze", "centipede"]


## Records the wall calls TrackBuilder makes.
class RecordingSkin extends ZoneSkin:
	var solid: Array = []  ## [side, start, end]
	var gaps: Array = []  ## [side, start, end, gap]
	var openings: Array = []  ## [side, start, end, gap]
	var stumps: Array = []  ## [side, start, end]

	func wall_section(_parent: Node3D, side: int, _face_x: float, start: float, end: float) -> void:
		solid.append([side, start, end])

	func wall_gap(_parent: Node3D, side: int, _face_x: float, start: float, end: float, gap: Vector2) -> void:
		gaps.append([side, start, end, gap])

	func wall_opening(_parent: Node3D, side: int, _face_x: float, start: float, end: float, gap: Vector2) -> void:
		openings.append([side, start, end, gap])

	func wall_stump(_parent: Node3D, side: int, _face_x: float, start: float, end: float) -> void:
		stumps.append([side, start, end])


var campaign: Campaign
var zone: ZoneDef
var arches: WallGapTuning
var sim: RunSim


func run() -> void:
	campaign = load(CAMPAIGN_PATH) as Campaign
	zone = load(ZONE_PATH) as ZoneDef
	arches = load(ARCHES_PATH) as WallGapTuning
	sim = RunSim.new(tree, tuning)
	check(zone != null and arches != null, "the Terminal's zone and its arches' numbers load")
	if zone == null or arches == null:
		return
	_test_data()
	_test_levels()
	await _test_track()
	await _test_no_wall_running()
	_test_hints()


func _test_data() -> void:
	var at: int = campaign.zones.find(zone)
	# The Golden Zone followed it until the Ice Lab came in between them (task Q1; the owner, October 21, 2026).
	check(at > 0 and at + 1 < campaign.zones.size() and campaign.zones[at - 1].id == &"dead_zone"
		and campaign.zones[at + 1].id == &"ice_lab", "the campaign's zone %d, between the Dead Zone and the Ice Lab" % (at + 1))
	check(zone.id == &"terminal" and zone.display_name == "The Terminal" and zone.tagline != "" and zone.music == &"terminal"
		and not zone.in_demo and not zone.placeholder, "the Terminal's id, name, tagline and music track, outside the web demo")
	check(zone.boss == null and zone.boss_intro == null, "no boss (owner, October 20, 2026): it leads straight into the next zone (the Ice Lab)")
	check(zone.intro != null and zone.outro != null and String(zone.intro.id) == "terminal_intro"
		and String(zone.outro.id) == "terminal_outro" and not zone.outro.is_built() and not zone.intro.is_skipped()
		and not zone.outro.is_skipped(), "an intro slot (the placeholder flyover) and an outro slot (a placeholder card)")
	check(zone.skin != null, "a skin (the Dead Zone's stands in until task O4's)")
	var ids: PackedStringArray = []
	for s: CampaignStep in campaign.steps():
		if s.zone == zone:
			ids.append(s.id)
	var first: CampaignStep = campaign.step(STEPS[0])
	check(ids == PackedStringArray(STEPS) and first != null and campaign.steps()[first.index - 1].id == "dead_zone/outro"
		and campaign.next_step(campaign.step(STEPS[-1])) == campaign.step("ice_lab/intro"),
		"its steps: intro, Rubble Line, Last Stop, outro, from the Dead Zone's outro to the Ice Lab's intro (%s)" % [ids])
	check(arches.arches() and is_equal_approx(arches.arch_length, 3.6) and arches.arch_spacing > arches.arch_length * 5.0
		and arches.arch_spacing < arches.arch_length * 7.0 and arches.arch_stump_share > 0.0 and arches.arch_stump_share < 0.5
		and not arches.opens_walls(), "the arches: one space long, about six lengths apart, mostly in pairs (DESIGN-TBD)")
	var seeds: Dictionary = {}
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s.zone != zone:
			seeds[s.level.level_seed] = true
	for n: int in 2:
		var level: LevelConfig = zone.levels[n]
		var tag: String = "terminal/%d" % (n + 1)
		check(String(level.id) == "terminal_%d" % (n + 1) and level.display_name == NAMES[n], "%s is %s" % [tag, NAMES[n]])
		check(level.off_curve and level.guarantee_features and not seeds.has(level.level_seed),
			"%s is off the difficulty curve, guarantees its features and has a seed of its own" % tag)
		check(level.patterns_path == PATTERNS_PATH, "%s picks from the Terminal's own patterns" % tag)
		check(level.wall_gap_tuning == arches and not level.wall_running, "%s: its walls are arches, and no wall running" % tag)
		check(is_equal_approx(level.narrow_ceiling_share, 1.0) and is_equal_approx(level.one_lane_ceiling_share, 1.0),
			"%s: every ceiling one lane wide" % tag)
		check(level.wide_gaps == 2 and level.dash_walls == 0 and level.wall_hop_lines == 0 and level.fill_empty_seconds == 0.0
			and level.charge_path_cyborgs == 0 and not level.buzz_company,
			"%s: a couple of holes (its two wider gaps), no dash walls, no wall-hop credits, nothing filled in" % tag)
		# The danger density dial follows the campaign's (test_danger_density): Dead Zone 2's to Golden 1's. The pass has
		# none of the level's own enemies or fillers to add (its centipedes keep to the maze, which it keeps off).
		var dz2: float = campaign.step("dead_zone/2").level.danger_density_increase
		var g1: float = campaign.step("golden/1").level.danger_density_increase
		check(level.danger_density_increase >= dz2 - 0.001 and level.danger_density_increase <= g1 + 0.001,
			"%s: its danger density dial (%.2f) between Dead Zone 2's and Golden 1's" % [tag, level.danger_density_increase])
		check(level.features == FEATURES, "%s lists only its ceilings, its walls' open space, the debris maze and the centipede (%s)"
			% [tag, level.features])
		check(not LevelConfig.PLANNED_FEATURES.has("debris_maze") and LayoutChecks.can_locate("debris_maze"),
			"`debris_maze` is built (task O2)")
		check(not LevelConfig.PLANNED_FEATURES.has("centipede") and LayoutChecks.can_locate("centipede"),
			"`centipede` is built (task O3)")
		# Its debris (task O2; GDD §5, Zone 8): doodads stop the runner rather than push them, and stand lower than other
		# zones' but still too tall to jump: over a jump's theoretical peak (jump_height) and the feet's clearance by a margin
		# (test_debris_maze runs the jumps on physics).
		var own: MovementTuning = level.movement_for(tuning)
		check(level.doodads_stop and level.doodad_height > 0.0 and own.doodad_height < tuning.doodad_height
			and own.doodad_height >= tuning.jump_height + Player.DOODAD_FEET_CLEARANCE + 0.04,
			"%s: its doodads stop the runner, lower than other zones' (%.2f m against %.2f m) and too tall to jump (%.2f m)"
				% [tag, own.doodad_height, tuning.doodad_height, tuning.jump_height])
		check(level.debris_maze_tuning != null and level.debris_maze_tuning.resource_path != DebrisMaze.TUNING_PATH,
			"%s has its own debris maze numbers" % tag)
	check(zone.levels[0].feature_starts.has("debris_maze") and zone.levels[0].feature_starts.has("centipede")
		and zone.levels[1].feature_starts.is_empty(), "Rubble Line introduces the debris maze and the centipede, each at a start of its own")
	# The Terminal's own patterns: nothing but its open stretches and its plain one-lane ceilings.
	for p: Dictionary in LevelGenerator.load_patterns(PATTERNS_PATH):
		for element: Dictionary in p.get("elements", []):
			check(String(element.get("kind", "")) in ["credits", "hull"], "the Terminal's pattern %s puts no %s on the track"
				% [p.get("id", "?"), element.get("kind", "?")])


## Every build at 3, 5 and 6 lanes on the levels' own seeds and others, as the campaign configures it.
func _test_levels() -> void:
	var ceilings: Array[int] = []
	var places: int = 0
	var stumps: int = 0
	for n: int in [1, 2]:
		var step: CampaignStep = campaign.step("terminal/%d" % n)
		for lanes: int in [3, 5, 6]:
			for k: int in OTHER_SEEDS.size() + 1:
				var config: LevelConfig = campaign.configure(step, lanes)
				if k > 0:
					config.level_seed = OTHER_SEEDS[k - 1]
				var tag: String = "%s lanes=%d seed=%d" % [step.id, lanes, config.level_seed]
				var patterns: Array = LevelGenerator.load_for(config)
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
				var layout: LevelLayout = gen.layout
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				LayoutChecks.check_layout(self, layout, config, tag)
				LayoutChecks.check_rules(self, layout, config, tag)
				if k == 0:
					var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(again.to_dict()) == JSON.stringify(layout.to_dict()), "the same level every attempt " + tag)
				check(not layout.wall_running, "its layout says its walls can't be run on " + tag)
				var others: Array = layout.enemies.filter(func(e: Dictionary) -> bool: return String(e["type"]) != "centipede")
				check(others.is_empty() and not layout.enemies.is_empty(),
					"no enemy but its centipedes, and some of those (%d; others %s) %s" % [layout.enemies.size(), others, tag])
				check(layout.dash_walls.is_empty() and layout.fences.is_empty() and layout.cuts.is_empty()
					and layout.speed_pads.is_empty() and layout.ceiling_fences.is_empty() and layout.stashes.is_empty(),
					"no dash walls, fences, floor cuts, speed pads or ceiling scenarios " + tag)
				# A couple of holes, not many (GDD §5): its wider gaps' rows, each across every lane but one.
				var rows: Array[Dictionary] = GapDensity.rows(layout)
				var across: bool = true
				for row: Dictionary in rows:
					across = across and (row["lanes"] as Array).size() == lanes - 1
				check(rows.size() >= 1 and rows.size() <= config.wide_gaps and across,
					"a couple of holes: %d rows, each in every lane but one %s" % [rows.size(), tag])
				# Few ceilings, every one a single lane wide and short (GDD §3, §5): little shortcuts.
				var one_lane: bool = true
				for h: Dictionary in layout.hulls:
					one_lane = one_lane and layout.hull_width(h) == 1
				check(not layout.hulls.is_empty() and layout.hulls.size() <= MOST_CEILINGS and one_lane,
					"few ceilings (%d), every one a single lane wide %s" % [layout.hulls.size(), tag])
				ceilings.append(layout.hulls.size())
				var counted: Vector2i = _check_arches(layout, tag)
				places += counted.x
				stumps += counted.y
	ceilings.sort()
	var share: float = float(stumps) / maxf(places, 1)
	check(share > arches.arch_stump_share * 0.6 and share < arches.arch_stump_share * 1.4,
		"about arch_stump_share of the arches' places have a broken stump (%d of %d, %.2f)" % [stumps, places, share])
	print("  the Terminal's ceilings per level: %s; broken stumps at %d of %d arch places (%.2f)" % [ceilings, stumps,
		places, share])


## The walls of one build: each a row of narrow arches (its solid pieces) over the whole stretch the track draws walls
## along, arch_length long, arch_spacing apart give or take its jitter; at each place both walls have their arch, or
## one has a broken stump opposite the other's. Returns Vector2i(the arch places, the stumps).
func _check_arches(layout: LevelLayout, tag: String) -> Vector2i:
	var span: Vector2 = TrackBuilder.wall_span(layout.length)
	var pieces: Array = [layout.wall_solid_pieces(-1, span.x, span.y), layout.wall_solid_pieces(1, span.x, span.y)]
	var lengths_ok: bool = true
	var spacing_ok: bool = true
	var lo: float = arches.arch_spacing * (1.0 - arches.arch_spacing_jitter) - 0.01
	var hi: float = arches.arch_spacing * (1.0 + arches.arch_spacing_jitter) + 0.01
	# Every arch place, both walls': the arches' and the stumps' starts (merged below: a solid piece's ends are float32).
	var starts: Array[float] = []
	for i: int in 2:
		var side: int = -1 if i == 0 else 1
		var mine: Array[Vector2] = []
		mine.assign(pieces[i])
		for p: Vector2 in mine:
			lengths_ok = lengths_ok and absf(p.y - p.x - arches.arch_length) < 0.01
			starts.append(p.x)
		# Every place on this wall, an arch or a broken stump.
		var all: Array[Vector2] = mine.duplicate()
		all.append_array(layout.wall_stump_spans(side, span.x, span.y))
		all.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for j: int in range(1, all.size()):
			var open: float = all[j].x - all[j - 1].y
			spacing_ok = spacing_ok and open >= lo and open <= hi
		check(not mine.is_empty() and all[0].x >= span.x and all[0].x <= span.x + arches.arch_spacing + 0.01
			and all[-1].y <= span.y and all[-1].y >= span.y - hi - arches.arch_length - 0.01,
			"wall %+d stands in arches from the track's first chunk to past its run-out %s" % [side, tag])
	check(lengths_ok, "every arch is one space long (%.1f m) %s" % [arches.arch_length, tag])
	check(spacing_ok, "about six lengths of open space from one arch place to the next (%.1f-%.1f m) %s" % [lo, hi, tag])
	var paired: bool = true
	for s: Dictionary in layout.wall_stumps:
		starts.append(float(s["start"]))
		paired = paired and absf(float(s["end"]) - float(s["start"]) - arches.arch_length) < 0.01
	starts.sort()
	var places: Array[float] = []
	for at: float in starts:
		if places.is_empty() or at > places[-1] + 0.01:
			places.append(at)
	for at: float in places:
		# Halfway along the place: a wall stands there unless one of its gaps holds it (wall_supported, the layout's own
		# numbers), and a stump stands there if one of the wall's stumps spans it.
		var mid: float = at + arches.arch_length * 0.5
		var left: bool = layout.wall_supported(-1, mid)
		var right: bool = layout.wall_supported(1, mid)
		var stump_left: bool = not layout.wall_stump_spans(-1, mid, mid + 0.01).is_empty()
		var stump_right: bool = not layout.wall_stump_spans(1, mid, mid + 0.01).is_empty()
		paired = paired and ((left and right and not stump_left and not stump_right)
			or (left and stump_right and not right and not stump_left) or (right and stump_left and not left and not stump_right))
	check(paired, "at each place both walls have their arch, or one a broken stump opposite the other's %s" % tag)
	return Vector2i(places.size(), layout.wall_stumps.size())


## TrackBuilder draws a Terminal level's walls (TrackBuilder._build_boundary_wall) through the skin: each arch whole and
## once, each stump whole and once, the open space with wall_opening and never wall_gap; together the arches and the
## openings tile every wall. A level with wall running is drawn as before.
func _test_track() -> void:
	for lanes: int in [3, 5, 6]:
		var config: LevelConfig = campaign.configure(campaign.step("terminal/1"), lanes)
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		var tag: String = "(terminal/1, %d lanes)" % lanes
		var skin := RecordingSkin.new()
		var track := TrackBuilder.new()
		tree.root.add_child(track)
		var fast: MovementTuning = config.movement_for(tuning)
		track.set_layout(layout, fast, skin)
		var to: float = 700.0
		for d: float in range(0, int(to), 20):
			track.update(float(d), float(d) / fast.run_speed)
		var built: float = track.built_until()
		track.queue_free()
		await tree.process_frame
		check(skin.gaps.is_empty(), "no wall gap's marks anywhere: the open space is wall_opening's %s" % tag)
		for i: int in 2:
			var side: int = -1 if i == 0 else 1
			# The arches the built chunks start, each whole.
			var want: Array[Vector2] = []
			for p: Vector2 in layout.wall_solid_pieces(side, TrackBuilder.TRACK_START - 1.0, built + TrackBuilder.CHUNK_LENGTH):
				if p.x >= TrackBuilder.TRACK_START and p.x < built:
					want.append(p)
			var drawn: Array[Vector2] = []
			for c: Array in skin.solid:
				if int(c[0]) == side:
					drawn.append(Vector2(float(c[1]), float(c[2])))
			var whole: bool = true
			for p: Vector2 in want:
				var times: int = 0
				for q: Vector2 in drawn:
					times += 1 if q.is_equal_approx(p) else 0
				whole = whole and times == 1
			var crossing: int = 0
			for p: Vector2 in want:
				crossing += 1 if floori(p.x / TrackBuilder.CHUNK_LENGTH) != floori(p.y / TrackBuilder.CHUNK_LENGTH) else 0
			check(whole, "wall %+d: every arch drawn whole and once, %d of them across a chunk's edge %s" % [side, crossing, tag])
			var stumps: Array[Vector2] = []
			for s: Vector2 in layout.wall_stump_spans(side, TrackBuilder.TRACK_START, built):
				if s.x < built:
					stumps.append(s)
			var stumps_drawn: int = 0
			for c: Array in skin.stumps:
				if int(c[0]) != side:
					continue
				var hit: bool = false
				for s: Vector2 in stumps:
					hit = hit or s.is_equal_approx(Vector2(float(c[1]), float(c[2])))
				stumps_drawn += 1 if hit else 0
			check(stumps_drawn == stumps.size(), "wall %+d: every broken stump drawn whole and once (%d of %d) %s"
				% [side, stumps_drawn, stumps.size(), tag])
			# The openings and the arches tile the wall: what isn't an arch is drawn as open space, nothing twice.
			var covered: float = 0.0
			var overlap: bool = false
			var spans: Array[Vector2] = []
			for c: Array in skin.openings:
				if int(c[0]) == side:
					spans.append(Vector2(float(c[1]), float(c[2])))
			for p: Vector2 in want:
				spans.append(p)
			spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			var cursor: float = TrackBuilder.TRACK_START
			for s: Vector2 in spans:
				overlap = overlap or s.x < cursor - 0.01
				covered += maxf(minf(s.y, to) - maxf(s.x, cursor), 0.0)
				cursor = maxf(cursor, s.y)
			check(not overlap and absf(covered - (to - TrackBuilder.TRACK_START)) < 0.05,
				"wall %+d: arches and openings tile it to %.0f m, nothing drawn twice (%.2f m covered) %s"
				% [side, to, covered, tag])
	# A level with wall running (Dead Zone 1, with its side wall gaps) is drawn as before.
	var dz: LevelConfig = campaign.configure(campaign.step("dead_zone/1"), 5)
	var dz_layout: LevelLayout = LayoutCache.generate(dz, tuning, LevelGenerator.load_for(dz))
	var plain := RecordingSkin.new()
	var dz_track := TrackBuilder.new()
	tree.root.add_child(dz_track)
	dz_track.set_layout(dz_layout, dz.movement_for(tuning), plain)
	var until: float = float(dz_layout.wall_gaps[0]["end"]) + 100.0 if not dz_layout.wall_gaps.is_empty() else 400.0
	for d: float in range(0, int(until), 40):
		dz_track.update(float(d), 0.0)
	dz_track.queue_free()
	await tree.process_frame
	check(dz_layout.wall_running and not plain.gaps.is_empty() and plain.openings.is_empty() and plain.stumps.is_empty(),
		"a level with wall running draws its gaps with wall_gap, never wall_opening or wall_stump (%d gaps)" % plain.gaps.size())
	# The default stump and opening build plain meshes without errors, in every skin there is.
	var skins: Array[ZoneSkin] = [GreyboxSkin.new(), ZoneSkin.new()]
	for file: String in DirAccess.get_files_at("res://data/skins"):
		if file.ends_with(".tres"):
			skins.append(load("res://data/skins".path_join(file)) as ZoneSkin)
	for skin: ZoneSkin in skins:
		var skin_name: String = skin.resource_path.get_file() if skin.resource_path != "" else skin.get_class()
		var opening := Node3D.new()
		tree.root.add_child(opening)
		skin.wall_opening(opening, -1, -9.0, 10.0, 30.0, Vector2(10.0, 30.0))
		var stump := Node3D.new()
		tree.root.add_child(stump)
		skin.wall_stump(stump, 1, 9.0, 30.0, 33.6)
		var box: AABB = _mesh_bounds(stump)
		check(box.size != Vector3.ZERO and box.position.x >= 9.0 - 0.01 and box.position.z < -30.0 and box.end.z > -33.6
			and box.end.y > 1.0, "%s: a broken stump stands at the wall line and back from it, over its stretch (%s)"
			% [skin_name, box])
		opening.queue_free()
		stump.queue_free()
	await tree.process_frame


## The world-space bounds of every mesh under `root` (an empty AABB if none).
static func _mesh_bounds(root: Node) -> AABB:
	var out := AABB()
	var first: bool = true
	var todo: Array[Node] = [root]
	while not todo.is_empty():
		var node: Node = todo.pop_back()
		todo.append_array(node.get_children())
		var m := node as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## No wall running (GDD §3 and §5, Zone 8, proposed: "moving past the outer lane bumps the runner back, like a sign's
## blocked entry, without damage"), on real physics, at 3, 5 and 6 lanes.
func _test_no_wall_running() -> void:
	for lanes: int in [3, 5, 6]:
		var tag: String = "(%d lanes)" % lanes
		var right: int = lanes - 1
		# An arch on each wall from 60 to 64 m and open space either side (as the Terminal's walls are).
		var walls := RunSim.layout(lanes)
		walls.wall_running = false
		for side: int in [-1, 1]:
			walls.wall_gaps.append({"side": side, "start": -40.0, "end": 60.0})
			walls.wall_gaps.append({"side": side, "start": 64.0, "end": 400.0})
		for case: Array in [[61.0, "beside an arch"], [80.0, "in the open space between the arches"]]:
			var at: float = float(case[0])
			var r: Dictionary = await sim.run(walls, right, 6.0, [[at, &"move_right"]], [at + 4.0, at + 12.0])
			check(r["alive"] and r["at"][at + 4.0]["surface"] == "floor" and r["at"][at + 12.0]["surface"] == "floor"
				and r["at"][at + 12.0]["lane"] == right and r["events"].has(&"wall_blocked") and not r["events"].has(&"wall_enter")
				and not r["events"].has(&"wall_missing"), "a move past the outer lane %s bumps back with the clank, no damage %s: %s"
				% [String(case[1]), tag, r["events"]])
			r = await sim.run(walls, 0, 6.0, [[at, &"move_left"]], [at + 12.0])
			check(r["alive"] and r["at"][at + 12.0]["surface"] == "floor" and r["at"][at + 12.0]["lane"] == 0
				and r["events"].has(&"wall_blocked"), "the left wall too, %s %s" % [String(case[1]), tag])
		# From a jump, and again and again: never onto the wall, never hurt.
		var r: Dictionary = await sim.run(walls, right, 6.0, [[70.0, &"jump"], [71.0, &"move_right"], [90.0, &"move_right"],
			[91.0, &"move_right"]], [100.0])
		check(r["alive"] and r["at"][100.0]["surface"] == "floor" and r["at"][100.0]["lane"] == right
			and int(r["max_wall_h"]) == 0 and not r["events"].has(&"wall_enter"), "nor from a jump, or move after move %s" % tag)
		# The same walls in a level with wall running: the move beside the arch steps onto it.
		walls.wall_running = true
		r = await sim.run(walls, right, 6.0, [[60.5, &"move_right"]], [62.0])
		check(r["at"][62.0]["surface"] == "wall" and r["events"].has(&"wall_enter"), "with wall running the arch can be run on %s" % tag)


## No wall gap hint in a level without wall running (HintDirector: its open space between arches is no wall gap to drop
## off a wall at), whatever the profile has seen.
func _test_hints() -> void:
	for id: String in ["terminal/1", "terminal/2"]:
		var step: CampaignStep = campaign.step(id)
		var config: LevelConfig = campaign.configure(step, 5)
		var world := RunWorld.new()
		world.config = config
		world.layout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		world.director = EnemyDirector.new()
		world.add_child(world.director)
		var ctx := RunContext.new()
		ctx.mode = RunContext.Mode.CAMPAIGN
		ctx.step = step
		ctx.config = config
		ctx.level_index = step.level_index
		var director := HintDirector.new()
		director.setup(world, Profile.new(), false, ctx)
		var ids: Array = director.intro_hints.map(func(entry: Dictionary) -> String: return entry["id"])
		check(not ids.has("wall_gap") and not ids.has("wall") and not world.layout.wall_gaps.is_empty(),
			"%s shows no wall gap hint, though its walls have open space all along (%s)" % [id, ids])
		director.free()
		world.free()
