extends KinematicBody2D
const PCE = preload("PowerCurveEntry.gd")

enum Controller {PLAYER, DUMB}
export var controller = Controller.PLAYER

enum CollisionTags {AIR, GROUND}
export(Array, CollisionTags) var collision_tags = []
export(Array, CollisionTags) var target_collision_tags = []

export var draw_points = PoolVector2Array([])
export var points_color = Color.blue
export var trail_length = 0
export var trail_color = Color.gray
export var orbit_size =  0
export var orbit_color = Color.gray
export var acceleration = 100
export var deceleration = 100
export var effective_range = -1
export var team = 0
export var roll_time = 2.0

export var health = -1
export var _explosion_radius = -1
export var auto_detonate = false


# purely for export/init, built into the below variable then never used
# [speed, turntime]
export(Array, Array, int) var _power_curve = [
	[0, -1],
	[250, 4],
	[500, 3],
	[1000, 0.1]
]
# array of PCEs constructed from the above
var power_curve = []
var pce : PCE # current speed and turn data
var speed setget set_speed

var remaining_range = effective_range
var course_altered = false



var roll = 0
var auto_level = false
var trail = []

func _ready():
	for x in _power_curve:
		power_curve.append(PCE.new(x[0], x[1]))
	pce = power_curve[0]
	speed = pce.speed
	$ExplosionArea/Collision.shape.radius = _explosion_radius
	for tag in collision_tags:
		set_collision_layer_bit(tag, true)
	for tag in target_collision_tags:
		$ExplosionArea.set_collision_mask_bit(tag, true)

func max_speed():
	return power_curve[power_curve.size()-1].speed

func min_speed():
	return power_curve[0].speed

func set_speed(x):
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
				if Input.is_action_pressed('decelerate'):
					set_speed(speed - deceleration * delta)
					course_altered = true
				if Input.is_action_pressed('turn_left'):
					roll = clamp(roll - delta/roll_time, -1.0, 1.0)
					course_altered = true
				elif Input.is_action_pressed('turn_right'):
					roll = clamp(roll + delta/roll_time, -1.0, 1.0)
					course_altered = true
				elif auto_level: 
					if(roll < 0):
						roll = clamp(roll  + delta/roll_time, -1.0, 0)
					else:
						roll = clamp(roll - delta/roll_time, 0, 1.0)
					course_altered = true
	
	if( 
		(speed*delta > remaining_range and remaining_range != -1)
		or ($ExplosionArea.get_overlapping_bodies().size() > 1 and auto_detonate)
		):
		die()
		return

	if (roll != 0 and speed != 0 and pce.r_rate != 0):
		var orbit = to_global(get_orbit())
		var orbit_radius = orbit_radius()
		var dist = speed * delta
		var angle_add = 2.0 * PI * roll * dist / pce.r_circumference
		var current_angle = global_rotation # equivalent to (global_position-orbit).angle()
		var current_pos = orbit + Vector2.RIGHT.rotated(current_angle) * orbit_radius
		var final_angle = current_angle + angle_add
		var direction = Vector2(cos(final_angle), sin(final_angle))
		var final_pos = orbit + direction  * orbit_radius
		global_position = final_pos
		if(pce.r_rate > 0):
			rotate(pce.r_rate * roll * delta)
		if(!course_altered):
#			print(to_global(get_orbit()) - orbit) 
			assert (to_global(get_orbit()).is_equal_approx(orbit),\
			 "%s != %s" %  [to_global(get_orbit()), orbit])
	else:
		if(pce.r_rate > 0):
			rotate(pce.r_rate * roll * delta)
		var _x = move_and_collide(Vector2(0, speed*delta))
		
	

	
	
	if(remaining_range != -1):
		remaining_range -= speed*delta
	
	
	if(trail_length > 0):
		trail.append(global_position)
		if(trail.size() > trail_length):
			trail.pop_front()
			
	var time_string = "none" if pce.r_time < 0 else "%.1f" % pce.r_time
	$"../UI/BottomText".text = \
	("spd: %.0f, rtime: %s, rrad: %.0f, roll: %.1f %s" % \
		[speed, time_string, pce.r_radius, roll, "A" if auto_level else ""])	
		
	course_altered = false

func _input(event):
	if event.is_action_pressed("reset_roll"):
		auto_level = not auto_level

func _process(_delta):
	update()

func _draw():
	if(draw_points.size() > 0):
		draw_polyline(draw_points + PoolVector2Array([draw_points[0]]), points_color)

	if trail_length > 0 and trail.size() >= 2:
		var trail_draw = []
		for point in trail:
			trail_draw.append(to_local(point))
			pass
		draw_polyline(trail_draw, trail_color)

	if(abs(roll) >= 0.01 and orbit_size > 0):
		# print(to_global(get_orbit()))
		draw_circle(get_orbit(), orbit_size, orbit_color)

# the point that this unit will orbit around if untouched
func get_orbit() -> Vector2:
	return Vector2(-orbit_radius(), 0)

func orbit_radius():
	return pce.r_radius / roll

func die():
	if controller == Controller.PLAYER:
		$"../UI/BottomText".text = "You are dead."
	queue_free()
