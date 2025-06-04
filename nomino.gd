extends Node2D
#

var move_types: Array[String] = []  # e.g. ["orthostep", "diagstep"]
var timer: Timer
var original_position: Vector2

var sprite: Sprite2D

func _ready():
	# Add a 5-second timer to each Nomino
	timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

	# Store original position for jump animation
	original_position = position

	# Get reference to Sprite2D
	sprite = get_node("Sprite2D")

func _on_timer_timeout():
	# Animate jump: up then down, using cubic ease in/out
	var jump_height = 32
	var jump_duration = 0.25
	var fall_duration = 0.25

	# Animate only the sprite's y offset, not the world position
	var tw = create_tween()
	tw.tween_property(sprite, "position:y", sprite.position.y - jump_height, jump_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", 0, fall_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

const NOMINO_MOVES = {
	"orthostep": [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)],
	"diagstep": [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)],
	"orthojump": [Vector2(0, -2), Vector2(-2, 0), Vector2(2, 0), Vector2(0, 2)],
	"diagjump": [Vector2(2, -2), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2)],
	"clockwiseknight": [Vector2(1, -2), Vector2(-2, -1), Vector2(2, 1), Vector2(2, -1)],
	"counterknight": [Vector2(2, -1), Vector2(-2, -1), Vector2(2, 1), Vector2(-2, 1)],
}
