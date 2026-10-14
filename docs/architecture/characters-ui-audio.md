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
