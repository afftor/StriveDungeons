extends Node2D

export(float) var lifetime := 1.2
export(float) var rise_speed := 32.0

var elapsed := 0.0
onready var label := $Label

func _ready() -> void:
    elapsed = 0.0

func setup(text: String, color: Color) -> void:
    label.text = text
    label.add_color_override("font_color", color)

func _process(delta: float) -> void:
    elapsed += delta
    position.y -= rise_speed * delta
    var alpha := clamp(1.0 - elapsed / lifetime, 0.0, 1.0)
    label.modulate.a = alpha
    if elapsed >= lifetime:
        queue_free()
