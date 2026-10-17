# Architecture: Tests: enemy, generator and level suites

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Tests (continued)

`test_resonator` plays the
Resonator in full worlds on real physics (the warning always before the wave, a jump clearing it at 3,
5 and 6 lanes with its margin measured, walls and the ceiling safe, armor, shield and dash, turns with a
`TurnDummy`, a first pulse that waiting for clear floor never starves (FIX4), Reduced flashing), checks
its rules over many seeds, and plays the real Golden 1-3 layouts
at 3, 5 and 6 lanes, watched by `attack_watch.gd`: no wave meets the runner on a gap or a fence, and no
big attacks overlap. `test_barnacle_turret` covers the Barnacle Turret (C1): its numbers against the
cyborg's and GDD §8's 7 laser tier 1 shots, hitboxes out of reach of anyone off its ceiling, both looks
(no hazard glow but the charging muzzle), placement over every campaign level and narrow-ceiling sweeps
(`LayoutChecks.check_turrets`, which `check_rules` runs on every generated level), a level unchanged
without it, and on real physics: popping out, firing only at a rider on its own ceiling after its
charge-up, dodging, two-lane ceilings at 3, 5 and 6 lanes with one turret and two, contact (armor, shield,
claws, dash, a stomp from the ceiling), 7 laser tier 1 shots, armor and the shield against its bolts,
determinism, and generated levels ridden through with every burst checked. `test_gilded_sentinel` plays
the Gilded Sentinels (C4) in full worlds on real physics at 18 and 25 m/s: the warning always first, for
its whole time; wall runners stepping on right before it (cut), jumping on (above) and stepping on early
(below) on both walls; floor runners in and out of the outer lane at 3, 5 and 6 lanes, jumping and
sliding; armor, the shield and the dash; its solid body back in its niche; 17 laser tier 1 shots through
the real weapon; the kick; twice and pairs; turns with a `TurnDummy` (its claim holds another back, and it
lets the runner pass when one begun before is on); Reduced flashing; the same every attempt. It also checks its look (one shared mesh, the eyes' own
material, the statue inside its niche with its front almost flush with the face and the solid body as deep as
it (H1), its gold never glowing, the lit niche's colours against the gold, the flare tinting rather than
adding red: its hue worked out), every statue niche lit and no see-through slot beside a live niche at a
chunk's end, the reaction checks (a floor runner's lane change and a wall runner's two moves at 0.35 s), the
grind as long as the warning, the Golden skins opening the niche and leaving out a decorative alcove that
would overlap it,
decorative statues on
recessed wall-base mounts, the statues as a relief on the wall face (K2: the live statue and every decorative
one in both Golden skins have the live relief, nothing of any stands in front of the face, each is within the
skin's inset of it in a shallow niche that holds it, and from the 20 m view of a 5-lane street 65% or more of
its width shows through its opening, the live one's steps out to its swing relief and back with its hitboxes
unchanged), its attack window covering its floor, its placement rules on hand-built layouts at 3, 5 and 6 lanes, the wall fences keeping off
it, and Golden 2 and the Palace's real layouts (its rules, `LayoutChecks.check_layout`, the introduction,
the same build twice). `test_ceilings` covers narrow
ceilings (B3) from the layout to the screen: the
sections and collision boxes the track builds for each range at 3, 5 and 6 lanes, moves on a ceiling
(within it, and blocked at its edges with the bump and the clank's event, on real physics), a pad
holding the player to its lane, a one-lane ceiling ridden and dropped from, the camera kept under a
ceiling and past its end, and every skin's ceilings (see Zone skins). `test_climb` (task E5e-a) covers the
climb's core for GDD §10's Beach boss at 3, 5 and 6 lanes: ceilings at their own heights (from the street,
and from a roof 9 m up to a ceiling at 15 m), a ceiling moving while ridden, a ceiling ending lane by lane
holding a switch within the lanes it still covers, the drop onto a raised roof in a lane it covers and past
it (onto the street, or to a death where the street is eaten) in one it doesn't, falls counted from the
floor base (as soon and as deep as from the street, in the pit as deep; a floor base above the runner never
dropping them), fast falls landing where they cross a floor (onto the street and back onto a ceiling), the
shadow on the roof only while the climb is on, the grapple's save and a revive after a fall
going where the hook says (and the framework's hook leaving them as they were), the climbing camera up a
five-step climb to 30 m, and boss props at a height. `test_mecha_guppy` (task E5e-b1) checks the Beach boss's data
(the slot's scene, title, phases, weapons doing nothing, the armor rule, the look without walls, the campaign under
Sunset Strip's sky, its rewards and par times, its hints), the climb's plan over 60 steps at 3, 5 and 6 lanes and both speeds (the lanes that
lead up and their counts, the cues alternating and shaped as the owner put them, the reading margin from the latest
settle in every lane, the hut full width until the deadline, a wrong drop dead before the next front even dashing,
an unjumpable pad strip, the reaching lanes past the latest settle, never the same lanes three times running for a
cue, phase 2 15-25% faster with every margin kept (task E5e-b3: its higher rise, steps as long), the notches'
promises (E5e-b3: an outer lane on a seeded side whatever leads up, eaten far enough past the landing for the
bait), no escalation, a retry the same), every tunable at both ends of its F6 range keeping those promises, the built climb against its plan on real physics (roof tops, hut ends, pads,
fronts and blocked sides, the lanes that lead up read off the collision, the edge of sight at the fog's end), the
roof faces' rules, the hits and phases (phase 3's 16 hits counted once the runner is on the top), and the armor
pickups on the roof ahead. `test_mecha_guppy_climb` plays it on physics without god mode with `MechaGuppyBot`:
through phases 1 and 2 (the bot baiting each step's hit, task E5e-b3) into phase 3's top at 3, 5 and 6 lanes and 18
and 23.8 m/s, phase 2's rate and its census of bombs to deal with measured, never a circle in the runner's lane with
no floor to switch to; the worst case (the farthest lane, the latest flip, also dashing, reading `read_seconds`
late, and with `reach_back` at 30 m) making every step with time to spare; wrong drops at both cues from the
farthest wrong lane, dashing, dying by a fall before the higher roof's front (and saved by the grapple or a revive
onto the higher roof, in its nearest lane that leads up, the rope from the lifted runner); phase changes (nothing in
sight changes, the next step is the new phase's, nothing ever planned in sight, `top_reached` starting phase 3's
attacks and the waterfall's fade); the same rhythm through a long phase 1 and on a retry, with the builder's work a
frame staying small; and the climbing camera (the runner on screen, never inside a roof, under 0.40 m a frame, the
shadow on the roof, over phase 1's steps and phase 2's higher ones); it prints its figures. `test_mecha_guppy_bombs`,
`test_mecha_guppy_bites`, `test_mecha_guppy_bait` and `test_mecha_guppy_tunables` (tasks E5e-b2 and E5e-b3) check
Captain Cogs' bombs, Mecha Guppy's bites and catches, the bait with both bots' phase times, and the bait's and the
fallback's promises at both ends of every tunable's range; `test_mecha_guppy_top` and `test_mecha_guppy_whole` (task
E5e-c) phase 3 and the defeat, and the whole fight with its par times and the campaign's flow (see Mecha Guppy and
Captain Cogs). `test_audio` checks
the music files (seamless loops, lengths, tempos, size budgets), the Music autoload's fades, duck and
death dip on its players' levels and the bus's low-pass (headless runs never start a player), and the
run's music hooks through the App. `test_cinematics` checks the cinematic toolkit: its paths (smooth,
eased and cut moves, cameras riding with an actor), a timeline's `problems()`, a cinematic played to its end
(events in order, `finished` once, actors on their paths, the camera riding along), `skip()` and the pause
action and the Skip button, Reduced flashing, holding in the background, the sampler (a cinematic described
in data), the poses that play out over time (the runner lying, getting up and climbing with its hands holding the
keys' position; cyborgs lying still and crouching, turning their heads by `look` and `look_up`), sound events at
their own level, every zone's arrival flyover (but the City's and the Dead Zone's intros) and the City's boss intro at 3, 5 and 6 lanes (the zone's skin from
its data, the level's lanes, a camera that never flies into a ceiling or out of the street, a runner that
never runs over a hole, ending in the run camera's view), and the App's flow through a built slot (the
next step follows, skipping, the web demo). `test_city_intro` checks the City's intro (F2h): its slot (the City's boss intro
keeps the flyover); at 3, 5 and 6 lanes its beats in order on a real street (every lane a gap, the road lifted to y = 0), the
camera's one continuous move down to the street with only two cuts, staying in the street above the road and out of the traffic's
lanes, the light on the wall at the feed billboard just before its screen bursts and past it as it does, the billboard's
picture tearing before the burst and its eyes following the light, the billboard (the Head's face shader, standing out of the wall
the right way round, a floor up) and its burst (the screen gone, glass and sparks flying out, the flare; with Reduced flashing a
share of the sparks and a slow faint glow; everything settled within 1.6 s), the runner landing on the first
cyborg's head and clearing the second and the fifth and never inside one, the stomped cyborg's ERR and flattening, the light on
the runner when the Head has them, the Head startled, angry and yelling by its face's state, its light cold white throughout;
the feed's surge (every screen changes at once, flickering normally, once with Reduced flashing, ending angry; the turn and the
chase); the traffic (two outer lanes, no overlaps, the stretch kept clear) and the people (on the sidewalks, walking); no hazard
hue on anything safe; the low-end counts; stepping the clock coarsely shows the same moment; `skip()`; costs and draw calls; and
the spot staying on the road through the whip, the chase no faster than the cyborg walk's authored pace, the shader warm-up
(`CityIntroWarmup`: it samples the glass, the sparks and the runner; the shards share the effects' glow and the sparks one Shader),
the two title cards (the game's title for 1.5-2 s, gone before the zone's card, which ends with the cinematic) and the App's flow (it
opens a new campaign, the web demo plays it). `test_city_outro` checks the City outro (F2a): at 3, 5 and 6
lanes its beats in order (the crash into the wreck, the camera at the runner's level, the look left, the pan
onto the roadblock, the startle, the leap out of the right wall's opening with the blast behind, the cut to
the next zone and the landing), a camera that only leaves the street through an opening, only the City's
music, its setup, cut and step costs and its props' draw calls; Reduced flashing; `skip()` at any moment;
the landing following the next zone's skin; and the App's flow (Gangland's intro follows; the web demo plays
it, then its end screen). `test_sewer_swarm_intro` checks Gangland's boss intro (F2b): its slot (after
Gangland 3, before the fight, the fight starting when it's skipped); at 3, 5 and 6 lanes the fight's look, lanes and
speed, the camera at ground level and in the street, cutting once, the owner's beats on time (two on one side
and one on the other, five left and six right, each manhole rattling first), the runner never touching a
screech, more and more pouring out and dropping from out of view, never in the runner's lane, the wall rising
and closing in, the heart and its glint only in the cut, and ending on black with the fight's music; Reduced
flashing; `skip()`; and its setup and step costs. `test_dead_zone_intro` checks the Dead Zone's intro (F2c): its slot
(before Dead Zone 1, which starts when it's skipped); at 3, 5 and 6 lanes the zone's look and lanes, the crater a
gap in the runner's lane with a floor, smoke and only greys in it, the runner lying in it, shaking their head,
getting up and reaching for the far wall, two cuts (to ground level beyond the far edge, then to the host's face),
at first only the hands over the edge, the hands holding the edge as they climb out, the runner up on the street,
the three cyborgs in view until the medium shot (two lying still with their screens dark, the host crouched), the host
looking over only as the runner gets up, the close-up of its grinning, glitching screen facing the camera, the
zone's music, the medium shot as the host turns, the whole face filling the close-up, the title card held on the black,
its own sounds; `skip()`; and its setup and step costs. `test_gangland_intro` checks Gangland's intro (F2g): its slot
(after the City outro, before Gangland 1, which starts when it's skipped); its own sounds in the library; at 3, 5 and 6
lanes the zone's look and lanes, the fork (both walls open at the junction onto side streets, a building ahead), the
cast's looks (the zone's, the Marketplace's and the Casino's, from the zones' data), the large Octodog and the truck
behind the right gang, the leader forward in the middle, three cuts, the first and last shots at human height, the
runner looking left, the ground-level tilt, the pan right, each gang and then both in view, the leader's charged shot
missing the left gang, their angry faces, the Octodog's wind-up before its charge, two cyborgs downed and the leader
not, the firefight's bolts bursting only on a cyborg, the street or a wall, the runner out of the picture while the gangs
are on screen, the slow turn to the right, the left hand in front of the face throughout, the walk off toward the
right-hand street, the zone's title card as they walk away, the zone's music, the warnings each before their attacks,
and its costs; Reduced flashing (smaller bursts,
nothing flashing); `skip()`. `test_gangland_outro` checks Gangland's outro (F2d): its slot;
`after_fight` (the fight's look and sky after it, the zone's own without it, so the City outro's look is unchanged);
the car's shape (a long, low wedge, a scissor door, lights and turning wheels, its cabin lit only while its
courtesy lights are on); the passenger (the fight's screech, every triangle and colour of it, sitting up); at 3, 5 and 6 lanes its beats in
order (the screeches sniffing, then gone before the runner arrives, never near the camera; a walk, not a run; the
Host trembling harder as they hold the key up; the hands meeting; the key in one hand, then the other; the glint;
the cut to the car, the runner facing the way they walk at once; the unlock's blinks; the door up as the runner gets
in; the screech on the passenger seat, and one shot from inside the car with it and the runner sitting down beside
it in view; its look round, then, once the runner's sat, the two nodding to each other before the car takes off; the
door down; the lights on; the runner out of sight once the camera's outside; the camera at road level as it drives straight off, fast, into the distance), the walk (`CinePoses.walk`,
its planted feet moving under 10% of the ground walked, its turns unhurried), the camera in the street and
above it, the street built 150 m wherever it looks, only the fight's music fading, its costs and draw calls; Reduced
flashing (one slow glow for the unlock); `skip()`; and the App's flow (the Marketplace's intro follows).
`test_pace` checks the pace and busier levels (G1): the zones' speeds in data and each campaign level at
its zone's speed (and each boss fight, E1f; quick play's at the base), `movement_for`, a pattern's timing in seconds at 18 and 25
m/s, the generator's fairness at 21, 23.4 and 25 m/s at 3, 5 and 6 lanes with every built feature and
the fill pass (`LayoutChecks` checks each level at its own speed: `level_tuning()`), the fill pass's
rules on campaign levels, the Octodog's and Resonator's windows in seconds, a cyborg and a screech on
real physics at 25 m/s (the charge-up, the bolt's flight, the dodge; the shake), floor routes under a
Golden level's ceilings run on physics at 25 m/s, and F6's Save keeping the base run speed.
`test_doodads` checks zone doodads (G5; GDD §3): a level without them is the same data as before and a
share of 0 changes nothing (every piece, enemy, pick and fill stays with a share; only credits inside a
doodad go; City 1's extra gaps, which FIX4 may send elsewhere around a doodad, keep its own gaps and their
count, task G7; dash walls past an introduction, which come after the doodads, left out of the comparison,
task H7a), placement over 216 levels at 3, 5 and 6 lanes (every difficulty, with and without every
built feature, at the highest share: `check_doodads`, `check_layout` and `check_rules`, deterministic),
every campaign level's doodads and City 1's gentle start, the rules' keep-outs (a Bad Dream's chase, a
hover truck's lane) and the enemies' own checks, the track's bodies (never a hazard, a standable top,
the skin's hook) and every skin's default look (inside its box, never glowing, muted colours); then the
push on real physics at 3, 5 and 6 lanes (head-on into the lane on its side in every inner lane, both
ways, quick, with the lean, costing nothing, the body never sinking in; a jump and a slide into one; a
corner caught mid-switch pushing back the way the player came; a blocked side entry with the clank and
the bump; landing on its top; a ceiling rider passing over it even mid-jump; a shot passing through it),
a few of every campaign level's doodads run into at the level's speed and onto safe floor, and a drone
and a hover truck holding their fire while a doodad is in reach. Then the dash smashing them (task H5),
on real physics: head-on at 3, 5 and 6 lanes in every inner lane, both sides, every size (once, no push,
the lane kept, no slowdown, broken before the body touches it); a dashing switch into a doodad's side
(through, no clank; pushed first, then a dash steering back into it, smashed and never sunk into; a dash
during its push leaving it standing); a dash that ends short, swept over where it starts at 18 and 25 m/s
(always a push or a smash, a smash only when the dash lasted until the body got there, never a sink, the
same every attempt); the dash's reach with a speed pad's boost fading at F6's fastest; a full world in the
City's look (its body, lane blocker and top gone, the crunch, its pieces in
its look's colours, never glowing, a light shake Screen shake scales away, no damage, no score, other solid
sides still blocking a dash); a LevelRun of City 2 (it stays smashed through a death and a revive, and a
retry builds the same level with it whole, pushing a runner who doesn't dash); every skin's pieces'
colours; two of every campaign level's doodads dashed through at its speed at 3, 5 and 6 lanes; and the
fairness measure for a runner who dashes through (The generator, Zone doodads). `RunSim` takes a `&"dash"`
action. The simulated runs of
`test_enemy_director` and `tools/measure/big_attacks.gd` keep their runner in the middle lane: it steps
back after a doodad's push (`AttackWatch.keep_lane`).
`test_dash_walls` checks dash walls (task H7a; GDD §9.14): the layout data (no key without them, copy and
append, a wall a doodad in every lane, broken or not); the generator over every level with the feature at 3, 5
and 6 lanes on its own seed and two others (the level's count on its own seed, at least one on any, no warning,
every wall fair by `LayoutChecks.check_dash_walls`, the same every build); Corporate 1's introduction right
after its start at every lane count, alone, and no other level introducing them; past an introduction the walls
standing after the danger density pass and the doodads (its report, the fillers, the enemies and the doodads as
with no walls, only the pieces in their way taken out); The Hush's walls out of its quiet stretches; a level without
the feature or with a count of 0 built exactly as without them; the track (the box on its layer, the forgiving hitbox that
armor absorbs and that breaks it, across the floor lanes and short of the side walls, taller than any jump, the
skin's hook and colours, a broken one never built); the damage rules (the dash, armor, the shield, a kill, god
mode, the invulnerability window; a truck's body still a hit armor never blocks); on real physics at 3, 5 and 6 lanes in
every lane, a dash smashing it before the body touches it (no hit, the lane and the distance run unchanged), a
crash killing a runner with no protection at its face (the outer lanes too) and breaking it, a dash that ends
short crashing, a jump and a slide crashing, a dash in the air smashing it, a wall runner passing it on either
wall; a full world (the armor, then the shield absorbing a crash with the invulnerability window, god mode, the
wall broken each time; the crumble in the Corporate look: its pieces in its colours, lit, the dust, the heavier
shake Screen shake scales away, the crash's sound, Reduced flashing changing nothing, the warm-up drawing its
look, pieces and dust); a LevelRun of Corporate 1 (it stays broken through a death and a revive, and a retry
rebuilds it whole); every skin's look; the hint; a hover truck giving way (pacing ahead, behind the runner as
they reach the wall, no rev near it, pacing again past it) and bursting through when boxed in; and a heli drone
rising over one, back down past it, never winding up with a wall in its barrage's reach; a panic cyborg's run
stopping short of a wall's clear approach (and one past it never walking back into its clear stretch); an Octodog
running off ahead and a Buzz Overdrive speeding off after letting the runner pass, each leaving play at a standing
wall's face. `LayoutChecks.check_dash_walls` also holds every Tithe Collector's stay's end out of the spacing
before a wall and every cyborg's run and walk out of its footprint, and the hint says what a crash costs. `RunSim`
reports `crashes` and `wall_passes`, and hands its Player the layout's walls.
`test_floor_cuts` checks floor cuts (B4; GDD §9.9) with the grey-box stand-in: the plan's geometry and
the layout data; the track's piece (its slices, its collision, a hold and a stop); on real
physics at 3, 5 and 6 lanes, the floor gone exactly behind the cause and whole ahead of it, a runner in
the lane falling frame for frame as into a normal gap, one who reacts to the warning leaving in time
from middle and outer lanes, one who stays hit by the cause, a wall runner and a ceiling rider
untouched; the floor holding for `cut_hold_seconds` after an armor or shield block (staying falls once
it's over, switching lanes or jumping inside it is safe); a kill stopping the cut where it dies (mid-
charge, during the warning, by the dash); the same cut at 30 and 60 physics frames a second, through
pauses and uneven steps; a cut added during a boss fight (`arena.cut_problem`, `add_pieces`) and on a
track extended during play; every skin's look and build cost (Zone skins, Floor cuts' looks); the
stand-in's warning (a red line from the warning point, never before, and a sound; the line steady with
Reduced flashing); and that the stand-in stays out of the campaign. `test_generator` sweeps the stand-in's cuts over seeds,
difficulties and lane counts, under narrow ceilings and in busy levels with every built feature
(`LayoutChecks.check_cuts`), checks each of GDD §9.9's limits by hand and `CutPlacement`'s clearing, and
shows a level whose rules plan no cut is the same data as one without them.
`test_buzz_overdrive` checks the Buzz Overdrive (C2; GDD §9.9): its numbers (health 20 everywhere, a rev
a little shorter level by level, its warning and charge in seconds at every zone's speed), its look
(every variant within an enemy's budget, only hazard colours glowing), its plan, every campaign level
that lists it at 3, 5 and 6 lanes (each tank with its cut, the same every build, Corporate 1's
introduction soon after its start; it prints the counts) and quick play with every built feature;
then on real physics at 3, 5 and 6 lanes and every zone's speed: the warning (line and sound) before
the charge and only its own lane cut, a runner who leaves at the warning never touched, one who stays
hit, wall and ceiling riders beside it safe, a block holding the floor for about a second (staying falls,
a lane switch escapes), kills while it rolls, revs and charges (the floor saved, the cut stopped), the
shots each weapon tier needs and when it stops it (laser tier 1 never before it meets the runner, the
missile tiers before it charges), the claws doing nothing, the dash smashing it, no stomp, the same
encounter on every attempt and at 30 and 60 Hz, and its rev and charge as a big attack; its sparks only
while it cuts, none and a line that only widens with Reduced flashing. Its turns (task FIX2): its claim
before its rev (another type's attack that gets ready then waits until it's gone, and it revs), its pass
(with one begun before its claim still on: no rev, no line, its lane whole, out of view ahead), none of
it with the switch off or for a boss's tank (no roll), and Dead Zone 1's original overlap rebuilt with a
real hover truck ready to lurch 0.85 s before its rev (0.62 s for a tank that takes no turns; now the
truck waits and nothing overlaps). `test_enemy_director`'s campaign runs hold Dead Zone 1 at 5 lanes to
no overlap at all.
`test_enforcer_truck` checks the Enforcer Truck (C6; GDD §9.13) off the road: its numbers (the owner's 0.8 s,
25 s, 3 riders, 2 a level; its close gap inside an Octodog's lunge at every zone's pace; its follow gap behind
the camera; a shot's bolts over a slide and a whole jump; each rider quickening it), its look in every zone's
variant (within budget, only its lights and its riders' faces glowing, the blue no safe cyan, flat additive
floor lights) and, at its close gap at every zone's pace, every vertex of it under the camera's line of sight
to the runner's feet; the core hooks (a charge's contact destroys it as the player's kill with the riders'
bonus; weapons, splash, targeting and health bars never touch it; DamageRules never lets a stomp, the claws or
the dash defeat it; hosts and generators still pass charges by and a charge's other victims earn nothing; an
Octodog's moved-on charges ignore its entry); showing itself (C6b: its numbers; beside the runner at 3, 5 and 6
lanes in every look, all of it on screen in the run camera's view and nothing of the runner or their side behind
it, two lanes in from a runner by a wall (C6c); `EnforcerTruckRoom.can_dodge` never leaving the only free lane,
both ways two lanes in); its showing windows (C6c: on every level that lists it at 3, 5 and 6 lanes, own seed and
another, each planned window lies in its chase and holds in the finished level, `ShowPlanner.problem_of`, with no
zone doodad, filler, wider gap, danger density row or enemy, or planted cyborg in it; Corporate 2 at 3 lanes plans
its first truck's arrival showing; the windows each level gets are printed); the chases with room (C6d: on a plain
track with two Octodogs, one truck a level goes to the bait whose chase has room for its showing before it, the
introduction too, and stays at the first where that has room, and two a level take both; a truck arriving between
a Buzz Overdrive's claim and its rev gets its window after that attack, counted after the bait, and one arriving
after it shows itself as it arrives; on every level that lists it at 3, 5 and 6 lanes, own seed and two others,
every truck, moved or arriving earlier, keeps its placement rules, no window counted before the bait comes after a
bait's charge, and a truck without one has no free bait with one that its level could give it beside its other
truck, nor a level with fewer trucks than it may have; Corporate 2 always introduces it; the chases' windows before
and after the bait are printed); room beside a hover truck and a Gilded Sentinel (C6e: a hover truck's lane held over
its stay and its entrance an attack that can't wait, at 3, 5 and 6 lanes: the truck never takes that lane nor stands
between the runner and it, a runner beside it sees it two lanes in, the lane between free, and at 3 lanes only a
runner in its lane has a lane for it; a Sentinel's turn from its claim, a showing back before it; a window planned
beside each, the runner keeping a free lane; a showing whose bait's claim may come during it out of view before the
rev); the calm start (C6e: on a plain track at the Golden Zone's pace, its Buzz Overdrive revving 4 s after the
run-up, the truck arrives inside the run-up from `calm_start_min_seconds`, shows itself as it arrives, out of view
before the rev, its bait where it was, nothing taken out and nothing else attacking there; none before the data
minimum; every campaign window in the calm start takes nothing out); both trucks kept where a level has two but room
for one showing (`BOTH_TRUCKS`, checked both ways: Corporate 2 at 6 lanes, Dead Zone 2 at 5 and 6); its blast (seen
wherever it goes off, never in front of the runner, no core and a softer fire with Reduced flashing, its fading materials the warmed ones'
shaders); every campaign level that lists it at 3, 5 and 6 lanes (own seed
and others: the placement rules, baits in every chase, Corporate 2 always with one, the same every build; it
prints the counts), the same level without it but for its trucks (its windows not planned), quick play without a
bait having none; its
marker, light bar and Reduced flashing; its warm-up look (its blast's too); and its data. `test_enforcer_truck_runs` plays it on
real physics at 3, 5 and 6 lanes and at 18 and 23.4 m/s, with a scripted runner (no armor) that steps aside
a reaction after each warning: its lane delay to the frame and its gap; a runner who stays hit by its laser,
never before the warning and a bolt's flight; a whole chase escaped, the line exactly while a volley is on,
the interval, giving up after 25 s and leaving play; turns with a scripted big attack both ways; an Octodog's
lunge and a Buzz Overdrive's charge dodged late destroying it (the player's kill and the riders' bonus) and
dodged early missing it, no volley during either though one was due, big attacks taking turns or not; a too-
wide gap and a cut (the tank shot down mid-charge) wrecking it, an ordinary gap hopped; riders from passed
cyborgs in its lane only (not another lane, a killed one, a window cyborg or a host), at most 3, quickening its
volleys; the same run twice; each way it's destroyed ending in its blast a lurch later, with its sound, seen by the
run camera and never in front of the runner, its wreck never rising into the camera it passes under (C6b); its showings (C6b; the other runs play without them): on
arrival and mid-chase for `show_seconds`, its whole look on screen, back to its follow gap and the runner's lane,
never firing meanwhile, its siren swelling, a lane change into it bumped back unhurt and it giving way, never the
only free lane (zone doodads at 3, 5 and 6 lanes), two lanes in from a runner by a wall (C6c), turns both ways, a
bait close behind its arrival keeping it back and a later one shortening its stay, its baits still destroying it, a
planned window bringing its showing (C6c: its claim holding another type's attack back, no volley meanwhile), the
same every attempt; beside a hover truck holding lane 0 (C6e: at 5 lanes a runner in lane 1 sees it in lane 3 and
its showings and the hover truck's attacks never overlap; at 3 lanes it never shows itself there) and a Gilded
Sentinel (its stay shortened, out of view before the Sentinel's claim, which swings as planned); in the calm start
(C6e: arriving inside the run-up at its follow gap from the data minimum, alongside as it arrives, out of view before
the tank's rev, no volley and nothing else on meanwhile, the tank revving as planned, the same every attempt); and
Corporate 2 at 3, 5 and 6 lanes played to its end by a runner that baits each
truck (god mode, grapples): each destroyed by a charge it dodged or in a wider gap (task G7), no overlap with
its volleys, never firing while it shows itself, each truck whose window comes before its first bait coming
alongside (the showings it makes are printed).

`test_beach_levels` checks the Beach's levels (tasks D10b and D10c; Campaign, The Beach; The generator, Side wall
gaps): the zone and level data and its place in the campaign (zone 6, its steps, slots and music stand-in, its
volleyball match second); both generated levels (Tiki Tides and Sunset Strip, beach/1 and beach/3) at 3, 5 and 6 lanes
as the campaign configures them, on their own seeds and two others, with the campaign's
fairness checks (LayoutChecks) and every listed feature present (on
other seeds the Enforcer Truck, which only comes where a bait's chase has room, in nearly every build); the open
walls: each wall standing on 40-60% of its level (or more only where its keep-outs leave no more free), the
median wall in 45-55%, every gap at least `open_seconds_min` long and clear of its wall's keep-outs, most of the
open length in stretches of 100 m and more, both walls open at once within `both_open_max`, the same gaps on a
second build, and the level otherwise the same as with the shared tuning; and `--level=beach/1`, the campaign step
with the full flow, end to end through the smoke tool. How the campaign configures the Beach off its curve, and
that no other level or boss changed (nor with the volleyball match added), is `test_campaign`'s (Campaign, The Beach).
`test_volleyball` plays the Beach's volleyball match (task D10e; Mini-games) through the App on the real main scene,
by `VolleyballBot` (`tests/helpers/volleyball_bot.gd`) through the runner's own actions: its data and its place
between Tiki Tides and Sunset Strip; its track (nothing that hurts, no gaps, its credits in the run-in, the walls
open around the court); at 3, 5 and 6 lanes a runner returning every ball (the run-in, the stop on the line, standing
there through the match, 4-0 after three returns a point, paid 400, three stars, the results' match payout and stats,
the level's duration a flawless match's length, every ball at least the fairness floor, every arc over the net, the net
sunk before the runner runs on, the level complete); one never moving (0-4, paid nothing, one star), one standing
under the ball (it bounces off their head), one in the wrong lane; one winning 1 and 3 points (paid 100 and 300); the
jump's timing window around the ring's cue (at least 0.3 s, and a jump far too early misses); the same match on every
attempt; and a version 3 save's Sunset Strip record moving to beach/3, with Continue leading to the match.
`test_wall_gaps` holds every other campaign level to the shared tuning and checks the open walls on made-up tracks.
`test_wide_gaps` checks the wider gaps (task G7; The generator, Wider gaps): every campaign level at 3, 5 and 6
lanes with its 2 (LayoutChecks.check_wide_gaps: the length, the spacing, nothing in any lane from the take-off
margin to the landing margin, no zone doodad or its push's lead there, no side wall gap beside) and a floor
route across each (FloorRoute from the clear floor before it), printing each level's rows, holes and where its
wider gaps came from; none in a boss arena even asked, nor in quick play or the prototype level; Corporate 2 the
same on every attempt; every filler at the fill pass's spacing from every wider gap (three builds on other seeds
where a filler had to go for a longer row); on real physics at quick play's speed and every campaign level's, at 3, 5 and 6 lanes, a
jump early, midway and late in the take-off window clears one and running on falls in; an Enforcer Truck
following a runner who jumps one wrecked in it (the player's kill) and hopping a 0.5-of-a-jump row, at 3, 5 and
6 lanes, at 18 and 23.4 m/s; none in an Enforcer Truck's chase before its showing (from its arrival to its window's
end; task C6e) in any campaign build, nor on another seed of each level with the truck, each keeping its wider gaps
(one fewer allowed off its own seed; how many sit in a chase past its window is printed); Corporate 2's own build
at 3, 5 and 6 lanes, whose first chase leaves room past its window at two lane counts at least and holds a wider
gap there at `CORPORATE_2_CHASE_LANES` only (checked both ways; 3 lanes since task K5: at 5 lanes the chase past
its window is full, at 6 its window comes after its bait), played from its start (god mode, grapples) until the
runner leads its first truck over that wider gap, where it's wrecked; and the pass's last way (task K5) on
`LAST_RESORT_CASES` (the build's one wider gap from it, fair, past every truck's showing, every window holding) and
on a plain stretch fenced every 15 m (plain fences make way for it, pulsing ones keep it from coming).
`test_wall_run_gaps` checks the wall-run gaps (task J2; The generator, Wall-run gaps): their numbers at every zone's
run speed (longer than any jump with every boost and the dash; a standard wall run from the lit stretch's first metre
leaves the wall past the far edge, one from its last lands on the landing floor; the run-in crosses 6 lanes; the lit
wall clear past the longest wall run; claws adding less to a wall run than the run-in and the lit stretch last, so a
runner who passed a dash wall on a wall comes down before the gap); every campaign level with the feature at 3, 5 and
6 lanes on its own build
(`LayoutCache`): no warnings, at least one, `LayoutChecks.check_wall_run_gaps` (part of `check_layout`, so
`test_campaign`'s seed sweep checks them too) and a floor route across each that steps onto the lit wall from the lit
stretch (FloorRoute's wall-run move), the count by zone printed; none in the City's or Gangland's levels, quick play
or a boss arena; the same seed the same level; what a build a wider gap short keeps for its wider gaps in one more build
(`WallRunGapPlacement.wide_gap_reserve`: its first one's clear stretch, never in the level that brings them in), and
Golden 2 at 3 lanes with every wider gap and its wall-run gap moved by its own last resort. On real physics at 3, 5 and 6 lanes and both walls: a step onto the
lit wall early, midway or late on the lit stretch crosses onto the landing floor; with claws too; a jump, a jump with
the dash or the dash alone falls in, as does a step onto the wall well before the lit stretch; the grapple's save and a
revive after a fall put the runner on the lit wall and across, and a save at the gap's far edge off the wall over the
landing floor. Every zone skin lights the lit wall in green chevrons over exactly the stretch to step on and the gap,
on the wall face, facing the street, seamless across chunks; and a heli drone's barrage, a Bad Dream's slash, an
Enforcer Truck's volley and an Octodog's wind-up hold off only while a crossing is in their reach. `test_campaign`'s sweep
of The Hush lists the builds crowded past any wall-run gap (`WALL_RUN_GAP_CROWDED`: they warn of that and nothing
else), and `test_danger_density` lets the final band land lower at 3 lanes where the wall-run gaps take the pass's room
(`WALL_RUN_GAP_ROOM`); its route case and `test_gilded_sentinel`'s Sentinel wall case are built without them.
`test_ceiling_scenarios` checks the ceiling scenarios (task I4; The generator, Ceiling scenarios): their numbers and
heights (a ceiling fence above a floor runner's jump, a hover truck roof's, a wall runner's body and the chase
camera); none in the City's, Gangland's or the Marketplace's levels; in every level that lists them, at 3, 5 and 6
lanes, `LayoutChecks.check_scenarios` on its own build (`LayoutCache`), Casino 1's stash at 5 and 6 lanes (none on
3), Casino 2's simple fenced ceiling at every lane count, the several-pad version later, how many over the campaign
(printed); every stash build's other credits alone clearing three stars (a stash's are out of the stars' best
score); endless mode's only past their minimum difficulty; an uncached rebuild the same. On real physics: the
CeilingScenarios physics against the Player's trace (a pad's flip and rise, a return pad's drop and fall, a jump and
its low stretch); excerpts of the campaign's fenced ceilings (the simple one at each lane count, a several-pad one
at 5 and 6): every unsafe pad's rider, in every lane the ceiling covers, still, hopping over the first or second row
or jumping all the way, dies of a ceiling fence; every safe pad's rider (who runs past the unsafe pads in a lane free
of them) drops off past the ceiling alive; a floor runner jumping under the fences is never touched; armor gets an
unsafe pad's rider through, and an EMP switches the fences off; a heli drone that outlived its pads fires before the
pick, holds its barrages through it, and is hurled by the safe pad; excerpts of the stashes at 5 and 6 lanes (the
first and the last in campaign order): floor runners from every lane pressing toward the stash every frame, from
before it and from alongside it, never inside it and taking no credit, nor with the top magnet, holding a lane or
pressing toward it; the dash smashing in; the return pad's rider landing inside, never pushed, collecting every
credit (into the run's credits and score, not the stars' best score) and running out; one who stays on in another
lane dropping beyond it.
The track builds the fences (an electrical hazard at its depth and size, dressed) and the return pad (on the
underside, turned down, over the stash's lane) and every stash doodad; every skin dresses both (the field in the
zone's fence materials, whose shader honours Reduced flashing; the return pad as its pad); the chase camera stays
`camera_doodad_clearance` above a stash's doodads as a rider passes over them, and `RunCamera.doodad_floor` itself.
`test_charge_paths` checks the cyborgs in charge paths (task G7; The generator, Cyborgs in charge paths): every
campaign level's count and LayoutChecks.check_charge_paths at 3, 5 and 6 lanes (a plain floor cyborg, never a
host; its charger's planned path through it, in view, holding its fire, nothing around it), one before
Corporate 2's first Enforcer at each lane count, printing what each level got; nothing planted in quick play,
the prototype level or a boss arena (even asked); Golden 2 the same on every attempt; hand-built encounters
planned by the placement itself on real physics at 3, 5 and 6 lanes, at quick play's speed and Corporate 2's (an
Octodog in an outer lane and the middle one, a parked Buzz Overdrive in an outer lane and the middle one): the
cyborg flattened by the charge (never the player's kill) with the runner in_view_seconds behind it, no burst
charged and no bolt landing in its hold_fire stretch, a runner who leaves the far lane (the cut's lane) after
the warning untouched and one who stays hit; and in the campaign's own builds, played from the start, the first
planted Octodog encounter and the earliest Buzz Overdrive one at each lane count flattening their cyborgs.
`test_host_releases` checks that weapons hit hosts (task H8; GDD §9.7) and what that does to the campaign:
auto-fire targets a host and never the fence generator beside it, the heavy missile's splash on the host sparing
the generator, and its Bad Dream bursting out; a splash that kills a host beside its target releasing the Bad
Dream too (no host bonus); a weapon hurts a host, never a charge (`charge_can_hurt`); every
host level's layout at 3, 5 and 6 lanes keeping what the generator keeps off chases out of where a chase may
begin early (a host's walk plus the lurk's `hover_ahead`); and each host level played once (Dead Zone 1 at 5
lanes, Dead Zone 2 at 3, Golden 1 at 6, Golden 2 at 3, Golden 3 at 5) by a god-mode runner with weapon tier 2,
whose kills come furthest ahead (`tools/measure/host_watch.gd`, `attack_watch.gd`): hosts shot down ahead of
their spots in every level, every chase begun where it was planned (the lurk), never more than 10 s without a
pad from its first claws and no longer from its start than a chase begun at its host, nothing kept off chases
met, none fizzled or overlapping, its first telegraph from its hover spot, and no slash during an Octodog's
charge or a drone's barrage. `test_bad_dream` checks a weapon release on real physics: the lurk (where it
burst out, harmless, holding nothing back), its chase beginning with the runner within `hover_ahead`, then
playing out as a stomped host's, and the kill's score without the host bonus.

`test_wall_fences` checks wall fences (B5; GDD §9.1): the layout data (left out of a level without them) and
`WallFencePlan`'s bands, reach (a floor runner in the middle of the outer lane never touches one, a wall runner
in its band does, at 3, 5 and 6 lanes) and state on the level clock (never off to on without the warning); the
track's hazard (WallFencePlan's hitbox, electrical, never a wall blocker, the crackle, following `state_at`
frame by frame, and picking up the level clock when built late); on real physics at 3, 5 and 6 lanes, a wall
runner hit while one is on and safe while it's off, a floor runner beside a live one never touched, stepping
onto the wall into a live one a hit, jumping off before one passing it, a low one passed by jumping onto the
wall and a high one by stepping on (and each hit the other way), a runner who jumps off 0.2 s after the warning
starts never hit wherever they are then (one who stays is hit at some phases), armor, the shield and the dash
through and claws not, the weapon finding nothing to shoot at, and an EMP switching them off, built or not;
every campaign level with them (own seed and others, 3, 5 and 6 lanes) placing them fairly
(`LayoutChecks.check_wall_fences`), keeping both kinds, the same on every attempt; Marketplace 2's and Corporate
1's introductions (first of their kind, alone, off long, within `intro_seconds` on the levels' own seeds and on
most others, mostly where no enemy is about); Marketplace 2 at 18 and 25 m/s (the margins in seconds); every
campaign level exactly the same without the features but for its wall fences (pattern picks, fillers and
guarantee builds too), and the levels without them having none; quick play with them among every rule's pieces
(`LayoutChecks.check_layout`); `wall_fence_problem` naming each rule; the hints; every skin's look; and a boss
arena carrying them.
`test_fireballs` checks the shared explosion (task H6; A run, Speed effects): the pool is bounded and reused
(built with the effects, a node count that doesn't move across many fireballs, the oldest cut short when every
slot is busy, fixed particle counts, each ending by itself, quick ones sooner), CPU particles and unshaded
billboards only, with no collision and no light, the camera's fade (none of a fireball within its size of the camera, all of it from
2.5 times, its smoke and hidden emitters, a smokeless fireball hiding its slot's old smoke), Reduced flashing (as long as the normal one, from nothing,
never brighter than it after 0.15 s and at most 0.45 of its peak, no white in it: sampled over the real life of the fire, the core and the embers),
the shader warm-up's looks, and each non-boss explosion (the drone's hit and crash, the hover truck's wreck, its
burst and its wall frame's steady glow with Reduced flashing, the Buzz Overdrive, the Enforcer truck, a fence
generator and its EMP, the plain and heavy missile, the lobby's blast) calling it at its size; the bosses'
(the Floating Head's crash and bomb blasts, The House's collapse and blasts, Hostile Takeover's defeat) are
checked in `test_floating_head`, `test_floating_head_defeat`, `test_the_house_phases`, `test_the_house_attacks`
and `test_hostile_takeover_fight`.
`test_perf` checks what keeps frames smooth (task PERF1; A run, Smooth frames) and that none of it changes the
game: a chunk's dressing spread over frames (the same gameplay nodes in each chunk's frame, the same look once
dressed, every chunk dressed before the player is `DRESS_BY` from it, a chunk freed undressed skipped without
errors, and a seeded run on Gangland 2 with its enemies giving the same trace, events and enemy log at budgets of
0, 1 µs and 1 ms), enemy types readied with the level (every hooked kind and a host's Bad Dream, scripts loaded,
nothing left in the tree or heard, once a process, `warm_looks()`, the hover truck's among them), hit-stops that never stack or chain, BossProps'
shared rings, the shader warm-up stage (the cyborgs' looks, fences in every state, particles as particles, the
run's hidden looks, nothing colliding, lit or top-level), the player's shadow and a screech lair's dark recess drawing with the glow's shaders and the speed lines sharing one
Shader (task I1), the frame monitor's tags (chunks, a spawn, a kill and
its hit-stop, the held frames) and summaries, and the frame graph's spikes and holds. `test_frame_times` plays
City 3, Marketplace 2 and Golden 2 for 40 s each as the game does (`frame_times.gd --child`, two passes, each in
a fresh process, each frame's faster time) and holds their 99th percentile and worst frame to
`PerformanceTuning`'s test budgets, scaled by load the way the skin suites' chunk budgets are: each pass times
`SkinSuite`'s reference build every 60 frames alongside the run (`--reference`, far off to one side, left out of
the frames), and `SkinSuite.load_factor()` widens the budgets by how slow the machine is right then. Unlike the
skin suites, it pools the passes' reference readings instead of folding them to their per-index minimum (FIX3):
the reference only samples ~40 times in the 40 s a frame-time pass plays (against the frames' own 2400), so
folding two such sparse passes needed both slow at the same one-in-forty moment to register, which a busy
machine's bursty load cleared far less often than it cleared the frames' own tail statistic (p99 needs only 1%
of 2400 chances) -- read as load factor 1.00x on a machine other agents' test runs kept busy, while the level's
own p99 and worst frame were plainly slower, failing under real `--jobs` load that a true reading would have
covered.
`test_hover_truck`'s cost checks (task I5; A run, The hover truck's cost on a phone) hold a truck to what a renderer
pays for it: its model built with the level and not by its first spawn, a warm-up look with a material for every
one it shows through a whole visit (spawn, banging, burst, pacing, lurch back, rev, forward lurch, shot down,
explosion), no `OmniLight3D` or `SpotLight3D` anywhere in play, no node made while it plays (its explosion is
`RunEffects.fireball`'s, pooled), and its warning glow shown exactly through the rev and the forward lurch,
flashing with the spikes and steady with Reduced flashing. Six of those checks fail on the build before I5.
`test_level_cache` checks that a retry plays a copy of the last build exactly as a fresh build (task PERF2; A
run, Retries reuse the built level): the key (the same for the same level configured again or with another
look; another for each thing the build reads: seed, lane count, difficulty, features, feature starts, pacing,
run speed, the recency curve, the movement, placement, danger density and enemy tunings edited in place as F6
does, the patterns, the build flavor), `LevelLayout.copy()` copying every field into lists of its own, generated
layouts holding plain data only, the warnings coming with a reused level, a seeded scripted attempt (dashes and
an EMP in its script) at Gangland 3 (5 lanes) and Corporate 2 (3 lanes) playing the same with the cache off, on
its first run, its restart and the results screen's retry (layout, the runner's trace and events, kills, credits,
the enemies' event log, floor cuts, score, EMPs), nothing leaking from an attempt changed every way play can into
either retry (and the kept build untouched; every zone doodad and dash wall smashed or marked, then all of them
standing as the retry's track is built), an attempt at Golden 1 at 3 lanes dashing through a doodad and a dash
wall, then dying: both retries from the build's layout with both built whole (the same node, place, layers, shapes
and look; the restart's standing in the physics world) and the restart, not dashing, playing as on a fresh build
(tasks H5 and H7a, the H merge), the debug keys, F6 edits and another level building again, and endless mode
building on every run and keeping nothing.
`test_web_demo` checks the web demo's preset (the head include's audio session script too), its export filter
against the data and everything the demo references, and walks the demo from the title to its end screen (see
Platforms and build flavors). `test_phone_screens` (task I3; Characters, UI and audio, Menus on a phone) lays
every screen the demo shows out at phone sizes, sideways and upright, in device pixels, and checks what a
phone's player needs of it: text and finger targets big enough, nothing cut or off the screen, the way on in
sight, touches passing to the scroll areas, and `UiScale`'s maths and lifecycle (`--verbose` after the suite
name lists every problem found). The runner frees
anything a suite leaves in the tree, gives suites a fresh, unsaved profile, reports a suite that fails
to load, and ends a stuck run after 2400 s of real time.

`test_zone_shaders` checks one program per look (task I1; A run, Smooth frames: the web demo's programs): in each
zone's first level, the Golden Palace and every built boss's arena (`LayoutCache` layouts; the world built, a second
of a boss's fight played so what it builds as the runner nears is there, some of the track dressed and the shader
warm-up's stage built) no shader code is in two Shaders, and no two standard materials differ only in what the
renderer ignores (the emission of an unshaded one: such a look is the glow's with a shader of its own, as the player's
shadow, a screech lair's recess and the Floating Head's tower cut were). A medium suite; the files that make such looks
(`greybox_materials.gd`, `shader_warmup.gd`, `screech_lair.gd`, the tower) map to it in `tests/suite_map.json`.
