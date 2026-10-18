# Architecture: Economy and saving; platforms and build flavors; the web demo

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Economy and saving

`Profile` (`scripts/app/profile.gd`) keeps earned and purchased credits apart (net worth = earned, unspent,
plus what was spent on cosmetics, `cosmetic_spent`: an outfit never lowers it), item tiers and stock, equip toggles, records per difficulty tier, settings and stats.
`SaveService` writes it to `user://profile.json` (with a backup). `Loadout` is what one run carries:
owned, switched-on items; every shield in stock (they stack, up to its max_stock) and one charge of the other breakables per attempt; and the free armor every run
starts with (GDD §4), whatever the profile, settings or flavor. The shop (`ShopScreen`, the catalog's
items) sells the permanent items tier by tier, among them the armor upgrade (GDD §8: four tiers; hits
and waits in `GameRules`; prices in the catalog, laid against the campaign's economy by R7 and rebalanced
for all eight zones by I7, still DESIGN-TBD pending the owner, items 846–850 in `docs/OPEN_QUESTIONS*.md`), and the breakables
(shield, grapple, revive) as stock. `tools/measure/economy.gd` reads a campaign's credits, payouts and the
shop's prices together (tasks R7, I7): per level and zone, the credits available, a good run's share of
them, the finish payout and what a death or quit pays, the running wallets of a typical and a weaker player
who finish every level once, and the first level each tier is in reach of (the model is
`tools/measure/economy_model.gd`, shared with `test_economy`).

**Cosmetics (task M1, GDD §8, "Cosmetics"; the owner, October 18, 2026).** Looks for the runner sold in their own
Cosmetics section of the shop, after the power-ups: each is **bought once with credits from the same wallet** (the
earned credits first, so that it never lowers net worth) and **kept forever**, and the player picks **one to wear**; Razor Echo's own look is
the free default, always owned, and the way back. They never change gameplay and never reach a run's `Loadout`.
- *Data:* `data/shop/catalog.json` has `default_cosmetic` (Echo's own look: id, name, text, colour) and `cosmetics`, the
  outfits in shop order (`ShopCatalog.cosmetics`, `default_cosmetic`, `cosmetic(id)`; `ShopCosmetic`: id, name, text,
  price, colour). They are **not** in `items`, so `tools/measure/economy.gd` and the economy tests price items only. The
  prices are the owner's: Rex and Camo 3,000, Beach Master, Centurion and Party Wolf 5,000, the last three `DESIGN-TBD`
  (they are meant to be won by challenges, the weekly seed and promoting the game, none designed yet; a `_note` on each
  entry and on the list says so). An id's look is its outfit file (`docs/architecture/characters-ui-audio.md`, The
  runner's outfits); an id with no file yet wears a tinted placeholder, and its card says "LOOK IN PROGRESS".
- *Saving:* `Profile.outfits` (id -> true; Echo's own look has no entry) and `Profile.worn_outfit` (`owns_outfit()`,
  `add_outfit()`, `wear_outfit()` which refuses an unowned one, `worn()`), written in `to_dict()`. The save version is
  unchanged: an older save has neither field and loads as nothing owned, Echo worn, and a save that wears what it doesn't own
  (edited by hand) or a damaged field loads as Echo's own look.
- *Net worth* (M4; owner, October 18, 2026, item 980; GDD §6, §8): **buying an outfit doesn't lower it.** `App.buy_cosmetic`
  pays through `Profile.spend_on_cosmetic()`: the wallet loses the price and the earned part spent is added to
  `Profile.cosmetic_spent`, so `net_worth()` (the leaderboard's value, what `App` submits after a run and the shop's NET WORTH
  label) is `earned + cosmetic_spent`; bought credits are never in it. `lifetime_spent` still counts the purchase.
  **An outfit spends the earned credits first, then bought ones** (an item spends bought credits first): that follows from item
  980. With the bought credits first, an outfit would leave earned credits in the wallet for the next item to spend, and the
  outfit would lower the net worth after all (earned 2,000 and bought 3,000: Rex, then a 1,500 item leaves 500, where the item
  alone leaves 2,000); earned first, the bought credits are what the item spends and both leave 2,000. *Old saves:*
  `cosmetic_spent` is a new field with a default and the version is unchanged (as the outfits were); a save without it (or with
  a damaged one) works it out when it loads (`Profile._owned_outfits_cost`): the catalog prices of the outfits it owns, never
  more than its `lifetime_spent` and never more than the earned credits it has spent (`lifetime_earned - earned`), so the
  owner's own save, which paid with earned credits, gets exactly what it paid back in its net worth, and the net worth given
  back never goes past `lifetime_earned`. A save from before the outfits has none and gets 0. The old buy spent bought credits
  first (mobile) and a save can't say which credits paid what, so an outfit paid with bought credits there gets back only what
  the earned spending reaches: possibly less than it cost, never bought credits in the net worth. An outfit won rather than
  bought (later) never reaches `spend_on_cosmetic`, so it adds nothing.
- *Flow:* screens only call `App.buy_cosmetic(id)` (once, with enough credits, never the free default; plays
  `ui_buy`; it is worn right away, the owner's answer to item 981) and `App.wear_outfit(id)` (owned only; `ui_equip`), both saved and followed by
  `profile_changed`. `App.sync_outfit()` makes `PlayerOutfits.worn` (what every new `PlayerAvatar` wears) the profile's
  outfit; it runs at start and after a wear, and a test or tool that swaps `App.profile` calls it.
- *The shop:* `ShopScreen` has a COSMETICS section after the breakable items (before the credit packs), a `CosmeticCard`
  (`scripts/ui/widgets/cosmetic_card.gd`, `shop.cosmetic_cards`) for Echo's own look and each outfit. Its one button follows
  the state: the price (disabled, with "NOT ENOUGH CREDITS", when the wallet is short), WEAR once owned, TAKE OFF on the worn
  one (Echo's own card says WORN and can't be taken off). It is an item card's look (the theme's `ItemCard` frame, fonts and
  button, about the same height) 1.4 times as wide (`CosmeticCard.WIDTH_FACTOR`), so the picture has its room: **the runner
  wearing the outfit** (item 982) where an item has its icon, as tall as the text beside it. The web demo and the mobile shop show it too.
  *Keyboard and D-pad:* left and right on a card's button go to the previous and next card in shop order (along the row, then
  on to the next one; they stop at Echo and at Party Wolf), set in `ShopScreen._link_cosmetic_cards()`: the cards are wider than
  the items', and Godot's own nearest-button search jumped to the items above and below. Up and down are left to that search:
  they find the card above or below, the items above the first row, nothing below the last. `test_cosmetics` drives `ui_left`,
  `ui_right`, `ui_up` and `ui_down` over the six cards at 1280x720, 1706x720 and a phone held either way.
- *The previews* (M4; owner, October 18, 2026, item 982; `scripts/ui/widgets/outfit_preview.gd`, `outfit_stage.gd`,
  `outfit_stills.gd`): the picture is an `OutfitPreview`, the runner in a run pose turned three-quarters to the camera on a
  little lit stage (a pedestal, a backdrop, two lights, no shadows), no power-ups on. **At rest it is a still**: `OutfitStills`
  draws each outfit once per pixel size on one shared `OutfitStage` (a `SubViewport` with a world of its own and a
  `PlayerAvatar` built for the outfit), reads it back as a texture and keeps it for the session, one picture every four frames.
  **The pictures are drawn lazily:** a preview asks for its still only when it is on show or about to be (within a fifth of
  the scroll view's height of it, `OutfitPreview.VIEW_MARGIN`, checked when the list scrolls or its content changes), so a shop
  opened on its power-ups builds no avatar and draws no viewport at all and the Cosmetics' six pictures are drawn as the
  section scrolls into view; from the second visit they cost nothing (the shop is shown after every death). A request
  nobody wants when its turn comes (the card closed, a size the window has left) is dropped at once, without the wait between
  pictures, so a burst of stale ones never holds up the ones that count. **The card the pointer is over or the focus is on runs
  and turns:** `ShopScreen` keeps the cards that have either (`CosmeticCard.interest_changed`) and makes the latest one's
  preview live (`set_preview_live`), so there is one live preview at most; it builds its own stage the first time (one
  avatar, one viewport drawn every frame), and a stopped stage is kept for the next hover only for the latest preview (another
  one stopping frees the older). The live runner turns all the way round, so the camera is far enough back (3.6 m) for a
  long coat's tails and the trailing leg to clear the frame side-on. The render is the card's size in pixels times the
  screen's scale (at most 2x), so a phone's magnified menu stays sharp and a dense screen is no dearer. Where nothing draws (the
  headless tests) the queue still runs and finishes with no texture, and a stage that is not live does not process.
  *Cost* (`tools/measure/shop_preview_cost.gd`, measured under Xvfb with Mesa's llvmpipe, a software rasteriser on four CPUs,
  so read the times against the same run on main, not against a phone; 1280x720, Camo's card focused for the live preview):
  opening the shop costs what main's does (the call 22 to 39 ms, no picture drawn); the cards at rest add no draw call and no
  frame time; one live preview adds 20 draw calls and about 1,900 triangles and, in software, about 8 ms a frame on both
  renderers (all six live at once were 72 to 78 ms against 30, which is why only one runs); when the Cosmetics first scroll
  into view the six pictures are drawn one every four frames, each about 50 to 95 ms on top of its frame here (the outfit's
  meshes, the avatar, the draw and the read-back), and the first also pays the body shader's first compile on the 3D side (about
  1.3 s in software on Forward+, 0.2 s on Compatibility; a real GPU compiles it far faster, and a first run would pay it anyway).
  Looked at on both renderers at 1280x720 and on phones (844x340 and 390x844): `build/m4/` (not kept in the repo),
  `tools/showcase/screens_showcase.tscn -- --screen=shop --scroll-end [--focus-outfit=<id>] [--hover-outfit=<id>[:button]]
  [--phone --flavor=web_demo]`, with `--rendering-method gl_compatibility` for the other renderer.
- *Tests:* `test_cosmetics` (the profile, old saves and their net worth, the save file, buying and the net worth it keeps,
  the leaderboard value after a run, wearing, the shop's cards and their previews: one per card in its outfit, a still at rest,
  none drawn until the section is scrolled to, then each once, one live at most, one stopped stage kept, the stage cheap and
  power-up-free, stale requests dropped, a late picture fading in; keyboard and D-pad navigation over the cards) and
  `test_outfits`; `test_economy` covers `spend_on_cosmetic` (earned credits first, net worth neutral).

**Approved early-economy revision (October 3, 2026; pre-density earnings snapshot).** The owner's answers in
`docs/USER_REQUESTS.md` supersede the historical R7 early-affordability assumption: City 1 stays
55 seconds, its lower earnings are intentional, and tests change instead of rewards or prices.
After the approved additive 30% floor-gap changes and Zone 2+ playable wall gaps, measured with
`--lanes=5 --seeds=0 --share=0.7` (native campaign seeds, default difficulty, no purchases or boss
payouts), City 1 has **389** available credits, **272** collected and a **372** wallet including
its unchanged 100-credit finish bonus. City 2's wallet is **833**, City 3's **1,495**: Armor I
at 350 still fits City 1; Laser I at 900 first fits City 3, not City 2 (it later rose to 1,800, so it
first fits the campaign's 4th level, Gangland 1: the figures below are as measured then, the placements
now are in the I7 section). Only that affordability deadline changes; claws still fit Gangland 2, and
every catalog price remains attainable within one clean playthrough (**11,877** total).
The isolated duration comparison disables additive floor gaps on in-memory copies only: 110 seconds
earns 556 available credits / 489 wallet, versus 55 seconds' 341 / 339. This historical controlled
comparison is not the current post-gap wallet. Economy tests retain the other affordability,
death-versus-finish and whole-playthrough guards, plus a shortening-driven earnings regression.
The subsequent danger-density overlay can move collectibles around new hazards, so the figures above
are historical rather than freshly measured totals. It changes neither duration nor reward tables,
and its added hazards earn no extra risk-credit pay.

**The rebalance for eight zones (task I7; the owner's answer of October 14, 2026, GDD §7; DESIGN-TBD, questions in
items 846–850 in `docs/OPEN_QUESTIONS*.md`).** The prices and payouts were set for a two-zone campaign.
- *How a tier is read.* Tiers are bought in order, so a tier costs its **line total** (its price and every tier
  before it). R7's tool read each tier's price alone, which put the Heavy missile at level 13 when owning it costs
  18,300, more than a typical player earns from the levels of a whole playthrough (16,343 before I4). A tier
  **first fits** at the first level (the volleyball match counted) where the running wallet covers its line total.
  That is **affordable after finishing that level, so usable from the next.** The pinned wallet leaves out the
  boss payouts, because the owner's October 3 anchors were measured "with no purchases or boss payouts"; but a boss
  pays on the win and the next zone opens only after it, so every player past a boss has been paid, and the
  "+boss" reading (shown beside it) is the shop a player really has: for the capstones it is up to three levels
  earlier. The **typical** player (`tools/measure/economy_model.gd`) keeps 70% of each level's credits, never dies,
  wins the whole match (400) and every boss, takes the treasure stashes at the same share, uses no magnet and buys
  nothing along the way; the **weaker** one keeps the two-star line (45%), takes no stash, fails every level twice
  first (each try pays 20% of what it had) and wins two match points.
- *Treasure stashes (task I4).* A stash (`LevelLayout.total_credit_value()` less `star_credit_value()`: 200 to 300
  credits a level from Casino 1 on, 5 and 6 lanes only) sits on an optional ceiling route, so the model keeps it
  apart: the typical player takes it, the weaker one and 3 lanes have none. It lifts a typical playthrough from
  16,343 to 18,382 and pulled Armor IV and the Heavy missile two levels early, which is why they moved.
  DESIGN-TBD (items 846–850 in `docs/OPEN_QUESTIONS*.md`).
- *Level stars (task N2's audit, the owner, October 18, 2026: every star has to be earnable).* A level's stars are the
  run's score against `GameRules.two_star_share` (0.45) and `three_star_share` (0.75) of `max_credit_score`; the score
  counts kills (a stomped Cyborg 200 + the stomp's 50, `data/enemies/*.tres`) and the ramps' double credits as well as
  credits, so the line is cleared on more than credits. Measured on every campaign level (the generator's layouts at 3, 5
  and 6 lanes, two seeds each; a best lane path through the floor credits, a switch of n lanes costing n lane switches' metres,
  hazards ignored): in City 1 and 2 the best floor line is 81-125% of the three-star line (it reaches it in 6 of the 12
  builds); from City 3 on it reaches 25-98% (the later levels put more of their credits on ceilings, wall runs and gap and
  fence arcs than on trails, and a floor line doesn't take the first two). Where the floor line falls short, the line also
  asks for one or two stomped Cyborgs (every shipped 5-lane build has two or more; the thinnest build of any lane count and
  seed, one Cyborg, has ceiling and wall credits to make up the rest) or a ceiling or wall run. No level's line is out of reach, and none is only reachable by a stash (left out of the best score, I4). The
  volleyball match's stars are by the match (`docs/architecture/mini-games.md`), a boss's by its par times or hits
  (`docs/architecture/bosses.md`, Stars).
- *Levels* are numbered in play order: City 1-3 are 1-3, Gangland 4-6, Marketplace 7-8, Casino 9-10, Corporate
  11-12, Beach 13-15 (the match is 14), Dead Zone 16-17 and Golden 18-20.
- *Where each tier first fits* (5 lanes, each level's own seed; `test_economy.gd`'s `FIRST_FIT`, give or take one
  level, and `IN_TIME` for the "+boss" column). Held: everything but the dash and two prices (Armor I 350, which fits City 1, the October 3 revision;
  Laser I 1,800, first affordable at level 4). The dash is the owner's (task L8): its four prices are 300 / 450 /
  600 / 700 (October 17, 2026), so it first fits at City 1, City 2, City 3 and Gangland 1. It is also the first
  item in `data/shop/catalog.json`, and the shop lists the permanent items above the breakable ones, so its card
  is the very first on the screen.
  Moved: **Armor IV 6,000 to 6,500** (it would fit the volleyball match, by 23 credits) and **Heavy missile 9,500 to
  7,000** (it would first fit at Golden 3). Slow time stays 2,400.

| Tier | Price | Line | Affordable after | Usable from | With boss payouts, after | Weaker player |
|---|---|---|---|---|---|---|
| Armor I / II / III / IV | 350 / 1,700 / 3,400 / 6,500 | 350 / 2,050 / 5,450 / 11,950 | 1 City 1 / 4 Gangland 1 / 8 Marketplace 2 / 15 Beach 3 | 2 / 5 / 9 Casino 1 / 16 Dead Zone 1 | City 1 / Gangland 1 / Marketplace 1 / Beach 1 | 2 / 5 / 10 / 18 |
| Laser, Enhanced laser | 1,800 / 2,200 | 1,800 / 4,000 | 4 Gangland 1 / 7 Marketplace 1 | 5 / 8 | City boss / Gangland 3 | 4 / 8 |
| Missile, Heavy missile | 4,800 / 7,000 | 8,800 / 15,800 | 11 Corporate 1 / 18 Golden 1 | 12 / 19 Golden 2 | Casino 2 / Dead Zone 1 | 15 / beyond (17,805 with the bosses) |
| Claws | 2,600 | 2,600 | 5 Gangland 2 | 6 | Gangland 1 | 6 |
| Dash I / II / III / IV | 300 / 450 / 600 / 700 | 300 / 750 / 1,350 / 2,050 | 1 City 1 / 2 City 2 / 3 City 3 / 4 Gangland 1 | 2 / 3 / 4 / 5 | City 1 / City 2 / City 3 / Gangland 1 | 1 / 3 / 4 / 5 |
| Magnet I / II / III | 700 / 1,600 / 3,200 | 700 / 2,300 / 5,500 | 2 City 2 / 4 Gangland 1 / 8 Marketplace 2 | 3 / 5 / 9 | City 2 / Gangland 1 / Marketplace 1 | 2 / 5 / 10 |
| Slow time (PC) | 2,400 | 2,400 | 5 Gangland 2 | 6 | Gangland 1 | 5 |

- *What each placement answers* (GDD §5's schedule). Where "usable from" is after the enemy debuts, the tier is in
  time only on the "+boss" reading:
  - claws against the Octodog's tentacles (debuts in Gangland 2, level 5): usable from level 6, but affordable
    after Gangland 1 once the City boss has paid;
  - the Enhanced laser against the Barnacle Turret (Marketplace 1, level 7): usable from level 8, or from level 7
    on the "+boss" reading (affordable after Gangland 3);
  - the Missile against Buzz Overdrive (Corporate 1, level 11): usable from level 12, or from level 11 on the
    "+boss" reading (affordable after Casino 2);
  - the dash (the owner: first in the shop, to be bought early, so a player has it before the first boss): tiers I to
    III are affordable by the end of City 3, before the City's boss pays, and IV after Gangland 1 (on the typical
    wallet it is 2,045 with the City boss paid, 5 credits short of the 2,050 line, so it needs Gangland 1's payout),
    well before the Corporate dash walls (level 11);
  - Armor III from the Casino's mixed crowd, and Armor IV from the Dead Zone, whose Bad Dreams ignore weapons;
  - the Heavy missile from Golden 2, where the Sentinels (17 shots at tier 1) debut with peak difficulty; Golden
    1's Resonator waves come a level earlier. On the "+boss" reading it is in reach after Dead Zone 1;
  - Slow time (GDD says only "PC only, cooldown-based") and the magnet are not tied to an enemy.
- *Wallets at each zone's end* (typical, no boss payouts / with them; weaker, the same; 5 lanes, re-measured October 18,
  2026, the same on PC and mobile): City 1,545 / 2,045 (1,275 / 1,775); Gangland 3,798 / 4,798 (3,147 / 4,147);
  Marketplace 5,644 / 6,644 (4,690 / 5,690); Casino 7,892 / 9,392 (6,243 / 7,743); Corporate 9,851 / 11,851 (7,702 /
  9,702); Beach 12,479 / 14,979 (9,468 / 11,968); Dead Zone 14,872 / 17,872 (11,177 / 14,177); Golden 18,350 / 22,350
  (13,805 / 17,805).
- *Payouts held.* The completion bonus stays 100 + 25 a level (City 1's 100 is the approved early revision, and a
  steeper slope moves only the late tiers: 35 a level puts Heavy missile at level 17, 15 at level 19) and the boss
  payouts stay 500 (1,000 for the last). The prices were placed against them. A boss pays 500 whatever the zone:
  77% of a City 3 finish, 46% of a Dead Zone 1 finish (items 846–850 in `docs/OPEN_QUESTIONS*.md`, question 3).
- *A menu, not a checklist.* The whole permanent catalog costs 40,300 (PC), 2.2 playthroughs of a typical player
  (1.8 with the bosses): the first-fit levels say when a tier is in reach if saved for, and a player who buys
  along the way owns only part of it after one playthrough. Every completion pays again, so the rest is about 22
  replays of a level that pays 1,000 (18 if the first playthrough's boss payouts are counted).
- *Mobile* (measured October 18, 2026: `tools/measure/economy.gd --mobile=true --lanes=5 --seeds=0 --packs`). Mobile
  runs 5 lanes like PC (GDD §3), so its levels, stashes and wallets are PC's to the credit (18,350 for a typical
  player's levels, 22,350 with the bosses; the weaker player 13,805 / 17,805) and every tier first fits at the same
  level as on PC. Only the catalog differs: no slow time, so its permanent tiers cost 37,900 (2.1 playthroughs of a
  typical player, 1.7 with the bosses; the weaker one 2.7 / 2.1). Nothing is needed to progress (GDD §8), and a
  $0.99 pack (1,000) is 1.1 typical finishes (reached by City 3), a $4.99 crate (6,000) 6.4 (reached by Casino 1):
  neither looks forced. (At 3 lanes, mobile's count until then, a playthrough paid about 20% less, no stashes, and
  tiers fit up to two levels later; `test_economy` still checks that 3 lanes reach the early tiers.)
- *Breakables.* Shield 400, grapple 250 and revive 600 stay under a finish and a half of a typical player from City
  2 on; all three together are 2.4 finishes in the City and 1.0 to 1.7 after.

The save has a version (`Profile.VERSION`, now 3). `Profile.from_dict()` brings an older save up to
date as it loads (`_migrate`): version 1's armor stock (armor was a breakable then) is paid back in
earned credits at the 150 each it cost (`V1_ARMOR_PRICE`, the only price it ever had), the purchases
leave `lifetime_spent`, and its old equip toggle goes, so an upgrade bought later starts switched on.
**Saves from before the Casino** (version 2 to 3, task K2): The House moved from the Marketplace to the
Casino, so every tier's `marketplace/boss` record becomes `casino/boss` and the `hint/marketplace_boss...`
keys `hint/casino_boss...`; a finished `marketplace/outro` (which then came after The House and led to
Corporate) also counts as `casino/outro`, so Corporate's intro, whose step before is now the Casino's
outro, stays open. `App.step_unlocked` keeps a step the player has done open even when the step before it
isn't (only a save from before steps were added ahead of it can have that: the moved House record, done
while the Casino's levels aren't), so a save keeps every step it had reached, and Continue leads into
the Casino (`test_campaign`, `_test_old_saves`).
**Saves from before the volleyball match** (version 3 to 4, task D10e): the Beach's volleyball match came in as Beach
2, so Sunset Strip moved from `beach/2` to `beach/3`, and every tier's `beach/2` record becomes `beach/3`'s. The new
Beach 2 is open (Beach 1 is done) and is the first step not done, so Continue leads to it (`test_volleyball`,
`_test_saves`; `test_campaign` checks the version).
A change to the save's format bumps the version and adds its step there, with a test.

## The weekly challenge

**The weekly challenge** (task N5; GDD §6, Replay features; the owner, October 18, 2026): one fixed level a week, the same
for every player, with a leaderboard for that week. Everything about it is in `scripts/weekly/` and `data/weekly/`; the
questions it leaves open are in items 1025-1041 (every placeholder is data, and the code that holds one carries a
DESIGN-TBD with its number).
- *Data* (`WeeklyChallenge`, `data/weekly/weekly_challenge.tres`, `@export_range` on the numbers): the calendar
  (`epoch_unix`, `week_seconds`: weeks open Monday 00:00 UTC, week 0 on October 19, 2026, DESIGN-TBD), the level
  (`lanes` 5 on every platform, `density_step` = `golden/2`, `source_levels`), the kit (`kit`: Armor IV and Juggernaut
  dash IV), the rewards (`first_clear_credits` 1,000, `top_places` 3, `reward_kind`, `reward_check_weeks`) and the unlock
  (`unlock_step` = `city/boss`). `App.weekly` holds it; `WeeklyWeek` is one week (its index, entry, zone, seed, dates).
- *Which level a week plays.* `data/weekly/weekly_seeds.json` is the **shipped seed list**: `{zone, seed}` entries, and week
  N plays entry `N mod size` (`WeeklyChallenge.week`), never a level worked out from the date. The list is the campaign's
  eight zones in order, four seeds each (32 weeks, then it goes round again), so the weeks rotate through the zones and
  every zone is in from the start. Every entry was built and checked in advance by a written rule (the first four seeds
  of the zone's block that pass every check in at most three generator builds: `tools/measure/weekly_seeds.gd`, which
  also looks for seeds to add; `test_weekly_challenge` and `test_weekly_fairness` check the list). Once the game has
  shipped, only ever add at the end, and see item 1027, for what appending does once the list has wrapped.
- *The level* (`WeeklyChallenge.build_config`). Every stored property of `LevelConfig` is in exactly one of three lists in
  `WeeklyChallenge`, and `test_weekly_challenge` fails on one that is in none, so a new dial forces a decision about
  whose it is: `ZONE_FIELDS` (from the zone's own level in `source_levels`: its features and their pick weights, patterns,
  skin, sky, darkness and open walls; a dial about a zone's own mechanic goes here), `WEEK_FIELDS` (the week's own: name,
  seed, five lanes, no `feature_starts`, no recency curve, not off the curve, no mini-game, every feature must appear) and
  `GOLDEN_FIELDS` (everything else, from the campaign's own configuration of `golden/2`, Sentinel Row: difficulty 0.91,
  enemy scaling 0.94 for fire rate, projectile speed and health, 25 m/s, 150 s, `danger_density_increase` and every pacing,
  density, gap and credit dial). A dial for a feature the zone lacks does nothing (the generator runs a rules script per
  feature the level lists). Generated and played like any level (`LevelCache` keys it by content, so a retry is instant).
- *The run* (`RunContext.Mode.WEEKLY`, `ctx.weekly`, `ctx.weekly_board`): `App.start_weekly()` builds it with the uniform kit
  (`Loadout.weekly(catalog, kit, mobile)`: the free armor under Armor IV, the dash at IV, no breakable and nothing else,
  whatever the profile owns or has switched off). There is **no revive**, from stock or for an ad (`revive_options`).
  Retrying (`App.retry`) starts the current week's level again, so a retry after the week turned over plays the new week.
- *The boards* (`WeeklyChallenge.board_id`): `weekly/pc/<week>` and `weekly/mobile/<week>`, one a week for each platform's
  players, the device's by `App.mobile`. A clear is posted (`Platform.submit_score`), a death or quit isn't.
- *The payout* (`App._settle_weekly`, before the wallet is paid): the credits collected on the way pay **nothing**, on a clear
  or not (a memorised layout would farm them); the week's **first clear** pays `first_clear_credits` once (`Profile.weekly`:
  `cleared`, `paid`, `best`, `attempts` per week; `record_weekly`); every other run pays nothing. The results screen shows
  the payout (or "paid this week"), no stars, and what became of the score (`result.record`: weekly, first_clear, new_best,
  board, submitted, best, paid, closed).
- *The clock* (`App.weekly_state()`, `Profile.weekly_high_water()`): the week is what the device's clock says, so a clock moved
  back must not pay or post a week again. A week **before the schedule's first** (negative index) is never played, paid,
  posted or kept (the screen says when it opens); and weeks only go forward: `Profile.weekly["high_water"]` is the highest
  week played, a week below it is "behind" (the screen says which week it goes on at, PLAY off) and `_settle_weekly` pays
  and posts nothing for it, whatever started the run. A clock moved **forward** still opens each future week once: that
  needs a trusted time through the platform layer (item 1026).
- *The reward hook* (the Leader of the Pack, item 977 in `docs/OPEN_QUESTIONS.md`; the cosmetic is not built): a clear leaves a
  pending record (`Profile.weekly_rewards`: week, board, score, state); `App.settle_weekly_rewards()` runs at start and when the
  weekly screen opens (one pass at a time: a second asks nothing while the first waits on the platform), and for each record
  whose week is over asks `Platform.leaderboard_rank(board)` (a new backend method: 0 until a real platform answers, which
  the stub does only with `report_ranks` on and `board_entries` to rank against). A place in the top `top_places` makes it
  "earned" (kept, `Profile.has_weekly_reward`; `App.weekly_reward_earned`; the screen lists the weeks), another "missed", an
  unknown rank stays pending until `reward_check_weeks` have passed. `App._grant_weekly_reward` is the one place the
  cosmetic will be given from.
- *Gating:* `App.weekly_available()` is false in the web demo (no title button, no screen, no board); `App.weekly_state()` says
  `unavailable`, `locked` (the Floating Head isn't beaten, `unlock_step`), `not_yet`, `behind` or `open`. The title's WEEKLY
  button shows a lock until the Floating Head is beaten and `WeeklyScreen` says what is wrong (`App.show_weekly`).
  `App.now_unix()` is the clock (tests and reviews set `App.clock_override`).
- *Review:* `--weekly` (debug builds) plays this week's level, `--weekly=N` week N's (`--god` and `--nofall` apply; `--lanes` and
  `--full-loadout` are ignored; open whatever the profile); `tools/showcase/screens_showcase.gd` has `weekly`,
  `weekly_locked`, `weekly_results`, `weekly_failed`, `weekly_intro` and `weekly_run`, with `--week=N`.
- *Tests:* `test_weekly_challenge` (every entry of the list generated at five lanes with the campaign levels' fairness checks,
  the config split, the calendar, the rotation, the kit, the payout, the boards, the clock, the unlock, the demo's exclusion,
  the reward hook and the save) and `test_weekly_fairness` (a slow suite: the per-feature checks of the campaign's suites on
  every entry, and each built twice); `test_phone_screens` lays out the weekly screens and the full game's title.

## Platforms and build flavors

`BuildFlavor` (`full_pc`, `full_mobile`, `web_demo`) comes from export feature tags (or
`--flavor=` for testing). `Platform` (autoload) is the only way to reach ads, purchases,
leaderboards, achievements, store links and cloud save; `StubBackend` serves the editor, tests and
the web demo until the real plugins are chosen (risk test R3). The store links are data
(`data/platform/store_links.json`) and open through `Platform.open_store()`, which hands the URL to the
backend's `open_url()`: a portal that restricts outbound links gets a backend of its own, and the stub
records what it opened (`opened_urls`; tests switch `open_links` off so nothing leaves the game).

**The web demo** (GDD §2; task E2) is the "Web (demo)" export preset: the `web_demo` feature tag, the
Compatibility renderer (the web's only one), no thread support (so it needs no cross-origin isolation
headers, as itch.io and the portals serve it), no GDExtension support, and a canvas that follows the
window or a portal's frame (`html/canvas_resize_policy` adaptive). `tools/godot.sh web` exports it
(README, The web demo).
- *What it plays:* the zones marked `in_demo` (the Neon City and its boss); a step past them leads to the
  "get the full game" screen (`App.in_demo_scope()`). No endless mode, and no ads, purchases or
  leaderboards: the platform offers none, and no screen shows any.
- *What it leaves out* (`tools/web/demo_filter.gd`, worked out from the data): the tests, the tools, the
  test boss, the music it never plays: every audio file in the music library's folders that no track
  the demo plays uses, the files of the tracks it never plays wherever they are, and those tracks'
  level-complete riffs; and the zone doodads' picture cards (`assets/sprites/doodads/<zone>.*`) of the
  zones it never shows (`DemoFilter.left_out_art()`; a zone without them would draw the plain default). The tracks it plays are the menus' (`menu`), the City's (`city`, quick play's too)
  and each demo zone's and its boss's (`DemoFilter.demo_tracks()`). `tools/web/update_filter.gd` writes
  the preset's exclude filter from that, `tools/godot.sh web` runs it before every export, and
  `test_web_demo` fails while the preset doesn't match the data. So when a track is replaced (the owner's
  songs, GDD §11: the same file name, or a new file named in `data/audio/music_library.tres`), the filter
  follows the library: a demo track's new file ships, the old file left in its folder doesn't, and another
  zone's new file stays out.
- *A build without some sounds:* `SfxLibrary.has_file()`; `PlayerSfx` readies only the sounds the build
  has, and `MusicDirector.level_complete_sound()` falls back to the E riff when a zone's riff isn't in
  the build. A sound asked for by name whose file is missing still warns.
- *Checks:* `test_web_demo` (the preset, the filter from the data and with replaced tracks, everything the
  demo's scenes, scripts and data reference kept by the filter and loading, the walk from the title to the
  end screen with the sound library as the export has it, no ads, purchases or leaderboards on any screen,
  the store links). `tools/web/check_pack.gd` checks an exported pack from the inside, run by the desktop
  Godot from the pack's folder so `res://` is the pack alone: the demo's music and sounds load, no other
  music is in it, and `tools/web/demo_walk.gd` walks it from the title to the end screen (the City's three
  levels and the Floating Head, with the results and the shop between them, in god mode) with no error or
  warning logged. `tools/web/browser_check.js` drives the release and debug exports in Chromium through
  Playwright (README).
- *In the browser:* `user://` is the page's storage (IndexedDB, under `/userfs/godot/app_userdata/Neon
  Runner/`), written through after each save, so progress survives a reload. Browsers hold sound back until
  the first click, tap or key: Godot creates its AudioContext at start (Chrome notes it's suspended) and
  resumes it on the first input. A phone's browser is a mobile device (`DeviceProfile.is_mobile()`, from the
  engine's `web_android` and `web_ios` tags): mobile's lane count (5 since October 18, 2026), the touch layout and hints.
- *The page's covers* (`html/head_include` in the preset: a style and a script that defines `window.neonPage`;
  DESIGN-TBD, `docs/questions/e2.md` and `l1.md`). Only a phone (a coarse pointer and a screen whose short
  side is 520 CSS pixels or less: a desktop's touch screen is not one) is covered. There are two covers:
  - **"Turn your phone sideways to play"**, the full cover with no way past it: a page whose own shape is taller
    than wide (the game is landscape, GDD §2). In a frame that needs the phone held upright *and* a portrait
    frame; a page that is not framed goes by its own shape alone.
  - **"Play it full screen"**, a card the player can dismiss, for a phone's frame (the game in an iframe, as
    itch.io shows it) that is not about the screen's size: wider than the screen's long side, narrower than
    four fifths of it, taller than its short side (a fixed embed the host page shrinks or crops, or a small
    one). It has a link that opens the game's own address in a tab of its own, where the page is the phone's
    (or `requestFullscreen()` where the browser has it, which an iPhone does not), and "Play here anyway"
    under it, so it never locks anyone out (the dismissal holds until the frame fits or the phone is turned).
    The same card, headed **"Turn your phone sideways"**, is what a *landscape* frame on a phone the browser
    says is held upright gets (a frame's own shape can't show that; a browser that misreports its orientation
    is why this one can be dismissed too).
  A turn changes the page's size a moment after the orientation, so the card (and a change of its wording)
  appears only once two measurements half a second apart agree, where the full cover and "no cover" apply at
  once; "Play here anyway" asks the phone's orientation afresh when it is pressed. The page's text keeps its
  size on the glass in a shrunk frame (`--neon-u`); the card's backdrop covers the whole frame, so the game under
  it isn't live, and the card itself keeps to the part of a tall frame a phone can show (`--neon-box`). Whenever
  a cover appears the page calls `window.neonPage.onCover()`, which the game sets (`WebPage.watch_cover()`,
  `App._on_page_cover()`), and a running level pauses as it does for a phone call, so nothing happens unseen
  behind the cover (a frame keeps its size when the phone is turned, so nothing resizes and only the page can
  say; `App._on_window_resized()` does the same for a page that is itself held upright; `test_app_flow` checks
  `_on_page_cover`). A `blur` sent to the canvas was tried first and did not pause the run: `App` pauses on the
  application's focus loss, which a canvas blur is not. iOS reports `screen.width` and `screen.height` as for
  an upright phone whichever way it is held, so the device's orientation comes from `screen.orientation`, then
  `window.orientation`, and only a framed page uses it. `neonPage.insets()` also hands the game the browser's
  safe-area insets (`WebPage`, Characters, UI and audio, Menus on a phone), and `neonPage.mode()` says which
  cover is up (`''`, `'turn'`, `'fit'`).
- *On itch.io* (task L1): itch.io shows an HTML5 zip in an iframe of the size set on the project page. On a
  phone that frame is the page's problem, not the game's: left at a fixed 960×540 it is shrunk to the screen's
  width, or cropped by the browser's bars, so the game reads a desktop-sized window and the menus come out tiny
  or cut off. What the game does about it is above (the menus are sized for what the screen shows, the card
  offers full screen); what the project page should say is below. Neither a phone nor itch.io's page could be
  reached from where this was built, so the settings are itch.io's documented options as known, tried in
  Chromium's iPhone emulation (`itch_embed`), not on a real iPhone: the checks at the end of this bullet are
  the real test.
  - Upload the zip with `index.html` at its top (`tools/godot.sh web`, then zip `exports/web/`), kind of project
    **HTML**, "This file will be played in the browser" ticked.
  - **Viewport dimensions: 960 × 540** (16:9; the game fills whatever frame it is given, so this is only the
    size of the frame on a desktop page; 1280 × 720 for a bigger one if the page's column is wide enough).
  - **Mobile friendly: ticked.** itch.io then launches the game from a "Run game" tap into a frame that fills
    the phone's page, which is the case the menus are made for (the title whole, 0.65 of a CSS pixel to a UI
    pixel). **Orientation: Landscape** (an iPhone's Safari cannot lock the orientation; the game's own cover
    asks the player to turn the phone).
  - **Fullscreen button: ticked** (a desktop and an Android browser use it; an iPhone has no fullscreen for a
    page, so it does nothing there).
  - "Click to launch in fullscreen" and "Automatically start on page load" are the owner's taste: the first
    tap on the game also lets Safari play its sound (the AudioContext resumes on a touch), so auto-start
    gains nothing on a phone. **Enable scrollbars: off. Enable SharedArrayBuffer support: off**: the demo is
    exported without threads, so nothing uses it, and it only adds isolation headers to the page.
  - Whatever those say, a phone whose frame turns out not to fit gets the "Play it full screen" card, so a
    forgotten setting costs one tap rather than unreadable menus.
  - *To check on an iPhone* (only a real one can say): (1) with "Mobile friendly" on, tap "Run game" and turn the
    phone sideways: the title shows PLAY, LEVEL SELECT, SHOP and SETTINGS and the demo line whole, the shop's
    cards read without squinting, nothing sits under the notch or the home bar, the HUD in a level too;
    (2) turn it upright: "Turn your phone sideways to play" covers the game and a running level pauses;
    (3) with "Mobile friendly" off, the card "Play it full screen" shows over the frame: "Open full screen" opens
    the game in a Safari tab of its own (is the menu then readable? its save is probably separate from the
    frame's: browsers keep a frame's storage apart by the page around it, so progress made in itch.io's
    frame does not show in the tab), "Play here anyway" plays on in the frame; (4) the notch, in both
    Safari's tab and itch.io's full-window frame, in both turns (left and right); (5) that Safari reports the
    phone's turn to the frame (`screen.orientation` or `window.orientation`): if the cover appears the wrong way
    round, "Play here anyway" is still there and the page's `upright()` function is the place to look.
- *A phone's menus* (tasks I3 and L1): held sideways a phone's page is about 844×340 CSS pixels with the browser's
  bars (390 high at most), a third to a half of the 720-pixel layout's height, so the menus were drawn at half size
  (the shop's captions 9 pixels). `UiScale` magnifies them while a screen is open (until a UI pixel is 0.65 CSS
  pixel, counting how small the host page shows the frame); the compact layouts, the scroll net, the touch drags,
  the embed scale and the page's safe areas are in Characters, UI and audio, Menus on a phone. Godot's web build
  reads the page's `devicePixelRatio` through `DisplayServer.screen_get_scale()` and the screen through
  `screen_get_size()`; `browser_check.js phone_menus` (the debug export logs the factor) checks that in Chromium
  at 844×340 with the screen an iPhone reports, and `itch_embed` checks the page in an iframe as itch.io shows
  it: "mobile friendly" (a full-page frame, with and without a notch's insets), a fixed 960×540 embed on an
  iPhone SE (the card, its link, playing on, the menus' size), the same held upright and turned, and a running
  level that pauses behind the card. **What L1 found (the first cause of the owner's iPhone report):** the menus
  were squeezed into the top of the phone by a bottom margin of 40% of its height, because the display server's
  screen and safe area are not the page's (Characters, UI and audio, Safe areas on the web); a fixed embed
  shrunk by the host page was the second.
- *Sound on an iPhone* (task I3; items 827–828 in `docs/OPEN_QUESTIONS*.md`): the demo's sound is all Web Audio (the web default,
  sample playback), which Safari mutes while the phone's ring/silent switch is on. The preset's
  `html/head_include` sets `navigator.audioSession.type = 'playback'` (the Audio Session API; guarded by a
  feature check and a try, set at load, on the first touch, click or key and when the page returns to the
  front), so the demo plays through the switch like a video; a browser without the API skips it
  (`browser_check.js audio_session` checks it with a stand-in for Safari's API, with none, and with one that
  throws; `test_web_demo` keeps the script in the preset). Godot itself resumes the AudioContext on a
  touch's start and end, a key and a mouse press (`DisplayServerWeb`), which iOS accepts at `touchend`. What
  only a real iPhone can say: that Safari applies the type to Web Audio (the likeliest cause of a silent
  phone), and how the demo's memory fares on an older one (a track is held decoded: Characters, UI and
  audio, Audio, On the web). An iPad that asks for desktop sites reports a Mac, so Godot's `web_ios` tag, and
  with it `DeviceProfile.is_mobile()`, is false there: it gets the desktop layout.
- *Touch words:* `DeviceProfile.has_touch()` means a phone, a tablet or a real touch screen. The project lets
  the mouse stand in for touch (`input_devices/pointing/emulate_touch_from_mouse`), which makes
  `DisplayServer.is_touchscreen_available()` true on every desktop and in every desktop browser, so the
  hints go by `has_touch()` and name the keys there.
