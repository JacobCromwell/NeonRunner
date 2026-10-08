# List of Tasks
NOTE: Mark tasks as done as you complete them.

- [x] three additional upgrade tiers to the dash costing 800, 1,000 and 1,200 credits, with a minimum cooldown of 3 seconds. The exact cooldowns for the four total tiers should be 8 / 6 / 4 / 3 seconds.

- [x] The enemy density and obstacle density is too light. In general, the algorithm that is used to make sure that there is always a free open lane is too forgiving. So that should be tightened up across the board to be creating levels that have more increased density of enemies and obstacles, etcetera. On a low end, so for the first few levels, the increase in density should be about 15%. However, by the final levels, the increase in density of danger should be about 35%. Use your own judgment for increases to the other levels and zones.

- [x] The cyborg enemy has a laser attack that is a little hard to notice, so make the sound of the lasers firing a little bit louder, about 30% louder.

- [x] the armor should protect or take one hit from the player touching the barnacle turret, which it does not currently.

- [x] The swarm host and the house bosses are both too easy and should be made more difficult.

- [x] As far as level design goes, in the gold zone, the knight/sentinels that are just decorative should appear at the bottom of the walls (currently they appear at the top), this way when an actual dangerous sentinel enemy exists, there is a chance of the player being surprised by it. Right now, they are too conspicuous and easy to avoid.

- [x] The Octodog and Buzz Overdrive's charge attacks should hurt other enemies if they charge into them. If having enemies being able to hurt each other drastically increases the complexity of the code, then write that out to the user requests and do not implement that feature for now. However, if it does not greatly increase the complexity of the code, then please implement it.

## Enforcer Truck follow-up (October 7, 2026)

- [x] Change the gap generation so that occasionally there is a wider gap. It shouldn't be very common, but it should happen a couple of times each level. (Answers open question 352: a wider gap wrecks an Enforcer Truck that follows the player into it.) DONE (task G7): two wider gaps per campaign level, 0.7 of a jump long, clearable with a normal jump, with clear room around each.
- [x] Change the enemy generation so that occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge. (Answers open question 353, the teaching moment: the player sees a charge flatten another enemy, at least once before the Enforcer's first appearance in Corporate 2.) DONE (task G7): one per level with Octodogs or Buzz Overdrives where it fits, and always one before Corporate 2's first Enforcer.
- [x] Hosts never board the Enforcer Truck, and its riders can't be shot off. (Answers open question 351: already built that way.)

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

## Owner's requests (October 8, 2026)

Task IDs refer to `docs/TASK_PLAN.md`, section H. The owner's answers to the orchestrator's questions are in brackets.

- [x] Sentinel wind-up time should be decreased by half. (H1: the warning goes from 1.2 s to 0.6 s.)
- [x] Sentinels and their background are too hard to see inside the arched recess: bring them a bit further forward so the player can see and make out what they are. (H1)
- [x] The attack sound of the Golden Zone's Resonator shouldn't sound like a doorbell: it should sound more like a crackling build of fire and a crashing wave. (H2)
- [ ] The bottoms of Buzz Overdrive cuts in the floor should show a zone-specific background. (H3)
- [x] Only one enemy may fire at a time, which looks and feels unnatural: let two enemies fire at a time. (H4) [Owner: this is the cyborg-type guns' limit (cyborgs, window cyborgs, Barnacle Turrets): two bursts may be in the air at once. Big attacks of different types still take turns.]
- [ ] Make doodads destructible by a dash. (H5)
- [ ] The heli drone's explosion and all explosions in the game need to be more visually impressive: a yellow and red fireball. (H6)
- [ ] Walls the player can dash through: not the side walls, but walls blocking the path forward, using the side walls' assets turned to face the player, like a building in the middle of the street. The player must dash through them; they crumble and explode into rubble when hit. Without the dash, the player takes one hit (armor, then shield; with neither, it kills). (H7a, H7b) [Owner: they block every floor lane but not the side walls, no ceiling shares their stretch, and they're introduced in the Corporate zone.]
- [ ] Lasers auto-target host cyborgs, so players have to switch the laser off to avoid releasing Bad Dreams. (H8) [Owner: in normal levels; this reverses the September 26 rule that hosts are immune to weapons.]
- [ ] Sleep Taker: when it makes the screen darker, things should get 50% darker than they already do (glowing things like gaps and lasers stay visible). (H9)
- [ ] Sleep Taker: more hands, spread out along the street rather than all at the same spot, so the player has to make several quick lane switches to get through one round of the hand attack. (H9)
- [ ] Sleep Taker: the side walls are too safe: many more gaps in the side walls, and hand attacks there too. (H9)
- [ ] Sleep Taker: double the floor gaps. (H9)
- [ ] The Tithe Collector should stay in the level twice as long. (H10)
