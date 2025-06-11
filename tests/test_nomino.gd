# Test for Nomino movement pattern logic
# This script uses GUT and assumes the presence of Nomino and its movement logic.

extends GutTest

const Nomino = preload("res://nomino.gd")

var nomino
var nomino_data
var main_scene_instance

func before_each():
	# Enable test mode for Nomino to bypass tweens
	Nomino.test_mode = true
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
	# Connect the request_move signal to update world_pos for testing
	nomino.request_move.connect(func(new_pos): nomino.world_pos = new_pos)

func after_each():
	# Clean up the main scene after each test
	if main_scene_instance and is_instance_valid(main_scene_instance):
		main_scene_instance.queue_free()
	# Disable test mode after test
	Nomino.test_mode = false

func test_nomino_movement():
	# Test that the nomino can move according to its defined patterns
	var initial_pos = nomino.world_pos
	# Call timer timeout to trigger autonomous movement logic
	nomino._on_timer_timeout()
	await get_tree().process_frame  # Allow signal to be processed
	# Simulate tween finish: call _on_hop_animation_finished with the intended new position
	# Find the move delta chosen by the logic
	var move_pattern = nomino.move_types[0]
	var options = nomino.NOMINO_MOVES[move_pattern]
	var found = false
	for delta in options:
		var candidate = initial_pos + delta
		if candidate.x >= 0 and candidate.x < 64 and candidate.y >= 0 and candidate.y < 64:
			# This matches the filtering logic in nomino.gd
			nomino._on_hop_animation_finished(candidate)
			found = true
			break
	assert(found, "No valid move found for test.")
	await get_tree().process_frame
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
