class_name ShockwaveAbility
extends AbilityData
## Vichr: pushes every opponent (not teammates) within `radius` away from the user (slightly upwards).
## A long reach (320 px, user 2026-11-05) so it is a ranged move, not melee.
## `strength` follows the same knockback limit as weapons (CombatRules).

@export var radius: float = 320.0
@export var strength: float = 1100.0
## Damage percent added to each pushed opponent (CombatRules.damage_multiplier).
@export var damage: float = 9.0
## How much the push is tilted upwards (0 = straight away from the user).
@export var lift: float = 0.35


func activate(user: Player, players: Array) -> Array[Player]:
	var pushed: Array[Player] = []
	for other: Player in players:
		if other == user or not other.visible or other.invulnerable or Teams.allies(user.team, other.team):
			continue
		var offset := other.global_position - user.global_position
		if offset.length() > radius:
			continue
		var direction := (offset.normalized() if not offset.is_zero_approx() else Vector2(user.facing, 0)) + Vector2(0, -lift)
		other.take_hit(direction.normalized() * strength / maxf(other.character.weight, 0.1), damage)
		pushed.append(other)
	return pushed
