class_name PracticeDummy
extends RefCounted
## Brain of the practice target (offline practice only): it walks a while, stops, sometimes
## jumps on the spot, and turns around before an edge, a wall or another player, so it
## never falls on its own - only when the player knocks it off. It never shoots or uses its
## ability. MatchController asks it for one InputFrame per physics tick.

## Floor must exist this far ahead (px from the body's center) to keep walking: half the
## body + the stopping distance at running speed (~30 px) + a margin.
const EDGE_LOOKAHEAD := 72.0
## The floor ahead may be at most this much lower than the feet (tiny steps are fine).
const MAX_STEP_DOWN := 20.0
## Seconds of walking and of standing (random within the range).
const WALK_TIME := Vector2(0.8, 2.4)
const PAUSE_TIME := Vector2(0.5, 1.5)
## Chance to jump on the spot at the start of a pause.
const JUMP_CHANCE := 0.4
## Physics layers "world" (1) and "platform_oneway" (2) carry the floor; walls are "world";
## other players ("players", 3) block the way too.
const FLOOR_MASK := 1 | 2
const BLOCK_MASK := 1 | 4

## direction (-1 / 1) -> true if the dummy may walk that way; physics check by default,
## replaced in unit tests.
var can_walk := Callable()

var _player: Player
var _rng := RandomNumberGenerator.new()
var _direction := 1
var _walking := false
var _time_left := 0.0
var _jump_pending := false


func _init(player: Player, rng_seed: int = 0) -> void:
	_player = player
	_rng.seed = rng_seed if rng_seed != 0 else Time.get_ticks_usec()
	_direction = 1 if _rng.randf() < 0.5 else -1
	_time_left = _rng.randf_range(PAUSE_TIME.x, PAUSE_TIME.y)
	can_walk = _physics_can_walk


func next_input(delta: float) -> InputFrame:
	# Dead, or in the air (jumping, falling, knocked back): no steering at all.
	if not _player.visible or not _player.motor_state.on_floor:
		return _input(0, 0)
	_time_left -= delta
	if _time_left <= 0.0:
		_walking = not _walking
		_time_left = _rng.randf_range(WALK_TIME.x, WALK_TIME.y) if _walking else _rng.randf_range(PAUSE_TIME.x, PAUSE_TIME.y)
		_jump_pending = not _walking and _rng.randf() < JUMP_CHANCE
		if _walking and _rng.randf() < 0.5:
			_direction = -_direction
	if not _walking:
		# Jump only when standing still, so the dummy lands where it took off.
		if _jump_pending and absf(_player.velocity.x) < 1.0:
			_jump_pending = false
			return _input(0, InputFrame.JUMP)
		return _input(0, 0)
	if not can_walk.call(_direction):
		_direction = -_direction
		if not can_walk.call(_direction):  # no room either way: stand
			return _input(0, 0)
	return _input(_direction, 0)


## Looks the way it walks; the aim never fires anything.
func _input(move: int, buttons: int) -> InputFrame:
	var aim := InputFrame.aim_from_vector(Vector2(_direction, 0))
	return InputFrame.create(move, buttons, aim)


func _physics_can_walk(direction: int) -> bool:
	var space := _player.get_world_2d().direct_space_state
	var center := _player.global_position
	var feet_y := center.y + Player.BODY_SIZE.y / 2.0
	var ahead_x := center.x + direction * EDGE_LOOKAHEAD
	var floor_ray := PhysicsRayQueryParameters2D.create(Vector2(ahead_x, feet_y - 8.0), Vector2(ahead_x, feet_y + MAX_STEP_DOWN), FLOOR_MASK)
	if space.intersect_ray(floor_ray).is_empty():
		return false
	var block_ray := PhysicsRayQueryParameters2D.create(center, Vector2(ahead_x, center.y), BLOCK_MASK, [_player.get_rid()])
	return space.intersect_ray(block_ray).is_empty()
