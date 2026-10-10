# Game Design Document — Checkpoint 1

**Working title:** TBD (placeholder: "Neon Runner")
**Status:** Design in progress. Everything below is DECIDED unless marked *(proposed)* or *(open)*. Open items are tracked in `OPEN_QUESTIONS.md`.
**Last updated:** September 26, 2026

**Owner-approved revisions (October 3-4, 2026):** the requests in [USER_REQUESTS.md](USER_REQUESTS.md)
take precedence where they differ from this historical checkpoint, including the four dash tiers
and armor protection against Barnacle Turret contact, plus simultaneous Sewer Swarm attacks and
dangerous, naturally colored wall crowds with local weak-point route clearance and a six-hit Host.
Current implementation and tuning details
are recorded in [ARCHITECTURE.md](ARCHITECTURE.md); the original design sections below are preserved.

---

## 1. Concept

A 3D endless-runner-style action game set in a neon cyberpunk future. The player runs forward automatically down a corridor and can use **three kinds of surface**: multi-lane floors, single-lane side walls they can briefly run along, and multi-lane ceilings (the undersides of ships, bridges, overpasses and buildings, depending on the zone) reached via anti-grav pads. Short, handcrafted-feeling levels (built by a rule-based generator) are grouped into visually distinct zones, each ending in a unique boss encounter. A shop between levels sells permanent upgrades and breakable protective items.

**Differentiator:** full use of floor, walls, and ceiling as play surfaces, each with its own rules and risks.

### Story (decided September 26, 2026)
- **A light story with little or no words.** It is told mostly through **environmental storytelling** in the zones, plus **5–15 second cinematics** between levels or between zones. The owner will describe the individual story beats later.
- **The runner is a silent protagonist** who is going to defeat the big bad. The game tells the player little more than that for now.
- **The final villain** is the all-powerful controller of this world. He is propped up by a **cult** that has grown in power over many years and controls a large share of the population and the companies. He is the final boss, in the Golden Zone (§5).
- **Bosses:** some are connected to the villain; others, such as the Sewer Swarm, are unconnected monsters that simply live in their zone.

---

## 2. Platforms & Business Model

| Platform | Store | Model |
|---|---|---|
| PC (Windows) | Steam | Paid up front. **No ads, no microtransactions.** |
| Mobile | iOS App Store + Google Play | Free with ads + optional in-app purchases |
| Web demo | itch.io; possibly Poki / CrazyGames (check each portal's rules on outbound links) | Free. Zone 1 including its boss, then a "get the full game" screen linking to Steam, App Store, Google Play. No ads, no IAP, no leaderboards. |

- **Engine:** Godot 4, **GDScript** (Godot 4 C# cannot export to web).
- **Development machine:** Windows, built with Claude Code.
- **iOS builds:** require macOS/Xcode → use a cloud Mac build service (e.g. Codemagic or GitHub Actions macOS runners). Needed only near release.
- **Approximate fees (verify at signup):** Apple Developer ~$99/yr; Google Play ~$25 one-time; Steam Direct ~$100 per app (recoupable).
- **Web and low-end Android use Godot's Compatibility renderer.** The neon look must hold up there (see §10).
- **Mobile monetization intent:** rewarded (player-chosen) ads such as revive or double rewards; avoid forced interstitials between levels *(proposed; see open questions)*.
- **Mobile orientation: landscape** (decided September 26, 2026). HUD, menus and the shop are laid out for landscape on every platform.

---

## 3. Play Space & Controls

### Axes
- **Z:** forward (auto-run).
- **X:** lanes on floor and ceiling.
- **Y:** height, meaningful especially on side walls.

### Floor
- **Lanes:** 3 on mobile; 5–6 on PC *(exact PC count open)*.
- **Lane switch:** left/right arrow keys (PC) or swipe left/right (mobile). The switch is animated; the player is physically between lanes mid-switch.
- **Jump:** swipe up on mobile *(PC key open)*.
- **Slide:** swipe down on mobile; down arrow on PC.

### Side walls (building faces)
- **A single lane** on each side.
- **Free entry:** move past the outermost floor lane to jump onto the wall, unless a **sign** blocks that section.
- **Entry grace:** wall entry follows the same grace rule as jumping. It still works just after running off an edge (the jump grace window), but not once the player is already falling into a gap.
- **Ramps:** a boosted entry. Hitting one launches the player higher on the wall and adds speed and a score multiplier. The speed boost fades away the same way a speed pad's does (decided September 26, 2026; the build's placeholder had no boost).
- **Slide:** the player slides downward over **2 seconds**, then drops to the floor.
- **Height:** matters for collision. Timing of entry decides whether you pass above or below a hazard.
- **Wall jump:** pressing jump while on a wall leaps back out toward the lanes.
- **Wall hop** (owner's playtest, October 9, 2026): jumping off a wall and straight back onto it starts a fresh wall run, so a skilled player can stay on a wall **as long as they like**. The owner likes it: it's a move players are meant to discover for themselves, and it **must not be patched out**.
- **Signs:** block wall entry, and colliding with one causes damage. A blocked entry plays a metallic clank **and a small sideways bump**, so the player sees why they didn't get onto the wall (decided September 26, 2026).
- **Vents** exist **only at the bottom of walls**, which punishes lingering (see Sewer Screech).

### Ceiling (city: undersides of low-flying spaceships)
- **Reached** by stepping on **anti-grav pads** in floor lanes, which flip gravity.
- **Lanes:** the ceiling has lanes, but the hull must look like a ship: no large gaps between lanes.
- **Duration:** the player stays on the ceiling until the ship's hull ends, then drops back down.
- **The floor beneath may be dangerous** (changed September 26, 2026, replacing the September 25 rule that kept it clear). The ceiling is a way to **escape the danger on the floor**, so the floor under a ceiling may hold gaps, hazards and enemies.
- **Safe landing zone:** wherever the player drops from a ceiling back to the floor, the floor is always safe to land on.
- **Every zone has ceilings** (decided September 26, 2026). What forms them changes from zone to zone (see §5). The in-world reason for a ceiling is up to each zone's skin: anything that makes sense in that zone's fiction (ships, building undersides, bridges, elevated roads, floating ads, archways).
- **Ceilings don't have to cover every lane** (decided September 26, 2026). The player can switch lanes only within the ceiling's width. A **one-lane ceiling** is simply ridden out, so it must be **very short and relatively safe**.
- **The ceiling is never required:** the floor route under a ceiling is always survivable without taking the pad. The ceiling is the easier route (decided September 26, 2026).
- **Ceiling hazards** (decided September 26, 2026): ceilings may carry hazards of their own, but none in zones 1–2 *(proposed; owner agreed)*. The first is the **Barnacle Turret** (§9.8), introduced in the Marketplace.

### Collision rules (core principle)
- **Damage only on real contact.** Lanes determine movement, not hits. A bullet in your lane that doesn't touch you does not hurt you.
- **What looks like a hit is a hit, on every surface** (decided September 26, 2026): if the character's body takes up the same space as a hazard or enemy, the player is hit, even on a wall. For example, a player low on a wall whose body reaches into the outer lane can hit a fence there. Enemies whose rules say a wall runner is safe (such as Buzz Overdrive) keep their hitboxes inside their own lane, so they never touch one.
- **Forgiving hitboxes:** damage hitboxes are slightly **smaller** than visuals, erring in the player's favor.

### Other inputs
- **Juggernaut dash:** tap anywhere (mobile) *(PC key open)*.
- **Slow time:** **E** key, **PC only**.
- **Settings menu:** audio volume and **full key rebinding**.
- **Controllers:** stretch goal. All input must go through Godot input actions from day one so it's cheap to add later. Steam Deck is a target of opportunity.

### Pace and busier levels (owner's playtest, September 30, 2026)
- The game should feel **edgier, flashier and more action-packed**. After playing every zone, the owner found that the runner and the enemies felt slow, even though the levels were hard.
- **Run speed rises zone by zone:** about **21 m/s in the Neon City** (it was 18 m/s everywhere), rising to about **25 m/s in the Golden Zone**. Enemies and their attacks speed up to match.
- **Speed effects** add spectacle: the camera widens at speed, speed lines, camera shake, sparks, and a brief freeze on kills. All of them honour Reduced flashing.
- **Busier levels:** more gaps, obstacles and enemies than the first build had (to an extent), so there is always something going on.
- **Zone doodads:** scenery pieces standing in lanes, specific to each zone.
  - The Neon City: pillars, small buildings and tiny market stalls.
  - Gangland: burned-out cars and broken-down shops.
  - The Marketplace: plenty of plants and casino machines.
  - The other zones' doodads follow each zone's look.
  - They never hurt. Running into one **pushes the player into a neighbouring lane**: the side with room, or, if both sides have room, a side chosen per doodad (the same on every attempt).
  - **Their look** (owner, October 9, 2026): each doodad stays a simple box with a picture of the object drawn on it, and the parts that are open air are see-through (a stall's open middle between its counter and its little roof, a van's empty windows, the bays of a colonnade). Never a jumble of shapes. The looks, approved the same day:
    - The Neon City: a street vending machine or a pillar covered in posters (small), a street-food stall (medium), a little shop with a roll-down shutter (large).
    - Gangland: a stack of rusted oil drums (small), a burned-out van (medium), a broken-down tin shack with a half-open shutter (large).
    - The Marketplace: a potted palm or a flowering bush (small), a vendor's stall with a wooden base, a post in each corner, a striped little roof and its goods in the open middle (medium), a bank of slot machines back to back (large).
    - Corporate: a steel planter with a trimmed shrub (small), a glass security booth (medium), a military supply container (large).
    - The Dead Zone: a broken concrete column (small), a rubble heap (medium), a burned-out bus (large).
    - The Golden Zone, outdoors and in the Golden Palace: a robed statue on a plinth or a gilded urn with a shrub (small), a wall fountain (medium), a colonnade with red drapes (large).
  - A doodad doesn't show which way it will push (owner, October 9, 2026: no hint needed).
  - Its outline may dip below the full height at its edges (the rubble heap) as long as its middle stays high, so it still reads as too tall to jump. Doodads are lit like the street around them, with no coloured edge glow.
  - *(Proposed:)* a push never lands the player on a gap or a hazard, and it costs nothing else.
  - **The dash smashes a doodad** (owner, October 8, 2026): dashing into one breaks it apart, and the player keeps their lane with no push and no damage.

---

## 4. Failure, Death & Revive

- **One hit ends the run**, unless protected by armor or a shield.
- **Falls:** into gaps between trucks or holes in the street, within a lane. Switching lanes into a lane that has a gap under you = fall. Lane switching itself is safe.
- **Invulnerability:** after armor or a shield breaks, the player gets about **1 second of invulnerability** (character flashes).
- **Free armor** (owner's playtest, September 30, 2026): every level and boss fight starts with armor, and after it breaks it **comes back 30 seconds later**. The armor in the shop becomes an upgrade to it (§8).
- **No checkpoints.** Levels are short (**90–150 seconds**). Death restarts the level.
- **On death, and when quitting a level from the pause menu, the player keeps 20%** of credits collected during that attempt (quitting decided September 26, 2026, so deliberately dying never pays better than quitting). Completing a level always pays far more, so deliberate dying is never profitable.

**Death flow:** Death → revive offer (mobile: rewarded ad or revive item; PC: revive item) → run summary → shop → retry.

---

## 5. World & Zone Skin System

Gameplay uses **abstract pieces**; each zone supplies a **skin** that decides how they look.

| Gameplay piece | City zone | Gangland zone |
|---|---|---|
| Floor segment | Roofs of trucks driving **toward** the player | Stretch of street |
| Gap | Space between trucks | Hole or crater in the road |
| Obstacle mount point | Truck cab or mid-roof | Barricade, wreck, rubble |
| Wall section | Building facade with signs | Bombed-out building face |
| Ceiling section | Underside of a low-flying ship | Underside of decaying or bombed-out buildings, overpasses and similar |

**Zone order** (decided September 26, 2026): **Zone 1 is the Neon City** (the web demo zone) and **Zone 2 is Gangland**. The remaining zones are still to be designed with the owner; the build keeps empty slots for them.

### Zone roster (decided September 26, 2026)
**Every zone is set in the same future, vaguely cyberpunk world.** No zone looks historical: the Marketplace is not a medieval market. Zones may be dustier or dirtier than the Neon City, but they stay futuristic.

**Seven zones** at launch, in the order below. Each zone has 1–3 levels, never more than 3; see the schedule at the end of this section. The **Casino** was added as Zone 4 by the owner on October 8, 2026, between the Marketplace and Corporate; the zones after it moved down one place.

| # | Zone | Mood (reference) | Palette |
|---|---|---|---|
| 1 | **Neon City** | Blade Runner | Keep the current city skin |
| 2 | **Gangland** | Mad Max, but in a cyberpunk setting | Browns and tans |
| 3 | **Marketplace** | A bustling, happy market | Tan, with livelier colours: whites, blue awnings, splashes of colour in shop signs and visible products |
| 4 | **Casino** (owner, October 8, 2026) | A covered casino street at night: gaudy, warm and a little seedy (reference: `docs/art/reference/casino_zone.webp`) | Dark iron and aged brass, warm lamplight and haze, a vaulted glass roof; its neon kept to the colour rule below |
| 5 | **Corporate** | A more oppressive Blade Runner, with corporate and military themes | Steel and gunmetal grey, military olive, cold and sterile white light, and one harsh brand colour (chosen by the art agent, away from the hazard colours) |
| 6 | **Dead Zone** | Eerie, quiet, haunting | Dark black, dark grey and ash grey |
| 7 | **Golden Zone** | Decadent opulence | A white and slightly creamy base with red and gold accents. There must be some gold to show the wealth, but it isn't the only colour. |

**Zone 1: Neon City.** Floor: roofs of trucks driving toward the player; gaps between trucks. Walls: building facades with signs. Ceilings: undersides of low-flying ships.

**Zone 2: Gangland.** Lived in: graffiti and plenty of signs of life. Gangs compete for power there, and some are directly funded by corporate and military interests. Floor: a street, with holes and craters as gaps. Walls: bombed-out building faces. Ceilings: undersides of decaying or bombed-out buildings, overpasses and similar.

**Zone 3: Marketplace.** An open-air market, dustier and dirtier than the city: commercial buildings, lots of signs, casinos and shops. Floor: stall roofs and awnings, with gaps between the stalls *(proposed; owner agreed)*. Ceilings: undersides of buildings, bridges and overpasses, a few ships, and floating advertisements.
- **Citizens:** interesting and funny citizens are **scenery only**, not real 3D characters or anything the player interacts with. They are seen inside the shops along the low part of the walls, as animations that play. They may react to the runner passing (startled, cheering, happy); the goal is to be funny or uplifting.
- **Conditions:** they are added only if they don't noticeably cost performance on mid-range phones and don't add much code complexity.

**Zone 4: Casino** (owner, October 8, 2026). The casino district the market street leads into: a long covered street lined with casinos, under a vaulted roof of glass and iron, with brass pipes running along the walls, stacked balconies, hanging banners and casino signs everywhere (the owner's reference image, `docs/art/reference/casino_zone.webp`).
- **Only the scenery is new:** the zone's walls, floor, ceilings and background. It **reuses the Marketplace's enemies and characters** as they are (the Casino Mob Enforcer cyborgs, its heli drones, hover trucks and the rest): no new enemy, cyborg, vehicle or character looks.
- **Two levels, then The House** (§10), which moves here from the Marketplace.
- Floor, gaps and ceiling pieces: chosen by the art agent from the reference *(to confirm)*.
- **The glass roof is whole** (owner, October 9, 2026): no broken or missing panes.
- **Two named casinos** (owner, October 9, 2026): their big signs carry real lettering, **"Gasket's House of Chance"** and **"The Brass Lotus"** (the names in the reference image). No pedestrians on the street; the Marketplace's citizens in the shop windows are enough.
- **Music:** the owner supplies the Casino's song (October 9, 2026).

**Zone 5: Corporate.** Close to the Neon City, but plainly corporate. Corporations and the military are intertwined, so there is a visible military presence. Generic, soulless corporate art. Floor: roofs of maglev trains or plazas *(proposed; owner agreed)*. Ceilings: undersides of buildings, bridges and similar, and occasionally a military ship.

**Zone 6: Dead Zone.** A blackened, bombed-out husk of the city: rubble, embers, smoke and silence, with not much life. Fires are kept minimal. Floor: a rubble street *(proposed; owner agreed)*. Ceilings: only the remains of the destroyed city, such as the undersides of dead buildings and crumbling, charred grey bridges. **The Cyborg's Bad Dream first appears here.**

**Zone 7: Golden Zone.** The city strictly for the elites and corporate bosses, and home of the final boss. The cult is felt everywhere, alongside an extravagant show of opulence and wealth. Floor: golden walkways over water *(proposed; owner agreed)*. Ceilings: undersides of golden bridges, golden archways and other decadent structures.
- **Water:** flows off the sides of the ceilings as waterfalls or fountains. It is **scenery only**, kept sparse, and thinned out if it clutters the view.
- **Final level: the Golden Palace.** The player runs **inside** the palace, which is so huge and grand that its interior is basically the size of a city. It plays like any other level; only the skin is an interior (floors, walls and ceilings are the palace's own halls, galleries and arches). The final boss follows it.

**Colour rule for every zone** *(proposed)*: zones may use colours close to hazard colours (red and gold in the Golden Zone, blue awnings in the Marketplace, fire in the Dead Zone), but only as **non-glowing** materials or dim background elements. Only hazards glow in hazard colours, so pink, yellow and black, red, orange, green and cyan keep their meaning everywhere.

### The cult (decided September 26, 2026)
- The cult is so widespread that it is **the reason the gangsters and cyborg gangsters attack the runner** in the first place.
- **What makes it insidious:** people are completely subservient to its philosophy without realizing that they're in a cult.
- **Symbol and colour** (owner, September 26, 2026): the **Convergent Triad**, option B of the options drawn in code (`tools/showcase/cult_emblem_sheet.tscn`): three notched arrows converging on a small centre point, with three-fold symmetry. At a glance it passes for a generic corporate "sync" or "alignment" mark ("every path leads to him"). In glowing ads it is a warm white, never a hazard colour; unlit it is brushed bronze; in the Golden Zone it is polished gold meeting at a small red centre stone.
- *(Proposed)* **Hidden in plain sight:** the symbol is worked into logos, ads and corporate art in every zone, and is displayed openly only in the Golden Zone.
- **Cyborg Viewing Devices** (decided September 26, 2026): the cult's philosophy reaches people **through their screens**. The more devoted someone is, the more of their face the device replaces, until the screen *is* the face: that's what the cyborg gangsters are. The order to attack the runner reaches them the same way, through the feed. Told purely through the environment and the cyborgs' look (no words): screen heads on the enemies, the same feed playing on billboards and in shop windows, and glitching screens on hosts, whose feed the Bad Dream has corrupted.

### Level schedule and enemy introductions (decided September 26, 2026)
**Every zone introduces at least one new enemy,** except the Casino, which reuses the Marketplace's (owner, October 8, 2026). New enemies are preferred over new mechanics. Anything introduced earlier keeps appearing later. Each level introduces about one new thing.

| Zone | Level (name) | New in this level |
|---|---|---|
| 1. Neon City | 1 · Rooftop Rush | The basics (gaps, fences, walls, signs), then basic cyborgs late in the level |
| | 2 · Skyway | Ceilings and anti-grav pads |
| | 3 · Neon Crossfire | Pulsing fences, window cyborgs and the **hover truck** |
| 2. Gangland | 1 · Scrapyard Streets | **Sewer screech** (from manholes) and ramps |
| | 2 · Dog Run | **Octodog** and speed pads |
| | 3 · Rotor Wash | Fence generators and **heli drones** |
| 3. Marketplace | 1 · Awning Alley | The **Barnacle Turret** (§9.8), the first ceiling hazard |
| | 2 · Shopfront Sparks | **Wall fences** (§9.1), plus screeches from wall vents in the shopfronts *(proposed)* |
| 4. Casino | 1 · Brass Arcade | Nothing new: the Marketplace's enemies and mechanics in a new setting (owner, October 8, 2026). What each Casino level adds is still to design *(to confirm)* |
| | 2 · House Edge | Then **The House** (§10) |
| 5. Corporate | 1 · Maglev Line | **Buzz Overdrive** (§9.9) |
| | 2 · Checkpoint Plaza | The **Tithe Collector** (§9.12) and the **Enforcer Truck** (§9.13, owner, October 4, 2026), with a heavier military presence *(proposed)* |
| 6. Dead Zone | 1 · Ashfall | Hosts and the **Cyborg's Bad Dream** |
| | 2 · The Hush | A quiet, eerie remix: **fewer enemies but more hosts and Bad Dream chases, darker lighting, and long silent stretches broken by sudden threats** (decided September 26, 2026) |
| 7. Golden Zone | 1 · Gilded Canals | The **Resonator** (§9.10) |
| | 2 · Sentinel Row | **Gilded Sentinels** (§9.11) and peak difficulty *(proposed)* |
| | 3 · Golden Palace | The **Golden Palace**, then the final boss |

Level names approved by the owner (September 26, 2026; the Casino's on October 9, 2026).

**Skies show progression** (owner, October 8, 2026). Most levels keep their zone's sky; a few change it, so the player sees time passing and what lies ahead:
- **Neon City 1:** the sun just starting to rise, with pinks and purples touching the undersides of clouds. *(Moved from City 3, which fits it less well thematically; City 2 and 3 keep the dark night sky.)*
- **Gangland 3:** a cloudy, blood-red sky, warning that a fiery stretch lies ahead.
- **Marketplace:** a darkening sky as the sun sets, with deep blues and pinks at the very bottom of the sky. The owner asked for it on the zone's third level; the Marketplace has two (the owner kept it at two when adding the Casino, October 8, 2026), so it is on **Marketplace 2**, its last (confirmed by the owner, October 9, 2026).
- **The boss fight after a level keeps that level's sky** (the Sewer Swarm under Gangland 3's; The House, which follows Casino 2 since the Casino was added, under the Casino's own sky). *(Proposed)* So does the boss's intro between them (the Sewer Swarm's), so the sky holds from the level to the fight.
- **The street's light follows the sky** (dimmer and pinker under the sunset, redder under the blood-red sky, a touch of pink at dawn). The sky, the distant haze and the scenery's light change; hazards, the runner and the enemies keep their colours and light, and the sky never glows. *(Proposed)* A boss built like the street (The House's cabinet, the Swarm Host's body and pipe) is lit like it, as a level's darkness already lights it; its glowing parts (weak points, reels, buttons, warnings) keep theirs.

**17 levels plus 6 bosses** (the Marketplace has no boss since the Casino was added; owner, October 8, 2026). A flawless run through every level takes about 40 minutes. With retries and bosses, a first playthrough is estimated at 60–90 minutes.

**Rules:**
- Identical gameplay behavior under every skin.
- **Obstacles and enemies must be recognizable across zones by color and shape.** For example, pink crackling energy always means electric fence.
- On still streets, add motion effects (debris, speed streaks, camera shake) to preserve the sense of speed *(proposed)*.

---

## 6. Structure, Progression & Replay

- **Zones:** 7 at launch, each with a distinct look (see §5).
- **Levels:** 1–3 per zone, each 90–150 seconds.
- **Bosses:** one at the end of each zone, except the Marketplace, which leads straight into the Casino (owner, October 8, 2026). Each boss is its own scripted encounter and scene, but **plays as close to the main runner as possible** (refined September 26, 2026; see §10). The build leaves a slot for each.
- **Cinematics:** short, minor cinematics between levels and zones give a sense of progression (decided September 26, 2026). Content comes later; the build leaves slots for them.
  - **Zone 1 outro** (owner, October 8, 2026): the Floating Head crashes to the ground. The camera comes down from its usual place, a little above and behind the runner, to the runner's level. The runner is running, stops, and looks to the left: a **barricade guarded by many enemies**, all reusing the game's own assets. **Barnacle Turrets stand on the floor** instead of the ceiling, so they look like cannons, with a **row of five cyborgs**, **one of the battle trucks** behind them, and a **heli drone** above it. The camera pans back to the runner, who is startled by so many enemies and runs the other way. The runner **jumps off a truck**, an **explosion** goes off behind them, and they **land in Gangland**. Built in task F2a; the staging choices made to fill in these beats are open questions (`docs/OPEN_QUESTIONS.md` §D, items 369–381).
  - **Gangland boss intro** (owner, October 9, 2026): see §10, Sewer Swarm ("Intro cinematic"). Built in task F2b; the staging choices made to fill in the beat are open questions (`docs/OPEN_QUESTIONS.md` §D, items 387–395).
  - **Dead Zone intro** (owner, October 9, 2026): it opens on a **smoking crater** in the Dead Zone's ground that **looks like a gap**, with the runner **lying on the ground inside it**. After a moment the runner **shakes themselves** and starts to pull themselves out. A **cut to ground level**: at first only the runner's **hands grabbing the edge** of the crater, then they **pull themselves up**. Throughout, **cyborgs can be seen in the distance**: **two lying on the ground, motionless**, and a **third crouched over them**, and we can't tell whether it was eating them or what exactly it was doing. As the runner pulls themselves up, the crouched cyborg **looks over**: it is a **host** (§9.7, the Cyborg's Bad Dream). A **cut to an extreme close-up of its glitching face**, looking menacingly at the camera, then a **fade to black**. The owner's answers on the staging (October 9, 2026): a cut to a **medium shot** of the host first, then the **extreme close-up**, with the host's **entire face filling the screen**; the **zone's title card** appears in the close-up **as it starts to fade to black**; the crater **has a floor** the runner lies on; the host's ambiguous crouched work over the bodies stays; **what put the runner in the crater is shown in a cinematic before this one** (its beats to come). Built in task F2c; the staging choices still open are in `docs/questions/f2c.md`.
- **Estimated first playthrough:** roughly 20–50 minutes. This is a known risk for a paid Steam game (Steam's refund window is 2 hours of play), so replay value is critical.
- **Levels are built by a rule-based generator** from obstacle and enemy patterns plus a difficulty value, fitted to the device's lane count.
  - **Campaign:** fixed seeds (same layout every attempt).
  - **Endless mode:** random layouts.
  - Each level's difficulty can be tuned individually, with an automatic curve making each level slightly harder than the last.
  - **No level gets easier when levels are added** (owner, October 9, 2026, after adding the Casino): every level is too easy, at least on PC. The Marketplace keeps at least the difficulty it had (a little harder is welcome), and Corporate and the zones after it may get harder.
  - Because lane counts differ, "level 5" on PC is not identical to "level 5" on mobile. This is intended: PC is harder.
  - Handmade set pieces (e.g. boss arenas) are allowed.
- **Replay features:**
  - Star ratings or grades per level
  - Harder difficulty tiers after completing the game
  - **Endless mode** (decided September 26, 2026). **Deferred** (owner, September 30, 2026): the campaign comes first, and endless mode is revisited once the campaign is done.
    - It runs **until the player dies**, with no time limit, and its difficulty keeps climbing.
    - Its scenery **cycles through the zones the player has unlocked**, changing every few minutes.
    - It pays **20% of credits collected, like a death, plus a lump sum every 2 minutes survived**, so lasting longer pays off.
    - Not in the web demo.
  - Leaderboards
- **Leaderboards:** separate per platform (Steam, Game Center, Google Play Games), per level and per difficulty tier.
  - Plus a **net worth** leaderboard: credits earned in play and never spent. Purchased credits are tracked separately and never count.
  - No leaderboards in the web demo.
- **Enemy scaling:** many enemies scale gradually across levels (fire rate, projectile speed, health, extra attackers): barely noticeable early, clearly harder at the end.
- **Introducing mechanics:** one new object or enemy type at a time. Zone 1 teaches lanes, jump, slide, and walls; ramps and speed pads arrive a few levels later.

---

## 7. Economy: Score & Credits

- **Credits** are scattered across floor, walls, and ceiling in **several clearly distinguishable denominations**.
- **High-value credits sit in risky spots:** gap edges, next to enemies, near hazards, far along wall runs.
- **Wall-hop credits** (owner, October 9, 2026): a gentle nudge toward the wall hop (§3). Some long walls carry **high-value credits further along than one wall run reaches**, so only a player inventive enough to wall hop collects them. *(Proposed)* From Gangland on, about once a level, on a stretch of wall long enough with no wall gap.
- **Each run produces two numbers:**
  1. **Level score:** credits collected plus bonuses (enemy kills, ramp multipliers, etc.). Feeds stars and level leaderboards. **Never spent.**
  2. **Credits earned:** added to the wallet and spent in the shop.
- **Mobile:** credits can also be bought with real money. These are tracked separately and excluded from the net worth leaderboard.
- **Key balancing value:** how fast credits are earned relative to shop prices. On mobile this governs whether purchases feel optional or forced.

---

## 8. Shop & Power-ups

The shop appears between levels and after every death.

### Permanent (buy once, keep forever)

| Item | Behavior | Upgrades |
|---|---|---|
| **Weapon line** | Fires **automatically** at the nearest valid target. Enemies show **health bars**. | **4 tiers:** 1) Laser; 2) Enhanced laser (new color, slightly thicker, more damage); 3) Missile (more damage); 4) Heavy missile (new look, large damage, **splash damage**, bonus damage vs swarm boss) |
| **Claws / skates** | Longer wall-run time; **kill any enemy on contact, everywhere**. Beat spines and tentacles. | *(open)* |
| **Juggernaut dash** | Tap-triggered; barrels through enemies and obstacles. Uses a **cooldown**. | *(open)* |
| **Magnet** | Automatically pulls in nearby credits. | Radius upgrades, **hard cap at the player's lane plus adjacent lanes**; never pulls credits from another surface (floor ↔ wall ↔ ceiling). |
| **Slow time** | **PC only**, E key, cooldown-based. | *(open)* |
| **Armor** (changed September 30, 2026; it was a breakable) | Free at the start of every level and boss fight. Blocks one **enemy attack or electrical hazard**; does NOT block solid collisions (signs, trucks, walls) or falls. After it breaks it **comes back 30 seconds later**. | Tiers **alternate** between one more hit before it breaks and a shorter wait before it comes back *(numbers open)*. |

### Breakable (break when used, then buy again)

| Item | Behavior |
|---|---|
| **Shield** | Blocks **one hit of anything**. More expensive than armor. |
| **Grapple hook** | Saves the player from **one fall**, then breaks. |
| **Revive item** | Revives on the spot. On PC it's the only revive; on mobile, revive is by rewarded ad or this item. |

### Rules
- **Power-ups stack** (e.g. weapon + shield + armor at once).
- **No loadout slots.** Power is kept in check by:
  - Cooldowns
  - The generator assuming an expected loadout per zone
  - Bosses ignoring claw contact kills (only weak points or weapons damage them)
- **Equip toggle:** in the shop, players can switch any owned item on or off (challenge runs, net worth play, balance safety valve).
- **Bosses may grant power-ups** before the fight. **Every boss must be beatable using only what the game grants.**
- **Deferred to post-launch:** throwable dog bone (distracts Octodogs).
- **Ramps** give speed and score. Immunity comes from items, not ramps *(proposed)*.

### Damage reference (shots to kill)

**Laser tier 1** (owner's playtest, September 30, 2026): it has a **shorter range**, and every enemy except the sewer screech takes **two more tier-1 shots** than before. Higher tiers keep their numbers. The tier-1 numbers in this table and in §9 include the change.

| Target | Laser tier 1 | Missile tier 4 |
|---|---|---|
| Hover truck | 17 | 5 |
| Heli drone | 17 | 5 |
| Octodog | 7 | *(scale)* |
| Sewer screech | 1 | 1 |
| Cyborg | *(open)* | *(open)* |

---

## 9. Enemies & Obstacles

**Big attacks take turns** (decided September 26, 2026): the major attacks of different enemy types never overlap (for example, a drone barrage never lands during a hover truck's lurch or cannon shot), so the player never has to dodge two big attacks at once. The owner found early playtests not very challenging, so this may be reverted after playtesting.

Shared interaction rules apply unless stated otherwise:
- Armor blocks enemy attacks and electrical hazards.
- The shield blocks anything.
- Claws kill on contact.
- The juggernaut dash smashes through.
- Any hit is followed by the brief invulnerability window.

### 9.1 Electric Fence (obstacle, early)
- **Look:** pink crackling energy barrier built into the truck, powered from futuristic exhaust pipes. Other zones use their own skins (e.g. strung between rubble or wrecks) but must still read as "pink crackle = fence."
- **Placement:** at the cab, mid-truck, or elsewhere. The generator avoids putting a fence right against a gap unless it's deliberately building a combined jump.
- **Variants:**
  - **Full-height:** jump over or switch lanes.
  - **Gapped:** visibly open at the bottom; slide under.
  - **Behavior:** each variant comes in an **always-on** and a **pulsing** (on/off timing) version.
- **Passing through:** the shield, armor, and juggernaut get you through. Claws don't.
- **Weapons:** cannot destroy fences, and auto-fire ignores them.
- **Generators:** occasional; **most fences have none**.
  - Destroyed by a **stomp** or the **dash**. **Weapons never set one off** (decided September 26, 2026): auto-fire never targets generators and missile splash never damages them, so an EMP is always the player's choice. (Hosts had the same rule until October 8, 2026; weapons now hit them, §9.7.)
  - Sends out an **EMP** that disables fences within a short radius for the rest of the level *(assumed duration)*.
  - The EMP also dissolves the Cyborg's Bad Dream.
- **Wall fences** (owner, September 26, 2026; first appear in Marketplace 2 *(proposed)*): electric fences that **span a side wall** and **turn off and on** from time to time, to make the walls less safe.
  - *(Proposed)* The same pink crackle, strung across the wall-run path between emitters on the facade, the way a floor fence crosses a lane. They follow the level clock with the same flicker and crackle before switching on.
  - **Variants** (decided September 26, 2026): **full-height** wall fences, passed by timing, from Marketplace 2. From the Corporate zone, **partial** wall fences also cover only the low or the high part of the wall, and are passed by entering the wall high or low.
  - The same rules as floor fences: armor, the shield and the dash get you through, claws don't, weapons can't destroy them, and a generator's EMP switches them off.
  - *(Proposed)* Fairness: never where a ramp launches the player into one while it's on, and never on the same wall section as a sign or a window cyborg.

### 9.2 Cyborg (early; scales through the campaign)
- **Look:** humanoid.
  - **Face:** an **LED visor/screen face** showing simple expressions.
  - **Base look** (redesigned September 26, 2026): a **ragged, strung-out gangster**, based on **Variant 1, the "Static TV Head" Infiltrator**, of the owner's concept sheet `docs/art/reference/cyborg_viewing_devices.jpg`. Build brief: `docs/art/BRIEF_CYBORG_GANGSTER.md`.
    - **One body:** a worn leather vest over a hoodie, torn layers, patched cargo pants, boots, and a backpack cabled into the head, with a gaunt, twitchy posture. One scavenged cyber arm is the arm cannon.
    - **The entire head is a beat-up CRT television** whose screen is the LED face, showing expressions readable on small screens. No hair, face or mask.
    - **Colours:** grimy khaki, olive, brown and grey clothing; dull rusted steel and gunmetal (no gold or brass, which belong to the player). The only glows are the **cold white LED face**, the arm cannon's **red** charge-up, and on hosts only, **purple** (glitching screen and glowing veins). No hazard or "safe" colours anywhere else.
  - **Used everywhere:** this base replaces the sleek city citizen and the patched scavenger in every zone, including the Neon City. It is also the model **every zone variant is derived from**.
  - **Zone variants** (decided September 26, 2026). They are **the same unit**: identical behaviour, attacks and hitboxes, and looks that differ only enough for the player to tell they fit the zone. Build brief: `docs/art/BRIEF_CYBORG_GANGSTER.md`, "Zone variants".
    - **Neon City:** the base (Static TV Head).
    - **Gangland:** Variant 3, the **"Broadcast Brute" Enforcer** (a caged screen head with side monitors, scavenged armour).
    - **Marketplace:** the **"Casino Mob Enforcer"** (`docs/art/reference/cyborg_casino_enforcer.jpg`: a gilded, card-suit screen head, a pinstripe suit with gold trim, gold armour plates).
    - **Corporate:** Variant 2, the **"Wide-Aspect VR" Runner** (a wide VR visor, a sleek dark jacket, chrome hands).
    - **Dead Zone:** the base, burned out (soot, ash, a flickering screen).
    - **Golden Zone:** derived from the Casino Mob Enforcer by the art agent.
    - Gold and brass may appear on variants as **unlit ornament**; the screen always glows cold white; nothing glows copper.
    - **No variant is bigger than the base.** The concept sheets are references and jumping-off points, not specs to copy, since a bigger body would no longer match the hitboxes.
- **Movement:** stands mostly on **truck roofs** and moves slowly toward the player, dropping behind quickly.
- **Attack:** loosely aimed laser bolts in **bursts of 2–3**, then a pause to reload.
  - Each burst has a **visible charge-up** (arm cannon glow).
  - Bolts are slow enough to dodge by switching lanes.
  - **Up to two bursts in the air at once** (owner, October 8, 2026): cyborgs, window cyborgs and Barnacle Turrets share the limit. The build had allowed only one, which looked unnatural. Big attacks still take turns (§9).
- **Panic variant (~1 in 3):** runs away in a panic, firing wildly over its shoulder, with a shocked "O" face on its visor.
- **Window cyborgs:** upper body in building windows.
  - They don't move; they shoot at the player.
  - **Touching one hurts.** They sit at a fixed height, so wall-entry timing decides whether you pass above or below.
  - Armor blocks their shots but not a body collision.
- **Kill:** **stomp on the head**, weapons, claws, or the dash.
- **Scaling:** fire rate, projectile speed, and health increase gradually across the campaign.
- **Production note:** the first animated humanoid. Use one shared body and skeleton with swappable parts per zone.

### 9.3 Hover Truck (mini-boss; first appears in Neon City 3; rare early, more frequent later)
- **Entrance:** bangs on a building wall (left or right) as a warning, then **bursts through** in fire and rubble.
  - A player on that wall section **takes damage** (the banging is the warning).
- **Movement:**
  - Hovers with a subtle bob, driving over other trucks and gaps.
  - Occupies **one lane** on all platforms.
  - Paces the player; **lurches** backward and forward.
  - Falls behind after **20–30 seconds** if not destroyed.
- **Attack:** a **cannon** with a slow fire rate. A visible cyborg driver; window shooters scale from **0 early to 1–2 by the final levels**.
- **Contact:**
  - Sides are **safe but solid**: switching lanes into it bumps you back.
  - **Being in front of it when it lurches forward kills you.** All versions have visible **front spikes**, from a sleek pointed nose (city) to a spiked plow with barbed wire and rusted plating (scavenger).
- **Kill:**
  - Get onto its roof and **stomp the glowing red weak point on the cab**, sending it spinning out to explode.
  - **Routes onto the roof:** (a) take a ramp onto the wall, then wall-jump onto the truck; (b) during a backward lurch, get ahead of it, jump onto the wall, wait for the forward lurch, then jump onto the truck.
  - Weapons also work (17 shots at laser tier 1, 5 at missile tier 4).
- **Visual variants:** sleek city version; scavenger version (rusted bolted plates, spiked plow, barbed wire).
- **Design principle it establishes:** safe things look safe, and the one deadly part looks deadly.

### 9.4 Octodog (first appears in Gangland 2, the campaign's 5th level)
- **Look:** a mass of green tentacles on robotic dog legs.
- **Movement:** floor only.
- **Attack sequence:**
  1. Appears **head-on from ahead**.
  2. Wind-up with a visual and **audio cue**.
  3. **Lunges** in a straight line that can cut diagonally across lanes. It **cannot change course mid-leap**.
  4. Runs ahead to about halfway up the screen, then repeats.
  - **2–3 charges early, up to 4 at the maximum**, then gives up.
- **Hint:** a **doghouse** prop warns of the first Octodog appearances only.
- **Dodge:** switch lanes or jump over it.
- **Kill:**
  - Weapons: 7 shots at laser tier 1.
  - Claws kill it (**claws beat tentacles**), and the dash kills it.
  - **Baiting it into a gap kills it** (skill bonus). The generator sometimes places Octodogs near gaps for this.
- **Stomping without claws:** the tentacles grab the player, causing damage.
- **Armor / shield:** blocks one lunge or grab.

### 9.5 Sewer Screech (first appears in Gangland 1)
- **Look:** slimy, diseased vermin with **rows of spines** on its back.
- **Where it comes from:** manhole covers in the floor (street zones) or vents at the bottom of walls. **None in the Neon City** (decided September 26, 2026), since the schedule introduces screeches in Gangland 1. Zones without streets get wall-vent screeches only.
- **Warning:** its cover or vent **shakes**, then bursts open.
- **Trigger:** comes out only if the player is **in its lane**. Otherwise it stays hidden.
- **Attack:** a short dash straight along its lane and **one swipe**, then it falls behind.
- **Wall vents:**
  - Player on the nearby floor: it drops to the floor lane and attacks.
  - Player on the wall at the vent: it swipes from the vent, then drops. Escape by jumping off the wall.
- **Dodge:** switch lanes or **jump over it**. Landing on it without claws hurts.
- **Kill:** any weapon in **one hit**, claws, or the dash. Armor and the shield block its swipe.
- **Reuse:** the **building block for the swarm boss**.

### 9.6 Heli Drone (first appears in Gangland 3)
- **Look:** a futuristic drone with a helicopter rotor on each side and a **gatling gun** underneath.
- **Entrance:** swoops in from the distance as a warning.
- **Movement:** hovers over the player's lane and **follows them between lanes**. It is **stationary while firing**.
- **Attack:**
  1. Audible **wind-up**.
  2. A barrage with enough spacing between bullets to **zigzag** through.
  3. Moves again afterward.
- **Where it attacks:** keeps firing at a player **on a wall**; **waits** while the player is on the ceiling.
- **Kill:**
  - **Anti-grav pad:** stepping on one hurls **every drone on screen** into the ship hull, destroying it. Anti-grav affects **only drones**.
  - Weapons: 17 shots at laser tier 1, 5 at missile tier 4, deliberately slow so the pad remains the satisfying route.
  - Claws don't work.
- **Armor / shield:** plus the invulnerability window, this protects through a barrage.
- **Persistence:** stays until destroyed or the level ends.
- **Generator rules:**
  - **At least 10 seconds** of dodging before a pad appears.
  - If the pad is missed, another appears 8–10 seconds later, repeating.
  - No drone spawns in the last ~15 seconds of a level.

### 9.7 Cyborg's Bad Dream (late levels; first appears in the Dead Zone)
- **Look:** a ghostly apparition, black with purple highlights, a mix of vapor and liquid. A bulbous head with a **circular maw of spiked teeth**, long fingers ending in slashing claws, and no legs.
- **Origin:**
  - Bursts out of a **host cyborg** when the host is killed.
  - Hosts are **visibly marked**: their LED visor glitches with purple static and corrupted expressions.
  - **Weapons hit hosts** (owner, October 8, 2026, replacing the September 26 rule that hosts were immune to all weapon damage): **auto-fire targets hosts** like any other cyborg, and a weapon kill releases the host's Bad Dream. The player who doesn't want that **switches the weapon off** in the shop (the equip toggle), so carrying a weapon into host levels becomes a choice with a cost. Killing a host with a stomp, claws or the dash still earns a big score bonus.
- **Movement:**
  - **Passes through fences and physical barriers.**
  - Drifts toward the player's lane at a limited sideways speed.
  - Follows onto walls slowly.
  - **Cannot reach the ship's hull.** It waits below until the player drops.
- **Attack:** a clearly telegraphed **lunging slash across three lanes** (your lane and the lanes on either side), with the maw opening and a shriek. It repeats every ~3–4 seconds for **20–30 seconds**, then dissolves.
- **Immune to weapons, stomping, and claws.**
- **Defenses and counters:**
  - Armor and the shield each block one slash.
  - The juggernaut dash passes through it safely but doesn't kill it.
  - **A generator's EMP dissolves it early.**
- **Rules:**
  - Only one on screen at a time.
  - Never at the same time as an Octodog charge sequence or a drone barrage.
  - Anti-grav pads guaranteed during the chase.
  - Surviving the full chase earns a score bonus.
- **Purpose:** a counter to late-game power creep that forces pure movement skill.

### 9.8 Barnacle Turret (owner, September 26, 2026; first appears in Marketplace 1)
- **Where:** a ceiling hazard, the Marketplace's new enemy. It **pops out of the ceiling's underside** (a ship's hull, or whatever forms the ceiling in that zone) and stays stationary.
- **Fires only at a player on the ceiling** (the ceiling is otherwise too safe). It never shoots down at the floor.
- **Look:** a round, dome-shaped body with a cannon or gun coming out of its chest.
  - **Mechanical** in most zones.
  - **Creature version in Gangland and the Marketplace:** more animalistic, as if alive, a bit cutesy and silly, like a furry creature. It keeps the same dome body and chest cannon, so it reads as the same enemy (readability rule). Since the turret arrives after Gangland, the Gangland look only matters if zones are ever mixed (e.g. endless mode).
- **Attack:** fires at the player **the same way the cyborg does** (a visible charge-up with a sound, a short burst of bolts, then a pause), and is **slightly more accurate** than the cyborg. It should **not** be a difficult enemy.
- **Dodge:** by dodging its shots.
- **Kill:** claws, the dash, a stomp, or **7 shots** at laser tier 1.
- **Body:** treated like the cyborg's body. Running into it is deadly unless the player has the shield or claws (or is dashing); armor doesn't help.
- **Armor and shield:** both block its shots.
- **Scaling:** across the campaign it fires somewhat faster and takes slightly more damage to kill, but never by much.
- **Limits:** never on a one-lane ceiling (no room to dodge); at most **2 per ceiling**. Up to two cyborg-type bursts are in the air at once (§9.2; owner, October 8, 2026), so both turrets on a ceiling may fire together.

### 9.9 Buzz Overdrive (owner, September 26, 2026; the Corporate zone's new enemy, first appears in Corporate 1)
- **Look:** a **truck-sized buzzsaw tank** with a giant, **vertical** buzzsaw blade. Militaristic. If it can be seen at gameplay size, a **red, angry eye on each side**.
- **Where:** floor lanes; it occupies one lane.
- **Sequence:**
  1. The player sees it **in the distance**, in its lane.
  2. It **revs in view for a few seconds**, with a spin-up noise as its blade spins up. During the wind-up, **the lane it is about to cut lights up with a red warning line** on the floor (like the Octodog's lunge line).
  3. It **charges forward along its lane** toward the player, **slicing the floor in half** as it goes. The floor it has cut **becomes a gap**, from where it started charging all the way back past the player. The cut edges glow the usual gap-edge orange. **Inside the cut, the player sees the zone's own scenery below the street**, the same as through an ordinary gap (owner, October 8, 2026): the canal in the Golden Zone, the trench under the maglev line, and so on, never a dark box.
  4. It goes off the screen behind the player, and that's the end of it.
- **Dodge:** leave its lane before it arrives. It only threatens **its own floor lane**: wall runners and ceiling runners are safe, even beside it.
- **Contact:** touching the buzzsaw hurts. The **shield and armor block it**. After a block, the floor under the player **holds for about a second**, just enough to switch lanes (a jump would land back in the cut lane). Escaping after a block should be of **medium difficulty**.
- **Kill:**
  - **Weapons:** very tough, **22 shots** at laser tier 1. **Killing it before it charges saves the floor**; killing it mid-charge **stops the cut where it dies**. Tuned so laser tier 1 can't stop it in time, but the missile tiers usually can.
  - **Claws don't work** (it's claw-immune).
  - **The dash smashes it**, but that's a risky panic move: the player dashes straight into the cut lane, so it's only survivable with the grapple hook.
  - **No stomp** (the player would land on the blade).
- **Limits:** only one at a time. It never cuts a lane holding a ramp, a pad or the safe landing zone after a ceiling. On 3 lanes, two lanes always stay whole.
- **Scaling:** the only change across the campaign is that its **rev time gets slightly shorter**. It appears in the Corporate zone and the **two zones after it (the Dead Zone and the Golden Zone)**, so the speed-up is spread over few levels and it never gets too fast (corrected September 26, 2026). Its health stays at 22 shots.
- **Implementation note:** the generator plans each cut in advance (lane, start and end), so levels stay fair and identical on every attempt; the saw is just the visible cause. This is the first floor that turns into a gap during play.

### 9.10 Resonator (the owner's "Hymn Censer" reworked in a sci-fi form; the Golden Zone's new enemy, first appears in Golden 1)
- **Direction:** leans heavily on sci-fi, and must not look like anything from a church. It reads as the cult's **broadcast technology**, not an object of worship.
- **Look** *(proposed)*: a floating, slender golden spire ringed by 2–3 slowly turning halos around a red glowing core. Elegant luxury tech rather than religious.
- **Sequence** *(proposed)*:
  1. It hovers far ahead.
  2. Before each pulse, its halos spin up and line up, with an audio warning. **The warning sounds like a crackling build-up of fire breaking into a crashing wave** (owner, October 8, 2026, replacing the three-note chime, which sounded like a doorbell).
  3. It sends a **red shockwave ring rolling along the floor toward the player, across every lane**.
  4. It leaves after a few pulses. Later in the zone it pulses faster or sends double waves.
- **Dodge:** jump the wave, or be on a wall or the ceiling (waves only travel along the floor).
- **Kill** *(proposed)*: weapons, or wait it out. It hovers too high to stomp. Armor and the shield block a wave.
- *(Proposed)* Fairness: the generator never lets a wave arrive on top of a gap or a fence.

### 9.11 Gilded Sentinels (owner, September 26, 2026; first appear in Golden 2 *(proposed)*)
- **Look:** the Golden Zone's walls are lined with golden statues holding halberds, most of them decorative. A **live** one stands in a niche **at wall-run height** with **glowing red eyes**; decorative statues never stand at wall-run height (safe things look safe). They fit the Golden Palace as its guards.
- **Attack:** as the player approaches, its eyes flare and stone grinds (visual and audio warning); then it **swings its halberd across its wall section and the outer floor lane**. **The warning is half as long as first built** (owner, October 8, 2026: 0.6 s instead of 1.2 s).
- **Seeing it** (owner, October 8, 2026): the live statue and the back of its niche stand **further forward**, out of the arch's shadow, so the player can make out what it is.
- **Dodge:** on the wall, pass above or below the swing by timing the wall entry; on the floor, stay out of the outer lane. Later ones swing twice or come in pairs.
- **Kill:** a stomp from a wall jump *(proposed)*, or weapons: **17 shots** at laser tier 1, with no special weapon rule (decided September 26, 2026). Armor blocks the halberd; the statue's body is solid *(proposed)*.

### 9.12 Tithe Collector (owner, September 26, 2026; first appears in Corporate 2 *(proposed)*)
- **Look:** a small, fast gold drone with a collection plate; smug and gaudy.
- **Behaviour:** darts along the lanes ahead of the player and **sucks up the credits in its path** (a visible stream of credits flowing into it). It weaves through the most dangerous lanes, so chasing it is the risk. It **stays in the level twice as long as first built** (owner, October 8, 2026).
- **Catch it** (stomp, shoot or dash through it) and it bursts into **everything it took plus a jackpot**.
- **Touching it isn't deadly:** it grabs **25% of the credits collected this run** (decided September 26, 2026) and flies off. This is the game's first non-lethal hit.
- *(Proposed)* It is **not a heli drone**: anti-grav pads don't affect it, and it has no rotors, so it doesn't look like one.
- **Where:** introduced earlier than the Golden Zone and appears there as well. *(Proposed)* Introduced in Corporate 2, skips the Dead Zone (there's no one left to collect from), and returns in the Golden Zone.
- **Priority:** it is the first idea to drop if the budget tightens (owner, September 26, 2026).

### 9.13 Enforcer Truck (owner, October 4, 2026; first appears in Corporate 2)
- **The idea:** an enemy the player **can't destroy directly**. It's destroyed by turning other enemies' attacks against it, so the player learns **the relationships between enemies** instead of looking at each one in isolation. It builds on the owner's enemy-versus-enemy mechanic: **an Octodog's lunge and a Buzz Overdrive's charge hurt other enemies.**
- **Look:** a heavy armoured truck, police-style, distinct from the hover truck, with **headlights** and a **red-and-blue light bar**. Cyborgs it picks up ride on its roof. *(Proposed)* Its body follows the zone's skin like the hover truck's.
- **Movement:**
  - **Drives on the street behind the player** and **follows the player's lane changes after a short delay** *(proposed: about 0.8 s)*, so a late dodge leaves it in the lane the player just left.
  - **Seeing it:** it's behind the camera, so its **headlight beams and light bar shine forward onto the floor of its lane**, and a small marker at the screen's bottom edge shows its lane. The light bar honours Reduced flashing.
  - **Showing itself** (owner, October 8, 2026): its model would otherwise never be seen, so **every so often it speeds up until it's on screen for a few seconds, then drops back**, even at the cost of some clutter. *(Proposed)* It pulls up beside the runner in a neighbouring lane rather than right behind them, so it never hides the runner. Its sides are safe but solid while it's there, like the hover truck's. It never takes the only free lane, and never shows itself during an attack's warning or a bait.
  - **Room to show itself** (owner, October 9, 2026): each chase keeps a short calm stretch for its showing, at a small cost to danger density (about 2% fewer enemies and obstacles on its levels). **It shows itself before the player can bait it:** a truck arrives early enough for its showing to come before its first bait. **A chase with no room for a showing gives its truck to another bait's chase that has room,** wherever the level has another bait. To a runner in an outer lane it shows itself **two lanes in**, leaving the lane between free.
  - **Making room where there is none** (owner, October 9, 2026): it **may show itself while a hover truck or a Gilded Sentinel is around**, as long as the runner keeps a free lane to dodge into (more clutter on screen is accepted). Where a level's first bait comes right after its calm start, **the truck arrives a few seconds early and shows itself in the last part of the calm start**; the bait stays where it is. A level with two trucks but room for only one showing **keeps both**.
  - **Its end is a visible explosion** (owner, October 8, 2026): however it's destroyed (a Buzz Overdrive's charge, an Octodog's lunge, a cut or a wider gap), it explodes where the player can see it. The flash honours Reduced flashing.
  - **Holes:** it hops ordinary gaps as the player does. A **Buzz Overdrive's floor cut** in its lane, or **a gap too wide to hop**, wrecks it.
    - **Wider gaps** (owner, October 7, 2026): every level has **a couple of wider gaps**. They're uncommon, still jumpable by the player, and wide enough that an Enforcer following the player into one is wrecked.
  - **During an Octodog's attack** it **closes right up behind the player**, so the Octodog's lunge (which ends just behind the player) reaches it. *(Proposed)* While that close it must not hide the runner: it stays under the camera's line of sight, or its body turns see-through while its lights stay solid.
  - **Gives up after about 25 seconds** if not destroyed (like the hover truck).
- **Attack:** **lasers** at the player's lane. Each volley is warned by **a red line on the floor ahead and a rising whine**, and dodged by changing lanes, which also moves the truck. *(Proposed)* Its volleys are a big attack for turn-taking (§9), so it never fires while an Octodog or Buzz Overdrive charges.
- **Killing it:**
  - **The only ways:** **bait an Octodog's lunge or a Buzz Overdrive's charge into it**, or **lead it into a Buzz Overdrive's cut or a gap too wide to hop**.
  - It's immune to weapons, stomps, claws and the dash. *(Proposed)* It never touches the player.
- **Picking up cyborgs:** a cyborg the player left alive that is in the truck's lane when the truck passes is **picked up**. It rides on the roof as a visible gunner and **raises the truck's rate of fire**. *(Proposed: up to 3 riders.)* Destroying the truck pays a **bonus for each rider aboard**, so a skilled player may let it load up before baiting it. **Hosts never board, and riders can't be shot off** (owner, October 7, 2026).
- **Placement:**
  - **Up to two per level**, never two at once.
  - Each one is placed only where **at least one Octodog or Buzz Overdrive charge comes during its chase**, so it always has a chance to be destroyed.
  - It appears where Octodogs or Buzz Overdrives appear, **introduced in Corporate 2** with a first-encounter hint.
- **Teaching** (owner, October 7, 2026): **occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge**, so the player sees a charge flatten another enemy. At least one comes before the Enforcer's first appearance in Corporate 2.
- **Name:** "Enforcer" is also used in two cyborg variants' art names (§9.2: Gangland's "Broadcast Brute" Enforcer and the Marketplace's "Casino Mob Enforcer"). The truck keeps the name.

### 9.14 Dash walls (owner, October 8, 2026; first appear in the Corporate zone)
- **What:** a wall standing **across every floor lane**, like a building in the middle of the street. It uses the zone's side-wall look (the same building faces), turned to face the player.
- **Getting through:** the player **dashes through it**. It crumbles and explodes into rubble.
- **Without the dash** (not owned, switched off, or on cooldown): the player crashes through it and takes **one hit**. **Armor or the shield absorbs it** (an exception to the rule that armor doesn't block solid collisions); with neither, the hit kills. The wall breaks either way.
- **Walls stay open:** it blocks only the floor. A player running on a side wall passes it. **No ceiling overlaps a dash wall.**
- **Introduced in the Corporate zone** *(proposed: Corporate 1, after the Buzz Overdrive's introduction)*, and in the zones after it.
- *(Proposed)* Fairness: walls are spaced so the dash's longest cooldown (8 s) is always over before the next wall, and nothing else that needs the dash comes just before one.

---

## 10. Bosses (partial)

- **General:**
  - One per zone.
  - Each boss is its own scripted encounter with its own scene and rules, not a variant of a normal level (decided September 26, 2026).
  - **Gameplay stays as close to the main runner as possible** (refined September 26, 2026): the same controls, camera and movement. A boss may get its own gimmick that makes it play differently, but none has been chosen yet.
  - Unique scripted encounters (handmade arenas are allowed within the generator system).
  - **Length:** about the same as a level, **60–120 seconds**. The final boss may run a little longer, to be more challenging.
  - **Death restarts the fight** (no checkpoints), like a level. **Exception: the final fight** has a checkpoint halfway, where the villain may change into a **second stage**.
  - **Items:** players bring their current items into the fight. Some fights may also offer **pickups**, for example a section of floor that spawns an armor, shield or grapple pickup.
  - **Standard armor rule** (decided September 26, 2026; used by the Floating Head and the Sewer Swarm, and the default for later bosses): one armor pickup appears at the start of the final phase. Whenever the player's armor or shield breaks during the fight, another armor pickup appears **15–17 seconds later**, at most once per phase *(proposed cap)*. The **Floating Head keeps 10–15 seconds**, so the first boss is a little gentler; the Sewer Swarm and later bosses use 15–17.
  - **Rewards:** beating a boss earns **credits and score points**.
  - **Stars and leaderboards:** bosses have both, like levels (decided September 26, 2026). *(Proposed)* One star for winning; two and three stars for beating par times set per boss in data. The leaderboard ranks the boss score, which includes a time bonus.
  - **No time limit, no escalation:** if the player doesn't land the hits, the fight keeps cycling its pattern until they win or die. It does **not** get harder while a player struggles.
  - Bosses ignore claw contact kills.
  - Every boss must be beatable using only the power-ups granted before the fight.
- **Roster** (decided September 26, 2026):

  | Zone | Boss |
  |---|---|
  | 1. Neon City | Floating Head |
  | 2. Gangland | Sewer Swarm |
  | 3. Marketplace | None: it leads into the Casino (owner, October 8, 2026) |
  | 4. Casino | The House (moved from the Marketplace; owner, October 8, 2026) |
  | 5. Corporate | Hostile Takeover |
  | 6. Dead Zone | Sleep Taker |
  | 7. Golden Zone | The Golden Convergence (the final villain) |

- **Floating Head** (Neon City). Owner's design, with the design round's additions approved by the owner (September 26, 2026).
  - **What it is:** a **giant ship**. Its back is a **giant cybernetic propaganda face** that watches over the city and **shouts its propaganda**.
  - **Bombing run:** the ship flies in overhead and **drops bombs toward the player**. Owner's playtest update (October 2, 2026): all bombing runs end about **30% sooner**; the initial 16-second run is now **11.2 seconds**, and later 8-second runs are **5.6 seconds** (10 seconds since the salvos, below). A searchlight sweeps the lanes and the bombs fall where it lingers, with a falling whistle, so the light is the visual warning.
  - **The reveal:** the ship finishes its flyby **directly in front of the player**, and its back turns out to be the face.
  - **Face-off attacks:** **eye lasers** while it looks at the player. *(Proposed)* The eyes glow and whine, then twin beams sweep across the lanes: jump a low sweep, slide under a high one, or switch lanes when a beam drags down a lane. **Cyborg drop** (kept): its mouth opens and drops 1–2 cyborgs onto the trucks ahead, who then fight like normal cyborgs.
  - **First laser is jumpable without dash** (owner's playtest, October 2, 2026): the low horizontal sweep must fit within a normal jump started at the firing cue, without requiring the dash power-up. High sweeps still require a slide; lane drags still require changing lanes.
  - **Back to the sky:** once or twice during the fight it rises for another bombing run (shorter than the first).
    - **Salvos** (owner, October 9, 2026): the first bombing run stays as it is (one spot at a time, one or two bombs). In the next run, the light marks **two to four spots at once**, each hit by **one or two bombs**. The first spot is the closest to the player and each later one a little further along the track, so the player can see the path they'll have to take before the bombs are released. The third phase's run drops salvos too (owner, October 9, 2026).
      - **How each spot is placed** (owner, October 9, 2026): each spot leaves the player as few lanes as possible, always at least one way through. **On 3 lanes** a spot takes one or two bombs and leaves **one lane: a forced path**. **On five or more lanes**, where a player could otherwise step clear of a whole salvo, it's harder: a spot takes up to **three bombs side by side** and leaves **a choice of two lanes**.
      - **Spots closer together** (owner, October 9, 2026): **10 m** apart at 18 m/s instead of 12 m, about 0.56 s from one blast to the next.
      - **Later runs longer** (owner, October 9, 2026: 10–12 seconds), to fit the salvos: **10 seconds** instead of 5.6, still shorter than the first run. That fits three salvos of four spots, and a flawless fight still pins the same towers (at 11 seconds it would miss one and run past 120 seconds on 3 lanes).
      - **Far spots look the same** (owner, October 9, 2026): every target circle is the same red at any distance (the City's fog doesn't tint the far ones).
  - **Bringing it down** (the owner's idea of a building falling on it): marked, cracked towers stand ahead at the roadside. The player **baits the eye laser into a marked tower** by leading the beam to that side and dodging at the last moment, the way players bait an Octodog into a gap. The tower topples onto the ship and pins it low across the trucks. If the player doesn't manage it, the laser eventually clips a tower on its own, so a struggling player still gets a chance; baiting it is faster and scores more.
  - **Weak points**: glowing **red** on top of the head, the same language as the hover truck's weak point. While it's pinned, the player **stomps** one. Each phase uses a different Zone 1 skill to get on top: (1) run up the fallen tower like a ramp; (2) wall-jump onto it; (3) ride a ship's underside via an anti-grav pad and drop onto it when the hull ends.
  - **Getting on top is forgiving** (owner's playtest, September 30, 2026): a lane switch onto the fallen tower partway along still gets the runner onto it, and each phase's route onto the head must be obvious and always there.
  - **Three phases**, one stomp each. After a stomp it shakes free, shrieks and rises; the next phase is faster, with more cyborgs.
  - **Damage:** stomps do the real damage (a third of its health each); weapons chip away slowly (tuned so even the best weapon saves at most one stomp over the whole fight).
  - **Propaganda voice:** a heavily distorted announcement voice that isn't meant to be understood, plus a few short slogans shown as text on its face screen (so only those slogans need translating).
  - **Armor pickups:** one appears at the start of the final phase. In addition, whenever the player's armor or shield breaks during the fight, another armor pickup appears **10–15 seconds later** to give them a chance (at most once per phase *(proposed)*).
  - **Kept simple:** no bonus damage for shooting into its open mouth.
  - **Defeat**: its face glitches, the propaganda cuts out mid-shout, and it crashes into the street ahead; the runner runs through the wreck. This leads into the zone's outro, and in the web demo into the "get the full game" screen.
- **Sewer Swarm** (Gangland). Owner's design, with the design round's additions approved by the owner (September 26, 2026).
  - **What it is:** a mutant horde of screeches rising from the sewers. It builds up on both sides of the street, and a mob attacks while the horde shifts **ahead of and behind** the player.
  - **The Host** at the heart of the swarm: a **poor person with electronic components fused to their sickly body**, mostly hidden under the screeches latched onto them. An unconnected monster, not one of the villain's (§1).
  - **Intro cinematic** (owner's story beat, October 9, 2026; Gangland's boss-intro slot, before the fight). The camera stays **at ground level** throughout, so the player feels more in the runner's shoes.
    - The runner runs down the middle of the street, with **manhole covers on either side**.
    - After **2 seconds**, **one** screech jumps out of a manhole. The runner easily avoids it and keeps moving forward.
    - **A second later**, **three** jump out of manholes on either side, **two on one side and one on the other**. The runner dodges them.
    - **A second later**, **five on the left and six on the right**. The runner runs past them.
    - Then **more and more** pour out of the manholes. They also start **dropping from the sky**, from outside the camera's view, landing on the ground and **running beside the runner**.
    - Soon a **wall or wave of screeches** is seen behind the runner, running after them.
    - As the wall gets closer, **one cut** to the mass of screeches: in a **dark area** inside it, a **glint of the Host** in the middle of the swarm can just be made out.
  - **The fight is Gangland's final exam** (screeches, ramps, baiting, fences) in three phases of about 30 seconds each:
    1. **Rising:** manholes and wall vents shake all along both sides, and screeches pour out and merge into clusters at the roadside. A cluster **surges down a lane** ahead of the player, with a red lane line and a rising chitter as the warning.
    2. **Surrounded:** clusters also strike **from behind**. The warning is a **chittering sound** plus a **visible rising wave of the swarm** on screen, curling like a breaking wave or a scorpion's stinger, about to strike its lane. The swarm also **climbs the walls**, taking them away as an escape route, but only **temporarily**, and the phase must stay engaging: **one wall at a time for a few seconds, alternating sides**, so one wall is always free.
    3. **The Host:** the Host bursts out of a big sewer pipe ahead and flings the remaining clusters at the player.
  - **Fighting the swarm:** the street is the weapon. The player **baits the swarm into attacking**, dodges in time, and the swarm **hits a live electric fence and is shocked**, which damages the boss. Baiting a cluster into a **hole** also works. Weapons thin clusters too, and the heavy missile gets bonus damage against them.
  - **Phase ends:** phase 1 ends when two clusters are destroyed, phase 2 when the rest are. If the player doesn't manage it, the phase keeps cycling (no time limit, no escalation).
  - **The Host's weak points:** its fused implants, glowing **red** (the same language as other bosses' weak points). The player reaches them by a ramp and a wall jump, Gangland's big new move. **Three stomps**, each knocking screeches off and revealing more of the person. Its lunge can also be baited into a fence.
  - **Pickups:** the standard armor rule, with the 15–17 second delay.
  - **Implementation:** 4–5 gameplay entities ("clusters"), each rendered as many screech-variant creatures using MultiMesh plus a shader for per-creature motion. It looks like hundreds, but only 4–5 are simulated. The Host is one more entity.
  - **Performance on phones** (owner, October 2, 2026): build it now with crowd sizes that scale (set in data, and smaller on low-end devices); the phone test (risk test R4, task E3) comes later and sets the sizes.
  - **Defeat: the Host is freed.** The screeches scatter, the implants short out, and the person slumps free.
- **The House** (Casino; it was the Marketplace's boss until the owner added the Casino zone on October 8, 2026, and the fight itself is unchanged). The design round's pitch, approved by the owner (September 26, 2026). The owner will playtest it once built and may revisit it.
  - **What it is:** a **slot machine the size of a building**, rolling down the casino street on treads, lights blazing and jingling. Loud, gaudy and a little ridiculous, to match the Marketplace's happy mood that the Casino carries on. The citizens in the shop windows cheer and duck throughout.
  - **Tied to the villain:** the cult secretly owns the casino. Its symbol is hidden on the machine, and the jackpot money flows up to the Golden Zone. The owner is also open to making the tie direct.
  - **The spin (the warning):** it paces ahead of the player and yanks its giant lever. Three huge reels on its chest spin and stop one at a time, each with a *ding*, over about 2 seconds. The symbols announce the attacks, in reel order:
    - **Cherry:** cherry bombs lobbed into lanes, with target circles on the floor (the Floating Head's bomb warning).
    - **Lightning:** a pink electric fence rolled across some lanes (normal fence rules).
    - **BAR:** heavy gold blocks slammed down into lanes; switch around them.
    - Two or three of a kind make a bigger version of that attack. Three symbols are enough for now.
  - **Rigging the jackpot:** while the reels spin, big glowing **7 buttons** appear along the route. Running over one locks its reel on 7. With all three locked: **JACKPOT**. Sirens go off, the machine overloads and sprays a fountain of real credits to grab, and its **coin hopper bursts open on top** as a glowing red weak point while it sags low. The player **stomps** it.
  - **Three phases,** with the buttons getting harder to reach, as the final exam of the Marketplace's mechanics, which the Casino reuses: (1) all three on the floor; (2) one on a wall, with wall fences in play; (3) one on a ceiling reached by an anti-grav pad, guarded by Barnacle Turrets.
  - **Missed buttons:** it just spins again (no time limit, no escalation). Weapons chip away at it; stomps do the real damage.
  - **Defeat:** the reels spin wildly and jam, "TILT" flashes, and it collapses in an explosion of coins while the shops erupt in cheers.
  - **Pickups:** the standard armor rule (15–17 seconds).
- **Sleep Taker** (Dead Zone). The design round's pitch, approved by the owner (September 26, 2026).
  - **What it is:** in the Dead Zone, when a cyborg dies, its Bad Dream doesn't dissolve. Over the years they drifted together through the ruins and fused into **one colossal nightmare** haunting the silent city: black with purple highlights like the Bad Dream, but vast, with dozens of circular maws and long clawed fingers.
  - **Tied to the villain indirectly:** the nightmares are an unintended consequence of what the cult has done to people's minds.
  - **Immune to weapons,** like every Bad Dream, so the fight is pure movement skill. **Only the EMP hurts it.** Fence generators are the Dead Zone's last working machines; blowing one near the nightmare tears part of it away.
  - **Lighting:** the arena is **darker than normal lighting, but never pitch black**. Hazards keep glowing in their usual colours, so the fight stays readable.
  - **Attacks** (each with a visual and audio warning):
    - **Giant slash** across three lanes: the maw opens with a shriek (the Bad Dream's warning, bigger). Get out of those lanes, or up onto the ceiling.
    - **Grasping hands** rising from the floor: purple mist pools in the lane, with whispering. Switch lanes.
    - **Lights out:** after a deep inhale, it swallows much of the light. It gets **darker still, but not pitch black**, and the glowing hazards stay visible while hands and slashes keep coming. **Half as bright again as first built** (owner, October 8, 2026): everything that is lit gets 50% darker than the first build's lights-out, while glowing things (gap edges, lasers, warnings) stay as visible as before.
    - **The hands spread out** (owner, October 8, 2026): one round of hands rises at **several distances along the street**, not all at the same spot, so the player has to make several lane switches in a row to get through one round.
    - **The walls aren't safe** (owner, October 8, 2026): the arena's side walls have **many gaps**, and the hands attack the walls much more often.
    - **Twice as many floor gaps** as first built (owner, October 8, 2026).
  - **It can't reach the ceiling** (the Bad Dream rule), so anti-grav pads are the refuge from the big slashes.
  - **Hurting it:** glowing fence generators stand along the route. The player **lures it close** (it lunges toward them), then **destroys the generator with a stomp or the dash**; the EMP rips a chunk of the nightmare away.
  - **Weapons never set off a generator** (the rule everywhere, §9.1), so the weapon can't trigger an EMP before the player wants it. Weapons have no effect in this fight at all.
  - **Three phases,** three EMP hits. It gets hungrier each phase (faster hands, more lights-out). A missed generator is followed by another (no time limit, no escalation).
  - **Defeat:** the last EMP bursts it into hundreds of wisps, each a faint face or figure that drifts upward and fades as the dreams are released. Then silence, and the first grey dawn light breaks over the Dead Zone, setting up the Golden Zone.
  - **Pickups:** the standard armor rule (15–17 seconds). EMP flashes honour Reduced flashing.
- **Hostile Takeover** (Corporate). The design round's pitch, approved by the owner (September 26, 2026).
  - **The idea:** corporations and the military are one and the same in this zone, so the boss is a merger, literally.
  - **The arena is the boss:** the player lands on the rear roof of the **Chairman's armored maglev train**, a long luxury corporate express, and runs forward along it toward the locomotive. Carriage roofs are the floor and the gaps between carriages are the gaps, so it plays like a level. A **military gunship** paces the train overhead. The sense of speed comes from the scenery streaming past (the City's moving-road trick in reverse).
  - **Tied to the villain directly:** the Chairman is one of the villain's inner circle. The player gets **a glimpse of him**: in the locomotive's window during the fight, and as the face on the "MERGER COMPLETE" screens.
  - **Phase 1, The Board (corporate carriages):** security cyborgs guard the roofs, a Tithe Collector skims credits, and partial wall fences run along the track's sound barriers. Each **carriage coupling** glows red and sits in one lane above the gap between carriages. The player **stomps it by landing on it while jumping the gap**, and the carriages behind break away and tumble off the track. A small target in a gap is the right difficulty for zone 4 (owner).
  - **Phase 2, The Contract (the military gunship):** the gunship strafes the lanes (a warning line and a rising whine) and drops a **Buzz Overdrive onto the roof ahead**, which cuts a carriage lane. An armored carriage with no roof access blocks the way, so the player takes an anti-grav pad and **rides the gunship's belly** over it (the gunship is the ceiling).
  - **Phase 3, The Merger:** the gunship docks onto the locomotive with huge clamps, forming one monstrous war engine, and "MERGER COMPLETE" flashes on every screen. Its attacks combine both. The player stomps the **three glowing docking clamps** to tear the gunship loose.
  - **Defeat:** the gunship spins away and explodes; the locomotive derails and ploughs through the lobby of a corporate tower, bringing down a giant, soulless logo sculpture.
  - **Missed weak points** come around again (no time limit, no escalation). Weapons chip; stomps do the real damage.
  - **Pickups:** the standard armor rule (15–17 seconds).
- **The Golden Convergence** (Golden Zone; the final villain). The owner's design (October 9, 2026). The owner then asked Claude to fill in the rest and build it (owner's mandate, October 9, 2026): those parts are marked *(proposed)* for the owner's review, with the questions in `docs/OPEN_QUESTIONS.md` §D, items 416–503.
  - **Name:** the fight, and the golden construct, are **The Golden Convergence**. The man inside is **The Magnate**.
  - **What it is:** a **giant mechanical construct**, a golden exoskeleton that the villain rides inside: a gaudy, almost religious relic, but entirely man-made. It floats in the distance ahead of the runner. **The man inside isn't visible** until the second stage.
  - **Look (the golden suit):**
    - A man's shape, a giant golden behemoth, with **extra-large shoulders, arms and hands**.
    - **A calm human face, cast in gold, with a red tear.** The tear is a **dull red and never glows**, so it never reads as a weak point.
    - **Decoration:** the cult's own symbols (the Convergent Triad, halo rings like the Resonator's), gold filigree, and signs of wealth, ego and self-righteousness. **No real-world religious symbols.**
    - **Pipes** come out of its shoulders. They fire missiles (the Missile Barrage, below).
    - **No legs:** metallic pipes, almost like tentacles, trail from its lower body and run out beyond the view.
    - **The cape** doesn't have to follow physics: a huge, undulating cloud of **burgundy** cloth with lots of **black folds and shadows**, billowing from the boss's back. It **never glows** (the colour rule, §5), so red hazards and warnings stay readable. It's scenery, not an attack.
  - **The arena** *(proposed)*: **the Grand Court**, the heart of the Golden Palace (§5). A wide golden causeway runs through a hall so vast it has its own sky under a painted, gilded vault. **No walls line it** (below): low golden balustrades edge it, with reflecting pools far below, and the palace's **towers** stand off to either side, the buildings the Flying Buttresses hold up. Giant screens hung on the towers show **the feed**: the cult's emblem and the calm golden face in stage 1, The Magnate's roaring face in stage 2. The track itself is plain: no holes, fences, ceilings, doodads or enemies of its own. Every danger is the boss's.
  - **No side walls:** the arena has none, except where a destroyed Flying Buttress brings a building down to make one (Fist Slam, below). Beyond the outer lanes, a **low golden balustrade** bumps the runner back (the bump the game already uses when a boss takes a wall away), so there's no new way to die.
  - **The entrance** *(proposed)*: as the runner comes into the court, the Golden Convergence **rises into view at the far end**, its cape unfurling into its cloud. The cult's three-note chime (the Resonator's, §9.10) rings out, huge and slow, and the calm golden face looks down the causeway at the runner. Then phase 1 begins.
  - **Stage 1, the golden suit:** **three phases**, built from three attacks: the **Helidrone Strafe**, the **Fist Slam** and the **Missile Barrage** (all below). The suit takes damage when the player destroys a **Refill Ship** (below): **each ship destroyed takes a third of its health.** **Weapons chip** at it slowly, by the Floating Head's rule: even the best weapon saves at most one ship over the whole stage.
    - **Phase 1:** a Helidrone Strafe on its own (3 passes, no pad; it teaches the strafe), then a Fist Slam sequence, a Missile Barrage, and the Refill Ship with a Helidrone Strafe.
    - **Phases 2 and 3:** Fist Slams, Missile Barrage, Fist Slams, Missile Barrage, then the Refill Ship with a Helidrone Strafe (7 passes).
    - **A missed pad:** the ship finishes refilling and flies off, and the phase's loop starts again from the slams. It never gets harder (no escalation, above).
    - *(Proposed)* **Pace:** each phase a little faster than the last (paces 1, 1.1 and 1.2). Between phases, the suit reels from the blast for a few seconds (the phase's intro), then attacks again.
  - **Helidrone Strafe** (owner's attack):
    - **The squadron:** heli drones (the heli drone's model, **never coloured red**) come **out of the cape**, move and fire as one through all of the strafe's passes, and then leave. It's a single attack, not separate enemies.
    - **Size:** one drone for every other lane (half the lanes, rounded up): **2 on 3 lanes, 3 on 5 or 6 lanes**.
    - **Fixed paths:** unlike a normal heli drone, it never tracks the player. On each pass the drones fly a fixed line and rake the floor with fire.
      - **Vertical pass:** the drones fly down the lanes, raking every other lane. The covered lanes **switch between passes** (odd lanes, then even lanes), so each vertical pass moves the player. Most come **head-on**; some come **from behind** the player. *(Proposed)* The first pass covers the outer lanes (lanes 1, 3, 5 counting from 1).
      - **The spare drone:** when a pass covers fewer lanes than there are drones (on 5 lanes, 3 then 2; on 3 lanes, 2 then 1), the spare drone pulls up above the formation and holds its fire, so a drone never flies over a safe lane.
      - **Horizontal pass:** the drones fly from wall to wall, raking a line across the track **and up both walls at every height**. The player dodges it **through a Flying Buttress** (below) or with **the dash**. Horizontal passes are **less frequent** than vertical ones. *(Proposed)* The live line's fire reaches above a jump, so a jump doesn't dodge it.
      - **Extra lines for show:** a horizontal pass rakes **several lines** across the track, further down the field, so it looks busier than it is. **Only one line is live**: the one at the Flying Buttress, with the red warning line. *(Proposed)* The extra lines get no red warning line and no buttress, their fire is over well before the runner reaches them, and they leave only dark, non-glowing scorch marks (what looks like a hit is a hit, §3).
      - Together, the passes draw a hatch pattern over the track, one pass after another, a second or two apart.
    - **Passes per strafe:** **3 in phase 1, 7 in later phases**, in a **fixed script** (learnable, and fair for par times): **V-V-H** in phase 1 and **V-V-H-V-V-H-V** in later phases (V = vertical, H = horizontal). *(Proposed)* Every phase 1 pass comes head-on; in the 7-pass strafe, the 4th and the 7th come from behind.
    - **Warning:** before each pass, a **red line on the floor** where the fire will land, about a second ahead, and a gatling **spin-up whine**.
    - **Walls:** fire in an outer lane hits a runner **low on the wall** but not one **high up** (what looks like a hit is a hit, §3).
    - **Weapons never target the squadron.**
    - **Anti-grav pads** destroy the whole squadron, as they do heli drones (§9.6). In this fight pads appear only for the Refill Ship (below).
    - Nothing else is on the track during a strafe.
  - **Flying Buttress** (owner's new doodad for this fight): **taller than other doodads**. It looks like it holds up buildings out of sight on either side of the track, and may run out beyond the view (the unseen part isn't rendered).
    - **A gate:** its pier rises from an **inner lane, never an outer one**, with a tall arched opening at its foot that the runner runs through. Its flying arch leaps from the top of the pier out over the wall toward the unseen building. The player has to move into its lane to take cover. *(Proposed)* Its arch leans toward the nearer edge of the track (either way from the middle lane, by the fight's seed).
    - **How it shelters:** the squadron rakes the horizontal pass's live line exactly along the buttress, so the bullets spark off the stone above the opening. The **red warning line crosses every lane except the opening.**
    - The sides of the gate are solid but safe, like any doodad: a lane switch into one bumps the player.
    - **When:** it appears for the Helidrone Strafe's **horizontal passes** and for the **Fist Slam** (below). *(Proposed)* In stage 2, also for The Magnate's Pounce.
    - **Fairness:** one buttress for each horizontal pass, always there (the dash is a bonus, not required: every boss must be beatable without bought items). It comes into view well before its line, and there's always time to reach it from the farthest lane (up to four lane switches on 6 lanes).
  - **Fist Slam** (owner's attack, October 9, 2026; stage 1). It's meant to be **scary**.
    - **Targeting and warning:** he raises a fist on an arm that **telescopes out on golden segments** to reach the track, and pulls back afterwards. The fist **follows the runner's lane, then locks about a second before it falls**. The fist rises, its shadow grows on the floor, a **red square** marks where it will land, and a deep grinding wind-up plays.
    - **The slam:** the fist **smashes straight through the floor, out of sight, and goes back to rest at his side**. It never blocks a lane; it leaves a **large square hole at least two lanes wide** at once (the floor turns into a gap during play, as it does under the Buzz Overdrive's cut, §9.9). *(Proposed)* Two lanes wide on 3 lanes, three on 5 or 6, as long as it is wide, around the locked lane (moved inward at the track's edge). Its edges glow the usual gap-edge orange.
    - **A runner under the fist is hit.** Unprotected, that's death. **Armor and the shield block the fist, but the hole is still there.** As after a blocked Buzz Overdrive cut (§9.9), **the floor under the runner holds for about a second**, a split second to jump out (the hole is a short jump) or switch lanes. A **dash** through the fist gets the same second. The grapple hook (it saves a fall, not a hit) and the revive item are the last resorts.
    - **Quick succession:** sometimes he slams several times in a row, **alternating left and right fists**: **up to 3 slams in phase 1, up to 5 in later phases**. Sometimes a fist lands **further ahead** of the runner, so the holes have to be jumped (a hole can always be jumped). *(Proposed)* A fixed script per phase: in phase 1, slams 1 and 2 come down on the runner and slam 3 ahead; in later phases, slams 1, 3 and 4 on the runner and 2 and 5 ahead; about two seconds apart, divided by the phase's pace.
    - **Baited into a Flying Buttress,** the fist destroys it. The building it held up, off screen, **topples forward along the track** on the side the buttress's arch leans toward, and its side forms a **wall** the runner can wall-run on (the normal wall run, no new move). The tower is scenery and never lands on the track. It **stays for about 8–12 seconds**: long enough to escape the Missile Barrage warming up, not for the rest of the stage. Every barrage needs a buttress baited again.
    - **Two chances a sequence:** in each slam sequence, **two slams land at a Flying Buttress**. Hitting one **ends the sequence, and the Missile Barrage starts warming up as the tower falls**, so the wall is there for the whole barrage. If the sequence ends without a buttress hit, the barrage comes anyway. *(Proposed)* The chances are slams that come down on the runner: slams 2 and 3 in phase 1, 3 and 4 later. The buttress stands where that slam will land, and the fist hits it when it locks onto the buttress's lane (a fist locked onto another lane digs its hole beside the buttress, never through it).
  - **Missile Barrage** (owner's attack, October 9, 2026; stage 1):
    - **Warning:** the shoulder pipes open, missiles climb high with a launch roar, and red target marks spread across the floor. The warning leaves time to reach the wall from the far side (up to 5 lane switches on 6 lanes, plus the wall entry). *(Proposed)* The missiles hang at the top of their climb, then dive with a rising whistle while the marks fill in; the fire lands when they're full.
    - The missiles **cover the whole floor, every lane**, and leave a **fiery trail**. The fire burns **longer than one layer of protection alone can carry the runner through** (the dash's 0.6 s, or one blocked hit's second of invulnerability), **long enough that two layers can** (the owner's example: one armor hit plus the dash, 1.6 s), and **shorter than one wall run without claws**, so the runner always drops back onto floor that's no longer burning. The wall-run timing isn't changed for this fight: a runner who gets on too early can **wall hop** (§3) to stay up, and by the final boss players are expected to know it. *(Proposed)* About 1.5 seconds, in data, set in playtesting; its flames reach about a metre up, so a jump only delays them.
    - **The fallen tower's wall is the only clean escape,** and it's **safe at every height**.
    - **No wall** (the player never baited the fist): **the barrage comes anyway, and the player takes the hit.**
    - **Armor and the shield count** against the barrage, as they do against the Helidrone Strafe and the Fist Slam. **Protection stacks the usual way** (owner, October 9, 2026): each armor hit and the shield blocks one touch of the fire and gives the usual second of invulnerability, and the dash passes through for 0.6 s. At about 1.5 s of fire, the free armor alone (1 hit) isn't enough; one armor hit plus the dash, two armor hits (any shop tier) or armor plus the shield get the runner through, a bit toasty.
  - **Damaging the suit: the Refill Ship** (owner's design, October 9, 2026):
    - **When:** after the boss has fired its Missile Barrages (**one in phase 1, two in later phases**), a **ship comes in to refill his missiles**. It feeds them to him along a **line running to his shoulder pipes**.
    - **The ship is a ceiling,** like most ships in the game. *(Proposed)* It's a gilded cult cargo ship, its flat plated belly across every lane at ceiling height, racks of missiles along its flanks, pacing the runner while it refills.
    - **The way up:** an **anti-grav pad** under the ship, **caged by electric fences** (§9.1). A runner who touches a fence is hit unless they **dash** through or first **knock out the cage's generator** (a stomp or the dash), whose pulse switches the fences off. Armor and the shield get through a fence at the cost of a hit, as usual.
      - **A closed cage:** fences in the lanes beside the pad as well, and the front fence placed so a jump over it lands past the pad. The only ways in are the dash, the generator, or spending armor or the shield. *(Proposed)* The cage's sides are fences running along the pad lane's edges, from the front fence to past the pad, so a lane switch into the cage touches one.
      - **The generator** stands in a **lane next to the cage, just before it**, with room after its pulse to switch into the pad's lane.
      - **A clear route:** the lanes the runner needs for the generator and the pad are never under the strafe's fire when the runner could reasonably be there, and no horizontal pass lands while the cage is coming up. *(Proposed)* The squadron holds its fire while the cage comes up and the runner goes for it, hovering in formation beside the ship, and fires on once the runner is past the pad.
    - **The squadron:** around then, a **Helidrone Strafe** is starting or under way. Stepping on the pad **hurls the whole squadron up into the Refill Ship** (the heli drone pad rule, §9.6), setting off a **chain reaction**:
      - the ship **goes spinning off to the side and explodes**, and the missiles it carries all explode;
      - the squadron explodes, which **ends that strafe**;
      - the explosion **races up the feed line into his shoulders**, and **the boss takes damage**. Each hit shows: the first blows out one shoulder's pipes, the second the other's, and the third **bursts the suit open**, burning the man inside: the second stage's entrance;
      - the runner **falls back to the floor unharmed**. *(Proposed)* The floor under the ship is always clear where they land.
    - **Again and again:** a new Refill Ship comes after each later attack phase, until the suit is destroyed and the second stage begins.
  - **Armor pickups:** the standard armor rule, triggered when the player has **lost all their armor**, with the **longest delay of any boss fight** (owner, October 9, 2026): **22 seconds**.
  - **Second stage, The Magnate** (the fight's halfway checkpoint; direction chosen by the owner, October 9, 2026): the golden suit is destroyed, and the man **pulls himself out of its wreckage, screeching an animal roar of rage**. He's a **twisted abomination, burnt blackish grey** by the suit's destruction, **two to three times the runner's size**.
    - **Look** (owner approved, October 9, 2026): blackish-grey skin cracked like burnt paper or cooled slag; splashes of the suit's gold melted onto him (dull, never glowing); **half of the calm golden mask fused to one side of his face**, dull red tear and all, the other half his real face, roaring; his weak points the **glowing red ports along his spine** where the suit plugged into him; the cape's remains as **burgundy tatters trailing smoke**. **No glowing embers** (orange is a hazard colour). Optional: cracks leaking the cult's **warm white** glow, as if the broadcast lives inside him (checked against the runner's own glow).
    - **The tentacle pipes** turn out to be **cables wiring him into the broadcast**: he is the **source of the feed** on every screen.
    - *(Proposed)* **The transition:** the third ship's blast bursts the suit open; its golden plates fall away and the empty suit crashes down beside the causeway. The Magnate claws his way out, roars, and leaps over the runner to land behind them. The checkpoint is here.
    - *(Proposed)* **The same open causeway:** stage 2 stays in the Grand Court with no side walls, like stage 1. With walls, the wall hop (§3) would let a runner wait out every attack on a wall. His "walls and ceilings" are the balustrades, the towers' faces and the high arches over the causeway, all out of the runner's reach.
    - **A chase:** stage 1 is a calm, distant giant the player can't touch; stage 2 flips it. He's fast and feral and **hunts the runner from behind** on all fours, **leaping along the palace's walls and ceilings**. He shows himself the way the Enforcer Truck does (§9.13): he overtakes along a wall or ceiling, lands ahead, then drops back. His **roar** is the audio warning. *(Proposed)* Behind the runner, his shadow and a marker at the screen's bottom edge show his lane, as with the Enforcer Truck.
    - **Beating him is baiting him,** the lesson every earlier boss taught. The player lures him into the arena. Each time he's **stunned**, his weak points are exposed for a **stomp**.
    - *(Proposed)* **Pounce**, his main attack (every phase): with a roar, his marker turns red and he leaps from behind over the runner, **locking onto their lane about a second before he lands**; a red square marks where he'll land, ahead in that lane. Dodge: leave the lane. He crashes down, then bounds off onto a balustrade or an arch and drops back behind.
    - *(Proposed)* **The bait:** a Flying Buttress comes up ahead for every second Pounce. Locked onto the buttress's lane as the runner reaches it, he crashes into the gate, too big to fit through, and is **stunned**: he slumps in its rubble across two lanes, his back to the runner, the red ports on his spine glowing. The runner **stomps a port by jumping onto his back** (from either lane). If they haven't by the time they're nearly on him, he shakes free and leaps away (a miss), and the bait comes around again. While stunned he's solid but safe: switching into him bumps the runner.
    - *(Proposed)* **Cable Lash** (from the second phase of stage 2): running along a balustrade beside the track, he rears back one of his broadcast cables (with a rising crackle) and whips it across every lane ahead: **low, jump it; high, slide under it**. A red line across the floor shows where it will sweep, as with the Floating Head's lasers.
    - *(Proposed)* **Three stomps,** one a phase, each faster and angrier (paces 1, 1.15 and 1.3). After a stomp he hurls himself clear, roaring, and drops back behind.
    - **Owner's playtest (October 9, 2026):** the owner loved the fight, but stage 2 was **too hard to hurt The Magnate**, and felt **slower, duller and less dangerous** than stage 1. Three changes, with the specifics Claude proposed, all approved by the owner the same day:
      - **Claw Slash** (new attack): he **runs up behind the runner and slashes at them with his claws**, and the player has **only a split second to dodge**. The warning: his marker flashes red with a sharp snarl (not the Pounce's roar) and red claw marks flash on the floor of the runner's lane; the swipe comes about half a second later (never sooner at a faster phase), over the runner's lane only and reaching above a jump: **dodge by switching lanes** (or the dash; armor and the shield block it). In the last phase he slashes twice in a row, the second locking onto the lane the runner dodged into.
      - **Screen Storm** (new attack): **TV screens on gold tentacles come crashing down from the sky on either side of the runner**, smashing lots of spots in lots of lanes, so the player has to **dodge and weave**. **Some of the screens hit The Magnate, chipping his health.** They're the feed's own screens, his glitching face on them, hanging from long gold broadcast tentacles out of the dark vault. Each spot is marked by a red square and the screen's growing shadow, with a rising glitch-whine, about 0.9 s before it crashes; a storm drops 10–16 screens over about 5 s, planned so a runner who moves a reaction time after each warning always has a way through. A crash hurts only in its square (and above a jump), shatters the screen, and its tentacle yanks it back up: nothing stays on the track. During a storm he runs close behind the runner where the camera shows him, and about a third of the screens crash on him: each takes about a twelfth of the phase's health (a storm about a quarter), so storms alone can end a phase (as the Floating Head's laser clips a tower on its own); the stomp stays the quick way.
      - **Darker:** the arena gets **about 30% darker once stage 2 starts**, a sign that The Magnate is losing control. It fades down through the transition; hazards and warnings keep their glow; the light comes back as he falls.
      - **More going on:** new beat scripts weave the new attacks between his Pounces, with shorter gaps between beats: phase 4 Pounce, Slash, Screens, Pounce with the bait, Slash, Screens; phase 5 adds Cable Lashes; phase 6 makes the Slashes double.
      - **The stomp easier to read:** while he's stunned, green chevrons on the floor (the game's "jump here" marks, as before the Hostile Takeover's couplings) show where to take off, and the stun leaves time to line up the jump (at least about 1.5 s from the stun to the last takeoff).
  - **Defeat: the feed dies.** When The Magnate falls, **the feed cuts out on every screen in the world**, freeing everyone the cult held. It closes the Cyborg Viewing Devices' story (§5) without words, and leads into the ending. *(Proposed)* The third stomp: he convulses, his cables tear out of his back one by one, and the screens on the towers glitch and go dark, one after another outward. The music cuts out with them. In the silence he collapses on the causeway ahead, the last light in his cracks goes out, and the runner runs past him; then the victory riff.
  - *(Proposed)* **Numbers** (all in data): six phases in the boss's health (three for the suit, three for The Magnate, a sixth each); weapons chip at most one big hit's worth over the whole fight; a payout of 1,000 credits and 10,000 points for the win; par times measured from a clean fight. The Golden Zone's music for now (a final boss theme is a question for the owner).
---

## 11. Art Direction (so far)

- **Theme:** neon cyberpunk future with **big visual shifts between zones** (e.g. clean neon city vs grimy, apocalyptic gangland).
- **Asset approach:**
  - Low-poly models with **glowing (emissive) materials** plus **bloom**, generated by code (exported as `.glb`) or built procedurally at runtime. No Blender required. Headless Blender scripting is an optional fallback.
  - The look must hold up on the **Compatibility renderer** (web and low-end Android). Verify glow/bloom support early.
- **Humanoid animation is the main art risk:**
  - Plan one shared humanoid rig.
  - Possibly use a free animation library rather than hand-authored motion *(decide in the art round)*.
- **LED visor faces:** a cheap, readable, on-theme way to show expressions for all cyborgs.
- **Player character: Razor Echo** (redesigned September 26, 2026, replacing the cyber suit and helmet): based on the owner's concept sheet `docs/art/reference/player_echo.jpg`. Build brief: `docs/art/BRIEF_RAZOR_ECHO.md`. Keep:
  - a **weathered dark-blue trench coat** with **glowing copper and brass conduits** running over it, including a distinctive pattern across the back
  - a **gold/brass cybernetic left arm**
  - a glowing **cybernetic ocular implant** over the left eye
  - a **tactical utility vest**, harness straps and belts
  - **reinforced combat cargo pants**, knee pads and **worn tactical boots** with a mechanical leg brace
  - **spiky black hair** and a scarred face (no helmet)
  
  **Leave out:** the **sword** (the game has no sword), the **holstered pistol**, and the **symbols on the coat's lower half** (the graffiti and the skull emblem), which would be too small to appreciate at gameplay size. **Nothing on the base character may look like a power-up**, so it carries no weapons; owned power-ups are clearly added on top.
  
  **Glow colour:** the copper conduits and the ocular implant are the player's signature glow (replacing cyan), kept soft so bloom never pushes them into gap-edge orange. The enemies' LED faces change from amber to **cold white**, so the player and the enemies never share a glow colour.
  
  The gameplay camera sits behind the player, so the **back view matters most**: the coat's copper conduits and the gold arm must read from behind. The silhouette must still read clearly differently from the enemy cyborgs' screen heads. Customization is still open.
- **Player scale** (owner feedback after the R1 grey box, September 26, 2026): the player looked too big next to the lanes, walls and ceiling. The player (with its hitbox, jump height and fence heights) is about 75% of the grey-box size; the lanes, walls and ceiling keep their size.
- **Music** (decided September 26, 2026): code-generated placeholder loops in the same crunchy 16-bit / heavy-metal style as the sound effects, one per zone plus the menus. Any track can later be replaced file by file with commissioned or licensed music. **The music dips when the player dies**, and the level-complete riff plays in each zone's key. **No more generated songs** (decided September 28, 2026): the owner will provide the game's songs later; until then the game keeps the generated tracks it already has, and no new music is generated (a place that needs a song it doesn't have reuses an existing track or plays none). This applies to songs only (owner, October 9, 2026): there is no reason not to make **new sound effects where the existing ones don't cover a moment properly** (a cinematic's included), in the same style.
- **Explosions** (owner, October 8, 2026): every explosion in the game (the heli drone's crash, the trucks, the Buzz Overdrive, generators, missiles and bosses) is a big, visually impressive **yellow and red fireball**. Reduced flashing softens it.
- **Readability rules:**
  - Hazards keep a consistent color and shape language across zones.
  - Safe things look safe; deadly parts look deadly.
  - Every attack is telegraphed (important under one-hit death).

---

## 12. Approved build defaults

On September 26, 2026 the owner reviewed the builders' placeholders (`OPEN_QUESTIONS.md` §D, "Owner's placeholder review"). Those marked **keep** now count as decided design. Their numbers stay tunable in data, and those marked **tune after playtesting** stay placeholders until the owner has played. The changes the review made are recorded in the sections above.

---

## 13. Glossary

| Term | Meaning |
|---|---|
| **Zone** | A group of 1–3 levels plus a boss, with its own visual skin |
| **Skin** | A zone's visual version of the abstract gameplay pieces |
| **Generator** | The rule-based system that assembles levels from patterns plus a difficulty value, fitted to lane count |
| **Host** | A marked cyborg carrying a Cyborg's Bad Dream |
| **Level score** | Per-run performance number used for stars and leaderboards; never spent |
| **Credits / wallet** | Spendable currency |
| **Net worth** | Credits earned in play and never spent (its own leaderboard) |
| **Invulnerability window** | ~1 second of invulnerability after armor or a shield breaks |
