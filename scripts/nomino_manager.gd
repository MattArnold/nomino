extends Node

# Handles all Nomino management: spawning, placement, movement, selection, highlighting, etc.

var nominos = [] # Array of NominoData instances
var selected_nomino: Node = null
var highlighted_tiles := [] # Array of (vx, vy) tuples currently highlighted
var nomino_click_handled_this_frame: bool = false

# External dependencies (must be set after instancing)
var terrain_manager = null
var viewboard_manager = null
var world_width = 64
var world_height = 64
var nomino_scene = null
var num_nominos = 99
var screen_size = Vector2(1024, 768) # Default, will be set by manager

# Called to initialize dependencies
func setup(_terrain_manager, _viewboard_manager, _nomino_scene, _world_width, _world_height, _num_nominos):
	terrain_manager = _terrain_manager
	viewboard_manager = _viewboard_manager
	nomino_scene = _nomino_scene
	world_width = _world_width
	world_height = _world_height
	num_nominos = _num_nominos

# Spawns all Nominos at unique positions and assigns them random movement patterns.
func spawn_nominos(parent_node, screen_size):
	nominos.clear()
	if parent_node.has_node("NominoLayer"):
		var old_layer = parent_node.get_node("NominoLayer")
		parent_node.remove_child(old_layer)
		old_layer.queue_free()
	var nomino_layer = Node2D.new()
	nomino_layer.name = "NominoLayer"
	parent_node.add_child(nomino_layer)

	var all_positions = []
	for x in range(world_width):
		for y in range(world_height):
			all_positions.append(Vector2i(x, y))
	all_positions.shuffle()
	for i in range(num_nominos):
		var pos = all_positions[i]
		var move_patterns = ["orthostep", "diagstep", "orthojump", "diagjump", "clockwiseknight", "counterknight"]
		var num_types = randi() % 2 + 1
		var move_types = []
		for j in range(num_types):
			var t = move_patterns[randi() % move_patterns.size()]
			if t not in move_types:
				move_types.append(t)
		var species_names = ["poe", "taw", "sue"]
		var species = species_names[randi() % species_names.size()]
		var nomino_data = NominoData.new()
		nomino_data.pos = pos
		for t in move_types:
			nomino_data.move_types.append(str(t))
		nomino_data.species = species
		nominos.append(nomino_data)
		place_nomino(nomino_data, parent_node, screen_size)

func place_nomino(n, parent_node, screen_size):
	if n.node and is_instance_valid(n.node):
		n.node.queue_free()
	var world_x = n.pos.x
	var world_y = n.pos.y
	var viewboard_x = world_x - viewboard_manager.world_offset_x
	var viewboard_y = world_y - viewboard_manager.world_offset_y
	if world_x < 0 or world_x >= world_width or world_y < 0 or world_y >= world_height:
		push_error("place_nomino: Nomino position out of world bounds: (" + str(world_x) + ", " + str(world_y) + ")")
		return
	var sprite = nomino_scene.instantiate()
	sprite.species = n.species
	sprite.move_types.clear()
	for t in n.move_types:
		sprite.move_types.append(t)
	sprite.add_to_group("Nominos")
	sprite.request_move.connect(
		func(new_pos):
			_on_nomino_request_move(new_pos, n, self.screen_size)
	)
	sprite.selection_changed.connect(notify_nomino_selection)
	var sprite2d = sprite.get_node_or_null("Sprite2D")
	if sprite2d and sprite2d.texture:
		var tex_size = sprite2d.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			sprite2d.scale = Vector2(viewboard_manager.tile_width / tex_size.x, viewboard_manager.tile_width / tex_size.y)
	var screen_pos = viewboard_manager.viewboard_to_screen_coords(viewboard_x - 1, viewboard_y - 1)
	var screen_offset = screen_size / 2 - Vector2(0, 175)
	sprite.position = screen_pos + screen_offset
	if world_x >= 0 and world_x < world_width and world_y >= 0 and world_y < world_height:
		sprite.position.y -= terrain_manager.elevation_map[world_x][world_y] * 6
	sprite.z_index = 1000 + world_y
	var nomino_layer = parent_node.get_node_or_null("NominoLayer")
	if nomino_layer:
		nomino_layer.add_child(sprite)
	sprite.visible = (viewboard_x >= 0 and viewboard_x < viewboard_manager.grid_size and viewboard_y >= 0 and viewboard_y < viewboard_manager.grid_size)
	n.node = sprite
	if sprite.has_method("set_world_pos"):
		sprite.set_world_pos(n.pos)
	else:
		sprite.world_pos = n.pos
	if sprite.has_method("start_autonomous_timer"):
		sprite.start_autonomous_timer()

func update_nomino_positions(parent_node, screen_size):
	for n in nominos:
		if not is_instance_valid(n.node):
			continue
		var world_x = n.pos.x
		var world_y = n.pos.y
		var viewboard_x = world_x - viewboard_manager.world_offset_x
		var viewboard_y = world_y - viewboard_manager.world_offset_y
		if world_x < 0 or world_x >= world_width or world_y < 0 or world_y >= world_height:
			continue
		if viewboard_x < 0 or viewboard_x >= viewboard_manager.grid_size or viewboard_y < 0 or viewboard_y >= viewboard_manager.grid_size:
			n.node.visible = false
			continue
		var screen_pos = viewboard_manager.viewboard_to_screen_coords(viewboard_x - 1, viewboard_y - 1)
		var screen_offset = screen_size / 2 - Vector2(0, 175)
		n.node.position = screen_pos + screen_offset
		if world_x >= 0 and world_x < world_width and world_y >= 0 and world_y < world_height:
			n.node.position.y -= terrain_manager.elevation_map[world_x][world_y] * 6
		n.node.z_index = 1000 + world_y
		n.node.visible = true
		var sprite2d = n.node.get_node_or_null("Sprite2D")
		if sprite2d and sprite2d.texture:
			var tex_size = sprite2d.texture.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				sprite2d.scale = Vector2(viewboard_manager.tile_width / tex_size.x, viewboard_manager.tile_width / tex_size.y)

func _on_nomino_request_move(new_pos: Vector2i, n, screen_size):
	var world_x = new_pos.x
	var world_y = new_pos.y
	if world_x < 0 or world_x >= world_width or world_y < 0 or world_y >= world_height:
		return
	n.pos = new_pos
	if n.node and is_instance_valid(n.node):
		if n.node.has_method("set_world_pos"):
			n.node.set_world_pos(new_pos)
		else:
			n.node.world_pos = new_pos
	update_nomino_positions(get_parent(), screen_size)

func clear_tile_highlights():
	for tile in highlighted_tiles:
		var vx = tile.x
		var vy = tile.y
		if vx >= 0 and vx < viewboard_manager.grid_size and vy >= 0 and vy < viewboard_manager.grid_size:
			var sprite = terrain_manager.tile_sprites[vx][vy]
			if sprite:
				sprite.modulate = Color(1, 1, 1, 1)
	highlighted_tiles.clear()

func highlight_nomino_targets(nomino_node):
	clear_tile_highlights()
	if not nomino_node:
		return
	var nomino_data = null
	for n in nominos:
		if n.node == nomino_node:
			nomino_data = n
			break
	if not nomino_data:
		return
	var pos = nomino_data.pos
	for move_type in nomino_data.move_types:
		if move_type in nomino_node.NOMINO_MOVES:
			var deltas = nomino_node.NOMINO_MOVES[move_type]
			for delta in deltas:
				var target = pos + Vector2i(int(delta.x), int(delta.y))
				if target.x >= 0 and target.x < world_width and target.y >= 0 and target.y < world_height:
					var vx = target.x - viewboard_manager.world_offset_x
					var vy = target.y - viewboard_manager.world_offset_y
					if vx >= 0 and vx < viewboard_manager.grid_size and vy >= 0 and vy < viewboard_manager.grid_size:
						var sprite = terrain_manager.tile_sprites[vx][vy]
						if sprite:
							sprite.modulate = Color(2, 2, 2, 1)
						highlighted_tiles.append(Vector2i(vx, vy))

func on_nomino_selected(nomino_node):
	selected_nomino = nomino_node
	highlight_nomino_targets(nomino_node)

func on_nomino_deselected():
	selected_nomino = null
	clear_tile_highlights()

func notify_nomino_selection(nomino_node, selected):
	if selected:
		on_nomino_selected(nomino_node)
	else:
		on_nomino_deselected()
