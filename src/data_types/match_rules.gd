class_name MatchRules
extends Resource
## Match-wide rules, edited in data/match_rules.tres.

@export var lives: int = 5
## Seconds between falling out and reappearing.
@export var respawn_delay: float = 1.5
## Seconds a player may stay out of the arena before losing a life (room for comebacks,
## e.g. a future flying ability).
@export var out_of_bounds_grace: float = 0.5
## Seconds of knockback immunity after a respawn.
@export var respawn_invulnerability: float = 1.5
@export var countdown_seconds: int = 3
