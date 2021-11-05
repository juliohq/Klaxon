extends TextureRect

func _ready():
	material.set_shader_param("global_transform", get_global_transform())
