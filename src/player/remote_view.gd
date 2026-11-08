class_name RemoteView
extends RefCounted
## How a player controlled on another computer is shown (M4.1): every received state is
## placed on the player's own playback timeline (SnapshotTimeline) and played back smoothly.
##   Client, remote players: receive() each snapshot, sample_state() gives what to show.
##   Host, client-controlled players: record() after each simulated input, display_offset()
##   draws them on the client's input timeline (simulation and hits keep the real position).

## null = plain interpolation by arrival time (RemoteInterpolator.INTERPOLATION_DELAY_MS).
var timeline: SnapshotTimeline

var _interpolator: RemoteInterpolator
var _display: RemoteInterpolator
var _last_state_time := -INF
var _last_state_active := false


func _init(player_timeline: SnapshotTimeline = null) -> void:
	timeline = player_timeline


## Client: queue a host snapshot of this player. The host's own player is placed at the
## snapshot's host time, client-controlled players at their own input time.
func receive(state: Dictionary, host_time_ms: float, is_host_player: bool) -> void:
	if _interpolator == null:
		_interpolator = RemoteInterpolator.new(0 if timeline else RemoteInterpolator.INTERPOLATION_DELAY_MS)
	if timeline == null:
		_interpolator.push(host_time_ms, state)
		return
	var time_ms := host_time_ms if is_host_player else timeline.seq_ms(state.last_seq)
	if time_ms <= _last_state_time:
		if state.active == _last_state_active:
			return  # the host is waiting for this player's next input: nothing new to show
		time_ms = _last_state_time + 1.0  # e.g. died on the same input: show it right after
	else:
		timeline.observe_ms(time_ms, Time.get_ticks_msec())
	_last_state_time = time_ms
	_last_state_active = state.active
	_interpolator.push(time_ms, state)


## Host: remember where the player is after this tick's inputs (input `seq`).
func record(seq: int, position: Vector2, velocity: Vector2) -> void:
	if timeline == null:
		return
	if _display == null:
		_display = RemoteInterpolator.new(0)
	var time_ms := timeline.seq_ms(seq)
	if time_ms <= _last_state_time:
		return
	timeline.observe_ms(time_ms, Time.get_ticks_msec())
	_last_state_time = time_ms
	_display.push(time_ms, {"position": position, "velocity": velocity, "active": true})


## Every frame, before sampling.
func update(delta: float) -> void:
	if timeline:
		timeline.update(delta)


## Client: the state to show now ({} = nothing received yet).
func sample_state(now_ms: int) -> Dictionary:
	if _interpolator == null:
		return {}
	return _interpolator.sample(timeline.render_time(now_ms) if timeline else float(now_ms))


func has_display() -> bool:
	return _display != null


## Host: where to draw the player relative to its simulated position (ZERO if nothing is
## recorded yet or the gap looks like a teleport, e.g. a respawn).
func display_offset(now_ms: int, position: Vector2) -> Vector2:
	var shown := _display.sample(timeline.render_time(now_ms))
	if shown.is_empty():
		return Vector2.ZERO
	var offset: Vector2 = (shown.position as Vector2) - position
	return offset if offset.length() < RemoteInterpolator.TELEPORT_DISTANCE else Vector2.ZERO
