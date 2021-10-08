extends Node2D

onready var G = $"/root/Globals"
# Projectiles must have the load as placeholder box checked and placed 1 per gun. 
# They can be fired any number of times, with any custom attributes! Transform is on the gun.

# TODO TEST single click burst, overflow, cancelling, does_ai_want_to_fire()
# burst: untested
# overflow: untested
# cancelling: untested
# ai: range works, angle is off
 
enum Keys {NOTHING = -1, ONE=49, TWO=50, THREE=51, FOUR=52, FIVE=53}
export(Keys) var fire_key
export(float) var clip_reload = 5
export(float) var bullets_per_second = 5
onready var shot_reload = 1/bullets_per_second
export(float) var max_ammo = -1 # -1 = infinite
export(bool) var single_click_for_full_burst = false
export(float) var ai_min_fire_range = 0
export(float) var ai_max_fire_range = 0
export(float) var ai_max_fire_angle_degrees = 0

var current_warmup = 0.0
var current_shot_reload = 0.0
var current_clip_reload = 0.0
onready var current_ammo = max_ammo
var full_burst = false

func _ready():
	assert (not (single_click_for_full_burst and max_ammo == -1))	

func _physics_process(delta):
	if(current_ammo == 0 and max_ammo != -1):
		clip_reload(delta)
	elif(current_shot_reload > 0):
		shot_reload(delta)
	elif (get_parent().is_player):
		if(single_click_for_full_burst):
			if(Input.is_key_pressed(fire_key)):
				full_burst = true
			if(full_burst):
				fire(delta)
			else:
				clip_reload(delta, true)
		elif(Input.is_key_pressed(fire_key)):
			fire(delta)
		else:
			clip_reload(delta, true)
	elif(does_ai_want_to_fire()):
			fire(delta)
	else:
			clip_reload(delta, true)

# tf_2 = Team Fortress 2 style reloading, which can be cancelled anytime
func clip_reload(delta, tf_2 = false):
	if(not tf_2):
		full_burst = false # our volley is over, wait for next click to repeat
	current_clip_reload += delta
	if(current_clip_reload >= clip_reload):
		current_clip_reload = 0
		current_ammo = max_ammo

func shot_reload(delta):
	current_clip_reload = 0
	current_shot_reload += delta
	if(current_shot_reload >= shot_reload):
		current_shot_reload = 0
		clip_reload(current_shot_reload - shot_reload)


	
func does_ai_want_to_fire():
	var enemy_player = G.players[0 if get_parent().team != 0 else 1]
	var enemy_range =  self.global_position.distance_to(enemy_player.global_position)
	var enemy_angle = rad2deg(to_local(enemy_player.global_position).angle())
	return enemy_range > ai_min_fire_range \
		and enemy_range < ai_max_fire_range \
		and enemy_angle < ai_max_fire_angle_degrees

func fire(delta):
	current_clip_reload = 0
	var kids = self.get_children()
	assert(kids.size() == 1)
	var only_child = kids[0]
	var instance = only_child.create_instance()
	instance.transform = self.global_transform
	self.remove_child(instance)
	$"/root/World".add_child(instance)
	shot_reload(delta)
