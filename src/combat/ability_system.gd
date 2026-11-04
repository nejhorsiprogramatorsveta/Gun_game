class_name AbilitySystem
extends RefCounted
## Authority: effects of special abilities on OTHER players (PLAN.md G.1, G.2).
## Cooldowns, activation on press and effects on the user's own movement run in
## Player.tick_ability() so client prediction computes them identically.

signal player_hit(attacker_peer_id: int, target: Player)


## Call every tick after the player moved. `players` = everyone in the match.
func tick(player: Player, players: Array) -> void:
	if not player.ability_started:
		return
	for target in player.character.ability.activate(player, players):
		player_hit.emit(player.peer_id, target)
