extends Node2D

const TURN_DURATION = 1.0
const PLAYER_FACTION = "player"
const ENEMY_FACTION = "enemy"

const CharacterClass = preload("res://scripts/character.gd")
const FloatingText = preload("res://scripts/floating_text.gd")

const MIN_SPAWN_DISTANCE = 3
const MAX_SPAWN_DISTANCE = 8
const MAX_LOG_ENTRIES = 50

const PLAYER_SPRITES = [
		"res://sprites/player_knight.png",
		"res://sprites/player_archer.png"
]

const ENEMY_SPRITES = [
		"res://sprites/enemy_bandit.png",
		"res://sprites/enemy_mage.png"
]

onready var hex_grid = $"Main@HexGrid"
onready var turn_progress_bar = $"TurnCanvas/TurnBarContainer/TurnProgress"
onready var floating_text_container = $"FloatingTextContainer"
onready var combat_log = $"TurnCanvas/CombatLogPanel/CombatLog"
onready var health_bar_layer = $"TurnCanvas/HealthBarLayer"

var combat_log_entries = []

var turn_timer = null
var turn_order = []
var next_character_id = 0

func _ready():
                randomize()
                _setup_input_actions()
                _create_turn_timer()
                _spawn_initial_characters()
                if health_bar_layer != null:
                                health_bar_layer.set_hex_grid(hex_grid)
                                health_bar_layer.refresh_from_grid()
                set_process(true)

func _process(delta):
		if turn_timer == null or turn_progress_bar == null:
				return
		if turn_timer.time_left > 0:
				var progress = (turn_timer.wait_time - turn_timer.time_left) / turn_timer.wait_time
				turn_progress_bar.value = clamp(progress, 0.0, 1.0)

func _create_turn_timer():
		turn_timer = Timer.new()
		turn_timer.wait_time = TURN_DURATION
		turn_timer.one_shot = false
		turn_timer.autostart = true
		add_child(turn_timer)
		turn_timer.connect("timeout", self, "_on_turn_timer_timeout")

func _on_turn_timer_timeout():
		if turn_progress_bar != null:
				turn_progress_bar.value = 1.0
		_process_turn_cycle()
		if turn_progress_bar != null:
				turn_progress_bar.value = 0.0

func _setup_input_actions():
	var action_map = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN]
	}
	for action in action_map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in action_map[action]:
			if _has_key_event(action, code):
					continue
			var event = InputEventKey.new()
			event.scancode = code
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("toggle_grid"):
		InputMap.add_action("toggle_grid")
	if not _has_key_event("toggle_grid", KEY_G):
		var toggle_event = InputEventKey.new()
		toggle_event.scancode = KEY_G
		InputMap.action_add_event("toggle_grid", toggle_event)

func _has_key_event(action_name, key_code):
		var events = InputMap.get_action_list(action_name)
		for event in events:
				if event is InputEventKey and event.scancode == key_code:
						return true
		return false

func _process_turn_cycle():
		_cleanup_defeated_characters()
		var active_ids = turn_order.duplicate()
		for character_id in active_ids:
				var character = hex_grid.get_character(character_id)
				if character == null or not character.is_alive():
						continue
				_perform_character_turn(character)
		_cleanup_defeated_characters()

func _perform_character_turn(character):
        var current_position = hex_grid.get_character_position(character.id)
        if current_position == null:
                return
        var target_info = _find_nearest_enemy_with_path(character)
        if target_info == null:
                return
        var target = target_info["enemy"]
        var target_position = target_info["target_position"]
        if target == null or target_position == null:
                return
        var distance = hex_grid.get_hex_distance(current_position.x, current_position.y, target_position.x, target_position.y)
        if distance <= 1:
                _resolve_attack(character, target)
                return
        var path_to_target = target_info["path"]
        if path_to_target == null or path_to_target.size() <= 1:
                return
        var steps_remaining = max(1, int(character.speed))
        var path_index = 1
        while path_index < path_to_target.size() and steps_remaining > 0:
                var step = path_to_target[path_index]
                if hex_grid.move_character(character.id, step.x, step.y):
                        steps_remaining -= 1
                        path_index += 1
                else:
                        break
        target_position = hex_grid.get_character_position(target.id)
        current_position = hex_grid.get_character_position(character.id)
        if target_position != null and current_position != null:
                var new_distance = hex_grid.get_hex_distance(current_position.x, current_position.y, target_position.x, target_position.y)
                if new_distance <= 1:
                        _resolve_attack(character, target)

func _resolve_attack(attacker, defender):
	if defender == null or attacker == null:
		return
	if not attacker.is_hostile_to(defender):
		return
	var result = attacker.attack(defender)
	var defender_position = hex_grid.get_character_position(defender.id)
	if result.hit:
		var damage_value = int(round(result.damage))
		if defender_position != null:
			_show_floating_text(defender_position, "-%d" % damage_value, Color(0.9, 0.2, 0.2))
			_log_combat_event("%s hits %s for %d damage." % [attacker.name, defender.name, damage_value])
		else:
			if defender_position != null:
				_show_floating_text(defender_position, "Dodge!", Color(0.6, 0.8, 1.0))
	_log_combat_event("%s misses %s." % [attacker.name, defender.name])
	if result.get("target_defeated", false):
		hex_grid.remove_character(defender.id)
		turn_order.erase(defender.id)
		_log_combat_event("%s is defeated." % defender.name)
	elif result.hit and hex_grid != null:
		hex_grid.update()

func _cleanup_defeated_characters():
        for character_id in hex_grid.get_character_ids():
                var character = hex_grid.get_character(character_id)
                if character == null:
                        continue
                if not character.is_alive():
                        hex_grid.remove_character(character_id)
                        turn_order.erase(character_id)
        if health_bar_layer != null:
                health_bar_layer.refresh_from_grid()

func _find_nearest_enemy_with_path(character):
        var character_position = hex_grid.get_character_position(character.id)
        if character_position == null:
                return null
        var best_enemy = null
        var best_path = []
        var best_moves = INF
        var best_target_position = null
        for candidate_id in hex_grid.get_character_ids():
                var candidate = hex_grid.get_character(candidate_id)
                if candidate == null or candidate == character:
                                continue
                if not character.is_hostile_to(candidate):
                                continue
                if not candidate.is_alive():
                                continue
                var candidate_position = hex_grid.get_character_position(candidate_id)
                if candidate_position == null:
                                continue
                var path = hex_grid.find_path_to_adjacent(character.id, character_position, candidate_position)
                if path.empty():
                        if hex_grid.get_hex_distance(character_position.x, character_position.y, candidate_position.x, candidate_position.y) > 1:
                                continue
                        path = [Vector2(int(character_position.x), int(character_position.y))]
                var moves_required = max(0, path.size() - 1)
                if moves_required < best_moves:
                        best_moves = moves_required
                        best_enemy = candidate
                        best_path = path
                        best_target_position = candidate_position
                elif moves_required == best_moves and best_target_position != null:
                        var current_distance = hex_grid.get_hex_distance(character_position.x, character_position.y, candidate_position.x, candidate_position.y)
                        var best_distance = hex_grid.get_hex_distance(character_position.x, character_position.y, best_target_position.x, best_target_position.y)
                        if current_distance < best_distance:
                                best_enemy = candidate
                                best_path = path
                                best_target_position = candidate_position
        if best_enemy == null:
                return null
        return {
                "enemy": best_enemy,
                "path": best_path,
                "target_position": best_target_position
        }

func _spawn_initial_characters():
        var existing_positions = []
        var player_positions = _generate_spawn_positions(2, existing_positions)
        existing_positions += player_positions
        var enemy_positions = _generate_spawn_positions(2, existing_positions)
	existing_positions += enemy_positions
	for index in range(player_positions.size()):
		var character = _create_character(PLAYER_FACTION, "Player %d" % (index + 1), PLAYER_SPRITES[index % PLAYER_SPRITES.size()])
		_place_character(character, player_positions[index])
	for index in range(enemy_positions.size()):
                var character = _create_character(ENEMY_FACTION, "Enemy %d" % (index + 1), ENEMY_SPRITES[index % ENEMY_SPRITES.size()])
                _place_character(character, enemy_positions[index])
        if health_bar_layer != null:
                health_bar_layer.refresh_from_grid()

func _generate_spawn_positions(count, existing_positions):
	var attempts = 0
	while attempts < 1000:
		var positions = []
		var used = existing_positions.duplicate()
		var success = true
		for _i in range(count):
			var candidate = _find_spawn_position(used)
			if candidate == null:
				success = false
				break
			positions.append(candidate)
			used.append(candidate)
		if success:
			return positions
		attempts += 1
	push_error("Failed to generate spawn positions with required spacing.")
	return []

func _find_spawn_position(used_positions):
	for _i in range(500):
		var column = randi() % hex_grid.GRID_WIDTH
		var row = randi() % hex_grid.GRID_HEIGHT
		if not hex_grid.can_place_character(column, row):
			continue
		if not _is_spawn_position_valid(column, row, used_positions):
			continue
		return Vector2(column, row)
	return null

func _is_spawn_position_valid(column, row, used_positions):
	if used_positions.empty():
		return true
	for other in used_positions:
		var distance = hex_grid.get_hex_distance(column, row, other.x, other.y)
		if distance < MIN_SPAWN_DISTANCE or distance > MAX_SPAWN_DISTANCE:
			return false
	return true

func _place_character(character, position):
	if character == null:
		return
	if hex_grid.spawn_character(character, position.x, position.y):
		turn_order.append(character.id)

func _show_floating_text(grid_position, text, color):
	if floating_text_container == null or hex_grid == null:
		return
	var world_position = hex_grid.get_world_position(grid_position.x, grid_position.y)
	var floating_text = FloatingText.new()
	floating_text.setup(text, color)
	floating_text.position = world_position
	floating_text_container.add_child(floating_text)

func _log_combat_event(message):
	if combat_log == null:
		return
	combat_log_entries.append(message)
	if combat_log_entries.size() > MAX_LOG_ENTRIES:
		combat_log_entries.remove(0)
	combat_log.clear()
	for entry in combat_log_entries:
		combat_log.append_bbcode(entry + "\n")

func _create_character(faction, name, sprite_path):
	var character = CharacterClass.new({
		"id": _generate_character_id(),
		"name": name,
		"faction": faction,
		"sprite_sheet_path": sprite_path
	})
	return character

func _generate_character_id():
	next_character_id += 1
	return "character_%d" % next_character_id
