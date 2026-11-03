extends TestCase


func test_disabled_runs_immediately() -> void:
	var simulator := LagSimulator.new()
	var calls := [0]
	simulator.run(func() -> void: calls[0] += 1)
	check_eq(calls[0], 1, "without fake lag the action runs right away")


func test_delays_and_keeps_order() -> void:
	var simulator := LagSimulator.new()
	simulator.rtt_ms = 100000  # far in the future: nothing may run yet
	simulator.jitter_ms = 40000
	var order: Array[int] = []
	for i in 5:
		simulator.run(func() -> void: order.append(i))
	simulator.flush()
	check(order.is_empty(), "delayed actions do not run early")
	var times: Array = simulator._queue.map(func(entry: Dictionary) -> int: return entry.time)
	var sorted_times := times.duplicate()
	sorted_times.sort()
	check_eq(times, sorted_times, "delivery order is preserved despite jitter")


func test_full_loss_drops_everything() -> void:
	var simulator := LagSimulator.new()
	simulator.loss_percent = 100.0
	var calls := [0]
	for i in 20:
		simulator.run(func() -> void: calls[0] += 1)
	simulator.flush()
	check_eq(calls[0], 0, "100 % loss drops every packet")
