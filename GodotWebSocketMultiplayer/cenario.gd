extends Node2D


var box_instance = preload("res://box.gd")
var boxes = []

var box_width = 64.0
var screen_width = 1200
var columns = 6
var left_offset = (screen_width - (columns * box_width)) / 2
var right_offset = left_offset + columns * box_width

var board_visual = []  

var can_drop = true
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
	box_instance.position.x = data + left_offset
	box_instance.position.y = -200

	match color:
		"red":
			box_instance.modulate = Color.LIGHT_CORAL
		"blue":
			box_instance.modulate = Color.LIGHT_BLUE
		_:
			box_instance.modulate = Color.WHITE

	add_child(box_instance)
	boxes.append(box_instance)

func _check_falling():
	if boxes.is_empty():
		can_drop = true
		return

	for box in boxes:
		if box.falling == true:
			can_drop = false
			return

	can_drop = true


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_check_falling()
				print(can_drop)
				var local_pos = get_viewport().get_camera_2d().get_global_mouse_position()
				if(local_pos.x < left_offset or local_pos.x > right_offset):
					return
				if(!can_drop):
					return
				server_handle.send_message("box_drop", {"pos_x": snapped(local_pos.x, 64) - left_offset})
				
func _on_box_drop(data):
	_spawn_box(data["x"]["pos_x"], data["z"])

func _on_button_pressed() -> void:
	server_handle.send_message("clear_bottom_line", {})
	
