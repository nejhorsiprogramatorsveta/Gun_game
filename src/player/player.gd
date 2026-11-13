class_name Player
extends CharacterBody2D
## A character in the arena. On the authority (host or offline practice) it is moved by
## PlayerMotor from inputs; clients predict themselves and play back other players
## (RemoteView). Weapon state lives in PlayerWeapon, the name/percent labels in PlayerLabels.

const BODY_SIZE := Vector2(36, 56)
const GUN_LENGTH := 30.0
## How long the shooting animation plays after a shot.
const FIRING_VISUAL_MS := 150
## How fast a prediction correction of the shown position fades (1/s); a correction caused
## by a hit the client could not predict (shot from close range) glides in more slowly, so
## it reads as being thrown rather than as a jerk.
const VISUAL_SMOOTHING := 20.0
const HIT_SMOOTHING := 8.0
## Placeholder colors so players can be told apart before characters have sprites.
const SLOT_COLORS: Array[Color] = [Color(1, 0.72, 0.2), Color(0.35, 0.75, 1), Color(0.55, 0.9, 0.4), Color(1, 0.45, 0.6),
		Color(0.72, 0.5, 1), Color(0.95, 0.95, 0.95)]

var character: CharacterData
var motor_state := PlayerMotor.State.new()
var peer_id := 1
var slot := 0
var display_name := ""
## Skin choice (CharacterData.SKIN_* bits), only for drawing.
var skins := 0
## Teams.NONE in free-for-all; teammates do not hurt each other (team modes).
var team := Teams.NONE
## Lives left in a network match (0 = eliminated). Set by the authority, shown in the HUD.
var lives := 0
## Damage percent 0-100 (host decides, shown above the character): more = more knockback.
var damage := 0.0
var kills := 0
var deaths := 0
## True right after a respawn: hits do not push the player (shown by blinking).
var invulnerable := false
var facing := 1
var aim := 0
## Newest input applied on the host; sent in snapshots for client prediction (M4).
var last_input_seq := 0
## Fire cooldown, magazine and reload; simulated by the host and the own client's prediction.
var gun := PlayerWeapon.new(self)
## True on the tick a shot was fired (the host then spawns the projectiles).
var fired_this_tick := false
## Ability runtime state (authority decides; clients receive it in snapshots).
var ability_cooldown := 0.0
var ability_time_left := 0.0
## True on the tick the ability was activated (host applies effects on others).
var ability_started := false
## Physics ticks in a row spent in an opponent's gas (AreaEffects.blow); in snapshots.
var gas_ticks := 0
## Gas and platforms of the match (set by MatchController); null in unit tests.
var effects: AreaEffects
## The match's arena (moving platforms carry the player, Arena.prepare); null in unit tests.
var arena: Arena
## Host tick of the last simulation (Arena.prepare); -1 after a respawn. Local only: the
## client's prediction sets it from the snapshot before replaying.
var world_tick := -1
## Authority: seconds of respawn protection left.
var invulnerable_time := 0.0
## Authority: how long the player has been outside the arena (see out_of_bounds_grace).
var out_of_bounds_time := 0.0
## Render correction only; collisions always use the corrected simulation position.
var visual_offset := Vector2.ZERO
var visual_smoothing := VISUAL_SMOOTHING
## Players controlled on another computer: smooth playback (set by MatchController for
## remote players on clients and client-controlled players on the host); null otherwise.
var remote_view: RemoteView

var _labels: PlayerLabels
## Pixel-art sprites (null = placeholder rectangle, e.g. in unit tests).
var _visual: PlayerVisual


func setup(data: CharacterData, player_slot: int, player_peer_id: int, player_name: String, player_skins: int = 0) -> void:
	character = data
	skins = player_skins
	slot = player_slot
	peer_id = player_peer_id
	display_name = player_name
	_labels = PlayerLabels.new()
	_labels.setup(player_name, SLOT_COLORS[slot % SLOT_COLORS.size()].lightened(0.3), BODY_SIZE.y)
	add_child(_labels)
	gun.refill()
	if character and character.sprite_sheet:
		_visual = PlayerVisual.new()
		_visual.setup(character, skins)
		add_child(_visual)


## Team modes: the name above the character takes the team color.
func set_team(new_team: int) -> void:
	team = new_team
	if _labels and Teams.is_valid(team):
		_labels.set_name_color(Teams.color(team).lightened(0.2))


## One shared movement tick, also used during client prediction and replay.
func simulate(input: InputFrame, delta: float) -> void:
	if arena and input.tick >= 0:
		arena.prepare(self, input.tick)  # moving platforms to this tick, carry the player
	tick_ability(input, delta)
	if effects:
		effects.blow(self)  # an opponent's gas blows the player away before moving
	PlayerMotor.step(self, input, motor_state, character, delta)
	fired_this_tick = tick_weapon(input, delta)
	aim = input.aim
	last_input_seq = input.seq
	facing = motor_state.facing
	queue_redraw()


func current_weapon() -> WeaponData:
	return character.weapon if character else null


## Shared by the host and the own client's prediction: cooldown, reload (also manual), ammo
## and the shooter's recoil. Returns true when a shot is fired this tick.
func tick_weapon(input: InputFrame, delta: float) -> bool:
	if not gun.tick(input.is_held(InputFrame.FIRE) and can_fire(), input.is_held(InputFrame.RELOAD), delta):
		return false
	velocity += CombatRules.recoil(InputFrame.aim_to_vector(input.aim), current_weapon())
	return true


## Cooldowns and activation on press (not while held); shared by host and prediction.
## The cooldown counts whole physics ticks (snapshots carry it in ticks), so the host and
## the client's replay agree on the exact tick it is ready: a press predicted on that tick
## is never refused by the host (the teleport used to snap back now and then).
func tick_ability(input: InputFrame, delta: float) -> void:
	ability_cooldown = maxf(roundf(ability_cooldown / delta) - 1.0, 0.0) * delta if delta > 0.0 else ability_cooldown
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
			"boost_time_left": motor_state.boost_time_left, "ammo": gun.ammo, "reloading": gun.is_reloading(),
			"fire_cooldown": gun.fire_cooldown, "reload_time_left": gun.reload_time_left, "damage": damage,
			"gas_ticks": gas_ticks}


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
	gun.restore(state)
	gas_ticks = state.get("gas_ticks", 0)
	set_collision_mask_value(PlayerMotor.ONE_WAY_LAYER, visible and motor_state.drop_timer <= 0.0)


## Client only: queue a host snapshot of this remote player for display (RemoteView).
func receive_state(state: Dictionary, host_time_ms: float) -> void:
	if remote_view == null:
		remote_view = RemoteView.new()
	remote_view.receive(state, host_time_ms, peer_id == 1)


## Host only, client-controlled players: remember the state after this tick's inputs for
## the smooth display on the client's input timeline.
func record_for_display() -> void:
	if remote_view:
		remote_view.record(last_input_seq, position, velocity)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if remote_view:
		remote_view.update(delta)
		_apply_state(remote_view.sample_state(now))
	if not visual_offset.is_zero_approx():
		visual_offset *= exp(-visual_smoothing * delta)
		if visual_offset.length_squared() < 0.01:
			visual_offset = Vector2.ZERO
			visual_smoothing = VISUAL_SMOOTHING
	if remote_view and remote_view.has_display():
		visual_offset = remote_view.display_offset(now, position) if visible else Vector2.ZERO
		queue_redraw()
	if _labels:
		_labels.position = visual_offset
		_labels.show_damage(damage)
	if _visual:
		_visual.position = visual_offset
		_visual.update_look(facing, InputFrame.aim_to_vector(aim), motor_state.on_floor, velocity, is_firing(),
				ability_active() and visible, gun.reload_progress() if visible else -1.0)
	var blink_off := invulnerable and (Time.get_ticks_msec() / 100) % 2 == 0
	modulate.a = 0.35 if blink_off else 1.0


## True right after a shot (drives the shooting animation). The own player on a client
## shows it from the local fire button, so it reacts without waiting for the host.
func is_firing() -> bool:
	if Time.get_ticks_msec() - gun.last_fire_ms < FIRING_VISUAL_MS:
		return true
	return _is_local_client() and Input.is_action_pressed("fire") and can_fire() and visible and not gun.is_reloading()


func _is_local_client() -> bool:
	return is_inside_tree() and multiplayer.has_multiplayer_peer() and not multiplayer.is_server() \
			and peer_id == multiplayer.get_unique_id()


func _apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	position = state.position
	velocity = state.velocity
	motor_state.on_floor = state.get("on_floor", motor_state.on_floor)
	set_active(state.active)
	facing = state.facing
	aim = state.aim
	lives = state.lives
	kills = state.get("kills", 0)
	deaths = state.get("deaths", 0)
	ability_cooldown = state.get("ability_cooldown", 0.0)
	# Clients only need "active or not" for drawing; the exact time stays on the host.
	ability_time_left = 1.0 if state.get("ability_active", false) else 0.0
	damage = state.get("damage", damage)
	gun.show_state(state)
	invulnerable = state.invulnerable
	queue_redraw()


func reset_to(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	motor_state = PlayerMotor.State.new()
	visual_offset = Vector2.ZERO
	set_collision_mask_value(PlayerMotor.ONE_WAY_LAYER, true)
	gun.fire_cooldown = 0.0
	damage = 0.0
	gun.refill()
	ability_time_left = 0.0
	ability_cooldown = 0.0  # after a death the ability is ready again
	gas_ticks = 0
	world_tick = -1
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
