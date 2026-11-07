extends SceneTree

## Full six-by-six groups, intentional lanes and reachable real input targets.
const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")
var checks: int = 0
var failures: int = 0


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(reason)


func _initialize() -> void:
	expect(World.WORLD_SIZE == Vector2(3600,2880),"expanded estate has room for whole squares and useful yards")
	var occupied: Dictionary = {}
	var frames: Array[Rect2] = []
	for area in ["home","nursery"]:
		var blocks: Array[Rect2] = Grid.block_rects(area)
		expect(blocks.size() == 4 and Grid.planting_cells(area).size() == 144,"each dry district contains four complete planting blocks")
		for block_id in range(4):
			var block: Rect2 = blocks[block_id]
			expect(block.size == Vector2.ONE*6*96,"each block is exactly six cells wide and six cells deep")
			for local in range(36):
				var slot: int = block_id*36+local
				var rect: Rect2 = Grid.planting_rect(area,slot)
				expect(Grid.block_index(area,slot) == block_id and block.encloses(rect),"plant identity belongs to its own square")
				expect(rect.position == block.position+Vector2(local%6,local/6)*96,"six regular rows contain six regular columns")
			expect(blocks[0].end.x+96 == blocks[1].position.x and blocks[0].end.y+96 == blocks[2].position.y,"full-cell crossing lanes separate the four squares")
		expect(Grid.block_index(area,-1) == -1 and Grid.block_index(area,144) == -1,"invalid addresses never obtain a block")
	for area in ["home","nursery","pond"]:
		for slot in range(Grid.planting_cells(area).size()):
			var cell: Vector2i = Grid.planting_cell(area,slot)
			var rect: Rect2 = Grid.planting_rect(area,slot)
			var district: String = "garden" if area == "home" else "nursery"
			expect(not occupied.has(cell),"every paid source has a distinct grid address")
			occupied[cell] = true
			expect(World.WORLD_RECT.encloses(rect) and World.district(district)["bounds"].encloses(rect),"complete planting remains inside its proper district")
			expect(rect.size.x*World.ZOOM_MIN >= 44,"smallest zoom preserves a usable touch footprint")
			for obstruction in World.building_hit_regions().values()+World.PROP_RECTS.values()+World.SIGN_RECTS.values()+Grid.occupied_areas().values():
				expect(not rect.intersects(obstruction),"building, prop, sign or equipment cannot cover a real planting")
			if area == "home": expect(World.planting_floor(slot).encloses(rect),"soil metadata uses the source's own square")
			frames.append(rect)
	expect(occupied.size() == 294,"all 288 dry and six water sources occupy unique cells")
	for index in range(frames.size()):
		for other in range(index): expect(not frames[index].intersects(frames[other]),"planting touch rectangles never overlap")
	var camera = World.new()
	for zoom in [World.ZOOM_MIN,World.DEFAULT_ZOOM,World.ZOOM_MAX]:
		camera.set_zoom(zoom)
		for id in ["garden","nursery","greenhouse","pond"]:
			expect(camera.focus_district(id),"every useful destination has a camera shortcut")
			expect(World.WORLD_RECT.grow(0.01).encloses(camera.visible_world_rect()),"district cameras remain inside the estate")
		for frame in frames:
			camera.set_center(frame.get_center())
			expect(camera.screen_to_world(camera.world_to_screen(frame.get_center())).distance_to(frame.get_center()) < 0.01,"every new or moved target keeps reversible input coordinates")
	print("Square bed geometry: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)
