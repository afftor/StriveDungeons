extends Node2D
class_name BattleCharacter

signal performed_attack(attacker, defender, hit, damage)
signal died(character)

const BASE_HP := 20
const BASE_DAMAGE := 10
const BASE_SPEED := 1
const BASE_HIT_CHANCE := 0.75

var board: HexBoard
var faction: StringName = "player"
var base_hp: int = BASE_HP
var hp: int = BASE_HP
var damage: int = BASE_DAMAGE
var speed: int = BASE_SPEED
var hit_chance: float = BASE_HIT_CHANCE
var sprite_sheet: Texture2D
var cell: Vector2i = Vector2i.ZERO
var display_name: String = ""

const HP_BAR_SIZE := Vector2(36, 4)

func _ready() -> void:
    set_process(false)

func is_alive() -> bool:
    return hp > 0

func take_turn() -> void:
    if board == null:
        return
    if not is_alive():
        return
    var target := board.find_nearest_enemy(self)
    if target == null:
        return
    for i in speed:
        if target == null or not target.is_alive():
            target = board.find_nearest_enemy(self)
            if target == null:
                return
        if cell == target.cell:
            await _perform_attack(target)
            return
        var next_cell := board.step_towards(cell, target.cell)
        if next_cell == cell:
            break
        var occupant := board.get_occupant(next_cell)
        if occupant != null:
            if occupant.faction != faction:
                await _perform_attack(occupant)
                if occupant.is_alive():
                    return
                await board.move_character(self, next_cell)
            return
        if not board.is_cell_passable(next_cell):
            break
        await board.move_character(self, next_cell)
    target = board.find_nearest_enemy(self)
    if target != null and target.cell == cell:
        await _perform_attack(target)

func take_damage(amount: int) -> void:
    hp = max(0, hp - amount)
    update()
    if hp <= 0:
        died.emit(self)

func get_display_name() -> String:
    if display_name != "":
        return display_name
    return name

func _perform_attack(target: BattleCharacter) -> void:
    if target == null or not target.is_alive():
        return
    var hit_roll := randf()
    var hit := hit_roll <= hit_chance
    var dealt := 0
    if hit:
        var fluctuation := randf_range(-0.2, 0.2)
        dealt = int(round(float(damage) * (1.0 + fluctuation)))
        target.take_damage(dealt)
    performed_attack.emit(self, target, hit, dealt)
    await get_tree().create_timer(0.35).timeout

func _draw() -> void:
    var radius := (board != null) ? board.HEX_RADIUS * 0.75 : 18.0
    var fill_color := Color(0.25, 0.8, 0.45) if faction == "player" else Color(0.8, 0.25, 0.35)
    draw_circle(Vector2.ZERO, radius, fill_color)
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0, 0, 0), 2.0)
    var hp_ratio := 0.0
    if base_hp > 0:
        hp_ratio = float(hp) / float(base_hp)
    var bar_origin := Vector2(-HP_BAR_SIZE.x * 0.5, -radius - 12)
    draw_rect(Rect2(bar_origin, HP_BAR_SIZE), Color(0.1, 0.1, 0.1))
    draw_rect(Rect2(bar_origin, Vector2(HP_BAR_SIZE.x * hp_ratio, HP_BAR_SIZE.y)), Color(0.2, 1.0, 0.2))
