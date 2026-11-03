class_name WeaponData
extends Resource
## One weapon. To add a weapon, copy a file in data/weapons/, change id + values,
## add its name to localization/translations.csv and reference it from a character.

@export var id: StringName
@export var name_key: String

## Shots per second while the fire button is held.
@export var shots_per_second: float = 3.0
## Projectile speed in px/s.
@export var projectile_speed: float = 1500.0
## Projectile disappears after this distance (px).
@export var max_range: float = 1400.0
## Random deviation of each shot, ± degrees.
@export var spread_degrees: float = 1.5
## Speed (px/s) a hit adds to the target, divided by the target's weight.
@export var knockback: float = 550.0
## Speed (px/s) the shooter gets pushed opposite to the aim direction.
@export var recoil: float = 120.0
