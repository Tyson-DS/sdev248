extends Camera3D
var ball: RigidBody3D
var offset = Vector3(0, .5, 1.5)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ball = get_ball()
	print(ball)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position = ball.global_position + offset
	look_at(ball.global_position, Vector3.UP)

func get_ball() -> RigidBody3D:
	return get_tree().get_first_node_in_group("cue_ball")
