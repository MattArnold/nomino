extends Node2D

func _ready():
	await get_tree().process_frame

	var world_pos = Vector2(5, 5)
	var viewboard_pos = $GameWorldManager.world_to_viewboard_coords(world_pos.x, world_pos.y)
	var screen_pos = $GameWorldManager.viewboard_to_screen_coords(viewboard_pos.x, viewboard_pos.y)
	var screen_offset = get_viewport_rect().size / 2 - Vector2(0, 200)
