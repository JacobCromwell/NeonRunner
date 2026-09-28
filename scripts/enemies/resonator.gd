class_name Resonator
extends Enemy
## The Resonator (GDD §9.10), the Golden Zone's new enemy: the cult's broadcast technology (the owner's
## "Hymn Censer" reworked in a sci-fi form, never anything from a church), a floating golden spire
## ringed by three halos around a red glowing core (ResonatorModel; DESIGN-TBD, docs/questions/c3.md:
## the look and the numbers in data/enemies/resonator.tres).
## 1. It hovers far ahead, still, where the generator put it; as the player nears it eases into pacing
##    them hover_ahead in front (it keeps pace from then on, so the player never reaches it).
## 2. Before each pulse, the warning: its halos spin up and swing into line facing the player, one on
##    each note of the cult's three-note chime (resonator_chime, pleasant like a public-address jingle,
##    the same every time: CHIME_NOTES), while its core, the halos' inner rings and its emitter glow red.
## 3. At the warning's end it sends a red shockwave (resonator_pulse) rolling along the floor toward
##    the player across every lane: a low band (ResonatorTuning.wave_height) that a jump clears. Later
##    in the zone it rests less between pulses, its waves roll faster, and some pulses send a second
##    wave double_gap behind the first.
## 4. After its pulses it pulls away ahead, powering down, and is gone.
## Dodge: jump the wave, or be on a wall or the ceiling: the wave travels along the floor only, and its
## hitbox stops short of a wall runner's body (ResonatorTuning.band_half_width).
## Kill: weapons (auto-fire targets its core: 15 laser tier 1 shots), or wait it out. It hovers too high
## to stomp and has nothing to touch: no contact hitbox, like the heli drone. Its wave is an enemy
## attack: armor and the shield block one (a double's second wave comes within the invulnerability
## window that follows), and the dash passes through it (dash_kills is off: a wave isn't its body).
## Shot down, it breaks apart, and a wave still rolling fizzles out (it can't hurt once its source is
## gone).
##
## Fairness (GDD §9.10, proposed: never a wave on top of a gap or a fence): the generator plans each
## visit's pulses (resonator_rules.gd: params "pulses", "pulse_at", the player distances where each
## warning may start, and "double") where the floor the wave meets the player on is clear in every
## lane (pulse_clear). Just before each warning it checks that again, from where the player really is
## and how fast they run; a warning that has started always finishes with its wave.
## Big attacks take turns (GDD §9): a pulse, from its warning until its last wave has passed the
## player, is a big attack (is_major_attack_active). It asks the director just before each warning
## (EnemyDirector.major_attack_blocked); while it's held, or the floor isn't clear, it hovers and moves
## its pulses on with the player. After turn_wait_max of waiting in all it drops the pulses left, but
## never its first: every visit pulses, unless the level ends first. One Resonator pulses at a time.
## Spawned without a plan (tests, quick experiments), it pulses as soon as it can, with the same checks.
## Spawn params: {"pulses": n, "pulse_at": [player distances], "double": bool or [bool per pulse]}.

enum State { APPROACH, PACE, WARNING, PULSE, LEAVE, DOWN }

const STATE_NAMES: PackedStringArray = ["approach", "pace", "warning", "pulse", "leave", "down"]
## The chime's three notes, in seconds from the warning's start (resonator_chime is made with them,
## tools/asset_gen/sfx_bank_resonator.gd): each swings one halo into line, inner to outer.
const CHIME_NOTES: Array[float] = [0.0, 0.42, 0.84]
## A halo swings into line from this long before its note to this long after it.
const LINE_UP_BEFORE: float = 0.1
const LINE_UP_AFTER: float = 0.2
## pulse_clear(): metres kept between a wave's meeting stretch and an anti-grav pad (the player may be
## stepping onto it), and before a ceiling's end (where its rider drops back to the floor).
const PAD_MARGIN: float = 6.0
const LANDING_LEAD: float = 2.0
const WAVE_NAME: String = "Resonator's wave"
## Seconds a wave takes to spread across the lanes as it leaves (visual only: its hitbox spans them
## from the start, far ahead of the player), and to fade once it's gone past.
const WAVE_SPREAD: float = 0.35
const WAVE_FADE: float = 0.3
## The visible wave over its hitbox (GDD §3: hitboxes smaller than visuals): the crest's height and
## depth, how far its ends taper past the hitbox's, and the wake behind it.
const CREST_HEIGHT_SCALE: float = 1.35
const CREST_DEPTH_SCALE: float = 1.4
const CREST_END_TAPER: float = 0.2
const WAKE_LENGTH: float = 3.5
## A crest's tapered end keeps this far from a wall runner's body.
const CREST_WALL_CLEARANCE: float = 0.05
## Seconds it takes to break apart once shot down, and to power down as it leaves.
const DOWN_SECONDS: float = 1.4
const LEAVE_EASE: float = 1.0
## Waves in flight at once (a double pulse's two).
const WAVE_POOL: int = 2
## Where an idle wave waits, out of everything's way.
const PARKED_Y: float = -60.0
const RED := Color(1.0, 0.15, 0.1)


## One wave: a hitbox band across the lanes and its look, rolling along the floor toward the player.
## Top-level, so it doesn't move with the Resonator.
class Wave:
	extends Node3D
	var hitbox: Hazard
	var mesh: MeshInstance3D
	var material: ShaderMaterial
	## Launched and not yet gone (it rolls on past the player, then fades).
	var rolling: bool = false
	## Its back edge is behind the player's hitbox (EnemyDirector.SHOT_PASS_MARGIN): it can't reach
	## them any more, and its hitbox is off.
	var passed: bool = false
	## Where its middle is along the track (m), and its speed toward the player (m/s).
	var d: float = 0.0
	var speed: float = 0.0
	var age: float = 0.0
	## Seconds left of its fade (-1 until it fades).
	var fading: float = -1.0

	## Still on its way to the player.
	func on_its_way() -> bool:
		return rolling and not passed


var state: State = State.APPROACH
var tune: ResonatorTuning
## Pulses planned for this visit, and warnings started so far.
var pulses: int = 3
var pulses_done: int = 0
var waves_sent: int = 0
## What happened: [event, level time, player distance]. Events: arrive (it starts pacing), warning,
## wave (one leaves), pass (one has passed the player), dropped (the pulses left after too long a
## wait), leave, down.
var history: Array = []
## Every sound it played: [name, level time].
var sounds: Array = []
## The warning's progress (0 to 1) while it warns, else 0.
var charge: float = 0.0
## The current (or last) pulse sends two waves.
var double_now: bool = false

var _scaling: float = 0.0
## Track distance of the Resonator (its core), and where the generator put it.
var _d: float = 0.0
var _at: float = 0.0
var _rel: float = 0.0
var _state_time: float = 0.0
var _anchors: Array[float] = []
var _doubles: Array[bool] = []
var _planned: bool = false
## Metres its pulses have moved on while it waited, and seconds it has waited in all.
var _shift: float = 0.0
var _waited: float = 0.0
var _last_p: float = 0.0
## The next warning may start once the player is here (the last pulse, then its rest).
var _next_free: float = -INF
var _leave_asked: bool = false
var _zones: CeilingZones
var _band_half: float = 0.0
var _sway_t: float = 0.0
var _bob_t: float = 0.0
var _flash: float = 0.0
var _roll: float = 0.0
var _since_wave: float = 99.0
var _down_t: float = 0.0
var _model: ResonatorModel
var _waves: Array[Wave] = []


func _build() -> void:
	tune = tuning_res as ResonatorTuning if tuning_res is ResonatorTuning else ResonatorTuning.new()
	display_name = "Resonator"
	# GDD §9.10: it hovers too high to stomp, and nothing of it can be touched (no contact hitbox).
	stompable = false
	claw_immune = true
	# The dash passes through its wave, as through other enemies' attacks.
	dash_kills = false
	if not (tuning_res is EnemyTuning):
		max_health = tune.health_early
		score_value = tune.score_value
	_scaling = world.config.enemy_scaling if world.config != null else 0.0
	_at = float(spawn.get("at", 0.0))
	_d = _at
	var p: Dictionary = spawn.get("params", {})
	for a: Variant in p.get("pulse_at", []):
		_anchors.append(float(a))
	_planned = not _anchors.is_empty()
	pulses = _anchors.size() if _planned else maxi(1, int(p.get("pulses", tune.pulses_at(_scaling))))
	var doubles: Variant = p.get("double", false)
	for i: int in pulses:
		if doubles is Array:
			_doubles.append(i < (doubles as Array).size() and bool((doubles as Array)[i]))
		else:
			_doubles.append(bool(doubles))
	_zones = CeilingZones.make(world.config, world.tuning)
	_band_half = tune.band_half_width(world.geo.lane_count, world.tuning)
	_sway_t = rng.randf() * TAU
	_bob_t = rng.randf() * TAU
	_last_p = world.player.distance if world.player != null else 0.0
	_model = ResonatorModel.new()
	_model.name = "Model"
	add_child(_model)
	_model.build()
	for i: int in WAVE_POOL:
		_waves.append(_make_wave(i))
	_place()


func _make_wave(index: int) -> Wave:
	var w := Wave.new()
	w.name = "Wave%d" % index
	w.top_level = true
	add_child(w)
	var height: float = tune.wave_height
	w.hitbox = add_hitbox(&"attack", Vector3(_band_half * 2.0, height, tune.wave_depth),
		Vector3(0.0, height * 0.5, 0.0), true, w)
	w.hitbox.hazard_name = WAVE_NAME
	w.hitbox.set_enabled(false)
	var reach: float = ResonatorTuning.wall_body_reach(world.geo.lane_count, world.tuning) - CREST_WALL_CLEARANCE
	var taper: float = clampf(reach - _band_half, 0.0, CREST_END_TAPER)
	w.mesh = MeshInstance3D.new()
	w.mesh.mesh = ResonatorModel.wave_mesh(_band_half, height * CREST_HEIGHT_SCALE,
		tune.wave_depth * CREST_DEPTH_SCALE, taper, WAKE_LENGTH)
	w.material = ShaderMaterial.new()
	w.material.shader = ResonatorModel.wave_shader()
	w.mesh.material_override = w.material
	w.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(w.mesh)
	_park(w)
	return w


# --- Behaviour ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null:
		return
	if alive:
		_tick(delta)
	elif state == State.DOWN:
		_down_t += delta
		_fade_waves(delta)
		if _down_t >= DOWN_SECONDS:
			queue_free()


func _tick(delta: float) -> void:
	var p: float = world.player.distance
	_state_time += delta
	_sway_t += delta * 0.35
	_bob_t += delta
	match state:
		State.APPROACH:
			_approach(p)
		State.PACE:
			_pace(delta, p)
		State.WARNING:
			_warning(p)
		State.PULSE:
			_d = p + tune.hover_ahead
			if _state_time >= tune.double_gap:
				_emit_wave()
				_set_state(State.PACE)
		State.LEAVE:
			var k: float = clampf(_state_time / LEAVE_EASE, 0.0, 1.0)
			_rel += tune.leave_speed * k * k * delta
			_d = p + _rel
	_roll_waves(delta, p)
	_last_p = p
	_place()


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0


## Where the player is when it has eased into pacing them (it hovers still at its spot until
## approach_ease before that).
func visit_start() -> float:
	return _at - tune.hover_ahead + tune.approach_ease


## Hovering still at its spot until the player comes within hover_ahead + approach_ease, then easing
## into pacing them: its speed rises steadily from nothing to theirs over 2 × approach_ease of their
## run, so it settles hover_ahead ahead of them exactly as they reach visit_start().
func _approach(p: float) -> void:
	var e: float = tune.approach_ease
	var u: float = p - (_at - tune.hover_ahead - e)
	if u <= 0.0:
		_d = _at
	elif u < 2.0 * e:
		_d = p + tune.hover_ahead + e - u + u * u / (4.0 * e)
	else:
		_d = p + tune.hover_ahead
		_set_state(State.PACE)
		_log("arrive")
		# One at a time: a Resonator still here from before pulls away once its pulse is over.
		for other: Resonator in _others():
			if other.state in [State.APPROACH, State.PACE, State.WARNING, State.PULSE]:
				other.request_leave()


func _pace(delta: float, p: float) -> void:
	_d = p + tune.hover_ahead
	if pulses_done >= pulses or (_leave_asked and not is_major_attack_active()):
		if not waves_on_their_way():
			_start_leave()
		return
	if p < _due_at():
		return
	if _ready_to_pulse():
		_start_warning()
		return
	# Not ready (another type's big attack is on, or the floor where the wave would meet the player
	# isn't clear): it hovers, and its pulses move on with the player.
	_shift += maxf(p - _last_p, 0.0)
	_waited += delta
	if (pulses_done > 0 and _waited > tune.turn_wait_max) or not _fits_before_end(p):
		_log("dropped")
		pulses = pulses_done


## Where the next pulse is due: its planned point (or, without a plan, as soon as it has settled),
## moved on by every wait so far, and never before the last pulse's rest is over.
func _due_at() -> float:
	var base: float = -INF
	if _planned and pulses_done < _anchors.size():
		base = _anchors[pulses_done]
	elif pulses_done == 0:
		base = visit_start() + tune.settle_seconds * world.tuning.run_speed
	return maxf(base + _shift, _next_free)


## Everything a warning needs, the director asked last (GDD §9: it asks only once it's otherwise ready,
## and while it's held it doesn't start).
func _ready_to_pulse() -> bool:
	var pl: Player = world.player
	if not pl.alive or not pl.running or waves_on_their_way() or _other_pulsing():
		return false
	var v: float = maxf(pl.speed, 1.0)
	var stretch: Vector2 = tune.meeting_stretch(pl.distance, _double_for(pulses_done), v, _scaling)
	if stretch.y > _last_ok() or not pulse_clear(world.layout, _zones, pl.distance, stretch):
		return false
	return not world.director.major_attack_blocked(self)


## True while the next pulse could still meet the player before the level's end-clear stretch.
func _fits_before_end(p: float) -> bool:
	var stretch: Vector2 = tune.meeting_stretch(p, _double_for(pulses_done), world.tuning.run_speed, _scaling)
	return stretch.y <= _last_ok()


func _last_ok() -> float:
	return world.layout.length - (world.config.end_clear_distance if world.config != null else 0.0)


func _double_for(i: int) -> bool:
	return i < _doubles.size() and _doubles[i]


func _start_warning() -> void:
	var pl: Player = world.player
	var v: float = maxf(pl.speed, 1.0)
	double_now = _double_for(pulses_done)
	pulses_done += 1
	_next_free = pl.distance + (tune.pulse_seconds(double_now, v, _scaling, world.tuning.hurtbox_size.z,
		EnemyDirector.SHOT_PASS_MARGIN) + tune.pulse_rest_at(_scaling)) * v
	_set_state(State.WARNING)
	charge = 0.0
	_log("warning")
	_sound(&"resonator_chime")


func _warning(p: float) -> void:
	_d = p + tune.hover_ahead
	charge = clampf(_state_time / tune.warning_seconds, 0.0, 1.0)
	if _state_time >= tune.warning_seconds:
		charge = 0.0
		_emit_wave()
		_set_state(State.PULSE if double_now else State.PACE)


## A wave leaves from the floor under it and rolls toward the player.
func _emit_wave() -> void:
	var w: Wave = _free_wave()
	w.d = _d
	w.speed = tune.wave_speed_at(_scaling)
	w.age = 0.0
	w.fading = -1.0
	w.rolling = true
	w.passed = false
	w.position = Vector3(0.0, 0.0, TrackGeometry.world_z(w.d))
	w.visible = true
	w.hitbox.set_enabled(true)
	waves_sent += 1
	_flash = 1.0
	_since_wave = 0.0
	_log("wave")
	_sound(&"resonator_pulse")
	var under := Vector3(global_position.x, 0.25, global_position.z)
	world.effects.burst(under, RED, 22, 0.8)


func _free_wave() -> Wave:
	for w: Wave in _waves:
		if not w.rolling:
			return w
	# Both in flight: reuse the one furthest behind the player (already past them).
	var oldest: Wave = _waves[0]
	for w: Wave in _waves:
		if w.d < oldest.d:
			oldest = w
	return oldest


## Moves every wave toward the player; one that has passed them switches its hitbox off, rolls on for
## wave_roll_on, then fades.
func _roll_waves(delta: float, p: float) -> void:
	var behind: float = world.tuning.hurtbox_size.z * 0.5 + EnemyDirector.SHOT_PASS_MARGIN
	for w: Wave in _waves:
		if not w.rolling:
			continue
		w.d -= w.speed * delta
		w.age += delta
		w.position = Vector3(0.0, 0.0, TrackGeometry.world_z(w.d))
		if not w.passed and w.d + tune.wave_depth * 0.5 < p - behind:
			w.passed = true
			w.hitbox.set_enabled(false)
			_log("pass")
		if w.passed and w.fading < 0.0 and w.d < p - tune.wave_roll_on:
			w.fading = WAVE_FADE
		if w.fading >= 0.0:
			w.fading -= delta
			if w.fading <= 0.0:
				_park(w)


## Shot down: its waves fizzle out (their hitboxes are already off, Enemy.defeat).
func _fade_waves(delta: float) -> void:
	for w: Wave in _waves:
		if not w.rolling:
			continue
		if w.fading < 0.0:
			w.fading = WAVE_FADE
		w.fading -= delta
		if w.fading <= 0.0:
			_park(w)


func _park(w: Wave) -> void:
	w.rolling = false
	w.passed = false
	w.fading = -1.0
	w.visible = false
	w.position = Vector3(0.0, PARKED_Y, 0.0)
	if alive:
		w.hitbox.set_enabled(false)


func _start_leave() -> void:
	_rel = maxf(_d - world.player.distance, tune.hover_ahead)
	_set_state(State.LEAVE)
	_log("leave")


## Another Resonator has come to pace the player: this one pulls away as soon as its pulse is over.
func request_leave() -> void:
	_leave_asked = true


func _others() -> Array[Resonator]:
	var out: Array[Resonator] = []
	for e: Enemy in world.director.active:
		if e != self and is_instance_valid(e) and e.alive and e is Resonator:
			out.append(e as Resonator)
	return out


## One Resonator pulses at a time.
func _other_pulsing() -> bool:
	for other: Resonator in _others():
		if other.is_major_attack_active():
			return true
	return false


## True while any of its waves is still on its way to the player.
func waves_on_their_way() -> bool:
	for w: Wave in _waves:
		if w.on_its_way():
			return true
	return false


## GDD §9: a pulse is a big attack, from its warning until its last wave has passed the player
## (EnemyDirector.SHOT_PASS_MARGIN behind their hitbox): no other type's big attack starts meanwhile
## while big attacks take turns (it asks before each warning, _ready_to_pulse). DESIGN-TBD
## (docs/questions/c3.md, OPEN_QUESTIONS "From build phase 2" 98): the pulse counts as big.
func is_major_attack_active() -> bool:
	return alive and (state == State.WARNING or state == State.PULSE or waves_on_their_way())


func should_retire() -> bool:
	if state == State.LEAVE and _d - world.player_distance() > tune.leave_distance:
		return true
	return super.should_retire()


func aim_point() -> Vector3:
	return global_position


func hit_radius() -> float:
	return 0.85


func _on_defeated(_cause: StringName) -> void:
	_set_state(State.DOWN)
	charge = 0.0
	_log("down")
	world.play_sfx_at(&"resonator_death", global_position)
	sounds.append([&"resonator_death", world.level_time()])
	world.effects.burst(global_position, RED, 34, 1.1)
	world.effects.burst(global_position, ResonatorModel.GOLD, 24, 0.9)
	world.effects.shake(0.12, 0.2)


func _place() -> void:
	if state == State.DOWN:
		return
	position = Vector3(tune.sway * sin(_sway_t), tune.hover_height + 0.12 * sin(_bob_t * 1.9),
		TrackGeometry.world_z(_d))


func _log(event: String) -> void:
	history.append([event, world.level_time(), world.player.distance])


## Plays one of its sounds for everyone to hear (the chime is a public-address jingle, heard wherever
## the player is) and notes it.
func _sound(sound: StringName) -> void:
	world.play_sfx(sound)
	sounds.append([sound, world.level_time()])


## The warnings and waves in order, as [event, level time] (tests).
func events(names: PackedStringArray) -> Array:
	var out: Array = []
	for h: Array in history:
		if names.has(String(h[0])):
			out.append([h[0], h[1]])
	return out


## Half the width of its waves' hitbox (tests).
func band_half() -> float:
	return _band_half


## Its waves, in flight or idle (tests and the showcase).
func wave_list() -> Array[Wave]:
	return _waves.duplicate()


func model() -> ResonatorModel:
	return _model


# --- Presentation -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _model == null or world == null:
		return
	var reduced: bool = Settings.flashing_reduced
	_since_wave += delta
	var warning: bool = state == State.WARNING and alive
	var holding: bool = state == State.PULSE and alive
	# The halos swing into line one per note, hold while a double's second wave leaves, then relax.
	var throb: float = 1.0
	if warning and not reduced:
		# Throbbing faster as the wave nears (a steady ramp with Reduced flashing).
		throb = 0.72 + 0.28 * sin(TAU * _state_time * lerpf(2.0, 5.0, charge))
	for k: int in 3:
		var target: float = 0.0
		if warning:
			target = smoothstep(CHIME_NOTES[k] - LINE_UP_BEFORE, CHIME_NOTES[k] + LINE_UP_AFTER, _state_time)
		elif holding:
			target = 1.0
		var now: float = _model.align[k]
		_model.align[k] = target if target >= now else move_toward(now, target, delta * 1.4)
		_model.halo_glow[k] = _model.align[k] * (throb if warning else 1.0) * (1.0 if warning or holding else 0.6)
	_model.spin = move_toward(_model.spin, 1.0 if warning or holding else 0.0, delta * (2.0 if warning else 0.8))
	_model.core_glow = 1.0 + 1.6 * (charge if warning else (1.0 if holding else 0.0))
	_model.emitter_glow = charge if warning else (1.0 if holding else maxf(0.0, 1.0 - _since_wave * 2.0))
	_flash = maxf(_flash - delta * (1.6 if reduced else 3.5), 0.0)
	_model.flash = _flash * (0.4 if reduced else 1.0)
	if state == State.LEAVE:
		_model.dim = clampf(_state_time / LEAVE_EASE, 0.0, 1.0)
	elif state == State.DOWN:
		_model.dim = 1.0
		_model.broken = _down_t
	_model.animate(delta)
	if not reduced:
		_roll += delta * 1.8
	for w: Wave in _waves:
		if not w.rolling:
			continue
		var spread: float = clampf(w.age / WAVE_SPREAD, 0.0, 1.0)
		var fade: float = clampf(w.fading / WAVE_FADE, 0.0, 1.0) if w.fading >= 0.0 else 1.0
		w.mesh.scale = Vector3(lerpf(0.12, 1.0, spread * (2.0 - spread)), 1.0, 1.0)
		w.material.set_shader_parameter(&"strength", fade * lerpf(0.5, 1.0, spread))
		w.material.set_shader_parameter(&"roll", _roll)


# --- Layout checks (shared with resonator_rules.gd) ---------------------------------------------

## True if a pulse whose warning starts with the player at `warn_at` meets them on clear floor over
## `stretch` (ResonatorTuning.meeting_stretch; GDD §9.10, proposed: never a wave on top of a gap or a
## fence): no lane holds a gap, a live fence (an EMP may have switched it off) or a floor enemy's
## stretch (LevelGenerator.enemy_floor_span), no anti-grav pad lies within PAD_MARGIN of it and no
## ceiling's landing zone (CeilingZones, from LANDING_LEAD before the ceiling's end, where its rider
## drops back) reaches it; and no speed pad lies between the warning's start and the stretch's end (a
## boost there would move where the wave meets the player). The generator plans every pulse with it,
## and the Resonator asks it again just before each warning.
static func pulse_clear(layout: LevelLayout, zones: CeilingZones, warn_at: float, stretch: Vector2) -> bool:
	for g: Dictionary in layout.gaps:
		if float(g["start"]) <= stretch.y and float(g["end"]) >= stretch.x:
			return false
	for f: Dictionary in layout.fences:
		if not f.get("disabled", false) and zones.fence_in(f, stretch):
			return false
	for p: Dictionary in layout.pads:
		if float(p["at"]) >= stretch.x - PAD_MARGIN and float(p["at"]) <= stretch.y + PAD_MARGIN:
			return false
	for h: Dictionary in layout.hulls:
		var landing: Vector2 = zones.landing_zone(h)
		if landing.x - LANDING_LEAD <= stretch.y and landing.y >= stretch.x:
			return false
	for e: Dictionary in layout.enemies:
		if CeilingZones.enemy_in(e, stretch):
			return false
	for s: Dictionary in layout.speed_pads:
		if float(s["at"]) >= warn_at - 1.0 and float(s["at"]) <= stretch.y:
			return false
	return true
