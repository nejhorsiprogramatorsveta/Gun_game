class_name ArenaBackground
extends CanvasLayer
## Pixel-art backdrop of an arena (tools/art/generate_world.py): a static scene that covers
## the whole window behind the arena, plus a slowly drifting cloud layer. Decoration only.

const CLOUDS: Texture2D = preload("res://assets/backgrounds/clouds.png")
## Cloud drift in background pixels per second.
const CLOUD_SPEED := 4.0

@export var scene: Texture2D
@export var show_clouds := true
## Darkens the backdrop (0..1) so menu text on top stays readable.
@export_range(0.0, 1.0) var dim := 0.0

var _clouds := TextureRect.new()
var _offset := 0.0


func _ready() -> void:
	layer = -10
	var picture := TextureRect.new()
	picture.texture = scene
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.color = Color(0.03, 0.02, 0.06, dim)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
	if show_clouds:
		_clouds.texture = CLOUDS
		_clouds.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_clouds.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_clouds.stretch_mode = TextureRect.STRETCH_TILE
		_clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clouds.modulate.a = 0.55
		add_child(_clouds)
		move_child(_clouds, 1)  # under the darkening layer


func _process(delta: float) -> void:
	if not show_clouds:
		return
	# Scale the cloud strip like the backdrop (window height / backdrop height) and scroll it.
	var scale_factor := get_viewport().get_visible_rect().size.y / float(scene.get_height()) if scene else 2.0
	_offset = fposmod(_offset + CLOUD_SPEED * delta, float(CLOUDS.get_width()))
	_clouds.scale = Vector2.ONE * scale_factor
	_clouds.size = Vector2(get_viewport().get_visible_rect().size.x / scale_factor + CLOUDS.get_width(), CLOUDS.get_height())
	_clouds.position = Vector2(-_offset * scale_factor, 0.0)
