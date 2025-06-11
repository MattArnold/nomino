extends Node2D
const NOMINO_SCENE = preload("res://nomino.tscn")

const WORLD_WIDTH = 64
const WORLD_HEIGHT = 64

# Grid configuration
const SEA_LEVEL = -0.5
const VIEWBOARD_PIXEL_WIDTH := 768.0
var GRID_SIZE = DEFAULT_GRID_SIZE  # Number of tiles along each edge of the viewboard
var TILE_WIDTH = VIEWBOARD_PIXEL_WIDTH / GRID_SIZE  # Width of each tile in pixels
var TILE_HEIGHT = TILE_WIDTH / 2  # Height of each tile in pixels (half of width for isometric)

# World position offset - this determines which part of the world we're viewing
var world_offset_x = 0
var world_offset_y = 0

# Storage for tile sprites
var tile_sprites = []
var terrain_map = []
var elevation_map = []

var current_viewboard_input := Vector2.ZERO
var input_hold_timer := 0.0
var input_repeat_timer := 0.0
var previous_input := Vector2.ZERO
const INPUT_REPEAT_DELAY := 0.3
const INPUT_REPEAT_RATE := 0.1

var terrain_noise := FastNoiseLite.new()
var elevation_noise := FastNoiseLite.new()

var nominos = []  # stores NominoData instances

var tile_textures = {
	"grass": preload("res://assets/tiles/grass_cube.png"),
	"sand": preload("res://assets/tiles/sand_cube.png"),
	"water": preload("res://assets/tiles/water_cube.png"),
	"plants": preload("res://assets/tiles/plants_grass_cube.png"),
	"border": preload("res://assets/tiles/border_cube.png"), # Added border texture
}

# Nomino sprite textures for random assignment
const NOMINO_SPRITES = [
	preload("res://assets/sprites/nomino0.png"),
	preload("res://assets/sprites/nomino1.png"),
	preload("res://assets/sprites/nomino2.png")
]

const NUM_NOMINOS = 99 # Number of Nominos to spawn
const DEFAULT_GRID_SIZE = 12 # Default number of tiles along each edge of the viewboard

var nomino_click_handled_this_frame: bool = false

# --- Highlighting for Nomino move targets ---
var highlighted_tiles := [] # Array of (vx, vy) tuples currently highlighted
var selected_nomino: Node = null # Reference to currently selected NominoData or node

func _ready():
	randomize()
	# Add a dedicated NominoLayer for nomino sprites
	if not has_node("NominoLayer"):
		var nomino_layer = Node2D.new()
		nomino_layer.name = "NominoLayer"
		add_child(nomino_layer)
	# Set noise type for terrain_noise and elevation_noise in the Godot editor Inspector, not in code.
	terrain_noise.seed = randi()
	terrain_noise.frequency = 1  # controls patch size
	elevation_noise.seed = randi()
	elevation_noise.frequency = 0.1
	# --- Use TerrainGenerator utility ---
	var result = TerrainGenerator.generate_terrain_and_elevation(WORLD_WIDTH, WORLD_HEIGHT, world_offset_x, world_offset_y, SEA_LEVEL, terrain_noise, elevation_noise)
	terrain_map = result["terrain_map"]
	elevation_map = result["elevation_map"]
	decorate_terrain()
	place_tiles()
	spawn_nominos()
	# spawn_nomino() # For debugging

func decorate_terrain():
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if terrain_map[x][y] != "grass":
				continue

			# Check cardinal neighbors
			var adjacent_types = []
			for offset in [Vector2(-1,0), Vector2(1,0), Vector2(0,-1), Vector2(0,1)]:
				var nx = x + int(offset.x)
				var ny = y + int(offset.y)

				if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
					adjacent_types.append("edge")  # treat out-of-bounds as edge
				else:
					adjacent_types.append(terrain_map[nx][ny])

			# Promote grass to grass+plants if fully surrounded by grass
			if adjacent_types.all(func(t): return t == "grass"):
				terrain_map[x][y] = "plants"

func place_tiles():
	# Clear existing tiles from scene and memory
	for row in tile_sprites:
		for sprite in row:
			if is_instance_valid(sprite):
				sprite.queue_free()
	tile_sprites.clear()

	# Create new tile sprites for current GRID_SIZE
	tile_sprites = []
	for vx in range(GRID_SIZE):
		tile_sprites.append([])
		for vy in range(GRID_SIZE):
			var wx = vx + world_offset_x
			var wy = vy + world_offset_y

			var tile_sprite
			if wx < 0 or wx >= WORLD_WIDTH or wy < 0 or wy >= WORLD_HEIGHT:
				# Out-of-bounds: show border sprite
				tile_sprite = Sprite2D.new()
				tile_sprite.texture = tile_textures["border"]
				tile_sprite.z_index = 0
				# Scale border sprite
				var tex_size = tile_sprite.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					tile_sprite.scale = Vector2(TILE_WIDTH / tex_size.x, TILE_WIDTH / tex_size.y)
			else:
				tile_sprite = create_tile_sprite(wx, wy)
			tile_sprites[vx].append(tile_sprite)
			add_child(tile_sprite)
			# Position sprite immediately
			var screen_pos = viewboard_to_screen_coords(vx, vy)
			var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
			tile_sprite.position = screen_pos + screen_offset
			if wx >= 0 and wx < WORLD_WIDTH and wy >= 0 and wy < WORLD_HEIGHT:
				var elevation = elevation_map[wx][wy]
				tile_sprite.position.y -= elevation * 6

func create_tile_sprite(wx, wy):
	var vx = wx - world_offset_x
	var vy = wy - world_offset_y

	var sprite = Sprite2D.new()
	var terrain_type = terrain_map[wx][wy]
	var elevation = elevation_map[wx][wy]
	sprite.texture = tile_textures[terrain_type]
	sprite.z_index = sprite.position.y

	# Scale the sprites to prevent them getting gaps when zooming in
	var tex_size = sprite.texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		sprite.scale = Vector2(TILE_WIDTH / tex_size.x, TILE_WIDTH / tex_size.y)

	var screen_pos = viewboard_to_screen_coords(vx, vy)
	var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
	sprite.position = screen_pos + screen_offset
	sprite.position.y -= elevation * 6

	return sprite

# Converts viewboard grid coordinates (0..GRID_SIZE-1) to screen pixel coordinates for isometric rendering.
# The resulting Vector2 is the pixel position on screen for the top-left corner of the tile at (viewboard_x, viewboard_y).
func viewboard_to_screen_coords(viewboard_x, viewboard_y):
	# Convert viewboard grid coordinates to screen pixel coordinates
	# This creates the isometric diamond pattern
	var screen_x = (viewboard_x - viewboard_y) * (TILE_WIDTH / 2)
	var screen_y = (viewboard_x + viewboard_y) * (TILE_HEIGHT / 2)
	return Vector2(screen_x, screen_y)

# Converts a screen pixel position (relative to the viewboard origin) back to viewboard grid coordinates.
# Returns a Vector2 of (viewboard_x, viewboard_y), rounded to the nearest integer grid cell.
func screen_to_viewboard_coords(screen_pos):
	# Convert screen pixel coordinates back to viewboard grid coordinates
	# This reverses the isometric transformation
	var temp_x = screen_pos.x / (TILE_WIDTH / 2) + screen_pos.y / (TILE_HEIGHT / 2)
	var temp_y = screen_pos.y / (TILE_HEIGHT / 2) - screen_pos.x / (TILE_WIDTH / 2)

	# Round to nearest integer coordinates
	var viewboard_x = int(round(temp_x / 2))
	var viewboard_y = int(round(temp_y / 2))

	return Vector2(viewboard_x, viewboard_y)

# Converts viewboard grid coordinates to world coordinates (absolute position in the game world).
# Returns a Vector2 of (world_x, world_y).
func viewboard_to_world_coords(viewboard_x, viewboard_y):
	return Vector2(viewboard_x + world_offset_x, viewboard_y + world_offset_y)

# Converts world coordinates to viewboard grid coordinates (relative to the current viewboard offset).
# Returns a Vector2 of (viewboard_x, viewboard_y).
func world_to_viewboard_coords(world_x, world_y):
	return Vector2(world_x - world_offset_x, world_y - world_offset_y)

func update_viewboard_tiles():
	for vx in range(GRID_SIZE):
		for vy in range(GRID_SIZE):
			var wx = vx + world_offset_x
			var wy = vy + world_offset_y

			var sprite = tile_sprites[vx][vy]
			if wx < 0 or wx >= WORLD_WIDTH or wy < 0 or wy >= WORLD_HEIGHT:
				sprite.texture = tile_textures["border"]
				sprite.visible = true
				# Scale border sprite
				var tex_size = sprite.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					sprite.scale = Vector2(TILE_WIDTH / tex_size.x, TILE_WIDTH / tex_size.y)
				# Position
				var screen_pos = viewboard_to_screen_coords(vx, vy)
				var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
				sprite.position = screen_pos + screen_offset
			else:
				sprite.visible = true
				var terrain_type = terrain_map[wx][wy]
				var elevation = elevation_map[wx][wy]
				sprite.texture = tile_textures[terrain_type]
				# Scale
				var tex_size = sprite.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					sprite.scale = Vector2(TILE_WIDTH / tex_size.x, TILE_WIDTH / tex_size.y)
				# Position
				var screen_pos = viewboard_to_screen_coords(vx, vy)
				var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
				sprite.position = screen_pos + screen_offset
				sprite.position.y -= elevation * 6

	clear_tile_highlights()
	# Re-apply highlights if a Nomino is selected
	if selected_nomino:
		highlight_nomino_targets(selected_nomino)

func update_nomino_positions():
	for n in nominos:
		if not is_instance_valid(n.node):
			push_warning("update_nomino_positions: Nomino node is not valid.")
			continue  # node has been freed or not created yet
		var world_x = n.pos.x
		var world_y = n.pos.y
		var viewboard_x = world_x - world_offset_x
		var viewboard_y = world_y - world_offset_y
		# Error logging for out-of-bounds
		if world_x < 0 or world_x >= WORLD_WIDTH or world_y < 0 or world_y >= WORLD_HEIGHT:
			push_warning("update_nomino_positions: Nomino position out of world bounds: (" + str(world_x) + ", " + str(world_y) + ")")
			continue
		# Check if Nomino is in view
		if viewboard_x < 0 or viewboard_x >= GRID_SIZE or viewboard_y < 0 or viewboard_y >= GRID_SIZE:
			n.node.visible = false
			continue
		var screen_pos = viewboard_to_screen_coords(viewboard_x - 1, viewboard_y - 1)
		var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
		n.node.position = screen_pos + screen_offset
		if world_x >= 0 and world_x < WORLD_WIDTH and world_y >= 0 and world_y < WORLD_HEIGHT:
			n.node.position.y -= elevation_map[world_x][world_y] * 6
		else:
			push_warning("update_nomino_positions: Elevation map out-of-bounds for (" + str(world_x) + ", " + str(world_y) + ")")
		n.node.z_index = 1000 + world_y
		n.node.visible = true
		# --- Ensure nomino sprite scales with zoom ---
		var sprite2d = n.node.get_node_or_null("Sprite2D")
		if sprite2d and sprite2d.texture:
			var tex_size = sprite2d.texture.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				sprite2d.scale = Vector2(TILE_WIDTH / tex_size.x, TILE_WIDTH / tex_size.y)
		else:
			push_warning("update_nomino_positions: Sprite2D or its texture missing for Nomino node.")

func move_viewboard(dx, dy):
	# Allow scrolling one step past the world bounds for border display
	var new_offset_x = clamp(world_offset_x + dx, -1, WORLD_WIDTH - GRID_SIZE + 1)
	var new_offset_y = clamp(world_offset_y + dy, -1, WORLD_HEIGHT - GRID_SIZE + 1)
	if new_offset_x == world_offset_x and new_offset_y == world_offset_y:
		return # No movement if already at edge
	world_offset_x = new_offset_x
	world_offset_y = new_offset_y
	update_viewboard_tiles()
	update_nomino_positions()
	# Notify controls to update button states
	var controls = get_tree().get_root().find_child("ViewboardControls", true, false)
	if controls and controls.has_method("update_scroll_buttons"):
		controls.update_scroll_buttons()

func _process(delta):
	call_deferred("_reset_nomino_click_flag")

	var input = Vector2.ZERO

	# WASD or Arrow Keys
	if Input.is_action_pressed("view_north"):
		input.y -= 1
	if Input.is_action_pressed("view_south"):
		input.y += 1
	if Input.is_action_pressed("view_west"):
		input.x -= 1
	if Input.is_action_pressed("view_east"):
		input.x += 1

	# HUD pad input from viewboard_root.gd
	if input == Vector2.ZERO:
		input = current_viewboard_input

	if input != Vector2.ZERO:
		if input != previous_input:
			move_viewboard(input.x, input.y)
			input_repeat_timer = INPUT_REPEAT_DELAY
		else:
			input_repeat_timer -= delta
			if input_repeat_timer <= 0.0:
				move_viewboard(input.x, input.y)
				input_repeat_timer = INPUT_REPEAT_RATE
	else:
		input_repeat_timer = 0.0

	previous_input = input

func _reset_nomino_click_flag():
	nomino_click_handled_this_frame = false

# Spawns all Nominos at unique positions and assigns them random movement patterns.
# Each Nomino is a dictionary with keys: 'pos' (Vector2i), 'node' (instance), and 'move_types' (Array of movement pattern names).
func spawn_nominos():
	nominos.clear() # Clear any previous nominos
	# Remove and recreate NominoLayer cleanly
	if has_node("NominoLayer"):
		var old_layer = get_node("NominoLayer")
		remove_child(old_layer)
		old_layer.queue_free()
	var nomino_layer = Node2D.new()
	nomino_layer.name = "NominoLayer"
	add_child(nomino_layer)

	# --- Ensure unique positions for each nomino ---
	var all_positions = []
	for x in range(WORLD_WIDTH):
		for y in range(WORLD_HEIGHT):
			all_positions.append(Vector2i(x, y))
	all_positions.shuffle()
	for i in range(NUM_NOMINOS):
		var pos = all_positions[i]
		# Assign a random movement pattern for demonstration; replace with your logic as needed
		var move_patterns = ["orthostep", "diagstep", "orthojump", "diagjump", "clockwiseknight", "counterknight"]
		var num_types = randi() % 2 + 1  # Each Nomino gets 1 or 2 move types
		var move_types = []
		for j in range(num_types):
			var t = move_patterns[randi() % move_patterns.size()]
			if t not in move_types:
				move_types.append(t)
		# Assign a random species name
		var species_names = ["poe", "taw", "sue"]
		var species = species_names[randi() % species_names.size()]
		# Create NominoData instance and set properties
		var nomino_data = NominoData.new()
		nomino_data.pos = pos
		# Assign move_types using add() to avoid type errors
		for t in move_types:
			nomino_data.move_types.append(str(t))
		nomino_data.species = species
		nominos.append(nomino_data)
		place_nomino(nomino_data)

# Spawns a single Nomino at (5, 5) with orthostep movement
func spawn_nomino():
	var nomino_data = NominoData.new()
	nomino_data.pos = Vector2i(5, 5)
	nomino_data.move_types.append("orthostep")
	nomino_data.species = "poe"
	nominos.clear()
	nominos.append(nomino_data)
	place_nomino(nomino_data)

# Places a Nomino instance in the scene at its world position, updating its sprite and visibility.
# Handles freeing any previous node instance for this Nomino.
func place_nomino(n):
	# n is now a NominoData instance
	# Delete existing node if present and still in scene tree
	if n.node and is_instance_valid(n.node):
		n.node.queue_free()

	var world_x = n.pos.x
	var world_y = n.pos.y
	var viewboard_x = world_x - world_offset_x
	var viewboard_y = world_y - world_offset_y

	# Error logging for out-of-bounds access
	if world_x < 0 or world_x >= WORLD_WIDTH or world_y < 0 or world_y >= WORLD_HEIGHT:
		push_error("place_nomino: Nomino position out of world bounds: (" + str(world_x) + ", " + str(world_y) + ")")
		return

	# Create the Nomino sprite and add to NominoLayer
	var sprite = NOMINO_SCENE.instantiate()
	# Set species property before adding to scene
	sprite.species = n.species
	# Assign move_types from NominoData to Nomino node
	sprite.move_types.clear()
	for t in n.move_types:
		sprite.move_types.append(t)
	# Add to Nominos group for group management
	sprite.add_to_group("Nominos")

	# Connect the request_move signal to the world manager
	sprite.request_move.connect(_on_nomino_request_move.bind(n))
	# Connect the selection_changed signal to the world manager
	sprite.selection_changed.connect(notify_nomino_selection)

	var sprite2d = sprite.get_node_or_null("Sprite2D")
	if not sprite2d:
		push_error("place_nomino: Sprite2D node missing in Nomino scene.")
	elif not sprite2d.texture:
		push_error("place_nomino: Sprite2D texture missing in Nomino scene.")
	else:
		# Sprite assignment is handled by nomino.gd via species
		var tex_size = sprite2d.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			sprite2d.scale = Vector2(TILE_WIDTH / tex_size.x, TILE_WIDTH / tex_size.y)

	var screen_pos = viewboard_to_screen_coords(viewboard_x - 1, viewboard_y - 1)
	var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
	sprite.position = screen_pos + screen_offset
	if world_x >= 0 and world_x < WORLD_WIDTH and world_y >= 0 and world_y < WORLD_HEIGHT:
		sprite.position.y -= elevation_map[world_x][world_y] * 6
	else:
		push_error("place_nomino: Elevation map out-of-bounds for (" + str(world_x) + ", " + str(world_y) + ")")
	sprite.z_index = 1000 + world_y # ensure above tiles
	var nomino_layer = get_node_or_null("NominoLayer")
	if not nomino_layer:
		push_error("place_nomino: NominoLayer node missing.")
	else:
		nomino_layer.add_child(sprite)

	# Set visibility based on whether the nomino is in the viewboard
	if viewboard_x >= 0 and viewboard_x < GRID_SIZE and viewboard_y >= 0 and viewboard_y < GRID_SIZE:
		sprite.visible = true
	else:
		sprite.visible = false

	n.node = sprite
	# Set the Nomino's world_pos before starting the timer
	if sprite.has_method("set_world_pos"):
		sprite.set_world_pos(n.pos)
	else:
		sprite.world_pos = n.pos
	# Start the Nomino's timer after world_pos is set
	if sprite.has_method("start_autonomous_timer"):
		sprite.start_autonomous_timer()

# Handle move requests from Nomino nodes
func _on_nomino_request_move(new_pos: Vector2i, n):
	# Validate and apply the move for the NominoData instance n
	var world_x = new_pos.x
	var world_y = new_pos.y
	# Check world bounds
	if world_x < 0 or world_x >= WORLD_WIDTH or world_y < 0 or world_y >= WORLD_HEIGHT:
		return # Ignore out-of-bounds moves
	# Optionally, add more validation here (e.g., collision, terrain)
	n.pos = new_pos
	# Keep Nomino node's world_pos in sync for autonomous movement
	if n.node and is_instance_valid(n.node):
		if n.node.has_method("set_world_pos"):
			n.node.set_world_pos(new_pos)
		else:
			n.node.world_pos = new_pos
	update_nomino_positions()

# --- ZOOM IN/OUT: Adjust GRID_SIZE and recalculate tile sizes ---
func zoom_in():
	# Show more tiles (smaller tiles)
	if GRID_SIZE < 24:
		GRID_SIZE += 1
		TILE_WIDTH = VIEWBOARD_PIXEL_WIDTH / GRID_SIZE
		TILE_HEIGHT = TILE_WIDTH / 2
		place_tiles()
		update_viewboard_tiles()
		update_nomino_positions()

func zoom_out():
	# Show fewer tiles (larger tiles)
	if GRID_SIZE > 6:
		GRID_SIZE -= 1
		TILE_WIDTH = VIEWBOARD_PIXEL_WIDTH / GRID_SIZE
		TILE_HEIGHT = TILE_WIDTH / 2
		place_tiles()
		update_viewboard_tiles()
		update_nomino_positions()

# Call this to clear all tile highlights
func clear_tile_highlights():
	for tile in highlighted_tiles:
		var vx = tile.x
		var vy = tile.y
		if vx >= 0 and vx < GRID_SIZE and vy >= 0 and vy < GRID_SIZE:
			var sprite = tile_sprites[vx][vy]
			if sprite:
				sprite.modulate = Color(1, 1, 1, 1)
	highlighted_tiles.clear()

# Call this to highlight all target tiles for a Nomino
func highlight_nomino_targets(nomino_node):
	clear_tile_highlights()
	if not nomino_node:
		return
	# Find the NominoData for this node
	var nomino_data = null
	for n in nominos:
		if n.node == nomino_node:
			nomino_data = n
			break
	if not nomino_data:
		return
	var pos = nomino_data.pos
	for move_type in nomino_data.move_types:
		if move_type in nomino_node.NOMINO_MOVES:
			var deltas = nomino_node.NOMINO_MOVES[move_type]
			for delta in deltas:
				var target = pos + Vector2i(int(delta.x), int(delta.y))
				# Only highlight if in world bounds and in viewboard
				if target.x >= 0 and target.x < WORLD_WIDTH and target.y >= 0 and target.y < WORLD_HEIGHT:
					var vx = target.x - world_offset_x
					var vy = target.y - world_offset_y
					if vx >= 0 and vx < GRID_SIZE and vy >= 0 and vy < GRID_SIZE:
						var sprite = tile_sprites[vx][vy]
						if sprite:
							sprite.modulate = Color(2, 2, 2, 1)
						highlighted_tiles.append(Vector2i(vx, vy))

# Patch Nomino selection logic to call highlight_nomino_targets
func on_nomino_selected(nomino_node):
	selected_nomino = nomino_node
	highlight_nomino_targets(nomino_node)

func on_nomino_deselected():
	selected_nomino = null
	clear_tile_highlights()

# --- Patch Nomino selection ---
# Wrap set_selected on Nomino nodes to notify us
func notify_nomino_selection(nomino_node, selected):
	if selected:
		on_nomino_selected(nomino_node)
	else:
		on_nomino_deselected()
