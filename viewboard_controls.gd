extends Control

@onready var game_world_manager = get_node("../../GameWorld/GameWorldManager")

var current_viewboard_input := Vector2.ZERO
var input_hold_timer := 0.0
var input_repeat_timer := 0.0
var previous_input := Vector2.ZERO
const INPUT_REPEAT_DELAY := 0.3
const INPUT_REPEAT_RATE := 0.1

func _ready():
	create_viewboard_controls_container()
	connect_buttons()
	responsive_hud_scale()
	update_scroll_buttons()

func create_viewboard_controls_container():
	var container = Control.new()
	container.custom_minimum_size = Vector2(200, 48)
	container.name = "ViewboardControlsContainer"
	container.anchor_top = 0.02
	container.anchor_left = 0.63
	add_child(container)

	create_scroll_pad(container)
	create_zoom_pad(container)

# Buttons that scroll the view of the world north/south/east/west
func create_scroll_pad(container: Control):
	# Scaling is handled responsively in responsive_hud_scale()
	var pad = Control.new()
	pad.name = "ScrollPad"
	pad.anchor_left = 0.9
	pad.offset_top = 0
	container.add_child(pad)

	# NESW scroll directional pad background image
	var bg = TextureRect.new()
	bg.name = "ButtonsImage"
	bg.texture = preload("res://assets/viewboard-buttons-image.png")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = 1
	pad.add_child(bg)

	# Directional buttons
	# Top-left: West
	var btn_w = Button.new()
	btn_w.name = "ButtonWest"
	btn_w.custom_minimum_size = Vector2(48, 48)
	btn_w.offset_left = 0
	btn_w.offset_top = 0
	btn_w.z_index = 0
	pad.add_child(btn_w)

	# Top-right: North
	var btn_n = Button.new()
	btn_n.name = "ButtonNorth"
	btn_n.custom_minimum_size = Vector2(48, 48)
	btn_n.offset_left = 50
	btn_n.offset_top = 0
	btn_n.z_index = 0
	pad.add_child(btn_n)

	# Bottom-left: South
	var btn_s = Button.new()
	btn_s.name = "ButtonSouth"
	btn_s.custom_minimum_size = Vector2(48, 48)
	btn_s.offset_left = 0
	btn_s.offset_top = 50
	btn_s.z_index = 0
	pad.add_child(btn_s)

	# Bottom-right: East
	var btn_e = Button.new()
	btn_e.name = "ButtonEast"
	btn_e.custom_minimum_size = Vector2(48, 48)
	btn_e.offset_left = 50
	btn_e.offset_top = 50
	btn_e.z_index = 0
	pad.add_child(btn_e)

# Buttons that zoom in and out on the view of the world
func create_zoom_pad(container: Control):
	# Scaling is handled responsively in responsive_hud_scale()
	var pad = Control.new()
	pad.name = "ZoomPad"
	pad.anchor_left = 0.64
	container.add_child(pad)

	# background image of Zoom pad
	var bg = TextureRect.new()
	bg.name = "ButtonsImage"
	bg.texture = preload("res://assets/zoom-buttons-image.png")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = 1
	bg.offset_left = 5
	bg.offset_top = 9
	pad.add_child(bg)

	# Zoom buttons
	var btn_zoom_in = Button.new()
	btn_zoom_in.name = "ButtonZoomIn"
	btn_zoom_in.custom_minimum_size = Vector2(48, 48)
	pad.add_child(btn_zoom_in)

	var btn_zoom_out = Button.new()
	btn_zoom_out.name = "ButtonZoomOut"
	btn_zoom_out.custom_minimum_size = Vector2(48, 48)
	btn_zoom_out.offset_top = 50
	pad.add_child(btn_zoom_out)

func connect_buttons():
	var scroll_pad = get_node("ViewboardControlsContainer/ScrollPad")

	scroll_pad.get_node("ButtonNorth").button_down.connect(func():
		current_viewboard_input = Vector2(0, -1)
		update_scroll_buttons()
	)
	scroll_pad.get_node("ButtonNorth").button_up.connect(func(): current_viewboard_input = Vector2.ZERO)

	scroll_pad.get_node("ButtonSouth").button_down.connect(func():
		current_viewboard_input = Vector2(0, 1)
		update_scroll_buttons()
	)
	scroll_pad.get_node("ButtonSouth").button_up.connect(func(): current_viewboard_input = Vector2.ZERO)

	scroll_pad.get_node("ButtonWest").button_down.connect(func():
		current_viewboard_input = Vector2(-1, 0)
		update_scroll_buttons()
	)
	scroll_pad.get_node("ButtonWest").button_up.connect(func(): current_viewboard_input = Vector2.ZERO)

	scroll_pad.get_node("ButtonEast").button_down.connect(func():
		current_viewboard_input = Vector2(1, 0)
		update_scroll_buttons()
	)
	scroll_pad.get_node("ButtonEast").button_up.connect(func(): current_viewboard_input = Vector2.ZERO)

	var zoom_pad = get_node("ViewboardControlsContainer/ZoomPad")

	zoom_pad.get_node("ButtonZoomIn").pressed.connect(func(): game_world_manager.zoom_in())
	zoom_pad.get_node("ButtonZoomOut").pressed.connect(func(): game_world_manager.zoom_out())

	var zoom_in_event = InputEventKey.new()
	zoom_in_event.keycode = KEY_Q
	InputMap.action_add_event("zoom_in", zoom_in_event)

	var zoom_out_event = InputEventKey.new()
	zoom_out_event.keycode = KEY_E
	InputMap.action_add_event("zoom_out", zoom_out_event)

func responsive_hud_scale():
	var screen_size = get_viewport_rect().size
	var scale_factor = screen_size.x / 768.0
	scale_factor = clamp(scale_factor, 0.5, 1.5)

	var container = get_node_or_null("ViewboardControlsContainer")
	var scroll_pad = get_node_or_null("ViewboardControlsContainer/ScrollPad")
	var zoom_pad = get_node_or_null("ViewboardControlsContainer/ZoomPad")

	if container:
		container.scale = Vector2(scale_factor, scale_factor)

	if scroll_pad:
		scroll_pad.scale = Vector2(scale_factor, scale_factor)

	if zoom_pad:
		zoom_pad.scale = Vector2(scale_factor, scale_factor)

func update_scroll_buttons():
	var scroll_pad = get_node_or_null("ViewboardControlsContainer/ScrollPad")
	if not scroll_pad or not game_world_manager:
		return

	# Check if scrolling in each direction is possible
	var viewboard = game_world_manager.viewboard_manager
	var can_north = viewboard.world_offset_y > 0
	var can_south = viewboard.world_offset_y < game_world_manager.WORLD_HEIGHT - viewboard.grid_size
	var can_west = viewboard.world_offset_x > 0
	var can_east = viewboard.world_offset_x < game_world_manager.WORLD_WIDTH - viewboard.grid_size

	scroll_pad.get_node("ButtonNorth").disabled = not can_north
	scroll_pad.get_node("ButtonSouth").disabled = not can_south
	scroll_pad.get_node("ButtonWest").disabled = not can_west
	scroll_pad.get_node("ButtonEast").disabled = not can_east

func _input(event):
	if event.is_action_pressed("zoom_in"):
		game_world_manager.zoom_in()
	elif event.is_action_pressed("zoom_out"):
		game_world_manager.zoom_out()
	# Update scroll buttons on any input
	update_scroll_buttons()

func _process(delta):
	var input = Vector2.ZERO

	# WASD or Arrow Keys
	if Input.is_action_pressed("view_north"):
		input.y -= 1
	if Input.is_action_pressed("view_south"):
		input.y += 1
	if Input.is_action_pressed("view_west"):
		input.x -= 1
	if Input.is_action_pressed("view_east"):
		input.x += 1

	# HUD pad input from scroll pad
	if input == Vector2.ZERO:
		input = current_viewboard_input

	# Input repeat/delay logic is managed here (UI/UX responsibility)
	if input != Vector2.ZERO:
		if input != previous_input:
			game_world_manager.move_viewboard(input.x, input.y)
			input_repeat_timer = INPUT_REPEAT_DELAY
		else:
			input_repeat_timer -= delta
			if input_repeat_timer <= 0.0:
				game_world_manager.move_viewboard(input.x, input.y)
				input_repeat_timer = INPUT_REPEAT_RATE
	else:
		input_repeat_timer = 0.0

	previous_input = input
