class_name JitterClock
extends RefCounted
## Maps a sender's timeline (host ticks / client input sequence numbers, both 60 per second)
## to local time and measures how late packets arrive (PLAN.md M4.1, play tests 2026-11-05:
## Wi-Fi delivered packets in bunches every ~100-150 ms).
## The earliest arrival in the last WINDOW_MS defines "on time" (base offset); every other
## packet is that much "late". The 90th percentile of lateness is the jitter that receivers
## must buffer to stay smooth. Clock drift and route changes are followed by the window.

const WINDOW_MS := 4000
const PERCENTILE := 0.9

## [[arrival_ms, offset_ms], ...] oldest first.
var _samples: Array = []
var _base_offset := 0.0
var _jitter := 0.0


## `sender_ms`: the sender's own time of the packet (tick * 1000 / ticks per second).
func observe(sender_ms: float, arrival_ms: int) -> void:
	_samples.append([arrival_ms, arrival_ms - sender_ms])
	while _samples.size() > 1 and arrival_ms - int(_samples[0][0]) > WINDOW_MS:
		_samples.pop_front()
	var offsets: Array[float] = []
	_base_offset = INF
	for sample in _samples:
		_base_offset = minf(_base_offset, sample[1])
		offsets.append(sample[1])
	offsets.sort()
	_jitter = offsets[mini(int(offsets.size() * PERCENTILE), offsets.size() - 1)] - _base_offset


func has_data() -> bool:
	return not _samples.is_empty()


func sample_count() -> int:
	return _samples.size()


## Local time minus this = the sender's time of a packet that arrived without delay.
func base_offset() -> float:
	return _base_offset


## 90th percentile of how late packets arrive compared with the fastest one (ms).
func jitter_ms() -> float:
	return _jitter


## The sender's time that corresponds to local `now_ms` (for an undelayed packet).
func sender_time(now_ms: int) -> float:
	return now_ms - _base_offset
