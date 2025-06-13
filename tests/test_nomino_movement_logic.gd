# Unit tests for Nomino.get_valid_moves (pure movement logic)
extends GutTest

const Nomino = preload("res://scripts/nomino.gd")

func to_sorted(arr):
	var copy = arr.duplicate()
	copy.sort()
	return copy

func test_orthostep_center():
	var pos = Vector2i(5, 5)
	var moves = ["orthostep"]
	var world_w = 10
	var world_h = 10
	var result = Nomino.get_valid_moves(pos, moves, world_w, world_h)
	var expected = [Vector2i(5,4), Vector2i(4,5), Vector2i(6,5), Vector2i(5,6)]
	assert_eq(to_sorted(result), to_sorted(expected), "Orthostep moves from center should match expected")

func test_orthostep_edge():
	var pos = Vector2i(0, 0)
	var moves = ["orthostep"]
	var world_w = 10
	var world_h = 10
	var result = Nomino.get_valid_moves(pos, moves, world_w, world_h)
	var expected = [Vector2i(1,0), Vector2i(0,1)]
	assert_eq(to_sorted(result), to_sorted(expected), "Orthostep moves from edge should match expected")

func test_diagstep_corner():
	var pos = Vector2i(0, 0)
	var moves = ["diagstep"]
	var world_w = 10
	var world_h = 10
	var result = Nomino.get_valid_moves(pos, moves, world_w, world_h)
	var expected = [Vector2i(1,1)]
	assert_eq(result, expected, "Diagstep from corner should only allow (1,1)")

func test_multiple_move_types():
	var pos = Vector2i(1, 1)
	var moves = ["orthostep", "diagstep"]
	var world_w = 3
	var world_h = 3
	var result = Nomino.get_valid_moves(pos, moves, world_w, world_h)
	var expected = [Vector2i(1,0), Vector2i(0,1), Vector2i(2,1), Vector2i(1,2), Vector2i(0,0), Vector2i(2,0), Vector2i(0,2), Vector2i(2,2)]
	assert_eq(to_sorted(result), to_sorted(expected), "All valid moves for center with both move types")

func test_out_of_bounds():
	var pos = Vector2i(0, 9)
	var moves = ["orthostep"]
	var world_w = 10
	var world_h = 10
	var result = Nomino.get_valid_moves(pos, moves, world_w, world_h)
	var expected = [Vector2i(1,9), Vector2i(0,8)]
	assert_eq(to_sorted(result), to_sorted(expected), "Orthostep at (0,9) should not go out of bounds")
