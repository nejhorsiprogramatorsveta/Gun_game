class_name CombatRules
## Pure combat formulas (no nodes, no network), shared by the simulation and unit tests.


## Velocity added to a hit player: along the bullet's flight, weaker on heavier characters.
static func knockback(direction: Vector2, weapon: WeaponData, target_weight: float) -> Vector2:
	return direction.normalized() * weapon.knockback / maxf(target_weight, 0.1)


## Velocity added to the shooter: opposite to where they aim (shooting down lifts a bit).
static func recoil(aim_direction: Vector2, weapon: WeaponData) -> Vector2:
	return -aim_direction.normalized() * weapon.recoil


## Seconds between two shots.
static func fire_interval(weapon: WeaponData) -> float:
	return 1.0 / maxf(weapon.shots_per_second, 0.01)


## Shot direction with random spread; the authority sends the result, so peers agree.
static func spread_direction(aim_direction: Vector2, weapon: WeaponData, random_value: float) -> Vector2:
	var angle := deg_to_rad(lerpf(-weapon.spread_degrees, weapon.spread_degrees, random_value))
	return aim_direction.normalized().rotated(angle)
