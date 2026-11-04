extends TestCase


class FakePlayer:
	var slot := 0


class FakeBuffer:
	var queued := 0
	func size() -> int:
		return queued


func test_client_line_every_interval_with_window_maxima() -> void:
	var log := NetLog.new()
	check_eq(log.tick(0, false, 60.0, 90, {}, {}), "", "nothing before the interval")
	log.record_snapshot_arrival(100)
	log.record_snapshot_arrival(180)
	log.record_correction(-1.0)
	log.record_correction(12.5)
	log.tick(1000, false, 40.0, 140, {}, {})
	var line := log.tick(NetLog.INTERVAL_MS, false, 60.0, 100, {}, {})
	check_eq(line, "[net] client ping=100ms max=140ms fps=60 min=40 snapshot_gap_max=80ms correction_max=12.5px", "client line")
	line = log.tick(NetLog.INTERVAL_MS * 2, false, 60.0, 100, {}, {})
	check(line.contains("max=100ms") and line.contains("correction_max=0.0px"), "maxima reset after each line")


func test_host_line_reports_input_queues_per_slot() -> void:
	var log := NetLog.new()
	var player := FakePlayer.new()
	player.slot = 1
	var buffer := FakeBuffer.new()
	buffer.queued = 4
	log.tick(0, true, 60.0, -1, {7: buffer}, {7: player})
	buffer.queued = 1
	var line := log.tick(NetLog.INTERVAL_MS, true, 60.0, -1, {7: buffer, 9: FakeBuffer.new()}, {7: player})
	check_eq(line, "[net] host fps=60 min=60 input_queue_max: slot1=4", "host line; unknown peers skipped")
