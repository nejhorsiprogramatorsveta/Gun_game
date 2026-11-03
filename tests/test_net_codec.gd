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
		{"slot": 0, "position": Vector2(400.5, -20.25), "velocity": Vector2(120, -820), "facing": -1, "active": true, "invulnerable": true, "aim": 32768, "last_seq": 65535, "lives": 5},
		{"slot": 3, "position": Vector2(1, 2), "velocity": Vector2(99999, 0), "facing": 1, "active": false, "invulnerable": false, "aim": 0, "last_seq": 7, "lives": 0},
	]
	var snapshot := NetCodec.decode_snapshot(NetCodec.encode_snapshot(1234, 3, states))
	check_eq(snapshot.tick, 1234, "tick")
	check_eq(snapshot.countdown, 3, "countdown")
	check_eq([snapshot.states[0].invulnerable, snapshot.states[0].lives, snapshot.states[1].lives], [true, 5, 0], "invulnerability and lives")
	var a: Dictionary = snapshot.states[0]
	var b: Dictionary = snapshot.states[1]
	check_eq([a.slot, a.position, a.velocity, a.facing, a.active, a.aim, a.last_seq], [0, Vector2(400.5, -20.25), Vector2(120, -820), -1, true, 32768, 65535], "first player")
	check_eq([b.slot, b.velocity.x, b.facing, b.active], [3, 32767.0, 1, false], "second player, velocity clamped")


func test_snapshot_rejects_malformed() -> void:
	var data := NetCodec.encode_snapshot(1, 0, [{"slot": 0, "position": Vector2.ZERO, "velocity": Vector2.ZERO, "facing": 1, "active": true, "invulnerable": false, "aim": 0, "last_seq": 0, "lives": 1}] as Array[Dictionary])
	data.resize(data.size() - 1)
	check(NetCodec.decode_snapshot(data).is_empty(), "truncated snapshot ignored")
	var too_many := PackedByteArray([0, 0, 0, 0, 200, 0])
	check(NetCodec.decode_snapshot(too_many).is_empty(), "absurd player count ignored")


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
