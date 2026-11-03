class_name LagSimulator
extends RefCounted
## Debug only: makes this computer's match traffic behave like a bad internet connection,
## so online play can be tested with two game windows on one PC (PLAN.md D.11).
## Start with `-- --fake-lag=100 --fake-loss=5 [--fake-jitter=10]`:
##   fake-lag   = extra round-trip time in ms (half is added to each direction),
##   fake-loss  = percent of packets dropped, fake-jitter = random ± ms per packet.
## Ignored in release exports. Only match inputs/snapshots are affected (they are the
## unreliable, timing-critical traffic); lobby messages stay instant.

var rtt_ms := 0
var jitter_ms := 0
var loss_percent := 0.0

## [{time: int, action: Callable}] with non-decreasing time, like an ordered channel.
var _queue: Array[Dictionary] = []
var _last_delivery_ms := 0


static func from_command_line() -> LagSimulator:
	var simulator := LagSimulator.new()
	if not OS.is_debug_build():
		return simulator
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--fake-lag="):
			simulator.rtt_ms = maxi(value.to_int(), 0)
			simulator.jitter_ms = simulator.rtt_ms / 10
		elif arg.begins_with("--fake-loss="):
			simulator.loss_percent = clampf(value.to_float(), 0.0, 100.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fake-jitter="):
			simulator.jitter_ms = maxi(arg.get_slice("=", 1).to_int(), 0)
	return simulator


func is_enabled() -> bool:
	return rtt_ms > 0 or loss_percent > 0.0


## Runs `action` (sending or handling one packet) now, later, or never.
func run(action: Callable) -> void:
	if not is_enabled():
		action.call()
		return
	if randf() * 100.0 < loss_percent:
		return
	var delivery := Time.get_ticks_msec() + rtt_ms / 2 + randi_range(-jitter_ms, jitter_ms)
	# Never deliver before an earlier packet: the real channels are ordered.
	_last_delivery_ms = maxi(delivery, _last_delivery_ms)
	_queue.append({"time": _last_delivery_ms, "action": action})


## Call every frame: performs the actions whose time has come.
func flush() -> void:
	var now := Time.get_ticks_msec()
	while not _queue.is_empty() and _queue[0].time <= now:
		var action: Callable = _queue.pop_front().action
		action.call()
