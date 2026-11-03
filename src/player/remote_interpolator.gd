class_name RemoteInterpolator
extends RefCounted
## Smooth display of a player simulated on the host. Snapshots arrive ~30 times a second
## with jitter, so the player is shown INTERPOLATION_DELAY_MS in the past and its position
## is blended between the two surrounding snapshots (PLAN.md D.4).

const INTERPOLATION_DELAY_MS := 100
## The client's own player only needs to cover one snapshot interval (33 ms), not network
## jitter of other players, so a shorter delay makes the controls feel much more direct.
const OWN_PLAYER_DELAY_MS := 40
const MAX_BUFFERED := 20
## Bigger jumps (e.g. a respawn) are shown instantly instead of sliding across the arena.
const TELEPORT_DISTANCE := 200.0

## [{time: int (local ms), state: Dictionary}], oldest first.
var _buffer: Array[Dictionary] = []
var _delay_ms := INTERPOLATION_DELAY_MS


func _init(delay_ms: int = INTERPOLATION_DELAY_MS) -> void:
	_delay_ms = delay_ms


func push(time_ms: int, state: Dictionary) -> void:
	_buffer.append({"time": time_ms, "state": state})
	if _buffer.size() > MAX_BUFFERED:
		_buffer.pop_front()


## Returns the state to display at `now_ms`, or an empty dictionary before the first snapshot.
func sample(now_ms: int) -> Dictionary:
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
	return _buffer[-1].state  # no newer data yet: hold the last known state


static func _blend(older: Dictionary, newer: Dictionary, render_time: int) -> Dictionary:
	var a: Dictionary = older.state
	var b: Dictionary = newer.state
	var a_position: Vector2 = a.position
	var b_position: Vector2 = b.position
	if a.active != b.active or a_position.distance_to(b_position) > TELEPORT_DISTANCE:
		return b
	var weight := float(render_time - older.time) / float(maxi(newer.time - older.time, 1))
	var blended := b.duplicate()
	blended.position = a_position.lerp(b_position, weight)
	return blended
