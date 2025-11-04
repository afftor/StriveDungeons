extends PopupDialog

func _ready() -> void:
    var button := $VBoxContainer/RestartButton
    if button:
        button.connect("pressed", self, "_on_restart_pressed")

func _on_restart_pressed() -> void:
    get_tree().reload_current_scene()
