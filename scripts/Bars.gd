extends Control


var unit = null

func set_unit(x):
	unit = x
	$HP/Bar.max_value = unit.max_health

func _process(_delta):
	if(unit != null):
		if(unit.health != -1):
			$HP/Bar.value = unit.health
