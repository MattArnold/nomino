# Test for coordinate_utils.gd utility functions (pure unit tests)
extends GutTest

const CoordinateUtils = preload("res://utils/coordinate_utils.gd")

func test_viewboard_to_screen_and_back():
	var tile_width = 64
	var tile_height = 32
	var coords = [
		Vector2(0, 0),
		Vector2(5, 5),
		Vector2(10, 3),
		Vector2(11, 11),
		Vector2(7, 2)
	]
	for v in coords:
		var screen = CoordinateUtils.viewboard_to_screen_coords(v.x, v.y, tile_width, tile_height)
		var v_back = CoordinateUtils.screen_to_viewboard_coords(screen, tile_width, tile_height)
		assert_true(abs(v.x - v_back.x) <= 1 and abs(v.y - v_back.y) <= 1, "Round-trip viewboard <-> screen failed for %s (got %s)" % [v, v_back])

func test_viewboard_to_world_and_back():
	var offsets = [Vector2(0,0), Vector2(5,5), Vector2(10,3)]
	var coords = [Vector2(0,0), Vector2(7,2), Vector2(11,11)]
	for offset in offsets:
		for v in coords:
			var world = CoordinateUtils.viewboard_to_world_coords(v.x, v.y, offset.x, offset.y)
			var v_back = CoordinateUtils.world_to_viewboard_coords(world.x, world.y, offset.x, offset.y)
			assert_true(abs(v.x - v_back.x) <= 1 and abs(v.y - v_back.y) <= 1, "Round-trip viewboard <-> world failed for %s with offset %s (got %s)" % [v, offset, v_back])
