class_name SlowCloudAbility
extends AbilityData
## Krügermann: shoots an arcade slowing cloud towards the mouse cursor. It stops at walls,
## slows other players inside (run and jump) and fades after `lifetime` seconds.

@export var distance: float = 240.0
@export var radius: float = 110.0
@export var lifetime: float = 3.0
@export_range(0.1, 1.0) var speed_scale: float = 0.5
@export_range(0.1, 1.0) var jump_scale: float = 0.8


func start(user: Player, input: InputFrame) -> void:
	if user.effects == null:
		return
	var from := user.global_position
	var to := from + InputFrame.aim_to_vector(input.aim) * distance
	var query := PhysicsRayQueryParameters2D.create(from, to, Platform.WORLD_LAYER_BIT)
	var hit := user.get_world_2d().direct_space_state.intersect_ray(query)
	user.effects.spawn(self, user.peer_id, input.seq, hit.position if hit else to)


func create_effect(owner_peer_id: int) -> Node2D:
	var cloud := SlowCloud.new()
	cloud.owner_peer_id = owner_peer_id
	cloud.radius = radius
	cloud.lifetime = lifetime
	cloud.speed_scale = speed_scale
	cloud.jump_scale = jump_scale
	return cloud
