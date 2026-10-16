# Questions from task F2f (the Neon City's intro; the owner's beats, October 16, 2026)

The owner's beats (GDD §6, Cinematics, "Zone 1 intro") leave these staging details open. Each has a placeholder, marked
`DESIGN-TBD` in `scripts/cinematics/city_intro/city_intro_tuning.gd` (its numbers, in `data/cinematics/city_intro_tuning.tres`) or
in the file named, and built so it is cheap to change.

1. **Which street is it, and how wide?** (GDD §6: "the street itself, not truck roofs".) The levels run on truck roofs 14 m over the
   City's road; the intro is on the road. Placeholder: the City's own stretch of towers with no floor, lifted so the road far below
   is the ground, 8 lanes wide (19.8 m between the walls) whatever the device's lane count, so the Head fits it as it does in its
   fight; dressed with asphalt and lane paint, crosswalks, sidewalks, shopfronts with lit windows and neon signs, and warm street
   lamps (`CityIntroStreet`). `street_lanes`, `dress_*`.

2. **Which window, and how does it burst?** (GDD §6: "the light sweeps past a building window, the glass bursts just behind it".)
   Placeholder: a lit window in the left wall's second storey, 14 m ahead of the camera's street-level start, 4.2 m up, 3.0 x 2.3 m,
   warm light behind its glass; it bursts as the light has just passed it (a spray of 44 glass shards that tumble, fall and lie on the
   road, and a dark opening with a few teeth of glass left; no flash). `window_*`, `burst_at`, `shard_count`
   (`CityIntroWindow`).

3. **How many cyborgs, where, and how do they march?** Placeholder: seven, in a loose column 13.5 m deep down the middle of the road
   (the traffic keeps to the outer lanes), trudging toward the camera at 1 m/s, their screens calm; the first is the one stomped, the
   runner hops over the second and the fifth. `march_*`, `lead_z`, `stomp_at`, `hop_*`.

4. **How does the stomp read?** (GDD §6: "the cyborg should read as killed the way a stomp kills in game".) Placeholder: the runner lands
   on its head in the stomp pose and hangs there a tenth of a second (a hit-stop), the screen shakes, and the cyborg is squashed
   flat, its screen showing ERR and going dark, as `CyborgBody.die(&"stomp")` does in play (a new `stomped` pose of the toolkit's
   cyborgs). Its screen stays dark: nothing about what the screens show when a cyborg dies (GDD §5, Cyborg Viewing Devices) is
   different here. `stomp_hold`.

5. **How fast does the runner run?** Placeholder: 8.5 m/s, a hard jog (the levels run at 18-21 m/s), so they are still in front of the
   Head's face as it is startled and angry and go under its chin at about the time it turns angry; a level's speed would have them
   out of the Head's sight before it had reacted. `run_speed`.

6. **How many people, cars, buses and trucks, and what are they?** (GDD §6: "lots of people, cars, buses and trucks moving on the
   streets below, reusing what assets exist".) Placeholder: 130 people on each sidewalk (a low-poly person of the Marketplace
   citizens' kind: plain, never a hazard's hue, never a cyborg's cold white, a strip of neon on some shoulders; the citizens
   themselves are flipbook cards that never walk), 12 vehicles in each of the road's two outer lanes: hover cars and a hover bus
   (new, by code, in the City's kit: muted paints, white headlights, violet tail lights) and the skin's own hover trucks (their
   orange marker lights and edges made headlight white and their red paint left out, since orange reads as a gap's edge). A low-end
   device gets half of each. `vehicles_per_lane`, `people_per_side`, `low_end_share`.

7. **The Head's place and look.** (GDD §6: the face shown, the light cold white.) Placeholder: its face's plane 40 m ahead of the
   camera's street-level start, its belly 11 m up (its crown under the towers), its face lit from the first frame, its searchlight
   sweeping the street under the camera's descent, then the cyborgs, then the wall past the window; the light is cold white (the
   fight's own beam and spot) and never red. `face_at`, `belly`, `spot_radius`, `CityIntro._plan_light`.

8. **The startled, angry and yelling faces.** (GDD §6: "startled, then angry, and yells".) Placeholder: startled for a second (the
   eyes wide with small pupils, the brows raised, an "O" drawn on the screen under the nose like the cyborgs' panic face, the jaw a
   little open), angry for a second (the fight's furious brows and lids, the jaw shut), then it yells (the jaw wide open and its
   inside lit, the picture breaking up a little, a long hoarse shout in its propaganda voice, the screen shaking). The new look is
   the face shader's `surprise` (0 in the fight). `startle_at`, `angry_at`, `yell_at`, `yell_glitch`, `startle_jaw`.

9. **What the feed's surge looks like, and the chase.** (GDD §6, §5: "every cyborg's screen face flickers at once and turns angry, and
   they turn and give chase".) Placeholder: they stop where they are as the yell starts, every screen (a few hundredths apart)
   flickers through the corrupted "broken" face and the calm face and the broken one again, then shows the angry face (the
   cannon-charging one; no red glow: nothing is charging); they turn round a moment apart (half a second) and chase down the street
   at 7 m/s in their walking pose. The corrupted faces are the hosts' glitches (purple on a host); here they are plain white, for a
   moment, on ordinary cyborgs. With Reduced flashing the screens change once, calm to angry, with no flicker. `flicker_at`,
   `flicker_seconds`, `turn_seconds`, `chase_speed`, `CityIntro.FLICKER_FACES`.

10. **The camera.** (GDD §6: "one continuous move", "a panning shot at street level / human height".) Placeholder: from 46 m up behind
    the Head's light, down the canyon of towers to street level, following the light's spot, panning down the street and onto the
    window and the first cyborg (one move, no cut, 5 s of flyby and 4 s of street); a cut to the Head's face from the street, tight on
    the startled face, in on the angry one, back and down for the jaw's drop; a cut back to the street, low in front of the cyborgs,
    which drifts on behind the chase under the title card. `move_*`, `head_*`, `street_*`, `chase_*`.

11. **The title card and the ending.** (GDD §6: "Zone 1's title card, and play begins".) Placeholder: the existing card ("ZONE 1" /
    "NEON CITY") over the last 2 s of the chase, then a half-second fade to black, as the arrival flyover ends; the level opens on its
    own view. The City's own music (the zone's track) comes in over 4 s from the start; no music of its own (GDD §11). `card_at`,
    `card_seconds`, `fade_out`, `music_fade`.

12. **New sounds.** The game's own sounds cover the jump, the land, the stomp and a cyborg's death; four are new, in the game's
    style (`tools/asset_gen/sfx_bank_city_intro.gd`): `window_smash`, `head_startle`, `head_yell` (2.2 s) and `feed_surge`.

13. **Not built, the owner has not decided them.** (a) The runner bursting through a feed billboard showing the Head's face
    instead of a plain window. (b) Showing the game's title before the zone card.
