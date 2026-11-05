class_name Player
extends CharacterBody2D
## A character in the arena. On the authority (host or offline practice) it is moved by
## PlayerMotor from inputs; clients predict themselves and interpolate other players.
## Visuals are placeholders until pixel-art sprites exist (PLAN.md section Q).

const BODY_SIZE := Vector2(36, 56)
const GUN_LENGTH := 30.0
## How long the shooting animation plays after a shot.
const FIRING_VISUAL_MS := 150
## Placeholder colors so players can be told apart before characters have sprites.
const SLOT_COLORS: Array[Color] = [Color(1, 0.72, 0.2), Color(0.35, 0.75, 1), Color(0.55, 0.9, 0.4), Color(1, 0.45, 0.6)]

var character: CharacterData
var motor_state := PlayerMotor.State.new()
var peer_id := 1
var slot := 0
var display_name := ""
## Teams.NONE in free-for-all; teammates do not hurt each other (2 v 2).
var team := Teams.NONE
## Lives left in a network match (0 = eliminated). Set by the authority, shown in the HUD.
var lives := 0
## Damage percent 0-100 (host decides, shown above the character): more = more knockback.
var damage := 0.0
var _damage_label: Label
var _shown_damage := -1
var kills := 0
var deaths := 0
## True right after a respawn: hits do not push the player (shown by blinking).
var invulnerable := false
var facing := 1
var aim := 0
## Newest input applied on the host; sent in snapshots for client prediction (M4).
var last_input_seq := 0
## Seconds until the current weapon may fire again. Simulated by the host AND by the own
## client's prediction (tick_weapon), so the shooter's recoil is predicted too.
var fire_cooldown := 0.0
## True on the tick a shot was fired (the host then spawns the projectiles).
var fired_this_tick := false
## Rounds left in the magazine and seconds of reloading left (authority decides; clients
## get both via the snapshot). reload_started_ms only drives the reload animation.
var ammo := 0
var reload_time_left := 0.0
var reload_started_ms := -100000
## Ability runtime state (authority decides; clients receive it in snapshots).
var ability_cooldown := 0.0
var ability_time_left := 0.0
## True on the tick the ability was activated (host applies effects on others).
var ability_started := false
## Clouds and platforms of the match (set by MatchController); null in unit tests.
var effects: AreaEffects
## Authority: seconds of respawn protection left.
var invulnerable_time := 0.0
## Authority: how long the player has been outside the arena (see out_of_bounds_grace).
var out_of_bounds_time := 0.0
## Render correction only; collisions always use the corrected simulation position.
var visual_offset := Vector2.ZERO

## Remote players on clients: playback on the player's own timeline (SnapshotTimeline).
## Client-controlled players on the host: _display shows them on the same kind of timeline
## (simulation and hits still use the real position).
var _interpolator: RemoteInterpolator
var _display: RemoteInterpolator
var timeline: SnapshotTimeline
var _last_state_time := -INF
var _last_state_active := false
var _name_label: Label
## Pixel-art sprites (null = placeholder rectangle, e.g. in unit tests).
var _visual: PlayerVisual
## Last shot (msec): the authority sets it, clients get it via the snapshot "firing" flag.
var last_fire_ms := -100000


func setup(data: CharacterData, player_slot: int, player_peer_id: int, player_name: String) -> void:
	character = data
	slot = player_slot
	peer_id = player_peer_id
	display_name = player_name
	var name_label := Label.new()
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text = player_name
	# The arena camera is zoomed out, so world-space text needs a bigger font to stay readable.
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(240, 36)
	name_label.position = Vector2(-120, -BODY_SIZE.y / 2.0 - 54)
	name_label.add_theme_color_override("font_color", SLOT_COLORS[slot % SLOT_COLORS.size()].lightened(0.3))
	add_child(name_label)
	_name_label = name_label
	_damage_label = Label.new()
	_damage_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_damage_label.add_theme_font_size_override("font_size", 26)
	_damage_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	_damage_label.add_theme_constant_override("outline_size", 6)
	_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_label.size = Vector2(120, 32)
	add_child(_damage_label)
	refill_magazine()
	if character and character.sprite_sheet:
		_visual = PlayerVisual.new()
		_visual.setup(character)
		add_child(_visual)


## 2 v 2: the name above the character takes the team color.
func set_team(new_team: int) -> void:
	team = new_team
	if _name_label and Teams.is_valid(team):
		_name_label.add_theme_color_override("font_color", Teams.color(team).lightened(0.2))


## One shared movement tick, also used during client prediction and replay.
func simulate(input: InputFrame, delta: float) -> void:
	tick_ability(input, delta)
	var slow := effects.slow_for(self) if effects else Vector2.ONE
	motor_state.speed_scale = slow.x
	motor_state.jump_scale = slow.y
	PlayerMotor.step(self, input, motor_state, character, delta)
	fired_this_tick = tick_weapon(input, delta)
	aim = input.aim
	last_input_seq = input.seq
	facing = motor_state.facing
	queue_redraw()


func current_weapon() -> WeaponData:
	return character.weapon if character else null


## Shared by the host and the own client's prediction: cooldown, reload, ammo and the
## shooter's recoil. Returns true when a shot is fired this tick.
func tick_weapon(input: InputFrame, delta: float) -> bool:
	fire_cooldown = _count_down(fire_cooldown, delta)
	if tick_reload(delta):
		return false
	var weapon := current_weapon()
	if weapon == null or not input.is_held(InputFrame.FIRE) or fire_cooldown > 0.0 or not can_fire():
		return false
	fire_cooldown = roundf(CombatRules.fire_interval(weapon) * NetCodec.WEAPON_TIMER_UNITS) / NetCodec.WEAPON_TIMER_UNITS
	last_fire_ms = Time.get_ticks_msec()
	velocity += CombatRules.recoil(InputFrame.aim_to_vector(input.aim), weapon)
	use_round()
	return true


## Weapon timers are kept on the snapshot's grid (NetCodec.WEAPON_TIMER_UNITS), so the host
## and the replaying client compare exactly the same numbers (0.1 s - 6 ticks is not 0 in
## floating point and would otherwise fire a tick apart).
static func _count_down(seconds: float, delta: float) -> float:
	var left := roundf((seconds - delta) * NetCodec.WEAPON_TIMER_UNITS)
	return left / NetCodec.WEAPON_TIMER_UNITS if left > 0.0 else 0.0


## Full magazine, no reload (spawn and every respawn).
func refill_magazine() -> void:
	var weapon := current_weapon()
	ammo = weapon.magazine_size if weapon else 0
	reload_time_left = 0.0


func is_reloading() -> bool:
	return reload_time_left > 0.0


## Authority, every tick: counts the reload down; true while the weapon cannot fire yet.
func tick_reload(delta: float) -> bool:
	if reload_time_left <= 0.0:
		return false
	reload_time_left = _count_down(reload_time_left, delta)
	if reload_time_left > 0.0:
		return true
	refill_magazine()
	return false


## Authority: one shot fired; the last round starts the reload.
func use_round() -> void:
	ammo = maxi(ammo - 1, 0)
	var weapon := current_weapon()
	if ammo == 0 and weapon:
		reload_time_left = weapon.reload_time
		reload_started_ms = Time.get_ticks_msec()


## 0..1 while reloading (for the animation), -1 otherwise.
func reload_progress() -> float:
	var weapon := current_weapon()
	if not is_reloading() or weapon == null:
		return -1.0
	return clampf((Time.get_ticks_msec() - reload_started_ms) / (weapon.reload_time * 1000.0), 0.0, 1.0)


## Cooldowns and activation on press (not while held); shared by host and prediction.
func tick_ability(input: InputFrame, delta: float) -> void:
	ability_cooldown = maxf(ability_cooldown - delta, 0.0)
	ability_time_left = maxf(ability_time_left - delta, 0.0)
	var ability := character.ability if character else null
	var pressed := input.is_held(InputFrame.ABILITY) and not motor_state.prev_buttons & InputFrame.ABILITY
	ability_started = ability != null and pressed and ability_cooldown <= 0.0
	if ability_started:
		ability_cooldown = ability.cooldown
		ability_time_left = ability.duration
		ability.start(self, input)


func ability_active() -> bool:
	return ability_time_left > 0.0


## Authority: a hit. Knockback grows with the damage taken so far, then the hit's damage is
## added; an active shield scales both.
func take_hit(push: Vector2, added_damage: float) -> void:
	var scale := knockback_scale()
	velocity += push * scale * CombatRules.damage_multiplier(damage)
	damage = minf(damage + added_damage * scale, CombatRules.MAX_DAMAGE)


## Knockback multiplier from an active ability (e.g. shield).
func knockback_scale() -> float:
	return character.ability.knockback_scale() if ability_active() and character and character.ability else 1.0


func can_fire() -> bool:
	return not (ability_active() and character and character.ability and not character.ability.allows_firing())


func snapshot_state() -> Dictionary:
	return {"slot": slot, "position": position, "velocity": velocity, "facing": facing,
			"active": visible, "invulnerable": invulnerable, "aim": aim, "last_seq": last_input_seq, "lives": lives,
			"on_floor": motor_state.on_floor, "prev_buttons": motor_state.prev_buttons,
			"jumps_left": motor_state.jumps_left, "jump_buffer_timer": motor_state.jump_buffer_timer,
			"drop_timer": motor_state.drop_timer, "kills": kills, "deaths": deaths,
			"ability_cooldown": ability_cooldown, "ability_active": ability_active(), "firing": is_firing(),
			"boost_time_left": motor_state.boost_time_left, "ammo": ammo, "reloading": is_reloading(),
			"fire_cooldown": fire_cooldown, "reload_time_left": reload_time_left, "damage": damage}


## Restore all movement memory before replaying inputs, including contact and press edges.
func restore_state(state: Dictionary) -> void:
	_apply_state(state)
	velocity = state.velocity
	last_input_seq = state.last_seq
	motor_state.facing = state.facing
	motor_state.on_floor = state.on_floor
	motor_state.prev_buttons = state.prev_buttons
	motor_state.jumps_left = state.jumps_left
	motor_state.jump_buffer_timer = state.jump_buffer_timer
	motor_state.drop_timer = state.drop_timer
	motor_state.boost_time_left = state.get("boost_time_left", 0.0)
	# Exact weapon timers, so replayed shots (recoil) happen on the same ticks as on the host.
	fire_cooldown = state.get("fire_cooldown", 0.0)
	reload_time_left = state.get("reload_time_left", reload_time_left)
	set_collision_mask_value(PlayerMotor.ONE_WAY_LAYER, visible and motor_state.drop_timer <= 0.0)


## Client only: queue a host snapshot of this remote player for display. The host's own
## player (peer 1) is placed at the snapshot's host time, others at their own input time.
func receive_state(state: Dictionary, host_time_ms: float) -> void:
	if _interpolator == null:
		_interpolator = RemoteInterpolator.new(0 if timeline else RemoteInterpolator.INTERPOLATION_DELAY_MS)
	if timeline == null:
		_interpolator.push(host_time_ms, state)
		return
	var time_ms := host_time_ms if peer_id == 1 else timeline.seq_ms(state.last_seq)
	if time_ms <= _last_state_time:
		if state.active == _last_state_active:
			return  # the host is waiting for this player's next input: nothing new to show
		time_ms = _last_state_time + 1.0  # e.g. died on the same input: show it right after
	else:
		timeline.observe_ms(time_ms, Time.get_ticks_msec())
	_last_state_time = time_ms
	_last_state_active = state.active
	_interpolator.push(time_ms, state)


## Host only, client-controlled players: remember the state after this tick's inputs for
## the smooth display on the client's input timeline (see _display).
func record_for_display() -> void:
	if timeline == null:
		return
	if _display == null:
		_display = RemoteInterpolator.new(0)
	var time_ms := timeline.seq_ms(last_input_seq)
	if time_ms <= _last_state_time:
		return
	timeline.observe_ms(time_ms, Time.get_ticks_msec())
	_last_state_time = time_ms
	_display.push(time_ms, {"position": position, "velocity": velocity, "active": true})


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if timeline:
		timeline.update(delta)
	if _interpolator:
		_apply_state(_interpolator.sample(timeline.render_time(now) if timeline else float(now)))
	if not visual_offset.is_zero_approx():
		visual_offset *= exp(-20.0 * delta)
		if visual_offset.length_squared() < 0.01:
			visual_offset = Vector2.ZERO
	if _display:
		var shown := _display.sample(timeline.render_time(now))
		var offset: Vector2 = (shown.position as Vector2) - position if not shown.is_empty() else Vector2.ZERO
		visual_offset = offset if visible and offset.length() < RemoteInterpolator.TELEPORT_DISTANCE else Vector2.ZERO
		queue_redraw()
		queue_redraw()
	if _name_label:
		_name_label.position = Vector2(-120, -BODY_SIZE.y / 2.0 - 54) + visual_offset
	if _damage_label:
		_update_damage_label()
	if _visual:
		_visual.position = visual_offset
		_visual.update_look(facing, InputFrame.aim_to_vector(aim), motor_state.on_floor, velocity, is_firing(),
				ability_active() and visible, reload_progress() if visible else -1.0)
	var blink_off := invulnerable and (Time.get_ticks_msec() / 100) % 2 == 0
	modulate.a = 0.35 if blink_off else 1.0


## True right after a shot (drives the shooting animation). The own player on a client
## shows it from the local fire button, so it reacts without waiting for the host.
func is_firing() -> bool:
	if Time.get_ticks_msec() - last_fire_ms < FIRING_VISUAL_MS:
		return true
	return _is_local_client() and Input.is_action_pressed("fire") and can_fire() and visible and not is_reloading()


## "37 %" above the name: white at 0 %, yellow at 50 %, red at 100 %. The text only changes
## when the whole percent changes.
func _update_damage_label() -> void:
	_damage_label.position = Vector2(-60, -BODY_SIZE.y / 2.0 - 86) + visual_offset
	var shown := roundi(damage)
	if shown == _shown_damage:
		return
	_shown_damage = shown
	_damage_label.text = "%d %%" % shown
	var t := shown / CombatRules.MAX_DAMAGE
	var yellow := Color(1.0, 0.82, 0.25)
	var color := Color.WHITE.lerp(yellow, t * 2.0) if t < 0.5 else yellow.lerp(Color(1.0, 0.25, 0.2), (t - 0.5) * 2.0)
	_damage_label.add_theme_color_override("font_color", color)


func _is_local_client() -> bool:
	return is_inside_tree() and multiplayer.has_multiplayer_peer() and not multiplayer.is_server() \
			and peer_id == multiplayer.get_unique_id()


func _apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	position = state.position
	velocity = state.velocity
	motor_state.on_floor = state.get("on_floor", motor_state.on_floor)
	if state.get("firing", false):
		last_fire_ms = Time.get_ticks_msec()
	set_active(state.active)
	facing = state.facing
	aim = state.aim
	lives = state.lives
	kills = state.get("kills", 0)
	deaths = state.get("deaths", 0)
	ability_cooldown = state.get("ability_cooldown", 0.0)
	# Clients only need "active or not" for drawing; the exact time stays on the host.
	ability_time_left = 1.0 if state.get("ability_active", false) else 0.0
	ammo = state.get("ammo", ammo)
	damage = state.get("damage", damage)
	var reloading: bool = state.get("reloading", false)
	if reloading and not is_reloading():
		reload_started_ms = Time.get_ticks_msec()
	var weapon := current_weapon()
	# Clients only show the reload; its exact timing stays on the host.
	reload_time_left = (weapon.reload_time if weapon else 1.0) if reloading else 0.0
	invulnerable = state.invulnerable
	queue_redraw()


func reset_to(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	motor_state = PlayerMotor.State.new()
	visual_offset = Vector2.ZERO
	set_collision_mask_value(PlayerMotor.ONE_WAY_LAYER, true)
	fire_cooldown = 0.0
	damage = 0.0
	refill_magazine()
	ability_time_left = 0.0
	invulnerable_time = 0.0
	invulnerable = false
	out_of_bounds_time = 0.0


## Inactive players are hidden and removed from physics (e.g. while waiting to respawn).
func set_active(active: bool) -> void:
	visible = active
	collision_layer = 4 if active else 0
	collision_mask = 7 if active else 0


func _draw() -> void:
	draw_set_transform(visual_offset)
	if _visual == null:  # placeholder look without a sprite sheet
		draw_rect(Rect2(-BODY_SIZE / 2.0, BODY_SIZE), SLOT_COLORS[slot % SLOT_COLORS.size()])
		var eye := Vector2(8.0 * facing, -BODY_SIZE.y / 4.0)
		draw_rect(Rect2(eye - Vector2(4, 4), Vector2(8, 8)), Color(0.1, 0.1, 0.12))
		draw_line(Vector2.ZERO, InputFrame.aim_to_vector(aim) * GUN_LENGTH, Color(0.15, 0.15, 0.18), 6.0)
	if ability_active() and _visual == null:  # placeholder look only; sprites have pixel-art effects
		draw_arc(Vector2.ZERO, BODY_SIZE.y * 0.75, 0.0, TAU, 32, Color(0.6, 0.85, 1.0, 0.8), 3.0)
