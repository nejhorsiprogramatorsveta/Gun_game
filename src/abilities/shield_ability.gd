class_name ShieldAbility
extends AbilityData
## Balvan: for `duration` seconds hits push much less, but the user cannot shoot.

@export_range(0.0, 1.0) var knockback_multiplier: float = 0.2


func knockback_scale() -> float:
	return knockback_multiplier


func allows_firing() -> bool:
	return false
