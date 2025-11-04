extends Node2D
class_name GameController

@onready var board: HexBoard = $Board
@onready var camera: BattleCamera = $GameCamera
@onready var floating_text_layer: FloatingTextLayer = $FloatingTextLayer
@onready var log_label: RichTextLabel = $UI/LogPanel/RichTextLabel
@onready var result_popup: AcceptDialog = $UI/ResultPopup
@onready var restart_button: Button = $UI/ResultPopup/RestartButton

var turn_index := 0
var battle_active := false
var log_entries: Array[String] = []
var max_log_entries := 30

func _ready() -> void:
    board.character_spawned.connect(_on_character_spawned)
    restart_button.pressed.connect(_on_restart_pressed)
    result_popup.hide()
    var ok_button := result_popup.get_ok_button()
    if ok_button:
        ok_button.visible = false
    start_battle()

func start_battle() -> void:
    log_entries.clear()
    _refresh_log()
    board.spawn_initial_characters()
    for character in board.characters:
        _register_character(character)
    if board.characters.size() > 0:
        camera.focus_on(board.characters[0])
    turn_index = 0
    battle_active = true
    call_deferred("_advance_turn")

func _register_character(character: BattleCharacter) -> void:
    if not character.performed_attack.is_connected(_on_character_attack):
        character.performed_attack.connect(_on_character_attack)
    if not character.died.is_connected(_on_character_died):
        character.died.connect(_on_character_died)

func _on_character_spawned(character: BattleCharacter) -> void:
    _register_character(character)

func _advance_turn() -> void:
    if not battle_active:
        return
    if board.characters.is_empty():
        _end_battle(StringName("none"))
        return
    if turn_index >= board.characters.size():
        turn_index = 0
    var character := board.characters[turn_index]
    turn_index += 1
    if not is_instance_valid(character):
        call_deferred("_advance_turn")
        return
    if not character.is_alive():
        call_deferred("_advance_turn")
        return
    await character.take_turn()
    if _check_battle_finished():
        return
    call_deferred("_advance_turn")

func _check_battle_finished() -> bool:
    var alive_factions := board.get_alive_factions()
    if alive_factions.size() <= 1:
        var winner := alive_factions[0] if alive_factions.size() == 1 else StringName("none")
        _end_battle(winner)
        return true
    return false

func _end_battle(winner: StringName) -> void:
    battle_active = false
    var message := ""
    if winner == StringName("player"):
        message = "Player faction is victorious!"
        _add_log_entry(message, Color(0.5, 1.0, 0.5))
    elif winner == StringName("enemy"):
        message = "Enemy faction prevails."
        _add_log_entry(message, Color(1.0, 0.5, 0.5))
    else:
        message = "Battle ended in a draw."
        _add_log_entry(message, Color(0.8, 0.8, 0.8))
    result_popup.dialog_text = message
    result_popup.popup_centered()

func _on_character_attack(attacker: BattleCharacter, defender: BattleCharacter, hit: bool, damage_amount: int) -> void:
    var impact_position := defender.global_position if is_instance_valid(defender) else attacker.global_position
    var defender_name := defender.get_display_name() if is_instance_valid(defender) else "Unknown"
    var attacker_name := attacker.get_display_name() if is_instance_valid(attacker) else "Unknown"
    if hit:
        floating_text_layer.show_text(str(damage_amount), impact_position, Color(1.0, 0.35, 0.3))
        _add_log_entry("%s hit %s for %d damage." % [attacker_name, defender_name, damage_amount], Color(1.0, 0.6, 0.6))
        if not is_instance_valid(defender) or not defender.is_alive():
            floating_text_layer.show_text("Defeated", impact_position, Color(1.0, 0.8, 0.2))
    else:
        floating_text_layer.show_text("Miss", impact_position, Color(0.65, 0.75, 1.0))
        _add_log_entry("%s missed %s." % [attacker_name, defender_name], Color(0.7, 0.8, 1.0))

func _on_character_died(character: BattleCharacter) -> void:
    _add_log_entry("%s was defeated." % character.get_display_name(), Color(0.9, 0.6, 0.3))
    var index := board.characters.find(character)
    if index != -1 and index <= turn_index:
        turn_index = max(0, turn_index - 1)
    board.remove_character(character)
    _check_battle_finished()

func _on_restart_pressed() -> void:
    result_popup.hide()
    board.reset()
    start_battle()

func _add_log_entry(message: String, color: Color = Color.WHITE) -> void:
    var color_code := "#%02x%02x%02x" % [int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0)]
    log_entries.append("[color=%s]%s[/color]" % [color_code, message])
    if log_entries.size() > max_log_entries:
        log_entries = log_entries.slice(log_entries.size() - max_log_entries, log_entries.size())
    _refresh_log()

func _refresh_log() -> void:
    log_label.text = "\n".join(log_entries)
    log_label.scroll_to_line(log_label.get_line_count())

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_grid"):
        board.toggle_grid_lines()
