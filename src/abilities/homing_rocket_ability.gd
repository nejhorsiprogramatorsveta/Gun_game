class_name HomingRocketAbility
extends AbilityData
## Bibi's guided rocket. Runtime flight and hit state belong to HomingRocket;
## RocketSystem spawns it only after the host accepts the ability press.

@export var speed: float = 460.0
@export var minimum_speed: float = 120.0
## Maximum turn rate in radians per second; the rocket curves towards its target.
@export var turn_rate: float = 4.0
@export var hit_speed_scale: float = 0.65
@export var slow_duration: float = 0.45
@export var recovery_acceleration: float = 600.0
@export var lifetime: float = 8.0
## Explosion balance matches Vichr; Bibi's rocket adds no damage percent.
@export var radius: float = 320.0
@export var strength: float = 1100.0
@export var lift: float = 0.35
@export var damage: float = 0.0
