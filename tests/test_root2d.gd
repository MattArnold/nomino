# Test that Root2D scales and centers itself on window resize
extends GutTest

var main_scene_instance
var root2d

func before_each():
	# Load and add the main scene to ensure Root2D exists
	var main_scene = load("res://scenes/main.tscn")
	main_scene_instance = main_scene.instantiate()
	get_tree().get_root().add_child(main_scene_instance)
	await get_tree().process_frame  # Let the scene initialize

	# main_scene_instance is the Root2D node
	root2d = main_scene_instance
	assert_not_null(root2d, "Root2D node not found. Test aborted.")
	if root2d == null:
		return

func after_each():
	if main_scene_instance and is_instance_valid(main_scene_instance):
		main_scene_instance.queue_free()

func test_root2d_scales_and_centers():
	# The scale and position should match the logic in root2d.gd
	var scale_factor = 0.9
	var window_size = Vector2(DisplayServer.window_get_size())
	var scaled_size = window_size * scale_factor
	var expected_offset = (window_size - scaled_size) / 2.0

	assert_almost_eq(root2d.scale.x, scale_factor, 0.01, "Root2D scale.x should be set correctly.")
	assert_almost_eq(root2d.scale.y, scale_factor, 0.01, "Root2D scale.y should be set correctly.")
	assert_almost_eq(root2d.position.x, expected_offset.x, 0.01, "Root2D position.x should be centered after scaling.")
	assert_almost_eq(root2d.position.y, expected_offset.y, 0.01, "Root2D position.y should be centered after scaling.")
