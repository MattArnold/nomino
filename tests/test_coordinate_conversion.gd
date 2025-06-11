# Test for coordinate conversion between world, viewport, and screen coordinates (isometric)
# This script should be run in Godot's test environment or as a tool script.
# It assumes the presence of the GameWorldManager node and its coordinate conversion methods.

extends GutTest

var game_world_manager

func _ready():
	# Find the GameWorldManager node
	game_world_manager = get_node_or_null("/root/GameWorld/GameWorldManager")
	if not game_world_manager:
		push_error("GameWorldManager node not found. Test aborted.")
		return

	# Test a set of world coordinates
	var test_coords = [
		Vector2(0, 0),
		Vector2(5, 5),
		Vector2(10, 3),
		Vector2(63, 63),
		Vector2(12, 7)
	]

	for world_pos in test_coords:
		var viewboard_pos = game_world_manager.world_to_viewboard_coords(world_pos.x, world_pos.y)
		var screen_pos = game_world_manager.viewboard_to_screen_coords(viewboard_pos.x, viewboard_pos.y)
		var viewboard_back = game_world_manager.screen_to_viewboard_coords(screen_pos)
		var world_back = game_world_manager.viewboard_to_world_coords(viewboard_back.x, viewboard_back.y)

		# Check that round-trip conversion is accurate (allowing for rounding)
		assert(abs(world_pos.x - world_back.x) <= 1 and abs(world_pos.y - world_back.y) <= 1, "Coordinate round-trip failed for "+str(world_pos))
