extends SceneTree

const World = preload("res://scripts/garden_world.gd")
const Grid = preload("res://scripts/garden_grid.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _near(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect(actual.distance_to(expected) < 0.002, message)


func _camera_inside(world, message: String) -> void:
	var visible: Rect2 = world.visible_world_rect()
	_expect(World.WORLD_RECT.grow(0.001).encloses(visible), message)
	_near(world.screen_to_world(World.MAP_VIEW.position), visible.position, "visible top-left matches camera transform")
	_near(world.screen_to_world(World.MAP_VIEW.end), visible.end, "visible lower-right matches camera transform")


func _run() -> void:
	_test_districts_and_geography()
	_test_shared_grid()
	_test_transforms_and_pan()
	_test_zoom_anchor_and_limits()
	_test_camera_edges()
	_test_navigation_context()
	print("Garden world: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _test_districts_and_geography() -> void:
	var areas: Array[Dictionary] = World.districts()
	_expect(areas.size() == 3, "world supplies exactly garden, nursery and greenhouse districts")
	var ids: Dictionary = {}
	var world = World.new()
	_camera_inside(world, "initial camera cannot show blank space beyond the world")
	for area in areas:
		var id: String = area["id"]
		var bounds: Rect2 = area["bounds"]
		_expect(not ids.has(id), "district identities are unique")
		ids[id] = true
		_expect(not String(area["name"]).is_empty() and not String(area["description"]).is_empty(), "district has usable player-facing labels")
		_expect(World.WORLD_RECT.encloses(bounds), "district remains in garden geography")
		_expect(bounds.has_point(area["center"]), "district focus belongs to its own area")
		_expect(World.district_at(area["center"]).get("id") == id, "world coordinate resolves to the correct district")
		_expect(world.focus_district(id), "known district can be focused")
		_camera_inside(world, "district jump respects camera limits")
		var focus_on_screen: Vector2 = world.world_to_screen(area["center"])
		_expect(World.MAP_VIEW.has_point(focus_on_screen), "focused district is actually visible")
	var before: Vector2 = world.center
	_expect(not world.focus_district("unknown"), "unknown district cannot navigate the camera")
	_near(world.center, before, "invalid district keeps camera unchanged")
	_expect(World.district("unknown").is_empty(), "unknown district lookup is safe")
	_expect(World.district_at(Vector2(-100, -100)).is_empty(), "outside-world lookup does not invent a district")
	for index in range(areas.size()):
		for other in range(index + 1, areas.size()):
			var first: Rect2 = areas[index]["bounds"]
			var second: Rect2 = areas[other]["bounds"]
			_expect(not first.intersects(second), "district areas are distinct rather than stacked copies")
	var building_hits: Dictionary = World.building_hit_regions()
	_expect(building_hits.size() == 4 and building_hits["collect"] == World.COTTAGE_RECT and building_hits["nursery"] == World.NURSERY_RECT and building_hits["greenhouse"] == World.GREENHOUSE_RECT and building_hits["gate"] == World.GATE_RECT, "one shared source defines exact interactive building bounds")
	for action in building_hits:
		_expect(World.WORLD_RECT.encloses(building_hits[action]), "interactive building stays inside the estate: " + action)
	for area in ["home","nursery","pond"]:
		var count: int = World.PLOT_CENTERS.size() if area == "home" else World.NURSERY_PLOT_CENTERS.size() if area == "nursery" else World.POND_PLOT_CENTERS.size()
		for index in range(count):
			var visual: Rect2 = World.plot_visual_rect(index) if area == "home" else World.nursery_plot_rect(index) if area == "nursery" else World.pond_plot_rect(index)
			for action in building_hits:
				_expect(not visual.intersects(building_hits[action]), "exact building input cannot intercept any complete planting: %s:%d / %s" % [area,index,action])
			for prop in World.PROP_RECTS:
				_expect(not visual.intersects(World.PROP_RECTS[prop]), "placed props leave the complete productive plant readable: %s:%d / %s" % [area,index,prop])
	var beds: Array[Vector2] = World.plot_positions()
	_expect(beds.size() == 96, "the first district supplies all ninety-six income planting slots")
	_expect(World.GARDEN_FLOOR.size == Vector2(Grid.CELL_SIZE*12,Grid.CELL_SIZE*8), "the enlarged garden has twelve columns and eight rows")
	_expect(World.NURSERY_FLOOR.size == World.GARDEN_FLOOR.size, "both dry planting districts offer the same large field area")
	# Save IDs belong to slots, while all income slots now share the first field.
	for index in range(beds.size()):
		var visual: Rect2 = World.plot_visual_rect(index)
		var district_id: String = World.plot_district(index)
		_expect(visual.size.x * World.ZOOM_MIN >= 44 and visual.size.y * World.ZOOM_MIN >= 44, "income beds retain a full 44px touch target at minimum zoom")
		_expect(not visual.intersects(World.NURSERY_RECT), "the nursery building never occludes an income crop")
		_expect(not visual.intersects(World.GREENHOUSE_RECT), "greenhouse building stays separate from all income touch targets")
		_expect(district_id == "garden", "every income crop belongs to the first planting district")
		_expect(not World.district("greenhouse")["bounds"].intersects(visual), "the upgrade district has no income planting footprint")
		var district_bounds: Rect2 = World.district(district_id)["bounds"]
		_expect(district_bounds.encloses(visual), "complete crop remains inside its actual district")
		_expect(World.planting_floor(index).encloses(World.plot_rect(index)), "crop soil remains on its own district planting ground")
		_expect(World.district_at(beds[index]).get("id") == district_id, "world lookup agrees with the crop's assigned district")
		_expect(visual.encloses(World.plot_rect(index)), "crop touch footprint includes its entire soil bed")
		_expect(World.plot_rect(index).has_point(beds[index]), "soil and world center agree")
		for other in range(index + 1, beds.size()):
			_expect(not visual.intersects(World.plot_visual_rect(other)), "garden plots do not overlap each other")
	_expect(World.plot_rect(-1) == Rect2(), "negative crop index is rejected")
	_expect(World.plot_visual_rect(beds.size()) == Rect2(), "out-of-range crop index is rejected")
	_expect(World.plot_district(-1).is_empty() and World.plot_district(beds.size()).is_empty(), "invalid crop indices cannot invent a district")
	_expect(World.planting_floor(-1) == Rect2() and World.planting_floor(beds.size()) == Rect2(), "invalid crop indices cannot acquire planting ground")
	_expect(World.expansion_regions().is_empty(), "removed regions have no active discovery metadata")
	for id in ["berry","far_garden","sun_meadow"]:
		_expect(World.district(id).is_empty() and not world.focus_district(id), "retired regions cannot be navigated: " + id)
	_expect(World.NURSERY_PLOT_CENTERS.size() == 96, "the second district supplies all ninety-six defender planting slots")
	for index in range(World.NURSERY_PLOT_CENTERS.size()):
		var visual: Rect2 = World.nursery_plot_rect(index)
		var district_id: String = "nursery"
		_expect(not visual.intersects(World.NURSERY_RECT), "nursery building never intercepts a defender planting touch target")
		_expect(visual.size.x * World.ZOOM_MIN >= 44 and visual.size.y * World.ZOOM_MIN >= 44, "defense beds retain 44px tap targets at minimum zoom")
		_expect(World.district(district_id)["bounds"].encloses(visual), "defender plot stays inside the second planting district")
		_expect(World.NURSERY_FLOOR.encloses(visual), "each defender cell is contained by the enlarged nursery ground")
		_expect(World.nursery_plot_district(index) == district_id, "defender metadata agrees with the second district")
		_expect(not World.district("greenhouse")["bounds"].intersects(visual), "the upgrade district has no defender planting footprint")
		_expect(World.district_at(World.NURSERY_PLOT_CENTERS[index]).get("id") == district_id, "defender world position resolves to its real district")
		for other in range(index + 1, World.NURSERY_PLOT_CENTERS.size()):
			_expect(not visual.intersects(World.nursery_plot_rect(other)), "nursery touch targets never overlap")
		for plot_index in range(beds.size()):
			_expect(not visual.intersects(World.plot_visual_rect(plot_index)), "income and defense planting footprints remain separate")
	_expect(World.POND_PLOT_CENTERS.size() == 6, "six stable aquatic planting slots are mapped to the pond")
	for index in range(World.POND_PLOT_CENTERS.size()):
		var visual: Rect2 = World.pond_plot_rect(index)
		_expect(World.district("pond")["bounds"].encloses(visual), "aquatic touch footprint belongs to the nursery district")
		_expect(World.district_at(visual.get_center()).get("id") == "nursery", "water belongs to the second planting district on the map")
		_expect(not World.district("greenhouse")["bounds"].intersects(visual), "the upgrade district has no aquatic planting footprint")
		_expect(visual.size.x * World.ZOOM_MIN >= 44 and visual.size.y * World.ZOOM_MIN >= 44, "aquatic plots retain a 44px tap target even at minimum zoom")
		for other in range(index + 1, World.POND_PLOT_CENTERS.size()):
			_expect(not visual.intersects(World.pond_plot_rect(other)), "aquatic touch targets never overlap")
	_expect(World.pond_plot_rect(-1) == Rect2() and World.pond_plot_rect(6) == Rect2(), "invalid aquatic slots do not invent a touch area")
	_expect(World.nursery_plot_rect(-1) == Rect2() and World.nursery_plot_rect(World.NURSERY_PLOT_CENTERS.size()) == Rect2(), "invalid defender indices are rejected")
	_expect(World.district("nursery")["bounds"].encloses(World.NURSERY_RECT), "nursery building belongs to nursery district")
	_expect(World.district("greenhouse")["bounds"].encloses(World.GREENHOUSE_RECT), "greenhouse building belongs to greenhouse district")
	_expect(World.district("pond")["bounds"].encloses(World.POND_RECT), "the entire pond belongs to the nursery district")
	for path in World.path_anchors():
		_expect(path.size() >= 2, "district connection has enough anchors to draw a path")
		for point in path:
			_expect(World.WORLD_RECT.has_point(point), "connecting paths remain inside garden geography")
	# Consumers receive copies; rendering or overview code cannot mutate the map.
	areas[0]["name"] = "changed"
	_expect(World.district("garden")["name"] == "Огород", "district result cannot mutate shared labels")
	beds[0] = Vector2.ZERO
	_expect(World.plot_positions()[0] != Vector2.ZERO, "crop positions are independent copies")


func _test_shared_grid() -> void:
	var occupied: Dictionary = {}
	var total: int = 0
	for area in ["home","nursery","pond"]:
		var points: Array[Vector2] = World.PLOT_CENTERS if area == "home" else World.NURSERY_PLOT_CENTERS if area == "nursery" else World.POND_PLOT_CENTERS
		for slot in range(points.size()):
			var bounds: Rect2 = World.plot_visual_rect(slot) if area == "home" else World.nursery_plot_rect(slot) if area == "nursery" else World.pond_plot_rect(slot)
			var address: Vector2 = (bounds.position-Grid.ORIGIN)/float(Grid.CELL_SIZE)
			_expect(address.is_equal_approx(address.round()) and bounds.size == Vector2.ONE*Grid.CELL_SIZE,"all 198 active planting footprints use one exact world-cell lattice")
			_expect(points[slot].is_equal_approx(bounds.get_center()),"one plant is anchored at its own cell center")
			_expect(bounds == Grid.planting_rect(area,slot),"rendering and hit geometry share the stable planting ID's cell address")
			_expect(not occupied.has(address),"income, defender and aquatic IDs never share a cell")
			occupied[address] = true
			for structure in Grid.occupied_areas():
				_expect(not bounds.intersects(Grid.occupied_areas()[structure]),"the full planting cell is separate from every reserved structure or helper: %s:%d/%s" % [area,slot,structure])
			total += 1
	_expect(total == 198 and occupied.size() == 198,"all 198 active plantings occupy distinct visible cells")
	var stored: Dictionary = {}
	var stored_count: int = 0
	for area in ["home","nursery","pond"]:
		for cell in Grid.planting_cells(area):
			var rect: Rect2 = Grid.cell_rect(cell)
			_expect(not stored.has(cell),"all expanded save IDs retain separate cell addresses")
			_expect(rect.size == Vector2.ONE*Grid.CELL_SIZE and rect.position == Vector2(cell)*Grid.CELL_SIZE,"serialized planting geometry stays on the shared whole-cell lattice")
			stored[cell] = true
			stored_count += 1
	_expect(stored_count == 198 and stored.size() == 198,"the expanded model maps all 198 serialized planting IDs to active cells")
	for structure in Grid.occupied_areas():
		var bounds: Rect2 = Grid.occupied_areas()[structure]
		var address: Vector2 = (bounds.position-Grid.ORIGIN)/float(Grid.CELL_SIZE)
		var span: Vector2 = bounds.size/float(Grid.CELL_SIZE)
		# The cottage artwork ends halfway through a row; the nursery and all
		# productive cells and equipment retain whole-cell spans.
		if structure == "cottage":
			_expect(address.is_equal_approx(address.round()) and is_equal_approx(span.x,roundf(span.x)) and is_equal_approx(span.y*2.0,roundf(span.y*2.0)),"building origins and widths use whole cells while art heights use half cells: "+structure)
		else:
			_expect(address.is_equal_approx(address.round()) and span.is_equal_approx(span.round()),"the whole reserved structure follows the same world lattice: "+structure)
	_expect(Grid.NURSERY_RECT.size == Vector2(Grid.CELL_SIZE*3,Grid.CELL_SIZE*4),"the nursery landmark occupies three whole columns and four whole rows")


func _test_transforms_and_pan() -> void:
	var world = World.new()
	world.set_center(World.WORLD_SIZE / 2.0)
	for zoom in [World.ZOOM_MIN, 0.9, World.ZOOM_MAX]:
		world.set_zoom(zoom)
		for point in [Vector2.ZERO, Vector2(300, 500), Vector2(900, 700), World.WORLD_SIZE, Vector2(-50, 1500)]:
			_near(world.screen_to_world(world.world_to_screen(point)), point, "world/screen transform round trip works at every supported zoom")
		_near(world.world_to_screen(world.center), World.MAP_VIEW.get_center(), "camera center maps to viewport center")
	world.set_zoom(0.9)
	world.set_center(Vector2(900, 700))
	var fixed_world_point = Vector2(1000, 700)
	var screen_before: Vector2 = world.world_to_screen(fixed_world_point)
	world.pan_screen(Vector2(90, -45))
	_near(world.center, Vector2(800, 750), "dragging content moves camera in the opposite world direction")
	_near(world.world_to_screen(fixed_world_point), screen_before + Vector2(90, -45), "world follows the player's drag without jumps")
	var before: Vector2 = world.center
	world.pan_screen(Vector2(NAN, 10))
	_near(world.center, before, "invalid drag cannot poison camera coordinates")


func _test_zoom_anchor_and_limits() -> void:
	var world = World.new()
	world.set_center(Vector2(900, 700))
	var anchor: Vector2 = World.MAP_VIEW.get_center() + Vector2(100, -80)
	var anchored_world: Vector2 = world.screen_to_world(anchor)
	world.zoom_at(1.2, anchor)
	_expect(is_equal_approx(world.zoom, World.DEFAULT_ZOOM * 1.2), "gesture factor adjusts magnification")
	_near(world.screen_to_world(anchor), anchored_world, "zoom keeps the world point under the cursor or pinch midpoint")
	world.zoom_at(0.9, anchor)
	_near(world.screen_to_world(anchor), anchored_world, "zoom-out also preserves the screen anchor away from edges")
	world.zoom_at(1000, anchor)
	_expect(world.zoom == World.ZOOM_MAX, "zoom-in respects maximum magnification")
	_camera_inside(world, "maximum anchored zoom remains inside the world")
	world.zoom_at(0.0001, anchor)
	_expect(world.zoom == World.ZOOM_MIN, "zoom-out respects overview limit")
	_camera_inside(world, "minimum anchored zoom remains inside the world")
	var before_zoom: float = world.zoom
	var before_center: Vector2 = world.center
	for invalid_factor in [0.0, -1.0, NAN, INF]:
		world.zoom_at(invalid_factor, anchor)
		_expect(world.zoom == before_zoom, "invalid zoom gesture is ignored")
		_near(world.center, before_center, "invalid gesture keeps world focus stable")
	world.set_zoom(INF)
	_expect(world.zoom == before_zoom, "invalid absolute zoom is ignored")


func _test_camera_edges() -> void:
	var world = World.new()
	for zoom in [World.ZOOM_MIN, 0.7, World.DEFAULT_ZOOM, 1.1, World.ZOOM_MAX]:
		world.set_zoom(zoom)
		for delta in [Vector2(100000, 100000), Vector2(-100000, -100000), Vector2(-100000, 100000), Vector2(100000, -100000)]:
			world.pan_screen(delta)
			_camera_inside(world, "extreme pan remains inside every world corner")
		for area in World.districts():
			world.focus_district(area["id"])
			_camera_inside(world, "every district is safely reachable at every zoom")
		world.set_center(Vector2(-10000, 10000))
		_camera_inside(world, "direct center change also respects the world bounds")
	var before: Vector2 = world.center
	world.set_center(Vector2(INF, 30))
	_near(world.center, before, "non-finite focus is ignored")


func _test_navigation_context() -> void:
	var world = World.new()
	for zoom in [World.ZOOM_MIN,World.DEFAULT_ZOOM,World.ZOOM_MAX]:
		world.set_zoom(zoom)
		for district in World.districts():
			var id: String = district["id"]
			_expect(world.focus_district(id), "a known place can be explicitly selected at each supported zoom")
			_expect(world.current_district().get("id") == id, "boundary clamping never renames the selected district: " + id)
			_near(world.navigation_context()["focus"],district["center"],"district context retains the actual requested focus before clamping")
			_camera_inside(world,"semantic focus never moves the viewport outside the estate")
			var context: Dictionary = world.navigation_context()
			for changed_zoom in [World.ZOOM_MIN,World.ZOOM_MAX,World.DEFAULT_ZOOM]:
				world.set_zoom(changed_zoom)
				_expect(world.current_district().get("id") == id and world.navigation_context() == context, "zoom alone preserves the place the player chose")
			world.zoom_at(0.75,World.MAP_VIEW.position+Vector2(50,80))
			_expect(world.current_district().get("id") == id and world.navigation_context() == context, "anchor-preserving zoom does not replace semantic focus with the clamped center")
	world.set_zoom(World.ZOOM_MIN)
	world.focus_district("garden")
	world.pan_screen(Vector2(1000,1000))
	var before_center: Vector2 = world.center
	var before_context: Dictionary = world.navigation_context()
	world.pan_screen(Vector2(1000,1000))
	_near(world.center,before_center,"dragging beyond a clamped edge produces no phantom camera movement")
	_expect(world.navigation_context() == before_context and world.current_district().get("id") == "garden", "zero-motion edge panning cannot discard the garden selection")
	before_center = world.center
	var before_focus: Vector2 = world.navigation_context()["focus"]
	world.pan_screen(Vector2(-0.5,-0.5))
	_near(world.navigation_context()["focus"],before_focus+world.center-before_center,"small panning changes context only by actual camera motion")
	_expect(world.current_district().get("id") == "garden","one pixel of panning never jumps from a clamped garden to an unrelated path")
	# Navigate by the actual district distance, so this remains a real long pan
	# when the planting fields and the world dimensions grow.
	world.set_zoom(maxf(World.DEFAULT_ZOOM,0.8))
	world.focus_district("garden")
	var greenhouse_focus: Vector2 = World.district("greenhouse")["center"]
	world.pan_screen((Vector2(world.navigation_context()["focus"])-greenhouse_focus)*world.zoom)
	_expect(world.current_district().get("id") == "greenhouse","a genuine long pan can enter the next logical place")
	world.set_zoom(World.ZOOM_MIN)
	world.set_center(World.subarea("pond")["center"])
	_expect(world.current_district().get("id") == "nursery", "raw minimap intent inside water selects its nursery parent district")
	_near(world.navigation_context()["focus"],World.POND_CENTER,"overview clamping retains the actual requested pond focus")
	_expect(World.district("pond")["id"] == "nursery" and World.subarea("pond")["parent"] == "nursery","pond shortcuts resolve to the second district without adding a fourth district")
	var saved_context: Dictionary = world.navigation_context()
	world.set_center(Vector2(900,1400))
	var physical_center: Vector2 = world.center
	world.restore_navigation_context(saved_context)
	_near(world.center,physical_center,"restoring navigation context never moves an already restored camera")
	_expect(world.current_district().get("id") == "nursery", "stored context restores the user's selected place independently of physical centering")
	for malformed in [{},{"focus":"retired_place"},{"focus":Vector2(INF,NAN)}]:
		world.restore_navigation_context(malformed)
		_expect(world.navigation_context() == saved_context and world.center == physical_center, "invalid navigation context cannot poison a valid camera or district")
	_expect(not world.focus_district("unknown") and world.navigation_context() == saved_context,"unknown destination leaves semantic navigation unchanged")
	# In-bounds raw coordinates now express intent in the larger current map;
	# main owns migration of saves that explicitly identify an older layout.
	for area in World.districts():
		var active_focus: Vector2 = Rect2(area["bounds"]).get_center()
		world.set_center(active_focus)
		world.restore_navigation_context({"focus":active_focus})
		_expect(world.current_district().get("id") == area["id"],"restoring a current in-bounds focus preserves its actual district")
		_near(world.navigation_context()["focus"],active_focus,"restoring an active focus does not snap it to a district shortcut")
		_camera_inside(world,"restored current focus stays inside the expanded estate")
	for retired_focus in [Vector2(480,World.WORLD_SIZE.y+144),Vector2(1296,World.WORLD_SIZE.y+720)]:
		world.set_center(retired_focus)
		world.restore_navigation_context({"focus":retired_focus})
		_expect(world.current_district().get("id") == "greenhouse","restoring an old off-map southern focus selects a remaining place")
		_near(world.navigation_context()["focus"],World.district("greenhouse")["center"],"off-map serialized focus cannot restore a deleted southern destination")
		_camera_inside(world,"migrated southern camera stays within the expanded estate")
