# C6d: every chase shows its truck

- **Chases no bait with room is left for** (GDD §9.13 "Room to show itself"; follows questions 384 and 385). On the
  levels' own seeds, 14 of the 23 chases still have no window before their bait, and no move or earlier arrival
  gives them one. In 8 builds the level has a single usable bait: it comes too soon for any showing before it (Golden
  1 at 3 and 6 lanes, Golden 2 and 3 at 6: a Buzz Overdrive revs 4 s after the run-up; Corporate 2 at 6 lanes: an
  Octodog charging at the start keeps its truck from arriving earlier), or a hover truck or a Gilded Sentinel is
  about for its whole chase (Dead Zone 1 at 6 lanes, Golden 2 at 3, Golden 3 at 5). In the other 6 chases the level's
  other bait already has its other truck (see the next question), or neither bait has room (Dead Zone 2 at 3 lanes).
  Placeholder: the truck keeps its chase, its showing after the bait where one fits (7 chases), else none
  (`_choose` in `enforcer_truck_rules.gd`; `DESIGN-TBD` on `EnforcerTruckTuning.show_window_planned`). Dropping those
  trucks would leave 9 of the 18 builds with none (Corporate 2 at 6 lanes among them, its introduction). On 8 other
  seeds of each level the hover truck and the Sentinel weigh most: they keep 93 of the 128 chases with no window from
  having one (Corporate 2 brings many hover trucks). Keep those trucks as they are, or make room another way (the
  level's first Buzz Overdrive later; the hover truck and the Sentinel letting it show)?
- **Two trucks, one chase with room** (Corporate 2 at 5 lanes, Dead Zone 1 at 3 lanes, Dead Zone 2 at 5 and 6 lanes, on
  their own seeds). The only bait whose chase has room before it has one truck; the other truck has nowhere with room
  to go. Placeholder: both stay, so in Corporate 2 at 5 lanes the introduction (14 s in, among a Tithe Collector's
  visit and then its own Buzz Overdrive's turn too close) shows itself only at the second truck (59 s). Or should such
  a level keep only the truck that shows itself (one truck instead of two; Corporate 2's introduction at 59 s)?
- **One truck that shows itself, or two that don't** (other seeds). Where giving a truck to a chase with room leaves
  the level's other truck no chase (they'd overlap), the level keeps the one that shows itself before its bait: 2 of
  144 builds on 8 other seeds lose a truck so (Corporate 2 at 6 lanes, Golden 1 at 5), and 1 gains one back that C6c's
  order dropped (Golden 2 at 5). Placeholder: the most windows before the bait count before the number of trucks
  (`_choose`), as C6c counted windows before trucks. Right?
- **An introduction that moves late** (other seeds). Where Corporate 2's first bait has no room, its introduction
  moves to the first chase where it shows itself before its bait: in 3 of its 24 builds on 8 other seeds, from 8 s to
  71 s or 82 s into the level (and from 70 s to 90 s), past the reach the campaign asks of an introduction (about 19 s
  into the level: 12 s past its start). Its first-encounter hint and the charge-path cyborg before it hold (the hint
  is on the level intro, the cyborg earlier in the campaign). Placeholder: it moves (it never moves on the level's own seeds). Or keep the introduction
  early, unseen, when the room is that far?
