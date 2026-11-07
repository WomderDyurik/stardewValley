class_name GardenHelperVisuals
extends RefCounted

const Helpers = preload("res://scripts/garden_helpers.gd")
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
static var FRAMES: Dictionary = {
	"irrigation":Grid.helper_rect("irrigation"),
	"compost":Grid.helper_rect("compost"),
	"harvest_crate":Grid.helper_rect("harvest_crate"),
}
const TEXTURES: Dictionary = {
	"irrigation":[preload("res://assets/pixel/garden_helpers_v1/irrigation_1.tres"),preload("res://assets/pixel/garden_helpers_v1/irrigation_2.tres"),preload("res://assets/pixel/garden_helpers_v1/irrigation_3.tres")],
	"compost":[preload("res://assets/pixel/garden_helpers_v1/compost_1.tres"),preload("res://assets/pixel/garden_helpers_v1/compost_2.tres"),preload("res://assets/pixel/garden_helpers_v1/compost_3.tres")],
	"harvest_crate":[preload("res://assets/pixel/garden_helpers_v1/harvest_crate_1.tres"),preload("res://assets/pixel/garden_helpers_v1/harvest_crate_2.tres"),preload("res://assets/pixel/garden_helpers_v1/harvest_crate_3.tres")],
}


static func draw_icon(canvas: Node2D, id: String, level: int, bounds: Rect2, world: bool = false) -> void:
	if not TEXTURES.has(id): return
	var texture: Texture2D = TEXTURES[id][clampi(level,1,3)-1]
	var scale: float = minf(bounds.size.x/texture.get_width(),bounds.size.y/texture.get_height())
	if world: scale *= [0.78,0.89,1.0][clampi(level,1,3)-1]
	var size: Vector2 = (texture.get_size()*scale).floor()
	var frame := Rect2(Vector2(bounds.get_center().x-size.x/2.0,bounds.end.y-size.y).floor(),size)
	canvas.draw_texture_rect(texture,frame,false)


static func draw_world(canvas: Node2D, view: Node) -> void:
	for id in Helpers.ORDER:
		var level: int = canvas.state.helper_level(id)
		if level <= 0: continue
		var frame: Rect2 = FRAMES[id]
		draw_icon(canvas,id,level,sprite_bounds(id),true)
		# The model and its compact number share one reserved grid cell. The
		# lower strip is deliberately left clear even at minimum camera zoom.
		view._queue_level(frame,level)
		if id == "irrigation" and not canvas.state.home_ready:
			# Drops stay beside the station, outside crop and walking silhouettes.
			var at: Vector2 = frame.position+Vector2(12,46)
			for index in range(3):
				var t: float = fposmod(canvas.elapsed*0.7+index/3.0,1.0)
				canvas.draw_rect(Rect2((at+Vector2(-3-t*4,-12*sin(t*PI))).floor(),Vector2(2,3)),Color(0.57,0.83,0.91,0.75))
		if canvas.home_panel.is_empty() and not canvas.help_open:
			var first: Vector2 = canvas.garden_world.world_to_screen(frame.position)
			var size: Vector2 = (frame.size*canvas.garden_world.zoom).max(Vector2(44,44))
			var hit := Rect2(first+frame.size*canvas.garden_world.zoom/2.0-size/2.0,size)
			var visible: Rect2 = hit.intersection(World.MAP_VIEW)
			if visible.size.x >= 20 and visible.size.y >= 20:
				canvas._hit(visible,"helper:"+id,true)


static func sprite_bounds(id: String) -> Rect2:
	if not FRAMES.has(id): return Rect2()
	return Rect2(FRAMES[id].position+Vector2(8,4),Vector2(80,60))
