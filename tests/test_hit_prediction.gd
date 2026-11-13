extends TestCase
## Predicted hits of other players' bullets on the own player (user 2026-11-13: "the
## character jerks after a hit").

const DELTA := 1.0 / 60.0


func _shot(hits: HitPrediction, id: int, origin: Vector2, tick: int, weapon_id: StringName = &"sniper", team: int = Teams.NONE) -> void:
	hits.add_shot(id, origin, Vector2.RIGHT, ContentDB.get_weapon(weapon_id), tick, team, 2000.0)


func _input(tick: int, move: int = 0) -> InputFrame:
	var input := InputFrame.create(move, 0, 0, tick & 0xFFFF)
	input.tick = tick
	return input


func _history_at(x: float, ticks: Array) -> Array[Dictionary]:
	var history: Array[Dictionary] = []
	for tick: int in ticks:
		history.append({"input": _input(tick), "delta": DELTA, "state": {"position": Vector2(x, 372), "active": true, "invulnerable": false}})
	return history


func test_segment_hits_rect() -> void:
	var box := Rect2(0, 0, 10, 10)
	check(HitPrediction.segment_hits_rect(Vector2(-5, 5), Vector2(15, 5), box), "straight through")
	check(HitPrediction.segment_hits_rect(Vector2(2, 2), Vector2(3, 3), box), "inside (muzzle in the body)")
	check(not HitPrediction.segment_hits_rect(Vector2(-5, 15), Vector2(15, 15), box), "passes below")
	check(not HitPrediction.segment_hits_rect(Vector2(-20, 5), Vector2(-1, 5), box), "stops short")
	check(HitPrediction.segment_hits_rect(Vector2(-5, -5), Vector2(1, 1), box), "clips the corner")


func test_bullet_moves_from_the_tick_after_its_spawn() -> void:
	var hits := HitPrediction.new()
	_shot(hits, 1, Vector2.ZERO, 100)
	var shot: HitPrediction.Shot = hits._shots[1]
	var step := ContentDB.get_weapon(&"sniper").projectile_speed / 60.0
	check(HitPrediction.segment_at(shot, 100).is_empty(), "not moving on the spawn tick (the host adds it mid-tick)")
	check_eq(HitPrediction.segment_at(shot, 101), [0.0, step] as Array[float], "first step on the next tick")
	check_eq(HitPrediction.segment_at(shot, 103), [2.0 * step, 3.0 * step] as Array[float], "then one step per tick")
	shot.length = 2.5 * step
	check_eq(HitPrediction.segment_at(shot, 103), [2.0 * step, 2.5 * step] as Array[float], "stops at the wall")
	check(HitPrediction.segment_at(shot, 104).is_empty(), "gone after the wall")


func test_detects_the_input_the_bullet_reaches() -> void:
	var player := Player.new()
	player.character = ContentDB.get_character(&"balvan")
	var hits := HitPrediction.new()
	# Sniper: 60 px per tick from x 100; the body (x 282..318) is crossed in the 4th step.
	_shot(hits, 7, Vector2(100, 372), 16)
	var history := _history_at(300, range(17, 25))
	var index := hits.detect(player, history)
	check_eq(index, 3, "the hit lands after the input of tick 20 (index 3)")
	check_eq(hits.pending_hits(), 1, "one predicted hit")
	check_eq(hits._hits[0].seq, 20, "after input 20")
	check(hits._hits[0].push.x > 0.0, "pushed along the bullet")
	check_eq(hits.detect(player, history), -1, "a bullet hits only once")
	# Grazing: the exact tick misses (body too high), only a neighbouring tick's path crosses it.
	var late := HitPrediction.new()
	_shot(late, 8, Vector2(100, 372), 16)
	var only_tick_21 := _history_at(300, [17, 18, 19, 21])
	only_tick_21[2].state.position = Vector2(500, 372)  # tick 19: nowhere near
	only_tick_21[3].state.position = Vector2(360, 372)  # tick 21: the path of tick 21 ends at 400, of 22 at 460
	check_eq(late.detect(player, only_tick_21), 3, "found with the one-tick tolerance")
	var ally := HitPrediction.new()
	player.team = 1
	_shot(ally, 9, Vector2(100, 372), 16, &"sniper", 1)
	check_eq(ally.detect(player, history), -1, "a teammate's bullet never hits")
	player.free()


func test_snapshot_keeps_only_hits_it_does_not_contain() -> void:
	var player := Player.new()
	player.character = ContentDB.get_character(&"balvan")
	var hits := HitPrediction.new()
	var a := HitPrediction.Hit.new(); a.id = 1; a.seq = 50; a.confirmed = true; a.host_tick = 59; a.push = Vector2(100, 0)
	var b := HitPrediction.Hit.new(); b.id = 2; b.seq = 52; b.confirmed = true; b.host_tick = 61; b.push = Vector2(100, 0)
	var c := HitPrediction.Hit.new(); c.id = 3; c.seq = 46; c.created_ms = Time.get_ticks_msec()
	var d := HitPrediction.Hit.new(); d.id = 4; d.seq = 49; d.created_ms = Time.get_ticks_msec(); d.push = Vector2(0, -50)
	hits._hits = [a, b, c, d] as Array[HitPrediction.Hit]
	hits.apply_after_snapshot(player, 60, 51)
	var left := hits._hits.map(func(hit: HitPrediction.Hit) -> int: return hit.id)
	check_eq(left, [2, 4], "confirmed at tick 59 is in snapshot 60, an unconfirmed one 5 inputs old missed")
	check(player.velocity.is_equal_approx(Vector2(0, -50)), "the unconfirmed recent one applies at once, the later one waits for input 52 (%s)" % player.velocity)
	hits.on_removed(4)
	check_eq(hits.pending_hits(), 1, "a bullet removed without a confirmation missed")
	hits.on_confirmed(2, 62, 53)
	check(hits._hits[0].seq == 53 and hits._hits[0].host_tick == 62, "the host's tick and input win")
	player.free()


func test_predicted_hit_ends_where_the_host_does() -> void:
	var world := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	var floor_block := Platform.new()
	floor_block.position = Vector2(0, 400)
	floor_block.size = Vector2(1400, 60)
	world.add_child(floor_block)
	var player: Player = load("res://src/player/player.tscn").instantiate()
	player.character = ContentDB.get_character(&"balvan")
	world.add_child(player)
	await physics_step()
	var sniper := ContentDB.get_weapon(&"sniper")
	player.reset_to(Vector2(300, 372))
	player.motor_state.on_floor = true
	# The host: inputs 1..40 (walking left from 25 on), the sniper bullet fired at tick 16
	# from x 100 hits after input 20.
	var state_at_10: Dictionary
	var state_at_30: Dictionary
	for tick in range(1, 41):
		player.simulate(_input(tick, -1 if tick >= 25 else 0), DELTA)
		if tick == 20:
			player.take_hit(CombatRules.knockback(Vector2.RIGHT, sniper, player.character.weight), sniper.damage)
		if tick == 10:
			state_at_10 = player.snapshot_state()
		if tick == 30:
			state_at_30 = player.snapshot_state()
	var host_end := player.position
	var host_damage := player.damage
	# The client: snapshot of tick 10, inputs 11..40 predicted, the bullet becomes known late.
	var prediction := ClientPrediction.new()
	var hits := HitPrediction.new()
	var tick_for := func(seq: int) -> int: return seq
	prediction.reconcile(player, state_at_10, tick_for, hits, 10)
	for tick in range(11, 41):
		prediction.predict(player, _input(tick, -1 if tick >= 25 else 0), DELTA, false)
	check(player.position.distance_to(host_end) > 20.0, "without the hit the prediction is far off (%.0f px)" % player.position.distance_to(host_end))
	hits.add_shot(1, Vector2(100, 372), Vector2.RIGHT, sniper, 16, Teams.NONE, 2000.0)
	var index := hits.detect(player, prediction.history())
	check(index >= 0, "the late bullet is found in the pending inputs")
	prediction.replay_from(player, index, hits)
	check(player.position.distance_to(host_end) < 0.5, "predicted = host (%s vs %s)" % [player.position, host_end])
	check(is_equal_approx(player.damage, host_damage), "damage percent too")
	# The host confirms it, then a snapshot of tick 30 (which contains the hit) arrives.
	hits.on_confirmed(1, 20, 20)
	var correction := prediction.reconcile(player, state_at_30, tick_for, hits, 30)
	check(correction < 0.5, "no correction after the snapshot (%.2f px)" % correction)
	check_eq(hits.pending_hits(), 0, "the hit is in the snapshot now")
	player.free()
	world.free()


func test_bias_learns_from_confirmations() -> void:
	var hits := HitPrediction.new()
	for i in 8:
		var hit := HitPrediction.Hit.new()
		hit.id = i
		hit.seq = 100 + i * 10
		hits._hits.append(hit)
		hits.on_confirmed(i, 500, 101 + i * 10)  # always one input later than predicted
	check(hits.tick_bias < -0.5 and hits.tick_bias >= -HitPrediction.MAX_BIAS, "estimate moves a tick earlier (%.2f)" % hits.tick_bias)
