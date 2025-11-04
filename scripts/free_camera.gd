extends Camera2D

export var move_speed = 600.0
export var drag_speed = 1.0
export var zoom_step = 0.1
export var min_zoom = 0.4
export var max_zoom = 4.0

var dragging = false
var last_mouse_position = Vector2.ZERO
var ui_blockers = []

func _ready():
		set_process(true)
		set_process_input(true)
		_cache_ui_blockers()
		if ui_blockers.empty():
				call_deferred("_cache_ui_blockers")

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
			if _is_mouse_over_ui(event.position):
				return
			_apply_zoom(-zoom_step)
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			if _is_mouse_over_ui(event.position):
				return
			_apply_zoom(zoom_step)
	elif event is InputEventMouseMotion and dragging:
		var delta = event.position - last_mouse_position
		last_mouse_position = event.position
		position -= delta * drag_speed * zoom.x

func _apply_zoom(step):
	var current_zoom = zoom.x
	var target_zoom = clamp(current_zoom + step, min_zoom, max_zoom)
	zoom = Vector2(target_zoom, target_zoom)

func _cache_ui_blockers():
	ui_blockers.clear()
	var root = get_tree().get_root()
	if root == null:
		return
	var turn_canvas = root.find_node("TurnCanvas", true, false)
	if turn_canvas == null:
		return
	_collect_ui_blockers(turn_canvas)

func _collect_ui_blockers(node):
	if node is Control:
		var control = node as Control
		if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			ui_blockers.append(control)
	for child in node.get_children():
			_collect_ui_blockers(child)

func _is_mouse_over_ui(position):
	for blocker in ui_blockers:
		if not is_instance_valid(blocker):
			continue
		if not blocker.is_visible_in_tree():
			continue
		if blocker.get_global_rect().has_point(position):
			return true
	return false
