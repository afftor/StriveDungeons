extends Node2D
class_name FloatingTextLayer

const FLOATING_TEXT := preload("res://scripts/floating_text.gd")

func show_text(text_value: String, world_position: Vector2, color: Color) -> void:
    var text_instance: FloatingText = FLOATING_TEXT.new()
    text_instance.position = world_position
    add_child(text_instance)
    text_instance.display(text_value, color)
