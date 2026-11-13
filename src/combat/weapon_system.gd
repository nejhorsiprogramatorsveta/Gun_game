class_name WeaponSystem
extends Node2D
## Shooting: projectiles, hits and knockback (PLAN.md D.5). Fire rate, ammo and recoil are
## in Player.tick_weapon (shared with the client's prediction).
## Only the authority (host or offline practice) decides hits. Clients receive spawn/remove
## events and fly the same bullets purely for display. The own player's shots are shown at
## once (spawn_predicted) and paired with the host's spawn events in order, so shooting
## has no network delay on screen.

signal player_hit(attacker_peer_id: int, target: Player)
## Client: another player's bullet with the host tick it was fired on (HitPrediction).
signal remote_shot_spawned(id: int, origin: Vector2, direction: Vector2, weapon: WeaponData, tick: int, shooter_slot: int)

## A predicted shot whose host event did not come within this time is no longer paired.
const PREDICTION_TIMEOUT_MS := 1000

## MatchNet of a network match; null in offline practice.
var _net: Node
## Client: slot of the own player, whose shots are predicted.
var local_slot := -1
## Authority: the current host tick (set by MatchController every tick; sent with shots
## and hits so clients can predict the hits on themselves).
var tick := 0
var _projectiles: Dictionary[int, Projectile] = {}
## Client: own shots shown before the host confirmed them, oldest first (one per pellet).
var _predicted: Array[Projectile] = []
var _next_id := 1
var _next_predicted_id := -1


func setup(net: Node) -> void:
	_net = net
	if _net:
		_net.projectile_spawned.connect(_on_remote_spawned)
		_net.projectile_removed.connect(_on_remote_removed)


## Authority: called after each Player.simulate(), which already decided the shot
## (cooldown, ammo, recoil - shared with the client's prediction); spawns its projectiles.
## catch_up_ticks > 0: the input belonged to an earlier tick (a client's bunch of inputs
## simulated at once), so its bullets fly that much further right away and do not clump.
func spawn_shot(player: Player, input: InputFrame, catch_up_ticks: int = 0) -> void:
	var weapon := player.current_weapon()
	if not player.fired_this_tick or weapon == null:
		return
	var aim_direction := InputFrame.aim_to_vector(input.aim)
	var origin := player.global_position + aim_direction * Player.GUN_LENGTH
	for pellet in weapon.pellets:
		var direction := _shot_direction(player, input, aim_direction, weapon, pellet)
		var id := _next_id
		_next_id += 1
		var projectile := _spawn(id, origin, direction, weapon, player)
		for i in catch_up_ticks:
			projectile.advance(get_physics_process_delta_time())
		# A bullet that already hit something while catching up is never shown on clients.
		if _net and not projectile.is_queued_for_deletion():
			_net.send_projectile_spawned(id, projectile.position, direction, weapon.id, player.slot, tick)


## Client: the own player fired in the prediction. Shown at once; the host's spawn events
## for this shot are paired with it later (_on_remote_spawned) instead of a second bullet.
func spawn_predicted(player: Player, input: InputFrame) -> void:
	var weapon := player.current_weapon()
	if weapon == null:
		return
	var aim_direction := InputFrame.aim_to_vector(input.aim)
	var origin := player.global_position + aim_direction * Player.GUN_LENGTH
	for pellet in weapon.pellets:
		var projectile := _spawn(_next_predicted_id, origin, _shot_direction(player, input, aim_direction, weapon, pellet), weapon, null)
		_next_predicted_id -= 1
		projectile.predicted = true
		projectile.predicted_ms = Time.get_ticks_msec()
		_predicted.append(projectile)


## Spread of one pellet. A client's shot has an input sequence number, so its random value
## comes from (slot, seq, pellet): the host and the shooter's own prediction get the same
## direction and the predicted bullet flies where the real one does. Inputs without a seq
## (the host's own player, practice) use plain randomness. Airborne = not on the floor
## after this tick's movement; moving = a movement key held in this input.
static func _shot_direction(player: Player, input: InputFrame, aim_direction: Vector2, weapon: WeaponData, pellet: int) -> Vector2:
	var random_value := randf()
	if input.seq != 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = (player.slot << 24) | (input.seq << 8) | pellet
		random_value = rng.randf()
	return CombatRules.spread_direction(aim_direction, weapon, random_value, not player.motor_state.on_floor, input.is_moving())


func _physics_process(_delta: float) -> void:
	# Shots the host never confirmed (a rare misprediction) stop being paired; they still
	# fly out and disappear on their own like any display-only bullet.
	var now := Time.get_ticks_msec()
	while not _predicted.is_empty() and (not is_instance_valid(_predicted[0])
			or now - _predicted[0].predicted_ms > PREDICTION_TIMEOUT_MS):
		_predicted.pop_front()


func _spawn(id: int, origin: Vector2, direction: Vector2, weapon: WeaponData, shooter: Player) -> Projectile:
	var projectile := Projectile.new()
	projectile.setup(id, origin, direction, weapon, shooter)
	projectile.hit_player.connect(_on_hit)
	projectile.finished.connect(_on_finished)
	add_child(projectile)
	_projectiles[id] = projectile
	return projectile


func _on_hit(projectile: Projectile, target: Player) -> void:
	if not projectile.authoritative or not target.visible or target.invulnerable:
		return
	target.take_hit(CombatRules.knockback(projectile.direction, projectile.weapon, target.character.weight), projectile.weapon.damage)
	player_hit.emit(projectile.shooter_peer_id, target)
	if _net and target.peer_id != multiplayer.get_unique_id():
		_net.send_hit_confirmed(target.peer_id, projectile.id, tick, target.last_input_seq)  # the victim predicted it


func _on_finished(projectile: Projectile) -> void:
	_projectiles.erase(projectile.id)
	if projectile.authoritative and _net:
		_net.send_projectile_removed(projectile.id)


func _on_remote_spawned(id: int, origin: Vector2, direction: Vector2, weapon_id: StringName, shooter_slot: int, shot_tick: int) -> void:
	var weapon := ContentDB.get_weapon(weapon_id)
	if weapon == null or _projectiles.has(id) or not origin.is_finite() or not direction.is_finite() \
			or direction.is_zero_approx():
		return
	if shooter_slot != local_slot:
		remote_shot_spawned.emit(id, origin, direction, weapon, shot_tick, shooter_slot)
	if shooter_slot == local_slot and not _predicted.is_empty():
		# Our own shot, already shown: pair it (strictly in order, one per pellet). If the
		# predicted bullet has already hit a wall, the shot has been shown in full.
		# Untyped: the bullet may already be freed, and a freed object in a typed variable is a
		# script error.
		var own: Variant = _predicted.pop_front()
		if is_instance_valid(own) and not (own as Projectile).is_queued_for_deletion():
			_projectiles.erase(own.id)
			own.id = id
			_projectiles[id] = own
		return
	_spawn(id, origin, direction, weapon, null)


func _on_remote_removed(id: int) -> void:
	var projectile: Projectile = _projectiles.get(id)
	if projectile:
		projectile.finish()
