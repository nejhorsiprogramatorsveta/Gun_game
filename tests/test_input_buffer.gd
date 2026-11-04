extends TestCase


func _packet(newest_seq: int, count: int = NetCodec.INPUT_HISTORY, buttons: int = 0) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	for i in count:
		frames.append(InputFrame.create(1, buttons, 0, newest_seq - i))
	return frames


func test_queues_unseen_inputs_oldest_first_and_repeats_when_late() -> void:
	var buffer := InputBuffer.new()
	buffer.push(_packet(5))
	check_eq(buffer.size(), 1, "first packet: only its newest frame")
	buffer.push(_packet(7))
	check_eq(buffer.size(), 3, "6 and 7 added, duplicates of older frames ignored")
	check_eq(buffer.next().seq, 5, "oldest first")
	check_eq(buffer.next().seq, 6, "then the next one")
	check_eq(buffer.next().seq, 7, "then the newest")
	check_eq(buffer.next().seq, 7, "late packet: the last input repeats")
	buffer.push(_packet(6))
	check_eq(buffer.size(), 0, "old packet ignored")


func test_hard_cap_skips_oldest_but_keeps_taps() -> void:
	var buffer := InputBuffer.new()
	buffer.push(_packet(1))
	buffer.next()
	var burst := _packet(11, 10)
	burst[9].buttons = InputFrame.JUMP  # seq 2, the oldest of the burst
	buffer.push(burst)
	check_eq(buffer.size(), InputBuffer.MAX_PENDING, "burst capped")
	var first := buffer.next()
	check_eq(first.seq, 11 - InputBuffer.MAX_PENDING + 1, "oldest surplus inputs skipped")
	check(first.buttons & InputFrame.JUMP != 0, "a skipped jump tap is merged into the next input")


func test_catch_up_drains_a_queue_that_never_shrinks() -> void:
	var buffer := InputBuffer.new()
	var seq := 0
	buffer.push(_packet(seq))
	for i in 4:  # queue of 5 inputs, then steady 1 in / 1 out like a real 60 Hz client
		seq += 1
		buffer.push(_packet(seq))
	check_eq(buffer.size(), 5, "filled queue")
	for tick in InputBuffer.WINDOW_TICKS * 2:
		buffer.next()
		seq += 1
		buffer.push(_packet(seq))
	check(buffer.size() <= InputBuffer.TARGET, "steady surplus removed within two windows")


func test_jitter_that_empties_the_queue_is_not_skipped() -> void:
	var buffer := InputBuffer.new()
	var seq := 0
	buffer.push(_packet(seq))
	var consumed: Array[int] = []
	for tick in InputBuffer.WINDOW_TICKS * 4:
		consumed.append(buffer.next().seq)
		if tick % 3 == 2:  # bursty delivery: 3 inputs every 3rd tick
			for i in 3:
				seq += 1
			buffer.push(_packet(seq))
	var skipped := 0
	for i in range(1, consumed.size()):
		if NetCodec.seq_newer(consumed[i], consumed[i - 1]) and consumed[i] != consumed[i - 1] + 1:
			skipped += 1
	check_eq(skipped, 0, "no input skipped when the queue regularly runs low")


func test_long_silence_stops_the_player() -> void:
	var buffer := InputBuffer.new()
	buffer.push(_packet(3, 1, InputFrame.FIRE))
	var frame := buffer.next()
	for tick in InputBuffer.STALE_TICKS:
		frame = buffer.next()
	check_eq(frame.move_x, 1, "short gap: the last input repeats")
	frame = buffer.next()
	check_eq(frame.move_x, 0, "long silence: no movement")
	check_eq(frame.buttons, 0, "long silence: no buttons")
	check_eq(frame.seq, 3, "sequence kept, so acknowledgements stay correct")
	buffer.push(_packet(4))
	check_eq(buffer.next().move_x, 1, "new input takes over again")
