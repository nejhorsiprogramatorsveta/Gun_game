extends TestCase


func _player(peer_id: int, slot: int) -> Player:
	var player := Player.new()
	player.peer_id = peer_id
	player.slot = slot
	return player


func test_latest_bullet_gets_credit_without_timeout() -> void:
	var first := _player(1, 0)
	var last := _player(20, 1)
	var victim := _player(30, 2)
	var players: Dictionary[int, Player] = {1: first, 20: last, 30: victim}
	var score := MatchScore.new()
	score.record_hit(first, victim)
	score.record_hit(last, victim)
	var event := score.record_death(victim, players, 60000)
	check_eq(event, {"killer_slot": 1, "victim_slot": 2, "kills": 1, "deaths": 1, "streak": 1}, "last bullet earns the fall even much later")
	check_eq(first.kills, 0, "earlier shooter gets no kill")
	check_eq(last.kills, 1, "credited shooter total increases")
	for player in players.values():
		player.free()


func test_unassisted_and_self_hits_only_count_deaths() -> void:
	var victim := _player(1, 0)
	var players: Dictionary[int, Player] = {1: victim}
	var score := MatchScore.new()
	var event := score.record_death(victim, players, 0)
	check_eq(event, {"killer_slot": -1, "victim_slot": 0, "kills": 0, "deaths": 1, "streak": 0}, "unassisted fall has no killer")
	score.record_hit(victim, victim)
	score.record_death(victim, players, 100)
	check_eq([victim.kills, victim.deaths], [0, 2], "self hits cannot earn kills")
	victim.free()


func test_invalid_hits_do_not_replace_last_valid_shooter() -> void:
	var first := _player(1, 0)
	var other := _player(2, 1)
	var victim := _player(3, 2)
	var players: Dictionary[int, Player] = {1: first, 2: other, 3: victim}
	var score := MatchScore.new()
	score.record_hit(first, victim)
	victim.invulnerable = true
	score.record_hit(other, victim)
	victim.invulnerable = false
	victim.visible = false
	score.record_hit(other, victim)
	victim.visible = true
	score.record_hit(victim, victim)
	check_eq(score.record_death(victim, players, 0).killer_slot, first.slot, "protected, hidden and self hits preserve last valid shooter")
	for player in players.values():
		player.free()


func test_death_consumes_credit_before_next_life() -> void:
	var attacker := _player(1, 0)
	var victim := _player(2, 1)
	var players: Dictionary[int, Player] = {1: attacker, 2: victim}
	var score := MatchScore.new()
	score.record_hit(attacker, victim)
	score.record_death(victim, players, 0)
	victim.reset_to(Vector2.ZERO)
	check_eq(score.record_death(victim, players, 100).killer_slot, -1, "respawn cannot reuse a previous life's hit")
	check_eq([attacker.kills, victim.deaths], [1, 2], "each fall is counted once per call")
	score.record_hit(attacker, victim)
	check_eq(score.record_death(victim, players, 200).kills, 2, "new-life hit earns a fresh kill")
	for player in players.values():
		player.free()


func test_absent_shooter_has_no_credit_but_dead_shooter_does() -> void:
	var attacker := _player(1, 0)
	var victim := _player(2, 1)
	var players: Dictionary[int, Player] = {1: attacker, 2: victim}
	var score := MatchScore.new()
	score.record_hit(attacker, victim)
	players.erase(attacker.peer_id)
	check_eq(score.record_death(victim, players, 0).killer_slot, -1, "disconnected shooter cannot earn credit")
	players[attacker.peer_id] = attacker
	score.record_hit(attacker, victim)
	attacker.set_active(false)
	attacker.lives = 0
	check_eq(score.record_death(victim, players, 100).killer_slot, attacker.slot, "posthumous kill still counts")
	for player in players.values():
		player.free()


func test_departed_shooter_bullet_clears_only_valid_hit_attribution() -> void:
	var attacker := _player(1, 0)
	var victim := _player(2, 1)
	var players: Dictionary[int, Player] = {1: attacker, 2: victim}
	var score := MatchScore.new()
	score.record_hit(attacker, victim)
	victim.invulnerable = true
	score.record_hit(null, victim)
	victim.invulnerable = false
	victim.visible = false
	score.record_hit(null, victim)
	victim.visible = true
	check_eq(score.record_death(victim, players, 0).killer_slot, attacker.slot, "ignored bullets from departed shooter preserve earlier valid attribution")
	score.record_hit(attacker, victim)
	score.record_hit(null, victim)
	check_eq(score.record_death(victim, players, 100).killer_slot, -1, "departed shooter's valid last bullet removes the earlier shooter's credit")
	check_eq(attacker.kills, 1, "earlier shooter does not earn credit for departed shooter's bullet")
	for player in players.values():
		player.free()


func test_multikills_follow_consecutive_kill_window() -> void:
	var attacker := _player(1, 0)
	var victim := _player(2, 1)
	var players: Dictionary[int, Player] = {1: attacker, 2: victim}
	var score := MatchScore.new()
	var times := [0, 0, 2000, 4000, 6001]
	var streaks := [1, 2, 3, 4, 1]
	for index in times.size():
		score.record_hit(attacker, victim)
		var event := score.record_death(victim, players, times[index])
		check_eq(event.streak, streaks[index], "simultaneous and consecutive kills share a streak until a gap exceeds two seconds")
	check_eq(attacker.kills, 5, "streak reset does not reset total kills")
	for player in players.values():
		player.free()


func test_removal_clears_attribution_and_streak_for_rejoined_peer() -> void:
	var attacker := _player(1, 0)
	var victim := _player(2, 1)
	var players: Dictionary[int, Player] = {1: attacker, 2: victim}
	var score := MatchScore.new()
	score.record_hit(attacker, victim)
	score.record_death(victim, players, 0)
	score.record_hit(attacker, victim)
	score.remove_player(attacker.peer_id)
	check_eq(score.record_death(victim, players, 100).killer_slot, -1, "removing shooter clears references even if its peer id returns")
	score.record_hit(attacker, victim)
	check_eq(score.record_death(victim, players, 200).streak, 1, "returning peer starts a fresh streak")
	score.record_hit(attacker, victim)
	score.remove_player(victim.peer_id)
	check_eq(score.record_death(victim, players, 300).killer_slot, -1, "removing victim clears its pending attribution")
	for player in players.values():
		player.free()


func test_new_match_starts_without_pending_credit() -> void:
	var attacker := _player(1, 0)
	var victim := _player(2, 1)
	var players: Dictionary[int, Player] = {1: attacker, 2: victim}
	var score := MatchScore.new()
	score.record_hit(attacker, victim)
	var next_match := MatchScore.new()
	check_eq(next_match.record_death(victim, players, 0).killer_slot, -1, "new match never inherits attribution")
	for player in players.values():
		player.free()
