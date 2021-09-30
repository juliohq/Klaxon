extends Node

onready var pfps = ProjectSettings.get_setting("physics/common/physics_fps")
onready var pdelta = 1.0/pfps
var player_camera = null
var free_camera = null
var current_camera = null
var players = [null, null]
enum Roll {LEFT, STRAIGHT, RIGHT, GUIDED}
func roll_to_int(roll):
	return -1 if roll == Roll.LEFT else 0 if roll == Roll.STRAIGHT else 1 if roll == Roll.RIGHT else null
