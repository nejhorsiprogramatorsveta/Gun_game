class_name ClientPrediction
extends RefCounted
## Own-player movement only: retain unacknowledged inputs, restore host state, replay.
## Combat, lives and respawns are always decided by the host.

const MAX_PENDING_INPUTS := 120
const MAX_SMOOTH_DISTANCE := 200.0

var _ready := false
var _last_discarded_seq := -1
## Oldest first. Saved states describe the predicted result of each numbered input.
var _history: Array[Dictionary] = []


## Returns true when the input was simulated (then player.fired_this_tick is current).
func predict(player: Player, input: InputFrame, delta: float, frozen: bool) -> bool:
	if not _ready or not player.visible:
		return false
	var movement := InputFrame.create(0, 0, input.aim, input.seq) if frozen else input
	player.simulate(movement, delta)
	_history.append({"input": movement, "delta": delta, "state": player.snapshot_state()})
	if _history.size() > MAX_PENDING_INPUTS:
		var discarded: Dictionary = _history.pop_front()
		_last_discarded_seq = discarded.input.seq
	return true


## Returns how far the prediction was off (px), or -1 when there was nothing to compare
## (first snapshot, death, respawn or a lost timeline).
func reconcile(player: Player, state: Dictionary) -> float:
	var old_position := player.position
	var old_display_position := player.position + player.visual_offset
	var discontinuity: bool = not _ready or player.visible != state.active or player.lives != state.lives
	_ready = true
	# After a long outage the acknowledged input may have fallen out of the bounded
	# history. Start from the host rather than replaying an incomplete timeline.
	if _last_discarded_seq >= 0 and NetCodec.seq_newer(_last_discarded_seq, state.last_seq):
		discontinuity = true
	_last_discarded_seq = -1
	if discontinuity or not state.active:
		_history.clear()
	else:
		while not _history.is_empty():
			var input: InputFrame = _history[0].input
			if NetCodec.seq_newer(input.seq, state.last_seq):
				break
			_history.pop_front()
	player.restore_state(state)
	for entry in _history:
		player.simulate(entry.input, entry.delta)
		entry.state = player.snapshot_state()
	var correction := old_display_position - player.position
	player.visual_offset = correction if not discontinuity and correction.length() < MAX_SMOOTH_DISTANCE else Vector2.ZERO
	return -1.0 if discontinuity or not state.active else old_position.distance_to(player.position)
