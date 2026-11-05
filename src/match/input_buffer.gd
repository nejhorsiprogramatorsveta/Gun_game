class_name InputBuffer
extends RefCounted
## Host: inputs received from ONE client, consumed one per physics tick (PLAN.md D.3).
## Packets arrive in bursts, so a small queue absorbs jitter. Because the client produces
## and the host consumes at the same 60 Hz, a queue that once filled up would never shrink
## again and would add constant input delay (measured ~50-80 ms with the F3 overlay).
## Catch-up: when the queue never got down to TARGET during a whole window, the surplus
## oldest inputs are skipped. Their held buttons are merged into the next input so a short
## tap (jump, fire) is not lost; the client corrects the skipped tick via reconciliation.
## Short gaps (packet loss) repeat the last input; after STALE_TICKS without any input the
## player stands still and stops firing, so a crashed or frozen client does not run off.
## Adaptive target (play tests 2026-11-05): on a link that delivers inputs in bunches the
## queue must hold a bunch, otherwise every gap starves the player (repeated input) and the
## catch-up then skips one - both visible as corrections. The target follows the measured
## arrival jitter (JitterClock): 1 on a clean LAN, up to MAX_TARGET on bursty Wi-Fi.

## Hard cap: older inputs beyond this (or target + 4) are skipped right away.
const MAX_PENDING := 6
## Inputs to keep queued at the start of a tick (1 = the one consumed this tick); the
## adaptive target never goes below TARGET or above MAX_TARGET (100 ms at 60 Hz).
const TARGET := 1
const MAX_TARGET := 6
## Jitter is trusted after this many packets.
const MIN_JITTER_SAMPLES := 30
const TICK_MS := 1000.0 / 60.0
## 0.5 s at 60 Hz: long enough that normal jitter never triggers a skip.
const WINDOW_TICKS := 30
## 0.25 s at 60 Hz without new input -> neutral input (keeps aim and sequence).
const STALE_TICKS := 15

var _queue: Array[InputFrame] = []
var _current := InputFrame.new()
var _newest_seq := -1
var _window_min := MAX_PENDING
var _window_ticks := 0
var _ticks_without_input := 0
## Current adaptive target (see TARGET / MAX_TARGET).
var target := TARGET
var _clock := JitterClock.new()
## Sequence number without the 16-bit wrap, for the jitter timeline.
var _unwrapped_seq := -1
## Diagnostics since the last take_stats() (NetLog): new inputs queued, ticks without a
## queued input, stalls (STALE_TICKS reached) and inputs dropped by the catch-up.
var _received := 0
var _starved := 0
var _stalls := 0
var _skipped := 0


## frames are newest first (NetCodec.decode_input); queues the unseen ones, oldest first.
## arrival_ms < 0 = now.
func push(frames: Array[InputFrame], arrival_ms: int = -1) -> void:
	if frames.is_empty():
		return
	_observe_arrival(frames[0].seq, arrival_ms if arrival_ms >= 0 else Time.get_ticks_msec())
	for i in range(frames.size() - 1, -1, -1):
		var frame := frames[i]
		var is_first_packet := _newest_seq == -1
		if (is_first_packet and i == 0) or (not is_first_packet and NetCodec.seq_newer(frame.seq, _newest_seq)):
			_queue.append(frame)
			_newest_seq = frame.seq
			_received += 1
	_skip_oldest(_queue.size() - max_pending())


func max_pending() -> int:
	return maxi(MAX_PENDING, target + 4)


## The input for this tick; if the client's packets are late, its last input repeats.
func next() -> InputFrame:
	_window_min = mini(_window_min, _queue.size())
	_window_ticks += 1
	if _window_ticks >= WINDOW_TICKS:
		_skip_oldest(_window_min - target)
		_window_ticks = 0
		_window_min = MAX_PENDING
	if not _queue.is_empty():
		_current = _queue.pop_front()
		_ticks_without_input = 0
		return _current
	_ticks_without_input += 1
	_starved += 1
	if _ticks_without_input == STALE_TICKS + 1:
		_stalls += 1
	if _ticks_without_input > STALE_TICKS:
		# Stop moving and shooting, but keep held jump/ability/down so the next real input is
		# not seen as a fresh press (an unwanted jump or ability after a short stall).
		_current = InputFrame.create(0, _current.buttons & ~InputFrame.FIRE, _current.aim, _current.seq)
	return _current


func size() -> int:
	return _queue.size()


## Counters since the previous call (then reset), see NetLog.
func take_stats() -> Dictionary:
	var stats := {"received": _received, "starved": _starved, "stalls": _stalls, "skipped": _skipped,
			"target": target, "jitter": roundi(_clock.jitter_ms())}
	_received = 0
	_starved = 0
	_stalls = 0
	_skipped = 0
	return stats


func _observe_arrival(newest_seq: int, arrival_ms: int) -> void:
	if _unwrapped_seq < 0:
		_unwrapped_seq = newest_seq
	else:
		var step := (newest_seq - (_unwrapped_seq & 0xFFFF)) & 0xFFFF
		if step == 0 or step >= 0x8000:
			return  # an old or repeated packet says nothing about timing
		_unwrapped_seq += step
	_clock.observe(_unwrapped_seq * TICK_MS, arrival_ms)
	if _clock.sample_count() >= MIN_JITTER_SAMPLES:
		target = clampi(TARGET + floori(_clock.jitter_ms() / TICK_MS), TARGET, MAX_TARGET)


func _skip_oldest(count: int) -> void:
	for i in mini(count, _queue.size() - 1):
		var skipped: InputFrame = _queue.pop_front()
		_queue[0].buttons |= skipped.buttons
		_skipped += 1
