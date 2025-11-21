extends CharacterBody2D

var is_holding := false
var can_hold := false
const NEW_ITEM := preload("res://Scenes/caixa_vermelha_X.tscn")

var speed = 5000
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	velocity = Vector2.ZERO
	
	if Input.is_action_pressed("moved"):
		velocity.x = 1
	if Input.is_action_pressed("movea"):
		velocity.x = -1
	
	velocity += velocity * delta * speed
	move_and_slide()
	
	if can_hold and !is_holding:
		if Input.is_action_just_pressed("pick_box"):
			can_hold = false
			is_holding = true
			var item_detector = $Area2D
			var items_detected = item_detector.get_overlapping_areas()
			for item_detected in items_detected:
				item_detected.queue_free()
	
	if !can_hold and is_holding:
		if Input.is_action_just_pressed("drop_box"):
			var item_instance = NEW_ITEM.instantiate()
			get_parent().add_child(item_instance)
			item_instance.position = $item_position.global_position
			item_instance.falling = true
			is_holding = false
			can_hold = true




func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("pickables") and !is_holding:
		can_hold = true
