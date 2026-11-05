class_name AbilityFx
## Pixel-art effects of abilities (tools/art/generate_effects.py), purely visual:
## Balvan's shield bubble while active, Vichr's expanding ring, Jiskra's dash trail and
## Stín's smoke poof. Krügermann's gas and Architekt's platform draw themselves.

const SHIELD: Texture2D = preload("res://assets/sprites/effects/shield_bubble.png")
const RING: Texture2D = preload("res://assets/sprites/effects/shockwave_ring.png")
const TRAIL: Texture2D = preload("res://assets/sprites/effects/dash_trail.png")
const SMOKE: Texture2D = preload("res://assets/sprites/effects/teleport_smoke.png")
## Outer ring radius in the last frame of the shockwave sheet (px of the sheet).
const RING_RADIUS := 76.0


## Looping effect shown while the ability is active (null = none).
static func make_loop(ability: AbilityData) -> AnimatedSprite2D:
	if ability is ShieldAbility:
		var bubble := _sprite(SHIELD, 2, 6.0, true)
		bubble.scale = Vector2.ONE * 2.0
		bubble.position = Vector2(0, -2)
		return bubble
	return null


## One-shot effect when the ability starts; it removes itself. `world` = true means it
## must stay where it started instead of following the player (e.g. a smoke poof).
static func make_burst(ability: AbilityData, facing: int) -> Dictionary:
	if ability is ShockwaveAbility:
		var ring := _sprite(RING, 6, 24.0, false)
		ring.scale = Vector2.ONE * ((ability as ShockwaveAbility).radius / RING_RADIUS)
		return {"node": ring, "world": false}
	if ability is DashAbility:
		var trail := _sprite(TRAIL, 3, 18.0, false)
		trail.scale = Vector2.ONE * 2.0
		trail.flip_h = facing < 0
		trail.position = Vector2(-28 * facing, -4)
		return {"node": trail, "world": true}
	if ability is TeleportAbility:
		var poof := _sprite(SMOKE, 5, 16.0, false)
		poof.scale = Vector2.ONE * 2.0
		return {"node": poof, "world": true}
	return {}


static func _sprite(sheet: Texture2D, count: int, fps: float, loop: bool) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", fps)
	frames.set_animation_loop(&"default", loop)
	var size := Vector2(sheet.get_width() / float(count), sheet.get_height())
	for i in count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(i * size.x, 0), size)
		frames.add_frame(&"default", frame)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 5
	if not loop:
		sprite.animation_finished.connect(sprite.queue_free)
	sprite.play()
	return sprite
