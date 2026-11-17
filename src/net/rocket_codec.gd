class_name RocketCodec
## Bounded host snapshots of every live homing rocket. Complete snapshots let a client
## remove a rocket even if its final flight update was lost (PLAN.md section S).
## Header: u32 host tick, u8 count. Each rocket: u32 id, s32 owner peer id,
## f32 x/y position, f32 x/y unit flight direction, f32 speed in px/s.

const HEADER_BYTES := 5
const ROCKET_BYTES := 28
const MAX_ROCKETS := 16
const MAX_PACKET_BYTES := HEADER_BYTES + MAX_ROCKETS * ROCKET_BYTES
const MAX_SPEED := 2000.0
const MAX_U32 := 0xFFFFFFFF
const MAX_PEER_ID := 0x7FFFFFFF
const MAX_F32 := 3.402823466e38


## Records use {id, owner_peer_id, position, direction, speed}. Invalid source data
## returns an empty packet rather than silently overflowing a field.
static func encode(tick: int, rockets: Array[Dictionary]) -> PackedByteArray:
	if tick < 0 or tick > MAX_U32 or rockets.size() > MAX_ROCKETS:
		return PackedByteArray()
	var ids: Dictionary[int, bool] = {}
	for record in rockets:
		if not _valid_record(record) or ids.has(record.id):
			return PackedByteArray()
		ids[record.id] = true
	var data := PackedByteArray()
	data.resize(HEADER_BYTES + rockets.size() * ROCKET_BYTES)
	data.encode_u32(0, tick)
	data.encode_u8(4, rockets.size())
	for i in rockets.size():
		var record := rockets[i]
		var offset := HEADER_BYTES + i * ROCKET_BYTES
		var at: Vector2 = record.position
		var direction: Vector2 = record.direction
		data.encode_u32(offset, record.id)
		data.encode_s32(offset + 4, record.owner_peer_id)
		data.encode_float(offset + 8, at.x)
		data.encode_float(offset + 12, at.y)
		data.encode_float(offset + 16, direction.x)
		data.encode_float(offset + 20, direction.y)
		data.encode_float(offset + 24, record.speed)
	return data


## {tick, rockets: Array[Dictionary]}, including a valid empty live set; {} = rejected.
static func decode(data: PackedByteArray) -> Dictionary:
	if data.size() < HEADER_BYTES or data.size() > MAX_PACKET_BYTES:
		return {}
	var count := data.decode_u8(4)
	if count > MAX_ROCKETS or data.size() != HEADER_BYTES + count * ROCKET_BYTES:
		return {}
	var rockets: Array[Dictionary] = []
	var ids: Dictionary[int, bool] = {}
	for i in count:
		var offset := HEADER_BYTES + i * ROCKET_BYTES
		var record := {
			"id": data.decode_u32(offset),
			"owner_peer_id": data.decode_s32(offset + 4),
			"position": Vector2(data.decode_float(offset + 8), data.decode_float(offset + 12)),
			"direction": Vector2(data.decode_float(offset + 16), data.decode_float(offset + 20)),
			"speed": data.decode_float(offset + 24),
		}
		if not _valid_record(record) or ids.has(record.id):
			return {}
		ids[record.id] = true
		rockets.append(record)
	return {"tick": data.decode_u32(0), "rockets": rockets}


static func _valid_record(record: Dictionary) -> bool:
	var id: Variant = record.get("id")
	var owner: Variant = record.get("owner_peer_id")
	var at: Variant = record.get("position")
	var direction: Variant = record.get("direction")
	var speed: Variant = record.get("speed")
	if typeof(id) != TYPE_INT or id <= 0 or id > MAX_U32 \
			or typeof(owner) != TYPE_INT or owner <= 0 or owner > MAX_PEER_ID \
			or typeof(at) != TYPE_VECTOR2 or typeof(direction) != TYPE_VECTOR2 \
			or (typeof(speed) != TYPE_FLOAT and typeof(speed) != TYPE_INT):
		return false
	var position: Vector2 = at
	var heading: Vector2 = direction
	return position.is_finite() and absf(position.x) <= MAX_F32 and absf(position.y) <= MAX_F32 \
			and heading.is_finite() and absf(heading.length_squared() - 1.0) <= 0.01 \
			and is_finite(float(speed)) and speed >= 0.0 and speed <= MAX_SPEED
