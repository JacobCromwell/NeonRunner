# List of Tasks
NOTE: Mark tasks as done as you complete them.

- [x] three additional upgrade tiers to the dash costing 800, 1,000 and 1,200 credits, with a minimum cooldown of 3 seconds. The exact cooldowns for the four total tiers should be 8 / 6 / 4 / 3 seconds.

- [x] The enemy density and obstacle density is too light. In general, the algorithm that is used to make sure that there is always a free open lane is too forgiving. So that should be tightened up across the board to be creating levels that have more increased density of enemies and obstacles, etcetera. On a low end, so for the first few levels, the increase in density should be about 15%. However, by the final levels, the increase in density of danger should be about 35%. Use your own judgment for increases to the other levels and zones.

- [x] The cyborg enemy has a laser attack that is a little hard to notice, so make the sound of the lasers firing a little bit louder, about 30% louder.

- [x] the armor should protect or take one hit from the player touching the barnacle turret, which it does not currently.

- [x] The swarm host and the house bosses are both too easy and should be made more difficult.

- [x] As far as level design goes, in the gold zone, the knight/sentinels that are just decorative should appear at the bottom of the walls (currently they appear at the top), this way when an actual dangerous sentinel enemy exists, there is a chance of the player being surprised by it. Right now, they are too conspicuous and easy to avoid.

- [x] The Octodog and Buzz Overdrive's charge attacks should hurt other enemies if they charge into them. If having enemies being able to hurt each other drastically increases the complexity of the code, then write that out to the user requests and do not implement that feature for now. However, if it does not greatly increase the complexity of the code, then please implement it.

## Floating Head follow-up (October 9, 2026)

- [x] Keep the first bombing run as it is. In the next bombing run, instead of one target at a time, drop bombs on two to four spots at once, with one or two bombs on each. To keep it fair, the first spot in a salvo is closest to the player and each later one a little further away, so the player can see the path they'll have to take before the bombs are released. DONE (task E1g): both later runs (phases 2 and 3) drop salvos of 2–4 spots (`salvo_spots` in `data/bosses/city_boss_tuning.tres`: set the last number to 1 to keep the third phase's run as it was). Every salvo leaves a way through, checked at 3, 5 and 6 lanes. The open choices are in `docs/OPEN_QUESTIONS.md` §D, items 396–399.
- [x] Answers on the salvos: (1) increase the difficulty on five or more lanes; (2) make the spots tighter; (3) the later runs a little longer, for the longer salvos; (4) far spots the same colour. DONE (task E1g): on 5 and 6 lanes a spot takes up to three bombs side by side, placed so only one way through is left (`salvo_wide_lanes`, `salvo_wide_bombs`, `salvo_wide_choices`); spots 10 m apart instead of 12 m (`salvo_spacing`); later runs 6.5 s instead of 5.6 s (`later_run_seconds`), enough for two salvos of four spots; every target circle stays the same red at any distance (it was tinted by the City's purple fog far away).

## Gangland boss intro (October 9, 2026)

- [x] The intro cinematic for the Gangland boss (the Swarm Host), at ground level so we feel in the runner's shoes: the runner runs down the middle of the street between manhole covers; at 2 s one screech jumps out of a manhole and the runner easily avoids it; a second later three (two on one side, one on the other), which the runner dodges; a second later five on the left and six on the right, which the runner runs past; then more and more pour out, and drop from the sky out of view, landing and running beside the runner; soon a wall or wave of screeches chases the runner; as it gets closer, one cut to the mass: in a dark area inside it, a glint of the Host. DONE (task F2b): `SewerSwarmIntro` in Gangland's boss-intro slot (GDD §10; what the beat leaves open is open questions 387–395).

## Zone 1 outro (October 8, 2026)

- [x] The outro after the Floating Head, if it doesn't cost too much in code complexity, storage or performance. The boss crashes. The camera comes down to the runner's level. The runner stops and looks left at a barricade guarded by Barnacle Turrets standing on the floor like cannons, a row of five cyborgs, a battle truck behind them and a heli drone above it, all reusing the game's assets. The camera pans back to the startled runner, who runs the other way and jumps off a truck. An explosion goes off behind them, and they land in Gangland. DONE (task F2a): `CityOutro`. It is code only, with no new files to download, and the City outro's own tests check what it costs at 3, 5 and 6 lanes. The staging choices are in `docs/OPEN_QUESTIONS.md` §D, items 369–381.

## Level skies (October 8, 2026)

- [x] Gangland 3's sky becomes a cloudy blood red, to show the player is coming up on a fiery section; Gangland 1 and 2 keep theirs. DONE: `data/skies/gangland_blood_red.tres`.
- [x] Neon City 3's sky shows the sun just starting to rise: pinks and purples touching the undersides of clouds. DONE: `data/skies/city_dawn.tres`.
- [x] The Marketplace's third level gets a darkening sky as the sun sets: deep blues, with pinks at the very bottom of the sky. DONE on Marketplace 2, the zone's last level (the Marketplace has two levels; to confirm): `data/skies/marketplace_sunset.tres`.

## Enforcer Truck follow-up (October 7, 2026)

- [x] Change the gap generation so that occasionally there is a wider gap. It shouldn't be very common, but it should happen a couple of times each level. (Answers open question 352: a wider gap wrecks an Enforcer Truck that follows the player into it.) DONE (task G7): two wider gaps per campaign level, 0.7 of a jump long, clearable with a normal jump, with clear room around each.
- [x] Change the enemy generation so that occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge. (Answers open question 353, the teaching moment: the player sees a charge flatten another enemy, at least once before the Enforcer's first appearance in Corporate 2.) DONE (task G7): one per level with Octodogs or Buzz Overdrives where it fits, and always one before Corporate 2's first Enforcer.
- [x] Hosts never board the Enforcer Truck, and its riders can't be shot off. (Answers open question 351: already built that way.)
- [x] The Enforcer Truck's model is never seen in play, so occasionally it should speed up until it's close enough to be on screen, even if that clutters the screen, stay there a few seconds, then slow down and fall back, so the player sees what's behind them. (October 8, 2026; task C6b.) DONE: it pulls up beside the runner for 3 s on arrival and mid-chase, where the level leaves room. Task C6c (October 9) has the generator keep a calm window for it in each chase where one fits, and lets it show itself two lanes in from a runner by a wall: over the six Enforcer levels at 3, 5 and 6 lanes, a runner sees it in 57 of 106 chase runs (15 before; 32 as it arrives, 7 before). The rest, chases with no room and windows lost to an early bait, are open questions 382–386.
- [x] When the Enforcer Truck falls into a gap or is hit by a Buzz Overdrive, there should be a visible explosion. (October 8, 2026; task C6b.) DONE: every kind of destruction (Octodog, Buzz Overdrive, cut, wider gap) lurches the wreck into view and explodes there.

## Sewer Swarm follow-up (October 4, 2026)

- [x] Update the Sewer Swarm's concurrent attacks and dangerous walls:
  - In phase 2, front and rear surges overlap in two different lanes, leaving X-2 safe lanes on an X-lane playfield.
  - Shorten the full surge warnings in phases 1 and 2, preserving the 0.9-second front and 1.0-second rear locked-lane dodge windows. Preserve enough early warning to choose a bait reactively, even if the total reduction is less than 50%.
  - Any visible swarm actually occupying a wall damages a player who contacts it and prevents mounting or remaining in that occupied area. Keep wall creatures naturally colored: DO NOT MAKE THEM RED.
  - Continue wall pressure into phase 3. Before each usable weak-point ramp, visibly clear only the necessary ramp, wall-run, wall-jump and landing route; swarm elsewhere remains dangerous.

- [x] Double the Sewer Swarm Host's phase-3 hit requirement from three to six successful weak-point hits, without increasing the phase-1 or phase-2 requirements.

Verified across 3/5/6 lanes at 18 and 21.8 m/s: all six Swarm suites pass (627 checks),
including six ramp/wall-run/wall-jump stomps, concurrent damage windows and local wall clearance.
Native phase-3 renders and the campaign-speed smoke run are clean. The full 81-suite gate reports
only the eight unrelated failures reproduced on unchanged HEAD (frame times, Hostile Takeover fight,
Resonator and doodads). Clean wins take about 104.5 seconds; boss star pars are now 115/150 seconds.