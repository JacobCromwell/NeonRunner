class_name WindowCyborgTuning
extends CyborgGunTuning
## Window cyborg numbers (GDD §9.2: the upper body in a building window), on top of the arm cannon's.
## Edit data/enemies/window_cyborg.tres. DESIGN-TBD: prototype values until playtested.

@export_group("Window")
## Its body blocks this band of wall-run heights, centred this far above the free wall-entry height
## (MovementTuning.wall_entry_height). With 0, entering the wall right before it hits it; entering
## earlier (lower by then) or from a jump or ramp (higher) passes below or above (GDD §9.2).
@export_range(-2.0, 2.0, 0.05, "suffix:m") var band_offset: float = 0.0
@export_range(0.3, 2.0, 0.05, "suffix:m") var band_height: float = 0.8
## How far its body reaches out of the facade toward the lanes (a wall runner's body spans ~1.1 m).
@export_range(0.2, 1.2, 0.05, "suffix:m") var reach: float = 0.55
## The hitbox's length along the track.
@export_range(0.3, 2.0, 0.05, "suffix:m") var hitbox_length: float = 0.7
## Size of the drawn window: along the track, and above / below the body band.
@export_range(0.8, 3.0, 0.05, "suffix:m") var window_length: float = 1.5
@export_range(0.0, 1.5, 0.05, "suffix:m") var window_above: float = 0.45
@export_range(0.0, 1.5, 0.05, "suffix:m") var window_below: float = 0.25
