# viewboard_manager.gd
# Handles viewboard/camera state and coordinate conversions for the game.
extends Node

# --- Viewboard State ---
const VIEWBOARD_PIXEL_WIDTH := 768.0
const DEFAULT_GRID_SIZE = 12
const MIN_GRID_SIZE = 6
const MAX_GRID_SIZE = 24

var grid_size := DEFAULT_GRID_SIZE
var tile_width := VIEWBOARD_PIXEL_WIDTH / DEFAULT_GRID_SIZE
var tile_height := tile_width / 2

var world_offset_x := 0
var world_offset_y := 0

# --- Coordinate conversion utility import ---
const CoordinateUtils = preload("../utils/coordinate_utils.gd")

# --- Coordinate Conversion Methods ---
func viewboard_to_screen_coords(viewboard_x, viewboard_y):
	return CoordinateUtils.viewboard_to_screen_coords(viewboard_x, viewboard_y, tile_width, tile_height)

func screen_to_viewboard_coords(screen_pos):
	return CoordinateUtils.screen_to_viewboard_coords(screen_pos, tile_width, tile_height)

func viewboard_to_world_coords(viewboard_x, viewboard_y):
	return CoordinateUtils.viewboard_to_world_coords(viewboard_x, viewboard_y, world_offset_x, world_offset_y)

func world_to_viewboard_coords(world_x, world_y):
	return CoordinateUtils.world_to_viewboard_coords(world_x, world_y, world_offset_x, world_offset_y)

# --- Viewboard Movement ---
func move_viewboard(dx, dy, world_width, world_height):
	# Allow scrolling one step past the world bounds for border display
	var new_offset_x = clamp(world_offset_x + dx, -1, world_width - grid_size + 1)
	var new_offset_y = clamp(world_offset_y + dy, -1, world_height - grid_size + 1)
	if new_offset_x == world_offset_x and new_offset_y == world_offset_y:
		return false # No movement if already at edge
	world_offset_x = new_offset_x
	world_offset_y = new_offset_y
	return true

# --- Zoom ---
func zoom_in():
	if grid_size < MAX_GRID_SIZE:
		grid_size += 1
		tile_width = VIEWBOARD_PIXEL_WIDTH / grid_size
		tile_height = tile_width / 2
		return true
	return false

func zoom_out():
	if grid_size > MIN_GRID_SIZE:
		grid_size -= 1
		tile_width = VIEWBOARD_PIXEL_WIDTH / grid_size
		tile_height = tile_width / 2
		return true
	return false
