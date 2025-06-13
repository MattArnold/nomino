# Test for viewboard scrolling logic and offset management
# This script uses GUT and assumes the presence of GameWorldManager and its scrolling methods.

extends GutTest

var main_scene_instance
var game_world_manager

func before_each():
	# Load and add the main scene to ensure GameWorldManager exists
	var main_scene = load("res://main.tscn")
	main_scene_instance = main_scene.instantiate()
	get_tree().get_root().add_child(main_scene_instance)
	await get_tree().process_frame  # Let the scene initialize

	# Find the GameWorldManager node
	game_world_manager = get_tree().get_root().find_child("GameWorldManager", true, false)
	assert_not_null(game_world_manager, "GameWorldManager node not found. Test aborted.")

func after_each():
	if main_scene_instance and is_instance_valid(main_scene_instance):
		main_scene_instance.queue_free()

func test_scroll_north_increases_offset_y():
	var initial_offset_y = game_world_manager.viewboard_manager.world_offset_y
	game_world_manager.move_viewboard(0, -1)
	assert_eq(game_world_manager.viewboard_manager.world_offset_y, initial_offset_y - 1, "Scrolling north should decrease offset_y by 1.")

func test_scroll_south_decreases_offset_y():
	var initial_offset_y = game_world_manager.viewboard_manager.world_offset_y
	game_world_manager.move_viewboard(0, 1)
	assert_eq(game_world_manager.viewboard_manager.world_offset_y, initial_offset_y + 1, "Scrolling south should increase offset_y by 1.")

func test_scroll_east_increases_offset_x():
	var initial_offset_x = game_world_manager.viewboard_manager.world_offset_x
	game_world_manager.move_viewboard(1, 0)
	assert_eq(game_world_manager.viewboard_manager.world_offset_x, initial_offset_x + 1, "Scrolling east should increase offset_x by 1.")

func test_scroll_west_decreases_offset_x():
	var initial_offset_x = game_world_manager.viewboard_manager.world_offset_x
	game_world_manager.move_viewboard(-1, 0)
	assert_eq(game_world_manager.viewboard_manager.world_offset_x, initial_offset_x - 1, "Scrolling west should decrease offset_x by 1.")

func test_scroll_limits_at_world_bounds():
	# Try to scroll far beyond the world bounds
	game_world_manager.viewboard_manager.world_offset_x = -1
	game_world_manager.viewboard_manager.world_offset_y = -1
	game_world_manager.move_viewboard(-10, -10)
	assert(game_world_manager.viewboard_manager.world_offset_x >= -1, "Offset x should not go below -1.")
	assert(game_world_manager.viewboard_manager.world_offset_y >= -1, "Offset y should not go below -1.")

	game_world_manager.viewboard_manager.world_offset_x = game_world_manager.WORLD_WIDTH - game_world_manager.viewboard_manager.grid_size + 1
	game_world_manager.viewboard_manager.world_offset_y = game_world_manager.WORLD_HEIGHT - game_world_manager.viewboard_manager.grid_size + 1
	game_world_manager.move_viewboard(10, 10)
	assert(game_world_manager.viewboard_manager.world_offset_x <= game_world_manager.WORLD_WIDTH - game_world_manager.viewboard_manager.grid_size + 1, "Offset x should not exceed max bound.")
	assert(game_world_manager.viewboard_manager.world_offset_y <= game_world_manager.WORLD_HEIGHT - game_world_manager.viewboard_manager.grid_size + 1, "Offset y should not exceed max bound.")
