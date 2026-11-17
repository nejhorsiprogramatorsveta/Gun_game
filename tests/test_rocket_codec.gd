extends TestCase
## Rocket packets are a complete, bounded host-owned live set; malformed packets must
## never create display objects or erase the client's valid live set.


func _record(id: int = 1) -> Dictionary:
	return {"id": id, "owner_peer_id": 37, "position": Vector2(-142.5, 612.25),
			"direction": Vector2(0.6, -0.8), "speed": 420.0}


func test_roundtrip_keeps_the_live_set_and_tick() -> void:
	var encoded := RocketCodec.encode(654321, [_record(1), _record(4294967295)] as Array[Dictionary])
	check_eq(encoded.size(), RocketCodec.HEADER_BYTES + 2 * RocketCodec.ROCKET_BYTES, "fixed compact layout")
	var decoded := RocketCodec.decode(encoded)
	check_eq(decoded.tick, 654321, "host tick kept")
	check_eq(decoded.rockets.size(), 2, "both rockets kept")
	for i in 2:
		var expected := _record(1 if i == 0 else 4294967295)
		var actual: Dictionary = decoded.rockets[i]
		check_eq([actual.id, actual.owner_peer_id, actual.position, actual.speed],
				[expected.id, expected.owner_peer_id, expected.position, expected.speed], "rocket identity and motion kept")
		check(actual.direction.distance_to(expected.direction) < 0.00001, "unit direction survives float encoding")
	var empty := RocketCodec.decode(RocketCodec.encode(900, [] as Array[Dictionary]))
	check_eq(empty, {"tick": 900, "rockets": []}, "empty live set is valid and removes old rockets")


func test_packet_sizes_and_counts_are_bounded() -> void:
	var records: Array[Dictionary] = []
	for i in RocketCodec.MAX_ROCKETS:
		records.append(_record(i + 1))
	var maximum := RocketCodec.encode(1, records)
	check_eq(maximum.size(), RocketCodec.MAX_PACKET_BYTES, "max sixteen rockets")
	check_eq(RocketCodec.decode(maximum).rockets.size(), RocketCodec.MAX_ROCKETS, "full packet accepted")
	records.append(_record(17))
	check(RocketCodec.encode(1, records).is_empty(), "oversized source set rejected")
	for size in [0, 1, 4, RocketCodec.HEADER_BYTES + 1, RocketCodec.MAX_PACKET_BYTES + 1]:
		var bad := PackedByteArray()
		bad.resize(size)
		check(RocketCodec.decode(bad).is_empty(), "unexpected size %d rejected" % size)
	var extra := RocketCodec.encode(1, [_record()] as Array[Dictionary])
	extra.append(0)
	check(RocketCodec.decode(extra).is_empty(), "trailing bytes rejected")
	maximum.encode_u8(4, RocketCodec.MAX_ROCKETS + 1)
	check(RocketCodec.decode(maximum).is_empty(), "count over capacity rejected")


func test_invalid_identity_and_duplicate_ids_are_rejected() -> void:
	var valid := RocketCodec.encode(5, [_record(1), _record(2)] as Array[Dictionary])
	for id in [0, -1, RocketCodec.MAX_U32 + 1]:
		var bad := _record(id)
		check(RocketCodec.encode(5, [bad] as Array[Dictionary]).is_empty(), "invalid source id %d rejected" % id)
	for owner in [0, -5, RocketCodec.MAX_PEER_ID + 1]:
		var bad := _record()
		bad.owner_peer_id = owner
		check(RocketCodec.encode(5, [bad] as Array[Dictionary]).is_empty(), "invalid source owner rejected")
	for tick in [-1, RocketCodec.MAX_U32 + 1]:
		check(RocketCodec.encode(tick, [] as Array[Dictionary]).is_empty(), "host tick cannot overflow")
	check(RocketCodec.encode(1, [_record(), _record()] as Array[Dictionary]).is_empty(), "duplicate source ids rejected")
	var duplicate := valid.duplicate()
	duplicate.encode_u32(RocketCodec.HEADER_BYTES + RocketCodec.ROCKET_BYTES, 1)
	check(RocketCodec.decode(duplicate).is_empty(), "duplicate wire ids rejected")
	var zero_id := valid.duplicate()
	zero_id.encode_u32(RocketCodec.HEADER_BYTES, 0)
	check(RocketCodec.decode(zero_id).is_empty(), "zero wire id rejected")
	for owner in [0, -1]:
		var bad_owner := valid.duplicate()
		bad_owner.encode_s32(RocketCodec.HEADER_BYTES + 4, owner)
		check(RocketCodec.decode(bad_owner).is_empty(), "invalid wire owner rejected")


func test_nonfinite_or_impossible_motion_is_rejected() -> void:
	var valid := RocketCodec.encode(1, [_record()] as Array[Dictionary])
	for field_offset in [8, 12, 16, 20, 24]:
		for value in [NAN, INF, -INF]:
			var bad := valid.duplicate()
			bad.encode_float(RocketCodec.HEADER_BYTES + field_offset, value)
			check(RocketCodec.decode(bad).is_empty(), "nonfinite motion at %d rejected" % field_offset)
	for direction in [Vector2.ZERO, Vector2(2, 0), Vector2(0.01, 0)]:
		var bad := valid.duplicate()
		bad.encode_float(RocketCodec.HEADER_BYTES + 16, direction.x)
		bad.encode_float(RocketCodec.HEADER_BYTES + 20, direction.y)
		check(RocketCodec.decode(bad).is_empty(), "nonunit heading rejected")
	for speed in [-0.1, RocketCodec.MAX_SPEED + 0.1]:
		var bad := valid.duplicate()
		bad.encode_float(RocketCodec.HEADER_BYTES + 24, speed)
		check(RocketCodec.decode(bad).is_empty(), "impossible flight speed rejected")
	for key in ["id", "owner_peer_id", "position", "direction", "speed"]:
		var bad := _record()
		bad[key] = "wrong type"
		check(RocketCodec.encode(1, [bad] as Array[Dictionary]).is_empty(), "wrong source type for %s rejected" % key)
