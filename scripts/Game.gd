extends Node2D

const BOARD_WIDTH := 100
const BOARD_HEIGHT := 100
const HEX_RADIUS := 32.0
const GRID_COLOR := Color(0.2, 0.2, 0.2, 1.0)
const FIELD_COLOR := Color(0.1, 0.12, 0.15, 1.0)
const BLACK_COLOR := Color(0, 0, 0, 1)
const TURN_DELAY := 0.4

const HEX_DIRECTIONS := [
    Vector2(1, 0),
    Vector2(1, -1),
    Vector2(0, -1),
    Vector2(-1, 0),
    Vector2(-1, 1),
    Vector2(0, 1)
]

export(NodePath) var log_label_path
export(NodePath) var result_popup_path

onready var log_label := log_label_path and get_node(log_label_path)
onready var result_popup := result_popup_path and get_node(result_popup_path)

var cells := {}
var occupants := {}
var characters := []
var show_grid := true
var turn_index := 0
var turn_timer := 0.0
var battle_over := false
var log_entries := []

var floating_text_scene := preload("res://scenes/FloatingText.tscn")
var character_scene := preload("res://scenes/Character.tscn")

func _ready() -> void:
    randomize()
    _initialize_cells()
    spawn_initial_characters()
    update()

func _physics_process(delta: float) -> void:
    if battle_over:
        return

    if characters.empty():
        return

    turn_timer -= delta
    if turn_timer <= 0.0:
        _advance_turn()
        turn_timer = TURN_DELAY

func _initialize_cells() -> void:
    cells.clear()
    occupants.clear()
    for q in range(BOARD_WIDTH):
        for r in range(BOARD_HEIGHT):
            var key := Vector2(q, r)
            cells[key] = {
                "impassable": false,
                "effects": []
            }
            occupants[key] = null

func spawn_initial_characters() -> void:
    var center := Vector2(BOARD_WIDTH / 2, BOARD_HEIGHT / 2)
    var factions := ["player", "player", "enemy", "enemy"]
    for i in range(factions.size()):
        var faction := factions[i]
        var cell := _find_spawn_cell(center, 10)
        if cell == null:
            continue
        var character := character_scene.instance()
        character.faction = faction
        character.current_cell = cell
        character.game = self
        character.set_stat_defaults()
        character.move_to_world(axial_to_world(cell))
        occupants[cell] = character
        add_child(character)
        characters.append(character)

    if not characters.empty():
        var camera = has_node("Camera2D") ? get_node("Camera2D") : get_viewport().get_camera()
        if camera:
            camera.global_position = characters[0].global_position

func _find_spawn_cell(center: Vector2, radius: int) -> Vector2:
    for _i in range(200):
        var q := clamp(int(center.x + randi() % (radius * 2 + 1) - radius), 0, BOARD_WIDTH - 1)
        var r := clamp(int(center.y + randi() % (radius * 2 + 1) - radius), 0, BOARD_HEIGHT - 1)
        var cell := Vector2(q, r)
        if occupants[cell] == null:
            return cell
    return null

func _advance_turn() -> void:
    if characters.empty():
        return

    var attempts := 0
    while attempts < max(1, characters.size()):
        if characters.empty():
            turn_index = 0
            return
        if turn_index >= characters.size():
            turn_index = 0
        var character = characters[turn_index]
        attempts += 1
        if character == null or not character.is_alive():
            characters.remove(turn_index)
            continue
        _character_take_turn(character)
        if characters.empty():
            turn_index = 0
        else:
            turn_index = (turn_index + 1) % characters.size()
        return

func _character_take_turn(character) -> void:
    if battle_over:
        return

    var enemies := _get_enemies(character)
    if enemies.empty():
        _finish_battle(character.faction)
        return

    var target = _get_nearest_enemy(character, enemies)
    if target == null:
        return

    if character.current_cell == target.current_cell:
        _attack(character, target)
        return

    var steps := max(1, character.speed)
    for _i in range(steps):
        var next_cell := _get_next_step_towards(character.current_cell, target.current_cell)
        if next_cell == null:
            return
        if occupants.has(next_cell) and occupants[next_cell] != null:
            var occupant = occupants[next_cell]
            if occupant.faction != character.faction:
                _attack(character, occupant, next_cell)
            return
        _move_character(character, next_cell)
        if character.current_cell == target.current_cell:
            _attack(character, target)
            return

func _get_enemies(character) -> Array:
    var enemies := []
    for other in characters:
        if other != character and other.is_alive() and other.faction != character.faction:
            enemies.append(other)
    return enemies

func _get_nearest_enemy(character, enemies: Array):
    var closest := null
    var closest_distance := INF
    for enemy in enemies:
        var distance := _hex_distance(character.current_cell, enemy.current_cell)
        if distance < closest_distance:
            closest_distance = distance
            closest = enemy
    return closest

func _get_next_step_towards(start: Vector2, goal: Vector2) -> Vector2:
    var best_cell := null
    var best_distance := INF
    for direction in HEX_DIRECTIONS:
        var neighbor_vec := start + direction
        var neighbor := Vector2(int(neighbor_vec.x), int(neighbor_vec.y))
        if not _is_inside_board(neighbor):
            continue
        if cells[neighbor]["impassable"]:
            continue
        var dist := _hex_distance(neighbor, goal)
        if dist < best_distance:
            best_distance = dist
            best_cell = neighbor
    return best_cell

func _move_character(character, cell: Vector2) -> void:
    var target_cell := Vector2(int(cell.x), int(cell.y))
    if not _is_inside_board(target_cell):
        return
    if occupants[target_cell] != null:
        return
    occupants[character.current_cell] = null
    character.current_cell = target_cell
    occupants[target_cell] = character
    character.move_to_world(axial_to_world(target_cell))

func _attack(attacker, defender, advance_cell := null) -> void:
    if not attacker.is_alive() or not defender.is_alive():
        return

    var hit_roll := randf()
    var log_message := ""
    if hit_roll <= attacker.hit_chance:
        var base_damage := attacker.base_damage
        var fluctuation := rand_range(0.8, 1.2)
        var dmg := int(round(base_damage * fluctuation))
        defender.receive_damage(dmg)
        log_message = "%s hits %s for %d damage" % [attacker.get_display_name(), defender.get_display_name(), dmg]
        _spawn_floating_text(defender.position, str(dmg), Color(1, 0.5, 0.2))
        if not defender.is_alive():
            log_message += " (defeated)"
            _on_character_defeated(defender)
            if advance_cell != null:
                _move_character(attacker, advance_cell)
    else:
        log_message = "%s misses %s" % [attacker.get_display_name(), defender.get_display_name()]
        _spawn_floating_text(defender.position, "Miss", Color(0.6, 0.8, 1))
    _append_log(log_message)

func _on_character_defeated(character) -> void:
    occupants[character.current_cell] = null
    character.die()
    characters.erase(character)
    if character:
        character.queue_free()

    var remaining_factions := {}
    for c in characters:
        if c.is_alive():
            remaining_factions[c.faction] = true
    if remaining_factions.size() <= 1:
        for faction in remaining_factions.keys():
            _finish_battle(faction)
            return

func _finish_battle(winning_faction: String) -> void:
    if battle_over:
        return
    battle_over = true
    var message := "%s faction wins the battle" % winning_faction.capitalize()
    var losing := _get_losing_faction(winning_faction)
    if losing != "":
        _append_log("%s faction loses the battle" % losing.capitalize())
    _append_log(message)
    if result_popup:
        result_popup.get_node("VBoxContainer/ResultLabel").text = message
        result_popup.popup_centered()

func _get_losing_faction(winning_faction: String) -> String:
    var factions := {}
    for character in characters:
        if character.is_alive():
            factions[character.faction] = true
    for faction in ["player", "enemy"]:
        if faction != winning_faction:
            return faction
    for faction in factions.keys():
        if faction != winning_faction:
            return faction
    return ""

func _spawn_floating_text(world_position: Vector2, text: String, color: Color) -> void:
    var floating = floating_text_scene.instance()
    floating.setup(text, color)
    floating.position = world_position
    add_child(floating)

func _append_log(entry: String) -> void:
    log_entries.append(entry)
    if log_entries.size() > 30:
        log_entries = log_entries.slice(log_entries.size() - 30, log_entries.size())
    if log_label:
        log_label.bbcode_text = "\n".join(log_entries)

func axial_to_world(cell: Vector2) -> Vector2:
    var q := cell.x
    var r := cell.y
    var x := HEX_RADIUS * sqrt(3) * (q + r / 2.0)
    var y := HEX_RADIUS * 1.5 * r
    return Vector2(x, y)

func _hex_distance(a: Vector2, b: Vector2) -> int:
    var ac := _axial_to_cube(a)
    var bc := _axial_to_cube(b)
    return int((abs(ac.x - bc.x) + abs(ac.y - bc.y) + abs(ac.z - bc.z)) / 2)

func _axial_to_cube(coord: Vector2) -> Vector3:
    var x := coord.x
    var z := coord.y
    var y := -x - z
    return Vector3(x, y, z)

func _is_inside_board(cell: Vector2) -> bool:
    return cell.x >= 0 and cell.x < BOARD_WIDTH and cell.y >= 0 and cell.y < BOARD_HEIGHT

func _unhandled_input(event) -> void:
    if event.is_action_pressed("toggle_grid"):
        show_grid = not show_grid
        update()

func _draw() -> void:
    var min_rect := Rect2(-5000, -5000, 10000, 10000)
    draw_rect(min_rect, BLACK_COLOR)

    for q in range(BOARD_WIDTH):
        for r in range(BOARD_HEIGHT):
            var cell := Vector2(q, r)
            var center := axial_to_world(cell)
            _draw_hex_cell(center)

func _draw_hex_cell(center: Vector2) -> void:
    var points := []
    for i in range(6):
        var angle := PI / 180.0 * (60 * i - 30)
        var x := center.x + HEX_RADIUS * cos(angle)
        var y := center.y + HEX_RADIUS * sin(angle)
        points.append(Vector2(x, y))
    draw_colored_polygon(points, FIELD_COLOR)
    if show_grid:
        points.append(points[0])
        for i in range(points.size() - 1):
            draw_line(points[i], points[i + 1], GRID_COLOR, 1.0)
