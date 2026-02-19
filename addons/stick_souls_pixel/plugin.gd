@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type(
		"SmoothPixelSubViewportContainer",
		"SubViewportContainer",
		preload("res://addons/stick_souls_pixel/smooth_pixel_subviewport_container.gd"),
		null
	)

func _exit_tree() -> void:
	remove_custom_type("SmoothPixelSubViewportContainer")
