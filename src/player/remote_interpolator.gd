class_name RemoteInterpolator
extends RefCounted
## Smooth display of a player simulated on the host. Snapshots arrive ~30 times a second
## with jitter, so the player is shown in the past and its position is blended between the
## two surrounding snapshots (PLAN.md D.4). In matches the times are the HOST's tick times
## and the display time comes from SnapshotTimeline (adaptive delay, delay_ms = 0 here).

const INTERPOLATION_DELAY_MS := 100
const MAX_BUFFERED := 20
## Bigger jumps (e.g. a respawn) are shown instantly instead of sliding across the arena.
const TELEPORT_DISTANCE := 200.0

## Diagnostics (NetLog): frames in which a remote player had to be held at its last known
## state because no newer snapshot had arrived (visible as stutter). Shared by all players.
static var hold_frames := 0

## [{time: float (ms), state: Dictionary}], oldest first.
var _buffer: Array[Dictionary] = []
var _delay_ms := INTERPOLATION_DELAY_MS


func _init(delay_ms: int = INTERPOLATION_DELAY_MS) -> void:
	_delay_ms = delay_ms


func push(time_ms: float, state: Dictionary) -> void:
	_buffer.append({"time": time_ms, "state": state})
	if _buffer.size() > MAX_BUFFERED:
		_buffer.pop_front()


## Returns the state to display at `now_ms`, or an empty dictionary before the first snapshot.
func sample(now_ms: float) -> Dictionary:
	if _buffer.is_empty():
		return {}
	var render_time := now_ms - _delay_ms
	if render_time <= _buffer[0].time:
		return _buffer[0].state
	for i in range(_buffer.size() - 1):
		var older: Dictionary = _buffer[i]
		var newer: Dictionary = _buffer[i + 1]
		if render_time < newer.time:
			return _blend(older, newer, render_time)
	hold_frames += 1
	return _buffer[-1].state  # no newer data yet: hold the last known state


static func _blend(older: Dictionary, newer: Dictionary, render_time: float) -> Dictionary:
	var a: Dictionary = older.state
	var b: Dictionary = newer.state
	var a_position: Vector2 = a.position
	var b_position: Vector2 = b.position
	if a.active != b.active or a_position.distance_to(b_position) > TELEPORT_DISTANCE:
		return b
	var weight := float(render_time - older.time) / maxf(float(newer.time - older.time), 1.0)
	var blended := b.duplicate()
	blended.position = a_position.lerp(b_position, weight)
	return blended
