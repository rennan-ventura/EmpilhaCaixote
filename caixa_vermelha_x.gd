
extends Area2D

var fall_speed := 50  # pixels por segundo

func _physics_process(delta):
	position.y += fall_speed * delta
	queue_redraw()
