class_name HitPrediction
extends RefCounted
## Client: predicts the host's hits of other players' bullets on the own player, so the
## knockback starts at once instead of as a jump when the snapshot arrives (user 2026-11-13:
## "the character jerks after a hit").
## Every remote bullet is known from the host's spawn event, which carries the host tick it
## was fired on. The host moves a bullet once per tick from the next tick on, after the
## players moved, so its path segment at any host tick is known. The own player runs ahead
## on the host's timeline (every pending input has its host tick, MatchClient.tick_for), so
## each bullet is checked against the predicted position at the tick the host will check
## it - also for inputs predicted before the spawn event arrived (then the pending inputs
## are replayed from the hit, ClientPrediction.replay_from).
## A predicted hit is replayed after every reconciliation until a snapshot contains it: the
## host confirms each real hit on us with its tick and our last input it had simulated then
## (on_confirmed; a snapshot contains the hit once its tick is newer); a bullet removed
## without a confirmation missed (on_removed). Other players standing in the way are not taken into
## account (rare misprediction, corrected by the next snapshot).

## An unconfirmed hit this many inputs older than a snapshot is dropped as a miss (the
## host's confirmation arrives before that snapshot); allows for a tick estimate a bit off.
const UNCONFIRMED_TOLERANCE := 2
const UNCONFIRMED_TIMEOUT_MS := 1000
## Bullets are forgotten after this many ticks (the slowest flies ~2.5 s).
const MAX_SHOT_TICKS := 240
## The host simulates our inputs as they arrive, so the host tick of an input is only known
## to about one tick (MatchClient.tick_for). A bullet that misses the own body in its exact
## path segment is also checked one tick earlier and later before it counts as a miss.
const TICK_TOLERANCE := 1
## The host's real hit input is learned from its confirmations: a hit confirmed one input
## later than predicted means the host simulates our inputs a tick earlier than estimated,
## so the estimate is shifted by the average difference, adapting by this fraction per
## confirmed hit, within ±MAX_BIAS ticks.
const BIAS_ADAPT := 0.25
const MAX_BIAS := 2.0


class Shot:
	var id := 0
	var origin := Vector2.ZERO
	var direction := Vector2.RIGHT
	var weapon: WeaponData
	## Host tick of the spawn; the bullet first moves on the next tick.
	var tick := 0
	## Distance to the first wall or the range limit.
	var length := 0.0
	var team := Teams.NONE


class Hit:
	var id := 0
	## Own input after which the hit lands (the host applies hits after the players moved).
	var seq := 0
	var push := Vector2.ZERO
	var damage := 0.0
	var confirmed := false
	## Host tick of a confirmed hit (snapshots of later ticks contain it).
	var host_tick := -1
	var created_ms := 0


var _shots: Dictionary[int, Shot] = {}
var _hits: Array[Hit] = []
## Ticks to add to an input's estimated host tick for hit checks (see BIAS_ADAPT).
var tick_bias := 0.0


func add_shot(id: int, origin: Vector2, direction: Vector2, weapon: WeaponData, tick: int, team: int, length: float) -> void:
	var shot := Shot.new()
	shot.id = id
	shot.origin = origin
	shot.direction = direction.normalized()
	shot.weapon = weapon
	shot.tick = tick
	shot.length = length
	shot.team = team
	_shots[id] = shot


func shot_count() -> int:
	return _shots.size()


func pending_hits() -> int:
	return _hits.size()


## Path of a bullet during host tick `tick`: [from, to] distances along its direction, or
## an empty array when it does not fly then (not yet moving, or already ended).
static func segment_at(shot: Shot, tick: int) -> Array[float]:
	var n := tick - shot.tick
	var step := shot.weapon.projectile_speed / Engine.physics_ticks_per_second
	if n < 1 or (n - 1) * step >= shot.length:
		return []
	return [(n - 1) * step, minf(n * step, shot.length)]


## Checks every known bullet against the own pending inputs (history entries of
## ClientPrediction: input with its host tick, state after its movement). The exact tick's
## path segment is tried first for all inputs, then the neighbouring ticks' (TICK_TOLERANCE).
## New hits are stored; returns the index of the earliest entry with a new hit (replay from
## there), or -1.
func detect(player: Player, history: Array[Dictionary]) -> int:
	var earliest := -1
	var weight := player.character.weight if player.character else 1.0
	var newest_tick := -1
	for entry in history:
		newest_tick = maxi(newest_tick, (entry.input as InputFrame).tick)
	for shot_id in _shots.keys():
		var shot: Shot = _shots[shot_id]
		if Teams.allies(shot.team, player.team):
			_shots.erase(shot_id)
			continue
		for slack in TICK_TOLERANCE + 1:
			var index := _first_hit(shot, history, slack)
			if index >= 0:
				_add_hit(shot, (history[index].input as InputFrame).seq, weight)
				_shots.erase(shot_id)
				earliest = index if earliest < 0 else mini(earliest, index)
				break
	_forget_old_shots(newest_tick)
	return earliest


## First pending input whose body the bullet crosses, in its tick's path segment widened by
## `slack` ticks on both sides; -1 = none.
func _first_hit(shot: Shot, history: Array[Dictionary], slack: int) -> int:
	var bias := roundi(tick_bias)
	for i in history.size():
		var input: InputFrame = history[i].input
		var state: Dictionary = history[i].state
		if not state.get("active", true) or state.get("invulnerable", false):
			continue
		var first := segment_at(shot, input.tick + bias - slack)
		var last := segment_at(shot, input.tick + bias + slack)
		if first.is_empty() and last.is_empty():
			continue
		var from_distance: float = first[0] if not first.is_empty() else 0.0
		var to_distance: float = last[1] if not last.is_empty() else shot.length
		var body := Rect2(state.position - Player.BODY_SIZE / 2.0, Player.BODY_SIZE)
		if segment_hits_rect(shot.origin + shot.direction * from_distance, shot.origin + shot.direction * to_distance, body):
			return i
	return -1


## Applies the hits that land after the own input `seq` (Player.take_hit, like the host).
func apply_at(player: Player, seq: int) -> void:
	for hit in _hits:
		if hit.seq == seq:
			player.take_hit(hit.push, hit.damage)


## Reconciliation with the snapshot of host tick `snapshot_tick` whose state ends after the
## own input `last_seq` (bullets move after the snapshot is taken, so a hit of that same
## tick comes in the next one): forget hits the state contains or that missed, apply the
## ones that land up to and with last_seq; later ones replay with their inputs.
func apply_after_snapshot(player: Player, snapshot_tick: int, last_seq: int) -> void:
	var now := Time.get_ticks_msec()
	var kept: Array[Hit] = []
	for hit in _hits:
		var age := _seq_diff(hit.seq, last_seq)  # < 0: older than the snapshot's input
		if hit.confirmed and hit.host_tick < snapshot_tick:
			continue  # already in the host's state
		if not hit.confirmed and (age < -UNCONFIRMED_TOLERANCE or now - hit.created_ms > UNCONFIRMED_TIMEOUT_MS):
			continue  # the host did not hit
		kept.append(hit)
	_hits = kept
	for hit in _hits:
		if _seq_diff(hit.seq, last_seq) <= 0:
			player.take_hit(hit.push, hit.damage)


## The host hit us with bullet `id` at host tick `tick`, after it had simulated our input
## `seq`. A hit we did not predict is left to the snapshot (and the bullet is not predicted
## any more).
func on_confirmed(id: int, tick: int, seq: int) -> void:
	_shots.erase(id)
	for hit in _hits:
		if hit.id == id:
			if not hit.confirmed:
				tick_bias = clampf(tick_bias + BIAS_ADAPT * _seq_diff(hit.seq, seq), -MAX_BIAS, MAX_BIAS)
			hit.seq = seq
			hit.host_tick = tick
			hit.confirmed = true


## The host's bullet ended; without a confirmation it missed us.
func on_removed(id: int) -> void:
	_shots.erase(id)
	for i in range(_hits.size() - 1, -1, -1):
		if _hits[i].id == id and not _hits[i].confirmed:
			_hits.remove_at(i)


## After a death or respawn nothing predicted is valid any more.
func clear_hits() -> void:
	_hits.clear()


## Liang-Barsky: does the segment a-b touch the rectangle?
static func segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for edge in [[-d.x, a.x - rect.position.x], [d.x, rect.end.x - a.x], [-d.y, a.y - rect.position.y], [d.y, rect.end.y - a.y]]:
		var p: float = edge[0]
		var q: float = edge[1]
		if is_zero_approx(p):
			if q < 0.0:
				return false
			continue
		var r := q / p
		if p < 0.0:
			t0 = maxf(t0, r)
		else:
			t1 = minf(t1, r)
		if t0 > t1:
			return false
	return true


func _add_hit(shot: Shot, seq: int, weight: float) -> void:
	var hit := Hit.new()
	hit.id = shot.id
	hit.seq = seq
	hit.push = CombatRules.knockback(shot.direction, shot.weapon, weight)
	hit.damage = shot.weapon.damage
	hit.created_ms = Time.get_ticks_msec()
	_hits.append(hit)


func _forget_old_shots(newest_tick: int) -> void:
	if newest_tick < 0:
		return
	for shot_id in _shots.keys():
		var shot: Shot = _shots[shot_id]
		var flown := (newest_tick - shot.tick) * shot.weapon.projectile_speed / Engine.physics_ticks_per_second
		if newest_tick - shot.tick > MAX_SHOT_TICKS or flown > shot.length + shot.weapon.projectile_speed:
			_shots.erase(shot_id)


static func _seq_diff(a: int, b: int) -> int:
	return ((a - b + 0x8000) & 0xFFFF) - 0x8000
