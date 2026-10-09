# H7a, dash walls (the mechanism): open questions

- **How many a level** (GDD §9.14 gives none; the brief: 2–4, rising). Placeholder: `LevelConfig.dash_walls`,
  2 in Corporate 1 and 2, Dead Zone 2, Golden 1 and Golden 3, 3 in Dead Zone 1, 4 in Golden 2 (0 to 8 in the F6
  "Level pacing" section). The generator places up to that many (every campaign level gets its full count on its
  own seed at 3, 5 and 6 lanes). Golden 1 and Golden 3 ask for fewer than the brief's rising 2 to 4 would give
  them because their tracks are the most crowded (each has room for two on some lane count: the walls past an
  introduction take the room the other passes leave, below). Endless mode and quick play keep their base level's
  count, however long the level. How many should each level have, and should endless mode scale them with its
  length?
- **Where Corporate 1 introduces them** (GDD §9.14, proposed: "Corporate 1, after the Buzz Overdrive's
  introduction"). Placeholder: `feature_starts["dash_wall"] = 0.42` in `data/levels/corporate_1.tres` (the Buzz
  Overdrive's is 0.1, the partial wall fences' 0.5). The introduction stands at the first fair spot from its start;
  where none comes within `DashWallTuning.intro_window_seconds` (10 s) it makes room by taking out a few enemies
  that block it (a Buzz Overdrive with its cut, a fence generator, a cyborg, a window cyborg or a screech; never the
  last of a feature nor any feature's first; `dash_wall_rules.gd`, `_make_room`). Corporate 1 is crowded (every new
  enemy of the zone is in it), so its own seed only lands every lane count's introduction on time from about 0.35
  on. Is 0.42 the right moment, and is taking an enemy out for the introduction acceptable?
- **The spacing and what counts as "needing the dash"** (GDD §9.14, proposed: "nothing else that needs the dash
  comes just before one"). Placeholder (`data/tuning/dash_walls.tres`): faces at least the dash's longest cooldown
  (8 s at tier 1) plus `cooldown_margin_seconds` (1 s) of run apart, plus the ground a dash covers; and within that
  same spacing before a face no Buzz Overdrive charge meets the runner (a panic dash smashes it) and no fence
  generator stands (its hint says to dash through it); `keep_dash_baits` turns that off. A zone doodad isn't
  treated as one: it never needs the dash (it only pushes the runner aside, and no hint sends the dash at it), and
  keeping doodads off the whole spacing before every wall left Golden 2 on 5 lanes with none. Should "just before"
  be the whole cooldown, and is the fence generator a bait?
- **The clear stretch around a wall** (GDD §9.14 gives none; the brief: a reaction and a lane switch at dash
  speed). Placeholder: `approach_seconds` and `after_seconds` 0.6 s at the dash's speed before the face and past the
  back, in every lane: no hole, floor cut's window, fence, doodad, speed pad, pad's zone, ramp or its wall run,
  ceiling or landing zone, and no enemy's attack. Plain holes, fences and signs there are taken out to make room
  (`clear_plain_pieces`).
- **Where the walls stand in the level's build, and the danger density request** (`docs/USER_REQUESTS.md`: about
  35% more enemies and obstacles by the final levels, which `test_danger_density` holds at 30% to 40%). Placeholder:
  only the introduction stands with the enemy rules; the rest stand after the danger density pass and the zone
  doodads, in the room those passes and the fill pass left, taking out plain holes and fences in their way.
  Standing them earlier (before those passes) took the stretches the passes add enemies and rows in: the final
  levels on 3 lanes then came out about 28% denser instead of 30% (the sample was at 30.3% before the walls), and
  any wall at all, even one a level, pushed them under; and it took a crowded level's few doodad stretches (Golden 1
  lost all its doodads on 5 and 6 lanes). So the walls now cost a few plain pieces where they stand (4 to 12 a level
  for 3 or 4 walls in the suite's sample; the final levels on 3 lanes stay 30.3% and 31.2% denser) rather than the
  level losing the danger the owner asked for, and in a crowded level the
  walls get fewer fair spots (where a level ends up with none, one makes room by taking out an enemy, as the
  introduction may). Is that the right trade, or should the walls count toward the requested danger (each is a
  hit across every lane)?
- **The wall's size and the wall runners' strip** (GDD §9.14: "it blocks only the floor; a player running on a side
  wall passes it"). Placeholder (`MovementTuning`, "Dash walls"): 9 m tall (a wall jump's feet reach about 5.3 m),
  2.5 m deep, its sides 1.2 m short of each side wall's face (`dash_wall_wall_room`), its hitbox 0.15 m inside its
  look at its sides and its face (`dash_wall_inset`), from 5 cm above the floor (a slide never passes under it).
  A runner in the outer lane meets it; one on the side wall clears its hitbox by about a quarter metre and passes.
  At least one side wall is kept open beside it for `wall_route_seconds` (0.6 s) before its face: no sign (one on
  each side has those of one side taken out), and no wall gap or wall fence on either.
- **A wall runner passing it** (GDD §9.14). Placeholder: the wall crumbles as the wall runner's front reaches its
  face (so it never stands between the chase camera and them), with the same crumble and sound as a smash, costing
  nothing (`Player._check_dash_walls`, broken by `pass`). Should it stay standing behind a wall runner instead?
- **No score for breaking one** (GDD §9.14 says nothing). Placeholder: a smash, a crash or a pass scores nothing and
  isn't a kill. Should a dash through one pay something?
- **The hover truck** (GDD §9.3 with §9.14; the brief asked for the simplest fair rule). Placeholder: it gives way:
  a standing wall coming within the time it needs to drop behind the runner sends it into its lurch back, and it
  holds back, revving for no forward lurch, until the runner has broken the wall (`HoverTruck._wall_ahead`); its
  cannon holds fire near a wall. Where it can't drop back (the runner in its lane behind it, ridden, leaving ahead),
  it bursts through the wall as it burst out of the building (broken by `hover_truck`). The generator keeps walls off
  its entrance only. Why: the runner always meets the wall themselves (the truck never takes the challenge away),
  and nothing new is asked of the truck but a move it already makes.
- **The Enforcer Truck** (GDD §9.13). Placeholder: nothing; it drives behind the runner, so it only meets a wall
  already broken, and its volleys never start with a wall in the escape (as with a doodad).
- **Flyers ahead of the runner** (the heli drone, the Resonator, a fleeing Tithe Collector). Placeholder: each rises
  over a standing wall in its way, 1.2 m over its top at 7 m/s, and comes back down past it (`Enemy.dash_wall_lift`);
  the drone holds its barrage while a wall is within its reach or its climb, and the Resonator's pulses wait for
  floor clear of walls. The generator keeps walls off a drone's wave no more (its barrage holds), off a floor
  cyborg's obstacle margin only and off a planned Resonator's pulses only (as the wider gaps do), and off a Tithe
  Collector's whole stay. Should they rise over it, or should the walls keep off them?
- **The look** (GDD §9.14: "the same assets as the side walls, turned to face the player"; task H7b). Placeholder:
  every skin's default look is a plain three-storey facade (pilasters, floor slabs, a plinth and a cornice, dark
  windows, a few shuttered ones, cracks across the ground storey) in colours from the zone's own side walls
  (`ZoneSkin.dash_wall`, `dash_wall_colors()` per skin), lit by the zone's kit material. No cue in the dash's
  colour yet. H7b replaces it with each zone's side-wall kit.
- **The crumble and the sound** (GDD §9.14: "they will crumble and explode into rubble"). Placeholder
  (`SpeedFxTuning`, "Dash walls"): up to 64 lit pieces in the wall's colours flung out of the lanes and up, a cloud of
  see-through dust out of its lower face that fades as the camera nears it, a shake heavier than a doodad's (0.26),
  and `dash_wall_smash.wav` (a heavy crack and thump over a slab's boom, the crumble's roar closing down, masonry
  thudding down after it). Nothing flashes or glows.
- **The first-encounter hint** (`data/hints/hints.json`, `dash_wall`): "A building blocks the street: dash through
  it ({dash})! Without the dash you crash through and take a hit, which armor or a shield absorbs. A run along a
  side wall passes it too." Is the wording right?
