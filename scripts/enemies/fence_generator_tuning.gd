class_name FenceGeneratorTuning
extends EnemyTuning
## Fence generator numbers (GDD §9.1). Edit data/enemies/generator.tres.

@export_group("EMP")
## DESIGN-TBD (GDD §9.1 only says "a short radius"): destroying the generator switches off every
## fence within this distance for the rest of the level. It must reach every fence of its group.
@export_range(2.0, 40.0, 0.5, "suffix:m") var emp_radius: float = 16.0
