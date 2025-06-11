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
	"poe": 2.1,
	"taw": 3.0,
	"sue": 3.7,
}

# Signal for requesting a move from the Nomino node
signal request_move(new_pos: Vector2i)
signal selection_changed(nomino_node: Node, is_selected: bool)

var is_selected: bool = false

var collision_shape

var current_selected_nomino: Area2D = null

var world_pos: Vector2i # Logical world/tile coordinate

# Static flag to enable test mode (bypasses tweens for testability)
static var test_mode: bool = false

func _ready():
	# Set timer wait_time and sprite based on species
	var wait_time = SPECIES_HOP_TIME[species] if SPECIES_HOP_TIME.has(species) else 5.0

	# Add a timer to each Nomino
	timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = false
	timer.autostart = false # Do not start yet
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	# timer.start() # Do not start here

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

	# Initialize world_pos from position (if needed, e.g. if placed by editor)
	# world_pos = Vector2i(int(position.x), int(position.y)) # Disabled: world_pos is set by GameWorldManager

	input_pickable = true
	z_index = 1000

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_selected(true)
		var gwm = get_tree().get_root().find_child("GameWorldManager", true, false)
		if gwm:
			gwm.nomino_click_handled_this_frame = true
		# event.consume() # Preferred in Godot 4.x, but if it fails, use the line below:
		# get_viewport().set_input_as_handled() # Fallback: prevent event from propagating to tile below

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
			sprite.modulate = Color(1.5, 1.5, 1.5, 1) # Lighten
		else:
			sprite.modulate = Color(1, 1, 1, 1) # Normal
	# --- Emit selection signal instead of notifying GameWorldManager directly ---
	emit_signal("selection_changed", self, selected)

func _on_timer_timeout():
	# --- Nomino autonomous movement logic ---
	if move_types.size() > 0:
		var move_pattern = move_types[randi() % move_types.size()]
		if NOMINO_MOVES.has(move_pattern):
			var options = NOMINO_MOVES[move_pattern]
			# Filter options to only those that stay in bounds
			var gwm = get_tree().get_root().find_child("GameWorldManager", true, false)
			var world_width = 64
			var world_height = 64
			if gwm:
				world_width = gwm.WORLD_WIDTH
				world_height = gwm.WORLD_HEIGHT
			var valid_options = []
			for delta in options:
				var new_world_pos = world_pos + delta
				if new_world_pos.x >= 0 and new_world_pos.x < world_width and new_world_pos.y >= 0 and new_world_pos.y < world_height:
					valid_options.append(delta)
			if valid_options.size() > 0:
				var delta = valid_options[randi() % valid_options.size()]
				var new_world_pos = world_pos + delta
				if test_mode:
					# In test mode, immediately emit move
					emit_signal("request_move", new_world_pos)
					return
				# --- Animate hop from current to new world position ---
				# Convert world positions to screen positions
				var origin_world = world_pos
				var dest_world = new_world_pos
				var origin_view = Vector2(origin_world.x, origin_world.y)
				var dest_view = Vector2(dest_world.x, dest_world.y)
				if gwm and gwm.has_method("world_to_viewboard_coords") and gwm.has_method("viewboard_to_screen_coords"):
					origin_view = gwm.world_to_viewboard_coords(origin_world.x, origin_world.y)
					dest_view = gwm.world_to_viewboard_coords(dest_world.x, dest_world.y)
					# Match update_nomino_positions: subtract 1 from both x and y
					origin_view.x -= 1
					origin_view.y -= 1
					dest_view.x -= 1
					dest_view.y -= 1
					var origin_screen = gwm.viewboard_to_screen_coords(origin_view.x, origin_view.y)
					var dest_screen = gwm.viewboard_to_screen_coords(dest_view.x, dest_view.y)
					var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
					origin_screen += screen_offset
					dest_screen += screen_offset
					# --- Apply elevation offset to both origin and destination ---
					if gwm and gwm.elevation_map and gwm.elevation_map.size() > origin_world.x and gwm.elevation_map[origin_world.x].size() > origin_world.y:
						origin_screen.y -= gwm.elevation_map[origin_world.x][origin_world.y] * 6
					if gwm and gwm.elevation_map and gwm.elevation_map.size() > dest_world.x and gwm.elevation_map[dest_world.x].size() > dest_world.y:
						dest_screen.y -= gwm.elevation_map[dest_world.x][dest_world.y] * 6
					# Animate position and y-offset for parabola
					var hop_height = 32
					var hop_duration = 0.5
					var tw = create_tween()
					tw.tween_property(self, "position", origin_screen, 0.0)
					tw.parallel().tween_property(self, "position", dest_screen, hop_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					tw.parallel().tween_property(sprite, "position:y", -hop_height, hop_duration/2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
					tw.tween_property(sprite, "position:y", 0, hop_duration/2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
					tw.connect("finished", Callable(self, "_on_hop_animation_finished").bind(new_world_pos))
				else:
					# Fallback: just emit move immediately
					emit_signal("request_move", new_world_pos)
			# else: no valid moves, just hop in place
	else:
		# No move: just hop in place (in-place parabola)
		if test_mode:
			return # skip animation in test mode
		# ...existing code...

func _on_hop_animation_finished(new_world_pos):
	if test_mode:
		emit_signal("request_move", new_world_pos)
		return
	emit_signal("request_move", new_world_pos)

const NOMINO_MOVES = {
	"orthostep": [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)],
	"diagstep": [Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1)],
	"orthojump": [Vector2i(0, -2), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, 2)],
	"diagjump": [Vector2i(2, -2), Vector2i(-2, -2), Vector2i(2, 2), Vector2i(-2, 2)],
	"clockwiseknight": [Vector2i(1, -2), Vector2i(-2, -1), Vector2i(2, 1), Vector2i(2, -1)],
	"counterknight": [Vector2i(2, -1), Vector2i(-2, -1), Vector2i(2, 1), Vector2i(-2, 1)],
}

func _input(event):
	# print("DEBUG: _input called for ", self, " event=", event)
	pass

func set_world_pos(new_pos: Vector2i):
	world_pos = new_pos

# Call this after world_pos is set to start the timer
func start_autonomous_timer():
	if timer and not timer.is_stopped():
		return
	timer.start()
