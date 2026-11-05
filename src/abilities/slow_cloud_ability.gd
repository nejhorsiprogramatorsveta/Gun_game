class_name SlowCloudAbility
extends AbilityData
## Krügermann: blows a long horizontal strip of arcade slowing gas in front of him, to the
## side of the mouse cursor, at his own height. It stops at walls, slows other players
## inside (run and jump) and fades after `lifetime` seconds.

## Strip size (px) and the gap between Krügermann and the strip's near end.
@export var length: float = 540.0
@export var height: float = 90.0
@export var gap: float = 30.0
@export var lifetime: float = 3.0
@export_range(0.1, 1.0) var speed_scale: float = 0.5
@export_range(0.1, 1.0) var jump_scale: float = 0.8


func start(user: Player, input: InputFrame) -> void:
	if user.effects == null:
		return
	var aim_x := InputFrame.aim_to_vector(input.aim).x
	var side := (1.0 if aim_x > 0.0 else -1.0) if absf(aim_x) > 0.01 else float(user.motor_state.facing)
	var from := user.global_position
	var far_end := from + Vector2(side * (gap + length), 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, far_end, Platform.WORLD_LAYER_BIT)
	var hit := user.get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		far_end = hit.position
	user.effects.spawn(self, user.peer_id, input.seq, far_end - Vector2(side * length / 2.0, 0.0))


func create_effect(owner_peer_id: int) -> Node2D:
	var cloud := SlowCloud.new()
	cloud.owner_peer_id = owner_peer_id
	cloud.half_size = Vector2(length, height) / 2.0
	cloud.lifetime = lifetime
	cloud.speed_scale = speed_scale
	cloud.jump_scale = jump_scale
	return cloud
