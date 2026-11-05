class_name AbilityData
extends Resource
## A character's special ability (PLAN.md G.1). Shared by every player with this character,
## so it holds only parameters; runtime state (cooldown, time left) lives in Player.
## A new KIND of ability = a small subclass in src/abilities/; a new variant = a new .tres.
## Only the authority (host, practice) activates abilities; clients see the result in snapshots.

@export var id: StringName
@export var name_key: String
@export var description_key: String
## Seconds before the ability can be used again (counted from activation).
@export var cooldown: float = 8.0
## Seconds the ability stays active (0 = instant). Shown to everyone via the snapshot flag.
@export var duration: float = 0.0


## Shared by the host and client prediction (runs inside Player.simulate): changes to the
## user's OWN movement only, so the client predicts them exactly (jetpack, teleport).
func start(_user: Player, _input: InputFrame) -> void:
	pass


## Authority only: effects on OTHER players (e.g. shockwave), after the user moved.
## Apply the instant part of the ability. `players` = everyone in the match.
## Return the players that were pushed, so the score can credit the user.
func activate(_user: Player, _players: Array) -> Array[Player]:
	return []


## World object this ability leaves behind (cloud, platform), see AreaEffects. null = none.
func create_effect(_owner_peer_id: int) -> Node2D:
	return null


## Multiplier for knockback the user receives while the ability is active.
func knockback_scale() -> float:
	return 1.0


## Whether the user may shoot while the ability is active.
func allows_firing() -> bool:
	return true
