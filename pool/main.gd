extends Node3D
signal balls_stopped
@onready var marker = $Marker3D
var done = true
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(marker)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if are_balls_stopped():
		if done == false:
			balls_stopped.emit()
			done = true

func are_balls_stopped() -> bool:
	for ball in get_tree().get_nodes_in_group("balls"):
		if ball.linear_velocity.length() > 0.05:
			done = false
			return false
	return true


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("cue_ball"):
		body.global_position = marker.global_position
		body.linear_velocity = Vector3.ZERO
		return
	if body.is_in_group("balls"):
		body.queue_free()
	pass # Replace with function body.
