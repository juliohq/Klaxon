extends KinematicBody2D
onready var Globals = $"/root/Globals"
const PCE = preload("PowerCurveEntry.gd")


export var team = 0

enum Controller {PLAYER, DUMB, PURSUIT_MK_I = 1001}
export(Controller) var controller = 1 setget set_controller
func set_controller(x):
	controller = x
	if not is_inside_tree():
		yield(self, "ready")
	if(x == Controller.PLAYER):
		assert(Globals.players[team] == null or Globals.players[team] == self, Globals.players[team])
		Globals.players[team] = self

# may be position node or vector, use get_target_pos() to access position/node as position
onready var _target = Globals.players[0 if team == 1 else 1] if is_pursuit() else null 
# will rotate to face the given direction not position
var rotate_to_vector = false 

func is_pursuit():
	return controller / 1000 == 1

enum CollisionTags {AIR = 11, GROUND = 12}
export(Array, CollisionTags) var collision_tags = []
export(Array, CollisionTags) var target_collision_tags = []

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
export var roll_time = 2.0

export var health = -1
export var _explosion_radius = 0
export var auto_detonate = false



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



var roll = 0
var auto_level = false
var trail = []

func _ready():
	for x in _power_curve:
		power_curve.append(PCE.new(x[0], x[1]))
	set_speed(speed)
	$ExplosionArea/Collision.shape.radius = _explosion_radius
	for tag in collision_tags:
		set_collision_layer_bit(tag, true)
	for tag in target_collision_tags:
		$ExplosionArea.set_collision_mask_bit(tag, true)
	$ExplosionArea.add_child($CollisionPolygon2D.duplicate())

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
					roll = clamp(roll - delta/roll_time, -1.0, 1.0) if roll_time != -1 else 0
					course_altered = true
					_target = null
				elif Input.is_action_pressed('turn_right'):
					roll = clamp(roll + delta/roll_time, -1.0, 1.0) if roll_time != -1 else 0
					course_altered = true
					_target = null
				elif get_target_pos() != null:
					if(rotate_to_vector):
						_basic_pursuit(delta, get_target_pos())
					else:
						_basic_pursuit(delta,get_target_pos())
				elif auto_level: 
					if(roll < 0):
						roll = clamp(roll  + delta/roll_time, -1.0, 0) if roll_time != -1 else 0
					else:
						roll = clamp(roll - delta/roll_time, 0, 1.0) if roll_time != -1 else 0
					course_altered = true
					_target = null
		Controller.DUMB:
			pass
		Controller.PURSUIT_MK_I:
			_basic_pursuit(delta, get_target_pos())
	
	
	var move = calculate_movement(delta)
	
	global_position = move[0]
	if not is_pursuit():
		rotation += move[1] 
	else:
		var pos = get_target_pos()
		if pos:
			var upper = abs(to_local(pos).angle())  
			rotation += clamp(move[1], 0, upper) if move[1] >= 0 else clamp(move[1], -upper, 0)
	
	
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
		("spd: %.0f, rtime: %s, rrad: %.0f, roll: %.2f %s" % \
			[speed, time_string, pce.r_radius, roll, "A" if auto_level else ""])	
		
	course_altered = false

# roll a the appropriate rate to face the target directly ASAP
func _basic_pursuit(delta, g_pos):
	assert(roll_time != -1)
	var angle = get_angle_to(g_pos) / (2 * PI)
	# for desired roll, angle = roll_time * roll * roll / 2 
	# since roll_time * roll / 2 is the amount of time spent rolling at max decel
	# thus roll_time * roll * roll / 2 is the time travelled at max decel
	# thus roll = sqrt(angle/roll_time) * 2
	var desired_roll = sqrt(abs(angle/roll_time)) * (2 if angle >= 0 else -2) # * overshoot if you want to lead the target perhaps
	roll = clamp(desired_roll, max(-1.0, roll - delta / roll_time), min(1.0, roll + delta / roll_time))

func _input(event):
	if event.is_action_pressed("reset_roll"):
		auto_level = not auto_level
	if event.is_action_pressed("l_click"):
		_target = get_global_mouse_position()
		rotate_to_vector = false
	if event.is_action_pressed("r_click"):
		_target = get_global_mouse_position() - global_position
		rotate_to_vector = true

func _process(_delta):
	update()

func acceptable_levels(x, top, name, bottom = 0):
	if(x < bottom or x > top):
		print("!!!Warning!!! %s is at unacceptable levels: %s" % [name, x])

func _draw():
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

	if(abs(roll) >= 0.01 and pce.r_radius > 0 and orbit_size > 0):
		# print(to_global(get_orbit()))
		draw_circle(get_orbit(), orbit_size, orbit_color)
	
	if(draw_explosion_prediction):
		var explosion_prediction_pos = to_local(calculate_movement(remaining_range/speed)[0])
		draw_circle(explosion_prediction_pos, 
			$ExplosionArea/Collision.shape.radius*(1.0-(remaining_range/effective_range)),
			explosion_prediction_circle_color)
		draw_arc(explosion_prediction_pos, $ExplosionArea/Collision.shape.radius, 0, 2*PI, 32, 
		explosion_prediction_ring_color, explosion_prediction_ring_width)
	
	

# the point that this unit will orbit around if untouched
func get_orbit(_roll = self.roll) -> Vector2:
	return Vector2(0, pce.r_radius / _roll)

func orbit_radius(_roll = self.roll):
	return -1.0 if _roll == 0.0 else abs(pce.r_radius / _roll)

func die(explode = true):
	if controller == Controller.PLAYER:
		$"../UI/BottomText".text = "You are dead."
	if explode:
#		print("%s is exploding, hitting these targets: %s" % [self, targets_in_explosion_range()])
		pass
	else:
#		print("%s is dying peacefully" % self)
		pass
	if $Death != null:
		set_physics_process(false)
		collision_draw_points = []
		$Death.visible = true
		$Death.playing = true
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

# used for calculating circular movement and not just prediction for the user
# list of locals: speed, global_position
# list of vars: delta, roll
# list of var-derived: remaining_range, orbit_radius, orbit
# returns [final global position, rotation]
func calculate_movement(delta, _roll = self.roll):
	var rot = pce.r_rate * _roll * delta if pce.r_rate > 0.0 else 0.0
	var move = speed*delta if effective_range < 0 else min(remaining_range, speed*delta) 
	var orbit_radius = orbit_radius(_roll)
	if (_roll != 0 and speed != 0 and orbit_radius != -1 and orbit_radius <= 100000):
		var orbit = to_global(get_orbit(_roll))
		var angle_add = 2.0 * PI * _roll * move / pce.r_circumference
		var current_angle = (global_position-orbit).angle()
		var current_pos = orbit + Vector2.RIGHT.rotated(current_angle) * orbit_radius
		var final_angle = current_angle + angle_add
		var final_pos = orbit + Vector2.RIGHT.rotated(final_angle) * orbit_radius
		# Used to ensure that our angle relative to orbit is fairly accurate,
		# since that's what our position is treated as when orbiting
		acceptable_levels(current_pos.distance_to(global_position), 0.005, "Orbit bounceback")
		if(!course_altered):
			acceptable_levels (to_global(get_orbit(_roll)).distance_to(orbit), 0.005, "Random orbit movement")
		return [final_pos, rot]	
	else:
		return [global_position + Vector2(move, 0).rotated(rotation), rot]




func _on_DeathAnim_animation_finished():
	queue_free()

func get_target_pos():
	return _target.global_position if _target is Node else _target
