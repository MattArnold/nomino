# Test for Nomino movement pattern logic
# This script uses GUT and assumes the presence of Nomino and its movement logic.

extends GutTest

var nomino
var nomino_data
var main_scene_instance

func before_each():
	# Load and add the main scene to ensure GameWorldManager exists
	var main_scene = load("res://main.tscn")
	main_scene_instance = main_scene.instantiate()
	get_tree().get_root().add_child(main_scene_instance)
	await get_tree().process_frame  # Let the scene initialize

	# Create a NominoData instance for testing
	nomino_data = load("res://nomino_data.gd").new()
	nomino_data.pos = Vector2i(5, 5)
	nomino_data.move_types.clear()
	nomino_data.move_types.append("orthostep")
	nomino_data.species = "poe"
	# Use the same placement logic as the game
	var gwm = get_tree().get_root().find_child("GameWorldManager", true, false)
	assert_not_null(gwm, "GameWorldManager node not found. Test aborted.")
	gwm.place_nomino(nomino_data)
	nomino = nomino_data.node

func after_each():
	# Clean up the main scene after each test
	if main_scene_instance and is_instance_valid(main_scene_instance):
		main_scene_instance.queue_free()

func test_nomino_movement():
	# Test that the nomino can move according to its defined patterns
	var initial_pos = nomino.world_pos
	nomino._on_timer_timeout()  # Trigger autonomous movement logic

	# Check if the position has changed according to orthostep rules
	var expected_moves = [
		Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)
	]
	var moved = false
	for move in expected_moves:
		if nomino.world_pos == initial_pos + move:
			moved = true
			break

	assert(moved, "Nomino did not move according to orthostep rules.")

func test_nomino_selection():
	# Test that selecting a nomino updates its state and notifies the GameWorldManager
	var gwm = get_tree().get_root().find_child("GameWorldManager", true, false)
	assert_not_null(gwm, "GameWorldManager node not found. Test aborted.")

	# Select the nomino
	nomino.set_selected(true)
	assert(nomino.is_selected, "Nomino should be selected.")

	# Deselect the nomino
	nomino.set_selected(false)
	assert(!nomino.is_selected, "Nomino should no longer be selected.")
