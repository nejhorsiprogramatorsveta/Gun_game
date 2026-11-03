@tool
class_name Platform
extends StaticBody2D
## Rectangular arena block, positioned by its top-left corner. Solid blocks use the
## "world" layer; one-way blocks can be jumped through from below and dropped through.

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
@export var color := Color(0.33, 0.36, 0.45):
	set(value):
		color = value
		queue_redraw()

var _shape_node := CollisionShape2D.new()


func _init() -> void:
	# Added here (not in _ready) so the shape is freed with the platform even if it
	# never enters the tree, e.g. when the exporter inspects the scene.
	add_child(_shape_node)
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
	draw_rect(Rect2(Vector2.ZERO, size), color)
	if one_way:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 4)), color.lightened(0.35))
