extends TestCase
## NetCodec (inputs, snapshots, sequence numbers) and RemoteInterpolator.


func test_input_roundtrip() -> void:
	var history: Array[InputFrame] = [
		InputFrame.create(1, InputFrame.JUMP | InputFrame.FIRE, 12345, 10),
		InputFrame.create(-1, 0, 400, 9),
		InputFrame.create(0, InputFrame.DOWN, 65535, 8),
	]
	var data := NetCodec.encode_input(history)
	check_eq(data.size(), NetCodec.INPUT_PACKET_BYTES, "fixed packet size")
	var frames := NetCodec.decode_input(data)
	check_eq(frames.size(), 3, "three frames")
	check_eq([frames[0].seq, frames[1].seq, frames[2].seq], [10, 9, 8], "sequence numbers count down")
	check_eq([frames[0].move_x, frames[0].buttons, frames[0].aim], [1, InputFrame.JUMP | InputFrame.FIRE, 12345], "newest frame")
	check_eq([frames[2].move_x, frames[2].aim], [0, 65535], "oldest frame")


func test_input_rejects_and_sanitizes_bad_packets() -> void:
	check(NetCodec.decode_input(PackedByteArray([1, 2, 3])).is_empty(), "wrong size ignored")
	var data := NetCodec.encode_input([InputFrame.create(0, 0, 0, 5)] as Array[InputFrame])
	data.encode_s8(2, 100)  # impossible move value
	data.encode_u8(3, 0xFF)  # unknown buttons
	var frame := NetCodec.decode_input(data)[0]
	check_eq(frame.move_x, 1, "move clamped to -1..1")
	check_eq(frame.buttons, InputFrame.ALL_BUTTONS, "unknown button bits removed")


func test_snapshot_roundtrip() -> void:
	var states: Array[Dictionary] = [
		{"slot": 0, "position": Vector2(400.5, -20.25), "velocity": Vector2(120, -820), "facing": -1, "active": true, "invulnerable": true, "aim": 32768, "last_seq": 65535, "lives": 5,
				"on_floor": true, "prev_buttons": InputFrame.JUMP | InputFrame.DOWN, "jumps_left": 2, "jump_buffer_timer": 0.125, "drop_timer": 0.25,
				"kills": 7, "deaths": 3, "ability_cooldown": 3.21, "ability_active": true, "firing": true, "dash_time_left": 0.05, "dash_direction": -1},
		{"slot": 3, "position": Vector2(1, 2), "velocity": Vector2(99999, 0), "facing": 1, "active": false, "invulnerable": false, "aim": 0, "last_seq": 7, "lives": 0},
	]
	var data := NetCodec.encode_snapshot(1234, 3, states)
	check_eq(data.size(), NetCodec.SNAPSHOT_HEADER_BYTES + 2 * NetCodec.SNAPSHOT_PLAYER_BYTES, "complete movement snapshot size")
	var snapshot := NetCodec.decode_snapshot(data)
	check_eq(snapshot.tick, 1234, "tick")
	check_eq(snapshot.countdown, 3, "countdown (tenths)")
	check_eq([snapshot.states[0].invulnerable, snapshot.states[0].lives, snapshot.states[1].lives], [true, 5, 0], "invulnerability and lives")
	var a: Dictionary = snapshot.states[0]
	var b: Dictionary = snapshot.states[1]
	check_eq([a.slot, a.position, a.velocity, a.facing, a.active, a.aim, a.last_seq], [0, Vector2(400.5, -20.25), Vector2(120, -820), -1, true, 32768, 65535], "first player")
	check_eq([b.slot, b.velocity.x, b.facing, b.active], [3, 32767.0, 1, false], "second player, velocity clamped")
	check_eq([a.kills, a.deaths, b.kills, b.deaths], [7, 3, 0, 0], "scores survive encoding with neutral defaults")
	check_eq([a.on_floor, a.prev_buttons, a.jumps_left, a.jump_buffer_timer, a.drop_timer],
			[true, InputFrame.JUMP | InputFrame.DOWN, 2, 0.125, 0.25], "movement memory survives encoding")
	check_eq([b.on_floor, b.prev_buttons, b.jumps_left, b.jump_buffer_timer, b.drop_timer],
			[false, 0, 0, 0.0, 0.0], "missing movement memory has neutral defaults")
	check_eq([a.firing, b.firing], [true, false], "shooting animation flag")
	check_eq([a.ability_cooldown, a.ability_active, b.ability_cooldown, b.ability_active], [193 / 60.0, true, 0.0, false],
			"ability cooldown in ticks (rounded up) and active flag")
	check_eq([is_equal_approx(a.dash_time_left, 0.05), a.dash_direction, b.dash_time_left, b.dash_direction], [true, -1, 0.0, 1],
			"dash state for prediction replay")


func test_snapshot_rejects_malformed() -> void:
	var data := NetCodec.encode_snapshot(1, 0, [{"slot": 0, "position": Vector2.ZERO, "velocity": Vector2.ZERO, "facing": 1, "active": true, "invulnerable": false, "aim": 0, "last_seq": 0, "lives": 1}] as Array[Dictionary])
	data.resize(data.size() - 1)
	check(NetCodec.decode_snapshot(data).is_empty(), "truncated snapshot ignored")
	var too_many := PackedByteArray([0, 0, 0, 0, 200, 0])
	check(NetCodec.decode_snapshot(too_many).is_empty(), "absurd player count ignored")
	var old_layout := PackedByteArray()
	old_layout.resize(NetCodec.SNAPSHOT_HEADER_BYTES + 19)
	old_layout.encode_u8(4, 1)
	check(NetCodec.decode_snapshot(old_layout).is_empty(), "old movement snapshot layout ignored")
	old_layout.resize(NetCodec.SNAPSHOT_HEADER_BYTES + 29)
	check(NetCodec.decode_snapshot(old_layout).is_empty(), "snapshot without scores ignored")


func test_score_counts_are_clamped_to_wire_range() -> void:
	var state := {"slot": 0, "position": Vector2.ZERO, "velocity": Vector2.ZERO, "facing": 1,
			"active": true, "invulnerable": false, "aim": 0, "last_seq": 0, "lives": 5,
			"kills": 100000, "deaths": -1}
	var snapshot := NetCodec.decode_snapshot(NetCodec.encode_snapshot(1, 0, [state] as Array[Dictionary]))
	check_eq([snapshot.states[0].kills, snapshot.states[0].deaths], [65535, 0], "score counts cannot overflow the wire format")


func test_snapshot_rejects_invalid_slots_and_nonfinite_movement() -> void:
	var state := {"slot": 0, "position": Vector2.ZERO, "velocity": Vector2.ZERO, "facing": 1,
			"active": true, "invulnerable": false, "aim": 0, "last_seq": 0, "lives": 1}
	var valid := NetCodec.encode_snapshot(1, 0, [state] as Array[Dictionary])
	var invalid_slot := valid.duplicate()
	invalid_slot.encode_u8(NetCodec.SNAPSHOT_HEADER_BYTES, NetCodec.MAX_SNAPSHOT_PLAYERS)
	check(NetCodec.decode_snapshot(invalid_slot).is_empty(), "out-of-range player slot ignored")
	var duplicates := NetCodec.encode_snapshot(1, 0, [state, state] as Array[Dictionary])
	check(NetCodec.decode_snapshot(duplicates).is_empty(), "duplicate player slots ignored")
	for field_offset in [1, 5, 21, 25]:
		for value in [NAN, INF, -INF]:
			var malformed := valid.duplicate()
			malformed.encode_float(NetCodec.SNAPSHOT_HEADER_BYTES + field_offset, value)
			check(NetCodec.decode_snapshot(malformed).is_empty(), "nonfinite movement field %d ignored" % field_offset)
	for field_offset in [21, 25]:
		var negative_timer := valid.duplicate()
		negative_timer.encode_float(NetCodec.SNAPSHOT_HEADER_BYTES + field_offset, -0.1)
		check(NetCodec.decode_snapshot(negative_timer).is_empty(), "negative movement timer ignored")


func test_seq_wraparound() -> void:
	check(NetCodec.seq_newer(5, 3), "5 is newer than 3")
	check(not NetCodec.seq_newer(3, 5), "3 is older than 5")
	check(NetCodec.seq_newer(2, 65534), "2 is newer than 65534 after wrapping")
	check(not NetCodec.seq_newer(7, 7), "same seq is not newer")


func test_aim_roundtrip() -> void:
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2(1, -1).normalized()]:
		var back := InputFrame.aim_to_vector(InputFrame.aim_from_vector(direction))
		check(back.distance_to(direction) < 0.001, "aim survives encoding: %s" % direction)


func test_interpolation_blends_and_snaps_on_teleport() -> void:
	var interpolator := RemoteInterpolator.new()
	var state := func(x: float, active: bool) -> Dictionary: return {"position": Vector2(x, 0), "active": active}
	interpolator.push(1000, state.call(0.0, true))
	interpolator.push(1100, state.call(100.0, true))
	var mid := interpolator.sample(1150 + RemoteInterpolator.INTERPOLATION_DELAY_MS - 100)
	check_eq(mid.position, Vector2(50, 0), "halfway between snapshots")
	interpolator.push(1200, state.call(900.0, true))
	var jumped := interpolator.sample(1150 + RemoteInterpolator.INTERPOLATION_DELAY_MS)
	check_eq(jumped.position, Vector2(900, 0), "big jump (respawn) is not interpolated")
