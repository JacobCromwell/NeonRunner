# F2d, Gangland's outro: open questions

The owner's beats (October 9, 2026; GDD §6, Cinematics) are built as given, and so is their follow-up (October 10,
2026, recorded in GDD §6 too): the runner's movement more fluid and less choppy; one shot where we see the runner
getting into the car and, in the seat next to them, a screech sitting nice and cute; the car faster as it drives off.
Then, the same day: the screech looking like the other screeches, still sitting there; the two nodding at each other
as the runner comes in, and then the car taking off.
These are the choices made to fill them in. Each is a placeholder in data
(`data/cinematics/gangland_outro_tuning.tres`, `GanglandOutroTuning`) or in code marked `DESIGN-TBD`
(`scripts/cinematics/gangland_outro/`, `scripts/cinematics/cine_poses.gd`).

- **Its length** (GDD §1 and §6: "5–15 second cinematics"). Placeholder: 22.4 s (12 s for the rubble and the key,
  10.4 s for the car), to give each beat time: the screeches' moment, the walk over, the trembling hand-off, the
  unlock, getting in beside the screech, the drive into the distance. Every time is data, so it can be tightened;
  at 15 s the hand-off and the getting in feel rushed. Is 22–23 s acceptable here?
- **The sky and look.** Placeholder: both scenes pick up where the fight ended, in the arena's look under Gangland
  3's blood-red sky (`CineStageDef.after_fight`), where the zones' other outros keep the zone's own sky. Or should
  the outro (or only the car scene) have Gangland's own night sky?
- **Where the car scene is** ("cut to a new scene"). Placeholder: another stretch of Gangland's street, the car
  parked in it, driving off down the street toward the Marketplace. Alternatives: a side street or garage, or the
  edge of the Marketplace.
- **The car's look** ("sleek, flashy ... angular, almost triangular ... shiny, like a Lambo"). Placeholder
  (`SportsCarModel`; size, paint and accent in data): a faceted wedge 4.4 m long, 2.0 m wide and 1.1 m tall (a
  little big for the runner, who is about 1.3 m tall, so they fit in it, sitting, with the screech beside them;
  two raked tan seats piped in cyan), a blade of a nose, a raked windshield,
  flared fenders, a dark side intake, a rear wing, a scissor door on the driver's (left) side; ultraviolet-purple
  paint with cyan running lights, wheel hubs and glow underneath, white headlights and red taillights. Purple and
  cyan stand clear of Gangland's browns and reds; cyan is also the anti-grav pads' colour, though nothing in a
  cinematic is a hazard or a pad. Another colour (a classic yellow or orange, or gold to match the key)?
- **Who the car belongs to, and what the key opens** (narrative, GDD §1). Placeholder: the Host's key opens the
  car; nothing says whose it was. Should anything (a card, a later beat) say?
- **The Host** ("the swarm host cyborg"). Placeholder: the fight's person (`SwarmHostPerson`), freed, lying back
  against a heap of rubble with their implants dimmed (shorted out at the defeat), 1.45 m tall (the fight holds
  them up at 1.75 m inside the swarm's bulk). They stay in the rubble; the outro shows nothing of what becomes
  of them.
- **The screeches.** Placeholder: four of them (`sniffers`), the sewer screech's own body, sniffing round the Host;
  they look up as the runner comes walking down the street, raise their spines (to the level a screech has in play
  when it isn't attacking, never the full blazing bristle of its attack: `GanglandOutroSet.ALARMED`), and scuttle off
  into the gutters at the walls before the runner arrives (`look_up_at`, `scuttle_at`), so the runner's coming
  scares them away. How many, and is that the reason they leave?
- **The runner's movement** (the owner, October 10, 2026: "stiff and unrealistic ... more fluid and less
  choppy"). Placeholder: a walk of its own for cinematics (`CinePoses.walk`, in place of the run cycle at a walking
  pace, which shuffled): heel strike, the knee bending through the swing, the foot rolling off its toe, the hips and
  shoulders turning against each other, the arms swinging opposite the legs, the head steady; the planted foot
  stays put (it skated about 40% of the ground covered before), and standing, the runner breathes and shifts their
  weight. They walk at an unhurried 1.05 m/s to the Host (`walk_speed`, from 5.8 m back) and 1.1 m/s to the car
  (`car_walk_speed`), about two steps a second; they turn at `turn_rate` (3 a second: a quarter turn takes about half
  a second, stepping round), and their reach for the key, holding it up and holding it out to the car ease in and
  out. Is the pace right (slower and more solemn, or brisker)? The walk is cinematics' own: play still uses the run
  cycle, which never walks.
- **Getting in.** Placeholder (`CinePoses.get_in`, over `get_in_seconds` 1.5 s): from standing at the door, the
  near (right) leg lifts over the sill, they duck under the door's edge, sit down onto the seat and bring the other
  leg in, then sit back low in the seat, legs out, hands in their lap, the key in their right hand.
- **The screech on the passenger seat** (the owner: "a screech is sitting nice and cute on the seat"; then "make it
  look like the other ones pretty much, but ... still have it sit there"). Placeholder (`CarPassenger`): one of the
  screeches, their very body and look in play, calm (spines down, as in play when not attacking: their tips still
  glow), at `SIZE` 0.55 (the fight's are 0.7), sitting up on its haunches on the passenger seat like a rat: body
  tipped up 45°, head level, paws held up in front of its chest, front legs tucked, hind feet forward on the seat,
  tail curled round on the seat toward the driver (`sitting_meshes`; the pose's angles are constants there). It
  faces ahead, breathing, the tip of its tail twitching; as the runner gets in it looks round at them with a curious
  tilt of its head (`passenger_looks_at`). Is the pose right, and its size? Who is it: one of the swarm's, staying
  with the runner from now on (does it appear in later zones or cinematics)? It rides off in the car; nothing shows
  it again.
- **The nod** (the owner: "the screech and the player character nod at each other, and then the car takes off").
  Placeholder: once the runner is sat, they look round at the screech (`GanglandOutro.LOOK_AT_PET`, 40°); it nods to
  them at `nod_at` (17.1 s: its head dips 24° over 0.7 s, with a soft chirp, `screech_chirp`) and they nod back
  0.15 s later (their head dips 26°), then look ahead again as the door comes down behind them (`door_down_at`) and
  the engine starts (`lights_at`); the cut to the road and the launch follow (`road_at`, `launch_at`), 2.2 s after
  the nod. Should the screech nod first, or the runner? Keep the chirp?
- **The getting-in shot** (the owner: "one shot where we see our character getting in and we see in the seat next
  to them, a screech"). Placeholder: from 14.8 s to 18.9 s (`passenger_at`, `road_at`), from behind the
  dashboard, looking back at both seats and out of the open door (wide, 68°, drifting in; the car's panels are
  one-sided, so the camera sees through the back of the windscreen): the runner at the door, stepping in, ducking
  in and sitting down beside the screech, which is in view throughout; the two nod to each other, the door comes
  down behind them and the engine starts. The courtesy lights come on as the door goes up and light the cabin
  warmly from over the front of the seats (the seats' piping glows), so both read in the dark street. Then the cut
  to the road for the launch.
- **The key and the hand-off.** Placeholder: an ornate golden key (`key_length` 0.21 m: a faceted bow round a
  jewel, a shaft, two teeth), glowing faintly so it reads as gold in the street's dim red light. The Host trembles
  (`tremble`, `tremble_offering`), sits up a little and holds it out (`offer_at`); it glints (`glint_at`: a soft
  halo and a bell chime, `key_glint`); the runner leans in and takes it (`reach_at`), then looks at it
  (`admire_at`). Is the key's look right, and should anything be said or shown (a card)?
- **The unlock and getting in.** Placeholder: the runner points the key at the car as they walk up; it chirps and
  blinks its lights twice (`unlock_at`, `car_unlock`; one slow glow with Reduced flashing); the scissor door swings
  up (`door_up_at`, `car_door`); the runner steps in and sits (`get_in_at`); the door comes down (`door_down_at`)
  behind them, and they're out of sight from the cut to the road (`road_at`). Should the runner (and the screech) be
  seen sitting in the car as it drives off (see-through glass, a costlier material)?
- **The drive-off** (the owner, October 10, 2026: "faster"). Placeholder: lights and engine on (`lights_at`,
  `car_start`: the starter, a blip, idling), a fine idle shudder, then it launches (`launch_at`, `car_drive`: the
  tyres spinning and biting, the engine screaming up through three quick shifts, fading fast into the distance)
  with a squat on its rear wheels and a moment of wheelspin, accelerating at 24 m/s² (`acceleration`; it was 13)
  straight down the street, seen from the road behind it, 0.16 m up (`road_cam`; the owner: "the camera should be
  at road level"). In the 3.1 s before it ends it reaches about 74 m/s and about 115 m away (its `top_speed` of
  80 m/s is a cap it doesn't reach), gone into the haze for the last moment before it fades to black. No tyre smoke
  or exhaust flames. Fast enough?
- **The car's own glow.** Placeholder: red taillights and red halos round them, cyan running lights and glow under
  it, and the gold key's glow. GDD §5 keeps glowing hazard colours for hazards; nothing in a cinematic is one, but
  red is the enemy-attack and weak-point colour. Keep red taillights (as any car has), or another colour?
- **Sounds.** Seven new ones (`tools/asset_gen/sfx_bank_gangland_outro.gd`): `screech_sniff`, `key_glint`,
  `car_unlock`, `car_door`, `screech_chirp` (the passenger's greeting as it nods: a little trill, a questioning chirp
  and a purr), `car_start`, `car_drive`; and from the fight, `swarm_scatter` as the screeches flee and `host_short`
  at 1.1 s (`spark_at`), a last crackle from the Host's dead implants (heard, not shown). Keep them?
- **Music.** Placeholder: the fight's music fades out as it opens (`music_fade`; a quiet aftermath) and no music
  plays; the Marketplace's intro brings its own. No cinematic music is generated (GDD §11). Should a track play
  over the drive-off?
- **The shots.** Placeholder (`rubble_cam`, `follow_cam`, `handoff_cam`, `reveal_cam`, `passenger_cam`, `road_cam`
  and their looks and fields of view): low beside the Host, looking back up the street at the runner coming; over the
  runner's shoulder as they walk up; low in front of the Host for the hand-off; the car's reveal low off its front
  corner, gliding round to its side; inside the car as the runner gets in beside the screech, they nod and the door
  comes down; then the road-level shot behind it. Should any beat get a different angle?
