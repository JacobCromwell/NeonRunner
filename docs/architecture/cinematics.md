# Architecture: Cinematics

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Cinematics

GDD §1 tells the story mostly through the zones themselves, plus 5–15 second cinematics between levels and
zones (their story beats come from the owner later; task F2). The cinematic toolkit (`scripts/cinematics/`,
task F1) is code-driven: a cinematic is a timeline of camera keys, actors on the humanoid rig and timed
events, played on a stretch of the slot's zone.

**The flow.** A slot's `CinematicDef.scene` is a scene whose root extends `Cinematic`
(`scripts/campaign/cinematic.gd`). The App instances it under the world root and calls `play(def, step)`;
the cinematic knows its `step`, `zone` and `slot` (`&"intro"`, `&"boss_intro"`, `&"outro"`; played on its
own, it finds the campaign step whose slot holds its def). At its end it emits `finished` once, and the App
marks the step done and seen and moves on (`advance_from`), so the next step's first frame follows at once.
**Skipping:** the pause action (Esc / P) or the cinematic's Skip button emits `skip_requested`, the App
answers with `skip_cinematic()` → `skip()`, and the cinematic ends within the call. `App.playing_cinematic()`
is the one playing. A cinematic holds while the game is in the background (focus lost, app paused), so it
never ends, and a level never starts, unattended.

| File | What |
|---|---|
| `cinematic_sequencer.gd` (`CinematicSequencer`) | the player: builds the stage, actors, camera and overlay, runs the clock (`advance`), fires the events, emits `finished`; `skip()`; `log_lines` lists every event fired (tests, the review tool); a script's hooks: `_on_cue()`, `_on_advance()` (its own props on the clock), `_stage_near()` (the street kept built under props further back), `switch_stage()` (a cut to another stretch, even another zone's) |
| `cine_timeline.gd` (`CineTimeline`) | one cinematic: `duration`, `letterbox`, `stage`, `camera` keys, `actors`, `events`; helpers to build one in a script (`shot`, `actor`, `sound` (at its own level over the library's), `music`, `card`, `effect`, `cue`); `problems()` checks it; `sort()` |
| `cine_key.gd`, `cine_path.gd` (`CineKey`, `CinePath`) | a key's time and how the path comes into it: `SMOOTH` (a flight through the keys, velocity carrying on through each), `LINEAR` (a straight move eased by Tween's transition and ease types) or `CUT`; `sample_riding` for keys that ride with an actor |
| `cine_camera_key.gd` (`CineCameraKey`) | where the camera is (`position`), what it looks at (`target`), `fov`, `roll`; `follow` / `watch` an actor: the point is then an offset from it |
| `cine_actor.gd`, `cine_actor_key.gd`, `cine_actor_node.gd` | an actor (`RUNNER`: Razor Echo's `PlayerAvatar`; `CYBORG`: a `CyborgBody` in the zone's look or a look of its own, a host or not), its keys (position, pose, a pose's `progress`, heading, the head's turn `look` and tip `look_up`, a cyborg's face, aim and charge) and its node in play |
| `cine_poses.gd` (`CinePoses`) | the runner's poses that play out over a key's `progress` rather than following movement: lying on its back (`lie`), getting up to reach up (`get_up`), climbing out over an edge (`climb`, its hands holding the keys' position), getting into a low car from beside its open door (`get_in`); its legs step while it is moved meanwhile (not while getting in: its legs are its key poses); and a walk at walking pace (`walk`), its planted feet staying put |
| `cine_event.gd` (`CineEvent`) | `SOUND` (a sound effect), `MUSIC` (a track, `@zone`, or none), `TEXT` (a card), `EFFECT` (`fade_in`, `fade_out`, `flash`, `shake`, `letterbox_in`, `letterbox_out`), `CUE` (a script's own moment) |
| `cine_stage_def.gd`, `cine_stage.gd` (`CineStageDef`, `CineStage`) | the set: a stretch of track built by the `TrackBuilder` in the zone's skin, with its sky and fog (`ZoneSkin.level_environment(0, sky)`: before a boss the fight's level sky, `sky_for`, otherwise the zone's own) and the run's sun; ceilings, gaps, pads and openings in the side walls (`wall_gaps`, dressed by the skin as in a level); `after_fight`: a stage straight after the zone's fight (an outro picking up where it ended) takes the fight's look and sky, as a boss intro does; streamed in chunks like a run |
| `cine_overlay.gd` (`CineOverlay`) | the 2D layer: letterbox bars, fades, flashes, text cards (menu fonts, capitals) and the Skip button (showing the pause key), in the safe area |
| `arrival_flyover.gd`, `arrival_flyover_tuning.gd`, `scenes/cinematics/arrival_flyover.tscn`, `data/cinematics/arrival_flyover.tres` | the placeholder arrival flyover (below) |
| `city_outro.gd`, `city_outro_set.gd`, `city_outro_tuning.gd`, `scenes/cinematics/city_outro.tscn`, `data/cinematics/city_outro_tuning.tres` | the Neon City's outro (below) and its props |
| `sewer_swarm_intro/` (`SewerSwarmIntro`, `SewerSwarmIntroTuning`, `SwarmIntroScreeches`, `SwarmIntroSwarm`, `swarm_intro_glint.gdshader`), `scenes/cinematics/sewer_swarm_intro.tscn`, `data/cinematics/sewer_swarm_intro.tres` | Gangland's boss intro, the owner's story beat (below) |
| `gangland_outro/` (`GanglandOutro`, `GanglandOutroTuning`, `GanglandOutroSet`, `SportsCarModel`, `sports_car.gdshader`, `CarPassenger`), `scenes/cinematics/gangland_outro.tscn`, `data/cinematics/gangland_outro_tuning.tres` | Gangland's outro, the owner's beats (below), its props, the sports car and the screech on its passenger seat; its sounds in `tools/asset_gen/sfx_bank_gangland_outro.gd` |
| `dead_zone_intro/` (`DeadZoneIntro`, `DeadZoneIntroTuning`, `DeadZoneCrater`), `scenes/cinematics/dead_zone_intro.tscn`, `data/cinematics/dead_zone_intro_tuning.tres`, `tools/asset_gen/sfx_bank_cinematics.gd` | the Dead Zone's intro, the owner's story beat (below), and its sounds |
| `beach_outro/` (`BeachOutro`, `BeachOutroTuning`, `BeachOutroBar`, `BeachOutroScreech`, `BeachOutroPalace`, `BeachOutroRaid`), `scenes/cinematics/beach_outro.tscn`, `data/cinematics/beach_outro_tuning.tres`, `tools/asset_gen/sfx_bank_beach_outro.gd` | the Beach's outro, the owner's beats (below), its props and its two sounds |

**Track space.** Every point is `(x, y, z)`: x metres right of the start lane's centre (the lane a level's
runner starts in, `lane_count / 2`), y metres up from the floor, z metres along the track. So a point
at x = 0 is on a lane's centre at 3, 5 and 6 lanes alike; `CineStage.point()` / `to_track()` convert,
and `lane_x()`, `wall_x()` and `lane_from_start()` give the street's geometry for scripts. Stage lanes are
counted from the start lane too (a lane past the street's edge is left out).

**The stage picks up the slot's look from the zone's data.** A stage def without a skin of its own takes
the slot's (`CineStage.skin_for`): the zone's skin (`ZoneDef.skin`), and before a boss the fight's arena's
(`BossDef.arena.skin`) if it has one. Before a boss it is under the fight's sky too (`CineStage.sky_for`: the
arena's own level sky, else the zone's last level's, as `Campaign.configure_boss` gives the fight; G8), and the
street's light under it; a zone's intro and outro keep the zone's own sky (unless a stage is `after_fight`, as
Gangland's outro's are: then it's under the fight's sky and in the arena's look). Its lanes default to the device's (`App.lane_count()`), so the street
matches the level that follows. A `@zone` music cue plays the slot's track (`ZoneDef.music`, or before a
boss `BossDef.music` if set); a track the music library doesn't list yet is skipped quietly and the music
playing carries on, so a song the owner adds later under that name just plays (no music is generated for
cinematics, GDD §11). Text on cards may name `{zone}`, `{zone_number}`, `{boss}` and `{title}`
(translated, then filled in). So a later change of a zone's skin, music or name reaches its cinematics.

**Cameras.** Keys are sampled with `CinePath`: `SMOOTH` keys make a Hermite spline timed by the keys (a
Catmull-Rom whose tangents come from the neighbouring keys), with no jolt at any key; `LINEAR` keys ease
with Tween's curves (`TRANS_SINE` + `EASE_IN_OUT` starts and ends at rest); a `CUT` holds, then jumps. A key
that follows (or watches) an actor gives an offset from it: between two keys riding with the same actor
the camera rides along, its offset moving through the keys; between a fixed key and a riding one it flies
through where each key will be at its own time; the velocity carries on through every key either way.
Straight up or down, the camera's up is the track's direction. `shake` follows the Screen shake setting.
A camera flying over a street must keep out of what hangs over it: nothing does below about 10 m in any
zone except ceilings (6 m up, their structure up to about 13 m), so keep under 9.5 m over open street and,
over a ceiling or within a few metres of one, at least `camera_ceiling_clearance` (1 m) under its underside,
as the run camera does (closer, the ceiling's end glow fills the screen); the tests check the flyovers so.

**Actors.** The runner is the real player model (`PlayerAvatar`), driven with the same movement state as
in play: its stride keeps pace with the ground it covers, it is in the air above the floor (with its jump
poses), leans into sideways moves like a lane switch, and takes `slide`, `dash`, `stomp` and `dead` from its
keys; it is in the air below the floor too (falling past its edge). Its poses that play out over time
(`CinePoses`: `lie`, `get_up`, `climb`, `get_in`) take the keys' `progress` (0-1, sampled like the position; a key below 0
keeps the one before) instead of its movement: blended key poses, put on the ground, the body tipping about its
hips; moved along meanwhile, its legs step (a walk's stride, so it can stagger forward as it rises; not while it
gets in, whose legs are its key poses); and while it
climbs, its hands hold the keys' position (the body hangs from them) until a foot takes its weight
(`CinePoses.LET_GO`). Its `walk` follows its movement instead (the run cycle at a walk's speed shuffles): heel
strike, a bent knee through the swing, the foot rolling off its toe, the hips and shoulders turning against each
other, the arms swinging; while a foot is down it goes back under the hip at exactly the body's pace (the thigh
worked out from where the foot must be and the knee's bend, turned back against the pelvis's turn and drop), and it
swings forward to land moving at that pace, so the feet don't skate. The stride follows the ground covered (shorter
when slow); turning on the spot it steps in place; stopping, it settles into standing at ease, breathing, its
weight shifting. Its pace and stride follow its movement over a moment (`CineActorNode.GAIT_SMOOTH`), so a sudden
change in speed or turning never jumps its pose in a frame (`test_gangland_outro` checks no knee moves further in
a frame than a full stride's swing does). An actor with a `turn_rate` of its own eases into and out of its turns
(critically damped; the toolkit's default turn starts at full speed). On its first frame, and after a jump cut
(`CineActorNode.MAX_STEP`), an actor moves as its path goes on from there: it faces that way at once and starts in
its stride. A cyborg (`CyborgBody`) walks or idles by its speed, or takes `aim`, `run_away`, `cower`,
`die`, `lie` (lying still, its screen dark) or `crouch` (crouched low over something, working at it; it stops as
it turns its head); its keys set its face, its aim (at another actor) and its charge glow (the red glow is its
attack's warning in play, so show it only where an attack follows). Either's head turns by its keys' `look`
(shared by its chest, neck and head) and tips by `look_up` (its neck and head; a cyborg's chest a little too, and
a cyborg's turn is about its upright, so a bowed head turns without rolling over), smoothly between keys. The
models move on the cinematic's clock, never by themselves between frames (the runner's rig by its update; a
cyborg's body by `CyborgBody.advance`), so stepping the clock shows the same (but for a cyborg's `die` fall, a tween,
and a host's random face glitches). An actor faces the way it moves, or
a heading of its keys; it's in the scene from `enter` to `leave`. Actors are visual only: no collision, no
gameplay.

**Reduced flashing and comfort.** `flash` becomes a slow, faint glow with Reduced flashing
(`CineOverlay.SOFT_FLASH_ALPHA`, `SOFT_FLASH_MIN_TIME`); nothing in the overlay blinks; the skins honour it
as in play; `shake` is scaled by Screen shake (0 when it's off).

**Writing a cinematic.** In data: a scene whose root is `CinematicSequencer` with `timeline` set to a
`CineTimeline` resource (`tools/showcase/cinematic_sampler.tres` shows every kind of key and event but the poses that
play out over time, which `test_cinematics` plays). Or in
a short script, which can use the stage's geometry:

```gdscript
extends CinematicSequencer   # the root of scenes/cinematics/<name>.tscn; the slot's CinematicDef.scene

func _stage_def() -> CineStageDef:          # the set; no skin: the zone's (from its data)
	var d := CineStageDef.new()
	d.ceilings = PackedVector2Array([Vector2(120.0, 170.0)])
	return d

func _make_timeline() -> CineTimeline:      # `stage` is built by now
	var t := CineTimeline.new()
	t.duration = 8.0
	var runner: CineActor = t.actor(&"runner")
	runner.at(0.0, Vector3(0.0, 0.0, 0.0), &"run")
	runner.at(8.0, Vector3(0.0, 0.0, tuning.run_speed * 8.0))  # LINEAR keys: a steady run
	t.shot(0.0, Vector3(stage.wall_x(1) - 2.0, 3.0, 10.0), Vector3(0.0, 1.0, 0.0))
	var ride: CineCameraKey = t.shot(8.0, Vector3(0.0, 4.2, -7.5), Vector3(0.0, 1.0, 14.0))
	ride.follow = &"runner"                 # the run camera's view of the runner
	ride.watch = &"runner"
	t.music(0.0, CineEvent.ZONE_MUSIC, 1.5)
	t.card(1.0, "{zone}", "ZONE {zone_number}", 3.0)
	t.effect(0.0, CineEvent.FADE_IN, 0.8)
	t.effect(7.6, CineEvent.FADE_OUT, 0.4)
	return t

func _on_cue(cue_name: StringName) -> void:  # a CUE event's moment (the `cue` signal fires too)
	pass

func _on_advance(delta: float) -> void:      # every step of the clock: move the script's own props by `time`
	pass
```

A script's props (models of its own that aren't actors) are plain nodes it adds in `_make_timeline()` and
moves in `_on_advance()` from `time`, so they keep time when a test steps the clock (added on the stage, they hide
with it when it ends). If they stand further back than the camera and the actors (a horde behind the runner),
`_stage_near(near)` returns how far back the stage must stay built (the track builder keeps only 30 m behind
`near`, and builds 180 m ahead of it: hold it back only as far as the props need, or the street ahead of a camera
looking down it ends short). `switch_stage(def, skin)` cuts to another stretch on the same lanes (track space stays put; cut under
black, since building one takes a few frames).

Then set the slot's `CinematicDef.scene` to the scene. End on the run camera's view of the runner
(`MovementTuning`'s camera numbers) or on black, since the next step opens on its own view at once.
`tools/showcase/cinematic_review.tscn` plays any slot's cinematic on its own for renders (`--slot=<step
id>`, `--sampler`, `--lanes=N`, `--reduced-flashing`, `--once`, `--from=S` to start S seconds in), printing
each event with its frame.

**The arrival flyover** (DESIGN-TBD, `docs/questions/f1.md`; `ArrivalFlyover`, a short script with its
numbers in `data/cinematics/arrival_flyover.tres`): every zone's intro slot (but the Dead Zone's, which has the
owner's beats) and the City's boss intro play it until the owner describes the story beats. It opens low in the street looking up at the zone's skyline
and tilts down as the runner runs in beneath it, glides over the street behind the runner, and settles into
the run camera's view as they run under one of the zone's ceilings; a card names the zone ("ZONE 1", "NEON
CITY"; before a boss, the boss, as the level select does), the slot's music comes in, and it fades to black
after 9.5 s, as the level (or the fight) opens on the same view. Gaps beside the runner's lane show the
zone's floor pieces. It sets up in about 15-40 ms and costs about 0.3 ms a frame (headless), so it stays
cheap on the web, where the demo plays the City's two.

**The City outro** (`CityOutro`, task F2a; the owner's beats, GDD §6 Cinematics; its staging is DESIGN-TBD,
`docs/OPEN_QUESTIONS.md` §D, items 369–381; numbers in `data/cinematics/city_outro_tuning.tres`): 15 s. From the run camera's view
the dying Floating Head plunges into the street ahead and becomes the fight's wreck. The camera comes down to
the runner's level as they stop. They look left, and the camera pans over their shoulder to a roadblock at the
mouth of a side street opening off the left wall. The roadblock is Barnacle Turrets standing on the floor like
cannons, five cyborgs (actors), an Enforcer Truck behind them with its light bar going, and a heli drone over
it. The camera pans back to the runner, who hops back startled and sprints to an opening in the right wall.
They leap out over the drop as the roadblock's red volley blows up the roof behind them, seen from out over
the drop. Under black it cuts (`switch_stage`) to the next zone's street (the campaign's next `ZoneDef.skin`,
Gangland), where they drop in, land and run off; Gangland's intro follows.

`CityOutroSet` holds the props, all visual only and built from the game's own models: the ship from
`FloatingHeadModel` (hull, face screen with the fight's shader, jaw, wreck), `BarnacleTurretModel` turned
over, `EnforcerTruckModel`, the drone's model (`drone.gd`'s static `add_model`, which the enemy uses too),
the blast (one of the shared fireballs, GDD §11, from a one-slot `FireballPool` of its own built with the props,
`build_blast`: a cinematic has no `RunEffects`), and a code-built barricade. The side street's floor and both
openings' building fronts come from the stage's skin (`ZoneSkin.floor_segment`, `wall_section`), so they follow
the zone's look. Reduced flashing holds the dying face's glitch and the light bar steady, and softens the blast's
fireball (no white-hot core).
Music: the zone's track, fading as the runner leaps; the web demo, which ends after this, never loads
Gangland's. Cost (headless, `test_city_outro`): about 25 ms to set up (about 220 ms the first time, with cold
mesh caches), about 10 ms for the cut (under black), at most about 3 ms a step, and its props add about 65
draw calls. It adds no asset files.

**Gangland's boss intro** (`SewerSwarmIntro`, task F2b; the owner's story beat, October 9, 2026, GDD §10 Sewer Swarm;
what it leaves open is DESIGN-TBD, `docs/OPEN_QUESTIONS.md` §D, items 387–395; numbers in `data/cinematics/sewer_swarm_intro.tres`):
12 s before the Sewer Swarm, on a plain stretch of the fight's arena look in the fight's lanes, the runner
running at the fight's speed (the zone's) down the start lane between rows of manholes one lane over, the camera
at ground level throughout (0.47-0.75 m up). The beats: one screech at 2 s (it pounces into the runner's lane
and lands under them as they jump), three at 3 s (one leaps over the runner's lane as they slide under it, two
land in it ahead and swipe as they weave round them), eleven at 4 s (five left, six right, landing either side of
the runner's lane and rearing up as they run past), each out of a manhole that rattles first; then from 5 s the
manholes around the runner burst one after another, more and more screeches pouring out, and from 5.6 s more
drop from above the camera's view, all running beside the runner (never in their lane) and dropping back. The
camera swings round the runner's right side (5.0-6.4 s, kept off the wall) to low in front of them looking back:
from 6.3 s the wall rises behind them (one of the swarm's wave formations as wide as the street, the rest of the
swarm behind it, heating toward enemy-attack red) and closes in to 9 m. At 9.6 s the one cut, to low between the
runner and the wall, looking into a dark hollow in the middle of the mass, ringed by screeches; the Host is held
up in the dark, a faint silhouette, and the implant at its temple glints red once (a slow, faint glow with
Reduced flashing); then black, and the fight. The props are its own, built on the stage (so they hide with it) and moved by the clock (`_on_advance`):
`SwarmIntroScreeches` (the manholes in one MultiMesh drawn and animated like the fight's lairs, `SwarmLairs.mesh`
and `swarm_lair.gdshader`; the beats' fifteen on the sewer screech's own body, `ScreechModel`; the pour and the
rain in one MultiMesh of its crowd body, placed in script from the clock) and `SwarmIntroSwarm` (the wall's two
`SwarmCrowd`s, the hollow, its mound in a MultiMesh, the Host on the rig with `SwarmHostPerson`'s look darkened
by its tint, and the glint, `swarm_intro_glint.gdshader`). Everything is worked out from the time, so stepping or
skipping it shows the same; anything behind the wall's foot is hidden (lost in it), and no screech is drawn
within 0.9 m of the camera. Crowd sizes are data, smaller on a low-end device. It sets up in about 15 ms (about 230 ms
the first time, with cold mesh caches) and costs about 0.6 ms a step, at most about 3 ms (headless,
`test_sewer_swarm_intro`); its props add about 25 draw calls. It adds no asset files, and one toolkit hook,
`_stage_near()`: the street stays built under the swarm behind the runner (the track builder keeps only 30 m
behind the camera and the actors).

**Gangland's outro** (`GanglandOutro`, task F2d; the owner's beats, October 9, 2026, GDD §6 Cinematics; what they
leave open is DESIGN-TBD, `docs/questions/f2d.md`; numbers in `data/cinematics/gangland_outro_tuning.tres`; the
owner's follow-up, October 10, 2026: the runner's movement more fluid, a shot of them getting in beside a cute
screech, the car faster; and then: the screech one of those from before, the two nodding to each other): 22.4 s
after the Sewer Swarm, both stretches picking up where the fight ended (`CineStageDef.after_fight`: the
arena's look under Gangland 3's blood-red sky), on the level's lanes. The fight's music fades out as it opens. Low
beside the Host, who lies freed against a heap of rubble, implants dark, looking back up the street: four screeches
sniff at them, look up as the runner comes walking down the street, spines up (never the full bristle of their attack), and
scuttle off into the gutters. Over
the runner's shoulder as they walk up (`CinePoses.walk`, at about 1 m/s) and stop beside the Host, turning to them
unhurriedly. Low in front of the Host: trembling (harder as they
strain), they look up, sit up a little and hold a golden key out to the runner; it glints (a bell chime and a slow
halo); the runner leans in and takes it (both arms reach for the same point, so the hands meet and the key passes
from one to the other), the Host sinks back, the runner looks at the key. Black, and the cut (`switch_stage`) to
another stretch where the car is parked: low off its front corner as the runner walks up holding out the key, the
car unlocking with a chirp and two blinks of its lights (one slow glow with Reduced flashing), its scissor door
swinging up and its courtesy lights coming on. Cut inside: from behind the dashboard, looking back at both seats and
out of the open door (the car's panels are one-sided, so the camera sees through the windscreen's back), the runner
steps in over the sill, ducks in and sits down (`CinePoses.get_in`) beside a screech sitting up on the passenger seat
(`CarPassenger`), which looks round at them with a tilt of its head; once they're sat they look round at it, it
nods to them with a chirp and they nod back; the door comes down behind them and the engine starts. Cut to the road
behind it (the runner out of sight from here), at road level (0.16 m up, the owner's ask), as it
launches, wheels spinning up, and tears off down the street (24 m/s², about 115 m in its 3.1 s) into the distance;
black, and the Marketplace's intro.

`GanglandOutroSet` holds the first scene's props, built on its stage: the rubble (slabs, chunks and rebar in the
street's kit material, one draw call), the Host (`SwarmHostPerson` on the humanoid rig, its glow dimmed; posed by
script: reclined, breathing, trembling, the offering arm turned toward the hand-off point) and the screeches
(`ScreechModel`, as in play). `SportsCarModel` is the car, built by code: a faceted wedge lofted through eleven
cross-sections (a blade of a nose, a raked windshield, flared fenders over angular wheel wells, a dark intake
behind the door, a wing), a scissor door hinged at its front edge over a cabin with two raked seats (their piping
glowing with the courtesy lights, which also cast a warm `OmniLight3D` on whoever is in it), four wheels that
turn with the distance driven, head and tail lights, running lights, glow underneath and headlight pools (MeshKit's
glow material, scaled by its lights). Its paint (`sports_car.gdshader`) is unshaded, like the kit: a fake key light
and a fake street mirrored in it (a sharp horizon, shopfront neon streaming back as it drives) under a clear coat,
so it shines the same on the Compatibility renderer; it follows a level's light and the street's tint under a
level's sky. Its look (size, paint, accent) is data. The key is the cinematic's own node (it goes from the first
scene into the second), held in a hand joint. The runner's reach, lean, look at the key and raised key are
layered on their pose in `_on_advance`, each easing in and out (`aim_arm` turns an arm toward a point; the rig sets
every joint afresh each update, so nothing builds up). `CarPassenger` is the screech on the passenger seat, a child
of the car: the screeches' own body (`ScreechModel.mesh()`, its material and shader, calm), posed sitting
(`sitting_meshes`: each part's triangles turned about its joint, the head level, the paws held up, the front legs
tucked, the hind feet forward on the seat, the tail curled round on it, then the body tipped up about its hips), its
head a mesh of its own so it can turn and nod; its look round, head tilt and nod are worked out from the time. Shots looking back up the street keep it built behind them
(`_stage_near`). Its sounds are seven new ones (`tools/asset_gen/sfx_bank_gangland_outro.gd`: `screech_sniff`,
`key_glint`, `car_unlock`, `car_door`, `screech_chirp` as the passenger nods to the runner, `car_start` as its lights
come on and `car_drive` at the launch) and the
fight's `host_short` and `swarm_scatter`. Cost (headless, `test_gangland_outro`): about 25 ms to set up (about 350 ms the first time, with
cold mesh caches), about 20 ms for the cut to the car (under black), about 10 ms on the two hard cuts (the street
building ahead) and about 0.4 ms a step otherwise; its props add about 22 draw calls (the Host on the rig is 16).

**The Dead Zone's intro** (`DeadZoneIntro`, task F2c; the owner's story beats and answers, October 9, 2026, GDD §6
Cinematics; what they leave open is DESIGN-TBD, `docs/questions/f2c.md`; numbers in
`data/cinematics/dead_zone_intro_tuning.tres`): 14.3 s before Dead Zone 1, on a stretch of the zone's street in the
level's lanes. A smoking crater is a gap in the runner's lane (`CineStageDef.gaps`), so it looks like one; the runner
lies on their back on its floor 1.42 m down, stirs, shakes their head as they sit up, gets to their feet, staggers to
the far wall and reaches up. The camera looks down into it from high over its far end, the street beyond and the
cyborgs down it in view. At 5.75 s it cuts to ground level 1.3 m beyond the far edge: at first only the runner's
hands come up over the edge and grab it, then they climb out (`CinePoses.climb`, the hands holding the edge) and
stand on the street as the camera rises and pulls back. Throughout, 16 m down the street behind the crater, two
cyborgs lie still with their screens dark and a host crouches over them, working at them; as the runner gets up it
looks over, and at 8.6 s, mid-turn, the cut to a medium shot of it from the runner's side, so it turns to look into
the camera. At 10 s the cut to an extreme close-up of its screen face: the camera straight in front of the screen as
it is at the cut (`frame_face`, measured from the head, the head held still: `CyborgBody.twitches`), the whole face
filling 80% of the picture inside the letterbox (its height, or its width on a screen narrower than the face),
pushing in to 92%, its corrupted grin glitching harder (the shader's `glitch`, 1.8). At 11.5 s it starts to fade to
black, and the zone's title card ("ZONE 7", "DEAD ZONE", from the zone's data as the flyovers' are) comes up with
it and holds on the black; then the level. The actors are the timeline's; the crater's inside is the cinematic's own
prop, `DeadZoneCrater`, built on the stage so it hides with it: a floor of the zone's own street plates
(`ZoneSkin.floor_segment`) tipped this way and that, slabs leaning on its walls and rubble (the skin's solid
material, in greys), three thin columns of the Dead Zone's smoke (`dead_smoke.gdshader`) kept off the camera's line
to the cyborgs, and a faint cold light. The street stays built back down to the haze behind the cyborgs
(`_stage_near`). Its sounds are its own, where the game's didn't fit (`tools/asset_gen/sfx_bank_cinematics.gd`, none
of them a hazard's warning): `crater_smoulder`, `rubble_shift`, `edge_grab`, `cyborg_host_turn` and `cyborg_host_glitch`; the
zone's track fades in under them. It sets up in about 19 ms (about 240 ms the first time, with cold mesh caches) and
costs at most about 2 ms a step (headless, `test_dead_zone_intro`); the crater adds 5 draw calls. It added to the
toolkit the poses that play out over time (`CinePoses`, a cyborg's `lie` and `crouch`), `look_up` and a cyborg's head
turn, models on the cinematic's clock, and sound events at their own level.

**The Beach's outro** (`BeachOutro`, task F2e; the owner's beats, October 15, 2026; what they leave open is DESIGN-TBD,
`docs/questions/f2e.md`; numbers in `data/cinematics/beach_outro_tuning.tres`): 39.6 s after Mecha Guppy and Captain
Cogs, on one stage in the fight's look (`after_fight`: the arena's open shore on both sides, under Sunset Strip's sky),
on the level's lanes, the pool a gap in the start lane (the Beach's gaps are pools). The fight's music fades out as it
opens; no music of its own. Out at sea Mecha Guppy (`MechaGuppySharkModel`'s meshes, smaller than in the fight) leaps
out in one long arc heading away (the fight's plumes, `MechaGuppySplash`, where it breaks the sea and where it dives),
then swims off, its back and fin cutting the water, and sinks. The camera turns (a pan whose looks are kept a few
metres off, so it turns evenly) to the runner watching it from the promenade, the screech friend sitting at their feet;
they turn and walk (`CinePoses.walk`) to a tiki bar at the street's left edge, the screech trotting beside them. Cut to
them walking up to the counter. From the bartender's own eyes (his body hidden in those shots) the screech hops up onto
the counter and sits there. The bartender, from the street: he turns most of the way round to the menu on the wall, his head
the rest, points up at it in front of him (`GanglandOutro.aim_arm`; the owner, October 15, 2026: turn to it "like a
human would"), turns back to them and asks with open hands. His view again: the runner holds up two fingers (two finger boxes on the runner's right hand
joint, the hand raised), the screech nodding along. Wider: he nods, turns his back and shakes the drinks. Cut to the
Golden Palace: the Golden Convergence's calm face close up in a dark room walled with the feed's screens, then the
camera swings to three-quarters as it raises its arm and points straight ahead, its index finger out. Cut to its refill
ships flying in a V at the camera and over it. Back at the bar, the two drinks are on the counter; the first bombs land
out on the beach; the two look up (low behind them, the ships passing over and the bombs falling), leave the drinks and
run, the camera ahead of them looking back as the blasts go off to one side, then the other; behind them, the pool
ahead: the runner (and the screech) leap in as the last bomb goes off on it, the fire fills the picture (a fade to its
colour, slower and darker with Reduced flashing) and then black; the Dead Zone's intro opens on them lying in a crater.

Its props are its own, moved by the clock (`_on_advance`), so stepping or skipping shows the same: `BeachOutroBar` (the
Beach's own tiki bar kiosk, `BeachSkin.doodad`'s large one, built bigger and scaled to the characters; one more mesh of
its dressing in the skin's materials: a wordless chalk menu board, a violet neon cocktail glass, two bamboo stools, two
paper lanterns; the two drinks; the bartender, `VolleyballRivalSuit` on the humanoid rig, posed by script, with a
shaker in his hand), `BeachOutroScreech` (a `CarPassenger`: the Gangland outro's passenger body sitting, plus the
screeches' running body for the trot, the hop and the run, in Gangland's look), `BeachOutroPalace` (a closed room of
dark panels with three walls of the Grand Court's feed screens, `golden_court_feed.gdshader`, and the Golden Convergence
from `GoldenConvergenceModel`'s meshes at 0.3 scale, its cape gathered in, a finger added to its fist,
`pointing_finger`), and `BeachOutroRaid` (three `GoldenConvergenceShipModel` refill ships with their racks, the bombs
their rack missiles, and a `FireballPool` of its own with a slot a bomb). The palace hangs 300 m over the bar; for its
shot the stage hides, the environment's fog goes off and the scenery's light goes down (`ZoneSkin.set_scenery_light`,
the room's 0.25), all put back as the shot ends and when it finishes or is skipped. The street stays built back for the
shots looking back along it (`_stage_near`). Its sounds are the game's (`guppy_leap`, `guppy_swim`, `screech_chirp`,
`gc_chime`, `gc_ship`, `bomb_whistle`, `bomb_blast`, `splash`) and two of its own
(`tools/asset_gen/sfx_bank_beach_outro.gd`: `bar_shaker`, `bar_glass`). Cost (headless, `test_beach_outro`): about
30-60 ms to set up (about 600 ms the first time, with cold mesh caches), about 0.45 ms a step and at most about 5 ms;
its props add about 33 draw calls. It adds no asset files beyond its two sounds, and nothing to the toolkit.
