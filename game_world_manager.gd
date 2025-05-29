extends Node2D
const NOMINO_SCENE = preload("res://nomino.tscn")

const WORLD_WIDTH = 64
const WORLD_HEIGHT = 64

# Grid configuration
const SEA_LEVEL = -0.5
const VIEWBOARD_PIXEL_WIDTH := 768.0
var GRID_SIZE = 12  # Number of tiles along each edge of the viewboard
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

var nominos = []  # stores { node: Nomino, pos: Vector2i }

var tile_textures = {
	"grass": preload("res://assets/tiles/grass_cube.png"),
	"sand": preload("res://assets/tiles/sand_cube.png"),
	"water": preload("res://assets/tiles/water_cube.png"),
	"plants": preload("res://assets/tiles/plants_grass_cube.png"),
	"border": preload("res://assets/tiles/border_cube.png"), # Added border texture
}

func _ready():
	randomize()
	# Add a dedicated NominoLayer for nomino sprites
	if not has_node("NominoLayer"):
		var nomino_layer = Node2D.new()
		nomino_layer.name = "NominoLayer"
		add_child(nomino_layer)
	# The desired noise type is Open Simplex 2, which is 0
	terrain_noise.noise_type = 0
	terrain_noise.seed = randi()
	terrain_noise.frequency = 1  # controls patch size

	# The desired noise type is Open Simplex 2, which is 0
	elevation_noise.noise_type = 0
	elevation_noise.seed = randi()
	elevation_noise.frequency = 0.1
	distribute_terrain()
	decorate_terrain()
	place_tiles()
	spawn_nominos()

func distribute_terrain():
	terrain_map = []
	tile_sprites = []
	var _tiles_created = 0
	elevation_map = []

	for x in range(WORLD_WIDTH):
		tile_sprites.append([])
		terrain_map.append([])
		elevation_map.append([])
		for y in range(WORLD_HEIGHT):
			var world_x = x + world_offset_x
			var world_y = y + world_offset_y

			# Terrain type noise
			var t_raw = terrain_noise.get_noise_2d(world_x * 0.1, world_y * 0.1)
			var t = (t_raw + 1.0) / 2.0
			var terrain = "sand" if t > 0.5 else "grass"

			# Elevation noise
			var e = elevation_noise.get_noise_2d(world_x + 1000, world_y + 1000)
			var elevation = int(round(e * 3))

			if elevation < SEA_LEVEL:
				terrain = "water"
				elevation = SEA_LEVEL

			terrain_map[x].append(terrain)
			elevation_map[x].append(elevation)

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

func viewboard_to_screen_coords(viewboard_x, viewboard_y):
	# Convert viewboard grid coordinates to screen pixel coordinates
	# This creates the isometric diamond pattern
	var screen_x = (viewboard_x - viewboard_y) * (TILE_WIDTH / 2)
	var screen_y = (viewboard_x + viewboard_y) * (TILE_HEIGHT / 2)
	return Vector2(screen_x, screen_y)

func screen_to_viewboard_coords(screen_pos):
	# Convert screen pixel coordinates back to viewboard grid coordinates
	# This reverses the isometric transformation
	var temp_x = screen_pos.x / (TILE_WIDTH / 2) + screen_pos.y / (TILE_HEIGHT / 2)
	var temp_y = screen_pos.y / (TILE_HEIGHT / 2) - screen_pos.x / (TILE_WIDTH / 2)

	# Round to nearest integer coordinates
	var viewboard_x = int(round(temp_x / 2))
	var viewboard_y = int(round(temp_y / 2))

	return Vector2(viewboard_x, viewboard_y)

func viewboard_to_world_coords(viewboard_x, viewboard_y):
	return Vector2(viewboard_x + world_offset_x, viewboard_y + world_offset_y)

func world_to_viewboard_coords(world_x, world_y):
	return Vector2(world_x - world_offset_x, world_y - world_offset_y)

func _input(event):
	# Handle mouse clicks on the grid
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = to_local(event.position)
		var viewboard_coords = screen_to_viewboard_coords(local_pos)

		# Check if the click is within our grid bounds
		if viewboard_coords.x >= 0 and viewboard_coords.x < GRID_SIZE and viewboard_coords.y >= 0 and viewboard_coords.y < GRID_SIZE:
			var world_coords = viewboard_to_world_coords(viewboard_coords.x, viewboard_coords.y)
			print("Clicked on viewboard (", viewboard_coords.x, ", ", viewboard_coords.y, ") = world (", world_coords.x, ", ", world_coords.y, ")") 

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

func update_nomino_positions():
	for n in nominos:
		if not is_instance_valid(n["node"]):
			continue  # node has been freed or not created yet

		var world_x = n.pos.x
		var world_y = n.pos.y
		var viewboard_x = world_x - world_offset_x
		var viewboard_y = world_y - world_offset_y

		# Check if Nomino is in view
		if viewboard_x < 0 or viewboard_x >= GRID_SIZE or viewboard_y < 0 or viewboard_y >= GRID_SIZE:
			n["node"].visible = false
			continue

		var screen_pos = viewboard_to_screen_coords(viewboard_x - 1, viewboard_y - 1)
		var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
		n["node"].position = screen_pos + screen_offset
		n["node"].position.y -= elevation_map[world_x][world_y] * 6
		n["node"].z_index = 1000 + world_y
		n["node"].visible = true

		# --- Ensure nomino sprite scales with zoom ---
		var sprite2d = n["node"].get_node_or_null("Sprite2D")
		if sprite2d and sprite2d.texture:
			var tex_size = sprite2d.texture.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				sprite2d.scale = Vector2(TILE_WIDTH / tex_size.x, TILE_WIDTH / tex_size.y)

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
	for i in range(24):
		var pos = all_positions[i]
		var n = { "pos": pos, "node": null }
		nominos.append(n)
		place_nomino(n)

func place_nomino(n: Dictionary) -> void:
	# Delete existing node if present and still in scene tree
	if n.has("node") and n["node"] and is_instance_valid(n["node"]):
		n["node"].queue_free()

	var world_x = n.pos.x
	var world_y = n.pos.y
	var viewboard_x = world_x - world_offset_x
	var viewboard_y = world_y - world_offset_y

	# Create the Nomino sprite and add to NominoLayer
	var sprite = preload("res://nomino.tscn").instantiate()

	var sprite2d = sprite.get_node_or_null("Sprite2D")
	if sprite2d and sprite2d.texture:
		sprite2d.scale = Vector2.ONE
		var tex_size = sprite2d.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			sprite2d.scale = Vector2(TILE_WIDTH / tex_size.x, TILE_WIDTH / tex_size.y)

	var screen_pos = viewboard_to_screen_coords(viewboard_x - 1, viewboard_y - 1)
	var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
	sprite.position = screen_pos + screen_offset
	sprite.position.y -= elevation_map[world_x][world_y] * 6
	sprite.z_index = 1000 + world_y # ensure above tiles
	get_node("NominoLayer").add_child(sprite)

	# Set visibility based on whether the nomino is in the viewboard
	if viewboard_x >= 0 and viewboard_x < GRID_SIZE and viewboard_y >= 0 and viewboard_y < GRID_SIZE:
		sprite.visible = true
	else:
		sprite.visible = false

	n["node"] = sprite

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
