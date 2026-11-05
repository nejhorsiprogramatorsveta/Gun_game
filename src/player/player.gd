class_name Player
extends CharacterBody2D
## A character in the arena. On the authority (host or offline practice) it is moved by
## PlayerMotor from inputs; clients predict themselves and interpolate other players.
## Visuals are placeholders until pixel-art sprites exist (PLAN.md section Q).

const BODY_SIZE := Vector2(36, 56)
const GUN_LENGTH := 30.0
## Placeholder colors so players can be told apart before characters have sprites.
const SLOT_COLORS: Array[Color] = [Color(1, 0.72, 0.2), Color(0.35, 0.75, 1), Color(0.55, 0.9, 0.4), Color(1, 0.45, 0.6)]

var character: CharacterData
var motor_state := PlayerMotor.State.new()
var peer_id := 1
var slot := 0
var display_name := ""
## Lives left in a network match (0 = eliminated). Set by the authority, shown in the HUD.
var lives := 0
var kills := 0
var deaths := 0
## True right after a respawn: hits do not push the player (shown by blinking).
var invulnerable := false
var facing := 1
var aim := 0
## Newest input applied on the host; sent in snapshots for client prediction (M4).
var last_input_seq := 0
## Authority: seconds until the current weapon may fire again.
var fire_cooldown := 0.0
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

## Only for remote players on clients.
var _interpolator: RemoteInterpolator
var _name_label: Label


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
	name_label.position = Vector2(-120, -BODY_SIZE.y / 2.0 - 42)
	add_child(name_label)
	_name_label = name_label


## One shared movement tick, also used during client prediction and replay.
func simulate(input: InputFrame, delta: float) -> void:
	tick_ability(input, delta)
	var slow := effects.slow_for(self) if effects else Vector2.ONE
	motor_state.speed_scale = slow.x
	motor_state.jump_scale = slow.y
	PlayerMotor.step(self, input, motor_state, character, delta)
	aim = input.aim
	last_input_seq = input.seq
	facing = motor_state.facing
	queue_redraw()


func current_weapon() -> WeaponData:
	return character.weapon if character else null


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
			"ability_cooldown": ability_cooldown, "ability_active": ability_active(),
			"dash_time_left": motor_state.dash_time_left, "dash_direction": motor_state.dash_direction}


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
	motor_state.dash_time_left = state.get("dash_time_left", 0.0)
	motor_state.dash_direction = state.get("dash_direction", 1)
	set_collision_mask_value(PlayerMotor.ONE_WAY_LAYER, visible and motor_state.drop_timer <= 0.0)


## Client only: queue a host snapshot for smooth display.
func receive_state(state: Dictionary, time_ms: int) -> void:
	if _interpolator == null:
		_interpolator = RemoteInterpolator.new()
	_interpolator.push(time_ms, state)


func _process(delta: float) -> void:
	if _interpolator:
		_apply_state(_interpolator.sample(Time.get_ticks_msec()))
	if not visual_offset.is_zero_approx():
		visual_offset *= exp(-20.0 * delta)
		if visual_offset.length_squared() < 0.01:
			visual_offset = Vector2.ZERO
		queue_redraw()
	if _name_label:
		_name_label.position = Vector2(-120, -BODY_SIZE.y / 2.0 - 42) + visual_offset
	var blink_off := invulnerable and (Time.get_ticks_msec() / 100) % 2 == 0
	modulate.a = 0.35 if blink_off else 1.0


func _apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	position = state.position
	set_active(state.active)
	facing = state.facing
	aim = state.aim
	lives = state.lives
	kills = state.get("kills", 0)
	deaths = state.get("deaths", 0)
	ability_cooldown = state.get("ability_cooldown", 0.0)
	# Clients only need "active or not" for drawing; the exact time stays on the host.
	ability_time_left = 1.0 if state.get("ability_active", false) else 0.0
	invulnerable = state.invulnerable
	queue_redraw()


func reset_to(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	motor_state = PlayerMotor.State.new()
	visual_offset = Vector2.ZERO
	set_collision_mask_value(PlayerMotor.ONE_WAY_LAYER, true)
	fire_cooldown = 0.0
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
	draw_rect(Rect2(-BODY_SIZE / 2.0, BODY_SIZE), SLOT_COLORS[slot % SLOT_COLORS.size()])
	var eye := Vector2(8.0 * facing, -BODY_SIZE.y / 4.0)
	draw_rect(Rect2(eye - Vector2(4, 4), Vector2(8, 8)), Color(0.1, 0.1, 0.12))
	draw_line(Vector2.ZERO, InputFrame.aim_to_vector(aim) * GUN_LENGTH, Color(0.15, 0.15, 0.18), 6.0)
	if ability_active():
		draw_arc(Vector2.ZERO, BODY_SIZE.y * 0.75, 0.0, TAU, 32, Color(0.6, 0.85, 1.0, 0.8), 3.0)
