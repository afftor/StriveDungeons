extends Node2D
class_name FloatingText

@onready var label := Label.new()

func _ready() -> void:
    add_child(label)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.set("theme_override_font_sizes/font_size", 18)
    label.size = Vector2(96, 28)
    label.pivot_offset = label.size * 0.5
    z_index = 100

func display(text_value: String, color: Color) -> void:
    label.text = text_value
    label.modulate = color
    var tween := create_tween()
    tween.tween_property(self, "position", position + Vector2(0, -40), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
    tween.finished.connect(queue_free)
