class_name GasBlastAbility
extends AbilityData
## Krügermann: blows a long horizontal strip of green gas in front of him, to the side of
## the mouse cursor, at his own height. It stops at walls and lasts `lifetime` seconds. An
## opponent who touches it is blown away AT ONCE along the strip, away from Krügermann and a
## bit upwards (arrows in the gas show the way), see AreaEffects.blow.

## Strip size (px) and the gap between Krügermann and the strip's near end.
@export var length: float = 540.0
@export var height: float = 90.0
@export var gap: float = 30.0
@export var lifetime: float = 3.0
## Speed (px/s) the gas gives an opponent touching it, divided by the opponent's weight:
## sideways (away from Krügermann) and upwards. Set, not added, every tick inside.
@export var blow_speed: float = 1500.0
@export var blow_lift: float = 450.0


func start(user: Player, input: InputFrame) -> void:
	if user.effects == null:
		return
	var aim_x := InputFrame.aim_to_vector(input.aim).x
	var side := (1 if aim_x > 0.0 else -1) if absf(aim_x) > 0.01 else user.motor_state.facing
	var from := user.global_position
	var far_end := from + Vector2(side * (gap + length), 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, far_end, Platform.WORLD_LAYER_BIT)
	var hit := user.get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		far_end = hit.position
	user.effects.spawn(self, user.peer_id, input.seq, far_end - Vector2(side * length / 2.0, 0.0), side)


func create_effect(owner_peer_id: int, direction: int) -> Node2D:
	var cloud := GasCloud.new()
	cloud.owner_peer_id = owner_peer_id
	cloud.direction = 1 if direction >= 0 else -1
	cloud.half_size = Vector2(length, height) / 2.0
	cloud.lifetime = lifetime
	cloud.blow_speed = blow_speed
	cloud.blow_lift = blow_lift
	return cloud
