extends KinematicBody2D

# in thise node specifically set on _enter_tree(), which is before _ready() and before all nodes are in the tree
# this way it can be used onready
var G 
const PCE = preload("nodeless/PowerCurveEntry.gd")

export var team = 0

enum Controller {PLAYER, DUMB, PURSUE_NEAREST = 1001, PURSUE_PLAYER = 1002}
export(Controller) var controller = 1
var is_player # set on _enter_tree(), which is before _ready() and before all nodes are in the tree
func set_controller(x):
	controller = x
	is_player = controller == Controller.PLAYER
	if(x == Controller.PLAYER):
		assert(G.players[team] == null or G.players[team] == self, G.players[team])
		G.players[team] = self


# may be position node or vector, use get_target_pos() to access position/node as position
# set on _ready()
var _target = null

func is_pursuit():
	return controller / 1000 == 1
	

enum CollisionTags {AIR = 11, GROUND = 12}
export(Array, CollisionTags) var collision_tags = [] setget set_collision_tags
func set_collision_tags(x):
	for tag in CollisionTags.values():
		set_collision_layer_bit(tag, tag in x)
	collision_tags = x
export(Array, CollisionTags) var target_collision_tags = [] setget set_target_collision_tags
func set_target_collision_tags(x):
	for tag in CollisionTags.values():
		$ExplosionArea.set_collision_mask_bit(tag, tag in x)
	target_collision_tags = x

export var collision_line_color = Color.red
export var collision_line_width = 1.0
export var _collision_poly_color = Color(1, 0, 0, 0.25)
var collision_poly_color = PoolColorArray([_collision_poly_color])
export var trail_length = 0
export var  trail_width = 0
export var trail_color = Color.gray
export var orbit_size =  0
export var orbit_color = Color.gray
onready var collision_draw_points = $CollisionPolygon2D.polygon
export var draw_collision = true
export var draw_explosion_prediction = false
export var explosion_prediction_ring_color = Color.blue
export var explosion_prediction_circle_color = Color(0, 0, 1, 0.25)
export var explosion_prediction_ring_width = 1.0

export var acceleration = 100
export var deceleration = 100
export var effective_range = -1

export var health = -1
export var explosion_radius = 0 setget set_explosion_radius
func set_explosion_radius(x : int):
	$ExplosionArea/Collision.shape.radius = x
	explosion_radius = x
export var auto_detonate = false

var dying = false



# purely for export/init, built into the below variable then never used
# [speed, turntime]
export(Array, Array, float, -1.0, 1000000, 0.1) var _power_curve = [
	[0, -1],
	[250, 4],
	[500, 3],
	[1000, 0.1]
]
# array of PCEs constructed from the above
var power_curve = []
var pce : PCE # current speed and turn data
export var speed = 0 setget set_speed

onready var remaining_range : float = effective_range
var course_altered = false


onready var roll = G.Roll.STRAIGHT
var trail = []

export var max_range_detect_time = 10 # scales linearly to 0 at half range
export var radar_range = 0.0
export var visual_range = 0.0
export var enemy_radar_flat_reduction = 0.0
export var enemy_visual_percent_reduction = 0.0
var tracked_enemies = []
var tracking_enemies = [] # enemies that are tracking us
export var is_decoy = false # always visible, and instantly destroyed when detected

# export var r_rate_no_interference = -1.0
# var _power_curve_no_interference # is this possible? since pces scale linearly by r_rate / speed
# export var interference_time = 30.0
# export var interference_safe_point = 0.75
# export var jam_strength = 0.0 # enemy interference per second, if directinoal
# export var jam_range = 500
# var interference = 100.0
#
# export var radar_direction_change_time = 5.0
# export var radar_direction_multiplier = 1.25


onready var is_ammo = get_parent().get_script().get_path().get_file() == "Gun.gd"
var auto_groups = ["Airborne"]

func _enter_tree():
	G = $"/root/Globals"
	set_controller(controller)
	

func _ready():
	for x in _power_curve:
		power_curve.append(PCE.new(x[0], x[1]))
	set_speed(speed)
	set_collision_tags(collision_tags)
	set_target_collision_tags(target_collision_tags)
	set_explosion_radius(explosion_radius)
	$ExplosionArea.add_child($CollisionPolygon2D.duplicate())
	if(is_ammo):
		assert(get_parent().get_parent().team == team, "A gun fires a projectile of a different team.")
	for group in auto_groups:
		add_to_group(group)

func _physics_process(delta):
	match(controller):
		Controller.PLAYER:
			if !$"../".cli_activated:
				if Input.is_action_pressed('accelerate'):
					set_speed(speed + acceleration * delta)
					course_altered = true
					_target = null
				if Input.is_action_pressed('decelerate'):
					set_speed(speed - deceleration * delta)
					course_altered = true
					_target = null
				if Input.is_action_pressed('turn_left'):
					roll = G.Roll.LEFT
					course_altered = true
					_target = null
				elif Input.is_action_pressed('turn_right'):
					roll = G.Roll.RIGHT
					course_altered = true
					_target = null
				elif get_target_pos() != null:
					roll = G.Roll.GUIDED
				else:
					roll = G.Roll.STRAIGHT
		Controller.DUMB:
			pass
		Controller.PURSUE_NEAREST:
			roll = G.Roll.GUIDED
			var nearest = null
			var nearest_dist = null
			for airborne in get_tree().get_nodes_in_group('Airborne'):
				if airborne.team != team:
					if(nearest == null):
						nearest = airborne
						nearest_dist = airborne.global_position.distance_to(global_position)
					else:
						var dist = airborne.global_position.distance_to(global_position)
						if (dist < nearest_dist):
							nearest = airborne
							nearest_dist = dist
			_target = nearest
		Controller.PURSUE_PLAYER:
			_target = G.players[get_enemy_team()]
			assert(_target != null, "Could not find player on team %s." % get_enemy_team())
			roll = G.Roll.GUIDED
	
	
	var move = calculate_movement(delta)
	
	global_position = move[0]
	rotation += move[1]
	
	update_tracked_enemies(delta)
	
	if(effective_range >= 0):
		remaining_range -= min(speed*delta, remaining_range)
		assert(remaining_range >= 0, "remaining range is less than 0 at %10d " % remaining_range)
		if remaining_range == 0 or (targets_in_explosion_range().size() > 0 and auto_detonate):
			die(auto_detonate)
			return
	
	
	if(trail_length > 0):
		trail.append(global_position)
		if(trail.size() > trail_length):
			trail.pop_front()
	
	if(controller == Controller.PLAYER):
		var time_string = "none" if pce.r_time < 0 else "%.1f" % pce.r_time
		$"../UI/BottomText".text = \
		("spd: %.0f, rtime: %s, rrad: %.0f" % \
			[speed, time_string, pce.r_radius])	
		
	course_altered = false

func _process(_delta):
	update()

func get_enemy_team():
	return 0 if team == 1 else 1

func is_visible_by_team(vision_team):
	return true if (vision_team == team or vision_team == -1 or is_decoy) \
		 else (self in G.visible_airbornes[vision_team])

func _draw():
	if not is_visible_by_team(G.client_vision_team):
		return
	if(draw_collision and collision_draw_points.size() > 0):
		var to_draw = collision_draw_points + PoolVector2Array([collision_draw_points[0]])
		draw_polyline(to_draw, collision_line_color, collision_line_width)
		draw_polygon(to_draw, collision_poly_color)

	if trail_length > 0 and trail.size() >= 2:
		var trail_draw = []
		for point in trail:
			trail_draw.append(to_local(point))
			pass
		draw_polyline(trail_draw, trail_color, trail_width)

	if(roll in [G.Roll.LEFT, G.Roll.RIGHT] and pce.r_radius > 0 and orbit_size > 0):
		draw_circle(get_orbit(), orbit_size, orbit_color)
	
	if(draw_explosion_prediction and not dying and speed != 0):
		var explosion_prediction_pos = to_local(calculate_movement(remaining_range/speed)[0])
		draw_circle(explosion_prediction_pos, 
			$ExplosionArea/Collision.shape.radius*(1.0-(remaining_range/effective_range)),
			explosion_prediction_circle_color)
		draw_arc(explosion_prediction_pos, $ExplosionArea/Collision.shape.radius, 0, 2*PI, 32, 
		explosion_prediction_ring_color, explosion_prediction_ring_width)
	
#	if(tracking_enemies != []):
#		draw_circle(Vector2(500,0), 5, Color.red)
#
#	draw_circle(Vector2(0, 0), 500, Color(0,0,0,0.1))
#	draw_circle(Vector2(0, 0), 250, Color(0,0,0,0.2))
	

func _input(event):
	if event.is_action_pressed("l_click"):
		_target = get_global_mouse_position()
	if event.is_action_pressed("r_click"):
		_target = get_global_mouse_position() - global_position

func _on_DeathAnim_animation_finished():
	queue_free()

func max_speed():
	return power_curve[power_curve.size()-1].speed

func min_speed():
	return power_curve[0].speed

func set_speed(x):
	if (power_curve == []):
		speed = x
		return
	x = clamp(x, min_speed(), max_speed())
	speed = x
	if(power_curve[0].speed >= x):
		pce = power_curve[0]
		return
	for i in range(1, power_curve.size()):
		if power_curve[i].speed >= x:
			pce = power_curve[i-1].interpolate_by_speed(x, power_curve[i])
			return
	assert(false, "This line should not be reachable")
	
	

# the point that this unit will orbit around if untouched
func get_orbit(_roll = G.roll_to_int(self.roll)) -> Vector2:
	return Vector2(0, orbit_radius(_roll) * (-1 if _roll < 1 else 1))

func orbit_radius(_roll = G.roll_to_int(self.roll)):
	return abs(pce.r_radius * _roll)

func die(explode = true):
	if controller == Controller.PLAYER:
		$"../UI/BottomText".text = "You are dead."
	if explode:
		var targets = targets_in_explosion_range()
		print("%s is exploding, " % self
			+ ("hitting no targets." if targets == [] 
			else "hitting these targets: %s." % targets))
	else:
#		print("%s is dying peacefully" % self)
		pass
	if $Death != null:
		set_physics_process(false)
		collision_draw_points = []
		$Death.visible = true
		$Death.playing = true
		dying = true
		for x in collision_tags:
			set_collision_layer_bit(x, false)
		for x in target_collision_tags:
			set_collision_mask_bit(x, false)
	else:
		queue_free()
	

func targets_in_explosion_range():
	var ret = $ExplosionArea.get_overlapping_bodies() 
	var x = ret.find(self)
	if(x != -1):
		ret.remove(x)
	return ret

func update_tracked_enemies(delta):
	for enemy in tracked_enemies:
		if chance_to_see(enemy, delta) == 0:
			tracked_enemies.erase(enemy)
			enemy.tracking_enemies.erase(self)
	var airbornes =  get_tree().get_nodes_in_group("Airborne")
	for enemy in airbornes:
		if(enemy.team != team and not (enemy in tracked_enemies)):
			if(randf() <= chance_to_see(enemy, delta)):
				if(enemy.is_decoy):
					enemy.die(false)
				else:
					tracked_enemies.append(enemy)
					enemy.tracking_enemies.append(self)


func chance_to_see(enemy, delta):
	var dist = enemy.global_position.distance_to(global_position)
	
	var visual = visual_range * (1 - (enemy.enemy_visual_percent_reduction/100))
	var v_insta = visual / 2 # instant detection range
	var visual_chance = 0.0 if visual < dist \
		else 1 if v_insta >= dist \
		else G.mean_time_to_chance(G.max_mean_detection_time * (dist / v_insta), delta)
	
	var radar = radar_range - enemy.enemy_radar_flat_reduction
	var r_insta = radar / 2 # instant detection range
	
	var radar_chance = 0.0 if radar < dist \
		else 1.0 if r_insta >= dist \
		else G.mean_time_to_chance(G.max_mean_detection_time * (dist / r_insta), delta)
#	if max(visual_chance, radar_chance) > 0:
#		print("%s, %s, %s, %s" % [dist/v_insta if v_insta != 0 else "??", dist/r_insta if r_insta != 0 else "??", visual_chance, radar_chance])
		
	return max(visual_chance, radar_chance)
	

# used for calculating circular movement and not just prediction for the user
# list of locals: speed, global_position
# list of vars: delta, roll
# list of var-derived: remaining_range, orbit_radius, orbit
# returns [final global position, rotation]
func calculate_movement(delta, _roll = self.roll):
	match _roll:
		G.Roll.LEFT:
			_roll = -1
		G.Roll.STRAIGHT:
			_roll = 0
		G.Roll.RIGHT:
			_roll = 1
		G.Roll.GUIDED:
			if(pce.r_rate == 0):
				roll = 0 # infinite turn time
			else:
				_roll = get_angle_to(get_target_pos()) / (pce.r_rate * delta)
				if _roll > 1: 
					_roll = 1
				elif _roll < -1: 
					_roll = -1
				else: 
					_roll = 0 # no less than frame turning
	var rot = pce.r_rate * _roll * delta if pce.r_rate > 0.0 else 0.0
	var move = speed*delta if effective_range < 0 else min(remaining_range, speed*delta) 
	var orbit_radius = orbit_radius(_roll) if _roll != 0 else -1
	if (speed != 0 and orbit_radius != -1 and orbit_radius <= 10000):
		var orbit = to_global(get_orbit(_roll))
		var angle_add = 2.0 * PI * _roll * move / pce.r_circumference
		var current_angle = (global_position-orbit).angle()
#		var current_pos = orbit + Vector2.RIGHT.rotated(current_angle) * orbit_radius
		var final_angle = current_angle + angle_add
		var final_pos = orbit + Vector2.RIGHT.rotated(final_angle) * orbit_radius
		return [final_pos, rot]	
	else:
		return [global_position + Vector2(move, 0).rotated(rotation), rot]

func get_target_pos():
	return _target.global_position if _target is Node else _target
