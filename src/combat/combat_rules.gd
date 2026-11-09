class_name CombatRules
## Pure combat formulas (no nodes, no network), shared by the simulation and unit tests.

## Balance limits (user 2026-11-04: knockback must not get too high). Reference: the pistol,
## 800 per hit x 9 shots/s. Checked for every weapon by tests/test_weapons.gd.
const MAX_KNOCKBACK_PER_SHOT := 1400.0
const MAX_KNOCKBACK_PER_SECOND := 7500.0
## Damage percent (user 2026-11-05): every hit adds the weapon's `damage` to the target
## (0-100 %, shown above the character); knockback grows with it linearly up to
## MAX_DAMAGE_KNOCKBACK times the weapon's own at 100 % ("flies away easily"). The limits
## above are the knockback at 0 %. Damage resets on respawn.
const MAX_DAMAGE := 100.0
const MAX_DAMAGE_KNOCKBACK := 2.5
## Arcade feel: every shot must visibly push the shooter. Ground friction removes ~53 px/s
## per tick, so smaller recoil would vanish on the ground (SMG bug, user 2026-11-04).
const MIN_RECOIL := 100.0


## Knockback multiplier of a target with `damage` percent (1.0 at 0 %).
static func damage_multiplier(damage: float) -> float:
	return 1.0 + (MAX_DAMAGE_KNOCKBACK - 1.0) * clampf(damage, 0.0, MAX_DAMAGE) / MAX_DAMAGE


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


## Shot direction with spread; random_value 0..1 (WeaponSystem derives it from the input,
## so the host and the shooter's prediction agree). In the air some guns spread much more.
static func spread_direction(aim_direction: Vector2, weapon: WeaponData, random_value: float, airborne: bool = false) -> Vector2:
	var spread := spread_degrees(weapon, airborne)
	var angle := deg_to_rad(lerpf(-spread, spread, random_value))
	return aim_direction.normalized().rotated(angle)


static func spread_degrees(weapon: WeaponData, airborne: bool) -> float:
	return weapon.air_spread_degrees if airborne and weapon.air_spread_degrees >= 0.0 else weapon.spread_degrees
