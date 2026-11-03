class_name Player
extends CharacterBody2D
## A character in the arena. On the authority (host or offline practice) it is moved by
## PlayerMotor from inputs; on clients it only displays interpolated host snapshots.
## Visuals are placeholders until pixel-art sprites exist (PLAN.md section Q).

const BODY_SIZE := Vector2(36, 56)
const GUN_LENGTH := 30.0
## Placeholder colors so players can be told apart before characters have sprites.
const SLOT_COLORS: Array[Color] = [Color(1, 0.72, 0.2), Color(0.35, 0.75, 1), Color(0.55, 0.9, 0.4), Color(1, 0.45, 0.6)]

var character: CharacterData
var motor_state := PlayerMotor.State.new()
var peer_id := 1
var slot := 0
var facing := 1
var aim := 0
## Newest input applied on the host; sent in snapshots for client prediction (M4).
var last_input_seq := 0
## Authority: seconds until the current weapon may fire again.
var fire_cooldown := 0.0

## Only on clients: smooths host snapshots.
var _interpolator: RemoteInterpolator


func setup(data: CharacterData, player_slot: int, player_peer_id: int, display_name: String) -> void:
	character = data
	slot = player_slot
	peer_id = player_peer_id
	var name_label := Label.new()
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(160, 24)
	name_label.position = Vector2(-80, -BODY_SIZE.y / 2.0 - 30)
	add_child(name_label)


## Authority only: one physics tick of movement from `input`.
func simulate(input: InputFrame, delta: float) -> void:
	PlayerMotor.step(self, input, motor_state, character, delta)
	aim = input.aim
	last_input_seq = input.seq
	facing = motor_state.facing
	queue_redraw()


func current_weapon() -> WeaponData:
	return character.weapons[0] if character and not character.weapons.is_empty() else null


func snapshot_state() -> Dictionary:
	return {"slot": slot, "position": position, "velocity": velocity, "facing": facing,
			"active": visible, "aim": aim, "last_seq": last_input_seq}


## Client only: queue a host snapshot for smooth display.
func receive_state(state: Dictionary, time_ms: int) -> void:
	if _interpolator == null:
		var own := peer_id == multiplayer.get_unique_id()
		_interpolator = RemoteInterpolator.new(RemoteInterpolator.OWN_PLAYER_DELAY_MS if own else RemoteInterpolator.INTERPOLATION_DELAY_MS)
	_interpolator.push(time_ms, state)


func _process(_delta: float) -> void:
	if _interpolator == null:
		return
	var state := _interpolator.sample(Time.get_ticks_msec())
	if state.is_empty():
		return
	position = state.position
	visible = state.active
	facing = state.facing
	aim = state.aim
	queue_redraw()


func reset_to(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	motor_state = PlayerMotor.State.new()
	fire_cooldown = 0.0


## Inactive players are hidden and removed from physics (e.g. while waiting to respawn).
func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _draw() -> void:
	draw_rect(Rect2(-BODY_SIZE / 2.0, BODY_SIZE), SLOT_COLORS[slot % SLOT_COLORS.size()])
	var eye := Vector2(8.0 * facing, -BODY_SIZE.y / 4.0)
	draw_rect(Rect2(eye - Vector2(4, 4), Vector2(8, 8)), Color(0.1, 0.1, 0.12))
	draw_line(Vector2.ZERO, InputFrame.aim_to_vector(aim) * GUN_LENGTH, Color(0.15, 0.15, 0.18), 6.0)
