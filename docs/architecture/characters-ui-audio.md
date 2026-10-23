# Architecture: Characters, UI and audio

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## Characters, UI and audio

- **Characters:** `HumanoidRig` (`scripts/characters/`) is the procedural rig and pose set behind the
  player model (`PlayerAvatar`: Razor Echo, look in `PlayerSuit`) and the cyborgs (`CyborgBody` with
  `CyborgSuit`: one skeleton, a part set per zone look, one material per cyborg). A look is a
  `HumanoidParts`: `HumanoidPiece` shapes per segment (BOX, PRISM, LATHE, BAND, TORUS, and SHELL, a
  closed sheet cut to an arc), named attachment sets (equipment, zone variants), and optional
  `HumanoidPanel`s. A piece's `glow` and `shine` (polish) ride in the mesh (UV.x, the vertex colour's
  alpha) so a whole segment is one draw call.
  - **Panels** are stiff flaps hinged at the waist (Razor Echo's coat skirt; looks without them are
    untouched). All of a rig's panels are one mesh on the pelvis joint; `update_panels()` (called by
    `animate()`; a user that poses the rig itself with `apply_pose()` calls it after) swings each by a
    pitch and a roll through a damped spring: it hangs toward the feet (on the ceiling too; on a wall it
    sags toward real gravity), follows its thigh, trails in the wind of the run and flares when falling,
    then the leg on its side and the surface push it clear (a hem pushed by the surface trails while
    the runner moves, otherwise folds the way it leans). `humanoid_panels.gdshaderinc` turns each
    panel's vertices by the rig's `panel_rot` / `panel_hinge` arrays, so the material must be the rig's
    own. The numbers are `HumanoidAnimTuning`'s Coat panels group (F6, "Runner animation").
  - **The player's shader** (`humanoid_body.gdshader`) also has a rim light and `glow_albedo` (soft
    trim that shines by its own light).
  - **Colour spaces:** the builder stores vertex colours in linear space; on the Compatibility
    renderer, which works in sRGB space, the rig's shaders (`humanoid_body`, `cyborg_body` and the
    cyborg kit's part shader) convert them back with `humanoid_color.gdshaderinc` (as
    `kit_common.gdshaderinc` does for the mesh kit). The same include's `humanoid_glow()` scales a
    colour uniform into a bright glow in linear light on every renderer, so a glow keeps its hue on the
    web (scaled in sRGB, the cyborgs' red charge-up turned cream). Sums of light (the screen head's
    LEDs averaged far away) are taken in linear light too (`humanoid_to_linear`); dim picture parts
    are brightness as seen, turned into light with `to_linear()`.
  - **Colour rule:** the player's only glow on the base model is its soft copper (`PlayerSuit.GLOW`);
    `test_avatar` keeps it and the effects built from it at least 0.3 from every skin's hazard colours
    and enemy fire on the hue and saturation wheel, and power-up looks never use it.
  - **The cyborgs** (GDD §9.2; tasks P2 and P3): `CyborgSuit` builds one `HumanoidParts` whose
    attachment sets are the looks (`LOOKS`) and their hosts' veins. The looks are the ragged "Static TV
    Head" base (P2, in `cyborg_suit.gd`) and its zone variants (P3), one file each in
    `scripts/enemies/cyborg_looks/`: `brute.gd` (Gangland's Broadcast Brute), `casino.gd` (the
    Marketplace's Casino Mob Enforcer), `vr_runner.gd` (Corporate's Wide-Aspect VR Runner), `burned.gd`
    (the Dead Zone's base, burned out) and `golden.gd` (the Golden Zone's ceremonial enforcer, built
    by `casino.gd`'s `build()` with its own palette). They are the same unit: one skeleton, the same
    poses and hitboxes, the same face expressions, and only the boot soles and the weapon's emitter
    ring and charge orb shared by every look (the soles ground the rig; the charge-up must look the
    same in every zone), so every weapon (the arm cannon, the Brute's pipe gun, the enforcers' drum
    gun, the VR Runner's chrome cannon) ends at the same muzzle (`MUZZLE`). No look is bigger than the
    base. `look_for(variant)` maps a skin's `enemy_variant` to a look: a look's own name picks it,
    `VARIANT_LOOKS` maps the City's and Gangland's older names, anything else wears the base (Zone
    skins lists each zone's value). A look file gives `pieces()` (its set), `veins()` (its hosts' set,
    `host_set(look)`; the burned base's hosts wear the base's `&"host"` set) and `material_params()`
    (its changes to the shader's uniforms over the base's, `look_params()`: the screen's rectangle, wear
    and LED shape, how metallic its polish is, its marked surfaces). The helpers at the end of
    `cyborg_suit.gd` build the pieces: `add`, `pipe`, `bar`, `cable`, `vein`, and `patch` (a flat
    decal, one quad: scorch, trim, engraving, a torn strip) with `facing` to turn it onto a surface.
    A cyborg is 11 draw calls in every look (a window cyborg's upper body 7): hands and feet ride on
    the forearms and shins, and the neck, backpack and cables on the chest. The cables and the shoulder
    hose belong to the chest and end inside the head and the shoulder cap near their joints
    (`HEAD_CABLES`, `ARM_HOSE`), so they stay plugged in however the head and arm turn.
    `cyborg_body.gdshader` draws marked pieces (glow values `SCREEN`, `RING`, `ORB`, `VEIN`, `GLASS`,
    `EMBLEM`, `STRIPES`): the pixel faces of `cyborg_kit.gd` as LED dots (round, or diamonds on the
    enforcers) in the cult feed's cold white on the look's screen (the VR visor has its own face grid,
    `VISOR_FACES`), averaged through mipmaps far away so a face a few pixels across keeps its shape; a
    host's purple static; the switch-off after a defeated cyborg's ERR; the burned screen's flicker and
    crack; the Brute's dim side screens; the Golden Zone's medallion with the cult's emblem (faded out
    below about 24 pixels, as the skins do); and pinstripes. `CyborgPoses` gives every look its
    posture (hunched, a shambling limp, twitches and a tremor added after the blend).
    `test_cyborg_body` runs every check over every look: the hitboxes, budgets and size, the weapons,
    and the colour rules: nothing on a cyborg glows but the cold white face and screens, the red
    charge-up and a host's purple; nothing is copper, purple only on hosts, no hazard or "safe" colour
    anywhere; gold and chrome only as unlit, polished ornament, the grimy looks dull.
- **UI:** a theme built in code (`scripts/ui/theme/`: `UiStyle` in `data/ui/ui_style.tres`,
  `UiTheme`), code-drawn icons (`scripts/ui/icons/`) and a widget kit (`scripts/ui/widgets/`). Screens
  (`scripts/ui/screens/`) extend `ScreenBase`; the HUD is `RunHud`: its protections show the armor's
  hits and, from any hit (task S3, GDD §4: any hit starts the wait), the cooldown ring filling in the
  kit's calm accent until it's back whole, when the icon flashes and the player's `armor_back` plays (a
  latch and a low chime; a hit the armor survives plays `armor_hit`). Worn but not broken, the icon stays
  lit with its hits left (`CooldownIcon.lit_while_cooling`); broken, it dims. Orbitron is for titles and Exo 2
  for text and numbers. On the HUD, draw icons from `IconFactory.texture()` (cached, tinted with a
  modulate colour) rather than `IconFactory.draw()`: every polygon or polyline command costs its own
  draw call every frame, and the HUD's icons alone were once 220 of about 370.
  - **One hit from death** (task I6, GDD §4, owner, October 14, 2026): while the player is alive in a level or a
    boss fight with no armor hit and no shield left, `RunHud.last_hit` (`LastHitWarning`, `scripts/ui/`) shows a
    red band along the screen's edges and plays the two-tone siren `last_hit_siren` once. It reads
    the player's state every frame (`armor_state.is_up()`, `shield`, `alive`), not a signal, so a break, the free
    armor's return, a pickup, a revive and a test setting `armor` are all the same to it; it ends when protection
    returns, the player dies or the run isn't being played any more (`LevelRun.state` is not RUNNING: a level
    finished, a boss beaten), and it never shows in a mini-game level (`LevelConfig.plays_minigame()`). A run that
    begins unprotected gives the cue once at the start (`warn_at_start`, DESIGN-TBD, items 832–835); the
    game's own runs always begin with the free armor, so that is a bare `Loadout` in tests and tools. Its clock is
    real time (`delta / Engine.time_scale`, as `MusicDirector` and the slow-time tint do): slow time slows the
    frame's `delta`, not the siren, which is a recording.
    - *The edge* is four `ColorRect` strips on one canvas_item shader (like `SpeedLines`, so the Compatibility
      renderer and the web draw it): the two sides, full height, and the top and bottom between them
      (`strip_rects()`), so nothing is drawn twice and only about a third of the screen is (the middle costs
      nothing), each shaded by the screen's own edges (`origin`, `extent`). The band is `edge_width` of the screen's
      shorter side deep, in the kit's danger red (`UiStyle.danger`; red is the hazard colour, so it stays on the
      HUD). It tints the scenery along the edges and the floor right under the runner, not the lanes ahead. Its
      strength: a fade up to `steady_alpha`, then one swell to `pulse_alpha` for each of `pulse_count` high
      tones, `pulse_seconds` apart (never more than 3 a second), `onset_delay` after the break so the armor's own
      break sound is heard first. **Reduced flashing** (`Settings.flashing_reduced`, read each frame) has no
      pulses: the edge fades in to `reduced_alpha` and holds.
    - *Its layer:* the cue is a `CanvasLayer` of its own, `LastHitWarning.LAYER` (2), a child of the HUD, **under**
      every other overlay: `SpeedLines` (3), the attack markers (4: the Enforcer Truck's lane marker, the Magnate's
      chevron and blink, the volleyball HUD), the slow-time tint (4) and the HUD (5). So the band never covers a
      marker whose colour is a warning (the Magnate's white-to-red turn and red blink are a Pounce's and a Claw
      Slash's warnings) or a number. `test_last_hit_warning` scans the scripts' canvas layers and fails if any
      is at or under the cue's. A canvas layer inside another is drawn even while the outer one is hidden (the
      HUD is hidden during a level's intro), which the warm-up relies on.
    - *Compiled with the level* (task PERF1's rule): every cue of the session uses one `Shader`
      (`LastHitWarning.shared_shader()`), and where the game renders `setup()` calls `warm_up()`, which draws the
      strips at no strength for `ShaderWarmup.DRAWN_FRAMES` frames (counted on `RenderingServer.frame_post_draw`,
      so the intro's held game doesn't stop it) and sets `LastHitWarning.warmed`; the first armor break then
      compiles nothing. A headless run draws nothing and warms nothing.
    - *The siren* (`tools/asset_gen/sfx_bank_power.gd`) is F5 and B4 (a tritone) alternating, each tone a pair of
      slightly detuned triangle waves through a low-pass (a soft, shimmering "nee-naw"), 0.34 s a tone, once for
      each pulse; the bank reads `pulse_count` and `pulse_seconds` from the tuning, so regenerate it
      (`tools/godot.sh sfx --only=last_hit_siren`) after changing either. It is deliberately not like the other
      two-tone sounds the player hears in a fight: lower, slower and softer than The House's jackpot (880 and
      660 Hz, 0.23 s a tone, over a fanfare; a reward) and the Floating Head's searchlight (1320 then 990 Hz in
      0.14 s beeps; a bomb's warning), and flat tones where the attack warnings are rising whines and crackles and
      the Enforcer Truck's siren sweeps. It plays once through the world's `PlayerSfx` (`requested` and `stopped`
      for tests) on the SFX bus, ducks nothing, and is cut off if the cue ends first.
    - *Its level* (`last_hit_siren` in `data/audio/sfx_library.tres`) is set so that, as heard on the general
      weighting (the loudest 400 ms K-weighted, `audio_review.gd`, plus the library's level), it is at least about
      2 dB under the quietest of every attack warning in the library (the 43 in `test_last_hit_warning`'s list,
      which also fails if a sound named like a warning isn't in it). On the phone weighting (a small speaker, little
      below 450 Hz) it is only louder than `truck_rev`, an engine rumble, and within about 3 dB of nineteen others,
      since a phone drops the low parts of many warnings but not the siren's: the owner's call
      (item 833). The suite prints the figures.
    Numbers: `LastHitWarningTuning` (`data/ui/last_hit_warning.tres`, F6 "One hit from death").
    `tools/showcase/screens_showcase.tscn -- --screen=hud_last_hit` plays it (`--reduced-flashing`).
  - **Menus on a phone** (task I3): the project stretches 1280×720 to the window (`canvas_items`, `expand`),
    so a screen's sizes are fractions of the window's height; a phone browser's page is 340 to 390 CSS pixels
    high with its bars, which drew the shop's captions 9 pixels high. `UiScale` (`theme/ui_scale.gd`)
    magnifies the root window's `content_scale_factor` while a `ScreenBase` is open on a touch device **in a web
    page** (native mobile builds are left alone until someone has looked at them with it), until one UI pixel is
    at least `UiStyle.phone_min_scale` (0.65) CSS pixels: `factor_for()` takes the window's size and
    `DisplayServer.screen_get_scale()` (the page's `devicePixelRatio`), never more than `phone_max_factor`, and
    not so far that the menus get narrower than `phone_min_width` (a phone held upright stays small and whole;
    the page covers it there, GDD §2). It's 1 on a desktop, a tablet and a run (the HUD and the swipes keep the
    plain stretch), back to 1 when the last screen closes (deferred a frame, so the next screen doesn't see a
    step), and outside a web page unless a test sets `UiScale.assume_web`, `pixel_ratio_override` and a window
    size (`test_phone_screens`; headless windows are 64×64).
    - **A page shown smaller than its own pixels** (task L1): itch.io puts an HTML5 game in an iframe of a fixed
      size (960×540, say) and a phone's browser shrinks that to the screen's width, so the game reads a 960-pixel
      window at the phone's pixel ratio and cannot see that it looks 0.7 (or 0.4) of that size. `UiScale.
      embed_scale_for()` estimates it: the page's width against the screen's long side (`screen_get_size()`,
      which on the web is `screen.width` and `screen.height` times the pixel ratio; only a phone held sideways
      plays, the page covers it otherwise), never below `UiStyle.phone_min_embed_scale` (0.4), and
      `factor_for()` counts it in, so a UI pixel is still 0.65 of what the player sees. It is 1 for a page
      that fills the screen, which is every case but a fixed embed (a full-window frame, Safari's own tab).
      `screen_size_override` is the tests'. The page's own cover is the real answer to such a frame (Economy,
      platforms, The web demo); this keeps the menus readable when the player plays on in it.
    - **Safe areas on the web** (task L1): `UiTheme.safe_area_margins()` used to take the display server's
      safe area against its screen. On the web the first is the *window* and the second the *physical screen*
      times the pixel ratio, and iOS reports `screen.width`/`screen.height` as for a phone held upright whichever
      way it is held (390×844 on an iPhone 14), so held sideways the difference read as a bottom inset of 40% of
      the page: every menu and the run's HUD were squeezed into the top of the phone, "scrunched up". (The I3
      tests and `browser_check` never saw it: Playwright's emulated screen is the viewport.) In a web page the
      margins now come from the page (`WebPage`, `scripts/ui/theme/web_page.gd`): `window.neonPage.insets()`,
      defined by the preset's page script, is `env(safe-area-inset-*)` in CSS pixels read in the game's own
      frame (zero where the browser keeps the page clear of the notch itself, which Safari does unless a page
      asks for `viewport-fit=cover`; an embedding page that does gives the frame its insets), scaled to UI
      pixels; native builds keep the display server's. `WebPage.insets_override` is the tests'.
    - A screen asks `is_short()` (`phone_short_height`, 620 UI pixels: a phone held sideways) for its compact
      layout: the title's name smaller and its buttons in one row, the pause menu's in two columns, the results
      panel's smaller title, stars and score, panels with less padding above and below (`add_panel`), and the
      shop's Menu and Next in the title bar instead of a row of their own. Read when the screen is built.
    - `ScreenBase.content` sits in `content_scroll`, a scroll area that does nothing unless the content needs
      more room than the screen has (then it scrolls both ways rather than cut it off; until then it ignores the
      mouse, so it can't take a press for a scroll); `is_scrolling()` says which, and desktop-sized tests still
      need it false.
    - A finger's drag scrolls a list only if it reaches the `ScrollContainer`; a panel or button takes the
      touch (mouse filter STOP), so a drag that began on a shop card did nothing. Every `PanelContainer` and
      button in a screen that takes touches passes them on (`ScreenBase._on_node_added`; a toast, which ignores
      them, still does), and a button still takes its own press. Sliders keep their drag. Then a press that
      moves must stay a press: Godot 4.7's `ScrollContainer` takes any press for the start of a scroll at the
      first pixel of movement (its `scroll_deadzone` is 0), which cancelled the press of every tap that moved a
      little, a mouse's too. Every scroll area in a screen gets `UiStyle.scroll_deadzone` (16 UI pixels, about
      10 CSS pixels on a phone): a tap that moves less presses, a drag that moves more scrolls.
    - `test_phone_screens` lays every screen the demo shows (and the pause, its settings and quit dialog, and
      the revive offer) out at 844×390, 844×340, 844×300, 667×375 and 640×290 sideways and 390×844 and 360×800
      upright, and a 960×540 embed shrunk to an iPhone SE's and an iPhone 14's screen and the 844×340 page on a
      390×844 screen (the embed scale counted), in device pixels as a phone has them, and checks the text size
      (11 CSS pixels at least, none cut), finger targets (40 at least), nothing off the screen or cut at the side, the screen's way on in sight,
      and panels and buttons passing touches; plus the magnifying's maths and lifecycle, and taps and drags
      (a tap moving a few pixels presses the title's, the shop's, a level tile's, the pause's and the revive
      offer's buttons; a drag past the deadzone scrolls the shop and the level select without pressing), the
      embed scale's maths and its effect on the factor, and the page's safe-area insets (parsing, the notch's
      margins at the magnified size, none on a desktop). `tools/web/browser_check.js` checks the same in a real
      browser, with the screen an iPhone reports (`phone_menus`, `itch_embed`).
      `godot --resolution 844x340 res://tools/showcase/screens_showcase.tscn -- --screen=shop --phone
      --flavor=web_demo --shot=build/shop.png` renders one (the window's size is the page's, at pixel ratio 1;
      the showcase sets `UiScale.assume_web` for `--phone`); `--screen-size=667x375` says how big the phone's
      screen is (a 960×540 page, `--resolution 960x540`, then looks shrunk to it, as itch.io's frame does) and
      `--insets=47,0,47,21` the page's safe-area insets (a notch).
- **Audio:** `SfxLibrary` maps sound names to `assets/sfx/*.wav` (volumes in
  `data/audio/sfx_library.tres`). The cyborg firing effect alone is -3.2 dB instead of -5.5 dB:
  about 1.303 times its former amplitude, matching the owner's approximately 30% increase;
  charge warnings and the player's laser are unchanged. `Music` (`MusicDirector`) plays `assets/music/` (files, levels and
  tempos in `data/audio/music_library.tres`), one looping track at a time with crossfades: the menus'
  default track and one default per zone, named after the zone's id (`ZoneDef.music`). Defaults are generated by code in
  `tools/asset_gen/` (`tools/godot.sh sfx` / `music`): a track is composed in `track_<name>.gd` with
  `music_song.gd` (stems on a 16th grid that wrap around the loop, and loop-safe effects) and
  `music_instruments.gd`, and a new one is listed in `music_gen.gd` and the library. **No new tracks are
  generated** (owner, September 28, 2026). Owner-supplied MP3s replace gameplay in every zone and
  the Floating Head, The House and Mecha Guppy fights. `MusicLibrary.zone_tracks` maps a zone's generated default
  to its supplied song, while `boss_tracks` maps a boss id to its supplied song; The House uses the
  Casino song, and the Mecha Guppy fight uses its own boss song, `Zone_Beach_Boss_Teeth_in_the_Surf.mp3`
  (re-encoded to 160 kbps to stay within the 40 MB supplied-song budget). The Beach and Casino retain generated defaults for cinematics. Their songs have no
  dedicated completion riffs yet and use the fallback City riff. `App._start_run` resolves these for campaign,
  quick play, endless and retries; cinematics and menus bypass the overrides, and unmatched bosses
  keep their defaults. All levels within a zone share its song. MP3s loop in full; regeneration
  leaves them untouched. The web demo keeps the Zone 1 and Boss 1 MP3s plus menu/cinematic defaults.
  Generated tracks are
  levelled so their K-weighted loudness (400 ms windows: the median, and the energy mean) sits at
  about -26.8 dB, some 10 dB under the attack warnings.
  - **Dips:** `set_ducked()` lowers the music under the pause menu, and `set_dipped()` is the death dip
    (GDD §11): `LevelRun` dips it as the player dies, it holds under the death screen, and a revive or a
    restart lifts it; playing another track (leaving to the menus) or `stop()` ends it, the dipped
    track fading out as it was. The dipped track sinks by `dip_db` while a low-pass on the Music bus
    closes to `dip_lowpass_hz` (switched off whenever it's open). With both, the deeper applies, never
    the sum. The numbers are `MusicLibrary`'s, in F6's "Music" section.
  - **The level-complete riff** plays in the key of the music playing (GDD §11):
    `MusicDirector.level_complete_sound(track)` gives `level_complete_<track>` when the sound library
    has one, otherwise the E riff `level_complete` (the City's), and `LevelRun` plays it when a level
    ends or a boss is beaten. The riffs are in `tools/asset_gen/sfx_bank_riffs.gd`, each over within
    `LevelRun.COMPLETE_PAUSE`, when the run and its sounds are freed. A track replaced by a file in
    another key needs its riff remade to match, or removed. For now `MusicLibrary.riff_tracks` maps
    supplied songs back to their original zone's riff, preserving the existing completion sounds;
    their keys have not been retuned to the supplied songs.
  - **The Resonator's warning** (H2, GDD §9.10; the owner's October 8, 2026 request that it not sound
    like a doorbell): `resonator_warning` (`tools/asset_gen/sfx_bank_resonator.gd`; it was the three-note
    chime `resonator_chime`) is noise only, a crackling build-up of fire that breaks into a crashing wave.
    A rumble, roar and hiss brighten and swell, crackle (ticks and snaps) thickens, and the fire flares on
    each halo's line-up (`Resonator.LINE_UP_AT`, once `CHIME_NOTES`: it still times the halos). A short
    breath follows, then the wave crash lands exactly as the red wave leaves
    (`ResonatorTuning.warning_seconds`, 1.3 s), its roll and fizz rolling out for 0.85 s after it.
    - *Regenerate it* (`tools/godot.sh sfx --only=resonator_warning`) after retuning `warning_seconds` or
      `LINE_UP_AT`: the sound is made for those times, and `test_resonator` measures its flares, its crash,
      its crackle and its lack of any bell-like partial against them.
    - *The wave leaving* plays `resonator_pulse` with the crash: a release thump and the rush of the wave
      rolling in (a double pulse's second wave has only this), with no pitched hum under the crash.
    - *Shot down in its warning,* a Resonator cuts the sound off before its crash (`PlayerSfx.stop()`):
      with no wave coming, the crash must not land.
  - **On the web** (task I3; `docs/architecture/economy-platforms.md`, The web demo): sound effects play with
    Godot's web default, "Sample" (`audio/general/default_playback_type.web`): each a short buffer the browser's Web
    Audio plays at once. **Music streams** (`MusicDirector.play()` sets every music player's `playback_type` to
    Stream; the owner's choice over shorter songs, item 828, October 19, 2026). As a sample a song was decoded whole
    on the page's thread when it first played (`AudioDriverWeb::register_sample`, at the output's rate whatever the
    file's bitrate: the Zone 1 song 52 MB, the Boss 1 song 60 MB, twice while it started, a full copy at every
    loop, never freed): City 1's start added about 250 MB to the tab and stopped the page while it decoded. A stream
    is decoded as it plays, but without threads the engine mixes it on the page's thread, into a buffer the browser
    plays from: `audio/driver/output_latency.web` (150 ms, project.godot; the engine's default is 50) rides out a
    slow frame, and a freeze longer than that is a gap in the music. The death dip's low-pass
    (`MusicDirector.dip_filter`, a Music bus effect) works on the web now; bus effects don't apply to samples.
    *The silent switch:* Safari mutes Web Audio, streams and samples alike, while an iPhone's ring/silent switch is
    on (a video isn't muted), so the web preset's head include sets `navigator.audioSession.type = 'playback'`
    (guarded; the demo then plays through the switch).

## The runner's outfits (cosmetics)

The cosmetics (GDD §8, "Cosmetics": looks the player buys in the shop and wears; the owner, October 18, 2026) are
**outfits for Razor Echo**, not other characters: the same rig, poses, 75% scale and hitbox (`PlayerSuit.DESIGN_SIZE`),
his head unless the outfit covers it, and the owned power-ups on top. They never change gameplay. Task M1 built the
system and Rex; M2 builds Camo and Beach Master, M3 Centurion and Party Wolf.

- **One file per outfit:** `scripts/player/outfits/<id>.gd`, `extends PlayerOutfit`, where `<id>` is the cosmetic's id in
  `data/shop/catalog.json` (`rex`, `camo`, `beach_master`, `centurion`, `party_wolf`). `PlayerOutfits` finds the file by
  that name: **there is nothing to register**, and no shared file to edit. An outfit overrides what it changes
  (`PlayerOutfit` documents them): `body_pieces()` (required: the pelvis, chest, arms, hands, legs and feet, as
  `HumanoidPiece`s; Echo's coat, arms and boots are *not* kept), `head_pieces()` (Echo's own by default, via
  `PlayerSuit.head_pieces()`; return your own to cover it, or `super()` plus a mask or hat to add to it, as Party Wolf's
  mask will), `panels()` (a coat's skirt or tails, `HumanoidPanel`s the rig swings, at most `HumanoidRig.MAX_PANELS`;
  Echo's skirt is not inherited, so a waist-length jacket has none and costs no extra draw call) and
  `attachment_overrides()` (a power-up set refitted to the outfit's shapes, by name: `armor`, `claws`, `weapon_1` to
  `weapon_4`, `magnet`; Echo's sets are used for every one not named, which is what Rex does). `PlayerOutfit` also has
  the builders `add()`, `pipe()` (a thin three-sided strip: circuit lines, cables, strap edges), `piece()` and
  `merged()`, which `PlayerSuit` uses too, and the shape and placement constants (`BOX`, `LATHE`, `MIRRORED`, ...).
  Pieces are in the segment's joint space at design scale, limb pieces authored on the right limb and mirrored with
  `side`: read `PlayerSuit` and `scripts/player/outfits/rex.gd` for the conventions, and `HumanoidPiece` for the
  shapes (`glow` and `shine` ride in the mesh, so a segment is still one draw call).
- **`PlayerOutfits`** (`player_outfits.gd`) keeps `worn` (the outfit every `PlayerAvatar` built from now on wears: the
  run's, a cinematic's, a review tool's) and `parts_for(id)` (cached: Echo's `PlayerSuit.parts()`; an outfit composed by
  `compose()` over Echo's skeleton, size and head; or, for a catalog id whose file isn't written yet, `placeholder_parts()`:
  Echo's look with the coat, arms and boots washed toward the catalog's colour for it, `DESIGN-TBD`, so buying and
  wearing an unbuilt outfit works end to end and shows. The placeholder, and the shop's "LOOK IN PROGRESS" caption,
  go when the file arrives). `is_built(id)`, `is_known(id)`, `resolve(id)` (an unknown id is Echo's own look; ids are plain
  identifiers and can't name another path) and `outfit(id)` (the file's instance) are its other calls.
- **`PlayerAvatar`** reads `PlayerOutfits.worn` when it is built, so the gameplay model (`Player`, untouched), a
  cinematic's runner (`CineActorNode`, so the Beach's outro and every other cinematic) and the review tools all wear it
  with no hook of their own. `set_outfit(id)` / `outfit()` change a live avatar (the rig is built again: do it right after
  building it; equipment, size fit and pose are kept). The title screen shows no runner. App keeps `worn` current from the
  profile (`App.sync_outfit()`, at start and after a wear, for a test or tool that swaps `App.profile`); `--outfit=<id>`
  (debug builds) sets it for a session, owned or not, and `avatar_showcase` / `avatar_run_review` take it too.
- **The colour rule does not apply to outfits** (owner, October 18, 2026): their glows and colours stay as their sheets
  draw them, hazard colours included; `test_avatar`'s colour checks are on the base look (`PlayerSuit`). Nothing on an
  outfit may be a weapon or look like a power-up (the owner's concept sheets all carry swords and guns; every one is left
  out), and the back view, which the gameplay camera sees, matters most. Keep glows thin and soft (Rex's stay under
  `test_outfit_rex`'s bloom cap) and the colours as the brief gives them.
- **The budget is the avatar's, with every power-up on:** `test_avatar`'s 2,000 triangles and 20 draw calls, and the
  power-ups take 452 of the triangles (claws 72, armor 84, a tier-4 weapon 108, the magnet 68, the shield bubble about 120),
  so an outfit with Echo's head (278) has about 1,270 for its body. Echo's own look is 1,472 triangles, Rex's 1,480
  (1,932 with everything). Thin glowing lines cost 8 triangles a piece, a chamfered box 28, a plain box 12, a six-sided
  prism 20.
- **Adding an outfit (M2, M3):** (1) write `scripts/player/outfits/<id>.gd` from its brief (`docs/art/BRIEF_OUTFIT_*.md`);
  (2) look at it: `tools/showcase/avatar_showcase.tscn -- --shot=sheet --outfit=<id>` (shots `sheet`, `sheet-run`, `sheet-close`,
  `poses`, `poses-back`, `equipment`, `equipment-back`, `turntable`; `--look=all` for every power-up) and
  `avatar_run_review.tscn -- --outfit=<id> --skin=<zone>` (the real game camera; `--equip=all`), rendered as the task's
  checklist says; (3) `tools/godot.sh test --suite=outfit` (`test_outfits` already runs every catalog outfit, built or not,
  through the budgets, Echo's size, the hair-tip height, the feet on the ground, every pose, the power-ups going on top, the
  weapon's muzzle, and the body and head segments; it needs nothing added) and, for the outfit's own looks, a suite of its
  own, `tests/suites/test_outfit_<id>.gd` (see `test_outfit_rex`); (4) a paragraph here under its marker below, and its
  `DESIGN-TBD` questions in `docs/questions/<task>.md`. The shop's price, name, colour and order are the catalog's
  (`ShopCosmetic`); its colour is also what an unbuilt outfit's placeholder uses. **Its shop preview needs nothing:** the
  card's `OutfitPreview` dresses an avatar from the same file (`docs/architecture/economy-platforms.md`, "The previews"), the
  runner in a run pose from the front and, on the card the pointer is on, running in place and turning; look at it there
  too (`tools/showcase/screens_showcase.tscn -- --screen=shop --scroll-end --focus-outfit=<id>`).

### Built outfits

- **Rex** (M1; `rex.gd`; brief `docs/art/BRIEF_OUTFIT_REX.md`). A magenta leather biker jacket (three box tiers, the tank
  top and chain between wide lapels, a standing collar, the belted waist, the zip), its **pink circuit lines** (thin
  strips over the shoulders and down the back of the right sleeve), the **cyan spine** (a line down the back with three
  vertebrae) and two plain patches on the back (no words); the right forearm bare to the fingerless glove (Echo's own hand
  shapes, so the Beach outro's two raised fingers still work); the **gunmetal and copper cyber-arm** (dome with the
  **orange** joint, plated arm, copper pistons front and back, an articulated hand) in place of Echo's gold one; a utility
  belt with hip and back pouches, dark cargo pants with an empty holster and a pocket on each thigh and knee straps,
  buckled combat boots with magenta trim. Echo's head; no skirt panels; the rifle left out. 1,480 triangles, 16 draw calls.
  The jacket's magenta is the electric fence's pink hue in every zone (the colour rule doesn't apply to outfits, so that
  is as drawn): in rendered frames of every zone's skin the fence's crackle, halo and shape and the runner's cyan spine and
  silhouette keep them apart, closest on the grey ones (the grey box, Corporate's plaza, the Dead Zone), left for the owner
  to look at. The frames come from `avatar_run_review.tscn -- --outfit=rex --skin=<zone>` (the fences at 80 m and 110 m).

- **Camo** (M2; `camo.gd`; brief `docs/art/BRIEF_OUTFIT_CAMO.md`). An aged olive military trench coat (two torso tiers, a
  high collar all round, lapels, an epaulette and a strapped cuff on the right sleeve) with **camo patches** (flat decals in
  dark green, brown, khaki and near-black on the back, the right sleeve, the carrier and every skirt panel, the left and
  right panels differing), a stained dark-brown hem, and eight **dark tubing** pipes across the
  upper back (two bent in from the shoulder blades and run down to the belt, tied by two rungs); in its open front a lighter
  camo **plate carrier** (a pouch strip, a harness strap down each side, a patch pattern) over a dark shirt; a belt with a
  pouch each side of the small of the back; the **armoured, dull brass cyber-arm** (Echo's dome for the shoulder, so the
  weapon's mount still folds out of it, a flared plate over the outer shoulder, two upper-arm plates round an exposed steel
  joint with a red and a black cable, an elbow disc, two forearm plates and a wrist ring, a three-finger articulated hand;
  the brass is a dark bronze of value 0.5 and shine 0.25 against Echo's gold 0.88 and 0.7, so it isn't treasure or a
  power-up) in place of Echo's gold one; the right hand's fingerless glove (Echo's own shapes); dark camo cargo pants with a
  pocket on each thigh and knee pads; tall laced combat boots. Echo's head. **Nothing glows** (the suit-glow effects act on
  Echo's implant and the tint), and the coat is lighter than Echo's so the body material's shared rim light keeps its outline
  on dark tracks: in rendered frames of all 11 zone skins on both renderers it reads everywhere, closest against Gangland's
  brown dirt. The long coat's skirt is `panels()`: four stiff panels like Echo's (two behind the legs, split by the vent,
  two at the open front; 0.47 m, flare 1.28; their nine patches are bands over single faces of the skirt's oval ring), which
  test_outfit_camo checks never go through a knee or the ground and trail in a slide. 1,482 triangles, 17 draw calls (1,934 and 18 with every power-up). Left out: the katana, the pistol, the
  grenades and the knife (no weapons) and the skull on the coat's lower back (too small to read). Its patches, the stripes of
  its laces and the shapes on the shoulder blades are `OutfitDecals` (`outfit_decals.gd`), which an outfit can use: a one-sided
  sheet a few millimetres off its surface, so a patch of camo, a flower or a skull costs two to eight triangles where a thin box
  costs twelve (`quad`, `diamond`, `disc`, and `on_prism` for a band over a sleeve, a trouser leg or a boot's shaft; `glow`
  makes one a glowing print), with no draw call of its own; `face_directions`, `faces_in` and `face_arc` find the faces of a
  skirt's ring from its shape (see below); test_outfit_decals pins how each faces and sits.
- **Beach Master** (M2; `beach_master.gd`; brief `docs/art/BRIEF_OUTFIT_BEACH_MASTER.md`). An open, short-sleeved dark teal
  tropical shirt (sleeves rolled to a lighter cuff, a flat open collar, a harness strap over each shoulder) printed with
  coral five-petalled hibiscus and dark palm leaves; over bare skin in the open front the same camo plate carrier as Camo's;
  a belt with two pouches; the **sea-salt corroded cyber-arm** (rusty brass plates round exposed steel joints with Echo's
  dome at the shoulder, seven verdigris patches, five tilted cloth wraps and an articulated hand); on the right a bare tanned
  arm with a teal and cream bead bracelet and the fingerless glove; dark cargo shorts with a pocket on each thigh
  and knee pads; bare tanned lower legs and strapped tactical sandals. Echo's head. The signature, which the gameplay camera
  sees all game, is the **glowing green skull** across the shirt's back (a crown, a jaw with three teeth, slanted dark eye
  sockets and a dark nose, with palm fronds fanning from its upper left; flat decals, the holes unlit so bloom keeps the
  shape; Rex's glow of 0.38): the only glow on the outfit, as the sheet draws it (the colour rule doesn't apply to outfits),
  which powers down on death and takes the dash's brightening and the invulnerability tint like Echo's conduits (it is body
  glow, so nothing extra flickers: Reduced flashing has nothing to calm). The shirt is short, so `panels()` is four small
  ones for its hem and open front (two tails behind, 9 cm, two flaps at the front edges, 13 cm, following the thighs at
  35 and 45%), one draw call. 1,513 triangles, 17 draw calls (1,965 and 18 with every power-up). Left out: the katana, the
  pistol, the grenades and the knife. Frames: `avatar_showcase.tscn -- --shot=poses-back --outfit=beach_master`; test_outfit_beach_master.
- **Writing an outfit (what M2 learned).** Match Echo's sole: the rig stands on the lowest vertex of the feet, so a sole that
  reaches 1 mm below his (-0.075 m in the foot's space) lifts the whole runner and moves the weapon's muzzle (test_outfits'
  height and muzzle checks catch it; a sandal's sole may be thicker if it ends at the same height). Keep the budget in mind
  when a joint or finger is a prism: `sides: 4` is 12 triangles where the default six sides are 20. Anything that is only
  paint (a camo patch, a print, a lace) is a decal, not a box. A skirt's ring is an oval, so its faces sit at 19, 52, 78, 102,
  128 and 161 degrees and so on, not at tidy angles: a patch aimed at "105 degrees" builds no triangle and draws nothing
  (M2's first build had 32 such pieces). Ask `OutfitDecals.face_directions` for the faces and `faces_in` for a panel's, and
  `test_outfits` fails any outfit with a body, head or panel piece that builds no triangle.

<!-- M3: Centurion and Party Wolf go here, one paragraph each. -->

- **Centurion** (M3; `centurion.gd`; brief `docs/art/BRIEF_OUTFIT_CENTURION.md`). A gold-and-crimson Roman outfit on Echo's own
  head. A charcoal and crimson trench coat (two box tiers, crimson lapels with a gold edge, the high collar with a gold rim, a
  crimson sash under a black belt with a gold buckle), a gold cuirass in its open front (a chest plate over an abdomen plate: a
  round emblem of a dark-gold ring round a crimson disc, a line under the pecs right across the plate with a slanting stroke
  under each, and lines across the abdomen), lion-head pauldrons (a gold dome, three layered scale plates and a lion as two gold
  diamonds, one mirrored definition for both shoulders), a crimson right sleeve with a gold bracer and a fingerless glove, the
  sleek gold cyber-arm with crimson joints in place of Echo's, black pants with crimson thigh straps, gold knee plates, greaves and
  gold-plated boots. **The skirt is six panels:** Echo's four (charcoal behind with the two outer faces crimson and a gold hem,
  crimson at the front edges), and two *pteruges* panels, a pair of black leather strips with gold tips hanging from the sash at
  each hip (follow 0.45), all swung by the rig. **The back** is the gold skull inside a sixteen-leaf wreath, 19 flat quads
  (`flat()` in `party_wolf.gd`'s paragraph below), between crimson borders. The gold is polished metal (`shine` 0.75) and nothing
  on the outfit glows, so bloom can't wash the armour's shapes out; the katana, the pistol and the dagger are left out.
  **The armor power-up is refitted** (`attachment_overrides`, `ARMOR_PLATE`): bright silver-blue caps standing above the
  pauldrons, a plate over the cuirass and a yoke across the upper back, each with Echo's pale glowing edge (96 triangles, Echo's
  set is 84). Echo's own steel is legible against the gold but dark and thin beside it, and its shards stay his steel colour
  (`PlayerAvatar`); to see his set on this outfit, comment out `attachment_overrides()` and render the sheet's close-up with
  the armor on (`godot --path . res://tools/showcase/avatar_showcase.tscn -- --shot=sheet-close --outfit=centurion --look=armor`
  with `--write-movie`, as in `CLAUDE.md`, Commands; add `--rendering-method gl_compatibility` for the web renderer). The run
  review shows the armor on, shattering and gone at 95 m (`avatar_run_review.tscn -- --outfit=centurion --skin=<zone>
  --equip=armor`). 1,506 triangles bare, 1,970 with every power-up, 17 draw calls (18 with the shield, 19 while the broken
  armor's shards fly). In the run review of the city, the Golden Zone, Gangland, the Beach and the Casino on Forward+ and
  Compatibility, and of the Dead Zone and Corporate's plaza on Forward+, the gold pauldrons, the wreath and the crimson skirt read
  against every track and the pink fence is nothing like the crimson. `DESIGN-TBD` (`docs/OPEN_QUESTIONS*.md` items 1003-1006): the armor
  refit, the skull, wreath, lion heads and cuirass relief are simplified from the sheet, the coat is clean rather than worn.
- **Party Wolf** (M3; `party_wolf.gd`; brief `docs/art/BRIEF_OUTFIT_PARTY_WOLF.md`). The only outfit that covers Echo's head:
  `head_pieces()` keeps his neck, skull and spiky hair from `super()` (the boxes of his face, the implant, eye, brow, nose and
  scar, are dropped under the mask) and adds the **cyber wolf mask**: a fur brow, a snout with a black nose, a jaw with bared
  fangs, cheek tufts, two pointed ears (tips no higher than his hair's, tested on the built mesh) with violet linings, a glowing
  pink eyepiece over his left eye (`-x`), a cyan right eye and neon cyan and violet markings. A long purple coat covered in neon
  graffiti with a grey fur mantle and collar, grey fur cuffs and two rave bracelets, a dark T-shirt with a glowing moon print under
  a pink chest rig, the glowing purple and cyan rave cyber-arm on the left, a studded belt with four hanging glow sticks **on his
  right** at the front, dark pants with pink straps, glowing knee pads and neon-laced boots with glowing soles. The skirt is Echo's
  four panels (a cyan hem line, a pink band behind) and **the tail**, a fifth panel: as the sheet draws it, the grey tail hangs
  from a carabiner at the front of the belt **on his left** (`side = -1`, authored on the right and mirrored; follow 0.35), in
  front of the thigh, in three tapering fur sections with a dark tip. That leaves the back of the belt free for the magnet
  power-up's coil (`test_outfit_party_wolf` checks none of the tail is inside it). **The back** is the neon wolf in shades (a cyan
  outline, pink lenses, a yellow bridge), "PARTY WOLF" in two lines of block letters (PARTY pink over WOLF cyan, above the belt;
  `GLYPHS` is the stroke font: 32 strokes) and graffiti tags down both sides in cyan, pink, green and yellow. **How it stays
  cheap:** the sign, the neon wolf, the graffiti and the markings are *flat quads*: `flat()` / `back_flat()` / `back_line()`
  (`party_wolf.gd`; `centurion.gd` has the first two for its wreath) make a one-sided `BAND` over a single face of a four-sided
  section, which is two triangles, 2 mm off the surface it sits on, with its own colour, glow and roll, so none of it is a separate
  mesh, a texture or a draw call and every glow powers down on death, brightens with the dash and sits under the invulnerability
  tint like Echo's conduits (`test_outfit_party_wolf` reads the sign back from the pieces and checks the letters). The glows are
  thin and soft: the brightest line while dashing is under `test_outfit_party_wolf`'s 1.4 cap. **The armor power-up is
  refitted** like the Centurion's (bright silver-blue plates, over the mantle, the pink rig and across the back under the mantle;
  Echo's steel is close to the fur's grey). 1,512 triangles bare, 1,976 with every power-up, 17 draw calls (18 with the
  shield). **The sign is not readable from the gameplay camera:** there it is about one pixel a cell and shows as a band of pink
  and cyan under the neon wolf; it reads in the showcase's close-ups (`avatar_showcase.tscn -- --shot=sheet-close
  --outfit=party_wolf`). The sheet sprays the words on the coat's skirt below the belt, not on the torso as built here (the
  skirt's panels swing apart, which would break the lettering). `DESIGN-TBD` (`docs/OPEN_QUESTIONS*.md` items 1003, 1004 and 1007-1010): the armor
  refit, the graffiti, the markings and the shirt print are simplified from the sheet, the sign's colours and size, the tail's
  carabiner, and the mask's expression are ours.
