class_name ClientPrediction
extends RefCounted
## Own-player movement only: retain unacknowledged inputs, restore host state, replay.
## Combat, lives and respawns are always decided by the host; hits of other players' bullets
## on us are predicted by HitPrediction and replayed here with the inputs they follow.

const MAX_PENDING_INPUTS := 120
const MAX_SMOOTH_DISTANCE := 200.0

var _ready := false
var _last_discarded_seq := -1
## Oldest first. Saved states describe the predicted result of each numbered input, after
## its movement but before the hits that land after it (HitPrediction.apply_at).
var _history: Array[Dictionary] = []


## The pending inputs (read only): {"input", "delta", "state"}.
func history() -> Array[Dictionary]:
	return _history


## Returns true when the input was simulated (then player.fired_this_tick is current).
func predict(player: Player, input: InputFrame, delta: float, frozen: bool) -> bool:
	if not _ready or not player.visible:
		return false
	var movement := InputFrame.create(0, 0, input.aim, input.seq) if frozen else input
	movement.tick = input.tick
	player.simulate(movement, delta)
	_history.append({"input": movement, "delta": delta, "state": player.snapshot_state()})
	if _history.size() > MAX_PENDING_INPUTS:
		var discarded: Dictionary = _history.pop_front()
		_last_discarded_seq = discarded.input.seq
	return true


## Returns how far the prediction was off (px), or -1 when there was nothing to compare
## (first snapshot, death, respawn or a lost timeline). tick_for(seq) gives the host tick of
## an input (moving platforms are replayed where they were); empty = no world time.
## hits: predicted hits on us, applied after the inputs they follow (null = none);
## snapshot_tick: the snapshot's host tick (which hits it already contains).
func reconcile(player: Player, state: Dictionary, tick_for: Callable = Callable(), hits: HitPrediction = null,
		snapshot_tick: int = 0) -> float:
	var old_position := player.position
	var old_display_position := player.position + player.visual_offset
	var old_damage := player.damage
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
	if tick_for.is_valid():
		player.world_tick = tick_for.call(state.last_seq)
	if hits:
		if discontinuity or not state.active:
			hits.clear_hits()
		hits.apply_after_snapshot(player, snapshot_tick, state.last_seq)
	for entry in _history:
		if tick_for.is_valid():
			entry.input.tick = tick_for.call(entry.input.seq)
		player.simulate(entry.input, entry.delta)
		entry.state = player.snapshot_state()
		if hits:
			hits.apply_at(player, entry.input.seq)
	var correction := old_display_position - player.position
	player.visual_offset = correction if not discontinuity and correction.length() < MAX_SMOOTH_DISTANCE else Vector2.ZERO
	# More damage on the host than predicted = a hit we could not predict.
	if state.damage > old_damage + 0.01:
		player.visual_smoothing = Player.HIT_SMOOTHING  # until the offset has faded
	return -1.0 if discontinuity or not state.active else old_position.distance_to(player.position)


## A hit was predicted after the pending input `index` (HitPrediction.detect, possibly for
## an input sent before the bullet was known): rewind to that input's state, apply its hits
## and replay the newer inputs. The shown position moves smoothly (visual offset).
func replay_from(player: Player, index: int, hits: HitPrediction) -> void:
	if index < 0 or index >= _history.size():
		return
	var old_display_position := player.position + player.visual_offset
	var start: Dictionary = _history[index]
	player.restore_state(start.state)
	player.world_tick = start.input.tick
	hits.apply_at(player, start.input.seq)
	for i in range(index + 1, _history.size()):
		var entry: Dictionary = _history[i]
		player.simulate(entry.input, entry.delta)
		entry.state = player.snapshot_state()
		hits.apply_at(player, entry.input.seq)
	var correction := old_display_position - player.position
	player.visual_offset = correction if correction.length() < MAX_SMOOTH_DISTANCE else Vector2.ZERO
	player.visual_smoothing = Player.HIT_SMOOTHING  # a hit found late: glide into the throw
