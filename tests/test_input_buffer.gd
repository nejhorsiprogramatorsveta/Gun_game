extends TestCase
## Host input handling (InputBuffer.take_for_tick): every input simulated as soon as
## possible and exactly once, in order.


func _packet(newest_seq: int, count: int = NetCodec.INPUT_HISTORY, buttons: int = 0) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	for i in count:
		frames.append(InputFrame.create(1, buttons, 0, newest_seq - i))
	return frames


## Arrival time of a packet sent on time by a steady 60 Hz client.
func _on_time(seq: int) -> int:
	return int(seq * InputBuffer.TICK_MS)


func _seqs(inputs: Array[InputFrame]) -> Array[int]:
	var result: Array[int] = []
	for input in inputs:
		result.append(input.seq)
	return result


func test_inputs_in_order_and_waits_instead_of_guessing() -> void:
	var buffer := InputBuffer.new()
	buffer.push(_packet(5))
	check_eq(buffer.size(), 1, "first packet: only its newest frame")
	buffer.push(_packet(7))
	check_eq(buffer.size(), 3, "6 and 7 added, duplicates of older frames ignored")
	check_eq(_seqs(buffer.take_for_tick()), [5, 6, 7] as Array[int], "a backlog is caught up in one tick, oldest first")
	check(buffer.take_for_tick().is_empty(), "late packet: the player waits, no input is invented")
	buffer.push(_packet(6))
	check_eq(buffer.size(), 0, "old packet ignored")
	buffer.push(_packet(8))
	check_eq(_seqs(buffer.take_for_tick()), [8] as Array[int], "the next input as soon as it arrives")


func test_steady_client_gets_one_input_per_tick_without_delay() -> void:
	var buffer := InputBuffer.new()
	var seq := 0
	for tick in 120:
		seq += 1
		buffer.push(_packet(seq), _on_time(seq))
		check_eq(_seqs(buffer.take_for_tick()), [seq] as Array[int], "tick %d: the input that just arrived" % tick)


func test_bunches_are_caught_up_without_losing_or_inventing_inputs() -> void:
	var buffer := InputBuffer.new()
	var seq := 0
	var simulated: Array[int] = []
	for tick in 600:
		if tick % 6 == 5:  # ~100 ms of inputs arrive together, like the Wi-Fi in the play tests
			for i in 6:
				seq += 1
				buffer.push(_packet(seq), _on_time(tick))
		simulated.append_array(_seqs(buffer.take_for_tick()))
	for tick in 3:  # the last bunch drains within a few ticks
		simulated.append_array(_seqs(buffer.take_for_tick()))
	var expected: Array[int] = []
	for i in range(1, seq + 1):
		expected.append(i)
	check_eq(simulated, expected, "every input exactly once and in order, nothing left behind")
	var stats := buffer.take_stats()
	check_eq(stats.skipped, 0, "no input skipped")


func test_huge_backlog_is_cut_but_keeps_taps() -> void:
	var buffer := InputBuffer.new()
	buffer.push(_packet(1))
	buffer.take_for_tick()
	var burst := _packet(31, 30)
	burst[29].buttons = InputFrame.JUMP  # seq 2, the oldest of the burst
	buffer.push(burst)
	check_eq(buffer.size(), InputBuffer.MAX_PENDING, "backlog capped")
	var first := buffer.take_for_tick()[0]
	check_eq(first.seq, 31 - InputBuffer.MAX_PENDING + 1, "oldest surplus inputs cut")
	check(first.buttons & InputFrame.JUMP != 0, "a cut jump tap is merged into the next input")


func test_long_silence_stops_the_player() -> void:
	var buffer := InputBuffer.new()
	buffer.push(_packet(3, 1, InputFrame.FIRE))
	buffer.take_for_tick()
	for tick in InputBuffer.STALE_TICKS:
		check(buffer.take_for_tick().is_empty(), "short gap: wait for the input")
	var neutral := buffer.take_for_tick()
	check_eq(neutral.size(), 1, "long silence: the player is simulated again")
	check_eq([neutral[0].move_x, neutral[0].buttons], [0, 0], "standing still, not shooting")
