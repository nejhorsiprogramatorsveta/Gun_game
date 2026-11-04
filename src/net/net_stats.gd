class_name NetStats
extends RefCounted
## Client-only ping for the HUD (PLAN.md M4). Uses only data that already travels, so it
## adds no network messages: ping = time from sending an input until a host snapshot
## confirms it (`last_seq`), i.e. round trip + host input queue + up to one snapshot interval.

## Exponential smoothing (0..1, higher = faster reaction).
const SMOOTHING := 0.1
const MAX_TRACKED_INPUTS := 256

## seq -> send time (ms)
var _sent_ms: Dictionary[int, int] = {}
var _ping_ms := -1.0
var _last_acked_seq := -1


func record_input_sent(seq: int, now_ms: int) -> void:
	_sent_ms[seq] = now_ms
	if _sent_ms.size() > MAX_TRACKED_INPUTS:
		_sent_ms.erase(_sent_ms.keys()[0])


## Call once per applied snapshot with the newest input sequence the host has used.
func record_ack(last_seq: int, now_ms: int) -> void:
	if last_seq == _last_acked_seq or not _sent_ms.has(last_seq):
		return
	_last_acked_seq = last_seq
	var sample := float(now_ms - _sent_ms[last_seq])
	_ping_ms = sample if _ping_ms < 0.0 else lerpf(_ping_ms, sample, SMOOTHING)
	for seq in _sent_ms.keys():
		if not NetCodec.seq_newer(seq, last_seq):
			_sent_ms.erase(seq)


## -1 = not measured yet.
func ping_ms() -> int:
	return roundi(_ping_ms) if _ping_ms >= 0.0 else -1
