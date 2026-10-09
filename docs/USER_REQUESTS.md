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

- [x] Add a Casino zone right after the Marketplace: two Marketplace levels on the way to the Casino, then two Casino levels, then The House, which moves from the Marketplace to the Casino. Don't create new character or enemy skins (no new cyborg, truck, heli drone and so on): use the Marketplace's. Only the walls, floors, ceilings and background change, following the owner's reference image (`docs/art/reference/casino_zone.webp`). Tasks K1 (the skin) and K2 (the campaign). DONE: the Casino is Zone 4 with two levels (*Brass Arcade* and *House Edge*, proposed names) and The House; the Marketplace has its two levels and no boss. Open points for the owner: `docs/OPEN_QUESTIONS.md` §D, items 416–436 (the skin's look, the 17-level difficulty curve, music, level names).

## Casino follow-up (October 9, 2026)

- [x] No level gets easier with the Casino added: every level is too easy, at least on PC. Corporate and beyond being harder is fine; the Marketplace levels should stay as difficult as they were, or be a little harder. (Task K4.) DONE: the campaign curve's exponent is 0.79 (`data/campaign/campaign.tres`): City 1 and Golden 3 unchanged, every other level harder than before the Casino (the Marketplace +0.026 and +0.016, Corporate 1 +0.095). Open points: `docs/OPEN_QUESTIONS.md` §D, items 440–444.
- [x] The Casino's level names, *Brass Arcade* and *House Edge*, are approved.
- [x] The owner adds the Casino's song in a separate change (nothing to do here).
- [x] The Casino's glass ceiling is whole, and its signs use real lettering: "Gasket's House of Chance" and "The Brass Lotus". No pedestrians. (Task K3.) DONE: the vault has every pane; the two names are landmark casinos about every 100 m along the street, alternating, on their boards and on tall blade signs readable from a distance (`CasinoSkin.name_spacing`; 0 names every casino). Open points: `docs/OPEN_QUESTIONS.md` §D, items 437–439.

## Floating Head follow-up (October 9, 2026)

- [x] Keep the first bombing run as it is. In the next bombing run, instead of one target at a time, drop bombs on two to four spots at once, with one or two bombs on each. To keep it fair, the first spot in a salvo is closest to the player and each later one a little further away, so the player can see the path they'll have to take before the bombs are released. DONE (task E1g): both later runs (phases 2 and 3) drop salvos of 2–4 spots (`salvo_spots` in `data/bosses/city_boss_tuning.tres`: set the last number to 1 to keep the third phase's run as it was). Every salvo leaves a way through, checked at 3, 5 and 6 lanes. The open choices are in `docs/OPEN_QUESTIONS.md` §D, items 396–399.
- [x] Answers on the salvos: (1) increase the difficulty on five or more lanes; (2) make the spots tighter; (3) the later runs a little longer, for the longer salvos; (4) far spots the same colour. DONE (task E1g): on 5 and 6 lanes a spot takes up to three bombs side by side, placed so only one way through is left (`salvo_wide_lanes`, `salvo_wide_bombs`, `salvo_wide_choices`); spots 10 m apart instead of 12 m (`salvo_spacing`); later runs 6.5 s instead of 5.6 s (`later_run_seconds`), enough for two salvos of four spots; every target circle stays the same red at any distance (it was tinted by the City's purple fog far away).
- [x] The third phase keeps its salvos; three bombs per spot is okay; on five or more lanes a choice of two lanes is okay, and on 3 lanes the salvo is a forced path. DONE (task E1g): every street now places its spots to leave the runner as few lanes as possible: one lane on 3 lanes (one or two bombs a spot), a choice of two from 5 lanes (up to three bombs). Open questions 396 and 397 answered.

## Doodad pictures (October 9, 2026)

- [x] The doodads look like a jumble of squares and other 3D primitives. Keep each doodad a simple box, but draw on it pictures that look like the object, with the open-air parts transparent: the Marketplace's stall has a wooden base, supports in each corner and a little roof, and the middle where the goods are is air. What to draw in each zone is left to the build's recommendation. DONE (task G6b): every zone's doodads are picture cards painted by code (`tools/asset_gen/doodad_art/`, `tools/godot.sh doodads`); the looks chosen are in `docs/OPEN_QUESTIONS.md` §D, items 412–415 (all answered).
- [x] Answers on the doodad pictures: (1) no hint of which way a doodad pushes; (2) a rubble heap lower at its edges is fine; (3) the soft neutral edge sheen instead of the violet one is fine; (4) the looks that differ from the first doodads (drums, a van, a stall, a booth, a container, a column, a bus, the statue as the small one, a colonnade) are fine. DONE: recorded in GDD §3 (Zone doodads, their look); the `DESIGN-TBD` marker is gone.
- [ ] Doodads prefer the lane next to the side wall when it's open, without costing gameplay: not where the generator already has something on that part of the wall or needs it open. Held, by the owner's choice ("art first, placement later"), until the dash-smash branch (`claude/nifty-brahmagupta-i5ov2i`, H5) is resolved, since it changes the same generator, track and player code.

## Gangland boss intro (October 9, 2026)

- [x] The intro cinematic for the Gangland boss (the Swarm Host), at ground level so we feel in the runner's shoes: the runner runs down the middle of the street between manhole covers; at 2 s one screech jumps out of a manhole and the runner easily avoids it; a second later three (two on one side, one on the other), which the runner dodges; a second later five on the left and six on the right, which the runner runs past; then more and more pour out, and drop from the sky out of view, landing and running beside the runner; soon a wall or wave of screeches chases the runner; as it gets closer, one cut to the mass: in a dark area inside it, a glint of the Host. DONE (task F2b): `SewerSwarmIntro` in Gangland's boss-intro slot (GDD §10; what the beat leaves open is open questions 387–395).

## Zone 1 outro (October 8, 2026)

- [x] The outro after the Floating Head, if it doesn't cost too much in code complexity, storage or performance. The boss crashes. The camera comes down to the runner's level. The runner stops and looks left at a barricade guarded by Barnacle Turrets standing on the floor like cannons, a row of five cyborgs, a battle truck behind them and a heli drone above it, all reusing the game's assets. The camera pans back to the startled runner, who runs the other way and jumps off a truck. An explosion goes off behind them, and they land in Gangland. DONE (task F2a): `CityOutro`. It is code only, with no new files to download, and the City outro's own tests check what it costs at 3, 5 and 6 lanes. The staging choices are in `docs/OPEN_QUESTIONS.md` §D, items 369–381.

## Level skies (October 8, 2026)

- [x] Gangland 3's sky becomes a cloudy blood red, to show the player is coming up on a fiery section; Gangland 1 and 2 keep theirs. DONE: `data/skies/gangland_blood_red.tres`.
- [x] Neon City 3's sky shows the sun just starting to rise: pinks and purples touching the undersides of clouds. DONE: `data/skies/city_dawn.tres`.
- [x] The Marketplace's third level gets a darkening sky as the sun sets: deep blues, with pinks at the very bottom of the sky. DONE on Marketplace 2, the zone's last level (the Marketplace has two levels; the owner confirmed it on October 9, 2026): `data/skies/marketplace_sunset.tres`.
- [x] Follow-up: the dawn fits City 1 better thematically: move it there, and City 3 goes back to the dark night sky. DONE.
- [x] Follow-up: the boss fight after a level whose sky changed has that level's sky. DONE (`Campaign.configure_boss`): the Sewer Swarm and The House, and the Sewer Swarm's intro before its fight (`CineStage.sky_for`).
- [x] Follow-up: the street lighting follows the sky, if it adds little code and no performance cost. DONE: one colour factor per level sky (`scenery_tint`), one multiply per pixel in the scenery shaders that already follow a level's darkness.
- [x] Follow-up: leave Gangland's smoke columns as they are. Left alone.

## Enforcer Truck follow-up (October 7, 2026)

- [x] Change the gap generation so that occasionally there is a wider gap. It shouldn't be very common, but it should happen a couple of times each level. (Answers open question 352: a wider gap wrecks an Enforcer Truck that follows the player into it.) DONE (task G7): two wider gaps per campaign level, 0.7 of a jump long, clearable with a normal jump, with clear room around each.
- [x] Change the enemy generation so that occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge. (Answers open question 353, the teaching moment: the player sees a charge flatten another enemy, at least once before the Enforcer's first appearance in Corporate 2.) DONE (task G7): one per level with Octodogs or Buzz Overdrives where it fits, and always one before Corporate 2's first Enforcer.
- [x] Hosts never board the Enforcer Truck, and its riders can't be shot off. (Answers open question 351: already built that way.)
- [x] The Enforcer Truck's model is never seen in play, so occasionally it should speed up until it's close enough to be on screen, even if that clutters the screen, stay there a few seconds, then slow down and fall back, so the player sees what's behind them. (October 8, 2026; task C6b.) DONE: it pulls up beside the runner for 3 s on arrival and mid-chase, where the level leaves room. Task C6c (October 9) has the generator keep a calm window for it in each chase where one fits, and lets it show itself two lanes in from a runner by a wall: over the six Enforcer levels at 3, 5 and 6 lanes, a runner sees it in 57 of 106 chase runs (15 before; 32 as it arrives, 7 before). The rest, chases with no room and windows lost to an early bait, are open questions 382–386.
- [x] When the Enforcer Truck falls into a gap or is hit by a Buzz Overdrive, there should be a visible explosion. (October 8, 2026; task C6b.) DONE: every kind of destruction (Octodog, Buzz Overdrive, cut, wider gap) lurches the wreck into view and explodes there.
- [x] An Enforcer chase with no room for a showing: move the truck to a chase with room whenever the level has another bait. (October 9, 2026; open question 384; task C6d.) DONE (task C6d): trucks go to the chases that have room before their bait, the level's introduction included. On the campaign levels' own seeds no level had a free bait with room, so they're unchanged; on other seeds chases with a window before the bait rose from 63 to 71 of 227. What's left is open questions 400–403.
- [x] Where its showing would come after the bait, the truck arrives earlier so the player sees it before they can bait it. (October 9, 2026; open question 385; task C6d.) DONE (task C6d): a pair of trucks is also planned the other way round so the earlier one arrives earlier; where the bait comes right after the run-up, no earlier arrival fits (open question 400).
- [x] To a runner in an outer lane it shows itself two lanes in, leaving the lane between free. (October 9, 2026; open question 382.) DONE in task C6c.
- [x] The showing windows' cost (about 2% fewer enemies and obstacles on the Enforcer's levels) is accepted. (October 9, 2026; open question 383.)
- [x] The Enforcer Truck may show itself while a hover truck or a Gilded Sentinel is around, as long as the runner keeps a free lane (more clutter is fine). (October 9, 2026; open questions 367 and 400; task C6e.) DONE (task C6e): beside a hover truck the runner keeps a free lane and the truck never shows itself between them; a showing never meets the hover truck's entrance or a Sentinel's turn. Wider gaps also keep off the stretch before a showing. Over the six Enforcer levels' own seeds, a runner sees the truck in 73 of 106 chase runs (57 before).
- [x] Where a level's first bait comes right after its calm start, the truck arrives a few seconds early and shows itself in the last part of the calm start. (October 9, 2026; open question 400, option A; task C6e.) DONE (task C6e): Golden 1 at 3 lanes shows it in the calm start; Golden 1 and 2 at 6 lanes and Golden 3 at 5 would need things taken out after the run-up (open question 408).
- [x] A level with two Enforcer Trucks but room for only one showing keeps both. (October 9, 2026; open question 401: as built.)
- [x] A retry of the same level reuses its built level instead of building it again, so retries start at once (the orchestrator's proposal, approved October 9, 2026; task PERF2). DONE: a retry from the results screen takes 0.3–0.4 s instead of 3.3–4.7 s on Corporate 2 and Dead Zone 1 at 5 lanes, and plays exactly as a fresh build (`LevelCache`). A level's first build still takes up to 2.9 s on a desktop (Dead Zone 1 at 5 lanes).

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