extends Area2D

var falling = true
@onready var sprite2d: Sprite2D = $Sprite2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:

	fall()


func snap():
	var size = sprite2d.texture.get_width()
	position.x = snappedi(position.x, size)

func fall():
	if not falling:
		return
	if(position.y > 640):
		falling = false
		position.y = 650
		return
	position.y += 5
	overlap()


func overlap():
	if get_overlapping_areas() != []:
		position.y -= 5
		falling = false
