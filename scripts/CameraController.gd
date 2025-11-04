extends Camera2D

export(float) var pan_speed := 400.0
export(float) var drag_multiplier := 0.8
export(float) var zoom_step := 0.1
export(float) var min_zoom := 0.4
export(float) var max_zoom := 2.5

var dragging := false
var last_mouse_position := Vector2.ZERO

func _ready() -> void:
    current = true

func _process(delta: float) -> void:
    var input_vector := Vector2.ZERO
    if Input.is_action_pressed("move_right"):
        input_vector.x += 1.0
    if Input.is_action_pressed("move_left"):
        input_vector.x -= 1.0
    if Input.is_action_pressed("move_down"):
        input_vector.y += 1.0
    if Input.is_action_pressed("move_up"):
        input_vector.y -= 1.0

    if input_vector.length() > 0.0:
        input_vector = input_vector.normalized()
        global_position += input_vector * pan_speed * delta

func _unhandled_input(event) -> void:
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            dragging = event.pressed
            last_mouse_position = event.position
        elif event.button_index == BUTTON_WHEEL_UP and event.pressed:
            _apply_zoom(-zoom_step)
        elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
            _apply_zoom(zoom_step)
    elif event is InputEventMouseMotion and dragging:
        var delta := event.relative
        global_position -= delta * zoom.x * drag_multiplier

func _apply_zoom(amount: float) -> void:
    var target_zoom := clamp(zoom.x + amount, min_zoom, max_zoom)
    zoom = Vector2.ONE * target_zoom
