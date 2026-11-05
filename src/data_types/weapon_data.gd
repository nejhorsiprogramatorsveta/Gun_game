class_name WeaponData
extends Resource
## One weapon. To add a weapon, copy a file in data/weapons/, change id + values,
## add its name to localization/translations.csv and reference it from a character.

@export var id: StringName
@export var name_key: String
## Pixel-art sheet (2 frames of 34x12: normal, muzzle flash), see tools/art/generate_sprites.py.
@export var sprite: Texture2D

## Shots per second while the fire button is held.
@export var shots_per_second: float = 3.0
## Projectile speed in px/s.
@export var projectile_speed: float = 1500.0
## Projectile disappears after this distance (px).
@export var max_range: float = 1400.0
## Random deviation of each shot, ± degrees.
@export var spread_degrees: float = 1.5
## Speed (px/s) a hit adds to the target, divided by the target's weight. Keep the totals
## within CombatRules.MAX_KNOCKBACK_PER_SHOT / _PER_SECOND (checked by tests/test_weapons.gd).
@export var knockback: float = 550.0
## Speed (px/s) the shooter gets pushed opposite to the aim direction.
@export var recoil: float = 120.0
## Projectiles per shot (shotgun > 1); each pellet gets its own spread and knockback.
@export_range(1, 12) var pellets: int = 1
## Rounds in a full magazine (pellets of one shotgun shot count as one round). After the
## last round the weapon reloads for reload_time seconds; every respawn starts with a full
## magazine. Slow, strong weapons get small magazines, fast ones big ones.
@export_range(1, 200) var magazine_size: int = 12
@export var reload_time: float = 1.0
