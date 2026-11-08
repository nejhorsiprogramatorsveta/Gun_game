extends TestCase

const DT := 1.0 / 60.0

## Reconciliation uses the real motor rules; physics-world contacts have separate smoke tests.
class TestPlayer extends Player:
	func simulate(input: InputFrame, delta: float) -> void:
		tick_ability(input, delta)
		velocity = PlayerMotor.compute_velocity(velocity, motor_state.on_floor, input, motor_state, character, delta)
		position += velocity * delta
		fired_this_tick = tick_weapon(input, delta)
		aim = input.aim
		facing = motor_state.facing
		last_input_seq = input.seq


func _player() -> TestPlayer:
	var player := TestPlayer.new()
	player.character = CharacterData.new()
	player.motor_state.on_floor = true
	player.motor_state.jumps_left = 2
	player.lives = 5
	return player


func test_waits_for_authority_then_predicts_immediately() -> void:
	var player := _player()
	var prediction := ClientPrediction.new()
	prediction.predict(player, InputFrame.create(1, 0, 0, 1), DT, false)
	check_eq(player.position, Vector2.ZERO, "wait for the first host baseline")
	prediction.reconcile(player, player.snapshot_state())
	prediction.predict(player, InputFrame.create(1, 0, 0, 2), DT, false)
	check(player.position.x > 0.0, "movement starts on the input tick, without waiting for a snapshot")
	player.free()


func test_reconciliation_replays_only_unacknowledged_inputs() -> void:
	var player := _player()
	var prediction := ClientPrediction.new()
	prediction.reconcile(player, player.snapshot_state())
	var confirmed := {}
	for seq in range(1, 4):
		prediction.predict(player, InputFrame.create(1, 0, 0, seq), DT, false)
		if seq == 1:
			confirmed = player.snapshot_state()
	var expected := player.position
	player.position += Vector2(5, 0)
	prediction.reconcile(player, confirmed)
	check(player.position.is_equal_approx(expected), "restore host position/velocity and replay inputs 2 and 3")
	check_eq(prediction._history.size(), 2, "acknowledged input removed")
	check(player.visual_offset.is_equal_approx(Vector2(5, 0)), "small correction preserved only as a visual offset")
	check_eq(prediction._history[-1].state.position, player.position, "saved predicted states updated after replay")
	player.free()


func test_reconcile_reports_prediction_error() -> void:
	var player := _player()
	var prediction := ClientPrediction.new()
	check_eq(prediction.reconcile(player, player.snapshot_state()), -1.0, "first baseline has nothing to compare")
	prediction.predict(player, InputFrame.create(1, 0, 0, 1), DT, false)
	var confirmed := player.snapshot_state()
	prediction.predict(player, InputFrame.create(1, 0, 0, 2), DT, false)
	check(is_equal_approx(prediction.reconcile(player, confirmed), 0.0), "exact prediction = zero correction")
	player.position += Vector2(3, 4)
	check(is_equal_approx(prediction.reconcile(player, confirmed), 5.0), "error = distance between predicted and corrected position")
	var dead := confirmed.duplicate()
	dead.active = false
	check_eq(prediction.reconcile(player, dead), -1.0, "death is not counted as a correction")
	player.free()


func test_sequence_wrap_and_repeated_acknowledgement() -> void:
	var player := _player()
	player.last_input_seq = 65533
	var prediction := ClientPrediction.new()
	var baseline := player.snapshot_state()
	prediction.reconcile(player, baseline)
	for seq in [65534, 65535, 0, 1]:
		prediction.predict(player, InputFrame.create(1, 0, 0, seq), DT, false)
	baseline.last_seq = 65535
	prediction.reconcile(player, baseline)
	check_eq(prediction._history.size(), 2, "sequence wrap retains inputs 0 and 1")
	var previous := player.position
	baseline.position += Vector2(20, 0)
	prediction.reconcile(player, baseline)
	check(player.position.is_equal_approx(previous + Vector2(20, 0)), "a newer host state with the same ack still corrects movement")
	player.free()


func test_restores_jump_edges_and_drop_memory() -> void:
	var player := _player()
	var prediction := ClientPrediction.new()
	var state := player.snapshot_state()
	state.on_floor = false
	state.prev_buttons = InputFrame.JUMP | InputFrame.DOWN
	state.jumps_left = 1
	state.jump_buffer_timer = 0.05
	state.drop_timer = 0.2
	state.velocity = Vector2(0, -300)
	prediction.reconcile(player, state)
	check(not player.get_collision_mask_value(PlayerMotor.ONE_WAY_LAYER), "restored drop-through disables the platform collision")
	prediction.predict(player, InputFrame.create(0, InputFrame.JUMP | InputFrame.DOWN, 0, 1), DT, false)
	check_eq(player.motor_state.jumps_left, 1, "held jump is not replayed as a new press")
	check(player.velocity.y > -300.0, "gravity continues instead of an extra jump")
	check(absf(player.motor_state.drop_timer - (0.2 - DT)) < 0.00001, "drop timer continues from the host")
	player.free()


func test_countdown_freezes_motion_but_preserves_sequence_and_aim() -> void:
	var player := _player()
	var prediction := ClientPrediction.new()
	prediction.reconcile(player, player.snapshot_state())
	prediction.predict(player, InputFrame.create(1, InputFrame.JUMP, 32768, 42), DT, true)
	check_eq(player.position, Vector2.ZERO, "no movement or jump during countdown")
	check_eq([player.last_input_seq, player.aim], [42, 32768], "sequence and aim retained while frozen")
	player.free()


func test_death_respawn_and_large_corrections_clear_smoothing() -> void:
	var player := _player()
	var prediction := ClientPrediction.new()
	var state := player.snapshot_state()
	prediction.reconcile(player, state)
	prediction.predict(player, InputFrame.create(1, 0, 0, 1), DT, false)
	state.active = false
	state.lives = 4
	prediction.reconcile(player, state)
	check_eq(prediction._history.size(), 0, "death discards pending movement")
	check_eq(player.collision_layer, 0, "dead body does not block other players")
	prediction.predict(player, InputFrame.create(1, 0, 0, 2), DT, false)
	check_eq(prediction._history.size(), 0, "dead player does not predict")
	state.active = true
	state.position = Vector2(500, 0)
	state.invulnerable = true
	prediction.reconcile(player, state)
	check_eq(player.position, Vector2(500, 0), "respawn applied without replaying pre-death input")
	check(player.invulnerable, "protection is restored from the host")
	check_eq(player.visual_offset, Vector2.ZERO, "respawn snaps visually")
	state.position += Vector2(500, 0)
	prediction.reconcile(player, state)
	check_eq(player.visual_offset, Vector2.ZERO, "large correction snaps visually")
	player.free()


func test_history_is_bounded_and_recovers_after_outage() -> void:
	var player := _player()
	var prediction := ClientPrediction.new()
	var baseline := player.snapshot_state()
	prediction.reconcile(player, baseline)
	for seq in range(1, ClientPrediction.MAX_PENDING_INPUTS + 10):
		prediction.predict(player, InputFrame.create(1, 0, 0, seq), DT, false)
	check_eq(prediction._history.size(), ClientPrediction.MAX_PENDING_INPUTS, "history has a fixed bound")
	prediction.reconcile(player, baseline)
	check_eq(player.position, baseline.position, "missing history resets to the host")
	check_eq(prediction._history.size(), 0, "incomplete timeline discarded")
	player.free()


func test_respawn_resets_history_even_when_death_snapshot_was_lost() -> void:
	var player := _player()
	var prediction := ClientPrediction.new()
	var state := player.snapshot_state()
	prediction.reconcile(player, state)
	prediction.predict(player, InputFrame.create(1, InputFrame.JUMP, 0, 1), DT, false)
	state.lives -= 1
	state.position = Vector2(800, 400)
	prediction.reconcile(player, state)
	check_eq(player.position, state.position, "life change detects a missed death/respawn")
	check_eq(prediction._history.size(), 0, "old-life inputs cannot affect respawn")
	check_eq(player.visual_offset, Vector2.ZERO, "missed death still snaps at respawn")
	player.free()


func test_snapshot_delivery_defers_replay_and_rejects_old_ticks() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var session := tree.root.get_node("Session")
	var previous_phase: int = session.phase
	session.phase = session.Phase.IN_MATCH
	var players: Dictionary[int, Player] = {}
	var client := MatchClient.new(players, 2, null, null, NetLog.new())
	var snapshot := {"tick": 0xFFFFFFFF, "countdown": 1, "states": []}
	client.receive_snapshot(snapshot)
	check_eq(client.countdown_display, 0, "delivery queues state without running simulation outside physics")
	check_eq(client.pending_snapshot, snapshot, "latest authoritative state queued for physics")
	snapshot = {"tick": 0, "countdown": 0, "states": []}
	client.receive_snapshot(snapshot)
	check_eq(client.last_snapshot_tick, 0, "u32 tick wrap accepted")
	client.receive_snapshot({"tick": 0xFFFFFFFE, "countdown": 3, "states": []})
	check_eq(client.pending_snapshot, snapshot, "old tick cannot overwrite queued state")
	client.receive_snapshot({"tick": 0, "countdown": 3, "states": []})
	check_eq(client.pending_snapshot, snapshot, "duplicate tick ignored")
	session.phase = session.Phase.RESULTS
	client.receive_snapshot({"tick": 1, "countdown": 3, "states": []})
	check_eq(client.last_snapshot_tick, 0, "late match packets ignored during scene transition")
	session.phase = previous_phase


func test_recoil_and_reload_are_predicted_without_correction() -> void:
	for id: StringName in [&"krugermann", &"jiskra", &"stin", &"architekt"]:
		_check_recoil_prediction(id)


func _check_recoil_prediction(character_id: StringName) -> void:
	var host := _player()
	host.character = ContentDB.get_character(character_id)
	host.gun.refill()
	var client := _player()
	client.character = host.character
	client.gun.refill()
	var prediction := ClientPrediction.new()
	prediction.reconcile(client, host.snapshot_state())
	var confirmed := {}
	var aim := InputFrame.aim_from_vector(Vector2(1, -0.3))
	var shots := 0
	for seq in range(1, 260):  # hold fire long enough for several shots (and the sniper's reload)
		var input := InputFrame.create(0, InputFrame.FIRE, aim, seq)
		host.simulate(input, DT)
		shots += 1 if host.fired_this_tick else 0
		prediction.predict(client, input, DT, false)
		if seq == 160:
			confirmed = NetCodec.decode_snapshot(NetCodec.encode_snapshot(1, 0, [host.snapshot_state()] as Array[Dictionary])).states[0]
	check(shots >= 2, "%s: the host fired (%d shots)" % [character_id, shots])
	check(not host.velocity.is_zero_approx() or not host.position.is_zero_approx(), "recoil moved the shooter")
	check(client.position.is_equal_approx(host.position), "%s: prediction applies the same recoil" % character_id)
	check_eq(client.gun.ammo, host.gun.ammo, "%s: same rounds left" % character_id)
	var correction := prediction.reconcile(client, confirmed)
	check(correction < 1.0, "%s: replay from a mid-burst snapshot needs no visible correction (%.3f px)" % [character_id, correction])
	host.free()
	client.free()


func test_bunched_inputs_on_the_host_cause_no_correction() -> void:
	var host := _player()
	var client := _player()
	var prediction := ClientPrediction.new()
	prediction.reconcile(client, host.snapshot_state())
	var buffer := InputBuffer.new()
	var in_flight: Array[InputFrame] = []
	var worst := 0.0
	for tick in range(1, 241):
		var move := 1 if (tick / 20) % 2 == 0 else -1  # change direction every 20 ticks
		var buttons := InputFrame.JUMP if tick % 45 == 0 else 0
		var input := InputFrame.create(move, buttons, 0, tick)
		prediction.predict(client, input, DT, false)
		in_flight.append(input)
		if tick % 6 == 0:  # Wi-Fi delivers the last 6 inputs together
			for sent in in_flight:
				buffer.push([sent] as Array[InputFrame], int(tick * InputBuffer.TICK_MS))
			in_flight.clear()
		for received in buffer.take_for_tick():
			host.simulate(received, DT)
		if tick % 3 == 0:
			var state: Dictionary = NetCodec.decode_snapshot(NetCodec.encode_snapshot(tick, 0, [host.snapshot_state()] as Array[Dictionary])).states[0]
			worst = maxf(worst, prediction.reconcile(client, state))
	check(worst < 1.0, "the host simulates exactly the client's inputs: no visible correction (%.3f px)" % worst)
	host.free()
	client.free()


func test_jetpack_is_predicted_without_correction() -> void:
	var host := _player()
	host.character = ContentDB.get_character(&"jiskra")
	var client := _player()
	client.character = host.character
	var prediction := ClientPrediction.new()
	prediction.reconcile(client, host.snapshot_state())
	var confirmed := {}
	for seq in range(1, 13):
		var buttons := InputFrame.ABILITY if seq >= 3 and seq <= 5 else 0
		var input := InputFrame.create(1, buttons, 0, seq)
		host.simulate(input, DT)
		prediction.predict(client, input, DT, false)
		if seq == 4:
			confirmed = NetCodec.decode_snapshot(NetCodec.encode_snapshot(1, 0, [host.snapshot_state()] as Array[Dictionary])).states[0]
	check(host.ability_cooldown > 0.0, "the jetpack was used")
	check(client.position.is_equal_approx(host.position), "prediction matches the host")
	var correction := prediction.reconcile(client, confirmed)
	# Snapshots carry velocity as whole px/s, so a sub-pixel difference from rounding remains.
	check(correction < 1.0, "replay from a mid-flight snapshot needs no visible correction (%.3f px)" % correction)
	host.free()
	client.free()
