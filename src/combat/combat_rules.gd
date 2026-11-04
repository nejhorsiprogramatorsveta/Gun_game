class_name CombatRules
## Pure combat formulas (no nodes, no network), shared by the simulation and unit tests.

## Balance limits (user 2026-11-04: knockback must not get too high). Reference: the pistol,
## 800 per hit x 9 shots/s. Checked for every weapon by tests/test_weapons.gd.
const MAX_KNOCKBACK_PER_SHOT := 1400.0
const MAX_KNOCKBACK_PER_SECOND := 7500.0
## No shooting right after switching weapons.
const WEAPON_SWITCH_SECONDS := 0.3


## Knockback of one full shot (all pellets hit).
static func knockback_per_shot(weapon: WeaponData) -> float:
	return weapon.knockback * weapon.pellets


static func knockback_per_second(weapon: WeaponData) -> float:
	return knockback_per_shot(weapon) * weapon.shots_per_second


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
