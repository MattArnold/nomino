# terrain_manager.gd
# Handles terrain generation, decoration, and tile sprite creation for the game world.
extends Object

class_name TerrainManager

# --- World size and terrain constants (moved from game_world_manager.gd) ---
const WORLD_WIDTH = 64
const WORLD_HEIGHT = 64
const SEA_LEVEL = -0.5

# --- Terrain/Tile Data ---
var tile_sprites = []
var terrain_map = []
var elevation_map = []

var terrain_noise := FastNoiseLite.new()
var elevation_noise := FastNoiseLite.new()

var tile_textures = {
	"grass": preload("res://assets/tiles/grass_cube.png"),
	"sand": preload("res://assets/tiles/sand_cube.png"),
	"water": preload("res://assets/tiles/water_cube.png"),
	"plants": preload("res://assets/tiles/plants_grass_cube.png"),
	"border": preload("res://assets/tiles/border_cube.png"),
}

# Generate terrain and elevation maps using a TerrainGenerator
# @param world_width: int - Width of the world in tiles
# @param world_height: int - Height of the world in tiles
# @param world_offset_x: int - X offset of the world
# @param world_offset_y: int - Y offset of the world
# @param sea_level: float - Sea level threshold for terrain
# @param terrain_noise: FastNoiseLite - Noise generator for terrain
# @param elevation_noise: FastNoiseLite - Noise generator for elevation
# @return Dictionary with keys 'terrain_map' and 'elevation_map'
static func generate_terrain_and_elevation(world_width: int, world_height: int, world_offset_x: int, world_offset_y: int, sea_level: float, terrain_noise, elevation_noise) -> Dictionary:
	return TerrainGenerator.generate_terrain_and_elevation(world_width, world_height, world_offset_x, world_offset_y, sea_level, terrain_noise, elevation_noise)

# Decorate terrain by promoting grass tiles to plant tiles if fully surrounded by grass
# @param terrain_map: Array - 2D array of terrain types
# @param grid_size: int - Size of the grid (width/height)
static func decorate_terrain(terrain_map: Array, grid_size: int) -> void:
	for x in range(grid_size):
		for y in range(grid_size):
			if terrain_map[x][y] != "grass":
				continue
			# Check cardinal neighbors
			var adjacent_types = []
			for offset in [Vector2(-1,0), Vector2(1,0), Vector2(0,-1), Vector2(0,1)]:
				var nx = x + int(offset.x)
				var ny = y + int(offset.y)
				if nx < 0 or nx >= grid_size or ny < 0 or ny >= grid_size:
					adjacent_types.append("edge")
				else:
					adjacent_types.append(terrain_map[nx][ny])
			# Promote grass to grass+plants if fully surrounded by grass
			if adjacent_types.all(func(t): return t == "grass"):
				terrain_map[x][y] = "plants"

# Create a tile sprite for a given world coordinate
# @param wx: int - World X coordinate
# @param wy: int - World Y coordinate
# @param terrain_map: Array - 2D array of terrain types
# @param elevation_map: Array - 2D array of elevation values
# @param tile_textures: Dictionary - Mapping of terrain type to Texture
# @param tile_width: float - Width of the tile in pixels
# @param screen_pos: Vector2 - Screen position for the tile
# @param screen_offset: Vector2 - Offset to apply to the screen position
# @return Sprite2D or null if texture is missing
static func create_tile_sprite(wx: int, wy: int, terrain_map: Array, elevation_map: Array, tile_textures: Dictionary, tile_width: float, screen_pos: Vector2, screen_offset: Vector2) -> Sprite2D:
	var sprite = Sprite2D.new()
	var terrain_type = terrain_map[wx][wy]
	var elevation = elevation_map[wx][wy]
	if not tile_textures.has(terrain_type):
		push_warning("Missing texture for terrain type: %s" % terrain_type)
		return null
	sprite.texture = tile_textures[terrain_type]
	sprite.z_index = sprite.position.y
	# Scale the sprites to prevent them getting gaps when zooming in
	var tex_size = sprite.texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		sprite.scale = Vector2(tile_width / tex_size.x, tile_width / tex_size.y)
	sprite.position = screen_pos + screen_offset
	sprite.position.y -= elevation * 6
	return sprite

# --- Terrain/Tile Methods ---
func setup_terrain(viewboard_manager):
	terrain_noise.seed = randi()
	terrain_noise.frequency = 1
	elevation_noise.seed = randi()
	elevation_noise.frequency = 0.1
	var result = TerrainManager.generate_terrain_and_elevation(WORLD_WIDTH, WORLD_HEIGHT, viewboard_manager.world_offset_x, viewboard_manager.world_offset_y, SEA_LEVEL, terrain_noise, elevation_noise)
	terrain_map = result["terrain_map"]
	elevation_map = result["elevation_map"]
	TerrainManager.decorate_terrain(terrain_map, viewboard_manager.grid_size)

func place_tiles(viewboard_manager, screen_offset, parent_node):
	# Clear existing tiles from scene and memory
	for row in tile_sprites:
		for sprite in row:
			if is_instance_valid(sprite):
				sprite.queue_free()
	tile_sprites.clear()
	# Create new tile sprites for current GRID_SIZE
	tile_sprites = []
	for vx in range(viewboard_manager.grid_size):
		tile_sprites.append([])
		for vy in range(viewboard_manager.grid_size):
			var wx = vx + viewboard_manager.world_offset_x
			var wy = vy + viewboard_manager.world_offset_y
			var tile_sprite
			if wx < 0 or wx >= WORLD_WIDTH or wy < 0 or wy >= WORLD_HEIGHT:
				tile_sprite = Sprite2D.new()
				tile_sprite.texture = tile_textures["border"]
				tile_sprite.z_index = 0
				var tex_size = tile_sprite.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					tile_sprite.scale = Vector2(viewboard_manager.tile_width / tex_size.x, viewboard_manager.tile_width / tex_size.y)
				var screen_pos = viewboard_manager.viewboard_to_screen_coords(vx, vy)
				tile_sprite.position = screen_pos + screen_offset
			else:
				tile_sprite = TerrainManager.create_tile_sprite(wx, wy, terrain_map, elevation_map, tile_textures, viewboard_manager.tile_width, viewboard_manager.viewboard_to_screen_coords(vx, vy), screen_offset)
			tile_sprites[vx].append(tile_sprite)
			parent_node.add_child(tile_sprite)

func update_viewboard_tiles(viewboard_manager, selected_nomino, highlighted_tiles, clear_tile_highlights, highlight_nomino_targets, screen_offset):
	for vx in range(viewboard_manager.grid_size):
		for vy in range(viewboard_manager.grid_size):
			var wx = vx + viewboard_manager.world_offset_x
			var wy = vy + viewboard_manager.world_offset_y
			var sprite = tile_sprites[vx][vy]
			if wx < 0 or wx >= WORLD_WIDTH or wy < 0 or wy >= WORLD_HEIGHT:
				sprite.texture = tile_textures["border"]
				sprite.visible = true
				var tex_size = sprite.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					sprite.scale = Vector2(viewboard_manager.tile_width / tex_size.x, viewboard_manager.tile_width / tex_size.y)
				var screen_pos = viewboard_manager.viewboard_to_screen_coords(vx, vy)
				sprite.position = screen_pos + screen_offset
			else:
				sprite.visible = true
				var terrain_type = terrain_map[wx][wy]
				var elevation = elevation_map[wx][wy]
				sprite.texture = tile_textures[terrain_type]
				var tex_size = sprite.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					sprite.scale = Vector2(viewboard_manager.tile_width / tex_size.x, viewboard_manager.tile_width / tex_size.y)
				var screen_pos = viewboard_manager.viewboard_to_screen_coords(vx, vy)
				sprite.position = screen_pos + screen_offset
				sprite.position.y -= elevation * 6
	# Call the passed-in callback to clear highlights
	if typeof(clear_tile_highlights) == TYPE_CALLABLE:
		clear_tile_highlights.call()
	# Call the passed-in callback to highlight nomino targets
	if typeof(highlight_nomino_targets) == TYPE_CALLABLE and selected_nomino:
		highlight_nomino_targets.call(selected_nomino)
