extends Reference
class_name Character

const DEFAULT_HP = 20
const DEFAULT_DAMAGE = 10
const DEFAULT_SPEED = 1
const DEFAULT_HIT_CHANCE = 0.75
const DAMAGE_VARIANCE = 0.2

var id = ""
var name = ""
var faction = "neutral"
var sprite_sheet_path = ""
var max_hp = DEFAULT_HP
var hp = DEFAULT_HP
var base_damage = DEFAULT_DAMAGE
var speed = DEFAULT_SPEED
var hit_chance = DEFAULT_HIT_CHANCE
var position = Vector2.ZERO

func _init(config = {}):
	id = config.get("id", id)
	name = config.get("name", name)
	faction = config.get("faction", faction)
	sprite_sheet_path = config.get("sprite_sheet_path", sprite_sheet_path)
	max_hp = config.get("max_hp", DEFAULT_HP)
	hp = config.get("hp", max_hp)
	base_damage = config.get("base_damage", DEFAULT_DAMAGE)
	speed = config.get("speed", DEFAULT_SPEED)
	hit_chance = config.get("hit_chance", DEFAULT_HIT_CHANCE)

func is_alive() -> bool:
		return hp > 0

func set_position(grid_position: Vector2) -> void:
	position = grid_position

func take_damage(amount: float) -> bool:
	if amount <= 0:
			return false
	hp = max(0, hp - amount)
	return not is_alive()

func roll_damage() -> float:
	var min_damage = base_damage * (1.0 - DAMAGE_VARIANCE)
	var max_damage = base_damage * (1.0 + DAMAGE_VARIANCE)
	return rand_range(min_damage, max_damage)

func attack(target: Character) -> Dictionary:
	var result = {
		"hit": false,
		"damage": 0.0,
		"target_defeated": false
	}
	if target == null or not target.is_alive():
		return result
	if not is_hostile_to(target):
		return result
	if randf() <= hit_chance:
		result.hit = true
		result.damage = roll_damage()
		result.target_defeated = target.take_damage(result.damage)
	return result

func is_hostile_to(other: Character) -> bool:
	if other == null:
		return false
	return faction != other.faction
