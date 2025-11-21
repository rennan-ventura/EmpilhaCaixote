extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_store_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_poderes.tscn")


func _on_user_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://cadastro.tscn")

func _on_sair_btn_pressed() -> void:
	get_tree().quit()
