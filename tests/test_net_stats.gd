extends TestCase


func test_input_ack_time_and_jitter() -> void:
	var stats := NetStats.new()
	check_eq(stats.summary(0).ack_ms, -1, "nothing measured yet")
	stats.record_input_sent(1, 1000)
	stats.record_input_sent(2, 1016)
	stats.record_ack(1, 1100)
	check_eq(stats.summary(1100).ack_ms, 100, "first sample taken directly")
	stats.record_ack(1, 1500)
	check_eq(stats.summary(1500).ack_ms, 100, "repeated acknowledgement is ignored")
	stats.record_ack(2, 1316)
	var summary := stats.summary(1316)
	check(summary.ack_ms > 100 and summary.ack_ms < 300, "average moves toward the slower sample")
	check(summary.jitter_ms > 0, "jitter grows with varying samples")


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


func test_snapshot_gaps_and_correction_peaks_use_a_window() -> void:
	var stats := NetStats.new()
	stats.record_snapshot_arrival(0)
	stats.record_snapshot_arrival(33)
	stats.record_snapshot_arrival(233)
	stats.record_correction(-1.0, 233)
	stats.record_correction(12.5, 240)
	stats.record_correction(2.0, 250)
	var summary := stats.summary(250)
	check_eq(summary.snapshot_gap_max_ms, 200, "longest pause in the window")
	check(summary.snapshot_gap_ms >= 33 and summary.snapshot_gap_ms < 200, "smoothed interval")
	check_eq(summary.correction_px, 2.0, "last correction")
	check_eq(summary.correction_max_px, 12.5, "largest correction; -1 (respawn) ignored")
	summary = stats.summary(250 + NetStats.WINDOW_MS + 1)
	check_eq(summary.snapshot_gap_max_ms, 0, "old pauses leave the window")
	check_eq(summary.correction_max_px, 0.0, "old corrections leave the window")
