class_name GardenHelperMenus
extends RefCounted

const Helpers = preload("res://scripts/garden_helpers.gd")
const Art = preload("res://scripts/garden_helper_visuals.gd")


static func draw(canvas: Node2D) -> void:
	canvas.hitboxes.clear()
	canvas.draw_rect(Rect2(0,0,540,960),Color(0.10,0.18,0.12,0.48))
	if canvas.home_panel == "helper_details": _details(canvas)
	else: _overview(canvas)


static func _overview(canvas: Node2D) -> void:
	canvas._box(Rect2(24,174,492,676),canvas.PAPER)
	canvas._label(Rect2(44,190,452,42),"Улучшения теплицы",28,canvas.GREEN,canvas.bold)
	canvas._label(Rect2(45,239,450,26),"Полив, подкормка и хранение урожая",17,canvas.MUTED)
	canvas._label(Rect2(45,273,450,25),"Цикл %d с · в запасе %d из %d урожаев" % [roundi(canvas.state.home_cycle()),canvas.state.stored_harvests(),canvas.state.harvest_capacity()],16,canvas.GREEN)
	for index in range(Helpers.ORDER.size()):
		var id: String = Helpers.ORDER[index]
		var info: Dictionary = Helpers.INFO[id]
		var level: int = canvas.state.helper_level(id)
		var rect := Rect2(42,312+index*140,456,128)
		var pressed: bool = canvas._is_control_pressed("helper:"+id)
		canvas._box(rect,Color("edeedf") if pressed else Color("faf7ed"),6,Color("d5d3c0"))
		Art.draw_icon(canvas,id,maxi(1,level),Rect2(rect.position+Vector2(12,14),Vector2(88,92)))
		canvas._label(Rect2(rect.position+Vector2(114,7),Vector2(328,28)),info["name"],21,canvas.INK,canvas.bold)
		canvas._label(Rect2(rect.position+Vector2(114,38),Vector2(328,23)),"Уровень %d из 3" % level if level>0 else "Ещё не построено",15,canvas.MUTED)
		canvas._label(Rect2(rect.position+Vector2(114,65),Vector2(328,24)),Helpers.effect_text(id,level) if level>0 else info["purpose"],16,canvas.GREEN)
		var cost: int = canvas.state.helper_upgrade_cost(id)
		var next: String = "Открыть" if cost<=0 else "%s · %d монет" % ["Улучшить" if level>0 else "Построить",cost]
		canvas._label(Rect2(rect.position+Vector2(114,96),Vector2(328,23)),next+" →",15,canvas.INK,canvas.bold)
		canvas._hit(rect,"helper:"+id)
	canvas._center(Rect2(44,741,452,24),"Урожаи накапливаются, пока игра открыта",15,canvas.MUTED)
	canvas._button(Rect2(44,788,452,44),"Вернуться в сад","close_home_panel",true,false)


static func _details(canvas: Node2D) -> void:
	var id: String = canvas.active_helper_id
	if not Helpers.is_valid(id):
		canvas.home_panel = "helpers"
		_overview(canvas)
		return
	var info: Dictionary = Helpers.INFO[id]
	var level: int = canvas.state.helper_level(id)
	var cost: int = canvas.state.helper_upgrade_cost(id)
	canvas._box(Rect2(24,170,492,700),canvas.PAPER)
	canvas._label(Rect2(44,185,452,42),info["name"],28,canvas.GREEN,canvas.bold)
	canvas._label(Rect2(45,234,450,26),"Уровень %d из 3 · весь сад" % level if level>0 else "Проект установки · весь сад",17,canvas.MUTED)
	Art.draw_icon(canvas,id,maxi(1,level),Rect2(202,272,136,128))
	canvas._label(Rect2(48,420,444,60),info["description"],18,canvas.INK,null,true)
	for index in range(2):
		var rect := Rect2(44+index*238,494,214,90)
		canvas._box(rect,Color("e9ecdc") if index==1 and cost>0 else Color("f7f5eb"),6)
		canvas._center(Rect2(rect.position+Vector2(4,4),Vector2(206,23)),"Сейчас" if index==0 else "После улучшения" if level>0 and cost>0 else "После постройки" if cost>0 else "Максимум",15,canvas.MUTED)
		var effect: String = Helpers.effect_text(id,level) if index==0 else Helpers.next_effect_text(id,level)
		canvas._label(Rect2(rect.position+Vector2(10,32),Vector2(194,50)),effect,17,canvas.GREEN,canvas.bold,true,true)
	var title: String = "Максимальный уровень" if cost<=0 else "%s · %d монет" % ["Улучшить" if level>0 else "Построить",cost]
	canvas._button(Rect2(44,612,452,56),title,"upgrade_helper:"+id,canvas.state.can_upgrade_helper(id))
	if cost>canvas.state.coins:
		canvas._center(Rect2(44,676,452,24),"Нужно ещё %d монет" % (cost-canvas.state.coins),16,canvas.MUTED)
	elif cost>0:
		canvas._center(Rect2(44,676,452,24),"Постоянное улучшение сада",16,canvas.MUTED)
	if level>0:
		canvas._button(Rect2(44,726,452,46),"Найти у теплицы","locate_helper:"+id,true,false)
	canvas._button(Rect2(44,800,452,46),"Все улучшения","helpers",true,false)
