# List of Tasks: done

The owner's requests that are built, with their DONE notes, moved out of `docs/USER_REQUESTS.md` (October 14, 2026 onward).

## Early requests (October 2026)

- [x] three additional upgrade tiers to the dash costing 800, 1,000 and 1,200 credits, with a minimum cooldown of 3 seconds. The exact cooldowns for the four total tiers should be 8 / 6 / 4 / 3 seconds.

- [x] The enemy density and obstacle density is too light. In general, the algorithm that is used to make sure that there is always a free open lane is too forgiving. So that should be tightened up across the board to be creating levels that have more increased density of enemies and obstacles, etcetera. On a low end, so for the first few levels, the increase in density should be about 15%. However, by the final levels, the increase in density of danger should be about 35%. Use your own judgment for increases to the other levels and zones.

- [x] The cyborg enemy has a laser attack that is a little hard to notice, so make the sound of the lasers firing a little bit louder, about 30% louder.

- [x] the armor should protect or take one hit from the player touching the barnacle turret, which it does not currently.

- [x] The swarm host and the house bosses are both too easy and should be made more difficult.

- [x] As far as level design goes, in the gold zone, the knight/sentinels that are just decorative should appear at the bottom of the walls (currently they appear at the top), this way when an actual dangerous sentinel enemy exists, there is a chance of the player being surprised by it. Right now, they are too conspicuous and easy to avoid.

- [x] The Octodog and Buzz Overdrive's charge attacks should hurt other enemies if they charge into them. If having enemies being able to hurt each other drastically increases the complexity of the code, then write that out to the user requests and do not implement that feature for now. However, if it does not greatly increase the complexity of the code, then please implement it.

## Beach volleyball (October 10, 2026)

- [x] "We need to create another beach level. This new beach level should come between the two beach levels that currently exist. So the beach level that's currently beach level two should become beach level three. This new beach level should be a mini game. So it starts off like a normal level for the first couple seconds. And then very quickly, our character walks up to a volleyball court. There is a net and there is another person there. You should render a new person who is wearing swim trunks and he will hit a volleyball over to our character and our character has to get underneath the volleyball and jump up in order to hit it back. This will go back and forth a few times. If our player misses, then the opponent gets a point. Whereas if we hit it back over the net enough times, say three or four times, then we get a point. This happens until one person has scored four points. Then our player gets a cash payout based upon how many rounds they won or how many points they won. So if they only won one round, they'll get a hundred. Whereas if they got all four points, they get 400 credits. After that, our character leaves and runs across the finish line of the level." Task D10e.
  - DONE (task D10e):
    - **Levels:** Beach 2 is the volleyball match, *Net Gains* (a proposed name; `data/levels/beach_2.tres`), and Sunset Strip is Beach 3 (`data/levels/beach_3.tres`), playing exactly as it did. The match is off the difficulty curve and counts for no other level's feature ages, so no other level changes. Play it with `--level=beach/2`.
    - **The match:** 2.5 s of normal run with a trail of credits, then the runner slows to a walk and stops on the line of a court laid across the street, on the open beach. A man in swim trunks (a new character on the shared rig) serves. A ring on the sand marks where the ball comes down, and a closing ring shows when to jump. Three returns in a rally win the point (the last one lands out of his reach and he dives for it). A ball that drops, or bounces off a runner who didn't jump, is his point. First to 4. Each point won pays 100 credits (the level's completion bonus, "Match payout" on the results). Then the net sinks into the sand, he steps aside and waves, and the runner runs on across the finish line.
    - **Fairness:** every ball leaves time to reach its lane and jump, each ball of a rally comes a little quicker and further away, and the runner can't die. Every attempt plays the same match against the same moves.
    - **Saves:** a save that finished Sunset Strip keeps it as Beach 3, and Continue leads to the new Beach 2.
    - **Open questions** (the name, three returns or four, the payout instead of the completion bonus, stars, the court, the rival's look and play): `docs/questions/d10e.md`.

## Beach zone (October 9, 2026)

- [x] A new zone, the Beach, with `docs/art/reference/beach_zone.jpg` as its inspiration: a sandy lane between bamboo tiki bars and surf shops running down to the sea. **The gaps are pools of water.** It gets its own background, floors, walls, ceilings and the rest of a zone's look, but **no new enemy assets**: it reuses the existing enemies. **Its place in the campaign is not decided yet; it won't be the last zone.** Task D10 builds the skin only (`data/skins/beach_skin.tres`, quick play `--skin=beach`). Its levels, boss, music, cinematics and campaign slot follow once the owner picks the slot. SKIN BUILT (task D10): sand and boardwalk lanes; pools filled near the rim with deep, unlit teal water in black steel tanks, with the orange gap edge; bamboo tiki bars and surf shops; footbridges, verandas and a party barge as ceilings; surfboard racks, cabanas and tiki kiosks as doodads; an afternoon sky over the sea and an island. Its open questions, the recommended slot among them (zone 5, between Corporate and the Dead Zone), are items 538–559 in `docs/OPEN_QUESTIONS.md` §D. The owner then placed it as zone 5 (task D10c, below).

- [x] The owner's answers on the Beach skin (October 9, 2026):
  - **Skies:** the first level in daylight. The last level shows the sun starting to set: "not dark, but the sun's starting to have some purples and oranges in the sky". Reuse an existing sky if one works. Neither the Marketplace's sunset nor the City's dawn does (both are night-dark overhead, with stars), so the Beach gets its own (`data/skies/beach_sunset.tres`).
  - **Pools:** a fall makes a splash, if it isn't too difficult. The water may sit a little closer to the rim, but it's pretty good as it is.
  - **Signs:** keep the wordless signs as they are.
  - **Cyborgs:** reuse whichever existing cyborg look fits the zone best. The orchestrator picked the Casino Mob Enforcer (`&"casino"`): a mob running the bars and lounges, and the Barnacle Turret's furry creature look, barnacles at the beach.
  - **Side walls:** "have more gaps on the side walls ... I want this zone to feel more open, so I'll have much longer sections where there aren't sidewalls, and the player can see the surrounding area a little bit better. So don't get rid of the sidewalls completely, but have them appear about 50% of the time that they are now currently appearing for this zone." Task D10b gives a level its own wall-gap tuning, which the Beach's levels use, and provisional Beach levels outside the campaign. Task D10 draws the surroundings in the open stretches.
  - DONE (tasks D10 and D10b):
    - **Skies:** `data/skies/beach_sunset.tres` on Beach 2; Beach 1 keeps the daylight.
    - **Pools:** a splash with a sound when a fall reaches the water (`BeachWaterWatch`, `BeachSplash`), and the water at 0.45 m under the rim.
    - **Cyborgs:** the Casino Mob Enforcer.
    - **Side walls:** each wall stands on about 50% of a Beach level, down from about 97%, in open stretches of 2 s or more (median about 117 m). The walls' own keep-outs (ramps' wall runs, wall enemies, signs, ceilings) leave a few walls standing on up to about 65%. The beach, the sea and palms show beyond (`BeachOpen`).
    - **Levels:** provisional Beach levels outside the campaign, set up for the recommended slot. Play them with `--level=beach/1` and `--level=beach/2`.
    - **Open questions:** items 538–568 in `docs/OPEN_QUESTIONS.md` §D.

- [x] The Beach joins the campaign (October 9, 2026):
  - "Put the beach between the corporate and dead zone."
  - "Keep in mind that there will be a boss battle for the beach, but it has not yet been created."
  - "Do not worry about any new enemies at this time."
  - "Create level names that fit the theme": Beach 1 is **Tiki Tides** and Beach 2 **Sunset Strip**.

  Then a PR, merged to main. Task D10c.
  - DONE (task D10c):
    - **Campaign:** the Beach is zone 5 (intro, Tiki Tides, Sunset Strip, boss slot, outro), zone 6 since the Casino (zone 4) joined main. It sits off the difficulty curve between Corporate 2 and Dead Zone 1, so every other level and boss plays exactly as before.
    - **Boss:** an unbuilt placeholder that the campaign passes through (task E5e, blocked on design).
    - **Cinematics and music:** placeholder cinematics; the Marketplace's songs as a stand-in.
    - **Fixes from the review before merge:**
      - the hover truck no longer lurches at a player beside an open wall;
      - a wall between two open stretches stands at least 2 s;
      - every Beach chunk keeps its motion cues.
    - **Open questions:** items 569–583 in `docs/OPEN_QUESTIONS.md` §D.

## Casino zone (October 8, 2026)

- [x] Add a Casino zone right after the Marketplace: two Marketplace levels on the way to the Casino, then two Casino levels, then The House, which moves from the Marketplace to the Casino. Don't create new character or enemy skins (no new cyborg, truck, heli drone and so on): use the Marketplace's. Only the walls, floors, ceilings and background change, following the owner's reference image (`docs/art/reference/casino_zone.webp`). Tasks K1 (the skin) and K2 (the campaign). DONE: the Casino is Zone 4 with two levels (*Brass Arcade* and *House Edge*, proposed names) and The House; the Marketplace has its two levels and no boss. Open points for the owner: `docs/OPEN_QUESTIONS.md` §D, items 504–524 (the skin's look, the 17-level difficulty curve, music, level names).

## Casino follow-up (October 9, 2026)

- [x] No level gets easier with the Casino added: every level is too easy, at least on PC. Corporate and beyond being harder is fine; the Marketplace levels should stay as difficult as they were, or be a little harder. (Task K4.) DONE: the campaign curve's exponent is 0.79 (`data/campaign/campaign.tres`): City 1 and Golden 3 unchanged, every other level harder than before the Casino (the Marketplace +0.026 and +0.016, Corporate 1 +0.095). Open points: `docs/OPEN_QUESTIONS.md` §D, items 528–532.

- [x] The Casino's level names, *Brass Arcade* and *House Edge*, are approved.

- [x] The owner adds the Casino's song in a separate change (nothing to do here).

- [x] The Casino's glass ceiling is whole, and its signs use real lettering: "Gasket's House of Chance" and "The Brass Lotus". No pedestrians. (Task K3.) DONE: the vault has every pane; the two names are landmark casinos about every 100 m along the street, alternating, on their boards and on tall blade signs readable from a distance (`CasinoSkin.name_spacing`; 0 names every casino). Open points: `docs/OPEN_QUESTIONS.md` §D, items 525–527.

## Floating Head follow-up (October 9, 2026)

- [x] Keep the first bombing run as it is. In the next bombing run, instead of one target at a time, drop bombs on two to four spots at once, with one or two bombs on each. To keep it fair, the first spot in a salvo is closest to the player and each later one a little further away, so the player can see the path they'll have to take before the bombs are released. DONE (task E1g): both later runs (phases 2 and 3) drop salvos of 2–4 spots (`salvo_spots` in `data/bosses/city_boss_tuning.tres`: set the last number to 1 to keep the third phase's run as it was). Every salvo leaves a way through, checked at 3, 5 and 6 lanes. The open choices are in `docs/OPEN_QUESTIONS.md` §D, items 396–399.

- [x] Answers on the salvos: (1) increase the difficulty on five or more lanes; (2) make the spots tighter; (3) the later runs a little longer, for the longer salvos; (4) far spots the same colour. DONE (task E1g): on 5 and 6 lanes a spot takes up to three bombs side by side, placed so only one way through is left (`salvo_wide_lanes`, `salvo_wide_bombs`, `salvo_wide_choices`); spots 10 m apart instead of 12 m (`salvo_spacing`); later runs 6.5 s instead of 5.6 s (`later_run_seconds`), enough for two salvos of four spots; every target circle stays the same red at any distance (it was tinted by the City's purple fog far away).

- [x] The third phase keeps its salvos; three bombs per spot is okay; on five or more lanes a choice of two lanes is okay, and on 3 lanes the salvo is a forced path. DONE (task E1g): every street now places its spots to leave the runner as few lanes as possible: one lane on 3 lanes (one or two bombs a spot), a choice of two from 5 lanes (up to three bombs). Open questions 396 and 397 answered.

- [x] The spacing between spots is perfect; the later bombing runs can be 10 to 12 seconds long instead of 6.5. DONE (task E1g): 10 s (`later_run_seconds`): three salvos of four spots fit, the runs stay shorter than the first (11.2 s), and a flawless fight keeps its length (at 11 s it would miss a tower and run to about 134 s on 3 lanes, past the GDD's 120 s). Open questions 398 and 399 answered.

## Doodad pictures (October 9, 2026)

- [x] The doodads look like a jumble of squares and other 3D primitives. Keep each doodad a simple box, but draw on it pictures that look like the object, with the open-air parts transparent: the Marketplace's stall has a wooden base, supports in each corner and a little roof, and the middle where the goods are is air. What to draw in each zone is left to the build's recommendation. DONE (task G6b): every zone's doodads are picture cards painted by code (`tools/asset_gen/doodad_art/`, `tools/godot.sh doodads`); the looks chosen are in `docs/OPEN_QUESTIONS.md` §D, items 412–415 (all answered).

- [x] Answers on the doodad pictures: (1) no hint of which way a doodad pushes; (2) a rubble heap lower at its edges is fine; (3) the soft neutral edge sheen instead of the violet one is fine; (4) the looks that differ from the first doodads (drums, a van, a stall, a booth, a container, a column, a bus, the statue as the small one, a colonnade) are fine. DONE: recorded in GDD §3 (Zone doodads, their look); the `DESIGN-TBD` marker is gone.

## Gangland boss intro (October 9, 2026)

- [x] The intro cinematic for the Gangland boss (the Swarm Host), at ground level so we feel in the runner's shoes: the runner runs down the middle of the street between manhole covers; at 2 s one screech jumps out of a manhole and the runner easily avoids it; a second later three (two on one side, one on the other), which the runner dodges; a second later five on the left and six on the right, which the runner runs past; then more and more pour out, and drop from the sky out of view, landing and running beside the runner; soon a wall or wave of screeches chases the runner; as it gets closer, one cut to the mass: in a dark area inside it, a glint of the Host. DONE (task F2b): `SewerSwarmIntro` in Gangland's boss-intro slot (GDD §10; what the beat leaves open is open questions 387–395).

## Gangland outro (October 9, 2026)

- [x] A cinematic after the Swarm Host is beaten: the Host lying in the rubble; the screeches stay just a moment, sniffing at the Host, then scuttle away; the runner walks over; the Host trembles and hands the runner a golden key. Cut to a new scene with a sleek, flashy car not made before: angular, almost triangular, sleek and shiny, like a Lambo. The runner gets in and drives off into the distance, the camera at road level as it drives off. DONE (task F2d): `GanglandOutro` in Gangland's outro slot (GDD §6), with the car built by code (`SportsCarModel`) and six new sounds; what the beats leave open is in `docs/questions/f2d.md`.

- [x] (October 10, 2026) The runner's movement is stiff and unrealistic: make it more fluid and less choppy. While the runner gets into the new car, one shot where we see them getting in and, in the seat next to them, a screech sitting nice and cute on the seat. When the car drives off, it should be faster. DONE (task F2d): a walk of the runner's own (`CinePoses.walk`, its planted feet staying put), unhurried turns, eased arm moves and a pose for getting in (`CinePoses.get_in`); a shot from inside the car as the runner gets in beside a screech sitting up on the passenger seat like a pet (`CarPassenger`), which looks round at them, wriggles, lifts a paw and chirps (a new sound, `screech_chirp`; the pet look and its greeting were replaced the same day, next entry); the launch nearly twice as hard (24 m/s², up to 80 m/s). Recorded in GDD §6; the new placeholders are in `docs/questions/f2d.md`.

- [x] (October 10, 2026) The screech's look isn't quite right: its eyes are too big and it's hard to tell it's one of the same screeches. Make it look like the other ones, pretty much, but still have it sit there. When the runner comes in, the screech and the runner nod at each other, and then the car takes off. DONE (task F2d): the passenger is the screeches' own body and look, posed sitting up on the seat (`CarPassenger.sitting_meshes`); once the runner is sat, they look round at it, it nods with a chirp and they nod back, the door comes down and the engine starts, and the car launches. Recorded in GDD §6; the placeholders are in `docs/questions/f2d.md`.

## The Golden Convergence playtest (October 9, 2026)

- [x] Stage 2, The Magnate, is too hard to hurt and feels slower, duller and less dangerous than stage 1. (1) A new attack: he runs up behind the player and slashes at them with his claws, and the player has only a split second to dodge. (2) A new attack: TV screens on gold tentacles come crashing down from the sky on either side of the player, smashing lots of spots in lots of lanes, so the player has to dodge and weave; some of them hit The Magnate for chip damage. (3) The level gets about 30% darker once stage 2 starts, a sign he is losing control. DONE (task E5d-e), with the specifics the owner approved (GDD §10, The Golden Convergence, Owner's playtest): the Claw Slash (a red snarl and claw marks in the runner's lane, the swipe about half a second later; dodge by switching lanes; doubled in the last phase); the Screen Storm (10–16 screens over about 5 s, each spot marked by a red square and the screen's growing shadow about 0.9 s before it crashes, always a way through; about a third land on him, a storm taking about a quarter of a phase's health); the arena about 30% darker as measured on both renderers (`stage_two_light`); new beat scripts with shorter gaps, and green chevrons showing where to take off for the stomp. The open choices are in `docs/OPEN_QUESTIONS.md` §D, items 491–503.

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

## Owner's requests (October 8, 2026)

Task IDs refer to `docs/TASK_PLAN.md`, section H. The owner's answers to the orchestrator's questions are in brackets.

- [x] Sentinel wind-up time should be decreased by half. (H1: the warning goes from 1.2 s to 0.6 s.)

- [x] Sentinels and their background are too hard to see inside the arched recess: bring them a bit further forward so the player can see and make out what they are. (H1)

- [x] The attack sound of the Golden Zone's Resonator shouldn't sound like a doorbell: it should sound more like a crackling build of fire and a crashing wave. (H2)

- [x] The bottoms of Buzz Overdrive cuts in the floor should show a zone-specific background. (H3)

- [x] Only one enemy may fire at a time, which looks and feels unnatural: let two enemies fire at a time. (H4) [Owner: this is the cyborg-type guns' limit (cyborgs, window cyborgs, Barnacle Turrets): two bursts may be in the air at once. Big attacks of different types still take turns.]

- [x] Make doodads destructible by a dash. (H5)

- [x] The heli drone's explosion and all explosions in the game need to be more visually impressive: a yellow and red fireball. (H6)

- [x] Walls the player can dash through: not the side walls, but walls blocking the path forward, using the side walls' assets turned to face the player, like a building in the middle of the street. The player must dash through them; they crumble and explode into rubble when hit. Without the dash, the player takes one hit (armor, then shield; with neither, it kills). (H7a, H7b) [Owner: they block every floor lane but not the side walls, no ceiling shares their stretch, and they're introduced in the Corporate zone.]

- [x] Lasers auto-target host cyborgs, so players have to switch the laser off to avoid releasing Bad Dreams. (H8) [Owner: in normal levels; this reverses the September 26 rule that hosts are immune to weapons.]

- [x] Sleep Taker: when it makes the screen darker, things should get 50% darker than they already do (glowing things like gaps and lasers stay visible). (H9)

- [x] Sleep Taker: more hands, spread out along the street rather than all at the same spot, so the player has to make several quick lane switches to get through one round of the hand attack. (H9)

- [x] Sleep Taker: the side walls are too safe: many more gaps in the side walls, and hand attacks there too. (H9)

- [x] Sleep Taker: double the floor gaps. (H9)

- [x] The Tithe Collector should stay in the level twice as long. (H10)

## Owner's requests (October 10, 2026)

Task H11 in `docs/TASK_PLAN.md`. Open points: `docs/questions/h11.md`.

- [x] Sleep Taker: when the level gets dark, it gets about 75 to 100% darker than it does currently. "The player will be going down a completely dark tunnel, and the only thing that they will be able to see is the glow of the hazards and the glow of the attacks", without the other environmental cues. (H11: 90% darker, `dark_level` 0.0225 from 0.225; the street, walls and ruins read black on screen while every warning, hazard, pad, generator and the nightmare's maws keep their glow.)

- [x] Sleep Taker: the player character needs some glow so the player has a sense of where they are. (H11: as the light sinks the runner's pale rim light grows over its whole silhouette, beside its copper trim, and fades as the light comes back.)

- [x] Sleep Taker: the hands that come out of the ground should be greater in number and more frequent. (H11: rounds of three to six rows, from two to four; rows 0.7 s apart, from 0.85 s; hands on both walls every row; a single row where only that fits; attacks 0.8 s apart, from 1.3 s. Over a fight about 1.5 times the rounds and 1.2 to 1.6 times the hands.)

- [x] Sleep Taker: more gaps on the walls, to make it harder to dodge the main attack. (H11: about 33 wall gaps a minute, from 15, and the giant slash's approach no longer kept whole, so the wall isn't always there to take as it warns; the walls still stand under each refuge's bridge.)

- [x] Sleep Taker: about three times more gaps on the ground, to make the dark sections more of a challenge. (H11: about 2.7 times October 8's holes, six times the first build's rows; 0.7 s between holes and the other obstacles fits that many.)

- [x] Sleep Taker: get rid of the ceilings in the fight completely. Every three-lane slash came with a ceiling, which neutered the attack on PC; even on the phone there should be a side wall the player can run to. (H12: no ceilings or pads; each slash's stretch keeps its floor clear and one side wall standing from the warning to past the strike, the other wall keeping its gaps; that wall's lane stays clear until a wall run against the slash is over; the slash's reach now stops short of a wall runner.)

- [x] Sleep Taker: it ends almost too fast: two more chunks on the health bar, two more phases, no new mechanics, more hands a little more often, about 10% more in the first new phase and 20% more in the second. A fight over two minutes is fine. (H12: five phases at paces 1, 1.15, 1.3, 1.45 and 1.55, the last two with the third's attack list; on the same track the fourth and fifth bring 6–47% and 16–81% more hands than the third, depending on the lane count; four chunks torn away before the last EMP bursts it; about 139 s for a runner who never misses; par times 150 s for three stars, 190 s for two.)

## Owner's answers to the open questions (October 14, 2026)

- [x] (I9) **The boss armor pickup comes only after the armor takes a hit** (GDD §10, standard armor rule; item 483). A shield break no longer schedules it. This is a boss framework change (`BossEncounter._on_item_used`), so it's a T1 task: check every boss that uses the armor rule, at 3, 5 and 6 lanes. (DONE, I9: a hit on the armor, not a shield break, schedules the phase's pickup, for every boss; reason `armor_hit`; suite test_boss_armor_rule at 3, 5 and 6 lanes. Items 825–826.)

- [x] (I7) **Rebalance the economy for the full campaign** (GDD §7; `docs/OPEN_QUESTIONS_ANSWERED.md` item 16). The shop prices and the completion payouts (100 + 25 per campaign level) were set for a two-zone campaign. Rebalance them for all eight zones with `tools/measure/economy.gd`, so each upgrade first fits about where the campaign needs it. Prices and payouts live in data (`data/shop/catalog.json` and the tuning files). Keep the approved early-economy revision (October 3, 2026) and the laser I price (1,800 credits, first affordable at City 4) unless the curve can't hold them, and report the before and after. (DONE, I7: measured at each tier's line total (tiers are bought in order) on the full campaign with I4's treasure stashes: Armor IV 6,000 → 6,500 and the Heavy missile 9,500 → 7,000, everything else held, payouts held; the October 3 revision and Laser I 1,800 (first affordable after Gangland 1, the campaign's 4th level, which is how "City 4" was read) held. Before/after in `docs/architecture/economy-platforms.md`. Items 846–850; 848, the payouts, needs the owner.)

- [x] (I8) **An intro cinematic slot for every boss** (GDD §6; item 395). The City and Gangland have boss intros. Give the other bosses (The House, Hostile Takeover, the Beach's boss, the Sleep Taker, the Golden Convergence) an empty intro slot that the campaign skips until it's filled, so the owner can add their beats later without a structural change. (DONE, I8: The House, Hostile Takeover, Mecha Guppy and Captain Cogs, the Sleep Taker and the Golden Convergence each have an intro slot (`data/cinematics/<zone>_boss_intro.tres`, `skip_while_empty`) that the campaign skips while it has no scene; setting its `scene` brings it in, and old saves stay valid. The Marketplace has no boss. Debug builds' level select shows an EMPTY SLOT tile before each boss.)

## The owner's batch requests (October 14, 2026)

- [x] **The shop on mobile, and music on one iPhone** (I3). On the itch.io demo on a phone the shop is scrunched and hard to read. One playtester's iPhone played no music (the owner's iPhone did): look for a known bug, or say if it was likely the phone's settings. (DONE, I3: the web demo's menus are drawn larger on a phone (at least 0.65 CSS px a UI px), scroll when they must, with compact layouts for a short page, and a drag on a card scrolls; the page asks Safari to play through the silent switch, the likeliest cause; items 827–828.)

- [x] **Cyborgs 20% bigger** (I2; GDD §9.2). They're hard to see in the first zone. Draw them 20% bigger without changing their hitboxes, so they're easier to see but no harder. (DONE, I2: the Neon City's floor and window cyborgs are drawn 1.2 times bigger (ZoneSkin.cyborg_draw_scale in the City's skin), from their feet or waist; every hitbox and the bolts' start unchanged. Every other zone followed in J1, item 829.)

- [x] **Shader cleanup in every zone** (I1). An earlier session found unused or duplicated shaders in Zone 1 (`fca7f77`, City 1's load compiles 17 fewer shader programs) and removing them helped performance without changing the look. Check every other zone for the same gains and make them. (DONE, I1: no zone draws one shader code from two Shaders; the player's shadow, the screech lair's recess and the Floating Head's tower cut now share the glow shaders, and the speed lines one Shader: 5–11 programs fewer per zone on the web (City 1 135→130, the Palace 224→213), nothing drawn changes; suite test_zone_shaders guards every zone and boss arena. The big remaining saving, one street shader per zone, is task I11, item 830.)

- [x] **The Hover Truck lags on mobile** (I5; GDD §9.3). The truck that smashes in through the side wall and fires its cannon causes a big performance drop on a playtester's phone. Find and make performance improvements. (DONE, I5: the truck's light (the game's only real light) made the phone's renderer compile a second version of every shader in reach as it burst in, a 6–10 s frame on software GL; it is now two glow discs, and the truck is warmed up with the level. Worst frame of a visit about 85–160 ms. Not measured on a real phone. Two cinematics still have a real light each: task I12.)

- [x] **One hit from death** (I6; GDD §4). An audio and visual cue when the player has run out of all armor and shields; the sound is a two-tone siren. (DONE, I6: when the last armor and shield are gone, a soft two-tone siren plays once (698/494 Hz, 1.4 s, under every attack warning) and a red band along the screen's edges pulses twice with it, then stays dim until protection returns; steady with Reduced flashing; drawn under the attack markers. Items 832–835: listen to the siren.)

- [x] **Ceiling scenarios** (I4; GDD §3, Ceiling scenarios). Not in zones 1–2; sprinkled into later zones. (a) Pick the right pad: electric fences on a ceiling hit a player who takes the first anti-grav pad; a second pad further along avoids them. First one safe and one unsafe pad; later several pads, some safe and some not. (b) The treasure stash: a separate return pad partway along a ceiling drops the player into a stretch of floor walled off by doodads (for a stash in lane 3: a doodad at its start, and doodads in the two adjacent lanes), holding two or three of the highest-denomination credits. (DONE, I4: from Casino 1 a treasure stash: a downward return pad partway along a ceiling drops its rider into a doodad-walled stretch of floor with 2–3 credits of 100, at 5 and 6 lanes only (item 837); from Casino 2 a fenced ceiling: rows of pink fences under the hull catch the first pad's rider, a safe pad past them lands its rider beyond; from Corporate 1 several pads, some safe; none in zones 1–3; first-encounter hints. Stash credits don't count toward the stars (item 844). Items 836–845; 837 and 838 need the owner.)

## Mecha Guppy's phase 3 reworked (October 15, 2026)

- [x] The third and final phase of the Beach's boss: Mecha Guppy joins it on the right of the screen, Captain Cogs stays on the left. His attacks come at the player horizontally (along the lanes' width) instead of rolling down the lanes: barrages of slightly smaller bombs, some high (slide under) and some low (jump). Each bomb the player dodges hits Mecha Guppy, and the timer is replaced by a health bar, Mecha Guppy's. After some hits it goes under the water; when it reappears its splash causes the wave attack; after the wave it does its chomp bite (dodge or jump, depending on its size). The rest of the fight unchanged. DONE (task E5e-g): GDD §10 records it; 16 hits, a dive after every 4, the bombs from a swivel gun on the captain's stern castle with a red line at each bomb's height; the floor bites alternate leaving a lane and crossing every lane; placeholders answered "good as built" on October 16, 2026 (items 888-896 in `docs/OPEN_QUESTIONS_ANSWERED.md`).

## October 15, 2026 batch

- [x] **Cyborgs 20% bigger in every other zone** (J1; GDD §9.2). Draw them 20% bigger in every zone after the Neon City, as the City's were (I2): hitboxes unchanged. (DONE, J1: `cyborg_draw_scale` 1.2 in every zone skin and every boss-arena skin, so the Floating Head's drops and the Board's guards match; the City's boss skin was still 1.0. Model only. Look at the window cyborgs in the Marketplace, Casino, Corporate, Dead Zone and Palace facades once; item 829.)
- [x] **Five lanes on mobile, if it is safe for the frame rate** (no task). (TABLED, not built: no phone frame-rate data can be measured from the cloud, and the mobile economy, the missing 3-lane treasure stash and several boss fights are tuned around 3 lanes, with the GDD's "PC is harder" on purpose. Needs a try on a real phone first.)
- [x] **Wall-run-only gaps** (J2; GDD §3, §9). Some sections, especially in later zones and levels, where a gap spans the whole floor and the only way across is a wall run. (DONE, J2: from halfway into Marketplace 1 on, about 1.3–2.6 a level; every floor lane is a hole no jump or dash crosses, one side wall is lit with the ramps' green chevrons, a plain wall run (no claws, no wall hop) carries the runner onto a landing floor; a clear run-in, nothing on the wall, drones, Bad Dreams, Enforcer Trucks and Octodogs hold their attacks, grapple and revive saves end over the landing floor, a first-time hint. Not in the City, Gangland, boss arenas or quick play. Late zones get the fewest, the opposite of the request: items 864 (open), 863–874.)
- [x] **Beach boss: water in the shark's third-phase bite** (J3; GDD §10, Mecha Guppy). (DONE, J3: each chomp bite on the top in the reworked phase 3 now shows the sea at the bottom of its hole, in the same look as the water beside the top; phases 1 and 2 and the climb's chasms unchanged; look only. Items 875–877: does bright water still read as deadly.)


## October 16, 2026 batch

- [x] The Bad Dream should be able to hit the player on the ceiling. DONE (K1): it telegraphs and slashes a ceiling rider like a floor runner (lanes lit on the underside, same warning); fewer lanes where three would leave no way out; a ceiling rider is hit only after a 0.5 s settle and never into an ending ceiling. Questions 878-882.
- [x] Wall signs (black and yellow stripes) must not kill a player with armor: they take one armor hit instead. DONE (K3): armor (then the shield) takes a sign's hit with the usual invulnerability; the runner passes on through that sign. Without protection a sign still kills; trucks, walls and falls unchanged. Questions 883-884.
- [x] The Sentinels (golden knight statues, the enemy and the decorative ones) are too far back in the wall recess to see; bring them onto the wall, closer to the lanes. DONE (K2): both are a shallow relief flush on the wall face (89% of the live statue visible from 20 m, was 44%); the swing steps out of the wall; the owner approved the images on October 16. Questions 885-887.
- [x] The Marketplace's (zone 3's) intro cinematic: the runner walks up to one stall in a line of market stalls (the stall doodad), a citizen inside it (from the owner's reference picture, simplified); shows her a card with the Corporate boss's face, the camera zooming in on it, its writing scribbled; she waves her arms and mumbles (speech-like, no words); the runner nods twice and walks off; a cyborg walks up and talks to her, gruffer; she talks again and points after the runner; the cyborg waves other cyborgs over and they follow. DONE (F2f): `MarketplaceIntro`, 38.6 s; the card shows the Chairman (Hostile Takeover's man); four mumble sounds; staging questions in `docs/questions/f2f.md`.

## Gangland intro (October 16, 2026)

- [x] "Please build the following cinematic for the intro to zone two. We start at human height level behind the player character who has come to a fork in the road. He takes a look to the left where we cut to the following scene. We start with the camera at ground level panning up to show two cyborg gangsters with a large octodog in between the two of them. They are looking to their right. We pan over to the right to see another group of cyborg gangsters. This group has three cyborg gangsters that are in the zone two attire, another cyborg gangster that is in the zone three attire, and in the middle, slightly forward and leading the group, is a cyborg gangster with the casino attire or zone three attire. Behind these cyborgs is a hover truck. The camera pans back to show both the group on the left and the group on the right. They yell at each other, and the group on the right fires a shot that misses. The group on the left gets angry. Their octodog charges and starts to tackle cyborgs on the right, who then begin opening fire. The camera then cuts over to the player character, who then turns slowly to the right and starts walking down the other street. The player character should also put their hand up, their left hand up, over their face to kind of hide their face as they turn and start walking the other direction. It is okay if this goes 20 seconds." Task F2f.
  - DONE (task F2g): `GanglandIntro` plays in Gangland's intro slot (after the City outro, before Gangland 1), in place of the arrival flyover; 21.6 s. Review it with `res://tools/showcase/cinematic_review.tscn -- --slot=gangland/intro`. The beats are recorded in GDD §6 (Cinematics, "Gangland intro"). The staging choices it made (the fork as a T junction, "their right" read as the camera's right, the leader set apart only by its place and height, who the Octodog tackles, and the rest) are in `docs/OPEN_QUESTIONS_DEFERRED.md`, items 897–910.
- [x] "Add the Gangland title card as the player character walks away at the end." DONE (F2g): the zone's card ("ZONE 2", "GANGLAND") comes up 0.3 s after the runner starts walking away and holds 2.9 s, on into the fade to black.
