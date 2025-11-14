extends CharacterBody2D

var speed = 5000
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	velocity = Vector2.ZERO
	
	if Input.is_action_pressed("move_right"):
		velocity.x = 1
	if Input.is_action_pressed("move_left"):
		velocity.x = -1
	
	
	velocity += velocity * delta * speed
	move_and_slide()
