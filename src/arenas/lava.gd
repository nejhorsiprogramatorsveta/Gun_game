class_name Lava
extends Node2D
## Rising lava of an arena (Peklo). It glows at the bottom from the start; once any player
## is down to `start_at_lives` lives it rises at `rise_speed` until `top_y`, just under the
## highest platform. A player whose feet touch it loses a life at once (MatchController).
## The host decides the level and sends it in every snapshot; clients only show it. While
## it rises, respawns only use spawn points above `top_y` (safe_feet_y).

signal started_rising

const SURFACE: Texture2D = preload("res://assets/sprites/tiles/lava_surface.png")
const FILL: Texture2D = preload("res://assets/sprites/tiles/lava_fill.png")
const SURFACE_SIZE := Vector2(32, 12)
const SURFACE_FRAMES := 4
## Rows of the surface tile above the wave crest (the crest is the deadly level).
const CREST_ROW := 3
const PIXEL_SCALE := 2.0
## Respawned feet stay at least this far above the lava's final level.
const SPAWN_CLEARANCE := 30.0

## Lava surface (y, px) at the start, below every platform, and where it stops rising.
@export var start_y := 880.0
@export var top_y := 290.0
@export var rise_speed := 14.0
## It starts rising when any player has this many lives left (practice: counted from deaths).
@export var start_at_lives := 3
## Horizontal extent drawn and the bottom of the drawing (arena coordinates).
@export var draw_from_x := -800.0
@export var draw_to_x := 2100.0
@export var bottom_y := 1300.0

var level := 0.0
var rising := false
var _age := 0.0


func _ready() -> void:
	level = start_y
	z_index = 1  # in front of players and platforms: what it covers is under the lava
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Authority, every match tick. lives_at_start: MatchRules.lives; networked: lives count
## (otherwise practice with endless lives, where deaths count instead).
func tick(players: Array, lives_at_start: int, networked: bool, delta: float) -> void:
	if not rising:
		for player: Player in players:
			var lives_left := player.lives if networked else lives_at_start - player.deaths
			if lives_left <= start_at_lives:
				rising = true
				started_rising.emit()
				break
	if rising:
		level = maxf(level - rise_speed * delta, top_y)


## Client: the level from the host's snapshot.
func show_level(y: float) -> void:
	level = y
	if not rising and y < start_y - 0.5:
		rising = true
		started_rising.emit()


func touches(player: Player) -> bool:
	return player.global_position.y + Player.BODY_SIZE.y / 2.0 >= level


## Respawned feet must be above this y: the final level once it rises, else the current one.
func safe_feet_y() -> float:
	return (top_y if rising else level) - SPAWN_CLEARANCE


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	# Pixel-art tiles (tools/art/generate_world.py) at PIXEL_SCALE: a glow above the surface,
	# the moving wavy crest, then molten rock down to bottom_y.
	var glow_height := 48.0
	for i in 6:
		var y := level - glow_height * (i + 1) / 6.0
		draw_rect(Rect2(draw_from_x, y, draw_to_x - draw_from_x, glow_height / 6.0), Color(1.0, 0.45, 0.1, 0.05 * (6 - i)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PIXEL_SCALE)
	var top := level / PIXEL_SCALE - CREST_ROW
	var frame := int(_age * 5.0) % SURFACE_FRAMES
	var x := draw_from_x / PIXEL_SCALE
	while x < draw_to_x / PIXEL_SCALE:
		draw_texture_rect_region(SURFACE, Rect2(Vector2(x, top), SURFACE_SIZE),
				Rect2(Vector2(frame * SURFACE_SIZE.x, 0), SURFACE_SIZE))
		x += SURFACE_SIZE.x
	var fill_top := top + SURFACE_SIZE.y
	draw_texture_rect(FILL, Rect2(Vector2(draw_from_x / PIXEL_SCALE, fill_top),
			Vector2((draw_to_x - draw_from_x) / PIXEL_SCALE, maxf(bottom_y / PIXEL_SCALE - fill_top, 0.0))), true)
