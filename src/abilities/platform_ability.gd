class_name PlatformAbility
extends AbilityData
## Architekt: builds a temporary one-way platform right under the feet (also mid-air),
## so he can stand on it, jump again from it, or save himself after a hit.

@export var width: float = 160.0
@export var lifetime: float = 3.0


func start(user: Player, input: InputFrame) -> void:
	if user.effects == null:
		return
	var top_left := user.global_position + Vector2(-width / 2.0, Player.BODY_SIZE.y / 2.0 + 2.0)
	user.effects.spawn(self, user.peer_id, input.seq, top_left)


func create_effect(owner_peer_id: int) -> Node2D:
	var platform := TempPlatform.new()
	platform.owner_peer_id = owner_peer_id
	platform.lifetime = lifetime
	platform.one_way = true
	platform.size = Vector2(width, 14.0)
	platform.color = Color(0.85, 0.65, 0.3)
	return platform
