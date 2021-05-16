extends Camera2D

func _process(delta):
	if is_current():
		$"/root/Globals".current_camera = self
