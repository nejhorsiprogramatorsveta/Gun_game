class_name CharacterData
extends Resource
## One playable character. To add a character, copy a file in data/characters/,
## change id + values and add its texts to localization/translations.csv.

@export var id: StringName
@export var name_key: String
@export var description_key: String
@export var color: Color = Color.WHITE

@export_group("Movement")
## Max running speed (px/s).
@export var move_speed: float = 420.0
@export var ground_acceleration: float = 3600.0
@export var air_acceleration: float = 2200.0
## Slowdown without input (and above max speed, e.g. after knockback).
@export var ground_friction: float = 3200.0
@export var air_friction: float = 500.0
@export var jump_velocity: float = 820.0
## Extra jumps in the air (1 = double jump).
@export var air_jumps: int = 1
@export var gravity: float = 2400.0
@export var max_fall_speed: float = 1400.0
## Seconds a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.1
## Seconds one-way platforms are ignored after pressing Down.
@export var drop_through_time: float = 0.25

@export_group("Combat")
## Knockback is divided by weight (heavier = harder to push).
@export var weight: float = 1.0
