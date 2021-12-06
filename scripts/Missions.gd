extends Control

@export var missions_path = "res://missions" # Missions will be loaded from this folder

var mission_list = []

func _ready():
	var dir = Directory.new()
	if dir.open(missions_path) == OK:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while not filename == "":
			if dir.current_is_dir():
				continue
#			if filename is not Mission:
#				continue
			mission_list.append(filename)
			filename = dir.get_next()
		dir.list_dir_end()
	print(mission_list)
	
	if mission_list.is_empty():
		print("No missions found")
