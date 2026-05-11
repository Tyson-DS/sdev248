extends Node2D

@export var radius = 40
@export var color = Color(0, 0.6, 1, 0.2)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
