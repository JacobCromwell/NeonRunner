class_name MarketplaceIntroTuning
extends Resource
## The Marketplace intro's numbers (MarketplaceIntro; data/cinematics/marketplace_intro_tuning.tres). The beats are the
## owner's (October 16, 2026): the runner walks up to one stall in a line of market stalls (the Marketplace's stall
## doodad), a citizen inside it; they show her a card with a photo of the Corporate zone's boss's face on it, and the
## camera closes in on it (a teaser of who they're after), its writing scribbled and hard to read; she waves her arms
## about and mumbles (no real words: speech-like sounds, as the grown-ups talk in Charlie Brown); the runner nods a
## couple of times and walks off. A cyborg of the zone walks up to her and talks to her in a gruffer voice; she talks
## again and points after the runner; the cyborg waves some other cyborgs over and they set off after the runner.
## The rest (timings, distances, the camera's places, her look, the sounds) is DESIGN-TBD (docs/questions/f2f.md).
## Times are seconds from the start; points are track space (CineStage: x metres right of the start lane's centre,
## y up, z ahead), most of them from the front of her stall's counter where she stands (x out into the street).

@export_group("Timing")
## The owner's beats take longer than GDD §1's 5-15 s, as the Beach outro's do. It ends on black: the level opens on
## its own view.
@export_range(10.0, 60.0, 0.1, "suffix:s") var duration: float = 38.6
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in: float = 1.2
## The zone's music comes in under it, quietly, from the start.
@export_range(0.0, 8.0, 0.1, "suffix:s") var music_fade: float = 4.0
## At the end it fades to black at `fade_at` over `fade_out`, the zone's title card coming up with it and holding on
## the black for `card_seconds` (its own fades included), ending before the cinematic does.
@export_range(10.0, 60.0, 0.05, "suffix:s") var fade_at: float = 35.4
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_out: float = 1.3
@export_range(1.0, 5.0, 0.05, "suffix:s") var card_seconds: float = 2.9
## The stretch of street (metres; the finish line the track builder draws at its end stays out of view).
@export_range(200.0, 2000.0, 10.0, "suffix:m") var stage_length: float = 420.0

@export_group("The stalls")
## The line of stalls along the left of the street: how many, which of them is hers (from the first, the nearest the
## runner comes from), and where hers stands along the track (its middle).
@export_range(3, 12) var stall_count: int = 8
@export_range(0, 11) var vendor_stall: int = 4
@export_range(80.0, 300.0, 0.5, "suffix:m") var stall_at: float = 150.0
## The stall doodad (the Marketplace's medium doodad, its picture cards) scaled to the characters, as the Beach
## outro's tiki bar is (the runner is 1.28 m tall); the gap between neighbouring stalls; how far in from the left wall
## line their backs stand.
@export_range(0.4, 1.2, 0.01) var stall_scale: float = 0.72
@export_range(0.0, 2.0, 0.05, "suffix:m") var stall_gap: float = 0.4
@export_range(0.0, 1.0, 0.01, "suffix:m") var stall_inset: float = 0.12
## The stalls' awnings in a few colours (the picture's blue repainted; a = 0 keeps it blue), in turn along the line;
## hers is the first. Plain market colours, never a hazard's.
@export var awning_colors: PackedColorArray = PackedColorArray([Color(0.22, 0.38, 0.63, 0.0),
	Color(0.24, 0.5, 0.3, 1.0), Color(0.5, 0.3, 0.6, 1.0), Color(0.18, 0.52, 0.55, 1.0), Color(0.62, 0.5, 0.22, 1.0)])

@export_group("The vendor")
## Her height, and where she stands in her stall: back from the counter's front.
@export_range(1.0, 1.6, 0.01, "suffix:m") var vendor_height: float = 1.25
@export_range(0.2, 0.8, 0.01, "suffix:m") var vendor_back: float = 0.4
## Her place along the counter from the stall's middle (+ further down the street), between the stall's picture's
## middle post and its hanging lanterns, so neither stands between her and the card. The counter's points
## (MarketplaceIntroSet.counter) are measured from here.
@export_range(-1.2, 1.2, 0.01, "suffix:m") var counter_along: float = -0.36
## She talks to the runner (her arms waving about), and later to the cyborg, pointing after the runner as she does.
## Each line lasts as long as its mumble (tools/asset_gen/sfx_bank_marketplace_intro.gd).
@export_range(0.0, 60.0, 0.05, "suffix:s") var talk_at: float = 10.55
@export_range(0.5, 4.0, 0.05, "suffix:s") var talk_seconds: float = 2.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var reply_at: float = 24.9
@export_range(0.5, 4.0, 0.05, "suffix:s") var reply_seconds: float = 2.1
## She points after the runner from `point_at` for `point_seconds`.
@export_range(0.0, 60.0, 0.05, "suffix:s") var point_at: float = 25.5
@export_range(0.5, 6.0, 0.05, "suffix:s") var point_seconds: float = 3.6

@export_group("The runner")
## They walk in from here (from the counter's front where she stands) at this pace and stop at the counter this far out from
## it; the walk starts `walk_at`.
@export var walk_from: Vector3 = Vector3(1.7, 0.0, -6.6)
@export_range(0.0, 3.0, 0.05, "suffix:s") var walk_at: float = 0.2
@export_range(0.5, 2.5, 0.05, "suffix:m/s") var walk_speed: float = 1.25
@export_range(0.15, 1.0, 0.01, "suffix:m") var counter_gap: float = 0.48
## How quickly they turn (1/s; eased, as someone walking turns).
@export_range(0.5, 20.0, 0.1, "suffix:1/s") var turn_rate: float = 4.5
## They hold the card up to her from `show_at` (taking `raise_seconds` to bring it up) until `put_away_at`.
@export_range(0.0, 60.0, 0.05, "suffix:s") var show_at: float = 6.9
@export_range(0.1, 1.5, 0.05, "suffix:s") var raise_seconds: float = 0.55
@export_range(0.0, 60.0, 0.05, "suffix:s") var put_away_at: float = 12.95
## The two nods, from `nod_at` (each `nod_seconds`, tipping the head down `nod_degrees`), then they turn and walk off
## down the street at `leave_speed`, from `leave_at`, this far out into the street.
@export_range(0.0, 60.0, 0.05, "suffix:s") var nod_at: float = 13.15
@export_range(0.2, 1.0, 0.05, "suffix:s") var nod_seconds: float = 0.45
@export_range(5.0, 40.0, 1.0, "suffix:°") var nod_degrees: float = 20.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var leave_at: float = 14.3
@export_range(0.5, 2.5, 0.05, "suffix:m/s") var leave_speed: float = 1.35
@export_range(0.0, 3.0, 0.05, "suffix:m") var leave_out: float = 1.3

@export_group("The card")
## Its size (width, height; metres), where it's held up to her (from the counter's front where she stands), and the scribbles'
## seed.
@export var card_size: Vector2 = Vector2(0.13, 0.09)
@export var card_point: Vector3 = Vector3(0.1, 1.1, 0.0)
@export_range(0.0, 100.0, 1.0) var scribble_seed: float = 3.0
## The close-up on it: from `card_shot_at` for as long as the shot before the cut to her lasts, the camera this far
## from its face, pushing in to `card_close_to`, with this field of view.
@export_range(0.0, 60.0, 0.05, "suffix:s") var card_shot_at: float = 7.6
@export_range(0.1, 1.0, 0.01, "suffix:m") var card_close_from: float = 0.27
@export_range(0.1, 1.0, 0.01, "suffix:m") var card_close_to: float = 0.215
@export_range(15.0, 70.0, 1.0, "suffix:°") var card_fov: float = 36.0

@export_group("The cyborgs")
## The one who talks to her: it walks up from back down the street (from the counter's front where she stands) at this pace,
## starting `cyborg_walk_at`, and stops at the counter this far out; it talks at `cyborg_talk_at` for
## `cyborg_talk_seconds`.
@export var cyborg_from: Vector3 = Vector3(1.5, 0.0, -8.2)
@export_range(0.0, 60.0, 0.05, "suffix:s") var cyborg_walk_at: float = 16.8
@export_range(0.5, 2.5, 0.05, "suffix:m/s") var cyborg_walk_speed: float = 1.55
@export_range(0.2, 1.2, 0.01, "suffix:m") var cyborg_gap: float = 0.55
@export_range(0.0, 60.0, 0.05, "suffix:s") var cyborg_talk_at: float = 22.85
@export_range(0.5, 4.0, 0.05, "suffix:s") var cyborg_talk_seconds: float = 1.8
## It turns to the others and waves them over at `wave_at` for `wave_seconds` (with a gruff call), and they all set off
## after the runner at `go_at`, at `follow_speed`.
@export_range(0.0, 60.0, 0.05, "suffix:s") var wave_at: float = 29.55
@export_range(0.5, 4.0, 0.05, "suffix:s") var wave_seconds: float = 1.9
@export_range(0.0, 60.0, 0.05, "suffix:s") var go_at: float = 32.4
@export_range(0.5, 3.0, 0.05, "suffix:m/s") var follow_speed: float = 1.75
## The others: where each stands about, waiting, from the cut that shows the street behind her stall (x, z from the
## counter's front where she stands; w its heading, degrees, + left), and where it comes to, beside the one who waved (x, z
## from that one's place at the counter).
@export var others_wait: PackedVector3Array = PackedVector3Array([Vector3(3.6, -7.4, -150.0),
	Vector3(4.4, -8.6, 160.0), Vector3(2.4, -9.4, 20.0)])
@export var others_join: PackedVector2Array = PackedVector2Array([Vector2(1.0, -1.3), Vector2(1.9, -0.6),
	Vector2(0.4, -2.1)])
## They come over at this pace once waved over.
@export_range(0.5, 3.0, 0.05, "suffix:m/s") var others_speed: float = 2.3

@export_group("Shots")
## When each shot after the first starts (the cuts): the two of them at the counter, the card (card_shot_at), her
## talking, the runner nodding and walking off, the street behind as the cyborg comes, the cyborg and her, along her
## pointing arm after the runner, the wave, and behind them as they set off.
@export_range(0.0, 60.0, 0.05, "suffix:s") var counter_shot_at: float = 5.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var talk_shot_at: float = 10.2
@export_range(0.0, 60.0, 0.05, "suffix:s") var leave_shot_at: float = 12.85
@export_range(0.0, 60.0, 0.05, "suffix:s") var street_shot_at: float = 17.3
@export_range(0.0, 60.0, 0.05, "suffix:s") var cyborg_shot_at: float = 22.4
@export_range(0.0, 60.0, 0.05, "suffix:s") var after_shot_at: float = 26.8
@export_range(0.0, 60.0, 0.05, "suffix:s") var wave_shot_at: float = 29.1
@export_range(0.0, 60.0, 0.05, "suffix:s") var follow_shot_at: float = 32.9
