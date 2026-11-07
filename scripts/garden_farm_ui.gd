class_name GardenFarmUi
extends RefCounted

## Wood-framed garden controls share the farm's square pixel edges.
## Battle and modal controls retain their existing layout and input rules.
const INK := Color("573018")
const EDGE := Color("71361c")
const WOOD := Color("cf762c")
const LIGHT := Color("ffe4a0")


static func panel(canvas: Node2D, rect: Rect2, active: bool = false) -> void:
	canvas.draw_rect(Rect2(rect.position+Vector2(0,3),rect.size),Color("603c24"))
	canvas.draw_rect(rect,EDGE)
	canvas.draw_rect(rect.grow(-2),Color("e09b41"))
	canvas.draw_rect(rect.grow(-5),WOOD)
	canvas.draw_rect(rect.grow(-7),Color("f3c779") if not active else Color("e6a454"))
	canvas.draw_rect(Rect2(rect.position+Vector2(7,7),Vector2(rect.size.x-14,2)),LIGHT)
	canvas.draw_rect(Rect2(rect.position+Vector2(7,rect.size.y-9),Vector2(rect.size.x-14,2)),Color("b8682e"))


static func button(canvas: Node2D, rect: Rect2, label: String, action: String, enabled: bool = true, harvest: bool = false) -> void:
	var pressed: bool = enabled and canvas._is_control_pressed(action)
	var drawn := Rect2(rect.position+Vector2(0,2 if pressed else 0),rect.size)
	panel(canvas,drawn,pressed)
	if harvest and enabled:
		canvas.draw_rect(drawn.grow(-7),Color("f5d58c"))
	var foreground: Color = INK if enabled else Color("886c42")
	var text_rect: Rect2 = drawn.grow(-9)
	var forward: bool = label.ends_with(" >")
	if forward:
		text_rect.size.x -= 18
		canvas._draw_control_chevron(Rect2(drawn.end.x-30,drawn.position.y,22,drawn.size.y),true,foreground)
	canvas._label(text_rect,label.left(label.length()-2) if forward else label,18,foreground,canvas.bold,false,true)
	if enabled: canvas._hit(rect,action)


static func header(canvas: Node2D) -> void:
	panel(canvas,Rect2(16,16,284,60))
	canvas._label(Rect2(30,20,256,28),"Тихий сад",23,INK,canvas.display_font)
	var district: Dictionary = canvas.garden_world.current_district()
	canvas._label(Rect2(30,48,256,19),district.get("name","Тропинки сада"),13,INK)
	button(canvas,Rect2(312,31,44,44),"?","help")
	panel(canvas,Rect2(368,22,156,60))
	canvas._draw_coin(Rect2(381,42,25,25))
	canvas._label(Rect2(417,27,95,18),"Монеты",12,INK,canvas.bold)
	canvas._label(Rect2(417,47,95,28),canvas._compact_coins(canvas.state.coins),21,INK,canvas.bold)
