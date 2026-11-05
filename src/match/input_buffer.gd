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

## Hard cap: older inputs beyond this are skipped right away.
const MAX_PENDING := 6
## Inputs to keep queued at the start of a tick (1 = the one consumed this tick).
const TARGET := 1
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


## frames are newest first (NetCodec.decode_input); queues the unseen ones, oldest first.
func push(frames: Array[InputFrame]) -> void:
	for i in range(frames.size() - 1, -1, -1):
		var frame := frames[i]
		var is_first_packet := _newest_seq == -1
		if (is_first_packet and i == 0) or (not is_first_packet and NetCodec.seq_newer(frame.seq, _newest_seq)):
			_queue.append(frame)
			_newest_seq = frame.seq
	_skip_oldest(_queue.size() - MAX_PENDING)


## The input for this tick; if the client's packets are late, its last input repeats.
func next() -> InputFrame:
	_window_min = mini(_window_min, _queue.size())
	_window_ticks += 1
	if _window_ticks >= WINDOW_TICKS:
		_skip_oldest(_window_min - TARGET)
		_window_ticks = 0
		_window_min = MAX_PENDING
	if not _queue.is_empty():
		_current = _queue.pop_front()
		_ticks_without_input = 0
		return _current
	_ticks_without_input += 1
	if _ticks_without_input > STALE_TICKS:
		# Stop moving and shooting, but keep held jump/ability/down so the next real input is
		# not seen as a fresh press (an unwanted jump or ability after a short stall).
		_current = InputFrame.create(0, _current.buttons & ~InputFrame.FIRE, _current.aim, _current.seq)
	return _current


func size() -> int:
	return _queue.size()


func _skip_oldest(count: int) -> void:
	for i in mini(count, _queue.size() - 1):
		var skipped: InputFrame = _queue.pop_front()
		_queue[0].buttons |= skipped.buttons
