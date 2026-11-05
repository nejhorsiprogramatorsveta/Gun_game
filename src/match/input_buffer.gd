class_name InputBuffer
extends RefCounted
## Host: inputs received from ONE client (PLAN.md D.3), handed to the simulation by
## take_for_tick(). Play tests 2026-11-05: Wi-Fi delivers inputs in bunches, and holding a
## queue to smooth them cost 50-80 ms of input delay ("ping 180 is unplayable").
## So every input is simulated as soon as possible and EXACTLY ONCE, in order:
## - normally one input per tick;
## - when the next input is late, the player waits for it (no input is invented, so the
##   client's prediction of its own movement stays exact - no correction);
## - when inputs queue up (a bunch arrived), up to MAX_PER_TICK are simulated in one tick
##   - nothing is skipped (others still see smooth movement: clients play client-controlled
##   players back on the owner's input timeline, SnapshotTimeline);
## - after STALE_TICKS without any input the player is simulated with a neutral input
##   (stands still, stops firing), so a crashed or frozen client does not hang in the air;
## - only a huge backlog beyond MAX_PENDING is cut (buttons of skipped inputs are merged).
## The arrival jitter (JitterClock) is only measured for the diagnostic log.

const MAX_PENDING := 12
const MAX_PER_TICK := 4
const TICK_MS := 1000.0 / 60.0
## 0.25 s at 60 Hz without new input -> neutral input (keeps aim and sequence).
const STALE_TICKS := 15

var _queue: Array[InputFrame] = []
var _current := InputFrame.new()
var _newest_seq := -1
var _ticks_without_input := 0
var _clock := JitterClock.new()
## Sequence number without the 16-bit wrap, for the jitter timeline.
var _unwrapped_seq := -1
## Diagnostics since the last take_stats() (NetLog): inputs queued, ticks without an input
## (waiting), stalls (STALE_TICKS reached), inputs cut from a huge backlog, and extra inputs
## simulated to catch up.
var _received := 0
var _starved := 0
var _stalls := 0
var _skipped := 0
var _extra := 0


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
	_skip_oldest(_queue.size() - MAX_PENDING)


## The inputs to simulate this tick, oldest first (see the class description).
func take_for_tick() -> Array[InputFrame]:
	var result: Array[InputFrame] = []
	if _queue.is_empty():
		_ticks_without_input += 1
		_starved += 1
		if _ticks_without_input == STALE_TICKS + 1:
			_stalls += 1
		if _ticks_without_input > STALE_TICKS:
			# Stop moving and shooting, but keep held jump/ability/down so the next real input
			# is not seen as a fresh press (an unwanted jump or ability after a stall).
			_current = InputFrame.create(0, _current.buttons & ~InputFrame.FIRE, _current.aim, _current.seq)
			result.append(_current)
		return result
	_ticks_without_input = 0
	var count := mini(_queue.size(), MAX_PER_TICK)
	for i in count:
		_current = _queue.pop_front()
		result.append(_current)
	_extra += count - 1
	return result


func size() -> int:
	return _queue.size()


## Counters since the previous call (then reset), see NetLog.
func take_stats() -> Dictionary:
	var stats := {"received": _received, "starved": _starved, "stalls": _stalls, "skipped": _skipped,
			"extra": _extra, "jitter": roundi(_clock.jitter_ms())}
	_received = 0
	_starved = 0
	_stalls = 0
	_skipped = 0
	_extra = 0
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


func _skip_oldest(count: int) -> void:
	for i in mini(count, _queue.size() - 1):
		var skipped: InputFrame = _queue.pop_front()
		_queue[0].buttons |= skipped.buttons
		_skipped += 1
