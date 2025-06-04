extends Node2D
#

var move_types: Array[String] = []  # e.g. ["orthostep", "diagstep"]
var timer: Timer
var original_position: Vector2

var sprite: Sprite2D

var species: String = "poe" # "poe", "taw", or "sue". Default to poe.

# Sprite textures for each species
const SPECIES_SPRITES = {
	"poe": preload("res://assets/sprites/nomino0.png"),
	"taw": preload("res://assets/sprites/nomino1.png"),
	"sue": preload("res://assets/sprites/nomino2.png")
}

# Hop timer for each species
const SPECIES_HOP_TIME = {
	"poe": 5.0,
	"taw": 3.5,
	"sue": 6.5
}

func _ready():
	# Set timer wait_time and sprite based on species
	var wait_time = SPECIES_HOP_TIME[species] if SPECIES_HOP_TIME.has(species) else 5.0

	# Add a timer to each Nomino
	timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

	# Store original position for jump animation
	original_position = position

	# Get reference to Sprite2D
	sprite = get_node("Sprite2D")
	# Assign correct sprite for species
	if SPECIES_SPRITES.has(species):
		sprite.texture = SPECIES_SPRITES[species]
	else:
		push_warning("Unknown species: %s. Using default sprite." % species)

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
