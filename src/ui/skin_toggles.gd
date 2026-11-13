class_name SkinToggles
extends HBoxContainer
## Two switches "Character skin: <name>" and "Weapon skin: <name>" for the chosen character
## (user 2026-11-13: one skin per character and per weapon). The choice is one setting for
## every character (Settings.skins, CharacterData.SKIN_* bits); `changed` tells the lobby to
## send it to the host. Used in the main menu (practice) and in the lobby.

signal changed(skins: int)

const FONT_SIZE := 14

var _character_button := CheckButton.new()
var _weapon_button := CheckButton.new()


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	for button: CheckButton in [_character_button, _weapon_button]:
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggled.connect(func(_on: bool) -> void: _on_toggled())
		add_child(button)
	_character_button.set_pressed_no_signal(Settings.skins & CharacterData.SKIN_CHARACTER != 0)
	_weapon_button.set_pressed_no_signal(Settings.skins & CharacterData.SKIN_WEAPON != 0)


## Names of the chosen character's skins on the switches (hidden when it has none).
func show_character(character_id: String) -> void:
	var character := ContentDB.get_character(StringName(character_id))
	var weapon := character.weapon if character else null
	_character_button.visible = character != null and character.skin_sheet != null
	_weapon_button.visible = weapon != null and weapon.skin_sprite != null
	if _character_button.visible:
		_character_button.text = tr("SKIN_CHARACTER_TOGGLE").format({"skin": tr(character.skin_name_key)})
	if _weapon_button.visible:
		_weapon_button.text = tr("SKIN_WEAPON_TOGGLE").format({"skin": tr(weapon.skin_name_key)})


func _on_toggled() -> void:
	Settings.skins = (CharacterData.SKIN_CHARACTER if _character_button.button_pressed else 0) \
			| (CharacterData.SKIN_WEAPON if _weapon_button.button_pressed else 0)
	Settings.save()
	changed.emit(Settings.skins)
