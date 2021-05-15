extends KinematicBody2D
const PCE = preload("PowerCurveEntry.gd")

enum Controller {PLAYER, DUMB}

export var draw_points = PoolVector2Array([])
export var points_color = Color.blue
export var trail_length = 0
export var trail_color = Color.gray
export var orbit_size =  0
export var orbit_color = Color.gray
export var controller = Controller.PLAYER
export var acceleration = 100
export var deceleration = 100
export var effective_range = -1

 # purely for export/init, built into the below variable then never used
export var _power_curve : PoolVector2Array = PoolVector2Array([
	Vector2(0, -1),
	Vector2(250, 4),
	Vector2(500, 3),
	Vector2(1000, 0.1)	
])
# array of PCEs constructed from the above
var power_curve = []
var pce : PCE # current speed and turn data
var speed setget set_speed

var remaining_range = effective_range



const roll_time = 2
var roll = 0
var auto_level = false
var trail = []

func _init():
	var to_power_curve = Array(_power_curve)
	for x in to_power_curve:
		power_curve.append(PCE.new(x[0], x[1]))
	pce = power_curve[0]
	speed = pce.speed

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
	if(controller == Controller.PLAYER and !$"../".cli_activated):
		if Input.is_action_pressed('accelerate'):
			set_speed(speed + acceleration * delta)
		if Input.is_action_pressed('decelerate'):
			set_speed(speed - deceleration * delta)
		if Input.is_action_pressed('turn_left'):
			roll = clamp(roll - delta/roll_time, -1.0, 1.0)
		elif Input.is_action_pressed('turn_right'):
			roll = clamp(roll + delta/roll_time, -1.0, 1.0)
		elif auto_level: 
			if(roll < 0):
				roll = clamp(roll  + delta/roll_time, -1.0, 0)
			else:
				roll = clamp(roll - delta/roll_time, 0, 1.0)
	
	if(pce.r_rate > 0):
		rotate(pce.r_rate * roll * delta)
	if(speed*delta <= remaining_range or remaining_range == -1):
		var _x = move_and_collide(Vector2(0, speed*delta).rotated(rotation))
		if(remaining_range != -1):
			remaining_range -= speed*delta
	else:
		die()
		return
	
	
	if(trail_length > 0):
		trail.append(global_position)
		if(trail.size() > trail_length):
			trail.pop_front()
			
	var time_string = "none" if pce.r_time < 0 else "%.1f" % pce.r_time
	$"../UI/BottomText".text = \
	("spd: %.0f, rtime: %s, rrad: %.0f, roll: %.1f %s" % \
		[speed, time_string, pce.r_radius, roll, "A" if auto_level else ""])	

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
		var r_radius = pce.r_radius / roll
		print(to_global(Vector2(-r_radius, 0)))
		draw_circle(Vector2(-r_radius, 0), orbit_size, orbit_color)

func die():
	if controller == Controller.PLAYER:
		$"../UI/BottomText".text = "You are dead."
	queue_free()
