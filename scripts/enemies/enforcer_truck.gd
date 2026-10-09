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
##   (never closer than MIN_GAP behind them in their lane: it never touches them).
## - Showing itself (the owner, October 8, 2026; GDD §9.13): behind the camera its model is never seen, so now
##   and then (as it arrives, and once more mid-chase where there's room: EnforcerTruckTuning.show_count) it
##   speeds up into view beside the runner, its front show_ahead ahead of them in a lane next to theirs, where
##   the chase camera shows its whole model, light bar and riders (EnforcerTruckView), holds there show_seconds
##   with its siren swelling as it pulls alongside, then drops back to follow_gap and takes up the runner's lane
##   again. Its sides are safe but solid meanwhile, like the hover truck's (GDD §9.3): a lane blocker bumps a
##   lane change into it back, and its body never reaches the runner. Fair, or it doesn't happen
##   (show_lane_now, show_problem): the runner on the floor in a lane with a lane on each side; in its lane
##   (show_lane), nothing that would wreck it (a gap too wide to hop, a cut) until it's back in the runner's
##   lane, and, where it's in view, nothing it would drive through or the runner may need (a fence, a doodad,
##   a floor enemy, a pad, a speed pad, a ramp: it never takes a lane the runner needs; it hops ordinary gaps);
##   wherever the runner must leave their lane (a doodad, a floor enemy, a cut's lane) the lane on its far side
##   open, and wherever their lane is otherwise blocked (a hole or fence) that one open or the truck's lane
##   blocked too (the runner always keeps a lane to dodge into: it never takes the only free one); no enemy in
##   its lane or beyond it near the runner (from the camera it would hide it); no bait's turn coming before it's
##   back behind them (its hold shortened to fit, never under show_min_seconds); no hover truck or Gilded
##   Sentinel about. A showing takes a turn like a big attack
##   (GDD §9): it starts only when the director lets it (no other type's big attack on or waiting ahead of it),
##   and no other type's starts while it's in view, so a volley's, a bait's or another attack's warning never
##   meets it. It never fires while it shows itself. It stays alongside show_seconds, or drops back sooner
##   (after show_min_seconds) before anything in its lane ahead; it gives way (drops back at once, faster) if
##   the runner moves toward its lane (a bumped lane change), leaves the floor, loses their other lane, or an
##   attack, a bait or an enemy beside it comes. Its marker fades while it's on screen.
## - Destroyed, it blows up where the player sees it (the owner, October 8, 2026): its wreck lurches on into
##   view (wreck_gap behind the runner, spinning out or nose-diving into its hole, at the hole's far edge if it
##   gets there first) and explodes there: one of the shared yellow-and-red fireballs (RunEffects.fireball; GDD
##   §11, the owner, October 8, 2026), as big as its blast (smaller in the runner's lane) and carried along with
##   its wreck in the runner's frame so it stays in view while it burns; RunEffects' sparks and debris, its riders
##   going up with it, a shake and truck_explode. Reduced flashing softens the fireball.
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
## Showing itself: not; pulling up beside the runner (its lane change first, behind the camera); alongside
## them; dropping back behind them.
enum Show { NONE, PULL_UP, ALONGSIDE, DROP_BACK }

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
## It's never closer behind the runner than this in their lane (metres from its front to the runner's middle).
const MIN_GAP: float = 1.6
## Its solid sides' height while it shows itself: over a jump, its roof and its riders.
const BLOCKER_HEIGHT: float = 5.0
## Where it blows up, in its own space (its front at the origin, its body back along +z): over its nose, this
## high and this far back; beside the runner a little higher, further back and BLAST_SHIFT further from their
## lane. With its wreck's front wreck_gap behind the runner, its blast sits low in the band of the chase camera's
## view between the screen's bottom edge and its line of sight to the runner (blast_spot).
const BLAST_HEIGHT: float = 0.8
const BLAST_BACK_IN_LANE: float = 0.4
const BLAST_BACK: float = 0.6
const BLAST_SHIFT: float = 0.3
## Its blast's look is one of the shared fireballs (RunEffects.fireball; GDD §11, the owner, October 8, 2026): as big
## as the blast (EnforcerTruckTuning.blast_radius, blast_radius_in_lane), its fire burning as long (blast_seconds,
## fire_pace), carried along with its wreck (blast_drift). Its fire and embers fly out of its centre only this share
## as far as a free fireball's do (less in the runner's lane, so it keeps low, under the camera's line of sight to
## them), and it leaves no smoke: everything it draws only adds light, so nothing of it can hide the runner.
## DESIGN-TBD (docs/questions/h-merge-main.md): the spreads, no smoke, and C6b's sizes.
const FIRE_SPREAD: float = 0.7
const FIRE_SPREAD_IN_LANE: float = 0.5
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
## Showing itself: the phase, the lane it shows itself in (-1 between showings), and the showings so far.
var show_phase: Show = Show.NONE
var show_lane: int = -1
var shows: int = 0
## What happened, as [event, runner distance] (tests and the showcase read it): arrive, chase, close, release,
## warn, fire, volley_end, rider, hop, leave, show (a showing begins), alongside, drop_back (its time is up),
## give_way (it drops back early), shown (back behind the runner), wreck:<cause>, blast.
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
## Its wreck (it lurches on into view, then blows up): the cause, seconds into it, its gap behind the runner as
## it was wrecked and where it blows up, the far edge of the hole it fell in (INF: none), whether it's in the
## runner's lane, its fall and spin, its trail of sparks, whether it has blown up yet (and when), and seconds since.
var _wreck_cause: StringName = &""
var _wreck_t: float = 0.0
var _wreck_gap0: float = 0.0
var _wreck_gap: float = 0.0
var _wreck_far: float = INF
var _hole_far: float = INF
var _wreck_in_lane: bool = false
var _fall_v: float = 0.0
var _sink: float = 0.0
var _spin: float = 0.0
var _trail_left: float = 0.0
var _blast_at: float = -1.0
var _blast_t: float = 0.0
## Its showing: seconds alongside, true while it drops back to give way (faster), the chase time its last
## showing ended (-INF before its first: that one comes as soon as it may, on arrival where there's room), and a
## lane change into its side bumped back since the last frame.
var _show_t: float = 0.0
## How long this showing stays alongside (show_seconds, or less: show_lane_now).
var _show_hold: float = 0.0
var _yielding: bool = false
var _last_show_end: float = -INF
var _bumped: bool = false
## The layout's side of what its showings need (EnforcerTruckRoom), read once.
var _room: EnforcerTruckRoom
## Whether its look fits on screen beside a runner without hiding them (EnforcerTruckRoom.fits_for): by runner
## lane * 64 + its lane.
var _fits: Dictionary = {}
var _blocker: Area3D
var _siren: AudioStreamPlayer
var _siren_db: float = 0.0
var _swell_t: float = -1.0
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
## its model with every rider aboard and its light bar in every state, its floor lights bright and dim, and its
## warning line (its blast is a shared fireball, whose materials ShaderWarmup draws with RunEffects'). The first
## one builds the meshes and materials every later truck shares. No physics object.
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
	# Its solid sides while it shows itself (GDD §9.3's hover truck): a lane change into it is bumped back. Off
	# (no collision layer) otherwise.
	var reach: float = tuning.body_size.z + tuning.blocker_ahead
	_blocker = add_lane_blocker(Vector3(world.geo.lane_width * 0.9, BLOCKER_HEIGHT, reach),
		Vector3(0.0, BLOCKER_HEIGHT * 0.5, tuning.body_size.z - reach * 0.5))
	_set_blocker(false)
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
	_siren = AudioStreamPlayer.new()
	_siren.name = "Siren"
	_siren.bus = _voice.bus
	add_child(_siren)
	if world.player != null:
		world.player.movement_event.connect(_on_player_event)
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
		# The runner is down (or paused): it holds where it is behind (or beside) them.
		_place(world.player_distance() - gap)
		_bumped = false
		return
	_clock += delta
	_log_player_lane()
	_update_show(delta)
	if show_phase == Show.NONE:
		_follow_player_lane()
	_update_lane(delta)
	close = state == State.CHASING and show_phase == Show.NONE and _octodog_engaged(tuning.close_lead_seconds)
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
	_update_siren(delta)
	if state == State.ARRIVING and gap <= tuning.follow_gap + 0.5:
		state = State.CHASING
		_note(&"chase")
	elif state == State.CHASING and show_phase == Show.NONE and _clock >= tuning.chase_seconds \
			and volley == Volley.IDLE and not _bait_on(tuning.close_lead_seconds):
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
	_note(&"arrive")
	# It shows itself as it arrives where there's room (its siren swelling as it pulls alongside), else its
	# siren whoops as it drives in behind the runner.
	var now: Array = show_lane_now()
	if int(now[0]) >= 0 and not world.director.major_attack_blocked(self):
		_begin_show(int(now[0]), float(now[2]))
	else:
		_sound(&"enforcer_siren")


## It gives up (GDD §9.13: after about 25 s) and drops back out of sight.
func _leave() -> void:
	state = State.LEAVING
	world.director.give_up_turn(self)
	_set_blocker(false)
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


## Notes each of the runner's lane changes on the level clock (it follows them lane_delay_seconds later, and
## while it shows itself it keeps noting them).
func _log_player_lane() -> void:
	var l: int = clampi(world.player.lane, 0, world.geo.lane_count - 1)
	if _lane_log.is_empty() or int(_lane_log[-1][1]) != l:
		_lane_log.append([world.level_time(), l])


## The runner's lane, lane_delay_seconds ago: the lane it heads for.
func _follow_player_lane() -> void:
	var now: float = world.level_time()
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
## attacks, show_ahead ahead of them while it shows itself, falling back while it leaves. Never under MIN_GAP
## unless it's in a lane beside theirs (_least_gap): it never touches the runner.
func _update_gap(delta: float) -> void:
	if state == State.LEAVING:
		gap += tuning.leave_speed * delta
		return
	var want: float = tuning.follow_gap
	var top: float = tuning.gap_speed_max
	match show_phase:
		Show.PULL_UP, Show.ALONGSIDE:
			want = -tuning.show_ahead
			if gap <= tuning.follow_gap + 0.5:
				top = tuning.show_close_speed
		Show.DROP_BACK:
			top = tuning.show_yield_speed if _yielding else tuning.show_drop_speed
	if close:
		want = tuning.close_gap_for(_dog_tuning, world.tuning.pace())
	var eased: float = want + (gap - want) * exp(-tuning.gap_rate * delta)
	var step: float = top * delta
	gap = maxf(clampf(eased, gap - step, gap + step), _least_gap())
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
				_hole_far = INF
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
				_hole_far = g.y
				_wreck(&"gap")
				return
			# An ordinary gap: it bounces over it, until its rear has cleared the far edge.
			_hop_from = front
			_hop_until = g.y + tuning.body_size.z
			_note(&"hop")
			return
		i += 1


## The layout's gaps and cuts by lane, in order (its hole checks walk them), and what its showings keep off
## (_index_showing).
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
	_index_showing()


## What its showings need from the layout (EnforcerTruckRoom), and where its look fits on screen (in every look, as
## the generator planned its window: the same in every zone's skin), once.
func _index_showing() -> void:
	_room = EnforcerTruckRoom.build(world.layout, world.geo, world.tuning, tuning, world.tuning.run_speed)
	_fits = EnforcerTruckRoom.fits_for(world.tuning, tuning, world.geo.lane_count)


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


# --- Showing itself ----------------------------------------------------------------------------------

## Starts, moves on and ends its showings (GDD §9.13 "Showing itself"; the class doc). A showing takes its turn
## like a big attack (GDD §9, big attacks take turns): it starts only when the director lets it, and no other
## type's big attack starts while it's on (is_major_attack_active), so it never meets another attack's warning.
func _update_show(delta: float) -> void:
	match show_phase:
		Show.NONE:
			var now: Array = show_lane_now()
			if int(now[0]) >= 0 and not world.director.major_attack_blocked(self):
				_begin_show(int(now[0]), float(now[2]))
		Show.PULL_UP:
			if _must_give_way():
				_drop_back(true)
			elif _switch_t >= 1.0 and gap <= -tuning.show_ahead + 0.3:
				show_phase = Show.ALONGSIDE
				_show_t = 0.0
				_note(&"alongside")
		Show.ALONGSIDE:
			_show_t += delta
			if _must_give_way():
				_drop_back(true)
			elif _show_t >= _show_hold \
					or (_show_t >= tuning.show_min_seconds and not _lane_ahead_clear(show_lane)):
				_drop_back(false)
		Show.DROP_BACK:
			if gap >= tuning.follow_gap - 0.5:
				_end_show()
	_bumped = false


## Why it can't show itself now ("" if it can: show_lane_now()[0] is the lane).
func show_problem() -> String:
	return show_lane_now()[1]


## The showing window the generator planned in its chase (task C6c; enforcer_truck_rules.gd, its params' "show"):
## Vector2(from, to), the stretch kept calm for it, or Vector2(INF, -INF) without one.
func show_window() -> Vector2:
	var show: Variant = (spawn.get("params", {}) as Dictionary).get("show")
	if not (show is Dictionary) or not (show as Dictionary).has("from"):
		return Vector2(INF, -INF)
	return Vector2(float(show["from"]), float(show["to"]))


## Where the runner is as its planned showing is due to begin (task C6c; INF without a window).
func show_at() -> float:
	var show: Variant = (spawn.get("params", {}) as Dictionary).get("show")
	return float((show as Dictionary).get("at", INF)) if show is Dictionary else INF


## True while it claims its turn among the big attacks for its planned showing (task C6c; as a Buzz Overdrive claims
## its turn before its rev): from show_claim_seconds of running before the runner reaches where it's due (waiting to
## arrive, for one as it arrives) until it begins (its showing holds the turn then) or the runner is
## show_window_slack_seconds past where it's due, while it hasn't shown itself yet. Another type's big attack that
## gets ready meanwhile waits for it (is_major_attack_active; EnemyDirector), one already on ends first.
func claiming() -> bool:
	var due: float = show_at()
	if due == INF or shows > 0 or not alive or state == State.LEAVING or state == State.WRECKED \
			or tuning.show_count <= 0 or world == null or world.player == null:
		return false
	var d: float = world.player_distance()
	var v: float = _plan_speed()
	return d >= due - tuning.show_claim_seconds * v and d <= due + tuning.show_window_slack_seconds * v


## True while its volleys wait for its planned showing (task C6c: the generator kept its window calm for it): it
## hasn't shown itself yet, and a volley warned now would still be on as the runner reaches where the showing is
## due, until they're show_window_slack_seconds of running past it (the window holds a showing begun that late).
func _holds_for_showing() -> bool:
	var due: float = show_at()
	if shows > 0 or due == INF or tuning.show_count <= 0:
		return false
	var d: float = world.player_distance()
	var v: float = _plan_speed()
	return d + (tuning.volley_seconds() + tuning.escape_reaction_seconds) * v >= due \
		and d <= due + tuning.show_window_slack_seconds * v


## [the lane it may show itself in now (-1: none), why not ("" if it may), and if it may, how long it stays
## alongside (show_seconds, or less to be back behind the runner in time for a bait's turn or its chase's end)]:
## a lane beside the runner's, the outer one first, or two lanes in from a runner by a wall (EnforcerTruckRoom
## .sides; task C6c), where its look fits on screen without hiding the runner or their side of the floor
## (EnforcerTruckView) and everything else a showing needs holds (the class doc; EnforcerTruckRoom for the layout's
## side, and what's in play here); one whose lane stays clear for its whole stay first (its planned window's, task
## C6c), else one clear for its shortest. As it arrives (while still behind the follow gap) or chasing at its follow
## gap, between volleys, show_spacing_seconds after its last showing.
func show_lane_now() -> Array:
	if shows >= tuning.show_count or not alive:
		return [-1, "shown enough"]
	if state == State.ARRIVING:
		if not tuning.show_on_arrival or shows > 0 or gap <= tuning.follow_gap + 0.5:
			return [-1, "arriving"]
	elif state != State.CHASING or volley != Volley.IDLE or close or absf(gap - tuning.follow_gap) > 1.0:
		return [-1, "busy"]
	elif _clock - _last_show_end < tuning.show_spacing_seconds:
		return [-1, "spacing"]
	var p: Player = world.player
	if not p.alive or not p.running or p.surface != Player.Surface.FLOOR or not p.grounded or p.in_pit:
		return [-1, "runner off the floor"]
	var r: int = p.lane
	if absf(p.position.x - world.geo.lane_x(r)) > 0.05:
		return [-1, "runner changing lanes"]
	if _attack_on(true):
		return [-1, "an attack on"]
	var chase_left: float = tuning.chase_seconds - _clock
	var to_bait: float = _seconds_to_bait()
	var hold: float = EnforcerTruckRoom.hold_for(tuning, gap, to_bait, chase_left)
	if hold < tuning.show_min_seconds:
		return [-1, "a bait coming" if to_bait - tuning.show_margin_seconds - tuning.close_lead_seconds < chase_left else "chase ending"]
	var total: float = tuning.show_total_seconds(gap, hold)
	if _quiet_near(total):
		return [-1, "a hover truck or Gilded Sentinel"]
	var sides: Array[int] = _room.sides(r, int(spawn.get("seed", 0)) + shows)
	if sides.is_empty():
		return [-1, "no lane beside the runner"]
	for whole: bool in [true, false]:
		var why: PackedStringArray = []
		for l: int in sides:
			if not bool(_fits.get(r * 64 + l, false)):
				why.append("off screen")
			elif not _show_lane_clear(l, total, hold if whole else -1.0):
				why.append("its lane not clear")
			elif not runner_can_dodge(r, l, total):
				why.append("no lane to dodge into")
			elif not _shadow_clear(l, total, true):
				why.append("an enemy beside it")
			else:
				return [l, "", hold]
		if not whole:
			return [-1, ", ".join(why)]
	return [-1, ""]


## A showing begins in lane `l`, to stay alongside `hold` seconds: its lane change first (at once while it's still
## far behind, arriving), its solid sides on, its siren swelling.
func _begin_show(l: int, hold: float) -> void:
	show_phase = Show.PULL_UP
	show_lane = l
	shows += 1
	_show_t = 0.0
	_show_hold = hold
	_yielding = false
	if target_lane != l:
		target_lane = l
		if gap > tuning.follow_gap + 2.0:
			_x = world.geo.lane_x(l)
			_switch_t = 1.0
			lane = l
		else:
			_switch_from = _x
			_switch_to = world.geo.lane_x(l)
			_switch_t = 0.0
	_set_blocker(true)
	_play_siren()
	_note(&"show")


## It drops back behind the runner: its time is up (or its lane ahead isn't clear), or it gives way
## (`yielding`: faster). A showing given way before it came into view (still behind the camera) doesn't count.
func _drop_back(yielding: bool) -> void:
	if yielding and show_phase == Show.PULL_UP and gap > EnforcerTruckRoom.OUT_OF_VIEW:
		shows -= 1
	show_phase = Show.DROP_BACK
	_yielding = yielding
	_note(&"give_way" if yielding else &"drop_back")


## Back behind the runner: the showing is over. Its sides are no longer solid, and it takes up the runner's lane
## again (_follow_player_lane).
func _end_show() -> void:
	show_phase = Show.NONE
	show_lane = -1
	_yielding = false
	_last_show_end = _clock
	_set_blocker(false)
	_note(&"shown")


## True when it must give way and drop back at once: the runner moves toward its lane (a lane change into its
## side bumped back, or they're in or heading into it), leaves the floor or falls in a hole, has no other lane
## to dodge into, another type's big attack comes on all the same (one that can't wait, or with big attacks not
## taking turns), a hover truck, a Gilded Sentinel or a bait comes sooner than planned, or an enemy comes
## beside or beyond it or into its lane.
func _must_give_way() -> bool:
	var p: Player = world.player
	if p.surface != Player.Surface.FLOOR or p.in_pit or _bumped or p.lane == show_lane \
			or absf(p.position.x - world.geo.lane_x(show_lane)) < world.geo.lane_width * 0.75:
		return true
	var left: float = _show_seconds_left()
	# A bait sooner than the showing was planned for (half its margin to spare: an Octodog not planned in the
	# layout, a wait that moved one on).
	if _attack_on(false) or _quiet_near(left) \
			or _bait_near(left + tuning.show_margin_seconds * 0.5 + tuning.close_lead_seconds):
		return true
	if absi(p.lane - show_lane) <= 2 and not runner_can_dodge(p.lane, show_lane, left):
		return true
	var d: float = world.player_distance()
	return not _shadow_clear(show_lane, 0.0, false) \
		or _floor_enemy_in(show_lane, d - gap - tuning.body_size.z - 1.0, _drop_reach())


## Seconds of its showing left: closing in, alongside, and dropping back.
func _show_seconds_left() -> float:
	var drop: float = tuning.ease_seconds(tuning.follow_gap - gap, tuning.show_drop_speed)
	match show_phase:
		Show.PULL_UP:
			return tuning.show_total_seconds(gap, _show_hold)
		Show.ALONGSIDE:
			return maxf(_show_hold - _show_t, 0.0) + drop
		Show.DROP_BACK:
			return drop
	return 0.0


## The closest it may come behind the runner: MIN_GAP, unless it's showing itself in a lane beside theirs (its
## lane change done, the runner neither in its lane nor overlapping it), when it may come alongside.
func _least_gap() -> float:
	if show_phase == Show.NONE or _switch_t < 1.0 or world.player == null:
		return MIN_GAP
	var p: Player = world.player
	if p.lane == lane or absf(p.position.x - _x) < (tuning.body_size.x + world.tuning.visual_size.x) * 0.5:
		return MIN_GAP
	return -INF


## True if lane `l` suits a showing starting now that takes `total` seconds: the layout's side
## (EnforcerTruckRoom.lane_clear) and no floor enemy in play where it's in view, for its shortest stay or, with
## `alongside`, for that many seconds alongside.
func _show_lane_clear(l: int, total: float, alongside: float = -1.0) -> bool:
	var v: float = _plan_speed()
	var d: float = world.player_distance()
	if not _room.lane_clear(l, tuning, d, gap, total, v, alongside):
		return false
	var span: Vector2 = EnforcerTruckRoom.view_stretch(tuning, d, gap, v, alongside)
	return not _floor_enemy_in(l, span.x, span.y)


## True while lane `l` stays clear ahead of it alongside the runner: nothing it would drive through or the runner
## may need from its rear to where its front gets before it has dropped back out of view (_drop_reach). It drops
## back once that's no longer so (after show_min_seconds).
func _lane_ahead_clear(l: int) -> bool:
	var from: float = world.player_distance() - gap - tuning.body_size.z - 1.0
	var to: float = _drop_reach()
	return not EnforcerTruckRoom.hit(_room.solid[l], from, to) and not EnforcerTruckRoom.hit(_room.soft[l], from, to) \
		and not _floor_enemy_in(l, from, to)


## How far along the track its front gets (a little room added) if it starts dropping back now, before it's out
## of the camera's view (EnforcerTruckRoom.OUT_OF_VIEW behind the runner).
func _drop_reach() -> float:
	var d: float = world.player_distance()
	var out_of_view: float = EnforcerTruckRoom.OUT_OF_VIEW
	return maxf(d - gap, d + tuning.show_drop_view_seconds(out_of_view) * _plan_speed() - out_of_view) + 2.0


## True if a runner in lane `r` keeps a lane to dodge into for `seconds` while the truck holds lane `l` (GDD §9.13:
## it never takes the only free lane): the layout's side (EnforcerTruckRoom.can_dodge: the lane on their other side
## while it's beside them, the lane between them two lanes in from a runner by a wall), and the floor enemies in
## play, which they must leave their lane for (that lane open around one in theirs) and which block that lane like
## the layout's. Two lanes in, the lane between them is held to the same, with their own lane to dodge back into.
func runner_can_dodge(r: int, l: int, seconds: float) -> bool:
	var v: float = _plan_speed()
	var d: float = world.player_distance()
	if not _room.can_dodge(r, l, tuning, d, seconds, v):
		return false
	var o: int = _room.escape_lane(r, l)
	if o < 0:
		return o == -2
	var to: float = d + (seconds + tuning.show_margin_seconds) * v
	if not _enemies_let_dodge(r, o, l, d, to, v):
		return false
	return absi(l - r) != 2 or _enemies_let_dodge(o, r, l, d, to, v)


## True if the floor enemies in play leave a runner in lane `mine` the lane `escape` to dodge into between `d` and
## `to` while the truck holds lane `truck` (runner_can_dodge): none in `escape` around what blocks `mine` (unless the
## truck's lane is blocked there too, for something to jump or slide), and none in `mine` with `escape` blocked
## around it.
func _enemies_let_dodge(mine: int, escape: int, truck: int, d: float, to: float, v: float) -> bool:
	var step: float = EnforcerTruckRoom.DODGE_ROOM_SECONDS * v
	var spans: PackedVector2Array = _room.hard[mine]
	var i: int = EnforcerTruckRoom.first(spans, d)
	while i < spans.size() and spans[i].x <= to:
		var span: Vector2 = spans[i]
		if _floor_enemy_in(escape, span.x - step, span.y + step) \
				and (EnforcerTruckRoom.hit(_room.must_leave[mine], span.x, span.y)
				or not EnforcerTruckRoom.hit(_room.hard[truck], span.x, span.y)):
			return false
		i += 1
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e == self or not LevelGenerator.enemy_uses_floor({"type": String(e.type_id)}):
			continue
		var at: float = e.track_distance()
		if at < d or at > to or world.geo.lane_at(e.global_position.x) != mine:
			continue
		var reach: float = EnforcerTruckRoom.ENEMY_ROOM + step
		if EnforcerTruckRoom.hit(_room.hard[escape], at - reach, at + reach) or _floor_enemy_in(escape, at - step, at + step):
			return false
	return true


## True if no enemy is in lane `l` or beyond it (toward that side's wall) near the runner, from just behind
## them to show_shadow_reach ahead, where from the camera the truck would hide it; with `planned`, none of the
## layout's coming there either over the next `seconds` of running (EnforcerTruckRoom.shadow_clear).
func _shadow_clear(l: int, seconds: float, planned: bool) -> bool:
	var r: int = world.player.lane
	var side: float = signf(float(l - r))
	if side == 0.0:
		return false
	var edge: float = world.geo.lane_x(l) - side * world.geo.lane_width * 0.5
	var d: float = world.player_distance()
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e == self:
			continue
		var at: float = e.track_distance()
		if at >= d - 3.0 and at <= d + tuning.show_shadow_reach and (e.global_position.x - edge) * side > 0.0:
			return false
	return not planned or _room.shadow_clear(l, r, tuning, d, seconds, _plan_speed())


## True if a floor enemy in play stands in lane `l` between track distances `from` and `to` (EnforcerTruckRoom.ENEMY_ROOM
## around it).
func _floor_enemy_in(l: int, from: float, to: float) -> bool:
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e == self:
			continue
		var at: float = e.track_distance()
		if at < from - EnforcerTruckRoom.ENEMY_ROOM or at > to + EnforcerTruckRoom.ENEMY_ROOM:
			continue
		if LevelGenerator.enemy_uses_floor({"type": String(e.type_id)}) and world.geo.lane_at(e.global_position.x) == l:
			return true
	return false


## True while another enemy's big attack is on (GDD §9) or its shots are still on their way to the runner, or,
## with `waiting`, one is waiting for its turn (but while it claims its turn for its planned showing, when they wait
## for it: claiming): a showing never meets another attack's warning.
func _attack_on(waiting: bool) -> bool:
	var ahead: bool = waiting and not claiming()
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or e == self or not e.alive:
			continue
		if e.is_major_attack_active() or world.director.shots_on_their_way(e.type_id) \
				or (ahead and world.director.is_waiting(e)):
			return true
	return false


## True while an enemy that keeps it from showing itself (EnforcerTruckRoom.NO_SHOW_TYPES) is in play, or one of
## the layout's comes into play within `seconds` of running.
func _quiet_near(seconds: float) -> bool:
	for e: Enemy in world.director.active:
		if is_instance_valid(e) and e.alive and e.type_id in EnforcerTruckRoom.NO_SHOW_TYPES:
			return true
	return _room.quiet_near(world.player_distance(), seconds, _plan_speed())


## True if one of its baits takes its turn within `seconds` of running (_seconds_to_bait).
func _bait_near(seconds: float) -> bool:
	return _seconds_to_bait() <= seconds


## Seconds of running until one of its baits takes its turn (INF: none known): an Octodog winding up or charging
## (0) or with charges left, its stop (where it winds up) that far ahead; a Buzz Overdrive claiming its turn,
## revving or charging (0), or parked or rolling in that far from its claim; or the next of the layout's baits
## (EnforcerTruckRoom.seconds_to_bait).
func _seconds_to_bait() -> float:
	var pd: float = world.player_distance()
	var v: float = _plan_speed()
	var best: float = _room.seconds_to_bait(pd, v)
	var scaling: float = world.config.enemy_scaling if world.config != null else 0.0
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive:
			continue
		if e is Octodog:
			var dog := e as Octodog
			if dog.in_doghouse:
				continue
			match dog.phase:
				Octodog.Phase.WINDUP, Octodog.Phase.LUNGE, Octodog.Phase.TURN, Octodog.Phase.SPRINT, Octodog.Phase.PACE:
					return 0.0
				Octodog.Phase.IDLE:
					if dog.charges_done < dog.charges:
						var stop: float = _dog_tuning.stop_distance(maxf(world.player.speed, 1.0), scaling, world.tuning.pace())
						best = minf(best, maxf(dog.track_distance() - pd - stop, 0.0) / v)
		elif e.type_id == &"buzz_overdrive":
			var s: int = int(e.get(&"state"))
			if s == BuzzScript.State.REV or s == BuzzScript.State.CHARGE or e.is_major_attack_active():
				return 0.0
			var cut: Dictionary = e.get(&"cut")
			if (s == BuzzScript.State.PARKED or s == BuzzScript.State.ROLL) and not cut.is_empty():
				best = minf(best, maxf(float(e.call(&"claim_at")) - pd, 0.0) / v)
	return best


## The runner's speed to plan a showing's stretch of track with (never under the level's run speed).
func _plan_speed() -> float:
	return maxf(world.player.speed, world.tuning.run_speed)


## Its solid sides, on while it shows itself (GDD §9.3: a lane change into it is bumped back).
func _set_blocker(on: bool) -> void:
	if _blocker != null:
		_blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER if on else 0


## True while its solid sides are on.
func blocking() -> bool:
	return _blocker != null and _blocker.collision_layer != 0


## The runner's movement events: a lane change bumped back toward its lane while it shows itself (it gives way).
func _on_player_event(kind: StringName) -> void:
	if kind != &"lane_blocked" or show_phase == Show.NONE or not alive:
		return
	var p: Player = world.player
	if int(p.get(&"_bump_dir")) == signi(show_lane - p.lane):
		_bumped = true


## Its siren on its own voice, swelling from siren_swell_db under its full volume as it pulls alongside. Silent
## headless; noted either way.
func _play_siren() -> void:
	sounds_played.append(&"enforcer_siren")
	_swell_t = -1.0
	var library: SfxLibrary = world.sfx_library
	if library == null or not SfxLibrary.audible():
		return
	var stream: AudioStream = library.stream(&"enforcer_siren")
	if stream == null:
		return
	_siren.stream = stream
	_siren_db = library.volume(&"enforcer_siren")
	_siren.volume_db = _siren_db - tuning.siren_swell_db
	_swell_t = 0.0
	_siren.play()


func _update_siren(delta: float) -> void:
	if _swell_t < 0.0 or not _siren.playing or _siren.stream == null:
		return
	_swell_t += delta
	var swell: float = maxf(_siren.stream.get_length() * 0.75, 0.2)
	_siren.volume_db = _siren_db - tuning.siren_swell_db * (1.0 - clampf(_swell_t / swell, 0.0, 1.0))


# --- Volleys -----------------------------------------------------------------------------------------

## Its volleys are a big attack (GDD §9; §9.13, proposed): from its warning until its last bolt has passed
## the runner. Its showings take a turn the same way (they take a lane from the runner, and GDD §9.13 keeps
## every attack's warning away from them): from when one begins until it has dropped back out of view, and for its
## planned showing from when it claims its turn (claiming, task C6c).
func is_major_attack_active() -> bool:
	if not alive:
		return false
	return volley != Volley.IDLE or (show_phase != Show.NONE and not (show_phase == Show.DROP_BACK and gap >= EnforcerTruckRoom.OUT_OF_VIEW)) \
		or claiming()


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


## Ready for a volley: chasing at its follow gap (never while it shows itself), its interval over, the runner on
## the floor, no bait about to attack before the volley would be over (so it never fires into one's attack, big
## attacks taking turns or not), and a lane beside the runner's clear to escape into (asked last).
func _ready_to_fire() -> bool:
	if state != State.CHASING or close or show_phase != Show.NONE or absf(gap - tuning.follow_gap) > 1.0 \
			or next_volley_in() > 0.0:
		return false
	var p: Player = world.player
	if not p.alive or not p.running or p.surface != Player.Surface.FLOOR:
		return false
	if _waits_for_first_show() or _holds_for_showing():
		return false
	if _bait_on(tuning.hold_seconds()):
		# Its baits come first: it leaves the director's queue at once (harmless when it isn't waiting), so
		# its place there never holds an Octodog back.
		world.director.give_up_turn(self)
		return false
	return escape_clear(clampi(p.lane, 0, world.geo.lane_count - 1))


## True while its first volley waits for its first showing (show_wait_seconds past its time at most): it hasn't
## shown itself yet, and a showing can still come before its bait and its chase's end.
func _waits_for_first_show() -> bool:
	if shows > 0 or _last_volley_end != -INF or not tuning.show_on_arrival or tuning.show_count <= 0 \
			or _clock >= tuning.first_volley_seconds + tuning.show_wait_seconds:
		return false
	var hold: float = EnforcerTruckRoom.hold_for(tuning, gap, _seconds_to_bait(), tuning.chase_seconds - _clock)
	return hold >= tuning.show_min_seconds


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
## marker; with Reduced flashing both stay lit, steady and softer. The marker fades while the truck shows
## itself on screen (it says where an unseen truck is).
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
	elif show_phase != Show.NONE and gap < tuning.follow_gap - 2.0:
		marker.shown = maxf(marker.shown - delta * 4.0, 0.0)
	else:
		marker.shown = minf(marker.shown + delta * 3.0, 1.0)


# --- Destroyed -----------------------------------------------------------------------------------------

## Wrecked in a hole in its lane (a gap too wide to hop, a Buzz Overdrive's cut): the player's kill.
func _wreck(cause: StringName) -> void:
	defeat(cause)


## Destroyed (a charge, a hole): the player's kill, with the bonus for its riders. The impact makes sparks and
## its crash (brakes, crunching steel); then its wreck lurches on into view and blows up there
## (_physics_process, _explode): the owner (October 8, 2026) wants every kill to end in a visible explosion.
func _on_defeated(cause: StringName) -> void:
	state = State.WRECKED
	_wreck_cause = cause
	_wreck_t = 0.0
	_wreck_gap0 = gap
	_wreck_far = _hole_far if _holed() else INF
	_wreck_in_lane = absf(_x - world.player.position.x) < (tuning.body_size.x + world.tuning.visual_size.x) * 0.5 + 0.6
	# In the runner's lane it blows up wreck_gap behind them (closer, its fireball would hide them); beside them a
	# wreck already closer stays where it is.
	_wreck_gap = tuning.wreck_gap if _wreck_in_lane else minf(gap, tuning.wreck_gap)
	_fall_v = 0.0
	_sink = model.position.y
	_spin = 0.0
	_trail_left = 0.0
	_blast_at = -1.0
	volley = Volley.IDLE
	volley_lane = -1
	_line.visible = false
	_voice.stop()
	_siren.stop()
	_swell_t = -1.0
	_canvas.visible = false
	_floor.visible = false
	show_phase = Show.NONE
	_set_blocker(false)
	world.director.give_up_turn(self)
	_note(StringName("wreck:" + String(cause)))
	# GDD §9.13: destroying it pays a bonus for each rider aboard (its own score comes from the ScoreKeeper:
	# a bait, the player's kill).
	if riders > 0:
		world.score.add_bonus(&"enforcer_riders", riders * tuning.rider_bonus, "Riders x%d" % riders)
	_sound(&"enforcer_crash")
	world.effects.burst(aim_point(), Color(1.0, 0.72, 0.3), 26, 0.9)
	world.effects.shake(0.2, 0.25)


## True if it was wrecked in a hole (a gap too wide to hop, a floor cut).
func _holed() -> bool:
	return _wreck_cause == &"gap" or _wreck_cause == &"cut"


## Its wreck, kept in the runner's frame like the truck itself: it lurches on into view (its front from where
## it was to wreck_gap behind the runner over wreck_surge_seconds, already closer staying put), spinning out
## (a charge) or nose-diving into its hole on its rear (nothing of it rises: it passes under the chase camera),
## trailing sparks, then blows up where the camera sees it (_explode):
## at the end of its lurch, or as its nose meets the far edge of the gap it fell in. The blast (its fireball,
## carried along with it) burns on, falling back slowly (blast_drift), and it's gone when the blast is over
## (blast_seconds).
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state != State.WRECKED or world == null:
		return
	_wreck_t += delta
	var pd: float = world.player_distance()
	if _blast_at < 0.0:
		var k: float = clampf(_wreck_t / maxf(tuning.wreck_surge_seconds, 0.01), 0.0, 1.0)
		gap = lerpf(_wreck_gap0, _wreck_gap, smoothstep(0.0, 1.0, k))
		var front: float = pd - gap
		var edge: bool = _holed() and front >= _wreck_far - 0.05
		if edge:
			front = _wreck_far
			gap = pd - front
		position = Vector3(_x, 0.0, TrackGeometry.world_z(front))
		if _holed():
			# Nose first into the hole, pivoting on its rear, so no part of it rises: on its front it would swing its
			# rear and riders up into the chase camera as it lurches on under it.
			_fall_v -= 18.0 * delta
			_sink += _fall_v * delta
			model.rotation.x = lerpf(model.rotation.x, -0.6, 1.0 - exp(-7.0 * delta))
			var pitch: float = model.rotation.x
			model.position = Vector3(0.0, _sink + tuning.body_size.z * sin(pitch), tuning.body_size.z * (1.0 - cos(pitch)))
		else:
			_spin = lerpf(_spin, 0.9, 1.0 - exp(-6.0 * delta))
			model.rotation.y = _spin * signf(_x - world.player.position.x + 0.01)
			model.rotation.z = 0.12 * sin(_wreck_t * 9.0)
		_trail_left -= delta
		if _trail_left <= 0.0:
			_trail_left = 0.15
			world.effects.burst(to_global(_blast_local()), Color(1.0, 0.45, 0.12), 10, 0.45)
		if k >= 1.0 or edge:
			_explode()
		return
	gap += tuning.blast_drift * delta
	position = Vector3(_x, 0.0, TrackGeometry.world_z(pd - gap))
	_blast_t += delta
	_trail_left -= delta
	if _trail_left <= 0.0 and _blast_t < tuning.blast_seconds * 0.5:
		_trail_left = 0.2
		world.effects.burst(to_global(_blast_local()) + Vector3(0.0, 0.8, 0.0), Color(1.0, 0.5, 0.15), 8, 0.4)
	if _blast_t >= tuning.blast_seconds:
		queue_free()


## It blows up where the camera sees it: its model, riders and all, gone in a shared yellow-and-red fireball
## (RunEffects.fireball, GDD §11: blast_size, smaller in the runner's lane, carried along with the wreck so it falls
## back with it at blast_drift, its fire burning blast_seconds), the shared effects' smoke and debris, a chunk flung
## up for each rider, a shake and truck_explode.
func _explode() -> void:
	_blast_at = _wreck_t
	_blast_t = 0.0
	_note(&"blast")
	var local: Vector3 = _blast_local()
	model.visible = false
	var at: Vector3 = to_global(local)
	_sound(&"truck_explode")
	world.effects.fireball(at, blast_size(_wreck_in_lane), false, fire_pace(),
		FIRE_SPREAD_IN_LANE if _wreck_in_lane else FIRE_SPREAD, self)
	world.effects.burst(at + Vector3(0.0, 1.0, 0.0), Color(0.35, 0.33, 0.32), 22, 0.9)
	world.effects.debris(at, Color(0.3, 0.3, 0.34), 12, 0.9)
	for i: int in mini(riders, EnforcerTruckModel.RIDER_SLOTS.size()):
		var slot: Vector2 = EnforcerTruckModel.RIDER_SLOTS[i]
		world.effects.debris(to_global(Vector3(slot.x, tuning.body_size.y + 0.4, slot.y)), Color(0.55, 0.6, 0.66), 5, 1.0)
	world.effects.shake(0.45, 0.45)
	_trail_left = 0.1


## Where it blows up, in its own space (blast_spot), away from the runner's side.
func _blast_local() -> Vector3:
	return blast_spot(_wreck_in_lane, signf(_x - world.player.position.x))


## Where a truck blows up, in its own space: in the runner's lane (`in_lane`) or beside it, `away` the side away
## from the runner (-1 or 1).
static func blast_spot(in_lane: bool, away: float) -> Vector3:
	if in_lane:
		return Vector3(0.0, BLAST_HEIGHT, BLAST_BACK_IN_LANE)
	return Vector3(away * BLAST_SHIFT, BLAST_HEIGHT + 0.15, BLAST_BACK)


## Its blast's fireball (RunEffects.fireball, metres in radius): the blast's radius, smaller in the runner's lane
## (`in_lane`).
func blast_size(in_lane: bool) -> float:
	return tuning.blast_radius_in_lane if in_lane else tuning.blast_radius


## How much faster than a free fireball of its size its blast's plays (RunEffects.fireball's `pace`): its fire burns
## blast_seconds, as long as its wreck stays after it blows up.
func fire_pace() -> float:
	var fx: SpeedFxTuning = world.effects.tuning if world != null and world.effects != null else null
	var fire: float = fx.fireball_seconds if fx != null else 1.0
	return fire / maxf(tuning.blast_seconds, 0.05)


## Weapons never target it (immune_to_weapons). Where effects appear: just behind its front, chest high.
func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 1.2, 1.2)


func hit_radius() -> float:
	return 1.4
