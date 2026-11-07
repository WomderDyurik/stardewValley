extends Node

## A separate scene; battle and wallet models live in the persistent controller.
func render(canvas: Node2D) -> void:
	canvas._draw_defense_header()
	canvas._draw_battle()
