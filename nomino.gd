extends Area2D
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

# Signal for requesting a move from the Nomino node
signal request_move(new_pos: Vector2i)

var is_selected: bool = false

var collision_shape

var current_selected_nomino: Area2D = null

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

	# Add to Nominos group for selection logic
	add_to_group("Nominos")

	# Add a CollisionShape2D for input hit detection if not present
	if not has_node("CollisionShape2D"):
		var new_collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		if sprite and sprite.texture:
			var tex_size = sprite.texture.get_size()
			rect_shape.size = tex_size
		else:
			rect_shape.size = Vector2(32, 32) # fallback size
		new_collision_shape.shape = rect_shape
		new_collision_shape.position = Vector2.ZERO
		add_child(new_collision_shape)
	# Assign RectangleShape2D to CollisionShape2D if not set in editor
	collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape and not collision_shape.shape:
		var new_rect_shape = RectangleShape2D.new()
		new_rect_shape.extents = Vector2(32, 32)
		collision_shape.shape = new_rect_shape

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_selected(true)
		print("DEBUG: Nomino sprite clicked and selected at pos=", position)
		# event.consume() # Preferred in Godot 4.x, but if it fails, use the line below:
		get_viewport().set_input_as_handled() # Fallback: prevent event from propagating to tile below

func set_selected(selected: bool):
	# Only update if the value is actually changing
	if is_selected == selected:
		return
	if selected:
		for n in get_tree().get_nodes_in_group("Nominos"):
			if n != self:
				n.set_selected(false)
	is_selected = selected
	if selected:
		if current_selected_nomino and current_selected_nomino != self:
			current_selected_nomino.set_selected(false)
		current_selected_nomino = self
	else:
		if current_selected_nomino == self:
			current_selected_nomino = null
	if sprite:
		if selected:
			print("DEBUG: set_selected called, should lighten sprite")
			sprite.modulate = Color(1.5, 1.5, 1.5, 1) # Lighten
		else:
			sprite.modulate = Color(1, 1, 1, 1) # Normal

func _on_timer_timeout():
	# Animate jump: up then down, using cubic ease in/out
	var jump_height = 32
	var jump_duration = 0.25
	var fall_duration = 0.25

	# Animate only the sprite's y offset, not the world position
	var tw = create_tween()
	tw.tween_property(sprite, "position:y", sprite.position.y - jump_height, jump_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", 0, fall_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# --- Nomino autonomous movement logic ---
	# Pick a random move from move_types, if any
	if move_types.size() > 0:
		var move_pattern = move_types[randi() % move_types.size()]
		if NOMINO_MOVES.has(move_pattern):
			var options = NOMINO_MOVES[move_pattern]
			var delta = options[randi() % options.size()]
			# Request a move via signal (let world manager validate and apply)
			var new_pos = Vector2i(int(position.x), int(position.y)) + Vector2i(int(delta.x), int(delta.y))
			emit_signal("request_move", new_pos)

const NOMINO_MOVES = {
	"orthostep": [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)],
	"diagstep": [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)],
	"orthojump": [Vector2(0, -2), Vector2(-2, 0), Vector2(2, 0), Vector2(0, 2)],
	"diagjump": [Vector2(2, -2), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2)],
	"clockwiseknight": [Vector2(1, -2), Vector2(-2, -1), Vector2(2, 1), Vector2(2, -1)],
	"counterknight": [Vector2(2, -1), Vector2(-2, -1), Vector2(2, 1), Vector2(-2, 1)],
}

func _input(event):
	# print("DEBUG: _input called for ", self, " event=", event)
	pass
