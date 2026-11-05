class_name NetLog
extends RefCounted
## Connection measurements of a network match in the game log (user://logs/godot.log), one
## line every INTERVAL_MS plus an immediate line for each big snapshot gap, so real play
## sessions can be analysed afterwards (PLAN.md M4.1, docs/PLAYTEST.md). Lines carry the
## wall-clock time (DiagLog). Never logs addresses or names. Developer text: not translated.
##   client: ping (input ack; last/avg/max), ENet RTT/variance/loss/throttle to the host,
##           snapshots received/dropped, largest gap and gaps > GAP_MS, own corrections,
##           FPS, longest pause between physics ticks and hitches (> HITCH_MS)
##   host:   FPS, tick pauses, and per client slot: ENet RTT/variance/loss, input queue
##           max, inputs received, ticks without input (starved), stalls (> 0.25 s without
##           input) and inputs skipped by the catch-up

const INTERVAL_MS := 5000
## A snapshot gap above this counts as a lag spike and is logged right away.
const SPIKE_MS := 250
const GAP_MS := 100
const HITCH_MS := 50
const CORRECTION_PX := 8.0
## Immediate spike lines per interval at most (a long freeze must not flood the log).
const MAX_SPIKE_LINES := 5

## Callable(peer_id) -> {"rtt", "rtt_var", "loss", "throttle"} (EnetDirectConnector.peer_stats);
## left empty in unit tests.
var peer_stats := Callable()

var _window_start_ms := -1
var _fps_min := -1.0
var _ping_max := -1
var _ping_sum := 0
var _ping_samples := 0
var _snapshots := 0
var _snapshots_dropped := 0
var _snapshot_gap_max := 0
var _snapshot_gaps := 0
var _last_snapshot_ms := -1
var _correction_max := 0.0
var _corrections := 0
var _last_tick_ms := -1
var _tick_gap_max := 0
var _hitches := 0
var _spike_lines := 0
## slot -> largest queued input count in this window (host)
var _queue_max: Dictionary[int, int] = {}


func record_snapshot_arrival(now_ms: int) -> void:
	_snapshots += 1
	if _last_snapshot_ms >= 0:
		var gap := now_ms - _last_snapshot_ms
		_snapshot_gap_max = maxi(_snapshot_gap_max, gap)
		if gap > GAP_MS:
			_snapshot_gaps += 1
		if gap > SPIKE_MS and _spike_lines < MAX_SPIKE_LINES:
			_spike_lines += 1
			print(DiagLog.line("net", "client spike: no snapshot for %dms" % gap))
	_last_snapshot_ms = now_ms


## A snapshot that arrived too late (older than or equal to one already applied).
func record_snapshot_dropped() -> void:
	_snapshots_dropped += 1


## distance < 0 = nothing comparable (first snapshot, death, respawn).
func record_correction(distance: float) -> void:
	_correction_max = maxf(_correction_max, distance)
	if distance > CORRECTION_PX:
		_corrections += 1


## Call every physics tick. ping_ms < 0 = not measured. inputs: peer_id -> InputBuffer (host).
## Returns the finished log line once per interval, otherwise "".
func tick(now_ms: int, is_host: bool, fps: float, ping_ms: int, inputs: Dictionary, players: Dictionary) -> String:
	if _window_start_ms < 0:
		_window_start_ms = now_ms
	if _last_tick_ms >= 0:
		var pause := now_ms - _last_tick_ms
		_tick_gap_max = maxi(_tick_gap_max, pause)
		if pause > HITCH_MS:
			_hitches += 1
	_last_tick_ms = now_ms
	_fps_min = fps if _fps_min < 0.0 else minf(_fps_min, fps)
	_ping_max = maxi(_ping_max, ping_ms)
	if ping_ms >= 0:
		_ping_sum += ping_ms
		_ping_samples += 1
	for peer_id: int in inputs:
		if players.has(peer_id):
			var slot: int = players[peer_id].slot
			_queue_max[slot] = maxi(_queue_max.get(slot, 0), inputs[peer_id].size())
	if now_ms - _window_start_ms < INTERVAL_MS:
		return ""
	var frame := "fps=%d min=%d tick_gap_max=%dms hitches=%d" % [fps, _fps_min, _tick_gap_max, _hitches]
	var report: String
	if is_host:
		var slots: PackedStringArray = []
		for peer_id: int in inputs:
			if players.has(peer_id):
				slots.append(_host_slot_text(peer_id, players[peer_id].slot, inputs[peer_id]))
		report = "host %s | %s" % [frame, " | ".join(slots)]
	else:
		report = "client ping=%dms avg=%dms max=%dms %s snapshots=%d dropped=%d gap_max=%dms gaps>%dms=%d correction_max=%.1fpx corrections>%dpx=%d %s" % [
			ping_ms, _ping_sum / maxi(_ping_samples, 1), _ping_max, _enet_text(1), _snapshots, _snapshots_dropped,
			_snapshot_gap_max, GAP_MS, _snapshot_gaps, _correction_max, CORRECTION_PX, _corrections, frame]
	_reset(now_ms)
	return DiagLog.line("net", report)


func _host_slot_text(peer_id: int, slot: int, buffer: Object) -> String:
	var text := "slot%d %s queue_max=%d" % [slot, _enet_text(peer_id), _queue_max.get(slot, 0)]
	if buffer.has_method("take_stats"):
		var stats: Dictionary = buffer.take_stats()
		text += " inputs=%d starved=%d stalls=%d skipped=%d" % [stats.received, stats.starved, stats.stalls, stats.skipped]
	return text


func _enet_text(peer_id: int) -> String:
	if not peer_stats.is_valid():
		return "enet=n/a"
	var stats: Dictionary = peer_stats.call(peer_id)
	if stats.is_empty():
		return "enet=n/a"
	return "rtt=%dms var=%dms loss=%.1f%% throttle=%d/32" % [stats.rtt, stats.rtt_var, stats.loss, stats.throttle]


func _reset(now_ms: int) -> void:
	_window_start_ms = now_ms
	_fps_min = -1.0
	_ping_max = -1
	_ping_sum = 0
	_ping_samples = 0
	_snapshots = 0
	_snapshots_dropped = 0
	_snapshot_gap_max = 0
	_snapshot_gaps = 0
	_correction_max = 0.0
	_corrections = 0
	_tick_gap_max = 0
	_hitches = 0
	_spike_lines = 0
	_queue_max.clear()
