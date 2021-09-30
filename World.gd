extends Node2D

const ZOOM_SPEED = 50
const MIN_ZOOM = 0.1
const MAX_ZOOM = 20 # higher zoom = more zoomed out
const PAN_SPEED = 100

var cli_activated = false

func camera_input(delta, c):
	var pan = PAN_SPEED * c.zoom.x * delta
	var zoom = ZOOM_SPEED * delta
	if Input.is_action_pressed("pan_left"):
		c.position.x -= pan
	if Input.is_action_pressed('pan_right'):
		c.position.x += pan
	if Input.is_action_pressed("pan_up"):
		c.position.y -= pan
	if Input.is_action_pressed("pan_down"):
		c.position.y += pan
	if Input.is_action_just_released('zoom_out'):
		_zoom(zoom, c)
	if Input.is_action_just_released('zoom_in'):
		_zoom(-zoom, c)

func _zoom(i, c):
	c.zoom.x = clamp(c.zoom.x + i, MIN_ZOOM, MAX_ZOOM)
	c.zoom.y = clamp(c.zoom.y + i, MIN_ZOOM, MAX_ZOOM)

func _process(delta):
	var c = $"/root/Globals".current_camera
	if(c):
		camera_input(delta, c)

func _input(event):
	if event.is_action_pressed('toggle_cli'):
		toggle_console()
		get_tree().set_input_as_handled()
	if (event.is_action_pressed("follow_player_toggle")):
		if($"/root/Globals".current_camera == $"/root/Globals".free_camera):
			$"/root/Globals".player_camera.make_current()
		else:
			assert($"/root/Globals".current_camera == $"/root/Globals".player_camera)
			$"/root/Globals".free_camera.make_current()
			$"/root/Globals".free_camera.global_position = $"/root/Globals".player_camera.global_position
		

func toggle_console():
	if(cli_activated):
		cli_activated = false
		$UI/CLI.release_focus()
	else:
		cli_activated = true
		$UI/CLI.grab_focus()
