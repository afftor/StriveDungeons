extends Node2D
class_name FloatingText

export var lifetime = 1.2
export var rise_speed = 45.0

const LABEL_VERTICAL_OFFSET = 40

var elapsed = 0.0
var label = null
var text_value = ""
var base_color = Color(1, 1, 1)

func _ready():
				set_process(true)
				z_index = 100
				label = Label.new()
				label.rect_min_size = Vector2(80, 24)
				label.align = Label.ALIGN_CENTER
				label.rect_position = Vector2(-label.rect_min_size.x * 0.5, -LABEL_VERTICAL_OFFSET)
				label.text = text_value
				label.set("custom_colors/font_color", base_color)
				label.set("custom_colors/font_color_shadow", Color(0, 0, 0, 0.75))
				label.set("custom_constants/shadow_offset_x", 2)
				label.set("custom_constants/shadow_offset_y", 2)
				add_child(label)
				modulate = Color(1, 1, 1, 1)

func setup(content, color):
				text_value = str(content)
				base_color = color
				if label != null:
								label.text = text_value
								label.set("custom_colors/font_color", base_color)

func _process(delta):
				elapsed += delta
				position.y -= rise_speed * delta
				var progress = clamp(elapsed / lifetime, 0.0, 1.0)
				var current_modulate = modulate
				current_modulate.a = 1.0 - progress
				modulate = current_modulate
				if elapsed >= lifetime:
								queue_free()
