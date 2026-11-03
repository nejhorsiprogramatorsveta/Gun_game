class_name MatchHud
extends Control
## In-match overlay: lives of every player and the start countdown.

@onready var _lives_label: Label = %LivesLabel
@onready var _countdown_label: Label = %CountdownLabel


func show_state(players: Array, countdown: int, show_lives: bool) -> void:
	_countdown_label.visible = countdown > 0
	_countdown_label.text = str(countdown)
	_lives_label.visible = show_lives
	if not show_lives:
		return
	var lines: PackedStringArray = []
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: Player, b: Player) -> bool: return a.slot < b.slot)
	for player: Player in sorted:
		var key := "HUD_LIVES" if player.lives > 0 else "HUD_ELIMINATED"
		lines.append(tr(key).format({"name": player.display_name, "lives": player.lives}))
	_lives_label.text = "\n".join(lines)
