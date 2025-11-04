extends Node2D

const GRID_WIDTH := 100
const GRID_HEIGHT := 100
const CELL_RADIUS := 24.0
const SQRT3 := 1.73205080757

var show_grid_lines := true
var grid_origin := Vector2.ZERO
var cells := []
var characters := {}

func _ready():
    _build_cells()
    _compute_origin()
    update()

func _build_cells():
    cells.clear()
    for row_index in range(GRID_HEIGHT):
        var row := []
        for column_index in range(GRID_WIDTH):
            row.append({
                "character": null,
                "impassable": false,
                "effects": []
            })
        cells.append(row)

func _compute_origin():
    var min_x := INF
    var max_x := -INF
    var min_y := INF
    var max_y := -INF
    for row_index in range(GRID_HEIGHT):
        for column_index in range(GRID_WIDTH):
            var point := _axial_to_pixel(column_index, row_index)
            min_x = min(min_x, point.x)
            max_x = max(max_x, point.x)
            min_y = min(min_y, point.y)
            max_y = max(max_y, point.y)
    var center := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
    grid_origin = -center

func _draw():
    var backdrop_rect := Rect2(Vector2(-50000, -50000), Vector2(100000, 100000))
    draw_rect(backdrop_rect, Color(0, 0, 0, 1))
    for row_index in range(GRID_HEIGHT):
        for column_index in range(GRID_WIDTH):
            var center := _axial_to_world(column_index, row_index)
            var polygon := _build_cell_polygon(center)
            var base_color := Color(0.16, 0.22, 0.27)
            var cell := cells[row_index][column_index]
            if cell["impassable"]:
                base_color = Color(0.35, 0.18, 0.18)
            elif cell["effects"].size() > 0:
                base_color = Color(0.20, 0.26, 0.34)
            draw_colored_polygon(polygon, base_color)
            if show_grid_lines:
                var outline := _build_cell_outline(center)
                draw_polyline(outline, Color(0.32, 0.40, 0.46), 1.2)
            if cell["character"] != null:
                draw_circle(center, CELL_RADIUS * 0.35, Color(0.85, 0.85, 0.35))

func _build_cell_polygon(center):
    var points := PoolVector2Array()
    for index in range(6):
        points.append(center + _hex_corner(index))
    return points

func _build_cell_outline(center):
    var outline := PoolVector2Array()
    for index in range(6):
        outline.append(center + _hex_corner(index))
    outline.append(center + _hex_corner(0))
    return outline

func _hex_corner(index):
    var angle := PI / 6.0 + index * PI / 3.0
    return Vector2(cos(angle), sin(angle)) * CELL_RADIUS

func _axial_to_world(column_index, row_index):
    return _axial_to_pixel(column_index, row_index) + grid_origin

func _axial_to_pixel(column_index, row_index):
    var x := CELL_RADIUS * (1.5 * column_index)
    var y := CELL_RADIUS * (SQRT3 * row_index + SQRT3 * 0.5 * column_index)
    return Vector2(x, y)

func toggle_grid_lines():
    show_grid_lines = not show_grid_lines
    update()

func _unhandled_input(event):
    if event.is_action_pressed("toggle_grid"):
        toggle_grid_lines()

func is_in_bounds(column_index, row_index):
    return column_index >= 0 and column_index < GRID_WIDTH and row_index >= 0 and row_index < GRID_HEIGHT

func get_cell(column_index, row_index):
    if not is_in_bounds(column_index, row_index):
        return null
    return cells[row_index][column_index]

func can_place_character(column_index, row_index):
    var cell := get_cell(column_index, row_index)
    if cell == null:
        return false
    if cell["impassable"]:
        return false
    if cell["character"] != null:
        return false
    return true

func spawn_character(character_id, column_index, row_index):
    if not can_place_character(column_index, row_index):
        return false
    var cell := get_cell(column_index, row_index)
    cell["character"] = character_id
    characters[character_id] = Vector2(column_index, row_index)
    update()
    return true

func move_character(character_id, new_column, new_row):
    if not characters.has(character_id):
        return false
    if not can_place_character(new_column, new_row):
        return false
    var current_position := characters[character_id]
    var current_cell := get_cell(current_position.x, current_position.y)
    var target_cell := get_cell(new_column, new_row)
    if current_cell == null or target_cell == null:
        return false
    current_cell["character"] = null
    target_cell["character"] = character_id
    characters[character_id] = Vector2(new_column, new_row)
    update()
    return true

func remove_character(character_id):
    if not characters.has(character_id):
        return false
    var position := characters[character_id]
    var cell := get_cell(position.x, position.y)
    if cell != null:
        cell["character"] = null
    characters.erase(character_id)
    update()
    return true

func set_impassable(column_index, row_index, value := true):
    var cell := get_cell(column_index, row_index)
    if cell == null:
        return false
    cell["impassable"] = value
    update()
    return true

func add_cell_effect(column_index, row_index, effect_name):
    var cell := get_cell(column_index, row_index)
    if cell == null:
        return false
    cell["effects"].append(effect_name)
    update()
    return true

func clear_cell_effects(column_index, row_index):
    var cell := get_cell(column_index, row_index)
    if cell == null:
        return false
    cell["effects"].clear()
    update()
    return true

func get_cell_effects(column_index, row_index):
    var cell := get_cell(column_index, row_index)
    if cell == null:
        return []
    return cell["effects"].duplicate()
