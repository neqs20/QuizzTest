extends Node

onready var content : Label = $Text

func set_text(text : String) -> void:
	content.text = text

