class_name DeathScreen
extends Control
## The revive offer after a death (GDD §4: mobile: rewarded ad or revive item; PC: revive item).
## With nothing to offer it goes straight on to the run summary. Placeholder look.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var options: Dictionary = App.revive_options()
	if not options["item"] and not options["ad"]:
		App.decline_revive.call_deferred()
		return
	ScreenKit.fill(self)
	ScreenKit.backdrop(self)
	var col: VBoxContainer = ScreenKit.column(self, 420.0)
	ScreenKit.title(col, "DOWN!", 40)
	var cause: String = App.run.death_cause if App.run != null else ""
	ScreenKit.label(col, "Hit by: %s" % cause, 16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if options["item"]:
		ScreenKit.button(col, "Revive (%d left)" % options["stock"], App.revive_with_item)
	if options["ad"]:
		ScreenKit.button(col, "Watch an ad to revive", App.revive_with_ad)
	ScreenKit.button(col, "Give up", App.decline_revive)
	ScreenKit.focus_first(self)
