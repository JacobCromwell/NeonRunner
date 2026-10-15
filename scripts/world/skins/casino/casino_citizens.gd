class_name CasinoCitizens
extends MarketCitizens
## The Casino's citizens (CasinoSkin; task K5): the Marketplace's, in the Casino's windows, picked the same
## way but without listing every window first. MarketCitizens.build() asks for all of a chunk's windows
## (about eighteen entries of ten fields, a dictionary each) to keep a sixth of them; here the sixth is
## picked from the windows' positions alone (CasinoFacades.windows_picked()), the same windows, the same
## citizens, a chunk build about 0.15 ms cheaper. The gates are MarketCitizens's own (its constants, the
## same hash salt), and test_casino_skin checks the two builders agree.

## The hash salt MarketCitizens.build() picks its citizens with (hash01(side, key, salt) < CITIZEN_SHARE).
const PICK_SALT: int = 211


func build(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	if not Settings.citizens_enabled:
		return
	var facades: CasinoFacades = skin.facades() as CasinoFacades
	for w: Dictionary in facades.windows_picked(side, face_x, start, end, PICK_SALT, CITIZEN_SHARE):
		if bool(w["screen"]):
			continue
		var at: float = float(w["at"])
		if skin.reserved_near(side, at, CYBORG_MARGIN):
			continue
		_build_one(parent, w, side, MeshKit.key(at))
