class_name PlayerLabels
extends Node2D
## Name and damage percent above a character. A child of the Player, so it blinks with it;
## the Player moves it by its visual_offset. The arena camera is zoomed out, so world-space
## text needs a big font to stay readable.

const FONT_SIZE := 26

var _name_label: Label
var _damage_label: Label
var _shown_damage := -1


func setup(player_name: String, name_color: Color, body_height: float) -> void:
	_name_label = Label.new()
	_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name_label.text = player_name
	_name_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size = Vector2(240, 36)
	_name_label.position = Vector2(-120, -body_height / 2.0 - 54)
	add_child(_name_label)
	set_name_color(name_color)
	_damage_label = Label.new()
	_damage_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_damage_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_damage_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	_damage_label.add_theme_constant_override("outline_size", 6)
	_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_label.size = Vector2(120, 32)
	_damage_label.position = Vector2(-60, -body_height / 2.0 - 86)
	add_child(_damage_label)


func set_name_color(color: Color) -> void:
	_name_label.add_theme_color_override("font_color", color)


## "37 %": white at 0 %, yellow at 50 %, red at 100 %. The text only changes when the whole
## percent changes.
func show_damage(damage: float) -> void:
	var shown := roundi(damage)
	if shown == _shown_damage:
		return
	_shown_damage = shown
	_damage_label.text = "%d %%" % shown
	var t := shown / CombatRules.MAX_DAMAGE
	var yellow := Color(1.0, 0.82, 0.25)
	var color := Color.WHITE.lerp(yellow, t * 2.0) if t < 0.5 else yellow.lerp(Color(1.0, 0.25, 0.2), (t - 0.5) * 2.0)
	_damage_label.add_theme_color_override("font_color", color)
