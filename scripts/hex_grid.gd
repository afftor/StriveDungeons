extends Node2D

const GRID_WIDTH = 30
const GRID_HEIGHT = 30
const CELL_RADIUS = 24.0
const SQRT3 = 1.73205080757

const HEALTH_BAR_WIDTH = CELL_RADIUS * 1.4
const HEALTH_BAR_HEIGHT = 4.0
const HEALTH_BAR_OFFSET_Y = CELL_RADIUS * 0.55
const HEALTH_BAR_BACKGROUND_COLOR = Color(0, 0, 0, 0.75)
const HEALTH_BAR_FOREGROUND_COLOR = Color(0.25, 0.85, 0.35)

const NEIGHBOR_OFFSETS_EVEN = [
    Vector2(1, 0),
    Vector2(0, -1),
    Vector2(-1, -1),
    Vector2(-1, 0),
    Vector2(-1, 1),
    Vector2(0, 1)
]

const NEIGHBOR_OFFSETS_ODD = [
    Vector2(1, 0),
    Vector2(1, -1),
    Vector2(0, -1),
    Vector2(-1, 0),
    Vector2(0, 1),
    Vector2(1, 1)
]

var show_grid_lines = true
var grid_origin = Vector2.ZERO
var cells = []
var characters = {}
var character_positions = {}

func _ready():
    _build_cells()
    _compute_origin()
    update()

func _build_cells():
    cells.clear()
    for row_index in range(GRID_HEIGHT):
        var row = []
        for column_index in range(GRID_WIDTH):
            row.append({
                "character": null,
                "impassable": false,
                "effects": []
            })
        cells.append(row)

func _compute_origin():
    var min_x = INF
    var max_x = -INF
    var min_y = INF
    var max_y = -INF
    for row_index in range(GRID_HEIGHT):
        for column_index in range(GRID_WIDTH):
            var point = _axial_to_pixel(column_index, row_index)
            min_x = min(min_x, point.x)
            max_x = max(max_x, point.x)
            min_y = min(min_y, point.y)
            max_y = max(max_y, point.y)
    var center = Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
    grid_origin = -center

func _draw():
    var backdrop_rect = Rect2(Vector2(-50000, -50000), Vector2(100000, 100000))
    draw_rect(backdrop_rect, Color(0, 0, 0, 1))
    for row_index in range(GRID_HEIGHT):
        for column_index in range(GRID_WIDTH):
            var center = _axial_to_world(column_index, row_index)
            var polygon = _build_cell_polygon(center)
            var base_color = Color(0.16, 0.22, 0.27)
            var cell = cells[row_index][column_index]
            if cell["impassable"]:
                base_color = Color(0.35, 0.18, 0.18)
            elif cell["effects"].size() > 0:
                base_color = Color(0.20, 0.26, 0.34)
            draw_colored_polygon(polygon, base_color)
            if not show_grid_lines:
                continue
            var outline = _build_cell_outline(center)
            draw_polyline(outline, Color(0.32, 0.40, 0.46), 1.2)
            if cell["character"] == null:
                continue
            var character_color = Color(0.85, 0.85, 0.35)
            var character_id = cell["character"]
            if character_id != null and characters.has(character_id):
                var character = characters[character_id]
                if character != null:
                    if character.faction == "player":
                        character_color = Color(0.35, 0.85, 0.45)
                    elif character.faction == "enemy":
                        character_color = Color(0.9, 0.3, 0.3)
            draw_circle(center, CELL_RADIUS * 0.35, character_color)

func _build_cell_polygon(center):
    var points = PoolVector2Array()
    for index in range(6):
        points.append(center + _hex_corner(index))
    return points

func _build_cell_outline(center):
    var outline = PoolVector2Array()
    for index in range(6):
        outline.append(center + _hex_corner(index))
    outline.append(center + _hex_corner(0))
    return outline

func _hex_corner(index):
    var angle = PI / 6.0 + index * PI / 3.0
    return Vector2(cos(angle), sin(angle)) * CELL_RADIUS

func _axial_to_world(column_index, row_index):
    return _axial_to_pixel(column_index, row_index) + grid_origin

func _axial_to_pixel(column_index, row_index):
    var row_offset = float(int(row_index) % 2) * (SQRT3 * 0.5)
    var x = CELL_RADIUS * (SQRT3 * column_index + row_offset)
    var y = CELL_RADIUS * (1.5 * row_index)
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
    var cell = get_cell(column_index, row_index)
    if cell == null:
        return false
    if cell["impassable"]:
        return false
    if cell["character"] != null:
        return false
    return true

func spawn_character(character, column_index, row_index):
    if not can_place_character(column_index, row_index):
        return false
    if character == null:
        return false
    var cell = get_cell(column_index, row_index)
    var character_id = character.id
    if character_id == "":
        return false
    if characters.has(character_id):
        return false
    cell["character"] = character_id
    characters[character_id] = character
    character_positions[character_id] = Vector2(column_index, row_index)
    character.set_position(Vector2(column_index, row_index))
    update()
    return true

func move_character(character_id, new_column, new_row):
    if not characters.has(character_id):
        return false
    if not can_place_character(new_column, new_row):
        return false
    var current_position = character_positions[character_id]
    var current_cell = get_cell(current_position.x, current_position.y)
    var target_cell = get_cell(new_column, new_row)
    if current_cell == null or target_cell == null:
        return false
    current_cell["character"] = null
    target_cell["character"] = character_id
    character_positions[character_id] = Vector2(new_column, new_row)
    var character = characters[character_id]
    if character != null:
        character.set_position(Vector2(new_column, new_row))
    update()
    return true

func remove_character(character_id):
    if not characters.has(character_id):
        return false
    var position = character_positions.get(character_id, null)
    if position != null:
        var cell = get_cell(position.x, position.y)
        if cell != null:
            cell["character"] = null
    characters.erase(character_id)
    character_positions.erase(character_id)
    update()
    return true

func set_impassable(column_index, row_index, value = true):
    var cell = get_cell(column_index, row_index)
    if cell == null:
        return false
    cell["impassable"] = value
    update()
    return true

func add_cell_effect(column_index, row_index, effect_name):
    var cell = get_cell(column_index, row_index)
    if cell == null:
        return false
    cell["effects"].append(effect_name)
    update()
    return true

func clear_cell_effects(column_index, row_index):
    var cell = get_cell(column_index, row_index)
    if cell == null:
        return false
    cell["effects"].clear()
    update()
    return true

func get_cell_effects(column_index, row_index):
    var cell = get_cell(column_index, row_index)
    if cell == null:
        return []
    return cell["effects"].duplicate()

func get_character(character_id):
    if not characters.has(character_id):
        return null
    return characters[character_id]

func get_character_ids():
    return characters.keys()

func get_character_position(character_id):
    return character_positions.get(character_id, null)

func get_character_at(column_index, row_index):
    var cell = get_cell(column_index, row_index)
    if cell == null:
        return null
    var character_id = cell["character"]
    if character_id == null:
        return null
    return get_character(character_id)

func is_cell_occupied(column_index, row_index):
    var cell = get_cell(column_index, row_index)
    if cell == null:
        return false
    return cell["character"] != null

func get_neighbor_coordinates(column_index, row_index):
    var neighbors = []
    var offsets = NEIGHBOR_OFFSETS_EVEN
    if int(row_index) % 2 != 0:
        offsets = NEIGHBOR_OFFSETS_ODD
    for offset in offsets:
        var neighbor_column = column_index + int(offset.x)
        var neighbor_row = row_index + int(offset.y)
        if is_in_bounds(neighbor_column, neighbor_row):
            neighbors.append(Vector2(neighbor_column, neighbor_row))
    return neighbors

func get_hex_distance(column_a, row_a, column_b, row_b):
    var cube_a = _offset_to_cube(column_a, row_a)
    var cube_b = _offset_to_cube(column_b, row_b)
    return int((abs(cube_a.x - cube_b.x) + abs(cube_a.y - cube_b.y) + abs(cube_a.z - cube_b.z)) / 2)

func get_step_towards(column_a, row_a, column_b, row_b):
    var current_distance = get_hex_distance(column_a, row_a, column_b, row_b)
    var best_step = null
    var best_distance = current_distance
    for neighbor in get_neighbor_coordinates(column_a, row_a):
        if is_cell_occupied(neighbor.x, neighbor.y):
            continue
        var neighbor_distance = get_hex_distance(neighbor.x, neighbor.y, column_b, row_b)
        if neighbor_distance >= best_distance:
            continue
        best_distance = neighbor_distance
        best_step = neighbor
    return best_step

func _offset_to_cube(column_index, row_index):
    var x = column_index - int((row_index - (int(row_index) & 1)) / 2)
    var z = row_index
    var y = -x - z
    return Vector3(x, y, z)

func get_world_position(column_index, row_index):
    return _axial_to_world(column_index, row_index)

func is_cell_walkable(column_index, row_index, ignore_character_id = ""):
    var cell = get_cell(column_index, row_index)
    if cell == null:
        return false
    if cell["impassable"]:
        return false
    var occupant = cell["character"]
    if occupant != null and occupant != ignore_character_id:
        return false
    return true

func find_path(start_column, start_row, goal_column, goal_row, ignore_character_id = "", allow_goal_occupied = false):
    if not is_in_bounds(start_column, start_row) or not is_in_bounds(goal_column, goal_row):
        return []
    var start = _make_grid_key(start_column, start_row)
    var goal = _make_grid_key(goal_column, goal_row)
    if start == goal:
        return [start]
    var frontier = [start]
    var came_from = {}
    came_from[start] = null
    while frontier.size() > 0:
        var current = frontier.pop_front()
        if current == goal:
            break
        for neighbor in get_neighbor_coordinates(current.x, current.y):
            var neighbor_key = _make_grid_key(neighbor.x, neighbor.y)
            if came_from.has(neighbor_key):
                continue
            var walkable = is_cell_walkable(neighbor.x, neighbor.y, ignore_character_id)
            if not walkable:
                if allow_goal_occupied and neighbor_key == goal:
                    var goal_cell = get_cell(goal.x, goal.y)
                    if goal_cell == null or goal_cell["impassable"]:
                        continue
                    walkable = true
                else:
                    continue
            if walkable:
                came_from[neighbor_key] = current
                frontier.append(neighbor_key)
    if not came_from.has(goal):
        return []
    var path = []
    var current_key = goal
    while current_key != null:
        path.insert(0, current_key)
        current_key = came_from.get(current_key, null)
    return path

func find_path_to_adjacent(character_id, start_position, target_position):
    if start_position == null or target_position == null:
        return []
    if get_hex_distance(start_position.x, start_position.y, target_position.x, target_position.y) <= 1:
        return [_make_grid_key(start_position.x, start_position.y)]
    var best_path = []
    var best_length = INF
    for neighbor in get_neighbor_coordinates(target_position.x, target_position.y):
        if neighbor == start_position:
            return [_make_grid_key(start_position.x, start_position.y)]
        if not is_cell_walkable(neighbor.x, neighbor.y, character_id):
            continue
        var candidate_path = find_path(start_position.x, start_position.y, neighbor.x, neighbor.y, character_id)
        if candidate_path.empty():
            continue
        if candidate_path.size() >= best_length:
            continue
        best_length = candidate_path.size()
        best_path = candidate_path
    return best_path

func _make_grid_key(column_index, row_index):
    return Vector2(int(column_index), int(row_index))
