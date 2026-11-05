@tool
class_name Platform
extends StaticBody2D
## Rectangular arena block, positioned by its top-left corner. Solid blocks use the
## "world" layer; one-way blocks can be jumped through from below and dropped through.
## Drawn with pixel-art tiles (tools/art/generate_world.py): mossy stone for solid blocks,
## a wooden beam for one-way platforms, at PIXEL_SCALE.

const STONE_TOP: Texture2D = preload("res://assets/sprites/tiles/stone_top.png")
const STONE_FILL: Texture2D = preload("res://assets/sprites/tiles/stone_fill.png")
const WOOD_BEAM: Texture2D = preload("res://assets/sprites/tiles/wood_beam.png")
const PIXEL_SCALE := 2.0

const WORLD_LAYER_BIT := 1
const ONE_WAY_LAYER_BIT := 2

@export var size := Vector2(400, 32):
	set(value):
		size = value
		_rebuild()
@export var one_way := false:
	set(value):
		one_way = value
		_rebuild()
## Tint of the tiles (white = original colours).
@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()

var _shape_node := CollisionShape2D.new()


func _init() -> void:
	# Added here (not in _ready) so the shape is freed with the platform even if it
	# never enters the tree, e.g. when the exporter inspects the scene.
	add_child(_shape_node)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rebuild()


func _rebuild() -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape_node.shape = rect
	_shape_node.position = size / 2.0
	_shape_node.one_way_collision = one_way
	collision_layer = ONE_WAY_LAYER_BIT if one_way else WORLD_LAYER_BIT
	collision_mask = 0
	queue_redraw()


func _draw() -> void:
	# Tiles are drawn in texture pixels and scaled, so they stay crisp pixel art.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PIXEL_SCALE)
	var area := size / PIXEL_SCALE
	if one_way:
		draw_texture_rect(WOOD_BEAM, Rect2(Vector2.ZERO, area), true, color)
		return
	var top_height := minf(area.y, STONE_TOP.get_height())
	draw_texture_rect(STONE_TOP, Rect2(Vector2.ZERO, Vector2(area.x, top_height)), true, color)
	if area.y > top_height:
		draw_texture_rect(STONE_FILL, Rect2(Vector2(0, top_height), Vector2(area.x, area.y - top_height)), true, color)
