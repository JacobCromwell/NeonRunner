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
  hits and, while it's broken, the cooldown ring filling in the kit's calm accent until it's back, when
  the icon flashes and the player's `armor_back` plays (a latch and a low chime; a hit the armor survives
  plays `armor_hit`). Orbitron is for titles and Exo 2
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
    begins unprotected gives the cue once at the start (`warn_at_start`, DESIGN-TBD, `docs/questions/i6.md`); the
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
      (`docs/questions/i6.md` 2). The suite prints the figures.
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
      upright, in device pixels as a phone has them, and checks the text size (11 CSS pixels at least, none cut),
      finger targets (40 at least), nothing off the screen or cut at the side, the screen's way on in sight,
      and panels and buttons passing touches; plus the magnifying's maths and lifecycle, and taps and drags
      (a tap moving a few pixels presses the title's, the shop's, a level tile's, the pause's and the revive
      offer's buttons; a drag past the deadzone scrolls the shop and the level select without pressing).
      `godot --resolution 844x340 res://tools/showcase/screens_showcase.tscn -- --screen=shop --phone
      --flavor=web_demo --shot=build/shop.png` renders one (the window's size is the page's, at pixel ratio 1;
      the showcase sets `UiScale.assume_web` for `--phone`).
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
  the Floating Head and The House fights. `MusicLibrary.zone_tracks` maps a zone's generated default
  to its supplied song, while `boss_tracks` maps a boss id to its supplied song; The House shares the
  Casino song. The Beach and Casino retain generated defaults for cinematics. Their songs have no
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
  - **On the web** (task I3; `docs/architecture/economy-platforms.md`, The web demo): every `AudioStreamPlayer`
    plays with Godot's web default, "Sample" (`audio/general/default_playback_type.web`), so music and effects
    both go through the browser's Web Audio, not the engine's own mixer. Three things follow. *The silent
    switch:* Safari mutes Web Audio while an iPhone's ring/silent switch is on (a video isn't muted), so the web
    preset's head include sets `navigator.audioSession.type = 'playback'` (guarded; the demo then plays through
    the switch). *Memory:* a sample is a whole decoded track (`AudioDriverWeb::register_sample` decodes it in
    one go on the page's thread), kept as 32-bit stereo: the Zone 1 song is 52 MB, the Boss 1 song 60 MB, and
    Godot's web audio code copies a sample's buffer again each time it starts. *Effects:* Music bus effects
    don't apply to samples, so the death dip's low-pass (`MusicDirector.dip_filter`) is silent on the web;
    only its volume dip is heard. Playing music as a stream would change all three (`docs/OPEN_QUESTIONS.md` item 828).
