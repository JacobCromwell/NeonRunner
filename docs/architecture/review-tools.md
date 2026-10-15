# Architecture: Review tools: smoke runs, showcases, measuring

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Review tools

`tools/godot.sh smoke --level=<zone>/<n>` (or `--boss=<id>`) runs the real main scene through
`tools/smoke/smoke_play.gd` (a SceneTree script), not the plain game: a campaign run waits at its level
introduction until PLAY is pressed (`App.begin_run`), and the script presses it after two frames, as
`tools/measure/frame_times.gd` does, then lets the level play for 2400 frames. It prints only problems
(a run that never started, never left the introduction, or whose runner never moved; plus Godot's own
script errors) and exits 1 on any. `--smoke-report` also prints what the run did, `--smoke-frames=N` shortens
it, `--smoke-hold` withholds PLAY (the check's own test, `test_smoke_play`). Quick play (`smoke` with no
arguments) is unchanged; `--level=beach/1` is the Beach's campaign step like any other (task D10c). The script cannot name `LevelRun` (compiling it before the autoloads exist fails),
so it finds the run's `State.READY` through the script's constant map.

Scenes in `tools/showcase/` show one part of the game up close for visual review (not part of the
game): the avatar (`avatar_showcase`: every pose, power-up and concept-sheet view, front, back and
side; `avatar_run_review`: a scripted run through the game camera on any zone's skin, with any
power-up look), ramps and walls (`ramp_wall_review`: a ramp launch with the credits along its wall
run, and blocked wall entries at a low and a high sign, through the game camera or a close one),
zone doodads (`doodad_review`: the runner pushed by a small, a medium and a large one, both ways, and a
switch into one's side blocked, with others standing in the other inner lanes at five lanes or more, in
any zone's look, through the game camera or a close one, `--hitboxes` for their bodies; `--dash` smashes
them instead, task H5: a small and a medium one head-on, a large one from the side, then a dash that ends
short of a fourth and pushes, `--reduced-flashing`), dash walls (`dash_wall_review`, task H7a: three walls in
any zone's look at its speed, `--take=smash` (the dash), `crash` (the armor, then the shield, then a kill),
`pass` (on the side wall) or `look` (a still in front of one, for task H7b's looks), `--hitboxes`,
`--reduced-flashing`, `--god`), floor cuts
(`floor_cut_review`: the stand-in's warning, charge and the gap it leaves beside a runner who switched
out, in any zone's look at any lane count and speed, through the game camera or a high one; `--stay`
for an armor block and the floor's hold, `--kill=D` for a cut stopped where its cause dies,
`--reduced-flashing`; `--compare` for a cut and an ordinary gap of the same stretch either side of the
runner, the cut open from the start with no cause, to see that the cut shows what the zone's gap does
(task H3), `--outer` for the outermost lanes, `--top` for a camera looking straight down), wall fences (`wall_fence_review`: full-height ones held off, in their warning and on,
then low and high ones on both walls, in any zone's look at any lane count, through the game camera with a
runner beside them or along the wall (`--wall`), or a fixed one beside the track (`--camera=side --at=D`);
`--cycle` lets them pulse on the level clock, `--reduced-flashing`),
the enemies (`enemy_showcase` for the cyborg family: poses, the faces close up, a turnaround, window
cyborgs, and a far view through the run camera where the expressions must read, in any zone's look
(`--variant=`, or ui_left / ui_right live), and every look side by side (`lineup`, front, back, as
hosts or aiming, and `lineup_far` at gameplay distance); `octodog_screech`,
`drone_truck_showcase`, `bad_dream_showcase` (`--weapon=N`: the host shot down ahead, its Bad Dream lurking
until the runner comes, task H8), `resonator_showcase`: its model through its warning
and pulse, or a scripted run where it pulses at a runner who jumps its waves; `barnacle_turret_showcase`:
both looks at rest and charging, and a scripted run under a ceiling with turrets or riding it past one,
through the run camera or a close one, on any zone's skin; `buzz_overdrive_showcase`: its model turning
and revving, or a scripted run through one encounter on any zone's skin, lane count and speed, through
the run camera, a high one or a low one beside its lane, with `--stay`, `--kill=D` and
`--reduced-flashing` as for the floor cuts, and `--pass`: another type's big attack still on as its rev
would start, so it speeds off ahead instead, task FIX2); `gilded_sentinel_showcase`: a Golden street with Sentinels in
their niches and a runner taking a route past each (`--route=lane|floor|high|low`, `--kick`), through the
run camera or a camera across the street, straight at a niche or along its wall (`--view=play|close|front|
wall`), with `--double`, `--pair`, `--skin=golden_palace`, `--speed=N`, `--reduced`), `enforcer_truck_showcase`: the Enforcer Truck arriving, picking up a rider and firing
a volley the runner dodges, showing itself beside the runner (twice, a lane change into it bumped back the
second time, `--bump=N`), closing up for an Octodog whose late-dodged lunge flattens it (`--early`: dodged
at once, it follows out unharmed), a Buzz Overdrive's charge left late or its cut (the tank shot down), a
too-wide gap (each ending in its blast), or its model on a plinth
(`--scenario=chase|show|octodog|buzz|cut|gap|model`; showings only in `show` unless `--shows`), on any zone's
skin, lane count, speed and rider count, through the game camera or one behind or beside it
(`--camera=game|behind|side`, `--reduced-flashing`), the Golden Zone's statue
kit (`statue_showcase`: every pose, a turnaround, and a statue rigged in the kit's niche and swinging), the bosses (`floating_head_showcase`, `sleep_taker_showcase`, `the_house_showcase`, `sewer_swarm_showcase`),
the swarm's rendering stress test for the phone test (`swarm_stress`: N clusters of C screeches with a frame-time
and draw-call readout, sliders, `--seconds=S` for a summary line), the UI kit, the screens (`screens_showcase`;
its `--screen=hud_armor [--tier=N]` takes the HUD's armor through its states: up, broken, its ring
filling, back; `--screen=hud_last_hit [--reduced-flashing] [--hold]` the "one hit from death" cue (the armor
breaks with a shield still held: nothing; the shield breaks: the red edges pulse and settle; the armor returns:
they fade; `--hold` stops with the edge steady, for a `--shot` at a phone's window size); `--phone --flavor=web_demo` with the engine's `--resolution 844x340` shows a screen as a
phone's browser does, the menus magnified, and `--shot=<png>` saves it), a zone skin
(`skin_review`: any skin from fixed spots, including close-ups of the cult's feed screens and emblems a
skin lists, or a scripted run with a ceiling ride and a wall run, in a level's darker lighting with
`--darkness=X` and under a level's own sky with `--sky=name`; `--narrow` makes three of its ceilings narrow, one lane in the middle, the two leftmost
lanes and the rightmost lane, with shots riding each, of its far end from below and from beside it, and
a run that tries moves past their edges; `--open` opens the side walls over four stretches, with shots
of each from the game camera, from beside the opening and from above (a skin's `wall_gap` hook, the Beach's
open beach); `--from=D` starts the run further on, `--reduced-flashing`
turns Reduced flashing on), the Beach's splash (`splash_review`: a real `RunWorld` with a skin, a pool in the
runner's lane and the game camera, for a real fall; `--skin`, `--sky`, `--lanes`, `--grapple`, `--side`), a cinematic (`cinematic_review`: any campaign slot's cinematic on its own, as
the App plays it, or the toolkit's sampler; `--from=S` starts S seconds in), and comparison
sheets for an open design choice (`cult_emblem_sheet`, D7). Each script's header lists its options. Render
frames on the Compatibility renderer (the web and low-end Android path) with `--write-movie`, as in
`CLAUDE.md`.

`tools/measure/big_attacks.gd` measures the big attacks (GDD §9, "Big attacks take turns") over
simulated runs of the campaign's levels at 3, 5 and 6 lanes, with `GameRules.big_attacks_take_turns` on
and off: a god-mode runner in the middle lane, stomping every host it passes, while the enemies play as
in the game. It reports the time big attacks of different types overlap, how many of each kind came,
how long attacks waited for their turn (from the first frame the director holds an enemy for another
type's turn until its attack, through gaps of up to 3 s, and an Octodog's until it charges, however
long it moves its charges on; the director answers each ask the same whatever its queue keeps, so two
builds measure the same asks alike), the enemies that never got a big attack in (Octodogs
without a charge, Resonators without a pulse, drones without a barrage, hover trucks without a lurch
or a cannon shot), and what each Buzz Overdrive did once it set off (`AttackWatch.buzz_tanks`: revved,
revved into another type's open attack, let the runner pass, or was shot down first; task FIX2), and each Enforcer Truck that arrived (`AttackWatch.enforcers`: its
volleys, riders and what destroyed it; its volleys count as `enforcer_volley` attacks; task C6)
(`godot --headless --fixed-fps 60 -s res://tools/measure/big_attacks.gd --
--levels=gangland/3 --lanes=3,5,6 --out=build/measure/x.json`; the whole campaign on its own seeds takes
about ten minutes; `--seeds=6` adds six other seeds a level, `--seeds=9007-9020` runs a range, and
`--features=octodog` keeps the levels that use a feature). `attack_watch.gd` watches the attacks from the
enemies' own states and the live shots, never from the turn-taking code (only the waits come from the
director's answers), and hashes each run's event log, so two builds (or the switch off and a build
without the rule) can be compared run by run.

`tools/measure/host_releases.gd` measures when the Cyborg's Bad Dreams are released in the campaign's host
levels (Dead Zone 1–2, Golden 1–3) with each weapon tier (task H8: weapons hit hosts, GDD §9.7) against where
the host rules planned their chases, with the same simulated runner (god mode, the middle lane, the weapon at
the tier given, stomping every host the weapon leaves). `host_watch.gd` follows each host and its Bad Dream
from their own states (where the host died and how, where the chase began and ended: while the Bad Dream
reports its big attack) and holds each chase to the generator's guarantees (`HostWatch.check`): how far before
its planned stretch it began, the longest run without an anti-grav pad from its start and from its first
claws, what the generator keeps off chases met outside the planned stretch (`kept_off_chases`: zone doodads, a
floor cut's attack, a wall fence's drop window, an Octodog's charges, a Gilded Sentinel's attack, a cyborg
planted in a charge's path), and chases that fizzled or overlap; AttackWatch adds a slash with an Octodog's
charge or a drone's barrage open (`godot --headless --fixed-fps 60 -s res://tools/measure/host_releases.gd --
[--levels=dead_zone/1] [--lanes=3,5,6] [--tiers=0,1,2,3,4] [--old-rule] [--out=build/measure/x.json]`; about ten
minutes for every host level at 3, 5 and 6 lanes and the five loadouts; `--old-rule` makes hosts immune again).
Measured on the levels' own seeds (October 8, 2026): tier 1's 42 m never killed a host before the runner
reached it; tier 2 killed every host 0.7–1.5 s of run before its spot (median 1.48 s, about 37 m), tier 3 all
but one 0.6–1.1 s before (median 1.06 s), tier 4 every one 0.9–1.3 s before (median 1.23 s). Released there, a
chase began up to 37 m before its planned stretch, in 12 of the 45 runs with
tiers 2–4 inside a wall fence's drop window, with up to 10.17 s without a pad (the guarantee is 10 s). With
the lurk (Enemies: a Bad Dream shot down ahead lurks until the runner is within `hover_ahead`), every chase
begins at most 14.3 m before its planned stretch (a stomped host's: 9.3 m, as hosts walk toward the runner),
with the same pads as a stomp's (10.00 s at most), nothing kept off chases met, none fizzled or overlapping,
and no slash during an Octodog's charge or a drone's barrage. The Octodogs that never charged with tiers 2–4
(1, 1 and 2 of 6) never charge with `--old-rule` either: the weapon shoots them first.

`tools/measure/truck_cost.gd` measures what a hover truck costs a run (task I5; A run, The hover truck's cost on a
phone): it plays a quick-play run with the truck's feature through the App, spawns trucks at set times (`--trucks`,
`--stay`, `--kill`) and reports, per phase of the visit (away, hidden, banging, the burst, pacing, the lurches, the
rev, the wreck), the frames' median, 95th percentile and worst time, the game's part of them, and the median draw
calls, primitives, objects, nodes, real lights in the tree and the pipelines built, then the slowest frames with
their phase and tags. Under xvfb with `--rendering-method gl_compatibility` and `MESA_SHADER_CACHE_DISABLE=true` (so
the driver's disk cache doesn't hide compiles) a frame that built shaders stands out by hundreds of milliseconds,
which is how the light was found; the times are software's (on a loaded machine a spike that doesn't come back at the
same frame in a second run is noise), the counts are any renderer's. `--bench` times a truck's spawn and its
per-frame script work, `--probe-lights` alternates the run's lights shown and hidden, `--trace` prints the tick of
each phase (to find frames in a `--write-movie` capture), `--pre-burst` fires two spark bursts first, `--no-light`
frees any light a truck has (for an older build). It runs on an older build too: copy it into an archive of that
build.

`tools/measure/frame_times.gd` measures frame times (task PERF1; A run, Smooth frames): it plays campaign
levels and boss fights (built ones, and ones still being built through their preview scene) through the App
as the game does, without App.boot (a stand-in for the main scene), with a scripted runner (god mode, no
falls, the zone's speed; the level's seed picks a lane switch, a jump or a slide every 0.5 to 1.25 s; a boss's
test bot where there is one), and times every frame with a `FrameMonitor`. Each pass runs in a fresh Godot
process (`--child`), so it pays what a session starting there pays, and each frame keeps its fastest time over
the passes (`--passes=N`, 2), since another process taking the CPU shows in one pass only; `--session` plays
everything in one process instead. Per run: the median, 95th and 99th percentile and worst frame, frames over
8 and 16 ms, the load, kills and hit-stops (begun, frames held, the longest hold, holds that ran into the
next), and the causes of the frames over 4 ms by time over the median; `--log` hashes an event log (AttackWatch's,
every kill, the runner's place each second), `--shaders` lists the shaders first drawn after the load (always on
under xvfb, where it also counts draw calls, primitives, objects and compiled pipelines by source), and
`--reference` times SkinSuite's reference build alongside (`test_frame_times`). The headless run is the CPU
only (the dummy renderer); xvfb's software renderers give valid counts, not times
(`godot --headless --fixed-fps 60 -s res://tools/measure/frame_times.gd -- [--levels=city/1] [--bosses=]
[--frames] [--out=build/measure/x.json]`; the whole campaign and its bosses take about fifteen minutes). It
runs on older builds too (it reads them by property names): copy it and `scripts/run/frame_monitor.gd` into
a `git archive` of the build.

`tools/measure/zone_shaders.gd` counts the shaders a level draws (task I1; A run, Smooth frames): headless, a few
seconds a level, for each zone's first level and the Golden Palace (`--levels=` for others, `--bosses` for every
built boss's arena: the boss set up as the framework's tests do and a second of the fight played). It builds the
level's world as a run does (full loadout, `--lanes=`), walks its whole track with the chunks dressed, spawns one of
each enemy kind its layout brings, builds the shader warm-up's stage, and prints the distinct Shader objects (and how
many codes come in more than one), the distinct standard-material looks (`ShaderWarmup.shader_key`), the keys only
the warm-up or only the level's own nodes draw, and with `--detail` each shader or look with the node that draws it
and the standard materials in words (opaque, unshaded, two-sided, vertex-colour, ...). Shaders plus looks, times
about 5.4, is what `tools/web/shader_programs.js` counts on the web export (City 1: 24 and 130; the looks can only
come out low, since `ShaderWarmup.shader_key` leaves out some settings that change a standard material's shader);
the web tool is the ground truth (it also counts each program's draws and its wait on the compiler), this one finds which shader
a program is. `--out=build/measure/x.json` keeps the numbers.

`tools/measure/level_builds.gd` measures how long a run takes to build its level (task PERF2; A run, Retries
reuse the built level): each campaign level's first build (the generator's, after one untimed build in the
process; the fastest of `--repeat=N`, with the builds its every-feature guarantee made) at each lane count,
each campaign boss arena's plan (`--bosses`), where one build's time goes pass by pass and each enemy type's
rules apart (`--passes=corporate/2:5`: `generate()`'s first build replayed in `LevelGenerator._build`'s order and
checked against the generator's own; it says so when the replay no longer matches), and the time from pressing
retry to the run starting, both ways (`--retry=corporate/2,dead_zone/1 --retry-lanes=5`: `App.retry` and
`LevelRun.restart` on the real main scene, and whether `LevelCache` reused the build). It runs on builds from
before the cache too, for the times before (`godot --headless -s res://tools/measure/level_builds.gd -- [--levels=]
[--lane-counts=3,5,6] [--repeat=N] [--no-table] [--bosses] [--passes=] [--retry=] [--retries=N]`; the whole table
takes about half a minute a repeat).

`tools/measure/stomp_routes.gd` measures how forgiving the Floating Head's ways onto its head are, in its
fight on a plain street at the City boss step's speed (21 m/s; `--speed=N` for another, 18 for the
reference speed): the ramp's boarding window (the latest lane switch from beside it that still
stomps, from each side), the stretch of jump points a single wall jump stomps from (swept about the jump
mark at the run's pace; `--fine` finds each end of it by bisection), getting onto the wall at the marks'
start or just before the release line, and the ceiling from a pad in each lane, in metres and in seconds
of running (what stays the same at every speed)
(`godot --headless --fixed-fps 60 -s res://tools/measure/stomp_routes.gd -- --lanes=3,5,6
--routes=ramp,wall,ceiling`; `--e1c` measures E1c's numbers, `--second-move` adds the in-air move; the
default run takes a few minutes).

`tools/measure/enforcer_shows.gd` counts the Enforcer Truck's showings chase by chase (tasks C6b to C6e) over
simulated runs of the campaign's levels with the truck, a god-mode runner keeping to each lane in turn (AttackWatch's,
jumping the holes in its lane, baiting nothing): each truck's arrival, its showings (`+` for the arrival showing),
its planned window, whether that comes before its chase's first bait (`gen.show_window_result`) and whether a showing
began in it, and for a chase without one why not (`show_problem()`'s shares, or what destroyed it before its window
was due); the totals by lane count, of the chases (each once: with a window before their bait, after it, none) and
of the runs (`godot --headless --fixed-fps 60 -s res://tools/measure/enforcer_shows.gd -- [--levels=corporate/2]
[--lanes=3,5,6] [--runner=all|middle|N] [--seeds=N] [--out=build/measure/x.json]`; all six levels at 3, 5 and 6
lanes, every lane, take about three minutes on their own seeds).

`tools/measure/level_shape.gd` measures the campaign's shape: for each level at 3, 5 and 6 lanes, on its
own seed and others, each feature's share of the pattern picks, the enemy, host and obstacle counts, the
features that appear only thanks to the every-feature guarantee, and for a level paced in bursts (The
Hush) its quiet stretches against its bursts, with the recency curve on and off and a level's remix
settings on or off (`godot --headless -s res://tools/measure/level_shape.gd -- --levels=dead_zone/2
--curve=on,off`; the whole campaign both ways takes about a minute and a half).

`tools/measure/level_pace.gd` measures each campaign level's pace and density (G1; GDD §3): its run
speed and length, and per minute its obstacle rows (and rows of holes), enemies, big attacks (Octodog
charges and Resonator pulses as planned, drone waves, hover trucks), mechanics, zone doodads (G5) and the
pushes a runner who keeps to a lane and ignores them takes (averaged over the lanes, and in the middle
one), and all events, doodads among them; its
empty stretches in seconds (the longest and the mean; what counts as going on is in its header); and
its credits. `--old-data=DIR` builds the levels with another version's data (the .tres files of
`data/tuning`, `enemies`, `levels`, `zones`, `campaign` and the patterns, e.g. main's exported with
`git archive`), `--dump=FILE` writes every layout as JSON, so the new code with the old data can be
compared byte for byte with the old build's dump, and `--set=key:value` tries level values before they go
in the files (`godot --headless -s res://tools/measure/level_pace.gd -- --seeds=4`; about half a minute).
