class_name CharacterData
extends Resource
## One playable character. To add a character, copy a file in data/characters/,
## change id + values and add its texts to localization/translations.csv.

@export var id: StringName
@export var name_key: String
@export var description_key: String
@export var color: Color = Color.WHITE
## Pixel-art sheet from tools/art/generate_sprites.py (10 frames of 32x40: idle, walk, jump, fall, shoot).
@export var sprite_sheet: Texture2D

@export_group("Movement")
## Max running speed (px/s).
@export var move_speed: float = 420.0
@export var ground_acceleration: float = 3600.0
@export var air_acceleration: float = 2200.0
## Slowdown without input (and above max speed, e.g. after knockback).
@export var ground_friction: float = 3200.0
@export var air_friction: float = 500.0
## Slowdown while faster than running speed (after a hit), also on the ground, so a hit
## slides the player far instead of being stopped by ground friction.
@export var knockback_friction: float = 900.0
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
## The character's one weapon (user decision 2026-11-04: no weapon switching).
@export var weapon: WeaponData
## Special ability (E / right mouse button), PLAN.md G.1. null = none yet.
@export var ability: AbilityData

@export_group("Skin")
## The character's one skin (user 2026-11-13): the same 10-frame sheet in other colours
## (tools/art/generate_sprites.py CHARACTER_SKINS) and its name. null = no skin.
@export var skin_sheet: Texture2D
@export var skin_name_key := ""

## Bits of a player's skin choice (Session.players[peer].skins, Settings.skins).
const SKIN_CHARACTER := 1
const SKIN_WEAPON := 2
const SKIN_ALL := SKIN_CHARACTER | SKIN_WEAPON


## The sheet to draw with the player's skin choice.
func sheet_for(skins: int) -> Texture2D:
	return skin_sheet if skins & SKIN_CHARACTER and skin_sheet else sprite_sheet
