# Architecture: Economy and saving; platforms and build flavors; the web demo

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Economy and saving

`Profile` (`scripts/app/profile.gd`) keeps earned and purchased credits apart (net worth = earned,
unspent), item tiers and stock, equip toggles, records per difficulty tier, settings and stats.
`SaveService` writes it to `user://profile.json` (with a backup). `Loadout` is what one run carries:
owned, switched-on items; one charge of each breakable per attempt; and the free armor every run
starts with (GDD §4), whatever the profile, settings or flavor. The shop (`ShopScreen`, the catalog's
items) sells the permanent items tier by tier, among them the armor upgrade (GDD §8: four tiers; hits
and waits in `GameRules`; prices in the catalog, laid against the campaign's economy by R7 and rebalanced
for all eight zones by I7, still DESIGN-TBD pending the owner, items 846–850 in `docs/OPEN_QUESTIONS*.md`), and the breakables
(shield, grapple, revive) as stock. `tools/measure/economy.gd` reads a campaign's credits, payouts and the
shop's prices together (tasks R7, I7): per level and zone, the credits available, a good run's share of
them, the finish payout and what a death or quit pays, the running wallets of a typical and a weaker player
who finish every level once, and the first level each tier is in reach of (the model is
`tools/measure/economy_model.gd`, shared with `test_economy`).

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
- *Levels* are numbered in play order: City 1-3 are 1-3, Gangland 4-6, Marketplace 7-8, Casino 9-10, Corporate
  11-12, Beach 13-15 (the match is 14), Dead Zone 16-17 and Golden 18-20.
- *Where each tier first fits* (5 lanes, each level's own seed; `test_economy.gd`'s `FIRST_FIT`, give or take one
  level, and `IN_TIME` for the "+boss" column). Held: everything but two prices (Armor I 350, which fits City 1,
  the October 3 revision; Laser I 1,800, first affordable at level 4; the dash's four prices, the owner's).
  Moved: **Armor IV 6,000 to 6,500** (it would fit the volleyball match, by 23 credits) and **Heavy missile 9,500 to
  7,000** (it would first fit at Golden 3). Slow time stays 2,400.

| Tier | Price | Line | Affordable after | Usable from | With boss payouts, after | Weaker player |
|---|---|---|---|---|---|---|
| Armor I / II / III / IV | 350 / 1,700 / 3,400 / 6,500 | 350 / 2,050 / 5,450 / 11,950 | 1 City 1 / 4 Gangland 1 / 8 Marketplace 2 / 15 Beach 3 | 2 / 5 / 9 Casino 1 / 16 Dead Zone 1 | City 1 / Gangland 1 / Marketplace 1 / Beach 1 | 2 / 5 / 10 / 18 |
| Laser, Enhanced laser | 1,800 / 2,200 | 1,800 / 4,000 | 4 Gangland 1 / 7 Marketplace 1 | 5 / 8 | City boss / Gangland 3 | 4 / 8 |
| Missile, Heavy missile | 4,800 / 7,000 | 8,800 / 15,800 | 11 Corporate 1 / 18 Golden 1 | 12 / 19 Golden 2 | Casino 2 / Dead Zone 1 | 15 / beyond (17,829 with the bosses) |
| Claws | 2,600 | 2,600 | 5 Gangland 2 | 6 | Gangland 1 | 6 |
| Dash I / II / III / IV | 1,800 / 800 / 1,000 / 1,200 | 1,800 / 2,600 / 3,600 / 4,800 | 4 / 5 / 6 / 8 Marketplace 2 | 5 / 6 / 7 / 9 | City boss / Gangland 1 / Gangland 3 / Gangland boss | 4 / 6 / 7 / 9 |
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
  - the dash line (all four by level 8, 9 usable) before the Corporate dash walls (level 11);
  - Armor III from the Casino's mixed crowd, and Armor IV from the Dead Zone, whose Bad Dreams ignore weapons;
  - the Heavy missile from Golden 2, where the Sentinels (17 shots at tier 1) debut with peak difficulty; Golden
    1's Resonator waves come a level earlier. On the "+boss" reading it is in reach after Dead Zone 1;
  - Slow time (GDD says only "PC only, cooldown-based") and the magnet are not tied to an enemy.
- *Wallets at each zone's end* (typical, no boss payouts / with them; weaker, the same): City 1,549 / 2,049 (1,278 /
  1,778); Gangland 3,804 / 4,804 (3,152 / 4,152); Marketplace 5,650 / 6,650 (4,695 / 5,695); Casino 7,919 / 9,419
  (6,263 / 7,763); Corporate 9,888 / 11,888 (7,730 / 9,730); Beach 12,530 / 15,030 (9,505 / 12,005); Dead Zone
  14,935 / 17,935 (11,225 / 14,225); Golden 18,382 / 22,382 (13,829 / 17,829).
- *Payouts held.* The completion bonus stays 100 + 25 a level (City 1's 100 is the approved early revision, and a
  steeper slope moves only the late tiers: 35 a level puts Heavy missile at level 17, 15 at level 19) and the boss
  payouts stay 500 (1,000 for the last). The prices were placed against them. A boss pays 500 whatever the zone:
  77% of a City 3 finish, 46% of a Dead Zone 1 finish (items 846–850 in `docs/OPEN_QUESTIONS*.md`, question 3).
- *A menu, not a checklist.* The whole permanent catalog costs 43,050 (PC), 2.3 playthroughs of a typical player
  (1.9 with the bosses): the first-fit levels say when a tier is in reach if saved for, and a player who buys
  along the way owns only part of it after one playthrough. Every completion pays again, so the rest is about 25
  replays of a level that pays 1,000 (21 if the first playthrough's boss payouts are counted).
- *Mobile.* (Measured when mobile had 3 lanes; mobile now has 5 like PC, owner October 2026, so these figures are history: re-measure with `tools/measure/economy.gd --mobile=true` (which now defaults to `GameRules.lanes_mobile`) before relying on them.) 3 lanes hold no stash and about 20% fewer credits than 5 (14,886 for a typical player's levels, 18,886
  with the bosses; the mobile catalog is 40,650 without slow time), so a tier first fits up to two levels later
  (Armor I at City 2, Armor IV at level 17) and the Heavy missile is out of reach on the levels alone, in reach
  after Golden 1 on the "+boss" reading. Nothing is needed to progress (GDD §8), and a $0.99 pack (1,000) is 1.3
  finishes, a $4.99 crate (6,000) 7.9: neither looks forced.
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
  engine's `web_android` and `web_ios` tags): 5 lanes (like PC), the touch layout and hints. Held upright, the page
  covers the game with "turn your phone sideways" (a style in the preset's `html/head_include`) and
  `App._on_window_resized()` pauses a running level (both DESIGN-TBD, `docs/questions/e2.md`).
- *A phone's menus* (task I3): held sideways a phone's page is about 844×340 CSS pixels with the browser's bars
  (390 high at most), a third to a half of the 720-pixel layout's height, so the menus were drawn at half size
  (the shop's captions 9 pixels). `UiScale` magnifies them while a screen is open (until a UI pixel is 0.65 CSS
  pixel); the compact layouts, the scroll net and the touch drags are in Characters, UI and audio, Menus on a
  phone. Godot's web build reads the page's `devicePixelRatio` through `DisplayServer.screen_get_scale()`;
  `browser_check.js phone_menus` (the debug export logs the factor) checks that in Chromium at 844×340.
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
