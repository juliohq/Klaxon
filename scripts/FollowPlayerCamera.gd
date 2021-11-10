extends Camera2D

func _ready():
	$"/root/Globals".player_camera = self
	if self.current:
		$"/root/Globals".current_camera = self

func _process(_delta):
	if self.current:
		$"/root/Globals".current_camera = self
