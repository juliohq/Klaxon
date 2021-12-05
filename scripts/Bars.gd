extends Control


var unit = null

func set_unit(x):
	unit = x
	$HP/Bar.max_value = unit.max_health
	$EW/Bar.max_value = unit.max_ewar
	$FL/Bar.max_value = unit.max_fuel

func _process(_delta):
	if(unit != null):
		if($HP/Bar.max_value > 0):
			$HP/Bar.value = unit.health
		if($EW/Bar.max_value > 0):
			$EW/Bar.value = unit.ewar
		if($FL/Bar.max_value > 0):
			$FL/Bar.value = unit.fuel
