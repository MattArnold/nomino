extends Node2D
# --- Remove terrain/tile logic and variables, use TerrainManager instead ---
# (All terrain/tile variables and methods have been moved to terrain_manager.gd)
# Add TerrainManager instance
var terrain_manager := preload("res://scripts/terrain_manager.gd").new()

# --- Viewboard/Camera State ---
const ViewboardManager = preload("res://scripts/viewboard_manager.gd")
var viewboard_manager := ViewboardManager.new()

# --- NominoManager ---
var NominoManager = load("res://scripts/nomino_manager.gd")
var nomino_manager = NominoManager.new()

const NOMINO_SCENE = preload("res://nomino.tscn")
const WORLD_WIDTH = 64
const WORLD_HEIGHT = 64
const NUM_NOMINOS = 99 # Number of Nominos to spawn
const DEFAULT_GRID_SIZE = 12 # Default number of tiles along each edge of the viewboard

var tile_textures = {
	"grass": preload("res://assets/tiles/grass_cube.png"),
	"sand": preload("res://assets/tiles/sand_cube.png"),
	"water": preload("res://assets/tiles/water_cube.png"),
	"plants": preload("res://assets/tiles/plants_grass_cube.png"),
	"border": preload("res://assets/tiles/border_cube.png"), # Added border texture
}

func _ready():
	randomize()
	var screen_size = get_viewport().get_visible_rect().size
	nomino_manager.screen_size = screen_size
	# Add a dedicated NominoLayer for nomino sprites (NominoManager will handle this)
	# --- Use TerrainManager for terrain setup and tile placement ---
	terrain_manager.setup_terrain(viewboard_manager)
	terrain_manager.place_tiles(viewboard_manager, screen_size / 2 - Vector2(0, 175), self)
	# Setup NominoManager dependencies
	nomino_manager.setup(terrain_manager, viewboard_manager, NOMINO_SCENE, WORLD_WIDTH, WORLD_HEIGHT, NUM_NOMINOS)
	nomino_manager.spawn_nominos(self, screen_size)

func update_viewboard_tiles():
	var screen_size = get_viewport().get_visible_rect().size
	nomino_manager.screen_size = screen_size
	var screen_offset = screen_size / 2 - Vector2(0, 175)
	terrain_manager.update_viewboard_tiles(viewboard_manager, nomino_manager.selected_nomino, nomino_manager.highlighted_tiles, nomino_manager.clear_tile_highlights, nomino_manager.highlight_nomino_targets, screen_offset)

func update_nomino_positions():
	var screen_size = get_viewport().get_visible_rect().size
	nomino_manager.screen_size = screen_size
	nomino_manager.update_nomino_positions(self, screen_size)

func move_viewboard(dx, dy):
	if viewboard_manager.move_viewboard(dx, dy, WORLD_WIDTH, WORLD_HEIGHT):
		update_viewboard_tiles()
		update_nomino_positions()
		# Notify controls to update button states
		var controls = get_tree().get_root().find_child("ViewboardControls", true, false)
		if controls and controls.has_method("update_scroll_buttons"):
			controls.update_scroll_buttons()

# --- ZOOM IN/OUT: Adjust GRID_SIZE and recalculate tile sizes ---
func zoom_in():
	if viewboard_manager.zoom_in():
		var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
		terrain_manager.place_tiles(viewboard_manager, screen_offset, self)
		update_viewboard_tiles()
		update_nomino_positions()

func zoom_out():
	if viewboard_manager.zoom_out():
		var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 175)
		terrain_manager.place_tiles(viewboard_manager, screen_offset, self)
		update_viewboard_tiles()
		update_nomino_positions()

# --- Coordinate conversion passthroughs for scene scripts ---
func world_to_viewboard_coords(world_x, world_y):
	return viewboard_manager.world_to_viewboard_coords(world_x, world_y)

func viewboard_to_screen_coords(viewboard_x, viewboard_y):
	return viewboard_manager.viewboard_to_screen_coords(viewboard_x, viewboard_y)
