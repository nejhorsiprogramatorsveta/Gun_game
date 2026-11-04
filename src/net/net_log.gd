class_name NetLog
extends RefCounted
## Writes one line of connection measurements to the game log (user://logs/godot.log) every
## INTERVAL_MS of a network match, so real sessions can be analysed afterwards (PLAN.md M4.1).
## Never logs addresses or names. Developer text, not player-facing, so it is not translated.
##   client: ping (last/max), FPS (now/min), longest pause between host snapshots,
##           largest correction of the own predicted character
##   host:   FPS (now/min), largest input queue per client slot

const INTERVAL_MS := 5000

var _window_start_ms := -1
var _fps_min := -1.0
var _ping_max := -1
var _snapshot_gap_max := 0
var _last_snapshot_ms := -1
var _correction_max := 0.0
## slot -> largest queued input count in this window (host)
var _queue_max: Dictionary[int, int] = {}


func record_snapshot_arrival(now_ms: int) -> void:
	if _last_snapshot_ms >= 0:
		_snapshot_gap_max = maxi(_snapshot_gap_max, now_ms - _last_snapshot_ms)
	_last_snapshot_ms = now_ms


## distance < 0 = nothing comparable (first snapshot, death, respawn).
func record_correction(distance: float) -> void:
	_correction_max = maxf(_correction_max, distance)


## Call every physics tick. ping_ms < 0 = not measured. inputs: peer_id -> InputBuffer (host).
## Returns the finished log line once per interval, otherwise "".
func tick(now_ms: int, is_host: bool, fps: float, ping_ms: int, inputs: Dictionary, players: Dictionary) -> String:
	if _window_start_ms < 0:
		_window_start_ms = now_ms
	_fps_min = fps if _fps_min < 0.0 else minf(_fps_min, fps)
	_ping_max = maxi(_ping_max, ping_ms)
	for peer_id: int in inputs:
		if players.has(peer_id):
			var slot: int = players[peer_id].slot
			_queue_max[slot] = maxi(_queue_max.get(slot, 0), inputs[peer_id].size())
	if now_ms - _window_start_ms < INTERVAL_MS:
		return ""
	var report: String
	if is_host:
		var queues: PackedStringArray = []
		for slot in _queue_max.keys():
			queues.append("slot%d=%d" % [slot, _queue_max[slot]])
		report = "[net] host fps=%d min=%d input_queue_max: %s" % [fps, _fps_min, ", ".join(queues)]
	else:
		report = "[net] client ping=%dms max=%dms fps=%d min=%d snapshot_gap_max=%dms correction_max=%.1fpx" \
				% [ping_ms, _ping_max, fps, _fps_min, _snapshot_gap_max, _correction_max]
	_window_start_ms = now_ms
	_fps_min = -1.0
	_ping_max = -1
	_snapshot_gap_max = 0
	_correction_max = 0.0
	_queue_max.clear()
	return report
