class_name Player
extends Node3D
## Kinematic runner controller covering the floor, both side walls and the ceiling.
## Lanes are movement targets only. Support comes from physics rays against floor and hull
## bodies. Hazard and trigger contact comes from shape queries on the current frame, swept
## over the distance run this frame so nothing is skipped at speed. DamageRules resolves hits.
## Input arrives only as named actions (keyboard via the InputMap, touch via TouchInput).
## Every contact goes through receive_hit(), which asks DamageRules what happens; the player's
## protection (the armor, whose rules are DamageRules.Armor's; shield, grapple, claws, the
## invulnerability window, the dash, and the moment after a theft when no theft can happen) lives here.

signal died(cause: String)
## Something happened that feedback (sound, HUD) may react to: jump, land, slide, wall_enter,
## wall_jump, wall_exit, wall_blocked, ramp, pad, hull_end, died, stomp, lane_blocked,
## ceiling_blocked, speed_pad, grapple, armor_hit (a blocked hit the armor survives), armor_break,
## armor_back (broken armor came back), shield_break, revive, dash, dash_end, doodad_push (a zone
## doodad shoved the player into a neighbouring lane), doodad_smash (the dash broke a zone doodad apart:
## `<kind>_smash` for a DashBreakable of another kind), robbed (a thief's touch took credits, GDD §9.12),
## wall_missing (a wall entry refused where a wall gap leaves no wall: no bump, there's nothing to
## bump against), wall_gap_drop (a wall runner reached a wall gap and dropped off into the outer lane).
## The three blocked moves (lane_blocked, wall_blocked, and ceiling_blocked: a move past the edge of a
## ceiling over fewer lanes) come with a bump: out toward the blocked side and back. A wall runner knocked
## off their wall (repel_from_wall) hears wall_blocked too, and drops off instead.
signal movement_event(kind: StringName)
## A thief's touch robbed the player (DamageRules.Outcome.ROBBED, GDD §9.12): the ScoreKeeper takes the
## thief's share of the run's credits (Hazard.steals_share). The `robbed` movement event follows.
signal robbed(hazard: Hazard)
## A protective item was used up: &"armor" (it broke: its last hit went; it comes back), &"shield" or
## &"grapple".
signal item_used(item: StringName)
## A protective item was picked up during the run (gain_item): &"armor", &"shield" or &"grapple".
signal item_gained(item: StringName)
## The armor changed: a hit blocked, broken, back, or restored (a pickup or a revive). See armor_state.
signal armor_changed
## The player's contact defeated an enemy (cause: &"stomp", &"claws" or &"dash").
signal enemy_contact(enemy: Enemy, cause: StringName)
## The dash broke something apart (GDD §3, owner, October 8, 2026: a zone doodad; task H5): it has
## switched off its collision and hidden its look (DashBreakable.smash), and the `<kind>_smash` movement
## event follows. RunEffects flings its pieces.
signal smashed(breakable: DashBreakable)
signal revived

enum Surface { FLOOR, CEILING, WALL }

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump", &"slide"]
## The feet's trigger sensor (pads, ramps, speed pads), swept back over each frame's motion.
const SENSOR_SIZE := Vector3(0.4, 0.3, 0.4)
## Room a blocked wall entry's bump leaves between the body and whatever stopped it (metres).
const BUMP_CLEARANCE: float = 0.02
## A zone doodad's push (GDD §3) goes to the doodad's own side for a player within this share of a lane
## of its middle (running into it head-on); one further off (caught by its front corner mid-switch)
## goes back the way they came. DESIGN-TBD (docs/questions/g5.md 3): which way a caught corner pushes.
const PUSH_HEAD_ON_SHARE: float = 0.15
## The doodad contact starts this far above the feet, so a player standing on a doodad's top (it's
## solid) isn't pushed by it (metres).
const DOODAD_FEET_CLEARANCE: float = 0.05
## A doodad the dash has claimed (_smash_claims: the dash reaches its front before it ends, or a switch
## into its side began while dashing) still breaks on contact this long after the dash ends (seconds):
## the contact may come a frame or two after the dash's last one (frame steps; the claim already counts a
## ramp's or speed pad's boost fading, _dash_reach). A dash that ends short of a doodad it never claimed
## pushes as usual. DESIGN-TBD (docs/questions/h5.md 3).
const SMASH_CLAIM_GRACE: float = 0.1

var tuning: MovementTuning
var geo: TrackGeometry
## The level's side wall gaps (LevelLayout.wall_gaps, the world's own list, so gaps a longer track adds
## count too): where a wall has no wall-running surface (wall_supported).
var wall_gaps: Array[Dictionary] = []
## Game-wide rules (stomp bounce, invulnerability windows, ...). A default copy if none is set.
var rules: GameRules
var god_mode: bool = false
var running: bool = false

# Protection, set from the run's loadout (GDD §8). Breakable items are single charges.
## The armor (GDD §4, §8): up or coming back; its rules are DamageRules.Armor's.
var armor_state := DamageRules.Armor.new()
## Armor hits left right now (0 while it's broken and coming back, or in a run without armor). Setting
## it (tests, review tools) puts that many hits up at once, or takes the armor away with 0.
var armor: int:
	get:
		return armor_state.hits
	set(value):
		armor_state.set_hits(value)
var shield: int = 0
var grapples: int = 0
var claws: bool = false
## Wall-run time multiplier (claws give longer wall runs, GDD §8).
var wall_time_multiplier: float = 1.0
## Seconds of invulnerability left (after a block or a revive; the character flashes).
var invulnerable_left: float = 0.0
## Seconds left in which no theft can happen (after one, GameRules.theft_grace): one touch robs once.
var theft_immune_left: float = 0.0
var dashing: bool = false
## Accessibility (reduced flashing): the invulnerability tint holds steady instead of flickering.
var steady_flash: bool = false

var distance: float = 0.0
var speed: float = 0.0
var lane: int = 0
var surface: Surface = Surface.FLOOR
## Distance from the current surface: height above the floor, depth below the hull, or height on a wall.
var h: float = 0.0
## Velocity away from the current surface.
var vh: float = 0.0
var grounded: bool = true
var in_pit: bool = false
var alive: bool = true
## The level clock: seconds since the run started.
var elapsed: float = 0.0
var wall_side: int = 0
var last_event: String = ""

var _x: float = 0.0
var _switch_from: float = 0.0
var _switch_to: float = 0.0
var _switch_t: float = 1.0
var _boost: float = 0.0
var _jump_buffer: float = 0.0
var _coyote: float = 0.0
var _slide_left: float = 0.0
var _slide_on_land: bool = false
var _wall_t: float = 0.0
var _wall_h0: float = 0.0
var _wall_entry_x: float = 0.0
var _wall_entry_h: float = 0.0
var _roll: float = 0.0
var _queued: Array[StringName] = []
## A bump (a blocked lane switch or wall entry, _start_bump) is playing out: how far toward the
## blocked side it reaches (metres, signed), which way that side is, how long it takes, and whether a
## wall pushed the player back (the model leans away from it on the way back).
var _bumping: bool = false
var _bump_reach: float = 0.0
var _bump_dir: int = 0
var _bump_time: float = 0.0
var _bump_off_wall: bool = false
## The ramp whose blocked wall entry bumped the player last: a ramp bumps once, not every frame the
## player runs over it.
var _blocked_ramp: int = 0
var _bump_shape := BoxShape3D.new()
var _bump_query := PhysicsShapeQueryParameters3D.new()
## A zone doodad's push (GDD §3, _check_doodads) is playing out (the lane switch machinery carries it,
## over doodad_push_time), and the doodad's instance id with how long it's still ignored: it pushes once,
## even if a move cuts its push short.
var _pushing: bool = false
var _push_doodad: int = 0
var _push_ignore_left: float = 0.0
## How many times zone doodads have pushed the player this run (tests and tools).
var pushes: int = 0
## How many zone doodads the dash has smashed this run (tests and tools).
var smashes: int = 0
## The doodads the dash has claimed (GDD §3: dashing into one smashes it), by instance id: each breaks
## when the body reaches it instead of pushing (_check_doodads). Kept while dashing and for
## SMASH_CLAIM_GRACE after (_smash_grace_left), then let go.
var _smash_claims: Dictionary = {}
var _smash_grace_left: float = 0.0
var _doodad_shape := BoxShape3D.new()
var _doodad_query := PhysicsShapeQueryParameters3D.new()
var _dash_left: float = 0.0
var _dash_bonus: float = 0.0
var _last_speed_pad: int = 0
var _death_cause: String = ""
var _blocker_shape := BoxShape3D.new()
var _blocker_query := PhysicsShapeQueryParameters3D.new()

var _pivot: Node3D
var _avatar: PlayerAvatar  # Avatar
var _avatar_landed: bool = false  # Avatar: a "land" event since the last avatar update
var _hurt_debug: MeshInstance3D
var _shadow: MeshInstance3D
var _hazard_shape := BoxShape3D.new()
var _hazard_query := PhysicsShapeQueryParameters3D.new()
var _trigger_shape := BoxShape3D.new()
var _trigger_query := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_build_nodes()
	_hazard_query.shape = _hazard_shape
	_hazard_query.collide_with_areas = true
	_hazard_query.collide_with_bodies = false
	_hazard_query.collision_mask = TrackBuilder.LAYER_HAZARD
	_trigger_query.shape = _trigger_shape
	_trigger_query.collide_with_areas = true
	_trigger_query.collide_with_bodies = false
	_trigger_query.collision_mask = TrackBuilder.LAYER_TRIGGER
	_blocker_query.shape = _blocker_shape
	_blocker_query.collide_with_areas = true
	_blocker_query.collide_with_bodies = false
	_blocker_query.collision_mask = TrackBuilder.LAYER_LANE_BLOCKER
	_bump_query.shape = _bump_shape
	_bump_query.collide_with_areas = true
	_bump_query.collide_with_bodies = false
	_bump_query.collision_mask = TrackBuilder.LAYER_HAZARD | TrackBuilder.LAYER_WALL_BLOCKER
	_doodad_query.shape = _doodad_shape
	_doodad_query.collide_with_areas = true
	_doodad_query.collide_with_bodies = false
	_doodad_query.collision_mask = TrackBuilder.LAYER_DOODAD


func setup(p_tuning: MovementTuning, p_geo: TrackGeometry, start_lane: int) -> void:
	tuning = p_tuning
	geo = p_geo
	if rules == null:
		rules = GameRules.new()
	distance = 0.0
	elapsed = 0.0
	speed = tuning.run_speed
	lane = start_lane
	_x = geo.lane_x(lane)
	_switch_t = 1.0
	surface = Surface.FLOOR
	h = 0.0
	vh = 0.0
	grounded = true
	in_pit = false
	alive = true
	wall_side = 0
	_boost = 0.0
	_jump_buffer = 0.0
	_coyote = 0.0
	_slide_left = 0.0
	_slide_on_land = false
	_roll = 0.0
	_queued.clear()
	_bumping = false
	_bump_reach = 0.0
	_bump_dir = 0
	_bump_time = 0.0
	_bump_off_wall = false
	_blocked_ramp = 0
	_pushing = false
	_push_doodad = 0
	_push_ignore_left = 0.0
	pushes = 0
	smashes = 0
	_smash_claims.clear()
	_smash_grace_left = 0.0
	invulnerable_left = 0.0
	theft_immune_left = 0.0
	dashing = false
	_dash_left = 0.0
	_dash_bonus = 0.0
	_last_speed_pad = 0
	_death_cause = ""
	last_event = ""
	_avatar.reset()  # Avatar
	_apply_transform(1.0)


## Protection for this run (GDD §8): the armor (DamageRules.Armor.create), and the breakable items as
## single charges that break when used.
func apply_loadout(p_armor: DamageRules.Armor, p_shield: int, p_grapples: int, p_claws: bool, p_wall_time_multiplier: float = 1.0) -> void:
	armor_state = p_armor if p_armor != null else DamageRules.Armor.new()
	shield = p_shield
	grapples = p_grapples
	claws = p_claws
	wall_time_multiplier = p_wall_time_multiplier
	_avatar.set_equipment({"armor": armor > 0, "shield": shield > 0, "claws": claws})


## A pickup taken during the run (GDD §10: a boss fight's pickups, PickupField): one more charge of a
## breakable item (&"shield" or &"grapple"), up to `cap` charges of it, or the armor back whole
## (DamageRules.Armor.take_pickup; its own cap). True if it changed anything.
func gain_item(item: StringName, cap: int = 1) -> bool:
	if item == &"armor":
		if not armor_state.take_pickup():
			return false
		_armor_changed()
		item_gained.emit(item)
		return true
	var have: int = charges_of(item)
	if have < 0 or have >= cap:
		return false
	match item:
		&"shield":
			shield += 1
		_:
			grapples += 1
	_avatar.set_equipment({"armor": armor > 0, "shield": shield > 0})
	item_gained.emit(item)
	return true


## Charges left of a breakable item (&"shield" or &"grapple") or the armor's hits left (&"armor"), or
## -1 for anything else.
func charges_of(item: StringName) -> int:
	match item:
		&"armor":
			return armor
		&"shield":
			return shield
		&"grapple":
			return grapples
	return -1


func is_invulnerable() -> bool:
	return invulnerable_left > 0.0


## What protects the player right now, for DamageRules.
func defense() -> DamageRules.Defense:
	var d := DamageRules.Defense.new()
	d.armor = armor_state.is_up()
	d.shield = shield > 0
	d.invulnerable = invulnerable_left > 0.0
	d.claws = claws
	d.dashing = dashing
	d.god_mode = god_mode
	d.theft_immune = theft_immune_left > 0.0
	return d


## Resolves one contact with a hazard (obstacle, enemy hitbox or projectile) and applies the
## outcome. `stomping`: the player is dropping onto it from above. Returns the outcome.
func receive_hit(hazard: Hazard, stomping: bool = false) -> DamageRules.Outcome:
	if not alive:
		return DamageRules.Outcome.IGNORE
	var d: DamageRules.Defense = defense()
	var outcome: DamageRules.Outcome = DamageRules.resolve(hazard, d, stomping)
	match outcome:
		DamageRules.Outcome.BLOCKED_ARMOR:
			invulnerable_left = rules.hit_invulnerability
			var broke: bool = armor_state.block()
			_armor_changed()
			if broke:
				item_used.emit(&"armor")
			_event(&"armor_break" if broke else &"armor_hit")
		DamageRules.Outcome.BLOCKED_SHIELD:
			shield -= 1
			invulnerable_left = rules.hit_invulnerability
			_avatar.set_equipment({"shield": shield > 0})
			item_used.emit(&"shield")
			_event(&"shield_break")
		DamageRules.Outcome.STOMP, DamageRules.Outcome.DEFEAT_ENEMY:
			var cause: StringName = DamageRules.defeat_cause(outcome, d)
			if outcome == DamageRules.Outcome.STOMP:
				vh = rules.stomp_bounce_velocity
				grounded = false
				_slide_left = 0.0
				_event(&"stomp")
			hazard.enemy.defeat(cause)
			enemy_contact.emit(hazard.enemy, cause)
		DamageRules.Outcome.ROBBED:
			# GDD §9.12: no hit; the thief takes its share (the ScoreKeeper hears `robbed`).
			theft_immune_left = rules.theft_grace
			robbed.emit(hazard)
			_event(&"robbed")
		DamageRules.Outcome.KILL:
			_die(hazard.hazard_name)
	if outcome != DamageRules.Outcome.IGNORE:
		hazard.contacted.emit(outcome)
	return outcome


## Brings the player back where they died (GDD §4: revive item or rewarded ad), invulnerable for
## a moment. A player who fell is pulled back up like the grapple hook.
func revive() -> void:
	if alive:
		return
	alive = true
	_show_dead(false)
	invulnerable_left = rules.revive_invulnerability
	# DESIGN-TBD (docs/questions/g3.md): the armor comes back whole with a revive.
	if armor_state.restore():
		_armor_changed()
	if _death_cause == "fell" or in_pit:
		in_pit = false
		h = maxf(h, -tuning.pit_depth)
		vh = rules.grapple_pull_velocity
		grounded = false
	_event(&"revive")
	revived.emit()


## The juggernaut dash (GDD §8): passes through hazards for `duration` seconds, `speed_bonus` faster,
## and smashes the zone doodads it runs into (GDD §3, _check_doodads). Cooldowns belong to the power-up
## that calls this.
func start_dash(duration: float, speed_bonus: float) -> void:
	if not alive:
		return
	dashing = true
	_dash_left = duration
	_dash_bonus = speed_bonus
	_event(&"dash")


## The damage hitbox in world space, as it is now (projectiles test against it).
func hurtbox_aabb() -> AABB:
	var height: float = _hurtbox_height()
	var hx: float = tuning.hurtbox_size.x * 0.5
	var hz: float = tuning.hurtbox_size.z * 0.5
	match surface:
		Surface.CEILING:
			return AABB(position + Vector3(-hx, -height, -hz), Vector3(hx * 2.0, height, hz * 2.0))
		Surface.WALL:
			var x0: float = position.x - height if wall_side > 0 else position.x
			return AABB(Vector3(x0, position.y - hx, position.z - hz), Vector3(height, hx * 2.0, hz * 2.0))
	return AABB(position + Vector3(-hx, 0.0, -hz), Vector3(hx * 2.0, height, hz * 2.0))


func is_sliding() -> bool:
	return _slide_left > 0.0


## Feeds one named action. Used by _unhandled_input and by tests.
func press(action: StringName) -> void:
	if alive and running:
		_queued.append(action)


func surface_name() -> String:
	return ["floor", "ceiling", "wall"][surface]


func set_hitbox_visible(on: bool) -> void:
	_hurt_debug.visible = on


func _unhandled_input(event: InputEvent) -> void:
	for action: StringName in ACTIONS:
		if event.is_action_pressed(action):
			press(action)


func _physics_process(delta: float) -> void:
	if not alive or not running or tuning == null:
		return
	elapsed += delta
	_jump_buffer -= delta
	_coyote -= delta
	_slide_left -= delta
	_push_ignore_left -= delta
	invulnerable_left = maxf(invulnerable_left - delta, 0.0)
	theft_immune_left = maxf(theft_immune_left - delta, 0.0)
	# Broken armor comes back on the run's clock (GDD §4): it waits while the game is paused or the
	# player is down.
	if armor_state.tick(delta):
		_armor_changed()
		_event(&"armor_back")
	if dashing:
		_dash_left -= delta
		if _dash_left <= 0.0:
			dashing = false
			_dash_bonus = 0.0
			_smash_grace_left = SMASH_CLAIM_GRACE
			_event(&"dash_end")
	elif not _smash_claims.is_empty():
		_smash_grace_left -= delta
		if _smash_grace_left <= 0.0:
			_smash_claims.clear()
	# A ramp's boost and a speed pad's fade away the same way (GDD §3).
	_boost = tuning.boost_left(_boost, delta)
	speed = tuning.run_speed + tuning.speed_gain_per_minute * elapsed / 60.0 + _boost + _dash_bonus
	var motion: float = speed * delta
	distance += motion

	_consume_input()
	if surface == Surface.WALL:
		_update_wall(delta)
	else:
		_update_lane_switch(delta)
		_update_vertical(delta)
	if not alive:
		return
	_apply_transform(delta)
	_check_doodads(motion)
	_check_triggers(motion)
	_check_hazards(motion)


# --- Input -----------------------------------------------------------------

func _consume_input() -> void:
	for action: StringName in _queued:
		match action:
			&"move_left":
				_on_move(-1)
			&"move_right":
				_on_move(1)
			&"jump":
				_jump_buffer = tuning.jump_buffer_time
			&"slide":
				_on_slide()
	_queued.clear()


func _on_move(dir: int) -> void:
	match surface:
		Surface.WALL:
			# DESIGN-TBD: moving back toward the lanes while on a wall acts as a wall jump.
			if dir == -wall_side:
				_leave_wall(tuning.wall_jump_velocity, &"wall_jump")
		Surface.FLOOR:
			if in_pit:
				return
			var target: int = lane + dir
			if target < 0 or target >= geo.lane_count:
				_try_enter_wall(dir, false)
			else:
				_start_switch(target)
		Surface.CEILING:
			# DESIGN-TBD: no way from the ceiling onto a wall; the move is ignored at the edge.
			var target: int = clampi(lane + dir, 0, geo.lane_count - 1)
			if target == lane:
				return
			if _ceiling_ends_before(target):
				# GDD §3: a ceiling over fewer lanes keeps the player within its lanes.
				_bump_ceiling_edge(dir)
			else:
				_start_switch(target)


func _on_slide() -> void:
	if surface == Surface.WALL:
		return  # DESIGN-TBD: the slide action on a wall does nothing yet.
	if grounded:
		_slide_left = tuning.slide_duration
		_event(&"slide")
	elif tuning.air_slide_fast_fall and not in_pit:
		vh = minf(vh, -tuning.fast_fall_speed)
		_slide_on_land = true
		_event(&"slide")


func _event(kind: StringName) -> void:
	last_event = String(kind)
	movement_event.emit(kind)


# --- Lanes -----------------------------------------------------------------

func _start_switch(target: int) -> void:
	# GDD §3 (owner, October 8, 2026): dashing into a zone doodad smashes it, from the side too, so a
	# doodad's side doesn't block a dashing player (_lane_blocked claims it; it breaks on contact).
	# DESIGN-TBD (docs/questions/h5.md 2): a dashing switch into a doodad's side smashes it.
	if target != lane and _lane_blocked(target, dashing):
		# GDD §9.3: a solid side (the hover truck's) bumps the player back.
		var dir: int = signi(target - lane)
		_start_bump(dir, rules.lane_bump_fraction * absf(geo.lane_x(target) - geo.lane_x(lane)), tuning.lane_switch_time, false)
		_event(&"lane_blocked")
		return
	_bumping = false
	_pushing = false
	lane = target
	_switch_from = _x
	_switch_to = geo.lane_x(target)
	_switch_t = 0.0


## A bump: `reach` metres out toward the blocked side `dir` (-1 left, 1 right) and back over `seconds`,
## ending in the middle of the lane (from wherever a switch in progress had got to). The lane doesn't
## change, and the player can act meanwhile: a move or a jump works as usual. `off_wall`: a wall
## pushed the player back (a blocked wall entry).
func _start_bump(dir: int, reach: float, seconds: float, off_wall: bool) -> void:
	_bumping = true
	_pushing = false
	_bump_dir = dir
	_bump_reach = dir * maxf(reach, 0.0)
	_bump_time = seconds
	_bump_off_wall = off_wall
	_switch_from = _x
	_switch_to = geo.lane_x(lane)
	_switch_t = 0.0


func _update_lane_switch(delta: float) -> void:
	if _switch_t >= 1.0:
		return
	var seconds: float = _bump_time if _bumping else (tuning.doodad_push_time if _pushing else tuning.lane_switch_time)
	_switch_t = minf(1.0, _switch_t + delta / seconds)
	if _pushing:
		_x = _push_x(_switch_from, _switch_to, _switch_t)
	else:
		_x = _switch_x(_switch_from, _switch_to, _bump_reach if _bumping else 0.0, _switch_t)
	if _switch_t >= 1.0:
		_bumping = false
		_pushing = false


## Where a lane switch or a bump puts the player at progress t (0–1): from `from` to `to`, easing out,
## plus a bump's `reach` out toward the blocked side and back again.
static func _switch_x(from: float, to: float, reach: float, t: float) -> float:
	var k: float = 1.0 - (1.0 - t) * (1.0 - t)
	return lerpf(from, to, k) + reach * (1.0 - absf(2.0 * t - 1.0))


## Where a zone doodad's push puts the player at progress t (0–1), from `from` to `to`: a shove, fast
## at first and easing out more sharply than a lane switch, so the body clears the doodad's side soon.
static func _push_x(from: float, to: float, t: float) -> float:
	var u: float = 1.0 - t
	return lerpf(from, to, 1.0 - u * u * u)


## The share of a push's way (from where it starts to the middle of the lane it goes to) by progress
## t, the inverse of what _push_x eases: the progress at which it has come `k` of the way.
static func _push_progress(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 1.0 / 3.0)


## True if a solid side (a lane blocker) fills `target` lane beside the player right now. With
## `dash_through` (the player is dashing: GDD §3, the dash smashes a zone doodad) a zone doodad's side
## doesn't count: it's claimed (_smash_claims) and breaks when the body reaches it (_check_doodads).
## Any other solid side (a hover truck's, a boss's prop) blocks a dashing player too.
func _lane_blocked(target: int, dash_through: bool = false) -> bool:
	if target < 0 or target >= geo.lane_count:
		return false
	var height: float = _hurtbox_height()
	var y: float = position.y + height * 0.5 if surface != Surface.CEILING else position.y - height * 0.5
	_blocker_shape.size = Vector3(geo.lane_width * 0.5, height, tuning.hurtbox_size.z + 0.6)
	_blocker_query.transform = Transform3D(Basis.IDENTITY, Vector3(geo.lane_x(target), y, TrackGeometry.world_z(distance)))
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(_blocker_query, 4 if dash_through else 1)
	if not dash_through or hits.is_empty():
		return not hits.is_empty()
	var claims: Array[int] = []
	for hit: Dictionary in hits:
		if not hit["collider"] is DashBreakable:
			return true
		claims.append((hit["collider"] as Node).get_instance_id())
	for id: int in claims:
		_smash_claims[id] = true
	return false


# --- Floor & ceiling -------------------------------------------------------

func _update_vertical(delta: float) -> void:
	if grounded:
		var ground: float = _support_top()
		if is_nan(ground):
			grounded = false
			_coyote = tuning.coyote_time
		else:
			h = ground  # Follows moving platforms (a hover truck's roof).

	if _jump_buffer > 0.0 and (grounded or _coyote > 0.0) and not in_pit:
		vh = tuning.jump_velocity()
		grounded = false
		_coyote = 0.0
		_jump_buffer = 0.0
		_slide_left = 0.0
		_event(&"jump")

	if grounded:
		vh = 0.0
		return

	var gravity: float = tuning.gravity() * (tuning.fall_gravity_multiplier if vh < 0.0 else 1.0)
	vh -= gravity * delta
	h += vh * delta
	if vh > 0.0:
		return
	# Land on whatever surface is under the feet (the track, or a raised one like a truck roof), but
	# never climb back out of a pit.
	var top: float = _support_top()
	if not in_pit and not is_nan(top) and h <= top and h > top - tuning.pit_depth:
		_land(top)
		return
	if h > 0.0:
		return
	if surface == Surface.CEILING:
		_flip(Surface.FLOOR, 0.0)
		_event(&"hull_end")
	else:
		if h < -tuning.pit_depth and not in_pit:
			if grapples > 0:
				_use_grapple()
				return
			in_pit = true
		if h < -tuning.fall_death_depth:
			_die("fell")


## GDD §8: the grapple hook saves the player from one fall, then breaks.
func _use_grapple() -> void:
	grapples -= 1
	h = -tuning.pit_depth
	vh = rules.grapple_pull_velocity
	grounded = false
	item_used.emit(&"grapple")
	_event(&"grapple")


func _land(top: float = 0.0) -> void:
	h = top
	vh = 0.0
	grounded = true
	_event(&"land")
	if _slide_on_land:
		_slide_on_land = false
		_slide_left = tuning.slide_duration


## Swaps between floor and ceiling while keeping the player's world height and velocity.
func _flip(to: Surface, extra_velocity: float) -> void:
	h = tuning.ceiling_height - h
	vh = -vh - extra_velocity
	surface = to
	grounded = false
	_slide_left = 0.0
	_slide_on_land = false


## The height (away from the current surface, like `h`) of the highest supporting surface under the
## player's footprint, from 0.6 m above the feet to 0.3 m below; NAN if there is none. On the floor
## that's the track (0) or a raised surface such as a hover truck's roof; on the ceiling, the hull.
func _support_top() -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var on_floor: bool = surface == Surface.FLOOR
	_ray.collision_mask = TrackBuilder.LAYER_FLOOR if on_floor else TrackBuilder.LAYER_HULL
	var z: float = TrackGeometry.world_z(distance)
	var best: float = NAN
	for ox: float in [-tuning.foot_half_width, tuning.foot_half_width]:
		for oz: float in [-tuning.foot_half_depth, tuning.foot_half_depth]:
			_ray.from = Vector3(_x + ox, _surface_y(h + 0.6), z + oz)
			_ray.to = Vector3(_x + ox, _surface_y(h - 0.3), z + oz)
			var hit: Dictionary = space.intersect_ray(_ray)
			if not hit.is_empty():
				var top: float = (hit["position"] as Vector3).y if on_floor else tuning.ceiling_height - (hit["position"] as Vector3).y
				best = top if is_nan(best) else maxf(best, top)
	return best


## World y of a point `height` away from the current surface (floor or ceiling).
func _surface_y(height: float) -> float:
	return height if surface != Surface.CEILING else tuning.ceiling_height - height


## GDD §3 (decided September 26, 2026): ceilings don't have to cover every lane, and on one the player
## switches lanes only within its lanes. True if a ceiling is over the player's lane here but not over
## `target`, so the move would leave it. With no ceiling over the player's lane at all (a pad with
## nothing above it), nothing holds them in.
func _ceiling_ends_before(target: int) -> bool:
	return _ceiling_over(lane) and not _ceiling_over(target)


## True if a ceiling section (anything on the hull layer: the track's ceilings, a boss's) is over the
## middle of lane `lane_index` at the player's distance, at the ceiling's height. The ceiling's own
## collision box says where it is, so this follows its lanes exactly.
func _ceiling_over(lane_index: int) -> bool:
	var x: float = geo.lane_x(lane_index)
	var z: float = TrackGeometry.world_z(distance)
	_ray.collision_mask = TrackBuilder.LAYER_HULL
	_ray.from = Vector3(x, tuning.ceiling_height - 0.6, z)
	_ray.to = Vector3(x, tuning.ceiling_height + 0.3, z)
	return not get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


## A move toward a lane the ceiling doesn't cover (GDD §3): the clank and a bump out toward that side
## and back, like a lane switch into a solid side (the ceiling_blocked event plays the lane bump's
## clank), so the player sees why they didn't move. The lane doesn't change, and the bump stops short
## of the ceiling's edge (the body never passes the last lane's edge), so the player stays on it.
## DESIGN-TBD (docs/questions/b3.md): how a blocked move on a narrow ceiling looks and sounds.
func _bump_ceiling_edge(dir: int) -> void:
	var room: float = minf(rules.lane_bump_fraction * geo.lane_width, (geo.lane_width - tuning.visual_size.x) * 0.5)
	_start_bump(dir, maxf(room - absf(_x - geo.lane_x(lane)), 0.0), tuning.lane_switch_time, false)
	_event(&"ceiling_blocked")


## An anti-grav pad lands the player on its ceiling in its own lane (GDD §3: a pad sits under its
## ceiling). A lane switch still under way from the floor toward a lane that ceiling doesn't cover is
## blocked like any move on it (_bump_ceiling_edge), back into the pad's lane.
func _hold_to_pad_lane(pad: Area3D) -> void:
	if _switch_t >= 1.0 or _bumping:
		return
	var pad_lane: int = geo.lane_at(pad.global_position.x)
	if lane == pad_lane or _ceiling_over(lane) or not _ceiling_over(pad_lane):
		return
	var dir: int = signi(lane - pad_lane)
	lane = pad_lane
	_bump_ceiling_edge(dir)


# --- Walls -----------------------------------------------------------------

## Enters the wall on `side` (a move past the outer lane, or a ramp: `from_ramp`, `ramp` its trigger's
## instance id). Refused while falling into a gap, where a wall gap leaves no wall (wall_missing, a
## ramp's only once), and where the wall is blocked (a sign, or a wall a boss takes away), which clanks
## and bumps instead (_bump_wall; a ramp only once).
func _try_enter_wall(side: int, from_ramp: bool, ramp: int = 0) -> bool:
	if surface != Surface.FLOOR or in_pit:
		return false
	if not grounded and h < 0.0 and _coyote <= 0.0:
		return false  # Already dropping into a gap; like a jump, the wall is out of reach.
	if not wall_supported(side, distance):
		# DESIGN-TBD (docs/questions/wall_gaps.md): no bump or clank, since nothing is there to hit.
		if ramp == 0 or ramp != _blocked_ramp:
			if ramp != 0:
				_blocked_ramp = ramp
			_event(&"wall_missing")
		return false
	if _wall_blocked(side):
		if ramp == 0 or ramp != _blocked_ramp:
			if ramp != 0:
				_blocked_ramp = ramp
			_bump_wall(side)
		return false
	surface = Surface.WALL
	wall_side = side
	_wall_t = 0.0
	_wall_entry_x = _x
	_wall_entry_h = maxf(h, 0.0)
	var target: float = tuning.ramp_entry_height if from_ramp \
		else tuning.wall_entry_height + _wall_entry_h * tuning.wall_air_entry_factor
	_wall_h0 = minf(target, tuning.wall_max_height)
	vh = 0.0
	grounded = false
	_jump_buffer = 0.0
	_slide_left = 0.0
	_slide_on_land = false
	_switch_t = 1.0
	_bumping = false
	_pushing = false
	if from_ramp:
		# GDD §3: a ramp adds speed, which fades away like a speed pad's (boost_left).
		_boost += tuning.ramp_speed_boost
	_event(&"ramp" if from_ramp else &"wall_enter")
	return true


## GDD §3: a blocked wall entry plays the clank (the wall_blocked event's sound) and a small sideways
## bump, out toward the wall and back like a blocked lane switch's, so the player sees why they didn't
## get on. The player stays in the outer lane, and the bump never takes them into a hazard (_bump_room).
func _bump_wall(side: int) -> void:
	_start_bump(side, _bump_room(side), tuning.wall_bump_time, true)
	_event(&"wall_blocked")


## How far toward the wall on `side` a bump may take the player, up to wall_bump_distance: the body (at
## its visual size, a little wider than the hitbox) must not reach into a hazard or anything that
## blocks the wall, anywhere along the bump. So a sign that reaches down to the player stops the bump
## at its face, and a bump never moves the player into a hazard. Collision itself is unchanged.
func _bump_room(side: int) -> float:
	var most: float = maxf(tuning.wall_bump_distance, 0.0)
	if _bump_clear(side, most):
		return most
	var lo: float = 0.0
	var hi: float = most
	for i: int in 8:
		var mid: float = (lo + hi) * 0.5
		if _bump_clear(side, mid):
			lo = mid
		else:
			hi = mid
	return maxf(lo - BUMP_CLEARANCE, 0.0)


## True if a bump of `reach` metres toward the wall on `side`, started now, keeps the body off every
## hazard and wall blocker: nothing in the ground it newly covers, beyond both the middle of its lane
## and where it is now (a bump started off-centre peaks further out), over the track it runs meanwhile
## and the heights it may pass through.
func _bump_clear(side: int, reach: float) -> bool:
	var half: float = tuning.visual_size.x * 0.5
	var home: float = geo.lane_x(lane)
	# Distances toward the wall: where the body's middle is now (or its lane's, if further out), and
	# the furthest the bump takes it (the curve's corners are on the samples).
	var now: float = maxf(side * _x, side * home)
	var peak: float = now
	for i: int in range(1, 33):
		peak = maxf(peak, side * _switch_x(_x, home, side * reach, i / 32.0))
	if peak <= now + 0.001:
		return true
	var inner: float = now + half
	var outer: float = peak + half
	var seconds: float = tuning.wall_bump_time
	var rise: float = vh * seconds
	var y0: float = h + minf(rise, 0.0) - 0.1
	var y1: float = h + tuning.visual_size.y + maxf(rise, 0.0) + 0.1
	var d0: float = distance - tuning.visual_size.z * 0.5 - 0.1
	var d1: float = distance + maxf(speed, 0.0) * seconds + tuning.visual_size.z * 0.5 + 0.1
	_bump_shape.size = Vector3(outer - inner, y1 - y0, d1 - d0)
	_bump_query.transform = Transform3D(Basis.IDENTITY,
		Vector3(side * (inner + outer) * 0.5, (y0 + y1) * 0.5, TrackGeometry.world_z((d0 + d1) * 0.5)))
	return get_world_3d().direct_space_state.intersect_shape(_bump_query, 1).is_empty()


func _wall_blocked(side: int) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 20.0, tuning.hurtbox_size.z + 0.4)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = TrackBuilder.LAYER_WALL_BLOCKER
	query.transform = Transform3D(Basis.IDENTITY, Vector3(side * (geo.wall_x() - 0.3), 5.0, TrackGeometry.world_z(distance)))
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## True if wall `side` has its wall-running surface at track distance `d`: no wall gap
## (LevelLayout.wall_gaps) holds it. A plain interval check on the layout, no physics.
func wall_supported(side: int, d: float) -> bool:
	return LevelLayout.wall_supported_in(wall_gaps, side, d)


func _update_wall(delta: float) -> void:
	if not wall_supported(wall_side, distance):
		# A wall gap: the wall runner drops off into the outer lane, falling from where they were.
		_leave_wall(0.0, &"wall_gap_drop")
		return
	_wall_t += delta
	var wall_x: float = wall_side * geo.wall_x()
	if _wall_t < tuning.wall_entry_time:
		var k: float = 1.0 - pow(1.0 - _wall_t / tuning.wall_entry_time, 2.0)
		_x = lerpf(_wall_entry_x, wall_x, k)
		h = lerpf(_wall_entry_h, _wall_h0, k)
	else:
		_x = wall_x
		var s: float = clampf((_wall_t - tuning.wall_entry_time) / (tuning.wall_slide_time * wall_time_multiplier), 0.0, 1.0)
		h = tuning.wall_exit_height + (_wall_h0 - tuning.wall_exit_height) * (1.0 - pow(s, tuning.wall_descent_exponent))
		if s >= 1.0:
			_leave_wall(0.0, &"wall_exit")
			return
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		_leave_wall(tuning.wall_jump_velocity, &"wall_jump")


func _leave_wall(velocity: float, kind: StringName) -> void:
	surface = Surface.FLOOR
	_start_switch(geo.lane_count - 1 if wall_side > 0 else 0)
	vh = velocity
	grounded = false
	_event(kind)


## Knocks a wall runner off their wall (something covering it that hurts and won't be run through, the Sewer
## Swarm's climb: SwarmClimb): they drop off into the outer lane, falling from where they were, with a
## blocked wall's clank (wall_blocked). False if they weren't on a wall.
func repel_from_wall() -> bool:
	if not alive or surface != Surface.WALL:
		return false
	_leave_wall(0.0, &"wall_blocked")
	return true


# --- Zone doodads -----------------------------------------------------------

## GDD §3 (owner's playtest, September 30, 2026): zone doodads never hurt; running into one pushes the
## player into a neighbouring lane. On the floor, the body (its visual size, as it is now: what looks
## like contact is contact; sliding, its slide height; from just above the feet, so a player standing
## on a doodad's top isn't pushed by it) meets a doodad's body (TrackBuilder.LAYER_DOODAD) at its front
## when it would touch it within the time the shove needs to clear its side (_push_clear_seconds), so
## the body never sinks into it. In the air it's the same: a jump into one is pushed too (doodads are
## too tall to jump). The push (_start_push) goes to the doodad's side, or back the way the player came
## if they caught its front corner mid-switch; a side without room (another lane blocker there) gives
## way to the other. Ceiling riders and wall runners never meet one (TrackBuilder; the generator keeps
## doodads off ceilings and out of the outermost lanes).
## The dash smashes one instead (GDD §3, owner, October 8, 2026: "dashing into one breaks it apart, and
## the player keeps their lane with no push and no damage"; _dash_claims): a doodad the dash reaches
## before it ends is claimed when it comes within the push's reach, and breaks (_smash) when the body
## meets it, head-on, at a front corner or from the side (a switch into it while dashing, _lane_blocked);
## the player runs on in their lane, at their speed. A dash that ends short of one leaves it unclaimed,
## and it pushes as usual, at the push's usual time.
func _check_doodads(motion: float) -> void:
	if surface != Surface.FLOOR or in_pit:
		return
	var half: float = tuning.visual_size.x * 0.5
	var depth: float = tuning.visual_size.z
	var height: float = _hurtbox_height() * tuning.visual_size.y / maxf(tuning.hurtbox_size.y, 0.01)
	var front: float = distance + depth * 0.5
	var widest: float = maxf(tuning.doodad_large_width, maxf(tuning.doodad_medium_width, tuning.doodad_small_width))
	var reach: float = maxf(speed, 0.0) * _push_clear_seconds(widest, 0.0, geo.lane_width) + motion + 0.05
	var back: float = distance - depth * 0.5
	_doodad_shape.size = Vector3(half * 2.0, maxf(height - DOODAD_FEET_CLEARANCE, 0.05), front + reach - back)
	_doodad_query.transform = Transform3D(Basis.IDENTITY, Vector3(_x, h + DOODAD_FEET_CLEARANCE + _doodad_shape.size.y * 0.5,
		TrackGeometry.world_z((back + front + reach) * 0.5)))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(_doodad_query, 4):
		var area := hit["collider"] as Area3D
		if area == null or not area.has_meta(&"doodad"):
			continue
		var d: Dictionary = area.get_meta(&"doodad")
		var gap: float = float(d["start"]) - front
		# The doodad pushing the player is left alone while its push carries them (it pushes once). A dash
		# started during the push doesn't smash it: the push completes (DESIGN-TBD, docs/questions/h5.md 7).
		# Once a move has cut the push short, a dash that steers back into it takes it: claimed (a dashing
		# switch into its side, _lane_blocked) or the dash reaches it (_dash_claims), so it breaks on contact
		# instead of the body sinking into it while it's still left alone.
		if area.get_instance_id() == _push_doodad and (_pushing or _push_ignore_left > 0.0) \
				and not _smash_claims.has(area.get_instance_id()) and (_pushing or not _dash_claims(area, gap)):
			continue
		if _dash_claims(area, gap):
			# The body meets it by the next frame (or is already beside it): it breaks now, before they touch.
			if gap <= motion:
				_smash(area as DashBreakable)
			continue
		var width: float = tuning.doodad_size(StringName(d["size"])).x
		var centre: float = geo.lane_x(int(d["lane"]))
		var off: float = _x - centre
		var dir: int = int(d["side"])
		if absf(off) > PUSH_HEAD_ON_SHARE * geo.lane_width:
			dir = 1 if off > 0.0 else -1
		var toward: float = off * dir
		if gap > maxf(speed, 0.0) * _push_clear_seconds(width, toward, absf(geo.lane_x(int(d["lane"]) + dir) - _x)) + motion:
			continue
		_start_push(area, int(d["lane"]), dir, int(d["side"]))
		return


## True if the dash takes doodad `area` (GDD §3: dashing into one smashes it), whose front is `gap` metres
## ahead of the body's (below 0 once the body is level with it): claimed already (a switch into its side
## while dashing, or an earlier frame of this approach), or the dash lasts until the body gets there (it
## covers `gap` in the time it has left, _dash_reach), which claims it now. Only a DashBreakable (what the
## track builds) breaks.
func _dash_claims(area: Area3D, gap: float) -> bool:
	if not area is DashBreakable:
		return false
	var id: int = area.get_instance_id()
	if _smash_claims.has(id):
		return true
	if not dashing or maxf(gap, 0.0) > _dash_reach():
		return false
	_smash_claims[id] = true
	return true


## How far along the track the player runs in the time the dash has left (metres): the speed without
## the ramp's or speed pad's boost over that time, plus what the boost adds while it fades
## (MovementTuning.boost_distance, as it fades each frame: boost_left).
func _dash_reach() -> float:
	return maxf(speed - _boost, 0.0) * _dash_left + tuning.boost_distance(_boost, _dash_left)


## The dash breaks doodad `b` apart (GDD §3, owner, October 8, 2026; DashBreakable.smash: its body, lane
## blocker and standable top go, and its look): no push and no damage, and the player runs on in their
## lane at their speed. `smashed` and the `<kind>_smash` event follow (RunEffects flings its pieces and
## shakes lightly; the event plays the crunch). DESIGN-TBD (docs/questions/h5.md 4): it scores nothing.
func _smash(b: DashBreakable) -> void:
	_smash_claims.erase(b.get_instance_id())
	if not b.smash():
		return
	smashes += 1
	smashed.emit(b)
	_event(StringName("%s_smash" % b.kind))


## How long into a push the body clears the side of a doodad `width` wide: starting `toward` metres off
## its middle toward the push's side (negative: on the other side) and going `way` metres to the next
## lane's middle (_push_x). 0 when it's clear already.
func _push_clear_seconds(width: float, toward: float, way: float) -> float:
	var need: float = width * 0.5 + tuning.visual_size.x * 0.5 - toward
	if need <= 0.0:
		return 0.0
	return _push_progress(need / maxf(way, 0.01)) * tuning.doodad_push_time


## Starts a doodad's push (_check_doodads) from the doodad's lane `doodad_lane` toward `dir`, or the
## other way when that side has no room (the track's edge, or a lane blocker there); with neither, the
## doodad's own way (`own_side`, where the generator always leaves room). The lane switch machinery
## carries it (doodad_push_time, _push_x), the event plays the thud, and the player can act meanwhile:
## a move or a jump works as usual.
func _start_push(area: Area3D, doodad_lane: int, dir: int, own_side: int) -> void:
	var target: int = doodad_lane + own_side
	for way: int in [dir, -dir]:
		if _push_room(doodad_lane + way):
			target = doodad_lane + way
			break
	target = clampi(target, 0, geo.lane_count - 1)
	_bumping = false
	_pushing = true
	_push_doodad = area.get_instance_id()
	_push_ignore_left = tuning.doodad_push_time
	lane = target
	_switch_from = _x
	_switch_to = geo.lane_x(target)
	_switch_t = 0.0
	pushes += 1
	_event(&"doodad_push")


## True if a push may end in `target`: a lane of the track no solid side fills beside the player.
func _push_room(target: int) -> bool:
	return target >= 0 and target < geo.lane_count and not _lane_blocked(target)


# --- Triggers & hazards ----------------------------------------------------

## Pads and ramps under the feet, swept back over this frame's motion.
func _check_triggers(motion: float) -> void:
	if surface != Surface.FLOOR or not grounded:
		return
	_trigger_shape.size = SENSOR_SIZE + Vector3(0.0, 0.0, motion)
	_trigger_query.transform = Transform3D(Basis.IDENTITY, position + Vector3(0.0, SENSOR_SIZE.y * 0.5, motion * 0.5))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(_trigger_query, 4):
		var area := hit["collider"] as Area3D
		match area.get_meta(&"kind", &""):
			&"pad":
				_flip(Surface.CEILING, tuning.antigrav_launch_velocity)
				_event(&"pad")
				_hold_to_pad_lane(area)
				return
			&"ramp":
				if _try_enter_wall(int(area.get_meta(&"side")), true, area.get_instance_id()):
					return
			&"speed_pad":
				if area.get_instance_id() != _last_speed_pad:
					_last_speed_pad = area.get_instance_id()
					_boost += tuning.speed_pad_boost  # Fades like a ramp's (boost_left).
					_event(&"speed_pad")


## The damage hitbox as it is now, stretched back over this frame's motion: any hazard
## the body passed through since the last frame counts as a real contact.
func _check_hazards(motion: float) -> void:
	var height: float = _hurtbox_height()
	_hazard_shape.size = Vector3(tuning.hurtbox_size.x, height, tuning.hurtbox_size.z + motion)
	var basis := Basis(Vector3.BACK, _roll)
	_hazard_query.transform = Transform3D(basis, position + basis * Vector3(0.0, height * 0.5, motion * 0.5))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(_hazard_query, 8):
		var hazard := hit["collider"] as Hazard
		if hazard == null:
			continue
		receive_hit(hazard, _is_stomping(hazard))
		if not alive:
			return


## Dropping onto the hazard from above: on the floor, descending, feet near its top. On the ceiling the
## same upside down, onto a hazard that hangs from it (Hazard.upside_down, a Barnacle Turret, GDD
## §9.8): falling back toward the ceiling after a jump, feet near its underside. DESIGN-TBD
## (docs/questions/c1.md 1): how a stomp reaches a ceiling enemy.
func _is_stomping(hazard: Hazard) -> bool:
	if grounded or vh > 0.0:
		return false
	if surface == Surface.CEILING:
		return hazard.upside_down and position.y <= hazard.bottom_y() + rules.stomp_tolerance
	return surface == Surface.FLOOR and position.y >= hazard.top_y() - rules.stomp_tolerance


func _hurtbox_height() -> float:
	return tuning.hurtbox_slide_height if is_sliding() else tuning.hurtbox_size.y


func _die(cause: String) -> void:
	alive = false
	dashing = false
	_dash_bonus = 0.0
	_smash_claims.clear()
	_death_cause = cause
	_update_avatar(0.0)  # Avatar: starts the collapse (the avatar finishes it on its own).
	_event(&"died")
	last_event = "died: " + cause
	died.emit(cause)


## Revive: the model stands back up (the avatar plays the collapse itself on death).
func _show_dead(on: bool) -> void:
	if not on:
		_avatar.reset()


## The invulnerability window flicker (GDD §4: the character flashes): a bright tint on the suit,
## flickering, or held steady with the reduced-flashing setting.
func _update_flash() -> void:
	var on: bool = invulnerable_left > 0.0 and (steady_flash or int(invulnerable_left * 16.0) % 2 == 1)
	_avatar.set_flash(on)


## What the player model shows the player carrying (PlayerAvatar.set_equipment): claws, armor,
## shield, weapon_tier, magnet. RunWorld sets it from the loadout; broken items update it.
func set_equipment_look(eq: Dictionary) -> void:
	_avatar.set_equipment(eq)


## The armor changed: the model wears it while it's up (and sheds it as it breaks), and listeners hear.
func _armor_changed() -> void:
	_avatar.set_equipment({"armor": armor_state.is_up()})
	armor_changed.emit()


## World position the shoulder weapon fires from (the model's emitter).
func weapon_muzzle() -> Vector3:
	return _avatar.weapon_muzzle()


# --- Presentation ----------------------------------------------------------

func _apply_transform(delta: float) -> void:
	var y: float = h
	var roll_target: float = 0.0
	match surface:
		Surface.CEILING:
			y = tuning.ceiling_height - h
			roll_target = PI
		Surface.WALL:
			roll_target = wall_side * PI * 0.5
	position = Vector3(_x, y, TrackGeometry.world_z(distance))
	_roll = lerp_angle(_roll, roll_target, 1.0 - exp(-22.0 * delta))
	_pivot.rotation.z = _roll
	_update_flash()

	var height: float = _hurtbox_height()
	_hurt_debug.scale = Vector3(tuning.hurtbox_size.x, height, tuning.hurtbox_size.z)
	_hurt_debug.position.y = height * 0.5
	_update_avatar(delta)  # Avatar: sliding is a pose now, not a squashed box.
	_update_shadow()


## Avatar: hands the runner model this frame's movement state (see PlayerAvatar.animate).
func _update_avatar(delta: float) -> void:
	_avatar.fit_to(tuning.visual_size)
	_avatar.animate({
		"surface": surface_name(),
		"grounded": grounded,
		"vh": vh,
		"sliding": is_sliding(),
		"distance": distance,
		"speed": speed,
		"wall_side": wall_side,
		"switch_dir": _switch_dir(),
		"alive": alive,
		"dashing": dashing,
		"just_landed": _avatar_landed,
		"stomping": _slide_on_land and not grounded,  # DESIGN-TBD: the air-slide fast fall shows the stomp.
	}, delta)
	_avatar_landed = false


## Avatar: the way the model leans sideways (PlayerAvatar's switch_dir) while it moves across: into a
## lane switch, and into the blocked lane through a blocked switch's bump. A blocked wall entry's bump
## stays upright on the way out and leans away from the wall on the way back: pushed off it. (Leaning
## in would take the upper body past a sign that the bump stopped the body short of.)
## DESIGN-TBD: the wall bump's look on the model (GDD §3 only says "a small sideways bump").
func _switch_dir() -> int:
	if _switch_t >= 1.0:
		return 0
	if not _bumping:
		return int(signf(_switch_to - _switch_from))
	if _bump_off_wall:
		return -_bump_dir if _switch_t >= 0.5 else 0
	return _bump_dir


## A blob shadow on the surface below (or above, on the ceiling) to read height and gaps.
## Over a gap there's no surface, so no shadow, which is itself a cue.
func _update_shadow() -> void:
	if surface == Surface.WALL or not is_inside_tree():
		_shadow.visible = false
		return
	var on_floor: bool = surface == Surface.FLOOR
	var plane_y: float = 0.0 if on_floor else tuning.ceiling_height
	_ray.collision_mask = TrackBuilder.LAYER_FLOOR if on_floor else TrackBuilder.LAYER_HULL
	var away: float = 1.0 if on_floor else -1.0
	_ray.from = position + Vector3(0.0, away * 0.1, 0.0)
	_ray.to = Vector3(position.x, plane_y - away * 0.5, position.z)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray)
	_shadow.visible = not hit.is_empty()
	if hit.is_empty():
		return
	var gap: float = absf(position.y - plane_y)
	var s: float = clampf(1.0 - gap / 6.0, 0.35, 1.0)
	_shadow.global_position = Vector3(position.x, plane_y + (0.02 if on_floor else -0.02), position.z)
	_shadow.scale = Vector3(s, 1.0, s)


func _build_nodes() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)

	# Avatar: the runner model replaces the grey-box body and visor.
	_avatar = PlayerAvatar.new()
	_pivot.add_child(_avatar)
	movement_event.connect(func(kind: StringName) -> void: _avatar_landed = _avatar_landed or kind == &"land")

	_hurt_debug = MeshInstance3D.new()
	_hurt_debug.mesh = GreyboxMaterials.unit_box()
	_hurt_debug.material_override = GreyboxMaterials.debug_hitbox()
	_hurt_debug.visible = false
	_pivot.add_child(_hurt_debug)

	var disc := CylinderMesh.new()
	disc.top_radius = 0.45
	disc.bottom_radius = 0.45
	disc.height = 0.01
	disc.radial_segments = 16
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	_shadow.material_override = GreyboxMaterials.overlay(GreyboxMaterials.SHADOW, false)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)
