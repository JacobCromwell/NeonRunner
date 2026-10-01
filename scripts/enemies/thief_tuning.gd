class_name ThiefTuning
extends EnemyTuning
## The numbers every thief shares (GDD §9.12: the Tithe Collector, task C5; and task B6's stand-in thief):
## what its touch takes and what catching it pays. A thief type's own tuning extends this; the thief sets
## steals_share on its hitboxes (Hazard.steals_share) and jackpot_credits on itself (Enemy).

@export_group("Theft")
## Share of the run's credits a touch takes (DamageRules ROBBED, ScoreKeeper.rob): GDD §9.12 (decided
## September 26, 2026), 25% of the credits collected this run.
@export_range(0.0, 1.0, 0.05) var steals_share: float = 0.25
## Credits catching it pays on top of everything it holds (ScoreKeeper.pay_out). DESIGN-TBD (the
## balancing pass): the jackpot's size.
@export_range(0, 5000, 10) var jackpot_credits: int = 100
