class_name MatchRules
extends Resource
## Match-wide rules, edited in data/match_rules.tres.

@export var lives: int = 5
## Seconds between falling out and reappearing.
@export var respawn_delay: float = 1.5
## Seconds of knockback immunity after a respawn.
@export var respawn_invulnerability: float = 1.5
@export var countdown_seconds: int = 3
