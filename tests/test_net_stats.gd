extends TestCase


func test_ping_from_input_acknowledgement() -> void:
	var stats := NetStats.new()
	check_eq(stats.ping_ms(), -1, "nothing measured yet")
	stats.record_input_sent(1, 1000)
	stats.record_input_sent(2, 1016)
	stats.record_ack(1, 1100)
	check_eq(stats.ping_ms(), 100, "first sample taken directly")
	stats.record_ack(1, 1500)
	check_eq(stats.ping_ms(), 100, "repeated acknowledgement is ignored")
	stats.record_ack(2, 1316)
	check(stats.ping_ms() > 100 and stats.ping_ms() < 300, "average moves toward the slower sample")


func test_acknowledged_and_older_inputs_are_forgotten() -> void:
	var stats := NetStats.new()
	for seq in range(65530, 65536):
		stats.record_input_sent(seq, seq)
	for seq in range(0, 3):
		stats.record_input_sent(seq, 65536 + seq)
	stats.record_ack(65535, 70000)
	check_eq(stats._sent_ms.keys(), [0, 1, 2], "only inputs newer than the ack stay tracked (with wraparound)")
	for seq in range(3, 3 + NetStats.MAX_TRACKED_INPUTS + 10):
		stats.record_input_sent(seq, seq)
	check(stats._sent_ms.size() <= NetStats.MAX_TRACKED_INPUTS, "tracking is bounded")
