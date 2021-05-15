extends Node2D

const ZOOM_SPEED = 50
const MIN_ZOOM = 1
const MAX_ZOOM = 5 # higher zoom = more zoomed out
const PAN_SPEED = 100

var cli_activated = false

func camera_input(delta):
	var pan = PAN_SPEED * $Camera2D.zoom.x * delta
	var zoom = ZOOM_SPEED * delta
	if Input.is_action_pressed("pan_left"):
		$Camera2D.position.x -= pan
	if Input.is_action_pressed('pan_right'):
		$Camera2D.position.x += pan
	if Input.is_action_pressed("pan_up"):
		$Camera2D.position.y -= pan
	if Input.is_action_pressed("pan_down"):
		$Camera2D.position.y += pan
	if Input.is_action_just_released('zoom_out'):
		_zoom(zoom)
	if Input.is_action_just_released('zoom_in'):
		_zoom(-zoom)

func _zoom(i):
	$Camera2D.zoom.x = clamp($Camera2D.zoom.x + i, MIN_ZOOM, MAX_ZOOM)
	$Camera2D.zoom.y = clamp($Camera2D.zoom.y + i, MIN_ZOOM, MAX_ZOOM)

func _process(delta):
	camera_input(delta)

func _input(event):
	if event.is_action_pressed('toggle_cli'):
		toggle_console()
		get_tree().set_input_as_handled()

func toggle_console():
	if(cli_activated):
		cli_activated = false
		$UI/CLI.release_focus()
	else:
		cli_activated = true
		$UI/CLI.grab_focus()
		
