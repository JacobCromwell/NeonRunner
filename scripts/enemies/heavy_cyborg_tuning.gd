class_name HeavyCyborgTuning
extends CyborgTuning
## The Heavy Cyborg's numbers (GDD §9.16), in data/enemies/heavy_cyborg.tres. It is a cyborg (CyborgTuning) whose
## arm cannon's bursts are replaced by a gatling's stream like the heli drone's barrage (GDD §9.6), so it keeps
## the cyborg's walk, margins and the cyborg-type gun's fairness numbers (CyborgGunTuning: the engage distance,
## the wind-up as `charge_time`, the reload, the rounds' speed as `bolt_speed_*`, the aim, the clear path around
## each round's arrival, its place in the cyborgs' airspace and the crossfire rule's numbers), and adds the
## stream's own (the Gatling group) and its build's.
## - Health in laser tier 1 shots (owner, October 23, 2026: "twice as many laser hits as a normal cyborg"): 11.1,
##   so laser tier 1 takes 14 shots (12, plus PowerupTuning.tier1_extra_shots), twice a cyborg's 7 in every level
##   it appears in (enemy scaling from 0.86 up: a cyborg's 4.6 to 4.9); the enhanced laser 8 (a cyborg's 4), the
##   missile 6 (3) and the heavy missile 4 (2): twice at every tier there (GDD §8 damage reference, proposed: twice
##   a cyborg's missile hits too). test_heavy_cyborg checks it against the cyborg's tuning in each of its levels.
## - Score: twice a cyborg's (proposed).
## The cyborg numbers it has no use for (UNUSED: its stream replaces the cyborgs' 2–3 bolt bursts, and it has no
## panic variant and is never a host, GDD §9.16) are hidden from the editor and the F6 panel.
## DESIGN-TBD (docs/questions/s1.md): every number here is a placeholder until playtested.

## The inherited numbers a Heavy Cyborg never reads (_validate_property hides them).
const UNUSED: PackedStringArray = ["burst_min", "burst_max", "shot_interval", "panic_chance", "panic_trigger_distance",
	"panic_startle_time", "panic_speed", "panic_run_max", "panic_spread", "host_bonus", "weapon_host_bonus"]

@export_group("Heavy build")
## DESIGN-TBD (docs/questions/s1.md): drawn this much bigger than its zone's cyborgs (on top of the zone's
## cyborg_draw_scale), its arms, body and legs bulked out further and armour plates over its clothes
## (HeavyCyborgBody). The model only: the hitboxes and the gatling's muzzle point (HeavyCyborg) never change.
@export_range(0.8, 1.6, 0.01) var model_scale: float = 1.15

@export_group("Gatling")
## DESIGN-TBD (docs/questions/s1.md): rounds in one stream (GDD §9.6's barrage, here fired from the floor ahead),
## capped so the stream's arrivals fit inside invulnerability_share of the hit invulnerability window: armor or a
## shield then protects through all of it, as through a drone's barrage.
@export_range(1, 20) var bullets_early: int = 6
@export_range(1, 20) var bullets_late: int = 6
## DESIGN-TBD (docs/questions/s1.md): seconds between two rounds reaching a runner who keeps to the locked line:
## the gap a zigzag goes through (GDD §9.6: "enough spacing between bullets to zigzag through", the drone's 0.18 s
## to 0.15 s). The runner runs into the stream, so the gatling fires its rounds further apart than this
## (HeavyCyborgGun.shot_interval).
@export_range(0.08, 0.5, 0.01, "suffix:s") var bullet_gap_early: float = 0.18
@export_range(0.08, 0.5, 0.01, "suffix:s") var bullet_gap_late: float = 0.16
@export_range(0.5, 1.0, 0.01) var invulnerability_share: float = 0.9
## DESIGN-TBD (docs/questions/s1.md): the wind-up's sound plays no further from the runner than this, on the way to
## the gatling, so the audio half of the warning is heard from as far off as the stream starts (a positional sound
## fades from 20 m and is silent at 90 m: SfxLibrary). The cyborgs' charge-up plays at the cannon.
@export_range(5.0, 90.0, 1.0, "suffix:m") var windup_heard_within: float = 24.0

@export_group("Generator")
## DESIGN-TBD (docs/questions/s1.md): seconds of run before it that the fill pass and the zone doodads keep clear
## (HeavyCyborgRules.keep_out; the cyborg's two, LevelGenerator.FILL_ENEMY_LEAD_SECONDS): a stream lands over about
## the last two seconds before the runner reaches it, and its clear path reaches a little further.
@export_range(0.0, 6.0, 0.1, "suffix:s") var keep_clear_seconds: float = 2.4


func bullets_at(t: float) -> int:
	return roundi(scaled(float(bullets_early), float(bullets_late), t))


func bullet_gap_at(t: float) -> float:
	return scaled(bullet_gap_early, bullet_gap_late, t)


## Rounds in one stream at scaling `t`, capped so the stream (its first round's arrival to its last's) fits inside
## invulnerability_share of `invulnerability` seconds (the drone's DroneTuning.barrage_count, GDD §9.6).
func barrage_count(t: float, invulnerability: float) -> int:
	var fits: int = int(floor(invulnerability * invulnerability_share / bullet_gap_at(t) + 0.0001)) + 1
	return clampi(bullets_at(t), 1, maxi(fits, 1))


func _validate_property(property: Dictionary) -> void:
	if UNUSED.has(String(property["name"])):
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR
