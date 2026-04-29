extends Node3D

@export var cue_ball: RigidBody3D

@export var move_speed := .1
@export var angle_speed := 0.01
@export var max_force := 25.0
@export var rotation_speed := 2.0

var offset := Vector3(0, 0.1, 0.5)
var charge := 0.0
var pitch_min := -170.0
var pitch_max := 10.0
var pitch := 0.0
var yaw := 0.0
var shooting = false

@onready var cue_mesh := $cue


func _physics_process(delta: float) -> void:
	handle_input(delta)
	var ball := get_ball()
	if ball == null:
		return
	

	# Keep cue attached to ball
	#global_position = ball.global_position

	handle_charge(delta)

func handle_input(delta: float) -> void:
	var input_pitch = Input.get_action_strength("back") - Input.get_action_strength("forward")
	var input_yaw = Input.get_action_strength("right") - Input.get_action_strength("left")

	pitch += input_pitch * rotation_speed
	yaw += input_yaw * rotation_speed

	pitch = clamp(pitch, pitch_min, pitch_max)

	rotation_degrees = Vector3(pitch, yaw, 0)


func handle_charge(delta: float) -> void:
	if Input.is_action_pressed("shoot"):
		charge = clamp(charge + delta * 2.0, 0.0, max_force)

	if Input.is_action_just_released("shoot"):
		shoot()
		charge = 0.0


func get_ball() -> RigidBody3D:
	return get_tree().get_first_node_in_group("cue_ball")


func shoot() -> void:
	if shooting:
		return
	var ball := get_ball()
	if ball == null:
		return
	visible = false
	shooting = true
	var forward := -global_transform.basis.z
	ball.apply_central_impulse(forward * charge)

func done_shooting():
	shooting = false 
	visible = true
