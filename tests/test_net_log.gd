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
	log.record_snapshot_arrival(330)
	log.record_snapshot_dropped()
	log.record_correction(-1.0)
	log.record_correction(12.5)
	log.tick(1000, false, 40.0, 140, {}, {})
	var line := log.tick(NetLog.INTERVAL_MS, false, 60.0, 100, {}, {})
	check(line.begins_with("[") and line.contains("] [net] client "), "timestamped client line: " + line)
	for part in ["ping=100ms", "avg=110ms", "max=140ms", "enet=n/a", "snapshots=3", "dropped=1", "gap_max=150ms",
			"gaps>100ms=1", "correction_max=12.5px", "corrections>8px=1", "fps=60 min=40", "hitches=2"]:
		check(line.contains(part), "client line has " + part)
	line = log.tick(NetLog.INTERVAL_MS * 2, false, 60.0, 100, {}, {})
	check(line.contains("max=100ms") and line.contains("correction_max=0.0px") and line.contains("snapshots=0"),
			"window values reset after each line")


func test_host_line_reports_each_client_slot() -> void:
	var log := NetLog.new()
	log.peer_stats = func(peer_id: int) -> Dictionary:
		return {"rtt": 42, "rtt_var": 7, "loss": 1.5, "throttle": 32} if peer_id == 7 else {}
	var player := FakePlayer.new()
	player.slot = 1
	var buffer := InputBuffer.new()
	var frame := InputFrame.create(0, 0)
	frame.seq = 1
	buffer.push([frame])
	log.tick(0, true, 60.0, -1, {7: buffer}, {7: player})
	for i in 20:
		buffer.take_for_tick()
	var line := log.tick(NetLog.INTERVAL_MS, true, 60.0, -1, {7: buffer, 9: FakeBuffer.new()}, {7: player})
	check(line.contains("] [net] host fps=60 min=60"), "host line: " + line)
	check(line.contains("slot1 rtt=42ms var=7ms loss=1.5% throttle=32/32 queue_max=1"), "ENet stats and queue per slot")
	check(line.contains("inputs=1 waited=19 stalls=1 skipped=0 caught_up=0"), "input buffer counters")
	check(not line.contains("slot9") and line.count("slot") == 1, "unknown peers skipped")


func test_input_buffer_counts_cut_inputs_and_resets() -> void:
	var buffer := InputBuffer.new()
	var frames: Array[InputFrame] = []
	for seq in range(10, 0, -1):
		var frame := InputFrame.create(0, 0)
		frame.seq = seq
		frames.append(frame)
	buffer.push(frames)  # first packet: only the newest frame counts
	var more: Array[InputFrame] = []
	for seq in range(30, 10, -1):
		var frame := InputFrame.create(0, 0)
		frame.seq = seq
		more.append(frame)
	buffer.push(more)
	var stats := buffer.take_stats()
	check_eq([stats.received, stats.skipped], [21, 21 - InputBuffer.MAX_PENDING], "received and capped")
	check_eq(buffer.take_stats().received, 0, "counters reset")


func test_free_memory_ignores_swap_and_page_file() -> void:
	var gb := 1024 * 1048576
	# Windows: "available" is the commit limit (RAM + page file), as in the 0.2.9 play test.
	var windows := {"physical": 16 * gb, "free": 6 * gb, "available": 57 * gb, "stack": 1048576}
	check_eq(NetLog.free_ram_mb(windows), 6 * 1024, "Windows: free RAM, not the commit limit")
	# Windows without a page file: the commit limit is below the physical size.
	var no_page_file := {"physical": 16 * gb, "free": 6 * gb, "available": 15 * gb}
	check_eq(NetLog.free_ram_mb(no_page_file), 6 * 1024, "no page file: still free RAM")
	# macOS / Linux: "available" = free RAM + free swap.
	check_eq(NetLog.free_ram_mb({"physical": 16 * gb, "free": 3 * gb, "available": 5 * gb}), 3 * 1024, "swap not counted")
	check_eq(NetLog.free_ram_mb({"physical": -1, "free": -1, "available": -1}), -1, "unknown stays unknown")


func test_diag_log_hides_addresses() -> void:
	check_eq(DiagLog.mask("cannot reach 192.168.1.20:24642 or 100.101.102.103"), "cannot reach <lan>:24642 or <lan>",
			"IPv4 replaced by its kind")
	check(not DiagLog.mask("host 8.8.8.8").contains("8.8"), "public address hidden")
	check_eq(DiagLog.describe_address("192.168.0.5:7777"), "lan port=7777", "join target without the address")
	check_eq(DiagLog.describe_address("my-pc.tail1234.ts.net"), "hostname port=%d" % EnetDirectConnector.DEFAULT_PORT, "hostname")
	check(DiagLog.line("net", "x").ends_with("] [net] x"), "timestamped line")
