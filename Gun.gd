extends Node2D

enum Keys {NOTHING = -1, ONE=49, TWO=50, THREE=51, FOUR=52, FIVE=53}
export(Keys) var fire_key


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == fire_key:
			fire()

func fire():
	var kids = self.get_children()
	assert(kids.size() == 1)
	var only_child = kids[0]
	var child_transform
	var instance = only_child.create_instance()
	instance.transform = self.global_transform
	self.remove_child(instance)
	$"/root/World".add_child(instance)
