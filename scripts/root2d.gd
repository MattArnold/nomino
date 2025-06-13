extends Node2D

func _ready():
	var scale_factor = 0.9
	self.scale = Vector2(scale_factor, scale_factor)

	var window_size = Vector2(DisplayServer.window_get_size())
	var scaled_size = window_size * scale_factor
	var offset = (window_size - scaled_size) / 2.0

	self.position = offset
