class_name PlantaUiTheme
extends RefCounted

## Shared quiet surfaces leave the illustrated world visible between controls.
const PAPER := Color("f8f5eb")
const LIGHT := Color("eeecdf")
const INK := Color("293f33")
const MUTED := Color("627164")
const GREEN := Color("386e51")
const LINE := Color("c9caba")
const GOLD := Color("d6b46d")
const SELECTED := Color("dcebd0")
const DISABLED := Color("dfe4d9")
const DISABLED_INK := Color("74816f")
const HUD := Color(0.98, 0.97, 0.93, 0.93)


static func panel(canvas: Node2D, rect: Rect2, fill: Color, border: Color = LINE, radius: float = 10.0, elevation: float = 2.0) -> void:
	if rect.size.x < 8 or rect.size.y < 8:
		canvas.draw_rect(rect,fill)
		return
	if elevation > 0:
		canvas.draw_colored_polygon(outline(Rect2(rect.position+Vector2(0,elevation),rect.size),radius),Color(0.12,0.22,0.15,0.16))
	var edge: PackedVector2Array = outline(rect,radius)
	canvas.draw_colored_polygon(edge,fill)
	edge.append(edge[0])
	canvas.draw_polyline(edge,border,1.0,false)


static func hud(canvas: Node2D, rect: Rect2) -> void:
	panel(canvas,rect,HUD,Color(0.83,0.85,0.76,0.8),12,3)


static func outline(rect: Rect2, radius: float = 10.0) -> PackedVector2Array:
	var r: float = clampf(radius,2,minf(rect.size.x,rect.size.y)*0.3)
	var corners: Array[Vector2] = [rect.position+Vector2(r,r),Vector2(rect.end.x-r,rect.position.y+r),rect.end-Vector2(r,r),Vector2(rect.position.x+r,rect.end.y-r)]
	var result := PackedVector2Array()
	for index in range(4):
		for step in range(4):
			var angle: float = PI+float(index)*PI/2.0+float(step)*PI/6.0
			var point: Vector2 = (corners[index]+Vector2(cos(angle),sin(angle))*r).round()
			if result.is_empty() or result[-1] != point: result.append(point)
	return result
