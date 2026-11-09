class_name ShieldAbility
extends AbilityData
## Balvan: for `duration` seconds hits (and Krügermann's gas) push much less; he can keep
## shooting behind the shield.

@export_range(0.0, 1.0) var knockback_multiplier: float = 0.2


func knockback_scale() -> float:
	return knockback_multiplier
