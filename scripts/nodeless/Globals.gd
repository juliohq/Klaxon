extends Node

onready var pfps = ProjectSettings.get_setting("physics/common/physics_fps")
onready var pdelta = 1.0/pfps
var player_camera = null
var free_camera = null
var current_camera = null
var players = [null, null]
enum Roll {LEFT, STRAIGHT, RIGHT, GUIDED}
func roll_to_int(roll):
	assert(roll in [Roll.LEFT, Roll.STRAIGHT, Roll.RIGHT])
	return -1 if roll == Roll.LEFT \
	else 0 if roll == Roll.STRAIGHT \
	else 1 # if roll == Roll.RIGHT

var client_vision_team = -1 
# -1 means show everything, positive numbers mean show only what that team's units see
var visible_airbornes = []
func get_visible_airbornes(team = client_vision_team):

	var airbornes =  get_tree().get_nodes_in_group("Airborne")
	if client_vision_team == -1: 
		return airbornes
	var ret = []
	for ally in airbornes:
		if(ally.team == team):
			if(not (ally in ret)):
				ret.append(ally)
			for enemy in airbornes:
				if(enemy.team != team and not (enemy in ret)):
					var visible = enemy.global_position.distance_to(ally.global_position) #TODO
					if(visible):
						ret.append(enemy)
	return ret

func _ready():
	 process_priority = -100

func _physics_process(delta):
	visible_airbornes = get_visible_airbornes()
