extends Node2D
# Projectiles must have the load as placeholder box checked and placed 1 per gun. 
# They can be fired any number of times, with any custom attributes! Transform is on the gun.


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
