# Questions from task F2l (the Terminal's outro; the owner's beats, October 21, 2026)

The owner's beats (GDD §6, Cinematics, "Terminal outro") and their follow-up ("The train should be a more modern looking
train, but just dirty and run down. Not a steam train!") left these details open. Each has a placeholder, marked
DESIGN-TBD in `scripts/cinematics/terminal_outro/` and its numbers in `data/cinematics/terminal_outro_tuning.tres`
(`TerminalOutroTuning`), built so it's cheap to change.

1. **The train's look.** Placeholder (`TerminalTrainModel`): a modern metro, four articulated cars (two cabs) about 60 m
   long: smooth boxy-streamlined bodies, tall flat windows, double-leaf sliding doors, a stripe, rubber gangway bellows
   between the cars, a skirt over the bogies, air-conditioning units and a folded pantograph on the roof. Faded cream paint
   with a dull blue stripe, under rain streaks, grime at the foot, rust blooms, flaked paint and a few strands of vine off
   its roof (dark, so they read as growth, not light), but whole: glass unbroken, doors shut. No symbol, logo or lettering
   on it (its destination board is dark and wordless). The colours, how dirty it is and how rusty are data.

2. **Where it stands, which way it faces.** Placeholder: on the left track-bed lane beside the start lane (the start lane
   itself on a street of fewer than five lanes), its nose toward the Golden Zone, standing dark in the haze about 60 m down
   the street. The runner comes up behind its tail and the pan runs tail to nose; it leaves the way its nose points.

3. **Getting from watching it to the door.** Placeholder: the pan along the train is one cut and the next shot finds the
   runner already walking up to the front door (they walked its length while the camera swept along it). The runner never
   crosses the pan's frame.

4. **The front door and the step.** Placeholder: a cab's front has two windscreens either side of a central single-leaf
   door (a window in it, a vertical handle bar on its left stile), a destination board over it and a wide tread-plate step
   under it that the runner stands on (so their hands reach the bar); the leaf is a plug door that slides toward the train's
   left behind the face when it opens, onto a short vestibule lit dimly by the cab's emergency light (so the window shows
   a faint warm interior behind its faintly tinted, dirty glass) and, past a back wall's doorway, a dark saloon.

5. **The shakes, the bangs, the hands up.** Placeholder (the numbers in the tuning): the first shake one small, firm tug
   (0.5 s, the leaf rattling about 1 cm); a pause of 0.65 s; then the violent shake 1.6 s long at about 5 heaves a second,
   ragged, the body heaving back and forth about the hands, the leaf rattling about 6 cm, the camera shaking (strength
   0.08, scaled by Settings > Screen shake) and a loud clatter; then three fist thumps 0.34 s apart (the other hand flat on
   the door); then hands thrown up (flung, held, slumping back to standing, 2.15 s). Two new generic poses in `CinePoses`
   (`brace`, `hands_up`); the hands' reach is worked out by two-bone IK in the cinematic's script (`TerminalOutro.reach_arm`).

6. **The screech.** Placeholder: the screech friend of the Gangland and Beach outros (`BeachOutroScreech`, the scavengers'
   look, 0.55), hopping up 0.7 m so its head fills the window while the runner's hands are up; its squeak is a new, friendlier
   sound (`screech_squeak`, two quick rising squeaks) rather than the Gangland car's `screech_chirp`; it drops out of sight and
   the door hisses open (no visible button or paw: the cinematic shows it opening, not how), and it trots ahead of the runner
   into the dark saloon. Should the screech visibly work the door (a button, a paw on a lever)?

7. **Going in.** Placeholder: the runner steps from the plate up into the cab, walks in toward the back doorway, the door
   closes behind them with them still seen through its window, and the cut away hides the rest.

8. **The departure.** Placeholder: a cut to behind the train's tail, low (5.5 m back), the camera then pulling back 22 m and
   rising 5 m while the train's lights come on (headlights and their pools on the track, tail lights, the windscreens and
   saloon windows glowing warm; a failing strip's stutter, or one slow glow with Reduced flashing), it sits 1.2 s, starts
   and accelerates at up to 14 m/s² (far faster than a real metro, as the Gangland car's launch is), so that it is well past
   the haze (170 m) and out of sight about 5 s after it starts; the picture holds on the empty tunnel and fades to black.
   Should its horn or a departure chime sound? (None does: a chime is a warning sound.) Its tail lights glow red, as the
   Gangland car's do: red is a hazard colour in play, but nothing in a cinematic is a hazard; should they be a softer colour?

9. **The staging and timing.** Placeholder: 28.0 s in six shots: low behind the runner as they jog in and ease to a stop
   short of the train's tail (3.6 s); from beside them as they look up at it (1.6 s); the long pan along the train's side,
   tail to nose (4.7 s); the front door from the runner's left (6.5 s: their walk up and onto the step, a wide shot; a
   profile medium shot for the violent shaking; a closer profile shot for the bangs); close on the window from their right as
   they throw their hands up and the screech pops up in it, then wider as the door slides open and they go in (4 s); and
   behind the tail as the train leaves (7.6 s, fading to black over the last 0.7 s). The zone's music (none until the
   Terminal's own track exists) fades in from the start.

10. **Its sounds.** Nine new ones (`tools/asset_gen/sfx_bank_terminal_outro.gd`): `door_rattle` (the first shake),
    `door_rattle_hard` (the clatter), `door_bang` (three fist thumps), `screech_squeak`, `train_door_open` and
    `train_door_close` (a pneumatic hiss, the leaf's slide and a thud), `train_start` (relays clunking with the lights, the
    transformer's hum, the brakes letting go, the motors spinning up), `train_depart` (wheels clacking faster and faster) and
    `train_rush` (the roar fading into the distance). All under 2.5 s, none a warning.

11. **The hall's own parked trains.** The Terminal's hall (task O4) draws old rusted, vine-covered subway cars parked on its
    second tracks. The outro's train is a new, modern one, as the owner asked; the hall's cars are untouched. Should they
    become modern too, as the hall's decoration?
