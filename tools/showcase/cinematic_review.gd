extends Node3D
## Cinematic review, for visual review only (not part of the game): plays a campaign slot's cinematic
## on its own (as the App would, from its step: its zone, skin and music), or the toolkit's sampler (a
## cinematic described in data, cinematic_sampler.tres: the runner and two cyborgs, every kind of camera
## move and event), then plays it again. Render it on both renderers:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/cine/f.png --quit-after 100 res://tools/showcase/cinematic_review.tscn -- --slot=city/intro
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options:
##   --slot=<step id>     the campaign step whose cinematic plays (default city/intro): a zone's intro
##                        (<zone>/intro), the City's boss intro (city/boss_intro)
##   --sampler            the toolkit sampler instead, in the zone --zone= names (default city)
##   --lanes=N            lanes (default: as many as a level on this device)
##   --reduced-flashing   with Settings > Reduced flashing on
##   --once               quits when it ends instead of playing it again
## Each event is printed with its time and frame as it fires, to find the matching frames.

const SAMPLER_PATH: String = "res://tools/showcase/cinematic_sampler.tres"

var cinematic: Cinematic
var _frame: int = 0
var _logged: int = 0


func _ready() -> void:
	var lanes: int = int(_opt("lanes", "0"))
	if lanes > 0:
		App.rules.lanes_pc = lanes
		App.rules.lanes_mobile = lanes
	if _has("reduced-flashing"):
		App.profile.settings["reduced_flashing"] = true
		Settings.apply_visuals(App.profile)
	_start()


func _process(_delta: float) -> void:
	_frame += 1
	var seq := cinematic as CinematicSequencer
	if seq != null and is_instance_valid(seq):
		while _logged < seq.log_lines.size():
			print("%6.2f s  frame %4d  %s" % [seq.time, _frame, seq.log_lines[_logged]])
			_logged += 1


func _start() -> void:
	var step: CampaignStep = null
	var def: CinematicDef = null
	if _has("sampler"):
		var seq := CinematicSequencer.new()
		seq.timeline = load(SAMPLER_PATH) as CineTimeline
		cinematic = seq
		def = CinematicDef.new()
		def.id = &"toolkit_sampler"
		def.title = "The toolkit sampler"
		# As if it filled a slot of the zone: its look, music and text come from the zone's data.
		var zone_id: String = _opt("zone", "city")
		step = CampaignStep.new()
		step.kind = CampaignStep.Kind.CINEMATIC
		step.id = "%s/sampler" % zone_id
		for zi: int in App.campaign.zones.size():
			if String(App.campaign.zones[zi].id) == zone_id:
				step.zone = App.campaign.zones[zi]
				step.zone_index = zi
	else:
		step = App.campaign.step(_opt("slot", "city/intro"))
		if step == null or step.cinematic == null or not step.cinematic.is_built():
			push_error("cinematic_review: %s has no built cinematic" % _opt("slot", "city/intro"))
			get_tree().quit(1)
			return
		def = step.cinematic
		cinematic = (load(def.scene) as PackedScene).instantiate() as Cinematic
	add_child(cinematic)
	cinematic.skip_requested.connect(cinematic.skip)
	cinematic.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	_logged = 0
	print("playing %s (%s) at frame %d" % [def.id, step.id if step != null else "-", _frame])
	cinematic.play(def, step)


func _on_finished() -> void:
	print("finished at frame %d" % _frame)
	if _has("once"):
		get_tree().quit()
		return
	var old: Cinematic = cinematic
	old.queue_free()
	_start.call_deferred()


static func _opt(opt_name: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % opt_name):
			return arg.get_slice("=", 1)
	return default


static func _has(flag: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + flag)
