# Architecture: Economy and saving; platforms and build flavors; the web demo

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Economy and saving

`Profile` (`scripts/app/profile.gd`) keeps earned and purchased credits apart (net worth = earned,
unspent), item tiers and stock, equip toggles, records per difficulty tier, settings and stats.
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
Cosmetics section of the shop, after the power-ups: each is **bought once with credits from the same wallet** (bought
credits first, as for every item) and **kept forever**, and the player picks **one to wear**; Razor Echo's own look is
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
- *Flow:* screens only call `App.buy_cosmetic(id)` (once, with enough credits, never the free default; plays
  `ui_buy`; it is not worn yet) and `App.wear_outfit(id)` (owned only; `ui_equip`), both saved and followed by
  `profile_changed`. `App.sync_outfit()` makes `PlayerOutfits.worn` (what every new `PlayerAvatar` wears) the profile's
  outfit; it runs at start and after a wear, and a test or tool that swaps `App.profile` calls it.
- *The shop:* `ShopScreen` has a COSMETICS section after the breakable items (before the credit packs), a `CosmeticCard`
  (`scripts/ui/widgets/cosmetic_card.gd`, `shop.cosmetic_cards`) for Echo's own look and each outfit. Its one button follows
  the state: the price (disabled, with "NOT ENOUGH CREDITS", when the wallet is short), WEAR once owned, TAKE OFF on the worn
  one (Echo's own card says WORN and can't be taken off). It is the same card as an item's (the theme's `ItemCard` sizes) with
  the jacket icon (`IconFactory` `outfit`) in the outfit's colour. The web demo and the mobile shop show it too.
- *Tests:* `test_cosmetics` (the profile, old saves, the save file, buying, wearing, the shop's cards) and `test_outfits`.

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
