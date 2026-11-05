class_name KillPopup
extends Node2D
## Arcade "KILL!" above the player who scored (child of that Player, so it follows them):
## pops in, floats up and fades. DOUBLE / TRIPLE / MULTI KILL for kills in quick succession.

const LIFETIME := 1.4
const RISE := 46.0
## Above the name label (Player name label sits at -BODY_SIZE.y / 2 - 54).
const START_Y := -Player.BODY_SIZE.y / 2.0 - 78.0

var _label := Label.new()
var _age := 0.0


static func text_for(streak: int) -> String:
	if streak >= 4:
		return TranslationServer.translate("POPUP_MULTI_KILL").format({"count": streak})
	return TranslationServer.translate(["POPUP_KILL", "POPUP_DOUBLE_KILL", "POPUP_TRIPLE_KILL"][clampi(streak, 1, 3) - 1])


func setup(streak: int) -> void:
	_label.text = text_for(streak)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 32 if streak <= 1 else 38)
	_label.add_theme_color_override("font_color", Color(1, 0.86, 0.3) if streak <= 1 else Color(1, 0.45, 0.25))
	_label.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.09))
	_label.add_theme_constant_override("outline_size", 8)
	_label.size = Vector2(320, 48)
	_label.position = Vector2(-160, -24)
	_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_label)
	position = Vector2(0, START_Y)
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var t := _age / LIFETIME
	position.y = START_Y - RISE * t
	# Pop: overshoot to 1.3x in the first 0.12 s, then settle at 1x.
	var pop := minf(_age / 0.12, 1.0)
	scale = Vector2.ONE * (lerpf(0.4, 1.3, pop) if _age < 0.12 else lerpf(1.3, 1.0, minf((_age - 0.12) / 0.1, 1.0)))
	modulate.a = clampf((LIFETIME - _age) / 0.4, 0.0, 1.0)
