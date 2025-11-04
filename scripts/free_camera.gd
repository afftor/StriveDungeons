extends Camera2D

export var move_speed = 600.0
export var drag_speed = 1.0
export var zoom_step = 0.1
export var min_zoom = 0.4
export var max_zoom = 4.0

var dragging = false
var last_mouse_position = Vector2.ZERO

func _ready():
	set_process(true)
	set_process_input(true)

func _process(delta):
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += direction * move_speed * delta

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			dragging = event.pressed
			last_mouse_position = event.position
		elif event.button_index == BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(-zoom_step)
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(zoom_step)
	elif event is InputEventMouseMotion and dragging:
		var delta = event.position - last_mouse_position
		last_mouse_position = event.position
		position -= delta * drag_speed * zoom.x

func _apply_zoom(step):
	var current_zoom = zoom.x
	var target_zoom = clamp(current_zoom + step, min_zoom, max_zoom)
	zoom = Vector2(target_zoom, target_zoom)
