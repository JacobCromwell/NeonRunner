class_name TerminalIntroTuning
extends Resource
## The Terminal intro's numbers (TerminalIntro; data/cinematics/terminal_intro_tuning.tres). The beats are the owner's
## (October 21, 2026; GDD §6 Cinematics, "Terminal intro"): it opens on the runner's face as they survey the land
## around them, and the camera pans over the scene in front of them, mostly the Dead Zone's wasteland, with the outside
## of the large Grand Terminal Station in it, abandoned and decayed: "GRAND" has fallen off its front and the letters of
## "TERMINAL" droop and are sparsely lit, a few sparking and flashing a little; light comes out of the station
## throughout. The runner walks quickly up to a sign on the station and wipes it with their hand; cut to a close-up of
## the sign, a list of stops with one in gold, the Palace; the runner makes up their mind. The runner looks at the
## station's entrance, blocked by rubble with a crack of light at the top, climbs up the rubble and squeezes in through
## the hole, then jumps down to the ground inside, where the first level's train tracks run off ahead.
## Everything else (timings, places, the station's design, the sign's other stops, the camera) is DESIGN-TBD
## (docs/questions/f2k.md). Times are seconds from the start. The station's points are in its own frame
## (TerminalIntroStation): x along its front (to the viewer's right as one looks at it from the street), y up, z out
## from its front toward the street; the street's left wall's line is `forecourt` out from the front.

@export_group("Timing")
## DESIGN-TBD (docs/questions/f2k.md, 13): the length and the shots' times; the owner asked for about 25 to 32 s.
## Longer than GDD §1's 5-15 s, as the other intros are. It ends on black: Terminal 1 opens on its own view.
@export_range(10.0, 60.0, 0.1, "suffix:s") var duration: float = 32.4
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in: float = 1.0
@export_range(0.0, 8.0, 0.1, "suffix:s") var music_fade: float = 4.0
@export_range(10.0, 60.0, 0.05, "suffix:s") var fade_at: float = 31.2
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_out: float = 1.2
## The zone's title card over the last shot (inside), and how long it shows.
@export_range(0.0, 60.0, 0.05, "suffix:s") var card_at: float = 29.6
@export_range(0.5, 6.0, 0.05, "suffix:s") var card_seconds: float = 2.8
## The shots: the face (from the start), the camera sweeping round to look over the wasteland and the station
## (`survey_at`), the station's front (`facade_at`), the runner walking across to the sign (`walk_at`), at the sign as
## they wipe it (`arrive_at`), the close-up of the sign (`sign_at`), the runner making up their mind (`mind_at`), the
## runner looking at the entrance (`door_at`), the climb and the squeeze in (`climb_at`), inside (`inside_at`).
@export_range(0.0, 60.0, 0.05, "suffix:s") var survey_at: float = 2.8
@export_range(0.0, 60.0, 0.05, "suffix:s") var facade_at: float = 6.2
@export_range(0.0, 60.0, 0.05, "suffix:s") var walk_at: float = 10.6
@export_range(0.0, 60.0, 0.05, "suffix:s") var arrive_at: float = 13.6
@export_range(0.0, 60.0, 0.05, "suffix:s") var sign_at: float = 16.2
@export_range(0.0, 60.0, 0.05, "suffix:s") var mind_at: float = 18.7
@export_range(0.0, 60.0, 0.05, "suffix:s") var door_at: float = 21.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var climb_at: float = 22.4
@export_range(0.0, 60.0, 0.05, "suffix:s") var inside_at: float = 27.4
## The stage's street (metres; the finish line the track builder draws at its end stays out of view).
@export_range(300.0, 2000.0, 10.0, "suffix:m") var stage_length: float = 400.0

@export_group("The station")
## DESIGN-TBD (docs/questions/f2k.md, 1, 2): the station's design and size, where it stands, the heap and the crack.
## Where its front's middle is along the street (z), the opening in the street's left wall (long enough that the
## wall's cut ends are never in view), and how far its front stands back from the wall's line (the forecourt).
@export_range(80.0, 300.0, 0.5, "suffix:m") var station_at: float = 120.0
@export_range(60.0, 200.0, 1.0, "suffix:m") var frontage: float = 110.0
@export_range(6.0, 30.0, 0.5, "suffix:m") var forecourt: float = 14.0
## The head house in the middle (its width and the height of its pediment, over which the sign runs) and the wings
## either side (their width and heights: the right one is broken down toward its end).
@export_range(20.0, 50.0, 0.5, "suffix:m") var hall_width: float = 34.0
@export_range(14.0, 34.0, 0.5, "suffix:m") var hall_height: float = 23.0
@export_range(15.0, 45.0, 0.5, "suffix:m") var wing_width: float = 32.0
@export_range(8.0, 24.0, 0.5, "suffix:m") var wing_height_left: float = 15.5
@export_range(8.0, 24.0, 0.5, "suffix:m") var wing_height_right: float = 14.5
## The entrance in the middle of the front: its width and height, and the rubble heap that blocks it: its height at
## the doorway (the crack of light is what is left under the lintel), how far it spills out onto the forecourt, and its
## width at its foot.
@export_range(3.0, 12.0, 0.1, "suffix:m") var door_width: float = 6.8
@export_range(3.0, 9.0, 0.1, "suffix:m") var door_height: float = 4.4
@export_range(1.5, 8.0, 0.05, "suffix:m") var heap_height: float = 3.55
@export_range(3.0, 14.0, 0.1, "suffix:m") var heap_length: float = 6.5
@export_range(4.0, 20.0, 0.1, "suffix:m") var heap_foot_width: float = 10.0
## The big arched window over the entrance (width, bottom and top) and the lower windows beside the door.
@export_range(4.0, 20.0, 0.1, "suffix:m") var window_width: float = 12.0
@export_range(5.0, 14.0, 0.1, "suffix:m") var window_from: float = 8.6
@export_range(10.0, 22.0, 0.1, "suffix:m") var window_to: float = 17.6

@export_group("Inside")
## DESIGN-TBD (docs/questions/f2k.md, 12): the way in from inside, the jump and where they land.
## The way in from inside: where it is along the street (z), how far back from the street's left wall's line its wall stands, how
## far the heap's inside slope runs into the hall, and where the runner lands from the jump (out from the wall) and when they jump.
@export_range(10.0, 300.0, 0.5, "suffix:m") var inside_at_z: float = 56.0
@export_range(0.0, 3.0, 0.05, "suffix:m") var inside_wall_back: float = 0.25
@export_range(1.0, 8.0, 0.05, "suffix:m") var inside_slope: float = 3.2
@export_range(1.0, 8.0, 0.05, "suffix:m") var landing_out: float = 4.4
@export_range(0.0, 60.0, 0.05, "suffix:s") var jump_at: float = 28.2

@export_group("The sign")
## DESIGN-TBD (docs/questions/f2k.md, 3, 4): how "GRAND" is shown fallen, TERMINAL's droop, which letters are lit and how they spark.
## "GRAND TERMINAL" across the head house: the letters' height, where its middle line is up the front, the gap
## between letters (a share of their height) and how far they stand out of the front.
@export_range(1.0, 4.0, 0.05, "suffix:m") var letter_height: float = 2.3
@export_range(14.0, 24.0, 0.1, "suffix:m") var sign_y: float = 20.4
@export_range(0.0, 1.0, 0.01) var letter_gap: float = 0.3
@export_range(0.05, 0.8, 0.01, "suffix:m") var letter_depth: float = 0.28
@export_range(0.05, 1.5, 0.01, "suffix:m") var letter_out: float = 0.55
## How each letter of TERMINAL droops on its mount: the angle it has tipped by in its plane (degrees, + clockwise as
## seen from the street) and how far it has slipped down (metres) and swung out from the wall at its foot (degrees).
@export var droop_angle: PackedFloat32Array = PackedFloat32Array([-3.0, 6.0, -9.0, 5.0, 16.0, -4.0, 11.0, -24.0])
@export var droop_slip: PackedFloat32Array = PackedFloat32Array([0.0, 0.12, 0.0, 0.2, 0.55, 0.0, 0.3, 0.85])
@export var droop_out: PackedFloat32Array = PackedFloat32Array([2.0, 5.0, 0.0, 8.0, 14.0, 0.0, 6.0, 18.0])
## Which of them still have light (indices into T E R M I N A L), their brightness, the share of them that flicker
## and how often a flickering one sparks (s between sparks).
@export var lit_letters: PackedInt32Array = PackedInt32Array([1, 3, 5, 7])
@export_range(0.0, 1.0, 0.01) var letter_glow: float = 0.3
@export_range(1.0, 10.0, 0.1, "suffix:s") var spark_every: float = 3.4

@export_group("The light")
## DESIGN-TBD (docs/questions/f2k.md, 5): the light out of the station.
## The failing orange of the Terminal's work lamps, spilling out of the entrance, the big window and the wings'
## windows: the colour, the strength of the shafts (their glow, share of full) and of the pool of light on the
## forecourt, and how strong the real lights on the runner are.
@export var light_color: Color = Color(1.0, 0.56, 0.16)
@export_range(0.0, 1.0, 0.01) var shaft_glow: float = 0.28
@export_range(0.0, 1.0, 0.01) var pool_glow: float = 0.3
@export_range(0.0, 8.0, 0.05) var light_energy: float = 2.2
@export_range(2.0, 30.0, 0.5, "suffix:m") var light_range: float = 16.0

@export_group("The wasteland")
## DESIGN-TBD (docs/questions/f2k.md, 6): which of the Dead Zone's props stand where.
## The Dead Zone's props on the plaza and the street: where each stands (x along the front, z out from it),
## turned this much (degrees): [kind, x, z, turn] with kind 0 a broken column, 1 a rubble heap, 2 the burned-out bus.
@export var props: PackedVector4Array = PackedVector4Array([
	Vector4(2, -27.0, 9.0, 160.0), Vector4(1, -15.0, 8.0, 20.0), Vector4(0, -9.0, 11.5, 0.0),
	Vector4(1, 17.0, 10.5, -30.0), Vector4(0, 26.0, 7.0, 40.0), Vector4(1, 33.0, 12.0, 70.0),
	Vector4(0, -37.0, 5.0, 10.0), Vector4(1, -42.0, 11.0, -40.0)])
## Columns of the Dead Zone's smoke from the rubble: [x, z, width, height] and colour/opacity.
@export var smoke_columns: PackedVector4Array = PackedVector4Array([
	Vector4(-20.0, 12.0, 2.4, 14.0), Vector4(22.0, 15.0, 2.0, 11.0), Vector4(-44.0, 6.0, 2.6, 16.0)])
@export var smoke_color: Color = Color(0.4, 0.394, 0.388, 0.42)
@export_range(0.0, 5.0, 0.1, "suffix:m/s") var smoke_rise: float = 0.8

@export_group("The route board")
## DESIGN-TBD (docs/questions/f2k.md, 8, 9): where the board hangs and how the wipe goes (its stops' names are TerminalIntroSign.stops).
## Where it hangs on the front: x along it (its middle) and how far its wiped strokes reach either side of that (metres: the
## hand sweeps this wide), how long the wipe takes (the pose's progress over it) and when it starts.
@export_range(-20.0, 20.0, 0.05, "suffix:m") var board_x: float = 5.2
@export_range(0.1, 1.2, 0.01, "suffix:m") var wipe_reach: float = 0.28
@export_range(0.0, 60.0, 0.05, "suffix:s") var wipe_at: float = 13.8

@export_group("The runner")
## DESIGN-TBD (docs/questions/f2k.md, 7, 9, 10, 11): where they stand, how they look about, walk, decide and climb.
## Where they stand at the start (x along the station's front, z out from it), the way they face (degrees, 0 along the
## front to the right, + turning left, toward the front) and how they look about: right, then left toward the station and up at it.
@export var start_at: Vector2 = Vector2(-3.0, 11.0)
@export_range(-180.0, 180.0, 1.0, "suffix:°") var start_yaw: float = 22.0
@export_range(0.5, 3.0, 0.05, "suffix:m/s") var walk_speed: float = 2.7
## They go round the heap: the corner they walk to first (x, z), beyond the heap's foot.
@export var walk_corner: Vector2 = Vector2(6.8, 8.0)
## The head's turns: [seconds, look (+ left), look up] keys from the start (the body does not move).
@export var looks: PackedVector3Array = PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.7, 4.0, 0.0), Vector3(1.5, -38.0, -2.0),
	Vector3(2.15, -38.0, -2.0), Vector3(3.2, 44.0, 6.0), Vector3(4.6, 52.0, 14.0), Vector3(6.4, 54.0, 16.0)])
## They set off for the board at `go_at`; at the board they stand `stand_off` from its panel (before the hand's own reach is added).
@export_range(0.0, 60.0, 0.05, "suffix:s") var go_at: float = 10.7
## After the wipe they have stepped back from the board (how far out from the front), look at it, nod (`nod_at`), and turn to
## the entrance (`turn_at`), walking off toward it.
@export_range(1.0, 4.0, 0.05, "suffix:m") var step_back: float = 2.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var nod_at: float = 19.2
@export_range(0.0, 60.0, 0.05, "suffix:s") var turn_at: float = 19.8
## The heap's foot, where they stand to look at the entrance (x, z), and the way up: when they start (`climb_from`), reach the
## crest (`crest_at`), where they start to squeeze, and are through (`through_at`).
@export var heap_foot: Vector2 = Vector2(1.9, 5.6)
@export_range(0.0, 60.0, 0.05, "suffix:s") var climb_from: float = 22.5
@export_range(0.0, 60.0, 0.05, "suffix:s") var crest_at: float = 25.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var through_at: float = 26.9

@export_group("The cameras")
## DESIGN-TBD (docs/questions/f2k.md, 7, 13): every shot's place, look and lens.
## Points are in the station's frame (x along its front, y up, z out from it) unless a comment says otherwise; each shot's lens is its
## own `fov` (vertical degrees). The face: in front of the runner, `forward` metres ahead and `right` to their right (negative: their
## left, the gold eyepiece's side) at their eye line, easing in from `face_from` to `face_to` (x forward, y right, z fov).
@export var face_from: Vector3 = Vector3(0.95, -0.2, 30.0)
@export var face_to: Vector3 = Vector3(0.82, -0.18, 30.0)
## The sweep round them (by their right) to behind them: the radius from and to (m), the angle round (degrees from in front of them),
## the height and lens it ends at (x, y), the wasteland it looks over on the way and the station it ends looking at.
@export var sweep_radius: Vector2 = Vector2(0.9, 2.5)
@export var sweep_angle: Vector2 = Vector2(16.0, 158.0)
@export var sweep_end: Vector2 = Vector2(1.7, 52.0)
@export var sweep_over: Vector3 = Vector3(10.0, 1.6, 7.0)
@export var sweep_scene: Vector3 = Vector3(1.0, 9.0, 0.0)
## The station's front from across the street (its z held inside the street's right wall): wide, then craning up and pushing in on the
## sign. [from, look, fov] each.
@export var wide_from: Vector3 = Vector3(-5.0, 2.0, 23.0)
@export var wide_look: Vector3 = Vector3(-1.5, 8.2, 0.0)
@export_range(20.0, 100.0, 1.0, "suffix:°") var wide_fov: float = 66.0
@export var crane_from: Vector3 = Vector3(-0.5, 6.5, 19.0)
@export var crane_look: Vector3 = Vector3(1.5, 16.5, 0.0)
@export_range(20.0, 100.0, 1.0, "suffix:°") var crane_fov: float = 54.0
## Following the runner across the forecourt (offsets from them, in track axes: x toward the street, y up, z along the front to the right):
## the camera and what it looks at, at the start and at the end of the shot, and the lenses.
@export var follow_from: Vector3 = Vector3(2.2, 1.25, 2.7)
@export var follow_look: Vector3 = Vector3(-1.4, 0.75, -0.5)
@export var follow_to: Vector3 = Vector3(1.8, 1.1, 2.3)
@export var follow_look_to: Vector3 = Vector3(-1.0, 0.8, -0.2)
@export var follow_fov: Vector2 = Vector2(46.0, 44.0)
## At the board as they wipe it, from their right front (offsets from the board's middle along the front, its height and out from the
## front): the camera and its look, then the camera at the end; the lenses.
@export var wipe_cam: Vector3 = Vector3(3.0, 1.15, 3.2)
@export var wipe_cam_to: Vector3 = Vector3(2.6, 1.15, 2.9)
@export var wipe_look: Vector3 = Vector3(0.0, 1.0, 0.1)
@export var wipe_fov: Vector2 = Vector2(40.0, 38.0)
## The close-up of the board, square in front of it: how far out (m) and the lens, then the push in toward the Palace at its foot (the
## camera's and look's offsets from the board's middle: along, up, out) and the lens.
@export_range(0.5, 4.0, 0.05, "suffix:m") var board_out: float = 1.5
@export_range(20.0, 100.0, 1.0, "suffix:°") var board_fov: float = 50.0
@export var board_push: Vector3 = Vector3(-0.25, -0.3, 0.85)
@export var board_push_look: Vector3 = Vector3(-0.2, -0.38, 0.1)
@export_range(20.0, 100.0, 1.0, "suffix:°") var board_push_fov: float = 42.0
## Making up their mind: close on them from beside the board (offsets: along from the board, height, out), looking at them, and at the end.
@export var mind_cam: Vector3 = Vector3(1.0, 1.1, 0.9)
@export var mind_look: Vector3 = Vector3(0.0, 1.1, 0.0)
@export var mind_cam_to: Vector3 = Vector3(0.9, 1.08, 1.0)
@export var mind_look_to: Vector3 = Vector3(-0.1, 1.06, 0.1)
@export var mind_fov: Vector2 = Vector2(28.0, 26.0)
## The entrance: low behind them at the heap's foot (offsets from the foot), looking up the heap at the crack of light; the look, and at the end.
@export var door_cam: Vector3 = Vector3(2.8, 0.95, 5.2)
@export var door_look: Vector3 = Vector3(0.0, 3.0, 0.0)
@export var door_cam_to: Vector3 = Vector3(2.2, 1.0, 4.4)
@export var door_look_to: Vector3 = Vector3(0.0, 3.4, 0.0)
@export var door_fov: Vector2 = Vector2(52.0, 48.0)
## The climb: from beside the heap, then close on the crack as they squeeze in ([camera, look, fov] each: beside, nearer, close, at the end).
@export var climb_cam: PackedVector3Array = PackedVector3Array([Vector3(-6.0, 2.0, 7.5), Vector3(0.8, 2.3, 3.2), Vector3(50.0, 0.0, 0.0),
	Vector3(-3.5, 3.0, 6.0), Vector3(0.4, 3.2, 1.0), Vector3(46.0, 0.0, 0.0),
	Vector3(-1.8, 3.6, 2.5), Vector3(0.2, 3.95, 0.1), Vector3(38.0, 0.0, 0.0),
	Vector3(-1.5, 3.7, 2.2), Vector3(0.2, 3.95, -0.4), Vector3(36.0, 0.0, 0.0)])
## Inside, in the way in's frame (x along the wall, y up, z out of it into the hall) [camera, look, fov] each: at the crack and the runner
## coming out of it, following the jump, round to the landing, and looking down the line, easing in.
@export var inside_cam: PackedVector3Array = PackedVector3Array([Vector3(-1.2, 1.6, 7.6), Vector3(0.2, 3.7, 0.0), Vector3(52.0, 0.0, 0.0),
	Vector3(-1.6, 1.7, 7.4), Vector3(0.2, 3.5, 0.3), Vector3(52.0, 0.0, 0.0),
	Vector3(-3.0, 1.5, 6.6), Vector3(4.0, 1.3, 4.4), Vector3(54.0, 0.0, 0.0),
	Vector3(-4.4, 1.55, 5.5), Vector3(14.0, 1.9, 4.6), Vector3(56.0, 0.0, 0.0),
	Vector3(-3.3, 1.55, 5.2), Vector3(14.0, 1.95, 4.6), Vector3(52.0, 0.0, 0.0)])
