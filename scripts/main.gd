extends Node2D

const TURN_DURATION = 1.0
const PLAYER_FACTION = "player"
const ENEMY_FACTION = "enemy"

const CharacterClass = preload("res://scripts/character.gd")

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

var turn_timer = null
var turn_order = []
var next_character_id = 0

func _ready():
		randomize()
		_setup_input_actions()
		_create_turn_timer()
		_spawn_initial_characters()
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
		var target = _find_nearest_enemy(character)
		if target == null:
				return
		var target_position = hex_grid.get_character_position(target.id)
		if target_position == null:
				return
		var distance = hex_grid.get_hex_distance(current_position.x, current_position.y, target_position.x, target_position.y)
		if distance <= 1:
				_resolve_attack(character, target)
				return
		var steps = max(1, int(character.speed))
		var position_after_move = current_position
		for _i in range(steps):
				var step = hex_grid.get_step_towards(position_after_move.x, position_after_move.y, target_position.x, target_position.y)
				if step == null:
						break
				if hex_grid.move_character(character.id, step.x, step.y):
						position_after_move = step
						target_position = hex_grid.get_character_position(target.id)
						if target_position == null:
								break
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
		var result = attacker.attack(defender)
		if result.get("target_defeated", false):
				hex_grid.remove_character(defender.id)
				turn_order.erase(defender.id)

func _cleanup_defeated_characters():
		for character_id in hex_grid.get_character_ids():
				var character = hex_grid.get_character(character_id)
				if character == null:
						continue
				if not character.is_alive():
						hex_grid.remove_character(character_id)
						turn_order.erase(character_id)

func _find_nearest_enemy(character):
		var character_position = hex_grid.get_character_position(character.id)
		if character_position == null:
				return null
		var nearest = null
		var shortest_distance = INF
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
				var distance = hex_grid.get_hex_distance(character_position.x, character_position.y, candidate_position.x, candidate_position.y)
				if distance < shortest_distance:
						shortest_distance = distance
						nearest = candidate
		return nearest

func _spawn_initial_characters():
		var player_positions = [Vector2(10, 10), Vector2(13, 10)]
		var enemy_positions = [Vector2(16, 10), Vector2(19, 10)]
		for index in range(player_positions.size()):
				var character = _create_character(PLAYER_FACTION, "Player %d" % (index + 1), PLAYER_SPRITES[index % PLAYER_SPRITES.size()])
				_place_character(character, player_positions[index])
		for index in range(enemy_positions.size()):
				var character = _create_character(ENEMY_FACTION, "Enemy %d" % (index + 1), ENEMY_SPRITES[index % ENEMY_SPRITES.size()])
				_place_character(character, enemy_positions[index])

func _place_character(character, position):
		if character == null:
				return
		if hex_grid.spawn_character(character, position.x, position.y):
				turn_order.append(character.id)

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
