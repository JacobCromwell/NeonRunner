# Game Design Document — Checkpoint 1

**Working title:** TBD (placeholder: "Neon Runner")
**Status:** Design in progress. Everything below is DECIDED unless marked *(proposed)* or *(open)*. Open items are tracked in `OPEN_QUESTIONS.md`.
**Last updated:** September 26, 2026

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
- **Ramps:** a boosted entry. Hitting one launches the player higher on the wall and adds speed and a score multiplier.
- **Slide:** the player slides downward over **2 seconds**, then drops to the floor.
- **Height:** matters for collision. Timing of entry decides whether you pass above or below a hazard.
- **Wall jump:** pressing jump while on a wall leaps back out toward the lanes.
- **Signs:** block wall entry, and colliding with one causes damage.
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
- **Ceiling hazards** (decided September 26, 2026): ceilings may carry hazards of their own, but none in zones 1–2 *(proposed; owner agreed)*. The owner is planning a **ceiling turret** that fires only at a player on the ceiling (design to come).

### Collision rules (core principle)
- **Damage only on real contact.** Lanes determine movement, not hits. A bullet in your lane that doesn't touch you does not hurt you.
- **Forgiving hitboxes:** damage hitboxes are slightly **smaller** than visuals, erring in the player's favor.

### Other inputs
- **Juggernaut dash:** tap anywhere (mobile) *(PC key open)*.
- **Slow time:** **E** key, **PC only**.
- **Settings menu:** audio volume and **full key rebinding**.
- **Controllers:** stretch goal. All input must go through Godot input actions from day one so it's cheap to add later. Steam Deck is a target of opportunity.

---

## 4. Failure, Death & Revive

- **One hit ends the run**, unless protected by armor or a shield.
- **Falls:** into gaps between trucks or holes in the street, within a lane. Switching lanes into a lane that has a gap under you = fall. Lane switching itself is safe.
- **Invulnerability:** after armor or a shield breaks, the player gets about **1 second of invulnerability** (character flashes).
- **No checkpoints.** Levels are short (**90–150 seconds**). Death restarts the level.
- **On death, the player keeps 20%** of credits collected during that attempt. Completing a level always pays far more, so deliberate dying is never profitable.

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

**Six zones** at launch, in the order below. Each zone has 1–3 levels, never more than 3; see the schedule at the end of this section.

| # | Zone | Mood (reference) | Palette |
|---|---|---|---|
| 1 | **Neon City** | Blade Runner | Keep the current city skin |
| 2 | **Gangland** | Mad Max, but in a cyberpunk setting | Browns and tans |
| 3 | **Marketplace** | A bustling, happy market | Tan, with livelier colours: whites, blue awnings, splashes of colour in shop signs and visible products |
| 4 | **Corporate** | A more oppressive Blade Runner, with corporate and military themes | Steel and gunmetal grey, military olive, cold and sterile white light, and one harsh brand colour (chosen by the art agent, away from the hazard colours) |
| 5 | **Dead Zone** | Eerie, quiet, haunting | Dark black, dark grey and ash grey |
| 6 | **Golden Zone** | Decadent opulence | A white and slightly creamy base with red and gold accents. There must be some gold to show the wealth, but it isn't the only colour. |

**Zone 1: Neon City.** Floor: roofs of trucks driving toward the player; gaps between trucks. Walls: building facades with signs. Ceilings: undersides of low-flying ships.

**Zone 2: Gangland.** Lived in: graffiti and plenty of signs of life. Gangs compete for power there, and some are directly funded by corporate and military interests. Floor: a street, with holes and craters as gaps. Walls: bombed-out building faces. Ceilings: undersides of decaying or bombed-out buildings, overpasses and similar.

**Zone 3: Marketplace.** An open-air market, dustier and dirtier than the city: commercial buildings, lots of signs, casinos and shops. Floor: stall roofs and awnings, with gaps between the stalls *(proposed; owner agreed)*. Ceilings: undersides of buildings, bridges and overpasses, a few ships, and floating advertisements.
- **Citizens:** interesting and funny citizens are **scenery only**, not real 3D characters or anything the player interacts with. They are seen inside the shops along the low part of the walls, as animations that play. They may react to the runner passing (startled, cheering, happy); the goal is to be funny or uplifting.
- **Conditions:** they are added only if they don't noticeably cost performance on mid-range phones and don't add much code complexity.

**Zone 4: Corporate.** Close to the Neon City, but plainly corporate. Corporations and the military are intertwined, so there is a visible military presence. Generic, soulless corporate art. Floor: roofs of maglev trains or plazas *(proposed; owner agreed)*. Ceilings: undersides of buildings, bridges and similar, and occasionally a military ship.

**Zone 5: Dead Zone.** A blackened, bombed-out husk of the city: rubble, embers, smoke and silence, with not much life. Fires are kept minimal. Floor: a rubble street *(proposed; owner agreed)*. Ceilings: only the remains of the destroyed city, such as the undersides of dead buildings and crumbling, charred grey bridges. **The Cyborg's Bad Dream first appears here.**

**Zone 6: Golden Zone.** The city strictly for the elites and corporate bosses, and home of the final boss. The cult is felt everywhere, alongside an extravagant show of opulence and wealth. Floor: golden walkways over water *(proposed; owner agreed)*. Ceilings: undersides of golden bridges, golden archways and other decadent structures.
- **Water:** flows off the sides of the ceilings as waterfalls or fountains. It is **scenery only**, kept sparse, and thinned out if it clutters the view.
- **Final level: the Golden Palace.** The player runs **inside** the palace, which is so huge and grand that its interior is basically the size of a city. It plays like any other level; only the skin is an interior (floors, walls and ceilings are the palace's own halls, galleries and arches). The final boss follows it.

**Colour rule for every zone** *(proposed)*: zones may use colours close to hazard colours (red and gold in the Golden Zone, blue awnings in the Marketplace, fire in the Dead Zone), but only as **non-glowing** materials or dim background elements. Only hazards glow in hazard colours, so pink, yellow and black, red, orange, green and cyan keep their meaning everywhere.

### The cult (decided September 26, 2026)
- The cult is so widespread that it is **the reason the gangsters and cyborg gangsters attack the runner** in the first place.
- **What makes it insidious:** people are completely subservient to its philosophy without realizing that they're in a cult.
- **Symbol and colour:** *(open)*. An art agent will draw up a few options for the owner to choose from.
- *(Proposed)* **Hidden in plain sight:** the symbol is worked into logos, ads and corporate art in every zone, and is displayed openly only in the Golden Zone.

### Level schedule and enemy introductions (decided September 26, 2026)
**Every zone introduces at least one new enemy.** New enemies are preferred over new mechanics. Anything introduced earlier keeps appearing later. Each level introduces about one new thing.

| Zone | Level | New in this level |
|---|---|---|
| 1. Neon City | 1 | The basics (gaps, fences, walls, signs), then basic cyborgs late in the level |
| | 2 | Ceilings and anti-grav pads |
| | 3 | Pulsing fences, window cyborgs and the **hover truck** |
| 2. Gangland | 1 | **Sewer screech** (from manholes) and ramps |
| | 2 | **Octodog** and speed pads |
| | 3 | Fence generators and **heli drones** |
| 3. Marketplace | 1 | A **new enemy** (owner to design) |
| | 2 | Screeches from wall vents in the shopfronts, and a remix |
| 4. Corporate | 1 | A **new enemy** (owner to design) |
| | 2 | A harder remix with a heavier military presence |
| 5. Dead Zone | 1 | Hosts and the **Cyborg's Bad Dream** |
| | 2 | A quiet, eerie remix |
| 6. Golden Zone | 1 | A **new enemy** (owner to design) |
| | 2 | Peak difficulty |
| | 3 | The **Golden Palace**, then the final boss |

**15 levels plus 6 bosses.** A flawless run through every level takes about 35 minutes. With retries and bosses, a first playthrough is estimated at 60–90 minutes.

The owner is also planning a **ceiling turret** (see §3). Which zone introduces it is *(open)*.

**Rules:**
- Identical gameplay behavior under every skin.
- **Obstacles and enemies must be recognizable across zones by color and shape.** For example, pink crackling energy always means electric fence.
- On still streets, add motion effects (debris, speed streaks, camera shake) to preserve the sense of speed *(proposed)*.

---

## 6. Structure, Progression & Replay

- **Zones:** 6 at launch, each with a distinct look (see §5).
- **Levels:** 1–3 per zone, each 90–150 seconds.
- **Bosses:** one at the end of each zone. Each boss is effectively a **standalone mini-game**, very different from the main runner (decided September 26, 2026). Designs come later; the build leaves a slot for each.
- **Cinematics:** short, minor cinematics between levels and zones give a sense of progression (decided September 26, 2026). Content comes later; the build leaves slots for them.
- **Estimated first playthrough:** roughly 20–50 minutes. This is a known risk for a paid Steam game (Steam's refund window is 2 hours of play), so replay value is critical.
- **Levels are built by a rule-based generator** from obstacle and enemy patterns plus a difficulty value, fitted to the device's lane count.
  - **Campaign:** fixed seeds (same layout every attempt).
  - **Endless mode:** random layouts.
  - Each level's difficulty can be tuned individually, with an automatic curve making each level slightly harder than the last.
  - Because lane counts differ, "level 5" on PC is not identical to "level 5" on mobile. This is intended: PC is harder.
  - Handmade set pieces (e.g. boss arenas) are allowed.
- **Replay features:**
  - Star ratings or grades per level
  - Harder difficulty tiers after completing the game
  - **Endless mode**
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

### Breakable (break when used, then buy again)

| Item | Behavior |
|---|---|
| **Armor** | Blocks one **enemy attack or electrical hazard**. Does NOT block solid collisions (signs, trucks, walls) or falls. |
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

| Target | Laser tier 1 | Missile tier 4 |
|---|---|---|
| Hover truck | 15 | 5 |
| Heli drone | 15 | 5 |
| Octodog | 5 | *(scale)* |
| Sewer screech | 1 | 1 |
| Cyborg | *(open)* | *(open)* |

---

## 9. Enemies & Obstacles

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
  - Destroyed by weapons, a **stomp**, or the **dash**.
  - Sends out an **EMP** that disables fences within a short radius for the rest of the level *(assumed duration)*.
  - The EMP also dissolves the Cyborg's Bad Dream.

### 9.2 Cyborg (early; scales through the campaign)
- **Look:** humanoid.
  - **Face:** an **LED visor/screen face** showing simple expressions.
  - **Zone variants:** sleek citizen in city zones; patched-together scavenger in grimy/gang zones, with a cracked, flickering visor.
- **Movement:** stands mostly on **truck roofs** and moves slowly toward the player, dropping behind quickly.
- **Attack:** loosely aimed laser bolts in **bursts of 2–3**, then a pause to reload.
  - Each burst has a **visible charge-up** (arm cannon glow).
  - Bolts are slow enough to dodge by switching lanes.
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
  - Weapons also work (15 shots at laser tier 1, 5 at missile tier 4).
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
  - Weapons: 5 shots at laser tier 1.
  - Claws kill it (**claws beat tentacles**), and the dash kills it.
  - **Baiting it into a gap kills it** (skill bonus). The generator sometimes places Octodogs near gaps for this.
- **Stomping without claws:** the tentacles grab the player, causing damage.
- **Armor / shield:** blocks one lunge or grab.

### 9.5 Sewer Screech (first appears in Gangland 1; rare in city)
- **Look:** slimy, diseased vermin with **rows of spines** on its back.
- **Where it comes from:** manhole covers in the floor (street zones) or vents at the bottom of walls. In city zones, it's rare and wall vents only.
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
  - Weapons: 15 shots at laser tier 1, 5 at missile tier 4, deliberately slow so the pad remains the satisfying route.
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
  - **Auto-fire never targets hosts**, and missile splash never damages them. Killing a host is always a deliberate choice (stomp, claws, or dash) and earns a big score bonus.
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

### 9.8 Ceiling Turret (owner, September 26, 2026; name and first zone open)
- **Where:** a ceiling hazard. It **pops out of the ceiling's underside** (a ship's hull, or whatever forms the ceiling in that zone) and stays stationary.
- **Look:** a round, dome-shaped body with a cannon or gun coming out of its chest.
  - **Mechanical** in most zones.
  - **Creature version in Gangland and the Marketplace:** more animalistic, as if alive, a bit cutesy and silly, like a furry creature. It keeps the same dome body and chest cannon, so it reads as the same enemy (readability rule).
- **Attack:** fires at the player **the same way the cyborg does** (a visible charge-up with a sound, a short burst of bolts, then a pause), and is **slightly more accurate** than the cyborg. It should **not** be a difficult enemy.
- **Dodge:** by dodging its shots.
- **Kill:** claws, the dash, a stomp, or **5 shots** at laser tier 1.
- **Armor and shield:** both block its shots.
- **Scaling:** across the campaign it fires somewhat faster and takes slightly more damage to kill, but never by much.
- *(Open)* whether it fires only at a player on the ceiling, what touching its body does, how many can share a ceiling, which zone introduces it, and its name.

---

## 10. Bosses (partial)

- **General:**
  - One per zone.
  - Each boss is a standalone mini-game with its own rules and scene, not a variant of a normal level (decided September 26, 2026).
  - Unique scripted encounters (handmade arenas are allowed within the generator system).
  - Bosses ignore claw contact kills.
  - Every boss must be beatable using only the power-ups granted before the fight.
- **Floating Head:** a monstrous floating head ahead of the player. The player dodges projectiles and **jumps on weak points** to defeat it.
- **Sewer Swarm:** a mutant horde rising from the sewers.
  - It builds up on both sides, and a mob attacks. The player must dispatch the mob while moving forward, as the horde shifts **ahead of and behind** the player dynamically.
  - **Implementation:** 4–5 gameplay entities ("clusters"), each rendered as many screech-variant creatures using MultiMesh plus a shader for per-creature motion. It looks like hundreds, but only 4–5 are simulated.
  - The heavy missile gets bonus damage against it.
  - Needs early performance testing on mid-range phones.
- **Remaining bosses:** *(open)*

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
- **Player character** (decided September 26, 2026): a **human runner in a cyber suit** (jacket, helmet with a glowing visor). The silhouette and visor must read clearly differently from the enemy cyborgs' LED faces. Name and customization are still open.
- **Player scale** (owner feedback after the R1 grey box, September 26, 2026): the player looked too big next to the lanes, walls and ceiling. The player (with its hitbox, jump height and fence heights) is about 75% of the grey-box size; the lanes, walls and ceiling keep their size.
- **Music** (decided September 26, 2026): code-generated placeholder loops in the same crunchy 16-bit / heavy-metal style as the sound effects, one per zone plus the menus. Any track can later be replaced file by file with commissioned or licensed music.
- **Readability rules:**
  - Hazards keep a consistent color and shape language across zones.
  - Safe things look safe; deadly parts look deadly.
  - Every attack is telegraphed (important under one-hit death).

---

## 12. Glossary

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
