extends CharacterBody2D

var is_holding = true
const NEW_ITEM := preload("res://caixa_vermelha_X.tscn")

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
	
	if is_holding:
		if Input.is_action_pressed("drop_box"):
			var item_instance = NEW_ITEM.instantiate()
			get_parent().add_child(item_instance)
			item_instance.position = $item_position.global_position
