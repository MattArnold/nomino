# nomino_data.gd
# Data class for encapsulating Nomino properties and state
extends Resource
class_name NominoData

# Position in world grid
var pos: Vector2i
# List of movement pattern names
var move_types: Array[String] = []
# Species: "poe", "taw", or "sue"
var species: String = "poe"
# Loyalty: e.g., "wild", "loyal", or other
var loyalty: String = "wild"
# State: e.g., "active", "stunned", etc.
var state: String = "active"
# Reference to the Nomino node instance (optional, for scene linkage)
var node: Node2D = null

func _init(_pos := Vector2i(0,0), _move_types := [], _species := "poe", _loyalty := "wild", _state := "active"):
	pos = _pos
	# Only need to clear and append if _move_types is not empty
	for t in _move_types:
		move_types.append(str(t))
	species = _species
	loyalty = _loyalty
	state = _state
