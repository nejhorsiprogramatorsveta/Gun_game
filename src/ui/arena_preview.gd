class_name ArenaPreview
extends SubViewportContainer
## Lobby backdrop: the chosen arena (its background, platforms and camera framing) rendered
## in its own SubViewport, so the arena camera never moves the lobby UI. Darkened so the
## lobby text on top stays readable. Decoration only: nothing is simulated.

## Darkening over the arena (0..1).
const DIM := 0.45

var _viewport := SubViewport.new()
var _arena: Node
var _shown_id := ""


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.disable_3d = true
	_viewport.physics_object_picking = false
	_viewport.gui_disable_input = true
	add_child(_viewport)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.06, DIM)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


## Shows the arena with this id (unknown ids fall back to the default arena).
func show_arena(arena_id: String) -> void:
	var data := ContentDB.arena_or_default(arena_id)
	if String(data.id) == _shown_id:
		return
	_shown_id = String(data.id)
	if _arena:
		_arena.queue_free()
	_arena = data.scene.instantiate()
	_viewport.add_child(_arena)
	var camera := _arena.get_node_or_null("Camera") as Camera2D
	if camera:
		camera.make_current()
