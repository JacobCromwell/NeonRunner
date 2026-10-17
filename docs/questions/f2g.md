# Questions from task F2g (the Neon City's intro; the owner's beats, October 16, 2026)

The owner's beats (GDD §6, Cinematics, "Zone 1 intro", with his October 16 answers: the runner bursts out through a feed
billboard, and the game's title comes before the zone's card) leave these staging details open. Each has a placeholder, marked
`DESIGN-TBD` in `scripts/cinematics/city_intro/city_intro_tuning.gd` (its numbers, in `data/cinematics/city_intro_tuning.tres`) or
in the file named, and built so it is cheap to change.

1. **Which street is it, and how wide?** (GDD §6: "the street itself, not truck roofs".) The levels run on truck roofs 14 m over the
   City's road; the intro is on the road. Placeholder: the City's own stretch of towers with no floor, lifted so the road far below
   is the ground, 8 lanes wide (19.8 m between the walls) whatever the device's lane count, so the Head fits it as it does in its
   fight; dressed with asphalt and lane paint, crosswalks, sidewalks, shopfronts with lit windows and neon signs, and warm street
   lamps (`CityIntroStreet`). `street_lanes`, `dress_*`.

2. **Which billboard, and how does it burst?** (GDD §6: the light sweeps past, the runner bursts out through "a billboard showing the
   feed, the Head's face", mounted "at about first-floor height" so the leap onto the cyborg's head reads.) Placeholder: a 4.4 x 2.8 m
   screen in a grey frame standing 0.45 m out of the left wall, 14 m ahead of the camera's street-level start, its bottom edge 3.7 m up
   (above the shopfronts' signs, a floor up; the leap down onto a cyborg's head is 1.9 m plus the arc). It shows the Head's face under
   the fight's own face shader (stern, the pupils following the searchlight across it), a cold-white trim and a cold-white spill on the
   wall; the light crosses it, the picture tears for a third of a second, and the screen bursts just behind the light (glass: 56 shards
   that tumble, fall and lie on the road; 40 cold-white sparks and a flare where the screen was; the frame left dark with a few
   teeth of glass and dangling cables, no light on it: the feed is broken). With Reduced flashing: 35% of the sparks, the flare a slow
   faint glow (no pop), and the face shader's static held still. Cold white, never a hazard colour (the sparks are not orange).
   Nothing flashes the picture. Sound: `billboard_smash` (glass and a power surge cut dead, sparks crackling). `billboard_*`, `burst_at`,
   `shard_count`, `spark_count` (`CityIntroBillboard`). Open: whether the billboard's face should do more than watch (it might startle
   as the runner bursts out of it).

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
   citizens' kind: plain, never a hazard's hue, nothing glowing (the palest a pale jacket and a thin pale blue-white neon strip on some shoulders,
   dim beside the cyborgs' screens); the citizens
   themselves are flipbook cards that never walk), 12 vehicles in each of the road's two outer lanes: hover cars and a hover bus
   (new, by code, in the City's kit: muted paints, white headlights, violet tail lights) and the skin's own hover trucks (their
   orange marker lights and edges made headlight white and their red paint left out, since orange reads as a gap's edge). A low-end
   device gets half of each. `vehicles_per_lane`, `people_per_side`, `low_end_share`.

7. **The Head's place and look.** (GDD §6: the face shown, the light cold white.) Placeholder: its face's plane 40 m ahead of the
   camera's street-level start, its belly 11 m up (its crown under the towers), its face lit from the first frame, its searchlight
   sweeping the street under the camera's descent, then the cyborgs, then the wall across the billboard; the light is cold white (the
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
   at 2.5 m/s in their walking pose: the pace that pose's stride is authored for (`full_stride_speed` of
   `data/tuning/cyborg_walk_animation.tres`), since at a run's speed (7 m/s was the first try) its feet skate, the walk's cadence topping
   out at 1.6 strides a second, and the only run a cyborg has is the panic variant's flight (head twisted back, an arm flailing).
   Open: a proper angry run for a chasing cyborg would let them keep pace. The corrupted faces are the hosts' glitches (purple on a host); here they are plain white, for a
   moment, on ordinary cyborgs. With Reduced flashing the screens change once, calm to angry, with no flicker. `flicker_at`,
   `flicker_seconds`, `turn_seconds`, `chase_speed`, `CityIntro.FLICKER_FACES`.

10. **The camera.** (GDD §6: "one continuous move", "a panning shot at street level / human height".) Placeholder: from 46 m up behind
    the Head's light, down the canyon of towers to street level, following the light's spot, panning down the street and onto the
    billboard and the first cyborg (one move, no cut, 5 s of flyby and 4 s of street, the view swinging left to the billboard
    for the burst, and then with the runner across the street); a cut to the Head's face from the street, tight on
    the startled face, in on the angry one, back and down for the jaw's drop; a cut back to the street, low in front of the cyborgs,
    which drifts on behind the chase under the title cards. `move_*`, `head_*`, `street_*`, `chase_*`.

11. **The title cards and the ending.** (GDD §6: the game's title, then "Zone 1's title card, and play begins"; the total may run a
    couple of seconds past 20.) Placeholder: after the chase has run for a second, the game's title, "NEON RUNNER" (the title screen's
    working title), on the existing card (no caption, 1.8 s, fading in and out as every card does), with a short deep sting
    (`title_sting`); a tenth of a second after it has gone, the zone's card ("ZONE 1" / "NEON CITY", 2 s), then a half-second fade to
    black, as the arrival flyover ends; the level opens on its own view. 21.7 s in all. The City's own music (the zone's track) comes in
    over 4 s from the start; no music of its own (GDD §11). Open: whether the title wants a bigger or different card than the zone's
    (it is the same size and style), and whether it should be over black rather than the chase. `title_at`, `title_seconds`,
    `title_text`, `card_at`, `card_seconds`, `fade_out`, `music_fade`.

12. **New sounds.** The game's own sounds cover the jump, the land, the stomp and a cyborg's death; five are new, in the game's style
    (`tools/asset_gen/sfx_bank_city_intro.gd`): `billboard_smash`, `head_startle`, `head_yell` (2.2 s), `feed_surge` and
    `title_sting`.
