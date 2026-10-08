class_name EnforcerTruck
extends Enemy
## The Enforcer Truck (GDD §9.13, owner, October 4, 2026; first in Corporate 2): a heavy armoured police truck
## that chases the runner from behind, can't be destroyed directly, and dies only when the player turns other
## enemies' attacks against it.
## - Arrival: where the generator planned it (its entry's `at`, enforcer_truck_rules.gd), its siren whoops and
##   it drives up from far behind (arrive_gap) to follow_gap behind the runner: behind the camera, so what
##   shows is its headlights' beams and its light bar's red and blue on the floor of its lane (cheap floor
##   shapes, EnforcerTruckModel.floor_lights) and a small marker at the screen's bottom edge under its lane
##   (EnforcerTruckMarker). The light bar takes turns red and blue; with Reduced flashing both stay lit.
## - Following: it copies the runner's lane lane_delay_seconds after they change it (GDD §9.13: about 0.8 s),
##   so a late dodge leaves it in the lane they just left. Its position is kept relative to the runner's
##   (never closer than its close gap: it never touches them).
## - Its attack: lasers down the runner's lane. Each volley is warned by a red line on the floor ahead in that
##   lane and a rising whine (warning_seconds), then its shots come up the lane from behind: columns of bolts
##   reaching over a slide and a whole jump, so only leaving the lane dodges it (which moves the truck too). A
##   volley starts only when a lane beside the runner's is clear to switch into until its last bolt has passed
##   (the escape), never while the runner is off the floor, and never from EnforcerTruckTuning.hold_seconds()
##   before one of its baits attacks (an Octodog's wind-up, a Buzz Overdrive's rev) until the attack is over, so
##   a volley never meets one, big attacks taking turns or not. Its volleys are a big attack (GDD §9: big
##   attacks take turns): it asks the director before each warning and waits while another type's is on.
## - Its baits: while an Octodog attacks it closes right up behind the runner (close_gap), so the lunge, which
##   ends lunge_overshoot behind the runner, reaches it; its body stays under the camera's line of sight to
##   the runner meanwhile (EnforcerTruckModel's profile). An Octodog's lunge or a Buzz Overdrive's charge that
##   crosses its body destroys it (Enemy._hurt_charge_contacts: it declares charge_bait, so a charge hurts it
##   though weapons don't, and the kill is the player's, a bait). It hops every ordinary gap in its lane; a
##   gap too wide to hop (EnforcerTruckTuning.max_hop_jump_fraction) or a Buzz Overdrive's cut in its lane
##   wrecks it, which is the player's kill too.
## - Riders: a cyborg the runner left alive (passed, not killed) in the truck's lane when the truck passes
##   that spot climbs aboard (GDD §9.13): it rides its roof as a crouching gunner, up to max_riders, and each
##   one raises its rate of fire. The passed cyborgs are recorded (lane, distance) as the runner passes them,
##   from before it arrives; a cyborg node still in play when it's picked up leaves play. Window cyborgs never
##   board; hosts don't either (DESIGN-TBD). Destroying it pays rider_bonus for each rider aboard.
## - Immune to weapons (never targeted, never hurt), stomps, claws and the dash (it never touches the runner).
## - It gives up after chase_seconds (GDD §9.13: about 25 s), never while a bait attack is on, and drops back.
## Numbers: EnforcerTruckTuning (data/enemies/enforcer_truck.tres). Look: EnforcerTruckModel. Placement:
## enforcer_truck_rules.gd. Its entry's params: {"baits": [player distances of the bait charges planned in
## its chase]}.

enum State { WAITING, ARRIVING, CHASING, LEAVING, WRECKED }
enum Volley { IDLE, WARNING, FIRING }

## Its bolts' name (ProjectilePool shots): what hits a runner says this.
const LASER_NAME: String = "Enforcer Truck laser"
## The red of every floor warning (the Octodog's lunge line, the Buzz Overdrive's).
const WARNING_COLOR := Color(1.0, 0.12, 0.08)
## The warning line's width, as a share of the lane, as the warning starts and at its end; and how far behind
## the runner it starts.
const LINE_WIDTH_START: float = 0.18
const LINE_WIDTH_END: float = 0.4
const LINE_BEHIND: float = 2.0
## A bolt has passed the runner once it's this far ahead of their hurtbox (metres).
const PASS_MARGIN: float = 0.5
## Seconds its wreck lasts before it's gone.
const WRECK_SECONDS: float = 1.6
## Its wreck's fireball (RunEffects.fireball, radius in metres; GDD §11).
const FIRE_SIZE: float = 3.6
## It's never closer behind the runner than this (metres from its front to the runner's middle).
const MIN_GAP: float = 1.6
const BuzzScript = preload("res://scripts/enemies/buzz_overdrive.gd")

var tuning: EnforcerTruckTuning
var state: State = State.WAITING
var volley: Volley = Volley.IDLE
## The lane under its middle, and the lane it's heading for (the runner's, lane_delay_seconds ago).
var lane: int = 0
var target_lane: int = 0
## Its front's distance behind the runner (metres).
var gap: float = 0.0
## Riders aboard, volleys started, and the lane the current volley sweeps (-1 between volleys).
var riders: int = 0
var volleys: int = 0
var volley_lane: int = -1
## True while it closes up behind the runner for an Octodog's attack.
var close: bool = false
## What happened, as [event, runner distance] (tests and the showcase read it): arrive, chase, close, release,
## warn, fire, volley_end, rider, hop, leave, wreck:<cause>.
var history: Array = []
## Every sound it asked for, in order (tests: each warning is heard; silent headless runs ask all the same).
var sounds_played: Array[StringName] = []
var model: EnforcerTruckModel
var marker: EnforcerTruckMarker

var _x: float = 0.0
var _switch_from: float = 0.0
var _switch_to: float = 0.0
var _switch_t: float = 1.0
## The runner's lane changes, [level time, lane], oldest first: it follows the one lane_delay_seconds old.
var _lane_log: Array = []
## Cyborgs the runner left alive behind them: {lane, at, cyborg (WeakRef)}; and those noted already.
var _passed: Array[Dictionary] = []
var _seen: Dictionary = {}
## Seconds since it arrived (its chase), and the chase time its last volley ended.
var _clock: float = 0.0
var _last_volley_end: float = -INF
var _volley_t: float = 0.0
var _shots_fired: int = 0
var _bolts: Array[Projectile] = []
var _flash_t: float = 0.0
## The close-up noted in its history (close, release).
var _close_noted: bool = false
## A hop over a gap: where its front was as it took off, and where its front is once its rear has cleared the
## gap (equal: not hopping). Keyed to its own distance, like everything it does.
var _hop_from: float = 0.0
var _hop_until: float = 0.0
## Its wreck: the cause, seconds into it, where its front is and how fast it still moves, its fall.
var _wreck_cause: StringName = &""
var _wreck_t: float = 0.0
var _wreck_front: float = 0.0
var _wreck_speed: float = 0.0
var _fall_v: float = 0.0
var _spin: float = 0.0
## The layout's gaps by lane, Vector2(start, end) in order, and each lane's cursor (the first that may still
## be ahead of its rear); the layout's cuts by lane.
var _lane_gaps: Array = []
var _gap_cursor: PackedInt32Array = PackedInt32Array()
var _lane_cuts: Array = []
var _run_speed: float = 18.0
var _jump: float = 10.0
var _dog_tuning: OctodogTuning
var _body: Hazard
var _floor: Node3D
var _wash_red: MeshInstance3D
var _wash_blue: MeshInstance3D
var _line: MeshInstance3D
var _voice: AudioStreamPlayer
var _canvas: CanvasLayer


## An Enforcer Truck's whole look for EnemyDirector.warm_up (which frees it) and ShaderWarmup (task PERF1):
## its model with every rider aboard and its light bar in every state, its floor lights bright and dim, and
## its warning line. The first one builds the meshes and materials every later truck shares. No physics object.
static func warm_up(world: RunWorld, _entry: Dictionary) -> Node:
	var t: EnforcerTruckTuning = EnemyDirector.tuning_for("enforcer_truck") as EnforcerTruckTuning
	if t == null:
		t = EnforcerTruckTuning.new()
	var variant: StringName = world.skin.enemy_variant if world.skin != null else &"city"
	var look := EnforcerTruckModel.new()
	look.name = "EnforcerTruckWarmUp"
	look.build(variant, t.body_size)
	look.set_riders(EnforcerTruckModel.RIDER_SLOTS.size())
	for color: Color in [EnforcerTruckModel.BAR_RED, EnforcerTruckModel.BAR_BLUE]:
		for state: StringName in [&"bright", &"dim", &"steady"]:
			var bar := MeshInstance3D.new()
			bar.mesh = look.bar_red.mesh
			bar.material_override = EnforcerTruckModel.bar_material(color, state)
			look.add_child(bar)
	for state: StringName in [&"bright", &"dim"]:
		var lights: Node3D = EnforcerTruckModel.floor_lights()
		for c: Node in lights.get_children():
			(c as MeshInstance3D).material_override = EnforcerTruckModel.floor_material(state)
		look.add_child(lights)
	var line := MeshInstance3D.new()
	line.mesh = GreyboxMaterials.unit_box()
	line.material_override = GreyboxMaterials.glow(WARNING_COLOR, 3.0, 0.5)
	look.add_child(line)
	return look


func _build() -> void:
	tuning = tuning_res as EnforcerTruckTuning
	if tuning == null:
		tuning = EnforcerTruckTuning.new()
	display_name = "Enforcer Truck"
	# GDD §9.13: immune to weapons, stomps, claws and the dash; only other enemies' charges hurt it, and the
	# kill is then the player's (a bait).
	immune_to_weapons = true
	charge_bait = true
	claw_immune = true
	stompable = false
	dash_kills = false
	_run_speed = world.tuning.run_speed
	_jump = world.tuning.jump_distance(_run_speed)
	_dog_tuning = EnemyDirector.tuning_for("octodog") as OctodogTuning
	if _dog_tuning == null:
		_dog_tuning = OctodogTuning.new()
	_index_layout()
	model = EnforcerTruckModel.new()
	model.name = "Model"
	add_child(model)
	model.build(world.skin.enemy_variant if world.skin != null else &"city", tuning.body_size)
	_floor = EnforcerTruckModel.floor_lights()
	_floor.position.y = 0.03
	add_child(_floor)
	_wash_red = _floor.get_node(^"WashRed") as MeshInstance3D
	_wash_blue = _floor.get_node(^"WashBlue") as MeshInstance3D
	var h: Vector3 = tuning.hitbox_size
	_body = add_hitbox(&"body", h, Vector3(0.0, tuning.hitbox_floor + h.y * 0.5, 0.2 + h.z * 0.5))
	_body.hazard_name = "Enforcer Truck"
	_body.set_enabled(false)
	_line = MeshInstance3D.new()
	_line.name = "WarningLine"
	_line.mesh = GreyboxMaterials.unit_box()
	_line.material_override = GreyboxMaterials.glow(WARNING_COLOR, 3.0, 0.5)
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.top_level = true
	_line.visible = false
	add_child(_line)
	_voice = AudioStreamPlayer.new()
	_voice.name = "Whine"
	if AudioServer.get_bus_index(SfxLibrary.BUS) >= 0:
		_voice.bus = SfxLibrary.BUS
	add_child(_voice)
	_canvas = CanvasLayer.new()
	_canvas.name = "MarkerLayer"
	# Under the HUD (layer 5): the HUD's icons stay on top where they meet.
	_canvas.layer = 4
	_canvas.visible = false
	add_child(_canvas)
	marker = EnforcerTruckMarker.new()
	_canvas.add_child(marker)
	lane = clampi(world.player.lane if world.player != null else int(spawn.get("lane", 0)), 0, world.geo.lane_count - 1)
	target_lane = lane
	_x = world.geo.lane_x(lane)
	gap = tuning.arrive_gap
	visible = false
	position = Vector3(_x, -60.0, TrackGeometry.world_z(float(spawn.get("at", 0.0))))


# --- Behaviour ---------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_record_passed_cyborgs()
	match state:
		State.WAITING:
			if world.player_distance() < float(spawn.get("at", 0.0)):
				return
			_arrive()
		State.WRECKED:
			return
	if not world.player.alive or not world.player.running:
		# The runner is down (or paused): it holds where it is behind them.
		_place(world.player_distance() - gap)
		return
	_clock += delta
	_track_player_lane()
	_update_lane(delta)
	close = state == State.CHASING and _octodog_engaged(tuning.close_lead_seconds)
	_update_gap(delta)
	var front: float = world.player_distance() - gap
	_place(front)
	if state != State.LEAVING and gap <= tuning.follow_gap + 2.0:
		_check_holes(front)
		if not alive:
			return
	_pick_up_riders(front)
	_update_volley(delta)
	_update_lights(delta)
	if state == State.ARRIVING and gap <= tuning.follow_gap + 0.5:
		state = State.CHASING
		_note(&"chase")
	elif state == State.CHASING and _clock >= tuning.chase_seconds and volley == Volley.IDLE \
			and not _bait_on(tuning.close_lead_seconds):
		_leave()


func _note(event: StringName) -> void:
	history.append([String(event), world.player_distance()])


## A sound for everyone to hear (the truck is behind the camera: none of its sounds is positional).
func _sound(sound: StringName) -> void:
	sounds_played.append(sound)
	world.play_sfx(sound)


## Its siren whoops and it drives in from far behind, in the runner's lane.
func _arrive() -> void:
	state = State.ARRIVING
	_clock = 0.0
	lane = clampi(world.player.lane, 0, world.geo.lane_count - 1)
	target_lane = lane
	_x = world.geo.lane_x(lane)
	_switch_t = 1.0
	_lane_log = [[world.level_time() - tuning.lane_delay_seconds, lane]]
	gap = tuning.arrive_gap
	visible = true
	_body.set_enabled(true)
	_canvas.visible = true
	# Cyborgs passed further back than where it drives in are behind it: it never reaches them.
	var front: float = world.player_distance() - gap
	for i: int in range(_passed.size() - 1, -1, -1):
		if float(_passed[i]["at"]) < front:
			_passed.remove_at(i)
	_sound(&"enforcer_siren")
	_note(&"arrive")


## It gives up (GDD §9.13: after about 25 s) and drops back out of sight.
func _leave() -> void:
	state = State.LEAVING
	world.director.give_up_turn(self)
	_note(&"leave")


func should_retire() -> bool:
	return state == State.LEAVING and gap >= tuning.gone_gap


## Records each cyborg the runner leaves alive behind them (GDD §9.13: picked up if it's in the truck's lane
## when the truck passes): its lane and where it was passed. Window cyborgs are another type and never
## board; hosts don't either unless the tuning says so (DESIGN-TBD).
func _record_passed_cyborgs() -> void:
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e.type_id != &"cyborg" or not (e is Cyborg):
			continue
		var c := e as Cyborg
		if c.mode != Cyborg.Mode.PASSED or (c.is_host and not tuning.picks_up_hosts):
			continue
		var id: int = c.get_instance_id()
		if _seen.has(id):
			continue
		_seen[id] = true
		_passed.append({"lane": c.lane, "at": c.track_distance(), "cyborg": weakref(c)})


## The passed cyborgs its front has reached: one in its lane climbs aboard (up to max_riders); the rest are
## behind it now.
func _pick_up_riders(front: float) -> void:
	var i: int = 0
	while i < _passed.size():
		var rec: Dictionary = _passed[i]
		if float(rec["at"]) > front:
			i += 1
			continue
		_passed.remove_at(i)
		if state == State.LEAVING or int(rec["lane"]) != lane or riders >= tuning.max_riders:
			continue
		riders += 1
		model.set_riders(riders)
		marker.riders = riders
		_sound(&"enforcer_pickup")
		_note(&"rider")
		var c: Cyborg = (rec["cyborg"] as WeakRef).get_ref() as Cyborg
		if c != null and c.alive:
			c.retire()


## The runner's lane, lane_delay_seconds ago: the lane it heads for.
func _track_player_lane() -> void:
	var now: float = world.level_time()
	var l: int = clampi(world.player.lane, 0, world.geo.lane_count - 1)
	if _lane_log.is_empty() or int(_lane_log[-1][1]) != l:
		_lane_log.append([now, l])
	var want: int = target_lane
	var keep: int = 0
	for i: int in _lane_log.size():
		if now - float(_lane_log[i][0]) >= tuning.lane_delay_seconds - 0.0001:
			want = int(_lane_log[i][1])
			keep = i
		else:
			break
	if keep > 0:
		_lane_log = _lane_log.slice(keep)
	if want != target_lane:
		target_lane = want
		_switch_from = _x
		_switch_to = world.geo.lane_x(want)
		_switch_t = 0.0


func _update_lane(delta: float) -> void:
	if _switch_t < 1.0:
		_switch_t = minf(1.0, _switch_t + delta / maxf(tuning.switch_seconds, 0.01))
		_x = lerpf(_switch_from, _switch_to, smoothstep(0.0, 1.0, _switch_t))
	lane = world.geo.lane_at(_x)


## Its gap behind the runner eases toward the one it wants: follow_gap, its close gap while an Octodog
## attacks, falling back while it leaves. Never under MIN_GAP: it never touches the runner.
func _update_gap(delta: float) -> void:
	if state == State.LEAVING:
		gap += tuning.leave_speed * delta
		return
	var want: float = tuning.follow_gap
	if close:
		want = tuning.close_gap_for(_dog_tuning, world.tuning.pace())
	var eased: float = want + (gap - want) * exp(-tuning.gap_rate * delta)
	var step: float = tuning.gap_speed_max * delta
	gap = maxf(clampf(eased, gap - step, gap + step), MIN_GAP)
	if close != _close_noted:
		_close_noted = close
		_note(&"close" if close else &"release")


func _place(front: float) -> void:
	position = Vector3(_x, 0.0, TrackGeometry.world_z(front))
	var y: float = 0.0
	if hopping():
		if front >= _hop_until:
			_hop_from = 0.0
			_hop_until = 0.0
		else:
			y = tuning.hop_height * sin(PI * clampf((front - _hop_from) / (_hop_until - _hop_from), 0.0, 1.0))
	model.position.y = y


## True while it bounces over a gap.
func hopping() -> bool:
	return _hop_until > _hop_from


## GDD §9.13: it hops every ordinary gap in its lane; a gap too wide to hop, or a Buzz Overdrive's cut in its
## lane, wrecks it (the player's kill: they led it there).
func _check_holes(front: float) -> void:
	if hopping():
		return
	var rear: float = front - tuning.body_size.z
	for cut: Dictionary in _lane_cuts[lane]:
		if front < float(cut["start"]) or rear > float(cut["end"]):
			continue
		var fc: FloorCut = world.track.floor_cut(lane, float(cut["end"]))
		if fc == null or not fc.began():
			continue
		for d: float in [front - 0.4, (front + rear) * 0.5]:
			if d >= fc.start and d <= fc.end and not fc.solid_at(d):
				_wreck(&"cut")
				return
	var gaps: PackedVector2Array = _lane_gaps[lane]
	var i: int = _gap_cursor[lane]
	while i < gaps.size() and gaps[i].y < rear:
		i += 1
	_gap_cursor[lane] = i
	while i < gaps.size() and gaps[i].x <= front:
		var g: Vector2 = gaps[i]
		if g.y > front - 0.4:
			if g.y - g.x > tuning.max_hop_jump_fraction * _jump + 0.001:
				_wreck(&"gap")
				return
			# An ordinary gap: it bounces over it, until its rear has cleared the far edge.
			_hop_from = front
			_hop_until = g.y + tuning.body_size.z
			_note(&"hop")
			return
		i += 1


## The layout's gaps and cuts by lane, in order (its hole checks walk them).
func _index_layout() -> void:
	var lanes: int = world.geo.lane_count
	_lane_gaps.resize(lanes)
	_lane_cuts.resize(lanes)
	_gap_cursor.resize(lanes)
	for l: int in lanes:
		var spans: Array[Vector2] = []
		for g: Dictionary in world.layout.gaps:
			if int(g["lane"]) == l:
				spans.append(Vector2(float(g["start"]), float(g["end"])))
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		_lane_gaps[l] = PackedVector2Array(spans)
		var cuts: Array[Dictionary] = []
		for c: Dictionary in world.layout.cuts:
			if int(c["lane"]) == l:
				cuts.append(c)
		_lane_cuts[l] = cuts
		_gap_cursor[l] = 0


## True while an Octodog is about to charge or charging (GDD §9.13: it closes up during an Octodog's attack):
## one winding up, lunging, or running ahead between its charges, and one with charges left whose stop (where
## it winds up) the runner reaches within `lead` seconds.
func _octodog_engaged(lead: float) -> bool:
	var pd: float = world.player_distance()
	var v: float = maxf(world.player.speed, 1.0)
	var scaling: float = world.config.enemy_scaling if world.config != null else 0.0
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or not (e is Octodog):
			continue
		var dog := e as Octodog
		if dog.in_doghouse:
			continue
		match dog.phase:
			Octodog.Phase.WINDUP, Octodog.Phase.LUNGE, Octodog.Phase.TURN, Octodog.Phase.SPRINT, Octodog.Phase.PACE:
				return true
			Octodog.Phase.IDLE:
				if dog.charges_done < dog.charges and dog.track_distance() - pd \
						<= _dog_tuning.stop_distance(v, scaling, world.tuning.pace()) + lead * v:
					return true
	return false


## True while one of its baits attacks or is about to within `lead` seconds: an Octodog (_octodog_engaged),
## or a Buzz Overdrive revving or charging, or parked or rolling in that close to its rev.
func _bait_on(lead: float) -> bool:
	if _octodog_engaged(lead):
		return true
	var pd: float = world.player_distance()
	var v: float = maxf(world.player.speed, 1.0)
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e.type_id != &"buzz_overdrive":
			continue
		var s: int = int(e.get(&"state"))
		if s == BuzzScript.State.REV or s == BuzzScript.State.CHARGE:
			return true
		var cut: Dictionary = e.get(&"cut")
		if (s == BuzzScript.State.PARKED or s == BuzzScript.State.ROLL) and not cut.is_empty() \
				and FloorCutPlan.warn_at(cut) - pd <= lead * v:
			return true
	return false


# --- Volleys -----------------------------------------------------------------------------------------

## Its volleys are a big attack (GDD §9; §9.13, proposed): from its warning until its last bolt has passed
## the runner.
func is_major_attack_active() -> bool:
	return alive and volley != Volley.IDLE


## Seconds until it may warn of its next volley, counted from the last one's end: the interval, quicker for
## each rider aboard (GDD §9.13).
func next_volley_in() -> float:
	if _last_volley_end == -INF:
		return maxf(tuning.first_volley_seconds - _clock, 0.0)
	return maxf(_last_volley_end + tuning.volley_interval(riders) - _clock, 0.0)


func _update_volley(delta: float) -> void:
	match volley:
		Volley.IDLE:
			if _ready_to_fire() and not world.director.major_attack_blocked(self):
				_warn()
		Volley.WARNING:
			_volley_t += delta
			if _volley_t >= tuning.warning_seconds:
				volley = Volley.FIRING
				_volley_t = 0.0
				_shots_fired = 0
				_note(&"fire")
				_fire_due()
		Volley.FIRING:
			_volley_t += delta
			_fire_due()
			if _shots_fired >= tuning.shots_per_volley and not _bolts_on_their_way():
				_end_volley()
	_update_line(delta)


## Ready for a volley: chasing at its follow gap, its interval over, the runner on the floor, no bait about
## to attack before the volley would be over (so it never fires into one's attack, big attacks taking turns
## or not), and a lane beside the runner's clear to escape into (asked last).
func _ready_to_fire() -> bool:
	if state != State.CHASING or close or absf(gap - tuning.follow_gap) > 1.0 or next_volley_in() > 0.0:
		return false
	var p: Player = world.player
	if not p.alive or not p.running or p.surface != Player.Surface.FLOOR:
		return false
	if _bait_on(tuning.hold_seconds()):
		# Its baits come first: it leaves the director's queue at once (harmless when it isn't waiting), so
		# its place there never holds an Octodog back.
		world.director.give_up_turn(self)
		return false
	return escape_clear(clampi(p.lane, 0, world.geo.lane_count - 1))


func _warn() -> void:
	volley = Volley.WARNING
	_volley_t = 0.0
	volleys += 1
	volley_lane = clampi(world.player.lane, 0, world.geo.lane_count - 1)
	_line.visible = true
	_play_whine()
	_note(&"warn")


## Fires the shots due by now: each a column of bolts at bolt_heights, from its front up the lane its
## volley sweeps, reaching the runner bolt_flight_seconds later.
func _fire_due() -> void:
	var p: Player = world.player
	while _shots_fired < tuning.shots_per_volley and _volley_t >= _shots_fired * tuning.shot_gap_seconds - 0.0001:
		var rel: float = maxf(gap, 1.0) / maxf(tuning.bolt_flight_seconds, 0.05)
		var velocity := Vector3(0.0, 0.0, -(maxf(p.speed, 1.0) + rel))
		var z: float = TrackGeometry.world_z(p.distance - gap)
		var x: float = world.geo.lane_x(volley_lane)
		for h: float in tuning.bolt_heights:
			var shot: Projectile = world.projectiles.fire_enemy(Vector3(x, h, z), velocity, &"enemy_bolt", LASER_NAME,
				tuning.bolt_flight_seconds + 1.2)
			if shot != null:
				_bolts.append(shot)
		_sound(&"enforcer_laser")
		_shots_fired += 1


## True while a bolt of this volley hasn't passed the runner yet (the same shot: the pool reuses them).
func _bolts_on_their_way() -> bool:
	var pz: float = world.player.position.z
	var reach: float = world.tuning.hurtbox_size.z * 0.5 + PASS_MARGIN
	for i: int in range(_bolts.size() - 1, -1, -1):
		var shot: Projectile = _bolts[i]
		if not is_instance_valid(shot) or not shot.in_use or shot.hazard_name != LASER_NAME \
				or shot.position.z < pz - reach - shot.radius:
			_bolts.remove_at(i)
	return not _bolts.is_empty()


func _end_volley() -> void:
	volley = Volley.IDLE
	volley_lane = -1
	_last_volley_end = _clock
	_bolts.clear()
	_line.visible = false
	_note(&"volley_end")


## True if a lane beside `target` is clear for the runner to switch into and stay in while a volley would
## sweep `target`: from escape_reaction_seconds of running after its warning to its last bolt's passing, no
## hole, live fence, floor cut, zone doodad, hover truck holding the lane, or other enemy on its floor.
func escape_clear(target: int) -> bool:
	var p: Player = world.player
	var v: float = maxf(p.speed, 1.0)
	var from: float = p.distance + tuning.escape_reaction_seconds * v
	var to: float = p.distance + tuning.volley_seconds() * v + 2.0
	for l: int in [target - 1, target + 1]:
		if l >= 0 and l < world.geo.lane_count and lane_open(l, from, to):
			return true
	return false


## True if the floor of `lane` is clear from track distance `from` to `to` (escape_clear).
func lane_open(lane_index: int, from: float, to: float) -> bool:
	var lay: LevelLayout = world.layout
	if lay.gapped_between(lane_index, from, to) or lay.doodad_between(from, to, lane_index) \
			or lay.cut_between(from, to, lane_index):
		return false
	var half: float = world.tuning.fence_depth * 0.5 + 0.5
	for f: Dictionary in lay.fences:
		if int(f["lane"]) == lane_index and float(f["at"]) >= from - half and float(f["at"]) <= to + half \
				and not f.get("disabled", false):
			return false
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e == self:
			continue
		if e.type_id == &"hover_truck":
			if int(e.get(&"lane")) == lane_index:
				return false
			continue
		var d: float = e.track_distance()
		if d < from - 3.0 or d > to + 3.0 or not LevelGenerator.enemy_uses_floor({"type": String(e.type_id)}):
			continue
		if world.geo.lane_at(e.global_position.x) == lane_index:
			return false
	return true


## The red line on the floor of the lane its volley sweeps (GDD §9.13), from just behind the runner to
## line_ahead ahead of them: widening over the warning and pulsing (only widening with Reduced flashing), on
## until the volley's last bolt has passed.
func _update_line(delta: float) -> void:
	if volley == Volley.IDLE or volley_lane < 0:
		_line.visible = false
		return
	_line.visible = true
	var pd: float = world.player_distance()
	var k: float = 1.0 if volley == Volley.FIRING else clampf(_volley_t / maxf(tuning.warning_seconds, 0.05), 0.0, 1.0)
	var t: float = _clock + delta
	var beat: float = 1.0 if Settings.flashing_reduced else 0.9 + 0.15 * sin(t * 30.0)
	var width: float = world.geo.lane_width * lerpf(LINE_WIDTH_START, LINE_WIDTH_END, k) * beat
	var from: float = pd - LINE_BEHIND
	var to: float = pd + tuning.line_ahead
	_line.global_transform = Transform3D(Basis.from_scale(Vector3(width, 0.04, to - from)),
		Vector3(world.geo.lane_x(volley_lane), 0.03, TrackGeometry.world_z((from + to) * 0.5)))


## Its rising whine (GDD §9.13), on its own voice, stretched by pitch to last its warning. Silent headless.
func _play_whine() -> void:
	sounds_played.append(&"enforcer_whine")
	var library: SfxLibrary = world.sfx_library
	if library == null or not SfxLibrary.audible():
		return
	var stream: AudioStream = library.stream(&"enforcer_whine")
	if stream == null:
		return
	_voice.stream = stream
	_voice.volume_db = library.volume(&"enforcer_whine")
	var length: float = stream.get_length()
	_voice.pitch_scale = clampf(length / maxf(tuning.warning_seconds, 0.05), 0.5, 2.0) if length > 0.0 else 1.0
	_voice.play()


# --- Lights and marker --------------------------------------------------------------------------------

## The light bar takes turns red and blue (flash_hz), on the truck and in its floor washes, and on the
## marker; with Reduced flashing both stay lit, steady and softer.
func _update_lights(delta: float) -> void:
	_flash_t += delta
	var reduced: bool = Settings.flashing_reduced
	var phase: int = int(_flash_t * tuning.flash_hz * 2.0) % 2
	model.set_flash(phase, reduced)
	var dim: Material = EnforcerTruckModel.floor_material(&"dim")
	var bright: Material = EnforcerTruckModel.floor_material(&"bright")
	_wash_red.material_override = dim if reduced or phase != 0 else bright
	_wash_blue.material_override = dim if reduced or phase != 1 else bright
	marker.lane_x = _x
	marker.runner_z = world.player.position.z
	marker.phase = -1 if reduced else phase
	if state == State.LEAVING:
		marker.shown = clampf(1.0 - (gap - tuning.follow_gap) / maxf(tuning.gone_gap - tuning.follow_gap, 1.0), 0.0, 1.0)
	else:
		marker.shown = minf(marker.shown + delta * 3.0, 1.0)


# --- Destroyed -----------------------------------------------------------------------------------------

## Wrecked in a hole in its lane (a gap too wide to hop, a Buzz Overdrive's cut): the player's kill.
func _wreck(cause: StringName) -> void:
	defeat(cause)


func _on_defeated(cause: StringName) -> void:
	state = State.WRECKED
	_wreck_cause = cause
	_wreck_t = 0.0
	_wreck_front = world.player_distance() - gap
	_wreck_speed = maxf(world.player.speed, 1.0) * (0.85 if cause == CHARGE_DAMAGE_CAUSE else 0.5)
	_fall_v = 0.0
	volley = Volley.IDLE
	volley_lane = -1
	_line.visible = false
	_voice.stop()
	_canvas.visible = false
	_floor.visible = false
	world.director.give_up_turn(self)
	_note(StringName("wreck:" + String(cause)))
	# GDD §9.13: destroying it pays a bonus for each rider aboard (its own score comes from the ScoreKeeper:
	# a bait, the player's kill).
	if riders > 0:
		world.score.add_bonus(&"enforcer_riders", riders * tuning.rider_bonus, "Riders x%d" % riders)
	var at: Vector3 = global_position + Vector3(0.0, 1.2, 1.2)
	_sound(&"enforcer_crash" if cause == &"gap" or cause == &"cut" else &"truck_explode")
	world.effects.fireball(at, FIRE_SIZE)
	world.effects.burst(at + Vector3(0.0, 0.8, 0.0), Color(0.3, 0.3, 0.33), 24, 1.1)
	world.effects.debris(at, Color(0.3, 0.3, 0.34), 10, 0.7)
	world.effects.shake(0.35, 0.4)


## Its wreck: in a hole it plunges in nose first; struck by a charge it skids, spins out and falls back,
## burning. Gone after WRECK_SECONDS.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state != State.WRECKED or world == null:
		return
	_wreck_t += delta
	_wreck_front += _wreck_speed * delta
	_wreck_speed = move_toward(_wreck_speed, 0.0, 22.0 * delta)
	position = Vector3(_x, 0.0, TrackGeometry.world_z(_wreck_front))
	if _wreck_cause == &"gap" or _wreck_cause == &"cut":
		_fall_v -= 18.0 * delta
		model.position.y += _fall_v * delta
		model.rotation.x = lerpf(model.rotation.x, -0.75, 1.0 - exp(-5.0 * delta))
	else:
		_spin = lerpf(_spin, 0.9, 1.0 - exp(-3.0 * delta))
		model.rotation.y = _spin * signf(_x - world.player.position.x + 0.01)
		model.rotation.z = 0.12 * sin(_wreck_t * 9.0) * (1.0 - _wreck_t / WRECK_SECONDS)
	if _wreck_t >= WRECK_SECONDS:
		queue_free()


## Weapons never target it (immune_to_weapons). Where effects appear: just behind its front, chest high.
func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 1.2, 1.2)


func hit_radius() -> float:
	return 1.4
