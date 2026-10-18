# Architecture: Tests: the boss suites

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Tests (continued)

The Floating Head's suites fight at the City's speed, 21 m/s, as the campaign plays it (E1f:
`FloatingHeadBot.campaign_tuning`), and recheck its fairness with its margins at that pace.
`test_floating_head`
runs the Floating Head's fight in bare worlds at 3, 5 and 6 lanes with a runner who dodges each lock
(and one who doesn't), rechecks its bombs' fairness from the arena's layout, and checks the campaign's
fight runs at the City's speed (a harder tier's faster);
`test_floating_head_faceoff` plays its face-off with `FloatingHeadBot` (every laser warned and
escaped without god mode, the cyborg drop, a baited and a fallback tower pinning it) and rechecks
each attack's fairness from the real arena's layout; `test_floating_head_stomps` has the bot take each
phase's stomp window at 3, 5 and 6 lanes without god mode, checks the ways up are physical, missed
windows repeat without escalation, the damage and weapon cap, the armor pickups, the window's ceiling
rules, and plays the whole fight from its entrance to the last stomp; `test_floating_head_routes` (E1e,
the owner's playtest) sweeps lane switches alongside the ramp (each boards it or bumps, never into it),
boards it late in the fight, checks the wall marks and a single wall jump off them from either wall
(at 5 and 6 lanes too), the ceiling from a pad in any lane, the ways' first-time hints and armor for a
runner who brings none, and plays the campaign's boss step end to end at 3, 5 and 6 lanes with a death
and a retry; `test_floating_head_defeat`
checks its defeat (after the last stomp at 3, 5 and 6 lanes and by weapons in the air: the
propaganda cut, the glitch, the fall, the wreck with room for a runner in every lane, the run through
it without god mode, Reduced flashing, the same every attempt) and plays the whole fight through the
campaign at 3, 5 and 6 lanes with the bot and no god mode (City 3, the boss intro's slot, the fight,
its results and stars, the shop, the outro's slot, and the web demo's end screen), checking along the
way that its propaganda never masks a warning, then that a death restarts the fight. `test_sleep_taker`
builds the Sleep Taker at 3, 5 and 6 lanes (its slot, immune to weapons, its hitboxes, its draw budget
and colours, its arena with no ceilings, its refuges (the floor clear, one wall standing from the warning
past the strike, its lane clear for the landing), its generator sites, six times the floor gaps it was first
built with and its many wall gaps, the other wall open at some refuges, and kept as laps join, the
entrance, shots and missiles passing through it, lights out at least 75% darker than October 8's with the
runner glowing by its own light, every other boss keeping the framework's floors, and the light always
coming back); `test_sleep_taker_attacks` plays its slash and
hands with `SleepTakerBot` at 18 and 24.2 m/s (struck only after the warning and only in the warned
lanes, every escape from every lane without god mode, up a wall or out of the lanes, a wall runner never
touched, the same every attempt; the hands' rounds growing from three rows to six, each row its own distance along the street, its door one
lane over from the last and a hand in the lane the runner kept free, wall hands on every row; the
planner's numbers and budget; every round's way through proved on real physics in each phase and at
both speeds, a lane switch at every row) and its whole pattern on the real arena at 3, 5 and 6 lanes for
a runner who lets every generator go by; `test_sleep_taker_fight` plays the whole fight with the bot at
3, 5 and 6 lanes and both speeds (five EMPs in 60-160 s, every round of hands with its way through,
every lure on time with the arcs showing it's in reach well before the stomp, nothing
attacking while lured, the chunks torn, the same every attempt), a missed generator followed by another
with nothing escalating, EMPs out of reach, the defeat (the wisps, the silence, the dawn, the lights back
after), and the campaign's flow at every lane count (the Dead Zone's last level, a death in the fight's
second phase, the retry won with three stars, the shop, the outro). `test_the_house` builds The House at
3, 5 and 6 lanes (its slot, built, with its data and par times, its plain arena, its size under the
street's cables, its squat under a ceiling and its draw budget, a cabinet that doesn't glow, its reels and
their defeat's wild spin and jam, TILT steady with Reduced flashing, how symbols become attacks, the
phases' special buttons, the route solver's rows, walls, fences, slaloms, buttons and holds, and phase 3's
ceiling within C1's limits for every pad lane); `test_the_house_attacks` plays every attack at every size with
`TheHouseBot` at 3, 5 and 6 lanes and 18 and 23 m/s (each strike's warning on the track where it then
hits and nothing hitting anywhere else, the bigger versions, the 3-lane mix of bombs and blocks always
leaving a way, the citizens ducking, every phase's spins survived over a few seeds without god mode);
`test_the_house_fight` plays its buttons and jackpot at every lane count and both speeds (buttons in
plain view and in lanes of their own, locking their reels; the sirens, the fountain's real credits, the
hopper open well ahead of the runner as the machine sinks; the stomp's big hit and its recovery), a
missed button, a missed set and a missed hopper (it just spins again, nothing escalating), weapons up to
their cap, the same fight every attempt, and phase 1 won in quick play at every lane count and both
speeds, then a death and the retry won through all three phases (floor, wall and ceiling buttons pressed,
inside its three-star par); `test_the_house_phases` plays phase 2 (wall fences pulsing along both walls,
the wall button lit in plain view and run over along the wall with every wall fence passed off, the
attacks waiting, strikes off the drop windows) and phase 3 (the billboard over every lane with its pad,
the machine squatting under it, one or two turrets firing, the ceiling button run over, the bolts
dodged, the rider dropping back onto clear floor) and the defeat (the wild spin, the jam, TILT, the
collapse in coins ahead of the runner, the citizens cheering) at 3, 5 and 6 lanes and both speeds, and
the campaign's flow at 23 m/s at every lane count (Casino 2, a death in the fight's second phase,
the retry won with three stars, the shop, the outro). `test_hostile_takeover` builds Hostile Takeover's
train (E5b) at 3, 5 and 6 lanes and 18 and 23.4 m/s (its slot in the campaign after Corporate 2, par times,
sounds and hints; the laps holding the train
alone, every gap across every lane, a share of a jump, the carriages in their consist, routed and jumped
from every lane with the real jump; the couplings' stomp box and take-off window at the run's pace, a fall
never high enough to stomp; the Board's coupling lanes, guards clear of the gaps, of each coupling's run-up
and landing and of each other, a way through everywhere, Tithe Collectors alone on the flatcars and capped
a phase, partial wall fences keeping a level's rules; phase 2's plan: each drop's cut the C2 tank's own and
keeping a level's rules for cuts, checked independently, the runway longer than any leap in every lane, the
armored carriage out of a jump's reach both ways, the belly over the runner to past it, the strafes' free
lane; phase 3's plan: no drop before the docking is over, each drop's cut a level's, each pass's runway on
the carriage after the flatcar, the belly over the runner until its stern passes them, the same seconds at
every speed, the landing clear of the gaps, the three clamps one under each third with a lane under each,
a jump from anywhere on a clamp's cue landing on it, time after boarding and after each stomp's bounce for a
reaction and two lane moves, the Board back only on its slots; its models' budgets and colours, the
breakaway on the train's material, phase 3's parts built with the fight and hidden, MERGER COMPLETE and the
clamps' pulse steady with Reduced flashing, nothing made while the city streams past or from the docking to
the defeat); `test_hostile_takeover_fight` plays the whole fight with `HostileTakeoverBot` and no god mode
at every lane count and both speeds (the entrance, the dark opening gaps, each coupling lit in plain view in
a lane of its own with its cue and hint, the stomp's big hit and the carriages breaking away; phase 1
standing down, each strafe warned and raking only its warned lanes after the warning, the drop and its
tank's rev before its charge, the armored carriage in sight, the ride and the drop bay stomped; the
docking, MERGER COMPLETE with its sounds and hint, phase 3's strafes and drops warned, the pass and the three
clamps stomped from lanes under them, each live only while ridden under; the defeat: the lobby ahead, the
gunship climbing away spinning and exploding, the locomotive ploughing into the lobby, the sculpture down,
the screens dark, each on time with its sound), a stomp from the lane beside the coupling's, a coupling
sailed over from its own lane and two let go by (each harmless, the next one coming), a run off the edge (a
fall, no stomp), the Tithe Collector skimming its trail, a runner hit in a strafe's lane only once its
warning is over, the dropped tank's rules with the armor (its blade blocked, the floor held), the armored
carriage impassable without its runway, a drop bay let go by and the next cycle's stomped, a pass let go by
and clamps left in a pass coming around in the next, weapons poured on never ending a phase and never
saving a clamp, the armor rule (an armor hit, no armor, the final phase), the whole fight the same on every
attempt, quick play at two setups (phases 1 and 2 won, a death once docked, the retry won whole, and quick
play starting over after the defeat), and the campaign at 23.4 m/s at every lane count (Corporate 2, a
death in the fight's last phase, the retry won with three stars, the shop, the outro);
`tools/measure/hostile_takeover.gd` plays every lane count and speed.
`test_golden_convergence` builds The Golden Convergence's first step (E5d-a): its slot (six phases with
their paces, the checkpoint at stage 2's first, equal shares, weapons within 0.17, the 22 s armor rule,
payout, score, pars, music, built: the campaign's slot plays it), its sounds (warnings never pitch-varied,
the whine as long as the warning) and hints, the beat scripts, the squadron's size and covered lanes, the
Grand Court at 3, 5 and 6 lanes (plain laps, both walls taken away ahead and bumping the runner back, a wall
opened, run, its end dropping the runner off, closed again, closing under a runner), the suit (no hitbox,
targetable only once the pattern begins, its chest within the upgraded weapons' reach and not the tier-1
weapon's, a hit chipping the fight; nothing on it glowing or past the hazards' saturation, the dull red
tear, the cape's shader never glowing; its arms, hatches, torn pipes and plates; its draw budget), the
entrance (the rise, the deep brass fanfare and not the chime, the unfurl, nothing attacking or targetable, then the first strafe), the
squadron never red or targeted, the Flying Buttress (its lean, its rise and sound, a lane switch into it
bumped, its arch run through, smashed and crumbling, back in the pool), Reduced flashing (the muzzle flashes
and tracers steady, flickering otherwise), the reel of a later phase (its right shoulder's pipes blown out, the
first ship's damage, whatever ended the phase), stage 2 starting with the transition from the checkpoint,
the feed's handles and colours, and the boss bar's name and phase; `test_golden_convergence_fight` plays
phase 1's two strafes with `GoldenConvergenceBot` and no god mode at 3, 5 and 6 lanes and 18 and 25 m/s
(every frame: fire only on a warned lane's stretch or the live line, never the opening, and only once the
warning is over; the fire reaching the runner's distance at least a second after its warning; drones over
covered lanes and the spare above; the live line whole while the runner is at it; the first vertical pass
on lanes 1, 3, 5 counting from 1 and the parity switching; each buttress in an inner lane, up
`buttress_sight` ahead and in reach from the farthest lane; the runner untouched; the sounds and hints), the
7-pass strafe (V-V-H-v-V-H-v, the passes from behind opening up behind the runner), a runner hit staying in a
raked lane (once its warning is over) or out of the arch (jumping or not), the armor blocking a rake, the
dash through the live line, the wall rule (low on an open wall hit by an outer lane's rake, high up safe;
the live line hitting a wall runner high up), a pad hurling the squadron and ending the strafe, the hold, and
40 s played the same on two attempts (since E5d-b phase 1's run plays the slams and the barrage between the
strafes, and phase 2's its two slam sequences and barrages before the 7-pass strafe, all untouched; since
E5d-c the bot lets each Refill Ship's pad go by there, so the phase loops).
E5d-c's suites: `test_golden_convergence_refill` checks the Refill Ship's data (its sounds in the library, under
2.5 s and never pitch-varied; its hints; its place at the end of each stage 1 phase's beats; the loop back to
the slams); the closed cage at 3, 5 and 6 lanes and 18 and 25 m/s (its fences flickering in harmlessly, then on;
its generator beside the pad's lane, `generator_before` ahead; a sweep of jumps from every takeoff that could
clear the front fence and a little past either way, every one that clears it coming down past the pad, never on
it; a lane switch into it from either side, on the floor and in the air, touching a side fence); the fence rules
on its front fence (the dash passes onto the pad, armor and the shield get through at a hit's cost, claws don't
help, an EMP switches off the fences it reaches and no others); the rides by the generator (5 lanes, 18 m/s),
the dash (3 lanes, 25 m/s) and armor (6 lanes, 25 m/s) with the bot and no god mode (every frame: the squadron
holding its fire from the cage coming up until the runner is past the pad, no pass at all meanwhile, the drones
at their places beside the ship once it's down; weapons never targeting the ship or the generator; the cage
`cage_lead` ahead, on `cage_flicker` later, the ship down over every lane at the ceiling's height
`settle_before` ahead of the front fence; the events in order from the ship flying in to the hit; the strafe
over with the hurl; every rack missile gone, the ship exploded; the hit a third of the suit's health, ending the
phase; the right shoulder's pipes; the runner riding, dropping back and landing unharmed on clear floor; each
sound once, the hints), Reduced flashing and the screen shake off (no sparks, no shake, the fireballs still,
their hearts never white-hot), the chain reaction's fire at 3 and 6 lanes at 25 m/s (E5d polish: the fire a
saturated orange-red, the smoke dark, every puff above the deck, the big ones beside the causeway in the run
camera's view, two draws and nothing made mid-fight), a missed pad (the ship climbing back, finishing and flying
off while the strafe fires its passes left; `ends_at()` silent before the miss and right after it; the slams
after it planned ahead; the next ship the same), the next phase's first slams planned by the chain (on time at
25 m/s, as soon as the built track allows at 18), phase 3's ship (the suit bursting open with the transition's
blast alone, nothing planned for stage 2), the review's phase-end fixes (a gate standing ahead sinking at a
phase's end, a crumbling one crumbling on, a stale gate reference leaving another attack's gate alone, a dropped
slam plan's floor warnings gone and a new plan's rows off its cuts, the hatches and the arms easing to rest
through an intro, a horizontal pass first after a hold keeping its full `buttress_sight`), a lane switch pressed
as the runner reaches the pad (the final review's: the pad firing from another lane still starts the chain and sinks
the cage, so the rider is never stranded on the belly; a failsafe in `_tick_refill` logs `refill_failsafe` and
starts it should anything else get them there), the ride the same on two attempts, and F6's ranges (E5d polish: at every end of `cage_lead` and `generator_before` the generator
stays in reach; at the worst ends on 6 lanes the bot stomps it and rides the pad).
`test_golden_convergence_whole` plays the whole fight from the entrance with the bot (the generator's way) and no
god mode at 3, 5 and 6 lanes and 18 and 25 m/s: stage 1 won from its pads (three ships, a third of the suit's
health each, one a phase, never a miss; the first blowing out his right shoulder's pipes, the second his left's,
the third bursting the suit open), stage 2 from the checkpoint at half health, three stomps, the defeat and
`victory_over`, untouched (217.6-220.2 s of fight at 25 m/s, 228.2-229.3 s at 18, with E5d-e's longer stage 2;
198.3-200.1 s and 208.9-209.1 s before it); the par times against those clean
fights (Hostile Takeover's margins: three stars at 238 s, two at 308 s, the time bonus to 378 s; three stars at
18 m/s too); and the campaign's Golden Zone boss step through the App at 25 m/s (the real fight, not a preview;
stage 1 won, a death in stage 2, the run summary and the retry resuming at the checkpoint with the time so far,
the transition again, won, its stars from the pars).
E5d-b's suites: `test_golden_convergence_slams` checks the Fist Slam's scripts (the GDD's ON, ON, AHEAD with
chances on 2 and 3, then ON, AHEAD, ON, ON, AHEAD with chances on 3 and 4), the footprints (sizes, moved inward
at the edge), the holes at 3, 5 and 6 lanes (planned past the built track, a cut in every lane of the row, the
footprint's lanes opened at the impact and no other, one square hole with no lips between its lanes, nothing in
its look glowing but the orange edges; E5d polish: the row draws nothing before its impact, the hole's few parts
under one cut from meshes made before the fight), the buttress rule at every lock lane and lane count (a hole
never through a standing gate unless the fist locked on its lane; on 3 lanes too), the touch and the holds
(unprotected dies; the armor, the shield and the dash live and have the floor held for the hold's second; the
grapple saves the fall, not the hit), an AHEAD hole jumped, fallen into, grappled out of, the sequences (two
chances, the sequence over on a hit, the other gate sinking), the tower (on the arch's lean side, out of view as
it starts, landing on time beside the causeway with its shake, honouring the Screen shake setting, the wall open
from about the gate for `tower_wall_seconds` and run on, closed after with the balustrade back, the pool), the
warning (its lead, the square and the shadow, the hint), Reduced flashing, and E5d polish's: consecutive rows at
least `row_gap()` apart at 3, 5 and 6 lanes, 18 to 28 m/s, in every phase, with the script's numbers and F6's
tightest (moved no more than needed), the shadow as dark on the Compatibility renderer, and a wall runner beside
a slam untouched while a floor runner in its footprint is hit;
`test_golden_convergence_barrage` checks its numbers against the GDD's limits (longer than one layer of
protection, through with two, shorter than a wall run), the warning against the time to reach the
wall from the far side at 3, 5 and 6 lanes and 18 and 25 m/s (the hatches, the missiles, the marks as floor
warnings over every lane, filling in, nothing burning before), the missiles hanging in the run camera's view
in front of the suit, the fire covering every lane over the stretch the runner runs while it burns (a dash
included) for `fire_seconds`, the burning floor over just what burns, a jump only delaying it, the fire's
boxes clear of a wall runner at every height on either wall, a wall runner untouched through the burn,
protection stacking with the real player (the free armor alone dies; armor and the dash, two armor hits,
armor and the shield get through), no wall still hitting, Reduced flashing, and E5d polish's: the marks' fill
and the burning floor reading red over the marble on both renderers' blending, and F6's ranges (at every end of
the warning's steps, the reaction and the margin the warning leaves time to reach the wall, the missiles hanging
longer where needed; the toppled tower's wall outlasting the barrage; the worst ends played on 6 lanes);
`test_golden_convergence_bait` has `GoldenConvergenceBot` play phase 1's and a later phase's slams, bait and
barrage at 3, 5 and 6 lanes and 18 and 25 m/s with no god mode (every frame: no fist touch but at an impact,
no fire but in its burn, no hole but a footprint, none through a gate; the bait on the first chance, the
tower down, the barrage warming up as it falls, the runner on the tower's wall through the whole burn,
untouched) and the same on two attempts.
`test_golden_convergence_magnate` builds stage 2 (E5d-d) a part at a time: its beat scripts, sounds and hints; his look (two to three
times the runner's size, inside the chroma limit but the ports, the dull red tear, the cracks' warm white
against the runner's copper, grey smoke, his draw budget, no target before the transition); the transition
from the checkpoint and again on a retry, and from phase 3's end (the order, the feed switching, nothing live,
the leap high over the runner, landing behind in their lane, the suit never down onto the track); the chase at
3 and 6 lanes (the lane delay, the marker and the shadow in his lane, nothing solid or harmful); the overtake
(never in a lane in sight); the Pounce at 3 lanes 18 m/s and 6 lanes 25 m/s (the red marker with the roar, the
lock at least a second before he lands, the square a floor warning, the crash live only after he lands and
only over the square, above a jump; a runner who stays is hit, jumping or not; the armor blocks it); the bait
(the stun across two lanes, a weak point over each, his sides; the stomp ending the phase and the hurl;
refused, a Pounce like any other and the bait again); the release; a switch into him bumping, never hurting;
the Cable Lash low and high (the warning as long as `lash_warning`, the red line over every lane, the cable
across every lane before the runner gets there; a runner who doesn't answer, or answers the other way, is hit;
the armor blocks it); the defeat with and without the riff (the cables one by one, the screens dark outward
to every one, the music cut, the collapse ahead out of the way, the crack light out, the runner past, only then
`victory_over`); Reduced flashing (the Lash's crackle at most about 3 sparks a second); F6's ranges (E5d polish:
`stun_stomp_top` past its old range's top, the longest release and the shortest reach, the bot still stomping
him at 18 and 25 m/s; a high Lash at the lowest `lash_high` and the thickest `lash_radius`, slid under). E5d-e
added the playtest's beat scripts (a Slash and a storm in every phase, the Slashes double in phase 6, phase 4's
script exactly, the shorter beat gap), the new sounds (the snarl and the glitch-whine never pitch-varied, the
whine as long as a screen's warning) and hints.
`test_golden_convergence_magnate_fight` plays stage 2 from the checkpoint
with `GoldenConvergenceBot` and no god mode at 3, 5 and 6 lanes and 18 and 25 m/s (won untouched, three stomps,
the paces, every Pounce locked a second ahead, every Lash warned; E5d-e: a Slash and a storm in every phase, none
let go, no screen touching the runner), the release at every lane count and speed, and the whole stage the same
on two attempts.
E5d-e's suites: `test_golden_convergence_slash` plays the Claw Slash at 3, 5 and 6 lanes and 18 and 25 m/s with
the bot dodging a reaction late (the warning, the marker flashing and held shown, the snarl and the claw marks a
floor warning in the runner's lane, at least `slash_warning` before the swipe at every pace; always a lane beside
it clear; the swipe live only over the marks and only as it lands, above a jump; his claws where the camera shows
them), `slash:double` (the second locked onto the lane the runner dodged into), a runner who stays hit (jumping
or not) and the armor blocking it, the hold while a buttress's sides leave no lane, Reduced flashing (the marker
and the marks steady), and the stomp (at least `stun_takeoff` from the stun to the last take-off at every lane
count and speed; the chevrons green, steady, in both his lanes over the middle of the take-off stretch; a jump
from their near end, middle or far end stomps him; gone once he's stomped). `test_golden_convergence_storm` plays
the storm's plan without the engine (200 storms at each of 3 to 6 lanes, five ways for a runner a reaction late to
pick a lane clear as the warning showed: never struck, never sent into a warned lane, every screen placed, three
on him, the runner's own lane struck again and again), storms in the fight at 3, 5 and 6 lanes and 18 and 25 m/s
with the bot weaving by the plan's escapes (each screen warned `screen_warning` before it crashes with its
whine, its square a floor warning, its touch live only over the square and from its crash, nothing left on the
track, a twelfth of the phase off him for each screen on him, cause `&"screen"`, his stagger and cry of pain), a
runner who stays hit and the armor blocking it, four storms ending a phase and the last phase's ending the fight,
Reduced flashing (squares steady, no sparks) and the darkness (the fade through the transition from the
checkpoint, on a retry and from phase 3's end; dark through stage 2; back as he falls, before the results; his
body dimmed with the court, his cracks' glow not).
`test_sewer_swarm` builds the Sewer Swarm (E4) at 3, 5
and 6 lanes and 18 and 21.8 m/s: its slot (built, the campaign's step plays it; phase 1 two clusters, phase 2
the rest, phase 3 three hits; its par times; weapons within its cap; its new sounds and hints), its
crowd sizes in data and smaller on a low-end device, the screech's crowd mesh, its clusters (simulated
entities with one hitbox each, their crowds one MultiMesh each with no collision and no node per creature, all
made before the fight and none after a whole phase of surges), the horde and its lairs, its draw count, its
MultiMeshes' white instance colours (the Compatibility renderer), its arena's every bait spot (a live full fence or a hole in one lane, the street around it clear, in reach from any
lane before the lock, a way out of every lane, met by a baited cluster ahead of the runner) and the stress scene;
`test_sewer_swarm_fight` plays phase 1 with `SewerSwarmBot` without god mode or armor: won by baiting at every
lane count and both speeds, the same every attempt, every surge warned (line and chitter) warning_seconds before
its hit and its hitbox live only from the lock, a fence and a hole baited by a runner who switches out and by
one who jumps (the line locked from the bait, never on toward the runner), a hit only through the hitbox (an
enemy attack armor blocks, once) and never beside it, a way out of every surge from every lane, no bait: no end
and no escalation, weapons thinning only a surging cluster with the heavy missile's swarm bonus (and a cluster
thinned to nothing counting), the armor rule with and without armor, the same fight at 30 and 400 screeches a
cluster, and a death then a retry won at 21.8 m/s (6 lanes) and through quick play's own restart (3 lanes).
`test_sewer_swarm_surrounded` plays phase 2 from its start: won by baiting at every lane count and both
speeds (from behind and from ahead), every strike from behind warned (the wave risen over the locked lane,
its chitter, the line) `behind_warning_seconds` before its crash and its hitbox live only from it, a way out
of it from every lane at both speeds, strikes from behind baited into a fence and a hole ahead, the climb
(one wall at a time, alternating, timed, the climbed wall refusing entry and the other taking the runner,
never the runner's wall), simultaneous damaging front/rear surges in distinct lanes, and no bait: no end.
`test_sewer_swarm_walls` checks natural colors, visible wall contact damage and repulsion with armor,
shield and grace, phase-3 local route clearance, and death/retry behavior.
`test_sewer_swarm_host` plays phase 3: its entrance, six
stomps from the ramp and a wall jump at every lane count and both speeds, its lunge baited into a fence, its
crouch solid, its defeat, and weapons within the cap. `test_sewer_swarm_whole` plays the whole fight: won at
every lane count and both speeds with no crowd made mid-fight, the same every attempt, its par times (a clean
win three stars, one with a chance let go by in each phase two), a death in Surrounded and the retry won,
and the campaign at every lane count (Gangland 3, a death, the retry, the win, stars, shop and the outro).
