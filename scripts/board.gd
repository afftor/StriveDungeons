extends Node2D
class_name HexBoard

signal character_spawned(character)
signal character_removed(character)

const GRID_WIDTH := 100
const GRID_HEIGHT := 100
const HEX_RADIUS := 24.0
const HEX_WIDTH := sqrt(3.0) * HEX_RADIUS
const HEX_VERTICAL_SPACING := HEX_RADIUS * 1.5

const CHARACTER_SCRIPT := preload("res://scripts/character.gd")

const DIRECTIONS_EVEN := [
    Vector2i(1, 0),
    Vector2i(0, -1),
    Vector2i(-1, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1)
]

const DIRECTIONS_ODD := [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(0, 1),
    Vector2i(1, 1)
]

var controller: Node
var show_grid_lines := true
var grid := {}
var characters: Array[BattleCharacter] = []
var board_offset := Vector2.ZERO
var spawn_counter := 0

func _ready() -> void:
    randomize()
    _generate_grid()
    _compute_offset()
    update()

func setup(p_controller: Node) -> void:
    controller = p_controller

func reset() -> void:
    for character in characters:
        if is_instance_valid(character):
            character.queue_free()
    characters.clear()
    for cell in grid.keys():
        var data := grid[cell]
        data["occupant"] = null
        data["effects"] = data.get("effects", [])
    spawn_counter = 0
    update()

func spawn_initial_characters() -> void:
    reset()
    if grid.is_empty():
        _generate_grid()
        _compute_offset()
    var placed_cells: Array[Vector2i] = []
    var base_cell := _get_random_free_cell()
    placed_cells.append(base_cell)
    var hero_one := spawn_character("player", base_cell)
    hero_one.display_name = "Hero 1"
    var hero_two_cell := _find_cluster_cell(placed_cells, 10)
    placed_cells.append(hero_two_cell)
    var hero_two := spawn_character("player", hero_two_cell)
    hero_two.display_name = "Hero 2"
    var raider_one_cell := _find_cluster_cell(placed_cells, 10)
    placed_cells.append(raider_one_cell)
    var raider_one := spawn_character("enemy", raider_one_cell)
    raider_one.display_name = "Raider 1"
    var raider_two_cell := _find_cluster_cell(placed_cells, 10)
    placed_cells.append(raider_two_cell)
    var raider_two := spawn_character("enemy", raider_two_cell)
    raider_two.display_name = "Raider 2"

func spawn_character(faction: String, cell: Vector2i) -> BattleCharacter:
    var character: BattleCharacter = CHARACTER_SCRIPT.new()
    character.board = self
    character.faction = faction
    character.cell = cell
    character.position = cell_to_world(cell)
    character.name = "%s_%d" % [faction, spawn_counter]
    spawn_counter += 1
    add_child(character)
    characters.append(character)
    var data := grid.get(cell)
    if data:
        data["occupant"] = character
    character_spawned.emit(character)
    character.update()
    return character

func remove_character(character: BattleCharacter) -> void:
    if not is_instance_valid(character):
        return
    if characters.has(character):
        characters.erase(character)
    var cell := character.cell
    if grid.has(cell):
        var data := grid[cell]
        if data.get("occupant") == character:
            data["occupant"] = null
    character_removed.emit(character)
    character.queue_free()
    update()

func toggle_grid_lines() -> void:
    show_grid_lines = not show_grid_lines
    update()

func set_grid_visible(value: bool) -> void:
    show_grid_lines = value
    update()

func cell_to_world(cell: Vector2i) -> Vector2:
    return _cell_to_world_no_offset(cell) - board_offset

func _cell_to_world_no_offset(cell: Vector2i) -> Vector2:
    var col := float(cell.x)
    var row := float(cell.y)
    var x := HEX_WIDTH * (col + (fmod(row, 2.0)) * 0.5)
    var y := HEX_VERTICAL_SPACING * row
    return Vector2(x, y)

func is_inside(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_WIDTH and cell.y < GRID_HEIGHT

func is_cell_passable(cell: Vector2i) -> bool:
    if not is_inside(cell):
        return false
    return grid[cell].get("passable", true)

func is_occupied(cell: Vector2i) -> bool:
    if not is_inside(cell):
        return true
    return grid[cell].get("occupant") != null

func get_occupant(cell: Vector2i) -> BattleCharacter:
    if not is_inside(cell):
        return null
    return grid[cell].get("occupant")

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
    var neighbors: Array[Vector2i] = []
    var dirs := (cell.y % 2 == 0) ? DIRECTIONS_EVEN : DIRECTIONS_ODD
    for dir in dirs:
        var candidate := cell + dir
        if is_inside(candidate):
            neighbors.append(candidate)
    return neighbors

func step_towards(from: Vector2i, to: Vector2i) -> Vector2i:
    var neighbors := get_neighbors(from)
    var best := from
    var best_distance := _cube_distance(from, to)
    for neighbor in neighbors:
        if not is_cell_passable(neighbor):
            continue
        if is_occupied(neighbor):
            continue
        var distance := _cube_distance(neighbor, to)
        if distance < best_distance:
            best_distance = distance
            best = neighbor
    return best

func find_nearest_enemy(character: BattleCharacter) -> BattleCharacter:
    var best: BattleCharacter = null
    var best_distance := INF
    for other in characters:
        if other == character:
            continue
        if other.faction == character.faction:
            continue
        if not other.is_alive():
            continue
        var distance := _cube_distance(character.cell, other.cell)
        if distance < best_distance:
            best_distance = distance
            best = other
    return best

func move_character(character: BattleCharacter, new_cell: Vector2i) -> void:
    if not is_inside(new_cell):
        return
    var current_cell := character.cell
    if current_cell == new_cell:
        return
    var data_current := grid.get(current_cell)
    if data_current and data_current.get("occupant") == character:
        data_current["occupant"] = null
    var data_new := grid.get(new_cell)
    if data_new:
        data_new["occupant"] = character
    var tween := create_tween()
    tween.tween_property(character, "position", cell_to_world(new_cell), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await tween.finished
    character.cell = new_cell
    character.position = cell_to_world(new_cell)
    apply_cell_effects(character)
    update()

func apply_cell_effects(character: BattleCharacter) -> void:
    if not grid.has(character.cell):
        return
    var effects := grid[character.cell].get("effects", [])
    for effect in effects:
        if effect is Callable:
            effect.call(character)

func get_effects(cell: Vector2i) -> Array:
    if not grid.has(cell):
        return []
    return grid[cell].get("effects", [])

func get_alive_factions() -> Array[StringName]:
    var alive := {}
    for character in characters:
        if character.is_alive():
            alive[character.faction] = true
    return alive.keys()

func _generate_grid() -> void:
    grid.clear()
    for x in GRID_WIDTH:
        for y in GRID_HEIGHT:
            var cell := Vector2i(x, y)
            grid[cell] = {
                "passable": true,
                "effects": [],
                "occupant": null
            }

func _compute_offset() -> void:
    if grid.is_empty():
        board_offset = Vector2.ZERO
        return
    var min_x := INF
    var max_x := -INF
    var min_y := INF
    var max_y := -INF
    for cell in grid.keys():
        var pos := _cell_to_world_no_offset(cell)
        min_x = min(min_x, pos.x)
        max_x = max(max_x, pos.x)
        min_y = min(min_y, pos.y)
        max_y = max(max_y, pos.y)
    board_offset = Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)

func _get_random_free_cell() -> Vector2i:
    var attempts := 0
    while attempts < 1000:
        var cell := Vector2i(randi_range(0, GRID_WIDTH - 1), randi_range(0, GRID_HEIGHT - 1))
        if not is_occupied(cell):
            return cell
        attempts += 1
    return Vector2i.ZERO

func _find_free_cell_near(center: Vector2i, max_distance: int) -> Vector2i:
    var attempts := 0
    while attempts < 1000:
        var offset := Vector2i(randi_range(-max_distance, max_distance), randi_range(-max_distance, max_distance))
        var candidate := center + offset
        if not is_inside(candidate):
            attempts += 1
            continue
        if _cube_distance(center, candidate) > max_distance:
            attempts += 1
            continue
        if is_occupied(candidate):
            attempts += 1
            continue
        return candidate
    return _get_random_free_cell()

func _find_cluster_cell(existing: Array[Vector2i], max_distance: int) -> Vector2i:
    var attempts := 0
    while attempts < 1500:
        var origin := existing[0]
        var offset := Vector2i(randi_range(-max_distance, max_distance), randi_range(-max_distance, max_distance))
        var candidate := origin + offset
        if not is_inside(candidate):
            attempts += 1
            continue
        if is_occupied(candidate):
            attempts += 1
            continue
        var fits := true
        for cell in existing:
            if _cube_distance(cell, candidate) > max_distance:
                fits = false
                break
        if fits:
            return candidate
        attempts += 1
    return _get_random_free_cell()

func _cube_distance(a: Vector2i, b: Vector2i) -> int:
    var ca := _offset_to_cube(a)
    var cb := _offset_to_cube(b)
    return int((abs(ca.x - cb.x) + abs(ca.y - cb.y) + abs(ca.z - cb.z)) / 2)

func _offset_to_cube(cell: Vector2i) -> Vector3i:
    var x := cell.x - ((cell.y - (cell.y & 1)) / 2)
    var z := cell.y
    var y := -x - z
    return Vector3i(x, y, z)

func _draw() -> void:
    var bounds_margin := Vector2(HEX_WIDTH, HEX_VERTICAL_SPACING)
    var total_width := HEX_WIDTH * GRID_WIDTH + HEX_WIDTH
    var total_height := HEX_VERTICAL_SPACING * GRID_HEIGHT + HEX_VERTICAL_SPACING
    var rect := Rect2(-board_offset - bounds_margin, Vector2(total_width, total_height) + bounds_margin * 2.0)
    draw_rect(rect, Color.BLACK)
    for cell in grid.keys():
        var center := cell_to_world(cell)
        var points := _get_hex_points(center)
        draw_colored_polygon(points, Color(0.15, 0.2, 0.25))
        if show_grid_lines:
            var outline := points.duplicate()
            outline.append(points[0])
            draw_polyline(outline, Color(0.3, 0.35, 0.45), 1.0)

func _get_hex_points(center: Vector2) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in 6:
        var angle := deg_to_rad(60.0 * i - 30.0)
        points.append(center + Vector2(cos(angle), sin(angle)) * HEX_RADIUS)
    return points
