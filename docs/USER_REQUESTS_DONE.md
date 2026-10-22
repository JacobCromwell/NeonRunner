

## October 21, 2026

- [x] **The Terminal's intro cinematic** (GDD §6, Cinematics, "Terminal intro"; task F2k): the runner surveys a Dead Zone wasteland and the decayed Grand Terminal Station ("GRAND" fallen off, "TERMINAL" drooping and sparking, light spilling out), wipes a sign showing the Palace in gold, climbs the rubble at the entrance, squeezes in through the crack of light, and drops inside to the first level's tracks.
  DONE (F2k): `TerminalIntro` (32 s) in the Terminal's intro slot in place of the arrival flyover, seven new sounds,
  `test_terminal_intro`. Staging choices in items 1102-1115 in `docs/OPEN_QUESTIONS_DEFERRED.md`.

## October 21, 2026

- [x] **Add the Ice Lab, zone 9: a frozen laboratory with falling gantryways and teleporters** (the owner, October 21,
  2026; GDD §5, Zone 9; reference `docs/art/reference/ice_lab_zone.webp`). Slot it between the Terminal and the Golden
  Zone (now zone 10), three levels, no boss. Icy and crystalline, industrial and lab: brain jars and lab equipment on
  the walls and as doodads, some jars holding a curled-up Octodog that sometimes breaks out when smashed and has to be
  fought. Level 1 leans into snow and industry, level 3 into the lab. **Falling gantryways** (all levels, from level 1):
  dash a pillar in a floor lane to drop its one-lane overhead walkway (a little shorter than a ceiling) after about a
  second; it destroys enemies beneath it and hits a runner under it (armor and shield block it). **Teleporters** (from
  level 2): a square pad with a green space-age antenna sends the runner to an output pad further down; the first is
  safe, later ones may land before a gap or an enemy; with two output pads the antenna's left or right light picks one;
  fixed antennas in level 2, blinking ones added in level 3. Enemies: cyborg gangsters, Octodogs and heli drones. Its
  two new enemies come in later sessions. Tasks Q1-Q5 in `docs/TASK_PLAN.md`.
  DONE (Q1-Q5): the Ice Lab is zone 9 with Frost Foundry, Relay Station and Specimen Vault between the Terminal and the
  Golden Zone (zone 10), no boss; its own skin with frost, mid and lab leans (brain jars in galleries above the
  wall-run band, a roof of steel and ice); falling gantryways in all three levels; teleporters from Relay Station
  (fixed) and Specimen Vault (blinking too); one Octodog jar per level that breaks open, with decoys; Corporate's song
  for now. Questions in items 1116-1183 (1118, 1149 and 1165 answered by the owner on October 22, 2026).
