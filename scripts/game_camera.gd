extends Camera2D
class_name BattleCamera

var drag_active := false
var drag_origin := Vector2.ZERO
var drag_start_position := Vector2.ZERO
var move_speed := 600.0
var zoom_step := 0.1
var min_zoom := 0.4
var max_zoom := 2.5
var edge_pan_margin := 24.0
var edge_pan_speed := 400.0

func _ready() -> void:
    current = true

func focus_on(target: Node2D) -> void:
    if target == null:
        return
    global_position = target.global_position

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_button := event as InputEventMouseButton
        if mouse_button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
            drag_active = mouse_button.pressed
            if drag_active:
                drag_origin = mouse_button.position
                drag_start_position = global_position
                accept_event()
        elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
            _adjust_zoom(-zoom_step)
            accept_event()
        elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            _adjust_zoom(zoom_step)
            accept_event()
    elif event is InputEventMouseMotion and drag_active:
        var motion := event as InputEventMouseMotion
        var delta := motion.position - drag_origin
        global_position = drag_start_position - delta * zoom.x
        accept_event()

func _process(delta: float) -> void:
    var input_vector := Vector2.ZERO
    if Input.is_action_pressed("camera_right"):
        input_vector.x += 1
    if Input.is_action_pressed("camera_left"):
        input_vector.x -= 1
    if Input.is_action_pressed("camera_down"):
        input_vector.y += 1
    if Input.is_action_pressed("camera_up"):
        input_vector.y -= 1
    var viewport := get_viewport()
    if viewport:
        var mouse_position := viewport.get_mouse_position()
        var view_size := viewport.get_visible_rect().size
        if mouse_position.x <= edge_pan_margin:
            input_vector.x -= 1
        elif mouse_position.x >= view_size.x - edge_pan_margin:
            input_vector.x += 1
        if mouse_position.y <= edge_pan_margin:
            input_vector.y -= 1
        elif mouse_position.y >= view_size.y - edge_pan_margin:
            input_vector.y += 1
    if input_vector.length() > 0:
        var move_vector := input_vector.normalized()
        var speed := move_speed
        if viewport and (mouse_position.x <= edge_pan_margin or mouse_position.x >= view_size.x - edge_pan_margin or mouse_position.y <= edge_pan_margin or mouse_position.y >= view_size.y - edge_pan_margin):
            speed = max(move_speed, edge_pan_speed)
        global_position += move_vector * speed * delta / zoom.x

func _adjust_zoom(delta_zoom: float) -> void:
    var new_zoom := clamp(zoom.x + delta_zoom, min_zoom, max_zoom)
    zoom = Vector2.ONE * new_zoom
