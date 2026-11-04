class_name NetStats
extends RefCounted
## Client-only connection measurements for the debug overlay (PLAN.md M4, M4.1).
## Uses only data that already travels: input sequence numbers and snapshot arrivals,
## so it adds no network messages. "Input ack" = time from sending an input until a
## snapshot confirms the host used it (RTT + host input queue + up to one snapshot interval).

## Peak values are taken over this window.
const WINDOW_MS := 2000
## Exponential smoothing of the averages (0..1, higher = faster reaction).
const SMOOTHING := 0.1
const MAX_TRACKED_INPUTS := 256

## seq -> send time (ms)
var _sent_ms: Dictionary[int, int] = {}
var _ack_ms := -1.0
var _ack_jitter_ms := 0.0
var _last_acked_seq := -1
var _last_snapshot_ms := -1
var _snapshot_gap_ms := -1.0
var _last_correction_px := 0.0
## [{time, value}] for the windowed maxima.
var _gap_peaks: Array[Dictionary] = []
var _correction_peaks: Array[Dictionary] = []


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
	if _ack_ms < 0.0:
		_ack_ms = sample
	else:
		_ack_jitter_ms = lerpf(_ack_jitter_ms, absf(sample - _ack_ms), SMOOTHING)
		_ack_ms = lerpf(_ack_ms, sample, SMOOTHING)
	for seq in _sent_ms.keys():
		if not NetCodec.seq_newer(seq, last_seq):
			_sent_ms.erase(seq)


func record_snapshot_arrival(now_ms: int) -> void:
	if _last_snapshot_ms >= 0:
		var gap := float(now_ms - _last_snapshot_ms)
		_snapshot_gap_ms = gap if _snapshot_gap_ms < 0.0 else lerpf(_snapshot_gap_ms, gap, SMOOTHING)
		_gap_peaks.append({"time": now_ms, "value": gap})
	_last_snapshot_ms = now_ms


## distance < 0 = no comparable prediction (first snapshot, death or respawn).
func record_correction(distance: float, now_ms: int) -> void:
	if distance < 0.0:
		return
	_last_correction_px = distance
	_correction_peaks.append({"time": now_ms, "value": distance})


## Values < 0 mean "not measured yet".
func summary(now_ms: int) -> Dictionary:
	return {
		"ack_ms": roundi(_ack_ms) if _ack_ms >= 0.0 else -1,
		"jitter_ms": roundi(_ack_jitter_ms),
		"snapshot_gap_ms": roundi(_snapshot_gap_ms) if _snapshot_gap_ms >= 0.0 else -1,
		"snapshot_gap_max_ms": roundi(_peak(_gap_peaks, now_ms)),
		"correction_px": snappedf(_last_correction_px, 0.1),
		"correction_max_px": snappedf(_peak(_correction_peaks, now_ms), 0.1),
	}


static func _peak(samples: Array[Dictionary], now_ms: int) -> float:
	while not samples.is_empty() and now_ms - int(samples[0].time) > WINDOW_MS:
		samples.pop_front()
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, sample.value)
	return peak
