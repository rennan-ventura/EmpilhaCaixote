extends Node2D


var server_handle
@export var box: PackedScene = preload("res://box.tscn")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	var player_container = $PlayerContainer
	var mp_manager = get_node("/root/MultiplayerManager")
	if mp_manager and mp_manager.has_method("set_player_container"):
		mp_manager.set_player_container(player_container)
		print("PlayerContainer registrado no MultiplayerManager")
	server_handle = get_node("/root/WebSocketClient")
	server_handle.connect("box_drop", Callable(self, "_on_box_drop"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _spawn_box(data: int, color: String) -> void:
	var box_instance := box.instantiate()
	box_instance.position.x = snapped(data, 64)
	box_instance.position.y = -200
	match color:
		"red":
			box_instance.modulate = Color.LIGHT_CORAL
		"blue":
			box_instance.modulate = Color.LIGHT_BLUE
		_:
			box_instance.modulate = Color.WHITE

	add_child(box_instance)


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos = get_viewport().get_camera_2d().get_global_mouse_position()
				server_handle.send_message("box_drop", {"pos_x": snapped(local_pos.x, 64)})
				
func _on_box_drop(data):
	_spawn_box(data["x"]["pos_x"], data["z"])
