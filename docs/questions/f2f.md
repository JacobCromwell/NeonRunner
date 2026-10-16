# F2f: Gangland's intro (the fork in the road)

The owner's beats (October 16, 2026; GDD §6, Cinematics, "Gangland intro"): the runner at a fork in the road looks
left; at ground level the camera pans up to two cyborg gangsters with a large Octodog between them, looking to their
right; it pans right to another gang (three in Gangland's look, one in the Zone 3 look, and leading them, in the middle
and slightly forward, one in the Casino or Zone 3 look) with a hover truck behind them; it pans back to show both; they
yell at each other, the right gang fires a shot that misses, the left gang gets angry, their Octodog charges and tackles
cyborgs on the right, who open fire; cut to the runner, who turns slowly to the right, left hand up over their face, and
walks off down the other street; 20 s is fine. Built as `GanglandIntro` (`scripts/cinematics/gangland_intro/`); its
numbers are in `data/cinematics/gangland_intro_tuning.tres`. The staging the beats leave open, marked `DESIGN-TBD` in
the code:

1. **The fork's shape.** Placeholder: a T junction 61 m down the street: both walls open onto side streets 7 lanes wide,
   and a building across the road closes it ahead, so the road splits left and right. The runner walks the last couple
   of metres up to it and stops (the beats say they "have come to" the fork). Should it be a Y-shaped fork instead,
   with the road splitting at an angle?
2. **"Looking to their right."** A gang facing the camera and looking to its own right would look away from where the
   camera then pans, so it is read as the camera's right, where the other gang stands: the left gang faces the other
   gang, turned a little toward the camera, and looks at it. Right?
3. **The left gang's look.** The beats don't say; placeholder: Gangland's own (the zone's look), like the three Gangland
   cyborgs on the right.
4. **The leader.** The Marketplace and the Casino share one cyborg look (GDD §5: the Casino reuses the Marketplace's), so
   the leader and the fourth cyborg wear the same look; the leader stands forward in the middle and is 8% taller
   (`leader_scale`). Should the leader have something of its own (a different face, a hat, a coloured accent)?
5. **The yelling.** Placeholder: three yells, the left gang, the leader answering, the left gang again, each yeller
   pointing its arm cannon without charging it, head bobbing; the voices are made-up syllables through a cyborg's speaker
   (new sounds `gang_taunt`, `gang_retort`, `gang_jeer`), with no subtitles or words on screen.
6. **The shot that misses.** Placeholder: the leader charges its arm cannon (the red glow and the cyborgs' charge-up
   sound, their warning in play, since a shot follows) and fires one bolt that zips between a left cyborg and the
   Octodog and bursts on the street behind them. The left gang flinches and looks at it, then rounds on the leader,
   faces angry, aiming their cannons, with a roar (`gang_rage`).
7. **The Octodog's charge.** Placeholder: it rears up first (its wind-up and sound, its warning in play), then lunges past
   the leader, who throws itself aside, bowls over the cyborg in the Marketplace's look (thrown back, out cold, its screen
   dark) and pounces on one in Gangland's look, mauling it. Nobody dies or vanishes on screen. Should it tackle the
   leader instead?
8. **The firefight.** Placeholder: the three right cyborgs left standing fire at the left gang, and the left gang fires
   back, about four bolts each over 1.5 s, a few hitting (a burst on the body, no damage shown); after the cut the shots
   go on round the corner as sound, further off and thinning out, until the fade.
9. **The runner's turn and hand.** Placeholder: the cut back to them comes from their left, so at first they face the
   camera looking toward the fight; they turn slowly to the right (most of the way round in about 1.5 s), their left
   hand coming up in front of the left side of their face (toward the fight) and staying up as they walk off at a walk
   (1.35 m/s), head down a little. It fades to black as they reach the mouth of the right-hand street; Gangland 1 then
   opens on its own run view (not on that street).
10. **The title card** (answered by the owner, October 16, 2026: "add the Gangland title card as the player character
    walks away at the end"). Built: the zone's card ("ZONE 2", "GANGLAND", from the zone's data) comes up 0.3 s after
    the runner starts walking away and stays 2.9 s, held on as the picture fades to black.
11. **The junction's corners.** A level's wall gap carries orange marks (the floor cut's colour) that tell a runner the
    wall stops there; at a story's street corner they read as a hazard, so the corners are covered with concrete piers
    and a kerb across each side street's mouth (`GanglandIntroSet.corners_mesh`). The City outro's openings still show
    them. Fine?
12. **Length and timing.** 21.6 s, a little over the owner's 20 s (allowed: "it is okay if this goes 20 seconds"):
    1.7 s to the stop, the look left at 2 s, the cut at 3.4 s, the pan right at 6 s, both gangs from 8.2 s, the yells at
    9.9-12 s, the shot at 12.9 s, the charge at 14.3 s, the cut back at 16.5 s, the walk off at 18.2 s, black at 21.6 s.
