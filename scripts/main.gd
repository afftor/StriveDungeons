extends Node2D

func _ready():
    _setup_input_actions()

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
