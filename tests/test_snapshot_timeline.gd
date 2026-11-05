extends TestCase
## Remote players play back on the host's timeline with an adaptive delay (SnapshotTimeline,
## JitterClock, RemoteInterpolator).


func test_jitter_clock_measures_lateness_against_the_fastest_packet() -> void:
	var clock := JitterClock.new()
	for i in 60:
		var late := 100 if i % 4 == 3 else 0  # every 4th packet 100 ms late
		clock.observe(i * 33.0, 1000 + i * 33 + late)
	check(is_equal_approx(clock.base_offset(), 1000.0), "base offset = the on-time packets")
	check(is_equal_approx(clock.jitter_ms(), 100.0), "90th percentile of lateness")
	check(is_equal_approx(clock.sender_time(2000), 1000.0), "local time -> sender time")


func test_delay_adapts_to_jitter_smoothly() -> void:
	var timeline := SnapshotTimeline.new()
	for tick in range(0, 240, 2):  # clean link: every snapshot on time
		timeline.observe(tick, 5000 + int(SnapshotTimeline.tick_ms(tick)))
	for i in 600:
		timeline.update(1.0 / 60.0)
	check(timeline.delay_ms <= SnapshotTimeline.MIN_DELAY_MS + 1.0, "clean link: shortest delay (%.0f ms)" % timeline.delay_ms)
	var bursty := SnapshotTimeline.new()
	for tick in range(0, 240, 2):  # bunches: three snapshots arrive together every 100 ms
		var arrival := 5000 + int(ceil(SnapshotTimeline.tick_ms(tick) / 100.0) * 100.0)
		bursty.observe(tick, arrival)
	var before := bursty.delay_ms
	bursty.update(1.0 / 60.0)
	check(absf(bursty.delay_ms - before) < 5.0, "the delay never jumps in one frame")
	for i in 120:
		bursty.update(1.0 / 60.0)
	check(bursty.delay_ms > 80.0 and bursty.delay_ms <= SnapshotTimeline.MAX_DELAY_MS,
			"bursty link: delay covers the bunches (%.0f ms)" % bursty.delay_ms)


func test_short_gaps_are_extrapolated_instead_of_freezing() -> void:
	var interpolator := RemoteInterpolator.new(0)
	interpolator.push(1000.0, {"position": Vector2(0, 0), "velocity": Vector2(600, 0), "active": true})
	interpolator.push(1016.0, {"position": Vector2(10, 0), "velocity": Vector2(600, 0), "active": true})
	check(is_equal_approx(interpolator.sample(1066.0).position.x, 40.0), "50 ms past the newest snapshot: keeps moving")
	check(is_equal_approx(interpolator.sample(1416.0).position.x, 70.0), "but at most MAX_EXTRAPOLATION_MS ahead")
	interpolator.push(1032.0, {"position": Vector2(20, 0), "velocity": Vector2.ZERO, "active": false})
	check_eq(interpolator.sample(1100.0).position, Vector2(20, 0), "inactive (dead) players are not extrapolated")


func test_bunched_snapshots_still_play_back_evenly() -> void:
	var timeline := SnapshotTimeline.new()
	var interpolator := RemoteInterpolator.new(0)
	RemoteInterpolator.hold_frames = 0
	# The host moves a player 6 px per tick; snapshots every 2 ticks arrive in 100 ms bunches.
	var pending: Array = []
	var positions: Array[float] = []
	for frame in 600:
		var now := 10000 + int(frame * 1000.0 / 60.0)
		var tick := frame
		if tick % 2 == 0:
			pending.append(tick)
		if frame % 6 == 5:
			for t: int in pending:
				timeline.observe(t, now)
				interpolator.push(SnapshotTimeline.tick_ms(t), {"position": Vector2(t * 6.0, 0), "active": true})
			pending.clear()
		timeline.update(1.0 / 60.0)
		if frame >= 300:
			positions.append(interpolator.sample(timeline.render_time(now)).position.x)
	var steps: Array[float] = []
	for i in range(1, positions.size()):
		steps.append(positions[i] - positions[i - 1])
	steps.sort()
	check(steps[0] > 2.0, "the player never stops (smallest step %.1f px)" % steps[0])
	check(steps[-1] < 10.0, "and never jumps (largest step %.1f px)" % steps[-1])
