class_name ShockwaveAbility
extends AbilityData
## Vichr: pushes every opponent within `radius` away from the user (slightly upwards).
## `strength` follows the same knockback limit as weapons (CombatRules).

@export var radius: float = 160.0
@export var strength: float = 1100.0
## How much the push is tilted upwards (0 = straight away from the user).
@export var lift: float = 0.35


func activate(user: Player, players: Array) -> Array[Player]:
	var pushed: Array[Player] = []
	for other: Player in players:
		if other == user or not other.visible or other.invulnerable:
			continue
		var offset := other.global_position - user.global_position
		if offset.length() > radius:
			continue
		var direction := (offset.normalized() if not offset.is_zero_approx() else Vector2(user.facing, 0)) + Vector2(0, -lift)
		other.velocity += direction.normalized() * strength * other.knockback_scale() / maxf(other.character.weight, 0.1)
		pushed.append(other)
	return pushed
