# List of Tasks
NOTE: Mark tasks as done as you complete them.

- [x] three additional upgrade tiers to the dash costing 800, 1,000 and 1,200 credits, with a minimum cooldown of 3 seconds. The exact cooldowns for the four total tiers should be 8 / 6 / 4 / 3 seconds.

- [x] The enemy density and obstacle density is too light. In general, the algorithm that is used to make sure that there is always a free open lane is too forgiving. So that should be tightened up across the board to be creating levels that have more increased density of enemies and obstacles, etcetera. On a low end, so for the first few levels, the increase in density should be about 15%. However, by the final levels, the increase in density of danger should be about 35%. Use your own judgment for increases to the other levels and zones.

- [x] The cyborg enemy has a laser attack that is a little hard to notice, so make the sound of the lasers firing a little bit louder, about 30% louder.

- [x] the armor should protect or take one hit from the player touching the barnacle turret, which it does not currently.

- [x] The swarm host and the house bosses are both too easy and should be made more difficult.

- [x] As far as level design goes, in the gold zone, the knight/sentinels that are just decorative should appear at the bottom of the walls (currently they appear at the top), this way when an actual dangerous sentinel enemy exists, there is a chance of the player being surprised by it. Right now, they are too conspicuous and easy to avoid.

- [x] The Octodog and Buzz Overdrive's charge attacks should hurt other enemies if they charge into them. If having enemies being able to hurt each other drastically increases the complexity of the code, then write that out to the user requests and do not implement that feature for now. However, if it does not greatly increase the complexity of the code, then please implement it.

## Casino zone (October 8, 2026)

- [ ] Add a Casino zone right after the Marketplace: two Marketplace levels on the way to the Casino, then two Casino levels, then The House, which moves from the Marketplace to the Casino. Don't create new character or enemy skins (no new cyborg, truck, heli drone and so on): use the Marketplace's. Only the walls, floors, ceilings and background change, following the owner's reference image (`docs/art/reference/casino_zone.webp`). Tasks K1 (the skin) and K2 (the campaign).

## Level skies (October 8, 2026)

- [x] Gangland 3's sky becomes a cloudy blood red, to show the player is coming up on a fiery section; Gangland 1 and 2 keep theirs. DONE: `data/skies/gangland_blood_red.tres`.
- [x] Neon City 3's sky shows the sun just starting to rise: pinks and purples touching the undersides of clouds. DONE: `data/skies/city_dawn.tres`.
- [x] The Marketplace's third level gets a darkening sky as the sun sets: deep blues, with pinks at the very bottom of the sky. DONE on Marketplace 2, the zone's last level (the Marketplace has two levels; to confirm): `data/skies/marketplace_sunset.tres`.

## Enforcer Truck follow-up (October 7, 2026)

- [x] Change the gap generation so that occasionally there is a wider gap. It shouldn't be very common, but it should happen a couple of times each level. (Answers open question 352: a wider gap wrecks an Enforcer Truck that follows the player into it.) DONE (task G7): two wider gaps per campaign level, 0.7 of a jump long, clearable with a normal jump, with clear room around each.
- [x] Change the enemy generation so that occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge. (Answers open question 353, the teaching moment: the player sees a charge flatten another enemy, at least once before the Enforcer's first appearance in Corporate 2.) DONE (task G7): one per level with Octodogs or Buzz Overdrives where it fits, and always one before Corporate 2's first Enforcer.
- [x] Hosts never board the Enforcer Truck, and its riders can't be shot off. (Answers open question 351: already built that way.)
- [x] The Enforcer Truck's model is never seen in play, so occasionally it should speed up until it's close enough to be on screen, even if that clutters the screen, stay there a few seconds, then slow down and fall back, so the player sees what's behind them. (October 8, 2026; task C6b.) DONE: it pulls up beside the runner for 3 s on arrival and mid-chase, where the level leaves room; making room in every chase is task C6c.
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