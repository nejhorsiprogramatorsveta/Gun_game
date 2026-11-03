class_name NetCodec
## Binary layout of the frequent match messages: client inputs (60 Hz) and host snapshots
## (30 Hz). Fixed layouts keep packets tiny and make validation a simple size check
## (PLAN.md D.3 and section S). Anything with an unexpected size is ignored.

## Input packet = u16 newest seq + INPUT_HISTORY frames (newest first, seq counts down).
## Repeating the last frames lets the host recover from a lost packet.
const INPUT_HISTORY := 3
const INPUT_FRAME_BYTES := 4  # s8 move_x, u8 buttons, u16 aim
const INPUT_PACKET_BYTES := 2 + INPUT_HISTORY * INPUT_FRAME_BYTES

const SNAPSHOT_HEADER_BYTES := 6  # u32 tick, u8 player count, u8 countdown seconds left
## u8 slot, f32 x, f32 y, s16 vx, s16 vy, u8 flags, u16 aim, u16 last input seq, u8 lives
const SNAPSHOT_PLAYER_BYTES := 19
const MAX_SNAPSHOT_PLAYERS := 4

const FLAG_FACING_RIGHT := 1
const FLAG_ACTIVE := 2
const FLAG_INVULNERABLE := 4


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


## states: [{slot, position, velocity, facing, active, invulnerable, aim, last_seq, lives}],
## see Player.snapshot_state(). countdown = whole seconds left before the match starts.
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
				| (FLAG_INVULNERABLE if state.invulnerable else 0)
		data.encode_u8(offset, state.slot)
		data.encode_float(offset + 1, position.x)
		data.encode_float(offset + 5, position.y)
		data.encode_s16(offset + 9, clampi(roundi(velocity.x), -32768, 32767))
		data.encode_s16(offset + 11, clampi(roundi(velocity.y), -32768, 32767))
		data.encode_u8(offset + 13, flags)
		data.encode_u16(offset + 14, state.aim)
		data.encode_u16(offset + 16, state.last_seq)
		data.encode_u8(offset + 18, clampi(state.lives, 0, 255))
	return data


## Returns {tick, countdown, states: Array[Dictionary]} or {} for a malformed packet.
static func decode_snapshot(data: PackedByteArray) -> Dictionary:
	if data.size() < SNAPSHOT_HEADER_BYTES:
		return {}
	var count := data.decode_u8(4)
	if count > MAX_SNAPSHOT_PLAYERS or data.size() != SNAPSHOT_HEADER_BYTES + count * SNAPSHOT_PLAYER_BYTES:
		return {}
	var states: Array[Dictionary] = []
	for i in count:
		var offset := SNAPSHOT_HEADER_BYTES + i * SNAPSHOT_PLAYER_BYTES
		var flags := data.decode_u8(offset + 13)
		states.append({
			"slot": data.decode_u8(offset),
			"position": Vector2(data.decode_float(offset + 1), data.decode_float(offset + 5)),
			"velocity": Vector2(data.decode_s16(offset + 9), data.decode_s16(offset + 11)),
			"facing": 1 if flags & FLAG_FACING_RIGHT else -1,
			"active": flags & FLAG_ACTIVE != 0,
			"invulnerable": flags & FLAG_INVULNERABLE != 0,
			"aim": data.decode_u16(offset + 14),
			"last_seq": data.decode_u16(offset + 16),
			"lives": data.decode_u8(offset + 18),
		})
	return {"tick": data.decode_u32(0), "countdown": data.decode_u8(5), "states": states}


## True if u16 sequence number `a` is newer than `b` (handles wrap-around at 65535).
static func seq_newer(a: int, b: int) -> bool:
	return a != b and ((a - b) & 0xFFFF) < 0x8000
