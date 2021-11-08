extends TextureRect
@onready var G = $"/root/Globals"
var blank_positions = []
var blank_ranges = []

func _ready():
	material.set_shader_param("global_transform", get_global_transform())
	for i in range(1024):
		blank_positions.append(Vector2.ZERO)
		blank_ranges.append(0.0)

func _process(_delta):
	var x = material
	var team = G.client_vision_team
	if(team == -1):
		material.set_shader_param("discard_all", true)
		return
	var unit_positions = blank_positions
	var unit_ranges = blank_ranges
	var units = get_tree().get_nodes_in_group("Airborne")
	
	var array_length = 0
	for i in range(units.size()-1):
		if (units[array_length].team == team):
			unit_positions[i] = units[array_length].global_position
			unit_ranges[i] = units[array_length].higher_range
			array_length += 1
			assert(array_length < 1025, "More than 1024 units on a team is not supported due to a possible shader limitation")
	material.set_shader_param("discard_all", false)
	material.set_shader_param ("unit_positions", unit_positions)
	material.set_shader_param ("unit_ranges", unit_ranges)
	material.set_shader_param("array_length", array_length)
