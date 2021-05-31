extends Node

onready var pfps = ProjectSettings.get_setting("physics/common/physics_fps")
onready var pdelta = 1.0/pfps
var player_camera = null
var free_camera = null
var current_camera = null
var player = null
