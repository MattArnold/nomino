# Utility and coordinate conversion functions for Nomino
# Place in res://utils/coordinate_utils.gd
extends Node

# Remove class_name, use as a plain script for static utility

static func viewboard_to_screen_coords(viewboard_x, viewboard_y, tile_width, tile_height):
	# Convert viewboard grid coordinates to screen pixel coordinates (isometric diamond)
	var screen_x = (viewboard_x - viewboard_y) * (tile_width / 2)
	var screen_y = (viewboard_x + viewboard_y) * (tile_height / 2)
	return Vector2(screen_x, screen_y)

static func screen_to_viewboard_coords(screen_pos, tile_width, tile_height):
	# Convert screen pixel coordinates back to viewboard grid coordinates
	var temp_x = screen_pos.x / (tile_width / 2) + screen_pos.y / (tile_height / 2)
	var temp_y = screen_pos.y / (tile_height / 2) - screen_pos.x / (tile_width / 2)
	var viewboard_x = int(round(temp_x / 2))
	var viewboard_y = int(round(temp_y / 2))
	return Vector2(viewboard_x, viewboard_y)

static func viewboard_to_world_coords(viewboard_x, viewboard_y, world_offset_x, world_offset_y):
	return Vector2(viewboard_x + world_offset_x, viewboard_y + world_offset_y)

static func world_to_viewboard_coords(world_x, world_y, world_offset_x, world_offset_y):
	return Vector2(world_x - world_offset_x, world_y - world_offset_y)
