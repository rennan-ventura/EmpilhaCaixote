extends Control
@onready var timer_counter = $HBoxContainer/global_timer as Label
@onready var clock_timer = $clock_timer as Timer

var minutes = 0
var seconds = 0
@export_range(0, 5) var default_minutes := 1
@export_range(0, 59) var default_seconds := 0

signal time_is_up()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer_counter.text = str("%02d" % default_minutes) + ":" + str("%02d" % default_seconds)
	reset_clock_timer()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if minutes == 0 and seconds == 0:
		emit_signal("time_is_up")
	pass


func _on_clock_timer_timeout() -> void:
	if seconds == 0:
		if minutes > 0:
			minutes -= 1
			seconds = 60
	seconds -= 1
	timer_counter.text = str("%02d" % minutes) + ":" + str("%02d" % seconds)

func reset_clock_timer():
	minutes = default_minutes
	seconds = default_seconds
