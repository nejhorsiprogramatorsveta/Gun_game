class_name NetCodec
## Binary layout of the frequent match messages: client inputs (60 Hz) and host snapshots
## (30 Hz). Fixed layouts keep packets tiny and make validation a simple size check
## (PLAN.md D.3 and section S). Anything with an unexpected size is ignored.

## Input packet = u16 newest seq + INPUT_HISTORY frames (newest first, seq counts down).
## Repeating the last frames lets the host recover from a lost packet.
const INPUT_HISTORY := 3
const INPUT_FRAME_BYTES := 4  # s8 move_x, u8 buttons, u16 aim
const INPUT_PACKET_BYTES := 2 + INPUT_HISTORY * INPUT_FRAME_BYTES

const SNAPSHOT_HEADER_BYTES := 6  # u32 tick, u8 player count, u8 countdown tenths of a second left
## u8 slot, f32 x, f32 y, s16 vx, s16 vy, u8 flags, u16 aim, u16 last input seq, u8 lives,
## u8 previous buttons, u8 jumps left, f32 jump buffer timer, f32 drop timer, u16 kills, u16 deaths,
## u16 ability cooldown in physics ticks (1/60 s), f32 movement ability (jetpack) time left,
## u8 rounds left in the magazine, u16 fire cooldown and u16 reload time left (both in
## WEAPON_TIMER_UNITS per second, exact enough that the client replays shots and recoil on
## the same ticks as the host), u8 damage percent.
const SNAPSHOT_PLAYER_BYTES := 45
const WEAPON_TIMER_UNITS := 10000.0
const MAX_SNAPSHOT_PLAYERS := 4
const COOLDOWN_TICKS_PER_SECOND := 60.0

const FLAG_FACING_RIGHT := 1
const FLAG_ACTIVE := 2
const FLAG_INVULNERABLE := 4
const FLAG_ON_FLOOR := 8
## The player shot within Player.FIRING_VISUAL_MS (shooting animation for everyone).
const FLAG_FIRING := 16
const FLAG_ABILITY_ACTIVE := 32
## The weapon is reloading (animation for everyone, "reloading" in the own HUD).
const FLAG_RELOADING := 64


## frames[0] is the newest; older frames must have seq = newest.seq - index.
static func encode_input(frames: Array[InputFrame]) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(INPUT_PACKET_BYTES)
	data.encode_u16(0, frames[0].seq)
	for i in INPUT_HISTORY:
		var frame := frames[mini(i, frames.size() - 1)]
		var offset := 2 + i * INPUT_FRAME_BYTES
		data.encode_s8(offset, frame.move_x)
		data.encode_u8(offset + 1, frame.buttons)
		data.encode_u16(offset + 2, frame.aim)
	return data


## Returns the frames newest first, or an empty array for a malformed packet.
static func decode_input(data: PackedByteArray) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	if data.size() != INPUT_PACKET_BYTES:
		return frames
	var newest_seq := data.decode_u16(0)
	for i in INPUT_HISTORY:
		var offset := 2 + i * INPUT_FRAME_BYTES
		# create() clamps and masks everything, so odd values cannot reach the simulation.
		frames.append(InputFrame.create(data.decode_s8(offset), data.decode_u8(offset + 1),
				data.decode_u16(offset + 2), newest_seq - i))
	return frames


## Player.snapshot_state() includes the movement memory needed to replay pending inputs.
## countdown = tenths of a second left before the match starts (max 25.5 s).
static func encode_snapshot(tick: int, countdown: int, states: Array[Dictionary]) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(SNAPSHOT_HEADER_BYTES + states.size() * SNAPSHOT_PLAYER_BYTES)
	data.encode_u32(0, tick)
	data.encode_u8(4, states.size())
	data.encode_u8(5, clampi(countdown, 0, 255))
	for i in states.size():
		var state := states[i]
		var offset := SNAPSHOT_HEADER_BYTES + i * SNAPSHOT_PLAYER_BYTES
		var position: Vector2 = state.position
		var velocity: Vector2 = state.velocity
		var flags := (FLAG_FACING_RIGHT if state.facing > 0 else 0) | (FLAG_ACTIVE if state.active else 0) \
				| (FLAG_INVULNERABLE if state.invulnerable else 0) | (FLAG_ON_FLOOR if state.get("on_floor", false) else 0) \
				| (FLAG_ABILITY_ACTIVE if state.get("ability_active", false) else 0) \
				| (FLAG_FIRING if state.get("firing", false) else 0) \
				| (FLAG_RELOADING if state.get("reloading", false) else 0)
		data.encode_u8(offset, state.slot)
		data.encode_float(offset + 1, position.x)
		data.encode_float(offset + 5, position.y)
		data.encode_s16(offset + 9, clampi(roundi(velocity.x), -32768, 32767))
		data.encode_s16(offset + 11, clampi(roundi(velocity.y), -32768, 32767))
		data.encode_u8(offset + 13, flags)
		data.encode_u16(offset + 14, state.aim)
		data.encode_u16(offset + 16, state.last_seq)
		data.encode_u8(offset + 18, clampi(state.lives, 0, 255))
		data.encode_u8(offset + 19, int(state.get("prev_buttons", 0)) & InputFrame.ALL_BUTTONS)
		data.encode_u8(offset + 20, clampi(state.get("jumps_left", 0), 0, 255))
		data.encode_float(offset + 21, state.get("jump_buffer_timer", 0.0))
		data.encode_float(offset + 25, state.get("drop_timer", 0.0))
		data.encode_u16(offset + 29, clampi(state.get("kills", 0), 0, 65535))
		data.encode_u16(offset + 31, clampi(state.get("deaths", 0), 0, 65535))
		data.encode_u16(offset + 33, clampi(_ticks_up(float(state.get("ability_cooldown", 0.0))), 0, 65535))
		data.encode_float(offset + 35, state.get("boost_time_left", 0.0))
		data.encode_u8(offset + 39, clampi(state.get("ammo", 0), 0, 255))
		data.encode_u16(offset + 40, _timer_units(state.get("fire_cooldown", 0.0)))
		data.encode_u16(offset + 42, _timer_units(state.get("reload_time_left", 0.0)))
		data.encode_u8(offset + 44, clampi(roundi(float(state.get("damage", 0.0))), 0, int(CombatRules.MAX_DAMAGE)))
	return data


## Returns {tick, countdown, states: Array[Dictionary]} or {} for a malformed packet.
static func decode_snapshot(data: PackedByteArray) -> Dictionary:
	if data.size() < SNAPSHOT_HEADER_BYTES:
		return {}
	var count := data.decode_u8(4)
	if count > MAX_SNAPSHOT_PLAYERS or data.size() != SNAPSHOT_HEADER_BYTES + count * SNAPSHOT_PLAYER_BYTES:
		return {}
	var states: Array[Dictionary] = []
	var slots: Dictionary[int, bool] = {}
	for i in count:
		var offset := SNAPSHOT_HEADER_BYTES + i * SNAPSHOT_PLAYER_BYTES
		var flags := data.decode_u8(offset + 13)
		var slot := data.decode_u8(offset)
		var position := Vector2(data.decode_float(offset + 1), data.decode_float(offset + 5))
		var jump_buffer_timer := data.decode_float(offset + 21)
		var drop_timer := data.decode_float(offset + 25)
		var boost_time_left := data.decode_float(offset + 35)
		if slot >= MAX_SNAPSHOT_PLAYERS or slots.has(slot) or not position.is_finite() \
				or not is_finite(jump_buffer_timer) or not is_finite(drop_timer) \
				or jump_buffer_timer < 0.0 or drop_timer < 0.0 or not is_finite(boost_time_left) \
				or boost_time_left < 0.0 or boost_time_left > 2.0:
			return {}
		slots[slot] = true
		states.append({
			"slot": slot,
			"position": position,
			"velocity": Vector2(data.decode_s16(offset + 9), data.decode_s16(offset + 11)),
			"facing": 1 if flags & FLAG_FACING_RIGHT else -1,
			"active": flags & FLAG_ACTIVE != 0,
			"invulnerable": flags & FLAG_INVULNERABLE != 0,
			"on_floor": flags & FLAG_ON_FLOOR != 0,
			"aim": data.decode_u16(offset + 14),
			"last_seq": data.decode_u16(offset + 16),
			"lives": data.decode_u8(offset + 18),
			"prev_buttons": data.decode_u8(offset + 19) & InputFrame.ALL_BUTTONS,
			"jumps_left": data.decode_u8(offset + 20),
			"jump_buffer_timer": jump_buffer_timer,
			"drop_timer": drop_timer,
			"kills": data.decode_u16(offset + 29),
			"deaths": data.decode_u16(offset + 31),
			"ability_cooldown": data.decode_u16(offset + 33) / COOLDOWN_TICKS_PER_SECOND,
			"boost_time_left": boost_time_left,
			"ability_active": flags & FLAG_ABILITY_ACTIVE != 0,
			"firing": flags & FLAG_FIRING != 0,
			"reloading": flags & FLAG_RELOADING != 0,
			"ammo": data.decode_u8(offset + 39),
			"fire_cooldown": data.decode_u16(offset + 40) / WEAPON_TIMER_UNITS,
			"reload_time_left": data.decode_u16(offset + 42) / WEAPON_TIMER_UNITS,
			"damage": float(mini(data.decode_u8(offset + 44), int(CombatRules.MAX_DAMAGE))),
		})
	return {"tick": data.decode_u32(0), "countdown": data.decode_u8(5), "states": states}


## True if u16 sequence number `a` is newer than `b` (handles wrap-around at 65535).
static func seq_newer(a: int, b: int) -> bool:
	return a != b and ((a - b) & 0xFFFF) < 0x8000


static func _timer_units(seconds: Variant) -> int:
	var value := float(seconds)
	return clampi(roundi(value * WEAPON_TIMER_UNITS), 0, 65535) if is_finite(value) else 0


## Cooldown seconds -> whole physics ticks, rounded up so "ready" never comes too early.
static func _ticks_up(seconds: float) -> int:
	return ceili(seconds * COOLDOWN_TICKS_PER_SECOND - 0.001)
