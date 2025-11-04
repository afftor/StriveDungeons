extends Node2D
class_name CharacterUnit

export(int) var base_hp := 20
export(int) var base_damage := 10
export(int) var speed := 1
export(float, 0.0, 1.0, 0.01) var hit_chance := 0.75
export(String) var faction := "player"
export(String) var sprite_sheet_path := ""

var current_hp := 0
var current_cell := Vector2()
var game = null

func _ready() -> void:
    if current_hp <= 0:
        current_hp = base_hp
    update()

func set_stat_defaults() -> void:
    current_hp = base_hp
    update()

func move_to_world(target: Vector2) -> void:
    position = target

func is_alive() -> bool:
    return current_hp > 0

func receive_damage(amount: int) -> void:
    current_hp = max(0, current_hp - amount)
    update()

func die() -> void:
    current_hp = 0
    update()

func get_display_name() -> String:
    return "%s #%d" % [faction.capitalize(), get_instance_id() % 1000]

func _draw() -> void:
    var radius := 20.0
    var color := _faction_color()
    draw_circle(Vector2.ZERO, radius, color)
    draw_circle(Vector2.ZERO, radius - 6.0, color.darkened(0.2))

func _faction_color() -> Color:
    match faction:
        "player":
            return Color(0.4, 0.7, 1.0)
        "enemy":
            return Color(1.0, 0.4, 0.4)
        _:
            return Color(0.8, 0.8, 0.8)
