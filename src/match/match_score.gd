class_name MatchScore
extends RefCounted
## Authority-owned attribution: the last valid bullet earns the victim's next fall.

const MULTIKILL_WINDOW_MS := 2000

var _last_attacker: Dictionary[int, int] = {}
var _last_kill_ms: Dictionary[int, int] = {}
var _streaks: Dictionary[int, int] = {}


func record_hit(attacker: Player, victim: Player) -> void:
	if not victim.visible or victim.invulnerable:
		return
	if attacker == null:
		_last_attacker.erase(victim.peer_id)
		return
	if attacker.peer_id == victim.peer_id:
		return
	_last_attacker[victim.peer_id] = attacker.peer_id


func record_death(victim: Player, players: Dictionary[int, Player], time_ms: int) -> Dictionary:
	victim.deaths += 1
	var event := {"killer_slot": -1, "victim_slot": victim.slot,
			"kills": 0, "deaths": victim.deaths, "streak": 0}
	var attacker_id: int = _last_attacker.get(victim.peer_id, victim.peer_id)
	_last_attacker.erase(victim.peer_id)
	if attacker_id == victim.peer_id or not players.has(attacker_id):
		return event
	var attacker := players[attacker_id]
	attacker.kills += 1
	var streak := 1
	if _last_kill_ms.has(attacker_id):
		var elapsed := time_ms - _last_kill_ms[attacker_id]
		if elapsed >= 0 and elapsed <= MULTIKILL_WINDOW_MS:
			streak = _streaks[attacker_id] + 1
	_last_kill_ms[attacker_id] = time_ms
	_streaks[attacker_id] = streak
	event.killer_slot = attacker.slot
	event.kills = attacker.kills
	event.streak = streak
	return event


func remove_player(peer_id: int) -> void:
	_last_attacker.erase(peer_id)
	for victim_id in _last_attacker.keys():
		if _last_attacker[victim_id] == peer_id:
			_last_attacker.erase(victim_id)
	_last_kill_ms.erase(peer_id)
	_streaks.erase(peer_id)
