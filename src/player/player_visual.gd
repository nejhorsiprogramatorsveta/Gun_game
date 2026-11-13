class_name PlayerVisual
extends Node2D
## Pixel-art look of a Player (PLAN.md Q): an animated body sprite sheet from CharacterData
## and the weapon (with the front hand) rotated towards the aim, with a muzzle flash.
## Purely visual: the state comes from the Player (simulation, prediction or snapshots).
## Sheets are made by tools/art/generate_sprites.py (frame layout documented there).

const FRAME_SIZE := Vector2i(32, 40)
const WEAPON_FRAME_SIZE := Vector2i(34, 12)
## Where the hand holds the weapon inside the weapon frame (px of the sheet).
const WEAPON_GRIP := Vector2(4, 6)
const PIXEL_SCALE := 2.0
## Shoulder of the weapon arm relative to the player's origin (world px).
const SHOULDER := Vector2(0, -10)
## Reload: the gun dips by up to this angle (rad); the bar above the head (world px).
const RELOAD_DIP := 1.1
const RELOAD_BAR := Rect2(-20, -124, 40, 6)  # above the name and the damage percent
## Horizontal speed above which the walk animation plays.
const WALK_SPEED := 30.0
## [name, first frame, frame count, frames per second, loop]
const ANIMATIONS := [
	["idle", 0, 2, 3.0, true], ["walk", 2, 4, 10.0, true], ["jump", 6, 1, 1.0, false],
	["fall", 7, 1, 1.0, false], ["shoot", 8, 2, 14.0, true],
]

var _body := AnimatedSprite2D.new()
var _weapon := Sprite2D.new()
var _weapon_frames: Array[AtlasTexture] = []
var _ability: AbilityData
var _ability_loop: AnimatedSprite2D
var _was_ability_active := false
## Reload progress 0..1, or -1 when not reloading.
var _reload_progress := -1.0


## skins: CharacterData.SKIN_* bits of the player's choice.
func setup(character: CharacterData, skins: int = 0) -> void:
	_body.sprite_frames = _build_frames(character.sheet_for(skins))
	_body.centered = false
	_body.scale = Vector2.ONE * PIXEL_SCALE
	_body.position = Vector2(-FRAME_SIZE.x * PIXEL_SCALE / 2.0, Player.BODY_SIZE.y / 2.0 - FRAME_SIZE.y * PIXEL_SCALE)
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_body)
	_body.play("idle")
	_ability = character.ability
	_ability_loop = AbilityFx.make_loop(_ability) if _ability else null
	if _ability_loop:
		_ability_loop.visible = false
		add_child(_ability_loop)
	var weapon := character.weapon
	if weapon and weapon.sprite:
		for i in 2:
			var frame := AtlasTexture.new()
			frame.atlas = weapon.sprite_for(skins)
			frame.region = Rect2(Vector2(i * WEAPON_FRAME_SIZE.x, 0), WEAPON_FRAME_SIZE)
			_weapon_frames.append(frame)
		_weapon.texture = _weapon_frames[0]
		_weapon.centered = false
		_weapon.offset = -WEAPON_GRIP
		_weapon.scale = Vector2.ONE * PIXEL_SCALE
		_weapon.position = SHOULDER
		_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_weapon)


## Called every frame by the Player with its current state.
func update_look(facing: int, aim_direction: Vector2, on_floor: bool, velocity: Vector2, firing: bool,
		ability_active := false, reload_progress := -1.0) -> void:
	_update_ability(ability_active, facing)
	_update_reload(reload_progress, facing)
	var animation := "idle"
	if firing and reload_progress < 0.0:
		animation = "shoot"
	elif not on_floor:
		animation = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > WALK_SPEED:
		animation = "walk"
	if _body.animation != animation:
		_body.play(animation)
	_body.flip_h = facing < 0
	if _weapon_frames.is_empty():
		return
	_weapon.rotation = aim_direction.angle()
	if reload_progress >= 0.0:  # dip the gun towards the ground and bring it back up
		_weapon.rotation += sin(reload_progress * PI) * RELOAD_DIP * (1.0 if aim_direction.x >= 0.0 else -1.0)
	_weapon.flip_v = aim_direction.x < 0.0
	_weapon.offset = Vector2(-WEAPON_GRIP.x, -(WEAPON_FRAME_SIZE.y - WEAPON_GRIP.y) if _weapon.flip_v else -WEAPON_GRIP.y)
	var flash := firing and _body.frame == 0
	_weapon.texture = _weapon_frames[1 if flash else 0]
	# The gun kicks back a little on the flash frame.
	_weapon.position = SHOULDER - aim_direction * (3.0 if flash else 0.0)


## Reload: a falling magazine when it starts, a progress bar above the head while it runs.
func _update_reload(progress: float, facing: int) -> void:
	if progress >= 0.0 and _reload_progress < 0.0 and get_parent() and get_parent().get_parent():
		var drop := MagazineDrop.new()
		drop.setup(facing)
		get_parent().get_parent().add_child(drop)
		drop.global_position = global_position + SHOULDER + Vector2(6.0 * facing, 6.0)
	if progress >= 0.0 or _reload_progress >= 0.0:
		queue_redraw()
	_reload_progress = progress


func _draw() -> void:
	if _reload_progress < 0.0:
		return
	draw_rect(RELOAD_BAR.grow(2.0), Color(0.05, 0.04, 0.08, 0.85))
	draw_rect(Rect2(RELOAD_BAR.position, Vector2(RELOAD_BAR.size.x * _reload_progress, RELOAD_BAR.size.y)), Color(1.0, 0.82, 0.3))


## Ability effects: a loop while active (shield) and a burst when it starts (ring, trail, smoke).
func _update_ability(active: bool, facing: int) -> void:
	if _ability_loop:
		_ability_loop.visible = active
		if _ability is JetpackAbility:  # the pack is on her back: follow the facing side
			_ability_loop.position = Vector2(AbilityFx.JET_OFFSET.x * facing, AbilityFx.JET_OFFSET.y)
	if active and not _was_ability_active and _ability:
		var burst := AbilityFx.make_burst(_ability, facing)
		if not burst.is_empty():
			var node: Node2D = burst.node
			if burst.world and get_parent() and get_parent().get_parent():
				var world := get_parent().get_parent()
				world.add_child(node)
				node.global_position = global_position + node.position
			else:
				add_child(node)
	_was_ability_active = active


static func _build_frames(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for spec in ANIMATIONS:
		var animation := StringName(spec[0])
		frames.add_animation(animation)
		frames.set_animation_speed(animation, spec[3])
		frames.set_animation_loop(animation, spec[4])
		for i in spec[2]:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2((spec[1] + i) * FRAME_SIZE.x, 0), FRAME_SIZE)
			frames.add_frame(animation, frame)
	return frames
