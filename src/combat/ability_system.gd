class_name AbilitySystem
extends RefCounted
## Authority: cooldowns and activation of special abilities (PLAN.md G.1, G.2).
## The ABILITY button activates on press (not while held), when the cooldown is over.

signal player_hit(attacker_peer_id: int, target: Player)


## Call every tick after the player moved. `players` = everyone in the match.
func tick(player: Player, input: InputFrame, delta: float, players: Array) -> void:
	player.ability_cooldown = maxf(player.ability_cooldown - delta, 0.0)
	player.ability_time_left = maxf(player.ability_time_left - delta, 0.0)
	var held := input.is_held(InputFrame.ABILITY)
	var pressed := held and not player.ability_was_held
	player.ability_was_held = held
	var ability := player.character.ability if player.character else null
	if ability == null or not pressed or player.ability_cooldown > 0.0:
		return
	player.ability_cooldown = ability.cooldown
	player.ability_time_left = ability.duration
	for target in ability.activate(player, players):
		player_hit.emit(player.peer_id, target)
