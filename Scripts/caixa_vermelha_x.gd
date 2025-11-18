extends Area2D
var falling : bool
var fall_speed := 50  # pixels por segundo


	
func _physics_process(delta):
	var bodies = get_overlapping_areas()
	if (falling):
		#position.y += 5
		position.y += fall_speed * delta
		
	
	
	
