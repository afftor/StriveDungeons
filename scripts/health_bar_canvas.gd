extends Control

var hex_grid = null
var bars = {}

func _ready():
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func set_hex_grid(grid):
    hex_grid = grid
    _rebuild_bars()

func refresh_from_grid():
    _sync_bars()
    _update_bars()

func _process(_delta):
    if hex_grid == null:
        return
    _sync_bars()
    _update_bars()

func _rebuild_bars():
    for child in get_children():
        child.queue_free()
    bars.clear()
    if hex_grid == null:
        return
    for character_id in hex_grid.get_character_ids():
        _ensure_bar(character_id)

func _sync_bars():
    if hex_grid == null:
        return
    var existing_ids = hex_grid.get_character_ids()
    var to_remove = []
    for character_id in bars.keys():
        if not existing_ids.has(character_id):
            to_remove.append(character_id)
    for character_id in to_remove:
        var node = bars.get(character_id, null)
        if node != null:
            node.queue_free()
        bars.erase(character_id)
    for character_id in existing_ids:
        _ensure_bar(character_id)

func _ensure_bar(character_id):
    if bars.has(character_id):
        return bars[character_id]
    if hex_grid == null:
        return null
    var bar_node = Control.new()
    bar_node.name = character_id
    bar_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar_node.anchor_left = 0
    bar_node.anchor_top = 0
    bar_node.anchor_right = 0
    bar_node.anchor_bottom = 0
    add_child(bar_node)
    var background = ColorRect.new()
    background.name = "Background"
    background.color = hex_grid.HEALTH_BAR_BACKGROUND_COLOR
    background.rect_size = Vector2(hex_grid.HEALTH_BAR_WIDTH, hex_grid.HEALTH_BAR_HEIGHT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar_node.add_child(background)
    var fill = ColorRect.new()
    fill.name = "Fill"
    fill.color = hex_grid.HEALTH_BAR_FOREGROUND_COLOR
    fill.rect_size = background.rect_size
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.add_child(fill)
    bars[character_id] = bar_node
    return bar_node

func _update_bars():
    if hex_grid == null:
        return
    var canvas_transform = get_viewport().get_canvas_transform()
    for character_id in bars.keys():
        var bar_node = bars[character_id]
        if bar_node == null:
            continue
        var character = hex_grid.get_character(character_id)
        if character == null:
            bar_node.visible = false
            continue
        var position = hex_grid.get_character_position(character_id)
        if position == null:
            bar_node.visible = false
            continue
        var world_position = hex_grid.get_world_position(position.x, position.y)
        var global_position = hex_grid.to_global(world_position)
        var screen_position = canvas_transform.xform(global_position)
        var offset = Vector2(-hex_grid.HEALTH_BAR_WIDTH * 0.5, hex_grid.HEALTH_BAR_OFFSET_Y)
        bar_node.rect_position = screen_position + offset
        var health_ratio = 0.0
        if character.max_hp > 0:
            health_ratio = clamp(float(character.hp) / float(character.max_hp), 0.0, 1.0)
        var background = bar_node.get_node("Background")
        if background != null:
            var fill = background.get_node("Fill")
            if fill != null:
                fill.rect_size.x = hex_grid.HEALTH_BAR_WIDTH * health_ratio
        bar_node.visible = character.is_alive()
